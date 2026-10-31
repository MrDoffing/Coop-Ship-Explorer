class_name OutpostProps
extends RefCounted
## The furniture and machinery of an abandoned station's rooms (see OutpostLayout for where each
## piece stands and DerelictBuilder for the rooms round them). Everything static goes into the
## station's mesh batch, with a collision box over each piece's footprint; what moves or glows on
## its own (the specimen tanks, the generator, the control hub's screens, map and computer) are nodes
## the Derelict animates.
##
## A piece's frame: its floor point under its middle, turned by its yaw, facing its local +z (into
## the room for pieces against a wall). "size" is its width (local x), height and depth (local z).

## The specimen tanks: liquid that glows and fizzes with rising bubbles, its surface `level` (0..1
## of the tank's height; above it the tank is empty glass), and a glassy rim where it is seen edge
## on.
const TANK_SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, shadows_disabled;
uniform vec3 liquid : source_color = vec3(0.35, 0.5, 0.18);
uniform float glow = 0.32;
instance uniform float level = 0.92;
instance uniform float seed = 0.0;
varying vec3 lp;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	lp = VERTEX;
}

void fragment() {
	float fres = pow(1.0 - abs(dot(NORMAL, VIEW)), 2.0);
	float h = lp.y + 0.5;
	float wet = step(h, level);
	// Bubbles: columns of dots drifting up round the tank.
	vec2 g = vec2(UV.x * 26.0, h * 9.0 - TIME * 0.9 - seed);
	vec2 cell = floor(g);
	vec2 f = fract(g) - 0.5;
	float r = hash(cell + seed);
	float bubble = (1.0 - smoothstep(0.03, 0.1, length(f + vec2(sin(TIME * 2.0 + r * 6.0) * 0.12, 0.0)))) * step(0.88, r);
	float sway = 0.75 + 0.25 * sin(TIME * 0.7 + h * 5.0 + seed);
	ALBEDO = mix(vec3(0.6, 0.7, 0.7), liquid * 0.35, wet);
	EMISSION = (liquid * glow * sway * (0.45 + 0.55 * h) + liquid * bubble * 0.6) * wet + vec3(0.25, 0.3, 0.3) * fres * 0.3;
	ROUGHNESS = 0.05;
	SPECULAR = 0.9;
	ALPHA = clamp(mix(0.06 + fres * 0.35, 0.5 + fres * 0.3, wet), 0.0, 1.0);
}
"""

static var _shared: Dictionary = {}
## The node the piece being built puts its model parts under (see _model).
static var _root: Node3D
static var _batch: Models.Batch
## The room's height over its floor, for the piece being built (see build()).
static var _ceiling := 4.4
## Furniture made in Blender (tools/blender/outpost_props.py), and the sizes its pieces were made at.
const MODELS := "outpost_props"
const CRATE_SIZE := Vector3(0.85, 0.75, 0.85)
const AMMO_SIZE := Vector3(0.48, 0.3, 0.6)


## Build a piece: into the batch `b`, its collision into `body`. `root` takes the nodes that live
## on their own; `out` collects what the Derelict animates ("tanks", "subjects", "generator",
## "screens", "lights"). `ceiling`: the room's height over its floor (pipes and cables run up into
## it).
static func build(root: Node3D, b: Models.Batch, body: StaticBody3D, p: Dictionary, m: Dictionary, out: Dictionary,
		ceiling := OutpostLayout.ROOM_H) -> void:
	var size: Vector3 = p["size"]
	var x := Transform3D(Basis(Vector3.UP, float(p["yaw"])), p["pos"])
	var rng := RandomNumberGenerator.new()
	rng.seed = int(p["var"]) * 7919 + 13
	var solid := true
	_root = root
	_batch = b
	_ceiling = ceiling
	match str(p["kind"]):
		"shelf":
			_shelf(b, x, size, m, rng)
		"locker":
			_lockers(b, x, size, m, rng)
		"crates":
			_crate_stack(b, x, size, m, rng)
		"cabinet":
			_cabinet(b, x, size, m, rng)
		"lab_bench":
			_lab_bench(b, x, size, m, rng)
		"console":
			_console(b, x, size, m, rng)
		"bed":
			_bed(b, x, size, m, rng)
		"counter":
			_counter(b, x, size, m, rng)
		"vending":
			_vending(b, x, size, m, rng)
		"gun_rack":
			_gun_rack(b, x, size, m, rng)
		"ammo":
			_ammo(b, x, size, m, rng)
		"fuel_tanks":
			_fuel_tanks(b, x, size, m, rng)
		"breaker":
			_breaker(b, x, size, m, rng)
		"monitor_wall":
			_monitor_wall(b, x, size, m, rng)
		"filing":
			_filing(b, x, size, m, rng)
		"workbench":
			_workbench(b, x, size, m, rng)
		"med_cabinet":
			_med_cabinet(b, x, size, m, rng)
		"strongbox":
			_strongbox(b, x, size, m, rng)
		"barrels":
			_barrels(b, x, size, m, rng)
		"pipes":
			_pipes(b, x, size, m, rng)
			solid = false
		"tube":
			_tube(root, b, x, size, m, rng, int(p["var"]), out)
		"lab_table":
			_lab_table(b, x, size, m, rng)
		"pallet":
			_pallet(b, x, size, m, rng)
		"table":
			_table(b, x, size, m, rng)
		"mess_table":
			_mess_table(b, x, size, m, rng)
		"hub_desk":
			_hub_desk(root, b, x, size, m, rng, out)
			# (Solid up to the desk top and where the board stands, so the computer can be reached.)
			_shape(body, x, Vector3(0, 0.465, 0), Vector3(size.x - 0.1, 0.93, size.z))
			_shape(body, x, Vector3(0, size.y * 0.5, -size.z * 0.5 + 0.12), Vector3(size.x - 0.1, size.y, 0.3))
			solid = false
		"generator":
			_generator(root, b, x, size, m, rng, out)
		"weapon_bench":
			_weapon_bench(b, x, size, m, rng)
		"surgery":
			_surgery(b, x, size, m, rng)
		"lathe":
			_lathe(b, x, size, m, rng)
	if solid:
		_shape(body, x, Vector3(0, size.y * 0.5, 0), size)


## A collision box in a piece's frame.
static func _shape(body: StaticBody3D, x: Transform3D, p: Vector3, size: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.transform = x * Transform3D(Basis.IDENTITY, p)
	body.add_child(cs)


# --- Primitives in a piece's frame -------------------------------------------------------------

## A part of the furniture model at `xform` (station-local): drawn with every other one of its kind
## nearby as one MultiMesh (see Models.Batch.add_instance()).
static func _model(part: String, xform: Transform3D) -> void:
	var mesh: Mesh = Models.asset(MODELS)[part]
	if _batch:
		_batch.add_instance(mesh, xform)
	else:
		Models.asset_mesh(_root, MODELS, part, {}, xform)


static func _box(b: Models.Batch, x: Transform3D, p: Vector3, size: Vector3, mat: Material, rot := Vector3.ZERO) -> void:
	b.box_at(x * Transform3D(Models.euler(rot), p), size, mat)


static func _cyl(b: Models.Batch, x: Transform3D, p: Vector3, r: float, h: float, mat: Material, rot := Vector3.ZERO,
		top := -1.0, sides := 12) -> void:
	b.cyl_at(x * Transform3D(Models.euler(rot), p), r, h, mat, top, sides)


static func _sph(b: Models.Batch, x: Transform3D, p: Vector3, r: float, mat: Material, scale := Vector3.ONE) -> void:
	b.add(Models.unit_sphere(10), x * Transform3D(Basis.from_scale(scale * r), p), mat)


static func _strut(b: Models.Batch, x: Transform3D, a: Vector3, e: Vector3, r: float, mat: Material) -> void:
	b.strut(x * a, x * e, r, mat)


## Four legs under a top `w` x `d` at height `h`.
static func _legs(b: Models.Batch, x: Transform3D, w: float, d: float, h: float, mat: Material, t := 0.07) -> void:
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_box(b, x, Vector3(sx * (w * 0.5 - t), h * 0.5, sz * (d * 0.5 - t)), Vector3(t, h, t), mat)


## A screen face: lit green text lines (or dead glass) on a dark bezel.
static func _screen(b: Models.Batch, x: Transform3D, p: Vector3, w: float, h: float, m: Dictionary, lit: bool, rot := Vector3.ZERO) -> void:
	_box(b, x, p, Vector3(w + 0.06, h + 0.06, 0.05), m["dark"], rot)
	var face := x * Transform3D(Models.euler(rot), p)
	b.box_at(face * Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.026)), Vector3(w, h, 0.012), m["screen"] if lit else m["dead_glass"])


# --- Along the walls ---------------------------------------------------------------------------

## Heavy steel shelving with crates, canisters and boxes on it.
static func _shelf(b: Models.Batch, x: Transform3D, s: Vector3, m: Dictionary, rng: RandomNumberGenerator) -> void:
	_model("Shelf", x * Transform3D(Basis.from_scale(s / Vector3(2.2, 2.4, 0.7)), Vector3.ZERO))
	for i in 3:
		var y := 0.135 + i * (s.y - 0.2) / 3.0
		var at := -s.x * 0.5 + 0.15
		while at < s.x * 0.5 - 0.3:
			var w := rng.randf_range(0.3, 0.6)
			if at + w > s.x * 0.5 - 0.1:
				break
			var r := rng.randf()
			if r < 0.45:
				var bh := rng.randf_range(0.25, 0.5)
				_crate(b, x, Vector3(at + w * 0.5, y, rng.randf_range(-0.05, 0.05)), Vector3(w, bh, s.z * 0.8), m, rng.randf_range(-8, 8))
			elif r < 0.7:
				var ch := rng.randf_range(0.3, 0.55)
				_cyl(b, x, Vector3(at + 0.15, y + ch * 0.5, 0.0), 0.13, ch, m["yellow"] if rng.randf() < 0.3 else m["steel"])
				_cyl(b, x, Vector3(at + 0.15, y + ch + 0.02, 0.0), 0.06, 0.05, m["dark"])
				w = 0.32
			at += w + rng.randf_range(0.05, 0.3)


## A bank of lockers, sometimes one of them standing open: hollow, a shelf and a coat on its rail
## inside, boots on its floor, its door swung out on its two hinges.
static func _lockers(b: Models.Batch, x: Transform3D, s: Vector3, m: Dictionary, rng: RandomNumberGenerator) -> void:
	var n := 3
	var w := s.x / n
	var open := rng.randi() % (n + 2)
	var depth := s.z - 0.04
	var zc := -0.02
	var front := zc + depth * 0.5
	var t := 0.02
	for i in n:
		var cx := -s.x * 0.5 + w * (i + 0.5)
		var bw := w - 0.03
		var mat: Material = m["olive"] if rng.randf() < 0.75 else m["rust"]
		if i != open:
			_box(b, x, Vector3(cx, s.y * 0.5, zc), Vector3(bw, s.y, depth), mat)
			for v in 3:
				_box(b, x, Vector3(cx, s.y - 0.25 - v * 0.06, front + 0.005), Vector3(w * 0.5, 0.025, 0.01), m["dark"])
			_box(b, x, Vector3(cx + w * 0.3, s.y * 0.52, front + 0.015), Vector3(0.04, 0.2, 0.03), m["steel"])
			continue
		# The open locker's shell: back, sides, top and floor; dark inside.
		_box(b, x, Vector3(cx, s.y * 0.5, zc - depth * 0.5 + t * 0.5), Vector3(bw, s.y, t), mat)
		for sx: float in [-1.0, 1.0]:
			_box(b, x, Vector3(cx + sx * (bw - t) * 0.5, s.y * 0.5, zc), Vector3(t, s.y, depth), mat)
		_box(b, x, Vector3(cx, s.y - t * 0.5, zc), Vector3(bw, t, depth), mat)
		_box(b, x, Vector3(cx, 0.05, zc), Vector3(bw, 0.1, depth), mat)
		_box(b, x, Vector3(cx, s.y * 0.5, zc - depth * 0.5 + t + 0.004), Vector3(bw - t * 2.0, s.y - 0.14, 0.008), m["dark"])
		# A shelf, the coat rail under it with a coat hanging from it, boots on the floor.
		_box(b, x, Vector3(cx, s.y * 0.8, zc), Vector3(bw - t * 2.0, 0.02, depth - t), m["steel"])
		_cyl(b, x, Vector3(cx, s.y * 0.74, zc), 0.01, bw - t * 2.0, m["steel"], Vector3(0, 0, 90), -1.0, 8)
		_box(b, x, Vector3(cx, s.y * 0.735, zc), Vector3(0.12, 0.03, 0.02), m["dark"])
		_box(b, x, Vector3(cx, s.y * 0.53, zc - 0.03), Vector3(bw * 0.62, s.y * 0.38, 0.14), m["cloth"], Vector3(rng.randf_range(-3, 3), 0, 0))
		for k in 2:
			_box(b, x, Vector3(cx - 0.07 + k * 0.14, 0.17, zc + 0.05), Vector3(0.1, 0.14, 0.22), m["rubber"])
		# The door, swung out on its hinges at its right edge (it covers the front when shut).
		var dw := bw - 0.01
		var hinge := x * Transform3D(Basis(Vector3.UP, deg_to_rad(rng.randf_range(100.0, 125.0))), Vector3(cx + bw * 0.5, 0, front + 0.012))
		_box(b, hinge, Vector3(-dw * 0.5, s.y * 0.5, 0), Vector3(dw, s.y - 0.04, t), mat)
		for v in 3:
			_box(b, hinge, Vector3(-dw * 0.5, s.y - 0.25 - v * 0.06, 0.013), Vector3(w * 0.5, 0.025, 0.006), m["dark"])
		_box(b, hinge, Vector3(-dw * 0.8, s.y * 0.52, 0.02), Vector3(0.04, 0.2, 0.03), m["steel"])
		for y: float in [s.y * 0.15, s.y * 0.85]:
			_cyl(b, x, Vector3(cx + bw * 0.5, y, front + 0.012), 0.012, 0.09, m["steel"], Vector3.ZERO, -1.0, 8)
	_box(b, x, Vector3(0, s.y + 0.02, -0.02), Vector3(s.x + 0.04, 0.04, s.z), m["steel"])


## Stacked military crates.
static func _crate_stack(b: Models.Batch, x: Transform3D, s: Vector3, m: Dictionary, rng: RandomNumberGenerator) -> void:
	_crate(b, x, Vector3(-0.42, 0, 0), Vector3(0.85, 0.75, 0.85), m, rng.randf_range(-6, 6))
	_crate(b, x, Vector3(0.45, 0, 0.02), Vector3(0.8, 0.7, 0.8), m, rng.randf_range(-10, 10))
	if rng.randf() < 0.7:
		_crate(b, x, Vector3(-0.3, 0.75, 0), Vector3(0.7, 0.6, 0.7), m, rng.randf_range(-20, 20))


## A crate: olive boards with bronze corners and a stencil band.
static func _crate(_b: Models.Batch, x: Transform3D, p: Vector3, size: Vector3, _m: Dictionary, yaw: float) -> void:
	_model("Crate", x * Transform3D(Basis(Vector3.UP, deg_to_rad(yaw)) * Basis.from_scale(size / CRATE_SIZE), p))


## A low lab cabinet: a plinth with a drawer row, and above it two shelves of jars behind a pair of
## framed glass doors (one left ajar).
static func _cabinet(b: Models.Batch, x: Transform3D, s: Vector3, m: Dictionary, rng: RandomNumberGenerator) -> void:
	var t := 0.03
	var depth := s.z - 0.04
	var zc := -0.02
	var front := zc + depth * 0.5
	var base := 0.3
	# The plinth with its drawers, then the case: back, sides and top round the shelves.
	_box(b, x, Vector3(0, base * 0.5, zc), Vector3(s.x, base, depth), m["white"])
	for i in 2:
		_box(b, x, Vector3(-s.x * 0.25 + i * s.x * 0.5, base * 0.55, front + 0.005), Vector3(s.x * 0.46, base * 0.7, 0.012), m["mid"])
		_box(b, x, Vector3(-s.x * 0.25 + i * s.x * 0.5, base * 0.7, front + 0.015), Vector3(0.12, 0.025, 0.02), m["steel"])
	_box(b, x, Vector3(0, (base + s.y) * 0.5, zc - depth * 0.5 + t * 0.5), Vector3(s.x, s.y - base, t), m["white"])
	for sx: float in [-1.0, 1.0]:
		_box(b, x, Vector3(sx * (s.x - t) * 0.5, (base + s.y) * 0.5, zc), Vector3(t, s.y - base, depth), m["white"])
	_box(b, x, Vector3(0, s.y - t * 0.5, zc), Vector3(s.x, t, depth), m["white"])
	_box(b, x, Vector3(0, (base + s.y) * 0.5, zc - depth * 0.5 + t + 0.004), Vector3(s.x - t * 2.0, s.y - base - t, 0.006), m["dark"])
	var inner := s.y - base - t
	for k in 2:
		var y := base + 0.02 + k * inner * 0.5
		_box(b, x, Vector3(0, y, zc), Vector3(s.x - t * 2.0, 0.02, depth - t), m["steel"])
		for i in 6:
			if rng.randf() < 0.25:
				continue
			var jh := rng.randf_range(0.12, 0.24)
			_cyl(b, x, Vector3(-s.x * 0.4 + i * s.x * 0.16, y + 0.01 + jh * 0.5, zc + rng.randf_range(-0.08, 0.08)), 0.05, jh,
				m["liquid"] if rng.randf() < 0.6 else m["glass"])
	# The doors: steel frames round their glass, hinged at the case's sides; the right one ajar.
	var dw := (s.x - t * 2.0) * 0.5
	for sx: float in [-1.0, 1.0]:
		var swing := deg_to_rad(rng.randf_range(25.0, 70.0)) if sx > 0.0 else 0.0
		var hinge := x * Transform3D(Basis(Vector3.UP, swing), Vector3(sx * (s.x * 0.5 - t), base, front + 0.012))
		var cxl := -sx * dw * 0.5
		var dh := s.y - base - t
		_box(b, hinge, Vector3(cxl, dh * 0.5, 0), Vector3(dw - 0.05, dh - 0.05, 0.006), m["glass"])
		for side: float in [-1.0, 1.0]:
			_box(b, hinge, Vector3(cxl + side * (dw * 0.5 - 0.015), dh * 0.5, 0), Vector3(0.03, dh, 0.02), m["steel"])
			_box(b, hinge, Vector3(cxl, dh * 0.5 + side * (dh * 0.5 - 0.015), 0), Vector3(dw, 0.03, 0.02), m["steel"])
		_box(b, hinge, Vector3(-sx * (dw - 0.06), dh * 0.5, 0.02), Vector3(0.02, 0.1, 0.02), m["dark"])
	_box(b, x, Vector3(0, s.y + 0.01, 0), Vector3(s.x + 0.04, 0.03, s.z), m["steel"])


## A lab bench: cupboards under a steel worktop, a shelf of jars over it, a sink and instruments.
static func _lab_bench(b: Models.Batch, x: Transform3D, s: Vector3, m: Dictionary, rng: RandomNumberGenerator) -> void:
	_box(b, x, Vector3(0, 0.45, -0.02), Vector3(s.x, 0.9, s.z - 0.08), m["white"])
	_box(b, x, Vector3(0, 0.93, 0), Vector3(s.x + 0.04, 0.06, s.z), m["steel"])
	for i in 3:
		_box(b, x, Vector3(-s.x * 0.33 + i * s.x * 0.33, 0.5, s.z * 0.5 - 0.05), Vector3(s.x * 0.3, 0.75, 0.02), m["olive"])
	# The jar shelf over it, on brackets from a splashback up the wall behind the worktop.
	_box(b, x, Vector3(0, 1.36, -s.z * 0.5 + 0.015), Vector3(s.x, 0.8, 0.03), m["white"])
	_box(b, x, Vector3(0, 1.7, -s.z * 0.5 + 0.12), Vector3(s.x, 0.04, 0.24), m["steel"])
	for sx: float in [-0.42, 0.0, 0.42]:
		_box(b, x, Vector3(s.x * sx, 1.62, -s.z * 0.5 + 0.1), Vector3(0.03, 0.14, 0.18), m["steel"])
	for i in 7:
		if rng.randf() < 0.3:
			continue
		_cyl(b, x, Vector3(-s.x * 0.45 + i * s.x * 0.15, 1.82, -s.z * 0.5 + 0.12), 0.05, 0.2, m["liquid"] if i % 2 == 0 else m["glass"])
	_box(b, x, Vector3(s.x * 0.3, 0.92, 0.0), Vector3(0.5, 0.06, 0.4), m["dark"])
	_strut(b, x, Vector3(s.x * 0.3, 0.96, -0.25), Vector3(s.x * 0.3, 1.25, -0.05), 0.02, m["steel"])
	_microscope(b, x, Vector3(-s.x * 0.3, 0.96, 0.0), m)
	for i in rng.randi_range(2, 4):
		_cyl(b, x, Vector3(rng.randf_range(-0.15, 0.15), 1.02, rng.randf_range(-0.2, 0.2)), 0.045, 0.14, m["liquid"] if rng.randf() < 0.5 else m["glass"])


## A microscope: base, arm, stage on the arm, and the tube held out over the stage.
static func _microscope(b: Models.Batch, x: Transform3D, p: Vector3, m: Dictionary) -> void:
	_box(b, x, p + Vector3(0, 0.03, 0), Vector3(0.22, 0.06, 0.28), m["white"])
	_box(b, x, p + Vector3(0, 0.2, -0.08), Vector3(0.06, 0.34, 0.06), m["white"])
	_box(b, x, p + Vector3(0, 0.13, -0.01), Vector3(0.16, 0.02, 0.16), m["steel"])
	_box(b, x, p + Vector3(0, 0.33, -0.05), Vector3(0.05, 0.05, 0.08), m["white"])
	_cyl(b, x, p + Vector3(0, 0.3, 0.0), 0.028, 0.24, m["dark"], Vector3(-25, 0, 0))
	_cyl(b, x, p + Vector3(0, 0.19, 0.03), 0.018, 0.06, m["steel"])


## A desk console: a cabinet with keys, a sloped panel and a green screen.
static func _console(b: Models.Batch, x: Transform3D, s: Vector3, m: Dictionary, rng: RandomNumberGenerator) -> void:
	_box(b, x, Vector3(0, 0.45, -0.05), Vector3(s.x, 0.9, s.z - 0.1), m["olive"])
	_box(b, x, Vector3(0, 0.95, 0.02), Vector3(s.x, 0.12, s.z - 0.1), m["steel"], Vector3(-12, 0, 0))
	for i in 12:
		_box(b, x, Vector3(-s.x * 0.4 + (i % 6) * s.x * 0.16, 1.02, 0.05 + (i / 6) * 0.1), Vector3(0.08, 0.03, 0.07),
			m["amber"] if rng.randf() < 0.08 else m["dark"], Vector3(-12, 0, 0))
	_box(b, x, Vector3(0, 1.1, -s.z * 0.5 + 0.18), Vector3(s.x * 0.85, 0.5, 0.3), m["dark"])
	_screen(b, x, Vector3(0, 1.12, -s.z * 0.5 + 0.34), s.x * 0.55, 0.36, m, rng.randf() < 0.45, Vector3(-8, 0, 0))


## A bed along the wall with a rumpled blanket, and a side table at its foot.
static func _bed(b: Models.Batch, x: Transform3D, s: Vector3, m: Dictionary, rng: RandomNumberGenerator) -> void:
	var bw := s.x - 0.6
	var bx := -0.3
	_box(b, x, Vector3(bx, 0.35, 0), Vector3(bw, 0.08, s.z), m["steel"])
	_legs(b, x * Transform3D(Basis.IDENTITY, Vector3(bx, 0, 0)), bw, s.z, 0.34, m["steel"], 0.05)
	_box(b, x, Vector3(bx, 0.47, 0), Vector3(bw - 0.08, 0.16, s.z - 0.08), m["cloth"])
	_box(b, x, Vector3(bx - bw * 0.5 + 0.25, 0.6, 0), Vector3(0.35, 0.12, s.z * 0.65), m["white"], Vector3(0, 0, -6))
	_box(b, x, Vector3(bx + bw * 0.12, 0.58, 0.04), Vector3(bw * 0.62, 0.1, s.z - 0.02), m["olive"], Vector3(rng.randf_range(-3, 3), rng.randf_range(-6, 6), 0))
	_box(b, x, Vector3(bx - bw * 0.5 - 0.02, 0.55, 0), Vector3(0.05, 0.5, s.z), m["steel"])
	# Side table with a dead lamp and clutter.
	var tx := s.x * 0.5 - 0.27
	_box(b, x, Vector3(tx, 0.3, -0.1), Vector3(0.45, 0.6, 0.45), m["olive"])
	_box(b, x, Vector3(tx, 0.4, 0.13), Vector3(0.38, 0.02, 0.01), m["dark"])
	_cyl(b, x, Vector3(tx, 0.68, -0.15), 0.06, 0.16, m["steel"])
	_cyl(b, x, Vector3(tx, 0.8, -0.15), 0.1, 0.08, m["dead_glass"], Vector3.ZERO, 0.05)
	if rng.randf() < 0.6:
		_box(b, x, Vector3(tx + 0.08, 0.62, 0.0), Vector3(0.14, 0.03, 0.2), m["white"], Vector3(0, rng.randf_range(0, 60), 0))


## A serving counter with a steel top, hot trays and a sneeze guard.
static func _counter(b: Models.Batch, x: Transform3D, s: Vector3, m: Dictionary, rng: RandomNumberGenerator) -> void:
	_box(b, x, Vector3(0, 0.48, -0.02), Vector3(s.x, 0.96, s.z - 0.04), m["olive"])
	_box(b, x, Vector3(0, 0.98, 0), Vector3(s.x + 0.04, 0.05, s.z), m["steel"])
	for i in 4:
		_box(b, x, Vector3(-s.x * 0.36 + i * s.x * 0.24, 0.97, -0.05), Vector3(s.x * 0.2, 0.06, s.z * 0.55), m["dark"])
	_box(b, x, Vector3(0, 1.35, 0.1), Vector3(s.x - 0.1, 0.02, 0.45), m["glass"], Vector3(25, 0, 0))
	for sx: float in [-1.0, 1.0]:
		_box(b, x, Vector3(sx * (s.x * 0.5 - 0.05), 1.2, 0.0), Vector3(0.04, 0.45, 0.04), m["steel"])
	for i in rng.randi_range(1, 3):
		_box(b, x, Vector3(rng.randf_range(-1.0, 1.0), 1.02, s.z * 0.3), Vector3(0.35, 0.03, 0.25), m["steel"], Vector3(0, rng.randf_range(-30, 30), 0))


## A vending machine: a lit (or dead) panel and rows of slots.
static func _vending(b: Models.Batch, x: Transform3D, s: Vector3, m: Dictionary, rng: RandomNumberGenerator) -> void:
	_box(b, x, Vector3(0, s.y * 0.5, -0.02), Vector3(s.x, s.y, s.z - 0.04), m["rust"] if rng.randf() < 0.3 else m["olive"])
	var lit := rng.randf() < 0.4
	_box(b, x, Vector3(-0.12, s.y * 0.58, s.z * 0.5 - 0.02), Vector3(s.x * 0.62, s.y * 0.62, 0.03), m["screen"] if lit else m["dead_glass"])
	for r in 4:
		_box(b, x, Vector3(-0.12, s.y * 0.35 + r * s.y * 0.13, s.z * 0.5), Vector3(s.x * 0.58, 0.02, 0.06), m["steel"])
	_box(b, x, Vector3(s.x * 0.36, s.y * 0.6, s.z * 0.5), Vector3(0.16, 0.4, 0.03), m["dark"])
	_box(b, x, Vector3(0, 0.25, s.z * 0.5), Vector3(s.x * 0.7, 0.2, 0.04), m["dark"])


## A wall rack of rifles (some slots empty) under a stencilled header.
static func _gun_rack(b: Models.Batch, x: Transform3D, s: Vector3, m: Dictionary, rng: RandomNumberGenerator) -> void:
	_box(b, x, Vector3(0, s.y * 0.5, -s.z * 0.5 + 0.05), Vector3(s.x, s.y, 0.08), m["olive"])
	_box(b, x, Vector3(0, s.y - 0.08, 0), Vector3(s.x, 0.12, s.z), m["steel"])
	_box(b, x, Vector3(0, 0.35, 0), Vector3(s.x, 0.08, s.z), m["steel"])
	_box(b, x, Vector3(0, s.y - 0.2, -s.z * 0.5 + 0.1), Vector3(s.x * 0.5, 0.1, 0.01), m["yellow"])
	var n := 6
	for i in n:
		var gx := -s.x * 0.5 + s.x * (i + 0.5) / n
		_box(b, x, Vector3(gx, 0.42, 0.02), Vector3(0.12, 0.06, 0.25), m["dark"])
		if rng.randf() < 0.35:
			continue
		# A rifle standing in the rack: stock, receiver, barrel and magazine.
		var lean := rng.randf_range(-3, 3)
		_box(b, x, Vector3(gx, 0.62, 0.0), Vector3(0.07, 0.4, 0.14), m["gunmetal"], Vector3(0, 0, lean))
		_box(b, x, Vector3(gx, 1.05, 0.02), Vector3(0.08, 0.5, 0.12), m["gunmetal"], Vector3(0, 0, lean))
		_box(b, x, Vector3(gx, 1.05, 0.11), Vector3(0.05, 0.16, 0.08), m["dark"], Vector3(0, 0, lean))
		_cyl(b, x, Vector3(gx, 1.55, 0.0), 0.022, 0.55, m["dark"], Vector3(0, 0, lean))


## Ammunition crates: green boxes with yellow bands.
static func _ammo(_b: Models.Batch, x: Transform3D, s: Vector3, _m: Dictionary, rng: RandomNumberGenerator) -> void:
	for i in 3:
		var px := -s.x * 0.5 + 0.28 + i * 0.52
		var h := rng.randf_range(0.25, 0.35)
		for k in rng.randi_range(1, 2):
			var size := Vector3(0.48, h - 0.01, s.z - 0.1)
			_model("AmmoBox", x * Transform3D(Basis(Vector3.UP, deg_to_rad(rng.randf_range(-6, 6))) * Basis.from_scale(size / AMMO_SIZE), Vector3(px, k * h, 0)))


## Two tall gas tanks plumbed into the wall, with gauges.
static func _fuel_tanks(b: Models.Batch, x: Transform3D, s: Vector3, m: Dictionary, rng: RandomNumberGenerator) -> void:
	for sx: float in [-1.0, 1.0]:
		var p := Vector3(sx * s.x * 0.25, 0, 0.0)
		var mat: Material = m["red_paint"] if rng.randf() < 0.6 else m["yellow"]
		_cyl(b, x, p + Vector3(0, 1.0, 0), 0.4, 1.8, mat)
		_sph(b, x, p + Vector3(0, 1.9, 0), 0.4, mat, Vector3(1, 0.4, 1))
		_cyl(b, x, p + Vector3(0, 0.08, 0), 0.43, 0.16, m["steel"])
		for y: float in [0.5, 1.5]:
			_cyl(b, x, p + Vector3(0, y, 0), 0.41, 0.06, m["steel"])
		_cyl(b, x, p + Vector3(0, 2.1, 0), 0.05, 0.3, m["bronze"])
		_strut(b, x, p + Vector3(0, 2.2, 0), Vector3(p.x, 2.2, -s.z * 0.5), 0.05, m["bronze"])
		_cyl(b, x, p + Vector3(0, 1.3, 0.4), 0.09, 0.04, m["white"], Vector3(90, 0, 0))
		_box(b, x, p + Vector3(0, 0.95, 0.41), Vector3(0.3, 0.1, 0.01), m["dark"])


## An electrical cabinet: breakers, a warning sign and cables up into the ceiling.
static func _breaker(b: Models.Batch, x: Transform3D, s: Vector3, m: Dictionary, rng: RandomNumberGenerator) -> void:
	_box(b, x, Vector3(0, s.y * 0.5, -0.02), Vector3(s.x, s.y, s.z - 0.04), m["olive"])
	_box(b, x, Vector3(0, s.y * 0.5, s.z * 0.5 - 0.02), Vector3(s.x - 0.12, s.y - 0.2, 0.02), m["steel"])
	for r in 3:
		for c in 5:
			_box(b, x, Vector3(-s.x * 0.36 + c * s.x * 0.18, 0.7 + r * 0.45, s.z * 0.5 + 0.02), Vector3(0.1, 0.18, 0.05),
				m["red"] if rng.randf() < 0.06 else m["dark"])
	_box(b, x, Vector3(0, s.y - 0.25, s.z * 0.5 + 0.005), Vector3(0.5, 0.18, 0.01), m["yellow"])
	# Cables from its top up into the ceiling, in glands.
	var rise := maxf(_ceiling - s.y, 0.1)
	for i in 3:
		_cyl(b, x, Vector3(-0.4 + i * 0.4, s.y + rise * 0.5, -0.05), 0.04, rise + 0.1, m["rubber"])
		_cyl(b, x, Vector3(-0.4 + i * 0.4, s.y + 0.03, -0.05), 0.065, 0.06, m["gunmetal"])


## A wall of monitors: some dead, some still glowing.
static func _monitor_wall(b: Models.Batch, x: Transform3D, s: Vector3, m: Dictionary, rng: RandomNumberGenerator) -> void:
	_box(b, x, Vector3(0, 0.45, -0.02), Vector3(s.x, 0.9, s.z - 0.04), m["olive"])
	_box(b, x, Vector3(0, 1.4, -s.z * 0.5 + 0.06), Vector3(s.x, 1.0, 0.1), m["steel"])
	for i in 3:
		for r in 2:
			_screen(b, x, Vector3(-s.x * 0.33 + i * s.x * 0.33, 1.15 + r * 0.48, -s.z * 0.5 + 0.13), 0.62, 0.38, m, rng.randf() < 0.35)


## Two filing cabinets of four drawers; now and then a drawer is left pulled out (its sides and
## bottom run back into the cabinet, folders in it).
static func _filing(b: Models.Batch, x: Transform3D, s: Vector3, m: Dictionary, rng: RandomNumberGenerator) -> void:
	for i in 2:
		var cx := -s.x * 0.25 + i * s.x * 0.5
		var dw := s.x * 0.42
		_box(b, x, Vector3(cx, s.y * 0.5, -0.02), Vector3(s.x * 0.48, s.y, s.z - 0.04), m["steel"])
		for d in 4:
			var out := 0.25 if rng.randf() < 0.12 else 0.0
			var y := 0.2 + d * 0.33
			var face := s.z * 0.5 - 0.02 + out
			if out > 0.0:
				# The drawer's dark slot in the cabinet, and the drawer itself out of it.
				_box(b, x, Vector3(cx, y, s.z * 0.5 - 0.035), Vector3(dw, 0.28, 0.01), m["black"])
				var back := s.z * 0.5 - 0.3
				var length := face - back
				for sx: float in [-1.0, 1.0]:
					_box(b, x, Vector3(cx + sx * (dw * 0.5 - 0.03), y - 0.02, back + length * 0.5), Vector3(0.012, 0.2, length), m["olive_dark"])
				_box(b, x, Vector3(cx, y - 0.115, back + length * 0.5), Vector3(dw - 0.06, 0.012, length), m["olive_dark"])
				_box(b, x, Vector3(cx, y - 0.02, back + 0.006), Vector3(dw - 0.06, 0.2, 0.012), m["olive_dark"])
				for f in 5:
					_box(b, x, Vector3(cx + rng.randf_range(-0.02, 0.02), y - 0.03, back + 0.04 + f * (length - 0.1) / 4.0),
						Vector3(dw - 0.1, 0.17, 0.008), m["white"] if f % 2 == 0 else m["yellow"], Vector3(rng.randf_range(-8, 8), 0, 0))
			_box(b, x, Vector3(cx, y, face), Vector3(dw, 0.28, 0.04), m["olive"])
			_box(b, x, Vector3(cx, y + 0.08, face + 0.02), Vector3(0.12, 0.03, 0.03), m["bronze"])


## A heavy workbench with a vice and tools, a pegboard over it.
static func _workbench(b: Models.Batch, x: Transform3D, s: Vector3, m: Dictionary, rng: RandomNumberGenerator) -> void:
	_box(b, x, Vector3(0, 0.95, 0), Vector3(s.x, 0.08, s.z), m["steel"])
	_legs(b, x, s.x, s.z, 0.92, m["olive"], 0.09)
	_box(b, x, Vector3(0, 0.3, 0), Vector3(s.x - 0.2, 0.04, s.z - 0.2), m["olive"])
	# The pegboard on two posts from the worktop, its tools hung on pegs.
	_box(b, x, Vector3(0, 1.75, -s.z * 0.5 + 0.03), Vector3(s.x, 1.1, 0.04), m["olive"])
	for sx: float in [-1.0, 1.0]:
		_box(b, x, Vector3(sx * (s.x * 0.5 - 0.05), 1.6, -s.z * 0.5 + 0.03), Vector3(0.06, 1.3, 0.06), m["gunmetal"])
	for i in 8:
		var tx := -s.x * 0.42 + i * s.x * 0.12
		var ty := 1.95 + rng.randf_range(-0.25, 0.15)
		var tz := -s.z * 0.5 + 0.075
		var length := rng.randf_range(0.18, 0.34)
		var mat: Material = m["steel"] if i % 2 == 0 else m["dark"]
		_cyl(b, x, Vector3(tx, ty, tz - 0.02), 0.006, 0.06, m["steel"], Vector3(90, 0, 0), -1.0, 6)
		if i % 3 == 0:
			# A wrench: a shank and an open jaw at its top.
			_box(b, x, Vector3(tx, ty - length * 0.5, tz), Vector3(0.025, length, 0.012), mat)
			for jx: float in [-1.0, 1.0]:
				_box(b, x, Vector3(tx + jx * 0.022, ty + 0.02, tz), Vector3(0.016, 0.05, 0.012), mat)
		elif i % 3 == 1:
			# A hammer: a handle and its head across the top.
			_box(b, x, Vector3(tx, ty - length * 0.5, tz), Vector3(0.022, length, 0.022), m["wood"] if m.has("wood") else m["rust"])
			_box(b, x, Vector3(tx, ty - 0.01, tz), Vector3(0.11, 0.035, 0.035), mat)
		else:
			# A screwdriver: a handle and a blade below it.
			_cyl(b, x, Vector3(tx, ty - 0.045, tz), 0.014, 0.09, m["red_paint"], Vector3.ZERO, -1.0, 8)
			_cyl(b, x, Vector3(tx, ty - 0.09 - length * 0.3, tz), 0.004, length * 0.6, m["steel"], Vector3.ZERO, -1.0, 6)
	_box(b, x, Vector3(s.x * 0.35, 1.08, 0.1), Vector3(0.22, 0.18, 0.2), m["gunmetal"])
	_box(b, x, Vector3(-s.x * 0.2, 1.05, 0.05), Vector3(0.45, 0.12, 0.25), m["red_paint"])


static func _med_cabinet(b: Models.Batch, x: Transform3D, s: Vector3, m: Dictionary, _rng: RandomNumberGenerator) -> void:
	_box(b, x, Vector3(0, s.y * 0.5, -0.02), Vector3(s.x, s.y, s.z - 0.04), m["white"])
	_box(b, x, Vector3(0, s.y * 0.5, s.z * 0.5 - 0.02), Vector3(0.02, s.y - 0.1, 0.02), m["steel"])
	_box(b, x, Vector3(0, s.y * 0.72, s.z * 0.5 + 0.005), Vector3(0.3, 0.09, 0.01), m["red_paint"])
	_box(b, x, Vector3(0, s.y * 0.72, s.z * 0.5 + 0.005), Vector3(0.09, 0.3, 0.01), m["red_paint"])


## Heavy strongboxes with dials.
static func _strongbox(b: Models.Batch, x: Transform3D, s: Vector3, m: Dictionary, rng: RandomNumberGenerator) -> void:
	_box(b, x, Vector3(0, s.y * 0.5, 0), s - Vector3(0.04, 0, 0.04), m["gunmetal"])
	_box(b, x, Vector3(0, s.y * 0.5, s.z * 0.5 - 0.01), Vector3(s.x - 0.2, s.y - 0.2, 0.03), m["steel"])
	_cyl(b, x, Vector3(0.2, s.y * 0.55, s.z * 0.5 + 0.02), 0.08, 0.04, m["bronze"], Vector3(90, 0, 0))
	for sx: float in [-1.0, 1.0]:
		_box(b, x, Vector3(sx * (s.x * 0.5 - 0.03), s.y * 0.5, s.z * 0.5 - 0.15), Vector3(0.05, s.y * 0.6, 0.08), m["dark"])
	if rng.randf() < 0.5:
		_box(b, x, Vector3(0.1, s.y + 0.15, 0), Vector3(0.6, 0.3, 0.5), m["crate"], Vector3(0, rng.randf_range(-20, 20), 0))


## Drums with bands, one of them toppled.
static func _barrels(b: Models.Batch, x: Transform3D, s: Vector3, m: Dictionary, rng: RandomNumberGenerator) -> void:
	var mats: Array = [m["rust"], m["olive"], m["yellow"], m["red_paint"]]
	for i in 3:
		var p := Vector3(-s.x * 0.5 + 0.3 + i * 0.5, 0, rng.randf_range(-0.1, 0.1))
		var mat: Material = mats[rng.randi() % mats.size()]
		if i == 2 and rng.randf() < 0.4:
			_cyl(b, x, p + Vector3(0, 0.28, 0.05), 0.27, 0.85, mat, Vector3(0, rng.randf_range(-20, 20), 90))
			continue
		_cyl(b, x, p + Vector3(0, 0.45, 0), 0.27, 0.9, mat)
		for y: float in [0.25, 0.65]:
			_cyl(b, x, p + Vector3(0, y, 0), 0.28, 0.04, m["steel"])
		_cyl(b, x, p + Vector3(0.1, 0.91, 0.05), 0.04, 0.03, m["dark"])


## A bundle of pipes up the wall, from flanges on the floor up into the ceiling, with valve wheels
## and brackets.
static func _pipes(b: Models.Batch, x: Transform3D, s: Vector3, m: Dictionary, rng: RandomNumberGenerator) -> void:
	var h := maxf(_ceiling, s.y)
	for i in 3:
		var px := -s.x * 0.33 + i * s.x * 0.33
		var r := rng.randf_range(0.06, 0.11)
		var mat: Material = m["bronze"] if i % 2 == 0 else m["olive"]
		var pz := -s.z * 0.5 + 0.15
		_cyl(b, x, Vector3(px, h * 0.5, pz), r, h + 0.1, mat)
		_cyl(b, x, Vector3(px, 0.03, pz), r + 0.06, 0.06, m["gunmetal"])
		_cyl(b, x, Vector3(px, h - 0.06, pz), r + 0.04, 0.12, m["gunmetal"])
		for k in 2:
			_cyl(b, x, Vector3(px, h * (0.33 + k * 0.33), pz), r + 0.025, 0.05, mat)
		if rng.randf() < 0.6:
			var y := rng.randf_range(0.9, 1.6)
			_cyl(b, x, Vector3(px, y, -s.z * 0.5 + 0.15 + r + 0.05), r * 1.2, 0.08, m["steel"], Vector3(90, 0, 0))
			_cyl(b, x, Vector3(px, y, -s.z * 0.5 + 0.15 + r + 0.18), 0.16, 0.03, m["red_paint"], Vector3(90, 0, 0))
			for k in 4:
				_box(b, x, Vector3(px, y, -s.z * 0.5 + 0.15 + r + 0.18), Vector3(0.3, 0.025, 0.025), m["red_paint"], Vector3(0, 0, k * 45))
	for y: float in [0.6, 2.0, 3.3]:
		_box(b, x, Vector3(0, y, -s.z * 0.5 + 0.08), Vector3(s.x, 0.08, 0.16), m["steel"])
		for i in 3:
			_box(b, x, Vector3(-s.x * 0.33 + i * s.x * 0.33, y, -s.z * 0.5 + 0.2), Vector3(0.05, 0.05, 0.2), m["steel"])


# --- Free-standing ------------------------------------------------------------------------------

## A specimen tank: a pedestal, a cylinder of glowing fluid with something floating in it, and a cap
## with cables to the ceiling. Some have been drained, some smashed (and whatever was inside is gone).
static func _tube(root: Node3D, b: Models.Batch, x: Transform3D, s: Vector3, m: Dictionary, rng: RandomNumberGenerator, v: int,
		out: Dictionary) -> void:
	var r := s.x * 0.5
	var state := v % 5
	_cyl(b, x, Vector3(0, 0.18, 0), r, 0.36, m["steel"], Vector3.ZERO, r - 0.05, 8)
	_cyl(b, x, Vector3(0, 0.38, 0), r - 0.08, 0.06, m["bronze"], Vector3.ZERO, -1.0, 8)
	_cyl(b, x, Vector3(0, s.y - 0.22, 0), r - 0.02, 0.36, m["steel"], Vector3.ZERO, r - 0.12, 8)
	_cyl(b, x, Vector3(0, s.y - 0.42, 0), r - 0.08, 0.06, m["bronze"], Vector3.ZERO, -1.0, 8)
	for i in 4:
		var a := i * TAU / 4.0 + PI / 4.0
		_box(b, x, Vector3(cos(a) * (r - 0.1), s.y * 0.5, sin(a) * (r - 0.1)), Vector3(0.06, s.y - 0.7, 0.06), m["bronze"])
	# Cables from the cap up into the ceiling, where they go in through a plate.
	var top := maxf(_ceiling, s.y + 0.3)
	for i in 3:
		var a := i * TAU / 3.0
		_strut(b, x, Vector3(cos(a) * 0.25, s.y, sin(a) * 0.25), Vector3(cos(a) * 0.4, top + 0.05, sin(a) * 0.4), 0.04, m["rubber"])
	_cyl(b, x, Vector3(0, top - 0.02, 0), 0.6, 0.04, m["gunmetal"], Vector3.ZERO, -1.0, 12)
	_box(b, x, Vector3(0, 0.5, r - 0.02), Vector3(0.36, 0.22, 0.06), m["dark"])
	_box(b, x, Vector3(0, 0.5, r + 0.012), Vector3(0.28, 0.14, 0.01), m["screen"] if state < 3 else m["dead_glass"])
	var glass_h := s.y - 0.84
	var glass_y := 0.41 + glass_h * 0.5
	if state == 4:
		# Smashed: jagged glass round the rim and shards on the floor, a dry stain.
		for i in 9:
			var a := i * TAU / 9.0 + rng.randf_range(-0.1, 0.1)
			var h := rng.randf_range(0.1, 0.7)
			_box(b, x, Vector3(cos(a) * (r - 0.12), 0.41 + h * 0.5, sin(a) * (r - 0.12)), Vector3(0.22, h, 0.015), m["glass"],
				Vector3(rng.randf_range(-10, 10), -rad_to_deg(a) + 90.0, rng.randf_range(-15, 15)))
		for i in 7:
			var a := rng.randf() * TAU
			var d := rng.randf_range(r + 0.1, r + 1.1)
			_box(b, x, Vector3(cos(a) * d, 0.01, sin(a) * d), Vector3(rng.randf_range(0.08, 0.25), 0.01, rng.randf_range(0.05, 0.18)), m["glass"],
				Vector3(0, rng.randf_range(0, 180), 0))
		_cyl(b, x, Vector3(0.3, 0.006, 0.4), 1.1, 0.01, m["stain"], Vector3.ZERO, -1.0, 10)
		return
	var tank := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r - 0.1
	cm.bottom_radius = r - 0.1
	cm.height = glass_h
	cm.radial_segments = 20
	cm.rings = 1
	cm.cap_top = false
	cm.cap_bottom = false
	tank.mesh = cm
	tank.material_override = tank_material()
	tank.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tank.transform = x * Transform3D(Basis.IDENTITY, Vector3(0, glass_y, 0))
	tank.set_instance_shader_parameter("level", 0.93 if state < 3 else 0.12)
	tank.set_instance_shader_parameter("seed", float(v % 97))
	root.add_child(tank)
	(out["tanks"] as Array).append(tank)
	var subject := Node3D.new()
	subject.transform = x * Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(0, glass_y + (0.1 if state < 3 else -glass_h * 0.38), 0))
	root.add_child(subject)
	_specimen(subject, v % 3, state >= 3)
	(out["subjects"] as Array).append({"node": subject, "base": subject.transform, "phase": rng.randf() * TAU, "float": state < 3})
	if state < 3 and v % 2 == 0:
		var l := OmniLight3D.new()
		l.light_color = Color(0.62, 0.75, 0.45)
		l.light_energy = 0.35
		l.omni_range = 3.6
		l.position = x * Vector3(0, s.y * 0.55, 0)
		root.add_child(l)


static func tank_material() -> ShaderMaterial:
	if not _shared.has("tank"):
		var sh := Shader.new()
		sh.code = TANK_SHADER
		var mat := ShaderMaterial.new()
		mat.shader = sh
		_shared["tank"] = mat
	return _shared["tank"]


## Something that floats in a specimen tank: a curled foetal alien, a crewman half turned into one,
## or a crawler with its legs folded. `slumped`: the tank was drained and it lies at the bottom.
static func _specimen(root: Node3D, kind: int, slumped: bool) -> void:
	var skin := Alien.organic(Color(0.42, 0.33, 0.3), Color(0.5, 1.0, 0.4), 1.0, 5.0)
	var pale := Alien.organic(Color(0.62, 0.55, 0.5), Color(0.9, 0.5, 0.3), 0.6, 7.0)
	match kind:
		0:
			var body := MeshInstance3D.new()
			body.mesh = Models.blob_mesh(11, 0.32, 0.3, 14)
			body.material_override = skin
			body.scale = Vector3(0.9, 1.25, 0.75)
			root.add_child(body)
			Models.sphere(root, Vector3(0, 0.42, -0.12), 0.2, skin, Vector3(0.8, 1.0, 1.5))
			Models.capsule(root, Vector3(0, 0.62, 0.15), 0.08, 0.5, skin, Vector3(-60, 0, 0))
			for sx: float in [-1.0, 1.0]:
				Models.strut(root, Vector3(sx * 0.18, 0.1, -0.1), Vector3(sx * 0.35, -0.2, -0.3), 0.05, skin)
				Models.strut(root, Vector3(sx * 0.2, -0.25, 0.0), Vector3(sx * 0.12, -0.5, -0.3), 0.06, skin)
			Models.capsule(root, Vector3(0, -0.45, 0.2), 0.06, 0.6, skin, Vector3(50, 0, 0))
		1:
			var suit := Models.mat(Color(0.32, 0.34, 0.3), 0.2, 0.75)
			Models.capsule(root, Vector3(0, 0.0, 0), 0.24, 0.9, suit)
			var growth := MeshInstance3D.new()
			growth.mesh = Models.blob_mesh(23, 0.3, 0.45, 12)
			growth.material_override = pale
			growth.position = Vector3(0.1, 0.2, 0.08)
			growth.scale = Vector3(1.0, 1.3, 0.9)
			root.add_child(growth)
			Models.sphere(root, Vector3(0, 0.62, 0), 0.19, pale, Vector3(1.0, 1.3, 1.1))
			for sx: float in [-1.0, 1.0]:
				Models.strut(root, Vector3(sx * 0.25, 0.3, 0), Vector3(sx * 0.45, -0.3, 0.1), 0.06, suit)
				Models.strut(root, Vector3(sx * 0.12, -0.45, 0), Vector3(sx * 0.15, -0.9, 0.05), 0.07, suit)
			Models.strut(root, Vector3(0.25, 0.3, 0), Vector3(0.55, 0.65, -0.2), 0.05, pale)
		_:
			var body := MeshInstance3D.new()
			body.mesh = Models.blob_mesh(37, 0.22, 0.25, 12)
			body.material_override = skin
			body.scale = Vector3(1.2, 0.8, 1.4)
			root.add_child(body)
			for i in 8:
				var a := i * TAU / 8.0
				var d := Vector3(cos(a), 0, sin(a))
				Models.strut(root, d * 0.18, d * 0.42 + Vector3(0, 0.15, 0), 0.03, skin)
				Models.strut(root, d * 0.42 + Vector3(0, 0.15, 0), d * 0.3 + Vector3(0, -0.25, 0), 0.025, skin)
			Models.capsule(root, Vector3(0, 0, 0.45), 0.05, 0.7, skin, Vector3(80, 0, 0))
	if slumped:
		root.rotation.x = 1.2
		root.scale = Vector3.ONE * 0.9


## A lab table with instruments: a microscope, flasks, a sample rack and a terminal.
static func _lab_table(b: Models.Batch, x: Transform3D, s: Vector3, m: Dictionary, rng: RandomNumberGenerator) -> void:
	_box(b, x, Vector3(0, 0.93, 0), Vector3(s.x, 0.06, s.z), m["white"])
	_legs(b, x, s.x, s.z, 0.9, m["steel"])
	_box(b, x, Vector3(0, 0.3, 0), Vector3(s.x - 0.2, 0.03, s.z - 0.2), m["steel"])
	_microscope(b, x, Vector3(-s.x * 0.3, 0.96, 0.15), m)
	_box(b, x, Vector3(s.x * 0.25, 1.15, -0.2), Vector3(0.5, 0.38, 0.35), m["olive"])
	_screen(b, x, Vector3(s.x * 0.25, 1.17, -0.02), 0.34, 0.24, m, rng.randf() < 0.5)
	_box(b, x, Vector3(0, 0.98, 0.25), Vector3(0.4, 0.05, 0.14), m["steel"])
	for i in 5:
		_cyl(b, x, Vector3(-0.16 + i * 0.08, 1.06, 0.25), 0.018, 0.14, m["liquid"] if i % 2 == 0 else m["glass"])
	for i in rng.randi_range(2, 4):
		var p := Vector3(rng.randf_range(-0.5, 0.6), 0.96, rng.randf_range(-0.35, 0.35))
		_cyl(b, x, p + Vector3(0, 0.1, 0), 0.07, 0.2, m["liquid"] if rng.randf() < 0.5 else m["glass"], Vector3.ZERO, 0.03)


## A pallet stacked with crates and strapped down.
static func _pallet(b: Models.Batch, x: Transform3D, s: Vector3, m: Dictionary, rng: RandomNumberGenerator) -> void:
	_box(b, x, Vector3(0, 0.07, 0), Vector3(s.x - 0.1, 0.14, s.z - 0.1), m["steel"])
	for sx: float in [-1.0, 1.0]:
		_box(b, x, Vector3(sx * 0.6, 0.03, 0), Vector3(0.18, 0.06, s.z - 0.1), m["dark"])
	var layers := rng.randi_range(1, 2)
	# How many layers stand in each row of crates (along z): a strap goes over a row only as high
	# as both its stacks reach.
	var rows := [layers, layers]
	for k in layers:
		for i in 2:
			for j in 2:
				if k > 0 and rng.randf() < 0.35:
					rows[j] = mini(int(rows[j]), k)
					continue
				_crate(b, x, Vector3(-0.47 + i * 0.94, 0.14 + k * 0.82, -0.47 + j * 0.94), Vector3(0.88, 0.8, 0.88), m, rng.randf_range(-4, 4))
	# A strap over each row and down to the pallet.
	for j in 2:
		var sz := -0.47 + j * 0.94
		var top := 0.12 + int(rows[j]) * 0.82
		_box(b, x, Vector3(0, top + 0.012, sz), Vector3(1.9, 0.02, 0.06), m["yellow"])
		for sx: float in [-1.0, 1.0]:
			_box(b, x, Vector3(sx * 0.95, (0.12 + top) * 0.5, sz), Vector3(0.02, top - 0.1, 0.06), m["yellow"])


## A small mess table with four stools.
static func _table(b: Models.Batch, x: Transform3D, s: Vector3, m: Dictionary, rng: RandomNumberGenerator) -> void:
	_box(b, x, Vector3(0, 0.76, 0), Vector3(1.2, 0.05, 1.2), m["steel"])
	_cyl(b, x, Vector3(0, 0.38, 0), 0.08, 0.76, m["dark"])
	_cyl(b, x, Vector3(0, 0.03, 0), 0.4, 0.06, m["dark"])
	for i in 4:
		var a := i * TAU / 4.0 + rng.randf_range(-0.3, 0.3)
		var p := Vector3(cos(a), 0, sin(a)) * 0.9
		if rng.randf() < 0.2:
			# Knocked over: on its side, its seat on edge and its post along the floor.
			var lie := x * Transform3D(Basis(Vector3.UP, -a), p)
			b.cyl_at(lie * Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(0, 0.2, 0.0)), 0.2, 0.06, m["olive"], -1.0, 12)
			b.cyl_at(lie * Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(0, 0.2, 0.25)), 0.04, 0.44, m["dark"], -1.0, 12)
			continue
		_cyl(b, x, p + Vector3(0, 0.45, 0), 0.2, 0.06, m["olive"])
		_cyl(b, x, p + Vector3(0, 0.22, 0), 0.04, 0.44, m["dark"])
	_box(b, x, Vector3(0.2, 0.8, -0.1), Vector3(0.3, 0.02, 0.22), m["steel"], Vector3(0, rng.randf_range(0, 90), 0))
	_cyl(b, x, Vector3(-0.25, 0.84, 0.2), 0.05, 0.1, m["white"])


## A long mess table with a bench either side.
static func _mess_table(b: Models.Batch, x: Transform3D, s: Vector3, m: Dictionary, rng: RandomNumberGenerator) -> void:
	var length := s.z
	_box(b, x, Vector3(0, 0.76, 0), Vector3(1.0, 0.06, length), m["steel"])
	_box(b, x, Vector3(0, 0.72, 0), Vector3(0.9, 0.04, length - 0.1), m["olive"])
	var legs := maxi(2, int(length / 2.0) + 1)
	for i in legs:
		var z := -length * 0.5 + 0.2 + (length - 0.4) * i / float(legs - 1)
		_box(b, x, Vector3(0, 0.37, z), Vector3(0.7, 0.74, 0.08), m["dark"])
		for sx: float in [-1.0, 1.0]:
			_box(b, x, Vector3(sx * 0.85, 0.22, z), Vector3(0.08, 0.44, 0.08), m["dark"])
	for sx: float in [-1.0, 1.0]:
		_box(b, x, Vector3(sx * 0.85, 0.46, 0), Vector3(0.36, 0.05, length - 0.2), m["olive"])
	for i in int(length / 0.9):
		if rng.randf() < 0.55:
			continue
		var z := -length * 0.5 + 0.45 + i * 0.9
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		_box(b, x, Vector3(side * 0.25, 0.8, z), Vector3(0.32, 0.02, 0.24), m["steel"], Vector3(0, rng.randf_range(-25, 25), 0))
		if rng.randf() < 0.5:
			_cyl(b, x, Vector3(side * 0.1, 0.85, z + 0.15), 0.04, 0.1, m["white"])


## The control hub's desk (a rough first version, plain boxes): the control computer (HubConsole: a
## green-screen terminal and its keyboard) on a desk; behind it a big board with the station's map
## on it (the Derelict draws it: "hub_map"); up over the board, out of the way, a bridge of four
## monitors for the camera feeds (set up by the Derelict), tilted down at the desk; a chair in front.
## The piece faces its +z: the desk's side.
static func _hub_desk(root: Node3D, b: Models.Batch, x: Transform3D, s: Vector3, m: Dictionary, rng: RandomNumberGenerator,
		out: Dictionary) -> void:
	var half := s.z * 0.5
	# The desk: a top on two pedestals of drawers, a panel at its back.
	_box(b, x, Vector3(0, 0.9, half - 0.42), Vector3(s.x - 0.5, 0.06, 0.8), m["olive_dark"])
	_box(b, x, Vector3(0, 0.935, half - 0.04), Vector3(s.x - 0.5, 0.012, 0.05), m["bronze"])
	for sx: float in [-1.0, 1.0]:
		_box(b, x, Vector3(sx * (s.x * 0.5 - 0.55), 0.44, half - 0.42), Vector3(0.5, 0.88, 0.76), m["olive"])
		for k in 3:
			_box(b, x, Vector3(sx * (s.x * 0.5 - 0.55), 0.2 + k * 0.24, half - 0.03), Vector3(0.42, 0.19, 0.02), m["mid"])
			_box(b, x, Vector3(sx * (s.x * 0.5 - 0.55), 0.24 + k * 0.24, half - 0.015), Vector3(0.12, 0.025, 0.02), m["steel"])
	_box(b, x, Vector3(0, 0.5, half - 0.8), Vector3(s.x - 1.5, 0.8, 0.04), m["olive"])
	# The map board behind the desk: a heavy frame round the big screen, on two legs.
	var board_z := -half + 0.12
	_box(b, x, Vector3(0, 1.72, board_z), Vector3(s.x - 0.1, 1.84, 0.1), m["gunmetal"])
	for y: float in [0.82, 2.62]:
		_box(b, x, Vector3(0, y, board_z + 0.06), Vector3(s.x - 0.1, 0.08, 0.06), m["bronze"])
	for sx: float in [-1.0, 1.0]:
		_box(b, x, Vector3(sx * (s.x * 0.5 - 0.09), 1.72, board_z + 0.06), Vector3(0.08, 1.84, 0.06), m["bronze"])
		_box(b, x, Vector3(sx * (s.x * 0.5 - 0.25), 0.4, board_z), Vector3(0.12, 0.8, 0.18), m["gunmetal"])
	var map := MeshInstance3D.new()
	var mq := QuadMesh.new()
	mq.size = Vector2(s.x - 0.34, 1.62)
	map.mesh = mq
	map.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	map.transform = x * Transform3D(Basis.IDENTITY, Vector3(0, 1.72, board_z + 0.056))
	map.set_meta("yaw", atan2(x.basis.z.x, x.basis.z.z))
	root.add_child(map)
	out["hub_map"] = map
	# The monitor bridge over the board: two posts and a beam, four monitors tilted down at the desk.
	for sx: float in [-1.0, 1.0]:
		_box(b, x, Vector3(sx * (s.x * 0.5 - 0.3), 2.95, board_z), Vector3(0.08, 0.6, 0.08), m["gunmetal"])
	_box(b, x, Vector3(0, 3.2, board_z), Vector3(s.x - 0.4, 0.1, 0.12), m["gunmetal"])
	for i in 4:
		var sx := -s.x * 0.36 + i * s.x * 0.24
		var mx := x * Transform3D(Models.euler(Vector3(18, 0, 0)), Vector3(sx, 2.9, board_z + 0.14))
		b.box_at(mx * Transform3D(Basis.IDENTITY, Vector3(0, 0, -0.08)), Vector3(0.66, 0.5, 0.16), m["dark"])
		var screen := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.58, 0.42)
		screen.mesh = q
		screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		screen.transform = mx * Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.002))
		root.add_child(screen)
		(out["screens"] as Array).append(screen)
	# The control computer on the desk, and a chair in front of it.
	var console := HubConsole.new()
	console.transform = x * Transform3D(Basis.IDENTITY, Vector3(0, 0.93, half - 0.45))
	root.add_child(console)
	console.build(m)
	out["hub_console"] = console
	_model("Chair", x * Transform3D(Basis(Vector3.UP, rng.randf_range(-0.3, 0.3)), Vector3(0, 0, half + 0.45)))


## The gas generator: an engine block on a skid with its cylinders, a flywheel (turning when it
## runs), a radiator, exhaust stacks up into the ceiling, a control box with gauges on a stand on the
## skid, and the pull starter on the crankcase. The Derelict turns the flywheel, shakes the engine
## and puffs the exhausts.
static func _generator(root: Node3D, b: Models.Batch, x: Transform3D, s: Vector3, m: Dictionary, _rng: RandomNumberGenerator,
		out: Dictionary) -> void:
	# The engine, its skid and the flywheel are a model (tools/blender/outpost_generator.py).
	var half := s.z * 0.5
	Models.asset_mesh(root, "outpost_generator", "Skid", {}, x)
	var engine := Node3D.new()
	engine.transform = x
	root.add_child(engine)
	Models.asset_mesh(engine, "outpost_generator", "Engine")
	var wheel := Node3D.new()
	wheel.position = Vector3(0, 1.1, -half + 0.25)
	engine.add_child(wheel)
	Models.asset_mesh(wheel, "outpost_generator", "Flywheel")
	# The exhaust stacks from the manifolds' flanges up through the ceiling, with a bellows each
	# (the engine shakes; they don't).
	for sx: float in [-1.0, 1.0]:
		_cyl(b, x, Vector3(sx * 0.85, 2.55, 0.6), 0.15, 0.22, m["rubber"], Vector3.ZERO, -1.0, 14)
		for k in 3:
			_cyl(b, x, Vector3(sx * 0.85, 2.47 + k * 0.08, 0.6), 0.165, 0.025, m["dark"], Vector3.ZERO, -1.0, 14)
		_cyl(b, x, Vector3(sx * 0.85, 4.2, 0.6), 0.13, 3.1, m["steel"], Vector3.ZERO, -1.0, 12)
		_cyl(b, x, Vector3(sx * 0.85, 2.7, 0.6), 0.16, 0.05, m["steel"], Vector3.ZERO, -1.0, 12)
		_cyl(b, x, Vector3(sx * 0.85, 3.9, 0.6), 0.15, 0.04, m["bronze"], Vector3.ZERO, -1.0, 12)
	# The control box with its gauges and lamp, on a stand bolted to the skid's rail (two legs on a
	# foot plate), its cables running into the crankcase.
	var ctrl := Vector3(1.1, 1.05, -0.6)
	_box(b, x, ctrl, Vector3(0.12, 0.8, 0.9), m["steel"])
	_box(b, x, Vector3(1.08, 0.215, -0.6), Vector3(0.2, 0.03, 0.8), m["gunmetal"])
	for dz: float in [-0.32, 0.32]:
		_box(b, x, Vector3(1.1, 0.44, -0.6 + dz), Vector3(0.06, 0.42, 0.06), m["gunmetal"])
		for sz: float in [-0.06, 0.06]:
			_cyl(b, x, Vector3(1.1 + sz * 0.9, 0.235, -0.6 + dz + sz), 0.012, 0.012, m["steel"], Vector3.ZERO, -1.0, 6)
	_box(b, x, Vector3(1.1, 0.67, -0.6), Vector3(0.08, 0.04, 0.76), m["gunmetal"])
	for i in 3:
		_strut(b, x, Vector3(1.04, 0.82 + i * 0.07, -0.78 + i * 0.16), Vector3(0.6, 0.62 + i * 0.1, -0.62 + i * 0.12), 0.016, m["rubber"])
		_cyl(b, x, Vector3(0.61, 0.62 + i * 0.1, -0.62 + i * 0.12), 0.03, 0.03, m["gunmetal"], Vector3(0, 0, 90), -1.0, 8)
	# The pull starter: a recoil drum bolted to the crankcase's side, its cord out of the middle of
	# the drum to the handle resting against it.
	var drum := Vector3(0.69, 0.75, 0.3)
	_cyl(b, x, Vector3(0.615, drum.y, drum.z), 0.18, 0.03, m["gunmetal"], Vector3(0, 0, 90), -1.0, 18)
	for k in 6:
		var a := TAU * k / 6.0
		_cyl(b, x, Vector3(0.635, drum.y + sin(a) * 0.155, drum.z + cos(a) * 0.155), 0.012, 0.014, m["steel"], Vector3(0, 0, 90), -1.0, 6)
	_cyl(b, x, drum, 0.15, 0.14, m["olive_dark"], Vector3(0, 0, 90), -1.0, 20)
	_cyl(b, x, drum + Vector3(0.075, 0, 0), 0.12, 0.012, m["steel"], Vector3(0, 0, 90), -1.0, 20)
	_cyl(b, x, drum + Vector3(0.088, 0, 0), 0.032, 0.02, m["dark"], Vector3(0, 0, 90), -1.0, 10)
	for i in 2:
		_cyl(b, x, ctrl + Vector3(0.07, 0.15, -0.2 + i * 0.4), 0.11, 0.03, m["white"], Vector3(0, 0, 90))
		_box(b, x, ctrl + Vector3(0.085, 0.17, -0.2 + i * 0.4), Vector3(0.005, 0.12, 0.012), m["dark"], Vector3(30 - i * 50, 0, 0))
	_box(b, x, ctrl + Vector3(0.07, -0.25, 0.0), Vector3(0.01, 0.12, 0.6), m["yellow"])
	var lamp := MeshInstance3D.new()
	var lm := SphereMesh.new()
	lm.radius = 0.05
	lm.height = 0.1
	lamp.mesh = lm
	lamp.material_override = m["red"]
	lamp.transform = x * Transform3D(Basis.IDENTITY, ctrl + Vector3(0.08, 0.32, 0.3))
	root.add_child(lamp)
	# (The handle's stem rests against the drum's cord guide; pulled, the cord runs out of the drum.)
	var handle := Node3D.new()
	handle.transform = x * Transform3D(Basis.IDENTITY, Vector3(0.92, drum.y, drum.z))
	root.add_child(handle)
	Models.cylinder(handle, Vector3(0, 0, 0), 0.025, 0.24, m["dark"], Vector3(0, 0, 90))
	Models.box(handle, Vector3(0.12, 0, 0), Vector3(0.05, 0.05, 0.22), m["red_paint"])
	var cord := Models.cylinder(handle, Vector3(-0.08, 0, 0), 0.008, 0.16, m["rubber"], Vector3(0, 0, 90))
	var area := Area3D.new()
	area.collision_layer = Game.LAYER_INTERACT
	area.collision_mask = 0
	area.monitoring = false
	area.set_meta("generator", true)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.6, 0.9, 0.9)
	cs.shape = shape
	area.add_child(cs)
	area.transform = x * Transform3D(Basis.IDENTITY, Vector3(1.05, 0.8, drum.z))
	root.add_child(area)
	out["generator"] = {"engine": engine, "rest": engine.transform, "wheel": wheel, "handle": handle, "handle_rest": handle.transform,
		"cord": cord, "lamp": lamp, "exhausts": [x * Vector3(0.85, 3.0, 0.6), x * Vector3(-0.85, 3.0, 0.6)],
		"pos": x * Vector3(0, 1.3, 0), "outward": x.basis * Vector3(1, 0, 0)}


## A bench with a rifle in pieces on it and toolboxes.
static func _weapon_bench(_b: Models.Batch, x: Transform3D, _s: Vector3, _m: Dictionary, _rng: RandomNumberGenerator) -> void:
	_model("WeaponBench", x)


## A surgery table under a lamp arm, with a monitor cart.
static func _surgery(b: Models.Batch, x: Transform3D, s: Vector3, m: Dictionary, rng: RandomNumberGenerator) -> void:
	_box(b, x, Vector3(0, 0.85, 0), Vector3(s.x - 0.2, 0.1, 0.75), m["white"])
	_box(b, x, Vector3(0, 0.92, 0), Vector3(s.x - 0.3, 0.06, 0.65), m["cloth"])
	_cyl(b, x, Vector3(0, 0.42, 0), 0.12, 0.8, m["steel"])
	_box(b, x, Vector3(0, 0.03, 0), Vector3(0.9, 0.06, 0.6), m["steel"])
	_strut(b, x, Vector3(-s.x * 0.5 + 0.1, 0.0, -0.5), Vector3(-s.x * 0.5 + 0.1, 2.1, -0.5), 0.05, m["steel"])
	_strut(b, x, Vector3(-s.x * 0.5 + 0.1, 2.1, -0.5), Vector3(-0.1, 1.9, 0.0), 0.04, m["steel"])
	_cyl(b, x, Vector3(-0.1, 1.85, 0.0), 0.28, 0.12, m["white"], Vector3.ZERO, 0.15)
	_cyl(b, x, Vector3(-0.1, 1.78, 0.0), 0.24, 0.02, m["dead_glass"])
	_box(b, x, Vector3(s.x * 0.5 - 0.1, 0.7, 0.5), Vector3(0.4, 1.4, 0.35), m["olive"])
	_screen(b, x, Vector3(s.x * 0.5 - 0.1, 1.2, 0.7), 0.3, 0.22, m, rng.randf() < 0.5)
	if rng.randf() < 0.6:
		_box(b, x, Vector3(0.3, 0.96, 0.1), Vector3(0.6, 0.04, 0.4), m["stain"])


## A machine tool: a heavy bed, a chuck, a tool post and a guard.
static func _lathe(b: Models.Batch, x: Transform3D, s: Vector3, m: Dictionary, _rng: RandomNumberGenerator) -> void:
	_box(b, x, Vector3(0, 0.45, 0), Vector3(s.x - 0.2, 0.9, 0.7), m["olive"])
	_box(b, x, Vector3(0, 0.95, 0), Vector3(s.x - 0.1, 0.1, 0.5), m["steel"])
	_box(b, x, Vector3(-s.x * 0.36, 1.25, 0), Vector3(0.5, 0.6, 0.6), m["olive"])
	_cyl(b, x, Vector3(-s.x * 0.2, 1.2, 0), 0.18, 0.15, m["gunmetal"], Vector3(0, 0, 90))
	_cyl(b, x, Vector3(0.2, 1.2, 0), 0.04, 0.8, m["steel"], Vector3(0, 0, 90))
	_box(b, x, Vector3(0.4, 1.1, 0.15), Vector3(0.25, 0.2, 0.2), m["dark"])
	_box(b, x, Vector3(s.x * 0.38, 1.15, 0), Vector3(0.35, 0.35, 0.4), m["olive"])
	_box(b, x, Vector3(0, 1.45, -0.28), Vector3(s.x * 0.5, 0.4, 0.03), m["glass"], Vector3(-20, 0, 0))
	_box(b, x, Vector3(-s.x * 0.36, 1.45, 0.31), Vector3(0.2, 0.12, 0.01), m["yellow"])
