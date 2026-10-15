class_name SettingsPanel
extends VBoxContainer
## Settings shared by the title screen and the pause menu.

signal back_pressed

var _reset_btn: Button
var _reset_armed := false


func _ready() -> void:
	add_theme_constant_override("separation", 10)
	add_child(UiTheme.label("SETTINGS", 28, UiTheme.ACCENT))
	add_child(HSeparator.new())

	add_child(UiTheme.label("Mouse sensitivity", 16, UiTheme.MUTED))
	var sens := HSlider.new()
	sens.min_value = 0.0005
	sens.max_value = 0.008
	sens.step = 0.0001
	sens.value = Game.mouse_sensitivity
	sens.custom_minimum_size.x = 360
	sens.value_changed.connect(func(v: float):
		Game.mouse_sensitivity = v
		Game.save_settings())
	add_child(sens)

	var invert := CheckBox.new()
	invert.text = "Invert mouse Y"
	invert.button_pressed = Game.invert_y
	invert.toggled.connect(func(on: bool):
		Game.invert_y = on
		Game.save_settings())
	add_child(invert)

	add_child(UiTheme.label("Master volume", 16, UiTheme.MUTED))
	var vol := HSlider.new()
	vol.min_value = 0.0
	vol.max_value = 1.0
	vol.step = 0.01
	vol.value = Game.master_volume
	vol.value_changed.connect(func(v: float):
		Game.master_volume = v
		Game.apply_settings()
		Game.save_settings())
	add_child(vol)

	var fs := CheckBox.new()
	fs.text = "Fullscreen (F11)"
	fs.button_pressed = Game.fullscreen
	fs.toggled.connect(func(on: bool):
		Game.fullscreen = on
		Game.apply_settings()
		Game.save_settings())
	add_child(fs)

	add_child(HSeparator.new())
	_reset_btn = UiTheme.button("Reset campaign progress", _on_reset)
	add_child(_reset_btn)
	add_child(UiTheme.button("Back", func(): back_pressed.emit()))
	visibility_changed.connect(func():
		_reset_armed = false
		_reset_btn.text = "Reset campaign progress"
		_reset_btn.disabled = Net.mode == "client" or Game.mission != null)


func _on_reset() -> void:
	if not _reset_armed:
		_reset_armed = true
		_reset_btn.text = "Click again to erase all progress"
		return
	_reset_armed = false
	_reset_btn.text = "Progress reset"
	Game.reset_profile()
	if Net.is_online():
		Game.sync_profile.rpc(Game.profile)
