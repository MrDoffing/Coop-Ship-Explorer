class_name HubMap
extends Node2D
## The station's map on the control hub's board (drawn into a SubViewport by the Derelict, again
## whenever a door or the power changes): the rooms with their names, the corridors and walls, every
## door with its id in its state's colour (green open, red locked, dark red locked down), the rooms
## shut in behind locked doors, the entrance, and YOU ARE HERE at the hub's desk. It is turned
## heads-up: up on the map is straight ahead for someone looking at the board. Without power it only
## says so.

const SIZE := Vector2i(1400, 852)
## Room for the title above the plan and the legend under it, and the margin at the sides (pixels).
const TOP := 84.0
const BOTTOM := 70.0
const SIDE := 50.0
const BG := Color(0.015, 0.035, 0.04)
const GRID := Color(0.05, 0.11, 0.12)
const ROOM := Color(0.1, 0.22, 0.24)
const HALL := Color(0.06, 0.13, 0.14)
const SHUT := Color(0.3, 0.08, 0.06)
const HERE_ROOM := Color(0.08, 0.3, 0.18)
const WALL := Color(0.55, 0.85, 0.85)
const TEXT := Color(0.75, 0.95, 0.92)
const OPEN := Color(0.3, 1.0, 0.4)
const LOCKED := Color(1.0, 0.22, 0.12)
const DOWN := Color(0.45, 0.04, 0.03)

var layout: Dictionary = {}
## The doors' states (Derelict.DOOR_*) and whether the hub has power.
var doors := PackedByteArray()
var powered := false
## Station (x, z) to map pixels; the hub desk's console (station-local x, z).
var _xf := Transform2D.IDENTITY
var _scale := 1.0
var _here := Vector2.ZERO
var _font: Font


## `yaw`: the board's (it faces its local +z); `here`: where YOU ARE HERE goes (station-local).
func setup(layout_d: Dictionary, yaw: float, here: Vector3) -> void:
	layout = layout_d
	_font = GunPod.mono_font()
	_here = Vector2(here.x, here.z)
	# Right on the map is the board's +x, down its +z (towards whoever looks at it).
	var right := Vector2(cos(yaw), -sin(yaw))
	var down := Vector2(sin(yaw), cos(yaw))
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var kind: PackedByteArray = layout["kind"]
	var half := OutpostLayout.CELL * 0.5
	for i in kind.size():
		if kind[i] == OutpostLayout.ROCK:
			continue
		var p := OutpostLayout.cell_pos(Vector2i(i % OutpostLayout.GX, i / OutpostLayout.GX))
		for corner: Vector2 in [Vector2(-half, -half), Vector2(half, half), Vector2(-half, half), Vector2(half, -half)]:
			var q := Vector2(p.x, p.z) + corner
			var m := Vector2(q.dot(right), q.dot(down))
			lo = lo.min(m)
			hi = hi.max(m)
	# (A cell more past the front door, for the entrance.)
	var front: Dictionary = layout["doors"][0]
	var fp: Vector3 = (front["pos"] as Vector3) + (front["normal"] as Vector3) * OutpostLayout.CELL
	var fm := Vector2(Vector2(fp.x, fp.z).dot(right), Vector2(fp.x, fp.z).dot(down))
	lo = lo.min(fm)
	hi = hi.max(fm)
	var span := hi - lo
	_scale = minf((SIZE.x - SIDE * 2.0) / span.x, (SIZE.y - TOP - BOTTOM) / span.y)
	var origin := Vector2(SIZE.x * 0.5, TOP + (SIZE.y - TOP - BOTTOM) * 0.5) - (lo + hi) * 0.5 * _scale
	_xf = Transform2D(Vector2(right.x, down.x) * _scale, Vector2(right.y, down.y) * _scale, origin)


func _at(p: Vector3) -> Vector2:
	return _xf * Vector2(p.x, p.z)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, SIZE), BG)
	if not powered:
		_text_at(Vector2(SIZE.x * 0.5, SIZE.y * 0.5 - 10.0), "NO POWER", 56, LOCKED * 0.8)
		_text_at(Vector2(SIZE.x * 0.5, SIZE.y * 0.5 + 44.0), "START THE GENERATOR", 28, LOCKED * 0.6)
		return
	for x in range(0, SIZE.x, 40):
		draw_line(Vector2(x, 0), Vector2(x, SIZE.y), GRID, 1.0)
	for y in range(0, SIZE.y, 40):
		draw_line(Vector2(0, y), Vector2(SIZE.x, y), GRID, 1.0)
	var kind: PackedByteArray = layout["kind"]
	var owner: PackedInt32Array = layout["owner"]
	var rooms: Array = layout["rooms"]
	var all_doors: Array = layout["doors"]
	var hub := int(layout.get("hub", -1))
	var shut := {}
	for ri in rooms.size():
		var open := false
		for di: int in rooms[ri]["doors"]:
			if Derelict.door_passable(all_doors[di], doors, di):
				open = true
		if not open:
			shut[ri] = true
	var half := OutpostLayout.CELL * 0.5
	# The floor: rooms (shut in ones dark red, the hub green), corridors.
	for i in kind.size():
		if kind[i] == OutpostLayout.ROCK:
			continue
		var c := Vector2i(i % OutpostLayout.GX, i / OutpostLayout.GX)
		var p := OutpostLayout.cell_pos(c)
		var col := HALL
		if kind[i] == OutpostLayout.ROOM:
			col = SHUT if shut.has(owner[i]) else (HERE_ROOM if owner[i] == hub else ROOM)
		draw_colored_polygon(PackedVector2Array([_at(p + Vector3(-half, 0, -half)), _at(p + Vector3(half, 0, -half)),
			_at(p + Vector3(half, 0, half)), _at(p + Vector3(-half, 0, half))]), col)
	# The walls: every cell edge that isn't open (the doorways get their doors over them).
	var w := maxf(2.0, OutpostLayout.WALL_T * _scale * 0.6)
	for i in kind.size():
		if kind[i] == OutpostLayout.ROCK:
			continue
		var c := Vector2i(i % OutpostLayout.GX, i / OutpostLayout.GX)
		var p := OutpostLayout.cell_pos(c)
		for dir: Vector2i in OutpostLayout.DIRS:
			if DerelictBuilder._open_edge(layout, c, c + dir):
				continue
			var n := Vector3(dir.x, 0, dir.y) * half
			var t := Vector3(dir.y, 0, -dir.x) * half
			draw_line(_at(p + n - t), _at(p + n + t), WALL, w)
	# The doors and their ids (on the corridor side), the entrance.
	var dw := OutpostLayout.DOOR_W * 0.5
	for di in all_doors.size():
		var d: Dictionary = all_doors[di]
		var pos: Vector3 = d["pos"]
		var n: Vector3 = d["normal"]
		var t := Vector3(n.z, 0, -n.x)
		var state := int(doors[di]) if di < doors.size() else Derelict.DOOR_CLOSED
		var col := OPEN if Derelict.door_passable(d, doors, di) else (DOWN if state == Derelict.DOOR_LOCKDOWN else LOCKED)
		var bar := maxf(5.0, 0.4 * _scale)
		draw_line(_at(pos - t * dw), _at(pos + t * dw), BG, w + 4.0)
		draw_line(_at(pos - t * dw), _at(pos + t * dw), col, bar)
		if di == 0:
			_text_out(pos, n, bar, "ENTRANCE", 22, TEXT)
		elif str(d.get("id", "")) != "":
			_text_out(pos, n, bar, str(d["id"]) + (" X" if state == Derelict.DOOR_LOCKDOWN else ""), 26, col, true)
	# The rooms' names (LOCKED under a shut in one's; the hub's over YOU ARE HERE), each shrunk to fit
	# its room.
	for ri in rooms.size():
		var c: Vector2 = rooms[ri]["c"]
		var at := _xf * c + (Vector2(0, -34) if ri == hub else Vector2.ZERO)
		var half_size: Vector2 = rooms[ri]["size"] * 0.5
		var across := absf((_xf.basis_xform(Vector2(half_size.x, 0))).x) + absf((_xf.basis_xform(Vector2(0, half_size.y))).x)
		var room_name := str(rooms[ri]["name"])
		_text_at(at - Vector2(0, 8), room_name, _fit(room_name, 22, across * 2.0 - 10.0), TEXT)
		if shut.has(ri):
			_text_at(at + Vector2(0, 20), "LOCKED", 20, LOCKED)
	var here := _xf * _here
	draw_circle(here, 9.0, OPEN)
	draw_arc(here, 16.0, 0.0, TAU, 24, OPEN, 2.0)
	_text_at(here + Vector2(0, 36), "YOU ARE HERE", 18, OPEN)
	# The title and the legend.
	_text_at(Vector2(SIZE.x * 0.5, 50), "%s  -  STATION MAP" % str(layout.get("name", "OUTPOST")).to_upper(), 34, TEXT)
	var lx := SIDE
	var ly := SIZE.y - BOTTOM * 0.45
	for key: Array in [[OPEN, "OPEN"], [LOCKED, "LOCKED"], [DOWN, "LOCKDOWN"]]:
		draw_rect(Rect2(lx, ly - 14, 34, 14), key[0])
		draw_string(_font, Vector2(lx + 44, ly), key[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, TEXT)
		lx += 190.0
	draw_string(_font, Vector2(lx + 40, ly), "AT THE CONSOLE: UNLOCK D23 / LOCK D23", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, TEXT)


## Text beside a doorway (station-local `pos`, `n` out into the corridor), just clear of its door's
## bar (`bar` pixels thick).
func _text_out(pos: Vector3, n: Vector3, bar: float, text: String, size: int, col: Color, bold := false) -> void:
	var out := (_at(pos + n) - _at(pos)).normalized()
	var width := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var reach := absf(out.x) * width * 0.5 + absf(out.y) * size * 0.4 + bar * 0.5 + 6.0
	_text_at(_at(pos) + out * reach, text, size, col, bold)


## The font size (at most `size`) at which `text` fits in `width` pixels.
func _fit(text: String, size: int, width: float) -> int:
	var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	return size if w <= width else maxi(12, int(size * width / w))


## Text centred on `at` (bold: drawn twice, a pixel apart).
func _text_at(at: Vector2, text: String, size: int, col: Color, bold := false) -> void:
	var width := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var p := at + Vector2(-width * 0.5, size * 0.35)
	draw_string(_font, p + Vector2(1, 1), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, BG)
	draw_string(_font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
	if bold:
		draw_string(_font, p + Vector2(1, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
