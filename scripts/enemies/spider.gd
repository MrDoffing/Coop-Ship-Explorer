class_name Spider
extends Climber
## An acid spider: a squat body on four long legs that grip any surface, so it walks up walls and
## across ceilings as easily as floors. Aggressive: once it spots someone it never stands still for
## long, scurrying from spot to spot round them (SPIT_NEAR..SPIT_FAR away), and stops only to rear
## up and spit a glob of acid.
##
## Its legs are worked out on every peer from where its body is: each foot stays planted where it
## stepped until the body has moved too far from it, then steps to its new place a little ahead of
## the way the body is going (lifting over the way, quicker the faster it goes), never while a
## neighbouring leg is stepping (the diagonal pairs trot together) unless the foot is out of reach;
## a foot lands on whatever is in its way (a wall it walks up to) or the surface under it; a
## two-bone reach puts each knee up and out, and a leg is never drawn longer than it is.

const SPIT_NEAR := 5.0
const SPIT_FAR := 12.0
## It is aggressive: it notices crew further off than most (NOTICE) and chases them further (CHASE).
const NOTICE := 19.0
const CHASE := 30.0
## A scurry lasts SCURRY_TIME, the stop to spit WINDUP (rearing up), and it settles RECOVER after.
const SCURRY_TIME := Vector2(0.9, 2.0)
const WINDUP := 0.5
const RECOVER := 0.35
## The acid: its speed (it arcs, Projectiles "acid") and aim error (radians).
const SPIT_SPEED := 14.0
const SPIT_SPREAD := 0.03
## Legs (body-local): where they join the body and where each foot rests, the thigh's and shin's
## lengths, how far a foot may get from its rest before it steps, and a step's time and lift.
const HIPS := [Vector3(0.2, 0.18, -0.18), Vector3(-0.2, 0.18, -0.18), Vector3(0.2, 0.18, 0.18), Vector3(-0.2, 0.18, 0.18)]
const FEET := [Vector3(0.78, 0.0, -0.7), Vector3(-0.78, 0.0, -0.7), Vector3(0.78, 0.0, 0.62), Vector3(-0.78, 0.0, 0.62)]
const THIGH := 0.62
const SHIN := 0.8
## The closest a foot can come to its hip, the leg folded up (and a foot nearer than TUCKED steps
## out at once).
const FOLDED := SHIN - THIGH + 0.02
const TUCKED := 0.32
const STEP_DIST := 0.42
const STEP_TIME := 0.13
const STEP_LIFT := 0.2
## mode (replicated).
enum { SCURRY, WINDUP_M, RECOVER_M }

var _phase_t := 0.0
var _spot := Vector3.ZERO
# Every peer: each foot's planted point (global), a step under way {from, to, t}, and the body's
# drawn position and velocity (global) the steps lead by.
var _feet: Array[Vector3] = []
var _steps: Array = []
var _body_at := Vector3.ZERO
var _body_vel := Vector3.ZERO
## For the autotests: frames drawn, and in how many of them a foot was out of the leg's reach
## (drawn reaching for it), and by how much at most (m).
var legs_frames := 0
var legs_reaching := 0
var legs_over := 0.0
var _thighs: Array[MeshInstance3D] = []
var _shins: Array[MeshInstance3D] = []


func _setup(data: Dictionary) -> void:
	super._setup(data)
	climb_bias = 0.65


func _think_outside(delta: float, ship: Mothership) -> void:
	_attack_cd = maxf(0.0, _attack_cd - delta)
	_repath -= delta
	var victim := _station_target(delta, ship, NOTICE, CHASE)
	if victim == null:
		mode = SCURRY
		attacking = false
		if not _investigate(delta, ship):
			_idle(delta, 3.0)
		_separate(delta)
		return
	_phase_t -= delta
	match mode:
		SCURRY:
			if _repath <= 0.0 or _path_i >= _path.size():
				_spot = _scurry_spot(ship, victim)
				_set_goal(ship, _graph(ship), _spot)
				_repath = 1.5
			_follow_path(delta)
			var aim_at := victim.position + Vector3(0, aim_height(victim), 0)
			var d := _surf_pos.distance_to(aim_at)
			if _phase_t <= 0.0 and d < SPIT_FAR + 3.0 and _attack_cd <= 0.0 \
					and _clear_from(ship, ship.to_global(_surf_pos + _surf_up * 0.4), ship.to_global(aim_at)):
				mode = WINDUP_M
				_phase_t = WINDUP
				attacking = true
				_climb_t = WINDUP + RECOVER + 0.5
				Game.mission.fx_event.rpc("spider_hiss", ship.to_global(_surf_pos), 0)
		WINDUP_M:
			_face(victim.position - position)
			if _phase_t <= 0.0:
				_spit(ship, victim)
				mode = RECOVER_M
				_phase_t = RECOVER
		RECOVER_M:
			if _phase_t <= 0.0:
				mode = SCURRY
				attacking = false
				_attack_cd = stat("cooldown") * randf_range(0.8, 1.2)
				_phase_t = randf_range(SCURRY_TIME.x, SCURRY_TIME.y)
				_repath = 0.0
	_separate(delta)


## Where to scurry next: a spot round the target, SPIT_NEAR..SPIT_FAR from it, off to one side.
func _scurry_spot(ship: Mothership, victim: Node3D) -> Vector3:
	var away := position - victim.position
	away.y = 0.0
	if away.length_squared() < 0.01:
		away = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
	var dist := clampf(away.length() + randf_range(-3.0, 2.0), SPIT_NEAR, SPIT_FAR)
	var dir := away.normalized().rotated(Vector3.UP, randf_range(-1.2, 1.2))
	var spot := victim.position + dir * dist
	# Keep it where it can walk.
	var graph := _graph(ship)
	var id := graph.get_closest_point(spot)
	return graph.get_point_position(id) if id >= 0 else spot


## A glob of acid from its mouth at the target's chest (a sentry turret's gun), aimed high to allow
## for the drop.
func _spit(ship: Mothership, victim: Node3D) -> void:
	var mouth := ship.to_global(_surf_pos + _surf_up * 0.35)
	var target := ship.to_global(victim.position + Vector3(0, aim_height(victim), 0))
	var dist := mouth.distance_to(target)
	var t := dist / SPIT_SPEED
	target += ship.global_basis.y * (0.5 * Projectiles.ACID_GRAVITY * t * t)
	var dir := (target - mouth).normalized()
	dir = (dir + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * SPIT_SPREAD).normalized()
	Game.mission.projectiles.fire("acid", mouth, dir * SPIT_SPEED, stat("damage") * dmg_mult)
	Game.mission.fx_event.rpc("spider_spit", mouth, 0)


func center_global() -> Vector3:
	return global_transform * Vector3(0, 0.35, 0)


## It goes over to a wall or the ceiling no faster than its legs can follow.
func _climb_speed() -> float:
	return stat("speed") * 1.25


# --- Looks -------------------------------------------------------------------------------------

func _build(model: Node3D) -> Dictionary:
	var shell := Alien.organic(Color(0.12, 0.16, 0.08), Color(0.65, 1.0, 0.2), 1.6, 7.0)
	var skin := Alien.organic(Color(0.2, 0.24, 0.12), Color(0.6, 0.9, 0.2), 1.2, 11.0)
	var acid := Models.emissive(Color(0.65, 1.0, 0.2), 2.2, Color(0.2, 0.35, 0.05))
	var body := Node3D.new()
	body.position = Vector3(0, 0.4, 0)
	model.add_child(body)
	Models.sphere(body, Vector3(0, 0, 0.12), 0.3, shell, Vector3(1.0, 0.7, 1.3))
	Models.sphere(body, Vector3(0, 0.08, 0.32), 0.17, acid, Vector3(1.0, 0.8, 1.0))
	Models.sphere(body, Vector3(0, -0.02, -0.28), 0.16, skin, Vector3(1.1, 0.8, 1.0))
	for side: float in [-1.0, 1.0]:
		Models.strut(body, Vector3(side * 0.06, -0.06, -0.38), Vector3(side * 0.1, -0.16, -0.5), 0.025, shell)
		Models.sphere(body, Vector3(side * 0.07, 0.04, -0.4), 0.025, Models.emissive(Color(1.0, 0.85, 0.2), 5.0))
	# The legs: top-level struts placed by _animate().
	for i in 4:
		var thigh := _leg_mesh(0.06, skin)
		var shin := _leg_mesh(0.04, shell)
		_thighs.append(thigh)
		_shins.append(shin)
		_steps.append({})
	return {"body": body}


func _leg_mesh(r: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r * 0.7
	cm.bottom_radius = r
	cm.height = 1.0
	cm.radial_segments = 6
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = mat
	mi.top_level = true
	# Placed every frame from the body's drawn (interpolated) transform.
	mi.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(mi)
	return mi


func _animate(delta: float) -> void:
	var body: Node3D = _parts.get("body")
	if body == null:
		return
	# Rearing up to spit.
	body.position.y = lerpf(body.position.y, 0.62 if mode == WINDUP_M else 0.4, NetUtil.smooth(10.0, delta))
	body.rotation.x = lerpf(body.rotation.x, 0.35 if mode == WINDUP_M else 0.0, NetUtil.smooth(10.0, delta))
	var x := get_global_transform_interpolated().orthonormalized()
	var up := x.basis.y
	var reach := THIGH + SHIN
	var first := _feet.is_empty()
	if first:
		_body_at = x.origin
	_body_vel = _body_vel.lerp((x.origin - _body_at) / maxf(delta, 0.0001), NetUtil.smooth(10.0, delta))
	_body_at = x.origin
	# Steps aim ahead of where the body is going, and are quicker the faster it goes.
	var lead := _body_vel * STEP_TIME
	lead = (lead - up * lead.dot(up)).limit_length(STEP_DIST)
	var step_time := STEP_TIME / clampf(1.0 + _body_vel.length() * 0.12, 1.0, 1.8)
	legs_frames += 1
	var reaching := false
	for i in 4:
		var rest: Vector3 = x * (FEET[i] as Vector3)
		var hip: Vector3 = x * ((HIPS[i] as Vector3) + body.position - Vector3(0, 0.4, 0))
		if first:
			_feet.append(_foothold(hip, rest, up))
		var step: Dictionary = _steps[i]
		if not step.is_empty():
			step["t"] = float(step["t"]) + delta / step_time
			step["to"] = _foothold(hip, rest + lead, up)
			if float(step["t"]) >= 1.0:
				_feet[i] = step["to"]
				_steps[i] = {}
		else:
			var off := _feet[i].distance_to(rest)
			if off > reach * 2.0:
				# Far off (the body jumped there): the foot is simply put down.
				_feet[i] = _foothold(hip, rest, up)
			elif _feet[i].distance_to(hip) > reach * 0.97 or _feet[i].distance_to(hip) < TUCKED \
					or (off > STEP_DIST and (_steps[i ^ 1] as Dictionary).is_empty() and (_steps[i ^ 2] as Dictionary).is_empty()):
				_steps[i] = {"from": _feet[i], "to": _foothold(hip, rest + lead, up), "t": 0.0}
		var foot := _feet[i]
		step = _steps[i]
		if not step.is_empty():
			var k := float(step["t"])
			foot = (step["from"] as Vector3).lerp(step["to"], k) + up * sin(k * PI) * STEP_LIFT
		# Never longer than the leg (out of reach, it is drawn reaching straight for the spot), nor
		# folded tighter than its two bones can.
		var over := foot.distance_to(hip) - reach
		if over > 0.0:
			reaching = true
			legs_over = maxf(legs_over, over)
		var span := foot - hip
		var span_l := clampf(span.length(), FOLDED, reach - 0.01)
		foot = hip + (span.normalized() if span.length_squared() > 0.0001 else -up) * span_l
		var knee := _knee(hip, foot, up, (hip - x.origin))
		Models.place_strut(_thighs[i], hip, knee)
		Models.place_strut(_shins[i], knee, foot)
	if reaching:
		legs_reaching += 1


## Where a foot reaching from `hip` for `p` lands, the body standing on a surface facing `up`: on
## whatever is in the way (a wall it walks up to, a table), else straight down onto the surface.
func _foothold(hip: Vector3, p: Vector3, up: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(hip, p - up * 0.15, Game.LAYER_STATION)
	var hit := space.intersect_ray(q)
	if not hit.is_empty():
		return hit["position"]
	q = PhysicsRayQueryParameters3D.create(p + up * 0.5, p - up * 0.7, Game.LAYER_STATION)
	hit = space.intersect_ray(q)
	return hit["position"] if not hit.is_empty() else p


## The knee of a leg from `hip` to `foot`: two bones of THIGH and SHIN, bent up (away from the surface)
## and outwards.
static func _knee(hip: Vector3, foot: Vector3, up: Vector3, outward: Vector3) -> Vector3:
	var d := foot - hip
	var length := clampf(d.length(), FOLDED, THIGH + SHIN - 0.01)
	var dir := d.normalized() if d.length_squared() > 0.0001 else -up
	var out := (outward - up * outward.dot(up))
	out = out.normalized() if out.length_squared() > 0.0001 else Vector3.ZERO
	var bend := (up * 0.85 + out * 0.5)
	bend = (bend - dir * bend.dot(dir))
	bend = bend.normalized() if bend.length_squared() > 0.0001 else up
	var a := (THIGH * THIGH - SHIN * SHIN + length * length) / (2.0 * length)
	var h := sqrt(maxf(THIGH * THIGH - a * a, 0.0))
	return hip + dir * a + bend * h
