class_name ShipBuilder
extends RefCounted
## Builds the mothership's exterior hull and walkable interior, and defines its layout.
##
## Ship-local space: +Y up, -Z forward, the interior deck floor is at y = 0. The interior fits
## inside the lofted exterior hull, whose back faces are culled so windows look out into the cave.

## Hull cross-sections: [z, half_width, half_height, y_center].
const HULL_SECTIONS := [
	[-13.8, 0.9, 0.7, 1.3],
	[-11.6, 3.5, 2.2, 1.4],
	[-9.2, 4.4, 2.95, 1.4],
	[-7.4, 4.7, 3.05, 1.4],
	[-6.6, 7.3, 3.25, 1.4],
	[7.0, 7.4, 3.3, 1.4],
	[10.4, 6.6, 3.0, 1.4],
	[11.8, 5.0, 2.3, 1.4],
]

## Interior stations. "seat" is where the crew member sits, "yaw" the direction they face.
const STATIONS := {
	"pilot": {"seat": Vector3(0, 0, -8.5), "yaw": 0.0, "console": Vector3(0, 0, -9.55), "label": "PILOT"},
	"gun_l": {"seat": Vector3(-4.75, 0, -2.5), "yaw": PI / 2.0, "console": Vector3(-5.55, 0, -2.5), "label": "PORT GUN"},
	"gun_r": {"seat": Vector3(4.75, 0, -2.5), "yaw": -PI / 2.0, "console": Vector3(5.55, 0, -2.5), "label": "STARBOARD GUN"},
	"mining": {"seat": Vector3(-3.6, 0, -4.75), "yaw": 0.0, "console": Vector3(-3.6, 0, -5.55), "label": "MINING LASER"},
	"scout": {"seat": Vector3(4.75, 0, 3.0), "yaw": -PI / 2.0, "console": Vector3(5.55, 0, 3.0), "label": "SCOUT BAY"},
}

const STATION_NAMES := {
	"pilot": "Pilot Seat", "gun_l": "Port Gun", "gun_r": "Starboard Gun",
	"mining": "Mining Laser", "scout": "Scout Bay",
}

## Machine parts the crew repairs with the toolkit.
const REPAIR_PANELS := [
	{"system": "engine", "pos": Vector3(-3.6, 1.3, 9.94), "yaw": 0.0},
	{"system": "engine", "pos": Vector3(3.6, 1.3, 9.94), "yaw": 0.0},
	{"system": "weapons", "pos": Vector3(-5.94, 1.3, 2.0), "yaw": -PI / 2.0},
	{"system": "weapons", "pos": Vector3(-5.94, 1.3, 4.0), "yaw": -PI / 2.0},
]

const SPAWN_POINTS := [Vector3(0, 0.1, 2.2), Vector3(-1.2, 0.1, 1.2), Vector3(1.2, 0.1, 1.2), Vector3(0, 0.1, 3.6)]

## The big red emergency blast button, beside the pilot seat.
const EMERGENCY_BUTTON := Vector3(2.25, 0, -8.6)

## Roof hatches infiltrators cut through: where they latch on outside and drop in inside.
const HATCHES := [
	{"outside": Vector3(0, 4.75, -2.0), "inside": Vector3(0, 0, -2.0)},
	{"outside": Vector3(-4.2, 4.75, 3.0), "inside": Vector3(-4.2, 0, 3.0)},
	{"outside": Vector3(0, 4.75, 7.2), "inside": Vector3(0, 0, 6.6)},
]

## Points on the hull where small critters latch on and scratch: [position, outward normal].
const HULL_POINTS := [
	[Vector3(-3.2, 4.72, -4.5), Vector3.UP], [Vector3(3.2, 4.72, -4.5), Vector3.UP],
	[Vector3(-3.4, 4.72, 5.0), Vector3.UP], [Vector3(3.4, 4.72, 5.0), Vector3.UP],
	[Vector3(-7.42, 1.6, 1.5), Vector3.LEFT], [Vector3(7.42, 1.6, 1.5), Vector3.RIGHT],
	[Vector3(-7.32, 1.0, 7.5), Vector3.LEFT], [Vector3(7.32, 1.0, 7.5), Vector3.RIGHT],
	[Vector3(-3.0, -1.92, -3.0), Vector3.DOWN], [Vector3(3.0, -1.92, -3.0), Vector3.DOWN],
	[Vector3(-3.8, -1.92, 8.0), Vector3.DOWN], [Vector3(3.8, -1.92, 8.0), Vector3.DOWN],
	[Vector3(0, 3.95, -10.6), Vector3(0, 0.75, -0.66)], [Vector3(0, 3.42, 11.85), Vector3.BACK],
]

## Interior navigation graph for boarding aliens (ship-local).
const WAYPOINTS := {
	"cockpit": Vector3(0, 0, -8.0), "cock_door": Vector3(0, 0, -6.1), "front": Vector3(0, 0, -3.6),
	"gun_l": Vector3(-4.1, 0, -2.6), "gun_r": Vector3(4.1, 0, -2.6), "mining": Vector3(-3.2, 0, -4.4),
	"hall": Vector3(0, 0, 0.8), "hall2": Vector3(0, 0, 3.0), "weap_door": Vector3(-2.5, 0, 3.0),
	"weap": Vector3(-4.3, 0, 3.0), "scout_door": Vector3(2.5, 0, 3.0), "scout": Vector3(4.2, 0, 3.0),
	"eng_door": Vector3(0, 0, 5.0), "eng": Vector3(0, 0, 6.0), "eng_l": Vector3(-3.6, 0, 8.9),
	"eng_r": Vector3(3.6, 0, 8.9), "cargo": Vector3(0, 0, 9.5),
}
const WAYPOINT_LINKS := [
	["cockpit", "cock_door"], ["cock_door", "front"], ["front", "gun_l"], ["front", "gun_r"],
	["front", "mining"], ["front", "hall"], ["gun_l", "hall"], ["gun_r", "hall"], ["hall", "hall2"],
	["hall2", "weap_door"], ["weap_door", "weap"], ["hall2", "scout_door"], ["scout_door", "scout"],
	["hall2", "eng_door"], ["eng_door", "eng"], ["eng", "eng_l"], ["eng", "eng_r"], ["eng_l", "cargo"],
	["eng_r", "cargo"],
]

## How far (degrees from the mount's rest direction) the side guns can swing towards the bow:
## past straight ahead, so both can hit targets in front of the nose.
const GUN_FORWARD_REACH := 124.0
const TURRET_MOUNTS := {
	"gun_l": {"pos": Vector3(-8.8, 1.8, -5.2), "yaw": PI / 2.0},
	"gun_r": {"pos": Vector3(8.8, 1.8, -5.2), "yaw": -PI / 2.0},
	"mining": {"pos": Vector3(0, 1.45, -14.35), "yaw": 0.0},
}
const DOCK_POINT := Vector3(0, -3.15, 3.5)
## Cargo door at the stern: a short corridor through the hull to a ramp hinged at the hull's end.
const DOOR_HALF_W := 1.4
const DOOR_H := 3.0
const RAMP_HINGE := Vector3(0, 0, 11.8)
const RAMP_LENGTH := 3.2
const RAMP_WIDTH := 2.9
## Open ramp angle from vertical: it slopes 1 m down onto a waystation pier (asin(1 / 3.2) past 90°).
const RAMP_OPEN := 1.8886
## Crew inside this box (ship-local) are aboard; the cargo corridor counts, the ramp does not.
const ABOARD_MIN := Vector3(-6.4, -1.0, -11.0)
const ABOARD_MAX := Vector3(6.4, 4.0, 11.6)
## Landing legs (hinges under the belly) and their length when deployed.
const LEGS := [Vector3(-3.4, -1.7, -7.0), Vector3(3.4, -1.7, -7.0), Vector3(-4.6, -1.7, 8.6), Vector3(4.6, -1.7, 8.6)]
const LEG_LENGTH := 2.5
## Auto cannon hardpoints ("rot" tilts the mount away from the hull). The first EDGE_CANNONS sit
## on the hull's top edges and take the cannons bought at homebase; the rest (roof and under the
## nose) take the ones found at waystations.
const AUTOCANNON_MOUNTS := [
	{"pos": Vector3(-6.2, 4.17, -4.0), "rot": Vector3(0, 0, 0.42)},
	{"pos": Vector3(6.2, 4.17, -4.0), "rot": Vector3(0, 0, -0.42)},
	{"pos": Vector3(-6.2, 4.25, 6.2), "rot": Vector3(0, 0, 0.42)},
	{"pos": Vector3(6.2, 4.25, 6.2), "rot": Vector3(0, 0, -0.42)},
	{"pos": Vector3(0, 4.66, -5.4), "rot": Vector3.ZERO},
	{"pos": Vector3(2.4, 4.7, 4.4), "rot": Vector3.ZERO},
	{"pos": Vector3(0, -1.62, -8.4), "rot": Vector3(0, 0, PI)},
]
const EDGE_CANNONS := 4
## Barrel tip relative to an auto cannon's pitch node.
const AUTOCANNON_MUZZLE := Vector3(0, 0, -1.35)
## Console where crew fit upgrades from supply crates (engine room, port side).
const INSTALL_HUB := Vector3(-5.5, 0, 7.2)
const COLLECTOR := Vector3(0, -2.0, -2.0)
## Shield ellipsoid around the hull.
const SHIELD_CENTER := Vector3(0, 1.4, -0.6)
const SHIELD_RADII := Vector3(11.5, 6.8, 16.8)
const NAME := "PROSPECTOR"


# --- Exterior ----------------------------------------------------------------------------------

## Build the exterior hull and fittings under `root`. Returns handles to animated parts.
static func build_exterior(root: Node3D) -> Dictionary:
	var parts := {}
	var hull_mat := Models.panel_mat(Color(0.62, 0.64, 0.68), 0.25, 0.5, 0.25)
	var dark := Models.mat(Color(0.14, 0.15, 0.18), 0.6, 0.5)
	var mid := Models.mat(Color(0.32, 0.34, 0.38), 0.6, 0.45)
	var accent := Models.mat(Color(0.95, 0.5, 0.12), 0.3, 0.5)
	var hull := MeshInstance3D.new()
	hull.name = "Hull"
	hull.mesh = Models.loft(HULL_SECTIONS, 0.3, false)
	hull.material_override = hull_mat
	root.add_child(hull)
	_rear_cap(root, hull_mat)

	# Accent stripes and panel bands.
	for side: float in [-1.0, 1.0]:
		Models.box(root, Vector3(side * 7.42, 3.15, 0.5), Vector3(0.08, 0.32, 12.0), accent)
		Models.box(root, Vector3(side * 7.42, 0.2, 0.5), Vector3(0.08, 0.14, 12.0), dark)
		var lbl := Label3D.new()
		lbl.text = NAME
		lbl.font_size = 140
		lbl.pixel_size = 0.008
		lbl.modulate = Color(0.15, 0.17, 0.2)
		lbl.outline_size = 0
		lbl.position = Vector3(side * 7.43, 1.9, 4.5)
		lbl.rotation = Vector3(0, side * PI / 2.0, 0)
		root.add_child(lbl)
	for z: float in [-4.0, 0.0, 4.0]:
		Models.box(root, Vector3(0, 4.71, z), Vector3(10.0, 0.04, 0.12), dark)
		Models.box(root, Vector3(0, -1.91, z), Vector3(10.0, 0.04, 0.12), dark)

	# Cockpit canopy on top of the nose.
	var canopy := Models.box(root, Vector3(0, 4.22, -9.8), Vector3(4.0, 0.12, 3.4),
			Models.emissive(Color(0.25, 0.6, 0.8), 0.6, Color(0.05, 0.08, 0.1)), Vector3(-17, 0, 0))
	canopy.name = "Canopy"
	# Thin frames around the gunnery windows (no glass, so the crew can see out).
	for side: float in [-1.0, 1.0]:
		for dz: float in [-1.55, 1.55]:
			Models.box(root, Vector3(side * 7.42, 1.8, -2.5 + dz), Vector3(0.06, 1.6, 0.1), dark)
		for dy: float in [-0.75, 0.75]:
			Models.box(root, Vector3(side * 7.42, 1.8 + dy, -2.5), Vector3(0.06, 0.1, 3.2), dark)

	# Engine housings either side of the cargo door, and two nacelles.
	for side: float in [-1.0, 1.0]:
		Models.box(root, Vector3(side * 2.2, 1.3, 12.3), Vector3(1.4, 3.0, 1.6), mid)
	Models.box(root, Vector3(0, DOOR_H + 0.32, RAMP_HINGE.z + 0.06), Vector3(DOOR_HALF_W * 2.0 + 0.3, 0.16, 0.12), accent)
	for side: float in [-1.0, 1.0]:
		Models.sphere(root, Vector3(side * (DOOR_HALF_W - 0.15), DOOR_H + 0.5, RAMP_HINGE.z + 0.05), 0.07, Models.emissive(Color(1.0, 0.6, 0.15), 4.0))
	var glows: Array[MeshInstance3D] = []
	var glow_mat := StandardMaterial3D.new()
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_mat.albedo_color = Color(0.45, 0.8, 1.0)
	for side: float in [-1.0, 1.0]:
		Models.cylinder(root, Vector3(side * 4.5, 1.1, 12.5), 1.55, 3.6, mid, Vector3(90, 0, 0), 1.35, 20)
		Models.cylinder(root, Vector3(side * 4.5, 1.1, 14.25), 1.25, 0.25, dark, Vector3(90, 0, 0), 1.25, 20)
		var g := Models.cylinder(root, Vector3(side * 4.5, 1.1, 14.4), 0.8, 0.08, glow_mat, Vector3(90, 0, 0), 0.8, 20)
		glows.append(g)
		Models.box(root, Vector3(side * 6.0, 1.1, 11.0), Vector3(0.6, 0.5, 2.0), dark)
	parts["engine_glows"] = glows
	parts["engine_glow_mat"] = glow_mat

	# Turret sponsons, turrets and the mining laser.
	# Sponsons sit behind the turrets so the barrels can swing forward past the bow.
	for id: String in ["gun_l", "gun_r"]:
		var m: Dictionary = TURRET_MOUNTS[id]
		var p: Vector3 = m["pos"]
		Models.box(root, Vector3(signf(p.x) * 7.85, p.y, p.z + 0.8), Vector3(1.5, 1.9, 2.4), mid)
		Models.box(root, Vector3(signf(p.x) * 7.85, p.y + 0.96, p.z + 0.8), Vector3(1.3, 0.04, 2.0), accent)
	Models.box(root, Vector3(0, 1.45, -13.9), Vector3(1.1, 0.9, 0.5), mid)
	for id in TURRET_MOUNTS:
		var m: Dictionary = TURRET_MOUNTS[id]
		var t := Turret.new()
		t.name = "Turret_" + id
		t.position = m["pos"]
		t.rotation = Vector3(0, m["yaw"], 0)
		root.add_child(t)
		t.build(id == "mining")
		if id != "mining":
			t.reach_forward(GUN_FORWARD_REACH)
		parts[id] = t

	# Scout dock clamps under the belly.
	Models.box(root, Vector3(0, -1.98, DOCK_POINT.z), Vector3(3.8, 0.12, 5.8), dark)
	for x: float in [-1.5, 1.5]:
		Models.box(root, Vector3(x, -2.25, DOCK_POINT.z), Vector3(0.25, 0.6, 3.2), mid)
	Models.box(root, Vector3(0, -2.0, DOCK_POINT.z - 3.1), Vector3(3.0, 0.08, 0.3), accent)

	# Roof hatches.
	for h in HATCHES:
		var hp: Vector3 = h["outside"]
		Models.box(root, Vector3(hp.x, 4.72, hp.z), Vector3(1.6, 0.06, 1.6), dark)
		Models.box(root, Vector3(hp.x, 4.74, hp.z), Vector3(1.2, 0.04, 0.12), accent)

	# Antennas and greebles.
	Models.cylinder(root, Vector3(-2.5, 5.6, 9.0), 0.05, 1.8, mid)
	Models.cylinder(root, Vector3(-2.2, 5.3, 9.5), 0.04, 1.2, mid)
	Models.sphere(root, Vector3(-2.5, 6.5, 9.0), 0.12, Models.emissive(Color(1, 0.2, 0.2), 4.0))
	Models.box(root, Vector3(3.0, 4.95, 8.0), Vector3(1.6, 0.5, 2.2), mid)
	Models.box(root, Vector3(-3.5, 4.9, -1.0), Vector3(1.2, 0.4, 1.4), mid)
	Models.box(root, Vector3(4.5, 4.85, -4.5), Vector3(0.8, 0.3, 2.4), dark)

	# Navigation lights.
	Models.sphere(root, Vector3(-7.45, 3.6, -6.4), 0.14, Models.emissive(Color(1, 0.15, 0.1), 5.0))
	Models.sphere(root, Vector3(7.45, 3.6, -6.4), 0.14, Models.emissive(Color(0.2, 1, 0.3), 5.0))

	# Headlight in a housing under the nose, clear of the nose-mounted mining laser so the turret
	# doesn't throw a giant shadow down the tunnel.
	var lamp_mat := Models.emissive(Color(1.0, 0.95, 0.85), 6.0)
	var lights: Array[Light3D] = []
	Models.box(root, Vector3(0, -0.05, -12.7), Vector3(1.8, 0.4, 1.0), mid)
	for x: float in [-0.45, 0.45]:
		Models.cylinder(root, Vector3(x, -0.08, -13.22), 0.16, 0.05, lamp_mat, Vector3(90, 0, 0))
	var head := SpotLight3D.new()
	head.position = Vector3(0, -0.1, -13.35)
	head.rotation_degrees = Vector3(-4, 0, 0)
	head.spot_range = 95.0
	head.spot_angle = 34.0
	head.spot_attenuation = 0.6
	head.light_energy = 7.0
	head.light_color = Color(1.0, 0.95, 0.86)
	configure_shadow(head)
	root.add_child(head)
	lights.append(head)
	for side: float in [-1.0, 1.0]:
		var flood := SpotLight3D.new()
		flood.position = Vector3(side * 6.8, 3.8, -7.0)
		flood.rotation_degrees = Vector3(-14, side * -24.0, 0)
		flood.spot_range = 70.0
		flood.spot_angle = 48.0
		flood.light_energy = 3.0
		flood.light_color = Color(0.85, 0.92, 1.0)
		root.add_child(flood)
		lights.append(flood)
	var belly := OmniLight3D.new()
	belly.position = Vector3(0, -3.0, -1.0)
	belly.omni_range = 34.0
	belly.light_energy = 0.9
	belly.light_color = Color(0.8, 0.88, 1.0)
	root.add_child(belly)
	lights.append(belly)
	# Work lights above the hull so the ship reads clearly from the chase and scout cameras.
	for z: float in [-6.0, 7.0]:
		var top := OmniLight3D.new()
		top.position = Vector3(0, 9.0, z)
		top.omni_range = 18.0
		top.light_energy = 0.7
		top.light_color = Color(1.0, 0.95, 0.88)
		root.add_child(top)
		lights.append(top)
	# Beacon marking the scout dock.
	Models.sphere(root, Vector3(0, -2.05, DOCK_POINT.z + 3.3), 0.12, Models.emissive(Color(0.3, 1.0, 0.5), 5.0))
	parts["lights"] = lights

	# Landing legs, folded flat against the belly in flight.
	var legs: Array = []
	for lp: Vector3 in LEGS:
		var pivot := Node3D.new()
		pivot.position = lp
		root.add_child(pivot)
		Models.box(pivot, Vector3(0, 0.08, 0), Vector3(0.75, 0.32, 0.75), dark)
		Models.cylinder(pivot, Vector3(0, -0.75, 0), 0.24, 1.5, mid)
		Models.cylinder(pivot, Vector3(0, -1.85, 0), 0.16, 1.1, dark)
		Models.cylinder(pivot, Vector3(0, -LEG_LENGTH + 0.08, 0), 0.55, 0.16, dark, Vector3.ZERO, 0.42)
		Models.strut(pivot, Vector3(0, -0.1, 0.45 * signf(-lp.z)), Vector3(0, -1.1, 0.0), 0.06, accent)
		legs.append({"node": pivot, "fold": 1.0 if lp.z < 0.0 else -1.0})
	parts["legs"] = legs

	# Auto cannon turrets, hidden until bought or installed.
	var guns: Array = []
	for m: Dictionary in AUTOCANNON_MOUNTS:
		var base := Node3D.new()
		base.position = m["pos"]
		base.rotation = m["rot"]
		root.add_child(base)
		Models.cylinder(base, Vector3(0, 0.12, 0), 0.55, 0.24, dark, Vector3.ZERO, 0.45)
		var swivel := Node3D.new()
		swivel.position = Vector3(0, 0.5, 0)
		base.add_child(swivel)
		Models.box(swivel, Vector3(0, 0, 0.1), Vector3(0.78, 0.44, 0.85), mid)
		Models.box(swivel, Vector3(0, 0.23, 0.1), Vector3(0.5, 0.05, 0.55), accent)
		var pitch := Node3D.new()
		swivel.add_child(pitch)
		for dx: float in [-0.17, 0.17]:
			Models.cylinder(pitch, Vector3(dx, 0, -0.78), 0.075, 1.15, dark, Vector3(90, 0, 0))
		base.visible = false
		guns.append({"root": base, "head": swivel, "pitch": pitch})
	parts["autocannons"] = guns
	return parts


## Rear end cap of the hull with the cargo door cut out of it.
static func _rear_cap(root: Node3D, material: Material) -> void:
	var ring := Models.octagon(HULL_SECTIONS[HULL_SECTIONS.size() - 1], 0.3)
	var z := ring[0].z
	var outline := PackedVector2Array()
	for p in ring:
		outline.append(Vector2(p.x, p.y))
	var hw := DOOR_HALF_W
	var y0 := -0.05
	var y1 := DOOR_H + 0.15
	var big := 50.0
	var pieces := [
		PackedVector2Array([Vector2(-big, -big), Vector2(-hw, -big), Vector2(-hw, big), Vector2(-big, big)]),
		PackedVector2Array([Vector2(hw, -big), Vector2(big, -big), Vector2(big, big), Vector2(hw, big)]),
		PackedVector2Array([Vector2(-hw, y1), Vector2(hw, y1), Vector2(hw, big), Vector2(-hw, big)]),
		PackedVector2Array([Vector2(-hw, -big), Vector2(hw, -big), Vector2(hw, y0), Vector2(-hw, y0)]),
	]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var inside := Vector3(0, 1.4, z - 1.0)
	for clip: PackedVector2Array in pieces:
		for poly: PackedVector2Array in Geometry2D.intersect_polygons(outline, clip):
			for i in range(1, poly.size() - 1):
				Models.tri(st, Vector3(poly[0].x, poly[0].y, z), Vector3(poly[i].x, poly[i].y, z),
						Vector3(poly[i + 1].x, poly[i + 1].y, z), inside)
	var mi := MeshInstance3D.new()
	mi.name = "RearCap"
	mi.mesh = st.commit()
	mi.material_override = material
	root.add_child(mi)


## Shadow settings for the long-range spot lights that light the cave. The cave and every model
## are closed meshes, so rendering back faces into the shadow map (reverse cull) removes
## self-shadowing acne on lit surfaces; the biases mop up the stair-stepped rock.
static func configure_shadow(light: Light3D) -> void:
	light.shadow_enabled = true
	light.shadow_reverse_cull_face = true
	light.shadow_bias = 0.12
	light.shadow_normal_bias = 2.0
	light.shadow_blur = 1.5


# --- Interior ----------------------------------------------------------------------------------

## Build the walkable interior under `root`: collision, visuals, consoles, lights and the
## interaction areas for stations and repair panels.
static func build_interior(root: Node3D) -> Dictionary:
	var parts := {}
	var body := StaticBody3D.new()
	body.name = "InteriorBody"
	body.collision_layer = Game.LAYER_INTERIOR
	body.collision_mask = 0
	root.add_child(body)
	parts["body"] = body

	var floor_mat := Models.panel_mat(Color(0.26, 0.28, 0.31), 0.5, 0.6, 0.6)
	var wall_mat := Models.panel_mat(Color(0.66, 0.68, 0.7), 0.25, 0.55, 0.45)
	var ceil_mat := Models.panel_mat(Color(0.3, 0.32, 0.35), 0.3, 0.6, 0.5)
	var trim := Models.mat(Color(0.95, 0.6, 0.15), 0.3, 0.5)
	var dark := Models.mat(Color(0.12, 0.13, 0.15), 0.5, 0.5)
	var glass := Models.glass(Color(0.55, 0.75, 0.95, 0.12))

	# Floors and ceilings.
	_solid(root, body, Vector3(0, -0.15, 2.0), Vector3(12.5, 0.3, 16.5), floor_mat)
	_solid(root, body, Vector3(0, -0.15, -8.25), Vector3(6.5, 0.3, 4.0), floor_mat)
	_solid(root, body, Vector3(0, 3.35, 2.0), Vector3(12.5, 0.3, 16.5), ceil_mat)
	_solid(root, body, Vector3(0, 3.35, -8.25), Vector3(6.5, 0.3, 4.0), ceil_mat)

	# Outer walls with gunnery windows.
	for side: float in [-1.0, 1.0]:
		var x := side * 6.125
		_solid(root, body, Vector3(x, 1.6, -5.125), Vector3(0.25, 3.2, 2.25), wall_mat)
		_solid(root, body, Vector3(x, 1.6, 4.625), Vector3(0.25, 3.2, 11.25), wall_mat)
		_solid(root, body, Vector3(x, 0.55, -2.5), Vector3(0.25, 1.1, 3.0), wall_mat)
		_solid(root, body, Vector3(x, 2.85, -2.5), Vector3(0.25, 0.7, 3.0), wall_mat)
		_solid(root, body, Vector3(x, 1.8, -2.5), Vector3(0.06, 1.4, 3.0), glass)
		Models.box(root, Vector3(x - side * 0.14, 1.1, -2.5), Vector3(0.05, 0.08, 3.1), trim)
		# Cockpit side walls.
		_solid(root, body, Vector3(side * 3.125, 1.6, -8.25), Vector3(0.25, 3.2, 4.0), wall_mat)
		# Front bulkhead either side of the cockpit door.
		_solid(root, body, Vector3(side * 3.675, 1.6, -6.125), Vector3(5.15, 3.2, 0.25), wall_mat)
		# Cockpit window frame.
		_solid(root, body, Vector3(side * 2.75, 1.6, -10.125), Vector3(0.5, 3.2, 0.25), wall_mat)
		# Engine bulkhead.
		_solid(root, body, Vector3(side * 3.55, 1.6, 5.0), Vector3(4.9, 3.2, 0.25), wall_mat)
		# Side rooms (weapons on port, scout bay on starboard).
		_solid(root, body, Vector3(side * 4.1875, 1.6, 1.0), Vector3(3.625, 3.2, 0.25), wall_mat)
		_solid(root, body, Vector3(side * 2.5, 1.6, 1.7125), Vector3(0.25, 3.2, 1.175), wall_mat)
		_solid(root, body, Vector3(side * 2.5, 1.6, 4.2875), Vector3(0.25, 3.2, 1.175), wall_mat)
		_solid(root, body, Vector3(side * 2.5, 2.8, 3.0), Vector3(0.25, 0.8, 1.4), wall_mat)
		Models.box(root, Vector3(side * 2.5, 2.38, 3.0), Vector3(0.3, 0.06, 1.4), trim)
	# Rear wall with the cargo door, and the corridor through the hull to the ramp.
	var corridor_z := (10.25 + RAMP_HINGE.z) * 0.5
	var corridor_len := RAMP_HINGE.z - 10.25
	for side: float in [-1.0, 1.0]:
		_solid(root, body, Vector3(side * (DOOR_HALF_W + (6.25 - DOOR_HALF_W) * 0.5), 1.6, 10.125), Vector3(6.25 - DOOR_HALF_W, 3.2, 0.25), wall_mat)
		_solid(root, body, Vector3(side * (DOOR_HALF_W + 0.1), 1.6, corridor_z), Vector3(0.2, 3.2, corridor_len), wall_mat)
		Models.box(root, Vector3(side * (DOOR_HALF_W + 0.02), 1.5, 9.99), Vector3(0.08, 3.0, 0.04), trim)
	_solid(root, body, Vector3(0, (DOOR_H + 3.2) * 0.5, 10.125), Vector3(DOOR_HALF_W * 2.0, 3.2 - DOOR_H, 0.25), wall_mat)
	_solid(root, body, Vector3(0, -0.15, corridor_z), Vector3(DOOR_HALF_W * 2.0 + 0.4, 0.3, corridor_len), floor_mat)
	_solid(root, body, Vector3(0, 3.35, corridor_z), Vector3(DOOR_HALF_W * 2.0 + 0.4, 0.3, corridor_len), ceil_mat)
	Models.box(root, Vector3(0, DOOR_H + 0.1, 9.99), Vector3(DOOR_HALF_W * 2.0, 0.08, 0.04), trim)
	var door_label := Label3D.new()
	door_label.text = "CARGO RAMP"
	door_label.font_size = 36
	door_label.pixel_size = 0.0045
	door_label.outline_size = 8
	door_label.modulate = Color(1.0, 0.7, 0.3)
	door_label.position = Vector3(0, DOOR_H + 0.1, 9.96)
	door_label.rotation.y = PI
	root.add_child(door_label)
	var ramp := Node3D.new()
	ramp.name = "Ramp"
	ramp.position = RAMP_HINGE
	root.add_child(ramp)
	var ramp_body := StaticBody3D.new()
	ramp_body.collision_layer = Game.LAYER_INTERIOR
	ramp_body.collision_mask = 0
	ramp.add_child(ramp_body)
	_solid(ramp, ramp_body, Vector3(0, RAMP_LENGTH * 0.5, 0.075), Vector3(RAMP_WIDTH, RAMP_LENGTH, 0.15),
			Models.panel_mat(Color(0.55, 0.57, 0.6), 0.35, 0.5, 0.45))
	for i in 6:
		Models.box(ramp, Vector3(0, 0.3 + i * 0.5, -0.006), Vector3(RAMP_WIDTH - 0.4, 0.12, 0.012), trim)
	for side: float in [-1.0, 1.0]:
		Models.sphere(ramp, Vector3(side * (RAMP_WIDTH * 0.5 - 0.15), RAMP_LENGTH - 0.12, -0.03), 0.06, Models.emissive(Color(1.0, 0.6, 0.15), 4.0))
	var ramp_light := OmniLight3D.new()
	ramp_light.position = Vector3(0, 2.7, 11.0)
	ramp_light.omni_range = 5.0
	ramp_light.light_energy = 0.0
	ramp_light.light_color = Color(1.0, 0.55, 0.15)
	root.add_child(ramp_light)
	parts["ramp"] = ramp
	parts["ramp_body"] = ramp_body
	parts["ramp_light"] = ramp_light
	_solid(root, body, Vector3(0, 2.8, -6.125), Vector3(2.2, 0.8, 0.25), wall_mat)
	_solid(root, body, Vector3(0, 2.8, 5.0), Vector3(2.2, 0.8, 0.25), wall_mat)
	_solid(root, body, Vector3(0, 0.45, -10.125), Vector3(5.0, 0.9, 0.25), wall_mat)
	_solid(root, body, Vector3(0, 3.0, -10.125), Vector3(5.0, 0.4, 0.25), wall_mat)
	_solid(root, body, Vector3(0, 1.85, -10.125), Vector3(5.0, 1.9, 0.06), glass)
	Models.box(root, Vector3(0, 2.38, -6.125), Vector3(2.2, 0.06, 0.3), trim)
	Models.box(root, Vector3(0, 2.38, 5.0), Vector3(2.2, 0.06, 0.3), trim)

	# Ceiling light strips.
	var strip := Models.emissive(Color(1.0, 0.95, 0.85), 2.5)
	for z: float in [-8.2, -3.5, 0.5, 3.0, 7.5]:
		Models.box(root, Vector3(0, 3.18, z), Vector3(1.6, 0.04, 0.3), strip)

	# Engine core.
	var core_mat := StandardMaterial3D.new()
	core_mat.albedo_color = Color(0.1, 0.25, 0.3)
	core_mat.emission_enabled = true
	core_mat.emission = Color(0.3, 0.85, 1.0)
	core_mat.emission_energy_multiplier = 2.5
	Models.cylinder(root, Vector3(0, 1.6, 7.8), 0.75, 3.2, core_mat, Vector3.ZERO, -1.0, 20)
	Models.cylinder(root, Vector3(0, 0.25, 7.8), 1.1, 0.5, dark, Vector3.ZERO, -1.0, 20)
	Models.cylinder(root, Vector3(0, 2.95, 7.8), 1.1, 0.5, dark, Vector3.ZERO, -1.0, 20)
	for a in 4:
		var ang := a * PI / 2.0 + PI / 4.0
		Models.box(root, Vector3(cos(ang) * 0.95, 1.6, 7.8 + sin(ang) * 0.95), Vector3(0.15, 2.4, 0.15), dark)
	var core_shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 1.1
	cyl.height = 3.2
	core_shape.shape = cyl
	core_shape.position = Vector3(0, 1.6, 7.8)
	body.add_child(core_shape)
	parts["core_mat"] = core_mat

	# Station consoles and seats.
	var console_sizes := {
		"pilot": Vector3(3.4, 0.9, 0.8), "gun_l": Vector3(0.8, 1.0, 1.8), "gun_r": Vector3(0.8, 1.0, 1.8),
		"mining": Vector3(1.8, 1.0, 0.8), "scout": Vector3(0.8, 1.0, 1.6),
	}
	var screen_cols := {
		"pilot": Color(0.3, 0.9, 1.0), "gun_l": Color(1.0, 0.45, 0.3), "gun_r": Color(1.0, 0.45, 0.3),
		"mining": Color(1.0, 0.75, 0.25), "scout": Color(0.45, 1.0, 0.5),
	}
	var areas := {}
	for id in STATIONS:
		var st: Dictionary = STATIONS[id]
		var c: Vector3 = st["console"]
		var size: Vector3 = console_sizes[id]
		_solid(root, body, Vector3(c.x, size.y * 0.5, c.z), size, dark)
		var yaw: float = st["yaw"]
		var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
		var screen := Models.box(root, Vector3(c.x, size.y + 0.22, c.z) - fwd * 0.05,
				Vector3(minf(maxf(size.x, size.z) * 0.6, 1.6), 0.4, 0.04), Models.emissive(screen_cols[id], 0.9, Color(0.02, 0.03, 0.04)))
		screen.rotation = Vector3(-0.35, yaw, 0)
		var seat: Vector3 = st["seat"]
		Models.cylinder(root, seat + Vector3(0, 0.22, 0), 0.08, 0.44, dark)
		var seat_root := Node3D.new()
		seat_root.position = seat
		seat_root.rotation.y = yaw
		root.add_child(seat_root)
		Models.box(seat_root, Vector3(0, 0.48, 0.05), Vector3(0.6, 0.1, 0.55), Models.mat(Color(0.2, 0.22, 0.25), 0.2, 0.7))
		Models.box(seat_root, Vector3(0, 0.85, 0.32), Vector3(0.6, 0.7, 0.1), Models.mat(Color(0.2, 0.22, 0.25), 0.2, 0.7))
		var label := Label3D.new()
		label.text = st["label"]
		label.font_size = 42
		label.pixel_size = 0.0045
		label.outline_size = 8
		label.modulate = screen_cols[id]
		label.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		label.position = Vector3(c.x, 2.35, c.z)
		root.add_child(label)
		areas[id] = _interact_area(root, Vector3(c.x, 0.9, c.z), Vector3(1.8, 1.8, 1.8), "station", id)
	parts["station_areas"] = areas

	# Emergency blast button on a pedestal beside the pilot seat.
	var eb := EMERGENCY_BUTTON
	_solid(root, body, Vector3(eb.x, 0.5, eb.z), Vector3(0.45, 1.0, 0.45), dark)
	Models.box(root, Vector3(eb.x, 0.5, eb.z), Vector3(0.47, 0.12, 0.47), Models.mat(Color(0.95, 0.8, 0.1), 0.3, 0.5))
	Models.cylinder(root, Vector3(eb.x, 1.015, eb.z), 0.2, 0.03, Models.mat(Color(0.95, 0.8, 0.1), 0.3, 0.5), Vector3.ZERO, -1.0, 20)
	var blast_mat := StandardMaterial3D.new()
	blast_mat.albedo_color = Color(0.45, 0.02, 0.02)
	blast_mat.emission_enabled = true
	blast_mat.emission = Color(1.0, 0.12, 0.05)
	blast_mat.emission_energy_multiplier = 2.0
	Models.cylinder(root, Vector3(eb.x, 1.07, eb.z), 0.13, 0.09, blast_mat, Vector3.ZERO, 0.11, 16)
	var blabel := Label3D.new()
	blabel.text = "EMERGENCY\nBLAST"
	blabel.font_size = 30
	blabel.pixel_size = 0.0032
	blabel.outline_size = 8
	blabel.modulate = Color(1.0, 0.35, 0.25)
	blabel.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	blabel.position = Vector3(eb.x, 1.5, eb.z)
	root.add_child(blabel)
	_interact_area(root, Vector3(eb.x, 0.9, eb.z), Vector3(0.9, 1.4, 0.9), "emergency", true)
	parts["blast_mat"] = blast_mat

	# Install hub for supply-crate upgrades, against the port wall of the engine room.
	var hub := INSTALL_HUB
	_solid(root, body, Vector3(hub.x, 0.55, hub.z), Vector3(0.9, 1.1, 1.8), dark)
	Models.box(root, Vector3(hub.x + 0.46, 0.6, hub.z), Vector3(0.04, 0.6, 1.4), Models.emissive(Color(0.35, 1.0, 0.6), 1.2, Color(0.02, 0.04, 0.03)))
	Models.box(root, Vector3(hub.x + 0.05, 1.13, hub.z), Vector3(0.7, 0.05, 1.3), Models.emissive(Color(1.0, 0.72, 0.25), 1.6))
	Models.box(root, Vector3(hub.x - 0.27, 1.9, hub.z), Vector3(0.05, 1.0, 1.7), Models.emissive(Color(0.15, 0.45, 0.35), 0.7, Color(0.02, 0.03, 0.03)))
	var hub_label := Label3D.new()
	hub_label.text = "INSTALLED\n(none)"
	hub_label.font_size = 30
	hub_label.pixel_size = 0.0034
	hub_label.outline_size = 6
	hub_label.modulate = Color(0.75, 1.0, 0.85)
	hub_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	hub_label.position = Vector3(hub.x - 0.23, 2.32, hub.z)
	hub_label.rotation.y = PI / 2.0
	root.add_child(hub_label)
	var hub_title := Label3D.new()
	hub_title.text = "INSTALL HUB"
	hub_title.font_size = 42
	hub_title.pixel_size = 0.0045
	hub_title.outline_size = 8
	hub_title.modulate = Color(0.45, 1.0, 0.6)
	hub_title.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	hub_title.position = Vector3(hub.x + 0.2, 2.62, hub.z)
	root.add_child(hub_title)
	_interact_area(root, Vector3(hub.x + 0.8, 0.9, hub.z), Vector3(1.3, 1.8, 2.0), "install_hub", true)
	parts["hub_label"] = hub_label

	# Scout launch hatch marking.
	Models.box(root, Vector3(4.0, 0.01, 3.0), Vector3(1.6, 0.02, 1.6), Models.mat(Color(0.9, 0.75, 0.1), 0.2, 0.6))
	Models.box(root, Vector3(4.0, 0.02, 3.0), Vector3(1.3, 0.02, 1.3), dark)

	# Repair panels.
	var panels: Array = []
	for p in REPAIR_PANELS:
		var pos: Vector3 = p["pos"]
		var yaw: float = p["yaw"]
		var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
		var panel_root := Node3D.new()
		panel_root.position = pos
		panel_root.rotation.y = yaw
		root.add_child(panel_root)
		Models.box(panel_root, Vector3.ZERO, Vector3(1.3, 1.3, 0.14), Models.mat(Color(0.2, 0.22, 0.26), 0.5, 0.5))
		Models.box(panel_root, Vector3(0, 0.25, -0.08), Vector3(1.0, 0.5, 0.04), Models.emissive(Color(0.3, 0.6, 0.9), 1.2))
		var status_mat := StandardMaterial3D.new()
		status_mat.albedo_color = Color(0.05, 0.05, 0.05)
		status_mat.emission_enabled = true
		status_mat.emission = Color(0.3, 1.0, 0.4)
		status_mat.emission_energy_multiplier = 3.0
		Models.box(panel_root, Vector3(0, -0.3, -0.08), Vector3(0.9, 0.18, 0.04), status_mat)
		for i in 3:
			Models.cylinder(panel_root, Vector3(-0.35 + i * 0.35, -0.55, -0.06), 0.06, 0.08, Models.mat(Color(0.7, 0.7, 0.72), 0.7, 0.3), Vector3(90, 0, 0))
		var plabel := Label3D.new()
		plabel.text = "ENGINE" if p["system"] == "engine" else "WEAPON SYSTEMS"
		plabel.font_size = 36
		plabel.pixel_size = 0.006
		plabel.outline_size = 8
		plabel.position = Vector3(0, 0.95, -0.05)
		plabel.rotation.y = PI
		panel_root.add_child(plabel)
		var area := _interact_area(root, pos + fwd * 0.45 - Vector3(0, 0.2, 0), Vector3(1.5, 1.8, 0.9), "repair", p["system"])
		area.rotation.y = yaw
		panels.append({"system": p["system"], "node": panel_root, "status_mat": status_mat, "area": area})
	parts["panels"] = panels

	# Crates and pipes for clutter.
	var crate := Models.panel_mat(Color(0.35, 0.4, 0.3), 0.2, 0.7, 1.0)
	_solid(root, body, Vector3(-5.4, 0.4, 9.3), Vector3(0.8, 0.8, 0.8), crate)
	_solid(root, body, Vector3(5.4, 0.4, 9.3), Vector3(0.8, 0.8, 0.8), crate)
	_solid(root, body, Vector3(-5.5, 0.35, -0.2), Vector3(0.7, 0.7, 0.7), crate)
	_solid(root, body, Vector3(5.5, 0.35, 1.6), Vector3(0.7, 0.7, 0.7), crate)
	var pipe := Models.mat(Color(0.5, 0.45, 0.4), 0.7, 0.4)
	for side: float in [-1.0, 1.0]:
		Models.cylinder(root, Vector3(side * 5.85, 2.95, 4.6), 0.08, 10.5, pipe, Vector3(90, 0, 0))
		Models.cylinder(root, Vector3(side * 5.7, 2.95, 4.6), 0.06, 10.5, Models.mat(Color(0.7, 0.2, 0.15), 0.5, 0.5), Vector3(90, 0, 0))

	# Lighting: normal lights plus red alarm lights.
	var lights: Array[OmniLight3D] = []
	var alarms: Array[OmniLight3D] = []
	for lp: Vector3 in [Vector3(0, 2.8, -8.2), Vector3(-3.2, 2.8, -3.0), Vector3(3.2, 2.8, -3.0), Vector3(0, 2.8, 2.0),
			Vector3(-4.3, 2.8, 3.0), Vector3(4.3, 2.8, 3.0), Vector3(-3.0, 2.8, 7.6), Vector3(3.0, 2.8, 7.6)]:
		var l := OmniLight3D.new()
		l.position = lp
		l.omni_range = 7.5
		l.light_energy = 1.1
		l.light_color = Color(1.0, 0.93, 0.84)
		root.add_child(l)
		lights.append(l)
	for ap: Vector3 in [Vector3(0, 3.0, -4.0), Vector3(0, 3.0, 2.8), Vector3(0, 3.0, 8.5), Vector3(0, 3.0, -8.5)]:
		var a := OmniLight3D.new()
		a.position = ap
		a.omni_range = 9.0
		a.light_energy = 0.0
		a.light_color = Color(1.0, 0.1, 0.05)
		root.add_child(a)
		alarms.append(a)
	parts["lights"] = lights
	parts["alarms"] = alarms
	return parts


static func _solid(root: Node3D, body: StaticBody3D, pos: Vector3, size: Vector3, material: Material) -> void:
	Models.box(root, pos, size, material)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.position = pos
	body.add_child(cs)


static func _interact_area(root: Node3D, pos: Vector3, size: Vector3, key: String, value: Variant) -> Area3D:
	var a := Area3D.new()
	a.collision_layer = Game.LAYER_INTERACT
	a.collision_mask = 0
	a.monitoring = false
	a.position = pos
	a.set_meta(key, value)
	var cs := CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = size
	cs.shape = sh
	a.add_child(cs)
	root.add_child(a)
	return a


## AStar graph over the interior waypoints (ids follow WAYPOINTS order).
static func build_nav() -> AStar3D:
	var astar := AStar3D.new()
	var ids := {}
	var i := 0
	for k in WAYPOINTS:
		astar.add_point(i, WAYPOINTS[k])
		ids[k] = i
		i += 1
	for link in WAYPOINT_LINKS:
		astar.connect_points(ids[link[0]], ids[link[1]])
	return astar
