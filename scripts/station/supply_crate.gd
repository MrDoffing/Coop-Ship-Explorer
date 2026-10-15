class_name SupplyCrate
extends Node3D
## A crate of free supplies from a waystation (see RunItems).
##
## Crates live in the mothership's interior (Interior/Cargo, ship-local space like the crew), so
## once carried aboard they ride along. While the ship is landed its frame is fixed, so the same
## space also covers the pier and the station building. The server decides who carries a crate;
## every peer places a carried crate in its carrier's hands.

const SIZE := Vector3(0.9, 0.6, 0.6)

# Replicated (server authority). Position and yaw are ship-local and only used while not carried.
var carrier := 0
var net_pos := Vector3.ZERO
var net_yaw := 0.0

var item := ""
var _ship: Mothership
var _area: Area3D
var _label: Label3D
var _last_carrier := -1
## Server: where the carrier last stood (to drop the crate if they disconnect or are knocked out).
var last_carrier_pos := Vector3.ZERO


func _init() -> void:
	NetUtil.add_sync(self, [], ["carrier", "net_pos", "net_yaw"], 0.05)


func setup(data: Dictionary) -> void:
	name = str(data["name"])
	item = str(data["item"])
	position = data["pos"]
	net_pos = position
	net_yaw = float(data.get("yaw", 0.0))
	rotation.y = net_yaw


func _ready() -> void:
	add_to_group("crates")
	_ship = get_parent().get_parent().get_parent() as Mothership
	_build()
	_area = Area3D.new()
	_area.collision_layer = Game.LAYER_INTERACT
	_area.collision_mask = 0
	_area.monitoring = false
	_area.set_meta("crate", str(name))
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = SIZE + Vector3(0.3, 0.4, 0.3)
	cs.shape = box
	_area.add_child(cs)
	add_child(_area)


func _build() -> void:
	var col := RunItems.color(item)
	var shell := Models.panel_mat(Color(0.22, 0.24, 0.27), 0.5, 0.5, 1.2)
	var band := Models.emissive(col, 2.2, col * 0.3)
	Models.box(self, Vector3.ZERO, SIZE, shell)
	for x: float in [-0.3, 0.3]:
		Models.box(self, Vector3(x, 0, 0), Vector3(0.07, SIZE.y + 0.02, SIZE.z + 0.02), band)
	# Corner bumpers and a lid handle.
	var trim := Models.mat(Color(0.75, 0.76, 0.8), 0.7, 0.35)
	for x: float in [-0.44, 0.44]:
		Models.box(self, Vector3(x, 0, 0), Vector3(0.04, SIZE.y + 0.03, SIZE.z + 0.03), trim)
	Models.box(self, Vector3(0, SIZE.y * 0.5 + 0.03, 0), Vector3(0.36, 0.05, 0.06), trim)
	# Item symbol on the front and back.
	for z: float in [-1.0, 1.0]:
		var face := Vector3(0, 0, z * (SIZE.z * 0.5 + 0.006))
		if RunItems.is_weapon(item):
			Models.box(self, face, Vector3(0.34, 0.07, 0.01), band)
			Models.box(self, face + Vector3(0.1, -0.06, 0), Vector3(0.07, 0.12, 0.01), band)
		elif item == "hull_kit":
			Models.box(self, face, Vector3(0.26, 0.08, 0.01), band)
			Models.box(self, face, Vector3(0.08, 0.26, 0.01), band)
		elif item == "autocannon":
			Models.box(self, face + Vector3(0, -0.04, 0), Vector3(0.2, 0.12, 0.01), band)
			Models.box(self, face + Vector3(0.12, 0.04, 0), Vector3(0.22, 0.04, 0.01), band)
		else:
			Models.box(self, face, Vector3(0.18, 0.18, 0.01), band, Vector3(0, 0, 45))
	_label = Label3D.new()
	_label.text = RunItems.display_name(item)
	_label.font_size = 40
	_label.pixel_size = 0.004
	_label.outline_size = 8
	_label.modulate = col.lerp(Color.WHITE, 0.4)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position = Vector3(0, SIZE.y * 0.5 + 0.32, 0)
	_label.visibility_range_end = 9.0
	add_child(_label)


func _physics_process(_delta: float) -> void:
	if _ship == null:
		return
	if carrier != 0:
		var c := _ship.crew_root.get_node_or_null(str(carrier)) as CrewMember
		if c:
			if multiplayer.is_server():
				last_carrier_pos = c.net_pos
			var yaw := c.look_yaw
			if c == _local_player():
				# First person: hold it low in front of the camera.
				position = c.position + Basis(Vector3.UP, yaw) * Vector3(0, CrewMember.EYE - 0.82, -0.85)
			else:
				position = c.position + Basis(Vector3.UP, yaw) * Vector3(0, 1.0, -0.58)
			rotation = Vector3(0, yaw + PI / 2.0, 0)
	else:
		position = net_pos
		rotation = Vector3(0, net_yaw, 0)
	if carrier != _last_carrier:
		_last_carrier = carrier
		reset_physics_interpolation()
		_area.collision_layer = 0 if carrier != 0 else Game.LAYER_INTERACT
		_label.visible = carrier == 0


func _local_player() -> CrewMember:
	return Game.mission.local_player if Game.mission else null
