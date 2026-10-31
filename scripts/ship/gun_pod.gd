class_name GunPod
extends Turret
## A manned gun: a glass pod with the gunner's seat, a control panel and a reflector sight inside,
## and a twin heavy machine gun on each side of it (two barrels over and under). The gunner sits in
## it in first person. The pod, its guns and the sight swing together, so the sight's glowing ring
## always marks where the four barrels' fire converges (see Mothership._fire_round).
##
## Built in the pitch frame: the ball's centre is on the pitch axis, -Z forward. The ship simulates
## the gun (rounds, heat, belt changes) and hands its state over through set_state(); the pod shows
## it in the world: the ammo counter and heat gauge on top of the control panel and their lamps,
## barrels glowing when hot, muzzle flashes, spent casings, smoke, and the belt being changed.
##
## A pod can carry the Multiple Rocket Launcher System instead ("mrls", mounted at its gun console
## from a crate; see WEAPONS and set_weapon()): a launcher box either side of the pod in place of the
## guns, eight rockets in each. Held down, the trigger looses a rocket from each box in turn (the
## rockets scatter wide, fly a little crooked and home in on an alien once they come close; see
## Projectiles), and the empty tubes are reloaded one rocket at a time. The screens then show the
## rockets left and the loader's progress.

## The heavy machine gun: seconds between rounds (the four barrels take turns), damage per round,
## muzzle velocity (m/s) and scatter (degrees). A belt holds BELT rounds. Once it runs dry a new
## one is loaded by itself, which takes RELOAD_TIME seconds.
const FIRE_INTERVAL := 0.066
const DAMAGE := 7.0
const SPEED := 170.0
const SPREAD := 0.9
const BELT := 240
const RELOAD_TIME := 4.0
## Heat (0..1): every round adds HEAT_PER_ROUND, and it bleeds off at HEAT_COOL per second (faster
## with turret coolant). A round that pushes it past full damages the ship's weapon systems by
## OVERHEAT_DAMAGE. The gauge turns amber at HEAT_WARN.
const HEAT_PER_ROUND := 0.02
const HEAT_COOL := 0.18
const HEAT_WARN := 0.75
const OVERHEAT_DAMAGE := 0.5
## The barrels' fire converges on whatever is under the sight, at least CONVERGE_MIN and at most
## CONVERGE_MAX metres out.
const CONVERGE_MIN := 12.0
const CONVERGE_MAX := 160.0
## The pod follows the gunner's aim at most this fast (rad/s): it is heavy.
const TURN_RATE := 2.4
## Smoke: the barrels start to smoke at SMOKE_FROM heat and smoke hardest at full heat; firing
## puffs smoke out of the muzzles too, more the hotter the barrels are.
const SMOKE_FROM := 0.3
## The traversing motors' low whine (dB at full swing; others hear it from the pod).
const SERVO_DB := -10.0
## The guns' bark rises in pitch as the barrels heat up, smoothly, to this at full heat.
const HOT_PITCH := 1.25

## What a pod can carry: mounted at its gun console from a crate ("weapon:<id>", RunItems), the name,
## the shop's line and the base price.
const WEAPONS := {
	"hmg": {"name": "Heavy Machine Gun", "short": "Four barrels firing in turn from a 240-round belt; heats up as it fires", "price": 90},
	"mrls": {"name": "Multiple Rocket Launcher", "short": "Sixteen rockets in two boxes: a wild salvo that homes in close, slow to reload", "price": 240},
}
## The Multiple Rocket Launcher System: MRLS_TUBES rockets in all, a rocket every MRLS_INTERVAL
## seconds while the trigger is held (the two boxes taking turns), MRLS_DAMAGE each (a direct hit; its
## blast hurts round it, see Projectiles.ROCKET_*), leaving the tube at MRLS_SPEED m/s up to
## MRLS_SPREAD degrees off the sight's line; the loader puts a rocket back in an empty tube every
## MRLS_LOAD seconds, one at a time.
const MRLS_TUBES := 16
const MRLS_INTERVAL := 0.12
const MRLS_DAMAGE := 38.0
const MRLS_SPEED := 30.0
const MRLS_SPREAD := 5.5
const MRLS_LOAD := 0.8
## The launcher boxes (tools/blender/mrls.py): their middles across, the tubes' columns either side of
## that and rows top to bottom, the front and back faces.
const MRLS_BOX_X := 1.31
const MRLS_COLS := [-0.095, 0.095]
const MRLS_ROWS := [0.24, 0.08, -0.08, -0.24]
const MRLS_FRONT := -0.62
const MRLS_BACK := 0.48
## The launcher model (res://assets/models/mrls).
const MRLS_ASSET := "mrls"

## Ball radius and the gunner's eye (pitch frame).
const RADIUS := 1.05
const EYE := Vector3(0, 0.18, -0.02)
## The barrels in firing order (left top, right top, left bottom, right bottom): where each one
## starts, just in front of its receiver. Each is BARREL_LEN long to the muzzle.
const BARRELS := [Vector3(-1.27, 0.12, -0.45), Vector3(1.27, 0.12, -0.45), Vector3(-1.27, -0.12, -0.45), Vector3(1.27, -0.12, -0.45)]
const BARREL_LEN := 2.0
## The mount under the pod (ShipBuilder) reaches up to MOUNT_TOP below the ball's centre. A pod out
## beside the hull stands on a column from an arm TOWER_DROP below its centre: low enough that the
## barrels never sweep through the arm, whichever way the pod points.
const MOUNT_TOP := 1.02
const TOWER_DROP := 2.7

## The windows' glass (the pods' and the cockpits'): tinted, smudged, grime gathered low down and a
## few scratches; lit as dirty glass (GLASS_LIGHT).
const GLASS_SHADER := """
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never;
uniform vec3 tint : source_color = vec3(0.55, 0.7, 0.68);
uniform vec3 grime_color : source_color = vec3(0.16, 0.13, 0.09);
// Grime gathers low down on the glass: fully below grime_lo, none above grime_hi (local height).
uniform float grime_lo = -1.0;
uniform float grime_hi = 0.0;
varying vec3 lp;
varying float glass_film;
varying float glass_alpha;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
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

void vertex() {
	lp = VERTEX;
}

void fragment() {
	float fres = pow(1.0 - clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 4.0);
	float n = vnoise(lp * 6.0) * 0.6 + vnoise(lp * 21.0) * 0.4;
	// Smudges, and grime gathering low down on the glass.
	float grime = smoothstep(0.62, 0.92, n) * 0.6 + (1.0 - smoothstep(grime_lo, grime_hi, lp.y)) * n * 0.55;
	grime = clamp(grime, 0.0, 1.0);
	// A few fine scratches.
	float s = abs(fract(lp.x * 7.0 - lp.y * 2.0 + vnoise(lp * 2.5) * 3.0) - 0.5);
	float scratch = (1.0 - smoothstep(0.0, 0.012, s)) * step(0.78, vnoise(lp * 9.0 + 4.0));
	ALBEDO = mix(tint * 0.12, grime_color, grime);
	ROUGHNESS = mix(0.05, 0.6, grime);
	float a = clamp(0.035 + fres * 0.45 + grime * 0.3 + scratch * 0.18, 0.0, 0.9);
	ALPHA = a;
	glass_alpha = a;
	// (A faint film of dust all over, as well as the grime.)
	glass_film = clamp(0.05 + grime + scratch * 0.4, 0.0, 1.0);
}
"""

## How light falls on dirty glass, shared by the windows (GLASS_SHADER), the scout's canopy and the
## helmet's visor; each of those shaders sets `glass_film` (how much grease, grime, fog or cracking
## there is: 0..1) and `glass_alpha` (its ALPHA) in fragment(). Glass mirrors a lamp as a dim copy
## of it (about 4% of it, head on) and grease smears that copy out; and a lamp beyond the glass
## shines through it, the grease scattering some of that light on to the eye, mostly close round
## the lamp, so the smears round it light up (a dirty windscreen at night):
## - A light on the eye's side of the glass: a soft glint off clean glass (its lobe never sharper
##   than GLINT_ROUGH, so never a pinpoint), spread into a dull sheen by the grease and never much
##   brighter than GLINT_MAX on screen; the grease is lit as well. With HELMET_VISOR defined nothing
##   on the eye's side reaches the glass at all: the helmet round it stops that light.
## - A light on the far side: the grease scatters GLARE of it on to the eye, nearly all of it
##   within a few degrees of the line from the eye to the light, and a little in a wider halo. It
##   fades out where the light grazes the glass (its cosine under GRAZE), so a curved pane lit
##   from the side shows no hard line where the glass turns edge-on to it.
## The light added is divided by the glass's alpha, since blending it in multiplies it by that.
const GLASS_LIGHT := """
const float GLINT_MAX = 0.5;
const float GLINT_ROUGH = 0.12;
const float GLARE = 0.25;
const float GRAZE = 0.4;

// The Henyey-Greenstein phase function: the share of the light the grease scatters that leaves it at
// an angle (cosine c) from the way it was going; g is how much of it keeps going forward.
float glass_phase(float c, float g) {
	float gg = g * g;
	return (1.0 - gg) / (12.566371 * pow(max(1.0 + gg - 2.0 * g * c, 0.0001), 1.5));
}

void light() {
	vec3 lc = LIGHT_COLOR * ATTENUATION;
	// (Both faces are drawn: NORMAL always faces the eye.)
	float nl = dot(NORMAL, LIGHT);
	float a = max(glass_alpha, 0.005);
	if (nl > 0.0) {
#ifndef HELMET_VISOR
		float r = max(ROUGHNESS, GLINT_ROUGH);
		float r2 = r * r;
		float a2 = r2 * r2;
		vec3 h = normalize(LIGHT + VIEW);
		float nh = max(dot(NORMAL, h), 0.0);
		float nv = max(dot(NORMAL, VIEW), 0.02);
		float dd = nh * nh * (a2 - 1.0) + 1.0;
		float d = a2 / (PI * dd * dd);
		float k = r2 * 0.5;
		float vis = 0.25 / ((nl * (1.0 - k) + k) * (nv * (1.0 - k) + k));
		float f = 0.04 + 0.96 * pow(1.0 - clamp(dot(LIGHT, h), 0.0, 1.0), 5.0);
		vec3 glint = lc * SPECULAR_AMOUNT * d * vis * f * nl;
		SPECULAR_LIGHT += GLINT_MAX * (vec3(1.0) - exp(-glint / GLINT_MAX)) / a;
		DIFFUSE_LIGHT += lc * nl / PI;
#endif
	} else {
		float c = dot(-LIGHT, VIEW);
		float ph = glass_phase(c, 0.9) * 0.8 + glass_phase(c, 0.6) * 0.2;
		// Light grazing the glass mostly glances off it instead of going through, so the glare fades
		// out towards where the glass turns edge-on to the light (no hard line across a curved pane
		// lit from the side).
		float through = smoothstep(0.0, GRAZE, -nl);
		SPECULAR_LIGHT += lc * glass_film * ph * GLARE * through / a;
	}
}
"""

## The reflector sight's reticle: a ring, a centre dot and a broken cross, glowing amber.
const SIGHT_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec3 color : source_color = vec3(1.0, 0.5, 0.12);
uniform float energy = 3.0;
instance uniform float power = 1.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float w = fwidth(r) * 1.5;
	float ring = 1.0 - smoothstep(0.018, 0.018 + w, abs(r - 0.6));
	float dot_c = 1.0 - smoothstep(0.035, 0.035 + w, r);
	float ax = abs(p.x);
	float ay = abs(p.y);
	float bars = (1.0 - smoothstep(0.012, 0.012 + fwidth(ay) * 1.5, ay)) * step(0.18, ax) * (1.0 - smoothstep(0.84, 0.9, ax));
	bars += (1.0 - smoothstep(0.012, 0.012 + fwidth(ax) * 1.5, ax)) * step(0.18, ay) * (1.0 - smoothstep(0.84, 0.9, ay));
	float a = clamp(ring + dot_c + bars, 0.0, 1.0);
	float halo = exp(-r * 5.0) * 0.05;
	ALBEDO = color * energy * power * (a + halo);
	ALPHA = clamp(a + halo, 0.0, 1.0);
}
"""

## The green screens on the control panel: scanlines, a dark vignette and a faint flicker.
const CRT_SHADER := """
shader_type spatial;
render_mode unshaded;
uniform vec3 glow : source_color = vec3(0.12, 0.6, 0.2);
instance uniform float power = 1.0;
void fragment() {
	float scan = 0.75 + 0.25 * sin(UV.y * 260.0);
	float vig = 1.0 - smoothstep(0.35, 0.75, length((UV - 0.5) * vec2(1.0, 1.6)));
	float flick = 0.95 + 0.05 * sin(TIME * 53.0) * sin(TIME * 7.3);
	ALBEDO = glow * 0.1 * power * scan * (0.35 + 0.65 * vig) * flick;
}
"""

const FLASH_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec3 color : source_color = vec3(1.0, 0.62, 0.25);
uniform float energy = 6.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float a = pow(clamp(1.0 - length(p), 0.0, 1.0), 1.5);
	ALBEDO = color * energy * a;
	ALPHA = 1.0;
}
"""

## The Blender-made model (res://assets/models/gun_pod).
const ASSET := "gun_pod"

const GREEN := Color(0.45, 1.35, 0.5)
const AMBER := Color(1.4, 0.85, 0.2)
const RED := Color(1.5, 0.3, 0.2)

static var _shared: Dictionary = {}

## The ship's colours (set before build()): the shell and the trim on the collar.
var paint := Color(0.36, 0.38, 0.36)
var accent := Color(0.95, 0.6, 0.15)
## Where the gunner's eye is (the camera of the crew member in the pod follows it).
var eye: Node3D
## What the pod shows (see set_state()).
var ammo := BELT
var heat := 0.0
var reload_left := 0.0
var online := true
## The ship itself is in the line of fire: the interrupter holds the guns (Mothership.fire_masked).
var masked := false
var _sys_hp := 100.0
## The local crew member is the gunner: sounds play in 2D and the view shakes.
var _local := false
var _barrel_nodes: Array[Node3D] = []
var _recoil: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _flashes: Array[MeshInstance3D] = []
var _flash_t: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _lights: Array[OmniLight3D] = []
var _casings: Array[CPUParticles3D] = []
## Smoke rising off each barrel, and puffing from each muzzle while firing (their process
## materials are shared by the four barrels).
var _smoke: Array[GPUParticles3D] = []
var _puffs: Array[GPUParticles3D] = []
var _smoke_pm: ParticleProcessMaterial
var _puff_pm: ParticleProcessMaterial
var _sparks: CPUParticles3D
var _barrel_mat: StandardMaterial3D
var _screens: Array[MeshInstance3D] = []
var _reticle: MeshInstance3D
var _ammo_label: Label3D
var _ammo_note: Label3D
var _heat_note: Label3D
var _sys_label: Label3D
var _ammo_segs: Array[MeshInstance3D] = []
var _heat_segs: Array[MeshInstance3D] = []
## Lamp name -> its material ("ready", "belt", "heat", "sys").
var _lamps: Dictionary = {}
var _figure: Node3D
var _visor_mat: StandardMaterial3D
var _servo: AudioStreamPlayer3D
var _servo_level := 0.0
var _last_aim := Vector2.ZERO
var _since_shot := 10.0
var _kick := 0.0
var _hot_t := 0.0
var _beep := 0.0
var _clock := 0.0
## Text and segment counts on the screens, so they are only rebuilt when they change.
var _shown: Dictionary = {}
## What the pod carries ("hmg" or "mrls", see WEAPONS), and the captions that change with it.
var weapon := "hmg"
var _captions: Dictionary = {}
## The rocket launchers (built the first time the pod carries them): the boxes, the rockets showing in
## their tubes (one MultiMesh), the tube that fires next, and the flash and smoke of a launch.
var _launchers: Node3D
var _tube_rockets: MultiMesh
var _next_tube := 0
var _shown_tubes := Vector2i(-1, -1)
var _launch_flash: Array[MeshInstance3D] = []
var _launch_light: OmniLight3D
var _launch_t := 0.0
var _backblast: Array[GPUParticles3D] = []
var _paint_tint := Color.WHITE


func build(def: Dictionary) -> void:
	read_mount(def)
	muzzle = Vector3(0, 0, (BARRELS[0] as Vector3).z - BARREL_LEN)
	camera_offset = EYE
	var heavy := style == "heavy"
	# The ball, its frame, the receivers and the cabin are a Blender-made model (tools/blender/
	# gun_pod.py), its shell painted in the ship's colour. The glass, the sight's glass and the
	# instruments are made here.
	var tint := {"Paint": paint.darkened(0.45 if heavy else 0.3)}
	_paint_tint = tint["Paint"]
	Models.asset_mesh(pitch_pivot, ASSET, "Pod", tint)
	if heavy:
		Models.asset_mesh(pitch_pivot, ASSET, "Armour", tint)
	var b := Models.Batch.new()
	b.add(_hemisphere(RADIUS, true), Transform3D.IDENTITY, _glass_mat())
	_build_guns()
	_build_cabin(b)
	for mi in b.commit(pitch_pivot, "Glass", false):
		if mi.material_override == _glass_mat():
			mi.layers = Game.VIS_GLASS
	_build_displays()
	_build_collar()
	_build_figure()
	eye = Node3D.new()
	eye.name = "Eye"
	eye.position = EYE
	pitch_pivot.add_child(eye)
	# A dim cabin lamp overhead: enough to pick out the frame and the panel.
	var lamp := OmniLight3D.new()
	lamp.position = Vector3(0, 0.55, 0.1)
	lamp.omni_range = 2.5
	lamp.omni_attenuation = 0.7
	lamp.light_energy = 1.2
	lamp.light_color = Color(1.0, 0.82, 0.58)
	pitch_pivot.add_child(lamp)
	_servo = AudioStreamPlayer3D.new()
	_servo.stream = Sfx.stream("pod_servo")
	_servo.position = Vector3(0, -0.75, 0)
	_servo.unit_size = 5.0
	yaw_pivot.add_child(_servo)
	Sfx.track(_servo)


## The muzzle lights, ejected casings and smoke from hot barrels of the two guns, and the four
## barrels (the receivers are part of the pod's model).
func _build_guns() -> void:
	var brass := Models.mat(Color(0.78, 0.58, 0.26), 0.85, 0.35)
	for s: float in [-1.0, 1.0]:
		var x := s * 1.27
		var light := OmniLight3D.new()
		light.position = Vector3(x, 0, -2.75)
		light.omni_range = 5.5
		light.light_energy = 0.0
		light.light_color = Color(1.0, 0.68, 0.32)
		pitch_pivot.add_child(light)
		_lights.append(light)
		var casings := CPUParticles3D.new()
		casings.position = Vector3(x, -0.25, -0.15)
		casings.emitting = false
		casings.amount = 6
		casings.lifetime = 0.75
		var case_mesh := CylinderMesh.new()
		case_mesh.top_radius = 0.011
		case_mesh.bottom_radius = 0.011
		case_mesh.height = 0.05
		case_mesh.radial_segments = 6
		case_mesh.rings = 1
		case_mesh.material = brass
		casings.mesh = case_mesh
		casings.direction = Vector3(s * 0.4, -1.0, 0.25)
		casings.spread = 18.0
		casings.initial_velocity_min = 1.6
		casings.initial_velocity_max = 2.6
		casings.gravity = Vector3(0, -9.0, 0)
		casings.angular_velocity_min = -720.0
		casings.angular_velocity_max = 720.0
		casings.particle_flag_rotate_y = true
		pitch_pivot.add_child(casings)
		_casings.append(casings)
	_smoke_pm = _smoke_process(false)
	_puff_pm = _smoke_process(true)
	# The bare barrels and flash hiders glow when hot: the model's "Hot" material with emission.
	_barrel_mat = (Models.asset_material(ASSET, "BarrelHot", "Hot") as StandardMaterial3D).duplicate()
	_barrel_mat.emission_enabled = true
	_barrel_mat.emission = Color(0.9, 0.18, 0.04)
	_barrel_mat.emission_energy_multiplier = 0.0
	for i in BARRELS.size():
		var node := Node3D.new()
		node.position = BARRELS[i]
		pitch_pivot.add_child(node)
		_barrel_nodes.append(node)
		# Perforated cooling jacket, the bare barrel inside it and a slotted flash hider.
		Models.asset_mesh(node, ASSET, "Barrel", {}, Transform3D.IDENTITY, false)
		Models.asset_mesh(node, ASSET, "BarrelHot", {"Hot": _barrel_mat}, Transform3D.IDENTITY, false)
		var flash := MeshInstance3D.new()
		flash.mesh = _flash_mesh()
		flash.material_override = _flash_mat()
		flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flash.position = Vector3(0, 0, -BARREL_LEN)
		flash.visible = false
		node.add_child(flash)
		_flashes.append(flash)
		# Smoke off the whole hot barrel, and from the muzzle while it fires.
		var smoke := _smoke_emitter(_smoke_pm, 28, 2.6)
		smoke.position = Vector3(0, 0.02, -1.05)
		node.add_child(smoke)
		_smoke.append(smoke)
		var puff := _smoke_emitter(_puff_pm, 18, 1.5)
		puff.position = Vector3(0, 0, -BARREL_LEN - 0.05)
		node.add_child(puff)
		_puffs.append(puff)


## The reflector sight's glass and glowing reticle, and the sparks off the panel when the guns
## overheat (the seat, the panel and the sight's housing are part of the pod's model).
func _build_cabin(b: Models.Batch) -> void:
	b.add(_box_mesh(Vector3(0.12, 0.11, 0.004)), Transform3D(Basis(Vector3.RIGHT, deg_to_rad(40.0)), Vector3(0, 0.18, -0.45)),
		Models.glass(Color(0.75, 0.8, 0.7, 0.1)))
	_reticle = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.1, 0.1)
	_reticle.mesh = quad
	_reticle.material_override = _sight_mat()
	_reticle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_reticle.position = Vector3(0, EYE.y, EYE.z - 0.42)
	pitch_pivot.add_child(_reticle)
	_sparks = CPUParticles3D.new()
	_sparks.position = Vector3(0, -0.24, -0.62)
	_sparks.emitting = false
	_sparks.one_shot = true
	_sparks.explosiveness = 1.0
	_sparks.amount = 14
	_sparks.lifetime = 0.35
	var spark := BoxMesh.new()
	spark.size = Vector3(0.006, 0.03, 0.006)
	spark.material = Models.glow(Color(1.6, 1.0, 0.4))
	_sparks.mesh = spark
	_sparks.particle_flag_align_y = true
	_sparks.direction = Vector3(0, 1, 0.4)
	_sparks.spread = 60.0
	_sparks.initial_velocity_min = 1.0
	_sparks.initial_velocity_max = 2.5
	_sparks.gravity = Vector3(0, -6.0, 0)
	pitch_pivot.add_child(_sparks)


## On the display housing on top of the control panel (part of the pod's model): the ammo counter
## and the heat gauge on two green screens, the lamps either side of them and a stencilled placard
## below.
func _build_displays() -> void:
	var disp := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-23.0)), Vector3(0, -0.13, -0.745))
	for x: float in [-0.228, 0.228]:
		var screen := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(0.31, 0.145)
		screen.mesh = quad
		screen.material_override = _crt_mat()
		screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		screen.transform = disp * Transform3D(Basis.IDENTITY, Vector3(x, -0.01, 0.054))
		pitch_pivot.add_child(screen)
		_screens.append(screen)
	# Ammo screen (left) and heat screen (right).
	var top := 0.045
	_captions["ammo"] = _label(disp, Vector3(-0.373, top, 0.056), "AMMO", 26, GREEN, HORIZONTAL_ALIGNMENT_LEFT)
	_ammo_note = _label(disp, Vector3(-0.083, top, 0.056), "READY", 26, GREEN, HORIZONTAL_ALIGNMENT_RIGHT)
	_ammo_label = _label(disp, Vector3(-0.255, -0.008, 0.056), "%03d" % BELT, 92, GREEN)
	_captions["unit"] = _label(disp, Vector3(-0.122, -0.022, 0.056), "RDS", 22, GREEN)
	_captions["heat"] = _label(disp, Vector3(0.083, top, 0.056), "BARREL HEAT", 26, GREEN, HORIZONTAL_ALIGNMENT_LEFT)
	_sys_label = _label(disp, Vector3(0.373, top, 0.056), "SYS 100%", 26, GREEN, HORIZONTAL_ALIGNMENT_RIGHT)
	_heat_note = _label(disp, Vector3(0.228, -0.052, 0.056), "NORMAL", 30, GREEN)
	var stencil := Color(0.85, 0.82, 0.7)
	_label(disp, Vector3(-0.085, -0.094, 0.057), "LMB FIRE    RMB SIGHT", 18, stencil, HORIZONTAL_ALIGNMENT_RIGHT)
	_label(disp, Vector3(0.085, -0.094, 0.057), "E EXIT POD", 18, stencil, HORIZONTAL_ALIGNMENT_LEFT)
	for i in 10:
		_ammo_segs.append(_segment(disp, Vector3(-0.363 + i * 0.0285, -0.061, 0.055), Vector3(0.023, 0.014, 0.003)))
	for i in 12:
		_heat_segs.append(_segment(disp, Vector3(0.095 + i * 0.0245, -0.004, 0.055), Vector3(0.02, 0.04, 0.003)))
	for lamp: Array in [["ready", -0.418, 0.04, Color(0.3, 1.0, 0.35)], ["belt", -0.418, -0.03, Color(1.0, 0.65, 0.15)],
			["heat", 0.418, 0.04, Color(1.0, 0.18, 0.1)], ["sys", 0.418, -0.03, Color(1.0, 0.18, 0.1)]]:
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.05, 0.05, 0.05)
		m.emission_enabled = true
		m.emission = lamp[3]
		m.emission_energy_multiplier = 0.0
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.013
		sm.height = 0.026
		sm.radial_segments = 10
		sm.rings = 5
		mi.mesh = sm
		mi.material_override = m
		mi.transform = disp * Transform3D(Basis.IDENTITY, Vector3(float(lamp[1]), float(lamp[2]), 0.05))
		pitch_pivot.add_child(mi)
		_lamps[str(lamp[0])] = m


## The ring the ball sits in (it turns with the pod's yaw), on top of the mount, with a band in the
## ship's accent colour.
func _build_collar() -> void:
	Models.asset_mesh(yaw_pivot, ASSET, "Collar", {"Accent": accent})


## A figure of the gunner, seen by everyone else while someone sits in the pod.
func _build_figure() -> void:
	_figure = Node3D.new()
	_figure.visible = false
	pitch_pivot.add_child(_figure)
	var suit := Models.mat(Color(0.3, 0.32, 0.3), 0.2, 0.7)
	Models.capsule(_figure, Vector3(0, -0.22, 0.13), 0.17, 0.62, suit, Vector3(-12, 0, 0))
	Models.sphere(_figure, Vector3(0, 0.19, 0.03), 0.13, Models.mat(Color(0.78, 0.79, 0.8), 0.3, 0.4))
	_visor_mat = StandardMaterial3D.new()
	_visor_mat.albedo_color = Color(0.05, 0.08, 0.1)
	_visor_mat.emission_enabled = true
	_visor_mat.emission_energy_multiplier = 1.5
	Models.sphere(_figure, Vector3(0, 0.18, -0.06), 0.1, _visor_mat, Vector3(1.0, 0.6, 0.7))
	for x: float in [-0.19, 0.19]:
		Models.strut(_figure, Vector3(x, 0.02, 0.08), Vector3(x, -0.24, -0.4), 0.05, suit)


## Text on the display housing (frame `disp`) in a plain monospace face, like an old terminal.
## `align` anchors it at `pos` by its left edge, centre or right edge.
func _label(disp: Transform3D, pos: Vector3, text: String, size: int, color: Color, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label3D:
	var l := Label3D.new()
	l.font = _mono()
	l.text = text
	l.font_size = size
	l.pixel_size = 0.00062
	l.outline_size = 0
	l.modulate = color
	l.double_sided = false
	l.set_meta("frame", disp)
	l.set_meta("anchor", pos)
	l.set_meta("align", align)
	pitch_pivot.add_child(l)
	_place(l)
	return l


## A Label3D centres its text on its origin whatever the alignment, so a label anchored by an edge
## is moved by half its width whenever its text changes.
func _place(l: Label3D) -> void:
	var pos: Vector3 = l.get_meta("anchor")
	var w := l.font.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, l.font_size).x * l.pixel_size
	match int(l.get_meta("align")):
		HORIZONTAL_ALIGNMENT_LEFT:
			pos.x += w * 0.5
		HORIZONTAL_ALIGNMENT_RIGHT:
			pos.x -= w * 0.5
	l.transform = (l.get_meta("frame") as Transform3D) * Transform3D(Basis.IDENTITY, pos)


func _segment(disp: Transform3D, pos: Vector3, size: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _box_mesh(size)
	mi.material_override = _seg_mat(0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.transform = disp * Transform3D(Basis.IDENTITY, pos)
	pitch_pivot.add_child(mi)
	return mi


# --- Aim and geometry (ship-local) ------------------------------------------------------------

## Where barrel `i`'s muzzle is for an aim.
func barrel_muzzle_local(a: Vector2, i: int) -> Vector3:
	return transform.origin + aim_basis_local(a) * ((BARRELS[i] as Vector3) + Vector3(0, 0, -BARREL_LEN))


## The gunner's eye for an aim (also where the sight looks from).
func eye_local(a: Vector2) -> Vector3:
	return transform.origin + aim_basis_local(a) * EYE


# --- State and effects -------------------------------------------------------------------------

## The gun's state from the ship: rounds left, heat, seconds left of a belt change, the weapon
## systems' health and whether they are online, the colour of someone else sitting in the pod
## (alpha 0: nobody, or it is us) and whether the local crew member is the gunner. Carrying rockets:
## the rockets loaded, the seconds left until the loader puts the next one in, and `tube`, the tube
## that fires next.
func set_state(rounds: int, heat_now: float, reload_now: float, sys_hp: float, sys_online: bool, figure: Color, local: bool, tube := -1) -> void:
	_local = local
	if weapon == "mrls":
		if tube >= 0:
			_next_tube = tube
		if rounds > ammo:
			_sound("clunk", -9.0)
	elif reload_now > 0.0 and reload_left <= 0.0:
		_sound("belt_out", -3.0)
	elif reload_now <= 0.0 and reload_left > 0.0:
		_sound("belt_in", -1.0)
	ammo = rounds
	heat = heat_now
	reload_left = reload_now
	_sys_hp = sys_hp
	online = sys_online
	_figure.visible = figure.a > 0.0
	if _figure.visible:
		_visor_mat.emission = figure


## Show what the pod carries (WEAPONS): the heavy machine gun's barrels, or the rocket launchers'
## boxes (built the first time), and the screens' captions to go with it.
func set_weapon(id: String) -> void:
	if id == weapon or not WEAPONS.has(id):
		return
	weapon = id
	var rockets := id == "mrls"
	if rockets and _launchers == null:
		_build_launchers()
	if _launchers:
		_launchers.visible = rockets
	for n in _barrel_nodes:
		n.visible = not rockets
	for l in _lights:
		l.light_energy = 0.0
	_next_tube = 0
	_shown_tubes = Vector2i(-1, -1)
	_shown.clear()
	_show(_captions["ammo"], "ROCKETS" if rockets else "AMMO", GREEN)
	_show(_captions["unit"], "RKT" if rockets else "RDS", GREEN)
	_show(_captions["heat"], "LOADER" if rockets else "BARREL HEAT", GREEN)


## Where tube `t`'s mouth is (pitch frame), `t` in firing order: the left and right boxes in turn,
## each from the top row down, the inner tube of a row before the outer.
static func mrls_mouth(t: int) -> Vector3:
	var s := -1.0 if t % 2 == 0 else 1.0
	var slot := t / 2
	var col := float(MRLS_COLS[0]) if slot % 2 == 0 else float(MRLS_COLS[1])
	return Vector3(s * (MRLS_BOX_X + col), float(MRLS_ROWS[slot / 2]), MRLS_FRONT)


## The rocket launchers (a Blender-made model, tools/blender/mrls.py, in the ship's paint): a box
## either side over the receivers, the rockets in their tubes (their noses show in the mouths), and
## a launch's flash, light and backblast.
func _build_launchers() -> void:
	_launchers = Node3D.new()
	_launchers.name = "Launchers"
	pitch_pivot.add_child(_launchers)
	Models.asset_mesh(_launchers, MRLS_ASSET, "Launchers", {"Paint": _paint_tint})
	_tube_rockets = MultiMesh.new()
	_tube_rockets.transform_format = MultiMesh.TRANSFORM_3D
	_tube_rockets.mesh = _rocket_mesh()
	_tube_rockets.instance_count = MRLS_TUBES
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = _tube_rockets
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_launchers.add_child(mmi)
	for k in 2:
		var f := MeshInstance3D.new()
		f.mesh = _flash_mesh()
		f.material_override = _flash_mat()
		f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		f.visible = false
		_launchers.add_child(f)
		_launch_flash.append(f)
	_launch_light = OmniLight3D.new()
	_launch_light.omni_range = 6.0
	_launch_light.light_energy = 0.0
	_launch_light.light_color = Color(1.0, 0.62, 0.3)
	_launchers.add_child(_launch_light)
	var pm := _smoke_process(true)
	pm.direction = Vector3(0, 0, 1)
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.16, 0.3, 0.02)
	for s: float in [-1.0, 1.0]:
		var smoke := _smoke_emitter(pm, 22, 1.6)
		smoke.position = Vector3(s * MRLS_BOX_X, 0, MRLS_BACK + 0.05)
		_launchers.add_child(smoke)
		_backblast.append(smoke)


## The rockets showing in the tubes: the `ammo` loaded ones, from the tube that fires next on (in
## firing order); an empty tube shows its dark mouth.
func _show_tubes() -> void:
	if _tube_rockets == null or _shown_tubes == Vector2i(ammo, _next_tube):
		return
	_shown_tubes = Vector2i(ammo, _next_tube)
	var hidden := Transform3D(Basis.from_scale(Vector3.ONE * 0.0001), Vector3.ZERO)
	for k in MRLS_TUBES:
		var t := (_next_tube + k) % MRLS_TUBES
		var mouth := mrls_mouth(t)
		_tube_rockets.set_instance_transform(t, Transform3D(Basis.IDENTITY, mouth + Vector3(0, 0, -0.08)) if k < ammo else hidden)


## A rocket as it shows in its tube, its nose's tip at the origin and its body running back along +Z:
## an olive body and a dull red nose (two surfaces), shared.
static func _rocket_mesh() -> ArrayMesh:
	if _shared.has("rocket"):
		return _shared["rocket"]
	var mesh := ArrayMesh.new()
	var body := CylinderMesh.new()
	body.top_radius = 0.05
	body.bottom_radius = 0.05
	body.height = 0.16
	body.radial_segments = 14
	body.rings = 1
	var nose := CylinderMesh.new()
	nose.top_radius = 0.004
	nose.bottom_radius = 0.05
	nose.height = 0.12
	nose.radial_segments = 14
	nose.rings = 1
	# (Cylinders stand along +Y; turned, +Y points forward, down -Z.)
	var turn := Basis(Vector3.RIGHT, -PI / 2.0)
	for part: Array in [[body, Transform3D(turn, Vector3(0, 0, 0.2)), Models.mat(Color(0.3, 0.33, 0.22), 0.3, 0.6)],
			[nose, Transform3D(turn, Vector3(0, 0, 0.06)), Models.mat(Color(0.55, 0.13, 0.08), 0.35, 0.5)]]:
		var st := SurfaceTool.new()
		st.append_from(part[0], 0, part[1])
		st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, part[2])
	_shared["rocket"] = mesh
	return mesh


## Barrel `i` fires a round (carrying rockets: tube `i` looses its rocket). `hot`: it was fired at
## full heat (the weapon systems take damage). `local`: the local crew member is the gunner.
func fire_fx(i: int, hot: bool, local: bool) -> void:
	if weapon == "mrls":
		_launch_fx(i, local)
		return
	if i < 0 or i >= _barrel_nodes.size():
		return
	_local = local
	_recoil[i] = 1.0
	_flash_t[i] = 0.05
	var flash := _flashes[i]
	flash.visible = true
	flash.rotation = Vector3(0, 0, randf() * TAU)
	flash.scale = Vector3.ONE * randf_range(0.75, 1.25)
	flash.reset_physics_interpolation()
	_lights[0 if (BARRELS[i] as Vector3).x < 0.0 else 1].light_energy = randf_range(2.2, 3.2)
	_since_shot = 0.0
	# The bark rises in pitch as the barrels heat up.
	var pitch := lerpf(1.0, HOT_PITCH, heat)
	if local:
		_kick = 1.0
		Sfx.play("hmg", null, -7.0, pitch)
	else:
		Sfx.play("hmg", _barrel_nodes[i].global_transform * Vector3(0, 0, -BARREL_LEN), -2.0, pitch)
	if hot and _hot_t <= 0.0:
		_hot_t = 0.22
		_sparks.restart()
		_sound("sizzle", -5.0)


## Tube `t` looses its rocket: a flash at its mouth and a blast out of the back of its box, their
## light, the launch's whoosh. (The tube shows empty once the ship's state says so, see set_state.)
func _launch_fx(t: int, local: bool) -> void:
	if _launchers == null or t < 0 or t >= MRLS_TUBES:
		return
	_local = local
	var mouth := mrls_mouth(t)
	var front := _launch_flash[0]
	front.position = mouth
	front.rotation = Vector3(0, 0, randf() * TAU)
	front.scale = Vector3.ONE * randf_range(0.9, 1.3)
	front.visible = true
	var back := _launch_flash[1]
	back.position = Vector3(mouth.x, mouth.y, MRLS_BACK)
	back.rotation = Vector3(0, PI, randf() * TAU)
	back.scale = Vector3.ONE * randf_range(1.1, 1.6)
	back.visible = true
	_launch_light.position = mouth
	_launch_light.light_energy = 3.2
	_launch_t = 0.07
	_since_shot = 0.0
	if local:
		_kick = 1.0
		Sfx.play("missile_launch", null, -9.0, randf_range(1.15, 1.35))
	elif is_inside_tree():
		Sfx.play("missile_launch", pitch_pivot.global_transform * mouth, -3.0, randf_range(1.15, 1.35))


## How hard the gunner's view shakes from the guns right now (0..1).
func shake() -> float:
	return _kick


func _sound(id: String, db: float) -> void:
	if _local:
		Sfx.play(id, null, db - 3.0)
	elif is_inside_tree():
		Sfx.play(id, global_position, db)


func _physics_process(delta: float) -> void:
	_clock += delta
	_since_shot += delta
	_kick = maxf(0.0, _kick - delta * 9.0)
	_hot_t = maxf(0.0, _hot_t - delta)
	for i in _barrel_nodes.size():
		if _recoil[i] > 0.0:
			_recoil[i] = maxf(0.0, _recoil[i] - delta * 12.0)
			_barrel_nodes[i].position.z = (BARRELS[i] as Vector3).z + _recoil[i] * 0.07
		if _flash_t[i] > 0.0:
			_flash_t[i] -= delta
			if _flash_t[i] <= 0.0:
				_flashes[i].visible = false
	for l in _lights:
		l.light_energy = maxf(0.0, l.light_energy - delta * 60.0)
	for c in _casings:
		c.emitting = _since_shot < 0.1 and weapon == "hmg"
	if _launchers:
		_launch_t = maxf(0.0, _launch_t - delta)
		if _launch_t <= 0.0 and _launch_flash[0].visible:
			for f in _launch_flash:
				f.visible = false
		_launch_light.light_energy = maxf(0.0, _launch_light.light_energy - delta * 40.0)
		for s in _backblast:
			s.emitting = weapon == "mrls" and _since_shot < 0.15
			s.amount_ratio = 1.0
		if weapon == "mrls":
			_show_tubes()
	_update_smoke()
	# Hot barrels glow: dull red, then orange.
	var glow := clampf((heat - 0.3) / 0.7, 0.0, 1.0)
	_barrel_mat.emission = Color(0.9, 0.16, 0.03).lerp(Color(1.0, 0.5, 0.12), glow)
	_barrel_mat.emission_energy_multiplier = glow * glow * 2.6
	_update_servo(delta)
	_update_displays()
	if _local and heat >= 0.97 and _since_shot < 0.3:
		_beep -= delta
		if _beep <= 0.0:
			_beep = 0.32
			Sfx.play("overheat", null, -9.0)
	else:
		_beep = 0.0


## The barrels smoke more the hotter they are: wisps from SMOKE_FROM heat, thick and dark at full
## heat, and every burst puffs smoke out of the muzzles (thicker when hot).
func _update_smoke() -> void:
	var h := smoothstep(SMOKE_FROM, 1.0, heat)
	var firing := _since_shot < 0.12
	for s in _smoke:
		s.emitting = h > 0.01
		s.amount_ratio = maxf(h, 0.08)
	for p in _puffs:
		p.emitting = firing and weapon == "hmg"
		p.amount_ratio = lerpf(0.25, 1.0, heat)
	_smoke_pm.color = Color(1.0, 1.0, 1.0, lerpf(0.35, 1.0, h))
	_smoke_pm.scale_min = lerpf(0.6, 1.2, h)
	_smoke_pm.scale_max = lerpf(1.0, 2.1, h)
	_puff_pm.color = Color(1.0, 1.0, 1.0, lerpf(0.3, 0.9, heat))


## The traversing motors whine while the pod swings round: louder and higher the faster it turns.
func _update_servo(delta: float) -> void:
	var speed := aim_delta(_last_aim, aim).length() / maxf(delta, 0.001)
	_last_aim = aim
	_servo_level = move_toward(_servo_level, clampf(speed / TURN_RATE, 0.0, 1.0), delta * 6.0)
	if _servo_level > 0.03:
		if not _servo.playing:
			_servo.play()
		_servo.volume_db = linear_to_db(_servo_level) + SERVO_DB
		_servo.pitch_scale = 0.8 + 0.35 * _servo_level
	elif _servo.playing:
		_servo.stop()


func _update_displays() -> void:
	var blink := fmod(_clock, 0.5) < 0.25
	var fast := fmod(_clock, 0.24) < 0.12
	if weapon == "mrls":
		_update_rocket_displays(blink)
		return
	var reloading := reload_left > 0.0
	var progress := clampf(1.0 - reload_left / RELOAD_TIME, 0.0, 1.0)
	_show(_ammo_label, "---" if reloading else "%03d" % ammo, GREEN if ammo * 5 > BELT or reloading else AMBER)
	var note := "READY"
	var note_col := GREEN
	if not online:
		note = "NO POWER"
		note_col = RED
	elif reloading:
		note = "LOADING %d%%" % int(progress * 100.0)
		note_col = AMBER
	elif masked:
		note = "HULL IN LINE" if blink else ""
		note_col = AMBER
	_show(_ammo_note, note, note_col)
	var belt := int(ceil(float(ammo) / BELT * 10.0)) if not reloading else int(progress * 10.0)
	_fill(_ammo_segs, belt, "belt", func(_i: int) -> int: return 1)
	var lit := int(ceil(heat * _heat_segs.size() - 0.001))
	_fill(_heat_segs, lit, "heat", func(i: int) -> int: return 1 if i < 8 else (2 if i < 10 else 3))
	var hnote := "NORMAL"
	var hcol := GREEN
	if not online:
		hnote = "WEAPONS OFFLINE"
		hcol = RED
	elif heat >= 0.97:
		hnote = "OVERHEAT" if fast else ""
		hcol = RED
	elif heat >= HEAT_WARN:
		hnote = "HOT"
		hcol = AMBER
	elif heat > 0.05 and _since_shot > 0.4:
		hnote = "COOLING"
	_show(_heat_note, hnote, hcol)
	_show(_sys_label, "SYS %3d%%" % int(round(_sys_hp)), GREEN if _sys_hp >= 50.0 else (AMBER if online else RED))
	(_lamps["ready"] as StandardMaterial3D).emission_energy_multiplier = 3.0 if online and not reloading and heat < 0.97 and not masked else 0.0
	(_lamps["belt"] as StandardMaterial3D).emission_energy_multiplier = 3.0 if reloading and blink else 0.0
	(_lamps["heat"] as StandardMaterial3D).emission_energy_multiplier = 3.5 if (heat >= 0.97 and fast) or (heat >= HEAT_WARN and heat < 0.97 and blink) else 0.0
	(_lamps["sys"] as StandardMaterial3D).emission_energy_multiplier = 3.0 if not online or (_sys_hp < 50.0 and blink) else 0.0
	var power := 1.0 if online else 0.35
	for s in _screens:
		s.set_instance_shader_parameter("power", power)
	_reticle.set_instance_shader_parameter("power", 1.0 if online else 0.15)


## Carrying rockets: the rockets left (and a bar of them) on the left screen, the loader putting the
## next one into an empty tube on the right (its progress on the bar), and the lamps: ready, loading,
## weapon systems.
func _update_rocket_displays(blink: bool) -> void:
	var loading := reload_left > 0.0 and ammo < MRLS_TUBES
	_show(_ammo_label, "%02d" % ammo, GREEN if ammo > 4 else (AMBER if ammo > 0 else RED))
	var note := "READY"
	var note_col := GREEN
	if not online:
		note = "NO POWER"
		note_col = RED
	elif masked:
		note = "HULL IN LINE" if blink else ""
		note_col = AMBER
	elif ammo <= 0:
		note = "EMPTY" if blink else ""
		note_col = RED
	elif loading:
		note = "LOADING"
		note_col = AMBER
	_show(_ammo_note, note, note_col)
	_fill(_ammo_segs, int(ceil(float(ammo) / MRLS_TUBES * 10.0 - 0.001)), "belt", func(_i: int) -> int: return 1)
	var progress := clampf(1.0 - reload_left / MRLS_LOAD, 0.0, 1.0) if loading else 1.0
	_fill(_heat_segs, int(round(progress * _heat_segs.size())), "load" if loading else "full", func(_i: int) -> int: return 2 if loading else 1)
	var hnote := "FULL" if not loading else "LOADING %d/%d" % [mini(ammo + 1, MRLS_TUBES), MRLS_TUBES]
	_show(_heat_note, hnote if online else "WEAPONS OFFLINE", (AMBER if loading else GREEN) if online else RED)
	_show(_sys_label, "SYS %3d%%" % int(round(_sys_hp)), GREEN if _sys_hp >= 50.0 else (AMBER if online else RED))
	(_lamps["ready"] as StandardMaterial3D).emission_energy_multiplier = 3.0 if online and ammo > 0 and not masked else 0.0
	(_lamps["belt"] as StandardMaterial3D).emission_energy_multiplier = 3.0 if loading and blink else 0.0
	(_lamps["heat"] as StandardMaterial3D).emission_energy_multiplier = 0.0
	(_lamps["sys"] as StandardMaterial3D).emission_energy_multiplier = 3.0 if not online or (_sys_hp < 50.0 and blink) else 0.0
	var power := 1.0 if online else 0.35
	for s in _screens:
		s.set_instance_shader_parameter("power", power)
	_reticle.set_instance_shader_parameter("power", 1.0 if online else 0.15)


func _show(l: Label3D, text: String, color: Color) -> void:
	if l.text != text:
		l.text = text
		_place(l)
	l.modulate = color


## Light the first `count` segments of a bar (`level_of`: segment index -> 1 green, 2 amber, 3 red).
func _fill(segs: Array[MeshInstance3D], count: int, key: String, level_of: Callable) -> void:
	if int(_shown.get(key, -1)) == count:
		return
	_shown[key] = count
	for i in segs.size():
		segs[i].material_override = _seg_mat(level_of.call(i) if i < count else 0)


# --- Shared meshes and materials ---------------------------------------------------------------

## The terminal font, the green screens' material and the grimy glass's shader, shared with the
## cockpit (Cockpit) so the ship's instruments all look alike.
static func mono_font() -> Font:
	return _mono()


static func crt_material() -> ShaderMaterial:
	return _crt_mat()


static func glass_shader() -> Shader:
	return _glass_mat().shader


## The soft round smoke puff, shared with the scouts' missile trails (Projectiles).
static func smoke_mesh() -> QuadMesh:
	return _smoke_mesh()


## The reflector sight's glowing reticle (instance uniform `power`), shared with the scouts' gunsight.
static func sight_material() -> ShaderMaterial:
	return _sight_mat()


## The muzzle flash's mesh and its glowing material, shared with the scouts' cannons.
static func flash_mesh() -> ArrayMesh:
	return _flash_mesh()


static func flash_material() -> ShaderMaterial:
	return _flash_mat()


static func _mono() -> Font:
	if not _shared.has("font"):
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Consolas", "Lucida Console", "Courier New", "Monospace"])
		f.font_weight = 600
		_shared["font"] = f
	return _shared["font"]


## Screen segments: 0 off, 1 green, 2 amber, 3 red.
static func _seg_mat(level: int) -> Material:
	var cols := [Color(0.08, 0.3, 0.1), Color(0.35, 1.0, 0.4), Color(1.0, 0.7, 0.15), Color(1.0, 0.2, 0.12)]
	return Models.emissive(cols[level], 0.25 if level == 0 else 2.6, Color(0.02, 0.03, 0.02))


static func _shader_mat(key: String, code: String) -> ShaderMaterial:
	if not _shared.has(key):
		var sh := Shader.new()
		sh.code = code
		var m := ShaderMaterial.new()
		m.shader = sh
		_shared[key] = m
	return _shared[key]


static func _glass_mat() -> ShaderMaterial:
	return _shader_mat("glass", GLASS_SHADER + GLASS_LIGHT)


static func _sight_mat() -> ShaderMaterial:
	return _shader_mat("sight", SIGHT_SHADER)


static func _crt_mat() -> ShaderMaterial:
	return _shader_mat("crt", CRT_SHADER)


static func _flash_mat() -> ShaderMaterial:
	return _shader_mat("flash", FLASH_SHADER)


static func _box_mesh(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


## Half a sphere: the front (z <= 0, the glass) or the back. Smooth normals pointing out.
static func _hemisphere(radius: float, front: bool) -> ArrayMesh:
	var key := "hemi%.3f%s" % [radius, front]
	if _shared.has(key):
		return _shared[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 48
	var rings := 16
	var axis := Vector3(0, 0, -1.0 if front else 1.0)
	var u := Vector3.RIGHT
	var v := axis.cross(u)
	for j in rings:
		for i in segs:
			var q: Array[Vector3] = []
			for c: Vector2i in [Vector2i(i, j), Vector2i(i + 1, j), Vector2i(i + 1, j + 1), Vector2i(i, j + 1)]:
				# Polar angle from the pole on the axis out to the rim, azimuth round it.
				var th := PI * 0.5 * float(c.y) / rings
				var ph := TAU * float(c.x) / segs
				q.append((axis * cos(th) + (u * cos(ph) + v * sin(ph)) * sin(th)).normalized())
			for t: Array in [[q[0], q[1], q[2]], [q[0], q[2], q[3]]]:
				var a: Vector3 = t[0]
				var b: Vector3 = t[1]
				var c: Vector3 = t[2]
				if (b - a).cross(c - a).length_squared() < 1e-12:
					continue
				# Godot's front faces wind clockwise: the right-handed normal must point inward.
				if (b - a).cross(c - a).dot(a + b + c) > 0.0:
					var swap := b
					b = c
					c = swap
				for p: Vector3 in [a, b, c]:
					st.set_normal(p)
					st.add_vertex(p * radius)
	var mesh := st.commit()
	_shared[key] = mesh
	return mesh


## Three flame blades round the bore and a burst facing forward (the flash shader fades each quad
## from its middle).
static func _flash_mesh() -> ArrayMesh:
	if _shared.has("flash_mesh"):
		return _shared["flash_mesh"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 3:
		var rot := Basis(Vector3.FORWARD, k * PI / 3.0)
		_quad(st, rot * Vector3(-0.16, 0, 0.03), rot * Vector3(0.16, 0, 0.03), rot * Vector3(0.16, 0, -0.8), rot * Vector3(-0.16, 0, -0.8))
	_quad(st, Vector3(-0.22, -0.22, -0.05), Vector3(0.22, -0.22, -0.05), Vector3(0.22, 0.22, -0.05), Vector3(-0.22, 0.22, -0.05))
	var mesh := st.commit()
	_shared["flash_mesh"] = mesh
	return mesh


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	var pts: Array[Vector3] = [a, b, c, a, c, d]
	var uvs: Array[Vector2] = [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 0), Vector2(1, 1), Vector2(0, 1)]
	for i in 6:
		st.set_uv(uvs[i])
		st.add_vertex(pts[i])


## How smoke moves: off a hot barrel it seeps out all along it and rises; out of a muzzle it puffs
## forward and slows down. Grey puffs grow as they rise and fade away.
static func _smoke_process(muzzle: bool) -> ParticleProcessMaterial:
	var pm := ParticleProcessMaterial.new()
	if muzzle:
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		pm.emission_sphere_radius = 0.04
		pm.direction = Vector3(0, 0, -1)
		pm.spread = 20.0
		pm.initial_velocity_min = 1.2
		pm.initial_velocity_max = 2.6
		pm.damping_min = 2.2
		pm.damping_max = 3.2
		pm.gravity = Vector3(0, 0.35, 0)
		pm.scale_min = 0.5
		pm.scale_max = 1.0
	else:
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = Vector3(0.04, 0.04, 0.85)
		pm.direction = Vector3.UP
		pm.spread = 35.0
		pm.initial_velocity_min = 0.1
		pm.initial_velocity_max = 0.35
		pm.damping_min = 0.3
		pm.damping_max = 0.6
		pm.gravity = Vector3(0, 0.55, 0)
		pm.scale_min = 0.6
		pm.scale_max = 1.0
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.35))
	grow.add_point(Vector2(0.5, 0.85))
	grow.add_point(Vector2(1.0, 1.25 if muzzle else 1.1))
	var grow_tex := CurveTexture.new()
	grow_tex.curve = grow
	pm.scale_curve = grow_tex
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.12, 0.55, 1.0])
	fade.colors = PackedColorArray([Color(0.62, 0.6, 0.57, 0.0), Color(0.5, 0.49, 0.47, 0.42), Color(0.4, 0.4, 0.39, 0.26),
		Color(0.36, 0.36, 0.36, 0.0)])
	var fade_tex := GradientTexture1D.new()
	fade_tex.gradient = fade
	pm.color_ramp = fade_tex
	pm.angle_min = -180.0
	pm.angle_max = 180.0
	return pm


## A smoke emitter (off until the heat calls for it). The smoke stays where it was let out, so it
## trails behind as the pod and the ship move.
static func _smoke_emitter(pm: ParticleProcessMaterial, amount: int, lifetime: float) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = amount
	p.lifetime = lifetime
	p.randomness = 0.5
	p.local_coords = false
	p.emitting = false
	p.amount_ratio = 0.0
	p.process_material = pm
	p.draw_pass_1 = _smoke_mesh()
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-15, -4, -15), Vector3(30, 14, 30))
	return p


## A soft round puff for the smoke off hot barrels.
static func _smoke_mesh() -> QuadMesh:
	if _shared.has("smoke_mesh"):
		return _shared["smoke_mesh"]
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = tex
	var q := QuadMesh.new()
	q.size = Vector2(0.4, 0.4)
	q.material = m
	_shared["smoke_mesh"] = q
	return q
