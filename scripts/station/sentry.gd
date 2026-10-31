class_name Sentry
extends SupplyCrate
## A portable sentry turret: found in the abandoned stations, a box much like the salvage crates,
## picked up, carried and put down the same way. A big double chevron on its lid points the way it
## faces, and its barrel's tip shows in a hatch at that end. Set down in a station, F opens it: the
## lid's halves swing out, the gun rises on its post and guards ARC either side of its front. It
## swings to the nearest alien it can see within RANGE there and fires at it, fast and hard (DAMAGE
## a round, every FIRE_INTERVAL), until its ROUNDS run out; the rounds left show on a display at its
## back. Aliens it hurts turn on it (Boarder takes it for the shooter); those it leaves alone may run
## past it after the crew. F folds an intact one up again (it keeps its rounds), to carry it
## elsewhere. Once it has taken HP of damage it is wrecked for good: bent, sparking and smoking. It
## only opens in a station, never aboard the ship.
##
## The server runs it (targets, aim, rounds, damage); every peer animates it from the replicated
## state and shows its shots (fx_shot).

enum { PACKED, OPENING, ACTIVE, CLOSING, WRECKED }
## How far it turns either side of its front, how far it looks up and down (radians), and how fast
## it swings (rad/s).
const ARC := 0.785
const PITCH_MIN := -0.35
const PITCH_MAX := 0.95
const TURN := 3.2
## How far it reaches (m), seconds between rounds, a round's damage and scatter (radians), the rounds
## it carries and the damage it takes before it is wrecked.
const RANGE := 24.0
const FIRE_INTERVAL := 0.08
const DAMAGE := 16.0
const SPREAD := 0.018
const ROUNDS := 300
const HP := 320.0
## Seconds to unfold (or fold up), how close its aim must be (radians) before it fires, how often it
## looks for a target.
const OPEN_TIME := 1.2
const AIM_TOLERANCE := 0.07
const RETARGET := 0.25
## The gun's pivot (crate frame, its middle at the origin, its front along +X) when up (the barrel
## about a metre over the floor, above beds and tables), how far the ram lowers it into the box
## folded, the barrel's tip from the pivot, and the lid's height.
const PIVOT := Vector3(0.0, 0.62, 0.0)
const SINK := 0.62
const BARREL_TIP := Vector3(0.52, 0.08, 0.0)
const LID_H := 0.16
const COLOR := Color(1.0, 0.55, 0.15)

# Replicated (server authority): what it is doing, its aim (yaw, pitch; from its front), rounds left
# and health.
var s_state := PACKED
var s_aim := Vector2.ZERO
var s_rounds := ROUNDS
var s_hp := HP

var _body: StaticBody3D
var _shape: CollisionShape3D
var _lids: Array[Node3D] = []
var _ram: Node3D
var _post: Node3D
var _yaw: Node3D
var _pitch: Node3D
var _flash: MeshInstance3D
var _flash_t := 0.0
var _since_shot := 10.0
var _kick := 0.0
var _caption: Label3D
var _count: Label3D
var _note: Label3D
var _lamp: StandardMaterial3D
var _sparks: CPUParticles3D
var _smoke: GPUParticles3D
var _spark_t := 0.0
var _open := 0.0
var _aim_shown := Vector2.ZERO
var _shown_text := ""
# Server.
var _state_t := 0.0
var _cd := 0.0
var _retarget_t := 0.0
var _target := 0


func _synced() -> Array:
	return ["s_state", "s_aim", "s_rounds", "s_hp"]


func setup(data: Dictionary) -> void:
	super.setup(data)
	var st: Dictionary = data.get("sentry", {})
	s_state = int(st.get("state", PACKED))
	s_rounds = int(st.get("rounds", ROUNDS))
	s_hp = float(st.get("hp", HP))
	s_aim = st.get("aim", Vector2.ZERO)
	# (One stowed while opening or folding up finishes it.)
	if s_state == OPENING:
		s_state = ACTIVE
	elif s_state == CLOSING:
		s_state = PACKED
	_open = 1.0 if s_state == ACTIVE or s_state == WRECKED else 0.0
	_aim_shown = s_aim


## What to keep of it when its station is stowed (Mothership._stow_derelict): merged into its spawn
## data when the crew comes back.
func save_data() -> Dictionary:
	return {"state": s_state, "rounds": s_rounds, "hp": s_hp, "aim": s_aim}


## True while it is open and not wrecked (aliens can go for it).
func standing() -> bool:
	return (s_state == OPENING or s_state == ACTIVE or s_state == CLOSING) and s_hp > 0.0


func _ready() -> void:
	# (Its body first: the base class builds the model, which sets the body's layer.)
	_body = StaticBody3D.new()
	_body.collision_layer = 0
	_body.collision_mask = 0
	_body.set_meta("sentry", str(name))
	_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = SIZE
	_shape.shape = box
	_body.add_child(_shape)
	add_child(_body)
	super._ready()


# --- The model ---------------------------------------------------------------------------------

## The box (its lower part and the lid's two halves, hinged along its long sides) with the gun folded
## inside it, the double chevron on the lid and the hatch at the front, the display at the back.
func _build_shell() -> void:
	if _visual:
		_visual.queue_free()
	_visual = Node3D.new()
	add_child(_visual)
	_built_item = item
	_lids.clear()
	var shell := Models.panel_mat(Color(0.22, 0.24, 0.27), 0.5, 0.5, 1.2)
	var band := Models.emissive(COLOR.lerp(Color(0.95, 0.8, 0.6), 0.35), 1.1, COLOR * 0.25)
	var trim := Models.mat(Color(0.75, 0.76, 0.8), 0.7, 0.35)
	var dark := Models.mat(Color(0.08, 0.08, 0.09), 0.5, 0.6)
	var hazard := Models.emissive(Color(0.95, 0.72, 0.15), 0.6, Color(0.3, 0.22, 0.04))
	var lower := SIZE.y - LID_H
	var base := Node3D.new()
	_visual.add_child(base)
	var by := -SIZE.y * 0.5 + lower * 0.5
	Models.box(base, Vector3(0, by, 0), Vector3(SIZE.x, lower, SIZE.z), shell)
	for x: float in [-0.3, 0.3]:
		Models.box(base, Vector3(x, by, 0), Vector3(0.07, lower + 0.02, SIZE.z + 0.02), band)
	# (Corner posts, not end plates: the ends carry the hatch and the display.)
	for x: float in [-0.44, 0.44]:
		for z: float in [-0.29, 0.29]:
			Models.box(base, Vector3(x, by, z), Vector3(0.04, lower + 0.03, 0.04), trim)
	# The front: a hatch round the barrel's tip, hazard-striped.
	var fx := SIZE.x * 0.5
	Models.cylinder(base, Vector3(fx + 0.004, PIVOT.y - SINK + BARREL_TIP.y, 0), 0.075, 0.008, hazard, Vector3(0, 0, 90))
	Models.cylinder(base, Vector3(fx + 0.007, PIVOT.y - SINK + BARREL_TIP.y, 0), 0.055, 0.008, dark, Vector3(0, 0, 90))
	# The back: the display (rounds left and the state) in a dark bezel.
	var back := Node3D.new()
	back.position = Vector3(-fx - 0.006, by + 0.02, 0)
	back.rotation.y = -PI / 2.0
	base.add_child(back)
	Models.box(back, Vector3(0, 0, -0.004), Vector3(0.3, 0.22, 0.01), dark)
	var screen := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.27, 0.19)
	screen.mesh = q
	screen.material_override = GunPod.crt_material()
	screen.position = Vector3(0, 0, 0.002)
	back.add_child(screen)
	_caption = _display_text(back, Vector3(-0.12, 0.072, 0.004), "SENTRY", 22, HORIZONTAL_ALIGNMENT_LEFT)
	_count = _display_text(back, Vector3(0.0, -0.005, 0.004), "%03d" % s_rounds, 60, HORIZONTAL_ALIGNMENT_CENTER)
	_note = _display_text(back, Vector3(0.0, -0.072, 0.004), "PACKED", 22, HORIZONTAL_ALIGNMENT_CENTER)
	_lamp = StandardMaterial3D.new()
	_lamp.albedo_color = Color(0.05, 0.05, 0.05)
	_lamp.emission_enabled = true
	_lamp.emission = Color(1.0, 0.6, 0.15)
	_lamp.emission_energy_multiplier = 1.5
	Models.sphere(back, Vector3(0.12, 0.072, 0.008), 0.012, _lamp)
	# The lid's halves: hinged along the box's long sides, each with an arm of the chevrons on it.
	for s: float in [-1.0, 1.0]:
		var hinge := Node3D.new()
		hinge.position = Vector3(0, -SIZE.y * 0.5 + lower, s * SIZE.z * 0.5)
		_visual.add_child(hinge)
		Models.box(hinge, Vector3(0, LID_H * 0.5, -s * SIZE.z * 0.25), Vector3(SIZE.x, LID_H, SIZE.z * 0.5 - 0.004), shell)
		for x: float in [-0.3, 0.3]:
			Models.box(hinge, Vector3(x, LID_H * 0.5, -s * SIZE.z * 0.25), Vector3(0.07, LID_H + 0.02, SIZE.z * 0.5 + 0.006), band)
		for tip: float in [0.36, 0.1]:
			var a := Vector3(tip - 0.27, LID_H + 0.006, -s * 0.1)
			var e := Vector3(tip, LID_H + 0.006, -s * SIZE.z * 0.5 + s * 0.012)
			var d := e - a
			Models.box(hinge, (a + e) * 0.5, Vector3(d.length(), 0.01, 0.06), hazard, Vector3(0, rad_to_deg(atan2(-d.z, d.x)), 0))
		Models.box(hinge, Vector3(-0.32, LID_H + 0.02, -s * SIZE.z * 0.25), Vector3(0.14, 0.03, 0.04), trim)
		_lids.append(hinge)
	# The gun on its post: a turntable, a yoke, the receiver with an ammunition can, a barrel in a
	# cooling jacket with a flash hider, and the sensor on top with its red eye.
	var olive := Models.mat(Color(0.3, 0.33, 0.22), 0.3, 0.65)
	var steel := Models.mat(Color(0.35, 0.36, 0.37), 0.8, 0.35)
	var gunmetal := Models.mat(Color(0.16, 0.16, 0.17), 0.75, 0.45)
	# (A sleeve in the box's floor and the ram out of it, which stretches up as the gun rises.)
	Models.cylinder(base, Vector3(0, -SIZE.y * 0.5 + 0.17, 0), 0.06, 0.3, gunmetal)
	_ram = Node3D.new()
	_ram.position = Vector3(0, -SIZE.y * 0.5 + 0.02, 0)
	_visual.add_child(_ram)
	Models.cylinder(_ram, Vector3(0, 0.5, 0), 0.038, 1.0, steel)
	_post = Node3D.new()
	_post.position = PIVOT
	_visual.add_child(_post)
	_yaw = Node3D.new()
	_post.add_child(_yaw)
	Models.cylinder(_yaw, Vector3(0, -0.015, 0), 0.085, 0.04, gunmetal)
	Models.box(_yaw, Vector3(0, 0.03, 0), Vector3(0.07, 0.05, 0.22), gunmetal)
	for s: float in [-1.0, 1.0]:
		Models.box(_yaw, Vector3(0, 0.075, s * 0.1), Vector3(0.07, 0.11, 0.02), gunmetal)
	_pitch = Node3D.new()
	_pitch.position = Vector3(0, BARREL_TIP.y, 0)
	_yaw.add_child(_pitch)
	Models.box(_pitch, Vector3(-0.04, 0, 0), Vector3(0.3, 0.12, 0.13), olive)
	Models.box(_pitch, Vector3(-0.04, 0.0, 0.0651), Vector3(0.22, 0.03, 0.002), hazard)
	Models.cylinder(_pitch, Vector3(0.3, 0, 0), 0.02, 0.44, steel, Vector3(0, 0, 90))
	Models.cylinder(_pitch, Vector3(0.24, 0, 0), 0.033, 0.24, dark, Vector3(0, 0, 90))
	Models.cylinder(_pitch, Vector3(BARREL_TIP.x - 0.03, 0, 0), 0.028, 0.06, gunmetal, Vector3(0, 0, 90))
	Models.box(_pitch, Vector3(-0.06, -0.025, -0.11), Vector3(0.16, 0.11, 0.09), olive)
	Models.box(_pitch, Vector3(0.02, 0.085, 0), Vector3(0.12, 0.05, 0.08), dark)
	Models.sphere(_pitch, Vector3(0.082, 0.085, 0), 0.015, Models.emissive(Color(1.0, 0.15, 0.08), 3.0))
	_flash = MeshInstance3D.new()
	_flash.mesh = GunPod.flash_mesh()
	_flash.material_override = CrewWeapons.flash_material(Color(1.0, 0.62, 0.25), 4.0)
	_flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flash.position = Vector3(BARREL_TIP.x, 0, 0)
	_flash.rotation = Vector3(0, -PI / 2.0, 0)
	_flash.scale = Vector3.ONE * 0.45
	_flash.visible = false
	_pitch.add_child(_flash)
	# A wreck's sparks and smoke.
	_sparks = CPUParticles3D.new()
	_sparks.position = Vector3(0, 0.05, 0)
	_sparks.emitting = false
	_sparks.one_shot = true
	_sparks.explosiveness = 0.9
	_sparks.amount = 14
	_sparks.lifetime = 0.45
	var spark := BoxMesh.new()
	spark.size = Vector3(0.006, 0.03, 0.006)
	spark.material = Models.glow(Color(1.6, 1.0, 0.4))
	_sparks.mesh = spark
	_sparks.particle_flag_align_y = true
	_sparks.direction = Vector3(0, 1, 0)
	_sparks.spread = 70.0
	_sparks.initial_velocity_min = 1.2
	_sparks.initial_velocity_max = 3.0
	_sparks.gravity = Vector3(0, -7.0, 0)
	_pitch.add_child(_sparks)
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 25.0
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 0.5
	pm.gravity = Vector3(0, 0.25, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.2
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
	fade.colors = PackedColorArray([Color(0.3, 0.3, 0.3, 0.0), Color(0.25, 0.25, 0.25, 0.35), Color(0.2, 0.2, 0.2, 0.0)])
	var ft := GradientTexture1D.new()
	ft.gradient = fade
	pm.color_ramp = ft
	_smoke = GPUParticles3D.new()
	_smoke.amount = 10
	_smoke.lifetime = 2.6
	_smoke.local_coords = false
	_smoke.emitting = false
	_smoke.process_material = pm
	_smoke.draw_pass_1 = GunPod.smoke_mesh()
	_smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_smoke.position = Vector3(0, 0.1, 0)
	_yaw.add_child(_smoke)
	_apply_pose(0.0)


## Text on the display (a single-line Label3D is centred on its origin, so one anchored by its left
## edge is moved by half its width).
func _display_text(parent: Node3D, pos: Vector3, text: String, size: int, align: HorizontalAlignment) -> Label3D:
	var l := Label3D.new()
	l.font = GunPod.mono_font()
	l.font_size = size
	l.pixel_size = 0.0011
	l.outline_size = 0
	l.modulate = GunPod.GREEN
	l.double_sided = false
	l.position = pos
	l.text = text
	if align == HORIZONTAL_ALIGNMENT_LEFT:
		l.offset.x = l.font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x * 0.5
	parent.add_child(l)
	return l


# --- Every peer --------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if _ship == null or _visual == null:
		return
	if multiplayer.is_server():
		_server_tick(delta)
	_apply_pose(delta)


## Unfold or fold up as its state says, turn the gun to its aim (bent and sparking once wrecked), the
## muzzle flash, the display, and its body (solid while it stands open).
func _apply_pose(delta: float) -> void:
	var wrecked := s_state == WRECKED
	var want := 1.0 if s_state == OPENING or s_state == ACTIVE or wrecked else 0.0
	_open = want if delta <= 0.0 else move_toward(_open, want, delta / OPEN_TIME)
	var lid := smoothstep(0.0, 0.5, _open)
	var up := smoothstep(0.35, 1.0, _open)
	for i in _lids.size():
		var s := -1.0 if i == 0 else 1.0
		# (A wreck's lid halves hang at odd angles.)
		var bend := (0.35 if i == 0 else -0.6) if wrecked else 0.0
		_lids[i].rotation.x = s * (deg_to_rad(118.0) * lid + bend)
	_post.position = PIVOT - Vector3(0, SINK * (1.0 - up), 0)
	_ram.scale = Vector3(1.0, maxf(_post.position.y - _ram.position.y - 0.02, 0.01), 1.0)
	_aim_shown = _aim_shown.lerp(s_aim, NetUtil.smooth(16.0, maxf(delta, 0.0)) if delta > 0.0 else 1.0)
	_kick = maxf(0.0, _kick - delta * 12.0)
	if wrecked:
		_post.rotation = Vector3(0.12, 0.0, -0.2)
		_yaw.rotation.y = _aim_shown.x
		_pitch.rotation = Vector3(0.3, 0.0, -0.45)
	else:
		_post.rotation = Vector3.ZERO
		_yaw.rotation.y = _aim_shown.x
		_pitch.rotation = Vector3(0, 0, _aim_shown.y)
		_pitch.position = Vector3(-0.02 * _kick, BARREL_TIP.y, 0)
	_since_shot += delta
	if _flash_t > 0.0:
		_flash_t -= delta
		if _flash_t <= 0.0:
			_flash.visible = false
	_smoke.emitting = wrecked
	if wrecked:
		_spark_t -= delta
		if _spark_t <= 0.0:
			_spark_t = randf_range(0.35, 1.6)
			_sparks.restart()
	var solid := s_state != PACKED and carrier == 0
	_body.collision_layer = Game.LAYER_STATION if solid else 0
	# (Its floating name only while it is a box: open, the gun stands where the name would hang.)
	if _label:
		_label.visible = carrier == 0 and s_state == PACKED
	_show_display()


## The display at its back: the rounds left and what it is doing.
func _show_display() -> void:
	var note := "PACKED"
	var col := GunPod.AMBER
	match s_state:
		OPENING:
			note = "ARMING"
		CLOSING:
			note = "FOLDING"
		ACTIVE:
			note = "EMPTY" if s_rounds <= 0 else ("FIRING" if _since_shot < 0.4 else "GUARDING")
			col = GunPod.RED if s_rounds <= 0 else GunPod.GREEN
		WRECKED:
			note = "DESTROYED"
			col = GunPod.RED
	var text := "%03d|%s" % [s_rounds, note]
	if text == _shown_text:
		return
	_shown_text = text
	_count.text = "--" if s_state == WRECKED else "%03d" % s_rounds
	_count.modulate = col if s_state != ACTIVE else (GunPod.AMBER if s_rounds < ROUNDS / 5 else GunPod.GREEN)
	_note.text = note
	_note.modulate = col
	_lamp.emission = col
	_lamp.emission_energy_multiplier = 0.4 if s_state == WRECKED else 2.0


## Where the muzzle is (global), as the gun is turned now.
func muzzle_global() -> Vector3:
	return _pitch.global_transform * Vector3(BARREL_TIP.x, 0, 0) if _pitch else global_position


## Every peer: a round out of the gun to ship-local `end_local`; `flesh`: it hit an alien.
@rpc("authority", "call_local", "unreliable")
func fx_shot(end_local: Vector3, flesh: bool) -> void:
	if _ship == null or _pitch == null:
		return
	var muzzle := muzzle_global()
	var end := _ship.to_global(end_local)
	if randf() < 0.55:
		Fx.tracer(muzzle, end, COLOR, 0.016, 0.05)
	Fx.impact(end, (muzzle - end).normalized(), Color(0.6, 1.0, 0.3) if flesh else Color(1.0, 0.6, 0.3), 0.8 if flesh else 0.6)
	_flash.visible = true
	_flash.rotation.z = randf() * TAU
	_flash_t = 0.04
	_since_shot = 0.0
	_kick = 1.0
	Sfx.play("hmg", muzzle, -6.0, randf_range(1.4, 1.5))


## Every peer: it opens up (or folds up): servos and latches.
@rpc("authority", "call_local", "reliable")
func fx_open(opening: bool) -> void:
	Sfx.play("clunk", global_position, -4.0, 1.3 if opening else 1.1)
	Sfx.play("scan_whirr", global_position, -6.0, 0.7 if opening else 0.6)


## Every peer: it is wrecked: a burst of sparks and a bang.
@rpc("authority", "call_local", "reliable")
func fx_wreck() -> void:
	var at := global_transform * Vector3(0, 0.35, 0)
	Fx.sparks(at, Color(1.0, 0.7, 0.3), 40, 7.0, 0.04, 0.7)
	Fx.explosion(at, 0.9, Color(1.0, 0.55, 0.2))
	Sfx.play("explosion", at, -4.0, 1.8)


## The line the crew sees looking at it.
func prompt_line() -> String:
	match s_state:
		WRECKED:
			return "Sentry turret - wrecked, beyond repair"
		OPENING:
			return "Sentry turret - unfolding"
		CLOSING:
			return "Sentry turret - folding up"
		ACTIVE:
			return "Sentry turret - %d rounds left   [F] Fold it up (to carry it elsewhere)" % s_rounds
	if not can_open_here():
		return "[E] Pick up the Sentry Turret - set it down in a station, then F opens it"
	return "[F] Open the sentry turret here: it guards 45 degrees either side of its front (where the arrows point)   [E] Pick up"


## True where it may open: out of the ship at the abandoned station it is landed at.
func can_open_here() -> bool:
	return _ship != null and _ship.derelict_k >= 0 and _ship.landing == Mothership.Dock.LANDED and not _ship.is_aboard(net_pos)


# --- Server --------------------------------------------------------------------------------------

## Server: open it (set down in a station, folded).
func server_open() -> void:
	if s_state != PACKED or carrier != 0 or not can_open_here():
		return
	s_state = OPENING
	_state_t = 0.0
	fx_open.rpc(true)


## Server: fold it up again (open and intact).
func server_fold() -> void:
	if s_state != ACTIVE:
		return
	s_state = CLOSING
	_state_t = 0.0
	_target = 0
	fx_open.rpc(false)


## Server: damage from an alien (a claw, a leap, a glob of acid). Wrecked once it has taken HP.
func hurt(amount: float) -> void:
	if not multiplayer.is_server() or not standing():
		return
	s_hp = maxf(0.0, s_hp - amount)
	if s_hp <= 0.0:
		s_state = WRECKED
		_target = 0
		fx_wreck.rpc()


func _server_tick(delta: float) -> void:
	match s_state:
		OPENING:
			_state_t += delta
			if _state_t >= OPEN_TIME:
				s_state = ACTIVE
		CLOSING:
			_state_t += delta
			s_aim = s_aim.move_toward(Vector2.ZERO, TURN * delta)
			if _state_t >= OPEN_TIME:
				s_state = PACKED
				s_aim = Vector2.ZERO
		ACTIVE:
			_think(delta)


## Server, open: look for the nearest alien it can hit, swing to it and fire while the aim is on it.
func _think(delta: float) -> void:
	_cd = maxf(0.0, _cd - delta)
	_retarget_t -= delta
	if _retarget_t <= 0.0:
		_retarget_t = RETARGET * randf_range(0.8, 1.2)
		_target = _pick_target()
	var t := instance_from_id(_target) as Boarder if _target != 0 else null
	if t == null or not is_instance_valid(t) or t.hp <= 0.0 or t.is_queued_for_deletion():
		_target = 0
		s_aim = s_aim.move_toward(Vector2.ZERO, TURN * 0.3 * delta)
		return
	var want := _aim_at(t.center_global())
	s_aim = s_aim.move_toward(want, TURN * delta)
	if s_rounds > 0 and _cd <= 0.0 and s_aim.distance_to(want) < AIM_TOLERANCE:
		_cd = FIRE_INTERVAL
		_fire()


## The nearest alien within RANGE, inside its arc and in sight of the gun (crawlers' nests last).
func _pick_target() -> int:
	var pivot := global_transform * PIVOT
	var space := get_world_3d().direct_space_state
	var best := 0
	var best_score := INF
	for n in _ship.boarder_root.get_children():
		var b := n as Boarder
		if b == null or b.hp <= 0.0 or not b.outside or b.is_queued_for_deletion():
			continue
		var at := b.center_global()
		var d := pivot.distance_to(at)
		if d > RANGE:
			continue
		var a := _aim_at(at, false)
		if absf(a.x) > ARC + 0.03 or a.y < PITCH_MIN - 0.03 or a.y > PITCH_MAX + 0.03:
			continue
		var score := d + (25.0 if b.kind == "hive" else 0.0)
		if score >= best_score:
			continue
		var q := PhysicsRayQueryParameters3D.create(pivot, at, Game.LAYER_STATION | Game.LAYER_INTERIOR | Game.LAYER_HULL)
		q.exclude = [_body.get_rid()]
		if not space.intersect_ray(q).is_empty():
			continue
		best_score = score
		best = b.get_instance_id()
	return best


## The aim (yaw from its front, pitch) at global point `at`, kept to what it can turn to.
func _aim_at(at: Vector3, clamp_it := true) -> Vector2:
	var d := global_transform.affine_inverse() * at - PIVOT - Vector3(0, BARREL_TIP.y, 0)
	var a := Vector2(atan2(-d.z, d.x), atan2(d.y, Vector2(d.x, d.z).length()))
	if clamp_it:
		a = Vector2(clampf(a.x, -ARC, ARC), clampf(a.y, PITCH_MIN, PITCH_MAX))
	return a


## Server: one round, scattered a little, at whatever is in its way; an alien hit takes DAMAGE (and
## knows the sentry did it).
func _fire() -> void:
	s_rounds -= 1
	var muzzle := muzzle_global()
	var aim_basis := global_basis * Basis(Vector3.UP, s_aim.x) * Basis(Vector3.BACK, s_aim.y)
	var dir := Mothership.scatter(aim_basis * Vector3.RIGHT, SPREAD)
	var q := PhysicsRayQueryParameters3D.create(muzzle, muzzle + dir * RANGE * 1.4, CrewWeapons.shot_mask())
	q.collide_with_areas = true
	q.exclude = [_body.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var end := muzzle + dir * RANGE * 1.4
	var flesh := false
	if not hit.is_empty():
		end = hit["position"]
		var col: Object = hit["collider"]
		if col.has_meta("boarder"):
			var b := _ship.boarder_root.get_node_or_null(str(col.get_meta("boarder"))) as Boarder
			if b:
				flesh = true
				b.take_damage(DAMAGE, {"source": "sentry", "sentry": str(name)})
	fx_shot.rpc(_ship.to_local(end), flesh)
