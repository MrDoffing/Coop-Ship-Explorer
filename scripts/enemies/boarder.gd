class_name Boarder
extends Node3D
## An alien that broke into the mothership. It lives in ship-local space (under Interior/Boarders),
## hunts nearby crew members and otherwise wrecks the engine and weapon systems. The crew kills it
## with blasters. Simulated on the server, following the interior waypoint graph.

const SPEED := 3.8
const ATTACK_RANGE := 1.7
const ATTACK_DAMAGE := 13.0
const SABOTAGE_DPS := 6.0
const HUNT_RANGE := 16.0

# Replicated (server authority), ship-local.
var net_pos := Vector3.ZERO
var net_yaw := 0.0
var hp := 55.0
var max_hp := 55.0
var attacking := false

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


func _init() -> void:
	NetUtil.add_sync(self, ["net_pos", "net_yaw"], ["hp", "attacking"], 0.05)


func setup(data: Dictionary) -> void:
	name = str(data["name"])
	position = data["pos"]
	net_pos = position
	max_hp = float(data.get("hp", 55.0))
	hp = max_hp


func _ready() -> void:
	add_to_group("boarders")
	var model := Node3D.new()
	model.position = Vector3(0, 0.75, 0)
	add_child(model)
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
	cap.radius = 0.6
	cap.height = 1.8
	cs.shape = cap
	cs.position = Vector3(0, 0.8, 0)
	area.add_child(cs)
	add_child(area)
	_last_hp = hp


func _ship() -> Mothership:
	return get_parent().get_parent().get_parent() as Mothership


func _physics_process(delta: float) -> void:
	var ship := _ship()
	if ship == null:
		return
	if multiplayer.is_server():
		_think(delta, ship)
		net_pos = position
		net_yaw = rotation.y
	else:
		var k := NetUtil.smooth(14.0, delta)
		position = position.lerp(net_pos, k) if position.distance_to(net_pos) < 4.0 else net_pos
		rotation.y = lerp_angle(rotation.y, net_yaw, k)


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
	for i in legs.size():
		(legs[i] as Node3D).rotation.x = sin(_anim_t * 11.0 + i * 1.7) * 0.4
	var swing := sin(_anim_t * (16.0 if attacking else 4.0)) * (0.8 if attacking else 0.3)
	(_parts["arm_l"] as Node3D).rotation.x = swing
	(_parts["arm_r"] as Node3D).rotation.x = -swing


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
		if to.length() < ATTACK_RANGE:
			attacking = true
			_face(to)
			if _attack_cd <= 0.0:
				_attack_cd = 1.1
				victim.hurt(ATTACK_DAMAGE)
				Game.mission.fx_event.rpc("claw", ship.to_global(victim.position + Vector3(0, 1.2, 0)), 0)
			return
		if _repath <= 0.0 or _goal.distance_to(victim.position) > 1.5:
			_set_goal(ship, victim.position)
	else:
		# No crew nearby: sabotage the closest machine.
		if _goal_panel < 0 or _repath <= 0.0:
			_goal_panel = _closest_panel()
			_set_goal(ship, _panel_spot(_goal_panel))
		var spot := _panel_spot(_goal_panel)
		if position.distance_to(spot) < 0.9:
			attacking = true
			_face(Vector3(ShipBuilder.REPAIR_PANELS[_goal_panel]["pos"]) - position)
			ship.damage_system(ShipBuilder.REPAIR_PANELS[_goal_panel]["system"], SABOTAGE_DPS * delta)
			return
	_follow_path(delta)


func _closest_player(ship: Mothership) -> CrewMember:
	var best: CrewMember = null
	var best_d := HUNT_RANGE
	for c in ship.crew_root.get_children():
		var p := c as CrewMember
		# Crew out on a waystation pier are beyond reach.
		if p == null or not p.alive or not Mothership.is_aboard(p.position):
			continue
		var d := p.position.distance_to(position)
		if d < best_d:
			best_d = d
			best = p
	return best


func _closest_panel() -> int:
	var best := 0
	var best_d := INF
	for i in ShipBuilder.REPAIR_PANELS.size():
		var d := _panel_spot(i).distance_to(position)
		if d < best_d:
			best_d = d
			best = i
	return best


func _panel_spot(i: int) -> Vector3:
	var p: Dictionary = ShipBuilder.REPAIR_PANELS[i]
	var yaw: float = p["yaw"]
	var spot: Vector3 = p["pos"] + Vector3(-sin(yaw), 0, -cos(yaw)) * 0.9
	spot.y = 0.0
	return spot


func _set_goal(ship: Mothership, goal: Vector3) -> void:
	_repath = 0.6
	_goal = goal
	var from := ship.nav.get_closest_point(position)
	var to := ship.nav.get_closest_point(goal)
	_path = ship.nav.get_point_path(from, to)
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
	var step := minf(SPEED * delta, to.length())
	position += to.normalized() * step
	_face(to)


func _face(dir: Vector3) -> void:
	if dir.length_squared() > 0.001:
		rotation.y = atan2(-dir.x, -dir.z)


func take_damage(amount: float, _info: Dictionary) -> void:
	if not multiplayer.is_server() or hp <= 0.0:
		return
	hp -= amount
	if hp <= 0.0:
		var mission := Game.mission as MissionLevel
		if mission:
			mission.kills += 1
			mission.fx_event.rpc("boarder_die", global_position + Vector3(0, 0.8, 0), 0)
		queue_free()
