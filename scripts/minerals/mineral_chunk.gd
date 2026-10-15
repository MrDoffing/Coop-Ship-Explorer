class_name MineralChunk
extends Node3D
## A crystal fragment broken off a deposit. It drifts until the mothership's tractor field (or the
## scout, for fuel) pulls it in. Motion is simulated identically on every peer from the spawn
## data; only the server decides when it is collected.

const LIFETIME := 90.0

var kind := "ferrite"
var vel := Vector3.ZERO
var value := 0
var fuel := 0.0
var _life := LIFETIME
var _spin := Vector3.ZERO
var _collected := false


func setup(data: Dictionary) -> void:
	name = str(data["name"])
	kind = str(data["kind"])
	position = data["pos"]
	vel = data["vel"]
	value = int(data["value"])
	fuel = float(data["fuel"])


func _ready() -> void:
	var col: Color = Deposit.TYPES[kind]["color"]
	var mi := MeshInstance3D.new()
	mi.mesh = Models.crystal_mesh()
	mi.material_override = Models.emissive(col, 2.5, col.darkened(0.3))
	mi.scale = Vector3(1.6, 0.9, 1.6)
	mi.position = Vector3(0, -0.35, 0)
	add_child(mi)
	_spin = Vector3(randf_range(-2, 2), randf_range(-3, 3), randf_range(-2, 2))
	rotation = Vector3(randf() * TAU, randf() * TAU, 0)


func _physics_process(delta: float) -> void:
	if _collected:
		return
	_life -= delta
	vel *= exp(-0.9 * delta)
	var target := Vector3.ZERO
	var carrier := Vector3.ZERO
	var attracted := false
	var mission := Game.mission as MissionLevel
	if mission == null:
		return
	if kind == "fuel":
		var scout := mission.scout
		if scout and scout.state == Scout.State.FLYING and scout.cargo < scout.max_cargo - 0.5:
			if scout.global_position.distance_to(global_position) < Scout.PICKUP_RANGE:
				attracted = true
				target = scout.global_position
				carrier = scout.velocity if multiplayer.is_server() else scout.net_vel
	else:
		var ship := mission.ship
		if ship and ship.alive:
			var c := ship.collector_global()
			if c.distance_to(global_position) < float(ship.stats["tractor_range"]):
				attracted = true
				target = c
				carrier = ship.velocity
	if attracted:
		var to := target - global_position
		vel = vel.move_toward(to.normalized() * 24.0 + carrier, 45.0 * delta)
		if to.length() < 2.2:
			_collect(mission)
			return
	position += vel * delta
	rotation += _spin * delta
	if _life <= 0.0 and multiplayer.is_server():
		queue_free()


func _collect(mission: MissionLevel) -> void:
	if not multiplayer.is_server():
		# Hide locally; the server despawns it.
		visible = false
		_collected = true
		return
	_collected = true
	if kind == "fuel":
		var taken := mission.scout.add_cargo(fuel)
		if taken > 0.0:
			mission.fx_event.rpc("fuel_pickup", global_position, 0)
	else:
		mission.ship.collect_mineral(kind, value)
	queue_free()
