class_name Hud
extends CanvasLayer
## In-mission HUD: ship systems (percentage inside each bar, absolute value beside it), depth,
## credits and research points, crew roster, interaction prompts, station read-outs, alerts, the
## scouts' dock markers, waystation and abandoned station markers, carried crates and
## end-of-mission banners. In a gun pod there is no crosshair or station read-out: the pod has its
## own sight and displays.

## Waystations closer than this get a marker on screen.
const STATION_MARKER_RANGE := 320.0
## Colours of the hostility meter's four stages (docile .. high).
const HOSTILITY_COLORS: Array[Color] = [Color(0.4, 0.9, 0.5), Color(0.95, 0.85, 0.3), Color(1.0, 0.55, 0.2), Color(1.0, 0.25, 0.2)]

var _root: Control
var _bars: Dictionary = {}
var _texts: Dictionary = {}
var _depth: Label
var _ship_title: Label
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
var _derelict_marker: Label
var _dock_status: Label
var _carry_label: Label
var _crew_panel: PanelContainer
var _crew_detail: Label
var _hostility: Control
var _hostility_label: Label
var _hostility_value := 0.0
var _hostility_hold := false


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
	var v := _panel(Vector2(16, 16), Vector2(380, 0))
	_ship_title = UiTheme.label("", 20, UiTheme.ACCENT)
	v.add_child(_ship_title)
	for row: Array in [["hull", "HULL", Color(1.0, 0.45, 0.3)], ["shield", "SHIELD", Color(0.35, 0.85, 1.0)],
			["fuel", "FUEL", Color(1.0, 0.65, 0.2)], ["engine", "ENGINE", Color(0.5, 1.0, 0.55)],
			["weapons", "WEAPONS", Color(0.5, 1.0, 0.55)], ["blast", "BLAST", Color(0.95, 0.35, 0.3)]]:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		var name_l := UiTheme.label(row[1], 14, UiTheme.MUTED)
		name_l.custom_minimum_size.x = 70
		h.add_child(name_l)
		var b := UiTheme.stat_bar(row[2], 18.0)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(b)
		var t := UiTheme.label("", 14)
		t.custom_minimum_size.x = 92
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
	# The hostility meter: four segments, docile to high.
	var host_row := HBoxContainer.new()
	host_row.alignment = BoxContainer.ALIGNMENT_CENTER
	host_row.add_theme_constant_override("separation", 10)
	top.add_child(host_row)
	var host_title := UiTheme.label("HOSTILITY", 14, UiTheme.MUTED)
	host_title.custom_minimum_size.x = 150
	host_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	host_row.add_child(host_title)
	_hostility = Control.new()
	_hostility.custom_minimum_size = Vector2(240, 14)
	_hostility.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_hostility.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hostility.draw.connect(_draw_hostility)
	host_row.add_child(_hostility)
	_hostility_label = UiTheme.label("", 14)
	_hostility_label.custom_minimum_size.x = 150
	host_row.add_child(_hostility_label)
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
	h.add_theme_constant_override("separation", 8)
	h.add_child(UiTheme.label("HEALTH", 14, UiTheme.MUTED))
	_hp_bar = UiTheme.stat_bar(Color(0.4, 1.0, 0.5), 18.0)
	_hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(_hp_bar)
	_hp_text = UiTheme.label("", 14)
	_hp_text.custom_minimum_size.x = 76
	_hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
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
	_derelict_marker = UiTheme.label("", 16, Color(0.75, 0.85, 0.7))
	_derelict_marker.add_theme_color_override("font_outline_color", Color.BLACK)
	_derelict_marker.add_theme_constant_override("outline_size", 6)
	_derelict_marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_derelict_marker.custom_minimum_size = Vector2(280, 0)
	_derelict_marker.visible = false
	_root.add_child(_derelict_marker)

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
	_update_derelict(player, ship)
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
	_ship_title.text = str(ship.layout.get("name", "MOTHERSHIP")).to_upper()
	_set_bar("hull", ship.hull / ship.max_hull, _pct(ship.hull, ship.max_hull), "%d / %d" % [int(ship.hull), int(ship.max_hull)])
	if ship.shield_down:
		_set_bar("shield", 0.0, "DOWN", "reboot %d s" % int(ceil(ship.shield_reboot)) if ship.fuel > 0.0 else "NO FUEL")
		(_texts["shield"] as Label).add_theme_color_override("font_color", UiTheme.DANGER)
	else:
		_set_bar("shield", ship.shield / ship.max_shield, _pct(ship.shield, ship.max_shield), "%d / %d" % [int(ship.shield), int(ship.max_shield)])
		(_texts["shield"] as Label).add_theme_color_override("font_color", UiTheme.TEXT)
	_set_bar("fuel", ship.fuel / ship.max_fuel, _pct(ship.fuel, ship.max_fuel), "%d / %d" % [int(ship.fuel), int(ship.max_fuel)])
	(_texts["fuel"] as Label).add_theme_color_override("font_color", UiTheme.DANGER if ship.fuel < ship.max_fuel * 0.2 else UiTheme.TEXT)
	if ship.blast_cd <= 0.0:
		_set_bar("blast", 1.0, "READY", "READY")
		(_texts["blast"] as Label).add_theme_color_override("font_color", UiTheme.GOOD)
	else:
		var charged := 1.0 - ship.blast_cd / Mothership.BLAST_COOLDOWN
		_set_bar("blast", charged, "%d%%" % int(charged * 100.0), "%d s" % int(ceil(ship.blast_cd)))
		(_texts["blast"] as Label).add_theme_color_override("font_color", UiTheme.MUTED)
	for sys: String in ["engine", "weapons"]:
		var hpv := ship.system_hp(sys)
		var online := ship.system_online(sys)
		_set_bar(sys, hpv / 100.0, _pct(hpv, 100.0) if online else "OFFLINE", "%d / 100" % int(hpv))
		var col := UiTheme.TEXT if online else UiTheme.DANGER
		if online and hpv < 50.0:
			col = UiTheme.WARN
		(_texts[sys] as Label).add_theme_color_override("font_color", col)
	match ship.landing:
		Mothership.Dock.APPROACH:
			_dock_status.text = "DOCKING - approach on autopilot"
		Mothership.Dock.LANDED:
			if ship.derelict_k >= 0:
				_dock_status.text = "LANDED - abandoned station, no defences"
				_dock_status.add_theme_color_override("font_color", UiTheme.WARN)
			else:
				_dock_status.text = "DOCKED - safe, refuelling, recharging shield"
				_dock_status.add_theme_color_override("font_color", UiTheme.GOOD)
		Mothership.Dock.LIFTOFF:
			_dock_status.text = "LIFTING OFF"
	_dock_status.visible = ship.landing != Mothership.Dock.FLYING
	_hostility_value = ship.hostility
	var stage := ship.hostility_stage()
	_hostility_label.text = Mothership.HOSTILITY_STAGES[stage]
	_hostility_hold = ship.landing != Mothership.Dock.FLYING
	if ship.landing == Mothership.Dock.LANDED and ship.derelict_k < 0:
		_hostility_label.text = "SAFE HAVEN"
	elif _hostility_hold and ship.derelict_k >= 0:
		_hostility_label.text += " (holding)"
	_hostility_label.add_theme_color_override("font_color", HOSTILITY_COLORS[stage])
	_hostility.queue_redraw()
	var record := "" if mission.best_depth <= 0 else "   (record %d m)" % mission.best_depth
	_depth.text = "DEPTH %d m%s" % [int(ship.depth), record]
	_haul.text = "Credits: %d CR    Research: +%d RP" % [ship.credits, int(mission.dive_rp()["total"])]


## Set a bar's fill, the read-out centred in it and the value beside it.
func _set_bar(id: String, value: float, inside: String, beside: String) -> void:
	var b := _bars[id] as ProgressBar
	b.value = clampf(value, 0.0, 1.0)
	(b.get_node("Pct") as Label).text = inside
	(_texts[id] as Label).text = beside


static func _pct(value: float, max_value: float) -> String:
	return "%d%%" % int(round(100.0 * clampf(value / maxf(max_value, 0.001), 0.0, 1.0)))


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
			where = ship.station_name(p.station)
		elif not ship.is_aboard(p.position):
			where = "in the abandoned station" if ship.derelict_k >= 0 else "at the waystation"
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
	if ship.hostiles > 0 and ship.derelict_k >= 0:
		lines.append("HOSTILES IN THE STATION: %d" % ship.hostiles)
	_crew.text = "\n".join(lines)
	_crew.add_theme_color_override("font_color", UiTheme.DANGER if danger else UiTheme.TEXT)


func _update_player(player: CrewMember, ship: Mothership, _delta: float) -> void:
	if player == null:
		_prompt.text = ""
		return
	_hp_bar.value = player.hp / player.max_hp
	(_hp_bar.get_node("Pct") as Label).text = _pct(player.hp, player.max_hp)
	_hp_text.text = "%d / %d" % [int(maxf(player.hp, 0.0)), int(player.max_hp)]
	_update_tool_label(player)
	_tool_label.visible = player.station == "" and player.carrying == null
	_carry_label.visible = player.carrying != null and player.alive
	if player.carrying:
		var item := player.carrying.item
		_carry_label.text = "CARRYING %s\n%s - %s\n[G] drop" % [RunItems.display_name(item).to_upper(),
			RunItems.describe(item), RunItems.install_hint(item, ship.install_hub_room())]
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
	# A gun pod has its own reflector sight in front of the gunner.
	_crosshair.visible = player.alive and (player.station == "" or ship.station_kind(player.station) == "laser" or ship.is_scout_station(player.station))


## The tool in hand: the hand weapon with its magazine (or the reload under way, or a reminder to
## reload once it is empty), or the toolkit.
func _update_tool_label(player: CrewMember) -> void:
	var col := UiTheme.ACCENT
	if player.tool != 0:
		_tool_label.text = "TOOLKIT  [2]"
	else:
		var w := CrewWeapons.display_name(player.weapon).to_upper()
		var full := CrewWeapons.mag(player.weapon)
		if player.reloading:
			_tool_label.text = "%s  RELOADING %d%%  [1]" % [w, int(player.reload_progress() * 100.0)]
			col = UiTheme.WARN
		elif player.ammo <= 0:
			_tool_label.text = "%s  EMPTY - [R] RELOAD  [1]" % w
			col = UiTheme.DANGER
		else:
			_tool_label.text = "%s  %d / %d  [1]" % [w, player.ammo, full]
			if player.ammo <= maxi(1, int(full * 0.25)):
				col = UiTheme.WARN
	_tool_label.add_theme_color_override("font_color", col)


func _update_station(player: CrewMember, ship: Mothership, mission: MissionLevel) -> void:
	# Gun pods show everything on their own control panel.
	if player == null or player.station == "" or not player.alive or ship.station_kind(player.station) == "gun":
		_station_panel.visible = false
		return
	_station_panel.visible = true
	_station_title.text = ship.station_name(player.station).to_upper()
	match ship.station_kind(player.station):
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
						if ship.in_hall(st):
							_station_info.text += "\nExit bulkhead sealed until you land"
					elif not ship.nearest_derelict(Mothership.DERELICT_LAND_RANGE).is_empty():
						var near := ship.aliens_near(Mothership.DERELICT_CLEAR_RANGE)
						if near > 0:
							_station_info.text += "\nAbandoned station: %d alien%s too close to land" % [near, "s" if near > 1 else ""]
						else:
							_station_info.text += "\nAbandoned station in range - L to land (optional)"
				Mothership.Dock.APPROACH:
					_station_info.text = "Docking approach on autopilot..."
				Mothership.Dock.LANDED:
					var out := ship.crew_outside()
					_station_info.text = "%s - L to lift off%s" % ["Landed" if ship.derelict_k >= 0 else "Docked",
						"" if out == "" else "\n(waiting for %s to board)" % out]
				Mothership.Dock.LIFTOFF:
					_station_info.text = "Lifting off..."
			_station_help.text = "W/S throttle   A/D turn   Space/Ctrl up/down\nT autopilot   X full stop   B emergency blast\nL land at / lift off from a station\nMouse: look around   E: leave"
		"laser":
			var reach := "Beam active" if ship.laser_on(player.station) else "Hold LMB to fire the mining laser"
			_station_info.text = "%s%s" % [reach, "" if ship.weapons_online else "\nWEAPONS OFFLINE - needs repair"]
			_station_help.text = "Aim at crystal deposits on the walls.\nChunks fly back to the laser's tip.   E: leave"
		"scout":
			var scout := mission.scout_at(player.station)
			if scout:
				_station_info.text = "Hull %d/%d   Fuel cargo %d/%d" % [int(scout.hp), int(scout.max_hp), int(scout.cargo), int(scout.max_cargo)]
			_station_help.text = "WASD move   Space/Ctrl up/down   Shift boost\nMouse: steer   LMB: fire   E: dock (near the ship)\nHold E: recall the scout (cargo is lost)"


func _update_dock_marker(player: CrewMember, ship: Mothership, mission: MissionLevel) -> void:
	_dock_marker.visible = false
	if player == null or not ship.is_scout_station(player.station):
		return
	var scout := mission.scout_at(player.station)
	var cam := get_viewport().get_camera_3d()
	if cam == null or scout == null:
		return
	var dock := ship.to_global(scout.dock_point())
	var dist := scout.global_position.distance_to(dock)
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


## Marker on the next waystation's entrance gate while flying.
func _update_waystation(player: CrewMember, ship: Mothership) -> void:
	_station_marker.visible = false
	if player == null or ship.landing != Mothership.Dock.FLYING or ship.is_scout_station(player.station):
		return
	var st := ship.nearest_station(STATION_MARKER_RANGE)
	var cam := get_viewport().get_camera_3d()
	if st.is_empty() or cam == null:
		return
	var target := Mothership.station_entrance(st)
	var dist := ship.station_distance(st)
	if dist < 20.0 and not ship.in_hall(st):
		return
	if ship.in_hall(st):
		target = (st["xform"] as Transform3D) * Vector3(0, StationBuilder.LAND_HEIGHT, 0)
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
	if ship.in_hall(st):
		_station_marker.text = "◆ %s  LANDING PAD%s" % [st["name"], hint]
	else:
		_station_marker.text = "◆ %s  %d m - shop and safe haven%s" % [st["name"], int(dist), hint]
	_station_marker.position = screen - Vector2(130, 10)


## Marker on the abandoned station in this stretch of tunnel while flying (landing is optional).
func _update_derelict(player: CrewMember, ship: Mothership) -> void:
	_derelict_marker.visible = false
	if player == null or ship.landing != Mothership.Dock.FLYING or ship.is_scout_station(player.station):
		return
	var d := ship.nearest_derelict(STATION_MARKER_RANGE)
	var cam := get_viewport().get_camera_3d()
	if d.is_empty() or cam == null:
		return
	var target := Mothership.derelict_entrance(d)
	var dist := ship.derelict_distance(d)
	if dist < 15.0:
		return
	var size := get_viewport().get_visible_rect().size
	var screen: Vector2
	if cam.is_position_behind(target):
		var v := cam.global_transform.basis.inverse() * (target - cam.global_position)
		screen = size * 0.5 + Vector2(-v.x, v.y).normalized() * size.length()
	else:
		screen = cam.unproject_position(target)
	screen = screen.clamp(Vector2(150, 70), size - Vector2(150, 110))
	var hint := ""
	if dist <= Mothership.DERELICT_LAND_RANGE:
		if ship.aliens_near(Mothership.DERELICT_CLEAR_RANGE) > 0:
			hint = "\nALIENS TOO CLOSE TO LAND"
		else:
			hint = "\n[L] LAND" if player.station == "pilot" else "\npilot: L to land"
	_derelict_marker.visible = true
	_derelict_marker.text = "◇ ABANDONED STATION  %d m\noptional - salvage, hostiles%s" % [int(dist), hint]
	_derelict_marker.position = screen - Vector2(140, 10)


func _crew_report(ship: Mothership, mission: MissionLevel) -> String:
	var lines := PackedStringArray(["CREW STATUS", ""])
	for c in ship.crew_root.get_children():
		var p := c as CrewMember
		if p == null:
			continue
		var where: String = "Walking" if p.station == "" else ship.station_name(p.station)
		lines.append("%s   %s   %s   HP %d%s" % [p.display_name, where, CrewWeapons.display_name(p.weapon), int(p.hp),
			"" if p.alive else "  (knocked out)"])
	lines.append("")
	var ore_lines := PackedStringArray()
	for k in ship.ore:
		ore_lines.append("%s x%d" % [Deposit.TYPES[k]["name"], int(ship.ore[k])])
	lines.append("Ore: " + (", ".join(ore_lines) if ore_lines.size() > 0 else "none yet"))
	lines.append("Aliens killed: %d   Nests destroyed: %d   Waystations: %d   Abandoned stations: %d" % [mission.kills,
		mission.nests_destroyed, ship.stations_docked, ship.derelicts_docked])
	var rp := mission.dive_rp()
	lines.append("Research so far: %d RP (depth %d, waystations %d, nests %d)" % [rp["total"], rp["depth"], rp["stations"], rp["nests"]])
	var guns := PackedStringArray()
	for g: String in ship.gun_stations():
		guns.append("%s: %s, heat %d%%" % [ship.station_name(g), "new belt loading" if ship.gun_reloading(g) else "%d rounds" % ship.gun_ammo_of(g),
			int(ship.gun_heat_of(g) * 100.0)])
	lines.append(", ".join(guns))
	if not ship.run_mods.is_empty():
		var mods := PackedStringArray()
		for item: String in ship.run_mods:
			var n := int(ship.run_mods[item])
			mods.append(RunItems.display_name(item) + (" x%d" % n if n > 1 else ""))
		lines.append("Installed this dive: " + ", ".join(mods))
	for sc in mission.scouts:
		lines.append("%s: %s" % [ship.station_name(sc.station_id), sc.status_text()])
	return "\n".join(lines)


func _draw_hostility() -> void:
	var size := _hostility.size
	var gap := 3.0
	var seg_w := (size.x - gap * 3.0) / 4.0
	var pulse := 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.008)
	for i in 4:
		var r := Rect2(i * (seg_w + gap), 0, seg_w, size.y)
		_hostility.draw_rect(r, Color(0.06, 0.08, 0.11, 0.85))
		var fill := clampf(_hostility_value * 4.0 - i, 0.0, 1.0)
		if fill > 0.0:
			var col: Color = HOSTILITY_COLORS[i]
			if i == 3 and fill >= 1.0 and not _hostility_hold:
				col = col * pulse
			_hostility.draw_rect(Rect2(r.position, Vector2(r.size.x * fill, r.size.y)), col)
		_hostility.draw_rect(r, Color(1, 1, 1, 0.3), false, 1.0)


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
