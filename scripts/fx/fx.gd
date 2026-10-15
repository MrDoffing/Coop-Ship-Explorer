class_name Fx
extends RefCounted
## One-shot visual effects. They are purely local: each peer spawns them from replicated events.

static var _spark_mat: StandardMaterial3D
static var _meshes: Dictionary = {}


static func _root() -> Node3D:
	if Game.mission and is_instance_valid(Game.mission):
		return Game.mission.get("fx_root")
	return null


## Add an effect node at a global transform. Effects never move, so physics interpolation is
## switched off and the transform is set before the node enters the tree; otherwise the first
## frame interpolates from the world origin (and particles are emitted there).
static func _attach(r: Node3D, node: Node3D, xform: Transform3D) -> void:
	node.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	node.transform = r.global_transform.affine_inverse() * xform
	r.add_child(node)


static func _spark_material() -> StandardMaterial3D:
	if _spark_mat == null:
		_spark_mat = StandardMaterial3D.new()
		_spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_spark_mat.vertex_color_use_as_albedo = true
		_spark_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_spark_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_spark_mat.disable_receive_shadows = true
	return _spark_mat


static func _streak_mesh(size: float) -> Mesh:
	var key := "streak%.3f" % size
	if not _meshes.has(key):
		var m := BoxMesh.new()
		m.size = Vector3(size * 0.5, size * 5.0, size * 0.5)
		m.material = _spark_material()
		_meshes[key] = m
	return _meshes[key]


## Bullet impact: sparks bouncing off the surface, a small glowing puff and a flash of light.
static func impact(pos: Vector3, normal: Vector3, color: Color, strength := 1.0) -> void:
	var r := _root()
	if r == null:
		return
	var n := normal.normalized() if normal.length_squared() > 0.0001 else Vector3.UP
	sparks(pos + n * 0.03, color, int(14 * strength), 6.5 * strength, 0.045 * strength, 0.45, n, 65.0)
	flash(pos + n * 0.3, color, 2.5 * strength, 4.0 * strength, 0.1)
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 10
	sm.rings = 5
	mi.mesh = sm
	var mat := Models.glow(Color(color.r * 2.0, color.g * 2.0, color.b * 2.0, 0.8))
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_attach(r, mi, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.05 * strength), pos + n * 0.05))
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * 0.22 * strength, 0.12)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.18)
	tw.chain().tween_callback(mi.queue_free)


## Burst of glowing streaks. With a direction, they spray into a cone around it.
static func sparks(pos: Vector3, color: Color, amount := 16, speed := 8.0, size := 0.06, life := 0.5,
		dir := Vector3.ZERO, spread := 180.0) -> void:
	var r := _root()
	if r == null:
		return
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = amount
	p.lifetime = life
	p.explosiveness = 1.0
	p.local_coords = false
	p.mesh = _streak_mesh(size)
	p.particle_flag_align_y = true
	p.direction = dir.normalized() if dir != Vector3.ZERO else Vector3.UP
	p.spread = spread
	p.initial_velocity_min = speed * 0.35
	p.initial_velocity_max = speed
	p.gravity = Vector3.ZERO
	p.damping_min = speed * 0.6
	p.damping_max = speed * 1.2
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	var ramp := Gradient.new()
	ramp.set_color(0, Color(color.r * 2.0, color.g * 2.0, color.b * 2.0, 1.0))
	ramp.set_color(1, Color(color.r, color.g, color.b, 0.0))
	p.color_ramp = ramp
	_attach(r, p, Transform3D(Basis.IDENTITY, pos))
	p.finished.connect(p.queue_free)


## Brief point light flash.
static func flash(pos: Vector3, color: Color, energy := 4.0, radius := 8.0, life := 0.15) -> void:
	var r := _root()
	if r == null:
		return
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = radius
	_attach(r, l, Transform3D(Basis.IDENTITY, pos))
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, life)
	tw.tween_callback(l.queue_free)


## Expanding fireball with sparks and a light flash.
static func explosion(pos: Vector3, radius := 3.0, color := Color(1.0, 0.55, 0.2)) -> void:
	var r := _root()
	if r == null:
		return
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 16
	sm.rings = 8
	mi.mesh = sm
	var mat := Models.glow(Color(color.r * 1.3, color.g * 1.3, color.b * 1.3, 0.55))
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_attach(r, mi, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * radius * 0.2), pos))
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * radius, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.45)
	tw.chain().tween_callback(mi.queue_free)
	sparks(pos, color, int(clampf(radius * 8.0, 10.0, 48.0)), radius * 7.0, 0.08 + radius * 0.02, 0.8)
	flash(pos, color, 3.0, radius * 6.0, 0.4)


## Expanding energy sphere (the mothership's emergency blast).
static func shockwave(pos: Vector3, radius: float, color: Color, life := 0.55) -> void:
	var r := _root()
	if r == null:
		return
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 32
	sm.rings = 16
	mi.mesh = sm
	var mat := Models.glow(Color(color.r * 1.6, color.g * 1.6, color.b * 1.6, 0.5))
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_attach(r, mi, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 2.0), pos))
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * radius, life).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(mat, "albedo_color:a", 0.0, life)
	tw.chain().tween_callback(mi.queue_free)
	ring(pos, Vector3.UP, color * 0.45, radius, life)


## Short-lived straight beam between two points (blasters, rail lance).
static func tracer(from: Vector3, to: Vector3, color: Color, width := 0.05, life := 0.08) -> void:
	var r := _root()
	if r == null or from.distance_squared_to(to) < 0.0001:
		return
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = width
	cm.bottom_radius = width
	cm.height = 1.0
	cm.radial_segments = 6
	cm.rings = 1
	mi.mesh = cm
	var mat := Models.glow(Color(color.r * 3.0, color.g * 3.0, color.b * 3.0, 1.0))
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_attach(r, mi, Models.strut_transform(from, to))
	var tw := mi.create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, life)
	tw.tween_callback(mi.queue_free)


## Expanding ring on a surface (shield and breach effects).
static func ring(pos: Vector3, normal: Vector3, color: Color, radius := 2.0, life := 0.4) -> void:
	var r := _root()
	if r == null:
		return
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.85
	tm.outer_radius = 1.0
	tm.rings = 24
	tm.ring_segments = 6
	mi.mesh = tm
	var mat := Models.glow(Color(color.r * 2.0, color.g * 2.0, color.b * 2.0, 1.0))
	mi.material_override = mat
	var up := normal.normalized()
	var side := up.cross(Vector3.RIGHT if absf(up.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD).normalized()
	_attach(r, mi, Transform3D(Basis(side, up, side.cross(up)).scaled_local(Vector3.ONE * 0.2), pos))
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(radius, 0.3, radius), life)
	tw.tween_property(mat, "albedo_color:a", 0.0, life)
	tw.chain().tween_callback(mi.queue_free)
