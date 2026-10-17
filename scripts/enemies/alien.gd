class_name Alien
extends Node3D
## Free-flying cave aliens, simulated on the server.
##
## SPITTER keeps its distance and lobs acid at the mothership (or the scout).
## CRITTER latches onto the mothership's hull and scratches it; turrets can't reach it there, so
## the scout has to shoot it off. INFILTRATOR latches onto a roof hatch and, once the shield is
## down, cuts through and drops into the ship as a boarder the crew must kill with blasters.
## While the ship is down at an abandoned station they leave it alone: latched aliens let go, and
## those that were after it roam the tunnel by the hangar until it comes back out.

enum Kind { SPITTER, CRITTER, INFILTRATOR }

const KIND_STATS := {
	Kind.SPITTER: {"hp": 45.0, "speed": 9.5, "radius": 1.5, "name": "Spitter"},
	Kind.CRITTER: {"hp": 18.0, "speed": 15.0, "radius": 0.9, "name": "Critter"},
	Kind.INFILTRATOR: {"hp": 50.0, "speed": 11.0, "radius": 1.4, "name": "Infiltrator"},
}
const SPIT_SPEED := 32.0
const AGGRO_RANGE := 90.0

const ORGANIC_SHADER := """
shader_type spatial;
uniform vec4 base_color : source_color = vec4(0.22, 0.1, 0.25, 1.0);
uniform vec4 glow_color : source_color = vec4(0.5, 1.0, 0.2, 1.0);
uniform float pulse_speed = 2.0;
uniform float vein_scale = 6.0;
instance uniform float flash = 0.0;
varying vec3 lp;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x),
			mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
			mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	lp = VERTEX;
}

void fragment() {
	// Branching veins: thin contour lines of two octaves of value noise.
	vec3 q = lp * vein_scale * 0.35;
	float n = vnoise(q) * 0.65 + vnoise(q * 2.3 + 7.1) * 0.35;
	float lw = max(fwidth(n) * 1.5, 0.012);
	float veins = 1.0 - smoothstep(lw * 0.3, lw, abs(n - 0.5));
	float mottle = vnoise(q * 1.7 + 3.0);
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	float pulse = 0.6 + 0.4 * sin(TIME * pulse_speed + lp.y * 2.0);
	ALBEDO = mix(base_color.rgb * (0.7 + 0.6 * mottle), vec3(1.0), flash * 0.6);
	ROUGHNESS = 0.3;
	SPECULAR = 0.7;
	EMISSION = glow_color.rgb * (veins * pulse * 1.4 + rim * 0.3) + vec3(1.0, 0.9, 0.8) * flash * 2.5;
}
"""

static var _shader: Shader
static var _mats: Dictionary = {}

# Replicated (server authority).
var net_pos := Vector3.ZERO
var net_vel := Vector3.ZERO
var net_dir := Vector3.FORWARD
var hp := 45.0
var max_hp := 45.0
## Hull point (critter) or hatch (infiltrator) this alien is latched onto, or -1.
var attached := -1

var kind := Kind.SPITTER
var hp_mult := 1.0
var dmg_mult := 1.0
var nest_name := ""
var home := Vector3.ZERO

var _parts: Dictionary = {}
var _meshes: Array[GeometryInstance3D] = []
var _hitbox: Area3D
var _anim_t := 0.0
var _flash := 0.0
var _last_hp := 0.0
var _since_sync := 0.0
# Server AI state.
var _claim := -1
var _spit_cd := 2.0
var _wander := Vector3.ZERO
var _wander_t := 0.0
var _avoid := Vector3.ZERO
var _avoid_t := 0.0
var _scratch := 0.0
var _breach := 0.0
var _orbit := 1.0
var _range := 24.0
## True while leaving the ship alone (it is down at an abandoned station).
var _roaming := false


static func organic(base: Color, glow: Color, pulse := 2.0, veins := 6.0) -> ShaderMaterial:
	var key := "%s|%s|%.1f|%.1f" % [base.to_html(), glow.to_html(), pulse, veins]
	if _mats.has(key):
		return _mats[key]
	if _shader == null:
		_shader = Shader.new()
		_shader.code = ORGANIC_SHADER
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("base_color", base)
	m.set_shader_parameter("glow_color", glow)
	m.set_shader_parameter("pulse_speed", pulse)
	m.set_shader_parameter("vein_scale", veins)
	_mats[key] = m
	return m


## Build the model for a kind under `root`. Returns animated parts.
static func build_model(root: Node3D, k: int) -> Dictionary:
	var parts := {}
	match k:
		Kind.SPITTER:
			var skin := organic(Color(0.26, 0.09, 0.3), Color(0.5, 1.0, 0.2), 2.5, 5.0)
			var sac := Models.emissive(Color(0.55, 1.0, 0.15), 2.2, Color(0.2, 0.35, 0.05))
			Models.sphere(root, Vector3.ZERO, 0.8, skin, Vector3(1.0, 0.8, 1.5))
			Models.sphere(root, Vector3(0, 0.15, -1.15), 0.5, skin, Vector3(1.0, 0.85, 1.1))
			Models.sphere(root, Vector3(0, -0.02, -1.6), 0.2, Models.emissive(Color(0.6, 1.0, 0.2), 4.0))
			for side: float in [-1.0, 1.0]:
				Models.sphere(root, Vector3(side * 0.38, 0.55, 0.25), 0.3, sac)
				Models.sphere(root, Vector3(side * 0.22, 0.35, -1.5), 0.07, Models.emissive(Color(1, 0.2, 0.1), 6.0))
				Models.sphere(root, Vector3(side * 0.12, 0.42, -1.42), 0.05, Models.emissive(Color(1, 0.2, 0.1), 6.0))
				var wing := Node3D.new()
				wing.position = Vector3(side * 0.65, 0.3, -0.25)
				root.add_child(wing)
				var membrane := organic(Color(0.3, 0.1, 0.26), Color(0.45, 0.85, 0.2), 3.0, 4.0)
				Models.sphere(wing, Vector3(side * 1.3, 0, 0.25), 1.0, membrane, Vector3(1.35, 0.04, 0.75), 20)
				Models.strut(wing, Vector3.ZERO, Vector3(side * 2.6, 0.1, -0.3), 0.06, skin)
				Models.strut(wing, Vector3(side * 1.3, 0.05, -0.1), Vector3(side * 2.0, 0.0, 0.8), 0.035, skin)
				parts["wing_l" if side < 0 else "wing_r"] = wing
			Models.cylinder(root, Vector3(0, 0, 1.6), 0.35, 1.4, skin, Vector3(90, 0, 0), 0.06)
		Kind.CRITTER:
			var skin := organic(Color(0.35, 0.08, 0.06), Color(1.0, 0.45, 0.1), 4.0, 9.0)
			Models.sphere(root, Vector3.ZERO, 0.45, skin, Vector3(1.0, 0.75, 1.2))
			Models.sphere(root, Vector3(0, 0.05, -0.5), 0.25, skin)
			for side: float in [-1.0, 1.0]:
				Models.sphere(root, Vector3(side * 0.1, 0.15, -0.7), 0.06, Models.emissive(Color(1.0, 0.6, 0.1), 6.0))
				Models.strut(root, Vector3(side * 0.15, -0.05, -0.65), Vector3(side * 0.2, -0.1, -1.05), 0.05, skin)
			var legs: Array[Node3D] = []
			for i in 6:
				var side := -1.0 if i < 3 else 1.0
				var leg := Node3D.new()
				leg.position = Vector3(side * 0.3, 0, -0.25 + (i % 3) * 0.25)
				root.add_child(leg)
				Models.strut(leg, Vector3.ZERO, Vector3(side * 0.55, 0.25, 0), 0.05, skin)
				Models.strut(leg, Vector3(side * 0.55, 0.25, 0), Vector3(side * 0.85, -0.35, 0), 0.04, skin)
				legs.append(leg)
			parts["legs"] = legs
		Kind.INFILTRATOR:
			var skin := organic(Color(0.08, 0.2, 0.22), Color(0.2, 0.9, 1.0), 2.0, 7.0)
			var plate := Models.mat(Color(0.1, 0.14, 0.16), 0.5, 0.35)
			Models.capsule(root, Vector3.ZERO, 0.45, 2.2, skin, Vector3(90, 0, 0))
			Models.box(root, Vector3(0, 0.38, 0.1), Vector3(0.6, 0.15, 1.6), plate)
			Models.sphere(root, Vector3(0, 0.1, -1.2), 0.35, skin, Vector3(0.9, 0.8, 1.2))
			for side: float in [-1.0, 1.0]:
				Models.sphere(root, Vector3(side * 0.15, 0.25, -1.45), 0.07, Models.emissive(Color(0.3, 1.0, 1.0), 6.0))
				var arm := Node3D.new()
				arm.position = Vector3(side * 0.35, 0.1, -0.8)
				root.add_child(arm)
				Models.strut(arm, Vector3.ZERO, Vector3(side * 0.4, 0.5, -0.5), 0.07, skin)
				Models.box(arm, Vector3(side * 0.45, 0.45, -0.95), Vector3(0.08, 0.12, 0.9), plate, Vector3(-30, 0, 0))
				parts["arm_l" if side < 0 else "arm_r"] = arm
			var legs: Array[Node3D] = []
			for i in 4:
				var side := -1.0 if i < 2 else 1.0
				var leg := Node3D.new()
				leg.position = Vector3(side * 0.35, -0.1, -0.1 + (i % 2) * 0.8)
				root.add_child(leg)
				Models.strut(leg, Vector3.ZERO, Vector3(side * 0.6, 0.35, 0), 0.06, skin)
				Models.strut(leg, Vector3(side * 0.6, 0.35, 0), Vector3(side * 0.9, -0.6, 0.1), 0.05, skin)
				legs.append(leg)
			parts["legs"] = legs
	return parts


static func collect_meshes(n: Node, out: Array[GeometryInstance3D]) -> void:
	for c in n.get_children():
		if c is GeometryInstance3D:
			out.append(c)
		collect_meshes(c, out)


func _init() -> void:
	NetUtil.add_sync(self, ["net_pos", "net_vel", "net_dir"], ["hp", "attached"], 0.05)


func setup(data: Dictionary) -> void:
	name = str(data["name"])
	kind = int(data["kind"]) as Kind
	hp_mult = float(data.get("hp_mult", 1.0))
	dmg_mult = float(data.get("dmg_mult", 1.0))
	nest_name = str(data.get("nest", ""))
	position = data["pos"]
	home = position
	net_pos = position
	max_hp = float(KIND_STATS[kind]["hp"]) * hp_mult
	hp = max_hp


func _ready() -> void:
	add_to_group("aliens")
	var model := Node3D.new()
	model.name = "Model"
	add_child(model)
	_parts = build_model(model, kind)
	collect_meshes(model, _meshes)
	_hitbox = Area3D.new()
	_hitbox.collision_layer = Game.LAYER_ENEMY
	_hitbox.collision_mask = 0
	_hitbox.monitoring = false
	_hitbox.set_meta("target", self)
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = float(KIND_STATS[kind]["radius"])
	cs.shape = sh
	_hitbox.add_child(cs)
	add_child(_hitbox)
	_last_hp = hp
	_anim_t = randf() * 10.0
	_orbit = 1.0 if randf() < 0.5 else -1.0
	_range = randf_range(20.0, 28.0)
	_spit_cd = randf_range(1.5, 3.5)
	_wander = home
	if not multiplayer.is_server():
		($Sync as MultiplayerSynchronizer).synchronized.connect(func(): _since_sync = 0.0)


func _physics_process(delta: float) -> void:
	var mission := Game.mission as MissionLevel
	if mission == null or mission.ship == null:
		return
	if multiplayer.is_server():
		_think(delta, mission)
		net_pos = global_position
	else:
		_client_motion(delta, mission)
	if not is_inside_tree():
		return
	var dir := net_dir
	if dir.length_squared() > 0.01:
		var up := Vector3.UP if absf(dir.normalized().y) < 0.95 else Vector3.FORWARD
		var q := global_basis.get_rotation_quaternion().slerp(Basis.looking_at(dir.normalized(), up).get_rotation_quaternion(), NetUtil.smooth(8.0, delta))
		global_basis = Basis(q)
	# Latched aliens are only hittable by the scout (see Projectiles.MASK_SCOUT).
	var layer := Projectiles.LAYER_ATTACHED if attached >= 0 else Game.LAYER_ENEMY
	if _hitbox.collision_layer != layer:
		_hitbox.collision_layer = layer


func _process(delta: float) -> void:
	_anim_t += delta
	if hp < _last_hp - 0.01:
		_flash = 1.0
	_last_hp = hp
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 5.0)
		for m in _meshes:
			m.set_instance_shader_parameter("flash", _flash)
	_animate()


func _animate() -> void:
	match kind:
		Kind.SPITTER:
			var flap := sin(_anim_t * 9.0) * 0.6
			(_parts["wing_l"] as Node3D).rotation.z = flap
			(_parts["wing_r"] as Node3D).rotation.z = -flap
		Kind.CRITTER, Kind.INFILTRATOR:
			var speed := 22.0 if attached >= 0 else 12.0
			var legs: Array = _parts.get("legs", [])
			for i in legs.size():
				(legs[i] as Node3D).rotation.x = sin(_anim_t * speed + i * 1.7) * 0.35
			if kind == Kind.INFILTRATOR:
				var swing := sin(_anim_t * (14.0 if attached >= 0 else 4.0)) * 0.5
				(_parts["arm_l"] as Node3D).rotation.x = swing
				(_parts["arm_r"] as Node3D).rotation.x = -swing


func _client_motion(delta: float, mission: MissionLevel) -> void:
	if attached >= 0:
		global_position = global_position.lerp(_attach_point(mission.ship), NetUtil.smooth(20.0, delta))
		return
	_since_sync += delta
	var target := net_pos + net_vel * minf(_since_sync, 0.3)
	if global_position.distance_to(target) > 15.0:
		global_position = target
		reset_physics_interpolation()
	else:
		global_position = global_position.lerp(target, NetUtil.smooth(10.0, delta))


func _attach_point(ship: Mothership) -> Vector3:
	if kind == Kind.CRITTER:
		var hp_def: Array = ship.hull_point(attached)
		return ship.to_global(hp_def[0] + hp_def[1] * 0.45)
	return ship.to_global(ship.hatch(attached)["outside"] + Vector3(0, 0.55, 0))


# --- Server AI ---------------------------------------------------------------------------------

func _think(delta: float, mission: MissionLevel) -> void:
	var ship := mission.ship
	if ship.at_derelict():
		_roam(delta, mission)
		return
	_roaming = false
	match kind:
		Kind.SPITTER:
			_think_spitter(delta, mission)
		Kind.CRITTER:
			_think_latcher(delta, mission, ship.claim_hull_point.bind(get_instance_id()))
		Kind.INFILTRATOR:
			_think_latcher(delta, mission, ship.claim_hatch.bind(get_instance_id()))


func _think_spitter(delta: float, mission: MissionLevel) -> void:
	var ship := mission.ship
	var target := Vector3.ZERO
	var target_vel := Vector3.ZERO
	var has_target := false
	var ship_center := ship.to_global(ship.shield_center())
	if ship.alive and ship_center.distance_to(global_position) < AGGRO_RANGE:
		target = ship_center
		target_vel = ship.velocity
		has_target = true
	# A scout out flying close by draws its fire.
	var scout: Scout = null
	var scout_d := 45.0
	for sc in mission.flying_scouts():
		var d := sc.global_position.distance_to(global_position)
		if d < scout_d:
			scout_d = d
			scout = sc
	if scout:
		if not has_target or scout_d < ship_center.distance_to(global_position) * 0.6:
			target = scout.global_position
			target_vel = scout.velocity
			has_target = true
	var speed := float(KIND_STATS[kind]["speed"])
	var desired := Vector3.ZERO
	if has_target:
		var to := target - global_position
		var dist := to.length()
		var radial := -to / maxf(dist, 0.01)
		var tangent := radial.cross(Vector3.UP).normalized() * _orbit
		var range_err := dist - _range
		desired = (-radial * clampf(range_err * 0.25, -1.0, 1.0) + tangent * 0.6).normalized() * speed + target_vel
		_spit_cd -= delta
		if _spit_cd <= 0.0 and dist < 62.0:
			_spit_cd = randf_range(2.2, 3.4)
			if _line_of_sight(target):
				var lead := target + target_vel * (dist / SPIT_SPEED)
				var dir := (lead - global_position).normalized()
				mission.projectiles.fire("spit", global_position + dir * 1.8, dir * SPIT_SPEED, 8.0 * dmg_mult)
	else:
		desired = _wander_velocity(delta, speed * 0.35)
	_steer(delta, desired, 14.0, true, mission)


## Shared behaviour for critters and infiltrators: fly to a free point on the hull and latch on.
func _think_latcher(delta: float, mission: MissionLevel, claim: Callable) -> void:
	var ship := mission.ship
	if attached >= 0:
		if not ship.alive:
			_detach(ship)
			return
		global_position = _attach_point(ship)
		var local_out: Vector3 = ship.hull_point(attached)[1] if kind == Kind.CRITTER else Vector3.UP
		var out := ship.global_basis * local_out
		net_dir = -out
		net_vel = ship.velocity
		if kind == Kind.CRITTER:
			_scratch += delta
			if _scratch >= 0.5:
				_scratch -= 0.5
				ship.apply_damage(1.2 * dmg_mult, global_position, "scratch")
		else:
			if ship.shield_down:
				_breach += delta
				if _breach >= 3.5:
					ship.spawn_boarder(attached, hp_mult)
					ship.release_hatch(attached, get_instance_id())
					attached = -1
					_claim = -1
					queue_free()
			else:
				_breach = 0.0
				_scratch += delta
				if _scratch >= 1.0:
					_scratch -= 1.0
					ship.apply_damage(1.0 * dmg_mult, global_position, "scratch")
		return
	var speed := float(KIND_STATS[kind]["speed"])
	var desired := Vector3.ZERO
	var dist_ship := ship.global_position.distance_to(global_position)
	if ship.alive and dist_ship < AGGRO_RANGE:
		if _claim < 0:
			_claim = claim.call()
		if _claim >= 0:
			var goal: Vector3
			if kind == Kind.CRITTER:
				var hp_def: Array = ship.hull_point(_claim)
				goal = ship.to_global(hp_def[0] + hp_def[1] * 0.45)
			else:
				goal = ship.to_global(ship.hatch(_claim)["outside"] + Vector3(0, 0.55, 0))
			var to := goal - global_position
			if to.length() < 1.3:
				attached = _claim
				global_position = goal
				_since_sync = 0.0
				if kind == Kind.CRITTER and not mission.warned_critters:
					mission.warned_critters = true
					ship.notify.rpc("Critters are clawing at the hull! Launch the scout to shoot them off", 1)
				elif kind == Kind.INFILTRATOR and not mission.warned_infiltrators:
					mission.warned_infiltrators = true
					ship.notify.rpc("An infiltrator is on the roof - it will break in if the shield goes down!", 1)
				return
			desired = to.normalized() * speed + ship.velocity
			_steer(delta, desired, 26.0, to.length() > 12.0, mission)
			return
		# Every point taken: circle the ship menacingly.
		var radial := (global_position - ship.global_position).normalized()
		desired = (radial.cross(Vector3.UP).normalized() * speed * 0.6) + radial * (14.0 - dist_ship) * 0.5 + ship.velocity
	else:
		desired = _wander_velocity(delta, speed * 0.3)
	_steer(delta, desired, 18.0, true, mission)


## Let go of the hull point or hatch this alien is latched onto (or was flying to).
func _detach(ship: Mothership) -> void:
	var idx := attached if attached >= 0 else _claim
	if idx >= 0:
		if kind == Kind.CRITTER:
			ship.release_hull_point(idx, get_instance_id())
		else:
			ship.release_hatch(idx, get_instance_id())
	attached = -1
	_claim = -1


## The ship is down at an abandoned station: leave it alone. Latched aliens push off the hull, and
## every alien that was after the ship takes the tunnel beside the hangar as its new home and
## wanders about there (no spitting) until the ship is back out in the tunnel.
func _roam(delta: float, mission: MissionLevel) -> void:
	var ship := mission.ship
	var speed := float(KIND_STATS[kind]["speed"])
	if not _roaming:
		_roaming = true
		_breach = 0.0
		_scratch = 0.0
		var engaged := attached >= 0 or _claim >= 0 or ship.global_position.distance_to(global_position) < AGGRO_RANGE
		if attached >= 0:
			net_vel = (global_position - ship.to_global(ship.shield_center())).normalized() * speed
		_detach(ship)
		if engaged:
			home = mission.cave.center3(-global_position.z) + Vector3(randf_range(-6.0, 6.0), randf_range(-3.0, 3.0), 0.0)
			_wander_t = 0.0
	_steer(delta, _wander_velocity(delta, speed * 0.3), 18.0, true, mission)


func _wander_velocity(delta: float, speed: float) -> Vector3:
	_wander_t -= delta
	if _wander_t <= 0.0 or global_position.distance_to(_wander) < 2.0:
		_wander_t = randf_range(2.0, 5.0)
		_wander = home + Vector3(randf_range(-10, 10), randf_range(-6, 6), randf_range(-10, 10))
	return (_wander - global_position).normalized() * speed


func _steer(delta: float, desired: Vector3, accel: float, avoid_ship: bool, mission: MissionLevel) -> void:
	net_vel = net_vel.move_toward(desired, accel * delta)
	_avoid_t -= delta
	if _avoid_t <= 0.0:
		_avoid_t = 0.2
		var d := mission.cave.sdf(global_position)
		_avoid = mission.cave.open_dir(global_position) * clampf((d + 4.0) / 4.0, 0.0, 1.5) if d > -4.0 else Vector3.ZERO
	net_vel += _avoid * 40.0 * delta
	if avoid_ship:
		var ship := mission.ship
		var local := (ship.to_local(global_position) - ship.shield_center()) / ship.shield_radii()
		var r := local.length()
		if r < 1.35:
			var push := ship.global_basis * (local.normalized() * ship.shield_radii()).normalized()
			net_vel += push * (1.35 - r) * 60.0 * delta
	var max_speed := float(KIND_STATS[kind]["speed"]) * 1.5 + mission.ship.velocity.length()
	net_vel = net_vel.limit_length(max_speed)
	global_position += net_vel * delta
	if net_vel.length_squared() > 0.5:
		net_dir = net_vel


func _line_of_sight(target: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(global_position, target, Game.LAYER_CAVE)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## Server: damage from weapons. Latched aliens are only reachable by the scout.
func take_damage(amount: float, info: Dictionary) -> void:
	if not multiplayer.is_server() or hp <= 0.0:
		return
	hp -= amount
	if hp <= 0.0:
		_die(str(info.get("source", "")))


func _die(_source: String) -> void:
	var mission := Game.mission as MissionLevel
	if mission and mission.ship:
		_detach(mission.ship)
	if mission:
		mission.kills += 1
		mission.fx_event.rpc("alien_die", global_position, int(kind))
	queue_free()


func _exit_tree() -> void:
	# Release any claimed hull point when despawned for other reasons.
	if multiplayer.is_server() and _claim >= 0:
		var mission := Game.mission as MissionLevel
		if mission and is_instance_valid(mission.ship):
			if kind == Kind.CRITTER:
				mission.ship.release_hull_point(_claim, get_instance_id())
			elif kind == Kind.INFILTRATOR:
				mission.ship.release_hatch(_claim, get_instance_id())
