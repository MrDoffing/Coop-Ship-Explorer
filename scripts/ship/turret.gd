class_name Turret
extends Node3D
## A gun or a mining laser mounted on the mothership hull.
##
## The mount's local -Z is the rest direction. Aim is (yaw, pitch) relative to it, clamped to the
## mount's limits so the gun can't shoot its own hull. All aim maths is done in ship-local space so
## the server and the gunner's client compute identical muzzle positions.

var is_mining := false
## "gun", "heavy" (bigger twin cannon), "laser" or "drill" (heavy mining laser head).
var style := "gun"
var yaw_min := deg_to_rad(-88.0)
var yaw_max := deg_to_rad(88.0)
var pitch_min := deg_to_rad(-60.0)
var pitch_max := deg_to_rad(72.0)
var aim := Vector2.ZERO
## Barrel tip and over-the-barrel camera, relative to the pitch pivot.
var muzzle := Vector3(0, 0, -2.1)
var camera_offset := Vector3(0, 1.5, 0.9)
var yaw_pivot: Node3D
var pitch_pivot: Node3D
var _barrel_glow: StandardMaterial3D
var _recoil := 0.0
var _barrels: Array[Node3D] = []
var _barrel_z: Array[float] = []


## Build the turret for a station entry of ShipTypes (kind, style and aim limits in degrees).
func build(def: Dictionary) -> void:
	is_mining = str(def.get("kind", "gun")) == "laser"
	style = str(def.get("style", "laser" if is_mining else "gun"))
	var lim: Array = def.get("limits", [-88.0, 88.0, -60.0, 72.0])
	yaw_min = deg_to_rad(float(lim[0]))
	yaw_max = deg_to_rad(float(lim[1]))
	pitch_min = deg_to_rad(float(lim[2]))
	pitch_max = deg_to_rad(float(lim[3]))
	var metal := Models.mat(Color(0.32, 0.34, 0.38), 0.65, 0.35)
	var dark := Models.mat(Color(0.12, 0.13, 0.15), 0.6, 0.45)
	var steel := Models.mat(Color(0.55, 0.57, 0.6), 0.75, 0.3)
	var glow_color := Color(1.0, 0.45, 0.15) if is_mining else Color(0.35, 0.85, 1.0)
	_barrel_glow = Models.emissive(glow_color, 1.2)
	yaw_pivot = Node3D.new()
	add_child(yaw_pivot)
	pitch_pivot = Node3D.new()
	yaw_pivot.add_child(pitch_pivot)
	match style:
		"heavy":
			muzzle = Vector3(0, 0.05, -3.0)
			camera_offset = Vector3(0, 1.9, 1.3)
			Models.cylinder(self, Vector3(0, 0, 0.7), 0.6, 1.4, dark, Vector3(90, 0, 0))
			Models.sphere(yaw_pivot, Vector3.ZERO, 0.95, metal, Vector3(1.0, 0.8, 1.05))
			Models.cylinder(yaw_pivot, Vector3(0, -0.45, 0), 1.0, 0.25, dark, Vector3.ZERO, -1.0, 20)
			Models.box(yaw_pivot, Vector3(0, 0.72, 0.15), Vector3(0.8, 0.22, 1.0), dark)
			Models.box(pitch_pivot, Vector3(0, 0.05, -0.35), Vector3(1.15, 0.65, 1.3), metal)
			Models.box(pitch_pivot, Vector3(0, 0.05, -1.05), Vector3(1.3, 0.75, 0.16), dark)
			for x: float in [-0.32, 0.32]:
				var b := Models.cylinder(pitch_pivot, Vector3(x, 0.05, -1.55), 0.16, 2.5, dark, Vector3(90, 0, 0))
				_barrels.append(b)
				Models.cylinder(b, Vector3(0, -0.95, 0), 0.21, 0.35, steel)
				Models.cylinder(b, Vector3(0, -1.27, 0), 0.12, 0.08, _barrel_glow)
		"drill":
			muzzle = Vector3(0, 0, -2.45)
			camera_offset = Vector3(0, 1.7, 1.1)
			Models.sphere(yaw_pivot, Vector3.ZERO, 0.85, metal, Vector3(1.0, 0.9, 1.0))
			var b := Models.cylinder(pitch_pivot, Vector3(0, 0, -1.15), 0.34, 1.9, dark, Vector3(90, 0, 0), 0.42)
			_barrels.append(b)
			for i in 3:
				Models.cylinder(b, Vector3(0, -0.55 + i * 0.42, 0), 0.5, 0.12, steel, Vector3.ZERO, -1.0, 20)
			Models.cylinder(pitch_pivot, Vector3(0, 0, -2.2), 0.24, 0.26, _barrel_glow, Vector3(90, 0, 0))
			Models.box(pitch_pivot, Vector3(0, 0.45, -0.55), Vector3(0.7, 0.24, 1.1), Models.mat(Color(0.95, 0.75, 0.15), 0.3, 0.5))
			for x: float in [-0.48, 0.48]:
				Models.cylinder(pitch_pivot, Vector3(x, -0.05, -0.75), 0.1, 1.2, steel, Vector3(90, 0, 0))
		"laser":
			Models.cylinder(self, Vector3(0, 0, 0.55), 0.42, 1.1, dark, Vector3(90, 0, 0))
			Models.sphere(yaw_pivot, Vector3.ZERO, 0.68, metal, Vector3(1.0, 0.85, 1.0))
			Models.box(yaw_pivot, Vector3(0, 0.55, 0.1), Vector3(0.5, 0.18, 0.7), dark)
			var b := Models.cylinder(pitch_pivot, Vector3(0, 0, -1.0), 0.22, 1.6, dark, Vector3(90, 0, 0), 0.3)
			_barrels.append(b)
			Models.cylinder(b, Vector3(0, -0.2, 0), 0.3, 0.1, steel, Vector3.ZERO, -1.0, 16)
			Models.cylinder(pitch_pivot, Vector3(0, 0, -1.85), 0.16, 0.2, _barrel_glow, Vector3(90, 0, 0))
			Models.box(pitch_pivot, Vector3(0, 0.3, -0.6), Vector3(0.6, 0.18, 0.9), metal)
			for x: float in [-0.26, 0.26]:
				Models.box(pitch_pivot, Vector3(x, 0.0, -0.45), Vector3(0.06, 0.36, 0.6), steel)
		_:
			# Mount stub reaching back into the sponson.
			Models.cylinder(self, Vector3(0, 0, 0.55), 0.42, 1.1, dark, Vector3(90, 0, 0))
			Models.sphere(yaw_pivot, Vector3.ZERO, 0.68, metal, Vector3(1.0, 0.85, 1.0))
			Models.box(yaw_pivot, Vector3(0, 0.55, 0.1), Vector3(0.5, 0.18, 0.7), dark)
			for x: float in [-0.22, 0.22]:
				var b := Models.cylinder(pitch_pivot, Vector3(x, 0.05, -1.05), 0.11, 1.7, dark, Vector3(90, 0, 0))
				_barrels.append(b)
				Models.cylinder(b, Vector3(0, -0.62, 0), 0.14, 0.22, steel)
				Models.cylinder(pitch_pivot, Vector3(x, 0.05, -1.92), 0.08, 0.1, _barrel_glow, Vector3(90, 0, 0))
			Models.box(pitch_pivot, Vector3(0, 0.0, -0.3), Vector3(0.75, 0.42, 0.9), metal)
			Models.box(pitch_pivot, Vector3(0, 0.24, -0.3), Vector3(0.5, 0.06, 0.6), dark)
	for b in _barrels:
		_barrel_z.append(b.position.z)


func set_aim(a: Vector2) -> void:
	aim = clamp_aim(a)
	yaw_pivot.rotation = Vector3(0, aim.x, 0)
	pitch_pivot.rotation = Vector3(aim.y, 0, 0)


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
	return transform.origin + aim_basis_local(a) * muzzle


func camera_local(a: Vector2) -> Transform3D:
	var b := aim_basis_local(a)
	return Transform3D(b, transform.origin + b * camera_offset)


func kick() -> void:
	_recoil = 1.0


func _process(delta: float) -> void:
	if _recoil > 0.0:
		_recoil = maxf(0.0, _recoil - delta * 6.0)
		for i in _barrels.size():
			_barrels[i].position.z = _barrel_z[i] + _recoil * 0.25
