extends Node
## Development-only automated runs: `godot --path . -- --autotest=<scenario>`.
## Screenshots go to user://autotest/ and a log line is printed for every step.

var scenario := ""
var _dir := "user://autotest"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_dir))
	print("[autotest] scenario=", scenario)
	# Never touch the player's real save, and start without crew bots unless a scenario adds them.
	Game.save_path = "user://autotest/savegame.json"
	Game.settings_path = "user://autotest/settings.cfg"
	# Every scenario starts from a fresh profile (the Prospector, no unlocks).
	for f: String in [Game.save_path, Game.save_path.get_basename() + "_v1_backup.json", Game.cheat_backup_path()]:
		if FileAccess.file_exists(f):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	Game.load_profile()
	Game.bot_count = 0
	await get_tree().process_frame
	match scenario:
		"menu":
			await _run_menu()
		"homebase":
			await _run_homebase()
		"cave":
			await _run_cave()
		"mission":
			await _run_mission(true)
		"smoke":
			await _run_mission(false)
		"scout":
			await _run_scout()
		"showcase":
			await _run_showcase()
		"combat":
			await _run_combat()
		"soak":
			await _run_soak()
		"fxcheck":
			await _run_fxcheck()
		"shadows":
			await _run_shadows()
		"bots":
			await _run_bots()
		"botfight":
			await _run_botfight()
		"blast":
			await _run_blast()
		"host":
			await _run_host()
		"host_late":
			await _run_host_late()
		"death":
			await _run_death()
		"join":
			await _run_join()
		"station":
			await _run_station()
		"notes":
			await _run_notes()
		"host_station":
			await _run_host_station()
		"meta":
			await _run_meta()
		"ships":
			await _run_ships()
		"hud":
			await _run_hud()
		"sound":
			await _run_sound()
		"models":
			await _run_models()
		"cheats":
			await _run_cheats()
		"join_station":
			await _run_join_station()
		_:
			print("[autotest] unknown scenario")
	print("[autotest] done")
	get_tree().quit()


func shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [_dir, shot_name]
	img.save_png(path)
	print("[autotest] screenshot ", ProjectSettings.globalize_path(path))


func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _run_menu() -> void:
	await wait(0.5)
	await shot("menu")


func _shot_if(enabled: bool, shot_name: String) -> void:
	if enabled:
		await shot(shot_name)


func _status(m: MissionLevel) -> void:
	var s := m.ship
	print("[autotest] t=%.1f depth=%.1f pos=%s hull=%.0f shield=%.0f fuel=%.1f thr=%.2f eng=%.0f wpn=%.0f credits=%d aliens=%d deposits=%d chunks=%d fps=%d" % [
		Time.get_ticks_msec() / 1000.0, s.depth, s.global_position, s.hull, s.shield, s.fuel, s.throttle,
		s.engine_hp, s.weapons_hp, s.credits, get_tree().get_nodes_in_group("aliens").size(),
		get_tree().get_nodes_in_group("deposits").size(), m.cave_root.get_child_count(), Engine.get_frames_per_second()])


## Start a solo mission and exercise every station, screenshotting along the way.
func _run_mission(shots: bool) -> void:
	Game.main.start_solo()
	await wait(0.5)
	Game.main.start_mission()
	var m: MissionLevel = null
	for i in 600:
		await get_tree().process_frame
		m = Game.mission as MissionLevel
		if m and m.local_ready and m.local_player and m.started:
			break
	if m == null or not m.local_ready:
		print("[autotest] FAIL: mission did not get ready")
		return
	print("[autotest] mission ready")
	m.ship.debug_damage = true
	_status(m)
	var p := m.local_player
	await wait(0.5)
	await _shot_if(shots, "m01_interior")
	# Walk forward a bit.
	Input.action_press("move_forward")
	await wait(1.0)
	Input.action_release("move_forward")
	print("[autotest] player local pos after walking: ", p.position)
	await _shot_if(shots, "m02_walked")
	# Pilot: raise throttle and fly with autopilot.
	m.ship.request_station.rpc_id(1, "pilot")
	await wait(0.3)
	print("[autotest] station=", p.station)
	Input.action_press("move_forward")
	await wait(2.5)
	Input.action_release("move_forward")
	await wait(4.0)
	_status(m)
	await _shot_if(shots, "m03_pilot_chase")
	# Full stop so the crew can fight and mine.
	Input.action_press("full_stop")
	await wait(0.3)
	Input.action_release("full_stop")
	await wait(4.0)
	print("[autotest] speed after full stop: %.2f" % m.ship.velocity.length())
	# Port gun against a spitter placed in its field of fire.
	p.exit_station(true)
	await wait(0.2)
	m.ship.request_station.rpc_id(1, "gun_l")
	await wait(0.3)
	var gun: Turret = m.ship.turrets["gun_l"]
	var target_pos := m.ship.to_global(Vector3(-16, 3, -10))
	var spitter := m.spawn_alien(Alien.Kind.SPITTER, target_pos, 1.0, 1.0) as Alien
	var kills_before := m.kills
	for i in 30:
		if not is_instance_valid(spitter):
			break
		p.station_aim = _aim_for(m.ship, gun, spitter.global_position)
		Input.action_press("fire")
		await wait(0.1)
	Input.action_release("fire")
	print("[autotest] gun test: kills %d -> %d" % [kills_before, m.kills])
	await _shot_if(shots, "m04_gun")
	_status(m)
	# Hull critter and roof infiltrator for the scout to deal with later.
	var ahead := m.ship.to_global(Vector3(-25, 4, -30))
	m.spawn_alien(Alien.Kind.CRITTER, ahead + Vector3(4, 2, 0), 1.0, 1.0)
	m.spawn_alien(Alien.Kind.INFILTRATOR, ahead + Vector3(-4, -2, 0), 1.0, 1.0)
	# Mining laser at the nearest deposit.
	p.exit_station(true)
	await wait(0.2)
	m.ship.request_station.rpc_id(1, "mining")
	await wait(0.3)
	var dep := _nearest_deposit(m)
	if dep:
		print("[autotest] nearest deposit %s at %.1f m (hp %.0f)" % [dep.kind, dep.global_position.distance_to(m.ship.global_position), dep.hp])
	Input.action_press("fire")
	for i in 60:
		if is_instance_valid(dep):
			p.station_aim = _aim_for(m.ship, m.ship.turrets["mining"], dep.global_position + dep.normal * 0.8)
		if i == 20:
			await _shot_if(shots, "m05_mining")
			print("[autotest] mining: station=%s on=%s aim=%s ship_aim=%s end=%s dep=%s dist_end_dep=%.1f" % [
				p.station, m.ship.laser_on("mining"), p.station_aim, m.ship.aim_of("mining"), m.ship.laser_end("mining"),
				dep.global_position if is_instance_valid(dep) else "-",
				m.ship.laser_end("mining").distance_to(dep.global_position) if is_instance_valid(dep) else -1.0])
		await wait(0.1)
	Input.action_release("fire")
	await wait(2.0)
	print("[autotest] mining test: deposit %s, ship credits %d, ore %s" % [
		"destroyed" if not is_instance_valid(dep) else "hp %.0f" % dep.hp, m.ship.credits, m.ship.ore])
	_status(m)
	# Scout.
	p.exit_station(true)
	await wait(0.2)
	m.ship.request_station.rpc_id(1, "scout")
	await wait(0.5)
	print("[autotest] scout state=", m.scouts[0].state, " station=", p.station)
	Input.action_press("move_forward")
	await wait(1.5)
	Input.action_release("move_forward")
	await _shot_if(shots, "m06_scout")
	Input.action_press("fire")
	await wait(0.6)
	Input.action_release("fire")
	# Damage the ship to see systems react, then dock and repair.
	m.ship.apply_damage(260.0, m.ship.global_position + Vector3(0, 5, 0), "test")
	m.ship.spawn_boarder(0, 1.0)
	await wait(0.5)
	m.scouts[0].request_dock.rpc_id(1)
	await wait(0.5)
	if p.station != "":
		p.exit_station(true)
	await wait(1.5)
	_status(m)
	await _shot_if(shots, "m07_boarder")
	await wait(4.0)
	print("[autotest] player hp=", p.hp, " boarders=", m.ship.boarders)
	_status(m)
	# Let the ship fly on autopilot for a while.
	await wait(6.0)
	_status(m)
	await _shot_if(shots, "m08_later")
	m.abort_mission()
	await wait(3.5)
	print("[autotest] after abort: level=", Game.main.current_level().name if Game.main.current_level() else "none",
		" research points=", Game.rp())
	await _shot_if(shots, "m09_homebase")


func _tap(action: String) -> void:
	Input.action_press(action)
	await wait(0.12)
	Input.action_release(action)
	await wait(0.15)


## Point a walking crew member's view at a ship-local point.
func _face(p: CrewMember, target: Vector3) -> void:
	var to := target - (p.position + Vector3.UP * CrewMember.EYE)
	p.look_yaw = atan2(-to.x, -to.z)
	p.look_pitch = atan2(to.y, Vector2(to.x, to.z).length())


## Multiplayer waystation test, host side: land, check liftoff waits for the client outside, then
## lift off once the client has carried a crate aboard and installed it.
func _run_host_station() -> void:
	Net.local_name = "HostPilot"
	if Net.host(Net.DEFAULT_PORT) != OK:
		print("[autotest] FAIL: could not host")
		return
	Game.main.change_level("homebase")
	for i in 400:
		await wait(0.1)
		if Net.human_count() >= 2:
			break
	if Net.human_count() < 2:
		print("[autotest] FAIL: no client joined")
		return
	await wait(1.0)
	Game.main.start_mission()
	var m: MissionLevel = null
	for i in 600:
		await get_tree().process_frame
		m = Game.mission as MissionLevel
		if m and m.started and m.local_player:
			break
	var ship := m.ship
	var st := m.cave.station(0)
	await _put_ship(m, float(st["s_entry"]) - 50.0, [float(st["s"])])
	ship.request_station.rpc_id(1, "pilot")
	await wait(0.5)
	await _tap("land")
	for i in 400:
		await wait(0.1)
		if ship.landing == Mothership.Dock.LANDED:
			break
	print("[autotest] host: landed=%s" % (ship.landing == Mothership.Dock.LANDED))
	ship.credits = 2000
	for i in 300:
		await wait(0.1)
		if ship.crew_outside() != "":
			break
	print("[autotest] host: crew outside = '%s'" % ship.crew_outside())
	await _tap("land")
	await wait(0.3)
	print("[autotest] host: liftoff with crew outside -> state %d (2 = still landed)" % ship.landing)
	for i in 400:
		await wait(0.1)
		if not ship.run_mods.is_empty() and ship.crew_outside() == "":
			break
	print("[autotest] host: client installed %s, crates %s" % [ship.run_mods, _crate_list(m)])
	await _tap("land")
	for i in 300:
		await wait(0.1)
		if ship.landing == Mothership.Dock.FLYING:
			break
	print("[autotest] host: flying again=%s, left at station %d, exit gate %.2f" % [ship.landing == Mothership.Dock.FLYING, ship._station_cargo.get(0, []).size(), ship.gate_exit])
	await wait(3.0)
	m.abort_mission()
	await wait(6.0)


## Multiplayer waystation test, client side: walk into the shop, buy an item, carry it aboard and
## install it.
func _run_join_station() -> void:
	Net.local_name = "ClientCarrier"
	await wait(2.0)
	if Net.join("127.0.0.1", Net.DEFAULT_PORT) != OK:
		print("[autotest] FAIL: could not start join")
		return
	var m: MissionLevel = null
	for i in 900:
		await wait(0.1)
		m = Game.mission as MissionLevel
		if m and m.local_ready and m.local_player:
			break
	if m == null or m.local_player == null:
		print("[autotest] FAIL: client never got into a mission")
		return
	var ship := m.ship
	var p := m.local_player
	for i in 900:
		await wait(0.1)
		if ship.landing == Mothership.Dock.LANDED and ship.ramp >= 1.0:
			break
	print("[autotest] client: ship landed=%s ramp=%.2f crates=%d" % [ship.landing == Mothership.Dock.LANDED, ship.ramp, ship.cargo_root.get_child_count()])
	var built := false
	for c in m.cave_root.get_children():
		if c.has_node("Waystation0"):
			built = true
	print("[autotest] client: station built locally: ", built)
	p.position = Vector3(0, 0.05, 10.6)
	p.look_yaw = PI
	p.look_pitch = 0.0
	p.reset_physics_interpolation()
	await wait(0.3)
	Input.action_press("move_forward")
	await wait(4.0)
	Input.action_release("move_forward")
	await wait(0.3)
	print("[autotest] client: walked to ", p.position)
	await shot("net_station_client_room")
	var pick: SupplyCrate = null
	for c in ship.cargo_root.get_children():
		var crate := c as SupplyCrate
		if crate and not RunItems.is_weapon(crate.item) and crate.item != "autocannon":
			pick = crate
			break
	await wait(1.0)
	print("[autotest] client: credits %d, bought %s: %s" % [ship.credits, pick.item, await _buy(p, pick)])
	await wait(0.6)
	print("[autotest] client: picked up %s: %s" % [pick.item, await _pick_up(m, p, pick)])
	await wait(4.0)
	p.position = ShipBuilder.INSTALL_HUB + Vector3(1.7, 0.05, 0)
	p.reset_physics_interpolation()
	await wait(0.4)
	_face(p, ShipBuilder.INSTALL_HUB + Vector3(0.6, 0.9, 0))
	await wait(0.3)
	print("[autotest] client: hub prompt: ", p.prompt)
	await _tap("interact")
	await wait(0.6)
	print("[autotest] client: run mods now %s, carrying=%s" % [ship.run_mods, p.carrying != null])
	await shot("net_station_client_hub")
	for i in 300:
		await wait(0.1)
		if ship.landing == Mothership.Dock.FLYING:
			break
	print("[autotest] client: ship flying again=%s ramp=%.2f" % [ship.landing == Mothership.Dock.FLYING, ship.ramp])
	for i in 200:
		await wait(0.1)
		var lvl: Node = Game.main.current_level()
		if lvl and lvl.name == "Homebase":
			break
	print("[autotest] client back at: ", Game.main.current_level().name if Game.main.current_level() else "none")


## Nearest deposit the mining laser can see and aim at.
func _nearest_deposit(m: MissionLevel) -> Deposit:
	var best: Deposit = null
	var best_d := INF
	var t: Turret = m.ship.turrets["mining"]
	var space := m.get_world_3d().direct_space_state
	for d in get_tree().get_nodes_in_group("deposits"):
		var dep := d as Deposit
		if dep.kind == "fuel":
			continue
		var target := dep.global_position + dep.normal * 0.8
		var raw := _aim_raw(m.ship, t, target)
		if not raw.is_equal_approx(t.clamp_aim(raw)):
			continue
		var muzzle := m.ship.to_global(t.muzzle_local(raw))
		var dist := muzzle.distance_to(target)
		if dist > 44.0 or dist >= best_d:
			continue
		var q := PhysicsRayQueryParameters3D.create(muzzle, target, Game.LAYER_CAVE)
		if not space.intersect_ray(q).is_empty():
			continue
		best_d = dist
		best = dep
	return best


func _aim_raw(ship: Mothership, t: Turret, target: Vector3) -> Vector2:
	var local := ship.to_local(target)
	var dir := (t.transform.basis.inverse() * (local - t.transform.origin)).normalized()
	return Vector2(atan2(-dir.x, -dir.z), asin(clampf(dir.y, -1.0, 1.0)))


## Aim (yaw, pitch) for a turret so its barrel points at a global position.
func _aim_for(ship: Mothership, t: Turret, target: Vector3) -> Vector2:
	var local := ship.to_local(target)
	var dir := (t.transform.basis.inverse() * (local - t.transform.origin)).normalized()
	var yaw := atan2(-dir.x, -dir.z)
	var pitch := asin(clampf(dir.y, -1.0, 1.0))
	return t.clamp_aim(Vector2(yaw, pitch))


func _start_solo_mission() -> MissionLevel:
	Game.main.start_solo()
	await wait(0.5)
	Game.main.start_mission()
	var m: MissionLevel = null
	for i in 600:
		await get_tree().process_frame
		m = Game.mission as MissionLevel
		if m and m.local_ready and m.local_player and m.started:
			return m
	return null


## Steer the scout towards a point; returns the distance left.
func _scout_steer(m: MissionLevel, target: Vector3) -> float:
	var p := m.local_player
	var to := target - m.scouts[0].global_position
	var d := to.normalized()
	p.station_aim = Vector2(atan2(-d.x, -d.z), asin(clampf(d.y, -1.0, 1.0)))
	return to.length()


func _scout_fly_path(m: MissionLevel, points: Array, reach: float, timeout: float) -> bool:
	Input.action_press("move_forward")
	for pt: Vector3 in points:
		var t := 0.0
		while _scout_steer(m, pt) > reach:
			await get_tree().physics_frame
			t += 1.0 / 60.0
			if t > timeout or m.scouts[0].state != Scout.State.FLYING:
				Input.action_release("move_forward")
				print("[autotest] scout stuck at %s heading to %s (state %d)" % [m.scouts[0].global_position, pt, m.scouts[0].state])
				return false
	Input.action_release("move_forward")
	return true


## Fly the scout into the first side tunnel, mine fuel, return and dock.
func _run_scout() -> void:
	var m := await _start_solo_mission()
	if m == null:
		print("[autotest] FAIL: mission not ready")
		return
	var tunnel: Dictionary = {}
	for k in 3:
		var list := m.cave.side_tunnels(k)
		if list.size() > 0:
			tunnel = list[0]
			break
	var pts: PackedVector3Array = tunnel["pts"]
	var s0: float = tunnel["s"]
	print("[autotest] side tunnel at s=%.0f chamber=%s" % [s0, tunnel["chamber"]])
	# Park the mothership next to the tunnel mouth.
	m.ship.global_position = m.cave.center3(s0) + Vector3(0, -1.4, 0)
	m.ship.velocity = Vector3.ZERO
	m.ship.throttle = 0.0
	await wait(3.0)
	m.ship.fuel = 30.0
	var fuel_before := m.ship.fuel
	m.ship.request_station.rpc_id(1, "scout")
	await wait(0.6)
	print("[autotest] scout state=%d station=%s" % [m.scouts[0].state, m.local_player.station])
	var route: Array = [pts[0]]
	for i in range(1, pts.size()):
		route.append(pts[i])
	route.append(tunnel["chamber"])
	var ok := await _scout_fly_path(m, route, 3.0, 25.0)
	print("[autotest] reached chamber: %s, scout hull %.0f" % [ok, m.scouts[0].hp])
	await shot("s01_chamber")
	# Shoot every fuel crystal nearby.
	var fuel_deps: Array = []
	for d in get_tree().get_nodes_in_group("deposits"):
		var dep := d as Deposit
		if dep.kind == "fuel" and dep.global_position.distance_to(m.scouts[0].global_position) < 25.0:
			fuel_deps.append(dep)
	print("[autotest] fuel deposits near the scout: ", fuel_deps.size())
	for dep: Deposit in fuel_deps:
		for i in 120:
			if not is_instance_valid(dep):
				break
			_scout_steer(m, dep.global_position + dep.normal * 0.8)
			Input.action_press("fire")
			await get_tree().physics_frame
		Input.action_release("fire")
	await wait(2.5)
	print("[autotest] scout cargo after mining: %.1f / %.1f" % [m.scouts[0].cargo, m.scouts[0].max_cargo])
	await shot("s02_mined")
	# Fly back out and dock.
	var back: Array = []
	for i in range(pts.size() - 1, -1, -1):
		back.append(pts[i])
	ok = await _scout_fly_path(m, back, 3.0, 25.0)
	var dock := m.ship.to_global(m.scouts[0].dock_point())
	ok = await _scout_fly_path(m, [dock + Vector3(0, -4, 0)], 5.0, 20.0)
	await shot("s03_return")
	m.scouts[0].request_dock.rpc_id(1)
	await wait(0.5)
	print("[autotest] docked=%s station=%s ship fuel %.1f -> %.1f" % [m.scouts[0].state == Scout.State.DOCKED,
		m.local_player.station, fuel_before, m.ship.fuel])


func _bot_report(m: MissionLevel) -> String:
	var parts := PackedStringArray()
	for c in m.ship.crew_root.get_children():
		var cm := c as CrewMember
		if cm and cm.bot:
			parts.append("%s(task=%s sys=%s gun=%s station=%s fight=%s hp=%.0f pos=%s)" % [cm.display_name, cm.brain.task,
				cm.brain.system, cm.brain.gun, cm.station, cm.brain.is_fighting(), cm.hp, cm.position.snapped(Vector3.ONE * 0.1)])
	return ", ".join(parts)


## Crew bots: guns, repairs, giving way to humans, taking damage.
func _run_bots() -> void:
	Game.bot_count = 2
	Game.main.start_solo()
	await wait(1.0)
	print("[autotest] roster: ", Net.roster)
	await shot("bots_homebase")
	Game.main.start_mission()
	var m: MissionLevel = null
	for i in 600:
		await get_tree().process_frame
		m = Game.mission as MissionLevel
		if m and m.local_ready and m.local_player and m.started:
			break
	var ship := m.ship
	var p := m.local_player
	p.max_hp = 99999.0
	p.hp = 99999.0
	print("[autotest] crew nodes: ", ship.crew_root.get_children().map(func(c): return c.name))
	await wait(6.0)
	print("[autotest] after 6s: occupants=%s | %s" % [ship.occupants, _bot_report(m)])
	# Targets on both sides.
	var kills0 := m.kills
	for side: float in [-1.0, 1.0]:
		for k in 3:
			var a := m.spawn_alien(Alien.Kind.SPITTER, ship.to_global(Vector3(side * randf_range(13, 16), randf_range(-2, 4), randf_range(-14, 4))), 1.0, 1.0) as Alien
			a.set_physics_process(false)
	await wait(10.0)
	print("[autotest] bot gunnery: kills %d -> %d" % [kills0, m.kills])
	p.position = Vector3(0, 0.05, -1.0)
	p.look_yaw = PI / 2.0
	p.look_pitch = -0.1
	await wait(0.3)
	await shot("bots_guns")
	# Break both systems: bots should drop the guns and repair.
	ship.damage_system("engine", 100.0)
	ship.damage_system("weapons", 75.0)
	await wait(1.5)
	print("[autotest] after damage: engine=%.0f weapons=%.0f | %s" % [ship.engine_hp, ship.weapons_hp, _bot_report(m)])
	await wait(6.0)
	print("[autotest] repairing: engine=%.0f weapons=%.0f online=%s/%s | %s" % [ship.engine_hp, ship.weapons_hp,
		ship.engine_online, ship.weapons_online, _bot_report(m)])
	p.position = Vector3(0, 0.05, 6.2)
	p.look_yaw = 0.0
	p.look_pitch = -0.2
	await wait(0.3)
	await shot("bots_repair")
	await wait(8.0)
	print("[autotest] repaired: engine=%.0f weapons=%.0f | %s" % [ship.engine_hp, ship.weapons_hp, _bot_report(m)])
	# A human takes over a bot's gun.
	await wait(3.0)
	var bot_gun := ""
	for g: String in ["gun_l", "gun_r"]:
		if Net.is_bot(int(ship.occupants.get(g, 0))):
			bot_gun = g
	if bot_gun != "":
		ship.request_station.rpc_id(1, bot_gun)
		await wait(1.5)
		print("[autotest] human took %s: occupants=%s station=%s | %s" % [bot_gun, ship.occupants, p.station, _bot_report(m)])
		p.exit_station(true)
	else:
		print("[autotest] WARNING: no bot was on a gun to take over")
	# Bots defend themselves: one boarder dropping into the gunnery deck, then a tougher wave.
	p.position = Vector3(0, 0.05, 9.0)
	for wave: Array in [[[0], 1.0], [[0, 1, 2], 2.0]]:
		var hatches: Array = wave[0]
		var kills_before := m.kills
		for h: int in hatches:
			ship.spawn_boarder(h, wave[1])
		var t0 := Time.get_ticks_msec()
		var min_hp := 1000.0
		var knocked := false
		var shot_taken := false
		for i in 60:
			await wait(0.25)
			for c in ship.crew_root.get_children():
				var cm := c as CrewMember
				if cm.bot:
					min_hp = minf(min_hp, cm.hp)
					knocked = knocked or not cm.alive
					shot_taken = shot_taken or cm.brain.is_fighting()
			if i == 3 and hatches.size() == 1:
				p.position = Vector3(0.0, 0.05, 2.6)
				p.look_yaw = 0.0
				p.look_pitch = -0.12
				p.reset_physics_interpolation()
				await get_tree().physics_frame
				await get_tree().physics_frame
				await shot("bots_fight")
				p.position = Vector3(0, 0.05, 9.0)
				p.reset_physics_interpolation()
			if ship.boarders == 0 and i > 4:
				break
		print("[autotest] %d boarder(s) x%.0f hp: %d killed in %.1f s, remaining %d, bots fought=%s, lowest bot hp %.0f, knocked out=%s" % [
			hatches.size(), wave[1], m.kills - kills_before, (Time.get_ticks_msec() - t0) / 1000.0, ship.boarders,
			shot_taken, min_hp, knocked])
		await wait(10.0)
		print("[autotest] after the fight: %s" % _bot_report(m))
	Game.bot_count = 0


## Detailed log of two bots against a wave of tough boarders.
func _run_botfight() -> void:
	Game.bot_count = 2
	var m := await _start_solo_mission()
	Game.bot_count = 0
	var ship := m.ship
	var p := m.local_player
	p.max_hp = 99999.0
	p.hp = 99999.0
	p.position = Vector3(0, 0.05, -8.0)
	await wait(6.0)
	print("[autotest] start: %s" % _bot_report(m))
	for h in 3:
		ship.spawn_boarder(h, 2.0)
	for i in 40:
		await wait(0.5)
		var bl := PackedStringArray()
		for c in ship.boarder_root.get_children():
			var b := c as Boarder
			bl.append("%s hp=%.0f pos=%s atk=%s" % [b.name, b.hp, b.position.snapped(Vector3.ONE * 0.1), b.attacking])
		print("[autotest] t=%.1f boarders[%s] | %s | player hp lost %.0f" % [i * 0.5, "; ".join(bl), _bot_report(m), 99999.0 - p.hp])
		if ship.boarders == 0:
			break


## Emergency blast: distance falloff, hull critters, costs, cooldown and the physical button.
func _run_blast() -> void:
	var m := await _start_solo_mission()
	if m == null:
		print("[autotest] FAIL: mission not ready")
		return
	var ship := m.ship
	ship.debug_damage = true
	var p := m.local_player
	var aliens: Array = []
	for d: float in [10.0, 20.0, 30.0, 38.0, 55.0]:
		var a := m.spawn_alien(Alien.Kind.SPITTER, ship.to_global(ship.shield_center() + Vector3(0, 0, -d)), 1.0, 1.0) as Alien
		a.set_physics_process(false)
		aliens.append([d, a])
	var critter := m.spawn_alien(Alien.Kind.CRITTER, ship.to_global(Vector3(0, -8, 0)), 1.0, 1.0) as Alien
	for i in 300:
		await get_tree().physics_frame
		if critter.attached >= 0:
			break
	print("[autotest] critter attached: ", critter.attached)
	var hull0 := ship.hull
	var fuel0 := ship.fuel
	var shield0 := ship.shield
	ship.request_station.rpc_id(1, "pilot")
	await wait(0.3)
	Input.action_press("emergency")
	await wait(0.1)
	Input.action_release("emergency")
	await wait(0.15)
	await shot("blast_wave")
	for e in aliens:
		print("[autotest]   spitter at %.0f m: %s" % [e[0], "KILLED" if not is_instance_valid(e[1]) else "alive hp %.0f" % (e[1] as Alien).hp])
	print("[autotest]   hull critter: %s" % ("KILLED" if not is_instance_valid(critter) else "alive"))
	print("[autotest] costs: hull %.0f -> %.0f, fuel %.1f -> %.1f, shield %.0f -> %.0f (down=%s), cooldown %.1f" % [
		hull0, ship.hull, fuel0, ship.fuel, shield0, ship.shield, ship.shield_down, ship.blast_cd])
	var hull1 := ship.hull
	Input.action_press("emergency")
	await wait(0.1)
	Input.action_release("emergency")
	await wait(0.2)
	print("[autotest] second press during cooldown: hull %.0f -> %.0f (should be unchanged), cd %.1f" % [hull1, ship.hull, ship.blast_cd])
	p.exit_station(true)
	# Wait out the cooldown, then use the physical button.
	await wait(15.5)
	p.position = ShipBuilder.EMERGENCY_BUTTON + Vector3(-0.9, 0.05, 0.0)
	p.look_yaw = -PI / 2.0
	p.look_pitch = -0.6
	await wait(0.3)
	print("[autotest] button prompt: ", p.prompt)
	await shot("blast_button")
	Input.action_press("interact")
	await wait(0.1)
	Input.action_release("interact")
	await wait(0.3)
	print("[autotest] button press: cooldown now %.1f, hull %.0f" % [ship.blast_cd, ship.hull])


## Views of rock lit by the shadow-casting headlights, for judging shadow artifacts.
func _run_shadows() -> void:
	var m := await _start_solo_mission()
	if m == null:
		print("[autotest] FAIL: mission not ready")
		return
	var ship := m.ship
	ship.global_position = m.cave.center3(120.0) + Vector3(0, -1.4, 0)
	ship.reset_physics_interpolation()
	await wait(2.5)
	ship.request_station.rpc_id(1, "mining")
	await wait(0.4)
	var p := m.local_player
	var views := [Vector2(0.0, 0.0), Vector2(0.55, -0.35), Vector2(-0.6, 0.25), Vector2(0.2, -0.9)]
	for i in views.size():
		p.station_aim = views[i]
		await wait(0.4)
		await shot("sh_mining_%d" % i)
	p.exit_station(true)
	await wait(0.2)
	# Chase view from behind/above the ship.
	ship.request_station.rpc_id(1, "pilot")
	await wait(0.6)
	await shot("sh_chase")
	p.exit_station(true)
	await wait(0.2)
	# Scout headlight inside the nearest side tunnel.
	var tunnel: Dictionary = {}
	for k in range(0, 3):
		for t in m.cave.side_tunnels(k):
			if absf(float(t["s"]) - 120.0) < 90.0:
				tunnel = t
	if not tunnel.is_empty():
		ship.request_station.rpc_id(1, "scout")
		await wait(0.5)
		var pts: PackedVector3Array = tunnel["pts"]
		m.scouts[0].global_position = pts[1]
		m.scouts[0].reset_physics_interpolation()
		var d := (pts[2] - pts[1]).normalized()
		p.station_aim = Vector2(atan2(-d.x, -d.z), asin(d.y))
		await wait(1.0)
		await shot("sh_scout")


## Fire the blaster at a wall after the ship has left the origin; check where the sparks are.
func _run_fxcheck() -> void:
	var m := await _start_solo_mission()
	if m == null:
		print("[autotest] FAIL: mission not ready")
		return
	m.ship.global_position = m.cave.center3(60.0) + Vector3(0, -1.4, 0)
	m.ship.reset_physics_interpolation()
	await wait(2.0)
	var p := m.local_player
	p.position = Vector3(2.5, 0.05, -3.0)
	p.look_yaw = 0.0
	p.look_pitch = 0.0
	p.reset_physics_interpolation()
	await wait(0.3)
	var before := m.fx_root.get_child_count()
	Input.action_press("fire")
	for i in 3:
		await get_tree().physics_frame
	Input.action_release("fire")
	await shot("fx_blaster_impact")
	for i in 3:
		await get_tree().physics_frame
	var expected := m.ship.to_global(Vector3(2.5, CrewMember.EYE, -6.0))
	for c in m.fx_root.get_children():
		if c is CPUParticles3D:
			var parts := c as CPUParticles3D
			var box := parts.capture_aabb()
			print("[autotest] sparks node at %s, particle aabb center %s (size %s); expected near %s" % [
				parts.global_position, box.get_center(), box.size, expected])
	print("[autotest] fx nodes added: ", m.fx_root.get_child_count() - before)
	await shot("fx_blaster")
func _run_soak() -> void:
	var m := await _start_solo_mission()
	if m == null:
		print("[autotest] FAIL: mission not ready")
		return
	m.ship.max_hull = 100000.0
	m.ship.hull = 100000.0
	m.local_player.max_hp = 100000.0
	m.local_player.hp = 100000.0
	m.ship.request_station.rpc_id(1, "pilot")
	await wait(0.3)
	Input.action_press("move_forward")
	await wait(2.5)
	Input.action_release("move_forward")
	Engine.time_scale = 4.0
	var last_depth := 0.0
	var ship := m.ship
	for i in 18:
		# Ten seconds of autopilot, landing at every waystation on the way and lifting off again.
		for step in 10:
			await wait(1.0)
			if ship.landing == Mothership.Dock.FLYING and not ship.nearest_station(Mothership.LAND_RANGE).is_empty() \
					and ship.in_hall(ship.next_station()):
				# Nobody fights the boarders in this test; docking needs a working engine.
				for b in ship.boarder_root.get_children():
					b.queue_free()
				print("[autotest]   landing at %s (depth %.0f, speed %.1f, engine %.0f online=%s, player at '%s')" % [ship.next_station()["name"],
					ship.depth, ship.velocity.length(), ship.engine_hp, ship.engine_online, m.local_player.station])
				ship.engine_hp = 100.0
				ship.engine_online = true
				# Boarders may have knocked the player out of the pilot seat.
				if m.local_player.station != "pilot" and m.local_player.alive:
					ship.request_station.rpc_id(1, "pilot")
					await wait(0.3)
				await _tap("land")
			elif ship.landing == Mothership.Dock.LANDED and m.local_player.station != "pilot" and m.local_player.alive:
				ship.request_station.rpc_id(1, "pilot")
				await wait(0.3)
			elif ship.landing == Mothership.Dock.LANDED and ship.gate_entry <= 0.0:
				print("[autotest]   docked at station %d (entrance %.2f) - lifting off" % [ship.gate_k, ship.gate_entry])
				await _tap("land")
			elif ship.landing == Mothership.Dock.FLYING and ship.throttle < 0.5:
				if m.local_player.station != "pilot" and m.local_player.alive:
					ship.request_station.rpc_id(1, "pilot")
					await wait(0.3)
				Input.action_press("move_forward")
				await wait(0.6)
				Input.action_release("move_forward")
		ship.fuel = ship.max_fuel
		ship.engine_hp = 100.0
		var nests := get_tree().get_nodes_in_group("nests").size()
		print("[autotest] soak depth=%.0f (+%.0f) hull=%.0f aliens=%d nests=%d deposits=%d pickups=%d chunks=%d boarders=%d kills=%d stations=%d gate %d/%.2f/%.2f fps=%d" % [
			ship.depth, ship.depth - last_depth, ship.hull, get_tree().get_nodes_in_group("aliens").size(), nests,
			get_tree().get_nodes_in_group("deposits").size(), m.pickup_root.get_child_count(), m.cave_root.get_child_count(),
			ship.boarders, m.kills, ship.stations_docked, ship.gate_k, ship.gate_entry, ship.gate_exit, Engine.get_frames_per_second()])
		if ship.depth - last_depth < 5.0 and i > 1 and ship.landing == Mothership.Dock.FLYING:
			print("[autotest] WARNING: ship seems stuck at ", ship.global_position)
		last_depth = ship.depth
	Engine.time_scale = 1.0
	print("[autotest] soak research so far: ", m.dive_rp())
	await shot("soak_end")


## Verify every way of dealing and repairing damage.
func _run_combat() -> void:
	var m := await _start_solo_mission()
	if m == null:
		print("[autotest] FAIL: mission not ready")
		return
	var ship := m.ship
	var p := m.local_player
	p.max_hp = 99999.0
	p.hp = 99999.0
	# 1) Every turret weapon kills a spitter in its arc.
	for weapon: String in ["pulse", "flak", "plasma", "rail"]:
		ship.gun_weapons["gun_l"] = weapon
		ship.request_station.rpc_id(1, "gun_l")
		await wait(0.3)
		var gun: Turret = ship.turrets["gun_l"]
		var a := m.spawn_alien(Alien.Kind.SPITTER, ship.to_global(Vector3(-15, 2, -8)), 1.0, 1.0) as Alien
		a.set_physics_process(false)
		var t0 := Time.get_ticks_msec()
		for i in 120:
			if not is_instance_valid(a):
				break
			p.station_aim = _aim_for(ship, gun, a.global_position)
			Input.action_press("fire")
			await get_tree().physics_frame
		Input.action_release("fire")
		print("[autotest] %s: spitter %s after %d ms" % [weapon, "KILLED" if not is_instance_valid(a) else "alive (hp %.0f)" % a.hp, Time.get_ticks_msec() - t0])
		if is_instance_valid(a):
			a.queue_free()
		p.exit_station(true)
		await wait(0.2)
	# 2) Blaster vs boarder.
	ship.spawn_boarder(0, 1.0)
	await wait(1.5)
	var b := ship.boarder_root.get_child(0) as Boarder
	p.position = b.position + Vector3(0, 0, 4.0)
	await get_tree().physics_frame
	for i in 300:
		if not is_instance_valid(b):
			break
		var to := b.position + Vector3(0, 0.8, 0) - (p.position + Vector3(0, CrewMember.EYE, 0))
		p.look_yaw = atan2(-to.x, -to.z)
		p.look_pitch = asin(clampf(to.normalized().y, -1.0, 1.0))
		Input.action_press("fire")
		await get_tree().physics_frame
	Input.action_release("fire")
	print("[autotest] blaster vs boarder: %s" % ("KILLED" if not is_instance_valid(b) else "alive"))
	# 3) Scout vs a critter latched onto the hull.
	var critter := m.spawn_alien(Alien.Kind.CRITTER, ship.to_global(Vector3(0, -8, 0)), 1.0, 1.0) as Alien
	for i in 300:
		await get_tree().physics_frame
		if critter.attached >= 0:
			break
	print("[autotest] critter attached to hull point: ", critter.attached)
	ship.request_station.rpc_id(1, "scout")
	await wait(0.5)
	var scout := m.scouts[0]
	for i in 400:
		if not is_instance_valid(critter):
			break
		var aim_from := scout.global_position
		var to := critter.global_position - aim_from
		if to.length() > 12.0:
			_scout_steer(m, critter.global_position)
			Input.action_press("move_forward")
		else:
			Input.action_release("move_forward")
			_scout_steer(m, critter.global_position)
			Input.action_press("fire")
		await get_tree().physics_frame
	Input.action_release("fire")
	Input.action_release("move_forward")
	print("[autotest] scout vs latched critter: %s" % ("KILLED" if not is_instance_valid(critter) else "alive (hp %.0f)" % critter.hp))
	scout.request_dock.rpc_id(1)
	await wait(0.3)
	if p.station != "":
		p.exit_station(true)
	# 4) Nest destruction.
	var chunk := m.cave_root.get_node("Chunk1") as CaveChunk
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	m._place_nest(chunk.result["verts"], chunk.result["norms"], rng, 60.0)
	await get_tree().process_frame
	var nests := get_tree().get_nodes_in_group("nests")
	var nest := nests[nests.size() - 1] as Nest
	var before := m.nests_destroyed
	for i in nest.sac_hp.size():
		nest.take_damage(99999.0, {"sac": i, "source": "turret"})
	await wait(0.5)
	print("[autotest] nest destroyed: %s (nests_destroyed %d -> %d), pickups dropped: %d" % [
		nest.alive_sacs() == 0, before, m.nests_destroyed, m.pickup_root.get_child_count()])
	# 5) Toolkit repairs.
	ship.damage_system("engine", 80.0)
	var eng_before := ship.engine_hp
	p.tool = 1
	var panel: Dictionary = ShipBuilder.REPAIR_PANELS[0]
	var panel_pos: Vector3 = panel["pos"]
	p.position = Vector3(panel_pos.x, 0.05, panel_pos.z - 1.4)
	p.look_yaw = PI
	p.look_pitch = -0.2
	await get_tree().physics_frame
	Input.action_press("fire")
	await wait(3.0)
	Input.action_release("fire")
	print("[autotest] repair: engine %.0f -> %.0f (prompt was '%s')" % [eng_before, ship.engine_hp, p.prompt])
	# 6) Load: many aliens at once.
	for i in 30:
		m.spawn_alien(i % 3, ship.to_global(Vector3(randf_range(-30, 30), randf_range(-8, 8), randf_range(-60, -20))), 1.0, 1.0)
	await wait(3.0)
	var t1 := Time.get_ticks_usec()
	var frames := 0
	while Time.get_ticks_usec() - t1 < 3000000:
		await get_tree().process_frame
		frames += 1
	print("[autotest] load test: %d aliens, %.1f fps" % [get_tree().get_nodes_in_group("aliens").size(), frames / 3.0])


## Close-up shots of aliens, a nest, deposits and a boarder.
func _run_showcase() -> void:
	var m := await _start_solo_mission()
	if m == null:
		print("[autotest] FAIL: mission not ready")
		return
	m.local_player.hp = 99999.0
	var cam := Camera3D.new()
	cam.fov = 60.0
	m.add_child(cam)
	cam.current = true
	var ship := m.ship
	# Aliens floating in front of the ship's nose (frozen so they hold still).
	var kinds := [Alien.Kind.SPITTER, Alien.Kind.CRITTER, Alien.Kind.INFILTRATOR]
	for i in kinds.size():
		var pos := ship.to_global(Vector3(0, 3, -32))
		var a := m.spawn_alien(kinds[i], pos, 1.0, 1.0) as Alien
		a.set_physics_process(false)
		a.global_basis = Basis(Vector3.UP, 2.4)
		var dist: float = [7.0, 3.5, 6.5][i]
		cam.global_position = pos + Vector3(dist * 0.7, dist * 0.35, dist * 0.6)
		cam.look_at(pos)
		await wait(0.4)
		await shot("c%d_%s" % [i, ["spitter", "critter", "infiltrator"][i]])
		a.queue_free()
	# Deposits of every kind on the nearest chunk's wall.
	var chunk := m.cave_root.get_node("Chunk1") as CaveChunk
	var verts: PackedVector3Array = chunk.result["verts"]
	var norms: PackedVector3Array = chunk.result["norms"]
	var idx := 0
	for k: String in ["ferrite", "cobalt", "aurium", "voidstone", "fuel"]:
		var vi := (idx * 997) % verts.size()
		idx += 1
		m._spawn_deposit(k, verts[vi], norms[vi], 1.2, idx)
		await get_tree().process_frame
		var p := verts[vi]
		cam.global_position = p + norms[vi] * 6.0 + Vector3(0, 1.5, 0)
		cam.look_at(p + norms[vi] * 1.0)
		var l := OmniLight3D.new()
		l.omni_range = 15.0
		l.light_energy = 1.5
		cam.add_child(l)
		await wait(0.3)
		await shot("d_%s" % k)
		l.queue_free()
	# A nest on the wall.
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var before := get_tree().get_nodes_in_group("nests").size()
	m._place_nest(verts, norms, rng, -verts[0].z)
	await get_tree().process_frame
	var nests := get_tree().get_nodes_in_group("nests")
	if nests.size() > before:
		var nest := nests[nests.size() - 1] as Nest
		cam.global_position = nest.global_position + nest.normal * 22.0 + Vector3(0, 4, 0)
		cam.look_at(nest.global_position)
		var l2 := OmniLight3D.new()
		l2.omni_range = 40.0
		l2.light_energy = 1.0
		cam.add_child(l2)
		await wait(0.6)
		await shot("n_nest")
		nest.take_damage(9999.0, {"sac": 0, "source": "turret"})
		await wait(0.5)
		await shot("n_nest_damaged")
		print("[autotest] nest sacs alive: ", nest.alive_sacs(), " agitated: ", nest.agitated)
	# Boarder inside the ship.
	ship.spawn_boarder(0, 1.0)
	await wait(1.5)
	var b := ship.boarder_root.get_child(0) as Boarder
	b.set_physics_process(false)
	cam.queue_free()
	await get_tree().process_frame
	m.local_player.camera.current = true
	var p := m.local_player
	p.position = b.position + Vector3(0, 0, 3.0)
	p.look_yaw = 0.0
	p.look_pitch = -0.15
	await wait(0.5)
	await shot("b_boarder")


## Host starts a mission alone; a client joins mid-mission (run "join" a few seconds later).
func _run_host_late() -> void:
	Net.local_name = "HostPilot"
	if Net.host(Net.DEFAULT_PORT) != OK:
		print("[autotest] FAIL: could not host")
		return
	Game.main.change_level("homebase")
	await wait(0.5)
	Game.main.start_mission()
	var m: MissionLevel = null
	for i in 600:
		await get_tree().process_frame
		m = Game.mission as MissionLevel
		if m and m.started:
			break
	m.ship.request_station.rpc_id(1, "pilot")
	await wait(0.3)
	Input.action_press("move_forward")
	await wait(1.0)
	Input.action_release("move_forward")
	print("[autotest] host mission running, waiting for a late joiner")
	for i in 400:
		await wait(0.1)
		if m.ship.crew_root.get_child_count() >= 2:
			break
	print("[autotest] crew after join: ", m.ship.crew_root.get_children().map(func(c): return c.name))
	await wait(10.0)
	print("[autotest] host sees occupants: ", m.ship.occupants)
	m.abort_mission()
	await wait(8.0)


## Multiplayer test, host side: wait for a client, run a mission, then abort.
func _run_host() -> void:
	Net.local_name = "HostPilot"
	# A full crew of bots: the joining client must bump one of them.
	Game.bot_count = 3
	if Net.host(Net.DEFAULT_PORT) != OK:
		print("[autotest] FAIL: could not host")
		return
	Game.main.change_level("homebase")
	print("[autotest] hosting with bots: ", Net.roster)
	for i in 400:
		await wait(0.1)
		if Net.human_count() >= 2:
			break
	Game.bot_count = 0
	print("[autotest] roster: ", Net.roster)
	if Net.human_count() < 2:
		print("[autotest] FAIL: no client joined")
		return
	await wait(1.5)
	await shot("net_host_homebase")
	Game.main.start_mission()
	var m: MissionLevel = null
	for i in 600:
		await get_tree().process_frame
		m = Game.mission as MissionLevel
		if m and m.started and m.local_player:
			break
	print("[autotest] host mission ready; crew nodes: ", m.ship.crew_root.get_children().map(func(c): return c.name))
	var p := m.local_player
	m.ship.request_station.rpc_id(1, "pilot")
	await wait(0.3)
	Input.action_press("move_forward")
	await wait(1.5)
	Input.action_release("move_forward")
	for i in 6:
		await wait(2.0)
		_status(m)
		print("[autotest] host sees occupants: ", m.ship.occupants)
	await shot("net_host_mission")
	# Throw an infiltrator at the ship so the client sees replicated aliens.
	m.spawn_alien(Alien.Kind.SPITTER, m.ship.to_global(Vector3(30, 3, -15)), 1.0, 1.0)
	await wait(6.0)
	_status(m)
	print("[autotest] host player station=", p.station)
	m.abort_mission()
	await wait(6.0)
	print("[autotest] host back at: ", Game.main.current_level().name if Game.main.current_level() else "none")
	await wait(2.0)


## Multiplayer test, client side: join, man a gun, walk around, verify replication.
func _run_join() -> void:
	Net.local_name = "ClientGunner"
	await wait(2.0)
	if Net.join("127.0.0.1", Net.DEFAULT_PORT) != OK:
		print("[autotest] FAIL: could not start join")
		return
	var m: MissionLevel = null
	for i in 900:
		await wait(0.1)
		m = Game.mission as MissionLevel
		if m and m.local_ready and m.local_player:
			break
	if m == null or m.local_player == null:
		print("[autotest] FAIL: client never got into a mission. level=", Game.main.current_level())
		return
	print("[autotest] client in mission; my id=", multiplayer.get_unique_id(), " roster=", Net.roster)
	print("[autotest] client sees ship at ", m.ship.global_position, " scouts=", m.scouts.size(), " chunks=", m.cave_root.get_child_count())
	var p := m.local_player
	await wait(1.0)
	Input.action_press("move_forward")
	await wait(1.0)
	Input.action_release("move_forward")
	print("[autotest] client walked to ", p.position)
	m.ship.request_station.rpc_id(1, "gun_r")
	await wait(0.6)
	print("[autotest] client station=", p.station, " occupants=", m.ship.occupants)
	p.station_aim = Vector2(0.3, 0.1)
	Input.action_press("fire")
	await wait(1.5)
	Input.action_release("fire")
	await shot("net_client_gun")
	for i in 4:
		await wait(2.0)
		print("[autotest] client view: depth=%.1f shipvel=%s aliens=%d deposits=%d hull=%.0f" % [m.ship.depth, m.ship.net_vel,
			get_tree().get_nodes_in_group("aliens").size(), get_tree().get_nodes_in_group("deposits").size(), m.ship.hull])
	var crew_view := PackedStringArray()
	for c in m.ship.crew_root.get_children():
		var cm := c as CrewMember
		crew_view.append("%s%s@%s" % [cm.display_name, "(bot)" if cm.bot else "", cm.station if cm.station != "" else "walking"])
	print("[autotest] client sees crew: ", ", ".join(crew_view), " | occupants: ", m.ship.occupants)
	p.exit_station(true)
	await wait(0.5)
	await shot("net_client_walk")
	for i in 200:
		await wait(0.1)
		var lvl: Node = Game.main.current_level()
		if lvl and lvl.name == "Homebase":
			break
	await wait(1.0)
	print("[autotest] client back at: ", Game.main.current_level().name if Game.main.current_level() else "none", " research points(view)=", Game.rp())
	await shot("net_client_homebase")


func _run_homebase() -> void:
	Game.main.start_solo()
	await wait(2.0)
	await shot("homebase")


## Build cave chunks without a mission and photograph the tunnel and a side tunnel.
func _run_cave() -> void:
	Game.main.menu.hide()
	var world := Node3D.new()
	add_child(world)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.01, 0.012, 0.02)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.35, 0.4, 0.5)
	env.ambient_light_energy = 0.25
	env.fog_enabled = true
	env.fog_light_color = Color(0.04, 0.05, 0.08)
	env.fog_density = 0.01
	env.glow_enabled = true
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var seed_value := 4242
	var chunks: Array[CaveChunk] = []
	var t0 := Time.get_ticks_msec()
	for n in range(-1, 9):
		var ch := CaveChunk.new()
		ch.setup(seed_value, n)
		world.add_child(ch)
		chunks.append(ch)
	while true:
		var done := true
		for ch in chunks:
			if not ch.is_built:
				done = false
		if done:
			break
		await get_tree().process_frame
	var tris := 0
	for ch in chunks:
		tris += (ch.result["indices"] as PackedInt32Array).size() / 3
	print("[autotest] %d chunks built in %d ms, %d triangles" % [chunks.size(), Time.get_ticks_msec() - t0, tris])
	var gen := CaveGen.new(seed_value)
	var cam := Camera3D.new()
	cam.fov = 75.0
	cam.far = 400.0
	world.add_child(cam)
	cam.current = true
	var light := SpotLight3D.new()
	light.spot_range = 130.0
	light.spot_angle = 40.0
	light.spot_attenuation = 0.5
	light.light_energy = 10.0
	light.shadow_enabled = true
	cam.add_child(light)
	var fill := OmniLight3D.new()
	fill.omni_range = 40.0
	fill.light_energy = 0.8
	cam.add_child(fill)
	for s: float in [-5.0, 60.0, 150.0, 260.0, 380.0]:
		cam.global_position = gen.center3(s) + Vector3(0, 4, 0)
		cam.look_at(gen.center3(s + 30.0) + Vector3(0, 2, 0))
		await wait(0.25)
		await shot("cave_%d" % int(s))
	var tunnels: Array = gen.side_tunnels(0) + gen.side_tunnels(1)
	var idx := 0
	for t in tunnels:
		var pts: PackedVector3Array = t["pts"]
		print("[autotest] side tunnel at s=%.0f, %d points, chamber %s" % [t["s"], pts.size(), t["chamber"]])
		var back := pts[0] - (pts[1] - pts[0]).normalized() * 6.0
		cam.global_position = back
		cam.look_at(pts[1])
		await wait(0.25)
		await shot("side_%d_mouth" % idx)
		cam.global_position = pts[1]
		cam.look_at(pts[2])
		await wait(0.25)
		await shot("side_%d_inside" % idx)
		idx += 1
	# Overview from outside the rock (backface view) to judge the overall shape.
	cam.global_position = Vector3(160, 60, -150)
	cam.look_at(Vector3(0, 0, -200))
	light.light_energy = 0.0
	env.ambient_light_energy = 1.5
	await wait(0.25)
	await shot("cave_outside")


## Waystation hall `k` (its Waystation node) once its chunk is built, or null.
func _waystation(m: MissionLevel, k: int) -> Waystation:
	for c in m.cave_root.get_children():
		var w := c.get_node_or_null("Waystation%d" % k) as Waystation
		if w:
			return w
	return null


## Place the ship on the tunnel's centre line at depth s, heading deeper, and wait for the cave.
func _put_ship(m: MissionLevel, s: float, extra: Array = []) -> void:
	var ship := m.ship
	ship.global_position = m.cave.center3(s) + Vector3(0, -1.4, 0)
	var t := m.cave.tangent(s)
	ship.rotation.y = atan2(-t.x, -t.z)
	ship.velocity = Vector3.ZERO
	ship.reset_physics_interpolation()
	for i in 900:
		await get_tree().process_frame
		var ready := m._chunks_ready_near(s)
		for e: float in extra:
			ready = ready and m._chunks_ready_near(e)
		if ready:
			break


## Stand in front of a shop crate (between it and the middle of the shop) and look at it.
func _stand_at(p: CrewMember, crate: SupplyCrate) -> void:
	var floor_y := StationBuilder.DECK_Y - StationBuilder.LAND_HEIGHT + 0.05
	var flat := Vector3(crate.net_pos.x, 0, crate.net_pos.z)
	var away := flat.direction_to(Vector3(0, 0, 26.0))
	if away.length_squared() < 0.01:
		away = Vector3.FORWARD
	p.position = Vector3(flat.x, floor_y, flat.z) + away * 1.25
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()
	await wait(0.35)
	_face(p, crate.net_pos)
	await wait(0.25)


## Buy a shop crate (standing at it): returns true once it is bought.
func _buy(p: CrewMember, crate: SupplyCrate) -> bool:
	await _stand_at(p, crate)
	print("[autotest]   prompt at shop item: ", p.prompt)
	await _tap("interact")
	await wait(0.25)
	return crate.price == 0


## Stand next to a crate and pick it up. Returns true once carrying it.
func _pick_up(m: MissionLevel, p: CrewMember, crate: SupplyCrate) -> bool:
	await _stand_at(p, crate)
	print("[autotest]   prompt at crate: ", p.prompt)
	await _tap("interact")
	await wait(0.2)
	return p.carrying == crate


## Carry the held crate to the install hub and fit it.
func _install_at_hub(p: CrewMember) -> String:
	p.position = ShipBuilder.INSTALL_HUB + Vector3(1.7, 0.05, 0)
	p.reset_physics_interpolation()
	await wait(0.25)
	_face(p, ShipBuilder.INSTALL_HUB + Vector3(0.6, 0.9, 0))
	await wait(0.3)
	var prompt := p.prompt
	await _tap("interact")
	await wait(0.3)
	return prompt


func _crate_list(m: MissionLevel) -> String:
	var out := PackedStringArray()
	for c in m.ship.cargo_root.get_children():
		var crate := c as SupplyCrate
		if crate:
			out.append("%s:%s%s@%s%s" % [crate.name, crate.item, " (%d CR)" % crate.price if crate.price > 0 else "",
				crate.net_pos.snapped(Vector3.ONE * 0.1), " (carried by %d)" % crate.carrier if crate.carrier != 0 else ""])
	return ", ".join(out)


## Waystations: fly into the hall (the flight computer stops short of the sealed exit), land and
## watch the entrance seal, walk into the shop, buy supplies with the dive's credits, carry them
## aboard and fit them, station defences, lift off through the exit (which seals behind the ship),
## the flight computer refusing to back into the sealed bulkhead, and a bought auto turret.
func _run_station() -> void:
	var m := await _start_solo_mission()
	if m == null:
		print("[autotest] FAIL: mission not ready")
		return
	var ship := m.ship
	var p := m.local_player
	p.max_hp = 99999.0
	p.hp = 99999.0
	var st := m.cave.station(0)
	var xf: Transform3D = st["xform"]
	var inv: Transform3D = st["inv"]
	print("[autotest] station 0: s=%.0f hall %.0f..%.0f origin=%s" % [st["s"], st["s_entry"], st["s_exit"], xf.origin])
	# Straightened tunnel through the station: the centre line runs through both gates.
	for z: float in [StationBuilder.ENTRY_FACE + 40.0, StationBuilder.ENTRY_FACE, 0.0, StationBuilder.EXIT_FACE, StationBuilder.EXIT_FACE - 40.0]:
		var wp := xf * Vector3(0, StationBuilder.LINE_Y, z)
		var c := m.cave.center3(-wp.z)
		print("[autotest]   centre line at station z=%.0f: off gate axis by %.2f m, radius %.1f, noise %.2f" % [z,
			Vector2(c.x - wp.x, c.y - wp.y).length(), m.cave.radius(-wp.z), m.cave.noise_scale(-wp.z)])
	await _put_ship(m, float(st["s_entry"]) - 80.0, [float(st["s"])])
	var ws := _waystation(m, 0)
	print("[autotest] station built: %s, doors entry %.2f exit %.2f" % [ws != null, ws.is_open("entry") if ws else -1.0, ws.is_open("exit") if ws else -1.0])
	ship.request_station.rpc_id(1, "pilot")
	await wait(0.6)
	await shot("st01_approach")
	# Fly in without landing: the ship must stop before the sealed exit bulkhead.
	Input.action_press("move_forward")
	await wait(2.5)
	Input.action_release("move_forward")
	var t0 := Time.get_ticks_msec()
	var shot_hall := false
	while Time.get_ticks_msec() - t0 < 40000:
		await wait(0.5)
		var l := inv * ship.global_position
		if not shot_hall and l.z < 10.0:
			shot_hall = true
			await shot("st02_in_hall")
		if ship.in_hall(st) and ship.velocity.length() < 0.3 and l.z < 10.0:
			break
	var lz := (inv * ship.global_position).z
	print("[autotest] stopped in the hall: in_hall=%s z=%.1f (nose at %.1f, exit door at %.1f) speed %.2f hull %.0f" % [
		ship.in_hall(st), lz, lz - ship._nose, StationBuilder.EXIT_INNER, ship.velocity.length(), ship.hull])
	print("[autotest] pilot info: ", m.hud._station_info.text.replace("\n", " | "))
	await _tap("land")
	print("[autotest] landing state after L: ", ship.landing)
	t0 = Time.get_ticks_msec()
	while ship.landing != Mothership.Dock.LANDED and Time.get_ticks_msec() - t0 < 45000:
		await wait(0.5)
	print("[autotest] landed: %s after %.1f s, gate_k %d, landing error %.2f m" % [ship.landing == Mothership.Dock.LANDED,
		(Time.get_ticks_msec() - t0) / 1000.0, ship.gate_k, ship.global_position.distance_to(xf * Vector3(0, StationBuilder.LAND_HEIGHT, 0))])
	await wait(1.0)
	print("[autotest] entrance closing: gate_entry %.2f, door %.2f" % [ship.gate_entry, ws.is_open("entry")])
	await wait(5.0)
	print("[autotest] entrance sealed: gate_entry %.2f, door %.2f; exit door %.2f; ramp %.2f" % [ship.gate_entry, ws.is_open("entry"), ws.is_open("exit"), ship.ramp])
	print("[autotest] shop stock: ", _crate_list(m))
	await shot("st03_landed_chase")
	# Views of the hall.
	var cam := Camera3D.new()
	cam.far = 500.0
	m.add_child(cam)
	for v: Array in [["st04_hall_entry", Vector3(16.0, 18.0, -16.0), Vector3(0, 8.0, 20.0)],
			["st05_hall_exit", Vector3(-14.0, 16.0, 14.0), Vector3(0, 12.0, -26.0)],
			["st06_entry_outside", Vector3(9.0, 17.0, StationBuilder.ENTRY_FACE + 45.0), Vector3(0, 15.0, StationBuilder.ENTRY_FACE)],
			["st07_shop_facade", Vector3(-11.0, 7.0, 12.5), Vector3(0, 5.0, 20.0)]]:
		cam.global_position = xf * (v[1] as Vector3)
		cam.look_at(xf * (v[2] as Vector3))
		cam.current = true
		await wait(0.3)
		await shot(v[0])
	cam.queue_free()
	p.camera.current = true
	# Station defences: an alien that comes close gets shot down.
	var hull0 := ship.hull
	var intruder := m.spawn_alien(Alien.Kind.SPITTER, ship.to_global(Vector3(0, 8, -30)), 1.0, 1.0) as Alien
	await wait(0.8)
	print("[autotest] station defence: intruder %s, ship hull %.0f -> %.0f" % ["shot down" if not is_instance_valid(intruder) else "ALIVE", hull0, ship.hull])
	ship.apply_damage(50.0, ship.global_position, "test")
	print("[autotest] damage while docked: hull %.0f (unchanged = safe haven)" % ship.hull)
	# Walk down the ramp onto the pier and into the shop.
	p.exit_station(true)
	await wait(0.3)
	p.position = Vector3(0, 0.05, 10.6)
	p.look_yaw = PI
	p.look_pitch = -0.1
	p.reset_physics_interpolation()
	await wait(0.3)
	Input.action_press("move_forward")
	await wait(1.6)
	await shot("st08_pier")
	await wait(2.6)
	Input.action_release("move_forward")
	await wait(0.4)
	print("[autotest] walked to: %s (in the shop: %s), crew outside: '%s'" % [p.position, p.position.z > StationBuilder.FACADE_Z, ship.crew_outside()])
	p.look_pitch = -0.2
	await wait(0.2)
	await shot("st09_shop")
	# Buying: not enough credits first, then with enough.
	ship.credits = 40
	ship.hull = ship.max_hull - 250.0
	var kit: SupplyCrate = null
	var gun: SupplyCrate = null
	var turret: SupplyCrate = null
	var others: Array[SupplyCrate] = []
	for c in ship.cargo_root.get_children():
		var crate := c as SupplyCrate
		if crate.item == "hull_kit":
			kit = crate
		elif RunItems.is_weapon(crate.item):
			gun = crate
		elif crate.item == "autocannon":
			turret = crate
		else:
			others.append(crate)
	print("[autotest] stock: kit=%s gun=%s turret=%s others=%s" % [kit != null, gun.item if gun else "-", turret != null, others.map(func(c): return c.item)])
	var cheap := await _buy(p, kit)
	print("[autotest] buy with 40 CR: bought=%s credits %d, prompt '%s'" % [cheap, ship.credits, p.prompt])
	ship.credits = 3000
	await wait(0.3)
	await _stand_at(p, kit)
	await shot("st10_shop_item")
	var credits0 := ship.credits
	print("[autotest] bought hull kit: %s (credits %d -> %d)" % [await _buy(p, kit), credits0, ship.credits])
	print("[autotest] picked up hull kit: ", await _pick_up(m, p, kit))
	await shot("st11_carrying")
	# Walk back aboard with it and fit it.
	p.position = Vector3(0, -0.95, 22.0)
	p.look_yaw = 0.0
	p.look_pitch = 0.0
	p.reset_physics_interpolation()
	Input.action_press("move_forward")
	await wait(4.5)
	Input.action_release("move_forward")
	await wait(0.3)
	print("[autotest] walked back aboard with the crate: pos %s aboard=%s carrying=%s" % [p.position, Mothership.is_aboard(p.position), p.carrying != null])
	var hull1 := ship.hull
	print("[autotest] hub prompt: ", await _install_at_hub(p))
	print("[autotest] hull kit installed: hull %.0f -> %.0f, mods %s, kit freed %s" % [hull1, ship.hull, ship.run_mods, not is_instance_valid(kit)])
	await shot("st12_hub")
	# The gun: mount it at the first gun console.
	if gun:
		var w := RunItems.weapon_of(gun.item)
		print("[autotest] bought gun %s: %s, picked up: %s" % [w, await _buy(p, gun), await _pick_up(m, p, gun)])
		var g: String = ship.gun_stations()[0]
		p.position = ship.console(g)["seat"] + Vector3(0.7, 0.05, 0)
		p.reset_physics_interpolation()
		await wait(0.25)
		_face(p, ship.console(g)["console"] + Vector3(0, 0.9, 0))
		await wait(0.3)
		print("[autotest] gun prompt: ", p.prompt)
		await _tap("interact")
		await wait(0.3)
		print("[autotest] %s weapon now: %s (wanted %s)" % [g, ship.gun_weapon(g), w])
	if turret:
		print("[autotest] bought auto turret: %s, picked up: %s" % [await _buy(p, turret), await _pick_up(m, p, turret)])
		print("[autotest] hub prompt: ", await _install_at_hub(p))
		print("[autotest] auto turrets installed: %d / %d slots" % [ship.autocannons, ship.turret_slots()])
	# Buy one more and leave it behind: liftoff asks for confirmation.
	var left_behind: SupplyCrate = others[0] if others.size() > 0 else null
	if left_behind:
		print("[autotest] bought %s to leave behind: %s" % [left_behind.item, await _buy(p, left_behind)])
	p.position = ShipBuilder.SPAWN_POINTS[0]
	p.reset_physics_interpolation()
	await wait(0.3)
	ship.request_station.rpc_id(1, "pilot")
	await wait(0.4)
	await _tap("land")
	await wait(0.3)
	print("[autotest] first L with a bought item outside: state %d (2 = still landed)" % ship.landing)
	await _tap("land")
	print("[autotest] second L: state %d, exit opening %.2f" % [ship.landing, ship.gate_exit])
	t0 = Time.get_ticks_msec()
	var shot_lift := false
	while ship.landing != Mothership.Dock.FLYING and Time.get_ticks_msec() - t0 < 40000:
		await wait(0.5)
		if not shot_lift and ship.gate_exit > 0.6:
			shot_lift = true
			await shot("st13_exit_opening")
	print("[autotest] flying again: %s after %.1f s, ramp %.2f, gear %.2f, exit %.2f, left at the station %d" % [
		ship.landing == Mothership.Dock.FLYING, (Time.get_ticks_msec() - t0) / 1000.0, ship.ramp, ship.gear,
		ship.gate_exit, ship._station_cargo.get(0, []).size()])
	t0 = Time.get_ticks_msec()
	while ship._exit_state != 3 and Time.get_ticks_msec() - t0 < 20000:
		await wait(0.5)
	print("[autotest] exit sealed behind the ship: state %d, gate_exit %.2f, door %.2f, ship z %.1f" % [ship._exit_state, ship.gate_exit,
		ws.is_open("exit"), (inv * ship.global_position).z])
	await shot("st14_sealed_behind")
	# Back up towards the sealed exit: the flight computer stops the ship short of it.
	Input.action_press("move_back")
	await wait(2.0)
	Input.action_release("move_back")
	await wait(12.0)
	var back_z := (inv * ship.global_position).z
	print("[autotest] backing up: stern at z %.1f (exit outer face %.1f), hull %.0f, speed %.2f" % [back_z + ship._stern,
		StationBuilder.EXIT_FACE, ship.hull, ship.velocity.length()])
	Input.action_press("full_stop")
	await wait(0.3)
	Input.action_release("full_stop")
	# The auto turret against a spitter.
	if ship.autocannons > 0:
		await _put_ship(m, float(st["s_exit"]) + 140.0)
		_clear_aliens()
		await wait(0.2)
		var target := m.spawn_alien(Alien.Kind.SPITTER, ship.to_global(Vector3(-5, 9, -16)), 1.0, 1.0) as Alien
		target.set_physics_process(false)
		var kills0 := m.kills
		await wait(3.0)
		print("[autotest] auto turret vs spitter: %s, kills %d -> %d" % ["KILLED" if not is_instance_valid(target) else "alive hp %.0f" % target.hp, kills0, m.kills])
	_status(m)


func _clear_aliens() -> void:
	for a in get_tree().get_nodes_in_group("aliens"):
		a.queue_free()


## Bots on the mining laser, guns covering the bow, auto turrets in unlocked turret slots, laser
## overcharge from the shop and nest pace.
func _run_notes() -> void:
	Game.bot_count = 3
	Game.main.start_solo()
	await wait(1.0)
	var ships: Dictionary = Game.profile.get("ships", {})
	ships["prospector"] = {"slots": 2}
	Game.profile["ships"] = ships
	Game.profile_changed.emit()
	await wait(0.5)
	await shot("n01_homebase_slots")
	Game.main.start_mission()
	var m: MissionLevel = null
	for i in 600:
		await get_tree().process_frame
		m = Game.mission as MissionLevel
		if m and m.local_ready and m.local_player and m.started:
			break
	var ship := m.ship
	var p := m.local_player
	p.max_hp = 99999.0
	p.hp = 99999.0
	ship.debug_damage = false
	ship.autocannons = 2
	ship._apply_item("overcharge")
	ship._apply_item("overcharge")
	print("[autotest] stats: turret slots=%d installed=%d mining_vs_alien=%.1f active cannons=%s" % [
		ship.turret_slots(), ship.autocannons, ship.stats["mining_vs_alien"], ship.active_cannons()])

	# 1) Bots: mine while it is quiet.
	var credits0 := ship.credits
	var mining_seen := 0
	for i in 40:
		_clear_aliens()
		await wait(0.5)
		if ship.beams != 0:
			mining_seen += 1
	print("[autotest] quiet: occupants=%s mining %d/40 samples, credits %d -> %d | %s" % [ship.occupants, mining_seen, credits0, ship.credits, _bot_report(m)])
	await shot("n02_bot_mining")
	# 2) Aliens arrive: two bots take the guns, the third turns the laser on the aliens.
	for k in 4:
		m.spawn_alien(Alien.Kind.SPITTER, ship.to_global(Vector3(-12 + k * 8, 4, -38)), 8.0, 1.0)
	var laser_on_alien := 0
	var kills0 := m.kills
	for i in 20:
		await wait(0.5)
		for c in ship.crew_root.get_children():
			var cm := c as CrewMember
			if cm.bot and cm.brain.task == "mine" and ship.beams != 0 and instance_from_id(cm.brain._target_id) is Alien:
				laser_on_alien += 1
	print("[autotest] under attack: occupants=%s laser on an alien %d/20 samples, kills %d -> %d | %s" % [
		ship.occupants, laser_on_alien, kills0, m.kills, _bot_report(m)])
	await shot("n03_bots_fighting")
	for i in 3:
		Net.remove_bot()
	await wait(0.5)
	_clear_aliens()
	await wait(0.5)

	# 3) Side guns reach the bow.
	for g: String in ["gun_l", "gun_r"]:
		var t: Turret = ship.turrets[g]
		var reach := PackedStringArray()
		for target: Vector3 in [Vector3(0, 1.5, -25), Vector3(0, 1.5, -45), Vector3(0, 6, -70)]:
			reach.append("%s:%s" % [target.z, t.within_limits(t.aim_at_local(target))])
		print("[autotest] %s covers points straight ahead: %s (yaw range %.0f..%.0f deg)" % [g, ", ".join(reach), rad_to_deg(t.yaw_min), rad_to_deg(t.yaw_max)])
	var ahead := m.spawn_alien(Alien.Kind.SPITTER, ship.to_global(Vector3(0, 1.5, -40)), 1.0, 1.0) as Alien
	ahead.set_physics_process(false)
	ship.request_station.rpc_id(1, "gun_l")
	await wait(0.4)
	var gun: Turret = ship.turrets["gun_l"]
	for i in 25:
		if not is_instance_valid(ahead):
			break
		p.station_aim = _aim_for(ship, gun, ahead.global_position)
		Input.action_press("fire")
		await wait(0.1)
		if i == 4:
			await shot("n04_port_gun_forward")
	Input.action_release("fire")
	print("[autotest] port gun vs spitter dead ahead: %s" % ("KILLED" if not is_instance_valid(ahead) else "alive hp %.0f" % ahead.hp))
	p.exit_station(true)
	await wait(0.3)

	# 4) Laser overcharge: mining laser damage to an alien.
	_clear_aliens()
	await wait(0.2)
	var tough := m.spawn_alien(Alien.Kind.SPITTER, ship.to_global(Vector3(0, -1.0, -32)), 20.0, 1.0) as Alien
	tough.set_physics_process(false)
	ship.request_station.rpc_id(1, "mining")
	await wait(0.4)
	var laser: Turret = ship.turrets["mining"]
	p.station_aim = _aim_for(ship, laser, tough.global_position)
	await wait(0.4)
	var hp0 := tough.hp
	var t0 := Time.get_ticks_msec()
	Input.action_press("fire")
	for i in 20:
		p.station_aim = _aim_for(ship, laser, tough.global_position)
		await wait(0.05)
	Input.action_release("fire")
	var secs := (Time.get_ticks_msec() - t0) / 1000.0
	print("[autotest] laser vs alien: %.0f damage in %.2f s = %.0f dps (mining power %.0f x overcharge %.1f)" % [
		hp0 - tough.hp, secs, (hp0 - tough.hp) / secs, ship.stats["mining_power"], ship.stats["mining_vs_alien"]])
	p.exit_station(true)
	_clear_aliens()
	await wait(0.3)

	# 5) Auto turrets in the unlocked slots.
	var side_target := m.spawn_alien(Alien.Kind.SPITTER, ship.to_global(Vector3(-17, 10, -6)), 1.0, 1.0) as Alien
	side_target.set_physics_process(false)
	var cam := Camera3D.new()
	m.add_child(cam)
	cam.global_position = ship.to_global(Vector3(-16, 12, 10))
	cam.look_at(ship.to_global(Vector3(-3, 3, -3)))
	cam.current = true
	await wait(0.8)
	await shot("n05_turrets")
	await wait(2.5)
	print("[autotest] auto turrets vs spitter: %s, aims %s" % ["KILLED" if not is_instance_valid(side_target) else "alive hp %.0f" % side_target.hp,
		ship.auto_aim.slice(0, 2)])
	cam.queue_free()
	p.camera.current = true

	# 6) Agitated nest: hatch pace over 30 s.
	var chunk := m.cave_root.get_node("Chunk1") as CaveChunk
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	m._place_nest(chunk.result["verts"], chunk.result["norms"], rng, 60.0)
	await get_tree().process_frame
	var nests := get_tree().get_nodes_in_group("nests")
	var nest := nests[nests.size() - 1] as Nest
	ship.global_position = nest.global_position + nest.normal * 30.0
	ship.reset_physics_interpolation()
	nest.take_damage(1.0, {"sac": 0, "source": "turret"})
	var most_alive := 0
	for i in 60:
		await wait(0.5)
		nest.take_damage(0.01, {"sac": 0, "source": "turret"})
		var alive := 0
		for id: int in nest._spawned:
			if is_instance_id_valid(id):
				alive += 1
		most_alive = maxi(most_alive, alive)
	print("[autotest] agitated nest (%d sacs): %d hatched in 30 s, at most %d alive at once" % [nest.sac_hp.size(), nest._spawned.size(), most_alive])
	_status(m)


## Run the ship into the ground: destruction ends the mission and pays research points; then
## spend them at homebase.
func _run_death() -> void:
	Game.reset_profile()
	var m := await _start_solo_mission()
	m.ship.credits = 300
	m.ship.depth = 622.0
	m.ship.stations_docked = 1
	m.nests_destroyed = 2
	m.ship.apply_damage(99999.0, m.ship.global_position, "test")
	print("[autotest] ship alive=%s ending=%s" % [m.ship.alive, m.ending])
	await wait(1.0)
	await shot("x_destroyed")
	for i in 120:
		await wait(0.1)
		var lvl: Node = Game.main.current_level()
		if lvl and lvl.name == "Homebase":
			break
	await wait(1.0)
	print("[autotest] after destruction: rp=%d (want 62 + 10 + 4 = 76) best=%d last=%s" % [Game.rp(), int(Game.profile["best_depth"]), Game.profile["last_mission"]])
	await shot("x_homebase_after")
	var hull_before: float = Game.ship_stats()["max_hull"]
	Game.request_unlock_gun("flak")
	Game.request_ship_upgrade("hull")
	await wait(0.5)
	print("[autotest] bought: guns %s, hull %.0f -> %.0f, rp now %d" % [Game.profile["guns"], hull_before, Game.ship_stats()["max_hull"], Game.rp()])
	Game.request_unlock_ship("vanguard")
	await wait(0.3)
	print("[autotest] vanguard with too few RP: owned=%s rp=%d" % [Game.owns_ship("vanguard"), Game.rp()])
	await shot("x_shop")


## Research points and the homebase shipyard: convert an old save, then unlock ships and guns,
## upgrade ships and switch between them.
func _run_meta() -> void:
	# A version 1 save, like the ones from before the shipyard changed.
	var old := {"best_depth": 2304, "credits": 622, "missions": 3, "total_earned": 21752,
		"upgrades": {"hull": 5, "engine": 5}, "weapons": ["pulse", "rail"], "loadout": {"left": "rail", "right": "pulse"},
		"last_mission": {"depth": 2304, "earned": 17838}}
	var f := FileAccess.open(Game.save_path, FileAccess.WRITE)
	f.store_string(JSON.stringify(old))
	f = null
	var backup := Game.save_path.get_basename() + "_v1_backup.json"
	if FileAccess.file_exists(backup):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(backup))
	Game.load_profile()
	print("[autotest] migrated profile: ", Game.profile)
	Game.main.start_solo()
	await wait(1.5)
	await shot("meta01_migrated")
	print("[autotest] old save on disk before the first save: version %s" % str(JSON.parse_string(FileAccess.get_file_as_string(Game.save_path)).get("version", 1)))
	Game.request_unlock_gun("plasma")
	await wait(0.3)
	print("[autotest] backup written: %s, save version now %s, guns %s, rp %d" % [FileAccess.file_exists(backup),
		str(JSON.parse_string(FileAccess.get_file_as_string(Game.save_path)).get("version", 1)), Game.profile["guns"], Game.rp()])
	var hb := Game.main.current_level() as HomebaseLevel
	for id: String in ["excavator", "vanguard", "dreadnought"]:
		var rp0 := Game.rp()
		Game.request_unlock_ship(id)
		await wait(0.3)
		print("[autotest] unlock %s: owned=%s selected=%s rp %d -> %d" % [id, Game.owns_ship(id), Game.selected_ship(), rp0, Game.rp()])
	Game.profile["rp"] = 5000
	for id: String in ShipTypes.ORDER:
		if not Game.owns_ship(id):
			Game.request_unlock_ship(id)
			await wait(0.2)
		Game.request_select_ship(id)
		await wait(0.4)
		for up: String in Game.SHIP_UPGRADE_ORDER:
			Game.request_ship_upgrade(up)
			await wait(0.1)
		var stt := Game.ship_stats(id)
		print("[autotest] %s: hull %.0f shield %.0f speed %.2f slots %d/%d levels %s" % [id, stt["max_hull"], stt["max_shield"],
			stt["max_speed"], stt["turret_slots"], ShipTypes.get_type(id)["max_slots"], Game.profile["ships"][id]])
		hb._tabs.current_tab = 0
		await wait(0.5)
		await shot("meta02_%s" % id)
	hb._tabs.current_tab = 1
	await wait(0.3)
	await shot("meta03_upgrades")
	hb._tabs.current_tab = 2
	await wait(0.3)
	await shot("meta04_armory")
	Game.request_select_ship("prospector")
	await wait(0.3)
	print("[autotest] selected back: ", Game.selected_ship())


## Every mothership: exterior views, its stations (guns, lasers, scouts) and its turret slots.
func _run_ships() -> void:
	Game.main.start_solo()
	await wait(0.5)
	var ships := {}
	for id: String in ShipTypes.ORDER:
		ships[id] = {"slots": 1}
	Game.profile["ships"] = ships
	for id: String in ShipTypes.ORDER:
		Game.profile["ship"] = id
		Game.profile_changed.emit()
		await wait(0.4)
		Game.main.start_mission()
		var m: MissionLevel = null
		for i in 900:
			await get_tree().process_frame
			m = Game.mission as MissionLevel
			if m and m.local_ready and m.local_player and m.started and m.ship and m.ship.ship_type == id:
				break
		if m == null:
			print("[autotest] FAIL: no mission for ", id)
			return
		var ship := m.ship
		var p := m.local_player
		p.max_hp = 99999.0
		p.hp = 99999.0
		ship.max_hull = 99999.0
		ship.hull = 99999.0
		ship.autocannons = ship.turret_slots()
		print("[autotest] === %s: stations %s guns %s lasers %s scouts %s slots %d hull %.0f shield %.0f speed %.1f" % [id, ship.layout["order"],
			ship.gun_stations(), ship.laser_stations(), ship.scout_stations(), ship.turret_slots(), ship.max_hull, ship.max_shield, float(ship.stats["max_speed"])])
		await _put_ship(m, 60.0)
		await wait(0.5)
		var cam := Camera3D.new()
		cam.far = 400.0
		m.add_child(cam)
		var flood := OmniLight3D.new()
		flood.omni_range = 60.0
		flood.light_energy = 1.4
		cam.add_child(flood)
		cam.current = true
		for v: Array in [["a", Vector3(-24, 11, -22)], ["b", Vector3(22, 7, 18)], ["c", Vector3(-6, 20, 26)], ["d", Vector3(18, -6, -16)]]:
			cam.global_position = ship.to_global(v[1])
			cam.look_at(ship.to_global(Vector3(0, 1.5, -2.0)))
			await wait(0.3)
			await shot("ship_%s_%s" % [id, v[0]])
		cam.queue_free()
		p.camera.current = true
		# Every gun kills a spitter in front of it.
		for g: String in ship.gun_stations():
			var t: Turret = ship.turrets[g]
			# A target out in the open tunnel ahead, within the gun's arc.
			var spot := Vector3(t.position.x * 0.6, 4.0, -34.0)
			if not t.within_limits(t.aim_at_local(spot)):
				spot = t.position + t.transform.basis * Vector3(0, 0.2, -1).normalized() * 12.0
			var a := m.spawn_alien(Alien.Kind.SPITTER, ship.to_global(spot), 1.0, 1.0) as Alien
			a.set_physics_process(false)
			ship.request_station.rpc_id(1, g)
			await wait(0.4)
			for i in 60:
				if not is_instance_valid(a):
					break
				p.station_aim = _aim_for(ship, t, a.global_position)
				Input.action_press("fire")
				await wait(0.1)
			Input.action_release("fire")
			print("[autotest]   %s (%s, %s): station=%s spitter %s" % [g, ship.station_name(g), t.style, p.station,
				"KILLED" if not is_instance_valid(a) else "alive hp %.0f" % a.hp])
			if g == ship.gun_stations()[0]:
				await shot("ship_%s_gun" % id)
			if is_instance_valid(a):
				a.queue_free()
			p.exit_station(true)
			await wait(0.2)
		# Every laser fires at an alien in front of it.
		for l: String in ship.laser_stations():
			var t: Turret = ship.turrets[l]
			var a := m.spawn_alien(Alien.Kind.SPITTER, ship.to_global(t.position + Vector3(0, -0.5, -18)), 3.0, 1.0) as Alien
			a.set_physics_process(false)
			ship.request_station.rpc_id(1, l)
			await wait(0.4)
			var hp0 := a.hp
			Input.action_press("fire")
			for i in 20:
				if not is_instance_valid(a):
					break
				p.station_aim = _aim_for(ship, t, a.global_position)
				await wait(0.05)
			var on := ship.laser_on(l)
			if l == ship.laser_stations()[0]:
				await shot("ship_%s_laser" % id)
			Input.action_release("fire")
			print("[autotest]   %s: beam on=%s, alien damage %.0f (mining power %.0f x%.1f)" % [l, on, hp0 - (a.hp if is_instance_valid(a) else 0.0),
				ship.stats["mining_power"], ship.stats["mining_vs_alien"]])
			if is_instance_valid(a):
				a.queue_free()
			p.exit_station(true)
			await wait(0.2)
		# Every scout launches from its own bay and docks again.
		for sid: String in ship.scout_stations():
			var sc: Scout = m.scout_at(sid)
			ship.request_station.rpc_id(1, sid)
			await wait(0.5)
			var launched := sc.state == Scout.State.FLYING
			Input.action_press("move_forward")
			await wait(1.2)
			Input.action_release("move_forward")
			print("[autotest]   %s (%s): launched=%s pilot station=%s hp %.0f speed stat %.1f damage stat %.1f" % [sid, sc.style, launched, p.station,
				sc.hp, ship.stats["scout_speed"], ship.stats["scout_damage"]])
			if sid == ship.scout_stations()[0]:
				await shot("ship_%s_scout" % id)
			await _scout_fly_path_for(m, sc, [ship.to_global(sc.dock_point()) + ship.global_basis * ship.dock_launch(sid).normalized() * 3.0], 4.0, 12.0)
			sc.request_dock.rpc_id(1)
			await wait(0.4)
			print("[autotest]   %s docked=%s" % [sid, sc.state == Scout.State.DOCKED])
			if p.station != "":
				p.exit_station(true)
			await wait(0.2)
		# Interior from the gunnery deck.
		p.position = Vector3(0, 0.05, 0.6)
		p.look_yaw = 0.0
		p.look_pitch = -0.1
		p.reset_physics_interpolation()
		await wait(0.4)
		await shot("ship_%s_interior" % id)
		m.abort_mission()
		for i in 100:
			await wait(0.1)
			var lvl: Node = Game.main.current_level()
			if lvl and lvl.name == "Homebase":
				break
		await wait(0.8)
		await shot("ship_%s_homebase" % id)


## Steer a given scout through points (like _scout_fly_path, for any scout).
func _scout_fly_path_for(m: MissionLevel, sc: Scout, points: Array, reach: float, timeout: float) -> bool:
	var p := m.local_player
	Input.action_press("move_forward")
	for pt: Vector3 in points:
		var t := 0.0
		while true:
			var to := pt - sc.global_position
			if to.length() <= reach:
				break
			var d := to.normalized()
			p.station_aim = Vector2(atan2(-d.x, -d.z), asin(clampf(d.y, -1.0, 1.0)))
			await get_tree().physics_frame
			t += 1.0 / 60.0
			if t > timeout or sc.state != Scout.State.FLYING:
				Input.action_release("move_forward")
				return false
	Input.action_release("move_forward")
	return true


## The HUD's ship panel: percentages inside the bars, absolute values beside them.
func _run_hud() -> void:
	var m := await _start_solo_mission()
	if m == null:
		print("[autotest] FAIL: mission not ready")
		return
	var ship := m.ship
	ship.apply_damage(220.0, ship.global_position, "test")
	ship.damage_system("engine", 35.0)
	ship.fuel = 61.0
	ship.credits = 1234
	await wait(0.5)
	for id: String in ["hull", "shield", "fuel", "engine", "weapons", "blast"]:
		var b := m.hud._bars[id] as ProgressBar
		print("[autotest] %s bar: inside '%s' beside '%s' (fill %.2f)" % [id, (b.get_node("Pct") as Label).text, (m.hud._texts[id] as Label).text, b.value])
	print("[autotest] health bar: inside '%s' beside '%s'" % [(m.hud._hp_bar.get_node("Pct") as Label).text, m.hud._hp_text.text])
	print("[autotest] top line: ", m.hud._haul.text)
	await shot("hud_bars")
	ship.request_blast.rpc_id(1)
	await wait(0.4)
	await shot("hud_bars_shield_down")


## Compare the mining laser hum with the old one (levels and harshness) and listen-free checks.
func _run_sound() -> void:
	var old := Sfx._synth(1.0, {"wave": "saw", "f0": 110.0, "f1": 110.0, "tone": 0.3, "noise": 0.3, "lp0": 0.3, "lp1": 0.3, "vib_f": 6.0, "vib_a": 0.04, "decay": 0.0, "attack": 0.0})
	var new_s := (Sfx.stream("mine_loop") as AudioStreamWAV)
	var data := new_s.data
	var cur := PackedFloat32Array()
	cur.resize(data.size() / 2)
	for i in cur.size():
		cur[i] = data.decode_s16(i * 2) / 32000.0
	for pair: Array in [["old mine_loop", old, -6.0], ["new mine_loop", cur, -13.0]]:
		var smp: PackedFloat32Array = pair[1]
		var sum := 0.0
		var peak := 0.0
		var diff := 0.0
		for i in smp.size():
			sum += smp[i] * smp[i]
			peak = maxf(peak, absf(smp[i]))
			if i > 0:
				diff += absf(smp[i] - smp[i - 1])
		var rms := sqrt(sum / smp.size())
		print("[autotest] %s: rms %.3f (%.1f dBFS), peak %.2f, player %.0f dB -> %.1f dB effective, brightness %.4f, loop seam jump %.3f" % [pair[0], rms,
			linear_to_db(rms), peak, pair[2], linear_to_db(rms) + float(pair[2]), diff / smp.size(), absf(smp[smp.size() - 1] - smp[0])])


## Every mothership (and both scout models) in a plain lit studio, for judging the models.
func _run_models() -> void:
	Game.main.menu.hide()
	var world := Node3D.new()
	add_child(world)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.09, 0.1, 0.13)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.6, 0.7)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.ssao_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	world.add_child(sun)
	var back := DirectionalLight3D.new()
	back.rotation_degrees = Vector3(-20, 150, 0)
	back.light_energy = 0.5
	world.add_child(back)
	var cam := Camera3D.new()
	cam.fov = 45.0
	world.add_child(cam)
	cam.current = true
	for id: String in ShipTypes.ORDER:
		var ship := Node3D.new()
		world.add_child(ship)
		var parts := ShipBuilder.build_exterior(ship, id)
		var t := ShipTypes.get_type(id)
		for sid: String in t["scouts"]:
			var sc := Node3D.new()
			sc.position = t["by_id"][sid]["dock"]
			ship.add_child(sc)
			Scout.build_model(sc, t["scout_style"])
		var guns: Array = parts["autocannons"]
		for i in guns.size():
			(guns[i]["root"] as Node3D).visible = true
			(guns[i]["head"] as Node3D).visible = i < 2
		(parts["engine_glow_mat"] as StandardMaterial3D).albedo_color = Color(0.5, 0.9, 1.2)
		var r := float(t.get("chase", 40.0)) * 1.05
		for v: Array in [["front", Vector3(-0.62, 0.42, -0.66)], ["rear", Vector3(0.6, 0.36, 0.72)], ["side", Vector3(1.0, 0.12, -0.05)],
				["top", Vector3(0.15, 1.0, 0.25)], ["below", Vector3(-0.5, -0.45, -0.7)]]:
			cam.global_position = (v[1] as Vector3).normalized() * r + Vector3(0, 1.5, -1.5)
			cam.look_at(Vector3(0, 1.0, -1.5), Vector3.UP if absf((v[1] as Vector3).normalized().y) < 0.95 else Vector3.FORWARD)
			await wait(0.25)
			await shot("model_%s_%s" % [id, v[0]])
		ship.queue_free()
		await wait(0.1)
	for style: String in ["standard", "combat"]:
		var sc := Node3D.new()
		world.add_child(sc)
		Scout.build_model(sc, style)
		cam.global_position = Vector3(-6.0, 3.5, -6.5)
		cam.look_at(Vector3(0, 0, 0))
		await wait(0.25)
		await shot("model_scout_%s" % style)
		cam.global_position = Vector3(5.0, 3.0, 6.0)
		cam.look_at(Vector3(0, 0, 0))
		await wait(0.25)
		await shot("model_scout_%s_rear" % style)
		sc.queue_free()
		await wait(0.1)


## The homebase cheat menu: research points, then buying every ship, gun and upgrade the normal
## way; unlock and max-out buttons on a fresh profile; dive credits; restoring the real save.
func _run_cheats() -> void:
	Game.main.start_solo()
	await wait(1.0)
	# A "real" profile to come back to.
	Game.profile["rp"] = 123
	Game.profile["best_depth"] = 456
	Game.save_profile()
	Game.profile_changed.emit()
	var hb := Game.main.current_level() as HomebaseLevel
	print("[autotest] cheats allowed: %s, button shown: %s" % [Game.cheats_allowed(), hb._cheat_btn != null and hb._cheat_btn.visible])
	hb._cheat_btn.pressed.emit()
	await wait(0.4)
	await shot("cheat01_menu")
	var cm := hb._cheats
	var rp0 := Game.rp()
	cm.buttons["rp_10000"].pressed.emit()
	await wait(0.3)
	print("[autotest] +10,000 RP: %d -> %d, backup kept: %s, restore enabled: %s" % [rp0, Game.rp(), Game.has_cheat_backup(),
		not (cm.buttons["restore"] as Button).disabled])
	# Buy everything through the shipyard's normal purchases.
	for id: String in ShipTypes.ORDER:
		Game.request_unlock_ship(id)
		await wait(0.05)
	for id: String in Game.GUN_ORDER:
		Game.request_unlock_gun(id)
		await wait(0.05)
	for id: String in ShipTypes.ORDER:
		Game.request_select_ship(id)
		await wait(0.05)
		for up: String in Game.SHIP_UPGRADE_ORDER:
			for n in 6:
				var cost := Game.ship_upgrade_cost(id, up)
				if cost < 0 or cost > Game.rp():
					break
				Game.request_ship_upgrade(up)
				await wait(0.03)
	print("[autotest] bought everything: ships %s, guns %s, rp left %d" % [Game.profile["ships"], Game.profile["guns"], Game.rp()])
	await wait(0.3)
	await shot("cheat02_bought")
	# Fresh profile (needs two clicks), then the unlock and max buttons.
	cm.buttons["fresh"].pressed.emit()
	await wait(0.2)
	print("[autotest] fresh after one click: ships %s, button '%s'" % [Game.profile["ships"].keys(), (cm.buttons["fresh"] as Button).text])
	cm.buttons["fresh"].pressed.emit()
	await wait(0.3)
	print("[autotest] fresh after two clicks: rp %d, ships %s, guns %s" % [Game.rp(), Game.profile["ships"], Game.profile["guns"]])
	for id: String in ["unlock_ships", "unlock_guns", "max_all"]:
		cm.buttons[id].pressed.emit()
		await wait(0.2)
	var maxed := true
	for id: String in ShipTypes.ORDER:
		for up: String in Game.SHIP_UPGRADE_ORDER:
			maxed = maxed and Game.ship_upgrade_cost(id, up) < 0
	print("[autotest] unlock all + max all: ships %s, guns %s, every upgrade maxed: %s" % [Game.profile["ships"].keys(), Game.profile["guns"], maxed])
	# Dive credits for the waystation shops.
	cm.buttons["credits_10000"].pressed.emit()
	await wait(0.2)
	print("[autotest] dive credits set: %d ('%s')" % [Game.cheat_dive_credits, cm._credits_label.text])
	await shot("cheat03_credits")
	Game.main.start_mission()
	var m: MissionLevel = null
	for i in 900:
		await get_tree().process_frame
		m = Game.mission as MissionLevel
		if m and m.local_ready and m.started and m.ship:
			break
	print("[autotest] dive started with %d credits (ship %s)" % [m.ship.credits, m.ship.ship_type])
	await wait(1.0)
	m.abort_mission()
	for i in 100:
		await wait(0.1)
		var lvl: Node = Game.main.current_level()
		if lvl and lvl.name == "Homebase":
			break
	await wait(0.5)
	hb = Game.main.current_level() as HomebaseLevel
	cm = hb._cheats
	cm.buttons["credits_0"].pressed.emit()
	# Back to the real save.
	cm.buttons["restore"].pressed.emit()
	await wait(0.3)
	print("[autotest] restored: rp %d best %d ships %s guns %s, backup removed: %s, dive credits %d" % [Game.rp(), int(Game.profile["best_depth"]),
		Game.profile["ships"].keys(), Game.profile["guns"], not Game.has_cheat_backup(), Game.cheat_dive_credits])
	hb._cheat_btn.pressed.emit()
	await wait(0.3)
	await shot("cheat04_restored")
