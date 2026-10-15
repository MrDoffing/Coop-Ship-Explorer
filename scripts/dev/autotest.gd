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
				p.station, m.ship.mining_on, p.station_aim, m.ship.aim_m, m.ship.mining_end,
				dep.global_position if is_instance_valid(dep) else "-",
				m.ship.mining_end.distance_to(dep.global_position) if is_instance_valid(dep) else -1.0])
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
	print("[autotest] scout state=", m.scout.state, " station=", p.station)
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
	m.scout.request_dock.rpc_id(1)
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
		" credits=", Game.credits())
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


## Stand next to a crate and pick it up. Returns true once carrying it.
func _pick_up(m: MissionLevel, p: CrewMember, crate: SupplyCrate) -> bool:
	var away := Vector3(crate.net_pos.x, 0, crate.net_pos.z).direction_to(Vector3(0, 0, 28.0 - StationBuilder.LAND_HEIGHT))
	if away.length_squared() < 0.01:
		away = Vector3.BACK
	p.position = Vector3(crate.net_pos.x, crate.net_pos.y - SupplyCrate.SIZE.y * 0.5 + 0.05, crate.net_pos.z) + away * 1.3
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()
	await wait(0.2)
	_face(p, crate.net_pos)
	await wait(0.2)
	print("[autotest]   prompt at crate: ", p.prompt)
	await _tap("interact")
	await wait(0.2)
	return p.carrying == crate


func _crate_list(m: MissionLevel) -> String:
	var out := PackedStringArray()
	for c in m.ship.cargo_root.get_children():
		var crate := c as SupplyCrate
		if crate:
			out.append("%s:%s@%s%s" % [crate.name, crate.item, crate.net_pos.snapped(Vector3.ONE * 0.1),
				" (carried by %d)" % crate.carrier if crate.carrier != 0 else ""])
	return ", ".join(out)


## Waystations: approach and land, walk down the ramp, carry supplies aboard and fit them,
## station defences, lift off and the auto cannon.
func _run_station() -> void:
	var m := await _start_solo_mission()
	if m == null:
		print("[autotest] FAIL: mission not ready")
		return
	var ship := m.ship
	var p := m.local_player
	var st := m.cave.station(0)
	print("[autotest] station 0: s=%.0f side=%.0f depth=%.1f origin=%s" % [st["s"], st["side"], st["depth"], (st["xform"] as Transform3D).origin])
	# Put the ship in the tunnel 60 m before the station and let the cave stream in.
	var s0 := float(st["s"]) - 60.0
	ship.global_position = m.cave.center3(s0) + Vector3(0, -1.4, 0)
	var t := m.cave.tangent(s0)
	ship.rotation.y = atan2(-t.x, -t.z)
	ship.velocity = Vector3.ZERO
	ship.reset_physics_interpolation()
	for i in 600:
		await get_tree().process_frame
		if m._chunks_ready_near(s0) and m._chunks_ready_near(float(st["s"])):
			break
	var built := false
	for c in m.cave_root.get_children():
		if c.has_node("Waystation0"):
			built = true
	print("[autotest] station structure built: ", built)
	ship.request_station.rpc_id(1, "pilot")
	await wait(1.0)
	print("[autotest] in range: ", not ship.nearest_station(Mothership.LAND_RANGE).is_empty(), " pilot info: ", m.hud._station_info.text.replace("\n", " | "))
	await shot("st01_marker")
	await _tap("land")
	print("[autotest] landing state after L: ", ship.landing)
	var t0 := Time.get_ticks_msec()
	var shots_taken := 0
	while ship.landing != Mothership.Dock.LANDED and Time.get_ticks_msec() - t0 < 45000:
		await wait(0.5)
		var el := (Time.get_ticks_msec() - t0) / 1000.0
		if shots_taken == 0 and el > 5.0:
			shots_taken = 1
			await shot("st02_approach")
		elif shots_taken == 1 and el > 11.0:
			shots_taken = 2
			await shot("st03_turn")
	print("[autotest] landed: %s after %.1f s, pos %s, yaw %.2f, gear %.2f" % [ship.landing == Mothership.Dock.LANDED,
		(Time.get_ticks_msec() - t0) / 1000.0, ship.global_position, ship.rotation.y, ship.gear])
	var expect: Transform3D = (st["xform"] as Transform3D) * Transform3D(Basis.IDENTITY, Vector3(0, StationBuilder.LAND_HEIGHT, 0))
	print("[autotest] landing error: %.2f m" % ship.global_position.distance_to(expect.origin))
	await wait(2.5)
	print("[autotest] ramp %.2f, crates: %s" % [ship.ramp, _crate_list(m)])
	await shot("st04_landed_chase")
	# Outside view into the hangar from the tunnel.
	var xf: Transform3D = st["xform"]
	var cam := Camera3D.new()
	cam.far = 500.0
	m.add_child(cam)
	cam.global_position = xf * Vector3(14.0, 12.0, -float(st["depth"]) - 4.0)
	cam.look_at(xf * Vector3(0, 4.0, 4.0))
	cam.current = true
	await wait(0.3)
	await shot("st04b_hangar_outside")
	cam.global_position = xf * Vector3(-4.5, 7.5, 18.6)
	cam.look_at(xf * Vector3(0, 3.6, 11.0))
	await wait(0.3)
	await shot("st04c_ramp_outside")
	cam.queue_free()
	p.camera.current = true
	# Station defences: an alien that comes close gets shot down.
	var hull0 := ship.hull
	var intruder := m.spawn_alien(Alien.Kind.SPITTER, ship.to_global(Vector3(0, 8, -30)), 1.0, 1.0) as Alien
	await wait(0.8)
	print("[autotest] station defence: intruder %s, ship hull %.0f -> %.0f" % ["shot down" if not is_instance_valid(intruder) else "ALIVE", hull0, ship.hull])
	ship.apply_damage(50.0, ship.global_position, "test")
	print("[autotest] damage while docked: hull %.0f (unchanged = safe haven)" % ship.hull)
	# Walk down the ramp onto the pier and into the station.
	p.exit_station(true)
	await wait(0.3)
	p.position = Vector3(0, 0.05, 10.6)
	p.look_yaw = PI
	p.look_pitch = -0.1
	p.reset_physics_interpolation()
	await wait(0.3)
	await shot("st05_ramp_inside")
	Input.action_press("move_forward")
	await wait(1.6)
	print("[autotest] on the ramp/pier: ", p.position)
	await shot("st06_pier")
	await wait(2.4)
	Input.action_release("move_forward")
	await wait(0.4)
	print("[autotest] walked to: %s (in station: %s), crew outside: '%s'" % [p.position, p.position.z > StationBuilder.FACADE_Z - StationBuilder.LAND_HEIGHT, ship.crew_outside()])
	p.look_pitch = -0.25
	await wait(0.2)
	await shot("st07_room")
	# Hull kit: carry it aboard on foot and fit it at the install hub.
	ship.hull = ship.max_hull - 200.0
	var kit: SupplyCrate = null
	var weapon: SupplyCrate = null
	var cannon: SupplyCrate = null
	var other: SupplyCrate = null
	for c in ship.cargo_root.get_children():
		var crate := c as SupplyCrate
		if crate.item == "hull_kit" and kit == null:
			kit = crate
		elif RunItems.is_weapon(crate.item) and weapon == null:
			weapon = crate
		elif crate.item == "autocannon":
			cannon = crate
		elif other == null and crate.item != "hull_kit":
			other = crate
	print("[autotest] picked up hull kit: ", await _pick_up(m, p, kit))
	await shot("st08_carrying")
	p.position = Vector3(0, -0.95, 22.0)
	p.look_yaw = 0.0
	p.look_pitch = 0.0
	p.reset_physics_interpolation()
	Input.action_press("move_forward")
	await wait(4.5)
	Input.action_release("move_forward")
	await wait(0.3)
	print("[autotest] walked back aboard with the crate: pos %s aboard=%s carrying=%s" % [p.position, Mothership.is_aboard(p.position), p.carrying != null])
	p.position = ShipBuilder.INSTALL_HUB + Vector3(1.7, 0.05, 0)
	p.reset_physics_interpolation()
	await wait(0.2)
	_face(p, ShipBuilder.INSTALL_HUB + Vector3(0.6, 0.9, 0))
	await wait(0.3)
	print("[autotest] hub prompt: ", p.prompt)
	await shot("st09_hub")
	var hull1 := ship.hull
	await _tap("interact")
	await wait(0.3)
	print("[autotest] hull kit installed: hull %.0f -> %.0f, mods %s, kit freed %s" % [hull1, ship.hull, ship.run_mods, not is_instance_valid(kit)])
	p.look_pitch = 0.15
	await wait(0.3)
	await shot("st09b_hub_screen")
	# Weapon crate onto the port gun.
	if weapon:
		var w := RunItems.weapon_of(weapon.item)
		print("[autotest] picked up weapon %s: %s" % [w, await _pick_up(m, p, weapon)])
		var seat: Vector3 = ShipBuilder.STATIONS["gun_l"]["seat"]
		p.position = seat + Vector3(0.7, 0.05, 0)
		p.reset_physics_interpolation()
		await wait(0.2)
		_face(p, ShipBuilder.STATIONS["gun_l"]["console"] + Vector3(0, 0.9, 0))
		await wait(0.3)
		print("[autotest] gun prompt: ", p.prompt)
		await _tap("interact")
		await wait(0.3)
		print("[autotest] port gun weapon now: %s (wanted %s)" % [ship.stats["weapon_left"], w])
	# Auto cannon at the hub.
	if cannon:
		print("[autotest] picked up auto cannon: ", await _pick_up(m, p, cannon))
		p.position = ShipBuilder.INSTALL_HUB + Vector3(1.7, 0.05, 0)
		p.reset_physics_interpolation()
		await wait(0.2)
		_face(p, ShipBuilder.INSTALL_HUB + Vector3(0.6, 0.9, 0))
		await wait(0.2)
		await _tap("interact")
		await wait(0.3)
		print("[autotest] auto cannons installed: ", ship.autocannons)
	# A general upgrade: carry it, drop it on the floor with G, then leave it.
	if other:
		print("[autotest] picked up %s: %s" % [other.item, await _pick_up(m, p, other)])
		await _tap("drop")
		await wait(0.3)
		print("[autotest] dropped: carrier=%d pos=%s" % [other.carrier, other.net_pos])
	# Back aboard and lift off. Crates left outside stay at the station.
	print("[autotest] crates before liftoff: ", _crate_list(m))
	p.position = Vector3(0, -0.95, 18.0)
	p.reset_physics_interpolation()
	await wait(0.3)
	print("[autotest] crew outside (player on pier): '%s'" % ship.crew_outside())
	p.position = ShipBuilder.SPAWN_POINTS[0]
	p.reset_physics_interpolation()
	await wait(0.3)
	ship.request_station.rpc_id(1, "pilot")
	await wait(0.4)
	await _tap("land")
	print("[autotest] liftoff requested: state ", ship.landing)
	t0 = Time.get_ticks_msec()
	while ship.landing != Mothership.Dock.FLYING and Time.get_ticks_msec() - t0 < 30000:
		await wait(0.5)
	print("[autotest] flying again: %s after %.1f s, ramp %.2f, gear %.2f, crates aboard: %s" % [ship.landing == Mothership.Dock.FLYING,
		(Time.get_ticks_msec() - t0) / 1000.0, ship.ramp, ship.gear, _crate_list(m)])
	print("[autotest] left at the station: ", ship._station_cargo.get(0, []).size(), " crates")
	await shot("st10_liftoff")
	# Fly on, then let the auto cannon handle a spitter.
	var s1 := float(st["s"]) + 140.0
	ship.global_position = m.cave.center3(s1) + Vector3(0, -1.4, 0)
	ship.reset_physics_interpolation()
	for i in 300:
		await get_tree().process_frame
		if m._chunks_ready_near(s1):
			break
	if ship.autocannons > 0:
		for a in get_tree().get_nodes_in_group("aliens"):
			a.queue_free()
		await wait(0.2)
		var target := m.spawn_alien(Alien.Kind.SPITTER, ship.to_global(Vector3(5, 9, -22)), 1.0, 1.0) as Alien
		target.set_physics_process(false)
		var kills0 := m.kills
		var hp0 := target.hp
		await wait(0.6)
		print("[autotest] auto cannon target: %s, aim %s, target hp %.0f -> %.0f" % [ship._auto_target, ship.auto_aim, hp0,
			target.hp if is_instance_valid(target) else 0.0])
		await shot("st11_autocannon")
		await wait(2.4)
		print("[autotest] auto cannon vs spitter: %s, kills %d -> %d" % ["KILLED" if not is_instance_valid(target) else "alive hp %.0f" % target.hp, kills0, m.kills])
	_status(m)


func _clear_aliens() -> void:
	for a in get_tree().get_nodes_in_group("aliens"):
		a.queue_free()


## Notes.txt features: bots on the mining laser, side guns covering the bow, auto cannons bought
## for the hull edges, laser overcharge, calmer nests.
func _run_notes() -> void:
	Game.bot_count = 3
	Game.main.start_solo()
	await wait(1.0)
	var ups: Dictionary = Game.profile.get("upgrades", {})
	ups["laser_overcharge"] = 2
	ups["auto_cannons"] = 2
	Game.profile["upgrades"] = ups
	Game.profile_changed.emit()
	await wait(0.5)
	await shot("n01_homebase_cannons")
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
	print("[autotest] stats: edge_cannons=%d mining_vs_alien=%.1f active cannons=%s" % [
		int(ship.stats["edge_cannons"]), ship.stats["mining_vs_alien"], ship.active_cannons()])

	# 1) Bots: mine while it is quiet.
	var credits0 := ship.credits
	var mining_seen := 0
	for i in 40:
		_clear_aliens()
		await wait(0.5)
		if ship.mining_on:
			mining_seen += 1
	print("[autotest] quiet: occupants=%s mining_on %d/40 samples, credits %d -> %d | %s" % [ship.occupants, mining_seen, credits0, ship.credits, _bot_report(m)])
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
			if cm.bot and cm.brain.task == "mine" and ship.mining_on and instance_from_id(cm.brain._target_id) is Alien:
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

	# 5) Auto cannons on the hull edges.
	var side_target := m.spawn_alien(Alien.Kind.SPITTER, ship.to_global(Vector3(-17, 10, -6)), 1.0, 1.0) as Alien
	side_target.set_physics_process(false)
	var cam := Camera3D.new()
	m.add_child(cam)
	cam.global_position = ship.to_global(Vector3(-16, 12, 10))
	cam.look_at(ship.to_global(Vector3(-3, 3, -3)))
	cam.current = true
	await wait(0.8)
	await shot("n05_edge_cannons")
	await wait(2.5)
	print("[autotest] edge cannons vs spitter: %s, aims %s" % ["KILLED" if not is_instance_valid(side_target) else "alive hp %.0f" % side_target.hp,
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
	var s0 := float(st["s"]) - 40.0
	ship.global_position = m.cave.center3(s0) + Vector3(0, -1.4, 0)
	var t := m.cave.tangent(s0)
	ship.rotation.y = atan2(-t.x, -t.z)
	ship.reset_physics_interpolation()
	for i in 600:
		await get_tree().process_frame
		if m._chunks_ready_near(s0) and m._chunks_ready_near(float(st["s"])):
			break
	ship.request_station.rpc_id(1, "pilot")
	await wait(0.5)
	await _tap("land")
	for i in 400:
		await wait(0.1)
		if ship.landing == Mothership.Dock.LANDED:
			break
	print("[autotest] host: landed=%s" % (ship.landing == Mothership.Dock.LANDED))
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
	print("[autotest] host: flying again=%s, left at station %d" % [ship.landing == Mothership.Dock.FLYING, ship._station_cargo.get(0, []).size()])
	await wait(3.0)
	m.abort_mission()
	await wait(6.0)


## Multiplayer waystation test, client side: walk out, carry a crate aboard, install it.
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
	var to := target - m.scout.global_position
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
			if t > timeout or m.scout.state != Scout.State.FLYING:
				Input.action_release("move_forward")
				print("[autotest] scout stuck at %s heading to %s (state %d)" % [m.scout.global_position, pt, m.scout.state])
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
	print("[autotest] scout state=%d station=%s" % [m.scout.state, m.local_player.station])
	var route: Array = [pts[0]]
	for i in range(1, pts.size()):
		route.append(pts[i])
	route.append(tunnel["chamber"])
	var ok := await _scout_fly_path(m, route, 3.0, 25.0)
	print("[autotest] reached chamber: %s, scout hull %.0f" % [ok, m.scout.hp])
	await shot("s01_chamber")
	# Shoot every fuel crystal nearby.
	var fuel_deps: Array = []
	for d in get_tree().get_nodes_in_group("deposits"):
		var dep := d as Deposit
		if dep.kind == "fuel" and dep.global_position.distance_to(m.scout.global_position) < 25.0:
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
	print("[autotest] scout cargo after mining: %.1f / %.1f" % [m.scout.cargo, m.scout.max_cargo])
	await shot("s02_mined")
	# Fly back out and dock.
	var back: Array = []
	for i in range(pts.size() - 1, -1, -1):
		back.append(pts[i])
	ok = await _scout_fly_path(m, back, 3.0, 25.0)
	var dock := m.ship.to_global(ShipBuilder.DOCK_POINT)
	ok = await _scout_fly_path(m, [dock + Vector3(0, -4, 0)], 5.0, 20.0)
	await shot("s03_return")
	m.scout.request_dock.rpc_id(1)
	await wait(0.5)
	print("[autotest] docked=%s station=%s ship fuel %.1f -> %.1f" % [m.scout.state == Scout.State.DOCKED,
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
		var a := m.spawn_alien(Alien.Kind.SPITTER, ship.to_global(ShipBuilder.SHIELD_CENTER + Vector3(0, 0, -d)), 1.0, 1.0) as Alien
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
		m.scout.global_position = pts[1]
		m.scout.reset_physics_interpolation()
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
	for i in 18:
		await wait(10.0)
		m.ship.fuel = m.ship.max_fuel
		m.ship.engine_hp = 100.0
		var nests := get_tree().get_nodes_in_group("nests").size()
		print("[autotest] soak depth=%.0f (+%.0f) hull=%.0f aliens=%d nests=%d deposits=%d pickups=%d chunks=%d boarders=%d kills=%d fps=%d" % [
			m.ship.depth, m.ship.depth - last_depth, m.ship.hull, get_tree().get_nodes_in_group("aliens").size(), nests,
			get_tree().get_nodes_in_group("deposits").size(), m.pickup_root.get_child_count(), m.cave_root.get_child_count(),
			m.ship.boarders, m.kills, Engine.get_frames_per_second()])
		if m.ship.depth - last_depth < 5.0 and i > 1:
			print("[autotest] WARNING: ship seems stuck at ", m.ship.global_position)
		last_depth = m.ship.depth
	Engine.time_scale = 1.0
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
		ship.stats["weapon_left"] = weapon
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
	var scout := m.scout
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


## Run the ship into the ground: destruction ends the mission and pays out; then shop.
func _run_death() -> void:
	Game.reset_profile()
	var m := await _start_solo_mission()
	m.ship.credits = 300
	m.ship.depth = 222.0
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
	print("[autotest] after destruction: credits=%d best=%d last=%s" % [Game.credits(), int(Game.profile["best_depth"]), Game.profile["last_mission"]])
	await shot("x_homebase_after")
	var hull_before: float = Game.ship_stats()["max_hull"]
	Game.request_buy_upgrade("hull")
	Game.request_buy_weapon("flak")
	Game.request_equip("right", "flak")
	await wait(0.5)
	print("[autotest] bought hull: max_hull %.0f -> %.0f, credits now %d, weapons %s, loadout %s" % [
		hull_before, Game.ship_stats()["max_hull"], Game.credits(), Game.profile["weapons"], Game.profile["loadout"]])
	await shot("x_shop")


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
	print("[autotest] client sees ship at ", m.ship.global_position, " scout=", m.scout != null, " chunks=", m.cave_root.get_child_count())
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
	print("[autotest] client back at: ", Game.main.current_level().name if Game.main.current_level() else "none", " credits(view)=", Game.credits())
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
