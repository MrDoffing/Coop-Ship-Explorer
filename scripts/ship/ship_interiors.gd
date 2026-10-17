class_name ShipInteriors
extends RefCounted
## The walkable interior of each mothership. The Prospector has the original layout; the other
## ships have layouts of their own so a new ship feels fresh to the crew. ShipBuilder builds the
## rooms; this file holds everything the rest of the game needs to know about them.
##
## Ship-local space: +Y up, -Z forward, the deck floor at y = 0. Every interior ends at the same rear
## wall (z = 10.125) with the cargo door and the corridor to the ramp hinged at z = 11.8.
##
## Keys of a layout:
## - "height": ceiling height, "door_h": height of the doorways between rooms, "half_w": x of the
##   outer walls (their centre lines), which is also how wide the rear wall is.
## - "spots": console spots stations can be fitted to (ShipTypes picks them by name): seat, the yaw
##   the seated crew member faces, console position and size.
## - "panels": repair panels {system, pos, yaw} (yaw: the direction the panel faces, which is where
##   the crew stands to repair it).
## - "hub" / "hub_yaw": the install hub (its front faces local +x turned by hub_yaw), "hub_room": where
##   it is, for prompts. "button": the emergency blast button.
## - "cores": engine reactor cores. "engine_room": box (min, max) of the engine room, where the
##   engine hum is heard at full level (it fades with distance from the room).
## - "waypoints" / "links": the walking graph for crew bots and boarders; "exit" is the waypoint by
##   the cargo door (linked to the ramp at abandoned stations).
## - "spawns": where crew members appear, "idle": where crew bots wait without a job, "hatches": the
##   floor below each roof hatch (ShipTypes "hatches" holds the hatches on the roof, same order).
## - "aboard": box (min, max) of the inside of the ship (the cargo corridor counts, the ramp does not),
##   "walk": where crew may be while flying.
## - "lights" / "alarms": ceiling lights and red alarm lights.

const LAYOUTS := {
	"prospector": {
		"height": 3.2, "door_h": 2.4, "half_w": 6.125,
		"spots": {
			"cockpit": {"seat": Vector3(0, 0, -8.5), "yaw": 0.0, "console": Vector3(0, 0, -9.55), "size": Vector3(3.4, 0.9, 0.8)},
			"port_window": {"seat": Vector3(-4.75, 0, -2.5), "yaw": PI / 2.0, "console": Vector3(-5.55, 0, -2.5), "size": Vector3(0.8, 1.0, 1.8)},
			"stbd_window": {"seat": Vector3(4.75, 0, -2.5), "yaw": -PI / 2.0, "console": Vector3(5.55, 0, -2.5), "size": Vector3(0.8, 1.0, 1.8)},
			"front_port": {"seat": Vector3(-3.6, 0, -4.75), "yaw": 0.0, "console": Vector3(-3.6, 0, -5.55), "size": Vector3(1.8, 1.0, 0.8)},
			"front_stbd": {"seat": Vector3(3.6, 0, -4.75), "yaw": 0.0, "console": Vector3(3.6, 0, -5.55), "size": Vector3(1.8, 1.0, 0.8)},
			"bay": {"seat": Vector3(4.75, 0, 3.0), "yaw": -PI / 2.0, "console": Vector3(5.55, 0, 3.0), "size": Vector3(0.8, 1.0, 1.6)},
			"bay_a": {"seat": Vector3(4.75, 0, 2.05), "yaw": -PI / 2.0, "console": Vector3(5.55, 0, 2.05), "size": Vector3(0.8, 1.0, 1.15)},
			"bay_b": {"seat": Vector3(4.75, 0, 3.95), "yaw": -PI / 2.0, "console": Vector3(5.55, 0, 3.95), "size": Vector3(0.8, 1.0, 1.15)},
		},
		"panels": [
			{"system": "engine", "pos": Vector3(-3.6, 1.3, 9.94), "yaw": 0.0},
			{"system": "engine", "pos": Vector3(3.6, 1.3, 9.94), "yaw": 0.0},
			{"system": "weapons", "pos": Vector3(-5.94, 1.3, 2.0), "yaw": -PI / 2.0},
			{"system": "weapons", "pos": Vector3(-5.94, 1.3, 4.0), "yaw": -PI / 2.0},
		],
		"hub": Vector3(-5.5, 0, 7.2), "hub_yaw": 0.0, "hub_room": "engine room",
		"button": Vector3(2.25, 0, -8.6),
		"cores": [Vector3(0, 0, 7.8)],
		"engine_room": [Vector3(-6.0, 0.0, 5.125), Vector3(6.0, 3.2, 10.0)],
		"waypoints": {
			"cockpit": Vector3(0, 0, -8.0), "cock_door": Vector3(0, 0, -6.1), "front": Vector3(0, 0, -3.6),
			"gun_l": Vector3(-4.1, 0, -2.6), "gun_r": Vector3(4.1, 0, -2.6), "mining": Vector3(-3.2, 0, -4.4),
			"front_stbd": Vector3(3.2, 0, -4.4),
			"hall": Vector3(0, 0, 0.8), "hall2": Vector3(0, 0, 3.0), "weap_door": Vector3(-2.5, 0, 3.0),
			"weap": Vector3(-4.3, 0, 3.0), "scout_door": Vector3(2.5, 0, 3.0), "scout": Vector3(4.2, 0, 3.0),
			"eng_door": Vector3(0, 0, 5.0), "eng": Vector3(0, 0, 6.0), "eng_lf": Vector3(-2.6, 0, 6.0),
			"eng_rf": Vector3(2.6, 0, 6.0), "eng_l": Vector3(-3.6, 0, 8.9), "eng_r": Vector3(3.6, 0, 8.9),
			"cargo": Vector3(0, 0, 9.5),
		},
		"links": [
			["cockpit", "cock_door"], ["cock_door", "front"], ["front", "gun_l"], ["front", "gun_r"],
			["front", "mining"], ["front", "front_stbd"], ["front", "hall"], ["gun_l", "hall"], ["gun_r", "hall"],
			["hall", "hall2"], ["hall2", "weap_door"], ["weap_door", "weap"], ["hall2", "scout_door"],
			["scout_door", "scout"], ["hall2", "eng_door"], ["eng_door", "eng"], ["eng", "eng_lf"], ["eng", "eng_rf"],
			["eng_lf", "eng_l"], ["eng_rf", "eng_r"], ["eng_l", "cargo"], ["eng_r", "cargo"],
		],
		"exit": "cargo",
		"spawns": [Vector3(0, 0.1, 2.2), Vector3(-1.2, 0.1, 1.2), Vector3(1.2, 0.1, 1.2), Vector3(0, 0.1, 3.6)],
		"idle": [Vector3(0.6, 0, 1.6), Vector3(-0.6, 0, 2.6), Vector3(0.0, 0, 4.0)],
		"hatches": [Vector3(0, 0, -2.0), Vector3(-4.2, 0, 3.0), Vector3(0, 0, 6.2)],
		"aboard": [Vector3(-6.4, -1.0, -11.0), Vector3(6.4, 4.0, 11.6)],
		"walk": [Vector3(-7.0, -3.0, -11.0), Vector3(7.0, 6.0, 12.2)],
		"lights": [Vector3(0, 2.8, -8.2), Vector3(-3.2, 2.8, -3.0), Vector3(3.2, 2.8, -3.0), Vector3(0, 2.8, 2.0),
			Vector3(-4.3, 2.8, 3.0), Vector3(4.3, 2.8, 3.0), Vector3(-3.0, 2.8, 7.6), Vector3(3.0, 2.8, 7.6)],
		"alarms": [Vector3(0, 3.0, -4.0), Vector3(0, 3.0, 2.8), Vector3(0, 3.0, 8.5), Vector3(0, 3.0, -8.5)],
	},
	# A carrier: a three-seat bridge, a narrow spine corridor with four rooms off it (flight operations
	# for each scout, weapon systems, the quartermaster's store with the install hub) and twin reactors.
	"vanguard": {
		"height": 3.2, "door_h": 2.4, "half_w": 6.125,
		"spots": {
			"bridge_pilot": {"seat": Vector3(0, 0, -10.4), "yaw": 0.0, "console": Vector3(0, 0, -11.45), "size": Vector3(1.8, 0.9, 0.7)},
			"bridge_port": {"seat": Vector3(-2.3, 0, -10.4), "yaw": 0.0, "console": Vector3(-2.3, 0, -11.45), "size": Vector3(1.4, 1.0, 0.7)},
			"bridge_stbd": {"seat": Vector3(2.3, 0, -10.4), "yaw": 0.0, "console": Vector3(2.3, 0, -11.45), "size": Vector3(1.4, 1.0, 0.7)},
			"flight_a": {"seat": Vector3(-4.75, 0, -3.75), "yaw": PI / 2.0, "console": Vector3(-5.55, 0, -3.75), "size": Vector3(0.8, 1.0, 1.6)},
			"flight_b": {"seat": Vector3(4.75, 0, -3.75), "yaw": -PI / 2.0, "console": Vector3(5.55, 0, -3.75), "size": Vector3(0.8, 1.0, 1.6)},
		},
		"panels": [
			{"system": "engine", "pos": Vector3(-5.94, 1.3, 8.2), "yaw": -PI / 2.0},
			{"system": "engine", "pos": Vector3(5.94, 1.3, 8.2), "yaw": PI / 2.0},
			{"system": "weapons", "pos": Vector3(-5.94, 1.3, 1.2), "yaw": -PI / 2.0},
			{"system": "weapons", "pos": Vector3(-5.94, 1.3, 3.6), "yaw": -PI / 2.0},
		],
		"hub": Vector3(5.5, 0, 2.4), "hub_yaw": PI, "hub_room": "quartermaster's store",
		"button": Vector3(1.15, 0, -10.75),
		"cores": [Vector3(-3.0, 0, 8.0), Vector3(3.0, 0, 8.0)],
		"engine_room": [Vector3(-6.0, 0.0, 5.625), Vector3(6.0, 3.2, 10.0)],
		"waypoints": {
			"bridge": Vector3(0, 0, -9.3), "bridge_l": Vector3(-2.3, 0, -9.4), "bridge_r": Vector3(2.3, 0, -9.4),
			"bridge_door": Vector3(0, 0, -6.75), "spine_f": Vector3(0, 0, -3.75),
			"fa_door": Vector3(-1.425, 0, -3.75), "fa": Vector3(-3.6, 0, -3.75),
			"fb_door": Vector3(1.425, 0, -3.75), "fb": Vector3(3.6, 0, -3.75),
			"spine_m": Vector3(0, 0, -0.6), "spine_a": Vector3(0, 0, 2.4),
			"weap_door": Vector3(-1.425, 0, 2.4), "weap": Vector3(-4.0, 0, 2.4),
			"qm_door": Vector3(1.425, 0, 2.4), "qm": Vector3(3.8, 0, 2.4),
			"eng_door": Vector3(0, 0, 5.5), "eng": Vector3(0, 0, 6.2), "eng_l": Vector3(-4.9, 0, 6.4),
			"eng_r": Vector3(4.9, 0, 6.4), "cargo": Vector3(0, 0, 9.5),
		},
		"links": [
			["bridge", "bridge_l"], ["bridge", "bridge_r"], ["bridge", "bridge_door"], ["bridge_door", "spine_f"],
			["spine_f", "fa_door"], ["fa_door", "fa"], ["spine_f", "fb_door"], ["fb_door", "fb"],
			["spine_f", "spine_m"], ["spine_m", "spine_a"], ["spine_a", "weap_door"], ["weap_door", "weap"],
			["spine_a", "qm_door"], ["qm_door", "qm"], ["spine_a", "eng_door"], ["eng_door", "eng"],
			["eng", "eng_l"], ["eng", "eng_r"], ["eng", "cargo"],
		],
		"exit": "cargo",
		"spawns": [Vector3(0, 0.1, -1.8), Vector3(0, 0.1, -0.6), Vector3(0, 0.1, 0.6), Vector3(0, 0.1, 1.6)],
		"idle": [Vector3(3.4, 0, 3.8), Vector3(-3.6, 0, -2.4), Vector3(3.6, 0, -2.4)],
		"hatches": [Vector3(0, 0, -4.8), Vector3(0, 0, 1.0), Vector3(0, 0, 7.0)],
		"aboard": [Vector3(-6.4, -1.0, -12.3), Vector3(6.4, 4.0, 11.6)],
		"walk": [Vector3(-7.0, -3.0, -12.6), Vector3(7.0, 6.0, 12.2)],
		"lights": [Vector3(0, 2.8, -9.6), Vector3(0, 2.8, -4.6), Vector3(0, 2.8, 1.4), Vector3(-3.8, 2.8, -3.75),
			Vector3(3.8, 2.8, -3.75), Vector3(-3.8, 2.8, 2.4), Vector3(3.8, 2.8, 2.4), Vector3(0, 2.8, 7.4),
			Vector3(0, 2.8, 9.3)],
		"alarms": [Vector3(0, 3.0, -9.6), Vector3(0, 3.0, -3.0), Vector3(0, 3.0, 2.0), Vector3(0, 3.0, 8.0)],
	},
	# A mining ship: a control room with the pilot between the two laser consoles, an open ore hall
	# with a walk-around crusher (the weapon systems are built into it), the gun and scout lift
	# consoles on the starboard wall, and the engine room behind it.
	"excavator": {
		"height": 3.2, "door_h": 2.4, "half_w": 6.6,
		"spots": {
			"ctl_pilot": {"seat": Vector3(0, 0, -8.6), "yaw": 0.0, "console": Vector3(0, 0, -9.65), "size": Vector3(1.8, 0.9, 0.7)},
			"ctl_port": {"seat": Vector3(-2.2, 0, -8.6), "yaw": 0.0, "console": Vector3(-2.2, 0, -9.65), "size": Vector3(1.3, 1.0, 0.7)},
			"ctl_stbd": {"seat": Vector3(2.2, 0, -8.6), "yaw": 0.0, "console": Vector3(2.2, 0, -9.65), "size": Vector3(1.3, 1.0, 0.7)},
			"gunnery": {"seat": Vector3(5.275, 0, -4.6), "yaw": -PI / 2.0, "console": Vector3(6.075, 0, -4.6), "size": Vector3(0.8, 1.0, 1.8)},
			"lift_bay": {"seat": Vector3(5.275, 0, 3.0), "yaw": -PI / 2.0, "console": Vector3(6.075, 0, 3.0), "size": Vector3(0.8, 1.0, 1.6)},
		},
		"panels": [
			{"system": "engine", "pos": Vector3(-6.405, 1.3, 8.2), "yaw": -PI / 2.0},
			{"system": "engine", "pos": Vector3(6.405, 1.3, 8.2), "yaw": PI / 2.0},
			{"system": "weapons", "pos": Vector3(-2.07, 1.3, -1.6), "yaw": PI / 2.0},
			{"system": "weapons", "pos": Vector3(2.07, 1.3, -1.6), "yaw": -PI / 2.0},
		],
		"hub": Vector3(-6.025, 0, 3.0), "hub_yaw": 0.0, "hub_room": "ore hall",
		"button": Vector3(1.12, 0, -9.05),
		"cores": [Vector3(0, 0, 7.7)],
		"engine_room": [Vector3(-6.475, 0.0, 5.725), Vector3(6.475, 3.2, 10.0)],
		"waypoints": {
			"ctl": Vector3(0, 0, -7.4), "ctl_l": Vector3(-2.2, 0, -7.5), "ctl_r": Vector3(2.2, 0, -7.5),
			"ctl_door": Vector3(0, 0, -5.8), "hall_f": Vector3(0, 0, -4.75), "hall_fl": Vector3(-4.3, 0, -4.75),
			"hall_fr": Vector3(4.3, 0, -4.75), "hall_l": Vector3(-4.3, 0, -1.6), "hall_r": Vector3(4.3, 0, -1.6),
			"hall_bl": Vector3(-4.3, 0, 2.0), "hall_br": Vector3(4.3, 0, 2.0), "hall_b": Vector3(0, 0, 2.6),
			"eng_door": Vector3(0, 0, 5.6), "eng": Vector3(0, 0, 6.15), "eng_l": Vector3(-3.8, 0, 6.3),
			"eng_r": Vector3(3.8, 0, 6.3), "eng_lb": Vector3(-3.8, 0, 9.45), "eng_rb": Vector3(3.8, 0, 9.45),
			"cargo": Vector3(0, 0, 9.45),
		},
		"links": [
			["ctl", "ctl_l"], ["ctl", "ctl_r"], ["ctl", "ctl_door"], ["ctl_door", "hall_f"], ["hall_f", "hall_fl"],
			["hall_f", "hall_fr"], ["hall_fl", "hall_l"], ["hall_fr", "hall_r"], ["hall_l", "hall_bl"], ["hall_r", "hall_br"],
			["hall_bl", "hall_b"], ["hall_br", "hall_b"], ["hall_b", "eng_door"], ["eng_door", "eng"], ["eng", "eng_l"],
			["eng", "eng_r"], ["eng_l", "eng_lb"], ["eng_r", "eng_rb"], ["eng_lb", "cargo"], ["eng_rb", "cargo"],
		],
		"exit": "cargo",
		"spawns": [Vector3(0, 0.1, 2.0), Vector3(-1.5, 0.1, 3.0), Vector3(1.5, 0.1, 3.0), Vector3(0, 0.1, 3.8)],
		"idle": [Vector3(-4.2, 0, 4.2), Vector3(4.2, 0, 4.2), Vector3(0, 0, -4.75)],
		"hatches": [Vector3(-4.0, 0, -2.6), Vector3(3.6, 0, 1.8), Vector3(-3.4, 0, 7.0)],
		"aboard": [Vector3(-6.8, -1.0, -10.5), Vector3(6.8, 4.0, 11.6)],
		"walk": [Vector3(-7.4, -3.0, -11.0), Vector3(7.4, 6.0, 12.2)],
		"lights": [Vector3(0, 2.8, -8.2), Vector3(-4.3, 2.8, -4.4), Vector3(4.3, 2.8, -4.4), Vector3(-4.3, 2.8, 1.4),
			Vector3(4.3, 2.8, 1.4), Vector3(0, 2.8, 2.9), Vector3(-3.6, 2.8, 7.6), Vector3(3.6, 2.8, 7.6)],
		"alarms": [Vector3(0, 3.0, -8.5), Vector3(0, 3.0, -5.0), Vector3(0, 3.0, 2.5), Vector3(0, 3.0, 8.5)],
	},
	# A warship, taller and wider than the rest: a bridge far forward, a combat information centre
	# with the side gun batteries and a plotting table, twin corridors round the armoury core (the
	# weapon systems) with the magazine and the scout bay either side, and twin reactors.
	"dreadnought": {
		"height": 3.6, "door_h": 2.6, "half_w": 7.8,
		"spots": {
			"helm": {"seat": Vector3(0, 0, -11.7), "yaw": 0.0, "console": Vector3(0, 0, -12.75), "size": Vector3(2.6, 0.9, 0.8)},
			"bridge_port": {"seat": Vector3(-2.475, 0, -11.0), "yaw": PI / 2.0, "console": Vector3(-3.275, 0, -11.0), "size": Vector3(0.8, 1.0, 1.6)},
			"bridge_stbd": {"seat": Vector3(2.475, 0, -11.0), "yaw": -PI / 2.0, "console": Vector3(3.275, 0, -11.0), "size": Vector3(0.8, 1.0, 1.6)},
			"battery_port": {"seat": Vector3(-6.475, 0, -2.5), "yaw": PI / 2.0, "console": Vector3(-7.275, 0, -2.5), "size": Vector3(0.8, 1.0, 1.8)},
			"battery_stbd": {"seat": Vector3(6.475, 0, -2.5), "yaw": -PI / 2.0, "console": Vector3(7.275, 0, -2.5), "size": Vector3(0.8, 1.0, 1.8)},
			"scout_bay": {"seat": Vector3(6.475, 0, 2.2), "yaw": -PI / 2.0, "console": Vector3(7.275, 0, 2.2), "size": Vector3(0.8, 1.0, 1.6)},
		},
		"panels": [
			{"system": "engine", "pos": Vector3(-7.605, 1.3, 7.6), "yaw": -PI / 2.0},
			{"system": "engine", "pos": Vector3(7.605, 1.3, 7.6), "yaw": PI / 2.0},
			{"system": "weapons", "pos": Vector3(-1.87, 1.3, 2.35), "yaw": PI / 2.0},
			{"system": "weapons", "pos": Vector3(1.87, 1.3, 2.35), "yaw": -PI / 2.0},
		],
		"hub": Vector3(-7.225, 0, 3.6), "hub_yaw": 0.0, "hub_room": "magazine",
		"button": Vector3(1.75, 0, -12.6),
		"cores": [Vector3(-4.4, 0, 7.6), Vector3(4.4, 0, 7.6)],
		"engine_room": [Vector3(-7.675, 0.0, 5.125), Vector3(7.675, 3.6, 10.0)],
		"waypoints": {
			"helm": Vector3(0, 0, -10.4), "bridge_l": Vector3(-1.4, 0, -10.2), "bridge_r": Vector3(1.4, 0, -10.2),
			"bridge_door": Vector3(0, 0, -8.6), "vest": Vector3(0, 0, -7.6), "cic_door": Vector3(0, 0, -6.6),
			"cic_f": Vector3(0, 0, -5.4), "cic_fl": Vector3(-4.0, 0, -5.4), "cic_fr": Vector3(4.0, 0, -5.4),
			"cic_l": Vector3(-4.0, 0, -2.5), "cic_r": Vector3(4.0, 0, -2.5),
			"cic_bl": Vector3(-3.4, 0, -1.4), "cic_br": Vector3(3.4, 0, -1.4),
			"cdoor_l": Vector3(-3.4, 0, -0.6), "cdoor_r": Vector3(3.4, 0, -0.6),
			"cor_lf": Vector3(-3.25, 0, 0.2), "cor_rf": Vector3(3.25, 0, 0.2), "core_f": Vector3(0, 0, 0.2),
			"cor_l": Vector3(-3.25, 0, 2.2), "cor_r": Vector3(3.25, 0, 2.2),
			"mag_door": Vector3(-4.8, 0, 2.2), "mag": Vector3(-6.0, 0, 2.2),
			"bay_door": Vector3(4.8, 0, 2.2), "bay": Vector3(5.7, 0, 3.4),
			"cor_lb": Vector3(-3.25, 0, 4.4), "cor_rb": Vector3(3.25, 0, 4.4),
			"eng_dl": Vector3(-3.25, 0, 5.75), "eng_dr": Vector3(3.25, 0, 5.75), "eng_c": Vector3(0, 0, 5.9),
			"eng_l": Vector3(-6.6, 0, 5.8), "eng_r": Vector3(6.6, 0, 5.8), "cargo": Vector3(0, 0, 9.5),
		},
		"links": [
			["helm", "bridge_l"], ["helm", "bridge_r"], ["helm", "bridge_door"], ["bridge_door", "vest"],
			["vest", "cic_door"], ["cic_door", "cic_f"], ["cic_f", "cic_fl"], ["cic_f", "cic_fr"], ["cic_fl", "cic_l"],
			["cic_fr", "cic_r"], ["cic_l", "cic_bl"], ["cic_r", "cic_br"], ["cic_bl", "cdoor_l"], ["cic_br", "cdoor_r"],
			["cdoor_l", "cor_lf"], ["cdoor_r", "cor_rf"], ["cor_lf", "core_f"], ["cor_rf", "core_f"], ["cor_lf", "cor_l"],
			["cor_rf", "cor_r"], ["cor_l", "mag_door"], ["mag_door", "mag"], ["cor_r", "bay_door"], ["bay_door", "bay"],
			["cor_l", "cor_lb"], ["cor_r", "cor_rb"], ["cor_lb", "eng_dl"], ["cor_rb", "eng_dr"], ["eng_dl", "eng_c"],
			["eng_dr", "eng_c"], ["eng_dl", "eng_l"], ["eng_dr", "eng_r"], ["eng_c", "cargo"],
		],
		"exit": "cargo",
		"spawns": [Vector3(0, 0.1, -1.6), Vector3(-1.6, 0.1, -1.4), Vector3(1.6, 0.1, -1.4), Vector3(0, 0.1, 0.2)],
		"idle": [Vector3(-3.25, 0, 3.6), Vector3(3.25, 0, 3.6), Vector3(0, 0, -1.6)],
		"hatches": [Vector3(0, 0, -5.4), Vector3(0, 0, 0.2), Vector3(0, 0, 6.0)],
		"aboard": [Vector3(-8.0, -1.0, -13.8), Vector3(8.0, 4.4, 11.6)],
		"walk": [Vector3(-8.6, -3.0, -14.2), Vector3(8.6, 6.4, 12.2)],
		"lights": [Vector3(0, 3.2, -11.0), Vector3(-4.5, 3.2, -4.0), Vector3(4.5, 3.2, -4.0), Vector3(0, 3.2, -2.0),
			Vector3(-3.25, 3.2, 2.2), Vector3(3.25, 3.2, 2.2), Vector3(-6.3, 3.2, 2.2), Vector3(6.3, 3.2, 2.2),
			Vector3(-2.2, 3.2, 7.2), Vector3(2.2, 3.2, 7.2)],
		"alarms": [Vector3(0, 3.4, -11.0), Vector3(0, 3.4, -4.0), Vector3(-3.25, 3.4, 2.2), Vector3(3.25, 3.4, 2.2),
			Vector3(0, 3.4, 8.0)],
	},
}


static func get_layout(ship_id: String) -> Dictionary:
	return LAYOUTS.get(ship_id, LAYOUTS["prospector"])


## Where a crew member stands to work on repair panel `p` (floor level).
static func panel_spot(p: Dictionary) -> Vector3:
	var yaw: float = p["yaw"]
	var spot: Vector3 = p["pos"] + Vector3(-sin(yaw), 0, -cos(yaw)) * 0.9
	spot.y = 0.0
	return spot


## A fresh AStar graph over a layout's waypoints (point ids follow the "waypoints" order).
static func build_nav(inner: Dictionary) -> AStar3D:
	var astar := AStar3D.new()
	add_to_nav(astar, inner)
	return astar


## Add a layout's waypoints and links to `astar`; returns waypoint name -> point id.
static func add_to_nav(astar: AStar3D, inner: Dictionary) -> Dictionary:
	var ids := {}
	var wps: Dictionary = inner["waypoints"]
	for k: String in wps:
		var id := astar.get_available_point_id()
		astar.add_point(id, wps[k])
		ids[k] = id
	for link: Array in inner["links"]:
		astar.connect_points(ids[link[0]], ids[link[1]])
	return ids
