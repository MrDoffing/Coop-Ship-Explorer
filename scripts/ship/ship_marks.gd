class_name ShipMarks
extends RefCounted
## Decals on a mothership's hull (see Marks): the painted markings (its name, registration and the
## guild's emblem, warnings by the hatches, the cargo ramp, the tractor field and the scout bays,
## walkways and lifting points), the grime and wear of a working ship (dirt on the roof, streaks
## down the sides, dust on the belly, chipped paint where the crew climb about, soot from the
## thrusters and the guns), and battle damage that fades: acid splashes, claw marks, dents and
## scrapes from the rock.
##
## Big surfaces get their wear from decals rather than baked textures, so a hull costs one small
## tiling plating texture (Models.hull_plating) however big it is. Placement is worked out from the
## hull's sections (ShipTypes) and seeded by the ship type, so every player sees the same ship.

## The ship's name along both sides: where (z, y), how tall (m) and in which paint; "x" puts it
## on a fitting standing out from the hull (the Excavator's ore hoppers, the Dreadnought's armour
## belt).
const NAMES := {
	"prospector": {"z": 4.5, "y": 1.9, "h": 0.88, "color": Color(0.13, 0.15, 0.18)},
	"vanguard": {"z": 3.5, "y": 1.9, "h": 0.88, "color": Color(0.13, 0.15, 0.18)},
	"excavator": {"z": 2.5, "y": 1.75, "h": 0.9, "color": Color(0.09, 0.09, 0.09), "x": 8.6},
	"dreadnought": {"z": 1.8, "y": 1.9, "h": 0.56, "color": Color(0.95, 0.72, 0.25), "x": 9.23},
}
## Where the warning by each roof hatch goes (from the hatch, ShipTypes "hatches" order); behind it
## unless something stands there (the Prospector's spine).
const HATCH_TEXT := {"prospector": [Vector3(0, 0, -1.3), Vector3(0, 0, 1.3), Vector3(0, 0, 1.3)]}
## Markings in this paint, warnings in WARN, walkways and hazard signs in their own.
const MARK := Color(0.13, 0.15, 0.18)
const MARK_LIGHT := Color(0.85, 0.85, 0.82)
const WARN := Color(0.9, 0.7, 0.12)
## How deep a painted decal's box reaches (m), centred on the surface.
const DEPTH := 0.8

## Battle damage by the kind of hit (Mothership.apply_damage): textures, size range (m), seconds
## it lasts, how hot it glows when fresh and how fast that cools (s).
const DAMAGE := {
	"spit": {"tex": ["dmg_acid_a", "dmg_acid_b"], "size": [0.9, 1.4], "life": 150.0, "glow": 2.5, "cool": 3.0},
	"scratch": {"tex": ["dmg_claw"], "size": [0.8, 1.15], "life": 120.0, "glow": 0.0, "cool": 1.0},
	"impact": {"tex": ["dmg_dent"], "size": [1.3, 2.0], "life": 180.0, "glow": 0.0, "cool": 1.0},
	"scrape": {"tex": ["dmg_scrape"], "size": [2.0, 2.6], "life": 120.0, "glow": 0.0, "cool": 1.0},
}
## At most this many damage decals on a ship at once (the oldest fade first).
const DAMAGE_CAP := 48
## A hit this close (m) to a mark of the same kind freshens that one instead (a critter clawing at
## one spot, the hull grinding along the rock).
const DAMAGE_MERGE := 0.5


static func build(root: Node3D, t: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(t["id"]) + "marks")
	_markings(root, t)
	_grime(root, t, rng)


# --- The hull's surface ----------------------------------------------------------------------------------

## The point on the hull's lofted surface nearest to ship-local `p` and the outward normal there:
## [point, normal]; behind the hull, on the stern cap. [] in front of the hull (the glazed nose).
static func surface(t: Dictionary, p: Vector3) -> Array:
	var sections: Array = t["sections"]
	var chamfer := float(t["chamfer"])
	var z0 := float((sections[0] as Array)[0]) + 0.15
	var z1 := float((sections[sections.size() - 1] as Array)[0])
	if p.z < z0 - 1.5:
		return []
	var ring := _ring(sections, chamfer, clampf(p.z, z0, z1))
	var q := Vector2(p.x, p.y)
	if p.z > z1 and Geometry2D.is_point_in_polygon(q, ring):
		return [Vector3(p.x, p.y, z1), Vector3.BACK]
	var z := clampf(p.z, z0, z1 - 0.02)
	var best := Vector2.ZERO
	var best_d := INF
	var k := 0
	for i in ring.size():
		var c := Geometry2D.get_closest_point_to_segment(q, ring[i], ring[(i + 1) % ring.size()])
		var d := c.distance_to(q)
		if d < best_d:
			best_d = d
			best = c
			k = i
	var n2 := _edge_normal(ring, k)
	# The hull narrows or widens along z: tilt the normal by how fast the face moves out.
	var ahead := _ring(sections, chamfer, z + 0.05)
	var slope := (ahead[k].dot(n2) - ring[k].dot(n2)) / 0.05
	return [Vector3(best.x, best.y, z), Vector3(n2.x, n2.y, -slope).normalized()]


## The hull's octagon at z as 2D points (x, y), as Models.octagon builds it.
static func _ring(sections: Array, chamfer: float, z: float) -> PackedVector2Array:
	var s := ShipBuilder.section_at(sections, z)
	var w := s.x
	var h := s.y
	var yc := s.z
	var c := 1.0 - chamfer
	return PackedVector2Array([Vector2(w, yc + h * c), Vector2(w * c, yc + h), Vector2(-w * c, yc + h), Vector2(-w, yc + h * c),
		Vector2(-w, yc - h * c), Vector2(-w * c, yc - h), Vector2(w * c, yc - h), Vector2(w, yc - h * c)])


static func _edge_normal(ring: PackedVector2Array, k: int) -> Vector2:
	var a := ring[k]
	var b := ring[(k + 1) % ring.size()]
	var n := Vector2(b.y - a.y, a.x - b.x).normalized()
	var centre := Vector2.ZERO
	for p in ring:
		centre += p
	centre /= ring.size()
	return n if n.dot((a + b) * 0.5 - centre) > 0.0 else -n


## A painted decal on the hull at the surface near `p`, its texture upright for someone facing it
## with their head towards `up`. Returns null where there is no hull.
static func _paint(root: Node3D, t: Dictionary, tex: String, p: Vector3, up: Vector3, height: float, color: Color,
		width := -1.0, orm := "orm_paint") -> Decal:
	var s := surface(t, p)
	if s.is_empty() or Marks.texture(tex) == null:
		return null
	var n: Vector3 = s[1]
	var w := width if width > 0.0 else height * Marks.aspect(tex)
	var d := Marks.make(tex, Marks.on_surface(s[0], n, Marks.right_of(n, up)), Vector3(w, DEPTH, height), Game.VIS_HULL, color, orm)
	root.add_child(d)
	return d


# --- Markings -------------------------------------------------------------------------------------------

static func _markings(root: Node3D, t: Dictionary) -> void:
	var id := str(t["id"])
	var sections: Array = t["sections"]
	var chamfer := float(t["chamfer"])
	var c := 1.0 - chamfer
	var z0 := float((sections[0] as Array)[0])
	var z1 := float((sections[sections.size() - 1] as Array)[0])
	var name_spec: Dictionary = NAMES.get(id, NAMES["prospector"])
	var paint: Color = name_spec["color"]
	var light := paint.get_luminance() > 0.5
	# The name along both sides, the registration on the bow and big on the roof, the emblem aft.
	for side: float in [-1.0, 1.0]:
		var nz := float(name_spec["z"])
		var ny := float(name_spec["y"])
		if name_spec.has("x"):
			var h := float(name_spec["h"])
			var tex := "name_" + id
			var d := Marks.make(tex, Marks.on_surface(Vector3(side * float(name_spec["x"]), ny, nz), Vector3(side, 0, 0), Vector3(0, 0, -side)),
				Vector3(h * Marks.aspect(tex), DEPTH, h), Game.VIS_HULL, paint, "orm_paint")
			root.add_child(d)
		else:
			_paint(root, t, "name_" + id, Vector3(side * (ShipBuilder.hull_x_at(sections, chamfer, nz, ny) + 0.05), ny, nz), Vector3.UP,
				float(name_spec["h"]), paint)
		var rz := z0 + 1.4
		var ry := ShipBuilder.section_at(sections, rz).z + 0.9
		_paint(root, t, "reg_" + id, Vector3(side * (ShipBuilder.hull_x_at(sections, chamfer, rz, ry) + 0.05), ry, rz), Vector3.UP, 0.42,
			MARK if not light else paint)
		var ez := z1 - 2.4
		var ey := ShipBuilder.section_at(sections, ez).z + 1.2
		_paint(root, t, "sym_emblem", Vector3(side * (ShipBuilder.hull_x_at(sections, chamfer, ez, ey) + 0.05), ey, ez), Vector3.UP, 1.15,
			MARK if not light else paint)
		# NO STEP on the upper chamfer, twice a side.
		for f: float in [0.3, 0.72]:
			var z := lerpf(z0, z1, f)
			var s := ShipBuilder.section_at(sections, z)
			var p := Vector3(side * s.x * (1.0 + c) * 0.5, s.z + s.y * (1.0 + c) * 0.5, z)
			_paint(root, t, "txt_no_step", p * Vector3(1.05, 1.0, 1.0) + Vector3(0, 0.05, 0), Vector3.UP, 0.2, MARK)
	var roof_z := z0 + 2.0
	_paint(root, t, "reg_" + id, Vector3(0, ShipBuilder.top_y(sections, roof_z) + 0.1, roof_z), Vector3.FORWARD, 0.9, MARK if not light else paint)
	# Lifting points at the roof's corners.
	var main := _widest(sections)
	for zf: float in [main.x + 1.2, main.y - 1.6]:
		var s := ShipBuilder.section_at(sections, zf)
		for side: float in [-1.0, 1.0]:
			_paint(root, t, "sym_ring", Vector3(side * (s.x * c - 0.8), s.z + s.y + 0.1, zf), Vector3.FORWARD, 0.55, WARN)
	# Hatches: a warning and an arrow behind each, and walkways between them.
	var hatches: Array = t["hatches"]
	var offsets: Array = HATCH_TEXT.get(id, [])
	for i in hatches.size():
		var h: Vector3 = hatches[i]
		var o: Vector3 = offsets[i] if i < offsets.size() else Vector3(0, 0, 1.3)
		var toward := -o.normalized()
		_paint(root, t, "txt_crew_hatch", h + o + Vector3(0, 0.1, 0), toward, 0.2, MARK)
		_arrow(root, t, h + o * 0.73 + Vector3(0, 0.1, 0), toward)
	for i in hatches.size() - 1:
		var a: Vector3 = hatches[i]
		var b: Vector3 = hatches[i + 1]
		var length := Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z)) - 2.2
		if length > 1.0:
			var mid := (a + b) * 0.5
			var s := surface(t, Vector3(mid.x, ShipBuilder.top_y(sections, mid.z) + 0.1, mid.z))
			if not s.is_empty():
				var d := Marks.make("walkway", Marks.on_surface(s[0], s[1], b - a), Vector3(length, DEPTH, 0.8), Game.VIS_HULL, Color.WHITE, "orm_paint")
				root.add_child(d)
	# The cargo ramp's sign above the door, and hazard signs either side.
	var cap := ShipBuilder.DOOR_H + 0.66
	_paint(root, t, "txt_cargo_ramp", Vector3(0, cap, z1 + 0.5), Vector3.UP, 0.24, MARK)
	for side: float in [-1.0, 1.0]:
		_paint(root, t, "sym_hazard", Vector3(side * (ShipBuilder.DOOR_HALF_W + 0.95), cap - 0.1, z1 + 0.5), Vector3.UP, 0.48, WARN)
	# Underneath: the tractor field, the landing gear and the scout bays.
	var col: Vector3 = t["collector"]
	_paint(root, t, "txt_tractor_field", Vector3(col.x, ShipBuilder.bottom_y(sections, col.z - 1.75) - 0.1, col.z - 1.75), Vector3.FORWARD,
		0.3, WARN)
	for lp: Vector3 in t["legs"]:
		var dz := 1.0 if lp.z < 0.0 else -1.0
		var p := Vector3(lp.x + signf(lp.x) * 1.0, ShipBuilder.bottom_y(sections, lp.z + dz * 1.15) - 0.1, lp.z + dz * 1.15)
		var s := surface(t, p)
		if not s.is_empty():
			var d := Marks.make("txt_keep_clear", Marks.on_surface(s[0], s[1], Vector3(0, 0, dz)), Vector3(0.24 * Marks.aspect("txt_keep_clear"), DEPTH, 0.24),
				Game.VIS_HULL, WARN, "orm_paint")
			root.add_child(d)
	for sid: String in t["scouts"]:
		var def: Dictionary = t["by_id"][sid]
		var dock: Vector3 = def["dock"]
		var launch: Vector3 = def["launch"]
		if launch.y < 0.0:
			var by := ShipBuilder.bottom_y(sections, dock.z)
			for dz: float in [-3.2, 3.2]:
				var d := Marks.make("chevrons", Marks.on_surface(Vector3(dock.x, by - 0.1, dock.z + dz), Vector3.DOWN, Vector3.RIGHT),
					Vector3(3.4, DEPTH, 0.3), Game.VIS_HULL, Color.WHITE, "orm_paint")
				root.add_child(d)
			_paint(root, t, "txt_scout_bay", Vector3(dock.x, by - 0.1, dock.z - 3.75), Vector3.FORWARD, 0.3, WARN)
		else:
			# On a flight deck: the deck is a fitting above the hull, so paint straight down onto it.
			var deck := dock.y - 0.57
			var d := Marks.make("txt_scout_bay", Marks.on_surface(Vector3(dock.x, deck, dock.z - 3.6), Vector3.UP, Vector3.RIGHT),
				Vector3(0.36 * Marks.aspect("txt_scout_bay"), DEPTH, 0.36), Game.VIS_HULL, WARN, "orm_paint")
			root.add_child(d)
	# The fuel point, low on the starboard quarter.
	var fz := z1 - 4.2
	var fy := ShipBuilder.section_at(sections, fz).z - 0.35
	_paint(root, t, "txt_fuel", Vector3(ShipBuilder.hull_x_at(sections, chamfer, fz, fy) + 0.05, fy, fz), Vector3.UP, 0.3, WARN)


## An arrow on the roof at `p` pointing along `dir`.
static func _arrow(root: Node3D, t: Dictionary, p: Vector3, dir: Vector3) -> Decal:
	var s := surface(t, p)
	if s.is_empty():
		return null
	var d := Marks.make("sym_arrow", Marks.on_surface(s[0], s[1], dir), Vector3(0.22 * Marks.aspect("sym_arrow"), DEPTH, 0.22), Game.VIS_HULL, WARN, "orm_paint")
	root.add_child(d)
	return d


## The z range (first, last) of the hull's widest stretch.
static func _widest(sections: Array) -> Vector2:
	var w := 0.0
	for s: Array in sections:
		w = maxf(w, float(s[1]))
	var first := INF
	var last := -INF
	for s: Array in sections:
		if float(s[1]) >= w - 0.5:
			first = minf(first, float(s[0]))
			last = maxf(last, float(s[0]))
	return Vector2(first, last)


# --- Grime and wear ------------------------------------------------------------------------------------

static func _grime(root: Node3D, t: Dictionary, rng: RandomNumberGenerator) -> void:
	var sections: Array = t["sections"]
	var chamfer := float(t["chamfer"])
	var c := 1.0 - chamfer
	var z0 := float((sections[0] as Array)[0]) + 0.6
	var z1 := float((sections[sections.size() - 1] as Array)[0]) - 0.4
	var dirt := Color(1, 1, 1)
	# Dirt on the roof.
	var roof_area := 0.0
	for i in sections.size() - 1:
		roof_area += (float(sections[i + 1][0]) - float(sections[i][0])) * float(sections[i][1]) * 2.0 * c
	for i in int(roof_area / 18.0):
		var z := rng.randf_range(z0, z1)
		var s := ShipBuilder.section_at(sections, z)
		var p := Vector3(rng.randf_range(-1.0, 1.0) * s.x * c * 0.9, s.z + s.y + 0.4, z)
		var size := rng.randf_range(2.5, 5.5)
		var tex: String = ["grime_a", "grime_b", "grime_c"][rng.randi() % 3]
		var d := Marks.make(tex, Marks.on_surface(Vector3(p.x, s.z + s.y + 0.4, p.z), Vector3.UP, Vector3.RIGHT.rotated(Vector3.UP, rng.randf() * TAU)),
			Vector3(size, 2.0, size * rng.randf_range(0.6, 1.0)), Game.VIS_HULL, Color(dirt, rng.randf_range(0.35, 0.6)), "orm_matte")
		root.add_child(d)
	# Streaks run down the sides from the upper chamfer.
	for side: float in [-1.0, 1.0]:
		var z := z0 + 0.4
		while z < z1:
			if rng.randf() < 0.6:
				var s := ShipBuilder.section_at(sections, z)
				var top := s.z + s.y * c - 0.05
				var length := rng.randf_range(1.4, 2.8)
				var y := top - length * 0.5
				var surf := surface(t, Vector3(side * (ShipBuilder.hull_x_at(sections, chamfer, z, y) + 0.05), y, z))
				if not surf.is_empty():
					var n: Vector3 = surf[1]
					var tex := "rust" if rng.randf() < 0.2 else ("streaks_a" if rng.randf() < 0.5 else "streaks_b")
					var d := Marks.make(tex, Marks.on_surface(surf[0], n, Marks.right_of(n, Vector3.UP)),
						Vector3(rng.randf_range(0.5, 1.0), DEPTH, length), Game.VIS_HULL, Color(dirt, rng.randf_range(0.35, 0.65)), "orm_matte")
					root.add_child(d)
			z += rng.randf_range(0.9, 1.6)
	# Dust and mud on the belly, more round the landing gear.
	var belly: Array[Vector3] = []
	for i in int(roof_area / 22.0):
		var z := rng.randf_range(z0, z1)
		var s := ShipBuilder.section_at(sections, z)
		belly.append(Vector3(rng.randf_range(-1.0, 1.0) * s.x * c * 0.85, 0.0, z))
	for lp: Vector3 in t["legs"]:
		belly.append(Vector3(lp.x, 0.0, lp.z + rng.randf_range(-0.8, 0.8)))
	for p in belly:
		var by := ShipBuilder.bottom_y(sections, p.z)
		var size := rng.randf_range(2.0, 4.0)
		var d := Marks.make("dirt" if rng.randf() < 0.6 else "grime_c", Marks.on_surface(Vector3(p.x, by - 0.3, p.z), Vector3.DOWN,
			Vector3.RIGHT.rotated(Vector3.UP, rng.randf() * TAU)), Vector3(size, 1.4, size), Game.VIS_HULL, Color(dirt, rng.randf_range(0.4, 0.65)), "orm_matte")
		root.add_child(d)
	# Chipped paint where the crew climb out, along the roof's edges and round the cargo door.
	for h: Vector3 in t["hatches"]:
		for k in 3:
			var a := rng.randf() * TAU
			_chip(root, t, h + Vector3(cos(a), 0.1, sin(a)) * rng.randf_range(0.8, 1.1), rng.randf_range(0.45, 0.75), rng)
	for side: float in [-1.0, 1.0]:
		for k in 6:
			var z := rng.randf_range(z0, z1)
			var s := ShipBuilder.section_at(sections, z)
			var corner := Vector3(side * s.x * c, s.z + s.y, z) if rng.randf() < 0.5 else Vector3(side * s.x, s.z + s.y * c, z)
			_chip(root, t, corner, rng.randf_range(0.5, 0.9), rng)
	var zs := float((sections[sections.size() - 1] as Array)[0])
	for k in 4:
		var side := -1.0 if k < 2 else 1.0
		_chip(root, t, Vector3(side * (ShipBuilder.DOOR_HALF_W + 0.25), rng.randf_range(0.3, ShipBuilder.DOOR_H), zs + 0.4), rng.randf_range(0.4, 0.7), rng)
	# Soot from the thrusters (ShipBuilder records them) and round the gun pods.
	for r: Array in root.get_meta("rcs", []):
		var pos: Vector3 = r[0]
		for dir: Vector3 in r[1]:
			var s := surface(t, pos + dir * 0.6)
			if s.is_empty():
				continue
			var n: Vector3 = s[1]
			if absf(dir.dot(n)) < 0.6:
				# The plume lies along the hull: a streak of soot from the nozzle.
				var along := (dir - n * dir.dot(n)).normalized()
				var s2 := surface(t, (s[0] as Vector3) + along * 0.7)
				if s2.is_empty():
					continue
				var d := Marks.make("soot", Marks.on_surface(s2[0], s2[1], along), Vector3(1.8, 1.4, 0.8), Game.VIS_HULL,
					Color(dirt, rng.randf_range(0.5, 0.75)), "orm_matte")
				root.add_child(d)
			else:
				var d := Marks.make("soot_round", Marks.on_surface(s[0], n, n.cross(Vector3.FORWARD) if absf(n.z) < 0.9 else Vector3.RIGHT),
					Vector3(1.3, 1.4, 1.3), Game.VIS_HULL, Color(dirt, rng.randf_range(0.4, 0.6)), "orm_matte")
				root.add_child(d)
	for gid: String in t["guns"]:
		var gp: Vector3 = (t["by_id"][gid] as Dictionary)["pos"]
		var s := surface(t, gp)
		if not s.is_empty():
			var d := Marks.make("soot_round", Marks.on_surface(s[0], s[1], Vector3.FORWARD.cross(s[1]) if absf((s[1] as Vector3).z) < 0.9 else Vector3.RIGHT),
				Vector3(2.6, 1.6, 2.6), Game.VIS_HULL, Color(dirt, 0.35), "orm_matte")
			root.add_child(d)


static func _chip(root: Node3D, t: Dictionary, p: Vector3, size: float, rng: RandomNumberGenerator) -> void:
	var s := surface(t, p)
	if s.is_empty():
		return
	var n: Vector3 = s[1]
	var d := Marks.make("chips", Marks.on_surface(s[0], n, n.cross(Vector3.UP).rotated(n, rng.randf() * TAU) if absf(n.y) < 0.9 else
		Vector3.RIGHT.rotated(Vector3.UP, rng.randf() * TAU)), Vector3(size, DEPTH, size), Game.VIS_HULL, Color(1, 1, 1, rng.randf_range(0.6, 0.95)), "orm_metal")
	root.add_child(d)


# --- Battle damage ---------------------------------------------------------------------------------------

## A hit of `kind` (Mothership.apply_damage: "spit", "scratch", "impact", or "scrape" from grinding
## along the rock) near ship-local `at`: a mark on the hull there that fades, kept by `marks` (a
## child of the ship's exterior). A hit next to a mark of the same kind freshens that one.
static func damage(marks: Marks, t: Dictionary, kind: String, at: Vector3) -> void:
	if marks == null:
		return
	var spec: Dictionary = DAMAGE.get(kind, DAMAGE["impact"])
	var s := surface(t, at)
	if s.is_empty():
		return
	var point: Vector3 = s[0]
	var n: Vector3 = s[1]
	var texs: Array = spec["tex"]
	for same: String in texs:
		var old := marks.near(same, point, DAMAGE_MERGE * (2.5 if kind == "scrape" else 1.0))
		if old:
			marks.refresh(old)
			return
	var tex: String = texs.pick_random()
	var size := randf_range(float(spec["size"][0]), float(spec["size"][1]))
	var right := Vector3.BACK if kind == "scrape" else n.cross(Vector3.UP if absf(n.y) < 0.9 else Vector3.RIGHT).rotated(n, randf() * TAU)
	var dims := Vector3(size, 1.2, size * (0.3 if kind == "scrape" else 1.0))
	var d := Marks.make(tex, Marks.on_surface(point, n, right), dims, Game.VIS_HULL, Color.WHITE, "orm_matte")
	marks.add(d, float(spec["life"]), float(spec["glow"]), float(spec["cool"]))
