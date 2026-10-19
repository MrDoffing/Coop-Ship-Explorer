class_name Grenades
extends Node3D
## The Multiple Grenade Launcher's 40 mm grenades in flight. Each flies in an arc, bounces off the
## walls, the floors and the rock (losing speed at every bounce, then rolling to a stop) and goes off
## when its fuse runs out, or at once when it strikes an alien. A small red lamp on its tail blinks
## so it can be followed in the dark. They live in the mothership's space (like the casings,
## Debris), so they keep up with a moving ship.
##
## The shooter's own grenades are the real ones: they decide where and when each goes off and call
## back (the shooter asks the server for the blast's damage and tells everyone else where it went
## off). Everyone else flies a copy of each from the same start; the copy goes off where the
## shooter's did (burst()), or by itself a moment after its fuse if that word never comes.
##
## One per ship (Grenades.of()).

## Ship-local gravity (m/s^2), how much speed survives a bounce (along the surface's normal and
## across it), how hard a rolling grenade is braked (m/s^2) and the grenade's radius.
const GRAVITY := 9.8
const BOUNCE := 0.42
const FRICTION := 0.72
const ROLL_DRAG := 3.0
const RADIUS := 0.03
## What grenades bounce off: the ship (inside and its hull), the stations and the rock.
const MASK := Game.LAYER_INTERIOR | Game.LAYER_HULL | Game.LAYER_STATION | Game.LAYER_CAVE
## A copy goes off by itself this long after its fuse if the shooter's word never came.
const LATE := 0.6
## The blast: the fireball's radius (the damage reaches CrewWeapons "splash") and colour, and how
## far away (m) a crew member still feels it shake their view.
const BLAST_RADIUS := 2.6
const BLAST_COLOR := Color(1.0, 0.55, 0.2)
const SHAKE_REACH := 14.0

var ship: Mothership
## {"id", "pos", "vel", "age", "fuse", "owned", "on_burst", "node", "lamp", "rolling", "bounces",
## "spin"}.
var _live: Array[Dictionary] = []
## The copies that went off by themselves (their ids), so the shooter's word arriving late doesn't
## blow them up twice.
var _gone: Array[int] = []
static var _count := 0


static func of(s: Mothership) -> Grenades:
	if s == null or not is_instance_valid(s):
		return null
	var g := s.get_node_or_null("Grenades") as Grenades
	if g == null:
		g = Grenades.new()
		g.name = "Grenades"
		g.ship = s
		s.add_child(g)
	return g


## A new grenade id for a shot by peer `peer` (unique across the crew).
static func next_id(peer: int) -> int:
	_count += 1
	return peer * 100000 + _count % 100000


func _ready() -> void:
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


## Launch grenade `id` from ship-local `pos` with ship-local velocity `vel`; it goes off `fuse`
## seconds later (or on striking an alien, if `owned`). `owned`: the local crew member's own, which
## calls `on_burst` (with the ship-local point) when it goes off.
func launch(id: int, pos: Vector3, vel: Vector3, fuse: float, owned: bool, on_burst := Callable()) -> void:
	var node := _model()
	node.position = pos
	add_child(node)
	_live.append({"id": id, "pos": pos, "vel": vel, "age": 0.0, "fuse": fuse, "owned": owned, "on_burst": on_burst,
		"node": node, "lamp": node.get_meta("lamp"), "rolling": false, "bounces": 0,
		"spin": Vector3(randf_range(-30, 30), randf_range(-30, 30), randf_range(-8, 8))})


## The shooter's grenade `id` went off at ship-local `pos`: blow up the copy there (unless it went
## off by itself already, the word coming late).
func burst(id: int, pos: Vector3) -> void:
	if _gone.has(id):
		_gone.erase(id)
		return
	for i in _live.size():
		if int(_live[i]["id"]) == id:
			_remove(i)
			break
	_blast(pos)


## How many grenades are in flight (for the tests), and how many times they have bounced in all.
func count() -> int:
	return _live.size()


func bounces() -> int:
	var n := 0
	for g in _live:
		n += int(g["bounces"])
	return n


func _remove(i: int) -> void:
	var node: Node3D = _live[i]["node"]
	if node and is_instance_valid(node):
		node.queue_free()
	_live.remove_at(i)


func _physics_process(delta: float) -> void:
	if ship == null or not is_instance_valid(ship):
		return
	var space := get_world_3d().direct_space_state
	var i := 0
	while i < _live.size():
		var g: Dictionary = _live[i]
		g["age"] = float(g["age"]) + delta
		var owned := bool(g["owned"])
		var due := float(g["fuse"]) + (0.0 if owned else LATE)
		var struck := false
		if float(g["age"]) < due:
			struck = _step(g, delta, space)
		if struck or float(g["age"]) >= due:
			var at: Vector3 = g["pos"]
			_remove(i)
			_blast(at)
			var cb: Callable = g["on_burst"]
			if owned and cb.is_valid():
				cb.call(at)
			elif not owned:
				_gone.append(int(g["id"]))
				if _gone.size() > 32:
					_gone.remove_at(0)
			continue
		_show(g)
		i += 1


## One step of a grenade: gravity (or rolling along the floor), and bouncing off whatever it hits.
## True when the shooter's own grenade has struck an alien.
func _step(g: Dictionary, delta: float, space: PhysicsDirectSpaceState3D) -> bool:
	var vel: Vector3 = g["vel"]
	var pos: Vector3 = g["pos"]
	if bool(g["rolling"]):
		vel = vel.move_toward(Vector3.ZERO, ROLL_DRAG * delta)
		# Rolled off an edge: it falls again.
		var under := PhysicsRayQueryParameters3D.create(ship.to_global(pos), ship.to_global(pos + Vector3.DOWN * (RADIUS + 0.06)), MASK)
		if space.intersect_ray(under).is_empty():
			g["rolling"] = false
	else:
		vel.y -= GRAVITY * delta
		vel *= 1.0 - 0.04 * delta
	var to := pos + vel * delta
	var ahead := to + (vel.normalized() * RADIUS if vel.length_squared() > 1e-6 else Vector3.ZERO)
	var from_g := ship.to_global(pos)
	var to_g := ship.to_global(ahead)
	if bool(g["owned"]):
		# An alien in the way sets it off.
		var qa := PhysicsRayQueryParameters3D.create(from_g, to_g, Game.LAYER_BOARDER)
		qa.collide_with_areas = true
		qa.collide_with_bodies = false
		var ha := space.intersect_ray(qa)
		if not ha.is_empty():
			g["pos"] = ship.to_local(ha["position"])
			return true
	var q := PhysicsRayQueryParameters3D.create(from_g, to_g, MASK)
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		g["pos"] = to
	else:
		var n := (ship.global_basis.inverse() * (hit["normal"] as Vector3)).normalized()
		var vn := vel.dot(n)
		var impact := -vn
		vel = (vel - n * vn) * FRICTION - n * vn * BOUNCE
		g["pos"] = ship.to_local(hit["position"]) + n * RADIUS
		g["bounces"] = int(g["bounces"]) + 1
		g["spin"] = (g["spin"] as Vector3) * 0.6 + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * vel.length() * 12.0
		if impact > 1.0:
			Sfx.play("grenade_bounce", hit["position"], clampf(linear_to_db(impact / 6.0), -14.0, 0.0) - 4.0, randf_range(0.9, 1.15))
		if n.y > 0.7 and absf(vel.dot(n)) < 1.2:
			# Settled on a floor: from here it rolls.
			vel -= n * vel.dot(n)
			g["rolling"] = true
	g["vel"] = vel
	return false


## The grenade's model follows it, tumbling as it flies (slowing as it rolls); its lamp blinks.
func _show(g: Dictionary) -> void:
	var node: Node3D = g["node"]
	var spin: Vector3 = g["spin"]
	var dt := get_physics_process_delta_time()
	if bool(g["rolling"]):
		spin *= 0.92
		g["spin"] = spin
	node.position = g["pos"]
	if spin.length_squared() > 0.0001:
		node.basis = (node.basis * Basis(spin.normalized(), spin.length() * dt)).orthonormalized()
	var on := fmod(float(g["age"]), 0.25) < 0.08
	var lamp: OmniLight3D = g["lamp"]
	lamp.light_energy = 0.7 if on else 0.0
	(node.get_meta("led") as StandardMaterial3D).emission_energy_multiplier = 4.0 if on else 0.3


## A grenade: an olive body with a copper band and a rounded yellow-ringed nose, and the blinking lamp
## on its tail (and its light).
func _model() -> Node3D:
	var root := Node3D.new()
	root.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var olive := Models.mat(Color(0.3, 0.32, 0.22), 0.25, 0.6)
	Models.cylinder(root, Vector3(0, 0, 0.005), 0.019, 0.04, olive, Vector3(90, 0, 0), -1.0, 10)
	Models.sphere(root, Vector3(0, 0, -0.016), 0.019, olive, Vector3(1.0, 1.0, 1.3), 10)
	Models.cylinder(root, Vector3(0, 0, 0.018), 0.0198, 0.006, Models.mat(Color(0.72, 0.4, 0.2), 0.85, 0.35), Vector3(90, 0, 0), -1.0, 10)
	Models.cylinder(root, Vector3(0, 0, -0.022), 0.0175, 0.004, Models.mat(Color(0.85, 0.7, 0.15), 0.3, 0.5), Vector3(90, 0, 0), -1.0, 10)
	var led := StandardMaterial3D.new()
	led.albedo_color = Color(0.1, 0.02, 0.02)
	led.emission_enabled = true
	led.emission = Color(1.0, 0.12, 0.06)
	led.emission_energy_multiplier = 0.3
	Models.sphere(root, Vector3(0, 0, 0.027), 0.004, led, Vector3.ONE, 8)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color(1.0, 0.15, 0.08)
	lamp.omni_range = 1.4
	lamp.light_energy = 0.0
	lamp.position = Vector3(0, 0, 0.05)
	root.add_child(lamp)
	for c in root.get_children():
		if c is GeometryInstance3D:
			(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.set_meta("lamp", lamp)
	root.set_meta("led", led)
	return root


## A grenade going off at ship-local `at`: a fireball, sparks, a flash and the bang; the local crew
## member's view shakes the more the closer it was.
func _blast(at: Vector3) -> void:
	var pos := ship.to_global(at)
	Fx.explosion(pos, BLAST_RADIUS, BLAST_COLOR)
	Fx.sparks(pos, Color(1.0, 0.72, 0.35), 30, 10.0, 0.05, 0.6)
	Fx.flash(pos, BLAST_COLOR, 7.0, 12.0, 0.35)
	Sfx.play("grenade_blast", pos, 1.0, randf_range(0.95, 1.05))
	var lp: CrewMember = Game.mission.local_player if Game.mission else null
	if lp and lp.camera and lp.alive:
		var d := lp.camera.global_position.distance_to(pos)
		Game.mission.shake(clampf(1.0 - d / SHAKE_REACH, 0.0, 1.0) * 0.6)
