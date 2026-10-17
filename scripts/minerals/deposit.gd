class_name Deposit
extends Node3D
## A crystal cluster growing out of the cave wall.
##
## The mining laser (or the scout's guns, for fuel crystals) wears it down; every quarter of its
## health breaks off chunks that float away and get pulled in to the tip of the mothership's mining
## laser (fuel chunks are collected by the scout instead).

const TYPES := {
	"ferrite": {"name": "Ferrite", "color": Color(0.95, 0.55, 0.3), "value": 2, "hp": 60.0, "chunks": 4},
	"cobalt": {"name": "Cobaltite", "color": Color(0.3, 0.6, 1.0), "value": 4, "hp": 85.0, "chunks": 4},
	"aurium": {"name": "Aurium", "color": Color(1.0, 0.82, 0.25), "value": 6, "hp": 110.0, "chunks": 5},
	"voidstone": {"name": "Voidstone", "color": Color(0.8, 0.35, 1.0), "value": 9, "hp": 150.0, "chunks": 5},
	"fuel": {"name": "Fuel crystal", "color": Color(1.0, 0.38, 0.12), "value": 0, "hp": 40.0, "chunks": 5, "fuel": 7.0},
}

var kind := "ferrite"
var hp := 60.0
var max_hp := 60.0
var size := 1.0
var normal := Vector3.UP
var crystal_seed := 0
var chunks_total := 4
var _chunks_out := 0
var _cluster: Node3D
var _mat: StandardMaterial3D
var _last_hp := -1.0
var _flash := 0.0


func _init() -> void:
	NetUtil.add_sync(self, [], ["hp"], 0.1)


func setup(data: Dictionary) -> void:
	name = str(data["name"])
	kind = str(data["kind"])
	position = data["pos"]
	normal = data["nrm"]
	size = float(data["size"])
	crystal_seed = int(data["seed"])
	var t: Dictionary = TYPES[kind]
	max_hp = float(t["hp"]) * size
	hp = max_hp
	chunks_total = maxi(2, int(round(float(t["chunks"]) * size)))


func _ready() -> void:
	add_to_group("deposits")
	var up := normal.normalized()
	var side := up.cross(Vector3.RIGHT if absf(up.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD).normalized()
	basis = Basis(side, up, side.cross(up))
	var t: Dictionary = TYPES[kind]
	var col: Color = t["color"]
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = col.darkened(0.25)
	_mat.metallic = 0.2
	_mat.roughness = 0.15
	_mat.emission_enabled = true
	_mat.emission = col
	_mat.emission_energy_multiplier = 1.6
	_mat.rim_enabled = true
	_mat.rim = 0.6
	_cluster = Node3D.new()
	add_child(_cluster)
	var rng := RandomNumberGenerator.new()
	rng.seed = crystal_seed
	var count := rng.randi_range(5, 9)
	var base_mat := Models.mat(Color(0.2, 0.18, 0.17), 0.1, 0.9)
	var rock := MeshInstance3D.new()
	rock.mesh = Models.blob_mesh(crystal_seed % 7, 1.0, 0.35, 10)
	rock.material_override = base_mat
	rock.scale = Vector3(1.6, 0.6, 1.6) * size
	_cluster.add_child(rock)
	for i in count:
		var mi := MeshInstance3D.new()
		mi.mesh = Models.crystal_mesh()
		mi.material_override = _mat
		var h := rng.randf_range(1.0, 2.6) * size * (1.3 if i == 0 else 1.0)
		var w := rng.randf_range(1.6, 2.6) * size
		mi.scale = Vector3(w, h, w)
		var tilt := 0.0 if i == 0 else rng.randf_range(0.25, 0.85)
		mi.rotation = (Basis(Vector3.UP, rng.randf_range(0, TAU)) * Basis(Vector3.RIGHT, tilt)).get_euler()
		mi.position = Vector3(rng.randf_range(-0.6, 0.6), 0, rng.randf_range(-0.6, 0.6)) * size
		_cluster.add_child(mi)
	if kind in ["aurium", "voidstone", "fuel"]:
		var l := OmniLight3D.new()
		l.light_color = col
		l.light_energy = 1.2
		l.omni_range = 7.0 * size
		l.position = Vector3(0, 1.5 * size, 0)
		add_child(l)
	var area := Area3D.new()
	area.collision_layer = Game.LAYER_MINERAL
	area.collision_mask = 0
	area.monitoring = false
	area.set_meta("target", self)
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 1.7 * size
	cs.shape = sh
	cs.position = Vector3(0, 1.0 * size, 0)
	area.add_child(cs)
	add_child(area)
	_last_hp = hp


func _process(delta: float) -> void:
	if hp < _last_hp - 0.01:
		_flash = 1.0
	_last_hp = hp
	_flash = maxf(0.0, _flash - delta * 4.0)
	var f := clampf(hp / max_hp, 0.0, 1.0)
	_cluster.scale = Vector3.ONE * lerpf(0.45, 1.0, f)
	_mat.emission_energy_multiplier = 1.6 + _flash * 4.0


func display_name() -> String:
	return TYPES[kind]["name"]


## Server: mining/scout damage. Turret fire only chips the rock without mining it.
func take_damage(amount: float, info: Dictionary) -> void:
	if not multiplayer.is_server() or hp <= 0.0:
		return
	var source := str(info.get("source", ""))
	var mult := 0.0
	if source == "mining":
		mult = 1.0
	elif source == "scout":
		mult = 1.0 if kind == "fuel" else 0.3
	if mult <= 0.0:
		return
	hp = maxf(0.0, hp - amount * mult)
	var due := int(floor((1.0 - hp / max_hp) * chunks_total))
	if hp <= 0.0:
		due = chunks_total
	while _chunks_out < due:
		_chunks_out += 1
		_spawn_chunk()
	if hp <= 0.0:
		Game.mission.fx_event.rpc("crystal_break", global_position + normal * size, TYPES[kind]["color"])
		queue_free()


func _spawn_chunk() -> void:
	var t: Dictionary = TYPES[kind]
	var up := normal.normalized()
	var jitter := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.5
	# Shards burst off the wall and drift towards whoever collects them.
	var collector := Vector3.ZERO
	var mission := Game.mission as MissionLevel
	var best := INF
	if kind == "fuel":
		for sc in mission.flying_scouts():
			var d := sc.global_position.distance_to(global_position)
			if d < best:
				best = d
				collector = sc.global_position
	if collector == Vector3.ZERO and mission.ship:
		collector = mission.ship.collector_global(global_position)
	var toward := (collector - global_position).normalized() if collector != Vector3.ZERO else Vector3.ZERO
	var vel := (up + jitter + toward * 1.2).normalized() * randf_range(4.0, 7.0)
	Game.mission.spawn_pickup(kind, global_position + up * (1.2 * size) + jitter, vel, int(t["value"]), float(t.get("fuel", 0.0)))
