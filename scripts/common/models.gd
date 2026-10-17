class_name Models
extends RefCounted
## Procedural meshes and materials for ships, aliens, minerals and props.

static var _mats: Dictionary = {}
static var _meshes: Dictionary = {}
static var _blink_shader: Shader

const BLINK_SHADER := """
shader_type spatial;
render_mode unshaded;
uniform vec4 color : source_color = vec4(1.0, 0.6, 0.1, 1.0);
uniform float rate = 1.5;
uniform float phase = 0.0;
uniform float duty = 0.5;
void fragment() {
	float on = step(1.0 - duty, fract(TIME * rate + phase));
	ALBEDO = color.rgb * (0.15 + on * 3.0);
}
"""


## Unshaded light that blinks on and off (beacons, strobes). `duty` is the fraction of time on.
static func blink(color: Color, rate: float, phase := 0.0, duty := 0.5) -> ShaderMaterial:
	var key := "b%s|%.2f|%.2f|%.2f" % [color.to_html(), rate, phase, duty]
	if _mats.has(key):
		return _mats[key]
	if _blink_shader == null:
		_blink_shader = Shader.new()
		_blink_shader.code = BLINK_SHADER
	var m := ShaderMaterial.new()
	m.shader = _blink_shader
	m.set_shader_parameter("color", color)
	m.set_shader_parameter("rate", rate)
	m.set_shader_parameter("phase", phase)
	m.set_shader_parameter("duty", duty)
	_mats[key] = m
	return m


static func mat(color: Color, metallic := 0.3, roughness := 0.6) -> StandardMaterial3D:
	var key := "m%s|%.2f|%.2f" % [color.to_html(), metallic, roughness]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.metallic = metallic
		m.roughness = roughness
		_mats[key] = m
	return _mats[key]


static func emissive(color: Color, energy := 2.0, albedo := Color(0.05, 0.05, 0.05)) -> StandardMaterial3D:
	var key := "e%s|%.2f|%s" % [color.to_html(), energy, albedo.to_html()]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = albedo
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = energy
		m.roughness = 0.4
		_mats[key] = m
	return _mats[key]


## Unshaded, optionally additive material for beams, tracers and glows. Not cached: callers
## often animate the colour.
static func glow(color: Color, additive := true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.disable_receive_shadows = true
	return m


static func glass(color: Color) -> StandardMaterial3D:
	var key := "g%s" % color.to_html()
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.metallic = 0.2
		m.roughness = 0.05
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mats[key] = m
	return _mats[key]


## Metal panel material with a procedural plate texture, mapped in object space.
static func panel_mat(color: Color, metallic := 0.4, roughness := 0.55, scale := 0.5) -> StandardMaterial3D:
	var key := "p%s|%.2f|%.2f|%.2f" % [color.to_html(), metallic, roughness, scale]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.albedo_texture = _panel_texture()
		m.metallic = metallic
		m.roughness = roughness
		m.uv1_triplanar = true
		m.uv1_scale = Vector3.ONE * scale
		_mats[key] = m
	return _mats[key]


static func _panel_texture() -> Texture2D:
	if _meshes.has("panel_tex"):
		return _meshes["panel_tex"]
	var size := 128
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	for y in size:
		for x in size:
			var v := 0.92 + rng.randf_range(-0.03, 0.03)
			if x % 64 < 2 or y % 64 < 2:
				v = 0.62
			elif x % 64 == 2 or y % 64 == 2:
				v = 1.0
			if (x % 64 > 56 and y % 64 > 56) and (x % 64 - 58) * (x % 64 - 58) + (y % 64 - 58) * (y % 64 - 58) < 4:
				v = 0.7
			img.set_pixel(x, y, Color(v, v, v))
	var tex := ImageTexture.create_from_image(img)
	_meshes["panel_tex"] = tex
	return tex


# --- Primitive helpers -------------------------------------------------------------------------

static func box(parent: Node3D, pos: Vector3, size: Vector3, material: Material, rot_deg := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = material
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi


static func cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, material: Material,
		rot_deg := Vector3.ZERO, top_radius := -1.0, sides := 16) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.bottom_radius = radius
	cm.top_radius = radius if top_radius < 0.0 else top_radius
	cm.height = height
	cm.radial_segments = sides
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = material
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi


static func sphere(parent: Node3D, pos: Vector3, radius: float, material: Material,
		scale := Vector3.ONE, segments := 16) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	sm.radial_segments = segments
	sm.rings = maxi(segments / 2, 4)
	mi.mesh = sm
	mi.material_override = material
	mi.position = pos
	mi.scale = scale
	parent.add_child(mi)
	return mi


static func capsule(parent: Node3D, pos: Vector3, radius: float, height: float, material: Material,
		rot_deg := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = radius
	cm.height = maxf(height, radius * 2.0)
	cm.radial_segments = 12
	cm.rings = 4
	mi.mesh = cm
	mi.material_override = material
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi


## A thin limb between two points (used for alien legs and pipes).
static func strut(parent: Node3D, a: Vector3, b: Vector3, radius: float, material: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.bottom_radius = radius
	cm.top_radius = radius * 0.7
	cm.height = 1.0
	cm.radial_segments = 6
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = material
	parent.add_child(mi)
	place_strut(mi, a, b)
	return mi


static func place_strut(mi: Node3D, a: Vector3, b: Vector3) -> void:
	if a.distance_squared_to(b) > 1e-6:
		mi.transform = strut_transform(a, b)


## Transform that stretches a unit-height Y-axis mesh from a to b.
static func strut_transform(a: Vector3, b: Vector3) -> Transform3D:
	var d := b - a
	var length := maxf(d.length(), 0.001)
	var y := d / length
	var x := y.cross(Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.95 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	return Transform3D(Basis(x, y * length, z), (a + b) * 0.5)


# --- Procedural meshes -------------------------------------------------------------------------

## Hull lofted through octagonal cross-sections given as [z, half_width, half_height, y_center].
## `cap_end` false leaves the last section open (for a custom end cap).
static func loft(sections: Array, chamfer := 0.3, cap_end := true) -> ArrayMesh:
	var rings: Array[PackedVector3Array] = []
	for s in sections:
		rings.append(octagon(s, chamfer))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in rings.size() - 1:
		var a := rings[r]
		var b := rings[r + 1]
		var axis := (_centroid(a) + _centroid(b)) * 0.5
		for i in 8:
			var j := (i + 1) % 8
			tri(st, a[i], a[j], b[j], axis)
			tri(st, a[i], b[j], b[i], axis)
	_cap(st, rings[0], Vector3(0, 0, 1))
	if cap_end:
		_cap(st, rings[rings.size() - 1], Vector3(0, 0, -1))
	return st.commit()


## The octagonal ring of one loft section [z, half_width, half_height, y_center].
static func octagon(section: Array, chamfer := 0.3) -> PackedVector3Array:
	var z: float = section[0]
	var w: float = section[1]
	var h: float = section[2]
	var yc: float = section[3]
	var c := 1.0 - chamfer
	var ring := PackedVector3Array([
		Vector3(w, h * c, z), Vector3(w * c, h, z), Vector3(-w * c, h, z), Vector3(-w, h * c, z),
		Vector3(-w, -h * c, z), Vector3(-w * c, -h, z), Vector3(w * c, -h, z), Vector3(w, -h * c, z)])
	for i in ring.size():
		ring[i].y += yc
	return ring


static func _centroid(ring: PackedVector3Array) -> Vector3:
	var c := Vector3.ZERO
	for p in ring:
		c += p
	return c / ring.size()


static func _cap(st: SurfaceTool, ring: PackedVector3Array, inward: Vector3) -> void:
	var c := _centroid(ring)
	for i in ring.size():
		tri(st, c, ring[i], ring[(i + 1) % ring.size()], c + inward)


## Add a flat-shaded triangle whose front face points away from `inside`.
static func tri(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, inside: Vector3) -> void:
	var n := (p1 - p0).cross(p2 - p0)
	if n.length_squared() < 1e-12:
		return
	n = n.normalized()
	var outward := (p0 + p1 + p2) / 3.0 - inside
	# Godot treats clockwise triangles as front faces, so the right-handed normal must point inward.
	if n.dot(outward) > 0.0:
		var t := p1
		p1 = p2
		p2 = t
		n = -n
	st.set_normal(-n)
	st.add_vertex(p0)
	st.add_vertex(p1)
	st.add_vertex(p2)


## A flat-shaded slab: the polygon `poly` (x, z) extruded from y0 to y1.
static func prism(poly: PackedVector2Array, y0: float, y1: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var mid := Vector3(0, (y0 + y1) * 0.5, 0)
	var c := Vector2.ZERO
	for p in poly:
		c += p
	c /= poly.size()
	mid.x = c.x
	mid.z = c.y
	var idx := Geometry2D.triangulate_polygon(poly)
	for i in range(0, idx.size(), 3):
		var a := poly[idx[i]]
		var b := poly[idx[i + 1]]
		var d := poly[idx[i + 2]]
		tri(st, Vector3(a.x, y1, a.y), Vector3(b.x, y1, b.y), Vector3(d.x, y1, d.y), mid)
		tri(st, Vector3(a.x, y0, a.y), Vector3(b.x, y0, b.y), Vector3(d.x, y0, d.y), mid)
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		tri(st, Vector3(a.x, y0, a.y), Vector3(b.x, y0, b.y), Vector3(b.x, y1, b.y), mid)
		tri(st, Vector3(a.x, y0, a.y), Vector3(b.x, y1, b.y), Vector3(a.x, y1, a.y), mid)
	return st.commit()


## Collects static primitives and merges them into one mesh per material, so detailed models
## cost a handful of draw calls instead of hundreds. Call commit() once everything is added.
class Batch extends RefCounted:
	var _tools: Dictionary = {}

	func _tool(m: Material) -> SurfaceTool:
		if not _tools.has(m):
			_tools[m] = SurfaceTool.new()
		return _tools[m]

	func add(mesh: Mesh, xform: Transform3D, m: Material) -> void:
		_tool(m).append_from(_indexed(mesh), 0, xform)

	## SurfaceTool.append_from() only carries over index lists: once a batch holds an indexed mesh
	## (every primitive mesh is), the triangles of meshes built without one (loft(), prism(), any
	## SurfaceTool mesh) would be dropped without a word. Such meshes are indexed first.
	static func _indexed(mesh: Mesh) -> Mesh:
		var am := mesh as ArrayMesh
		if am == null or am.surface_get_array_index_len(0) > 0:
			return mesh
		var st := SurfaceTool.new()
		st.create_from(am, 0)
		st.index()
		return st.commit()

	func box(pos: Vector3, size: Vector3, m: Material, rot_deg := Vector3.ZERO) -> void:
		var bm := BoxMesh.new()
		bm.size = size
		add(bm, Transform3D(Models.euler(rot_deg), pos), m)

	func cyl(pos: Vector3, radius: float, height: float, m: Material, rot_deg := Vector3.ZERO,
			top_radius := -1.0, sides := 16) -> void:
		var cm := CylinderMesh.new()
		cm.bottom_radius = radius
		cm.top_radius = radius if top_radius < 0.0 else top_radius
		cm.height = height
		cm.radial_segments = sides
		cm.rings = 1
		add(cm, Transform3D(Models.euler(rot_deg), pos), m)

	func sphere(pos: Vector3, radius: float, m: Material, scale := Vector3.ONE, segments := 12) -> void:
		var sm := SphereMesh.new()
		sm.radius = radius
		sm.height = radius * 2.0
		sm.radial_segments = segments
		sm.rings = maxi(segments / 2, 4)
		add(sm, Transform3D(Basis.from_scale(scale), pos), m)

	func strut(a: Vector3, b: Vector3, radius: float, m: Material, sides := 6) -> void:
		var cm := CylinderMesh.new()
		cm.bottom_radius = radius
		cm.top_radius = radius
		cm.height = 1.0
		cm.radial_segments = sides
		cm.rings = 1
		add(cm, Models.strut_transform(a, b), m)

	## A box from a to b that stays upright: `width` across, `height` up.
	func beam(a: Vector3, b: Vector3, width: float, height: float, m: Material) -> void:
		var d := b - a
		var bm := BoxMesh.new()
		bm.size = Vector3(width, height, d.length())
		var up := Vector3.UP if absf(d.normalized().y) < 0.95 else Vector3.FORWARD
		add(bm, Transform3D(Basis.looking_at(d, up), (a + b) * 0.5), m)

	func commit(parent: Node3D, node_name := "Detail", shadows := true) -> Array[MeshInstance3D]:
		var out: Array[MeshInstance3D] = []
		var i := 0
		for m: Material in _tools:
			var mi := MeshInstance3D.new()
			mi.name = "%s%d" % [node_name, i]
			mi.mesh = (_tools[m] as SurfaceTool).commit()
			mi.material_override = m
			if not shadows:
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			parent.add_child(mi)
			out.append(mi)
			i += 1
		_tools.clear()
		return out


static func euler(rot_deg: Vector3) -> Basis:
	return Basis.from_euler(Vector3(deg_to_rad(rot_deg.x), deg_to_rad(rot_deg.y), deg_to_rad(rot_deg.z)))


## Unit crystal: hexagonal prism with a pointed tip, 1 m tall. Scale per instance.
static func crystal_mesh() -> ArrayMesh:
	if _meshes.has("crystal"):
		return _meshes["crystal"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides := 6
	var r := 0.22
	var shoulder := 0.72
	var tip := Vector3(0, 1.0, 0)
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var b0 := Vector3(cos(a0) * r, -0.15, sin(a0) * r)
		var b1 := Vector3(cos(a1) * r, -0.15, sin(a1) * r)
		var t0 := Vector3(cos(a0) * r * 0.9, shoulder, sin(a0) * r * 0.9)
		var t1 := Vector3(cos(a1) * r * 0.9, shoulder, sin(a1) * r * 0.9)
		var axis := Vector3(0, (shoulder - 0.15) * 0.5, 0)
		tri(st, b0, b1, t1, axis)
		tri(st, b0, t1, t0, axis)
		tri(st, t0, t1, tip, Vector3(0, shoulder * 0.8, 0))
	var mesh := st.commit()
	_meshes["crystal"] = mesh
	return mesh


## Lumpy rock/organic blob built from a displaced sphere.
static func blob_mesh(seed_value: int, radius: float, roughness := 0.25, segments := 14) -> ArrayMesh:
	var key := "blob%d|%.2f|%.2f|%d" % [seed_value, radius, roughness, segments]
	if _meshes.has(key):
		return _meshes[key]
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 1.4 / maxf(radius, 0.1)
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	sm.radial_segments = segments
	sm.rings = segments / 2
	var arrays := sm.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in verts.size():
		var v := verts[i]
		var d := 1.0 + noise.get_noise_3dv(v) * roughness
		verts[i] = v * d
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = null
	arrays[Mesh.ARRAY_TANGENT] = null
	var tmp := ArrayMesh.new()
	tmp.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var st := SurfaceTool.new()
	st.create_from(tmp, 0)
	st.generate_normals()
	var mesh := st.commit()
	_meshes[key] = mesh
	return mesh
