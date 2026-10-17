class_name Nest
extends Node3D
## An alien hive on the cave wall, surrounded by egg sacs.
##
## Every living sac keeps hatching aliens forever. The nest becomes agitated when the mothership
## comes close or a sac is hit, and then hatches much faster with a higher cap. Destroying every
## sac destroys the nest and drops a cache of rare minerals.

const IDLE_INTERVAL := Vector2(16.0, 24.0)
const AGITATED_INTERVAL := Vector2(9.0, 13.0)
## Live hatchlings a nest keeps around (idle / agitated) and the shortest gap between two hatches.
const IDLE_CAP := 2
const AGITATED_CAP := 5
const HATCH_GAP := 1.6
## How long a hit sac keeps the nest agitated.
const HIT_AGITATION := 15.0
## Egg sac health at the surface; deeper down it grows by half as much as other aliens' health.
const SAC_HP := 55.0
const ACTIVE_RANGE := 150.0
const AGITATE_RANGE := 55.0

const SAC_SHADER := """
shader_type spatial;
render_mode blend_mix, cull_back, depth_draw_always;
uniform vec4 color : source_color = vec4(0.65, 1.0, 0.2, 1.0);
instance uniform float flash = 0.0;
instance uniform float pulse_rate = 3.0;
void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 1.6);
	float pulse = 0.5 + 0.5 * sin(TIME * pulse_rate);
	ALBEDO = color.rgb * 0.25;
	EMISSION = color.rgb * (0.35 + rim * 1.6 + pulse * 0.35) + vec3(flash * 2.5);
	ALPHA = 0.55 + rim * 0.35;
	ROUGHNESS = 0.15;
	SPECULAR = 0.8;
}
"""

static var _sac_shader: Shader

# Replicated (server authority).
var sac_hp: Array = []
var agitated := false

var normal := Vector3.UP
var sac_pos: Array = []
var sac_nrm: Array = []
var hp_mult := 1.0
var dmg_mult := 1.0
var infiltrator_bias := 0.0

var _sacs: Array[Node3D] = []
var _sac_meshes: Array[MeshInstance3D] = []
var _flash: Array[float] = []
var _last_hp: Array = []
var _hive: Node3D
var _hive_meshes: Array[GeometryInstance3D] = []
var _anim_t := 0.0
# Server state.
var _spawn_t: Array[float] = []
var _agitate_t := 0.0
var _hatch_gap := 0.0
var _spawned: Array[int] = []
var _seq := 0
var _dead := false


func _init() -> void:
	NetUtil.add_sync(self, [], ["sac_hp", "agitated"], 0.1)


func setup(data: Dictionary) -> void:
	name = str(data["name"])
	position = data["pos"]
	normal = data["nrm"]
	sac_pos = data["sacs"]
	sac_nrm = data["sac_nrm"]
	hp_mult = float(data.get("hp_mult", 1.0))
	dmg_mult = float(data.get("dmg_mult", 1.0))
	infiltrator_bias = float(data.get("infiltrators", 0.0))
	sac_hp = []
	for i in sac_pos.size():
		sac_hp.append(SAC_HP * (1.0 + (hp_mult - 1.0) * 0.5))


func _ready() -> void:
	add_to_group("nests")
	if _sac_shader == null:
		_sac_shader = Shader.new()
		_sac_shader.code = SAC_SHADER
	var up := normal.normalized()
	var side := up.cross(Vector3.RIGHT if absf(up.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD).normalized()
	# Hive mound.
	_hive = Node3D.new()
	add_child(_hive)
	_hive.global_basis = Basis(side, up, side.cross(up))
	var skin := Alien.organic(Color(0.2, 0.07, 0.12), Color(0.8, 1.0, 0.25), 1.2, 3.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(name)
	for i in 7:
		var mi := MeshInstance3D.new()
		mi.mesh = Models.blob_mesh(rng.randi() % 5, 1.0, 0.3, 14)
		mi.material_override = skin
		var s := rng.randf_range(1.4, 3.2)
		mi.scale = Vector3(s, s * rng.randf_range(0.7, 1.2), s)
		mi.position = Vector3(rng.randf_range(-2.5, 2.5), rng.randf_range(0.0, 1.8), rng.randf_range(-2.5, 2.5))
		_hive.add_child(mi)
		_hive_meshes.append(mi)
	var core_light := OmniLight3D.new()
	core_light.light_color = Color(0.7, 1.0, 0.3)
	core_light.omni_range = 18.0
	core_light.light_energy = 1.4
	core_light.position = up * 3.0
	add_child(core_light)
	# Egg sacs, tendrils and hitboxes (positions are global in the spawn data).
	var tendril := Alien.organic(Color(0.22, 0.08, 0.15), Color(0.6, 0.9, 0.2), 1.5, 8.0)
	for i in sac_pos.size():
		var p: Vector3 = sac_pos[i]
		var n: Vector3 = sac_nrm[i]
		var sac := Node3D.new()
		add_child(sac)
		sac.global_position = p
		var su := n.normalized()
		var ss := su.cross(Vector3.RIGHT if absf(su.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD).normalized()
		sac.global_basis = Basis(ss, su, ss.cross(su))
		var embryo := Models.sphere(sac, Vector3(0, 1.0, 0), 0.5, Models.mat(Color(0.05, 0.08, 0.02), 0.0, 0.8))
		embryo.name = "Embryo"
		var mat := ShaderMaterial.new()
		mat.shader = _sac_shader
		var shell := Models.sphere(sac, Vector3(0, 1.0, 0), 1.0, mat, Vector3(1.0, 1.35, 1.0), 20)
		shell.set_instance_shader_parameter("pulse_rate", rng.randf_range(2.0, 4.0))
		Models.sphere(sac, Vector3(0, 0.1, 0), 0.9, skin, Vector3(1.4, 0.5, 1.4))
		Models.strut(self, to_local(p), Vector3(rng.randf_range(-1, 1), 0.8, rng.randf_range(-1, 1)), 0.25, tendril)
		_sacs.append(sac)
		_sac_meshes.append(shell)
		_flash.append(0.0)
		var area := Area3D.new()
		area.collision_layer = Game.LAYER_ENEMY
		area.collision_mask = 0
		area.monitoring = false
		area.set_meta("target", self)
		area.set_meta("sac", i)
		var cs := CollisionShape3D.new()
		var sh := SphereShape3D.new()
		sh.radius = 1.5
		cs.shape = sh
		area.add_child(cs)
		sac.add_child(area)
		area.position = Vector3(0, 1.0, 0)
		_spawn_t.append(rng.randf_range(3.0, IDLE_INTERVAL.x))
	_last_hp = sac_hp.duplicate()
	_refresh_sacs()


func _process(delta: float) -> void:
	_anim_t += delta
	for i in _sacs.size():
		if i < _last_hp.size() and float(sac_hp[i]) < float(_last_hp[i]) - 0.01:
			_flash[i] = 1.0
		if _flash[i] > 0.0:
			_flash[i] = maxf(0.0, _flash[i] - delta * 4.0)
			_sac_meshes[i].set_instance_shader_parameter("flash", _flash[i])
		var pulse := 1.0 + sin(_anim_t * (5.0 if agitated else 2.0) + i) * (0.06 if agitated else 0.03)
		_sacs[i].scale = Vector3.ONE * pulse if float(sac_hp[i]) > 0.0 else Vector3.ONE
	if _last_hp != sac_hp:
		_refresh_sacs()
	_last_hp = sac_hp.duplicate()


func _refresh_sacs() -> void:
	for i in _sacs.size():
		var alive := float(sac_hp[i]) > 0.0
		_sac_meshes[i].visible = alive
		(_sacs[i].get_node("Embryo") as Node3D).visible = alive
		for c in _sacs[i].get_children():
			if c is Area3D:
				(c as Area3D).collision_layer = Game.LAYER_ENEMY if alive else 0


func alive_sacs() -> int:
	var n := 0
	for h in sac_hp:
		if float(h) > 0.0:
			n += 1
	return n


# --- Server ------------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server() or _dead:
		return
	var mission := Game.mission as MissionLevel
	if mission == null or mission.ship == null or not mission.ship.alive:
		return
	var dist := mission.ship.global_position.distance_to(global_position)
	if dist > ACTIVE_RANGE:
		return
	if dist < AGITATE_RANGE:
		_agitate_t = maxf(_agitate_t, 4.0)
	_agitate_t = maxf(0.0, _agitate_t - delta)
	var now_agitated := _agitate_t > 0.0
	if now_agitated != agitated:
		agitated = now_agitated
	var alive_spawn := 0
	for id in _spawned:
		if is_instance_id_valid(id):
			alive_spawn += 1
	var cap := AGITATED_CAP if agitated else IDLE_CAP
	var difficulty := sqrt(mission.difficulty())
	_hatch_gap = maxf(0.0, _hatch_gap - delta)
	for i in sac_hp.size():
		if float(sac_hp[i]) <= 0.0:
			continue
		_spawn_t[i] -= delta
		if _spawn_t[i] > 0.0:
			continue
		if _hatch_gap > 0.0:
			# Sacs take turns, so an agitated nest never bursts out a whole pack at once.
			_spawn_t[i] = _hatch_gap + randf() * 0.5
			continue
		var range_v := AGITATED_INTERVAL if agitated else IDLE_INTERVAL
		_spawn_t[i] = randf_range(range_v.x, range_v.y) / difficulty
		if alive_spawn >= cap:
			continue
		alive_spawn += 1
		_hatch_gap = HATCH_GAP
		_hatch(i, mission)


func _hatch(i: int, mission: MissionLevel) -> void:
	var r := randf()
	var kind := Alien.Kind.SPITTER
	if r < 0.32:
		kind = Alien.Kind.CRITTER
	elif r < 0.32 + 0.15 + infiltrator_bias:
		kind = Alien.Kind.INFILTRATOR
	var p: Vector3 = sac_pos[i] + (sac_nrm[i] as Vector3) * 2.6
	var alien: Node = mission.spawn_alien(kind, p, hp_mult, dmg_mult, name)
	if alien:
		_spawned.append(alien.get_instance_id())
	mission.fx_event.rpc("hatch", p, 0)


func take_damage(amount: float, info: Dictionary) -> void:
	if not multiplayer.is_server() or _dead:
		return
	var i := int(info.get("sac", -1))
	if i < 0 or i >= sac_hp.size() or float(sac_hp[i]) <= 0.0:
		return
	if str(info.get("source", "")) == "mining":
		amount *= 0.6 * float(info.get("vs_alien", 1.0))
	var hps := sac_hp.duplicate()
	hps[i] = maxf(0.0, float(hps[i]) - amount)
	sac_hp = hps
	_agitate_t = HIT_AGITATION
	var mission := Game.mission as MissionLevel
	if float(hps[i]) <= 0.0 and mission:
		mission.fx_event.rpc("sac_burst", sac_pos[i] + (sac_nrm[i] as Vector3), 0)
		if alive_sacs() == 0:
			_destroyed(mission)


func _destroyed(mission: MissionLevel) -> void:
	_dead = true
	mission.nests_destroyed += 1
	mission.ship.notify.rpc("Nest destroyed! It dropped a mineral cache", 0)
	mission.fx_event.rpc("nest_dead", global_position + normal * 2.0, 0)
	var kinds := ["cobalt", "aurium", "aurium", "voidstone"]
	for k in 5:
		var kind: String = kinds[mini(k, kinds.size() - 1)] if mission.ship.depth > 300.0 else "cobalt"
		var vel := (normal + Vector3(randf_range(-0.6, 0.6), randf_range(-0.6, 0.6), randf_range(-0.6, 0.6))).normalized() * randf_range(4.0, 7.0)
		mission.spawn_pickup(kind, global_position + normal * 3.0, vel, int(Deposit.TYPES[kind]["value"]), 0.0)
	# The husk stays as scenery; stop pulsing.
	agitated = false
