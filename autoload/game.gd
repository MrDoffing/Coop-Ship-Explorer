extends Node
## Global game state shared by every scene.
##
## Holds the crew's persistent profile (research points, unlocked guns, the motherships the crew
## owns with their upgrades, and the selected ship), turns it into ship stats for a mission, stores
## local settings and registers the input actions. The server (host or solo player) owns and saves
## the profile; clients receive copies through sync_profile().
##
## Progress is split in two: research points (meta progression) are earned at the end of every dive
## and spent at homebase; credits from mining only exist during a dive and are spent in waystation
## shops.

signal profile_changed
signal settings_changed

const SAVE_PATH := "user://savegame.json"
## Where the profile is saved (autotests point this elsewhere so they never touch real saves).
var save_path := SAVE_PATH
const SETTINGS_PATH := "user://settings.cfg"
## Where settings are saved (autotests point this elsewhere so they never change real settings).
var settings_path := SETTINGS_PATH
## Version 2: research points, ships and gun unlocks (version 1 had credits and homebase upgrades).
const PROFILE_VERSION := 2

# Physics layer bits (also named in project.godot).
const LAYER_CAVE := 1
const LAYER_HULL := 2
const LAYER_INTERIOR := 4
const LAYER_PLAYER := 8
const LAYER_ENEMY := 16
const LAYER_INTERACT := 32
const LAYER_SCOUT := 64
const LAYER_MINERAL := 128
const LAYER_BOARDER := 256
## Walkable waystation geometry (pier, building, railings).
const LAYER_STATION := 1024

const PLAYER_COLORS: Array[Color] = [
	Color(0.25, 0.65, 1.0), Color(1.0, 0.55, 0.2), Color(0.4, 0.95, 0.45), Color(0.95, 0.4, 0.85),
]

## Weapons for the manned guns. Every gun launches with a Pulse Cannon; the others are unlocked at
## homebase with research points and then turn up in waystation shops during a dive.
const GUNS := {
	"pulse": {"name": "Pulse Cannon", "short": "Rapid energy bolts", "desc": "Rapid energy bolts. A reliable all-rounder, fitted to every gun at launch.", "rp": 0},
	"flak": {"name": "Flak Cannon", "short": "Rapid close-range flak bursts", "desc": "Rapid bursts of flak that shred anything close to the ship. Useless at long range.", "rp": 60},
	"plasma": {"name": "Plasma Mortar", "short": "Exploding plasma orbs", "desc": "Slow orbs that burst in a huge blast, damaging everything in it.", "rp": 100},
	"rail": {"name": "Rail Lance", "short": "Piercing hitscan slug", "desc": "Piercing hitscan slug. Slow but devastating.", "rp": 140},
}
const GUN_ORDER := ["pulse", "flak", "plasma", "rail"]

## Upgrades bought at homebase for each mothership. Level n+1 costs base * growth^n research
## points (rounded to 5). Turret slots are capped by the ship's hardpoints.
const SHIP_UPGRADES := {
	"hull": {"name": "Hull Plating", "desc": "+15% max hull integrity", "base": 30, "growth": 1.6, "max": 5},
	"shield": {"name": "Shield Capacitors", "desc": "+15% max shield", "base": 30, "growth": 1.6, "max": 5},
	"engine": {"name": "Engine Tuning", "desc": "+8% speed and handling", "base": 35, "growth": 1.6, "max": 4},
	"slots": {"name": "Turret Slot", "desc": "+1 auto turret slot. Slots launch empty; fill them from waystation shops.", "base": 80, "growth": 1.8, "max": -1},
}
const SHIP_UPGRADE_ORDER := ["hull", "shield", "engine", "slots"]

## Research points for a dive: per 10 m of depth, per waystation reached and per nest destroyed.
const RP_PER_10M := 1
const RP_PER_STATION := 10
const RP_PER_NEST := 2
## Converting a version 1 save: lifetime credits earned per research point.
const RP_LEGACY_RATE := 45.0

var profile: Dictionary = {}
var mouse_sensitivity := 0.0025
var invert_y := false
var master_volume := 0.8
var fullscreen := false
## How many crew bots the host wants aboard (restored when a session starts).
var bot_count := 0
## True while a menu that needs the mouse is open (pause menu etc.).
var ui_blocking := false
## The running mission level, set by the mission itself.
var mission: Node = null
## The game root (scripts/main.gd), set when it starts.
var main: Node = null
## The save on disk is still in the old format: back it up before overwriting it.
var _legacy_on_disk := false
## Cheat (homebase cheat menu): every dive starts with this many credits. Not saved.
var cheat_dive_credits := 0


func _ready() -> void:
	_setup_input()
	_load_settings()
	load_profile()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("fullscreen"):
		fullscreen = not fullscreen
		apply_settings()
		save_settings()


## Peer id of the caller of the current RPC (or the local peer for local calls).
func sender_id() -> int:
	var id := multiplayer.get_remote_sender_id()
	return id if id != 0 else multiplayer.get_unique_id()


# --- Profile -----------------------------------------------------------------------------------

func default_profile() -> Dictionary:
	return {
		"version": PROFILE_VERSION,
		"rp": 0,
		"rp_total": 0,
		"best_depth": 0,
		"missions": 0,
		"guns": ["pulse"],
		"ships": {"prospector": {}},
		"ship": "prospector",
		"last_mission": {},
	}


func load_profile() -> void:
	profile = default_profile()
	_legacy_on_disk = false
	if FileAccess.file_exists(save_path):
		var f := FileAccess.open(save_path, FileAccess.READ)
		if f:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				if int((parsed as Dictionary).get("version", 1)) < PROFILE_VERSION:
					profile = migrate_profile(parsed)
					_legacy_on_disk = true
				else:
					for k in parsed:
						profile[k] = parsed[k]
	profile_changed.emit()


## Convert a version 1 profile (credits and homebase upgrades) to research points. The old
## upgrades no longer exist; lifetime earnings become research points and bought guns stay unlocked.
func migrate_profile(old: Dictionary) -> Dictionary:
	var p := default_profile()
	p["best_depth"] = int(old.get("best_depth", 0))
	p["missions"] = int(old.get("missions", 0))
	var rp := int(round(float(old.get("total_earned", 0)) / RP_LEGACY_RATE))
	p["rp"] = rp
	p["rp_total"] = rp
	var guns: Array = ["pulse"]
	for w in old.get("weapons", []):
		if GUNS.has(str(w)) and not str(w) in guns:
			guns.append(str(w))
	p["guns"] = guns
	p["migrated"] = {"rp": rp, "guns": guns.size() - 1}
	return p


func save_profile() -> void:
	if not multiplayer.is_server():
		return
	if _legacy_on_disk:
		# Keep the old save next to the new one the first time it is overwritten.
		_legacy_on_disk = false
		var backup := save_path.get_basename() + "_v1_backup.json"
		if FileAccess.file_exists(save_path) and not FileAccess.file_exists(backup):
			var src := FileAccess.open(save_path, FileAccess.READ)
			var dst := FileAccess.open(backup, FileAccess.WRITE)
			if src and dst:
				dst.store_string(src.get_as_text())
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(profile, "\t"))


func reset_profile() -> void:
	profile = default_profile()
	save_profile()
	profile_changed.emit()


func rp() -> int:
	return int(profile.get("rp", 0))


func owns_gun(id: String) -> bool:
	return id in profile.get("guns", [])


func owns_ship(id: String) -> bool:
	return (profile.get("ships", {}) as Dictionary).has(id)


func selected_ship() -> String:
	var id := str(profile.get("ship", "prospector"))
	return id if owns_ship(id) and ShipTypes.exists(id) else "prospector"


func ship_level(ship_id: String, upgrade: String) -> int:
	return int((profile.get("ships", {}) as Dictionary).get(ship_id, {}).get(upgrade, 0))


func ship_upgrade_max(ship_id: String, upgrade: String) -> int:
	if upgrade == "slots":
		var t := ShipTypes.get_type(ship_id)
		return int(t["max_slots"]) - int(t["slots"])
	return int(SHIP_UPGRADES[upgrade]["max"])


## Research point price of the next level of a ship upgrade, or -1 when it is maxed out.
func ship_upgrade_cost(ship_id: String, upgrade: String) -> int:
	var lvl := ship_level(ship_id, upgrade)
	if lvl >= ship_upgrade_max(ship_id, upgrade):
		return -1
	var u: Dictionary = SHIP_UPGRADES[upgrade]
	return int(round(float(u["base"]) * pow(float(u["growth"]), lvl) / 5.0)) * 5


## Auto turret slots of a ship (all empty at launch).
func turret_slots(ship_id: String) -> int:
	return int(ShipTypes.get_type(ship_id)["slots"]) + ship_level(ship_id, "slots")


func request_unlock_ship(id: String) -> void:
	_unlock_ship.rpc_id(1, id)


func request_select_ship(id: String) -> void:
	_select_ship.rpc_id(1, id)


func request_ship_upgrade(upgrade: String) -> void:
	_ship_upgrade.rpc_id(1, upgrade)


func request_unlock_gun(id: String) -> void:
	_unlock_gun.rpc_id(1, id)


@rpc("any_peer", "call_local", "reliable")
func _unlock_ship(id: String) -> void:
	if not multiplayer.is_server() or not ShipTypes.exists(id) or owns_ship(id) or mission != null:
		return
	var cost := int(ShipTypes.TYPES[id]["cost"])
	if rp() < cost:
		return
	profile["rp"] = rp() - cost
	var ships: Dictionary = profile.get("ships", {})
	ships[id] = {}
	profile["ships"] = ships
	profile["ship"] = id
	_commit_profile()


@rpc("any_peer", "call_local", "reliable")
func _select_ship(id: String) -> void:
	if not multiplayer.is_server() or not owns_ship(id) or mission != null:
		return
	profile["ship"] = id
	_commit_profile()


@rpc("any_peer", "call_local", "reliable")
func _ship_upgrade(upgrade: String) -> void:
	if not multiplayer.is_server() or not SHIP_UPGRADES.has(upgrade) or mission != null:
		return
	var id := selected_ship()
	var cost := ship_upgrade_cost(id, upgrade)
	if cost < 0 or rp() < cost:
		return
	profile["rp"] = rp() - cost
	var ships: Dictionary = profile.get("ships", {})
	var levels: Dictionary = ships.get(id, {})
	levels[upgrade] = ship_level(id, upgrade) + 1
	ships[id] = levels
	profile["ships"] = ships
	_commit_profile()


@rpc("any_peer", "call_local", "reliable")
func _unlock_gun(id: String) -> void:
	if not multiplayer.is_server() or not GUNS.has(id) or owns_gun(id) or mission != null:
		return
	var cost := int(GUNS[id]["rp"])
	if rp() < cost:
		return
	profile["rp"] = rp() - cost
	var owned: Array = profile.get("guns", [])
	owned.append(id)
	profile["guns"] = owned
	_commit_profile()


## Research points earned by a dive (see the RP_* constants).
static func dive_rp(depth: int, stations: int, nests: int) -> Dictionary:
	var by_depth := int(depth / 10) * RP_PER_10M
	var by_stations := stations * RP_PER_STATION
	var by_nests := nests * RP_PER_NEST
	return {"depth": by_depth, "stations": by_stations, "nests": by_nests, "total": by_depth + by_stations + by_nests}


## Server: bank the result of a finished mission (research points; the dive's credits are gone).
func apply_mission_result(result: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var earned := int(result.get("rp", 0))
	profile["rp"] = rp() + earned
	profile["rp_total"] = int(profile.get("rp_total", 0)) + earned
	profile["best_depth"] = maxi(int(profile.get("best_depth", 0)), int(result.get("depth", 0)))
	profile["missions"] = int(profile.get("missions", 0)) + 1
	profile["last_mission"] = result
	profile.erase("migrated")
	_commit_profile()


# --- Cheats ------------------------------------------------------------------------------------

## The homebase cheat menu is for testing: it only exists in debug builds (running from the editor
## or the Godot executable), and only the host can use it.
func cheats_allowed() -> bool:
	return OS.is_debug_build()


## Where the profile from before the first cheat is kept (next to the save).
func cheat_backup_path() -> String:
	return save_path.get_basename() + "_precheat.json"


func has_cheat_backup() -> bool:
	return FileAccess.file_exists(cheat_backup_path())


## Host: apply a cheat. Kinds: "rp" (add `amount` research points), "unlock_ships", "unlock_guns",
## "max_ship" (the selected ship's upgrades), "max_all" (every owned ship's upgrades), "fresh" (a
## brand-new profile) and "restore" (the profile from before the first cheat).
func request_cheat(kind: String, amount := 0) -> void:
	_cheat.rpc_id(1, kind, amount)


@rpc("any_peer", "call_local", "reliable")
func _cheat(kind: String, amount: int) -> void:
	if not multiplayer.is_server() or sender_id() != 1 or not cheats_allowed() or mission != null:
		return
	if kind == "restore":
		_restore_cheat_backup()
		return
	# Keep the real profile the first time a cheat changes it.
	if not has_cheat_backup():
		var f := FileAccess.open(cheat_backup_path(), FileAccess.WRITE)
		if f:
			f.store_string(JSON.stringify(profile, "\t"))
	match kind:
		"rp":
			profile["rp"] = rp() + maxi(amount, 0)
		"unlock_ships":
			var ships: Dictionary = profile.get("ships", {})
			for id: String in ShipTypes.ORDER:
				if not ships.has(id):
					ships[id] = {}
			profile["ships"] = ships
		"unlock_guns":
			profile["guns"] = GUN_ORDER.duplicate()
		"max_ship", "max_all":
			var ships: Dictionary = profile.get("ships", {})
			for id: String in ships:
				if kind == "max_ship" and id != selected_ship():
					continue
				var levels: Dictionary = ships[id]
				for up: String in SHIP_UPGRADE_ORDER:
					levels[up] = ship_upgrade_max(id, up)
				ships[id] = levels
			profile["ships"] = ships
		"fresh":
			profile = default_profile()
		_:
			return
	_commit_profile()


func _restore_cheat_backup() -> void:
	var path := cheat_backup_path()
	if not FileAccess.file_exists(path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return
	var p := default_profile()
	for k in parsed:
		p[k] = parsed[k]
	profile = p
	_commit_profile()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _commit_profile() -> void:
	save_profile()
	sync_profile.rpc(profile)


## Server: send the current profile to one peer (used when a client joins).
func push_profile_to(peer_id: int) -> void:
	sync_profile.rpc_id(peer_id, profile)


@rpc("authority", "call_local", "reliable")
func sync_profile(p: Dictionary) -> void:
	profile = p
	profile_changed.emit()


## Mission stats for a ship (the selected one by default): its type's base stats plus the
## homebase upgrades bought for it. Waystation items change them further during a dive.
func ship_stats(ship_id := "") -> Dictionary:
	var id := ship_id if ShipTypes.exists(ship_id) else selected_ship()
	var t := ShipTypes.get_type(id)
	var hull_l := ship_level(id, "hull")
	var shield_l := ship_level(id, "shield")
	var engine_l := ship_level(id, "engine")
	return {
		"ship": id,
		"base_hull": float(t["hull"]),
		"base_shield": float(t["shield"]),
		"max_hull": float(t["hull"]) * (1.0 + 0.15 * hull_l),
		"max_shield": float(t["shield"]) * (1.0 + 0.15 * shield_l),
		"shield_regen": 9.0,
		"shield_reboot": 9.0,
		"max_speed": float(t["speed"]) * (1.0 + 0.08 * engine_l),
		"accel": float(t["accel"]) * (1.0 + 0.1 * engine_l),
		"yaw_rate": deg_to_rad(float(t["yaw"])) * (1.0 + 0.06 * engine_l),
		"vert_speed": float(t["vert"]) * (1.0 + 0.06 * engine_l),
		"max_fuel": 100.0,
		"fuel_burn": 1.0,
		"collateral": 0.35,
		"turret_damage": 1.0,
		"turret_rate": 1.0,
		# Mining lasers deal Mothership.LASER_ALIEN_SHARE of this to aliens and egg sacs.
		"mining_power": 40.0 * float(t["mining"]),
		"mining_vs_alien": float(t["laser_vs_alien"]),
		"overcharge_step": 0.5 * float(t["laser_vs_alien"]),
		"mining_range": 60.0,
		# Measured from the tip of the mining laser, so it reaches everything the laser does.
		"tractor_range": 64.0,
		"scout_hp": 70.0 * float(t["scout_hp"]),
		"scout_damage": 7.0 * float(t["scout_damage"]),
		"scout_cargo": 40.0,
		"scout_speed": 17.0 * float(t["scout_speed"]),
		"blaster_damage": 20.0,
		"repair_rate": 14.0,
		"crew_hp": 100.0,
		"turret_slots": turret_slots(id),
	}


# --- Settings ----------------------------------------------------------------------------------

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(settings_path) == OK:
		mouse_sensitivity = float(cfg.get_value("input", "mouse_sensitivity", mouse_sensitivity))
		invert_y = bool(cfg.get_value("input", "invert_y", invert_y))
		master_volume = float(cfg.get_value("audio", "master_volume", master_volume))
		fullscreen = bool(cfg.get_value("video", "fullscreen", fullscreen))
		Net.local_name = str(cfg.get_value("player", "name", Net.local_name))
		Net.last_address = str(cfg.get_value("player", "last_address", Net.last_address))
		bot_count = int(cfg.get_value("player", "bots", bot_count))
	apply_settings()


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("input", "mouse_sensitivity", mouse_sensitivity)
	cfg.set_value("input", "invert_y", invert_y)
	cfg.set_value("audio", "master_volume", master_volume)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("player", "name", Net.local_name)
	cfg.set_value("player", "last_address", Net.last_address)
	cfg.set_value("player", "bots", bot_count)
	cfg.save(settings_path)


func apply_settings() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master_volume, 0.0001)))
	var want := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.get_name() != "headless" and DisplayServer.window_get_mode() != want:
		DisplayServer.window_set_mode(want)
	settings_changed.emit()


# --- Input -------------------------------------------------------------------------------------

func _setup_input() -> void:
	_bind_keys("move_forward", [KEY_W, KEY_UP])
	_bind_keys("move_back", [KEY_S, KEY_DOWN])
	_bind_keys("move_left", [KEY_A, KEY_LEFT])
	_bind_keys("move_right", [KEY_D, KEY_RIGHT])
	_bind_keys("jump", [KEY_SPACE])
	_bind_keys("descend", [KEY_CTRL, KEY_C])
	_bind_keys("sprint", [KEY_SHIFT])
	_bind_keys("interact", [KEY_E])
	_bind_keys("tool_blaster", [KEY_1])
	_bind_keys("tool_toolkit", [KEY_2])
	_bind_keys("tool_swap", [KEY_Q])
	_bind_keys("autopilot", [KEY_T])
	_bind_keys("full_stop", [KEY_X])
	_bind_keys("emergency", [KEY_B])
	_bind_keys("land", [KEY_L])
	_bind_keys("drop", [KEY_G])
	_bind_keys("equip", [KEY_F])
	_bind_keys("reload", [KEY_R])
	_bind_keys("crew_list", [KEY_TAB])
	_bind_keys("pause", [KEY_ESCAPE])
	_bind_keys("fullscreen", [KEY_F11])
	_bind_mouse("fire", MOUSE_BUTTON_LEFT)
	_bind_mouse("aim", MOUSE_BUTTON_RIGHT)
	_bind_mouse("tool_next", MOUSE_BUTTON_WHEEL_DOWN)
	_bind_mouse("tool_prev", MOUSE_BUTTON_WHEEL_UP)


func _bind_keys(action: String, keys: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)


func _bind_mouse(action: String, button: MouseButton) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)
