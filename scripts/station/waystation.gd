class_name Waystation
extends Node3D
## A waystation built into the tunnel (see StationBuilder). It animates its two bulkhead doors on
## every peer from the mothership's replicated gate state: stations ahead of the ship have their
## entrance open and exit sealed, the station the ship last landed at follows `gate_entry` /
## `gate_exit`, and stations behind it stay sealed for good.

## How fast (open fraction per second) clients move a door towards the replicated gate state; a
## little faster than the server's own rate (Mothership.GATE_RATE) so they keep up.
const FOLLOW_RATE := 0.35

var k := 0
## "entry" / "exit" -> {"panels", "lights", "audio", "pos"} (built by StationBuilder).
var doors: Dictionary = {}
var _open: Dictionary = {}
var _moving: Dictionary = {}


func _physics_process(delta: float) -> void:
	var ship: Mothership = Game.mission.ship if Game.mission else null
	if ship == null:
		return
	var want := targets(ship)
	for id: String in doors:
		var target: float = want[id]
		var first := not _open.has(id)
		var cur: float = target if first else float(_open[id])
		var next := target if multiplayer.is_server() else move_toward(cur, target, FOLLOW_RATE * delta)
		var moving := absf(next - cur) > 0.00001
		_open[id] = next
		if first or moving:
			_apply(id, next)
		if moving != bool(_moving.get(id, false)) and not first:
			_moving[id] = moving
			var d: Dictionary = doors[id]
			var audio: AudioStreamPlayer3D = d["audio"]
			if moving:
				audio.play()
			else:
				audio.stop()
				Sfx.play("gate_clang", to_global(d["pos"]), 4.0)
		_update_lights(id, next, moving)


## Open fraction (0 sealed .. 1 open) each door should have for the ship's progress.
func targets(ship: Mothership) -> Dictionary:
	if k > ship.gate_k:
		return {"entry": 1.0, "exit": 0.0}
	if k == ship.gate_k:
		return {"entry": ship.gate_entry, "exit": ship.gate_exit}
	return {"entry": 0.0, "exit": 0.0}


func is_open(id: String) -> float:
	return float(_open.get(id, 0.0))


func _apply(id: String, open: float) -> void:
	var d: Dictionary = doors[id]
	var e := smoothstep(0.0, 1.0, open)
	var panels: Array = d["panels"]
	for i in panels.size():
		var p: Node3D = panels[i]
		p.position.x = (-1.0 if i == 0 else 1.0) * e * StationBuilder.DOOR_TRAVEL


func _update_lights(id: String, open: float, moving: bool) -> void:
	var col := Color(1.0, 0.1, 0.05)
	if moving:
		col = Color(1.0, 0.6, 0.1) * (0.4 + 0.6 * absf(sin(Time.get_ticks_msec() * 0.008)))
	elif open > 0.98:
		col = Color(0.2, 1.0, 0.35)
	for mat: StandardMaterial3D in doors[id]["lights"]:
		mat.emission = col
