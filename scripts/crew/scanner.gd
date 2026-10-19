class_name Scanner
extends Node3D
## The echolocation scanner on a crew member's suit. Holding Q swings it up on its bracket in front
## of the chest (the hand weapon goes down meanwhile, so it can't be fired): a rugged box with a
## round green screen that pings like a boat's radar. A beam sweeps round the screen (the top is
## the way the crew member faces) and paints what the ping bounces off as it passes: a rough
## outline of the walls, aliens as bright blobs and the rest of the crew as rings. What it painted
## fades until the beam comes round again, and it only reaches RANGE metres.
##
## The further out, the rougher it gets: walls blur and break up, blips wander off where they are
## (more so behind a wall), some don't show at all, and false echoes and speckle creep in towards
## the edge. Aboard the ship its hull drowns the echoes: the screen shows only static (HULL
## INTERFERENCE); it works out in the stations.
##
## Built in the camera's frame by the crew member's own view (CrewMember); the display is drawn in
## 2D into a small viewport (Screen) shown on the device's screen, updated only while it is up.

## How far it reaches (m), seconds per sweep, rays per sweep, and how high above the floor it pings.
const RANGE := 22.0
const PERIOD := 2.0
const BINS := 120
const CHEST := 1.1
## How fast echoes fade (per second), and how long they are kept (sweeps).
const DECAY := 1.1
const KEEP := 2.2
## Seconds to swing up (and down).
const RAISE_TIME := 0.3
## The noise: wall echoes scatter by WALL_NOISE + WALL_NOISE_SQ * d^2 metres at d metres, and drop
## out with a chance of DROPOUT * (d / RANGE)^2.5; blips scatter by BLIP_NOISE + BLIP_NOISE_M * d
## (more behind a wall) and are missed with a chance of MISS * (d / RANGE)^2; a false echo turns up
## about GHOSTS times a sweep, in the outer half.
const WALL_NOISE := 0.04
const WALL_NOISE_SQ := 0.0028
const DROPOUT := 0.55
const BLIP_NOISE := 0.12
const BLIP_NOISE_M := 0.06
const MISS := 0.35
const GHOSTS := 0.9
## What the ping bounces off.
const MASK := Game.LAYER_INTERIOR | Game.LAYER_STATION | Game.LAYER_CAVE
## Where the device is when up and when stowed (camera frame): position and rotation.
const UP_POS := Vector3(0.0, -0.08, -0.29)
const UP_ROT := Vector3(-0.27, 0.0, 0.0)
const DOWN_POS := Vector3(0.07, -0.42, -0.2)
const DOWN_ROT := Vector3(-1.2, 0.25, 0.5)
const SCREEN_PX := 256

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


## The scanner's display, drawn in 2D: range rings, the sweeping beam, the echoes fading behind it,
## speckle, and the crew member in the middle.
class Screen extends Node2D:
	var scanner: Scanner
	var font: Font

	func _draw() -> void:
		var s := scanner
		if s == null:
			return
		var size := float(Scanner.SCREEN_PX)
		var c := Vector2(size, size) * 0.5
		var r := size * 0.455
		var ink := Color(0.35, 1.0, 0.45)
		draw_rect(Rect2(Vector2.ZERO, Vector2(size, size)), Color(0.012, 0.035, 0.02))
		for k: float in [1.0 / 3.0, 2.0 / 3.0, 1.0]:
			draw_arc(c, r * k, 0.0, TAU, 72, Color(ink, 0.22 if k < 1.0 else 0.4), 1.2, true)
		draw_line(c - Vector2(r, 0), c + Vector2(r, 0), Color(ink, 0.08), 1.0)
		draw_line(c - Vector2(0, r), c + Vector2(0, r), Color(ink, 0.08), 1.0)
		var now := s.clock
		if s.interference:
			for i in 260:
				var p := c + Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * r
				if p.distance_to(c) < r:
					draw_rect(Rect2(p, Vector2(randf_range(1.0, 3.0), 1.0)), Color(ink, randf_range(0.05, 0.4)))
			_text(Vector2(c.x, c.y - 6.0), "HULL", 15, Color(ink, 0.8))
			_text(Vector2(c.x, c.y + 12.0), "INTERFERENCE", 15, Color(ink, 0.8))
			_text(Vector2(c.x, size - 6.0), "NO RETURN", 13, Color(ink, 0.6))
			return
		# The beam and the glow trailing behind it.
		var pts := PackedVector2Array([c])
		var cols := PackedColorArray([Color(ink, 0.3)])
		for i in 17:
			var a := s.sweep - 0.75 * float(i) / 16.0
			pts.append(c + Vector2(sin(a), -cos(a)) * r)
			cols.append(Color(ink, 0.26 * (1.0 - float(i) / 16.0)))
		draw_polygon(pts, cols)
		draw_line(c, c + Vector2(sin(s.sweep), -cos(s.sweep)) * r, Color(ink, 0.85), 2.0, true)
		var px := r / Scanner.RANGE
		for e: Dictionary in s.walls:
			var alpha := exp(-(now - float(e["t"])) * Scanner.DECAY)
			var a_px := c + s.to_display(e["a"]) * px
			var b_px := c + s.to_display(e["b"]) * px
			if a_px.distance_to(c) > r + 2.0 and b_px.distance_to(c) > r + 2.0:
				continue
			var w := clampf(1.3 + float(e["w"]) * 5.0, 1.3, 5.0)
			var col := Color(ink, clampf(alpha * (1.1 - 0.06 * float(e["w"])), 0.0, 1.0))
			if a_px.distance_squared_to(b_px) < 1.0:
				draw_circle(a_px, w * 0.6, col)
			else:
				draw_line(a_px, b_px, col, w, true)
		for e: Dictionary in s.contacts:
			var alpha := exp(-(now - float(e["t"])) * Scanner.DECAY)
			var p := c + s.to_display(e["p"]) * px
			if p.distance_to(c) > r:
				continue
			match int(e["kind"]):
				1:
					draw_arc(p, 4.0, 0.0, TAU, 16, Color(0.75, 1.0, 0.9, alpha), 1.6, true)
				_:
					var size_px := 3.5 + float(e["size"]) * 3.0
					draw_circle(p, size_px * 1.9, Color(1.0, 0.6, 0.2, alpha * 0.22))
					draw_circle(p, size_px, Color(1.0, 0.72, 0.3, alpha))
		# Speckle, thicker towards the edge.
		for i in 70:
			var rr := r * pow(randf(), 0.35)
			var a := randf() * TAU
			var p := c + Vector2(sin(a), -cos(a)) * rr
			draw_rect(Rect2(p, Vector2(1.0, 1.0)), Color(ink, randf() * 0.35 * pow(rr / r, 2.0)))
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -6), c + Vector2(4.5, 4), c + Vector2(-4.5, 4)]), Color(ink, 0.9))
		_text(Vector2(c.x, size - 6.0), "%d M" % int(Scanner.RANGE), 13, Color(ink, 0.6))
		_text(Vector2(26.0, 18.0), "ECHO", 13, Color(ink, 0.6))

	func _text(at: Vector2, text: String, font_size: int, col: Color) -> void:
		var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_string(font, Vector2(at.x - w * 0.5, at.y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, col)


## The crew member wearing it.
var crew: CrewMember
## 0 stowed .. 1 up in front of the face.
var raise := 0.0
## The beam's angle on the screen (radians, clockwise from the top) and the scanner's clock.
var sweep := 0.0
var clock := 0.0
## Aboard the ship: nothing but static.
var interference := false
## The echoes: walls {"a", "b" (ship-local xz; the same point for a dot), "t" (when painted), "w"
## (how rough, m)} and blips {"p", "t", "kind" (0 alien, 1 crew, 2 false echo), "size"}.
var walls: Array[Dictionary] = []
var contacts: Array[Dictionary] = []
var _device: Node3D
var _vp: SubViewport
var _screen: Screen
var _screen_mesh: MeshInstance3D
var _lamp: StandardMaterial3D
var _status: Label3D
var _static: AudioStreamPlayer
var _lamp_t := 0.0
## The last wall echo painted (to join the next one to it).
var _last_hit := Vector2.ZERO
var _last_ok := false
var _last_d := 0.0


func build(c: CrewMember) -> void:
	crew = c
	_device = Node3D.new()
	_device.name = "Device"
	add_child(_device)
	_build_device()
	_vp = SubViewport.new()
	_vp.size = Vector2i(SCREEN_PX, SCREEN_PX)
	_vp.disable_3d = true
	_vp.transparent_bg = false
	_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_vp)
	_screen = Screen.new()
	_screen.scanner = self
	_screen.font = GunPod.mono_font()
	_vp.add_child(_screen)
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


## Ship-local point (xz) -> the screen's frame (m, x right, y down, the top the way the crew member
## faces), from where the crew member is now.
func to_display(p: Vector2) -> Vector2:
	var v := p - Vector2(crew.position.x, crew.position.z)
	var yaw := crew.look_yaw
	var fwd := Vector2(-sin(yaw), -cos(yaw))
	var right := Vector2(cos(yaw), -sin(yaw))
	return Vector2(v.dot(right), -v.dot(fwd))


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
		_last_ok = false
	_prune()
	_lamp_t = maxf(0.0, _lamp_t - delta * 3.0)
	_lamp.emission_energy_multiplier = 0.3 + 3.0 * _lamp_t
	CrewWeapons.set_text(_status, "NO RETURN" if interference else "RNG %d M  SWEEP %.0f S" % [int(RANGE), PERIOD])
	if visible:
		_screen.queue_redraw()


## The beam moves on, painting the bins it passes: a ray each for the walls, and whatever moves
## within the slice. A ping sounds as it passes the top.
func _scan(delta: float) -> void:
	var step := TAU / BINS
	var from := sweep
	sweep += TAU * delta / PERIOD
	var b0 := int(floor(from / step))
	var b1 := int(floor(sweep / step))
	for b in range(b0 + 1, b1 + 1):
		_paint(fposmod(b * step, TAU), step)
	if sweep >= TAU:
		sweep -= TAU
		_lamp_t = 1.0
		Sfx.play("scan_ping", null, -17.0)


## Paint one bin at screen angle `a` (`width` wide).
func _paint(a: float, width: float) -> void:
	var ship := crew.ship
	var space := get_world_3d().direct_space_state
	var yaw := crew.look_yaw
	var fwd := Vector2(-sin(yaw), -cos(yaw))
	var right := Vector2(cos(yaw), -sin(yaw))
	var dir := right * sin(a) + fwd * cos(a)
	var side := Vector2(-dir.y, dir.x)
	var me := Vector2(crew.position.x, crew.position.z)
	var origin := crew.position + Vector3(0, CHEST, 0)
	var q := PhysicsRayQueryParameters3D.create(ship.to_global(origin), ship.to_global(origin + Vector3(dir.x, 0, dir.y) * RANGE), MASK)
	q.exclude = [crew.get_rid()]
	var hit := space.intersect_ray(q)
	var ok := false
	if not hit.is_empty():
		var d := origin.distance_to(ship.to_local(hit["position"]))
		var k := d / RANGE
		if randf() >= DROPOUT * pow(k, 2.5):
			var sigma := WALL_NOISE + WALL_NOISE_SQ * d * d
			var p := me + dir * (d + randfn(0.0, sigma)) + side * randfn(0.0, sigma * 0.5)
			var joined := _last_ok and p.distance_to(_last_hit) < maxf(1.5, 0.35 * d) and absf(d - _last_d) < maxf(1.2, 0.3 * d)
			walls.append({"a": _last_hit if joined else p, "b": p, "t": clock, "w": sigma})
			_last_hit = p
			_last_d = d
			ok = true
	_last_ok = ok
	# Clutter: false wall echoes out towards the edge.
	if randf() < 0.05 * GHOSTS:
		var rr := RANGE * randf_range(0.5, 0.98)
		walls.append({"a": me + dir * rr, "b": me + dir * rr, "t": clock, "w": 1.5})
	if randf() < GHOSTS / BINS:
		contacts.append({"p": me + dir * RANGE * randf_range(0.55, 0.98), "t": clock, "kind": 2, "size": 0.6})
	# Whatever moves in this slice: aliens and the rest of the crew.
	for n in ship.boarder_root.get_children():
		var bd := n as Boarder
		if bd and bd.hp > 0.0 and not bd.is_queued_for_deletion():
			_blip(bd.position, bd.stat("height") * 0.5, 0, clampf(bd.stat("radius") * 2.0, 0.4, 1.2), a, width, space)
	for n in ship.crew_root.get_children():
		var cm := n as CrewMember
		if cm and cm != crew and cm.alive:
			_blip(cm.position, CHEST, 1, 1.0, a, width, space)


## A blip for something at ship-local `pos` if it is within RANGE and in the slice the beam just
## passed (centred on screen angle `a`).
func _blip(pos: Vector3, up: float, kind: int, size: float, a: float, width: float, space: PhysicsDirectSpaceState3D) -> void:
	var flat := Vector2(pos.x, pos.z)
	var disp := to_display(flat)
	var d := disp.length()
	if d > RANGE or d < 0.3:
		return
	var ang := fposmod(atan2(disp.x, -disp.y), TAU)
	var off := absf(angle_difference(ang, a))
	if off > width * 0.5:
		return
	var ship := crew.ship
	var q := PhysicsRayQueryParameters3D.create(ship.to_global(crew.position + Vector3(0, CHEST, 0)), ship.to_global(pos + Vector3(0, up, 0)), MASK)
	q.exclude = [crew.get_rid()]
	var hidden := not space.intersect_ray(q).is_empty()
	var k := d / RANGE
	if randf() < MISS * k * k * (1.6 if hidden else 1.0):
		return
	var sigma := (BLIP_NOISE + BLIP_NOISE_M * d) * (1.8 if hidden else 1.0)
	contacts.append({"p": flat + Vector2(randfn(0.0, sigma), randfn(0.0, sigma)), "t": clock, "kind": kind, "size": size})
	if kind == 0:
		Sfx.play("scan_blip", null, -24.0 + (1.0 - k) * 6.0, lerpf(1.25, 0.95, k))


func _prune() -> void:
	var keep := PERIOD * KEEP
	while not walls.is_empty() and clock - float(walls[0]["t"]) > keep:
		walls.pop_front()
	while not contacts.is_empty() and clock - float(contacts[0]["t"]) > keep:
		contacts.pop_front()
