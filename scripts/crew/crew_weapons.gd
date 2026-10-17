class_name CrewWeapons
extends RefCounted
## Hand weapons for the crew. Everyone starts a dive with the Blaster; the others turn up in
## abandoned stations and in waystation shops, packed in supply crates like everything else. Look
## at a crate holding one and press F to swap: your current weapon goes into that crate. Every
## weapon fires from a magazine; once it is empty, press R to reload (crew bots reload by
## themselves).
##
## Damage scales with the ship's "blaster_damage" stat relative to BASE_DAMAGE, so Blaster
## Overcharge from a shop boosts every crew weapon. Hits are detected by the shooter and sent to
## the server (like the original blaster); the Plasma Launcher's orb flies in ship-local space so
## it keeps up with a moving ship, and asks the server for splash damage where it bursts.

const BASE_DAMAGE := 20.0
const DEFAULT := "blaster"
const ORDER := ["blaster", "rifle", "scatter", "rail", "plasma"]
## "damage" per pellet, "cooldown" seconds between shots (all of them fire while LMB is held),
## "spread" the random cone every shot scatters into (radians: tiny for the long-range weapons, wide
## for the Scattergun, which makes up for it with its rate of fire up close), "pierce" how many
## enemies a rail slug passes through, "splash" radius and orb "speed" for the launcher, "price" in
## waystation shops (before the depth markup), "mag" shots per magazine and "reload" seconds to
## reload it (R; a weapon fresh out of a crate comes loaded).
const DEFS := {
	"blaster": {"name": "Blaster", "short": "Reliable sidearm", "damage": 20.0, "cooldown": 0.24, "pellets": 1,
		"spread": 0.012, "range": 60.0, "color": Color(1.0, 0.5, 0.2), "sound": "blaster", "volume": -5.0, "pitch": 1.0,
		"muzzle": Vector3(0, 0.03, -0.33), "price": 50, "mag": 15, "reload": 1.2},
	"rifle": {"name": "Pulse Rifle", "short": "Rapid-fire energy rifle", "damage": 11.0, "cooldown": 0.09, "pellets": 1,
		"spread": 0.03, "range": 70.0, "color": Color(0.35, 0.85, 1.0), "sound": "pulse", "volume": -10.0, "pitch": 1.45,
		"muzzle": Vector3(0, 0.02, -0.58), "price": 110, "mag": 45, "reload": 1.8},
	"scatter": {"name": "Scattergun", "short": "Rapid close-range pellet blasts", "damage": 9.0, "cooldown": 0.3, "pellets": 10,
		"spread": 0.1, "range": 24.0, "color": Color(1.0, 0.72, 0.3), "sound": "flak", "volume": -3.0, "pitch": 1.35,
		"muzzle": Vector3(0, 0.025, -0.5), "price": 100, "mag": 8, "reload": 1.9},
	"rail": {"name": "Rail Carbine", "short": "Piercing slug, slow to recharge", "damage": 90.0, "cooldown": 1.0, "pellets": 1,
		"spread": 0.004, "range": 100.0, "pierce": 5, "color": Color(0.7, 0.9, 1.0), "sound": "rail", "volume": -6.0, "pitch": 1.5,
		"muzzle": Vector3(0, 0.0, -0.55), "price": 120, "mag": 5, "reload": 2.0},
	"plasma": {"name": "Plasma Launcher", "short": "Bursting orbs that hit whole groups", "damage": 60.0, "cooldown": 0.95,
		"pellets": 1, "spread": 0.02, "range": 60.0, "splash": 6.0, "speed": 30.0, "color": Color(0.75, 0.4, 1.0),
		"sound": "plasma", "volume": -6.0, "pitch": 1.4, "muzzle": Vector3(0, 0.0, -0.44), "price": 130,
		"mag": 6, "reload": 2.2},
}
## Where the weapon sits relative to the first-person camera, and in a crew member's hand.
const VIEW_POS := Vector3(0.24, -0.2, -0.45)
const HELD_POS := Vector3(0.3, 1.15, -0.5)


static func exists(id: String) -> bool:
	return DEFS.has(id)


static func def(id: String) -> Dictionary:
	return DEFS.get(id, DEFS[DEFAULT])


static func display_name(id: String) -> String:
	return str(def(id)["name"])


## Shots in a full magazine.
static func mag(id: String) -> int:
	return int(def(id)["mag"])


## Seconds a reload takes.
static func reload_time(id: String) -> float:
	return float(def(id)["reload"])


## Shooting ray mask: ship interior, waystation and abandoned station walls, and enemies on foot.
static func shot_mask() -> int:
	return Game.LAYER_INTERIOR | Game.LAYER_BOARDER | Game.LAYER_STATION


# --- Models ------------------------------------------------------------------------------------

## Build a weapon model (origin at its middle, barrel along -Z) under `parent`. `accent` is the
## owner's colour.
static func build_model(parent: Node3D, id: String, accent: Color, first_person: bool) -> Node3D:
	var root := Node3D.new()
	root.name = "Weapon_" + id
	parent.add_child(root)
	var dark := Models.mat(Color(0.14, 0.15, 0.17), 0.5, 0.45)
	var steel := Models.mat(Color(0.3, 0.3, 0.32), 0.7, 0.3)
	var col: Color = def(id)["color"]
	var glow := Models.emissive(col, 1.6 if id != "blaster" else 1.0)
	match id:
		"rifle":
			Models.box(root, Vector3(0, 0, -0.05), Vector3(0.1, 0.13, 0.62), dark)
			Models.box(root, Vector3(0, -0.02, 0.33), Vector3(0.07, 0.11, 0.2), dark)
			Models.box(root, Vector3(0, -0.1, 0.1), Vector3(0.06, 0.15, 0.07), dark, Vector3(-15, 0, 0))
			Models.box(root, Vector3(0, -0.12, -0.13), Vector3(0.06, 0.15, 0.09), steel, Vector3(12, 0, 0))
			Models.cylinder(root, Vector3(0, 0.02, -0.46), 0.022, 0.24, steel, Vector3(90, 0, 0))
			Models.box(root, Vector3(0, 0.085, 0.0), Vector3(0.03, 0.04, 0.14), steel)
			for x: float in [-0.052, 0.052]:
				Models.box(root, Vector3(x, 0.02, -0.08), Vector3(0.006, 0.025, 0.42), glow)
		"scatter":
			Models.box(root, Vector3(0, 0, 0), Vector3(0.14, 0.13, 0.46), dark)
			for x: float in [-0.032, 0.032]:
				Models.cylinder(root, Vector3(x, 0.025, -0.36), 0.028, 0.3, steel, Vector3(90, 0, 0))
			Models.box(root, Vector3(0, -0.05, -0.3), Vector3(0.1, 0.06, 0.16), Models.mat(Color(0.45, 0.3, 0.18), 0.2, 0.7))
			Models.box(root, Vector3(0, -0.1, 0.14), Vector3(0.07, 0.16, 0.08), dark, Vector3(-15, 0, 0))
			Models.box(root, Vector3(0, 0.068, 0.02), Vector3(0.05, 0.012, 0.3), glow)
		"rail":
			Models.box(root, Vector3(0, 0, 0), Vector3(0.07, 0.1, 0.56), dark)
			for x: float in [-0.05, 0.05]:
				Models.box(root, Vector3(x, 0.0, -0.2), Vector3(0.025, 0.05, 0.66), steel)
			for z: float in [-0.1, -0.25, -0.4]:
				Models.cylinder(root, Vector3(0, 0.0, z), 0.06, 0.025, glow, Vector3(90, 0, 0))
			Models.box(root, Vector3(0, -0.1, 0.12), Vector3(0.06, 0.15, 0.07), dark, Vector3(-15, 0, 0))
			Models.box(root, Vector3(0, -0.01, 0.34), Vector3(0.06, 0.1, 0.16), dark)
		"plasma":
			Models.box(root, Vector3(0, 0, 0.02), Vector3(0.15, 0.15, 0.4), dark)
			Models.sphere(root, Vector3(0, 0.035, -0.1), 0.085, glow)
			Models.cylinder(root, Vector3(0, 0.0, -0.3), 0.05, 0.22, steel, Vector3(90, 0, 0), 0.04)
			Models.box(root, Vector3(0, -0.11, 0.14), Vector3(0.07, 0.16, 0.08), dark, Vector3(-15, 0, 0))
			Models.box(root, Vector3(0.078, 0.02, 0.06), Vector3(0.006, 0.04, 0.2), Models.emissive(accent, 0.8))
		_:
			Models.box(root, Vector3.ZERO, Vector3(0.09, 0.12, 0.42), dark)
			Models.box(root, Vector3(0, -0.07, 0.12), Vector3(0.07, 0.16, 0.08), dark, Vector3(-15, 0, 0))
			Models.cylinder(root, Vector3(0, 0.03, -0.25), 0.025, 0.18, steel, Vector3(90, 0, 0))
			Models.box(root, Vector3(0, 0.063, 0), Vector3(0.025, 0.015, 0.26), glow)
			Models.box(root, Vector3(-0.044, 0.03, -0.05), Vector3(0.006, 0.02, 0.12), Models.emissive(accent, 0.8))
	if first_person:
		for c in root.get_children():
			(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return root


## Muzzle position in first-person camera space.
static func view_muzzle(id: String) -> Vector3:
	return VIEW_POS + (def(id)["muzzle"] as Vector3)


## Muzzle position in a crew member's local space (third person).
static func held_muzzle(id: String) -> Vector3:
	return HELD_POS + (def(id)["muzzle"] as Vector3)


# --- Effects (every peer) ----------------------------------------------------------------------

## Tracers, impacts and the shot sound. `ends` holds one end point per pellet (world space),
## `normals` the surface normals there; bit i of `hit_mask` / `flesh_mask` says pellet i hit
## something / an alien.
static func shot_fx(id: String, from: Vector3, ends: PackedVector3Array, normals: PackedVector3Array, hit_mask: int, flesh_mask: int) -> void:
	var d := def(id)
	var col: Color = d["color"]
	for i in ends.size():
		var hit := (hit_mask & (1 << i)) != 0
		var flesh := (flesh_mask & (1 << i)) != 0
		match id:
			"rail":
				Fx.tracer(from, ends[i], Color(0.7, 0.9, 1.0), 0.07, 0.25)
				Fx.tracer(from, ends[i], Color(1.0, 1.0, 1.0), 0.02, 0.15)
			"scatter":
				Fx.tracer(from, ends[i], col, 0.018, 0.06)
			"rifle":
				Fx.tracer(from, ends[i], col, 0.025, 0.05)
			"plasma":
				pass
			_:
				Fx.tracer(from, ends[i], col, 0.035, 0.07)
		if hit and id != "plasma":
			var strength := 0.6 if id == "scatter" or id == "rifle" else (1.4 if id == "rail" else 1.0)
			Fx.impact(ends[i], normals[i] if i < normals.size() else Vector3.UP,
				Color(0.6, 1.0, 0.3) if flesh else Color(1.0, 0.6, 0.3), strength * (1.2 if flesh else 1.0))
	Fx.flash(from, col, 1.5, 3.0, 0.05)
	Sfx.play(str(d["sound"]), from, float(d["volume"]), float(d["pitch"]))


## A plasma orb flying from `from_local` to `to_local` in `ship`'s space; it bursts on arrival and
## then calls `on_burst` (the shooter uses that to ask for the splash damage).
static func launch_orb(ship: Node3D, from_local: Vector3, to_local: Vector3, on_burst := Callable()) -> void:
	var d := def("plasma")
	var col: Color = d["color"]
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.14
	sm.height = 0.28
	sm.radial_segments = 10
	sm.rings = 6
	mi.mesh = sm
	mi.material_override = Models.glow(Color(col.r * 3.0, col.g * 3.0, col.b * 3.0, 1.0))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	mi.position = from_local
	ship.add_child(mi)
	var light := OmniLight3D.new()
	light.light_color = col
	light.light_energy = 1.5
	light.omni_range = 4.0
	mi.add_child(light)
	var t := maxf(0.05, from_local.distance_to(to_local) / float(d["speed"]))
	var tw := mi.create_tween()
	tw.tween_property(mi, "position", to_local, t)
	tw.tween_callback(func():
		var pos := ship.to_global(to_local)
		Fx.explosion(pos, float(d["splash"]) * 0.8, col)
		Sfx.play("small_explosion", pos, -4.0, 1.3)
		if on_burst.is_valid():
			on_burst.call()
		mi.queue_free())
