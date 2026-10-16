class_name CheatMenu
extends PanelContainer
## The homebase cheat menu, for testing (debug builds, host only): research points, unlocks, maxed
## ship upgrades, starting credits for dives and a fresh profile. Cheats change the real save; the
## first one keeps a copy of the profile from before, which "Restore my save" brings back.

## Credits every dive can start with (Game.cheat_dive_credits).
const DIVE_CREDITS := [0, 1000, 10000, 99999]

## Buttons by id (the autotest presses them too).
var buttons: Dictionary = {}
var _credits_label: Label
var _status: Label
var _fresh_armed := false


func _ready() -> void:
	add_theme_stylebox_override("panel", UiTheme.panel_style(1.0))
	custom_minimum_size = Vector2(460, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	var head := HBoxContainer.new()
	var title := UiTheme.label("CHEATS", 24, UiTheme.WARN)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(_button("close", "X", func(): visible = false, 44.0))
	v.add_child(head)
	var note := UiTheme.label("For testing. Cheats change your save; the first one keeps a copy of your profile from before, which Restore brings back.", 14, UiTheme.MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD
	v.add_child(note)

	v.add_child(UiTheme.label("Research points", 16, UiTheme.ACCENT))
	var rp_row := HBoxContainer.new()
	for amount: int in [100, 1000, 10000]:
		rp_row.add_child(_button("rp_%d" % amount, "+%s RP" % HomebaseLevel._fmt(amount), func(): Game.request_cheat("rp", amount)))
	v.add_child(rp_row)

	v.add_child(UiTheme.label("Unlocks and upgrades", 16, UiTheme.ACCENT))
	var unlock_row := HBoxContainer.new()
	unlock_row.add_child(_button("unlock_ships", "Unlock all ships", func(): Game.request_cheat("unlock_ships")))
	unlock_row.add_child(_button("unlock_guns", "Unlock all guns", func(): Game.request_cheat("unlock_guns")))
	v.add_child(unlock_row)
	var max_row := HBoxContainer.new()
	max_row.add_child(_button("max_ship", "Max this ship", func(): Game.request_cheat("max_ship")))
	max_row.add_child(_button("max_all", "Max all owned ships", func(): Game.request_cheat("max_all")))
	v.add_child(max_row)

	v.add_child(UiTheme.label("Dive credits (to test the waystation shops)", 16, UiTheme.ACCENT))
	var cr_row := HBoxContainer.new()
	for amount: int in DIVE_CREDITS:
		cr_row.add_child(_button("credits_%d" % amount, HomebaseLevel._fmt(amount), func(): _set_dive_credits(amount)))
	v.add_child(cr_row)
	_credits_label = UiTheme.label("", 14, UiTheme.MUTED)
	v.add_child(_credits_label)

	v.add_child(HSeparator.new())
	var save_row := HBoxContainer.new()
	save_row.add_child(_button("fresh", "Fresh profile", _on_fresh))
	save_row.add_child(_button("restore", "Restore my save", func(): Game.request_cheat("restore")))
	v.add_child(save_row)
	_status = UiTheme.label("", 14, UiTheme.MUTED)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD
	v.add_child(_status)
	Game.profile_changed.connect(refresh)
	visibility_changed.connect(refresh)
	refresh()


func _button(id: String, text: String, callback: Callable, width := 0.0) -> Button:
	var b := UiTheme.button(text, callback, width)
	if width <= 0.0:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if id != "fresh":
		# Any other button cancels a pending "Fresh profile".
		b.pressed.connect(func():
			_fresh_armed = false
			refresh())
	buttons[id] = b
	return b


func _set_dive_credits(amount: int) -> void:
	Game.cheat_dive_credits = amount
	refresh()


## A fresh profile needs a second click.
func _on_fresh() -> void:
	if not _fresh_armed:
		_fresh_armed = true
		(buttons["fresh"] as Button).text = "Click again: wipe"
		return
	_fresh_armed = false
	Game.request_cheat("fresh")


func refresh() -> void:
	if _credits_label == null:
		return
	if Game.cheat_dive_credits > 0:
		_credits_label.text = "Every dive starts with %s credits (until you quit the game)." % HomebaseLevel._fmt(Game.cheat_dive_credits)
	else:
		_credits_label.text = "Dives start with no credits, as normal."
	for amount: int in DIVE_CREDITS:
		(buttons["credits_%d" % amount] as Button).disabled = amount == Game.cheat_dive_credits
	if not visible:
		_fresh_armed = false
	if not _fresh_armed:
		(buttons["fresh"] as Button).text = "Fresh profile"
	var backup := Game.has_cheat_backup()
	(buttons["restore"] as Button).disabled = not backup
	_status.text = "Your profile from before the first cheat is kept; Restore my save brings it back." if backup \
			else "No cheats used on this save yet."
