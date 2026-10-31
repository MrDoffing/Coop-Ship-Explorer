class_name Projectiles
extends Node3D
## All bolts, orbs, alien spit and needles in a mission.
##
## The server simulates authoritative projectiles and applies damage. Every shot is announced to
## clients, which fly cosmetic copies that stop on the same geometry but never deal damage.
##
## Kinds with "trail" (the gun pods' tracer rounds) draw as a streak behind the round that grows
## to "len" as it leaves the muzzle: fast rounds that hit a tunnel wall a few metres off are still
## seen in flight.
##
## The scouts' heat-seeking missiles (fire_missile) home on their target, an alien, turning at most
## MISSILE_TURN rad/s and speeding up to MISSILE_SPEED (m/s) after the launch. One whose target is
## gone seeks the nearest alien within MISSILE_SEEK (radians) of its heading and MISSILE_SEEK_RANGE
## metres. It bursts on rock (once it has flown MISSILE_ARM seconds, clear of its pylon, which may
## hang over rock while the scout hugs a wall), on any alien in its way or within MISSILE_FUSE
## metres of its target (or once it runs out after MISSILE_LIFE seconds): full damage to what it
## hits, splash damage up to MISSILE_SPLASH metres round. The clients' copies fly the same way and
## burst where the server's did.
##
## The gun pods' rockets (fire_rocket, the Multiple Rocket Launcher System) are smaller and aren't
## locked on anything: each leaves its tube at the speed it is given and speeds up to ROCKET_SPEED,
## flying a little crooked at first (a curve of its own, at most ROCKET_CURVE rad/s, dying away over
## ROCKET_CURVE_TIME seconds), and homes in on the first alien that comes within ROCKET_SEEK_RANGE
## metres and ROCKET_SEEK radians of its heading (turning at most ROCKET_TURN rad/s). It bursts on
## rock (once it has flown ROCKET_ARM seconds), on any alien in its way or within ROCKET_FUSE metres
## of the one it homes in on, or when it runs out after ROCKET_LIFE seconds: full damage to what it
## hits and ROCKET_SPLASH_SHARE of it round it, out to ROCKET_SPLASH metres.

## The scouts' missiles: see above.
const MISSILE_SPEED := 62.0
const MISSILE_ACCEL := 45.0
const MISSILE_TURN := 3.2
const MISSILE_LIFE := 6.0
const MISSILE_ARM := 0.2
const MISSILE_SEEK := 0.6
const MISSILE_SEEK_RANGE := 70.0
const MISSILE_FUSE := 1.2
const MISSILE_SPLASH := 9.0
## The gun pods' rockets: see above.
const ROCKET_SPEED := 72.0
const ROCKET_ACCEL := 110.0
const ROCKET_CURVE := 0.9
const ROCKET_CURVE_TIME := 0.7
const ROCKET_SEEK := 0.9
const ROCKET_SEEK_RANGE := 18.0
const ROCKET_TURN := 3.0
const ROCKET_ARM := 0.12
const ROCKET_FUSE := 1.1
const ROCKET_LIFE := 4.0
const ROCKET_SPLASH := 4.5
const ROCKET_SPLASH_SHARE := 0.55

const KINDS := {
	"pulse": {"color": Color(0.35, 0.85, 1.0), "len": 2.4, "width": 0.13, "life": 1.6},
	"hmg": {"color": Color(0.75, 0.48, 0.2), "len": 5.0, "width": 0.04, "life": 1.4, "trail": true},
	"flak": {"color": Color(1.0, 0.75, 0.3), "len": 1.0, "width": 0.1, "life": 0.5},
	"plasma": {"color": Color(0.75, 0.4, 1.0), "orb": 0.75, "life": 3.0, "splash": 16.0},
	"scout": {"color": Color(0.45, 1.0, 0.45), "len": 1.6, "width": 0.09, "life": 1.3},
	"spit": {"color": Color(0.55, 1.0, 0.15), "orb": 0.42, "life": 5.0},
	"needle": {"color": Color(1.0, 0.35, 0.85), "len": 0.8, "width": 0.05, "life": 2.0},
	"acid": {"color": Color(0.6, 1.0, 0.18), "orb": 0.11, "life": 3.0},
}
## The acid spiders' globs arc down at this rate (m/s²); the spiders aim high to allow for it.
const ACID_GRAVITY := 6.0

## Ship weapons hit enemies, minerals and rock (Game.LAYER_CAVE | LAYER_ENEMY | LAYER_MINERAL).
## Scout bolts also hit aliens latched onto the hull, which move to LAYER_ATTACHED.
const MASK_SHIP := 1 | 16 | 128
const LAYER_ATTACHED := 512
const MASK_SCOUT := MASK_SHIP | LAYER_ATTACHED
## Needlers' needles hit crew members (their bodies) and stop on walls, rock and the ship.
const MASK_NEEDLE := 1 | 2 | 4 | 8 | 1024

var _shots: Array[Dictionary] = []
var _mats: Dictionary = {}
var _meshes: Dictionary = {}
## The server numbers its missiles, so the clients' copies can be put out where it burst.
var _missile_seq := 0
static var _trail_pm: ParticleProcessMaterial


## Server: fire a projectile. `dmg` is applied on impact (plasma: splash damage).
func fire(kind: String, pos: Vector3, vel: Vector3, dmg: float) -> void:
	if not multiplayer.is_server():
		return
	_spawn(kind, pos, vel, dmg, true)
	_net_fire.rpc(kind, pos, vel)


## Server: instant piercing rail shot.
func fire_rail(from: Vector3, dir: Vector3, dmg: float) -> void:
	if not multiplayer.is_server():
		return
	var space := get_world_3d().direct_space_state
	var to := from + dir * 260.0
	var exclude: Array[RID] = []
	var end := to
	for i in 6:
		var q := PhysicsRayQueryParameters3D.create(from, to, MASK_SHIP)
		q.collide_with_areas = true
		q.exclude = exclude
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			break
		var col: Object = hit["collider"]
		if col is Area3D and col.has_meta("target"):
			_damage(col, dmg, hit["position"], "turret")
			exclude.append(hit["rid"])
			if col.collision_layer & Game.LAYER_MINERAL:
				end = hit["position"]
				break
			continue
		end = hit["position"]
		break
	_net_rail.rpc(from, end)


@rpc("authority", "call_local", "unreliable")
func _net_rail(from: Vector3, to: Vector3) -> void:
	Fx.tracer(from, to, Color(0.7, 0.9, 1.0), 0.18, 0.35)
	Fx.tracer(from, to, Color(1.0, 1.0, 1.0), 0.05, 0.2)
	Fx.sparks(to, Color(0.6, 0.85, 1.0), 14, 10.0)


@rpc("authority", "call_remote", "unreliable")
func _net_fire(kind: String, pos: Vector3, vel: Vector3) -> void:
	_spawn(kind, pos, vel, 0.0, false)


func _spawn(kind: String, pos: Vector3, vel: Vector3, dmg: float, auth: bool) -> void:
	var def: Dictionary = KINDS[kind]
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh(kind)
	mi.material_override = _material(kind)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var s := {"kind": kind, "pos": pos, "vel": vel, "life": def["life"], "dmg": dmg, "auth": auth, "node": mi, "from": pos}
	mi.global_transform = _shot_xform(s, pos, vel)
	mi.reset_physics_interpolation()
	_shots.append(s)


func _physics_process(delta: float) -> void:
	if _shots.is_empty():
		return
	var space := get_world_3d().direct_space_state
	var ship: Mothership = Game.mission.ship if Game.mission else null
	var scouts: Array[Scout] = []
	if Game.mission:
		scouts = (Game.mission as MissionLevel).flying_scouts()
	for i in range(_shots.size() - 1, -1, -1):
		var s := _shots[i]
		s["life"] = float(s["life"]) - delta
		if s["kind"] == "missile":
			if _missile_step(s, delta, space):
				_drop(i)
			continue
		if s["kind"] == "rocket":
			if _rocket_step(s, delta, space):
				_drop(i)
			continue
		var from: Vector3 = s["pos"]
		var vel: Vector3 = s["vel"]
		var kind: String = s["kind"]
		if kind == "spit":
			vel += Vector3.DOWN * 2.0 * delta
			s["vel"] = vel
		elif kind == "acid" and ship:
			# Down is the ship's down: the station the spiders live in is level with the parked ship.
			vel -= ship.global_basis.y * ACID_GRAVITY * delta
			s["vel"] = vel
		var to := from + vel * delta
		var done := false
		if kind == "spit":
			done = _spit_step(s, from, to, ship, scouts, space)
		elif kind == "needle" or kind == "acid":
			var nq := PhysicsRayQueryParameters3D.create(from, to, MASK_NEEDLE)
			var nhit := space.intersect_ray(nq)
			if not nhit.is_empty():
				done = true
				var crew := nhit["collider"] as CrewMember
				if crew and s["auth"]:
					crew.hurt(float(s["dmg"]))
				elif s["auth"] and (nhit["collider"] as Object).has_meta("sentry"):
					# (A sentry turret standing open: its body, a child of the turret.)
					var sentry := (nhit["collider"] as Node).get_parent() as Sentry
					if sentry:
						sentry.hurt(float(s["dmg"]))
				Fx.sparks(nhit["position"], KINDS[kind]["color"], 6 if crew == null else 12, 4.0 if kind == "needle" else 2.5, 0.03, 0.3 if kind == "needle" else 0.6)
				if kind == "acid":
					Sfx.play("acid_hit", nhit["position"], -6.0)
		else:
			var q := PhysicsRayQueryParameters3D.create(from, to, MASK_SCOUT if kind == "scout" else MASK_SHIP)
			q.collide_with_areas = true
			var hit := space.intersect_ray(q)
			if not hit.is_empty():
				done = true
				_impact(s, hit["position"], hit["collider"])
		if not done and float(s["life"]) <= 0.0:
			done = true
			if kind == "plasma":
				_impact(s, to, null)
		if done:
			(s["node"] as Node).queue_free()
			_shots.remove_at(i)
		else:
			s["pos"] = to
			(s["node"] as Node3D).global_transform = _shot_xform(s, to, vel)


func _spit_step(s: Dictionary, from: Vector3, to: Vector3, ship: Mothership, scouts: Array[Scout], space: PhysicsDirectSpaceState3D) -> bool:
	if ship and ship.alive:
		var hit_pos: Variant = ship.shield_hit(from, to)
		if hit_pos != null:
			if s["auth"]:
				ship.apply_damage(float(s["dmg"]), hit_pos, "spit")
			Fx.sparks(hit_pos, KINDS["spit"]["color"], 10, 6.0)
			return true
	for scout in scouts:
		var d := _seg_point_dist(from, to, scout.global_position)
		if d < 1.8:
			if s["auth"]:
				scout.take_damage(float(s["dmg"]), {"source": "spit"})
			Fx.sparks(scout.global_position, KINDS["spit"]["color"], 10, 6.0)
			return true
	var q := PhysicsRayQueryParameters3D.create(from, to, Game.LAYER_CAVE)
	var hit := space.intersect_ray(q)
	if not hit.is_empty():
		Fx.sparks(hit["position"], KINDS["spit"]["color"], 8, 5.0)
		return true
	return false


func _impact(s: Dictionary, pos: Vector3, collider: Object) -> void:
	var kind: String = s["kind"]
	var color: Color = KINDS[kind]["color"]
	if kind == "plasma":
		var splash := float(KINDS["plasma"]["splash"])
		Fx.explosion(pos, splash * 0.55, color)
		Fx.shockwave(pos, splash, color)
		Sfx.play("explosion", pos, -4.0, 1.4)
		if s["auth"]:
			_splash(pos, splash, float(s["dmg"]))
		return
	Fx.sparks(pos, color, 8, 7.0)
	if s["auth"] and collider is Area3D and collider.has_meta("target"):
		_damage(collider, float(s["dmg"]), pos, "scout" if kind == "scout" else "turret")


func _damage(area: Object, dmg: float, pos: Vector3, source: String) -> void:
	var target: Variant = area.get_meta("target")
	if target is Node and is_instance_valid(target) and target.has_method("take_damage"):
		target.take_damage(dmg, {"source": source, "pos": pos, "sac": area.get_meta("sac", -1)})


## Splash damage round `pos` to every target on `mask` (falling off with distance), but not to
## `spare` (one already hit in full: its hit area, or the alien itself).
func _splash(pos: Vector3, radius: float, dmg: float, mask := Game.LAYER_ENEMY, spare: Object = null) -> void:
	var shape := SphereShape3D.new()
	shape.radius = radius
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = Transform3D(Basis.IDENTITY, pos)
	q.collision_mask = mask
	q.collide_with_areas = true
	q.collide_with_bodies = false
	for r in get_world_3d().direct_space_state.intersect_shape(q, 64):
		var col: Object = r["collider"]
		if col is Area3D and col.has_meta("target") and (spare == null or (col != spare and col.get_meta("target") != spare)):
			var tpos: Vector3 = (col as Node3D).global_position
			var falloff := clampf(1.0 - pos.distance_to(tpos) / (radius * 1.4), 0.3, 1.0)
			_damage(col, dmg * falloff, tpos, "splash")


# --- Missiles ----------------------------------------------------------------------------------

## Server: launch a scout's heat-seeking missile at `target` (see MISSILE_SPEED and the rest).
func fire_missile(pos: Vector3, vel: Vector3, target: Node3D, dmg: float) -> void:
	if not multiplayer.is_server():
		return
	_missile_seq += 1
	var tname := str(target.name) if target else ""
	_spawn_missile(_missile_seq, pos, vel, tname, dmg, true)
	_net_missile.rpc(_missile_seq, pos, vel, tname)


@rpc("authority", "call_remote", "reliable")
func _net_missile(id: int, pos: Vector3, vel: Vector3, tname: String) -> void:
	_spawn_missile(id, pos, vel, tname, 0.0, false)


## Server -> clients: missile `id` burst at `pos`.
@rpc("authority", "call_remote", "reliable")
func _net_missile_end(id: int, pos: Vector3) -> void:
	_missile_fx(pos)
	for i in range(_shots.size() - 1, -1, -1):
		if _shots[i]["kind"] == "missile" and int(_shots[i]["id"]) == id:
			_drop(i)
			return


func _spawn_missile(id: int, pos: Vector3, vel: Vector3, tname: String, dmg: float, auth: bool) -> void:
	var target: Node3D = null
	if tname != "" and Game.mission:
		target = (Game.mission as MissionLevel).enemy_root.get_node_or_null(tname) as Node3D
	var node := _missile_node()
	node.transform = _xform(pos, vel)
	add_child(node)
	node.reset_physics_interpolation()
	_shots.append({"kind": "missile", "id": id, "pos": pos, "vel": vel, "life": MISSILE_LIFE, "dmg": dmg, "auth": auth,
		"node": node, "from": pos, "target": target})


## One step of a missile's flight: it turns towards its target (or seeks a new one) and speeds up.
## The server's bursts on what it meets (true: it is done); a client's copy only flies, until the
## server says where it burst.
func _missile_step(s: Dictionary, delta: float, space: PhysicsDirectSpaceState3D) -> bool:
	var pos: Vector3 = s["pos"]
	var vel: Vector3 = s["vel"]
	var t: Variant = s["target"]
	var target: Node3D = t if is_instance_valid(t) and (t as Node3D).is_inside_tree() else null
	if target == null:
		target = _seek(pos, vel)
		s["target"] = target
	var dir := vel.normalized() if vel.length_squared() > 0.01 else Vector3.FORWARD
	if target:
		var want := (target.global_position - pos).normalized()
		var axis := dir.cross(want)
		if axis.length_squared() > 1e-8:
			dir = dir.rotated(axis.normalized(), minf(dir.angle_to(want), MISSILE_TURN * delta))
	vel = dir * minf(vel.length() + MISSILE_ACCEL * delta, MISSILE_SPEED)
	s["vel"] = vel
	var to := pos + vel * delta
	var node := s["node"] as Node3D
	if not s["auth"]:
		s["pos"] = to
		node.global_transform = _xform(to, vel)
		return float(s["life"]) < -1.0
	var armed := MISSILE_LIFE - float(s["life"]) >= MISSILE_ARM
	var q := PhysicsRayQueryParameters3D.create(pos, to, MASK_SCOUT if armed else MASK_SCOUT & ~Game.LAYER_CAVE)
	q.collide_with_areas = true
	var hit := space.intersect_ray(q)
	var at := to
	var dmg := float(s["dmg"])
	# What takes the full blow: the area it flew into, or its target when it bursts beside it.
	var spare: Object = null
	if not hit.is_empty():
		at = hit["position"]
		var col: Object = hit["collider"]
		if col is Area3D and col.has_meta("target"):
			_damage(col, dmg, at, "missile")
			spare = col
	elif target and _seg_point_dist(pos, to, target.global_position) < MISSILE_FUSE:
		at = target.global_position
		if target.has_method("take_damage"):
			target.take_damage(dmg, {"source": "missile", "pos": at})
		spare = target
	elif float(s["life"]) > 0.0:
		s["pos"] = to
		node.global_transform = _xform(to, vel)
		return false
	_splash(at, MISSILE_SPLASH, dmg, Game.LAYER_ENEMY | LAYER_ATTACHED, spare)
	_missile_fx(at)
	_net_missile_end.rpc(int(s["id"]), at)
	return true


## The alien nearest to a missile's heading, within `cone` radians of it and `reach` metres.
func _seek(pos: Vector3, vel: Vector3, cone := MISSILE_SEEK, reach := MISSILE_SEEK_RANGE) -> Node3D:
	var dir := vel.normalized() if vel.length_squared() > 0.01 else Vector3.FORWARD
	var best: Node3D = null
	var best_a := cone
	for a in get_tree().get_nodes_in_group("aliens"):
		var n := a as Node3D
		var to := n.global_position - pos
		if to.length() > reach:
			continue
		var ang := dir.angle_to(to)
		if ang < best_a:
			best_a = ang
			best = n
	return best


# --- Rockets -----------------------------------------------------------------------------------

## Server: launch a gun pod's rocket (see ROCKET_*); `curve` is its crooked turn at first (an angular
## velocity, rad/s).
func fire_rocket(pos: Vector3, vel: Vector3, dmg: float, curve: Vector3) -> void:
	if not multiplayer.is_server():
		return
	_missile_seq += 1
	_spawn_rocket(_missile_seq, pos, vel, curve, dmg, true)
	_net_rocket.rpc(_missile_seq, pos, vel, curve)


@rpc("authority", "call_remote", "reliable")
func _net_rocket(id: int, pos: Vector3, vel: Vector3, curve: Vector3) -> void:
	_spawn_rocket(id, pos, vel, curve, 0.0, false)


## Server -> clients: rocket `id` burst at `pos`.
@rpc("authority", "call_remote", "reliable")
func _net_rocket_end(id: int, pos: Vector3) -> void:
	_rocket_fx(pos)
	for i in range(_shots.size() - 1, -1, -1):
		if _shots[i]["kind"] == "rocket" and int(_shots[i]["id"]) == id:
			_drop(i)
			return


func _spawn_rocket(id: int, pos: Vector3, vel: Vector3, curve: Vector3, dmg: float, auth: bool) -> void:
	var node := _rocket_node()
	node.transform = _xform(pos, vel)
	add_child(node)
	node.reset_physics_interpolation()
	_shots.append({"kind": "rocket", "id": id, "pos": pos, "vel": vel, "life": ROCKET_LIFE, "dmg": dmg, "auth": auth,
		"node": node, "from": pos, "target": null, "curve": curve, "age": 0.0, "seek_t": 0.0})


## One step of a rocket's flight: its own curve (dying away), homing in on an alien once one is close
## ahead of it, speeding up. The server's bursts on what it meets (true: it is done); a client's copy
## only flies, until the server says where it burst.
func _rocket_step(s: Dictionary, delta: float, space: PhysicsDirectSpaceState3D) -> bool:
	var pos: Vector3 = s["pos"]
	var vel: Vector3 = s["vel"]
	var age := float(s["age"]) + delta
	s["age"] = age
	var t: Variant = s["target"]
	var target: Node3D = t if t != null and is_instance_valid(t) and (t as Node3D).is_inside_tree() else null
	if target == null:
		s["seek_t"] = float(s["seek_t"]) - delta
		if float(s["seek_t"]) <= 0.0:
			s["seek_t"] = 0.08
			target = _seek(pos, vel, ROCKET_SEEK, ROCKET_SEEK_RANGE)
		s["target"] = target
	var dir := vel.normalized() if vel.length_squared() > 0.01 else Vector3.FORWARD
	var curve: Vector3 = s["curve"]
	if curve.length_squared() > 1e-8:
		dir = dir.rotated(curve.normalized(), curve.length() * exp(-age / ROCKET_CURVE_TIME) * delta).normalized()
	if target:
		var want := (target.global_position - pos).normalized()
		var axis := dir.cross(want)
		if axis.length_squared() > 1e-8:
			dir = dir.rotated(axis.normalized(), minf(dir.angle_to(want), ROCKET_TURN * delta))
	vel = dir * minf(vel.length() + ROCKET_ACCEL * delta, ROCKET_SPEED)
	s["vel"] = vel
	var to := pos + vel * delta
	var node := s["node"] as Node3D
	if not s["auth"]:
		s["pos"] = to
		node.global_transform = _xform(to, vel)
		return float(s["life"]) < -1.0
	var armed := age >= ROCKET_ARM
	var q := PhysicsRayQueryParameters3D.create(pos, to, MASK_SHIP if armed else MASK_SHIP & ~Game.LAYER_CAVE)
	q.collide_with_areas = true
	var hit := space.intersect_ray(q)
	var at := to
	var dmg := float(s["dmg"])
	var spare: Object = null
	if not hit.is_empty():
		at = hit["position"]
		var col: Object = hit["collider"]
		if col is Area3D and col.has_meta("target"):
			_damage(col, dmg, at, "rocket")
			spare = col
	elif target and _seg_point_dist(pos, to, target.global_position) < ROCKET_FUSE:
		at = target.global_position
		if target.has_method("take_damage"):
			target.take_damage(dmg, {"source": "rocket", "pos": at})
		spare = target
	elif float(s["life"]) > 0.0:
		s["pos"] = to
		node.global_transform = _xform(to, vel)
		return false
	_splash(at, ROCKET_SPLASH, dmg * ROCKET_SPLASH_SHARE, Game.LAYER_ENEMY, spare)
	_rocket_fx(at)
	_net_rocket_end.rpc(int(s["id"]), at)
	return true


## A rocket bursting: a smaller fireball and a shock wave out to the edge of its blast.
func _rocket_fx(pos: Vector3) -> void:
	Fx.explosion(pos, 2.0, Color(1.0, 0.6, 0.25))
	Fx.shockwave(pos, ROCKET_SPLASH, Color(1.0, 0.55, 0.25), 0.25)
	Sfx.play("explosion", pos, -5.0, 1.6)


## A gun pod's rocket under `parent`, pointing down -Z from its middle: olive with a dull red nose and
## four small fins.
static func rocket_body(parent: Node3D) -> void:
	var b := Models.Batch.new()
	var dark := Models.mat(Color(0.12, 0.12, 0.13), 0.5, 0.5)
	b.cyl(Vector3.ZERO, 0.05, 0.5, Models.mat(Color(0.3, 0.33, 0.22), 0.3, 0.6), Vector3(90, 0, 0), -1.0, 10)
	b.cyl(Vector3(0, 0, -0.31), 0.001, 0.12, Models.mat(Color(0.55, 0.13, 0.08), 0.35, 0.5), Vector3(90, 0, 0), 0.05, 10)
	for k in 4:
		var a := TAU * k / 4.0 + PI / 4.0
		b.box(Vector3(cos(a) * 0.07, sin(a) * 0.07, 0.2), Vector3(0.008, 0.06, 0.1), dark, Vector3(0, 0, rad_to_deg(a) - 90.0))
	b.commit(parent, "Rocket", false)


## A gun pod's rocket in flight: its body, the motor's flame and light, a trail of smoke and its hiss.
func _rocket_node() -> Node3D:
	var root := Node3D.new()
	rocket_body(root)
	Models.sphere(root, Vector3(0, 0, 0.28), 0.04, Models.emissive(Color(1.0, 0.65, 0.25), 6.0))
	var light := OmniLight3D.new()
	light.position = Vector3(0, 0, 0.4)
	light.omni_range = 4.0
	light.light_energy = 1.6
	light.light_color = Color(1.0, 0.6, 0.3)
	root.add_child(light)
	var trail := GPUParticles3D.new()
	trail.name = "Trail"
	trail.position = Vector3(0, 0, 0.3)
	trail.amount = 36
	trail.lifetime = 0.9
	trail.local_coords = false
	trail.process_material = _trail_material()
	trail.draw_pass_1 = GunPod.smoke_mesh()
	trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	trail.visibility_aabb = AABB(Vector3(-50, -50, -50), Vector3(100, 100, 100))
	root.add_child(trail)
	var audio := AudioStreamPlayer3D.new()
	audio.stream = Sfx.stream("missile_loop")
	audio.volume_db = -12.0
	audio.pitch_scale = 1.3
	audio.unit_size = 5.0
	audio.max_distance = 90.0
	audio.autoplay = true
	root.add_child(audio)
	Sfx.track(audio)
	return root


## A missile bursting: a fireball and a shock wave out to the edge of its blast.
func _missile_fx(pos: Vector3) -> void:
	Fx.explosion(pos, 3.6, Color(1.0, 0.6, 0.25))
	Fx.shockwave(pos, MISSILE_SPLASH, Color(1.0, 0.55, 0.25), 0.35)
	Sfx.play("explosion", pos, 0.0, 1.35)


## Take shot `i` out of the air. A missile's smoke trail stays behind and fades.
func _drop(i: int) -> void:
	var node := _shots[i]["node"] as Node3D
	_shots.remove_at(i)
	var trail := node.get_node_or_null("Trail") as GPUParticles3D
	if trail:
		var xf := trail.global_transform
		node.remove_child(trail)
		add_child(trail)
		trail.global_transform = xf
		trail.emitting = false
		get_tree().create_timer(trail.lifetime + 0.2).timeout.connect(trail.queue_free)
	node.queue_free()


## A missile's body under `parent`, pointing down -Z from its middle: white with a red nose and four
## fins at the tail (also hung under the scouts' wings).
static func missile_body(parent: Node3D, shadows := false) -> void:
	var b := Models.Batch.new()
	var dark := Models.mat(Color(0.12, 0.12, 0.13), 0.5, 0.5)
	b.cyl(Vector3.ZERO, 0.07, 0.75, Models.mat(Color(0.82, 0.82, 0.78), 0.3, 0.5), Vector3(90, 0, 0), -1.0, 10)
	b.cyl(Vector3(0, 0, -0.47), 0.001, 0.2, Models.mat(Color(0.75, 0.12, 0.08), 0.3, 0.5), Vector3(90, 0, 0), 0.07, 10)
	for k in 4:
		var a := TAU * k / 4.0 + PI / 4.0
		b.box(Vector3(cos(a) * 0.1, sin(a) * 0.1, 0.3), Vector3(0.012, 0.1, 0.16), dark, Vector3(0, 0, rad_to_deg(a) - 90.0))
	b.cyl(Vector3(0, 0, 0.39), 0.05, 0.04, dark, Vector3(90, 0, 0), -1.0, 10)
	b.commit(parent, "Missile", shadows)


## A missile in flight: its body, the motor's flame and light, a trail of smoke and the rocket's
## roar.
func _missile_node() -> Node3D:
	var root := Node3D.new()
	missile_body(root)
	Models.sphere(root, Vector3(0, 0, 0.44), 0.06, Models.emissive(Color(1.0, 0.65, 0.25), 6.0))
	var light := OmniLight3D.new()
	light.position = Vector3(0, 0, 0.55)
	light.omni_range = 6.0
	light.light_energy = 2.5
	light.light_color = Color(1.0, 0.6, 0.3)
	root.add_child(light)
	var trail := GPUParticles3D.new()
	trail.name = "Trail"
	trail.position = Vector3(0, 0, 0.45)
	trail.amount = 60
	trail.lifetime = 1.4
	trail.local_coords = false
	trail.process_material = _trail_material()
	trail.draw_pass_1 = GunPod.smoke_mesh()
	trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	trail.visibility_aabb = AABB(Vector3(-60, -60, -60), Vector3(120, 120, 120))
	root.add_child(trail)
	var audio := AudioStreamPlayer3D.new()
	audio.stream = Sfx.stream("missile_loop")
	audio.volume_db = -4.0
	audio.unit_size = 8.0
	audio.max_distance = 160.0
	audio.autoplay = true
	root.add_child(audio)
	Sfx.track(audio)
	return root


## The missile's smoke: puffs left where it passed, swelling and fading from the flame's glow to
## grey.
static func _trail_material() -> ParticleProcessMaterial:
	if _trail_pm:
		return _trail_pm
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.04
	pm.direction = Vector3(0, 0, 1)
	pm.spread = 12.0
	pm.initial_velocity_min = 0.5
	pm.initial_velocity_max = 1.5
	pm.damping_min = 1.0
	pm.damping_max = 2.0
	pm.gravity = Vector3(0, 0.3, 0)
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.4))
	grow.add_point(Vector2(1.0, 2.2))
	var grow_tex := CurveTexture.new()
	grow_tex.curve = grow
	pm.scale_curve = grow_tex
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.08, 0.3, 1.0])
	fade.colors = PackedColorArray([Color(1.6, 1.0, 0.5, 0.9), Color(0.75, 0.68, 0.6, 0.5), Color(0.5, 0.5, 0.5, 0.32), Color(0.4, 0.4, 0.4, 0.0)])
	var fade_tex := GradientTexture1D.new()
	fade_tex.gradient = fade
	pm.color_ramp = fade_tex
	pm.angle_min = -180.0
	pm.angle_max = 180.0
	_trail_pm = pm
	return pm


static func _seg_point_dist(a: Vector3, b: Vector3, p: Vector3) -> float:
	var ab := b - a
	var l2 := ab.length_squared()
	if l2 < 1e-9:
		return a.distance_to(p)
	var t := clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	return (a + ab * t).distance_to(p)


func _xform(pos: Vector3, vel: Vector3) -> Transform3D:
	var dir := vel.normalized() if vel.length_squared() > 1e-6 else Vector3.FORWARD
	var up := Vector3.UP if absf(dir.y) < 0.98 else Vector3.RIGHT
	return Transform3D(Basis.looking_at(dir, up), pos)


## A shot's transform at `pos`; a trail is stretched over the distance it has flown so far (up to
## its full length), so it never reaches back past the muzzle.
func _shot_xform(s: Dictionary, pos: Vector3, vel: Vector3) -> Transform3D:
	var x := _xform(pos, vel)
	var def: Dictionary = KINDS[s["kind"]]
	if def.get("trail", false):
		var flown := (s["from"] as Vector3).distance_to(pos)
		x = x.scaled_local(Vector3(1.0, 1.0, clampf(flown / float(def["len"]), 0.02, 1.0)))
	return x


func _mesh(kind: String) -> Mesh:
	if _meshes.has(kind):
		return _meshes[kind]
	var def: Dictionary = KINDS[kind]
	var m: Mesh
	if def.has("orb"):
		var sm := SphereMesh.new()
		sm.radius = def["orb"]
		sm.height = float(def["orb"]) * 2.0
		sm.radial_segments = 10
		sm.rings = 6
		m = sm
	else:
		var cm := CapsuleMesh.new()
		cm.radius = def["width"]
		cm.height = def["len"]
		cm.radial_segments = 6
		cm.rings = 1
		var st := SurfaceTool.new()
		st.create_from(cm, 0)
		# Capsules are built along Y; rotate them to point down -Z (the direction of travel).
		var arr := st.commit_to_arrays()
		var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var rot := Basis(Vector3.RIGHT, -PI / 2.0)
		# A trail starts at the round and streams out behind it (+Z).
		var shift := Vector3(0, 0, float(def["len"]) * 0.5) if def.get("trail", false) else Vector3.ZERO
		for i in verts.size():
			verts[i] = rot * verts[i] + shift
			norms[i] = rot * norms[i]
		arr[Mesh.ARRAY_VERTEX] = verts
		arr[Mesh.ARRAY_NORMAL] = norms
		arr[Mesh.ARRAY_TANGENT] = null
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		m = am
	_meshes[kind] = m
	return m


func _material(kind: String) -> Material:
	if _mats.has(kind):
		return _mats[kind]
	var c: Color = KINDS[kind]["color"]
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(c.r * 3.0, c.g * 3.0, c.b * 3.0)
	if kind == "spit":
		mat.albedo_color = Color(c.r * 1.6, c.g * 1.6, c.b * 1.6)
	_mats[kind] = mat
	return mat
