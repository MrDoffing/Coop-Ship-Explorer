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


## The motherships' hull plating: painted plates of uneven widths with seams and rivet lines,
## 4 m to the tile, mapped from three sides (res://assets/textures, made by tools/blender/decals.py)
## and painted `color`. It is clean: the grime and wear on a hull are decals (ShipMarks), so the
## biggest surfaces cost one small tiling texture set.
static func hull_plating(color: Color) -> ORMMaterial3D:
	var key := "hull%s" % color.to_html()
	if not _mats.has(key):
		var m := ORMMaterial3D.new()
		m.albedo_color = color
		m.albedo_texture = load("res://assets/textures/hull_plating_albedo.png")
		# Occlusion, roughness and metallic come from the texture as they are.
		m.orm_texture = load("res://assets/textures/hull_plating_orm.png")
		m.roughness = 1.0
		m.metallic = 1.0
		m.ao_enabled = true
		m.normal_enabled = true
		m.normal_texture = load("res://assets/textures/hull_plating_normal.png")
		m.uv1_triplanar = true
		m.uv1_triplanar_sharpness = 8.0
		m.uv1_scale = Vector3.ONE * 0.25
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		_mats[key] = m
	return _mats[key]


## A light cookie (projector texture) for a spot light, so its light falls like a real lamp's rather
## than as an even disc: a hotter middle, rings from the reflector, a slightly uneven edge and a
## little dirt on the lens. The light's own cone fade still softens the rim, so the cookie only trims
## its outermost edge (and the pool stays as wide as the plain spot's). Made once per kind:
## - "headlight": a broad beam round a brighter core, with faint reflector rings.
## - "flood": an even wash with a soft edge, crossed by the faint shadows of the lamp's guard bars.
## - "flashlight": a tight hot spot, a dark band round it, a dimmer halo and a brighter rim.
## - "beacon": a hot core with streaks from the revolving lamp's fluted lens.
## A projector only shows on a light with shadows on.
static func light_cookie(kind: String) -> ImageTexture:
	var key := "cookie_" + kind
	if _meshes.has(key):
		return _meshes[key]
	var size := 128
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var dirt := FastNoiseLite.new()
	dirt.seed = 4711 + kind.length()
	dirt.frequency = 0.07
	var edge := FastNoiseLite.new()
	edge.seed = 917 + kind.length() * 3
	edge.frequency = 1.1
	for y in size:
		for x in size:
			var u := (x + 0.5) / size * 2.0 - 1.0
			var v := (y + 0.5) / size * 2.0 - 1.0
			var a := atan2(v, u)
			var r := sqrt(u * u + v * v) / (1.0 + 0.035 * edge.get_noise_2d(cos(a) * 2.0, sin(a) * 2.0))
			var val := 0.0
			match kind:
				"flashlight":
					val = 0.5 * exp(-pow(r / 0.2, 2.0)) + 0.58 * (1.0 - smoothstep(0.93, 1.0, r)) \
						+ 0.24 * exp(-pow((r - 0.9) / 0.04, 2.0)) - 0.16 * exp(-pow((r - 0.38) / 0.06, 2.0))
				"headlight":
					val = 0.12 * exp(-pow(r / 0.33, 2.0)) + 0.95 * (1.0 - smoothstep(0.9, 1.0, r)) \
						+ 0.03 * sin(r * 40.0) * (1.0 - smoothstep(0.4, 0.9, r))
				"beacon":
					val = (0.6 * exp(-pow(r / 0.3, 2.0)) + 0.5 * (1.0 - smoothstep(0.85, 1.0, r))) * (1.0 - 0.18 * r * (0.5 + 0.5 * sin(a * 14.0)))
				_:
					var bars := minf(absf(fposmod(u * 2.5 + 0.5, 1.0) - 0.5) / 2.5, absf(fposmod(v * 1.25 + 0.5, 1.0) - 0.5) / 1.25)
					val = (0.94 + 0.06 * exp(-pow(r / 0.45, 2.0))) * (1.0 - smoothstep(0.93, 1.0, r)) * (1.0 - 0.09 * (1.0 - smoothstep(0.012, 0.03, bars)))
			val *= 0.92 + 0.08 * dirt.get_noise_2d(x, y)
			val = clampf(val, 0.0, 1.0) if r < 1.0 else 0.0
			img.set_pixel(x, y, Color(val, val, val))
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_meshes[key] = tex
	return tex


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


# --- Assets made in Blender (tools/blender) ----------------------------------------------------

## The meshes of a Blender-made asset (res://assets/models/<name>/<name>.gltf), by object name.
## Loaded once. Each object's mesh is in the frame it is shown in (see the asset's script).
static func asset(asset_name: String) -> Dictionary:
	var key := "asset_" + asset_name
	if not _meshes.has(key):
		var scene: PackedScene = load("res://assets/models/%s/%s.gltf" % [asset_name, asset_name])
		var root := scene.instantiate()
		var out := {}
		for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
			out[str(mi.name)] = mi.mesh
		root.free()
		_meshes[key] = out
	return _meshes[key]


## Show mesh `mesh_name` of asset `asset_name` under `parent`. Its surfaces keep their baked
## materials, except those named in `swap`: a Material replaces it, a Color tints it (the material's
## albedo colour multiplies its baked texture; tinted copies are shared).
static func asset_mesh(parent: Node3D, asset_name: String, mesh_name: String, swap := {}, xform := Transform3D.IDENTITY,
		shadows := true) -> MeshInstance3D:
	var mesh: Mesh = asset(asset_name)[mesh_name]
	var mi := MeshInstance3D.new()
	mi.name = mesh_name
	mi.mesh = mesh
	mi.transform = xform
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in mesh.get_surface_count():
		var m := mesh.surface_get_material(i)
		if m == null or not swap.has(m.resource_name):
			continue
		var s: Variant = swap[m.resource_name]
		mi.set_surface_override_material(i, s if s is Material else tinted(m, s))
	parent.add_child(mi)
	return mi


## A copy of a baked asset material with its albedo colour set to `color`.
static func tinted(m: Material, color: Color) -> Material:
	var key := "t%d|%s" % [m.get_instance_id(), color.to_html()]
	if not _mats.has(key):
		var c := m.duplicate() as BaseMaterial3D
		c.albedo_color = color
		_mats[key] = c
	return _mats[key]


## The material named `material_name` on an asset mesh (to copy and animate, e.g. a glow).
static func asset_material(asset_name: String, mesh_name: String, material_name: String) -> Material:
	var mesh: Mesh = asset(asset_name)[mesh_name]
	for i in mesh.get_surface_count():
		var m := mesh.surface_get_material(i)
		if m != null and m.resource_name == material_name:
			return m
	return null


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
## `cap_end` / `cap_start` false leave the last / first section open (for a custom end cap, or a
## nose built onto it).
static func loft(sections: Array, chamfer := 0.3, cap_end := true, cap_start := true) -> ArrayMesh:
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
	if cap_start:
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
##
## It keeps the merged triangles itself (positions, normals and UVs, not indexed) and builds each
## material's mesh once in commit(): SurfaceTool.append_from() reads every source mesh back from the
## renderer, a stall per primitive that made a detailed build take over a second with a real
## renderer (and nothing headless). Normals are carried by the inverse transpose, so they stay
## right under any scale.
##
## With `cell` set (metres), pieces are grouped by where they are as well (cubes `cell` on a side,
## by each piece's middle): a big batch (a whole station) then commits as a mesh per material per
## cube, so what is out of view, or out of a light's reach, is culled instead of the lot being
## drawn in every pass. add_model() merges an imported model's surfaces (with their own materials)
## in too.
class Batch extends RefCounted:
	## Material (or [material, cube] with `cell`) -> BatchPart. (A packed array taken out of an Array
	## or Dictionary is a copy, so the triangles live in an object's members, which grow in place.)
	var _parts: Dictionary = {}
	## Boxes kept clear (keep_clear()): [inverse of the box's frame, the box] each.
	var _keep_out: Array = []
	## The size of the cubes pieces are grouped into (0: by material only).
	var cell := 0.0
	## Whole models placed as they are (add_instance()): [mesh, cube] (or the mesh) -> transforms.
	var _instances: Dictionary = {}

	func _part(m: Material, at: Vector3) -> BatchPart:
		var key: Variant = m
		if cell > 0.0:
			key = [m, Vector3i((at / cell).floor())]
		var part: BatchPart = _parts.get(key)
		if part == null:
			part = BatchPart.new()
			part.material = m
			_parts[key] = part
		return part

	func _kept_out(mesh: Mesh, xform: Transform3D) -> bool:
		if _keep_out.is_empty():
			return false
		var bounds := mesh.get_aabb()
		for k: Array in _keep_out:
			if ((k[0] as Transform3D) * xform * bounds).intersects(k[1]):
				return true
		return false

	## Keep `box` (in frame `xform`) clear: any piece added from now on whose bounds reach into it is
	## left out (a keypad and the view of it, say). Bounds are boxes round the pieces, so a slanted
	## piece near the box can go too.
	func keep_clear(xform: Transform3D, box: AABB) -> void:
		_keep_out.append([xform.affine_inverse(), box])

	func add(mesh: Mesh, xform: Transform3D, m: Material) -> void:
		if _kept_out(mesh, xform):
			return
		var tri: Array = Models.triangles(mesh)
		var part := _part(m, xform * mesh.get_aabb().get_center())
		var nb := xform.basis
		if absf(nb.determinant()) > 1e-12:
			nb = nb.inverse().transposed()
		part.v.append_array(xform * (tri[0] as PackedVector3Array))
		part.n.append_array(Transform3D(nb, Vector3.ZERO) * (tri[1] as PackedVector3Array))
		part.uv.append_array(tri[2] as PackedVector2Array)

	## Place a whole imported model (every surface with its own material) at `xform`, as it is: all
	## placements of the same mesh (in the same cube, with `cell`) are drawn together, as one
	## MultiMesh, with no copying of its triangles.
	func add_instance(mesh: Mesh, xform: Transform3D) -> void:
		if _kept_out(mesh, xform):
			return
		var key: Variant = mesh
		if cell > 0.0:
			key = [mesh, Vector3i(((xform * mesh.get_aabb().get_center()) / cell).floor())]
		if not _instances.has(key):
			_instances[key] = []
		(_instances[key] as Array).append(xform)

	## Merge every surface of an imported model (a Blender asset's mesh) in at `xform`, each with its
	## own material (or the one `swap` gives for that material's name). Its tangents come along for
	## the normal maps. False if the mesh's triangles can't be had (it should be shown on its own).
	func add_model(mesh: Mesh, xform: Transform3D, swap := {}) -> bool:
		var surfaces: Array = Models.surface_triangles(mesh)
		if surfaces.is_empty():
			return false
		if _kept_out(mesh, xform):
			return true
		var at := xform * mesh.get_aabb().get_center()
		var nb := xform.basis
		if absf(nb.determinant()) > 1e-12:
			nb = nb.inverse().transposed()
		var flip := -1.0 if xform.basis.determinant() < 0.0 else 1.0
		for sd: Array in surfaces:
			var m: Material = sd[0]
			if m and swap.has(m.resource_name) and swap[m.resource_name] is Material:
				m = swap[m.resource_name]
			var part := _part(m, at)
			var v: PackedVector3Array = sd[1]
			var base := part.v.size()
			part.v.append_array(xform * v)
			part.n.append_array(Transform3D(nb, Vector3.ZERO) * (sd[2] as PackedVector3Array))
			part.uv.append_array(sd[3] as PackedVector2Array)
			var tan: PackedFloat32Array = sd[4]
			if tan.size() == v.size() * 4:
				# Tangents follow the model's turn (not its scale's inverse), their sign the handedness.
				if part.t.size() < base * 4:
					part.t.resize(base * 4)
				for i in v.size():
					var tv := (xform.basis * Vector3(tan[i * 4], tan[i * 4 + 1], tan[i * 4 + 2])).normalized()
					part.t.append(tv.x)
					part.t.append(tv.y)
					part.t.append(tv.z)
					part.t.append(tan[i * 4 + 3] * flip)
		return true

	## The primitives below scale shared unit meshes into place. Boxes and straight cylinders scale
	## exactly; cones are shared per size.
	func box(pos: Vector3, size: Vector3, m: Material, rot_deg := Vector3.ZERO) -> void:
		add(Models.unit_box(), Transform3D(Models.euler(rot_deg) * Basis.from_scale(size), pos), m)

	## A box `size` in frame `xform` (its middle at the frame's origin).
	func box_at(xform: Transform3D, size: Vector3, m: Material) -> void:
		add(Models.unit_box(), xform * Transform3D(Basis.from_scale(size), Vector3.ZERO), m)

	func cyl(pos: Vector3, radius: float, height: float, m: Material, rot_deg := Vector3.ZERO,
			top_radius := -1.0, sides := 16) -> void:
		cyl_at(Transform3D(Models.euler(rot_deg), pos), radius, height, m, top_radius, sides)

	## A cylinder (or cone, with `top_radius`) along the y axis of frame `xform`.
	func cyl_at(xform: Transform3D, radius: float, height: float, m: Material, top_radius := -1.0, sides := 16) -> void:
		if top_radius < 0.0 or is_equal_approx(top_radius, radius):
			add(Models.unit_cyl(sides), xform * Transform3D(Basis.from_scale(Vector3(radius, height, radius)), Vector3.ZERO), m)
		else:
			add(Models.cone_mesh(radius, top_radius, height, sides), xform, m)

	func sphere(pos: Vector3, radius: float, m: Material, scale := Vector3.ONE, segments := 12) -> void:
		add(Models.unit_sphere(segments), Transform3D(Basis.from_scale(scale * radius), pos), m)

	func strut(a: Vector3, b: Vector3, radius: float, m: Material, sides := 6) -> void:
		add(Models.unit_cyl(sides), Models.strut_transform(a, b) * Transform3D(Basis.from_scale(Vector3(radius, 1.0, radius)), Vector3.ZERO), m)

	## A box from a to b that stays upright: `width` across, `height` up.
	func beam(a: Vector3, b: Vector3, width: float, height: float, m: Material) -> void:
		var d := b - a
		var up := Vector3.UP if absf(d.normalized().y) < 0.95 else Vector3.FORWARD
		add(Models.unit_box(), Transform3D(Basis.looking_at(d, up) * Basis.from_scale(Vector3(width, height, d.length())), (a + b) * 0.5), m)

	func commit(parent: Node3D, node_name := "Detail", shadows := true) -> Array[MeshInstance3D]:
		var out: Array[MeshInstance3D] = []
		var i := 0
		for key: Variant in _parts:
			var part: BatchPart = _parts[key]
			if part.v.is_empty():
				continue
			var arrays := []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = part.v
			arrays[Mesh.ARRAY_NORMAL] = part.n
			arrays[Mesh.ARRAY_TEX_UV] = part.uv
			if not part.t.is_empty():
				part.t.resize(part.v.size() * 4)
				arrays[Mesh.ARRAY_TANGENT] = part.t
			var am := ArrayMesh.new()
			am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			var mi := MeshInstance3D.new()
			mi.name = "%s%d" % [node_name, i]
			mi.mesh = am
			mi.material_override = part.material
			if not shadows:
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			parent.add_child(mi)
			out.append(mi)
			i += 1
		_parts.clear()
		for key: Variant in _instances:
			var list: Array = _instances[key]
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = key[0] if key is Array else key
			mm.instance_count = list.size()
			for k in list.size():
				mm.set_instance_transform(k, list[k])
			var mmi := MultiMeshInstance3D.new()
			mmi.name = "%sModels%d" % [node_name, i]
			mmi.multimesh = mm
			if not shadows:
				mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			parent.add_child(mmi)
			i += 1
		_instances.clear()
		return out


## One material's merged triangles in a Batch (tangents only for merged models: 4 floats a corner).
class BatchPart extends RefCounted:
	var material: Material
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var uv := PackedVector2Array()
	var t := PackedFloat32Array()


## Merge every visible mesh under `root` (a model that no longer moves in parts, say a weapon lying on
## a crate) into one mesh per material under `root`, and free the pieces: a model of a hundred small
## boxes then costs a draw call per material. Hidden pieces (and what is under them), labels, lights
## and the rest stay as they are.
static func flatten(root: Node3D) -> void:
	var b := Batch.new()
	var done: Array[Node] = []
	_flatten_into(root, Transform3D.IDENTITY, b, done)
	for n in done:
		n.get_parent().remove_child(n)
		n.queue_free()
	b.commit(root, "Merged")


static func _flatten_into(node: Node, xform: Transform3D, b: Batch, done: Array[Node]) -> void:
	for c in node.get_children():
		var n3 := c as Node3D
		if n3 == null or not n3.visible:
			continue
		var x := xform * n3.transform
		var mi := c as MeshInstance3D
		if mi and mi.mesh and mi.get_child_count() == 0:
			var mesh := mi.mesh
			var merged := false
			if mesh is PrimitiveMesh:
				var m: Material = mi.material_override if mi.material_override else (mesh as PrimitiveMesh).material
				if m == null:
					m = mi.get_surface_override_material(0)
				if m:
					b.add(mesh, x, m)
					merged = true
			elif mi.material_override == null:
				var swap := {}
				for i in mesh.get_surface_count():
					var own := mesh.surface_get_material(i)
					if own and mi.get_surface_override_material(i):
						swap[own.resource_name] = mi.get_surface_override_material(i)
				merged = b.add_model(mesh, x, swap)
			if merged:
				done.append(mi)
				continue
		_flatten_into(c, x, b, done)


## Every surface of an imported mesh as triangles: [material, positions, normals, uvs, tangents]
## each, one entry per corner (not indexed); read back from the renderer once per mesh and kept.
## Empty when the renderer has none to give (the mesh is then shown on its own).
static func surface_triangles(mesh: Mesh) -> Array:
	if _surface_tris.has(mesh):
		return _surface_tris[mesh]
	var out: Array = []
	for si in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(si)
		if arrays.is_empty() or arrays[Mesh.ARRAY_VERTEX] == null:
			out = []
			break
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
		var tan: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT] if arrays[Mesh.ARRAY_TANGENT] != null else PackedFloat32Array()
		if n.size() != v.size():
			n.resize(v.size())
		if uv.size() != v.size():
			uv.resize(v.size())
		var index: Variant = arrays[Mesh.ARRAY_INDEX]
		if index != null and (index as PackedInt32Array).size() > 0:
			var ix: PackedInt32Array = index
			var tv := PackedVector3Array()
			var tn := PackedVector3Array()
			var tu := PackedVector2Array()
			var tt := PackedFloat32Array()
			tv.resize(ix.size())
			tn.resize(ix.size())
			tu.resize(ix.size())
			var with_t := tan.size() == v.size() * 4
			if with_t:
				tt.resize(ix.size() * 4)
			for i in ix.size():
				var k := ix[i]
				tv[i] = v[k]
				tn[i] = n[k]
				tu[i] = uv[k]
				if with_t:
					for c in 4:
						tt[i * 4 + c] = tan[k * 4 + c]
			v = tv
			n = tn
			uv = tu
			tan = tt
		out.append([mesh.surface_get_material(si), v, n, uv, tan])
	_surface_tris[mesh] = out
	return out


static var _surface_tris: Dictionary = {}


## The triangles of a mesh's first surface: [positions, normals, uvs], one entry per corner (not
## indexed). Primitive meshes are generated on the CPU (no read back from the renderer); the shared
## ones below keep theirs.
static func triangles(mesh: Mesh) -> Array:
	if _tris.has(mesh):
		return _tris[mesh]
	var prim := mesh as PrimitiveMesh
	var arrays: Array = prim.get_mesh_arrays() if prim else mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
	if n.size() != v.size():
		n.resize(v.size())
	if uv.size() != v.size():
		uv.resize(v.size())
	var out := [v, n, uv]
	var index: Variant = arrays[Mesh.ARRAY_INDEX]
	if index != null and (index as PackedInt32Array).size() > 0:
		var ix: PackedInt32Array = index
		var tv := PackedVector3Array()
		var tn := PackedVector3Array()
		var tu := PackedVector2Array()
		tv.resize(ix.size())
		tn.resize(ix.size())
		tu.resize(ix.size())
		for i in ix.size():
			tv[i] = v[ix[i]]
			tn[i] = n[ix[i]]
			tu[i] = uv[ix[i]]
		out = [tv, tn, tu]
	if _shared_prims.has(mesh):
		_tris[mesh] = out
	return out


static var _tris: Dictionary = {}
static var _shared_prims: Dictionary = {}


## Shared unit meshes for Batch: a 1 m box, cylinders of radius 1 and height 1, spheres of radius 1.
static func unit_box() -> BoxMesh:
	if not _meshes.has("unit_box"):
		var bm := BoxMesh.new()
		bm.size = Vector3.ONE
		_meshes["unit_box"] = bm
		_shared_prims[bm] = true
	return _meshes["unit_box"]


static func unit_cyl(sides: int) -> CylinderMesh:
	var key := "unit_cyl%d" % sides
	if not _meshes.has(key):
		var cm := CylinderMesh.new()
		cm.bottom_radius = 1.0
		cm.top_radius = 1.0
		cm.height = 1.0
		cm.radial_segments = sides
		cm.rings = 1
		_meshes[key] = cm
		_shared_prims[cm] = true
	return _meshes[key]


static func unit_sphere(segments: int) -> SphereMesh:
	var key := "unit_sphere%d" % segments
	if not _meshes.has(key):
		var sm := SphereMesh.new()
		sm.radius = 1.0
		sm.height = 2.0
		sm.radial_segments = segments
		sm.rings = maxi(segments / 2, 4)
		_meshes[key] = sm
		_shared_prims[sm] = true
	return _meshes[key]


static func cone_mesh(r0: float, r1: float, h: float, sides: int) -> CylinderMesh:
	var key := "cone%.3f|%.3f|%.3f|%d" % [r0, r1, h, sides]
	if not _meshes.has(key):
		var cm := CylinderMesh.new()
		cm.bottom_radius = r0
		cm.top_radius = r1
		cm.height = h
		cm.radial_segments = sides
		cm.rings = 1
		_meshes[key] = cm
		_shared_prims[cm] = true
	return _meshes[key]


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
