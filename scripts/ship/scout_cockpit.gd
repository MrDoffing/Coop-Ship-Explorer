class_name ScoutCockpit
extends Node3D
## The scout's cockpit: a seat for one under a bubble canopy of grimy glass held by bolted steel
## straps, built low into the fuselage so the deck is at the pilot's shoulders and the glass wraps
## round and over them, and the instruments close at hand, everything shown in the world:
## - The reflector gunsight on the front panel: its glowing ring marks where both cannons' rounds
##   converge, dead ahead.
## - Under it, on the front panel, the heat gauge (green, amber, red; it flashes while the cannons
##   and the booster are cut out) and four lamps: HULL (critical), HEAT, RELOAD and LOCK.
## - The panel on the left: thrust (the speed, with the booster's zone beyond the top speed), hull
##   integrity and the fuel cargo, each a bar with its figures.
## - The panel on the right: the cannons' magazine (rounds left on a green screen, and a bar), the
##   missiles (a drawing of the scout with two missiles under each wing: green when loaded, red when
##   fired) and the homing needle that points to the scout's dock on the mothership, with the
##   distance.
## - On the canopy glass: the targeting crosshair, which closes in on the alien held in the sight
##   until it is locked on, and the dock's marker while the dock is in view.
## - Cracks run out over the canopy from the edges of the glass, beside its straps, once the hull
##   takes heavy damage (CRACKS, CRACK_AT), and grow longer with every hit; once the hull is
##   critical (Scout.HULL_CRITICAL) the alarm sounds and the red lights pulse, bathing the cockpit
##   red.
##
## Built in the scout's frame (-Z forward): the canopy and furniture with the model (build_shell,
## also for the homebase display), the instruments only on a scout in a mission (build). Everyone
## sees the instruments through the glass; the targeting, the alarm and the view's shake are the
## local pilot's.

## The pilot's eye (the first-person camera), and the field of view (degrees) at the top speed and
## at full boost: the view widens as the booster drives the scout past its top speed.
const EYE := Vector3(0, 0.45, -0.55)
const FOV := 80.0
const FOV_BOOST := 100.0
## The fuselage's deck under the canopy.
const DECK_Y := 0.06
## The canopy: [z, sill height, half width at the sill, top] front to back. Across, each is half an
## ellipse from sill to sill over the top. The glass ends at GLASS_TO; behind it a fairing of the
## same shape closes it off down to the spine.
const CANOPY := [
	[-1.62, 0.04, 0.4, 0.05],
	[-1.4, 0.05, 0.47, 0.38],
	[-1.15, 0.06, 0.52, 0.6],
	[-0.85, 0.06, 0.55, 0.72],
	[-0.5, 0.06, 0.56, 0.78],
	[-0.15, 0.06, 0.55, 0.77],
	[0.1, 0.065, 0.54, 0.73],
	[0.45, 0.09, 0.48, 0.6],
	[0.75, 0.12, 0.4, 0.42],
	[1.0, 0.16, 0.3, 0.22],
]
const GLASS_TO := 0.1
## The frame's two pillars run along the canopy this far round from the sill (radians; PI / 2 is
## the top), framing the windscreen.
const PILLAR_T := 0.9
## The cracks, each running out over the glass from its edge beside one of the canopy's straps (the
## windscreen's pillars and its foot, the sills): [z, t] where it starts (see canopy_point, just
## clear of the strap), the way it runs ([along the canopy, round it]) and how long it grows (m).
## Crack k starts once the hull is below CRACK_AT[k] of full, a quarter of its length, and grows
## with the damage to its full length CRACK_GROW of the hull further down: the more the scout is
## hit, the further the glass cracks.
const CRACKS := [
	[-1.3, PILLAR_T + 0.05, 0.0, 1.0, 0.26],
	[-1.57, PI * 0.5 + 0.35, 1.0, 0.0, 0.24],
	[-1.05, PI - PILLAR_T - 0.05, 0.0, -1.0, 0.3],
	[-1.3, PI - PILLAR_T + 0.05, 0.0, 1.0, 0.22],
	[-0.9, PILLAR_T + 0.05, 0.4, 1.0, 0.28],
	[-1.57, PI * 0.5 - 0.45, 1.0, 0.0, 0.22],
	[-1.2, PI - 0.11, 0.0, -1.0, 0.24],
	[-0.95, 0.11, 0.0, 1.0, 0.24],
]
const CRACK_AT := [0.85, 0.75, 0.66, 0.57, 0.48, 0.39, 0.3, 0.2]
const CRACK_GROW := 0.3
## The instrument panels either side (their middles, 35 degrees out and 17 down from the eye, so
## they stay whole in view; they face the eye) and the front panel's fascia under the gunsight.
## SIGHT is the middle of the gunsight's glass, on the eye's line.
const PANEL_L := Vector3(-0.329, 0.275, -1.02)
const PANEL_R := Vector3(0.329, 0.275, -1.02)
const PANEL_SIZE := Vector2(0.28, 0.2)
const FASCIA := Vector3(0, 0.135, -1.11)
const FASCIA_SIZE := Vector2(0.42, 0.15)
const SIGHT := Vector3(0, 0.45, -0.91)
## Markers on the glass sit this share of the way out from the eye to it.
const GLASS_INSET := 0.97

const GREEN := Color(0.45, 1.35, 0.5)
const AMBER := Color(1.3, 0.85, 0.25)
const RED := Color(1.4, 0.35, 0.22)
const STENCIL := Color(0.85, 0.82, 0.7)
## The lamps under the gunsight, left to right: id, caption, colour.
const LAMPS := [["hull", "HULL", Color(1.0, 0.18, 0.1)], ["heat", "HEAT", Color(1.0, 0.3, 0.1)],
	["load", "RELOAD", Color(1.0, 0.65, 0.15)], ["lock", "LOCK", Color(0.35, 1.0, 0.4)]]

## The canopy's glass: greasy (blotchy smears, arcs wiped across it with a rag, runs down it and
## grime gathered along the sills; light enough to catch the cockpit's lamp, with a faint haze of
## its own so it shows against the dark), a few scratches, and the cracks (`cracks`: xyz where each
## starts, w how long it has grown, 0 for none; `crack_dirs`: xyz the way it runs over the glass,
## w its seed): splinters fanning out from the edge of the glass, wavering and forking as they run.
## Lit as dirty glass (GunPod.GLASS_LIGHT): lamps glint softly in it and glare through the grease.
const GLASS_SHADER := """
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never;
uniform vec3 tint : source_color = vec3(0.55, 0.7, 0.68);
uniform vec3 grease_color : source_color = vec3(0.36, 0.32, 0.25);
uniform float grime_lo = 0.0;
uniform float grime_hi = 0.3;
uniform vec4 cracks[8];
uniform vec4 crack_dirs[8];
varying vec3 lp;
varying vec3 ln;
varying float glass_film;
varying float glass_alpha;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float hash1(float n) {
	return fract(sin(n) * 43758.5453);
}

float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x),
			mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
			mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

// A crack running out from the edge of the glass (c: where it starts, how long it has grown; cd: the
// way it runs, its seed): five splinters fanning out over the glass (never back under the strap
// beside it) in straight runs with sharp kinks between them, as glass breaks, each forking part
// of the way along, thinner towards their ends.
float crack(vec4 c, vec4 cd, vec3 p, vec3 nrm) {
	vec3 d = p - c.xyz;
	float r = length(d);
	if (c.w <= 0.0 || r > c.w) {
		return 0.0;
	}
	vec3 fwd = normalize(cd.xyz - nrm * dot(cd.xyz, nrm));
	vec3 side = cross(nrm, fwd);
	float a = atan(dot(d, side), dot(d, fwd));
	float k = cd.w;
	float v = 0.0;
	for (int j = 0; j < 5; j++) {
		float fj = float(j);
		float aj = (fj / 4.0 - 0.5) * 1.9 + (hash1(k * 13.1 + fj) - 0.5) * 0.35;
		float len = c.w * (0.5 + 0.5 * hash1(k * 7.3 + fj * 1.7));
		float run = r * 28.0;
		float n0 = k * 7.1 + fj * 3.3 + floor(run);
		float kink = mix(hash1(n0), hash1(n0 + 1.0), fract(run)) - 0.5;
		float run2 = r * 110.0;
		float n2 = k * 3.9 + fj * 5.7 + floor(run2);
		float jag = mix(hash1(n2), hash1(n2 + 1.0), fract(run2)) - 0.5;
		float da = a - aj - (kink * 0.11 + jag * 0.03) * smoothstep(0.0, 0.03, r);
		float w = 0.0003 + 0.0007 * max(1.0 - r / len, 0.0);
		float dist = abs(da) * r;
		v = max(v, (1.0 - smoothstep(w, w + fwidth(dist) * 1.2, dist)) * step(r, len));
		float r0 = len * (0.25 + 0.35 * hash1(k * 5.1 + fj));
		float turn = hash1(k * 9.7 + fj) > 0.5 ? 0.55 : -0.55;
		float fork = abs(da - turn * max(r - r0, 0.0) / max(r, 0.0001)) * r;
		v = max(v, (1.0 - smoothstep(w * 0.8, w * 0.8 + fwidth(fork) * 1.2, fork)) * step(r0, r) * step(r, r0 + len * 0.45));
	}
	// Crazed glass where it starts.
	return max(v, (1.0 - smoothstep(0.002, 0.006, r)) * 0.8);
}

void vertex() {
	lp = VERTEX;
	ln = NORMAL;
}

void fragment() {
	float fres = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 4.0);
	// Grease: blotchy smears, arcs wiped across the glass with a rag, runs down it, and grime
	// gathered low down along the sills.
	float n = vnoise(lp * 7.0) * 0.6 + vnoise(lp * 23.0) * 0.4;
	float blotch = smoothstep(0.5, 0.8, n);
	// The rag's strokes: uneven swaths (some strokes missed), each streaked along its sweep.
	vec2 q = vec2(lp.x * 2.2 + lp.z * 1.1, lp.y * 2.4 - lp.x * 0.7 + lp.z * 0.6);
	float rr = length(q - vec2(0.4, -0.9)) + vnoise(lp * 3.0) * 0.08;
	float sw = rr * 3.4;
	float swath = smoothstep(0.0, 0.2, fract(sw)) * (1.0 - smoothstep(0.4, 0.85, fract(sw))) * step(0.35, hash1(floor(sw) * 3.7 + 1.0));
	float st = rr * 36.0;
	float streak = (0.25 + 0.75 * hash1(floor(st) * 1.7 + 2.0)) * (1.0 - abs(fract(st) - 0.5) * 2.0);
	float wipe = swath * streak * smoothstep(0.35, 0.7, vnoise(lp * 2.3 + 11.0));
	// Runs: drips down only some of the glass, each fading out along its length.
	float rs = lp.x * 24.0 + lp.z * 15.0 + vnoise(lp * 4.0) * 1.4;
	float stripe = abs(fract(rs) - 0.5);
	float runs = (1.0 - smoothstep(0.03, 0.2, stripe)) * step(0.6, hash1(floor(rs) * 2.3 + 5.0)) * smoothstep(0.55, 0.85, vnoise(vec3(lp.x * 9.0, lp.y * 1.3, lp.z * 9.0)));
	float low = (1.0 - smoothstep(grime_lo, grime_hi, lp.y)) * n;
	float grease = clamp(blotch * 0.65 + wipe * 0.7 + runs * 0.5 + low * 0.7, 0.0, 1.0);
	float s = abs(fract(lp.x * 7.0 - lp.y * 2.0 + vnoise(lp * 2.5) * 3.0) - 0.5);
	float scratch = (1.0 - smoothstep(0.0, 0.012, s)) * step(0.78, vnoise(lp * 9.0 + 4.0));
	float cr = 0.0;
	vec3 nrm = normalize(ln);
	for (int k = 0; k < 8; k++) {
		cr = max(cr, crack(cracks[k], crack_dirs[k], lp, nrm));
	}
	ALBEDO = mix(mix(tint * 0.12, grease_color, grease), vec3(0.8, 0.82, 0.8), cr);
	ROUGHNESS = mix(mix(0.05, 0.75, grease), 0.3, cr);
	// The grease scatters the cockpit's light: a film over the view that shows even in the dark.
	EMISSION = grease_color * grease * 0.8 + vec3(0.07, 0.08, 0.07) * cr;
	float a = clamp(0.03 + fres * 0.45 + grease * 0.34 + scratch * 0.18 + cr * 0.7, 0.0, 0.92);
	ALPHA = a;
	glass_alpha = a;
	// (A faint film of dust all over; crazed glass catches the light like the grease.)
	glass_film = clamp(0.05 + grease + scratch * 0.4 + cr * 0.6, 0.0, 1.0);
}
"""

## The missiles' display: the scout from above, nose up, drawn in glowing lines (added onto its
## screen), with two missiles under each wing, filled green while loaded and red once fired
## (`loaded`: the left outer, right outer, left inner and right inner one).
const MISSILE_SHADER := """
shader_type spatial;
render_mode unshaded, shadows_disabled, blend_add, depth_draw_never;
uniform vec3 ink : source_color = vec3(0.4, 1.0, 0.45);
uniform vec3 gone : source_color = vec3(1.0, 0.2, 0.1);
instance uniform vec4 loaded = vec4(1.0);
instance uniform float power = 1.0;

float seg(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}

float ink_line(float d, float w) {
	return 1.0 - smoothstep(w, w + fwidth(d) * 1.2, d);
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.2;
	p.y = -p.y;
	float d = seg(p, vec2(0.0, 0.92), vec2(0.13, 0.55));
	d = min(d, seg(p, vec2(0.13, 0.55), vec2(0.16, -0.55)));
	d = min(d, seg(p, vec2(0.16, -0.55), vec2(0.1, -0.85)));
	d = min(d, seg(p, vec2(0.1, -0.85), vec2(-0.1, -0.85)));
	d = min(d, seg(p, vec2(-0.1, -0.85), vec2(-0.16, -0.55)));
	d = min(d, seg(p, vec2(-0.16, -0.55), vec2(-0.13, 0.55)));
	d = min(d, seg(p, vec2(-0.13, 0.55), vec2(0.0, 0.92)));
	for (int i = 0; i < 2; i++) {
		float s = i == 0 ? -1.0 : 1.0;
		d = min(d, seg(p, vec2(0.16 * s, 0.05), vec2(0.88 * s, -0.25)));
		d = min(d, seg(p, vec2(0.88 * s, -0.25), vec2(0.88 * s, -0.42)));
		d = min(d, seg(p, vec2(0.88 * s, -0.42), vec2(0.16 * s, -0.36)));
	}
	vec2 q = (p - vec2(0.0, 0.36)) / vec2(0.075, 0.2);
	vec3 col = ink * max(ink_line(d, 0.03), ink_line(abs(length(q) - 1.0) * 0.075, 0.022)) * 0.85;
	for (int i = 0; i < 4; i++) {
		float s = i % 2 == 0 ? -1.0 : 1.0;
		float x = i < 2 ? 0.7 : 0.4;
		float dm = seg(p, vec2(x * s, 0.2), vec2(x * s, -0.38)) - 0.055;
		float fill = 1.0 - smoothstep(0.0, fwidth(dm) * 1.2, dm);
		col = mix(col, (loaded[i] > 0.5 ? ink * 1.5 : gone * 1.2), fill);
	}
	ALBEDO = col * power;
}
"""

## The homing dial: a ring with a tick every 30 degrees, the scout seen from above in the middle and
## a needle pointing the way to its dock (`bearing`, radians, clockwise from ahead); a chevron lights
## above or below it when the dock is well above or below (`elev`, -1..1).
const DOCK_SHADER := """
shader_type spatial;
render_mode unshaded, shadows_disabled;
uniform vec3 paint : source_color = vec3(0.72, 1.0, 0.7);
uniform vec3 needle_col : source_color = vec3(1.0, 0.7, 0.25);
uniform vec3 face : source_color = vec3(0.022, 0.025, 0.023);
instance uniform float bearing = 0.0;
instance uniform float elev = 0.0;
instance uniform float active = 1.0;
instance uniform float power = 1.0;

float seg(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}

float ink_line(float d, float w) {
	return 1.0 - smoothstep(w, w + fwidth(d) * 1.2, d);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	p.y = -p.y;
	float r = length(p);
	float a = atan(p.x, p.y);
	float tick = abs(fract(a / 0.5236 + 0.5) - 0.5) * 0.5236 * r;
	float ticks = ink_line(tick, 0.018) * step(0.74, r) * step(r, 0.88);
	ticks = max(ticks, ink_line(abs(r - 0.9), 0.012));
	float plane = min(seg(p, vec2(0.0, 0.2), vec2(0.0, -0.18)), seg(p, vec2(-0.2, 0.02), vec2(0.2, 0.02)));
	plane = min(plane, seg(p, vec2(-0.08, -0.16), vec2(0.08, -0.16)));
	vec2 nd = vec2(sin(bearing), cos(bearing));
	vec2 tip = nd * 0.7;
	vec2 side = vec2(nd.y, -nd.x);
	float needle = min(seg(p, nd * 0.28, tip), min(seg(p, tip, tip - nd * 0.16 + side * 0.1), seg(p, tip, tip - nd * 0.16 - side * 0.1)));
	float up_c = min(seg(p, vec2(-0.12, 0.42), vec2(0.0, 0.54)), seg(p, vec2(0.0, 0.54), vec2(0.12, 0.42)));
	float down_c = min(seg(p, vec2(-0.12, -0.42), vec2(0.0, -0.54)), seg(p, vec2(0.0, -0.54), vec2(0.12, -0.42)));
	vec3 col = mix(face, paint * 0.8, max(ticks, ink_line(plane, 0.03) * 0.8));
	col = mix(col, needle_col * 1.6, ink_line(needle, 0.035) * active);
	col = mix(col, needle_col * 1.4, ink_line(up_c, 0.03) * step(0.3, elev) * active);
	col = mix(col, needle_col * 1.4, ink_line(down_c, 0.03) * step(elev, -0.3) * active);
	ALBEDO = col * (0.3 + 0.7 * power);
	ALPHA = 1.0 - smoothstep(0.97, 1.0, r);
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
"""

## Markers on the canopy glass, glowing: the targeting crosshair (mode 0), four corner brackets
## closing in on the target as the lock builds (`progress`) and a diamond round it once locked; and
## the dock's marker (mode 1), a diamond with a dot.
const MARK_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec3 seek : source_color = vec3(1.0, 0.65, 0.15);
uniform vec3 locked : source_color = vec3(1.0, 0.16, 0.08);
uniform vec3 dock : source_color = vec3(0.45, 1.0, 0.55);
uniform float mode = 0.0;
instance uniform float progress = 0.0;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	vec2 q = abs(p);
	float w = 0.035;
	float a = 0.0;
	vec3 col = dock;
	if (mode > 0.5) {
		float d = abs(q.x + q.y - 0.7);
		a = max(1.0 - smoothstep(w * 1.4, w * 1.4 + fwidth(d) * 1.5, d), 1.0 - smoothstep(0.08, 0.12, length(p)));
	} else {
		float s = mix(0.95, 0.32, progress);
		float arm = s * 0.4;
		float hx = step(s - arm, q.x) * step(q.x, s) * (1.0 - smoothstep(w, w + fwidth(q.y) * 1.5, abs(q.y - s)));
		float hy = step(s - arm, q.y) * step(q.y, s) * (1.0 - smoothstep(w, w + fwidth(q.x) * 1.5, abs(q.x - s)));
		float on = step(0.999, progress);
		float dia = abs(q.x + q.y - 0.24);
		a = max(max(hx, hy), on * (1.0 - smoothstep(w, w + fwidth(dia) * 1.5, dia)));
		col = mix(seek, locked, on);
	}
	ALBEDO = col * 3.0;
	ALPHA = a;
}
"""

static var _shared: Dictionary = {}

## The scout this cockpit is in.
var scout: Scout
## The local pilot holds RMB: the sight looks for an alien to lock on to (set by their CrewMember).
var targeting := false
## The alien held in the sight (or null) and how far the lock on it has closed in (1: locked).
var target: Node3D = null
var lock := 0.0
var _glass_mat: ShaderMaterial
## The cracks (CRACKS order): where each starts on the glass, how long it has grown (m) and which
## quarter of its full length it has reached (for the creak as it spreads).
var _crack_pos: Array[Vector3] = []
var _crack_len: Array[float] = []
var _crack_step: Array[int] = []
var _cracks_shown := 0
var _cracks_sent: Array[Vector4] = []
var _reticle: MeshInstance3D
var _bars: Dictionary = {}
var _texts: Dictionary = {}
var _lamps: Dictionary = {}
var _screens: Array[MeshInstance3D] = []
var _missile_draw: MeshInstance3D
var _dock_dial: MeshInstance3D
var _lock_mark: Node3D
var _lock_quad: MeshInstance3D
var _lock_label: Label3D
var _dock_mark: Node3D
var _dock_label: Label3D
var _alarm_light: OmniLight3D
var _tone: AudioStreamPlayer
var _clock := 0.0
var _beep_t := 0.0
var _warn_t := 0.0
## The view: the cannons' kick, a hit's jolt, the booster's rumble (0..1 each) and how far past
## its top speed the scout flies (0..1, the field of view widens).
var _kick := 0.0
var _jolt := 0.0
var _rumble := 0.0
var _speed_fx := 0.0
var _was_boosting := false


# --- The canopy and the furniture (static: also for the homebase display) ----------------------

## The canopy (its glass, the steel straps holding it and the fairing behind it) and the cockpit
## inside it (the deck, the seat, the front panel with the gunsight, the instrument panels' housings
## either side and the consoles along the sides) under `root`, in the scout's frame. Returns
## {"glass" (the glass's MeshInstance3D)}.
static func build_shell(root: Node3D, body_mat: Material) -> Dictionary:
	var glass := MeshInstance3D.new()
	glass.name = "Canopy"
	glass.mesh = _glass_mesh()
	glass.material_override = _glass_material()
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glass.layers = Game.VIS_GLASS
	root.add_child(glass)
	var olive := Models.panel_mat(Color(0.25, 0.27, 0.22), 0.35, 0.75, 3.0)
	var dark := Models.mat(Color(0.07, 0.075, 0.08), 0.4, 0.7)
	var steel := Models.mat(Color(0.5, 0.51, 0.5), 0.8, 0.35)
	var frame := Cockpit.frame_mat()
	var bolt := Models.mat(Color(0.5, 0.49, 0.45), 0.5, 0.45)
	var leather := Models.mat(Color(0.2, 0.14, 0.1), 0.1, 0.8)
	var black := Models.mat(Color(0.02, 0.02, 0.02), 0.2, 0.6)
	var b := Models.Batch.new()
	b.add(_fairing_mesh(), Transform3D.IDENTITY, body_mat)
	_build_frame(b, frame, bolt)
	# The deck, following the sills.
	var deck := PackedVector2Array()
	var zs := _ring_zs(float(CANOPY[0][0]) + 0.02, GLASS_TO)
	for z in zs:
		deck.append(Vector2(-section(z).y + 0.03, z))
	for i in range(zs.size() - 1, -1, -1):
		deck.append(Vector2(section(zs[i]).y - 0.03, zs[i]))
	b.add(Models.prism(deck, DECK_Y, DECK_Y + 0.012), Transform3D.IDENTITY, Models.panel_mat(Color(0.14, 0.15, 0.15), 0.5, 0.7, 4.0))
	# The bulkhead behind the seat (the fairing's front), with a radio and an oxygen bottle.
	b.box(Vector3(0.18, 0.17, -0.0), Vector3(0.24, 0.2, 0.16), olive)
	b.box(Vector3(0.18, 0.2, -0.085), Vector3(0.18, 0.08, 0.01), black)
	b.cyl(Vector3(-0.2, 0.2, -0.0), 0.07, 0.28, Models.mat(Color(0.3, 0.42, 0.3), 0.4, 0.5))
	# The seat, built into the cockpit: shell, cushions, headrest and harness.
	var back := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(12.0)), Vector3(0, 0.34, -0.25))
	b.add(_box(Vector3(0.46, 0.56, 0.06)), back, olive)
	b.add(_box(Vector3(0.38, 0.46, 0.05)), back * Transform3D(Basis.IDENTITY, Vector3(0, -0.02, -0.05)), leather)
	b.add(_box(Vector3(0.26, 0.13, 0.08)), back * Transform3D(Basis.IDENTITY, Vector3(0, 0.29, -0.04)), leather)
	for x: float in [-0.22, 0.22]:
		b.add(_box(Vector3(0.05, 0.4, 0.12)), back * Transform3D(Basis.IDENTITY, Vector3(x, -0.05, -0.05)), olive)
	for x: float in [-0.1, 0.1]:
		b.add(_box(Vector3(0.045, 0.42, 0.01)), back * Transform3D(Basis.IDENTITY, Vector3(x, 0.02, -0.08)), Models.mat(Color(0.12, 0.1, 0.08), 0.1, 0.8))
	# The front panel under the windscreen, its fascia turned to the eye.
	b.box(Vector3(0, 0.13, -1.265), Vector3(0.42, 0.14, 0.23), olive)
	b.box(Vector3(0, 0.203, -1.265), Vector3(0.44, 0.012, 0.25), dark)
	var fascia := facing_eye(FASCIA)
	b.add(_box(Vector3(FASCIA_SIZE.x, FASCIA_SIZE.y, 0.02)), fascia * Transform3D(Basis.IDENTITY, Vector3(0, 0, -0.012)), olive)
	b.add(_box(Vector3(FASCIA_SIZE.x + 0.01, 0.01, 0.025)), fascia * Transform3D(Basis.IDENTITY, Vector3(0, -FASCIA_SIZE.y * 0.5, -0.008)),
		Models.mat(Color(0.9, 0.7, 0.1), 0.2, 0.6))
	# The gunsight: a lamp housing on a post just under the line of sight, and the glass the ring
	# shows on in a slim U-shaped holder.
	b.strut(Vector3(0, 0.2, -1.2), Vector3(0, 0.36, -0.96), 0.012, steel)
	b.box(Vector3(0, 0.375, -0.95), Vector3(0.045, 0.04, 0.1), dark)
	b.box(Vector3(0, 0.3955, -0.915), Vector3(0.026, 0.002, 0.03), Models.emissive(Color(1.0, 0.55, 0.15), 0.8))
	b.box(Vector3(0, 0.398, -0.92), Vector3(0.094, 0.006, 0.014), dark)
	for x: float in [-0.045, 0.045]:
		b.box(Vector3(x, 0.432, -0.92), Vector3(0.005, 0.07, 0.008), dark)
	b.add(_box(Vector3(0.085, 0.075, 0.003)), Transform3D(Basis(Vector3.RIGHT, deg_to_rad(40.0)), SIGHT), Models.glass(Color(0.7, 0.8, 0.72, 0.05)))
	# The instrument panels' housings either side, on pedestals.
	for p: Vector3 in [PANEL_L, PANEL_R]:
		var xf := facing_eye(p)
		b.add(_box(Vector3(PANEL_SIZE.x + 0.02, PANEL_SIZE.y + 0.02, 0.06)), xf * Transform3D(Basis.IDENTITY, Vector3(0, 0, -0.032)), dark)
		b.add(_box(Vector3(PANEL_SIZE.x, PANEL_SIZE.y, 0.008)), xf * Transform3D(Basis.IDENTITY, Vector3(0, 0, -0.002)), olive)
		b.add(_box(Vector3(PANEL_SIZE.x + 0.04, 0.015, 0.08)), xf * Transform3D(Basis.IDENTITY, Vector3(0, PANEL_SIZE.y * 0.5 + 0.012, -0.02)), dark)
		for c: Vector2 in [Vector2(-1, 1), Vector2(1, 1), Vector2(-1, -1), Vector2(1, -1)]:
			var at := Vector3(c.x * (PANEL_SIZE.x * 0.5 - 0.01), c.y * (PANEL_SIZE.y * 0.5 - 0.01), 0.003)
			b.add(_cyl(0.006, 0.006), xf * Transform3D(Basis(Vector3.RIGHT, PI / 2.0), at), bolt)
		var foot := p.y - PANEL_SIZE.y * 0.45
		b.box(Vector3(p.x * 1.05, (DECK_Y + foot) * 0.5, p.z + 0.03), Vector3(0.18, foot - DECK_Y, 0.14), dark)
	# The consoles along the sides, with rows of switches.
	for s: float in [-1.0, 1.0]:
		b.box(Vector3(s * 0.41, 0.115, -0.53), Vector3(0.17, 0.11, 0.62), olive)
		b.box(Vector3(s * 0.41, 0.172, -0.53), Vector3(0.18, 0.006, 0.64), dark)
		for i in 5:
			b.box(Vector3(s * 0.39, 0.185, -0.75 + i * 0.1), Vector3(0.02, 0.02, 0.03), steel)
			b.box(Vector3(s * 0.44, 0.18, -0.75 + i * 0.1), Vector3(0.035, 0.008, 0.035), black)
	b.commit(root, "Cockpit")
	return {"glass": glass}


## The canopy's straps: a rail along each sill, a pillar up each side of the windscreen and over to
## the rear arch where the glass meets the fairing, a strap along the top behind the pilot's head,
## and a bar across the windscreen's foot; bolts along them.
static func _build_frame(b: Models.Batch, frame: Material, bolt: Material) -> void:
	var zs := _ring_zs(float(CANOPY[0][0]), GLASS_TO)
	for t: float in [0.03, PILLAR_T, PI - PILLAR_T, PI - 0.03]:
		var pts: Array[Vector3] = []
		var ns: Array[Vector3] = []
		for z in zs:
			pts.append(canopy_point(z, t))
			ns.append(canopy_normal(z, t))
		_strap(b, pts, ns, 0.045 if t > 0.1 and t < PI - 0.1 else 0.06, 0.022, frame)
		if t > 0.1 and t < PI - 0.1:
			for i in range(2, pts.size(), 3):
				_bolt(b, pts[i] + ns[i] * 0.022, ns[i], bolt)
	var arch: Array[Vector3] = []
	var arch_n: Array[Vector3] = []
	var top: Array[Vector3] = []
	var top_n: Array[Vector3] = []
	for k in 17:
		var t := PI * k / 16.0
		arch.append(canopy_point(GLASS_TO, t))
		arch_n.append(canopy_normal(GLASS_TO, t))
	for k in 9:
		var z := lerpf(-0.6, GLASS_TO, k / 8.0)
		top.append(canopy_point(z, PI * 0.5))
		top_n.append(canopy_normal(z, PI * 0.5))
	_strap(b, arch, arch_n, 0.06, 0.026, frame)
	_strap(b, top, top_n, 0.045, 0.022, frame)
	for i in range(1, arch.size(), 2):
		_bolt(b, arch[i] + arch_n[i] * 0.026, arch_n[i], bolt)
	var foot := canopy_point(float(CANOPY[0][0]) + 0.01, PI * 0.5)
	var w := section(float(CANOPY[0][0]) + 0.01).y
	b.box(foot + Vector3(0, 0.012, 0), Vector3(w * 2.0, 0.03, 0.05), frame)


## A steel strap along `pts` on the canopy (`ns`: the canopy's outward normals there), `w` wide and
## `t` thick, standing on the glass.
static func _strap(b: Models.Batch, pts: Array[Vector3], ns: Array[Vector3], w: float, t: float, mat: Material) -> void:
	for i in pts.size() - 1:
		var a := pts[i]
		var c := pts[i + 1]
		var length := a.distance_to(c)
		if length < 0.0005:
			continue
		var f := (c - a) / length
		var n := (ns[i] + ns[i + 1]).normalized()
		var up := (n - f * n.dot(f)).normalized()
		b.add(_box(Vector3(w, t, length + 0.004)), Transform3D(Basis(up.cross(f), up, f), (a + c) * 0.5 + up * t * 0.5), mat)


## A bolt head at `pos` on a strap, facing out along `n`.
static func _bolt(b: Models.Batch, pos: Vector3, n: Vector3, mat: Material) -> void:
	var side := n.cross(Vector3.FORWARD if absf(n.z) < 0.9 else Vector3.RIGHT).normalized()
	b.add(_cyl(0.011, 0.012), Transform3D(Basis(side, n, side.cross(n)), pos), mat)


## The canopy's glass: half-ellipse rings along CANOPY (each stretch split in four) back to GLASS_TO,
## smooth, facing out.
static func _glass_mesh() -> ArrayMesh:
	if _shared.has("glass_mesh"):
		return _shared["glass_mesh"]
	var zs := _ring_zs(float(CANOPY[0][0]), GLASS_TO)
	var segs := 28
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in zs.size() - 1:
		for j in segs:
			var q: Array[Vector2] = [Vector2(zs[i], PI * j / segs), Vector2(zs[i + 1], PI * j / segs),
				Vector2(zs[i + 1], PI * (j + 1) / segs), Vector2(zs[i], PI * (j + 1) / segs)]
			for tri: Array in [[q[0], q[1], q[2]], [q[0], q[2], q[3]]]:
				var a: Vector2 = tri[0]
				var b: Vector2 = tri[1]
				var c: Vector2 = tri[2]
				var pa := canopy_point(a.x, a.y)
				var pb := canopy_point(b.x, b.y)
				var pc := canopy_point(c.x, c.y)
				if (pb - pa).cross(pc - pa).length_squared() < 1e-12:
					continue
				# Godot's front faces wind clockwise: the right-handed normal must point in.
				if (pb - pa).cross(pc - pa).dot(canopy_normal(a.x, a.y)) > 0.0:
					var swap := b
					b = c
					c = swap
				for v: Vector2 in [a, b, c]:
					st.set_normal(canopy_normal(v.x, v.y))
					st.add_vertex(canopy_point(v.x, v.y))
	var mesh := st.commit()
	_shared["glass_mesh"] = mesh
	return mesh


## The fairing behind the glass (GLASS_TO to the canopy's end) on the same half ellipses, closed at
## both ends: in front it is the bulkhead behind the seat.
static func _fairing_mesh() -> ArrayMesh:
	var zs := _ring_zs(GLASS_TO, float(CANOPY[CANOPY.size() - 1][0]))
	var segs := 16
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in zs.size() - 1:
		var axis := Vector3(0, section((zs[i] + zs[i + 1]) * 0.5).x, (zs[i] + zs[i + 1]) * 0.5)
		for j in segs:
			var t0 := PI * j / segs
			var t1 := PI * (j + 1) / segs
			Models.tri(st, canopy_point(zs[i], t0), canopy_point(zs[i + 1], t0), canopy_point(zs[i + 1], t1), axis)
			Models.tri(st, canopy_point(zs[i], t0), canopy_point(zs[i + 1], t1), canopy_point(zs[i], t1), axis)
	for end: Array in [[zs[0], 1.0], [zs[zs.size() - 1], -1.0]]:
		var z := float(end[0])
		var s := section(z)
		var mid := Vector3(0, s.x + (s.z - s.x) * 0.35, z)
		for j in segs:
			Models.tri(st, mid, canopy_point(z, PI * j / segs), canopy_point(z, PI * (j + 1) / segs), mid + Vector3(0, 0, float(end[1])))
	return st.commit()


## The z of the rings between z0 and z1: every CANOPY ring in between, each stretch split in four.
static func _ring_zs(z0: float, z1: float) -> Array[float]:
	var cuts: Array[float] = [z0]
	for r: Array in CANOPY:
		var z := float(r[0])
		if z > z0 + 0.001 and z < z1 - 0.001:
			cuts.append(z)
	cuts.append(z1)
	var out: Array[float] = []
	for i in cuts.size() - 1:
		for k in 4:
			out.append(lerpf(cuts[i], cuts[i + 1], k / 4.0))
	out.append(z1)
	return out


## The canopy's cross-section at z: (sill height, half width at the sill, top); zero outside it.
static func section(z: float) -> Vector3:
	var first: Array = CANOPY[0]
	var last: Array = CANOPY[CANOPY.size() - 1]
	if z < float(first[0]) or z > float(last[0]):
		return Vector3.ZERO
	for i in CANOPY.size() - 1:
		var a: Array = CANOPY[i]
		var b: Array = CANOPY[i + 1]
		if z <= float(b[0]):
			var t := (z - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.0001)
			return Vector3(lerpf(a[1], b[1], t), lerpf(a[2], b[2], t), lerpf(a[3], b[3], t))
	return Vector3(last[1], last[2], last[3])


## A point on the canopy at z, `t` round from the left sill (0) over the top (PI / 2) to the right
## sill (PI).
static func canopy_point(z: float, t: float) -> Vector3:
	var s := section(z)
	return Vector3(-s.y * cos(t), s.x + (s.z - s.x) * sin(t), z)


## The canopy's outward normal at (z, t).
static func canopy_normal(z: float, t: float) -> Vector3:
	var dz := 0.01
	var z0 := clampf(z - dz, float(CANOPY[0][0]), float(CANOPY[CANOPY.size() - 1][0]))
	var z1 := clampf(z + dz, float(CANOPY[0][0]), float(CANOPY[CANOPY.size() - 1][0]))
	var along := canopy_point(z1, t) - canopy_point(z0, t)
	var across := canopy_point(z, t + 0.01) - canopy_point(z, t - 0.01)
	var n := along.cross(across)
	if n.length_squared() < 1e-12:
		n = Vector3(-cos(t), sin(t), 0.0)
	n = n.normalized()
	var s := section(z)
	if n.dot(canopy_point(z, t) - Vector3(0, s.x, z)) < 0.0:
		n = -n
	return n


## True for a point (scout frame) inside the canopy.
static func inside(p: Vector3) -> bool:
	var s := section(p.z)
	if s.y <= 0.0 or p.y < s.x:
		return false
	var u := p.x / s.y
	var v := (p.y - s.x) / maxf(s.z - s.x, 0.001)
	return u * u + v * v <= 1.0


## How far the canopy (or the deck) is from the eye looking along `dir` (scout frame).
static func glass_distance(dir: Vector3) -> float:
	var near := 0.05
	var far := 0.05
	while far < 2.5 and inside(EYE + dir * far):
		near = far
		far += 0.05
	for i in 6:
		var mid := (near + far) * 0.5
		if inside(EYE + dir * mid):
			near = mid
		else:
			far = mid
	return (near + far) * 0.5


## A frame at `pos` turned to face the eye (its +Z towards the eye).
static func facing_eye(pos: Vector3) -> Transform3D:
	var to := EYE - pos
	var yaw := atan2(to.x, to.z)
	var pitch := -atan2(to.y, Vector2(to.x, to.z).length())
	return Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch), pos)


static func _glass_material() -> ShaderMaterial:
	if not _shared.has("glass"):
		var m := ShaderMaterial.new()
		m.shader = _shader("glass", GLASS_SHADER + GunPod.GLASS_LIGHT)
		var none: Array[Vector4] = []
		none.resize(8)
		m.set_shader_parameter("cracks", none)
		m.set_shader_parameter("crack_dirs", none)
		_shared["glass"] = m
	return _shared["glass"]


static func _shader(key: String, code: String) -> Shader:
	var k := "shader_" + key
	if not _shared.has(k):
		var sh := Shader.new()
		sh.code = code
		_shared[k] = sh
	return _shared[k]


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


# --- The instruments (a scout in a mission) ----------------------------------------------------

## Build the instruments for scout `s`, whose canopy glass is `glass` (it gets a material of its own
## for its cracks).
func build(s: Scout, glass: MeshInstance3D) -> void:
	scout = s
	_glass_mat = (glass.material_override as ShaderMaterial).duplicate() as ShaderMaterial
	glass.material_override = _glass_mat
	# Where each crack starts on the glass and the way it runs over it.
	var dirs: Array[Vector4] = []
	for c: Array in CRACKS:
		var z := float(c[0])
		var t := float(c[1])
		var along := (canopy_point(z + 0.01, t) - canopy_point(z - 0.01, t)).normalized()
		var across := (canopy_point(z, t + 0.01) - canopy_point(z, t - 0.01)).normalized()
		var run := (along * float(c[2]) + across * float(c[3])).normalized()
		_crack_pos.append(canopy_point(z, t))
		_crack_len.append(0.0)
		_crack_step.append(0)
		dirs.append(Vector4(run.x, run.y, run.z, float(dirs.size()) + 1.0))
	_glass_mat.set_shader_parameter("crack_dirs", dirs)
	_build_sight()
	_build_left()
	_build_right()
	_build_front()
	_build_marks()
	# A dim lamp over the seat, so the panels read in the dark (it reaches the windscreen, where the
	# grease catches it), and the red alarm light.
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, 0.66, -0.3)
	lamp.omni_range = 1.9
	lamp.omni_attenuation = 0.8
	lamp.light_energy = 0.4
	lamp.light_color = Color(1.0, 0.8, 0.55)
	add_child(lamp)
	_alarm_light = OmniLight3D.new()
	_alarm_light.position = Vector3(0, 0.6, -0.85)
	_alarm_light.omni_range = 1.8
	_alarm_light.light_energy = 0.0
	_alarm_light.light_color = Color(1.0, 0.12, 0.06)
	add_child(_alarm_light)
	_tone = AudioStreamPlayer.new()
	_tone.stream = Sfx.stream("lock_tone")
	_tone.volume_db = -15.0
	add_child(_tone)


## The gunsight's glowing ring, on its glass on the eye's line (GunPod's reticle).
func _build_sight() -> void:
	_reticle = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.06, 0.06)
	_reticle.mesh = q
	var m := GunPod.sight_material()
	_reticle.material_override = m
	_reticle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_reticle.position = SIGHT
	add_child(_reticle)


## The left panel: thrust (with the booster's zone), hull and fuel cargo.
func _build_left() -> void:
	var f := facing_eye(PANEL_L)
	var rows := [["thrust", "THRUST", 0.06, 0.03], ["hull", "HULL", 0.0, 0.024], ["cargo", "CARGO", -0.06, 0.024]]
	for r: Array in rows:
		var y := float(r[2])
		_label(f, Vector3(-0.128, y, 0.004), str(r[1]), 19, GREEN * 0.85, -1.0)
		var bar: MeshInstance3D
		match str(r[0]):
			"thrust":
				bar = Cockpit.bar_mesh(Vector2(0.14, float(r[3])), 18, false, 0.0, 1.0 / Scout.BOOST)
			"hull":
				bar = Cockpit.bar_mesh(Vector2(0.14, float(r[3])), 20, false, Scout.HULL_CRITICAL, 2.0)
			_:
				bar = Cockpit.bar_mesh(Vector2(0.14, float(r[3])), 20, false, 0.0, 2.0)
				(bar.material_override as ShaderMaterial).set_shader_parameter("lit", Color(1.0, 0.72, 0.25))
		bar.transform = f * Transform3D(Basis.IDENTITY, Vector3(0.0, y, 0.004))
		add_child(bar)
		_bars[r[0]] = bar
		_texts[r[0]] = _label(f, Vector3(0.128, y, 0.004), "", 20, GREEN, 1.0)
	# The booster's zone of the thrust gauge.
	var boost_x := -0.07 + 0.14 * (1.0 / Scout.BOOST + 1.0) * 0.5
	_label(f, Vector3(boost_x, 0.083, 0.004), "BOOST", 14, AMBER * 0.85)
	_label(f, Vector3(0, -0.088, 0.004), "FLIGHT", 14, STENCIL)


## The right panel: the magazine (rounds on a green screen, and a bar), the missiles and the homing
## needle with the dock's distance.
func _build_right() -> void:
	var f := facing_eye(PANEL_R)
	_screen(f, Vector3(-0.064, 0.035, 0.004), Vector2(0.12, 0.085))
	_label(f, Vector3(-0.12, 0.067, 0.006), "CANNON", 15, GREEN * 0.8, -1.0)
	_texts["gun"] = _label(f, Vector3(-0.008, 0.067, 0.006), "", 15, GREEN, 1.0)
	_texts["ammo"] = _label(f, Vector3(-0.078, 0.028, 0.006), "", 60, GREEN)
	_label(f, Vector3(-0.02, 0.014, 0.006), "RDS", 15, GREEN * 0.8)
	var mag := Cockpit.bar_mesh(Vector2(0.12, 0.015), 16, false, 0.0, 2.0)
	mag.transform = f * Transform3D(Basis.IDENTITY, Vector3(-0.064, -0.018, 0.004))
	add_child(mag)
	_bars["mag"] = mag
	_screen(f, Vector3(0.076, 0.035, 0.004), Vector2(0.1, 0.085))
	_missile_draw = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.082, 0.074)
	_missile_draw.mesh = q
	var mm := ShaderMaterial.new()
	mm.shader = _shader("missiles", MISSILE_SHADER)
	_missile_draw.material_override = mm
	_missile_draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_missile_draw.transform = f * Transform3D(Basis.IDENTITY, Vector3(0.076, 0.038, 0.005))
	add_child(_missile_draw)
	_texts["msl"] = _label(f, Vector3(0.076, -0.018, 0.004), "", 16, GREEN)
	_dock_dial = MeshInstance3D.new()
	var dq := QuadMesh.new()
	dq.size = Vector2(0.054, 0.054)
	_dock_dial.mesh = dq
	var dm := ShaderMaterial.new()
	dm.shader = _shader("dock", DOCK_SHADER)
	_dock_dial.material_override = dm
	_dock_dial.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_dock_dial.transform = f * Transform3D(Basis.IDENTITY, Vector3(-0.1, -0.064, 0.004))
	add_child(_dock_dial)
	_texts["dock"] = _label(f, Vector3(-0.066, -0.055, 0.004), "", 18, GREEN, -1.0)
	_texts["dock2"] = _label(f, Vector3(-0.066, -0.077, 0.004), "", 15, GREEN, -1.0)


## The front panel's fascia: the lamps, the heat gauge and the stencilled controls.
func _build_front() -> void:
	var f := facing_eye(FASCIA)
	var n := LAMPS.size()
	for i in n:
		var l: Array = LAMPS[i]
		var x := (i - (n - 1) * 0.5) * 0.09
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.06, 0.055, 0.05)
		m.emission_enabled = true
		m.emission = l[2]
		m.emission_energy_multiplier = 0.0
		var lens := MeshInstance3D.new()
		lens.mesh = _box(Vector3(0.077, 0.03, 0.008))
		lens.material_override = m
		lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		lens.transform = f * Transform3D(Basis.IDENTITY, Vector3(x, 0.043, 0.004))
		add_child(lens)
		var rim := MeshInstance3D.new()
		rim.mesh = _box(Vector3(0.086, 0.04, 0.006))
		rim.material_override = Models.mat(Color(0.5, 0.51, 0.5), 0.8, 0.35)
		rim.transform = f * Transform3D(Basis.IDENTITY, Vector3(x, 0.043, 0.001))
		add_child(rim)
		_lamps[l[0]] = {"mat": m, "label": _label(f, Vector3(x, 0.043, 0.0085), str(l[1]), 17, Color(0.42, 0.4, 0.36))}
	_label(f, Vector3(-0.2, -0.007, 0.004), "HEAT", 19, GREEN * 0.85, -1.0)
	var heat := Cockpit.bar_mesh(Vector2(0.3, 0.028), 15, false, 0.0, 0.6, 0.85)
	heat.transform = f * Transform3D(Basis.IDENTITY, Vector3(0.035, -0.007, 0.004))
	add_child(heat)
	_bars["heat"] = heat
	_label(f, Vector3(0, -0.042, 0.004), "LMB GUNS   RMB LOCK ON   RMB+LMB MISSILE", 17, STENCIL)
	_label(f, Vector3(0, -0.06, 0.004), "SHIFT BOOST   E DOCK   HOLD E RECALL", 17, STENCIL)


## The markers on the glass: the targeting crosshair with its read-out, and the dock's marker.
func _build_marks() -> void:
	_lock_mark = Node3D.new()
	_lock_mark.visible = false
	add_child(_lock_mark)
	_lock_quad = _mark_quad(0.1, 0.0)
	_lock_mark.add_child(_lock_quad)
	_lock_label = _glass_label()
	_lock_label.position = Vector3(0, -0.066, 0)
	_lock_mark.add_child(_lock_label)
	_dock_mark = Node3D.new()
	_dock_mark.visible = false
	add_child(_dock_mark)
	_dock_mark.add_child(_mark_quad(0.034, 1.0))
	_dock_label = _glass_label()
	_dock_label.position = Vector3(0, -0.035, 0)
	_dock_label.modulate = Color(0.55, 1.3, 0.6)
	_dock_mark.add_child(_dock_label)


func _mark_quad(size: float, mode: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	mi.mesh = q
	var m := ShaderMaterial.new()
	m.shader = _shader("mark", MARK_SHADER)
	m.set_shader_parameter("mode", mode)
	m.render_priority = 2
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _glass_label() -> Label3D:
	var l := Label3D.new()
	l.font = GunPod.mono_font()
	l.font_size = 30
	l.pixel_size = 0.0006
	l.outline_size = 0
	l.double_sided = false
	l.render_priority = 3
	return l


## A green screen (the gun pods' CRT look) `size` big at `pos` on panel frame `f`.
func _screen(f: Transform3D, pos: Vector3, size: Vector2) -> void:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	mi.mesh = q
	mi.material_override = GunPod.crt_material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.transform = f * Transform3D(Basis.IDENTITY, pos)
	add_child(mi)
	_screens.append(mi)


## Text in the terminals' monospace face on a panel (frame `f`): `anchor` -1 starts it at `pos`,
## 0 centres it there, 1 ends it there (kept when the text changes, see _set_text).
func _label(f: Transform3D, pos: Vector3, text: String, size: int, color: Color, anchor := 0.0) -> Label3D:
	var l := Label3D.new()
	l.font = GunPod.mono_font()
	l.font_size = size
	l.pixel_size = 0.0005
	l.outline_size = 0
	l.modulate = color
	l.double_sided = false
	l.set_meta("anchor", anchor)
	_set_text(l, text)
	l.transform = f * Transform3D(Basis.IDENTITY, pos)
	add_child(l)
	return l


static func _set_text(l: Label3D, text: String) -> void:
	if l.text == text and not text.is_empty():
		return
	l.text = text
	var anchor := float(l.get_meta("anchor", 0.0))
	if anchor != 0.0:
		l.offset.x = -anchor * l.font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, l.font_size).x * 0.5


# --- Per frame ---------------------------------------------------------------------------------

func _process(delta: float) -> void:
	if scout == null or not is_instance_valid(scout):
		return
	_clock += delta
	var local := scout.local_pilot()
	var flying := scout.state == Scout.State.FLYING
	_update_view(delta, local)
	_update_cracks(delta, local)
	_update_targeting(delta, local)
	_update_alarm(delta, local, flying)
	_update_panels(flying)
	_update_marks(local)


## The pilot's view: the cannons' kick and hits fade, the booster rumbles and the view widens as the
## scout flies past its top speed. The pilot hears the booster kick in.
func _update_view(delta: float, local: bool) -> void:
	_kick = maxf(0.0, _kick - delta * 10.0)
	_jolt = maxf(0.0, _jolt - delta * 3.0)
	var boosting := scout.boosting or (local and bool(scout.local_input.get("boost", false)) and not scout.overheat)
	_rumble = move_toward(_rumble, 1.0 if boosting else 0.0, delta * 4.0)
	var speed := (scout.velocity if multiplayer.is_server() else scout.net_vel).length()
	var past := clampf((speed / scout.top_speed() - 1.0) / (Scout.BOOST - 1.0), 0.0, 1.0)
	_speed_fx = lerpf(_speed_fx, past, NetUtil.smooth(4.0, delta))
	if local and boosting and not _was_boosting:
		Sfx.play("boost_on", null, -4.0)
	_was_boosting = boosting


## The cannons fired (the pilot's view kicks).
func kick() -> void:
	_kick = 1.0


## The scout was hit for `amount` (the pilot's view jolts, more for a heavy hit).
func jolt(amount: float) -> void:
	_jolt = maxf(_jolt, clampf(amount / 15.0, 0.25, 1.0))


## The pilot's field of view (degrees): it widens as the booster drives the scout past its top
## speed.
func view_fov() -> float:
	return lerpf(FOV, FOV_BOOST, smoothstep(0.0, 1.0, _speed_fx))


## The pilot's view shaking (from the eye): the booster's rumble, the cannons' kick and hits.
func view_shake() -> Transform3D:
	var amp := _rumble * 0.005 + _kick * 0.002 + _jolt * 0.018
	var turn := _rumble * 0.003 + _kick * 0.0015 + _jolt * 0.02
	if amp <= 0.0:
		return Transform3D.IDENTITY
	var t := _clock
	var wobble := Vector3(sin(t * 61.0) + sin(t * 37.0 + 1.3), sin(t * 53.0 + 0.7) + sin(t * 29.0), sin(t * 47.0 + 2.1)) * 0.5
	var spin := Vector3(sin(t * 43.0 + 0.4), sin(t * 59.0 + 2.2), sin(t * 31.0 + 1.1))
	return Transform3D(Basis.from_euler(spin * turn), wobble * amp)


## The cracks run out over the canopy from its edges as the hull drops below CRACK_AT, longer with
## every hit (creeping out over a moment), and go once it is repaired. The pilot hears the glass
## crack as a new one starts, and creak as they spread.
func _update_cracks(delta: float, local: bool) -> void:
	var frac := scout.hp / maxf(scout.max_hp, 0.001)
	var started := 0
	var data: Array[Vector4] = []
	for k in CRACKS.size():
		var full := float(CRACKS[k][4])
		var want := 0.0
		if frac < float(CRACK_AT[k]):
			started += 1
			want = full * (0.25 + 0.75 * clampf((float(CRACK_AT[k]) - frac) / CRACK_GROW, 0.0, 1.0))
		_crack_len[k] = move_toward(_crack_len[k], want, delta * 0.4) if want > _crack_len[k] else want
		var step := int(_crack_len[k] / full * 4.0)
		if local and step > _crack_step[k] and step > 1:
			Sfx.play("glass_crack", null, -13.0, randf_range(1.25, 1.45))
		_crack_step[k] = step
		var p: Vector3 = _crack_pos[k]
		data.append(Vector4(p.x, p.y, p.z, _crack_len[k]))
	if started > _cracks_shown and local:
		Sfx.play("glass_crack", null, -3.0, randf_range(0.9, 1.1))
		jolt(8.0)
	_cracks_shown = started
	if data != _cracks_sent:
		_cracks_sent = data
		_glass_mat.set_shader_parameter("cracks", data)


## Targeting, for the local pilot holding RMB: the alien nearest the middle of the sight (within
## Scout.LOCK_CONE and LOCK_RANGE, in plain view) is locked on after Scout.LOCK_TIME seconds held in
## the sight; it stays the target while within half as much again of the cone. The seeker beeps
## faster as the lock closes in, then holds a steady tone.
func _update_targeting(delta: float, local: bool) -> void:
	var was := target
	if not local or not targeting or Game.ui_blocking:
		target = null
	else:
		var xf := scout.get_global_transform_interpolated()
		var eye := xf * EYE
		var fwd := -xf.basis.z
		if target != null and not _lockable(target, eye, fwd, Scout.LOCK_CONE * 1.5):
			target = null
		if target == null:
			var best := Scout.LOCK_CONE
			for a in get_tree().get_nodes_in_group("aliens"):
				var n := a as Node3D
				var ang := fwd.angle_to(n.global_position - eye)
				if ang < best and _lockable(n, eye, fwd, Scout.LOCK_CONE):
					best = ang
					target = n
	if target != was:
		lock = 0.0
	lock = minf(1.0, lock + delta / Scout.LOCK_TIME) if target else 0.0
	if target and lock < 1.0:
		_beep_t -= delta
		if _beep_t <= 0.0:
			_beep_t = lerpf(0.24, 0.07, lock)
			Sfx.play("lock_beep", null, -11.0, 1.0 + lock * 0.4)
	else:
		_beep_t = 0.0
	var tone := target != null and lock >= 1.0
	if tone != _tone.playing:
		if tone:
			_tone.play()
		else:
			_tone.stop()


func _lockable(n: Node3D, eye: Vector3, fwd: Vector3, cone: float) -> bool:
	if not is_instance_valid(n) or not n.is_inside_tree() or n.is_queued_for_deletion():
		return false
	var alien := n as Alien
	if alien and alien.hp <= 0.0:
		return false
	var to := n.global_position - eye
	if to.length() > Scout.LOCK_RANGE or fwd.angle_to(to) > cone:
		return false
	var q := PhysicsRayQueryParameters3D.create(eye, n.global_position, Game.LAYER_CAVE)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## The pilot clicks (LMB with RMB held) to fire a missile at the alien locked on to; without a lock
## or missiles left there is only a dull buzz.
func fire_missile() -> void:
	if is_instance_valid(target) and lock >= 1.0 and scout.missiles != 0 and scout.state == Scout.State.FLYING:
		scout.request_missile.rpc_id(1, str(target.name))
	else:
		Sfx.play("deny", null, -6.0)


## The hull critical: the red lights pulse, the HULL lamp flashes and the pilot hears the alarm.
func _update_alarm(delta: float, local: bool, flying: bool) -> void:
	var crit := flying and scout.hp < scout.max_hp * Scout.HULL_CRITICAL
	var pulse := 0.5 + 0.5 * sin(_clock * 7.0)
	_alarm_light.light_energy = (0.2 + 1.2 * pulse) if crit else 0.0
	if local and crit:
		_warn_t -= delta
		if _warn_t <= 0.0:
			_warn_t = 1.2
			Sfx.play("warn", null, -8.0)
	else:
		_warn_t = 0.0


## The gauges, screens and lamps follow the scout (dim while it is docked).
func _update_panels(flying: bool) -> void:
	var power := 1.0 if flying else 0.25
	var blink := fmod(_clock, 0.5) < 0.25
	var fast := fmod(_clock, 0.24) < 0.12
	var speed := (scout.velocity if multiplayer.is_server() else scout.net_vel).length() if flying else 0.0
	_bar("thrust", speed / (scout.top_speed() * Scout.BOOST), power)
	_set_text(_texts["thrust"], "%d" % int(round(speed)) if flying else "")
	_bar("hull", scout.hp / maxf(scout.max_hp, 0.001), power, 0.5 if flying and scout.hp < scout.max_hp * Scout.HULL_CRITICAL and not blink else 1.0)
	_set_text(_texts["hull"], "%d/%d" % [int(ceil(scout.hp)), int(round(scout.max_hp))])
	(_texts["hull"] as Label3D).modulate = RED if scout.hp < scout.max_hp * Scout.HULL_CRITICAL else GREEN
	_bar("cargo", scout.cargo / maxf(scout.max_cargo, 0.001), power)
	_set_text(_texts["cargo"], "%d/%d" % [int(scout.cargo), int(scout.max_cargo)])
	# The magazine.
	var loading := scout.reload_left > 0.0
	var progress := clampf(1.0 - scout.reload_left / Scout.RELOAD_TIME, 0.0, 1.0)
	_set_text(_texts["ammo"], "---" if loading else "%03d" % scout.ammo)
	(_texts["ammo"] as Label3D).modulate = AMBER if loading or scout.ammo * 5 <= Scout.MAG else GREEN
	var note := "READY"
	var note_col := GREEN
	if scout.overheat:
		note = "OVERHEAT" if fast else ""
		note_col = RED
	elif loading:
		note = "LOAD %d%%" % int(progress * 100.0)
		note_col = AMBER
	_set_text(_texts["gun"], note)
	(_texts["gun"] as Label3D).modulate = note_col
	_bar("mag", progress if loading else float(scout.ammo) / Scout.MAG, power, 0.5 if loading and not blink else 1.0)
	# The missiles.
	var on := Vector4.ZERO
	var left := 0
	for i in 4:
		if scout.missiles & (1 << i):
			on[i] = 1.0
			left += 1
	_missile_draw.set_instance_shader_parameter("loaded", on)
	_missile_draw.set_instance_shader_parameter("power", power)
	_set_text(_texts["msl"], "MSL %d/4" % left)
	(_texts["msl"] as Label3D).modulate = GREEN if left > 0 else RED
	for s in _screens:
		s.set_instance_shader_parameter("power", power)
	# The way home.
	_update_dock_dial(flying, power)
	# The heat gauge and the lamps.
	_bar("heat", scout.heat, power, 0.35 if scout.overheat and not fast else 1.0)
	var crit := flying and scout.hp < scout.max_hp * Scout.HULL_CRITICAL
	var st := {
		"hull": (2 if blink else 1) if crit else 0,
		"heat": (2 if fast else 0) if scout.overheat else (1 if scout.heat >= 0.75 else 0),
		"load": (2 if blink else 1) if loading else 0,
		"lock": (2 if lock >= 1.0 else (1 if blink else 0)) if target else 0,
	}
	for k: String in _lamps:
		var l: Dictionary = _lamps[k]
		var level: int = st.get(k, 0) if flying else 0
		(l["mat"] as StandardMaterial3D).emission_energy_multiplier = [0.0, 1.6, 3.2][level]
		(l["label"] as Label3D).modulate = Color(0.42, 0.4, 0.36) if level == 0 else Color(0.03, 0.03, 0.02)
	_reticle.set_instance_shader_parameter("power", 1.0 if flying else 0.15)


func _bar(id: String, value: float, power: float, blink := 1.0) -> void:
	var mi: MeshInstance3D = _bars[id]
	mi.set_instance_shader_parameter("value", clampf(value, 0.0, 1.0))
	mi.set_instance_shader_parameter("power", power)
	mi.set_instance_shader_parameter("blink", blink)


## The homing needle points the way to the scout's dock (seen from above the scout), a chevron
## lights when it is well above or below, and the distance shows beside it ("[E] DOCK" once it is
## close enough to dock).
func _update_dock_dial(flying: bool, power: float) -> void:
	_dock_dial.set_instance_shader_parameter("power", power)
	_dock_dial.set_instance_shader_parameter("active", 1.0 if flying else 0.0)
	if not flying or Game.mission == null or Game.mission.ship == null:
		_set_text(_texts["dock"], "")
		_set_text(_texts["dock2"], "")
		return
	var to := scout.global_basis.inverse() * (scout.dock_transform().origin - scout.global_position)
	var dist := to.length()
	_dock_dial.set_instance_shader_parameter("bearing", atan2(to.x, -to.z))
	var elev := atan2(to.y, Vector2(to.x, to.z).length()) / (PI * 0.5)
	_dock_dial.set_instance_shader_parameter("elev", elev)
	_set_text(_texts["dock"], "DOCK %d M" % int(dist))
	var near := dist <= Scout.DOCK_RANGE
	_set_text(_texts["dock2"], "[E] DOCK" if near else ("ABOVE" if elev > 0.3 else ("BELOW" if elev < -0.3 else "")))
	(_texts["dock2"] as Label3D).modulate = Color(0.55, 1.4, 0.6) if near else GREEN


## The markers on the glass, for the local pilot: the crosshair over the alien held in the sight
## (closing in until it is locked on, with the distance) and the dock's marker while it is in view.
func _update_marks(local: bool) -> void:
	var xf := scout.get_global_transform_interpolated()
	var eye := xf * EYE
	_lock_mark.visible = local and is_instance_valid(target)
	if _lock_mark.visible:
		var at := target.get_global_transform_interpolated().origin
		_place_mark(_lock_mark, xf, at)
		_lock_quad.set_instance_shader_parameter("progress", lock)
		var dist := int(eye.distance_to(at))
		_lock_label.text = "LOCK %d M" % dist if lock >= 1.0 else "SEEK %d M" % dist
		_lock_label.modulate = Color(1.5, 0.3, 0.2) if lock >= 1.0 else Color(1.4, 0.9, 0.3)
	_dock_mark.visible = false
	if local and Game.mission and Game.mission.ship:
		var dock := scout.dock_transform().origin
		var dir := xf.basis.inverse() * (dock - eye)
		if dir.normalized().dot(Vector3.FORWARD) > 0.5:
			_dock_mark.visible = true
			_place_mark(_dock_mark, xf, dock)
			var dist := eye.distance_to(dock)
			_dock_label.text = "[E] DOCK" if dist <= Scout.DOCK_RANGE else "DOCK %d M" % int(dist)


## Put a glass marker where the line from the eye to `world` meets the canopy, facing the eye.
func _place_mark(mark: Node3D, xf: Transform3D, world: Vector3) -> void:
	var dir := (xf.affine_inverse() * world - EYE).normalized()
	var up := Vector3.UP if absf(dir.y) < 0.95 else Vector3.BACK
	mark.transform = Transform3D(Basis.looking_at(dir, up), EYE + dir * glass_distance(dir) * GLASS_INSET)
