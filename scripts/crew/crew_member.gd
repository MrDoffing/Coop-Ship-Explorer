class_name CrewMember
extends CharacterBody3D
## A crew member inside the mothership.
##
## Each client simulates its own avatar (it is that node's multiplayer authority) in ship-local
## space, so walking stays responsive while the ship moves. Stations are driven by sending input
## to the server every physics tick; cameras for stations are placed locally from the player's own
## aim so looking around never waits for the network.
##
## While the ship is docked at a waystation the crew can walk down the cargo ramp into the shop
## (ship-local space still works: the ship is parked), buy supplies with the dive's credits and
## carry the crates aboard. At an abandoned station they explore its rooms the same way.
##
## Slot 1 holds the crew member's hand weapon (CrewWeapons; the Pistol at the start of a dive),
## slot 2 the toolkit. Looking at a crate with another hand weapon, F swaps the two. A magazine
## weapon's trigger only clicks once it runs dry, until R swaps the magazine; a heat weapon vents
## (R, or by itself once it overheats). Switching to the toolkit, taking a station, picking up a
## crate or bringing out the scanner cuts a reload short.
##
## Walking, the crew member sees the world from inside their helmet (Helmet: its edge, the
## instruments in its chin, the visor that seals outside the ship) and the weapon in front of them
## (WeaponRig): held relaxed until it fires (LMB, from the hip: a wide scatter) or is aimed down its
## own sight (RMB: accurate, slower on the feet, the view zooms in). Most weapons fire while LMB is
## held, the semi-automatic ones once a click. Every shot kicks the view up, and shots in quick
## succession scatter wider (and with some weapons kick harder). Holding Q brings out the
## echolocation scanner (Scanner) instead.
##
## Crew bots are CrewMembers with `bot = true`: the server owns them and a CrewBot brain drives
## them (repairs and side guns); everyone else sees them like any other crew member.
##
## A gunner sits inside the gun pod (GunPod) and looks out through its sight in first person; the
## heavy pod swings after the mouse at its own pace. Everyone else sees the gunner in the pod.
##
## The pilot sits in the cockpit (Cockpit) in first person too, behind the glazed nose: the mouse
## turns their head (as far as a seated pilot can) and RMB leans in towards what they look at.
##
## A scout's pilot climbs into the scout and flies it from its cockpit (ScoutCockpit), in first
## person: the mouse steers, RMB holds the sight on an alien to lock a missile on.

const WALK := 4.6
const SPRINT := 7.2
const ACCEL := 45.0
const JUMP := 4.8
const GRAVITY := 14.0
const EYE := 1.62
const REACH := 2.7
const RESPAWN_TIME := 8.0
## The walking field of view (degrees).
const FOV := 78.0
## Aiming down the sight: seconds to bring it up to the eye, and the walking speed meanwhile (share
## of WALK).
const ADS_TIME := 0.16
const ADS_SPEED := 0.55
## The weapon comes up to fire in RAISE_TIME (a shot waits for it) and is held relaxed again once it
## has not fired for RELAX_WALK seconds on the move (RELAX_STILL standing still).
const RAISE_TIME := 0.12
const LOWER_TIME := 0.35
const RELAX_WALK := 0.8
const RELAX_STILL := 1.6
## Extra scatter (radians) firing on the move (from the hip, and aimed), and in the air.
const MOVE_SPREAD := 0.02
const MOVE_SPREAD_ADS := 0.004
const AIR_SPREAD := 0.04
## Each shot kicks the view up (CrewWeapons "kick"); this much of it comes back by itself, at this
## rate.
const KICK_RECOVER := 0.75
const KICK_RATE := 12.0
## What everyone else sees the crew member doing with their weapon (`pose`).
enum Pose { RELAXED, READY, AIM, SCAN }

var peer_id := 1
var display_name := ""
var color := Color.WHITE
## Server-controlled crew bot (negative peer_id, server authority).
var bot := false
## The bot's AI (server only).
var brain: CrewBot

# Replicated (owned by the player).
var net_pos := Vector3.ZERO
var look_yaw := 0.0
var look_pitch := 0.0
var station := ""
var tool := 0
## Hand weapon (CrewWeapons id), and whether it is being reloaded.
var weapon := CrewWeapons.DEFAULT
var reloading := false
var hp := 100.0
var max_hp := 100.0
var alive := true

var ship: Mothership
var camera: Camera3D
## Gun / mining aim relative to the mount, or the scout's (yaw, pitch) while flying it. In a gun
## pod this is where the gunner wants it to point; pod_aim is where the pod points as it swings
## after it.
var station_aim := Vector2.ZERO
var pod_aim := Vector2.ZERO
## Interaction hint shown by the HUD.
var prompt := ""
## The supply crate this crew member is carrying, if any (looked up every tick).
var carrying: SupplyCrate
var respawn_left := 0.0
var hurt_flash := 0.0
## Shots left in the hand weapon's magazine (owner only; the server's for bots).
var ammo := 0
## Replicated: what the crew member is doing with their weapon (Pose).
var pose := Pose.RELAXED
## Heat weapons (owner only): the heat (0..1), whether it overheated (locked until it has cooled),
## and the Lightning Thrower's charge (0..1).
var heat := 0.0
var overheated := false
var charge := 0.0
## Q held: the scanner is up and the weapon down (owner only).
var scanning := false

var _body: Node3D
var _head: Node3D
var _held: Array[Node3D] = []
## The first-person view (the camera's child, scaled so the zoom of aiming leaves it the same size
## on screen): the weapon, the helmet and the scanner.
var _view: Node3D
var _rig: WeaponRig
var _helmet: Helmet
var _scanner: Scanner
## Third person: the scanner in front of the chest, the weapon's pose and its muzzle flash.
var _scan_box: Node3D
var _held_pos := CrewWeapons.HELD_POS
var _held_rot := Vector3.ZERO
var _flash3_t := 0.0
## Aiming (0..1 down the sight), the weapon raised (0 relaxed .. 1), sprinting (0..1), time since
## the last shot, the scatter that builds up with quick shots, the part of the view's kick still to
## come back, where a vent started from, a shot waiting for the weapon to come up, and how fast the
## view turns (for the weapon's sway).
var _aim_t := 0.0
var _ready_t := 0.0
var _sprint_t := 0.0
var _sprinting := false
var _since_shot := 10.0
var _bloom := 0.0
var _kick_debt := 0.0
## The last shot's kick (radians; for the tests).
var _last_kick := 0.0
var _vent_from := 1.0
var _fire_queued := 0.0
var _look_acc := Vector2.ZERO
var _look_vel := Vector2.ZERO
var _charge_snd: AudioStreamPlayer
## The hand weapon the models currently show.
var _shown_weapon := ""
var _name_label: Label3D
var _cam_light: OmniLight3D
var _recall_hold := 0.0
var _fire_cd := 0.0
var _reload_left := 0.0
var _was_reloading := false
## How far the held weapon is tipped for a reload (0..1, third person).
var _reload_pose := 0.0
var _repair_acc := 0.0
var _repair_sys := ""
var _repair_send := 0.0
var _repair_fx := 0.0
var _last_hurt := -100.0
var _clock := 0.0
## The orbiting camera that watches the ship while knocked out.
var _chase_yaw := 0.0
var _chase_pitch := -0.22
## The pilot's head: yaw and pitch relative to looking straight ahead from the seat.
var _pilot_look := Vector2(0.0, Cockpit.LOOK_REST)
## Leaning into a gun pod's sight, or towards the dashboard or the glass in the cockpit (0..1, RMB).
var _lean := 0.0
var _bob := 0.0
var _was_on_floor := true
## Flashlight: on while out exploring an abandoned station.
var _flashlight: SpotLight3D
var _lamp_mat: StandardMaterial3D
var _flash_on := false
## The keypad lock whose panel the crew member has gone into (owner only; see HackPanel), and where
## they look on it (yaw, pitch away from straight at it).
var _panel: HackPanel
var _panel_look := Vector2.ZERO


func _init() -> void:
	NetUtil.add_sync(self, ["net_pos", "look_yaw", "look_pitch"], ["station", "tool", "weapon", "reloading", "hp", "max_hp", "alive", "pose"], 1.0 / 30.0)


func setup(data: Dictionary) -> void:
	peer_id = int(data["id"])
	name = str(peer_id)
	display_name = str(data["name"])
	color = Game.PLAYER_COLORS[int(data["color"]) % Game.PLAYER_COLORS.size()]
	max_hp = float(data["hp"])
	hp = max_hp
	position = data["pos"]
	net_pos = position
	bot = bool(data.get("bot", false))
	set_multiplayer_authority(1 if bot else peer_id)


func _ready() -> void:
	ship = get_parent().get_parent().get_parent() as Mothership
	collision_layer = Game.LAYER_PLAYER
	collision_mask = Game.LAYER_INTERIOR | Game.LAYER_STATION | Game.LAYER_BARRIER
	platform_floor_layers = 0
	floor_snap_length = 0.3
	safe_margin = 0.02
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.8
	shape.shape = cap
	shape.position = Vector3(0, 0.9, 0)
	add_child(shape)
	ammo = CrewWeapons.mag(weapon)
	_build_body()
	if bot and multiplayer.is_server():
		brain = CrewBot.new(self)
	if is_multiplayer_authority() and not bot:
		camera = Camera3D.new()
		camera.fov = FOV
		camera.near = 0.05
		camera.far = 700.0
		camera.top_level = true
		camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		add_child(camera)
		camera.current = true
		# Soft fill light that follows exterior cameras so the dark cave stays readable.
		_cam_light = OmniLight3D.new()
		_cam_light.omni_range = 45.0
		_cam_light.light_energy = 0.45
		_cam_light.light_color = Color(0.85, 0.9, 1.0)
		# (In a gun pod it hangs out in front of the glass; no lamp is there to glare in it.)
		_cam_light.light_cull_mask &= ~Game.VIS_GLASS
		camera.add_child(_cam_light)
		_build_viewmodel()
		_flashlight = _make_flashlight(camera, Vector3(0.18, -0.1, 0.0), true)
		# The helmet round the eye would only catch the torch's glare.
		_flashlight.light_cull_mask &= ~Game.VIS_VIEWMODEL
		_charge_snd = AudioStreamPlayer.new()
		_charge_snd.stream = Sfx.stream("charge_loop")
		_charge_snd.volume_db = -30.0
		add_child(_charge_snd)
		_body.visible = false
		look_yaw = rotation.y
		if Game.mission:
			Game.mission.set_local_player(self)
		Game.main.restore_mouse()
	else:
		_name_label = Label3D.new()
		_name_label.text = display_name + (" [BOT]" if bot else "")
		_name_label.font_size = 48
		_name_label.pixel_size = 0.005
		_name_label.outline_size = 10
		_name_label.modulate = color
		_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_name_label.position = Vector3(0, 2.2, 0)
		_name_label.no_depth_test = true
		add_child(_name_label)
		_flashlight = _make_flashlight(_head, Vector3(0.14, 0.06, -0.2), false)


func _exit_tree() -> void:
	if Game.mission and Game.mission.get("local_player") == self:
		Game.mission.set("local_player", null)


func _build_body() -> void:
	_body = Node3D.new()
	add_child(_body)
	var suit := Models.mat(color.lerp(Color(0.35, 0.37, 0.4), 0.45), 0.3, 0.6)
	var accent := Models.mat(color, 0.2, 0.5)
	var dark := Models.mat(Color(0.12, 0.13, 0.15), 0.4, 0.6)
	Models.capsule(_body, Vector3(0, 1.05, 0), 0.3, 1.05, suit)
	Models.box(_body, Vector3(0, 1.2, 0.27), Vector3(0.45, 0.55, 0.22), dark)
	Models.box(_body, Vector3(0, 1.32, -0.2), Vector3(0.36, 0.12, 0.12), accent)
	for side: float in [-1.0, 1.0]:
		Models.capsule(_body, Vector3(side * 0.13, 0.4, 0), 0.11, 0.8, suit)
		Models.capsule(_body, Vector3(side * 0.34, 1.12, -0.12), 0.08, 0.6, suit, Vector3(70, 0, 0))
	_head = Node3D.new()
	_head.position = Vector3(0, 1.62, 0)
	_body.add_child(_head)
	Models.sphere(_head, Vector3.ZERO, 0.24, Models.mat(Color(0.85, 0.86, 0.88), 0.3, 0.4))
	Models.sphere(_head, Vector3(0, 0.0, -0.1), 0.18, Models.emissive(color, 1.5, Color(0.05, 0.08, 0.1)), Vector3(1.0, 0.75, 0.8))
	if bot:
		# Bots wear an antenna so they are easy to tell apart.
		Models.cylinder(_head, Vector3(0.1, 0.32, 0.05), 0.012, 0.3, Models.mat(Color(0.6, 0.6, 0.62), 0.7, 0.3))
		Models.sphere(_head, Vector3(0.1, 0.48, 0.05), 0.04, Models.emissive(Color(1.0, 0.3, 0.2), 4.0))
	# Held tools (third person): the hand weapon (built by _show_weapon) and the toolkit.
	var gun := Node3D.new()
	gun.position = CrewWeapons.HELD_POS
	_body.add_child(gun)
	var toolkit := Node3D.new()
	toolkit.position = Vector3(0.3, 1.1, -0.45)
	_body.add_child(toolkit)
	Models.box(toolkit, Vector3.ZERO, Vector3(0.08, 0.08, 0.45), Models.mat(Color(0.7, 0.7, 0.72), 0.7, 0.3))
	Models.box(toolkit, Vector3(0, 0, -0.25), Vector3(0.2, 0.08, 0.1), Models.mat(Color(0.95, 0.75, 0.15), 0.4, 0.5))
	_held = [gun, toolkit]
	# The scanner, held up in front of the chest while it is out.
	_scan_box = Node3D.new()
	_scan_box.position = Vector3(0.0, 1.32, -0.36)
	_scan_box.rotation = Vector3(0.5, 0, 0)
	_scan_box.visible = false
	_body.add_child(_scan_box)
	Models.box(_scan_box, Vector3.ZERO, Vector3(0.17, 0.125, 0.045), Models.mat(Color(0.25, 0.27, 0.2), 0.35, 0.7))
	Models.cylinder(_scan_box, Vector3(0, 0.004, -0.024), 0.05, 0.006, Models.emissive(Color(0.35, 1.0, 0.45), 1.2), Vector3(90, 0, 0))
	Models.strut(_scan_box, Vector3(0, -0.06, 0.0), Vector3(0.0, -0.2, 0.16), 0.012, Models.mat(Color(0.35, 0.36, 0.36), 0.8, 0.35))
	# Helmet lamp (it lights up with the flashlight).
	_lamp_mat = StandardMaterial3D.new()
	_lamp_mat.albedo_color = Color(0.2, 0.2, 0.2)
	_lamp_mat.emission_enabled = true
	_lamp_mat.emission = Color(1.0, 0.95, 0.8)
	_lamp_mat.emission_energy_multiplier = 0.0
	Models.cylinder(_head, Vector3(0.14, 0.06, -0.14), 0.05, 0.1, _lamp_mat, Vector3(90, 0, 0))


## The first-person view: the weapon (and toolkit), the helmet round the eye and the scanner.
func _build_viewmodel() -> void:
	_view = Node3D.new()
	_view.name = "View"
	camera.add_child(_view)
	_rig = WeaponRig.new()
	_view.add_child(_rig)
	_rig.build(self)
	_helmet = Helmet.new()
	_view.add_child(_helmet)
	_helmet.build(self)
	_scanner = Scanner.new()
	_view.add_child(_scanner)
	_scanner.build(self)


## Rebuild the hand weapon models (first person and third person) when the weapon changes.
func _show_weapon() -> void:
	if weapon == _shown_weapon:
		return
	_shown_weapon = weapon
	for c in _held[0].get_children():
		_held[0].remove_child(c)
		c.queue_free()
	CrewWeapons.build_model(_held[0], weapon, color, false)
	if _rig:
		_rig.set_weapon(weapon)


## The parts of the weapon in the crew member's hand (third person).
func _held_parts() -> Dictionary:
	if _held.is_empty() or _held[0].get_child_count() == 0:
		return {}
	return CrewWeapons.parts_of(_held[0].get_child(0) as Node3D)


## The flashlight is on (out in an abandoned station).
func lamp_on() -> bool:
	return _flash_on


# --- Per-frame ---------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_clock += delta
	_show_weapon()
	if bot:
		if multiplayer.is_server():
			_bot_physics(delta)
		else:
			_remote_update(delta)
		return
	if not is_multiplayer_authority():
		_remote_update(delta)
		return
	if ship == null or not is_instance_valid(ship):
		return
	carrying = ship.crate_carried_by(peer_id)
	_sync_max_hp()
	_fire_cd = maxf(0.0, _fire_cd - delta)
	_tick_reload(delta)
	_tick_weapon(delta)
	hurt_flash = maxf(0.0, hurt_flash - delta * 1.5)
	if not alive:
		scanning = false
		charge = 0.0
		respawn_left -= delta
		if respawn_left <= 0.0:
			_respawn()
		net_pos = position
		return
	if hp < max_hp and _clock - _last_hurt > 6.0:
		hp = minf(max_hp, hp + 4.0 * delta)
	var blocked := Game.ui_blocking
	if station != "":
		_station_physics(blocked)
	elif _panel:
		_panel_physics(delta, blocked)
	else:
		_walk(delta, blocked)
		_interact(delta, blocked)
	_flush_repair(delta)
	# Safety net: never let the avatar fall out of the ship (or off the pier while docked).
	if not _in_bounds(position):
		position = ship.spawn_points()[0]
		velocity = Vector3.ZERO
		reset_physics_interpolation()
	net_pos = position
	_update_held()


## Where a crew member may be (ship-local): inside the ship, plus the ramp, pier and station
## building while docked.
func _in_bounds(p: Vector3) -> bool:
	return ship.walk_bounds().has_point(p)


## Max health follows the ship's crew stats (crew armour from waystations raises it).
func _sync_max_hp() -> void:
	var want := float(ship.stats.get("crew_hp", max_hp))
	if absf(want - max_hp) > 0.01:
		if want > max_hp and alive:
			hp += want - max_hp
		max_hp = want
		hp = minf(hp, max_hp)


func _process(delta: float) -> void:
	if is_multiplayer_authority() and camera:
		_update_camera(delta)
	_update_flashlight()


## A flashlight (off) under `parent`, pointing along its -Z.
func _make_flashlight(parent: Node3D, offset: Vector3, local: bool) -> SpotLight3D:
	var l := SpotLight3D.new()
	l.position = offset
	l.spot_range = 24.0 if local else 18.0
	l.spot_angle = 28.0
	l.spot_attenuation = 0.8
	l.light_energy = 3.2 if local else 2.2
	l.light_color = Color(1.0, 0.95, 0.85)
	# A projector only shows on a light with shadows.
	l.light_projector = Models.light_cookie("flashlight")
	l.shadow_enabled = true
	l.visible = false
	parent.add_child(l)
	return l


## The flashlight comes on by itself out in an abandoned station and goes off back aboard.
func _update_flashlight() -> void:
	if _flashlight == null or ship == null or not is_instance_valid(ship):
		return
	var on := alive and ship.landing == Mothership.Dock.LANDED and ship.derelict_k >= 0 and not ship.is_aboard(position)
	if on != _flash_on:
		_flash_on = on
		_flashlight.visible = on
		_lamp_mat.emission_energy_multiplier = 3.0 if on else 0.0
		if camera and not bot:
			Sfx.play("ui", null, -14.0, 1.7)
	if on and _flashlight.get_parent() == _head:
		# The head only pitches part of the way; the lamp follows the rest of the look.
		_flashlight.rotation.x = look_pitch * 0.4


## Server: crew bot update (the CrewBot brain does the thinking).
func _bot_physics(delta: float) -> void:
	if ship == null or not is_instance_valid(ship):
		return
	hurt_flash = maxf(0.0, hurt_flash - delta * 1.5)
	_sync_max_hp()
	if not alive:
		respawn_left -= delta
		if respawn_left <= 0.0:
			_respawn()
			brain.reset()
	else:
		if hp < max_hp and _clock - _last_hurt > 6.0:
			hp = minf(max_hp, hp + 4.0 * delta)
		_tick_reload(delta)
		brain.tick(delta)
		pose = Pose.READY if brain.is_fighting() else Pose.RELAXED
		var held := _held_by()
		if held:
			position = held.reel(position, delta)
			velocity = Vector3.ZERO
	net_pos = position
	_head.rotation.x = look_pitch * 0.6
	_show_body()
	_update_held()


func _unhandled_input(event: InputEvent) -> void:
	if bot or not is_multiplayer_authority() or Game.ui_blocking or not alive:
		return
	if _panel:
		# In a keypad lock's panel: the mouse looks over it, the number keys key digits in.
		if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			var dm: Vector2 = (event as InputEventMouseMotion).relative * Game.mouse_sensitivity
			_panel_look.x = clampf(_panel_look.x - dm.x, -0.45, 0.45)
			_panel_look.y = clampf(_panel_look.y - dm.y * (-1.0 if Game.invert_y else 1.0), -0.4, 0.4)
		elif event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
			var key := (event as InputEventKey).keycode
			var label := ""
			if key >= KEY_0 and key <= KEY_9:
				label = str(key - KEY_0)
			elif key >= KEY_KP_0 and key <= KEY_KP_9:
				label = str(key - KEY_KP_0)
			elif key == KEY_BACKSPACE:
				label = "<"
			elif key == KEY_DELETE:
				label = "C"
			if label != "":
				_panel_key(label)
				get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var d: Vector2 = (event as InputEventMouseMotion).relative * Game.mouse_sensitivity
		if Game.invert_y:
			d.y = -d.y
		match station:
			"":
				# Aimed down a sight the view is zoomed in, so the mouse turns it as much less.
				if camera:
					d *= tan(deg_to_rad(camera.fov) * 0.5) / tan(deg_to_rad(FOV) * 0.5)
				look_yaw = wrapf(look_yaw - d.x, -PI, PI)
				look_pitch = clampf(look_pitch - d.y, -1.45, 1.45)
				_look_acc += Vector2(-d.x, -d.y)
			"pilot":
				_pilot_look.x = clampf(_pilot_look.x - d.x, -Cockpit.LOOK_YAW, Cockpit.LOOK_YAW)
				_pilot_look.y = clampf(_pilot_look.y - d.y, -Cockpit.LOOK_DOWN, Cockpit.LOOK_UP)
			_:
				if ship.is_turret_station(station):
					var t: Turret = ship.turrets[station]
					# In a gun pod the view turns with the aim, so it takes the walking sensitivity.
					station_aim = t.clamp_aim(station_aim + Vector2(-d.x, -d.y) * (1.0 if t is GunPod else 0.75))
				elif ship.is_scout_station(station):
					station_aim.x = wrapf(station_aim.x - d.x, -PI, PI)
					station_aim.y = clampf(station_aim.y - d.y, -1.45, 1.45)


## The barnacle holding this crew member (see Barnacle), or null.
func _held_by() -> Barnacle:
	if ship == null or ship.derelict_k < 0:
		return null
	for c in ship.boarder_root.get_children():
		var b := c as Barnacle
		if b and b.grab == peer_id and not b.is_queued_for_deletion():
			return b
	return null


func _walk(delta: float, blocked: bool) -> void:
	var held := _held_by()
	if held:
		# Caught by a barnacle: reeled in and held off the floor under it (looking about and shooting
		# still work).
		velocity = Vector3.ZERO
		position = held.reel(position, delta)
		rotation.y = look_yaw
		_sprinting = false
		_sprint_t = move_toward(_sprint_t, 0.0, delta / 0.2)
		return
	var input := Vector2.ZERO if blocked else Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var local_dir := Basis(Vector3.UP, look_yaw) * Vector3(input.x, 0, input.y)
	var dir := ship.global_basis * local_dir
	# Aiming down the sight slows the crew member down; firing or aiming cuts a sprint short.
	var busy := tool == 0 and not scanning and carrying == null and not blocked \
		and (Input.is_action_pressed("fire") or Input.is_action_pressed("aim") or charge > 0.0)
	_sprinting = not blocked and Input.is_action_pressed("sprint") and not busy and input.length() > 0.1
	_sprint_t = move_toward(_sprint_t, 1.0 if _sprinting else 0.0, delta / 0.2)
	var speed := WALK * ADS_SPEED if _aim_t > 0.3 else (SPRINT if _sprinting else WALK)
	var hv := Vector3(velocity.x, 0, velocity.z).move_toward(dir * speed, ACCEL * delta)
	velocity.x = hv.x
	velocity.z = hv.z
	if is_on_floor():
		if not blocked and Input.is_action_just_pressed("jump"):
			velocity.y = JUMP
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()
	rotation.y = look_yaw
	if is_on_floor():
		_bob += hv.length() * delta * 1.7
	_was_on_floor = is_on_floor()


## Look at stations / repair panels, switch tools, shoot and repair, hold the scanner up.
func _interact(delta: float, blocked: bool) -> void:
	if not blocked:
		if Input.is_action_just_pressed("tool_blaster"):
			tool = 0
		elif Input.is_action_just_pressed("tool_toolkit"):
			tool = 1
		elif Input.is_action_just_pressed("tool_next") or Input.is_action_just_pressed("tool_prev"):
			tool = 1 - tool
	scanning = not blocked and carrying == null and Input.is_action_pressed("scanner")
	var eye := _eye_global()
	var dir := _look_dir_global()
	var q := PhysicsRayQueryParameters3D.create(eye, eye + dir * REACH, Game.LAYER_INTERACT | Game.LAYER_INTERIOR | Game.LAYER_STATION)
	q.collide_with_areas = true
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	prompt = ""
	var col: Object = hit.get("collider")
	if carrying:
		_weapon_input(delta, true)
		_interact_carrying(col, blocked)
		return
	if col is Area3D and col.has_meta("crate"):
		var crate := ship.cargo_root.get_node_or_null(str(col.get_meta("crate"))) as SupplyCrate
		if crate and crate.carrier == 0 and crate.price > 0:
			if ship.credits >= crate.price:
				prompt = "[E] Buy %s for %d CR - %s" % [RunItems.display_name(crate.item), crate.price, RunItems.describe(crate.item)]
				if not blocked and Input.is_action_just_pressed("interact"):
					ship.request_crate_buy.rpc_id(1, str(crate.name))
			else:
				prompt = "%s costs %d CR - you have %d CR" % [RunItems.display_name(crate.item), crate.price, ship.credits]
		elif crate and crate.carrier == 0 and RunItems.is_crew_weapon(crate.item):
			var w := RunItems.crew_weapon_of(crate.item)
			if w == weapon:
				prompt = "%s - you already carry one   [E] Pick up" % CrewWeapons.display_name(w)
			else:
				prompt = "[F] Equip %s (your %s goes in the crate)   [E] Pick up - %s" % [CrewWeapons.display_name(w),
					CrewWeapons.display_name(weapon), RunItems.describe(crate.item)]
				if not blocked and Input.is_action_just_pressed("equip"):
					ship.request_weapon_swap.rpc_id(1, str(crate.name))
			if not blocked and Input.is_action_just_pressed("interact"):
				ship.request_crate_pickup.rpc_id(1, str(crate.name))
		elif crate and crate.carrier == 0:
			prompt = "[E] Pick up %s - %s" % [RunItems.display_name(crate.item), RunItems.describe(crate.item)]
			if not blocked and Input.is_action_just_pressed("interact"):
				ship.request_crate_pickup.rpc_id(1, str(crate.name))
	elif col is Area3D and col.has_meta("install_hub"):
		prompt = "Install hub - carry supply crates here from a waystation"
	elif col is Area3D and col.has_meta("sell_pad"):
		prompt = "Buyback - carry a crate here to sell it for %d%% of its price" % int(RunItems.SELL_SHARE * 100.0)
	elif col is Area3D and col.has_meta("station"):
		var id := str(col.get_meta("station"))
		var holder := int(ship.occupants.get(id, 0))
		if Net.is_bot(holder):
			prompt = "[E] %s (take over from %s)" % [_station_verb(id), Net.player_name(holder)]
			if not blocked and Input.is_action_just_pressed("interact"):
				ship.request_station.rpc_id(1, id)
		elif holder != 0 and holder != peer_id:
			prompt = "%s - in use by %s" % [ship.station_name(id), Net.player_name(holder)]
		elif ship.is_scout_station(id) and Game.mission.scout_at(id) and not Game.mission.scout_at(id).can_launch():
			prompt = Game.mission.scout_at(id).status_text()
		else:
			prompt = "[E] %s" % _station_verb(id)
			if not blocked and Input.is_action_just_pressed("interact"):
				ship.request_station.rpc_id(1, id)
	elif col is Area3D and col.has_meta("repair"):
		var sys := str(col.get_meta("repair"))
		var label := "Engine" if sys == "engine" else "Weapon systems"
		var value := ship.system_hp(sys)
		var state := "" if ship.system_online(sys) else " OFFLINE"
		if tool == 1:
			if value >= 100.0:
				prompt = "%s fully repaired" % label
			else:
				prompt = "[Hold LMB] Repair %s - %d%%%s" % [label, int(value), state]
				if not blocked and Input.is_action_pressed("fire"):
					_repair_acc += delta
					_repair_sys = sys
					_repair_fx -= delta
					if _repair_fx <= 0.0:
						_repair_fx = 0.22
						Fx.sparks(hit["position"], Color(0.5, 0.9, 1.0), 6, 4.0, 0.03, 0.3)
						Sfx.play("repair", hit["position"], -8.0)
		else:
			prompt = "%s %d%%%s - switch to the toolkit [2] to repair" % [label, int(value), state]
	elif col is Area3D and col.has_meta("emergency"):
		if ship.blast_cd > 0.0:
			prompt = "Emergency blast recharging (%d s)" % int(ceil(ship.blast_cd))
		else:
			prompt = "[E] EMERGENCY BLAST - kills nearby aliens; costs hull, fuel and shields"
			if not blocked and Input.is_action_just_pressed("interact"):
				ship.cockpit.press_button()
				ship.request_blast.rpc_id(1)
	elif col is Area3D and col.has_meta("hack"):
		_hack_prompt(int(col.get_meta("hack")), blocked)
	elif col is Area3D and col.has_meta("generator"):
		if ship.outpost_power:
			prompt = "Generator running"
		else:
			prompt = "[E] Pull the generator's starter cord"
			if not blocked and Input.is_action_just_pressed("interact"):
				ship.request_generator.rpc_id(1)
	if prompt == "" and _held_by():
		prompt = "A barnacle has you - shoot it!"
	_weapon_input(delta, blocked)


## The state of door `di` at the abandoned station the ship is landed at (Derelict.DOOR_*).
func _door_state(di: int) -> int:
	if ship.outpost_k == ship.derelict_k and di >= 0 and di < ship.outpost_doors.size():
		return ship.outpost_doors[di]
	return Derelict.DOOR_CLOSED


## Looking at a keypad lock: E goes into its panel while the door is locked.
func _hack_prompt(di: int, blocked: bool) -> void:
	var node: Derelict = Derelict.live.get(ship.derelict_k)
	var panel := node.panel_of(di) if node else null
	if panel == null:
		return
	match _door_state(di):
		Derelict.DOOR_OPEN:
			prompt = "Door open"
		Derelict.DOOR_LOCKDOWN:
			prompt = "LOCKED DOWN - this door won't open again"
		_:
			var left := OutpostLayout.HACK_TRIES - (ship.outpost_tries[di] if di < ship.outpost_tries.size() else 0)
			prompt = "[E] Open the lock's panel - trace each lit colour's cord to its digit; %d tr%s before it locks down" % [left,
				"y" if left == 1 else "ies"]
			if not blocked and Input.is_action_just_pressed("interact"):
				_enter_panel(panel)


func _enter_panel(panel: HackPanel) -> void:
	_panel = panel
	_panel_look = Vector2.ZERO
	velocity = Vector3.ZERO
	scanning = false
	charge = 0.0
	_fire_queued = 0.0
	# Face it (as everyone else sees it).
	var to := ship.to_local(panel.global_position) - position
	look_yaw = atan2(-to.x, -to.z)
	look_pitch = 0.0
	panel.enter()


func _leave_panel() -> void:
	if _panel and is_instance_valid(_panel):
		_panel.leave()
	_panel = null


## In a keypad lock's panel: the view rests on it (see _update_camera), LMB presses the key in the
## middle of the view, and E, walking off, a hit or the door no longer being locked takes you out.
func _panel_physics(delta: float, blocked: bool) -> void:
	velocity = Vector3(0, 0.0 if is_on_floor() else velocity.y - GRAVITY * delta, 0)
	move_and_slide()
	pose = Pose.RELAXED
	var leave := not is_instance_valid(_panel) or ship.derelict_k < 0 or _door_state(_panel.door) != Derelict.DOOR_CLOSED \
		or ship.to_local(_panel.global_position).distance_to(position + Vector3(0, EYE, 0)) > 3.5
	if not blocked and (Input.is_action_just_pressed("interact") or Input.get_vector("move_left", "move_right", "move_forward", "move_back").length() > 0.5):
		leave = true
	if leave:
		_leave_panel()
		return
	# (The keys are stencilled on the panel; a prompt would cover the wiring.)
	prompt = ""
	var label := _panel.key_at(camera.global_position, -camera.global_basis.z) if camera else ""
	_panel.hover(label)
	if not blocked and Input.is_action_just_pressed("fire"):
		_panel_key(label)


func _panel_key(label: String) -> void:
	if _panel == null or not is_instance_valid(_panel):
		return
	var code := _panel.press(label)
	if code != "":
		ship.request_hack.rpc_id(1, _panel.door, code)


## The hand weapon: R reloads (vents a heat weapon), RMB aims down the sight, LMB fires once the
## weapon is up (a quick click waits for it), from the hip or aimed: for as long as it is held, or
## for a semi-automatic weapon once a click (as fast as the clicks come); the Lightning Thrower
## charges while LMB is held and lets go on release. Nothing fires with the scanner up, the toolkit
## out or a crate in hand. An empty magazine only clicks; an overheated weapon only fizzles.
func _weapon_input(delta: float, blocked: bool) -> void:
	var armed := tool == 0 and not scanning and carrying == null and not blocked
	var trigger := armed and Input.is_action_pressed("fire")
	var aim_held := armed and Input.is_action_pressed("aim") and not reloading
	_aim_t = move_toward(_aim_t, 1.0 if aim_held else 0.0, delta / ADS_TIME)
	var local_v := ship.global_basis.inverse() * velocity
	var moving := Vector2(local_v.x, local_v.z).length() > 0.6
	# (The weapon comes up for a reload too, so the swap is in view.)
	var want_up := armed and not _sprinting and (trigger or aim_held or charge > 0.0 or _fire_queued > 0.0 or reloading
		or _since_shot < (RELAX_WALK if moving else RELAX_STILL))
	_ready_t = move_toward(_ready_t, 1.0 if want_up else 0.0, delta / (RAISE_TIME if want_up else LOWER_TIME))
	pose = Pose.SCAN if scanning else (Pose.AIM if _aim_t > 0.5 else (Pose.READY if _ready_t > 0.5 else Pose.RELAXED))
	if not armed:
		_fire_queued = 0.0
		if charge > 0.0:
			charge = 0.0
		return
	if Input.is_action_just_pressed("reload"):
		start_reload()
	var clicked := Input.is_action_just_pressed("fire")
	if clicked:
		_fire_queued = 0.3
	var up := _ready_t >= 0.8 or _aim_t >= 0.5
	if weapon == "lightning":
		_charge_input(delta, trigger, up, clicked)
		return
	if CrewWeapons.uses_heat(weapon):
		if overheated or reloading:
			_fire_queued = 0.0
			if clicked:
				Sfx.play("fizzle", null, -9.0)
			return
	elif ammo <= 0 and not reloading:
		_fire_queued = 0.0
		if clicked:
			# Empty: the hammer falls on nothing until R swaps the magazine.
			Sfx.play("dry_fire", null, -6.0)
		return
	var pulled := _fire_queued > 0.0 if CrewWeapons.semi(weapon) else (trigger or _fire_queued > 0.0)
	if pulled and up and _fire_cd <= 0.0 and not reloading:
		_shoot()


## The Lightning Thrower: holding LMB charges it (once it is up), letting go lets the bolt go if it
## is charged enough (a weak fizzle otherwise). Held at full charge it slowly heats up.
func _charge_input(delta: float, trigger: bool, up: bool, clicked: bool) -> void:
	_fire_queued = 0.0
	if overheated or reloading:
		charge = 0.0
		if clicked:
			Sfx.play("fizzle", null, -9.0)
		return
	if trigger:
		if up and _fire_cd <= 0.0:
			charge = minf(1.0, charge + delta / CrewWeapons.CHARGE_TIME)
			if charge >= 1.0:
				_add_heat(delta * 0.08)
	elif charge > 0.0:
		if charge >= CrewWeapons.CHARGE_MIN:
			_discharge(charge)
		else:
			Sfx.play("fizzle", null, -13.0, 1.4)
		charge = 0.0


## Interaction while carrying a crate: no tools; install it at the hub or a gun console, or drop it.
func _interact_carrying(col: Object, blocked: bool) -> void:
	var item := carrying.item
	var gun := RunItems.is_weapon(item)
	var name_s := RunItems.display_name(item)
	var target := ""
	if RunItems.is_credits(item):
		# Paid in once it is put down aboard (or handed in at the install hub).
		if col is Area3D and col.has_meta("install_hub"):
			prompt = "[E] Deposit %d CR" % RunItems.credits_of(item)
			target = "hub"
		elif ship.is_aboard(position):
			prompt = "[G] Put the credit box down to deposit %d CR" % RunItems.credits_of(item)
	elif col is Area3D and col.has_meta("sell_pad"):
		prompt = "[E] Sell %s for %d CR (%d%% of its price)" % [name_s, RunItems.sell_price(item, ship.station_k),
			int(RunItems.SELL_SHARE * 100.0)]
		target = "sell"
	elif RunItems.is_crew_weapon(item):
		if col is Area3D and (col.has_meta("install_hub") or col.has_meta("station")):
			prompt = "Hand weapons aren't installed - [G] put the crate down, then [F] to equip it"
		elif col is Area3D and (col.has_meta("repair") or col.has_meta("crate")):
			prompt = "Your hands are full - [G] drop the crate"
	elif col is Area3D and col.has_meta("install_hub"):
		if gun:
			prompt = "Guns are mounted at a GUN console"
		elif item == "autocannon" and ship.autocannons >= ship.turret_slots():
			prompt = "Every turret slot is taken" if ship.turret_slots() > 0 else "This ship has no turret slots"
		else:
			prompt = "[E] Install %s" % name_s
			target = "hub"
	elif col is Area3D and col.has_meta("station"):
		var id := str(col.get_meta("station"))
		if ship.station_kind(id) == "gun" and gun:
			var current := ship.gun_weapon(id)
			prompt = "[E] Mount %s on the %s (replaces the %s)" % [name_s, ship.station_name(id).to_lower(),
				Game.GUNS[current]["name"]]
			target = id
		elif gun:
			prompt = "Mount guns at a GUN console"
		else:
			prompt = "Fit this at the INSTALL HUB in the %s" % ship.install_hub_room()
	elif col is Area3D and (col.has_meta("repair") or col.has_meta("crate")):
		prompt = "Your hands are full - [G] drop the crate"
	if blocked:
		return
	if target == "sell" and Input.is_action_just_pressed("interact"):
		ship.request_sell.rpc_id(1, str(carrying.name))
	elif target != "" and Input.is_action_just_pressed("interact"):
		ship.request_install.rpc_id(1, str(carrying.name), target)
	elif Input.is_action_just_pressed("drop"):
		_drop_carried()


## Put the carried crate down in front of us (or at our feet if a wall is in the way).
func _drop_carried() -> void:
	var space := get_world_3d().direct_space_state
	var mask := Game.LAYER_INTERIOR | Game.LAYER_STATION | Game.LAYER_BARRIER
	var spot := position + Basis(Vector3.UP, look_yaw) * Vector3(0, 0, -0.95)
	var q := PhysicsRayQueryParameters3D.create(_eye_global(), ship.to_global(spot + Vector3(0, 0.9, 0)), mask)
	q.exclude = [get_rid()]
	if not space.intersect_ray(q).is_empty():
		spot = position
	var down := PhysicsRayQueryParameters3D.create(ship.to_global(spot + Vector3(0, 1.0, 0)), ship.to_global(spot + Vector3(0, -3.0, 0)), mask)
	down.exclude = [get_rid()]
	var hit := space.intersect_ray(down)
	spot.y = ship.to_local(hit["position"]).y if not hit.is_empty() else position.y
	ship.request_crate_drop.rpc_id(1, str(carrying.name), spot + Vector3(0, SupplyCrate.SIZE.y * 0.5, 0), look_yaw + PI / 2.0)


func _station_verb(id: String) -> String:
	match ship.station_kind(id):
		"pilot":
			return "Pilot the ship"
		"gun":
			return "Man the %s" % ship.station_name(id).to_lower()
		"laser":
			return "Operate the %s" % ship.station_name(id).to_lower()
		"scout":
			var bay := ship.station_name(id)
			return "Launch the scout" + (bay.substr(bay.length() - 2) if bay.ends_with(" A") or bay.ends_with(" B") else "")
	return "Use"


func _flush_repair(delta: float) -> void:
	_repair_send += delta
	if _repair_send < 0.1:
		return
	_repair_send = 0.0
	if _repair_acc > 0.0 and _repair_sys != "":
		ship.request_repair.rpc_id(1, _repair_sys, _repair_acc)
	_repair_acc = 0.0


## Start reloading the hand weapon (R; crew bots do it by themselves): swap the magazine, or vent a
## heat weapon. False when there is nothing to do, it is already at it or its owner is knocked out.
func start_reload() -> bool:
	if reloading or not alive:
		return false
	if CrewWeapons.uses_heat(weapon):
		if heat <= 0.05:
			return false
		_vent_from = heat
	elif ammo >= CrewWeapons.mag(weapon):
		return false
	reloading = true
	_reload_left = CrewWeapons.reload_time(weapon)
	_reload_sound(true)
	if bot:
		_drop_held_mag()
	return true


## How far along the current reload (or vent) is (0..1; 0 when not reloading).
func reload_progress() -> float:
	if not reloading:
		return 0.0
	if CrewWeapons.uses_heat(weapon):
		return clampf(1.0 - heat / maxf(_vent_from, 0.01), 0.0, 1.0)
	return clampf(1.0 - _reload_left / CrewWeapons.reload_time(weapon), 0.0, 1.0)


## Reload progress (run by the owner; by the server for bots). Switching to the toolkit, taking a
## station, picking up a crate, bringing out the scanner or being knocked out cuts a player's
## reload (or vent) short. A vent bleeds the heat off (an overheated weapon vents slower) and ends
## when it is cold.
func _tick_reload(delta: float) -> void:
	if not reloading:
		return
	if not alive or (not bot and (tool != 0 or station != "" or carrying != null or scanning)):
		reloading = false
		return
	if CrewWeapons.uses_heat(weapon):
		var rate := 1.0 / (CrewWeapons.reload_time(weapon) * (CrewWeapons.OVERHEAT_VENT if overheated else 1.0))
		heat = maxf(0.0, heat - delta * rate)
		if heat <= 0.0:
			reloading = false
			overheated = false
			_reload_sound(false)
		return
	_reload_left -= delta
	if _reload_left <= 0.0:
		reloading = false
		ammo = CrewWeapons.mag(weapon)
		_reload_sound(false)


## Reload sounds, as it starts and ends: venting steam, or (for everyone else, and the bots) the
## magazine coming out and the slide racked; a player's own magazine swap sounds step by step from
## their weapon (WeaponRig). In 2D for your own avatar, from the crew member's hands for everyone
## else.
func _reload_sound(starting: bool) -> void:
	var id := ""
	if CrewWeapons.uses_heat(weapon):
		id = ("overheat_vent" if overheated else "vent") if starting else "vent_done"
	elif camera == null:
		if weapon in WeaponRig.CYLINDER:
			id = "cyl_open" if starting else "cyl_close"
		else:
			id = "mag_out" if starting else ("pump" if weapon == "shotgun" else "rack")
	if id == "":
		return
	if camera:
		Sfx.play(id, null, -9.0)
	else:
		Sfx.play(id, global_transform * CrewWeapons.HELD_POS, -4.0)


## Owner (and the server for bots): the weapon settles after shooting, and heat bleeds off.
func _tick_weapon(delta: float) -> void:
	_since_shot += delta
	_fire_queued = maxf(0.0, _fire_queued - delta)
	if _since_shot > 0.12:
		_bloom *= exp(-delta / 0.25)
	# Most of each shot's kick comes back by itself.
	if _kick_debt > 0.0001:
		var back := _kick_debt * (1.0 - exp(-KICK_RATE * delta))
		_kick_debt -= back
		look_pitch = clampf(look_pitch - back, -1.45, 1.45)
	if CrewWeapons.uses_heat(weapon) and not reloading:
		if _since_shot > CrewWeapons.COOL_DELAY and charge <= 0.0:
			heat = maxf(0.0, heat - delta * float(CrewWeapons.def(weapon)["cool"]))
		if overheated and heat < 0.35:
			overheated = false
	if _charge_snd:
		var on := charge > 0.0 and alive
		if on != _charge_snd.playing:
			if on:
				_charge_snd.play()
			else:
				_charge_snd.stop()
		if on:
			_charge_snd.pitch_scale = 0.7 + charge * 0.9
			_charge_snd.volume_db = -22.0 + charge * 8.0


## The scatter of the next shot (radians): from the hip or aimed, what quick shots have built up,
## and more on the move or in the air.
func _spread() -> float:
	var d := CrewWeapons.def(weapon)
	var e := smoothstep(0.0, 1.0, _aim_t)
	var s := lerpf(float(d["hip"]), float(d["ads"]), e) + _bloom
	var local_v := ship.global_basis.inverse() * velocity
	if Vector2(local_v.x, local_v.z).length() > 0.6:
		s += lerpf(MOVE_SPREAD, MOVE_SPREAD_ADS, e)
	if not is_on_floor():
		s += AIR_SPREAD
	return s


## A shot's kick: the view jumps up (and a little sideways); most of it comes back by itself.
func _kick_view(amount: float) -> void:
	var k := amount * randf_range(0.85, 1.15) * (0.7 if _aim_t > 0.5 else 1.0)
	_last_kick = k
	look_pitch = clampf(look_pitch + k, -1.45, 1.45)
	look_yaw = wrapf(look_yaw + randf_range(-0.3, 0.3) * k, -PI, PI)
	_kick_debt += k * KICK_RECOVER


## Heat a heat weapon up; at full heat it overheats and vents, locked until it is cold.
func _add_heat(amount: float) -> void:
	heat = minf(1.0, heat + amount)
	if heat >= 1.0 and not overheated:
		overheated = true
		charge = 0.0
		reloading = true
		_vent_from = 1.0
		_reload_sound(true)
		if camera:
			Sfx.play("overheat", null, -10.0)


## Where the weapon's muzzle is (global): the first-person model's for your own avatar.
func _muzzle_global() -> Vector3:
	if _rig and _rig.model:
		return _rig.model.global_transform * (_rig.parts.get("muzzle", Vector3.ZERO) as Vector3)
	return global_transform * CrewWeapons.held_muzzle(weapon)


## Nothing solid between two points (global)?
func _clear_line(a: Vector3, b: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(a, b, Game.LAYER_INTERIOR | Game.LAYER_STATION)
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


## Let the Lightning Thrower's bolt go (charge `c`): it strikes the closest alien within the cone in
## front (in plain view, within range) and jumps on to the closest alien near that one, and so on,
## each jump a little weaker. With no alien to strike it hits whatever is ahead.
func _discharge(c: float) -> void:
	var d := CrewWeapons.def("lightning")
	_fire_cd = float(d["cooldown"])
	_since_shot = 0.0
	var eye := _eye_global()
	var aim := _look_dir_global()
	var reach := float(d["range"])
	var cone := deg_to_rad(lerpf(CrewWeapons.BOLT_CONE, CrewWeapons.BOLT_CONE_ADS, smoothstep(0.0, 1.0, _aim_t)))
	var struck: Array[Boarder] = []
	var first: Boarder = null
	var best := reach
	for n in ship.boarder_root.get_children():
		var b := n as Boarder
		if b == null or b.hp <= 0.0 or b.is_queued_for_deletion():
			continue
		var at := b.center_global()
		var dist := eye.distance_to(at)
		if dist < best and aim.angle_to(at - eye) <= cone and _clear_line(eye, at):
			best = dist
			first = b
	var muzzle := _muzzle_global()
	var points := PackedVector3Array([muzzle])
	if first:
		struck.append(first)
		var last := first
		for k in CrewWeapons.CHAIN_JUMPS:
			var next: Boarder = null
			var near := CrewWeapons.CHAIN_RANGE
			for n in ship.boarder_root.get_children():
				var b := n as Boarder
				if b == null or b.hp <= 0.0 or b.is_queued_for_deletion() or struck.has(b):
					continue
				var dd := last.center_global().distance_to(b.center_global())
				if dd < near and _clear_line(last.center_global(), b.center_global()):
					near = dd
					next = b
			if next == null:
				break
			struck.append(next)
			last = next
		var dmg := lerpf(float(d["damage"]), float(d["damage_max"]), c) * float(ship.stats["blaster_damage"]) / CrewWeapons.BASE_DAMAGE
		for i in struck.size():
			points.append(struck[i].center_global())
			ship.hit_boarder.rpc_id(1, str(struck[i].name), dmg * pow(CrewWeapons.CHAIN_FALLOFF, i))
		if Game.mission and Game.mission.hud:
			Game.mission.hud.hit_marker()
	else:
		var q := PhysicsRayQueryParameters3D.create(eye, eye + aim * reach, Game.LAYER_INTERIOR | Game.LAYER_STATION)
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		points.append(hit["position"] if not hit.is_empty() else eye + aim * reach)
	CrewWeapons.lightning_fx(points, c, struck.size(), true)
	var local_points := PackedVector3Array()
	for p in points:
		local_points.append(ship.to_local(p))
	ship.fx_lightning.rpc(local_points, c, struck.size())
	_kick_view(float(d["kick"]) * (0.5 + c))
	if Game.mission:
		Game.mission.shake(0.1 + 0.15 * c)
	if _rig:
		_rig.shot()
	_add_heat(float(d["heat"]) + float(d["heat_charge"]) * c)


## Fire the hand weapon: hitscan pellets (piercing for the Marksman Rifle), their damage falling
## off with distance for some weapons, or a grenade; scattered by _spread(). Hits on aliens are sent
## to the server, the effects to everyone. A weapon with "kick_grow" kicks harder the more its
## scatter has built up with quick shots.
func _shoot() -> void:
	var d := CrewWeapons.def(weapon)
	_fire_cd = float(d["cooldown"])
	_fire_queued = 0.0
	var heat_weapon := CrewWeapons.uses_heat(weapon)
	if not heat_weapon:
		ammo -= 1
	var eye := _eye_global()
	var aim := _look_dir_global()
	var reach := float(d["range"])
	var dmg := float(d["damage"]) * float(ship.stats["blaster_damage"]) / CrewWeapons.BASE_DAMAGE
	var muzzle := _muzzle_global()
	var space := get_world_3d().direct_space_state
	var ends := PackedVector3Array()
	var normals := PackedVector3Array()
	var hit_mask := 0
	var flesh_mask := 0
	var spread := _spread()
	var up := ship.global_basis.y if absf(aim.dot(ship.global_basis.y)) < 0.99 else ship.global_basis.z
	var frame := Basis.looking_at(aim, up)
	if d.has("grenade"):
		_launch_grenade(d, muzzle, frame, spread, dmg)
	else:
		# Alien name -> damage dealt by this shot.
		var dealt := {}
		var pierce := int(d.get("pierce", 1))
		for i in int(d["pellets"]):
			var dir := aim
			if spread > 0.0:
				var r := spread * sqrt(randf())
				var a := randf() * TAU
				dir = (frame * Vector3(cos(a) * r, sin(a) * r, -1.0)).normalized()
			var end := eye + dir * reach
			var normal := -dir
			var exclude: Array[RID] = [get_rid()]
			for k in pierce:
				var q := PhysicsRayQueryParameters3D.create(eye, eye + dir * reach, CrewWeapons.shot_mask())
				q.collide_with_areas = true
				q.exclude = exclude
				var hit := space.intersect_ray(q)
				if hit.is_empty():
					end = eye + dir * reach
					break
				end = hit["position"]
				normal = hit["normal"]
				hit_mask |= 1 << i
				var col: Object = hit["collider"]
				if not col.has_meta("boarder"):
					break
				flesh_mask |= 1 << i
				var who := str(col.get_meta("boarder"))
				dealt[who] = float(dealt.get(who, 0.0)) + dmg * CrewWeapons.falloff(weapon, eye.distance_to(end))
				# A heavy round carries on through the alien.
				exclude.append(hit["rid"])
			ends.append(end)
			normals.append(normal)
		for who: String in dealt:
			ship.hit_boarder.rpc_id(1, who, float(dealt[who]))
		if not dealt.is_empty() and Game.mission and Game.mission.hud:
			Game.mission.hud.hit_marker()
	# A heat weapon's report rises as it heats up; a magazine running low ticks hollow, and the last
	# round out of it rings.
	CrewWeapons.shot_fx(weapon, muzzle, ends, normals, hit_mask, flesh_mask, true, lerpf(1.0, 1.18, heat) if heat_weapon else 1.0)
	if not heat_weapon:
		if ammo == 0:
			Sfx.play("mag_ping", null, -15.0)
		elif ammo <= maxi(2, int(CrewWeapons.mag(weapon) * 0.25)):
			Sfx.play("low_ammo", null, -17.0)
	var grow := 1.0 + float(d.get("kick_grow", 0.0)) * _bloom / maxf(float(d["bloom_max"]), 0.0001)
	_since_shot = 0.0
	_bloom = minf(float(d["bloom_max"]), _bloom + float(d["bloom"]))
	_kick_view(float(d["kick"]) * grow)
	if _rig:
		_rig.shot(grow)
	if heat_weapon:
		_add_heat(float(d["heat"]))
	var local_ends := PackedVector3Array()
	var local_normals := PackedVector3Array()
	for i in ends.size():
		local_ends.append(ship.to_local(ends[i]))
		local_normals.append(ship.global_basis.inverse() * normals[i])
	ship.fx_weapon.rpc(weapon, ship.to_local(muzzle), local_ends, local_normals, hit_mask, flesh_mask)


## Launch a grenade (the Multiple Grenade Launcher): out of the muzzle along the aim, scattered by
## `spread` and lifted a little above the aim (the sight is set for about ten metres), carried along
## with the crew member's own movement. It is this crew member's own (Grenades): where it goes off,
## it asks the server for the blast's damage (`dmg` in its middle) and tells everyone else.
func _launch_grenade(d: Dictionary, muzzle: Vector3, frame: Basis, spread: float, dmg: float) -> void:
	var g: Dictionary = d["grenade"]
	var r := spread * sqrt(randf())
	var a := randf() * TAU
	var dir := (frame * Vector3(cos(a) * r, sin(a) * r + float(g["lift"]), -1.0)).normalized()
	var inv := ship.global_basis.inverse()
	var from_local := ship.to_local(muzzle)
	var vel_local := inv * (dir * float(g["speed"]) + velocity)
	var fuse := float(g["fuse"])
	var splash := float(g["splash"])
	var id := Grenades.next_id(peer_id)
	var s := ship
	Grenades.of(ship).launch(id, from_local, vel_local, fuse, true, func(at_local: Vector3):
		if is_instance_valid(s):
			s.crew_splash.rpc_id(1, at_local, splash, dmg)
			s.fx_grenade_burst.rpc(id, at_local))
	ship.fx_grenade.rpc(id, from_local, vel_local, fuse)


func _station_physics(blocked: bool) -> void:
	velocity = Vector3.ZERO
	var st := ship.console(station)
	position = st["seat"]
	rotation.y = st["seat_yaw"]
	var scout: Scout = Game.mission.scout_at(station) if ship.is_scout_station(station) else null
	if not blocked and Input.is_action_just_pressed("interact"):
		if scout:
			scout.request_dock.rpc_id(1)
		else:
			exit_station(true)
			return
	# Holding E in the scout abandons the flight: the scout is recalled and its cargo is lost.
	if scout and not blocked and Input.is_action_pressed("interact"):
		_recall_hold += get_physics_process_delta_time()
		if _recall_hold >= 2.0:
			_recall_hold = -100.0
			scout.request_recall.rpc_id(1)
	else:
		_recall_hold = 0.0
	var data := {}
	match ship.station_kind(station):
		"pilot":
			if not blocked:
				data["throttle"] = Input.get_axis("move_back", "move_forward")
				data["turn"] = Input.get_axis("move_right", "move_left")
				data["vert"] = Input.get_axis("descend", "jump")
				data["stop"] = Input.is_action_pressed("full_stop")
				# T and B, or a click on the autopilot switch or the red button the pilot looks at.
				var pressed := ship.cockpit.hovered if Input.is_action_just_pressed("fire") else ""
				if Input.is_action_just_pressed("autopilot") or pressed == "auto":
					ship.toggle_autopilot.rpc_id(1)
				if Input.is_action_just_pressed("emergency") or pressed == "blast":
					ship.cockpit.press_button()
					ship.request_blast.rpc_id(1)
				if Input.is_action_just_pressed("land"):
					ship.request_land.rpc_id(1)
			ship.station_input.rpc_id(1, station, data)
		"gun":
			# The pod is heavy: it swings after the aim at most GunPod.TURN_RATE (the short way round).
			var pod: Turret = ship.turrets[station]
			pod_aim = pod.clamp_aim(pod_aim + pod.aim_delta(pod_aim, station_aim).limit_length(GunPod.TURN_RATE * get_physics_process_delta_time()))
			data["aim"] = pod_aim
			data["fire"] = not blocked and Input.is_action_pressed("fire")
			ship.station_input.rpc_id(1, station, data)
		"laser":
			data["aim"] = station_aim
			data["fire"] = not blocked and Input.is_action_pressed("fire")
			ship.station_input.rpc_id(1, station, data)
		"scout":
			var mv := Vector3.ZERO
			if not blocked:
				mv = Vector3(Input.get_axis("move_left", "move_right"), Input.get_axis("descend", "jump"),
						Input.get_axis("move_back", "move_forward"))
			# RMB holds the sight on an alien to lock a missile on; LMB then fires a missile (one a
			# click) instead of the cannons.
			var targeting := not blocked and Input.is_action_pressed("aim")
			data = {"move": mv, "yaw": station_aim.x, "pitch": station_aim.y,
					"fire": not blocked and not targeting and Input.is_action_pressed("fire"),
					"boost": not blocked and Input.is_action_pressed("sprint")}
			if scout:
				scout.local_input = data
				scout.pilot_input.rpc_id(1, data)
				scout.cockpit.targeting = targeting
				if targeting and Input.is_action_just_pressed("fire"):
					scout.cockpit.fire_missile()


## Called when the server grants a station.
func enter_station(id: String) -> void:
	station = id
	var st := ship.console(id)
	position = st["seat"]
	rotation.y = st["seat_yaw"]
	velocity = Vector3.ZERO
	reset_physics_interpolation()
	_aim_t = 0.0
	_ready_t = 0.0
	charge = 0.0
	scanning = false
	match ship.station_kind(id):
		"gun", "laser":
			station_aim = ship.aim_of(id)
			pod_aim = station_aim
			_lean = 0.0
		"scout":
			station_aim = Vector2(ship.rotation.y, 0.15 if ship.dock_launch(id).y > 0.0 else -0.25)
		"pilot":
			_pilot_look = Vector2(0.0, Cockpit.LOOK_REST)
			_lean = 0.0
	Sfx.play("ui")


## Leave the current station (send = tell the server; false when the server already freed it).
func exit_station(send := true) -> void:
	if station == "":
		return
	var id := station
	if send:
		ship.release_station.rpc_id(1, id)
	station = ""
	var st := ship.console(id)
	var yaw: float = st["seat_yaw"]
	position = st["seat"] + Basis(Vector3.UP, yaw) * Vector3(0, 0.05, 0.9)
	look_yaw = yaw
	look_pitch = 0.0
	velocity = Vector3.ZERO
	reset_physics_interpolation()


## Server -> owner: the crew member swapped hand weapons at a crate.
@rpc("any_peer", "call_local", "reliable")
func set_weapon(id: String) -> void:
	if multiplayer.get_remote_sender_id() > 1 or not is_multiplayer_authority() or not CrewWeapons.exists(id):
		return
	weapon = id
	tool = 0
	_fire_cd = 0.4
	# A weapon out of a crate comes loaded (and cold).
	reloading = false
	ammo = CrewWeapons.mag(id)
	heat = 0.0
	overheated = false
	charge = 0.0
	_bloom = 0.0
	if not bot:
		Sfx.play("install", null, -10.0, 1.4)


# --- Damage and respawn ------------------------------------------------------------------------

## Server: damage this crew member (boarding aliens). Bots take it here, players on their client.
func hurt(amount: float) -> void:
	if not multiplayer.is_server() or not alive:
		return
	if bot:
		_apply_damage(amount)
	else:
		receive_damage.rpc_id(peer_id, amount)


## Server -> owner: take damage.
@rpc("any_peer", "call_local", "reliable")
func receive_damage(amount: float) -> void:
	if multiplayer.get_remote_sender_id() > 1:
		return
	if not is_multiplayer_authority() or not alive:
		return
	_apply_damage(amount)


func _apply_damage(amount: float) -> void:
	hp -= amount
	hurt_flash = 1.0
	_last_hurt = _clock
	# A hit pulls you out of a keypad lock's panel.
	_leave_panel()
	if not bot:
		if Game.mission:
			Game.mission.shake(0.25)
		Sfx.play("hull_hit", null, -10.0, 1.6)
	if hp <= 0.0:
		_die()


func _die() -> void:
	hp = 0.0
	alive = false
	respawn_left = RESPAWN_TIME
	if bot:
		if brain:
			brain.on_died()
		return
	if station != "":
		exit_station(true)
	Sfx.play("death", null, -4.0)
	if Game.mission and Game.mission.hud:
		Game.mission.hud.toast("You were knocked out!", 2)


func _respawn() -> void:
	alive = true
	hp = max_hp
	reloading = false
	ammo = CrewWeapons.mag(weapon)
	heat = 0.0
	overheated = false
	charge = 0.0
	_bloom = 0.0
	_kick_debt = 0.0
	position = ship.spawn_points().pick_random()
	velocity = Vector3.ZERO
	look_pitch = 0.0
	reset_physics_interpolation()


# --- Cameras and visuals -----------------------------------------------------------------------

func _eye_global() -> Vector3:
	return global_position + Vector3.UP * EYE


func _look_dir_global() -> Vector3:
	return ship.global_basis * (Basis(Vector3.UP, look_yaw) * Basis(Vector3.RIGHT, look_pitch) * Vector3.FORWARD)


func _update_camera(delta: float) -> void:
	var shake := Vector3.ZERO
	if Game.mission:
		shake = Game.mission.shake_offset()
	var ship_x := ship.get_global_transform_interpolated()
	_cam_light.visible = station != "" or not alive or not ship.alive
	_cam_light.position = Vector3.ZERO
	if station != "" or not alive or not ship.alive or _panel:
		# The helmet's visor and the scanner keep up while out of view.
		_helmet.update(delta, false)
		_scanner.update(delta, false)
	if not alive or not ship.alive:
		_chase_camera(ship_x, delta)
		camera.global_position += shake
		return
	if _panel and station == "":
		# Gone into a keypad lock's panel: the view rests on it and the mouse looks over it.
		var x := _panel.view_transform()
		var pb := x.basis * Basis(Vector3.UP, _panel_look.x) * Basis(Vector3.RIGHT, _panel_look.y)
		camera.global_transform = Transform3D(pb, x.origin + shake * 0.2)
		camera.fov = HackPanel.VIEW_FOV
		_view.visible = false
		return
	match station:
		"":
			var origin := get_global_transform_interpolated().origin + ship_x.basis.y * (EYE + sin(_bob * 2.0) * 0.03 * (1.0 - 0.8 * _aim_t))
			var b := ship_x.basis * Basis(Vector3.UP, look_yaw) * Basis(Vector3.RIGHT, look_pitch)
			camera.global_transform = Transform3D(b, origin + shake * 0.5)
			_update_view(delta)
		"pilot":
			_cockpit_camera(delta, shake)
			_view.visible = false
		_:
			if ship.is_turret_station(station) and ship.turrets[station] is GunPod:
				_pod_camera(ship.turrets[station] as GunPod, delta, shake)
			elif ship.is_turret_station(station):
				var t: Turret = ship.turrets[station]
				camera.global_transform = ship_x * t.camera_local(station_aim)
				camera.global_position += shake * 0.4
				camera.fov = 70.0 if not Input.is_action_pressed("aim") else 35.0
			elif ship.is_scout_station(station):
				_scout_camera(Game.mission.scout_at(station), ship_x, shake)
			_view.visible = false


## Walking: the view zooms in while aiming down the sight (the weapon, the helmet and the scanner are
## scaled so they stay the same size on screen), and the weapon, the helmet and the scanner follow
## the crew member.
func _update_view(delta: float) -> void:
	var e := smoothstep(0.0, 1.0, _aim_t)
	camera.fov = lerpf(FOV, CrewWeapons.aim_fov(weapon, FOV), e)
	var s := tan(deg_to_rad(camera.fov) * 0.5) / tan(deg_to_rad(FOV) * 0.5)
	_view.scale = Vector3(s, s, 1.0)
	_view.visible = true
	_look_vel = _look_vel.lerp(_look_acc / maxf(delta, 0.001), NetUtil.smooth(20.0, delta))
	_look_acc = Vector2.ZERO
	var local_v := ship.global_basis.inverse() * velocity
	_rig.update(delta, {"tool": tool, "ready": _ready_t, "aim": _aim_t, "sprint": _sprint_t,
		"holster": 1.0 if scanning or carrying != null else 0.0, "reloading": reloading, "progress": reload_progress(),
		"ammo": ammo, "heat": heat, "overheat": overheated, "charge": charge, "bob": _bob,
		"move": Vector2(local_v.x, local_v.z).length() / WALK, "look_vel": _look_vel})
	_helmet.update(delta, true)
	_scanner.update(delta, scanning)


## Inside a gun pod: the gunner's eye. It follows the pod's displayed (interpolated) transform, so
## the view and the pod around it never drift apart. Holding RMB leans in towards the sight, and
## the guns shake the view while they fire.
func _pod_camera(pod: GunPod, delta: float, shake: Vector3) -> void:
	var lean_in := Input.is_action_pressed("aim") and not Game.ui_blocking
	_lean = move_toward(_lean, 1.0 if lean_in else 0.0, delta * 4.0)
	var lean := smoothstep(0.0, 1.0, _lean)
	var x := pod.eye.get_global_transform_interpolated()
	var kick := pod.shake()
	var jitter := Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-0.5, 0.5)) * kick * 0.006
	# Leaning moves straight along the sight line, so the sight stays in the middle of the view.
	x.origin += x.basis * (Vector3(0, 0, -0.11) * lean + jitter) + shake * 0.3
	if kick > 0.0:
		x.basis = x.basis * Basis.from_euler(Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), 0.0) * kick * 0.003)
	camera.global_transform = x
	camera.fov = lerpf(74.0, 46.0, lean)
	# The fill light sits out in front of the glass: it lights the cave, not the cabin.
	_cam_light.position = Vector3(0, 0, -3.0)


## In the pilot seat: the pilot's eye in the cockpit, turned by their head. Holding RMB leans in
## along the look (to read a screen or peer out through the glass). The ship's knocks shake it.
func _cockpit_camera(delta: float, shake: Vector3) -> void:
	var lean_in := Input.is_action_pressed("aim") and not Game.ui_blocking
	_lean = move_toward(_lean, 1.0 if lean_in else 0.0, delta * 4.0)
	var lean := smoothstep(0.0, 1.0, _lean)
	var x := ship.cockpit.get_global_transform_interpolated() * Transform3D(Basis.IDENTITY, Cockpit.EYE)
	var b := x.basis * Basis(Vector3.UP, _pilot_look.x) * Basis(Vector3.RIGHT, _pilot_look.y)
	camera.global_transform = Transform3D(b, x.origin + b * Vector3(0, 0, -0.25) * lean + shake * 0.35)
	camera.fov = lerpf(74.0, 48.0, lean)
	# No fill light in the cockpit: the headlights and floods light the tunnel through the glass.
	_cam_light.visible = false


## Flying a scout: the pilot's eye in its cockpit, turning with the scout. The view kicks with the
## cannons, jolts with hits, and shakes and widens with the booster (ScoutCockpit). (The scout
## launches and docks within a tick of the station changing; meanwhile the view stays at the bay.)
func _scout_camera(scout: Scout, ship_x: Transform3D, shake: Vector3) -> void:
	_cam_light.visible = false
	if scout == null or scout.state != Scout.State.FLYING:
		var st := ship.console(station)
		camera.global_transform = ship_x * Transform3D(Basis(Vector3.UP, float(st["seat_yaw"])), (st["seat"] as Vector3) + Vector3.UP * 1.2)
		return
	var x := scout.get_global_transform_interpolated() * Transform3D(Basis.IDENTITY, ScoutCockpit.EYE) * scout.cockpit.view_shake()
	camera.global_transform = Transform3D(x.basis, x.origin + shake * 0.1)
	camera.fov = scout.cockpit.view_fov()


func _chase_camera(ship_x: Transform3D, _delta: float) -> void:
	var orbit := Basis(Vector3.UP, _chase_yaw) * Basis(Vector3.RIGHT, _chase_pitch)
	var focus := ship_x * Vector3(0, 2.5, -4.0)
	var pos := _clip_to_cave(focus, focus + ship_x.basis * (orbit * Vector3(0, 0, float(ship.layout.get("chase", 40.0)))))
	camera.global_transform = Transform3D(Basis.looking_at(focus - pos, ship_x.basis.y), pos)
	camera.fov = 72.0
	_view.visible = false


## Pull a camera in front of the rock between `from` and `to` (spring-arm style).
func _clip_to_cave(from: Vector3, to: Vector3) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(from, to, Game.LAYER_CAVE)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return to
	var dir := (to - from).normalized()
	var d := from.distance_to(hit["position"])
	return from + dir * maxf(d - 1.5, d * 0.5)


## The body as everyone else sees it: seated at a station's console, or gone into a gun pod or a
## scout (they show a figure of the gunner or pilot instead).
func _show_body() -> void:
	var in_pod := station != "" and ship.station_kind(station) in ["gun", "scout"]
	_body.visible = alive and not in_pod
	_body.position.y = -0.3 if station != "" else 0.0
	_name_label.visible = alive and not in_pod


## The weapon as everyone else sees it: held relaxed (pointing down across the body), raised, or up
## at the eye to aim; put away while the scanner is out (held in front of the chest instead). It
## tips over while the magazine is swapped.
func _update_held() -> void:
	var dt := get_physics_process_delta_time()
	var out := station == "" and carrying == null and pose != Pose.SCAN
	for i in _held.size():
		_held[i].visible = i == tool and out
	_scan_box.visible = station == "" and alive and pose == Pose.SCAN
	var want_pos := CrewWeapons.HELD_POS
	var want_rot := Vector3.ZERO
	match pose:
		Pose.RELAXED:
			want_pos = Vector3(0.22, 1.02, -0.42)
			want_rot = Vector3(-0.55, 0.5, -0.2)
		Pose.AIM:
			want_pos = Vector3(0.16, 1.47, -0.42)
			want_rot = Vector3(look_pitch * 0.6, 0.0, 0.0)
		_:
			want_rot = Vector3(look_pitch * 0.4, 0.0, 0.0)
	var k := NetUtil.smooth(10.0, dt)
	_held_pos = _held_pos.lerp(want_pos, k)
	_held_rot = _held_rot.lerp(want_rot, k)
	# Reloading: the weapon tips down and to the side while the magazine is swapped.
	_reload_pose = move_toward(_reload_pose, 1.0 if reloading else 0.0, dt * 5.0)
	_held[0].position = _held_pos
	_held[0].rotation = _held_rot + Vector3(-0.8, 0.0, 0.5) * _reload_pose
	var parts := _held_parts()
	if parts.is_empty():
		return
	if not reloading and parts.has("mag") and not (parts["mag"] as Node3D).visible:
		(parts["mag"] as Node3D).visible = true
	if _flash3_t > 0.0:
		_flash3_t -= dt
		if _flash3_t <= 0.0:
			(parts["flash"] as Node3D).visible = false


## Someone else's shot (or a bot's), seen in third person: the muzzle flash and, from a magazine
## weapon, a casing out of the ejection port.
func remote_shot() -> void:
	var parts := _held_parts()
	if parts.is_empty() or not _held[0].visible:
		return
	var flash: Node3D = parts["flash"]
	flash.visible = true
	flash.rotation = Vector3(0, 0, randf() * TAU)
	_flash3_t = 0.05
	var kind := str(CrewWeapons.def(weapon)["casing"])
	var deb := Debris.of(ship)
	if kind == "" or not parts.has("port") or deb == null:
		return
	var model: Node3D = parts["root"]
	var b := model.global_basis.orthonormalized()
	var at := model.global_transform * (parts["port"] as Vector3)
	var inv := ship.global_basis.inverse()
	var out := b * Vector3(randf_range(1.5, 2.2), randf_range(0.9, 1.5), randf_range(0.1, 0.5))
	deb.eject(kind, ship.to_local(at), inv * out, inv * b * Basis(Vector3.FORWARD, PI / 2.0),
		Vector3(randf_range(-25, 25), randf_range(-8, 8), randf_range(-25, 25)))


## A reload seen in third person: the old magazine drops out of the gun onto the floor (the gun
## shows it again once the reload is done).
func _drop_held_mag() -> void:
	var parts := _held_parts()
	var mag: Node3D = parts.get("mag")
	var deb := Debris.of(ship)
	if mag == null or deb == null or not _held[0].visible or not mag.visible or weapon == "mgl":
		return
	var inv := ship.global_transform.affine_inverse()
	var vel := ship.global_basis.inverse() * Vector3(0, -1.0, 0)
	if weapon == "revolver":
		deb.drop_mag(mag, inv * mag.global_transform.orthonormalized(), vel, Basis(Vector3.RIGHT, PI / 2.0), 0.015, "moonclip")
	else:
		deb.drop_mag(mag, inv * mag.global_transform.orthonormalized(), vel)
	mag.visible = false


func _remote_update(delta: float) -> void:
	carrying = ship.crate_carried_by(peer_id) if ship else null
	var k := NetUtil.smooth(14.0, delta)
	if position.distance_to(net_pos) > 3.0:
		position = net_pos
		reset_physics_interpolation()
	else:
		position = position.lerp(net_pos, k)
	rotation.y = lerp_angle(rotation.y, look_yaw if station == "" else float(ship.console(station).get("seat_yaw", look_yaw)), k)
	if reloading != _was_reloading:
		_was_reloading = reloading
		# (A reload cut short by switching tools ends without the snap.)
		if reloading or (tool == 0 and alive):
			_reload_sound(reloading)
		if reloading:
			_drop_held_mag()
	_head.rotation.x = look_pitch * 0.6
	_show_body()
	_update_held()
