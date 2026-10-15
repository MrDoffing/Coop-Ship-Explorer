extends Node
## Global game state shared by every scene.
##
## Holds the crew's persistent profile (credits, upgrades, turret loadout), turns it into ship
## stats for a mission, stores local settings and registers the input actions. The server (host
## or solo player) owns and saves the profile; clients receive copies through sync_profile().

signal profile_changed
signal settings_changed

const SAVE_PATH := "user://savegame.json"
## Where the profile is saved (autotests point this elsewhere so they never touch real saves).
var save_path := SAVE_PATH
const SETTINGS_PATH := "user://settings.cfg"
## Where settings are saved (autotests point this elsewhere so they never change real settings).
var settings_path := SETTINGS_PATH

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

const UPGRADE_CATEGORIES := ["Mothership", "Weapons", "Scout", "Crew"]

## Upgrade catalogue. The cost of buying level n+1 is base * 1.65^n (rounded to 10).
const UPGRADES := {
	"hull": {"name": "Hull Plating", "desc": "+80 max hull integrity.", "cat": "Mothership", "base": 120, "max": 6},
	"shield_cap": {"name": "Shield Capacitors", "desc": "+40 max shield strength.", "cat": "Mothership", "base": 110, "max": 6},
	"shield_regen": {"name": "Shield Regenerator", "desc": "+25% shield recharge and 1s faster reboot.", "cat": "Mothership", "base": 140, "max": 4},
	"engine": {"name": "Engine Tuning", "desc": "+12% top speed and handling.", "cat": "Mothership", "base": 100, "max": 5},
	"fuel_tank": {"name": "Fuel Tanks", "desc": "+30 fuel capacity.", "cat": "Mothership", "base": 90, "max": 5},
	"fuel_eff": {"name": "Fuel Injectors", "desc": "-12% fuel consumption.", "cat": "Mothership", "base": 130, "max": 4},
	"hardening": {"name": "System Hardening", "desc": "-15% collateral damage to engine and weapons.", "cat": "Mothership", "base": 150, "max": 4},
	"turret_dmg": {"name": "Turret Calibration", "desc": "+20% turret damage.", "cat": "Weapons", "base": 120, "max": 6},
	"turret_rate": {"name": "Turret Autoloaders", "desc": "+15% turret fire rate.", "cat": "Weapons", "base": 130, "max": 5},
	"mining": {"name": "Mining Laser Focus", "desc": "+30% mining speed.", "cat": "Weapons", "base": 90, "max": 5},
	"laser_overcharge": {"name": "Laser Overcharge", "desc": "+50% mining laser damage to aliens and egg sacs.", "cat": "Weapons", "base": 110, "max": 4},
	"auto_cannons": {"name": "Auto Cannons", "desc": "A small automatic turret on a hull edge. Weak, but it never stops shooting.", "cat": "Weapons", "base": 650, "max": 4},
	"tractor": {"name": "Tractor Field", "desc": "+25% mineral collection range.", "cat": "Weapons", "base": 80, "max": 4},
	"scout_armor": {"name": "Scout Armor", "desc": "+30 scout hull.", "cat": "Scout", "base": 90, "max": 5},
	"scout_guns": {"name": "Scout Blasters", "desc": "+25% scout weapon damage.", "cat": "Scout", "base": 100, "max": 5},
	"scout_cargo": {"name": "Scout Cargo Hold", "desc": "+20 fuel cargo capacity.", "cat": "Scout", "base": 80, "max": 4},
	"scout_engine": {"name": "Scout Thrusters", "desc": "+12% scout speed.", "cat": "Scout", "base": 80, "max": 4},
	"blaster": {"name": "Crew Blasters", "desc": "+25% blaster damage.", "cat": "Crew", "base": 90, "max": 5},
	"toolkit": {"name": "Toolkits", "desc": "+30% repair speed.", "cat": "Crew", "base": 90, "max": 5},
	"suit": {"name": "Armored Suits", "desc": "+25 crew health.", "cat": "Crew", "base": 80, "max": 4},
}

## Turret weapons that can be bought and mounted on the port or starboard turret.
const WEAPONS := {
	"pulse": {"name": "Pulse Cannon", "desc": "Rapid energy bolts. Reliable all-rounder.", "cost": 0},
	"flak": {"name": "Flak Cannon", "desc": "Short-range pellet bursts that shred swarms.", "cost": 450},
	"plasma": {"name": "Plasma Mortar", "desc": "Slow orbs that explode, damaging everything nearby.", "cost": 650},
	"rail": {"name": "Rail Lance", "desc": "Piercing hitscan slug. Slow but devastating.", "cost": 900},
}

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
		"credits": 0,
		"best_depth": 0,
		"missions": 0,
		"total_earned": 0,
		"upgrades": {},
		"weapons": ["pulse"],
		"loadout": {"left": "pulse", "right": "pulse"},
		"last_mission": {},
	}


func load_profile() -> void:
	profile = default_profile()
	if FileAccess.file_exists(save_path):
		var f := FileAccess.open(save_path, FileAccess.READ)
		if f:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				for k in parsed:
					profile[k] = parsed[k]
	profile_changed.emit()


func save_profile() -> void:
	if not multiplayer.is_server():
		return
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(profile, "\t"))


func reset_profile() -> void:
	profile = default_profile()
	save_profile()
	profile_changed.emit()


func credits() -> int:
	return int(profile.get("credits", 0))


func upgrade_level(id: String) -> int:
	return int(profile.get("upgrades", {}).get(id, 0))


## Price of the next level of an upgrade, or -1 when it is maxed out.
func upgrade_cost(id: String) -> int:
	var u: Dictionary = UPGRADES[id]
	var lvl := upgrade_level(id)
	if lvl >= int(u["max"]):
		return -1
	return int(round(float(u["base"]) * pow(1.65, lvl) / 10.0)) * 10


func owns_weapon(id: String) -> bool:
	return id in profile.get("weapons", [])


func request_buy_upgrade(id: String) -> void:
	_buy_upgrade.rpc_id(1, id)


func request_buy_weapon(id: String) -> void:
	_buy_weapon.rpc_id(1, id)


func request_equip(slot: String, weapon: String) -> void:
	_equip_weapon.rpc_id(1, slot, weapon)


@rpc("any_peer", "call_local", "reliable")
func _buy_upgrade(id: String) -> void:
	if not multiplayer.is_server() or not UPGRADES.has(id) or mission != null:
		return
	var cost := upgrade_cost(id)
	if cost < 0 or credits() < cost:
		return
	profile["credits"] = credits() - cost
	var ups: Dictionary = profile.get("upgrades", {})
	ups[id] = upgrade_level(id) + 1
	profile["upgrades"] = ups
	_commit_profile()


@rpc("any_peer", "call_local", "reliable")
func _buy_weapon(id: String) -> void:
	if not multiplayer.is_server() or not WEAPONS.has(id) or owns_weapon(id) or mission != null:
		return
	var cost := int(WEAPONS[id]["cost"])
	if credits() < cost:
		return
	profile["credits"] = credits() - cost
	var owned: Array = profile.get("weapons", [])
	owned.append(id)
	profile["weapons"] = owned
	_commit_profile()


@rpc("any_peer", "call_local", "reliable")
func _equip_weapon(slot: String, id: String) -> void:
	if not multiplayer.is_server() or not slot in ["left", "right"] or not owns_weapon(id):
		return
	var loadout: Dictionary = profile.get("loadout", {})
	loadout[slot] = id
	profile["loadout"] = loadout
	_commit_profile()


## Server: bank the result of a finished mission.
func apply_mission_result(result: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	profile["credits"] = credits() + int(result.get("earned", 0))
	profile["total_earned"] = int(profile.get("total_earned", 0)) + int(result.get("earned", 0))
	profile["best_depth"] = maxi(int(profile.get("best_depth", 0)), int(result.get("depth", 0)))
	profile["missions"] = int(profile.get("missions", 0)) + 1
	profile["last_mission"] = result
	_commit_profile()


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


## Mission stats derived from the purchased upgrades.
func ship_stats() -> Dictionary:
	var loadout: Dictionary = profile.get("loadout", {})
	return {
		"max_hull": 400.0 + 80.0 * upgrade_level("hull"),
		"max_shield": 120.0 + 40.0 * upgrade_level("shield_cap"),
		"shield_regen": 9.0 * (1.0 + 0.25 * upgrade_level("shield_regen")),
		"shield_reboot": maxf(4.0, 9.0 - upgrade_level("shield_regen")),
		"max_speed": 9.0 * (1.0 + 0.12 * upgrade_level("engine")),
		"accel": 2.6 * (1.0 + 0.15 * upgrade_level("engine")),
		"yaw_rate": deg_to_rad(26.0) * (1.0 + 0.1 * upgrade_level("engine")),
		"vert_speed": 5.0 * (1.0 + 0.1 * upgrade_level("engine")),
		"max_fuel": 100.0 + 30.0 * upgrade_level("fuel_tank"),
		"fuel_burn": pow(0.88, upgrade_level("fuel_eff")),
		"collateral": 0.35 * pow(0.85, upgrade_level("hardening")),
		"turret_damage": 1.0 + 0.2 * upgrade_level("turret_dmg"),
		"turret_rate": 1.0 + 0.15 * upgrade_level("turret_rate"),
		"mining_power": 24.0 * (1.0 + 0.3 * upgrade_level("mining")),
		"mining_vs_alien": 1.0 + 0.5 * upgrade_level("laser_overcharge"),
		"edge_cannons": upgrade_level("auto_cannons"),
		"mining_range": 48.0,
		"tractor_range": 42.0 * (1.0 + 0.25 * upgrade_level("tractor")),
		"scout_hp": 70.0 + 30.0 * upgrade_level("scout_armor"),
		"scout_damage": 7.0 * (1.0 + 0.25 * upgrade_level("scout_guns")),
		"scout_cargo": 40.0 + 20.0 * upgrade_level("scout_cargo"),
		"scout_speed": 17.0 * (1.0 + 0.12 * upgrade_level("scout_engine")),
		"blaster_damage": 20.0 * (1.0 + 0.25 * upgrade_level("blaster")),
		"repair_rate": 14.0 * (1.0 + 0.3 * upgrade_level("toolkit")),
		"crew_hp": 100.0 + 25.0 * upgrade_level("suit"),
		"weapon_left": str(loadout.get("left", "pulse")),
		"weapon_right": str(loadout.get("right", "pulse")),
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
