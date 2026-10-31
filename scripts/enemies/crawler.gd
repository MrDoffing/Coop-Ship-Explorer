class_name Crawler
extends Climber
## A crawler: a pale, many-fingered thing with a long tail, like a face-hugger. A pack lives round its
## nest (Hive) on the walls and the ceiling of a room or corridor. Whoever comes into its patch is
## leapt at: it springs off its wall in an arc at their chest, rakes them on the way and lands on the
## floor, then scuttles back up a wall for the next go. Crawlers aren't fast and they don't leave
## their patch to hunt anyone, unless they are shot at: then the whole pack hunts the crew out to
## HUNT_RADIUS from the nest for a while.

## How far from its nest (or where it was put) it keeps and strikes, and how far while angry
## (ANGRY_TIME seconds after being shot at).
const TERRITORY := 7.0
const HUNT_RADIUS := 18.0
const ANGRY_TIME := 25.0
## Leaping: from within LEAP_RANGE (but no closer than LEAP_MIN) of a chest, at LEAP_SPEED; it rakes
## whatever chest it passes within LEAP_HIT of. Then LAND_TIME on the floor, and LEAP_COOLDOWN
## before it leaps again.
const LEAP_RANGE := 4.6
const LEAP_MIN := 0.9
const LEAP_SPEED := 7.0
const LEAP_HIT := 0.75
const LAND_TIME := Vector2(0.8, 1.3)
const LEAP_COOLDOWN := Vector2(1.6, 2.8)
## mode (replicated): crawling, in the air, down on the floor after a leap.
enum { CRAWL, LEAP, LANDED }

var hive_id := -1
var _angry := 0.0
var _leap_a := Vector3.ZERO
var _leap_b := Vector3.ZERO
var _leap_c := Vector3.ZERO
var _leap_t := 0.0
var _leap_time := 0.5
var _leap_hit := false
var _leap_victim := 0
var _land_t := 0.0
var _leap_cd := 0.0


func _setup(data: Dictionary) -> void:
	super._setup(data)
	hive_id = int(data.get("hive_id", -1))
	climb_bias = 0.85
	_leap_cd = randf_range(0.5, 1.5)


func save_data() -> Dictionary:
	return {"hive_id": hive_id}


func want_floor() -> bool:
	return mode == LANDED


## The middle of its patch: its nest while it lives, else where it was put.
func _centre() -> Vector3:
	for c in get_parent().get_children():
		var h := c as Hive
		if h and h.hive_id == hive_id and not h.is_queued_for_deletion():
			return Vector3(h.position.x, home.y, h.position.z)
	return home


func _server_tick(delta: float, ship: Mothership) -> void:
	_leap_cd -= delta
	_angry = maxf(0.0, _angry - delta)
	if mode == LEAP:
		_fly(delta, ship)
		return
	if mode == LANDED:
		_land_t -= delta
		if _land_t <= 0.0:
			mode = CRAWL
			_climb_t = 0.0
	super._server_tick(delta, ship)


func _think_outside(delta: float, ship: Mothership) -> void:
	_repath -= delta
	attacking = false
	var centre := _centre()
	var radius := HUNT_RADIUS if _angry > 0.0 else TERRITORY
	var victim := _station_target(delta, ship, radius, radius + 4.0)
	if victim and victim.position.distance_to(centre) > radius + 1.5:
		# Out of its patch: let them go.
		victim = null
		_target_id = 0
	if victim == null:
		if position.distance_to(centre) > TERRITORY * 0.8:
			if _repath <= 0.0:
				_set_goal(ship, _graph(ship), centre)
			_follow_path(delta)
		else:
			_idle(delta, TERRITORY * 0.5)
		_separate(delta)
		return
	var chest := victim.position + Vector3(0, aim_height(victim) - 0.05, 0)
	var d := _surf_pos.distance_to(chest)
	if mode == CRAWL and _leap_cd <= 0.0 and d < LEAP_RANGE and d > LEAP_MIN \
			and _clear_from(ship, ship.to_global(_surf_pos), ship.to_global(chest)):
		_start_leap(ship, victim, chest)
		return
	var flat := victim.position - position
	flat.y = 0.0
	if flat.length() > LEAP_RANGE * 0.55 and mode == CRAWL:
		var goal := victim.position
		if goal.distance_to(centre) > radius:
			goal = centre + (goal - centre).limit_length(radius)
		if _repath <= 0.0 or _goal.distance_to(goal) > 1.5:
			_set_goal(ship, _graph(ship), goal)
		_follow_path(delta)
	else:
		_face(flat)
	_separate(delta)


## Spring off the surface at a chest (or a sentry turret's gun): an arc from the body over it (a
## little above it) down to the floor beyond.
func _start_leap(ship: Mothership, victim: Node3D, chest: Vector3) -> void:
	mode = LEAP
	attacking = true
	_leap_a = _surf_pos
	var dir := Vector3(chest.x - _leap_a.x, 0, chest.z - _leap_a.z).normalized()
	var land := Vector3(chest.x, _ground.y, chest.z) + dir * 0.9
	# Not into a wall beyond them.
	var q := PhysicsRayQueryParameters3D.create(ship.to_global(chest), ship.to_global(land + Vector3(0, 0.3, 0)), Game.LAYER_STATION)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		land = ship.to_local(hit["position"]) - dir * 0.35
		land.y = _ground.y
	_leap_c = land
	_leap_b = chest * 2.0 - (_leap_a + _leap_c) * 0.5 + Vector3(0, 0.25, 0)
	_leap_time = clampf((_leap_a.distance_to(chest) + chest.distance_to(land)) / LEAP_SPEED, 0.35, 0.9)
	_leap_t = 0.0
	_leap_hit = false
	_leap_victim = victim.get_instance_id()
	Game.mission.fx_event.rpc("crawler_leap", ship.to_global(_leap_a), 0)


## In the air: along the arc, raking the chest it passes, and down onto the floor.
func _fly(delta: float, ship: Mothership) -> void:
	_leap_t += delta
	var k := minf(_leap_t / _leap_time, 1.0)
	var p := _leap_a.lerp(_leap_b, k).lerp(_leap_b.lerp(_leap_c, k), k)
	var ahead := _leap_a.lerp(_leap_b, minf(k + 0.05, 1.0)).lerp(_leap_b.lerp(_leap_c, minf(k + 0.05, 1.0)), minf(k + 0.05, 1.0))
	var dir := ahead - p
	position = p
	if dir.length_squared() > 0.000001:
		basis = Basis.looking_at(dir.normalized(), Vector3.UP if absf(dir.normalized().y) < 0.95 else Vector3.FORWARD)
	if not _leap_hit:
		var victim := instance_from_id(_leap_victim) as Node3D
		if target_ok(ship, victim):
			var up := Vector3(0, aim_height(victim) - 0.05, 0)
			if victim.position.distance_to(p - up) < LEAP_HIT + 0.4 and (victim.position + up).distance_to(p) < LEAP_HIT:
				_leap_hit = true
				_claw(ship, victim)
	if k >= 1.0:
		mode = LANDED
		attacking = false
		_land_t = randf_range(LAND_TIME.x, LAND_TIME.y)
		_leap_cd = randf_range(LEAP_COOLDOWN.x, LEAP_COOLDOWN.y)
		_ground = _leap_c
		_surf_pos = _leap_c
		_surf_up = Vector3.UP
		_climb = 0
		_heading = atan2(-(_leap_c - _leap_a).x, -(_leap_c - _leap_a).z)
		position = _leap_c
		basis = Basis(Vector3.UP, _heading)


## Shot at: the pack round the nest turns on the crew (out to HUNT_RADIUS) for a while.
func _hurt(_amount: float, shooter: Node3D) -> void:
	_anger(shooter)
	for c in get_parent().get_children():
		var mate := c as Crawler
		if mate and mate != self and mate.hive_id == hive_id and mate.position.distance_to(position) < HUNT_RADIUS:
			mate._anger(shooter)


func _anger(shooter: Node3D) -> void:
	_angry = ANGRY_TIME
	if shooter and _target_id == 0:
		_target_id = shooter.get_instance_id()
		_retarget_t = randf_range(0.1, 0.5)


func hear(_pos: Vector3) -> void:
	pass


func center_global() -> Vector3:
	return global_transform * Vector3(0, 0.15, 0)


# --- Looks -------------------------------------------------------------------------------------

func _build(model: Node3D) -> Dictionary:
	var skin := Alien.organic(Color(0.62, 0.55, 0.45), Color(0.9, 0.55, 0.35), 1.8, 10.0)
	var dark := Alien.organic(Color(0.35, 0.28, 0.22), Color(0.8, 0.4, 0.2), 1.2, 12.0)
	var body := Node3D.new()
	body.position = Vector3(0, 0.16, 0)
	model.add_child(body)
	Models.sphere(body, Vector3.ZERO, 0.22, skin, Vector3(1.0, 0.5, 1.15))
	Models.sphere(body, Vector3(0, 0.05, 0.05), 0.14, dark, Vector3(1.0, 0.6, 1.2))
	for side: float in [-1.0, 1.0]:
		Models.sphere(body, Vector3(side * 0.09, 0.0, -0.17), 0.04, dark, Vector3(1.0, 0.7, 1.0))
	# Eight long fingers, two joints each, curling down to the surface.
	var legs: Array[Node3D] = []
	for i in 8:
		var side := -1.0 if i < 4 else 1.0
		var j := i % 4
		var leg := Node3D.new()
		leg.position = Vector3(side * 0.12, 0, -0.12 + j * 0.08)
		leg.rotation.y = side * (0.5 - j * 0.32)
		body.add_child(leg)
		var knee := Vector3(side * 0.22, 0.12, 0)
		var tip := Vector3(side * 0.42, -0.16, -0.02)
		Models.strut(leg, Vector3.ZERO, knee, 0.025, skin)
		Models.strut(leg, knee, tip, 0.018, skin)
		legs.append(leg)
	# The tail.
	var tail := Node3D.new()
	tail.position = Vector3(0, 0.0, 0.2)
	body.add_child(tail)
	var segs: Array[Node3D] = []
	var seg := tail
	for i in 6:
		var s := Node3D.new()
		s.position = Vector3(0, 0, 0.0 if i == 0 else 0.11)
		seg.add_child(s)
		Models.capsule(s, Vector3(0, 0, 0.055), 0.03 - i * 0.003, 0.13, skin, Vector3(90, 0, 0))
		segs.append(s)
		seg = s
	return {"body": body, "legs": legs, "tail": segs}


func _animate(_delta: float) -> void:
	var legs: Array = _parts.get("legs", [])
	var moving := clampf(_speed_seen / 2.5, 0.0, 1.0)
	for i in legs.size():
		var leg: Node3D = legs[i]
		if mode == LEAP:
			# Fingers splayed forward, reaching.
			leg.rotation.x = -0.7
			leg.rotation.z = 0.0
		else:
			leg.rotation.x = sin(_anim_t * 16.0 + i * 1.3) * 0.35 * moving
			leg.rotation.z = (-1.0 if i < 4 else 1.0) * (0.15 + sin(_anim_t * 5.0 + i) * 0.05)
	var segs: Array = _parts.get("tail", [])
	for i in segs.size():
		(segs[i] as Node3D).rotation.y = sin(_anim_t * 6.0 - i * 0.8) * (0.25 + moving * 0.2)
		(segs[i] as Node3D).rotation.x = 0.15 if mode == LEAP else 0.05
