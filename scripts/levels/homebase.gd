class_name HomebaseLevel
extends Node3D
## Hub between missions: the selected mothership on display, the shipyard and the mission launcher.
##
## The shipyard spends research points (earned at the end of every dive, more the deeper the crew
## got): unlock motherships and choose which one to fly, upgrade each ship's hull, shield, engines
## and turret slots, and unlock guns, which then turn up in waystation shops during dives. Research
## points are shared by the whole crew. Purchases are requested from the server, which validates
## them and pushes the updated profile to everyone.

var _cam: Camera3D
var _cam_t := 0.0
var _cam_r := 44.0
var _rp_label: Label
var _stats_label: Label
var _report_box: VBoxContainer
var _crew_box: VBoxContainer
var _tabs: TabContainer
var _launch_btn: Button
var _ship_label: Label
var _wait_label: Label
## The display ship and the type it shows.
var _display: Node3D
var _display_type := ""
## The cheat menu and its button (debug builds, host only).
var _cheat_btn: Button
var _cheats: CheatMenu


func setup(_data: Dictionary) -> void:
	pass


func _ready() -> void:
	_build_world()
	_build_ui()
	Game.profile_changed.connect(_refresh)
	Net.roster_changed.connect(_refresh_crew)
	_refresh()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _process(delta: float) -> void:
	_cam_t += delta * 0.06
	_cam.position = Vector3(sin(_cam_t) * _cam_r, 11.0 + sin(_cam_t * 0.7) * 3.0, cos(_cam_t) * _cam_r)
	_cam.look_at(Vector3(0, 0.5, -1.5))


func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.025, 0.035)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.5, 0.6)
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.ssao_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var floor_mat := Models.panel_mat(Color(0.2, 0.22, 0.25), 0.5, 0.5, 0.15)
	Models.box(self, Vector3(0, -4.5, 0), Vector3(140, 1, 140), floor_mat)
	var pad := Models.cylinder(self, Vector3(0, -3.9, 0), 19.0, 0.2, Models.mat(Color(0.28, 0.3, 0.33), 0.3, 0.5), Vector3.ZERO, -1.0, 48)
	pad.name = "Pad"
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 18.7
	torus.outer_radius = 19.1
	torus.rings = 64
	ring.mesh = torus
	ring.material_override = Models.emissive(Color(1.0, 0.6, 0.15), 1.5)
	ring.position = Vector3(0, -3.8, 0)
	ring.scale = Vector3(1, 0.15, 1)
	add_child(ring)
	for a in 8:
		var ang := TAU * a / 8.0
		Models.box(self, Vector3(cos(ang) * 14.5, -3.75, sin(ang) * 14.5), Vector3(2.4, 0.04, 0.5),
				Models.emissive(Color(0.3, 0.8, 1.0), 2.0), Vector3(0, -rad_to_deg(ang), 0))
	# Hangar walls with light strips.
	var wall_mat := Models.panel_mat(Color(0.3, 0.32, 0.36), 0.4, 0.6, 0.1)
	for i in 4:
		var wall := Node3D.new()
		wall.rotation.y = i * PI / 2.0
		add_child(wall)
		Models.box(wall, Vector3(0, 10, -55), Vector3(110, 30, 1), wall_mat)
		for k in 7:
			Models.box(wall, Vector3(-45 + k * 15, 6, -54.4), Vector3(0.6, 14, 0.2), Models.emissive(Color(0.9, 0.95, 1.0), 1.6))
		Models.box(wall, Vector3(0, -3.0, -54.4), Vector3(110, 0.3, 0.2), Models.emissive(Color(1.0, 0.55, 0.1), 2.0))
	# Gantries.
	var gantry := Models.mat(Color(0.75, 0.55, 0.15), 0.5, 0.5)
	for side: float in [-1.0, 1.0]:
		Models.box(self, Vector3(side * 18, 3, 0), Vector3(1, 14, 1), gantry)
		Models.box(self, Vector3(side * 18, 10, 0), Vector3(1, 1, 34), gantry)
		Models.box(self, Vector3(side * 18, 3, 16), Vector3(1, 14, 1), gantry)
		Models.box(self, Vector3(side * 18, 3, -16), Vector3(1, 14, 1), gantry)

	for p: Vector3 in [Vector3(-20, 22, -10), Vector3(20, 22, 10), Vector3(0, 24, 25)]:
		var spot := SpotLight3D.new()
		spot.position = p
		spot.look_at_from_position(p, Vector3.ZERO)
		spot.spot_range = 60.0
		spot.spot_angle = 32.0
		spot.light_energy = 6.0
		if p.z > 20.0:
			ShipBuilder.configure_shadow(spot)
		add_child(spot)
	var fill := OmniLight3D.new()
	fill.position = Vector3(0, 12, 0)
	fill.omni_range = 60.0
	fill.light_energy = 0.8
	add_child(fill)

	_cam = Camera3D.new()
	_cam.fov = 55.0
	_cam.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	# Shift the view so the ship sits between the two UI panels.
	_cam.h_offset = 7.0
	add_child(_cam)
	_cam.current = true
	_cam_t = 0.6


## Show the selected ship on the pad, standing on its landing legs (feet on the pad top at -3.8).
func _show_ship(type_id: String) -> void:
	if _display_type == type_id:
		return
	_display_type = type_id
	if _display:
		_display.queue_free()
	_display = Node3D.new()
	_display.name = "ShipDisplay"
	_display.position = Vector3(0, -3.8 + 4.2, 0)
	add_child(_display)
	var parts := ShipBuilder.build_exterior(_display, type_id)
	for l in parts.get("lights", []):
		(l as Light3D).light_energy *= 0.4
	var mat: StandardMaterial3D = parts["engine_glow_mat"]
	mat.albedo_color = Color(0.3, 0.6, 0.8)
	for leg: Dictionary in parts["legs"]:
		(leg["node"] as Node3D).rotation.x = 0.0
	var t := ShipTypes.get_type(type_id)
	for sid: String in t["scouts"]:
		var scout := Node3D.new()
		scout.position = t["by_id"][sid]["dock"]
		_display.add_child(scout)
		Scout.build_model(scout, t["scout_style"])
	_display.set_meta("cannons", parts["autocannons"])
	_cam_r = float(t.get("chase", 40.0)) + 4.0


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.theme = UiTheme.get_theme()
	UiTheme.full_rect(root)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	# Left: research points, crew status and last mission.
	var left := PanelContainer.new()
	left.position = Vector2(24, 24)
	left.custom_minimum_size = Vector2(400, 0)
	root.add_child(left)
	var lbox := VBoxContainer.new()
	lbox.add_theme_constant_override("separation", 8)
	left.add_child(lbox)
	lbox.add_child(UiTheme.label("HOMEBASE", 34, UiTheme.ACCENT))
	_rp_label = UiTheme.label("", 30, UiTheme.GOLD)
	lbox.add_child(_rp_label)
	_stats_label = UiTheme.label("", 16, UiTheme.MUTED)
	lbox.add_child(_stats_label)
	lbox.add_child(HSeparator.new())
	_report_box = VBoxContainer.new()
	lbox.add_child(_report_box)
	lbox.add_child(HSeparator.new())
	lbox.add_child(UiTheme.label("CREW", 20, UiTheme.ACCENT))
	_crew_box = VBoxContainer.new()
	lbox.add_child(_crew_box)

	# Right: the shipyard.
	var right := PanelContainer.new()
	right.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	right.offset_left = -700
	right.offset_right = -24
	right.offset_top = 24
	right.offset_bottom = -130
	root.add_child(right)
	var rbox := VBoxContainer.new()
	right.add_child(rbox)
	rbox.add_child(UiTheme.label("SHIPYARD", 26, UiTheme.ACCENT))
	var note := UiTheme.label("Spend research points here. Credits you mine only buy supplies in waystation shops during a dive.", 14, UiTheme.MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD
	rbox.add_child(note)
	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rbox.add_child(_tabs)

	# Bottom: launch.
	var bottom := VBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bottom.offset_top = -124
	bottom.offset_bottom = -24
	bottom.offset_left = -240
	bottom.offset_right = 240
	bottom.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(bottom)
	_ship_label = UiTheme.label("", 18, UiTheme.TEXT)
	_ship_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_child(_ship_label)
	_launch_btn = UiTheme.button("LAUNCH MISSION", func(): Game.main.start_mission())
	_launch_btn.custom_minimum_size = Vector2(480, 58)
	_launch_btn.add_theme_font_size_override("font_size", 26)
	bottom.add_child(_launch_btn)
	_wait_label = UiTheme.label("Waiting for the host to launch the mission...", 18, UiTheme.MUTED)
	_wait_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_child(_wait_label)
	var hint := UiTheme.label("Esc: menu", 14, UiTheme.MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_child(hint)

	# Bottom left: the cheat menu, for testing.
	if Game.cheats_allowed():
		_cheat_btn = UiTheme.button("CHEATS", func(): _cheats.visible = not _cheats.visible, 130)
		_cheat_btn.add_theme_color_override("font_color", UiTheme.WARN)
		_cheat_btn.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		_cheat_btn.offset_left = 24
		_cheat_btn.offset_right = 154
		_cheat_btn.offset_top = -64
		_cheat_btn.offset_bottom = -24
		root.add_child(_cheat_btn)
		_cheats = CheatMenu.new()
		_cheats.visible = false
		_cheats.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		_cheats.offset_left = 24
		_cheats.offset_top = -76
		_cheats.offset_bottom = -76
		_cheats.grow_vertical = Control.GROW_DIRECTION_BEGIN
		root.add_child(_cheats)


func _refresh() -> void:
	var p := Game.profile
	var ship_id := Game.selected_ship()
	_show_ship(ship_id)
	# Unlocked turret slots show as empty mounts on the display ship.
	var cannons: Array = _display.get_meta("cannons", [])
	var slots := Game.turret_slots(ship_id)
	for i in cannons.size():
		(cannons[i]["root"] as Node3D).visible = i < slots
	_rp_label.text = "%s RP" % _fmt(Game.rp())
	_stats_label.text = "Research points: earned after every dive, more the deeper you get.\nDeepest dive: %d m\nMissions flown: %d\nResearch earned in total: %s RP" % [
		int(p.get("best_depth", 0)), int(p.get("missions", 0)), _fmt(int(p.get("rp_total", 0)))]
	for c in _report_box.get_children():
		c.queue_free()
	var last: Dictionary = p.get("last_mission", {})
	if p.has("migrated"):
		var mig: Dictionary = p["migrated"]
		_report_box.add_child(UiTheme.label("NEW SHIPYARD", 20, UiTheme.ACCENT))
		var text := UiTheme.label("Homebase upgrades are gone: upgrades are now bought in waystation shops during a dive.\nYour old progress was converted into %s research points%s." % [
			_fmt(int(mig.get("rp", 0))), " and your bought guns stay unlocked" if int(mig.get("guns", 0)) > 0 else ""], 15)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD
		text.custom_minimum_size.x = 370
		_report_box.add_child(text)
	elif last.is_empty() or not last.has("rp"):
		_report_box.add_child(UiTheme.label("No missions yet.\nDive deep, mine minerals for the shops,\nand bring back research points.", 16, UiTheme.MUTED))
	else:
		_report_box.add_child(UiTheme.label("LAST MISSION", 20, UiTheme.ACCENT))
		var outcome := "Mothership destroyed" if last.get("destroyed", false) else "Mission aborted"
		_report_box.add_child(UiTheme.label("%s (%s)" % [outcome, ShipTypes.display_name(str(last.get("ship", "prospector")))], 16,
				UiTheme.DANGER if last.get("destroyed", false) else UiTheme.WARN))
		var lines := "Depth reached: %d m%s\nWaystations reached: %d\nNests destroyed: %d   Aliens killed: %d\nCredits mined: %s CR (spent in shops, the rest is lost)\nResearch: depth +%d, waystations +%d, nests +%d" % [
			int(last.get("depth", 0)), "  NEW RECORD!" if last.get("record", false) else "", int(last.get("stations", 0)),
			int(last.get("nests", 0)), int(last.get("kills", 0)), _fmt(int(last.get("mined", 0))),
			int(last.get("rp_depth", 0)), int(last.get("rp_stations", 0)), int(last.get("rp_nests", 0))]
		_report_box.add_child(UiTheme.label(lines, 15))
		_report_box.add_child(UiTheme.label("Earned: +%s RP" % _fmt(int(last.get("rp", 0))), 18, UiTheme.GOLD))
	var t := ShipTypes.get_type(ship_id)
	_ship_label.text = "Flying the %s  -  %s" % [t["name"], t["role"]]
	_launch_btn.visible = multiplayer.is_server()
	_wait_label.visible = not multiplayer.is_server()
	if _cheat_btn:
		_cheat_btn.visible = multiplayer.is_server()
		_cheats.visible = _cheats.visible and multiplayer.is_server()
	_rebuild_shop()
	_refresh_crew()


func _refresh_crew() -> void:
	for c in _crew_box.get_children():
		c.queue_free()
	var ids := Net.roster.keys()
	# Humans first (host, then by id), then bots in the order they were added.
	ids.sort_custom(func(a, b): return (a > 0 and b < 0) or (a > 0 and b > 0 and a < b) or (a < 0 and b < 0 and a > b))
	for id in ids:
		var row := HBoxContainer.new()
		var swatch := ColorRect.new()
		swatch.color = Net.player_color(id)
		swatch.custom_minimum_size = Vector2(14, 14)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(swatch)
		var tag := "  (host)" if id == 1 and Net.mode != "solo" else ""
		if id == multiplayer.get_unique_id():
			tag += "  (you)"
		if Net.is_bot(id):
			tag += "  [bot]"
		row.add_child(UiTheme.label(" " + Net.player_name(id) + tag, 17, UiTheme.MUTED if Net.is_bot(id) else UiTheme.TEXT))
		_crew_box.add_child(row)
	if multiplayer.is_server():
		var bots := HBoxContainer.new()
		bots.add_theme_constant_override("separation", 6)
		bots.add_child(UiTheme.label("Crew bots: %d" % Net.bot_ids().size(), 16))
		var add := UiTheme.button("+ Bot", _add_bot, 70)
		add.disabled = Net.roster.size() >= Net.MAX_PLAYERS
		bots.add_child(add)
		var remove := UiTheme.button("- Bot", _remove_bot, 70)
		remove.disabled = Net.bot_ids().is_empty()
		bots.add_child(remove)
		_crew_box.add_child(bots)
		var hint := UiTheme.label("Bots repair the ship, man the guns and mining lasers and\nfight off boarders. Joining players take a bot's slot.", 14, UiTheme.MUTED)
		_crew_box.add_child(hint)
	if Net.mode == "host":
		_crew_box.add_child(UiTheme.label("Friends join on port %d." % Net.DEFAULT_PORT, 14, UiTheme.MUTED))


func _add_bot() -> void:
	if Net.add_bot():
		Game.bot_count = Net.bot_ids().size()
		Game.save_settings()


func _remove_bot() -> void:
	if Net.remove_bot():
		Game.bot_count = Net.bot_ids().size()
		Game.save_settings()


func _rebuild_shop() -> void:
	var current := _tabs.current_tab
	for c in _tabs.get_children():
		_tabs.remove_child(c)
		c.queue_free()
	var ships := _new_tab("Ships")
	for id: String in ShipTypes.ORDER:
		ships.add_child(_ship_row(id))
	var ups := _new_tab("Upgrades")
	var ship_id := Game.selected_ship()
	ups.add_child(UiTheme.label("Upgrades for the %s (each ship keeps its own)" % ShipTypes.display_name(ship_id), 17, UiTheme.ACCENT))
	for up: String in Game.SHIP_UPGRADE_ORDER:
		ups.add_child(_upgrade_row(ship_id, up))
	var armory := _new_tab("Armory")
	var hint := UiTheme.label("Every gun launches with a Pulse Cannon. Unlocked guns turn up in waystation shops, where the crew can buy them and mount them at a gun console.", 15, UiTheme.MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	armory.add_child(hint)
	for id: String in Game.GUN_ORDER:
		armory.add_child(_gun_row(id))
	if current >= 0 and current < _tabs.get_tab_count():
		_tabs.current_tab = current


func _new_tab(title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tabs.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 12)
	scroll.add_child(list)
	return list


func _ship_row(id: String) -> Control:
	var t := ShipTypes.get_type(id)
	var stats := Game.ship_stats(id)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(UiTheme.label("%s  -  %s" % [t["name"], t["role"]], 19, UiTheme.GOLD if id == Game.selected_ship() else UiTheme.TEXT))
	var desc := UiTheme.label(str(t["desc"]), 14, UiTheme.MUTED)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	info.add_child(desc)
	# Non-breaking spaces keep each name with its value when the line wraps.
	var line := UiTheme.label("Hull %d  -  Shield %d  -  Speed %.1f  -  Guns %d  -  Mining lasers %d  -  Scouts %d  -  Turret slots %d/%d" % [
		int(stats["max_hull"]), int(stats["max_shield"]), float(stats["max_speed"]), (t["guns"] as Array).size(),
		(t["lasers"] as Array).size(), (t["scouts"] as Array).size(), int(stats["turret_slots"]), int(t["max_slots"])], 14, UiTheme.ACCENT)
	line.autowrap_mode = TextServer.AUTOWRAP_WORD
	info.add_child(line)
	row.add_child(info)
	var btn: Button
	if Game.owns_ship(id):
		if id == Game.selected_ship():
			btn = UiTheme.button("SELECTED", func(): pass, 150)
			btn.disabled = true
		else:
			btn = UiTheme.button("SELECT", func(): Game.request_select_ship(id), 150)
	else:
		var cost := int(t["cost"])
		btn = UiTheme.button("UNLOCK %s RP" % _fmt(cost), func(): Game.request_unlock_ship(id), 150)
		btn.disabled = Game.rp() < cost
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(btn)
	return row


func _upgrade_row(ship_id: String, up: String) -> Control:
	var u: Dictionary = Game.SHIP_UPGRADES[up]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lvl := Game.ship_level(ship_id, up)
	var max_lvl := Game.ship_upgrade_max(ship_id, up)
	info.add_child(UiTheme.label("%s   %s" % [u["name"], "■".repeat(lvl) + "□".repeat(maxi(max_lvl - lvl, 0))], 19))
	var stats := Game.ship_stats(ship_id)
	var now := ""
	match up:
		"hull":
			now = "Max hull %d" % int(stats["max_hull"])
		"shield":
			now = "Max shield %d" % int(stats["max_shield"])
		"engine":
			now = "Top speed %.1f m/s" % float(stats["max_speed"])
		"slots":
			now = "Turret slots %d of %d hardpoints" % [int(stats["turret_slots"]), int(ShipTypes.get_type(ship_id)["max_slots"])]
	var desc := UiTheme.label("%s.  Now: %s" % [str(u["desc"]).trim_suffix("."), now], 14, UiTheme.MUTED)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	info.add_child(desc)
	row.add_child(info)
	var cost := Game.ship_upgrade_cost(ship_id, up)
	var btn: Button
	if cost < 0:
		btn = UiTheme.button("MAXED", func(): pass, 140)
		btn.disabled = true
	else:
		btn = UiTheme.button("%s RP" % _fmt(cost), func(): Game.request_ship_upgrade(up), 140)
		btn.disabled = Game.rp() < cost
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(btn)
	return row


func _gun_row(id: String) -> Control:
	var g: Dictionary = Game.GUNS[id]
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(UiTheme.label(g["name"], 19))
	info.add_child(UiTheme.label(g["desc"], 14, UiTheme.MUTED))
	row.add_child(info)
	var btn: Button
	if Game.owns_gun(id):
		btn = UiTheme.button("STANDARD" if int(g["rp"]) == 0 else "UNLOCKED", func(): pass, 150)
		btn.disabled = true
	else:
		btn = UiTheme.button("UNLOCK %s RP" % _fmt(int(g["rp"])), func(): Game.request_unlock_gun(id), 150)
		btn.disabled = Game.rp() < int(g["rp"])
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(btn)
	return row


static func _fmt(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out
