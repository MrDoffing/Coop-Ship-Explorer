class_name Scout
extends CharacterBody3D
## One of the mothership's scout pods.
##
## Docked on the mothership (under the belly, or on the Vanguard's flight deck) until a crew member
## launches it from its scout bay console. It is small enough for the narrow side tunnels where fuel
## crystals grow, carries the fuel back (delivered on docking) and its guns can pick off critters
## clawing at the mothership's hull, which the turrets cannot reach. It uses no fuel. If destroyed
## it is rebuilt after a while. Simulated on the server from the pilot's input; the pilot's camera
## follows it locally. Its stats come live from the mothership, so run upgrades apply at once.

enum State { DOCKED, FLYING, DESTROYED }

const REBUILD_TIME := 25.0
const DOCK_RANGE := 15.0
const PICKUP_RANGE := 12.0
## Same as Projectiles.MASK_SCOUT (rock, enemies, minerals and hull-latched aliens). Kept local to
## avoid a cyclic constant dependency between the two scripts.
const AIM_MASK := 1 | 16 | 128 | 512
const HULL_SECTIONS := [
	[-2.5, 0.22, 0.18, 0.0],
	[-1.5, 0.75, 0.48, 0.05],
	[0.4, 0.95, 0.58, 0.05],
	[1.8, 0.8, 0.48, 0.0],
	[2.25, 0.55, 0.36, 0.0],
]
const COMBAT_SECTIONS := [
	[-3.0, 0.14, 0.1, 0.0],
	[-1.8, 0.58, 0.36, 0.04],
	[0.2, 0.86, 0.5, 0.06],
	[1.7, 0.74, 0.44, 0.02],
	[2.3, 0.5, 0.3, 0.0],
]

# Replicated (server authority).
var net_pos := Vector3.ZERO
var net_vel := Vector3.ZERO
var net_rot := Vector3.ZERO
var state := State.DOCKED
var hp := 70.0
var max_hp := 70.0
var cargo := 0.0
var max_cargo := 40.0
var rebuild := 0.0
var pilot := 0

## The scout bay station that launches this scout ("scout", "scout2") and its index.
var station_id := "scout"
var index := 0
## "standard" or "combat" (the Vanguard's).
var style := "standard"
var _model: Node3D
var _glow_mat: StandardMaterial3D
var _head_light: SpotLight3D
var _fill_light: OmniLight3D
var _audio: AudioStreamPlayer3D
var _since_sync := 0.0
var _input: Dictionary = {}
var _fire_cd := 0.0
var _side := 1.0
var _bump_cd := 0.0


## Build a scout's visual model under `root` (also used by the homebase display).
static func build_model(root: Node3D, model_style := "standard") -> Dictionary:
	if model_style == "combat":
		return _build_combat(root)
	var parts := {}
	var body_mat := Models.panel_mat(Color(0.95, 0.55, 0.16), 0.4, 0.45, 0.8)
	var grey := Models.mat(Color(0.5, 0.52, 0.56), 0.6, 0.4)
	var dark := Models.mat(Color(0.12, 0.13, 0.15), 0.6, 0.5)
	var hull := MeshInstance3D.new()
	hull.mesh = Models.loft(HULL_SECTIONS, 0.35)
	hull.material_override = body_mat
	root.add_child(hull)
	var b := Models.Batch.new()
	b.sphere(Vector3(0, 0.42, -0.75), 0.5, Models.emissive(Color(0.2, 0.55, 0.7), 0.7, Color(0.03, 0.05, 0.07)), Vector3(1.0, 0.6, 1.7))
	b.box(Vector3(0, 0.62, -0.75), Vector3(0.06, 0.08, 1.5), dark)
	for side: float in [-1.0, 1.0]:
		b.box(Vector3(side * 1.55, -0.05, 0.7), Vector3(1.9, 0.1, 1.3), grey, Vector3(0, side * -8.0, side * 8.0))
		b.box(Vector3(side * 1.4, 0.01, 0.75), Vector3(1.2, 0.04, 0.16), Models.mat(Color(0.95, 0.55, 0.16), 0.4, 0.45), Vector3(0, side * -8.0, side * 8.0))
		b.box(Vector3(side * 2.45, 0.08, 0.95), Vector3(0.12, 0.5, 0.9), dark)
		b.sphere(Vector3(side * 2.5, 0.35, 0.9), 0.07, Models.emissive(Color(1, 0.2, 0.15) if side < 0 else Color(0.2, 1, 0.3), 5.0))
		b.cyl(Vector3(side * 1.1, -0.18, -0.4), 0.06, 1.4, dark, Vector3(90, 0, 0))
		b.cyl(Vector3(side * 1.1, -0.18, 0.25), 0.1, 0.3, grey, Vector3(90, 0, 0))
		b.cyl(Vector3(side * 0.6, 0.0, 2.25), 0.3, 0.9, grey, Vector3(90, 0, 0), 0.24)
		b.cyl(Vector3(side * 0.6, 0.0, 1.75), 0.32, 0.08, dark, Vector3(90, 0, 0))
		# Landing skids.
		b.box(Vector3(side * 0.55, -0.5, 0.3), Vector3(0.08, 0.08, 2.2), dark)
		for z: float in [-0.5, 1.0]:
			b.box(Vector3(side * 0.55, -0.38, z), Vector3(0.06, 0.24, 0.06), dark)
	b.box(Vector3(0, 0.55, 1.2), Vector3(0.08, 0.5, 0.9), dark, Vector3(-20, 0, 0))
	b.cyl(Vector3(0.3, 0.62, 0.6), 0.02, 0.5, grey)
	b.commit(root)
	var glow_mat := StandardMaterial3D.new()
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_mat.albedo_color = Color(0.4, 0.85, 1.0)
	for side: float in [-1.0, 1.0]:
		Models.cylinder(root, Vector3(side * 0.6, 0.0, 2.72), 0.2, 0.05, glow_mat, Vector3(90, 0, 0))
	parts["glow_mat"] = glow_mat
	return parts


## The Vanguard's combat scout: darker armour, forward-swept wings with gun pods and tail fins.
static func _build_combat(root: Node3D) -> Dictionary:
	var parts := {}
	var body_mat := Models.panel_mat(Color(0.25, 0.27, 0.31), 0.6, 0.38, 0.8)
	var stripe := Models.mat(Color(0.85, 0.16, 0.12), 0.35, 0.45)
	var steel := Models.mat(Color(0.55, 0.57, 0.6), 0.75, 0.3)
	var dark := Models.mat(Color(0.1, 0.11, 0.13), 0.6, 0.5)
	var hull := MeshInstance3D.new()
	hull.mesh = Models.loft(COMBAT_SECTIONS, 0.4)
	hull.material_override = body_mat
	root.add_child(hull)
	var b := Models.Batch.new()
	b.sphere(Vector3(0, 0.38, -0.95), 0.42, Models.emissive(Color(0.9, 0.3, 0.2), 0.8, Color(0.08, 0.03, 0.03)), Vector3(0.9, 0.55, 1.8))
	b.box(Vector3(0, 0.56, -0.25), Vector3(0.14, 0.06, 2.4), stripe)
	for side: float in [-1.0, 1.0]:
		# Forward-swept wings with a red leading edge.
		var wing := PackedVector2Array([Vector2(side * 0.7, 1.4), Vector2(side * 2.7, 0.2), Vector2(side * 2.7, -0.4), Vector2(side * 0.7, 0.0)])
		b.add(Models.prism(wing, -0.1, 0.0), Transform3D.IDENTITY, body_mat)
		b.beam(Vector3(side * 0.8, -0.02, -0.02), Vector3(side * 2.7, -0.02, -0.42), 0.1, 0.12, stripe)
		# Gun pods under each wing: twin barrels.
		b.box(Vector3(side * 1.1, -0.24, -0.3), Vector3(0.36, 0.28, 1.4), dark)
		for dx: float in [-0.08, 0.08]:
			b.cyl(Vector3(side * 1.1 + dx, -0.24, -1.25), 0.045, 0.6, steel, Vector3(90, 0, 0))
		b.sphere(Vector3(side * 2.72, 0.02, -0.4), 0.07, Models.emissive(Color(1, 0.2, 0.15) if side < 0 else Color(0.2, 1, 0.3), 5.0))
		# Canted tail fins.
		b.box(Vector3(side * 0.5, 0.6, 1.6), Vector3(0.07, 0.75, 0.9), body_mat, Vector3(-25, 0, side * -18.0))
		b.box(Vector3(side * 0.56, 0.86, 1.78), Vector3(0.08, 0.12, 0.5), stripe, Vector3(-25, 0, side * -18.0))
		# Twin engines.
		b.cyl(Vector3(side * 0.55, 0.0, 2.2), 0.3, 1.0, steel, Vector3(90, 0, 0), 0.25)
		b.cyl(Vector3(side * 0.55, 0.0, 1.66), 0.33, 0.08, dark, Vector3(90, 0, 0))
		# Landing skids.
		b.box(Vector3(side * 0.5, -0.48, 0.2), Vector3(0.08, 0.08, 2.2), dark)
		for z: float in [-0.6, 0.9]:
			b.box(Vector3(side * 0.5, -0.36, z), Vector3(0.06, 0.24, 0.06), dark)
	b.box(Vector3(0, -0.36, -1.4), Vector3(0.3, 0.16, 1.0), dark)
	b.cyl(Vector3(0, -0.36, -2.15), 0.05, 0.6, steel, Vector3(90, 0, 0))
	b.commit(root)
	var glow_mat := StandardMaterial3D.new()
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_mat.albedo_color = Color(0.4, 0.85, 1.0)
	for side: float in [-1.0, 1.0]:
		Models.cylinder(root, Vector3(side * 0.55, 0.0, 2.72), 0.2, 0.05, glow_mat, Vector3(90, 0, 0))
	parts["glow_mat"] = glow_mat
	return parts


func _init() -> void:
	NetUtil.add_sync(self, ["net_pos", "net_vel", "net_rot"],
		["state", "hp", "max_hp", "cargo", "max_cargo", "rebuild", "pilot"], 1.0 / 30.0)


func setup(data: Dictionary) -> void:
	index = int(data.get("index", 0))
	station_id = str(data.get("station", "scout"))
	style = str(data.get("style", "standard"))
	name = "Scout" if index == 0 else "Scout%d" % (index + 1)
	var stats: Dictionary = data["stats"]
	max_hp = float(stats["scout_hp"])
	hp = max_hp
	max_cargo = float(stats["scout_cargo"])


func _ready() -> void:
	process_physics_priority = -10
	collision_layer = Game.LAYER_SCOUT
	collision_mask = Game.LAYER_CAVE
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	var cs := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.2
	cs.shape = sphere
	add_child(cs)
	_model = Node3D.new()
	add_child(_model)
	_glow_mat = build_model(_model, style)["glow_mat"]
	_head_light = SpotLight3D.new()
	_head_light.position = Vector3(0, 0.1, -2.6)
	_head_light.spot_range = 70.0
	_head_light.spot_angle = 38.0
	_head_light.spot_attenuation = 0.5
	_head_light.light_energy = 7.0
	_head_light.light_color = Color(1.0, 0.92, 0.8)
	ShipBuilder.configure_shadow(_head_light)
	add_child(_head_light)
	_fill_light = OmniLight3D.new()
	_fill_light.omni_range = 16.0
	_fill_light.light_energy = 0.8
	_fill_light.light_color = Color(0.9, 0.8, 0.7)
	add_child(_fill_light)
	_audio = AudioStreamPlayer3D.new()
	_audio.stream = Sfx.stream("scout_loop")
	_audio.volume_db = -10.0
	_audio.unit_size = 10.0
	add_child(_audio)
	if not multiplayer.is_server():
		($Sync as MultiplayerSynchronizer).synchronized.connect(func(): _since_sync = 0.0)


func _exit_tree() -> void:
	if Game.mission:
		var list: Array = Game.mission.get("scouts")
		if list != null:
			list.erase(self)


func _ship() -> Mothership:
	return Game.mission.ship if Game.mission else null


## A live ship stat (run upgrades change them mid-dive).
func _stat(key: String) -> float:
	var ship := _ship()
	return float(ship.stats.get(key, 0.0)) if ship else 0.0


func dock_point() -> Vector3:
	var ship := _ship()
	return ship.dock_point(station_id) if ship else Vector3.ZERO


func dock_transform() -> Transform3D:
	var ship := _ship()
	if ship == null:
		return global_transform
	return ship.global_transform * Transform3D(Basis.IDENTITY, ship.dock_point(station_id))


func can_launch() -> bool:
	var ship := _ship()
	return state == State.DOCKED and (ship == null or ship.landing == Mothership.Dock.FLYING)


func status_text() -> String:
	match state:
		State.DESTROYED:
			return "Scout is being rebuilt (%d s)" % int(ceil(rebuild))
		State.FLYING:
			return "Scout is out - piloted by %s" % Net.player_name(pilot)
	var ship := _ship()
	if ship and ship.landing != Mothership.Dock.FLYING:
		return "Scout clamped while docked at the waystation"
	return "Scout ready"


# --- Simulation --------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	var ship := _ship()
	if ship == null:
		return
	if multiplayer.is_server():
		_server_tick(delta, ship)
		net_pos = global_position
		net_vel = velocity
		net_rot = global_rotation
	else:
		_client_tick(delta)
	_update_visuals()


func _server_tick(delta: float, ship: Mothership) -> void:
	# Hull and cargo follow the ship's stats (scout upgrades from waystation shops).
	var want_hp := float(ship.stats.get("scout_hp", max_hp))
	if absf(want_hp - max_hp) > 0.01:
		if want_hp > max_hp and state != State.DESTROYED:
			hp += want_hp - max_hp
		max_hp = want_hp
		hp = minf(hp, max_hp)
	max_cargo = float(ship.stats.get("scout_cargo", max_cargo))
	match state:
		State.DOCKED:
			global_transform = dock_transform()
			velocity = ship.velocity
			hp = minf(max_hp, hp + 12.0 * delta)
		State.DESTROYED:
			global_transform = dock_transform()
			velocity = ship.velocity
			rebuild = maxf(0.0, rebuild - delta)
			if rebuild <= 0.0:
				state = State.DOCKED
				hp = max_hp
				ship.notify.rpc("Scout rebuilt and ready in the bay", 0)
		State.FLYING:
			_fly(delta)


func _fly(delta: float) -> void:
	var mv: Vector3 = _input.get("move", Vector3.ZERO)
	var yaw := float(_input.get("yaw", global_rotation.y))
	var pitch := float(_input.get("pitch", 0.0))
	var aim := Basis.from_euler(Vector3(pitch, yaw, 0.0))
	var bank := Basis(Vector3.FORWARD, mv.x * 0.35)
	var q := global_basis.get_rotation_quaternion().slerp((aim * bank).get_rotation_quaternion(), NetUtil.smooth(10.0, delta))
	global_basis = Basis(q)
	var speed := _stat("scout_speed") * (1.6 if _input.get("boost", false) else 1.0)
	var desired := aim * Vector3(mv.x, mv.y, -mv.z).limit_length(1.0) * speed
	velocity = velocity.move_toward(desired, 32.0 * delta)
	var pre := velocity
	move_and_slide()
	_bump_cd = maxf(0.0, _bump_cd - delta)
	for i in get_slide_collision_count():
		var impact := -pre.dot(get_slide_collision(i).get_normal())
		if impact > 9.0 and _bump_cd <= 0.0:
			_bump_cd = 0.5
			take_damage((impact - 7.0) * 2.0, {"source": "impact"})
	_fire_cd = maxf(0.0, _fire_cd - delta)
	if _input.get("fire", false) and _fire_cd <= 0.0:
		_fire_cd = 0.12
		_side = -_side
		# Both wing guns converge on whatever the pilot is aiming at.
		var ray := PhysicsRayQueryParameters3D.create(global_position, global_position - aim.z * 120.0, AIM_MASK)
		ray.collide_with_areas = true
		var hit := get_world_3d().direct_space_state.intersect_ray(ray)
		var focus: Vector3 = hit["position"] if not hit.is_empty() else global_position - aim.z * 120.0
		var muzzle := to_global(Vector3(_side * 1.1, -0.18 if style == "standard" else -0.24, -1.3))
		var dir := (focus - muzzle).normalized()
		Game.mission.projectiles.fire("scout", muzzle, dir * 170.0 + velocity, _stat("scout_damage"))


func _client_tick(delta: float) -> void:
	if state != State.FLYING:
		global_transform = dock_transform()
		return
	_since_sync += delta
	var target := net_pos + net_vel * minf(_since_sync, 0.3)
	if global_position.distance_to(target) > 10.0:
		global_position = target
		reset_physics_interpolation()
	else:
		global_position = global_position.lerp(target, NetUtil.smooth(14.0, delta))
	var q := global_basis.get_rotation_quaternion().slerp(Quaternion.from_euler(net_rot), NetUtil.smooth(14.0, delta))
	global_basis = Basis(q)


func _update_visuals() -> void:
	_model.visible = state != State.DESTROYED
	var flying := state == State.FLYING
	_head_light.visible = flying
	_fill_light.visible = flying
	var speed := (velocity if multiplayer.is_server() else net_vel).length()
	var p := clampf(speed / 20.0, 0.0, 1.0) if flying else 0.0
	_glow_mat.albedo_color = Color(0.2, 0.35, 0.45).lerp(Color(1.2, 2.0, 2.6), 0.2 + 0.8 * p if flying else 0.0)
	if flying != _audio.playing:
		if flying:
			_audio.play()
		else:
			_audio.stop()
	if flying:
		_audio.pitch_scale = 0.8 + p * 0.7


# --- Server API --------------------------------------------------------------------------------

func launch(pid: int) -> void:
	var ship := _ship()
	state = State.FLYING
	pilot = pid
	global_transform = dock_transform()
	velocity = ship.velocity + ship.global_basis * ship.dock_launch(station_id)
	var up := ship.dock_launch(station_id).y > 0.0
	_input = {"yaw": ship.rotation.y, "pitch": 0.15 if up else -0.25}
	reset_physics_interpolation()
	_fx.rpc("launch")


## The pilot left the scout station (exit, death or disconnect): recall the scout.
func pilot_left() -> void:
	if state == State.FLYING:
		_dock()
	pilot = 0


## Server: the mothership is docking at a waystation: bring the scout home (its cargo included).
func recall_for_docking() -> void:
	if state == State.FLYING:
		var ship := _ship()
		ship.notify_peer(pilot, "Scout recalled - the mothership is docking", 1)
		_dock()


func take_damage(amount: float, _info: Dictionary) -> void:
	if not multiplayer.is_server() or state != State.FLYING:
		return
	hp -= amount
	if hp <= 0.0:
		hp = 0.0
		state = State.DESTROYED
		rebuild = REBUILD_TIME
		cargo = 0.0
		Game.mission.fx_event.rpc("scout_boom", global_position, 0)
		var ship := _ship()
		ship.notify.rpc("The scout was destroyed! Rebuilding...", 2)
		ship.release_peer(pilot)
		pilot = 0


## Accept up to `amount` fuel into the cargo hold; returns what fit.
func add_cargo(amount: float) -> float:
	var taken := minf(amount, max_cargo - cargo)
	if taken > 0.0:
		cargo += taken
	return taken


func _dock() -> void:
	var ship := _ship()
	state = State.DOCKED
	global_transform = dock_transform()
	reset_physics_interpolation()
	if cargo > 0.0:
		ship.add_fuel(cargo)
		cargo = 0.0
	_fx.rpc("dock")
	var pid := pilot
	pilot = 0
	ship.release_peer(pid)


@rpc("any_peer", "call_local", "unreliable_ordered")
func pilot_input(data: Dictionary) -> void:
	if multiplayer.is_server() and Game.sender_id() == pilot and state == State.FLYING:
		_input = data


@rpc("any_peer", "call_local", "reliable")
func request_dock() -> void:
	if not multiplayer.is_server() or Game.sender_id() != pilot or state != State.FLYING:
		return
	var dist := global_position.distance_to(dock_transform().origin)
	if dist <= DOCK_RANGE:
		_dock()
	else:
		_ship().notify_peer(pilot, "Too far to dock (%d m) - fly back to the mothership's scout dock" % int(dist), 1)


## Pilot gave up the flight: the scout returns to the bay on autopilot, dropping its cargo.
@rpc("any_peer", "call_local", "reliable")
func request_recall() -> void:
	if not multiplayer.is_server() or Game.sender_id() != pilot or state != State.FLYING:
		return
	cargo = 0.0
	_ship().notify_peer(pilot, "Scout recalled - fuel cargo jettisoned", 1)
	_dock()


@rpc("authority", "call_local", "reliable")
func _fx(kind: String) -> void:
	match kind:
		"launch":
			Sfx.play("launch", global_position, 0.0)
		"dock":
			Sfx.play("dock", global_position, 0.0)
			Fx.ring(global_position, Vector3.UP, Color(0.4, 1.0, 0.6), 4.0, 0.5)
