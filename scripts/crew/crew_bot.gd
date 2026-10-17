class_name CrewBot
extends RefCounted
## Server-side brain for a crew bot (a CrewMember with `bot = true`).
##
## Priorities: defend themselves against boarders in sight with their blasters (reloading when
## the magazine runs dry, and topping it up between fights), then repair the engine or weapon
## systems when they are damaged (offline systems first). When no aliens have
## been around for a while, bots mine crystals with the mining lasers (one bot per laser);
## otherwise bots man the free guns and shoot aliens (or nearby egg sacs), and a bot left without
## a gun turns a mining laser on the aliens. Bots walk the interior waypoint graph, take stations
## like crew do and give them up when a human wants them.
##
## When the ship has landed at an abandoned station and the host goes out exploring, bots drop
## their jobs and follow the host around the station. They never pick up crates, but they shoot
## any alien that comes close (a little further out than aboard), and go back to work once the
## host is aboard again.

const THINK_INTERVAL := 0.5
## Start repairing a system once it drops below this.
const REPAIR_BELOW := 70.0
const GUN_RANGE := 105.0
const SAC_RANGE := 60.0
## How fast the bot can swing a turret (rad/s) and how close the aim must be before firing.
const TURN_RATE := 2.4
const FIRE_TOLERANCE := 0.045
## Seconds a bot studies a new target before opening fire.
const REACTION := 0.35
## Self-defence: boarders closer than this (and in line of sight) are shot on sight. Bots react
## and shoot a little slower and less accurately than a player would.
const DEFEND_RANGE := 10.0
## Mining laser: aliens this close to the ship count as a threat; with none around for SAFE_DELAY
## seconds it is safe to mine. Deposits near a nest are left alone (hitting a sac agitates it).
const THREAT_RANGE := 100.0
const SAFE_DELAY := 6.0
const LASER_TOLERANCE := 0.03
const NEST_CLEARANCE := 24.0
const DEFEND_REACTION := 0.5
const BLASTER_INTERVAL := 0.36
## Blaster aim error in radians: a base amount plus more per metre of distance.
const BLASTER_SPREAD := 0.035
const BLASTER_SPREAD_PER_M := 0.016
## Following the host: how close the first bot stays (the others keep a little further back), and
## how far away they open fire on aliens.
const FOLLOW_GAP := 2.6
const FOLLOW_DEFEND_RANGE := 16.0

var crew: CrewMember
## "", "repair", "gun" or "mine".
var task := ""
var system := ""
var panel := -1
## The station the bot works at: a gun station for "gun", a mining laser station for "mine".
var gun := ""
var seated := false

var _think := 0.0
var _path := PackedVector3Array()
var _path_i := 0
var _goal := Vector3(INF, INF, INF)
var _stuck_t := 0.0
var _stuck_pos := Vector3.ZERO
var _aim := Vector2.ZERO
var _target_id := 0
var _target_sac := -1
var _target_t := 0.0
var _retarget := 0.0
var _fx_t := 0.0
## Boarder being fought (instance id), and the self-defence timers.
var _foe_id := 0
var _foe_scan := 0.0
var _foe_react := 0.0
var _foe_cd := 0.0
## Free-flying aliens near the ship at the last decision, and seconds without any.
var _threats := 0
var _safe_t := 0.0
## True while tagging along behind the host at an abandoned station.
var following := false
var _follow_goal := Vector3(INF, INF, INF)


func _init(c: CrewMember) -> void:
	crew = c


## True while the bot is shooting at a boarder.
func is_fighting() -> bool:
	return _foe_id != 0


func tick(delta: float) -> void:
	var ship := crew.ship
	if ship == null or not ship.alive:
		_hold_still(delta)
		return
	# Self-defence comes before any job.
	if _defend(delta):
		return
	if _follow_host(delta):
		return
	_safe_t = 0.0 if _threats > 0 else _safe_t + delta
	_think -= delta
	if _think <= 0.0:
		_think = THINK_INTERVAL
		_decide()
	match task:
		"repair":
			_do_repair(delta)
		"gun":
			_do_gun(delta)
		"mine":
			_do_mine(delta)
		_:
			_do_idle(delta)


## Called when the bot is knocked out.
func on_died() -> void:
	if seated:
		crew.ship.release_peer(crew.peer_id)
	seated = false
	crew.station = ""
	task = ""
	_foe_id = 0
	_goal = Vector3(INF, INF, INF)


func reset() -> void:
	task = ""
	seated = false
	following = false
	_foe_id = 0
	_think = 0.0
	_goal = Vector3(INF, INF, INF)


# --- Decisions ---------------------------------------------------------------------------------

func _decide() -> void:
	var ship := crew.ship
	_threats = _count_threats()
	# Lost the station (a human took over, or it was released)?
	if seated and int(ship.occupants.get(gun, 0)) != crew.peer_id:
		_unseat(false)
		task = ""
	var need := _repair_need()
	if need != "":
		if task != "repair" or system != need:
			_start_repair(need)
		return
	if task == "repair" and ship.system_hp(system) < 100.0:
		return
	var safe := _threats == 0 and _safe_t >= SAFE_DELAY
	var g := _pick_gun()
	var laser := _free_laser()
	# Quiet: mine crystals. Aliens about: man a free gun, or use a laser on them if none is free.
	if safe and laser != "" and _pick_deposit(laser) != null:
		_start_mining(laser)
		return
	if not safe and g == "" and laser != "":
		_start_mining(laser)
		return
	if g != "":
		if task != "gun" or gun != g:
			_start_gun(g)
		return
	if task != "":
		if seated:
			_unseat(true)
		task = ""
		_goal = Vector3(INF, INF, INF)


## The system this bot should repair, or "" when nothing needs it.
func _repair_need() -> String:
	var ship := crew.ship
	var best := ""
	var best_score := INF
	for sys: String in ["engine", "weapons"]:
		var hpv := ship.system_hp(sys)
		var offline := not ship.system_online(sys)
		var mine := task == "repair" and system == sys
		if hpv >= 100.0 or (hpv >= REPAIR_BELOW and not offline and not mine):
			continue
		# Leave a merely damaged system to another bot already on it.
		if not offline and not mine and _bot_on("repair", sys) != null:
			continue
		var score := hpv - (100.0 if offline else 0.0)
		if score < best_score:
			best_score = score
			best = sys
	return best


func _pick_gun() -> String:
	var ship := crew.ship
	var options: Array[String] = []
	for g: String in ship.gun_stations():
		var holder := int(ship.occupants.get(g, 0))
		if holder != 0 and holder != crew.peer_id:
			continue
		if holder == 0 and _bot_on("gun", g) != null:
			continue
		options.append(g)
	if options.is_empty():
		return ""
	if task == "gun" and gun in options:
		return gun
	var best := options[0]
	var best_n := -1
	for g in options:
		var n := _threats_for(ship.turrets[g])
		if n > best_n:
			best_n = n
			best = g
	return best


## How many aliens a gun could engage right now.
func _threats_for(t: Turret) -> int:
	var ship := crew.ship
	var mount := ship.to_global(t.transform.origin)
	var n := 0
	for a in crew.get_tree().get_nodes_in_group("aliens"):
		var alien := a as Alien
		if alien == null or alien.attached >= 0 or mount.distance_to(alien.global_position) > GUN_RANGE:
			continue
		if t.within_limits(t.aim_at_local(ship.to_local(alien.global_position))):
			n += 1
	return n


## Another bot doing `what` on `which` (a system or a gun), if any.
func _bot_on(what: String, which: String) -> CrewMember:
	for c in crew.ship.crew_root.get_children():
		var m := c as CrewMember
		if m == null or m == crew or not m.bot or m.brain == null or not m.alive:
			continue
		if m.brain.task == what and (m.brain.system == which if what == "repair" else m.brain.gun == which):
			return m
	return null


func _start_repair(sys: String) -> void:
	if seated:
		_unseat(true)
	task = "repair"
	system = sys
	panel = _pick_panel(sys)
	crew.tool = 1
	_goal = Vector3(INF, INF, INF)


func _pick_panel(sys: String) -> int:
	var best := -1
	var best_d := INF
	var panels := crew.ship.repair_panels()
	for i in panels.size():
		if panels[i]["system"] != sys:
			continue
		var d := crew.position.distance_to(_panel_spot(i))
		var other := _bot_on("repair", sys)
		if other and other.brain.panel == i:
			d += 50.0
		if d < best_d:
			best_d = d
			best = i
	return best


func _start_gun(g: String) -> void:
	if seated and gun != g:
		_unseat(true)
	task = "gun"
	gun = g
	crew.tool = 0
	_goal = Vector3(INF, INF, INF)


func _start_mining(laser: String) -> void:
	if task == "mine" and gun == laser:
		return
	if seated and gun != laser:
		_unseat(true)
	task = "mine"
	gun = laser
	crew.tool = 0
	_target_id = 0
	_goal = Vector3(INF, INF, INF)


## A mining laser this bot may use (the one it is on, or a free one), or "" (also while docked).
func _free_laser() -> String:
	var ship := crew.ship
	if ship.landing != Mothership.Dock.FLYING:
		return ""
	if task == "mine" and gun in ship.laser_stations():
		var mine_holder := int(ship.occupants.get(gun, 0))
		if mine_holder == 0 or mine_holder == crew.peer_id:
			return gun
	for id: String in ship.laser_stations():
		var holder := int(ship.occupants.get(id, 0))
		if holder != 0 and holder != crew.peer_id:
			continue
		if _bot_on("mine", id) != null:
			continue
		return id
	return ""


## Free-flying aliens near the ship.
func _count_threats() -> int:
	var ship := crew.ship
	var n := 0
	for a in crew.get_tree().get_nodes_in_group("aliens"):
		var alien := a as Alien
		if alien and alien.attached < 0 and alien.hp > 0.0 and alien.global_position.distance_to(ship.global_position) < THREAT_RANGE:
			n += 1
	return n


# --- Tasks -------------------------------------------------------------------------------------

func _do_repair(delta: float) -> void:
	var ship := crew.ship
	if panel < 0:
		task = ""
		return
	if not _walk_to(_panel_spot(panel), delta):
		return
	var p: Dictionary = ship.repair_panels()[panel]
	var yaw: float = p["yaw"]
	crew.look_yaw = wrapf(yaw + PI, -PI, PI)
	crew.rotation.y = crew.look_yaw
	crew.look_pitch = -0.15
	crew.tool = 1
	ship.request_repair(system, delta)
	_fx_t -= delta
	if _fx_t <= 0.0:
		_fx_t = 0.25
		var pos: Vector3 = p["pos"]
		ship.fx_repair.rpc(pos + Vector3(-sin(yaw), 0, -cos(yaw)) * 0.12)
	if ship.system_hp(system) >= 100.0:
		task = ""
		_think = 0.0


## Walk to a station's seat and claim it. Returns true while seated there.
func _sit(id: String, delta: float) -> bool:
	var ship := crew.ship
	var st := ship.console(id)
	var seat: Vector3 = st["seat"]
	if not seated:
		if not _walk_to(seat, delta):
			return false
		if ship.bot_claim_station(crew.peer_id, id):
			seated = true
			crew.station = id
			crew.position = seat
			crew.rotation.y = st["seat_yaw"]
			crew.velocity = Vector3.ZERO
			crew.reset_physics_interpolation()
			_aim = ship.aim_of(id)
			_target_id = 0
		else:
			_think = 0.0
		return false
	crew.position = seat
	crew.rotation.y = st["seat_yaw"]
	crew.velocity = Vector3.ZERO
	return true


func _do_gun(delta: float) -> void:
	var ship := crew.ship
	if not _sit(gun, delta):
		return
	var t: Turret = ship.turrets[gun]
	_retarget -= delta
	if _retarget <= 0.0:
		_retarget = 0.4
		_choose_target(t)
	var firing := false
	var target := _target_point(t)
	if target.is_finite():
		var desired := t.aim_at_local(ship.to_local(target))
		_aim.x = move_toward(_aim.x, desired.x, TURN_RATE * delta)
		_aim.y = move_toward(_aim.y, desired.y, TURN_RATE * delta)
		_aim = t.clamp_aim(_aim)
		_target_t += delta
		var weapon := ship.gun_weapon(gun)
		var tolerance := FIRE_TOLERANCE * (2.5 if weapon == "flak" else 1.0)
		firing = _target_t > REACTION and (_aim - desired).length() < tolerance and ship.weapons_online
	crew.station_aim = _aim
	ship.bot_station_input(crew.peer_id, gun, {"aim": _aim, "fire": firing})


## Mining laser: crystals when it is quiet, aliens when they are about.
func _do_mine(delta: float) -> void:
	var ship := crew.ship
	if not _sit(gun, delta):
		return
	var t: Turret = ship.turrets[gun]
	_retarget -= delta
	if _retarget <= 0.0:
		_retarget = 0.4
		_choose_laser_target(t)
	var firing := false
	var target := _laser_point()
	if target.is_finite():
		var desired := t.aim_at_local(ship.to_local(target))
		_aim.x = move_toward(_aim.x, desired.x, TURN_RATE * delta)
		_aim.y = move_toward(_aim.y, desired.y, TURN_RATE * delta)
		_aim = t.clamp_aim(_aim)
		_target_t += delta
		firing = _target_t > REACTION and (_aim - desired).length() < LASER_TOLERANCE and ship.weapons_online
	crew.station_aim = _aim
	ship.bot_station_input(crew.peer_id, gun, {"aim": _aim, "fire": firing})


func _choose_laser_target(t: Turret) -> void:
	var ship := crew.ship
	var mount := ship.to_global(t.transform.origin)
	var reach := float(ship.stats["mining_range"]) - 2.0
	var found: Node3D = null
	if _threats > 0:
		var space := crew.get_world_3d().direct_space_state
		var best_d := reach
		for a in crew.get_tree().get_nodes_in_group("aliens"):
			var alien := a as Alien
			if alien == null or alien.attached >= 0 or alien.hp <= 0.0:
				continue
			var d := mount.distance_to(alien.global_position)
			if d >= reach:
				continue
			# Stay on the current target rather than flicking between aliens.
			var score := d * (0.6 if alien.get_instance_id() == _target_id else 1.0)
			if score >= best_d or not t.within_limits(t.aim_at_local(ship.to_local(alien.global_position))):
				continue
			var q := PhysicsRayQueryParameters3D.create(mount, alien.global_position, Game.LAYER_CAVE)
			if not space.intersect_ray(q).is_empty():
				continue
			best_d = score
			found = alien
	else:
		found = _pick_deposit(gun)
	var id := found.get_instance_id() if found else 0
	if id != _target_id:
		_target_id = id
		_target_sac = -1
		_target_t = 0.0


## Where the laser should point, or an infinite vector when there is nothing to hit.
func _laser_point() -> Vector3:
	if _target_id == 0:
		return Vector3(INF, INF, INF)
	var obj := instance_from_id(_target_id)
	if obj == null or not is_instance_valid(obj):
		_target_id = 0
		return Vector3(INF, INF, INF)
	if obj is Deposit:
		var dep := obj as Deposit
		return dep.global_position + dep.normal * 0.8
	var alien := obj as Alien
	if alien == null or alien.hp <= 0.0 or alien.attached >= 0:
		_target_id = 0
		return Vector3(INF, INF, INF)
	return alien.global_position


## Nearest crystal deposit a mining laser can reach and see (not fuel, not next to a nest), and
## that no other bot is cutting.
func _pick_deposit(laser: String) -> Deposit:
	var ship := crew.ship
	var t: Turret = ship.turrets[laser]
	var mount := ship.to_global(t.transform.origin)
	var space := crew.get_world_3d().direct_space_state
	var best: Deposit = null
	var best_d := float(ship.stats["mining_range"]) - 3.0
	for d in crew.get_tree().get_nodes_in_group("deposits"):
		var dep := d as Deposit
		if dep == null or dep.kind == "fuel" or dep.hp <= 0.0 or _deposit_taken(dep):
			continue
		var p := dep.global_position + dep.normal * 0.8
		var dist := mount.distance_to(p)
		if dist >= best_d or not t.within_limits(t.aim_at_local(ship.to_local(p))):
			continue
		var near_nest := false
		for n in crew.get_tree().get_nodes_in_group("nests"):
			var nest := n as Nest
			if nest.alive_sacs() > 0 and nest.global_position.distance_to(p) < NEST_CLEARANCE:
				near_nest = true
				break
		if near_nest:
			continue
		var q := PhysicsRayQueryParameters3D.create(mount, p, Game.LAYER_CAVE)
		if not space.intersect_ray(q).is_empty():
			continue
		best_d = dist
		best = dep
	return best


## Another bot's mining laser is already on this deposit.
func _deposit_taken(dep: Deposit) -> bool:
	for c in crew.ship.crew_root.get_children():
		var m := c as CrewMember
		if m and m != crew and m.bot and m.brain and m.brain.task == "mine" and m.brain._target_id == dep.get_instance_id():
			return true
	return false


func _do_idle(delta: float) -> void:
	var spots := crew.ship.idle_spots()
	if _walk_to(spots[absi(crew.peer_id) % spots.size()], delta):
		crew.tool = 0


func _hold_still(delta: float) -> void:
	crew.velocity = Vector3(0, crew.velocity.y - CrewMember.GRAVITY * delta, 0) if not crew.is_on_floor() else Vector3.ZERO
	if not seated:
		crew.move_and_slide()


## Leave the gun seat. `release` tells the ship (false when the ship already took it back).
func _unseat(release: bool) -> void:
	if release:
		crew.ship.release_peer(crew.peer_id)
	seated = false
	if crew.station != "":
		var st := crew.ship.console(crew.station)
		var yaw: float = st["seat_yaw"]
		crew.position = st["seat"] + Basis(Vector3.UP, yaw) * Vector3(0, 0.05, 0.9)
		crew.reset_physics_interpolation()
	crew.station = ""
	_goal = Vector3(INF, INF, INF)


# --- Following the host ------------------------------------------------------------------------

## At an abandoned station, tag along behind the host while the host is out of the ship. Returns
## true while following (the job waits).
func _follow_host(delta: float) -> bool:
	var ship := crew.ship
	var host: CrewMember = null
	if ship.landing == Mothership.Dock.LANDED and ship.derelict_k >= 0:
		host = ship.crew_root.get_node_or_null("1") as CrewMember
		if host and (not host.alive or ship.is_aboard(host.net_pos)):
			host = null
	if host == null:
		if following:
			# The host is back aboard: back to work.
			following = false
			_think = 0.0
			_goal = Vector3(INF, INF, INF)
		return false
	if not following:
		following = true
		if seated:
			_unseat(true)
		task = ""
		_goal = Vector3(INF, INF, INF)
		_follow_goal = Vector3(INF, INF, INF)
	crew.tool = 0
	var gap := FOLLOW_GAP + _follow_slot() * 1.4
	var to := host.net_pos - crew.position
	to.y = 0.0
	if to.length() <= gap:
		crew.velocity = Vector3(0, crew.velocity.y, 0)
		_fall(delta)
		if to.length_squared() > 0.01:
			crew.look_yaw = atan2(-to.x, -to.z)
			crew.rotation.y = crew.look_yaw
		return true
	if _follow_goal.distance_to(host.net_pos) > 1.5:
		_follow_goal = host.net_pos
	_walk_to(_follow_goal, delta)
	return true


## This bot's place in the line behind the host (0 = right behind).
func _follow_slot() -> int:
	var n := 0
	for c in crew.ship.crew_root.get_children():
		var m := c as CrewMember
		if m and m.bot and m != crew and m.peer_id > crew.peer_id:
			n += 1
	return n


# --- Self-defence ------------------------------------------------------------------------------

## Fight the nearest boarder in sight. Returns true while fighting (the job waits).
func _defend(delta: float) -> bool:
	_foe_scan -= delta
	if _foe_scan <= 0.0:
		_foe_scan = 0.25
		var found := _find_boarder()
		var id := found.get_instance_id() if found else 0
		if id != _foe_id:
			if id == 0:
				# Fight over: pick the job back up (walk back to the gun, the panel...).
				_think = 0.0
				_goal = Vector3(INF, INF, INF)
			_foe_id = id
			_foe_react = DEFEND_REACTION
	if _foe_id == 0:
		# Between fights: top up the magazine.
		if crew.ammo < CrewWeapons.mag(crew.weapon):
			crew.start_reload()
		return false
	var foe := instance_from_id(_foe_id) as Boarder
	if foe == null or not is_instance_valid(foe) or foe.hp <= 0.0:
		_foe_id = 0
		_think = 0.0
		_goal = Vector3(INF, INF, INF)
		return false
	if seated:
		_unseat(true)
	crew.tool = 0
	var to := foe.position - crew.position
	to.y = 0.0
	if to.length_squared() > 0.0001:
		crew.look_yaw = atan2(-to.x, -to.z)
		crew.rotation.y = crew.look_yaw
	crew.look_pitch = -0.08
	crew.velocity = Vector3(0, crew.velocity.y, 0)
	_fall(delta)
	_foe_react -= delta
	_foe_cd -= delta
	if crew.reloading:
		pass
	elif crew.ammo <= 0:
		crew.start_reload()
	elif _foe_react <= 0.0 and _foe_cd <= 0.0:
		_foe_cd = BLASTER_INTERVAL
		crew.ammo -= 1
		_shoot(foe)
	return true


## Nearest alien on foot within DEFEND_RANGE (further while following the host) that the bot can see.
func _find_boarder() -> Boarder:
	var ship := crew.ship
	var up := ship.global_basis.y
	var eye := crew.global_position + up * CrewMember.EYE
	var space := crew.get_world_3d().direct_space_state
	var best: Boarder = null
	var best_d := FOLLOW_DEFEND_RANGE if following else DEFEND_RANGE
	for c in ship.boarder_root.get_children():
		var b := c as Boarder
		if b == null or b.hp <= 0.0:
			continue
		var d := b.position.distance_to(crew.position)
		if d >= best_d:
			continue
		var q := PhysicsRayQueryParameters3D.create(eye, b.center_global(), Game.LAYER_INTERIOR | Game.LAYER_STATION)
		if not space.intersect_ray(q).is_empty():
			continue
		best_d = d
		best = b
	return best


## One blaster shot at a boarder, with aim error that grows with distance.
func _shoot(foe: Boarder) -> void:
	var ship := crew.ship
	var up := ship.global_basis.y
	var eye := crew.global_position + up * CrewMember.EYE
	var target := foe.center_global()
	var spread := BLASTER_SPREAD + BLASTER_SPREAD_PER_M * eye.distance_to(target)
	var jitter := Vector3(randf_range(-spread, spread), randf_range(-spread, spread), randf_range(-spread, spread))
	var dir := ((target - eye).normalized() + jitter).normalized()
	var q := PhysicsRayQueryParameters3D.create(eye, eye + dir * 40.0, Game.LAYER_INTERIOR | Game.LAYER_BOARDER | Game.LAYER_STATION)
	q.collide_with_areas = true
	var hit := crew.get_world_3d().direct_space_state.intersect_ray(q)
	var end := eye + dir * 40.0
	var normal := -dir
	var flesh := false
	if not hit.is_empty():
		end = hit["position"]
		normal = hit["normal"]
		var col: Object = hit["collider"]
		if col.has_meta("boarder"):
			flesh = true
			var b := ship.boarder_root.get_node_or_null(str(col.get_meta("boarder")))
			if b:
				b.take_damage(float(ship.stats["blaster_damage"]), {"source": "bot", "by": crew.peer_id})
	# Effects: locally for the host, relayed to everyone else.
	var muzzle := crew.global_transform * Vector3(0.3, 1.2, -0.8)
	Fx.tracer(muzzle, end, Color(1.0, 0.5, 0.2), 0.035, 0.07)
	if not hit.is_empty():
		Fx.impact(end, normal, Color(0.6, 1.0, 0.3) if flesh else Color(1.0, 0.6, 0.3), 1.2 if flesh else 1.0)
	Sfx.play("blaster", muzzle, -5.0)
	ship.fx_blaster.rpc(ship.to_local(muzzle), ship.to_local(end), ship.global_basis.inverse() * normal, flesh, not hit.is_empty())


# --- Gunnery -----------------------------------------------------------------------------------

## Pick the most dangerous alien this gun can see; egg sacs when no aliens are around.
func _choose_target(t: Turret) -> void:
	var ship := crew.ship
	var mount := ship.to_global(t.transform.origin)
	var candidates: Array = []
	for a in crew.get_tree().get_nodes_in_group("aliens"):
		var alien := a as Alien
		if alien == null or alien.attached >= 0 or alien.hp <= 0.0:
			continue
		var d := mount.distance_to(alien.global_position)
		if d > GUN_RANGE or not t.within_limits(t.aim_at_local(ship.to_local(alien.global_position))):
			continue
		var weight := 0.6 if alien.kind == Alien.Kind.SPITTER else (0.8 if alien.kind == Alien.Kind.INFILTRATOR else 1.0)
		if alien.get_instance_id() == _target_id:
			weight *= 0.7
		candidates.append([d * weight, alien, -1])
	if candidates.is_empty():
		for n in crew.get_tree().get_nodes_in_group("nests"):
			var nest := n as Nest
			for i in nest.sac_hp.size():
				if float(nest.sac_hp[i]) <= 0.0:
					continue
				var p := _sac_point(nest, i)
				var d := mount.distance_to(p)
				if d < SAC_RANGE and t.within_limits(t.aim_at_local(ship.to_local(p))):
					candidates.append([d, nest, i])
	candidates.sort_custom(func(x, y): return x[0] < y[0])
	var space := crew.get_world_3d().direct_space_state
	for c in candidates.slice(0, 4):
		var node: Node3D = c[1]
		var sac: int = c[2]
		var p := _sac_point(node as Nest, sac) if sac >= 0 else node.global_position
		var q := PhysicsRayQueryParameters3D.create(mount, p, Game.LAYER_CAVE)
		if space.intersect_ray(q).is_empty():
			if node.get_instance_id() != _target_id or sac != _target_sac:
				_target_id = node.get_instance_id()
				_target_sac = sac
				_target_t = 0.0
			return
	_target_id = 0
	_target_sac = -1


## Where to aim right now (with lead for moving targets), or an infinite vector when idle.
func _target_point(t: Turret) -> Vector3:
	if _target_id == 0:
		return Vector3(INF, INF, INF)
	var obj := instance_from_id(_target_id)
	if obj == null or not is_instance_valid(obj):
		_target_id = 0
		return Vector3(INF, INF, INF)
	if _target_sac >= 0:
		var nest := obj as Nest
		if nest == null or float(nest.sac_hp[_target_sac]) <= 0.0:
			_target_id = 0
			return Vector3(INF, INF, INF)
		return _sac_point(nest, _target_sac)
	var alien := obj as Alien
	if alien == null or alien.hp <= 0.0 or alien.attached >= 0:
		_target_id = 0
		return Vector3(INF, INF, INF)
	var ship := crew.ship
	var weapon := ship.gun_weapon(gun)
	var speed := float(Mothership.WEAPON_DEFS.get(weapon, Mothership.WEAPON_DEFS["pulse"])["speed"])
	var p := alien.global_position
	if speed > 0.0:
		var muzzle := ship.to_global(t.muzzle_local(_aim))
		var rel_v := alien.net_vel - ship.velocity
		for i in 2:
			p = alien.global_position + rel_v * (muzzle.distance_to(p) / speed)
	return p


static func _sac_point(nest: Nest, i: int) -> Vector3:
	return (nest.sac_pos[i] as Vector3) + (nest.sac_nrm[i] as Vector3).normalized() * 1.0


# --- Walking -----------------------------------------------------------------------------------

## Walk along the interior waypoint graph; returns true once at `goal`.
func _walk_to(goal: Vector3, delta: float) -> bool:
	var flat := Vector3(crew.position.x, 0, crew.position.z)
	if flat.distance_to(Vector3(goal.x, 0, goal.z)) < 0.45:
		crew.velocity = Vector3(0, crew.velocity.y, 0)
		_fall(delta)
		return true
	if _goal.distance_to(goal) > 0.2:
		_goal = goal
		_plan(goal)
	var wp := _path[_path_i] if _path_i < _path.size() else goal
	var to := wp - crew.position
	to.y = 0.0
	if to.length() < 0.4 and _path_i < _path.size():
		_path_i += 1
		wp = _path[_path_i] if _path_i < _path.size() else goal
		to = wp - crew.position
		to.y = 0.0
	var dir := to.normalized() if to.length_squared() > 0.0001 else Vector3.ZERO
	var v := crew.ship.global_basis * dir * CrewMember.WALK
	crew.velocity.x = v.x
	crew.velocity.z = v.z
	_fall(delta)
	if dir != Vector3.ZERO:
		crew.look_yaw = atan2(-dir.x, -dir.z)
		crew.rotation.y = crew.look_yaw
	crew.look_pitch = 0.0
	# Unstick: if barely moving for a while, hop to the next waypoint.
	_stuck_t += delta
	if _stuck_t > 1.5:
		if crew.position.distance_to(_stuck_pos) < 0.3:
			crew.position = Vector3(wp.x, crew.position.y, wp.z)
			crew.reset_physics_interpolation()
		_stuck_t = 0.0
		_stuck_pos = crew.position
	return false


func _fall(delta: float) -> void:
	if not crew.is_on_floor():
		crew.velocity.y -= CrewMember.GRAVITY * delta
	else:
		crew.velocity.y = minf(crew.velocity.y, 0.0)
	crew.move_and_slide()


func _plan(goal: Vector3) -> void:
	var nav := crew.ship.nav
	var from := crew.ship.nav_closest(nav, crew.position)
	var to := crew.ship.nav_closest(nav, goal)
	_path = nav.get_point_path(from, to)
	_path.append(goal)
	_path_i = 0
	# Skip a first waypoint that lies behind us.
	if _path.size() > 1 and crew.position.distance_to(_path[1]) < _path[0].distance_to(_path[1]):
		_path_i = 1


func _panel_spot(i: int) -> Vector3:
	return ShipInteriors.panel_spot(crew.ship.repair_panels()[i])
