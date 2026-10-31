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
		"interiors":
			await _run_interiors(true)
		"backlog":
			await _run_backlog(true)
		"backlog_check":
			await _run_backlog(false)
		"backlog2":
			await _run_backlog2(true)
		"backlog2_check":
			await _run_backlog2(false)
		"interiors_check":
			await _run_interiors(false)
		"interior_bots":
			await _run_interior_bots()
		"hud":
			await _run_hud()
		"sound":
			await _run_sound()
		"models":
			await _run_models()
		"assets":
			await _run_assets()
		"decals":
			await _run_decals(true)
		"decals_check":
			await _run_decals(false)
		"cheats":
			await _run_cheats()
		"join_station":
			await _run_join_station()
		"tunnels":
			await _run_tunnels()
		"derelict":
			await _run_derelict()
		"weapons":
			await _run_weapons()
		"host_derelict":
			await _run_host_derelict()
		"join_derelict":
			await _run_join_derelict()
		"gunpod":
			await _run_gunpod(true)
		"gunpod_check":
			await _run_gunpod(false)
		"rockets":
			await _run_rockets(true)
		"rockets_check":
			await _run_rockets(false)
		"cockpit":
			await _run_cockpit(true)
		"cockpit_check":
			await _run_cockpit(false)
		"fighter":
			await _run_fighter(true)
		"fighter_check":
			await _run_fighter(false)
		"host_scout":
			await _run_host_scout()
		"join_scout":
			await _run_join_scout()
		"soldier":
			await _run_soldier(true)
		"soldier_check":
			await _run_soldier(false)
		"dual":
			await _run_dual()
		"outpost":
			await _run_outpost(true)
		"outpost_check":
			await _run_outpost(false)
		"host_soldier":
			await _run_host_soldier()
		"join_soldier":
			await _run_join_soldier()
		"glass":
			await _run_glass()
		"visor_side":
			await _run_visor_side()
		"sfx_levels":
			_run_sfx_levels()
		"outpost_plans":
			await OutpostAutotest.new(self).run_plans()
		"outpost_tour":
			await OutpostAutotest.new(self).run_tour()
		"outposts":
			await OutpostAutotest.new(self).run_check(true)
		"outposts_check":
			await OutpostAutotest.new(self).run_check(false)
		"outpost_gallery":
			await OutpostAutotest.new(self).run_gallery()
		"keypads":
			await OutpostAutotest.new(self).run_keypad_clear(true)
		"props_gallery":
			await OutpostAutotest.new(self).run_props_gallery()
		"outpost_perf":
			await OutpostAutotest.new(self).run_perf(3)
		"outpost_perf_solo":
			await OutpostAutotest.new(self).run_perf(0)
		"keypads_check":
			await OutpostAutotest.new(self).run_keypad_clear(false)
		"outpost_walls":
			await OutpostAutotest.new(self).run_walls(120.0)
		"scanner_perf":
			await OutpostAutotest.new(self).run_scanner_perf()
		"generator_views":
			await OutpostAutotest.new(self).run_generator_views()
		"sentries":
			await OutpostAutotest.new(self).run_sentries(true)
		"sentries_check":
			await OutpostAutotest.new(self).run_sentries(false)
		"hub":
			await OutpostAutotest.new(self).run_hub(true)
		"hub_check":
			await OutpostAutotest.new(self).run_hub(false)
		"host_outpost":
			await OutpostAutotest.new(self).run_host()
		"join_outpost":
			await OutpostAutotest.new(self).run_join()
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
	p.position = _hub_spot(p.ship, 1.7, 0.05)
	p.reset_physics_interpolation()
	await wait(0.4)
	_face(p, _hub_spot(p.ship, 0.6, 0.9))
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
	p.position = ship.cockpit.button_spot() + Vector3(0, 0.05, 0)
	p.reset_physics_interpolation()
	_face(p, ship.cockpit.button_local())
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
	# 1) The port gun pod kills a spitter in its arc.
	ship.request_station.rpc_id(1, "gun_l")
	await wait(0.3)
	var gun: Turret = ship.turrets["gun_l"]
	var a := m.spawn_alien(Alien.Kind.SPITTER, ship.to_global(Vector3(-17, 2, -10)), 1.0, 1.0) as Alien
	a.set_physics_process(false)
	var t0 := Time.get_ticks_msec()
	for i in 120:
		if not is_instance_valid(a):
			break
		p.station_aim = _aim_for(ship, gun, a.global_position)
		Input.action_press("fire")
		await get_tree().physics_frame
	Input.action_release("fire")
	print("[autotest] gun pod: spitter %s after %d ms" % ["KILLED" if not is_instance_valid(a) else "alive (hp %.0f)" % a.hp, Time.get_ticks_msec() - t0])
	if is_instance_valid(a):
		a.queue_free()
	p.exit_station(true)
	await wait(0.2)
	# 2) Pistol vs boarder.
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
	print("[autotest] pistol vs boarder: %s" % ("KILLED" if not is_instance_valid(b) else "alive"))
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
	var panel: Dictionary = ship.repair_panels()[0]
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
		# The motion tracker's warning, then the surge, reach the client too.
		if i == 0:
			m._director_t = 99999.0
			m.ship.hostility = 0.3
		elif i == 1:
			# Close to the dive's start no pack can come from astern, and none from ahead this close to
			# the first waystation: keep asking until the ship is deep enough for one.
			for k in 25:
				m._ambush = {}
				m._director_t = 0.0
				await wait(0.3)
				if m.ship.contact_warning() > 0.0:
					break
			print("[autotest] host: ambush warned of at depth %.0f, %.1f s to go (%s)" % [m.ship.depth, m.ship.contact_warning(),
				"ahead" if m.ship.contact_ahead() else "astern"])
		elif i == 4:
			m.ship.hostility = 1.0
	print("[autotest] host: hostility %s, motion warning %.1f s" % [Mothership.HOSTILITY_STAGES[m.ship.hostility_stage()], m.ship.contact_warning()])
	await shot("net_host_mission")
	m.ship.hostility = 0.0
	m._director_t = 99999.0
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
	var cp := m.ship.cockpit
	for i in 7:
		# Watch the motion tracker, the HUD's warning and the cockpit's SURGE lamp all the way through
		# each 2 s.
		var warn := 0.0
		var hud_warn := ""
		var lamp_surge := 0.0
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 2000:
			await get_tree().process_frame
			warn = maxf(warn, m.ship.contact_warning())
			if m.hud._ambush.visible and hud_warn.is_empty():
				hud_warn = m.hud._ambush.text
			lamp_surge = maxf(lamp_surge, (cp._lamps["surge"]["mat"] as StandardMaterial3D).emission_energy_multiplier)
		print("[autotest] client view: depth=%.1f shipvel=%s aliens=%d deposits=%d hull=%.0f; host's thrust lever %.2f rad; motion warning up to %.1f s (HUD: '%s'), hostility %s, cockpit SURGE lamp %.1f" % [
			m.ship.depth, m.ship.net_vel, get_tree().get_nodes_in_group("aliens").size(), get_tree().get_nodes_in_group("deposits").size(),
			m.ship.hull, cp._lever.rotation.x, warn, hud_warn, Mothership.HOSTILITY_STAGES[m.ship.hostility_stage()], lamp_surge])
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
	light.light_projector = Models.light_cookie("headlight")
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


## A point in front of the ship's install hub: `out` metres out from it, `up` above the floor.
func _hub_spot(ship: Mothership, out: float, up: float) -> Vector3:
	var inner := ship.interior_layout()
	return (inner["hub"] as Vector3) + Basis(Vector3.UP, float(inner.get("hub_yaw", 0.0))) * Vector3(out, up, 0)


## Carry the held crate to the install hub and fit it.
func _install_at_hub(p: CrewMember) -> String:
	p.position = _hub_spot(p.ship, 1.7, 0.05)
	p.reset_physics_interpolation()
	await wait(0.25)
	_face(p, _hub_spot(p.ship, 0.6, 0.9))
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
	print("[autotest] pilot info: ", " | ".join(m.ship.pilot_status()))
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
	print("[autotest] walked back aboard with the crate: pos %s aboard=%s carrying=%s" % [p.position, p.ship.is_aboard(p.position), p.carrying != null])
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
	p.position = p.ship.spawn_points()[0]
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
	# No Armory tab while the ship guns are shelved (every gun pod carries a heavy machine gun).
	var tabs := PackedStringArray()
	for i in hb._tabs.get_tab_count():
		tabs.append(hb._tabs.get_tab_title(i))
	print("[autotest] shipyard tabs: %s" % ", ".join(tabs))
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


## Camera views (first person: stand at a floor point, look at a point) of each ship's interior.
const INTERIOR_VIEWS := {
	"prospector": [["cockpit", Vector3(0, 0, -6.6), Vector3(0, 1.2, -10.1)], ["plate", Vector3(0, 0, -3.0), Vector3(0, 2.8, -6.0)],
		["hall", Vector3(0, 0, 4.2), Vector3(0, 1.5, -6.0)], ["door", Vector3(1.6, 0, 8.0), Vector3(0, 2.9, 10.0)]],
	"vanguard": [["bridge", Vector3(0, 0, -7.6), Vector3(0, 1.2, -12.0)], ["plate", Vector3(0, 0, -4.4), Vector3(0, 2.8, -6.6)],
		["corridor", Vector3(0, 0, 4.6), Vector3(0, 1.5, -7.0)], ["corridor_aft", Vector3(0, 0, -2.0), Vector3(0, 2.6, 5.4)],
		["flight_a", Vector3(-2.2, 0, -1.6), Vector3(-5.5, 1.5, -4.5)], ["weapons", Vector3(-2.0, 0, 4.5), Vector3(-6.0, 1.3, 1.5)],
		["quartermaster", Vector3(2.0, 0, 0.2), Vector3(6.0, 1.2, 3.5)], ["engine", Vector3(0, 0, 6.0), Vector3(0, 1.2, 10.0)],
		["engine_side", Vector3(-4.9, 0, 6.0), Vector3(-6.0, 1.3, 8.5)], ["door", Vector3(1.6, 0, 8.0), Vector3(0, 2.9, 10.0)]],
	"excavator": [["control", Vector3(0, 0, -6.4), Vector3(0, 1.2, -10.2)], ["plate", Vector3(-2.5, 0, -4.6), Vector3(0, 2.8, -5.7)],
		["hall_front", Vector3(-4.3, 0, -5.2), Vector3(2.0, 1.2, 3.0)], ["crusher", Vector3(5.6, 0, -1.0), Vector3(0, 1.3, -1.6)],
		["hall_rear", Vector3(0, 0, 4.8), Vector3(0, 1.6, -5.8)], ["gunnery", Vector3(3.8, 0, -3.0), Vector3(6.6, 1.5, -4.6)],
		["hub", Vector3(-3.6, 0, 1.0), Vector3(-6.5, 1.2, 3.0)], ["engine", Vector3(0, 0, 5.9), Vector3(0, 1.2, 10.0)],
		["engine_side", Vector3(-4.5, 0, 6.2), Vector3(-6.5, 1.3, 8.2)], ["door", Vector3(1.6, 0, 8.0), Vector3(0, 2.9, 10.0)]],
	"dreadnought": [["bridge", Vector3(0, 0, -8.9), Vector3(0, 1.4, -13.4)], ["bridge_side", Vector3(1.0, 0, -10.0), Vector3(3.8, 1.5, -11.0)],
		["plate", Vector3(0, 0, -4.8), Vector3(0, 3.1, -6.5)], ["cic", Vector3(0, 0, -1.2), Vector3(0, 1.5, -6.6)],
		["battery", Vector3(-4.0, 0, -4.5), Vector3(-7.8, 1.6, -2.5)], ["corridor", Vector3(-3.25, 0, 4.6), Vector3(-3.25, 1.6, -0.6)],
		["core", Vector3(2.5, 0, -0.2), Vector3(0, 1.8, 0.9)], ["magazine", Vector3(-5.4, 0, 1.0), Vector3(-7.6, 1.2, 3.6)],
		["scout_bay", Vector3(5.4, 0, 0.5), Vector3(7.4, 1.2, 2.6)], ["engine", Vector3(0, 0, 5.6), Vector3(0, 1.4, 10.0)],
		["engine_side", Vector3(-6.6, 0, 5.6), Vector3(-7.6, 1.3, 7.6)], ["door", Vector3(1.6, 0, 8.0), Vector3(0, 2.9, 10.0)]],
}


## Every mothership's interior: its walls inside the hull, the walking graph clear for a crew member,
## every seat, panel, spawn point and hatch reachable, and (with shots) views from around the ship.
func _run_interiors(shots: bool) -> void:
	Game.main.start_solo()
	await wait(0.5)
	var ships := {}
	for id: String in ShipTypes.ORDER:
		ships[id] = {}
	Game.profile["ships"] = ships
	for id: String in ShipTypes.ORDER:
		Game.profile["ship"] = id
		Game.profile_changed.emit()
		await wait(0.3)
		Game.main.start_mission()
		var m: MissionLevel = null
		for i in 900:
			await get_tree().process_frame
			m = Game.mission as MissionLevel
			if m and m.local_ready and m.local_player and m.started and m.ship and m.ship.ship_type == id:
				break
		if m == null or m.ship == null or m.ship.ship_type != id:
			print("[autotest] FAIL: no mission for ", id)
			return
		var ship := m.ship
		var p := m.local_player
		p.max_hp = 99999.0
		p.hp = 99999.0
		await wait(0.5)
		print("[autotest] === %s interior" % id)
		_check_interior(ship)
		if shots:
			for v: Array in INTERIOR_VIEWS.get(id, []):
				p.position = (v[1] as Vector3) + Vector3(0, 0.05, 0)
				p.velocity = Vector3.ZERO
				_face(p, v[2])
				p.reset_physics_interpolation()
				await wait(0.35)
				await shot("int_%s_%s" % [id, v[0]])
		m.abort_mission()
		for i in 100:
			await wait(0.1)
			var lvl: Node = Game.main.current_level()
			if lvl and lvl.name == "Homebase":
				break
		await wait(0.5)


## Crew bots in every ship's interior: two bots repair both systems and then man the guns. Counts
## the times a bot got stuck and hopped (the unstick teleport in CrewBot._walk_to).
func _run_interior_bots() -> void:
	Game.bot_count = 2
	Game.main.start_solo()
	await wait(0.5)
	Game.bot_count = 0
	var ships := {}
	for id: String in ShipTypes.ORDER:
		ships[id] = {}
	Game.profile["ships"] = ships
	for id: String in ShipTypes.ORDER:
		Game.profile["ship"] = id
		Game.profile_changed.emit()
		await wait(0.3)
		Game.main.start_mission()
		var m: MissionLevel = null
		for i in 900:
			await get_tree().process_frame
			m = Game.mission as MissionLevel
			if m and m.local_ready and m.local_player and m.started and m.ship and m.ship.ship_type == id:
				break
		if m == null or m.ship == null or m.ship.ship_type != id:
			print("[autotest] FAIL: no mission for ", id)
			return
		var ship := m.ship
		ship.max_hull = 99999.0
		ship.hull = 99999.0
		await _put_ship(m, 60.0)
		_clear_aliens()
		var bots: Array[CrewMember] = []
		for c in ship.crew_root.get_children():
			var cm := c as CrewMember
			if cm and cm.bot:
				bots.append(cm)
		ship.damage_system("engine", 60.0)
		ship.damage_system("weapons", 60.0)
		var hops := 0
		var last := {}
		var seated := {}
		var t := 0.0
		while t < 45.0 and (ship.engine_hp < 100.0 or ship.weapons_hp < 100.0):
			await get_tree().physics_frame
			t += 1.0 / 60.0
			for b in bots:
				var was: bool = seated.get(b.name, false)
				if last.has(b.name) and not was and not b.brain.seated and b.position.distance_to(last[b.name]) > 0.5:
					hops += 1
				last[b.name] = b.position
				seated[b.name] = b.brain.seated
		print("[autotest] %s: %d bots repaired engine %.0f%% and weapons %.0f%% in %.1f s, %d stuck hops" % [id, bots.size(),
			ship.engine_hp, ship.weapons_hp, t, hops])
		# Aliens ahead: the bots go to the guns.
		for i in 3:
			var a := m.spawn_alien(Alien.Kind.SPITTER, ship.to_global(Vector3(-6.0 + i * 6.0, 6.0, -45.0)), 50.0, 0.0) as Alien
			if a:
				a.set_physics_process(false)
		hops = 0
		t = 0.0
		var manned := 0
		while t < 20.0:
			await get_tree().physics_frame
			t += 1.0 / 60.0
			manned = 0
			for b in bots:
				var was: bool = seated.get(b.name, false)
				if last.has(b.name) and not was and not b.brain.seated and b.position.distance_to(last[b.name]) > 0.5:
					hops += 1
				last[b.name] = b.position
				seated[b.name] = b.brain.seated
				if b.brain.seated and b.station in ship.gun_stations():
					manned += 1
			if manned >= mini(bots.size(), ship.gun_stations().size()):
				break
		var at := PackedStringArray()
		for b in bots:
			at.append("%s %s" % [b.display_name, b.station if b.station != "" else "walking"])
		print("[autotest] %s: guns manned %d of %d after %.1f s (%s), %d stuck hops" % [id, manned, ship.gun_stations().size(), t,
			", ".join(at), hops])
		_clear_aliens()
		m.abort_mission()
		for i in 100:
			await wait(0.1)
			var lvl: Node = Game.main.current_level()
			if lvl and lvl.name == "Homebase":
				break
		await wait(0.5)

## How far ship-local point q is inside the hull (negative: outside), roughly in metres.
static func _hull_margin(sections: Array, chamfer: float, q: Vector3) -> float:
	if q.z < float((sections[0] as Array)[0]) - 0.001 or q.z > float((sections[sections.size() - 1] as Array)[0]) + 0.001:
		return -1.0
	var sec := ShipBuilder.section_at(sections, q.z)
	var ax := absf(q.x)
	var ay := absf(q.y - sec.z)
	var diag := ((2.0 - chamfer) - ax / sec.x - ay / sec.y) * minf(sec.x, sec.y) * 0.7
	return minf(minf(sec.x - ax, sec.y - ay), diag)


## Interior checks for one ship (see _run_interiors).
func _check_interior(ship: Mothership) -> void:
	var t := ship.layout
	var inner := ship.interior_layout()
	# The whole hull, the glazed nose in front of the cockpit included.
	var sections: Array = ShipTypes.full_sections(t)
	var chamfer := float(t["chamfer"])
	var outside := 0
	var shapes := 0
	for c in ship.interior_body.get_children():
		var cs := c as CollisionShape3D
		if cs == null:
			continue
		shapes += 1
		var corners: Array[Vector3] = []
		if cs.shape is BoxShape3D:
			var half := (cs.shape as BoxShape3D).size * 0.5
			for i in 8:
				corners.append(cs.transform * Vector3(half.x * (1.0 if i & 1 else -1.0), half.y * (1.0 if i & 2 else -1.0), half.z * (1.0 if i & 4 else -1.0)))
		elif cs.shape is CylinderShape3D:
			var cyl := cs.shape as CylinderShape3D
			for i in 8:
				var a := TAU * i / 8.0
				for y: float in [-cyl.height * 0.5, cyl.height * 0.5]:
					corners.append(cs.position + Vector3(cos(a) * cyl.radius, y, sin(a) * cyl.radius))
		var worst := INF
		var worst_q := Vector3.ZERO
		for q in corners:
			var mg := _hull_margin(sections, chamfer, q)
			if mg < worst:
				worst = mg
				worst_q = q
		if worst < -0.01:
			outside += 1
			print("[autotest]   OUTSIDE HULL by %.2f m: shape at %s, corner %s" % [-worst, cs.position, worst_q])
	print("[autotest]   hull fit: %d of %d interior shapes poke outside the hull" % [outside, shapes])
	var space := ship.get_world_3d().direct_space_state
	var cap := CapsuleShape3D.new()
	cap.radius = 0.36
	cap.height = 1.8
	var wps: Dictionary = inner["waypoints"]
	var blocked := 0
	for link: Array in inner["links"]:
		var frac := _sweep(space, ship, cap, wps[link[0]], wps[link[1]])
		if frac < 1.0:
			blocked += 1
			print("[autotest]   BLOCKED link %s -> %s at %.0f%%" % [link[0], link[1], frac * 100.0])
	for k: String in wps:
		if not ship.is_aboard(wps[k]):
			print("[autotest]   waypoint %s is not aboard" % k)
	print("[autotest]   walking graph: %d of %d links blocked" % [blocked, (inner["links"] as Array).size()])
	var spots: Array = []
	for sid: String in t["order"]:
		var st: Dictionary = t["by_id"][sid]
		spots.append(["seat " + sid, st["seat"]])
		spots.append(["seat exit " + sid, (st["seat"] as Vector3) + Basis(Vector3.UP, float(st["seat_yaw"])) * Vector3(0, 0, 0.9)])
	var panels := ship.repair_panels()
	for i in panels.size():
		spots.append(["panel %d %s" % [i, panels[i]["system"]], ShipInteriors.panel_spot(panels[i])])
	spots.append(["install hub", _hub_spot(ship, 1.25, 0.0)])
	for q: Vector3 in ship.spawn_points():
		spots.append(["spawn", Vector3(q.x, 0, q.z)])
	for q: Vector3 in ship.idle_spots():
		spots.append(["bot idle", q])
	for q: Vector3 in inner["hatches"]:
		spots.append(["hatch", q])
	var bad := 0
	for sp: Array in spots:
		var pt: Vector3 = sp[1]
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = cap
		q.collision_mask = Game.LAYER_INTERIOR
		q.transform = Transform3D(ship.global_basis, ship.to_global(pt + Vector3(0, 0.95, 0)))
		var hits := space.intersect_shape(q, 4)
		var wp := ship.nav_closest(ship.nav, pt)
		var frac := _sweep(space, ship, cap, ship.nav.get_point_position(wp), pt)
		if not hits.is_empty() or frac < 1.0 or not ship.is_aboard(pt):
			bad += 1
			print("[autotest]   SPOT %s at %s: overlaps %d, reach from waypoint %s %.0f%%, aboard %s" % [sp[0], pt, hits.size(),
				ship.nav.get_point_position(wp), frac * 100.0, ship.is_aboard(pt)])
	print("[autotest]   spots: %d of %d unreachable or blocked" % [bad, spots.size()])


## How far (0..1) a crew-sized capsule gets moving from ship-local floor point a to b.
func _sweep(space: PhysicsDirectSpaceState3D, ship: Mothership, cap: Shape3D, a: Vector3, b: Vector3) -> float:
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = cap
	q.collision_mask = Game.LAYER_INTERIOR
	q.transform = Transform3D(ship.global_basis, ship.to_global(Vector3(a.x, 0.95, a.z)))
	q.motion = ship.global_basis * Vector3(b.x - a.x, 0, b.z - a.z)
	var r := space.cast_motion(q)
	return r[0] if r.size() > 0 else 1.0


## The 2026-10-16 backlog: gun names and tuning, spread on every weapon, the plasma blast, mining at
## the laser tip, waystation spacing, hostility (stages, ambushes, reset at a waystation, holding at
## an abandoned station), the shop door, the buyback counter, the flashlight, crawling skitters and
## egg sac health. Screenshots with `shots`.
func _run_backlog(shots: bool) -> void:
	var m := await _start_solo_mission()
	if m == null:
		print("[autotest] FAIL: mission not ready")
		return
	var ship := m.ship
	var p := m.local_player
	var tough := ship.stats.duplicate()
	tough["crew_hp"] = 99999.0
	ship.stats = tough
	ship.max_hull = 99999.0
	ship.hull = 99999.0
	# Waystation spacing, gun names, nests.
	var ss := PackedStringArray()
	for k in 4:
		ss.append("%.0f" % float(m.cave.station(k)["s"]))
	print("[autotest] waystations at %s m (spacing %.0f)" % [", ".join(ss), CaveGen.STATION_SPACING])
	print("[autotest] guns: %s" % ", ".join(PackedStringArray(Game.GUN_ORDER.map(func(g): return Game.GUNS[g]["name"]))))
	print("[autotest] egg sac health: %.0f at the surface, %.0f at 1000 m (other aliens x%.2f)" % [Nest.SAC_HP,
		Nest.SAC_HP * (1.0 + (m.hp_mult(1000.0) - 1.0) * 0.5), m.hp_mult(1000.0)])
	# Gun pod tuning and spread (measured from the rounds it fires: each one aims from its muzzle at
	# the point under the sight, then scatters).
	await _put_ship(m, 560.0)
	ship.gate_k = 0
	ship.gate_entry = 0.0
	ship._exit_state = 3
	var g: String = ship.gun_stations()[0]
	var pod: GunPod = ship.turrets[g]
	var before: int = m.projectiles._shots.size()
	for i in 12:
		ship._fire_round(g, ship.gun_index(g), false)
	var sight := _gp_sight_point(ship, g)
	var max_a := 0.0
	var sum := 0.0
	var n := 0
	for i in range(before, m.projectiles._shots.size()):
		var s: Dictionary = m.projectiles._shots[i]
		var v: Vector3 = (s["vel"] as Vector3) - ship.velocity
		var a := rad_to_deg(v.angle_to(sight - (s["pos"] as Vector3)))
		max_a = maxf(max_a, a)
		sum += a
		n += 1
	print("[autotest] gun pod: %d rounds, spread mean %.2f max %.2f deg (cone %.2f) round the sight point %.0f m out, every %.3f s, %.0f dmg, dps %.0f" % [n,
		sum / maxf(n, 1), max_a, GunPod.SPREAD, ship.to_global(pod.eye_local(ship.aim_of(g))).distance_to(sight), GunPod.FIRE_INTERVAL,
		GunPod.DAMAGE, GunPod.DAMAGE / GunPod.FIRE_INTERVAL])
	for id: String in CrewWeapons.ORDER:
		var d := CrewWeapons.def(id)
		print("[autotest] hand %s: spread %.3f rad from the hip, %.4f aimed, every %.2f s, %d x %.0f dmg = %.0f dps%s" % [d["name"], float(d["hip"]), float(d["ads"]),
			float(d["cooldown"]), int(d["pellets"]), float(d["damage"]), float(d["damage"]) * int(d["pellets"]) / float(d["cooldown"]),
			", splash %.1f m" % float(d["splash"]) if d.has("splash") else ""])
	# The plasma blast: aliens 0, 7, 12 and 18 m from the burst.
	var burst := ship.to_global(Vector3(0, 3.0, -40.0))
	var victims: Array[Alien] = []
	for dist: float in [0.0, 7.0, 12.0, 18.0]:
		var a := m.spawn_alien(Alien.Kind.SPITTER, burst + ship.global_basis.x * dist, 10.0, 1.0) as Alien
		a.set_physics_process(false)
		victims.append(a)
	await wait(0.2)
	var hps: Array[float] = []
	for a in victims:
		hps.append(a.hp)
	m.projectiles._splash(burst, float(Projectiles.KINDS["plasma"]["splash"]), 34.0)
	var hit_report := PackedStringArray()
	for i in victims.size():
		hit_report.append("%.0f m: -%.0f" % [[0.0, 7.0, 12.0, 18.0][i], hps[i] - victims[i].hp])
		victims[i].queue_free()
	print("[autotest] plasma mortar blast (radius %.0f m): %s" % [float(Projectiles.KINDS["plasma"]["splash"]), ", ".join(hit_report)])
	# Mining: a chunk flies to the mining laser's tip.
	var lid: String = ship.laser_stations()[0]
	var lt: Turret = ship.turrets[lid]
	var tip := ship.to_global(lt.muzzle_local(lt.aim))
	var credits0 := ship.credits
	var chunk := m.pickup_spawner.spawn({"name": "PT1", "kind": "aurium", "pos": tip + ship.global_basis * Vector3(6.0, -4.0, -18.0),
		"vel": Vector3.ZERO, "value": 6, "fuel": 0.0}) as MineralChunk
	var last := chunk.global_position
	for i in 600:
		if not is_instance_valid(chunk) or chunk._collected:
			break
		last = chunk.global_position
		await get_tree().physics_frame
	tip = ship.to_global(lt.muzzle_local(lt.aim))
	print("[autotest] mineral chunk collected %.1f m from the laser tip (%.1f m from the old belly collector), credits %d -> %d" % [
		last.distance_to(tip), last.distance_to(ship.to_global(ship.layout["collector"])), credits0, ship.credits])
	# Hostility: no ambushes while docile, then more and bigger ones.
	_clear_aliens()
	await wait(0.3)
	for h: float in [0.1, 0.3, 0.6, 0.9]:
		ship.hostility = h
		await wait(0.2)
		var waves := 0
		var spawned := 0
		var warned := 0
		for i in 4:
			var n0 := get_tree().get_nodes_in_group("aliens").size()
			# The motion tracker warns first; forcing the timer again sends the pack at once.
			m._director_t = 0.0
			await wait(0.1)
			if ship.contact_warning() > 0.0:
				warned += 1
			m._director_t = 0.0
			await wait(0.25)
			var n1 := get_tree().get_nodes_in_group("aliens").size()
			if n1 > n0:
				waves += 1
				spawned += n1 - n0
		print("[autotest] hostility %.2f = %s: %d of 4 forced ambushes warned of, %d sent, %d aliens; next one in %.0f s" % [h,
			Mothership.HOSTILITY_STAGES[ship.hostility_stage()], warned, waves, spawned, m._director_t])
		_clear_aliens()
		await wait(0.2)
	ship.hostility = 0.62
	await wait(0.3)
	if shots:
		await shot("bl01_hostility_hud")
	# Waystation: landing resets the hostility; the shop door, the buyback counter.
	var st := m.cave.station(1)
	ship.gate_k = 0
	await _put_ship(m, float(st["s_entry"]) - 80.0, [float(st["s"])])
	ship.request_station.rpc_id(1, "pilot")
	await wait(0.6)
	ship.hostility = 0.8
	await _tap("land")
	var t0 := Time.get_ticks_msec()
	while ship.landing != Mothership.Dock.LANDED and Time.get_ticks_msec() - t0 < 60000:
		await wait(0.5)
		if ship.landing == Mothership.Dock.APPROACH and absf(ship.hostility - 0.8) > 0.01:
			print("[autotest] FAIL: hostility changed while docking: %.2f" % ship.hostility)
	await wait(0.6)
	print("[autotest] docked at %s: %s, hostility %.2f (%s), HUD '%s'" % [st["name"], ship.landing == Mothership.Dock.LANDED,
		ship.hostility, Mothership.HOSTILITY_STAGES[ship.hostility_stage()], m.hud._hostility_label.text])
	p.exit_station(true)
	await wait(0.3)
	var floor_y := StationBuilder.DECK_Y - StationBuilder.LAND_HEIGHT + 0.05
	for dir: float in [1.0, -1.0]:
		p.position = Vector3(0, floor_y, 17.6 if dir > 0.0 else 24.0)
		p.look_yaw = PI if dir > 0.0 else 0.0
		p.look_pitch = 0.0
		p.velocity = Vector3.ZERO
		p.reset_physics_interpolation()
		await wait(0.3)
		var lo := INF
		var hi := -INF
		Input.action_press("move_forward")
		for i in 120:
			await get_tree().physics_frame
			if absf(p.position.z - StationBuilder.FACADE_Z) < 1.0:
				lo = minf(lo, p.position.y)
				hi = maxf(hi, p.position.y)
		Input.action_release("move_forward")
		print("[autotest] walked %s the shop door: now z %.1f, height in the doorway %.3f .. %.3f (floor %.3f)" % [
			"in through" if dir > 0.0 else "out through", p.position.z, lo, hi, floor_y - 0.05])
	if shots:
		p.position = Vector3(0, floor_y, 25.0)
		p.look_yaw = 0.0
		p.look_pitch = 0.25
		p.reset_physics_interpolation()
		await wait(0.4)
		await shot("bl02_shop_door_inside")
		p.position = Vector3(0, floor_y, 15.0)
		p.look_yaw = PI
		p.look_pitch = 0.42
		p.reset_physics_interpolation()
		await wait(0.4)
		await shot("bl03_shop_door_outside")
		var counter := StationBuilder.SELL_SPOT - Vector3(0, StationBuilder.LAND_HEIGHT, 0)
		p.position = Vector3(1.2, floor_y, 21.2)
		p.reset_physics_interpolation()
		_face(p, counter + Vector3(0, 1.4, 0))
		await wait(0.4)
		await shot("bl03b_buyback_counter")
	# Buy a crate, carry it to the buyback counter and sell it.
	ship.credits = 3000
	var sale: SupplyCrate = null
	for c in ship.cargo_root.get_children():
		var crate := c as SupplyCrate
		if crate and crate.price > 0 and crate.item != "hull_kit":
			sale = crate
			break
	if sale:
		var price := sale.price
		print("[autotest] bought %s for %d: %s, picked up: %s" % [sale.item, price, await _buy(p, sale), await _pick_up(m, p, sale)])
		var spot := StationBuilder.SELL_SPOT - Vector3(0, StationBuilder.LAND_HEIGHT, 0)
		p.position = Vector3(spot.x, floor_y, spot.z - 1.6)
		p.velocity = Vector3.ZERO
		p.reset_physics_interpolation()
		await wait(0.3)
		_face(p, spot + Vector3(0, 0.9, 0))
		await wait(0.3)
		var prompt := p.prompt
		if shots:
			await shot("bl04_buyback")
		var c0 := ship.credits
		await _tap("interact")
		await wait(0.3)
		print("[autotest] buyback prompt '%s'; sold: %s, credits %d -> %d (+%d = %d%% of %d)" % [prompt, not is_instance_valid(sale),
			c0, ship.credits, ship.credits - c0, int(round(100.0 * (ship.credits - c0) / float(price))), price])
	else:
		print("[autotest] FAIL: nothing to buy in the shop")
	# Lift off, then land at an abandoned station: hostility holds there, flashlights, skitters.
	p.position = p.ship.spawn_points()[0]
	p.reset_physics_interpolation()
	await wait(0.3)
	var k := -1
	var d := {}
	for kk in 12:
		d = m.cave.derelict(kk)
		if not d.is_empty():
			k = kk
			break
	if k < 0:
		print("[autotest] FAIL: no abandoned station in this cave")
		return
	ship.landing = Mothership.Dock.FLYING
	ship.station_k = -1
	ship.gate_k = k
	ship.gate_entry = 0.0
	ship._exit_state = 3
	_clear_aliens()
	await _put_ship(m, float(d["s"]) - 70.0, [float(d["s"])])
	ship.request_station.rpc_id(1, "pilot")
	await wait(0.8)
	ship.hostility = 0.55
	# No landing with aliens close (that rule is tested in backlog2): clear any that came along.
	_clear_aliens()
	await wait(0.1)
	await _tap("land")
	t0 = Time.get_ticks_msec()
	while ship.landing != Mothership.Dock.LANDED and Time.get_ticks_msec() - t0 < 60000:
		await wait(0.5)
	await wait(4.0)
	print("[autotest] landed at %s: %s; hostility after 4 s down there %.2f (%s), HUD '%s'" % [d["name"],
		ship.landing == Mothership.Dock.LANDED, ship.hostility, Mothership.HOSTILITY_STAGES[ship.hostility_stage()], m.hud._hostility_label.text])
	# Clear the station's own aliens so only our test pack is about.
	for c in ship.boarder_root.get_children():
		c.queue_free()
	p.exit_station(true)
	await wait(0.3)
	print("[autotest] flashlight aboard: %s" % p._flash_on)
	var layout: Dictionary = d["layout"]
	var rooms: Array = layout["rooms"]
	var lift := Vector3(0, StationBuilder.LAND_HEIGHT, 0)
	var r0: Dictionary = rooms[0]
	var entry := _room_entry(d["layout"], r0) - lift
	p.position = Vector3(entry.x, floor_y, entry.z)
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()
	await wait(0.5)
	var c0v: Vector2 = r0["c"]
	_face(p, Vector3(c0v.x, floor_y + 1.0, c0v.y) - lift + lift)
	await wait(0.3)
	print("[autotest] flashlight out in the station: %s (aboard %s)" % [p._flash_on, ship.is_aboard(p.position)])
	if shots:
		await shot("bl05_flashlight")
		# A doorway from inside a room (the skirting band stops at the door frame).
		var dr: Dictionary = layout["doors"][(r0["doors"] as Array)[0]]
		var door_in := DerelictBuilder.door_inside(dr) - lift
		var c0p := Vector3(c0v.x, floor_y, c0v.y) - Vector3(0, 0, 0)
		p.position = c0p + (Vector3(door_in.x, floor_y, door_in.z) - c0p) * 0.2
		p.reset_physics_interpolation()
		await wait(0.2)
		_face(p, Vector3(door_in.x, floor_y + 0.3, door_in.z))
		p.look_pitch = -0.25
		await wait(0.4)
		await shot("bl06_room_door")
	# A pack of crawlers (they climb like the skitters they replaced) in the room furthest from the door:
	# let them settle, then go in.
	var far: Dictionary = rooms[int(layout["vault"])]
	var fc: Vector2 = far["c"]
	var pack: Array[Boarder] = []
	for i in 5:
		ship._boarder_seq += 1
		var b := ship.boarder_spawner.spawn({"name": "T%d" % ship._boarder_seq, "kind": "crawler",
			"pos": Vector3(fc.x - 2.0 + i * 1.0, floor_y - 0.05, fc.y), "hp": 9999.0, "max_hp": 9999.0, "dmg": 0.3, "outside": true}) as Boarder
		pack.append(b)
	await wait(9.0)
	print("[autotest] crawlers settled: %s" % _skitter_report(ship, pack, floor_y - 0.05))
	var fentry := _room_entry(layout, far) - lift
	p.position = Vector3(fentry.x, floor_y, fentry.z)
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()
	_face(p, Vector3(fc.x, floor_y + 2.0, fc.y))
	var hp0 := p.hp
	var seen := {}
	for i in 12:
		await wait(0.25)
		for b in pack:
			if is_instance_valid(b):
				seen[_surface_of(ship, b)] = int(seen.get(_surface_of(ship, b), 0)) + 1
		if i == 3 and shots:
			p.look_pitch = 0.45
			await shot("bl07_skitters")
	print("[autotest] crawlers chasing: %s; surfaces seen %s; crew hp %.0f -> %.0f (attacked: %s)" % [_skitter_report(ship, pack, floor_y - 0.05),
		seen, hp0, p.hp, p.hp < hp0])
	var b0: Boarder = pack[0]
	if is_instance_valid(b0):
		print("[autotest] crawler size: radius %.2f height %.2f" % [b0.stat("radius"), b0.stat("height")])
	# Back aboard: the flashlight goes off.
	p.position = p.ship.spawn_points()[0]
	p.reset_physics_interpolation()
	await wait(0.5)
	print("[autotest] flashlight back aboard: %s" % p._flash_on)


## Which surface a climbing alien clings to: "floor", "wall" or "ceiling".
static func _surface_of(ship: Mothership, b: Boarder) -> String:
	var up := ship.global_basis.inverse() * b.global_basis.y
	return "floor" if up.y > 0.7 else ("ceiling" if up.y < -0.7 else "wall")


static func _skitter_report(ship: Mothership, pack: Array[Boarder], floor_y: float) -> String:
	var out := PackedStringArray()
	for b in pack:
		if is_instance_valid(b):
			out.append("%s %.1f m up" % [_surface_of(ship, b), b.position.y - floor_y])
	return ", ".join(out)


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
	# The engine hum heard from around the ship: the first version (-8 dB, unit size 20, max +3 dB),
	# the second (-22 dB, unit size 9, max 0 dB, both from a point behind the reactor) and now (even
	# in the engine room, fading with distance from it; see Mothership.engine_hum_db).
	var hum := _stream_samples(Sfx.stream("engine_loop") as AudioStreamWAV)
	var blaster := _stream_samples(Sfx.stream("blaster") as AudioStreamWAV)
	var engine := Vector3(0, 1.5, 9.0)
	var room: Array = ShipInteriors.get_layout("prospector")["engine_room"]
	for spot: Array in [["engine room", Vector3(0, 1.6, 7.0)], ["install hub", ShipInteriors.get_layout("prospector")["hub"] + Vector3(0.8, 1.6, 0)],
			["mid-ship hall", Vector3(0, 1.6, 0.8)], ["gun window", Vector3(-4.75, 1.6, -2.5)], ["cockpit", Vector3(0, 1.6, -8.5)],
			["knocked-out chase camera", Vector3(0, 12.0, 38.0)]]:
		var ear: Vector3 = spot[1]
		var dist := ear.distance_to(engine)
		print("[autotest] engine hum at the %s (%.0f m): first %.1f dB, second %.1f dB, now %.1f .. %.1f dB (idle .. full throttle)" % [spot[0], dist,
			_loudness(hum, -8.0, 20.0, 3.0, dist), _loudness(hum, -22.0, 9.0, 0.0, dist),
			_rms_db(hum) + Mothership.engine_hum_db(room, ear, 0.0), _rms_db(hum) + Mothership.engine_hum_db(room, ear, 1.0)])
	print("[autotest] for comparison: your own blaster shot %.1f dB, a mining laser at its console %.1f dB" % [
		_loudness(blaster, -5.0, 14.0, 3.0, 0.8), _loudness(cur, -13.0, 8.0, 3.0, 1.0)])


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


## Close-ups of the Blender-made assets (tools/blender): the Prospector's hull, a gun pod outside and
## from the gunner's seat, and the Pulse Rifle, in a plain studio light (windowed).
func _run_assets() -> void:
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
	cam.near = 0.02
	world.add_child(cam)
	cam.current = true
	var views := {
		"prospector_front": [Vector3(-22, 10, -26), Vector3(0, 1.0, -2.0)],
		"prospector_rear": [Vector3(20, 8, 30), Vector3(0, 1.0, 2.0)],
		"prospector_side": [Vector3(-34, 3, 0), Vector3(0, 1.0, 0)],
		"prospector_top": [Vector3(6, 30, 8), Vector3(0, 1.0, 0)],
		"prospector_pod": [Vector3(-15.5, 4.5, -10.5), Vector3(-9.5, 1.2, -5.0)],
		"prospector_engines": [Vector3(9, 4, 22), Vector3(3, 1.5, 11)],
		"prospector_hull": [Vector3(-12.5, 4.0, 2.0), Vector3(-7.0, 2.5, 2.0)],
	}
	var ship := Node3D.new()
	world.add_child(ship)
	var parts := ShipBuilder.build_exterior(ship, "prospector")
	(parts["engine_glow_mat"] as StandardMaterial3D).albedo_color = Color(0.5, 0.9, 1.2)
	for tur: Turret in (parts["turrets"] as Dictionary).values():
		tur.set_aim(Vector2(0.35, 0.12))
	for v: String in views:
		cam.global_position = views[v][0]
		cam.look_at(views[v][1])
		await wait(0.3)
		await shot("asset_" + v)
	ship.queue_free()
	await wait(0.1)
	# A gun pod on its own.
	var t := ShipTypes.get_type("prospector")
	var pod := GunPod.new()
	pod.paint = t["paint"]
	pod.accent = t["accent"]
	world.add_child(pod)
	pod.build(t["by_id"]["gun_l"])
	pod.set_aim(Vector2(0.25, 0.1))
	for v: Array in [["pod_front", Vector3(-2.2, 1.2, -4.2), Vector3(0, 0, -0.4)], ["pod_rear", Vector3(3.0, 1.6, 3.2), Vector3(0, 0, 0)],
			["pod_side", Vector3(-4.2, 0.4, -0.6), Vector3(0, 0, -0.6)], ["pod_barrel", Vector3(-2.1, 0.5, -2.2), Vector3(-1.1, 0.0, -1.6)]]:
		cam.global_position = v[1]
		cam.look_at(v[2])
		await wait(0.3)
		await shot("asset_" + str(v[0]))
	cam.fov = 75.0
	cam.global_transform = pod.eye.global_transform
	await wait(0.3)
	await shot("asset_pod_gunner")
	cam.global_transform = pod.eye.global_transform * Transform3D(Basis(Vector3.UP, 0.9) * Basis(Vector3.RIGHT, -0.25), Vector3.ZERO)
	await wait(0.2)
	await shot("asset_pod_gunner_left")
	pod.queue_free()
	await wait(0.1)
	# The Pulse Rifle.
	cam.fov = 40.0
	var holder := Node3D.new()
	world.add_child(holder)
	CrewWeapons.build_model(holder, "rifle", Color(0.3, 0.8, 1.0), false)
	for v: Array in [["rifle_side", Vector3(1.15, 0.05, -0.1), Vector3(0, 0, -0.1)], ["rifle_front", Vector3(0.75, 0.35, -0.95), Vector3(0, 0, -0.1)],
			["rifle_rear", Vector3(-0.6, 0.3, 0.75), Vector3(0, 0.02, 0)], ["rifle_close", Vector3(0.32, 0.12, -0.12), Vector3(0, 0.03, -0.05)]]:
		cam.global_position = v[1]
		cam.look_at(v[2])
		await wait(0.3)
		await shot("asset_" + str(v[0]))
	holder.queue_free()


## Decals (Marks, ShipMarks): every mothership's markings, grime and wear under a plain studio
## light, battle damage of each kind on the Prospector's hull (fresh, then nearly faded, then gone,
## and the cap), and in a real mission the mining laser burning a trail across the rock and hits
## landing on the bare hull. `shots`: windowed screenshots ("decals"); without, numbers only
## ("decals_check", headless).
func _run_decals(shots: bool) -> void:
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
	# Every ship's painted markings, grime and wear: how many, all with a texture, all on the hull.
	for id: String in ShipTypes.ORDER:
		var ship := Node3D.new()
		world.add_child(ship)
		var parts := ShipBuilder.build_exterior(ship, id)
		var t := ShipTypes.get_type(id)
		var decals: Array[Decal] = []
		for c in ship.get_children():
			if c is Decal:
				decals.append(c)
		var missing := 0
		var worst := 0.0
		var worst_tex := ""
		for d in decals:
			if d.texture_albedo == null:
				missing += 1
			var s := ShipMarks.surface(t, d.position)
			if not s.is_empty():
				var off := (s[0] as Vector3).distance_to(d.position)
				if off > worst:
					worst = off
					worst_tex = d.texture_albedo.resource_path.get_file() if d.texture_albedo else "?"
		var layered := 0
		for c in ship.get_children():
			if c is GeometryInstance3D and ((c as GeometryInstance3D).layers & Game.VIS_HULL):
				layered += 1
		print("[autotest] %s: %d decals (%d without a texture), farthest from the hull %.2f m (%s); %d hull meshes take decals" % [id, decals.size(),
			missing, worst, worst_tex, layered])
		(parts["engine_glow_mat"] as StandardMaterial3D).albedo_color = Color(0.5, 0.9, 1.2)
		if shots:
			var r := float(t.get("chase", 40.0)) * 0.95
			for v: Array in [["front", Vector3(-0.62, 0.42, -0.66), Vector3(0, 1.0, -1.5)], ["rear", Vector3(0.6, 0.36, 0.72), Vector3(0, 1.0, 1.5)],
					["side", Vector3(1.0, 0.1, -0.05), Vector3(0, 1.2, 0)], ["top", Vector3(0.12, 1.0, 0.3), Vector3(0, 1.0, 0)],
					["below", Vector3(-0.4, -0.6, -0.55), Vector3(0, 0.0, 0)]]:
				cam.global_position = (v[1] as Vector3).normalized() * r + Vector3(0, 1.5, -1.5)
				cam.look_at(v[2], Vector3.UP if absf((v[1] as Vector3).normalized().y) < 0.95 else Vector3.FORWARD)
				await wait(0.25)
				await shot("dc_%s_%s" % [id, v[0]])
		if id == "prospector" and shots:
			for v: Array in [["name", Vector3(-17, 2.5, 5.0), Vector3(-7.4, 1.9, 4.5)], ["roof", Vector3(4, 13, 6), Vector3(0, 4.7, -2.0)],
					["stern", Vector3(4, 4.5, 21), Vector3(0, 2.6, 11.8)], ["belly", Vector3(5, -9, -6), Vector3(0, -1.9, -1.0)],
					["bow", Vector3(-12, 3.5, -12), Vector3(-4.4, 2.0, -8.6)]]:
				cam.global_position = v[1]
				cam.look_at(v[2])
				await wait(0.25)
				await shot("dc_prospector_%s" % v[0])
		if id == "prospector":
			await _decal_damage(ship, t, cam, shots)
		ship.queue_free()
		await wait(0.1)
	world.queue_free()
	await wait(0.2)
	await _decal_mission(shots)


## Battle damage on a studio Prospector: each kind, a merge, fading, the cap.
func _decal_damage(ship: Node3D, t: Dictionary, cam: Camera3D, shots: bool) -> void:
	var marks := Marks.new()
	marks.cap = ShipMarks.DAMAGE_CAP
	ship.add_child(marks)
	var hits := [["spit", Vector3(-7.6, 2.4, 1.0)], ["spit", Vector3(-7.6, 0.6, 3.2)], ["spit", Vector3(-5.5, 4.9, -3.0)],
		["scratch", Vector3(-7.6, 1.2, -0.2)], ["impact", Vector3(-7.6, 2.2, 6.0)], ["scrape", Vector3(-7.6, -0.4, -1.0)],
		["scrape", Vector3(-7.6, -0.4, -0.6)], ["scrape", Vector3(-7.6, -0.4, 2.6)], ["spit", Vector3(-7.6, 2.4, 1.1)]]
	for h: Array in hits:
		ShipMarks.damage(marks, t, h[0], h[1])
	var glowing := 0
	for d: Decal in marks.find_children("*", "Decal", false, false):
		if d.emission_energy > 0.0:
			glowing += 1
	print("[autotest] damage: %d hits -> %d marks (repeat hits on one spot freshen the mark there), %d glowing" % [hits.size(), marks.count(), glowing])
	if shots:
		cam.global_position = Vector3(-16, 3.0, 2.0)
		cam.look_at(Vector3(-7.4, 1.4, 2.0))
		await wait(0.3)
		await shot("dc_damage_fresh")
	marks._process(4.0)
	var glow_left := 0.0
	for d: Decal in marks.find_children("*", "Decal", false, false):
		glow_left = maxf(glow_left, d.emission_energy)
	marks._process(126.0)
	var alpha := 0.0
	for d: Decal in marks.find_children("*", "Decal", false, false):
		# (Marks past their time are freed at the end of the frame.)
		if not d.is_queued_for_deletion():
			alpha = maxf(alpha, d.modulate.a)
	print("[autotest] damage after 4 s: brightest glow %.2f (of %.1f); after 130 s: %d marks, most opaque %.2f" % [glow_left,
		float(ShipMarks.DAMAGE["spit"]["glow"]), marks.count(), alpha])
	if shots:
		await wait(0.2)
		await shot("dc_damage_faded")
	marks._process(60.0)
	print("[autotest] damage after 190 s: %d marks" % marks.count())
	for i in 70:
		ShipMarks.damage(marks, t, "spit", Vector3(-7.6, 0.8 + (i % 5) * 0.6, -5.5 + (i / 5) * 1.0))
	await get_tree().process_frame
	print("[autotest] damage cap: 70 hits far apart -> %d marks (cap %d)" % [marks.count(), ShipMarks.DAMAGE_CAP])
	marks.queue_free()


## In a mission: the mining laser sweeps across the rock, then the hull takes hits with the shield
## down.
func _decal_mission(shots: bool) -> void:
	var m := await _start_solo_mission()
	if m == null:
		print("[autotest] FAIL: no mission")
		return
	var ship := m.ship
	var p := m.local_player
	p.max_hp = 99999.0
	p.hp = 99999.0
	ship.max_hull = 99999.0
	ship.hull = 99999.0
	await _put_ship(m, 70.0)
	await wait(0.5)
	ship.request_station.rpc_id(1, "mining")
	await wait(0.5)
	print("[autotest] laser: station '%s'" % p.station)
	var cam := Camera3D.new()
	cam.fov = 55.0
	m.add_child(cam)
	Input.action_press("fire")
	var steps := 90
	for i in steps:
		var f := float(i) / steps
		p.station_aim = Vector2(lerpf(-0.55, 0.55, f), -0.62 + 0.12 * sin(f * TAU))
		await wait(0.04)
		if i == steps - 20 and shots:
			var end := ship.laser_end("mining")
			cam.global_position = ship.to_global(Vector3(3.5, 1.5, -15.5))
			cam.look_at(end)
			cam.current = true
			await shot("dc_laser_burning")
	var burns: Marks = ship._rock_marks
	var count := burns.count() if burns else 0
	var hot := 0
	if burns:
		for d: Decal in burns.find_children("*", "Decal", false, false):
			if d.emission_energy > 0.5:
				hot += 1
	Input.action_release("fire")
	print("[autotest] laser swept for %.1f s: %d burns on the rock, %d still glowing" % [steps * 0.04, count, hot])
	await wait(3.0)
	var warm := 0.0
	if burns:
		for d: Decal in burns.find_children("*", "Decal", false, false):
			warm = maxf(warm, d.emission_energy)
	print("[autotest] 3 s after: hottest burn glows %.2f (from %.1f)" % [warm, Mothership.BURN_GLOW])
	if shots and burns and count > 0:
		var mid := (burns.find_children("*", "Decal", false, false)[count / 2] as Decal).global_position
		cam.global_position = ship.to_global(Vector3(3.5, 1.5, -15.5))
		cam.look_at(mid)
		cam.current = true
		await wait(0.2)
		await shot("dc_laser_cooled")
	# Hits on the bare hull.
	ship.request_station.rpc_id(1, "")
	await wait(0.3)
	ship.shield = 0.0
	ship.shield_down = true
	ship.shield_reboot = 999.0
	var t := ShipTypes.get_type(ship.ship_type)
	var spots := [Vector3(-7.5, 2.2, -1.0), Vector3(-7.5, 0.4, 4.0), Vector3(-4.0, 4.8, 2.0), Vector3(7.5, 1.5, 6.5)]
	for i in spots.size():
		var s := ShipMarks.surface(t, spots[i])
		ship.apply_damage(12.0, ship.to_global((s[0] as Vector3) + (s[1] as Vector3) * 2.5), ["spit", "impact", "spit", "scratch"][i])
		await wait(0.12)
	await wait(0.2)
	print("[autotest] hull hits with the shield down: %d damage marks" % ship._damage_marks.count())
	if shots:
		cam.global_position = ship.to_global(Vector3(-17, 4, 3))
		cam.look_at(ship.to_global(Vector3(-7, 1.6, 1.5)))
		cam.current = true
		await wait(0.2)
		await shot("dc_hull_hits")
	cam.queue_free()


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


## Tunnel width and station fit over several seeds: the free space along the ship's flight line,
## every waystation's gates on the straightened centre line with its bulkheads sealing the tunnel
## (no open space around them), and the abandoned stations: placement between the waystations,
## hangar open from the tunnel to the pad, rooms carved out of the rock.
func _run_tunnels() -> void:
	for seed_i: int in [1, 7, 42, 1234, 99999]:
		var cave := CaveGen.new(seed_i)
		var clear_min := INF
		var clear_sum := 0.0
		var n := 0
		var s := 30.0
		while s < 2100.0:
			if not cave.near_station(s, 120.0):
				var free := -cave.sdf(cave.center3(s) + Vector3(0, -1.4, 0))
				clear_min = minf(clear_min, free)
				clear_sum += free
				n += 1
			s += 4.0
		print("[autotest] seed %d: free space around the flight line: min %.1f m, mean %.1f m (radius %.0f +- %.0f m)" % [seed_i,
			clear_min, clear_sum / n, CaveGen.TUNNEL_RADIUS, CaveGen.TUNNEL_RADIUS_VAR])
		for k in 4:
			var st := cave.station(k)
			var xf: Transform3D = st["xform"]
			var open_ok := true
			for z: float in [StationBuilder.ENTRY_FACE + 40.0, StationBuilder.ENTRY_FACE + 4.0, 0.0, StationBuilder.EXIT_FACE - 4.0, StationBuilder.EXIT_FACE - 40.0]:
				if cave.sdf(xf * Vector3(0, StationBuilder.LINE_Y, z)) > -4.0:
					open_ok = false
			var leaks := 0
			var margin := INF
			for z: float in [(StationBuilder.EXIT_FACE + StationBuilder.EXIT_INNER) * 0.5, (StationBuilder.FACADE_Z + StationBuilder.ENTRY_FACE) * 0.5]:
				var x := -45.0
				while x <= 45.0:
					var y := -25.0
					while y <= 60.0:
						var d := cave.sdf(xf * Vector3(x, y, z))
						var in_wall := absf(x) < StationBuilder.WALL_X and y > StationBuilder.WALL_Y0 and y < StationBuilder.WALL_Y1
						if d < 0.0:
							if not in_wall:
								leaks += 1
							else:
								margin = minf(margin, minf(StationBuilder.WALL_X - absf(x), minf(y - StationBuilder.WALL_Y0, StationBuilder.WALL_Y1 - y)))
						y += 1.0
					x += 1.0
			print("[autotest]   waystation %d at %.0f m: gate line open %s, open space around the bulkheads %d points (%s), closest open point %.1f m inside the wall edge" % [
				k, st["s"], open_ok, leaks, "sealed" if leaks == 0 else "LEAK", margin])
		for k in 5:
			var dr := cave.derelict(k)
			if dr.is_empty():
				print("[autotest]   stretch after waystation %d: no abandoned station" % k)
				continue
			var dxf: Transform3D = dr["xform"]
			var hangar_ok := true
			for z: float in [-float(dr["depth"]) + 3.0, -14.0, -6.0, 0.0, 8.0, 14.0]:
				for x: float in [-12.0, 0.0, 12.0]:
					if cave.sdf(dxf * Vector3(x, 7.2, z)) > -1.0:
						hangar_ok = false
			var layout: Dictionary = dr["layout"]
			var carved := 0
			for room: Dictionary in layout["rooms"]:
				var c: Vector2 = room["c"]
				if cave.sdf(dxf * Vector3(c.x, StationBuilder.DECK_Y + 2.0, c.y)) < -1.0:
					carved += 1
			var to_prev := float(dr["s"]) - float(cave.station(k)["s_exit"])
			var to_next := float(cave.station(k + 1)["s_entry"]) - float(dr["s"])
			var props := 0
			var spots := 0
			for room: Dictionary in layout["rooms"]:
				props += (room["props"] as Array).size()
				spots += (room["spots"] as Array).size()
			print("[autotest]   abandoned station %d '%s' at %.0f m on the %s wall (%.0f m after waystation %d, %.0f m before the next): %d rooms (%d carved out), %d corridors, vault room %d, %d props, %d salvage spots, hangar open: %s" % [
				k, dr["name"], dr["s"], "right" if float(dr["side"]) > 0.0 else "left", to_prev, k, to_next, (layout["rooms"] as Array).size(),
				carved, (layout["corridors"] as Array).size(), layout["vault"], props, spots, hangar_ok])


## Stand `dist` metres from a crate, on the side facing `toward` (ship-local), and look at it.
func _stand_near(p: CrewMember, crate: SupplyCrate, toward: Vector3, floor_y: float, dist := 1.25) -> void:
	var flat := Vector3(crate.net_pos.x, 0, crate.net_pos.z)
	var away := flat.direction_to(Vector3(toward.x, 0, toward.z))
	if away.length_squared() < 0.01:
		away = Vector3.FORWARD
	p.position = Vector3(flat.x, floor_y, flat.z) + away * dist
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()
	await wait(0.35)
	_face(p, crate.net_pos)
	await wait(0.25)


func _hostile_report(ship: Mothership) -> String:
	var counts := {}
	for c in ship.boarder_root.get_children():
		var b := c as Boarder
		if b and b.outside:
			counts[b.kind] = int(counts.get(b.kind, 0)) + 1
	return str(counts)


## Abandoned stations: the HUD marker, landing (optional; side-on into the hangar, nose out), the
## salvage and hostiles in the rooms, walking in, bots following the host, clearing the rooms with
## hand weapons while the aliens fight back, swapping weapons at a crate with F, carrying salvage
## aboard and fitting it, and lifting off (what is left stays in the station).
func _run_derelict() -> void:
	Game.bot_count = 2
	var m := await _start_solo_mission()
	Game.bot_count = 0
	if m == null:
		print("[autotest] FAIL: mission not ready")
		return
	var ship := m.ship
	var p := m.local_player
	# A sturdy crew for the test (crew health follows the ship's crew stat).
	var tough := ship.stats.duplicate()
	tough["crew_hp"] = 1500.0
	ship.stats = tough
	var k := -1
	var d := {}
	for kk in 10:
		d = m.cave.derelict(kk)
		if not d.is_empty():
			k = kk
			break
	if k < 0:
		print("[autotest] FAIL: no abandoned station in this cave")
		return
	var xf: Transform3D = d["xform"]
	var layout: Dictionary = d["layout"]
	var rooms: Array = layout["rooms"]
	print("[autotest] abandoned station %d '%s' at %.0f m: %d rooms, vault %d, side %+.0f, pad %s" % [k, d["name"], d["s"], rooms.size(),
		layout["vault"], d["side"], xf.origin])
	# The abandoned station is in the stretch after waystation k: pretend the crew came through it.
	ship.gate_k = k
	ship.gate_entry = 0.0
	ship._exit_state = 3
	await _put_ship(m, float(d["s"]) - 70.0, [float(d["s"])])
	ship.request_station.rpc_id(1, "pilot")
	await wait(1.0)
	print("[autotest] marker: '%s' (visible %s); pilot info: %s" % [m.hud._derelict_marker.text.replace("\n", " | "),
		m.hud._derelict_marker.visible, " | ".join(m.ship.pilot_status())])
	await shot("dr01_approach")
	# No landing with aliens close (that rule is tested in backlog2): clear any that came along.
	_clear_aliens()
	await wait(0.1)
	await _tap("land")
	print("[autotest] landing state after L: %d (derelict %d)" % [ship.landing, ship.derelict_k])
	var t0 := Time.get_ticks_msec()
	var shot_dock := false
	while ship.landing != Mothership.Dock.LANDED and Time.get_ticks_msec() - t0 < 50000:
		await wait(0.5)
		if not shot_dock and ship._dock_keys.size() <= 2:
			shot_dock = true
			await shot("dr02_docking")
	var pad := xf * Vector3(0, StationBuilder.LAND_HEIGHT, 0)
	print("[autotest] landed: %s after %.1f s, error %.2f m, nose out: %.2f (1 = facing the tunnel), hull %.0f" % [
		ship.landing == Mothership.Dock.LANDED, (Time.get_ticks_msec() - t0) / 1000.0, ship.global_position.distance_to(pad),
		(-ship.global_basis.z).dot(-xf.basis.z), ship.hull])
	await wait(3.0)
	var crate_items := PackedStringArray()
	for c in ship.cargo_root.get_children():
		crate_items.append((c as SupplyCrate).item)
	print("[autotest] salvage: %s | hostiles: %s (%d) | ramp %.2f | status '%s'" % [", ".join(crate_items), _hostile_report(ship),
		ship.hostiles, ship.ramp, m.hud._dock_status.text])
	await shot("dr03_landed")
	# Free camera views of the hangar, the front wall and the rooms.
	var cam := Camera3D.new()
	cam.far = 600.0
	m.add_child(cam)
	var vault: Dictionary = rooms[int(layout["vault"])]
	var r0: Dictionary = rooms[0]
	var views: Array = [
		["dr04_hangar", Vector3(14.0, 12.0, -float(d["depth"]) + 6.0), Vector3(0, 5.0, 8.0)],
		["dr05_facade", Vector3(9.5, 9.0, 13.5), Vector3(-1.0, 4.5, DerelictBuilder.FACADE_Z)],
	]
	for room: Dictionary in [r0, vault]:
		var c: Vector2 = room["c"]
		var size: Vector2 = room["size"]
		views.append(["dr06_room%d" % rooms.find(room), Vector3(c.x - size.x * 0.42, StationBuilder.DECK_Y + 2.6, c.y - size.y * 0.42),
			Vector3(c.x + size.x * 0.2, StationBuilder.DECK_Y + 1.0, c.y + size.y * 0.2)])
	for v: Array in views:
		cam.global_position = xf * (v[1] as Vector3)
		cam.look_at(xf * (v[2] as Vector3))
		cam.current = true
		await wait(0.3)
		await shot(v[0])
	cam.queue_free()
	p.camera.current = true
	# Walk down the ramp, along the pier and in through the door.
	p.exit_station(true)
	await wait(0.3)
	p.position = Vector3(0, 0.05, 10.6)
	p.look_yaw = PI
	p.look_pitch = -0.05
	p.reset_physics_interpolation()
	await wait(0.3)
	Input.action_press("move_forward")
	await wait(2.0)
	await shot("dr07_pier")
	await wait(2.4)
	Input.action_release("move_forward")
	await wait(0.4)
	print("[autotest] walked to %s: inside the station %s, aboard %s, crew outside '%s'" % [p.position.snapped(Vector3.ONE * 0.1),
		p.position.z > DerelictBuilder.FACADE_Z, p.ship.is_aboard(p.position), ship.crew_outside()])
	await shot("dr08_inside")
	await wait(4.0)
	var follow := PackedStringArray()
	for c in ship.crew_root.get_children():
		var cm := c as CrewMember
		if cm.bot:
			follow.append("%s following=%s %.1f m from the host" % [cm.display_name, cm.brain.following, cm.position.distance_to(p.position)])
	print("[autotest] bots: ", ", ".join(follow))
	# Clear the rooms: walk into each one (nearest first) and shoot whatever is there.
	var lift := Vector3(0, StationBuilder.LAND_HEIGHT, 0)
	var floor_y := StationBuilder.DECK_Y - StationBuilder.LAND_HEIGHT + 0.05
	var kills0 := m.kills
	var bot_kills0 := 0
	var taken := 0.0
	var last_hp := p.hp
	var weapons := ["pistol", "rifle", "shotgun", "marksman", "smg"]
	var fight_shot := false
	for idx in rooms.size():
		var room: Dictionary = rooms[idx]
		var entry := _room_entry(layout, room) - lift
		p.position = Vector3(entry.x, floor_y, entry.z)
		p.reset_physics_interpolation()
		p.set_weapon(weapons[idx % weapons.size()])
		ship._crew_weapons[1] = p.weapon
		await wait(0.4)
		var rt := Time.get_ticks_msec()
		var quiet := 0.0
		var hostiles_before := ship.hostiles
		while Time.get_ticks_msec() - rt < 12000 and quiet < 2.5:
			taken += maxf(0.0, last_hp - p.hp)
			last_hp = p.hp
			var foe := _nearest_hostile(ship, p, 18.0)
			if foe == null:
				Input.action_release("fire")
				quiet += 0.25
				await wait(0.25)
				continue
			quiet = 0.0
			if p.ammo <= 0 and not p.reloading:
				Input.action_release("fire")
				await _tap("reload")
				# (It may have died meanwhile, to the bots.)
				if not is_instance_valid(foe):
					continue
			_face(p, foe.position + Vector3(0, foe.stat("height") * 0.55, 0))
			Input.action_press("fire")
			await wait(0.12)
			if not fight_shot and idx > 0 and is_instance_valid(foe) and foe.position.distance_to(p.position) < 9.0:
				fight_shot = true
				await shot("dr09_fight")
		Input.action_release("fire")
		print("[autotest]   room %d %s with the %s: hostiles %d -> %d, player hp %.0f, bots %s" % [idx, room["name"],
			CrewWeapons.display_name(p.weapon), hostiles_before, ship.hostiles, p.hp,
			", ".join(ship.crew_root.get_children().filter(func(c): return c.bot).map(func(c): return "%s %.0f m%s" % [c.display_name,
				c.position.distance_to(p.position), " FIGHTING" if c.brain.is_fighting() else ""]))])
	print("[autotest] cleared: kills %d -> %d, hostiles left %d (%s), player took %.0f damage, alive %s | %s" % [kills0, m.kills, ship.hostiles,
		_hostile_report(ship), taken, p.alive, _bot_report(m)])
	# Swap hand weapons at a crate with F.
	p.set_weapon(CrewWeapons.DEFAULT)
	ship._crew_weapons.erase(1)
	var wc: SupplyCrate = null
	for c in ship.cargo_root.get_children():
		var crate := c as SupplyCrate
		if RunItems.is_crew_weapon(crate.item):
			wc = crate
	if wc == null:
		var spot := Vector3(r0["c"].x, StationBuilder.DECK_Y + SupplyCrate.SIZE.y * 0.5, r0["c"].y) - lift
		ship.cargo_spawner.spawn({"name": "CW1", "item": "crew:rifle", "price": 0, "pos": spot, "yaw": 0.0})
		await wait(0.3)
		wc = ship.cargo_root.get_node("CW1") as SupplyCrate
	await _stand_near(p, wc, _room_center_near(rooms, wc.net_pos), floor_y)
	var want := RunItems.crew_weapon_of(wc.item)
	print("[autotest] at the weapon crate: prompt '%s'" % p.prompt)
	await shot("dr10_swap_prompt")
	await _tap("equip")
	await wait(0.4)
	print("[autotest] after F: weapon %s (wanted %s), crate now holds %s" % [p.weapon, want, wc.item])
	await shot("dr11_new_weapon")
	# Carry some salvage aboard and fit it.
	var loot: SupplyCrate = null
	for c in ship.cargo_root.get_children():
		var crate := c as SupplyCrate
		if not RunItems.is_crew_weapon(crate.item) and not RunItems.is_weapon(crate.item) and crate.item != "autocannon":
			loot = crate
	if loot:
		await _stand_near(p, loot, _room_center_near(rooms, loot.net_pos), floor_y)
		await _tap("interact")
		await wait(0.3)
		print("[autotest] picked up salvage %s: %s" % [loot.item, p.carrying == loot])
		p.position = Vector3(0, floor_y, 17.0)
		p.look_yaw = 0.0
		p.look_pitch = 0.0
		p.reset_physics_interpolation()
		Input.action_press("move_forward")
		await wait(2.4)
		await shot("dr12_carry")
		await wait(1.6)
		Input.action_release("move_forward")
		print("[autotest] carried it aboard: %s, hub prompt: '%s'" % [p.ship.is_aboard(p.position), await _install_at_hub(p)])
		print("[autotest] installed: %s, mods %s" % [not is_instance_valid(loot), ship.run_mods])
	# Back aboard: the bots come back, then lift off.
	p.position = p.ship.spawn_points()[0]
	p.reset_physics_interpolation()
	t0 = Time.get_ticks_msec()
	while ship.crew_outside() != "" and Time.get_ticks_msec() - t0 < 30000:
		await wait(0.5)
	print("[autotest] everyone aboard after %.1f s (outside: '%s') | %s" % [(Time.get_ticks_msec() - t0) / 1000.0, ship.crew_outside(), _bot_report(m)])
	ship.request_station.rpc_id(1, "pilot")
	await wait(0.4)
	await _tap("land")
	t0 = Time.get_ticks_msec()
	while ship.landing != Mothership.Dock.FLYING and Time.get_ticks_msec() - t0 < 30000:
		await wait(0.5)
	var state: Dictionary = ship._derelict_state.get(k, {})
	print("[autotest] flying again: %s after %.1f s, derelict_k %d, left in the station: %d crates, %d hostiles; nav points %d" % [
		ship.landing == Mothership.Dock.FLYING, (Time.get_ticks_msec() - t0) / 1000.0, ship.derelict_k,
		(state.get("crates", []) as Array).size(), (state.get("enemies", []) as Array).size(), ship.nav.get_point_count()])
	await wait(1.0)
	await shot("dr13_liftoff")
	_status(m)


## The station-local floor just inside a room's first doorway.
static func _room_entry(layout: Dictionary, room: Dictionary) -> Vector3:
	return DerelictBuilder.door_inside(layout["doors"][(room["doors"] as Array)[0]])


## Ship-local middle of the abandoned station room nearest to a ship-local point (ship landed).
func _room_center_near(rooms: Array, p: Vector3) -> Vector3:
	var best := Vector3.ZERO
	var best_d := INF
	for room: Dictionary in rooms:
		var c: Vector2 = room["c"]
		var q := Vector3(c.x, p.y, c.y)
		if q.distance_to(p) < best_d:
			best_d = q.distance_to(p)
			best = q
	return best


## The nearest alien in an abandoned station within `reach` that the player can see.
func _nearest_hostile(ship: Mothership, p: CrewMember, reach: float) -> Boarder:
	var best: Boarder = null
	var best_d := reach
	var space := p.get_world_3d().direct_space_state
	for c in ship.boarder_root.get_children():
		var b := c as Boarder
		if b == null or b.hp <= 0.0 or b.is_queued_for_deletion():
			continue
		var dist := b.position.distance_to(p.position)
		if dist >= best_d:
			continue
		var q := PhysicsRayQueryParameters3D.create(ship.to_global(p.position + Vector3(0, CrewMember.EYE, 0)),
			ship.to_global(b.position + Vector3(0, b.stat("height") * 0.5, 0)), Game.LAYER_STATION | Game.LAYER_INTERIOR)
		if not space.intersect_ray(q).is_empty():
			continue
		best_d = dist
		best = b
	return best


## Hand weapons against a line of boarders aboard (held still): damage each weapon deals in a few
## seconds (the semi-automatic ones clicked about seven times a second), the Marksman Rifle's rounds
## piercing the line, the grenades' blasts, the HUD label and the first-person models; then swapping
## weapons at a crate with F, and a crate holding a hand weapon at the install hub.
func _run_weapons() -> void:
	var m := await _start_solo_mission()
	if m == null:
		print("[autotest] FAIL: mission not ready")
		return
	var ship := m.ship
	var p := m.local_player
	p.max_hp = 99999.0
	p.hp = 99999.0
	var n := 0
	for w: String in CrewWeapons.ORDER:
		p.set_weapon(w)
		ship._crew_weapons[1] = w
		p.position = Vector3(0, 0.05, 4.2)
		p.look_yaw = 0.0
		p.reset_physics_interpolation()
		var line: Array[Boarder] = []
		for i in 3:
			n += 1
			ship.boarder_spawner.spawn({"name": "W%d" % n, "pos": Vector3(0.25 * (i - 1), 0.0, -1.0 - i * 1.4), "hp": 2000.0})
		await wait(0.2)
		for i in 3:
			var b := ship.boarder_root.get_node("W%d" % (n - 2 + i)) as Boarder
			b.set_physics_process(false)
			line.append(b)
		_face(p, line[0].position + Vector3(0, 0.9, 0))
		await wait(0.3)
		if CrewWeapons.exists(w):
			await shot("wp_%s" % w)
		# Three seconds on the trigger, reloading (R) whenever the magazine runs dry.
		var reloads := 0
		var t0 := Time.get_ticks_msec()
		var frame := 0
		while Time.get_ticks_msec() - t0 < 3000:
			_trigger(w, frame)
			frame += 1
			await get_tree().physics_frame
			if p.ammo <= 0 and not p.reloading and not CrewWeapons.uses_heat(w):
				reloads += 1
				p.start_reload()
		Input.action_release("fire")
		# (Grenades still in the air go off.)
		await wait(1.0 if w == "mgl" else 0.0)
		await wait(0.6)
		print("[autotest]   %s: magazine %d, %d reload%s in those 3 s" % [w, CrewWeapons.mag(w), reloads, "" if reloads == 1 else "s"])
		var hits := PackedStringArray()
		var total := 0.0
		for b in line:
			hits.append("%.0f" % (2000.0 - b.hp))
			total += 2000.0 - b.hp
		var d := CrewWeapons.def(w)
		print("[autotest] %s: %.0f damage in 3 s (%.0f/s; nominal %.0f/s per target) - per boarder [%s], HUD '%s'" % [CrewWeapons.display_name(w),
			total, total / 3.0, float(d["damage"]) * int(d["pellets"]) / maxf(float(d["cooldown"]), 8.0 / 60.0 if CrewWeapons.semi(w) else 0.0),
			", ".join(hits), m.hud._tool_label.text])
		for b in line:
			b.queue_free()
		await wait(0.2)
	# Swap at a crate with F (the old weapon goes into the crate).
	p.set_weapon(CrewWeapons.DEFAULT)
	ship._crew_weapons[1] = CrewWeapons.DEFAULT
	ship.cargo_spawner.spawn({"name": "CW9", "item": "crew:shotgun", "price": 0, "pos": Vector3(-2.5, 0.3, 7.5), "yaw": 0.0})
	await wait(0.3)
	var crate := ship.cargo_root.get_node("CW9") as SupplyCrate
	await _stand_near(p, crate, Vector3(0, 0, 7.5), 0.05)
	print("[autotest] prompt: '%s'" % p.prompt)
	await _tap("equip")
	await wait(0.4)
	print("[autotest] after F: weapon %s, crate holds %s, label '%s'" % [p.weapon, crate.item, crate._label.text])
	await _tap("equip")
	await wait(0.4)
	print("[autotest] F again: weapon %s, crate holds %s" % [p.weapon, crate.item])
	# Carry it to the install hub: refused.
	await _stand_near(p, crate, Vector3(0, 0, 7.5), 0.05)
	await _tap("interact")
	await wait(0.3)
	print("[autotest] carrying the weapon crate: %s, hub prompt '%s'" % [p.carrying == crate, await _install_at_hub(p)])
	print("[autotest] still carrying after E at the hub: %s, mods %s" % [p.carrying == crate, ship.run_mods])
	await shot("wp_hub_refused")


## Effective loudness (dB) of a looping stream for a listener `dist` metres away from a player with
## the given volume, unit size and max_db (inverse-distance attenuation, as Godot does it: the
## volume plus the attenuation, capped at max_db, so close to the source it gets louder than the
## volume itself).
func _loudness(smp: PackedFloat32Array, volume_db: float, unit: float, max_db: float, dist: float) -> float:
	return _rms_db(smp) + minf(volume_db + linear_to_db(1.0 / (dist / unit + 0.0001)), max_db)


static func _rms_db(smp: PackedFloat32Array) -> float:
	var sum := 0.0
	for v in smp:
		sum += v * v
	return linear_to_db(sqrt(sum / maxf(smp.size(), 1.0)))


static func _stream_samples(st: AudioStreamWAV) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(st.data.size() / 2)
	for i in out.size():
		out[i] = st.data.decode_s16(i * 2) / 32000.0
	return out


## Multiplayer abandoned station test, host side (run --autotest=join_derelict in a second
## instance): land at an abandoned station, leave a Marksman Rifle crate in the first room for the
## client, and report what the host sees of the client's weapon swap and fight.
func _run_host_derelict() -> void:
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
	for i in 900:
		await get_tree().process_frame
		m = Game.mission as MissionLevel
		if m and m.started and m.local_player:
			break
	var ship := m.ship
	var tough := ship.stats.duplicate()
	tough["crew_hp"] = 1500.0
	ship.stats = tough
	# The abandoned station may be deep down (they are 650 m apart): a sturdy ship survives the wait.
	ship.max_hull = 5000.0
	ship.hull = 5000.0
	var k := -1
	var d := {}
	for kk in 10:
		d = m.cave.derelict(kk)
		if not d.is_empty():
			k = kk
			break
	if k < 0:
		print("[autotest] FAIL: no abandoned station in this cave")
		return
	ship.gate_k = k
	ship.gate_entry = 0.0
	ship._exit_state = 3
	await _put_ship(m, float(d["s"]) - 60.0, [float(d["s"])])
	ship.request_station.rpc_id(1, "pilot")
	await wait(0.5)
	# No landing with aliens close (that rule is tested in backlog2): clear any that came along.
	_clear_aliens()
	await wait(0.1)
	await _tap("land")
	for i in 600:
		await wait(0.1)
		if ship.landing == Mothership.Dock.LANDED:
			break
	print("[autotest] host: landed at abandoned station %d (%.0f m): %s, hostiles %d (%s), hull %.0f" % [k, float(d["s"]),
		ship.landing == Mothership.Dock.LANDED, ship.hostiles, _hostile_report(ship), ship.hull])
	var r0: Dictionary = (d["layout"]["rooms"] as Array)[0]
	var lift := Vector3(0, StationBuilder.LAND_HEIGHT, 0)
	var c: Vector2 = r0["c"]
	ship.cargo_spawner.spawn({"name": "HX", "item": "crew:marksman", "price": 0,
		"pos": Vector3(c.x, StationBuilder.DECK_Y + SupplyCrate.SIZE.y * 0.5, c.y) - lift, "yaw": 0.0})
	await wait(0.3)
	var crate := ship.cargo_root.get_node("HX") as SupplyCrate
	var client_id := 0
	for id in Net.roster:
		if int(id) > 1:
			client_id = int(id)
	for i in 900:
		await wait(0.1)
		if i % 20 == 0 and is_instance_valid(ship):
			print("[autotest] host: t+%.0f s hull %.0f shield %.0f alive %s, aliens %d, latched %s" % [i * 0.1, ship.hull, ship.shield,
				ship.alive, get_tree().get_nodes_in_group("aliens").size(), get_tree().get_nodes_in_group("aliens").filter(func(a): return a.attached >= 0).size()])
		if not is_instance_valid(crate) or not is_instance_valid(ship) or not ship.alive or crate.item != "crew:marksman":
			break
	if not is_instance_valid(crate) or not is_instance_valid(ship) or not ship.alive:
		print("[autotest] FAIL: host: the swap crate is gone (ship valid %s, alive %s, ending %s)" % [is_instance_valid(ship),
			ship.alive if is_instance_valid(ship) else false, m.ending if is_instance_valid(m) else true])
		return
	var cm := ship.crew_root.get_node_or_null(str(client_id)) as CrewMember
	await wait(0.5)
	print("[autotest] host: crate now holds %s; the client's weapon as the host sees it: %s (server record %s)" % [crate.item,
		cm.weapon if cm else "?", ship.crew_weapon(client_id)])
	var kills0 := m.kills
	var hostiles0 := ship.hostiles
	for i in 400:
		await wait(0.1)
		if ship.crew_outside() == "" and i > 50:
			break
	print("[autotest] host: while the client was out: hostiles %d -> %d, kills %d -> %d, client hp %.0f / %.0f" % [hostiles0, ship.hostiles,
		kills0, m.kills, cm.hp if cm else -1.0, cm.max_hp if cm else -1.0])
	await _tap("land")
	for i in 400:
		await wait(0.1)
		if ship.landing == Mothership.Dock.FLYING:
			break
	print("[autotest] host: flying again=%s, derelict_k %d" % [ship.landing == Mothership.Dock.FLYING, ship.derelict_k])
	await wait(3.0)
	m.abort_mission()
	await wait(6.0)


## Multiplayer abandoned station test, client side: walk into the first room, swap weapons at the
## crate the host left there with F, fight the aliens that come, and go back aboard.
func _run_join_derelict() -> void:
	Net.local_name = "ClientScavenger"
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
	for i in 1200:
		await wait(0.1)
		if ship.landing == Mothership.Dock.LANDED and ship.derelict_k >= 0 and ship.ramp >= 1.0 and ship.cargo_root.has_node("HX"):
			break
	var d := m.cave.derelict(ship.derelict_k)
	var built := false
	for c in m.cave_root.get_children():
		if c.has_node("Derelict%d" % ship.derelict_k):
			built = true
	print("[autotest] client: landed at abandoned station %d: %s, built locally %s, hostiles %d, crates %d" % [ship.derelict_k,
		ship.landing == Mothership.Dock.LANDED, built, ship.hostiles, ship.cargo_root.get_child_count()])
	var rooms: Array = d["layout"]["rooms"]
	var lift := Vector3(0, StationBuilder.LAND_HEIGHT, 0)
	var floor_y := StationBuilder.DECK_Y - StationBuilder.LAND_HEIGHT + 0.05
	var entry := _room_entry(d["layout"], rooms[0]) - lift
	p.position = Vector3(entry.x, floor_y, entry.z)
	p.reset_physics_interpolation()
	await wait(0.5)
	var crate := ship.cargo_root.get_node("HX") as SupplyCrate
	await _stand_near(p, crate, _room_center_near(rooms, crate.net_pos) + Vector3(0, 0, -3.0), floor_y)
	print("[autotest] client: prompt at the crate: '%s'" % p.prompt)
	await _tap("equip")
	await wait(0.8)
	print("[autotest] client: weapon %s, crate holds %s, HUD '%s'" % [p.weapon, crate.item, m.hud._tool_label.text])
	await shot("net_derelict_client_swap")
	var hp_lost := 0.0
	var last := p.hp
	var t0 := Time.get_ticks_msec()
	var fired := 0
	while Time.get_ticks_msec() - t0 < 25000 and ship.hostiles > 0:
		hp_lost += maxf(0.0, last - p.hp)
		last = p.hp
		var foe := _nearest_hostile(ship, p, 20.0)
		if foe == null:
			Input.action_release("fire")
			await wait(0.25)
			continue
		if p.ammo <= 0 and not p.reloading:
			Input.action_release("fire")
			await _tap("reload")
			if not is_instance_valid(foe):
				continue
		_face(p, foe.position + Vector3(0, foe.stat("height") * 0.55, 0))
		Input.action_press("fire")
		fired += 1
		await wait(0.15)
	Input.action_release("fire")
	print("[autotest] client: fought for %.1f s (%d aim updates): hostiles left %d, hp lost %.0f, alive %s" % [
		(Time.get_ticks_msec() - t0) / 1000.0, fired, ship.hostiles, hp_lost, p.alive])
	p.position = p.ship.spawn_points()[1]
	p.reset_physics_interpolation()
	for i in 600:
		await wait(0.1)
		if ship.landing == Mothership.Dock.FLYING:
			break
	print("[autotest] client: ship flying again=%s" % (ship.landing == Mothership.Dock.FLYING))
	for i in 200:
		await wait(0.1)
		var lvl: Node = Game.main.current_level()
		if lvl and lvl.name == "Homebase":
			break
	print("[autotest] client: back at ", Game.main.current_level().name if Game.main.current_level() else "none")



## The second 2026-10-16 backlog round: the engine hum (even all over the engine room, fading with
## distance), reloading hand weapons, the waystation (the buyback counter facing the middle of the
## shop, no pillars across the gates, revolving warning beacons while the bulkhead doors move), and
## abandoned stations (no landing with aliens close, the cave's aliens leaving a landed ship alone,
## and the aliens inside going for crew bots as well as players). backlog2_check: no screenshots.
func _run_backlog2(shots: bool) -> void:
	Game.bot_count = 2
	var m := await _start_solo_mission()
	Game.bot_count = 0
	if m == null:
		print("[autotest] FAIL: mission not ready")
		return
	var ship := m.ship
	var tough := ship.stats.duplicate()
	tough["crew_hp"] = 99999.0
	ship.stats = tough
	ship.max_hull = 99999.0
	ship.hull = 99999.0
	await _bl2_hum(m)
	await _bl2_reload(m, shots)
	await _bl2_station(m, shots)
	await _bl2_derelict(m, shots)
	_status(m)


## Engine hum levels around every ship (from the formula), and the live player with the listener
## at the reactor, in a corner of the engine room and in the cockpit.
func _bl2_hum(m: MissionLevel) -> void:
	var ship := m.ship
	var p := m.local_player
	var hum := _stream_samples(Sfx.stream("engine_loop") as AudioStreamWAV)
	var rms := _rms_db(hum)
	var inner := ShipInteriors.get_layout("prospector")
	var room: Array = inner["engine_room"]
	var old_src := Vector3(0, 1.5, 9.0)
	for spot: Array in [["right by the reactor", Vector3(0, 1.6, 8.7)], ["engine room corner", Vector3(-5.6, 1.6, 5.5)],
			["engine room doorway", Vector3(0, 1.6, 5.3)], ["install hub", (inner["hub"] as Vector3) + Vector3(0.8, 1.6, 0)],
			["mid-ship hall", Vector3(0, 1.6, 0.8)], ["gun window", Vector3(-4.75, 1.6, -2.5)], ["cockpit", Vector3(0, 1.6, -8.5)],
			["knocked-out chase camera", Vector3(0, 12.0, 38.0)]]:
		var ear: Vector3 = spot[1]
		print("[autotest] hum %s: before %.1f .. %.1f dB, now %.1f .. %.1f dB (idle .. full throttle)" % [spot[0],
			_loudness(hum, -22.0, 9.0, 0.0, ear.distance_to(old_src)), _loudness(hum, -16.0, 9.0, 0.0, ear.distance_to(old_src)),
			rms + Mothership.engine_hum_db(room, ear, 0.0), rms + Mothership.engine_hum_db(room, ear, 1.0)])
	for id: String in ShipInteriors.LAYOUTS:
		var lay := ShipInteriors.get_layout(id)
		var r: Array = lay["engine_room"]
		var lo: Vector3 = r[0]
		var hi: Vector3 = r[1]
		var cores: Array = lay["cores"]
		var seat: Vector3 = ((lay["spots"] as Dictionary).values()[0] as Dictionary)["seat"]
		print("[autotest] hum in the %s (idle): engine room middle %.1f, corner %.1f, by a core %.1f, mid-ship %.1f, bridge %.1f dB" % [id,
			rms + Mothership.engine_hum_db(r, (lo + hi) * 0.5, 0.0), rms + Mothership.engine_hum_db(r, lo + Vector3(0.3, 1.6, 0.3), 0.0),
			rms + Mothership.engine_hum_db(r, (cores[0] as Vector3) + Vector3(0, 1.6, 0.8), 0.0),
			rms + Mothership.engine_hum_db(r, (lay["spawns"] as Array)[0] + Vector3(0, 1.5, 0), 0.0),
			rms + Mothership.engine_hum_db(r, seat + Vector3(0, 1.6, 0), 0.0)])
	var cam := Camera3D.new()
	m.add_child(cam)
	cam.current = true
	for ear: Vector3 in [Vector3(0, 1.6, 8.7), Vector3(-5.6, 1.6, 5.5), Vector3(0, 1.6, -8.5)]:
		cam.global_position = ship.to_global(ear)
		for i in 3:
			await get_tree().physics_frame
		var a := ship._engine_audio
		print("[autotest] live hum, listener at %s: player %.1f dB at %s, attenuation %s, playing %s" % [ear, a.volume_db,
			a.position.snapped(Vector3.ONE * 0.01), "off" if a.attenuation_model == AudioStreamPlayer3D.ATTENUATION_DISABLED else "ON", a.playing])
	cam.queue_free()
	p.camera.current = true


## Reloading: every weapon fires its magazine dry, the trigger then only clicks (no automatic
## reload), R reloads it in the weapon's time; switching to the toolkit cuts a reload short; a
## weapon out of a crate comes loaded.
func _bl2_reload(m: MissionLevel, shots: bool) -> void:
	var ship := m.ship
	var p := m.local_player
	if p.station != "":
		p.exit_station(true)
	p.position = ship.spawn_points()[0]
	p.look_yaw = 0.0
	p.look_pitch = 0.0
	p.tool = 0
	p.reset_physics_interpolation()
	await wait(0.4)
	print("[autotest] start of the dive: %s with %d / %d shots, HUD '%s'" % [p.weapon, p.ammo, CrewWeapons.mag(p.weapon), m.hud._tool_label.text])
	for w: String in CrewWeapons.ORDER:
		# (Heat weapons have no magazine: see the soldier test.)
		if CrewWeapons.uses_heat(w):
			continue
		p.set_weapon(w)
		ship._crew_weapons[1] = w
		await wait(0.5)
		var full := p.ammo
		var d := CrewWeapons.def(w)
		var fired := 0
		var last := p.ammo
		var t0 := Time.get_ticks_msec()
		var frame := 0
		while p.ammo > 0 and Time.get_ticks_msec() - t0 < (full * maxf(float(d["cooldown"]), 0.14) + 2.0) * 1000.0:
			_trigger(w, frame)
			frame += 1
			await get_tree().physics_frame
			if p.ammo < last:
				fired += last - p.ammo
				last = p.ammo
		var dry_s := (Time.get_ticks_msec() - t0) / 1000.0
		# Keep the trigger held a moment longer: nothing fires and nothing reloads by itself.
		Input.action_press("fire")
		await wait(0.8)
		Input.action_release("fire")
		var empty_label := m.hud._tool_label.text
		if shots and w == "pistol":
			await shot("b2_01_empty")
		await _tap("fire")
		var still := "ammo %d, reloading %s" % [p.ammo, p.reloading]
		await _tap("reload")
		var started := p.reloading
		var lead := p.reload_progress() * CrewWeapons.reload_time(w)
		var t1 := Time.get_ticks_msec()
		var mid := ""
		while p.reloading and Time.get_ticks_msec() - t1 < 6000:
			await get_tree().physics_frame
			if mid == "" and p.reload_progress() > 0.4:
				mid = m.hud._tool_label.text
				if shots and w == "pistol":
					await shot("b2_02_reloading")
		print("[autotest] %s: magazine %d, fired %d in %.2f s; held trigger + click on empty: %s, HUD '%s'; R -> reloading %s, done in %.2f s (nominal %.2f), mid-way '%s', now %d, HUD '%s'" % [
			CrewWeapons.display_name(w), full, fired, dry_s, still, empty_label, started, (Time.get_ticks_msec() - t1) / 1000.0 + lead,
			CrewWeapons.reload_time(w), mid, p.ammo, m.hud._tool_label.text])
	# Interrupting a reload.
	p.set_weapon("pistol")
	ship._crew_weapons[1] = "pistol"
	await wait(0.5)
	Input.action_press("fire")
	await wait(0.6)
	Input.action_release("fire")
	await wait(0.2)
	var part := p.ammo
	await _tap("reload")
	await wait(0.3)
	var was := p.reloading
	await _tap("tool_toolkit")
	await wait(0.2)
	print("[autotest] reload cut short by the toolkit: was reloading %s, now %s, ammo %d (was %d), HUD '%s'" % [was, p.reloading, p.ammo, part, m.hud._tool_label.text])
	await _tap("tool_blaster")
	await _tap("reload")
	await wait(CrewWeapons.reload_time("pistol") + 0.3)
	print("[autotest] reloaded again: ammo %d" % p.ammo)
	await _tap("reload")
	print("[autotest] R with a full magazine: reloading %s" % p.reloading)
	# A weapon out of a crate comes loaded.
	Input.action_press("fire")
	await wait(1.0)
	Input.action_release("fire")
	var before := p.ammo
	ship.cargo_spawner.spawn({"name": "RL1", "item": "crew:rifle", "price": 0, "pos": Vector3(-2.5, 0.3, 7.5), "yaw": 0.0})
	await wait(0.3)
	var crate := ship.cargo_root.get_node("RL1") as SupplyCrate
	await _stand_near(p, crate, Vector3(0, 0, 7.5), 0.05)
	await _tap("equip")
	await wait(0.4)
	print("[autotest] swapped a pistol with %d shots left for %s: %d / %d" % [before, p.weapon, p.ammo, CrewWeapons.mag(p.weapon)])
	await _tap("equip")
	await wait(0.4)
	print("[autotest] and back: %s %d / %d (the crate holds %s)" % [p.weapon, p.ammo, CrewWeapons.mag(p.weapon), crate.item])
	crate.queue_free()


## A free camera at station-local `from` looking at `to` (station transform `xf`).
func _bl2_view(m: MissionLevel, xf: Transform3D, from: Vector3, to: Vector3) -> Camera3D:
	var cam := Camera3D.new()
	cam.far = 600.0
	m.add_child(cam)
	cam.global_position = xf * from
	cam.look_at(xf * to)
	cam.current = true
	return cam


## Land at waystation 1: the entrance bulkhead's beacons turn while it seals and stop once it is
## shut; the buyback counter faces the middle of the shop and still buys crates; on liftoff the
## exit bulkhead's beacons turn while it opens.
func _bl2_station(m: MissionLevel, shots: bool) -> void:
	var ship := m.ship
	var p := m.local_player
	var st := m.cave.station(1)
	var xf: Transform3D = st["xform"]
	ship.gate_k = 0
	ship.gate_entry = 0.0
	ship._exit_state = 3
	await _put_ship(m, float(st["s_entry"]) - 80.0, [float(st["s"])])
	var ws := _waystation(m, 1)
	if ws == null:
		print("[autotest] FAIL: waystation 1 not built")
		return
	print("[autotest] waystation %s: beacons entry %d, exit %d; turning before landing: %s / %s" % [st["name"],
		(ws.doors["entry"]["beacons"] as Array).size(), (ws.doors["exit"]["beacons"] as Array).size(), ws.beacons_on("entry"), ws.beacons_on("exit")])
	if shots:
		var cam := _bl2_view(m, xf, Vector3(0, 16.0, StationBuilder.ENTRY_FACE + 40.0), Vector3(0, 16.0, StationBuilder.ENTRY_FACE))
		await wait(0.4)
		await shot("b2_03_entry_gate_outside")
		cam.queue_free()
		p.camera.current = true
	ship.request_station.rpc_id(1, "pilot")
	await wait(0.6)
	await _tap("land")
	var t0 := Time.get_ticks_msec()
	while ship.landing != Mothership.Dock.LANDED and Time.get_ticks_msec() - t0 < 60000:
		await wait(0.25)
	# The entrance seals behind the ship.
	var spin: Node3D = (ws.doors["entry"]["beacons"] as Array)[0]["spin"]
	var on_samples := 0
	var samples := 0
	var turned := 0.0
	var shot_taken := false
	var t1 := Time.get_ticks_msec()
	while ws.is_open("entry") > 0.001 and Time.get_ticks_msec() - t1 < 12000:
		# physics_frame comes before the nodes' physics step: one full step lies between two of them.
		await get_tree().physics_frame
		var a0 := spin.rotation.y
		await get_tree().physics_frame
		turned += absf(angle_difference(a0, spin.rotation.y))
		await wait(0.2)
		samples += 1
		if ws.beacons_on("entry"):
			on_samples += 1
		if shots and not shot_taken and ws.is_open("entry") < 0.6:
			shot_taken = true
			var cam := _bl2_view(m, xf, Vector3(-11.0, 17.0, 3.0), Vector3(-2.0, 17.0, StationBuilder.FACADE_Z))
			await wait(0.15)
			await shot("b2_04_entry_beacons")
			cam.global_position = xf * Vector3(9.0, 21.0, 9.0)
			cam.look_at(xf * Vector3(14.5, 24.0, StationBuilder.FACADE_Z))
			await wait(0.1)
			await shot("b2_05_beacon_close")
			cam.queue_free()
			p.camera.current = true
	var during := "%d of %d samples, spinning at %.1f rad/s" % [on_samples, samples, turned / maxf(samples, 1) * Engine.physics_ticks_per_second]
	await wait(Waystation.BEACON_LINGER + 0.5)
	print("[autotest] entrance sealing (%.1f s): beacons turning %s; after it shut: turning %s, lamp glow %.2f" % [
		(Time.get_ticks_msec() - t1) / 1000.0, during, ws.beacons_on("entry"), (ws.doors["entry"]["lamp"] as StandardMaterial3D).emission_energy_multiplier])
	if shots:
		var cam := _bl2_view(m, xf, Vector3(-13.0, 15.0, 2.0), Vector3(0, 14.0, StationBuilder.FACADE_Z))
		await wait(0.3)
		await shot("b2_06_entry_gate_hall")
		cam.global_position = xf * Vector3(12.0, 16.0, -4.0)
		cam.look_at(xf * Vector3(0, 15.0, StationBuilder.EXIT_INNER))
		await wait(0.3)
		await shot("b2_07_exit_gate_hall")
		cam.queue_free()
		p.camera.current = true
	# The buyback counter.
	p.exit_station(true)
	await wait(0.3)
	var floor_y := StationBuilder.DECK_Y - StationBuilder.LAND_HEIGHT + 0.05
	var pad: Area3D = null
	for c in ws.get_children():
		if c is Area3D and c.has_meta("sell_pad"):
			pad = c
	var spot := StationBuilder.SELL_SPOT - Vector3(0, StationBuilder.LAND_HEIGHT, 0)
	var to_mid := Vector3(-spot.x, 0, (StationBuilder.FACADE_Z + StationBuilder.ROOM_END) * 0.5 - StationBuilder.SELL_SPOT.z).normalized()
	print("[autotest] buyback counter faces %s (station-local; the middle of the shop is %s, the door -z)" % [
		(pad.basis * Vector3.FORWARD).snapped(Vector3.ONE * 0.01) if pad else Vector3.ZERO, to_mid.snapped(Vector3.ONE * 0.01)])
	if shots:
		p.position = Vector3(-1.5, floor_y, 26.5)
		p.reset_physics_interpolation()
		_face(p, spot + Vector3(0, 1.3, 0))
		await wait(0.4)
		await shot("b2_08_buyback_from_shop")
		p.position = Vector3(0, floor_y, 21.3)
		p.reset_physics_interpolation()
		_face(p, spot + Vector3(0, 1.2, 0))
		await wait(0.4)
		await shot("b2_09_buyback_from_door")
	ship.credits = 3000
	var sale: SupplyCrate = null
	for c in ship.cargo_root.get_children():
		var crate := c as SupplyCrate
		if crate and crate.price > 0 and crate.item != "hull_kit":
			sale = crate
			break
	if sale:
		var price := sale.price
		print("[autotest] bought %s for %d: %s, picked up: %s" % [sale.item, price, await _buy(p, sale), await _pick_up(m, p, sale)])
		p.position = Vector3(spot.x - 1.6, floor_y, spot.z)
		p.velocity = Vector3.ZERO
		p.reset_physics_interpolation()
		await wait(0.3)
		_face(p, spot + Vector3(0, 0.9, 0))
		await wait(0.3)
		var prompt := p.prompt
		if shots:
			await shot("b2_10_selling")
		var c0 := ship.credits
		await _tap("interact")
		await wait(0.3)
		print("[autotest] at the counter's front: prompt '%s'; sold %s, credits %d -> %d" % [prompt, not is_instance_valid(sale), c0, ship.credits])
	else:
		print("[autotest] FAIL: nothing to buy in the shop")
	# Liftoff: the exit bulkhead opens with its beacons turning.
	p.position = ship.spawn_points()[0]
	p.reset_physics_interpolation()
	await wait(0.3)
	t0 = Time.get_ticks_msec()
	while ship.crew_outside() != "" and Time.get_ticks_msec() - t0 < 20000:
		await wait(0.3)
	ship.request_station.rpc_id(1, "pilot")
	await wait(0.4)
	await _tap("land")
	if ship.landing == Mothership.Dock.LANDED:
		await _tap("land")
	var exit_on := 0
	var exit_samples := 0
	var exit_shot := false
	t0 = Time.get_ticks_msec()
	while ship.landing != Mothership.Dock.FLYING and Time.get_ticks_msec() - t0 < 60000:
		await wait(0.2)
		if ws.is_open("exit") > 0.02 and ws.is_open("exit") < 0.98:
			exit_samples += 1
			if ws.beacons_on("exit"):
				exit_on += 1
			if shots and not exit_shot and ws.is_open("exit") > 0.3:
				exit_shot = true
				var cam := _bl2_view(m, xf, Vector3(13.0, 10.0, -6.0), Vector3(4.0, 17.0, StationBuilder.EXIT_INNER))
				await wait(0.15)
				await shot("b2_11_exit_beacons")
				cam.queue_free()
				p.camera.current = true
	print("[autotest] liftoff: flying %s; exit bulkhead opening: beacons turning in %d of %d samples" % [ship.landing == Mothership.Dock.FLYING, exit_on, exit_samples])


## Abandoned station: refused with an alien close; a critter latched on lets go when landing
## starts and roams the tunnel, a spitter that turns up leaves the ship alone; the station's
## aliens go for the bots as well as the host; bots reload as they fight.
func _bl2_derelict(m: MissionLevel, shots: bool) -> void:
	var ship := m.ship
	var p := m.local_player
	var k := -1
	var d := {}
	for kk in 12:
		d = m.cave.derelict(kk)
		if not d.is_empty():
			k = kk
			break
	if k < 0:
		print("[autotest] FAIL: no abandoned station in this cave")
		return
	ship.landing = Mothership.Dock.FLYING
	ship.station_k = -1
	ship.gate_k = k
	ship.gate_entry = 0.0
	ship._exit_state = 3
	_clear_aliens()
	if p.station != "":
		p.exit_station(true)
	await _put_ship(m, float(d["s"]) - 70.0, [float(d["s"])])
	ship.request_station.rpc_id(1, "pilot")
	await wait(0.6)
	# An alien close by: no landing.
	var near := m.spawn_alien(Alien.Kind.SPITTER, ship.global_position + ship.global_basis * Vector3(0, 6.0, -35.0), 50.0, 1.0) as Alien
	await wait(0.6)
	var info := " | ".join(m.ship.pilot_status())
	var marker := m.hud._derelict_marker.text.replace("\n", " | ")
	await _tap("land")
	print("[autotest] alien %.0f m off: aliens_near %d, after L landing state %d (0 = flying); pilot info '%s'; marker '%s'" % [
		near.global_position.distance_to(ship.global_position), ship.aliens_near(Mothership.DERELICT_CLEAR_RANGE), ship.landing, info, marker])
	if shots:
		await shot("b2_12_too_close")
	near.queue_free()
	# A critter latches onto the hull.
	var hp0: Array = ship.hull_point(0)
	var critter := m.spawn_alien(Alien.Kind.CRITTER, ship.to_global((hp0[0] as Vector3) + (hp0[1] as Vector3) * 4.0), 1000.0, 1.0) as Alien
	var t0 := Time.get_ticks_msec()
	while critter.attached < 0 and Time.get_ticks_msec() - t0 < 8000:
		await wait(0.1)
	await wait(0.3)
	print("[autotest] critter latched: %s; aliens_near now %d; pilot info '%s'" % [critter.attached >= 0,
		ship.aliens_near(Mothership.DERELICT_CLEAR_RANGE), " | ".join(m.ship.pilot_status())])
	# Other aliens about (from the cave) would block the landing: only the latched critter stays.
	for a in get_tree().get_nodes_in_group("aliens"):
		if a != critter:
			a.queue_free()
	await wait(0.2)
	var hull0 := ship.hull
	await _tap("land")
	await wait(0.6)
	print("[autotest] landing at %s: state %d (1 = approach); critter attached %d, roaming %s, hull claims %s" % [d["name"], ship.landing,
		critter.attached, critter._roaming, ship._hull_claims])
	# A spitter turns up while the ship is coming in.
	var spitter := m.spawn_alien(Alien.Kind.SPITTER, ship.global_position + ship.global_basis * Vector3(10.0, 8.0, -24.0), 1000.0, 1.0) as Alien
	var spits := 0
	var relatched := false
	var far_crit := 0.0
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 70000:
		await wait(0.25)
		for s: Dictionary in m.projectiles._shots:
			if str(s["kind"]) == "spit":
				spits += 1
		if is_instance_valid(critter):
			relatched = relatched or critter.attached >= 0
			far_crit = maxf(far_crit, critter.global_position.distance_to(ship.global_position))
		if ship.landing == Mothership.Dock.LANDED and Time.get_ticks_msec() - t0 > 8000:
			break
	await wait(5.0)
	var crit_home := critter.home.distance_to(m.cave.center3(-critter.home.z)) if is_instance_valid(critter) else -1.0
	print("[autotest] landed %s; while landing and 5 s down: spit samples %d, critter re-latched %s, critter up to %.0f m from the ship (now %.0f m; its home %.1f m from the tunnel's centre line), spitter %.0f m off, hull %.0f -> %.0f" % [
		ship.landing == Mothership.Dock.LANDED, spits, relatched, far_crit,
		critter.global_position.distance_to(ship.global_position) if is_instance_valid(critter) else -1.0, crit_home,
		spitter.global_position.distance_to(ship.global_position) if is_instance_valid(spitter) else -1.0, hull0, ship.hull])
	if shots:
		var dxf: Transform3D = d["xform"]
		var cam := _bl2_view(m, dxf, Vector3(16.0, 12.0, -float(d["depth"]) + 8.0), Vector3(0, 4.0, 0))
		await wait(0.3)
		await shot("b2_13_landed_aliens_roam")
		cam.queue_free()
		p.camera.current = true
	# The station's aliens against the host and the bots: walk into the first room, let the bots
	# catch up, then set a pack loose between them.
	for c in ship.boarder_root.get_children():
		c.queue_free()
	if p.station != "":
		p.exit_station(true)
	await wait(0.3)
	var rooms: Array = d["layout"]["rooms"]
	var lift := Vector3(0, StationBuilder.LAND_HEIGHT, 0)
	var floor_y := StationBuilder.DECK_Y - StationBuilder.LAND_HEIGHT + 0.05
	var r0: Dictionary = rooms[0]
	var c0: Vector2 = r0["c"]
	var mid := Vector3(c0.x, floor_y, c0.y)
	var entry := _room_entry(d["layout"], r0) - lift
	p.position = Vector3(entry.x, floor_y, entry.z)
	p.reset_physics_interpolation()
	await wait(0.4)
	p.position = mid
	p.reset_physics_interpolation()
	var bots: Array[CrewMember] = []
	for c in ship.crew_root.get_children():
		if (c as CrewMember).bot:
			bots.append(c)
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 30000:
		await wait(0.5)
		var ok := true
		for b in bots:
			ok = ok and b.position.distance_to(p.position) < 7.0
		if ok:
			break
	await wait(1.0)
	var where := PackedStringArray()
	for b in bots:
		where.append("%s %.1f m from the host" % [b.display_name, b.position.distance_to(p.position)])
	print("[autotest] in room 0 (%s): %s" % [r0["name"], ", ".join(where)])
	var hp := {}
	var reloads := {}
	var was_reloading := {}
	for c in ship.crew_root.get_children():
		hp[c.name] = (c as CrewMember).hp
		reloads[c.name] = 0
		was_reloading[c.name] = false
	# The pack comes at the host from the far side of the room: the host is the nearest one to
	# all of them, the bots (who followed the host in) are further off.
	var pack: Array[Boarder] = []
	var away := (mid - Vector3(entry.x, floor_y, entry.z)).normalized()
	var spawn_at := mid + away * 2.8 + Vector3(0, -0.05, 0)
	var kinds := ["crawler", "crawler", "crawler", "crawler", "stalker", "spider"]
	for i in kinds.size():
		ship._boarder_seq += 1
		var b := ship.boarder_spawner.spawn({"name": "Q%d" % ship._boarder_seq, "kind": kinds[i],
			"pos": spawn_at + away.cross(Vector3.UP) * ((i % 3 - 1) * 0.9) + away * floorf(i / 3.0) * 0.9, "hp": 4000.0, "max_hp": 4000.0, "dmg": 0.4, "outside": true}) as Boarder
		pack.append(b)
	var targets := {}
	var fight_shot := false
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 16000:
		await wait(0.25)
		for b in pack:
			if not is_instance_valid(b) or b._target_id == 0:
				continue
			var who := instance_from_id(b._target_id) as CrewMember
			if who:
				var key := "%s -> %s" % [b.kind, "host" if not who.bot else "bot"]
				targets[key] = int(targets.get(key, 0)) + 1
		for c in ship.crew_root.get_children():
			var cm := c as CrewMember
			if cm.reloading and not bool(was_reloading[cm.name]):
				reloads[cm.name] = int(reloads[cm.name]) + 1
			was_reloading[cm.name] = cm.reloading
		if shots and not fight_shot and Time.get_ticks_msec() - t0 > 5000:
			fight_shot = true
			var cam := Camera3D.new()
			m.add_child(cam)
			cam.global_position = ship.to_global(mid + Vector3(-3.0, 2.6, -3.0))
			cam.look_at(ship.to_global(mid + Vector3(0, 0.8, 0)), ship.global_basis.y)
			cam.current = true
			await wait(0.1)
			await shot("b2_14_pack_vs_bots")
			cam.queue_free()
			p.camera.current = true
	var lost := PackedStringArray()
	for c in ship.crew_root.get_children():
		var cm := c as CrewMember
		lost.append("%s%s -%.0f hp, %d reloads (ammo %d)" % [cm.display_name, " [bot]" if cm.bot else "", float(hp[cm.name]) - cm.hp,
			int(reloads[cm.name]), cm.ammo])
	print("[autotest] pack of %d vs host + %d bots for 16 s: target samples %s" % [pack.size(), bots.size(), targets])
	print("[autotest] damage taken: %s" % ", ".join(lost))
	for b in pack:
		if is_instance_valid(b):
			b.queue_free()
	# Back aboard and away: the roaming critter comes for the ship again once it is out.
	p.position = ship.spawn_points()[0]
	p.reset_physics_interpolation()
	t0 = Time.get_ticks_msec()
	while ship.crew_outside() != "" and Time.get_ticks_msec() - t0 < 30000:
		await wait(0.5)
	ship.request_station.rpc_id(1, "pilot")
	await wait(0.4)
	await _tap("land")
	t0 = Time.get_ticks_msec()
	while ship.landing != Mothership.Dock.FLYING and Time.get_ticks_msec() - t0 < 40000:
		await wait(0.5)
	var back := false
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 10000 and is_instance_valid(critter):
		await wait(0.25)
		if critter.attached >= 0 or critter._claim >= 0:
			back = true
			break
	print("[autotest] flying again %s: the critter %s" % [ship.landing == Mothership.Dock.FLYING,
		"came back for the hull" if back else ("is gone" if not is_instance_valid(critter) else "is still roaming (%.0f m off)" % critter.global_position.distance_to(ship.global_position))])


## Gun pods (the 2026-10-17 backlog). First every ship's pods in a studio: barrels and receivers
## clear of the hull and of the pod's own tower over the whole aim range, the gunner's eye outside
## the hull, and views of them. Then the Prospector's port pod in a dive: the gunner's view from
## the pod's eye (no HUD crosshair or gun panel), the pod swinging after the aim, a spitter shot
## down, heat building up and firing hot into the weapon systems, cooling down, the belt running
## dry and a new one loading by itself, leaning into the sight, the weapon systems offline, and a
## crew bot gunner that never fires hot, seen in its pod from outside. gunpod_check: no shots.
func _run_gunpod(shots: bool) -> void:
	await _gp_studio(shots)
	Game.bot_count = 1
	var m := await _start_solo_mission()
	Game.bot_count = 0
	if m == null:
		print("[autotest] FAIL: mission not ready")
		return
	var ship := m.ship
	# Nothing but the guns may hurt the weapon systems: no hull damage spills into them.
	var tough := ship.stats.duplicate()
	tough["crew_hp"] = 99999.0
	tough["collateral"] = 0.0
	ship.stats = tough
	ship.max_hull = 99999.0
	ship.hull = 99999.0
	m._director_t = 99999.0
	await _put_ship(m, 60.0)
	_clear_aliens()
	# The bot waits its turn.
	var bot: CrewMember = null
	for c in ship.crew_root.get_children():
		var cm := c as CrewMember
		if cm and cm.bot:
			bot = cm
	if bot:
		bot.set_physics_process(false)
	await _gp_gunner(m, shots)
	await _gp_bot(m, bot, shots)
	_status(m)


## Every ship's gun pods in a studio: their clearances (see _gp_clearance) and, with shots, each
## pod from outside at rest and swung round, and the cabin from the gunner's eye.
func _gp_studio(shots: bool) -> void:
	Game.main.menu.hide()
	var world := Node3D.new()
	add_child(world)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.09, 0.1, 0.13)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.6, 0.7)
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	world.add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 50.0
	cam.near = 0.03
	world.add_child(cam)
	cam.current = true
	for id: String in ShipTypes.ORDER:
		var ship := Node3D.new()
		world.add_child(ship)
		var parts := ShipBuilder.build_exterior(ship, id)
		var t := ShipTypes.get_type(id)
		for g: String in t["guns"]:
			var pod: GunPod = parts["turrets"][g]
			var mount := str(t["by_id"][g].get("mount", "?"))
			var c := _gp_clearance(t, g, pod)
			var eye_out := -_hull_margin(t["sections"], float(t["chamfer"]), pod.transform * GunPod.EYE)
			print("[autotest] %s %s (%s pod on a %s): barrels and receivers clear the hull%s by %.2f m at worst (%s); the gunner's eye is %.2f m outside the hull" % [
				id, g, pod.style, mount, " and the tower arm" if mount == "tower" else "", c[0], c[1], eye_out])
			if not shots:
				continue
			var p := pod.position
			var fwd := -pod.transform.basis.z
			var side := fwd.cross(Vector3.UP).normalized()
			# "back": from above and behind, on the pod's side of the ship (never inside the hull).
			var out := signf(p.x) if absf(p.x) > 2.0 else 1.0
			for v: Array in [["front", fwd * 4.6 + side * 2.2 + Vector3(0, 1.2, 0), Vector2.ZERO],
					["back", Vector3(out * 2.6, 2.3, 4.8), Vector2.ZERO],
					["swung", fwd * 3.6 - side * 3.4 + Vector3(0, 0.6, 0), Vector2(pod.yaw_min * 0.8, 0.5)]]:
				pod.set_aim(v[2])
				cam.global_position = ship.to_global(p + (v[1] as Vector3))
				cam.look_at(ship.to_global(p))
				await wait(0.15)
				await shot("gp_%s_%s_%s" % [id, g, v[0]])
			pod.set_aim(Vector2.ZERO)
		if shots:
			var first: GunPod = parts["turrets"][t["guns"][0]]
			cam.fov = 74.0
			cam.global_transform = ship.global_transform * first.camera_local(Vector2.ZERO)
			await wait(0.15)
			await shot("gp_%s_cabin" % id)
			cam.fov = 50.0
		ship.queue_free()
		await wait(0.1)
	world.queue_free()
	await wait(0.2)


## Worst clearance (m) of a gun pod's barrels and receivers from its ship's hull, and from the arm
## of its tower mount, over the pod's whole aim range (negative: they clip into it), and where.
func _gp_clearance(t: Dictionary, g: String, pod: GunPod) -> Array:
	var sections: Array = ShipTypes.full_sections(t)
	var chamfer := float(t["chamfer"])
	var def: Dictionary = t["by_id"][g]
	var pts: Array = []
	for b: Vector3 in GunPod.BARRELS:
		for k in 9:
			pts.append([b + Vector3(0, 0, -GunPod.BARREL_LEN * k / 8.0), 0.075])
	for sx: float in [-1.0, 1.0]:
		for x: float in [1.15, 1.39]:
			for y: float in [-0.23, 0.23]:
				for z: float in [-0.5, 0.4]:
					pts.append([Vector3(sx * x, y, z), 0.0])
	var arm := AABB()
	if str(def.get("mount", "")) == "tower":
		var p: Vector3 = def["pos"]
		var arm_y := p.y - GunPod.TOWER_DROP
		var x0 := ShipBuilder.hull_x_at(sections, chamfer, p.z, arm_y) * signf(p.x)
		var x1 := p.x + signf(p.x) * 0.3
		arm = AABB(Vector3(minf(x0, x1), arm_y - 0.26, p.z - 0.25), Vector3(absf(x1 - x0), 0.52, 0.5))
	var worst := INF
	var at := ""
	for i in 31:
		for j in 16:
			var a := Vector2(lerpf(pod.yaw_min, pod.yaw_max, i / 30.0), lerpf(pod.pitch_min, pod.pitch_max, j / 15.0))
			var xf := Transform3D(pod.aim_basis_local(a), pod.transform.origin)
			for pr: Array in pts:
				var q: Vector3 = xf * (pr[0] as Vector3)
				var gap := -_hull_margin(sections, chamfer, q) - float(pr[1])
				if arm.has_volume():
					gap = minf(gap, _gp_box_gap(arm, q) - float(pr[1]))
				if gap < worst:
					worst = gap
					at = "yaw %.0f pitch %.0f at %s" % [rad_to_deg(a.x), rad_to_deg(a.y), q.snapped(Vector3.ONE * 0.01)]
	return [worst, at]


## Distance from q to a box (negative inside it: how deep).
static func _gp_box_gap(box: AABB, q: Vector3) -> float:
	var d := (q - box.get_center()).abs() - box.size * 0.5
	var outside := Vector3(maxf(d.x, 0.0), maxf(d.y, 0.0), maxf(d.z, 0.0)).length()
	return outside if outside > 0.0 else maxf(d.x, maxf(d.y, d.z))


## Where a gun pod's rounds converge right now: the point under its sight (see
## Mothership._fire_round).
func _gp_sight_point(ship: Mothership, g: String) -> Vector3:
	var pod: GunPod = ship.turrets[g]
	var a := ship.aim_of(g)
	var eye := ship.to_global(pod.eye_local(a))
	var fwd := -(ship.global_basis * pod.aim_basis_local(a)).z
	var q := PhysicsRayQueryParameters3D.create(eye, eye + fwd * GunPod.CONVERGE_MAX, Projectiles.MASK_SHIP)
	q.collide_with_areas = true
	var hit := ship.get_world_3d().direct_space_state.intersect_ray(q)
	var dist := GunPod.CONVERGE_MAX if hit.is_empty() else maxf(GunPod.CONVERGE_MIN, eye.distance_to(hit["position"]))
	return eye + fwd * dist


## The first of `spots` (ship-local) that gun pod `g` can aim at with no rock near the line of fire
## (the cave differs from run to run), or the last one.
func _gp_open_spot(ship: Mothership, g: String, spots: Array) -> Vector3:
	var pod: GunPod = ship.turrets[g]
	var space := ship.get_world_3d().direct_space_state
	var from := ship.to_global(pod.position)
	for spot: Vector3 in spots:
		if not pod.within_limits(pod.aim_at_local(spot)):
			continue
		var clear := true
		for off: Vector3 in [Vector3.ZERO, Vector3(0, 2, 0), Vector3(0, -2, 0), Vector3(2, 0, 0), Vector3(-2, 0, 0)]:
			if not space.intersect_ray(PhysicsRayQueryParameters3D.create(from, ship.to_global(spot + off), Game.LAYER_CAVE)).is_empty():
				clear = false
				break
		if clear:
			return spot
	return spots[spots.size() - 1]


## Set a gun pod's belt and heat (and stop a belt change).
func _gp_set(ship: Mothership, gi: int, rounds: int, heat: float) -> void:
	var am := ship.gun_ammo
	am[gi] = rounds
	ship.gun_ammo = am
	var ht := ship.gun_heat
	ht[gi] = heat
	ship.gun_heat = ht
	var rl := ship.gun_reload
	rl[gi] = 0.0
	ship.gun_reload = rl


## The local player in the Prospector's port pod (see _run_gunpod).
func _gp_gunner(m: MissionLevel, shots: bool) -> void:
	var ship := m.ship
	var p := m.local_player
	var g := "gun_l"
	var gi := ship.gun_index(g)
	var pod: GunPod = ship.turrets[g]
	ship.request_station.rpc_id(1, g)
	await wait(0.6)
	var cam := p.camera
	var middle := get_viewport().get_visible_rect().size * 0.5
	# (The camera and the pod are both drawn where physics interpolation puts them.)
	print("[autotest] in the %s: station %s, camera %.3f m from the pod's eye and %s, fov %.0f, sight %.1f px from the middle of the screen, HUD crosshair %s, gun panel %s; belt %d, heat %.2f" % [
		ship.station_name(g), p.station, cam.global_position.distance_to(pod.eye.get_global_transform_interpolated().origin),
		"looking along the pod" if cam.global_basis.z.dot(pod.eye.global_basis.z) > 0.999 else "NOT looking along the pod", cam.fov,
		cam.unproject_position(pod._reticle.get_global_transform_interpolated().origin).distance_to(middle), m.hud._crosshair.visible,
		m.hud._station_panel.visible, ship.gun_ammo[gi], ship.gun_heat[gi]])
	await _shot_if(shots, "gp10_gunner_view")
	# The pod swings after the aim at its own pace.
	var want := Vector2(pod.yaw_min * 0.75, 0.25)
	var from := p.pod_aim
	p.station_aim = want
	var t0 := Time.get_ticks_msec()
	while p.pod_aim.distance_to(want) > 0.005 and Time.get_ticks_msec() - t0 < 5000:
		await get_tree().physics_frame
	var took := (Time.get_ticks_msec() - t0) / 1000.0
	await wait(0.3)
	print("[autotest] swinging %.0f deg towards the bow took %.2f s (at most %.0f deg/s); the server's aim %s, the pod's %s" % [
		rad_to_deg(from.distance_to(want)), took, rad_to_deg(GunPod.TURN_RATE), ship.aim_of(g), pod.aim])
	await _shot_if(shots, "gp11_bow")
	# A spitter (twice the health, harmless) out to port in the open: the four barrels converge on
	# the sight.
	var spot := _gp_open_spot(ship, g, [Vector3(-26, 4, -22), Vector3(-18, 3, -28), Vector3(-14, 2, -20), Vector3(-10, 4, -34), Vector3(-20, 0, -12)])
	var a := m.spawn_alien(Alien.Kind.SPITTER, ship.to_global(spot), 2.0, 0.0) as Alien
	a.set_physics_process(false)
	var ammo0 := ship.gun_ammo[gi]
	var shot_taken := false
	t0 = Time.get_ticks_msec()
	Input.action_press("fire")
	while is_instance_valid(a) and Time.get_ticks_msec() - t0 < 6000:
		p.station_aim = _aim_for(ship, pod, a.global_position)
		await get_tree().physics_frame
		if shots and not shot_taken and Time.get_ticks_msec() - t0 > 450:
			shot_taken = true
			await shot("gp12_firing")
	Input.action_release("fire")
	print("[autotest] spitter with twice the health: %s after %.2f s, %d rounds, heat %.2f" % ["KILLED" if not is_instance_valid(a) else "alive hp %.0f" % a.hp,
		(Time.get_ticks_msec() - t0) / 1000.0, ammo0 - ship.gun_ammo[gi], ship.gun_heat[gi]])
	if is_instance_valid(a):
		a.queue_free()
	# Hold the trigger: the heat climbs to full, and every round fired hot hurts the weapon systems.
	p.station_aim = Vector2(-0.6, 0.35)
	await wait(1.0)
	_gp_set(ship, gi, GunPod.BELT, ship.gun_heat[gi])
	var sys0 := ship.weapons_hp
	var heat0 := ship.gun_heat[gi]
	var full_at := -1.0
	var rounds_to_full := 0
	t0 = Time.get_ticks_msec()
	Input.action_press("fire")
	while Time.get_ticks_msec() - t0 < 15000:
		await get_tree().physics_frame
		var t := (Time.get_ticks_msec() - t0) / 1000.0
		if full_at < 0.0 and ship.gun_heat[gi] >= 0.99:
			full_at = t
			rounds_to_full = GunPod.BELT - ship.gun_ammo[gi]
		if full_at >= 0.0 and t > full_at + 2.0:
			break
	var tracers := 0
	for s: Dictionary in m.projectiles._shots:
		if s["kind"] == "hmg":
			tracers += 1
	var hot_rounds := GunPod.BELT - ship.gun_ammo[gi] - rounds_to_full
	var shown := "ammo '%s' '%s', heat note '%s', %s, heat lamp %.1f" % [pod._ammo_label.text, pod._ammo_note.text, pod._heat_note.text,
		pod._sys_label.text, (pod._lamps["heat"] as StandardMaterial3D).emission_energy_multiplier]
	await _shot_if(shots, "gp13_overheat")
	Input.action_release("fire")
	print("[autotest] trigger held from heat %.2f: full heat after %.1f s (%d rounds); %d rounds fired hot took the weapon systems %.0f -> %.0f; %d tracers in flight; screens: %s" % [
		heat0, full_at, rounds_to_full, hot_rounds, sys0, ship.weapons_hp, tracers, shown])
	# Let go: the heat bleeds off.
	var h1 := ship.gun_heat[gi]
	await wait(2.0)
	print("[autotest] 2 s after letting go: heat %.2f -> %.2f (cools %.2f/s), heat note '%s'" % [h1, ship.gun_heat[gi], GunPod.HEAT_COOL, pod._heat_note.text])
	await _shot_if(shots, "gp14_cooling")
	# The belt runs dry with the trigger held: a new one loads by itself.
	ship.weapons_hp = 100.0
	_gp_set(ship, gi, 8, 0.0)
	Input.action_press("fire")
	await wait(1.0)
	var started := ship.gun_reload[gi] > 0.0
	var left := ship.gun_reload[gi]
	await wait(1.2)
	var mid := "'%s' '%s', belt lamp %.1f" % [pod._ammo_label.text, pod._ammo_note.text, (pod._lamps["belt"] as StandardMaterial3D).emission_energy_multiplier]
	await _shot_if(shots, "gp15_reloading")
	t0 = Time.get_ticks_msec()
	while ship.gun_reload[gi] > 0.0 and Time.get_ticks_msec() - t0 < 8000:
		await get_tree().physics_frame
	var loaded := ship.gun_ammo[gi]
	var waited := (Time.get_ticks_msec() - t0) / 1000.0
	await wait(0.5)
	var firing_again := ship.gun_ammo[gi] < loaded
	Input.action_release("fire")
	print("[autotest] belt ran dry with the trigger held: belt change %s (%.1f of %.1f s left), mid-way %s; %.1f s later a new belt of %d, firing again %s" % [
		started, left, GunPod.RELOAD_TIME, mid, waited, loaded, firing_again])
	# Leaning into the sight.
	Input.action_press("aim")
	await wait(0.7)
	var lean_fov := cam.fov
	var lean_off := cam.unproject_position(pod._reticle.get_global_transform_interpolated().origin).distance_to(middle)
	await _shot_if(shots, "gp16_sight")
	Input.action_release("aim")
	await wait(0.6)
	print("[autotest] leaning into the sight: fov %.0f, sight %.1f px from the middle; let go: fov %.0f" % [lean_fov, lean_off, cam.fov])
	# Weapon systems offline: the trigger does nothing and the screens say so.
	ship.damage_system("weapons", 200.0)
	await wait(0.3)
	var before := ship.gun_ammo[gi]
	Input.action_press("fire")
	await wait(0.6)
	Input.action_release("fire")
	print("[autotest] weapon systems offline: %d rounds fired, screens '%s' / '%s', ready lamp %.1f" % [before - ship.gun_ammo[gi],
		pod._ammo_note.text, pod._heat_note.text, (pod._lamps["ready"] as StandardMaterial3D).emission_energy_multiplier])
	await _shot_if(shots, "gp17_offline")
	ship.weapons_hp = 100.0
	ship.weapons_online = true
	p.exit_station(true)
	await wait(0.4)
	var guns_line := ""
	for line in m.hud._crew_report(ship, m).split("\n"):
		if line.contains("heat"):
			guns_line = line
	print("[autotest] out of the pod: station '%s', HUD crosshair %s, crew status (Tab): %s" % [p.station, m.hud._crosshair.visible, guns_line])


## The Multiple Rocket Launcher System on the Prospector's port pod: mounted from a crate at its gun
## console (its heavy machine gun comes off in a crate), the launchers and the rockets in their
## tubes, a salvo held down against tough, harmless spitters with the sight a little off them (the
## rockets scatter, curve and home in), the loader putting the rockets back one at a time, the
## screens, and a crew bot firing salvos from it (rockets_check: no shots).
func _run_rockets(shots: bool) -> void:
	Game.bot_count = 1
	var m := await _start_solo_mission()
	Game.bot_count = 0
	if m == null:
		print("[autotest] FAIL: mission not ready")
		return
	var ship := m.ship
	var tough := ship.stats.duplicate()
	tough["crew_hp"] = 99999.0
	tough["collateral"] = 0.0
	ship.stats = tough
	ship.max_hull = 99999.0
	ship.hull = 99999.0
	m._director_t = 99999.0
	await _put_ship(m, 60.0)
	_clear_aliens()
	var bot: CrewMember = null
	for c in ship.crew_root.get_children():
		var cm := c as CrewMember
		if cm and cm.bot:
			bot = cm
			cm.set_physics_process(false)
	var p := m.local_player
	var g := "gun_l"
	var gi := ship.gun_index(g)
	var pod: GunPod = ship.turrets[g]
	# Mount it: a crate of rocket launchers carried to the port gun's console.
	var spot: Vector3 = ship.console(g)["console"]
	p.position = Vector3(spot.x, p.position.y, spot.z) + Basis(Vector3.UP, float(ship.console(g).get("seat_yaw", 0.0))) * Vector3(0, 0, 0.8)
	await wait(0.3)
	ship.spawn_crate("weapon:mrls", p.position + Vector3(0, SupplyCrate.SIZE.y * 0.5, 0), 0.0)
	await wait(0.3)
	var crate_name := ""
	for c in ship.cargo_root.get_children():
		if (c as SupplyCrate).item == "weapon:mrls":
			crate_name = str(c.name)
	ship.request_crate_pickup.rpc_id(1, crate_name)
	await wait(0.3)
	ship.request_install.rpc_id(1, crate_name, g)
	await wait(0.5)
	var hmg_crates := 0
	for c in ship.cargo_root.get_children():
		if (c as SupplyCrate).item == "weapon:hmg":
			hmg_crates += 1
	var shown := 0
	await wait(0.2)
	for t in GunPod.MRLS_TUBES:
		if pod._tube_rockets and pod._tube_rockets.get_instance_transform(t).basis.get_scale().x > 0.5:
			shown += 1
	print("[autotest] mounted: %s carries '%s' (pod shows '%s', launchers shown %s, barrels shown %s), rockets %d, rockets in the tubes %d, heavy machine gun crates %d, crate in hand %s" % [
		ship.station_name(g), ship.gun_weapon(g), pod.weapon, pod._launchers != null and pod._launchers.visible, pod._barrel_nodes[0].visible,
		ship.gun_ammo[gi], shown, hmg_crates, ship.crate_carried_by(p.peer_id) != null])
	if shots:
		var cam := Camera3D.new()
		cam.fov = 50.0
		m.add_child(cam)
		var at := ship.to_global(pod.position)
		cam.global_position = at + ship.global_basis * Vector3(-3.6, 1.6, -4.4)
		cam.look_at(at, ship.global_basis.y)
		cam.current = true
		await wait(0.4)
		await shot("rk01_launchers")
		cam.queue_free()
		await wait(0.1)
	# Into the pod: the screens.
	ship.request_station.rpc_id(1, g)
	await wait(0.8)
	print("[autotest] in the pod: screens '%s' '%s' '%s' / '%s' '%s', ready lamp %.1f" % [pod._captions["ammo"].text, pod._ammo_label.text, pod._ammo_note.text,
		pod._captions["heat"].text, pod._heat_note.text, (pod._lamps["ready"] as StandardMaterial3D).emission_energy_multiplier])
	await _shot_if(shots, "rk02_gunner")
	# A salvo: four tough spitters out to port, the sight held a few degrees off the first one.
	var base := _gp_open_spot(ship, g, [Vector3(-26, 4, -22), Vector3(-18, 3, -28), Vector3(-14, 2, -20), Vector3(-10, 4, -34), Vector3(-20, 0, -12)])
	var aliens: Array[Alien] = []
	for off: Vector3 in [Vector3.ZERO, Vector3(3, 2, 2), Vector3(-3, -1, 3), Vector3(2, -2, -3)]:
		var a := m.spawn_alien(Alien.Kind.SPITTER, ship.to_global(base + off), 2.0, 0.0) as Alien
		a.set_physics_process(false)
		aliens.append(a)
	await wait(0.3)
	var hp0 := 0.0
	for a in aliens:
		hp0 += a.hp
	var aim := _aim_for(ship, pod, aliens[0].global_position)
	p.station_aim = aim + Vector2(0.09, 0.05)
	await wait(1.5)
	var fired := 0
	var homed := {}
	var seen := {}
	var t0 := Time.get_ticks_msec()
	var snapped := not shots
	Input.action_press("fire")
	while Time.get_ticks_msec() - t0 < 2600:
		await get_tree().physics_frame
		for s: Dictionary in m.projectiles._shots:
			if s["kind"] != "rocket":
				continue
			var id := int(s["id"])
			if not seen.has(id):
				seen[id] = true
				fired += 1
			if s["target"] != null:
				homed[id] = true
		if not snapped and Time.get_ticks_msec() - t0 > 700:
			snapped = true
			await shot("rk03_salvo")
	Input.action_release("fire")
	await wait(2.0)
	var left := 0
	var hp1 := 0.0
	for a in aliens:
		if is_instance_valid(a) and a.hp > 0.0:
			left += 1
			hp1 += a.hp
	print("[autotest] salvo held 2.6 s with the sight %.1f deg off: %d rockets loosed (every %.2f s), %d of them homed in, aliens left %d of %d, damage dealt %.0f; rockets loaded now %d" % [
		rad_to_deg(Vector2(0.09, 0.05).length()), fired, GunPod.MRLS_INTERVAL, homed.size(), left, aliens.size(), hp0 - hp1, ship.gun_ammo[gi]])
	for a in aliens:
		if is_instance_valid(a):
			a.queue_free()
	# The loader: from empty, a rocket every MRLS_LOAD seconds.
	var am := ship.gun_ammo
	am[gi] = 0
	ship.gun_ammo = am
	await wait(0.3)
	var loading := "'%s' '%s' / '%s'" % [pod._ammo_label.text, pod._ammo_note.text, pod._heat_note.text]
	var n0 := ship.gun_ammo[gi]
	t0 = Time.get_ticks_msec()
	await wait(4.0)
	var per := (Time.get_ticks_msec() - t0) / 1000.0 / maxf(float(ship.gun_ammo[gi] - n0), 1.0)
	await _shot_if(shots, "rk04_loading")
	print("[autotest] loader from empty: %d rockets in 4 s (one every %.2f s, nominal %.2f), screens while loading %s, tubes showing %d" % [
		ship.gun_ammo[gi] - n0, per, GunPod.MRLS_LOAD, loading, pod._shown_tubes.x])
	p.exit_station(true)
	await wait(0.4)
	# A crew bot in a pod (rockets on both, whichever it takes): salvos at a pack out to port.
	if bot:
		var all := {}
		for gg: String in ship.gun_stations():
			all[gg] = "mrls"
		ship.gun_weapons = all
		for k in ship.gun_stations().size():
			ship._reset_gun(k)
		bot.set_physics_process(true)
		var pack: Array[Alien] = []
		for k in 4:
			var a := m.spawn_alien(Alien.Kind.SPITTER, ship.to_global(base + Vector3(k * 3.0 - 4.5, k % 2 * 2.0, 0)), 1.5, 0.0) as Alien
			a.set_physics_process(false)
			pack.append(a)
		t0 = Time.get_ticks_msec()
		var used := 0
		var last: Array[int] = []
		for k in ship.gun_ammo.size():
			last.append(ship.gun_ammo[k])
		var station_seen := ""
		while Time.get_ticks_msec() - t0 < 14000:
			await wait(0.1)
			for k in ship.gun_ammo.size():
				if ship.gun_ammo[k] < last[k]:
					used += last[k] - ship.gun_ammo[k]
				last[k] = ship.gun_ammo[k]
			station_seen = bot.station
			var alive := 0
			for a in pack:
				if is_instance_valid(a) and a.hp > 0.0:
					alive += 1
			if alive == 0:
				break
		var alive_n := 0
		for a in pack:
			if is_instance_valid(a) and a.hp > 0.0:
				alive_n += 1
				a.queue_free()
		print("[autotest] crew bot on the rockets (%s): %d rockets in %.1f s, aliens left %d of %d" % [station_seen, used,
			(Time.get_ticks_msec() - t0) / 1000.0, alive_n, pack.size()])


## A crew bot mans a gun pod against a pack of tough, harmless spitters out to port (beside the
## ship, clear of any waystation's defences): it fires in bursts and never fires hot, and sits in
## the pod for everyone to see (see _run_gunpod).
func _gp_bot(m: MissionLevel, bot: CrewMember, shots: bool) -> void:
	if bot == null:
		print("[autotest] FAIL: no crew bot")
		return
	var ship := m.ship
	var pack: Array[Alien] = []
	var spots: Array = [Vector3(-16, 3, -12), Vector3(-13, 6, -18), Vector3(-19, 1, -6), Vector3(-11, 4, -24), Vector3(-22, 4, -14),
		Vector3(-15, -1, -20), Vector3(-24, 2, -2)]
	for k in 4:
		var spot := _gp_open_spot(ship, "gun_l", spots)
		spots.erase(spot)
		var a := m.spawn_alien(Alien.Kind.SPITTER, ship.to_global(spot), 8.0, 0.0) as Alien
		a.set_physics_process(false)
		pack.append(a)
	# Start the bot afresh, so it picks the pod that has the pack in its arc.
	ship.release_peer(bot.peer_id)
	bot.station = ""
	bot.brain.reset()
	bot.set_physics_process(true)
	var sys0 := ship.weapons_hp
	var gun := ""
	var peak := 0.0
	var seen := ""
	var t := 0.0
	var left := pack.size()
	while t < 40.0 and left > 0:
		await get_tree().physics_frame
		t += 1.0 / 60.0
		if bot.station in ship.gun_stations():
			gun = bot.station
			peak = maxf(peak, ship.gun_heat_of(gun))
			if seen == "" and t > 6.0:
				var pod: GunPod = ship.turrets[gun]
				seen = "body at the console %s, figure in the pod %s" % [bot._body.visible, pod._figure.visible]
				if shots:
					var cam := Camera3D.new()
					cam.far = 400.0
					m.add_child(cam)
					cam.global_position = ship.to_global(pod.position + Vector3(signf(pod.position.x) * 4.5, 1.6, -4.2))
					cam.look_at(ship.to_global(pod.position))
					cam.current = true
					await wait(0.1)
					await shot("gp18_bot_pod")
					cam.queue_free()
					m.local_player.camera.current = true
		left = 0
		for a in pack:
			if is_instance_valid(a):
				left += 1
	print("[autotest] crew bot gunner on %s for %.0f s: heat peaked at %.2f (it stops at %.2f), weapon systems %.0f -> %.0f, spitters left %d of %d; %s" % [
		gun if gun != "" else "no gun", t, peak, CrewBot.POD_HEAT_STOP, sys0, ship.weapons_hp, left, pack.size(), seen])
	for a in pack:
		if is_instance_valid(a):
			a.queue_free()


## The pilot's cockpit (Cockpit) and the 2026-10-17 issues: every ship's glazed nose (the camera
## feeds' mounts outside the hull, the mining lasers never swinging through the glass, and with
## shots each nose from outside and what each camera feed sees), then in a mission the pilot's
## first-person view with the HUD panels gone, the thrust lever, gear stick, dials, lamps and
## terminal following the ship, the camera feeds rendering, the big red button, the motion
## tracker's warning before an ambush, the hostility surging, scraping the rock, the gun pod's
## clockwork and smoke, and every ship's cockpit (cockpit_check: no screenshots).
func _run_cockpit(shots: bool) -> void:
	await _ck_studio(shots)
	_ck_sounds()
	var m := await _start_solo_mission()
	if m == null:
		print("[autotest] FAIL: mission not ready")
		return
	var ship := m.ship
	# A tough ship: the aliens about while the ship sits still for the tests can't wear it down.
	var tough := ship.stats.duplicate()
	tough["crew_hp"] = 99999.0
	tough["collateral"] = 0.0
	ship.stats = tough
	ship.max_hull = 99999.0
	ship.hull = 99999.0
	m._director_t = 99999.0
	await _put_ship(m, 70.0)
	_clear_aliens()
	await _ck_seat(m, shots)
	await _ck_markers(m, shots)
	await _ck_controls(m, shots)
	await _ck_feeds(m, shots)
	await _ck_gauges(m, shots)
	await _ck_button(m, shots)
	await _ck_hover(m, shots)
	await _ck_barrier(m, shots)
	# Between the first two waystations, where ambushes may come from either way.
	await _put_ship(m, 600.0)
	await _ck_ambush(m, shots)
	await _ck_surge(m, shots)
	await _ck_scrape(m, shots)
	await _ck_smoke(m, shots)
	m.local_player.exit_station(true)
	await wait(0.4)
	print("[autotest] left the seat: ship panel %s, station panel %s, crosshair %s" % [m.hud._ship_panel.visible,
		m.hud._station_panel.visible, m.hud._crosshair.visible])
	m.abort_mission()
	for i in 100:
		await wait(0.1)
		var lvl: Node = Game.main.current_level()
		if lvl and lvl.name == "Homebase":
			break
	await _ck_ships(shots)


## Every ship's nose in a lit studio: the camera mounts outside the hull, the clearance of each
## mining laser's barrel and the first metres of its beam from the nose, and (with shots) the nose
## from outside and what each camera feed sees.
func _ck_studio(shots: bool) -> void:
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
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	world.add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 50.0
	cam.near = 0.05
	world.add_child(cam)
	cam.current = true
	for id: String in ShipTypes.ORDER:
		var ship := Node3D.new()
		world.add_child(ship)
		var parts := ShipBuilder.build_exterior(ship, id)
		var t := ShipTypes.get_type(id)
		var full := ShipTypes.full_sections(t)
		var chamfer := float(t["chamfer"])
		var outs := PackedStringArray()
		var covers := PackedStringArray()
		for c: String in t["cams"]:
			outs.append("%s %.2f m" % [c, -_hull_margin(full, chamfer, ShipTypes.cam_transform(t, c).origin)])
			covers.append("%s %d%%" % [c, int(round(_ck_hull_cover(t, Cockpit.feed_transform(t, c)) * 100.0))])
		print("[autotest] %s camera feeds, outside the hull by: %s" % [id, ", ".join(outs)])
		print("[autotest] %s camera feeds, share of the picture the hull fills: %s" % [id, ", ".join(covers)])
		for lid: String in t["lasers"]:
			var tur: Turret = parts["turrets"][lid]
			var worst := INF
			var at := ""
			for i in 33:
				for j in 33:
					var a := Vector2(lerpf(tur.yaw_min, tur.yaw_max, i / 32.0), lerpf(tur.pitch_min, tur.pitch_max, j / 32.0))
					var basis := tur.aim_basis_local(a)
					# The barrel (0.2 m out to the muzzle) and the first 6 m of the beam.
					for k in 33:
						var d := 0.2 + k * 0.25
						var q := tur.transform.origin + basis * Vector3(0, 0, -d)
						var gap := _ck_nose_gap(t, q) - (0.25 if d < 2.1 else 0.0)
						if gap < worst:
							worst = gap
							at = "yaw %.0f pitch %.0f, %.1f m out" % [rad_to_deg(a.x), rad_to_deg(a.y), d]
			print("[autotest] %s %s: barrel and beam clear the glazed nose by %.2f m at worst (%s)" % [id, lid, worst, at])
		if shots:
			var tip_z := float((t["nose"] as Array).back()[0])
			for v: Array in [["nose", Vector3(-6.5, 3.0, tip_z - 7.0), Vector3(0, 1.4, tip_z + 1.5)],
					["nose_side", Vector3(-9.0, 1.2, tip_z + 1.0), Vector3(0, 1.0, tip_z + 2.0)],
					["nose_low", Vector3(2.5, -3.0, tip_z - 6.0), Vector3(0, 0.0, tip_z + 1.0)]]:
				cam.fov = 50.0
				cam.global_position = v[1]
				cam.look_at(v[2])
				await wait(0.15)
				await shot("ck_%s_%s" % [id, v[0]])
			for c: String in t["cams"]:
				cam.fov = Cockpit.FEED_FOV
				cam.global_transform = Cockpit.feed_transform(t, c)
				await wait(0.12)
				await shot("ck_%s_cam_%s" % [id, c])
		ship.queue_free()
		await wait(0.1)
	world.queue_free()
	await wait(0.2)


## How much of a camera feed's picture (camera at ship-local `xf`) the hull fills (0..1): rays
## through a grid over the feed's frame, marched 30 m out against the hull's sections.
static func _ck_hull_cover(t: Dictionary, xf: Transform3D) -> float:
	var full := ShipTypes.full_sections(t)
	var chamfer := float(t["chamfer"])
	var ty := tan(deg_to_rad(Cockpit.FEED_FOV) * 0.5)
	var tx := ty * float(Cockpit.FEED_SIZE.x) / float(Cockpit.FEED_SIZE.y)
	var hits := 0
	for j in 18:
		for i in 24:
			var d := (xf.basis * Vector3(((i + 0.5) / 24.0 * 2.0 - 1.0) * tx, (1.0 - (j + 0.5) / 18.0 * 2.0) * ty, -1.0)).normalized()
			var s := 0.05
			while s < 30.0:
				if _hull_margin(full, chamfer, xf.origin + d * s) > 0.0:
					hits += 1
					break
				s += 0.2
	return hits / 432.0


## How far ship-local point q is from the glazed nose (negative: inside it). Behind the cockpit's
## bulkhead it does not count.
static func _ck_nose_gap(t: Dictionary, q: Vector3) -> float:
	var nose: Array = t["nose"]
	var asc: Array = []
	for i in range(nose.size() - 1, -1, -1):
		asc.append(nose[i])
	var tip_z := float((asc[0] as Array)[0])
	var base_z := float((asc.back() as Array)[0])
	if q.z > base_z:
		return INF
	var m := _hull_margin(asc, float(t["chamfer"]), Vector3(q.x, q.y, maxf(q.z, tip_z)))
	if q.z < tip_z:
		return maxf(tip_z - q.z, -m)
	return -m


## The gun pod's traversing motors: the first version's whine, low-passed, so far less of it is up
## where it screeched (over 2 kHz) and how loud it plays; and the guns' bark by barrel heat.
func _ck_sounds() -> void:
	var smp := _stream_samples(Sfx.stream("pod_servo") as AudioStreamWAV)
	var first := Sfx._synth(1.0, {"wave": "saw", "f0": 96.0, "f1": 96.0, "tone": 0.22, "harm": 0.35, "noise": 0.3, "lp0": 0.12,
		"lp1": 0.12, "vib_f": 7.0, "vib_a": 0.015, "decay": 0.0, "gain": 0.7, "attack": 0.0})
	print("[autotest] gun pod motors: %.2f%% of the energy over 800 Hz, %.2f%% over 1.5 kHz (the first version: %.2f%%, %.2f%%), rms %.1f dBFS (first %.1f), played at %.0f dB at full swing (first -9); loops without a jump: %.3f (first sample minus last)" % [
		_share_above(smp, 800.0) * 100.0, _share_above(smp, 1500.0) * 100.0, _share_above(first, 800.0) * 100.0, _share_above(first, 1500.0) * 100.0,
		_rms_db(smp), _rms_db(first), GunPod.SERVO_DB, smp[0] - smp[smp.size() - 1]])
	var pitches := PackedStringArray()
	for h: float in [0.0, 0.25, 0.5, 0.75, 1.0]:
		pitches.append("%.2f" % lerpf(1.0, GunPod.HOT_PITCH, h))
	print("[autotest] gun pod bark: one sound, its pitch at heat 0 / 0.25 / 0.5 / 0.75 / 1: %s" % " / ".join(pitches))


## The share of a sound's energy above `hz` (four one-pole high-passes in a row, so the strong low
## harmonics hardly leak into it).
static func _share_above(smp: PackedFloat32Array, hz: float) -> float:
	var a := 1.0 / (1.0 + TAU * hz / Sfx.RATE)
	var sig := smp.duplicate()
	for stage in 4:
		var hp := 0.0
		var prev := 0.0
		for i in sig.size():
			var v := sig[i]
			hp = a * (hp + v - prev)
			prev = v
			sig[i] = hp
	var high := 0.0
	var all := 0.0
	for i in smp.size():
		high += sig[i] * sig[i]
		all += smp[i] * smp[i]
	return high / maxf(all, 0.000001)


## The pilot seat: first person at the cockpit's eye, no HUD ship panel, station panel or
## crosshair, and views round the cockpit.
func _ck_seat(m: MissionLevel, shots: bool) -> void:
	var ship := m.ship
	var p := m.local_player
	ship.request_station.rpc_id(1, "pilot")
	await wait(0.8)
	var cam := p.camera
	var eye := ship.cockpit.get_global_transform_interpolated() * Cockpit.EYE
	print("[autotest] pilot seat: station '%s', camera %.3f m from the cockpit's eye, fov %.0f; HUD ship panel %s, station panel %s, crosshair %s; feeds rendering %s" % [
		p.station, cam.global_position.distance_to(eye), cam.fov, m.hud._ship_panel.visible, m.hud._station_panel.visible,
		m.hud._crosshair.visible, ship.cockpit._feeds_on])
	print("[autotest] terminal:\n%s" % ship.cockpit._nav.text)
	print("[autotest] terminal text bounds %s on its screen %s; a caption's bounds %s" % [ship.cockpit._nav.get_aabb(),
		(ship.cockpit._nav_screen.mesh as QuadMesh).size, (ship.cockpit._lamps["auto"]["label"] as Label3D).get_aabb()])
	await _shot_if(shots, "ck01_pilot_view")
	for v: Array in [["ck02_look_left", Vector2(1.25, -0.15)], ["ck03_look_right", Vector2(-1.25, -0.15)], ["ck04_look_up", Vector2(0.0, 0.75)],
			["ck05_dashboard", Vector2(0.0, -0.62)], ["ck05b_far_left", Vector2(1.75, -0.3)]]:
		p._pilot_look = v[1]
		await wait(0.3)
		await _shot_if(shots, v[0])
	# Lean in to read the terminal.
	p._pilot_look = Vector2(0.0, -0.62)
	Input.action_press("aim")
	await wait(0.6)
	print("[autotest] leaning in: fov %.0f, eye moved %.2f m" % [cam.fov, cam.global_position.distance_to(eye)])
	await _shot_if(shots, "ck06_terminal")
	Input.action_release("aim")
	p._pilot_look = Vector2(0.0, Cockpit.LOOK_REST)
	await wait(0.5)


## Frames drawn a second over the next `seconds`.
func _frame_rate(seconds: float) -> float:
	var f0 := Engine.get_frames_drawn()
	var t0 := Time.get_ticks_usec()
	await wait(seconds)
	return float(Engine.get_frames_drawn() - f0) / maxf(float(Time.get_ticks_usec() - t0) / 1000000.0, 0.001)


## The waystation marker: from the pilot seat only over the station when it is in view through the
## glass (not on the HUD's top lines while the pilot looks down at the dashboard); a walker facing
## aft gets it on the screen's edge, whole.
func _ck_markers(m: MissionLevel, shots: bool) -> void:
	var ship := m.ship
	var p := m.local_player
	var mk: Label = m.hud._station_marker
	var screen := Rect2(Vector2.ZERO, m.hud.get_viewport().get_visible_rect().size)
	var seen := PackedStringArray()
	for v: Array in [["ahead", Vector2(0.0, Cockpit.LOOK_REST)], ["at the dashboard", Vector2(0.0, -0.7)], ["over the shoulder", Vector2(1.7, 0.1)]]:
		p._pilot_look = v[1]
		await wait(0.3)
		seen.append("%s: %s" % [v[0], ("shown at (%d, %d)" % [mk.position.x, mk.position.y]) if mk.visible else "hidden"])
	p._pilot_look = Vector2(0.0, Cockpit.LOOK_REST)
	print("[autotest] waystation marker from the pilot seat, looking %s" % ", ".join(seen))
	p.exit_station(true)
	await wait(0.3)
	_face(p, p.position + Vector3(0.0, CrewMember.EYE, 10.0))
	await wait(0.3)
	print("[autotest] walker facing aft: marker %s at (%d, %d), %d px wide, whole on screen %s" % ["shown" if mk.visible else "hidden",
		mk.position.x, mk.position.y, mk.size.x, screen.encloses(Rect2(mk.position, mk.size))])
	await _shot_if(shots, "ck05c_walker_aft")
	ship.request_station.rpc_id(1, "pilot")
	await wait(0.8)


## The thrust lever follows the throttle and the gear stick the turn and climb.
func _ck_controls(m: MissionLevel, shots: bool) -> void:
	var ship := m.ship
	var cp := ship.cockpit
	var p := m.local_player
	var lever0 := cp._lever.rotation.x
	Input.action_press("move_forward")
	await wait(1.4)
	Input.action_release("move_forward")
	await wait(0.4)
	var lever1 := cp._lever.rotation.x
	var thr := ship.throttle
	Input.action_press("move_left")
	Input.action_press("jump")
	await wait(0.5)
	var stick := cp._stick.rotation
	p._pilot_look = Vector2(0.0, -0.7)
	await wait(0.2)
	await _shot_if(shots, "ck07_controls")
	Input.action_release("move_left")
	Input.action_release("jump")
	await wait(0.6)
	var stick_rest := cp._stick.rotation
	print("[autotest] thrust lever: throttle %.2f, lever %.2f -> %.2f rad; gear stick with A + Space: roll %.2f pitch %.2f, let go: roll %.2f pitch %.2f" % [
		thr, lever0, lever1, stick.z, stick.x, stick_rest.z, stick_rest.x])
	Input.action_press("full_stop")
	await wait(0.2)
	Input.action_release("full_stop")
	await wait(0.8)
	p._pilot_look = Vector2(0.0, Cockpit.LOOK_REST)
	print("[autotest] full stop: throttle %.2f, lever %.2f rad (stop at %.2f)" % [ship.throttle, cp._lever.rotation.x, -Cockpit.LEVER_STOP])


## The camera feeds: each renders while the pilot is in the seat; how bright each picture is.
func _ck_feeds(m: MissionLevel, shots: bool) -> void:
	var ship := m.ship
	var cp := ship.cockpit
	var p := m.local_player
	# What the feeds cost: the frame rate with vsync off, with the feeds running (one renders each
	# frame) and with them stopped. (Godot reports no GPU time for a viewport that renders once.)
	var main_rid := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(main_rid, true)
	var vsync := DisplayServer.window_get_vsync_mode()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await wait(0.5)
	var with_feeds := await _frame_rate(2.0)
	var main_ms := RenderingServer.viewport_get_measured_render_time_gpu(main_rid)
	cp.set_process(false)
	for f: Dictionary in cp._feeds:
		(f["vp"] as SubViewport).render_target_update_mode = SubViewport.UPDATE_DISABLED
	await wait(0.3)
	var without := await _frame_rate(2.0)
	cp.set_process(true)
	DisplayServer.window_set_vsync_mode(vsync)
	RenderingServer.viewport_set_measure_render_time(main_rid, false)
	print("[autotest] frame rate with vsync off: %.0f fps with the feeds running, %.0f fps without (the feeds: %.2f ms a frame); GPU time of the main view %.2f ms" % [
		with_feeds, without, 1000.0 / maxf(with_feeds, 1.0) - 1000.0 / maxf(without, 1.0), main_ms])
	var lines := PackedStringArray()
	# A headless run has no feed pictures to read back (the dummy renderer has no textures).
	var pictures := DisplayServer.get_name() != "headless"
	for f: Dictionary in cp._feeds:
		var vp: SubViewport = f["vp"]
		var img := vp.get_texture().get_image() if pictures else null
		var mean := 0.0
		if img and not img.is_empty():
			var n := 0
			for y in range(0, img.get_height(), 12):
				for x in range(0, img.get_width(), 12):
					var c := img.get_pixel(x, y)
					mean += (c.r + c.g + c.b) / 3.0
					n += 1
			mean /= maxf(n, 1)
		lines.append("%s %s (mirrored %s, picture brightness %.3f)" % [f["name"], "rendering" if f["seen"] else "NOT RENDERED",
			(f["screen"] as MeshInstance3D).material_override.get_shader_parameter("mirror"), mean])
	print("[autotest] camera feeds: %s" % ", ".join(lines))
	if shots:
		Input.action_press("aim")
		for v: Array in [["ck08_feeds_left", "spine", 0.0], ["ck09_feeds_right", "belly", 0.0], ["ck10_mirror", "rear", 0.0]]:
			var sx := cp.global_transform * cp._screen_xform(v[1])
			var eye := cp.global_transform * Cockpit.EYE
			var to := cp.global_basis.inverse() * (sx.origin + sx.basis.y * (0.15 if v[1] != "rear" else 0.0) - eye)
			p._pilot_look = Vector2(atan2(-to.x, -to.z), atan2(to.y, Vector2(to.x, to.z).length()))
			await wait(0.7)
			await shot(v[0])
		Input.action_release("aim")
		p._pilot_look = Vector2(0.0, Cockpit.LOOK_REST)
		await wait(0.4)


## The gauges, readouts, red lights, lamps and side displays follow the ship: healthy, then hull at a
## quarter, fuel low, shield down, an intruder aboard and the engine offline.
func _ck_gauges(m: MissionLevel, shots: bool) -> void:
	var ship := m.ship
	var cp := ship.cockpit
	# Healthy first: the readouts, the side displays and no red lights.
	ship.throttle = 0.6
	await wait(1.5)
	var lit0 := await _ck_lit(cp._lights)
	print("[autotest] healthy, throttle 0.6: fuel '%s' (scale %s), speed '%s' (scale %s), hull '%s' %.2f, shield '%s' %.2f; red lights lit: %s" % [
		cp._dials["fuel"]["readout"].text, _ck_figures(cp, "fuel"), cp._dials["speed"]["readout"].text, _ck_figures(cp, "speed"),
		cp._bars["hull"]["readout"].text, float(cp._bars["hull"]["shown"]), cp._bars["shield"]["readout"].text, float(cp._bars["shield"]["shown"]),
		", ".join(lit0) if not lit0.is_empty() else "none"])
	print("[autotest] engine display: '%s' integrity '%s', '%s', '%s' (fan turned %.1f rad); weapons display: '%s'%s" % [
		cp._engine["state"].text, cp._engine["integrity"].text, cp._engine["thrust"].text, cp._engine["rpm"].text, cp._engine_spin,
		cp._weapons["state"].text, _ck_pod_rows(cp)])
	ship.throttle = 0.0
	# Then everything wrong at once.
	ship.hull = ship.max_hull * 0.25
	ship.fuel = ship.max_fuel * 0.15
	ship.shield = 0.0
	ship.shield_down = true
	ship.shield_reboot = 30.0
	ship.damage_system("engine", 200.0)
	ship.spawn_boarder(0, 1.0)
	await wait(2.5)
	var lamps := await _ck_lit(cp._lamps)
	var lights := await _ck_lit(cp._lights)
	var states := {}
	for i in 40:
		states[cp._engine["state"].text] = true
		await get_tree().process_frame
	print("[autotest] hull 25%%, fuel 15%%, shield down, engine offline, a boarder aboard: fuel '%s' %.2f, hull '%s' %.2f, shield '%s' %.2f; lamps lit within a second: %s; red lights flashing: %s; engine display shows %s" % [
		cp._dials["fuel"]["readout"].text, float(cp._dials["fuel"]["shown"]), cp._bars["hull"]["readout"].text, float(cp._bars["hull"]["shown"]),
		cp._bars["shield"]["readout"].text, float(cp._bars["shield"]["shown"]), ", ".join(lamps), ", ".join(lights), "/".join(states.keys())])
	print("[autotest] terminal:\n%s" % cp._nav.text)
	if shots:
		for v: Array in [["ck11_warnings", Vector2(0.0, -0.5)], ["ck11b_engine_display", Vector2(1.2, -0.25)], ["ck11c_weapons_display", Vector2(-1.2, -0.25)]]:
			m.local_player._pilot_look = v[1]
			await wait(0.35)
			await shot(v[0])
	m.local_player._pilot_look = Vector2(0.0, Cockpit.LOOK_REST)
	for c in ship.boarder_root.get_children():
		c.queue_free()
	ship.hull = ship.max_hull
	ship.fuel = ship.max_fuel
	ship.shield_down = false
	ship.shield_reboot = 0.0
	ship.shield = ship.max_shield
	ship.engine_hp = 100.0
	ship.engine_online = true
	await wait(0.5)


## Which of the lamps or lights (id -> {"mat"} or id -> material) light up within a second (some
## blink).
func _ck_lit(lamps: Dictionary) -> PackedStringArray:
	var lit := PackedStringArray()
	for i in 60:
		for k: String in lamps:
			var mat: StandardMaterial3D = lamps[k]["mat"] if lamps[k] is Dictionary else lamps[k]
			if mat.emission_energy_multiplier > 0.0 and not k in lit:
				lit.append(k)
		await get_tree().process_frame
	return lit


## The figures round a cockpit dial's scale.
static func _ck_figures(cp: Cockpit, id: String) -> String:
	var out := PackedStringArray()
	for l: Label3D in cp._dials[id]["figures"]:
		out.append(l.text)
	return " ".join(out)


## The weapons display's rows: pod, rounds and the bars' values.
static func _ck_pod_rows(cp: Cockpit) -> String:
	var out := ""
	for row: Dictionary in cp._pod_rows:
		out += ", %s %s (belt %.2f, heat %.2f)" % [row["id"], (row["count"] as Label3D).text,
			float((row["ammo"] as MeshInstance3D).get_instance_shader_parameter("value")), float((row["heat"] as MeshInstance3D).get_instance_shader_parameter("value"))]
	return out


## The big red button: B flips its cover up and presses it, and the blast goes off.
func _ck_button(m: MissionLevel, shots: bool) -> void:
	var ship := m.ship
	var cp := ship.cockpit
	var p := m.local_player
	_ck_look(m, cp.button_local())
	await wait(0.3)
	Input.action_press("emergency")
	await wait(0.18)
	Input.action_release("emergency")
	var cover := cp._cover.rotation.x
	var cap := cp._button_cap.position.y
	await _shot_if(shots, "ck12_button")
	await wait(0.3)
	print("[autotest] big red button (B): cover %.2f rad open, button down %.3f m; blast cooldown %.1f s" % [-cover, 0.025 - cap, ship.blast_cd])
	await wait(1.6)
	print("[autotest] after the press: cover %.2f rad" % -cp._cover.rotation.x)
	p._pilot_look = Vector2(0.0, Cockpit.LOOK_REST)
	ship.blast_cd = 0.0
	ship.shield_down = false
	ship.shield = ship.max_shield
	ship.hull = ship.max_hull


## Turn the pilot's head to look at ship-local point q.
static func _ck_look(m: MissionLevel, q: Vector3) -> void:
	var cp := m.ship.cockpit
	var to := cp.transform.basis.inverse() * (q - cp.eye_local())
	m.local_player._pilot_look = Vector2(atan2(-to.x, -to.z), atan2(to.y, Vector2(to.x, to.z).length()))


## In the seat, looking at the autopilot switch or the big red button shows its key over it and LMB
## presses it; looking elsewhere shows nothing.
func _ck_hover(m: MissionLevel, shots: bool) -> void:
	var ship := m.ship
	var cp := ship.cockpit
	var p := m.local_player
	var auto0 := ship.autopilot
	_ck_look(m, cp.control_local("auto"))
	await wait(0.4)
	var hov_auto := cp.hovered
	var hint_auto := cp._hint.text if cp._hint.visible else "(none)"
	await _shot_if(shots, "ck12b_look_autopilot")
	await _ck_click()
	var auto1 := ship.autopilot
	p._pilot_look = Vector2(0.0, 0.3)
	await wait(0.3)
	var away := cp.hovered if cp.hovered != "" else "(nothing)"
	_ck_look(m, cp.control_local("blast"))
	await wait(0.4)
	var hov_blast := cp.hovered
	var hint_blast := cp._hint.text if cp._hint.visible else "(none)"
	await _shot_if(shots, "ck12c_look_button")
	await _ck_click()
	var cover := -cp._cover.rotation.x
	await wait(0.3)
	print("[autotest] looking at the autopilot switch: '%s', key shown '%s'; LMB: autopilot %s -> %s; looking up: %s; at the red button: '%s', key shown '%s'; LMB: cover %.2f rad open, blast cooldown %.1f s, key now '%s'" % [
		hov_auto, hint_auto, auto0, auto1, away, hov_blast, hint_blast, cover, ship.blast_cd, cp._hint.text])
	ship.autopilot = auto0
	ship.blast_cd = 0.0
	ship.shield_down = false
	ship.shield = ship.max_shield
	ship.hull = ship.max_hull
	ship.fuel = ship.max_fuel
	p._pilot_look = Vector2(0.0, Cockpit.LOOK_REST)
	await wait(1.6)


## A left click (the "fire" action) held for a moment.
func _ck_click() -> void:
	Input.action_press("fire")
	await wait(0.15)
	Input.action_release("fire")
	await wait(0.25)


## The crew can't climb over the dashboard into the nose: a crew member up on the console beside
## the seat, walking and jumping at the glass, stays in the cockpit (and is never put back at a
## spawn point).
func _ck_barrier(m: MissionLevel, _shots: bool) -> void:
	var ship := m.ship
	var cp := ship.cockpit
	var p := m.local_player
	p.exit_station(true)
	await wait(0.3)
	var out := PackedStringArray()
	for s: float in [-1.0, 1.0]:
		p.position = cp.transform * Vector3(s * 0.45, 0.62, 0.5)
		p.velocity = Vector3.ZERO
		p.look_yaw = 0.0
		p.look_pitch = 0.0
		p.reset_physics_interpolation()
		var front := INF
		var jumps := 0
		var last := p.position
		Input.action_press("move_forward")
		for i in 150:
			if i % 30 == 0:
				Input.action_press("jump")
			elif i % 30 == 10:
				Input.action_release("jump")
				jumps += 1
			await get_tree().physics_frame
			if p.position.distance_to(last) > 1.0:
				jumps = -1000
			last = p.position
			front = minf(front, (cp.transform.affine_inverse() * p.position).z)
		Input.action_release("move_forward")
		Input.action_release("jump")
		var at := cp.transform.affine_inverse() * p.position
		out.append("%s console: nearest the glass z %.2f (the barrier's back is 0), ended at z %.2f height %.2f%s" % ["left" if s < 0.0 else "right",
			front, at.z, at.y, ", PUT BACK AT A SPAWN POINT" if jumps < 0 else ""])
	print("[autotest] climbing over the dashboard: %s" % "; ".join(out))
	ship.request_station.rpc_id(1, "pilot")
	await wait(0.8)


## The motion tracker warns of an ambush AMBUSH_WARNING seconds before the aliens appear.
func _ck_ambush(m: MissionLevel, shots: bool) -> void:
	var ship := m.ship
	_clear_aliens()
	await wait(0.3)
	ship.hostility = 0.3
	await wait(0.3)
	# The aliens already about (roaming the tunnel, hatching from nests) don't count.
	var before := {}
	for a in get_tree().get_nodes_in_group("aliens"):
		before[a.get_instance_id()] = true
	m._director_t = 0.0
	var t0 := Time.get_ticks_msec()
	var warned_at := -1.0
	var spawned_at := -1.0
	var hud_lines := PackedStringArray()
	var shown := 0.0
	var terminal := ""
	var shot_taken := false
	while Time.get_ticks_msec() - t0 < 12000 and spawned_at < 0.0:
		await get_tree().physics_frame
		var t := (Time.get_ticks_msec() - t0) / 1000.0
		if warned_at < 0.0 and ship.contact_warning() > 0.0:
			warned_at = t
		if m.hud._ambush.visible:
			shown += get_physics_process_delta_time()
			if not m.hud._ambush.text in hud_lines:
				hud_lines.append(m.hud._ambush.text)
			if terminal.is_empty():
				terminal = " | ".join(ship.pilot_status())
		if shots and not shot_taken and warned_at >= 0.0 and t > warned_at + 2.0:
			shot_taken = true
			await shot("ck13_motion")
		for a in get_tree().get_nodes_in_group("aliens"):
			if not before.has(a.get_instance_id()) and (a as Alien).nest_name == "":
				spawned_at = t
	print("[autotest] ambush at hostility 0.30: motion tracker warning after %.1f s, the pack arrived %.1f s after the warning (want %.0f); the HUD warned for %.1f s: %s; the terminal meanwhile: '%s'; next ambush in %.0f s" % [
		warned_at, spawned_at - warned_at, MissionLevel.AMBUSH_WARNING, shown, " / ".join(hud_lines), terminal, m._director_t])
	_clear_aliens()
	m._director_t = 99999.0
	m._ambush = {}


## The hostility surges once the meter is full: alarm, then aliens in ones and twos, slowly at
## first and faster and faster.
func _ck_surge(m: MissionLevel, shots: bool) -> void:
	var ship := m.ship
	_clear_aliens()
	await wait(0.3)
	var seen := {}
	for a in get_tree().get_nodes_in_group("aliens"):
		seen[a.get_instance_id()] = true
	ship.hostility = 1.0
	var t0 := Time.get_ticks_msec()
	var arrivals: Array[float] = []
	var shot_taken := false
	var lamp := 0.0
	var alarm := 0.0
	while Time.get_ticks_msec() - t0 < 55000:
		await get_tree().physics_frame
		var t := (Time.get_ticks_msec() - t0) / 1000.0
		for a in get_tree().get_nodes_in_group("aliens"):
			if seen.has(a.get_instance_id()):
				continue
			seen[a.get_instance_id()] = true
			# The swarm, not nest hatchlings; they are only counted, so they never pile up to the cap.
			if (a as Alien).nest_name == "":
				arrivals.append(t)
				a.queue_free()
		lamp = maxf(lamp, (ship.cockpit._lamps["surge"]["mat"] as StandardMaterial3D).emission_energy_multiplier)
		alarm = maxf(alarm, ((ship._int["alarms"] as Array)[0] as OmniLight3D).light_energy)
		if shots and not shot_taken and t > 3.0:
			shot_taken = true
			await shot("ck14_surge")
	var marks := PackedStringArray()
	for a in arrivals:
		marks.append("%.0f" % a)
	print("[autotest] surging (stage %s, HUD '%s', SURGE lamp peak %.1f, alarm lights peak %.2f): %d aliens in 55 s, arriving at %s s" % [
		Mothership.HOSTILITY_STAGES[ship.hostility_stage()], m.hud._hostility_label.text, lamp, alarm, arrivals.size(), " ".join(marks)])
	ship.hostility = 0.0
	await wait(0.3)
	_clear_aliens()
	m._director_t = 99999.0


## Scraping along the rock: sparks, the SCRAPE lamp and no damage.
func _ck_scrape(m: MissionLevel, shots: bool) -> void:
	var ship := m.ship
	ship.autopilot = false
	await _put_ship(m, 620.0)
	# Find the rock to port and slide the ship along it.
	var space := ship.get_world_3d().direct_space_state
	var from := ship.global_position + Vector3(0, 1.4, 0)
	var left := -ship.global_basis.x
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + left * 60.0, Game.LAYER_CAVE))
	if hit.is_empty():
		print("[autotest] FAIL: no rock to port")
		return
	var reach := 0.0
	for bx: Array in ship.layout["boxes"]:
		reach = maxf(reach, (bx[1] as Vector3).x * 0.5 + absf((bx[0] as Vector3).x))
	ship.global_position += left * (from.distance_to(hit["position"]) - reach - 0.4)
	ship.reset_physics_interpolation()
	var hull0 := ship.hull
	var shield0 := ship.shield
	var scraped := false
	ship.throttle = 0.5
	# Drift gently into the rock (well under the speed that knocks the hull) while flying on.
	for i in 150:
		ship.velocity += left * (1.0 - ship.velocity.dot(left))
		await get_tree().physics_frame
		if ship.scraping():
			scraped = true
	print("[autotest] slid along the rock: scraping %s, hull %.0f -> %.0f, shield %.0f -> %.0f" % [scraped, hull0, ship.hull,
		shield0, ship.shield])
	if shots:
		var cp := ship.cockpit
		var sx := cp.global_transform * cp._screen_xform("port")
		var to := cp.global_basis.inverse() * (sx.origin - cp.global_transform * Cockpit.EYE)
		m.local_player._pilot_look = Vector2(atan2(-to.x, -to.z), atan2(to.y, Vector2(to.x, to.z).length()))
		Input.action_press("aim")
		for i in 40:
			ship.velocity += left * (1.0 - ship.velocity.dot(left))
			await get_tree().physics_frame
		await shot("ck15_scrape_feed")
		Input.action_release("aim")
		m.local_player._pilot_look = Vector2(0.0, Cockpit.LOOK_REST)
	ship.throttle = 0.0
	ship.velocity = Vector3.ZERO
	ship.autopilot = true
	await _put_ship(m, 600.0)


## The gun pod's barrels smoke more the hotter they are.
func _ck_smoke(m: MissionLevel, shots: bool) -> void:
	var ship := m.ship
	var pod: GunPod = ship.turrets["gun_l"]
	var gi := ship.gun_index("gun_l")
	var rows := PackedStringArray()
	for h: float in [0.2, 0.45, 0.7, 1.0]:
		_gp_set(ship, gi, GunPod.BELT, h)
		await wait(0.15)
		rows.append("heat %.2f: smoke %s ratio %.2f, alpha %.2f, size %.1f-%.1f" % [h, pod._smoke[0].emitting, pod._smoke[0].amount_ratio,
			pod._smoke_pm.color.a, pod._smoke_pm.scale_min, pod._smoke_pm.scale_max])
	print("[autotest] gun pod smoke: %s" % "; ".join(rows))
	if shots:
		# Hot barrels from outside: hold the heat up for a few seconds while the smoke builds.
		var cam := Camera3D.new()
		cam.far = 300.0
		m.add_child(cam)
		for i in 180:
			_gp_set(ship, gi, GunPod.BELT, 1.0)
			cam.global_position = ship.to_global(pod.position + Vector3(-3.6, 1.6, -4.0))
			cam.look_at(ship.to_global(pod.position + Vector3(0, 0.3, -1.4)))
			cam.current = true
			await get_tree().process_frame
		await shot("ck16_pod_smoke_hot")
		_gp_set(ship, gi, GunPod.BELT, 0.35)
		for i in 120:
			cam.global_position = ship.to_global(pod.position + Vector3(-3.6, 1.6, -4.0))
			cam.look_at(ship.to_global(pod.position + Vector3(0, 0.3, -1.4)))
			await get_tree().process_frame
		await shot("ck17_pod_smoke_warm")
		cam.queue_free()
		m.local_player.camera.current = true
	_gp_set(ship, gi, GunPod.BELT, 0.0)


## Every ship's cockpit from the pilot seat (looking ahead, to either side and at the dashboard).
func _ck_ships(shots: bool) -> void:
	var ships := {}
	for id: String in ShipTypes.ORDER:
		ships[id] = {}
	Game.profile["ships"] = ships
	for id: String in ShipTypes.ORDER:
		Game.profile["ship"] = id
		Game.profile_changed.emit()
		await wait(0.3)
		Game.main.start_mission()
		var m: MissionLevel = null
		for i in 900:
			await get_tree().process_frame
			m = Game.mission as MissionLevel
			if m and m.local_ready and m.local_player and m.started and m.ship and m.ship.ship_type == id:
				break
		if m == null or m.ship == null or m.ship.ship_type != id:
			print("[autotest] FAIL: no mission for ", id)
			return
		m._director_t = 99999.0
		await _put_ship(m, 60.0)
		_clear_aliens()
		m.ship.request_station.rpc_id(1, "pilot")
		await wait(1.2)
		var p := m.local_player
		var seen := 0
		for f: Dictionary in m.ship.cockpit._feeds:
			if f["seen"]:
				seen += 1
		print("[autotest] %s cockpit: station '%s', %d of %d feeds rendering, terminal top line '%s'; weapons display rows: %d" % [id, p.station, seen,
			m.ship.cockpit._feeds.size(), m.ship.cockpit._nav.text.split("\n")[0].strip_edges(), m.ship.cockpit._pod_rows.size()])
		# A gun pod that turns all the way round holds its fire while the ship is in its line of fire.
		for g: String in m.ship.gun_stations():
			var pod := m.ship.turrets[g] as GunPod
			if pod == null or not pod.full_traverse:
				continue
			var lines := PackedStringArray()
			for a: Array in [["ahead", Vector2(0.0, 0.0)], ["to port", Vector2(PI / 2.0, 0.0)], ["astern, level", Vector2(PI, 0.05)],
					["astern, 15 deg down", Vector2(PI, -0.26)], ["at the island", Vector2(-2.83, 0.0)], ["astern, past the island", Vector2(-2.6, 0.25)]]:
				lines.append("%s %s" % [a[0], "HELD" if m.ship.fire_masked(g, a[1]) else "fires"])
			print("[autotest] %s %s turns all the way round (yaw %.0f..%.0f, wraps: %.2f -> %.2f); the interrupter: %s" % [id, g, rad_to_deg(pod.yaw_min),
				rad_to_deg(pod.yaw_max), PI + 0.1, pod.clamp_aim(Vector2(PI + 0.1, 0.0)).x, ", ".join(lines)])
		if shots:
			for v: Array in [["ahead", Vector2(0.0, Cockpit.LOOK_REST)], ["left", Vector2(1.2, -0.12)], ["right", Vector2(-1.2, -0.12)]]:
				p._pilot_look = v[1]
				await wait(0.35)
				await shot("ck_seat_%s_%s" % [id, v[0]])
		m.abort_mission()
		for i in 100:
			await wait(0.1)
			var lvl: Node = Game.main.current_level()
			if lvl and lvl.name == "Homebase":
				break
		await wait(0.5)


## The scout's cockpit: both scouts' models (clear of every mothership's docks: the belly above, the
## ground or the deck below) and what the pilot sees from the eye; then in a mission the pilot's
## first-person view and panels, the cannons (rate, heat, the magazine and its reload, overheating),
## the booster (speed, heat, the view widening), locking on and the missiles, the cracks and the
## critical alarm, the homing needle and the dock's marker, docking (rearmed), which sounds come
## through muffled from inside the ship, a gun pod and the scout, and the Vanguard's combat scouts
## (fighter_check: no screenshots).
func _run_fighter(shots: bool) -> void:
	await _ft_studio(shots)
	var m := await _start_solo_mission()
	if m == null:
		print("[autotest] FAIL: mission not ready")
		return
	var ship := m.ship
	var tough := ship.stats.duplicate()
	tough["crew_hp"] = 99999.0
	tough["collateral"] = 0.0
	tough["scout_hp"] = 400.0
	ship.stats = tough
	ship.max_hull = 99999.0
	ship.hull = 99999.0
	m._director_t = 99999.0
	# Well clear of the waystations: their guns shoot every alien near them.
	var s := 70.0
	while not m.cave.stations_in(s - 220.0, s + 220.0).is_empty() and s < 4000.0:
		s += 20.0
	print("[autotest] the mothership waits at %.0f m down the tunnel" % s)
	await _put_ship(m, s)
	_clear_aliens()
	await _ft_launch(m, shots)
	await _ft_cannons(m, shots)
	await _ft_boost(m, shots)
	await _ft_missiles(m, shots)
	await _ft_damage(m, shots)
	await _ft_dock(m, shots)
	await _ft_muffle(m)
	m.abort_mission()
	for i in 100:
		await wait(0.1)
		var lvl: Node = Game.main.current_level()
		if lvl and lvl.name == "Homebase":
			break
	await _ft_vanguard(shots)


## Both scouts in a lit studio: how high and low they reach against every mothership's docks, what
## the pilot sees from the eye (the panels' and the sight's bearings, the glass round them), and
## (with shots) each from outside.
func _ft_studio(shots: bool) -> void:
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
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	world.add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 50.0
	cam.near = 0.02
	world.add_child(cam)
	cam.current = true
	for style: String in ["standard", "combat"]:
		var root := Node3D.new()
		world.add_child(root)
		Scout.build_model(root, style)
		var box := _ft_bounds(root)
		print("[autotest] %s scout: from %.2f to %.2f m high, %.2f to %.2f long, %.2f m wide" % [style, box.position.y, box.end.y, box.position.z,
			box.end.z, box.size.x])
		for id: String in ShipTypes.ORDER:
			var t := ShipTypes.get_type(id)
			if str(t["scout_style"]) != style:
				continue
			for sid: String in t["scouts"]:
				var dock: Vector3 = t["by_id"][sid]["dock"]
				if (t["by_id"][sid]["launch"] as Vector3).y < 0.0:
					# The dock's plate under the belly (ShipBuilder._common_fittings) and the ground once landed.
					var plate := ShipBuilder.bottom_y(t["sections"], dock.z) - 0.1
					print("[autotest]   %s %s under the belly: %.2f m clear of the plate above, %.2f m clear of the ground when landed" % [id, sid,
						plate - (dock.y + box.end.y), dock.y + box.position.y + 4.2])
				else:
					print("[autotest]   %s %s on deck: lowest point %.2f m off the pad" % [id, sid, box.position.y + 0.57])
		if shots:
			for v: Array in [["front", Vector3(-3.2, 1.6, -5.5), Vector3(0, 0.2, -0.6)], ["side", Vector3(-6.0, 0.8, 0.5), Vector3(0, 0.1, 0.0)],
					["above", Vector3(1.5, 4.5, 2.5), Vector3(0, 0.0, -0.3)], ["seat", Vector3(1.4, 1.5, 0.9), Vector3(0, 0.35, -0.8)]]:
				cam.global_position = v[1]
				cam.look_at(v[2])
				await wait(0.15)
				await shot("f00_%s_%s" % [style, v[0]])
		root.queue_free()
		await wait(0.1)
	world.queue_free()
	var parts := PackedStringArray()
	for p: Array in [["left panel", ScoutCockpit.PANEL_L], ["right panel", ScoutCockpit.PANEL_R], ["front panel", ScoutCockpit.FASCIA],
			["gunsight", ScoutCockpit.SIGHT]]:
		var d: Vector3 = (p[1] as Vector3) - ScoutCockpit.EYE
		parts.append("%s %.0f deg %s and %.0f deg down, %.2f m" % [p[0], absf(rad_to_deg(atan2(d.x, -d.z))), "left" if d.x < 0.0 else "right",
			-rad_to_deg(atan2(d.y, Vector2(d.x, d.z).length())), d.length()])
	var glass := PackedStringArray()
	for g: Array in [["ahead", Vector3.FORWARD], ["45 left", Vector3(-1, 0, -1)], ["90 left", Vector3.LEFT], ["30 up", Vector3(0, 0.58, -1)],
			["straight up", Vector3.UP], ["20 down", Vector3(0, -0.36, -1)]]:
		glass.append("%s %.2f m" % [g[0], ScoutCockpit.glass_distance((g[1] as Vector3).normalized())])
	print("[autotest] from the pilot's eye: %s; the canopy %s (the view: %.0f deg high)" % [", ".join(parts), ", ".join(glass), ScoutCockpit.FOV])
	# Each side panel's corners: inside the canopy, and on screen at 16:9 (1 is the screen's edge).
	var ty := tan(deg_to_rad(ScoutCockpit.FOV) * 0.5)
	var tx := ty * 16.0 / 9.0
	for p: Vector3 in [ScoutCockpit.PANEL_L, ScoutCockpit.PANEL_R]:
		var xf := ScoutCockpit.facing_eye(p)
		var inside := true
		var worst := Vector2.ZERO
		for c: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			var q := xf * Vector3(c.x * ScoutCockpit.PANEL_SIZE.x * 0.5, c.y * ScoutCockpit.PANEL_SIZE.y * 0.5, 0.0)
			inside = inside and ScoutCockpit.inside(q)
			var d := q - ScoutCockpit.EYE
			worst = worst.max(Vector2(absf(d.x / -d.z) / tx, absf(d.y / -d.z) / ty))
		print("[autotest] %s panel: corners inside the canopy %s, on screen out to %.2f across and %.2f down (1 = the edge)" % [
			"left" if p.x < 0.0 else "right", inside, worst.x, worst.y])


## The box round everything visible under `root` (in its frame).
func _ft_bounds(root: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for n in root.find_children("*", "VisualInstance3D", true, false):
		var vi := n as VisualInstance3D
		if not vi.visible:
			continue
		var b := root.global_transform.affine_inverse() * vi.global_transform * vi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box


## Into the scout: first person at its cockpit's eye, the HUD's station panel and crosshair gone,
## the crew member's body hidden; out from under the ship, what the panels show.
func _ft_launch(m: MissionLevel, shots: bool) -> void:
	var ship := m.ship
	var p := m.local_player
	ship.request_station.rpc_id(1, "scout")
	await wait(1.0)
	var sc: Scout = m.scouts[0]
	var eye := sc.get_global_transform_interpolated() * ScoutCockpit.EYE
	print("[autotest] in the scout: station '%s', scout flying %s, camera %.3f m from the cockpit's eye, fov %.0f; HUD station panel %s, crosshair %s; the pilot's body shown %s, the figure in the cockpit (for others) %s" % [
		p.station, sc.state == Scout.State.FLYING, p.camera.global_position.distance_to(eye), p.camera.fov, m.hud._station_panel.visible,
		m.hud._crosshair.visible, p._body.visible, sc._figure.visible])
	_scout_steer(m, m.cave.center3(-sc.global_position.z + 60.0))
	Input.action_press("move_forward")
	await wait(1.6)
	Input.action_release("move_forward")
	await wait(0.6)
	print("[autotest] panels: thrust '%s', hull '%s', cargo '%s', rounds '%s' (%s), missiles '%s', dock '%s' / '%s'" % [_ft_text(sc, "thrust"),
		_ft_text(sc, "hull"), _ft_text(sc, "cargo"), _ft_text(sc, "ammo"), _ft_text(sc, "gun"), _ft_text(sc, "msl"), _ft_text(sc, "dock"),
		_ft_text(sc, "dock2")])
	await _shot_if(shots, "f01_cockpit")


func _ft_text(sc: Scout, id: String) -> String:
	return (sc.cockpit._texts[id] as Label3D).text


## The cannons: the rate of fire and the heat, the magazine running dry and reloading, firing at
## full heat (they cut out until cooled down).
func _ft_cannons(m: MissionLevel, shots: bool) -> void:
	var sc: Scout = m.scouts[0]
	var ammo0 := sc.ammo
	var heat0 := sc.heat
	Input.action_press("fire")
	await wait(1.0)
	await _shot_if(shots, "f02_firing")
	await wait(1.0)
	Input.action_release("fire")
	print("[autotest] cannons for 2 s: rounds %d -> %d (%.1f a second), heat %.2f -> %.2f, rounds in the air %d" % [ammo0, sc.ammo,
		(ammo0 - sc.ammo) / 2.0, heat0, sc.heat, m.projectiles._shots.size()])
	sc.ammo = 3
	Input.action_press("fire")
	await wait(0.7)
	Input.action_release("fire")
	await wait(0.2)
	print("[autotest] magazine dry: rounds %d, reloading (%.1f s left), the screen '%s' '%s', RELOAD lamp %.1f" % [sc.ammo, sc.reload_left,
		_ft_text(sc, "ammo"), _ft_text(sc, "gun"), (sc.cockpit._lamps["load"]["mat"] as StandardMaterial3D).emission_energy_multiplier])
	await _shot_if(shots, "f03_reload")
	await wait(Scout.RELOAD_TIME + 0.3)
	print("[autotest] after the reload: rounds %d, reloading %.1f s" % [sc.ammo, sc.reload_left])
	sc.heat = 0.9
	Input.action_press("fire")
	var t_hot := 0.0
	while not sc.overheat and t_hot < 3.0:
		await get_tree().physics_frame
		t_hot += 1.0 / 60.0
	var rounds := sc.ammo
	var notes := {}
	var lamp := 0.0
	for i in 40:
		await get_tree().process_frame
		notes[_ft_text(sc, "gun")] = true
		lamp = maxf(lamp, (sc.cockpit._lamps["heat"]["mat"] as StandardMaterial3D).emission_energy_multiplier)
	print("[autotest] firing from 90%% heat: overheated after %.2f s, then rounds fired %d (trigger still held), heat %.2f, the screen shows %s, heat lamp up to %.1f" % [
		t_hot, rounds - sc.ammo, sc.heat, "/".join(notes.keys()), lamp])
	await _shot_if(shots, "f04_overheat")
	Input.action_release("fire")
	Input.action_press("sprint")
	await wait(0.4)
	print("[autotest] booster while overheated: burning %s" % sc.boosting)
	Input.action_release("sprint")
	var t := 0.0
	while sc.overheat and t < 12.0:
		await wait(0.1)
		t += 0.1
	print("[autotest] cooled down to %.2f in another %.1f s; overheated %s (back on at %.2f)" % [sc.heat, t, sc.overheat, Scout.HEAT_RESUME])


## The booster: the speed straight ahead, the heat, the view widening and shaking; and after.
func _ft_boost(m: MissionLevel, shots: bool) -> void:
	var sc: Scout = m.scouts[0]
	var cam := m.local_player.camera
	sc.heat = 0.0
	_scout_steer(m, m.cave.center3(-sc.global_position.z + 80.0))
	await wait(0.5)
	var fov0 := cam.fov
	Input.action_press("sprint")
	var peak := 0.0
	for i in 15:
		await wait(0.1)
		_scout_steer(m, m.cave.center3(-sc.global_position.z + 80.0))
		peak = maxf(peak, sc.velocity.length())
	await _shot_if(shots, "f05_boost")
	print("[autotest] boosting 1.5 s: top speed reached %.1f m/s (cruise %.1f, boost %.1f), heat %.2f, fov %.0f -> %.0f, rumble %.2f, thrust gauge '%s'" % [
		peak, sc.top_speed(), sc.top_speed() * Scout.BOOST, sc.heat, fov0, cam.fov, sc.cockpit._rumble, _ft_text(sc, "thrust")])
	Input.action_release("sprint")
	await wait(1.5)
	print("[autotest] 1.5 s after: speed %.1f m/s, fov %.0f, heat %.2f, hull %.0f" % [sc.velocity.length(), cam.fov, sc.heat, sc.hp])


## Locking on (RMB held on a spitter ahead: the crosshair on the glass closes in) and the missiles:
## one a click, homing in; the second at another; a third click with none left only buzzes.
func _ft_missiles(m: MissionLevel, shots: bool) -> void:
	var sc: Scout = m.scouts[0]
	# Just ahead of the mothership, well clear of the waystation's guns (they shoot every alien).
	var s0 := -m.ship.global_position.z + 25.0
	for k in 2:
		_clear_aliens()
		sc.global_position = m.cave.center3(s0) + Vector3(0, 2.0, 0)
		sc.velocity = Vector3.ZERO
		sc.reset_physics_interpolation()
		_scout_steer(m, m.cave.center3(s0 + 40.0) + Vector3(0, 2.0, 0))
		await wait(0.6)
		var alien := m.spawn_alien(Alien.Kind.SPITTER, m.cave.center3(s0 + 38.0) + Vector3(0, 2.0, 0)) as Alien
		var name_s := str(alien.name)
		await wait(0.2)
		Input.action_press("aim")
		var t := 0.0
		var locked_at := -1.0
		var seek_shot := false
		while t < 3.0 and is_instance_valid(alien):
			_scout_steer(m, alien.global_position)
			await get_tree().physics_frame
			t += 1.0 / 60.0
			if locked_at < 0.0 and sc.cockpit.lock >= 1.0:
				locked_at = t
			if k == 0 and not seek_shot and t > 0.45:
				seek_shot = true
				print("[autotest] seeking: lock %.2f, crosshair shown %s, '%s'" % [sc.cockpit.lock, sc.cockpit._lock_mark.visible, sc.cockpit._lock_label.text])
				await _shot_if(shots, "f06_seek")
			if locked_at >= 0.0 and t > locked_at + 0.3:
				break
		print("[autotest] missile %d: target %s, locked after %.2f s (LOCK_TIME %.1f), crosshair '%s', LOCK lamp %.1f" % [k + 1,
			sc.cockpit.target.name if is_instance_valid(sc.cockpit.target) else "none", locked_at, Scout.LOCK_TIME, sc.cockpit._lock_label.text,
			(sc.cockpit._lamps["lock"]["mat"] as StandardMaterial3D).emission_energy_multiplier])
		if k == 0:
			await _shot_if(shots, "f07_locked")
		var before := sc.missiles
		await _ck_click()
		var flying := 0
		for s: Dictionary in m.projectiles._shots:
			if s["kind"] == "missile":
				flying += 1
		var hung := []
		for n: Node3D in sc._parts["missiles"]:
			hung.append(n.visible)
		print("[autotest] fired: missiles %d -> %d, in flight %d, on the pylons %s, panel '%s'" % [before, sc.missiles, flying, hung,
			_ft_text(sc, "msl")])
		if k == 0:
			await _shot_if(shots, "f08_missile")
		t = 0.0
		while t < 4.0 and is_instance_valid(alien) and m.enemy_root.has_node(name_s):
			await wait(0.1)
			t += 0.1
		print("[autotest] the spitter %s after %.1f s" % ["is dead" if not m.enemy_root.has_node(name_s) else "LIVES", t])
		Input.action_release("aim")
	# Out of missiles: a click only buzzes.
	sc.missiles = 0
	var alien2 := m.spawn_alien(Alien.Kind.SPITTER, m.cave.center3(s0 + 35.0) + Vector3(0, 2.0, 0)) as Alien
	Input.action_press("aim")
	for i in 90:
		if is_instance_valid(alien2):
			_scout_steer(m, alien2.global_position)
		await get_tree().physics_frame
	await _ck_click()
	print("[autotest] a click with none left (lock %.2f): missiles %d, the drawing's missiles %s, panel '%s'" % [sc.cockpit.lock, sc.missiles,
		sc.cockpit._missile_draw.get_instance_shader_parameter("loaded"), _ft_text(sc, "msl")])
	Input.action_release("aim")
	_clear_aliens()


## Hull damage: cracks spread over the canopy; critical: the red light pulses and the HULL lamp
## flashes.
func _ft_damage(m: MissionLevel, shots: bool) -> void:
	var sc: Scout = m.scouts[0]
	for v: Array in [[0.6, "f09_cracks"], [0.2, "f10_critical"]]:
		sc.hp = sc.max_hp * float(v[0])
		await wait(0.6)
		var sizes := PackedStringArray()
		for c in sc.cockpit._cracks_sent:
			sizes.append("%.2f" % c.w)
		var light := 0.0
		for i in 30:
			light = maxf(light, sc.cockpit._alarm_light.light_energy)
			await get_tree().process_frame
		print("[autotest] hull at %d%%: %d cracks (sizes %s), alarm light up to %.2f, HULL lamp %.1f, hull figure '%s'" % [int(float(v[0]) * 100.0),
			sc.cockpit._cracks_shown, ", ".join(sizes), light, (sc.cockpit._lamps["hull"]["mat"] as StandardMaterial3D).emission_energy_multiplier,
			_ft_text(sc, "hull")])
		await _shot_if(shots, str(v[1]))
	sc.hp = sc.max_hp
	await wait(0.3)
	print("[autotest] repaired: %d cracks, alarm light %.2f" % [sc.cockpit._cracks_shown, sc.cockpit._alarm_light.light_energy])


## The homing needle and the dock's marker on the glass, then docking: rearmed and cooled, the pilot
## back aboard.
func _ft_dock(m: MissionLevel, shots: bool) -> void:
	var sc: Scout = m.scouts[0]
	var p := m.local_player
	sc.heat = 0.5
	sc.ammo = 10
	var dock := sc.dock_transform().origin
	sc.global_position = dock + m.ship.global_basis * Vector3(0, -7.0, -16.0)
	sc.velocity = Vector3.ZERO
	sc.reset_physics_interpolation()
	_scout_steer(m, dock)
	await wait(1.0)
	_scout_steer(m, dock)
	print("[autotest] facing the dock %.0f m off: needle %.2f rad, '%s' / '%s', the marker on the glass %s ('%s')" % [sc.global_position.distance_to(dock),
		sc.cockpit._dock_dial.get_instance_shader_parameter("bearing"), _ft_text(sc, "dock"), _ft_text(sc, "dock2"), sc.cockpit._dock_mark.visible,
		sc.cockpit._dock_label.text])
	await _shot_if(shots, "f11_dock_marker")
	sc.global_position = dock + m.ship.global_basis * Vector3(0, -3.0, 0.0)
	sc.reset_physics_interpolation()
	await wait(0.3)
	await _tap("interact")
	await wait(0.6)
	print("[autotest] docked %s: missiles %d, rounds %d, heat %.2f; the pilot's station '%s', body shown %s" % [sc.state == Scout.State.DOCKED,
		sc.missiles, sc.ammo, sc.heat, p.station, p._body.visible])


## Which sounds come through muffled: aboard, in a gun pod, at the pilot seat and in the scout, a
## sound well outside the ship, one aboard, one at the pod and one at the scout.
func _ft_muffle(m: MissionLevel) -> void:
	var ship := m.ship
	var p := m.local_player
	var outside := ship.to_global(Vector3(0, 0, -45.0))
	var aboard := ship.to_global((ship.spawn_points()[0] as Vector3) + Vector3(0, 1.0, 0))
	var pod := (ship.turrets["gun_l"] as Node3D).global_position
	var lines := PackedStringArray()
	for st: String in ["", "gun_l", "pilot", "scout"]:
		if p.station != "":
			p.exit_station(true)
			await wait(0.4)
		if st != "":
			ship.request_station.rpc_id(1, st)
			await wait(0.8)
		var scout_at := m.scouts[0].global_position
		Sfx.play("hit", outside, -60.0)
		await get_tree().process_frame
		var pooled: AudioStreamPlayer3D = Sfx._pool3d[(Sfx._next3d + Sfx.POOL_3D - 1) % Sfx.POOL_3D]
		lines.append("%s (listener '%s'): outside -> %s (a sound playing out there: %s), aboard -> %s, at the pod -> %s, at the scout -> %s" % [
			st if st != "" else "walking aboard", Sfx.listener_space(), Sfx.bus_for(outside), pooled.bus, Sfx.bus_for(aboard), Sfx.bus_for(pod),
			Sfx.bus_for(scout_at)])
	print("[autotest] muffled sounds:\n  %s" % "\n  ".join(lines))
	if p.station != "":
		m.scouts[0].request_dock.rpc_id(1)
		p.exit_station(true)
		await wait(0.4)
	var bus := AudioServer.get_bus_index(Sfx.HULL_BUS)
	var glass := AudioServer.get_bus_index(Sfx.GLASS_BUS)
	print("[autotest] buses: Hull #%d (low-pass %.0f Hz, %.0f dB), Glass #%d (low-pass %.0f Hz, %.0f dB), both into %s" % [bus,
		(AudioServer.get_bus_effect(bus, 0) as AudioEffectLowPassFilter).cutoff_hz, AudioServer.get_bus_volume_db(bus), glass,
		(AudioServer.get_bus_effect(glass, 0) as AudioEffectLowPassFilter).cutoff_hz, AudioServer.get_bus_volume_db(glass), AudioServer.get_bus_send(bus)])


## Multiplayer scout test, host side (run --autotest=join_scout in a second instance): park the
## ship clear of the waystations, keep a spitter in front of the client's scout while it flies, and
## report the scout as the server has it.
func _run_host_scout() -> void:
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
	await wait(1.5)
	Game.main.start_mission()
	var m: MissionLevel = null
	for i in 600:
		await get_tree().process_frame
		m = Game.mission as MissionLevel
		if m and m.started and m.local_player:
			break
	m._director_t = 99999.0
	var tough := m.ship.stats.duplicate()
	tough["scout_hp"] = 400.0
	m.ship.stats = tough
	var s := 70.0
	while not m.cave.stations_in(s - 220.0, s + 220.0).is_empty() and s < 4000.0:
		s += 20.0
	await _put_ship(m, s)
	_clear_aliens()
	print("[autotest] host: the ship waits at %.0f m" % s)
	var t := 0.0
	while t < 40.0:
		await wait(0.5)
		t += 0.5
		var sc: Scout = m.scouts[0]
		if sc.state == Scout.State.FLYING and get_tree().get_nodes_in_group("aliens").is_empty():
			m.spawn_alien(Alien.Kind.SPITTER, m.cave.center3(-sc.global_position.z + 35.0) + Vector3(0, 1.5, 0))
			print("[autotest] host: a spitter on the tunnel's middle 35 m on from the client's scout")
		if int(t * 2.0) % 8 == 0:
			print("[autotest] host sees the scout: state %d, pilot %s, rounds %d, heat %.2f, missiles %d, boosting %s, speed %.1f, hull %.0f" % [sc.state,
				Net.player_name(sc.pilot) if sc.pilot != 0 else "-", sc.ammo, sc.heat, sc.missiles, sc.boosting, sc.velocity.length(), sc.hp])
	m.abort_mission()
	await wait(6.0)


## Multiplayer scout test, client side: fly the scout from a client. Its own view turns at once (the
## server's turn arrives later), the cannons, the booster, locking on to the host's spitter and a
## missile at it, then back to the bay.
func _run_join_scout() -> void:
	Net.local_name = "ClientScout"
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
	await wait(4.0)
	var p := m.local_player
	m.ship.request_station.rpc_id(1, "scout")
	await wait(1.0)
	var sc := m.scout_at("scout")
	print("[autotest] client in the scout: station '%s', flying %s, the local pilot %s, camera %.3f m from its eye, fov %.0f" % [p.station,
		sc.state == Scout.State.FLYING, sc.local_pilot(), p.camera.global_position.distance_to(sc.get_global_transform_interpolated() * ScoutCockpit.EYE),
		p.camera.fov])
	Input.action_press("move_forward")
	await wait(1.0)
	Input.action_release("move_forward")
	var yaw0 := sc.global_rotation.y
	var server0 := sc.net_rot.y
	p.station_aim.x += 0.8
	await wait(0.12)
	print("[autotest] client 0.12 s after a 0.8 rad turn: its scout turned %.2f rad, the server's (as synced so far) %.2f rad" % [
		absf(angle_difference(yaw0, sc.global_rotation.y)), absf(angle_difference(server0, sc.net_rot.y))])
	await wait(1.0)
	print("[autotest] client 1.1 s after: its scout %.2f rad, the server's %.2f rad" % [absf(angle_difference(yaw0, sc.global_rotation.y)),
		absf(angle_difference(server0, sc.net_rot.y))])
	p.station_aim.x -= 0.8
	await wait(1.0)
	var ammo0 := sc.ammo
	Input.action_press("fire")
	await wait(1.0)
	Input.action_release("fire")
	await wait(0.3)
	print("[autotest] client fired 1 s: rounds %d -> %d, heat %.2f (synced)" % [ammo0, sc.ammo, sc.heat])
	var alien: Alien = null
	for i in 60:
		await wait(0.1)
		var list := get_tree().get_nodes_in_group("aliens")
		if not list.is_empty():
			alien = list[0] as Alien
			break
	if alien == null:
		print("[autotest] FAIL: client saw no spitter")
	else:
		var name_s := str(alien.name)
		Input.action_press("aim")
		var t := 0.0
		while t < 4.0 and is_instance_valid(alien) and sc.cockpit.lock < 1.0:
			_ft_steer(p, sc, alien.global_position)
			await get_tree().physics_frame
			t += 1.0 / 60.0
		print("[autotest] client lock on %s after %.2f s: %.2f" % [name_s, t, sc.cockpit.lock])
		var before := sc.missiles
		var copies := 0
		Input.action_press("fire")
		for i in 24:
			await get_tree().process_frame
			for s: Dictionary in m.projectiles._shots:
				if s["kind"] == "missile":
					copies = maxi(copies, 1)
		Input.action_release("fire")
		await wait(0.3)
		print("[autotest] client fired a missile: missiles %d -> %d (synced), a copy seen in flight %s; the scout %.1f m from rock" % [before,
			sc.missiles, copies > 0, -m.cave.sdf(sc.global_position)])
		t = 0.0
		while t < 5.0 and m.enemy_root.has_node(name_s):
			await wait(0.1)
			t += 0.1
		print("[autotest] client: the spitter %s after %.1f s" % ["is dead" if not m.enemy_root.has_node(name_s) else "LIVES", t])
		Input.action_release("aim")
	Input.action_press("sprint")
	await wait(1.2)
	print("[autotest] client boosting: speed %.1f m/s (synced), view fov %.0f" % [sc.net_vel.length(), p.camera.fov])
	Input.action_release("sprint")
	await wait(0.5)
	p.exit_station(true)
	await wait(1.0)
	print("[autotest] client left the scout: station '%s', scout docked %s, missiles %d" % [p.station, sc.state == Scout.State.DOCKED, sc.missiles])
	for i in 300:
		await wait(0.1)
		var lvl: Node = Game.main.current_level()
		if lvl and lvl.name == "Homebase":
			break


## Steer a scout the local crew member flies at a point (like _scout_steer, for any scout).
func _ft_steer(p: CrewMember, sc: Scout, target: Vector3) -> void:
	var d := (target - sc.global_position).normalized()
	p.station_aim = Vector2(atan2(-d.x, -d.z), asin(clampf(d.y, -1.0, 1.0)))


## The Vanguard's combat scouts launch up off the flight deck with the same cockpit.
func _ft_vanguard(shots: bool) -> void:
	var ships := {}
	for id: String in ShipTypes.ORDER:
		ships[id] = {}
	Game.profile["ships"] = ships
	Game.profile["ship"] = "vanguard"
	Game.profile_changed.emit()
	await wait(0.3)
	Game.main.start_mission()
	var m: MissionLevel = null
	for i in 900:
		await get_tree().process_frame
		m = Game.mission as MissionLevel
		if m and m.local_ready and m.local_player and m.started and m.ship and m.ship.ship_type == "vanguard":
			break
	if m == null or m.ship == null or m.ship.ship_type != "vanguard":
		print("[autotest] FAIL: no Vanguard mission")
		return
	m._director_t = 99999.0
	await _put_ship(m, 70.0)
	_clear_aliens()
	m.ship.request_station.rpc_id(1, "scout2")
	await wait(1.2)
	var sc := m.scout_at("scout2")
	print("[autotest] Vanguard scout B: flying %s, style %s, camera %.3f m from its eye, %.1f m above the deck after 1.2 s" % [sc.state == Scout.State.FLYING,
		sc.style, m.local_player.camera.global_position.distance_to(sc.get_global_transform_interpolated() * ScoutCockpit.EYE),
		m.ship.to_local(sc.global_position).y - 5.05])
	await _shot_if(shots, "f12_vanguard")
	m.local_player.exit_station(true)
	await wait(0.4)


# --- The soldier -------------------------------------------------------------------------------

## The soldier's experience (Backlogg.md "Space soldiers"): the helmet and its instruments, the
## weapon's poses and how fast it comes up to fire, each weapon aimed down its sight (is the sight
## in the middle of the view?), the scatter (hip, aimed, building up, on the move) and the speed
## while aiming, casings and dropped magazines, reloading and the empty click, heat weapons
## overheating and venting, the lightning thrower's chain, the Revolver, Submachine Gun, Marksman
## Rifle, Shotgun and Multiple Grenade Launcher (_so_guns), the scanner aboard (static) and in an
## abandoned station, and outside the ship the visor sealing and cracking at critical health
## (soldier_check: no shots).
func _run_soldier(shots: bool) -> void:
	var m := await _start_solo_mission()
	if m == null:
		print("[autotest] FAIL: mission not ready")
		return
	m._director_t = 99999.0
	_clear_aliens()
	var ship := m.ship
	var p := m.local_player
	ship.stats["crew_hp"] = 1500.0
	await wait(0.3)
	await _so_aboard(m, shots)
	await _so_clipping(m, shots)
	await _so_sights(m, shots)
	await _so_scatter(m)
	await _so_casings(m, shots)
	await _so_heat(m, shots)
	await _so_lightning(m, shots)
	await _so_guns(m, shots)
	await _so_scanner_aboard(m, shots)
	await _so_outside(m, shots)
	p.set_weapon(CrewWeapons.DEFAULT)


## Only the Dual Pistols' part of the soldier run, with its pictures (windowed).
func _run_dual() -> void:
	var m := await _start_solo_mission()
	if m == null:
		print("[autotest] FAIL: mission not ready")
		return
	m._director_t = 99999.0
	_clear_aliens()
	m.ship.stats["crew_hp"] = 1500.0
	await wait(0.3)
	await _so_dual(m, true)
	m.local_player.set_weapon(CrewWeapons.DEFAULT)


func _so_stand(p: CrewMember, pos: Vector3, yaw: float, pitch := -0.05) -> void:
	p.position = pos
	p.velocity = Vector3.ZERO
	p.look_yaw = yaw
	p.look_pitch = pitch
	p.reset_physics_interpolation()
	await wait(0.3)


func _so_text(l: Label3D) -> String:
	return l.text if l else ""


## Aboard: the helmet's instruments, the HUD left without health, crosshair or weapon read-out, the
## pistol held relaxed, how fast a click from relaxed fires, and relaxing again after shooting.
func _so_aboard(m: MissionLevel, shots: bool) -> void:
	var ship := m.ship
	var p := m.local_player
	await _so_stand(p, ship.spawn_points()[0], 0.0)
	await wait(2.2)
	var h := p._helmet
	print("[autotest] aboard: weapon %s %d/%d, visor %.2f (sealed %s), VITALS '%s' '%s', SUIT '%s' '%s' '%s', HUD health row %s, crosshair %s, weapon label %s, pose %d, ready %.2f" % [
		p.weapon, p.ammo, CrewWeapons.mag(p.weapon), h.visor, h.sealed, _so_text(h._texts["vit_cap"]), _so_text(h._texts["hp"]),
		_so_text(h._texts["seal"]), _so_text(h._texts["ship"]), _so_text(h._texts["lamp"]), m.hud._hp_bar.get_parent().visible,
		m.hud._crosshair.visible, m.hud._tool_label.visible, p.pose, p._ready_t])
	print("[autotest] gun display: '%s' '%s'" % [_so_text(p._rig.parts["display"]["value"]), _so_text(p._rig.parts["display"]["caption"])])
	await _shot_if(shots, "so01_aboard_relaxed")
	# A click from relaxed: the gun comes up and fires.
	var ammo0 := p.ammo
	var t0 := Time.get_ticks_msec()
	Input.action_press("fire")
	await get_tree().physics_frame
	Input.action_release("fire")
	var waited := -1.0
	for i in 60:
		await get_tree().physics_frame
		if p.ammo < ammo0:
			waited = (Time.get_ticks_msec() - t0) / 1000.0
			break
	print("[autotest] a click from relaxed fired after %.2f s (ammo %d -> %d), pose %d, ready %.2f" % [waited, ammo0, p.ammo, p.pose, p._ready_t])
	await wait(0.6)
	var pose_soon := p.pose
	await wait(1.4)
	print("[autotest] standing still after the shot: pose %d at 0.6 s, %d at 2.0 s (relaxed = %d)" % [pose_soon, p.pose, CrewMember.Pose.RELAXED])
	Input.action_press("sprint")
	Input.action_press("move_forward")
	await wait(0.5)
	print("[autotest] sprinting: speed %.2f m/s, sprint pose %.2f, ready %.2f" % [Vector2(p.velocity.x, p.velocity.z).length(), p._sprint_t, p._ready_t])
	Input.action_release("sprint")
	Input.action_release("move_forward")
	await wait(0.4)
	p.ammo = CrewWeapons.mag(p.weapon)


## Every weapon aimed down its sight (the sight's front element should sit in the middle of the
## view), and fired from the hip.
func _so_sights(m: MissionLevel, shots: bool) -> void:
	var ship := m.ship
	var p := m.local_player
	await _so_stand(p, ship.spawn_points()[0], 0.0, 0.0)
	var mid := get_viewport().get_visible_rect().size * 0.5
	for w: String in CrewWeapons.ORDER:
		p.set_weapon(w)
		ship._crew_weapons[1] = w
		await wait(0.7)
		Input.action_press("aim")
		await wait(0.5)
		var rig := p._rig
		var front: Vector3 = rig.parts["front"]
		var at := p.camera.unproject_position(rig.model.global_transform * front)
		var disp: Dictionary = rig.parts["display"]
		print("[autotest] %s aimed: fov %.1f (zoom %.2f), the sight's front %.1f px from the middle, view scale %.3f, gun shown %s, display '%s' '%s' '%s', walk speed share %.2f" % [
			CrewWeapons.display_name(w), p.camera.fov, float(CrewWeapons.def(w)["zoom"]), at.distance_to(mid), p._view.scale.x, rig.model.visible,
			_so_text(disp["caption"]), _so_text(disp["value"]), _so_text(disp["state"]), CrewMember.ADS_SPEED])
		await _shot_if(shots, "so02_aim_%s" % w)
		Input.action_release("aim")
		await wait(0.45)
		if shots:
			Input.action_press("fire")
			await wait(1.0 if w == "lightning" else 0.3)
			await shot("so03_hip_%s" % w)
			Input.action_release("fire")
		await wait(0.6)
		p.ammo = CrewWeapons.mag(w)
		p.heat = 0.0
		p.overheated = false
		p.reloading = false


## The scatter: from the hip and aimed, building up with a burst and settling again, on the move;
## and the walking speed while aiming.
func _so_scatter(m: MissionLevel) -> void:
	var ship := m.ship
	var p := m.local_player
	p.set_weapon("rifle")
	ship._crew_weapons[1] = "rifle"
	await _so_stand(p, ship.spawn_points()[0], 0.0, 0.0)
	await wait(0.6)
	var hip := p._spread()
	Input.action_press("aim")
	await wait(0.4)
	var aimed := p._spread()
	var pitch0 := p.look_pitch
	Input.action_press("fire")
	await wait(0.75)
	var burst := p._spread()
	var climbed := p.look_pitch - pitch0
	var shots_fired := CrewWeapons.mag("rifle") - p.ammo
	Input.action_release("fire")
	await wait(0.6)
	var settled := p._spread()
	var after := p.look_pitch - pitch0
	Input.action_press("move_forward")
	await wait(0.6)
	var aim_moving := p._spread()
	var aim_speed := Vector2(p.velocity.x, p.velocity.z).length()
	Input.action_release("aim")
	await wait(0.4)
	var hip_moving := p._spread()
	var walk_speed := Vector2(p.velocity.x, p.velocity.z).length()
	Input.action_release("move_forward")
	print("[autotest] Pulse Rifle scatter (rad): hip %.4f, aimed %.4f, aimed after a %d-round burst %.4f (view climbed %.3f rad, %.3f still up 0.6 s later), settled %.4f, aimed on the move %.4f, hip on the move %.4f" % [
		hip, aimed, shots_fired, burst, climbed, after, settled, aim_moving, hip_moving])
	print("[autotest] walking %.2f m/s, aiming %.2f m/s" % [walk_speed, aim_speed])
	await wait(0.3)
	p.ammo = CrewWeapons.mag("rifle")


## Casings fly out and come to rest on the floor; a reload drops the old magazine (and steps through
## the swap); an empty magazine only clicks, the pistol's slide locked back.
func _so_casings(m: MissionLevel, shots: bool) -> void:
	var ship := m.ship
	var p := m.local_player
	p.set_weapon("pistol")
	ship._crew_weapons[1] = "pistol"
	await _so_stand(p, ship.spawn_points()[0], 0.0, -0.1)
	await wait(0.6)
	var deb := Debris.of(ship)
	var c0 := deb.count("pistol")
	var ammo0 := p.ammo
	Input.action_press("fire")
	await wait(1.1)
	Input.action_release("fire")
	var fired := ammo0 - p.ammo
	await wait(0.25)
	await _shot_if(shots, "so04_casings_flying")
	await wait(2.5)
	var ys := PackedFloat32Array()
	for piece: Dictionary in deb._pieces:
		if piece["kind"] == "pistol":
			ys.append((piece["pos"] as Vector3).y)
	ys.sort()
	print("[autotest] pistol: %d shots, %d new casings, %d pieces still moving after 2.5 s, casings lie %.3f .. %.3f m above the deck" % [fired,
		deb.count("pistol") - c0, deb.moving(), ys[0] if ys.size() > 0 else -1.0, ys[ys.size() - 1] if ys.size() > 0 else -1.0])
	# Look down at them.
	p.look_pitch = -0.9
	await wait(0.3)
	await _shot_if(shots, "so05_casings_floor")
	p.look_pitch = -0.05
	var mags0 := deb.count("mag")
	await _tap("reload")
	var steps := PackedInt32Array()
	var t0 := Time.get_ticks_msec()
	while p.reloading and Time.get_ticks_msec() - t0 < 4000:
		await get_tree().physics_frame
		if steps.is_empty() or steps[steps.size() - 1] != p._rig._reload_step:
			steps.append(p._rig._reload_step)
		if shots and p.reload_progress() > 0.5 and p.reload_progress() < 0.56:
			await shot("so06_reload")
	# (The tap itself took 0.27 s of it.)
	var took := (Time.get_ticks_msec() - t0) / 1000.0 + 0.27
	await wait(1.0)
	print("[autotest] reload: %.2f s (nominal %.2f), steps %s, magazines dropped %d (moving %d), ammo %d/%d, display '%s'" % [
		took, CrewWeapons.reload_time("pistol"), steps, deb.count("mag") - mags0, deb.moving(), p.ammo,
		CrewWeapons.mag("pistol"), _so_text(p._rig.parts["display"]["value"])])
	# Empty it, then pull the trigger again.
	Input.action_press("fire")
	t0 = Time.get_ticks_msec()
	while p.ammo > 0 and Time.get_ticks_msec() - t0 < 6000:
		await get_tree().physics_frame
	Input.action_release("fire")
	await wait(0.3)
	await _tap("fire")
	var slide: Node3D = p._rig.parts["slide"]
	print("[autotest] empty: ammo %d, reloading %s, display '%s' '%s', slide back %.3f m" % [p.ammo, p.reloading,
		_so_text(p._rig.parts["display"]["value"]), _so_text(p._rig.parts["display"]["state"]), slide.position.z])
	await _shot_if(shots, "so07_empty")
	await _tap("reload")
	await wait(CrewWeapons.reload_time("pistol") + 0.3)


## Heat weapons: the Photon Rifle fired until it overheats (and vents, locked), then fired in a
## burst and vented early with R.
func _so_heat(m: MissionLevel, shots: bool) -> void:
	var ship := m.ship
	var p := m.local_player
	p.set_weapon("photon")
	ship._crew_weapons[1] = "photon"
	await _so_stand(p, ship.spawn_points()[0], 0.0, 0.0)
	await wait(0.6)
	var t0 := Time.get_ticks_msec()
	var fired := 0
	var last_cd := 0.0
	Input.action_press("fire")
	while not p.overheated and Time.get_ticks_msec() - t0 < 20000:
		await get_tree().physics_frame
		if p._since_shot < last_cd:
			fired += 1
		last_cd = p._since_shot
	Input.action_release("fire")
	var t_hot := (Time.get_ticks_msec() - t0) / 1000.0
	await wait(0.3)
	print("[autotest] Photon Rifle: overheated after %d shots in %.1f s; heat %.2f, venting %s, display '%s' '%s', HUD '%s'" % [fired, t_hot, p.heat,
		p.reloading, _so_text(p._rig.parts["display"]["value"]), _so_text(p._rig.parts["display"]["state"]), m.hud._tool_label.text])
	await _shot_if(shots, "so08_overheat")
	var shots0 := p._since_shot
	Input.action_press("fire")
	await wait(0.4)
	Input.action_release("fire")
	print("[autotest] trigger while overheated: fired %s" % (p._since_shot < shots0))
	t0 = Time.get_ticks_msec()
	while p.overheated and Time.get_ticks_msec() - t0 < 8000:
		await get_tree().physics_frame
	print("[autotest] vented and usable again after %.1f s (nominal %.1f), heat %.2f" % [(Time.get_ticks_msec() - t0) / 1000.0,
		CrewWeapons.reload_time("photon") * CrewWeapons.OVERHEAT_VENT, p.heat])
	await wait(0.3)
	Input.action_press("fire")
	await wait(1.5)
	Input.action_release("fire")
	var h := p.heat
	await _tap("reload")
	t0 = Time.get_ticks_msec()
	var venting := p.reloading
	while p.reloading and Time.get_ticks_msec() - t0 < 5000:
		await get_tree().physics_frame
	print("[autotest] Photon Rifle: heat %.2f after 1.5 s of fire, R vents: %s, cold after %.2f s, heat %.2f" % [h, venting,
		(Time.get_ticks_msec() - t0) / 1000.0, p.heat])


## The Lightning Thrower against a line of boarders: a full charge strikes the closest and jumps
## down the line; a quick click only fizzles.
func _so_lightning(m: MissionLevel, shots: bool) -> void:
	var ship := m.ship
	var p := m.local_player
	p.set_weapon("lightning")
	ship._crew_weapons[1] = "lightning"
	await _so_stand(p, Vector3(0, 0.05, 4.2), 0.0, 0.0)
	var line: Array[Boarder] = []
	for i in 4:
		ship.boarder_spawner.spawn({"name": "SL%d" % i, "pos": Vector3(-0.6 + 0.4 * i, 0.0, -0.5 - i * 1.7), "hp": 500.0})
	await wait(0.2)
	for i in 4:
		var b := ship.boarder_root.get_node("SL%d" % i) as Boarder
		b.set_physics_process(false)
		line.append(b)
	_face(p, line[0].position + Vector3(0, 0.9, 0))
	await wait(0.6)
	Input.action_press("fire")
	await wait(1.1)
	var ch := p.charge
	await _shot_if(shots, "so09_charged")
	Input.action_release("fire")
	await get_tree().physics_frame
	await get_tree().physics_frame
	var shake: float = m._shake
	await wait(0.02)
	await _shot_if(shots, "so10_bolt")
	await wait(0.4)
	var hits := PackedStringArray()
	for b in line:
		hits.append("%.0f" % (500.0 - b.hp))
	print("[autotest] Storm Lance: charge %.2f, damage down the line [%s] (nominal %.0f first, x%.2f a jump), heat %.2f, the view's shake %.2f and kick %.3f rad" % [ch,
		", ".join(hits), float(CrewWeapons.def("lightning")["damage_max"]), CrewWeapons.CHAIN_FALLOFF, p.heat, shake, p._last_kick])
	await wait(0.4)
	var before := line[0].hp
	Input.action_press("fire")
	await wait(0.12)
	Input.action_release("fire")
	await wait(0.4)
	print("[autotest] a quick click (charge under %.0f%%): damage %.0f" % [CrewWeapons.CHARGE_MIN * 100.0, before - line[0].hp])
	# Aimed 18 degrees past the first alien (away from the others; the old bolt sought out aliens in a
	# 32 degree cone): it goes where it is aimed.
	_face(p, line[0].position + Vector3(0, 0.9, 0))
	p.look_yaw += deg_to_rad(18.0)
	await wait(0.5)
	var hp_before: Array[float] = []
	for b in line:
		hp_before.append(b.hp)
	Input.action_press("fire")
	await wait(1.1)
	Input.action_release("fire")
	await wait(0.4)
	var off_hits := PackedStringArray()
	for i in line.size():
		off_hits.append("%.0f" % (hp_before[i] - line[i].hp))
	print("[autotest] Storm Lance, full charge aimed 18 deg off the first alien: damage down the line [%s] (none expected)" % ", ".join(off_hits))
	for b in line:
		if is_instance_valid(b):
			b.queue_free()
	await wait(0.3)
	p.set_weapon(CrewWeapons.DEFAULT)
	ship._crew_weapons[1] = CrewWeapons.DEFAULT


## The 2026-10-19 weapons: the Revolver (one shot a pull of the trigger; fanned, each shot scatters
## and kicks harder than the last, fired slowly they stay accurate; its moon-clip reload), the
## Submachine Gun (its rate, scatter, climb and damage falling off with distance), the Marksman Rifle
## (its rate, and a round through one alien into the next but not a third), the Shotgun (its rate
## and a shot's damage up close) and the Multiple Grenade Launcher (one grenade a pull, bouncing,
## going off on its fuse or on an alien, the blast's damage, the cases thrown out on a reload).
func _so_guns(m: MissionLevel, shots: bool) -> void:
	await _so_dual(m, shots)
	await _so_revolver(m, shots)
	await _so_smg(m, shots)
	await _so_marksman(m, shots)
	await _so_shotgun(m)
	await _so_mgl(m, shots)
	m.local_player.set_weapon(CrewWeapons.DEFAULT)
	m.ship._crew_weapons[1] = CrewWeapons.DEFAULT


## Boarders held still at ship-local `spots`, named `prefix` and a number.
func _so_line(m: MissionLevel, prefix: String, spots: Array, hp: float) -> Array[Boarder]:
	var ship := m.ship
	for i in spots.size():
		ship.boarder_spawner.spawn({"name": "%s%d" % [prefix, i], "pos": spots[i], "hp": hp})
	await wait(0.2)
	var line: Array[Boarder] = []
	for i in spots.size():
		var b := ship.boarder_root.get_node_or_null("%s%d" % [prefix, i]) as Boarder
		if b:
			b.set_physics_process(false)
			line.append(b)
	return line


## The damage each of `line` has taken (from `hp`).
func _so_damage(line: Array[Boarder], hp: float) -> String:
	var out := PackedStringArray()
	for b in line:
		out.append("%.0f" % (hp - b.hp) if is_instance_valid(b) else "dead")
	return ", ".join(out)


func _so_clear(line: Array[Boarder]) -> void:
	for b in line:
		if is_instance_valid(b):
			b.queue_free()
	await wait(0.3)


## One pull of the trigger: down for a couple of physics frames, then up.
func _click() -> void:
	Input.action_press("fire")
	await get_tree().physics_frame
	await get_tree().physics_frame
	Input.action_release("fire")
	await get_tree().physics_frame


## The trigger during a sustained burst with weapon `w`, at physics frame `frame` of it: held down,
## or for a semi-automatic weapon pulled every eighth frame (about seven times a second).
func _trigger(w: String, frame: int) -> void:
	if not CrewWeapons.semi(w) or frame % 8 == 0:
		Input.action_press("fire")
	elif frame % 8 == 2:
		Input.action_release("fire")


## The Dual Pistols: held down they fire in turn (right, left, right...), each gun flashing, running
## its slide back and throwing its casing on its own shot and its display counting its own rounds;
## their rate; a gun with no rounds left locks its slide back; a reload drops both magazines.
func _so_dual(m: MissionLevel, shots: bool) -> void:
	var ship := m.ship
	var p := m.local_player
	p.set_weapon("dual")
	ship._crew_weapons[1] = "dual"
	await _so_stand(p, ship.spawn_points()[0], 0.0, 0.0)
	await wait(0.6)
	var rig := p._rig
	if shots:
		await wait(1.6)
		await shot("so12_dual_relaxed")
		Input.action_press("aim")
		await wait(0.5)
		await shot("so12_dual_aimed")
		Input.action_release("aim")
		await wait(0.4)
	var deb := Debris.of(ship)
	var casings0 := deb.count("pistol")
	var order := ""
	var ammo0 := p.ammo
	var last := p.ammo
	var snapped := not shots
	Input.action_press("fire")
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 1000:
		await get_tree().physics_frame
		if p.ammo < last:
			last = p.ammo
			order += "R" if rig._gun_flash[0] > rig._gun_flash[1] else "L"
			if not snapped and order.length() == 5:
				snapped = true
				await shot("so12_dual_firing")
	Input.action_release("fire")
	await wait(0.8)
	var rounds := CrewWeapons.twin_rounds("dual", p.ammo)
	print("[autotest] Dual Pistols: trigger held 1 s: %d shots (cooldown %.2f s), guns in turn '%s'; displays right '%s' left '%s' (rounds %d+%d of %d); casings thrown out %d" % [
		ammo0 - p.ammo, float(CrewWeapons.def("dual")["cooldown"]), order, rig.parts["display"]["value"].text,
		rig._twin["display"]["value"].text, rounds.x, rounds.y, ammo0, deb.count("pistol") - casings0])
	# One round left: the right gun is empty (its slide locked back), the left fires it.
	p.ammo = 1
	await wait(0.4)
	var right_back: float = (rig.parts["slide"] as Node3D).position.z
	await _click()
	await wait(0.3)
	print("[autotest] Dual Pistols, one round left: right slide back %.3f m, fired by the %s gun; then rounds %d, both slides back %.3f / %.3f m" % [
		right_back, "left" if rig._gun_flash[1] > rig._gun_flash[0] or rig._twin["slide"].position.z > 0.0 else "right", p.ammo,
		(rig.parts["slide"] as Node3D).position.z, (rig._twin["slide"] as Node3D).position.z])
	var mags0 := deb.count("mag")
	await _tap("reload")
	t0 = Time.get_ticks_msec()
	var reload_shot := not shots
	while p.reloading and Time.get_ticks_msec() - t0 < 5000:
		await get_tree().physics_frame
		if not reload_shot and p.reload_progress() > 0.3:
			reload_shot = true
			await shot("so12_dual_reload")
	var took := (Time.get_ticks_msec() - t0) / 1000.0 + 0.27
	await wait(0.4)
	print("[autotest] Dual Pistols reload: %.2f s (nominal %.2f), magazines dropped %d, rounds %d, displays '%s' '%s'" % [took,
		CrewWeapons.reload_time("dual"), deb.count("mag") - mags0, p.ammo, rig.parts["display"]["value"].text, rig._twin["display"]["value"].text])


## The Revolver: held down it fires once; fanned (a click every 0.12 s) each shot scatters wider and
## kicks harder than the last, clicked slowly they stay accurate; and the moon-clip reload.
func _so_revolver(m: MissionLevel, shots: bool) -> void:
	var ship := m.ship
	var p := m.local_player
	p.set_weapon("revolver")
	ship._crew_weapons[1] = "revolver"
	await _so_stand(p, ship.spawn_points()[0], 0.0, 0.0)
	await wait(0.6)
	var ammo0 := p.ammo
	Input.action_press("fire")
	await wait(1.0)
	Input.action_release("fire")
	print("[autotest] Revolver: trigger held for 1 s: %d shot (of %d)" % [ammo0 - p.ammo, ammo0])
	await wait(1.2)
	for pace: float in [0.12, 0.8]:
		p.ammo = CrewWeapons.mag("revolver")
		p._bloom = 0.0
		await wait(0.8)
		var row := PackedStringArray()
		for i in 5:
			var spread := p._spread()
			var before := p.ammo
			await _click()
			for k in 10:
				if p.ammo < before:
					break
				await get_tree().physics_frame
			row.append("%.3f/%.3f" % [spread, p._last_kick])
			if shots and pace < 0.5 and i == 3:
				await shot("so13_revolver_fanned")
			await wait(maxf(0.0, pace - 0.05))
		print("[autotest] Revolver, a click every %.2f s: scatter before each shot / its kick (rad): %s" % [pace, ", ".join(row)])
	# The moon-clip reload.
	await wait(0.6)
	p.ammo = 0
	var deb := Debris.of(ship)
	var mags0 := deb.count("mag")
	await _tap("reload")
	var steps := PackedInt32Array()
	var crane := 0.0
	var snapped := not shots
	var t0 := Time.get_ticks_msec()
	while p.reloading and Time.get_ticks_msec() - t0 < 5000:
		await get_tree().physics_frame
		crane = maxf(crane, p._rig._crane)
		if steps.is_empty() or steps[steps.size() - 1] != p._rig._reload_step:
			steps.append(p._rig._reload_step)
		if not snapped and p.reload_progress() > 0.3:
			snapped = true
			await shot("so14_revolver_reload")
	var took := (Time.get_ticks_msec() - t0) / 1000.0 + 0.27
	await wait(0.8)
	print("[autotest] Revolver reload: %.2f s (nominal %.2f), steps %s, crane swung out %.2f, moon clips dropped %d (still moving %d), rounds %d" % [
		took, CrewWeapons.reload_time("revolver"), steps, crane, deb.count("mag") - mags0, deb.moving(), p.ammo])


## The Submachine Gun: rounds in a second's aimed burst, the scatter from the hip, aimed and after
## the burst, how far the burst climbs the view, and its damage falling off with distance.
func _so_smg(m: MissionLevel, shots: bool) -> void:
	var ship := m.ship
	var p := m.local_player
	p.set_weapon("smg")
	ship._crew_weapons[1] = "smg"
	await _so_stand(p, ship.spawn_points()[0], 0.0, 0.0)
	await wait(0.6)
	var hip := p._spread()
	Input.action_press("aim")
	await wait(0.4)
	var aimed := p._spread()
	var ammo0 := p.ammo
	var pitch0 := p.look_pitch
	Input.action_press("fire")
	await wait(0.5)
	await _shot_if(shots, "so15_smg_burst")
	await wait(0.5)
	var burst := p._spread()
	var climbed := p.look_pitch - pitch0
	Input.action_release("fire")
	Input.action_release("aim")
	var fall := PackedStringArray()
	for dist: float in [5.0, 10.0, 15.0, 20.0, 28.0, 40.0]:
		fall.append("%.0f m %.0f%%" % [dist, CrewWeapons.falloff("smg", dist) * 100.0])
	print("[autotest] Submachine Gun: %d rounds in an aimed second (magazine %d), scatter hip %.3f, aimed %.3f, after the burst %.3f; the burst climbed the view %.3f rad; damage by range %s" % [
		ammo0 - p.ammo, CrewWeapons.mag("smg"), hip, aimed, burst, climbed, ", ".join(fall)])
	await wait(0.6)
	p.ammo = CrewWeapons.mag("smg")


## The Marksman Rifle aimed through its scope at three aliens in a line: one round goes through the
## first into the second but not the third; and how many rounds the held trigger fires in 2 s.
func _so_marksman(m: MissionLevel, shots: bool) -> void:
	var ship := m.ship
	var p := m.local_player
	p.set_weapon("marksman")
	ship._crew_weapons[1] = "marksman"
	await _so_stand(p, Vector3(0, 0.05, 4.2), 0.0, 0.0)
	var line := await _so_line(m, "MK", [Vector3(0, 0, -0.5), Vector3(0, 0, -2.2), Vector3(0, 0, -3.9)], 500.0)
	_face(p, line[0].position + Vector3(0, 0.9, 0))
	await wait(0.6)
	Input.action_press("aim")
	await wait(0.5)
	await _shot_if(shots, "so16_marksman_scope")
	await _click()
	await wait(0.4)
	var one := _so_damage(line, 500.0)
	var ammo0 := p.ammo
	Input.action_press("fire")
	await wait(2.0)
	Input.action_release("fire")
	Input.action_release("aim")
	var d := CrewWeapons.def("marksman")
	print("[autotest] Marksman Rifle: one round down the line: damage [%s] (nominal %.0f, through %d); trigger held 2 s: %d rounds (every %.2f s)" % [one,
		float(d["damage"]) * float(ship.stats["blaster_damage"]) / CrewWeapons.BASE_DAMAGE, int(d["pierce"]), ammo0 - p.ammo, float(d["cooldown"])])
	await _so_clear(line)
	p.ammo = CrewWeapons.mag("marksman")


## The Shotgun: how often it fires with the trigger held, and a shot's damage on an alien 3 m away.
func _so_shotgun(m: MissionLevel) -> void:
	var ship := m.ship
	var p := m.local_player
	p.set_weapon("shotgun")
	ship._crew_weapons[1] = "shotgun"
	await _so_stand(p, Vector3(0, 0.05, 4.2), 0.0, 0.0)
	var line := await _so_line(m, "SG", [Vector3(0, 0, 1.2)], 2000.0)
	_face(p, line[0].position + Vector3(0, 0.9, 0))
	await wait(0.6)
	var ammo0 := p.ammo
	Input.action_press("fire")
	await wait(2.2)
	Input.action_release("fire")
	await wait(0.3)
	var fired := ammo0 - p.ammo
	var dealt := 2000.0 - line[0].hp
	var d := CrewWeapons.def("shotgun")
	print("[autotest] Shotgun: trigger held 2.2 s: %d shots (one every %.2f s), %.0f damage at 3 m (%.0f a shot; %d pellets x %.0f)" % [fired,
		float(d["cooldown"]), dealt, dealt / maxf(fired, 1), int(d["pellets"]), float(d["damage"]) * float(ship.stats["blaster_damage"]) / CrewWeapons.BASE_DAMAGE])
	await _so_clear(line)
	p.ammo = CrewWeapons.mag("shotgun")


## The Multiple Grenade Launcher: one grenade a pull of the trigger; fired down the ship it bounces
## about until its fuse sets it off; fired into three aliens it goes off as it strikes the first and
## hurts all three; a reload throws the six spent cases out.
func _so_mgl(m: MissionLevel, shots: bool) -> void:
	var ship := m.ship
	var p := m.local_player
	p.set_weapon("mgl")
	ship._crew_weapons[1] = "mgl"
	await _so_stand(p, Vector3(0, 0.05, 4.2), 0.0, -0.1)
	await wait(0.6)
	var gr := Grenades.of(ship)
	var ammo0 := p.ammo
	var t0 := Time.get_ticks_msec()
	Input.action_press("fire")
	await wait(0.2)
	var flying := gr.count()
	await wait(0.8)
	Input.action_release("fire")
	var bounced := 0
	while gr.count() > 0 and Time.get_ticks_msec() - t0 < 5000:
		bounced = maxi(bounced, gr.bounces())
		await get_tree().physics_frame
	var g: Dictionary = CrewWeapons.def("mgl")["grenade"]
	print("[autotest] Multiple Grenade Launcher: trigger held 1 s: %d grenade (in flight %d); it bounced %d times and went off %.2f s after the shot (fuse %.1f s)" % [
		ammo0 - p.ammo, flying, bounced, (Time.get_ticks_msec() - t0) / 1000.0, float(g["fuse"])])
	# One into three aliens.
	var line := await _so_line(m, "GL", [Vector3(-0.5, 0, -1.0), Vector3(0.3, 0, -1.6), Vector3(0.9, 0, -2.6)], 500.0)
	_face(p, line[0].position + Vector3(0, 0.9, 0))
	await wait(0.6)
	await _click()
	await wait(0.2)
	await _shot_if(shots, "so17_mgl_blast")
	await wait(0.6)
	var d := CrewWeapons.def("mgl")
	print("[autotest] a grenade into three aliens: damage [%s] (the blast %.0f in its middle, half at its edge %.1f m out), grenades left in flight %d" % [
		_so_damage(line, 500.0), float(d["damage"]) * float(ship.stats["blaster_damage"]) / CrewWeapons.BASE_DAMAGE, float(g["splash"]), gr.count()])
	await _so_clear(line)
	# The reload: the six spent cases tumble out.
	var deb := Debris.of(ship)
	var cases0 := deb.count("40mm")
	await _tap("reload")
	var t1 := Time.get_ticks_msec()
	var snapped := not shots
	while p.reloading and Time.get_ticks_msec() - t1 < 6000:
		await get_tree().physics_frame
		if not snapped and p.reload_progress() > 0.25:
			snapped = true
			await shot("so18_mgl_reload")
	var noses: Array = p._rig.parts.get("noses", [])
	print("[autotest] Multiple Grenade Launcher reload: %.2f s (nominal %.2f), cases thrown out %d, grenades %d, chambers showing a round %d" % [
		(Time.get_ticks_msec() - t1) / 1000.0 + 0.27, CrewWeapons.reload_time("mgl"), deb.count("40mm") - cases0, p.ammo,
		noses.filter(func(n): return (n as Node3D).visible).size()])


## The scanner aboard: up in front of the face (the weapon down), but the hull drowns the echoes.
func _so_scanner_aboard(m: MissionLevel, shots: bool) -> void:
	var p := m.local_player
	await _so_stand(p, m.ship.spawn_points()[0], 0.0, 0.0)
	Input.action_press("scanner")
	await wait(0.8)
	var sc := p._scanner
	print("[autotest] scanner aboard: raised %.2f, interference %s, echoes %s, pose %d (scan = %d), weapon shown %s, can fire %s" % [sc.raise,
		sc.interference, sc.echo_text(), p.pose, CrewMember.Pose.SCAN, p._rig.model.visible, p.scanning == false])
	await _shot_if(shots, "so11_scanner_aboard")
	var ammo0 := p.ammo
	Input.action_press("fire")
	await wait(0.4)
	Input.action_release("fire")
	Input.action_release("scanner")
	await wait(0.5)
	print("[autotest] fired with the scanner up: %s; lowered: raised %.2f, pose %d" % [p.ammo < ammo0, sc.raise, p.pose])


## Outside: land at an abandoned station, walk out (the visor seals), take critical damage (the
## visor cracks), use the scanner in the first room, and go back aboard (the visor opens).
func _so_outside(m: MissionLevel, shots: bool) -> void:
	var ship := m.ship
	var p := m.local_player
	var k := -1
	var d := {}
	for kk in 10:
		d = m.cave.derelict(kk)
		if not d.is_empty():
			k = kk
			break
	if k < 0:
		print("[autotest] FAIL: no abandoned station in this cave")
		return
	ship.gate_k = k
	ship.gate_entry = 0.0
	ship._exit_state = 3
	await _put_ship(m, float(d["s"]) - 70.0, [float(d["s"])])
	ship.request_station.rpc_id(1, "pilot")
	await wait(1.0)
	_clear_aliens()
	await wait(0.1)
	await _tap("land")
	var t0 := Time.get_ticks_msec()
	while ship.landing != Mothership.Dock.LANDED and Time.get_ticks_msec() - t0 < 50000:
		await wait(0.5)
	await wait(2.5)
	print("[autotest] landed at '%s': %s, hostiles %d" % [d["name"], ship.landing == Mothership.Dock.LANDED, ship.hostiles])
	p.exit_station(true)
	await wait(0.3)
	await _so_stand(p, Vector3(0, 0.05, 10.6), PI, -0.05)
	var h := p._helmet
	var visor_log := PackedStringArray()
	Input.action_press("move_forward")
	t0 = Time.get_ticks_msec()
	var sealed_at := -1.0
	while Time.get_ticks_msec() - t0 < 3200:
		await get_tree().physics_frame
		if sealed_at < 0.0 and h.visor >= 1.0:
			sealed_at = (Time.get_ticks_msec() - t0) / 1000.0
		if visor_log.size() < 12 and Time.get_ticks_msec() - t0 > visor_log.size() * 250:
			visor_log.append("%.2f" % h.visor)
	Input.action_release("move_forward")
	await wait(0.6)
	print("[autotest] walked out to %s: aboard %s, visor %s (sealed after %.2f s of walking), SUIT '%s' '%s' '%s'" % [p.position.snapped(Vector3.ONE * 0.1),
		ship.is_aboard(p.position), ",".join(visor_log), sealed_at, _so_text(h._texts["seal"]), _so_text(h._texts["ship"]), _so_text(h._texts["lamp"])])
	await _shot_if(shots, "so12_visor_sealed")
	# Health down to half cracks the visor, more as it drops.
	var cracks := PackedStringArray()
	for frac: float in [0.55, 0.45, 0.26, 0.16, 0.04]:
		p._apply_damage(maxf(0.0, p.hp - p.max_hp * frac))
		await wait(1.2)
		cracks.append("%.0f%% hp: %d" % [frac * 100.0, h.cracks()])
	print("[autotest] cracks: %s; VITALS '%s'" % [", ".join(cracks), _so_text(h._texts["hp"])])
	await _shot_if(shots, "so13_cracked")
	p.hp = p.max_hp
	await wait(0.5)
	print("[autotest] healed: cracks %d" % h.cracks())
	# The scanner in the first room.
	var layout: Dictionary = d["layout"]
	var rooms: Array = layout["rooms"]
	var lift := Vector3(0, StationBuilder.LAND_HEIGHT, 0)
	var floor_y := StationBuilder.DECK_Y - StationBuilder.LAND_HEIGHT + 0.05
	var r0: Dictionary = rooms[0]
	var entry := _room_entry(d["layout"], r0) - lift
	var c: Vector2 = r0["c"]
	await _so_stand(p, Vector3(entry.x, floor_y, entry.z), atan2(-(c.x - entry.x), -(c.y - entry.z)), -0.05)
	Input.action_press("scanner")
	await wait(2.8)
	var sc := p._scanner
	var kinds := {0: 0, 1: 0, 2: 0}
	for e: Array in sc.blips():
		var kind := mini(int(e[0]), 2)
		kinds[kind] = int(kinds[kind]) + 1
	var near := 0
	for b in ship.boarder_root.get_children():
		if (b as Boarder).position.distance_to(p.position) < Scanner.RANGE:
			near += 1
	# Echoes off walls out of plain view (something solid between the scanner and them).
	var behind := 0
	var space := p.get_world_3d().direct_space_state
	var eye := p.position + Vector3(0, Scanner.PING_HEIGHT, 0)
	var echoes := sc.wall_points()
	for b: Vector2 in echoes:
		var at := Vector3(b.x, eye.y, b.y)
		var dist := eye.distance_to(at)
		if dist < 1.0:
			continue
		var q := PhysicsRayQueryParameters3D.create(ship.to_global(eye), ship.to_global(eye.lerp(at, 1.0 - 0.8 / dist)), Scanner.MASK)
		q.exclude = [p.get_rid()]
		if not space.intersect_ray(q).is_empty():
			behind += 1
	print("[autotest] scanner in room 0 '%s': raised %.2f, interference %s, %d wall echoes (%d of them behind other walls), blips: %d aliens, %d crew, %d of any other kind (aliens within range: %d)" % [
		r0["name"], sc.raise, sc.interference, echoes.size(), behind, kinds[0], kinds[1], kinds.get(2, 0), near])
	await _shot_if(shots, "so14_scanner")
	Input.action_release("scanner")
	await wait(0.5)
	# Back aboard: the visor opens.
	await _so_stand(p, ship.spawn_points()[0], 0.0)
	await wait(1.2)
	print("[autotest] back aboard: visor %.2f, sealed %s, SUIT '%s' '%s'" % [h.visor, h.sealed, _so_text(h._texts["seal"]), _so_text(h._texts["ship"])])


## Multiplayer soldier test, host side: three boarders held still aboard in front of where the
## client stands; what the host sees of the client's weapon: its hits (the lightning bolt's jumps
## too), its poses, and the casings and magazine thrown out of its gun.
func _run_host_soldier() -> void:
	Net.local_name = "HostSoldier"
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
	await wait(1.5)
	Game.main.start_mission()
	var m: MissionLevel = null
	for i in 600:
		await get_tree().process_frame
		m = Game.mission as MissionLevel
		if m and m.started and m.local_player:
			break
	m._director_t = 99999.0
	var s := 70.0
	while not m.cave.stations_in(s - 220.0, s + 220.0).is_empty() and s < 4000.0:
		s += 20.0
	await _put_ship(m, s)
	_clear_aliens()
	var ship := m.ship
	for i in 3:
		ship.boarder_spawner.spawn({"name": "NS%d" % i, "pos": Vector3(-0.4 + 0.4 * i, 0.0, -0.5 - i * 1.7), "hp": 2000.0})
	await wait(0.3)
	var line: Array[Boarder] = []
	for i in 3:
		var b := ship.boarder_root.get_node("NS%d" % i) as Boarder
		b.set_physics_process(false)
		line.append(b)
	print("[autotest] host: three boarders held still in front of the client's spot")
	var client: CrewMember = null
	for c in ship.crew_root.get_children():
		var cm := c as CrewMember
		if cm and cm != m.local_player and not cm.bot:
			client = cm
	var deb := Debris.of(ship)
	var poses := {}
	var weapons := {}
	var seen_reload := false
	var copies := 0
	var casings := 0
	var mags := 0
	var t := 0.0
	while t < 30.0:
		await wait(0.1)
		t += 0.1
		if is_instance_valid(ship):
			copies = maxi(copies, Grenades.of(ship).count())
			# (Casings only lie about for a few seconds: count the most there were at once.)
			casings = maxi(casings, deb.count("pistol"))
			mags = maxi(mags, deb.count("mag"))
		if client:
			poses[client.pose] = int(poses.get(client.pose, 0)) + 1
			weapons[client.weapon] = true
			seen_reload = seen_reload or client.reloading
	var hits := PackedStringArray()
	for b in line:
		hits.append("%.0f" % (2000.0 - b.hp) if is_instance_valid(b) else "dead")
	print("[autotest] host: the client's poses seen %s (relaxed %d, ready %d, aim %d, scan %d), weapons %s, reloading seen %s" % [poses,
		CrewMember.Pose.RELAXED, CrewMember.Pose.READY, CrewMember.Pose.AIM, CrewMember.Pose.SCAN, weapons.keys(), seen_reload])
	print("[autotest] host: casings from the client's gun (at most at once) %d, magazines %d; the client's grenades seen in flight at once (at most) %d; damage to the boarders [%s]" % [
		casings, mags, copies, ", ".join(hits)])
	m.abort_mission()
	await wait(6.0)


## Multiplayer soldier test, client side: the pistol from the hip and aimed at the host's boarders,
## a reload, a full lightning bolt down the line, two grenades into it, and the scanner held up.
func _run_join_soldier() -> void:
	Net.local_name = "ClientSoldier"
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
	var target: Boarder = null
	for i in 300:
		await wait(0.1)
		target = ship.boarder_root.get_node_or_null("NS0") as Boarder
		if target:
			break
	if target == null:
		print("[autotest] FAIL: client saw no boarders")
		return
	await wait(1.0)
	var p := m.local_player
	await _so_stand(p, Vector3(0, 0.05, 4.2), 0.0, 0.0)
	_face(p, target.position + Vector3(0, 0.9, 0))
	await wait(0.4)
	var deb := Debris.of(ship)
	var ammo0 := p.ammo
	Input.action_press("fire")
	await wait(1.5)
	Input.action_release("fire")
	print("[autotest] client: hip fire 1.5 s: rounds %d -> %d, own casings %d" % [ammo0, p.ammo, deb.count("pistol")])
	await _tap("reload")
	await wait(CrewWeapons.reload_time("pistol") + 0.3)
	print("[autotest] client: reloaded: %d rounds, own magazines on the floor %d" % [p.ammo, deb.count("mag")])
	_face(p, target.position + Vector3(0, 0.9, 0))
	Input.action_press("aim")
	await wait(0.4)
	Input.action_press("fire")
	await wait(1.0)
	Input.action_release("fire")
	Input.action_release("aim")
	await wait(0.5)
	var hp_before := PackedFloat32Array()
	for i in 3:
		var b := ship.boarder_root.get_node_or_null("NS%d" % i) as Boarder
		hp_before.append(b.hp if b else -1.0)
	p.set_weapon("lightning")
	await wait(0.6)
	_face(p, target.position + Vector3(0, 0.9, 0))
	Input.action_press("fire")
	await wait(1.1)
	Input.action_release("fire")
	await wait(0.8)
	var jumps := PackedStringArray()
	for i in 3:
		var b := ship.boarder_root.get_node_or_null("NS%d" % i) as Boarder
		jumps.append("%.0f" % (hp_before[i] - b.hp) if b else "gone")
	print("[autotest] client: lightning bolt, damage per boarder as synced [%s], heat %.2f" % [", ".join(jumps), p.heat])
	var hp_mid := PackedFloat32Array()
	for i in 3:
		var b := ship.boarder_root.get_node_or_null("NS%d" % i) as Boarder
		hp_mid.append(b.hp if b else -1.0)
	p.set_weapon("mgl")
	await wait(0.6)
	_face(p, target.position + Vector3(0, 0.9, 0))
	await _click()
	await wait(0.7)
	await _click()
	await wait(2.2)
	var blasts := PackedStringArray()
	for i in 3:
		var b := ship.boarder_root.get_node_or_null("NS%d" % i) as Boarder
		blasts.append("%.0f" % (hp_mid[i] - b.hp) if b else "gone")
	print("[autotest] client: two grenades, damage per boarder as synced [%s], grenades left %d" % [", ".join(blasts), p.ammo])
	Input.action_press("scanner")
	await wait(1.5)
	print("[autotest] client: scanner up: raised %.2f, interference %s (aboard), pose %d" % [p._scanner.raise, p._scanner.interference, p.pose])
	Input.action_release("scanner")
	for i in 400:
		await wait(0.1)
		var lvl: Node = Game.main.current_level()
		if lvl and lvl.name == "Homebase":
			break


## What hid a screen's points in the last _hidden_samples() (mesh type and position -> true).
var _hiders := {}


## Nothing in front of a screen: how many of a 9 x 5 grid of points on each of the helmet's screens,
## and on each gun's display (held relaxed, raised and aimed), something else hides from the eye
## (rays from the eye against the triangles of every other mesh of the helmet and the gun).
func _so_clipping(m: MissionLevel, shots: bool) -> void:
	var ship := m.ship
	var p := m.local_player
	await _so_stand(p, ship.spawn_points()[0], 0.0, -0.1)
	var h := p._helmet
	var counts := PackedStringArray()
	for sc: Dictionary in h.screens():
		counts.append("%d" % _hidden_samples([h], h, sc["frame"], sc["size"], Vector3.ZERO))
	print("[autotest] helmet screens: points hidden by other geometry [%s] (of 45 each); %d meshes in the helmet" % [", ".join(counts),
		h.find_children("*", "MeshInstance3D", true, false).size()])
	await _shot_if(shots, "so00_helmet")
	for w: String in CrewWeapons.ORDER:
		p.set_weapon(w)
		ship._crew_weapons[1] = w
		p._since_shot = 10.0
		await wait(0.9)
		var poses := PackedStringArray()
		for pose: String in ["relaxed", "raised", "aimed"]:
			if pose == "raised":
				p._since_shot = 0.0
				await wait(0.35)
			elif pose == "aimed":
				Input.action_press("aim")
				await wait(0.5)
			var rig := p._rig
			var model := rig.model
			var disp: Dictionary = rig.parts["display"]
			var eye := model.global_transform.affine_inverse() * p.camera.global_position
			var frame: Transform3D = disp["frame"]
			var size: Vector2 = (disp["screen"] as MeshInstance3D).mesh.size
			var by_gun := _hidden_samples([model], model, frame, size, eye)
			var gun_hiders := ", ".join(_hiders.keys())
			poses.append("%s %d by the gun%s / %d by the helmet" % [pose, by_gun, (" (" + gun_hiders + ")") if by_gun > 0 else "",
				_hidden_samples([h], model, frame, size, eye)])
		Input.action_release("aim")
		await wait(0.3)
		print("[autotest] %s display: points hidden %s (of 45)" % [CrewWeapons.display_name(w), ", ".join(poses)])
	p.set_weapon(CrewWeapons.DEFAULT)
	ship._crew_weapons[1] = CrewWeapons.DEFAULT
	await wait(0.6)


## Of a 9 x 5 grid of points on the quad `size` big at `frame` (in `space`), how many something hides
## from `eye` (also in `space`): rays against the triangles of every visible mesh under `roots` that
## isn't part of a screen. What hid them is left in _hiders (mesh type and where it sits in `space`).
func _hidden_samples(roots: Array, space: Node3D, frame: Transform3D, size: Vector2, eye: Vector3) -> int:
	var to_space := space.global_transform.affine_inverse()
	var tris: Array[PackedVector3Array] = []
	var names: PackedStringArray = []
	_hiders.clear()
	for root: Node3D in roots:
		for n in root.find_children("*", "MeshInstance3D", true, false):
			var g := n as MeshInstance3D
			if g.has_meta("screen") or g.mesh == null or not g.is_visible_in_tree():
				continue
			var xf := to_space * g.global_transform
			var faces := g.mesh.get_faces()
			var out := PackedVector3Array()
			out.resize(faces.size())
			for k in faces.size():
				out[k] = xf * faces[k]
			tris.append(out)
			names.append("%s at %s" % [g.mesh.get_class(), (to_space * g.global_position).snapped(Vector3.ONE * 0.001)])
	var hidden := 0
	for iy in 5:
		for ix in 9:
			var q := frame * Vector3((float(ix) / 8.0 - 0.5) * size.x * 0.96, (float(iy) / 4.0 - 0.5) * size.y * 0.94, 0.0)
			var dir := q - eye
			var dist := dir.length()
			dir /= dist
			var blocked := false
			for t in tris.size():
				var faces := tris[t]
				for k in range(0, faces.size(), 3):
					var hit: Variant = Geometry3D.ray_intersects_triangle(eye, dir, faces[k], faces[k + 1], faces[k + 2])
					if hit != null and eye.distance_to(hit) < dist - 0.0002:
						blocked = true
						_hiders[names[t]] = true
						break
				if blocked:
					break
			if blocked:
				hidden += 1
	return hidden


## The outpost test (title screen button / cheat / `--test=outpost`): the ship lands at an
## abandoned station at once, a crate of every hand weapon stands on its pier, the player on the
## pier; F swaps each weapon in turn; the dive leaves the save alone (outpost_check: no shots).
func _run_outpost(shots: bool) -> void:
	var rp0 := Game.rp()
	var best0 := int(Game.profile.get("best_depth", 0))
	Game.main.start_outpost_test()
	var m: MissionLevel = null
	for i in 900:
		await get_tree().process_frame
		m = Game.mission as MissionLevel
		if m and m.started and m.local_player and m.local_ready:
			break
	if m == null or not m.started:
		print("[autotest] FAIL: the outpost test never started")
		return
	await wait(1.5)
	var ship := m.ship
	var p := m.local_player
	var crates := PackedStringArray()
	for c in ship.cargo_root.get_children():
		var crate := c as SupplyCrate
		if crate and RunItems.is_crew_weapon(crate.item):
			crates.append("%s %s" % [RunItems.crew_weapon_of(crate.item), crate.net_pos.snapped(Vector3.ONE * 0.1)])
	print("[autotest] outpost test: landed %s at abandoned station %d (%.0f m), ramp %.2f, hostiles %d, the player at %s (aboard %s, visor %.2f)" % [
		ship.landing == Mothership.Dock.LANDED, ship.derelict_k, ship.depth, ship.ramp, ship.hostiles, p.position.snapped(Vector3.ONE * 0.1),
		ship.is_aboard(p.position), p._helmet.visor])
	print("[autotest] weapon crates on the pier: %s" % ", ".join(crates))
	await _shot_if(shots, "ot01_pier")
	# Swap to each weapon in turn at its crate.
	var swapped := PackedStringArray()
	for w: String in CrewWeapons.ORDER:
		if w == CrewWeapons.DEFAULT:
			continue
		var target: SupplyCrate = null
		for c in ship.cargo_root.get_children():
			var crate := c as SupplyCrate
			if crate and crate.item == RunItems.crew_weapon_item(w):
				target = crate
		if target == null:
			swapped.append("%s: no crate" % w)
			continue
		await _stand_near(p, target, Vector3(0, 0, target.net_pos.z), target.net_pos.y - SupplyCrate.SIZE.y * 0.5 + 0.05)
		await _tap("equip")
		await wait(0.5)
		swapped.append("%s -> %s" % [w, p.weapon])
		if shots and w == "lightning":
			await shot("ot02_swapped")
	print("[autotest] swaps at the crates: %s" % ", ".join(swapped))
	m.abort_mission()
	for i in 200:
		await wait(0.1)
		var lvl: Node = Game.main.current_level()
		if lvl and lvl.name == "Homebase":
			break
	print("[autotest] after the test dive: RP %d -> %d, best depth %d -> %d (unchanged: %s)" % [rp0, Game.rp(), best0,
		int(Game.profile.get("best_depth", 0)), rp0 == Game.rp() and best0 == int(Game.profile.get("best_depth", 0))])


# --- Dirty glass -------------------------------------------------------------------------------

## Lamps and dirty glass (the 2026-10-19 Issues): out on an abandoned station's pier with the visor
## sealed, a lamp behind the head (as a crewmate's flashlight would be) must leave nothing on the
## visor, while one ahead glares through its grime; then in a gun pod (its cabin lamp glints softly
## in the glass, the guns' flashes glare through the grime), the cockpit and a scout's canopy (the
## fill light out ahead of it must leave the glass alone). For each it prints how bright the middle
## of the view is and its brightest pixel; for the visor, what the visor itself adds to the picture
## (shown against hidden).
## A lamp close beside the helmet, 45 to 90 degrees off the view (a bare bulb, then a crewmate's
## flashlight shining at the face): the visor's glare and the helmet's shell lit through the
## opening should both fade smoothly as the lamp moves round, with no hard line across either.
func _run_visor_side() -> void:
	Game.main.start_outpost_test()
	var m: MissionLevel = null
	for i in 900:
		await get_tree().process_frame
		m = Game.mission as MissionLevel
		if m and m.started and m.local_player and m.local_ready:
			break
	if m == null or not m.started:
		print("[autotest] FAIL: the outpost test never started")
		return
	m._director_t = 99999.0
	await wait(2.0)
	_steady_lights()
	var p := m.local_player
	p.look_yaw = PI
	p.look_pitch = -0.05
	await wait(1.2)
	for kind: String in ["bulb", "torch"]:
		for deg: float in [45.0, 60.0, 70.0, 80.0, 90.0]:
			var a := deg_to_rad(deg)
			var off := Vector3(sin(a), 0.05, -cos(a)) * 1.3
			var lamp: Light3D
			if kind == "bulb":
				var o := OmniLight3D.new()
				o.omni_range = 6.0
				o.light_energy = 2.5
				lamp = o
			else:
				var s := SpotLight3D.new()
				s.spot_range = 12.0
				s.spot_angle = 28.0
				s.light_energy = 3.0
				s.light_projector = Models.light_cookie("flashlight")
				s.shadow_enabled = true
				lamp = s
			lamp.light_color = Color(1.0, 0.92, 0.8)
			m.fx_root.add_child(lamp)
			var at := p.camera.global_transform * off
			lamp.global_transform = Transform3D(Basis.looking_at(p.camera.global_position - at, Vector3.UP), at)
			await wait(0.3)
			var glass: Node3D = p._helmet._visor_node.get_child(0)
			var with_v := await _glass_shot("vs_%s_%d" % [kind, int(deg)])
			glass.visible = false
			var without := await _glass_shot("vs_%s_%d_no_glass" % [kind, int(deg)])
			glass.visible = true
			var adds := _glass_adds(with_v[0], without[0])
			print("[autotest] %s at %d deg, 1.3 m: the visor adds at most %.3f (%d pixels over 0.05), the view's middle %.3f" % [
				kind, int(deg), adds.x, int(adds.y), with_v[1]])
			lamp.queue_free()
			await wait(0.2)
	m.abort_mission()
	await wait(2.0)


func _run_glass() -> void:
	Game.main.start_outpost_test()
	var m: MissionLevel = null
	for i in 900:
		await get_tree().process_frame
		m = Game.mission as MissionLevel
		if m and m.started and m.local_player and m.local_ready:
			break
	if m == null or not m.started:
		print("[autotest] FAIL: the outpost test never started")
		return
	m._director_t = 99999.0
	await wait(2.0)
	_steady_lights()
	var p := m.local_player
	var h := p._helmet
	p.look_yaw = PI
	p.look_pitch = -0.05
	await wait(1.2)
	print("[autotest] outside: visor %.2f (sealed %s), flashlight %s" % [h.visor, h.sealed, p.lamp_on()])
	await _glass_visor(m, "plain", Vector3.ZERO)
	# A crewmate's flashlight 2.5 m behind the head, shining at it.
	await _glass_visor(m, "lamp_behind", Vector3(0.3, 0.1, 2.5))
	# And one 3 m ahead, shining at the visor.
	await _glass_visor(m, "lamp_ahead", Vector3(0.5, 0.1, -3.0))
	# Lamps off to the side, 60 to 90 degrees from the view: the glass turns edge-on to them somewhere
	# across the visor, which used to show as a hard line.
	for deg: float in [60.0, 75.0, 90.0]:
		var a := deg_to_rad(deg)
		await _glass_visor(m, "lamp_side_%d" % int(deg), Vector3(sin(a) * 3.0, 0.1, -cos(a) * 3.0))
	m.abort_mission()
	for i in 200:
		await wait(0.1)
		var lvl: Node = Game.main.current_level()
		if lvl and lvl.name == "Homebase":
			break
	m = await _start_solo_mission()
	if m == null:
		print("[autotest] FAIL: mission not ready")
		return
	m._director_t = 99999.0
	var s := 70.0
	while not m.cave.stations_in(s - 220.0, s + 220.0).is_empty() and s < 4000.0:
		s += 20.0
	await _put_ship(m, s)
	_clear_aliens()
	var ship := m.ship
	p = m.local_player
	var g: String = ship.gun_stations()[0]
	ship.request_station.rpc_id(1, g)
	await wait(1.2)
	await _glass_shot("gl04_pod")
	Input.action_press("fire")
	await wait(0.3)
	await _glass_shot("gl05_pod_firing")
	Input.action_release("fire")
	p.exit_station(true)
	await wait(0.5)
	ship.request_station.rpc_id(1, "pilot")
	await wait(1.2)
	await _glass_shot("gl06_cockpit")
	p.exit_station(true)
	await wait(0.5)
	if not ship.scout_stations().is_empty():
		ship.request_station.rpc_id(1, ship.scout_stations()[0])
		await wait(1.0)
		var sc: Scout = m.scouts[0]
		_scout_steer(m, m.cave.center3(-sc.global_position.z + 60.0))
		Input.action_press("move_forward")
		await wait(1.6)
		Input.action_release("move_forward")
		await wait(0.6)
		await _glass_shot("gl07_scout")
		Input.action_press("fire")
		await wait(0.3)
		await _glass_shot("gl08_scout_firing")
		Input.action_release("fire")
	m.abort_mission()
	await wait(3.0)


## Out on the pier: what the visor adds to the view with a flashlight at `offset` from the eye
## (camera frame; none for zero) shining at the face, against the same view with the visor's glass
## hidden. A reflection on the visor would show as a bright spot it adds.
func _glass_visor(m: MissionLevel, label: String, offset: Vector3) -> void:
	var p := m.local_player
	var lamp: SpotLight3D = null
	if offset != Vector3.ZERO:
		lamp = SpotLight3D.new()
		lamp.spot_range = 18.0
		lamp.spot_angle = 28.0
		lamp.spot_attenuation = 0.8
		lamp.light_energy = 2.2
		lamp.light_color = Color(1.0, 0.95, 0.85)
		lamp.light_projector = Models.light_cookie("flashlight")
		lamp.shadow_enabled = true
		m.fx_root.add_child(lamp)
		var at := p.camera.global_transform * offset
		lamp.global_transform = Transform3D(Basis.looking_at(p.camera.global_position - at, Vector3.UP), at)
	await wait(0.3)
	var glass: Node3D = p._helmet._visor_node.get_child(0)
	var with_v := await _glass_shot("gl_visor_%s" % label)
	glass.visible = false
	var without := await _glass_shot("gl_visor_%s_no_glass" % label)
	glass.visible = true
	var adds := _glass_adds(with_v[0], without[0])
	print("[autotest] visor, %s: the visor adds at most %.3f to a pixel (%d pixels brighter by over 0.05), the view's middle %.3f, brightest %.3f" % [
		label, adds.x, int(adds.y), with_v[1], with_v[2]])
	if lamp:
		lamp.queue_free()
	await wait(0.2)


## The view: a screenshot, how bright its middle is (mean) and its brightest pixel.
func _glass_shot(shot_name: String) -> Array:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [_dir, shot_name]
	img.save_png(path)
	var w := img.get_width()
	var hh := img.get_height()
	var sum := 0.0
	var n := 0
	var top := 0.0
	for y in range(0, hh, 3):
		for x in range(0, w, 3):
			var c := img.get_pixel(x, y)
			var l := c.r * 0.2126 + c.g * 0.7152 + c.b * 0.0722
			top = maxf(top, l)
			if absf(x - w * 0.5) < w * 0.12 and absf(y - hh * 0.5) < hh * 0.12:
				sum += l
				n += 1
	print("[autotest] screenshot %s: middle %.3f, brightest %.3f" % [ProjectSettings.globalize_path(path), sum / maxf(n, 1), top])
	return [img, sum / maxf(n, 1), top]


## How much brighter picture `a` is than `b` anywhere: the most a pixel gained, and how many gained
## more than 0.05.
static func _glass_adds(a: Image, b: Image) -> Vector2:
	var most := 0.0
	var count := 0
	for y in range(0, a.get_height(), 2):
		for x in range(0, a.get_width(), 2):
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			var d := ((ca.r + ca.g + ca.b) - (cb.r + cb.g + cb.b)) / 3.0
			most = maxf(most, d)
			if d > 0.05:
				count += 1
	return Vector2(most, count)


## Stop the abandoned stations' failing lights flickering (for pictures to compare).
func _steady_lights() -> void:
	for n in get_tree().root.find_children("*", "Node3D", true, false):
		var d := n as Derelict
		if d == null:
			continue
		for f: Dictionary in d.flicker:
			(f["light"] as Light3D).light_energy = float(f["energy"])
		d.set_process(false)


## How loud and how harsh the hand weapons' sounds are, the 2026-10-19 ones next to the older ones:
## each stream's length, RMS (dBFS) and peak, the level it plays at (a shot's "volume"; heard by its
## shooter 5 dB lower), and its brightness (the mean jump from one sample to the next: higher is
## harsher). Headless.
func _run_sfx_levels() -> void:
	var levels := {}
	for w: String in CrewWeapons.ORDER:
		var d := CrewWeapons.def(w)
		levels[str(d["sound"])] = float(d["volume"])
	for id: String in ["pistol", "revolver", "smg", "rifle", "photon", "marksman", "shotgun", "mgl", "zap", "thunder", "zap_hit", "hit",
			"grenade_blast", "grenade_bounce", "small_explosion", "explosion", "cyl_open", "cyl_close", "moonclip", "mag_out", "mag_in", "rack", "pump"]:
		var st := Sfx.stream(id) as AudioStreamWAV
		if st == null:
			print("[autotest] sound %s: MISSING" % id)
			continue
		var smp := _stream_samples(st)
		var sum := 0.0
		var peak := 0.0
		var jump := 0.0
		for i in smp.size():
			sum += smp[i] * smp[i]
			peak = maxf(peak, absf(smp[i]))
			if i > 0:
				jump += absf(smp[i] - smp[i - 1])
		print("[autotest] sound %-15s %.2f s, rms %6.1f dBFS, peak %.2f, played at %s, brightness %.4f" % [id, smp.size() / float(Sfx.RATE),
			linear_to_db(sqrt(sum / maxf(smp.size(), 1.0))), peak, ("%.0f dB" % float(levels[id])) if levels.has(id) else "-", jump / maxf(smp.size(), 1.0)])
