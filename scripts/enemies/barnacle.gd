class_name Barnacle
extends Boarder
## A barnacle: a flat crust grown onto a ceiling, crusted over with the ceiling's own grime and
## paint so it is hard to tell from it, round a dark slit of a maw. It never moves, and its tongue
## stays inside until someone walks within GRAB_RANGE of the spot under it: then it lashes out and
## wraps round them (`grab`), reels them in under it, lifts them a little off their feet and holds
## them there (they can't walk away, but they can look up and shoot) while it chews on them, until
## it is shot dead or they are knocked out. Crew bots shoot it too (CrewMember holds the one caught
## in place on its own client, see reel()). Now and then a drop falls from its maw: its only tell.
##
## Its node hangs upside down from the ceiling point (`position`), so its hit area hangs below it.

## Whoever's feet come within GRAB_RANGE (horizontally) of the spot under it, in its sight, is
## caught; after letting go it waits REARM seconds before it catches again. The tongue takes
## LASH_TIME to reach them and RETRACT_TIME to go back in; the one caught is reeled in at
## REEL_SPEED and held HOLD_LIFT above the floor.
const GRAB_RANGE := 1.9
const REARM := 3.0
const LASH_TIME := 0.2
const RETRACT_TIME := 0.35
const REEL_SPEED := 2.6
const HOLD_LIFT := 0.3
## A drop gathers at its maw for DRIP_TIME seconds, then falls.
const DRIP_TIME := Vector2(6.0, 14.0)

var _rearm := 0.0
var _floor := INF
var _tongue: MeshInstance3D
var _tip: MeshInstance3D
var _drop: MeshInstance3D
# Every peer: how far the tongue is out (0..1), where it last held someone (node-local), and the
# drop gathering or falling.
var _lash := 0.0
var _held_at := Vector3.ZERO
var _drip_t := 0.0
var _drop_v := -1.0


func _setup(_data: Dictionary) -> void:
	basis = Basis(Vector3.RIGHT, PI)


## The stations' floor (ship-local height, the ship landed).
static func deck_floor() -> float:
	return StationBuilder.DECK_Y - StationBuilder.LAND_HEIGHT


## The floor under it (ship-local height), found once.
func floor_y() -> float:
	if _floor == INF:
		_floor = deck_floor()
		var ship := _ship()
		if ship and is_inside_tree():
			var from := ship.to_global(position + Vector3(0, -0.6, 0))
			var q := PhysicsRayQueryParameters3D.create(from, from - ship.global_basis.y * 9.0, Game.LAYER_STATION | Game.LAYER_CAVE)
			var hit := get_world_3d().direct_space_state.intersect_ray(q)
			if not hit.is_empty():
				_floor = ship.to_local(hit["position"]).y
	return _floor


## Where the one caught is held (ship-local).
func hold_point() -> Vector3:
	return Vector3(position.x, floor_y() + HOLD_LIFT, position.z)


## Where the one caught is drawn to from `p` (ship-local) this frame: nowhere until the tongue has
## them, then in under it at REEL_SPEED, and held there.
func reel(p: Vector3, delta: float) -> Vector3:
	if _lash < 1.0:
		return p
	return p.move_toward(hold_point(), REEL_SPEED * delta)


func _think_outside(delta: float, ship: Mothership) -> void:
	_attack_cd = maxf(0.0, _attack_cd - delta)
	_rearm -= delta
	if grab != 0:
		var victim := ship.crew_root.get_node_or_null(str(grab)) as CrewMember
		if victim == null or not victim.alive or ship.is_aboard(victim.position):
			grab = 0
			attacking = false
			_rearm = REARM
			return
		attacking = true
		if _attack_cd <= 0.0:
			_attack_cd = stat("cooldown")
			victim.hurt(stat("damage") * dmg_mult)
			Game.mission.fx_event.rpc("barnacle_chew", ship.to_global(victim.position + Vector3(0, 1.4, 0)), 0)
		return
	attacking = false
	if _rearm > 0.0:
		return
	var maw := ship.to_global(position - Vector3(0, 0.2, 0))
	for c in ship.crew_root.get_children():
		var p := c as CrewMember
		if p == null or not p.alive or ship.is_aboard(p.position) or _held_elsewhere(p):
			continue
		var flat := Vector2(p.position.x - position.x, p.position.z - position.z)
		if flat.length() >= GRAB_RANGE or p.position.y > position.y - 1.0:
			continue
		# It must see them, and have a clear floor to reel them in over.
		if not _clear_from(ship, maw, ship.to_global(p.position + Vector3(0, 1.2, 0))) \
				or not _clear_from(ship, ship.to_global(p.position + Vector3(0, 0.5, 0)), ship.to_global(hold_point() + Vector3(0, 0.2, 0))):
			continue
		grab = p.peer_id
		_attack_cd = 0.6
		Game.mission.fx_event.rpc("barnacle_grab", ship.to_global(p.position + Vector3(0, 1.2, 0)), 0)
		return


func _held_elsewhere(p: CrewMember) -> bool:
	for c in get_parent().get_children():
		var b := c as Boarder
		if b and b != self and b.grab == p.peer_id:
			return true
	return false


func center_global() -> Vector3:
	return global_transform * Vector3(0, 0.1, 0)


## A flat disc under the ceiling, a little wider than the crust.
func _hit_shape(cs: CollisionShape3D) -> void:
	var disc := CylinderShape3D.new()
	disc.radius = 0.55
	disc.height = 0.5
	cs.shape = disc
	cs.position = Vector3(0, 0.2, 0)


# --- Looks -------------------------------------------------------------------------------------

func _build(model: Node3D) -> Dictionary:
	# The crust wears the ceiling's own surface, lined up with it (the node is upside down: its z
	# runs the other way, hence the flipped scale).
	var crust := (DerelictBuilder.surface_mat("outpost_wall", Color(0.4, 0.4, 0.38), 0.5, false)).duplicate() as ORMMaterial3D
	crust.uv1_scale = Vector3(0.5, 0.5, -0.5)
	crust.uv1_offset = Vector3(position.x * 0.5, 0.0, position.z * 0.5)
	var flesh := Alien.organic(Color(0.07, 0.05, 0.045), Color(0.1, 0.03, 0.02), 0.6, 9.0)
	var maw := Models.mat(Color(0.015, 0.01, 0.01), 0.0, 0.25)
	var teeth := Models.mat(Color(0.32, 0.29, 0.24), 0.1, 0.4)
	var gum := Alien.organic(Color(0.3, 0.07, 0.08), Color(0.35, 0.08, 0.06), 2.5, 9.0)
	# A low, lumpy crust (+y points down), a ring of dark flesh in it and the slit of the maw.
	var shell := MeshInstance3D.new()
	shell.mesh = Models.blob_mesh(53 + int(absf(position.x * 7.0 + position.z * 3.0)) % 40, 0.55, 0.3, 14)
	shell.material_override = crust
	shell.scale = Vector3(1.0, 0.17, 1.0)
	model.add_child(shell)
	var ring := MeshInstance3D.new()
	ring.mesh = Models.blob_mesh(71, 0.27, 0.35, 12)
	ring.material_override = flesh
	ring.scale = Vector3(1.0, 0.3, 0.8)
	ring.position = Vector3(0, 0.03, 0)
	model.add_child(ring)
	Models.sphere(model, Vector3(0, 0.1, 0), 0.13, maw, Vector3(1.5, 0.22, 0.4))
	for i in 8:
		var x := -0.13 + i * 0.037
		for side: float in [-1.0, 1.0]:
			Models.cylinder(model, Vector3(x, 0.11, side * 0.045), 0.008, 0.035, teeth, Vector3(side * 25.0, 0, 0), 0.0, 5)
	# The tongue (hidden until it lashes out) and the drop that gathers at the maw.
	_tongue = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.045
	cm.bottom_radius = 0.03
	cm.height = 1.0
	cm.radial_segments = 8
	cm.rings = 4
	_tongue.mesh = cm
	_tongue.material_override = gum
	_tongue.visible = false
	model.add_child(_tongue)
	_tip = Models.sphere(model, Vector3(0, 0.1, 0), 0.06, gum)
	_tip.visible = false
	_drop = Models.sphere(model, Vector3(0, 0.12, 0), 0.022, Models.mat(Color(0.18, 0.05, 0.04), 0.0, 0.05))
	_drop.scale = Vector3.ZERO
	_drip_t = randf_range(0.0, DRIP_TIME.y)
	return {}


func _animate(delta: float) -> void:
	if _tongue == null:
		return
	var ship := _ship()
	if ship == null:
		return
	_lash = move_toward(_lash, 1.0 if grab != 0 else 0.0, delta / (LASH_TIME if grab != 0 else RETRACT_TIME))
	if grab != 0:
		var victim := ship.crew_root.get_node_or_null(str(grab)) as CrewMember
		if victim:
			# Round their chest, off to one side (not across the face of the one held).
			var side := Basis(Vector3.UP, victim.look_yaw) * Vector3(0.22, 0, 0.12)
			_held_at = to_local(ship.to_global(victim.position + Vector3(0, 1.15, 0) + side))
	var out := _lash > 0.001
	_tongue.visible = out
	_tip.visible = out
	if out:
		var top := Vector3(0, 0.1, 0)
		var k := ease(_lash, 0.6)
		var tip := top.lerp(_held_at, k)
		# A lash curls a little on its way out.
		tip += Vector3(sin(_anim_t * 9.0), 0, cos(_anim_t * 7.0)) * 0.06 * sin(k * PI)
		Models.place_strut(_tongue, top, tip)
		_tip.position = tip
	_drip(delta, ship)


## A drop gathering at the maw, then falling to the floor with a small plop.
func _drip(delta: float, ship: Mothership) -> void:
	if _drop_v >= 0.0:
		_drop_v += 9.8 * delta
		_drop.position.y += _drop_v * delta
		if _drop.position.y >= position.y - floor_y():
			Sfx.play("barnacle_drip", ship.to_global(Vector3(position.x, floor_y(), position.z)), -16.0, randf_range(0.85, 1.2))
			_drop_v = -1.0
			_drop.position = Vector3(0, 0.12, 0)
			_drop.scale = Vector3.ZERO
			_drip_t = randf_range(DRIP_TIME.x, DRIP_TIME.y)
		return
	_drip_t -= delta
	var grow := clampf(1.0 - _drip_t / 3.0, 0.0, 1.0)
	_drop.scale = Vector3(1.0, 1.0 + grow * 0.5, 1.0) * grow
	if _drip_t <= 0.0:
		_drop_v = 0.0
