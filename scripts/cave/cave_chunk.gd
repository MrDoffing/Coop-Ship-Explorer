class_name CaveChunk
extends StaticBody3D
## One slice of the cave. Geometry is generated on a worker thread from the mission seed, so every
## peer builds identical rock locally and only the chunk index needs to be replicated.

signal built(chunk: CaveChunk)

static var _material: Material

var index := 0
var cave_seed := 0
## Generation output (vertices, normals...). Kept on the server for placing minerals and nests.
var result: Dictionary = {}
var is_built := false
var _task := -1
var _job: ChunkJob


class ChunkJob extends RefCounted:
	var seed_value := 0
	var index := 0
	var result: Dictionary
	var msec := 0

	func run() -> void:
		var t := Time.get_ticks_msec()
		result = CaveGen.new(seed_value).build_chunk(index)
		msec = Time.get_ticks_msec() - t


func setup(p_seed: int, p_index: int) -> void:
	cave_seed = p_seed
	index = p_index
	name = "Chunk%d" % p_index


func _ready() -> void:
	collision_layer = Game.LAYER_CAVE
	collision_mask = 0
	_job = ChunkJob.new()
	_job.seed_value = cave_seed
	_job.index = index
	_task = WorkerThreadPool.add_task(_job.run, false, "Cave chunk %d" % index)


func _process(_delta: float) -> void:
	if _task < 0 or not WorkerThreadPool.is_task_completed(_task):
		return
	WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
	set_process(false)
	_finish(_job.result)
	if OS.is_debug_build() and _job.msec > 400:
		print("Cave chunk %d took %d ms" % [index, _job.msec])
	_job = null


func _exit_tree() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1


func _finish(data: Dictionary) -> void:
	result = data
	var indices: PackedInt32Array = data["indices"]
	if indices.size() > 0:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = data["verts"]
		arrays[Mesh.ARRAY_NORMAL] = data["norms"]
		arrays[Mesh.ARRAY_COLOR] = data["colors"]
		arrays[Mesh.ARRAY_INDEX] = indices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = rock_material()
		add_child(mi)
		var shape := ConcavePolygonShape3D.new()
		shape.backface_collision = true
		shape.set_faces(data["faces"])
		var cs := CollisionShape3D.new()
		cs.shape = shape
		add_child(cs)
	is_built = true
	built.emit(self)


const ROCK_SHADER := """
shader_type spatial;
render_mode cull_back;

uniform sampler2D detail_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D vein_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D mask_tex : filter_linear_mipmap, repeat_enable;
uniform float scale = 0.07;
uniform float vein_scale = 0.03;
uniform vec3 vein_color : source_color = vec3(0.2, 0.75, 0.95);
uniform float vein_energy = 1.6;
uniform float normal_strength = 0.9;

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize(mat3(MODEL_MATRIX) * NORMAL);
}

vec4 tri(sampler2D t, vec3 p, vec3 w) {
	return texture(t, p.zy) * w.x + texture(t, p.xz) * w.y + texture(t, p.xy) * w.z;
}

void fragment() {
	vec3 n = normalize(wnrm);
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z);
	vec3 p = wpos * scale;
	vec3 detail = tri(detail_tex, p, w).rgb;
	float fine = tri(detail_tex, p * 3.7, w).r;
	ALBEDO = COLOR.rgb * detail * (0.72 + 0.4 * fine);
	ROUGHNESS = 0.88;
	// Glowing mineral veins: thin contour lines of a smooth noise, only in sparse patches.
	vec3 pv = wpos * vein_scale;
	float v = tri(vein_tex, pv, w).r;
	// Hairline width in screen space so veins stay thin up close.
	float lw = max(fwidth(v) * 1.4, 0.0015);
	float line = 1.0 - smoothstep(lw * 0.4, lw, abs(v - 0.5));
	float mask = smoothstep(0.63, 0.78, tri(mask_tex, pv * 0.3, w).r);
	EMISSION = vein_color * line * mask * vein_energy;
	// Triplanar normal mapping (whiteout blend).
	vec3 tx = texture(normal_tex, p.zy).xyz * 2.0 - 1.0;
	vec3 ty = texture(normal_tex, p.xz).xyz * 2.0 - 1.0;
	vec3 tz = texture(normal_tex, p.xy).xyz * 2.0 - 1.0;
	tx.xy *= normal_strength;
	ty.xy *= normal_strength;
	tz.xy *= normal_strength;
	tx = vec3(tx.xy + n.zy, abs(tx.z) * n.x);
	ty = vec3(ty.xy + n.xz, abs(ty.z) * n.y);
	tz = vec3(tz.xy + n.xy, abs(tz.z) * n.z);
	vec3 wn = normalize(tx.zyx * w.x + ty.xzy * w.y + tz.xyz * w.z);
	NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
}
"""


## Tint the glowing veins (the mission shifts it with depth).
static func set_vein_color(c: Color) -> void:
	if _material is ShaderMaterial:
		(_material as ShaderMaterial).set_shader_parameter("vein_color", c)


static func rock_material() -> Material:
	if _material:
		return _material
	var m := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = ROCK_SHADER
	m.shader = shader
	var detail := FastNoiseLite.new()
	detail.noise_type = FastNoiseLite.TYPE_CELLULAR
	detail.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	detail.frequency = 0.025
	detail.fractal_type = FastNoiseLite.FRACTAL_FBM
	detail.fractal_octaves = 4
	var tex := NoiseTexture2D.new()
	tex.width = 512
	tex.height = 512
	tex.seamless = true
	tex.noise = detail
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.45, 0.43, 0.42))
	ramp.set_color(1, Color(1.0, 0.98, 0.95))
	tex.color_ramp = ramp
	m.set_shader_parameter("detail_tex", tex)
	var bump := FastNoiseLite.new()
	bump.noise_type = FastNoiseLite.TYPE_CELLULAR
	bump.frequency = 0.03
	bump.fractal_octaves = 3
	bump.fractal_type = FastNoiseLite.FRACTAL_FBM
	var ntex := NoiseTexture2D.new()
	ntex.width = 512
	ntex.height = 512
	ntex.seamless = true
	ntex.as_normal_map = true
	ntex.bump_strength = 12.0
	ntex.noise = bump
	m.set_shader_parameter("normal_tex", ntex)
	var veins := FastNoiseLite.new()
	veins.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	veins.frequency = 0.004
	veins.fractal_octaves = 2
	var vtex := NoiseTexture2D.new()
	vtex.width = 512
	vtex.height = 512
	vtex.seamless = true
	vtex.noise = veins
	m.set_shader_parameter("vein_tex", vtex)
	var mask := FastNoiseLite.new()
	mask.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	mask.frequency = 0.008
	mask.seed = 77
	var mtex := NoiseTexture2D.new()
	mtex.width = 256
	mtex.height = 256
	mtex.seamless = true
	mtex.noise = mask
	m.set_shader_parameter("mask_tex", mtex)
	_material = m
	return m
