class_name PauseMenu
extends Control
## In-game menu (Esc). Pauses the game in solo play only; online the world keeps running.

signal leave_requested
signal abort_requested

var _panel: PanelContainer
var _main_box: VBoxContainer
var _abort_btn: Button
var _leave_btn: Button
var _settings: SettingsPanel


func _ready() -> void:
	theme = UiTheme.get_theme()
	UiTheme.full_rect(self)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	UiTheme.full_rect(dim)
	add_child(dim)
	var center := CenterContainer.new()
	UiTheme.full_rect(center)
	add_child(center)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(420, 0)
	center.add_child(_panel)
	var holder := VBoxContainer.new()
	_panel.add_child(holder)
	_main_box = VBoxContainer.new()
	_main_box.add_theme_constant_override("separation", 10)
	holder.add_child(_main_box)
	_main_box.add_child(UiTheme.label("MENU", 30, UiTheme.ACCENT))
	_main_box.add_child(HSeparator.new())
	_main_box.add_child(UiTheme.button("Resume", hide_menu))
	_main_box.add_child(UiTheme.button("Settings", func():
		_main_box.visible = false
		_settings.visible = true))
	_abort_btn = UiTheme.button("Abort mission (return to homebase)", func(): abort_requested.emit())
	_main_box.add_child(_abort_btn)
	_leave_btn = UiTheme.button("Leave to title screen", func(): leave_requested.emit())
	_main_box.add_child(_leave_btn)
	_main_box.add_child(UiTheme.button("Quit game", func(): get_tree().quit()))
	_settings = SettingsPanel.new()
	_settings.visible = false
	holder.add_child(_settings)
	_settings.back_pressed.connect(func():
		_settings.visible = false
		_main_box.visible = true)
	visible = false


func toggle() -> void:
	if visible:
		hide_menu()
	else:
		show_menu()


func show_menu() -> void:
	visible = true
	_main_box.visible = true
	_settings.visible = false
	Game.ui_blocking = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_abort_btn.visible = multiplayer.is_server() and Game.mission != null
	_leave_btn.text = "End session (disconnects the crew)" if Net.mode == "host" else "Leave to title screen"
	if Net.mode == "solo":
		get_tree().paused = true


func hide_menu() -> void:
	if not visible:
		return
	visible = false
	Game.ui_blocking = false
	get_tree().paused = false
	if Game.main:
		Game.main.restore_mouse()
