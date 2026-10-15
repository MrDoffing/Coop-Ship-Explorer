class_name Turret
extends Node3D
## A gun or the mining laser mounted on the mothership hull.
##
## The mount's local -Z is the rest direction. Aim is (yaw, pitch) relative to it, clamped to a
## cone so the gun can't shoot its own hull. All aim maths is done in ship-local space so the
## server and the gunner's client compute identical muzzle positions.

const MUZZLE := Vector3(0, 0, -2.1)
## Over-the-barrel camera, high enough to clear the sponson.
const CAMERA := Vector3(0, 1.5, 0.9)

var is_mining := false
## Yaw range relative to the mount (side guns reach further towards the bow, see reach_forward).
var yaw_min := deg_to_rad(-88.0)
var yaw_max := deg_to_rad(88.0)
var pitch_min := deg_to_rad(-60.0)
var pitch_max := deg_to_rad(72.0)
var aim := Vector2.ZERO
var yaw_pivot: Node3D
var pitch_pivot: Node3D
var _barrel_glow: StandardMaterial3D
var _recoil := 0.0
var _barrels: Array[Node3D] = []


func build(mining: bool) -> void:
	is_mining = mining
	if mining:
		yaw_min = deg_to_rad(-82.0)
		yaw_max = deg_to_rad(82.0)
		pitch_min = deg_to_rad(-80.0)
		pitch_max = deg_to_rad(78.0)
	var metal := Models.mat(Color(0.32, 0.34, 0.38), 0.65, 0.35)
	var dark := Models.mat(Color(0.12, 0.13, 0.15), 0.6, 0.45)
	var glow_color := Color(1.0, 0.45, 0.15) if mining else Color(0.35, 0.85, 1.0)
	_barrel_glow = Models.emissive(glow_color, 1.2)
	# Mount stub reaching back into the sponson.
	Models.cylinder(self, Vector3(0, 0, 0.55), 0.42, 1.1, dark, Vector3(90, 0, 0))
	yaw_pivot = Node3D.new()
	add_child(yaw_pivot)
	Models.sphere(yaw_pivot, Vector3.ZERO, 0.68, metal, Vector3(1.0, 0.85, 1.0))
	Models.box(yaw_pivot, Vector3(0, 0.55, 0.1), Vector3(0.5, 0.18, 0.7), dark)
	pitch_pivot = Node3D.new()
	yaw_pivot.add_child(pitch_pivot)
	if mining:
		var b := Models.cylinder(pitch_pivot, Vector3(0, 0, -1.0), 0.22, 1.6, dark, Vector3(90, 0, 0), 0.3)
		_barrels.append(b)
		Models.cylinder(pitch_pivot, Vector3(0, 0, -1.85), 0.16, 0.2, _barrel_glow, Vector3(90, 0, 0))
		Models.box(pitch_pivot, Vector3(0, 0.3, -0.6), Vector3(0.6, 0.18, 0.9), metal)
	else:
		for x: float in [-0.22, 0.22]:
			var b := Models.cylinder(pitch_pivot, Vector3(x, 0.05, -1.05), 0.11, 1.7, dark, Vector3(90, 0, 0))
			_barrels.append(b)
			Models.cylinder(pitch_pivot, Vector3(x, 0.05, -1.92), 0.08, 0.1, _barrel_glow, Vector3(90, 0, 0))
		Models.box(pitch_pivot, Vector3(0, 0.0, -0.3), Vector3(0.75, 0.42, 0.9), metal)


func set_aim(a: Vector2) -> void:
	aim = clamp_aim(a)
	yaw_pivot.rotation = Vector3(0, aim.x, 0)
	pitch_pivot.rotation = Vector3(aim.y, 0, 0)


## Let a side gun swing past straight ahead so both guns can cover the bow. `limit_deg` is the
## largest yaw towards the bow, measured from the mount's rest direction.
func reach_forward(limit_deg: float) -> void:
	# The aim yaw that points straight ahead is minus the mount's own yaw.
	if -rotation.y < 0.0:
		yaw_min = -deg_to_rad(limit_deg)
	else:
		yaw_max = deg_to_rad(limit_deg)


func clamp_aim(a: Vector2) -> Vector2:
	return Vector2(clampf(a.x, yaw_min, yaw_max), clampf(a.y, pitch_min, pitch_max))


func within_limits(a: Vector2) -> bool:
	return a.x >= yaw_min and a.x <= yaw_max and a.y >= pitch_min and a.y <= pitch_max


## Unclamped (yaw, pitch) that points the barrel at a point in the ship's local space.
func aim_at_local(p: Vector3) -> Vector2:
	var dir := (transform.basis.inverse() * (p - transform.origin)).normalized()
	return Vector2(atan2(-dir.x, -dir.z), asin(clampf(dir.y, -1.0, 1.0)))


## Basis of the barrel for a given aim, in the ship's local space.
func aim_basis_local(a: Vector2) -> Basis:
	return transform.basis * Basis(Vector3.UP, a.x) * Basis(Vector3.RIGHT, a.y)


func muzzle_local(a: Vector2) -> Vector3:
	return transform.origin + aim_basis_local(a) * MUZZLE


func camera_local(a: Vector2) -> Transform3D:
	var b := aim_basis_local(a)
	return Transform3D(b, transform.origin + b * CAMERA)


func kick() -> void:
	_recoil = 1.0


func _process(delta: float) -> void:
	if _recoil > 0.0:
		_recoil = maxf(0.0, _recoil - delta * 6.0)
		for b in _barrels:
			b.position.z = (-1.0 if is_mining else -1.05) + _recoil * 0.25
