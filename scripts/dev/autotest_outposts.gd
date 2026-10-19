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
	var stats := {"rooms": 0, "doors": 0, "hack": 0, "power": 0, "generator": 0, "security": 0, "armory": 0, "loops": 0,
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
		stats["security"] += 1 if int(layout["security"]) >= 0 else 0
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
	print("[autotest] plans: per outpost %.1f rooms, %.1f doorways; %d keypad locks, %d power doors, %d generators, %d security rooms, %d armories" % [
		stats["rooms"] / float(seeds), stats["doors"] / float(seeds), stats["hack"], stats["power"], stats["generator"], stats["security"], stats["armory"]])
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
## (green open, red keypad, yellow power), furniture outlined, salvage spots and cameras dotted.
func _draw_plan(layout: Dictionary, sd: int) -> void:
	var px := 30
	var w := OutpostLayout.GX * px
	var h := OutpostLayout.GZ * px
	var img := Image.create(w, h + px, false, Image.FORMAT_RGB8)
	img.fill(Color(0.08, 0.08, 0.09))
	var colors := {"lab": Color(0.25, 0.55, 0.35), "storage": Color(0.45, 0.4, 0.25), "vault": Color(0.55, 0.3, 0.2),
		"quarters": Color(0.3, 0.35, 0.55), "mess": Color(0.55, 0.45, 0.3), "security": Color(0.25, 0.45, 0.55),
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
				col = {"open": Color(0.2, 0.9, 0.3), "hack": Color(1.0, 0.15, 0.1), "power": Color(1.0, 0.85, 0.1)}.get(str(layout["doors"][di]["kind"]), Color.WHITE)
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
## corridors, every room, the generator, the security desk and a keypad, with the power off and on,
## and a lockdown.
func run_tour() -> void:
	var sd := seed_where(func(l): return int(l["generator"]) >= 0 and int(l["security"]) >= 0 and OutpostLayout._seals(l["rooms"], "hack") > 0)
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
	DerelictBuilder._build_halls(root, b, d["layout"], mats, rng, true)
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


## Views of every room, a corridor or two, the generator, the security desk and a keypad.
func _views(cam: Camera3D, xf: Transform3D, layout: Dictionary, prefix: String) -> void:
	var rooms: Array = layout["rooms"]
	for ri in rooms.size():
		var room: Dictionary = rooms[ri]
		var core: Rect2i = room["core"]
		var a := OutpostLayout.cell_pos(core.position)
		var e := OutpostLayout.cell_pos(core.end - Vector2i.ONE)
		var mid := (a + e) * 0.5
		var eye := a + (a - mid).normalized() * 0.6 + Vector3(0, float(room["h"]) - 1.0, 0)
		if ri == int(layout["generator"]) or ri == int(layout["security"]):
			eye = mid + (a - mid) * 0.8 + Vector3(0, 2.4, 0)
		_look(cam, xf, eye, mid + Vector3(0, 0.6, 0))
		await t.wait(0.35)
		await t.shot("%s_room%d_%s" % [prefix, ri, room["theme"]])
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
	# The security desk's screens, from its chairs (the feeds run while the viewer is in the room).
	var sec := int(layout["security"])
	if sec >= 0:
		for prop: Dictionary in rooms[sec]["props"]:
			if str(prop["kind"]) == "security_desk":
				var px := Transform3D(Basis(Vector3.UP, float(prop["yaw"])), prop["pos"])
				_look(cam, xf, px * Vector3(0.2, 1.55, 1.9), px * Vector3(0, 1.3, -0.25))
				await t.wait(1.0)
				await t.shot("%s_security_desk" % prefix)
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
