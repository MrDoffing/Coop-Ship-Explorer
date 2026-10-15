class_name UiTheme
extends RefCounted
## Shared look for menus and the HUD, plus small helpers for building UI from code.

const ACCENT := Color(0.35, 0.85, 1.0)
const ACCENT_DIM := Color(0.2, 0.5, 0.65)
const TEXT := Color(0.86, 0.93, 1.0)
const MUTED := Color(0.55, 0.65, 0.72)
const WARN := Color(1.0, 0.72, 0.2)
const DANGER := Color(1.0, 0.32, 0.26)
const GOOD := Color(0.42, 1.0, 0.55)
const GOLD := Color(1.0, 0.85, 0.35)

static var _theme: Theme


static func get_theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Bahnschrift", "Segoe UI", "Arial"])
	t.default_font = font
	t.default_font_size = 18
	t.set_stylebox("panel", "Panel", panel_style())
	t.set_stylebox("panel", "PanelContainer", panel_style())
	t.set_stylebox("normal", "Button", box(Color(0.07, 0.14, 0.2, 0.95), ACCENT_DIM, 1, 4, 10))
	t.set_stylebox("hover", "Button", box(Color(0.1, 0.22, 0.3, 0.98), ACCENT, 1, 4, 10))
	t.set_stylebox("pressed", "Button", box(Color(0.15, 0.35, 0.45, 1.0), ACCENT, 2, 4, 10))
	t.set_stylebox("disabled", "Button", box(Color(0.06, 0.08, 0.1, 0.8), Color(0.25, 0.3, 0.35), 1, 4, 10))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", ACCENT)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(0.45, 0.5, 0.55))
	t.set_stylebox("normal", "LineEdit", box(Color(0.02, 0.05, 0.08, 0.95), ACCENT_DIM, 1, 3, 8))
	t.set_stylebox("focus", "LineEdit", box(Color(0.02, 0.05, 0.08, 0.95), ACCENT, 1, 3, 8))
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("font_color", "Label", TEXT)
	t.set_stylebox("background", "ProgressBar", box(Color(0.02, 0.04, 0.06, 0.85), Color(0.2, 0.3, 0.38), 1, 2, 0))
	t.set_stylebox("fill", "ProgressBar", box(ACCENT, Color(0, 0, 0, 0), 0, 2, 0))
	t.set_stylebox("panel", "TabContainer", box(Color(0.03, 0.06, 0.09, 0.9), ACCENT_DIM, 1, 4, 10))
	t.set_stylebox("tab_selected", "TabContainer", box(Color(0.12, 0.28, 0.36, 1.0), ACCENT, 1, 3, 8))
	t.set_stylebox("tab_unselected", "TabContainer", box(Color(0.05, 0.1, 0.14, 0.95), ACCENT_DIM, 1, 3, 8))
	t.set_stylebox("tab_hovered", "TabContainer", box(Color(0.09, 0.18, 0.24, 1.0), ACCENT, 1, 3, 8))
	t.set_color("font_selected_color", "TabContainer", Color.WHITE)
	t.set_color("font_unselected_color", "TabContainer", MUTED)
	t.set_color("font_hovered_color", "TabContainer", ACCENT)
	t.set_stylebox("separator", "HSeparator", box(ACCENT_DIM, Color(0, 0, 0, 0), 0, 0, 0))
	t.set_constant("separation", "HSeparator", 10)
	_theme = t
	return t


static func panel_style(alpha := 0.88) -> StyleBoxFlat:
	return box(Color(0.03, 0.06, 0.09, alpha), Color(0.3, 0.75, 0.95, 0.55), 1, 6, 14)


static func box(bg: Color, border: Color, border_w: int, radius: int, margin: float) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(margin)
	return s


static func label(text: String, size := 18, color := TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func button(text: String, callback: Callable, min_width := 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.x = min_width
	b.pressed.connect(func(): Sfx.play("ui"))
	b.pressed.connect(callback)
	return b


## A progress bar with its own fill colour.
static func bar(color: Color, height := 14.0) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size.y = height
	b.max_value = 1.0
	b.step = 0.0
	b.add_theme_stylebox_override("fill", box(color, Color(0, 0, 0, 0), 0, 2, 0))
	return b


static func full_rect(c: Control) -> Control:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return c
