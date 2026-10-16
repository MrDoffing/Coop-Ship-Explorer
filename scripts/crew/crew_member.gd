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
## carry the crates aboard.
##
## Crew bots are CrewMembers with `bot = true`: the server owns them and a CrewBot brain drives
## them (repairs and side guns); everyone else sees them like any other crew member.

const WALK := 4.6
const SPRINT := 7.2
const ACCEL := 45.0
const JUMP := 4.8
const GRAVITY := 14.0
const EYE := 1.62
const REACH := 2.7
const RESPAWN_TIME := 8.0
const BLASTER_COOLDOWN := 0.24
const MUZZLE := Vector3(0.24, -0.17, -0.78)

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
var hp := 100.0
var max_hp := 100.0
var alive := true

var ship: Mothership
var camera: Camera3D
## Gun / mining aim relative to the mount, or the scout's (yaw, pitch) while flying it.
var station_aim := Vector2.ZERO
## Interaction hint shown by the HUD.
var prompt := ""
## The supply crate this crew member is carrying, if any (looked up every tick).
var carrying: SupplyCrate
var respawn_left := 0.0
var hurt_flash := 0.0

var _body: Node3D
var _head: Node3D
var _held: Array[Node3D] = []
var _view: Node3D
var _view_tools: Array[Node3D] = []
var _name_label: Label3D
var _cam_light: OmniLight3D
var _recall_hold := 0.0
var _fire_cd := 0.0
var _repair_acc := 0.0
var _repair_sys := ""
var _repair_send := 0.0
var _repair_fx := 0.0
var _last_hurt := -100.0
var _clock := 0.0
var _chase_yaw := 0.0
var _chase_pitch := -0.22
var _bob := 0.0
var _recoil := 0.0
var _was_on_floor := true


func _init() -> void:
	NetUtil.add_sync(self, ["net_pos", "look_yaw", "look_pitch"], ["station", "tool", "hp", "max_hp", "alive"], 1.0 / 30.0)


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
	collision_mask = Game.LAYER_INTERIOR | Game.LAYER_STATION
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
	_build_body()
	if bot and multiplayer.is_server():
		brain = CrewBot.new(self)
	if is_multiplayer_authority() and not bot:
		camera = Camera3D.new()
		camera.fov = 78.0
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
		camera.add_child(_cam_light)
		_build_viewmodel()
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
	# Held tools (third person).
	var blaster := Node3D.new()
	blaster.position = Vector3(0.3, 1.15, -0.5)
	_body.add_child(blaster)
	Models.box(blaster, Vector3.ZERO, Vector3(0.1, 0.14, 0.5), dark)
	Models.box(blaster, Vector3(0, 0.08, -0.05), Vector3(0.06, 0.04, 0.3), Models.emissive(Color(1.0, 0.5, 0.2), 2.0))
	var toolkit := Node3D.new()
	toolkit.position = Vector3(0.3, 1.1, -0.45)
	_body.add_child(toolkit)
	Models.box(toolkit, Vector3.ZERO, Vector3(0.08, 0.08, 0.45), Models.mat(Color(0.7, 0.7, 0.72), 0.7, 0.3))
	Models.box(toolkit, Vector3(0, 0, -0.25), Vector3(0.2, 0.08, 0.1), Models.mat(Color(0.95, 0.75, 0.15), 0.4, 0.5))
	_held = [blaster, toolkit]


func _build_viewmodel() -> void:
	_view = Node3D.new()
	camera.add_child(_view)
	var dark := Models.mat(Color(0.14, 0.15, 0.17), 0.5, 0.45)
	var blaster := Node3D.new()
	_view.add_child(blaster)
	Models.box(blaster, Vector3(0.24, -0.2, -0.45), Vector3(0.09, 0.12, 0.42), dark)
	Models.box(blaster, Vector3(0.24, -0.27, -0.33), Vector3(0.07, 0.16, 0.08), dark, Vector3(-15, 0, 0))
	Models.cylinder(blaster, Vector3(0.24, -0.17, -0.7), 0.025, 0.18, Models.mat(Color(0.3, 0.3, 0.32), 0.7, 0.3), Vector3(90, 0, 0))
	Models.box(blaster, Vector3(0.24, -0.137, -0.45), Vector3(0.025, 0.015, 0.26), Models.emissive(Color(1.0, 0.5, 0.2), 1.0))
	Models.box(blaster, Vector3(0.196, -0.17, -0.5), Vector3(0.006, 0.02, 0.12), Models.emissive(color, 0.8))
	var toolkit := Node3D.new()
	_view.add_child(toolkit)
	Models.box(toolkit, Vector3(0.26, -0.22, -0.42), Vector3(0.06, 0.06, 0.4), Models.mat(Color(0.7, 0.7, 0.72), 0.7, 0.3))
	Models.box(toolkit, Vector3(0.26, -0.22, -0.66), Vector3(0.18, 0.07, 0.09), Models.mat(Color(0.95, 0.75, 0.15), 0.4, 0.5))
	Models.box(toolkit, Vector3(0.26, -0.22, -0.72), Vector3(0.05, 0.04, 0.06), Models.emissive(Color(0.4, 0.9, 1.0), 3.0))
	_view_tools = [blaster, toolkit]
	for n in [blaster, toolkit]:
		for c in n.get_children():
			(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# --- Per-frame ---------------------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_clock += delta
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
	hurt_flash = maxf(0.0, hurt_flash - delta * 1.5)
	_recoil = maxf(0.0, _recoil - delta * 8.0)
	if not alive:
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
	else:
		_walk(delta, blocked)
		_interact(delta, blocked)
	_flush_repair(delta)
	# Safety net: never let the avatar fall out of the ship (or off the pier while docked).
	if not _in_bounds(position):
		position = ShipBuilder.SPAWN_POINTS[0]
		velocity = Vector3.ZERO
		reset_physics_interpolation()
	net_pos = position
	_update_held()


## Where a crew member may be (ship-local): inside the ship, plus the ramp, pier and station
## building while docked.
func _in_bounds(p: Vector3) -> bool:
	if ship.landing == Mothership.Dock.LANDED:
		return p.y > -2.6 and p.y < 8.0 and absf(p.x) < 12.0 and p.z > -11.0 and p.z < StationBuilder.ROOM_END + 1.0
	return p.y > -3.0 and p.y < 6.0 and absf(p.x) < 7.0 and p.z > -11.0 and p.z < 12.2


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
		brain.tick(delta)
	net_pos = position
	_head.rotation.x = look_pitch * 0.6
	_body.visible = alive
	_body.position.y = -0.3 if station != "" else 0.0
	_name_label.visible = alive
	_update_held()


func _unhandled_input(event: InputEvent) -> void:
	if bot or not is_multiplayer_authority() or Game.ui_blocking or not alive:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var d: Vector2 = (event as InputEventMouseMotion).relative * Game.mouse_sensitivity
		if Game.invert_y:
			d.y = -d.y
		match station:
			"":
				look_yaw = wrapf(look_yaw - d.x, -PI, PI)
				look_pitch = clampf(look_pitch - d.y, -1.45, 1.45)
			"pilot":
				_chase_yaw = wrapf(_chase_yaw - d.x, -PI, PI)
				_chase_pitch = clampf(_chase_pitch - d.y, -1.3, 0.6)
			_:
				if ship.is_turret_station(station):
					var t: Turret = ship.turrets[station]
					station_aim = t.clamp_aim(station_aim + Vector2(-d.x, -d.y) * 0.75)
				elif ship.is_scout_station(station):
					station_aim.x = wrapf(station_aim.x - d.x, -PI, PI)
					station_aim.y = clampf(station_aim.y - d.y, -1.45, 1.45)


func _walk(delta: float, blocked: bool) -> void:
	var input := Vector2.ZERO if blocked else Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var local_dir := Basis(Vector3.UP, look_yaw) * Vector3(input.x, 0, input.y)
	var dir := ship.global_basis * local_dir
	var speed := SPRINT if Input.is_action_pressed("sprint") else WALK
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


## Look at stations / repair panels, switch tools, shoot and repair.
func _interact(delta: float, blocked: bool) -> void:
	if not blocked:
		if Input.is_action_just_pressed("tool_blaster"):
			tool = 0
		elif Input.is_action_just_pressed("tool_toolkit"):
			tool = 1
		elif Input.is_action_just_pressed("tool_swap") or Input.is_action_just_pressed("tool_next") or Input.is_action_just_pressed("tool_prev"):
			tool = 1 - tool
	var eye := _eye_global()
	var dir := _look_dir_global()
	var q := PhysicsRayQueryParameters3D.create(eye, eye + dir * REACH, Game.LAYER_INTERACT | Game.LAYER_INTERIOR | Game.LAYER_STATION)
	q.collide_with_areas = true
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	prompt = ""
	var col: Object = hit.get("collider")
	if carrying:
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
		elif crate and crate.carrier == 0:
			prompt = "[E] Pick up %s - %s" % [RunItems.display_name(crate.item), RunItems.describe(crate.item)]
			if not blocked and Input.is_action_just_pressed("interact"):
				ship.request_crate_pickup.rpc_id(1, str(crate.name))
	elif col is Area3D and col.has_meta("install_hub"):
		prompt = "Install hub - carry supply crates here from a waystation"
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
				ship.request_blast.rpc_id(1)
	if tool == 0 and not blocked and Input.is_action_pressed("fire") and _fire_cd <= 0.0:
		_shoot()


## Interaction while carrying a crate: no tools; install it at the hub or a gun console, or drop it.
func _interact_carrying(col: Object, blocked: bool) -> void:
	var item := carrying.item
	var weapon := RunItems.is_weapon(item)
	var name_s := RunItems.display_name(item)
	var target := ""
	if col is Area3D and col.has_meta("install_hub"):
		if weapon:
			prompt = "Guns are mounted at a GUN console"
		elif item == "autocannon" and ship.autocannons >= ship.turret_slots():
			prompt = "Every turret slot is taken" if ship.turret_slots() > 0 else "This ship has no turret slots"
		else:
			prompt = "[E] Install %s" % name_s
			target = "hub"
	elif col is Area3D and col.has_meta("station"):
		var id := str(col.get_meta("station"))
		if ship.station_kind(id) == "gun" and weapon:
			var current := ship.gun_weapon(id)
			prompt = "[E] Mount %s on the %s (replaces the %s)" % [name_s, ship.station_name(id).to_lower(),
				Game.GUNS[current]["name"]]
			target = id
		elif weapon:
			prompt = "Mount guns at a GUN console"
		else:
			prompt = "Fit this at the INSTALL HUB in the engine room"
	elif col is Area3D and (col.has_meta("repair") or col.has_meta("crate")):
		prompt = "Your hands are full - [G] drop the crate"
	if blocked:
		return
	if target != "" and Input.is_action_just_pressed("interact"):
		ship.request_install.rpc_id(1, str(carrying.name), target)
	elif Input.is_action_just_pressed("drop"):
		_drop_carried()


## Put the carried crate down in front of us (or at our feet if a wall is in the way).
func _drop_carried() -> void:
	var space := get_world_3d().direct_space_state
	var mask := Game.LAYER_INTERIOR | Game.LAYER_STATION
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


func _shoot() -> void:
	_fire_cd = BLASTER_COOLDOWN
	_recoil = 1.0
	var eye := _eye_global()
	var dir := _look_dir_global()
	var q := PhysicsRayQueryParameters3D.create(eye, eye + dir * 60.0, Game.LAYER_INTERIOR | Game.LAYER_BOARDER | Game.LAYER_STATION)
	q.collide_with_areas = true
	q.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var end := eye + dir * 60.0
	var normal := -dir
	var flesh := false
	if not hit.is_empty():
		end = hit["position"]
		normal = hit["normal"]
		var col: Object = hit["collider"]
		if col.has_meta("boarder"):
			flesh = true
			ship.hit_boarder.rpc_id(1, str(col.get_meta("boarder")), float(ship.stats["blaster_damage"]))
			if Game.mission and Game.mission.hud:
				Game.mission.hud.hit_marker()
		Fx.impact(end, normal, Color(0.6, 1.0, 0.3) if flesh else Color(1.0, 0.6, 0.3), 1.2 if flesh else 1.0)
	var muzzle := camera.global_transform * MUZZLE
	Fx.tracer(muzzle, end, Color(1.0, 0.5, 0.2), 0.035, 0.07)
	Sfx.play("blaster", muzzle, -5.0)
	ship.fx_blaster.rpc(ship.to_local(muzzle), ship.to_local(end), ship.global_basis.inverse() * normal, flesh, not hit.is_empty())


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
				if Input.is_action_just_pressed("autopilot"):
					ship.toggle_autopilot.rpc_id(1)
				if Input.is_action_just_pressed("emergency"):
					ship.request_blast.rpc_id(1)
				if Input.is_action_just_pressed("land"):
					ship.request_land.rpc_id(1)
			ship.station_input.rpc_id(1, station, data)
		"gun", "laser":
			data["aim"] = station_aim
			data["fire"] = not blocked and Input.is_action_pressed("fire")
			ship.station_input.rpc_id(1, station, data)
		"scout":
			var mv := Vector3.ZERO
			if not blocked:
				mv = Vector3(Input.get_axis("move_left", "move_right"), Input.get_axis("descend", "jump"),
						Input.get_axis("move_back", "move_forward"))
			data = {"move": mv, "yaw": station_aim.x, "pitch": station_aim.y,
					"fire": not blocked and Input.is_action_pressed("fire"),
					"boost": not blocked and Input.is_action_pressed("sprint")}
			if scout:
				scout.pilot_input.rpc_id(1, data)


## Called when the server grants a station.
func enter_station(id: String) -> void:
	station = id
	var st := ship.console(id)
	position = st["seat"]
	rotation.y = st["seat_yaw"]
	velocity = Vector3.ZERO
	reset_physics_interpolation()
	match ship.station_kind(id):
		"gun", "laser":
			station_aim = ship.aim_of(id)
		"scout":
			station_aim = Vector2(ship.rotation.y, 0.15 if ship.dock_launch(id).y > 0.0 else -0.25)
		"pilot":
			_chase_yaw = 0.0
			_chase_pitch = -0.22
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
	position = ShipBuilder.SPAWN_POINTS.pick_random()
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
	if not alive or not ship.alive:
		_chase_camera(ship_x, delta)
		camera.global_position += shake
		return
	match station:
		"":
			var origin := get_global_transform_interpolated().origin + ship_x.basis.y * (EYE + sin(_bob * 2.0) * 0.03)
			var b := ship_x.basis * Basis(Vector3.UP, look_yaw) * Basis(Vector3.RIGHT, look_pitch)
			camera.global_transform = Transform3D(b, origin + shake * 0.5)
			camera.fov = 78.0
			_view.visible = true
			_view.position = Vector3(sin(_bob) * 0.008, -absf(cos(_bob)) * 0.01, _recoil * 0.06)
			_view.rotation = Vector3(_recoil * 0.12, 0, 0)
			for i in _view_tools.size():
				_view_tools[i].visible = i == tool and carrying == null
		"pilot":
			_chase_camera(ship_x, delta)
			camera.global_position += shake
		_:
			if ship.is_turret_station(station):
				var t: Turret = ship.turrets[station]
				camera.global_transform = ship_x * t.camera_local(station_aim)
				camera.global_position += shake * 0.4
				camera.fov = 70.0 if not Input.is_action_pressed("aim") else 35.0
			elif ship.is_scout_station(station):
				var scout: Scout = Game.mission.scout_at(station)
				var anchor := scout.get_global_transform_interpolated().origin if scout else ship_x.origin
				var b := Basis.from_euler(Vector3(station_aim.y, station_aim.x, 0.0))
				var pos := _clip_to_cave(anchor, anchor + b * Vector3(0, 1.7, 6.5))
				camera.global_transform = Transform3D(b, pos)
				camera.global_position += shake * 0.3
				camera.fov = 80.0
			_view.visible = false


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


func _update_held() -> void:
	for i in _held.size():
		_held[i].visible = i == tool and station == "" and carrying == null


func _remote_update(delta: float) -> void:
	carrying = ship.crate_carried_by(peer_id) if ship else null
	var k := NetUtil.smooth(14.0, delta)
	if position.distance_to(net_pos) > 3.0:
		position = net_pos
		reset_physics_interpolation()
	else:
		position = position.lerp(net_pos, k)
	rotation.y = lerp_angle(rotation.y, look_yaw if station == "" else float(ship.console(station).get("seat_yaw", look_yaw)), k)
	_head.rotation.x = look_pitch * 0.6
	_body.visible = alive
	_body.position.y = -0.3 if station != "" else 0.0
	_name_label.visible = alive
	_update_held()
