class_name WeaponRig
extends Node3D
## The hand weapon (and the toolkit) in a walking crew member's own first-person view, in the
## camera's frame. There are no hands: the weapon itself does all the moving.
## - Poses: held relaxed across the body (walking, or a moment after the last shot), raised to fire
##   from the hip, up to the eye to aim down its own sight (RMB; the sight lines up with the middle
##   of the view), swung low while sprinting and down out of view for the scanner, a crate or the
##   toolkit. A weapon just taken comes up from below.
## - Every shot kicks it back and up and lights its muzzle flash (a shot that kicks harder, see
##   CrewWeapons "kick_grow", kicks it harder too). The pistol's slide and the rifles' and the
##   submachine gun's bolts run back and forward (the pistol's slide locks back on an empty
##   magazine); the shotgun's pump racks after every shot; the Revolver's hammer flicks back and
##   falls and its cylinder turns a chamber, as does the grenade launcher's. The magazine weapons
##   throw their casings out of the ejection port (Debris), the shotgun as the pump comes back.
## - Reloading a magazine weapon: it tips over, the old magazine drops out (onto the floor, as
##   debris), the new one slides up into the well and clicks home, and the slide or bolt is racked.
##   The Revolver and the grenade launcher instead tip up and swing their cylinder out on its crane:
##   the Revolver's spent moon clip drops out of the back (the launcher's six cases tumble out), a
##   full one slides in, and the cylinder swings shut.
##   Venting a heat weapon: its hatch or flaps open and steam pours out.
## - Its display shows the rounds left (or the heat), its coils and fins glow with heat or charge
##   (the Photon Rifle's flash with every shot), and the Lightning Thrower's prongs crackle with arcs
##   as it charges.

const READY_POS := Vector3(0.19, -0.155, -0.45)
const READY_ROT := Vector3(0.0, 0.035, 0.0)
const RELAX_POS := Vector3(0.16, -0.21, -0.42)
# (Canted towards the eye, so its display stays in view.)
const RELAX_ROT := Vector3(-0.42, 0.48, 0.12)
const SPRINT_POS := Vector3(0.13, -0.26, -0.36)
const SPRINT_ROT := Vector3(-0.7, 0.8, -0.45)
const HOLSTER_POS := Vector3(0.2, -0.62, -0.26)
const HOLSTER_ROT := Vector3(-1.1, 0.3, -0.2)
## Seconds the weapon takes to go down out of view (or come up again).
const HOLSTER_TIME := 0.22
const SWAP_TIME := 0.35
## A reload's steps (share of the way through it): the old magazine drops, the new one starts up
## the well, clicks home, and the slide is racked (or the cylinder swings shut).
const MAG_OUT := 0.16
const MAG_UP := 0.42
const MAG_IN := 0.66
const RACK := 0.8
## The weapons with a cylinder on a crane, how far the crane swings it out to reload (radians), and
## how long a turn of a chamber takes (s).
const CYLINDER := ["revolver", "mgl"]
const CRANE_OPEN := 1.66
const TURN_TIME := {"revolver": 0.06, "mgl": 0.14}
## Seconds a slide or bolt takes to run back and forward, and the shotgun's pump to rack.
const SLIDE_TIME := {"pistol": 0.08, "smg": 0.035, "marksman": 0.07}
const PUMP_TIME := 0.45

## The crew member holding it.
var crew: CrewMember
## The weapon shown (CrewWeapons id), its model and the model's parts (CrewWeapons.build_model).
var weapon := ""
var model: Node3D
var parts: Dictionary = {}
var _toolkit: Node3D
var _holster := 1.0
var _swap := 0.0
var _tool_up := 0.0
var _kick := 0.0
var _kick_yaw := 0.0
var _slide_t := 1.0
var _pump_t := 1.0
var _pump_out := true
var _pumped := true
var _flash_t := 0.0
var _pulse := 0.0
var _sway := Vector2.ZERO
var _reload_step := 0
var _mag_home := Transform3D.IDENTITY
var _vent := 0.0
## The Revolver's and the grenade launcher's cylinder: chambers turned so far, its angle, how far
## its crane is swung out (0..1) and the hammer's flick (0 as it fires .. 1 at rest).
var _cyl_index := 0
var _cyl_angle := 0.0
var _crane := 0.0
var _hammer_t := 1.0
var _steam: CPUParticles3D
var _arcs: MeshInstance3D
var _arc_mesh: ImmediateMesh
var _clock := 0.0


## Build the rig for crew member `c` (under their first-person view).
func build(c: CrewMember) -> void:
	crew = c
	_toolkit = Node3D.new()
	_toolkit.name = "Toolkit"
	add_child(_toolkit)
	Models.box(_toolkit, Vector3(0.26, -0.22, -0.42), Vector3(0.06, 0.06, 0.4), Models.mat(Color(0.7, 0.7, 0.72), 0.7, 0.3))
	Models.box(_toolkit, Vector3(0.26, -0.22, -0.66), Vector3(0.18, 0.07, 0.09), Models.mat(Color(0.95, 0.75, 0.15), 0.4, 0.5))
	Models.box(_toolkit, Vector3(0.26, -0.22, -0.72), Vector3(0.05, 0.04, 0.06), Models.emissive(Color(0.4, 0.9, 1.0), 3.0))
	for n in _toolkit.get_children():
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_arc_mesh = ImmediateMesh.new()
	_arcs = MeshInstance3D.new()
	_arcs.mesh = _arc_mesh
	_arcs.material_override = Models.glow(Color(1.6, 2.2, 3.0, 1.0))
	_arcs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_steam = CPUParticles3D.new()
	_steam.amount = 24
	_steam.lifetime = 0.7
	_steam.emitting = false
	_steam.local_coords = true
	var puff := SphereMesh.new()
	puff.radius = 0.012
	puff.height = 0.024
	puff.radial_segments = 6
	puff.rings = 3
	var pm := StandardMaterial3D.new()
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pm.vertex_color_use_as_albedo = true
	pm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	puff.material = pm
	_steam.mesh = puff
	_steam.direction = Vector3(0, 1, 0)
	_steam.spread = 35.0
	_steam.initial_velocity_min = 0.15
	_steam.initial_velocity_max = 0.35
	_steam.gravity = Vector3(0, 0.25, 0)
	_steam.scale_amount_min = 0.6
	_steam.scale_amount_max = 1.6
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.85, 0.88, 0.9, 0.5))
	ramp.set_color(1, Color(0.8, 0.82, 0.85, 0.0))
	_steam.color_ramp = ramp
	_steam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _notification(what: int) -> void:
	# The arcs and the steam are only parented to models that have prongs or a vent.
	if what == NOTIFICATION_PREDELETE:
		for n: Node in [_arcs, _steam]:
			if n and is_instance_valid(n) and n.get_parent() == null:
				n.free()


## Show weapon `id` (it comes up from below).
func set_weapon(id: String) -> void:
	if id == weapon and model != null:
		return
	weapon = id
	if model:
		if _arcs.get_parent() == model:
			model.remove_child(_arcs)
		if _steam.get_parent() == model:
			model.remove_child(_steam)
		model.queue_free()
	model = CrewWeapons.build_model(self, id, crew.color, true)
	parts = CrewWeapons.parts_of(model)
	var mag: Node3D = parts.get("mag")
	_mag_home = mag.transform if mag else Transform3D.IDENTITY
	if parts.has("vent"):
		_steam.position = (parts["vent"] as Node3D).position
		model.add_child(_steam)
	if parts.has("prongs"):
		model.add_child(_arcs)
	_swap = 1.0
	_reload_step = 0
	_slide_t = 1.0
	_pump_t = 1.0
	_pumped = true
	_pump_out = true
	_flash_t = 0.0
	_pulse = 0.0
	_vent = 0.0
	_cyl_index = 0
	_cyl_angle = 0.0
	_crane = 0.0
	_hammer_t = 1.0
	(parts["flash"] as Node3D).visible = false


## A shot: the kick (`grow` times as hard as usual: the shots that kick harder as they come
## quicker), the muzzle flash, the slide or bolt and the casing (the shotgun's comes out as the
## pump racks), or the hammer and the cylinder's turn.
func shot(grow := 1.0) -> void:
	if model == null:
		return
	var d := CrewWeapons.def(weapon)
	_kick = minf(grow, 1.8)
	_kick_yaw = randf_range(-1.0, 1.0)
	_flash_t = 0.045
	_pulse = 1.0
	var flash: Node3D = parts["flash"]
	flash.visible = true
	flash.rotation = Vector3(0, 0, randf() * TAU)
	flash.scale = Vector3.ONE * randf_range(0.8, 1.25)
	match weapon:
		"shotgun":
			_pump_t = 0.0
			_pump_out = false
			_pumped = false
		"revolver", "mgl":
			_hammer_t = 0.0
			# (The launcher's round leaves its chamber: its nose no longer shows in the mouth.)
			var noses: Array = parts.get("noses", [])
			if not noses.is_empty():
				(noses[_cyl_index % noses.size()] as Node3D).visible = false
			_cyl_index += 1
		_:
			_slide_t = 0.0
			if str(d["casing"]) != "":
				_eject()


## Throw a casing out of the ejection port, to the right and up, carried along with the crew
## member's own movement.
func _eject() -> void:
	var kind := str(CrewWeapons.def(weapon)["casing"])
	if kind == "" or not parts.has("port") or crew.ship == null:
		return
	var deb := Debris.of(crew.ship)
	if deb == null:
		return
	var ship := crew.ship
	var mx := model.global_transform
	var mb := mx.basis.orthonormalized()
	var at := mx * (parts["port"] as Vector3)
	var cam := crew.camera.global_transform.basis
	var out := cam * Vector3(randf_range(1.6, 2.4), randf_range(1.0, 1.7), randf_range(0.1, 0.5))
	if kind == "shell":
		out = cam * Vector3(randf_range(1.2, 1.8), randf_range(0.8, 1.3), randf_range(0.2, 0.6))
	var inv := ship.global_basis.inverse()
	var vel := inv * out + inv * crew.velocity
	var rot := inv * mb * Basis(Vector3.FORWARD, PI / 2.0 + randf_range(-0.3, 0.3))
	deb.eject(kind, ship.to_local(at), vel, rot, Vector3(randf_range(-25, 25), randf_range(-8, 8), randf_range(-25, 25)))


## The state to show: "tool" (0 the weapon, 1 the toolkit), "ready" (0 relaxed .. 1 raised), "aim"
## (0..1 down the sight), "sprint", "holster" (0..1: down for the scanner or a crate), "reloading",
## "progress" (of the reload or vent), "ammo", "heat", "overheat", "charge" (Lightning Thrower),
## "bob" (the walk's phase), "move" (speed, share of walking), "look_vel" (how fast the view turns,
## rad/s) and "vel" (ship-local).
func update(delta: float, st: Dictionary) -> void:
	if model == null:
		return
	_clock += delta
	_pulse = maxf(0.0, _pulse - delta * 9.0)
	var tool := int(st.get("tool", 0))
	var down := maxf(float(st.get("holster", 0.0)), 1.0 if tool != 0 else 0.0)
	_holster = move_toward(_holster, down, delta / HOLSTER_TIME)
	_swap = move_toward(_swap, 0.0, delta / SWAP_TIME)
	var reloading := bool(st.get("reloading", false))
	var p := float(st.get("progress", 0.0))
	var e_ready := smoothstep(0.0, 1.0, float(st.get("ready", 0.0)))
	var e_aim := smoothstep(0.0, 1.0, float(st.get("aim", 0.0)))
	var e_sprint := smoothstep(0.0, 1.0, float(st.get("sprint", 0.0)))
	var e_down := smoothstep(0.0, 1.0, maxf(_holster, _swap))
	var eye: Vector3 = parts.get("eye", Vector3(0, 0.07, 0.3))
	var pos := RELAX_POS.lerp(READY_POS, e_ready)
	var rot := RELAX_ROT.lerp(READY_ROT, e_ready)
	pos = pos.lerp(SPRINT_POS, e_sprint)
	rot = rot.lerp(SPRINT_ROT, e_sprint)
	pos = pos.lerp(-eye, e_aim)
	rot = rot.lerp(Vector3.ZERO, e_aim)
	pos = pos.lerp(HOLSTER_POS, e_down)
	rot = rot.lerp(HOLSTER_ROT, e_down)
	# Walking sways it, turning drags it behind the view, and breathing moves it a little.
	var move := clampf(float(st.get("move", 0.0)), 0.0, 1.7)
	var bob := float(st.get("bob", 0.0))
	var calm := 1.0 - 0.85 * e_aim
	pos += Vector3(sin(bob) * 0.006, -absf(cos(bob)) * 0.008, 0.0) * move * calm * (1.0 + 0.6 * e_sprint)
	rot.z += sin(bob) * 0.015 * move * calm
	pos.y += sin(_clock * 1.6) * 0.0015 * calm
	var lv: Vector2 = st.get("look_vel", Vector2.ZERO)
	var want := Vector2(clampf(-lv.x * 0.012, -0.07, 0.07), clampf(-lv.y * 0.012, -0.05, 0.05)) * (1.0 - 0.7 * e_aim)
	_sway = _sway.lerp(want, NetUtil.smooth(9.0, delta))
	rot += Vector3(_sway.y, _sway.x, _sway.x * 0.6)
	# The kick: straight back, and tipping up (less while aiming down the sight).
	var d := CrewWeapons.def(weapon)
	var punch := float(d["punch"])
	_kick *= exp(-delta * 13.0)
	pos.z += punch * _kick
	rot.x += punch * 3.2 * _kick * (1.0 - 0.6 * e_aim)
	rot.y += punch * 0.8 * _kick * _kick_yaw
	var kind := "heat" if CrewWeapons.uses_heat(weapon) else ("cylinder" if weapon in CYLINDER else "mag")
	match kind:
		"heat":
			_update_vent(delta, reloading)
		"cylinder":
			_update_cylinder(delta, reloading, p, int(st.get("ammo", 0)))
		_:
			_update_reload(reloading, p)
	var r := _reload_pose(reloading, p, kind)
	pos += r[0]
	rot += r[1]
	if weapon == "lightning":
		var ch := float(st.get("charge", 0.0))
		pos += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0.0) * 0.0012 * ch * ch
	model.position = pos
	model.rotation = rot
	_update_slide(delta, st)
	_update_flash(delta)
	_update_glow(st)
	_update_arcs(st)
	_update_display(st)
	model.visible = e_down < 0.98
	# The toolkit comes up from below when it is taken.
	_tool_up = move_toward(_tool_up, 1.0 if tool == 1 and float(st.get("holster", 0.0)) < 0.5 else 0.0, delta / HOLSTER_TIME)
	_toolkit.visible = _tool_up > 0.0
	var tu := smoothstep(0.0, 1.0, _tool_up)
	_toolkit.position = Vector3(0, -0.3 * (1.0 - tu), 0.05 * (1.0 - tu)) + Vector3(sin(bob) * 0.006, -absf(cos(bob)) * 0.01, 0.0) * move
	_toolkit.rotation = Vector3(-0.6 * (1.0 - tu), 0, 0)


## How far a reload tips the weapon over, a vent turns it to the side, or a cylinder reload tips it
## up and turns its open side to the eye ([position, rotation]).
func _reload_pose(reloading: bool, p: float, kind: String) -> Array:
	if not reloading:
		return [Vector3.ZERO, Vector3.ZERO]
	var t := smoothstep(0.0, 0.14, p) * (1.0 - smoothstep(0.84, 1.0, p))
	match kind:
		"heat":
			return [Vector3(-0.02, 0.025, 0.02) * t, Vector3(0.12, -0.2, 0.35) * t]
		"cylinder":
			return [Vector3(-0.06, 0.07, 0.03) * t, Vector3(0.75, -0.25, 0.35) * t]
	return [Vector3(-0.035, 0.05, 0.03) * t, Vector3(0.3, -0.35, 0.7) * t]


## A magazine weapon's reload, step by step (each sound and the dropped magazine come once).
func _update_reload(reloading: bool, p: float) -> void:
	var mag: Node3D = parts.get("mag")
	if mag == null:
		return
	if not reloading:
		if _reload_step != 0:
			_reload_step = 0
			mag.visible = true
			mag.transform = _mag_home
		return
	if _reload_step == 0 and p >= MAG_OUT:
		_reload_step = 1
		_drop_mag(mag)
		mag.visible = false
		Sfx.play("mag_out", null, -8.0)
	if _reload_step >= 1 and p >= MAG_UP and p < MAG_IN:
		var u := clampf((p - MAG_UP) / (MAG_IN - MAG_UP), 0.0, 1.0)
		mag.visible = true
		mag.transform = _mag_home * Transform3D(Basis.IDENTITY, Vector3(0, -0.24 * pow(1.0 - u, 2.0), 0))
	if _reload_step == 1 and p >= MAG_IN:
		_reload_step = 2
		mag.visible = true
		mag.transform = _mag_home
		_kick = maxf(_kick, 0.3)
		Sfx.play("mag_in", null, -6.0)
	if _reload_step == 2 and p >= RACK:
		_reload_step = 3
		Sfx.play("pump" if weapon == "shotgun" else "rack", null, -7.0)


## The Revolver's (or the grenade launcher's) cylinder: it turns a chamber after every shot (the
## hammer flicks back and falls as it fires). A reload swings it out on its crane, drops the spent
## moon clip out of the back (the launcher throws out its six cases), slides a full one in and swings
## it shut, step by step. `ammo`: the rounds left, which the launcher's chambers show.
func _update_cylinder(delta: float, reloading: bool, p: float, ammo: int) -> void:
	var cyl: Node3D = parts.get("cylinder")
	var crane: Node3D = parts.get("crane")
	var mag: Node3D = parts.get("mag")
	if cyl == null or crane == null or mag == null:
		return
	var step := TAU / 6.0
	_cyl_angle = move_toward(_cyl_angle, -float(_cyl_index) * step, delta * step / float(TURN_TIME.get(weapon, 0.1)))
	cyl.rotation.z = _cyl_angle
	_hammer_t = minf(1.0, _hammer_t + delta / 0.05)
	var hammer: Node3D = parts.get("hammer")
	if hammer:
		hammer.rotation.x = 0.6 * (1.0 - _hammer_t)
	if not reloading:
		_crane = move_toward(_crane, 0.0, delta / 0.12)
		if _reload_step != 0:
			_reload_step = 0
			mag.visible = true
			mag.transform = _mag_home
			_show_rounds(ammo)
	else:
		_crane = smoothstep(0.04, 0.14, p) * (1.0 - smoothstep(RACK, RACK + 0.06, p))
		if _reload_step == 0 and p >= 0.05:
			_reload_step = 1
			Sfx.play("cyl_open", null, -9.0)
		if _reload_step == 1 and p >= MAG_OUT:
			_reload_step = 2
			if weapon == "mgl":
				_dump_cases(cyl)
			else:
				_drop_mag(mag, true)
				Sfx.play("mag_out", null, -12.0, 1.4)
			mag.visible = false
		if _reload_step >= 2 and p >= MAG_UP and p < MAG_IN:
			var u := clampf((p - MAG_UP) / (MAG_IN - MAG_UP), 0.0, 1.0)
			mag.visible = true
			_show_rounds(6)
			mag.transform = _mag_home * Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.16 * pow(1.0 - u, 2.0)))
		if _reload_step == 2 and p >= MAG_IN:
			_reload_step = 3
			mag.visible = true
			mag.transform = _mag_home
			_kick = maxf(_kick, 0.3)
			Sfx.play("mag_in", null, -6.0, 0.75 if weapon == "mgl" else 1.15)
		if _reload_step == 3 and p >= RACK:
			_reload_step = 4
			Sfx.play("cyl_close", null, -7.0, 0.85 if weapon == "mgl" else 1.0)
	crane.rotation.z = CRANE_OPEN * smoothstep(0.0, 1.0, _crane)


## The grenade launcher's chambers: the rounds still in it show in their mouths (the next to fire
## first, in the order the cylinder brings them up).
func _show_rounds(ammo: int) -> void:
	var noses: Array = parts.get("noses", [])
	for k in noses.size():
		var left := posmod(k - _cyl_index, noses.size()) < ammo
		(noses[k] as Node3D).visible = left


## The old magazine (or the Revolver's moon clip, `clip`) falls out of the gun onto the floor.
func _drop_mag(mag: Node3D, clip := false) -> void:
	var deb := Debris.of(crew.ship)
	if deb == null:
		return
	var ship := crew.ship
	var g := mag.global_transform.orthonormalized()
	var inv := ship.global_transform.affine_inverse()
	var cam := crew.camera.global_transform.basis
	if clip:
		# Out of the back of the cylinder, and down: it lands flat, its cases jangling.
		var out := g.basis * Vector3(0, 0, 0.9) + cam * Vector3(randf_range(-0.1, 0.1), -0.6, 0.0)
		deb.drop_mag(mag, inv * g, ship.global_basis.inverse() * (out + crew.velocity), Basis(Vector3.RIGHT, PI / 2.0), 0.015, "moonclip")
		return
	var down := cam * Vector3(randf_range(-0.1, 0.2), -1.2, randf_range(0.0, 0.3))
	deb.drop_mag(mag, inv * g, ship.global_basis.inverse() * (down + crew.velocity))


## The grenade launcher's six spent cases tumble out of the back of its open cylinder.
func _dump_cases(cyl: Node3D) -> void:
	var deb := Debris.of(crew.ship)
	if deb == null:
		return
	var ship := crew.ship
	var inv := ship.global_basis.inverse()
	var cb := cyl.global_basis.orthonormalized()
	var cam := crew.camera.global_transform.basis
	for at: Vector2 in parts.get("chambers", []):
		var pos := cyl.global_transform * Vector3(at.x, at.y, 0.05)
		var vel := cb * Vector3(randf_range(-0.2, 0.2), randf_range(-0.2, 0.2), randf_range(0.5, 1.0)) + cam * Vector3(0, -0.4, 0)
		var rot := inv * cb * Basis(Vector3.RIGHT, PI / 2.0)
		deb.eject("40mm", ship.to_local(pos), inv * (vel + crew.velocity), rot,
			Vector3(randf_range(-9, 9), randf_range(-4, 4), randf_range(-9, 9)))
	Sfx.play("mag_out", null, -10.0, 0.7)


## A heat weapon venting: its hatch (or flaps) opens and steam pours out while it vents.
func _update_vent(delta: float, reloading: bool) -> void:
	_vent = move_toward(_vent, 1.0 if reloading else 0.0, delta / 0.15)
	var vent: Node3D = parts.get("vent")
	if vent:
		var e := smoothstep(0.0, 1.0, _vent)
		if weapon == "photon":
			vent.rotation.z = 1.1 * e
		else:
			vent.rotation.x = -1.0 * e
	_steam.emitting = reloading


## The slide or bolt runs back with a shot and returns (the pistol's locks back once the magazine is
## empty); the shotgun's pump racks after every shot, throwing the shell out as it comes back; a
## reload racks them too.
func _update_slide(delta: float, st: Dictionary) -> void:
	var slide: Node3D = parts.get("slide")
	if slide == null:
		return
	var travel: Vector3 = parts.get("travel", Vector3.ZERO)
	var off := 0.0
	if weapon == "shotgun":
		_pump_t = minf(1.0, _pump_t + delta / PUMP_TIME)
		if not _pumped and _pump_t >= 0.2:
			_pumped = true
			Sfx.play("pump", null, -9.0, 0.95)
		if not _pump_out and _pump_t >= 0.45:
			_pump_out = true
			_eject()
		off = smoothstep(0.2, 0.5, _pump_t) - smoothstep(0.6, 0.92, _pump_t)
	else:
		_slide_t = minf(1.0, _slide_t + delta / float(SLIDE_TIME.get(weapon, 0.06)))
		off = 1.0 - _slide_t
		if weapon == "pistol" and int(st.get("ammo", 1)) <= 0 and not bool(st.get("reloading", false)) and _slide_t >= 1.0:
			off = 1.0
	if bool(st.get("reloading", false)):
		var p := float(st.get("progress", 0.0))
		var rack := smoothstep(RACK, RACK + 0.05, p) - smoothstep(RACK + 0.06, RACK + 0.14, p)
		# The pistol's slide stays back until the reload racks it home.
		var locked := 1.0 if weapon == "pistol" and int(st.get("ammo", 1)) <= 0 and p < RACK + 0.06 else 0.0
		off = maxf(off, maxf(rack, locked))
	slide.position = travel * off


func _update_flash(delta: float) -> void:
	var flash: Node3D = parts["flash"]
	if _flash_t > 0.0:
		_flash_t -= delta
		if _flash_t <= 0.0:
			flash.visible = false


## Coils, fins and chambers glow brighter the hotter the weapon is (or the more it is charged); the
## Photon Rifle's also flash with every shot.
func _update_glow(st: Dictionary) -> void:
	var heat := float(st.get("heat", 0.0))
	var ch := float(st.get("charge", 0.0))
	for g: StandardMaterial3D in parts.get("glow", []):
		var base := float(g.get_meta("base", 0.6))
		if weapon == "lightning":
			g.emission_energy_multiplier = base + ch * 5.0 * (0.8 + 0.2 * sin(_clock * 60.0)) + heat * 0.8
		else:
			g.emission_energy_multiplier = base * (1.0 + heat * 3.0) + _pulse * 1.6


## The Lightning Thrower's prongs crackle as it charges: arcs leap between them, more and wilder the
## fuller the charge.
func _update_arcs(st: Dictionary) -> void:
	if not parts.has("prongs"):
		return
	var ch := float(st.get("charge", 0.0))
	_arc_mesh.clear_surfaces()
	if ch <= 0.02 or not model.visible:
		return
	var pr: Array = parts["prongs"]
	var a: Vector3 = pr[0]
	var b: Vector3 = pr[1]
	_arc_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := 1 + int(ch * 3.0)
	for k in count:
		var prev := a
		for i in range(1, 7):
			var t := float(i) / 6.0
			var p := a.lerp(b, t)
			if i < 6:
				p += Vector3(0, randf_range(-1, 1), randf_range(-1, 1)) * 0.012 * (0.3 + ch) * sin(t * PI)
			_ribbon(prev, p, 0.0008 + 0.0018 * ch)
			prev = p
	if ch > 0.6:
		for tip: Vector3 in [a, b]:
			var reach := tip + Vector3(randf_range(-0.02, 0.02), randf_range(-0.02, 0.02), -randf_range(0.01, 0.05))
			_ribbon(tip, reach, 0.0008)
	_arc_mesh.surface_end()


func _ribbon(p: Vector3, q: Vector3, w: float) -> void:
	var side := (q - p).cross(Vector3.BACK)
	if side.length_squared() < 1e-10:
		return
	side = side.normalized() * w
	for v: Vector3 in [p - side, p + side, q + side, p - side, q + side, q - side]:
		_arc_mesh.surface_add_vertex(v)


## The display: rounds left (amber when low, red and flashing when empty, dashes while reloading),
## or the heat on a bar with the weapon's state (READY, HOT, VENT, OVERHEAT, the charge).
func _update_display(st: Dictionary) -> void:
	var disp: Dictionary = parts.get("display", {})
	if disp.is_empty():
		return
	var blink := fmod(_clock, 0.5) < 0.25
	var value: Label3D = disp["value"]
	var state: Label3D = disp["state"]
	var reloading := bool(st.get("reloading", false))
	if CrewWeapons.uses_heat(weapon):
		var heat := float(st.get("heat", 0.0))
		var ch := float(st.get("charge", 0.0))
		CrewWeapons.set_text(value, "%d%%" % int(round(heat * 100.0)))
		var bar: MeshInstance3D = disp["bar"]
		bar.set_instance_shader_parameter("value", heat)
		var col := GunPod.GREEN
		var text := "READY"
		if bool(st.get("overheat", false)):
			text = "OVHT" if blink else ""
			col = GunPod.RED
			bar.set_instance_shader_parameter("blink", 0.4 if not blink else 1.0)
		elif reloading:
			text = "VENT"
			col = GunPod.AMBER
			bar.set_instance_shader_parameter("blink", 1.0)
		elif ch > 0.0:
			text = "CHG %d" % int(ch * 100.0) if ch < 1.0 else "FULL"
			col = GunPod.AMBER if ch < 1.0 else GunPod.GREEN
		elif heat >= 0.75:
			text = "HOT"
			col = GunPod.AMBER
		else:
			bar.set_instance_shader_parameter("blink", 1.0)
		CrewWeapons.set_text(state, text)
		state.modulate = col
		value.modulate = GunPod.RED if heat >= 0.9 else (GunPod.AMBER if heat >= 0.6 else GunPod.GREEN)
	else:
		var ammo := int(st.get("ammo", 0))
		var full := CrewWeapons.mag(weapon)
		if reloading:
			CrewWeapons.set_text(value, "--")
			value.modulate = GunPod.AMBER * (1.0 if blink else 0.5)
			CrewWeapons.set_text(state, "RELOAD")
			state.modulate = GunPod.AMBER
		elif ammo <= 0:
			CrewWeapons.set_text(value, "00")
			value.modulate = GunPod.RED * (1.0 if blink else 0.35)
			CrewWeapons.set_text(state, "EMPTY" if blink else "")
			state.modulate = GunPod.RED
		else:
			CrewWeapons.set_text(value, "%02d" % ammo)
			value.modulate = GunPod.AMBER if ammo <= maxi(1, int(full * 0.25)) else GunPod.GREEN
			CrewWeapons.set_text(state, "")
