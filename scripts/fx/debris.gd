class_name Debris
extends Node3D
## Spent casings and dropped magazines (and the Revolver's moon clips). They fly, tumble, bounce off
## the floor and the walls (and clink as they land) and come to rest lying on their side. They live in the mothership's space,
## so a casing dropped aboard a ship in flight stays where it fell. Purely local: every peer throws
## them out of the guns it sees firing.
##
## One per ship (Debris.of()). Casings are drawn in batches (a MultiMesh per kind, CrewWeapons
## CASINGS); a magazine is a copy of the one that was in the gun. They don't stay for long: a few
## seconds after they were thrown out they shrink away (FADE), and pieces left outside the ship are
## cleared once it takes off.

## Ship-local gravity (m/s^2), how much speed survives a bounce (along the surface normal and
## across it), and below what speed a piece on a floor comes to rest.
const GRAVITY := 9.8
const BOUNCE := 0.32
const FRICTION := 0.55
const REST_SPEED := 0.35
## Most pieces kept per kind (the oldest go first), how long they stay (s, from when they were thrown
## out) and how long they take to shrink away at the end of that.
const MAX_CASINGS := 48
const MAX_MAGS := 10
const CASING_LIFE := 6.0
const MAG_LIFE := 9.0
const FADE := 0.8
## What the pieces bounce off: the ship's interior, the stations and the rock.
const MASK := Game.LAYER_INTERIOR | Game.LAYER_STATION | Game.LAYER_CAVE
## Sounds: how many may start a second, and their players (separate from Sfx's pool, so a burst of
## casings never cuts other sounds short).
const SOUNDS_PER_S := 9.0
const PLAYERS := 4

var ship: Mothership
## {"kind", "pos", "vel", "rot" (Quaternion), "spin" (rad/s, local), "rest", "age", "bounces",
## "size" (half height above the floor at rest), "node", "lie" (how it lies at rest) and "sound"
## (magazines)}.
var _pieces: Array[Dictionary] = []
var _batches: Dictionary = {}
var _players: Array[AudioStreamPlayer3D] = []
var _next_player := 0
var _sound_budget := 0.0


static func of(s: Mothership) -> Debris:
	if s == null or not is_instance_valid(s):
		return null
	var d := s.get_node_or_null("Debris") as Debris
	if d == null:
		d = Debris.new()
		d.name = "Debris"
		d.ship = s
		s.add_child(d)
	return d


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	for kind: String in CrewWeapons.CASINGS:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = CrewWeapons.casing_mesh(kind)
		mm.instance_count = MAX_CASINGS
		mm.visible_instance_count = 0
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Big enough for anything the crew can walk to (the ship, a station's rooms).
		mmi.custom_aabb = AABB(Vector3(-80, -30, -80), Vector3(160, 60, 160))
		add_child(mmi)
		_batches[kind] = mm
	for i in PLAYERS:
		var p := AudioStreamPlayer3D.new()
		p.max_distance = 40.0
		p.unit_size = 4.0
		add_child(p)
		Sfx.track(p)
		_players.append(p)


## Throw a casing of `kind` out from ship-local `pos` with ship-local velocity `vel`, turned `rot`
## (its length along local Y), spinning `spin` (rad/s, about its own axes).
func eject(kind: String, pos: Vector3, vel: Vector3, rot: Basis, spin: Vector3) -> void:
	if not CrewWeapons.CASINGS.has(kind):
		return
	_trim(kind, MAX_CASINGS - 1)
	_pieces.append({"kind": kind, "pos": pos, "vel": vel, "rot": rot.get_rotation_quaternion(), "spin": spin, "rest": false,
		"age": 0.0, "bounces": 0, "size": float(CrewWeapons.CASINGS[kind][0])})


## Drop a magazine: `mag` is the gun's magazine node (it is copied), dropping from ship-local
## transform `xform` with ship-local velocity `vel`. At rest it lies turned `lie` (its own frame,
## before a turn about the floor's normal), `size` above the floor, and it lands with `sound`.
func drop_mag(mag: Node3D, xform: Transform3D, vel: Vector3, lie := Basis(Vector3.FORWARD, PI / 2.0), size := 0.022,
		sound := "mag_drop") -> void:
	if mag == null or not is_instance_valid(mag):
		return
	_trim("mag", MAX_MAGS - 1)
	var copy := mag.duplicate() as Node3D
	copy.visible = true
	copy.transform = Transform3D.IDENTITY
	var holder := Node3D.new()
	holder.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	holder.transform = xform
	add_child(holder)
	holder.add_child(copy)
	for c in copy.find_children("*", "GeometryInstance3D", true, false):
		(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var spin := Vector3(randf_range(-6.0, 6.0), randf_range(-3.0, 3.0), randf_range(-6.0, 6.0))
	_pieces.append({"kind": "mag", "pos": xform.origin, "vel": vel, "rot": xform.basis.get_rotation_quaternion(), "spin": spin,
		"rest": false, "age": 0.0, "bounces": 0, "size": size, "node": holder, "lie": lie, "sound": sound})


## How many pieces of a kind are about ("mag" for magazines); for the tests.
func count(kind: String) -> int:
	var n := 0
	for p in _pieces:
		if p["kind"] == kind:
			n += 1
	return n


## How many pieces are still moving; for the tests.
func moving() -> int:
	var n := 0
	for p in _pieces:
		if not p["rest"]:
			n += 1
	return n


func _trim(kind: String, keep: int) -> void:
	var n := count(kind)
	var i := 0
	while n > keep and i < _pieces.size():
		if _pieces[i]["kind"] == kind:
			_remove(i)
			n -= 1
		else:
			i += 1


func _remove(i: int) -> void:
	var node: Node3D = _pieces[i].get("node")
	if node and is_instance_valid(node):
		node.queue_free()
	_pieces.remove_at(i)


func _physics_process(delta: float) -> void:
	if ship == null or not is_instance_valid(ship):
		return
	_sound_budget = minf(2.0, _sound_budget + delta * SOUNDS_PER_S)
	var space := get_world_3d().direct_space_state
	var landed := ship.landing == Mothership.Dock.LANDED
	var i := 0
	while i < _pieces.size():
		var p: Dictionary = _pieces[i]
		p["age"] = float(p["age"]) + delta
		var life := MAG_LIFE if p["kind"] == "mag" else CASING_LIFE
		# Whatever was left out in a station stays behind when the ship takes off.
		if float(p["age"]) > life or (not landed and not ship.is_aboard(p["pos"])):
			_remove(i)
			continue
		if not p["rest"]:
			_step(p, delta, space)
		var node: Node3D = p.get("node")
		if node:
			node.scale = Vector3.ONE * _shrink(p)
		i += 1
	_update_batches()


## How big a piece still is (1 .. 0 as it shrinks away at the end of its life).
func _shrink(p: Dictionary) -> float:
	var life := MAG_LIFE if p["kind"] == "mag" else CASING_LIFE
	return clampf((life - float(p["age"])) / FADE, 0.0, 1.0)


## One step of a piece in flight: gravity, a little air drag, tumbling, and bouncing off whatever it
## hits (it rests once it lies slow on something flat).
func _step(p: Dictionary, delta: float, space: PhysicsDirectSpaceState3D) -> void:
	var vel: Vector3 = p["vel"]
	vel.y -= GRAVITY * delta
	vel *= 1.0 - 0.15 * delta
	var pos: Vector3 = p["pos"]
	var to := pos + vel * delta
	var size := float(p["size"])
	var q := PhysicsRayQueryParameters3D.create(ship.to_global(pos), ship.to_global(to + vel.normalized() * size), MASK)
	var hit := space.intersect_ray(q)
	var spin: Vector3 = p["spin"]
	if hit.is_empty():
		p["pos"] = to
	else:
		var n := (ship.global_basis.inverse() * (hit["normal"] as Vector3)).normalized()
		var at := ship.to_local(hit["position"]) + n * size
		var vn := vel.dot(n)
		var impact := -vn
		vel = (vel - n * vn) * FRICTION - n * vn * BOUNCE
		spin = spin * 0.5 + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * vel.length() * 25.0
		p["pos"] = at
		p["bounces"] = int(p["bounces"]) + 1
		if impact > 0.6 and int(p["bounces"]) <= 3:
			_clink(p, hit["position"], impact)
		if n.y > 0.7 and (vel.length() < REST_SPEED or int(p["bounces"]) > 6):
			_settle(p, n, at)
			return
	p["vel"] = vel
	p["spin"] = spin
	var rot: Quaternion = p["rot"]
	if spin.length_squared() > 0.0001:
		rot = (rot * Quaternion(spin.normalized(), spin.length() * delta)).normalized()
	p["rot"] = rot
	var node: Node3D = p.get("node")
	if node:
		node.transform = Transform3D(Basis(rot), p["pos"])


## Lay a piece down on its side on the floor (normal `n`), turned whichever way it was spinning.
func _settle(p: Dictionary, n: Vector3, at: Vector3) -> void:
	p["rest"] = true
	p["vel"] = Vector3.ZERO
	var yaw := randf() * TAU
	var lying := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, PI / 2.0)
	if p["kind"] == "mag":
		# A magazine lands flat on its side (a moon clip flat on its face).
		lying = Basis(Vector3.UP, yaw) * (p.get("lie", Basis(Vector3.FORWARD, PI / 2.0)) as Basis)
	var tilt := Quaternion(Vector3.UP, n) if n.cross(Vector3.UP).length() > 0.001 else Quaternion.IDENTITY
	p["rot"] = (tilt * lying.get_rotation_quaternion()).normalized()
	p["pos"] = at
	var node: Node3D = p.get("node")
	if node:
		node.transform = Transform3D(Basis(p["rot"]), at)


func _clink(p: Dictionary, global_pos: Vector3, impact: float) -> void:
	if _sound_budget < 1.0:
		return
	_sound_budget -= 1.0
	var kind: String = p["kind"]
	var id := str(p.get("sound", "mag_drop")) if kind == "mag" else ("shell_drop" if kind == "shell" or kind == "40mm" else "casing")
	var pl := _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	pl.stream = Sfx.stream(id)
	pl.global_position = global_pos
	pl.volume_db = (-8.0 if kind == "mag" else (-12.0 if kind == "40mm" else -16.0)) + clampf(linear_to_db(impact / 3.0), -10.0, 2.0)
	pl.pitch_scale = randf_range(0.85, 1.2) * (1.0 if int(p["bounces"]) == 1 else 1.1) * (0.7 if kind == "40mm" else 1.0)
	pl.play()


## The casings' batches follow their pieces (the magazines move their own nodes).
func _update_batches() -> void:
	var shown := {}
	for kind: String in _batches:
		shown[kind] = 0
	for p in _pieces:
		var kind: String = p["kind"]
		if not _batches.has(kind):
			continue
		var mm: MultiMesh = _batches[kind]
		var k: int = shown[kind]
		if k >= mm.instance_count:
			continue
		var rot: Quaternion = p["rot"]
		mm.set_instance_transform(k, Transform3D(Basis(rot).scaled(Vector3.ONE * _shrink(p)), p["pos"]))
		shown[kind] = k + 1
	for kind: String in _batches:
		(_batches[kind] as MultiMesh).visible_instance_count = shown[kind]
