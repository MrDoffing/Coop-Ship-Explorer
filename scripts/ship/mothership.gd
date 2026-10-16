class_name Mothership
extends CharacterBody3D
## The crew's ship. Flight, systems, weapons and damage are simulated on the server; clients get
## the state through the synchronizer and drive stations by sending input to the server.
##
## The ship type (see ShipTypes) decides its stations: one pilot seat plus any number of guns,
## mining lasers and scout bays, and its auto turret slots. Crew members and boarding aliens live
## inside it (Interior/Crew, Interior/Boarders) in ship-local space, so they ride along with its
## movement. Damage hits the energy shield first; once the shield breaks, the hull takes damage and
## part of it spills over into the engine and weapon systems, which go offline at zero until the
## crew repairs them. The hull cannot be repaired in flight, only with repair kits from a shop.
##
## Waystations sit in the tunnel between two bulkheads. The pilot requests landing (L) and the ship
## flies a scripted approach through the open entrance gate onto the pad; the entrance then seals
## behind it. While docked it is safe, refuels, and the cargo ramp opens so the crew can buy supplies
## in the shop and carry them aboard. On liftoff the exit gate opens, and it seals again once the
## ship is through, so there is no way back. Supplies only last for the current dive.

signal destroyed

enum Dock { FLYING, APPROACH, LANDED, LIFTOFF }

const WEAPON_DEFS := {
	"pulse": {"cooldown": 0.15, "speed": 150.0, "damage": 11.0, "pellets": 1, "spread": 0.6, "kind": "pulse"},
	"flak": {"cooldown": 0.75, "speed": 120.0, "damage": 6.0, "pellets": 8, "spread": 4.5, "kind": "flak"},
	"plasma": {"cooldown": 0.95, "speed": 60.0, "damage": 34.0, "pellets": 1, "spread": 0.3, "kind": "plasma"},
	"rail": {"cooldown": 1.35, "speed": 0.0, "damage": 75.0, "pellets": 1, "spread": 0.0, "kind": "rail"},
}
## Systems come back online once repaired to this level.
const REBOOT_HP := 50.0
## Emergency blast: a shockwave from the shield emitters that hits everything nearby (damage falls
## off with distance). It drains the shield and costs hull and fuel.
const BLAST_COOLDOWN := 15.0
const BLAST_RADIUS := 42.0
const BLAST_DAMAGE := 420.0
const BLAST_HULL_COST := 0.06
const BLAST_FUEL_COST := 12.0
## Waystations: landing is possible within LAND_RANGE of a station's entrance gate (or inside its
## hall). Docking flight speeds, ramp and landing gear travel rates, and what the station tops up
## per second while docked.
const LAND_RANGE := 110.0
const DOCK_SPEED := 11.0
const DOCK_SPEED_SLOW := 7.0
const DOCK_TURN_RATE := 0.7
const DOCK_DESCENT := 3.0
const RAMP_RATE := 0.7
const GEAR_RATE := 0.8
const DOCK_REFUEL := 9.0
const DOCK_SHIELD := 25.0
## Bulkhead doors move this much (open fraction) per second.
const GATE_RATE := 0.22
## Braking (m/s²) the flight computer allows for when it stops the ship short of a sealed bulkhead.
const BRAKE_DECEL := 2.0
## Auto turrets: reach, turn rate, rate of fire and damage per bolt.
const AUTO_RANGE := 75.0
const AUTO_TURN := 3.0
const AUTO_COOLDOWN := 0.32
const AUTO_DAMAGE := 7.0
const AUTO_SPEED := 150.0

const SHIELD_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 tint : source_color = vec4(0.3, 0.8, 1.0, 1.0);
uniform float intensity = 0.0;
uniform float base = 0.04;
void fragment() {
	float fres = pow(1.0 - abs(dot(NORMAL, VIEW)), 2.5);
	float bands = 0.5 + 0.5 * sin(UV.y * 90.0 + TIME * 3.0);
	float a = (base + intensity * 0.45) * fres * (0.7 + 0.3 * bands) + intensity * 0.025;
	ALBEDO = tint.rgb * (1.0 + intensity);
	ALPHA = clamp(a, 0.0, 1.0);
}
"""

## The ship type (ShipTypes id), from the spawn data.
var ship_type := "prospector"
## Its layout (ShipTypes.get_type), set up before the ship enters the tree.
var layout: Dictionary = {}

# --- Replicated state (server authority) ---
var net_pos := Vector3.ZERO
var net_vel := Vector3.ZERO
var net_yaw := 0.0
## Aim of every gun and mining laser, in layout["aimables"] order.
var aims := PackedVector2Array()
## Where each mining laser's beam ends (layout["lasers"] order) and which ones fire (bit mask).
var beam_ends := PackedVector3Array()
var beams := 0
## Gun station -> mounted weapon (Game.GUNS id).
var gun_weapons: Dictionary = {}
var hull := 400.0
var shield := 120.0
var shield_down := false
var shield_reboot := 0.0
var engine_hp := 100.0
var weapons_hp := 100.0
var engine_online := true
var weapons_online := true
var fuel := 100.0
var throttle := 0.0
var autopilot := true
var occupants: Dictionary = {}
## Credits mined this dive: spent in waystation shops, gone when the dive ends.
var credits := 0
var ore: Dictionary = {}
var depth := 0.0
var alive := true
var boarders := 0
var frozen := true
## Seconds until the emergency blast can fire again.
var blast_cd := 0.0
## Waystation docking state and the station (index) the ship is docking at, or -1.
var landing := Dock.FLYING
var station_k := -1
## The waystation the ship last landed at (-1: none yet) and how far its entrance and exit
## bulkheads are open (0 sealed .. 1 open). Stations further on are open to enter; earlier ones
## stay sealed.
var gate_k := -1
var gate_entry := 1.0
var gate_exit := 0.0
## Waystations landed at this dive.
var stations_docked := 0
## Supplies installed this dive (item id -> count), auto turrets installed in the turret slots, and
## the aim of every turret hardpoint.
var run_mods: Dictionary = {}
var autocannons := 0
var auto_aim := PackedVector2Array()
## Cargo ramp (0 closed .. 1 open) and landing legs (0 folded .. 1 down), animated on every peer.
var ramp := 0.0
var gear := 0.0

var stats: Dictionary = {}
## Print every damage event (development aid, toggled by the autotest).
var debug_damage := false
var max_hull := 400.0
var max_shield := 120.0
var max_fuel := 100.0

# --- Local nodes ---
var exterior: Node3D
var interior: Node3D
var interior_body: StaticBody3D
var crew_root: Node3D
var boarder_root: Node3D
var cargo_root: Node3D
var crew_spawner: MultiplayerSpawner
var boarder_spawner: MultiplayerSpawner
var cargo_spawner: MultiplayerSpawner
## Station id -> Turret for every gun and mining laser.
var turrets: Dictionary = {}
var panels: Array = []
var nav: AStar3D
var _ext: Dictionary = {}
var _int: Dictionary = {}
var _shield_mat: ShaderMaterial
var _shield_flash := 0.0
## Laser station -> {"mesh", "light", "audio"}.
var _beams: Dictionary = {}
var _engine_audio: AudioStreamPlayer3D
var _since_sync := 0.0
var _alarm_t := 0.0
var _alarm_sound_t := 0.0
var _ramp_body: StaticBody3D
var _hub_text := ""
## How far the ship reaches ahead of and behind its origin (from the collision boxes).
var _nose := 14.0
var _stern := 14.5

# --- Server only ---
var _inputs: Dictionary = {}
var _fire_cd: Dictionary = {}
var _time := 0.0
var _last_hit := -100.0
var _yaw_rate := 0.0
var _bump_cd := 0.0
var _fx_cd := 0.0
var _hull_claims: Dictionary = {}
var _hatch_claims: Dictionary = {}
var _boarder_seq := 0
var _low_fuel_warned := false
var _no_fuel_warned := false
## Docking flight: remaining keyframes {pos, yaw, time} and progress through the current one.
var _dock_keys: Array = []
var _dock_t := 0.0
var _dock_from := Vector3.ZERO
var _dock_from_yaw := 0.0
var _dock_wait := 0.0
## The exit bulkhead of station gate_k: 0 sealed, 1 opening for liftoff, 2 waiting for the ship
## (and scouts) to clear it, 3 sealed for good.
var _exit_state := 0
## Waystation whose "sealed bulkhead ahead" warning was already shown.
var _brake_warned := -1
## Second L press within this time leaves purchased crates behind.
var _liftoff_confirm := -100.0
## Crates still at each waystation (index -> [{item, price, pos (station-local), yaw}]).
var _station_cargo: Dictionary = {}
var _crate_seq := 0
var _auto_cd: Array[float] = []
var _auto_target: Array[int] = []
var _auto_retarget := 0.0


func _init() -> void:
	NetUtil.add_sync(self,
		["net_pos", "net_vel", "net_yaw", "aims", "beam_ends"],
		["hull", "shield", "shield_down", "shield_reboot", "engine_hp", "weapons_hp", "engine_online",
		"weapons_online", "fuel", "throttle", "autopilot", "occupants", "beams", "gun_weapons", "credits", "ore",
		"depth", "alive", "boarders", "frozen", "blast_cd", "landing", "station_k", "gate_k", "gate_entry",
		"gate_exit", "stations_docked", "stats", "max_hull", "max_shield", "max_fuel", "run_mods", "autocannons",
		"auto_aim"], 1.0 / 30.0)


func setup(data: Dictionary) -> void:
	name = "Mothership"
	stats = data["stats"]
	ship_type = str(data.get("ship", stats.get("ship", "prospector")))
	layout = ShipTypes.get_type(ship_type)
	max_hull = stats["max_hull"]
	max_shield = stats["max_shield"]
	max_fuel = stats["max_fuel"]
	hull = max_hull
	shield = max_shield
	fuel = max_fuel
	position = data.get("pos", Vector3.ZERO)
	net_pos = position
	var aimables: Array = layout["aimables"]
	aims.resize(aimables.size())
	for i in aimables.size():
		aims[i] = Vector2(0.0, -0.35) if station_kind(aimables[i]) == "laser" else Vector2.ZERO
	beam_ends.resize((layout["lasers"] as Array).size())
	var w := {}
	for g: String in layout["guns"]:
		w[g] = "pulse"
		_fire_cd[g] = 0.0
	gun_weapons = w
	var mounts := (layout["hardpoints"] as Array).size()
	auto_aim.resize(mounts)
	_auto_cd.resize(mounts)
	_auto_cd.fill(0.0)
	_auto_target.resize(mounts)
	_auto_target.fill(0)
	for bx: Array in layout["boxes"]:
		var c: Vector3 = bx[0]
		var s: Vector3 = bx[1]
		_nose = maxf(_nose, -(c.z - s.z * 0.5))
		_stern = maxf(_stern, c.z + s.z * 0.5)


func _ready() -> void:
	process_physics_priority = -20
	collision_layer = Game.LAYER_HULL
	collision_mask = Game.LAYER_CAVE
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	_add_hull_shapes()
	exterior = Node3D.new()
	exterior.name = "Exterior"
	add_child(exterior)
	_ext = ShipBuilder.build_exterior(exterior, ship_type)
	turrets = _ext["turrets"]
	interior = Node3D.new()
	interior.name = "Interior"
	add_child(interior)
	_int = ShipBuilder.build_interior(interior, ship_type)
	interior_body = _int["body"]
	panels = _int["panels"]
	crew_root = Node3D.new()
	crew_root.name = "Crew"
	interior.add_child(crew_root)
	boarder_root = Node3D.new()
	boarder_root.name = "Boarders"
	interior.add_child(boarder_root)
	cargo_root = Node3D.new()
	cargo_root.name = "Cargo"
	interior.add_child(cargo_root)
	_ramp_body = _int["ramp_body"]
	crew_spawner = NetUtil.add_spawner(self, "CrewSpawner", crew_root, _spawn_crew)
	boarder_spawner = NetUtil.add_spawner(self, "BoarderSpawner", boarder_root, _spawn_boarder)
	cargo_spawner = NetUtil.add_spawner(self, "CargoSpawner", cargo_root, _spawn_crate)
	nav = ShipBuilder.build_nav()
	_build_shield()
	_build_beams()
	_build_audio()
	if not multiplayer.is_server():
		($Sync as MultiplayerSynchronizer).synchronized.connect(func(): _since_sync = 0.0)


func _exit_tree() -> void:
	if Game.mission and Game.mission.get("ship") == self:
		Game.mission.set("ship", null)


func _add_hull_shapes() -> void:
	for bx: Array in layout["boxes"]:
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = bx[1]
		cs.shape = box
		cs.position = bx[0]
		add_child(cs)


func _build_shield() -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 48
	sm.rings = 24
	mi.mesh = sm
	var shader := Shader.new()
	shader.code = SHIELD_SHADER
	_shield_mat = ShaderMaterial.new()
	_shield_mat.shader = shader
	mi.material_override = _shield_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = shield_center()
	mi.scale = shield_radii()
	add_child(mi)


func _build_beams() -> void:
	for id: String in layout["lasers"]:
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.08 if style_of(id) != "drill" else 0.12
		cm.bottom_radius = cm.top_radius
		cm.height = 1.0
		cm.radial_segments = 8
		cm.rings = 1
		mi.mesh = cm
		mi.material_override = Models.glow(Color(2.0, 0.85, 0.3, 1.0))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		add_child(mi)
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.55, 0.2)
		light.omni_range = 9.0
		light.light_energy = 0.0
		add_child(light)
		var audio := AudioStreamPlayer3D.new()
		audio.stream = Sfx.stream("mine_loop")
		audio.position = console(id)["pos"]
		audio.volume_db = -13.0
		audio.unit_size = 8.0
		audio.max_distance = 120.0
		add_child(audio)
		_beams[id] = {"mesh": mi, "light": light, "audio": audio}


func _build_audio() -> void:
	_engine_audio = AudioStreamPlayer3D.new()
	_engine_audio.stream = Sfx.stream("engine_loop")
	_engine_audio.position = Vector3(0, 1.5, 9.0)
	_engine_audio.volume_db = -8.0
	_engine_audio.unit_size = 20.0
	_engine_audio.autoplay = true
	add_child(_engine_audio)


func _spawn_crew(data: Variant) -> Node:
	var c := CrewMember.new()
	c.setup(data)
	return c


func _spawn_boarder(data: Variant) -> Node:
	var b := Boarder.new()
	b.setup(data)
	return b


func _spawn_crate(data: Variant) -> Node:
	var c := SupplyCrate.new()
	c.setup(data)
	return c


# --- Layout ------------------------------------------------------------------------------------

## The layout entry of a station (seat, console, kind, mount...), or {}.
func console(id: String) -> Dictionary:
	return (layout["by_id"] as Dictionary).get(id, {})


func has_station(id: String) -> bool:
	return (layout["by_id"] as Dictionary).has(id)


func station_name(id: String) -> String:
	return str(console(id).get("name", id))


## "pilot", "gun", "laser" or "scout".
func station_kind(id: String) -> String:
	return str(console(id).get("kind", ""))


func style_of(id: String) -> String:
	return str(console(id).get("style", ""))


func is_turret_station(id: String) -> bool:
	return turrets.has(id)


func is_scout_station(id: String) -> bool:
	return station_kind(id) == "scout"


func gun_stations() -> Array:
	return layout["guns"]


func laser_stations() -> Array:
	return layout["lasers"]


func scout_stations() -> Array:
	return layout["scouts"]


func aim_of(id: String) -> Vector2:
	var i := (layout["aimables"] as Array).find(id)
	return aims[i] if i >= 0 and i < aims.size() else Vector2.ZERO


func gun_weapon(id: String) -> String:
	return str(gun_weapons.get(id, "pulse"))


func laser_on(id: String) -> bool:
	var i := (layout["lasers"] as Array).find(id)
	return i >= 0 and (beams & (1 << i)) != 0


func laser_end(id: String) -> Vector3:
	var i := (layout["lasers"] as Array).find(id)
	return beam_ends[i] if i >= 0 and i < beam_ends.size() else global_position


func dock_point(scout_station: String) -> Vector3:
	return console(scout_station).get("dock", Vector3(0, -3.15, 3.5))


func dock_launch(scout_station: String) -> Vector3:
	return console(scout_station).get("launch", Vector3(0, -7.0, 0))


func shield_center() -> Vector3:
	return layout["shield_center"]


func shield_radii() -> Vector3:
	return layout["shield_radii"]


## [position, outward normal] of hull point i (where critters latch on).
func hull_point(i: int) -> Array:
	return layout["hull_points"][i]


## {"outside", "inside"} of roof hatch i (where infiltrators cut in).
func hatch(i: int) -> Dictionary:
	return layout["hatch_list"][i]


## Auto turret slots this dive (ship type and homebase upgrades; all launch empty).
func turret_slots() -> int:
	return mini(int(stats.get("turret_slots", 0)), (layout["hardpoints"] as Array).size())


# --- Simulation --------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		_time += delta
		_fx_cd = maxf(0.0, _fx_cd - delta)
		if alive:
			_server_systems(delta)
		_server_gates(delta)
		_server_flight(delta)
		_server_weapons(delta)
		_server_autocannons(delta)
		_server_mining(delta)
		_server_cargo()
		net_pos = global_position
		net_vel = velocity
		net_yaw = rotation.y
	else:
		_client_motion(delta)
	_update_dock_parts(delta)
	# Keep the interior collision in sync with the moved ship before the crew's physics runs.
	interior_body.force_update_transform()
	_ramp_body.force_update_transform()
	_update_visuals(delta)


func _client_motion(delta: float) -> void:
	_since_sync += delta
	var target := net_pos + net_vel * minf(_since_sync, 0.3)
	if global_position.distance_to(target) > 12.0:
		global_position = target
		rotation.y = net_yaw
		reset_physics_interpolation()
	else:
		global_position = global_position.lerp(target, NetUtil.smooth(10.0, delta))
		rotation.y = lerp_angle(rotation.y, net_yaw, NetUtil.smooth(10.0, delta))
	velocity = net_vel


func _server_systems(delta: float) -> void:
	if blast_cd > 0.0:
		blast_cd = maxf(0.0, blast_cd - delta)
	if not frozen and landing == Dock.FLYING:
		var burn := (0.12 + absf(throttle) * 0.55 + (0.12 * _laser_count() if beams != 0 else 0.0)) * float(stats["fuel_burn"])
		fuel = maxf(0.0, fuel - burn * delta)
	if landing == Dock.LANDED:
		# Station services: refuel and recharge the shield.
		fuel = minf(max_fuel, fuel + DOCK_REFUEL * delta)
		shield_down = false
		shield_reboot = 0.0
		shield = minf(max_shield, shield + DOCK_SHIELD * delta)
	var self_repair := float(stats.get("self_repair", 0.0))
	if self_repair > 0.0:
		engine_hp = minf(100.0, engine_hp + self_repair * delta)
		weapons_hp = minf(100.0, weapons_hp + self_repair * delta)
	if shield_down:
		if fuel > 0.0:
			shield_reboot = maxf(0.0, shield_reboot - delta)
			if shield_reboot <= 0.0:
				shield_down = false
				shield = max_shield * 0.3
				notify.rpc("Shield back online", 0)
	elif fuel > 0.0 and _time - _last_hit > 3.0 and shield < max_shield:
		shield = minf(max_shield, shield + float(stats["shield_regen"]) * delta)
	if not engine_online and engine_hp >= REBOOT_HP:
		engine_online = true
		notify.rpc("Engine back online", 0)
	if not weapons_online and weapons_hp >= REBOOT_HP:
		weapons_online = true
		notify.rpc("Weapon systems back online", 0)
	if fuel < max_fuel * 0.2 and not _low_fuel_warned:
		_low_fuel_warned = true
		notify.rpc("Fuel low! Send the scout into the side tunnels for fuel crystals", 1)
	elif fuel > max_fuel * 0.3:
		_low_fuel_warned = false
	if fuel <= 0.0 and not _no_fuel_warned:
		_no_fuel_warned = true
		notify.rpc("OUT OF FUEL - engines at minimum, shields cannot recharge!", 2)
	elif fuel > 0.0:
		_no_fuel_warned = false
	depth = maxf(depth, -global_position.z)
	boarders = boarder_root.get_child_count()


func _laser_count() -> int:
	var n := 0
	for i in (layout["lasers"] as Array).size():
		if beams & (1 << i):
			n += 1
	return n


func _server_flight(delta: float) -> void:
	if landing != Dock.FLYING:
		_dock_flight(delta)
		return
	var inp: Dictionary = _inputs.get("pilot", {}) if occupants.has("pilot") else {}
	var power := 1.0 if fuel > 0.0 else 0.4
	var can_fly := engine_online and not frozen and alive
	var turn := 0.0
	var vert := 0.0
	var strafe := 0.0
	if can_fly:
		throttle = clampf(throttle + float(inp.get("throttle", 0.0)) * 0.55 * delta, -0.4, 1.0)
		if inp.get("stop", false):
			throttle = 0.0
		turn = float(inp.get("turn", 0.0))
		vert = float(inp.get("vert", 0.0))
		if autopilot and Game.mission:
			var ap := _autopilot()
			if absf(turn) < 0.05:
				turn = ap.x
			if absf(vert) < 0.05:
				vert = ap.y
			strafe = ap.z
	var desired := Vector3.ZERO
	if can_fly:
		desired = -global_basis.z * throttle * float(stats["max_speed"]) * power
		desired += Vector3.UP * vert * float(stats["vert_speed"]) * power
		desired += global_basis.x * strafe * 4.0 * power
		desired = _gate_brake(desired)
	var accel := float(stats["accel"]) * (1.0 if can_fly else 0.35)
	velocity = velocity.move_toward(desired, accel * delta)
	var target_rate := turn * float(stats["yaw_rate"]) * power if can_fly else 0.0
	_yaw_rate = move_toward(_yaw_rate, target_rate, 0.9 * delta)
	rotation.y = wrapf(rotation.y + _yaw_rate * delta, -PI, PI)
	var pre := velocity
	move_and_slide()
	_bump_cd = maxf(0.0, _bump_cd - delta)
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var impact := -pre.dot(c.get_normal())
		if impact > 2.5 and _bump_cd <= 0.0:
			_bump_cd = 0.6
			apply_damage((impact - 1.5) * 5.0, c.get_position(), "impact")
			velocity += c.get_normal() * impact * 0.6


## Steering (turn, vertical, strafe) that keeps the ship on the cave's centre line.
func _autopilot() -> Vector3:
	var cave: CaveGen = Game.mission.cave
	var s := -global_position.z
	var dir := 1.0 if throttle >= 0.0 else -1.0
	var tan := cave.tangent(s)
	var desired_yaw := atan2(-tan.x, -tan.z)
	var yaw_err := wrapf(desired_yaw - rotation.y, -PI, PI)
	var turn := clampf(yaw_err * 2.5 - _yaw_rate * 1.5, -1.0, 1.0)
	var target := cave.center3(s + dir * 16.0)
	var to := target - global_position
	var vert := clampf((to.y - 1.4) * 0.3, -1.0, 1.0)
	var strafe := clampf(to.dot(global_basis.x) * 0.15, -1.0, 1.0)
	return Vector3(turn, vert, strafe)


## The flight computer stops the ship short of a sealed bulkhead: it limits the speed along a
## waystation's axis so the ship can brake in time.
func _gate_brake(desired: Vector3) -> Vector3:
	if Game.mission == null:
		return desired
	var cave: CaveGen = Game.mission.cave
	var s := -global_position.z
	for st: Dictionary in cave.stations_in(s - 130.0, s + 130.0):
		var k := int(st["k"])
		var l: Vector3 = (st["inv"] as Transform3D) * global_position
		if absf(l.x) > StationBuilder.HALL_HALF_X + 10.0:
			continue
		var deeper := -(st["xform"] as Transform3D).basis.z
		var v := desired.dot(deeper)
		var exit_open := k == gate_k and gate_exit > 0.95
		if exit_open:
			continue
		if v > 0.0 and k > gate_k and l.z > StationBuilder.EXIT_FACE:
			# Heading for the sealed exit of a station we have not landed at.
			var room := (l.z - _nose) - (StationBuilder.EXIT_INNER + 5.0)
			var vmax := sqrt(2.0 * BRAKE_DECEL * maxf(room, 0.0))
			if v > vmax:
				desired -= deeper * (v - vmax)
				if _brake_warned != k and room < 40.0:
					_brake_warned = k
					notify.rpc("%s: exit bulkhead sealed - land (L) to continue" % st["name"], 1)
		elif v < 0.0 and k <= gate_k and l.z < StationBuilder.EXIT_FACE:
			# Backing up towards the sealed exit of a station we already left.
			var room := (StationBuilder.EXIT_FACE - 5.0) - (l.z + _stern)
			var vmax := sqrt(2.0 * BRAKE_DECEL * maxf(room, 0.0))
			if -v > vmax:
				desired += deeper * (-v - vmax)
	return desired


func _server_weapons(delta: float) -> void:
	for id: String in layout["guns"]:
		_fire_cd[id] = maxf(0.0, float(_fire_cd.get(id, 0.0)) - delta)
		if not occupants.has(id) or not weapons_online or not alive:
			continue
		var inp: Dictionary = _inputs.get(id, {})
		if not inp.get("fire", false) or float(_fire_cd[id]) > 0.0:
			continue
		_fire_cd[id] = _fire_turret(id, gun_weapon(id))


func _fire_turret(id: String, weapon: String) -> float:
	var def: Dictionary = WEAPON_DEFS.get(weapon, WEAPON_DEFS["pulse"])
	var t: Turret = turrets[id]
	var a := aim_of(id)
	var b := global_basis * t.aim_basis_local(a)
	var muzzle := to_global(t.muzzle_local(a))
	var dmg := float(def["damage"]) * float(stats["turret_damage"])
	if style_of(id) == "heavy":
		dmg *= 1.25
	var proj: Projectiles = Game.mission.projectiles
	if weapon == "rail":
		proj.fire_rail(muzzle, -b.z, dmg)
	else:
		var spread := deg_to_rad(float(def["spread"]))
		for i in int(def["pellets"]):
			var dir := (b * Vector3(randf_range(-spread, spread), randf_range(-spread, spread), -1.0)).normalized()
			proj.fire(def["kind"], muzzle, dir * float(def["speed"]) + velocity, dmg)
	_fx_shot.rpc(id, weapon)
	return float(def["cooldown"]) / float(stats["turret_rate"])


func _server_mining(delta: float) -> void:
	var lasers: Array = layout["lasers"]
	var mask := 0
	var space := get_world_3d().direct_space_state
	for i in lasers.size():
		var id: String = lasers[i]
		var inp: Dictionary = _inputs.get(id, {})
		var on := occupants.has(id) and bool(inp.get("fire", false)) and weapons_online and alive
		if not on:
			continue
		mask |= 1 << i
		var t: Turret = turrets[id]
		var a := aim_of(id)
		var from := to_global(t.muzzle_local(a))
		var dir := -(global_basis * t.aim_basis_local(a)).z
		var reach := float(stats["mining_range"])
		var q := PhysicsRayQueryParameters3D.create(from, from + dir * reach, Game.LAYER_CAVE | Game.LAYER_ENEMY | Game.LAYER_MINERAL)
		q.collide_with_areas = true
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			beam_ends[i] = from + dir * reach
			continue
		beam_ends[i] = hit["position"]
		var col: Object = hit["collider"]
		if col.has_meta("target"):
			var target: Variant = col.get_meta("target")
			if target is Node and is_instance_valid(target):
				var power := float(stats["mining_power"]) * delta
				# Laser Overcharge: extra damage to aliens and egg sacs.
				var vs_alien := float(stats.get("mining_vs_alien", 1.0))
				if target is Alien:
					power *= vs_alien
				target.take_damage(power, {"source": "mining", "pos": beam_ends[i], "sac": col.get_meta("sac", -1), "vs_alien": vs_alien})
	if mask != beams:
		beams = mask


# --- Damage, repairs and resources (server) ----------------------------------------------------

func apply_damage(amount: float, at: Vector3, kind := "") -> void:
	if not multiplayer.is_server() or not alive or amount <= 0.0:
		return
	# Waystations are safe havens: their defences cover a docking ship.
	if landing != Dock.FLYING:
		return
	if OS.has_feature("debug") and debug_damage:
		print("[damage] %.1f from %s (shield %.0f hull %.0f)" % [amount, kind, shield, hull])
	_last_hit = _time
	if fuel <= 0.0:
		amount *= 1.25
	var absorbed_all := false
	if not shield_down and shield > 0.0:
		var absorbed := minf(shield, amount)
		shield -= absorbed
		amount -= absorbed
		absorbed_all = amount <= 0.0
		if shield <= 0.01:
			shield = 0.0
			shield_down = true
			shield_reboot = float(stats["shield_reboot"])
			notify.rpc("SHIELD DOWN - the hull is exposed!", 2)
	if amount > 0.0:
		hull = maxf(0.0, hull - amount)
		var coll := float(stats["collateral"])
		damage_system("engine", amount * coll * randf_range(0.5, 1.5))
		damage_system("weapons", amount * coll * randf_range(0.5, 1.5))
	if _fx_cd <= 0.0 or kind == "impact":
		_fx_cd = 0.07
		_fx_hit.rpc(to_local(at), absorbed_all, kind)
	if hull <= 0.0:
		_destroy()


func damage_system(sys: String, amount: float) -> void:
	if not multiplayer.is_server() or amount <= 0.0:
		return
	if sys == "engine":
		engine_hp = maxf(0.0, engine_hp - amount)
		if engine_hp <= 0.0 and engine_online:
			engine_online = false
			notify.rpc("ENGINE OFFLINE - repair it in the engine room!", 2)
	elif sys == "weapons":
		weapons_hp = maxf(0.0, weapons_hp - amount)
		if weapons_hp <= 0.0 and weapons_online:
			weapons_online = false
			notify.rpc("WEAPONS OFFLINE - repair the weapon systems!", 2)


func system_hp(sys: String) -> float:
	return engine_hp if sys == "engine" else weapons_hp


func system_online(sys: String) -> bool:
	return engine_online if sys == "engine" else weapons_online


func collector_global() -> Vector3:
	return to_global(layout["collector"])


func collect_mineral(kind: String, value: int) -> void:
	if not multiplayer.is_server():
		return
	credits += value
	var o := ore.duplicate()
	o[kind] = int(o.get(kind, 0)) + 1
	ore = o
	_fx_collect.rpc(kind, value)


func add_fuel(amount: float) -> void:
	if not multiplayer.is_server() or amount <= 0.0:
		return
	fuel = minf(max_fuel, fuel + amount)
	notify.rpc("Refuelled +%d" % int(round(amount)), 0)


## Index of a free hull point for a critter to latch onto, or -1.
func claim_hull_point(owner_id: int) -> int:
	var free: Array[int] = []
	for i in (layout["hull_points"] as Array).size():
		if not _hull_claims.has(i):
			free.append(i)
	if free.is_empty():
		return -1
	var idx: int = free.pick_random()
	_hull_claims[idx] = owner_id
	return idx


func release_hull_point(idx: int, owner_id: int) -> void:
	if _hull_claims.get(idx, -1) == owner_id:
		_hull_claims.erase(idx)


func claim_hatch(owner_id: int) -> int:
	var free: Array[int] = []
	for i in (layout["hatch_list"] as Array).size():
		if not _hatch_claims.has(i):
			free.append(i)
	if free.is_empty():
		return -1
	var idx: int = free.pick_random()
	_hatch_claims[idx] = owner_id
	return idx


func release_hatch(idx: int, owner_id: int) -> void:
	if _hatch_claims.get(idx, -1) == owner_id:
		_hatch_claims.erase(idx)


## Server: an infiltrator cut through a hatch; spawn a boarder inside.
func spawn_boarder(hatch_i: int, hp_mult: float) -> void:
	if not multiplayer.is_server() or not alive:
		return
	_boarder_seq += 1
	var inside: Vector3 = hatch(hatch_i)["inside"]
	boarder_spawner.spawn({"name": "B%d" % _boarder_seq, "pos": inside + Vector3(0, 2.6, 0), "hp": 55.0 * hp_mult})
	notify.rpc("INTRUDER ALERT - aliens are inside the ship!", 2)
	_fx_breach.rpc(hatch_i)


## Point where the segment a→b first enters the shield ellipsoid, or null.
func shield_hit(a: Vector3, b: Vector3) -> Variant:
	var inv := Vector3.ONE / shield_radii()
	var la := (to_local(a) - shield_center()) * inv
	var lb := (to_local(b) - shield_center()) * inv
	var d := lb - la
	var qa := d.dot(d)
	var qb := 2.0 * la.dot(d)
	var qc := la.dot(la) - 1.0
	if qc < 0.0:
		return a
	if qa < 1e-9:
		return null
	var disc := qb * qb - 4.0 * qa * qc
	if disc < 0.0:
		return null
	var t := (-qb - sqrt(disc)) / (2.0 * qa)
	if t < 0.0 or t > 1.0:
		return null
	return a.lerp(b, t)


func _destroy() -> void:
	alive = false
	frozen = true
	for k in occupants.keys():
		_release(k)
	_fx_destroyed.rpc()
	destroyed.emit()


# --- Emergency blast ---------------------------------------------------------------------------

@rpc("any_peer", "call_local", "reliable")
func request_blast() -> void:
	if not multiplayer.is_server() or not alive:
		return
	var pid := Game.sender_id()
	if landing != Dock.FLYING:
		notify_peer(pid, "No emergency blast while docked", 1)
		return
	if blast_cd > 0.0:
		notify_peer(pid, "Emergency blast recharging (%d s)" % int(ceil(blast_cd)), 1)
		return
	if fuel < BLAST_FUEL_COST:
		notify_peer(pid, "Not enough fuel for an emergency blast", 1)
		return
	var hull_cost := max_hull * BLAST_HULL_COST
	if hull <= hull_cost + 1.0:
		notify_peer(pid, "Hull too weak - the blast would tear the ship apart", 2)
		return
	emergency_blast()


## Server: fire the emergency blast. Everything within BLAST_RADIUS takes damage that falls off
## with distance (point blank is lethal to almost anything), including aliens latched onto the
## hull and nearby egg sacs. The shield is drained and the blast costs hull integrity and fuel.
func emergency_blast() -> void:
	blast_cd = BLAST_COOLDOWN
	fuel = maxf(0.0, fuel - BLAST_FUEL_COST)
	hull = maxf(1.0, hull - max_hull * BLAST_HULL_COST)
	shield = 0.0
	shield_down = true
	shield_reboot = float(stats["shield_reboot"])
	_last_hit = _time
	var center := to_global(shield_center())
	var shape := SphereShape3D.new()
	shape.radius = BLAST_RADIUS
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = Transform3D(Basis.IDENTITY, center)
	# Free-flying aliens and egg sacs (enemy layer) plus aliens latched onto the hull (layer 10).
	q.collision_mask = Game.LAYER_ENEMY | 512
	q.collide_with_areas = true
	q.collide_with_bodies = false
	var hits := 0
	for r in get_world_3d().direct_space_state.intersect_shape(q, 96):
		var col: Object = r["collider"]
		if not (col is Area3D and col.has_meta("target")):
			continue
		var target: Variant = col.get_meta("target")
		if not (target is Node and is_instance_valid(target)):
			continue
		var d := center.distance_to((col as Node3D).global_position)
		var falloff := clampf(1.0 - d / BLAST_RADIUS, 0.0, 1.0)
		if falloff <= 0.0:
			continue
		target.take_damage(BLAST_DAMAGE * pow(falloff, 1.4), {"source": "blast", "sac": col.get_meta("sac", -1)})
		hits += 1
	_fx_blast.rpc()
	notify.rpc("EMERGENCY BLAST - shields drained, hull and fuel spent", 1)
	if debug_damage:
		print("[blast] hit %d targets" % hits)


@rpc("authority", "call_local", "reliable")
func _fx_blast() -> void:
	var center := to_global(shield_center())
	Fx.shockwave(center, BLAST_RADIUS, Color(0.55, 0.9, 1.0))
	Fx.flash(center, Color(0.6, 0.9, 1.0), 10.0, BLAST_RADIUS * 2.0, 0.5)
	for i in 10:
		var p := to_global(Vector3(randf_range(-7, 7), randf_range(-1.5, 4.5), randf_range(-12, 12)))
		Fx.sparks(p, Color(0.6, 0.9, 1.0), 10, 14.0, 0.08, 0.6)
	_shield_flash = 1.0
	Sfx.play("blast", center, 6.0)
	if Game.mission:
		Game.mission.shake(1.4)


# --- Waystations -------------------------------------------------------------------------------

## The point in the tunnel in front of a waystation's entrance gate, where docking starts.
static func station_entrance(st: Dictionary) -> Vector3:
	return (st["xform"] as Transform3D) * Vector3(0, StationBuilder.PASS_Y, StationBuilder.ENTRY_FACE + 14.0)


## The next waystation ahead: the first one the ship has not landed at yet.
func next_station() -> Dictionary:
	if Game.mission == null:
		return {}
	return (Game.mission.cave as CaveGen).station(gate_k + 1)


## True while the ship is inside a waystation's hall (between its bulkheads).
func in_hall(st: Dictionary) -> bool:
	var l: Vector3 = (st["inv"] as Transform3D) * global_position
	return absf(l.x) < StationBuilder.HALL_HALF_X and l.z < StationBuilder.ENTRY_FACE and l.z > StationBuilder.EXIT_INNER


## How far the ship is from landing at a waystation: the distance to its entrance gate, or 0 once
## inside its hall.
func station_distance(st: Dictionary) -> float:
	if in_hall(st):
		return 0.0
	return global_position.distance_to(station_entrance(st))


## The next waystation if it is within `max_dist` of landing, or {}.
func nearest_station(max_dist: float) -> Dictionary:
	var st := next_station()
	if st.is_empty() or station_distance(st) > max_dist:
		return {}
	return st


## True for a ship-local point inside the ship (the ramp and the station outside are not).
static func is_aboard(p: Vector3) -> bool:
	var lo := ShipBuilder.ABOARD_MIN
	var hi := ShipBuilder.ABOARD_MAX
	return p.x > lo.x and p.x < hi.x and p.y > lo.y and p.y < hi.y and p.z > lo.z and p.z < hi.z


## Name of a conscious crew member who is not aboard, or "".
func crew_outside() -> String:
	for c in crew_root.get_children():
		var m := c as CrewMember
		if m and m.alive and not is_aboard(m.net_pos):
			return m.display_name
	return ""


## Pilot (L): land at the next waystation in range, or lift off once everyone is aboard.
@rpc("any_peer", "call_local", "reliable")
func request_land() -> void:
	if not multiplayer.is_server() or not alive or frozen:
		return
	var pid := Game.sender_id()
	if int(occupants.get("pilot", 0)) != pid:
		return
	match landing:
		Dock.FLYING:
			var st := nearest_station(LAND_RANGE)
			if st.is_empty():
				notify_peer(pid, "No waystation in range", 1)
			elif not engine_online:
				notify_peer(pid, "Engine offline - repair it before docking", 1)
			else:
				_begin_landing(st)
		Dock.LANDED:
			var missing := crew_outside()
			var left := bought_crates_outside()
			if missing != "":
				notify_peer(pid, "Waiting for %s to come aboard" % missing, 1)
			elif left > 0 and _time > _liftoff_confirm:
				_liftoff_confirm = _time + 6.0
				notify_peer(pid, "%d bought item%s still in the shop - press L again to leave without %s" % [
					left, "s are" if left > 1 else " is", "them" if left > 1 else "it"], 1)
			else:
				_begin_liftoff()
		_:
			notify_peer(pid, "Docking manoeuvre in progress", 1)


## Server: fly to the entrance gate along the tunnel, through the gate and over the shop to above the
## pad, then settle on the landing legs, nose towards the exit.
func _begin_landing(st: Dictionary) -> void:
	var xf: Transform3D = st["xform"]
	var yaw := atan2(xf.basis.z.x, xf.basis.z.z)
	var l: Vector3 = (st["inv"] as Transform3D) * global_position
	var outside := station_entrance(st)
	var above := xf * Vector3(0, StationBuilder.PASS_Y, 0)
	var pad := xf * Vector3(0, StationBuilder.LAND_HEIGHT, 0)
	_dock_keys = []
	var start := global_position
	if l.z > StationBuilder.ENTRY_FACE + 14.0:
		# Follow the tunnel's centre line to the gate so the ship never cuts through rock.
		var cave: CaveGen = Game.mission.cave
		var route := PackedVector3Array([global_position])
		var s0 := -global_position.z
		var s1 := -outside.z
		var steps := int(absf(s1 - s0) / 15.0)
		for i in range(1, steps):
			route.append(cave.center3(lerpf(s0, s1, float(i) / float(steps))) + Vector3(0, -1.4, 0))
		route.append(outside)
		var length := 0.0
		for i in route.size() - 1:
			length += route[i].distance_to(route[i + 1])
		_dock_keys.append({"pos": outside, "route": route, "yaw": yaw, "time": clampf(length / DOCK_SPEED, 2.0, 16.0)})
		start = outside
	elif absf(l.x) > 1.0 or absf(l.y - StationBuilder.PASS_Y) > 1.0:
		# Close to the gate or already inside: line up with the gate axis first.
		var lined := xf * Vector3(0, StationBuilder.PASS_Y, l.z)
		_dock_keys.append({"pos": lined, "yaw": yaw, "time": maxf(1.5, start.distance_to(lined) / DOCK_SPEED_SLOW)})
		start = lined
	_dock_keys.append({"pos": above, "yaw": yaw, "time": maxf(2.0, start.distance_to(above) / DOCK_SPEED_SLOW)})
	_dock_keys.append({"pos": pad, "yaw": yaw, "time": maxf(2.2, above.distance_to(pad) / DOCK_DESCENT)})
	_start_dock_path()
	landing = Dock.APPROACH
	station_k = int(st["k"])
	throttle = 0.0
	# Scouts come home first: the entrance seals once the ship is down.
	for sc: Scout in Game.mission.scouts:
		sc.recall_for_docking()
	notify.rpc("Docking at %s - approach on autopilot" % st["name"], 0)


## Server: close the ramp, rise to the gate height, wait for the exit gate and fly out through it.
func _begin_liftoff() -> void:
	var cave: CaveGen = Game.mission.cave
	var st := cave.station(station_k)
	var xf: Transform3D = st["xform"]
	var yaw := atan2(xf.basis.z.x, xf.basis.z.z)
	var above := xf * Vector3(0, StationBuilder.PASS_Y, 0)
	var out := xf * Vector3(0, StationBuilder.PASS_Y, StationBuilder.EXIT_FACE - _stern - 12.0)
	_dock_keys = [
		{"pos": above, "yaw": yaw, "time": maxf(2.5, global_position.distance_to(above) / DOCK_DESCENT)},
		{"wait_gate": true},
		{"pos": out, "yaw": yaw, "time": maxf(3.0, above.distance_to(out) / DOCK_SPEED_SLOW)},
	]
	_start_dock_path()
	_dock_wait = 0.4
	landing = Dock.LIFTOFF
	_exit_state = 1
	_stow_station(st)
	notify.rpc("Lifting off - ramp closing, exit bulkhead opening", 0)


func _start_dock_path() -> void:
	_dock_t = 0.0
	_dock_from = global_position
	_dock_from_yaw = rotation.y
	_yaw_rate = 0.0


## Server: follow the scripted docking path (eased keyframes of position and yaw).
func _dock_flight(delta: float) -> void:
	velocity = Vector3.ZERO
	throttle = 0.0
	if landing == Dock.LANDED:
		return
	if landing == Dock.LIFTOFF and (_dock_wait > 0.0 or ramp > 0.0):
		_dock_wait -= delta
		return
	if _dock_keys.is_empty():
		_dock_done()
		return
	var key: Dictionary = _dock_keys[0]
	if key.has("wait_gate"):
		# Hold until the exit bulkhead is fully open.
		if gate_exit >= 0.98:
			_dock_keys.pop_front()
			_start_dock_path()
		return
	_dock_t = minf(1.0, _dock_t + delta / float(key["time"]))
	var k := smoothstep(0.0, 1.0, _dock_t)
	var prev := global_position
	if key.has("route"):
		global_position = _route_point(key["route"], k)
	else:
		global_position = _dock_from.lerp(key["pos"], k)
	rotation.y = wrapf(_dock_from_yaw + angle_difference(_dock_from_yaw, float(key["yaw"])) * k, -PI, PI)
	velocity = (global_position - prev) / maxf(delta, 0.0001)
	if _dock_t >= 1.0:
		_dock_keys.pop_front()
		_start_dock_path()
		if _dock_keys.is_empty():
			_dock_done()


## Point at fraction t (by length) along a polyline.
static func _route_point(route: PackedVector3Array, t: float) -> Vector3:
	var total := 0.0
	for i in route.size() - 1:
		total += route[i].distance_to(route[i + 1])
	var want := total * t
	for i in route.size() - 1:
		var seg := route[i].distance_to(route[i + 1])
		if want <= seg or i == route.size() - 2:
			return route[i].lerp(route[i + 1], clampf(want / maxf(seg, 0.001), 0.0, 1.0))
		want -= seg
	return route[route.size() - 1]


func _dock_done() -> void:
	velocity = Vector3.ZERO
	if landing == Dock.APPROACH:
		landing = Dock.LANDED
		_on_landed()
	elif landing == Dock.LIFTOFF:
		landing = Dock.FLYING
		station_k = -1
		autopilot = true
		_exit_state = 2
		notify.rpc("Clear of the waystation - the helm is yours", 0)


func _on_landed() -> void:
	var st: Dictionary = Game.mission.cave.station(station_k)
	# The entrance seals behind the ship: the previous stretch of tunnel is closed for good.
	gate_k = station_k
	gate_entry = 1.0
	gate_exit = 0.0
	_exit_state = 0
	stations_docked += 1
	_unload_station(st)
	_fx_touchdown.rpc()
	notify.rpc("Docked at %s - entrance bulkhead sealing. Refuelling; the shop is open." % st["name"], 0)


## Server: animate the bulkheads of the station the ship last landed at. The exit opens for
## liftoff and seals again once the ship and its scouts are through.
func _server_gates(delta: float) -> void:
	if gate_k < 0:
		return
	gate_entry = move_toward(gate_entry, 0.0, GATE_RATE * delta)
	var want := 0.0
	match _exit_state:
		1:
			want = 1.0
		2:
			if not _clear_of_exit():
				want = 1.0
			elif gate_exit <= 0.0:
				_exit_state = 3
				notify.rpc("Exit bulkhead sealed behind us - there is no way back", 0)
	gate_exit = move_toward(gate_exit, want, GATE_RATE * delta)


## True once the ship and every flying scout are past the exit bulkhead of station gate_k.
func _clear_of_exit() -> bool:
	var st: Dictionary = Game.mission.cave.station(gate_k)
	var inv: Transform3D = st["inv"]
	if (inv * global_position).z + _stern > StationBuilder.EXIT_FACE - 4.0:
		return false
	for sc: Scout in Game.mission.scouts:
		if sc.state == Scout.State.FLYING and (inv * sc.global_position).z > StationBuilder.EXIT_FACE - 4.0:
			return false
	return true


# --- Shop and supply crates --------------------------------------------------------------------

## The crate a crew member is carrying, or null.
func crate_carried_by(pid: int) -> SupplyCrate:
	for c in cargo_root.get_children():
		var crate := c as SupplyCrate
		if crate and crate.carrier == pid:
			return crate
	return null


## Server: put a waystation's shop stock out on its pedestals (crates live in ship space; the
## ship is parked).
func _unload_station(st: Dictionary) -> void:
	var k := int(st["k"])
	if not _station_cargo.has(k):
		_station_cargo[k] = _station_offer(k)
	var lift := Vector3(0, StationBuilder.LAND_HEIGHT, 0)
	for rec: Dictionary in _station_cargo[k]:
		_crate_seq += 1
		cargo_spawner.spawn({"name": "C%d" % _crate_seq, "item": rec["item"], "price": int(rec.get("price", 0)),
			"pos": (rec["pos"] as Vector3) - lift, "yaw": rec["yaw"]})
	_station_cargo[k] = []


## Server: crates left outside the ship stay at the station (the ship never comes back).
func _stow_station(st: Dictionary) -> void:
	var k := int(st["k"])
	var left: Array = _station_cargo.get(k, [])
	var lift := Vector3(0, StationBuilder.LAND_HEIGHT, 0)
	var bought := 0
	for c in cargo_root.get_children():
		var crate := c as SupplyCrate
		if crate == null or crate.carrier != 0 or is_aboard(crate.net_pos):
			continue
		if crate.price <= 0:
			bought += 1
		left.append({"item": crate.item, "price": crate.price, "pos": crate.net_pos + lift, "yaw": crate.net_yaw})
		crate.queue_free()
	_station_cargo[k] = left
	if bought > 0:
		notify.rpc("%d bought item%s left behind at the station" % [bought, "s" if bought > 1 else ""], 1)


## Bought crates that are still outside the ship (not carried).
func bought_crates_outside() -> int:
	var n := 0
	for c in cargo_root.get_children():
		var crate := c as SupplyCrate
		if crate and crate.price <= 0 and crate.carrier == 0 and not is_aboard(crate.net_pos):
			n += 1
	return n


## What waystation k's shop stocks (see RunItems.roll_shop), on its pedestals.
func _station_offer(k: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([int(Game.mission.mission_seed), k, "shop"])
	var guns: Array = Game.profile.get("guns", ["pulse"])
	var free := turret_slots() - autocannons - _crates_of("autocannon")
	var items := RunItems.roll_shop(rng, guns, gun_weapons.values(), free)
	var out := []
	for i in mini(items.size(), StationBuilder.SHOP_SLOTS.size()):
		var sl: Array = StationBuilder.SHOP_SLOTS[i]
		out.append({"item": items[i], "price": RunItems.price(items[i], k), "yaw": float(sl[2]),
			"pos": Vector3(float(sl[0]), StationBuilder.DECK_Y + StationBuilder.PEDESTAL_H + SupplyCrate.SIZE.y * 0.5, float(sl[1]))})
	return out


func _crates_of(item: String) -> int:
	var n := 0
	for c in cargo_root.get_children():
		if c is SupplyCrate and (c as SupplyCrate).item == item:
			n += 1
	return n


## Server: crates whose carrier left or was knocked out fall where they stood.
func _server_cargo() -> void:
	for c in cargo_root.get_children():
		var crate := c as SupplyCrate
		if crate == null or crate.carrier == 0 or crate.is_queued_for_deletion():
			continue
		var who := crew_root.get_node_or_null(str(crate.carrier)) as CrewMember
		if who == null or not who.alive:
			_drop_crate(crate, crate.last_carrier_pos + Vector3(0, SupplyCrate.SIZE.y * 0.5, 0), 0.0)


func _drop_crate(crate: SupplyCrate, pos: Vector3, yaw: float) -> void:
	crate.net_pos = pos
	crate.net_yaw = yaw
	crate.carrier = 0


## Buy a shop item with the dive's credits; it can then be picked up.
@rpc("any_peer", "call_local", "reliable")
func request_crate_buy(crate_name: String) -> void:
	if not multiplayer.is_server() or not alive:
		return
	var pid := Game.sender_id()
	var crate := cargo_root.get_node_or_null(crate_name) as SupplyCrate
	var who := crew_root.get_node_or_null(str(pid)) as CrewMember
	if crate == null or who == null or not who.alive or crate.price <= 0:
		return
	if who.net_pos.distance_to(crate.net_pos) > 4.0:
		return
	if credits < crate.price:
		notify_peer(pid, "Not enough credits: %s costs %d CR (you have %d)" % [RunItems.display_name(crate.item), crate.price, credits], 1)
		return
	credits -= crate.price
	var paid := crate.price
	crate.price = 0
	notify.rpc("%s bought %s for %d CR" % [who.display_name, RunItems.display_name(crate.item), paid], 0)
	_fx_buy.rpc(crate.net_pos)


@rpc("any_peer", "call_local", "reliable")
func request_crate_pickup(crate_name: String) -> void:
	if not multiplayer.is_server():
		return
	var pid := Game.sender_id()
	var crate := cargo_root.get_node_or_null(crate_name) as SupplyCrate
	var who := crew_root.get_node_or_null(str(pid)) as CrewMember
	if crate == null or who == null or not who.alive or crate.carrier != 0 or crate.price > 0 or crate_carried_by(pid) != null:
		return
	if who.net_pos.distance_to(crate.net_pos) > 4.0:
		return
	crate.carrier = pid
	crate.last_carrier_pos = who.net_pos
	_fx_crate.rpc(crate.net_pos)


@rpc("any_peer", "call_local", "reliable")
func request_crate_drop(crate_name: String, pos: Vector3, yaw: float) -> void:
	if not multiplayer.is_server():
		return
	var crate := cargo_root.get_node_or_null(crate_name) as SupplyCrate
	if crate == null or crate.carrier != Game.sender_id():
		return
	if pos.distance_to(crate.last_carrier_pos) > 3.0:
		pos = crate.last_carrier_pos + Vector3(0, SupplyCrate.SIZE.y * 0.5, 0)
	_drop_crate(crate, pos, yaw)
	_fx_crate.rpc(pos)


## Install a carried crate: guns at a gun console (its station id), the rest at the "hub".
@rpc("any_peer", "call_local", "reliable")
func request_install(crate_name: String, target: String) -> void:
	if not multiplayer.is_server() or not alive:
		return
	var pid := Game.sender_id()
	var crate := cargo_root.get_node_or_null(crate_name) as SupplyCrate
	var who := crew_root.get_node_or_null(str(pid)) as CrewMember
	if crate == null or who == null or crate.carrier != pid or not (target == "hub" or target in gun_stations()):
		return
	var spot := ShipBuilder.INSTALL_HUB
	if target != "hub":
		spot = console(target)["console"]
	if Vector2(who.net_pos.x - spot.x, who.net_pos.z - spot.z).length() > 4.0:
		return
	var item := crate.item
	var msg := ""
	if RunItems.is_weapon(item):
		if target == "hub":
			notify_peer(pid, "Guns are mounted at the gun consoles", 1)
			return
		var old := gun_weapon(target)
		var w := gun_weapons.duplicate()
		w[target] = RunItems.weapon_of(item)
		gun_weapons = w
		_fire_cd[target] = 0.6
		msg = "%s mounted a %s on the %s (was %s)" % [who.display_name, RunItems.display_name(item),
			station_name(target).to_lower(), Game.GUNS[old]["name"]]
	else:
		if target != "hub":
			notify_peer(pid, "Fit this at the install hub in the engine room", 1)
			return
		if item == "autocannon" and autocannons >= turret_slots():
			notify_peer(pid, "Every turret slot is taken", 1)
			return
		_apply_item(item)
		msg = "%s installed %s: %s" % [who.display_name, RunItems.display_name(item), RunItems.describe(item)]
	var mods := run_mods.duplicate()
	mods[item] = int(mods.get(item, 0)) + 1
	run_mods = mods
	crate.queue_free()
	notify.rpc(msg, 0)
	_fx_install.rpc(spot)


## Server: apply a shop upgrade or repair.
func _apply_item(item: String) -> void:
	var st := stats.duplicate()
	match item:
		"hull_kit":
			hull = minf(max_hull, hull + maxf(RunItems.HULL_KIT, max_hull * RunItems.HULL_KIT_SHARE))
		"autocannon":
			autocannons = mini(autocannons + 1, turret_slots())
		"plating":
			var add := float(st.get("base_hull", 400.0)) * 0.15
			max_hull += add
			hull += add
		"shield_cell":
			var add := float(st.get("base_shield", 120.0)) * 0.25
			max_shield += add
			if not shield_down:
				shield += add
		"shield_coil":
			st["shield_regen"] = float(st["shield_regen"]) * 1.3
			st["shield_reboot"] = maxf(4.0, float(st["shield_reboot"]) - 1.0)
		"coolant":
			st["turret_rate"] = float(st["turret_rate"]) * 1.15
		"calibration":
			st["turret_damage"] = float(st["turret_damage"]) * 1.2
		"fuel_tank":
			max_fuel += 30.0
			fuel += 30.0
		"injectors":
			st["fuel_burn"] = float(st["fuel_burn"]) * 0.85
		"thrusters":
			for key: String in ["max_speed", "accel", "yaw_rate", "vert_speed"]:
				st[key] = float(st[key]) * 1.1
		"mining_lens":
			st["mining_power"] = float(st["mining_power"]) * 1.25
		"overcharge":
			st["mining_vs_alien"] = float(st["mining_vs_alien"]) + float(st.get("overcharge_step", 0.5))
		"tractor":
			st["tractor_range"] = float(st["tractor_range"]) * 1.25
		"nanobots":
			st["self_repair"] = float(st.get("self_repair", 0.0)) + 1.2
		"dampers":
			st["collateral"] = float(st["collateral"]) * 0.8
		"scout_plating":
			st["scout_hp"] = float(st["scout_hp"]) + 30.0
		"scout_guns":
			st["scout_damage"] = float(st["scout_damage"]) * 1.25
		"scout_cargo":
			st["scout_cargo"] = float(st["scout_cargo"]) + 20.0
		"scout_thrusters":
			st["scout_speed"] = float(st["scout_speed"]) * 1.12
		"blaster_mod":
			st["blaster_damage"] = float(st["blaster_damage"]) * 1.25
		"power_tools":
			st["repair_rate"] = float(st["repair_rate"]) * 1.3
		"crew_armor":
			st["crew_hp"] = float(st["crew_hp"]) + 20.0
	stats = st


# --- Auto turrets ------------------------------------------------------------------------------

## Ship-local frame of auto turret i's barrels for an aim (yaw, pitch).
func _auto_frame(i: int, a: Vector2) -> Transform3D:
	var g: Dictionary = (_ext["autocannons"] as Array)[i]
	var base: Node3D = g["root"]
	var head: Node3D = g["head"]
	return base.transform * Transform3D(Basis(Vector3.UP, a.x), head.position) * Transform3D(Basis(Vector3.RIGHT, a.y), Vector3.ZERO)


## Aim (yaw, pitch) that points auto turret i at a ship-local point.
func _auto_aim_at(i: int, p: Vector3) -> Vector2:
	var g: Dictionary = (_ext["autocannons"] as Array)[i]
	var base: Node3D = g["root"]
	var q := base.transform.affine_inverse() * p - (g["head"] as Node3D).position
	return Vector2(atan2(-q.x, -q.z), clampf(atan2(q.y, Vector2(q.x, q.z).length()), -0.15, 1.5))


## Hardpoints with an auto turret installed (the first ones in the ship's hardpoint list).
func active_cannons() -> Array[int]:
	var out: Array[int] = []
	for i in mini(autocannons, turret_slots()):
		out.append(i)
	return out


## Server: auto turrets track and shoot free-flying aliens on their own.
func _server_autocannons(delta: float) -> void:
	var guns := active_cannons()
	if guns.is_empty() or not alive:
		return
	var aims_now := auto_aim.duplicate()
	_auto_retarget -= delta
	var retarget := _auto_retarget <= 0.0
	if retarget:
		_auto_retarget = 0.3
	var space := get_world_3d().direct_space_state
	for i in guns:
		var mount: Dictionary = layout["hardpoints"][i]
		var origin := to_global(mount["pos"])
		var up := global_basis * (Basis.from_euler(mount["rot"]) * Vector3.UP)
		if retarget:
			_auto_target[i] = 0
			var best_d := AUTO_RANGE
			for a in get_tree().get_nodes_in_group("aliens"):
				var cand := a as Alien
				if cand == null or cand.attached >= 0 or cand.hp <= 0.0:
					continue
				var to := cand.global_position - origin
				var d := to.length()
				if d >= best_d or to.dot(up) < 0.5:
					continue
				var q := PhysicsRayQueryParameters3D.create(origin + up * 0.8, cand.global_position, Game.LAYER_CAVE)
				if not space.intersect_ray(q).is_empty():
					continue
				best_d = d
				_auto_target[i] = cand.get_instance_id()
		_auto_cd[i] = maxf(0.0, _auto_cd[i] - delta)
		var alien: Alien = null
		if _auto_target[i] != 0:
			alien = instance_from_id(_auto_target[i]) as Alien
		if alien == null or not is_instance_valid(alien) or alien.hp <= 0.0 or alien.attached >= 0:
			_auto_target[i] = 0
			continue
		# Lead the target.
		var p := alien.global_position
		var rel_v := alien.net_vel - velocity
		for n in 2:
			p = alien.global_position + rel_v * (origin.distance_to(p) / AUTO_SPEED)
		var want := _auto_aim_at(i, to_local(p))
		var a: Vector2 = aims_now[i]
		a.x = wrapf(a.x + clampf(angle_difference(a.x, want.x), -AUTO_TURN * delta, AUTO_TURN * delta), -PI, PI)
		a.y = move_toward(a.y, want.y, AUTO_TURN * delta)
		aims_now[i] = a
		if _auto_cd[i] <= 0.0 and weapons_online and absf(angle_difference(a.x, want.x)) < 0.05 and absf(a.y - want.y) < 0.05:
			_auto_cd[i] = AUTO_COOLDOWN / float(stats["turret_rate"])
			var frame := _auto_frame(i, a)
			var muzzle := to_global(frame * ShipBuilder.AUTOCANNON_MUZZLE)
			var dir := (global_basis * (frame.basis * Vector3.FORWARD)).normalized()
			Game.mission.projectiles.fire("pulse", muzzle, dir * AUTO_SPEED + velocity, AUTO_DAMAGE * float(stats["turret_damage"]))
			_fx_auto.rpc(i)
	auto_aim = aims_now


# --- Stations ----------------------------------------------------------------------------------

@rpc("any_peer", "call_local", "reliable")
func request_station(id: String) -> void:
	if not multiplayer.is_server() or not alive or not has_station(id):
		return
	var pid := Game.sender_id()
	var holder := int(occupants.get(id, 0))
	if Net.is_bot(holder):
		_release(id)  # Crew bots make room for human crew.
	elif holder != 0 and holder != pid and Net.roster.has(holder):
		_station_denied.rpc_id(pid, "%s is in use by %s" % [station_name(id), Net.player_name(holder)])
		return
	if is_scout_station(id):
		var scout: Scout = Game.mission.scout_at(id)
		if scout == null or not scout.can_launch():
			_station_denied.rpc_id(pid, scout.status_text() if scout else "Scout unavailable")
			return
	for k in occupants.keys():
		if int(occupants[k]) == pid:
			_release(k)
	var o := occupants.duplicate()
	o[id] = pid
	occupants = o
	_inputs.erase(id)
	if is_scout_station(id):
		Game.mission.scout_at(id).launch(pid)
	_station_granted.rpc_id(pid, id)


@rpc("any_peer", "call_local", "reliable")
func release_station(id: String) -> void:
	if not multiplayer.is_server():
		return
	if int(occupants.get(id, 0)) == Game.sender_id():
		_release(id)


## Server: free every station held by a peer (on disconnect or death).
func release_peer(pid: int) -> void:
	for k in occupants.keys():
		if int(occupants[k]) == pid:
			_release(k)


func _release(id: String) -> void:
	if not occupants.has(id):
		return
	var pid := int(occupants[id])
	var o := occupants.duplicate()
	o.erase(id)
	occupants = o
	_inputs.erase(id)
	if is_scout_station(id) and Game.mission:
		var scout: Scout = Game.mission.scout_at(id)
		if scout:
			scout.pilot_left()
	if pid == multiplayer.get_unique_id() or pid in multiplayer.get_peers():
		_station_released.rpc_id(pid, id)


@rpc("any_peer", "call_local", "unreliable_ordered")
func station_input(id: String, data: Dictionary) -> void:
	if not multiplayer.is_server() or int(occupants.get(id, 0)) != Game.sender_id():
		return
	_apply_station_input(id, data)


## Server: a crew bot takes a free station. Returns false if someone else holds it.
func bot_claim_station(bot_id: int, id: String) -> bool:
	if not multiplayer.is_server() or not alive or not has_station(id):
		return false
	if occupants.has(id) and int(occupants[id]) != bot_id:
		return false
	var o := occupants.duplicate()
	o[id] = bot_id
	occupants = o
	_inputs.erase(id)
	return true


## Server: station input from a crew bot that holds the station.
func bot_station_input(bot_id: int, id: String, data: Dictionary) -> void:
	if multiplayer.is_server() and int(occupants.get(id, 0)) == bot_id:
		_apply_station_input(id, data)


func _apply_station_input(id: String, data: Dictionary) -> void:
	_inputs[id] = data
	if data.has("aim") and turrets.has(id):
		var i := (layout["aimables"] as Array).find(id)
		if i >= 0:
			aims[i] = (turrets[id] as Turret).clamp_aim(data["aim"])


@rpc("any_peer", "call_local", "reliable")
func toggle_autopilot() -> void:
	if multiplayer.is_server() and int(occupants.get("pilot", 0)) == Game.sender_id():
		autopilot = not autopilot


@rpc("any_peer", "call_local", "unreliable_ordered")
func request_repair(sys: String, seconds: float) -> void:
	if not multiplayer.is_server() or not alive:
		return
	var amount := float(stats["repair_rate"]) * clampf(seconds, 0.0, 0.5)
	if sys == "engine":
		engine_hp = minf(100.0, engine_hp + amount)
	elif sys == "weapons":
		weapons_hp = minf(100.0, weapons_hp + amount)


@rpc("any_peer", "call_local", "reliable")
func hit_boarder(boarder_name: String, amount: float) -> void:
	if not multiplayer.is_server():
		return
	var b := boarder_root.get_node_or_null(boarder_name)
	if b:
		b.take_damage(amount, {"source": "player"})


@rpc("authority", "call_local", "reliable")
func _station_granted(id: String) -> void:
	if Game.mission and Game.mission.local_player:
		Game.mission.local_player.enter_station(id)


@rpc("authority", "call_local", "reliable")
func _station_denied(reason: String) -> void:
	if Game.mission and Game.mission.hud:
		Game.mission.hud.toast(reason, 1)


@rpc("authority", "call_local", "reliable")
func _station_released(id: String) -> void:
	var p: CrewMember = Game.mission.local_player if Game.mission else null
	if p and p.station == id:
		p.exit_station(false)


# --- Effects (all peers) -----------------------------------------------------------------------

## Server: show a message to one crew member.
func notify_peer(pid: int, text: String, level: int) -> void:
	if pid == multiplayer.get_unique_id() or pid in multiplayer.get_peers():
		notify.rpc_id(pid, text, level)


@rpc("authority", "call_local", "reliable")
func notify(text: String, level: int) -> void:
	if Game.mission and Game.mission.hud:
		Game.mission.hud.toast(text, level)
	if level >= 2:
		Sfx.play("alarm", null, -12.0)


@rpc("authority", "call_local", "unreliable")
func _fx_hit(local_pos: Vector3, shielded: bool, kind: String) -> void:
	var pos := to_global(local_pos)
	if shielded:
		_shield_flash = maxf(_shield_flash, 0.25 if kind == "scratch" else 0.8)
		Sfx.play("shield_hit", pos, -12.0 if kind == "scratch" else -6.0)
	else:
		_shield_flash = maxf(_shield_flash, 0.15)
		Fx.sparks(pos, Color(1.0, 0.6, 0.2), 14, 9.0)
		Sfx.play("hull_hit", pos, -2.0)
		if Game.mission:
			Game.mission.shake(0.45 if kind == "impact" else 0.22)
	if kind == "scratch":
		Sfx.play("scratch", pos, -10.0)


@rpc("authority", "call_local", "unreliable")
func _fx_shot(id: String, weapon: String) -> void:
	var t: Turret = turrets.get(id)
	if t == null:
		return
	t.kick()
	var muzzle := to_global(t.muzzle_local(t.aim))
	Sfx.play(weapon, muzzle, -8.0 if t.style != "heavy" else -5.0, 1.0 if t.style != "heavy" else 0.85)
	Fx.flash(muzzle, Color(0.4, 0.8, 1.0) if weapon != "flak" else Color(1.0, 0.7, 0.3), 2.5, 6.0, 0.06)


@rpc("authority", "call_local", "unreliable")
func _fx_collect(_kind: String, value: int) -> void:
	Sfx.play("pickup", collector_global(), -10.0, 1.0 + minf(value, 60) / 120.0)
	if Game.mission and Game.mission.hud:
		Game.mission.hud.credit_popup(value)


@rpc("authority", "call_local", "reliable")
func _fx_breach(hatch_i: int) -> void:
	var inside: Vector3 = hatch(hatch_i)["inside"]
	var pos := to_global(inside + Vector3(0, 3.0, 0))
	Fx.sparks(pos, Color(1.0, 0.5, 0.2), 30, 8.0)
	Sfx.play("breach", pos)
	if Game.mission:
		Game.mission.shake(0.3)


@rpc("authority", "call_local", "reliable")
func _fx_destroyed() -> void:
	if Game.mission:
		Game.mission.shake(2.0)
	Sfx.play("explosion", global_position, 8.0)
	for i in 7:
		var p := to_global(Vector3(randf_range(-7, 7), randf_range(-1, 4), randf_range(-12, 12)))
		get_tree().create_timer(i * 0.35).timeout.connect(func():
			Fx.explosion(p, randf_range(4.0, 8.0))
			Sfx.play("explosion", p, 2.0, randf_range(0.7, 1.1)))


@rpc("authority", "call_local", "unreliable")
func _fx_auto(i: int) -> void:
	if i >= auto_aim.size():
		return
	var muzzle := to_global(_auto_frame(i, auto_aim[i]) * ShipBuilder.AUTOCANNON_MUZZLE)
	Fx.flash(muzzle, Color(0.4, 0.85, 1.0), 2.0, 5.0, 0.05)
	Sfx.play("pulse", muzzle, -14.0, 1.3)


@rpc("authority", "call_local", "reliable")
func _fx_touchdown() -> void:
	for lp: Vector3 in layout["legs"]:
		var foot := to_global(lp + Vector3(0, -float(layout["leg_length"]), 0))
		Fx.sparks(foot, Color(0.85, 0.8, 0.7), 10, 4.0, 0.05, 0.5)
	Sfx.play("dock", global_position, 2.0, 0.7)
	if Game.mission:
		Game.mission.shake(0.35)


@rpc("authority", "call_local", "unreliable")
func _fx_crate(local_pos: Vector3) -> void:
	Sfx.play("dock", to_global(local_pos), -10.0, 1.6)


@rpc("authority", "call_local", "unreliable")
func _fx_buy(local_pos: Vector3) -> void:
	var pos := to_global(local_pos)
	Sfx.play("buy", pos, -2.0)
	Fx.sparks(pos + Vector3(0, 0.3, 0), Color(1.0, 0.85, 0.35), 14, 3.5, 0.04, 0.5)


@rpc("authority", "call_local", "reliable")
func _fx_install(local_pos: Vector3) -> void:
	var pos := to_global(local_pos + Vector3(0, 1.2, 0))
	Fx.sparks(pos, Color(0.5, 1.0, 0.7), 18, 5.0, 0.04, 0.5)
	Fx.flash(pos, Color(0.5, 1.0, 0.7), 3.0, 6.0, 0.3)
	Sfx.play("install", pos, -2.0)


## Repair sparks at a ship-local point, shown to everyone (used by crew bots).
@rpc("authority", "call_local", "unreliable")
func fx_repair(local_pos: Vector3) -> void:
	var pos := to_global(local_pos)
	Fx.sparks(pos, Color(0.5, 0.9, 1.0), 6, 4.0, 0.03, 0.3)
	Sfx.play("repair", pos, -8.0)


## Relay a crew member's blaster shot (ship-local coordinates) to the other peers.
@rpc("any_peer", "call_remote", "unreliable")
func fx_blaster(from_local: Vector3, to_local_pos: Vector3, normal_local: Vector3, flesh: bool, did_hit: bool) -> void:
	var a := to_global(from_local)
	var b := to_global(to_local_pos)
	Fx.tracer(a, b, Color(1.0, 0.5, 0.2), 0.04, 0.08)
	if did_hit:
		Fx.impact(b, global_basis * normal_local, Color(0.6, 1.0, 0.3) if flesh else Color(1.0, 0.6, 0.3), 1.2 if flesh else 1.0)
	Sfx.play("blaster", a, -6.0)


# --- Visuals -----------------------------------------------------------------------------------

## Animate the cargo ramp and landing legs from the docking state (every peer does this itself,
## so the ramp the crew walks on matches what they see).
func _update_dock_parts(delta: float) -> void:
	var prev := ramp
	ramp = move_toward(ramp, 1.0 if landing == Dock.LANDED else 0.0, RAMP_RATE * delta)
	var down := landing == Dock.APPROACH or landing == Dock.LANDED or (landing == Dock.LIFTOFF and ramp > 0.0)
	var prev_gear := gear
	gear = move_toward(gear, 1.0 if down else 0.0, GEAR_RATE * delta)
	(_int["ramp"] as Node3D).rotation.x = smoothstep(0.0, 1.0, ramp) * ShipBuilder.RAMP_OPEN
	for leg: Dictionary in _ext["legs"]:
		(leg["node"] as Node3D).rotation.x = float(leg["fold"]) * deg_to_rad(84.0) * (1.0 - smoothstep(0.0, 1.0, gear))
	var moving := ramp != prev
	var light := _int["ramp_light"] as OmniLight3D
	light.light_energy = (1.2 + sin(_alarm_t * 14.0)) if moving else (0.5 if ramp >= 1.0 else 0.0)
	if (moving and (prev == 0.0 or prev == 1.0)) or (gear != prev_gear and (prev_gear == 0.0 or prev_gear == 1.0)):
		Sfx.play("servo", to_global(Vector3(0, 0, 10.0) if moving else Vector3(0, -2.0, 0)), -6.0)


func _update_visuals(delta: float) -> void:
	var lp: CrewMember = Game.mission.local_player if Game.mission else null
	var guns: Array = _ext["autocannons"]
	var slots := turret_slots()
	var active := mini(autocannons, slots)
	for i in guns.size():
		var g: Dictionary = guns[i]
		(g["root"] as Node3D).visible = i < slots
		(g["head"] as Node3D).visible = i < active
		if i < active and i < auto_aim.size():
			(g["head"] as Node3D).rotation.y = auto_aim[i].x
			(g["pitch"] as Node3D).rotation.x = auto_aim[i].y
	var hub_text := _hub_listing()
	if hub_text != _hub_text:
		_hub_text = hub_text
		(_int["hub_label"] as Label3D).text = hub_text
	for id: String in turrets:
		var a := aim_of(id)
		if lp and lp.station == id:
			a = lp.station_aim
		(turrets[id] as Turret).set_aim(a)
	var glow: StandardMaterial3D = _ext["engine_glow_mat"]
	var power := clampf(absf(throttle), 0.0, 1.0) if engine_online and alive else 0.0
	glow.albedo_color = Color(0.12, 0.2, 0.26).lerp(Color(0.7, 1.2, 1.5), 0.2 + power * 0.8 if engine_online and alive else 0.0)
	_shield_flash = maxf(0.0, _shield_flash - delta * 2.5)
	_shield_mat.set_shader_parameter("intensity", _shield_flash)
	_shield_mat.set_shader_parameter("base", 0.0 if shield_down else 0.025 * clampf(shield / max_shield, 0.0, 1.0))
	for id: String in _beams:
		var bm: Dictionary = _beams[id]
		var mesh: MeshInstance3D = bm["mesh"]
		var light: OmniLight3D = bm["light"]
		var audio: AudioStreamPlayer3D = bm["audio"]
		var on := laser_on(id)
		mesh.visible = on
		if on:
			var t: Turret = turrets[id]
			var to := to_local(laser_end(id))
			Models.place_strut(mesh, t.muzzle_local(t.aim), to)
			mesh.scale = Vector3(1.0 + randf() * 0.4, 1.0, 1.0 + randf() * 0.4) * mesh.scale
			light.position = to
			light.light_energy = 2.5 + randf() * 1.5
			if randf() < 0.35:
				Fx.sparks(laser_end(id), Color(1.0, 0.6, 0.25), 4, 6.0, 0.05, 0.35)
		else:
			light.light_energy = 0.0
		if on != audio.playing:
			if on:
				audio.play()
			else:
				audio.stop()
	_engine_audio.pitch_scale = 0.75 + clampf(velocity.length() / 14.0, 0.0, 1.0) * 0.6
	# Alarm lights inside the ship.
	var alarm := alive and (boarders > 0 or hull < max_hull * 0.3 or not engine_online or not weapons_online or shield_down)
	_alarm_t += delta
	var pulse := (0.5 + 0.5 * sin(_alarm_t * 6.0)) * 0.9 if alarm else 0.0
	for l: OmniLight3D in _int["alarms"]:
		l.light_energy = pulse
	if alarm and boarders > 0 and lp and lp.station == "":
		_alarm_sound_t -= delta
		if _alarm_sound_t <= 0.0:
			_alarm_sound_t = 2.5
			Sfx.play("alarm", null, -16.0)
	(_int["core_mat"] as StandardMaterial3D).emission_energy_multiplier = (1.0 + engine_hp / 60.0) * (0.5 + 0.5 * sin(_alarm_t * (2.0 + power * 6.0))) + 0.6 if engine_online else 0.25
	(_int["blast_mat"] as StandardMaterial3D).emission_energy_multiplier = \
			(2.2 + 1.3 * sin(_alarm_t * 5.0)) if blast_cd <= 0.0 and alive else 0.25
	for p in panels:
		var hpv := system_hp(p["system"])
		var online := system_online(p["system"])
		var col := Color(0.3, 1.0, 0.4)
		if not online:
			col = Color(1.0, 0.1, 0.05) * (0.4 + 0.6 * absf(sin(_alarm_t * 5.0)))
		elif hpv < 50.0:
			col = Color(1.0, 0.6, 0.1)
		elif hpv < 99.0:
			col = Color(0.9, 1.0, 0.2)
		(p["status_mat"] as StandardMaterial3D).emission = col
		if hpv < 60.0 and randf() < (0.02 if online else 0.08):
			var panel_node: Node3D = p["node"]
			Fx.sparks(panel_node.global_position + panel_node.global_basis.z * -0.15, Color(1.0, 0.7, 0.3), 6, 4.0, 0.03, 0.4)


## Text for the install hub's screen: what was fitted this dive.
func _hub_listing() -> String:
	var lines := PackedStringArray(["INSTALLED THIS DIVE"])
	for item: String in run_mods:
		var n := int(run_mods[item])
		lines.append("%s%s" % [RunItems.display_name(item), " x%d" % n if n > 1 else ""])
	if lines.size() == 1:
		lines.append("(nothing yet)")
	lines.append("")
	lines.append("Auto turrets %d/%d" % [mini(autocannons, turret_slots()), turret_slots()])
	return "\n".join(lines)
