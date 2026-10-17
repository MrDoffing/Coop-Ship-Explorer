class_name ShipTypes
extends RefCounted
## The motherships the crew can fly: base stats, stations and the exterior layout of each.
##
## Each ship has its own walkable interior (see ShipInteriors; the Prospector has the original
## layout), the consoles of its stations fitted into it, where the guns, mining lasers, scout docks
## and auto turret hardpoints sit on the hull, the hull's size and shape (collision, shield, landing
## legs, the points aliens latch onto) and its looks. Ship-local space: +Y up, -Z forward, the deck
## floor at y = 0. Every hull ends at z = 11.8 (the cargo ramp hinge) and every ship stands with its
## feet 4.2 m below the deck.

const ORDER := ["prospector", "vanguard", "excavator", "dreadnought"]

## Ship catalogue. Station entries: "kind" is "pilot", "gun", "laser" or "scout", "spot" the
## console spot in the ship's interior (ShipInteriors); guns and lasers have a hull mount ("pos", rest "yaw" in degrees, "limits" = [yaw min, yaw max, pitch min,
## pitch max] in degrees relative to the rest direction, "style"), scouts a dock ("dock") and the
## direction they are launched in ("launch", ship-local velocity). Guns are gun pods (GunPod;
## "pos" is the centre of the ball) on a "mount": a "barbette" up from the roof or deck at height
## "base", or a "tower" (a column on an outrigger arm) for a pod out beside the hull. The pods sit
## where their barrels clear the hull over the whole aim range (checked by the gunpod autotest).
const TYPES := {
	"prospector": {
		"name": "Prospector", "role": "Mining frigate", "cost": 0,
		"desc": "The crew's trusty all-rounder: a gun pod on each side, a nose-mounted mining laser and a scout pod under the belly.",
		"hull": 400.0, "shield": 120.0, "speed": 9.0, "accel": 2.6, "yaw": 26.0, "vert": 5.0, "slots": 1,
		"mining": 1.0, "laser_vs_alien": 1.0, "scout_hp": 1.0, "scout_damage": 1.0, "scout_speed": 1.0,
		"scout_style": "standard", "chase": 40.0,
		"paint": Color(0.62, 0.64, 0.68), "accent": Color(0.95, 0.5, 0.12), "trim": Color(0.95, 0.6, 0.15),
		"sections": [
			[-13.8, 0.9, 0.7, 1.3], [-11.6, 3.5, 2.2, 1.4], [-9.2, 4.4, 2.95, 1.4], [-7.4, 4.7, 3.05, 1.4],
			[-6.6, 7.3, 3.25, 1.4], [7.0, 7.4, 3.3, 1.4], [10.4, 6.6, 3.0, 1.4], [11.8, 5.0, 2.3, 1.4],
		],
		"chamfer": 0.3,
		"stations": [
			{"id": "pilot", "kind": "pilot", "spot": "cockpit", "name": "Pilot Seat", "label": "PILOT"},
			{"id": "gun_l", "kind": "gun", "spot": "port_window", "name": "Port Gun", "label": "PORT GUN",
				"pos": Vector3(-10.0, 1.9, -5.0), "yaw": 90.0, "limits": [-124.0, 88.0, -60.0, 72.0], "style": "gun", "mount": "tower"},
			{"id": "gun_r", "kind": "gun", "spot": "stbd_window", "name": "Starboard Gun", "label": "STARBOARD GUN",
				"pos": Vector3(10.0, 1.9, -5.0), "yaw": -90.0, "limits": [-88.0, 124.0, -60.0, 72.0], "style": "gun", "mount": "tower"},
			{"id": "mining", "kind": "laser", "spot": "front_port", "name": "Mining Laser", "label": "MINING LASER",
				"pos": Vector3(0, 1.45, -14.35), "yaw": 0.0, "limits": [-82.0, 82.0, -80.0, 78.0], "style": "laser"},
			{"id": "scout", "kind": "scout", "spot": "bay", "name": "Scout Bay", "label": "SCOUT BAY",
				"dock": Vector3(0, -3.15, 3.5), "launch": Vector3(0, -7.0, 0)},
		],
		"boxes": [[Vector3(0, 1.4, 0.3), Vector3(19.0, 6.8, 28.0)], [Vector3(0, -2.7, 3.5), Vector3(5.5, 1.8, 6.0)]],
		"shield_center": Vector3(0, 1.4, -0.6), "shield_radii": Vector3(11.5, 6.8, 16.8),
		"collector": Vector3(0, -2.0, -2.0),
		"legs": [Vector3(-3.4, -1.7, -7.0), Vector3(3.4, -1.7, -7.0), Vector3(-4.6, -1.7, 8.6), Vector3(4.6, -1.7, 8.6)],
		"roof": 4.75,
		"hatches": [Vector3(0, 4.75, -2.0), Vector3(-4.2, 4.75, 3.0), Vector3(0, 4.75, 7.2)],
		"hull_points": [
			[Vector3(-3.2, 4.72, -4.5), Vector3.UP], [Vector3(3.2, 4.72, -4.5), Vector3.UP],
			[Vector3(-3.4, 4.72, 5.0), Vector3.UP], [Vector3(3.4, 4.72, 5.0), Vector3.UP],
			[Vector3(-7.42, 1.6, 1.5), Vector3.LEFT], [Vector3(7.42, 1.6, 1.5), Vector3.RIGHT],
			[Vector3(-7.32, 1.0, 7.5), Vector3.LEFT], [Vector3(7.32, 1.0, 7.5), Vector3.RIGHT],
			[Vector3(-3.0, -1.92, -3.0), Vector3.DOWN], [Vector3(3.0, -1.92, -3.0), Vector3.DOWN],
			[Vector3(-3.8, -1.92, 8.0), Vector3.DOWN], [Vector3(3.8, -1.92, 8.0), Vector3.DOWN],
			[Vector3(0, 3.95, -10.6), Vector3(0, 0.75, -0.66)], [Vector3(0, 3.42, 11.85), Vector3.BACK],
		],
		"hardpoints": [
			{"pos": Vector3(-6.2, 4.17, -4.0), "rot": Vector3(0, 0, 0.42)},
			{"pos": Vector3(6.2, 4.17, -4.0), "rot": Vector3(0, 0, -0.42)},
			{"pos": Vector3(-6.2, 4.25, 6.2), "rot": Vector3(0, 0, 0.42)},
			{"pos": Vector3(6.2, 4.25, 6.2), "rot": Vector3(0, 0, -0.42)},
		],
	},
	"vanguard": {
		"name": "Vanguard Carrier", "role": "Scout carrier", "cost": 250,
		"desc": "A carrier with a flight deck and two combat scouts (tougher, faster and harder-hitting than the standard pod). Only one gun pod, on the bow.",
		"hull": 380.0, "shield": 140.0, "speed": 9.4, "accel": 2.8, "yaw": 27.0, "vert": 5.2, "slots": 1,
		"mining": 1.0, "laser_vs_alien": 1.0, "scout_hp": 1.6, "scout_damage": 1.5, "scout_speed": 1.15,
		"scout_style": "combat", "chase": 42.0,
		"paint": Color(0.46, 0.52, 0.6), "accent": Color(0.3, 0.6, 1.0), "trim": Color(0.35, 0.65, 1.0),
		"sections": [
			[-15.6, 1.2, 0.8, 1.2], [-13.2, 3.9, 2.2, 1.3], [-10.2, 4.9, 2.9, 1.4], [-7.4, 5.3, 3.1, 1.4],
			[-6.6, 7.0, 3.2, 1.4], [7.0, 7.1, 3.25, 1.4], [10.4, 6.4, 2.95, 1.4], [11.8, 5.0, 2.3, 1.4],
		],
		"chamfer": 0.3,
		"stations": [
			{"id": "pilot", "kind": "pilot", "spot": "bridge_pilot", "name": "Pilot Seat", "label": "PILOT"},
			{"id": "gun_f", "kind": "gun", "spot": "bridge_port", "name": "Bow Gun", "label": "BOW GUN",
				"pos": Vector3(0, 6.75, -17.4), "yaw": 0.0, "limits": [-150.0, 150.0, -35.0, 80.0], "style": "gun", "mount": "barbette", "base": 5.0},
			{"id": "mining", "kind": "laser", "spot": "bridge_stbd", "name": "Mining Laser", "label": "MINING LASER",
				"pos": Vector3(0, 1.2, -16.15), "yaw": 0.0, "limits": [-82.0, 82.0, -80.0, 55.0], "style": "laser"},
			{"id": "scout", "kind": "scout", "spot": "flight_a", "name": "Scout Bay A", "label": "SCOUT A",
				"dock": Vector3(-3.4, 5.62, -6.2), "launch": Vector3(0, 6.0, -4.0)},
			{"id": "scout2", "kind": "scout", "spot": "flight_b", "name": "Scout Bay B", "label": "SCOUT B",
				"dock": Vector3(3.2, 5.62, -6.2), "launch": Vector3(0, 6.0, -4.0)},
		],
		"boxes": [[Vector3(0, 1.4, -1.9), Vector3(17.0, 6.6, 27.4)], [Vector3(0, 4.85, -4.1), Vector3(16.8, 0.5, 30.6)],
			[Vector3(7.1, 6.85, 4.5), Vector3(2.4, 3.6, 8.0)]],
		"shield_center": Vector3(0, 2.0, -3.6), "shield_radii": Vector3(12.0, 7.6, 19.2),
		"collector": Vector3(0, -1.9, -2.0),
		"legs": [Vector3(-3.4, -1.6, -7.0), Vector3(3.4, -1.6, -7.0), Vector3(-4.6, -1.6, 8.6), Vector3(4.6, -1.6, 8.6)],
		"roof": 5.06,
		"hatches": [Vector3(0, 5.06, -4.8), Vector3(0, 5.06, 1.0), Vector3(0, 5.06, 7.0)],
		"hull_points": [
			[Vector3(-6.2, 5.06, -10.5), Vector3.UP], [Vector3(6.2, 5.06, -10.5), Vector3.UP],
			[Vector3(-6.4, 5.06, 6.0), Vector3.UP], [Vector3(0.0, 5.06, 10.2), Vector3.UP],
			[Vector3(-7.12, 1.6, 1.5), Vector3.LEFT], [Vector3(7.12, 1.6, 1.5), Vector3.RIGHT],
			[Vector3(-7.02, 1.0, 7.5), Vector3.LEFT], [Vector3(7.02, 1.0, 7.5), Vector3.RIGHT],
			[Vector3(-3.0, -1.82, -3.0), Vector3.DOWN], [Vector3(3.0, -1.82, -3.0), Vector3.DOWN],
			[Vector3(-3.8, -1.82, 8.0), Vector3.DOWN], [Vector3(3.8, -1.82, 8.0), Vector3.DOWN],
			[Vector3(0, 3.42, 11.85), Vector3.BACK],
		],
		"hardpoints": [
			{"pos": Vector3(-7.3, 5.06, -8.6), "rot": Vector3.ZERO},
			{"pos": Vector3(-7.3, 5.06, 4.4), "rot": Vector3.ZERO},
			{"pos": Vector3(3.2, 5.06, 9.7), "rot": Vector3.ZERO},
			{"pos": Vector3(0, -1.78, -9.0), "rot": Vector3(0, 0, PI)},
		],
	},
	"excavator": {
		"name": "Excavator Prime", "role": "Heavy mining ship", "cost": 300,
		"desc": "An industrial miner with two arm-mounted mining lasers that cut crystal (and aliens) far faster. One gun pod on the front corner, and two auto turret slots.",
		"hull": 460.0, "shield": 110.0, "speed": 8.4, "accel": 2.4, "yaw": 24.0, "vert": 4.8, "slots": 2,
		"mining": 1.45, "laser_vs_alien": 1.6, "scout_hp": 1.0, "scout_damage": 1.0, "scout_speed": 1.0,
		"scout_style": "standard", "chase": 42.0,
		"paint": Color(0.93, 0.72, 0.16), "accent": Color(0.12, 0.12, 0.13), "trim": Color(1.0, 0.78, 0.15),
		"sections": [
			[-13.6, 2.0, 1.3, 1.1], [-11.6, 4.2, 2.5, 1.3], [-9.2, 4.9, 3.0, 1.4], [-7.4, 5.1, 3.1, 1.4],
			[-6.6, 7.4, 3.45, 1.4], [7.0, 7.5, 3.45, 1.4], [10.4, 6.8, 3.1, 1.4], [11.8, 5.2, 2.4, 1.4],
		],
		"chamfer": 0.2,
		"stations": [
			{"id": "pilot", "kind": "pilot", "spot": "ctl_pilot", "name": "Pilot Seat", "label": "PILOT"},
			{"id": "gun_f", "kind": "gun", "spot": "gunnery", "name": "Forward Gun", "label": "FORWARD GUN",
				"pos": Vector3(5.6, 6.5, -5.6), "yaw": -45.0, "limits": [-150.0, 150.0, -35.0, 80.0], "style": "gun", "mount": "barbette", "base": 4.8},
			{"id": "mining", "kind": "laser", "spot": "ctl_port", "name": "Port Mining Laser", "label": "PORT LASER",
				"pos": Vector3(-3.8, 0.15, -16.7), "yaw": 0.0, "limits": [-78.0, 62.0, -75.0, 70.0], "style": "drill"},
			{"id": "mining2", "kind": "laser", "spot": "ctl_stbd", "name": "Starboard Mining Laser", "label": "STARBOARD LASER",
				"pos": Vector3(3.8, 0.15, -16.7), "yaw": 0.0, "limits": [-62.0, 78.0, -75.0, 70.0], "style": "drill"},
			{"id": "scout", "kind": "scout", "spot": "lift_bay", "name": "Scout Lift", "label": "SCOUT LIFT",
				"dock": Vector3(0, 5.42, 3.8), "launch": Vector3(0, 7.0, 0)},
		],
		"boxes": [[Vector3(0, 1.4, -0.9), Vector3(18.0, 7.0, 25.4)], [Vector3(0, 0.2, -12.4), Vector3(10.4, 2.2, 9.2)],
			[Vector3(0, -2.6, -2.0), Vector3(3.4, 1.2, 3.4)]],
		"shield_center": Vector3(0, 1.3, -2.6), "shield_radii": Vector3(12.4, 7.2, 19.0),
		"collector": Vector3(0, -3.0, -2.0),
		"legs": [Vector3(-3.6, -1.85, -6.8), Vector3(3.6, -1.85, -6.8), Vector3(-4.8, -1.85, 8.6), Vector3(4.8, -1.85, 8.6)],
		"roof": 4.87,
		"hatches": [Vector3(-4.0, 4.87, -2.6), Vector3(3.6, 4.87, 1.8), Vector3(-3.4, 4.87, 7.0)],
		"hull_points": [
			[Vector3(-3.2, 4.87, -4.5), Vector3.UP], [Vector3(3.2, 4.87, -4.5), Vector3.UP],
			[Vector3(-4.4, 4.87, 6.5), Vector3.UP], [Vector3(4.4, 4.87, 6.5), Vector3.UP],
			[Vector3(-8.62, 2.0, 0.0), Vector3.LEFT], [Vector3(8.62, 2.0, 0.0), Vector3.RIGHT],
			[Vector3(-8.62, 1.2, 6.0), Vector3.LEFT], [Vector3(8.62, 1.2, 6.0), Vector3.RIGHT],
			[Vector3(-3.2, -2.07, -5.0), Vector3.DOWN], [Vector3(3.2, -2.07, -5.0), Vector3.DOWN],
			[Vector3(-3.8, -2.07, 8.0), Vector3.DOWN], [Vector3(3.8, -2.07, 8.0), Vector3.DOWN],
			[Vector3(0, 3.5, 11.85), Vector3.BACK],
		],
		"hardpoints": [
			{"pos": Vector3(-5.6, 4.87, -5.6), "rot": Vector3.ZERO},
			{"pos": Vector3(-5.5, 4.87, 1.5), "rot": Vector3.ZERO},
			{"pos": Vector3(5.5, 4.87, 1.5), "rot": Vector3.ZERO},
			{"pos": Vector3(4.2, 4.87, 9.2), "rot": Vector3.ZERO},
		],
	},
	"dreadnought": {
		"name": "Dreadnought", "role": "Heavy warship", "cost": 400,
		"desc": "Big, armoured and slow. Three armoured gun pods (one on each side and one on the front corner) and two auto turret slots.",
		"hull": 640.0, "shield": 160.0, "speed": 7.6, "accel": 2.2, "yaw": 22.0, "vert": 4.4, "slots": 2,
		"mining": 1.0, "laser_vs_alien": 1.0, "scout_hp": 1.0, "scout_damage": 1.0, "scout_speed": 1.0,
		"scout_style": "standard", "chase": 47.0,
		"paint": Color(0.6, 0.11, 0.09), "accent": Color(0.95, 0.68, 0.2), "trim": Color(1.0, 0.3, 0.2),
		"sections": [
			[-17.0, 1.6, 1.1, 0.9], [-14.6, 4.8, 2.6, 1.2], [-11.4, 6.2, 3.4, 1.35], [-8.0, 6.8, 3.6, 1.4],
			[-6.8, 8.7, 3.9, 1.4], [7.2, 8.9, 4.0, 1.4], [10.4, 7.9, 3.6, 1.4], [11.8, 6.2, 2.8, 1.4],
		],
		"chamfer": 0.3,
		"stations": [
			{"id": "pilot", "kind": "pilot", "spot": "helm", "name": "Pilot Seat", "label": "HELM"},
			{"id": "gun_l", "kind": "gun", "spot": "battery_port", "name": "Port Gun", "label": "PORT BATTERY",
				"pos": Vector3(-11.4, 2.4, -6.0), "yaw": 90.0, "limits": [-124.0, 88.0, -60.0, 72.0], "style": "heavy", "mount": "tower"},
			{"id": "gun_r", "kind": "gun", "spot": "battery_stbd", "name": "Starboard Gun", "label": "STARBOARD BATTERY",
				"pos": Vector3(11.4, 2.4, -6.0), "yaw": -90.0, "limits": [-88.0, 124.0, -60.0, 72.0], "style": "heavy", "mount": "tower"},
			{"id": "gun_f", "kind": "gun", "spot": "bridge_stbd", "name": "Forward Gun", "label": "FORWARD GUN",
				"pos": Vector3(5.9, 6.8, -10.2), "yaw": -45.0, "limits": [-150.0, 150.0, -35.0, 80.0], "style": "heavy", "mount": "barbette", "base": 4.0},
			{"id": "mining", "kind": "laser", "spot": "bridge_port", "name": "Mining Laser", "label": "MINING LASER",
				"pos": Vector3(0, 2.3, -17.45), "yaw": 0.0, "limits": [-82.0, 82.0, -80.0, 78.0], "style": "laser"},
			{"id": "scout", "kind": "scout", "spot": "scout_bay", "name": "Scout Bay", "label": "SCOUT BAY",
				"dock": Vector3(0, -3.3, 4.0), "launch": Vector3(0, -7.0, 0)},
		],
		"boxes": [[Vector3(0, 1.4, -2.6), Vector3(21.6, 8.0, 28.8)], [Vector3(0, -3.0, 4.0), Vector3(5.5, 1.4, 6.0)]],
		"shield_center": Vector3(0, 1.4, -2.2), "shield_radii": Vector3(13.6, 8.2, 20.0),
		"collector": Vector3(0, -2.8, -2.5),
		"legs": [Vector3(-4.2, -2.4, -8.0), Vector3(4.2, -2.4, -8.0), Vector3(-5.6, -2.4, 8.4), Vector3(5.6, -2.4, 8.4)],
		"roof": 5.42,
		"hatches": [Vector3(0, 5.42, -5.4), Vector3(0, 5.42, 0.2), Vector3(0, 5.42, 6.0)],
		"hull_points": [
			[Vector3(-3.2, 5.42, -4.5), Vector3.UP], [Vector3(3.2, 5.42, -4.5), Vector3.UP],
			[Vector3(-3.4, 5.42, 5.0), Vector3.UP], [Vector3(3.4, 5.42, 5.0), Vector3.UP],
			[Vector3(-9.22, 1.6, 1.5), Vector3.LEFT], [Vector3(9.22, 1.6, 1.5), Vector3.RIGHT],
			[Vector3(-9.22, 1.0, 6.5), Vector3.LEFT], [Vector3(9.22, 1.0, 6.5), Vector3.RIGHT],
			[Vector3(-3.0, -2.62, -3.0), Vector3.DOWN], [Vector3(3.0, -2.62, -3.0), Vector3.DOWN],
			[Vector3(-3.8, -2.62, 8.6), Vector3.DOWN], [Vector3(3.8, -2.62, 8.6), Vector3.DOWN],
			[Vector3(0, 3.9, 11.85), Vector3.BACK],
		],
		"hardpoints": [
			{"pos": Vector3(-7.9, 4.68, -2.0), "rot": Vector3(0, 0, 0.42)},
			{"pos": Vector3(7.9, 4.68, -2.0), "rot": Vector3(0, 0, -0.42)},
			{"pos": Vector3(-7.9, 4.68, 7.0), "rot": Vector3(0, 0, 0.42)},
			{"pos": Vector3(7.9, 4.68, 7.0), "rot": Vector3(0, 0, -0.42)},
			{"pos": Vector3(0, 5.42, 1.6), "rot": Vector3.ZERO},
		],
	},
}

static var _cache: Dictionary = {}


static func exists(id: String) -> bool:
	return TYPES.has(id)


## The full layout of a ship type, with lookup tables added: "by_id" (station id -> entry),
## "guns", "lasers", "scouts" and "aimables" (guns then lasers: every station with a turret), and
## "interior" (its ShipInteriors layout).
static func get_type(id: String) -> Dictionary:
	if not TYPES.has(id):
		id = "prospector"
	if _cache.has(id):
		return _cache[id]
	var t: Dictionary = (TYPES[id] as Dictionary).duplicate(true)
	t["id"] = id
	var inner := ShipInteriors.get_layout(id)
	t["interior"] = inner
	var by_id := {}
	var guns: Array[String] = []
	var lasers: Array[String] = []
	var scouts: Array[String] = []
	var order: Array[String] = []
	for st: Dictionary in t["stations"]:
		var sid := str(st["id"])
		var spot: Dictionary = inner["spots"][st["spot"]]
		st["seat"] = spot["seat"]
		st["seat_yaw"] = spot["yaw"]
		st["console"] = spot["console"]
		st["console_size"] = spot["size"]
		by_id[sid] = st
		order.append(sid)
		match str(st["kind"]):
			"gun":
				guns.append(sid)
			"laser":
				lasers.append(sid)
			"scout":
				scouts.append(sid)
	var aimables: Array[String] = []
	aimables.append_array(guns)
	aimables.append_array(lasers)
	t["by_id"] = by_id
	t["order"] = order
	t["guns"] = guns
	t["lasers"] = lasers
	t["scouts"] = scouts
	t["aimables"] = aimables
	var hatches: Array = []
	for i in (t["hatches"] as Array).size():
		hatches.append({"outside": t["hatches"][i], "inside": inner["hatches"][i]})
	t["hatch_list"] = hatches
	t["leg_length"] = 4.2 + float((t["legs"] as Array)[0].y)
	t["max_slots"] = (t["hardpoints"] as Array).size()
	_cache[id] = t
	return t


static func display_name(id: String) -> String:
	return str(TYPES.get(id, TYPES["prospector"])["name"])
