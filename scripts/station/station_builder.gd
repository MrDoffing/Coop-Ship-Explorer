class_name StationBuilder
extends RefCounted
## Builds a waystation: a hall built into the tunnel around a landing pad, sealed by a bulkhead at
## each end, with a pier from the ship's cargo ramp to the shop in the entrance bulkhead.
##
## Station-local frame (see CaveGen.station): -z along the tunnel (deeper, towards the exit), y up,
## origin on top of the landing pad. A landed mothership sits at (0, LAND_HEIGHT, 0) with its nose
## towards the exit, so the cargo ramp at its stern comes down onto the pier. Ships fly through the
## gates PASS_Y above the pad, over the shop, which sits under the entrance gate.

## Height of the ship's origin above the pad when its landing legs are down. The ship's deck is
## then 1 m above the pier, which the open ramp bridges.
const LAND_HEIGHT := 4.2
## Height of the ship's origin above the pad while it flies through the gates. The tunnel's centre
## line runs LINE_Y above the pad (the autopilot flies 1.4 m below the centre line).
const PASS_Y := 14.5
const LINE_Y := 15.9
## The hall carved out of the rock (the bulkheads stand just inside its ends).
const HALL_HALF_X := 24.0
const HALL_FLOOR := -1.5
const HALL_ROOF := 33.0
const HALL_ENTRY := 38.0
const HALL_EXIT := -32.0
const HALL_ROUND := 3.0
## Entrance bulkhead: a block from FACADE_Z (its inner face) to ENTRY_FACE, holding the shop under
## its gate. Exit bulkhead: a wall from EXIT_INNER to EXIT_FACE.
const FACADE_Z := 20.0
const FACADE_T := 0.6
const ENTRY_FACE := 36.0
const EXIT_INNER := -26.0
const EXIT_FACE := -30.0
## Gate aperture in both bulkheads, and how far the door panels slide sideways to open.
const GATE_HALF_W := 15.0
const GATE_Y0 := 8.0
const GATE_Y1 := 24.5
const DOOR_TRAVEL := 15.6
## Bulkheads reach this far past the hall's walls into the rock.
const WALL_X := 25.5
const WALL_Y0 := -3.5
const WALL_Y1 := 35.0
## Walkway height (pier and shop floor).
const DECK_Y := 3.2
const PIER_START := 14.6
const PIER_HALF_W := 1.9
const DOOR_HALF_W := 1.6
const DOOR_H := 3.2
const ROOM_HALF_X := 9.0
const ROOM_END := 34.5
const ROOM_H := 4.0
## Shop pedestals: [x, z, yaw] of the item spots, and the height of the pedestals' tops.
const SHOP_SLOTS := [[-6.0, 30.6, 0.35], [-3.0, 32.1, 0.15], [0.0, 32.6, 0.0], [3.0, 32.1, -0.15], [6.0, 30.6, -0.35]]
const PEDESTAL_H := 0.75
## Defence turrets (station-local muzzle positions): under the roof inside both bulkheads, and above
## both gates outside.
const GUARDS := [Vector3(-17.0, 28.0, 16.5), Vector3(17.0, 28.0, 16.5), Vector3(-17.0, 28.0, -22.5),
	Vector3(17.0, 28.0, -22.5), Vector3(0, 28.6, 37.0), Vector3(0, 28.6, -31.0)]
## Aliens inside this station-local box (the hall and its approach tunnels) are shot down.
const SAFE_MIN := Vector3(-60.0, -30.0, EXIT_FACE - 70.0)
const SAFE_MAX := Vector3(60.0, 60.0, ENTRY_FACE + 70.0)

const HOLO_SHADER := """
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 tint : source_color = vec4(0.3, 0.8, 1.0, 1.0);
uniform float strength = 1.0;
varying vec3 lp;
void vertex() {
	lp = VERTEX;
}
void fragment() {
	float scan = 0.55 + 0.45 * sin(lp.y * 40.0 - TIME * 4.0);
	float rim = pow(1.0 - abs(dot(NORMAL, VIEW)), 1.5);
	ALBEDO = tint.rgb;
	ALPHA = clamp((0.08 + rim * 0.7) * scan * strength, 0.0, 1.0);
}
"""

static var _holo_shader: Shader


## Build the station's visuals and collision under `parent`. The returned Waystation sits at the
## station's transform (`parent` must be at the world origin) and animates the bulkhead doors.
static func build(parent: Node3D, st: Dictionary) -> Waystation:
	var root := Waystation.new()
	root.name = "Waystation%d" % int(st["k"])
	root.k = int(st["k"])
	root.transform = st["xform"]
	parent.add_child(root)
	var m := {
		"hull": Models.panel_mat(Color(0.5, 0.52, 0.56), 0.4, 0.55, 0.35),
		"wall": Models.panel_mat(Color(0.42, 0.44, 0.48), 0.45, 0.55, 0.2),
		"dark": Models.mat(Color(0.12, 0.13, 0.15), 0.5, 0.6),
		"mid": Models.mat(Color(0.3, 0.32, 0.36), 0.6, 0.45),
		"steel": Models.mat(Color(0.55, 0.57, 0.6), 0.75, 0.3),
		"floor": Models.panel_mat(Color(0.24, 0.26, 0.29), 0.5, 0.6, 0.5),
		"yellow": Models.mat(Color(0.95, 0.72, 0.12), 0.3, 0.5),
		"accent": Models.mat(Color(0.95, 0.5, 0.12), 0.3, 0.5),
		"black": Models.mat(Color(0.07, 0.07, 0.08), 0.4, 0.6),
		"amber": Models.emissive(Color(1.0, 0.6, 0.15), 3.0),
		"white": Models.emissive(Color(1.0, 0.95, 0.85), 2.5),
		"glass": Models.emissive(Color(0.45, 0.75, 1.0), 1.4, Color(0.03, 0.06, 0.09)),
	}
	var b := Models.Batch.new()
	_build_pad(root, b, m)
	_build_entry_block(root, b, st, m)
	_build_exit_wall(root, b, m)
	_build_pier(root, b, m)
	_build_room(root, b, m)
	_build_hall(root, b, m)
	b.commit(root, "Station")
	root.doors["entry"] = _build_door(root, FACADE_Z + 0.75, [FACADE_Z - FACADE_T * 0.5 - 0.12, ENTRY_FACE + 0.12], m, "ENTRY")
	root.doors["exit"] = _build_door(root, EXIT_INNER - 0.75, [EXIT_INNER + 0.12, EXIT_FACE - 0.12], m, "EXIT")
	return root


static func _body(root: Node3D, layers: int) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = layers
	body.collision_mask = 0
	root.add_child(body)
	return body


static func _shape(body: StaticBody3D, pos: Vector3, size: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.position = pos
	body.add_child(cs)


## A solid box from corner `lo` to corner `hi`: batched visual plus collision.
static func _block(b: Models.Batch, body: StaticBody3D, lo: Vector3, hi: Vector3, material: Material) -> void:
	var size := hi - lo
	var pos := (lo + hi) * 0.5
	b.box(pos, size, material)
	_shape(body, pos, size)


static func _solid(b: Models.Batch, body: StaticBody3D, pos: Vector3, size: Vector3, material: Material) -> void:
	b.box(pos, size, material)
	_shape(body, pos, size)


static func _label(root: Node3D, text: String, pos: Vector3, size: int, pixel: float, color: Color, yaw := PI) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = pixel
	l.outline_size = 12
	l.modulate = color
	l.position = pos
	l.rotation.y = yaw
	root.add_child(l)
	return l


# --- Parts -------------------------------------------------------------------------------------

static func _build_pad(root: Node3D, b: Models.Batch, m: Dictionary) -> void:
	var body := _body(root, Game.LAYER_CAVE)
	_solid(b, body, Vector3(0, -0.6, -2.0), Vector3(28.0, 1.2, 32.0), m["floor"])
	# Plinth sinking into the hall floor.
	b.box(Vector3(0, -2.8, -2.0), Vector3(27.0, 3.2, 31.0), m["dark"])
	# Touchdown ring and markings.
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 6.9
	torus.outer_radius = 7.5
	torus.rings = 48
	torus.ring_segments = 6
	ring.mesh = torus
	ring.material_override = m["yellow"]
	ring.scale = Vector3(1.0, 0.08, 1.0)
	root.add_child(ring)
	for x: float in [-1.6, 1.6]:
		b.box(Vector3(x, 0.015, 0), Vector3(0.5, 0.03, 5.0), m["yellow"])
	b.box(Vector3(0, 0.015, 0), Vector3(2.7, 0.03, 0.5), m["yellow"])
	# Guide arrow towards the exit and hazard stripes along both short edges.
	for i in 3:
		var z := -10.5 - i * 2.2
		for side: float in [-1.0, 1.0]:
			b.box(Vector3(side * 0.7, 0.015, z), Vector3(0.35, 0.03, 2.0), m["white"], Vector3(0, side * 35.0, 0))
	for i in 14:
		b.box(Vector3(-13.0 + i * 2.0, 0.015, -17.6), Vector3(0.9, 0.03, 0.9), m["yellow"], Vector3(0, 45, 0))
	for z: float in [-17.6, -13.0, -8.0, -3.0, 2.0, 7.0, 12.0]:
		for x: float in [-13.7, 13.7]:
			b.box(Vector3(x, 0.06, z), Vector3(0.3, 0.12, 0.3), m["amber"])
	# Fuel and power couplings at the back of the pad.
	for x: float in [-9.5, 9.5]:
		b.box(Vector3(x, 0.6, 12.0), Vector3(1.6, 1.2, 1.2), m["dark"])
		b.cyl(Vector3(x, 1.25, 12.0), 0.25, 0.3, Models.mat(Color(0.9, 0.2, 0.15), 0.3, 0.5))
		b.strut(Vector3(x, 1.0, 11.4), Vector3(x * 0.62, 0.15, 8.0), 0.09, Models.mat(Color(0.15, 0.15, 0.17), 0.2, 0.8))


## The entrance bulkhead: a block across the whole hall with the gate the ship flies through and
## the shop underneath it. Its inner face is the shop's facade at the end of the pier.
static func _build_entry_block(root: Node3D, b: Models.Batch, st: Dictionary, m: Dictionary) -> void:
	var body := _body(root, Game.LAYER_CAVE | Game.LAYER_STATION)
	var z0 := FACADE_Z - FACADE_T * 0.5
	var z1 := ENTRY_FACE
	var hx := ROOM_HALF_X + 0.25
	var room_top := DECK_Y + ROOM_H + 0.3
	# Below and beside the shop, a slab between the shop's ceiling and the gate, the gate's side
	# pillars and the wall above the gate.
	_block(b, body, Vector3(-WALL_X, WALL_Y0, z0), Vector3(WALL_X, DECK_Y - 0.3, z1), m["wall"])
	for side: float in [-1.0, 1.0]:
		_block(b, body, Vector3(minf(side * hx, side * WALL_X), DECK_Y - 0.3, z0), Vector3(maxf(side * hx, side * WALL_X), GATE_Y0, z1), m["wall"])
		_block(b, body, Vector3(minf(side * GATE_HALF_W, side * WALL_X), GATE_Y0, z0), Vector3(maxf(side * GATE_HALF_W, side * WALL_X), GATE_Y1, z1), m["wall"])
	_block(b, body, Vector3(-hx, room_top, z0), Vector3(hx, GATE_Y0, z1), m["wall"])
	_block(b, body, Vector3(-WALL_X, GATE_Y1, z0), Vector3(WALL_X, WALL_Y1, z1), m["wall"])
	# Behind the shop's back wall.
	_block(b, body, Vector3(-hx, DECK_Y - 0.3, ROOM_END + 0.25), Vector3(hx, room_top, z1), m["wall"])
	# The shop's front wall, with its door at the end of the pier.
	var side_w := hx - DOOR_HALF_W
	for side: float in [-1.0, 1.0]:
		_solid(b, body, Vector3(side * (DOOR_HALF_W + side_w * 0.5), (DECK_Y - 0.3 + room_top) * 0.5, FACADE_Z), Vector3(side_w, room_top - DECK_Y + 0.3, FACADE_T), m["hull"])
	_solid(b, body, Vector3(0, (DECK_Y + DOOR_H + room_top) * 0.5, FACADE_Z), Vector3(DOOR_HALF_W * 2.0, room_top - DECK_Y - DOOR_H, FACADE_T), m["hull"])
	# Facade dressing: ribs, a walkway ledge, windows and the door frame.
	var fz := z0 - 0.02
	for x: float in [-21.0, -12.0, 12.0, 21.0]:
		b.box(Vector3(x, (WALL_Y0 + GATE_Y1) * 0.5 + 2.0, fz - 0.2), Vector3(0.8, GATE_Y1 - WALL_Y0 + 4.0, 0.4), m["mid"])
	for side: float in [-1.0, 1.0]:
		b.box(Vector3(side * 19.5, 14.0, fz), Vector3(5.5, 2.4, 0.05), m["glass"])
		b.box(Vector3(side * 19.5, 18.5, fz), Vector3(5.5, 1.2, 0.05), m["glass"])
		b.box(Vector3(side * 12.0, 6.0, fz), Vector3(4.2, 1.4, 0.05), m["glass"])
		b.box(Vector3(side * 19.5, 12.6, fz - 0.5), Vector3(6.0, 0.25, 1.0), m["dark"])
	b.box(Vector3(0, DECK_Y + DOOR_H + 0.2, fz - 0.06), Vector3(DOOR_HALF_W * 2.0 + 0.8, 0.4, 0.12), m["accent"])
	for side: float in [-1.0, 1.0]:
		b.box(Vector3(side * (DOOR_HALF_W + 0.2), DECK_Y + DOOR_H * 0.5, fz - 0.06), Vector3(0.4, DOOR_H, 0.12), m["accent"])
		for i in 4:
			b.box(Vector3(side * (DOOR_HALF_W + 0.2), DECK_Y + 0.4 + i * 0.8, fz - 0.13), Vector3(0.42, 0.3, 0.02), m["dark"], Vector3(0, 0, 35))
	b.box(Vector3(0, DECK_Y + DOOR_H + 0.65, fz - 0.1), Vector3(1.2, 0.25, 0.1), Models.emissive(Color(0.3, 1.0, 0.45), 3.0))
	_gate_frame(root, b, fz, m, -1.0)
	_gate_frame(root, b, z1 + 0.02, m, 1.0)
	# Name boards inside (over the gate) and outside (facing the incoming tunnel).
	b.box(Vector3(0, 27.0, fz - 0.1), Vector3(17.0, 2.4, 0.2), m["dark"])
	_label(root, str(st.get("name", "WAYSTATION")), Vector3(0, 27.0, fz - 0.25), 170, 0.011, Color(1.0, 0.72, 0.3))
	_label(root, "SHOP  -  FUEL  -  SAFE HAVEN", Vector3(0, DECK_Y + DOOR_H + 1.15, fz - 0.15), 56, 0.006, Color(0.75, 0.9, 1.0))
	b.box(Vector3(0, 27.0, z1 + 0.12), Vector3(17.0, 2.4, 0.2), m["dark"])
	_label(root, str(st.get("name", "WAYSTATION")), Vector3(0, 27.0, z1 + 0.25), 170, 0.011, Color(1.0, 0.72, 0.3), 0.0)
	_label(root, "SAFE HAVEN  -  LAND TO CONTINUE", Vector3(0, 25.3, z1 + 0.25), 60, 0.009, Color(0.75, 0.9, 1.0), 0.0)
	# Light strips along the gate tunnel.
	for side: float in [-1.0, 1.0]:
		b.box(Vector3(side * (GATE_HALF_W - 0.04), GATE_Y0 + 0.6, (z0 + z1) * 0.5), Vector3(0.06, 0.2, z1 - z0 - 1.0), m["amber"])
		b.box(Vector3(side * (GATE_HALF_W - 0.04), GATE_Y1 - 0.6, (z0 + z1) * 0.5), Vector3(0.06, 0.2, z1 - z0 - 1.0), m["amber"])
	for i in 4:
		var z := z0 + 2.0 + i * 4.0
		b.box(Vector3(0, GATE_Y0 + 0.02, z), Vector3(GATE_HALF_W * 1.6, 0.04, 0.4), m["yellow"])
	# Floodlights over the pad, hung from the facade.
	for side: float in [-1.0, 1.0]:
		var housing := Vector3(side * 8.0, 25.0, fz - 1.2)
		b.box(housing, Vector3(1.6, 0.6, 1.0), m["dark"])
		b.box(housing + Vector3(0, -0.31, -0.2), Vector3(1.3, 0.04, 0.6), m["white"])
		var flood := SpotLight3D.new()
		var lamp := housing + Vector3(0, -0.4, -0.3)
		flood.transform = Transform3D(Basis.looking_at(Vector3(side * 2.0, 0.0, -4.0) - lamp, Vector3.UP), lamp)
		root.add_child(flood)
		flood.spot_range = 60.0
		flood.spot_angle = 50.0
		flood.spot_attenuation = 0.7
		flood.light_energy = 7.0
		flood.light_color = Color(1.0, 0.94, 0.85)
		ShipBuilder.configure_shadow(flood)


## The exit bulkhead: a wall across the hall with the gate into the next stretch of tunnel.
static func _build_exit_wall(root: Node3D, b: Models.Batch, m: Dictionary) -> void:
	var body := _body(root, Game.LAYER_CAVE)
	var z0 := EXIT_FACE
	var z1 := EXIT_INNER
	_block(b, body, Vector3(-WALL_X, WALL_Y0, z0), Vector3(WALL_X, GATE_Y0, z1), m["wall"])
	for side: float in [-1.0, 1.0]:
		_block(b, body, Vector3(minf(side * GATE_HALF_W, side * WALL_X), GATE_Y0, z0), Vector3(maxf(side * GATE_HALF_W, side * WALL_X), GATE_Y1, z1), m["wall"])
	_block(b, body, Vector3(-WALL_X, GATE_Y1, z0), Vector3(WALL_X, WALL_Y1, z1), m["wall"])
	var fz := z1 + 0.02
	for x: float in [-21.0, -12.0, 12.0, 21.0]:
		b.box(Vector3(x, (WALL_Y0 + GATE_Y1) * 0.5 + 2.0, fz + 0.2), Vector3(0.8, GATE_Y1 - WALL_Y0 + 4.0, 0.4), m["mid"])
	for i in 9:
		b.box(Vector3(-16.0 + i * 4.0, 4.0, fz + 0.05), Vector3(1.9, 4.0, 0.1), m["dark"] if i % 2 == 0 else m["mid"])
	_gate_frame(root, b, fz, m, 1.0)
	_gate_frame(root, b, z0 - 0.02, m, -1.0)
	b.box(Vector3(0, 27.0, fz + 0.1), Vector3(14.0, 2.4, 0.2), m["dark"])
	_label(root, "EXIT  -  NEXT SECTOR", Vector3(0, 27.0, fz + 0.25), 140, 0.011, Color(1.0, 0.72, 0.3), 0.0)
	_label(root, "LIFT OFF TO OPEN", Vector3(0, 6.2, fz + 0.15), 90, 0.012, Color(0.75, 0.9, 1.0), 0.0)


## Hazard stripes and lights around a gate aperture on a wall face at z (`facing` = the face's
## normal along z).
static func _gate_frame(root: Node3D, b: Models.Batch, z: float, m: Dictionary, facing: float) -> void:
	var zz := z + facing * 0.08
	for side: float in [-1.0, 1.0]:
		b.box(Vector3(side * (GATE_HALF_W + 0.5), (GATE_Y0 + GATE_Y1) * 0.5, zz), Vector3(1.0, GATE_Y1 - GATE_Y0 + 1.0, 0.14), m["black"])
		for i in 9:
			b.box(Vector3(side * (GATE_HALF_W + 0.5), GATE_Y0 + 0.9 + i * 1.8, zz + facing * 0.02), Vector3(1.05, 0.55, 0.14), m["yellow"], Vector3(0, 0, 40.0 * side))
		Models.sphere(root, Vector3(side * (GATE_HALF_W + 0.5), GATE_Y1 + 1.0, zz), 0.35, Models.blink(Color(1.0, 0.62, 0.12), 1.2, 0.5 if side > 0 else 0.0))
	b.box(Vector3(0, GATE_Y1 + 0.5, zz), Vector3(GATE_HALF_W * 2.0 + 2.0, 1.0, 0.14), m["black"])
	b.box(Vector3(0, GATE_Y0 - 0.5, zz), Vector3(GATE_HALF_W * 2.0 + 2.0, 1.0, 0.14), m["black"])
	for i in 15:
		var x := -GATE_HALF_W + 1.0 + i * 2.0
		b.box(Vector3(x, GATE_Y1 + 0.5, zz + facing * 0.02), Vector3(0.55, 1.05, 0.14), m["yellow"], Vector3(0, 0, 40.0))
		b.box(Vector3(x, GATE_Y0 - 0.5, zz + facing * 0.02), Vector3(0.55, 1.05, 0.14), m["yellow"], Vector3(0, 0, 40.0))
	var l := OmniLight3D.new()
	l.position = Vector3(0, GATE_Y1 + 2.0, z + facing * 3.0)
	l.omni_range = 24.0
	l.light_energy = 1.2
	l.light_color = Color(1.0, 0.7, 0.35)
	root.add_child(l)


## One bulkhead door: two panels that slide apart sideways, each with collision, and status lights
## on both faces of its bulkhead (at `faces`). Returns the handles the Waystation animates.
static func _build_door(root: Node3D, z: float, faces: Array, m: Dictionary, title: String) -> Dictionary:
	var panels: Array[Node3D] = []
	var plate := Models.panel_mat(Color(0.36, 0.38, 0.42), 0.6, 0.45, 0.25)
	var h := GATE_Y1 - GATE_Y0 + 0.4
	var w := GATE_HALF_W + 0.15
	for side: float in [-1.0, 1.0]:
		var p := Node3D.new()
		p.name = "%sDoor%s" % [title.capitalize(), "L" if side < 0 else "R"]
		p.position = Vector3(0, (GATE_Y0 + GATE_Y1) * 0.5, z)
		root.add_child(p)
		var cx := side * w * 0.5
		var b := Models.Batch.new()
		b.box(Vector3(cx, 0, 0), Vector3(w, h, 0.8), plate)
		for i in 5:
			var y := -h * 0.5 + 1.6 + i * (h - 3.2) / 4.0
			for f: float in [-1.0, 1.0]:
				b.box(Vector3(cx, y, f * 0.44), Vector3(w - 0.6, 0.35, 0.1), m["mid"])
		for f: float in [-1.0, 1.0]:
			for i in 3:
				b.box(Vector3(side * (2.0 + i * 4.4), 0, f * 0.45), Vector3(0.3, h - 0.8, 0.08), m["dark"])
			# Hazard chevrons along the meeting edge and a light strip.
			for i in 8:
				b.box(Vector3(side * 0.55, -h * 0.5 + 1.2 + i * 2.0, f * 0.46), Vector3(0.9, 0.5, 0.06), m["yellow"], Vector3(0, 0, -40.0 * side))
			b.box(Vector3(side * 1.25, 0, f * 0.47), Vector3(0.12, h - 1.0, 0.04), m["amber"])
		b.commit(p, "Panel")
		var body := StaticBody3D.new()
		body.collision_layer = Game.LAYER_CAVE
		body.collision_mask = 0
		p.add_child(body)
		_shape(body, Vector3(cx, 0, 0), Vector3(w, h, 0.8))
		panels.append(p)
	# Status lights either side of the gate (red closed, amber moving, green open).
	var lights: Array[StandardMaterial3D] = []
	for side: float in [-1.0, 1.0]:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.05, 0.05, 0.05)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.1, 0.05)
		mat.emission_energy_multiplier = 4.0
		for fz: float in faces:
			Models.box(root, Vector3(side * (GATE_HALF_W + 2.2), GATE_Y0 + 3.0, fz), Vector3(1.0, 1.0, 0.2), mat)
		lights.append(mat)
	var audio := AudioStreamPlayer3D.new()
	audio.stream = Sfx.stream("gate_loop")
	audio.position = Vector3(0, (GATE_Y0 + GATE_Y1) * 0.5, z)
	audio.unit_size = 30.0
	audio.max_distance = 220.0
	audio.volume_db = -2.0
	root.add_child(audio)
	return {"panels": panels, "lights": lights, "audio": audio, "pos": audio.position}


static func _build_pier(root: Node3D, b: Models.Batch, m: Dictionary) -> void:
	var body := _body(root, Game.LAYER_STATION)
	var z0 := PIER_START
	var z1 := FACADE_Z - FACADE_T * 0.5
	var length := z1 - z0
	var zc := (z0 + z1) * 0.5
	_solid(b, body, Vector3(0, DECK_Y - 0.15, zc), Vector3(PIER_HALF_W * 2.0, 0.3, length), m["floor"])
	for x: float in [-PIER_HALF_W + 0.15, PIER_HALF_W - 0.15]:
		b.box(Vector3(x, DECK_Y + 0.01, zc), Vector3(0.12, 0.02, length), m["yellow"])
	# Railings on both sides.
	for side: float in [-1.0, 1.0]:
		var x := side * (PIER_HALF_W - 0.05)
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(0.08, 1.2, length - 0.3)
		cs.shape = shape
		cs.position = Vector3(x, DECK_Y + 0.6, zc + 0.15)
		body.add_child(cs)
		Models.box(root, Vector3(x, DECK_Y + 0.6, zc + 0.15), Vector3(0.08, 1.2, length - 0.3), Models.glass(Color(0.6, 0.8, 1.0, 0.12)))
		b.box(Vector3(x, DECK_Y + 1.15, zc + 0.15), Vector3(0.12, 0.1, length - 0.3), m["yellow"])
		var n := 5
		for i in n:
			var pz := z0 + 0.3 + (length - 0.4) * float(i) / float(n - 1)
			b.box(Vector3(x, DECK_Y + 0.6, pz), Vector3(0.1, 1.2, 0.1), m["mid"])
	# Supports down to the hall floor.
	for x: float in [-1.4, 1.4]:
		b.box(Vector3(x, (DECK_Y - 0.3 + HALL_FLOOR - 1.0) * 0.5, zc + 0.6), Vector3(0.45, DECK_Y - 0.3 - HALL_FLOOR + 1.0, 0.45), m["mid"])


## The shop inside the entrance bulkhead: five pedestals for the stock, racks, a hologram table and
## the shop terminal.
static func _build_room(root: Node3D, b: Models.Batch, m: Dictionary) -> void:
	var body := _body(root, Game.LAYER_STATION | Game.LAYER_CAVE)
	var z0 := FACADE_Z + FACADE_T * 0.5
	var z1 := ROOM_END
	var zc := (z0 + z1) * 0.5
	var length := z1 - z0
	var hx := ROOM_HALF_X
	var ceil_y := DECK_Y + ROOM_H
	var wall_mat := Models.panel_mat(Color(0.62, 0.64, 0.66), 0.25, 0.55, 0.45)
	_solid(b, body, Vector3(0, DECK_Y - 0.15, zc), Vector3(hx * 2.0 + 0.5, 0.3, length), m["floor"])
	_solid(b, body, Vector3(0, ceil_y + 0.15, zc), Vector3(hx * 2.0 + 0.5, 0.3, length), Models.panel_mat(Color(0.3, 0.32, 0.35), 0.3, 0.6, 0.5))
	for side: float in [-1.0, 1.0]:
		_solid(b, body, Vector3(side * (hx + 0.125), DECK_Y + ROOM_H * 0.5, zc), Vector3(0.25, ROOM_H, length), wall_mat)
	_solid(b, body, Vector3(0, DECK_Y + ROOM_H * 0.5, z1 + 0.125), Vector3(hx * 2.0 + 0.5, ROOM_H, 0.25), wall_mat)
	# Inner face of the front wall: trim around the doorway.
	for side: float in [-1.0, 1.0]:
		b.box(Vector3(side * (DOOR_HALF_W + 0.15), DECK_Y + DOOR_H * 0.5, z0 + 0.03), Vector3(0.3, DOOR_H, 0.06), m["yellow"])
	# Floor guide lines from the door to the counter.
	for x: float in [-1.7, 1.7]:
		b.box(Vector3(x, DECK_Y + 0.01, (z0 + 29.0) * 0.5), Vector3(0.12, 0.02, 29.0 - z0 - 1.0), m["yellow"])
	# Storage racks along the side walls.
	for side: float in [-1.0, 1.0]:
		for zr: float in [23.6, 28.0]:
			var rack := Vector3(side * (hx - 0.5), DECK_Y, zr)
			_solid(b, body, rack + Vector3(0, 1.4, 0), Vector3(0.9, 0.08, 3.6), m["mid"])
			_solid(b, body, rack + Vector3(0, 2.6, 0), Vector3(0.9, 0.08, 3.6), m["mid"])
			for dz: float in [-1.75, 1.75]:
				b.box(rack + Vector3(0, 1.6, dz), Vector3(0.9, 3.2, 0.1), m["dark"])
			for i in 3:
				var c := Models.panel_mat(Color(0.3, 0.36, 0.3).lerp(Color(0.4, 0.33, 0.25), float(i) / 2.0), 0.2, 0.7, 1.0)
				b.box(rack + Vector3(0, 1.74, -1.1 + i * 1.1), Vector3(0.6, 0.6, 0.7), c, Vector3(0, i * 9.0, 0))
				b.box(rack + Vector3(0, 2.92, -1.0 + i * 1.0), Vector3(0.5, 0.55, 0.6), c, Vector3(0, -i * 7.0, 0))
	# Hologram table in the middle.
	var holo_c := Vector3(-5.2, DECK_Y, 22.6)
	_solid(b, body, holo_c + Vector3(0, 0.45, 0), Vector3(1.6, 0.9, 1.6), m["dark"])
	b.cyl(holo_c + Vector3(0, 0.93, 0), 0.6, 0.06, Models.emissive(Color(0.3, 0.8, 1.0), 0.6))
	if _holo_shader == null:
		_holo_shader = Shader.new()
		_holo_shader.code = HOLO_SHADER
	var holo := ShaderMaterial.new()
	holo.shader = _holo_shader
	holo.set_shader_parameter("strength", 0.55)
	var globe := MeshInstance3D.new()
	globe.mesh = Models.blob_mesh(7, 0.45, 0.3, 16)
	globe.material_override = holo
	globe.position = holo_c + Vector3(0, 2.95, 0)
	globe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(globe)
	var beam := Models.cylinder(root, holo_c + Vector3(0, 1.75, 0), 0.5, 1.6, holo, Vector3.ZERO, 0.06)
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Shop pedestals with glowing tops, and the counter terminal on the back wall.
	for sl: Array in SHOP_SLOTS:
		var p := Vector3(float(sl[0]), DECK_Y, float(sl[1]))
		_solid(b, body, p + Vector3(0, PEDESTAL_H * 0.5 - 0.05, 0), Vector3(1.3, PEDESTAL_H - 0.1, 1.0), m["dark"])
		b.box(p + Vector3(0, PEDESTAL_H - 0.05, 0), Vector3(1.4, 0.1, 1.1), Models.emissive(Color(0.3, 0.85, 1.0), 1.4, Color(0.05, 0.1, 0.12)))
		b.box(p + Vector3(0, 0.3, -0.51), Vector3(1.0, 0.2, 0.02), m["yellow"])
		var l := OmniLight3D.new()
		l.position = p + Vector3(0, 2.4, -0.4)
		l.omni_range = 3.2
		l.light_energy = 0.7
		l.light_color = Color(0.6, 0.85, 1.0)
		root.add_child(l)
	b.box(Vector3(0, DECK_Y + 3.1, z1 - 0.06), Vector3(4.2, 1.2, 0.06), Models.emissive(Color(0.25, 0.7, 0.95), 0.9, Color(0.02, 0.03, 0.04)))
	_label(root, "WAYSTATION SHOP\nPay with the credits you mined. Look at an item and press E to buy.", Vector3(0, DECK_Y + 3.1, z1 - 0.1), 34, 0.0052, Color(0.8, 0.95, 1.0))
	_label(root, "SHOP", Vector3(0, DECK_Y + DOOR_H + 0.4, z0 + 0.08), 64, 0.008, Color(1.0, 0.75, 0.35), 0.0)
	# Pipes and lights.
	var pipe := Models.mat(Color(0.5, 0.45, 0.4), 0.7, 0.4)
	for side: float in [-1.0, 1.0]:
		b.cyl(Vector3(side * (hx - 0.25), ceil_y - 0.3, zc), 0.1, length, pipe, Vector3(90, 0, 0))
	for zl: float in [23.0, 27.5, 32.0]:
		b.box(Vector3(0, ceil_y - 0.03, zl), Vector3(3.0, 0.05, 0.35), m["white"])
		var l := OmniLight3D.new()
		l.position = Vector3(0, ceil_y - 0.5, zl)
		l.omni_range = 11.0
		l.light_energy = 1.3
		l.light_color = Color(1.0, 0.94, 0.86)
		root.add_child(l)
	var holo_light := OmniLight3D.new()
	holo_light.position = holo_c + Vector3(0, 2.9, 0)
	holo_light.omni_range = 5.0
	holo_light.light_energy = 0.5
	holo_light.light_color = Color(0.4, 0.8, 1.0)
	root.add_child(holo_light)


## The hall around the pad: wall ribs, roof beams with lights, defence turrets and floor lights.
static func _build_hall(root: Node3D, b: Models.Batch, m: Dictionary) -> void:
	var rib := Models.panel_mat(Color(0.55, 0.57, 0.6), 0.55, 0.45, 0.4)
	for i in 4:
		var z := -19.0 + i * 11.0
		for side: float in [-1.0, 1.0]:
			b.box(Vector3(side * (HALL_HALF_X - 0.4), (HALL_FLOOR + HALL_ROOF) * 0.5, z), Vector3(1.0, HALL_ROOF - HALL_FLOOR + 2.0, 0.8), rib)
			b.box(Vector3(side * (HALL_HALF_X - 0.95), 4.0, z), Vector3(0.12, 0.6, 0.6), m["amber"])
			b.box(Vector3(side * (HALL_HALF_X - 0.95), 22.0, z), Vector3(0.12, 0.6, 0.6), m["amber"])
		b.box(Vector3(0, HALL_ROOF - 1.0, z), Vector3(HALL_HALF_X * 2.0, 1.2, 0.9), rib)
	# Light rigs hanging from the roof beams.
	for z: float in [-13.4, -5.8, 1.8, 9.4]:
		for x: float in [-9.0, 9.0]:
			b.box(Vector3(x, HALL_ROOF - 2.2, z), Vector3(3.6, 0.3, 0.8), m["dark"])
			b.box(Vector3(x, HALL_ROOF - 2.4, z), Vector3(3.2, 0.06, 0.5), m["white"])
	for p: Vector3 in [Vector3(0, 26.0, -8.0), Vector3(0, 26.0, 8.0), Vector3(-15.0, 18.0, 0.0), Vector3(15.0, 18.0, 0.0)]:
		var fill := OmniLight3D.new()
		fill.position = p
		fill.omni_range = 34.0
		fill.light_energy = 0.9
		fill.light_color = Color(1.0, 0.86, 0.68)
		root.add_child(fill)
	# Defence turrets.
	for g: Vector3 in GUARDS:
		var outside := g.z > ENTRY_FACE or g.z < EXIT_FACE
		var facing := 1.0 if g.z > ENTRY_FACE else (-1.0 if g.z < EXIT_FACE else (1.0 if g.z < 0.0 else -1.0))
		if outside:
			b.box(g + Vector3(0, 1.2, -facing * 0.6), Vector3(1.6, 1.6, 1.2), m["dark"])
		else:
			b.box(g + Vector3(0, 2.6, 0), Vector3(1.4, 3.6, 1.4), m["dark"])
		b.sphere(g + Vector3(0, 0.35, 0), 0.8, m["mid"])
		var aim := Vector3(-signf(g.x) * 0.25, -0.35, facing).normalized()
		for dx: float in [-0.22, 0.22]:
			var from := g + Vector3(dx, 0.3, 0)
			b.strut(from, from + aim * 2.2, 0.09, m["dark"])
		Models.sphere(root, g + Vector3(0, 0.35, 0) + aim * 0.8, 0.12, Models.emissive(Color(1.0, 0.25, 0.15), 5.0))
	# Guide lights on the hall floor either side of the pad.
	for i in 7:
		for x: float in [-17.5, 17.5]:
			b.box(Vector3(x, HALL_FLOOR + 0.2, -16.0 + i * 5.0), Vector3(0.4, 0.4, 0.4), m["amber"])
