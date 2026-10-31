class_name Helmet
extends Node3D
## The helmet around a walking crew member's own first-person view (their camera's child; CrewMember
## shows it only while walking). Its edge frames the view all round: a steel shell with a rubber
## seal's bead round the opening, panel seams and rivets, the visor's hinges at the top corners,
## hoses round the lower corners, and in its chin the instruments, each on a flat plate pressed into
## the shell (lit by their own glow), a breathing vent between them and two status lamps:
## - Bottom left, VITALS: the crew member's health (the figure, a bar and a heartbeat trace that
##   races as the health drops, and runs flat once knocked out). The CRIT lamp beside it flashes
##   while the health is critical.
## - Bottom right, SUIT: whether the visor is sealed, and out of the ship a homing needle with the
##   distance back to the ship's cargo door (the flashlight's state under it). The SEAL lamp beside
##   it shines green while the visor is sealed, amber while it moves.
## The opening is tight at the sides and the top, its sides bowed out a little and its bottom a
## shallow V; the shell is deepest at the bottom, where the instruments are.
## The visor (grimy glass like the mothership's windows: grime gathered round its edge and along the
## bottom, smudges and scratches) swings down and seals by itself when the crew member leaves the
## ship and opens again back aboard; it fogs up for a moment as it seals. Once the health is down to
## half (CRACK_START) the visor cracks from its edges, more and further as the health drops; once it
## is critical (CRITICAL) the suit beeps. The cracks seal over once the health has recovered.
##
## Built in the camera's frame (-Z forward, the eye at the origin). Everything is on the viewmodel
## render layer (Game.VIS_VIEWMODEL), which the crew's own flashlight does not light. Other lights
## only reach the inside of the helmet through its opening, from ahead: the shell and its fittings
## (LIT_SHADER) and the visor (no reflections of anything behind it) leave out light from behind.

## The opening of the helmet, in tangent space (x / -z, y / -z from the eye; see outline()): its
## sides bow out a little (OPEN_SIDE in the middle, SIDE_BOW less at their ends), its top is nearly
## straight (OPEN_TOP) and its bottom is a shallow V, lowest in the middle (OPEN_BOTTOM, V_RISE higher
## 1.2 out). At FOV 78 on a 16:9 screen the rim leaves about 2% of the width at each side, 2% of the
## height at the top and 13-16% at the bottom, for the instruments.
const OPEN_SIDE := 1.395
const SIDE_BOW := 0.06
const OPEN_TOP := 0.775
const OPEN_BOTTOM := -0.6
const V_RISE := 0.085
## How many points the opening's outline (and the shell round it) is divided into.
const OUTLINE_POINTS := 176
## The shell's rings from the opening out, scaled round MIDDLE: [scale, distance from the eye]. The
## first four are the rubber seal's bead round the opening.
const MIDDLE := Vector2(0.0, 0.08)
const RINGS := [[1.0, 0.1335], [1.012, 0.1324], [1.026, 0.1338], [1.04, 0.1352], [1.07, 0.1358], [1.11, 0.1358],
	[1.16, 0.1355], [1.22, 0.135], [1.3, 0.1342], [1.4, 0.133], [1.55, 0.131], [1.75, 0.128], [2.05, 0.123],
	[2.5, 0.115], [3.1, 0.104]]
## Panel seams: grooves across the shell from where the bottom of the opening is at x = SEAMS_X and
## the sides at y = SEAMS_Y, and one round it along ring SEAM_RING.
const SEAMS_X := [0.0, -1.0, 1.0]
const SEAMS_Y := [0.32]
const SEAM_RING := 6
## The instruments: their middles (tangent space) and size (m). Each sits on a flat plate pressed
## PLATE_INSET into the shell (whose face is about PLATE_R from the eye there); the plate reaches
## PLATE_MARGIN past the screen and blends into the shell over PLATE_FALL. The breathing vent sits
## on a plate of its own under the V.
const VITALS_AT := Vector2(-0.68, -0.7)
const SUIT_AT := Vector2(0.68, -0.7)
const DISPLAY_SIZE := Vector2(0.034, 0.017)
const VENT_AT := Vector2(0.0, -0.745)
const VENT_SIZE := Vector2(0.026, 0.009)
const PLATE_R := 0.1356
const PLATE_INSET := 0.0012
const PLATE_MARGIN := 0.0045
const PLATE_FALL := 0.005
## The visor: radius of its glass round the eye, and how far it swings up to open (radians).
const R_VISOR := 0.158
const OPEN_ANGLE := 1.5
const VISOR_TIME := 0.7
## Below CRACK_START of max health the visor cracks (crack k once below CRACK_AT[k], growing to full
## length over CRACK_GROW more of the health); the cracks seal once the health is back above
## CRACK_START + HEAL_MARGIN. Below CRITICAL the health is critical: the suit beeps and the CRIT
## lamp flashes.
const CRITICAL := 0.3
const CRACK_START := 0.5
const CRACK_AT := [0.5, 0.4, 0.3, 0.2, 0.1]
const CRACK_GROW := 0.15
const HEAL_MARGIN := 0.12
## The cracks: where each starts by the visor's edge (tangent space), the way it runs and its full
## length.
const CRACKS := [[Vector2(-0.95, -0.51), Vector2(0.55, 0.85), 0.62], [Vector2(1.36, 0.25), Vector2(-1.0, -0.2), 0.66],
	[Vector2(-1.12, 0.72), Vector2(0.8, -0.6), 0.55], [Vector2(0.72, -0.53), Vector2(-0.3, 1.0), 0.5],
	[Vector2(-1.36, -0.12), Vector2(1.0, 0.3), 0.52]]
## Where the ship's cargo door is (ship-local), for the homing needle.
const SHIP_DOOR := Vector3(0, 1.0, 10.8)

const GREEN := Color(0.45, 1.35, 0.5)
const AMBER := Color(1.3, 0.85, 0.25)
const RED := Color(1.4, 0.35, 0.22)

## The visor's glass: tinted, grime gathered round its edge (`edge`: the opening, as above) and
## along the bottom, light smudges and scratches, the fog as it seals, and the cracks (`cracks`: xy where each starts, z how long it
## has grown, w its seed; `crack_dirs`: xy the way it runs) splintering out from the edge. Lit as
## dirty glass (GunPod.GLASS_LIGHT, HELMET_VISOR): no light from behind reaches it (the helmet stops
## it), and lights ahead glare through its grime.
const VISOR_SHADER := """
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never;
#define HELMET_VISOR
uniform vec3 tint : source_color = vec3(0.55, 0.68, 0.66);
uniform vec3 grime_color : source_color = vec3(0.2, 0.17, 0.12);
uniform vec4 edge = vec4(1.33, 0.73, -0.56, 0.0);
uniform vec2 corners = vec2(0.38, 0.3);
uniform float fog = 0.0;
uniform vec4 cracks[5];
uniform vec4 crack_dirs[5];
varying float glass_film;
varying float glass_alpha;

float hash2(vec2 p) {
	p = fract(p * vec2(0.3183099, 0.3678794) + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * (p.x + p.y));
}

float hash1(float n) {
	return fract(sin(n) * 43758.5453);
}

float vnoise(vec2 x) {
	vec2 i = floor(x);
	vec2 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), f.x), mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), f.x), f.y);
}

// Signed distance to the opening's rounded rectangle (negative inside).
float opening(vec2 p) {
	float top = p.y > (edge.y + edge.z) * 0.5 ? 1.0 : 0.0;
	float r = mix(corners.y, corners.x, top);
	vec2 c = vec2(0.0, (edge.y + edge.z) * 0.5);
	vec2 h = vec2(edge.x, (edge.y - edge.z) * 0.5);
	vec2 q = abs(p - c) - h + vec2(r);
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
}

// A crack from the edge of the glass: five splinters fanning out over it in straight runs with
// sharp kinks, each forking part of the way along, thinner towards their ends.
float crack(vec4 c, vec4 cd, vec2 p) {
	vec2 d = p - c.xy;
	float r = length(d);
	if (c.z <= 0.0 || r > c.z) {
		return 0.0;
	}
	vec2 fwd = normalize(cd.xy);
	vec2 side = vec2(-fwd.y, fwd.x);
	float a = atan(dot(d, side), dot(d, fwd));
	float k = c.w;
	float v = 0.0;
	for (int j = 0; j < 5; j++) {
		float fj = float(j);
		float aj = (fj / 4.0 - 0.5) * 1.9 + (hash1(k * 13.1 + fj) - 0.5) * 0.35;
		float len = c.z * (0.5 + 0.5 * hash1(k * 7.3 + fj * 1.7));
		float run = r * 4.5;
		float n0 = k * 7.1 + fj * 3.3 + floor(run);
		float kink = mix(hash1(n0), hash1(n0 + 1.0), fract(run)) - 0.5;
		float run2 = r * 18.0;
		float n2 = k * 3.9 + fj * 5.7 + floor(run2);
		float jag = mix(hash1(n2), hash1(n2 + 1.0), fract(run2)) - 0.5;
		float da = a - aj - (kink * 0.11 + jag * 0.03) * smoothstep(0.0, 0.2, r);
		float w = 0.0008 + 0.0018 * max(1.0 - r / len, 0.0);
		float dist = abs(da) * r;
		v = max(v, (1.0 - smoothstep(w, w + fwidth(dist) * 1.2, dist)) * step(r, len));
		float r0 = len * (0.25 + 0.35 * hash1(k * 5.1 + fj));
		float turn = hash1(k * 9.7 + fj) > 0.5 ? 0.55 : -0.55;
		float fork = abs(da - turn * max(r - r0, 0.0) / max(r, 0.0001)) * r;
		v = max(v, (1.0 - smoothstep(w * 0.8, w * 0.8 + fwidth(fork) * 1.2, fork)) * step(r0, r) * step(r, r0 + len * 0.45));
	}
	// Crazed glass where it starts.
	return max(v, (1.0 - smoothstep(0.012, 0.04, r)) * 0.8);
}

void fragment() {
	vec2 p = UV;
	float fres = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 4.0);
	float n = vnoise(p * 9.0) * 0.6 + vnoise(p * 31.0) * 0.4;
	// Grime round the edge (thicker in the corners) and along the bottom; a few light smudges.
	float rim = smoothstep(-0.26, 0.0, opening(p));
	float low = 1.0 - smoothstep(edge.z, edge.z + 0.3, p.y);
	float smudge = smoothstep(0.66, 0.9, vnoise(p * 4.0 + 7.0)) * 0.5;
	float grime = clamp(rim * (0.25 + 0.6 * n) + low * n * 0.35 + smudge * 0.25, 0.0, 1.0);
	float s = abs(fract(p.x * 11.0 - p.y * 3.0 + vnoise(p * 4.0) * 3.0) - 0.5);
	float scratch = (1.0 - smoothstep(0.0, 0.01, s)) * step(0.8, vnoise(p * 14.0 + 4.0));
	float misty = fog * (0.55 + 0.45 * vnoise(p * 6.0 + 3.0)) * (1.0 - 0.5 * smoothstep(0.0, 0.5, length(p - vec2(0.0, 0.1))));
	float cr = 0.0;
	for (int k = 0; k < 5; k++) {
		cr = max(cr, crack(cracks[k], crack_dirs[k], p));
	}
	ALBEDO = mix(mix(tint * 0.1, grime_color, grime), vec3(0.8, 0.82, 0.8), max(cr, misty * 0.6));
	ROUGHNESS = mix(mix(0.05, 0.7, grime), 0.35, cr);
	EMISSION = grime_color * grime * 0.05 + vec3(0.06) * cr + vec3(0.03) * misty;
	float a = clamp(0.01 + fres * 0.1 + grime * 0.26 + scratch * 0.1 + cr * 0.72 + misty * 0.18, 0.0, 0.92);
	ALPHA = a;
	glass_alpha = a;
	// (A faint film of dust all over; fog and crazed glass catch the light like the grime.)
	glass_film = clamp(0.06 + grime + misty * 0.7 + cr * 0.6 + scratch * 0.3, 0.0, 1.0);
}
"""

## The shell and its fittings: lit only by the light that shines in through the opening, in front
## of the eye; the shell stops light from behind and from the sides (so a crewmate's lamp behind you
## lights nothing in your helmet). `opening`: the opening's half width, its top and its bottom
## (tangent space) and a margin round it (the surfaces sit round its edge). Some of the light that
## gets in bounces round inside the helmet (BOUNCE), lighting it all over a little.
const LIT_SHADER := """
shader_type spatial;
uniform vec3 albedo : source_color = vec3(0.2);
uniform float metallic = 0.5;
uniform float roughness = 0.5;
uniform bool vertex_color = false;
uniform vec4 opening = vec4(1.4, 0.78, -0.6, 0.45);
const float BOUNCE = 0.18;

void fragment() {
	ALBEDO = vertex_color ? COLOR.rgb : albedo;
	METALLIC = metallic;
	ROUGHNESS = roughness;
}

// How much of a light gets into the helmet: what comes from ahead through the opening, with a soft
// edge round it.
float let_in(vec3 l) {
	float ahead = -l.z;
	if (ahead <= 0.0) {
		return 0.0;
	}
	vec2 t = l.xy / ahead;
	float m = opening.w;
	return (1.0 - smoothstep(opening.x, opening.x + m, abs(t.x)))
		* (1.0 - smoothstep(opening.y, opening.y + m, t.y))
		* (1.0 - smoothstep(-opening.z, -opening.z + m, -t.y))
		* smoothstep(0.0, 0.2, ahead);
}

void light() {
	float g = let_in(LIGHT);
	if (g > 0.0) {
		vec3 lc = LIGHT_COLOR * ATTENUATION * g;
		float nl = max(dot(NORMAL, LIGHT), 0.0);
		DIFFUSE_LIGHT += lc * (nl + BOUNCE) / PI;
		if (nl > 0.0) {
			float r2 = ROUGHNESS * ROUGHNESS;
			float a2 = r2 * r2;
			vec3 h = normalize(LIGHT + VIEW);
			float nh = max(dot(NORMAL, h), 0.0);
			float nv = max(dot(NORMAL, VIEW), 0.02);
			float dd = nh * nh * (a2 - 1.0) + 1.0;
			float d = a2 / (PI * dd * dd);
			float k = r2 * 0.5;
			float vis = 0.25 / ((nl * (1.0 - k) + k) * (nv * (1.0 - k) + k));
			vec3 f0 = mix(vec3(0.04), ALBEDO, METALLIC);
			vec3 f = f0 + (vec3(1.0) - f0) * pow(1.0 - clamp(dot(LIGHT, h), 0.0, 1.0), 5.0);
			SPECULAR_LIGHT += lc * SPECULAR_AMOUNT * d * vis * f * nl;
		}
	}
}
"""

## A heartbeat trace scrolling across the vitals display (`phase`: beats so far; `flatline`: none).
const ECG_SHADER := """
shader_type spatial;
render_mode unshaded, shadows_disabled;
instance uniform float phase = 0.0;
instance uniform float flatline = 0.0;
instance uniform vec3 ink = vec3(0.45, 1.35, 0.5);

float beat(float t) {
	float p = 0.1 * exp(-pow((t - 0.15) / 0.035, 2.0));
	float q = -0.12 * exp(-pow((t - 0.28) / 0.012, 2.0));
	float r = 1.0 * exp(-pow((t - 0.31) / 0.011, 2.0));
	float s = -0.28 * exp(-pow((t - 0.34) / 0.012, 2.0));
	float w = 0.22 * exp(-pow((t - 0.52) / 0.05, 2.0));
	return p + q + r + s + w;
}

void fragment() {
	float beats = 2.2;
	float x = UV.x * beats + phase;
	float y = (1.0 - UV.y) * 2.0 - 0.6;
	float v = beat(fract(x)) * (1.0 - flatline);
	float d = abs(y - v);
	float line = 1.0 - smoothstep(0.03, 0.03 + fwidth(y - v) * 2.0 + 0.05, d);
	float grid = step(0.94, fract(UV.x * 8.0)) * 0.08 + step(0.9, fract(UV.y * 3.0)) * 0.05;
	ALBEDO = ink * (line * (0.35 + 0.65 * UV.x) + grid * 0.4) + vec3(0.005, 0.02, 0.008);
}
"""

## The homing dial: a ring with ticks and a needle pointing the way (`bearing`, radians, clockwise
## from ahead); dark when there is nowhere to point (`active` 0).
const NEEDLE_SHADER := """
shader_type spatial;
render_mode unshaded, shadows_disabled;
instance uniform float bearing = 0.0;
instance uniform float active = 1.0;
instance uniform vec3 ink = vec3(0.45, 1.35, 0.5);

float seg(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	p.y = -p.y;
	float r = length(p);
	float a = atan(p.x, p.y);
	float tick = abs(fract(a / 1.5708 + 0.5) - 0.5) * 1.5708 * r;
	float ring = 1.0 - smoothstep(0.05, 0.05 + fwidth(r) * 1.5, abs(r - 0.86));
	float ticks = (1.0 - smoothstep(0.06, 0.06 + fwidth(tick) * 1.5, tick)) * step(0.62, r) * step(r, 0.86);
	vec2 nd = vec2(sin(bearing), cos(bearing));
	vec2 side = vec2(nd.y, -nd.x);
	vec2 tip = nd * 0.7;
	float needle = min(seg(p, -nd * 0.25, tip), min(seg(p, tip, tip - nd * 0.3 + side * 0.22), seg(p, tip, tip - nd * 0.3 - side * 0.22)));
	float nl = (1.0 - smoothstep(0.07, 0.07 + fwidth(needle) * 1.5, needle)) * active;
	vec3 col = ink * 0.45 * max(ring, ticks) + ink * 1.3 * nl;
	ALBEDO = col + vec3(0.005, 0.02, 0.008);
	ALPHA = 1.0 - smoothstep(0.96, 1.0, r);
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
"""

static var _shared: Dictionary = {}

## The crew member wearing it.
var crew: CrewMember
## 0 open .. 1 closed and sealed; whether it is meant to be closed.
var visor := 0.0
var sealed := false
## The opening's outline, the plates pressed into the shell (displays and vent), the shell's grid
## ([ring][point along the opening]) and the screens (see screens()).
var _ring := PackedVector2Array()
var _plates: Array = []
var _shell_grid: Array[PackedVector3Array] = []
var _screens: Array = []
## The status lamps' materials: "crit" and "seal".
var _lamps: Dictionary = {}
var _visor_node: Node3D
var _visor_mat: ShaderMaterial
var _fog := 0.0
var _crack_len: Array[float] = []
var _crack_step: Array[int] = []
var _cracks_on := 0
var _cracks_sent: Array[Vector4] = []
var _ecg: MeshInstance3D
var _ecg_phase := 0.0
var _needle: MeshInstance3D
var _bar: MeshInstance3D
var _texts: Dictionary = {}
var _beep_t := 0.0
var _clock := 0.0
var _last_hp := -1.0
var _hurt_t := 10.0


## Build the helmet for crew member `c` (its camera is the parent).
func build(c: CrewMember) -> void:
	crew = c
	_ring = outline()
	_plates = [_plate(VITALS_AT, DISPLAY_SIZE, -1.0), _plate(SUIT_AT, DISPLAY_SIZE, 1.0), _plate(VENT_AT, VENT_SIZE, 0.0)]
	_build_shell()
	_build_details()
	_build_visor()
	_build_vitals()
	_build_suit()
	for n in find_children("*", "VisualInstance3D", true, false):
		(n as VisualInstance3D).layers = Game.VIS_VIEWMODEL
		if n is GeometryInstance3D:
			(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# --- The opening and the shell -----------------------------------------------------------------

## The opening's sides (x at height y), top (y at x) and bottom (the V: y at x).
static func _side(y: float) -> float:
	return OPEN_SIDE - SIDE_BOW * pow((y - 0.1) / 0.62, 2.0)


static func _top(x: float) -> float:
	return OPEN_TOP - 0.02 * pow(x / 1.25, 2.0)


static func _bottom(x: float) -> float:
	return OPEN_BOTTOM + V_RISE * absf(x) / 1.2


## The opening's outline in tangent space, `n` points spaced evenly, anticlockwise from the bottom
## of the V: the V's two halves, the bowed sides and the nearly straight top, joined by rounded
## corners (quadratic curves through where the edges would meet).
static func outline(n := OUTLINE_POINTS) -> PackedVector2Array:
	var raw := PackedVector2Array()
	var k := 12
	var low := OPEN_BOTTOM + V_RISE
	for i in k:
		var x := 1.05 * float(i) / k
		raw.append(Vector2(x, _bottom(x)))
	_curve(raw, Vector2(1.05, _bottom(1.05)), Vector2(_side(low), low), Vector2(_side(-0.38), -0.38), k)
	for i in k:
		var y := lerpf(-0.38, 0.55, float(i) / k)
		raw.append(Vector2(_side(y), y))
	_curve(raw, Vector2(_side(0.55), 0.55), Vector2(_side(OPEN_TOP), OPEN_TOP), Vector2(1.1, _top(1.1)), k)
	for i in k * 2:
		var x := lerpf(1.1, -1.1, float(i) / (k * 2))
		raw.append(Vector2(x, _top(x)))
	_curve(raw, Vector2(-1.1, _top(-1.1)), Vector2(-_side(OPEN_TOP), OPEN_TOP), Vector2(-_side(0.55), 0.55), k)
	for i in k:
		var y := lerpf(0.55, -0.38, float(i) / k)
		raw.append(Vector2(-_side(y), y))
	_curve(raw, Vector2(-_side(-0.38), -0.38), Vector2(-_side(low), low), Vector2(-1.05, _bottom(-1.05)), k)
	for i in k:
		var x := lerpf(-1.05, 0.0, float(i) / k)
		raw.append(Vector2(x, _bottom(x)))
	return _resample(raw, n)


## A quadratic curve from `a` (included) towards `b` (left out) bent towards `ctrl`.
static func _curve(out: PackedVector2Array, a: Vector2, ctrl: Vector2, b: Vector2, steps: int) -> void:
	for i in steps:
		var t := float(i) / steps
		out.append(a.lerp(ctrl, t).lerp(ctrl.lerp(b, t), t))


## `n` points spaced evenly round a closed polygon, starting at its first point.
static func _resample(poly: PackedVector2Array, n: int) -> PackedVector2Array:
	var lengths := PackedFloat32Array([0.0])
	for i in poly.size():
		lengths.append(lengths[i] + poly[i].distance_to(poly[(i + 1) % poly.size()]))
	var total := lengths[lengths.size() - 1]
	var out := PackedVector2Array()
	var seg := 0
	for k in n:
		var want := total * float(k) / n
		while seg < poly.size() - 1 and lengths[seg + 1] < want:
			seg += 1
		var t := (want - lengths[seg]) / maxf(lengths[seg + 1] - lengths[seg], 0.00001)
		out.append(poly[seg].lerp(poly[(seg + 1) % poly.size()], t))
	return out


## A point `dist` from the eye in tangent-space direction t.
static func point(t: Vector2, dist: float) -> Vector3:
	return Vector3(t.x, t.y, -1.0).normalized() * dist


## A flat plate set into the shell at tangent-space point `at`, for a display (or the vent) `size`
## big. Its top edge runs along the V (side -1: its left half, 1: its right half, 0: level), its face
## square to the eye: {"frame" (+Z to the eye, x along the top edge, the origin on the plate's face),
## "size", "c" (the way to its middle), "dist" (the plate's plane, along c)}.
static func _plate(at: Vector2, size: Vector2, side: float) -> Dictionary:
	var c := Vector3(at.x, at.y, -1.0).normalized()
	var dist := PLATE_R + PLATE_INSET
	var along := Vector2(1.0, side * V_RISE / 1.2).normalized()
	var x := (_on_plane(at + along * 0.05, c, dist) - _on_plane(at - along * 0.05, c, dist)).normalized()
	var z := -c
	x = (x - z * x.dot(z)).normalized()
	return {"frame": Transform3D(Basis(x, z.cross(x), z), c * dist), "size": size, "c": c, "dist": dist}


## Where the ray through tangent-space point t meets a plate's plane.
static func _on_plane(t: Vector2, c: Vector3, dist: float) -> Vector3:
	var d := Vector3(t.x, t.y, -1.0).normalized()
	return d * (dist / d.dot(c))


## How far a plate pulls the shell in direction `d` onto its plane (0 .. 1), and that distance.
static func _plate_pull(pl: Dictionary, d: Vector3) -> Vector2:
	var cosang := d.dot(pl["c"] as Vector3)
	if cosang < 0.9:
		return Vector2.ZERO
	var t := float(pl["dist"]) / cosang
	var local := (pl["frame"] as Transform3D).affine_inverse() * (d * t)
	var size: Vector2 = pl["size"]
	var out := maxf(absf(local.x) - size.x * 0.5 - PLATE_MARGIN, absf(local.y) - size.y * 0.5 - PLATE_MARGIN)
	return Vector2(1.0 - smoothstep(0.0, PLATE_FALL, out), t)


## The shell's grooves: panel seams across it where it meets the opening at SEAMS_X (bottom) and
## SEAMS_Y (sides), and round it along SEAM_RING. How much deeper the shell is there (m).
static func _seam(o: Vector2, j: int) -> float:
	if j < 4:
		return 0.0
	var g := 0.0
	if o.y < -0.45:
		for sx: float in SEAMS_X:
			g = maxf(g, 1.0 - smoothstep(0.0, 0.03, absf(o.x - sx)))
	elif absf(o.x) > 1.2:
		for sy: float in SEAMS_Y:
			g = maxf(g, 1.0 - smoothstep(0.0, 0.03, absf(o.y - sy)))
	if j == SEAM_RING:
		g = 1.0
	return 0.0008 * g


## The shell: rings running out from the opening round MIDDLE (the rubber seal's bead, then the
## shell curving back round the head out of view), divided finely along the opening, with its
## panel seams, and pressed flat into a plate under each display and the vent. Its normals follow
## its shape (so the bead, the seams and the plates catch the light) and its colours are a little
## uneven (scuffs and grime).
func _build_shell() -> void:
	var n := _ring.size()
	var m := RINGS.size()
	var noise := FastNoiseLite.new()
	noise.seed = 77
	noise.frequency = 2.5
	var grid: Array[PackedVector3Array] = []
	var flat: Array[PackedFloat32Array] = []
	var grooves: Array[PackedFloat32Array] = []
	for j in m:
		var row := PackedVector3Array()
		var frow := PackedFloat32Array()
		var grow := PackedFloat32Array()
		for i in n:
			var t: Vector2 = MIDDLE + (_ring[i] - MIDDLE) * float(RINGS[j][0])
			var d := Vector3(t.x, t.y, -1.0).normalized()
			var groove := _seam(_ring[i], j)
			var r := float(RINGS[j][1]) + groove
			var pull := 0.0
			# The bead round the opening stays as it is; behind it the plates are pressed in.
			if j >= 4:
				for pl: Dictionary in _plates:
					var p := _plate_pull(pl, d)
					if p.x > 0.0:
						r = lerpf(r, p.y, p.x)
						pull = maxf(pull, p.x)
			row.append(d * r)
			frow.append(pull)
			grow.append(groove / 0.0008 * (1.0 - pull))
		grid.append(row)
		flat.append(frow)
		grooves.append(grow)
	var normals: Array[PackedVector3Array] = []
	for j in m:
		var nrow := PackedVector3Array()
		for i in n:
			var du := grid[j][(i + 1) % n] - grid[j][(i - 1 + n) % n]
			var dv := grid[mini(j + 1, m - 1)][i] - grid[maxi(j - 1, 0)][i]
			var nn := du.cross(dv).normalized()
			if nn.dot(-grid[j][i]) < 0.0:
				nn = -nn
			nrow.append(nn)
		normals.append(nrow)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in m - 1:
		for i in n:
			var i2 := (i + 1) % n
			for tri: Array in [[Vector2i(i, j), Vector2i(i2, j), Vector2i(i2, j + 1)], [Vector2i(i, j), Vector2i(i2, j + 1), Vector2i(i, j + 1)]]:
				var a := grid[(tri[0] as Vector2i).y][(tri[0] as Vector2i).x]
				var b := grid[(tri[1] as Vector2i).y][(tri[1] as Vector2i).x]
				var cc := grid[(tri[2] as Vector2i).y][(tri[2] as Vector2i).x]
				var order := [0, 1, 2]
				# Godot's front faces wind clockwise: the right-handed normal must point away from the eye.
				if (b - a).cross(cc - a).dot(a + b + cc) < 0.0:
					order = [0, 2, 1]
				for o: int in order:
					var at: Vector2i = tri[o]
					var v := grid[at.y][at.x]
					st.set_color(_shell_color(at.y, flat[at.y][at.x], grooves[at.y][at.x], noise.get_noise_3dv(v * 40.0)))
					st.set_normal(normals[at.y][at.x])
					st.add_vertex(v)
	var mi := MeshInstance3D.new()
	mi.name = "Shell"
	mi.mesh = st.commit()
	mi.material_override = _lit(Color.WHITE, 0.55, 0.5, true)
	add_child(mi)
	_shell_grid = grid


## The colour of the shell at ring j: the rubber seal, the steel (scuffed by `n`, darker in the
## seams) and the painted plates under the displays.
static func _shell_color(j: int, plate: float, groove: float, n: float) -> Color:
	var g := 0.85 + 0.3 * n
	var col := Color(0.095, 0.1, 0.095) * g
	if j <= 2:
		col = Color(0.016, 0.016, 0.016) * (0.9 + 0.2 * n)
	elif j == 3:
		col = Color(0.035, 0.035, 0.034)
	elif j == 4:
		col = Color(0.07, 0.072, 0.068) * g
	col = col.lerp(Color(0.05, 0.056, 0.058), plate)
	col = col.lerp(col * 0.45, clampf(groove, 0.0, 1.0))
	return Color(col.r, col.g, col.b * 0.97)


## The shell's surface at tangent-space point t, and its normal there (towards the eye): found from
## the shell's grid (ring and point along the opening nearest t).
func _surface(t: Vector2) -> Array:
	var best := Vector2i.ZERO
	var best_d := INF
	var dir := Vector3(t.x, t.y, -1.0).normalized()
	for j in _shell_grid.size():
		var row: PackedVector3Array = _shell_grid[j]
		for i in row.size():
			var dd := row[i].normalized().distance_squared_to(dir)
			if dd < best_d:
				best_d = dd
				best = Vector2i(i, j)
	var r := _shell_grid[best.y][best.x].length()
	return [dir * r, -dir]


## A frame on the shell at tangent-space point t, `lift` in front of it: +Z towards the eye, x along
## `along` (tangent space) as seen from the eye.
func _frame_at(t: Vector2, along: Vector2, lift: float) -> Transform3D:
	var s: Array = _surface(t)
	var p: Vector3 = s[0]
	var z: Vector3 = s[1]
	var x := (point(t + along.normalized() * 0.03, 1.0) - point(t - along.normalized() * 0.03, 1.0))
	x = (x - z * x.dot(z)).normalized()
	return Transform3D(Basis(x, z.cross(x), z), p + z * lift)


func _part(mesh: Mesh, xform: Transform3D, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.transform = xform
	add_child(mi)
	return mi


static func _box_mesh(size: Vector3) -> BoxMesh:
	var bm := BoxMesh.new()
	bm.size = size
	return bm


static func _cyl_mesh(r: float, h: float, sides := 8) -> CylinderMesh:
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = sides
	cm.rings = 1
	return cm


## The shell's fittings: rivets round the opening, the visor's hinges at the top corners, the
## breathing vent's slats under the V, ribbed hoses running round the lower corners, and the two
## status lamps (CRIT by VITALS, SEAL by SUIT).
func _build_details() -> void:
	var steel := _lit(Color(0.22, 0.225, 0.22), 0.8, 0.35)
	var dark := _lit(Color(0.05, 0.052, 0.05), 0.5, 0.6)
	var rubber := _lit(Color(0.03, 0.03, 0.03), 0.1, 0.9)
	# Rivets along the shell just out from the seal, not on the plates.
	var rivet := _cyl_mesh(0.00105, 0.0008, 6)
	for i in range(3, _ring.size(), 8):
		var t: Vector2 = MIDDLE + (_ring[i] - MIDDLE) * 1.085
		var d := Vector3(t.x, t.y, -1.0).normalized()
		var on_plate := false
		for pl: Dictionary in _plates:
			on_plate = on_plate or _plate_pull(pl, d).x > 0.0
		if on_plate:
			continue
		var f := _frame_at(t, Vector2(1, 0), 0.0003)
		_part(rivet, Transform3D(f.basis * Basis(Vector3.RIGHT, PI / 2.0), f.origin), steel)
	# The visor's hinges, a barrel and a bracket at each top corner.
	for side: float in [-1.0, 1.0]:
		var t := Vector2(side * 1.4, 0.75)
		var f := _frame_at(t, Vector2(-0.6 * side, 1.0), 0.002)
		_part(_cyl_mesh(0.0032, 0.012, 10), Transform3D(f.basis, f.origin), steel)
		_part(_box_mesh(Vector3(0.007, 0.004, 0.003)), f * Transform3D(Basis.IDENTITY, Vector3(0.006 * -side, -0.003, -0.0008)), dark)
		for e: float in [-1.0, 1.0]:
			_part(_cyl_mesh(0.0036, 0.0016, 10), f * Transform3D(Basis.IDENTITY, Vector3(0, e * 0.0062, 0)), dark)
	# The breathing vent: slats across its plate, and two screws.
	var vent: Dictionary = _plates[2]
	var vf: Transform3D = vent["frame"]
	_part(_box_mesh(Vector3(VENT_SIZE.x, VENT_SIZE.y, 0.0006)), vf * Transform3D(Basis.IDENTITY, Vector3(0, 0, -0.0002)), _lit(Color(0.01, 0.01, 0.01), 0.2, 0.9))
	# (Dark, worn slats: bright steel caught the room's lights.)
	var slat := _lit(Color(0.075, 0.078, 0.076), 0.6, 0.55)
	for k in 5:
		var y := lerpf(-VENT_SIZE.y * 0.4, VENT_SIZE.y * 0.4, float(k) / 4.0)
		_part(_box_mesh(Vector3(VENT_SIZE.x - 0.002, 0.0011, 0.0016)), vf * Transform3D(Basis(Vector3.RIGHT, -0.5), Vector3(0, y, 0.0008)), slat)
	for e: float in [-1.0, 1.0]:
		_part(_cyl_mesh(0.0009, 0.0007, 6), vf * Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(e * (VENT_SIZE.x * 0.5 + 0.0024), 0, 0.0004)), steel)
	# Ribbed hoses round the lower corners, each from under the instruments out of view.
	for side: float in [-1.0, 1.0]:
		var a := Vector2(side * 1.02, -0.72)
		var b := Vector2(side * 1.43, -0.5)
		var count := 14
		for k in count:
			var u := float(k) / (count - 1)
			var t := a.lerp(b, u) + Vector2(0, -0.05 * sin(u * PI))
			var f := _frame_at(t, b - a, 0.0032)
			_part(_cyl_mesh(0.0027 if k % 2 == 0 else 0.0024, 0.0042, 10), Transform3D(f.basis * Basis(Vector3.BACK, PI / 2.0), f.origin), rubber)
		for t: Vector2 in [a, b]:
			var f := _frame_at(t, b - a, 0.0032)
			_part(_cyl_mesh(0.0034, 0.0035, 10), Transform3D(f.basis * Basis(Vector3.BACK, PI / 2.0), f.origin), steel)
	# The status lamps, each in its bezel.
	for lamp: Array in [["crit", Vector2(-0.33, -0.69), Color(1.0, 0.15, 0.08)], ["seal", Vector2(0.33, -0.69), Color(0.35, 1.0, 0.4)]]:
		var f := _frame_at(lamp[1], Vector2(1, 0), 0.0004)
		_part(_cyl_mesh(0.0026, 0.0012, 12), Transform3D(f.basis * Basis(Vector3.RIGHT, PI / 2.0), f.origin), steel)
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.06, 0.05, 0.05)
		m.emission_enabled = true
		m.emission = lamp[2]
		m.emission_energy_multiplier = 0.0
		var bulb := _part(_sphere_mesh(0.0017), f * Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.0008)), m)
		bulb.name = "Lamp_" + str(lamp[0])
		_lamps[lamp[0]] = m


static func _sphere_mesh(r: float) -> SphereMesh:
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 10
	sm.rings = 5
	return sm


## The visor: a sheet of glass on a sphere round the eye, covering the opening and a bit beyond, on
## a pivot through the eye so it slides up into the shell to open.
func _build_visor() -> void:
	_visor_node = Node3D.new()
	_visor_node.name = "Visor"
	add_child(_visor_node)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nx := 40
	var ny := 22
	var x0 := -OPEN_SIDE - 0.2
	var x1 := OPEN_SIDE + 0.2
	var y0 := OPEN_BOTTOM - 0.16
	var y1 := OPEN_TOP + 0.18
	for j in ny:
		for i in nx:
			var q: Array[Vector2] = []
			for c: Vector2i in [Vector2i(i, j), Vector2i(i + 1, j), Vector2i(i + 1, j + 1), Vector2i(i, j + 1)]:
				q.append(Vector2(lerpf(x0, x1, float(c.x) / nx), lerpf(y0, y1, float(c.y) / ny)))
			for tri: Array in [[q[0], q[1], q[2]], [q[0], q[2], q[3]]]:
				var vs: Array[Vector3] = [point(tri[0], R_VISOR), point(tri[1], R_VISOR), point(tri[2], R_VISOR)]
				var order := [0, 1, 2]
				if (vs[1] - vs[0]).cross(vs[2] - vs[0]).dot(vs[0] + vs[1] + vs[2]) < 0.0:
					order = [0, 2, 1]
				for k: int in order:
					st.set_uv(tri[k])
					st.set_normal(-vs[k].normalized())
					st.add_vertex(vs[k])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	_visor_mat = ShaderMaterial.new()
	_visor_mat.shader = _shader("visor", VISOR_SHADER + GunPod.GLASS_LIGHT)
	# The grime follows a rounded rectangle close to the opening.
	_visor_mat.set_shader_parameter("edge", Vector4(OPEN_SIDE - 0.02, OPEN_TOP, OPEN_BOTTOM + V_RISE * 0.5, 0.0))
	_visor_mat.set_shader_parameter("corners", Vector2(0.26, 0.22))
	var dirs: Array[Vector4] = []
	for k in CRACKS.size():
		var d: Vector2 = (CRACKS[k][1] as Vector2).normalized()
		dirs.append(Vector4(d.x, d.y, 0.0, 0.0))
		_crack_len.append(0.0)
		_crack_step.append(0)
	_visor_mat.set_shader_parameter("crack_dirs", dirs)
	_send_cracks()
	mi.material_override = _visor_mat
	_visor_node.add_child(mi)
	_visor_node.rotation.x = OPEN_ANGLE


## A display on plate `pl`: the green screen just in front of the plate, a narrow bezel standing up
## round it to the shell's face, and a screw in each corner. Returns the screen's frame (for its
## text and gauges). Everything on the screen carries the "screen" meta (see screens()).
func _display(pl: Dictionary) -> Transform3D:
	var f: Transform3D = pl["frame"]
	var size: Vector2 = pl["size"]
	var screen_f := f * Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.0004))
	var screen := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	screen.mesh = q
	screen.material_override = GunPod.crt_material()
	screen.transform = screen_f
	screen.set_meta("screen", true)
	add_child(screen)
	var bezel := _lit(Color(0.075, 0.078, 0.076), 0.6, 0.45)
	var b := 0.0022
	var depth := PLATE_INSET + 0.0008
	for piece: Array in [[Vector3(0, size.y * 0.5 + b * 0.5, depth * 0.5), Vector3(size.x + b * 2.0, b, depth)],
			[Vector3(0, -size.y * 0.5 - b * 0.5, depth * 0.5), Vector3(size.x + b * 2.0, b, depth)],
			[Vector3(-size.x * 0.5 - b * 0.5, 0, depth * 0.5), Vector3(b, size.y, depth)],
			[Vector3(size.x * 0.5 + b * 0.5, 0, depth * 0.5), Vector3(b, size.y, depth)]]:
		_part(_box_mesh(piece[1]), f * Transform3D(Basis.IDENTITY, piece[0]), bezel)
	var screw := _lit(Color(0.42, 0.42, 0.4), 0.85, 0.35)
	for x: float in [-1.0, 1.0]:
		for y: float in [-1.0, 1.0]:
			_part(_cyl_mesh(0.0008, 0.0005, 6), f * Transform3D(Basis(Vector3.RIGHT, PI / 2.0),
				Vector3(x * (size.x * 0.5 + b * 0.5), y * (size.y * 0.5 + b * 0.5), depth + 0.0002)), screw)
	_screens.append({"frame": screen_f, "size": size})
	return screen_f


## The screens set into the helmet: [{"frame" (in the helmet's frame, +Z to the eye), "size"}]; the
## tests check nothing else in the helmet hides any of them.
func screens() -> Array:
	return _screens


func _label(f: Transform3D, pos: Vector3, text: String, height: float, anchor: float) -> Label3D:
	var size := 40 if height > 0.004 else 26
	var l := Label3D.new()
	l.font = GunPod.mono_font()
	l.font_size = size
	l.pixel_size = height / float(size)
	l.outline_size = 0
	l.modulate = GREEN
	l.double_sided = false
	# Drawn after the visor's glass (which is further from the eye).
	l.render_priority = 2
	l.set_meta("anchor", anchor)
	l.set_meta("screen", true)
	l.transform = f * Transform3D(Basis.IDENTITY, pos + Vector3(0, 0, 0.0004))
	add_child(l)
	CrewWeapons.set_text(l, text)
	return l


func _build_vitals() -> void:
	var f := _display(_plates[0])
	var w := DISPLAY_SIZE.x * 0.5
	var h := DISPLAY_SIZE.y * 0.5
	_texts["vit_cap"] = _label(f, Vector3(-w + 0.0012, h - 0.0023, 0), "VITALS", 0.0025, -1.0)
	_texts["hp"] = _label(f, Vector3(w - 0.0012, 0.0016, 0), "100", 0.0068, 1.0)
	_ecg = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.019, 0.0068)
	_ecg.mesh = q
	var m := ShaderMaterial.new()
	m.shader = _shader("ecg", ECG_SHADER)
	_ecg.material_override = m
	_ecg.transform = f * Transform3D(Basis.IDENTITY, Vector3(-0.0058, 0.0004, 0.0003))
	_ecg.set_meta("screen", true)
	add_child(_ecg)
	_bar = Cockpit.bar_mesh(Vector2(DISPLAY_SIZE.x - 0.003, 0.0026), 20, false, CRITICAL, 2.0)
	_bar.transform = f * Transform3D(Basis.IDENTITY, Vector3(0, -h + 0.0024, 0.0003))
	_bar.set_meta("screen", true)
	add_child(_bar)


func _build_suit() -> void:
	var f := _display(_plates[1])
	var w := DISPLAY_SIZE.x * 0.5
	var h := DISPLAY_SIZE.y * 0.5
	_texts["suit_cap"] = _label(f, Vector3(-w + 0.0012, h - 0.0023, 0), "SUIT", 0.0025, -1.0)
	_texts["seal"] = _label(f, Vector3(w - 0.0012, h - 0.0023, 0), "OPEN", 0.0025, 1.0)
	_needle = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.0088, 0.0088)
	_needle.mesh = q
	var m := ShaderMaterial.new()
	m.shader = _shader("needle", NEEDLE_SHADER)
	_needle.material_override = m
	_needle.transform = f * Transform3D(Basis.IDENTITY, Vector3(-w + 0.0057, -0.0022, 0.0003))
	_needle.set_meta("screen", true)
	add_child(_needle)
	_texts["ship"] = _label(f, Vector3(-w + 0.0112, -0.0006, 0), "", 0.0034, -1.0)
	_texts["lamp"] = _label(f, Vector3(-w + 0.0112, -0.0054, 0), "", 0.0025, -1.0)


static func _shader(key: String, code: String) -> Shader:
	if not _shared.has(key):
		var sh := Shader.new()
		sh.code = code
		_shared[key] = sh
	return _shared[key]


## A material for the shell and its fittings (LIT_SHADER: lit only through the opening), shared per
## look; `vertex_color` takes the colour from the mesh instead (the shell).
static func _lit(color: Color, metallic: float, roughness: float, vertex_color := false) -> ShaderMaterial:
	var key := "lit%s|%.2f|%.2f|%s" % [color.to_html(), metallic, roughness, vertex_color]
	if not _shared.has(key):
		var m := ShaderMaterial.new()
		m.shader = _shader("lit", LIT_SHADER)
		m.set_shader_parameter("albedo", color)
		m.set_shader_parameter("metallic", metallic)
		m.set_shader_parameter("roughness", roughness)
		m.set_shader_parameter("vertex_color", vertex_color)
		m.set_shader_parameter("opening", Vector4(OPEN_SIDE, OPEN_TOP, OPEN_BOTTOM, 0.45))
		_shared[key] = m
	return _shared[key]


# --- Per frame ---------------------------------------------------------------------------------

## Follow the crew member: the visor, the cracks and the instruments. `shown`: the helmet is in view
## (walking); its sounds only play then.
func update(delta: float, shown: bool) -> void:
	if crew == null or crew.ship == null or not is_instance_valid(crew.ship):
		return
	_clock += delta
	var ship := crew.ship
	sealed = not ship.is_aboard(crew.position) and crew.alive
	_update_visor(delta, shown)
	_update_cracks(delta, shown)
	if not shown:
		return
	_update_vitals(delta)
	_update_suit(ship)


## The visor swings down and seals outside the ship, and opens back aboard, with the whine of its
## motor, the hiss of the seal, and a moment of fog on the glass.
func _update_visor(delta: float, shown: bool) -> void:
	var want := 1.0 if sealed else 0.0
	if want != visor and shown:
		if visor == 0.0 and want > 0.0:
			Sfx.play("visor_servo", null, -14.0, 1.0)
		elif visor == 1.0 and want < 1.0:
			Sfx.play("visor_unseal", null, -12.0)
			Sfx.play("visor_servo", null, -15.0, 1.15)
	var was := visor
	visor = move_toward(visor, want, delta / VISOR_TIME)
	if was < 1.0 and visor >= 1.0:
		_fog = 1.0
		if shown:
			Sfx.play("visor_seal", null, -11.0)
			Sfx.play("clunk", null, -20.0, 1.8)
	_visor_node.rotation.x = OPEN_ANGLE * (1.0 - smoothstep(0.0, 1.0, visor))
	_visor_node.visible = visor > 0.0
	_fog = maxf(0.0, _fog - delta * 0.55)
	_visor_mat.set_shader_parameter("fog", _fog * _fog)


## Health down to half (CRACK_START) cracks the visor from its edges, further as the health drops;
## it seals over once the health has recovered. The suit beeps while the health is critical.
func _update_cracks(delta: float, shown: bool) -> void:
	var frac := clampf(crew.hp / maxf(crew.max_hp, 0.001), 0.0, 1.0) if crew.alive else 0.0
	if frac > CRACK_START + HEAL_MARGIN or not crew.alive:
		if _cracks_on > 0 and crew.alive and shown:
			Sfx.play("visor_seal", null, -14.0, 1.25)
		for k in _crack_len.size():
			_crack_len[k] = 0.0
			_crack_step[k] = 0
		_cracks_on = 0
	else:
		var on := 0
		for k in CRACKS.size():
			if frac >= float(CRACK_AT[k]):
				continue
			on += 1
			var full := float(CRACKS[k][2])
			var want := full * (0.3 + 0.7 * clampf((float(CRACK_AT[k]) - frac) / CRACK_GROW, 0.0, 1.0))
			# Cracks only ever spread (until the visor seals over).
			if want > _crack_len[k]:
				_crack_len[k] = move_toward(_crack_len[k], want, delta * 1.5)
			var step := int(_crack_len[k] / full * 4.0)
			if shown and step > _crack_step[k] and step > 1:
				Sfx.play("glass_crack", null, -15.0, randf_range(1.3, 1.5))
			_crack_step[k] = step
		if on > _cracks_on and shown:
			Sfx.play("glass_crack", null, -5.0, randf_range(1.05, 1.2))
		_cracks_on = maxi(on, _cracks_on)
	_send_cracks()
	if shown and crew.alive and frac < CRITICAL:
		_beep_t -= delta
		if _beep_t <= 0.0:
			_beep_t = 1.4
			Sfx.play("lock_beep", null, -16.0, 0.75)
	else:
		_beep_t = 0.0


func _send_cracks() -> void:
	var data: Array[Vector4] = []
	for k in CRACKS.size():
		var at: Vector2 = CRACKS[k][0]
		data.append(Vector4(at.x, at.y, _crack_len[k] if k < _crack_len.size() else 0.0, float(k) + 1.0))
	if data != _cracks_sent:
		_cracks_sent = data
		_visor_mat.set_shader_parameter("cracks", data)


## How many cracks are in the visor (for the tests).
func cracks() -> int:
	var n := 0
	for l in _crack_len:
		if l > 0.0:
			n += 1
	return n


## VITALS: the health figure and bar (amber below half, red and flashing when critical) and the
## heartbeat: faster the lower the health (and for a while after a hit), flat once knocked out.
func _update_vitals(delta: float) -> void:
	var frac := clampf(crew.hp / maxf(crew.max_hp, 0.001), 0.0, 1.0)
	if _last_hp >= 0.0 and crew.hp < _last_hp - 0.01:
		_hurt_t = 0.0
	_last_hp = crew.hp
	_hurt_t += delta
	var crit := crew.alive and frac < CRITICAL
	var blink := fmod(_clock, 0.5) < 0.25
	var col := GREEN if frac >= 0.5 else (AMBER if not crit else RED)
	var hp_l: Label3D = _texts["hp"]
	CrewWeapons.set_text(hp_l, "%d" % int(ceil(maxf(crew.hp, 0.0))) if crew.alive else "---")
	hp_l.modulate = col * (0.35 if crit and not blink else 1.0)
	_bar.set_instance_shader_parameter("value", frac if crew.alive else 0.0)
	_bar.set_instance_shader_parameter("blink", 0.4 if crit and not blink else 1.0)
	var bpm := lerpf(135.0, 72.0, smoothstep(0.15, 1.0, frac)) + (22.0 if _hurt_t < 4.0 else 0.0)
	_ecg_phase += delta * bpm / 60.0
	_ecg.set_instance_shader_parameter("phase", fposmod(_ecg_phase, 1000.0))
	_ecg.set_instance_shader_parameter("flatline", 0.0 if crew.alive else 1.0)
	_ecg.set_instance_shader_parameter("ink", Vector3(col.r, col.g, col.b))
	(_lamps["crit"] as StandardMaterial3D).emission_energy_multiplier = (3.5 if blink else 0.4) if crit else 0.0


## SUIT: the visor's seal; out of the ship, the homing needle and the distance back to its cargo
## door, and the flashlight.
func _update_suit(ship: Mothership) -> void:
	var seal: Label3D = _texts["seal"]
	var lamp_m: StandardMaterial3D = _lamps["seal"]
	if visor >= 1.0:
		CrewWeapons.set_text(seal, "SEALED" if _cracks_on == 0 else "BREACH")
		seal.modulate = GREEN if _cracks_on == 0 else RED
		lamp_m.emission = Color(0.35, 1.0, 0.4) if _cracks_on == 0 else Color(1.0, 0.15, 0.08)
		lamp_m.emission_energy_multiplier = 2.5
	elif visor > 0.0:
		CrewWeapons.set_text(seal, "SEALING" if sealed else "VENTING")
		seal.modulate = AMBER
		lamp_m.emission = Color(1.0, 0.65, 0.15)
		lamp_m.emission_energy_multiplier = 2.5 if fmod(_clock, 0.3) < 0.15 else 0.5
	else:
		CrewWeapons.set_text(seal, "OPEN")
		seal.modulate = GREEN * 0.8
		lamp_m.emission_energy_multiplier = 0.0
	var ship_l: Label3D = _texts["ship"]
	var lamp: Label3D = _texts["lamp"]
	if ship.is_aboard(crew.position):
		CrewWeapons.set_text(ship_l, "ABOARD")
		CrewWeapons.set_text(lamp, "SHIP AIR")
		_needle.set_instance_shader_parameter("active", 0.0)
	else:
		var to := SHIP_DOOR - (crew.position + Vector3.UP * CrewMember.EYE)
		var fwd := Vector2(-sin(crew.look_yaw), -cos(crew.look_yaw))
		var right := Vector2(cos(crew.look_yaw), -sin(crew.look_yaw))
		var flat := Vector2(to.x, to.z)
		_needle.set_instance_shader_parameter("bearing", atan2(flat.dot(right), flat.dot(fwd)))
		_needle.set_instance_shader_parameter("active", 1.0)
		CrewWeapons.set_text(ship_l, "SHIP %d M" % int(round(to.length())))
		CrewWeapons.set_text(lamp, "LAMP ON" if crew.lamp_on() else "LAMP OFF")
