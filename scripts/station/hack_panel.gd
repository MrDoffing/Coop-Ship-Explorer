class_name HackPanel
extends Node3D
## The keypad lock beside a sealed door (OutpostLayout "hack" doors). Upper half: four lamps lit in
## the code's colours, a display, the keys and three lamps for the tries left. Lower half: a service
## hatch over the lock's wiring, six cords tangled from six digits on the left to six coloured
## terminals on the right. To get through, follow each lit colour's cord back to its digit and key
## in the four digits in the lamps' order. Three wrong codes and the door locks down for good.
##
## A crew member "enters" the panel (CrewMember: E): the view closes in on it, the hatch swings open
## and a lamp inside lights the wiring; LMB presses the key under the middle of the view (or type the
## digits), and four digits are sent to the server (Mothership.request_hack). The hatch and what has
## been keyed in are the local player's own; the lamps and the display show the lock's replicated
## state to everyone.
##
## Panel-local frame: x right, y up, z out of the wall; the origin on the wall's face, mid-panel.

const SIZE := Vector2(0.82, 1.12)
const DEPTH := 0.12
## The keys: rows top to bottom; "C" clears, "<" deletes the last digit.
const KEYS := [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"], ["C", "0", "<"]]
const KEY_SIZE := Vector2(0.085, 0.066)
const KEY_GAP := Vector2(0.105, 0.082)
const KEY_DEPTH := 0.034
## The readout's phosphor (amber, not a neon green).
const DISPLAY_COLOR := Color(1.0, 0.66, 0.28)
## The wiring board: cord rows and the terminals' x either side.
const ROW_TOP := -0.08
const ROW_STEP := 0.08
const TERMINAL_X := 0.27
const CORD_R := 0.0085
## Where the view sits for a close look (panel-local) and its field of view, and how long the hatch
## takes to open.
const VIEW_AT := Vector3(0, 0.0, 1.2)
const VIEW_FOV := 60.0
const HATCH_TIME := 0.35

var door := -1
var _d: Dictionary = {}
var _keys: Array = []
var _code_lamps: Array[StandardMaterial3D] = []
var _try_lamps: Array[StandardMaterial3D] = []
var _display: Label3D
var _hatch: Node3D
var _inner_light: OmniLight3D
var _key_mat: StandardMaterial3D
var _key_hot: StandardMaterial3D
## The local player's own: what has been keyed in, whether the panel is open, the hatch (0..1).
var typed := ""
var active := false
var _hatch_t := 0.0
var _hover := ""
var _waiting := 0.0
var _flash_t := 0.0
var _flash_text := ""
var _flash_col := Color.WHITE
var _state := -1
var _tries := 0
static var _key_box: BoxMesh


func build(d: Dictionary, di: int, m: Dictionary) -> void:
	_d = d
	door = di
	var b := Models.Batch.new()
	var steel: Material = m["steel"]
	var dark: Material = m["dark"]
	# The housing: a bolted steel box with a lip round the hatch and a stencil. Its lower half is
	# hollow: a back plate and sides round the wiring, closed by the hatch.
	var top_h := SIZE.y * 0.5 + 0.005
	b.box(Vector3(0, SIZE.y * 0.5 - top_h * 0.5, DEPTH * 0.5), Vector3(SIZE.x, top_h, DEPTH), m["olive"])
	b.box(Vector3(0, -SIZE.y * 0.25, 0.01), Vector3(SIZE.x, SIZE.y * 0.5, 0.02), m["olive"])
	for sx: float in [-1.0, 1.0]:
		b.box(Vector3(sx * (SIZE.x * 0.5 - 0.02), -SIZE.y * 0.25, DEPTH * 0.5), Vector3(0.04, SIZE.y * 0.5, DEPTH), m["olive"])
	b.box(Vector3(0, -SIZE.y * 0.5 + 0.02, DEPTH * 0.5), Vector3(SIZE.x, 0.04, DEPTH), m["olive"])
	b.box(Vector3(0, SIZE.y * 0.5 - 0.02, DEPTH + 0.01), Vector3(SIZE.x, 0.04, 0.02), m["bronze"])
	b.box(Vector3(0, -SIZE.y * 0.5 + 0.02, DEPTH + 0.01), Vector3(SIZE.x, 0.04, 0.02), m["bronze"])
	b.box(Vector3(0, -0.005, DEPTH + 0.008), Vector3(SIZE.x - 0.04, 0.02, 0.016), steel)
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			b.cyl(Vector3(sx * (SIZE.x * 0.5 - 0.035), sy * (SIZE.y * 0.5 - 0.035), DEPTH + 0.01), 0.012, 0.02, m["bronze"], Vector3(90, 0, 0), -1.0, 8)
	# The keypad: a recessed plate, the code lamps, the display and the keys.
	b.box(Vector3(0, 0.28, DEPTH + 0.002), Vector3(0.6, 0.5, 0.01), dark)
	for i in OutpostLayout.HACK_DIGITS:
		var lx := -0.165 + i * 0.11
		b.cyl(Vector3(lx, 0.47, DEPTH + 0.01), 0.034, 0.02, steel, Vector3(90, 0, 0), -1.0, 12)
		var lm := StandardMaterial3D.new()
		lm.albedo_color = Color(0.05, 0.05, 0.05)
		lm.emission_enabled = true
		lm.emission_energy_multiplier = 0.7
		Models.cylinder(self, Vector3(lx, 0.47, DEPTH + 0.022), 0.025, 0.01, lm, Vector3(90, 0, 0), -1.0, 12)
		_code_lamps.append(lm)
	b.box(Vector3(-0.04, 0.37, DEPTH + 0.008), Vector3(0.36, 0.075, 0.01), m["dead_glass"])
	b.box(Vector3(-0.04, 0.37, DEPTH + 0.005), Vector3(0.39, 0.105, 0.008), m["gunmetal"])
	# The keys' bed, and the armoured conduit from the housing down into the wall.
	b.box(Vector3(-0.04, 0.27 - KEY_GAP.y * 1.5, DEPTH + 0.004), Vector3(KEY_GAP.x * 3.0 + 0.02, KEY_GAP.y * 4.0 + 0.02, 0.008), m["gunmetal"])
	b.cyl(Vector3(SIZE.x * 0.3, -SIZE.y * 0.5 - 0.17, 0.05), 0.024, 0.34, m["dark"], Vector3.ZERO, -1.0, 8)
	b.box(Vector3(SIZE.x * 0.3, -SIZE.y * 0.5 - 0.02, 0.05), Vector3(0.08, 0.05, 0.06), m["steel"])
	b.box(Vector3(SIZE.x * 0.3, -SIZE.y * 0.5 - 0.36, 0.025), Vector3(0.08, 0.06, 0.05), m["steel"])
	_display = Label3D.new()
	_display.font = GunPod.mono_font()
	_display.font_size = 40
	_display.pixel_size = 0.0016
	_display.outline_size = 0
	_display.modulate = DISPLAY_COLOR
	_display.position = Vector3(-0.04, 0.37, DEPTH + 0.015)
	add_child(_display)
	for i in OutpostLayout.HACK_TRIES:
		var tm := StandardMaterial3D.new()
		tm.albedo_color = Color(0.05, 0.05, 0.05)
		tm.emission_enabled = true
		tm.emission_energy_multiplier = 1.3
		Models.sphere(self, Vector3(0.22, 0.4 - i * 0.04, DEPTH + 0.012), 0.012, tm)
		_try_lamps.append(tm)
	_key_mat = StandardMaterial3D.new()
	_key_mat.albedo_color = Color(0.2, 0.21, 0.2)
	_key_mat.metallic = 0.5
	_key_mat.roughness = 0.5
	_key_hot = StandardMaterial3D.new()
	_key_hot.albedo_color = Color(0.3, 0.32, 0.25)
	_key_hot.emission_enabled = true
	_key_hot.emission = Color(0.9, 0.7, 0.3)
	_key_hot.emission_energy_multiplier = 0.6
	for r in KEYS.size():
		for c in 3:
			var label: String = KEYS[r][c]
			var centre := Vector2((c - 1) * KEY_GAP.x - 0.04, 0.27 - r * KEY_GAP.y)
			var key := MeshInstance3D.new()
			key.mesh = _key_mesh()
			key.material_override = _key_mat
			key.position = Vector3(centre.x, centre.y, DEPTH + 0.02)
			add_child(key)
			var l := Label3D.new()
			l.text = label
			l.font = GunPod.mono_font()
			l.font_size = 36
			l.pixel_size = 0.001
			l.outline_size = 0
			l.modulate = Color(0.78, 0.74, 0.62) if label.is_valid_int() else Color(0.85, 0.55, 0.28)
			l.position = Vector3(0, 0, KEY_DEPTH * 0.5 + 0.001)
			key.add_child(l)
			_keys.append({"label": label, "centre": centre, "node": key})
	# The wiring board behind the hatch: terminals, digits, colours and the tangled cords.
	b.box(Vector3(0, -0.29, DEPTH * 0.35), Vector3(SIZE.x - 0.08, 0.5, 0.01), m["gunmetal"])
	var digits: PackedInt32Array = d["digits"]
	var colors: PackedInt32Array = d["colors"]
	for i in OutpostLayout.HACK_CORDS:
		var y := ROW_TOP - i * ROW_STEP
		b.cyl(Vector3(-TERMINAL_X, y, DEPTH * 0.35 + 0.012), 0.016, 0.022, m["bronze"], Vector3(90, 0, 0), -1.0, 8)
		var dl := Label3D.new()
		dl.text = str(digits[i])
		dl.font = GunPod.mono_font()
		dl.font_size = 44
		dl.pixel_size = 0.0016
		dl.outline_size = 0
		dl.modulate = Color(0.95, 0.92, 0.8)
		dl.position = Vector3(-TERMINAL_X - 0.05, y, DEPTH * 0.35 + 0.008)
		add_child(dl)
		var col: Color = OutpostLayout.HACK_COLORS[colors[i]]
		b.cyl(Vector3(TERMINAL_X, y, DEPTH * 0.35 + 0.012), 0.016, 0.022, m["bronze"], Vector3(90, 0, 0), -1.0, 8)
		Models.box(self, Vector3(TERMINAL_X + 0.045, y, DEPTH * 0.35 + 0.012), Vector3(0.045, 0.045, 0.02), Models.emissive(col, 1.4, col * 0.5))
	var cord_mat := Models.mat(Color(0.13, 0.13, 0.12), 0.1, 0.45)
	var crng := RandomNumberGenerator.new()
	crng.seed = hash([Array(digits), Array(colors), Array(d["wires"] as PackedInt32Array)])
	var wires: PackedInt32Array = d["wires"]
	for i in OutpostLayout.HACK_CORDS:
		b.add(_cord_mesh(i, wires[i], crng), Transform3D.IDENTITY, cord_mat)
	b.commit(self, "Keypad")
	# The hatch over the board, hinged on its left edge.
	_hatch = Node3D.new()
	_hatch.position = Vector3(-SIZE.x * 0.5 + 0.03, -0.29, DEPTH + 0.012)
	add_child(_hatch)
	var hb := Models.Batch.new()
	hb.box(Vector3(SIZE.x * 0.5 - 0.03, 0, 0), Vector3(SIZE.x - 0.07, 0.5, 0.014), m["olive"])
	hb.box(Vector3(SIZE.x - 0.12, 0, 0.012), Vector3(0.03, 0.14, 0.02), m["steel"])
	hb.box(Vector3(SIZE.x * 0.5 - 0.03, 0.16, 0.009), Vector3(0.3, 0.05, 0.004), m["yellow"])
	for y: float in [-0.18, 0.18]:
		hb.cyl(Vector3(0, y, 0), 0.012, 0.08, steel, Vector3.ZERO, -1.0, 8)
	hb.commit(_hatch, "Hatch")
	var stencil := Label3D.new()
	stencil.text = "SERVICE"
	stencil.font_size = 30
	stencil.pixel_size = 0.0016
	stencil.outline_size = 0
	stencil.modulate = Color(0.08, 0.08, 0.06)
	stencil.position = Vector3(SIZE.x * 0.5 - 0.03, 0.16, 0.0125)
	_hatch.add_child(stencil)
	# The keys, stencilled along the bottom of the housing.
	var keys := Label3D.new()
	keys.text = "TRACE  THE  CORDS  -  KEY  THE  CODE      LMB/0-9 KEY   E LEAVE"
	keys.font = GunPod.mono_font()
	keys.font_size = 22
	keys.pixel_size = 0.0011
	keys.outline_size = 0
	keys.modulate = Color(0.9, 0.78, 0.4)
	keys.position = Vector3(0, -SIZE.y * 0.5 + 0.02, DEPTH + 0.012)
	add_child(keys)
	_inner_light = OmniLight3D.new()
	_inner_light.light_color = Color(0.95, 0.92, 0.85)
	_inner_light.light_energy = 0.0
	_inner_light.omni_range = 1.1
	_inner_light.position = Vector3(0, -0.2, 0.35)
	_inner_light.visible = false
	add_child(_inner_light)
	var area := Area3D.new()
	area.collision_layer = Game.LAYER_INTERACT
	area.collision_mask = 0
	area.monitoring = false
	area.set_meta("hack", di)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(SIZE.x, SIZE.y, 0.25)
	cs.shape = shape
	cs.position = Vector3(0, 0, DEPTH * 0.5 + 0.05)
	area.add_child(cs)
	add_child(area)


static func _key_mesh() -> BoxMesh:
	if _key_box == null:
		_key_box = BoxMesh.new()
		_key_box.size = Vector3(KEY_SIZE.x, KEY_SIZE.y, KEY_DEPTH)
	return _key_box


## One cord: from the digit terminal on row `left` to the colour terminal on row `right`, wandering
## up and down across the board on the way (and over or under the others), as a tube.
func _cord_mesh(left: int, right: int, rng: RandomNumberGenerator) -> ArrayMesh:
	var y0 := ROW_TOP - left * ROW_STEP
	var y1 := ROW_TOP - right * ROW_STEP
	var lo := ROW_TOP - (OutpostLayout.HACK_CORDS - 1) * ROW_STEP - 0.02
	var hi := ROW_TOP + 0.02
	var z0 := DEPTH * 0.35 + 0.02
	var pts: Array[Vector3] = [Vector3(-TERMINAL_X, y0, z0), Vector3(-TERMINAL_X + 0.05, y0, z0 + 0.004)]
	var xs := [-0.15, -0.05, 0.05, 0.15]
	for i in xs.size():
		var t := float(i + 1) / float(xs.size() + 1)
		var y := lerpf(y0, y1, t) + rng.randf_range(-0.16, 0.16)
		pts.append(Vector3(float(xs[i]) + rng.randf_range(-0.02, 0.02), clampf(y, lo, hi), z0 + rng.randf_range(0.006, 0.03)))
	pts.append(Vector3(TERMINAL_X - 0.05, y1, z0 + 0.004))
	pts.append(Vector3(TERMINAL_X, y1, z0))
	var samples: Array[Vector3] = []
	for i in pts.size() - 1:
		var p0 := pts[maxi(i - 1, 0)]
		var p1 := pts[i]
		var p2 := pts[i + 1]
		var p3 := pts[mini(i + 2, pts.size() - 1)]
		for s in 10:
			var t := s / 10.0
			var t2 := t * t
			var t3 := t2 * t
			samples.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	samples.append(pts[pts.size() - 1])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides := 6
	var rings: Array = []
	for i in samples.size():
		var tangent := (samples[mini(i + 1, samples.size() - 1)] - samples[maxi(i - 1, 0)]).normalized()
		var side := tangent.cross(Vector3(0, 0, 1)).normalized()
		var up := side.cross(tangent)
		var ring: Array = []
		for k in sides:
			var a := TAU * k / sides
			var nrm := side * cos(a) + up * sin(a)
			ring.append([samples[i] + nrm * CORD_R, nrm])
		rings.append(ring)
	for i in rings.size() - 1:
		for k in sides:
			var a: Array = rings[i][k]
			var e: Array = rings[i][(k + 1) % sides]
			var c: Array = rings[i + 1][k]
			var f: Array = rings[i + 1][(k + 1) % sides]
			for v: Array in [a, c, e, e, c, f]:
				st.set_normal(v[1])
				st.add_vertex(v[0])
	st.index()
	return st.commit()


# --- Using it ----------------------------------------------------------------------------------

## The camera for a close look at the panel (global).
## The space in front of the panel (panel-local) that must stay clear of the station's fittings: the
## panel's face and a margin round it, out to where the close look's view is (VIEW_AT).
static func clear_box() -> AABB:
	var margin := 0.05
	return AABB(Vector3(-SIZE.x * 0.5 - margin, -SIZE.y * 0.5 - margin, 0.008), Vector3(SIZE.x + margin * 2.0, SIZE.y + margin * 2.0, VIEW_AT.z + 0.15))


func view_transform() -> Transform3D:
	var eye := to_global(VIEW_AT)
	return Transform3D(Basis.looking_at(to_global(Vector3(0, -0.01, 0)) - eye, global_basis.y), eye)


func enter() -> void:
	active = true
	typed = ""
	_waiting = 0.0
	Sfx.play("hatch_open", global_position, -6.0)


func leave() -> void:
	active = false
	typed = ""
	hover("")


## The key a ray (global) points at, or "".
func key_at(from: Vector3, dir: Vector3) -> String:
	var inv := global_transform.affine_inverse()
	var o := inv * from
	var v := inv.basis * dir
	if absf(v.z) < 0.0001:
		return ""
	var t := (DEPTH + 0.022 - o.z) / v.z
	if t <= 0.0:
		return ""
	var p := o + v * t
	for k: Dictionary in _keys:
		var c: Vector2 = k["centre"]
		if absf(p.x - c.x) < KEY_SIZE.x * 0.5 + 0.008 and absf(p.y - c.y) < KEY_SIZE.y * 0.5 + 0.008:
			return k["label"]
	return ""


func hover(label: String) -> void:
	if label == _hover:
		return
	_hover = label
	for k: Dictionary in _keys:
		(k["node"] as MeshInstance3D).material_override = _key_hot if k["label"] == label else _key_mat


## Press a key: returns the code to send once four digits are in, else "".
func press(label: String) -> String:
	if _waiting > 0.0 or _state != Derelict.DOOR_CLOSED or label == "":
		return ""
	for k: Dictionary in _keys:
		if k["label"] == label:
			var node: MeshInstance3D = k["node"]
			var tw := create_tween()
			tw.tween_property(node, "position:z", DEPTH + 0.004, 0.04)
			tw.tween_property(node, "position:z", DEPTH + 0.012, 0.08)
	Sfx.play("switch", global_position, -8.0, 1.2)
	match label:
		"C":
			typed = ""
		"<":
			typed = typed.substr(0, maxi(typed.length() - 1, 0))
		_:
			typed += label
	if typed.length() >= OutpostLayout.HACK_DIGITS:
		var code := typed
		_waiting = 2.0
		return code
	return ""


## The server's verdict on a code (on every peer, see Derelict.on_event).
func result(kind: String) -> void:
	_waiting = 0.0
	typed = ""
	match kind:
		"hack_bad":
			_flash("DENIED", Color(1.0, 0.25, 0.15), 1.2)
			Sfx.play("deny", global_position, -2.0)
		"hack_ok":
			_flash("GRANTED", Color(0.4, 1.0, 0.5), 1.6)
			Sfx.play("buy", global_position, -4.0, 0.8)
		"lockdown":
			_flash("LOCKDOWN", Color(1.0, 0.15, 0.1), 3.0)


func _flash(text: String, col: Color, time: float) -> void:
	_flash_text = text
	_flash_col = col
	_flash_t = time


## The lock's replicated state (Derelict, every frame): the lamps and the display.
func show_state(state: int, tries: int, now: float) -> void:
	_state = state
	_tries = tries
	var dt := get_process_delta_time()
	_waiting = maxf(0.0, _waiting - dt)
	_flash_t = maxf(0.0, _flash_t - dt)
	_hatch_t = move_toward(_hatch_t, 1.0 if active else 0.0, dt / HATCH_TIME)
	_hatch.rotation.y = -smoothstep(0.0, 1.0, _hatch_t) * deg_to_rad(105.0)
	_inner_light.visible = _hatch_t > 0.05
	_inner_light.light_energy = 0.5 * _hatch_t
	var lights: PackedInt32Array = _d["lights"]
	for i in _code_lamps.size():
		var lm := _code_lamps[i]
		if state == Derelict.DOOR_CLOSED:
			lm.emission = OutpostLayout.HACK_COLORS[lights[i]]
		elif state == Derelict.DOOR_OPEN:
			lm.emission = Color(0.1, 0.5, 0.15)
		else:
			lm.emission = Color(0.6, 0.03, 0.02) * float(fposmod(now * 2.0, 1.0) < 0.5)
	for i in _try_lamps.size():
		_try_lamps[i].emission = Color(0.9, 0.12, 0.05) if i < tries else Color(0.3, 0.7, 0.2)
	var text := ""
	var col := DISPLAY_COLOR
	if _flash_t > 0.0 and fposmod(_flash_t * 4.0, 1.0) < 0.75:
		text = _flash_text
		col = _flash_col
	elif state == Derelict.DOOR_OPEN:
		text = "OPEN"
	elif state == Derelict.DOOR_LOCKDOWN:
		text = "LOCKDOWN" if fposmod(now * 2.0, 1.0) < 0.6 else ""
		col = Color(1.0, 0.15, 0.1)
	elif _waiting > 0.0:
		text = "...."
	elif active:
		text = ""
		for i in OutpostLayout.HACK_DIGITS:
			text += (typed[i] if i < typed.length() else "_") + (" " if i < OutpostLayout.HACK_DIGITS - 1 else "")
	else:
		text = "LOCKED"
		col = Color(1.0, 0.7, 0.3)
	_display.text = text
	_display.modulate = col
