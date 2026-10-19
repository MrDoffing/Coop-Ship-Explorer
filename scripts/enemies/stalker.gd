class_name Stalker
extends Boarder
## The stalker: taller than a man, glossy black, all limbs, a long head and a bladed tail. It takes
## a lot of shooting and roams the whole station. Once it spots someone it rushes them, claws a few
## times and runs off to hide out of sight, then comes back for more. Badly hurt it flees to its
## lair (or anywhere far from the crew) and heals there before it hunts again. A noise (the
## generator starting, a lockdown's alarm) draws it, as soon as there's a way there.

enum { ROAM, RUSH, CLAW, RETREAT, HIDE, FLEE, RECOVER }
## Speeds (m/s): prowling and running.
const WALK := 2.6
const RUN := 8.2
## It spots crew it can see within SIGHT (or hear within HEARING, by the open ways: see
## Boarder._hears), and gives up a rush it has lost sight of for LOSE_TIME seconds.
const SIGHT := 22.0
const HEARING := 6.0
const LOSE_TIME := 3.0
## A visit: CLAWS strikes, then off to hide at least HIDE_DIST from everyone and out of their sight,
## for HIDE_TIME seconds; cornered there (crew within CORNERED) it attacks.
const CLAWS := Vector2i(2, 4)
const HIDE_DIST := 14.0
const HIDE_TIME := Vector2(5.0, 10.0)
const CORNERED := 3.5
## Below FLEE_AT of its health it flees and heals HEAL_RATE of its full health a second where
## nobody is within SAFE_DIST, until back to HEALED_AT.
const FLEE_AT := 0.35
const HEALED_AT := 0.85
const HEAL_RATE := 0.045
const SAFE_DIST := 10.0

var _state := ROAM
var _timer := 0.0
var _claws_left := 0
var _lair := Vector3.ZERO
var _seen_t := 0.0
var _hide_for := 6.0
var _noise := Vector3(INF, INF, INF)
var _noise_t := 0.0


func _setup(data: Dictionary) -> void:
	_lair = data.get("lair", position)


func save_data() -> Dictionary:
	return {"lair": _lair}


func _enter(state: int) -> void:
	_state = state
	mode = state
	_timer = 0.0
	_hide_for = randf_range(HIDE_TIME.x, HIDE_TIME.y)
	_repath = 0.0
	_path = PackedVector3Array()
	_path_i = 0


func _think_outside(delta: float, ship: Mothership) -> void:
	_attack_cd = maxf(0.0, _attack_cd - delta)
	_repath -= delta
	_timer += delta
	attacking = _state == CLAW
	var graph := _graph(ship)
	match _state:
		ROAM:
			var prey := _spot(ship)
			if prey:
				_target_id = prey.get_instance_id()
				_seen_t = 0.0
				_enter(RUSH)
				Game.mission.fx_event.rpc("stalker_shriek", ship.to_global(position + Vector3(0, 2.0, 0)), 0)
				return
			if _noise.x < INF:
				_noise_t -= delta
				if _repath <= 0.0:
					_set_goal(ship, graph, _noise)
					_repath = 2.0
				# While there's no way there (a shut door) it waits and tries again for a while.
				var there := position.distance_to(_noise) < 1.5 or (not _path.is_empty() and _follow_path(delta, WALK * 1.4))
				if there or _noise_t <= 0.0:
					_noise = Vector3(INF, INF, INF)
				return
			if _path_i >= _path.size() or _timer > 14.0:
				_timer = 0.0
				_set_goal(ship, graph, _random_spot(ship, graph))
				_repath = 1000.0
			_follow_path(delta, WALK)
		RUSH:
			var prey := _outside_crew(ship, _target_id)
			if prey == null:
				_enter(ROAM)
				return
			_seen_t = 0.0 if _sees(ship, prey) else _seen_t + delta
			if _seen_t > LOSE_TIME:
				_enter(ROAM)
				return
			var to := prey.position - position
			to.y = 0.0
			if to.length() < stat("reach"):
				_claws_left = randi_range(CLAWS.x, CLAWS.y)
				_attack_cd = 0.15
				_enter(CLAW)
				return
			_chase(delta, ship, prey, RUN)
		CLAW:
			var prey := _outside_crew(ship, _target_id)
			if prey == null:
				_enter(RETREAT)
				return
			var to := prey.position - position
			to.y = 0.0
			_face(to)
			if to.length() > stat("reach") + 0.5:
				_chase(delta, ship, prey, RUN)
			elif _attack_cd <= 0.0:
				_attack_cd = stat("cooldown") * randf_range(0.85, 1.2)
				_claw(ship, prey)
				_claws_left -= 1
				if _claws_left <= 0:
					_enter(RETREAT)
					_set_goal(ship, graph, _hide_spot(ship, graph))
					_repath = 1000.0
		RETREAT, FLEE:
			if _follow_path(delta, RUN) or _timer > 12.0:
				_enter(HIDE if _state == RETREAT else RECOVER)
				_timer = 0.0
				_claws_left = 0
		HIDE:
			var near := _nearest_crew(ship)
			if near and near.position.distance_to(position) < CORNERED and (_sees(ship, near) or _hears(ship, near.position, CORNERED)):
				_target_id = near.get_instance_id()
				_enter(RUSH)
			elif _timer > _hide_for:
				_enter(ROAM)
		RECOVER:
			var near := _nearest_crew(ship)
			if near and near.position.distance_to(position) < SAFE_DIST and _sees(ship, near):
				if near.position.distance_to(position) < CORNERED:
					_target_id = near.get_instance_id()
					_enter(RUSH)
				else:
					_enter(FLEE)
					_set_goal(ship, graph, _hide_spot(ship, graph))
					_repath = 1000.0
				return
			hp = minf(max_hp, hp + HEAL_RATE * max_hp * delta)
			if hp >= max_hp * HEALED_AT:
				_enter(ROAM)


## Someone it can see within SIGHT (or hear within HEARING), the closest.
func _spot(ship: Mothership) -> CrewMember:
	var best: CrewMember = null
	var best_d := SIGHT
	for c in ship.crew_root.get_children():
		var p := c as CrewMember
		if p == null or not p.alive or ship.is_aboard(p.position):
			continue
		var d := p.position.distance_to(position)
		if d < best_d and (_sees(ship, p) or _hears(ship, p.position, HEARING)):
			best_d = d
			best = p
	return best


func _nearest_crew(ship: Mothership) -> CrewMember:
	var best: CrewMember = null
	var best_d := INF
	for c in ship.crew_root.get_children():
		var p := c as CrewMember
		if p and p.alive and not ship.is_aboard(p.position) and p.position.distance_to(position) < best_d:
			best_d = p.position.distance_to(position)
			best = p
	return best


## A waypoint anywhere it can walk to (open doors only).
func _random_spot(ship: Mothership, graph: AStar3D) -> Vector3:
	var from := ship.nav_closest(graph, position)
	var ids := graph.get_point_ids()
	for i in 12:
		var id: int = ids[randi() % ids.size()]
		if graph.is_point_disabled(id) or id >= DerelictBuilder.NAV_PIER:
			continue
		if not graph.get_id_path(from, id).is_empty():
			return graph.get_point_position(id)
	return home


## Somewhere to hide: a reachable waypoint as far as possible from the crew (at least HIDE_DIST)
## and out of their sight; failing that, its lair.
func _hide_spot(ship: Mothership, graph: AStar3D) -> Vector3:
	var crew: Array[Vector3] = []
	for c in ship.crew_root.get_children():
		var p := c as CrewMember
		if p and p.alive and not ship.is_aboard(p.position):
			crew.append(p.position)
	var from := ship.nav_closest(graph, position)
	var ids := graph.get_point_ids()
	var best := _lair
	var best_score := -INF
	for i in 24:
		var id: int = ids[randi() % ids.size()]
		if graph.is_point_disabled(id) or id >= DerelictBuilder.NAV_PIER:
			continue
		var at := graph.get_point_position(id)
		var far := INF
		for q in crew:
			far = minf(far, q.distance_to(at))
		if far < HIDE_DIST:
			continue
		var hidden := true
		for q in crew:
			if _clear_from(ship, ship.to_global(at + Vector3(0, 1.2, 0)), ship.to_global(q + Vector3(0, 1.4, 0))):
				hidden = false
				break
		var score := minf(far, 30.0) + (12.0 if hidden else 0.0) + randf() * 4.0
		if score > best_score and not graph.get_id_path(from, id).is_empty():
			best_score = score
			best = at
	return best


func _hurt(_amount: float, shooter: CrewMember) -> void:
	if hp < max_hp * FLEE_AT and _state != FLEE and _state != RECOVER:
		var ship := _ship()
		_enter(FLEE)
		var graph := _graph(ship)
		# Home to the lair if it is far enough from the crew, else anywhere safe.
		var lair_ok := true
		for c in ship.crew_root.get_children():
			var p := c as CrewMember
			if p and p.alive and not ship.is_aboard(p.position) and p.position.distance_to(_lair) < HIDE_DIST:
				lair_ok = false
		_set_goal(ship, graph, _lair if lair_ok else _hide_spot(ship, graph))
		_repath = 1000.0
		Game.mission.fx_event.rpc("stalker_shriek", ship.to_global(position + Vector3(0, 2.0, 0)), 1)
	elif shooter and (_state == ROAM or _state == HIDE):
		_target_id = shooter.get_instance_id()
		_enter(RUSH)


func hear(pos: Vector3) -> void:
	if _state == ROAM:
		_noise = pos
		_noise_t = HEARD_TIME
		_repath = 0.0


# --- Looks -------------------------------------------------------------------------------------

func _build(model: Node3D) -> Dictionary:
	var parts := {}
	var skin := Alien.organic(Color(0.05, 0.06, 0.08), Color(0.25, 0.45, 0.6), 1.2, 9.0)
	var bone := Alien.organic(Color(0.12, 0.13, 0.15), Color(0.3, 0.5, 0.55), 0.8, 14.0)
	var teeth := Models.mat(Color(0.5, 0.5, 0.46), 0.7, 0.25)
	var hips := Node3D.new()
	hips.position = Vector3(0, 1.1, 0.15)
	model.add_child(hips)
	parts["hips"] = hips
	# The torso leans forward from the hips; ribs and dorsal tubes.
	var torso := Node3D.new()
	torso.rotation.x = -0.75
	hips.add_child(torso)
	parts["torso"] = torso
	# A spine with a narrow ribcage round it, shoulders, and the dorsal tubes swept back.
	Models.capsule(torso, Vector3(0, 0.48, 0.06), 0.11, 1.1, skin)
	Models.sphere(torso, Vector3(0, 0.62, -0.06), 0.17, skin, Vector3(1.0, 1.6, 0.85))
	for i in 6:
		var y := 0.3 + i * 0.1
		var w := 0.17 - absf(i - 2.5) * 0.02
		for side: float in [-1.0, 1.0]:
			Models.strut(torso, Vector3(0, y, 0.08), Vector3(side * w, y - 0.03, -0.04), 0.022, bone)
			Models.strut(torso, Vector3(side * w, y - 0.03, -0.04), Vector3(side * w * 0.45, y - 0.06, -0.14), 0.018, bone)
	for side: float in [-1.0, 1.0]:
		Models.sphere(torso, Vector3(side * 0.22, 0.86, -0.02), 0.08, skin)
		Models.cylinder(torso, Vector3(side * 0.12, 0.98, 0.3), 0.05, 0.8, bone, Vector3(-58, 0, side * 14.0), 0.022)
		Models.cylinder(torso, Vector3(side * 0.06, 0.88, 0.32), 0.042, 0.65, bone, Vector3(-62, 0, side * 7.0), 0.02)
	# The head: long and smooth, swept back, with a jaw of teeth under it.
	var head := Node3D.new()
	head.position = Vector3(0, 1.0, -0.05)
	head.rotation.x = 0.55
	torso.add_child(head)
	parts["head"] = head
	# The cranium sweeps far back over the shoulders; the face is narrow, the jaw a row of small
	# steel-grey teeth under a glossy brow.
	Models.capsule(head, Vector3(0, 0.12, 0.38), 0.14, 1.15, skin, Vector3(-68, 0, 0))
	Models.sphere(head, Vector3(0, 0.02, -0.16), 0.11, skin, Vector3(0.85, 0.8, 1.45))
	Models.sphere(head, Vector3(0, 0.06, -0.08), 0.1, Models.mat(Color(0.08, 0.12, 0.16), 0.6, 0.05), Vector3(1.0, 0.45, 1.5))
	for i in 7:
		var tx := -0.045 + i * 0.015
		Models.cylinder(head, Vector3(tx, -0.08, -0.27 + absf(tx) * 0.6), 0.006, 0.035, teeth, Vector3.ZERO, 0.0, 5)
		Models.cylinder(head, Vector3(tx, -0.12, -0.25 + absf(tx) * 0.6), 0.006, 0.035, teeth, Vector3(180, 0, 0), 0.0, 5)
	Models.sphere(head, Vector3(0, -0.13, -0.17), 0.075, skin, Vector3(0.9, 0.5, 1.4))
	# Arms with three claws.
	for side: float in [-1.0, 1.0]:
		var arm := Node3D.new()
		arm.position = Vector3(side * 0.24, 0.85, -0.05)
		torso.add_child(arm)
		Models.strut(arm, Vector3.ZERO, Vector3(side * 0.12, -0.45, -0.2), 0.05, skin)
		Models.strut(arm, Vector3(side * 0.12, -0.45, -0.2), Vector3(side * 0.08, -0.9, -0.35), 0.04, skin)
		for f in 3:
			Models.strut(arm, Vector3(side * 0.08, -0.9, -0.35), Vector3(side * (0.03 + f * 0.04), -1.1, -0.48 + f * 0.03), 0.015, teeth)
		parts["arm_l" if side < 0 else "arm_r"] = arm
	# Legs: thigh forward, shin back, a long foot (digitigrade).
	var legs: Array[Node3D] = []
	for side: float in [-1.0, 1.0]:
		var leg := Node3D.new()
		leg.position = Vector3(side * 0.2, 0.0, 0.0)
		hips.add_child(leg)
		Models.strut(leg, Vector3.ZERO, Vector3(side * 0.05, -0.45, -0.28), 0.08, skin)
		Models.strut(leg, Vector3(side * 0.05, -0.45, -0.28), Vector3(side * 0.06, -0.8, 0.18), 0.055, skin)
		Models.strut(leg, Vector3(side * 0.06, -0.8, 0.18), Vector3(side * 0.06, -1.08, 0.02), 0.04, bone)
		Models.box(leg, Vector3(side * 0.06, -1.08, -0.08), Vector3(0.1, 0.04, 0.26), bone)
		legs.append(leg)
	parts["legs"] = legs
	# The tail: segments tapering to a blade, swinging.
	var tail := Node3D.new()
	tail.position = Vector3(0, -0.05, 0.25)
	hips.add_child(tail)
	parts["tail"] = tail
	var seg := tail
	var segs: Array[Node3D] = []
	for i in 7:
		var s := Node3D.new()
		s.position = Vector3(0, 0, 0.0 if i == 0 else 0.26)
		s.rotation.x = 0.12
		seg.add_child(s)
		Models.capsule(s, Vector3(0, 0, 0.13), 0.07 - i * 0.008, 0.3, bone, Vector3(90, 0, 0))
		segs.append(s)
		seg = s
	Models.box(seg, Vector3(0, 0, 0.36), Vector3(0.02, 0.12, 0.28), teeth, Vector3(0, 0, 0))
	parts["tail_segs"] = segs
	return parts


func _animate(delta: float) -> void:
	var speed := _speed_seen
	var running := speed > 4.0
	var crouch := mode == HIDE or mode == RECOVER
	var hips: Node3D = _parts["hips"]
	var torso: Node3D = _parts["torso"]
	var target_y := 0.75 if crouch else (1.0 if running else 1.1)
	hips.position.y = lerpf(hips.position.y, target_y, NetUtil.smooth(6.0, delta))
	torso.rotation.x = lerpf(torso.rotation.x, -1.15 if running else (-0.95 if crouch else -0.75), NetUtil.smooth(6.0, delta))
	var stride := clampf(speed / RUN, 0.0, 1.0)
	var cycle := _anim_t * (6.0 + stride * 7.0)
	var legs: Array = _parts["legs"]
	for i in legs.size():
		(legs[i] as Node3D).rotation.x = sin(cycle + i * PI) * (0.15 + 0.6 * stride)
	hips.position.y += absf(sin(cycle)) * 0.06 * stride
	var swipe := sin(_anim_t * 14.0) * 0.9 if mode == CLAW else sin(cycle) * 0.3 * stride
	(_parts["arm_l"] as Node3D).rotation.x = swipe
	(_parts["arm_r"] as Node3D).rotation.x = -swipe if mode == CLAW else swipe * -1.0
	var head: Node3D = _parts["head"]
	head.rotation.y = sin(_anim_t * 0.7) * (0.35 if mode == ROAM else 0.1)
	var segs: Array = _parts["tail_segs"]
	for i in segs.size():
		(segs[i] as Node3D).rotation.y = sin(_anim_t * 2.2 - i * 0.6) * (0.12 + 0.05 * i) * (1.5 if crouch else 1.0)
