class_name Derelict
extends Node3D
## An abandoned station built into the cave wall (see DerelictBuilder). Every peer animates it from
## the mothership's replicated outpost state (Mothership.outpost_*): its lamps (failing ones flicker;
## with a generator, the working lamps wait for its power and red emergency lamps glow meanwhile),
## its sealed doors (sliding up into the wall once opened, and a keypad lock's shutter slamming down
## in a lockdown, with red alarm lights), its keypads, the generator (the starter's pull, the flywheel,
## the shaking engine, its smoke and chug), the specimens floating in their tanks, and the control
## hub (its camera feeds, the station map on its board, its computer). The mothership spawns the
## station's salvage and hostiles when it lands there.

## Lamp circuits: lit whatever happens, lit by the generator's power, lit until the power is back
## (the red emergency lamps), never lit.
const ALWAYS := 0
const POWER := 1
const EMERGENCY := 2
const DEAD := 3
## Door states (Mothership.outpost_doors).
const DOOR_CLOSED := 0
const DOOR_OPEN := 1
const DOOR_LOCKDOWN := 2
## A sealed door opens at this rate (fraction per second); a lockdown shutter drops in SHUTTER_TIME.
const DOOR_RATE := 0.45
const SHUTTER_TIME := 0.22
## Once the power is back the working lamps come on in a wave from the generator: POWER_WAVE seconds
## per cell of distance, each with a stutter.
const POWER_WAVE := 0.09
## A lockdown's alarm: the red lights flash hard for ALARM_TIME seconds, then keep pulsing slowly.
const ALARM_TIME := 14.0
## The generator: its flywheel at full speed (rad/s), and how much the engine shakes (m).
const FLYWHEEL_SPEED := 9.0
const ENGINE_SHAKE := 0.006
## Security feeds: picture size, field of view, and how close (in the room) the viewer must be.
const FEED_SIZE := Vector2i(256, 192)
const FEED_FOV := 68.0

## The derelict nodes built right now, by station index (on every peer).
static var live: Dictionary = {}

var k := 0
var layout: Dictionary = {}
## Lights that cut out now and then: {"light", "energy", "rate", "phase"}.
var flicker: Array = []
## Lamps: {"light", "glass", "energy", "circuit", "cell", "flicker", "on"}.
var lamps: Array = []
## Sealed doors by door index (see DerelictBuilder._build_doors), plus "open" (0..1) and "drop"
## (the shutter, 0 up .. 1 down).
var doors: Dictionary = {}
var _t := 0.0
var _power := false
var _power_t := -100.0
var _gen: Dictionary = {}
var _gen_spin := 0.0
var _gen_audio: AudioStreamPlayer3D
var _gen_smoke: Array[GPUParticles3D] = []
var _subjects: Array = []
var _feeds: Array = []
var _feed_next := 0
var _feeds_on := false
var _screens: Array = []
## The control hub's computer and the map on its board (drawn into _map_vp; _map_key: what it
## shows, so it is only drawn again on a change).
var _console: HubConsole
var _map: HubMap
var _map_vp: SubViewport
var _map_key := ""
var _alarm_audio: Dictionary = {}
var _door_audio: Dictionary = {}
static var _feed_shader: Shader
static var _lit_mat: StandardMaterial3D
static var _off_mat: StandardMaterial3D
static var _strip_mat: StandardMaterial3D
## The emergency strips low along the corridors (one batch) and their circuit.
var _strips: Array[MeshInstance3D] = []
var _strip_circuit := ALWAYS
var _strips_on := -1
## Inside, the cave's cold blue ambient light gives way to a dim olive grey (0..1, eased).
const INSIDE_AMBIENT := Color(0.33, 0.34, 0.29)
const INSIDE_AMBIENT_ENERGY := 0.3
## ...a little more while the power is out, so shapes still show in the emergency light.
const DARK_AMBIENT_ENERGY := 0.42
var _ambient_dark := false
var _inside := 0.0
var _env_rest: Array = []


func _enter_tree() -> void:
	live[k] = self


func _exit_tree() -> void:
	if live.get(k) == self:
		live.erase(k)
	_inside = 0.0
	_apply_ambient()


func add_flicker(light: Light3D, rate: float, phase: float) -> void:
	flicker.append({"light": light, "energy": light.light_energy, "rate": rate, "phase": phase})


## A lamp: its glowing glass (a box `size` at `pos`, station-local) and its light, on `circuit`.
func add_lamp(pos: Vector3, size: Vector3, color: Color, energy: float, reach: float, circuit: int, cell: Vector2i, flickers: bool,
		rng: RandomNumberGenerator, glass_color := Color(0, 0, 0, 0)) -> void:
	var glass := MeshInstance3D.new()
	glass.mesh = Models.unit_box()
	glass.position = pos
	glass.scale = size
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(glass)
	var light: OmniLight3D = null
	if circuit != DEAD:
		light = OmniLight3D.new()
		light.position = pos + Vector3(0, -0.25, 0)
		light.light_color = color
		light.light_energy = energy
		light.omni_range = reach
		light.omni_attenuation = 1.3
		light.visible = false
		add_child(light)
	var lit := StandardMaterial3D.new()
	var glow := glass_color if glass_color.a > 0.0 else color
	lit.albedo_color = glow * 0.3
	lit.emission_enabled = true
	lit.emission = glow
	lit.emission_energy_multiplier = 3.0 if glow.g > 0.3 else 2.2
	lamps.append({"light": light, "glass": glass, "energy": energy, "circuit": circuit, "cell": cell, "flicker": flickers,
		"rate": rng.randf_range(0.15, 0.45), "phase": rng.randf(), "lit": lit, "on": -1.0, "delay": rng.randf_range(0.0, 0.35)})
	glass.material_override = _dark_glass()


## The emergency strips' meshes (lit like EMERGENCY lamps, or always without a generator).
func add_strips(meshes: Array[MeshInstance3D], circuit: int) -> void:
	_strips = meshes
	_strip_circuit = circuit


## The emergency strips' glow (the batch's material; swapped for dark glass while they are off).
static func strip_material() -> StandardMaterial3D:
	if _strip_mat == null:
		_strip_mat = StandardMaterial3D.new()
		_strip_mat.albedo_color = Color(0.2, 0.09, 0.03)
		_strip_mat.emission_enabled = true
		_strip_mat.emission = Color(1.0, 0.45, 0.15)
		_strip_mat.emission_energy_multiplier = 0.35
	return _strip_mat


func add_door(di: int, rec: Dictionary) -> void:
	rec["open"] = 0.0
	rec["drop"] = 0.0
	rec["state"] = -1
	rec["alarm_t"] = 0.0
	doors[di] = rec


## Once the station is built: what the props left to animate.
func setup(out: Dictionary) -> void:
	_subjects = out["subjects"]
	_gen = out["generator"]
	_screens = out["screens"]
	_console = out.get("hub_console")
	if not _gen.is_empty():
		_build_generator_fx()
	_build_feeds()
	if out.has("hub_map"):
		_build_map(out["hub_map"])
	var st := _state()
	_power = bool(st["power"])
	_power_t = -100.0
	_apply_lamps(true)
	for di: int in doors:
		_apply_door(di, (st["doors"] as PackedByteArray), true)
	_update_hub(st)


## Whether nobody needs to open door `di` to pass it: the front door, or a door whose state
## (`states`, Mothership.outpost_doors; missing: the station's starting state) is open. (An open
## doorway always is, unless the control hub has locked its door.)
static func door_passable(door: Dictionary, states: PackedByteArray, di: int) -> bool:
	var kind := str(door["kind"])
	if kind == "front":
		return true
	if di >= states.size():
		return kind == "open"
	return states[di] == DOOR_OPEN


## The station's starting door states: open doorways open, sealed doors shut.
static func start_doors(layout_d: Dictionary) -> PackedByteArray:
	var out := PackedByteArray()
	for d: Dictionary in layout_d["doors"]:
		out.append(DOOR_OPEN if str(d["kind"]) in ["open", "front"] else DOOR_CLOSED)
	return out


## The replicated state that applies to this station: {"power", "doors", "tries"}.
func _state() -> Dictionary:
	var ship: Mothership = Game.mission.ship if Game.mission else null
	if ship and ship.outpost_k == k and ship.outpost_doors.size() == (layout["doors"] as Array).size():
		return {"power": ship.outpost_power, "doors": ship.outpost_doors, "tries": ship.outpost_tries}
	return {"power": false, "doors": start_doors(layout), "tries": PackedByteArray()}


func _process(delta: float) -> void:
	_t += delta
	for f: Dictionary in flicker:
		var v := fposmod(_t * float(f["rate"]) + float(f["phase"]), 1.0)
		# Short dropouts, a stutter, then steady again.
		var off := v < 0.06 or (v > 0.1 and v < 0.13) or (v > 0.55 and v < 0.57)
		(f["light"] as Light3D).light_energy = float(f["energy"]) * (0.08 if off else 1.0)
	var st := _state()
	var power := bool(st["power"])
	if power != _power:
		_power = power
		_power_t = _t
	_apply_lamps(false)
	var states: PackedByteArray = st["doors"]
	for di: int in doors:
		_apply_door(di, states, false, delta)
		var panel: HackPanel = doors[di].get("panel")
		if panel:
			var tries: PackedByteArray = st["tries"]
			panel.show_state(states[di] if di < states.size() else DOOR_CLOSED, tries[di] if di < tries.size() else 0, _t)
	_animate_generator(delta)
	_ease_ambient(delta)
	for s: Dictionary in _subjects:
		if s["float"]:
			var n: Node3D = s["node"]
			var base: Transform3D = s["base"]
			var ph := float(s["phase"])
			n.transform = base.rotated_local(Vector3.UP, sin(_t * 0.13 + ph) * 0.4).translated(Vector3(0, sin(_t * 0.6 + ph) * 0.05, 0))
	_update_feeds()
	_update_hub(st)


# --- Lamps -------------------------------------------------------------------------------------

func _apply_lamps(instant: bool) -> void:
	var gen_cell := Vector2i(-100, -100)
	var gi := int(layout.get("generator", -1))
	if gi >= 0:
		var core: Rect2i = layout["rooms"][gi]["core"]
		gen_cell = core.get_center()
	for l: Dictionary in lamps:
		var want := false
		var circuit := int(l["circuit"])
		match circuit:
			ALWAYS:
				want = true
			POWER:
				want = _power
				if want and not instant and _power_t > 0.0:
					var cell: Vector2i = l["cell"]
					var wait := (absi(cell.x - gen_cell.x) + absi(cell.y - gen_cell.y)) * POWER_WAVE + float(l["delay"])
					var since := _t - _power_t - wait
					# Coming on: a few stutters first.
					want = since > 0.0 and not (since < 0.35 and fposmod(since * 11.0, 1.0) < 0.45)
			EMERGENCY:
				want = not _power
		var light: OmniLight3D = l["light"]
		if want and bool(l["flicker"]) and light:
			var v := fposmod(_t * float(l["rate"]) + float(l["phase"]), 1.0)
			if v < 0.05 or (v > 0.09 and v < 0.12) or (v > 0.6 and v < 0.62):
				want = false
		var on := 1.0 if want else 0.0
		if float(l["on"]) == on:
			continue
		l["on"] = on
		if light:
			light.visible = want
		(l["glass"] as MeshInstance3D).material_override = l["lit"] if want else _dark_glass()
	var strips := 1 if _strip_circuit == ALWAYS or (_strip_circuit == EMERGENCY and not _power) else 0
	if strips != _strips_on:
		_strips_on = strips
		for mi in _strips:
			mi.material_override = strip_material() if strips == 1 else _dark_glass()


## Ease the ambient light towards the station's own while the camera is inside it.
func _ease_ambient(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	var want := 0.0
	if cam:
		var lp := global_transform.affine_inverse() * cam.global_position
		var c := OutpostLayout.cell_at(lp)
		if OutpostLayout.inside(c) and (layout["kind"] as PackedByteArray)[OutpostLayout.idx(c)] != OutpostLayout.ROCK:
			want = 1.0
	var was := _inside
	_inside = move_toward(_inside, want, delta * 1.5)
	var dark := not _power and int(layout.get("generator", -1)) >= 0
	if _inside != was or dark != _ambient_dark:
		_ambient_dark = dark
		_apply_ambient()


func _apply_ambient() -> void:
	if not is_inside_tree():
		return
	var env := get_world_3d().environment
	if env == null:
		return
	if _env_rest.is_empty():
		_env_rest = [env.ambient_light_color, env.ambient_light_energy]
	env.ambient_light_color = (_env_rest[0] as Color).lerp(INSIDE_AMBIENT, _inside)
	env.ambient_light_energy = lerpf(float(_env_rest[1]), DARK_AMBIENT_ENERGY if _ambient_dark else INSIDE_AMBIENT_ENERGY, _inside)


static func _dark_glass() -> StandardMaterial3D:
	if _off_mat == null:
		_off_mat = StandardMaterial3D.new()
		_off_mat.albedo_color = Color(0.09, 0.085, 0.07)
		_off_mat.metallic = 0.3
		_off_mat.roughness = 0.3
	return _off_mat


# --- Doors -------------------------------------------------------------------------------------

func _apply_door(di: int, states: PackedByteArray, instant: bool, delta := 0.0) -> void:
	var rec: Dictionary = doors[di]
	var state := int(states[di]) if di < states.size() else DOOR_CLOSED
	var want := 1.0 if state == DOOR_OPEN else 0.0
	var was := float(rec["open"])
	var now := want if instant else move_toward(was, want, DOOR_RATE * delta)
	rec["open"] = now
	var moving := not instant and absf(now - was) > 0.00001
	var dh := OutpostLayout.DOOR_H
	(rec["slab"] as Node3D).position = (rec["pos"] as Vector3) + Vector3(0, smoothstep(0.0, 1.0, now) * (dh - 0.05), 0)
	(rec["shape"] as CollisionShape3D).disabled = now > 0.85
	_door_sound(di, rec, moving)
	var lamp: StandardMaterial3D = rec["lamp"]
	var kind := str(layout["doors"][di]["kind"])
	if state == DOOR_OPEN:
		lamp.emission = Color(0.2, 1.0, 0.3)
	elif state == DOOR_LOCKDOWN:
		lamp.emission = Color(1.0, 0.08, 0.04) * (0.3 + 0.7 * float(fposmod(_t * 2.5, 1.0) < 0.5))
	elif kind == "power" and not _power:
		lamp.emission = Color(0.25, 0.04, 0.02)
	else:
		lamp.emission = Color(1.0, 0.12, 0.05)
	if rec.has("shutter"):
		var down := state == DOOR_LOCKDOWN
		if down and int(rec["state"]) != DOOR_LOCKDOWN:
			rec["alarm_t"] = 0.0 if instant else ALARM_TIME
			if not instant:
				_slam(di, rec)
		var drop := 1.0 if down else 0.0
		rec["drop"] = drop if instant else move_toward(float(rec["drop"]), drop, delta / SHUTTER_TIME)
		var rest: Transform3D = rec["shutter_rest"]
		(rec["shutter"] as Node3D).transform = rest.translated(Vector3(0, (1.0 - float(rec["drop"])) * OutpostLayout.CORRIDOR_H, 0))
		(rec["shutter_shape"] as CollisionShape3D).disabled = not down
		var alarm: OmniLight3D = rec["alarm"]
		alarm.visible = down
		if down:
			rec["alarm_t"] = maxf(0.0, float(rec["alarm_t"]) - delta)
			var hard := float(rec["alarm_t"]) > 0.0
			var pulse := 0.5 + 0.5 * sin(_t * (9.0 if hard else 3.0))
			alarm.light_energy = (2.6 if hard else 1.0) * pulse
			_alarm_sound(di, rec, hard)
		else:
			_alarm_sound(di, rec, false)
	rec["state"] = state


## The grinding of a sealed door on the move, and the clang when it stops.
func _door_sound(di: int, rec: Dictionary, moving: bool) -> void:
	var p: AudioStreamPlayer3D = _door_audio.get(di)
	if moving and p == null:
		p = AudioStreamPlayer3D.new()
		p.stream = Sfx.stream("door_grind")
		p.volume_db = -8.0
		p.unit_size = 6.0
		p.max_distance = 60.0
		p.position = (rec["pos"] as Vector3) + Vector3(0, 2.0, 0)
		add_child(p)
		Sfx.track(p)
		p.play()
		_door_audio[di] = p
	elif not moving and p != null:
		p.queue_free()
		_door_audio.erase(di)
		Sfx.play("gate_clang", to_global((rec["pos"] as Vector3) + Vector3(0, 2.5, 0)), -6.0, 1.5)


## A lockdown: the shutter slams down, the station shakes, the alarm starts.
func _slam(_di: int, rec: Dictionary) -> void:
	var at := to_global((rec["pos"] as Vector3) + (rec["normal"] as Vector3) * 0.6 + Vector3(0, 1.2, 0))
	Sfx.play("shutter_slam", at, 4.0)
	Fx.sparks(at + Vector3(0, -1.1, 0), Color(1.0, 0.7, 0.3), 24, 6.0, 0.04, 0.5)
	var lp: CrewMember = Game.mission.local_player if Game.mission else null
	if lp and lp.global_position.distance_to(at) < 14.0:
		Game.mission.shake(0.45)


func _alarm_sound(di: int, rec: Dictionary, on: bool) -> void:
	var p: AudioStreamPlayer3D = _alarm_audio.get(di)
	if on and p == null:
		p = AudioStreamPlayer3D.new()
		p.stream = Sfx.stream("lockdown_alarm")
		p.volume_db = -6.0
		p.unit_size = 8.0
		p.max_distance = 90.0
		p.position = (rec["pos"] as Vector3) + (rec["normal"] as Vector3) * 1.5 + Vector3(0, 2.6, 0)
		add_child(p)
		Sfx.track(p)
		p.play()
		_alarm_audio[di] = p
	elif not on and p != null:
		p.queue_free()
		_alarm_audio.erase(di)


## A keypad lock's panel (or null).
func panel_of(di: int) -> HackPanel:
	return doors.get(di, {}).get("panel") as HackPanel


## Something happened at the station (Mothership.fx_outpost): a starter pull, the generator
## catching, a wrong or right code.
func on_event(kind: String, di: int) -> void:
	match kind:
		"gen_pull":
			if not _gen.is_empty():
				_gen["pull_t"] = 0.0
				Sfx.play("gen_cough", to_global(_gen["pos"]), -2.0)
		"gen_start":
			if not _gen.is_empty():
				_gen["pull_t"] = 0.0
				Sfx.play("gen_start", to_global(_gen["pos"]), 0.0)
		"hack_bad", "hack_ok", "lockdown":
			var panel := panel_of(di)
			if panel:
				panel.result(kind)


# --- The generator -----------------------------------------------------------------------------

func _build_generator_fx() -> void:
	_gen["pull_t"] = 10.0
	_gen_audio = AudioStreamPlayer3D.new()
	_gen_audio.stream = Sfx.stream("generator_loop")
	_gen_audio.volume_db = -9.0
	_gen_audio.unit_size = 7.0
	_gen_audio.max_distance = 70.0
	_gen_audio.position = _gen["pos"]
	add_child(_gen_audio)
	Sfx.track(_gen_audio)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.12
	pm.direction = Vector3.UP
	pm.spread = 30.0
	pm.initial_velocity_min = 0.3
	pm.initial_velocity_max = 0.8
	pm.damping_min = 0.4
	pm.damping_max = 0.8
	pm.gravity = Vector3(0, 0.3, 0)
	pm.scale_min = 0.8
	pm.scale_max = 1.6
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.15, 1.0])
	fade.colors = PackedColorArray([Color(0.5, 0.5, 0.48, 0.0), Color(0.42, 0.42, 0.4, 0.28), Color(0.35, 0.35, 0.35, 0.0)])
	var ft := GradientTexture1D.new()
	ft.gradient = fade
	pm.color_ramp = ft
	for p: Vector3 in _gen["exhausts"]:
		var s := GPUParticles3D.new()
		s.amount = 16
		s.lifetime = 3.0
		s.randomness = 0.5
		s.local_coords = false
		s.emitting = false
		s.process_material = pm
		s.draw_pass_1 = GunPod.smoke_mesh()
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		s.position = p
		add_child(s)
		_gen_smoke.append(s)


func _animate_generator(delta: float) -> void:
	if _gen.is_empty():
		return
	var running := _power
	_gen_spin = move_toward(_gen_spin, 1.0 if running else 0.0, delta * (0.5 if running else 0.25))
	var wheel: Node3D = _gen["wheel"]
	wheel.rotation.z += _gen_spin * FLYWHEEL_SPEED * delta
	var engine: Node3D = _gen["engine"]
	var rest: Transform3D = _gen["rest"]
	var shake := ENGINE_SHAKE * _gen_spin
	engine.transform = rest.translated(Vector3(sin(_t * 61.0) * shake, absf(sin(_t * 47.0)) * shake, cos(_t * 53.0) * shake * 0.5))
	if running != _gen_audio.playing:
		if running:
			_gen_audio.play()
		else:
			_gen_audio.stop()
	if running:
		_gen_audio.pitch_scale = lerpf(0.6, 1.0, _gen_spin)
	for s in _gen_smoke:
		s.emitting = _gen_spin > 0.2
	# The starter's handle: yanked out along the cord and springing back.
	_gen["pull_t"] = float(_gen["pull_t"]) + delta
	var pt := float(_gen["pull_t"])
	var out := 0.0
	if pt < 0.18:
		out = pt / 0.18
	elif pt < 0.7:
		out = 1.0 - smoothstep(0.18, 0.7, pt)
	var handle: Node3D = _gen["handle"]
	var hrest: Transform3D = _gen["handle_rest"]
	handle.transform = hrest.translated((_gen["outward"] as Vector3) * out * 0.55)
	var cord: Node3D = _gen["cord"]
	cord.scale = Vector3(1.0, 1.0 + out * 3.6, 1.0)
	cord.position.x = -0.08 - out * 0.29
	var lamp: MeshInstance3D = _gen["lamp"]
	lamp.material_override = _green_lamp() if running else _red_lamp()


static func _green_lamp() -> StandardMaterial3D:
	return Models.emissive(Color(0.2, 1.0, 0.3), 3.0)


static func _red_lamp() -> StandardMaterial3D:
	return Models.emissive(Color(1.0, 0.12, 0.06), 3.0)


## Where the generator's starter is (global), or an infinite vector when there is none.
func generator_spot() -> Vector3:
	if _gen.is_empty():
		return Vector3(INF, INF, INF)
	return to_global(_gen["pos"])


# --- The control hub -----------------------------------------------------------------------------

## Whether the control hub works: with a generator, once it runs.
func hub_powered() -> bool:
	return _power or int(layout.get("generator", -1)) < 0


## The control hub's computer, or null.
func hub_console() -> HubConsole:
	return _console


## The server's answer to a command typed at the hub (Mothership.fx_hub_log).
func hub_print(lines: PackedStringArray, ok: bool) -> void:
	if _console:
		_console.print_lines(lines, ok)


## The map on the hub's board: drawn offscreen (once, and again on a change, see _update_hub).
func _build_map(board: MeshInstance3D) -> void:
	_map_vp = SubViewport.new()
	_map_vp.size = HubMap.SIZE
	_map_vp.disable_3d = true
	_map_vp.transparent_bg = false
	_map_vp.msaa_2d = Viewport.MSAA_4X
	_map_vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_map_vp)
	_map = HubMap.new()
	_map.setup(layout, float(board.get_meta("yaw", 0.0)), _console.position if _console else board.position)
	_map_vp.add_child(_map)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = _map_vp.get_texture()
	board.material_override = mat


## The hub's computer and map follow the power and the doors' states.
func _update_hub(st: Dictionary) -> void:
	var on := hub_powered()
	if _console:
		_console.set_powered(on)
	if _map == null:
		return
	var states: PackedByteArray = st["doors"]
	var key := "%s|%s" % [on, states.hex_encode()]
	if key == _map_key:
		return
	_map_key = key
	_map.doors = states
	_map.powered = on
	_map.queue_redraw()
	_map_vp.render_target_update_mode = SubViewport.UPDATE_ONCE


# --- Security feeds ----------------------------------------------------------------------------

## The cameras in the watched rooms (a housing on a bracket with a blinking light), and an offscreen
## view of each for a screen over the control hub's desk.
func _build_feeds() -> void:
	var sec := int(layout.get("hub", -1))
	if sec < 0:
		return
	var cams: Array = []
	for room: Dictionary in layout["rooms"]:
		for cam: Dictionary in room["cams"]:
			cams.append(cam)
	var housing := Models.mat(Color(0.2, 0.21, 0.2), 0.6, 0.5)
	for i in mini(cams.size(), _screens.size()):
		var cam: Dictionary = cams[i]
		var pos: Vector3 = cam["pos"]
		var look: Vector3 = cam["look"]
		var x := Transform3D(Basis.looking_at(look - pos, Vector3.UP), pos)
		var body := Node3D.new()
		body.transform = x
		add_child(body)
		Models.box(body, Vector3(0, 0, 0.05), Vector3(0.2, 0.18, 0.36), housing)
		Models.cylinder(body, Vector3(0, 0, -0.17), 0.06, 0.08, Models.mat(Color(0.05, 0.05, 0.06), 0.5, 0.2), Vector3(90, 0, 0))
		Models.sphere(body, Vector3(0.07, 0.07, -0.12), 0.015, Models.blink(Color(1.0, 0.15, 0.1), 0.9, float(i) * 0.3, 0.5))
		Models.box(body, Vector3(0, 0.16, 0.12), Vector3(0.05, 0.2, 0.05), housing)
		var vp := SubViewport.new()
		vp.size = FEED_SIZE
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		vp.positional_shadow_atlas_size = 0
		vp.msaa_3d = Viewport.MSAA_DISABLED
		vp.audio_listener_enable_3d = false
		add_child(vp)
		var c3 := Camera3D.new()
		c3.fov = FEED_FOV
		c3.near = 0.1
		c3.far = 60.0
		c3.cull_mask &= ~(Game.VIS_INTERIOR | Game.VIS_VIEWMODEL)
		c3.environment = Cockpit._feed_env()
		c3.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		vp.add_child(c3)
		c3.current = true
		var screen: MeshInstance3D = _screens[i]
		var mat := ShaderMaterial.new()
		if _feed_shader == null:
			_feed_shader = Shader.new()
			_feed_shader.code = Cockpit.FEED_SHADER
		mat.shader = _feed_shader
		mat.set_shader_parameter("feed", vp.get_texture())
		screen.material_override = mat
		var label := Label3D.new()
		label.text = "CAM %d  %s" % [i + 1, _room_of(pos)]
		label.font_size = 20
		label.pixel_size = 0.0022
		label.modulate = Color(0.55, 1.0, 0.6)
		label.outline_size = 0
		label.position = Vector3(0, 0.19, 0.002)
		screen.add_child(label)
		_feeds.append({"vp": vp, "cam": c3, "xform": x * Transform3D(Basis.IDENTITY, Vector3(0, 0, -0.26)), "screen": screen, "seen": false,
			"label": label})
		# (Dark until the viewer is in the hub and it has power, see _update_feeds.)
		screen.set_instance_shader_parameter("power", 0.0)
		label.visible = false
	for i in range(_feeds.size(), _screens.size()):
		(_screens[i] as MeshInstance3D).material_override = Models.mat(Color(0.04, 0.05, 0.05), 0.5, 0.2)


func _room_of(p: Vector3) -> String:
	var ri := OutpostLayout.room_at(layout, p)
	return str(layout["rooms"][ri]["name"]) if ri >= 0 else "CORRIDOR"


## The feeds render while the local viewer is in the control hub (and it has power: with a
## generator, only once it runs), one feed a frame in turn.
func _update_feeds() -> void:
	if _feeds.is_empty():
		return
	var cam := get_viewport().get_camera_3d()
	var on := cam != null and hub_powered() \
		and OutpostLayout.room_at(layout, to_local(cam.global_position)) == int(layout["hub"])
	if on != _feeds_on:
		_feeds_on = on
		for f: Dictionary in _feeds:
			(f["vp"] as SubViewport).render_target_update_mode = SubViewport.UPDATE_DISABLED
			(f["screen"] as MeshInstance3D).set_instance_shader_parameter("power", 1.0 if on else 0.0)
			(f["label"] as Label3D).visible = on
	if not on:
		return
	var f: Dictionary = _feeds[_feed_next]
	(f["cam"] as Camera3D).global_transform = global_transform * (f["xform"] as Transform3D)
	(f["vp"] as SubViewport).render_target_update_mode = SubViewport.UPDATE_ONCE
	if not f["seen"]:
		f["seen"] = true
		(f["screen"] as MeshInstance3D).set_instance_shader_parameter("snow", 0.0)
	_feed_next = (_feed_next + 1) % _feeds.size()
