class_name NetUtil
extends RefCounted
## Helpers for replicating nodes that are built from code.


## Add a MultiplayerSynchronizer named "Sync" to `root`. Properties in `always` are sent every
## `interval` seconds, properties in `on_change` only when they change. All of them are included
## in the spawn packet so late joiners start with the current state.
##
## Call this from _init() so the synchronizer exists before the node enters the tree; that way
## spawn state is applied before _ready() runs on remote peers.
static func add_sync(root: Node, always: Array, on_change: Array, interval := 0.05) -> MultiplayerSynchronizer:
	var cfg := SceneReplicationConfig.new()
	for p in always:
		var path := NodePath(".:" + str(p))
		cfg.add_property(path)
		cfg.property_set_spawn(path, true)
		cfg.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ALWAYS)
	for p in on_change:
		var path := NodePath(".:" + str(p))
		cfg.add_property(path)
		cfg.property_set_spawn(path, true)
		cfg.property_set_replication_mode(path, SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE)
	var sync := MultiplayerSynchronizer.new()
	sync.name = "Sync"
	sync.replication_interval = interval
	sync.delta_interval = interval
	sync.replication_config = cfg
	root.add_child(sync)
	return sync


## Create a MultiplayerSpawner under `owner_node` that spawns into `target` through `spawn_fn`.
static func add_spawner(owner_node: Node, spawner_name: String, target: Node, spawn_fn: Callable) -> MultiplayerSpawner:
	var sp := MultiplayerSpawner.new()
	sp.name = spawner_name
	owner_node.add_child(sp)
	sp.spawn_path = sp.get_path_to(target)
	sp.spawn_function = spawn_fn
	# Children leave the tree in reverse order. Keeping spawners first means spawned nodes (and
	# anything spawned inside them) despawn before their spawner tears everything down at once.
	owner_node.move_child(sp, 0)
	return sp


## Exponential smoothing factor for frame-rate independent lerps.
static func smooth(rate: float, delta: float) -> float:
	return 1.0 - exp(-rate * delta)
