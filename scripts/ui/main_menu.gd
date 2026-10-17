class_name MainMenu
extends Control
## Title screen: callsign, solo / host / join, settings. Draws an animated starfield behind.

signal solo_requested
signal host_requested(port: int)
signal join_requested(address: String, port: int)

var _name_edit: LineEdit
var _port_edit: LineEdit
var _addr_edit: LineEdit
var _status: Label
var _main_panel: Control
var _settings: SettingsPanel
var _stars: Array[Vector3] = []
var _t := 0.0


func _ready() -> void:
	theme = UiTheme.get_theme()
	UiTheme.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 260:
		_stars.append(Vector3(rng.randf(), rng.randf(), rng.randf_range(0.2, 1.0)))
	_build()
	show_menu("")


func show_menu(status: String) -> void:
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_status.text = status
	_settings.visible = false
	_main_panel.visible = true


func set_status(text: String) -> void:
	_status.text = text


func _process(delta: float) -> void:
	if visible:
		_t += delta
		queue_redraw()


func _draw() -> void:
	var size_v := size
	draw_rect(Rect2(Vector2.ZERO, size_v), Color(0.012, 0.018, 0.035))
	for s in _stars:
		var x := fmod(s.x + _t * 0.004 * s.z, 1.0) * size_v.x
		var y := s.y * size_v.y
		var a := 0.35 + 0.65 * s.z * (0.75 + 0.25 * sin(_t * 2.0 + s.x * 40.0))
		draw_rect(Rect2(x, y, 1.0 + s.z * 1.6, 1.0 + s.z * 1.6), Color(0.75, 0.85, 1.0, a))
	# A dim asteroid silhouette in the corner.
	var c := Vector2(size_v.x * 0.86, size_v.y * 0.92)
	var pts := PackedVector2Array()
	for i in 40:
		var ang := TAU * i / 40.0
		var r := size_v.y * 0.42 * (1.0 + 0.06 * sin(ang * 5.0 + 1.0) + 0.04 * sin(ang * 11.0))
		pts.append(c + Vector2(cos(ang), sin(ang)) * r)
	draw_colored_polygon(pts, Color(0.06, 0.06, 0.075))
	draw_circle(c + Vector2(-size_v.y * 0.12, -size_v.y * 0.18), size_v.y * 0.05, Color(0.02, 0.02, 0.03))


func _build() -> void:
	var center := CenterContainer.new()
	UiTheme.full_rect(center)
	add_child(center)
	var holder := VBoxContainer.new()
	center.add_child(holder)

	_main_panel = PanelContainer.new()
	_main_panel.custom_minimum_size = Vector2(560, 0)
	holder.add_child(_main_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	_main_panel.add_child(box)

	var title := UiTheme.label("COOP SHIP EXPLORER", 44, UiTheme.ACCENT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sub := UiTheme.label("Dive into asteroid caves. Mine. Repair. Survive the swarm.", 16, UiTheme.MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)
	box.add_child(HSeparator.new())

	var name_row := HBoxContainer.new()
	name_row.add_child(UiTheme.label("Callsign", 18, UiTheme.MUTED))
	_name_edit = LineEdit.new()
	_name_edit.text = Net.local_name
	_name_edit.max_length = 16
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.text_changed.connect(func(t: String): Net.local_name = t.strip_edges() if t.strip_edges() != "" else "Pilot")
	name_row.add_child(_name_edit)
	box.add_child(name_row)

	var solo := UiTheme.button("PLAY SOLO", func(): solo_requested.emit())
	solo.custom_minimum_size.y = 48
	box.add_child(solo)

	var host_row := HBoxContainer.new()
	host_row.add_theme_constant_override("separation", 8)
	var host_btn := UiTheme.button("HOST GAME", _on_host_pressed)
	host_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	host_btn.custom_minimum_size.y = 42
	host_row.add_child(host_btn)
	host_row.add_child(UiTheme.label("Port", 16, UiTheme.MUTED))
	_port_edit = LineEdit.new()
	_port_edit.text = str(Net.DEFAULT_PORT)
	_port_edit.custom_minimum_size.x = 90
	host_row.add_child(_port_edit)
	box.add_child(host_row)

	var join_row := HBoxContainer.new()
	join_row.add_theme_constant_override("separation", 8)
	var join_btn := UiTheme.button("JOIN GAME", _on_join_pressed)
	join_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	join_btn.custom_minimum_size.y = 42
	join_row.add_child(join_btn)
	_addr_edit = LineEdit.new()
	_addr_edit.text = Net.last_address
	_addr_edit.placeholder_text = "host address[:port]"
	_addr_edit.custom_minimum_size.x = 220
	join_row.add_child(_addr_edit)
	box.add_child(join_row)

	_status = UiTheme.label("", 16, UiTheme.WARN)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_status)
	box.add_child(HSeparator.new())

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 8)
	var settings_btn := UiTheme.button("Settings", func():
		_main_panel.visible = false
		_settings.visible = true)
	settings_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(settings_btn)
	var quit_btn := UiTheme.button("Quit", func(): get_tree().quit())
	quit_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(quit_btn)
	box.add_child(bottom)

	var settings_panel := PanelContainer.new()
	settings_panel.custom_minimum_size = Vector2(560, 0)
	holder.add_child(settings_panel)
	_settings = SettingsPanel.new()
	settings_panel.add_child(_settings)
	_settings.back_pressed.connect(func():
		_settings.visible = false
		_main_panel.visible = true)
	settings_panel.visible = false
	_settings.visibility_changed.connect(func(): settings_panel.visible = _settings.visible)

	var help := UiTheme.label(
		"Walk: WASD + mouse   Interact / leave station: E   Blaster / Toolkit: 1 / 2 (or Q)   Fire / repair: Left mouse   Reload: R   Drop crate: G\n"
		+ "Pilot: W/S throttle, A/D turn, Space/Ctrl up/down, T autopilot, X full stop, B emergency blast, L land / lift off   Crew status: Tab   Menu: Esc",
		14, UiTheme.MUTED)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	help.position.y -= 60
	help.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(help)


func _on_host_pressed() -> void:
	var port := int(_port_edit.text) if _port_edit.text.is_valid_int() else Net.DEFAULT_PORT
	host_requested.emit(port)


func _on_join_pressed() -> void:
	var text := _addr_edit.text.strip_edges()
	if text.is_empty():
		text = "127.0.0.1"
	var port := Net.DEFAULT_PORT
	var address := text
	var colon := text.rfind(":")
	if colon > 0 and text.count(":") == 1:
		address = text.substr(0, colon)
		var p := text.substr(colon + 1)
		if p.is_valid_int():
			port = int(p)
	join_requested.emit(address, port)
