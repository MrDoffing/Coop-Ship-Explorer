class_name OutpostAutotest
extends RefCounted
## Automated runs for the abandoned outposts (scripts/dev/autotest.gd starts them; `t` is the
## autotest node, for its helpers: wait, shot, _tap, _face...).

var t: Node


func _init(autotest: Node) -> void:
	t = autotest


# --- Plans -------------------------------------------------------------------------------------

## Generate the plans of many outposts and check them: every room reachable from the front door
## (and on the walking graph), sealed rooms dead ends behind the right door, furniture clear of
## each other, of the walls and of the doorways, salvage spots free; how long a plan takes. The
## first few are drawn to user://autotest/plan_<seed>.png. Headless.
func run_plans() -> void:
	var seeds := 80
	var fails := 0
	var times: Array[float] = []
	var stats := {"rooms": 0, "doors": 0, "hack": 0, "power": 0, "generator": 0, "hub": 0, "armory": 0, "loops": 0,
		"l_shaped": 0, "junctions": 0, "bends": 0}
	var themes := {}
	for sd in seeds:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([sd, "plan"])
		var t0 := Time.get_ticks_usec()
		var layout := OutpostLayout.generate(rng)
		times.append((Time.get_ticks_usec() - t0) / 1000.0)
		var problems := _check_plan(layout)
		if not problems.is_empty():
			fails += 1
			print("[autotest] plan %d: FAIL %s" % [sd, "; ".join(problems)])
		var rooms: Array = layout["rooms"]
		stats["rooms"] += rooms.size()
		stats["doors"] += (layout["doors"] as Array).size() - 1
		for d: Dictionary in layout["doors"]:
			if str(d["kind"]) in ["hack", "power"]:
				stats[str(d["kind"])] += 1
		stats["generator"] += 1 if int(layout["generator"]) >= 0 else 0
		stats["hub"] += 1 if int(layout["hub"]) >= 0 else 0
		for room: Dictionary in rooms:
			themes[room["theme"]] = int(themes.get(room["theme"], 0)) + 1
			if str(room["theme"]) == "armory":
				stats["armory"] += 1
			if (room["doors"] as Array).size() > 1:
				stats["loops"] += 1
			if (room["cells"] as Array).size() != (room["core"] as Rect2i).get_area():
				stats["l_shaped"] += 1
		for c: Vector2i in OutpostLayout.corridor_cells(layout):
			var bits := DerelictBuilder._hall_opens(layout, c)
			var n := 0
			for i in 4:
				n += (bits >> i) & 1
			if n >= 3:
				stats["junctions"] += 1
			elif n == 2 and bits != 3 and bits != 12:
				stats["bends"] += 1
		if sd < 8:
			_draw_plan(layout, sd)
	times.sort()
	print("[autotest] plans: %d of %d failed; generation median %.1f ms, max %.1f ms" % [fails, seeds, times[times.size() / 2], times[times.size() - 1]])
	# Where the time goes: placing the rooms, one corridor route per room, furnishing, the graph.
	var phase := {"place": 0.0, "route": 0.0, "furnish": 0.0, "nav": 0.0}
	for sd in 20:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([sd, "plan"])
		var kind := PackedByteArray()
		kind.resize(OutpostLayout.GX * OutpostLayout.GZ)
		var owner := PackedInt32Array()
		owner.resize(OutpostLayout.GX * OutpostLayout.GZ)
		owner.fill(-1)
		var t0 := Time.get_ticks_usec()
		var rooms := OutpostLayout._place_rooms(rng, kind, owner)
		var t1 := Time.get_ticks_usec()
		for ri in rooms.size():
			OutpostLayout._route(kind, OutpostLayout._door_starts(rooms[ri], ri, owner, []), {}, 1 << 30)
		var t2 := Time.get_ticks_usec()
		var layout := OutpostLayout.generate(rng)
		var t3 := Time.get_ticks_usec()
		for ri in (layout["rooms"] as Array).size():
			layout["rooms"][ri]["props"] = []
			layout["rooms"][ri]["spots"] = []
			OutpostLayout._furnish(layout, ri, rng)
		var t4 := Time.get_ticks_usec()
		DerelictBuilder.build_nav({"layout": layout}, {})
		var t5 := Time.get_ticks_usec()
		phase["place"] += (t1 - t0) / 20000.0
		phase["route"] += (t2 - t1) / maxf(rooms.size(), 1.0) / 20000.0
		phase["furnish"] += (t4 - t3) / 20000.0
		phase["nav"] += (t5 - t4) / 20000.0
	print("[autotest] plans: placing rooms %.1f ms, a corridor route %.2f ms, furnishing %.1f ms, the walking graph %.1f ms" % [
		phase["place"], phase["route"], phase["furnish"], phase["nav"]])
	print("[autotest] plans: per outpost %.1f rooms, %.1f doorways; %d keypad locks, %d power doors, %d generators, %d control hubs, %d armories" % [
		stats["rooms"] / float(seeds), stats["doors"] / float(seeds), stats["hack"], stats["power"], stats["generator"], stats["hub"], stats["armory"]])
	print("[autotest] plans: %d rooms with two or more doorways (loops), %d L-shaped or with an alcove, corridor junctions %d, bends %d" % [
		stats["loops"], stats["l_shaped"], stats["junctions"], stats["bends"]])
	print("[autotest] plans: themes %s" % str(themes))


## What is wrong with a plan (empty when nothing).
func _check_plan(layout: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var rooms: Array = layout["rooms"]
	var doors: Array = layout["doors"]
	if rooms.size() < OutpostLayout.ROOMS_MIN - 1:
		out.append("only %d rooms" % rooms.size())
	# Every walkable cell reachable from the front door with every door open.
	var seen := {Vector2i(OutpostLayout.MID, 0): true}
	var queue: Array[Vector2i] = [Vector2i(OutpostLayout.MID, 0)]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_front()
		for d in OutpostLayout.DIRS:
			var n := c + d
			if seen.has(n) or not OutpostLayout.inside(n):
				continue
			if DerelictBuilder._open_edge(layout, c, n) or DerelictBuilder._door_between(layout, c, n) >= 0:
				seen[n] = true
				queue.append(n)
	var kind: PackedByteArray = layout["kind"]
	var unreached := 0
	for i in kind.size():
		if kind[i] != OutpostLayout.ROCK and not seen.has(Vector2i(i % OutpostLayout.GX, i / OutpostLayout.GX)):
			unreached += 1
	if unreached > 0:
		out.append("%d cells unreachable" % unreached)
	for ri in rooms.size():
		var room: Dictionary = rooms[ri]
		var seal := str(room["seal"])
		if seal != "":
			if (room["doors"] as Array).size() != 1:
				out.append("room %d sealed (%s) with %d doorways" % [ri, seal, (room["doors"] as Array).size()])
			elif str(doors[(room["doors"] as Array)[0]]["kind"]) != seal:
				out.append("room %d sealed %s behind a %s door" % [ri, seal, doors[(room["doors"] as Array)[0]]["kind"]])
		if (room["doors"] as Array).is_empty():
			out.append("room %d has no doorway" % ri)
		if OutpostLayout.free_cells(room).is_empty():
			out.append("room %d has no free floor" % ri)
		var props: Array = room["props"]
		for i in props.size():
			var a := OutpostLayout.footprint(props[i]["pos"], float(props[i]["yaw"]), props[i]["size"])
			for j in range(i + 1, props.size()):
				var e := OutpostLayout.footprint(props[j]["pos"], float(props[j]["yaw"]), props[j]["size"])
				if a.intersects(e):
					out.append("room %d: %s and %s overlap" % [ri, props[i]["kind"], props[j]["kind"]])
			for di: int in room["doors"]:
				var dd: Dictionary = doors[di]
				var inside := DerelictBuilder.door_inside(dd, 1.0)
				if a.has_point(Vector2(inside.x, inside.z)):
					out.append("room %d: %s in front of a doorway" % [ri, props[i]["kind"]])
		for di: int in room["doors"]:
			var cell: Vector2i = doors[di]["cell"]
			if OutpostLayout.blocked_cells(room).has(cell):
				out.append("room %d: its doorway's cell is blocked" % ri)
	# The walking graph: every room's free cells from the pier with every door open, none of the
	# sealed rooms' with the doors as the station starts.
	var astar := DerelictBuilder.build_nav({"layout": layout}, {})
	var open := PackedByteArray()
	open.resize(doors.size())
	open.fill(Derelict.DOOR_OPEN)
	DerelictBuilder.apply_doors(astar, layout, open)
	for ri in rooms.size():
		var cells := OutpostLayout.free_cells(rooms[ri])
		var id := DerelictBuilder.NAV_CELL + OutpostLayout.idx(cells[0]) if not cells.is_empty() else -1
		if id < 0 or not astar.has_point(id) or astar.get_id_path(DerelictBuilder.NAV_PIER, id).is_empty():
			out.append("room %d off the walking graph" % ri)
	DerelictBuilder.apply_doors(astar, layout, Derelict.start_doors(layout))
	for ri in rooms.size():
		var cells := OutpostLayout.free_cells(rooms[ri])
		if cells.is_empty():
			continue
		var reach := not astar.get_id_path(DerelictBuilder.NAV_PIER, DerelictBuilder.NAV_CELL + OutpostLayout.idx(cells[0])).is_empty()
		if reach == (str(rooms[ri]["seal"]) != ""):
			out.append("room %d (%s) %s while the doors are as they start" % [ri, rooms[ri]["seal"], "reachable" if reach else "unreachable"])
	return out


## A plan as a picture: rock dark, rooms by theme, corridors grey, walls black, doorways by kind
## (green open, red keypad, yellow power, blue locked from the control hub), furniture outlined,
## salvage spots and cameras dotted.
func _draw_plan(layout: Dictionary, sd: int) -> void:
	var px := 30
	var w := OutpostLayout.GX * px
	var h := OutpostLayout.GZ * px
	var img := Image.create(w, h + px, false, Image.FORMAT_RGB8)
	img.fill(Color(0.08, 0.08, 0.09))
	var colors := {"lab": Color(0.25, 0.55, 0.35), "storage": Color(0.45, 0.4, 0.25), "vault": Color(0.55, 0.3, 0.2),
		"quarters": Color(0.3, 0.35, 0.55), "mess": Color(0.55, 0.45, 0.3), "hub": Color(0.25, 0.45, 0.55),
		"generator": Color(0.6, 0.55, 0.15), "armory": Color(0.5, 0.25, 0.25), "medbay": Color(0.55, 0.55, 0.55), "workshop": Color(0.4, 0.3, 0.45)}
	var kind: PackedByteArray = layout["kind"]
	var owner: PackedInt32Array = layout["owner"]
	for i in kind.size():
		var c := Vector2i(i % OutpostLayout.GX, i / OutpostLayout.GX)
		var col := Color(0.08, 0.08, 0.09)
		if kind[i] == OutpostLayout.HALL:
			col = Color(0.42, 0.42, 0.42)
		elif kind[i] == OutpostLayout.ROOM:
			col = colors.get(layout["rooms"][owner[i]]["theme"], Color.WHITE)
		img.fill_rect(Rect2i(c.x * px, (OutpostLayout.GZ - 1 - c.y) * px + px, px, px), col)
	# Walls and doorways on the edges.
	for i in kind.size():
		var c := Vector2i(i % OutpostLayout.GX, i / OutpostLayout.GX)
		for d: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
			var n := c + d
			var walk_c := kind[i] != OutpostLayout.ROCK
			var walk_n := OutpostLayout.inside(n) and kind[OutpostLayout.idx(n)] != OutpostLayout.ROCK
			if not walk_c and not walk_n:
				continue
			if DerelictBuilder._open_edge(layout, c, n):
				continue
			var di := DerelictBuilder._door_between(layout, c, n)
			var col := Color.BLACK
			if di >= 0:
				col = {"open": Color(0.2, 0.9, 0.3), "hack": Color(1.0, 0.15, 0.1), "power": Color(1.0, 0.85, 0.1),
					"hub": Color(0.3, 0.75, 1.0)}.get(str(layout["doors"][di]["kind"]), Color.WHITE)
			var x0 := c.x * px
			var y0 := (OutpostLayout.GZ - 1 - c.y) * px + px
			var r := Rect2i()
			match d:
				Vector2i(1, 0):
					r = Rect2i(x0 + px - 2, y0, 3, px)
				Vector2i(-1, 0):
					r = Rect2i(x0 - 1, y0, 3, px)
				Vector2i(0, 1):
					r = Rect2i(x0, y0 - 1, px, 3)
				_:
					r = Rect2i(x0, y0 + px - 2, px, 3)
			if di >= 0:
				r = r.grow(1)
			img.fill_rect(r.intersection(Rect2i(0, 0, w, h + px)), col)
	# Furniture, spots and cameras.
	for room: Dictionary in layout["rooms"]:
		for p: Dictionary in room["props"]:
			var f := OutpostLayout.footprint(p["pos"], float(p["yaw"]), p["size"])
			var a := _to_px(Vector2(f.position.x, f.end.y), px)
			var e := _to_px(Vector2(f.end.x, f.position.y), px)
			var r := Rect2i(a, e - a).abs()
			img.fill_rect(r, Color(0.85, 0.85, 0.8) if str(p["kind"]) != "generator" else Color(1.0, 0.95, 0.4))
			img.fill_rect(r.grow(-2), Color(0.3, 0.3, 0.3) if r.size.x > 4 and r.size.y > 4 else Color(0.85, 0.85, 0.8))
		for s: Dictionary in room["spots"]:
			var q := _to_px(Vector2((s["pos"] as Vector3).x, (s["pos"] as Vector3).z), px)
			img.fill_rect(Rect2i(q - Vector2i(2, 2), Vector2i(5, 5)), Color(1.0, 0.8, 0.0))
		for cam: Dictionary in room["cams"]:
			var q := _to_px(Vector2((cam["pos"] as Vector3).x, (cam["pos"] as Vector3).z), px)
			img.fill_rect(Rect2i(q - Vector2i(2, 2), Vector2i(5, 5)), Color(1.0, 0.2, 0.9))
	# The front door.
	img.fill_rect(Rect2i(OutpostLayout.MID * px + 4, h + px - 3, px - 8, 3), Color(0.3, 0.8, 1.0))
	var path := "%s/plan_%d.png" % [t._dir, sd]
	img.save_png(path)
	print("[autotest] plan %d: %s (%d rooms: %s)" % [sd, ProjectSettings.globalize_path(path), (layout["rooms"] as Array).size(),
		", ".join((layout["rooms"] as Array).map(func(r): return "%s%s" % [r["theme"], ("/" + str(r["seal"])) if str(r["seal"]) != "" else ""]))])


# --- A tour --------------------------------------------------------------------------------------

## A mission seed whose first abandoned station (the one the outpost test lands at) passes `want`.
static func seed_where(want: Callable, from := 1) -> int:
	for s in range(from, from + 400):
		var cave := CaveGen.new(s)
		for k in 16:
			var d := cave.derelict(k)
			if not d.is_empty():
				if want.call(d["layout"]):
					return s
				break
	return -1


## Start the outpost test (landed at the first abandoned station; `mission_seed` picks the cave)
## and wait until it runs.
func start_outpost(mission_seed := -1) -> MissionLevel:
	Game.main.start_outpost_test(mission_seed)
	var m: MissionLevel = null
	for i in 900:
		await t.get_tree().process_frame
		m = Game.mission as MissionLevel
		if m and m.started and m.local_player and m.local_ready:
			return m
	return null


## A camera tour of the outpost the test lands at (windowed): how long it takes to build, the
## corridors, every room, the generator, the control hub's desk and a keypad, with the power off and on,
## and a lockdown.
func run_tour() -> void:
	var sd := seed_where(func(l): return int(l["generator"]) >= 0 and int(l["hub"]) >= 0 and OutpostLayout._seals(l["rooms"], "hack") > 0)
	var m := await start_outpost(sd)
	if m == null:
		print("[autotest] FAIL: the outpost test never started")
		return
	await t.wait(1.0)
	var ship := m.ship
	var d := m.cave.derelict(ship.derelict_k)
	var layout: Dictionary = d["layout"]
	var node: Derelict = Derelict.live.get(ship.derelict_k)
	var rooms: Array = layout["rooms"]
	print("[autotest] tour: seed %d, %s (k %d), %d rooms: %s" % [sd, d["name"], ship.derelict_k, rooms.size(),
		", ".join(rooms.map(func(r): return "%s%s" % [r["name"], (" (" + str(r["seal"]) + ")") if str(r["seal"]) != "" else ""]))])
	# How long building one takes (a second copy, freed again).
	var scratch := Node3D.new()
	m.add_child(scratch)
	var t0 := Time.get_ticks_usec()
	var copy := DerelictBuilder.build(scratch, d)
	var build_ms := (Time.get_ticks_usec() - t0) / 1000.0
	var meshes := copy.find_children("*", "MeshInstance3D", true, false).size()
	var lights := copy.find_children("*", "Light3D", true, false).size()
	var shapes := copy.find_children("*", "CollisionShape3D", true, false).size()
	scratch.free()
	Derelict.live[ship.derelict_k] = node
	print("[autotest] tour: build stages %s" % _stage_times(m, d))
	print("[autotest] tour: building it takes %.0f ms: %d mesh instances, %d lights, %d collision shapes" % [build_ms, meshes, lights, shapes])
	for c in ship.boarder_root.get_children():
		c.queue_free()
	var p := m.local_player
	p.position = ship.spawn_points()[0]
	var cam := Camera3D.new()
	cam.far = 300.0
	cam.fov = 70.0
	m.add_child(cam)
	cam.current = true
	var xf: Transform3D = d["xform"]
	await _views(cam, xf, layout, "tr_off")
	# The power comes back.
	if int(layout["generator"]) >= 0:
		ship.outpost_power = true
		ship._power_doors_at = ship._time + 0.5
		await t.wait(5.0)
		print("[autotest] tour: power on, doors %s" % str(Array(ship.outpost_doors)))
		await _views(cam, xf, layout, "tr_on")
	# A lockdown at the first keypad lock.
	for di in (layout["doors"] as Array).size():
		if str(layout["doors"][di]["kind"]) == "hack":
			ship._set_door(di, Derelict.DOOR_LOCKDOWN)
			await t.wait(1.2)
			var dd: Dictionary = layout["doors"][di]
			var out := DerelictBuilder.door_outside(dd, 3.4) + Vector3(0, 1.7, 0)
			_look(cam, xf, out + Vector3(0.6, 0, 0.6), (dd["pos"] as Vector3) + Vector3(0, 1.3, 0))
			await t.wait(0.4)
			await t.shot("tr_lockdown")
			break
	cam.queue_free()


## How long each stage of DerelictBuilder.build takes (ms), on a scratch copy.
func _stage_times(m: MissionLevel, d: Dictionary) -> String:
	var scratch := Node3D.new()
	m.add_child(scratch)
	var root := Derelict.new()
	root.k = -999
	root.layout = d["layout"]
	scratch.add_child(root)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(d["seed"])
	var out := {}
	var t0 := Time.get_ticks_usec()
	var mats := DerelictBuilder._materials()
	var b := Models.Batch.new()
	var body := StaticBody3D.new()
	root.add_child(body)
	var stamp := func(key: String) -> void:
		var now := Time.get_ticks_usec()
		out[key] = snappedf((now - t0) / 1000.0, 0.1)
		t0 = now
	stamp.call("materials")
	DerelictBuilder._build_pad(root, b, mats, rng)
	stamp.call("pad")
	DerelictBuilder._build_facade(root, b, body, d, mats, rng)
	stamp.call("facade")
	DerelictBuilder._build_shell(b, body, d["layout"], mats)
	stamp.call("shell")
	DerelictBuilder._build_halls(root, b, d["layout"], mats, rng, true, Models.Batch.new())
	stamp.call("halls")
	var props := {"tanks": [], "subjects": [], "screens": [], "generator": {}}
	for ri in (d["layout"]["rooms"] as Array).size():
		DerelictBuilder._build_room(root, b, body, d["layout"], ri, mats, rng, true, props)
		stamp.call("room%d" % ri)
	DerelictBuilder._build_doors(root, b, d["layout"], mats, rng)
	stamp.call("doors")
	b.commit(root, "X")
	stamp.call("commit")
	root.setup(props)
	stamp.call("setup")
	scratch.free()
	return str(out)


## Views of every room, a corridor or two, the generator, the control hub's desk and a keypad.
func _views(cam: Camera3D, xf: Transform3D, layout: Dictionary, prefix: String) -> void:
	var rooms: Array = layout["rooms"]
	for ri in rooms.size():
		var room: Dictionary = rooms[ri]
		var core: Rect2i = room["core"]
		var a := OutpostLayout.cell_pos(core.position)
		var e := OutpostLayout.cell_pos(core.end - Vector2i.ONE)
		var mid := (a + e) * 0.5
		# (Below the hanging lamps, which hang over every other core cell from its corner.)
		var eye := a + (a - mid).normalized() * 0.6 + Vector3(0, float(room["h"]) - 1.6, 0)
		if ri == int(layout["generator"]) or ri == int(layout["hub"]):
			eye = mid + (a - mid) * 0.8 + Vector3(0, 2.4, 0)
		_look(cam, xf, eye, mid + Vector3(0, 0.6, 0))
		await t.wait(0.35)
		await t.shot("%s_room%d_%s" % [prefix, ri, room["theme"]])
		# At eye height, a step in from its first doorway.
		var dd: Dictionary = layout["doors"][(room["doors"] as Array)[0]]
		_look(cam, xf, DerelictBuilder.door_inside(dd, 0.5) + Vector3(0, 1.65, 0), mid + Vector3(0, 1.1, 0))
		await t.wait(0.35)
		await t.shot("%s_room%d_%s_eye" % [prefix, ri, room["theme"]])
	# The longest straight run of corridor, looking along it.
	var best := []
	for c: Vector2i in OutpostLayout.corridor_cells(layout):
		for d: Vector2i in [Vector2i(1, 0), Vector2i(0, 1)]:
			var run := [c]
			var n := c
			while DerelictBuilder._open_edge(layout, n, n + d):
				n += d
				run.append(n)
			if run.size() > best.size():
				best = run
	if best.size() >= 2:
		var c0: Vector2i = best[0]
		var c1: Vector2i = best[best.size() - 1]
		var p0 := OutpostLayout.cell_pos(c0)
		var p1 := OutpostLayout.cell_pos(c1)
		_look(cam, xf, p0 + Vector3(0, 1.65, 0) - (p1 - p0).normalized() * 1.2, p1 + Vector3(0, 1.4, 0))
		await t.wait(0.35)
		await t.shot("%s_corridor" % prefix)
	# The control hub's desk from its chair (the feeds run while the viewer is in the room): the map
	# board, the monitors over it and the computer.
	var sec := int(layout["hub"])
	if sec >= 0:
		for prop: Dictionary in rooms[sec]["props"]:
			if str(prop["kind"]) == "hub_desk":
				var px := Transform3D(Basis(Vector3.UP, float(prop["yaw"])), prop["pos"])
				_look(cam, xf, px * Vector3(0.2, 1.6, 2.3), px * Vector3(0, 1.8, -0.6))
				await t.wait(1.0)
				await t.shot("%s_hub_desk" % prefix)
	# A keypad lock, close up.
	var node: Derelict = Derelict.live.get(Game.mission.ship.derelict_k)
	for di in (layout["doors"] as Array).size():
		var panel := node.panel_of(di) if node else null
		if panel:
			cam.global_transform = panel.view_transform()
			await t.wait(0.3)
			await t.shot("%s_keypad" % prefix)
			var dd: Dictionary = layout["doors"][di]
			_look(cam, xf, DerelictBuilder.door_outside(dd, 3.6) + Vector3(0, 1.7, 0) + Vector3(dd["normal"].z, 0, -dd["normal"].x) * 1.0,
				(dd["pos"] as Vector3) + Vector3(0, 1.4, 0))
			await t.wait(0.3)
			await t.shot("%s_lockeddoor" % prefix)
			break


func _look(cam: Camera3D, xf: Transform3D, eye: Vector3, at: Vector3) -> void:
	cam.global_position = xf * eye
	cam.look_at(xf * at, xf.basis.y)


# --- Keypads in view ---------------------------------------------------------------------------

## Every keypad lock of many outposts: nothing the station builds stands in front of its panel,
## between it and the close look at it (HackPanel.clear_box). Each outpost is built far below the
## test's own (not set up: no lamps run), its batched triangles checked before they are committed
## (their bounds, in the panel's frame) and every other mesh's and label's bounds. Windowed, the
## first few keypads are also pictured as the close look sees them (kc_<seed>_<door>.png).
func run_keypad_clear(shots: bool) -> void:
	var m := await start_outpost()
	if m == null:
		print("[autotest] FAIL: the outpost test never started")
		return
	await t.wait(0.5)
	var scratch := Node3D.new()
	m.add_child(scratch)
	var seeds := 40
	var panels := 0
	var bad_tris := 0
	var bad_nodes := PackedStringArray()
	var pictured := 0
	var t0 := Time.get_ticks_msec()
	for sd in seeds:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([sd, "plan"])
		var layout := OutpostLayout.generate(rng)
		var spots: Array[Transform3D] = []
		for dd: Dictionary in layout["doors"]:
			if str(dd["kind"]) == "hack":
				spots.append(DerelictBuilder._keypad_spot(layout, dd))
		if spots.is_empty():
			continue
		var at := Transform3D(Basis.IDENTITY, Vector3(0, -600.0, 0))
		var d := {"k": -1000 - sd, "layout": layout, "xform": at, "seed": hash([sd, "dressing"]), "name": layout["name"]}
		var root := Derelict.new()
		root.k = int(d["k"])
		root.layout = layout
		root.transform = at
		scratch.add_child(root)
		var b := Models.Batch.new()
		DerelictBuilder.build_parts(root, b, Models.Batch.new(), d)
		var boxes: Array = []
		for spot in spots:
			boxes.append([spot.affine_inverse(), HackPanel.clear_box()])
		panels += spots.size()
		# The batched triangles (station-local).
		for part: Models.BatchPart in b._parts.values():
			var v := part.v
			for i in range(0, v.size() - 2, 3):
				for bx: Array in boxes:
					var inv: Transform3D = bx[0]
					var tri := AABB(inv * v[i], Vector3.ZERO).expand(inv * v[i + 1]).expand(inv * v[i + 2])
					if tri.intersects(bx[1]):
						bad_tris += 1
		# The furniture models placed whole (their bounds).
		for key: Variant in b._instances:
			var mesh: Mesh = key[0] if key is Array else key
			for x: Transform3D in b._instances[key]:
				for bx: Array in boxes:
					if ((bx[0] as Transform3D) * x * mesh.get_aabb()).intersects(bx[1]):
						bad_nodes.append("%d:%s model" % [sd, mesh.resource_name])
		# Everything else that shows (meshes, labels), but the panels themselves.
		var station_inv := root.global_transform.affine_inverse()
		for g: GeometryInstance3D in root.find_children("*", "GeometryInstance3D", true, false):
			var inside_panel := false
			var n: Node = g
			while n != null and n != root:
				if n is HackPanel:
					inside_panel = true
					break
				n = n.get_parent()
			# (A keypad lock's lockdown shutter hangs up in the ceiling until a lockdown, when the
			# keypad is dead.)
			if inside_panel or not g.visible or str(g.name).begins_with("Shutter"):
				continue
			var local := station_inv * g.global_transform * g.get_aabb()
			for bx: Array in boxes:
				if ((bx[0] as Transform3D) * local).intersects(bx[1]):
					var what: String = (g as MeshInstance3D).mesh.get_class() if g is MeshInstance3D and (g as MeshInstance3D).mesh else g.get_class()
					var spot_of: Transform3D = (bx[0] as Transform3D).affine_inverse()
					bad_nodes.append("%d:%s (%s under %s at %s; the keypad at %s facing %s, in cell %s)" % [sd, g.name, what, g.get_parent().name,
						(station_inv * g.global_position).snapped(Vector3.ONE * 0.01), spot_of.origin.snapped(Vector3.ONE * 0.01),
						spot_of.basis.z.snapped(Vector3.ONE * 0.01), OutpostLayout.cell_at(spot_of.origin)])
		if shots and pictured < 6:
			b.commit(root, "Derelict")
			for panel: HackPanel in root.find_children("*", "HackPanel", true, false):
				if pictured >= 6:
					break
				var cam := Camera3D.new()
				cam.fov = HackPanel.VIEW_FOV
				m.add_child(cam)
				cam.global_transform = panel.view_transform()
				cam.current = true
				var lamp := OmniLight3D.new()
				lamp.omni_range = 6.0
				lamp.light_energy = 1.6
				cam.add_child(lamp)
				lamp.position = Vector3(0.3, 0.4, 0.2)
				panel.enter()
				await t.wait(1.5)
				await t.shot("kc_%d_%d" % [sd, panel.door])
				cam.queue_free()
				pictured += 1
			m.local_player.camera.current = true
		root.free()
	scratch.queue_free()
	print("[autotest] keypads: %d keypads in %d outposts checked in %.1f s: %d batched triangles in front of a keypad, other meshes in front: %s" % [
		panels, seeds, (Time.get_ticks_msec() - t0) / 1000.0, bad_tris, "none" if bad_nodes.is_empty() else ", ".join(bad_nodes)])


# --- Performance -------------------------------------------------------------------------------

## What an outpost costs to draw (windowed, vsync off): the player stands on the pier looking in, in
## a corridor and in every room, flashlight on; at each the frame rate, the main view's GPU time and
## the draw calls, objects and triangles drawn. Then the same in the first room with the flashlight
## off, with the station hidden, and the station's own counts: mesh instances, triangles, lights,
## decals. `bots` crew bots come along (they stand beside the player, their flashlights on).
func run_perf(bots := 0, bisect := false) -> void:
	var sd := seed_where(func(l): return int(l["generator"]) >= 0 and int(l["hub"]) >= 0)
	Game.bot_count = bots
	var m := await start_outpost(sd)
	if m == null:
		print("[autotest] FAIL: the outpost test never started")
		return
	await t.wait(1.0)
	var ship := m.ship
	var p := m.local_player
	# (Nobody gets hurt meanwhile: the aliens live on, but the player can't die.)
	p.max_hp = 100000.0
	p.hp = 100000.0
	var d := m.cave.derelict(ship.derelict_k)
	var layout: Dictionary = d["layout"]
	var node: Derelict = Derelict.live.get(ship.derelict_k)
	var lift := Vector3(0, StationBuilder.LAND_HEIGHT, 0)
	var floor_y := StationBuilder.DECK_Y - StationBuilder.LAND_HEIGHT + 0.05
	var tris := 0
	var meshes := 0
	for mi: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		meshes += 1
		if mi.mesh:
			tris += mi.mesh.get_faces().size() / 3
	var lights := node.find_children("*", "Light3D", true, false).size()
	var decals := node.find_children("*", "Decal", true, false).size()
	print("[autotest] perf: %s, %d mesh instances, %d triangles, %d lights, %d decals; %d aliens, %d crew bots, %d nodes in the tree" % [d["name"], meshes, tris, lights,
		decals, ship.boarder_root.get_child_count(), bots, int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))])
	var rid := t.get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	var vsync := DisplayServer.window_get_vsync_mode()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var spots: Array = []
	spots.append(["pier", Vector3(0, floor_y, DerelictBuilder.FACADE_Z - 4.0), 0.0])
	var halls := OutpostLayout.corridor_cells(layout)
	if not halls.is_empty():
		spots.append(["corridor", OutpostLayout.cell_pos(halls[halls.size() / 2]) - lift + Vector3(0, 0.05, 0), PI * 0.5])
	var rooms: Array = layout["rooms"]
	for ri in rooms.size():
		var core: Rect2i = rooms[ri]["core"]
		spots.append(["room%d %s" % [ri, rooms[ri]["theme"]], OutpostLayout.cell_pos(core.get_center()) - lift + Vector3(0, 0.05, 0), 0.0])
	var sum_fps := 0.0
	for s: Array in spots:
		p.position = s[1]
		p.velocity = Vector3.ZERO
		p.look_yaw = float(s[2])
		p.look_pitch = -0.05
		_bots_beside(ship, p)
		await t.wait(0.8)
		var r := await _measure(rid)
		sum_fps += r[0]
		print("[autotest] perf at %s: %s" % [s[0], _perf_text(r)])
	print("[autotest] perf: mean %.0f fps over %d spots" % [sum_fps / spots.size(), spots.size()])
	# The first room again: flashlight off, then the station hidden.
	var first: Array = spots[2] if spots.size() > 2 else spots[0]
	p.position = first[1]
	p.look_yaw = float(first[2])
	await t.wait(0.6)
	_bots_beside(ship, p)
	var lit := 0
	for c in ship.crew_root.get_children():
		if c is CrewMember and (c as CrewMember)._flashlight and (c as CrewMember)._flashlight.visible:
			lit += 1
			(c as CrewMember)._flashlight.visible = false
	await t.wait(0.5)
	print("[autotest] perf at %s, the %d flashlights off: %s" % [first[0], lit, _perf_text(await _measure(rid))])
	for c in ship.crew_root.get_children():
		if c is CrewMember and (c as CrewMember)._flashlight:
			(c as CrewMember)._flashlight.visible = (c as CrewMember).lamp_on()
	node.visible = false
	await t.wait(0.5)
	print("[autotest] perf at %s, the station hidden: %s" % [first[0], _perf_text(await _measure(rid))])
	node.visible = true
	node.set_process(false)
	await t.wait(0.5)
	print("[autotest] perf at %s, the station's own updates (lamps, doors, feeds) stopped: %s" % [first[0], _perf_text(await _measure(rid))])
	node.set_process(true)
	for c in ship.boarder_root.get_children():
		c.process_mode = Node.PROCESS_MODE_DISABLED
	await t.wait(0.5)
	print("[autotest] perf at %s, the aliens stopped: %s" % [first[0], _perf_text(await _measure(rid))])
	for c in ship.boarder_root.get_children():
		c.process_mode = Node.PROCESS_MODE_INHERIT
	for c in ship.boarder_root.get_children():
		c.set_physics_process(false)
	await t.wait(0.5)
	print("[autotest] perf at %s, the aliens' thinking stopped (animation runs): %s" % [first[0], _perf_text(await _measure(rid))])
	for c in ship.boarder_root.get_children():
		c.set_physics_process(true)
		c.set_process(false)
	await t.wait(0.5)
	print("[autotest] perf at %s, the aliens' animation stopped (thinking runs): %s" % [first[0], _perf_text(await _measure(rid))])
	var kinds := {}
	for c in ship.boarder_root.get_children():
		c.set_process(true)
		kinds[(c as Boarder).kind] = int(kinds.get((c as Boarder).kind, 0)) + 1
	print("[autotest] perf: the aliens %s" % str(kinds))
	if not bisect:
		DisplayServer.window_set_vsync_mode(vsync)
		RenderingServer.viewport_set_measure_render_time(rid, false)
		return
	# Which part of the mission the frame's time goes to: each of the mission's and the ship's
	# children stopped in turn (process and physics), the frame rate then.
	await t.wait(1.0)
	var base := await _measure(rid)
	print("[autotest] perf bisect: everything running %s" % _perf_text(base))
	var parts: Array[Node] = []
	for c in m.get_children():
		parts.append(c)
	for c in ship.get_children():
		parts.append(c)
	var interior := ship.get_node_or_null("Interior")
	if interior:
		for c in interior.get_children():
			parts.append(c)
			for g in c.get_children():
				if g.get_child_count() > 3 or g.get_script() != null:
					parts.append(g)
	for c in parts:
		if c == ship or c is Camera3D or not is_instance_valid(c):
			continue
		var was := c.process_mode
		c.process_mode = Node.PROCESS_MODE_DISABLED
		await t.wait(0.3)
		var r := await _measure(rid)
		c.process_mode = was
		if r[0] > float(base[0]) * 1.08:
			print("[autotest] perf bisect: %s/%s (%s) stopped: %.0f fps (%.1f ms, %+.1f ms)" % [c.get_parent().name, c.name, c.get_class(), r[0],
				1000.0 / float(r[0]), 1000.0 / float(r[0]) - 1000.0 / float(base[0])])
	DisplayServer.window_set_vsync_mode(vsync)
	RenderingServer.viewport_set_measure_render_time(rid, false)


## The crew bots stand round the player (just behind), facing the same way.
func _bots_beside(ship: Mothership, p: CrewMember) -> void:
	var k := 0
	for c in ship.crew_root.get_children():
		var b := c as CrewMember
		if b == null or not b.bot:
			continue
		k += 1
		var off := Basis(Vector3.UP, p.look_yaw) * Vector3((k - 2) * 0.9, 0, 1.4)
		b.position = p.position + off
		b.net_pos = b.position
		b.look_yaw = p.look_yaw
		b.rotation.y = p.look_yaw


## [fps, GPU ms of the main view, draw calls, objects, triangles] over 1.5 s.
func _measure(rid: RID) -> Array:
	var f0 := Engine.get_frames_drawn()
	var t0 := Time.get_ticks_usec()
	var gpu := 0.0
	var cpu := 0.0
	var proc := 0.0
	var phys := 0.0
	var n := 0
	while Time.get_ticks_usec() - t0 < 1500000:
		await t.get_tree().process_frame
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(rid)
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(rid)
		proc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		n += 1
	var fps := float(Engine.get_frames_drawn() - f0) / ((Time.get_ticks_usec() - t0) / 1000000.0)
	return [fps, gpu / maxf(n, 1), RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME), cpu / maxf(n, 1), proc / maxf(n, 1), phys / maxf(n, 1)]


func _perf_text(r: Array) -> String:
	return "%.0f fps (%.1f ms), GPU %.2f ms, render CPU %.2f ms, process %.2f ms, physics %.2f ms, %d draw calls, %d objects, %.2fM triangles" % [
		r[0], 1000.0 / maxf(float(r[0]), 1.0), r[1], r[5], r[6], r[7], r[2], r[3], float(r[4]) / 1000000.0]


## What the echolocation scanner costs (windowed, vsync off), standing in the room nearest the
## outpost's middle (walls all round within its reach; the aliens frozen where they are): the frame
## rate with it down and held up, held up with its screen drawing nothing, how long drawing its
## screen takes (Scanner.draw_us) and how long one ray of its ping takes, and how many echoes it
## holds.
func run_scanner_perf() -> void:
	var sd := seed_where(func(l): return (l["rooms"] as Array).size() >= 7)
	var m := await start_outpost(sd)
	if m == null:
		print("[autotest] FAIL: the outpost test never started")
		return
	await t.wait(1.0)
	var ship := m.ship
	var p := m.local_player
	p.max_hp = 100000.0
	p.hp = 100000.0
	for c in ship.boarder_root.get_children():
		c.process_mode = Node.PROCESS_MODE_DISABLED
	var layout: Dictionary = m.cave.derelict(ship.derelict_k)["layout"]
	var rooms: Array = layout["rooms"]
	var mid := Vector2(0.0, OutpostLayout.Z0 + OutpostLayout.GZ * OutpostLayout.CELL * 0.5)
	var best := 0
	for ri in rooms.size():
		if (rooms[ri]["c"] as Vector2).distance_to(mid) < (rooms[best]["c"] as Vector2).distance_to(mid):
			best = ri
	var c2: Vector2 = rooms[best]["c"]
	_stand(p, Vector3(c2.x, 0, c2.y), Vector3(c2.x, 1.6, c2.y - 5.0))
	var rid := t.get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(rid, true)
	var vsync := DisplayServer.window_get_vsync_mode()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await t.wait(1.0)
	print("[autotest] scanner perf: seed %d, standing in room %d (%s), %d aliens" % [sd, best, rooms[best]["theme"], ship.boarder_root.get_child_count()])
	print("[autotest] scanner perf: down: %s" % _perf_text(await _measure(rid)))
	Input.action_press("scanner")
	await t.wait(PI)
	var sc: Scanner = p._scanner
	var r := await _measure(rid)
	print("[autotest] scanner perf: up (%s): %s; drawing the screen %.2f ms" % [sc.echo_text(), _perf_text(r), sc.draw_us / 1000.0])
	if sc.get("parts") != null:
		print("[autotest] scanner perf: drawing by part (us): %s" % str(sc.get("parts")))
	await t.shot("scanner_perf")
	# Its screen drawing nothing (Screen._draw returns at once).
	var screen: Scanner.Screen = sc._screen
	screen.scanner = null
	await t.wait(0.4)
	print("[autotest] scanner perf: up, the screen drawing nothing: %s" % _perf_text(await _measure(rid)))
	screen.scanner = sc
	# One ray of the ping on its own, the average over a whole sweep's worth (and what it painted is
	# swept up again by the next real sweep).
	var t0 := Time.get_ticks_usec()
	for i in Scanner.BINS:
		sc._paint(i)
	var ray_us := float(Time.get_ticks_usec() - t0) / Scanner.BINS
	print("[autotest] scanner perf: one ray of the ping %.3f ms (%.1f rays a second: %.2f ms a second)" % [ray_us / 1000.0,
		Scanner.BINS / Scanner.PERIOD, ray_us * Scanner.BINS / Scanner.PERIOD / 1000.0])
	Input.action_release("scanner")
	await t.wait(0.6)
	print("[autotest] scanner perf: down again: %s" % _perf_text(await _measure(rid)))
	DisplayServer.window_set_vsync_mode(vsync)
	RenderingServer.viewport_set_measure_render_time(rid, false)


# --- Sentry turrets ----------------------------------------------------------------------------

## The sentry turrets: one of the outpost test's boxes carried from the pier into the first room (it
## won't open aboard), put down facing the room's far side and opened with F; three aliens in front of
## it and one behind it: what it shoots (and what it leaves alone), the aliens it hurts turning on it,
## its rounds; folding one up and picking it up again; one wrecked (it can't be picked up, it
## sparks). The player waits aboard meanwhile (aliens don't go for crew aboard). Pictures with
## `shots` (sentries; sentries_check: none).
func run_sentries(shots: bool) -> void:
	# (A room with low furniture, so the lines of fire stay clear.)
	var m := await start_outpost(seed_where(func(l): return _open_room(l, ["quarters", "mess"]) >= 0))
	if m == null:
		print("[autotest] FAIL: the outpost test never started")
		return
	await t.wait(1.0)
	var ship := m.ship
	var p := m.local_player
	p.max_hp = 100000.0
	p.hp = 100000.0
	for c in ship.boarder_root.get_children():
		c.queue_free()
	var layout: Dictionary = m.cave.derelict(ship.derelict_k)["layout"]
	var lift := Vector3(0, StationBuilder.LAND_HEIGHT, 0)
	var boxes: Array[Sentry] = []
	for c in ship.cargo_root.get_children():
		if c is Sentry:
			boxes.append(c as Sentry)
	print("[autotest] sentries: %d sentry boxes in the station and on the pier, states %s" % [boxes.size(), str(boxes.map(func(s): return s.s_state))])
	if boxes.is_empty():
		print("[autotest] FAIL: no sentry boxes")
		return
	var s := boxes[0]
	# Picked up on the pier, it won't open aboard.
	_stand(p, s.net_pos + lift + Vector3(0, 0, -1.2), s.net_pos + lift)
	await t.wait(0.4)
	print("[autotest] sentry on the pier: prompt '%s'" % p.prompt)
	if shots:
		await _look_at_sentry(m, s, Vector3(1.6, 1.2, 1.4), "st01_box")
	ship.request_crate_pickup.rpc_id(1, str(s.name))
	await t.wait(0.3)
	p.position = ship.spawn_points()[0]
	await t.wait(0.3)
	ship.request_crate_drop.rpc_id(1, str(s.name), p.position + Vector3(0, SupplyCrate.SIZE.y * 0.5, -0.9), 0.0)
	await t.wait(0.3)
	ship.request_sentry.rpc_id(1, str(s.name), true)
	await t.wait(0.4)
	print("[autotest] put down aboard: carried %s, can open here %s, F: state %d (packed %d)" % [s.carrier != 0, s.can_open_here(), s.s_state, Sentry.PACKED])
	# Into a room: facing its furthest free cell, opened with F.
	var room: Dictionary = layout["rooms"][maxi(_open_room(layout, ["quarters", "mess"]), 0)]
	var cells := OutpostLayout.free_cells(room)
	var mid := Vector2(room["c"])
	# (On the free floor nearest the room's middle: furniture often stands in the middle.)
	var centre := OutpostLayout.cell_pos(cells[0])
	for c: Vector2i in cells:
		var q := OutpostLayout.cell_pos(c)
		if Vector2(q.x, q.z).distance_to(mid) < Vector2(centre.x, centre.z).distance_to(mid):
			centre = q
	var far := centre
	for c: Vector2i in cells:
		if OutpostLayout.cell_pos(c).distance_to(centre) > far.distance_to(centre):
			far = OutpostLayout.cell_pos(c)
	var fwd := (far - centre).normalized()
	var yaw := atan2(-fwd.z, fwd.x)
	ship.request_crate_pickup.rpc_id(1, str(s.name))
	await t.wait(0.3)
	_stand(p, centre - fwd * 1.0, far)
	await t.wait(0.3)
	ship.request_crate_drop.rpc_id(1, str(s.name), centre - lift + Vector3(0, SupplyCrate.SIZE.y * 0.5, 0), yaw)
	await t.wait(0.5)
	_stand(p, centre - fwd * 1.3, centre)
	await t.wait(0.3)
	var eye := p.global_position + ship.global_basis.y * CrewMember.EYE
	var q := PhysicsRayQueryParameters3D.create(eye, eye + p._look_dir_global() * CrewMember.REACH, Game.LAYER_INTERACT | Game.LAYER_INTERIOR | Game.LAYER_STATION)
	q.collide_with_areas = true
	var hit := p.get_world_3d().direct_space_state.intersect_ray(q)
	print("[autotest] sentry set down in %s at %s (wanted %s), carried %s, player at %s; the look ray hits %s; prompt '%s'" % [room["name"],
		(s.net_pos + lift).snapped(Vector3.ONE * 0.01), centre.snapped(Vector3.ONE * 0.01), s.carrier != 0, (p.position + lift).snapped(Vector3.ONE * 0.01),
		str(hit.get("collider", "nothing")) + (" meta %s" % str((hit["collider"] as Object).get_meta_list())) if not hit.is_empty() else "nothing", p.prompt])
	await t._tap("equip")
	await t.wait(0.4)
	var opening := s.s_state
	await t.wait(Sentry.OPEN_TIME + 0.3)
	print("[autotest] F: state %d while opening (opening %d), then %d (active %d); prompt '%s'; solid %s" % [opening, Sentry.OPENING, s.s_state,
		Sentry.ACTIVE, p.prompt, s._body.collision_layer != 0])
	if shots:
		await _look_at_sentry(m, s, Vector3(-1.4, 1.3, 1.6), "st02_open")
	# Aliens: three in front (within its arc), one behind it; the player waits aboard.
	p.position = ship.spawn_points()[0]
	var side := Vector3(-fwd.z, 0, fwd.x)
	# (Free cells of the room: the three furthest in front of it within its arc, and one behind it.)
	var front: Array = []
	var behind := Vector3(INF, 0, 0)
	for c: Vector2i in cells:
		var v := OutpostLayout.cell_pos(c) - centre
		var along := v.dot(fwd)
		if along > 2.0 and absf(v.dot(side)) < along * 0.8:
			front.append([along, OutpostLayout.cell_pos(c)])
		elif along < -1.5 and not behind.is_finite():
			behind = OutpostLayout.cell_pos(c)
	front.sort_custom(func(x, y): return float(x[0]) > float(y[0]))
	var spots: Array = front.slice(0, 3).map(func(e): return e[1])
	while spots.size() < 3:
		spots.append(centre + fwd * (4.0 + spots.size()))
	spots.append(behind if behind.is_finite() else centre - fwd * 2.5)
	var aliens: Array[Boarder] = []
	for sp: Vector3 in spots:
		aliens.append(ship.spawn_hostile("boarder", sp - lift, {"hp": 120.0, "max_hp": 120.0}))
	await t.wait(0.3)
	var rounds0 := s.s_rounds
	var hp0 := s.s_hp
	var turned := {}
	var t0 := Time.get_ticks_msec()
	var snapped := not shots
	while Time.get_ticks_msec() - t0 < 6000:
		await t.get_tree().physics_frame
		for i in aliens.size():
			var a := aliens[i]
			if is_instance_valid(a) and a._target_id == s.get_instance_id():
				turned[i] = true
		if not snapped and s.s_rounds < rounds0 - 8:
			snapped = true
			await _look_at_sentry(m, s, Vector3(-1.2, 1.5, -1.8), "st03_firing")
	var fates := PackedStringArray()
	for i in aliens.size():
		var a := aliens[i]
		fates.append("%s%s" % ["dead" if not is_instance_valid(a) or a.hp <= 0.0 else "hp %.0f" % a.hp, " (went for it)" if turned.has(i) else ""])
	print("[autotest] sentry vs aliens for 6 s: front %s; behind %s; rounds %d -> %d (%.1f a second while firing at most), its health %.0f -> %.0f, display '%s' '%s'" % [
		", ".join(fates.slice(0, 3)), fates[3], rounds0, s.s_rounds, 1.0 / Sentry.FIRE_INTERVAL, hp0, s.s_hp, s._count.text, s._note.text])
	for a in aliens:
		if is_instance_valid(a):
			a.queue_free()
	await t.wait(0.3)
	# Folded up again and picked up.
	_stand(p, centre - fwd * 1.3, centre)
	await t.wait(0.3)
	await t._tap("equip")
	await t.wait(Sentry.OPEN_TIME + 0.4)
	var folded := s.s_state
	await t._tap("interact")
	await t.wait(0.3)
	print("[autotest] F again: state %d (packed %d), rounds kept %d; E: carried %s" % [folded, Sentry.PACKED, s.s_rounds, s.carrier == p.peer_id])
	await t._tap("drop")
	await t.wait(0.4)
	# Wrecked: the damage it can take, then it is bent, sparking and smoking and can't be picked up.
	ship.request_sentry.rpc_id(1, str(s.name), true)
	await t.wait(Sentry.OPEN_TIME + 0.3)
	s.hurt(Sentry.HP + 1.0)
	await t.wait(0.6)
	_stand(p, s.net_pos + lift - fwd * 1.3, s.net_pos + lift)
	await t.wait(0.3)
	var prompt := p.prompt
	await t._tap("interact")
	await t.wait(0.3)
	print("[autotest] wrecked: state %d (wrecked %d), prompt '%s', E: carried %s, smoke %s, display '%s'" % [s.s_state, Sentry.WRECKED, prompt,
		s.carrier != 0, s._smoke.emitting, s._note.text])
	if shots:
		await _look_at_sentry(m, s, Vector3(1.5, 1.2, 1.5), "st04_wreck")
	# Stowed with the station at liftoff and set out again on the next landing.
	var d := m.cave.derelict(ship.derelict_k)
	ship._stow_derelict(d)
	await t.wait(0.4)
	ship._unload_derelict(d)
	await t.wait(0.6)
	var back := PackedStringArray()
	for c in ship.cargo_root.get_children():
		if c is Sentry:
			back.append("%d/%d" % [(c as Sentry).s_state, (c as Sentry).s_rounds])
	print("[autotest] stowed and set out again: sentries (state/rounds) %s" % ", ".join(back))


## The first room of a plan with one of `themes` that no door seals, or -1.
static func _open_room(layout: Dictionary, themes: Array) -> int:
	var rooms: Array = layout["rooms"]
	for ri in rooms.size():
		if str(rooms[ri]["theme"]) in themes and str(rooms[ri]["seal"]) == "":
			return ri
	return -1


## A picture of sentry turret `s` from `off` (in its own frame, metres), looking at its middle.
func _look_at_sentry(m: MissionLevel, s: Sentry, off: Vector3, shot_name: String) -> void:
	var cam := Camera3D.new()
	cam.fov = 55.0
	m.add_child(cam)
	var at := s.global_transform * Vector3(0, 0.25, 0)
	cam.global_position = s.global_transform * off
	cam.look_at(at, m.ship.global_basis.y)
	cam.current = true
	await t.wait(0.25)
	await t.shot(shot_name)
	cam.queue_free()
	await t.wait(0.05)


# --- The control hub ---------------------------------------------------------------------------

## The control hub, in an outpost with a generator and a dead end locked from the hub: the door ids
## (every door but the front door, no two alike) and finding a door by its id; the horde behind the
## locked door; the computer dark and deaf until the power runs; then sat at and typed at through
## the keyboard (HELP, DOORS, a door that isn't there, an unknown command), an open door refused
## with a crate in its doorway, locked (its waypoint off, the map drawn again) and unlocked, the dead
## end opened (its horde hears it), and Esc getting up again without the pause menu. Windowed:
## hub_*.png, the desk dark and lit, the map, the screen, a door's id plate.
func run_hub(shots: bool) -> void:
	var sd := seed_where(func(l): return int(l["hub"]) >= 0 and int(l["generator"]) >= 0 and OutpostLayout._seals(l["rooms"], "hub") > 0)
	var m := await start_outpost(sd)
	if m == null:
		print("[autotest] FAIL: the outpost test never started")
		return
	await t.wait(1.0)
	var ship := m.ship
	var p := m.local_player
	p.max_hp = 100000.0
	p.hp = 100000.0
	var d := m.cave.derelict(ship.derelict_k)
	var layout: Dictionary = d["layout"]
	var rooms: Array = layout["rooms"]
	var doors: Array = layout["doors"]
	var node: Derelict = Derelict.live.get(ship.derelict_k)
	var lift := Vector3(0, StationBuilder.LAND_HEIGHT, 0)
	print("[autotest] hub: seed %d, %s: %s" % [sd, d["name"], ", ".join(rooms.map(func(r): return "%s%s" % [r["theme"],
		("/" + str(r["seal"])) if str(r["seal"]) != "" else ""]))])
	var ids := {}
	for di in range(1, doors.size()):
		ids[str(doors[di]["id"])] = di
	var sealed := -1
	for di in doors.size():
		if str(doors[di]["kind"]) == "hub" and sealed < 0:
			sealed = di
	var sid := str(doors[sealed]["id"])
	print("[autotest] hub: %d doors, %d ids (%s), front door id '%s'; %s by '%s' %d, '%s' %d, '%s' %d, 'D99' %d, 'x1' %d" % [
		doors.size() - 1, ids.size(), ", ".join(ids.keys()), doors[0]["id"], sid, sid.to_lower(), OutpostLayout.door_by_id(layout, sid.to_lower()),
		sid.trim_prefix("D"), OutpostLayout.door_by_id(layout, sid.trim_prefix("D")), sid, OutpostLayout.door_by_id(layout, sid),
		OutpostLayout.door_by_id(layout, "D99"), OutpostLayout.door_by_id(layout, "x1")])
	# The horde behind the locked dead end; every other alien is put away.
	var sroom := int(doors[sealed]["room"])
	var horde: Array[Boarder] = []
	var kinds := {}
	for c in ship.boarder_root.get_children():
		var b := c as Boarder
		if b and OutpostLayout.room_at(layout, b.position + lift) == sroom:
			horde.append(b)
			kinds[b.kind] = int(kinds.get(b.kind, 0)) + 1
		elif b:
			b.queue_free()
	print("[autotest] hub: behind %s (%s): %s; door state %d, slab shape on %s" % [sid, rooms_name(layout, sealed), str(kinds),
		ship.outpost_doors[sealed], not (node.doors[sealed]["shape"] as CollisionShape3D).disabled])
	var console := node.hub_console()
	var desk: Dictionary = {}
	for prop: Dictionary in rooms[int(layout["hub"])]["props"]:
		if str(prop["kind"]) == "hub_desk":
			desk = prop
	var dx := Transform3D(Basis(Vector3.UP, float(desk["yaw"])), desk["pos"])
	var cpos := ship.to_local(console.global_position) + lift
	var front := ship.to_local(console.global_position + console.global_basis.z * 0.95) + lift
	_stand(p, front, cpos + Vector3(0, 0.3, 0))
	await t.wait(0.5)
	var n0 := console.lines.size()
	ship.request_hub_command.rpc_id(1, "help")
	await t.wait(0.3)
	print("[autotest] hub: no power: console powered %s, map shows '%s', prompt '%s', a command -> %d new lines" % [console.powered,
		node._map_key.get_slice("|", 0), p.prompt, console.lines.size() - n0])
	if shots:
		await _hub_view(m, dx, Vector3(0.6, 1.7, 2.6), Vector3(0, 1.9, -0.6), "hub01_dark")
	ship.outpost_power = true
	await t.wait(1.5)
	print("[autotest] hub: power on: console powered %s, map shows '%s', prompt '%s'" % [console.powered, node._map_key.get_slice("|", 0), p.prompt])
	if shots:
		await _hub_view(m, dx, Vector3(0.6, 1.7, 2.6), Vector3(0, 1.9, -0.6), "hub02_desk")
		await _hub_view(m, dx, Vector3(0, 1.72, 0.9), Vector3(0, 1.72, -0.7), "hub03_map")
	await t._tap("interact")
	await t.wait(0.4)
	print("[autotest] hub: at the computer %s, view %.2f m from it, fov %.0f" % [p._hub == console,
		p.camera.global_position.distance_to(console.global_position), p.camera.fov])
	n0 = console.lines.size()
	await _type_line("help")
	await t.wait(0.4)
	print("[autotest] hub: HELP -> %s; on the screen %s" % [" | ".join(console.lines.slice(n0)), console._text.text.contains("COMMANDS:")])
	n0 = console.lines.size()
	await _type_line("doors")
	await t.wait(0.4)
	print("[autotest] hub: DOORS -> %s" % " | ".join(console.lines.slice(n0)))
	n0 = console.lines.size()
	await _type_line("unlock d99")
	await _type_line("hello there")
	await _type_line("lock")
	await t.wait(0.4)
	print("[autotest] hub: bad lines -> %s" % " | ".join(console.lines.slice(n0)))
	if shots:
		await t.shot("hub04_screen")
	# An open door, refused with a crate in its doorway, then locked and unlocked.
	var open_di := -1
	for di in range(1, doors.size()):
		if str(doors[di]["kind"]) == "open" and int(doors[di]["room"]) != int(layout["hub"]) and open_di < 0:
			open_di = di
	var oid := str(doors[open_di]["id"])
	var crate: SupplyCrate = null
	for c in ship.cargo_root.get_children():
		if c is SupplyCrate and not c is Sentry and (c as SupplyCrate).carrier == 0 and crate == null:
			crate = c as SupplyCrate
	var was := crate.net_pos
	crate.net_pos = (doors[open_di]["pos"] as Vector3) - lift + Vector3(0, SupplyCrate.SIZE.y * 0.5, 0)
	await t.wait(0.2)
	n0 = console.lines.size()
	await _type_line("lock " + oid)
	await t.wait(0.4)
	print("[autotest] hub: LOCK %s with a crate in the doorway -> state %d: %s" % [oid, ship.outpost_doors[open_di], " | ".join(console.lines.slice(n0))])
	crate.net_pos = was
	await t.wait(0.2)
	var key0 := node._map_key
	n0 = console.lines.size()
	await _type_line("lock " + oid.to_lower())
	await t.wait(1.0)
	print("[autotest] hub: LOCK %s -> state %d, waypoint off %s, slab shape on %s, map drawn again %s: %s" % [oid, ship.outpost_doors[open_di],
		ship.nav.is_point_disabled(DerelictBuilder.NAV_DOOR + open_di), not (node.doors[open_di]["shape"] as CollisionShape3D).disabled,
		node._map_key != key0, " | ".join(console.lines.slice(n0))])
	if shots:
		var dd: Dictionary = doors[open_di]
		var out := DerelictBuilder.door_outside(dd, 2.6) + Vector3(0, 1.6, 0)
		var cam := Camera3D.new()
		cam.fov = 60.0
		m.add_child(cam)
		_look(cam, ship.global_transform * Transform3D(Basis.IDENTITY, -lift), out, (dd["pos"] as Vector3) + Vector3(0, 2.2, 0))
		cam.current = true
		await t.wait(2.5)
		await t.shot("hub05_locked_door")
		cam.queue_free()
		await t.wait(0.1)
		await _hub_view(m, dx, Vector3(0, 1.72, 0.9), Vector3(0, 1.72, -0.7), "hub06_map_locked")
	n0 = console.lines.size()
	await _type_line("lock " + oid)
	await _type_line("unlock " + oid)
	await t.wait(0.4)
	print("[autotest] hub: again -> %s; state %d, waypoint off %s" % [" | ".join(console.lines.slice(n0)), ship.outpost_doors[open_di],
		ship.nav.is_point_disabled(DerelictBuilder.NAV_DOOR + open_di)])
	# The dead end: opened, and its horde hears it.
	n0 = console.lines.size()
	await _type_line("unlock " + sid)
	await t.wait(0.5)
	var heard := horde.filter(func(b): return is_instance_valid(b) and (b._heard_t > 0.0 or b._target_id != 0)).size()
	print("[autotest] hub: UNLOCK %s -> state %d, %d of the %d shut in heard it: %s" % [sid, ship.outpost_doors[sealed], heard, horde.size(),
		" | ".join(console.lines.slice(n0))])
	await _key(KEY_ESCAPE)
	await t.wait(0.3)
	print("[autotest] hub: Esc -> at the computer %s, pause menu open %s" % [p._hub != null, Game.main.pause_menu.visible])


## A picture of the hub's desk from `eye` (in the desk's frame) looking at `at`.
func _hub_view(m: MissionLevel, dx: Transform3D, eye: Vector3, at: Vector3, shot_name: String) -> void:
	var lift := Vector3(0, StationBuilder.LAND_HEIGHT, 0)
	var cam := Camera3D.new()
	cam.fov = 62.0
	m.add_child(cam)
	_look(cam, m.ship.global_transform * Transform3D(Basis.IDENTITY, -lift), dx * eye, dx * at)
	cam.current = true
	await t.wait(0.4)
	await t.shot(shot_name)
	cam.queue_free()
	await t.wait(0.05)


## Type a line on the keyboard, and Enter.
func _type_line(text: String) -> void:
	for ch in text:
		await _key(KEY_SPACE if ch == " " else OS.find_keycode_from_string(ch.to_upper()), ch.unicode_at(0))
	await _key(KEY_ENTER)


func _key(code: Key, unicode := 0) -> void:
	var ev := InputEventKey.new()
	ev.keycode = code
	ev.physical_keycode = code
	ev.unicode = unicode
	ev.pressed = true
	Input.parse_input_event(ev)
	await t.get_tree().process_frame
	var up := ev.duplicate() as InputEventKey
	up.pressed = false
	Input.parse_input_event(up)
	await t.wait(0.04)


# --- Furniture gallery -------------------------------------------------------------------------

## Every kind of furniture (OutpostLayout.PROPS), built in a studio corner of the landing pad (a
## floor, a back wall and a ceiling 4.8 m up) and pictured from the front at three quarters: pg_<kind>.png.
## Lockers, filing cabinets, specimen tanks and barrels are built in four variants side by side (open
## doors and drawers, drained and smashed tanks, a toppled drum come and go with the variant).
## Windowed.
func run_props_gallery() -> void:
	var m := await start_outpost()
	if m == null:
		print("[autotest] FAIL: the outpost test never started")
		return
	await t.wait(1.0)
	var ship := m.ship
	for c in ship.boarder_root.get_children():
		c.queue_free()
	var node: Derelict = Derelict.live.get(ship.derelict_k)
	var p := m.local_player
	p.position = ship.spawn_points()[0]
	# (Nothing else of the station shows meanwhile, nor the HUD.)
	for c in node.get_children():
		if c is Node3D:
			(c as Node3D).visible = false
	m.hud.visible = false
	var dy := StationBuilder.DECK_Y
	var room_h := 4.8
	var wall_z := -16.6
	var studio := Node3D.new()
	node.add_child(studio)
	var wall_mat := DerelictBuilder.surface_mat("outpost_wall", Color(0.82, 0.85, 0.8), 0.5, true)
	var sx := -13.0
	for box: Array in [[Vector3(sx, dy + room_h + 0.15, -12.5), Vector3(14.0, 0.3, 9.0)], [Vector3(sx, dy + room_h * 0.5, wall_z - 0.15), Vector3(14.0, room_h, 0.3)],
			[Vector3(sx, dy - 0.05, -12.5), Vector3(14.0, 0.1, 9.0)]]:
		Models.box(studio, box[0], box[1], wall_mat)
	var cam := Camera3D.new()
	cam.fov = 50.0
	m.add_child(cam)
	cam.current = true
	var key := OmniLight3D.new()
	key.light_energy = 1.8
	key.omni_range = 12.0
	key.light_color = Color(1.0, 0.86, 0.7)
	studio.add_child(key)
	var fill := OmniLight3D.new()
	fill.light_energy = 0.6
	fill.omni_range = 12.0
	fill.light_color = Color(0.75, 0.82, 1.0)
	studio.add_child(fill)
	var mats := DerelictBuilder._materials()
	var several := ["locker", "filing", "tube", "barrels"]
	for kind: String in OutpostLayout.PROPS:
		var size: Vector3 = OutpostLayout.PROPS[kind]
		var holder := Node3D.new()
		studio.add_child(holder)
		var b := Models.Batch.new()
		var body := StaticBody3D.new()
		holder.add_child(body)
		var out := {"tanks": [], "subjects": [], "screens": [], "generator": {}}
		var count := 4 if kind in several else 1
		var span := (size.x + 0.4) * count
		var mid := Vector3(sx, dy, wall_z + size.z * 0.5 + 0.02)
		for v in count:
			var at := mid + Vector3(-span * 0.5 + (size.x + 0.4) * (v + 0.5), 0, 0)
			if kind in ["tube", "table", "pallet", "generator", "hub_desk", "lab_table", "surgery", "lathe", "weapon_bench"]:
				at.z = wall_z + maxf(size.z, size.x) * 0.5 + 0.8
			var pd := {"kind": kind, "size": size, "pos": at, "yaw": 0.0, "var": v + 2}
			OutpostProps.build(holder, b, body, pd, mats, out, room_h)
		b.commit(holder, "Props")
		var extent := maxf(span, maxf(size.y, size.z))
		var look := mid + Vector3(0, minf(size.y, 3.0) * 0.45, (size.z * 0.5) if kind != "generator" else 1.6)
		# (From the left: the ship stands off to the right.)
		var eye := look + Vector3(-0.5, 0.38, 1.0).normalized() * (extent * 0.95 + 1.0)
		cam.global_transform = node.global_transform * Transform3D(Basis.looking_at(look - eye, Vector3.UP), eye)
		key.position = eye + Vector3(1.0, 1.5, -0.5)
		fill.position = look + Vector3(extent * 0.8, 1.0, extent * 0.6)
		await t.wait(0.6)
		await t.shot("pg_%s" % kind)
		holder.free()
	cam.queue_free()
	studio.queue_free()
	m.hud.visible = true


## The generator alone in a studio on the pad, from each side, its control box and starter close up,
## and the starter pulled out: gen_<view>.png (windowed).
func run_generator_views() -> void:
	var m := await start_outpost()
	if m == null:
		print("[autotest] FAIL: the outpost test never started")
		return
	await t.wait(1.0)
	var ship := m.ship
	for c in ship.boarder_root.get_children():
		c.queue_free()
	var node: Derelict = Derelict.live.get(ship.derelict_k)
	m.local_player.position = ship.spawn_points()[0]
	for c in node.get_children():
		if c is Node3D:
			(c as Node3D).visible = false
	m.hud.visible = false
	# (The ship's side pods stand where some of the views look from.)
	ship.exterior.visible = false
	var dy := StationBuilder.DECK_Y
	var studio := Node3D.new()
	node.add_child(studio)
	var wall_mat := DerelictBuilder.surface_mat("outpost_wall", Color(0.82, 0.85, 0.8), 0.5, true)
	var mid := Vector3(-13.0, dy, -9.0)
	Models.box(studio, mid + Vector3(0, -0.05, 0), Vector3(14.0, 0.1, 14.0), wall_mat)
	var cam := Camera3D.new()
	cam.fov = 50.0
	m.add_child(cam)
	cam.current = true
	var lights: Array[OmniLight3D] = []
	for i in 3:
		var l := OmniLight3D.new()
		l.light_energy = 2.4 if i == 0 else 1.2
		l.omni_range = 14.0
		l.light_color = Color(1.0, 0.86, 0.7) if i == 0 else Color(0.8, 0.85, 1.0)
		studio.add_child(l)
		lights.append(l)
	var b := Models.Batch.new()
	var body := StaticBody3D.new()
	studio.add_child(body)
	var out := {"tanks": [], "subjects": [], "screens": [], "generator": {}}
	var size: Vector3 = OutpostLayout.PROPS["generator"]
	OutpostProps.build(studio, b, body, {"kind": "generator", "size": size, "pos": mid, "yaw": 0.0, "var": 3}, DerelictBuilder._materials(), out, 5.2)
	b.commit(studio, "Props")
	var g: Dictionary = out["generator"]
	# [name, eye, look] in the piece's frame (its +x side carries the control box and the starter).
	for v: Array in [["side_x", Vector3(5.2, 2.2, 1.8), Vector3(0.6, 1.0, -0.2)], ["front_x", Vector3(3.8, 1.9, 4.6), Vector3(0.4, 1.0, 0.4)],
			["back_x", Vector3(3.6, 2.0, -5.0), Vector3(0.3, 1.0, -0.8)], ["side_minus_x", Vector3(-5.2, 2.2, 0.8), Vector3(-0.5, 1.0, -0.2)],
			["close_ctrl", Vector3(2.6, 1.45, 0.25), Vector3(1.05, 0.85, -0.25)], ["top", Vector3(1.8, 6.5, 0.4), Vector3(0.0, 0.5, -0.2)]]:
		var eye: Vector3 = mid + (v[1] as Vector3)
		var look: Vector3 = mid + (v[2] as Vector3)
		cam.global_transform = node.global_transform * Transform3D(Basis.looking_at(look - eye, Vector3.UP), eye)
		lights[0].position = eye + Vector3(0.5, 1.5, 0.5)
		lights[1].position = mid + Vector3(-4.0, 3.0, 3.0)
		lights[2].position = mid + Vector3(3.0, 3.0, -4.0)
		await t.wait(0.5)
		await t.shot("gen_%s" % v[0])
	# The starter pulled out (as the Derelict animates it: the handle along the cord).
	var handle: Node3D = g["handle"]
	var hrest: Transform3D = g["handle_rest"]
	handle.transform = hrest.translated((g["outward"] as Vector3) * 0.55)
	var cord: Node3D = g["cord"]
	cord.scale = Vector3(1.0, 1.0 + 3.6, 1.0)
	cord.position.x = -0.08 - 0.29
	var eye2: Vector3 = mid + Vector3(2.9, 1.5, 1.4)
	var look2: Vector3 = mid + Vector3(1.0, 0.85, 0.2)
	cam.global_transform = node.global_transform * Transform3D(Basis.looking_at(look2 - eye2, Vector3.UP), eye2)
	await t.wait(0.5)
	await t.shot("gen_pulled")
	cam.queue_free()
	studio.queue_free()
	m.hud.visible = true
	ship.exterior.visible = true


# --- Mechanics -----------------------------------------------------------------------------------

## The outpost's mechanics with the local player (a tough one): the generator's starter, a keypad
## lock (a wrong code, a key pressed by looking at it, the right code, walking through), a lockdown,
## a barnacle catching the player, the stalker's visit, the crawlers keeping to their patch and
## turning on a shooter, and an acid spider moving and spitting. `shots`: pictures along the way.
func run_check(shots: bool) -> void:
	var sd := seed_where(func(l): return int(l["generator"]) >= 0 and OutpostLayout._seals(l["rooms"], "hack") > 0 \
		and OutpostLayout._seals(l["rooms"], "power") > 0)
	var m := await start_outpost(sd)
	if m == null:
		print("[autotest] FAIL: the outpost test never started")
		return
	await t.wait(1.0)
	var ship := m.ship
	var p := m.local_player
	var tough := ship.stats.duplicate()
	tough["crew_hp"] = 5000.0
	ship.stats = tough
	await t.wait(0.2)
	var d := m.cave.derelict(ship.derelict_k)
	var layout: Dictionary = d["layout"]
	var node: Derelict = Derelict.live.get(ship.derelict_k)
	var rooms: Array = layout["rooms"]
	print("[autotest] check: seed %d, %s: %s" % [sd, d["name"], ", ".join(rooms.map(func(r): return "%s%s" % [r["theme"],
		("/" + str(r["seal"])) if str(r["seal"]) != "" else ""]))])
	var kinds := {}
	for c in ship.boarder_root.get_children():
		var b := c as Boarder
		kinds[b.kind] = int(kinds.get(b.kind, 0)) + 1
	var items := PackedStringArray()
	for c in ship.cargo_root.get_children():
		var crate := c as SupplyCrate
		if not RunItems.is_crew_weapon(crate.item) or (crate.net_pos.z + StationBuilder.LAND_HEIGHT) > DerelictBuilder.FACADE_Z:
			items.append(crate.item)
	print("[autotest] check: aliens %s; salvage in the station: %s" % [str(kinds), ", ".join(items)])
	# The rest needs a quiet station: put its aliens away.
	for c in ship.boarder_root.get_children():
		c.queue_free()
	await t.wait(0.3)
	await _check_generator(m, layout, node, shots)
	await _check_keypad(m, layout, node, shots)
	await _check_barnacle(m, layout, shots)
	await _check_stalker(m, layout, shots)
	await _check_crawlers(m, layout, shots)
	await _check_spider(m, layout, shots)
	await _check_credits(m, shots)
	await _check_shut_door(m, layout)
	await _check_walls(m, layout)


const FLOOR_Y := StationBuilder.DECK_Y - StationBuilder.LAND_HEIGHT + 0.05


## Put the player on the floor at station-local `at`, looking at station-local `look`.
func _stand(p: CrewMember, at: Vector3, look: Vector3) -> void:
	var lift := Vector3(0, StationBuilder.LAND_HEIGHT, 0)
	p.position = Vector3(at.x, FLOOR_Y, at.z)
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()
	t._face(p, look - lift)


func _lit(node: Derelict) -> int:
	var n := 0
	for l: Dictionary in node.lamps:
		if float(l["on"]) > 0.5:
			n += 1
	return n


func _check_generator(m: MissionLevel, layout: Dictionary, node: Derelict, shots: bool) -> void:
	var ship := m.ship
	var p := m.local_player
	var gen := ship.to_local(node.generator_spot()) + Vector3(0, StationBuilder.LAND_HEIGHT, 0)
	var rec: Dictionary = node._gen
	var out: Vector3 = rec["outward"]
	var handle := (rec["handle"] as Node3D).global_position
	var handle_l := ship.to_local(handle) + Vector3(0, StationBuilder.LAND_HEIGHT, 0)
	_stand(p, handle_l + out * 1.0, handle_l)
	await t.wait(0.4)
	var power_doors: Array = []
	for di in (layout["doors"] as Array).size():
		if str(layout["doors"][di]["kind"]) == "power":
			power_doors.append(di)
	var lit0 := _lit(node)
	print("[autotest] generator: prompt '%s', lamps lit %d of %d, power doors %s closed %s, on the graph %s" % [p.prompt, lit0, node.lamps.size(),
		str(power_doors), str(power_doors.map(func(di): return ship.outpost_doors[di] == Derelict.DOOR_CLOSED)),
		str(power_doors.map(func(di): return not ship.nav.is_point_disabled(DerelictBuilder.NAV_DOOR + di)))])
	if shots:
		await t.shot("oc01_generator_off")
	var pulls := 0
	while not ship.outpost_power and pulls < 5:
		await t._tap("interact")
		pulls += 1
		await t.wait(0.5)
		print("[autotest] generator: pull %d: power %s" % [pulls, ship.outpost_power])
	await t.wait(4.0)
	var lit1 := _lit(node)
	print("[autotest] generator: running after %d pulls: %s, lamps lit %d -> %d, prompt '%s', power doors open %s, on the graph %s" % [pulls,
		ship.outpost_power, lit0, lit1, p.prompt, str(power_doors.map(func(di): return ship.outpost_doors[di] == Derelict.DOOR_OPEN)),
		str(power_doors.map(func(di): return not ship.nav.is_point_disabled(DerelictBuilder.NAV_DOOR + di)))])
	if shots:
		await t.shot("oc02_generator_on")


func _check_keypad(m: MissionLevel, layout: Dictionary, node: Derelict, shots: bool) -> void:
	var ship := m.ship
	var p := m.local_player
	var doors: Array = layout["doors"]
	var hack: Array = []
	for di in doors.size():
		if str(doors[di]["kind"]) == "hack":
			hack.append(di)
	var di: int = hack[0]
	var panel := node.panel_of(di)
	var lift := Vector3(0, StationBuilder.LAND_HEIGHT, 0)
	var front := ship.to_local(panel.global_position + panel.global_basis.z * 1.0) + lift
	_stand(p, front, ship.to_local(panel.global_position) + lift)
	await t.wait(0.4)
	print("[autotest] keypad: door %d (%s), code %s; prompt '%s'" % [di, rooms_name(layout, di), doors[di]["code"], p.prompt])
	await t._tap("interact")
	await t.wait(0.5)
	print("[autotest] keypad: in the panel %s, prompt '%s', view %.2f m from the panel" % [p._panel == panel, p.prompt,
		p.camera.global_position.distance_to(panel.global_position)])
	if shots:
		await t.shot("oc03_panel")
	# A wrong code, typed.
	var code := str(doors[di]["code"])
	var wrong := ""
	for ch in code:
		wrong += str((int(ch) + 1) % 10)
	await _type(wrong)
	await t.wait(0.8)
	print("[autotest] keypad: wrong code %s -> tries %d, door state %d, display '%s'" % [wrong, ship.outpost_tries[di], ship.outpost_doors[di],
		panel._display.text])
	# A key pressed by looking at it and clicking.
	var key: Dictionary = panel._keys[4]
	var eye := panel.view_transform()
	var at: Vector3 = panel.to_global(Vector3((key["centre"] as Vector2).x, (key["centre"] as Vector2).y, HackPanel.DEPTH + 0.02))
	var local := eye.basis.inverse() * (at - eye.origin)
	p._panel_look = Vector2(atan2(-local.x, -local.z), atan2(local.y, Vector2(local.x, local.z).length()))
	await t.wait(0.2)
	await t._tap("fire")
	print("[autotest] keypad: looked at key '%s' and clicked: keyed '%s'" % [key["label"], panel.typed])
	panel.press("C")
	await _type(code)
	await t.wait(0.8)
	print("[autotest] keypad: right code %s -> door state %d (open %s), on the graph %s, still in the panel %s" % [code, ship.outpost_doors[di],
		ship.outpost_doors[di] == Derelict.DOOR_OPEN, not ship.nav.is_point_disabled(DerelictBuilder.NAV_DOOR + di), p._panel != null])
	await t.wait(3.5)
	# Walk through.
	var dd: Dictionary = doors[di]
	_stand(p, DerelictBuilder.door_outside(dd, 2.0), DerelictBuilder.door_inside(dd, 3.0) + Vector3(0, 1.6, 0))
	await t.wait(0.3)
	if shots:
		await t.shot("oc04_door_open")
	Input.action_press("move_forward")
	await t.wait(1.4)
	Input.action_release("move_forward")
	var room := OutpostLayout.room_at(layout, p.position + lift)
	print("[autotest] keypad: walked through into room %d (the door's %d)" % [room, int(dd["room"])])
	# A lockdown: the door shut again, three wrong codes.
	ship._set_door(di, Derelict.DOOR_CLOSED)
	var tries := ship.outpost_tries.duplicate()
	tries[di] = 0
	ship.outpost_tries = tries
	await t.wait(3.5)
	_stand(p, front, ship.to_local(panel.global_position) + lift)
	await t.wait(0.3)
	await t._tap("interact")
	await t.wait(0.4)
	for i in 3:
		await _type(wrong)
		await t.wait(0.7)
		if p._panel == null and i < 2:
			await t._tap("interact")
			await t.wait(0.3)
	await t.wait(1.0)
	var rec: Dictionary = node.doors[di]
	print("[autotest] lockdown: door state %d (lockdown %s), tries %d, shutter down %.2f, its collision %s, alarm light %s, on the graph %s, prompt '%s', in the panel %s" % [
		ship.outpost_doors[di], ship.outpost_doors[di] == Derelict.DOOR_LOCKDOWN, ship.outpost_tries[di], float(rec["drop"]),
		not (rec["shutter_shape"] as CollisionShape3D).disabled, (rec["alarm"] as OmniLight3D).visible,
		not ship.nav.is_point_disabled(DerelictBuilder.NAV_DOOR + di), p.prompt, p._panel != null])
	ship.request_hack.rpc_id(1, di, code)
	await t.wait(0.4)
	print("[autotest] lockdown: the right code afterwards changes nothing: state %d" % ship.outpost_doors[di])
	if shots:
		_stand(p, front + Vector3(0.6, 0, 0.6), DerelictBuilder.door_inside(dd, -0.3) + Vector3(0, 1.4, 0))
		await t.wait(0.5)
		await t.shot("oc05_lockdown")


func rooms_name(layout: Dictionary, di: int) -> String:
	var r := int(layout["doors"][di]["room"])
	return str(layout["rooms"][r]["name"]) if r >= 0 else "front"


## Key a code in through the keyboard (the number keys).
func _type(code: String) -> void:
	for ch in code:
		var ev := InputEventKey.new()
		ev.keycode = KEY_0 + int(ch)
		ev.pressed = true
		Input.parse_input_event(ev)
		await t.get_tree().process_frame
		var up := ev.duplicate() as InputEventKey
		up.pressed = false
		Input.parse_input_event(up)
		await t.wait(0.08)


## A free corridor cell with nothing above it for a few metres either way (station-local floor).
func _corridor_spot(layout: Dictionary) -> Vector3:
	var best := Vector2i(-1, -1)
	for c: Vector2i in OutpostLayout.corridor_cells(layout):
		var bits := DerelictBuilder._hall_opens(layout, c)
		if (bits == 3 or bits == 12) and c.y > 2:
			best = c
			break
	return OutpostLayout.cell_pos(best if best.x >= 0 else OutpostLayout.corridor_cells(layout)[3])


func _check_barnacle(m: MissionLevel, layout: Dictionary, shots: bool) -> void:
	var ship := m.ship
	var p := m.local_player
	var lift := Vector3(0, StationBuilder.LAND_HEIGHT, 0)
	var spot := _corridor_spot(layout)
	var along := _corridor_axis(layout, spot)
	var b := ship.spawn_hostile("barnacle", spot + Vector3(0, OutpostLayout.CORRIDOR_H - 0.02, 0) - lift, {"hp": 120.0})
	_stand(p, spot + along * 2.2, spot + Vector3(0, 1.0, 0))
	await t.wait(0.6)
	var hp0 := p.hp
	print("[autotest] barnacle: 2.2 m off: caught %s, its tongue out %s" % [b.grab == p.peer_id, b._tongue.visible])
	if shots:
		_stand(p, spot + along * 2.6, spot + Vector3(0, OutpostLayout.CORRIDOR_H - 0.3, 0))
		await t.wait(0.3)
		await t.shot("oc06a_barnacle_hidden")
	# Walking by 1.6 m off: it lashes out and reels them in.
	_stand(p, spot + along * 1.55 + along.cross(Vector3.UP) * 0.4, spot + Vector3(0, 3.0, 0))
	var t0 := Time.get_ticks_msec()
	var t_grab := -1.0
	var t_in := -1.0
	for i in 60:
		await t.wait(0.05)
		var now := (Time.get_ticks_msec() - t0) / 1000.0
		if b.grab == p.peer_id and t_grab < 0.0:
			t_grab = now
		if t_grab >= 0.0 and t_in < 0.0 and Vector2(p.position.x - b.position.x, p.position.z - b.position.z).length() < 0.1:
			t_in = now
	var caught := b.grab == p.peer_id
	var at := p.position
	Input.action_press("move_back")
	await t.wait(1.2)
	Input.action_release("move_back")
	print("[autotest] barnacle: walked by 1.6 m off: caught %s after %.2f s, reeled in under it after %.2f s, prompt '%s', tried to walk away for 1.2 s: moved %.2f m, held %.2f m off the floor, hp %.0f -> %.0f" % [
		caught, t_grab, t_in, p.prompt, Vector2(p.position.x - at.x, p.position.z - at.z).length(), p.position.y - FLOOR_Y + 0.05, hp0, p.hp])
	if shots:
		await t.shot("oc06_barnacle")
	b.take_damage(500.0, {"by": p.peer_id})
	await t.wait(0.4)
	at = p.position
	Input.action_press("move_back")
	await t.wait(0.8)
	Input.action_release("move_back")
	print("[autotest] barnacle: shot dead: free again, walked %.2f m" % Vector2(p.position.x - at.x, p.position.z - at.z).length())
	# Through a wall: over a corridor, the player in the room the other side of its wall.
	var pair := _wall_pair(layout)
	if pair.is_empty():
		print("[autotest] barnacle: no corridor along a room's wall here")
		return
	var cc := OutpostLayout.cell_pos(pair[0])
	var rc := OutpostLayout.cell_pos(pair[1])
	var dir := (rc - cc).normalized()
	var b2 := ship.spawn_hostile("barnacle", cc + dir * 0.9 + Vector3(0, OutpostLayout.ceiling(layout, pair[0]) - 0.02, 0) - lift, {"hp": 120.0})
	_stand(p, rc - dir * 0.6, rc + Vector3(0, 1.4, 0))
	await t.wait(1.5)
	print("[autotest] barnacle: over a corridor, the player %.1f m off in the room the other side of its wall: caught %s" % [
		Vector2(p.position.x - b2.position.x, p.position.z - b2.position.z).length(), b2.grab == p.peer_id])
	b2.queue_free()


## Which way a straight corridor cell at station-local `spot` runs.
func _corridor_axis(layout: Dictionary, spot: Vector3) -> Vector3:
	return Vector3(1, 0, 0) if DerelictBuilder._hall_opens(layout, OutpostLayout.cell_at(spot)) == 3 else Vector3(0, 0, 1)


## A corridor cell and a room cell next to it with a plain wall between them, or [].
func _wall_pair(layout: Dictionary) -> Array:
	var kind: PackedByteArray = layout["kind"]
	for c: Vector2i in OutpostLayout.corridor_cells(layout):
		for dir: Vector2i in OutpostLayout.DIRS:
			var n := c + dir
			if OutpostLayout.inside(n) and kind[OutpostLayout.idx(n)] == OutpostLayout.ROOM and DerelictBuilder._door_between(layout, c, n) < 0:
				return [c, n]
	return []


func _check_stalker(m: MissionLevel, layout: Dictionary, shots: bool) -> void:
	var ship := m.ship
	var p := m.local_player
	var lift := Vector3(0, StationBuilder.LAND_HEIGHT, 0)
	# In the open: the player in a corridor, the stalker in sight down it.
	var spot := _corridor_spot(layout)
	var run := _run_from(layout, OutpostLayout.cell_at(spot))
	var far: Vector3 = OutpostLayout.cell_pos(run[run.size() - 1])
	_stand(p, spot, far + Vector3(0, 1.4, 0))
	var s := ship.spawn_hostile("stalker", far - lift, {"lair": far - lift}) as Stalker
	var states := PackedStringArray()
	var names := ["roam", "rush", "claw", "retreat", "hide", "flee", "recover"]
	var last := -1
	var taken := 0.0
	var hits := 0
	var last_hp := p.hp
	var t0 := Time.get_ticks_msec()
	var shot_rush := false
	var furthest := 0.0
	while Time.get_ticks_msec() - t0 < 30000:
		await t.wait(0.1)
		if not is_instance_valid(s):
			break
		if s.mode != last:
			last = s.mode
			states.append("%s@%.1f" % [names[last], (Time.get_ticks_msec() - t0) / 1000.0])
		if p.hp < last_hp - 0.5:
			hits += 1
			taken += last_hp - p.hp
		last_hp = p.hp
		if s.mode == Stalker.HIDE:
			furthest = maxf(furthest, s.position.distance_to(p.position))
		if shots and not shot_rush and s.mode == Stalker.CLAW:
			shot_rush = true
			await t.shot("oc07_stalker")
	print("[autotest] stalker: states %s; clawed %d times for %.0f damage; hid %.1f m away" % [" ".join(states), hits, taken, furthest])
	# Badly hurt: it flees and heals out of the way.
	if is_instance_valid(s):
		_stand(p, far, far + Vector3(0, 1.4, 0))
		s.take_damage(s.max_hp * 0.7, {"by": p.peer_id})
		await t.wait(0.2)
		var mode_hurt: String = names[s.mode]
		_stand(p, OutpostLayout.cell_pos(Vector2i(OutpostLayout.MID, 0)) + Vector3(0, 0, -1.0), Vector3(0, 1.4, DerelictBuilder.FACADE_Z))
		p.position = Vector3(0, FLOOR_Y, StationBuilder.PIER_START + 1.0 - StationBuilder.LAND_HEIGHT * 0.0)
		var hp_low := s.hp
		await t.wait(12.0)
		print("[autotest] stalker: hurt to %.0f%%: %s, then %s; health %.0f -> %.0f (of %.0f)" % [hp_low / s.max_hp * 100.0, mode_hurt, names[s.mode],
			hp_low, s.hp, s.max_hp])
		s.queue_free()


## The straight run of linked corridor from cell c (the longer way).
func _run_from(layout: Dictionary, c: Vector2i) -> Array:
	var best := [c]
	for dir in OutpostLayout.DIRS:
		var run := [c]
		var n := c
		while DerelictBuilder._open_edge(layout, n, n + dir):
			n += dir
			run.append(n)
		if run.size() > best.size():
			best = run
	return best


func _check_crawlers(m: MissionLevel, layout: Dictionary, shots: bool) -> void:
	var ship := m.ship
	var p := m.local_player
	var lift := Vector3(0, StationBuilder.LAND_HEIGHT, 0)
	var rooms: Array = layout["rooms"]
	var ri := 1
	for i in range(1, rooms.size()):
		if str(rooms[i]["seal"]) == "" and (rooms[i]["cells"] as Array).size() > (rooms[ri]["cells"] as Array).size():
			ri = i
	var room: Dictionary = rooms[ri]
	var mid := Vector3((room["c"] as Vector2).x, StationBuilder.DECK_Y, (room["c"] as Vector2).y)
	var slot: Dictionary = OutpostLayout.wall_slots(layout, ri)[0]
	var hive := ship.spawn_hostile("hive", (slot["pos"] as Vector3) + Vector3(0, 1.2, 0) - lift, {"hive_id": 99, "brood": 4, "up": slot["inward"]})
	var pack: Array[Crawler] = []
	var cells := OutpostLayout.free_cells(room)
	for i in 4:
		pack.append(ship.spawn_hostile("crawler", OutpostLayout.cell_pos(cells[i % cells.size()]) - lift, {"hive_id": 99, "hp": 400.0}) as Crawler)
	# Outside its patch: the player well off, in the corridor outside the room's door.
	var door: Dictionary = layout["doors"][(room["doors"] as Array)[0]]
	var outside := DerelictBuilder.door_outside(door, 2.5)
	var hive_at := hive.position + lift
	_stand(p, outside, mid + Vector3(0, 1.0, 0))
	var hp0 := p.hp
	await t.wait(5.0)
	var dist := 0.0
	for c in pack:
		dist = maxf(dist, (c.body_pos() + lift).distance_to(hive_at))
	print("[autotest] crawlers: the player %.1f m from the nest, outside the room: hp %.0f -> %.0f, the pack within %.1f m of the nest" % [
		Vector3(outside.x, hive_at.y, outside.z).distance_to(hive_at), hp0, p.hp, dist])
	# In the room: they leap.
	_stand(p, mid, hive_at)
	hp0 = p.hp
	var leaps := 0
	var surfaces := {}
	var was := {}
	var t0 := Time.get_ticks_msec()
	var shot_leap := false
	while Time.get_ticks_msec() - t0 < 10000:
		await t.wait(0.05)
		for c in pack:
			if not is_instance_valid(c):
				continue
			surfaces[["floor", "wall", "ceiling"][c.surface()]] = true
			if c.mode == Crawler.LEAP and int(was.get(c, 0)) != Crawler.LEAP:
				leaps += 1
				if shots and not shot_leap:
					shot_leap = true
					await t.shot("oc08_crawler_leap")
			was[c] = c.mode
	print("[autotest] crawlers: 10 s in their room: %d leaps, hp %.0f -> %.0f, surfaces %s" % [leaps, hp0, p.hp, str(surfaces.keys())])
	# Shot at: they hunt the shooter out of the room (but not past HUNT_RADIUS).
	pack[0].take_damage(1.0, {"by": p.peer_id})
	var away := DerelictBuilder.door_outside(door, 7.0)
	_stand(p, away, mid)
	await t.wait(6.0)
	var chase := 0.0
	for c in pack:
		if is_instance_valid(c):
			chase = maxf(chase, (c.position + lift).distance_to(hive_at))
	print("[autotest] crawlers: shot one, the player went %.1f m from the nest: angry %s, the pack came out to %.1f m" % [
		Vector3(away.x, hive_at.y, away.z).distance_to(hive_at), pack[1]._angry > 0.0, chase])
	for c in pack:
		if is_instance_valid(c):
			c.queue_free()
	hive.queue_free()


func _check_spider(m: MissionLevel, layout: Dictionary, shots: bool) -> void:
	var ship := m.ship
	var p := m.local_player
	var lift := Vector3(0, StationBuilder.LAND_HEIGHT, 0)
	var rooms: Array = layout["rooms"]
	var room: Dictionary = rooms[0]
	var cells := OutpostLayout.free_cells(room)
	var a := OutpostLayout.cell_pos(cells[0])
	var b := a
	for c in cells:
		var q := OutpostLayout.cell_pos(c)
		if absf(q.distance_to(a) - 8.0) < absf(b.distance_to(a) - 8.0):
			b = q
	_stand(p, a, b + Vector3(0, 1.0, 0))
	print("[autotest] spider: put %.1f m from the player" % a.distance_to(b))
	var sp := ship.spawn_hostile("spider", b - lift, {"hp": 500.0}) as Spider
	var hp0 := p.hp
	var spits := 0
	var last := -1
	var surfaces := {}
	var moved := 0.0
	var at := sp.body_pos()
	var t0 := Time.get_ticks_msec()
	var shot_wall := false
	var longest := 0.0
	while Time.get_ticks_msec() - t0 < 12000:
		await t.wait(0.05)
		for i in 4:
			longest = maxf(longest, (sp._shins[i] as Node3D).transform.basis.y.length() - Spider.SHIN)
			longest = maxf(longest, (sp._thighs[i] as Node3D).transform.basis.y.length() - Spider.THIGH)
		if sp.mode == Spider.RECOVER_M and last != Spider.RECOVER_M:
			spits += 1
			moved += sp.body_pos().distance_to(at)
			at = sp.body_pos()
		last = sp.mode
		surfaces[["floor", "wall", "ceiling"][sp.surface()]] = true
		if shots and not shot_wall and sp.surface() != 0 and Time.get_ticks_msec() - t0 > 2000:
			shot_wall = true
			t._face(p, sp.body_pos())
			await t.wait(0.1)
			await t.shot("oc09_spider")
	print("[autotest] spider: 12 s: %d spits, it moved %.1f m between them on average, surfaces %s, hp %.0f -> %.0f" % [spits,
		moved / maxf(spits, 1.0), str(surfaces.keys()), hp0, p.hp])
	print("[autotest] spider: legs: a foot out of reach in %d of %d frames (%.1f%%, by %.2f m at most); thighs and shins drawn at most %.3f m longer than they are" % [
		sp.legs_reaching, sp.legs_frames, 100.0 * sp.legs_reaching / maxf(sp.legs_frames, 1.0), sp.legs_over, longest])
	sp.queue_free()


## Credit boxes: how many the station holds, and one picked up on the pier, carried aboard and put
## down there paying into the dive's credits.
func _check_credits(m: MissionLevel, shots: bool) -> void:
	var ship := m.ship
	var p := m.local_player
	var lift := Vector3(0, StationBuilder.LAND_HEIGHT, 0)
	var worth := PackedStringArray()
	for c in ship.cargo_root.get_children():
		var crate := c as SupplyCrate
		if crate and RunItems.is_credits(crate.item):
			worth.append(str(RunItems.credits_of(crate.item)))
	var at := Vector3(0, StationBuilder.DECK_Y + SupplyCrate.SIZE.y * 0.5, 19.2)
	ship.cargo_spawner.spawn({"name": "CBX", "item": RunItems.credits_item(120), "price": 0, "pos": at - lift, "yaw": 0.0})
	await t.wait(0.3)
	var box := ship.cargo_root.get_node("CBX") as SupplyCrate
	_stand(p, at + Vector3(0, 0, -1.5), at)
	await t.wait(0.4)
	if shots:
		await t.shot("oc10_credit_box")
	var prompt0 := p.prompt
	await t._tap("interact")
	await t.wait(0.4)
	var carried := box.carrier == p.peer_id
	var hud := m.hud._carry_label.text.replace("\n", " / ") if m.hud and m.hud.get("_carry_label") else "?"
	p.position = ship.spawn_points()[0]
	p.velocity = Vector3.ZERO
	p.reset_physics_interpolation()
	await t.wait(0.5)
	var prompt1 := p.prompt
	var credits0 := ship.credits
	await t._tap("drop")
	await t.wait(0.5)
	print("[autotest] credits: the station holds %d credit boxes (%s CR); at the box '%s'; carried %s ('%s'); aboard: '%s'; put down: credits %d -> %d, the box gone %s" % [
		worth.size(), ", ".join(worth), prompt0, carried, hud, prompt1, credits0, ship.credits, not is_instance_valid(box) or box.is_queued_for_deletion()])


## Aliens a few metres from the player but behind a shut door: they mustn't notice the player (nor
## come for them) until it opens.
func _check_shut_door(m: MissionLevel, layout: Dictionary) -> void:
	var ship := m.ship
	var p := m.local_player
	var lift := Vector3(0, StationBuilder.LAND_HEIGHT, 0)
	var doors: Array = layout["doors"]
	var di := -1
	for i in doors.size():
		if str(doors[i]["kind"]) in ["hack", "power"] and ship.outpost_doors[i] != Derelict.DOOR_OPEN:
			di = i
			break
	if di < 0:
		for i in doors.size():
			if str(doors[i]["kind"]) in ["hack", "power"]:
				di = i
				ship._set_door(i, Derelict.DOOR_CLOSED)
				break
	if di < 0:
		print("[autotest] shut door: no door to shut here")
		return
	var dd: Dictionary = doors[di]
	await t.wait(3.0)
	var across := (dd["normal"] as Vector3).cross(Vector3.UP)
	_stand(p, DerelictBuilder.door_outside(dd, 1.2), DerelictBuilder.door_inside(dd, 3.0) + Vector3(0, 1.4, 0))
	var aliens: Array[Boarder] = []
	aliens.append(ship.spawn_hostile("stalker", DerelictBuilder.door_inside(dd, 2.6) - lift, {"hp": 5000.0}))
	aliens.append(ship.spawn_hostile("spider", DerelictBuilder.door_inside(dd, 2.0) + across * 0.9 - lift, {"hp": 5000.0, "dmg": 0.0}))
	aliens.append(ship.spawn_hostile("crawler", DerelictBuilder.door_inside(dd, 1.8) - across * 0.9 - lift, {"hp": 5000.0}))
	await t.wait(0.2)
	var d0 := PackedStringArray()
	for a in aliens:
		d0.append("%s %.1f m" % [a.kind, (a.position + lift).distance_to(p.position + lift)])
	await t.wait(6.0)
	var noticed := PackedStringArray()
	var nearest := INF
	for a in aliens:
		if a._target_id != 0 or (a is Stalker and (a as Stalker)._state == Stalker.RUSH):
			noticed.append(a.kind)
		nearest = minf(nearest, Vector2(a.position.x - p.position.x, a.position.z - p.position.z).length())
	print("[autotest] shut door: door %d (%s, state %d), the player outside it, aliens behind it: %s; after 6 s noticed by %s, the nearest %.1f m off" % [
		di, dd["kind"], ship.outpost_doors[di], ", ".join(d0), str(noticed), nearest])
	ship._set_door(di, Derelict.DOOR_OPEN)
	await t.wait(4.0)
	noticed.clear()
	for a in aliens:
		if is_instance_valid(a) and (a._target_id != 0 or (a is Stalker and (a as Stalker)._state != Stalker.ROAM)):
			noticed.append(a.kind)
	print("[autotest] shut door: opened: noticed by %s" % str(noticed))
	for a in aliens:
		if is_instance_valid(a):
			a.queue_free()


## Only the busy station below, for `seconds` (headless: outpost_walls).
func run_walls(seconds: float) -> void:
	var sd := seed_where(func(l): return int(l["generator"]) >= 0 and OutpostLayout._seals(l["rooms"], "power") > 0)
	var m := await start_outpost(sd)
	if m == null:
		print("[autotest] FAIL: the outpost test never started")
		return
	await t.wait(1.0)
	var tough := m.ship.stats.duplicate()
	tough["crew_hp"] = 50000.0
	m.ship.stats = tough
	for c in m.ship.boarder_root.get_children():
		c.queue_free()
	await t.wait(0.3)
	await _check_walls(m, m.cave.derelict(m.ship.derelict_k)["layout"], seconds)


## A busy station: aliens of every kind roaming, chasing the player who pops up all over it, going
## home and going to look at a noise. Every alien's step (its floor track, and the body of those on
## the walls) is checked against the plan: none through a wall or a shut door
## (DerelictBuilder.step_clear), nor its middle closer to a wall than it keeps.
func _check_walls(m: MissionLevel, layout: Dictionary, seconds := 40.0) -> void:
	var ship := m.ship
	var p := m.local_player
	var lift := Vector3(0, StationBuilder.LAND_HEIGHT, 0)
	var rooms: Array = layout["rooms"]
	var aliens: Array[Boarder] = []
	var far := 0
	for ri in range(1, rooms.size()):
		if int(rooms[ri]["dist"]) > int(rooms[far]["dist"]):
			far = ri
		var cells := OutpostLayout.free_cells(rooms[ri])
		if cells.is_empty():
			continue
		aliens.append(ship.spawn_hostile("spider", OutpostLayout.cell_pos(cells[0]) - lift, {"hp": 5000.0, "dmg": 0.0}))
		aliens.append(ship.spawn_hostile("crawler", OutpostLayout.cell_pos(cells[cells.size() - 1]) - lift, {"hp": 5000.0, "dmg": 0.0}))
	var far_cells := OutpostLayout.free_cells(rooms[far])
	var far_at := OutpostLayout.cell_pos(far_cells[0] if not far_cells.is_empty() else (rooms[far]["cells"] as Array)[0])
	aliens.append(ship.spawn_hostile("stalker", far_at - lift, {"hp": 5000.0, "dmg": 0.0}))
	# Strays far from home: they must walk back by the corridors.
	var halls := OutpostLayout.corridor_cells(layout)
	var stray := ship.spawn_hostile("spider", OutpostLayout.cell_pos(halls[halls.size() / 2]) - lift, {"hp": 5000.0, "dmg": 0.0})
	stray.home = far_at - lift
	aliens.append(stray)
	var stray2 := ship.spawn_hostile("crawler", OutpostLayout.cell_pos(halls[halls.size() - 1]) - lift, {"hp": 5000.0, "dmg": 0.0})
	stray2.home = far_at - lift
	aliens.append(stray2)
	# Where the player pops up: the middle of every room and every few corridor cells.
	var spots: Array[Vector3] = []
	for ri in rooms.size():
		var cells := OutpostLayout.free_cells(rooms[ri])
		if not cells.is_empty():
			spots.append(OutpostLayout.cell_pos(cells[cells.size() / 2]))
	for i in range(0, halls.size(), 4):
		spots.append(OutpostLayout.cell_pos(halls[i]))
	var prev := {}
	var bad := {}
	var deep := 0.0
	var deep_kind := ""
	var frames := 0
	var t0 := Time.get_ticks_msec()
	var next_spot := 0.0
	var spot_i := 0
	var noise := false
	var chased := {}
	while Time.get_ticks_msec() - t0 < seconds * 1000.0:
		await t.get_tree().physics_frame
		frames += 1
		var now := (Time.get_ticks_msec() - t0) / 1000.0
		if now >= next_spot:
			next_spot += 4.0
			var at: Vector3 = spots[spot_i % spots.size()]
			spot_i += 1
			_stand(p, at, at + Vector3(randf_range(-3, 3), 1.4, randf_range(-3, 3)))
		if not noise and now > seconds * 0.5:
			noise = true
			ship.alert_outpost(spots[0] - lift, 45.0)
		var doors: PackedByteArray = ship.outpost_doors
		for a in aliens:
			if not is_instance_valid(a):
				continue
			if a._target_id != 0:
				chased[a.kind] = true
			# The body is where the node is drawn (on its surface, or along a leap's arc).
			var climber := a as Climber
			var track: Vector3 = climber._ground if climber else a.position
			var body: Vector3 = a.position
			var leaping := a is Crawler and a.mode != Crawler.CRAWL
			if prev.has(a):
				var was: Array = prev[a]
				var what := ""
				if not bool(was[2]) and not leaping and not DerelictBuilder.step_clear(layout, doors, (was[0] as Vector3) + lift, track + lift):
					what = "%s track" % a.kind
				elif not DerelictBuilder.step_clear(layout, doors, (was[1] as Vector3) + lift, body + lift):
					what = "%s body" % a.kind
				if what != "":
					bad[what] = int(bad.get(what, 0)) + 1
					if int(bad[what]) <= 3:
						print("[autotest] walls: %s stepped %s -> %s (cells %s -> %s), its track at %s (cell %s), on %s, mode %d, at %.1f s" % [what,
							(was[1] as Vector3) + lift, body + lift, OutpostLayout.cell_at((was[1] as Vector3) + lift), OutpostLayout.cell_at(body + lift),
							track + lift, OutpostLayout.cell_at(track + lift), ["floor", "wall", "ceiling"][climber.surface()] if climber else "floor", a.mode, now])
			prev[a] = [track, body, leaping]
			if not leaping:
				var kept := DerelictBuilder.keep_off_walls(layout, doors, track + lift, minf(a.stat("radius"), 0.5) + Boarder.WALL_GAP) - lift
				var off := Vector2(kept.x - track.x, kept.z - track.z).length()
				if off > deep:
					deep = off
					deep_kind = a.kind
	var home_d := Vector2(stray.position.x - stray.home.x, stray.position.z - stray.home.z).length() if is_instance_valid(stray) else -1.0
	print("[autotest] walls: %d aliens for %.0f s (%d physics frames), the player at %d spots, a noise half way; they went after the player: %s" % [
		aliens.size(), seconds, frames, spot_i, str(chased.keys())])
	print("[autotest] walls: steps through a wall or a shut door: %s; a track at most %.3f m inside the gap it keeps from the walls (%s); the stray spider %.1f m from its home" % [
		str(bad) if not bad.is_empty() else "none", deep, deep_kind, home_d])
	for a in aliens:
		if is_instance_valid(a):
			a.queue_free()


# --- Multiplayer ---------------------------------------------------------------------------------

## The seed both sides of the multiplayer test use: an outpost with a generator, a door that needs
## its power and a keypad lock.
func _mp_seed() -> int:
	return seed_where(func(l): return int(l["generator"]) >= 0 and OutpostLayout._seals(l["rooms"], "hack") > 0 \
		and OutpostLayout._seals(l["rooms"], "power") > 0)


## Multiplayer outpost test, host side (run --autotest=join_outpost in a second instance): host,
## start the outpost test once the client is in, clear the station and put a barnacle in a
## corridor (where the client will walk) and a spider in the first room; report what the server
## sees of the client's generator pulls, codes and the barnacle, and kill the barnacle once it has
## held the client for two seconds.
func run_host() -> void:
	Net.local_name = "HostPilot"
	if Net.host(Net.DEFAULT_PORT) != OK:
		print("[autotest] FAIL: could not host")
		return
	Game.main.change_level("homebase")
	for i in 400:
		await t.wait(0.1)
		if Net.human_count() >= 2:
			break
	if Net.human_count() < 2:
		print("[autotest] FAIL: no client joined")
		return
	await t.wait(1.0)
	Game.main.start_mission("outpost", _mp_seed())
	var m: MissionLevel = null
	for i in 900:
		await t.get_tree().process_frame
		m = Game.mission as MissionLevel
		if m and m.started and m.local_player and m.ship and m.ship.landing == Mothership.Dock.LANDED:
			break
	await t.wait(1.0)
	var ship := m.ship
	var tough := ship.stats.duplicate()
	tough["crew_hp"] = 5000.0
	ship.stats = tough
	for c in ship.boarder_root.get_children():
		c.queue_free()
	await t.wait(0.3)
	var d := m.cave.derelict(ship.derelict_k)
	var layout: Dictionary = d["layout"]
	var lift := Vector3(0, StationBuilder.LAND_HEIGHT, 0)
	var spot := _corridor_spot(layout)
	var barnacle := ship.spawn_hostile("barnacle", spot + Vector3(0, OutpostLayout.CORRIDOR_H - 0.02, 0) - lift, {"hp": 300.0})
	print("[autotest] host: landed at %s, %d doors; a barnacle over %s" % [d["name"], (layout["doors"] as Array).size(), spot])
	var client_id := 0
	for id in Net.roster:
		if int(id) > 1:
			client_id = int(id)
	var power_seen := false
	var tries_seen := 0
	var held_t := 0.0
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 120000:
		await t.wait(0.1)
		if ship.outpost_power and not power_seen:
			power_seen = true
			print("[autotest] host: the client started the generator (pulls %d)" % ship._gen_pulls)
		var tries := 0
		for v in ship.outpost_tries:
			tries += v
		if tries != tries_seen:
			tries_seen = tries
			print("[autotest] host: a wrong code from the client: tries %s" % str(Array(ship.outpost_tries)))
		if is_instance_valid(barnacle) and barnacle.grab == client_id:
			held_t += 0.1
			if held_t >= 2.0:
				var cm := ship.crew_root.get_node_or_null(str(client_id)) as CrewMember
				print("[autotest] host: the barnacle has held the client %.1f s (the client %.2f m from under it): killing it" % [held_t,
					Vector2(cm.position.x - barnacle.position.x, cm.position.z - barnacle.position.z).length() if cm else -1.0])
				barnacle.take_damage(1000.0, {})
				# A harmless spider for the client to look at (its legs are worked out on every peer).
				var r0: Dictionary = layout["rooms"][0]
				ship.spawn_hostile("spider", OutpostLayout.cell_pos(OutpostLayout.free_cells(r0)[0]) - lift, {"hp": 5000.0, "dmg": 0.0})
		if Net.human_count() < 2:
			break
		var client := ship.crew_root.get_node_or_null(str(client_id)) as CrewMember
		if client and ship.is_aboard(client.net_pos) and power_seen and not is_instance_valid(barnacle):
			break
	print("[autotest] host: at the end: power %s, doors %s, tries %s" % [ship.outpost_power, str(Array(ship.outpost_doors)), str(Array(ship.outpost_tries))])
	await t.wait(2.0)
	m.abort_mission()
	await t.wait(6.0)


## Multiplayer outpost test, client side: once landed, pull the generator's starter (its lamps and
## the power door, as the client sees them), go into the keypad's panel and key a wrong code and
## then the right one (the display, the tries, the door opening on the client), walk under the
## barnacle (held on its own client until the host kills it), look at the spider's legs, go aboard.
func run_join() -> void:
	Net.local_name = "ClientScavenger"
	await t.wait(2.0)
	if Net.join("127.0.0.1", Net.DEFAULT_PORT) != OK:
		print("[autotest] FAIL: could not start join")
		return
	var m: MissionLevel = null
	for i in 1200:
		await t.wait(0.1)
		m = Game.mission as MissionLevel
		if m and m.local_ready and m.local_player and m.ship and m.ship.landing == Mothership.Dock.LANDED and m.ship.outpost_k == m.ship.derelict_k \
				and m.ship.derelict_k >= 0:
			break
	if m == null or m.local_player == null:
		print("[autotest] FAIL: client never got into the outpost test")
		return
	await t.wait(2.0)
	var ship := m.ship
	var p := m.local_player
	var d := m.cave.derelict(ship.derelict_k)
	var layout: Dictionary = d["layout"]
	var node: Derelict = Derelict.live.get(ship.derelict_k)
	var lift := Vector3(0, StationBuilder.LAND_HEIGHT, 0)
	print("[autotest] client: landed at %s: built locally %s, power %s, doors %s, lamps lit %d" % [d["name"], node != null, ship.outpost_power,
		str(Array(ship.outpost_doors)), _lit(node)])
	# The generator.
	var rec: Dictionary = node._gen
	var out: Vector3 = rec["outward"]
	var handle := ship.to_local((rec["handle"] as Node3D).global_position) + lift
	_stand(p, handle + out * 1.0, handle)
	await t.wait(0.4)
	print("[autotest] client: at the generator: '%s'" % p.prompt)
	var pulls := 0
	while not ship.outpost_power and pulls < 6:
		await t._tap("interact")
		pulls += 1
		await t.wait(0.6)
	await t.wait(4.0)
	var power_door := -1
	for di in (layout["doors"] as Array).size():
		if str(layout["doors"][di]["kind"]) == "power":
			power_door = di
	var pr: Dictionary = node.doors.get(power_door, {})
	print("[autotest] client: after %d pulls: power %s, lamps lit %d, the power door's state %d, its slab up %.2f, its collision %s" % [pulls,
		ship.outpost_power, _lit(node), ship.outpost_doors[power_door] if power_door >= 0 else -1, float(pr.get("open", -1.0)),
		"off" if pr.has("shape") and (pr["shape"] as CollisionShape3D).disabled else "on"])
	# The keypad.
	var di := -1
	for i in (layout["doors"] as Array).size():
		if str(layout["doors"][i]["kind"]) == "hack":
			di = i
			break
	var panel := node.panel_of(di)
	var front := ship.to_local(panel.global_position + panel.global_basis.z * 1.0) + lift
	_stand(p, front, ship.to_local(panel.global_position) + lift)
	await t.wait(0.4)
	await t._tap("interact")
	await t.wait(0.5)
	var code := str(layout["doors"][di]["code"])
	var wrong := ""
	for ch in code:
		wrong += str((int(ch) + 3) % 10)
	await _type(wrong)
	await t.wait(1.0)
	print("[autotest] client: in the panel %s; wrong code: tries %s, display '%s'" % [p._panel != null, str(Array(ship.outpost_tries)),
		panel._display.text])
	await _type(code)
	await t.wait(3.5)
	var dr: Dictionary = node.doors[di]
	print("[autotest] client: right code: door state %d, slab up %.2f, collision %s, out of the panel %s" % [ship.outpost_doors[di],
		float(dr["open"]), "off" if (dr["shape"] as CollisionShape3D).disabled else "on", p._panel == null])
	# The barnacle.
	var spot := _corridor_spot(layout)
	_stand(p, spot + Vector3(0.2, 0, 0.2), spot + Vector3(0, 3.0, 0))
	var held := false
	var moved := 0.0
	for i in 60:
		await t.wait(0.1)
		if p._held_by() != null and not held:
			held = true
			var at := p.position
			Input.action_press("move_back")
			await t.wait(1.0)
			Input.action_release("move_back")
			moved = Vector2(p.position.x - at.x, p.position.z - at.z).length()
		if held and p._held_by() == null:
			break
	print("[autotest] client: under the barnacle: held %s, tried to walk off: moved %.2f m; free again %s" % [held, moved, p._held_by() == null])
	# The spider's legs, as worked out on this client (the host sends one once the barnacle is dead).
	var spider: Spider = null
	for i in 40:
		await t.wait(0.1)
		for c in ship.boarder_root.get_children():
			if c is Spider:
				spider = c
		if spider:
			break
	await t.wait(1.5)
	if spider:
		var feet := PackedFloat32Array()
		for i in 4:
			feet.append((spider._shins[i] as Node3D).global_transform.origin.distance_to(spider.global_position))
		print("[autotest] client: the spider's legs here: shins %.2f..%.2f m from its body, %s" % [Array(feet).min(), Array(feet).max(),
			"placed" if Array(feet).max() < 2.0 and Array(feet).min() > 0.05 else "WRONG"])
	p.position = ship.spawn_points()[1]
	p.reset_physics_interpolation()
	for i in 300:
		await t.wait(0.1)
		var lvl: Node = Game.main.current_level()
		if lvl and lvl.name == "Homebase":
			break
	print("[autotest] client: back at ", Game.main.current_level().name if Game.main.current_level() else "none")


# --- The aliens up close -------------------------------------------------------------------------

## Each of the outposts' aliens in a lit corridor, held still for close-ups (windowed): the stalker
## from the side and the front (prowling and crouched), a barnacle from below, a crawler and an acid
## spider on a wall and on the floor, a crawler nest.
func run_gallery() -> void:
	var sd := seed_where(func(l): return int(l["generator"]) >= 0)
	var m := await start_outpost(sd)
	if m == null:
		print("[autotest] FAIL: the outpost test never started")
		return
	await t.wait(1.0)
	var ship := m.ship
	var p := m.local_player
	for c in ship.boarder_root.get_children():
		c.queue_free()
	ship.outpost_power = true
	var d := m.cave.derelict(ship.derelict_k)
	var layout: Dictionary = d["layout"]
	var xf: Transform3D = d["xform"]
	var lift := Vector3(0, StationBuilder.LAND_HEIGHT, 0)
	# A studio on a free corner of the landing pad: a floor, two walls and a ceiling (station
	# geometry, so the climbers climb them), the subject in its middle, the camera in front.
	var node: Derelict = Derelict.live.get(ship.derelict_k)
	var studio := StaticBody3D.new()
	studio.collision_layer = Game.LAYER_STATION
	studio.collision_mask = 0
	node.add_child(studio)
	var wall_mat := Models.panel_mat(Color(0.36, 0.38, 0.27), 0.35, 0.72, 0.42)
	# (At the stations' deck height, where the aliens' waypoints are.)
	var room_h := 4.6
	var dy := StationBuilder.DECK_Y
	for box: Array in [[Vector3(-10.5, dy + room_h + 0.15, -12.5), Vector3(8.0, 0.3, 8.0)], [Vector3(-10.5, dy + room_h * 0.5, -16.6), Vector3(8.0, room_h, 0.3)],
			[Vector3(-14.6, dy + room_h * 0.5, -12.5), Vector3(0.3, room_h, 8.0)], [Vector3(-10.5, dy - 0.05, -12.5), Vector3(8.0, 0.1, 8.0)]]:
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = box[1]
		cs.shape = sh
		cs.position = box[0]
		studio.add_child(cs)
		Models.box(studio, box[0], box[1], wall_mat)
	var mid := Vector3(-11.5, dy, -14.0)
	p.position = ship.spawn_points()[0]
	var cam := Camera3D.new()
	cam.fov = 55.0
	m.add_child(cam)
	cam.current = true
	var lamp := OmniLight3D.new()
	lamp.light_energy = 1.6
	lamp.omni_range = 7.0
	lamp.light_color = Color(1.0, 0.85, 0.7)
	m.add_child(lamp)
	await t.wait(2.0)
	# [kind, where, spawn data, mode, heading (yaw), [camera, looking at], picture].
	var shots: Array = [
		["stalker", mid, {"lair": mid - lift}, Stalker.ROAM, 0.0, [mid + Vector3(4.4, 1.5, 0.6), mid + Vector3(0, 1.1, 0)], "ga01_stalker_side"],
		["stalker", mid, {"lair": mid - lift}, Stalker.HIDE, -PI / 2.0, [mid + Vector3(3.8, 1.1, 1.6), mid + Vector3(0, 0.8, 0)], "ga02_stalker_crouch"],
		["stalker", mid, {"lair": mid - lift}, Stalker.CLAW, -PI / 2.0, [mid + Vector3(3.4, 1.7, 0.4), mid + Vector3(0, 1.4, 0)], "ga03_stalker_front"],
		["barnacle", mid + Vector3(0, room_h - 0.02, 0), {}, 0, 0.0, [mid + Vector3(2.2, 1.6, 1.4), mid + Vector3(0, room_h - 0.3, 0)], "ga04_barnacle"],
		["spider", mid, {}, 0, -PI / 4.0, [mid + Vector3(2.4, 1.3, 1.8), mid + Vector3(0, 0.45, 0)], "ga05_spider"],
		["crawler", mid, {}, 0, -PI / 4.0, [mid + Vector3(1.4, 0.8, 1.1), mid + Vector3(0, 0.2, 0)], "ga06_crawler"],
		["hive", mid, {"up": Vector3.UP, "hive_id": 7}, 0, 0.0, [mid + Vector3(2.0, 1.4, 1.6), mid + Vector3(0, 0.5, 0)], "ga07_hive"],
	]
	for s: Array in shots:
		var b := ship.spawn_hostile(s[0], (s[1] as Vector3) - lift, s[2])
		b.set_physics_process(false)
		await t.wait(0.3)
		b.mode = s[3]
		if s[0] != "barnacle" and s[0] != "hive":
			b.rotation = Vector3(0, float(s[4]), 0)
		var view: Array = s[5]
		cam.global_position = xf * (view[0] as Vector3)
		cam.look_at(xf * (view[1] as Vector3), xf.basis.y)
		lamp.global_position = xf * ((view[0] as Vector3) + Vector3(0, 0.6, 0))
		await t.wait(0.8)
		await t.shot(s[6])
		b.queue_free()
		await t.wait(0.1)
	# Climbers on a wall: let them move until they are up one, then hold them.
	for kind: String in ["spider", "crawler"]:
		var b := ship.spawn_hostile(kind, mid - lift, {}) as Climber
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 20000 and not (b.surface() == 1 and b._surf_up.dot(b._wall_n) > 0.95):
			await t.wait(0.1)
		b.set_physics_process(false)
		var body := b.body_pos() + lift
		var n := Vector3(b._wall_n.x, 0, b._wall_n.z)
		var side := n.cross(Vector3.UP)
		cam.global_position = xf * (body + n * 2.2 + side * 0.9 + Vector3(0, -0.4, 0))
		cam.look_at(xf * body, xf.basis.y)
		lamp.global_position = xf * (body + n * 1.5 + Vector3(0, 0.5, 0))
		await t.wait(0.8)
		await t.shot("ga08_%s_wall" % kind)
		print("[autotest] gallery: %s on a wall %s after %.1f s" % [kind, b.surface() == 1, (Time.get_ticks_msec() - t0) / 1000.0])
		b.queue_free()
	cam.queue_free()
	lamp.queue_free()
	# Barnacles where they live, seen from the floor (helmet lamp on): on a corridor's ceiling and a
	# room's, and one lashing out at someone in front of it.
	p.camera.current = true
	var spot := _corridor_spot(layout)
	var along := _corridor_axis(layout, spot)
	var b1 := ship.spawn_hostile("barnacle", spot + Vector3(0, OutpostLayout.ceiling(layout, OutpostLayout.cell_at(spot)) - 0.02, 0) - lift, {})
	b1.set_physics_process(false)
	_stand(p, spot + along * 2.4, spot + Vector3(0, OutpostLayout.CORRIDOR_H - 0.1, 0))
	await t.wait(1.0)
	await t.shot("ga09_barnacle_corridor")
	b1.grab = 99999
	b1._held_at = Vector3(0.0, 2.1, 0.0) + (Basis(Vector3.RIGHT, PI).inverse() * along) * 1.0
	await t.wait(0.5)
	await t.shot("ga10_barnacle_lash")
	b1.queue_free()
	var room: Dictionary = layout["rooms"][0]
	var cells := OutpostLayout.free_cells(room)
	var at := OutpostLayout.cell_pos(cells[cells.size() / 2])
	var b2 := ship.spawn_hostile("barnacle", at + Vector3(0, float(room["h"]) - 0.02, 0) - lift, {})
	b2.set_physics_process(false)
	var away := Vector3(2.3, 0, 0.8)
	if not OutpostLayout.cell_at(at + away) in cells:
		away = -away
	_stand(p, at + away, at + Vector3(0, float(room["h"]) - 0.1, 0))
	await t.wait(1.0)
	await t.shot("ga11_barnacle_room")
	b2.queue_free()


static func _to_px(p: Vector2, px: int) -> Vector2i:
	var gx := p.x / OutpostLayout.CELL + OutpostLayout.MID + 0.5
	var gz := (p.y - OutpostLayout.Z0) / OutpostLayout.CELL
	return Vector2i(roundi(gx * px), roundi((OutpostLayout.GZ - gz) * px) + px)
