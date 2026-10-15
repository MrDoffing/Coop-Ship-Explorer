class_name HomebaseLevel
extends Node3D
## Hub between missions: the docked mothership, the upgrade shop and the mission launcher.
##
## Credits are shared by the whole crew. Purchases are requested from the server, which validates
## them and pushes the updated profile to everyone.

var _cam: Camera3D
var _cam_t := 0.0
var _credits_label: Label
var _stats_label: Label
var _report_box: VBoxContainer
var _crew_box: VBoxContainer
var _tabs: TabContainer
var _launch_btn: Button
var _wait_label: Label
## Auto cannon turrets on the display ship (shown once bought).
var _display_cannons: Array = []


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
	var r := 44.0
	_cam.position = Vector3(sin(_cam_t) * r, 11.0 + sin(_cam_t * 0.7) * 3.0, cos(_cam_t) * r)
	_cam.look_at(Vector3(0, 0.5, 0))


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
	var pad := Models.cylinder(self, Vector3(0, -3.9, 0), 17.0, 0.2, Models.mat(Color(0.28, 0.3, 0.33), 0.3, 0.5), Vector3.ZERO, -1.0, 48)
	pad.name = "Pad"
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 16.7
	torus.outer_radius = 17.1
	torus.rings = 64
	ring.mesh = torus
	ring.material_override = Models.emissive(Color(1.0, 0.6, 0.15), 1.5)
	ring.position = Vector3(0, -3.8, 0)
	ring.scale = Vector3(1, 0.15, 1)
	add_child(ring)
	for a in 8:
		var ang := TAU * a / 8.0
		Models.box(self, Vector3(cos(ang) * 13.0, -3.75, sin(ang) * 13.0), Vector3(2.4, 0.04, 0.5),
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
		Models.box(self, Vector3(side * 16, 3, 0), Vector3(1, 14, 1), gantry)
		Models.box(self, Vector3(side * 16, 10, 0), Vector3(1, 1, 30), gantry)
		Models.box(self, Vector3(side * 16, 3, 14), Vector3(1, 14, 1), gantry)
		Models.box(self, Vector3(side * 16, 3, -14), Vector3(1, 14, 1), gantry)

	var ship := Node3D.new()
	ship.name = "ShipDisplay"
	# Standing on its landing legs, feet on the pad (whose top is at y = -3.8).
	var leg_hinge: Vector3 = ShipBuilder.LEGS[0]
	ship.position = Vector3(0, -3.8 - leg_hinge.y + ShipBuilder.LEG_LENGTH, 0)
	add_child(ship)
	var parts := ShipBuilder.build_exterior(ship)
	_display_cannons = parts["autocannons"]
	for l in parts.get("lights", []):
		(l as Light3D).light_energy *= 0.4
	var mat: StandardMaterial3D = parts["engine_glow_mat"]
	mat.albedo_color = Color(0.3, 0.6, 0.8)
	var scout := Node3D.new()
	scout.position = ShipBuilder.DOCK_POINT
	ship.add_child(scout)
	Scout.build_model(scout)

	for p: Vector3 in [Vector3(-20, 22, -10), Vector3(20, 22, 10), Vector3(0, 24, 25)]:
		var spot := SpotLight3D.new()
		spot.position = p
		spot.look_at_from_position(p, Vector3.ZERO)
		spot.spot_range = 60.0
		spot.spot_angle = 30.0
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


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.theme = UiTheme.get_theme()
	UiTheme.full_rect(root)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	# Left: crew status and last mission.
	var left := PanelContainer.new()
	left.position = Vector2(24, 24)
	left.custom_minimum_size = Vector2(390, 0)
	root.add_child(left)
	var lbox := VBoxContainer.new()
	lbox.add_theme_constant_override("separation", 8)
	left.add_child(lbox)
	lbox.add_child(UiTheme.label("HOMEBASE", 34, UiTheme.ACCENT))
	_credits_label = UiTheme.label("", 30, UiTheme.GOLD)
	lbox.add_child(_credits_label)
	_stats_label = UiTheme.label("", 16, UiTheme.MUTED)
	lbox.add_child(_stats_label)
	lbox.add_child(HSeparator.new())
	_report_box = VBoxContainer.new()
	lbox.add_child(_report_box)
	lbox.add_child(HSeparator.new())
	lbox.add_child(UiTheme.label("CREW", 20, UiTheme.ACCENT))
	_crew_box = VBoxContainer.new()
	lbox.add_child(_crew_box)

	# Right: upgrade shop.
	var right := PanelContainer.new()
	right.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	right.offset_left = -680
	right.offset_right = -24
	right.offset_top = 24
	right.offset_bottom = -120
	root.add_child(right)
	var rbox := VBoxContainer.new()
	right.add_child(rbox)
	rbox.add_child(UiTheme.label("SHIPYARD", 26, UiTheme.ACCENT))
	_tabs = TabContainer.new()
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rbox.add_child(_tabs)

	# Bottom: launch.
	var bottom := VBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bottom.offset_top = -104
	bottom.offset_bottom = -24
	bottom.offset_left = -220
	bottom.offset_right = 220
	bottom.alignment = BoxContainer.ALIGNMENT_END
	root.add_child(bottom)
	_launch_btn = UiTheme.button("LAUNCH MISSION", func(): Game.main.start_mission())
	_launch_btn.custom_minimum_size = Vector2(440, 58)
	_launch_btn.add_theme_font_size_override("font_size", 26)
	bottom.add_child(_launch_btn)
	_wait_label = UiTheme.label("Waiting for the host to launch the mission...", 18, UiTheme.MUTED)
	_wait_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_child(_wait_label)
	var hint := UiTheme.label("Esc: menu", 14, UiTheme.MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bottom.add_child(hint)


func _refresh() -> void:
	var p := Game.profile
	# Auto cannons bought for the hull edges show up on the display ship.
	for i in _display_cannons.size():
		(_display_cannons[i]["root"] as Node3D).visible = i < mini(Game.upgrade_level("auto_cannons"), ShipBuilder.EDGE_CANNONS)
	_credits_label.text = "%s CR" % _fmt(Game.credits())
	_stats_label.text = "Deepest dive: %d m\nMissions flown: %d\nTotal earned: %s CR" % [
		int(p.get("best_depth", 0)), int(p.get("missions", 0)), _fmt(int(p.get("total_earned", 0)))]
	for c in _report_box.get_children():
		c.queue_free()
	var last: Dictionary = p.get("last_mission", {})
	if last.is_empty():
		_report_box.add_child(UiTheme.label("No missions yet.\nDive deep, mine minerals,\nand bring the crew home richer.", 16, UiTheme.MUTED))
	else:
		_report_box.add_child(UiTheme.label("LAST MISSION", 20, UiTheme.ACCENT))
		var outcome := "Mothership destroyed" if last.get("destroyed", false) else "Mission aborted"
		_report_box.add_child(UiTheme.label(outcome, 16, UiTheme.DANGER if last.get("destroyed", false) else UiTheme.WARN))
		var lines := "Depth reached: %d m%s\nMinerals: %s CR\nDepth bonus: %s CR\nNests destroyed: %d (+%s CR)\nAliens killed: %d\nEarned: %s CR" % [
			int(last.get("depth", 0)), "  NEW RECORD!" if last.get("record", false) else "",
			_fmt(int(last.get("minerals", 0))), _fmt(int(last.get("depth_bonus", 0))),
			int(last.get("nests", 0)), _fmt(int(last.get("nest_bonus", 0))), int(last.get("kills", 0)),
			_fmt(int(last.get("earned", 0)))]
		_report_box.add_child(UiTheme.label(lines, 16))
	_launch_btn.visible = multiplayer.is_server()
	_wait_label.visible = not multiplayer.is_server()
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
		var hint := UiTheme.label("Bots repair the ship, man the side guns and fight\noff boarders. Joining players take a bot's slot.", 14, UiTheme.MUTED)
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
	for cat in Game.UPGRADE_CATEGORIES:
		var list := _new_tab(cat)
		for id in Game.UPGRADES:
			var u: Dictionary = Game.UPGRADES[id]
			if u["cat"] == cat:
				list.add_child(_upgrade_row(id, u))
	var turrets := _new_tab("Turrets")
	var loadout: Dictionary = Game.profile.get("loadout", {})
	turrets.add_child(UiTheme.label("Port: %s    Starboard: %s" % [
		Game.WEAPONS[str(loadout.get("left", "pulse"))]["name"],
		Game.WEAPONS[str(loadout.get("right", "pulse"))]["name"]], 17, UiTheme.ACCENT))
	for id in Game.WEAPONS:
		turrets.add_child(_weapon_row(id, Game.WEAPONS[id], loadout))
	if current >= 0 and current < _tabs.get_tab_count():
		_tabs.current_tab = current


func _new_tab(title: String) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_tabs.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)
	return list


func _upgrade_row(id: String, u: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lvl := Game.upgrade_level(id)
	var max_lvl := int(u["max"])
	info.add_child(UiTheme.label("%s   %s" % [u["name"], "■".repeat(lvl) + "□".repeat(max_lvl - lvl)], 19))
	info.add_child(UiTheme.label(u["desc"], 15, UiTheme.MUTED))
	row.add_child(info)
	var cost := Game.upgrade_cost(id)
	var btn: Button
	if cost < 0:
		btn = UiTheme.button("MAXED", func(): pass, 140)
		btn.disabled = true
	else:
		btn = UiTheme.button("%s CR" % _fmt(cost), func(): Game.request_buy_upgrade(id), 140)
		btn.disabled = Game.credits() < cost
	row.add_child(btn)
	return row


func _weapon_row(id: String, w: Dictionary, loadout: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(UiTheme.label(w["name"], 19))
	info.add_child(UiTheme.label(w["desc"], 15, UiTheme.MUTED))
	row.add_child(info)
	if Game.owns_weapon(id):
		for slot: String in ["left", "right"]:
			var equipped := str(loadout.get(slot, "")) == id
			var b := UiTheme.button(("PORT" if slot == "left" else "STARBOARD") + (" ✓" if equipped else ""),
					func(): Game.request_equip(slot, id), 120)
			b.disabled = equipped
			row.add_child(b)
	else:
		var cost := int(w["cost"])
		var b := UiTheme.button("%s CR" % _fmt(cost), func(): Game.request_buy_weapon(id), 140)
		b.disabled = Game.credits() < cost
		row.add_child(b)
	return row


static func _fmt(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out
