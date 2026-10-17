class_name Derelict
extends Node3D
## An abandoned station built into the cave wall (see DerelictBuilder). The node only animates its
## failing lights; the mothership spawns the station's salvage and hostiles when it lands there.

var k := 0
## Lights that cut out now and then: {"light", "energy", "rate", "phase"}.
var flicker: Array = []
var _t := 0.0


func add_flicker(light: Light3D, rate: float, phase: float) -> void:
	flicker.append({"light": light, "energy": light.light_energy, "rate": rate, "phase": phase})


func _process(delta: float) -> void:
	_t += delta
	for f: Dictionary in flicker:
		var v := fmod(_t * float(f["rate"]) + float(f["phase"]), 1.0)
		# Short dropouts, a stutter, then steady again.
		var off := v < 0.06 or (v > 0.1 and v < 0.13) or (v > 0.55 and v < 0.57)
		(f["light"] as Light3D).light_energy = float(f["energy"]) * (0.08 if off else 1.0)
