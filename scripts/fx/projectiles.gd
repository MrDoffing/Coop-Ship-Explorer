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

const KINDS := {
	"pulse": {"color": Color(0.35, 0.85, 1.0), "len": 2.4, "width": 0.13, "life": 1.6},
	"hmg": {"color": Color(0.75, 0.48, 0.2), "len": 5.0, "width": 0.04, "life": 1.4, "trail": true},
	"flak": {"color": Color(1.0, 0.75, 0.3), "len": 1.0, "width": 0.1, "life": 0.5},
	"plasma": {"color": Color(0.75, 0.4, 1.0), "orb": 0.75, "life": 3.0, "splash": 16.0},
	"scout": {"color": Color(0.45, 1.0, 0.45), "len": 1.6, "width": 0.09, "life": 1.3},
	"spit": {"color": Color(0.55, 1.0, 0.15), "orb": 0.42, "life": 5.0},
	"needle": {"color": Color(1.0, 0.35, 0.85), "len": 0.8, "width": 0.05, "life": 2.0},
}

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
		var from: Vector3 = s["pos"]
		var vel: Vector3 = s["vel"]
		var kind: String = s["kind"]
		if kind == "spit":
			vel += Vector3.DOWN * 2.0 * delta
			s["vel"] = vel
		var to := from + vel * delta
		var done := false
		if kind == "spit":
			done = _spit_step(s, from, to, ship, scouts, space)
		elif kind == "needle":
			var nq := PhysicsRayQueryParameters3D.create(from, to, MASK_NEEDLE)
			var nhit := space.intersect_ray(nq)
			if not nhit.is_empty():
				done = true
				var crew := nhit["collider"] as CrewMember
				if crew and s["auth"]:
					crew.hurt(float(s["dmg"]))
				Fx.sparks(nhit["position"], KINDS["needle"]["color"], 6 if crew == null else 10, 4.0, 0.03, 0.3)
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


func _splash(pos: Vector3, radius: float, dmg: float) -> void:
	var shape := SphereShape3D.new()
	shape.radius = radius
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = Transform3D(Basis.IDENTITY, pos)
	q.collision_mask = Game.LAYER_ENEMY
	q.collide_with_areas = true
	q.collide_with_bodies = false
	for r in get_world_3d().direct_space_state.intersect_shape(q, 64):
		var col: Object = r["collider"]
		if col is Area3D and col.has_meta("target"):
			var tpos: Vector3 = (col as Node3D).global_position
			var falloff := clampf(1.0 - pos.distance_to(tpos) / (radius * 1.4), 0.3, 1.0)
			_damage(col, dmg * falloff, tpos, "splash")


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
