class_name OutpostLayout
extends RefCounted
## The plan of an abandoned station behind its front wall (see DerelictBuilder): rooms on a grid of
## CELL-sized squares, corridors that bend and branch between them, the doors, what each room is
## and what stands in it. Plain maths (it runs on the cave worker threads); DerelictBuilder makes
## the nodes from it.
##
## Station-local frame: x along the tunnel, y up, z into the rock. Cell (i, j) has its middle at
## x = (i - MID) * CELL, z = Z0 + (j + 0.5) * CELL. The station's front door opens into cell
## (MID, 0), the start of a short entry corridor.
##
## Rooms are rectangles, rectangles with an alcove on one side, or L-shapes, at least one cell
## apart. Corridors are one cell wide. Each room in turn is joined to the corridors already laid
## by the cheapest path from one of its walls: going straight is cheaper than turning and running
## alongside another corridor is dear, so corridors bend round the rooms and branch off each other
## (T-junctions); a few extra links make loops. Rooms with a single doorway can be sealed: by a door
## that needs the generator's power, by a door locked behind a keypad (the vault, the room furthest
## in, always is when it can be), or by a door locked from the control hub (only with a hub).
##
## Layout: {"rooms", "doors", "kind" (per cell: ROCK, ROOM or HALL), "owner" (per cell: room index
## or -1), "links" (corridor edges that are open: edge_key -> true), "door_at" (edge_key -> door
## index), "vault", "generator" (room index or -1), "hub" (the control hub, room index or -1),
## "carve_min", "carve_max", "name"}.
## Room: {"name", "theme", "cells", "core" (the main rectangle, cells), "inner" (its middle, where
## furniture stands free of the walls, cells; may be empty), "c" and "size" (the core in metres,
## x/z), "h" (ceiling height above the deck), "doors" (door indices), "seal" ("", "power",
## "hack"), "dist" (cells from the front door), "props", "spots" (free floor by the walls for
## salvage: {pos, yaw}), "cams" (security cameras watching it: {pos, look})}.
## Door: {"room" (-1: the front door), "cell" (the room side; the entry corridor for the front
## door), "out" (the corridor side), "kind" ("front", "open", "power", "hack", "hub"), "pos" (the
## floor in the middle of the doorway), "normal" (from the room out into the corridor), "id" (with a
## control hub: its name on the hub's map and over the doorway, "D23"; "" for the front door)}, and
## for a keypad
## lock "digits" (the digit at each cord's left end), "colors" (the colour id at each cord
## terminal on the right), "wires" (the right terminal each left one is wired to), "lights" (the
## colour ids lit on the keypad, in order) and "code".
## Prop: {"kind", "pos" (floor point under its middle), "yaw", "size" (width along its local x,
## height, depth along its local z; it faces its local +z), "var" (a number to vary it by)}.

const CELL := 3.0
## The grid: columns along the tunnel (the front door opens into column MID) and rows into the rock,
## starting behind the front wall (DerelictBuilder.FACADE_Z plus half its thickness).
const GX := 15
const GZ := 14
const MID := 7
const Z0 := 20.3
const ROOMS_MIN := 5
const ROOMS_MAX := 8
## Rooms are ROOM_H tall (some themes taller, THEME_H), corridors CORRIDOR_H. Doorways are DOOR_W
## wide and DOOR_H tall; walls WALL_T thick.
const ROOM_H := 4.4
const CORRIDOR_H := 3.4
const DOOR_W := 2.2
const DOOR_H := 2.8
const WALL_T := 0.3
const THEME_H := {"generator": 5.2, "mess": 4.8, "lab": 4.8, "storage": 4.8}
## Corridor routing costs: a step, a turn on top, and a step beside a corridor already there.
const STEP := 10
const TURN := 14
const BESIDE := 34
## Chance of an extra corridor from a room (making loops), and its longest (cells).
const LOOP_CHANCE := 0.35
const LOOP_MAX := 8
## Chances that an outpost has a generator room (whose power some sealed doors need), a control hub
## and an armory, and that another dead-end room is locked behind a keypad.
const GENERATOR_CHANCE := 0.65
const HUB_CHANCE := 0.6
const ARMORY_CHANCE := 0.6
const EXTRA_LOCK_CHANCE := 0.25
## At most this many rooms behind keypad locks (the vault and one more).
const MAX_LOCKS := 2
## With a control hub: one dead end locked from it (two with HUB_SECOND_CHANCE), and every door's id
## a number from DOOR_IDS (no two alike).
const HUB_SECOND_CHANCE := 0.4
const DOOR_IDS := Vector2i(10, 60)
## Keypad locks: six cords run tangled from six digits on the left to six colours on the right, and
## the keypad lights HACK_DIGITS of those colours in a row: the code is their digits, in order.
const HACK_COLORS: Array[Color] = [Color(0.88, 0.12, 0.06), Color(0.95, 0.68, 0.12), Color(0.25, 0.75, 0.2),
	Color(0.2, 0.4, 0.85), Color(0.92, 0.88, 0.78), Color(0.75, 0.25, 0.65)]
const HACK_COLOR_NAMES := ["RED", "YELLOW", "GREEN", "BLUE", "WHITE", "MAGENTA"]
const HACK_CORDS := 6
const HACK_DIGITS := 4
## Wrong codes before a keypad locks its door down for good.
const HACK_TRIES := 3
## Cells.
const ROCK := 0
const ROOM := 1
const HALL := 2
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const THEMES := {
	"lab": ["SCIENCE LAB", "BIO LAB", "RESEARCH LAB"],
	"storage": ["STORAGE", "CARGO HOLD", "SUPPLY ROOM"],
	"quarters": ["CREW QUARTERS", "BUNK ROOM", "DORMITORY"],
	"mess": ["MESS HALL", "CANTEEN"],
	"hub": ["CONTROL HUB"],
	"generator": ["GENERATOR"],
	"armory": ["ARMORY"],
	"vault": ["SECURE STORAGE"],
	"medbay": ["MED BAY"],
	"workshop": ["WORKSHOP"],
}
const NAMES := ["VESTA", "KEPLER", "HADES", "CERES", "ORPHEUS", "TALOS", "ICARUS", "BOREAS", "LETHE", "NEREID",
	"PALLAS", "HYGIEA"]
## Furniture: width along its wall (local x), height, depth (local z, out from the wall). Free
## standing pieces use the same frame.
const PROPS := {
	"shelf": Vector3(2.2, 2.4, 0.7), "locker": Vector3(1.8, 2.1, 0.6), "crates": Vector3(1.8, 1.4, 0.9),
	"cabinet": Vector3(1.4, 1.2, 0.6), "lab_bench": Vector3(2.4, 1.0, 0.85), "console": Vector3(1.6, 1.25, 0.75),
	"bed": Vector3(2.7, 0.75, 0.95), "counter": Vector3(2.6, 1.05, 0.8), "vending": Vector3(1.1, 2.1, 0.8),
	"gun_rack": Vector3(2.4, 2.1, 0.45), "ammo": Vector3(1.6, 0.8, 0.7), "fuel_tanks": Vector3(2.4, 2.2, 0.9),
	"breaker": Vector3(1.6, 2.2, 0.5), "monitor_wall": Vector3(2.6, 1.9, 0.4), "filing": Vector3(1.2, 1.4, 0.6),
	"workbench": Vector3(2.4, 1.0, 0.9), "med_cabinet": Vector3(1.4, 2.0, 0.5), "strongbox": Vector3(1.4, 1.0, 0.85),
	"barrels": Vector3(1.6, 1.0, 0.9), "pipes": Vector3(1.0, 4.0, 0.45),
	"tube": Vector3(1.3, 2.9, 1.3), "lab_table": Vector3(2.4, 1.0, 1.15), "pallet": Vector3(2.1, 1.8, 2.1),
	"table": Vector3(2.3, 0.8, 2.3), "hub_desk": Vector3(3.0, 3.2, 1.7), "generator": Vector3(2.4, 2.6, 4.8),
	"weapon_bench": Vector3(2.3, 1.0, 1.2), "surgery": Vector3(2.3, 1.3, 1.2), "lathe": Vector3(2.4, 1.6, 1.4),
}
## What stands along the walls in each kind of room ([kind, weight]), and the share of wall stretches
## left free (where salvage can lie).
const WALL_PROPS := {
	"lab": [["lab_bench", 3], ["cabinet", 2], ["console", 1], ["med_cabinet", 1], ["pipes", 1]],
	"storage": [["shelf", 4], ["crates", 3], ["barrels", 2]],
	"vault": [["strongbox", 3], ["locker", 2], ["shelf", 2]],
	"quarters": [["bed", 5], ["locker", 2]],
	"mess": [["counter", 2], ["vending", 2], ["barrels", 1]],
	"hub": [["filing", 2], ["locker", 2], ["console", 2], ["breaker", 1]],
	"generator": [["fuel_tanks", 3], ["breaker", 2], ["pipes", 2], ["barrels", 1]],
	"armory": [["gun_rack", 4], ["ammo", 2], ["locker", 1]],
	"medbay": [["med_cabinet", 3], ["bed", 2], ["console", 1]],
	"workshop": [["workbench", 3], ["shelf", 2], ["breaker", 1], ["pipes", 1]],
}
const WALL_FREE := 0.32


# --- Grid helpers ------------------------------------------------------------------------------

static func idx(c: Vector2i) -> int:
	return c.x + c.y * GX


static func inside(c: Vector2i) -> bool:
	return c.x >= 0 and c.x < GX and c.y >= 0 and c.y < GZ


## The floor point (station-local) in the middle of cell c.
static func cell_pos(c: Vector2i) -> Vector3:
	return Vector3((c.x - MID) * CELL, StationBuilder.DECK_Y, Z0 + (c.y + 0.5) * CELL)


## The cell a station-local point lies in (it may be outside the grid).
static func cell_at(p: Vector3) -> Vector2i:
	return Vector2i(roundi(p.x / CELL) + MID, floori((p.z - Z0) / CELL))


## Key of the edge between 4-neighbouring cells a and b (both in the grid).
static func edge_key(a: Vector2i, b: Vector2i) -> int:
	var lo := a if (a.y < b.y or (a.y == b.y and a.x < b.x)) else b
	return idx(lo) * 2 + (0 if a.y == b.y else 1)


static func dir_of(d: Vector2i) -> int:
	return DIRS.find(d)


# --- Generation --------------------------------------------------------------------------------

static func generate(rng: RandomNumberGenerator) -> Dictionary:
	var kind := PackedByteArray()
	kind.resize(GX * GZ)
	var owner := PackedInt32Array()
	owner.resize(GX * GZ)
	owner.fill(-1)
	var links := {}
	# The entry corridor: two cells straight in from the front door.
	kind[idx(Vector2i(MID, 0))] = HALL
	kind[idx(Vector2i(MID, 1))] = HALL
	links[edge_key(Vector2i(MID, 0), Vector2i(MID, 1))] = true
	var rooms := _place_rooms(rng, kind, owner)
	var doors: Array = [{"room": -1, "cell": Vector2i(MID, 0), "out": Vector2i(MID, -1), "kind": "front"}]
	var door_at := {}
	# Join the rooms one by one, the cheapest first (Prim's way).
	var joined := {}
	while joined.size() < rooms.size():
		var best_room := -1
		var best := {}
		for ri in rooms.size():
			if joined.has(ri):
				continue
			var r := _route(kind, _door_starts(rooms[ri], ri, owner, doors), {}, int(best.get("cost", 1 << 30)))
			if not r.is_empty() and (best.is_empty() or int(r["cost"]) < int(best["cost"])):
				best = r
				best_room = ri
		if best_room < 0:
			break
		_lay(best, best_room, kind, owner, links, doors, door_at)
		joined[best_room] = true
	# Rooms nothing could reach are given back to the rock.
	if joined.size() < rooms.size():
		var keep: Array = []
		for ri in rooms.size():
			if joined.has(ri):
				keep.append(rooms[ri])
			else:
				for c: Vector2i in rooms[ri]["cells"]:
					kind[idx(c)] = ROCK
		rooms = keep
		_reown(rooms, owner, doors)
	# A few loops: a second doorway joined to a corridor further off than the first one's.
	for ri in rooms.size():
		if rng.randf() >= LOOP_CHANCE:
			continue
		var near := _near_doors(rooms[ri], doors, links, kind, 3)
		var r := _route(kind, _door_starts(rooms[ri], ri, owner, doors), near, LOOP_MAX * (STEP + 8))
		if not r.is_empty():
			_lay(r, ri, kind, owner, links, doors, door_at)
	# Rooms in order of distance from the front door (room 0 is the nearest).
	var dist := _distances(kind, links, doors)
	for ri in rooms.size():
		var dmin := 1 << 20
		for di: int in _room_doors(doors, ri):
			var o: Vector2i = doors[di]["out"]
			dmin = mini(dmin, int(dist.get(idx(o), 1 << 20)) + 1)
		rooms[ri]["dist"] = dmin
	var order: Array = range(rooms.size())
	order.sort_custom(func(a, b): return int(rooms[a]["dist"]) < int(rooms[b]["dist"]))
	var sorted: Array = []
	for ri: int in order:
		sorted.append(rooms[ri])
	rooms = sorted
	_reown(rooms, owner, doors)
	for di in doors.size():
		var d: Dictionary = doors[di]
		if int(d["room"]) >= 0:
			(rooms[int(d["room"])]["doors"] as Array).append(di)
	var out := {"rooms": rooms, "doors": doors, "kind": kind, "owner": owner, "links": links, "door_at": door_at}
	_assign(out, rng)
	for di in doors.size():
		_finish_door(doors[di], rng)
	_door_ids(out, rng.seed)
	for ri in rooms.size():
		_furnish(out, ri, rng)
	_cameras(out, rng)
	var lo := Vector3(INF, StationBuilder.DECK_Y - 1.2, Z0 - 1.0)
	var hi := Vector3(-INF, -INF, -INF)
	for i in GX * GZ:
		if kind[i] == ROCK:
			continue
		var p := cell_pos(Vector2i(i % GX, i / GX))
		lo.x = minf(lo.x, p.x - CELL * 0.5 - 2.0)
		hi.x = maxf(hi.x, p.x + CELL * 0.5 + 2.0)
		hi.z = maxf(hi.z, p.z + CELL * 0.5 + 2.0)
	var top := CORRIDOR_H
	for room: Dictionary in rooms:
		top = maxf(top, float(room["h"]))
	hi.y = StationBuilder.DECK_Y + top + 1.2
	out["carve_min"] = lo
	out["carve_max"] = hi
	out["name"] = "%s-%d OUTPOST" % [NAMES[rng.randi() % NAMES.size()], rng.randi_range(2, 19)]
	return out


## Lay out the rooms: the first just past the entry corridor, each next one beside a room already
## there, one or two cells away.
static func _place_rooms(rng: RandomNumberGenerator, kind: PackedByteArray, owner: PackedInt32Array) -> Array:
	var want := rng.randi_range(ROOMS_MIN, ROOMS_MAX)
	var rooms: Array = []
	for attempt in 600:
		if rooms.size() >= want:
			break
		var shape := _shape(rng)
		var size: Vector2i = shape["size"]
		var at := Vector2i.ZERO
		if rooms.is_empty():
			at = Vector2i(MID + rng.randi_range(-size.x, 1) + (0 if rng.randf() < 0.5 else 1), 2 + rng.randi_range(0, 1))
		elif attempt > 450:
			at = Vector2i(rng.randi_range(0, GX - size.x), rng.randi_range(1, GZ - size.y))
		else:
			var anchor: Dictionary = rooms[rng.randi() % rooms.size()]
			var ab: Rect2i = anchor["bounds"]
			var gap := 1 if rng.randf() < 0.6 else 2
			match rng.randi() % 4:
				0:
					at = Vector2i(ab.end.x + gap, ab.position.y + rng.randi_range(2 - size.y, ab.size.y - 2))
				1:
					at = Vector2i(ab.position.x - gap - size.x, ab.position.y + rng.randi_range(2 - size.y, ab.size.y - 2))
				2:
					at = Vector2i(ab.position.x + rng.randi_range(2 - size.x, ab.size.x - 2), ab.end.y + gap)
				_:
					at = Vector2i(ab.position.x + rng.randi_range(2 - size.x, ab.size.x - 2), ab.position.y - gap - size.y)
		var cells: Array[Vector2i] = []
		for c: Vector2i in shape["cells"]:
			cells.append(c + at)
		if not _fits(cells, kind, owner):
			continue
		var ri := rooms.size()
		for c in cells:
			kind[idx(c)] = ROOM
			owner[idx(c)] = ri
		var core: Rect2i = shape["core"]
		core.position += at
		rooms.append({"cells": cells, "core": core, "bounds": Rect2i(at, size), "doors": [], "props": [], "spots": [],
			"cams": [], "seal": "", "theme": "", "name": "", "dist": 0, "h": ROOM_H})
	return rooms


## A room's shape: {"cells" and "core" (its main rectangle) relative to its corner, "size"}.
static func _shape(rng: RandomNumberGenerator) -> Dictionary:
	var cells: Array[Vector2i] = []
	var r := rng.randf()
	if r < 0.3:
		# L-shaped: a rectangle with a corner cut away; both arms at least two cells wide.
		var w := rng.randi_range(4, 6)
		var h := rng.randi_range(4, 6)
		var cw := rng.randi_range(2, w - 2)
		var ch := rng.randi_range(2, h - 2)
		var corner := rng.randi() % 4
		var cut := Rect2i(0 if corner % 2 == 0 else w - cw, 0 if corner < 2 else h - ch, cw, ch)
		for x in w:
			for z in h:
				if not cut.has_point(Vector2i(x, z)):
					cells.append(Vector2i(x, z))
		# The core is the bigger arm: the full-width band or the full-depth one.
		var band_z := Rect2i(0, ch if corner < 2 else 0, w, h - ch)
		var band_x := Rect2i(cw if corner % 2 == 0 else 0, 0, w - cw, h)
		var core := band_z if band_z.get_area() >= band_x.get_area() else band_x
		return {"cells": cells, "core": core, "size": Vector2i(w, h)}
	var w := rng.randi_range(3, 5)
	var h := rng.randi_range(3, 5)
	if r < 0.62:
		# A rectangle with an alcove on one side.
		var side := rng.randi() % 4
		var along := h if side < 2 else w
		var aw := rng.randi_range(1, mini(3, along - 1))
		var off := rng.randi_range(0, along - aw)
		var shift := Vector2i(1 if side == 1 else 0, 1 if side == 3 else 0)
		for x in w:
			for z in h:
				cells.append(Vector2i(x, z) + shift)
		for a in aw:
			match side:
				0:
					cells.append(Vector2i(w, off + a))
				1:
					cells.append(Vector2i(0, off + a))
				2:
					cells.append(Vector2i(off + a, h))
				_:
					cells.append(Vector2i(off + a, 0))
		var size := Vector2i(w + (1 if side < 2 else 0), h + (1 if side >= 2 else 0))
		return {"cells": cells, "core": Rect2i(shift, Vector2i(w, h)), "size": size}
	for x in w:
		for z in h:
			cells.append(Vector2i(x, z))
	return {"cells": cells, "core": Rect2i(0, 0, w, h), "size": Vector2i(w, h)}


## True when a room fits there: inside the grid (not in the row behind the front wall), on rock, and
## a cell clear of every other room (corners included).
static func _fits(cells: Array[Vector2i], kind: PackedByteArray, owner: PackedInt32Array) -> bool:
	for c in cells:
		if c.x < 0 or c.x >= GX or c.y < 1 or c.y >= GZ or kind[idx(c)] != ROCK:
			return false
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				var n := c + Vector2i(dx, dz)
				if inside(n) and owner[idx(n)] >= 0:
					return false
	return true


## Where a room's next doorway could go: [room cell, direction] for each stretch of its wall that
## faces rock or a corridor, but not right beside one of its doorways.
static func _door_starts(room: Dictionary, ri: int, owner: PackedInt32Array, doors: Array) -> Array:
	var taken: Array[Vector2i] = []
	for d: Dictionary in doors:
		if int(d["room"]) == ri:
			taken.append(d["cell"])
	var out: Array = []
	for c: Vector2i in room["cells"]:
		var close := false
		for t in taken:
			if absi(t.x - c.x) + absi(t.y - c.y) <= 1:
				close = true
		if close:
			continue
		for d in 4:
			var n: Vector2i = c + DIRS[d]
			if inside(n) and owner[idx(n)] < 0:
				out.append([c, d])
	return out


## The cheapest corridor from one of `starts` to the corridors already laid (but not those in
## `avoid`, which block the way): {"start" ([room cell, direction]), "path" (cells from the doorway
## outwards, ending in the corridor joined), "cost"}, or {} when there is none within `max_cost`.
static func _route(kind: PackedByteArray, starts: Array, avoid: Dictionary, max_cost: int) -> Dictionary:
	var cells := GX * GZ
	# What stepping into each cell costs (-1: no way in).
	var enter := PackedInt32Array()
	enter.resize(cells)
	for i in cells:
		if kind[i] == ROOM or avoid.has(i):
			enter[i] = -1
		elif kind[i] == HALL:
			enter[i] = STEP
		else:
			var x := i % GX
			var beside := (x > 0 and kind[i - 1] == HALL) or (x < GX - 1 and kind[i + 1] == HALL) \
				or (i >= GX and kind[i - GX] == HALL) or (i + GX < cells and kind[i + GX] == HALL)
			enter[i] = STEP + BESIDE if beside else STEP
	var step := PackedInt32Array([1, -1, GX, -GX])
	var best := PackedInt32Array()
	best.resize(cells * 4)
	best.fill(1 << 30)
	var prev := PackedInt32Array()
	prev.resize(cells * 4)
	prev.fill(-1)
	var buckets: Array = []
	for si in starts.size():
		var d: int = starts[si][1]
		var c: Vector2i = (starts[si][0] as Vector2i) + DIRS[d]
		var ci := idx(c)
		if enter[ci] < 0:
			continue
		var s := ci * 4 + d
		if enter[ci] < best[s]:
			best[s] = enter[ci]
			prev[s] = -2 - si
			_push(buckets, enter[ci], s)
	var at := 0
	while at < buckets.size() and at <= max_cost:
		var bucket: Array = buckets[at]
		if bucket.is_empty():
			at += 1
			continue
		var s: int = bucket.pop_back()
		if best[s] != at:
			continue
		var ci := s >> 2
		var dir := s & 3
		if kind[ci] == HALL:
			var path: Array[Vector2i] = []
			var k := s
			while k >= 0:
				path.push_front(Vector2i((k >> 2) % GX, (k >> 2) / GX))
				if prev[k] <= -2:
					return {"start": starts[-2 - prev[k]], "path": path, "cost": at}
				k = prev[k]
			return {}
		var x := ci % GX
		for nd in 4:
			if (nd == 0 and x == GX - 1) or (nd == 1 and x == 0):
				continue
			var ni := ci + step[nd]
			if ni < 0 or ni >= cells or enter[ni] < 0:
				continue
			var cost := at + enter[ni] + (TURN if nd != dir else 0)
			var ns := ni * 4 + nd
			if cost < best[ns]:
				best[ns] = cost
				prev[ns] = s
				_push(buckets, cost, ns)
	return {}


static func _push(buckets: Array, cost: int, s: int) -> void:
	while buckets.size() <= cost:
		buckets.append([])
	(buckets[cost] as Array).append(s)


## Lay a route: its cells become corridor, linked to each other and to the corridor it joins, and
## its start becomes a doorway of room `ri`.
static func _lay(r: Dictionary, ri: int, kind: PackedByteArray, owner: PackedInt32Array, links: Dictionary, doors: Array,
		door_at: Dictionary) -> void:
	var path: Array = r["path"]
	for i in path.size():
		var c: Vector2i = path[i]
		kind[idx(c)] = HALL
		if i > 0:
			links[edge_key(path[i - 1], c)] = true
	var start: Array = r["start"]
	var cell: Vector2i = start[0]
	var out: Vector2i = cell + DIRS[int(start[1])]
	door_at[edge_key(cell, out)] = doors.size()
	doors.append({"room": ri, "cell": cell, "out": out, "kind": "open"})
	owner[idx(cell)] = ri


## Corridor cells within `steps` of a room's doorways (a loop must join the corridors further off).
static func _near_doors(room: Dictionary, doors: Array, links: Dictionary, kind: PackedByteArray, steps: int) -> Dictionary:
	var near := {}
	var frontier: Array[Vector2i] = []
	for d: Dictionary in doors:
		if d["cell"] in room["cells"]:
			frontier.append(d["out"])
			near[idx(d["out"])] = true
	for s in steps:
		var next: Array[Vector2i] = []
		for c in frontier:
			for dd in DIRS:
				var n := c + dd
				if inside(n) and kind[idx(n)] == HALL and not near.has(idx(n)) and links.has(edge_key(c, n)):
					near[idx(n)] = true
					next.append(n)
		frontier = next
	return near


## Steps from the front door to every corridor cell (by cell index).
static func _distances(kind: PackedByteArray, links: Dictionary, _doors: Array) -> Dictionary:
	var dist := {idx(Vector2i(MID, 0)): 0}
	var queue: Array[Vector2i] = [Vector2i(MID, 0)]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		for d in DIRS:
			var n := c + d
			if inside(n) and kind[idx(n)] == HALL and not dist.has(idx(n)) and links.has(edge_key(c, n)):
				dist[idx(n)] = int(dist[idx(c)]) + 1
				queue.append(n)
	return dist


static func _room_doors(doors: Array, ri: int) -> Array:
	var out: Array = []
	for di in doors.size():
		if int(doors[di]["room"]) == ri:
			out.append(di)
	return out


## After rooms were dropped or reordered: fix the cells' and doorways' room indices.
static func _reown(rooms: Array, owner: PackedInt32Array, doors: Array) -> void:
	var remap := {}
	for i in owner.size():
		if owner[i] >= 0:
			remap[owner[i]] = -1
	for ri in rooms.size():
		var c0: Vector2i = rooms[ri]["cells"][0]
		remap[owner[idx(c0)]] = ri
	for i in owner.size():
		if owner[i] >= 0:
			owner[i] = int(remap.get(owner[i], -1))
	for d: Dictionary in doors:
		if int(d["room"]) >= 0:
			d["room"] = int(remap.get(int(d["room"]), -1))
	for ri in rooms.size():
		rooms[ri]["doors"] = []


# --- What each room is -------------------------------------------------------------------------

## Themes and seals: the vault (the dead end furthest in, behind a keypad), a generator room with a
## dead end or two that need its power, an armory, a control hub (with a dead end or two locked from
## it) and the rest.
static func _assign(layout: Dictionary, rng: RandomNumberGenerator) -> void:
	var rooms: Array = layout["rooms"]
	var doors: Array = layout["doors"]
	var leaves: Array = []
	for ri in range(1, rooms.size()):
		if (rooms[ri]["doors"] as Array).size() == 1:
			leaves.append(ri)
	var free: Array = range(rooms.size())
	var vault := rooms.size() - 1
	if not leaves.is_empty():
		vault = leaves[0]
		for ri: int in leaves:
			if int(rooms[ri]["dist"]) >= int(rooms[vault]["dist"]):
				vault = ri
		rooms[vault]["seal"] = "hack"
		leaves.erase(vault)
	rooms[vault]["theme"] = "vault"
	free.erase(vault)
	layout["vault"] = vault
	layout["generator"] = -1
	layout["hub"] = -1
	if rng.randf() < GENERATOR_CHANCE:
		var picks: Array = []
		for ri: int in free:
			if not leaves.has(ri) and _inner(rooms[ri]).get_area() >= 2:
				picks.append(ri)
		if picks.is_empty():
			for ri: int in free:
				if _inner(rooms[ri]).get_area() >= 2:
					picks.append(ri)
		if not picks.is_empty():
			var gen: int = picks[rng.randi() % picks.size()]
			rooms[gen]["theme"] = "generator"
			free.erase(gen)
			leaves.erase(gen)
			layout["generator"] = gen
			_shuffle(leaves, rng)
			for i in mini(leaves.size(), 2 if leaves.size() >= 4 and rng.randf() < 0.5 else 1):
				rooms[leaves[i]]["seal"] = "power"
	if rng.randf() < ARMORY_CHANCE and not free.is_empty():
		var picks: Array = []
		for ri: int in leaves:
			if free.has(ri):
				picks.append(ri)
		var armory: int = picks[rng.randi() % picks.size()] if not picks.is_empty() else free[rng.randi() % free.size()]
		rooms[armory]["theme"] = "armory"
		free.erase(armory)
		if str(rooms[armory]["seal"]) == "" and leaves.has(armory) and rng.randf() < 0.4 and _seals(rooms, "hack") < MAX_LOCKS:
			rooms[armory]["seal"] = "hack"
	if rng.randf() < HUB_CHANCE and not free.is_empty():
		# The control hub: a room no door seals, with floor in its middle for the desk, near the front.
		var hub: int = free[0]
		var best := INF
		for ri: int in free:
			var score := float(rooms[ri]["dist"]) + (1000.0 if str(rooms[ri]["seal"]) != "" else 0.0) \
				+ (100.0 if _inner(rooms[ri]).get_area() == 0 else 0.0)
			if score < best:
				best = score
				hub = ri
		rooms[hub]["theme"] = "hub"
		free.erase(hub)
		leaves.erase(hub)
		layout["hub"] = hub
	for ri: int in leaves:
		if str(rooms[ri]["seal"]) == "" and _seals(rooms, "hack") < MAX_LOCKS and rng.randf() < EXTRA_LOCK_CHANCE:
			rooms[ri]["seal"] = "hack"
	if int(layout["hub"]) >= 0:
		# A dead end or two locked from the control hub (rolled apart, so the rest of the plan is as it
		# was without them).
		var hrng := RandomNumberGenerator.new()
		hrng.seed = hash([rng.seed, "hub"])
		var want := 1 + (1 if hrng.randf() < HUB_SECOND_CHANCE else 0)
		# (The furthest in first.)
		var far := leaves.duplicate()
		far.sort_custom(func(a, e): return int(rooms[a]["dist"]) > int(rooms[e]["dist"]))
		for ri: int in far:
			if want > 0 and str(rooms[ri]["seal"]) == "" and str(rooms[ri]["theme"]) != "generator":
				rooms[ri]["seal"] = "hub"
				want -= 1
	var rest: Array = ["lab", "storage", "quarters", "mess", "lab", "medbay", "workshop", "storage", "quarters"]
	_shuffle(rest, rng)
	rest.erase("lab")
	rest.push_front("lab")
	for ri: int in free:
		rooms[ri]["theme"] = rest.pop_front() if not rest.is_empty() else "storage"
	for ri in rooms.size():
		var room: Dictionary = rooms[ri]
		var names: Array = THEMES[room["theme"]]
		room["name"] = names[rng.randi() % names.size()]
		room["h"] = float(THEME_H.get(room["theme"], ROOM_H))
		var core: Rect2i = room["core"]
		room["inner"] = _inner(room)
		var p0 := cell_pos(core.position)
		var p1 := cell_pos(core.end - Vector2i.ONE)
		room["c"] = Vector2((p0.x + p1.x) * 0.5, (p0.z + p1.z) * 0.5)
		room["size"] = Vector2(core.size.x * CELL, core.size.y * CELL)
		if str(room["seal"]) != "":
			var di: int = (room["doors"] as Array)[0]
			doors[di]["kind"] = room["seal"]


static func _seals(rooms: Array, seal: String) -> int:
	var n := 0
	for room: Dictionary in rooms:
		if str(room["seal"]) == seal:
			n += 1
	return n


## The middle of a room's core, where furniture can stand free of the walls (one cell in from them).
static func _inner(room: Dictionary) -> Rect2i:
	var core: Rect2i = room["core"]
	if core.size.x < 3 or core.size.y < 3:
		return Rect2i(core.position, Vector2i.ZERO)
	return Rect2i(core.position + Vector2i.ONE, core.size - Vector2i(2, 2))


static func _shuffle(a: Array, rng: RandomNumberGenerator) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var t: Variant = a[i]
		a[i] = a[j]
		a[j] = t


## A doorway's place, and a keypad lock's cords and code.
static func _finish_door(d: Dictionary, rng: RandomNumberGenerator) -> void:
	var cell: Vector2i = d["cell"]
	var out: Vector2i = d["out"]
	var dir := Vector3(out.x - cell.x, 0, out.y - cell.y)
	d["normal"] = dir
	d["pos"] = cell_pos(cell) + dir * CELL * 0.5
	if str(d["kind"]) != "hack":
		return
	var digits: Array = range(10)
	_shuffle(digits, rng)
	var colors: Array = range(HACK_CORDS)
	_shuffle(colors, rng)
	var wires: Array = range(HACK_CORDS)
	# Tangled: no cord runs straight across.
	for attempt in 20:
		_shuffle(wires, rng)
		var straight := false
		for i in HACK_CORDS:
			if int(wires[i]) == i:
				straight = true
		if not straight:
			break
	var lights: Array = range(HACK_CORDS)
	_shuffle(lights, rng)
	lights = lights.slice(0, HACK_DIGITS)
	d["digits"] = PackedInt32Array(digits.slice(0, HACK_CORDS))
	d["colors"] = PackedInt32Array(colors)
	d["wires"] = PackedInt32Array(wires)
	d["lights"] = PackedInt32Array(lights)
	d["code"] = hack_code(d)


## With a control hub: every door but the front door gets an id ("D" and a number from DOOR_IDS, no
## two alike), on the hub's map and over the doorway (its own random numbers, from `base_seed`).
static func _door_ids(layout: Dictionary, base_seed: int) -> void:
	var doors: Array = layout["doors"]
	for d: Dictionary in doors:
		d["id"] = ""
	if int(layout["hub"]) < 0:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([base_seed, "door ids"])
	var numbers: Array = range(DOOR_IDS.x, DOOR_IDS.y)
	_shuffle(numbers, rng)
	for di in range(1, doors.size()):
		doors[di]["id"] = "D%d" % int(numbers[(di - 1) % numbers.size()])


## The door whose id is `name` ("d23", "D23" or "23"), or -1.
static func door_by_id(layout: Dictionary, name: String) -> int:
	var digits := name.strip_edges().to_upper().trim_prefix("D")
	if digits.is_empty() or not digits.is_valid_int():
		return -1
	var doors: Array = layout["doors"]
	for di in range(1, doors.size()):
		if str(doors[di].get("id", "")) == "D%d" % int(digits):
			return di
	return -1


## The code a keypad lock opens to: for each lit colour, the digit at the other end of its cord.
static func hack_code(d: Dictionary) -> String:
	var digits: PackedInt32Array = d["digits"]
	var colors: PackedInt32Array = d["colors"]
	var wires: PackedInt32Array = d["wires"]
	var code := ""
	for c in (d["lights"] as PackedInt32Array):
		var right := colors.find(c)
		var left := wires.find(right)
		code += str(digits[left])
	return code


# --- Furniture ---------------------------------------------------------------------------------

## Furnish a room for its theme: free-standing pieces in its middle, more along its walls, and free
## floor by the walls for salvage. Nothing stands in front of a doorway.
static func _furnish(layout: Dictionary, ri: int, rng: RandomNumberGenerator) -> void:
	var room: Dictionary = layout["rooms"][ri]
	var theme := str(room["theme"])
	var taken: Array[Rect2] = []
	for di: int in room["doors"]:
		var d: Dictionary = layout["doors"][di]
		var p: Vector3 = d["pos"]
		var n: Vector3 = d["normal"]
		# The floor just inside a doorway stays clear.
		var c := Vector2(p.x, p.z) - Vector2(n.x, n.z) * 1.3
		var half := Vector2(absf(n.z) * (DOOR_W * 0.5 + 0.5) + absf(n.x) * 1.3, absf(n.x) * (DOOR_W * 0.5 + 0.5) + absf(n.z) * 1.3)
		taken.append(Rect2(c - half, half * 2.0))
	_central(room, theme, taken, rng)
	var slots := wall_slots(layout, ri)
	_shuffle(slots, rng)
	var weights: Array = WALL_PROPS.get(theme, WALL_PROPS["storage"])
	var total := 0
	for w: Array in weights:
		total += int(w[1])
	for s: Dictionary in slots:
		var placed := false
		if rng.randf() >= WALL_FREE:
			var pick := rng.randi() % total
			var kind_s := ""
			for w: Array in weights:
				pick -= int(w[1])
				if pick < 0:
					kind_s = w[0]
					break
			var size: Vector3 = PROPS[kind_s]
			var inward: Vector3 = s["inward"]
			var pos: Vector3 = (s["pos"] as Vector3) + inward * (size.z * 0.5 + 0.02)
			placed = _place(room, taken, kind_s, pos, float(s["yaw"]), size, rng)
			if not placed and size.x > 1.6:
				# Squeezed in a corner: try it narrower, slid away from the corner.
				for slide: float in [-0.6, 0.6]:
					var along := Vector3(inward.z, 0, -inward.x) * slide
					if _place(room, taken, kind_s, pos + along, float(s["yaw"]), Vector3(size.x - 1.2, size.y, size.z), rng):
						placed = true
						break
		if not placed:
			var spot := (s["pos"] as Vector3) + (s["inward"] as Vector3) * 0.6
			if _clear(taken, Rect2(Vector2(spot.x, spot.z) - Vector2(0.5, 0.5), Vector2(1.0, 1.0)), room):
				(room["spots"] as Array).append({"pos": spot, "yaw": float(s["yaw"])})
				taken.append(Rect2(Vector2(spot.x, spot.z) - Vector2(0.45, 0.45), Vector2(0.9, 0.9)))


## Free-standing furniture or machinery in a room's middle.
static func _central(room: Dictionary, theme: String, taken: Array[Rect2], rng: RandomNumberGenerator) -> void:
	var inner: Rect2i = room["inner"]
	if inner.get_area() == 0:
		return
	var long_x := inner.size.x >= inner.size.y
	var a := cell_pos(inner.position)
	var e := cell_pos(inner.end - Vector2i.ONE)
	var mid := (a + e) * 0.5
	var yaw_long := PI / 2.0 if long_x else 0.0
	match theme:
		"generator":
			_place(room, taken, "generator", mid, yaw_long, PROPS["generator"], rng)
			return
		"hub":
			# The hub desk faces the room's longer way (its map board across the room).
			_place(room, taken, "hub_desk", mid, 0.0 if long_x else PI / 2.0, PROPS["hub_desk"], rng)
			return
		"mess":
			# Long tables with benches down the length of the room.
			var rows := inner.size.y if long_x else inner.size.x
			var length := (inner.size.x if long_x else inner.size.y) * CELL - 0.8
			for r in rows:
				var p := mid
				if long_x:
					p.z = cell_pos(inner.position + Vector2i(0, r)).z
				else:
					p.x = cell_pos(inner.position + Vector2i(r, 0)).x
				_place(room, taken, "mess_table", p, yaw_long, Vector3(2.5, 0.8, length), rng)
			return
	for i in inner.size.x:
		for j in inner.size.y:
			var c := inner.position + Vector2i(i, j)
			var p := cell_pos(c)
			var yaw := (rng.randi() % 4) * PI / 2.0
			match theme:
				"lab":
					if rng.randf() < 0.65:
						_place(room, taken, "tube", p, yaw, PROPS["tube"], rng)
					else:
						_place(room, taken, "lab_table", p, yaw_long, PROPS["lab_table"], rng)
				"storage", "vault":
					if rng.randf() < 0.8:
						_place(room, taken, "pallet", p, yaw, PROPS["pallet"], rng)
				"quarters":
					if (i + j) % 2 == 0 and rng.randf() < 0.7:
						_place(room, taken, "table", p, 0.0, PROPS["table"], rng)
				"armory":
					if rng.randf() < 0.7:
						_place(room, taken, "weapon_bench", p, yaw_long, PROPS["weapon_bench"], rng)
				"medbay":
					if rng.randf() < 0.75:
						_place(room, taken, "surgery", p, yaw_long, PROPS["surgery"], rng)
				"workshop":
					if rng.randf() < 0.7:
						_place(room, taken, "lathe", p, yaw_long, PROPS["lathe"], rng)


## Put a piece of furniture down if it fits (inside the room, clear of everything else).
static func _place(room: Dictionary, taken: Array[Rect2], kind_s: String, pos: Vector3, yaw: float, size: Vector3,
		rng: RandomNumberGenerator) -> bool:
	var r := footprint(pos, yaw, size)
	if not _clear(taken, r, room):
		return false
	taken.append(r)
	(room["props"] as Array).append({"kind": kind_s, "pos": pos, "yaw": yaw, "size": size, "var": rng.randi() % 1000})
	return true


## The floor a piece takes (x, z), turned by its yaw (a multiple of a right angle).
static func footprint(pos: Vector3, yaw: float, size: Vector3) -> Rect2:
	var turned := absf(sin(yaw)) > 0.5
	var half := Vector2(size.z, size.x) * 0.5 if turned else Vector2(size.x, size.z) * 0.5
	return Rect2(Vector2(pos.x, pos.z) - half, half * 2.0)


## True if `r` is clear of everything taken and inside the room's walls.
static func _clear(taken: Array[Rect2], r: Rect2, room: Dictionary) -> bool:
	for t in taken:
		if t.grow(0.05).intersects(r):
			return false
	var cells: Array = room["cells"]
	var inset := WALL_T * 0.5 + 0.02
	for corner: Vector2 in [r.position + Vector2(inset * 0.0, 0), r.position + Vector2(r.size.x, 0), r.position + Vector2(0, r.size.y), r.end]:
		var q := corner - (corner - r.get_center()).sign() * inset
		var c := cell_at(Vector3(q.x, 0, q.y))
		if not c in cells:
			return false
	return true


## The stretches of wall round a room, one per room cell side that is wall (not a doorway): {"pos"
## (the floor at the wall's face, station-local), "inward", "yaw" (furniture there faces into the
## room), "cell", "dir"}.
static func wall_slots(layout: Dictionary, ri: int) -> Array:
	var room: Dictionary = layout["rooms"][ri]
	var owner: PackedInt32Array = layout["owner"]
	var door_at: Dictionary = layout["door_at"]
	var out: Array = []
	for c: Vector2i in room["cells"]:
		for d in 4:
			var n: Vector2i = c + DIRS[d]
			if inside(n) and owner[idx(n)] == ri:
				continue
			if inside(n) and door_at.has(edge_key(c, n)):
				continue
			var dv := Vector3(DIRS[d].x, 0, DIRS[d].y)
			out.append({"pos": cell_pos(c) + dv * (CELL * 0.5 - WALL_T * 0.5), "inward": -dv, "yaw": atan2(-dv.x, -dv.z),
				"cell": c, "dir": d})
	return out


## Cells of a room a piece of furniture stands on (where nobody can walk through the middle).
static func blocked_cells(room: Dictionary) -> Dictionary:
	var out := {}
	for p: Dictionary in room["props"]:
		var r := footprint(p["pos"], float(p["yaw"]), p["size"]).grow(0.35)
		for c: Vector2i in room["cells"]:
			var q := cell_pos(c)
			if r.has_point(Vector2(q.x, q.z)):
				out[c] = true
	return out


## True when the floor segment a-b (station-local x/z) is clear of a room's furniture (with room
## for a body round it).
static func clear_line(room: Dictionary, a: Vector3, b: Vector3) -> bool:
	for p: Dictionary in room["props"]:
		var r := footprint(p["pos"], float(p["yaw"]), p["size"]).grow(0.3)
		if _segment_hits(r, Vector2(a.x, a.z), Vector2(b.x, b.z)):
			return false
	return true


static func _segment_hits(r: Rect2, a: Vector2, b: Vector2) -> bool:
	if r.has_point(a) or r.has_point(b):
		return true
	var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for i in 4:
		if Geometry2D.segment_intersects_segment(a, b, corners[i], corners[(i + 1) % 4]) != null:
			return true
	return false


## Security cameras: up to four rooms (not the control hub) each get a camera high in a corner of
## their core, looking at its middle; the hub desk's monitors show them.
static func _cameras(layout: Dictionary, rng: RandomNumberGenerator) -> void:
	var sec := int(layout["hub"])
	if sec < 0:
		return
	var rooms: Array = layout["rooms"]
	var picks: Array = []
	for ri in rooms.size():
		if ri != sec:
			picks.append(ri)
	_shuffle(picks, rng)
	for ri: int in picks.slice(0, 4):
		var room: Dictionary = rooms[ri]
		var core: Rect2i = room["core"]
		var corner := Vector2i(core.position.x if rng.randf() < 0.5 else core.end.x - 1, core.position.y if rng.randf() < 0.5 else core.end.y - 1)
		var cp := cell_pos(corner)
		var mid := Vector3(float((room["c"] as Vector2).x), StationBuilder.DECK_Y, float((room["c"] as Vector2).y))
		var toward := (mid - cp)
		toward.y = 0.0
		var sx := signf(toward.x) if absf(toward.x) > 0.1 else 1.0
		var sz := signf(toward.z) if absf(toward.z) > 0.1 else 1.0
		var pos := cp + Vector3(-sx * (CELL * 0.5 - 0.45), float(room["h"]) - 0.45, -sz * (CELL * 0.5 - 0.45))
		(room["cams"] as Array).append({"pos": pos, "look": mid + Vector3(0, 0.9, 0)})


# --- Queries -----------------------------------------------------------------------------------

## Walkable cells of a room nobody's furniture stands on.
static func free_cells(room: Dictionary) -> Array[Vector2i]:
	var blocked := blocked_cells(room)
	var out: Array[Vector2i] = []
	for c: Vector2i in room["cells"]:
		if not blocked.has(c):
			out.append(c)
	return out


## Every corridor cell.
static func corridor_cells(layout: Dictionary) -> Array[Vector2i]:
	var kind: PackedByteArray = layout["kind"]
	var out: Array[Vector2i] = []
	for i in GX * GZ:
		if kind[i] == HALL:
			out.append(Vector2i(i % GX, i / GX))
	return out


## Ceiling height above the deck over cell c (0 for rock).
static func ceiling(layout: Dictionary, c: Vector2i) -> float:
	if not inside(c):
		return 0.0
	var kind: PackedByteArray = layout["kind"]
	match kind[idx(c)]:
		ROOM:
			return float(layout["rooms"][(layout["owner"] as PackedInt32Array)[idx(c)]]["h"])
		HALL:
			return CORRIDOR_H
	return 0.0


## The room (index) a station-local point is in, or -1 (corridors, outside).
static func room_at(layout: Dictionary, p: Vector3) -> int:
	var c := cell_at(p)
	if not inside(c):
		return -1
	return (layout["owner"] as PackedInt32Array)[idx(c)]
