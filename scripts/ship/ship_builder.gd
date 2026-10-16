class_name ShipBuilder
extends RefCounted
## Builds the motherships' exterior hulls and the shared walkable interior.
##
## Ship-local space: +Y up, -Z forward, the interior deck floor is at y = 0. The interior fits
## inside every ship's lofted exterior hull (see ShipTypes), whose back faces are culled so windows
## look out into the cave. Which consoles the interior has depends on the ship type.

## Machine parts the crew repairs with the toolkit.
const REPAIR_PANELS := [
	{"system": "engine", "pos": Vector3(-3.6, 1.3, 9.94), "yaw": 0.0},
	{"system": "engine", "pos": Vector3(3.6, 1.3, 9.94), "yaw": 0.0},
	{"system": "weapons", "pos": Vector3(-5.94, 1.3, 2.0), "yaw": -PI / 2.0},
	{"system": "weapons", "pos": Vector3(-5.94, 1.3, 4.0), "yaw": -PI / 2.0},
]

const SPAWN_POINTS := [Vector3(0, 0.1, 2.2), Vector3(-1.2, 0.1, 1.2), Vector3(1.2, 0.1, 1.2), Vector3(0, 0.1, 3.6)]

## The big red emergency blast button, beside the pilot seat.
const EMERGENCY_BUTTON := Vector3(2.25, 0, -8.6)

## Interior navigation graph for boarding aliens and crew bots (ship-local).
const WAYPOINTS := {
	"cockpit": Vector3(0, 0, -8.0), "cock_door": Vector3(0, 0, -6.1), "front": Vector3(0, 0, -3.6),
	"gun_l": Vector3(-4.1, 0, -2.6), "gun_r": Vector3(4.1, 0, -2.6), "mining": Vector3(-3.2, 0, -4.4),
	"front_stbd": Vector3(3.2, 0, -4.4),
	"hall": Vector3(0, 0, 0.8), "hall2": Vector3(0, 0, 3.0), "weap_door": Vector3(-2.5, 0, 3.0),
	"weap": Vector3(-4.3, 0, 3.0), "scout_door": Vector3(2.5, 0, 3.0), "scout": Vector3(4.2, 0, 3.0),
	"eng_door": Vector3(0, 0, 5.0), "eng": Vector3(0, 0, 6.0), "eng_l": Vector3(-3.6, 0, 8.9),
	"eng_r": Vector3(3.6, 0, 8.9), "cargo": Vector3(0, 0, 9.5),
}
const WAYPOINT_LINKS := [
	["cockpit", "cock_door"], ["cock_door", "front"], ["front", "gun_l"], ["front", "gun_r"],
	["front", "mining"], ["front", "front_stbd"], ["front", "hall"], ["gun_l", "hall"], ["gun_r", "hall"],
	["hall", "hall2"], ["hall2", "weap_door"], ["weap_door", "weap"], ["hall2", "scout_door"],
	["scout_door", "scout"], ["hall2", "eng_door"], ["eng_door", "eng"], ["eng", "eng_l"], ["eng", "eng_r"],
	["eng_l", "cargo"], ["eng_r", "cargo"],
]

## Cargo door at the stern: a short corridor through the hull to a ramp hinged at the hull's end.
const DOOR_HALF_W := 1.4
const DOOR_H := 3.0
const RAMP_HINGE := Vector3(0, 0, 11.8)
const RAMP_LENGTH := 3.2
const RAMP_WIDTH := 2.9
## Open ramp angle from vertical: it slopes 1 m down onto a waystation pier (asin(1 / 3.2) past 90°).
const RAMP_OPEN := 1.8886
## Crew inside this box (ship-local) are aboard; the cargo corridor counts, the ramp does not.
const ABOARD_MIN := Vector3(-6.4, -1.0, -11.0)
const ABOARD_MAX := Vector3(6.4, 4.0, 11.6)
## Barrel tip relative to an auto turret's pitch node.
const AUTOCANNON_MUZZLE := Vector3(0, 0, -1.35)
## Console where crew fit upgrades from supply crates (engine room, port side).
const INSTALL_HUB := Vector3(-5.5, 0, 7.2)


# --- Hull geometry helpers ---------------------------------------------------------------------

## Interpolated hull cross-section at depth z: (half width, half height, y centre).
static func section_at(sections: Array, z: float) -> Vector3:
	var first: Array = sections[0]
	if z <= float(first[0]):
		return Vector3(first[1], first[2], first[3])
	for i in sections.size() - 1:
		var a: Array = sections[i]
		var b: Array = sections[i + 1]
		if z <= float(b[0]):
			var t := (z - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.001)
			return Vector3(lerpf(a[1], b[1], t), lerpf(a[2], b[2], t), lerpf(a[3], b[3], t))
	var last: Array = sections[sections.size() - 1]
	return Vector3(last[1], last[2], last[3])


static func top_y(sections: Array, z: float) -> float:
	var s := section_at(sections, z)
	return s.z + s.y


static func bottom_y(sections: Array, z: float) -> float:
	var s := section_at(sections, z)
	return s.z - s.y


static func side_x(sections: Array, z: float) -> float:
	return section_at(sections, z).x


static func _mats(t: Dictionary) -> Dictionary:
	var paint: Color = t["paint"]
	var accent: Color = t["accent"]
	return {
		"hull": Models.panel_mat(paint, 0.25, 0.5, 0.25),
		"paint": Models.panel_mat(paint.darkened(0.12), 0.3, 0.5, 0.6),
		"dark": Models.mat(Color(0.14, 0.15, 0.18), 0.6, 0.5),
		"mid": Models.mat(Color(0.32, 0.34, 0.38), 0.6, 0.45),
		"steel": Models.mat(Color(0.55, 0.57, 0.6), 0.75, 0.3),
		"black": Models.mat(Color(0.07, 0.07, 0.08), 0.4, 0.6),
		"accent": Models.mat(accent, 0.3, 0.5),
		"hazard": Models.mat(Color(0.95, 0.74, 0.1), 0.3, 0.5),
		"glass": Models.emissive(Color(0.25, 0.6, 0.8), 0.6, Color(0.05, 0.08, 0.1)),
		"window": Models.emissive(Color(1.0, 0.84, 0.58), 1.5, Color(0.1, 0.08, 0.05)),
		"red": Models.emissive(Color(1, 0.15, 0.1), 5.0),
		"green": Models.emissive(Color(0.2, 1, 0.3), 5.0),
		"amber": Models.emissive(Color(1.0, 0.6, 0.15), 4.0),
		"white": Models.emissive(Color(1.0, 0.95, 0.85), 4.0),
		"cyan": Models.emissive(Color(0.35, 0.85, 1.0), 2.5),
	}


# --- Exterior ----------------------------------------------------------------------------------

## Build the exterior of a ship type under `root`. Returns handles to animated parts: "turrets"
## (station id -> Turret), "legs", "autocannons" (hardpoints), "lights", "engine_glow_mat".
static func build_exterior(root: Node3D, type_id: String) -> Dictionary:
	var t := ShipTypes.get_type(type_id)
	var m := _mats(t)
	var parts := {}
	var sections: Array = t["sections"]
	var chamfer := float(t["chamfer"])
	var hull := MeshInstance3D.new()
	hull.name = "Hull"
	hull.mesh = Models.loft(sections, chamfer, false)
	hull.material_override = m["hull"]
	root.add_child(hull)
	_rear_cap(root, sections, chamfer, m["hull"])
	var glow_mat := StandardMaterial3D.new()
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_mat.albedo_color = Color(0.45, 0.8, 1.0)
	parts["engine_glow_mat"] = glow_mat
	var b := Models.Batch.new()
	match str(t["id"]):
		"vanguard":
			_dress_vanguard(root, b, t, m, glow_mat)
		"excavator":
			_dress_excavator(root, b, t, m, glow_mat)
		"dreadnought":
			_dress_dreadnought(root, b, t, m, glow_mat)
		_:
			_dress_prospector(root, b, t, m, glow_mat)
	_common_fittings(root, b, t, m)
	b.commit(root)
	# Turrets and mining lasers.
	var turrets := {}
	for id: String in t["aimables"]:
		var def: Dictionary = t["by_id"][id]
		var tur := Turret.new()
		tur.name = "Turret_" + id
		tur.position = def["pos"]
		tur.rotation = Vector3(0, deg_to_rad(float(def["yaw"])), 0)
		root.add_child(tur)
		tur.build(def)
		turrets[id] = tur
	parts["turrets"] = turrets
	parts["lights"] = _lights(root, t, m)
	parts["legs"] = _legs(root, t, m)
	parts["autocannons"] = _hardpoints(root, t, m)
	_name_labels(root, t)
	return parts


## Fittings every ship has: roof hatches, scout docks, the cargo door frame, landing gear bays
## and the tractor emitter.
static func _common_fittings(root: Node3D, b: Models.Batch, t: Dictionary, m: Dictionary) -> void:
	var sections: Array = t["sections"]
	for h: Vector3 in t["hatches"]:
		b.box(Vector3(h.x, h.y - 0.03, h.z), Vector3(1.6, 0.06, 1.6), m["dark"])
		b.box(Vector3(h.x, h.y - 0.01, h.z), Vector3(1.2, 0.04, 0.12), m["accent"])
		for dx: float in [-0.62, 0.62]:
			b.box(Vector3(h.x + dx, h.y - 0.005, h.z), Vector3(0.12, 0.04, 1.3), m["steel"])
	for sid: String in t["scouts"]:
		var def: Dictionary = t["by_id"][sid]
		var dock: Vector3 = def["dock"]
		var launch: Vector3 = def["launch"]
		if launch.y < 0.0:
			var py := bottom_y(sections, dock.z) - 0.04
			b.box(Vector3(dock.x, py, dock.z), Vector3(3.8, 0.12, 5.8), m["dark"])
			for x: float in [-1.5, 1.5]:
				b.box(Vector3(dock.x + x, (py + dock.y + 0.62) * 0.5, dock.z), Vector3(0.25, absf(py - dock.y - 0.62) + 0.1, 3.2), m["mid"])
			b.box(Vector3(dock.x, py - 0.03, dock.z - 3.1), Vector3(3.0, 0.08, 0.3), m["accent"])
			b.sphere(Vector3(dock.x, py - 0.08, dock.z + 3.3), 0.12, m["green"])
		else:
			var py := dock.y - 0.57
			b.box(Vector3(dock.x, py, dock.z), Vector3(4.6, 0.08, 5.8), m["dark"])
			for i in 16:
				var a := TAU * i / 16.0
				b.box(Vector3(dock.x + cos(a) * 2.0, py + 0.05, dock.z + sin(a) * 2.0), Vector3(0.7, 0.03, 0.12), m["hazard"], Vector3(0, -rad_to_deg(a) + 90.0, 0))
			for c: Vector2 in [Vector2(-1.9, -2.5), Vector2(1.9, -2.5), Vector2(-1.9, 2.5), Vector2(1.9, 2.5)]:
				b.box(Vector3(dock.x + c.x, py + 0.12, dock.z + c.y), Vector3(0.5, 0.18, 0.5), m["mid"])
				b.sphere(Vector3(dock.x + c.x, py + 0.24, dock.z + c.y), 0.07, m["green"])
	# Cargo door frame and hazard stripes at the stern.
	var z := RAMP_HINGE.z + 0.06
	b.box(Vector3(0, DOOR_H + 0.32, z), Vector3(DOOR_HALF_W * 2.0 + 0.3, 0.16, 0.12), m["accent"])
	for side: float in [-1.0, 1.0]:
		b.sphere(Vector3(side * (DOOR_HALF_W - 0.15), DOOR_H + 0.5, z - 0.01), 0.07, m["amber"])
		b.box(Vector3(side * (DOOR_HALF_W + 0.16), DOOR_H * 0.5, z), Vector3(0.22, DOOR_H + 0.2, 0.1), m["black"])
		for i in 5:
			b.box(Vector3(side * (DOOR_HALF_W + 0.16), 0.35 + i * 0.6, z + 0.01), Vector3(0.24, 0.2, 0.1), m["hazard"], Vector3(0, 0, 40.0 * side))
	# Landing gear bays under the legs.
	for lp: Vector3 in t["legs"]:
		var by := bottom_y(sections, lp.z)
		var dir := 1.0 if lp.z < 0.0 else -1.0
		b.box(Vector3(lp.x, by - 0.01, lp.z + dir * 1.15), Vector3(1.1, 0.04, 3.0), m["black"])
	# Tractor field emitter.
	var col: Vector3 = t["collector"]
	var cy := bottom_y(sections, col.z)
	b.cyl(Vector3(col.x, cy - 0.06, col.z), 1.1, 0.12, m["dark"], Vector3.ZERO, -1.0, 20)
	b.cyl(Vector3(col.x, cy - 0.12, col.z), 0.75, 0.04, m["cyan"], Vector3.ZERO, -1.0, 20)


## Hull seam: a thin band around the hull at depth z.
static func _seam(b: Models.Batch, t: Dictionary, z: float, mat: Material, width := 0.1, grow := 1.012) -> void:
	var s := section_at(t["sections"], z)
	var band := [[z - width * 0.5, s.x * grow, s.y * grow, s.z], [z + width * 0.5, s.x * grow, s.y * grow, s.z]]
	b.add(Models.loft(band, float(t["chamfer"]), true), Transform3D.IDENTITY, mat)


## Small attitude thruster block with nozzles pointing along `dirs`.
static func _rcs(b: Models.Batch, pos: Vector3, dirs: Array, m: Dictionary) -> void:
	b.box(pos, Vector3(0.6, 0.42, 0.6), m["mid"])
	b.box(pos + Vector3(0, 0.22, 0), Vector3(0.5, 0.04, 0.5), m["dark"])
	for d: Vector3 in dirs:
		var rot := Vector3.ZERO
		if absf(d.x) > 0.5:
			rot = Vector3(0, 0, 90)
		elif absf(d.z) > 0.5:
			rot = Vector3(90, 0, 0)
		b.cyl(pos + d * 0.36, 0.09, 0.16, m["black"], rot, 0.13, 8)


## Row of vent slats on a surface facing `normal`: `count` slats `slat_len` long, spaced along `along`.
static func _vents(b: Models.Batch, center: Vector3, normal: Vector3, along: Vector3, count: int, slat_len: float, m: Dictionary) -> void:
	var across := normal.cross(along).abs()
	b.box(center, normal.abs() * 0.04 + along.abs() * (count * 0.18 + 0.08) + across * (slat_len + 0.1), m["black"])
	for i in count:
		var off := (i - (count - 1) * 0.5) * 0.18
		b.box(center + normal * 0.03 + along * off, normal.abs() * 0.05 + along.abs() * 0.07 + across * slat_len, m["mid"])


## A detailed engine nacelle pointing backwards (+Z): intake ring, cooling fins, nozzle and glow.
static func _engine(root: Node3D, b: Models.Batch, pos: Vector3, r: float, length: float, m: Dictionary,
		glow: Material) -> void:
	b.cyl(pos, r, length, m["mid"], Vector3(90, 0, 0), r * 0.87, 20)
	b.cyl(pos + Vector3(0, 0, -length * 0.5 - 0.08), r * 1.06, 0.22, m["dark"], Vector3(90, 0, 0), -1.0, 20)
	b.cyl(pos + Vector3(0, 0, -length * 0.5 - 0.2), r * 0.7, 0.06, m["black"], Vector3(90, 0, 0), -1.0, 20)
	for i in 3:
		b.cyl(pos + Vector3(0, 0, -length * 0.25 + i * length * 0.25), r * 1.025, 0.08, m["steel"], Vector3(90, 0, 0), -1.0, 20)
	for i in 8:
		var a := TAU * i / 8.0 + PI / 8.0
		b.box(pos + Vector3(cos(a) * r * 0.98, sin(a) * r * 0.98, length * 0.1), Vector3(0.08, r * 0.28, length * 0.55), m["dark"],
				Vector3(0, 0, rad_to_deg(a) - 90.0))
	var tail := pos + Vector3(0, 0, length * 0.5)
	b.cyl(tail + Vector3(0, 0, 0.18), r * 0.84, 0.36, m["dark"], Vector3(90, 0, 0), r * 0.72, 20)
	b.cyl(tail + Vector3(0, 0, 0.3), r * 0.66, 0.12, m["black"], Vector3(90, 0, 0), -1.0, 20)
	b.cyl(tail + Vector3(0, 0, 0.12), r * 0.3, 0.5, m["steel"], Vector3(90, 0, 0), r * 0.08, 12)
	var g := Models.cylinder(root, tail + Vector3(0, 0, 0.37), r * 0.6, 0.04, glow, Vector3(90, 0, 0), r * 0.6, 20)
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Antenna mast with a blinking tip light.
static func _antenna(root: Node3D, b: Models.Batch, base: Vector3, height: float, m: Dictionary, color := Color(1, 0.2, 0.2)) -> void:
	b.cyl(base + Vector3(0, 0.08, 0), 0.16, 0.16, m["dark"])
	b.cyl(base + Vector3(0, height * 0.5, 0), 0.045, height, m["steel"], Vector3.ZERO, 0.025, 6)
	for i in 2:
		b.box(base + Vector3(0, height * (0.45 + i * 0.25), 0), Vector3(0.5 - i * 0.15, 0.03, 0.03), m["steel"])
	Models.sphere(root, base + Vector3(0, height + 0.06, 0), 0.08, Models.blink(color, 0.9, base.x * 0.13, 0.25))


## Sensor dish on a short pylon, facing `facing`.
static func _dish(b: Models.Batch, pos: Vector3, radius: float, tilt_deg: Vector3, m: Dictionary) -> void:
	b.cyl(pos + Vector3(0, -0.35, 0), 0.12, 0.5, m["dark"])
	var rot := tilt_deg
	b.cyl(pos, radius * 0.25, 0.18, m["steel"], rot, radius, 16)
	b.cyl(pos + Models.euler(rot) * Vector3(0, 0.22, 0), 0.05, 0.4, m["dark"], rot)


## Lit porthole windows along a side of the hull.
static func _portholes(b: Models.Batch, x: float, y: float, z0: float, z1: float, n: int, m: Dictionary) -> void:
	for i in n:
		var z := lerpf(z0, z1, float(i) / maxf(n - 1, 1))
		b.box(Vector3(x, y, z), Vector3(0.05, 0.32, 0.42), m["dark"])
		b.box(Vector3(x + signf(x) * 0.01, y, z), Vector3(0.04, 0.22, 0.3), m["window"])


static func _name_labels(root: Node3D, t: Dictionary) -> void:
	var sections: Array = t["sections"]
	var id := str(t["id"])
	var z := 4.5
	var y := 1.9
	var size := 140
	var color := Color(0.15, 0.17, 0.2)
	match id:
		"vanguard":
			z = 3.5
		"excavator":
			z = -4.4
			y = 2.3
			size = 110
			color = Color(0.1, 0.1, 0.1)
		"dreadnought":
			z = 1.8
			y = 1.9
			size = 90
			color = Color(0.95, 0.72, 0.25)
	var x := side_x(sections, z) + 0.03
	if id == "dreadnought":
		x = 9.23  # On the armour belt.
	for side: float in [-1.0, 1.0]:
		var lbl := Label3D.new()
		lbl.text = str(t["name"]).to_upper()
		lbl.font_size = size
		lbl.pixel_size = 0.008
		lbl.modulate = color
		lbl.outline_size = 0
		lbl.position = Vector3(side * x, y, z)
		lbl.rotation = Vector3(0, side * PI / 2.0, 0)
		root.add_child(lbl)


# --- Ship dressing -----------------------------------------------------------------------------

static func _dress_prospector(root: Node3D, b: Models.Batch, t: Dictionary, m: Dictionary, glow: Material) -> void:
	for z: float in [-9.2, -6.6, -3.0, 1.0, 5.0, 8.6]:
		_seam(b, t, z, m["dark"])
	# Accent stripes and panel bands along the sides.
	for side: float in [-1.0, 1.0]:
		b.box(Vector3(side * 7.42, 3.15, 0.5), Vector3(0.08, 0.32, 12.0), m["accent"])
		b.box(Vector3(side * 7.42, 0.2, 0.5), Vector3(0.08, 0.14, 12.0), m["dark"])
		_portholes(b, side * 7.38, 2.62, 1.6, 6.8, 5, m)
		_vents(b, Vector3(side * 7.0, 1.2, 9.4), Vector3(side, 0, 0), Vector3(0, 0, 1), 6, 0.9, m)
		# Raised plates on the shoulders.
		b.box(Vector3(side * 4.2, 4.77, -1.2), Vector3(1.6, 0.05, 3.0), m["paint"])
		b.box(Vector3(side * 4.4, 4.77, 8.4), Vector3(1.4, 0.05, 2.4), m["paint"])
		# Attitude thrusters at the corners.
		_rcs(b, Vector3(side * 6.7, 4.05, -6.0), [Vector3(side, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, -1)], m)
		_rcs(b, Vector3(side * 6.1, 3.75, 10.0), [Vector3(side, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)], m)
	for z: float in [-4.0, 0.0, 4.0]:
		b.box(Vector3(0, 4.71, z), Vector3(10.0, 0.04, 0.12), m["dark"])
		b.box(Vector3(0, -1.91, z), Vector3(10.0, 0.04, 0.12), m["dark"])
	# Dorsal spine with vents, between the roof hatches.
	b.box(Vector3(0, 4.86, 2.6), Vector3(1.3, 0.24, 6.8), m["mid"])
	for i in 7:
		b.box(Vector3(0, 5.0, -0.4 + i * 1.0), Vector3(1.0, 0.04, 0.12), m["dark"])
	b.sphere(Vector3(0, 5.02, -0.9), 0.09, m["red"])
	# Cockpit canopy with frame struts.
	b.box(Vector3(0, 4.22, -9.8), Vector3(4.0, 0.12, 3.4), m["glass"], Vector3(-17, 0, 0))
	for x: float in [-1.35, 0.0, 1.35]:
		b.box(Vector3(x, 4.3, -9.8), Vector3(0.1, 0.1, 3.5), m["dark"], Vector3(-17, 0, 0))
	b.box(Vector3(0, 4.03, -11.35), Vector3(4.1, 0.14, 0.14), m["dark"], Vector3(-17, 0, 0))
	# Gunnery window frames (no glass, so the crew can see out).
	for side: float in [-1.0, 1.0]:
		for dz: float in [-1.55, 1.55]:
			b.box(Vector3(side * 7.42, 1.8, -2.5 + dz), Vector3(0.06, 1.6, 0.1), m["dark"])
		for dy: float in [-0.75, 0.75]:
			b.box(Vector3(side * 7.42, 1.8 + dy, -2.5), Vector3(0.06, 0.1, 3.2), m["dark"])
	# Side gun sponsons, set behind the turrets so the barrels can swing forward past the bow.
	for id: String in ["gun_l", "gun_r"]:
		var p: Vector3 = t["by_id"][id]["pos"]
		var sx := signf(p.x)
		b.box(Vector3(sx * 7.85, p.y, p.z + 0.8), Vector3(1.5, 1.9, 2.4), m["mid"])
		b.box(Vector3(sx * 7.85, p.y + 0.96, p.z + 0.8), Vector3(1.3, 0.04, 2.0), m["accent"])
		b.box(Vector3(sx * 8.1, p.y - 0.7, p.z + 1.4), Vector3(0.9, 0.4, 1.0), m["dark"])
		for i in 3:
			b.box(Vector3(sx * 8.61, p.y - 0.3 + i * 0.3, p.z + 0.8), Vector3(0.02, 0.08, 1.9), m["dark"])
	# Mining laser housing and the sensor dome under the nose.
	b.box(Vector3(0, 1.45, -13.9), Vector3(1.1, 0.9, 0.5), m["mid"])
	b.box(Vector3(0, 1.95, -13.6), Vector3(0.7, 0.14, 0.9), m["accent"])
	b.sphere(Vector3(0, 0.1, -11.4), 0.45, m["glass"], Vector3(1.0, 0.6, 1.0))
	for side: float in [-1.0, 1.0]:
		b.box(Vector3(side * 1.6, 3.05, -11.9), Vector3(0.12, 0.12, 0.9), m["dark"], Vector3(0, side * 20.0, 0))
	# Engines: housings either side of the cargo door, two nacelles and pylons.
	for side: float in [-1.0, 1.0]:
		b.box(Vector3(side * 2.2, 1.3, 12.3), Vector3(1.4, 3.0, 1.6), m["mid"])
		b.box(Vector3(side * 2.2, 1.3, 13.12), Vector3(1.1, 2.6, 0.06), m["dark"])
		_engine(root, b, Vector3(side * 4.5, 1.1, 12.5), 1.55, 3.6, m, glow)
		b.box(Vector3(side * 6.0, 1.1, 11.0), Vector3(0.6, 0.5, 2.0), m["dark"])
		b.box(Vector3(side * 4.5, 2.75, 11.6), Vector3(0.5, 0.4, 2.2), m["mid"])
	# Antennas, a sensor dish and greebles on the roof.
	_antenna(root, b, Vector3(-2.5, 4.7, 9.0), 1.8, m)
	_antenna(root, b, Vector3(-2.2, 4.7, 9.7), 1.1, m, Color(1.0, 0.95, 0.85))
	_dish(b, Vector3(3.0, 5.55, 8.0), 0.7, Vector3(-35, 30, 0), m)
	b.box(Vector3(3.0, 4.85, 8.0), Vector3(1.6, 0.3, 2.2), m["mid"])
	b.box(Vector3(-3.5, 4.9, -1.0), Vector3(1.2, 0.4, 1.4), m["mid"])
	b.box(Vector3(-3.5, 5.12, -1.0), Vector3(0.9, 0.06, 1.1), m["dark"])
	b.box(Vector3(4.5, 4.85, -4.5), Vector3(0.8, 0.3, 2.4), m["dark"])
	for i in 3:
		b.cyl(Vector3(4.5, 5.05, -5.4 + i * 0.9), 0.22, 0.18, m["steel"])
	b.cyl(Vector3(-1.6, 4.95, 4.4), 0.12, 6.0, m["steel"], Vector3(90, 0, 0))
	b.cyl(Vector3(-1.9, 4.92, 4.4), 0.08, 6.0, m["accent"], Vector3(90, 0, 0))
	# Navigation lights.
	b.sphere(Vector3(-7.45, 3.6, -6.4), 0.14, m["red"])
	b.sphere(Vector3(7.45, 3.6, -6.4), 0.14, m["green"])
	for side: float in [-1.0, 1.0]:
		Models.sphere(root, Vector3(side * 6.4, 3.85, 10.6), 0.1, Models.blink(Color(1, 1, 1), 1.1, 0.5 if side > 0 else 0.0, 0.12))
	# Headlight housing under the nose, clear of the nose-mounted mining laser so the turret
	# doesn't throw a giant shadow down the tunnel.
	b.box(Vector3(0, -0.05, -12.7), Vector3(1.8, 0.4, 1.0), m["mid"])
	for x: float in [-0.45, 0.45]:
		b.cyl(Vector3(x, -0.08, -13.22), 0.16, 0.05, m["white"], Vector3(90, 0, 0))
	# Belly antenna and cargo hatch outlines.
	b.box(Vector3(0, -1.93, -5.5), Vector3(3.4, 0.04, 2.6), m["dark"])
	b.box(Vector3(0, -1.95, -5.5), Vector3(3.0, 0.04, 0.1), m["hazard"])
	b.cyl(Vector3(2.2, -2.3, 9.3), 0.04, 0.8, m["steel"])


static func _dress_vanguard(root: Node3D, b: Models.Batch, t: Dictionary, m: Dictionary, glow: Material) -> void:
	var deck_mat := Models.panel_mat(Color(0.24, 0.26, 0.3), 0.4, 0.6, 0.35)
	var white := Models.mat(Color(0.9, 0.92, 0.95), 0.1, 0.6)
	for z: float in [-10.2, -6.6, -2.0, 2.5, 7.0]:
		_seam(b, t, z, m["dark"])
	# Flight deck: overhangs the sides and runs out past the bow.
	var deck := PackedVector2Array([Vector2(-8.4, 11.2), Vector2(-8.4, -11.5), Vector2(-5.2, -19.4),
		Vector2(5.2, -19.4), Vector2(8.4, -11.5), Vector2(8.4, 11.2)])
	b.add(Models.prism(deck, 4.6, 5.05), Transform3D.IDENTITY, deck_mat)
	# Forecastle under the bow overhang.
	var fore := PackedVector2Array([Vector2(-5.6, -10.0), Vector2(-4.6, -18.9), Vector2(4.6, -18.9), Vector2(5.6, -10.0)])
	b.add(Models.prism(fore, 2.9, 4.6), Transform3D.IDENTITY, m["hull"])
	b.box(Vector3(0, 3.6, -18.95), Vector3(9.0, 1.2, 0.1), m["dark"])
	for x: float in [-3.0, -1.0, 1.0, 3.0]:
		b.box(Vector3(x, 3.6, -19.0), Vector3(1.4, 0.5, 0.06), m["window"])
	# Deck markings: centre line, edge lines, scout spots and bow hazard chevrons.
	for i in 14:
		b.box(Vector3(0, 5.06, -17.0 + i * 2.0), Vector3(0.22, 0.02, 1.1), white)
	for side: float in [-1.0, 1.0]:
		b.box(Vector3(side * 7.7, 5.06, -0.2), Vector3(0.14, 0.02, 22.6), m["hazard"])
		for i in 8:
			var z := -10.0 + i * 3.0
			b.box(Vector3(side * 8.32, 5.07, z), Vector3(0.14, 0.05, 0.3), Models.blink(Color(0.35, 0.7, 1.0), 0.8, i * 0.11, 0.35))
		# Support struts under the deck overhang.
		for i in 6:
			var z := -8.0 + i * 3.6
			var hx := side_x(t["sections"], z)
			b.strut(Vector3(side * (hx - 0.2), 2.6, z), Vector3(side * 8.1, 4.55, z), 0.12, m["dark"])
		for i in 6:
			b.box(Vector3(side * (3.0 + i * 0.35), 5.07, -18.4), Vector3(0.18, 0.02, 1.2), m["hazard"], Vector3(0, side * 35.0, 0))
	# The island: tower, bridge, mast and radar on the starboard edge.
	b.box(Vector3(7.1, 6.25, 4.5), Vector3(2.2, 2.4, 8.0), m["hull"])
	b.box(Vector3(7.0, 8.0, 3.8), Vector3(1.9, 1.1, 4.4), m["mid"])
	b.box(Vector3(7.0, 8.05, 1.58), Vector3(1.7, 0.42, 0.04), m["window"])
	for side: float in [-1.0, 1.0]:
		b.box(Vector3(7.0 + side * 0.96, 8.05, 3.8), Vector3(0.04, 0.42, 3.8), m["window"])
	b.box(Vector3(7.1, 7.48, 4.5), Vector3(2.25, 0.08, 8.05), m["accent"])
	for i in 4:
		b.box(Vector3(5.98, 6.25, 1.6 + i * 1.9), Vector3(0.04, 0.5, 0.7), m["window"])
	_antenna(root, b, Vector3(7.1, 8.55, 5.6), 0.35, m)
	_dish(b, Vector3(7.0, 8.95, 6.5), 0.45, Vector3(-30, -40, 0), m)
	b.box(Vector3(7.1, 8.62, 2.6), Vector3(0.8, 0.08, 0.8), m["dark"])
	# Bow gun barbette at the front edge of the deck.
	var gun: Vector3 = t["by_id"]["gun_f"]["pos"]
	b.cyl(Vector3(gun.x, 5.45, gun.z), 1.05, 0.8, m["mid"], Vector3.ZERO, 0.95, 20)
	b.cyl(Vector3(gun.x, 5.86, gun.z), 0.98, 0.05, m["accent"], Vector3.ZERO, -1.0, 20)
	# Mining laser housing under the bow.
	b.box(Vector3(0, 1.2, -15.6), Vector3(1.2, 1.0, 0.7), m["mid"])
	# Hull details below the deck.
	for side: float in [-1.0, 1.0]:
		b.box(Vector3(side * 7.12, 3.0, 0.5), Vector3(0.08, 0.3, 12.0), m["accent"])
		b.box(Vector3(side * 7.12, 0.2, 0.5), Vector3(0.08, 0.14, 12.0), m["dark"])
		_portholes(b, side * 7.1, 2.3, -4.6, 6.4, 6, m)
		_vents(b, Vector3(side * 6.75, 1.2, 9.4), Vector3(side, 0, 0), Vector3(0, 0, 1), 6, 0.9, m)
		for dz: float in [-1.55, 1.55]:
			b.box(Vector3(side * 7.12, 1.8, -2.5 + dz), Vector3(0.06, 1.6, 0.1), m["dark"])
		for dy: float in [-0.75, 0.75]:
			b.box(Vector3(side * 7.12, 1.8 + dy, -2.5), Vector3(0.06, 0.1, 3.2), m["dark"])
		_rcs(b, Vector3(side * 6.4, 1.0, -7.4), [Vector3(side, 0, 0), Vector3(0, -1, 0), Vector3(0, 0, -1)], m)
	# Engines: two nacelles plus two small ones under the deck's rear corners.
	for side: float in [-1.0, 1.0]:
		b.box(Vector3(side * 2.2, 1.3, 12.3), Vector3(1.4, 3.0, 1.6), m["mid"])
		_engine(root, b, Vector3(side * 4.5, 1.1, 12.5), 1.55, 3.6, m, glow)
		_engine(root, b, Vector3(side * 7.0, 3.75, 11.9), 0.75, 2.0, m, glow)
		b.box(Vector3(side * 6.0, 1.1, 11.0), Vector3(0.6, 0.5, 2.0), m["dark"])
	b.sphere(Vector3(-8.45, 4.82, -11.4), 0.14, m["red"])
	b.sphere(Vector3(8.45, 4.82, -11.4), 0.14, m["green"])
	# Headlight housing under the nose.
	b.box(Vector3(0, -0.1, -14.4), Vector3(1.8, 0.4, 1.0), m["mid"])
	for x: float in [-0.45, 0.45]:
		b.cyl(Vector3(x, -0.13, -14.92), 0.16, 0.05, m["white"], Vector3(90, 0, 0))
	# Deck lettering for the scout spots.
	for sid: String in ["scout", "scout2"]:
		var dock: Vector3 = t["by_id"][sid]["dock"]
		var lbl := Label3D.new()
		lbl.text = "A" if sid == "scout" else "B"
		lbl.font_size = 220
		lbl.pixel_size = 0.01
		lbl.modulate = Color(0.95, 0.95, 1.0, 0.85)
		lbl.outline_size = 0
		lbl.position = Vector3(dock.x, 5.08, dock.z + 3.4)
		lbl.rotation = Vector3(-PI / 2.0, 0, 0)
		root.add_child(lbl)


static func _dress_excavator(root: Node3D, b: Models.Batch, t: Dictionary, m: Dictionary, glow: Material) -> void:
	var sec: Array = t["sections"]
	for z: float in [-9.2, -6.6, -2.4, 2.0, 6.0, 9.4]:
		_seam(b, t, z, m["dark"], 0.12)
	# Hazard stripes across the brow of the nose.
	for i in 11:
		var x := -4.0 + i * 0.8
		b.box(Vector3(x, top_y(sec, -11.0) + 0.03, -11.0), Vector3(0.36, 0.05, 1.6), m["black"], Vector3(0, 40, 0))
	# Mining arms: shoulder pivots, booms, pistons and the laser heads (turrets) at their tips.
	for side: float in [-1.0, 1.0]:
		var shoulder := Vector3(side * 5.5, 0.3, -6.9)
		var tip := Vector3(side * 3.8, 0.15, -15.7)
		b.cyl(shoulder, 0.9, 1.4, m["dark"], Vector3(0, 0, 90), -1.0, 16)
		b.cyl(shoulder, 0.55, 1.5, m["steel"], Vector3(0, 0, 90), -1.0, 12)
		b.beam(shoulder, tip, 1.2, 1.3, m["paint"])
		b.beam(shoulder + Vector3(0, 0.66, 0), tip + Vector3(0, 0.66, 0), 0.9, 0.06, m["black"])
		b.strut(shoulder + Vector3(side * -0.6, 0.9, 1.0), tip + Vector3(side * -0.4, 0.75, 4.5), 0.13, m["steel"])
		b.strut(shoulder + Vector3(side * -0.6, -0.7, 1.0), tip + Vector3(side * -0.4, -0.5, 4.5), 0.13, m["steel"])
		b.box(tip + Vector3(0, 0, 0.35), Vector3(1.5, 1.5, 0.9), m["dark"])
		for i in 4:
			b.box(shoulder.lerp(tip, 0.2 + i * 0.18) + Vector3(side * 0.62, 0, 0), Vector3(0.05, 0.9, 0.5), m["hazard"])
		b.cyl(shoulder.lerp(tip, 0.5) + Vector3(0, -0.72, 0), 0.08, 9.0, m["black"], Vector3(90, 0, 0))
	# Ore hoppers along the sides with ribs and a chute.
	for side: float in [-1.0, 1.0]:
		b.box(Vector3(side * 8.05, 1.9, 2.5), Vector3(1.1, 3.4, 11.0), m["paint"])
		b.box(Vector3(side * 8.05, 3.66, 2.5), Vector3(1.2, 0.12, 11.1), m["black"])
		for i in 6:
			b.box(Vector3(side * 8.62, 1.9, -2.5 + i * 2.0), Vector3(0.08, 3.4, 0.25), m["dark"])
		for i in 10:
			b.box(Vector3(side * 8.63, 3.35, -2.6 + i * 1.12), Vector3(0.06, 0.28, 0.5), m["black"], Vector3(40, 0, 0))
		b.box(Vector3(side * 8.0, -0.15, -3.4), Vector3(0.8, 0.8, 1.0), m["dark"], Vector3(30, 0, 0))
		_vents(b, Vector3(side * 7.15, 0.6, 9.6), Vector3(side, 0, 0), Vector3(0, 0, 1), 5, 0.8, m)
		_rcs(b, Vector3(side * 6.6, 4.4, 10.2), [Vector3(side, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)], m)
	# Tractor funnel under the belly.
	var col: Vector3 = t["collector"]
	var by := bottom_y(sec, col.z)
	b.cyl(Vector3(col.x, by - 0.55, col.z), 0.9, 1.1, m["dark"], Vector3.ZERO, 1.7, 20)
	b.cyl(Vector3(col.x, by - 1.12, col.z), 0.95, 0.08, m["cyan"], Vector3.ZERO, -1.0, 20)
	for i in 6:
		var a := TAU * i / 6.0
		b.box(Vector3(col.x + cos(a) * 1.25, by - 0.5, col.z + sin(a) * 1.25), Vector3(0.12, 1.0, 0.3), m["hazard"], Vector3(0, -rad_to_deg(a), 22))
	# Forward gun barbette on the front-starboard corner.
	var gun: Vector3 = t["by_id"]["gun_f"]["pos"]
	b.cyl(Vector3(gun.x, 5.05, gun.z), 0.95, 0.5, m["dark"], Vector3.ZERO, 0.85, 20)
	b.cyl(Vector3(gun.x, 5.3, gun.z), 0.86, 0.05, m["hazard"], Vector3.ZERO, -1.0, 20)
	# Crane at the stern, exhaust stacks and floodlight bars.
	b.cyl(Vector3(-4.3, 5.9, 8.4), 0.3, 2.1, m["dark"])
	b.beam(Vector3(-4.3, 6.9, 8.4), Vector3(-1.4, 7.3, 4.8), 0.35, 0.35, m["hazard"])
	b.strut(Vector3(-1.4, 7.3, 4.8), Vector3(-1.4, 6.0, 4.8), 0.03, m["black"])
	b.box(Vector3(-1.4, 5.92, 4.8), Vector3(0.4, 0.2, 0.3), m["dark"])
	for x: float in [-2.6, 2.6]:
		b.cyl(Vector3(x, 5.5, 10.3), 0.32, 1.3, m["dark"])
		b.cyl(Vector3(x, 6.2, 10.3), 0.36, 0.12, m["black"])
	for side: float in [-1.0, 1.0]:
		b.box(Vector3(side * 3.3, 5.1, -9.0), Vector3(1.6, 0.25, 0.25), m["dark"])
		for i in 3:
			b.box(Vector3(side * 3.3 + (i - 1) * 0.5, 5.1, -9.14), Vector3(0.35, 0.16, 0.04), m["white"])
	_antenna(root, b, Vector3(2.6, 4.87, 8.6), 1.5, m, Color(1.0, 0.65, 0.1))
	_dish(b, Vector3(-3.6, 5.5, -1.0), 0.55, Vector3(-30, -30, 0), m)
	# Cockpit glazing and the hull number on the brow.
	b.box(Vector3(0, top_y(sec, -9.9) + 0.02, -9.9), Vector3(3.6, 0.1, 2.4), m["glass"], Vector3(-10, 0, 0))
	for x: float in [-0.9, 0.9]:
		b.box(Vector3(x, top_y(sec, -9.9) + 0.06, -9.9), Vector3(0.12, 0.08, 2.5), m["black"], Vector3(-10, 0, 0))
	# Engines.
	for side: float in [-1.0, 1.0]:
		b.box(Vector3(side * 2.2, 1.3, 12.3), Vector3(1.4, 3.0, 1.6), m["dark"])
		_engine(root, b, Vector3(side * 4.6, 1.1, 12.5), 1.55, 3.6, m, glow)
		b.box(Vector3(side * 4.6, 2.85, 11.4), Vector3(1.6, 0.5, 2.6), m["paint"])
	b.sphere(Vector3(-7.55, 3.8, -6.2), 0.14, m["red"])
	b.sphere(Vector3(7.55, 3.8, -6.2), 0.14, m["green"])
	for side: float in [-1.0, 1.0]:
		Models.sphere(root, Vector3(side * 8.1, 3.85, 8.0), 0.12, Models.blink(Color(1.0, 0.6, 0.1), 1.3, 0.5 if side > 0 else 0.0, 0.3))
	# Headlight housing under the nose.
	b.box(Vector3(0, -0.72, -12.4), Vector3(1.8, 0.4, 1.0), m["dark"])
	for x: float in [-0.45, 0.45]:
		b.cyl(Vector3(x, -0.75, -12.92), 0.16, 0.05, m["white"], Vector3(90, 0, 0))


static func _dress_dreadnought(root: Node3D, b: Models.Batch, t: Dictionary, m: Dictionary, glow: Material) -> void:
	var sec: Array = t["sections"]
	var armor := Models.panel_mat(Color(0.2, 0.21, 0.24), 0.65, 0.42, 0.5)
	var gold := Models.mat(Color(0.95, 0.68, 0.2), 0.7, 0.35)
	for z: float in [-11.4, -8.0, -4.0, 0.0, 4.0, 8.0]:
		_seam(b, t, z, m["black"], 0.14)
	# Armour belts along the sides (with gaps for the gun sponsons) and bolt rows.
	for side: float in [-1.0, 1.0]:
		for seg: Vector2 in [Vector2(-6.6, -4.2), Vector2(-0.8, 4.4), Vector2(4.8, 7.4)]:
			var zc := (seg.x + seg.y) * 0.5
			var ln := seg.y - seg.x
			b.box(Vector3(side * 9.05, 1.3, zc), Vector3(0.3, 4.0, ln), armor)
			b.box(Vector3(side * 9.21, 3.15, zc), Vector3(0.06, 0.18, ln - 0.3), gold)
			for i in int(ln / 0.8):
				b.cyl(Vector3(side * 9.21, -0.5, seg.x + 0.4 + i * 0.8), 0.07, 0.06, m["steel"], Vector3(0, 0, 90), -1.0, 6)
		b.box(Vector3(side * 8.92, -1.2, 0.5), Vector3(0.1, 0.18, 14.0), gold)
		_vents(b, Vector3(side * 8.55, 2.0, 9.6), Vector3(side, 0, 0), Vector3(0, 0, 1), 6, 1.2, m)
	# Heavy sponsons for the side guns.
	for id: String in ["gun_l", "gun_r"]:
		var p: Vector3 = t["by_id"][id]["pos"]
		var sx := signf(p.x)
		b.box(Vector3(sx * 9.6, p.y, p.z + 1.0), Vector3(2.0, 2.8, 3.4), armor)
		b.box(Vector3(sx * 9.6, p.y + 1.42, p.z + 1.0), Vector3(1.8, 0.05, 3.0), gold)
		b.box(Vector3(sx * 9.6, p.y - 1.1, p.z + 1.0), Vector3(2.1, 0.5, 3.5), m["black"])
		for i in 4:
			b.box(Vector3(sx * 10.61, p.y - 0.9 + i * 0.6, p.z + 1.0), Vector3(0.04, 0.12, 3.0), m["dark"])
	# Gunnery window frames.
	for side: float in [-1.0, 1.0]:
		for dz: float in [-1.55, 1.55]:
			b.box(Vector3(side * 8.92, 1.8, -2.5 + dz), Vector3(0.06, 1.6, 0.1), m["black"])
	# Top armour, missile pods and the command tower (front-port) with its bridge windows.
	for side: float in [-1.0, 1.0]:
		b.box(Vector3(side * 3.6, 5.46, 0.5), Vector3(4.0, 0.1, 12.5), armor)
		for i in 2:
			var pc := Vector3(side * 5.3, 5.85, 3.2 + i * 2.6)
			b.box(pc, Vector3(1.6, 0.8, 2.0), armor)
			for gx in 2:
				for gz in 2:
					b.cyl(pc + Vector3(-0.38 + gx * 0.76, 0.41, -0.45 + gz * 0.9), 0.26, 0.04, m["black"], Vector3.ZERO, -1.0, 10)
	b.box(Vector3(-3.4, 5.9, -9.6), Vector3(2.8, 2.0, 3.2), armor)
	b.box(Vector3(-3.4, 6.3, -11.22), Vector3(2.5, 0.42, 0.06), m["window"])
	for side: float in [-1.0, 1.0]:
		b.box(Vector3(-3.4 + side * 1.42, 6.3, -9.6), Vector3(0.04, 0.42, 2.8), m["window"])
	b.box(Vector3(-3.4, 6.95, -9.6), Vector3(3.0, 0.12, 3.4), m["paint"])
	_antenna(root, b, Vector3(-3.4, 7.0, -8.8), 1.2, m)
	_dish(b, Vector3(-2.6, 7.5, -10.3), 0.45, Vector3(-25, 20, 0), m)
	# Forward gun barbette on the front-starboard corner.
	var gun: Vector3 = t["by_id"]["gun_f"]["pos"]
	b.cyl(Vector3(gun.x, 4.6, gun.z), 1.45, 2.4, armor, Vector3.ZERO, 1.3, 20)
	b.cyl(Vector3(gun.x, 5.82, gun.z), 1.32, 0.06, gold, Vector3.ZERO, -1.0, 20)
	# The bow: a ram under the nose and two horn antennas.
	var ram := PackedVector2Array([Vector2(-2.2, -13.6), Vector2(0, -19.2), Vector2(2.2, -13.6)])
	b.add(Models.prism(ram, -0.6, 1.3), Transform3D.IDENTITY, armor)
	b.add(Models.prism(PackedVector2Array([Vector2(-1.0, -16.2), Vector2(0, -19.1), Vector2(1.0, -16.2)]), 1.3, 1.36), Transform3D.IDENTITY, gold)
	for side: float in [-1.0, 1.0]:
		b.strut(Vector3(side * 1.4, top_y(sec, -14.0) - 0.1, -14.0), Vector3(side * 2.4, top_y(sec, -14.0) + 1.3, -15.6), 0.07, m["steel"])
		b.sphere(Vector3(side * 2.4, top_y(sec, -14.0) + 1.34, -15.6), 0.09, m["red"])
	b.box(Vector3(0, 2.3, -17.1), Vector3(1.2, 1.0, 0.6), armor)
	# Engines: two big lower nacelles, two upper ones and a central exhaust above the door.
	for side: float in [-1.0, 1.0]:
		b.box(Vector3(side * 2.3, 1.4, 12.2), Vector3(1.6, 3.4, 1.4), armor)
		_engine(root, b, Vector3(side * 4.9, 0.4, 13.0), 1.9, 4.0, m, glow)
		_engine(root, b, Vector3(side * 7.2, 3.8, 12.3), 1.2, 3.0, m, glow)
		b.box(Vector3(side * 6.2, 2.1, 11.6), Vector3(1.4, 1.2, 2.4), armor)
		_rcs(b, Vector3(side * 7.6, 4.9, -7.0), [Vector3(side, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, -1)], m)
	_engine(root, b, Vector3(0, 4.55, 12.2), 0.9, 2.4, m, glow)
	b.sphere(Vector3(-9.25, 4.2, -6.2), 0.16, m["red"])
	b.sphere(Vector3(9.25, 4.2, -6.2), 0.16, m["green"])
	for side: float in [-1.0, 1.0]:
		Models.sphere(root, Vector3(side * 8.3, 5.3, 10.6), 0.12, Models.blink(Color(1, 1, 1), 1.0, 0.5 if side > 0 else 0.0, 0.12))
	# Headlights either side of the ram.
	for side: float in [-1.0, 1.0]:
		b.box(Vector3(side * 2.6, -0.4, -14.4), Vector3(1.2, 0.5, 1.0), m["dark"])
		b.cyl(Vector3(side * 2.6, -0.42, -14.92), 0.2, 0.05, m["white"], Vector3(90, 0, 0))


## Exterior lights: headlights, side floods and the belly and work lights. The headlight is set
## clear of the nose turret so it doesn't throw a giant shadow down the tunnel.
static func _lights(root: Node3D, t: Dictionary, _m: Dictionary) -> Array[Light3D]:
	var sec: Array = t["sections"]
	var nose := float((sec[0] as Array)[0])
	var lights: Array[Light3D] = []
	var heads: Array[Vector3] = []
	match str(t["id"]):
		"dreadnought":
			heads = [Vector3(0, -0.45, -15.0)]
		"vanguard":
			heads = [Vector3(0, -0.15, -14.95)]
		"excavator":
			heads = [Vector3(0, -0.77, -12.95)]
		_:
			heads = [Vector3(0, -0.1, nose + 0.45)]
	for hp in heads:
		var head := SpotLight3D.new()
		head.position = hp
		head.rotation_degrees = Vector3(-4, 0, 0)
		head.spot_range = 95.0
		head.spot_angle = 34.0
		head.spot_attenuation = 0.6
		head.light_energy = 7.0
		head.light_color = Color(1.0, 0.95, 0.86)
		configure_shadow(head)
		root.add_child(head)
		lights.append(head)
	for side: float in [-1.0, 1.0]:
		var flood := SpotLight3D.new()
		flood.position = Vector3(side * (side_x(sec, -7.0) - 0.5), top_y(sec, -7.0) - 0.9, -7.0)
		flood.rotation_degrees = Vector3(-14, side * -24.0, 0)
		flood.spot_range = 70.0
		flood.spot_angle = 48.0
		flood.light_energy = 3.0
		flood.light_color = Color(0.85, 0.92, 1.0)
		root.add_child(flood)
		lights.append(flood)
	var belly := OmniLight3D.new()
	belly.position = Vector3(0, bottom_y(sec, -1.0) - 1.1, -1.0)
	belly.omni_range = 34.0
	belly.light_energy = 0.9
	belly.light_color = Color(0.8, 0.88, 1.0)
	root.add_child(belly)
	lights.append(belly)
	# Work lights above the hull so the ship reads clearly from the chase and scout cameras.
	for z: float in [-6.0, 7.0]:
		var top := OmniLight3D.new()
		top.position = Vector3(0, float(t["roof"]) + 4.3, z)
		top.omni_range = 18.0
		top.light_energy = 0.7
		top.light_color = Color(1.0, 0.95, 0.88)
		root.add_child(top)
		lights.append(top)
	return lights


## Landing legs, folded flat against the belly in flight.
static func _legs(root: Node3D, t: Dictionary, m: Dictionary) -> Array:
	var ln := float(t["leg_length"])
	var legs: Array = []
	for lp: Vector3 in t["legs"]:
		var pivot := Node3D.new()
		pivot.position = lp
		root.add_child(pivot)
		Models.box(pivot, Vector3(0, 0.08, 0), Vector3(0.75, 0.32, 0.75), m["dark"])
		Models.cylinder(pivot, Vector3(0, -ln * 0.3, 0), 0.24, ln * 0.6, m["mid"])
		Models.cylinder(pivot, Vector3(0, -ln * 0.74, 0), 0.16, ln * 0.44, m["dark"])
		Models.cylinder(pivot, Vector3(0, -ln * 0.56, 0), 0.27, 0.12, m["steel"])
		Models.cylinder(pivot, Vector3(0, -ln + 0.08, 0), 0.55, 0.16, m["dark"], Vector3.ZERO, 0.42)
		Models.strut(pivot, Vector3(0, -0.1, 0.45 * signf(-lp.z)), Vector3(0, -ln * 0.44, 0.0), 0.06, m["accent"])
		legs.append({"node": pivot, "fold": 1.0 if lp.z < 0.0 else -1.0})
	return legs


## Auto turret hardpoints. "root" (the mount) shows once the slot is unlocked, "head" (the gun)
## once a turret is installed in it.
static func _hardpoints(root: Node3D, t: Dictionary, m: Dictionary) -> Array:
	var guns: Array = []
	for hp: Dictionary in t["hardpoints"]:
		var base := Node3D.new()
		base.position = hp["pos"]
		base.rotation = hp["rot"]
		root.add_child(base)
		Models.cylinder(base, Vector3(0, 0.12, 0), 0.55, 0.24, m["dark"], Vector3.ZERO, 0.45)
		Models.cylinder(base, Vector3(0, 0.245, 0), 0.38, 0.02, m["accent"], Vector3.ZERO, -1.0, 16)
		var swivel := Node3D.new()
		swivel.position = Vector3(0, 0.5, 0)
		base.add_child(swivel)
		Models.box(swivel, Vector3(0, 0, 0.1), Vector3(0.78, 0.44, 0.85), m["mid"])
		Models.box(swivel, Vector3(0, 0.23, 0.1), Vector3(0.5, 0.05, 0.55), m["accent"])
		Models.box(swivel, Vector3(0, -0.05, 0.6), Vector3(0.6, 0.3, 0.2), m["dark"])
		var pitch := Node3D.new()
		swivel.add_child(pitch)
		for dx: float in [-0.17, 0.17]:
			Models.cylinder(pitch, Vector3(dx, 0, -0.78), 0.075, 1.15, m["dark"], Vector3(90, 0, 0))
			Models.cylinder(pitch, Vector3(dx, 0, -1.28), 0.1, 0.16, m["steel"], Vector3(90, 0, 0))
		base.visible = false
		swivel.visible = false
		guns.append({"root": base, "head": swivel, "pitch": pitch})
	return guns


## Rear end cap of the hull with the cargo door cut out of it.
static func _rear_cap(root: Node3D, sections: Array, chamfer: float, material: Material) -> void:
	var ring := Models.octagon(sections[sections.size() - 1], chamfer)
	var z := ring[0].z
	var outline := PackedVector2Array()
	for p in ring:
		outline.append(Vector2(p.x, p.y))
	var hw := DOOR_HALF_W
	var y0 := -0.05
	var y1 := DOOR_H + 0.15
	var big := 50.0
	var pieces := [
		PackedVector2Array([Vector2(-big, -big), Vector2(-hw, -big), Vector2(-hw, big), Vector2(-big, big)]),
		PackedVector2Array([Vector2(hw, -big), Vector2(big, -big), Vector2(big, big), Vector2(hw, big)]),
		PackedVector2Array([Vector2(-hw, y1), Vector2(hw, y1), Vector2(hw, big), Vector2(-hw, big)]),
		PackedVector2Array([Vector2(-hw, -big), Vector2(hw, -big), Vector2(hw, y0), Vector2(-hw, y0)]),
	]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var inside := Vector3(0, 1.4, z - 1.0)
	for clip: PackedVector2Array in pieces:
		for poly: PackedVector2Array in Geometry2D.intersect_polygons(outline, clip):
			for i in range(1, poly.size() - 1):
				Models.tri(st, Vector3(poly[0].x, poly[0].y, z), Vector3(poly[i].x, poly[i].y, z),
						Vector3(poly[i + 1].x, poly[i + 1].y, z), inside)
	var mi := MeshInstance3D.new()
	mi.name = "RearCap"
	mi.mesh = st.commit()
	mi.material_override = material
	root.add_child(mi)


## Shadow settings for the long-range spot lights that light the cave. The cave and every model
## are closed meshes, so rendering back faces into the shadow map (reverse cull) removes
## self-shadowing acne on lit surfaces; the biases mop up the stair-stepped rock.
static func configure_shadow(light: Light3D) -> void:
	light.shadow_enabled = true
	light.shadow_reverse_cull_face = true
	light.shadow_bias = 0.12
	light.shadow_normal_bias = 2.0
	light.shadow_blur = 1.5


# --- Interior ----------------------------------------------------------------------------------

## Build the walkable interior under `root` for a ship type: collision, visuals, the consoles of
## its stations, lights and the interaction areas for stations and repair panels.
static func build_interior(root: Node3D, type_id: String) -> Dictionary:
	var layout := ShipTypes.get_type(type_id)
	var parts := {}
	var body := StaticBody3D.new()
	body.name = "InteriorBody"
	body.collision_layer = Game.LAYER_INTERIOR
	body.collision_mask = 0
	root.add_child(body)
	parts["body"] = body

	var floor_mat := Models.panel_mat(Color(0.26, 0.28, 0.31), 0.5, 0.6, 0.6)
	var wall_mat := Models.panel_mat(Color(0.66, 0.68, 0.7), 0.25, 0.55, 0.45)
	var ceil_mat := Models.panel_mat(Color(0.3, 0.32, 0.35), 0.3, 0.6, 0.5)
	var trim := Models.mat(layout["trim"], 0.3, 0.5)
	var dark := Models.mat(Color(0.12, 0.13, 0.15), 0.5, 0.5)
	var glass := Models.glass(Color(0.55, 0.75, 0.95, 0.12))

	# Floors and ceilings.
	_solid(root, body, Vector3(0, -0.15, 2.0), Vector3(12.5, 0.3, 16.5), floor_mat)
	_solid(root, body, Vector3(0, -0.15, -8.25), Vector3(6.5, 0.3, 4.0), floor_mat)
	_solid(root, body, Vector3(0, 3.35, 2.0), Vector3(12.5, 0.3, 16.5), ceil_mat)
	_solid(root, body, Vector3(0, 3.35, -8.25), Vector3(6.5, 0.3, 4.0), ceil_mat)

	# Outer walls with gunnery windows.
	for side: float in [-1.0, 1.0]:
		var x := side * 6.125
		_solid(root, body, Vector3(x, 1.6, -5.125), Vector3(0.25, 3.2, 2.25), wall_mat)
		_solid(root, body, Vector3(x, 1.6, 4.625), Vector3(0.25, 3.2, 11.25), wall_mat)
		_solid(root, body, Vector3(x, 0.55, -2.5), Vector3(0.25, 1.1, 3.0), wall_mat)
		_solid(root, body, Vector3(x, 2.85, -2.5), Vector3(0.25, 0.7, 3.0), wall_mat)
		_solid(root, body, Vector3(x, 1.8, -2.5), Vector3(0.06, 1.4, 3.0), glass)
		Models.box(root, Vector3(x - side * 0.14, 1.1, -2.5), Vector3(0.05, 0.08, 3.1), trim)
		# Cockpit side walls.
		_solid(root, body, Vector3(side * 3.125, 1.6, -8.25), Vector3(0.25, 3.2, 4.0), wall_mat)
		# Front bulkhead either side of the cockpit door.
		_solid(root, body, Vector3(side * 3.675, 1.6, -6.125), Vector3(5.15, 3.2, 0.25), wall_mat)
		# Cockpit window frame.
		_solid(root, body, Vector3(side * 2.75, 1.6, -10.125), Vector3(0.5, 3.2, 0.25), wall_mat)
		# Engine bulkhead.
		_solid(root, body, Vector3(side * 3.55, 1.6, 5.0), Vector3(4.9, 3.2, 0.25), wall_mat)
		# Side rooms (weapons on port, scout bay on starboard).
		_solid(root, body, Vector3(side * 4.1875, 1.6, 1.0), Vector3(3.625, 3.2, 0.25), wall_mat)
		_solid(root, body, Vector3(side * 2.5, 1.6, 1.7125), Vector3(0.25, 3.2, 1.175), wall_mat)
		_solid(root, body, Vector3(side * 2.5, 1.6, 4.2875), Vector3(0.25, 3.2, 1.175), wall_mat)
		_solid(root, body, Vector3(side * 2.5, 2.8, 3.0), Vector3(0.25, 0.8, 1.4), wall_mat)
		Models.box(root, Vector3(side * 2.5, 2.38, 3.0), Vector3(0.3, 0.06, 1.4), trim)
		# Wainscot trim and wall ribs.
		Models.box(root, Vector3(x - side * 0.14, 0.35, 4.6), Vector3(0.04, 0.06, 11.0), trim)
		for z: float in [-0.6, 6.2, 8.6]:
			Models.box(root, Vector3(x - side * 0.16, 1.6, z), Vector3(0.08, 3.2, 0.22), dark)
	# Rear wall with the cargo door, and the corridor through the hull to the ramp.
	var corridor_z := (10.25 + RAMP_HINGE.z) * 0.5
	var corridor_len := RAMP_HINGE.z - 10.25
	for side: float in [-1.0, 1.0]:
		_solid(root, body, Vector3(side * (DOOR_HALF_W + (6.25 - DOOR_HALF_W) * 0.5), 1.6, 10.125), Vector3(6.25 - DOOR_HALF_W, 3.2, 0.25), wall_mat)
		_solid(root, body, Vector3(side * (DOOR_HALF_W + 0.1), 1.6, corridor_z), Vector3(0.2, 3.2, corridor_len), wall_mat)
		Models.box(root, Vector3(side * (DOOR_HALF_W + 0.02), 1.5, 9.99), Vector3(0.08, 3.0, 0.04), trim)
	_solid(root, body, Vector3(0, (DOOR_H + 3.2) * 0.5, 10.125), Vector3(DOOR_HALF_W * 2.0, 3.2 - DOOR_H, 0.25), wall_mat)
	_solid(root, body, Vector3(0, -0.15, corridor_z), Vector3(DOOR_HALF_W * 2.0 + 0.4, 0.3, corridor_len), floor_mat)
	_solid(root, body, Vector3(0, 3.35, corridor_z), Vector3(DOOR_HALF_W * 2.0 + 0.4, 0.3, corridor_len), ceil_mat)
	Models.box(root, Vector3(0, DOOR_H + 0.1, 9.99), Vector3(DOOR_HALF_W * 2.0, 0.08, 0.04), trim)
	var door_label := Label3D.new()
	door_label.text = "CARGO RAMP"
	door_label.font_size = 36
	door_label.pixel_size = 0.0045
	door_label.outline_size = 8
	door_label.modulate = Color(1.0, 0.7, 0.3)
	door_label.position = Vector3(0, DOOR_H + 0.1, 9.96)
	door_label.rotation.y = PI
	root.add_child(door_label)
	var ramp := Node3D.new()
	ramp.name = "Ramp"
	ramp.position = RAMP_HINGE
	root.add_child(ramp)
	var ramp_body := StaticBody3D.new()
	ramp_body.collision_layer = Game.LAYER_INTERIOR
	ramp_body.collision_mask = 0
	ramp.add_child(ramp_body)
	_solid(ramp, ramp_body, Vector3(0, RAMP_LENGTH * 0.5, 0.075), Vector3(RAMP_WIDTH, RAMP_LENGTH, 0.15),
			Models.panel_mat(Color(0.55, 0.57, 0.6), 0.35, 0.5, 0.45))
	for i in 6:
		Models.box(ramp, Vector3(0, 0.3 + i * 0.5, -0.006), Vector3(RAMP_WIDTH - 0.4, 0.12, 0.012), trim)
	for side: float in [-1.0, 1.0]:
		Models.sphere(ramp, Vector3(side * (RAMP_WIDTH * 0.5 - 0.15), RAMP_LENGTH - 0.12, -0.03), 0.06, Models.emissive(Color(1.0, 0.6, 0.15), 4.0))
	var ramp_light := OmniLight3D.new()
	ramp_light.position = Vector3(0, 2.7, 11.0)
	ramp_light.omni_range = 5.0
	ramp_light.light_energy = 0.0
	ramp_light.light_color = Color(1.0, 0.55, 0.15)
	root.add_child(ramp_light)
	parts["ramp"] = ramp
	parts["ramp_body"] = ramp_body
	parts["ramp_light"] = ramp_light
	_solid(root, body, Vector3(0, 2.8, -6.125), Vector3(2.2, 0.8, 0.25), wall_mat)
	_solid(root, body, Vector3(0, 2.8, 5.0), Vector3(2.2, 0.8, 0.25), wall_mat)
	_solid(root, body, Vector3(0, 0.45, -10.125), Vector3(5.0, 0.9, 0.25), wall_mat)
	_solid(root, body, Vector3(0, 3.0, -10.125), Vector3(5.0, 0.4, 0.25), wall_mat)
	_solid(root, body, Vector3(0, 1.85, -10.125), Vector3(5.0, 1.9, 0.06), glass)
	Models.box(root, Vector3(0, 2.38, -6.125), Vector3(2.2, 0.06, 0.3), trim)
	Models.box(root, Vector3(0, 2.38, 5.0), Vector3(2.2, 0.06, 0.3), trim)

	# Ceiling light strips and the ship's name over the cockpit door.
	var strip := Models.emissive(Color(1.0, 0.95, 0.85), 2.5)
	for z: float in [-8.2, -3.5, 0.5, 3.0, 7.5]:
		Models.box(root, Vector3(0, 3.18, z), Vector3(1.6, 0.04, 0.3), strip)
	var plate := Label3D.new()
	plate.text = str(layout["name"]).to_upper()
	plate.font_size = 40
	plate.pixel_size = 0.0045
	plate.outline_size = 8
	plate.modulate = layout["trim"]
	plate.position = Vector3(0, 2.75, -5.99)
	root.add_child(plate)

	# Engine core.
	var core_mat := StandardMaterial3D.new()
	core_mat.albedo_color = Color(0.1, 0.25, 0.3)
	core_mat.emission_enabled = true
	core_mat.emission = Color(0.3, 0.85, 1.0)
	core_mat.emission_energy_multiplier = 2.5
	Models.cylinder(root, Vector3(0, 1.6, 7.8), 0.75, 3.2, core_mat, Vector3.ZERO, -1.0, 20)
	Models.cylinder(root, Vector3(0, 0.25, 7.8), 1.1, 0.5, dark, Vector3.ZERO, -1.0, 20)
	Models.cylinder(root, Vector3(0, 2.95, 7.8), 1.1, 0.5, dark, Vector3.ZERO, -1.0, 20)
	for a in 4:
		var ang := a * PI / 2.0 + PI / 4.0
		Models.box(root, Vector3(cos(ang) * 0.95, 1.6, 7.8 + sin(ang) * 0.95), Vector3(0.15, 2.4, 0.15), dark)
	var core_shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 1.1
	cyl.height = 3.2
	core_shape.shape = cyl
	core_shape.position = Vector3(0, 1.6, 7.8)
	body.add_child(core_shape)
	parts["core_mat"] = core_mat

	# Station consoles and seats.
	var screen_cols := {
		"pilot": Color(0.3, 0.9, 1.0), "gun": Color(1.0, 0.45, 0.3), "laser": Color(1.0, 0.75, 0.25), "scout": Color(0.45, 1.0, 0.5),
	}
	var areas := {}
	for id: String in layout["order"]:
		var st: Dictionary = layout["by_id"][id]
		var c: Vector3 = st["console"]
		var size: Vector3 = st["console_size"]
		var col: Color = screen_cols[st["kind"]]
		_solid(root, body, Vector3(c.x, size.y * 0.5, c.z), size, dark)
		var yaw: float = st["seat_yaw"]
		var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
		var screen := Models.box(root, Vector3(c.x, size.y + 0.22, c.z) - fwd * 0.05,
				Vector3(minf(maxf(size.x, size.z) * 0.6, 1.6), 0.4, 0.04), Models.emissive(col, 0.9, Color(0.02, 0.03, 0.04)))
		screen.rotation = Vector3(-0.35, yaw, 0)
		Models.box(root, Vector3(c.x, size.y + 0.005, c.z) - fwd * 0.18, Vector3(minf(maxf(size.x, size.z) * 0.5, 1.2), 0.02, 0.18), Models.emissive(col, 0.5, Color(0.05, 0.05, 0.05)))
		var seat: Vector3 = st["seat"]
		Models.cylinder(root, seat + Vector3(0, 0.22, 0), 0.08, 0.44, dark)
		var seat_root := Node3D.new()
		seat_root.position = seat
		seat_root.rotation.y = yaw
		root.add_child(seat_root)
		Models.box(seat_root, Vector3(0, 0.48, 0.05), Vector3(0.6, 0.1, 0.55), Models.mat(Color(0.2, 0.22, 0.25), 0.2, 0.7))
		Models.box(seat_root, Vector3(0, 0.85, 0.32), Vector3(0.6, 0.7, 0.1), Models.mat(Color(0.2, 0.22, 0.25), 0.2, 0.7))
		var label := Label3D.new()
		label.text = st["label"]
		label.font_size = 42
		label.pixel_size = 0.0045
		label.outline_size = 8
		label.modulate = col
		label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		label.position = Vector3(c.x, 2.35, c.z)
		root.add_child(label)
		areas[id] = _interact_area(root, Vector3(c.x, 0.9, c.z), Vector3(1.8, 1.8, minf(1.8, size.z + 0.6) if st["kind"] == "scout" else 1.8), "station", id)
	parts["station_areas"] = areas

	# Emergency blast button on a pedestal beside the pilot seat.
	var eb := EMERGENCY_BUTTON
	_solid(root, body, Vector3(eb.x, 0.5, eb.z), Vector3(0.45, 1.0, 0.45), dark)
	Models.box(root, Vector3(eb.x, 0.5, eb.z), Vector3(0.47, 0.12, 0.47), Models.mat(Color(0.95, 0.8, 0.1), 0.3, 0.5))
	Models.cylinder(root, Vector3(eb.x, 1.015, eb.z), 0.2, 0.03, Models.mat(Color(0.95, 0.8, 0.1), 0.3, 0.5), Vector3.ZERO, -1.0, 20)
	var blast_mat := StandardMaterial3D.new()
	blast_mat.albedo_color = Color(0.45, 0.02, 0.02)
	blast_mat.emission_enabled = true
	blast_mat.emission = Color(1.0, 0.12, 0.05)
	blast_mat.emission_energy_multiplier = 2.0
	Models.cylinder(root, Vector3(eb.x, 1.07, eb.z), 0.13, 0.09, blast_mat, Vector3.ZERO, 0.11, 16)
	var blabel := Label3D.new()
	blabel.text = "EMERGENCY\nBLAST"
	blabel.font_size = 30
	blabel.pixel_size = 0.0032
	blabel.outline_size = 8
	blabel.modulate = Color(1.0, 0.35, 0.25)
	blabel.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	blabel.position = Vector3(eb.x, 1.5, eb.z)
	root.add_child(blabel)
	_interact_area(root, Vector3(eb.x, 0.9, eb.z), Vector3(0.9, 1.4, 0.9), "emergency", true)
	parts["blast_mat"] = blast_mat

	# Install hub for supply-crate upgrades, against the port wall of the engine room.
	var hub := INSTALL_HUB
	_solid(root, body, Vector3(hub.x, 0.55, hub.z), Vector3(0.9, 1.1, 1.8), dark)
	Models.box(root, Vector3(hub.x + 0.46, 0.6, hub.z), Vector3(0.04, 0.6, 1.4), Models.emissive(Color(0.35, 1.0, 0.6), 1.2, Color(0.02, 0.04, 0.03)))
	Models.box(root, Vector3(hub.x + 0.05, 1.13, hub.z), Vector3(0.7, 0.05, 1.3), Models.emissive(Color(1.0, 0.72, 0.25), 1.6))
	Models.box(root, Vector3(hub.x - 0.27, 1.9, hub.z), Vector3(0.05, 1.0, 1.7), Models.emissive(Color(0.15, 0.45, 0.35), 0.7, Color(0.02, 0.03, 0.03)))
	var hub_label := Label3D.new()
	hub_label.text = "INSTALLED\n(none)"
	hub_label.font_size = 30
	hub_label.pixel_size = 0.0034
	hub_label.outline_size = 6
	hub_label.modulate = Color(0.75, 1.0, 0.85)
	hub_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	hub_label.position = Vector3(hub.x - 0.23, 2.32, hub.z)
	hub_label.rotation.y = PI / 2.0
	root.add_child(hub_label)
	var hub_title := Label3D.new()
	hub_title.text = "INSTALL HUB"
	hub_title.font_size = 42
	hub_title.pixel_size = 0.0045
	hub_title.outline_size = 8
	hub_title.modulate = Color(0.45, 1.0, 0.6)
	hub_title.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	hub_title.position = Vector3(hub.x + 0.2, 2.62, hub.z)
	root.add_child(hub_title)
	_interact_area(root, Vector3(hub.x + 0.8, 0.9, hub.z), Vector3(1.3, 1.8, 2.0), "install_hub", true)
	parts["hub_label"] = hub_label

	# Scout launch hatch marking.
	Models.box(root, Vector3(3.9, 0.01, 3.0), Vector3(1.4, 0.02, 1.4), Models.mat(Color(0.9, 0.75, 0.1), 0.2, 0.6))
	Models.box(root, Vector3(3.9, 0.02, 3.0), Vector3(1.1, 0.02, 1.1), dark)

	# Repair panels.
	var panels: Array = []
	for p in REPAIR_PANELS:
		var pos: Vector3 = p["pos"]
		var yaw: float = p["yaw"]
		var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
		var panel_root := Node3D.new()
		panel_root.position = pos
		panel_root.rotation.y = yaw
		root.add_child(panel_root)
		Models.box(panel_root, Vector3.ZERO, Vector3(1.3, 1.3, 0.14), Models.mat(Color(0.2, 0.22, 0.26), 0.5, 0.5))
		Models.box(panel_root, Vector3(0, 0.25, -0.08), Vector3(1.0, 0.5, 0.04), Models.emissive(Color(0.3, 0.6, 0.9), 1.2))
		var status_mat := StandardMaterial3D.new()
		status_mat.albedo_color = Color(0.05, 0.05, 0.05)
		status_mat.emission_enabled = true
		status_mat.emission = Color(0.3, 1.0, 0.4)
		status_mat.emission_energy_multiplier = 3.0
		Models.box(panel_root, Vector3(0, -0.3, -0.08), Vector3(0.9, 0.18, 0.04), status_mat)
		for i in 3:
			Models.cylinder(panel_root, Vector3(-0.35 + i * 0.35, -0.55, -0.06), 0.06, 0.08, Models.mat(Color(0.7, 0.7, 0.72), 0.7, 0.3), Vector3(90, 0, 0))
		var plabel := Label3D.new()
		plabel.text = "ENGINE" if p["system"] == "engine" else "WEAPON SYSTEMS"
		plabel.font_size = 36
		plabel.pixel_size = 0.006
		plabel.outline_size = 8
		plabel.position = Vector3(0, 0.95, -0.05)
		plabel.rotation.y = PI
		panel_root.add_child(plabel)
		var area := _interact_area(root, pos + fwd * 0.45 - Vector3(0, 0.2, 0), Vector3(1.5, 1.8, 0.9), "repair", p["system"])
		area.rotation.y = yaw
		panels.append({"system": p["system"], "node": panel_root, "status_mat": status_mat, "area": area})
	parts["panels"] = panels

	# Crates and pipes for clutter.
	var crate := Models.panel_mat(Color(0.35, 0.4, 0.3), 0.2, 0.7, 1.0)
	_solid(root, body, Vector3(-5.4, 0.4, 9.3), Vector3(0.8, 0.8, 0.8), crate)
	_solid(root, body, Vector3(5.4, 0.4, 9.3), Vector3(0.8, 0.8, 0.8), crate)
	_solid(root, body, Vector3(-5.5, 0.35, -0.2), Vector3(0.7, 0.7, 0.7), crate)
	_solid(root, body, Vector3(5.5, 0.35, 0.3), Vector3(0.7, 0.7, 0.7), crate)
	var pipe := Models.mat(Color(0.5, 0.45, 0.4), 0.7, 0.4)
	for side: float in [-1.0, 1.0]:
		Models.cylinder(root, Vector3(side * 5.85, 2.95, 4.6), 0.08, 10.5, pipe, Vector3(90, 0, 0))
		Models.cylinder(root, Vector3(side * 5.7, 2.95, 4.6), 0.06, 10.5, Models.mat(Color(0.7, 0.2, 0.15), 0.5, 0.5), Vector3(90, 0, 0))

	# Lighting: normal lights plus red alarm lights.
	var lights: Array[OmniLight3D] = []
	var alarms: Array[OmniLight3D] = []
	for lp: Vector3 in [Vector3(0, 2.8, -8.2), Vector3(-3.2, 2.8, -3.0), Vector3(3.2, 2.8, -3.0), Vector3(0, 2.8, 2.0),
			Vector3(-4.3, 2.8, 3.0), Vector3(4.3, 2.8, 3.0), Vector3(-3.0, 2.8, 7.6), Vector3(3.0, 2.8, 7.6)]:
		var l := OmniLight3D.new()
		l.position = lp
		l.omni_range = 7.5
		l.light_energy = 1.1
		l.light_color = Color(1.0, 0.93, 0.84)
		root.add_child(l)
		lights.append(l)
	for ap: Vector3 in [Vector3(0, 3.0, -4.0), Vector3(0, 3.0, 2.8), Vector3(0, 3.0, 8.5), Vector3(0, 3.0, -8.5)]:
		var a := OmniLight3D.new()
		a.position = ap
		a.omni_range = 9.0
		a.light_energy = 0.0
		a.light_color = Color(1.0, 0.1, 0.05)
		root.add_child(a)
		alarms.append(a)
	parts["lights"] = lights
	parts["alarms"] = alarms
	return parts


static func _solid(root: Node3D, body: StaticBody3D, pos: Vector3, size: Vector3, material: Material) -> void:
	Models.box(root, pos, size, material)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.position = pos
	body.add_child(cs)


static func _interact_area(root: Node3D, pos: Vector3, size: Vector3, key: String, value: Variant) -> Area3D:
	var a := Area3D.new()
	a.collision_layer = Game.LAYER_INTERACT
	a.collision_mask = 0
	a.monitoring = false
	a.position = pos
	a.set_meta(key, value)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	a.add_child(cs)
	root.add_child(a)
	return a


## AStar graph over the interior waypoints (ids follow WAYPOINTS order).
static func build_nav() -> AStar3D:
	var astar := AStar3D.new()
	var ids := {}
	var i := 0
	for k in WAYPOINTS:
		astar.add_point(i, WAYPOINTS[k])
		ids[k] = i
		i += 1
	for link in WAYPOINT_LINKS:
		astar.connect_points(ids[link[0]], ids[link[1]])
	return astar
