class_name Boarder
extends Node3D
## An alien on foot. It lives in ship-local space (under Interior/Boarders) and is simulated on the
## server along a waypoint graph. The crew kills it with hand weapons.
##
## Kinds (KIND_STATS):
## - "boarder": broke into the mothership through a roof hatch. It hunts crew members aboard and
##   otherwise wrecks the engine and weapon systems.
## - "skitter": small and fast, attacks in packs with its claws. Skitters crawl over the walls and
##   ceilings of the station's rooms, which makes them hard to hit: they drop down to claw at their
##   prey, then scuttle off and up a wall again (hit and run).
## - "needler": keeps its distance and fires needles.
## Aliens living in an abandoned station (`outside`) stay there: they guard their room, chase crew
## members who come close and fight anyone out in the station, players and crew bots alike, but
## never board the ship. While the ship is landed there, ship-local space covers the station too
## (the ship is parked).

const KIND_STATS := {
	"boarder": {"hp": 55.0, "speed": 3.8, "damage": 13.0, "cooldown": 1.1, "reach": 1.7, "radius": 0.6, "height": 1.8,
		"name": "Boarder"},
	"skitter": {"hp": 20.0, "speed": 7.6, "damage": 3.0, "cooldown": 0.8, "reach": 1.25, "radius": 0.24, "height": 0.48,
		"name": "Skitter"},
	"needler": {"hp": 40.0, "speed": 2.8, "damage": 8.0, "cooldown": 1.8, "reach": 14.0, "radius": 0.55, "height": 1.9,
		"name": "Needler"},
}
const SABOTAGE_DPS := 6.0
const HUNT_RANGE := 16.0
## Aliens in an abandoned station notice crew within NOTICE_RANGE that they can see (or within
## HEAR_RANGE regardless), and give up once their target is CHASE_RANGE away and out of sight for
## FORGET_TIME seconds.
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
## Needlers: preferred distance band, needle speed and aim error (radians).
const NEEDLE_NEAR := 5.5
const NEEDLE_FAR := 11.0
const NEEDLE_SPEED := 24.0
const NEEDLE_SPREAD := 0.035
## Aliens push apart when closer than this.
const PERSONAL_SPACE := 0.9
## Skitters climb where the ceiling is at least CLIMB_CEILING above the floor (rooms, not the
## doorways and corridors between them, which they cross on the floor; they look CLIMB_LOOKAHEAD
## metres ahead along their path for those). Within POUNCE_RANGE of their prey they drop to the
## floor to attack. On a wall they cling CLIMB_MIN..CLIMB_MAX above the floor; WALL_REACH is how
## far a wall may be.
const CLIMB_CEILING := 3.5
const CLIMB_LOOKAHEAD := 2.6
const POUNCE_RANGE := 3.2
const CLIMB_MIN := 1.4
const CLIMB_MAX := 3.4
const WALL_REACH := 4.5
## After a claw, a skitter scuttles away for this long (seconds) and up a wall or the ceiling.
const RETREAT_TIME := Vector2(0.45, 0.85)
## Skitters scale their critter model by this.
const SKITTER_SCALE := 0.5

# Replicated (server authority), ship-local.
var net_pos := Vector3.ZERO
var net_rot := Quaternion.IDENTITY
var hp := 55.0
var max_hp := 55.0
var attacking := false

## From the spawn data.
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
# Skitters (server): the floor track the pack logic moves along and its heading, the surface they
# cling to (0 floor, 1 wall, 2 ceiling), where on it they are, and the cached wall and ceiling.
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
var _retreat_t := 0.0
var _retreat_dir := Vector3.ZERO


func _init() -> void:
	NetUtil.add_sync(self, ["net_pos", "net_rot"], ["hp", "attacking"], 0.05)


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
	_ground = position
	_surf_pos = position
	net_pos = position
	max_hp = float(data.get("max_hp", data.get("hp", 55.0)))
	hp = float(data.get("hp", max_hp))


func stat(key: String) -> float:
	return float(KIND_STATS[kind][key])


func _ready() -> void:
	add_to_group("boarders")
	var model := Node3D.new()
	add_child(model)
	match kind:
		"skitter":
			model.position = Vector3(0, 0.42 * SKITTER_SCALE, 0)
			_parts = Alien.build_model(model, Alien.Kind.CRITTER)
			model.scale = Vector3.ONE * SKITTER_SCALE
		"needler":
			_parts = _build_needler(model)
		_:
			model.position = Vector3(0, 0.75, 0)
			_parts = Alien.build_model(model, Alien.Kind.INFILTRATOR)
			model.scale = Vector3.ONE * 0.85
	Alien.collect_meshes(model, _meshes)
	var area := Area3D.new()
	area.collision_layer = Game.LAYER_BOARDER
	area.collision_mask = 0
	area.monitoring = false
	area.set_meta("boarder", str(name))
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = stat("radius")
	cap.height = maxf(stat("height"), cap.radius * 2.0)
	cs.shape = cap
	cs.position = Vector3(0, cap.height * 0.5 - 0.05, 0)
	area.add_child(cs)
	add_child(area)
	_last_hp = hp
	_anim_t = randf() * 10.0
	_attack_cd = randf_range(0.6, 1.4)


## A needler: a hunched, long-legged alien with a needle launcher growing out of its back.
static func _build_needler(root: Node3D) -> Dictionary:
	var parts := {}
	var skin := Alien.organic(Color(0.24, 0.07, 0.2), Color(1.0, 0.3, 0.8), 2.4, 6.0)
	var bone := Models.mat(Color(0.75, 0.7, 0.62), 0.1, 0.6)
	var glow := Models.emissive(Color(1.0, 0.35, 0.85), 3.0)
	var body := Node3D.new()
	body.position = Vector3(0, 1.15, 0)
	root.add_child(body)
	Models.capsule(body, Vector3.ZERO, 0.32, 1.1, skin, Vector3(-25, 0, 0))
	Models.sphere(body, Vector3(0, 0.55, -0.35), 0.27, skin, Vector3(0.9, 0.8, 1.2))
	for side: float in [-1.0, 1.0]:
		Models.sphere(body, Vector3(side * 0.11, 0.6, -0.6), 0.05, Models.emissive(Color(1.0, 0.85, 0.2), 6.0))
	# The launcher: a bony tube over the shoulder fed by a glowing sac.
	var launcher := Node3D.new()
	launcher.position = Vector3(0.22, 0.55, 0.1)
	body.add_child(launcher)
	Models.cylinder(launcher, Vector3(0, 0, -0.35), 0.08, 1.0, bone, Vector3(90, 0, 0), 0.05)
	Models.sphere(launcher, Vector3(0, 0, 0.25), 0.2, glow)
	Models.sphere(launcher, Vector3(0, 0, -0.86), 0.06, glow)
	parts["launcher"] = launcher
	var legs: Array[Node3D] = []
	for side: float in [-1.0, 1.0]:
		var leg := Node3D.new()
		leg.position = Vector3(side * 0.22, 0.85, 0.05)
		root.add_child(leg)
		Models.strut(leg, Vector3.ZERO, Vector3(side * 0.12, -0.45, -0.25), 0.07, skin)
		Models.strut(leg, Vector3(side * 0.12, -0.45, -0.25), Vector3(side * 0.15, -0.85, 0.1), 0.05, skin)
		legs.append(leg)
		var arm := Node3D.new()
		arm.position = Vector3(side * 0.3, 1.45, -0.25)
		root.add_child(arm)
		Models.strut(arm, Vector3.ZERO, Vector3(side * 0.15, -0.45, -0.3), 0.045, skin)
		parts["arm_l" if side < 0 else "arm_r"] = arm
	parts["legs"] = legs
	parts["body"] = body
	return parts


func _ship() -> Mothership:
	return get_parent().get_parent().get_parent() as Mothership


func _physics_process(delta: float) -> void:
	var ship := _ship()
	if ship == null:
		return
	if multiplayer.is_server():
		var crawler := outside and kind == "skitter"
		if crawler:
			# The pack logic works on the floor track; _crawl() puts the skitter on its surface.
			position = _ground
			basis = Basis(Vector3.UP, _heading)
		if outside:
			_think_outside(delta, ship)
		else:
			_think(delta, ship)
		if crawler:
			_ground = position
			_heading = rotation.y
			_crawl(delta, ship)
		net_pos = position
		net_rot = quaternion
	else:
		var k := NetUtil.smooth(14.0, delta)
		position = position.lerp(net_pos, k) if position.distance_to(net_pos) < 4.0 else net_pos
		quaternion = quaternion.slerp(net_rot, k)


func _process(delta: float) -> void:
	_anim_t += delta
	if hp < _last_hp - 0.01:
		_flash = 1.0
	_last_hp = hp
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 5.0)
		for m in _meshes:
			m.set_instance_shader_parameter("flash", _flash)
	var legs: Array = _parts.get("legs", [])
	var stride := 22.0 if kind == "skitter" else 11.0
	for i in legs.size():
		(legs[i] as Node3D).rotation.x = sin(_anim_t * stride + i * 1.7) * 0.4
	var swing := sin(_anim_t * (16.0 if attacking else 4.0)) * (0.8 if attacking else 0.3)
	if _parts.has("arm_l"):
		(_parts["arm_l"] as Node3D).rotation.x = swing
		(_parts["arm_r"] as Node3D).rotation.x = -swing
	if _parts.has("launcher"):
		(_parts["launcher"] as Node3D).position.z = 0.1 + (0.12 * absf(sin(_anim_t * 18.0)) if attacking else 0.0)
	if _parts.has("body"):
		(_parts["body"] as Node3D).rotation.z = sin(_anim_t * 2.0) * 0.05


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
		# Crew out on a waystation pier are beyond reach.
		if p == null or not p.alive or not ship.is_aboard(p.position):
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

func _think_outside(delta: float, ship: Mothership) -> void:
	_attack_cd = maxf(0.0, _attack_cd - delta)
	_repath -= delta
	attacking = false
	var victim := _station_target(delta, ship)
	if victim == null:
		_idle(delta)
		_separate(delta, ship)
		return
	var to := victim.position - position
	to.y = 0.0
	var dist := to.length()
	if _retreat_t > 0.0:
		# Hit and run: scuttle off (and up a wall, see _crawl) before the next pounce.
		_retreat_t -= delta
		_back_off(delta, ship, _retreat_dir)
		_face(_retreat_dir)
		_separate(delta, ship)
		return
	if kind == "needler":
		var sees := _sees(ship, victim)
		if sees and dist < stat("reach"):
			_face(to)
			if _attack_cd <= 0.0:
				_attack_cd = stat("cooldown") * randf_range(0.85, 1.15)
				_fire_needle(ship, victim)
			attacking = _attack_cd > stat("cooldown") - 0.35
			if dist < NEEDLE_NEAR:
				_back_off(delta, ship, -to.normalized())
			elif dist > NEEDLE_FAR:
				_chase(delta, ship, victim)
		else:
			_chase(delta, ship, victim)
	elif dist < stat("reach"):
		attacking = true
		_face(to)
		if _attack_cd <= 0.0:
			_attack_cd = stat("cooldown")
			victim.hurt(stat("damage") * dmg_mult)
			Game.mission.fx_event.rpc("claw", ship.to_global(victim.position + Vector3(0, 1.0, 0)), 0)
			if kind == "skitter":
				_retreat_t = randf_range(RETREAT_TIME.x, RETREAT_TIME.y)
				_retreat_dir = Basis(Vector3.UP, randf_range(-1.1, 1.1)) * -to.normalized()
				_climb_t = 0.0
	else:
		_chase(delta, ship, victim)
	_separate(delta, ship)


## The crew member this alien is after: once noticed, it keeps chasing until the target gets away,
## but now and then it looks again and switches to someone better placed (see RETARGET_TIME).
func _station_target(delta: float, ship: Mothership) -> CrewMember:
	_provoke_t = maxf(0.0, _provoke_t - delta)
	var current := _outside_crew(ship, _target_id)
	if current:
		var d := current.position.distance_to(position)
		if d > CHASE_RANGE or not _sees(ship, current):
			_lost_t += delta
		else:
			_lost_t = 0.0
		if _lost_t >= FORGET_TIME or d >= CHASE_RANGE * 1.5:
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
		if d >= (CHASE_RANGE if provoker else NOTICE_RANGE) or not (d < HEAR_RANGE or _sees(ship, p)):
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
		# Its pack mates join in (and soon pick a target of their own among the crew).
		for c in get_parent().get_children():
			var mate := c as Boarder
			if mate and mate != self and mate.outside and mate._target_id == 0 and mate.position.distance_to(position) < 7.0:
				mate._target_id = _target_id
				mate._retarget_t = randf_range(0.1, 0.4)
	return best


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


## Line of sight from this alien's eyes to a crew member's chest (station walls and the ship block
## it).
func _sees(ship: Mothership, p: CrewMember) -> bool:
	var up := ship.global_basis.y
	var from := ship.to_global(position) + up * (stat("height") * 0.8)
	var to := ship.to_global(p.position) + up * 1.2
	var q := PhysicsRayQueryParameters3D.create(from, to, Game.LAYER_STATION | Game.LAYER_INTERIOR | Game.LAYER_HULL)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _chase(delta: float, ship: Mothership, victim: CrewMember) -> void:
	var graph: AStar3D = ship.derelict_nav if ship.derelict_nav else ship.nav
	if _repath <= 0.0 or _goal.distance_to(victim.position) > 1.5:
		_set_goal(ship, graph, victim.position)
	_follow_path(delta)


func _fire_needle(ship: Mothership, victim: CrewMember) -> void:
	var up := ship.global_basis.y
	var muzzle := ship.to_global(position + Basis(Vector3.UP, rotation.y) * Vector3(0.22, 1.75, -0.95))
	var target := ship.to_global(victim.position) + up * 1.15
	var dir := (target - muzzle).normalized()
	dir = (dir + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * NEEDLE_SPREAD).normalized()
	Game.mission.projectiles.fire("needle", muzzle, dir * NEEDLE_SPEED, stat("damage") * dmg_mult)
	Game.mission.fx_event.rpc("needle", muzzle, 0)


## Step away from a crew member who came too close (unless a wall is in the way).
func _back_off(delta: float, ship: Mothership, away: Vector3) -> void:
	var step := away * stat("speed") * 0.8 * delta
	var from := ship.to_global(position + Vector3(0, 0.6, 0))
	var q := PhysicsRayQueryParameters3D.create(from, from + ship.global_basis * (away * 1.2), Game.LAYER_STATION | Game.LAYER_INTERIOR | Game.LAYER_HULL)
	if get_world_3d().direct_space_state.intersect_ray(q).is_empty():
		position += step


## Nobody around: shuffle about near the spot it guards.
func _idle(delta: float) -> void:
	_wander_t -= delta
	if _wander_t <= 0.0:
		_wander_t = randf_range(2.5, 6.0)
		_wander = home + Vector3(randf_range(-2.0, 2.0), 0.0, randf_range(-2.0, 2.0))
	var to := _wander - position
	to.y = 0.0
	if to.length() > 0.3:
		position += to.normalized() * minf(stat("speed") * 0.3 * delta, to.length())
		_face(to)


## Keep a little room between aliens so a pack doesn't merge into one.
func _separate(delta: float, _ship: Mothership) -> void:
	var push := Vector3.ZERO
	for c in get_parent().get_children():
		var mate := c as Boarder
		if mate == null or mate == self:
			continue
		var d := position - mate.position
		d.y = 0.0
		var l := d.length()
		if l < PERSONAL_SPACE:
			push += (d / l if l > 0.001 else Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()) * (PERSONAL_SPACE - l)
	if push != Vector3.ZERO:
		position += push.limit_length(1.0) * 4.0 * delta


# --- Skitters on the walls and ceilings ---------------------------------------------------------

## Put the skitter on the surface it is crawling on: the floor, a wall beside its floor track or the
## ceiling above it, turned to stand on that surface and face along its heading. It leaps between
## surfaces, drops to the floor near doorways and corridors, and pounces when its prey is close.
func _crawl(delta: float, ship: Mothership) -> void:
	_probe_t -= delta
	var heading := Basis(Vector3.UP, _heading) * Vector3.FORWARD
	if _probe_t <= 0.0:
		_probe_t = 0.1
		_ceil_h = _ceiling_above(ship, _ground)
		var ahead := _ground + heading * CLIMB_LOOKAHEAD * 0.6
		if _path_i < _path.size():
			ahead = _ground + (_path[_path_i] - _ground).limit_length(CLIMB_LOOKAHEAD)
		_ceil_ahead = _ceiling_above(ship, ahead)
		if _climb == 1:
			_probe_wall(ship)
	var prey: CrewMember = null
	if _target_id != 0:
		prey = instance_from_id(_target_id) as CrewMember
	var retreating := _retreat_t > 0.0
	var pounce := not retreating and prey != null and is_instance_valid(prey) \
			and Vector2(prey.position.x - _ground.x, prey.position.z - _ground.z).length() < POUNCE_RANGE
	var roomy := _ceil_h > CLIMB_CEILING and _ceil_ahead > CLIMB_CEILING
	_climb_t -= delta
	if pounce or not roomy:
		_climb = 0
	elif _climb_t <= 0.0:
		_climb_t = randf_range(1.2, 3.0) if prey else randf_range(3.0, 7.0)
		var r := randf()
		_climb = 0 if r < (0.0 if retreating else (0.1 if prey else 0.25)) else (1 if r < 0.6 else 2)
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
	_surf_pos = _surf_pos.move_toward(target, stat("speed") * 2.4 * delta)
	if _surf_up.dot(up) < -0.9:
		# Turning right over (floor to ceiling): roll through the side first.
		_surf_up = (_surf_up + heading.cross(Vector3.UP) * 0.4).normalized()
	_surf_up = _surf_up.lerp(up, NetUtil.smooth(12.0, delta)).normalized()
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
## doorway at the climbing height, the skitter climbs above it.
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


## Where the middle of the body is (global): skitters on a wall or ceiling hang off it.
func center_global() -> Vector3:
	return global_transform * Vector3(0, stat("height") * 0.5, 0)


# --- Movement ----------------------------------------------------------------------------------

func _set_goal(ship: Mothership, graph: AStar3D, goal: Vector3) -> void:
	_repath = 0.6
	_goal = goal
	var from := ship.nav_closest(graph, position)
	var to := ship.nav_closest(graph, goal)
	_path = graph.get_point_path(from, to)
	_path.append(goal)
	_path_i = 0
	# Skip waypoints behind us.
	if _path.size() > 1 and position.distance_to(_path[1]) < _path[0].distance_to(_path[1]):
		_path_i = 1


func _follow_path(delta: float) -> void:
	if _path_i >= _path.size():
		return
	var wp := _path[_path_i]
	var to := wp - position
	to.y = 0.0
	if to.length() < 0.35:
		_path_i += 1
		return
	var step := minf(stat("speed") * delta, to.length())
	position += to.normalized() * step
	if outside:
		# Follow the floor (the pier, the station and their small steps).
		position.y = move_toward(position.y, wp.y, 3.0 * delta)
	_face(to)


func _face(dir: Vector3) -> void:
	if dir.length_squared() > 0.001:
		rotation.y = atan2(-dir.x, -dir.z)


## Server: damage from the crew. `info["by"]` is the shooter's peer id (crew bots included) when known.
func take_damage(amount: float, info: Dictionary) -> void:
	if not multiplayer.is_server() or hp <= 0.0:
		return
	hp -= amount
	if outside:
		var ship := _ship()
		var shooter := ship.crew_root.get_node_or_null(str(info.get("by", 0))) as CrewMember
		if shooter and shooter.alive and not ship.is_aboard(shooter.position):
			# Shot at: the shooter becomes the prime suspect for a while.
			_provoker = shooter.get_instance_id()
			_provoke_t = PROVOKE_TIME
			_retarget_t = 0.0
		if _target_id == 0:
			# Go and find the shooter (or whoever is closest if it doesn't know who).
			_wander_t = 0.0
			if _provoke_t > 0.0 and _outside_crew(ship, _provoker):
				_target_id = _provoker
			else:
				var best_d := CHASE_RANGE
				for c in ship.crew_root.get_children():
					var p := c as CrewMember
					if p and p.alive and not ship.is_aboard(p.position) and p.position.distance_to(position) < best_d:
						best_d = p.position.distance_to(position)
						_target_id = p.get_instance_id()
	if hp <= 0.0:
		var mission := Game.mission as MissionLevel
		if mission:
			mission.kills += 1
			var size := 0.45 if kind == "skitter" else (1.1 if kind == "needler" else 1.0)
			mission.fx_event.rpc("boarder_die", center_global(), size)
		queue_free()
