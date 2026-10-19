class_name Hive
extends Boarder
## A crawlers' nest: a spongy growth of hollow tubes full of holes, grown out of a wall, a ceiling or
## the floor. It never moves or fights. The crawlers born in it (Crawler.hive_id) keep to the room
## round it; while it lives it slowly breeds new ones to replace those killed (one every BREED_TIME
## seconds, while nobody is within QUIET metres).

const BREED_TIME := 30.0
const QUIET := 6.0

var hive_id := 0
## How many crawlers it keeps.
var brood := 4
var _breed_t := BREED_TIME
var _up := Vector3.UP


func _setup(data: Dictionary) -> void:
	hive_id = int(data.get("hive_id", 0))
	brood = int(data.get("brood", 4))
	_up = data.get("up", Vector3.UP)
	var up := _up.normalized()
	var side := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	basis = Basis(side, up, side.cross(up))


func save_data() -> Dictionary:
	return {"hive_id": hive_id, "brood": brood, "up": _up}


func _think_outside(delta: float, ship: Mothership) -> void:
	attacking = false
	_breed_t -= delta
	if _breed_t > 0.0:
		return
	_breed_t = BREED_TIME
	var alive := 0
	for c in get_parent().get_children():
		var cr := c as Crawler
		if cr and cr.hive_id == hive_id and not cr.is_queued_for_deletion():
			alive += 1
	if alive >= brood:
		return
	for c in ship.crew_root.get_children():
		var p := c as CrewMember
		if p and p.alive and p.position.distance_to(position) < QUIET:
			return
	var floor_pos := Vector3(position.x, Barnacle.deck_floor(), position.z) + Vector3(_up.x, 0, _up.z) * 0.8
	ship.spawn_hostile("crawler", floor_pos, {"hive_id": hive_id, "hp": float(KIND_STATS["crawler"]["hp"]) * ship.outpost_hp_mult(),
		"dmg": dmg_mult})
	Game.mission.fx_event.rpc("hive_birth", global_position, 0)


func center_global() -> Vector3:
	return global_transform * Vector3(0, 0.45, 0)


# --- Looks -------------------------------------------------------------------------------------

func _build(model: Node3D) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(name))
	var flesh := Alien.organic(Color(0.42, 0.34, 0.2), Color(0.85, 0.75, 0.3), 0.7, 8.0)
	var hole := Models.mat(Color(0.02, 0.015, 0.01), 0.0, 1.0)
	var base := MeshInstance3D.new()
	base.mesh = Models.blob_mesh(61, 0.8, 0.35, 16)
	base.material_override = flesh
	base.scale = Vector3(1.0, 0.45, 1.0)
	base.position = Vector3(0, 0.15, 0)
	model.add_child(base)
	# Tubes standing out of it, each ending in a hole; smaller holes pocking its sides.
	for i in rng.randi_range(6, 9):
		var a := rng.randf() * TAU
		var r := rng.randf_range(0.1, 0.55)
		var h := rng.randf_range(0.35, 0.9)
		var tilt := Vector3(rng.randf_range(-25, 25), 0, rng.randf_range(-25, 25))
		var foot := Vector3(cos(a) * r, 0.15, sin(a) * r)
		var tube := Node3D.new()
		tube.position = foot
		tube.rotation_degrees = tilt
		model.add_child(tube)
		var tr := rng.randf_range(0.09, 0.16)
		Models.cylinder(tube, Vector3(0, h * 0.5, 0), tr, h, flesh, Vector3.ZERO, tr * 0.85, 10)
		Models.cylinder(tube, Vector3(0, h + 0.005, 0), tr * 0.62, 0.02, hole, Vector3.ZERO, -1.0, 10)
		for k in 2:
			Models.sphere(tube, Vector3(tr * 0.95 * (1.0 if k == 0 else -1.0), h * rng.randf_range(0.3, 0.7), 0), tr * 0.28, hole)
	for i in 10:
		var a := rng.randf() * TAU
		Models.sphere(model, Vector3(cos(a) * 0.62, 0.22, sin(a) * 0.62), rng.randf_range(0.04, 0.08), hole)
	return {}


func _animate(_delta: float) -> void:
	# It breathes.
	var m: Node3D = get_node_or_null("Model")
	if m:
		var s := 1.0 + sin(_anim_t * 1.3) * 0.025
		m.scale = Vector3(s, 1.0 + sin(_anim_t * 1.3 + 0.5) * 0.04, s)
