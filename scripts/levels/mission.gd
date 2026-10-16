class_name MissionLevel
extends Node3D
## A dive into an asteroid cave.
##
## The server streams cave chunks around the mothership, fills new chunks with mineral deposits,
## fuel crystals (in the scout-only side tunnels), alien nests and free-roaming aliens, keeps a
## director spawning ambushes that get nastier with depth, and ends the mission when the
## mothership is destroyed (or the host aborts). Clients rebuild the cave locally from the seed,
## including the waystations, whose defences shoot down any alien that comes near. The dive pays
## out research points (depth, waystations reached, nests); the credits mined are only good for
## waystation shops during the dive.

const AHEAD := 230.0
const BEHIND := 90.0
const DESPAWN_BEHIND := 160.0
const MAX_ALIENS := 34

var mission_seed := 0
var stats: Dictionary = {}
var best_depth := 0
var cave: CaveGen
var ship: Mothership
## The mothership's scouts (one per scout bay), by index.
var scouts: Array[Scout] = []
var local_player: CrewMember
var hud: Hud
var projectiles: Projectiles
var fx_root: Node3D
var cave_root: Node3D
var ship_root: Node3D
var enemy_root: Node3D
var mineral_root: Node3D
var pickup_root: Node3D
var chunk_spawner: MultiplayerSpawner
var ship_spawner: MultiplayerSpawner
var enemy_spawner: MultiplayerSpawner
var mineral_spawner: MultiplayerSpawner
var pickup_spawner: MultiplayerSpawner

## True on this peer once the cave around the ship has been built.
var local_ready := false
var started := false
var ending := false
var kills := 0
var nests_destroyed := 0
var warned_critters := false
var warned_infiltrators := false

var _chunks: Dictionary = {}
var _populated: Dictionary = {}
var _seq := 0
var _director_t := 45.0
var _defense_t := 0.0
var _shake := 0.0
var _env: Environment
var _dust: CPUParticles3D


func setup(data: Dictionary) -> void:
	mission_seed = int(data.get("seed", 1))
	stats = data.get("stats", Game.ship_stats())
	best_depth = int(data.get("best", 0))


func _ready() -> void:
	Game.mission = self
	cave = CaveGen.new(mission_seed)
	_build_environment()
	cave_root = _container("Cave")
	ship_root = _container("Ships")
	enemy_root = _container("Enemies")
	mineral_root = _container("Minerals")
	pickup_root = _container("Pickups")
	fx_root = _container("Fx")
	projectiles = Projectiles.new()
	projectiles.name = "Projectiles"
	add_child(projectiles)
	chunk_spawner = NetUtil.add_spawner(self, "ChunkSpawner", cave_root, _spawn_chunk)
	ship_spawner = NetUtil.add_spawner(self, "ShipSpawner", ship_root, _spawn_ship)
	enemy_spawner = NetUtil.add_spawner(self, "EnemySpawner", enemy_root, _spawn_enemy)
	mineral_spawner = NetUtil.add_spawner(self, "MineralSpawner", mineral_root, _spawn_mineral)
	pickup_spawner = NetUtil.add_spawner(self, "PickupSpawner", pickup_root, _spawn_pickup)
	hud = Hud.new()
	add_child(hud)
	Game.main.restore_mouse()
	if multiplayer.is_server():
		_server_start()


## Server: despawn replicated entities innermost-first before the level itself goes away.
func teardown() -> void:
	ending = true
	for root: Node in [pickup_root, mineral_root, enemy_root, cave_root]:
		for c in root.get_children():
			c.queue_free()
	if ship:
		for c in ship.boarder_root.get_children():
			c.queue_free()
		for c in ship.cargo_root.get_children():
			c.queue_free()
		for c in ship.crew_root.get_children():
			c.queue_free()
	await get_tree().process_frame
	for c in ship_root.get_children():
		c.queue_free()
	await get_tree().process_frame


func _exit_tree() -> void:
	if Game.mission == self:
		Game.mission = null
	Game.ui_blocking = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _container(n: String) -> Node3D:
	var c := Node3D.new()
	c.name = n
	add_child(c)
	return c


func _build_environment() -> void:
	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.background_color = Color(0.004, 0.006, 0.012)
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(0.36, 0.42, 0.55)
	_env.ambient_light_energy = 0.38
	_env.tonemap_mode = Environment.TONE_MAPPER_ACES
	_env.glow_enabled = true
	_env.glow_intensity = 0.7
	_env.glow_bloom = 0.04
	_env.fog_enabled = true
	_env.fog_light_color = Color(0.03, 0.04, 0.06)
	_env.fog_density = 0.007
	_env.ssao_enabled = true
	_env.ssao_radius = 2.0
	var we := WorldEnvironment.new()
	we.environment = _env
	add_child(we)
	# Drifting dust motes around the viewer give a sense of scale and motion in the dark.
	_dust = CPUParticles3D.new()
	_dust.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_dust.amount = 350
	_dust.lifetime = 8.0
	_dust.preprocess = 8.0
	_dust.local_coords = false
	_dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_dust.emission_box_extents = Vector3(30, 18, 30)
	_dust.direction = Vector3.UP
	_dust.spread = 180.0
	_dust.gravity = Vector3.ZERO
	_dust.initial_velocity_min = 0.05
	_dust.initial_velocity_max = 0.4
	_dust.scale_amount_min = 0.5
	_dust.scale_amount_max = 1.2
	var dust_mesh := QuadMesh.new()
	dust_mesh.size = Vector2(0.06, 0.06)
	var dust_mat := StandardMaterial3D.new()
	dust_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dust_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	dust_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dust_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	dust_mat.vertex_color_use_as_albedo = true
	dust_mesh.material = dust_mat
	_dust.mesh = dust_mesh
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.2, 0.8, 1.0])
	fade.colors = PackedColorArray([Color(0.7, 0.75, 0.8, 0.0), Color(0.7, 0.75, 0.8, 0.35), Color(0.7, 0.75, 0.8, 0.35), Color(0.7, 0.75, 0.8, 0.0)])
	_dust.color_ramp = fade
	add_child(_dust)


func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam and _dust:
		_dust.global_position = cam.global_position
		# No drifting cave dust inside the pressurised ship.
		_dust.visible = not (local_player and local_player.alive and local_player.station == ""
				and Mothership.is_aboard(local_player.position))


func set_local_player(p: CrewMember) -> void:
	local_player = p


## Difficulty multiplier that grows with depth and crew size (a solo player has to do every job).
## Crew bots count as half a crew member.
func difficulty() -> float:
	var d := ship.depth if ship else 0.0
	var crew := clampf(float(Net.human_count()) + 0.5 * Net.bot_ids().size(), 1.0, 4.0)
	return (1.0 + d / 450.0) * (0.7 + 0.15 * crew)


func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func shake_offset() -> Vector3:
	if _shake <= 0.0:
		return Vector3.ZERO
	return Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * _shake * 0.25


# --- Spawning ----------------------------------------------------------------------------------

func _spawn_chunk(data: Variant) -> Node:
	var c := CaveChunk.new()
	var n := int(data["n"])
	c.setup(mission_seed, n)
	if multiplayer.is_server():
		c.built.connect(_on_chunk_built)
	# Waystation structures are built locally with the chunk that holds the station.
	var s0 := n * CaveGen.CHUNK_LEN
	for st in cave.stations_in(s0, s0 + CaveGen.CHUNK_LEN):
		var s := float(st["s"])
		if s >= s0 and s < s0 + CaveGen.CHUNK_LEN:
			StationBuilder.build(c, st)
	return c


func _spawn_ship(data: Variant) -> Node:
	var d: Dictionary = data
	if d["t"] == "ship":
		var s := Mothership.new()
		s.setup(d)
		ship = s
		if multiplayer.is_server():
			s.destroyed.connect(_on_ship_destroyed)
		return s
	var sc := Scout.new()
	sc.setup(d)
	scouts.append(sc)
	scouts.sort_custom(func(a: Scout, b: Scout): return a.index < b.index)
	return sc


## The scout launched from a scout bay station, or null.
func scout_at(station_id: String) -> Scout:
	for sc in scouts:
		if is_instance_valid(sc) and sc.station_id == station_id:
			return sc
	return null


## Scouts that are out flying.
func flying_scouts() -> Array[Scout]:
	var out: Array[Scout] = []
	for sc in scouts:
		if is_instance_valid(sc) and sc.state == Scout.State.FLYING:
			out.append(sc)
	return out


func _spawn_enemy(data: Variant) -> Node:
	var d: Dictionary = data
	if d["t"] == "nest":
		var n := Nest.new()
		n.setup(d)
		return n
	var a := Alien.new()
	a.setup(d)
	return a


func _spawn_mineral(data: Variant) -> Node:
	var dep := Deposit.new()
	dep.setup(data)
	return dep


func _spawn_pickup(data: Variant) -> Node:
	var p := MineralChunk.new()
	p.setup(data)
	return p


func _next_name(prefix: String) -> String:
	_seq += 1
	return "%s%d" % [prefix, _seq]


## Server: spawn a free-flying alien.
func spawn_alien(kind: int, pos: Vector3, hp_mult := 1.0, dmg_mult := 1.0, nest := "") -> Node:
	if enemy_root.get_tree().get_nodes_in_group("aliens").size() >= MAX_ALIENS:
		return null
	return enemy_spawner.spawn({"t": "alien", "name": _next_name("A"), "kind": kind, "pos": pos,
		"hp_mult": hp_mult, "dmg_mult": dmg_mult, "nest": nest})


## Server: spawn a mineral fragment that drifts towards the collector.
func spawn_pickup(kind: String, pos: Vector3, vel: Vector3, value: int, fuel: float) -> void:
	if not multiplayer.is_server():
		return
	pickup_spawner.spawn({"name": _next_name("P"), "kind": kind, "pos": pos, "vel": vel, "value": value, "fuel": fuel})


# --- Server flow -------------------------------------------------------------------------------

func _server_start() -> void:
	for n in range(-1, 5):
		_ensure_chunk(n)
	var ship_id := str(stats.get("ship", "prospector"))
	ship_spawner.spawn({"t": "ship", "ship": ship_id, "stats": stats, "pos": Vector3(0, -1.0, 0)})
	if Game.cheats_allowed() and Game.cheat_dive_credits > 0:
		ship.credits = Game.cheat_dive_credits
	var layout := ShipTypes.get_type(ship_id)
	var i_scout := 0
	for sid: String in layout["scouts"]:
		ship_spawner.spawn({"t": "scout", "stats": stats, "index": i_scout, "station": sid, "style": layout["scout_style"]})
		i_scout += 1
	var i := 0
	var ids := Net.roster.keys()
	ids.sort()
	for id in ids:
		_spawn_crew_member(int(id), i)
		i += 1
	Net.player_registered.connect(_on_player_registered)
	Net.player_left.connect(_on_player_left)


func _spawn_crew_member(id: int, slot: int) -> void:
	if ship == null or ship.crew_root.has_node(str(id)):
		return
	ship.crew_spawner.spawn({
		"id": id, "name": Net.player_name(id), "color": int(Net.roster.get(id, {}).get("color", 0)),
		"hp": float(stats["crew_hp"]), "pos": ShipBuilder.SPAWN_POINTS[slot % ShipBuilder.SPAWN_POINTS.size()],
		"bot": Net.is_bot(id),
	})


func _on_player_registered(id: int) -> void:
	_spawn_crew_member(id, Net.roster.size() - 1)
	ship.notify.rpc("%s joined the crew" % Net.player_name(id), 0)


func _on_player_left(id: int) -> void:
	if ship == null:
		return
	ship.release_peer(id)
	var p := ship.crew_root.get_node_or_null(str(id))
	if p:
		p.queue_free()


func _ensure_chunk(n: int) -> void:
	if _chunks.has(n):
		return
	_chunks[n] = chunk_spawner.spawn({"n": n})


func _physics_process(delta: float) -> void:
	_shake = maxf(0.0, _shake - delta * 2.5)
	if ship == null:
		return
	# Veins shift from cyan to violet as the crew descends.
	CaveChunk.set_vein_color(Color(0.2, 0.75, 0.95).lerp(Color(0.85, 0.3, 1.0), clampf(ship.depth / 1500.0, 0.0, 1.0)))
	if not local_ready:
		local_ready = _chunks_ready_near(-ship.global_position.z)
	if not multiplayer.is_server():
		return
	if not started:
		if local_ready:
			started = true
			ship.frozen = false
			ship.notify.rpc("Systems online. Take the pilot seat and dive!", 0)
			if Game.cheats_allowed() and Game.cheat_dive_credits > 0:
				ship.notify.rpc("Cheat: this dive starts with %d credits" % Game.cheat_dive_credits, 1)
			_tutorial.rpc()
		return
	_stream_chunks()
	if not ending:
		_director(delta)
	_station_defense(delta)
	_despawn_far()


func _chunks_ready_near(s: float) -> bool:
	var n0 := int(floor(s / CaveGen.CHUNK_LEN))
	for n in range(n0 - 1, n0 + 3):
		var c := cave_root.get_node_or_null("Chunk%d" % n) as CaveChunk
		if c == null or not c.is_built:
			return false
	return true


func _stream_chunks() -> void:
	var s := -ship.global_position.z
	var s_lo := s - BEHIND
	var s_hi := s + AHEAD
	# Keep the cave around the scouts too when they scout far ahead (or behind).
	for sc in flying_scouts():
		var ss := -sc.global_position.z
		s_lo = minf(s_lo, ss - 60.0)
		s_hi = maxf(s_hi, ss + 120.0)
	var lo := int(floor(s_lo / CaveGen.CHUNK_LEN))
	var hi := int(floor(s_hi / CaveGen.CHUNK_LEN))
	for n in range(maxi(lo, -1), hi + 1):
		_ensure_chunk(n)
	for n in _chunks.keys():
		if n < lo - 1 or n > hi + 2:
			var c: Node = _chunks[n]
			if is_instance_valid(c):
				c.queue_free()
			_chunks.erase(n)


func _despawn_far() -> void:
	var s := -ship.global_position.z
	for sc in flying_scouts():
		s = minf(s, -sc.global_position.z)
	for root: Node3D in [enemy_root, mineral_root, pickup_root]:
		for c in root.get_children():
			var n := c as Node3D
			if n and -n.global_position.z < s - DESPAWN_BEHIND:
				n.queue_free()


func _on_chunk_built(chunk: CaveChunk) -> void:
	if _populated.has(chunk.index):
		return
	_populated[chunk.index] = true
	_populate(chunk)


## Place deposits, fuel crystals, nests and roaming aliens in a freshly built chunk.
func _populate(chunk: CaveChunk) -> void:
	var n := chunk.index
	if n < 0:
		return
	var verts: PackedVector3Array = chunk.result.get("verts", PackedVector3Array())
	var norms: PackedVector3Array = chunk.result.get("norms", PackedVector3Array())
	if verts.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([mission_seed, n, "populate"])
	var s0 := n * CaveGen.CHUNK_LEN
	var s1 := s0 + CaveGen.CHUNK_LEN
	var placed: Array[Vector3] = []

	# Minerals on the main tunnel walls.
	var want := rng.randi_range(4, 7) if n > 0 else 3
	var tries := 0
	while placed.size() < want and tries < 120:
		tries += 1
		var i := rng.randi() % verts.size()
		var p := verts[i]
		if not _on_main_wall(p) or _too_close(p, placed, 9.0) or _in_station(p, 3.0):
			continue
		placed.append(p)
		var kind := _roll_mineral(rng, -p.z)
		_spawn_deposit(kind, p, norms[i], rng.randf_range(0.85, 1.35), rng.randi())

	# Fuel crystals in the chambers at the end of side tunnels.
	for t in cave.side_tunnels_in(s0, s1):
		var ch: Vector3 = t["chamber"]
		if -ch.z < s0 or -ch.z >= s1:
			continue
		var cr: float = t["chamber_r"]
		var fuel_placed: Array[Vector3] = []
		for k in 600:
			if fuel_placed.size() >= 3:
				break
			var i := rng.randi() % verts.size()
			var p := verts[i]
			if p.distance_to(ch) > cr + 2.5 or _too_close(p, fuel_placed, 4.0):
				continue
			fuel_placed.append(p)
			_spawn_deposit("fuel", p, norms[i], rng.randf_range(0.8, 1.1), rng.randi())
		# A couple of fuel crystals along the tunnel itself.
		var pts: PackedVector3Array = t["pts"]
		for k in 300:
			if fuel_placed.size() >= 4:
				break
			var i := rng.randi() % verts.size()
			var p := verts[i]
			if p.distance_to(pts[pts.size() - 1]) > float(t["r"]) + 2.0 or _too_close(p, fuel_placed, 4.0):
				continue
			fuel_placed.append(p)
			_spawn_deposit("fuel", p, norms[i], 0.8, rng.randi())

	# Nests in caverns, plus random ones deeper down.
	var depth_mid := (s0 + s1) * 0.5
	var nest_here := false
	for k in range(int(floor(s0 / CaveGen.CAVERN_SEGMENT)) - 1, int(floor(s1 / CaveGen.CAVERN_SEGMENT)) + 1):
		if k < 1:
			continue
		var cv := cave.cavern(k)
		if float(cv["s"]) >= s0 and float(cv["s"]) < s1:
			nest_here = true
	if not nest_here and n >= 4 and rng.randf() < clampf((s0 - 200.0) / 1400.0, 0.0, 0.3):
		nest_here = true
	if nest_here and cave.near_station(depth_mid, 140.0):
		nest_here = false
	if nest_here:
		_place_nest(verts, norms, rng, depth_mid)

	# Free-roaming aliens.
	if n >= 3:
		var count := rng.randi_range(0, 1) + int(depth_mid / 350.0)
		for k in mini(count, 4):
			var s := rng.randf_range(s0, s1)
			if cave.near_station(s, 140.0):
				continue
			var c := cave.center3(s)
			var r := cave.radius(s) * 0.5
			var p := c + Vector3(rng.randf_range(-r, r), rng.randf_range(-r, r) * 0.6, 0)
			var kind := Alien.Kind.SPITTER if rng.randf() < 0.65 else Alien.Kind.CRITTER
			spawn_alien(kind, p, _hp_mult(depth_mid), _dmg_mult(depth_mid))


func _place_nest(verts: PackedVector3Array, norms: PackedVector3Array, rng: RandomNumberGenerator, depth_mid: float) -> void:
	var center_i := -1
	for k in 200:
		var i := rng.randi() % verts.size()
		if _on_main_wall(verts[i]) and absf(-verts[i].z - depth_mid) < 16.0:
			center_i = i
			break
	if center_i < 0:
		return
	var c := verts[center_i]
	var sacs: Array = []
	var sac_nrm: Array = []
	var want := rng.randi_range(4, 6)
	for k in 800:
		if sacs.size() >= want:
			break
		var i := rng.randi() % verts.size()
		var p := verts[i]
		var d := p.distance_to(c)
		if d < 5.0 or d > 15.0 or not _on_main_wall(p):
			continue
		var close := false
		for q in sacs:
			if (q as Vector3).distance_to(p) < 4.0:
				close = true
				break
		if close:
			continue
		sacs.append(p)
		sac_nrm.append(norms[i])
	if sacs.size() < 2:
		return
	enemy_spawner.spawn({"t": "nest", "name": _next_name("N"), "pos": c, "nrm": norms[center_i], "sacs": sacs,
		"sac_nrm": sac_nrm, "hp_mult": _hp_mult(depth_mid), "dmg_mult": _dmg_mult(depth_mid),
		"infiltrators": clampf(depth_mid / 3000.0, 0.0, 0.15)})


func _spawn_deposit(kind: String, p: Vector3, nrm: Vector3, size: float, crystal_seed: int) -> void:
	mineral_spawner.spawn({"name": _next_name("D"), "kind": kind, "pos": p - nrm * 0.4, "nrm": nrm, "size": size, "seed": crystal_seed})


## True inside (or within `margin` of) the rock carved out for a waystation.
func _in_station(p: Vector3, margin: float) -> bool:
	for st in cave.stations_in(-p.z - 1.0, -p.z + 1.0):
		if cave.station_raw(p, st) < margin:
			return true
	return false


func _on_main_wall(p: Vector3) -> bool:
	var s := -p.z
	var c := cave.center(s)
	return Vector2(p.x - c.x, p.y - c.y).length() < cave.radius(s) + 11.0


func _too_close(p: Vector3, list: Array[Vector3], dist: float) -> bool:
	for q in list:
		if q.distance_to(p) < dist:
			return true
	return false


func _roll_mineral(rng: RandomNumberGenerator, d: float) -> String:
	var weights := {
		"ferrite": maxf(0.25, 1.0 - d / 700.0),
		"cobalt": clampf(0.2 + d / 500.0, 0.2, 0.9),
		"aurium": clampf((d - 150.0) / 600.0, 0.0, 0.7),
		"voidstone": clampf((d - 450.0) / 900.0, 0.0, 0.45),
	}
	var total := 0.0
	for k in weights:
		total += float(weights[k])
	var r := rng.randf() * total
	for k in weights:
		r -= float(weights[k])
		if r <= 0.0:
			return k
	return "ferrite"


func _hp_mult(d: float) -> float:
	return 1.0 + d / 700.0


func _dmg_mult(d: float) -> float:
	return 1.0 + d / 900.0


## Ambient threats: packs of aliens ambush the ship from ahead or behind.
func _director(delta: float) -> void:
	if ship.landing != Mothership.Dock.FLYING:
		# Docked: a breather, and some quiet after leaving the station.
		_director_t = maxf(_director_t, 20.0)
		return
	_director_t -= delta
	if _director_t > 0.0 or not ship.alive:
		return
	var diff := difficulty()
	_director_t = randf_range(26.0, 40.0) / diff
	var s := -ship.global_position.z
	var ahead := randf() < 0.7
	var sp := s + (randf_range(90.0, 130.0) if ahead else -randf_range(60.0, 80.0))
	# Bulkheads seal the tunnel: never spawn behind the last waystation or near the next one.
	var behind: Dictionary = cave.station(ship.gate_k) if ship.gate_k >= 0 else {}
	if cave.near_station(sp, 140.0) or (not behind.is_empty() and sp < float(behind["s_exit"]) + 40.0):
		_director_t = 8.0
		return
	var c := cave.center3(sp)
	var pack := (1 if s < 120.0 else 2) + int(randf() * diff * 1.5)
	for k in mini(pack, 6):
		var r := randf()
		var kind := Alien.Kind.SPITTER
		if r < 0.4:
			kind = Alien.Kind.CRITTER
		elif r < 0.55 and s > 120.0:
			kind = Alien.Kind.INFILTRATOR
		var p := c + Vector3(randf_range(-8, 8), randf_range(-5, 5), randf_range(-8, 8))
		spawn_alien(kind, p, _hp_mult(s), _dmg_mult(s))


## Waystation defences: one shot every quarter second at the alien nearest to a station's pad
## inside its safe zone (the hall and its approach tunnels, hull-latched aliens included), fired
## from the closest of its guard turrets.
func _station_defense(delta: float) -> void:
	_defense_t -= delta
	if _defense_t > 0.0:
		return
	_defense_t = 0.25
	var aliens := get_tree().get_nodes_in_group("aliens")
	if aliens.is_empty():
		return
	var s := -ship.global_position.z
	for st in cave.stations_in(s - 250.0, s + 250.0):
		var xf: Transform3D = st["xform"]
		var inv: Transform3D = st["inv"]
		var best: Alien = null
		var best_d := INF
		for a in aliens:
			var alien := a as Alien
			if alien == null or alien.hp <= 0.0 or alien.is_queued_for_deletion():
				continue
			var l := inv * alien.global_position
			if l.x < StationBuilder.SAFE_MIN.x or l.x > StationBuilder.SAFE_MAX.x or l.y < StationBuilder.SAFE_MIN.y \
					or l.y > StationBuilder.SAFE_MAX.y or l.z < StationBuilder.SAFE_MIN.z or l.z > StationBuilder.SAFE_MAX.z:
				continue
			var d := l.length()
			if d < best_d:
				best_d = d
				best = alien
		if best:
			var l := inv * best.global_position
			var from := xf * (StationBuilder.GUARDS[0] as Vector3)
			var guard_d := INF
			for g: Vector3 in StationBuilder.GUARDS:
				var d := g.distance_to(l)
				if d < guard_d:
					guard_d = d
					from = xf * g
			fx_event.rpc("station_zap", best.global_position, from)
			best.take_damage(99999.0, {"source": "station"})


func _on_ship_destroyed() -> void:
	if ending:
		return
	ending = true
	_show_end.rpc(true)
	await get_tree().create_timer(6.0).timeout
	_finish(true)


## Server (host menu): return to homebase with what was collected so far.
func abort_mission() -> void:
	if ending:
		return
	ending = true
	_show_end.rpc(false)
	await get_tree().create_timer(2.5).timeout
	_finish(false)


## Research points this dive has earned so far (see Game.dive_rp).
func dive_rp() -> Dictionary:
	return Game.dive_rp(int(ship.depth) if ship else 0, ship.stations_docked if ship else 0, nests_destroyed)


func _finish(destroyed: bool) -> void:
	if not is_inside_tree():
		return
	var depth := int(ship.depth) if ship else 0
	var rp := dive_rp()
	Game.apply_mission_result({
		"destroyed": destroyed, "depth": depth, "ship": str(stats.get("ship", "prospector")),
		"stations": ship.stations_docked if ship else 0, "nests": nests_destroyed, "kills": kills,
		"mined": int(ship.credits) if ship else 0, "ore": ship.ore.duplicate() if ship else {},
		"rp_depth": int(rp["depth"]), "rp_stations": int(rp["stations"]), "rp_nests": int(rp["nests"]),
		"rp": int(rp["total"]), "record": depth > best_depth,
	})
	Game.main.return_to_homebase()


# --- Replicated events -------------------------------------------------------------------------

@rpc("authority", "call_local", "reliable")
func _show_end(destroyed: bool) -> void:
	# Stop streaming our avatar to the host: it despawns the crew shortly and late packets for a
	# freed node would only produce errors.
	if local_player and local_player.has_node("Sync") and not multiplayer.is_server():
		var sync := local_player.get_node("Sync") as MultiplayerSynchronizer
		sync.replication_interval = 3600.0
		sync.delta_interval = 3600.0
	if hud == null:
		return
	var depth := int(ship.depth) if ship else 0
	var rp := int(dive_rp()["total"])
	if destroyed:
		hud.show_banner("MOTHERSHIP DESTROYED", "Depth reached: %d m  -  +%d research points\nThe crew is evacuated to homebase" % [depth, rp])
	else:
		hud.show_banner("MISSION ABORTED", "Returning to homebase  -  +%d research points" % rp, UiTheme.WARN)


@rpc("authority", "call_local", "reliable")
func _tutorial() -> void:
	if hud == null:
		return
	var tips := [
		["Walk to the PILOT seat at the front and press E. W raises the throttle.", 0],
		["The mining laser breaks crystals; the tractor field collects the chunks.", 0],
		["Fuel crystals grow in narrow side tunnels - only the scout fits.", 0],
		["Mined credits buy supplies in the waystation shops. Land (L) at each waystation to pass its bulkheads.", 0],
	]
	for i in tips.size():
		get_tree().create_timer(2.0 + i * 5.0).timeout.connect(func():
			if hud:
				hud.toast(tips[i][0], tips[i][1]))


@rpc("authority", "call_local", "unreliable")
func fx_event(kind: String, pos: Vector3, arg: Variant) -> void:
	match kind:
		"alien_die":
			var k := int(arg)
			Fx.explosion(pos, 1.2 if k == Alien.Kind.CRITTER else 2.4, Color(0.55, 1.0, 0.25))
			Sfx.play("screech", pos, -4.0, 1.4 if k == Alien.Kind.CRITTER else 1.0)
		"boarder_die":
			Fx.explosion(pos, 1.6, Color(0.4, 1.0, 0.9))
			Sfx.play("screech", pos, -2.0, 0.8)
		"crystal_break":
			var col: Color = arg if arg is Color else Color.WHITE
			Fx.sparks(pos, col, 26, 10.0, 0.08, 0.7)
			Fx.flash(pos, col, 5.0, 12.0, 0.3)
			Sfx.play("hit", pos, 0.0, 0.6)
		"fuel_pickup":
			Sfx.play("fuel_pickup", pos, -4.0)
		"sac_burst":
			Fx.explosion(pos, 3.0, Color(0.7, 1.0, 0.3))
			Sfx.play("egg_burst", pos, 2.0)
		"nest_dead":
			Fx.explosion(pos, 7.0, Color(0.8, 1.0, 0.3))
			Sfx.play("explosion", pos, 4.0, 1.3)
		"hatch":
			Fx.sparks(pos, Color(0.6, 1.0, 0.3), 12, 5.0)
			Sfx.play("egg_burst", pos, -8.0, 1.4)
		"scout_boom":
			Fx.explosion(pos, 4.5)
			Sfx.play("explosion", pos, 2.0, 1.2)
		"claw":
			Fx.sparks(pos, Color(1.0, 0.2, 0.2), 8, 4.0, 0.04, 0.3)
			Sfx.play("scratch", pos, -2.0)
		"station_zap":
			var from: Vector3 = arg
			Fx.tracer(from, pos, Color(1.0, 0.5, 0.25), 0.14, 0.14)
			Fx.flash(from, Color(1.0, 0.55, 0.3), 4.0, 8.0, 0.1)
			Sfx.play("rail", from, -4.0, 1.25)
