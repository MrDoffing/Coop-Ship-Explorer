class_name Cockpit
extends Node3D
## The pilot's cockpit, at the very front of the mothership. The pilot sits right behind the glazed
## nose (built with the hull, see ShipBuilder._nose), which wraps round the seat for a wide view of
## the tunnel, at a dashboard that shows everything the pilot needs in the world instead of on the
## HUD:
## - The fuel gauge and the speedometer side by side left of the terminal: luminous dials with
##   figures round their scales and a window with the value. Hull integrity and shield side by side
##   right of it, on a plate of their own: vertical bar gauges with their figures under them. A
##   small red light over the fuel gauge and over each bar flashes when it runs critically low
##   (FUEL_LOW, HULL_LOW, SHIELD_LOW; the shield's also while it is down).
## - Three lamps over the terminal: the autopilot (a lit push switch), intruders aboard and the
##   hostility surging.
## - A green-text terminal: throttle, speed, depth, the systems, the emergency blast, hostility and
##   what the next station needs from the pilot.
## - Five screens with the hull's camera feeds (ShipTypes "cams"): the rear camera's hangs over the
##   dashboard like a rear-view mirror, the side cameras' (looking back along the flanks) stand on
##   arms off the dashboard's ends like a car's side mirrors, and the spine and belly cameras' are
##   set into the dashboard. Feeds looking back are mirrored, so what is on the left shows on the
##   left.
## - Side panels on cabinets either side of the seat: the engine's display on the left (a drawing of
##   the engine, its fan turning and its exhaust burning with the thrust, red where it is damaged,
##   its state and integrity) and the weapon systems' on the right (their state, and each gun pod's
##   belt and barrel heat).
## - The thrust lever on the left console, the gear stick on the right console (it leans with
##   turning and climbing) and the big red button (the emergency blast) under a hinged cover on a
##   pedestal right of the stick.
##
## In the seat, looking at the autopilot switch or the big red button shows its key over it, and LMB
## presses it (see hovered). An invisible barrier across the room's front (Game.LAYER_BARRIER) keeps
## the crew from climbing over the dashboard into the nose.
##
## Built in the cockpit frame: origin on the floor at the front of the cockpit room, where the
## glazed nose begins, -Z forward. Everyone sees the levers, dials and lamps move. The camera feeds
## only render while the local crew member is in or near the cockpit, one feed per frame in turn,
## so they flicker along like old closed-circuit television.

## Where the pilot sits and where their eye is (the first-person camera).
const SEAT := Vector3(0, 0, 0.62)
const EYE := Vector3(0, 1.3, 0.42)
## How far the pilot can turn their head (radians): either way, up and down. The view starts
## tipped down by LOOK_REST, so the top of the dashboard shows.
const LOOK_YAW := 1.75
const LOOK_UP := 0.95
const LOOK_DOWN := 1.2
const LOOK_REST := -0.08
## The camera feeds in the order of their screens, and the caption each screen shows.
const FEEDS := ["rear", "port", "stbd", "spine", "belly"]
const FEED_LABELS := {"rear": "CAM 1  REAR", "port": "CAM 2  PORT", "stbd": "CAM 3  STBD", "spine": "CAM 4  SPINE",
	"belly": "CAM 5  BELLY"}
## Feed resolution and field of view (degrees), and how close (m) the local crew member's camera
## must be to the pilot's eye for the feeds to render. A feed looks out from just in front of its
## camera's lens (LENS, in the camera's frame; see ShipBuilder._cam_housings).
const FEED_SIZE := Vector2i(320, 240)
const FEED_FOV := 64.0
const FEED_RANGE := 6.5
const LENS := Vector3(0, 0, -0.17)
## The gear stick leans this far (radians) at full turn or climb. The thrust lever's angle (radians,
## forward positive) at full reverse, stop and full ahead.
const STICK_TILT := 0.32
const LEVER_REV := -0.6
const LEVER_STOP := -0.12
const LEVER_FULL := 0.62
## The speedometer's full scale (m/s).
const SPEED_SCALE := 14.0
## Below these shares of full the red light over the fuel gauge, the hull bar or the shield bar
## flashes.
const FUEL_LOW := 0.2
const HULL_LOW := 0.3
const SHIELD_LOW := 0.25
## The dashboard's fascia: its middle, width and height, and how far its top tips away. Across it
## (fascia frame, out from the middle) the camera screens, the terminal (TERM_W wide), the two dials
## side by side left of it (the fuel gauge and the speedometer) and the two bar gauges side by side
## right of it (hull and shield), on a plate of their own.
const DASH := Vector3(0, 0.76, -0.62)
const DASH_SIZE := Vector2(2.0, 0.46)
const DASH_TILT := -16.0
const SCREEN_X := 0.82
const TERM_W := 0.41
const FUEL_X := -0.544
const SPEED_X := -0.326
const HULL_X := 0.37
const SHIELD_X := 0.5
## The consoles beside the seat: the thrust lever's and the gear stick's pivots. The big red button
## (its block's middle) on its pedestal right of the stick, and the side panels' cabinets either
## side of the seat (SIDE_X out, SIDE_Z back, their displays turned to the pilot).
const LEVER_PIVOT := Vector3(-0.56, 0.63, -0.12)
const STICK_PIVOT := Vector3(0.56, 0.62, -0.12)
const BUTTON := Vector3(0.95, 0.66, -0.3)
const SIDE_X := 0.87
const SIDE_Z := 0.12
## The side cabinets' height: low enough that a crew member behind the seat reaches over the right
## one to the red button.
const SIDE_H := 0.76
## The equipment racks run from RACK_X out to the walls.
const RACK_X := 1.0
## The terminal's text block: lines and columns (every line is padded to it, so the block never
## moves on the screen).
const NAV_ROWS := 9
const NAV_COLS := 32
## Looking within this much (radians) beyond a control's edge counts as looking at it.
const HOVER_SLACK := 0.03

## The camera feeds' green phosphor monitors: the picture as a monochrome image (with a trace of
## its colour), scanlines, a slight bulge, a vignette, noise, and snow when there is no signal.
## Feeds looking back are mirrored.
const FEED_SHADER := """
shader_type spatial;
render_mode unshaded, shadows_disabled;
uniform sampler2D feed : source_color, filter_linear, repeat_disable;
uniform bool mirror = false;
uniform vec3 tint : source_color = vec3(0.55, 1.0, 0.62);
instance uniform float power = 1.0;
instance uniform float snow = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 c = UV - 0.5;
	vec2 uv = 0.5 + c * (1.0 + 0.09 * dot(c, c));
	vec2 src = vec2(mirror ? 1.0 - uv.x : uv.x, uv.y);
	vec3 pic = texture(feed, src).rgb;
	float lum = dot(pic, vec3(0.3, 0.59, 0.11));
	lum = pow(clamp(lum * 1.7, 0.0, 1.0), 0.8);
	float n = hash(floor(uv * vec2(320.0, 240.0)) + floor(vec2(TIME * 47.0, TIME * 31.0)));
	float scan = 0.72 + 0.28 * sin(uv.y * 480.0);
	float band = fract(uv.y * 0.6 - TIME * 0.13);
	float roll = 1.0 - 0.12 * smoothstep(0.0, 0.08, band) * (1.0 - smoothstep(0.08, 0.16, band));
	float vig = 1.0 - smoothstep(0.3, 0.72, length(c * vec2(1.0, 1.2)));
	float inside = step(0.0, uv.x) * step(uv.x, 1.0) * step(0.0, uv.y) * step(uv.y, 1.0);
	vec3 col = mix(tint * lum, pic * 1.4, 0.18);
	col = mix(col, tint * n * 0.8, snow) + tint * n * 0.05;
	ALBEDO = col * scan * roll * (0.25 + 0.75 * vig) * inside * power;
}
"""

## A dial painted with luminous paint on a black face: a 270-degree scale with major and minor
## ticks (`majors` major divisions over the whole scale), red zones and a needle (instance uniform
## `value`, 0..1). The figures and the value's window are separate (Cockpit._build_dials).
const DIAL_SHADER := """
shader_type spatial;
render_mode unshaded, shadows_disabled;
uniform vec3 paint : source_color = vec3(0.72, 1.0, 0.7);
uniform vec3 red : source_color = vec3(1.0, 0.28, 0.16);
uniform vec3 face : source_color = vec3(0.022, 0.025, 0.023);
uniform float majors = 10.0;
uniform float red_to = 0.0;
uniform float red_from = 2.0;
instance uniform float value = 0.0;
instance uniform float power = 1.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	p.y = -p.y;
	float r = length(p);
	float aa = fwidth(r) * 1.5;
	float sweep = 4.712389;
	float f = atan(p.x, p.y) / sweep + 0.5;
	float on_scale = step(0.0, f) * step(f, 1.0);
	float major = abs(fract(f * majors + 0.5) - 0.5) / majors * sweep * r;
	float minor = abs(fract(f * majors * 5.0 + 0.5) - 0.5) / (majors * 5.0) * sweep * r;
	float ticks = (1.0 - smoothstep(0.016, 0.016 + aa, major)) * step(0.64, r) * step(r, 0.86);
	ticks += (1.0 - smoothstep(0.007, 0.007 + aa, minor)) * step(0.76, r) * step(r, 0.86);
	ticks += 1.0 - smoothstep(0.008, 0.008 + aa, abs(r - 0.86));
	ticks *= on_scale;
	float zone = on_scale * (step(f, red_to) + step(red_from, f)) * step(0.88, r) * step(r, 0.95);
	float va = (clamp(value, -0.02, 1.02) - 0.5) * sweep;
	vec2 nd = vec2(sin(va), cos(va));
	float along = dot(p, nd);
	float across = abs(p.x * nd.y - p.y * nd.x);
	float needle = (1.0 - smoothstep(0.022, 0.022 + aa, across + along * 0.012)) * step(-0.16, along) * step(along, 0.82);
	float hub = 1.0 - smoothstep(0.075, 0.075 + aa, r);
	vec3 col = mix(face, paint * 0.85, clamp(ticks, 0.0, 1.0));
	col = mix(col, red, zone);
	col = mix(col, paint * 1.7, needle);
	col = mix(col, vec3(0.12, 0.12, 0.11), hub);
	ALBEDO = col * (0.3 + 0.7 * power);
	ALPHA = 1.0 - smoothstep(1.0 - aa, 1.0, r);
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
"""

## A bar graph of luminous segments (vertical: filling up from the bottom; otherwise left to
## right): `segments` of them, lit up to instance uniform `value` (0..1). Segments below `low_to`
## are red, above `hot_from` amber and above `red_from` red again; `blink` dims the lit ones (for
## flashing).
const BAR_SHADER := """
shader_type spatial;
render_mode unshaded, shadows_disabled;
uniform vec3 lit : source_color = vec3(0.45, 1.0, 0.5);
uniform vec3 low : source_color = vec3(1.0, 0.25, 0.14);
uniform vec3 hot : source_color = vec3(1.0, 0.62, 0.15);
uniform float segments = 20.0;
uniform bool vertical = true;
uniform float low_to = 0.0;
uniform float hot_from = 2.0;
uniform float red_from = 2.0;
instance uniform float value = 0.0;
instance uniform float power = 1.0;
instance uniform float blink = 1.0;

void fragment() {
	float u = vertical ? 1.0 - UV.y : UV.x;
	float v = vertical ? UV.x : UV.y;
	float seg = floor(u * segments);
	float f = fract(u * segments);
	float cell = step(0.16, f) * step(f, 0.84) * step(0.14, v) * step(v, 0.86);
	float centre = (seg + 0.5) / segments;
	float on = seg < ceil(value * segments - 0.001) ? 1.0 : 0.0;
	vec3 col = centre < low_to || centre > red_from ? low : (centre > hot_from ? hot : lit);
	vec3 shown = mix(col * 0.08 + vec3(0.012), col * 1.5 * blink, on);
	ALBEDO = mix(vec3(0.008), shown, cell) * (0.25 + 0.75 * power);
}
"""

## The engine's display: a drawing of the engine from the side in glowing lines (added onto the
## screen under it): the intake fan with its blades turning (`spin`, radians), the casing with its
## cooling ribs, the nozzle and the exhaust burning as long as the thrust (`thrust`, 0..1). Below
## half integrity (`health`) the casing flashes red; offline the whole engine does.
const ENGINE_SHADER := """
shader_type spatial;
render_mode unshaded, shadows_disabled, blend_add, depth_draw_never;
uniform vec3 ink : source_color = vec3(0.4, 1.0, 0.45);
uniform vec3 alarm : source_color = vec3(1.0, 0.22, 0.1);
uniform vec3 fire : source_color = vec3(1.0, 0.6, 0.22);
uniform float aspect = 2.36;
instance uniform float spin = 0.0;
instance uniform float thrust = 0.0;
instance uniform float health = 1.0;
instance uniform float online = 1.0;
instance uniform float power = 1.0;

float seg(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}

float ink_line(float d, float w) {
	float aa = fwidth(d) * 1.2;
	return 1.0 - smoothstep(w, w + aa, d);
}

void fragment() {
	vec2 p = (UV - 0.5) * vec2(aspect, 1.0) * 2.2;
	p.y = -p.y;
	float w = 0.04;
	vec2 fc = vec2(-1.78, 0.0);
	float fan = ink_line(abs(length(p - fc) - 0.55), w);
	fan = max(fan, ink_line(length(p - fc) - 0.08, w));
	for (int k = 0; k < 6; k++) {
		float a = spin + float(k) * 1.0472;
		fan = max(fan, ink_line(seg(p, fc, fc + vec2(cos(a), sin(a)) * 0.5), w * 0.8));
	}
	vec2 q = abs(p - vec2(-0.05, 0.0)) - vec2(1.05, 0.56);
	float box = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0);
	float casing = ink_line(abs(box), w);
	for (int k = 0; k < 6; k++) {
		float x = -0.85 + float(k) * 0.32;
		casing = max(casing, ink_line(seg(p, vec2(x, -0.42), vec2(x, 0.42)), w * 0.7));
	}
	float duct = max(ink_line(seg(p, vec2(-1.1, 0.56), vec2(-1.57, 0.51)), w), ink_line(seg(p, vec2(-1.1, -0.56), vec2(-1.57, -0.51)), w));
	float nozzle = max(ink_line(seg(p, vec2(1.0, 0.56), vec2(1.55, 0.34)), w), ink_line(seg(p, vec2(1.0, -0.56), vec2(1.55, -0.34)), w));
	nozzle = max(nozzle, ink_line(seg(p, vec2(1.55, 0.34), vec2(1.55, -0.34)), w));
	float reach = thrust * (0.95 + 0.08 * sin(TIME * 41.0) * sin(TIME * 13.0));
	float t = (p.x - 1.6) / max(reach, 0.001);
	float flame = step(0.0, t) * step(t, 1.0) * step(0.01, reach) * (1.0 - t)
		* (1.0 - smoothstep(0.3 * (1.0 - t), 0.3 * (1.0 - t) + 0.04, abs(p.y)));
	float blink = step(0.5, fract(TIME * 2.0));
	vec3 hull_col = health < 0.5 ? mix(ink, alarm, blink) : ink;
	vec3 col = ink * max(max(fan, duct), nozzle) + hull_col * casing;
	if (online < 0.5) {
		col = alarm * max(max(fan, duct), max(nozzle, casing)) * (0.45 + 0.55 * blink);
	}
	col += fire * flame * 0.8 * online;
	ALBEDO = col * power * 1.3;
}
"""

const GREEN := Color(0.45, 1.35, 0.5)
const AMBER := Color(1.3, 0.85, 0.25)
const RED := Color(1.4, 0.35, 0.22)
## The lamps over the terminal, left to right: id, caption, colour.
const LAMPS := [["auto", "AUTOPILOT", Color(0.35, 1.0, 0.4)], ["intruder", "INTRUDER", Color(1.0, 0.2, 0.12)],
	["surge", "SURGE", Color(1.0, 0.2, 0.12)]]
const LAMP_SPACING := 0.15
## What the pilot can press by looking at it (LMB), and the key that does the same, shown over it.
const CONTROL_HINTS := {"auto": "[T] AUTOPILOT", "blast": "[B] EMERGENCY BLAST"}

static var _shared: Dictionary = {}

## The ship this cockpit belongs to (set by the Mothership).
var ship: Mothership
## The area the crew looks at to take the pilot seat, and the big red button's.
var station_area: Area3D
var button_area: Area3D
## The control the local pilot is looking at ("auto", "blast"; "" for none). LMB presses it.
var hovered := ""
## The layout this was built for (ShipTypes), and the room's inside half width.
var _t: Dictionary = {}
var _half_w := 3.0
var _height := 3.2
var _fascia: Transform3D
var _dials: Dictionary = {}
var _bars: Dictionary = {}
var _lights: Dictionary = {}
var _lamps: Dictionary = {}
var _nav: Label3D
var _nav_screen: MeshInstance3D
var _side_screens: Array[MeshInstance3D] = []
var _lever: Node3D
var _stick: Node3D
var _button_cap: MeshInstance3D
var _button_mat: StandardMaterial3D
var _cover: Node3D
## Seconds into the button press animation (-1: not pressed).
var _press_t := -1.0
var _lever_angle := LEVER_STOP
var _lever_click := 0.0
var _stick_tilt := Vector2.ZERO
var _last_yaw := 0.0
var _yaw_rate := 0.0
## Camera feeds: {"name", "vp", "cam", "xform" (ship-local), "screen", "seen" (has rendered)}.
var _feeds: Array[Dictionary] = []
var _feed_next := 0
var _feeds_on := false
var _screens: Array[MeshInstance3D] = []
var _clock := 0.0
var _nav_t := 0.0
## Text shown on the terminal, so the label is only touched when it changes.
var _nav_text := ""
var _auto_was := true
## The engine's display: the drawing, its fan's angle and the lines of text; the weapons' display:
## the state and a row per gun pod ({"id", "ammo", "heat", "count"}).
var _engine: Dictionary = {}
var _engine_spin := 0.0
var _weapons: Dictionary = {}
var _pod_rows: Array[Dictionary] = []
## The pressable controls in the cockpit frame: {"pos", "radius", "hint" (where its key shows)}.
var _controls: Dictionary = {}
var _hint: Label3D


## Build the cockpit for a ship layout (ShipTypes.get_type) into the ship's interior, with the
## collision of the furniture on `body` (the interior's StaticBody3D, ship-local).
func build(t: Dictionary, body: StaticBody3D) -> void:
	_t = t
	var room: Dictionary = (t["interior"] as Dictionary)["cockpit"]
	_half_w = float(room["half_w"])
	_height = float((t["interior"] as Dictionary)["height"])
	var b := Models.Batch.new()
	var m := _mats()
	_build_frame(b, m)
	_build_seat(b, m)
	_build_dashboard(b, m)
	_build_consoles(b, m)
	_build_racks(b, m)
	_build_sides(b, m)
	_build_screens(b, m)
	b.commit(self, "Cockpit")
	_build_dials()
	_build_bars()
	_build_lamps()
	_build_terminal()
	_build_engine_display()
	_build_weapons_display()
	_build_controls(m)
	_build_feeds()
	_build_hint()
	# The furniture: the dashboard, the consoles beside the seat, the side panels' cabinets and the
	# racks out to the walls.
	_solid(body, Vector3(0, 0.51, -0.31), Vector3(0.8, 1.02, 0.62))
	for s: float in [-1.0, 1.0]:
		_solid(body, Vector3(s * (RACK_X + _half_w) * 0.5, 0.475, 0.16), Vector3(_half_w - RACK_X, 0.95, 0.32))
		_solid(body, Vector3(s * 0.56, 0.3, -0.05), Vector3(0.32, 0.6, 1.1))
		_solid(body, Vector3(s * SIDE_X, SIDE_H * 0.5, SIDE_Z), Vector3(0.24, SIDE_H, 0.34))
	# Over them, an invisible barrier right across the room's front: only the crew's bodies collide
	# with it (Game.LAYER_BARRIER), so nobody climbs over the furniture into the nose, while their
	# reach (the red button) and their shots pass.
	var barrier := StaticBody3D.new()
	barrier.name = "Barrier"
	barrier.collision_layer = Game.LAYER_BARRIER
	barrier.collision_mask = 0
	add_child(barrier)
	var bs := CollisionShape3D.new()
	var bb := BoxShape3D.new()
	bb.size = Vector3(_half_w * 2.0, _height, 0.1)
	bs.shape = bb
	bs.position = Vector3(0, _height * 0.5, -0.05)
	barrier.add_child(bs)
	station_area = _area(Vector3(0, 0.9, 0.62), Vector3(0.75, 1.8, 0.9), "station", "pilot")
	# The button's area is big enough for a crew member standing behind the seat to reach.
	button_area = _area(_button_frame() * Vector3(0, 0.08, 0), Vector3(0.34, 0.3, 0.34), "emergency", true)
	# A dim lamp over the seat, so the levers and the dashboard's edges read in the dark.
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, 2.1, 0.75)
	lamp.omni_range = 2.6
	lamp.omni_attenuation = 0.8
	lamp.light_energy = 0.55
	lamp.light_color = Color(1.0, 0.8, 0.55)
	add_child(lamp)


## Where a crew member stands to reach the big red button (ship-local floor point), and the button
## itself.
func button_spot() -> Vector3:
	return transform * Vector3(0.75, 0.0, 1.0)


func button_local() -> Vector3:
	return transform * (_button_frame() * Vector3(0, 0.08, 0))


## The pilot's eye in the ship's space.
func eye_local() -> Vector3:
	return transform * EYE


## A pressable control's spot (ship-local): "auto" (the autopilot switch) or "blast".
func control_local(id: String) -> Vector3:
	return transform * (_controls[id]["pos"] as Vector3)


## Where a camera feed looks from (ship-local): just in front of its camera's lens.
static func feed_transform(t: Dictionary, cam: String) -> Transform3D:
	return ShipTypes.cam_transform(t, cam) * Transform3D(Basis.IDENTITY, LENS)


# --- Building ----------------------------------------------------------------------------------

func _mats() -> Dictionary:
	return {
		"olive": Models.panel_mat(Color(0.25, 0.27, 0.22), 0.35, 0.75, 3.0),
		"dark": Models.mat(Color(0.07, 0.075, 0.08), 0.4, 0.7),
		"steel": Models.mat(Color(0.5, 0.51, 0.5), 0.8, 0.35),
		"frame": frame_mat(),
		"bolt": Models.mat(Color(0.5, 0.49, 0.45), 0.5, 0.45),
		"leather": Models.mat(Color(0.2, 0.14, 0.1), 0.1, 0.8),
		"rubber": Models.mat(Color(0.05, 0.05, 0.05), 0.0, 0.9),
		"hazard": Models.mat(Color(0.9, 0.7, 0.1), 0.2, 0.6),
		"black": Models.mat(Color(0.02, 0.02, 0.02), 0.2, 0.6),
		"cable": Models.mat(Color(0.12, 0.1, 0.08), 0.1, 0.8),
	}


## Painted steel for the nose's frames and the posts round the room's opening.
static func frame_mat() -> StandardMaterial3D:
	return Models.mat(Color(0.3, 0.31, 0.27), 0.25, 0.6)


## The steel posts and header round the room's front opening, where the glazing begins.
func _build_frame(b: Models.Batch, m: Dictionary) -> void:
	for s: float in [-1.0, 1.0]:
		var x := s * (_half_w - 0.07)
		b.box(Vector3(x, _height * 0.5, -0.02), Vector3(0.14, _height, 0.16), m["frame"])
		for i in 7:
			var y := 0.35 + i * (_height - 0.6) / 6.0
			b.cyl(Vector3(x - s * 0.072, y, -0.02), 0.016, 0.016, m["bolt"], Vector3(0, 0, 90), -1.0, 6)
	b.box(Vector3(0, _height - 0.08, -0.02), Vector3(_half_w * 2.0, 0.16, 0.16), m["frame"])
	for i in 13:
		b.cyl(Vector3(-_half_w + 0.3 + i * (_half_w * 2.0 - 0.6) / 12.0, _height - 0.16, -0.02), 0.016, 0.016, m["bolt"], Vector3.ZERO, -1.0, 6)


## A bucket seat: steel shell, leather cushions, a headrest and the harness.
func _build_seat(b: Models.Batch, m: Dictionary) -> void:
	var s := SEAT
	b.cyl(s + Vector3(0, 0.2, 0.04), 0.07, 0.4, m["steel"])
	b.box(s + Vector3(0, 0.03, 0.04), Vector3(0.5, 0.06, 0.4), m["dark"])
	b.box(s + Vector3(0, 0.44, 0.0), Vector3(0.54, 0.06, 0.52), m["olive"])
	b.box(s + Vector3(0, 0.5, 0.0), Vector3(0.46, 0.07, 0.46), m["leather"])
	var back := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(10.0)), s + Vector3(0, 0.86, 0.27))
	b.add(_box(Vector3(0.54, 0.78, 0.06)), back, m["olive"])
	b.add(_box(Vector3(0.44, 0.66, 0.06)), back * Transform3D(Basis.IDENTITY, Vector3(0, 0, -0.05)), m["leather"])
	b.add(_box(Vector3(0.3, 0.2, 0.08)), back * Transform3D(Basis.IDENTITY, Vector3(0, 0.5, -0.03)), m["leather"])
	for x: float in [-0.29, 0.29]:
		b.box(s + Vector3(x, 0.5, 0.02), Vector3(0.04, 0.12, 0.5), m["steel"])
	# Harness straps over the shoulders.
	for x: float in [-0.12, 0.12]:
		b.add(_box(Vector3(0.05, 0.6, 0.012)), back * Transform3D(Basis.IDENTITY, Vector3(x, 0.05, -0.085)), m["cable"])
		b.add(_box(Vector3(0.06, 0.05, 0.02)), back * Transform3D(Basis.IDENTITY, Vector3(x, -0.15, -0.09)), m["steel"])


## The dashboard: a wide sloping fascia under a padded coaming, standing on the deck of the nose.
## Along its top, over the terminal, the lamps; below them, left to right, the spine camera's
## screen, the fuel gauge and the speedometer, the terminal, the hull and shield bars and the belly
## camera's screen.
func _build_dashboard(b: Models.Batch, m: Dictionary) -> void:
	_fascia = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(DASH_TILT)), DASH)
	var w := DASH_SIZE.x
	var h := DASH_SIZE.y
	b.add(_box(Vector3(w, h, 0.05)), _fascia, m["olive"])
	b.add(_box(Vector3(w + 0.04, 0.05, 0.17)), _fascia * Transform3D(Basis.IDENTITY, Vector3(0, h * 0.5 + 0.015, 0.05)), m["leather"])
	b.add(_box(Vector3(w + 0.02, 0.014, 0.02)), _fascia * Transform3D(Basis.IDENTITY, Vector3(0, -h * 0.5 + 0.005, 0.03)), m["hazard"])
	# The body under it, down to the deck, and the struts holding it.
	b.box(Vector3(0, 0.29, -0.66), Vector3(w - 0.1, 0.58, 0.3), m["dark"])
	for x: float in [-0.85, -0.3, 0.3, 0.85]:
		b.strut(Vector3(x, 0.36, -0.5), Vector3(x, 0.56, -0.56), 0.022, m["steel"])
	# Cable runs from under the dashboard into the floor.
	for i in 4:
		var x := -0.2 + i * 0.13
		b.strut(Vector3(x, 0.5, -0.55), Vector3(x * 1.4, 0.02, 0.12), 0.012, m["cable"])
	# The dials' bezels and the windows for their values.
	for x: float in [FUEL_X, SPEED_X]:
		b.add(_ring(0.085, 0.097), _fascia * Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(x, -0.01, 0.035)), m["steel"])
		b.add(_box(Vector3(0.046, 0.019, 0.004)), _fascia * Transform3D(Basis.IDENTITY, Vector3(x, -0.05, 0.032)), m["black"])
	# The bar gauges' plate (bolted on, with room for their names and figures), their steel frames
	# and black wells.
	var plate_x := (HULL_X + SHIELD_X) * 0.5
	b.add(_box(Vector3(SHIELD_X - HULL_X + 0.15, 0.39, 0.006)), _fascia * Transform3D(Basis.IDENTITY, Vector3(plate_x, -0.012, 0.027)), m["dark"])
	for c: Vector2 in [Vector2(-1, 1), Vector2(1, 1), Vector2(-1, -1), Vector2(1, -1)]:
		var at := Vector3(plate_x + c.x * ((SHIELD_X - HULL_X) * 0.5 + 0.06), -0.012 + c.y * 0.178, 0.031)
		b.add(_cyl(0.008, 0.008), _fascia * Transform3D(Basis(Vector3.RIGHT, PI / 2.0), at), m["bolt"])
	for x: float in [HULL_X, SHIELD_X]:
		b.add(_box(Vector3(0.074, 0.23, 0.026)), _fascia * Transform3D(Basis.IDENTITY, Vector3(x, -0.005, 0.03)), m["steel"])
		b.add(_box(Vector3(0.056, 0.212, 0.03)), _fascia * Transform3D(Basis.IDENTITY, Vector3(x, -0.005, 0.032)), m["black"])
	# The rims of the small red lights over the fuel gauge and the bars.
	for x: float in [FUEL_X, HULL_X, SHIELD_X]:
		b.add(_ring(0.011, 0.017), _fascia * Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(x, 0.125, 0.031)), m["steel"])
	# The terminal's and the camera screens' frames, and corner bolts.
	b.add(_box(Vector3(TERM_W, 0.3, 0.03)), _fascia * Transform3D(Basis.IDENTITY, Vector3(0, -0.02, 0.035)), m["black"])
	for x: float in [-SCREEN_X, SCREEN_X]:
		b.add(_box(Vector3(0.31, 0.24, 0.03)), _fascia * Transform3D(Basis.IDENTITY, Vector3(x, -0.02, 0.035)), m["black"])
	for c: Vector2 in [Vector2(-0.985, 0.215), Vector2(0.985, 0.215), Vector2(-0.985, -0.21), Vector2(0.985, -0.21)]:
		b.add(_cyl(0.012, 0.01), _fascia * Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(c.x, c.y, 0.03)), m["bolt"])


## The consoles beside the seat, reaching forward to the dashboard: the thrust lever's quadrant on
## the left, the gear stick's gate on the right; and right of the stick, the big red button's
## pedestal.
func _build_consoles(b: Models.Batch, m: Dictionary) -> void:
	for s: float in [-1.0, 1.0]:
		var x := s * 0.56
		b.box(Vector3(x, 0.3, -0.05), Vector3(0.32, 0.6, 1.1), m["olive"])
		b.box(Vector3(x, 0.605, -0.05), Vector3(0.34, 0.012, 1.12), m["dark"])
		b.box(Vector3(x - s * 0.165, 0.3, -0.05), Vector3(0.012, 0.58, 1.08), m["steel"])
	# Throttle quadrant: a slotted plate with its scale.
	var lp := LEVER_PIVOT
	b.box(Vector3(lp.x, 0.625, lp.z - 0.1), Vector3(0.12, 0.03, 0.46), m["steel"])
	b.box(Vector3(lp.x, 0.642, lp.z - 0.1), Vector3(0.025, 0.006, 0.42), m["black"])
	var flat := Basis(Vector3.RIGHT, -PI / 2.0)
	_label(Transform3D(flat, Vector3(lp.x - 0.1, 0.613, lp.z - 0.28)), Vector3.ZERO, "FULL", 26, Color(0.85, 0.82, 0.7))
	_label(Transform3D(flat, Vector3(lp.x - 0.1, 0.613, lp.z + 0.03)), Vector3.ZERO, "STOP", 26, Color(0.85, 0.82, 0.7))
	_label(Transform3D(flat, Vector3(lp.x - 0.1, 0.613, lp.z + 0.15)), Vector3.ZERO, "REV", 26, Color(1.0, 0.45, 0.3))
	_label(Transform3D(flat, Vector3(lp.x, 0.613, lp.z + 0.3)), Vector3.ZERO, "THRUST", 28, Color(0.85, 0.82, 0.7))
	# Gear stick boot, and the gate it moves in.
	var sp := STICK_PIVOT
	b.cyl(sp, 0.08, 0.04, m["rubber"])
	b.box(sp - Vector3(0, 0.007, 0), Vector3(0.22, 0.01, 0.22), m["steel"])
	_label(Transform3D(flat, sp + Vector3(0, -0.006, 0.2)), Vector3.ZERO, "STEER", 28, Color(0.85, 0.82, 0.7))
	# The big red button's pedestal, turned to the pilot like the block on top of it: hazard stripes
	# round the button and the stencil on its front.
	var block := _button_frame()
	var post := Transform3D(Basis(Vector3.UP, block.basis.get_euler().y), Vector3(BUTTON.x, 0.0, BUTTON.z))
	b.add(_box(Vector3(0.2, BUTTON.y, 0.2)), post * Transform3D(Basis.IDENTITY, Vector3(0, BUTTON.y * 0.5, 0)), m["olive"])
	b.add(_box(Vector3(0.22, 0.04, 0.22)), post * Transform3D(Basis.IDENTITY, Vector3(0, 0.02, 0)), m["dark"])
	_label(post, Vector3(0, BUTTON.y - 0.1, 0.101), "EMERGENCY", 26, Color(1.0, 0.35, 0.25))
	_label(post, Vector3(0, BUTTON.y - 0.13, 0.101), "BLAST", 26, Color(1.0, 0.35, 0.25))
	b.add(_box(Vector3(0.24, 0.1, 0.24)), block, m["dark"])
	b.add(_box(Vector3(0.22, 0.004, 0.22)), block * Transform3D(Basis.IDENTITY, Vector3(0, 0.051, 0)), m["hazard"])
	for i in 5:
		b.add(_box(Vector3(0.022, 0.005, 0.29)), block * Transform3D(Basis(Vector3.UP, PI / 4.0), Vector3(-0.1 + i * 0.05, 0.052, 0)),
			m["black"])
	b.add(_box(Vector3(0.15, 0.007, 0.15)), block * Transform3D(Basis.IDENTITY, Vector3(0, 0.054, 0)), m["dark"])


## The big red button's block (cockpit frame): turned to the pilot, its top tipped towards them.
static func _button_frame() -> Transform3D:
	var to := EYE - BUTTON
	return Transform3D(Basis(Vector3.UP, atan2(to.x, to.z)) * Basis(Vector3.RIGHT, deg_to_rad(30.0)), BUTTON)


## Equipment racks either side of the side panels' cabinets, out to the walls: breaker panels,
## dials and switches.
func _build_racks(b: Models.Batch, m: Dictionary) -> void:
	var dial_mat := Models.emissive(Color(0.35, 0.9, 0.4), 0.6, Color(0.02, 0.03, 0.02))
	for s: float in [-1.0, 1.0]:
		var x0 := RACK_X
		var w := _half_w - x0
		var cx := s * (x0 + _half_w) * 0.5
		b.box(Vector3(cx, 0.475, 0.16), Vector3(w, 0.95, 0.32), m["olive"])
		b.box(Vector3(cx, 0.955, 0.16), Vector3(w + 0.02, 0.02, 0.34), m["dark"])
		var n := int(w / 0.45)
		for i in n:
			var x := s * (x0 + 0.25 + i * 0.45)
			# A breaker panel with a row of switches and a small dial.
			b.box(Vector3(x, 0.62, 0.325), Vector3(0.36, 0.42, 0.012), m["dark"])
			for k in 4:
				b.box(Vector3(x - 0.12 + k * 0.08, 0.72, 0.335), Vector3(0.025, 0.04, 0.02), m["steel"])
			b.cyl(Vector3(x + 0.08, 0.53, 0.333), 0.05, 0.012, dial_mat, Vector3(90, 0, 0), -1.0, 12)
			b.cyl(Vector3(x - 0.08, 0.53, 0.334), 0.03, 0.012, Models.blink(Color(1.0, 0.55, 0.1) if (i + int(s)) % 2 else Color(0.3, 1.0, 0.4),
				0.6 + i * 0.13, 0.1 * i, 0.5), Vector3(90, 0, 0), -1.0, 10)
			for c: Vector2 in [Vector2(-0.16, 0.19), Vector2(0.16, 0.19), Vector2(-0.16, -0.19), Vector2(0.16, -0.19)]:
				b.cyl(Vector3(x + c.x, 0.62 + c.y, 0.333), 0.01, 0.01, m["bolt"], Vector3(90, 0, 0), -1.0, 6)
		# Conduits up the outside of the racks into the nose's frame.
		b.strut(Vector3(s * (_half_w - 0.15), 0.95, 0.05), Vector3(s * (_half_w - 0.15), _height - 0.2, -0.05), 0.03, m["cable"])
	# The kick plate at the front edge of the floor, under the dashboard and the racks.
	b.box(Vector3(0, 0.2, -0.01), Vector3(_half_w * 2.0, 0.4, 0.02), m["dark"])


## The side panels' cabinets either side of the seat, each with a display head on a neck, turned to
## the pilot: the engine's on the left, the weapons' on the right.
func _build_sides(b: Models.Batch, m: Dictionary) -> void:
	for s: float in [-1.0, 1.0]:
		var c := Vector3(s * SIDE_X, 0.0, SIDE_Z)
		b.box(c + Vector3(0, SIDE_H * 0.5, 0), Vector3(0.24, SIDE_H, 0.34), m["olive"])
		b.box(c + Vector3(0, SIDE_H + 0.005, 0), Vector3(0.26, 0.012, 0.36), m["dark"])
		b.box(c + Vector3(-s * 0.121, SIDE_H * 0.5, 0), Vector3(0.006, SIDE_H - 0.04, 0.3), m["steel"])
		for i in 5:
			b.box(c + Vector3(-s * 0.123, 0.18 + i * 0.07, 0), Vector3(0.006, 0.022, 0.2), m["black"])
		var head := _side_xform(s)
		b.strut(c + Vector3(0, SIDE_H, 0), head * Vector3(0, -0.06, -0.08), 0.032, m["steel"])
		b.add(_box(Vector3(0.3, 0.24, 0.12)), head * Transform3D(Basis.IDENTITY, Vector3(0, 0, -0.065)), m["dark"])
		b.add(_box(Vector3(0.276, 0.216, 0.01)), head * Transform3D(Basis.IDENTITY, Vector3(0, 0, -0.003)), m["black"])
		b.add(_box(Vector3(0.32, 0.02, 0.15)), head * Transform3D(Basis.IDENTITY, Vector3(0, 0.13, -0.05)), m["dark"])
		for cc: Vector2 in [Vector2(-0.137, 0.107), Vector2(0.137, 0.107), Vector2(-0.137, -0.107), Vector2(0.137, -0.107)]:
			b.add(_cyl(0.008, 0.008), head * Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(cc.x, cc.y, 0.002)), m["bolt"])


## The side panel's display head on side s (-1 left, 1 right), turned to the pilot's eye.
static func _side_xform(s: float) -> Transform3D:
	return _facing_eye(Vector3(s * SIDE_X, 1.04, SIDE_Z))


## A frame at `pos` turned to face the pilot's eye (its +Z towards the eye).
static func _facing_eye(pos: Vector3) -> Transform3D:
	var to := EYE - pos
	var yaw := atan2(to.x, to.z)
	var pitch := -atan2(to.y, Vector2(to.x, to.z).length())
	return Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch), pos)


## The screens for the camera feeds: the rear camera hangs over the dashboard like a rear-view
## mirror and the side cameras are on arms off the dashboard's ends like side mirrors, each in a
## housing with a hood; the spine and belly cameras' screens are set into the dashboard.
func _build_screens(b: Models.Batch, m: Dictionary) -> void:
	for f: String in ["rear", "port", "stbd"]:
		var xf := _screen_xform(f)
		b.add(_box(Vector3(0.34, 0.27, 0.12)), xf * Transform3D(Basis.IDENTITY, Vector3(0, 0, -0.065)), m["dark"])
		b.add(_box(Vector3(0.31, 0.235, 0.012)), xf * Transform3D(Basis.IDENTITY, Vector3(0, 0, -0.002)), m["black"])
		b.add(_box(Vector3(0.36, 0.02, 0.14)), xf * Transform3D(Basis.IDENTITY, Vector3(0, 0.145, -0.04)), m["dark"])
		for c: Vector2 in [Vector2(-0.15, 0.115), Vector2(0.15, 0.115), Vector2(-0.15, -0.115), Vector2(0.15, -0.115)]:
			b.add(_cyl(0.009, 0.008), xf * Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(c.x, c.y, 0.004)), m["bolt"])
	# The rear screen hangs from the header on two rods; the side screens stand on arms.
	var rear := _screen_xform("rear")
	for x: float in [-0.12, 0.12]:
		b.strut(rear * Vector3(x, 0.13, -0.07), Vector3(x, _height - 0.16, -0.02), 0.014, m["steel"])
	for s: float in [-1.0, 1.0]:
		var side := _screen_xform("port" if s < 0.0 else "stbd")
		var corner := _fascia * Vector3(s * (DASH_SIZE.x * 0.5 - 0.06), DASH_SIZE.y * 0.5, -0.02)
		b.strut(side * Vector3(0, -0.12, -0.1), corner, 0.025, m["steel"])
		b.add(_box(Vector3(0.08, 0.08, 0.08)), Transform3D(Basis.IDENTITY, corner), m["dark"])


## Where each screen sits (cockpit frame): the mirrors face the pilot's eye, the spine and belly
## screens are in the fascia.
func _screen_xform(f: String) -> Transform3D:
	match f:
		"rear":
			return _facing_eye(Vector3(0, 1.68, -0.85))
		"port", "stbd":
			return _facing_eye(Vector3(-1.04 if f == "port" else 1.04, 1.2, -0.56))
	return _fascia * Transform3D(Basis.IDENTITY, Vector3(-SCREEN_X if f == "spine" else SCREEN_X, -0.02, 0.052))


## The fuel gauge and the speedometer in the fascia: the dial, the figures round its scale (see
## _number_dial), a window with the value under the hub and its name below it.
func _build_dials() -> void:
	for d: Array in [["fuel", FUEL_X, "FUEL", 0.2], ["speed", SPEED_X, "SPEED  M/S", 0.0]]:
		var x := float(d[1])
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.17, 0.17)
		mi.mesh = q
		var mat := ShaderMaterial.new()
		mat.shader = _shader("dial", DIAL_SHADER)
		mat.set_shader_parameter("red_to", float(d[3]))
		mat.set_shader_parameter("red_from", 2.0)
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.transform = _fascia * Transform3D(Basis.IDENTITY, Vector3(x, -0.01, 0.03))
		add_child(mi)
		var readout := _label(_fascia, Vector3(x, -0.05, 0.035), "", 24, GREEN * 1.15)
		_label(_fascia, Vector3(x, -0.124, 0.032), str(d[2]), 20, GREEN * 0.8)
		_dials[d[0]] = {"mi": mi, "x": x, "shown": 0.0, "readout": readout, "figures": [], "full": 0.0}
	_number_dial("speed", SPEED_SCALE)
	_lights["fuel"] = _red_light(Vector3(FUEL_X, 0.125, 0.033))


## Put figures round dial `id`'s scale for a full scale of `full`: a major division every round
## step, with its figure inside the ticks.
func _number_dial(id: String, full: float) -> void:
	var d: Dictionary = _dials[id]
	if is_equal_approx(float(d["full"]), full) or full <= 0.0:
		return
	d["full"] = full
	for l: Label3D in d["figures"]:
		l.queue_free()
	var step := _round_step(full / 7.0)
	((d["mi"] as MeshInstance3D).material_override as ShaderMaterial).set_shader_parameter("majors", full / step)
	var figures: Array[Label3D] = []
	var k := 0
	while k * step <= full + 0.001:
		var a := (k * step / full - 0.5) * 4.712389
		var p := Vector3(float(d["x"]) + sin(a) * 0.046, -0.01 + cos(a) * 0.046, 0.033)
		figures.append(_label(_fascia, p, String.num(k * step, 0 if is_equal_approx(step, roundf(step)) else 1), 15, GREEN * 0.8))
		k += 1
	d["figures"] = figures


## The smallest round step (1, 2, 2.5 or 5 times a power of ten) of at least x.
static func _round_step(x: float) -> float:
	var mag := pow(10.0, floorf(log(x) / log(10.0)))
	for f: float in [1.0, 2.0, 2.5, 5.0]:
		if f * mag >= x - 0.0001:
			return f * mag
	return 10.0 * mag


## The hull and shield bar gauges in the fascia: twenty segments (the critically low ones painted
## red), the figures under them, their names and the red lights over them.
func _build_bars() -> void:
	for d: Array in [["hull", HULL_X, "HULL", HULL_LOW], ["shield", SHIELD_X, "SHIELD", SHIELD_LOW]]:
		var x := float(d[1])
		var mi := _bar_mesh(Vector2(0.036, 0.19), 20, true, float(d[3]), 2.0)
		mi.transform = _fascia * Transform3D(Basis.IDENTITY, Vector3(x, -0.005, 0.0485))
		add_child(mi)
		var readout := _label(_fascia, Vector3(x, -0.13, 0.032), "", 24, GREEN * 1.15)
		_label(_fascia, Vector3(x, -0.158, 0.032), str(d[2]), 20, GREEN * 0.8)
		_bars[d[0]] = {"mi": mi, "shown": 0.0, "readout": readout}
		_lights[d[0]] = _red_light(Vector3(x, 0.125, 0.033))


## A bar graph of luminous segments (BAR_SHADER) `size` big.
func _bar_mesh(size: Vector2, segments: int, vertical: bool, low_to: float, hot_from: float) -> MeshInstance3D:
	return bar_mesh(size, segments, vertical, low_to, hot_from)


## A bar graph of luminous segments (BAR_SHADER) `size` big, also for the scout's cockpit.
static func bar_mesh(size: Vector2, segments: int, vertical: bool, low_to: float, hot_from: float, red_from := 2.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	mi.mesh = q
	var mat := ShaderMaterial.new()
	mat.shader = _shader("bar", BAR_SHADER)
	mat.set_shader_parameter("segments", float(segments))
	mat.set_shader_parameter("vertical", vertical)
	mat.set_shader_parameter("low_to", low_to)
	mat.set_shader_parameter("hot_from", hot_from)
	mat.set_shader_parameter("red_from", red_from)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## A small red light in the fascia (fascia frame position), dark until it flashes.
func _red_light(pos: Vector3) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.12, 0.02, 0.02)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.12, 0.06)
	m.emission_energy_multiplier = 0.0
	var mi := MeshInstance3D.new()
	mi.mesh = _cyl(0.011, 0.01)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.transform = _fascia * Transform3D(Basis(Vector3.RIGHT, PI / 2.0), pos)
	add_child(mi)
	return m


## The lamps along the top of the fascia, over the terminal: the autopilot's is a lit push switch.
func _build_lamps() -> void:
	var n := LAMPS.size()
	for i in n:
		var l: Array = LAMPS[i]
		var x := (i - (n - 1) * 0.5) * LAMP_SPACING
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.06, 0.055, 0.05)
		m.emission_enabled = true
		m.emission = l[2]
		m.emission_energy_multiplier = 0.0
		var mi := MeshInstance3D.new()
		mi.mesh = _box(Vector3(0.13, 0.046, 0.012))
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.transform = _fascia * Transform3D(Basis.IDENTITY, Vector3(x, 0.178, 0.03))
		add_child(mi)
		var rim := MeshInstance3D.new()
		rim.mesh = _box(Vector3(0.142, 0.058, 0.008))
		rim.material_override = Models.mat(Color(0.5, 0.51, 0.5), 0.8, 0.35)
		rim.transform = _fascia * Transform3D(Basis.IDENTITY, Vector3(x, 0.178, 0.027))
		add_child(rim)
		var lbl := _label(_fascia, Vector3(x, 0.178, 0.0375), str(l[1]), 28, Color(0.42, 0.4, 0.36))
		_lamps[l[0]] = {"mat": m, "label": lbl}
		if l[0] == "auto":
			_controls["auto"] = {"pos": _fascia * Vector3(x, 0.178, 0.036), "radius": 0.07,
				"hint": _fascia * Vector3(x, 0.262, 0.06)}


## The green-text terminal in the middle of the fascia.
func _build_terminal() -> void:
	_nav_screen = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(TERM_W - 0.03, 0.27)
	_nav_screen.mesh = q
	_nav_screen.material_override = GunPod.crt_material()
	_nav_screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_nav_screen.transform = _fascia * Transform3D(Basis.IDENTITY, Vector3(0, -0.02, 0.0515))
	add_child(_nav_screen)
	_nav = Label3D.new()
	_nav.font = GunPod.mono_font()
	_nav.font_size = 26
	_nav.pixel_size = 0.0006
	_nav.outline_size = 0
	_nav.modulate = GREEN
	_nav.double_sided = false
	_nav.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_nav.line_spacing = -2.0
	# Left-aligned lines of text start at the label's origin (and the block is centred top to
	# bottom); the block is always NAV_ROWS by NAV_COLS characters, so this centres it on the screen.
	var block := _nav.font.get_string_size("-".repeat(NAV_COLS), HORIZONTAL_ALIGNMENT_LEFT, -1, _nav.font_size).x * _nav.pixel_size
	_nav.transform = _fascia * Transform3D(Basis.IDENTITY, Vector3(-block * 0.5, -0.02, 0.053))
	_nav.text = ""
	add_child(_nav)


## A side panel's screen (side s), for its display to be drawn on.
func _side_screen(s: float) -> Transform3D:
	var head := _side_xform(s)
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.26, 0.2)
	mi.mesh = q
	mi.material_override = GunPod.crt_material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.transform = head * Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.003))
	add_child(mi)
	_side_screens.append(mi)
	return head


## The engine's display on the left side panel: its name and state, the drawing of the engine
## (ENGINE_SHADER), its integrity as a bar and in figures, the thrust and the fan's revolutions.
func _build_engine_display() -> void:
	var head := _side_screen(-1.0)
	_label(head, Vector3(-0.118, 0.078, 0.006), "ENGINE", 26, GREEN, -1.0)
	var drawing := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.236, 0.1)
	drawing.mesh = q
	var mat := ShaderMaterial.new()
	mat.shader = _shader("engine", ENGINE_SHADER)
	mat.set_shader_parameter("aspect", 2.36)
	drawing.material_override = mat
	drawing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	drawing.transform = head * Transform3D(Basis.IDENTITY, Vector3(0, 0.012, 0.005))
	add_child(drawing)
	_label(head, Vector3(-0.118, -0.052, 0.006), "INTEGRITY", 20, GREEN * 0.8, -1.0)
	var bar := _bar_mesh(Vector2(0.09, 0.014), 10, false, 0.5, 2.0)
	bar.transform = head * Transform3D(Basis.IDENTITY, Vector3(0.022, -0.052, 0.006))
	add_child(bar)
	_engine = {
		"drawing": drawing, "bar": bar,
		"state": _label(head, Vector3(0.118, 0.078, 0.006), "", 22, GREEN, 1.0),
		"integrity": _label(head, Vector3(0.118, -0.052, 0.006), "", 20, GREEN, 1.0),
		"thrust": _label(head, Vector3(-0.118, -0.08, 0.006), "", 20, GREEN, -1.0),
		"rpm": _label(head, Vector3(0.118, -0.08, 0.006), "", 20, GREEN, 1.0),
	}


## The weapons' display on the right side panel: the weapon systems' state, and a row per gun pod
## with its belt (a bar and the rounds left) and its barrels' heat.
func _build_weapons_display() -> void:
	var head := _side_screen(1.0)
	_label(head, Vector3(-0.118, 0.078, 0.006), "WEAPONS", 26, GREEN, -1.0)
	_weapons = {"state": _label(head, Vector3(0.118, 0.078, 0.006), "", 22, GREEN, 1.0)}
	var guns: Array = _t.get("guns", [])
	if guns.is_empty():
		_label(head, Vector3(0, 0.0, 0.006), "NO GUN PODS", 22, GREEN * 0.7)
		return
	_label(head, Vector3(-0.06, 0.05, 0.006), "BELT", 17, GREEN * 0.7, -1.0)
	_label(head, Vector3(0.068, 0.05, 0.006), "HEAT", 17, GREEN * 0.7, -1.0)
	for i in mini(guns.size(), 4):
		var id: String = guns[i]
		var y := 0.022 - i * 0.032
		_label(head, Vector3(-0.118, y, 0.006), _pod_tag(id), 20, GREEN, -1.0)
		var ammo := _bar_mesh(Vector2(0.085, 0.013), 12, false, 0.0, 2.0)
		ammo.transform = head * Transform3D(Basis.IDENTITY, Vector3(-0.0175, y, 0.006))
		add_child(ammo)
		var heat := _bar_mesh(Vector2(0.05, 0.013), 8, false, 0.0, GunPod.HEAT_WARN)
		heat.transform = head * Transform3D(Basis.IDENTITY, Vector3(0.093, y, 0.006))
		add_child(heat)
		_pod_rows.append({"id": id, "ammo": ammo, "heat": heat, "count": _label(head, Vector3(0.046, y, 0.006), "", 19, GREEN)})


## A gun pod's short name on the weapons' display: PORT, STBD, BOW, FWD.
func _pod_tag(id: String) -> String:
	var name_s := str((_t["by_id"][id] as Dictionary).get("name", id)).to_upper()
	var word := name_s.split(" ")[0]
	return {"STARBOARD": "STBD", "FORWARD": "FWD"}.get(word, word.substr(0, 4))


## The animated controls: the thrust lever, the gear stick, the red button and its cover.
func _build_controls(m: Dictionary) -> void:
	_lever = Node3D.new()
	_lever.position = LEVER_PIVOT
	add_child(_lever)
	Models.cylinder(_lever, Vector3(0, 0.15, 0), 0.014, 0.3, m["steel"])
	Models.cylinder(_lever, Vector3(0, 0.31, 0), 0.03, 0.13, m["black"], Vector3(0, 0, 90))
	Models.sphere(_lever, Vector3(0, 0.31, -0.02), 0.022, Models.emissive(Color(1.0, 0.55, 0.15), 1.2))
	_stick = Node3D.new()
	_stick.position = STICK_PIVOT
	add_child(_stick)
	Models.cylinder(_stick, Vector3(0, 0.03, 0), 0.06, 0.07, m["rubber"], Vector3.ZERO, 0.03)
	Models.cylinder(_stick, Vector3(0, 0.15, 0), 0.016, 0.26, m["steel"])
	Models.sphere(_stick, Vector3(0, 0.3, 0), 0.042, m["black"])
	Models.cylinder(_stick, Vector3(0, 0.335, 0), 0.02, 0.012, Models.mat(Color(0.85, 0.82, 0.7), 0.1, 0.6))
	# The button and its cover move in the block's frame.
	var block := Node3D.new()
	block.transform = _button_frame()
	add_child(block)
	var button := Node3D.new()
	button.position = Vector3(0, 0.058, 0)
	block.add_child(button)
	_button_mat = StandardMaterial3D.new()
	_button_mat.albedo_color = Color(0.45, 0.02, 0.02)
	_button_mat.emission_enabled = true
	_button_mat.emission = Color(1.0, 0.12, 0.05)
	_button_mat.emission_energy_multiplier = 2.0
	Models.cylinder(button, Vector3(0, 0.0, 0), 0.066, 0.012, m["steel"], Vector3.ZERO, -1.0, 20)
	_button_cap = Models.cylinder(button, Vector3(0, 0.025, 0), 0.052, 0.04, _button_mat, Vector3.ZERO, 0.046, 20)
	# The hinged cover: a clear red guard in a steel rim, hinged at the far edge, so it flips up and
	# away from the pilot.
	_cover = Node3D.new()
	_cover.position = Vector3(0, 0.058, -0.068)
	block.add_child(_cover)
	var guard := Models.glass(Color(1.0, 0.3, 0.2, 0.14))
	Models.box(_cover, Vector3(0, 0.054, 0.068), Vector3(0.13, 0.004, 0.13), guard)
	for x: float in [-0.065, 0.065]:
		Models.box(_cover, Vector3(x, 0.027, 0.068), Vector3(0.006, 0.054, 0.13), m["steel"])
	Models.box(_cover, Vector3(0, 0.027, 0.133), Vector3(0.136, 0.054, 0.006), m["steel"])
	Models.cylinder(_cover, Vector3.ZERO, 0.009, 0.15, m["steel"], Vector3(0, 0, 90))
	_controls["blast"] = {"pos": _button_frame() * Vector3(0, 0.08, 0), "radius": 0.08, "hint": _button_frame() * Vector3(0, 0.2, 0)}


## The camera feeds: an offscreen view per hull camera and the screens that show them.
func _build_feeds() -> void:
	var cams: Dictionary = _t.get("cams", {})
	for f: String in FEEDS:
		if not cams.has(f):
			continue
		var vp := SubViewport.new()
		vp.size = FEED_SIZE
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		vp.positional_shadow_atlas_size = 0
		vp.msaa_3d = Viewport.MSAA_DISABLED
		vp.audio_listener_enable_3d = false
		add_child(vp)
		var cam := Camera3D.new()
		cam.fov = FEED_FOV
		cam.near = 0.1
		cam.far = 180.0
		cam.cull_mask &= ~(Game.VIS_INTERIOR | Game.VIS_VIEWMODEL)
		cam.environment = _feed_env()
		cam.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		vp.add_child(cam)
		cam.current = true
		var xform := feed_transform(_t, f)
		var mat := ShaderMaterial.new()
		mat.shader = _shader("feed", FEED_SHADER)
		mat.set_shader_parameter("feed", vp.get_texture())
		# A camera looking back is shown mirrored, like a mirror.
		mat.set_shader_parameter("mirror", (xform.basis * Vector3.FORWARD).z > 0.0)
		var screen := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.28, 0.21)
		screen.mesh = q
		screen.material_override = mat
		screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var sx := _screen_xform(f)
		screen.transform = sx * Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.006))
		add_child(screen)
		_label(sx, Vector3(-0.128, 0.088, 0.008), str(FEED_LABELS[f]), 22, GREEN, -1.0)
		var rec := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.006
		sm.height = 0.012
		rec.mesh = sm
		rec.material_override = Models.blink(Color(1.0, 0.15, 0.1), 0.8, 0.0, 0.5)
		rec.transform = sx * Transform3D(Basis.IDENTITY, Vector3(0.125, 0.088, 0.008))
		add_child(rec)
		_feeds.append({"name": f, "vp": vp, "cam": cam, "xform": xform, "screen": screen, "seen": false})
		_screens.append(screen)


## The key of the control the pilot looks at, floating over it (hidden until then).
func _build_hint() -> void:
	_hint = Label3D.new()
	_hint.font = GunPod.mono_font()
	_hint.font_size = 44
	_hint.pixel_size = 0.0005
	_hint.outline_size = 14
	_hint.outline_modulate = Color(0.0, 0.0, 0.0, 0.85)
	_hint.modulate = Color(1.0, 0.86, 0.45)
	_hint.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hint.no_depth_test = true
	_hint.visible = false
	add_child(_hint)


## Text in a plain monospace face on a panel (frame `frame`): `anchor` -1 starts it at `pos`, 0
## centres it there and 1 ends it there (kept when the text changes, see _set_text).
func _label(frame: Transform3D, pos: Vector3, text: String, size: int, color: Color, anchor := 0.0) -> Label3D:
	var l := Label3D.new()
	l.font = GunPod.mono_font()
	l.font_size = size
	l.pixel_size = 0.0005
	l.outline_size = 0
	l.modulate = color
	l.double_sided = false
	l.set_meta("anchor", anchor)
	_set_text(l, text)
	l.transform = frame * Transform3D(Basis.IDENTITY, pos)
	add_child(l)
	return l


## Change a label's text, keeping it anchored where it was made to start, centre or end.
static func _set_text(l: Label3D, text: String) -> void:
	if l.text == text and not text.is_empty():
		return
	l.text = text
	var anchor := float(l.get_meta("anchor", 0.0))
	if anchor != 0.0:
		l.offset.x = -anchor * l.font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, l.font_size).x * 0.5


## A collision box on the interior's body (cockpit frame position).
func _solid(body: StaticBody3D, pos: Vector3, size: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.position = transform * pos
	body.add_child(cs)


func _area(pos: Vector3, size: Vector3, key: String, value: Variant) -> Area3D:
	var a := Area3D.new()
	a.collision_layer = Game.LAYER_INTERACT
	a.collision_mask = 0
	a.monitoring = false
	a.position = pos
	a.set_meta(key, value)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	a.add_child(cs)
	add_child(a)
	return a


# --- Per frame ---------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if ship == null or not is_instance_valid(ship):
		return
	_clock += delta
	var lp: CrewMember = Game.mission.local_player if Game.mission else null
	var pilot_here := lp != null and lp.station == "pilot" and lp.alive
	var powered := ship.alive
	_update_hover(pilot_here, powered)
	_update_dials(delta, powered)
	_update_bars(delta, powered)
	_update_lamps(powered)
	_update_engine(delta, powered)
	_update_weapons(powered)
	_update_controls(delta, pilot_here)
	_update_button(delta)
	_nav_t -= delta
	if _nav_t <= 0.0:
		_nav_t = 0.15
		_update_terminal(powered)
	_update_feeds(powered)


## What the local pilot is looking at: the control nearest the middle of their view, if they look
## at it (or within HOVER_SLACK of its edge). Its key shows over it.
func _update_hover(pilot_here: bool, powered: bool) -> void:
	var want := ""
	var cam: Camera3D = get_viewport().get_camera_3d() if pilot_here and powered and not Game.ui_blocking else null
	if cam:
		var fwd := -cam.global_basis.z
		var best := INF
		for id: String in _controls:
			var c: Dictionary = _controls[id]
			var to := global_transform * (c["pos"] as Vector3) - cam.global_position
			var ang := fwd.angle_to(to)
			if ang < atan2(float(c["radius"]), to.length()) + HOVER_SLACK and ang < best:
				best = ang
				want = id
	hovered = want
	_hint.visible = want != ""
	if want == "":
		return
	_hint.position = _controls[want]["hint"]
	var text: String = CONTROL_HINTS[want]
	if want == "auto":
		text += " - TURN %s" % ("OFF" if ship.autopilot else "ON")
	elif ship.blast_cd > 0.0:
		text += " - %d S" % int(ceil(ship.blast_cd))
	if _hint.text != text:
		_hint.text = text


## The fuel gauge and the speedometer: the needles swing over (heavy and damped) and tremble a
## little while the engine runs; the windows show the values.
func _update_dials(delta: float, powered: bool) -> void:
	_number_dial("fuel", ship.max_fuel)
	var want := {"fuel": ship.fuel / maxf(ship.max_fuel, 0.001), "speed": ship.velocity.length() / SPEED_SCALE}
	var shake := 0.004 if ship.engine_online and powered else 0.0
	for k: String in _dials:
		var d: Dictionary = _dials[k]
		var target: float = want[k] if powered else 0.0
		var v := lerpf(float(d["shown"]), target, NetUtil.smooth(3.5, delta))
		d["shown"] = v
		var mi: MeshInstance3D = d["mi"]
		mi.set_instance_shader_parameter("value", v + sin(_clock * 37.0 + v * 9.0) * shake)
		mi.set_instance_shader_parameter("power", 1.0 if powered else 0.15)
	_set_text(_dials["fuel"]["readout"], "%d" % int(ceil(ship.fuel)) if powered else "")
	_set_text(_dials["speed"]["readout"], "%.1f" % ship.velocity.length() if powered else "")
	var low := ship.fuel < ship.max_fuel * FUEL_LOW and powered
	var rate := 0.25 if ship.fuel <= 0.0 else 0.6
	_lights["fuel"].emission_energy_multiplier = 3.0 if low and fmod(_clock, rate) < rate * 0.5 else 0.0


## The hull and shield bars fill and drain smoothly, with the figures under them; their red lights
## flash when they run critically low (the shield's quickly while it is down).
func _update_bars(delta: float, powered: bool) -> void:
	var want := {"hull": ship.hull / maxf(ship.max_hull, 0.001),
		"shield": 0.0 if ship.shield_down else ship.shield / maxf(ship.max_shield, 0.001)}
	for k: String in _bars:
		var d: Dictionary = _bars[k]
		var target: float = want[k] if powered else 0.0
		var v := lerpf(float(d["shown"]), target, NetUtil.smooth(5.0, delta))
		d["shown"] = v
		var mi: MeshInstance3D = d["mi"]
		mi.set_instance_shader_parameter("value", v)
		mi.set_instance_shader_parameter("power", 1.0 if powered else 0.15)
	if powered:
		_set_text(_bars["hull"]["readout"], "%d/%d" % [int(ceil(ship.hull)), int(round(ship.max_hull))])
		_set_text(_bars["shield"]["readout"], "DOWN" if ship.shield_down else "%d/%d" % [int(ceil(ship.shield)), int(round(ship.max_shield))])
	else:
		_set_text(_bars["hull"]["readout"], "")
		_set_text(_bars["shield"]["readout"], "")
	var blink := fmod(_clock, 0.6) < 0.3
	var fast := fmod(_clock, 0.25) < 0.125
	var hull_low := ship.hull < ship.max_hull * HULL_LOW
	var shield_low := ship.shield_down or ship.shield < ship.max_shield * SHIELD_LOW
	_lights["hull"].emission_energy_multiplier = 3.0 if powered and hull_low and blink else 0.0
	_lights["shield"].emission_energy_multiplier = 3.0 if powered and shield_low and (fast if ship.shield_down else blink) else 0.0


## The lamps over the terminal: levels 0 (dark), 1 (lit) and 2 (bright). The autopilot switch
## brightens while the pilot looks at it.
func _update_lamps(powered: bool) -> void:
	var blink := fmod(_clock, 0.6) < 0.3
	var fast := fmod(_clock, 0.25) < 0.125
	var flying := ship.landing == Mothership.Dock.FLYING
	var st := {
		"auto": 1 if ship.autopilot else 0,
		"intruder": (2 if fast else 0) if ship.boarders > 0 else 0,
		"surge": (2 if blink else 1) if ship.surging() and flying else 0,
	}
	for k: String in _lamps:
		var l: Dictionary = _lamps[k]
		var level: int = st.get(k, 0) if powered else 0
		var m: StandardMaterial3D = l["mat"]
		var look := 0.9 if hovered == k else 0.0
		m.emission_energy_multiplier = [0.0, 1.6, 3.2][level] + look
		# Light lettering on a dark lens; black lettering on a lit one.
		(l["label"] as Label3D).modulate = (Color(0.42, 0.4, 0.36) if look == 0.0 else Color(0.85, 0.8, 0.6)) if level == 0 else Color(0.03, 0.03, 0.02)


## The engine's display: the fan turns with the engine's output and the exhaust burns with the
## thrust; the state, integrity, thrust and revolutions in figures.
func _update_engine(delta: float, powered: bool) -> void:
	var online := ship.engine_online and powered
	var output := absf(ship.throttle) * (0.5 if ship.fuel <= 0.0 else 1.0) if online else 0.0
	var rpm := (600.0 + 3000.0 * output) if online else 0.0
	_engine_spin = fmod(_engine_spin + delta * rpm / 60.0 * 0.35, TAU)
	var drawing: MeshInstance3D = _engine["drawing"]
	drawing.set_instance_shader_parameter("spin", _engine_spin)
	drawing.set_instance_shader_parameter("thrust", output if ship.throttle > 0.0 else output * 0.4)
	drawing.set_instance_shader_parameter("health", ship.engine_hp / 100.0)
	drawing.set_instance_shader_parameter("online", 1.0 if online else 0.0)
	drawing.set_instance_shader_parameter("power", 1.0 if powered else 0.0)
	var bar: MeshInstance3D = _engine["bar"]
	bar.set_instance_shader_parameter("value", ship.engine_hp / 100.0 if powered else 0.0)
	bar.set_instance_shader_parameter("power", 1.0 if powered else 0.15)
	if not powered:
		for k: String in ["state", "integrity", "thrust", "rpm"]:
			_set_text(_engine[k], "")
		return
	var state := "ONLINE"
	var col := GREEN
	if not ship.engine_online:
		state = "OFFLINE" if fmod(_clock, 0.6) < 0.4 else ""
		col = RED
	elif ship.fuel <= 0.0:
		state = "NO FUEL"
		col = AMBER
	elif ship.engine_hp < 50.0:
		state = "DAMAGED"
		col = AMBER
	_set_text(_engine["state"], state)
	(_engine["state"] as Label3D).modulate = col
	_set_text(_engine["integrity"], "%d%%" % int(round(ship.engine_hp)))
	(_engine["integrity"] as Label3D).modulate = GREEN if ship.engine_hp >= 50.0 else (AMBER if ship.engine_online else RED)
	_set_text(_engine["thrust"], "THRUST %+d%%" % int(round(ship.throttle * 100.0)))
	_set_text(_engine["rpm"], "RPM %04d" % int(rpm))


## The weapons' display: the weapon systems' state and integrity, and each gun pod's belt (the
## loading belt filling up while it changes) and barrel heat.
func _update_weapons(powered: bool) -> void:
	var state := ""
	var col := GREEN
	if powered:
		if not ship.weapons_online:
			state = "OFFLINE" if fmod(_clock, 0.6) < 0.4 else ""
			col = RED
		else:
			state = "%s %d%%" % ["ONLINE" if ship.weapons_hp >= 50.0 else "DAMAGED", int(round(ship.weapons_hp))]
			col = GREEN if ship.weapons_hp >= 50.0 else AMBER
	_set_text(_weapons["state"], state)
	(_weapons["state"] as Label3D).modulate = col
	var blink := fmod(_clock, 0.5) < 0.25
	for row: Dictionary in _pod_rows:
		var id: String = row["id"]
		var i := ship.gun_index(id)
		var loading := ship.gun_reloading(id)
		var ammo := ship.gun_ammo_of(id)
		var fill := float(ammo) / GunPod.BELT
		if loading and i >= 0 and i < ship.gun_reload.size():
			fill = clampf(1.0 - ship.gun_reload[i] / GunPod.RELOAD_TIME, 0.0, 1.0)
		var on := 1.0 if powered and ship.weapons_online else 0.3
		var am: MeshInstance3D = row["ammo"]
		am.set_instance_shader_parameter("value", fill if powered else 0.0)
		am.set_instance_shader_parameter("blink", 0.5 if loading and not blink else 1.0)
		am.set_instance_shader_parameter("power", on)
		var ht: MeshInstance3D = row["heat"]
		ht.set_instance_shader_parameter("value", ship.gun_heat_of(id) if powered else 0.0)
		ht.set_instance_shader_parameter("power", on)
		var count: Label3D = row["count"]
		_set_text(count, ("LOAD" if loading else "%03d" % ammo) if powered else "")
		count.modulate = AMBER if loading or ammo * 5 <= GunPod.BELT else GREEN


## The thrust lever follows the throttle; the gear stick leans with the pilot's turn and climb
## input, or (for everyone else, and while the autopilot steers) with how the ship turns and climbs.
func _update_controls(delta: float, pilot_here: bool) -> void:
	var t := ship.throttle
	var want := lerpf(LEVER_STOP, LEVER_FULL, t) if t >= 0.0 else lerpf(LEVER_STOP, LEVER_REV, -t / 0.4)
	var prev := _lever_angle
	_lever_angle = move_toward(_lever_angle, want, delta * 2.5)
	_lever.rotation.x = -_lever_angle
	# A click at every notch the lever passes.
	_lever_click += absf(_lever_angle - prev)
	if _lever_click > 0.12:
		_lever_click = 0.0
		_sound("lever", -14.0)
	var yaw := ship.rotation.y
	if _clock <= delta:
		_last_yaw = yaw
	var rate := angle_difference(_last_yaw, yaw) / maxf(delta, 0.001)
	_last_yaw = yaw
	_yaw_rate = lerpf(_yaw_rate, rate, NetUtil.smooth(6.0, delta))
	var turn := clampf(_yaw_rate / maxf(float(ship.stats.get("yaw_rate", 0.4)), 0.01), -1.0, 1.0)
	var climb := clampf(ship.velocity.dot(ship.global_basis.y) / maxf(float(ship.stats.get("vert_speed", 5.0)), 0.01), -1.0, 1.0)
	if pilot_here and not Game.ui_blocking:
		var in_turn := Input.get_axis("move_right", "move_left")
		var in_climb := Input.get_axis("descend", "jump")
		if absf(in_turn) > 0.05:
			turn = in_turn
		if absf(in_climb) > 0.05:
			climb = in_climb
	var tilt := Vector2(turn, climb) * STICK_TILT
	_stick_tilt = _stick_tilt.lerp(tilt, NetUtil.smooth(10.0, delta))
	# Pull back to climb, push forward to dive; lean left to turn left.
	_stick.rotation = Vector3(_stick_tilt.y, 0.0, _stick_tilt.x)
	if pilot_here and ship.autopilot != _auto_was:
		_sound("switch", -8.0)
	_auto_was = ship.autopilot


## Flip the big red button's cover up and press it (the pilot's B or a look and a click, a crew
## member's E, or the blast going off for everyone else).
func press_button() -> void:
	if _press_t < 0.0 or _press_t > 0.9:
		_press_t = 0.0
		_sound("clunk", -6.0)


func _update_button(delta: float) -> void:
	var open := 0.0
	var down := 0.0
	if _press_t >= 0.0:
		_press_t += delta
		open = smoothstep(0.0, 0.12, _press_t) * (1.0 - smoothstep(1.1, 1.4, _press_t))
		down = smoothstep(0.12, 0.2, _press_t) * (1.0 - smoothstep(0.45, 0.6, _press_t))
		if _press_t > 1.5:
			_press_t = -1.0
	_cover.rotation.x = -open * 1.9
	_button_cap.position.y = 0.025 - down * 0.018
	var ready := ship.blast_cd <= 0.0 and ship.alive
	_button_mat.emission_energy_multiplier = ((1.4 + 0.8 * sin(_clock * 5.0)) if ready else 0.2) + (1.0 if hovered == "blast" else 0.0)


func _update_terminal(powered: bool) -> void:
	var text := pilot_text(ship) if powered else ""
	if text != _nav_text:
		_nav_text = text
		_nav.text = text
	_nav_screen.set_instance_shader_parameter("power", 1.0 if powered else 0.2)
	for s in _side_screens:
		s.set_instance_shader_parameter("power", 1.0 if powered else 0.2)


## What the pilot's terminal shows: throttle and autopilot, speed and depth, the systems, the blast,
## the hostility, and what the next station (or the docking) needs from the pilot.
static func pilot_text(s: Mothership) -> String:
	var lines := PackedStringArray()
	lines.append("THRUST %+4d%%   AUTOPILOT %s" % [int(round(s.throttle * 100.0)), "ON" if s.autopilot else "OFF"])
	lines.append("SPEED %4.1f M/S   DEPTH %05d M" % [s.velocity.length(), int(s.depth)])
	lines.append("ENGINE %s  WEAPONS %s" % [_sys(s.engine_hp, s.engine_online), _sys(s.weapons_hp, s.weapons_online)])
	lines.append("BLAST %s   HOSTILITY %s" % ["READY" if s.blast_cd <= 0.0 else "%2d S" % int(ceil(s.blast_cd)),
		Mothership.HOSTILITY_STAGES[s.hostility_stage()]])
	lines.append("-".repeat(NAV_COLS))
	for l: String in s.pilot_status():
		lines.append(l.to_upper())
	# A block of fixed size, so it sits still on the screen whatever it says.
	while lines.size() < NAV_ROWS:
		lines.append("")
	for i in lines.size():
		lines[i] = lines[i].substr(0, NAV_COLS).rpad(NAV_COLS)
	return "\n".join(lines.slice(0, NAV_ROWS))


static func _sys(hp: float, online: bool) -> String:
	return "%3d%%" % int(round(hp)) if online else " OFF"


## Render the camera feeds while the local crew member is in or near the cockpit: one feed each
## frame, in turn, from where its camera is on the ship right now.
func _update_feeds(powered: bool) -> void:
	var cam := get_viewport().get_camera_3d()
	var near := cam != null and powered and ship.to_local(cam.global_position).distance_to(eye_local()) < FEED_RANGE
	if near != _feeds_on:
		_feeds_on = near
		if not near:
			for f in _feeds:
				(f["vp"] as SubViewport).render_target_update_mode = SubViewport.UPDATE_DISABLED
	for s in _screens:
		s.set_instance_shader_parameter("power", 1.0 if powered else 0.0)
	if not near or _feeds.is_empty():
		return
	var f: Dictionary = _feeds[_feed_next]
	(f["cam"] as Camera3D).global_transform = ship.get_global_transform_interpolated() * (f["xform"] as Transform3D)
	(f["vp"] as SubViewport).render_target_update_mode = SubViewport.UPDATE_ONCE
	if not f["seen"]:
		f["seen"] = true
		(f["screen"] as MeshInstance3D).set_instance_shader_parameter("snow", 0.0)
	_feed_next = (_feed_next + 1) % _feeds.size()


## Cockpit sounds: in 2D for the pilot, from the dashboard for everyone else nearby.
func _sound(id: String, db: float) -> void:
	var lp: CrewMember = Game.mission.local_player if Game.mission else null
	if lp != null and lp.station == "pilot":
		Sfx.play(id, null, db)
	elif is_inside_tree():
		Sfx.play(id, to_global(Vector3(0, 0.8, -0.2)), db)


# --- Shared resources --------------------------------------------------------------------------

## The feeds' cameras see the cave as a low-light camera would: no dark corners, a little haze.
static func _feed_env() -> Environment:
	if not _shared.has("env"):
		var env := Environment.new()
		env.background_mode = Environment.BG_COLOR
		env.background_color = Color(0.0, 0.0, 0.0)
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color(0.55, 0.6, 0.65)
		env.ambient_light_energy = 1.1
		env.tonemap_mode = Environment.TONE_MAPPER_ACES
		env.fog_enabled = true
		env.fog_light_color = Color(0.04, 0.05, 0.06)
		env.fog_density = 0.012
		_shared["env"] = env
	return _shared["env"]


static func _shader(key: String, code: String) -> Shader:
	if not _shared.has(key):
		var sh := Shader.new()
		sh.code = code
		_shared[key] = sh
	return _shared[key]


static func _box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


static func _cyl(radius: float, height: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = radius
	m.bottom_radius = radius
	m.height = height
	m.radial_segments = 10
	m.rings = 1
	return m


## A ring (a dial's bezel), its axis along Y.
static func _ring(inner: float, outer: float) -> TorusMesh:
	var m := TorusMesh.new()
	m.inner_radius = inner
	m.outer_radius = outer
	m.rings = 24
	m.ring_segments = 6
	return m
