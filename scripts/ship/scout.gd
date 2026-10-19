class_name Scout
extends CharacterBody3D
## One of the mothership's scouts: a small fighter with a cockpit for one (ScoutCockpit).
##
## Docked on the mothership (under the belly, or on the Vanguard's flight deck) until a crew member
## climbs in at its scout bay console and launches it. It is small enough for the narrow side
## tunnels where fuel crystals grow, carries the fuel back (delivered on docking) and its guns can
## pick off critters clawing at the mothership's hull, which the gun pods cannot reach. It uses no
## fuel. If destroyed it is rebuilt after a while. Simulated on the server from the pilot's input;
## the pilot flies it in first person from the cockpit, and their own client turns it at once
## (local_input) while its position follows the server's. Its stats come live from the mothership,
## so run upgrades apply at once.
##
## Weapons: two cannons under the belly, one each side, fire in turn from a magazine (MAG rounds)
## that reloads by itself once it is empty. Every round heats the scout and so does the booster
## (Shift: BOOST times its top speed, straight ahead); the heat bleeds off by itself, but at full
## heat the cannons and the booster cut out until it is down to HEAT_RESUME. Four heat-seeking
## missiles hang under the wings, two each: the pilot holds the sight on an alien (RMB) until it
## locks on, and every click (LMB) fires one at it (request_missile). Docking reloads the missiles
## and the magazine and cools the scout down.

enum State { DOCKED, FLYING, DESTROYED }

const REBUILD_TIME := 25.0
const DOCK_RANGE := 15.0
const PICKUP_RANGE := 12.0
## Same as Projectiles.MASK_SCOUT (rock, enemies, minerals and hull-latched aliens). Kept local to
## avoid a cyclic constant dependency between the two scripts.
const AIM_MASK := 1 | 16 | 128 | 512
## The cannons: seconds between rounds (they fire in turn), round speed (m/s), the magazine and how
## long it takes to reload once empty. Both converge on whatever is under the sight, between
## CONVERGE_MIN and CONVERGE_MAX metres out.
const FIRE_INTERVAL := 0.12
const ROUND_SPEED := 170.0
const MAG := 80
const RELOAD_TIME := 2.5
const CONVERGE_MIN := 8.0
const CONVERGE_MAX := 120.0
## Heat (0..1): HEAT_SHOT a round and HEAT_BOOST a second of boosting, bleeding off at HEAT_COOL a
## second. At full heat the cannons and the booster cut out until it is down to HEAT_RESUME.
const HEAT_SHOT := 0.03
const HEAT_BOOST := 0.24
const HEAT_COOL := 0.12
const HEAT_RESUME := 0.45
## Flying: how fast the scout reaches the speed it is steered to (m/s²); the booster drives it at
## BOOST times its top speed along its nose, reached at BOOST_ACCEL.
const ACCEL := 32.0
const BOOST := 2.4
const BOOST_ACCEL := 48.0
## Missiles: two under each wing, one bit of `missiles` each in PYLONS order (the lowest left is
## fired first, so the sides take turns). Locking on takes LOCK_TIME seconds with an alien within
## LOCK_CONE (radians) of the sight and LOCK_RANGE metres. A missile deals MISSILE_DAMAGE (more with
## the scout's gun upgrades, see missile_damage()) and its blast reaches Projectiles.MISSILE_SPLASH;
## it drops off its pylon at LAUNCH_SPEED, then its motor takes over (Projectiles).
const MISSILES := 15
const LOCK_TIME := 1.0
const LOCK_CONE := 0.2
const LOCK_RANGE := 150.0
const MISSILE_DAMAGE := 150.0
const LAUNCH_SPEED := 14.0
## The scout banks into turns (BANK_TURN radians per rad/s of turn, at most BANK_MAX) and into
## sideways moves (BANK_SLIDE at full input).
const BANK_TURN := 0.12
const BANK_MAX := 0.32
const BANK_SLIDE := 0.22
## Hitting rock faster than 9 m/s hurts; one crash takes at most this share of the hull.
const CRASH_MAX := 0.45
## Below this share of its hull the scout is critical: the alarm sounds and the red lights pulse.
const HULL_CRITICAL := 0.3
## The fuselage's sections ([z, half width, half height, y centre], front to back): a low body with
## the cockpit's deck on top (the canopy stands on it, see ScoutCockpit.CANOPY) and the nose sloping
## away below the windscreen. Nothing hangs lower than the skids (0.57 m under the scout's middle,
## where the deck docks' pads are) and nothing stands higher than the canopy.
const BODY := [
	[-2.85, 0.14, 0.09, -0.19],
	[-2.3, 0.4, 0.18, -0.15],
	[-1.62, 0.62, 0.24, -0.2],
	[-0.5, 0.78, 0.255, -0.195],
	[0.6, 0.78, 0.255, -0.195],
	[1.2, 0.72, 0.3, -0.12],
	[2.0, 0.62, 0.3, -0.1],
	[2.5, 0.42, 0.22, -0.08],
]
const BODY_CHAMFER := 0.25
## The cannons' muzzles (left, right) under the belly.
const MUZZLES := [Vector3(-0.5, -0.49, -2.45), Vector3(0.5, -0.49, -2.45)]
## The missiles' middles under the wings, for each style: left outer, right outer, left inner,
## right inner.
const PYLONS := {
	"standard": [Vector3(-1.85, -0.36, 0.8), Vector3(1.85, -0.36, 0.8), Vector3(-1.15, -0.36, 0.85), Vector3(1.15, -0.36, 0.85)],
	"combat": [Vector3(-2.0, -0.36, 0.35), Vector3(2.0, -0.36, 0.35), Vector3(-1.25, -0.36, 0.62), Vector3(1.25, -0.36, 0.62)],
}

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
## The heat (0..1) and whether the scout overheated (cannons and booster out until it cools to
## HEAT_RESUME), the rounds left in the magazine and the seconds left of its reload, the missiles
## left (bits, see MISSILES) and whether the booster burns.
var heat := 0.0
var overheat := false
var ammo := MAG
var reload_left := 0.0
var missiles := MISSILES
var boosting := false

## The scout bay station that launches this scout ("scout", "scout2") and its index.
var station_id := "scout"
var index := 0
## "standard" or "combat" (the Vanguard's).
var style := "standard"
## The cockpit and its instruments.
var cockpit: ScoutCockpit
## The pilot's latest input on their own client, so the scout turns there at once (set by the
## CrewMember flying it).
var local_input: Dictionary = {}
var _model: Node3D
var _parts: Dictionary = {}
var _glow_mat: StandardMaterial3D
var _head_light: SpotLight3D
var _fill_light: OmniLight3D
var _audio: AudioStreamPlayer3D
var _boost_audio: AudioStreamPlayer3D
var _since_sync := 0.0
var _input: Dictionary = {}
var _fire_cd := 0.0
var _side := 1
var _bump_cd := 0.0
## The aim's last yaw (INF: start afresh) and how fast it turns (rad/s, smoothed), for the bank.
var _last_yaw := INF
var _turn := 0.0
var _was_flying := false
## The cannons' muzzle flashes and their lights (left, right), and how long each still shows.
var _flashes: Array[MeshInstance3D] = []
var _flash_lights: Array[OmniLight3D] = []
var _flash_t: Array[float] = [0.0, 0.0]
## The booster's flame for everyone to see (0..1).
var _boost_fx := 0.0
## The pilot as everyone else sees them in the cockpit, and their visor (in their colour).
var _figure: Node3D
var _visor_mat: StandardMaterial3D


## Build a scout's visual model under `root` (also used by the homebase display): the fuselage, the
## canopy and the cockpit inside it (ScoutCockpit.build_shell), the cannons, wings with their
## missiles, the engines and the skids. Returns {"glow_mat", "missiles" (the four on their pylons,
## in PYLONS order), "glass" (the canopy)}.
static func build_model(root: Node3D, model_style := "standard") -> Dictionary:
	var combat := model_style == "combat"
	var body_mat := Models.panel_mat(Color(0.25, 0.27, 0.31), 0.6, 0.38, 0.8) if combat else Models.panel_mat(Color(0.95, 0.55, 0.16), 0.4, 0.45, 0.8)
	var trim := Models.mat(Color(0.85, 0.16, 0.12), 0.35, 0.45) if combat else Models.mat(Color(0.2, 0.21, 0.23), 0.5, 0.5)
	var steel := Models.mat(Color(0.55, 0.57, 0.6), 0.75, 0.3)
	var grey := Models.mat(Color(0.5, 0.52, 0.56), 0.6, 0.4)
	var dark := Models.mat(Color(0.12, 0.13, 0.15), 0.6, 0.5)
	var hull := MeshInstance3D.new()
	hull.mesh = Models.loft(BODY, BODY_CHAMFER)
	hull.material_override = body_mat
	root.add_child(hull)
	var b := Models.Batch.new()
	# A stripe down the nose and the spine.
	b.box(Vector3(0, -0.11, -2.4), Vector3(0.14, 0.04, 0.9), trim, Vector3(-13, 0, 0))
	b.box(Vector3(0, 0.22, 1.6), Vector3(0.14, 0.04, 1.6), trim, Vector3(3, 0, 0))
	for side: float in [-1.0, 1.0]:
		# The cannons, built into fairings along the belly's edges, their barrels out under the nose.
		b.box(Vector3(side * 0.5, -0.47, -1.25), Vector3(0.18, 0.12, 1.3), dark)
		b.cyl(Vector3(side * 0.5, -0.49, -2.1), 0.045, 0.75, steel, Vector3(90, 0, 0), -1.0, 10)
		b.cyl(Vector3(side * 0.5, -0.49, -2.42), 0.06, 0.08, dark, Vector3(90, 0, 0), -1.0, 10)
		# Wings, each with two missiles on pylons underneath.
		if combat:
			var wing := PackedVector2Array([Vector2(side * 0.72, 1.35), Vector2(side * 2.7, 0.3), Vector2(side * 2.7, -0.25), Vector2(side * 0.72, 0.4)])
			b.add(Models.prism(wing, -0.24, -0.14), Transform3D.IDENTITY, body_mat)
			b.beam(Vector3(side * 0.76, -0.19, 0.38), Vector3(side * 2.7, -0.19, -0.27), 0.1, 0.12, trim)
			b.sphere(Vector3(side * 2.72, -0.19, -0.25), 0.07, Models.emissive(Color(1, 0.2, 0.15) if side < 0 else Color(0.2, 1, 0.3), 5.0))
			# Canted tail fins.
			b.box(Vector3(side * 0.42, 0.38, 2.05), Vector3(0.07, 0.5, 0.7), body_mat, Vector3(-25, 0, side * -18.0))
			b.box(Vector3(side * 0.46, 0.58, 2.15), Vector3(0.08, 0.08, 0.4), trim, Vector3(-25, 0, side * -18.0))
		else:
			b.box(Vector3(side * 1.5, -0.2, 0.9), Vector3(1.6, 0.1, 1.2), grey, Vector3(0, side * -6.0, side * 4.0))
			b.box(Vector3(side * 1.4, -0.14, 0.92), Vector3(1.0, 0.04, 0.16), Models.mat(Color(0.95, 0.55, 0.16), 0.4, 0.45), Vector3(0, side * -6.0, side * 4.0))
			b.box(Vector3(side * 2.32, -0.08, 1.0), Vector3(0.12, 0.42, 0.85), dark)
			b.sphere(Vector3(side * 2.36, 0.18, 0.95), 0.07, Models.emissive(Color(1, 0.2, 0.15) if side < 0 else Color(0.2, 1, 0.3), 5.0))
		for pylon: Vector3 in PYLONS[model_style]:
			if signf(pylon.x) == side:
				b.box(pylon + Vector3(0, 0.13, 0), Vector3(0.06, 0.12, 0.55), dark)
		# Engines.
		b.cyl(Vector3(side * 0.46, -0.02, 2.2), 0.3, 1.0, steel, Vector3(90, 0, 0), 0.25)
		b.cyl(Vector3(side * 0.46, -0.02, 1.66), 0.33, 0.08, dark, Vector3(90, 0, 0))
		# Landing skids, between the cannons.
		b.box(Vector3(side * 0.26, -0.53, 0.2), Vector3(0.07, 0.08, 2.3), dark)
		for z: float in [-0.7, 1.0]:
			b.box(Vector3(side * 0.26, -0.48, z), Vector3(0.05, 0.1, 0.05), dark)
	if not combat:
		# The tail fin on the spine.
		b.box(Vector3(0, 0.42, 2.1), Vector3(0.08, 0.4, 0.9), dark, Vector3(-22, 0, 0))
	b.cyl(Vector3(0.24, 0.42, 1.35), 0.015, 0.45, grey)
	b.commit(root)
	var glow_mat := StandardMaterial3D.new()
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_mat.albedo_color = Color(0.4, 0.85, 1.0)
	for side: float in [-1.0, 1.0]:
		Models.cylinder(root, Vector3(side * 0.46, -0.02, 2.72), 0.2, 0.05, glow_mat, Vector3(90, 0, 0))
	var parts := ScoutCockpit.build_shell(root, body_mat)
	parts["glow_mat"] = glow_mat
	var held: Array[Node3D] = []
	for pylon: Vector3 in PYLONS[model_style]:
		var m := Node3D.new()
		m.position = pylon
		root.add_child(m)
		Projectiles.missile_body(m, true)
		held.append(m)
	parts["missiles"] = held
	return parts


func _init() -> void:
	NetUtil.add_sync(self, ["net_pos", "net_vel", "net_rot"],
		["state", "hp", "max_hp", "cargo", "max_cargo", "rebuild", "pilot", "heat", "overheat", "ammo", "reload_left", "missiles", "boosting"],
		1.0 / 30.0)


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
	_parts = build_model(_model, style)
	_glow_mat = _parts["glow_mat"]
	cockpit = ScoutCockpit.new()
	cockpit.name = "Cockpit"
	_model.add_child(cockpit)
	cockpit.build(self, _parts["glass"] as MeshInstance3D)
	_head_light = SpotLight3D.new()
	_head_light.position = Vector3(0, -0.12, -2.95)
	_head_light.spot_range = 70.0
	_head_light.spot_angle = 38.0
	_head_light.spot_attenuation = 0.5
	_head_light.light_energy = 7.0
	_head_light.light_color = Color(1.0, 0.92, 0.8)
	_head_light.light_projector = Models.light_cookie("headlight")
	ShipBuilder.configure_shadow(_head_light)
	add_child(_head_light)
	# The fill light hangs out ahead of the nose: it lights the rock round the scout, not the
	# cockpit.
	_fill_light = OmniLight3D.new()
	_fill_light.position = Vector3(0, 0.6, -4.5)
	_fill_light.omni_range = 16.0
	_fill_light.light_energy = 0.8
	_fill_light.light_color = Color(0.9, 0.8, 0.7)
	_fill_light.light_cull_mask &= ~Game.VIS_GLASS
	add_child(_fill_light)
	for side in 2:
		var flash := MeshInstance3D.new()
		flash.mesh = GunPod.flash_mesh()
		flash.material_override = GunPod.flash_material()
		flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flash.position = MUZZLES[side]
		flash.scale = Vector3.ONE * 0.8
		flash.visible = false
		_model.add_child(flash)
		_flashes.append(flash)
		# The flash's light, out in front of the nose: it lights up the nose and the rock ahead, so
		# the pilot sees the cannons fire.
		var light := OmniLight3D.new()
		light.position = MUZZLES[side] + Vector3(0, 0.4, -0.55)
		light.omni_range = 6.0
		light.light_energy = 0.0
		light.light_color = Color(1.0, 0.68, 0.32)
		_model.add_child(light)
		_flash_lights.append(light)
	_build_figure()
	_audio = AudioStreamPlayer3D.new()
	_audio.stream = Sfx.stream("scout_loop")
	_audio.volume_db = -10.0
	_audio.unit_size = 10.0
	add_child(_audio)
	Sfx.track(_audio)
	_boost_audio = AudioStreamPlayer3D.new()
	_boost_audio.stream = Sfx.stream("boost_loop")
	_boost_audio.position = Vector3(0, 0, 2.2)
	_boost_audio.unit_size = 12.0
	add_child(_boost_audio)
	Sfx.track(_boost_audio)
	if not multiplayer.is_server():
		($Sync as MultiplayerSynchronizer).synchronized.connect(func(): _since_sync = 0.0)


## The pilot in the cockpit as everyone else sees them: shoulders and a helmet with a visor in their
## colour (hidden from the pilot themselves: they look out through it).
func _build_figure() -> void:
	_figure = Node3D.new()
	_figure.visible = false
	_model.add_child(_figure)
	var suit := Models.mat(Color(0.3, 0.32, 0.3), 0.2, 0.7)
	Models.capsule(_figure, Vector3(0, 0.12, -0.42), 0.18, 0.5, suit)
	Models.sphere(_figure, Vector3(0, 0.45, -0.45), 0.13, Models.mat(Color(0.78, 0.79, 0.8), 0.3, 0.4))
	_visor_mat = StandardMaterial3D.new()
	_visor_mat.albedo_color = Color(0.05, 0.08, 0.1)
	_visor_mat.emission_enabled = true
	_visor_mat.emission_energy_multiplier = 1.5
	Models.sphere(_figure, Vector3(0, 0.45, -0.54), 0.1, _visor_mat, Vector3(1.0, 0.6, 0.7))


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


## The scout's top speed (m/s) without the booster.
func top_speed() -> float:
	return maxf(_stat("scout_speed"), 1.0)


## A missile's damage: MISSILE_DAMAGE, scaled like the cannons' rounds (combat scouts and the scout
## gun upgrades; 7 is a standard scout's round, see Game.ship_stats()).
func missile_damage() -> float:
	return MISSILE_DAMAGE * _stat("scout_damage") / 7.0


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


## The local crew member is flying this scout.
func local_pilot() -> bool:
	return state == State.FLYING and pilot != 0 and pilot == multiplayer.get_unique_id()


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
	_update_visuals(delta)


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
				_rearm()
				ship.notify.rpc("Scout rebuilt and ready in the bay", 0)
		State.FLYING:
			_fly(delta)


func _fly(delta: float) -> void:
	var mv: Vector3 = _input.get("move", Vector3.ZERO)
	_steer(delta, _input)
	var aim := Basis.from_euler(Vector3(float(_input.get("pitch", 0.0)), float(_input.get("yaw", global_rotation.y)), 0.0))
	var speed := top_speed()
	boosting = bool(_input.get("boost", false)) and not overheat
	# The booster drives the scout straight ahead, along its nose.
	var desired := -global_basis.z * speed * BOOST if boosting else aim * Vector3(mv.x, mv.y, -mv.z).limit_length(1.0) * speed
	velocity = velocity.move_toward(desired, (BOOST_ACCEL if boosting else ACCEL) * delta)
	var pre := velocity
	move_and_slide()
	_bump_cd = maxf(0.0, _bump_cd - delta)
	for i in get_slide_collision_count():
		var impact := -pre.dot(get_slide_collision(i).get_normal())
		if impact > 9.0 and _bump_cd <= 0.0:
			_bump_cd = 0.5
			take_damage(minf((impact - 7.0) * 2.0, max_hp * CRASH_MAX), {"source": "impact"})
	# Heat: the booster and every round heat the scout and it bleeds off by itself; at full heat
	# the cannons and the booster cut out until it has cooled down.
	heat = clampf(heat + ((HEAT_BOOST if boosting else 0.0) - HEAT_COOL) * delta, 0.0, 1.0)
	if overheat and heat <= HEAT_RESUME:
		overheat = false
	if reload_left > 0.0:
		reload_left = maxf(0.0, reload_left - delta)
		if reload_left <= 0.0:
			ammo = MAG
			_fx.rpc("reloaded")
	_fire_cd = maxf(0.0, _fire_cd - delta)
	if _input.get("fire", false) and _fire_cd <= 0.0 and not overheat and reload_left <= 0.0:
		_fire_cd = FIRE_INTERVAL
		_side = 1 - _side
		_fire_round(_side)
	if heat >= 1.0 and not overheat:
		overheat = true
		boosting = false
		_fx.rpc("overheat")


## Fire a round from cannon `side` (0 left, 1 right) at whatever is under the sight.
func _fire_round(side: int) -> void:
	var eye := to_global(ScoutCockpit.EYE)
	var fwd := -global_basis.z
	var ray := PhysicsRayQueryParameters3D.create(eye, eye + fwd * CONVERGE_MAX, AIM_MASK)
	ray.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	var reach := eye.distance_to(hit["position"]) if not hit.is_empty() else CONVERGE_MAX
	var focus := eye + fwd * maxf(reach, CONVERGE_MIN)
	var muzzle := to_global(MUZZLES[side])
	var dir := Mothership.scatter(focus - muzzle, deg_to_rad(Mothership.SCOUT_SPREAD))
	Game.mission.projectiles.fire("scout", muzzle, dir * ROUND_SPEED + velocity, _stat("scout_damage"))
	heat = minf(1.0, heat + HEAT_SHOT)
	ammo -= 1
	if ammo <= 0:
		reload_left = RELOAD_TIME
		_fx.rpc("reload")
	_fx_shot.rpc(side)


## Turn towards the pilot's aim, banking into turns and sideways moves (the server's simulation,
## and the pilot's own client at once).
func _steer(delta: float, input: Dictionary) -> void:
	var yaw := float(input.get("yaw", global_rotation.y))
	var pitch := float(input.get("pitch", 0.0))
	var mv: Vector3 = input.get("move", Vector3.ZERO)
	if _last_yaw == INF:
		_last_yaw = yaw
		_turn = 0.0
	_turn = lerpf(_turn, angle_difference(_last_yaw, yaw) / maxf(delta, 0.001), NetUtil.smooth(6.0, delta))
	_last_yaw = yaw
	var bank := clampf(-_turn * BANK_TURN, -BANK_MAX, BANK_MAX) + mv.x * BANK_SLIDE
	var want := Basis.from_euler(Vector3(pitch, yaw, 0.0)) * Basis(Vector3.FORWARD, bank)
	var q := global_basis.get_rotation_quaternion().slerp(want.get_rotation_quaternion(), NetUtil.smooth(10.0, delta))
	global_basis = Basis(q)


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
	# The pilot's own client turns the scout from their input at once; everyone else follows the
	# server.
	if local_pilot() and not local_input.is_empty():
		_steer(delta, local_input)
	else:
		var q := global_basis.get_rotation_quaternion().slerp(Quaternion.from_euler(net_rot), NetUtil.smooth(14.0, delta))
		global_basis = Basis(q)


func _update_visuals(delta: float) -> void:
	_model.visible = state != State.DESTROYED
	var flying := state == State.FLYING
	if flying != _was_flying:
		_was_flying = flying
		_last_yaw = INF
		if not flying:
			local_input = {}
	_head_light.visible = flying
	_fill_light.visible = flying
	var speed := (velocity if multiplayer.is_server() else net_vel).length()
	var p := clampf(speed / 20.0, 0.0, 1.0) if flying else 0.0
	_boost_fx = move_toward(_boost_fx, 1.0 if flying and boosting else 0.0, delta * 3.0)
	_glow_mat.albedo_color = Color(0.2, 0.35, 0.45).lerp(Color(1.2, 2.0, 2.6), 0.2 + 0.8 * p if flying else 0.0).lerp(Color(2.8, 1.7, 0.9), _boost_fx)
	if flying != _audio.playing:
		if flying:
			_audio.play()
		else:
			_audio.stop()
	if flying:
		_audio.pitch_scale = 0.8 + p * 0.6 + _boost_fx * 0.25
	if _boost_fx > 0.02:
		if not _boost_audio.playing:
			_boost_audio.play()
		_boost_audio.volume_db = linear_to_db(_boost_fx) - 3.0
	elif _boost_audio.playing:
		_boost_audio.stop()
	# The missiles on their pylons, and the muzzle flashes fading.
	var held: Array = _parts["missiles"]
	for i in held.size():
		(held[i] as Node3D).visible = missiles & (1 << i) != 0
	for side in 2:
		if _flash_t[side] > 0.0:
			_flash_t[side] -= delta
			if _flash_t[side] <= 0.0:
				_flashes[side].visible = false
		_flash_lights[side].light_energy = maxf(0.0, _flash_lights[side].light_energy - delta * 60.0)
	# Everyone else sees the pilot in the cockpit.
	var crew: CrewMember = null
	if flying and pilot != 0 and _ship():
		crew = _ship().crew_root.get_node_or_null(str(pilot)) as CrewMember
	_figure.visible = crew != null and not local_pilot()
	if _figure.visible:
		_visor_mat.emission = crew.color


# --- Server API --------------------------------------------------------------------------------

func launch(pid: int) -> void:
	var ship := _ship()
	state = State.FLYING
	pilot = pid
	boosting = false
	global_transform = dock_transform()
	velocity = ship.velocity + ship.global_basis * ship.dock_launch(station_id)
	var up := ship.dock_launch(station_id).y > 0.0
	_input = {"yaw": ship.rotation.y, "pitch": 0.15 if up else -0.25}
	_last_yaw = INF
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
	_fx_hit.rpc(amount)
	if hp <= 0.0:
		hp = 0.0
		state = State.DESTROYED
		rebuild = REBUILD_TIME
		cargo = 0.0
		boosting = false
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
	boosting = false
	global_transform = dock_transform()
	reset_physics_interpolation()
	if cargo > 0.0:
		ship.add_fuel(cargo)
		cargo = 0.0
	_rearm()
	_fx.rpc("dock")
	var pid := pilot
	pilot = 0
	ship.release_peer(pid)


## Docked (or rebuilt): every missile back on its pylon, a full magazine, the heat gone.
func _rearm() -> void:
	missiles = MISSILES
	ammo = MAG
	reload_left = 0.0
	heat = 0.0
	overheat = false


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


## The pilot fires a missile at the alien they locked on to (by its node name): the outer ones
## first, left then right, then the inner ones. The pilot's client checked the lock; the server
## only makes sure the target is still about and roughly ahead.
@rpc("any_peer", "call_local", "reliable")
func request_missile(target_name: String) -> void:
	if not multiplayer.is_server() or Game.sender_id() != pilot or state != State.FLYING or missiles == 0:
		return
	var target := (Game.mission as MissionLevel).enemy_root.get_node_or_null(target_name) as Alien
	if target == null or target.hp <= 0.0:
		return
	var to := target.global_position - global_position
	if to.length() > LOCK_RANGE * 1.3 or (-global_basis.z).angle_to(to) > LOCK_CONE * 3.0:
		return
	var slot := 0
	while missiles & (1 << slot) == 0:
		slot += 1
	missiles &= ~(1 << slot)
	var at := to_global(PYLONS[style][slot])
	Game.mission.projectiles.fire_missile(at, velocity - global_basis.z * LAUNCH_SPEED - global_basis.y * 2.0, target, missile_damage())
	_fx.rpc("missile%d" % slot)


# --- Effects (every peer) ----------------------------------------------------------------------

## A scout sound: in 2D for its pilot, from the scout (or `at`) for everyone else.
func _sound(id: String, db: float, pitch := 1.0, at: Variant = null) -> void:
	if local_pilot():
		Sfx.play(id, null, db - 3.0, pitch)
	elif is_inside_tree():
		Sfx.play(id, at if at is Vector3 else global_position, db, pitch)


## Cannon `side` fired: its muzzle flash and the bang (the pilot's view kicks).
@rpc("authority", "call_local", "unreliable")
func _fx_shot(side: int) -> void:
	if side < 0 or side >= _flashes.size():
		return
	_flash_t[side] = 0.05
	var flash := _flashes[side]
	flash.visible = true
	flash.rotation = Vector3(0, 0, randf() * TAU)
	flash.reset_physics_interpolation()
	_flash_lights[side].light_energy = randf_range(2.2, 3.2)
	if local_pilot():
		Sfx.play("scout_gun", null, -10.0, randf_range(0.95, 1.05))
		cockpit.kick()
	elif is_inside_tree():
		Sfx.play("scout_gun", to_global(MUZZLES[side]), -2.0)


## The scout was hit: sparks off the hull, a thud, and the pilot is thrown about.
@rpc("authority", "call_local", "unreliable")
func _fx_hit(amount: float) -> void:
	if not is_inside_tree():
		return
	var at := to_global(Vector3(randf_range(-0.7, 0.7), randf_range(-0.3, 0.4), randf_range(-2.0, 1.8)))
	Fx.sparks(at, Color(1.0, 0.6, 0.2), 10, 6.0)
	_sound("hull_hit", -3.0, 1.3, at)
	if local_pilot():
		cockpit.jolt(amount)


@rpc("authority", "call_local", "reliable")
func _fx(kind: String) -> void:
	match kind:
		"launch":
			_sound("launch", 0.0)
		"dock":
			Sfx.play("dock", global_position, 0.0)
			Fx.ring(global_position, Vector3.UP, Color(0.4, 1.0, 0.6), 4.0, 0.5)
		"reload":
			_sound("belt_out", -6.0, 1.35)
		"reloaded":
			_sound("belt_in", -4.0, 1.35)
		"overheat":
			_sound("overheat", -2.0, 0.8)
			_sound("sizzle", -6.0)
		"missile0", "missile1", "missile2", "missile3":
			var slot := int(kind.right(1))
			var at := to_global(PYLONS[style][slot])
			_sound("missile_launch", 0.0, 1.0, at)
			Fx.flash(at + global_basis.z * 0.6, Color(1.0, 0.6, 0.3), 3.0, 6.0, 0.12)
