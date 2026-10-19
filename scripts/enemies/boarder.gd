class_name Boarder
extends Node3D
## An alien on foot. It lives in ship-local space (under Interior/Boarders) and is simulated on the
## server along a waypoint graph. The crew kills it with hand weapons.
##
## This class is the "boarder": an infiltrator that broke into the mothership through a roof hatch.
## It hunts crew members aboard and otherwise wrecks the engine and weapon systems. The aliens
## living in the abandoned stations (`outside`) are its subclasses, one per kind (make()):
## - Stalker: bigger than a man; roams the station, rushes whoever it spots, claws them a few times
##   and runs off to hide, and comes back; badly hurt, it flees to heal.
## - Barnacle: hangs from a ceiling and catches whoever walks under it.
## - Crawler: small, on the walls and ceilings round its nest (Hive), leaping at whoever comes into
##   its room; shot at, the pack hunts the shooter out to some way from the nest.
## - Spider: four legs that cling to any surface; it scurries about and stops to spit acid.
## Aliens in a station stay there: they never board the ship. While the ship is landed there,
## ship-local space covers the station too (the ship is parked).
##
## Everything shared lives here: replication, the hit area, damage and death, picking a target
## among the crew out in the station (the closest, sticking to the one it is after, turning on
## whoever shoots it, a pack spreading out over the crew), and walking the station's waypoint graph.

const KIND_STATS := {
	"boarder": {"hp": 55.0, "speed": 3.8, "damage": 13.0, "cooldown": 1.1, "reach": 1.7, "radius": 0.6, "height": 1.8,
		"name": "Boarder"},
	"stalker": {"hp": 400.0, "speed": 2.8, "damage": 10.0, "cooldown": 0.5, "reach": 2.0, "radius": 0.55, "height": 2.4,
		"name": "Stalker"},
	"barnacle": {"hp": 40.0, "speed": 0.0, "damage": 5.0, "cooldown": 0.9, "reach": 1.9, "radius": 0.5, "height": 1.0,
		"name": "Barnacle"},
	"crawler": {"hp": 14.0, "speed": 2.9, "damage": 7.0, "cooldown": 1.2, "reach": 4.6, "radius": 0.3, "height": 0.4,
		"name": "Crawler"},
	"hive": {"hp": 140.0, "speed": 0.0, "damage": 0.0, "cooldown": 1.0, "reach": 0.0, "radius": 0.85, "height": 1.3,
		"name": "Crawler nest"},
	"spider": {"hp": 50.0, "speed": 5.2, "damage": 9.0, "cooldown": 2.0, "reach": 16.0, "radius": 0.5, "height": 0.8,
		"name": "Acid spider"},
}
const SABOTAGE_DPS := 6.0
const HUNT_RANGE := 16.0
## Aliens in an abandoned station notice crew within NOTICE_RANGE that they can see (or hear within
## HEAR_RANGE: sound goes round by the open ways, see _hears()), and give up once their target is
## CHASE_RANGE away and out of sight for FORGET_TIME seconds.
const NOTICE_RANGE := 15.0
const HEAR_RANGE := 4.0
const CHASE_RANGE := 26.0
const FORGET_TIME := 6.0
## Every RETARGET_TIME seconds they look again and go for the best target: the closest one, with
## distances to the one they are already after scaled by STICKY, to whoever shot them in the last
## PROVOKE_TIME seconds by PROVOKED, and CROWD metres added per pack mate already on someone (so
## a pack spreads over the crew, bots included, instead of all mobbing the one in front).
const RETARGET_TIME := 0.6
const STICKY := 0.75
const PROVOKED := 0.6
const PROVOKE_TIME := 4.0
const CROWD := 1.6
## Aliens push apart when closer than this.
const PERSONAL_SPACE := 0.9
## In a station an alien keeps its middle its radius (at most 0.5) plus WALL_GAP off the walls and
## inside a doorway's jambs; a move into a wall or a shut door is undone (_keep_inside()), and one
## blocked for BLOCKED_TIME makes it think again.
const WALL_GAP := 0.12
const BLOCKED_TIME := 0.8
## A noise (hear()) draws it for this long, even while there's no way there yet.
const HEARD_TIME := 20.0

# Replicated (server authority), ship-local. `mode` is what the alien is doing (each kind's own
# states, for its animation); `grab` the peer id of the crew member a barnacle holds (0: none).
var net_pos := Vector3.ZERO
var net_rot := Quaternion.IDENTITY
var hp := 55.0
var max_hp := 55.0
var attacking := false
var mode := 0
var grab := 0

## From the spawn data (and kept for when the station is stowed, see save_data()).
var kind := "boarder"
var outside := false
var dmg_mult := 1.0
## Where an alien in an abandoned station was placed (it guards that spot).
var home := Vector3.ZERO

var _parts: Dictionary = {}
var _meshes: Array[GeometryInstance3D] = []
var _anim_t := 0.0
var _flash := 0.0
var _last_hp := 0.0
var _fall_v := 0.0
## How fast it moves on the clients (from the replicated position), for the animation.
var _speed_seen := 0.0
var _last_pos := Vector3.ZERO
# Server state.
var _path: PackedVector3Array = PackedVector3Array()
var _path_i := 0
var _repath := 0.0
var _attack_cd := 1.0
var _goal := Vector3.ZERO
var _goal_panel := -1
var _target_id := 0
var _lost_t := 0.0
var _retarget_t := 0.0
## The crew member who last shot this alien (instance id) and for how much longer that counts.
var _provoker := 0
var _provoke_t := 0.0
var _wander := Vector3.ZERO
var _wander_t := 0.0
## A noise it is going to have a look at, and for how much longer.
var _heard := Vector3.ZERO
var _heard_t := 0.0
## The plan of the station it is in (cached by station) and how long its moves have been blocked.
var _layout: Dictionary = {}
var _layout_k := -1
var _blocked_t := 0.0


## A new alien of `kind` (its class).
static func make(kind_id: String) -> Boarder:
	match kind_id:
		"stalker":
			return Stalker.new()
		"barnacle":
			return Barnacle.new()
		"crawler":
			return Crawler.new()
		"spider":
			return Spider.new()
		"hive":
			return Hive.new()
	return Boarder.new()


func _init() -> void:
	NetUtil.add_sync(self, ["net_pos", "net_rot"], ["hp", "attacking", "mode", "grab"], 0.05)


func setup(data: Dictionary) -> void:
	name = str(data["name"])
	kind = str(data.get("kind", "boarder"))
	if not KIND_STATS.has(kind):
		kind = "boarder"
	outside = bool(data.get("outside", false))
	dmg_mult = float(data.get("dmg", 1.0))
	position = data["pos"]
	home = position
	_wander = home
	net_pos = position
	_last_pos = position
	max_hp = float(data.get("max_hp", data.get("hp", 55.0)))
	hp = float(data.get("hp", max_hp))
	_setup(data)
	net_rot = quaternion


## Kind-specific spawn data (subclasses).
func _setup(_data: Dictionary) -> void:
	pass


## What to keep of this alien when the station is stowed (merged into its spawn data next time).
func save_data() -> Dictionary:
	return {}


func stat(key: String) -> float:
	return float(KIND_STATS[kind][key])


func _ready() -> void:
	add_to_group("boarders")
	var model := Node3D.new()
	model.name = "Model"
	add_child(model)
	_parts = _build(model)
	Alien.collect_meshes(model, _meshes)
	var area := Area3D.new()
	area.collision_layer = Game.LAYER_BOARDER
	area.collision_mask = 0
	area.monitoring = false
	area.set_meta("boarder", str(name))
	var cs := CollisionShape3D.new()
	_hit_shape(cs)
	area.add_child(cs)
	add_child(area)
	_last_hp = hp
	_anim_t = randf() * 10.0
	_attack_cd = randf_range(0.6, 1.4)


## The hit area (node-local): a capsule of the kind's radius and height standing on the node's
## origin (subclasses shape their own).
func _hit_shape(cs: CollisionShape3D) -> void:
	var cap := CapsuleShape3D.new()
	cap.radius = stat("radius")
	cap.height = maxf(stat("height"), cap.radius * 2.0)
	cs.shape = cap
	cs.position = Vector3(0, cap.height * 0.5 - 0.05, 0)


## The boarder's model: an infiltrator on its feet.
func _build(model: Node3D) -> Dictionary:
	model.position = Vector3(0, 0.75, 0)
	model.scale = Vector3.ONE * 0.85
	return Alien.build_model(model, Alien.Kind.INFILTRATOR)


func _ship() -> Mothership:
	return get_parent().get_parent().get_parent() as Mothership


func _physics_process(delta: float) -> void:
	var ship := _ship()
	if ship == null:
		return
	if multiplayer.is_server():
		_server_tick(delta, ship)
		net_pos = position
		net_rot = quaternion
	else:
		var k := NetUtil.smooth(14.0, delta)
		position = position.lerp(net_pos, k) if position.distance_to(net_pos) < 4.0 else net_pos
		quaternion = quaternion.slerp(net_rot, k)
	_speed_seen = lerpf(_speed_seen, position.distance_to(_last_pos) / maxf(delta, 0.0001), NetUtil.smooth(8.0, delta))
	_last_pos = position


func _server_tick(delta: float, ship: Mothership) -> void:
	if outside:
		var before := position
		_think_outside(delta, ship)
		_keep_inside(delta, ship, before)
	else:
		_think(delta, ship)


func _process(delta: float) -> void:
	_anim_t += delta
	if hp < _last_hp - 0.01:
		_flash = 1.0
	_last_hp = hp
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 5.0)
		for m in _meshes:
			m.set_instance_shader_parameter("flash", _flash)
	_animate(delta)


## The boarder's walk and claws.
func _animate(_delta: float) -> void:
	var legs: Array = _parts.get("legs", [])
	for i in legs.size():
		(legs[i] as Node3D).rotation.x = sin(_anim_t * 11.0 + i * 1.7) * 0.4
	var swing := sin(_anim_t * (16.0 if attacking else 4.0)) * (0.8 if attacking else 0.3)
	if _parts.has("arm_l"):
		(_parts["arm_l"] as Node3D).rotation.x = swing
		(_parts["arm_r"] as Node3D).rotation.x = -swing


# --- Aboard the mothership ---------------------------------------------------------------------

func _think(delta: float, ship: Mothership) -> void:
	# Drop from the ceiling hatch first.
	if position.y > 0.01:
		_fall_v += 14.0 * delta
		position.y = maxf(0.0, position.y - _fall_v * delta)
		return
	_attack_cd = maxf(0.0, _attack_cd - delta)
	_repath -= delta
	var victim := _closest_player(ship)
	attacking = false
	if victim:
		var to := victim.position - position
		to.y = 0.0
		if to.length() < stat("reach"):
			attacking = true
			_face(to)
			if _attack_cd <= 0.0:
				_attack_cd = stat("cooldown")
				victim.hurt(stat("damage") * dmg_mult)
				Game.mission.fx_event.rpc("claw", ship.to_global(victim.position + Vector3(0, 1.2, 0)), 0)
			return
		if _repath <= 0.0 or _goal.distance_to(victim.position) > 1.5:
			_set_goal(ship, ship.nav, victim.position)
	else:
		# No crew nearby: sabotage the closest machine.
		if _goal_panel < 0 or _repath <= 0.0:
			_goal_panel = _closest_panel()
			_set_goal(ship, ship.nav, _panel_spot(_goal_panel))
		var spot := _panel_spot(_goal_panel)
		if position.distance_to(spot) < 0.9:
			attacking = true
			var panel: Dictionary = ship.repair_panels()[_goal_panel]
			_face(Vector3(panel["pos"]) - position)
			ship.damage_system(panel["system"], SABOTAGE_DPS * delta)
			return
	_follow_path(delta)


func _closest_player(ship: Mothership) -> CrewMember:
	var best: CrewMember = null
	var best_d := HUNT_RANGE
	for c in ship.crew_root.get_children():
		var p := c as CrewMember
		# Crew out on a waystation pier, or out flying a scout, are beyond reach.
		if p == null or not p.alive or not ship.is_aboard(p.position) or ship.is_scout_station(p.station):
			continue
		var d := p.position.distance_to(position)
		if d < best_d:
			best_d = d
			best = p
	return best


func _closest_panel() -> int:
	var best := 0
	var best_d := INF
	for i in _ship().repair_panels().size():
		var d := _panel_spot(i).distance_to(position)
		if d < best_d:
			best_d = d
			best = i
	return best


func _panel_spot(i: int) -> Vector3:
	return ShipInteriors.panel_spot(_ship().repair_panels()[i])


# --- In an abandoned station -------------------------------------------------------------------

## A boarder that finds itself in a station just goes for the crew there with its claws.
func _think_outside(delta: float, ship: Mothership) -> void:
	_attack_cd = maxf(0.0, _attack_cd - delta)
	_repath -= delta
	attacking = false
	var victim := _station_target(delta, ship)
	if victim == null:
		if not _investigate(delta, ship):
			_idle(delta)
		_separate(delta)
		return
	var to := victim.position - position
	to.y = 0.0
	if to.length() < stat("reach"):
		attacking = true
		_face(to)
		if _attack_cd <= 0.0:
			_attack_cd = stat("cooldown")
			_claw(ship, victim)
	else:
		_chase(delta, ship, victim)
	_separate(delta)


## A claw at a crew member.
func _claw(ship: Mothership, victim: CrewMember, damage := -1.0) -> void:
	victim.hurt((stat("damage") if damage < 0.0 else damage) * dmg_mult)
	Game.mission.fx_event.rpc("claw", ship.to_global(victim.position + Vector3(0, 1.0, 0)), 0)


## The crew member this alien is after: once noticed, it keeps chasing until the target gets away,
## but now and then it looks again and switches to someone better placed (see RETARGET_TIME).
## `notice` and `chase` override NOTICE_RANGE and CHASE_RANGE.
func _station_target(delta: float, ship: Mothership, notice := NOTICE_RANGE, chase := CHASE_RANGE) -> CrewMember:
	_provoke_t = maxf(0.0, _provoke_t - delta)
	var current := _outside_crew(ship, _target_id)
	if current:
		var d := current.position.distance_to(position)
		if d > chase or not _sees(ship, current):
			_lost_t += delta
		else:
			_lost_t = 0.0
		if _lost_t >= FORGET_TIME or d >= chase * 1.5:
			current = null
	if current == null:
		_target_id = 0
		_lost_t = 0.0
	_retarget_t -= delta
	if current and _retarget_t > 0.0:
		return current
	_retarget_t = RETARGET_TIME * randf_range(0.8, 1.2)
	var best := current
	var best_score := _target_score(current, true) if current else INF
	for c in ship.crew_root.get_children():
		var p := c as CrewMember
		if p == null or p == current or not p.alive or ship.is_aboard(p.position):
			continue
		var d := p.position.distance_to(position)
		var provoker := _provoke_t > 0.0 and p.get_instance_id() == _provoker
		if d >= (chase if provoker else notice) or not (_sees(ship, p) or _hears(ship, p.position, HEAR_RANGE)):
			continue
		var score := _target_score(p, false)
		if score < best_score:
			best_score = score
			best = p
	if best == null or best == current:
		return best
	var fresh := _target_id == 0
	_target_id = best.get_instance_id()
	_lost_t = 0.0
	_repath = 0.0
	if fresh:
		_alert_pack()
	return best


## A pack mate noticed someone: the others of the same kind within earshot join in (and soon pick
## a target of their own among the crew).
func _alert_pack() -> void:
	var ship := _ship()
	for c in get_parent().get_children():
		var mate := c as Boarder
		if mate and mate != self and mate.outside and mate.kind == kind and mate._target_id == 0 and mate._hears(ship, position, 7.0):
			mate._target_id = _target_id
			mate._retarget_t = randf_range(0.1, 0.4)


## A conscious crew member (player or bot) out in the station, by instance id, or null.
func _outside_crew(ship: Mothership, id: int) -> CrewMember:
	if id == 0:
		return null
	var p := instance_from_id(id) as CrewMember
	if p == null or not is_instance_valid(p) or not p.alive or ship.is_aboard(p.position):
		return null
	return p


## How good a target a crew member is (lower is better): its distance, shrunk for the one already
## being chased and for whoever just shot this alien, plus room for each pack mate already on it.
func _target_score(p: CrewMember, is_current: bool) -> float:
	var score := p.position.distance_to(position)
	if is_current:
		score *= STICKY
	if _provoke_t > 0.0 and p.get_instance_id() == _provoker:
		score *= PROVOKED
	var id := p.get_instance_id()
	for c in get_parent().get_children():
		var mate := c as Boarder
		if mate and mate != self and mate.outside and mate._target_id == id:
			score += CROWD
	return score


## Line of sight from this alien's eyes to a crew member's chest (station walls and doors and the
## ship block it).
func _sees(ship: Mothership, p: CrewMember) -> bool:
	return _clear_from(ship, center_global() + ship.global_basis.y * (stat("height") * 0.3), ship.to_global(p.position) + ship.global_basis.y * 1.2)


func _clear_from(ship: Mothership, from: Vector3, to: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(from, to, Game.LAYER_STATION | Game.LAYER_INTERIOR | Game.LAYER_HULL)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## Whether it hears something at ship-local `p` within `reach`: sound goes round by the station's
## open ways (walls and shut doors stop it), so the way there may be at most half as long again.
func _hears(ship: Mothership, p: Vector3, reach: float) -> bool:
	if p.distance_to(position) >= reach:
		return false
	var graph := _graph(ship)
	var from := _nav_point(ship, graph, position)
	var to := _nav_point(ship, graph, p)
	if from < 0 or to < 0:
		return false
	if from == to:
		return true
	var way := graph.get_point_path(from, to)
	if way.is_empty():
		return false
	var length := 0.0
	for i in range(1, way.size()):
		length += way[i - 1].distance_to(way[i])
	return length < reach * 1.5 + OutpostLayout.CELL


## The graph the aliens in a station walk on.
func _graph(ship: Mothership) -> AStar3D:
	return ship.derelict_nav if ship.derelict_nav else ship.nav


## The waypoint for ship-local point p: in a station the one of the cell it is in (when that cell
## has one; not under furniture), else the closest one in sight.
func _nav_point(ship: Mothership, graph: AStar3D, p: Vector3) -> int:
	if outside and graph == ship.derelict_nav:
		var c := OutpostLayout.cell_at(p + Vector3(0, StationBuilder.LAND_HEIGHT, 0))
		if OutpostLayout.inside(c) and graph.has_point(DerelictBuilder.NAV_CELL + OutpostLayout.idx(c)):
			return DerelictBuilder.NAV_CELL + OutpostLayout.idx(c)
	return ship.nav_closest(graph, p)


## The plan of the station the ship is landed at ({} when none).
func _station_layout(ship: Mothership) -> Dictionary:
	if ship.derelict_k != _layout_k:
		_layout_k = ship.derelict_k
		_layout = {}
		if _layout_k >= 0 and Game.mission:
			_layout = (Game.mission.cave as CaveGen).derelict(_layout_k).get("layout", {})
	return _layout


## Server, in a station: undo a move through a wall or a shut door (the step from `before` to where
## its thinking put it, see DerelictBuilder.step_clear()) and keep its body off the walls (WALL_GAP).
## A move blocked for BLOCKED_TIME makes it think again: a new path, somewhere else to wander.
func _keep_inside(delta: float, ship: Mothership, before: Vector3) -> void:
	var layout := _station_layout(ship)
	if layout.is_empty() or stat("speed") <= 0.0:
		return
	var lift := Vector3(0, StationBuilder.LAND_HEIGHT, 0)
	var doors: PackedByteArray = ship.outpost_doors
	if not DerelictBuilder.step_clear(layout, doors, before + lift, position + lift):
		position = Vector3(before.x, position.y, before.z)
		_blocked_t += delta
		if _blocked_t > BLOCKED_TIME:
			_blocked_t = 0.0
			_repath = 0.0
			_wander_t = 0.0
			_path = PackedVector3Array()
			_path_i = 0
	else:
		_blocked_t = maxf(0.0, _blocked_t - delta * 0.5)
	var kept := DerelictBuilder.keep_off_walls(layout, doors, position + lift, minf(stat("radius"), 0.5) + WALL_GAP)
	position.x = kept.x
	position.z = kept.z


func _chase(delta: float, ship: Mothership, victim: CrewMember, speed := -1.0) -> void:
	if _repath <= 0.0 or _goal.distance_to(victim.position) > 1.5:
		_set_goal(ship, _graph(ship), victim.position)
	_follow_path(delta, speed)


## Step away from a point (unless a wall is in the way).
func _back_off(delta: float, ship: Mothership, away: Vector3, speed := -1.0) -> void:
	var step := away * (stat("speed") if speed < 0.0 else speed) * 0.8 * delta
	var from := ship.to_global(position + Vector3(0, 0.6, 0))
	var q := PhysicsRayQueryParameters3D.create(from, from + ship.global_basis * (away * 1.2), Game.LAYER_STATION | Game.LAYER_INTERIOR | Game.LAYER_HULL)
	if get_world_3d().direct_space_state.intersect_ray(q).is_empty():
		position += step


## Nobody around: shuffle about near the spot it guards, walking back there along the waypoints
## first if it has strayed (a chase, a noise). Where there's no way back it makes its home where it is.
func _idle(delta: float, roam := 2.0) -> void:
	if outside and Vector2(position.x - home.x, position.z - home.z).length() > roam + 2.0:
		if _repath <= 0.0 or _path_i >= _path.size():
			var ship := _ship()
			_set_goal(ship, _graph(ship), home)
			_repath = 3.0
			if _path.is_empty():
				home = position
		_follow_path(delta, stat("speed") * 0.6)
		return
	_wander_t -= delta
	if _wander_t <= 0.0:
		_wander_t = randf_range(2.5, 6.0)
		_wander = home + Vector3(randf_range(-roam, roam), 0.0, randf_range(-roam, roam))
	var to := _wander - position
	to.y = 0.0
	if to.length() > 0.3:
		position += to.normalized() * minf(stat("speed") * 0.3 * delta, to.length())
		_face(to)


## Keep a little room between aliens so a pack doesn't merge into one.
func _separate(delta: float) -> void:
	var push := Vector3.ZERO
	for c in get_parent().get_children():
		var mate := c as Boarder
		if mate == null or mate == self or mate.stat("speed") <= 0.0:
			continue
		var d := position - mate.position
		d.y = 0.0
		var l := d.length()
		if l < PERSONAL_SPACE:
			push += (d / l if l > 0.001 else Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()) * (PERSONAL_SPACE - l)
	if push != Vector3.ZERO:
		position += push.limit_length(1.0) * 4.0 * delta


## Where the middle of the body is (global): aliens on a wall or ceiling hang off it.
func center_global() -> Vector3:
	return global_transform * Vector3(0, stat("height") * 0.5, 0)


# --- Movement ----------------------------------------------------------------------------------

func _set_goal(ship: Mothership, graph: AStar3D, goal: Vector3) -> void:
	_repath = 0.6
	_goal = goal
	var from := _nav_point(ship, graph, position)
	var to := _nav_point(ship, graph, goal)
	_path = graph.get_point_path(from, to) if from >= 0 and to >= 0 else PackedVector3Array()
	_path_i = 0
	if _path.is_empty():
		# Out of reach (behind a shut door): stay put rather than walk through the walls.
		return
	_path.append(goal)
	_path_i = 0
	# Skip waypoints behind us.
	if _path.size() > 1 and position.distance_to(_path[1]) < _path[0].distance_to(_path[1]):
		_path_i = 1


## Walk the path (at `speed`, or the kind's own); true once at its end.
func _follow_path(delta: float, speed := -1.0) -> bool:
	if _path_i >= _path.size():
		return true
	var wp := _path[_path_i]
	var to := wp - position
	to.y = 0.0
	if to.length() < 0.35:
		_path_i += 1
		return _path_i >= _path.size()
	var step := minf((stat("speed") if speed < 0.0 else speed) * delta, to.length())
	position += to.normalized() * step
	if outside:
		# Follow the floor (the pier, the station and their small steps).
		position.y = move_toward(position.y, wp.y, 3.0 * delta)
	_face(to)
	return false


func _face(dir: Vector3) -> void:
	if dir.length_squared() > 0.001:
		rotation.y = atan2(-dir.x, -dir.z)


## Server: a noise at ship-local `pos` (Mothership.alert_outpost): it goes to have a look, along the
## waypoints (while there's no way there yet, a shut door, it tries again now and then).
func hear(pos: Vector3) -> void:
	if _target_id == 0:
		_heard = pos
		_heard_t = HEARD_TIME
		_repath = 0.0


## On its way to look at a noise it heard (false when there's none): once there it stays about.
func _investigate(delta: float, ship: Mothership) -> bool:
	if _heard_t <= 0.0:
		return false
	_heard_t -= delta
	if _repath <= 0.0:
		_set_goal(ship, _graph(ship), _heard)
		_repath = 2.0
	if position.distance_to(_heard) < 2.0 or (not _path.is_empty() and _follow_path(delta, stat("speed") * 0.7)):
		_heard_t = 0.0
		home = position
		_wander_t = 0.0
	return true


## Server: damage from the crew. `info["by"]` is the shooter's peer id (crew bots included) when known.
func take_damage(amount: float, info: Dictionary) -> void:
	if not multiplayer.is_server() or hp <= 0.0:
		return
	hp -= amount
	var shooter: CrewMember = null
	if outside:
		var ship := _ship()
		shooter = ship.crew_root.get_node_or_null(str(info.get("by", 0))) as CrewMember
		if shooter and (not shooter.alive or ship.is_aboard(shooter.position)):
			shooter = null
		if shooter:
			# Shot at: the shooter becomes the prime suspect for a while.
			_provoker = shooter.get_instance_id()
			_provoke_t = PROVOKE_TIME
			_retarget_t = 0.0
		if _target_id == 0 and stat("speed") > 0.0:
			# Go and find the shooter (or whoever is closest if it doesn't know who).
			_wander_t = 0.0
			if shooter:
				_target_id = shooter.get_instance_id()
			else:
				var best_d := CHASE_RANGE
				for c in ship.crew_root.get_children():
					var p := c as CrewMember
					if p and p.alive and not ship.is_aboard(p.position) and p.position.distance_to(position) < best_d:
						best_d = p.position.distance_to(position)
						_target_id = p.get_instance_id()
	if hp <= 0.0:
		_die()
		return
	_hurt(amount, shooter)


## A hit that didn't kill it (subclasses react).
func _hurt(_amount: float, _shooter: CrewMember) -> void:
	pass


func _die() -> void:
	var mission := Game.mission as MissionLevel
	if mission:
		mission.kills += 1
		mission.fx_event.rpc("boarder_die", center_global(), clampf(stat("radius") * 1.7, 0.4, 1.6))
	queue_free()
