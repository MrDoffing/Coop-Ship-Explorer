extends Node
## Game root. Owns the replicated level slot (homebase or mission) and the local menus.
##
## Levels are spawned by the server through LevelSpawner, so every peer always runs the same
## level. Command line `-- --autotest=<scenario>` runs an automated test (scripts/dev/autotest.gd).

var level_root: Node
var level_spawner: MultiplayerSpawner
var ui: CanvasLayer
var menu: MainMenu
var pause_menu: PauseMenu


func _ready() -> void:
	Game.main = self
	level_root = Node.new()
	level_root.name = "Level"
	add_child(level_root)
	level_spawner = NetUtil.add_spawner(self, "LevelSpawner", level_root, _spawn_level)
	level_root.child_entered_tree.connect(_on_level_entered)
	level_root.child_exiting_tree.connect(_on_level_exiting)

	ui = CanvasLayer.new()
	ui.layer = 20
	add_child(ui)
	menu = MainMenu.new()
	ui.add_child(menu)
	menu.solo_requested.connect(start_solo)
	menu.host_requested.connect(_on_host)
	menu.join_requested.connect(_on_join)
	pause_menu = PauseMenu.new()
	ui.add_child(pause_menu)
	pause_menu.leave_requested.connect(leave_session)
	pause_menu.abort_requested.connect(_on_abort)

	Net.joined_session.connect(_on_joined)
	Net.join_failed.connect(_on_join_failed)
	Net.session_closed.connect(_on_session_closed)

	var autotest := _user_arg("--autotest=")
	if autotest != "":
		var at: Node = load("res://scripts/dev/autotest.gd").new()
		at.set("scenario", autotest)
		add_child(at)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and current_level() != null:
		pause_menu.toggle()
		get_viewport().set_input_as_handled()


func current_level() -> Node:
	for c in level_root.get_children():
		if not c.is_queued_for_deletion():
			return c
	return null


## Server: replace the current level on every peer.
func change_level(kind: String, data: Dictionary = {}) -> void:
	if not multiplayer.is_server():
		return
	# Let the level despawn its replicated contents in a safe order first.
	for c in level_root.get_children():
		if c.has_method("teardown"):
			await c.teardown()
	for c in level_root.get_children():
		level_root.remove_child(c)
		c.queue_free()
	var d := data.duplicate()
	d["kind"] = kind
	level_spawner.spawn(d)


## Server: start a new mission with the current upgrades.
func start_mission() -> void:
	change_level("mission", {
		"seed": randi() % 1000000,
		"stats": Game.ship_stats(),
		"best": int(Game.profile.get("best_depth", 0)),
	})


func return_to_homebase() -> void:
	change_level("homebase")


func start_solo() -> void:
	Net.start_solo()
	Game.save_settings()
	change_level("homebase")


## Capture the mouse during missions, free it in menus.
func restore_mouse() -> void:
	if Game.ui_blocking or Game.mission == null:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


## Leave the session (or the solo game) and return to the title screen.
func leave_session() -> void:
	pause_menu.hide_menu()
	get_tree().paused = false
	_clear_level()
	Net.leave()
	menu.show_menu("")


func _spawn_level(data: Variant) -> Node:
	var d: Dictionary = data
	var lvl: Node
	if d.get("kind", "") == "mission":
		lvl = MissionLevel.new()
		lvl.name = "Mission"
	else:
		lvl = HomebaseLevel.new()
		lvl.name = "Homebase"
	lvl.call("setup", d)
	return lvl


func _clear_level() -> void:
	for c in level_root.get_children():
		level_root.remove_child(c)
		c.queue_free()


func _on_level_entered(_node: Node) -> void:
	menu.hide()
	pause_menu.hide_menu()


func _on_level_exiting(_node: Node) -> void:
	_check_menu.call_deferred()


func _check_menu() -> void:
	if current_level() == null and not menu.visible:
		Game.ui_blocking = false
		menu.show_menu("Disconnected." if Net.mode == "client" else "")


func _on_host(port: int) -> void:
	var err := Net.host(port)
	if err != OK:
		menu.set_status("Could not host on port %d (error %d)." % [port, err])
		return
	Game.save_settings()
	change_level("homebase")


func _on_join(address: String, port: int) -> void:
	var err := Net.join(address, port)
	if err != OK:
		menu.set_status("Could not start connection (error %d)." % err)
		return
	Net.last_address = address if port == Net.DEFAULT_PORT else "%s:%d" % [address, port]
	Game.save_settings()
	menu.set_status("Connecting to %s:%d ..." % [address, port])


func _on_joined() -> void:
	menu.set_status("Connected. Waiting for the host...")


func _on_join_failed(reason: String) -> void:
	_clear_level()
	menu.show_menu(reason)


func _on_session_closed(reason: String) -> void:
	get_tree().paused = false
	pause_menu.hide_menu()
	_clear_level()
	menu.show_menu(reason)


func _on_abort() -> void:
	pause_menu.hide_menu()
	if Game.mission and multiplayer.is_server():
		Game.mission.call("abort_mission")


func _user_arg(prefix: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(prefix):
			return a.substr(prefix.length())
	return ""
