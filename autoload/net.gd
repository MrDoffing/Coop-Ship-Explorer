extends Node
## Networking: solo play, hosting and joining (ENet), and the shared crew roster.
##
## Solo play runs on the default offline peer, so the local player is always the "server" and all
## server-side game code works the same way in every mode.
##
## Crew bots also live in the roster, under negative ids, so they take up crew slots: bots are
## only available while fewer than MAX_PLAYERS humans are aboard, and a joining human bumps one.

signal roster_changed
## Client: connected and registered with the host.
signal joined_session
signal join_failed(reason: String)
## The session ended unexpectedly (host left, connection lost...).
signal session_closed(reason: String)
## Server: a peer finished registering (used to spawn late joiners).
signal player_registered(peer_id: int)
## Server: a registered peer left.
signal player_left(peer_id: int)

const DEFAULT_PORT := 24565
const MAX_PLAYERS := 4
const BOT_NAMES := ["Bolt", "Rivet", "Sprocket"]

## peer_id -> {"name": String, "color": int, "bot": bool}. Bots use negative ids.
var roster: Dictionary = {}
## "", "solo", "host" or "client".
var mode := ""
var local_name := "Pilot"
var last_address := "127.0.0.1"
var _registered := false


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func is_online() -> bool:
	return mode == "host" or mode == "client"


func start_solo() -> void:
	_reset_peer()
	mode = "solo"
	roster = {1: {"name": local_name, "color": 0}}
	_restore_bots()
	roster_changed.emit()


func host(port: int) -> Error:
	_reset_peer()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PLAYERS - 1)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	mode = "host"
	roster = {1: {"name": local_name, "color": 0}}
	_restore_bots()
	roster_changed.emit()
	return OK


func join(address: String, port: int) -> Error:
	_reset_peer()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	mode = "client"
	_registered = false
	return OK


## Leave the current session (or solo game) and go back to an offline state.
func leave() -> void:
	var was_client := mode == "client"
	mode = ""
	_reset_peer()
	roster.clear()
	roster_changed.emit()
	if was_client:
		Game.load_profile()


func player_name(peer_id: int) -> String:
	return str(roster.get(peer_id, {}).get("name", "Crew %d" % peer_id))


func player_color(peer_id: int) -> Color:
	var idx := int(roster.get(peer_id, {}).get("color", 0))
	return Game.PLAYER_COLORS[idx % Game.PLAYER_COLORS.size()]


static func is_bot(peer_id: int) -> bool:
	return peer_id < 0


func bot_ids() -> Array[int]:
	var ids: Array[int] = []
	for id in roster:
		if int(id) < 0:
			ids.append(int(id))
	ids.sort()
	ids.reverse()
	return ids


func human_count() -> int:
	return roster.size() - bot_ids().size()


## Server: add a crew bot if there is a free crew slot.
func add_bot() -> bool:
	if not multiplayer.is_server() or roster.size() >= MAX_PLAYERS:
		return false
	var id := -1
	while roster.has(id):
		id -= 1
	roster[id] = {"name": BOT_NAMES[(-id - 1) % BOT_NAMES.size()], "color": _free_color(), "bot": true}
	_set_roster.rpc(roster)
	return true


## Server: remove a crew bot (the most recently added one by default).
func remove_bot(id := 0) -> bool:
	if not multiplayer.is_server():
		return false
	var ids := bot_ids()
	if ids.is_empty():
		return false
	if id == 0 or not roster.has(id):
		id = ids[ids.size() - 1]
	roster.erase(id)
	_set_roster.rpc(roster)
	player_left.emit(id)
	return true


## Re-add the host's preferred number of bots when a session starts.
func _restore_bots() -> void:
	var want := clampi(Game.bot_count, 0, MAX_PLAYERS - 1)
	var id := -1
	while want > 0 and roster.size() < MAX_PLAYERS:
		roster[id] = {"name": BOT_NAMES[(-id - 1) % BOT_NAMES.size()], "color": _free_color(), "bot": true}
		id -= 1
		want -= 1


func _reset_peer() -> void:
	var peer := multiplayer.multiplayer_peer
	if peer and not peer is OfflineMultiplayerPeer:
		peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()


func _free_color() -> int:
	var used := []
	for id in roster:
		used.append(int(roster[id]["color"]))
	for i in Game.PLAYER_COLORS.size():
		if not i in used:
			return i
	return 0


func _on_peer_connected(_id: int) -> void:
	pass # Peers register themselves once connected (see _register).


func _on_peer_disconnected(id: int) -> void:
	if multiplayer.is_server() and roster.has(id):
		roster.erase(id)
		_set_roster.rpc(roster)
		player_left.emit(id)


func _on_connected() -> void:
	_register.rpc_id(1, local_name)


func _on_connection_failed() -> void:
	mode = ""
	_reset_peer()
	join_failed.emit("Could not connect to host.")


func _on_server_disconnected() -> void:
	if mode != "client":
		return
	mode = ""
	_reset_peer()
	roster.clear()
	Game.load_profile()
	session_closed.emit("Lost connection to the host.")


@rpc("any_peer", "reliable")
func _register(pname: String) -> void:
	if not multiplayer.is_server():
		return
	var id := multiplayer.get_remote_sender_id()
	if roster.size() >= MAX_PLAYERS:
		# Humans take priority over crew bots.
		if not remove_bot():
			_rejected.rpc_id(id, "The crew is full.")
			return
	var clean := pname.strip_edges().substr(0, 16)
	if clean.is_empty():
		clean = "Crew %d" % roster.size()
	roster[id] = {"name": clean, "color": _free_color()}
	Game.push_profile_to(id)
	_set_roster.rpc(roster)
	player_registered.emit(id)


@rpc("authority", "reliable")
func _rejected(reason: String) -> void:
	mode = ""
	_reset_peer()
	join_failed.emit(reason)


@rpc("authority", "call_local", "reliable")
func _set_roster(r: Dictionary) -> void:
	roster = r
	roster_changed.emit()
	if mode == "client" and not _registered:
		_registered = true
		joined_session.emit()
