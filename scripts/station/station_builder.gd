class_name StationBuilder
extends RefCounted
## Builds a waystation: a landing pad in a hangar cut into the cave wall, a pier from the ship's
## cargo ramp to the station's front wall, and the supply room behind it.
##
## Station-local frame (see CaveGen.station): x along the tunnel, y up, z into the wall, origin on
## top of the landing pad. A landed mothership sits at (0, LAND_HEIGHT, 0) with its nose pointing
## out of the hangar (-z), so the cargo ramp at its stern comes down onto the pier.

## Height of the ship's origin above the pad when its landing legs are down. The ship's deck is
## then 1 m above the pier, which the open ramp bridges.
const LAND_HEIGHT := 4.2
## The ship turns around this much higher above the pad before settling.
const HOVER := 3.0
## Rock carved out for the hangar (z runs from the tunnel centre line to HANGAR_BACK).
const HANGAR_HALF_X := 21.0
const HANGAR_FLOOR := -1.5
const HANGAR_ROOF := 16.0
const HANGAR_BACK := 23.0
const HANGAR_ROUND := 3.0
## Rock carved out around the station building.
const CARVE_MIN := Vector3(-12.0, 0.0, 19.0)
const CARVE_MAX := Vector3(12.0, 10.5, 39.0)
## Walkway height (pier and station floor).
const DECK_Y := 3.2
const PIER_START := 14.6
const PIER_HALF_W := 1.9
const FACADE_Z := 20.0
const FACADE_T := 0.6
const DOOR_HALF_W := 1.6
const DOOR_H := 3.2
const ROOM_HALF_X := 9.0
const ROOM_END := 36.0
const ROOM_H := 4.0
## Floor spots for supply crates: [x, z, yaw].
const CRATE_SLOTS := [
	[-6.6, 23.0, 0.3], [6.4, 22.9, -0.2], [-7.0, 27.6, 1.4], [7.1, 28.2, 1.6], [-4.3, 31.6, 0.1],
	[4.5, 32.0, -0.4], [-6.8, 34.6, 0.0], [6.6, 34.6, 0.2], [0.0, 34.8, 0.05], [-3.0, 25.4, -0.3],
]
## Defence turrets under the hangar roof (station-local muzzle positions).
const GUARDS := [Vector3(-17.0, 12.6, -6.0), Vector3(17.0, 12.6, -6.0)]
## Aliens closer than SAFE_RADIUS to SAFE_CENTER are shot down by the station's defences.
const SAFE_CENTER := Vector3(0.0, 7.0, -6.0)
const SAFE_RADIUS := 65.0

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

static var _blink_shader: Shader
static var _holo_shader: Shader

const BLINK_SHADER := """
shader_type spatial;
render_mode unshaded;
uniform vec4 color : source_color = vec4(1.0, 0.6, 0.1, 1.0);
uniform float rate = 1.5;
uniform float phase = 0.0;
void fragment() {
	float on = step(0.5, fract(TIME * rate + phase));
	ALBEDO = color.rgb * (0.15 + on * 3.0);
}
"""


## Build the station's visuals and collision under `parent`. The returned node sits at the
## station's transform (`parent` must be at the world origin).
static func build(parent: Node3D, st: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "Waystation%d" % int(st["k"])
	root.transform = st["xform"]
	parent.add_child(root)
	var hull := Models.panel_mat(Color(0.5, 0.52, 0.56), 0.4, 0.55, 0.35)
	var dark := Models.mat(Color(0.12, 0.13, 0.15), 0.5, 0.6)
	var mid := Models.mat(Color(0.3, 0.32, 0.36), 0.6, 0.45)
	var floor_mat := Models.panel_mat(Color(0.24, 0.26, 0.29), 0.5, 0.6, 0.5)
	var yellow := Models.mat(Color(0.95, 0.72, 0.12), 0.3, 0.5)
	var accent := Models.mat(Color(0.95, 0.5, 0.12), 0.3, 0.5)
	var amber := Models.emissive(Color(1.0, 0.6, 0.15), 3.0)
	var white := Models.emissive(Color(1.0, 0.95, 0.85), 2.5)
	_build_pad(root, floor_mat, dark, yellow, amber)
	_build_facade(root, st, hull, dark, mid, yellow, accent, white)
	_build_pier(root, floor_mat, mid, yellow)
	_build_room(root, floor_mat, hull, dark, mid, yellow, white)
	_build_hangar_fittings(root, dark, mid, amber)
	return root


static func _body(root: Node3D, layers: int) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = layers
	body.collision_mask = 0
	root.add_child(body)
	return body


static func _solid(root: Node3D, body: StaticBody3D, pos: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mi := Models.box(root, pos, size, material)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.position = pos
	body.add_child(cs)
	return mi


static func _blink(color: Color, rate: float, phase: float) -> ShaderMaterial:
	if _blink_shader == null:
		_blink_shader = Shader.new()
		_blink_shader.code = BLINK_SHADER
	var m := ShaderMaterial.new()
	m.shader = _blink_shader
	m.set_shader_parameter("color", color)
	m.set_shader_parameter("rate", rate)
	m.set_shader_parameter("phase", phase)
	return m


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

static func _build_pad(root: Node3D, floor_mat: Material, dark: Material, yellow: Material, amber: Material) -> void:
	var body := _body(root, Game.LAYER_CAVE)
	_solid(root, body, Vector3(0, -0.6, -1.5), Vector3(26.0, 1.2, 30.0), floor_mat)
	# Plinth sinking into the rock floor.
	Models.box(root, Vector3(0, -2.6, -1.5), Vector3(25.0, 2.8, 29.0), dark)
	# Touchdown ring and markings.
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 6.9
	torus.outer_radius = 7.5
	torus.rings = 48
	torus.ring_segments = 6
	ring.mesh = torus
	ring.material_override = yellow
	ring.position = Vector3(0, 0.0, 0)
	ring.scale = Vector3(1.0, 0.08, 1.0)
	root.add_child(ring)
	for x: float in [-1.6, 1.6]:
		Models.box(root, Vector3(x, 0.015, 0), Vector3(0.5, 0.03, 5.0), yellow)
	Models.box(root, Vector3(0, 0.015, 0), Vector3(2.7, 0.03, 0.5), yellow)
	# Hazard stripes along the front edge and lights around the rim.
	for i in 12:
		Models.box(root, Vector3(-11.0 + i * 2.0, 0.015, -15.9), Vector3(0.9, 0.03, 0.9), yellow, Vector3(0, 45, 0))
	for z: float in [-16.2, -12.0, -8.0, -4.0, 0.0, 4.0, 8.0, 12.2]:
		for x: float in [-12.7, 12.7]:
			Models.box(root, Vector3(x, 0.06, z), Vector3(0.3, 0.12, 0.3), amber)
	for x: float in [-8.0, -4.0, 4.0, 8.0]:
		Models.box(root, Vector3(x, 0.06, -16.2), Vector3(0.3, 0.12, 0.3), amber)
	# Fuel and power couplings at the back of the pad.
	for x: float in [-9.5, 9.5]:
		Models.box(root, Vector3(x, 0.6, 11.8), Vector3(1.6, 1.2, 1.2), dark)
		Models.cylinder(root, Vector3(x, 1.25, 11.8), 0.25, 0.3, Models.mat(Color(0.9, 0.2, 0.15), 0.3, 0.5))
		Models.strut(root, Vector3(x, 1.0, 11.2), Vector3(x * 0.62, 0.15, 8.0), 0.09, Models.mat(Color(0.15, 0.15, 0.17), 0.2, 0.8))


static func _build_facade(root: Node3D, st: Dictionary, hull: Material, dark: Material, mid: Material,
		yellow: Material, accent: Material, white: Material) -> void:
	var body := _body(root, Game.LAYER_CAVE | Game.LAYER_STATION)
	var z := FACADE_Z
	var t := FACADE_T
	var top := HANGAR_ROOF + 2.0
	var bottom := HANGAR_FLOOR - 1.5
	var wide := HANGAR_HALF_X + 2.0
	var door_top := DECK_Y + DOOR_H
	# Wall with a doorway at the end of the pier.
	var side_w := wide - DOOR_HALF_W
	for side: float in [-1.0, 1.0]:
		_solid(root, body, Vector3(side * (DOOR_HALF_W + side_w * 0.5), (top + bottom) * 0.5, z), Vector3(side_w, top - bottom, t), hull)
	_solid(root, body, Vector3(0, (door_top + top) * 0.5, z), Vector3(DOOR_HALF_W * 2.0, top - door_top, t), hull)
	_solid(root, body, Vector3(0, (DECK_Y + bottom) * 0.5, z), Vector3(DOOR_HALF_W * 2.0, DECK_Y - bottom, t), hull)
	# Ribs, a walkway ledge and the control room windows.
	for x: float in [-18.0, -12.0, -6.0, 6.0, 12.0, 18.0]:
		Models.box(root, Vector3(x, (top + bottom) * 0.5, z - t * 0.5 - 0.2), Vector3(0.7, top - bottom, 0.4), mid)
	Models.box(root, Vector3(0, 10.5, z - t * 0.5 - 0.6), Vector3(wide * 2.0, 0.3, 1.2), dark)
	var glass := Models.emissive(Color(0.45, 0.75, 1.0), 1.4, Color(0.03, 0.06, 0.09))
	for side: float in [-1.0, 1.0]:
		Models.box(root, Vector3(side * 9.0, 12.2, z - t * 0.5 - 0.02), Vector3(9.0, 2.0, 0.05), glass)
		Models.box(root, Vector3(side * 9.0, 7.6, z - t * 0.5 - 0.02), Vector3(5.0, 1.2, 0.05), glass)
	# Door frame with hazard stripes and a green "open" light.
	Models.box(root, Vector3(0, door_top + 0.2, z - t * 0.5 - 0.06), Vector3(DOOR_HALF_W * 2.0 + 0.8, 0.4, 0.12), accent)
	for side: float in [-1.0, 1.0]:
		Models.box(root, Vector3(side * (DOOR_HALF_W + 0.2), DECK_Y + DOOR_H * 0.5, z - t * 0.5 - 0.06), Vector3(0.4, DOOR_H, 0.12), accent)
		for i in 4:
			Models.box(root, Vector3(side * (DOOR_HALF_W + 0.2), DECK_Y + 0.4 + i * 0.8, z - t * 0.5 - 0.13),
					Vector3(0.42, 0.3, 0.02), dark, Vector3(0, 0, 35))
	Models.box(root, Vector3(0, door_top + 0.65, z - t * 0.5 - 0.1), Vector3(1.2, 0.25, 0.1), Models.emissive(Color(0.3, 1.0, 0.45), 3.0))
	# Name board.
	Models.box(root, Vector3(0, 15.0, z - t * 0.5 - 0.1), Vector3(17.0, 2.4, 0.2), dark)
	_label(root, str(st.get("name", "WAYSTATION")), Vector3(0, 15.0, z - t * 0.5 - 0.25), 170, 0.011, Color(1.0, 0.72, 0.3))
	_label(root, "SAFE HAVEN  -  FUEL  -  SUPPLIES", Vector3(0, door_top + 1.35, z - t * 0.5 - 0.15), 64, 0.006, Color(0.75, 0.9, 1.0))
	# Floodlights over the pad.
	for side: float in [-1.0, 1.0]:
		var housing := Vector3(side * 8.0, 14.2, z - 1.2)
		Models.box(root, housing, Vector3(1.6, 0.6, 1.0), dark)
		Models.box(root, housing + Vector3(0, -0.31, -0.2), Vector3(1.3, 0.04, 0.6), white)
		var flood := SpotLight3D.new()
		var lamp := housing + Vector3(0, -0.4, -0.3)
		flood.transform = Transform3D(Basis.looking_at(Vector3(side * 2.0, 0.0, -2.0) - lamp, Vector3.UP), lamp)
		root.add_child(flood)
		flood.spot_range = 48.0
		flood.spot_angle = 52.0
		flood.spot_attenuation = 0.7
		flood.light_energy = 6.0
		flood.light_color = Color(1.0, 0.94, 0.85)
		ShipBuilder.configure_shadow(flood)
	# Warm work light that fills the whole hangar.
	var fill := OmniLight3D.new()
	fill.position = Vector3(0, 13.0, 2.0)
	fill.omni_range = 34.0
	fill.light_energy = 1.1
	fill.light_color = Color(1.0, 0.85, 0.65)
	root.add_child(fill)


static func _build_pier(root: Node3D, floor_mat: Material, mid: Material, yellow: Material) -> void:
	var body := _body(root, Game.LAYER_STATION)
	var z0 := PIER_START
	var z1 := FACADE_Z - FACADE_T * 0.5
	var length := z1 - z0
	var zc := (z0 + z1) * 0.5
	_solid(root, body, Vector3(0, DECK_Y - 0.15, zc), Vector3(PIER_HALF_W * 2.0, 0.3, length), floor_mat)
	for x: float in [-PIER_HALF_W + 0.15, PIER_HALF_W - 0.15]:
		Models.box(root, Vector3(x, DECK_Y + 0.01, zc), Vector3(0.12, 0.02, length), yellow)
	# Railings on both sides.
	for side: float in [-1.0, 1.0]:
		var x := side * (PIER_HALF_W - 0.05)
		_solid(root, body, Vector3(x, DECK_Y + 0.6, zc + 0.15), Vector3(0.08, 1.2, length - 0.3), Models.glass(Color(0.6, 0.8, 1.0, 0.12)))
		Models.box(root, Vector3(x, DECK_Y + 1.15, zc + 0.15), Vector3(0.12, 0.1, length - 0.3), yellow)
		var n := 5
		for i in n:
			var pz := z0 + 0.3 + (length - 0.4) * float(i) / float(n - 1)
			Models.box(root, Vector3(x, DECK_Y + 0.6, pz), Vector3(0.1, 1.2, 0.1), mid)
	# Supports down to the hangar floor.
	for x: float in [-1.4, 1.4]:
		Models.box(root, Vector3(x, (DECK_Y - 0.3 + HANGAR_FLOOR - 1.0) * 0.5, zc + 0.6), Vector3(0.45, DECK_Y - 0.3 - HANGAR_FLOOR + 1.0, 0.45), mid)


static func _build_room(root: Node3D, floor_mat: Material, hull: Material, dark: Material, mid: Material,
		yellow: Material, white: Material) -> void:
	var body := _body(root, Game.LAYER_STATION | Game.LAYER_CAVE)
	var z0 := FACADE_Z + FACADE_T * 0.5
	var z1 := ROOM_END
	var zc := (z0 + z1) * 0.5
	var length := z1 - z0
	var hx := ROOM_HALF_X
	var ceil_y := DECK_Y + ROOM_H
	var wall_mat := Models.panel_mat(Color(0.62, 0.64, 0.66), 0.25, 0.55, 0.45)
	_solid(root, body, Vector3(0, DECK_Y - 0.15, zc), Vector3(hx * 2.0 + 0.5, 0.3, length), floor_mat)
	_solid(root, body, Vector3(0, ceil_y + 0.15, zc), Vector3(hx * 2.0 + 0.5, 0.3, length), Models.panel_mat(Color(0.3, 0.32, 0.35), 0.3, 0.6, 0.5))
	for side: float in [-1.0, 1.0]:
		_solid(root, body, Vector3(side * (hx + 0.125), DECK_Y + ROOM_H * 0.5, zc), Vector3(0.25, ROOM_H, length), wall_mat)
	_solid(root, body, Vector3(0, DECK_Y + ROOM_H * 0.5, z1 + 0.125), Vector3(hx * 2.0 + 0.5, ROOM_H, 0.25), wall_mat)
	# Inner face of the front wall (the facade is thick, so just trim around the doorway).
	for side: float in [-1.0, 1.0]:
		Models.box(root, Vector3(side * (DOOR_HALF_W + 0.15), DECK_Y + DOOR_H * 0.5, z0 + 0.03), Vector3(0.3, DOOR_H, 0.06), yellow)
	# Floor guide lines from the door.
	for x: float in [-1.7, 1.7]:
		Models.box(root, Vector3(x, DECK_Y + 0.01, zc), Vector3(0.12, 0.02, length - 1.0), yellow)
	# Storage racks along the side walls.
	for side: float in [-1.0, 1.0]:
		for zr: float in [25.0, 30.5]:
			var rack := Vector3(side * (hx - 0.5), DECK_Y, zr)
			_solid(root, body, rack + Vector3(0, 1.4, 0), Vector3(0.9, 0.08, 3.8), mid)
			_solid(root, body, rack + Vector3(0, 2.6, 0), Vector3(0.9, 0.08, 3.8), mid)
			for dz: float in [-1.85, 1.85]:
				Models.box(root, rack + Vector3(0, 1.6, dz), Vector3(0.9, 3.2, 0.1), dark)
			for i in 3:
				var c := Models.panel_mat(Color(0.3, 0.36, 0.3).lerp(Color(0.4, 0.33, 0.25), float(i) / 2.0), 0.2, 0.7, 1.0)
				Models.box(root, rack + Vector3(0, 1.74, -1.1 + i * 1.1), Vector3(0.6, 0.6, 0.7), c, Vector3(0, i * 9.0, 0))
				Models.box(root, rack + Vector3(0, 2.92, -1.0 + i * 1.0), Vector3(0.5, 0.55, 0.6), c, Vector3(0, -i * 7.0, 0))
	# Hologram table in the middle.
	var holo_c := Vector3(0, DECK_Y, 28.6)
	_solid(root, body, holo_c + Vector3(0, 0.45, 0), Vector3(1.6, 0.9, 1.6), dark)
	Models.cylinder(root, holo_c + Vector3(0, 0.93, 0), 0.6, 0.06, Models.emissive(Color(0.3, 0.8, 1.0), 0.6))
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
	# Terminal on the back wall.
	_solid(root, body, Vector3(0, DECK_Y + 0.5, z1 - 0.45), Vector3(2.4, 1.0, 0.7), dark)
	Models.box(root, Vector3(0, DECK_Y + 1.7, z1 - 0.06), Vector3(2.8, 1.4, 0.06), Models.emissive(Color(0.25, 0.7, 0.95), 0.9, Color(0.02, 0.03, 0.04)))
	_label(root, "SUPPLY DEPOT\nTake what you need. Safe travels.", Vector3(0, DECK_Y + 1.7, z1 - 0.1), 40, 0.0055, Color(0.8, 0.95, 1.0))
	_label(root, "SUPPLY DEPOT", Vector3(0, DECK_Y + DOOR_H + 0.4, z0 + 0.08), 52, 0.007, Color(1.0, 0.75, 0.35), 0.0)
	# Pipes and lights.
	var pipe := Models.mat(Color(0.5, 0.45, 0.4), 0.7, 0.4)
	for side: float in [-1.0, 1.0]:
		Models.cylinder(root, Vector3(side * (hx - 0.25), ceil_y - 0.3, zc), 0.1, length, pipe, Vector3(90, 0, 0))
	for zl: float in [23.5, 28.6, 33.5]:
		Models.box(root, Vector3(0, ceil_y - 0.03, zl), Vector3(3.0, 0.05, 0.35), white)
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


static func _build_hangar_fittings(root: Node3D, dark: Material, mid: Material, amber: Material) -> void:
	# Defence turrets hanging from the roof near the mouth.
	for g: Vector3 in GUARDS:
		Models.box(root, g + Vector3(0, 2.6, 0), Vector3(1.4, 3.6, 1.4), dark)
		Models.sphere(root, g + Vector3(0, 0.35, 0), 0.8, mid)
		var aim := Vector3(-signf(g.x) * 0.25, -0.25, -1.0).normalized()
		for dx: float in [-0.22, 0.22]:
			var from := g + Vector3(dx, 0.3, 0)
			Models.strut(root, from, from + aim * 2.2, 0.09, dark)
		Models.sphere(root, g + Vector3(0, 0.35, 0) + aim * 0.8, 0.12, Models.emissive(Color(1.0, 0.25, 0.15), 5.0))
	# Blinking beacons on the side walls at the mouth, so the crew can spot the station.
	for i in 4:
		var side := -1.0 if i % 2 == 0 else 1.0
		var pos := Vector3(side * (HANGAR_HALF_X - 0.9), 12.5 if i < 2 else 1.5, -11.0)
		Models.box(root, pos + Vector3(side * 0.9, 0, 0), Vector3(1.4, 0.7, 0.7), dark)
		Models.sphere(root, pos, 0.32, _blink(Color(1.0, 0.62, 0.12), 1.2, i * 0.25))
		var l := OmniLight3D.new()
		l.position = pos + Vector3(-side * 0.8, 0, 0)
		l.omni_range = 22.0
		l.light_energy = 1.4
		l.light_color = Color(1.0, 0.65, 0.25)
		root.add_child(l)
	# Guide lights on the hangar floor either side of the pad.
	for i in 6:
		for x: float in [-16.5, 16.5]:
			Models.box(root, Vector3(x, HANGAR_FLOOR + 0.2, -11.0 + i * 4.0), Vector3(0.4, 0.4, 0.4), amber)
	# Struts under the front lip of the pad, braced into the rock.
	for x: float in [-9.0, 0.0, 9.0]:
		Models.strut(root, Vector3(x, -1.0, -15.5), Vector3(x, -6.0, -9.0), 0.4, mid)
