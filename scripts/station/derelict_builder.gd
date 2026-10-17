class_name DerelictBuilder
extends RefCounted
## Abandoned stations (derelicts): a hangar cut into the cave wall with a landing pad, a pier from
## the ship's cargo ramp to the station's front wall, and behind it a procedurally generated
## complex of rooms joined by corridors. Landing there is optional. The rooms hold salvage crates
## and hostile aliens, which the mothership spawns when it lands (Mothership._derelict_contents).
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
## Rooms sit on a grid of CELL-sized squares: columns -COLS..COLS along the tunnel and ROWS rows
## going into the rock, starting ENTRY_LEN behind the front wall. Doorways and corridors are DOOR_W
## wide and DOOR_H tall.
const CELL := 13.0
const COLS := 1
const ROWS := 3
const ENTRY_LEN := 5.0
const ROOMS_MIN := 4
const ROOMS_MAX := 7
const ROOM_MIN := Vector2(7.5, 7.0)
const ROOM_MAX := Vector2(10.5, 10.0)
const ROOM_H := 4.0
const DOOR_W := 2.6
const DOOR_H := 3.0
const WALL_T := 0.3
## Chance of an extra corridor between two neighbouring rooms (making loops).
const LOOP_CHANCE := 0.3
## Rock is carved this far around the rooms.
const CARVE_MARGIN := 2.0
## Room walls: FRONT faces the hangar (-z), BACK is deeper in (+z), LEFT is -x, RIGHT is +x.
enum Side { FRONT, BACK, LEFT, RIGHT }
## Furniture along the walls: width along the wall, height, depth.
const PROPS := {
	"shelf": Vector3(1.8, 2.4, 0.8), "console": Vector3(1.4, 1.1, 0.7), "locker": Vector3(0.9, 2.1, 0.6),
	"crates": Vector3(1.6, 1.4, 1.0), "bunk": Vector3(1.9, 1.5, 0.95),
}
const ROOM_NAMES := ["STORAGE", "CREW QUARTERS", "MESS HALL", "MED BAY", "WORKSHOP", "LAB", "CONTROL ROOM",
	"REACTOR", "COMMS", "ORE PROCESSING"]
const NAMES := ["VESTA", "KEPLER", "HADES", "CERES", "ORPHEUS", "TALOS", "ICARUS", "BOREAS", "LETHE", "NEREID",
	"PALLAS", "HYGIEA"]


# --- Layout (maths only) -----------------------------------------------------------------------

## Lay out the rooms and corridors. Rooms: {"cell", "c" (centre x, z), "size" (x, z), "doors"
## [{"side", "at" (position along the wall)}], "props" [{"kind", "pos", "yaw", "size"}], "spots"
## [{"pos", "yaw"}] (free floor by the walls for salvage), "name"}. Corridors: {"from", "to",
## "axis" (0 = along x, 2 = along z), "a", "b"} where a and b are [room, door] (room -1 = the
## entrance in the front wall). "vault" is the room farthest from the entrance.
static func generate(rng: RandomNumberGenerator) -> Dictionary:
	var want := rng.randi_range(ROOMS_MIN, ROOMS_MAX)
	var cells := {Vector2i(0, 0): 0}
	var order: Array[Vector2i] = [Vector2i(0, 0)]
	var links: Array = []
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for attempt in 300:
		if order.size() >= want:
			break
		var from: Vector2i = order[rng.randi() % order.size()]
		var to := from + dirs[rng.randi() % dirs.size()]
		if absi(to.x) > COLS or to.y < 0 or to.y >= ROWS or cells.has(to):
			continue
		cells[to] = order.size()
		order.append(to)
		links.append([cells[from], cells[to]])
	for i in order.size():
		for step: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
			var j := int(cells.get(order[i] + step, -1))
			if j < 0 or _linked(links, i, j) or rng.randf() > LOOP_CHANCE:
				continue
			links.append([i, j])
	var names: Array = ROOM_NAMES.duplicate()
	for i in range(names.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var t: Variant = names[i]
		names[i] = names[j]
		names[j] = t
	var rooms: Array = []
	for i in order.size():
		var cell := order[i]
		var size := Vector2(rng.randf_range(ROOM_MIN.x, ROOM_MAX.x), rng.randf_range(ROOM_MIN.y, ROOM_MAX.y))
		var c := Vector2(cell.x * CELL + rng.randf_range(-1.0, 1.0) * (CELL - size.x) * 0.25,
			FACADE_Z + ENTRY_LEN + CELL * 0.5 + cell.y * CELL + rng.randf_range(-1.0, 1.0) * (CELL - size.y) * 0.25)
		rooms.append({"cell": cell, "c": c, "size": size, "doors": [], "props": [], "spots": [], "name": names[i % names.size()]})
	# The entrance corridor from the front wall to the first room, then one per link.
	var corridors: Array = [{"from": Vector3(0, StationBuilder.DECK_Y, FACADE_Z),
		"to": Vector3(0, StationBuilder.DECK_Y, _z0(rooms[0])), "axis": 2, "a": [-1, 0], "b": [0, _add_door(rooms[0], Side.FRONT, 0.0)]}]
	for l: Array in links:
		var ia: int = l[0]
		var ib: int = l[1]
		var ca: Vector2i = rooms[ia]["cell"]
		var cb: Vector2i = rooms[ib]["cell"]
		if ca.y == cb.y:
			# Side by side: a corridor along x.
			var left := ia if ca.x < cb.x else ib
			var right := ib if left == ia else ia
			var lo := maxf(_z0(rooms[left]), _z0(rooms[right])) + 0.5 + DOOR_W * 0.5
			var hi := minf(_z1(rooms[left]), _z1(rooms[right])) - 0.5 - DOOR_W * 0.5
			var at := (lo + hi) * 0.5
			corridors.append({"from": Vector3(_x1(rooms[left]), StationBuilder.DECK_Y, at),
				"to": Vector3(_x0(rooms[right]), StationBuilder.DECK_Y, at), "axis": 0,
				"a": [left, _add_door(rooms[left], Side.RIGHT, at)], "b": [right, _add_door(rooms[right], Side.LEFT, at)]})
		else:
			# One behind the other: a corridor along z.
			var front := ia if ca.y < cb.y else ib
			var back := ib if front == ia else ia
			var lo := maxf(_x0(rooms[front]), _x0(rooms[back])) + 0.5 + DOOR_W * 0.5
			var hi := minf(_x1(rooms[front]), _x1(rooms[back])) - 0.5 - DOOR_W * 0.5
			var at := (lo + hi) * 0.5
			corridors.append({"from": Vector3(at, StationBuilder.DECK_Y, _z1(rooms[front])),
				"to": Vector3(at, StationBuilder.DECK_Y, _z0(rooms[back])), "axis": 2,
				"a": [front, _add_door(rooms[front], Side.BACK, at)], "b": [back, _add_door(rooms[back], Side.FRONT, at)]})
	# The vault: the room the most corridors away from the entrance.
	var dist: Array[int] = []
	dist.resize(rooms.size())
	dist.fill(-1)
	dist[0] = 0
	var queue: Array[int] = [0]
	while not queue.is_empty():
		var r: int = queue.pop_front()
		for l: Array in links:
			var other := -1
			if int(l[0]) == r:
				other = int(l[1])
			elif int(l[1]) == r:
				other = int(l[0])
			if other >= 0 and dist[other] < 0:
				dist[other] = dist[r] + 1
				queue.append(other)
	var vault := 0
	for i in rooms.size():
		if dist[i] >= dist[vault]:
			vault = i
	rooms[vault]["name"] = "SECURE STORAGE"
	for room: Dictionary in rooms:
		_furnish(room, rng)
	var lo := Vector3(INF, StationBuilder.DECK_Y - 1.2, FACADE_Z - 1.0)
	var hi := Vector3(-INF, StationBuilder.DECK_Y + ROOM_H + 1.2, -INF)
	for room: Dictionary in rooms:
		lo.x = minf(lo.x, _x0(room) - CARVE_MARGIN)
		hi.x = maxf(hi.x, _x1(room) + CARVE_MARGIN)
		hi.z = maxf(hi.z, _z1(room) + CARVE_MARGIN)
	var title := "%s-%d OUTPOST" % [NAMES[rng.randi() % NAMES.size()], rng.randi_range(2, 19)]
	return {"rooms": rooms, "corridors": corridors, "links": links, "vault": vault, "carve_min": lo, "carve_max": hi,
		"name": title}


static func _linked(links: Array, a: int, b: int) -> bool:
	for l: Array in links:
		if (int(l[0]) == a and int(l[1]) == b) or (int(l[0]) == b and int(l[1]) == a):
			return true
	return false


## Add a doorway to a room; returns its index in the room's door list.
static func _add_door(room: Dictionary, side: int, at: float) -> int:
	var doors: Array = room["doors"]
	doors.append({"side": side, "at": at})
	return doors.size() - 1


static func _x0(room: Dictionary) -> float:
	return (room["c"] as Vector2).x - (room["size"] as Vector2).x * 0.5


static func _x1(room: Dictionary) -> float:
	return (room["c"] as Vector2).x + (room["size"] as Vector2).x * 0.5


static func _z0(room: Dictionary) -> float:
	return (room["c"] as Vector2).y - (room["size"] as Vector2).y * 0.5


static func _z1(room: Dictionary) -> float:
	return (room["c"] as Vector2).y + (room["size"] as Vector2).y * 0.5


## Wall `side` of a room: [fixed coordinate (z for front/back, x for left/right), inward normal].
static func _wall_line(room: Dictionary, side: int) -> Array:
	match side:
		Side.FRONT:
			return [_z0(room), Vector3(0, 0, 1)]
		Side.BACK:
			return [_z1(room), Vector3(0, 0, -1)]
		Side.LEFT:
			return [_x0(room), Vector3(1, 0, 0)]
	return [_x1(room), Vector3(-1, 0, 0)]


## Station-local floor point on wall `side` at `along` (x for front/back walls, z for side walls),
## `inset` metres into the room.
static func _wall_point(room: Dictionary, side: int, along: float, inset: float) -> Vector3:
	var wl := _wall_line(room, side)
	var p := Vector3(along, StationBuilder.DECK_Y, float(wl[0])) if side <= Side.BACK else Vector3(float(wl[0]), StationBuilder.DECK_Y, along)
	return p + (wl[1] as Vector3) * inset


## The floor point just inside a doorway (a waypoint).
static func door_inside(room: Dictionary, door: Dictionary) -> Vector3:
	return _wall_point(room, int(door["side"]), float(door["at"]), 1.0)


## Furniture and salvage spots in slots along the walls, clear of the doorways and the corners.
static func _furnish(room: Dictionary, rng: RandomNumberGenerator) -> void:
	var c: Vector2 = room["c"]
	var size: Vector2 = room["size"]
	var kinds := PROPS.keys()
	for side in 4:
		var length := size.x if side <= Side.BACK else size.y
		var mid := c.x if side <= Side.BACK else c.y
		var n := int((length - 1.6) / 2.1)
		var inward: Vector3 = _wall_line(room, side)[1]
		# Furniture faces into the room; crates lie along the wall.
		var yaw := atan2(inward.x, inward.z)
		for i in n:
			var along := mid + (i - (n - 1) * 0.5) * 2.1
			var clear := true
			for door: Dictionary in room["doors"]:
				if int(door["side"]) == side and absf(float(door["at"]) - along) < DOOR_W * 0.5 + 1.3:
					clear = false
			if not clear:
				continue
			var r := rng.randf()
			if r < 0.34:
				var kind: String = kinds[rng.randi() % kinds.size()]
				var ps: Vector3 = PROPS[kind]
				(room["props"] as Array).append({"kind": kind, "size": ps, "yaw": yaw,
					"pos": _wall_point(room, side, along, WALL_T * 0.5 + ps.z * 0.5 + 0.02)})
			elif r < 0.7:
				(room["spots"] as Array).append({"pos": _wall_point(room, side, along, WALL_T * 0.5 + 0.5), "yaw": yaw})


# --- Navigation --------------------------------------------------------------------------------

## Waypoint graph for walking around the station: the pier, the doorways and the middle of every
## room, in ship-local coordinates of a ship landed there. Given the mothership's interior layout
## (ShipInteriors), its waypoints are linked in through its cargo ramp (for crew bots); with {} the
## graph covers just the station and its pier (for the aliens living there).
static func build_nav(d: Dictionary, ship_interior: Dictionary) -> AStar3D:
	var astar := AStar3D.new()
	var lift := Vector3(0, StationBuilder.LAND_HEIGHT, 0)
	var layout: Dictionary = d["layout"]
	var rooms: Array = layout["rooms"]
	var pier0 := _point(astar, Vector3(0, StationBuilder.DECK_Y, StationBuilder.PIER_START + 0.8) - lift)
	var pier1 := _point(astar, Vector3(0, StationBuilder.DECK_Y, FACADE_Z - 1.0) - lift)
	var gate := _point(astar, Vector3(0, StationBuilder.DECK_Y, FACADE_Z + 1.2) - lift)
	astar.connect_points(pier0, pier1)
	astar.connect_points(pier1, gate)
	var doors := {}
	for i in rooms.size():
		var room: Dictionary = rooms[i]
		var c: Vector2 = room["c"]
		var center := _point(astar, Vector3(c.x, StationBuilder.DECK_Y, c.y) - lift)
		var mine: Array[int] = []
		var list: Array = room["doors"]
		for j in list.size():
			var id := _point(astar, door_inside(room, list[j]) - lift)
			doors[Vector2i(i, j)] = id
			astar.connect_points(center, id)
			for other in mine:
				astar.connect_points(other, id)
			mine.append(id)
	for cor: Dictionary in layout["corridors"]:
		var a: Array = cor["a"]
		var b: Array = cor["b"]
		var ia: int = gate if int(a[0]) < 0 else int(doors[Vector2i(a[0], a[1])])
		astar.connect_points(ia, int(doors[Vector2i(b[0], b[1])]))
	if not ship_interior.is_empty():
		var ids := ShipInteriors.add_to_nav(astar, ship_interior)
		var ramp := _point(astar, Vector3(0, 0, 11.4))
		astar.connect_points(ids[ship_interior["exit"]], ramp)
		astar.connect_points(ramp, pier0)
	return astar


static func _point(astar: AStar3D, p: Vector3) -> int:
	var id := astar.get_available_point_id()
	astar.add_point(id, p)
	return id


# --- Nodes -------------------------------------------------------------------------------------

## Build the station's visuals and collision under `parent` (which must sit at the world origin).
static func build(parent: Node3D, d: Dictionary) -> Derelict:
	var root := Derelict.new()
	root.name = "Derelict%d" % int(d["k"])
	root.k = int(d["k"])
	root.transform = d["xform"]
	parent.add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(d["seed"])
	var m := {
		"wall": Models.panel_mat(Color(0.36, 0.37, 0.38), 0.4, 0.65, 0.35),
		"inner": Models.panel_mat(Color(0.46, 0.47, 0.47), 0.25, 0.7, 0.45),
		"floor": Models.panel_mat(Color(0.2, 0.21, 0.22), 0.45, 0.7, 0.5),
		"ceiling": Models.panel_mat(Color(0.22, 0.23, 0.25), 0.3, 0.7, 0.5),
		"dark": Models.mat(Color(0.1, 0.1, 0.11), 0.5, 0.7),
		"mid": Models.mat(Color(0.27, 0.27, 0.28), 0.6, 0.55),
		"rust": Models.mat(Color(0.34, 0.2, 0.12), 0.3, 0.85),
		"yellow": Models.mat(Color(0.7, 0.55, 0.12), 0.3, 0.7),
		"black": Models.mat(Color(0.06, 0.06, 0.06), 0.4, 0.7),
		"crate": Models.panel_mat(Color(0.3, 0.33, 0.27), 0.2, 0.8, 1.0),
		"dead_glass": Models.mat(Color(0.05, 0.07, 0.09), 0.6, 0.15),
		"amber": Models.emissive(Color(1.0, 0.55, 0.15), 2.5),
		"red": Models.emissive(Color(1.0, 0.12, 0.06), 3.0),
		"screen": Models.emissive(Color(0.25, 0.7, 0.55), 0.7, Color(0.02, 0.03, 0.03)),
		"goo": Alien.organic(Color(0.16, 0.07, 0.18), Color(0.6, 1.0, 0.25), 1.2, 5.0),
	}
	var b := Models.Batch.new()
	var body := StaticBody3D.new()
	body.collision_layer = Game.LAYER_CAVE | Game.LAYER_STATION
	body.collision_mask = 0
	root.add_child(body)
	_build_pad(root, b, m, rng)
	_build_facade(root, b, body, d, m, rng)
	_build_pier(root, b, m)
	var layout: Dictionary = d["layout"]
	var rooms: Array = layout["rooms"]
	for i in rooms.size():
		_build_room(root, b, body, rooms[i], m, rng, i == int(layout["vault"]))
	for cor: Dictionary in layout["corridors"]:
		_build_corridor(root, b, body, cor, m)
	b.commit(root, "Derelict")
	return root


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


# --- Parts -------------------------------------------------------------------------------------

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
	var dw := DOOR_W * 0.5
	var deck := StationBuilder.DECK_Y
	_block(b, body, Vector3(-hx, y0, z0), Vector3(-dw, y1, z1), m["wall"])
	_block(b, body, Vector3(dw, y0, z0), Vector3(hx, y1, z1), m["wall"])
	_block(b, body, Vector3(-dw, y0, z0), Vector3(dw, deck, z1), m["wall"])
	_block(b, body, Vector3(-dw, deck + DOOR_H, z0), Vector3(dw, y1, z1), m["wall"])
	var fz := z0 - 0.02
	# Ribs, a dead window band and cracked panels.
	for x: float in [-18.0, -10.0, 10.0, 18.0]:
		b.box(Vector3(x, 7.0, fz - 0.25), Vector3(0.9, 18.0, 0.5), m["mid"])
	for side: float in [-1.0, 1.0]:
		b.box(Vector3(side * 14.0, 9.5, fz), Vector3(6.5, 2.0, 0.05), m["dead_glass"])
		b.box(Vector3(side * 5.5, 6.5, fz), Vector3(3.5, 1.2, 0.05), m["dead_glass"])
		for i in 3:
			b.box(Vector3(side * rng.randf_range(3.0, 19.0), rng.randf_range(1.0, 13.0), fz - 0.06),
				Vector3(rng.randf_range(1.0, 2.6), rng.randf_range(0.8, 2.0), 0.08), m["rust"] if i == 0 else m["mid"],
				Vector3(0, 0, rng.randf_range(-12.0, 12.0)))
	# Door frame with hazard stripes, a jammed door panel and a blinking warning light.
	for side: float in [-1.0, 1.0]:
		b.box(Vector3(side * (dw + 0.25), deck + DOOR_H * 0.5, fz - 0.05), Vector3(0.5, DOOR_H, 0.12), m["black"])
		for i in 4:
			b.box(Vector3(side * (dw + 0.25), deck + 0.4 + i * 0.75, fz - 0.12), Vector3(0.52, 0.28, 0.02), m["yellow"], Vector3(0, 0, 35))
	b.box(Vector3(0, deck + DOOR_H + 0.25, fz - 0.05), Vector3(DOOR_W + 1.0, 0.5, 0.12), m["black"])
	_solid(b, body, Vector3(-dw - 0.05, deck + DOOR_H * 0.5, z1 + 0.15), Vector3(0.9, DOOR_H, 0.2), m["mid"])
	Models.sphere(root, Vector3(0, deck + DOOR_H + 0.75, fz - 0.15), 0.22, Models.blink(Color(1.0, 0.15, 0.05), 0.8, 0.0, 0.3))
	# Name board and warnings.
	b.box(Vector3(0, 13.0, fz - 0.1), Vector3(16.0, 2.2, 0.2), m["dark"])
	_label(root, str(d["name"]), Vector3(0, 13.0, fz - 0.25), 150, 0.011, Color(0.85, 0.55, 0.25))
	_label(root, "ABANDONED  -  NO SIGNAL", Vector3(0, 11.4, fz - 0.25), 64, 0.01, Color(0.85, 0.3, 0.25))
	_label(root, "QUARANTINE", Vector3(0, deck + DOOR_H + 1.5, fz - 0.15), 48, 0.008, Color(1.0, 0.85, 0.3))
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
		ShipBuilder.configure_shadow(flood)
		if side > 0.0:
			root.add_flicker(flood, rng.randf_range(0.12, 0.25), rng.randf())
		b.box(housing + Vector3(0, -0.31, -0.2), Vector3(1.3, 0.04, 0.6), m["amber"])
	_omni(root, Vector3(0, deck + DOOR_H + 0.9, fz - 1.0), Color(1.0, 0.2, 0.1), 1.2, 9.0, true, rng)


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
	_solid(b, body, Vector3(0, deck - 0.15, zc), Vector3(PIER_HALF_W * 2.0, 0.3, length), m["floor"])
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


## A room: floor, ceiling, walls with doorways, furniture, a (failing) light and its name.
static func _build_room(root: Derelict, b: Models.Batch, body: StaticBody3D, room: Dictionary, m: Dictionary,
		rng: RandomNumberGenerator, vault: bool) -> void:
	var c: Vector2 = room["c"]
	var size: Vector2 = room["size"]
	var deck := StationBuilder.DECK_Y
	_solid(b, body, Vector3(c.x, deck - 0.15, c.y), Vector3(size.x + WALL_T, 0.3, size.y + WALL_T), m["floor"])
	_solid(b, body, Vector3(c.x, deck + ROOM_H + 0.15, c.y), Vector3(size.x + WALL_T, 0.3, size.y + WALL_T), m["ceiling"])
	for side in 4:
		_room_wall(b, body, room, side, m)
	for p: Dictionary in room["props"]:
		_prop(root, b, body, p, m, rng)
	# Ceiling lamp: cold, warm, red emergency light or dead; some of them flicker.
	var lamp := Vector3(c.x, deck + ROOM_H - 0.05, c.y)
	var roll := rng.randf()
	var col := Color(0.8, 0.88, 1.0) if roll < 0.35 else (Color(1.0, 0.78, 0.5) if roll < 0.65 else Color(1.0, 0.22, 0.12))
	var dead := rng.randf() < 0.15 and not vault
	b.box(lamp, Vector3(2.2, 0.08, 0.5), m["dark"] if dead else Models.emissive(col, 2.0))
	_omni(root, lamp + Vector3(0, -0.5, 0), col, 0.15 if dead else rng.randf_range(0.9, 1.4),
		maxf(size.x, size.y) * 0.95, not dead and rng.randf() < 0.45, rng)
	if vault:
		# The vault is lit by a glowing alien hive on the back wall.
		var back := Vector3(c.x, deck + 1.5, _z1(room) - WALL_T * 0.5 - 0.05)
		_growth(root, back, Vector3(0, 0, -1), m, rng, 1.6)
		_omni(root, back + Vector3(0, 0.5, -1.5), Color(0.55, 1.0, 0.3), 1.0, 7.0)
	# The room's name over its first doorway.
	var doors: Array = room["doors"]
	if not doors.is_empty():
		var door: Dictionary = doors[0]
		var side := int(door["side"])
		var inward: Vector3 = _wall_line(room, side)[1]
		var p := _wall_point(room, side, float(door["at"]), WALL_T * 0.5 + 0.03) + Vector3(0, DOOR_H + 0.45, 0)
		_label(root, str(room["name"]), p, 40, 0.006, Color(0.9, 0.8, 0.55), atan2(inward.x, inward.z))
	# Debris on the floor and alien growth in a corner.
	for i in rng.randi_range(2, 5):
		var p := Vector3(c.x + rng.randf_range(-0.4, 0.4) * size.x, deck + 0.06, c.y + rng.randf_range(-0.4, 0.4) * size.y)
		b.box(p, Vector3(rng.randf_range(0.2, 0.7), 0.1, rng.randf_range(0.2, 0.9)), m["mid"] if i % 2 == 0 else m["rust"],
			Vector3(0, rng.randf_range(0, 180), rng.randf_range(-8, 8)))
	if rng.randf() < 0.55 or vault:
		var corner := Vector3(_x0(room) + 0.4 if rng.randf() < 0.5 else _x1(room) - 0.4, deck + 0.05,
			_z0(room) + 0.4 if rng.randf() < 0.5 else _z1(room) - 0.4)
		_growth(root, corner, Vector3.UP, m, rng)


## One wall of a room with its doorways cut out (a lintel above each one).
static func _room_wall(b: Models.Batch, body: StaticBody3D, room: Dictionary, side: int, m: Dictionary) -> void:
	var horizontal := side <= Side.BACK
	var fixed := float(_wall_line(room, side)[0])
	var c: Vector2 = room["c"]
	var size: Vector2 = room["size"]
	var a0 := c.x - size.x * 0.5 - WALL_T * 0.5 if horizontal else c.y - size.y * 0.5 + WALL_T * 0.5
	var a1 := c.x + size.x * 0.5 + WALL_T * 0.5 if horizontal else c.y + size.y * 0.5 - WALL_T * 0.5
	var gaps: Array = []
	for door: Dictionary in room["doors"]:
		if int(door["side"]) == side:
			gaps.append(float(door["at"]))
	gaps.sort()
	var deck := StationBuilder.DECK_Y
	var cur := a0
	var inward: Vector3 = _wall_line(room, side)[1]
	for at: float in gaps:
		_wall_piece(b, body, horizontal, fixed, cur, at - DOOR_W * 0.5, deck, deck + ROOM_H, m["inner"])
		_skirting(b, horizontal, fixed, cur, at - DOOR_W * 0.5 - 0.08, inward, m)
		_wall_piece(b, body, horizontal, fixed, at - DOOR_W * 0.5, at + DOOR_W * 0.5, deck + DOOR_H, deck + ROOM_H, m["inner"])
		# Door frame.
		for e: float in [at - DOOR_W * 0.5, at + DOOR_W * 0.5]:
			var fp := Vector3(e, deck + DOOR_H * 0.5, fixed) if horizontal else Vector3(fixed, deck + DOOR_H * 0.5, e)
			b.box(fp + inward * (WALL_T * 0.5 + 0.02), Vector3(0.16, DOOR_H, 0.04) if horizontal else Vector3(0.04, DOOR_H, 0.16), m["dark"])
		cur = at + DOOR_W * 0.5
	_wall_piece(b, body, horizontal, fixed, cur, a1, deck, deck + ROOM_H, m["inner"])
	_skirting(b, horizontal, fixed, cur + (0.08 if cur > a0 else 0.0), a1, inward, m)


## A grimy skirting band along the inside of a wall piece from `a` to `e` (it stops at the door
## frames instead of running across the doorways).
static func _skirting(b: Models.Batch, horizontal: bool, fixed: float, a: float, e: float, inward: Vector3, m: Dictionary) -> void:
	if e - a < 0.05:
		return
	var mid := (a + e) * 0.5
	var band := Vector3(mid, StationBuilder.DECK_Y + 0.25, fixed) if horizontal else Vector3(fixed, StationBuilder.DECK_Y + 0.25, mid)
	b.box(band + inward * (WALL_T * 0.5 + 0.01), Vector3(e - a, 0.5, 0.02) if horizontal else Vector3(0.02, 0.5, e - a), m["mid"])


static func _wall_piece(b: Models.Batch, body: StaticBody3D, horizontal: bool, fixed: float, a: float, e: float, y0: float, y1: float, mat: Material) -> void:
	if e - a < 0.02:
		return
	var mid := (a + e) * 0.5
	if horizontal:
		_solid(b, body, Vector3(mid, (y0 + y1) * 0.5, fixed), Vector3(e - a, y1 - y0, WALL_T), mat)
	else:
		_solid(b, body, Vector3(fixed, (y0 + y1) * 0.5, mid), Vector3(WALL_T, y1 - y0, e - a), mat)


## A corridor between two doorways: floor, ceiling, walls and a red emergency light.
static func _build_corridor(root: Derelict, b: Models.Batch, body: StaticBody3D, cor: Dictionary, m: Dictionary) -> void:
	var a: Vector3 = cor["from"]
	var e: Vector3 = cor["to"]
	var length := a.distance_to(e)
	if length < 0.05:
		return
	var along_x := int(cor["axis"]) == 0
	var mid := (a + e) * 0.5
	var deck := StationBuilder.DECK_Y
	var across := DOOR_W + WALL_T * 2.0
	var floor_size := Vector3(length, 0.3, across) if along_x else Vector3(across, 0.3, length)
	_solid(b, body, Vector3(mid.x, deck - 0.15, mid.z), floor_size, m["floor"])
	_solid(b, body, Vector3(mid.x, deck + DOOR_H + 0.15, mid.z), floor_size, m["ceiling"])
	for side: float in [-1.0, 1.0]:
		var off := side * (DOOR_W + WALL_T) * 0.5
		var pos := Vector3(mid.x, deck + DOOR_H * 0.5, mid.z + off) if along_x else Vector3(mid.x + off, deck + DOOR_H * 0.5, mid.z)
		_solid(b, body, pos, Vector3(length, DOOR_H, WALL_T) if along_x else Vector3(WALL_T, DOOR_H, length), m["wall"])
	b.box(Vector3(mid.x, deck + DOOR_H - 0.03, mid.z), Vector3(0.4, 0.05, 0.4), m["red"])
	_omni(root, Vector3(mid.x, deck + DOOR_H - 0.4, mid.z), Color(1.0, 0.18, 0.1), 0.6, 4.5)


## Furniture against a wall (solid, so the crew walks around it).
static func _prop(root: Derelict, b: Models.Batch, body: StaticBody3D, p: Dictionary, m: Dictionary, rng: RandomNumberGenerator) -> void:
	var size: Vector3 = p["size"]
	var yaw: float = p["yaw"]
	var pos: Vector3 = p["pos"]
	var basis := Basis(Vector3.UP, yaw)
	var center := pos + Vector3(0, size.y * 0.5, 0)
	_shape(body, center, Vector3(size.x, size.y, size.z), yaw)
	var deg := Vector3(0, rad_to_deg(yaw), 0)
	match str(p["kind"]):
		"shelf":
			for i in 3:
				b.box(pos + basis * Vector3(0, 0.3 + i * 0.95, 0), Vector3(size.x, 0.06, size.z), m["mid"], deg)
			for sx: float in [-1.0, 1.0]:
				b.box(pos + basis * Vector3(sx * size.x * 0.48, size.y * 0.5, 0), Vector3(0.06, size.y, size.z), m["dark"], deg)
			for i in rng.randi_range(1, 4):
				b.box(pos + basis * Vector3(rng.randf_range(-0.6, 0.6), 0.55 + (i % 3) * 0.95, 0), Vector3(0.45, 0.4, 0.5), m["crate"],
					deg + Vector3(0, rng.randf_range(-20, 20), 0))
		"console":
			b.box(center, size, m["dark"], deg)
			var screen: Material = m["screen"] if rng.randf() < 0.4 else m["dead_glass"]
			b.box(pos + basis * Vector3(0, size.y + 0.25, size.z * 0.3), Vector3(size.x * 0.8, 0.45, 0.05), screen, deg + Vector3(-15, 0, 0))
		"locker":
			b.box(center, size, m["mid"] if rng.randf() < 0.6 else m["rust"], deg)
			b.box(pos + basis * Vector3(0, size.y * 0.6, -size.z * 0.5 - 0.01), Vector3(0.05, 0.3, 0.02), m["dark"], deg)
		"crates":
			b.box(pos + basis * Vector3(-0.35, 0.4, 0), Vector3(0.8, 0.8, 0.8), m["crate"], deg + Vector3(0, rng.randf_range(-10, 10), 0))
			b.box(pos + basis * Vector3(0.4, 0.35, 0.05), Vector3(0.7, 0.7, 0.7), m["crate"], deg + Vector3(0, rng.randf_range(-15, 15), 0))
			b.box(pos + basis * Vector3(-0.2, 1.05, 0), Vector3(0.6, 0.55, 0.6), m["crate"], deg + Vector3(0, rng.randf_range(-25, 25), 0))
		"bunk":
			for y: float in [0.45, 1.3]:
				b.box(pos + basis * Vector3(0, y, 0), Vector3(size.x, 0.12, size.z), m["mid"], deg)
				b.box(pos + basis * Vector3(0, y + 0.1, 0), Vector3(size.x - 0.1, 0.1, size.z - 0.1), m["rust"], deg)
			for sx: float in [-1.0, 1.0]:
				b.box(pos + basis * Vector3(sx * size.x * 0.47, size.y * 0.5, 0), Vector3(0.06, size.y, size.z), m["dark"], deg)
