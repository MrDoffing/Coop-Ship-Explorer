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

const GLASS_SHADER := """
shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_never, specular_schlick_ggx;
uniform vec3 tint : source_color = vec3(0.55, 0.7, 0.68);
uniform vec3 grime_color : source_color = vec3(0.16, 0.13, 0.09);
varying vec3 lp;

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
	float grime = smoothstep(0.62, 0.92, n) * 0.6 + (1.0 - smoothstep(-1.0, 0.0, lp.y)) * n * 0.55;
	grime = clamp(grime, 0.0, 1.0);
	// A few fine scratches.
	float s = abs(fract(lp.x * 7.0 - lp.y * 2.0 + vnoise(lp * 2.5) * 3.0) - 0.5);
	float scratch = (1.0 - smoothstep(0.0, 0.012, s)) * step(0.78, vnoise(lp * 9.0 + 4.0));
	ALBEDO = mix(tint * 0.12, grime_color, grime);
	ROUGHNESS = mix(0.05, 0.6, grime);
	SPECULAR = 0.5;
	ALPHA = clamp(0.035 + fres * 0.45 + grime * 0.3 + scratch * 0.18, 0.0, 0.9);
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
var _sys_hp := 100.0
## The local crew member is the gunner: sounds play in 2D and the view shakes.
var _local := false
var _barrel_nodes: Array[Node3D] = []
var _recoil: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _flashes: Array[MeshInstance3D] = []
var _flash_t: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _lights: Array[OmniLight3D] = []
var _casings: Array[CPUParticles3D] = []
var _smoke: Array[CPUParticles3D] = []
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


func build(def: Dictionary) -> void:
	read_mount(def)
	muzzle = Vector3(0, 0, (BARRELS[0] as Vector3).z - BARREL_LEN)
	camera_offset = EYE
	var heavy := style == "heavy"
	var shell := _shell_mat(paint.darkened(0.45 if heavy else 0.3))
	# Painted steel, light and barely metallic: the strips only catch the cabin lamp, and must
	# still stand out against the dark cave.
	var frame := Models.mat(Color(0.37, 0.37, 0.32), 0.15, 0.62)
	var bolt := Models.mat(Color(0.5, 0.49, 0.45), 0.5, 0.45)
	var gunmetal := Models.mat(Color(0.09, 0.09, 0.1), 0.7, 0.45)
	var steel := Models.mat(Color(0.5, 0.51, 0.5), 0.8, 0.35)
	var olive := Models.panel_mat(Color(0.27, 0.29, 0.24), 0.35, 0.75, 3.0)
	var dark := Models.mat(Color(0.07, 0.075, 0.08), 0.4, 0.7)
	var b := Models.Batch.new()
	# The ball: glass in front, a riveted shell behind, held together by metal strips. Seen from
	# the gunner's eye near the centre, every strip (a great circle) reads as a straight frame bar.
	b.add(_hemisphere(RADIUS, true), Transform3D.IDENTITY, _glass_mat())
	b.add(_hemisphere(RADIUS + 0.004, false), Transform3D.IDENTITY, shell)
	b.add(_band(Vector3.RIGHT, Vector3.UP, 0.0, TAU, RADIUS + 0.012, 0.09, 0.05, 64), Transform3D.IDENTITY, frame)
	for yaw: float in [-1.08, -0.52, 0.52, 1.08]:
		var d := Vector3(sin(yaw), 0, -cos(yaw))
		b.add(_band(Vector3.DOWN, d, 0.0, PI, RADIUS + 0.01, 0.065, 0.04, 32), Transform3D.IDENTITY, frame)
		_bolts(b, Vector3.DOWN, d, RADIUS + 0.01, 0.04, 8, bolt)
	for elev: float in [0.45, -0.37]:
		var e := Vector3(0, sin(elev), -cos(elev))
		b.add(_band(Vector3.LEFT, e, 0.0, PI, RADIUS + 0.01, 0.065, 0.04, 32), Transform3D.IDENTITY, frame)
		_bolts(b, Vector3.LEFT, e, RADIUS + 0.01, 0.04, 8, bolt)
	_bolts(b, Vector3.RIGHT, Vector3.UP, RADIUS + 0.012, 0.05, 24, bolt, true)
	# Ribs on the shell, and armour plates on a heavy pod.
	b.add(_band(Vector3.DOWN, Vector3.BACK, 0.0, PI, RADIUS + 0.01, 0.07, 0.04, 24), Transform3D.IDENTITY, frame)
	b.add(_band(Vector3.LEFT, Vector3.BACK, 0.0, PI, RADIUS + 0.01, 0.07, 0.04, 24), Transform3D.IDENTITY, frame)
	if heavy:
		for x: float in [-0.48, 0.48]:
			b.box(Vector3(x, 0.42, 0.88), Vector3(0.5, 0.42, 0.08), frame, Vector3(-25, -x * 55.0, 0))
			b.box(Vector3(x, -0.4, 0.9), Vector3(0.5, 0.36, 0.08), frame, Vector3(22, -x * 55.0, 0))
	# The cap on top and the trunnions on each side, where the guns are fixed to the ball.
	b.cyl(Vector3(0, RADIUS - 0.005, 0), 0.22, 0.05, frame, Vector3.ZERO, -1.0, 20)
	b.box(Vector3(0, RADIUS + 0.04, 0.08), Vector3(0.1, 0.08, 0.16), dark)
	for s: float in [-1.0, 1.0]:
		b.cyl(Vector3(s * (RADIUS - 0.01), 0, 0), 0.32, 0.08, frame, Vector3(0, 0, 90), -1.0, 24)
		b.cyl(Vector3(s * 1.1, 0, 0), 0.15, 0.12, steel, Vector3(0, 0, 90), -1.0, 16)
		for i in 8:
			var a := TAU * i / 8.0
			b.cyl(Vector3(s * (RADIUS + 0.035), sin(a) * 0.26, cos(a) * 0.26), 0.016, 0.02, bolt, Vector3(0, 0, 90), -1.0, 6)
	_build_guns(b, gunmetal, steel, dark, frame)
	_build_cabin(b, olive, dark, steel, frame)
	b.commit(pitch_pivot, "Pod")
	_build_displays()
	_build_collar(heavy)
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


## The two receivers with their twin barrels, the muzzle flashes and lights, ejected casings and
## smoke from hot barrels.
func _build_guns(b: Models.Batch, gunmetal: Material, steel: Material, dark: Material, frame: Material) -> void:
	var brass := Models.mat(Color(0.78, 0.58, 0.26), 0.85, 0.35)
	for s: float in [-1.0, 1.0]:
		var x := s * 1.27
		b.box(Vector3(s * 1.11, 0, 0), Vector3(0.14, 0.2, 0.26), frame)
		b.box(Vector3(x, 0, -0.05), Vector3(0.24, 0.46, 0.9), gunmetal)
		b.box(Vector3(x, 0.245, -0.05), Vector3(0.2, 0.03, 0.78), steel)
		b.box(Vector3(x, 0, -0.5), Vector3(0.26, 0.48, 0.04), frame)
		b.box(Vector3(x, -0.235, -0.15), Vector3(0.12, 0.02, 0.18), dark)
		for z: float in [-0.35, -0.05, 0.25]:
			b.box(Vector3(s * 1.395, 0, z), Vector3(0.012, 0.4, 0.04), frame)
		# Charging handle on the outboard side.
		b.box(Vector3(s * 1.41, 0.1, 0.22), Vector3(0.04, 0.05, 0.14), steel)
		b.sphere(Vector3(s * 1.44, 0.1, 0.3), 0.025, dark)
		# The belt chute from the receiver back into the pod (the rounds come from inside the ship).
		var chute: Array[Vector3] = [Vector3(s * 1.13, -0.06, 0.3), Vector3(s * 1.02, -0.13, 0.47), Vector3(s * 0.84, -0.2, 0.62)]
		for i in chute.size() - 1:
			b.beam(chute[i], chute[i + 1], 0.11, 0.09, dark)
		for c: Vector3 in chute:
			b.box(c, Vector3(0.13, 0.11, 0.025), brass)
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
		var smoke := CPUParticles3D.new()
		smoke.position = Vector3(x, 0.0, -2.3)
		smoke.emitting = false
		smoke.local_coords = false
		smoke.amount = 10
		smoke.lifetime = 1.6
		smoke.mesh = _smoke_mesh()
		smoke.direction = Vector3.UP
		smoke.spread = 25.0
		smoke.initial_velocity_min = 0.2
		smoke.initial_velocity_max = 0.5
		smoke.gravity = Vector3(0, 0.5, 0)
		smoke.scale_amount_min = 0.6
		smoke.scale_amount_max = 1.4
		var fade := Gradient.new()
		fade.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
		fade.colors = PackedColorArray([Color(0.5, 0.5, 0.5, 0.0), Color(0.45, 0.45, 0.45, 0.22), Color(0.4, 0.4, 0.4, 0.0)])
		smoke.color_ramp = fade
		var grow := Curve.new()
		grow.add_point(Vector2(0.0, 0.4))
		grow.add_point(Vector2(1.0, 1.0))
		smoke.scale_amount_curve = grow
		pitch_pivot.add_child(smoke)
		_smoke.append(smoke)
	_barrel_mat = StandardMaterial3D.new()
	_barrel_mat.albedo_color = Color(0.12, 0.11, 0.1)
	_barrel_mat.metallic = 0.7
	_barrel_mat.roughness = 0.45
	_barrel_mat.emission_enabled = true
	_barrel_mat.emission = Color(0.9, 0.18, 0.04)
	_barrel_mat.emission_energy_multiplier = 0.0
	for i in BARRELS.size():
		var node := Node3D.new()
		node.position = BARRELS[i]
		pitch_pivot.add_child(node)
		_barrel_nodes.append(node)
		var bb := Models.Batch.new()
		# Perforated cooling jacket, the bare barrel and a flared flash hider.
		bb.cyl(Vector3(0, 0, -0.55), 0.072, 1.1, gunmetal, Vector3(90, 0, 0), -1.0, 14)
		for z: float in [-0.03, -1.08]:
			bb.cyl(Vector3(0, 0, z), 0.082, 0.04, steel, Vector3(90, 0, 0), -1.0, 14)
		for k in 4:
			var a := TAU * k / 4.0 + PI / 4.0
			for j in 5:
				bb.box(Vector3(cos(a) * 0.07, sin(a) * 0.07, -0.18 - j * 0.19), Vector3(0.02, 0.02, 0.075), dark, Vector3(0, 0, rad_to_deg(a)))
		bb.cyl(Vector3(0, 0, -1.47), 0.036, 0.74, _barrel_mat, Vector3(90, 0, 0), -1.0, 12)
		bb.cyl(Vector3(0, 0, -1.9), 0.075, 0.2, _barrel_mat, Vector3(90, 0, 0), 0.052, 12)
		bb.commit(node, "Barrel", false)
		var flash := MeshInstance3D.new()
		flash.mesh = _flash_mesh()
		flash.material_override = _flash_mat()
		flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		flash.position = Vector3(0, 0, -BARREL_LEN)
		flash.visible = false
		node.add_child(flash)
		_flashes.append(flash)


## The gunner's seat, the control panel with its grips, and the reflector sight.
func _build_cabin(b: Models.Batch, olive: Material, dark: Material, steel: Material, frame: Material) -> void:
	var leather := Models.mat(Color(0.2, 0.14, 0.1), 0.1, 0.8)
	var hazard := Models.mat(Color(0.9, 0.7, 0.1), 0.2, 0.6)
	b.cyl(Vector3(0, -0.84, 0), 0.62, 0.03, Models.panel_mat(Color(0.2, 0.2, 0.19), 0.6, 0.6, 4.0), Vector3.ZERO, -1.0, 24)
	b.box(Vector3(0, -0.72, -0.45), Vector3(0.36, 0.03, 0.06), steel)
	b.cyl(Vector3(0, -0.71, 0.16), 0.04, 0.24, steel)
	b.box(Vector3(0, -0.57, 0.16), Vector3(0.44, 0.07, 0.4), leather)
	b.box(Vector3(0, -0.24, 0.4), Vector3(0.42, 0.55, 0.07), leather, Vector3(12, 0, 0))
	b.box(Vector3(0, 0.2, 0.26), Vector3(0.24, 0.15, 0.07), leather, Vector3(12, 0, 0))
	for x: float in [-0.23, 0.23]:
		b.box(Vector3(x, -0.4, 0.3), Vector3(0.03, 0.06, 0.5), steel, Vector3(-30, 0, 0))
	# The control panel: a sloping desk with switches, the fascia below it and two spade grips.
	var desk := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(29.4)), Vector3(0, -0.31, -0.54))
	b.add(_box_mesh(Vector3(0.92, 0.05, 0.37)), desk, olive)
	b.add(_box_mesh(Vector3(0.94, 0.012, 0.02)), desk * Transform3D(Basis.IDENTITY, Vector3(0, 0.02, 0.18)), hazard)
	b.box(Vector3(0, -0.42, -0.74), Vector3(0.8, 0.38, 0.06), olive)
	for i in 6:
		var x := -0.36 + i * 0.065 if i < 3 else 0.17 + (i - 3) * 0.065
		b.add(_box_mesh(Vector3(0.022, 0.03, 0.04)), desk * Transform3D(Basis.IDENTITY, Vector3(x, 0.035, 0.07)), dark)
		b.add(_box_mesh(Vector3(0.008, 0.04, 0.008)), desk * Transform3D(Basis(Vector3.RIGHT, -0.5), Vector3(x, 0.06, 0.065)), steel)
	for x: float in [-0.3, 0.3]:
		b.add(_cyl_mesh(0.03, 0.025), desk * Transform3D(Basis.IDENTITY, Vector3(x, 0.035, -0.08)), dark)
	b.box(Vector3(0, -0.33, -0.42), Vector3(0.44, 0.03, 0.03), steel)
	for x: float in [-0.19, 0.19]:
		b.cyl(Vector3(x, -0.27, -0.42), 0.022, 0.13, Models.mat(Color(0.1, 0.08, 0.06), 0.1, 0.9))
		b.sphere(Vector3(x, -0.2, -0.42), 0.017, Models.emissive(Color(1.0, 0.15, 0.08), 1.5))
	# The reflector sight: a slim lamp housing on a post, well below the line of sight, and a
	# U-shaped holder for the tilted glass the reticle shows on.
	b.cyl(Vector3(0, -0.148, -0.49), 0.011, 0.325, steel)
	b.box(Vector3(0, 0.0375, -0.47), Vector3(0.05, 0.045, 0.12), frame)
	b.box(Vector3(0, 0.045, -0.4095), Vector3(0.03, 0.006, 0.002), Models.emissive(Color(1.0, 0.55, 0.15), 0.8))
	b.box(Vector3(0, 0.063, -0.45), Vector3(0.132, 0.008, 0.02), frame)
	for x: float in [-0.063, 0.063]:
		b.box(Vector3(x, 0.145, -0.45), Vector3(0.007, 0.17, 0.01), frame)
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


## The display housing on top of the control panel: the ammo counter and the heat gauge on two
## green screens, the lamps either side of them and a stencilled placard below.
func _build_displays() -> void:
	var disp := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-23.0)), Vector3(0, -0.13, -0.745))
	var b := Models.Batch.new()
	var frame := Models.mat(Color(0.11, 0.115, 0.12), 0.7, 0.5)
	b.add(_box_mesh(Vector3(0.9, 0.2, 0.1)), disp, Models.panel_mat(Color(0.25, 0.27, 0.22), 0.35, 0.75, 3.0))
	b.add(_box_mesh(Vector3(0.92, 0.016, 0.07)), disp * Transform3D(Basis.IDENTITY, Vector3(0, 0.104, 0.03)), frame)
	# The screens sit either side of the sight's post, clear of it from the gunner's eye.
	for x: float in [-0.228, 0.228]:
		b.add(_box_mesh(Vector3(0.33, 0.16, 0.004)), disp * Transform3D(Basis.IDENTITY, Vector3(x, -0.01, 0.051)), frame)
		for y: float in [-0.085, 0.065]:
			for bx: float in [-0.155, 0.155]:
				b.add(_cyl_mesh(0.006, 0.006), disp * Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(x + bx, y, 0.054)),
					Models.mat(Color(0.5, 0.5, 0.47), 0.85, 0.35))
	b.commit(pitch_pivot, "Displays", false)
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
	_label(disp, Vector3(-0.373, top, 0.056), "AMMO", 26, GREEN, HORIZONTAL_ALIGNMENT_LEFT)
	_ammo_note = _label(disp, Vector3(-0.083, top, 0.056), "READY", 26, GREEN, HORIZONTAL_ALIGNMENT_RIGHT)
	_ammo_label = _label(disp, Vector3(-0.255, -0.008, 0.056), "%03d" % BELT, 92, GREEN)
	_label(disp, Vector3(-0.122, -0.022, 0.056), "RDS", 22, GREEN)
	_label(disp, Vector3(0.083, top, 0.056), "BARREL HEAT", 26, GREEN, HORIZONTAL_ALIGNMENT_LEFT)
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


## The ring the ball sits in (it turns with the pod's yaw), on top of the mount.
func _build_collar(heavy: bool) -> void:
	var b := Models.Batch.new()
	var dark := Models.mat(Color(0.12, 0.125, 0.13), 0.7, 0.45)
	var torus := TorusMesh.new()
	torus.inner_radius = 0.79
	torus.outer_radius = 0.99 if heavy else 0.97
	torus.rings = 32
	torus.ring_segments = 8
	b.add(torus, Transform3D(Basis.from_scale(Vector3(1.0, 0.6, 1.0)), Vector3(0, -0.76, 0)), dark)
	b.add(_band(Vector3.FORWARD, Vector3.RIGHT, 0.0, TAU, 0.985 if heavy else 0.965, 0.03, 0.01, 40), Transform3D(Basis.IDENTITY, Vector3(0, -0.76, 0)),
		Models.mat(accent, 0.3, 0.5))
	for i in 4:
		var a := TAU * i / 4.0 + PI / 4.0
		var dir := Vector3(cos(a), 0, sin(a))
		b.box(dir * 0.92 + Vector3(0, -0.76, 0), Vector3(0.16, 0.12, 0.16), dark, Vector3(0, -rad_to_deg(a), 0))
		b.strut(dir * 0.86 + Vector3(0, -0.8, 0), dir * 0.42 + Vector3(0, -MOUNT_TOP, 0), 0.045, dark)
	b.commit(yaw_pivot, "Collar")


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
## (alpha 0: nobody, or it is us) and whether the local crew member is the gunner.
func set_state(rounds: int, heat_now: float, reload_now: float, sys_hp: float, sys_online: bool, figure: Color, local: bool) -> void:
	_local = local
	if reload_now > 0.0 and reload_left <= 0.0:
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


## Barrel `i` fires a round. `hot`: it was fired at full heat (the weapon systems take damage).
## `local`: the local crew member is the gunner.
func fire_fx(i: int, hot: bool, local: bool) -> void:
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
	if local:
		_kick = 1.0
		Sfx.play("hmg", null, -7.0)
	else:
		Sfx.play("hmg", _barrel_nodes[i].global_transform * Vector3(0, 0, -BARREL_LEN), -2.0)
	if hot and _hot_t <= 0.0:
		_hot_t = 0.22
		_sparks.restart()
		_sound("sizzle", -5.0)


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
		c.emitting = _since_shot < 0.1
	for s in _smoke:
		s.emitting = heat > 0.5
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


## The traversing motors whine while the pod swings round.
func _update_servo(delta: float) -> void:
	var speed := (aim - _last_aim).length() / maxf(delta, 0.001)
	_last_aim = aim
	_servo_level = move_toward(_servo_level, clampf(speed / TURN_RATE, 0.0, 1.0), delta * 6.0)
	if _servo_level > 0.03:
		if not _servo.playing:
			_servo.play()
		_servo.volume_db = linear_to_db(_servo_level) - 9.0
		_servo.pitch_scale = 0.8 + 0.35 * _servo_level
	elif _servo.playing:
		_servo.stop()


func _update_displays() -> void:
	var blink := fmod(_clock, 0.5) < 0.25
	var fast := fmod(_clock, 0.24) < 0.12
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
	(_lamps["ready"] as StandardMaterial3D).emission_energy_multiplier = 3.0 if online and not reloading and heat < 0.97 else 0.0
	(_lamps["belt"] as StandardMaterial3D).emission_energy_multiplier = 3.0 if reloading and blink else 0.0
	(_lamps["heat"] as StandardMaterial3D).emission_energy_multiplier = 3.5 if (heat >= 0.97 and fast) or (heat >= HEAT_WARN and heat < 0.97 and blink) else 0.0
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


static func _shell_mat(color: Color) -> StandardMaterial3D:
	var key := "shell" + color.to_html()
	if not _shared.has(key):
		# Seen from inside the pod too.
		var m := Models.panel_mat(color, 0.55, 0.62, 1.6).duplicate() as StandardMaterial3D
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_shared[key] = m
	return _shared[key]


static func _shader_mat(key: String, code: String) -> ShaderMaterial:
	if not _shared.has(key):
		var sh := Shader.new()
		sh.code = code
		var m := ShaderMaterial.new()
		m.shader = sh
		_shared[key] = m
	return _shared[key]


static func _glass_mat() -> ShaderMaterial:
	return _shader_mat("glass", GLASS_SHADER)


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


static func _cyl_mesh(radius: float, height: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = radius
	m.bottom_radius = radius
	m.height = height
	m.radial_segments = 10
	m.rings = 1
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


## A metal strip along a great circle of the ball: points u cos(a) + v sin(a) for a from a0 to a1
## (u, v: unit vectors at right angles), `width` across and `thick` deep, centred on `radius`.
static func _band(u: Vector3, v: Vector3, a0: float, a1: float, radius: float, width: float, thick: float, steps: int) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := u.cross(v).normalized()
	var prev: Array[Vector3] = []
	var prev_c := Vector3.ZERO
	for i in steps + 1:
		var a := lerpf(a0, a1, float(i) / steps)
		var r := (u * cos(a) + v * sin(a)).normalized()
		var c := r * radius
		var ring: Array[Vector3] = [c + r * thick * 0.5 + n * width * 0.5, c + r * thick * 0.5 - n * width * 0.5,
			c - r * thick * 0.5 - n * width * 0.5, c - r * thick * 0.5 + n * width * 0.5]
		if not prev.is_empty():
			var mid := (prev_c + c) * 0.5
			for k in 4:
				var k2 := (k + 1) % 4
				Models.tri(st, prev[k], ring[k], ring[k2], mid)
				Models.tri(st, prev[k], ring[k2], prev[k2], mid)
		prev = ring
		prev_c = c
	return st.commit()


## Bolt heads along a strip (see _band), on its outer face and its inner face (seen from inside).
## `full`: the strip is a whole circle.
static func _bolts(b: Models.Batch, u: Vector3, v: Vector3, radius: float, thick: float, count: int, mat: Material, full := false) -> void:
	for i in count:
		var a := (TAU * i / count) if full else PI * (i + 0.5) / count
		var r := (u * cos(a) + v * sin(a)).normalized()
		var side := r.cross(Vector3.UP if absf(r.y) < 0.9 else Vector3.RIGHT).normalized()
		var basis := Basis(side, r, side.cross(r))
		for depth: float in [thick * 0.5 + 0.006, -thick * 0.5 - 0.006]:
			b.add(_cyl_mesh(0.013, 0.014), Transform3D(basis, r * (radius + depth)), mat)


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
	q.size = Vector2(0.28, 0.28)
	q.material = m
	_shared["smoke_mesh"] = q
	return q
