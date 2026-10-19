class_name Marks
extends Node3D
## Decals: Godot's Decal node is a box that paints a texture onto the surfaces inside it, projected
## along the box's -Y. The textures are in res://assets/decals (tools/blender/decals.py): a texture
## "x" may come with "x_n" (normals), "x_e" (emission) and "x_orm" (occlusion, roughness, metallic).
##
## A decal only paints surfaces on its render layers (`cull_mask`): the motherships' hull and the
## things fixed to it carry Game.VIS_HULL, the cave rock Game.VIS_ROCK, so the crew, aliens, turrets
## and the interior walls just inside the hull stay clean.
##
## As a node, Marks keeps decals that fade away: battle damage on a ship's hull (a child of its
## exterior, so they travel with it) and the mining lasers' burns on the rock. Each lives `life`
## seconds, fading out over the last FADE share of it; one that was hot (a fresh acid splash, molten
## rock) glows and cools. When there are more than `cap`, the oldest go first.

const DIR := "res://assets/decals/"
## Fading decals fade out over this last share of their life.
const FADE := 0.4
## Decals further than this from the camera fade out over FADE_LENGTH metres (they cost nothing
## then).
const FADE_FROM := 140.0
const FADE_LENGTH := 40.0

static var _textures: Dictionary = {}

## At most this many fading decals; the oldest go first.
var cap := 40
## Each fading decal: {"decal", "age", "life", "alpha", "glow", "cool", "hot_age"}.
var _marks: Array[Dictionary] = []


## A decal texture by name (null if there is none).
static func texture(tex_name: String) -> Texture2D:
	if not _textures.has(tex_name):
		var path := DIR + tex_name + ".png"
		_textures[tex_name] = load(path) if ResourceLoader.exists(path) else null
	return _textures[tex_name]


## Width over height of a decal texture (for text).
static func aspect(tex_name: String) -> float:
	var t := texture(tex_name)
	return float(t.get_width()) / float(t.get_height()) if t else 1.0


## A decal painting `tex_name` (and its "_n", "_e" and "_orm" textures when there are), sized
## `size` (width along the texture's left-to-right, depth along the projection, height), placed by
## `xform` (see on_surface()), tinted `color` (its alpha is the opacity), on render layers `layers`.
## `orm` names a separate texture for occlusion, roughness and metallic where it has none of its own
## (e.g. "orm_matte" for dirt, "orm_metal" for bare metal).
static func make(tex_name: String, xform: Transform3D, size: Vector3, layers: int, color := Color.WHITE, orm := "") -> Decal:
	var d := Decal.new()
	d.texture_albedo = texture(tex_name)
	d.texture_normal = texture(tex_name + "_n")
	d.texture_emission = texture(tex_name + "_e")
	var o := texture(tex_name + "_orm")
	d.texture_orm = o if o else (texture(orm) if orm != "" else null)
	d.emission_energy = 0.0
	d.size = size
	d.transform = xform
	d.modulate = color
	d.cull_mask = layers
	# Fade on surfaces turned away from the projection, and towards the ends of the box.
	d.normal_fade = 0.35
	d.upper_fade = 0.2
	d.lower_fade = 0.2
	d.distance_fade_enabled = true
	d.distance_fade_begin = FADE_FROM
	d.distance_fade_length = FADE_LENGTH
	return d


## Where a decal sits on a surface at `point` facing `normal`: its box's -Y goes into the surface,
## and its texture reads left to right along `right` (a viewer facing the surface has it upright).
static func on_surface(point: Vector3, normal: Vector3, right: Vector3) -> Transform3D:
	var y := normal.normalized()
	var x := right - y * right.dot(y)
	if x.length_squared() < 1e-6:
		x = y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT)
	x = x.normalized()
	return Transform3D(Basis(x, y, x.cross(y)), point)


## The right-hand direction of someone facing a surface with normal `normal`, their head towards
## `up` (for text to read upright).
static func right_of(normal: Vector3, up: Vector3) -> Vector3:
	var r := (-normal).cross(up)
	return r.normalized() if r.length_squared() > 1e-6 else Vector3.RIGHT


# --- Fading decals --------------------------------------------------------------------------------------

## Keep `d` (added as a child) for `life` seconds. `glow` (emission energy) cools away over
## `cool` seconds once it is no longer heated (see heat()).
func add(d: Decal, life: float, glow := 0.0, cool := 1.0) -> Decal:
	add_child(d)
	_marks.append({"decal": d, "age": 0.0, "life": life, "alpha": d.modulate.a, "glow": glow, "cool": maxf(cool, 0.05), "hot_age": 0.0})
	d.emission_energy = glow
	while _marks.size() > cap:
		_drop(0)
	return d


## Keep `d` hot (glowing at full emission) right now.
func heat(d: Decal) -> void:
	for m in _marks:
		if m["decal"] == d:
			m["hot_age"] = m["age"]
			return


## The fading decal using texture `tex_name` nearest to `point` (local) within `radius`, or null.
func near(tex_name: String, point: Vector3, radius: float) -> Decal:
	var best: Decal = null
	var best_d := radius
	for m in _marks:
		var d: Decal = m["decal"]
		if d.texture_albedo == texture(tex_name):
			var dist := d.position.distance_to(point)
			if dist < best_d:
				best_d = dist
				best = d
	return best


## Make `d` fresh again (it stays the full time from now), and glow anew.
func refresh(d: Decal) -> void:
	for m in _marks:
		if m["decal"] == d:
			m["age"] = 0.0
			m["hot_age"] = 0.0
			return


func count() -> int:
	return _marks.size()


func _drop(i: int) -> void:
	var d: Decal = _marks[i]["decal"]
	_marks.remove_at(i)
	if is_instance_valid(d):
		d.queue_free()


func _process(delta: float) -> void:
	var i := 0
	while i < _marks.size():
		var m: Dictionary = _marks[i]
		var d: Decal = m["decal"]
		var age := float(m["age"]) + delta
		m["age"] = age
		var life := float(m["life"])
		if age >= life or not is_instance_valid(d):
			_drop(i)
			continue
		var fade := 1.0 - smoothstep(life * (1.0 - FADE), life, age)
		d.modulate.a = float(m["alpha"]) * fade
		var glow := float(m["glow"])
		if glow > 0.0:
			var since := age - float(m["hot_age"])
			d.emission_energy = glow * exp(-since / float(m["cool"])) * fade
		i += 1
