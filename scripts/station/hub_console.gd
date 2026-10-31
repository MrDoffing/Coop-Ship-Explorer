class_name HubConsole
extends Node3D
## The control hub's computer (on the hub desk, see OutpostProps): a green-screen terminal and its
## keyboard. A crew member sits down at it (CrewMember: E): the view closes in on the screen and the
## keys type; Enter sends the line to the server as a command (Mothership.request_hub_command:
## HELP, DOORS, LOCK <id>, UNLOCK <id>), whose answer comes back to every peer into the screen's log
## (Mothership.fx_hub_log). What is being typed is the local player's own. Without power (a station
## with a generator, until it runs) the screen is dark and nobody can use it.
##
## Console-local frame: x right, y up, z towards the operator; the origin on the desk top under the
## middle of the screen.

## The text block on the screen: COLS characters wide (its rows follow from the screen's height).
const COLS := 40
const SCREEN := Vector2(0.46, 0.34)
## The screen's middle, and how far it leans back (degrees about x).
const SCREEN_AT := Vector3(0, 0.3, 0.035)
const TILT := -12.0
const FONT_SIZE := 32
const GREEN := Color(0.45, 1.0, 0.55)
## Where the view sits for the close look (out from the screen's middle) and its field of view; it
## looks a little below the middle, so the keys' stencil under the screen is in view.
const VIEW_DIST := 0.5
const VIEW_FOV := 50.0
const VIEW_DROP := 0.025
## The log keeps this many lines; a typed line at most TYPED_MAX characters.
const LOG_MAX := 60
const TYPED_MAX := 30
const TITLE := "OUTPOST CONTROL - HUB TERMINAL"
const BOOT := ["SYSTEM READY.", "TYPE HELP AND PRESS ENTER FOR COMMANDS."]
const HELP := ["COMMANDS:",
	"  DOORS        EVERY DOOR AND ITS STATE",
	"  LOCK D23     LOCK DOOR D23",
	"  UNLOCK D23   UNLOCK DOOR D23",
	"  HELP         THIS LIST",
	"DOOR IDS: SEE THE MAP OVER THE DESK."]

## The log (every peer's, from the server's answers) and the local player's own typing.
var lines := PackedStringArray()
var typed := ""
var active := false
var powered := false
var _rows := 12
var _text: Label3D
var _screen: MeshInstance3D
var _led: StandardMaterial3D
var _shown := "-"
## What the screen showed last (power, answers printed, typing, cursor), so it is composed only on a
## change.
var _key := []
var _printed := 0
var _t := 0.0


func build(m: Dictionary) -> void:
	var b := Models.Batch.new()
	# The monitor: a deep housing on a foot, the screen sunk in its bezel; the keyboard in front.
	var face := Transform3D(Models.euler(Vector3(TILT, 0, 0)), SCREEN_AT)
	b.box_at(face * Transform3D(Basis.IDENTITY, Vector3(0, 0, -0.03)), Vector3(SCREEN.x + 0.1, SCREEN.y + 0.12, 0.06), m["olive"])
	b.box_at(face * Transform3D(Basis.IDENTITY, Vector3(0, 0, -0.19)), Vector3(SCREEN.x - 0.02, SCREEN.y, 0.26), m["olive_dark"])
	b.box_at(face * Transform3D(Basis.IDENTITY, Vector3(0, -SCREEN.y * 0.5 - 0.04, 0.003)), Vector3(SCREEN.x + 0.06, 0.035, 0.006), m["dark"])
	b.box(Vector3(0, 0.04, -0.12), Vector3(0.24, 0.08, 0.22), m["gunmetal"])
	var keys := Transform3D(Models.euler(Vector3(5, 0, 0)), Vector3(0, 0.02, 0.24))
	b.box_at(keys, Vector3(0.48, 0.03, 0.17), m["gunmetal"])
	for r in 4:
		b.box_at(keys * Transform3D(Basis.IDENTITY, Vector3(0, 0.018, -0.06 + r * 0.037)), Vector3(0.43 - (0.06 if r == 3 else 0.0), 0.012, 0.028), m["steel"])
	b.commit(self, "HubConsole")
	_screen = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = SCREEN
	_screen.mesh = q
	_screen.material_override = GunPod.crt_material()
	_screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_screen.transform = face
	add_child(_screen)
	_led = Models.emissive(Color(0.2, 1.0, 0.3), 2.0, Color(0.05, 0.2, 0.06)).duplicate()
	Models.sphere(self, face * Vector3(SCREEN.x * 0.5 + 0.02, -SCREEN.y * 0.5 - 0.035, 0.006), 0.009, _led)
	# The text: left-aligned lines start at the label's origin and the block is centred top to
	# bottom; every line is padded to COLS and there are always _rows of them, so it never moves.
	_text = Label3D.new()
	_text.font = GunPod.mono_font()
	_text.font_size = FONT_SIZE
	_text.outline_size = 0
	_text.modulate = GREEN
	_text.double_sided = false
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_text.line_spacing = -2.0
	var font: Font = _text.font
	var block := font.get_string_size("-".repeat(COLS), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	_text.pixel_size = (SCREEN.x - 0.036) / block
	var row := (font.get_height(FONT_SIZE) + _text.line_spacing) * _text.pixel_size
	_rows = maxi(6, int((SCREEN.y - 0.03) / row))
	_text.transform = face * Transform3D(Basis.IDENTITY, Vector3(-(SCREEN.x - 0.036) * 0.5, 0, 0.002))
	add_child(_text)
	var hint := Label3D.new()
	hint.text = "TYPE A COMMAND    ENTER SEND    ESC LEAVE"
	hint.font = GunPod.mono_font()
	hint.font_size = 20
	hint.pixel_size = 0.0008
	hint.outline_size = 0
	hint.modulate = Color(0.85, 0.78, 0.45)
	hint.double_sided = false
	hint.transform = face * Transform3D(Basis.IDENTITY, Vector3(0, -SCREEN.y * 0.5 - 0.04, 0.007))
	add_child(hint)
	var area := Area3D.new()
	area.collision_layer = Game.LAYER_INTERACT
	area.collision_mask = 0
	area.monitoring = false
	area.set_meta("hub_console", true)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.62, 0.55, 0.75)
	cs.shape = shape
	cs.position = Vector3(0, 0.27, 0.04)
	area.add_child(cs)
	add_child(area)
	lines.append_array(PackedStringArray(BOOT))
	_show()


func _process(delta: float) -> void:
	_t += delta
	_show()


func set_powered(on: bool) -> void:
	if on == powered:
		return
	powered = on
	if not on:
		active = false
		typed = ""
	_show()


# --- Using it ----------------------------------------------------------------------------------

## The camera for the close look at the screen (global).
func view_transform() -> Transform3D:
	var x := global_transform * Transform3D(Models.euler(Vector3(TILT, 0, 0)), SCREEN_AT)
	var eye := x * Vector3(0, -VIEW_DROP, VIEW_DIST)
	return Transform3D(Basis.looking_at(x * Vector3(0, -VIEW_DROP, 0) - eye, x.basis.y), eye)


func enter() -> void:
	active = true
	typed = ""
	Sfx.play("switch", global_position, -8.0, 0.8)


func leave() -> void:
	active = false
	typed = ""


func type_char(c: String) -> void:
	if not active or typed.length() >= TYPED_MAX:
		return
	typed += c.to_upper()
	Sfx.play("switch", global_position, -16.0, 1.5)


func backspace() -> void:
	if active and not typed.is_empty():
		typed = typed.substr(0, typed.length() - 1)
		Sfx.play("switch", global_position, -16.0, 1.2)


## Enter: the line to send (and the typing cleared), or "".
func submit() -> String:
	var line := typed.strip_edges()
	typed = ""
	if active and line != "":
		Sfx.play("switch", global_position, -10.0, 0.9)
	return line if active else ""


## The server's answer to a command (on every peer): into the log, with a beep.
func print_lines(more: PackedStringArray, ok: bool) -> void:
	lines.append_array(more)
	_printed += 1
	if lines.size() > LOG_MAX:
		lines = lines.slice(lines.size() - LOG_MAX)
	if ok:
		Sfx.play("buy", global_position, -10.0, 1.2)
	else:
		Sfx.play("deny", global_position, -8.0)
	_show()


# --- The screen ----------------------------------------------------------------------------------

func _show() -> void:
	var key := [powered, _printed, typed, active, active and fposmod(_t * 2.0, 1.0) < 0.55]
	if key == _key:
		return
	_key = key
	var text := _compose() if powered else ""
	if text != _shown:
		_shown = text
		_text.text = text
		_screen.set_instance_shader_parameter("power", 1.0 if powered else 0.12)
		_led.emission = Color(0.2, 1.0, 0.3) if powered else Color(0.06, 0.02, 0.02)


## The block: the title and a rule, then the log's last lines with the prompt under them.
func _compose() -> String:
	var out := PackedStringArray([_pad(TITLE), _pad("=".repeat(COLS))])
	var cursor := "_" if active and fposmod(_t * 2.0, 1.0) < 0.55 else " "
	var shown := typed if typed.length() <= COLS - 4 else typed.right(COLS - 4)
	var body := lines.duplicate()
	body.append("> " + shown + cursor)
	var n := _rows - out.size()
	var from := maxi(0, body.size() - n)
	for i in n:
		out.append(_pad(body[from + i] if from + i < body.size() else ""))
	return "\n".join(out)


static func _pad(s: String) -> String:
	var t := s.left(COLS)
	return t + " ".repeat(COLS - t.length())
