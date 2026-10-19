class_name Climber
extends Boarder
## An alien that crawls over the walls and ceilings of an abandoned station (crawlers and acid
## spiders). Its thinking moves it along a floor track on the station's waypoint graph; _crawl()
## then puts the body on the surface it clings to: the floor, a wall beside the track or the ceiling
## above it, turned to stand on that surface and face along its heading. It changes surface now and
## then, and drops to the floor where the ceiling is low (doorways and corridors' ends) or when its
## kind wants it down (want_floor()).

## It climbs where the ceiling is at least CLIMB_CEILING above the floor (looking ahead along its
## path for low ones, at least CLIMB_LOOKAHEAD metres and far enough to get down in time); on a wall
## it clings CLIMB_MIN..CLIMB_MAX above the floor; WALL_REACH is how far a wall may be from its
## track. Its floor track keeps inside the walls like any alien's (Boarder._keep_inside()).
const CLIMB_CEILING := 3.2
const CLIMB_LOOKAHEAD := 2.6
const CLIMB_MIN := 1.3
const CLIMB_MAX := 3.0
const WALL_REACH := 4.5

## The share of its changes of surface that take it up a wall or onto the ceiling rather than down.
var climb_bias := 0.75
## Server: the floor track and its heading, the surface clung to (0 floor, 1 wall, 2 ceiling),
## where on it the body is and which way is up there, and the cached wall and ceiling.
var _ground := Vector3.ZERO
var _heading := 0.0
var _climb := 0
var _climb_t := 0.0
var _climb_h := 2.0
var _wall_dir := Vector3.RIGHT
var _surf_pos := Vector3.ZERO
var _surf_up := Vector3.UP
var _probe_t := 0.0
var _ceil_h := 0.0
var _ceil_ahead := 0.0
var _wall_p := Vector3.ZERO
var _wall_n := Vector3.ZERO


func _setup(data: Dictionary) -> void:
	_ground = position
	_surf_pos = position


func _server_tick(delta: float, ship: Mothership) -> void:
	# The thinking works on the floor track; _crawl() puts the body on its surface.
	position = _ground
	basis = Basis(Vector3.UP, _heading)
	_think_outside(delta, ship)
	_keep_inside(delta, ship, _ground)
	_ground = position
	_heading = rotation.y
	_crawl(delta, ship)


## True while it must be down on the floor (subclasses: about to strike, just landed...).
func want_floor() -> bool:
	return false


## The surface it is on: 0 floor, 1 wall, 2 ceiling.
func surface() -> int:
	return _climb


## How fast its body moves over to another surface (m/s).
func _climb_speed() -> float:
	return maxf(stat("speed"), 3.0) * 2.4


## The lowest ceiling over its way for the next `look` metres: over each waypoint of its path in
## that reach (a doorway's waypoint is right under its lintel) and where it gets to; straight ahead
## when it has no path.
func _lowest_ahead(ship: Mothership, look: float, heading: Vector3) -> float:
	if _path_i >= _path.size():
		return _ceiling_above(ship, _ground + heading * CLIMB_LOOKAHEAD * 0.6)
	var low := INF
	var at := _ground
	var left := look
	for i in range(_path_i, mini(_path.size(), _path_i + 4)):
		var seg := _path[i] - at
		seg.y = 0.0
		var l := seg.length()
		if l >= left:
			low = minf(low, _ceiling_above(ship, at + seg * (left / maxf(l, 0.0001))))
			return low
		at += seg
		left -= l
		low = minf(low, _ceiling_above(ship, at))
	return low


## The body's step from `a` towards `b` (ship-local) kept out of the walls: straight on where
## nothing is in the way, else along one axis (sliding round a corner or along a wall), else only
## up or down. Gone far from its floor track that way, it is put back on it.
func _slide(ship: Mothership, a: Vector3, b: Vector3) -> Vector3:
	var layout := _station_layout(ship)
	if layout.is_empty():
		return b
	var lift := Vector3(0, StationBuilder.LAND_HEIGHT, 0)
	var doors: PackedByteArray = ship.outpost_doors
	if DerelictBuilder.step_clear(layout, doors, a + lift, b + lift):
		return b
	for c: Vector3 in [Vector3(b.x, b.y, a.z), Vector3(a.x, b.y, b.z)]:
		if DerelictBuilder.step_clear(layout, doors, a + lift, c + lift):
			return c
	if Vector2(a.x - _ground.x, a.z - _ground.z).length() > 3.0:
		return _ground
	return Vector3(a.x, b.y, a.z)


## Where its body is (ship-local; its floor track is `position` only while it thinks).
func body_pos() -> Vector3:
	return _surf_pos


## It looks from its body (from a wall or the ceiling it sees over the furniture).
func _sees(ship: Mothership, p: CrewMember) -> bool:
	return _clear_from(ship, ship.to_global(_surf_pos + _surf_up * 0.3), ship.to_global(p.position) + ship.global_basis.y * 1.2)


## Put the body on its surface (see the class description).
func _crawl(delta: float, ship: Mothership) -> void:
	_probe_t -= delta
	var heading := Basis(Vector3.UP, _heading) * Vector3.FORWARD
	if _probe_t <= 0.0:
		_probe_t = 0.1
		_ceil_h = _ceiling_above(ship, _ground)
		# Far enough ahead along its path to be down off a wall or the ceiling before a doorway.
		_ceil_ahead = _lowest_ahead(ship, maxf(CLIMB_LOOKAHEAD, stat("speed") * 4.6 / _climb_speed() + 0.6), heading)
		if _climb == 1:
			_probe_wall(ship)
	var roomy := _ceil_h > CLIMB_CEILING and _ceil_ahead > CLIMB_CEILING
	_climb_t -= delta
	if want_floor() or not roomy:
		_climb = 0
	elif _climb_t <= 0.0:
		_climb_t = randf_range(1.2, 3.0) if _target_id != 0 else randf_range(3.0, 7.0)
		var r := randf()
		_climb = 0 if r > climb_bias else (1 if r < climb_bias * 0.55 else 2)
		if _climb == 1:
			_climb_h = randf_range(CLIMB_MIN, CLIMB_MAX)
			_wall_dir = heading.cross(Vector3.UP) * (1.0 if randf() < 0.5 else -1.0)
			_probe_wall(ship)
	var target := _ground
	var up := Vector3.UP
	if _climb == 1:
		if _wall_n == Vector3.ZERO:
			_climb = 2
		else:
			# The point on the wall's plane level with the floor track, at the climbing height.
			var p := _ground + Vector3(0, _climb_h, 0)
			target = p - _wall_n * _wall_n.dot(p - _wall_p) + _wall_n * 0.04
			up = _wall_n
	if _climb == 2:
		target = _ground + Vector3(0, _ceil_h - 0.04, 0)
		up = Vector3.DOWN
	_surf_pos = _slide(ship, _surf_pos, _surf_pos.move_toward(target, _climb_speed() * delta))
	if _surf_up.dot(up) < -0.9:
		# Turning right over (floor to ceiling): roll through the side first.
		_surf_up = (_surf_up + heading.cross(Vector3.UP) * 0.4).normalized()
	_surf_up = _surf_up.lerp(up, NetUtil.smooth(12.0, delta)).normalized()
	_place_body(heading)


## Stand the body at _surf_pos on _surf_up, facing along `heading` as far as the surface allows.
func _place_body(heading: Vector3) -> void:
	position = _surf_pos
	var fwd := heading - _surf_up * heading.dot(_surf_up)
	if fwd.length_squared() < 0.0001:
		fwd = Vector3.UP.cross(_surf_up).cross(_surf_up)
	fwd = fwd.normalized()
	var z := -fwd
	basis = Basis(_surf_up.cross(z).normalized(), _surf_up, z)


## Height of the ceiling above ship-local floor point p (0 when there is none within reach).
func _ceiling_above(ship: Mothership, p: Vector3) -> float:
	var from := ship.to_global(p + Vector3(0, 0.3, 0))
	var q := PhysicsRayQueryParameters3D.create(from, from + ship.global_basis.y * 6.0, Game.LAYER_STATION)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return 0.0 if hit.is_empty() else ship.to_local(hit["position"]).y - p.y


## Find the wall to cling to beside the floor track (in _wall_dir, or the other way): its point and
## inward normal (ship-local), or a zero normal when there is none in reach. Where the wall has a
## doorway at the climbing height, it climbs above it.
func _probe_wall(ship: Mothership) -> void:
	_wall_n = Vector3.ZERO
	var space := get_world_3d().direct_space_state
	for dir: Vector3 in [_wall_dir, -_wall_dir]:
		# Above the lintels the room's own wall is always there; lower down a ray can pass through
		# a doorway and find a wall further off (in the corridor or the next room).
		var top := _wall_hit(space, ship, dir, CLIMB_MAX)
		if top.is_empty():
			continue
		var low := _wall_hit(space, ship, dir, _climb_h)
		var use := top
		if not low.is_empty() and float(low["dist"]) < float(top["dist"]) + 0.3:
			use = low
		else:
			_climb_h = CLIMB_MAX
		_wall_p = use["pos"]
		_wall_n = use["normal"]
		_wall_dir = dir
		return


## A wall `h` above the floor track in direction `dir` (ship-local): {pos, normal, dist}, or {}.
func _wall_hit(space: PhysicsDirectSpaceState3D, ship: Mothership, dir: Vector3, h: float) -> Dictionary:
	var from := ship.to_global(_ground + Vector3(0, h, 0))
	var q := PhysicsRayQueryParameters3D.create(from, from + ship.global_basis * dir * WALL_REACH, Game.LAYER_STATION)
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return {}
	var n := ship.global_basis.inverse() * (hit["normal"] as Vector3)
	if absf(n.y) > 0.3:
		return {}
	return {"pos": ship.to_local(hit["position"]), "normal": Vector3(n.x, 0, n.z).normalized(),
		"dist": from.distance_to(hit["position"])}
