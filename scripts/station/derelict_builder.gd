class_name DerelictBuilder
extends RefCounted
## Abandoned stations (derelicts, outposts): a hangar cut into the cave wall with a landing pad, a
## pier from the ship's cargo ramp to the station's front wall, and behind it a complex of rooms
## and corridors (OutpostLayout: the plan; OutpostProps: the furniture). Landing there is optional.
## The rooms hold salvage crates and hostile aliens, which the mothership spawns when it lands
## (Mothership._derelict_contents).
##
## The look: a military mining outpost of olive-drab and bronze plate, ribbed wall panels, grated
## floors and heavy door frames; the corridors are ringed with octagonal frames every few metres,
## with pipes along them and caged amber lamps. Some outposts have a generator: until the crew starts
## it only red emergency lamps glow, and some doors stay shut for want of power.
##
## Station-local frame (see CaveGen.derelict): x along the tunnel, y up, z into the wall, origin on
## top of the landing pad. A landed mothership sits at (0, StationBuilder.LAND_HEIGHT, 0) with its
## nose pointing out of the hangar (-z) and its cargo ramp down on the pier, so while it is landed,
## ship-local coordinates are station-local ones minus LAND_HEIGHT in y.
##
## generate() is plain maths (it runs on the cave worker threads); build() makes the nodes.

## The ship turns round this much higher above the pad before settling.
const HOVER := 3.0
## Rock carved out for the hangar (z runs from the tunnel's centre line to HANGAR_BACK).
const HANGAR_HALF_X := 21.0
const HANGAR_FLOOR := -1.5
const HANGAR_ROOF := 16.0
const HANGAR_BACK := 21.0
const HANGAR_ROUND := 3.0
## The station's front wall, with the entrance door, at the end of the pier.
const FACADE_Z := 20.0
const FACADE_T := 0.6
const PIER_HALF_W := 1.9
## Corridors: the octagon's chamfers at the top and bottom corners, the frames' thickness and
## depth, and lamps in every LAMP_EVERY-th straight cell.
const CHAMFER_TOP := 0.6
const CHAMFER_BOTTOM := 0.35
const FRAME_T := 0.2
const FRAME_D := 0.36
const LAMP_EVERY := 2
## Lamps: warm working light, the red emergency lamps, and how far they reach.
const LAMP_COLOR := Color(1.0, 0.64, 0.3)
const EMERGENCY_COLOR := Color(1.0, 0.16, 0.08)
## Doors: a sealed door's slab slides up into the wall over the doorway; a lockdown shutter drops
## in front of it on the corridor side (SHUTTER_OUT from the wall's middle).
const SLAB_T := 0.18
const SHUTTER_OUT := 0.42
## Waypoint ids (see build_nav): cells, doorways and the pier.
const NAV_CELL := 200000
const NAV_DOOR := 100000
const NAV_PIER := 300000


# --- Layout (maths only) -----------------------------------------------------------------------

## The plan: rooms, corridors, doors and furniture (see OutpostLayout).
static func generate(rng: RandomNumberGenerator) -> Dictionary:
	return OutpostLayout.generate(rng)


## The floor point just inside a doorway (in its room), station-local.
static func door_inside(door: Dictionary, depth := 1.2) -> Vector3:
	return (door["pos"] as Vector3) - (door["normal"] as Vector3) * depth


## The floor point just outside a doorway (in its corridor), station-local.
static func door_outside(door: Dictionary, depth := 1.2) -> Vector3:
	return (door["pos"] as Vector3) + (door["normal"] as Vector3) * depth


# --- Navigation --------------------------------------------------------------------------------

## Waypoint graph for walking round the station: the pier, a point in the middle of every free cell
## (rooms and corridors; cells furniture stands on are left out, and room cells link to their
## neighbours, diagonals too, where nothing stands in the way) and one in each doorway, in
## ship-local coordinates of a ship landed there. A closed door's waypoint is switched off (see
## apply_doors), so nobody plans a way through it. Given the mothership's interior layout
## (ShipInteriors), its waypoints are linked in through its cargo ramp (for crew bots); with {} the
## graph covers just the station and its pier (for the aliens living there).
static func build_nav(d: Dictionary, ship_interior: Dictionary) -> AStar3D:
	var astar := AStar3D.new()
	var lift := Vector3(0, StationBuilder.LAND_HEIGHT, 0)
	var layout: Dictionary = d["layout"]
	var kind: PackedByteArray = layout["kind"]
	var owner: PackedInt32Array = layout["owner"]
	var links: Dictionary = layout["links"]
	var rooms: Array = layout["rooms"]
	var blocked := {}
	for room: Dictionary in rooms:
		blocked.merge(OutpostLayout.blocked_cells(room))
	var gx := OutpostLayout.GX
	for i in gx * OutpostLayout.GZ:
		var c := Vector2i(i % gx, i / gx)
		if kind[i] != OutpostLayout.ROCK and not blocked.has(c):
			astar.add_point(NAV_CELL + i, OutpostLayout.cell_pos(c) - lift)
	for i in gx * OutpostLayout.GZ:
		if not astar.has_point(NAV_CELL + i):
			continue
		var c := Vector2i(i % gx, i / gx)
		for step: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(-1, 1)]:
			var n := c + step
			if not OutpostLayout.inside(n) or not astar.has_point(NAV_CELL + OutpostLayout.idx(n)):
				continue
			var ni := OutpostLayout.idx(n)
			var diagonal := step.x != 0 and step.y != 0
			if kind[i] == OutpostLayout.HALL:
				if not diagonal and kind[ni] == OutpostLayout.HALL and links.has(OutpostLayout.edge_key(c, n)):
					astar.connect_points(NAV_CELL + i, NAV_CELL + ni)
				continue
			if kind[ni] != OutpostLayout.ROOM or owner[ni] != owner[i]:
				continue
			if diagonal:
				var a := Vector2i(n.x, c.y)
				var e := Vector2i(c.x, n.y)
				if not astar.has_point(NAV_CELL + OutpostLayout.idx(a)) or not astar.has_point(NAV_CELL + OutpostLayout.idx(e)) \
						or owner[OutpostLayout.idx(a)] != owner[i] or owner[OutpostLayout.idx(e)] != owner[i]:
					continue
			if OutpostLayout.clear_line(rooms[owner[i]], OutpostLayout.cell_pos(c), OutpostLayout.cell_pos(n)):
				astar.connect_points(NAV_CELL + i, NAV_CELL + ni)
	var doors: Array = layout["doors"]
	for di in doors.size():
		var dd: Dictionary = doors[di]
		astar.add_point(NAV_DOOR + di, (dd["pos"] as Vector3) - lift)
		for c: Vector2i in [dd["cell"], dd["out"]]:
			if OutpostLayout.inside(c) and astar.has_point(NAV_CELL + OutpostLayout.idx(c)):
				astar.connect_points(NAV_DOOR + di, NAV_CELL + OutpostLayout.idx(c))
	# The pier, out to the front door (door 0).
	var deck := StationBuilder.DECK_Y
	astar.add_point(NAV_PIER, Vector3(0, deck, StationBuilder.PIER_START + 0.8) - lift)
	astar.add_point(NAV_PIER + 1, Vector3(0, deck, FACADE_Z - 1.2) - lift)
	astar.connect_points(NAV_PIER, NAV_PIER + 1)
	astar.connect_points(NAV_PIER + 1, NAV_DOOR)
	if not ship_interior.is_empty():
		var ids := ShipInteriors.add_to_nav(astar, ship_interior)
		var ramp := astar.get_available_point_id()
		astar.add_point(ramp, Vector3(0, 0, 11.4))
		astar.connect_points(ids[ship_interior["exit"]], ramp)
		astar.connect_points(ramp, NAV_PIER)
	return astar


## Switch the doorways' waypoints on (open) or off (closed): `states` per door (Derelict.DOOR_*).
static func apply_doors(astar: AStar3D, layout: Dictionary, states: PackedByteArray) -> void:
	var doors: Array = layout["doors"]
	for di in doors.size():
		if astar.has_point(NAV_DOOR + di):
			astar.set_point_disabled(NAV_DOOR + di, not Derelict.door_passable(doors[di], states, di))


# --- Nodes -------------------------------------------------------------------------------------

## Build the station's visuals and collision under `parent` (which must sit at the world origin).
static func build(parent: Node3D, d: Dictionary) -> Derelict:
	var root := Derelict.new()
	root.name = "Derelict%d" % int(d["k"])
	root.k = int(d["k"])
	root.layout = d["layout"]
	root.transform = d["xform"]
	parent.add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(d["seed"])
	var m := _materials()
	var b := Models.Batch.new()
	var body := StaticBody3D.new()
	body.collision_layer = Game.LAYER_CAVE | Game.LAYER_STATION
	body.collision_mask = 0
	root.add_child(body)
	_build_pad(root, b, m, rng)
	_build_facade(root, b, body, d, m, rng)
	_build_pier(root, b, m)
	var layout: Dictionary = d["layout"]
	var powered := int(layout["generator"]) >= 0
	_build_shell(b, body, layout, m)
	_build_halls(root, b, layout, m, rng, powered)
	var out := {"tanks": [], "subjects": [], "screens": [], "generator": {}}
	var rooms: Array = layout["rooms"]
	for ri in rooms.size():
		_build_room(root, b, body, layout, ri, m, rng, powered, out)
	_build_doors(root, b, layout, m, rng)
	b.commit(root, "Derelict")
	root.setup(out)
	return root


static func _materials() -> Dictionary:
	return {
		"wall": surface_mat("outpost_wall", Color(1, 1, 1), 0.5, true),
		"hall_wall": surface_mat("outpost_wall", Color(0.82, 0.85, 0.8), 0.5, true),
		"floor": surface_mat("outpost_floor", Color(1, 1, 1), 0.5, false),
		"grate": surface_mat("outpost_grate", Color(1, 1, 1), 1.0, false),
		"ceiling": surface_mat("outpost_wall", Color(0.5, 0.5, 0.5), 0.5, false),
		"steel": Models.mat(Color(0.3, 0.31, 0.31), 0.75, 0.45),
		"gunmetal": Models.mat(Color(0.14, 0.15, 0.16), 0.8, 0.4),
		"olive": Models.mat(Color(0.3, 0.32, 0.2), 0.3, 0.68),
		"bronze": Models.mat(Color(0.55, 0.38, 0.19), 0.85, 0.38),
		"dark": Models.mat(Color(0.08, 0.08, 0.085), 0.5, 0.7),
		"mid": Models.mat(Color(0.27, 0.27, 0.26), 0.6, 0.55),
		"rust": Models.mat(Color(0.34, 0.2, 0.12), 0.3, 0.85),
		"yellow": Models.mat(Color(0.72, 0.56, 0.12), 0.3, 0.7),
		"red_paint": Models.mat(Color(0.5, 0.1, 0.07), 0.3, 0.65),
		"black": Models.mat(Color(0.06, 0.06, 0.06), 0.4, 0.7),
		"crate": Models.panel_mat(Color(0.3, 0.33, 0.22), 0.2, 0.8, 1.0),
		"white": Models.mat(Color(0.62, 0.62, 0.58), 0.15, 0.55),
		"cloth": Models.mat(Color(0.33, 0.34, 0.3), 0.0, 0.95),
		"rubber": Models.mat(Color(0.05, 0.05, 0.05), 0.0, 0.8),
		"stain": Models.mat(Color(0.08, 0.1, 0.06), 0.1, 0.35),
		"glass": Models.glass(Color(0.55, 0.7, 0.68, 0.22)),
		"liquid": Models.emissive(Color(0.3, 0.95, 0.4), 1.1, Color(0.06, 0.2, 0.08)),
		"dead_glass": Models.mat(Color(0.05, 0.07, 0.09), 0.6, 0.15),
		"amber": Models.emissive(Color(1.0, 0.55, 0.15), 2.5),
		"red": Models.emissive(Color(1.0, 0.12, 0.06), 3.0),
		"screen": Models.emissive(Color(0.25, 0.7, 0.55), 0.7, Color(0.02, 0.03, 0.03)),
		"goo": Alien.organic(Color(0.16, 0.07, 0.18), Color(0.6, 1.0, 0.25), 1.2, 5.0),
	}


## A tiling outpost surface (res://assets/textures/<texture>_*, made by tools/blender/outpost.py):
## painted wall panels, tread plate or grating, mapped from three sides in the station's frame,
## `scale` tiles a metre, tinted `tint`. `deck_seams` lines the wall panels' seams up with the deck.
static func surface_mat(texture: String, tint: Color, scale: float, deck_seams: bool) -> ORMMaterial3D:
	var key := "%s|%s|%.2f|%s" % [texture, tint.to_html(), scale, deck_seams]
	if _surfaces.has(key):
		return _surfaces[key]
	var m := ORMMaterial3D.new()
	m.albedo_color = tint
	m.albedo_texture = load("res://assets/textures/%s_albedo.png" % texture)
	m.orm_texture = load("res://assets/textures/%s_orm.png" % texture)
	m.roughness = 1.0
	m.metallic = 1.0
	m.ao_enabled = true
	m.normal_enabled = true
	m.normal_texture = load("res://assets/textures/%s_normal.png" % texture)
	m.uv1_triplanar = true
	m.uv1_triplanar_sharpness = 8.0
	m.uv1_scale = Vector3.ONE * scale
	if deck_seams:
		m.uv1_offset = Vector3(0, -StationBuilder.DECK_Y * scale, 0)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_surfaces[key] = m
	return m


static var _surfaces: Dictionary = {}


static func _shape(body: StaticBody3D, pos: Vector3, size: Vector3, yaw := 0.0) -> void:
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.position = pos
	cs.rotation.y = yaw
	body.add_child(cs)


static func _solid(b: Models.Batch, body: StaticBody3D, pos: Vector3, size: Vector3, material: Material) -> void:
	b.box(pos, size, material)
	_shape(body, pos, size)


static func _block(b: Models.Batch, body: StaticBody3D, lo: Vector3, hi: Vector3, material: Material) -> void:
	_solid(b, body, (lo + hi) * 0.5, hi - lo, material)


static func _label(root: Node3D, text: String, pos: Vector3, size: int, pixel: float, color: Color, yaw := PI) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = pixel
	l.outline_size = 10
	l.modulate = color
	l.position = pos
	l.rotation.y = yaw
	root.add_child(l)
	return l


static func _omni(root: Derelict, pos: Vector3, color: Color, energy: float, reach: float, flicker := false, rng: RandomNumberGenerator = null) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = reach
	root.add_child(l)
	if flicker and rng:
		root.add_flicker(l, rng.randf_range(0.15, 0.45), rng.randf())
	return l


## Alien growth: a cluster of glowing organic lumps around a point on a surface.
static func _growth(root: Node3D, pos: Vector3, normal: Vector3, m: Dictionary, rng: RandomNumberGenerator, scale := 1.0) -> void:
	var up := normal.normalized()
	var side := up.cross(Vector3.UP if absf(up.y) < 0.9 else Vector3.RIGHT).normalized()
	var fwd := side.cross(up)
	for i in rng.randi_range(3, 6):
		var mi := MeshInstance3D.new()
		mi.mesh = Models.blob_mesh(rng.randi() % 7, 1.0, 0.35, 10)
		mi.material_override = m["goo"]
		var off := side * rng.randf_range(-0.9, 0.9) + fwd * rng.randf_range(-0.9, 0.9)
		var r := rng.randf_range(0.25, 0.6) * scale
		mi.transform = Transform3D(Basis(side * r * 1.4, up * r * 0.5, fwd * r * 1.2), pos + off * scale)
		root.add_child(mi)


# --- Hangar ------------------------------------------------------------------------------------

## The landing pad: faded markings, grime and dead landing lights.
static func _build_pad(root: Derelict, b: Models.Batch, m: Dictionary, rng: RandomNumberGenerator) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = Game.LAYER_CAVE
	body.collision_mask = 0
	root.add_child(body)
	_solid(b, body, Vector3(0, -0.6, -2.0), Vector3(28.0, 1.2, 32.0), m["floor"])
	b.box(Vector3(0, -2.8, -2.0), Vector3(27.0, 3.2, 31.0), m["dark"])
	# The front of the pad juts out over the tunnel: girders brace it against the rock below.
	for x: float in [-12.0, -4.0, 4.0, 12.0]:
		b.box(Vector3(x, -14.0, -16.5), Vector3(1.2, 24.0, 1.2), m["dark"])
		b.beam(Vector3(x, -4.0, -16.5), Vector3(x, -16.0, -4.0), 0.6, 0.6, m["mid"])
	b.box(Vector3(0, -4.6, -17.2), Vector3(28.0, 0.8, 0.8), m["rust"])
	# What is left of the touchdown ring and the guide stripes.
	for i in 28:
		if rng.randf() < 0.35:
			continue
		var a := TAU * i / 28.0
		b.box(Vector3(cos(a) * 7.2, 0.015, sin(a) * 7.2), Vector3(1.4, 0.03, 0.45), m["yellow"], Vector3(0, -rad_to_deg(a) + 90.0, 0))
	for i in 12:
		if rng.randf() < 0.3:
			continue
		b.box(Vector3(-11.0 + i * 2.0, 0.015, -16.6), Vector3(0.9, 0.03, 0.9), m["yellow"], Vector3(0, 45, 0))
	# Grime, scorch marks and scattered debris.
	for i in 14:
		var p := Vector3(rng.randf_range(-12.0, 12.0), 0.012, rng.randf_range(-16.0, 12.0))
		b.box(p, Vector3(rng.randf_range(1.0, 4.0), 0.02, rng.randf_range(1.0, 4.0)), m["black"], Vector3(0, rng.randf_range(0, 90), 0))
	for i in 10:
		var p := Vector3(rng.randf_range(-13.0, 13.0), 0.15, rng.randf_range(-17.0, 13.0))
		if absf(p.x) < 6.0 and absf(p.z) < 11.0:
			continue
		b.box(p, Vector3(rng.randf_range(0.3, 1.2), rng.randf_range(0.15, 0.5), rng.randf_range(0.3, 1.4)), m["rust"] if i % 3 == 0 else m["mid"],
			Vector3(rng.randf_range(-20, 20), rng.randf_range(0, 180), rng.randf_range(-20, 20)))
	# A toppled cargo container at the edge of the pad.
	var cx := -13.0 if rng.randf() < 0.5 else 13.0
	_solid(b, body, Vector3(cx, 1.2, -14.0), Vector3(2.6, 2.4, 6.0), m["crate"])
	b.box(Vector3(cx, 2.42, -14.0), Vector3(2.4, 0.05, 5.6), m["rust"])
	for z: float in [-16.6, -11.0, -5.0, 1.0, 7.0]:
		for x: float in [-13.7, 13.7]:
			b.box(Vector3(x, 0.06, z), Vector3(0.3, 0.12, 0.3), m["amber"] if rng.randf() < 0.3 else m["dark"])


## The front wall across the end of the hangar, with the entrance door, signs and floodlights.
static func _build_facade(root: Derelict, b: Models.Batch, body: StaticBody3D, d: Dictionary, m: Dictionary, rng: RandomNumberGenerator) -> void:
	var layout: Dictionary = d["layout"]
	var cmin: Vector3 = layout["carve_min"]
	var cmax: Vector3 = layout["carve_max"]
	var hx := maxf(HANGAR_HALF_X, maxf(-cmin.x, cmax.x)) + 3.0
	var y0 := HANGAR_FLOOR - 3.0
	var y1 := maxf(HANGAR_ROOF, cmax.y) + 3.0
	var z0 := FACADE_Z - FACADE_T * 0.5
	var z1 := FACADE_Z + FACADE_T * 0.5
	var dw := OutpostLayout.DOOR_W * 0.5
	var dh := OutpostLayout.DOOR_H
	var deck := StationBuilder.DECK_Y
	_block(b, body, Vector3(-hx, y0, z0), Vector3(-dw, y1, z1), m["wall"])
	_block(b, body, Vector3(dw, y0, z0), Vector3(hx, y1, z1), m["wall"])
	_block(b, body, Vector3(-dw, y0, z0), Vector3(dw, deck, z1), m["wall"])
	_block(b, body, Vector3(-dw, deck + dh, z0), Vector3(dw, y1, z1), m["wall"])
	var fz := z0 - 0.02
	# Ribs, a dead window band and cracked panels.
	for x: float in [-18.0, -10.0, 10.0, 18.0]:
		b.box(Vector3(x, 7.0, fz - 0.25), Vector3(0.9, 18.0, 0.5), m["olive"])
		b.box(Vector3(x, 7.0, fz - 0.52), Vector3(0.3, 18.0, 0.06), m["bronze"])
	for side: float in [-1.0, 1.0]:
		b.box(Vector3(side * 14.0, 9.5, fz), Vector3(6.5, 2.0, 0.05), m["dead_glass"])
		b.box(Vector3(side * 5.5, 6.5, fz), Vector3(3.5, 1.2, 0.05), m["dead_glass"])
		for i in 3:
			b.box(Vector3(side * rng.randf_range(3.0, 19.0), rng.randf_range(1.0, 13.0), fz - 0.06),
				Vector3(rng.randf_range(1.0, 2.6), rng.randf_range(0.8, 2.0), 0.08), m["rust"] if i == 0 else m["mid"],
				Vector3(0, 0, rng.randf_range(-12.0, 12.0)))
	# Door frame with hazard stripes, a jammed door panel and a blinking warning light.
	for side: float in [-1.0, 1.0]:
		b.box(Vector3(side * (dw + 0.25), deck + dh * 0.5, fz - 0.05), Vector3(0.5, dh, 0.12), m["black"])
		for i in 4:
			b.box(Vector3(side * (dw + 0.25), deck + 0.4 + i * 0.7, fz - 0.12), Vector3(0.52, 0.28, 0.02), m["yellow"], Vector3(0, 0, 35))
	b.box(Vector3(0, deck + dh + 0.25, fz - 0.05), Vector3(OutpostLayout.DOOR_W + 1.0, 0.5, 0.12), m["black"])
	_solid(b, body, Vector3(-dw - 0.05, deck + dh * 0.5, z1 + 0.15), Vector3(0.9, dh, 0.2), m["mid"])
	Models.sphere(root, Vector3(0, deck + dh + 0.75, fz - 0.15), 0.22, Models.blink(Color(1.0, 0.15, 0.05), 0.8, 0.0, 0.3))
	# Name board and warnings.
	b.box(Vector3(0, 13.0, fz - 0.1), Vector3(16.0, 2.2, 0.2), m["dark"])
	_label(root, str(d["name"]), Vector3(0, 13.0, fz - 0.25), 150, 0.011, Color(0.85, 0.55, 0.25))
	_label(root, "ABANDONED  -  NO SIGNAL", Vector3(0, 11.4, fz - 0.25), 64, 0.01, Color(0.85, 0.3, 0.25))
	_label(root, "QUARANTINE", Vector3(0, deck + dh + 1.5, fz - 0.15), 48, 0.008, Color(1.0, 0.85, 0.3))
	# Growth creeping out of the doorway.
	_growth(root, Vector3(dw + 0.9, deck + 2.6, fz - 0.1), Vector3(0, 0, -1), m, rng, 0.8)
	_growth(root, Vector3(-hx + 6.0, rng.randf_range(2.0, 8.0), fz - 0.1), Vector3(0, 0, -1), m, rng, 1.4)
	# Floodlights over the pad, flickering.
	for side: float in [-1.0, 1.0]:
		var housing := Vector3(side * 8.0, 14.6, fz - 1.0)
		b.box(housing, Vector3(1.6, 0.6, 1.0), m["dark"])
		var flood := SpotLight3D.new()
		var lamp := housing + Vector3(0, -0.4, -0.3)
		flood.transform = Transform3D(Basis.looking_at(Vector3(side * 2.0, 0.0, -4.0) - lamp, Vector3.UP), lamp)
		root.add_child(flood)
		flood.spot_range = 45.0
		flood.spot_angle = 48.0
		flood.spot_attenuation = 0.8
		flood.light_energy = 3.0
		flood.light_color = Color(1.0, 0.82, 0.6)
		flood.light_projector = Models.light_cookie("flood")
		ShipBuilder.configure_shadow(flood)
		if side > 0.0:
			root.add_flicker(flood, rng.randf_range(0.12, 0.25), rng.randf())
		b.box(housing + Vector3(0, -0.31, -0.2), Vector3(1.3, 0.04, 0.6), m["amber"])
	_omni(root, Vector3(0, deck + dh + 0.9, fz - 1.0), Color(1.0, 0.2, 0.1), 1.2, 9.0, true, rng)


## The pier from the cargo ramp to the door; one of its railings has fallen off.
static func _build_pier(root: Derelict, b: Models.Batch, m: Dictionary) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = Game.LAYER_STATION
	body.collision_mask = 0
	root.add_child(body)
	var deck := StationBuilder.DECK_Y
	var z0 := StationBuilder.PIER_START
	var z1 := FACADE_Z - FACADE_T * 0.5
	var length := z1 - z0
	var zc := (z0 + z1) * 0.5
	_solid(b, body, Vector3(0, deck - 0.15, zc), Vector3(PIER_HALF_W * 2.0, 0.3, length), m["grate"])
	b.box(Vector3(-PIER_HALF_W + 0.15, deck + 0.01, zc), Vector3(0.12, 0.02, length), m["yellow"])
	var x := PIER_HALF_W - 0.05
	_shape(body, Vector3(x, deck + 0.6, zc + 0.15), Vector3(0.08, 1.2, length - 0.3))
	b.box(Vector3(x, deck + 1.15, zc + 0.15), Vector3(0.1, 0.1, length - 0.3), m["rust"])
	for i in 4:
		b.box(Vector3(x, deck + 0.6, z0 + 0.3 + (length - 0.4) * float(i) / 3.0), Vector3(0.1, 1.2, 0.1), m["mid"])
	_shape(body, Vector3(-x, deck + 0.6, zc + 0.15), Vector3(0.08, 1.2, length - 0.3))
	b.box(Vector3(-x, deck + 0.6, z0 + 0.3), Vector3(0.1, 1.2, 0.1), m["mid"])
	b.box(Vector3(-x - 0.6, 0.2, zc), Vector3(0.1, 0.1, length - 1.0), m["rust"], Vector3(0, 0, 70))
	for xs: float in [-1.4, 1.4]:
		b.box(Vector3(xs, (deck - 0.3 + HANGAR_FLOOR - 1.0) * 0.5, zc + 0.6), Vector3(0.45, deck - 0.3 - HANGAR_FLOOR + 1.0, 0.45), m["mid"])


# --- The complex -------------------------------------------------------------------------------

## True when nothing separates 4-neighbouring cells a and b: the same room, or linked corridor.
static func _open_edge(layout: Dictionary, a: Vector2i, b: Vector2i) -> bool:
	if not OutpostLayout.inside(a) or not OutpostLayout.inside(b):
		return false
	var kind: PackedByteArray = layout["kind"]
	var owner: PackedInt32Array = layout["owner"]
	var ia := OutpostLayout.idx(a)
	var ib := OutpostLayout.idx(b)
	if kind[ia] == OutpostLayout.ROOM and kind[ib] == OutpostLayout.ROOM:
		return owner[ia] == owner[ib]
	if kind[ia] == OutpostLayout.HALL and kind[ib] == OutpostLayout.HALL:
		return (layout["links"] as Dictionary).has(OutpostLayout.edge_key(a, b))
	return false


static func _walkable(layout: Dictionary, c: Vector2i) -> bool:
	return OutpostLayout.inside(c) and (layout["kind"] as PackedByteArray)[OutpostLayout.idx(c)] != OutpostLayout.ROCK


## The door between 4-neighbouring cells, or -1.
static func _door_between(layout: Dictionary, a: Vector2i, b: Vector2i) -> int:
	if not OutpostLayout.inside(a) or not OutpostLayout.inside(b):
		return -1
	return int((layout["door_at"] as Dictionary).get(OutpostLayout.edge_key(a, b), -1))


# --- Walls, for the aliens' moves ------------------------------------------------------------------

## True when something's middle may go from station-local point a to b (a short step): within one
## cell, or into a neighbouring one it is open to (the same room, a linked corridor, or through an
## open doorway between its jambs; a shut door is a wall). `doors`: the doors' states (Derelict).
## On and off the grid (the pier) only by the front door; out of rock always, never into it.
static func step_clear(layout: Dictionary, doors: PackedByteArray, a: Vector3, b: Vector3) -> bool:
	var ca := OutpostLayout.cell_at(a)
	var cb := OutpostLayout.cell_at(b)
	if ca == cb:
		return true
	var on_a := OutpostLayout.inside(ca)
	var on_b := OutpostLayout.inside(cb)
	if not on_a and not on_b:
		return true
	if on_a and not _walkable(layout, ca):
		return true
	if on_b and not _walkable(layout, cb):
		return false
	var mid := (a + b) * 0.5
	var d := cb - ca
	if absi(d.x) + absi(d.y) == 1:
		return _side_open(layout, doors, ca, cb, mid, 0.0)
	if absi(d.x) == 1 and absi(d.y) == 1:
		for m: Vector2i in [Vector2i(cb.x, ca.y), Vector2i(ca.x, cb.y)]:
			if _walkable(layout, m) and _side_open(layout, doors, ca, m, mid, 0.0) and _side_open(layout, doors, m, cb, mid, 0.0):
				return true
	return false


## Station-local point p moved off the walls of its cell, the jambs of its doorways and the ends of
## walls at its corners, to at least `margin` from their faces: where something that thick may be.
static func keep_off_walls(layout: Dictionary, doors: PackedByteArray, p: Vector3, margin: float) -> Vector3:
	var c := OutpostLayout.cell_at(p)
	if not _walkable(layout, c):
		return p
	var centre := OutpostLayout.cell_pos(c)
	var reach := OutpostLayout.CELL * 0.5 - OutpostLayout.WALL_T * 0.5 - margin
	var out := p
	for dir: Vector2i in OutpostLayout.DIRS:
		var off := (p.x - centre.x) * dir.x + (p.z - centre.z) * dir.y
		if off <= reach or _side_open(layout, doors, c, c + dir, p, margin):
			continue
		if dir.x != 0:
			out.x = centre.x + dir.x * reach
		else:
			out.z = centre.z + dir.y * reach
	for dx: int in [-1, 1]:
		for dz: int in [-1, 1]:
			var ox := (out.x - centre.x) * dx
			var oz := (out.z - centre.z) * dz
			if ox <= reach or oz <= reach:
				continue
			var diag := c + Vector2i(dx, dz)
			if _walkable(layout, diag) and _open_edge(layout, c + Vector2i(dx, 0), diag) and _open_edge(layout, c + Vector2i(0, dz), diag):
				continue
			# The end of a wall at this corner: out of its way the shorter way.
			if ox < oz:
				out.x = centre.x + dx * reach
			else:
				out.z = centre.z + dz * reach
	return out


## Whether something `margin` thick at station-local point p may cross from cell c into its
## 4-neighbour n: they are open to each other, or p is within an open doorway between them.
static func _side_open(layout: Dictionary, doors: PackedByteArray, c: Vector2i, n: Vector2i, p: Vector3, margin: float) -> bool:
	if _open_edge(layout, c, n):
		return true
	var front := Vector2i(OutpostLayout.MID, 0)
	var pier := Vector2i(OutpostLayout.MID, -1)
	if (c == front and n == pier) or (c == pier and n == front):
		return absf(p.x) < OutpostLayout.DOOR_W * 0.5 - margin
	var di := _door_between(layout, c, n)
	if di < 0 or not Derelict.door_passable(layout["doors"][di], doors, di):
		return false
	var dd: Dictionary = layout["doors"][di]
	var across := (dd["normal"] as Vector3).cross(Vector3.UP)
	return absf((p - (dd["pos"] as Vector3)).dot(across)) < OutpostLayout.DOOR_W * 0.5 - margin


## Floors, ceilings and walls: every cell's floor and ceiling, and a wall on every edge between a
## walkable cell and anything it isn't open to (rock, another room, a corridor it isn't linked to),
## with doorways cut where the doors are. Runs of equal pieces are merged.
static func _build_shell(b: Models.Batch, body: StaticBody3D, layout: Dictionary, m: Dictionary) -> void:
	var kind: PackedByteArray = layout["kind"]
	var deck := StationBuilder.DECK_Y
	var cell := OutpostLayout.CELL
	var gx := OutpostLayout.GX
	var gz := OutpostLayout.GZ
	# Floors and ceilings, merged along each row.
	for j in gz:
		var i := 0
		while i < gx:
			var c := Vector2i(i, j)
			if kind[OutpostLayout.idx(c)] == OutpostLayout.ROCK:
				i += 1
				continue
			var k := kind[OutpostLayout.idx(c)]
			var h := OutpostLayout.ceiling(layout, c)
			var e := i
			while e + 1 < gx and kind[OutpostLayout.idx(Vector2i(e + 1, j))] == k and is_equal_approx(OutpostLayout.ceiling(layout, Vector2i(e + 1, j)), h):
				e += 1
			var p0 := OutpostLayout.cell_pos(Vector2i(i, j))
			var p1 := OutpostLayout.cell_pos(Vector2i(e, j))
			var mid := (p0 + p1) * 0.5
			var size := Vector3(p1.x - p0.x + cell, 0.3, cell)
			var hall := k == OutpostLayout.HALL
			_solid(b, body, Vector3(mid.x, deck - 0.15, mid.z), size, m["grate"] if hall else m["floor"])
			_solid(b, body, Vector3(mid.x, deck + h + 0.15, mid.z), size, m["ceiling"])
			i = e + 1
	# Walls along x (between rows j and j + 1) and along z (between columns i and i + 1).
	for axis in 2:
		var lines := gz if axis == 0 else gx
		var along_n := gx if axis == 0 else gz
		for line in range(0 if axis == 0 else -1, lines):
			var run_start := -1
			var run_h := 0.0
			for t in along_n + 1:
				var h := 0.0
				var door := -1
				if t < along_n:
					var a := Vector2i(t, line) if axis == 0 else Vector2i(line, t)
					var e := a + (Vector2i(0, 1) if axis == 0 else Vector2i(1, 0))
					if (_walkable(layout, a) or _walkable(layout, e)) and not _open_edge(layout, a, e):
						h = maxf(OutpostLayout.ceiling(layout, a), OutpostLayout.ceiling(layout, e))
						door = _door_between(layout, a, e)
						if door >= 0:
							_doorway_wall(b, body, a, e, h, m)
							h = 0.0
				if run_start >= 0 and (h <= 0.0 or not is_equal_approx(h, run_h)):
					_wall_run(b, body, axis, line, run_start, t - 1, run_h, m)
					run_start = -1
				if h > 0.0 and run_start < 0:
					run_start = t
					run_h = h


## A merged wall from cell `t0` to `t1` along a grid line.
static func _wall_run(b: Models.Batch, body: StaticBody3D, axis: int, line: int, t0: int, t1: int, h: float, m: Dictionary) -> void:
	var cell := OutpostLayout.CELL
	var deck := StationBuilder.DECK_Y
	var wt := OutpostLayout.WALL_T
	if axis == 0:
		var a := OutpostLayout.cell_pos(Vector2i(t0, line))
		var e := OutpostLayout.cell_pos(Vector2i(t1, line))
		var z := a.z + cell * 0.5
		_block(b, body, Vector3(a.x - cell * 0.5 - wt * 0.5, deck, z - wt * 0.5), Vector3(e.x + cell * 0.5 + wt * 0.5, deck + h, z + wt * 0.5), m["wall"])
	else:
		var a := OutpostLayout.cell_pos(Vector2i(line, t0))
		var e := OutpostLayout.cell_pos(Vector2i(line, t1))
		var x := a.x + cell * 0.5
		_block(b, body, Vector3(x - wt * 0.5, deck, a.z - cell * 0.5 - wt * 0.5), Vector3(x + wt * 0.5, deck + h, e.z + cell * 0.5 + wt * 0.5), m["wall"])


## The wall on a doorway's edge: a piece either side of the opening and a lintel over it.
static func _doorway_wall(b: Models.Batch, body: StaticBody3D, a: Vector2i, e: Vector2i, h: float, m: Dictionary) -> void:
	var cell := OutpostLayout.CELL
	var deck := StationBuilder.DECK_Y
	var wt := OutpostLayout.WALL_T
	var dw := OutpostLayout.DOOR_W * 0.5
	var mid := (OutpostLayout.cell_pos(a) + OutpostLayout.cell_pos(e)) * 0.5
	var along_x := a.y != e.y
	var t := Vector3(1, 0, 0) if along_x else Vector3(0, 0, 1)
	var n := Vector3(0, 0, 1) if along_x else Vector3(1, 0, 0)
	for side: float in [-1.0, 1.0]:
		var c0 := mid + t * side * dw
		var c1 := mid + t * side * (cell * 0.5 + wt * 0.5)
		var lo := Vector3(minf(c0.x, c1.x), deck, minf(c0.z, c1.z)) - n * wt * 0.5
		var hi := Vector3(maxf(c0.x, c1.x), deck + h, maxf(c0.z, c1.z)) + n * wt * 0.5
		_block(b, body, lo, hi, m["wall"])
	var l0 := mid - t * dw - n * wt * 0.5
	var l1 := mid + t * dw + n * wt * 0.5
	_block(b, body, Vector3(l0.x, deck + OutpostLayout.DOOR_H, l0.z), Vector3(l1.x, deck + h, l1.z), m["wall"])


## Which sides of a corridor cell are open (to a linked corridor cell or through a doorway): one bit
## per OutpostLayout.DIRS entry.
static func _hall_opens(layout: Dictionary, c: Vector2i) -> int:
	var bits := 0
	for d in 4:
		var n: Vector2i = c + OutpostLayout.DIRS[d]
		if _open_edge(layout, c, n) or _door_between(layout, c, n) >= 0:
			bits |= 1 << d
	if c == Vector2i(OutpostLayout.MID, 0):
		bits |= 1 << 3
	return bits


## The corridors: straight runs get octagonal frames, chamfered corners, pipes and lamps; corners
## and junctions a frame in the ceiling and a lamp.
static func _build_halls(root: Derelict, b: Models.Batch, layout: Dictionary, m: Dictionary, rng: RandomNumberGenerator, powered: bool) -> void:
	var h := OutpostLayout.CORRIDOR_H
	var w := OutpostLayout.CELL * 0.5 - OutpostLayout.WALL_T * 0.5
	for c: Vector2i in OutpostLayout.corridor_cells(layout):
		var bits := _hall_opens(layout, c)
		var p := OutpostLayout.cell_pos(c)
		var straight_x := bits == 3
		var straight_z := bits == 12
		if straight_x or straight_z:
			var x := Transform3D(Basis(Vector3.UP, PI / 2.0) if straight_x else Basis.IDENTITY, p)
			_octagon_frame(b, x, m)
			for e: Array in _octagon_edges():
				var a: Vector2 = e[0]
				var f: Vector2 = e[1]
				if a.y > 0.01 and f.y > 0.01 and absf(a.x - f.x) > 0.01 and absf(a.y - f.y) > 0.01:
					_panel_along(b, x, a, f, OutpostLayout.CELL, m["hall_wall"])
				elif a.y < 0.01 != (f.y < 0.01):
					_panel_along(b, x, a, f, OutpostLayout.CELL, m["steel"])
			# Pipes along the right-hand wall under the chamfer, a cable tray on the left.
			var pv := h - CHAMFER_TOP - 0.2
			b.cyl_at(x * Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(w - 0.14, pv, 0)), 0.075, OutpostLayout.CELL, m["bronze"], -1.0, 8)
			b.cyl_at(x * Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(w - 0.12, pv - 0.24, 0)), 0.05, OutpostLayout.CELL, m["olive"], -1.0, 8)
			b.box(x * Vector3(-w + 0.12, pv + 0.05, 0), Vector3(0.18, 0.06, OutpostLayout.CELL) if straight_z else Vector3(OutpostLayout.CELL, 0.06, 0.18), m["steel"])
			for i in 3:
				b.cyl_at(x * Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(-w + 0.08 + i * 0.05, pv + 0.1, 0)), 0.022, OutpostLayout.CELL, m["rubber"], -1.0, 8)
			# A grate down the middle of the floor and steel plates either side.
			b.box(x * Vector3(0, 0.005, 0), Vector3(1.3, 0.012, OutpostLayout.CELL) if straight_z else Vector3(OutpostLayout.CELL, 0.012, 1.3), m["dark"])
			if (c.x + c.y) % LAMP_EVERY == 0:
				_hall_lamp(root, b, x * Vector3(0, h, 0.9), straight_x, m, rng, powered, c)
			elif rng.randf() < 0.3:
				_emergency_lamp(root, b, x * Vector3(-w + 0.02, 2.2, 0.0), x.basis * Vector3(1, 0, 0), m, rng, powered, c)
		else:
			# A corner or junction: a square frame in the ceiling round a lamp.
			for i in 4:
				var a := Vector3(-1.0, 0, -1.0).rotated(Vector3.UP, i * PI / 2.0)
				var e := Vector3(1.0, 0, -1.0).rotated(Vector3.UP, i * PI / 2.0)
				b.beam(p + a * w + Vector3(0, h - 0.12, 0), p + e * w + Vector3(0, h - 0.12, 0), FRAME_T, 0.24, m["bronze"])
			for d in 4:
				if bits & (1 << d) != 0:
					continue
				# A closed side: a ribbed bulkhead panel on the wall.
				var dv := Vector3(OutpostLayout.DIRS[d].x, 0, OutpostLayout.DIRS[d].y)
				var wx := Transform3D(Basis.looking_at(dv, Vector3.UP), p + dv * (w - 0.04))
				for r in 5:
					b.box(wx * Vector3(0, 0.45 + r * 0.55, 0), Vector3(2.2, 0.08, 0.08), m["steel"])
			_hall_lamp(root, b, p + Vector3(0, h, 0), false, m, rng, powered, c)


## The octagon a corridor's frames follow (across, up), corridor along local z: [from, to] of each
## side but the floor.
static func _octagon_edges() -> Array:
	var w := OutpostLayout.CELL * 0.5 - OutpostLayout.WALL_T * 0.5
	var h := OutpostLayout.CORRIDOR_H
	var ct := CHAMFER_TOP
	var cb := CHAMFER_BOTTOM
	var p := [Vector2(-w, cb), Vector2(-w + cb, 0), Vector2(w - cb, 0), Vector2(w, cb), Vector2(w, h - ct), Vector2(w - ct, h),
		Vector2(-w + ct, h), Vector2(-w, h - ct)]
	return [[p[0], p[1]], [p[2], p[3]], [p[3], p[4]], [p[4], p[5]], [p[5], p[6]], [p[6], p[7]], [p[7], p[0]]]


## An octagonal frame round a corridor at local z = 0 of `x`: heavy bronze-edged beams on every side
## but the floor, with a threshold plate across it.
static func _octagon_frame(b: Models.Batch, x: Transform3D, m: Dictionary) -> void:
	var centre := Vector2(0, OutpostLayout.CORRIDOR_H * 0.5)
	for e: Array in _octagon_edges():
		var a: Vector2 = e[0]
		var f: Vector2 = e[1]
		var dir := (f - a).normalized()
		var inward := Vector2(-dir.y, dir.x)
		if inward.dot(centre - (a + f) * 0.5) < 0.0:
			inward = -inward
		var mid := (a + f) * 0.5 + inward * FRAME_T * 0.5
		var basis := Basis(Vector3(0, 0, 1), atan2(dir.y, dir.x))
		b.box_at(x * Transform3D(basis, Vector3(mid.x, mid.y, 0)), Vector3(a.distance_to(f) + 0.12, FRAME_T, FRAME_D), m["olive"])
		var edge := (a + f) * 0.5 + inward * (FRAME_T + 0.02)
		b.box_at(x * Transform3D(basis, Vector3(edge.x, edge.y, 0)), Vector3(a.distance_to(f) + 0.1, 0.05, FRAME_D + 0.06), m["bronze"])
	var w := OutpostLayout.CELL * 0.5 - OutpostLayout.WALL_T * 0.5
	b.box(x * Vector3(0, 0.012, 0), Vector3(2.0 * (w - CHAMFER_BOTTOM), 0.025, FRAME_D) if x.basis.z.z != 0.0 \
		else Vector3(FRAME_D, 0.025, 2.0 * (w - CHAMFER_BOTTOM)), m["yellow"])
	# Bolts on the wall beams.
	for side: float in [-1.0, 1.0]:
		for y: float in [0.8, 1.6, 2.4]:
			b.cyl_at(x * Transform3D(Basis(Vector3(0, 0, 1), PI / 2.0), Vector3(side * (w - FRAME_T - 0.02), y, 0.0)), 0.035, 0.05, m["bronze"], -1.0, 8)


## A flat panel along the corridor over the octagon side a-b (a chamfer), `length` long.
static func _panel_along(b: Models.Batch, x: Transform3D, a: Vector2, e: Vector2, length: float, mat: Material) -> void:
	var dir := (e - a).normalized()
	var mid := (a + e) * 0.5
	b.box_at(x * Transform3D(Basis(Vector3(0, 0, 1), atan2(dir.y, dir.x)), Vector3(mid.x, mid.y, 0)), Vector3(a.distance_to(e), 0.04, length), mat)


## A caged lamp on a corridor's ceiling (`at`: the ceiling point). With a generator it waits for its
## power; without one it is one of the failing lamps (some dead, some flickering).
static func _hall_lamp(root: Derelict, b: Models.Batch, at: Vector3, across_x: bool, m: Dictionary, rng: RandomNumberGenerator,
		powered: bool, c: Vector2i) -> void:
	var size := Vector3(0.3, 0.12, 0.6) if across_x else Vector3(0.6, 0.12, 0.3)
	b.box(at + Vector3(0, -0.06, 0), size + Vector3(0.08, 0, 0.08), m["steel"])
	for i in 3:
		var off := (i - 1) * 0.12
		b.box(at + Vector3(off if across_x else 0.0, -0.17, 0.0 if across_x else off), Vector3(0.025, 0.08, size.z) if across_x else Vector3(size.x, 0.08, 0.025), m["dark"])
	var circuit := Derelict.POWER if powered else Derelict.ALWAYS
	if rng.randf() < (0.12 if powered else 0.3):
		circuit = Derelict.DEAD
	root.add_lamp(at + Vector3(0, -0.14, 0), size - Vector3(0.06, 0.04, 0.06), LAMP_COLOR, rng.randf_range(1.0, 1.35), 6.5, circuit,
		c, rng.randf() < (0.2 if powered else 0.45), rng)
	if powered and rng.randf() < 0.35:
		_emergency_lamp(root, b, at + Vector3(0, -0.25, 0), Vector3.DOWN, m, rng, powered, c)


## A small red emergency lamp on a surface (`facing`: out of it). With a generator it goes out once
## the power is back.
static func _emergency_lamp(root: Derelict, b: Models.Batch, at: Vector3, facing: Vector3, m: Dictionary, rng: RandomNumberGenerator,
		powered: bool, c: Vector2i) -> void:
	b.box(at, Vector3(0.22, 0.14, 0.22), m["dark"])
	root.add_lamp(at + facing * 0.1, Vector3(0.14, 0.08, 0.14), EMERGENCY_COLOR, 0.55, 4.5,
		Derelict.EMERGENCY if powered else Derelict.ALWAYS, c, rng.randf() < 0.3, rng)


## A room: ribbed walls with pilasters, beams under the ceiling, lamps, its furniture, signs over its
## doorways (on the corridor side) and a little debris and alien growth.
static func _build_room(root: Derelict, b: Models.Batch, body: StaticBody3D, layout: Dictionary, ri: int, m: Dictionary,
		rng: RandomNumberGenerator, powered: bool, out: Dictionary) -> void:
	var room: Dictionary = layout["rooms"][ri]
	var h := float(room["h"])
	var deck := StationBuilder.DECK_Y
	var cell := OutpostLayout.CELL
	var cells: Array = room["cells"]
	# Ribbed lower panels and a cornice along each stretch of wall, pilasters where they meet.
	var pilasters := {}
	for s: Dictionary in OutpostLayout.wall_slots(layout, ri):
		var inward: Vector3 = s["inward"]
		var along := Vector3(inward.z, 0, -inward.x)
		var p: Vector3 = s["pos"]
		for r in 4:
			b.box(p + inward * 0.03 + Vector3(0, 0.2 + r * 0.26, 0), _along_size(along, cell - 0.3, 0.07, 0.06), m["olive"])
		b.box(p + inward * 0.04 + Vector3(0, 1.22, 0), _along_size(along, cell - 0.3, 0.06, 0.08), m["bronze"])
		b.box(p + inward * 0.06 + Vector3(0, h - 0.3, 0), _along_size(along, cell, 0.22, 0.12), m["steel"])
		for side: float in [-1.0, 1.0]:
			var q := p + along * side * cell * 0.5
			var key := Vector2i(roundi(q.x * 10.0), roundi(q.z * 10.0))
			if pilasters.has(key):
				continue
			pilasters[key] = true
			b.box(q + inward * 0.09 + Vector3(0, h * 0.5, 0), Vector3(0.3, h, 0.3) if absf(inward.x) < 0.5 else Vector3(0.3, h, 0.3), m["olive"])
			b.box(q + inward * 0.25 + Vector3(0, h * 0.5, 0), _along_size(along, 0.12, h, 0.04), m["bronze"])
	# Beams under the ceiling across every cell boundary along z inside the room.
	for c: Vector2i in cells:
		var n := c + Vector2i(0, 1)
		if n in cells:
			var p := OutpostLayout.cell_pos(c) + Vector3(0, h - 0.2, cell * 0.5)
			b.box(p, Vector3(cell + 0.02, 0.4, 0.3), m["olive"])
			b.box(p + Vector3(0, -0.21, 0), Vector3(cell + 0.02, 0.04, 0.34), m["bronze"])
	# Lamps: up to three over the core, spread out; one gets a light.
	var core: Rect2i = room["core"]
	var spots: Array[Vector2i] = []
	for i in core.size.x:
		for j in core.size.y:
			if (i + j) % 2 == 0 and (i % 2 == 0):
				spots.append(core.position + Vector2i(i, j))
	OutpostLayout._shuffle(spots, rng)
	var lamps := mini(spots.size(), 2 + (1 if core.get_area() > 12 else 0))
	for i in lamps:
		var lp := OutpostLayout.cell_pos(spots[i]) + Vector3(0, h, 0)
		_room_lamp(root, b, lp, m, rng, powered, spots[i], str(room["theme"]) == "generator")
	if powered:
		# A dim emergency lamp by the room's first doorway, so it can be found in the dark.
		var dd: Dictionary = layout["doors"][(room["doors"] as Array)[0]]
		var ep := DerelictBuilder.door_inside(dd, 0.25) + Vector3(0, OutpostLayout.DOOR_H + 0.35, 0)
		_emergency_lamp(root, b, ep, -(dd["normal"] as Vector3), m, rng, powered, dd["cell"])
	# Furniture.
	for p: Dictionary in room["props"]:
		OutpostProps.build(root, b, body, p, m, out)
	# Signs over the doorways (above their frames), on the corridor side.
	for di: int in room["doors"]:
		var dd: Dictionary = layout["doors"][di]
		var n: Vector3 = dd["normal"]
		var sp := (dd["pos"] as Vector3) + n * (OutpostLayout.WALL_T * 0.5 + 0.04) + Vector3(0, OutpostLayout.DOOR_H + 0.47, 0)
		b.box(sp - n * 0.015, _along_size(Vector3(n.z, 0, -n.x), 1.3, 0.2, 0.03), m["dark"])
		_label(root, str(room["name"]), sp + n * 0.004, 32, 0.0042, Color(0.92, 0.72, 0.38), atan2(n.x, n.z))
	# Debris on the floor and alien growth in a corner.
	var free := OutpostLayout.free_cells(room)
	for i in rng.randi_range(2, 5):
		var c: Vector2i = free[rng.randi() % free.size()] if not free.is_empty() else cells[0]
		var p := OutpostLayout.cell_pos(c) + Vector3(rng.randf_range(-1.0, 1.0), 0.06, rng.randf_range(-1.0, 1.0))
		b.box(p, Vector3(rng.randf_range(0.2, 0.7), 0.1, rng.randf_range(0.2, 0.9)), m["mid"] if i % 2 == 0 else m["rust"],
			Vector3(0, rng.randf_range(0, 180), rng.randf_range(-8, 8)))
	if rng.randf() < 0.5 or str(room["theme"]) == "vault":
		var slots := OutpostLayout.wall_slots(layout, ri)
		var s: Dictionary = slots[rng.randi() % slots.size()]
		_growth(root, (s["pos"] as Vector3) + Vector3(0, rng.randf_range(0.3, 2.5), 0), s["inward"], m, rng, 1.1)


## A box `length` long along `along` (x or z), `height` tall and `depth` deep across it.
static func _along_size(along: Vector3, length: float, height: float, depth: float) -> Vector3:
	return Vector3(length, height, depth) if absf(along.x) > 0.5 else Vector3(depth, height, length)


## A hanging industrial lamp over a room (`at`: the ceiling point).
static func _room_lamp(root: Derelict, b: Models.Batch, at: Vector3, m: Dictionary, rng: RandomNumberGenerator, powered: bool,
		c: Vector2i, emergency_too: bool) -> void:
	var drop := 0.9
	b.box(at + Vector3(0, -drop * 0.5, 0), Vector3(0.04, drop, 0.04), m["dark"])
	b.cyl_at(Transform3D(Basis.IDENTITY, at + Vector3(0, -drop - 0.12, 0)), 0.45, 0.3, m["olive"], 0.12, 12)
	var circuit := Derelict.POWER if powered else Derelict.ALWAYS
	if rng.randf() < (0.1 if powered else 0.25):
		circuit = Derelict.DEAD
	root.add_lamp(at + Vector3(0, -drop - 0.28, 0), Vector3(0.36, 0.06, 0.36), LAMP_COLOR, rng.randf_range(2.2, 2.8), 10.5, circuit, c,
		rng.randf() < (0.2 if powered else 0.45), rng)
	if emergency_too:
		root.add_lamp(at + Vector3(0.6, -0.1, 0), Vector3(0.18, 0.08, 0.18), EMERGENCY_COLOR, 0.8, 7.0, Derelict.ALWAYS, c, true, rng)


## Doorways: a heavy frame on both faces of every doorway; sealed doors get their door (sliding up
## into the wall), a lamp over it on the corridor side, and a keypad lock its keypad and lockdown
## shutter. Some open doorways have a door jammed half way up.
static func _build_doors(root: Derelict, b: Models.Batch, layout: Dictionary, m: Dictionary, rng: RandomNumberGenerator) -> void:
	var doors: Array = layout["doors"]
	var deck := StationBuilder.DECK_Y
	var dw := OutpostLayout.DOOR_W * 0.5
	var dh := OutpostLayout.DOOR_H
	for di in range(1, doors.size()):
		var d: Dictionary = doors[di]
		var n: Vector3 = d["normal"]
		var t := Vector3(n.z, 0, -n.x)
		var pos: Vector3 = d["pos"]
		var yaw := atan2(n.x, n.z)
		for face: float in [-1.0, 1.0]:
			var fp := pos + n * face * (OutpostLayout.WALL_T * 0.5 + 0.06)
			var x := Transform3D(Basis(Vector3.UP, yaw if face > 0.0 else yaw + PI), fp)
			for side: float in [-1.0, 1.0]:
				b.box(x * Vector3(side * (dw + 0.14), dh * 0.5, 0), Vector3(0.3, dh, 0.14), m["gunmetal"])
				b.box(x * Vector3(side * (dw + 0.02), dh * 0.5, 0.05), Vector3(0.06, dh - 0.1, 0.06), m["bronze"])
				for y: float in [0.5, 1.4, 2.3]:
					b.cyl_at(x * Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(side * (dw + 0.2), y, 0.08)), 0.035, 0.05, m["bronze"], -1.0, 8)
			b.box(x * Vector3(0, dh + 0.17, 0), Vector3(OutpostLayout.DOOR_W + 0.88, 0.34, 0.16), m["gunmetal"])
			for i in 7:
				b.box(x * Vector3(-dw - 0.2 + i * (OutpostLayout.DOOR_W + 0.4) / 6.0, dh + 0.17, 0.09), Vector3(0.16, 0.26, 0.01), m["yellow"] if i % 2 == 0 else m["black"],
					Vector3(0, rad_to_deg(yaw if face > 0.0 else yaw + PI), 30))
		var kind := str(d["kind"])
		if kind == "open":
			if rng.randf() < 0.22:
				# A door jammed most of the way up.
				var stuck := rng.randf_range(0.78, 0.9)
				_door_slab(b, Transform3D(Basis(Vector3.UP, yaw), pos + Vector3(0, dh * stuck, 0)), m)
			continue
		var slab := Node3D.new()
		slab.transform = Transform3D(Basis(Vector3.UP, yaw), pos)
		root.add_child(slab)
		var sb := Models.Batch.new()
		_door_slab(sb, Transform3D.IDENTITY, m)
		sb.commit(slab, "Door")
		var sbody := StaticBody3D.new()
		sbody.collision_layer = Game.LAYER_CAVE | Game.LAYER_STATION
		sbody.collision_mask = 0
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(OutpostLayout.DOOR_W + 0.1, dh, 0.3)
		cs.shape = shape
		cs.position = Vector3(0, dh * 0.5, 0)
		sbody.add_child(cs)
		sbody.transform = Transform3D(Basis(Vector3.UP, yaw), pos)
		root.add_child(sbody)
		# The status lamp over the door, on the corridor side.
		var lamp_mat := StandardMaterial3D.new()
		lamp_mat.albedo_color = Color(0.1, 0.02, 0.02)
		lamp_mat.emission_enabled = true
		lamp_mat.emission = Color(1.0, 0.1, 0.05)
		lamp_mat.emission_energy_multiplier = 3.0
		var lp := pos + n * (OutpostLayout.WALL_T * 0.5 + 0.2) + Vector3(0, dh + 0.62, 0) + t * 0.85
		b.box(lp - n * 0.08, Vector3(0.24, 0.24, 0.16) if absf(n.x) < 0.5 else Vector3(0.16, 0.24, 0.24), m["dark"])
		Models.sphere(root, lp, 0.08, lamp_mat)
		var rec := {"slab": slab, "body": sbody, "shape": cs, "lamp": lamp_mat, "pos": pos, "normal": n}
		if kind == "power":
			_label(slab, "NO POWER", Vector3(0, 1.75, SLAB_T * 0.5 + 0.035), 44, 0.006, Color(1.0, 0.75, 0.25), 0.0)
		else:
			_lockdown_gear(root, b, d, rec, m)
			var panel := HackPanel.new()
			root.add_child(panel)
			panel.transform = _keypad_spot(layout, d)
			panel.build(d, di, m)
			rec["panel"] = panel
		root.add_door(di, rec)


## A door's slab (frame `x` at the doorway's middle on the floor, facing out): ribbed steel with
## chevrons along its bottom edge.
static func _door_slab(b: Models.Batch, x: Transform3D, m: Dictionary) -> void:
	var w := OutpostLayout.DOOR_W + 0.1
	var dh := OutpostLayout.DOOR_H
	b.box(x * Vector3(0, dh * 0.5, 0), Vector3(w, dh, SLAB_T), m["gunmetal"])
	for side: float in [-1.0, 1.0]:
		for r in 6:
			b.box(x * Vector3(0, 0.5 + r * 0.38, side * (SLAB_T * 0.5 + 0.015)), Vector3(w - 0.3, 0.1, 0.03), m["olive"])
		for i in 5:
			b.box(x * Vector3(-w * 0.4 + i * w * 0.2, 0.16, side * (SLAB_T * 0.5 + 0.01)), Vector3(0.22, 0.24, 0.02), m["yellow"] if i % 2 == 0 else m["black"],
				Vector3(0, 0, 35))
		b.box(x * Vector3(0, dh * 0.5, side * (SLAB_T * 0.5 + 0.02)), Vector3(0.06, dh - 0.4, 0.02), m["bronze"])


## A keypad lock's lockdown gear on the corridor side: the shutter (hidden up in the ceiling until
## it drops), its guide rails and housing, and the red alarm light that flashes in a lockdown.
static func _lockdown_gear(root: Derelict, b: Models.Batch, d: Dictionary, rec: Dictionary, m: Dictionary) -> void:
	var n: Vector3 = d["normal"]
	var pos: Vector3 = d["pos"]
	var yaw := atan2(n.x, n.z)
	var dh := OutpostLayout.DOOR_H
	var sw := OutpostLayout.DOOR_W + 0.6
	var x := Transform3D(Basis(Vector3.UP, yaw), pos + n * SHUTTER_OUT)
	for side: float in [-1.0, 1.0]:
		b.box(x * Vector3(side * (sw * 0.5 + 0.06), dh * 0.5 + 0.2, 0), Vector3(0.12, dh + 0.4, 0.3), m["steel"])
	b.box(x * Vector3(0, OutpostLayout.CORRIDOR_H - 0.12, 0), Vector3(sw + 0.3, 0.24, 0.36), m["gunmetal"])
	var shutter := Node3D.new()
	shutter.transform = x
	root.add_child(shutter)
	var sb := Models.Batch.new()
	sb.box(Vector3(0, (dh + 0.25) * 0.5, 0), Vector3(sw, dh + 0.25, 0.22), m["gunmetal"])
	for r in 7:
		sb.box(Vector3(0, 0.3 + r * 0.42, 0.12), Vector3(sw - 0.2, 0.16, 0.04), m["steel"])
	for i in 6:
		sb.box(Vector3(-sw * 0.42 + i * sw * 0.168, 0.18, 0.12), Vector3(0.26, 0.3, 0.02), m["yellow"] if i % 2 == 0 else m["black"], Vector3(0, 0, 35))
	sb.commit(shutter, "Shutter")
	var sbody := StaticBody3D.new()
	sbody.collision_layer = Game.LAYER_CAVE | Game.LAYER_STATION
	sbody.collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(sw, dh + 0.25, 0.3)
	cs.shape = shape
	cs.position = Vector3(0, (dh + 0.25) * 0.5, 0)
	cs.disabled = true
	sbody.add_child(cs)
	sbody.transform = x
	root.add_child(sbody)
	var alarm := OmniLight3D.new()
	alarm.light_color = Color(1.0, 0.08, 0.04)
	alarm.light_energy = 0.0
	alarm.omni_range = 9.0
	alarm.position = pos + n * 1.6 + Vector3(0, 2.6, 0)
	alarm.visible = false
	root.add_child(alarm)
	rec["shutter"] = shutter
	rec["shutter_rest"] = x
	rec["shutter_shape"] = cs
	rec["alarm"] = alarm


## Where a keypad lock's keypad hangs (facing into the corridor): on the wall carrying on beside the
## doorway, or failing that on a side wall of the corridor cell in front of it, near the door.
static func _keypad_spot(layout: Dictionary, d: Dictionary) -> Transform3D:
	var cell: Vector2i = d["cell"]
	var out: Vector2i = d["out"]
	var dn: Vector2i = out - cell
	var n := Vector3(dn.x, 0, dn.y)
	var tv := Vector2i(dn.y, -dn.x)
	var t := Vector3(tv.x, 0, tv.y)
	var face := OutpostLayout.CELL * 0.5 - OutpostLayout.WALL_T * 0.5
	var y := StationBuilder.DECK_Y + 1.25
	for s: int in [1, -1]:
		var o2: Vector2i = out + tv * s
		var c2: Vector2i = cell + tv * s
		if _walkable(layout, o2) and _open_edge(layout, out, o2) and not _open_edge(layout, c2, o2) and _door_between(layout, c2, o2) < 0:
			var p := (d["pos"] as Vector3) + t * s * (OutpostLayout.CELL * 0.5 + 0.55) + n * (OutpostLayout.WALL_T * 0.5 + 0.02)
			return Transform3D(Basis(Vector3.UP, atan2(n.x, n.z)), Vector3(p.x, y, p.z))
	for s: int in [1, -1]:
		var o2: Vector2i = out + tv * s
		if not _open_edge(layout, out, o2) and _door_between(layout, out, o2) < 0:
			var inward := -t * s
			var p := OutpostLayout.cell_pos(out) + t * s * face - n * (OutpostLayout.CELL * 0.5 - 0.75)
			return Transform3D(Basis(Vector3.UP, atan2(inward.x, inward.z)), Vector3(p.x, y, p.z))
	var p := (d["pos"] as Vector3) + n * 1.2 + t * 1.0
	return Transform3D(Basis(Vector3.UP, atan2(-t.x, -t.z)), Vector3(p.x, y, p.z))
