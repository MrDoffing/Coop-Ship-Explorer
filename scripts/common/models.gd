class_name Models
extends RefCounted
## Procedural meshes and materials for ships, aliens, minerals and props.

static var _mats: Dictionary = {}
static var _meshes: Dictionary = {}


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
