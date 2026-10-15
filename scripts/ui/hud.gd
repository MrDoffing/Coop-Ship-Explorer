class_name Hud
extends CanvasLayer
## In-mission HUD: ship systems, depth and haul, crew roster, interaction prompts, station
## read-outs, alerts, the scout's dock marker, waystation markers, carried crates and
## end-of-mission banners.

## Waystations closer than this get a marker on screen.
const STATION_MARKER_RANGE := 320.0

var _root: Control
var _bars: Dictionary = {}
var _texts: Dictionary = {}
var _depth: Label
var _haul: Label
var _popup: Label
var _popup_value := 0
var _popup_t := 0.0
var _crew: Label
var _prompt: Label
var _hp_bar: ProgressBar
var _hp_text: Label
var _tool_label: Label
var _station_panel: PanelContainer
var _station_title: Label
var _station_info: Label
var _station_help: Label
var _toasts: VBoxContainer
var _crosshair: Control
var _hit_t := 0.0
var _hurt: ColorRect
var _banner: Label
var _banner_sub: Label
var _loading: Control
var _loading_label: Label
var _dock_marker: Label
var _station_marker: Label
var _dock_status: Label
var _carry_label: Label
var _crew_panel: PanelContainer
var _crew_detail: Label


func _ready() -> void:
	layer = 5
	_root = Control.new()
	_root.theme = UiTheme.get_theme()
	UiTheme.full_rect(_root)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_hurt = ColorRect.new()
	UiTheme.full_rect(_hurt)
	_hurt.color = Color(0.8, 0.0, 0.0, 0.0)
	_hurt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_hurt)
	_build_ship_panel()
	_build_top()
	_build_bottom()
	_build_station_panel()
	_build_overlays()


# --- Construction ------------------------------------------------------------------------------

func _panel(pos: Vector2, min_size: Vector2) -> VBoxContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiTheme.panel_style(0.72))
	p.position = pos
	p.custom_minimum_size = min_size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	p.add_child(v)
	return v


func _build_ship_panel() -> void:
	var v := _panel(Vector2(16, 16), Vector2(330, 0))
	v.add_child(UiTheme.label(ShipBuilder.NAME, 20, UiTheme.ACCENT))
	for row: Array in [["hull", "HULL", Color(1.0, 0.45, 0.3)], ["shield", "SHIELD", Color(0.35, 0.85, 1.0)],
			["fuel", "FUEL", Color(1.0, 0.65, 0.2)], ["engine", "ENGINE", Color(0.5, 1.0, 0.55)],
			["weapons", "WEAPONS", Color(0.5, 1.0, 0.55)], ["blast", "BLAST", Color(0.95, 0.35, 0.3)]]:
		var h := HBoxContainer.new()
		var name_l := UiTheme.label(row[1], 14, UiTheme.MUTED)
		name_l.custom_minimum_size.x = 76
		h.add_child(name_l)
		var b := UiTheme.bar(row[2], 14.0)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(b)
		var t := UiTheme.label("", 14)
		t.custom_minimum_size.x = 86
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		h.add_child(t)
		v.add_child(h)
		_bars[row[0]] = b
		_texts[row[0]] = t
	_dock_status = UiTheme.label("", 15, UiTheme.GOOD)
	_dock_status.visible = false
	v.add_child(_dock_status)


func _build_top() -> void:
	var top := VBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_CENTER_TOP)
	top.offset_left = -300
	top.offset_right = 300
	top.offset_top = 12
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.alignment = BoxContainer.ALIGNMENT_BEGIN
	_root.add_child(top)
	_depth = UiTheme.label("", 30, Color.WHITE)
	_depth.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(_depth)
	var haul_row := HBoxContainer.new()
	haul_row.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_child(haul_row)
	_haul = UiTheme.label("", 20, UiTheme.GOLD)
	haul_row.add_child(_haul)
	_popup = UiTheme.label("", 20, UiTheme.GOOD)
	haul_row.add_child(_popup)
	_toasts = VBoxContainer.new()
	_toasts.add_theme_constant_override("separation", 2)
	top.add_child(_toasts)

	_crew = UiTheme.label("", 15)
	_crew.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_crew.offset_left = -300
	_crew.offset_right = -16
	_crew.offset_top = 16
	_crew.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_root.add_child(_crew)


func _build_bottom() -> void:
	_prompt = UiTheme.label("", 20, Color.WHITE)
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.offset_left = -400
	_prompt.offset_right = 400
	_prompt.offset_top = -190
	_prompt.offset_bottom = -160
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.add_theme_color_override("font_outline_color", Color.BLACK)
	_prompt.add_theme_constant_override("outline_size", 6)
	_root.add_child(_prompt)

	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	v.offset_left = 16
	v.offset_top = -86
	v.offset_right = 316
	v.offset_bottom = -16
	v.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_root.add_child(v)
	_carry_label = UiTheme.label("", 17, UiTheme.GOLD)
	_carry_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_carry_label.add_theme_constant_override("outline_size", 5)
	_carry_label.visible = false
	v.add_child(_carry_label)
	_tool_label = UiTheme.label("", 18, UiTheme.ACCENT)
	v.add_child(_tool_label)
	var h := HBoxContainer.new()
	h.add_child(UiTheme.label("HEALTH", 14, UiTheme.MUTED))
	_hp_bar = UiTheme.bar(Color(0.4, 1.0, 0.5), 16.0)
	_hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(_hp_bar)
	_hp_text = UiTheme.label("", 14)
	h.add_child(_hp_text)
	v.add_child(h)

	_crosshair = Control.new()
	_crosshair.set_anchors_preset(Control.PRESET_CENTER)
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crosshair.draw.connect(_draw_crosshair)
	_root.add_child(_crosshair)


func _build_station_panel() -> void:
	_station_panel = PanelContainer.new()
	_station_panel.add_theme_stylebox_override("panel", UiTheme.panel_style(0.72))
	_station_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_station_panel.offset_left = -380
	_station_panel.offset_right = -16
	_station_panel.offset_top = -110
	_station_panel.offset_bottom = -16
	_station_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_station_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_station_panel)
	var v := VBoxContainer.new()
	_station_panel.add_child(v)
	_station_title = UiTheme.label("", 20, UiTheme.ACCENT)
	v.add_child(_station_title)
	_station_info = UiTheme.label("", 16)
	v.add_child(_station_info)
	_station_help = UiTheme.label("", 14, UiTheme.MUTED)
	v.add_child(_station_help)


func _build_overlays() -> void:
	_dock_marker = UiTheme.label("", 18, UiTheme.GOOD)
	_dock_marker.add_theme_color_override("font_outline_color", Color.BLACK)
	_dock_marker.add_theme_constant_override("outline_size", 6)
	_dock_marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dock_marker.custom_minimum_size = Vector2(160, 0)
	_root.add_child(_dock_marker)
	_station_marker = UiTheme.label("", 17, Color(1.0, 0.72, 0.3))
	_station_marker.add_theme_color_override("font_outline_color", Color.BLACK)
	_station_marker.add_theme_constant_override("outline_size", 6)
	_station_marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_station_marker.custom_minimum_size = Vector2(260, 0)
	_station_marker.visible = false
	_root.add_child(_station_marker)

	var bv := VBoxContainer.new()
	bv.set_anchors_preset(Control.PRESET_CENTER)
	bv.offset_left = -500
	bv.offset_right = 500
	bv.offset_top = -120
	bv.offset_bottom = 0
	bv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bv)
	_banner = UiTheme.label("", 52, UiTheme.DANGER)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_color_override("font_outline_color", Color.BLACK)
	_banner.add_theme_constant_override("outline_size", 10)
	bv.add_child(_banner)
	_banner_sub = UiTheme.label("", 22, Color.WHITE)
	_banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_sub.add_theme_color_override("font_outline_color", Color.BLACK)
	_banner_sub.add_theme_constant_override("outline_size", 6)
	bv.add_child(_banner_sub)

	_crew_panel = PanelContainer.new()
	_crew_panel.set_anchors_preset(Control.PRESET_CENTER)
	_crew_panel.offset_left = -260
	_crew_panel.offset_right = 260
	_crew_panel.offset_top = -180
	_crew_panel.offset_bottom = 180
	_crew_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crew_panel.visible = false
	_root.add_child(_crew_panel)
	_crew_detail = UiTheme.label("", 18)
	_crew_panel.add_child(_crew_detail)

	_loading = ColorRect.new()
	(_loading as ColorRect).color = Color(0.01, 0.015, 0.03, 1.0)
	UiTheme.full_rect(_loading)
	_root.add_child(_loading)
	_loading_label = UiTheme.label("DESCENDING INTO THE ASTEROID...\nGenerating cave", 28, UiTheme.ACCENT)
	_loading_label.set_anchors_preset(Control.PRESET_CENTER)
	_loading_label.offset_left = -400
	_loading_label.offset_right = 400
	_loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading.add_child(_loading_label)


# --- Public API --------------------------------------------------------------------------------

func toast(text: String, level := 0) -> void:
	var color: Color = [UiTheme.TEXT, UiTheme.WARN, UiTheme.DANGER][clampi(level, 0, 2)]
	var l := UiTheme.label(text, 19 if level < 2 else 22, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	_toasts.add_child(l)
	while _toasts.get_child_count() > 5:
		var old := _toasts.get_child(0)
		_toasts.remove_child(old)
		old.queue_free()
	var tw := l.create_tween()
	tw.tween_interval(4.0 if level < 2 else 6.0)
	tw.tween_property(l, "modulate:a", 0.0, 0.8)
	tw.tween_callback(l.queue_free)


func credit_popup(value: int) -> void:
	_popup_value += value
	_popup_t = 1.6


func hit_marker() -> void:
	_hit_t = 0.15


func show_banner(text: String, sub: String, color := UiTheme.DANGER) -> void:
	_banner.text = text
	_banner_sub.text = sub
	_banner.add_theme_color_override("font_color", color)


# --- Update ------------------------------------------------------------------------------------

func _process(delta: float) -> void:
	var mission := Game.mission as MissionLevel
	if mission == null:
		return
	var ship := mission.ship
	var player := mission.local_player
	_loading.visible = not mission.local_ready
	if mission.local_ready and _loading.visible == false and _loading_label.text != "":
		_loading_label.text = ""
	if ship == null:
		return
	_update_ship(ship, mission)
	_update_crew(ship)
	_update_player(player, ship, delta)
	_update_station(player, ship, mission)
	_update_dock_marker(player, ship, mission)
	_update_waystation(player, ship)
	_popup_t -= delta
	if _popup_t <= 0.0:
		_popup_value = 0
		_popup.text = ""
	else:
		_popup.text = "  +%d" % _popup_value
	_hit_t = maxf(0.0, _hit_t - delta)
	_crosshair.queue_redraw()
	var show_crew := Input.is_action_pressed("crew_list") and not Game.ui_blocking
	_crew_panel.visible = show_crew
	if show_crew:
		_crew_detail.text = _crew_report(ship, mission)


func _update_ship(ship: Mothership, mission: MissionLevel) -> void:
	_set_bar("hull", ship.hull / ship.max_hull, "%d / %d" % [int(ship.hull), int(ship.max_hull)])
	if ship.shield_down:
		_set_bar("shield", 0.0, "DOWN %ds" % int(ceil(ship.shield_reboot)) if ship.fuel > 0.0 else "NO FUEL")
		(_texts["shield"] as Label).add_theme_color_override("font_color", UiTheme.DANGER)
	else:
		_set_bar("shield", ship.shield / ship.max_shield, "%d%%" % int(100.0 * ship.shield / ship.max_shield))
		(_texts["shield"] as Label).add_theme_color_override("font_color", UiTheme.TEXT)
	_set_bar("fuel", ship.fuel / ship.max_fuel, "%d%%" % int(100.0 * ship.fuel / ship.max_fuel))
	(_texts["fuel"] as Label).add_theme_color_override("font_color", UiTheme.DANGER if ship.fuel < ship.max_fuel * 0.2 else UiTheme.TEXT)
	if ship.blast_cd <= 0.0:
		_set_bar("blast", 1.0, "READY")
		(_texts["blast"] as Label).add_theme_color_override("font_color", UiTheme.GOOD)
	else:
		_set_bar("blast", 1.0 - ship.blast_cd / Mothership.BLAST_COOLDOWN, "%d s" % int(ceil(ship.blast_cd)))
		(_texts["blast"] as Label).add_theme_color_override("font_color", UiTheme.MUTED)
	for sys: String in ["engine", "weapons"]:
		var hpv := ship.system_hp(sys)
		var online := ship.system_online(sys)
		_set_bar(sys, hpv / 100.0, ("%d%%" % int(hpv)) if online else "OFFLINE")
		var col := UiTheme.TEXT if online else UiTheme.DANGER
		if online and hpv < 50.0:
			col = UiTheme.WARN
		(_texts[sys] as Label).add_theme_color_override("font_color", col)
	match ship.landing:
		Mothership.Dock.APPROACH:
			_dock_status.text = "DOCKING - approach on autopilot"
		Mothership.Dock.LANDED:
			_dock_status.text = "DOCKED - safe, refuelling, recharging shield"
		Mothership.Dock.LIFTOFF:
			_dock_status.text = "LIFTING OFF"
	_dock_status.visible = ship.landing != Mothership.Dock.FLYING
	var record := "" if mission.best_depth <= 0 else "   (record %d m)" % mission.best_depth
	_depth.text = "DEPTH %d m%s" % [int(ship.depth), record]
	_haul.text = "Haul: %d CR" % ship.credits


func _set_bar(id: String, value: float, text: String) -> void:
	(_bars[id] as ProgressBar).value = clampf(value, 0.0, 1.0)
	(_texts[id] as Label).text = text


func _update_crew(ship: Mothership) -> void:
	var lines := PackedStringArray()
	for c in ship.crew_root.get_children():
		var p := c as CrewMember
		if p == null:
			continue
		var where := "walking"
		if not p.alive:
			where = "knocked out"
		elif p.station != "":
			where = ShipBuilder.STATION_NAMES[p.station]
		elif not Mothership.is_aboard(p.position):
			where = "at the waystation"
		lines.append("%s%s - %s" % [p.display_name, " [bot]" if p.bot else "", where])
	var critters := 0
	var infiltrators := 0
	for a in get_tree().get_nodes_in_group("aliens"):
		var alien := a as Alien
		if alien and alien.attached >= 0:
			if alien.kind == Alien.Kind.CRITTER:
				critters += 1
			else:
				infiltrators += 1
	var danger := ship.boarders > 0 or critters > 0 or infiltrators > 0
	if critters > 0:
		lines.append("CRITTERS ON HULL: %d (scout!)" % critters)
	if infiltrators > 0:
		lines.append("INFILTRATORS ON ROOF: %d" % infiltrators)
	if ship.boarders > 0:
		lines.append("INTRUDERS ABOARD: %d" % ship.boarders)
	_crew.text = "\n".join(lines)
	_crew.add_theme_color_override("font_color", UiTheme.DANGER if danger else UiTheme.TEXT)


func _update_player(player: CrewMember, ship: Mothership, _delta: float) -> void:
	if player == null:
		_prompt.text = ""
		return
	_hp_bar.value = player.hp / player.max_hp
	_hp_text.text = " %d" % int(player.hp)
	_tool_label.text = "BLASTER  [1]" if player.tool == 0 else "TOOLKIT  [2]"
	_tool_label.visible = player.station == "" and player.carrying == null
	_carry_label.visible = player.carrying != null and player.alive
	if player.carrying:
		var item := player.carrying.item
		_carry_label.text = "CARRYING %s\n%s - %s\n[G] drop" % [RunItems.display_name(item).to_upper(),
			RunItems.describe(item), RunItems.install_hint(item)]
	var low := player.hp < player.max_hp * 0.35
	var vignette := player.hurt_flash * 0.35 + (0.12 + 0.08 * sin(Time.get_ticks_msec() * 0.006) if low and player.alive else 0.0)
	_hurt.color.a = vignette
	if not player.alive and ship.alive:
		show_banner("KNOCKED OUT", "Recovering in %d s..." % int(ceil(player.respawn_left)), UiTheme.WARN)
		_prompt.text = ""
	elif ship.alive and _banner.text == "KNOCKED OUT":
		show_banner("", "")
	if player.alive:
		_prompt.text = player.prompt if player.station == "" else ""
	_crosshair.visible = player.alive and (player.station == "" or player.station in ["gun_l", "gun_r", "mining", "scout"])


func _update_station(player: CrewMember, ship: Mothership, mission: MissionLevel) -> void:
	if player == null or player.station == "" or not player.alive:
		_station_panel.visible = false
		return
	_station_panel.visible = true
	_station_title.text = ShipBuilder.STATION_NAMES[player.station].to_upper()
	match player.station:
		"pilot":
			var speed := ship.velocity.length()
			var state := "ENGINE OFFLINE" if not ship.engine_online else ("LOW POWER (no fuel)" if ship.fuel <= 0.0 else "")
			_station_info.text = "Throttle %d%%   Speed %.1f m/s\nAutopilot: %s   %s" % [int(ship.throttle * 100.0), speed,
				"ON" if ship.autopilot else "OFF", state]
			match ship.landing:
				Mothership.Dock.FLYING:
					var st := ship.nearest_station(Mothership.LAND_RANGE)
					if not st.is_empty():
						_station_info.text += "\n%s in range - press L to land" % st["name"]
				Mothership.Dock.APPROACH:
					_station_info.text = "Docking approach on autopilot..."
				Mothership.Dock.LANDED:
					var out := ship.crew_outside()
					_station_info.text = "Docked - L to lift off%s" % ("" if out == "" else "\n(waiting for %s to board)" % out)
				Mothership.Dock.LIFTOFF:
					_station_info.text = "Lifting off..."
			_station_help.text = "W/S throttle   A/D turn   Space/Ctrl up/down\nT autopilot   X full stop   B emergency blast\nL land at / lift off from a waystation\nMouse: look around   E: leave"
		"gun_l", "gun_r":
			var w := str(ship.stats["weapon_left" if player.station == "gun_l" else "weapon_right"])
			_station_info.text = "%s%s" % [Game.WEAPONS[w]["name"], "" if ship.weapons_online else "\nWEAPONS OFFLINE - needs repair"]
			_station_help.text = "Mouse: aim   LMB: fire   RMB: zoom   E: leave"
		"mining":
			var reach := "Beam active" if ship.mining_on else "Hold LMB to fire the mining laser"
			_station_info.text = "%s%s" % [reach, "" if ship.weapons_online else "\nWEAPONS OFFLINE - needs repair"]
			_station_help.text = "Aim at crystal deposits on the walls.\nChunks fly into the tractor field.   E: leave"
		"scout":
			var scout := mission.scout
			if scout:
				_station_info.text = "Hull %d/%d   Fuel cargo %d/%d" % [int(scout.hp), int(scout.max_hp), int(scout.cargo), int(scout.max_cargo)]
			_station_help.text = "WASD move   Space/Ctrl up/down   Shift boost\nMouse: steer   LMB: fire   E: dock (near the ship)\nHold E: recall the scout (cargo is lost)"


func _update_dock_marker(player: CrewMember, ship: Mothership, mission: MissionLevel) -> void:
	_dock_marker.visible = false
	if player == null or player.station != "scout" or mission.scout == null:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var dock := ship.to_global(ShipBuilder.DOCK_POINT)
	var dist := mission.scout.global_position.distance_to(dock)
	var size := get_viewport().get_visible_rect().size
	var screen: Vector2
	if cam.is_position_behind(dock):
		var v := cam.global_transform.basis.inverse() * (dock - cam.global_position)
		screen = size * 0.5 + Vector2(-v.x, v.y).normalized() * size.length()
	else:
		screen = cam.unproject_position(dock)
	screen = screen.clamp(Vector2(90, 60), size - Vector2(90, 80))
	_dock_marker.visible = true
	_dock_marker.text = "▼ DOCK %d m%s" % [int(dist), "  [E]" if dist <= Scout.DOCK_RANGE else ""]
	_dock_marker.position = screen - Vector2(80, 10)


## Marker on the nearest waystation's hangar while flying.
func _update_waystation(player: CrewMember, ship: Mothership) -> void:
	_station_marker.visible = false
	if player == null or ship.landing != Mothership.Dock.FLYING or player.station == "scout":
		return
	var st := ship.nearest_station(STATION_MARKER_RANGE)
	var cam := get_viewport().get_camera_3d()
	if st.is_empty() or cam == null:
		return
	var target := Mothership.station_entrance(st)
	var dist := ship.global_position.distance_to(target)
	if dist < 20.0:
		return
	var size := get_viewport().get_visible_rect().size
	var screen: Vector2
	if cam.is_position_behind(target):
		var v := cam.global_transform.basis.inverse() * (target - cam.global_position)
		screen = size * 0.5 + Vector2(-v.x, v.y).normalized() * size.length()
	else:
		screen = cam.unproject_position(target)
	screen = screen.clamp(Vector2(140, 70), size - Vector2(140, 90))
	_station_marker.visible = true
	var hint := ""
	if dist <= Mothership.LAND_RANGE:
		hint = "\n[L] LAND" if player.station == "pilot" else "\npilot: L to land"
	_station_marker.text = "◆ %s  %d m - safe haven%s" % [st["name"], int(dist), hint]
	_station_marker.position = screen - Vector2(130, 10)


func _crew_report(ship: Mothership, mission: MissionLevel) -> String:
	var lines := PackedStringArray(["CREW STATUS", ""])
	for c in ship.crew_root.get_children():
		var p := c as CrewMember
		if p == null:
			continue
		var where: String = "Walking" if p.station == "" else ShipBuilder.STATION_NAMES[p.station]
		lines.append("%s   %s   HP %d%s" % [p.display_name, where, int(p.hp), "" if p.alive else "  (knocked out)"])
	lines.append("")
	var ore_lines := PackedStringArray()
	for k in ship.ore:
		ore_lines.append("%s x%d" % [Deposit.TYPES[k]["name"], int(ship.ore[k])])
	lines.append("Ore: " + (", ".join(ore_lines) if ore_lines.size() > 0 else "none yet"))
	lines.append("Aliens killed: %d   Nests destroyed: %d" % [mission.kills, mission.nests_destroyed])
	if not ship.run_mods.is_empty():
		var mods := PackedStringArray()
		for item: String in ship.run_mods:
			var n := int(ship.run_mods[item])
			mods.append(RunItems.display_name(item) + (" x%d" % n if n > 1 else ""))
		lines.append("Waystation supplies (this dive): " + ", ".join(mods))
	if mission.scout:
		lines.append("Scout: " + mission.scout.status_text())
	return "\n".join(lines)


func _draw_crosshair() -> void:
	var c := Vector2.ZERO
	var col := Color(1, 1, 1, 0.85)
	for d: Vector2 in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		_crosshair.draw_line(c + d * 5.0, c + d * 12.0, col, 2.0)
	_crosshair.draw_circle(c, 1.5, col)
	if _hit_t > 0.0:
		var hc := Color(1.0, 0.4, 0.3, _hit_t / 0.15)
		for d: Vector2 in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			_crosshair.draw_line(c + d * 7.0, c + d * 14.0, hc, 2.5)
