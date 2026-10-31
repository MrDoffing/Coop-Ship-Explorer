class_name Scanner
extends Node3D
## The echolocation scanner on a crew member's suit. Holding Q swings it up on its bracket in front
## of the chest (the hand weapon goes down meanwhile, so it can't be fired): a rugged box with a
## round green screen that pings like a boat's radar. A beam sweeps round the screen (the top is
## the way the crew member faces) and paints the walls the ping bounces off as it passes: a clean
## outline of the rooms and corridors around, out to RANGE metres. Aliens show as orange blobs and
## the rest of the crew as blue rings, where they are right now; each flares as the beam passes it.
##
## A clear picture: every echo is where the wall is (no scatter, nothing missed, no specks of
## clutter) and stays at full strength until the beam comes round that way again and paints it
## afresh (only what it has just painted glows brighter). The ping goes through walls: it maps every
## wall within range, not only the ones in plain view (up to WALL_LAYERS of them along each ray). It
## pings at PING_HEIGHT, over the furniture and under the doorways, so what it maps is the walls.
## Aboard the ship its hull drowns the echoes: the screen shows only static (HULL INTERFERENCE); it
## works out in the stations.
##
## Built in the camera's frame by the crew member's own view (CrewMember); the display is drawn in
## 2D into a small viewport (Screen) shown on the device's screen, updated only while it is up. What
## the screen draws costs little: the echoes are kept per bearing (only the newest ray's), and all of
## them go to the screen in one batched line drawing.

## How far it reaches (m), seconds per sweep, rays per sweep, and how high above the floor it pings.
const RANGE := 32.0
const PERIOD := 2.0
const BINS := 180
const PING_HEIGHT := 2.0
## Seconds to swing up (and down).
const RAISE_TIME := 0.3
## How many walls one ray of the ping goes on through, and how far past each wall it starts again.
const WALL_LAYERS := 6
const WALL_STEP := 0.05
## What the beam has just painted glows brighter for FRESH seconds; an alien or crewmate it passes
## flares, fading over FLARE seconds.
const FRESH := 0.35
const FLARE := 0.45
## Two neighbouring rays' echoes off the same wall are joined into a line: they face the same way
## (the cosine between their normals over JOIN_FACING), lie in one plane (within JOIN_PLANE m) and
## are at most JOIN_GAP m apart, or JOIN_SPREAD times the rays' spacing out there. So walls draw as
## lines and a doorway stays a gap.
const JOIN_FACING := 0.95
const JOIN_PLANE := 0.12
const JOIN_GAP := 0.8
const JOIN_SPREAD := 2.5
## Ink: the phosphor, the aliens' blips and the crew's.
const INK := Color(0.35, 1.0, 0.45)
const ALIEN_INK := Color(1.0, 0.6, 0.22)
const CREW_INK := Color(0.35, 0.62, 1.0)
## The screen's dark ground.
const GROUND := Color(0.012, 0.035, 0.02)
## What the ping bounces off.
const MASK := Game.LAYER_INTERIOR | Game.LAYER_STATION | Game.LAYER_CAVE
## Where the device is when up and when stowed (camera frame): position and rotation, and its size.
const UP_POS := Vector3(0.0, -0.088, -0.3)
const UP_ROT := Vector3(-0.27, 0.0, 0.0)
const DOWN_POS := Vector3(0.07, -0.42, -0.2)
const DOWN_ROT := Vector3(-1.2, 0.25, 0.5)
const DEVICE_SCALE := 1.2
const SCREEN_PX := 320

## The green screen: the viewport's picture, slightly bulged, glowing, with scanlines and a dark
## rim, round.
const SCREEN_SHADER := """
shader_type spatial;
render_mode unshaded, shadows_disabled;
uniform sampler2D picture : source_color, filter_linear;
instance uniform float power = 1.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	vec2 uv = 0.5 + p * (0.93 + 0.07 * r * r) * 0.5;
	vec3 c = texture(picture, uv).rgb;
	vec3 g = texture(picture, uv + vec2(0.007, 0.0)).rgb + texture(picture, uv - vec2(0.007, 0.0)).rgb
		+ texture(picture, uv + vec2(0.0, 0.007)).rgb + texture(picture, uv - vec2(0.0, 0.007)).rgb;
	c += g * 0.15;
	float scan = 0.84 + 0.16 * sin(UV.y * 430.0);
	float vig = 1.0 - smoothstep(0.78, 1.0, r);
	ALBEDO = c * scan * (0.25 + 0.75 * vig) * 1.5 * power;
	ALPHA = 1.0 - smoothstep(0.97, 1.0, r);
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
"""


## The scanner's display, drawn in 2D in three layers over each other: the back (the screen's
## ground, the range rings with their distances) and the front (whatever lies beyond the rim covered,
## the rim, the crew member's own mark in the middle and the captions), each drawn once, and between
## them the picture, drawn every frame: the beam, the walls it painted (the freshest brighter) and
## the aliens and the crew where they are, or static aboard. A circle, an arc or a line with a width
## is a polygon of its own here, built afresh each time it is drawn, which is dear every frame; so
## the picture draws the walls as hairlines (one drawing for all of them) and the blips as round dots
## (textured squares, drawn together).
class Screen extends Node2D:
	enum { BACK, PICTURE, FRONT }
	var scanner: Scanner
	var font: Font
	var layer := PICTURE

	func _draw() -> void:
		var s := scanner
		if s == null:
			return
		var t0 := Time.get_ticks_usec()
		var size := float(Scanner.SCREEN_PX)
		var c := Vector2(size, size) * 0.5
		var r := size * 0.455
		var k := size / 256.0
		match layer:
			BACK:
				_draw_back(c, r, k, size)
			FRONT:
				_draw_front(c, r, k, size)
			_:
				_draw_picture(s, c, r, k, size)
				s.draw_us = float(Time.get_ticks_usec() - t0)

	## The ground, the range rings every quarter of the range with their distances, and the cross.
	func _draw_back(c: Vector2, r: float, k: float, size: float) -> void:
		var ink := Scanner.INK
		draw_rect(Rect2(Vector2.ZERO, Vector2(size, size)), Scanner.GROUND)
		for i in 3:
			var rr := r * float(i + 1) / 4.0
			draw_arc(c, rr, 0.0, TAU, 72, Color(ink, 0.16), 1.2 * k, true)
			_text(c + Vector2(0.0, -rr + 9.0 * k), "%d" % int(Scanner.RANGE * float(i + 1) / 4.0), int(10 * k), Color(ink, 0.35))
		draw_line(c - Vector2(r, 0), c + Vector2(r, 0), Color(ink, 0.07), 1.0)
		draw_line(c - Vector2(0, r), c + Vector2(0, r), Color(ink, 0.07), 1.0)

	## The beam, the walls, the blips (or the static aboard).
	func _draw_picture(s: Scanner, c: Vector2, r: float, k: float, size: float) -> void:
		var ink := Scanner.INK
		if s.interference:
			draw_rect(Rect2(Vector2.ZERO, Vector2(size, size)), Scanner.GROUND)
			for i in 140:
				var p := c + Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * r
				if p.distance_to(c) < r:
					draw_rect(Rect2(p, Vector2(randf_range(1.0, 3.0), 1.0) * k), Color(ink, randf_range(0.05, 0.4)))
			_text(Vector2(c.x, c.y - 6.0 * k), "HULL", int(15 * k), Color(ink, 0.8))
			_text(Vector2(c.x, c.y + 12.0 * k), "INTERFERENCE", int(15 * k), Color(ink, 0.8))
			_text(Vector2(c.x, size - 6.0 * k), "NO RETURN", int(13 * k), Color(ink, 0.6))
			return
		# The beam and the glow trailing behind it.
		var pts := PackedVector2Array([c])
		var cols := PackedColorArray([Color(ink, 0.22)])
		for i in 17:
			var a := s.sweep - 0.6 * float(i) / 16.0
			pts.append(c + Vector2(sin(a), -cos(a)) * r)
			cols.append(Color(ink, 0.18 * (1.0 - float(i) / 16.0)))
		draw_polygon(pts, cols)
		draw_line(c, c + Vector2(sin(s.sweep), -cos(s.sweep)) * r, Color(ink, 0.85), 2.0 * k)
		# The walls: every bearing's echoes in one drawing, what was just painted in a second, brighter.
		var xf := s.display_xform(c, r / Scanner.RANGE)
		var settled := PackedVector2Array()
		var fresh := PackedVector2Array()
		for b in Scanner.BINS:
			var lines: PackedVector2Array = s._bin_lines[b]
			if lines.is_empty():
				continue
			if s.clock - s._bin_time[b] < Scanner.FRESH:
				fresh.append_array(lines)
			else:
				settled.append_array(lines)
		_lines(settled, xf, Color(ink, 0.9))
		_lines(fresh, xf, Color(ink.lightened(0.55), 1.0))
		# The aliens and the rest of the crew, where they are.
		for e: Array in s.blips():
			var p := xf * (e[1] as Vector2)
			var flare := s.flare_of(int(e[3]))
			if int(e[0]) == 1:
				var crew_ink := Scanner.CREW_INK
				_dot(Scanner.dot_texture(0), p, (9.0 + 4.0 * flare) * k, Color(crew_ink, 0.3 + 0.35 * flare))
				_dot(Scanner.dot_texture(2), p, 7.5 * k, crew_ink)
				_dot(Scanner.dot_texture(1), p, 2.8 * k, crew_ink.lightened(0.3))
			else:
				var size_px := (3.5 + float(e[2]) * 3.0) * k
				var alien_ink := Scanner.ALIEN_INK
				_dot(Scanner.dot_texture(0), p, size_px * (2.0 + flare), Color(alien_ink, 0.45 + 0.4 * flare))
				_dot(Scanner.dot_texture(1), p, size_px, alien_ink.lightened(0.45 * flare))

	## Over the picture: whatever lies beyond the rim (echoes painted before the crew member moved on)
	## covered, the rim, the crew member's own mark and the captions.
	func _draw_front(c: Vector2, r: float, k: float, size: float) -> void:
		var ink := Scanner.INK
		draw_arc(c, r + size * 0.2, 0.0, TAU, 72, Scanner.GROUND, size * 0.4 - 2.0, false)
		draw_arc(c, r, 0.0, TAU, 72, Color(ink, 0.4), 1.2 * k, true)
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -6) * k, c + Vector2(4.5, 4) * k, c + Vector2(-4.5, 4) * k]), Color(ink, 0.95))
		_text(Vector2(c.x, size - 6.0 * k), "%d M" % int(Scanner.RANGE), int(13 * k), Color(ink, 0.6))
		_text(Vector2(26.0 * k, 18.0 * k), "ECHO", int(13 * k), Color(ink, 0.6))

	## Lines (pairs of ship-local points, put on the screen by `xf`) about two pixels thick: hairlines
	## (all of them one drawing), three times a pixel apart.
	func _lines(points: PackedVector2Array, xf: Transform2D, col: Color) -> void:
		if points.is_empty():
			return
		for off: Vector2 in [Vector2.ZERO, Vector2(1, 0), Vector2(0, 1)]:
			draw_set_transform_matrix(Transform2D(0.0, off) * xf)
			draw_multiline(points, col)
		draw_set_transform_matrix(Transform2D.IDENTITY)

	## A round dot `radius` pixels across at `p`.
	func _dot(tex: Texture2D, p: Vector2, radius: float, col: Color) -> void:
		draw_texture_rect(tex, Rect2(p - Vector2(radius, radius), Vector2(radius, radius) * 2.0), false, col)

	func _text(at: Vector2, text: String, font_size: int, col: Color) -> void:
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_string(font, Vector2(at.x - w * 0.5, at.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, col)


## The blips' dots (see dot_texture()).
static var _dots: Array[Texture2D] = []

## The crew member wearing it.
var crew: CrewMember
## 0 stowed .. 1 up in front of the face.
var raise := 0.0
## The beam's angle on the screen (radians, clockwise from the top) and the scanner's clock.
var sweep := 0.0
var clock := 0.0
## Aboard the ship: nothing but static.
var interference := false
## How long the screen's last drawing took (microseconds; for the tests).
var draw_us := 0.0
var _device: Node3D
var _vp: SubViewport
var _screen: Screen
## The screen's back and front layers (drawn once; hidden while it shows static).
var _frame: Array[Screen] = []
var _screen_mesh: MeshInstance3D
var _lamp: StandardMaterial3D
var _status: Label3D
var _static: AudioStreamPlayer
var _lamp_t := 0.0
## The wall echoes per bearing on the screen (BINS of them): the lines the last ray that way painted
## (pairs of ship-local x/z points), and when.
var _bin_lines: Array[PackedVector2Array] = []
var _bin_time := PackedFloat32Array()
## The abandoned station the echoes were painted in (another one, or none: they are wiped).
var _painted_k := -1
## The last ray's echoes, [point, normal] (x/z) each, to join the next ray's to.
var _last_hits: Array = []
## When the beam last passed each alien or crewmate (instance id -> clock).
var _swept: Dictionary = {}


func build(c: CrewMember) -> void:
	crew = c
	_device = Node3D.new()
	_device.name = "Device"
	_device.scale = Vector3.ONE * DEVICE_SCALE
	add_child(_device)
	_build_device()
	_vp = SubViewport.new()
	_vp.size = Vector2i(SCREEN_PX, SCREEN_PX)
	_vp.disable_3d = true
	_vp.transparent_bg = false
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_vp)
	for layer: int in [Screen.BACK, Screen.PICTURE, Screen.FRONT]:
		var s := Screen.new()
		s.scanner = self
		s.font = GunPod.mono_font()
		s.layer = layer
		_vp.add_child(s)
		if layer == Screen.PICTURE:
			_screen = s
		else:
			_frame.append(s)
	var m := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SCREEN_SHADER
	m.shader = sh
	m.set_shader_parameter("picture", _vp.get_texture())
	_screen_mesh.material_override = m
	_static = AudioStreamPlayer.new()
	_static.stream = Sfx.stream("scan_static")
	_static.volume_db = -26.0
	add_child(_static)
	for n in find_children("*", "GeometryInstance3D", true, false):
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bin_lines.resize(BINS)
	_bin_time.resize(BINS)
	visible = false


## The box: olive steel with a bolted bezel round the round screen, the emitter on top, knobs on the
## side, a lamp that flashes with every ping, its name plate and the bracket below.
func _build_device() -> void:
	var olive := Models.panel_mat(Color(0.25, 0.27, 0.2), 0.35, 0.7, 7.0)
	var dark := Models.mat(Color(0.1, 0.105, 0.11), 0.6, 0.45)
	var steel := Models.mat(Color(0.35, 0.36, 0.36), 0.8, 0.35)
	Models.box(_device, Vector3(0, 0, -0.0225), Vector3(0.17, 0.15, 0.045), olive)
	Models.box(_device, Vector3(0, -0.071, -0.02), Vector3(0.172, 0.01, 0.047), dark)
	Models.cylinder(_device, Vector3(0, 0.0, 0.002), 0.05, 0.008, dark, Vector3(90, 0, 0), -1.0, 28)
	_screen_mesh = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.088, 0.088)
	_screen_mesh.mesh = q
	_screen_mesh.position = Vector3(0, 0.0, 0.0065)
	_device.add_child(_screen_mesh)
	for x: float in [-0.074, 0.074]:
		for y: float in [-0.058, 0.064]:
			Models.cylinder(_device, Vector3(x, y, 0.001), 0.0035, 0.004, steel, Vector3(90, 0, 0), -1.0, 6)
	Models.cylinder(_device, Vector3(0.05, 0.085, -0.022), 0.016, 0.026, dark)
	Models.cylinder(_device, Vector3(0.05, 0.103, -0.022), 0.012, 0.012, steel, Vector3.ZERO, 0.03)
	for y: float in [0.025, -0.01]:
		Models.cylinder(_device, Vector3(0.091, y, -0.02), 0.009, 0.012, dark, Vector3(0, 0, 90))
	Models.box(_device, Vector3(0, -0.097, -0.03), Vector3(0.03, 0.05, 0.02), dark)
	Models.strut(_device, Vector3(0, -0.117, -0.03), Vector3(0.03, -0.31, 0.08), 0.012, steel)
	_lamp = StandardMaterial3D.new()
	_lamp.albedo_color = Color(0.05, 0.1, 0.05)
	_lamp.emission_enabled = true
	_lamp.emission = Color(0.4, 1.0, 0.45)
	_lamp.emission_energy_multiplier = 0.3
	Models.sphere(_device, Vector3(-0.06, 0.063, 0.002), 0.0045, _lamp, Vector3.ONE, 8)
	var plate := Label3D.new()
	plate.font = GunPod.mono_font()
	plate.font_size = 32
	plate.pixel_size = 0.00017
	plate.text = "ECHO-SCAN MK II"
	plate.modulate = Color(0.85, 0.82, 0.7)
	plate.outline_size = 0
	plate.double_sided = false
	plate.position = Vector3(0.006, 0.0625, 0.001)
	_device.add_child(plate)
	_status = Label3D.new()
	_status.font = GunPod.mono_font()
	_status.font_size = 32
	_status.pixel_size = 0.00016
	_status.modulate = GunPod.GREEN
	_status.outline_size = 0
	_status.double_sided = false
	_status.position = Vector3(0.0, -0.0585, 0.001)
	_device.add_child(_status)


## Ship-local x/z -> the screen's pixels: centred on `c`, `px` pixels a metre, the top the way the
## crew member faces.
func display_xform(c: Vector2, px: float) -> Transform2D:
	var xf := Transform2D(crew.look_yaw, Vector2(px, px), 0.0, Vector2.ZERO)
	xf.origin = c - xf.basis_xform(Vector2(crew.position.x, crew.position.z))
	return xf


## Swing up while `held`, sweep and paint while up (or show static aboard).
func update(delta: float, held: bool) -> void:
	if crew == null or crew.ship == null or not is_instance_valid(crew.ship):
		return
	clock += delta
	var was := raise
	raise = move_toward(raise, 1.0 if held else 0.0, delta / RAISE_TIME)
	if was == 0.0 and raise > 0.0:
		Sfx.play("scan_whirr", null, -15.0, 1.1)
	elif was == 1.0 and raise < 1.0:
		Sfx.play("scan_whirr", null, -17.0, 0.9)
	visible = raise > 0.0
	var e := smoothstep(0.0, 1.0, raise)
	_device.position = DOWN_POS.lerp(UP_POS, e)
	_device.rotation = DOWN_ROT.lerp(UP_ROT, e)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if visible else SubViewport.UPDATE_DISABLED
	interference = crew.ship.is_aboard(crew.position)
	for s in _frame:
		s.visible = not interference
	if crew.ship.derelict_k != _painted_k:
		_painted_k = crew.ship.derelict_k
		_wipe()
	var on := raise >= 0.6 and crew.alive
	var hiss := visible and interference
	if hiss != _static.playing:
		if hiss:
			_static.play()
		else:
			_static.stop()
	if on and not interference:
		_scan(delta)
	elif not on:
		_last_hits.clear()
	_lamp_t = maxf(0.0, _lamp_t - delta * 3.0)
	_lamp.emission_energy_multiplier = 0.3 + 3.0 * _lamp_t
	CrewWeapons.set_text(_status, "NO RETURN" if interference else "RNG %d M  SWEEP %.0f S" % [int(RANGE), PERIOD])
	if visible:
		_screen.queue_redraw()


## Forget every echo (a new station).
func _wipe() -> void:
	for b in BINS:
		_bin_lines[b] = PackedVector2Array()
	_last_hits.clear()
	_swept.clear()


## The beam moves on, painting the bearings it passes. A ping sounds as it passes the top.
func _scan(delta: float) -> void:
	var step := TAU / BINS
	var from := sweep
	sweep += TAU * delta / PERIOD
	var b0 := int(floor(from / step))
	var b1 := int(floor(sweep / step))
	for b in range(b0 + 1, b1 + 1):
		_paint(posmod(b, BINS))
	if sweep >= TAU:
		sweep -= TAU
		_lamp_t = 1.0
		Sfx.play("scan_ping", null, -17.0)


## Paint bearing `bin`: a ray goes out that way, on through every wall it meets (up to WALL_LAYERS),
## and each echo is joined to the last ray's echo off the same wall. Aliens and crewmates in the
## slice flare (an alien's echo blips).
func _paint(bin: int) -> void:
	var width := TAU / BINS
	var a := float(bin) * width
	var ship := crew.ship
	var space := get_world_3d().direct_space_state
	var yaw := crew.look_yaw
	var fwd := Vector2(-sin(yaw), -cos(yaw))
	var right := Vector2(cos(yaw), -sin(yaw))
	var dir := right * sin(a) + fwd * cos(a)
	var me := Vector2(crew.position.x, crew.position.z)
	var origin := crew.position + Vector3(0, PING_HEIGHT, 0)
	var dir3 := Vector3(dir.x, 0, dir.y)
	var to := ship.to_global(origin + dir3 * RANGE)
	var step := ship.global_basis * dir3 * WALL_STEP
	var from := ship.to_global(origin)
	var inv := ship.global_basis.inverse()
	var lines := PackedVector2Array()
	var hits: Array = []
	for layer in WALL_LAYERS:
		var q := PhysicsRayQueryParameters3D.create(from, to, MASK)
		q.exclude = [crew.get_rid()]
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			break
		var at: Vector3 = hit["position"]
		# (A ray that starts just inside a wall passes out of it without a hit, on to the next.)
		from = at + step
		var n3: Vector3 = inv * (hit["normal"] as Vector3)
		var n := Vector2(n3.x, n3.z)
		if n.length_squared() < 0.25:
			# A floor, a ceiling or a slope: not a wall.
			continue
		n = n.normalized()
		var local := ship.to_local(at)
		var p := Vector2(local.x, local.z)
		var reach := maxf(JOIN_GAP, JOIN_SPREAD * me.distance_to(p) * width)
		for prev: Array in _last_hits:
			var pp: Vector2 = prev[0]
			if (prev[1] as Vector2).dot(n) > JOIN_FACING and absf((p - pp).dot(n)) < JOIN_PLANE and pp.distance_to(p) < reach:
				lines.append(pp)
				lines.append(p)
				break
		hits.append([p, n])
	_last_hits = hits
	_bin_lines[bin] = lines
	_bin_time[bin] = clock
	for e: Array in blips():
		var disp := (e[1] as Vector2) - me
		var bearing := fposmod(atan2(disp.dot(right), disp.dot(fwd)), TAU)
		if absf(angle_difference(bearing, a)) <= width * 0.5:
			_swept[int(e[3])] = clock
			if int(e[0]) == 0:
				var k := disp.length() / RANGE
				Sfx.play("scan_blip", null, -24.0 + (1.0 - k) * 6.0, lerpf(1.25, 0.95, k))


## What shows as blips right now, within range: [kind (0 an alien, 1 a crewmate), where (ship-local
## x/z), size (m), instance id] each. The crew's suits answer the ping, so crewmates always show.
func blips() -> Array:
	var out: Array = []
	var ship := crew.ship
	var me := Vector2(crew.position.x, crew.position.z)
	for n in ship.boarder_root.get_children():
		var bd := n as Boarder
		if bd and bd.hp > 0.0 and not bd.is_queued_for_deletion():
			var p := Vector2(bd.position.x, bd.position.z)
			if p.distance_to(me) < RANGE:
				out.append([0, p, clampf(bd.stat("radius") * 2.0, 0.4, 1.2), bd.get_instance_id()])
	for n in ship.crew_root.get_children():
		var cm := n as CrewMember
		if cm and cm != crew and cm.alive:
			var p := Vector2(cm.position.x, cm.position.z)
			if p.distance_to(me) < RANGE:
				out.append([1, p, 1.0, cm.get_instance_id()])
	return out


## How strongly a blip flares (1 as the beam passes it, fading over FLARE seconds).
func flare_of(id: int) -> float:
	return clampf(1.0 - (clock - float(_swept.get(id, -100.0))) / FLARE, 0.0, 1.0)


## A round dot for the blips, white (tinted when drawn), 64 pixels across: 0 a soft glow, 1 a disc
## with a crisp edge, 2 a ring.
static func dot_texture(kind: int) -> Texture2D:
	if _dots.is_empty():
		var clear := Color(1, 1, 1, 0)
		var white := Color(1, 1, 1, 1)
		for stops: Array in [[[0.0, 1.0], [white, clear]], [[0.0, 0.78, 0.94], [white, white, clear]],
				[[0.0, 0.62, 0.7, 0.84, 0.92], [clear, clear, white, white, clear]]]:
			var g := Gradient.new()
			g.offsets = PackedFloat32Array(stops[0])
			g.colors = PackedColorArray(stops[1])
			var t := GradientTexture2D.new()
			t.gradient = g
			t.fill = GradientTexture2D.FILL_RADIAL
			t.fill_from = Vector2(0.5, 0.5)
			t.fill_to = Vector2(1.0, 0.5)
			t.width = 64
			t.height = 64
			_dots.append(t)
	return _dots[kind]


## Every wall echo on the screen now (ship-local x/z; the end of each line; for the tests).
func wall_points() -> PackedVector2Array:
	var out := PackedVector2Array()
	for lines in _bin_lines:
		for i in range(1, lines.size(), 2):
			out.append(lines[i])
	return out


## How many echoes it holds right now (for the tests).
func echo_text() -> String:
	var segs := 0
	for lines in _bin_lines:
		segs += lines.size() / 2
	return "%d wall lines, %d blips" % [segs, blips().size()]
