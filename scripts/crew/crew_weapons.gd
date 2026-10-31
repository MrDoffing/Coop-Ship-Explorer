class_name CrewWeapons
extends RefCounted
## Hand weapons for the crew. Everyone starts a dive with the Pistol; the others turn up in
## abandoned stations and in waystation shops, packed in supply crates like everything else. Look
## at a crate holding one and press F to swap: your current weapon goes into that crate.
##
## Two kinds:
## - "mag": guns firing from a magazine (Pistol, Revolver, Submachine Gun, Pulse Rifle, Marksman
##   Rifle, Shotgun, Multiple Grenade Launcher). Most throw a spent casing out of the ejection port
##   with every shot; the Revolver keeps its cases in the cylinder until its moon clip drops out at a
##   reload, and the grenade launcher throws its six out when it is opened. Once the magazine is
##   empty the trigger only clicks, and R reloads (the old magazine drops to the floor). Crew bots
##   reload by themselves.
## - "heat": energy weapons (Photon Rifle, Storm Lance). Every shot heats them and the heat bleeds
##   off by itself; at full heat they overheat and vent, locked until they have cooled. R vents them
##   early.
## Most fire for as long as LMB is held; "semi" weapons (the Revolver) fire once a pull of the
## trigger, as fast as it is pulled. The Photon Rifle's shots fly as glowing bolts. The Storm Lance
## (id "lightning") charges while LMB is held and lets go a bolt on release: it goes where it is
## aimed, strikes the alien in its way and jumps on to the aliens near it. The grenade launcher's
## grenades fly in an arc and bounce about until they go off (Grenades).
##
## Hip fire (LMB) scatters widely ("hip"); aiming down the weapon's own sight (RMB, "sight" and
## "zoom") is accurate ("ads"), but every shot in quick succession widens the scatter ("bloom", up
## to "bloom_max"; it settles again within half a second or so), so the first shot is the most
## accurate. Every shot kicks the view up ("kick", radians) and the gun back ("punch", metres); with
## "kick_grow" each shot kicks harder the more the scatter has built up.
##
## Damage scales with the ship's "blaster_damage" stat relative to BASE_DAMAGE, so the Gunsmith Kit
## from a shop boosts every crew weapon. Hits are detected by the shooter and sent to the server;
## a grenade flies in ship-local space so it keeps up with a moving ship, and asks the server for
## its blast's damage where it goes off.

const BASE_DAMAGE := 20.0
const DEFAULT := "pistol"
const ORDER := ["pistol", "dual", "revolver", "smg", "rifle", "photon", "marksman", "shotgun", "mgl", "lightning"]
## "kind" "mag" or "heat"; "damage" per pellet (for the grenade launcher, the blast's in its middle;
## half of it at its edge); "cooldown" seconds between shots; "semi": one shot a pull of the
## trigger (the others fire while LMB is held); "hip" / "ads" the scatter (radius of the cone,
## radians) from the hip and aimed; "bloom" scatter added per shot, up to "bloom_max"; "kick_grow"
## how much harder a shot kicks once the bloom is full (1 + kick_grow times its share of
## bloom_max); "range" (m); "falloff" [from, to, share]: the damage falls off from `from` metres to
## `share` of it at `to` metres and beyond; "pierce" enemies a round passes through; "grenade" the
## launcher's grenades ("speed" m/s, "lift" radians above the aim, "fuse" seconds, "splash" radius);
## "mag" rounds and "reload" seconds (mag weapons); "heat" per shot, "cool" per second and "reload"
## seconds for a full vent (heat weapons); "zoom" when aiming; "sight" the kind of sight; "kick" view
## climb and "punch" gun recoil per shot; "casing" what the ejection port throws out; "flash" the
## muzzle flash [size, glow, light energy]; "bolt" the Photon Rifle's bolts [speed m/s, length m];
## "price" in waystation shops (before the depth markup); "twin": two guns, one in each hand, taking
## turns (the Dual Pistols: "mag" counts both magazines).
const DEFS := {
	"pistol": {"name": "Pistol", "short": "Heavy sidearm", "kind": "mag", "damage": 22.0, "cooldown": 0.22, "pellets": 1,
		"hip": 0.05, "ads": 0.003, "bloom": 0.012, "bloom_max": 0.045, "range": 60.0,
		"mag": 12, "reload": 1.5, "zoom": 1.25, "sight": "iron", "kick": 0.016, "punch": 0.05, "casing": "pistol",
		"color": Color(1.0, 0.8, 0.45), "sound": "pistol", "volume": -4.0, "pitch": 1.0, "price": 50},
	"dual": {"name": "Dual Pistols", "short": "A pistol in each hand, firing in turn while the trigger is held; wild from the hip",
		"kind": "mag", "twin": true, "damage": 18.0, "cooldown": 0.12, "pellets": 1, "hip": 0.065, "ads": 0.014, "bloom": 0.01,
		"bloom_max": 0.05, "range": 55.0, "mag": 30, "reload": 2.2, "zoom": 1.1, "sight": "twin", "kick": 0.012, "punch": 0.05,
		"casing": "pistol", "color": Color(1.0, 0.8, 0.45), "sound": "pistol", "volume": -5.0, "pitch": 1.06, "price": 80},
	"revolver": {"name": "Revolver", "short": "Six shots as fast as you pull the trigger, each kicking harder; reloads from a moon clip",
		"kind": "mag", "damage": 40.0, "cooldown": 0.07, "semi": true, "pellets": 1, "hip": 0.035, "ads": 0.0025,
		"bloom": 0.05, "bloom_max": 0.22, "kick_grow": 2.4, "range": 60.0, "mag": 6, "reload": 2.3, "zoom": 1.25,
		"sight": "notch", "kick": 0.03, "punch": 0.075, "casing": "", "color": Color(1.0, 0.78, 0.42),
		"sound": "revolver", "volume": -3.0, "pitch": 1.0, "price": 90},
	"smg": {"name": "Submachine Gun", "short": "Drum-fed and very fast, but wild, and weak beyond close range", "kind": "mag",
		"damage": 7.5, "cooldown": 0.06, "pellets": 1, "hip": 0.09, "ads": 0.035, "bloom": 0.006, "bloom_max": 0.06,
		"kick_grow": 0.8, "falloff": [10.0, 28.0, 0.45], "range": 50.0, "mag": 64, "reload": 2.6, "zoom": 1.2,
		"sight": "peep", "kick": 0.011, "punch": 0.024, "casing": "pistol", "color": Color(1.0, 0.8, 0.45),
		"flash": [0.21, 3.0, 1.2], "sound": "smg", "volume": -8.0, "pitch": 1.0, "price": 100},
	"rifle": {"name": "Pulse Rifle", "short": "Rapid-fire rifle with an ammo counter; hits hard and climbs", "kind": "mag", "damage": 15.0,
		"cooldown": 0.09, "pellets": 1, "hip": 0.06, "ads": 0.004, "bloom": 0.006, "bloom_max": 0.045, "kick_grow": 0.5,
		"range": 70.0, "mag": 40, "reload": 2.0, "zoom": 1.45, "sight": "reflex", "kick": 0.013, "punch": 0.042,
		"casing": "rifle", "color": Color(1.0, 0.82, 0.5), "sound": "rifle", "volume": -6.0, "pitch": 1.0, "price": 110},
	"photon": {"name": "Photon Rifle", "short": "Rapid-fire energy rifle firing glowing bolts; heats up instead of running dry", "kind": "heat",
		"damage": 11.5, "cooldown": 0.095, "pellets": 1, "hip": 0.06, "ads": 0.004, "bloom": 0.005, "bloom_max": 0.04,
		"range": 70.0, "heat": 0.024, "cool": 0.3, "reload": 1.8, "zoom": 1.45, "sight": "holo", "kick": 0.007,
		"punch": 0.022, "casing": "", "color": Color(0.45, 0.95, 1.0), "flash": [0.22, 2.6, 1.1], "bolt": [95.0, 0.75],
		"sound": "photon", "volume": -7.0, "pitch": 1.0, "price": 130},
	"marksman": {"name": "Marksman Rifle", "short": "Heavy semi-automatic rifle with a short scope; hits hard, through one alien into the next",
		"kind": "mag", "damage": 52.0, "cooldown": 0.36, "pellets": 1, "hip": 0.05, "ads": 0.0012, "bloom": 0.012,
		"bloom_max": 0.035, "range": 90.0, "pierce": 2, "mag": 10, "reload": 2.3, "zoom": 1.8, "sight": "scope",
		"kick": 0.04, "punch": 0.07, "casing": "marksman", "color": Color(1.0, 0.8, 0.45), "sound": "marksman",
		"volume": -2.0, "pitch": 1.0, "price": 120},
	"shotgun": {"name": "Shotgun", "short": "Slow, heavy pump shotgun; shreds anything up close", "kind": "mag", "damage": 15.0,
		"cooldown": 0.7, "pellets": 10, "hip": 0.12, "ads": 0.075, "bloom": 0.01, "bloom_max": 0.02, "falloff": [6.0, 20.0, 0.4],
		"range": 24.0, "mag": 8, "reload": 2.2, "zoom": 1.15, "sight": "bead", "kick": 0.07, "punch": 0.11, "casing": "shell",
		"color": Color(1.0, 0.72, 0.35), "sound": "shotgun", "volume": -1.0, "pitch": 0.92, "price": 100},
	"mgl": {"name": "Multiple Grenade Launcher", "short": "Six 40 mm grenades, fully automatic: they bounce about until they go off with a big blast",
		"kind": "mag", "damage": 80.0, "cooldown": 0.36, "pellets": 1, "hip": 0.025, "ads": 0.006,
		"bloom": 0.012, "bloom_max": 0.04, "range": 60.0, "grenade": {"speed": 22.0, "lift": 0.1, "fuse": 1.6, "splash": 6.5},
		"mag": 6, "reload": 3.0, "zoom": 1.2, "sight": "ring", "kick": 0.05, "punch": 0.09, "casing": "",
		"color": Color(1.0, 0.6, 0.25), "sound": "mgl", "volume": -3.0, "pitch": 1.0, "price": 160},
	"lightning": {"name": "Storm Lance", "short": "Charge, aim and release: a bolt that jumps on from the alien it strikes", "kind": "heat",
		"damage": 30.0, "damage_max": 85.0, "cooldown": 0.25, "pellets": 1, "hip": 0.0, "ads": 0.0, "bloom": 0.0,
		"bloom_max": 0.0, "range": 20.0, "heat": 0.16, "heat_charge": 0.24, "cool": 0.15, "reload": 1.8, "zoom": 1.15,
		"sight": "fork", "kick": 0.045, "punch": 0.06, "casing": "", "color": Color(0.55, 0.8, 1.0), "sound": "zap",
		"volume": -3.0, "pitch": 1.0, "price": 150},
}
## Storm Lance: seconds to a full charge, the least charge that lets a bolt go, how close (m, beyond
## its own size) an alien must pass to the line it is aimed along to draw the bolt (it does not seek
## targets: it goes where it is aimed), how far the bolt jumps on from an alien to the next, how many
## more it jumps to and how much of the damage each jump keeps.
const CHARGE_TIME := 0.9
const CHARGE_MIN := 0.2
const BOLT_SLACK := 0.15
const CHAIN_RANGE := 7.0
const CHAIN_JUMPS := 4
const CHAIN_FALLOFF := 0.72
## Heat weapons: an overheated weapon vents (locked) this many times slower than a vent with R, and
## heat starts to bleed off this long after the last shot.
const OVERHEAT_VENT := 1.5
const COOL_DELAY := 0.3
## Where the weapon sits relative to the first-person camera (ready, from the hip), and in a crew
## member's hand.
const VIEW_POS := Vector3(0.2, -0.19, -0.42)
const HELD_POS := Vector3(0.3, 1.15, -0.5)
## Each weapon's muzzle (in its model's frame).
const MUZZLES := {
	"pistol": Vector3(0, 0.045, -0.142),
	"dual": Vector3(0, 0.045, -0.139),
	"revolver": Vector3(0, 0.036, -0.174),
	"smg": Vector3(0, 0.012, -0.356),
	"rifle": Vector3(0, 0.005, -0.585),
	"photon": Vector3(0, 0.0, -0.51),
	"marksman": Vector3(0, 0.006, -0.672),
	"shotgun": Vector3(0, 0.025, -0.525),
	"mgl": Vector3(0, 0.03, -0.268),
	"lightning": Vector3(0, 0, -0.455),
}
## Muzzle flash sizes for the weapons without a "flash" of their own.
const FLASH_SIZES := {"pistol": 0.3, "dual": 0.27, "revolver": 0.38, "marksman": 0.44, "shotgun": 0.45, "mgl": 0.5}
## The Dual Pistols: how far either side of the middle each gun is held, in your own view, in a crew
## member's hands (seen by everyone else), and lying on a crate.
const DUAL_SPREAD := 0.165
const DUAL_HELD_SPREAD := 0.3
const DUAL_CRATE_SPREAD := 0.075
## The marksman rifle's scope: where its eyepiece is (Z, the model's frame), how far behind it the eye
## sits when aiming, the eyepiece's radius and the scope's length (it flares out to the front).
const SCOPE_EYEPIECE_Z := 0.0855
const SCOPE_RELIEF := 0.1045
const SCOPE_RADIUS := 0.0195
const SCOPE_LENGTH := 0.075
## Casings: [mesh radius, length, colour, base colour] per kind (the base is the rim); a little
## bigger than life, so they show. "40mm" are the grenade launcher's aluminium cases.
const CASINGS := {
	"pistol": [0.0065, 0.028, Color(0.78, 0.58, 0.24), Color(0.7, 0.52, 0.22)],
	"rifle": [0.007, 0.05, Color(0.8, 0.6, 0.25), Color(0.7, 0.52, 0.22)],
	"marksman": [0.0078, 0.066, Color(0.8, 0.6, 0.25), Color(0.7, 0.52, 0.22)],
	"shell": [0.0115, 0.068, Color(0.62, 0.08, 0.06), Color(0.78, 0.6, 0.26)],
	"40mm": [0.021, 0.05, Color(0.62, 0.63, 0.6), Color(0.5, 0.5, 0.48)],
}
## The marksman scope's eyepiece: a faintly tinted lens, darker towards its rim, with a fine cross
## (broken in the middle), a post rising from below, stadia ticks under it and a glowing red chevron
## whose tip is the aim point.
const RETICLE_SHADER := """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, shadows_disabled;
uniform vec3 tint : source_color = vec3(0.5, 0.62, 0.58);
uniform vec3 chevron : source_color = vec3(1.0, 0.12, 0.05);
uniform float energy = 3.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	p.y = -p.y;
	float r = length(p);
	if (r > 0.97) {
		discard;
	}
	float px = fwidth(p.x);
	float h = (1.0 - smoothstep(px * 0.6, px * 1.6, abs(p.y))) * step(0.22, abs(p.x));
	float v = (1.0 - smoothstep(px * 1.2, px * 2.6, abs(p.x))) * step(p.y, -0.2);
	float ticks = 0.0;
	for (int i = 1; i < 4; i++) {
		float y = -0.2 - float(i) * 0.14;
		ticks = max(ticks, (1.0 - smoothstep(px * 0.6, px * 1.6, abs(p.y - y))) * step(abs(p.x), 0.07 - 0.015 * float(i)));
	}
	float d = abs(-p.y - abs(p.x)) * 0.7071;
	float chev = (1.0 - smoothstep(px * 0.8, px * 2.2, d)) * step(-0.12, p.y) * step(p.y, 0.004);
	float lines = max(max(h, v), ticks);
	float rim = smoothstep(0.78, 0.97, r);
	vec3 col = mix(tint * 0.08, vec3(0.0), max(lines, rim));
	col = mix(col, chevron * energy, chev);
	ALBEDO = col;
	ALPHA = clamp(0.05 + rim * 0.85 + lines * 0.9 + chev, 0.0, 1.0);
}
"""

static var _cache: Dictionary = {}


static func exists(id: String) -> bool:
	return DEFS.has(id)


static func def(id: String) -> Dictionary:
	return DEFS.get(id, DEFS[DEFAULT])


static func display_name(id: String) -> String:
	return str(def(id)["name"])


## True for the energy weapons that heat up instead of firing from a magazine.
static func uses_heat(id: String) -> bool:
	return str(def(id)["kind"]) == "heat"


## True for the weapons that fire once a pull of the trigger.
static func semi(id: String) -> bool:
	return bool(def(id).get("semi", false))


## Shots in a full magazine (0 for heat weapons).
static func mag(id: String) -> int:
	return int(def(id).get("mag", 0))


## Seconds a reload takes (a full vent for heat weapons).
static func reload_time(id: String) -> float:
	return float(def(id)["reload"])


## The share of its damage a round of `id` still does after flying `dist` metres ("falloff").
static func falloff(id: String, dist: float) -> float:
	var f: Array = def(id).get("falloff", [])
	if f.is_empty():
		return 1.0
	return lerpf(1.0, float(f[2]), smoothstep(float(f[0]), float(f[1]), dist))


## Shooting ray mask: ship interior, waystation and abandoned station walls, and enemies on foot.
static func shot_mask() -> int:
	return Game.LAYER_INTERIOR | Game.LAYER_BOARDER | Game.LAYER_STATION


## The field of view (degrees) when aiming down `id`'s sight, from `base`.
static func aim_fov(id: String, base: float) -> float:
	return rad_to_deg(2.0 * atan(tan(deg_to_rad(base) * 0.5) / float(def(id)["zoom"])))


# --- Models ------------------------------------------------------------------------------------

## Build a weapon model (origin at its middle, barrel along -Z, its sight line on x = 0) under
## `parent`. `accent` is the owner's colour. Every model has its display on top at the back (the
## first-person one shows the rounds left, or the heat). The parts the animations need are in the root's "parts" meta:
## "mag" (the magazine, mag weapons; the Revolver's moon clip, the grenade launcher's rounds),
## "slide" (the pistol's slide, a rifle's or the submachine gun's bolt handle, the shotgun's pump)
## and "travel" (how far it moves back), "crane", "cylinder" and "hammer" (the Revolver and the
## grenade launcher: the crane swings the cylinder out, the cylinder turns, the hammer falls),
## "noses" (the grenade launcher's rounds as they show in its chambers), "muzzle", "port" (the
## ejection port), "eye" (where the eye is when aiming down the sight), "front" (the sight's front
## element, which sits in the middle of the view when aiming), "glow" (materials that glow with heat
## or charge), "vent" (the hatch that opens to vent heat), "prongs" (the Lightning Thrower's emitter
## tips), "flash" (the muzzle flash) and "display" (labels and bar, first person). The Dual Pistols
## are two guns (see _build_dual): the right gun's parts are the root's own, "twin" holds the left
## gun's, "guns" the two gun nodes (right first). `compact`: laid on a crate (the Dual Pistols side
## by side).
static func build_model(parent: Node3D, id: String, accent: Color, first_person: bool, compact := false) -> Node3D:
	var root := Node3D.new()
	root.name = "Weapon_" + id
	parent.add_child(root)
	var parts := {"root": root, "glow": [], "travel": Vector3.ZERO, "muzzle": MUZZLES.get(id, MUZZLES[DEFAULT])}
	var m := _mats(accent)
	if id == "dual":
		_build_dual(root, parts, m, first_person, compact)
		if first_person:
			_no_shadows(root)
		root.set_meta("parts", parts)
		return root
	match id:
		"revolver":
			_build_revolver(root, parts, m)
		"smg":
			_build_smg(root, parts, m)
		"rifle":
			_build_rifle(root, parts, m)
		"photon":
			_build_photon(root, parts, m)
		"marksman":
			_build_marksman(root, parts, m)
		"shotgun":
			_build_shotgun(root, parts, m)
		"mgl":
			_build_mgl(root, parts, m)
		"lightning":
			_build_lightning(root, parts, m)
		_:
			_build_pistol(root, parts, m)
	_build_flash(root, parts, id)
	_build_display(root, parts, id, first_person)
	if first_person:
		_no_shadows(root)
	root.set_meta("parts", parts)
	return root


static func _mats(accent: Color) -> Dictionary:
	return {
		"dark": Models.mat(Color(0.12, 0.125, 0.13), 0.6, 0.45),
		"steel": Models.mat(Color(0.3, 0.31, 0.32), 0.8, 0.32),
		"gun": Models.mat(Color(0.2, 0.21, 0.22), 0.75, 0.38),
		"olive": Models.panel_mat(Color(0.25, 0.27, 0.2), 0.3, 0.7, 6.0),
		"grip": Models.mat(Color(0.1, 0.085, 0.07), 0.1, 0.85),
		"wood": Models.mat(Color(0.33, 0.2, 0.11), 0.1, 0.7),
		"black": Models.mat(Color(0.02, 0.02, 0.02), 0.2, 0.9),
		"brass": Models.mat(Color(0.75, 0.55, 0.22), 0.85, 0.35),
		"copper": Models.mat(Color(0.72, 0.4, 0.2), 0.85, 0.35),
		"ceramic": Models.mat(Color(0.82, 0.8, 0.74), 0.0, 0.5),
		"tritium": Models.emissive(Color(0.4, 1.0, 0.45), 2.2),
		"bead": Models.emissive(Color(1.0, 0.7, 0.28), 1.8),
		"accent": Models.emissive(accent, 0.8),
	}


static func _box(root: Node3D, pos: Vector3, size: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	return Models.box(root, pos, size, mat, rot)


static func _cyl(root: Node3D, pos: Vector3, r: float, h: float, mat: Material, rot := Vector3(90, 0, 0), top := -1.0) -> MeshInstance3D:
	return Models.cylinder(root, pos, r, h, mat, rot, top, 12)


## An open tube along Z (no end caps, so you can look through it): `r_back` at its +Z end, `r_front`
## at its -Z end.
static func _tube(root: Node3D, pos: Vector3, r_back: float, r_front: float, length: float, mat: Material) -> MeshInstance3D:
	var cm := CylinderMesh.new()
	cm.top_radius = r_back
	cm.bottom_radius = r_front
	cm.height = length
	cm.radial_segments = 18
	cm.rings = 1
	cm.cap_top = false
	cm.cap_bottom = false
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = Vector3(90, 0, 0)
	root.add_child(mi)
	return mi


## A ring round the Z axis (a sight's ring, a chamber's mouth).
static func _ring(root: Node3D, pos: Vector3, inner: float, outer: float, mat: Material, rings := 20) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = inner
	tm.outer_radius = outer
	tm.rings = rings
	tm.ring_segments = 6
	mi.mesh = tm
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = Vector3(90, 0, 0)
	root.add_child(mi)
	return mi


## A material that glows (heat or charge); each weapon gets its own, so it can follow the weapon.
static func _glow_mat(parts: Dictionary, col: Color, base := 0.6) -> StandardMaterial3D:
	var g := StandardMaterial3D.new()
	g.albedo_color = Color(0.08, 0.08, 0.09)
	g.emission_enabled = true
	g.emission = col
	g.emission_energy_multiplier = base
	g.set_meta("base", base)
	(parts["glow"] as Array).append(g)
	return g


## A heavy service pistol, a Blender-made model (tools/blender/weapons.py): frame, slide (it runs
## back with every shot and locks back when the magazine is empty), grip with the magazine in it,
## and iron sights; their glowing tritium dots are made here, on the slide.
static func _build_pistol(root: Node3D, parts: Dictionary, m: Dictionary) -> void:
	var asset := "weapon_pistol"
	Models.asset_mesh(root, asset, "Body", {"Accent": m["accent"]})
	var slide := Node3D.new()
	slide.name = "Slide"
	root.add_child(slide)
	Models.asset_mesh(slide, asset, "Slide")
	for x: float in [-0.011, 0.011]:
		Models.sphere(slide, Vector3(x, 0.0745, 0.0625), 0.0019, m["tritium"], Vector3.ONE, 8)
	Models.sphere(slide, Vector3(0, 0.0745, -0.1125), 0.0019, m["tritium"], Vector3.ONE, 8)
	var mag := Node3D.new()
	mag.name = "Mag"
	mag.position = Vector3(0, -0.055, 0.045)
	mag.rotation_degrees = Vector3(-14, 0, 0)
	root.add_child(mag)
	Models.asset_mesh(mag, asset, "Mag")
	parts["mag"] = mag
	parts["slide"] = slide
	parts["travel"] = Vector3(0, 0, 0.042)
	parts["port"] = Vector3(0.026, 0.056, -0.03)
	parts["eye"] = Vector3(0, 0.0745, 0.5)
	parts["front"] = Vector3(0, 0.0745, -0.1125)
	parts["display_at"] = [Vector3(0, 0.016, 0.0915), Vector3(0, 0.32, 1.0), Vector2(0.032, 0.016)]


## The Dual Pistols: a slim stainless pistol in each hand (a Blender-made model, "dual" in
## tools/blender/weapons.py: an open-top slide showing the barrel, a round-spur hammer, black
## wraparound grips), DUAL_SPREAD either side of the root (DUAL_HELD_SPREAD in a crew member's hands,
## DUAL_CRATE_SPREAD on a crate). Each is built like the Pistol, with its own slide, magazine, sight
## dots, muzzle flash and display (showing that gun's own rounds).
static func _build_dual(root: Node3D, parts: Dictionary, m: Dictionary, first_person: bool, compact: bool) -> void:
	var spread := DUAL_CRATE_SPREAD if compact else (DUAL_SPREAD if first_person else DUAL_HELD_SPREAD)
	var guns: Array[Node3D] = []
	for side in 2:
		var gun := Node3D.new()
		gun.name = "GunR" if side == 0 else "GunL"
		gun.position = Vector3(spread if side == 0 else -spread, 0, 0)
		root.add_child(gun)
		var gp := parts if side == 0 else {"root": gun, "glow": [], "travel": Vector3.ZERO}
		gp["muzzle"] = MUZZLES["dual"]
		_build_dual_gun(gun, gp, m)
		_build_flash(gun, gp, "dual")
		_build_display(gun, gp, "dual", first_person)
		gp["gun"] = gun
		guns.append(gun)
		if side == 1:
			parts["twin"] = gp
	parts["guns"] = guns


## One of the Dual Pistols, in its own frame (the Pistol's: barrel along -Z, the sight line on x = 0).
static func _build_dual_gun(gun: Node3D, gp: Dictionary, m: Dictionary) -> void:
	var asset := "weapon_dual"
	Models.asset_mesh(gun, asset, "Body", {"Accent": m["accent"]})
	var slide := Node3D.new()
	slide.name = "Slide"
	gun.add_child(slide)
	Models.asset_mesh(slide, asset, "Slide")
	for x: float in [-0.0095, 0.0095]:
		Models.sphere(slide, Vector3(x, 0.0735, 0.0625), 0.0018, m["tritium"], Vector3.ONE, 8)
	Models.sphere(slide, Vector3(0, 0.0725, -0.1175), 0.0018, m["tritium"], Vector3.ONE, 8)
	var mag := Node3D.new()
	mag.name = "Mag"
	mag.position = Vector3(0, -0.055, 0.043)
	mag.rotation_degrees = Vector3(-15, 0, 0)
	gun.add_child(mag)
	Models.asset_mesh(mag, asset, "Mag")
	gp["mag"] = mag
	gp["slide"] = slide
	gp["travel"] = Vector3(0, 0, 0.04)
	gp["port"] = Vector3(0.024, 0.054, -0.012)
	gp["eye"] = Vector3(0, 0.0735, 0.5)
	gp["front"] = Vector3(0, 0.0725, -0.1175)
	gp["display_at"] = [Vector3(0, 0.016, 0.0915), Vector3(0, 0.32, 1.0), Vector2(0.032, 0.016)]


## The Dual Pistols' gun that fires next with `ammo` rounds left in both (0 the right, 1 the left:
## they take turns, the right first after a reload).
static func twin_side(id: String, ammo: int) -> int:
	return (mag(id) - ammo) % 2


## How many rounds each of the Dual Pistols has left with `ammo` in both: [right, left].
static func twin_rounds(id: String, ammo: int) -> Vector2i:
	var fired := mag(id) - ammo
	var half := mag(id) / 2
	return Vector2i(half - (fired + 1) / 2, half - fired / 2)


## True for a weapon of two guns that take turns (the Dual Pistols).
static func is_twin(id: String) -> bool:
	return bool(def(id).get("twin", false))


## A heavy six-shot revolver, a Blender-made model: a big frame, a barrel with a vented rib and a
## full-length lug under it, a fluted cylinder that turns a chamber after every shot (the hammer
## flicks back and falls as it fires), and a notch in the top strap and a blade with a glowing bead
## (made here) to aim with. It reloads from a moon clip: the cylinder swings out to the left on its
## crane, the spent clip (six cases on a steel star) drops out of the back and a full one goes in.
static func _build_revolver(root: Node3D, parts: Dictionary, m: Dictionary) -> void:
	var asset := "weapon_revolver"
	var axis := 0.022
	Models.asset_mesh(root, asset, "Body", {"Accent": m["accent"]})
	Models.sphere(root, Vector3(0, 0.0605, -0.155), 0.0021, m["bead"], Vector3.ONE, 8)
	var hammer := Node3D.new()
	hammer.name = "Hammer"
	hammer.position = Vector3(0, 0.05, 0.036)
	root.add_child(hammer)
	Models.asset_mesh(hammer, asset, "Hammer")
	# The crane (it pivots under the cylinder), the cylinder on it, the moon clip at its back.
	var crane := Node3D.new()
	crane.name = "Crane"
	crane.position = Vector3(-0.004, axis - 0.028, -0.001)
	root.add_child(crane)
	Models.asset_mesh(crane, asset, "Crane")
	var cyl := Node3D.new()
	cyl.name = "Cylinder"
	cyl.position = Vector3(0.004, 0.028, 0)
	crane.add_child(cyl)
	Models.asset_mesh(cyl, asset, "Cylinder")
	var clip := Node3D.new()
	clip.name = "Mag"
	clip.position = Vector3(0, 0, 0.0232)
	cyl.add_child(clip)
	Models.asset_mesh(clip, asset, "Clip")
	parts["mag"] = clip
	parts["crane"] = crane
	parts["cylinder"] = cyl
	parts["hammer"] = hammer
	parts["port"] = Vector3(-0.03, axis, 0.03)
	parts["eye"] = Vector3(0, 0.0605, 0.5)
	parts["front"] = Vector3(0, 0.0605, -0.155)
	parts["display_at"] = [Vector3(0, 0.012, 0.076), Vector3(0, 0.3, 1.0), Vector2(0.03, 0.015)]


## A drum-fed submachine gun, WW2 style, a Blender-made model: a stamped steel receiver, a slotted
## cooling jacket round the barrel with a slanted lip over the muzzle, a bolt handle on the right
## that runs back and forth with every shot, a 64-round drum under it, a wooden pistol grip, and a
## peep sight at the back with a hooded post at the front.
static func _build_smg(root: Node3D, parts: Dictionary, m: Dictionary) -> void:
	var asset := "weapon_smg"
	Models.asset_mesh(root, asset, "Body", {"Accent": m["accent"]})
	var bolt := Node3D.new()
	bolt.name = "Bolt"
	bolt.position = Vector3(0.0255, 0.008, -0.02)
	root.add_child(bolt)
	Models.asset_mesh(bolt, asset, "Bolt")
	var mag := Node3D.new()
	mag.name = "Mag"
	mag.position = Vector3(0, -0.028, -0.075)
	root.add_child(mag)
	Models.asset_mesh(mag, asset, "Mag")
	parts["mag"] = mag
	parts["slide"] = bolt
	parts["travel"] = Vector3(0, 0, 0.05)
	parts["port"] = Vector3(0.026, 0.019, -0.065)
	parts["eye"] = Vector3(0, 0.056, 0.42)
	parts["front"] = Vector3(0, 0.056, -0.33)
	parts["display_at"] = [Vector3(0, 0.026, 0.138), Vector3(0, 0.42, 1.0), Vector2(0.032, 0.016)]


## A pulse rifle, a Blender-made model (tools/blender/rifle.py): an olive receiver and a slotted
## barrel shroud, a launcher tube under it, a magazine in front of the grip, a bolt handle that
## cycles with every shot, a reflex sight (a glass pane with a glowing ring, made here) and an ammo
## counter on top at the back. A stripe on its side is in the owner's colour.
static func _build_rifle(root: Node3D, parts: Dictionary, m: Dictionary) -> void:
	Models.asset_mesh(root, "rifle", "Body", {"Accent": m["accent"]})
	var mag := Node3D.new()
	mag.name = "Mag"
	mag.position = Vector3(0, -0.06, -0.075)
	root.add_child(mag)
	Models.asset_mesh(mag, "rifle", "Mag")
	var bolt := Node3D.new()
	bolt.name = "Bolt"
	root.add_child(bolt)
	Models.asset_mesh(bolt, "rifle", "Bolt")
	var glass := MeshInstance3D.new()
	var gq := QuadMesh.new()
	gq.size = Vector2(0.032, 0.058)
	glass.mesh = gq
	glass.material_override = Models.glass(Color(0.5, 0.7, 0.75, 0.12))
	glass.position = Vector3(0, 0.105, 0.02)
	root.add_child(glass)
	var ret := MeshInstance3D.new()
	var rq := QuadMesh.new()
	rq.size = Vector2(0.016, 0.016)
	ret.mesh = rq
	ret.material_override = GunPod.sight_material()
	ret.position = Vector3(0, 0.105, 0.0195)
	root.add_child(ret)
	parts["mag"] = mag
	parts["slide"] = bolt
	parts["travel"] = Vector3(0, 0, 0.05)
	parts["port"] = Vector3(0.036, 0.022, -0.04)
	parts["eye"] = Vector3(0, 0.105, 0.38)
	parts["front"] = Vector3(0, 0.105, 0.0195)
	parts["display_at"] = [Vector3(0, 0.064, 0.135), Vector3(0, 0.45, 1.0), Vector2(0.034, 0.017)]


## The photon rifle, a Blender-made model: an olive receiver with a glass chamber on its left (the
## photon core in it glows hotter as the rifle heats up and flashes with every shot; the glass is
## made here) and capacitor cans on its right, an emitter barrel of cooling fins on a copper core
## (the fins glow with the heat) ending in a lens, a round holographic sight (its glass and cyan
## ring made here), and a hatch on the side that opens to vent.
static func _build_photon(root: Node3D, parts: Dictionary, m: Dictionary) -> void:
	var asset := "weapon_photon"
	var col: Color = DEFS["photon"]["color"]
	var glow := _glow_mat(parts, col, 0.5)
	Models.asset_mesh(root, asset, "Body", {"Accent": m["accent"], "Glow": glow})
	_cyl(root, Vector3(-0.037, 0.012, -0.01), 0.013, 0.17, Models.glass(Color(0.6, 0.9, 1.0, 0.18)))
	var glass := MeshInstance3D.new()
	var gc := CylinderMesh.new()
	gc.top_radius = 0.0213
	gc.bottom_radius = 0.0213
	gc.height = 0.001
	gc.radial_segments = 32
	gc.rings = 1
	glass.mesh = gc
	glass.material_override = Models.glass(Color(0.5, 0.8, 0.85, 0.1))
	glass.position = Vector3(0, 0.074, 0.0)
	glass.rotation_degrees = Vector3(90, 0, 0)
	root.add_child(glass)
	var ret := MeshInstance3D.new()
	var rq := QuadMesh.new()
	rq.size = Vector2(0.016, 0.016)
	ret.mesh = rq
	ret.material_override = holo_material()
	ret.position = Vector3(0, 0.074, -0.0008)
	root.add_child(ret)
	var vent := Node3D.new()
	vent.name = "Vent"
	vent.position = Vector3(0.031, 0.025, 0.12)
	root.add_child(vent)
	Models.asset_mesh(vent, asset, "Vent")
	parts["vent"] = vent
	parts["eye"] = Vector3(0, 0.074, 0.4)
	parts["front"] = Vector3(0, 0.074, -0.0008)
	parts["display_at"] = [Vector3(0, 0.048, 0.212), Vector3(0, 0.4, 1.0), Vector2(0.034, 0.017)]


## The holographic sight's ring (the reflector sight's reticle, in cyan), shared.
static func holo_material() -> ShaderMaterial:
	if not _cache.has("holo"):
		var mat := GunPod.sight_material().duplicate() as ShaderMaterial
		mat.set_shader_parameter("color", Color(0.3, 0.95, 1.0))
		mat.set_shader_parameter("energy", 2.6)
		_cache["holo"] = mat
	return _cache["holo"]


## The marksman rifle, a Blender-made model: a heavy semi-automatic rifle with a steel receiver, a
## wooden handguard and pistol grip, a long barrel with a ported muzzle brake, a ten-round box
## magazine and a bolt handle on the right that runs back with every shot. A short, wide prism scope
## sits on top (made here): aimed, you look through its eyepiece at a red chevron, with the world
## round the scope still in view. The scope's body flares out from the eyepiece exactly as the eye's
## view through it does (SCOPE_*), so from the eye its inside is never seen: only the world through it.
static func _build_marksman(root: Node3D, parts: Dictionary, m: Dictionary) -> void:
	var asset := "weapon_marksman"
	var sy := 0.085
	Models.asset_mesh(root, asset, "Body", {"Accent": m["accent"]})
	var mag := Node3D.new()
	mag.name = "Mag"
	mag.position = Vector3(0, -0.04, -0.04)
	root.add_child(mag)
	Models.asset_mesh(mag, asset, "Mag")
	var bolt := Node3D.new()
	bolt.name = "Bolt"
	bolt.position = Vector3(0.0265, 0.012, 0.02)
	root.add_child(bolt)
	Models.asset_mesh(bolt, asset, "Bolt")
	# The scope on its two mounts: its flared body, the rims round the eyepiece and the objective,
	# the adjusters' caps, the objective lens and the reticle on the eyepiece's lens.
	var scope := _scope_mat()
	var eye_z := scope_eye_z()
	var back := SCOPE_EYEPIECE_Z
	var front := back - SCOPE_LENGTH
	var r_front := SCOPE_RADIUS * (eye_z - front) / (eye_z - back)
	for z: float in [0.02, 0.05]:
		var r := SCOPE_RADIUS * (eye_z - z) / (eye_z - back)
		var top := sy - r + 0.002
		_box(root, Vector3(0, (0.033 + top) * 0.5, z), Vector3(0.016, top - 0.033, 0.012), m["dark"])
	_tube(root, Vector3(0, sy, (back + front) * 0.5), SCOPE_RADIUS, r_front, SCOPE_LENGTH, scope)
	_ring(root, Vector3(0, sy, back), SCOPE_RADIUS, SCOPE_RADIUS + 0.0034, scope, 24)
	_ring(root, Vector3(0, sy, front), r_front, r_front + 0.0035, scope, 24)
	_cyl(root, Vector3(0, sy + 0.029, 0.045), 0.006, 0.01, m["dark"], Vector3.ZERO)
	_cyl(root, Vector3(0.029, sy, 0.045), 0.006, 0.01, m["dark"], Vector3(0, 0, 90))
	_cyl(root, Vector3(0, sy, front - 0.0005), r_front, 0.001, Models.glass(Color(0.3, 0.5, 0.6, 0.06)))
	var lens := MeshInstance3D.new()
	var lq := QuadMesh.new()
	lq.size = Vector2(SCOPE_RADIUS * 2.05, SCOPE_RADIUS * 2.05)
	lens.mesh = lq
	lens.material_override = reticle_material()
	lens.position = Vector3(0, sy, back + 0.0003)
	root.add_child(lens)
	parts["mag"] = mag
	parts["slide"] = bolt
	parts["travel"] = Vector3(0, 0, 0.07)
	parts["port"] = Vector3(0.027, 0.02, -0.03)
	parts["eye"] = Vector3(0, sy, scope_eye_z())
	parts["front"] = Vector3(0, sy, SCOPE_EYEPIECE_Z + 0.0003)
	parts["display_at"] = [Vector3(0, 0.042, 0.08), Vector3(0, 0.45, 1.0), Vector2(0.028, 0.014)]


## Where the eye is (Z, the scope's frame) when aiming the marksman rifle: SCOPE_RELIEF behind the
## eyepiece.
static func scope_eye_z() -> float:
	return SCOPE_EYEPIECE_Z + SCOPE_RELIEF


## The scope's dark matte metal (the tube is open: inside it nothing shows).
static func _scope_mat() -> StandardMaterial3D:
	if not _cache.has("scope"):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.035, 0.036, 0.04)
		mat.metallic = 0.45
		mat.roughness = 0.55
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_cache["scope"] = mat
	return _cache["scope"]


## The marksman scope's reticle (RETICLE_SHADER), shared.
static func reticle_material() -> ShaderMaterial:
	if not _cache.has("reticle"):
		var mat := ShaderMaterial.new()
		var sh := Shader.new()
		sh.code = RETICLE_SHADER
		mat.shader = sh
		_cache["reticle"] = mat
	return _cache["reticle"]


## A pistol-grip pump shotgun fed from a box magazine (no stock), a Blender-made model: the pump runs
## back and forward after every shot and throws the shell out; a bead (made here) on a post at the
## muzzle and a ghost ring at the back to aim with.
static func _build_shotgun(root: Node3D, parts: Dictionary, m: Dictionary) -> void:
	var asset := "weapon_shotgun"
	Models.asset_mesh(root, asset, "Body", {"Accent": m["accent"]})
	Models.sphere(root, Vector3(0, 0.074, -0.468), 0.0035, Models.emissive(Color(1.0, 0.75, 0.35), 2.0), Vector3.ONE, 8)
	var pump := Node3D.new()
	pump.name = "Pump"
	root.add_child(pump)
	Models.asset_mesh(pump, asset, "Pump")
	var mag := Node3D.new()
	mag.name = "Mag"
	mag.position = Vector3(0, -0.04, -0.05)
	root.add_child(mag)
	Models.asset_mesh(mag, asset, "Mag")
	parts["mag"] = mag
	parts["slide"] = pump
	parts["travel"] = Vector3(0, 0, 0.075)
	parts["port"] = Vector3(0.034, 0.02, -0.01)
	parts["eye"] = Vector3(0, 0.074, 0.45)
	parts["front"] = Vector3(0, 0.074, -0.468)
	parts["display_at"] = [Vector3(0, 0.0505, 0.13), Vector3(0, 0.42, 1.0), Vector2(0.03, 0.014)]


## The multiple grenade launcher, a Blender-made model: a revolving cylinder of six 40 mm grenades
## between the plates of a heavy frame, a short wide barrel with a foregrip under it, a pistol grip,
## and a WW2-style ring sight (a ring with cross wires up front, a glowing bead at the back, made
## here). The cylinder turns a chamber after every shot (the rounds' noses show in the chambers'
## mouths until they are fired); to reload it swings out to the left on its crane, the six spent
## cases tumble out of the back and six new rounds slide in.
static func _build_mgl(root: Node3D, parts: Dictionary, m: Dictionary) -> void:
	var asset := "weapon_mgl"
	var bore := 0.03
	var axis := bore - 0.046
	Models.asset_mesh(root, asset, "Body", {"Accent": m["accent"]})
	Models.sphere(root, Vector3(0, 0.125, 0.06), 0.0035, m["tritium"], Vector3.ONE, 8)
	# The crane (pivoting low on the left), the cylinder on it, and its six rounds ("mag": their
	# bases at the back, a nose in each chamber's mouth).
	var crane := Node3D.new()
	crane.name = "Crane"
	crane.position = Vector3(-0.02, axis - 0.05, -0.015)
	root.add_child(crane)
	Models.asset_mesh(crane, asset, "Crane")
	var cyl := Node3D.new()
	cyl.name = "Cylinder"
	cyl.position = Vector3(0.02, 0.05, 0)
	crane.add_child(cyl)
	Models.asset_mesh(cyl, asset, "Cylinder")
	var rounds := Node3D.new()
	rounds.name = "Mag"
	cyl.add_child(rounds)
	Models.asset_mesh(rounds, asset, "Rounds")
	var noses: Array[Node3D] = []
	var chambers: Array[Vector2] = []
	for k in 6:
		var a := PI * 0.5 + k * TAU / 6.0
		var at := Vector2(cos(a), sin(a)) * 0.046
		chambers.append(at)
		var nose := Node3D.new()
		nose.position = Vector3(at.x, at.y, -0.0648)
		rounds.add_child(nose)
		Models.asset_mesh(nose, asset, "Nose")
		noses.append(nose)
	parts["mag"] = rounds
	parts["noses"] = noses
	parts["chambers"] = chambers
	parts["crane"] = crane
	parts["cylinder"] = cyl
	parts["port"] = Vector3(-0.06, axis, 0.06)
	parts["eye"] = Vector3(0, 0.125, 0.5)
	parts["front"] = Vector3(0, 0.125, -0.1)
	parts["display_at"] = [Vector3(0, 0.035, 0.085), Vector3(0, 0.42, 1.0), Vector2(0.034, 0.017)]


## The Storm Lance, a Blender-made model: a body with capacitor cans, a copper rod wound with coils
## (they glow as it charges), and a fork of two prongs the bolt leaps from; a ring and notch to aim
## with, and a hatch on top that opens to vent.
static func _build_lightning(root: Node3D, parts: Dictionary, m: Dictionary) -> void:
	var asset := "weapon_lightning"
	var col: Color = DEFS["lightning"]["color"]
	var glow := _glow_mat(parts, col, 0.25)
	Models.asset_mesh(root, asset, "Body", {"Accent": m["accent"], "Glow": glow})
	var vent := Node3D.new()
	vent.name = "Vent"
	vent.position = Vector3(0, 0.0485, 0.02)
	root.add_child(vent)
	Models.asset_mesh(vent, asset, "Vent")
	parts["vent"] = vent
	parts["prongs"] = [Vector3(-0.026, 0, -0.448), Vector3(0.026, 0, -0.448)]
	parts["eye"] = Vector3(0, 0.1, 0.48)
	parts["front"] = Vector3(0, 0.1, -0.15)
	parts["display_at"] = [Vector3(0, 0.058, 0.168), Vector3(0, 0.42, 1.0), Vector2(0.034, 0.017)]


## The muzzle flash (hidden until a shot): the gun pods' flame blades, small, and a light. A
## weapon's "flash" [size, glow, light energy] tones it down (the fast-firing ones, whose flash
## would otherwise hide what they shoot at); the others are FLASH_SIZES big, glowing at 5.
static func _build_flash(root: Node3D, parts: Dictionary, id: String) -> void:
	var d := def(id)
	var fl: Array = d.get("flash", [FLASH_SIZES.get(id, 0.34), 5.0, 2.4])
	var flash := Node3D.new()
	flash.name = "Flash"
	flash.position = parts["muzzle"]
	flash.visible = false
	root.add_child(flash)
	if id != "lightning":
		var mi := MeshInstance3D.new()
		mi.mesh = GunPod.flash_mesh()
		mi.material_override = flash_material(d["color"] if uses_heat(id) else Color(1.0, 0.62, 0.25), float(fl[1]))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.scale = Vector3.ONE * float(fl[0])
		flash.add_child(mi)
	var light := OmniLight3D.new()
	light.light_color = d["color"] if uses_heat(id) else Color(1.0, 0.7, 0.35)
	light.omni_range = 4.5
	light.light_energy = float(fl[2])
	light.position = Vector3(0, 0, -0.05)
	flash.add_child(light)
	parts["flash"] = flash


## The flash's material in a colour and glow (shared).
static func flash_material(col: Color, energy := 5.0) -> ShaderMaterial:
	var key := "flash%s|%.2f" % [col.to_html(), energy]
	if not _cache.has(key):
		var mat := GunPod.flash_material().duplicate() as ShaderMaterial
		mat.set_shader_parameter("color", Color(col.r, col.g, col.b))
		mat.set_shader_parameter("energy", energy)
		_cache[key] = mat
	return _cache[key]


## The display built into the weapon, Halo style: a small green screen on the top of the gun at the
## back, turned to the shooter under a hood, in a housing that is part of the gun. Seen from the hip
## and just under the sight when aiming. First person it shows the rounds left (or the heat on a
## bar, for heat weapons); third person it is only a dim screen. The screen's parts carry the
## "screen" meta (the tests check nothing on the gun hides them).
static func _build_display(root: Node3D, parts: Dictionary, id: String, first_person: bool) -> void:
	var at: Array = parts["display_at"]
	var size: Vector2 = at[2]
	var f := facing(at[0], at[1])
	var housing := Models.mat(Color(0.1, 0.105, 0.11), 0.55, 0.5)
	var w := size.x
	var h := size.y
	# The housing: a block behind the screen that runs down into the gun, a hood over the screen,
	# cheeks either side (flush with the screen, so they never hide its edge from the side) and a lip
	# under it.
	for piece: Array in [[Vector3(0, -0.012, -0.0095), Vector3(w + 0.008, h + 0.03, 0.018)],
			[Vector3(0, h * 0.5 + 0.0028, 0.0035), Vector3(w + 0.008, 0.0024, 0.013)],
			[Vector3(-(w * 0.5 + 0.0022), 0.0005, -0.0008), Vector3(0.0024, h + 0.005, 0.0024)],
			[Vector3(w * 0.5 + 0.0022, 0.0005, -0.0008), Vector3(0.0024, h + 0.005, 0.0024)],
			[Vector3(0, -(h * 0.5 + 0.0018), -0.0004), Vector3(w + 0.008, 0.0024, 0.0016)]]:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = piece[1]
		mi.mesh = bm
		mi.material_override = housing
		mi.transform = f * Transform3D(Basis.IDENTITY, piece[0])
		root.add_child(mi)
	var screen := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	screen.mesh = q
	screen.material_override = GunPod.crt_material() if first_person else Models.emissive(Color(0.15, 0.5, 0.2), 0.6, Color(0.01, 0.03, 0.015))
	screen.transform = f * Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.0004))
	screen.set_meta("screen", true)
	root.add_child(screen)
	var disp := {"screen": screen, "frame": f}
	parts["display"] = disp
	if not first_person:
		return
	var small := 22
	if uses_heat(id):
		disp["caption"] = _label(root, f, Vector3(-w * 0.5 + 0.0016, h * 0.5 - 0.0036, 0.0009), "HEAT", small, h * 0.26, -1.0)
		disp["state"] = _label(root, f, Vector3(w * 0.5 - 0.0016, h * 0.5 - 0.0036, 0.0009), "READY", small, h * 0.26, 1.0)
		disp["value"] = _label(root, f, Vector3(w * 0.5 - 0.0016, -0.0018, 0.0009), "0%", 40, h * 0.42, 1.0)
		var bar := Cockpit.bar_mesh(Vector2(w * 0.55, h * 0.26), 10, false, 0.0, 0.6, 0.85)
		bar.transform = f * Transform3D(Basis.IDENTITY, Vector3(-w * 0.2, -h * 0.24, 0.0008))
		bar.set_meta("screen", true)
		root.add_child(bar)
		disp["bar"] = bar
	else:
		disp["caption"] = _label(root, f, Vector3(-w * 0.5 + 0.0016, h * 0.5 - 0.0036, 0.0009), "GRN" if id == "mgl" else "RDS", small, h * 0.26, -1.0)
		disp["state"] = _label(root, f, Vector3(-w * 0.5 + 0.0016, -h * 0.5 + 0.0036, 0.0009), "", small, h * 0.26, -1.0)
		disp["value"] = _label(root, f, Vector3(w * 0.5 - 0.0014, -0.0006, 0.0009), "%02d" % mag(id), 64, h * 0.72, 1.0)


## A frame at `pos` whose +Z faces along `dir` (upright where it can be), for text facing that way.
static func facing(pos: Vector3, dir: Vector3) -> Transform3D:
	var z := dir.normalized()
	var up := Vector3.UP if absf(z.y) < 0.95 else Vector3.BACK
	var x := up.cross(z).normalized()
	return Transform3D(Basis(x, z.cross(x), z), pos)


## Text in the terminals' monospace face, `height` tall (m), anchored at `pos` in frame `f` by its
## left edge (-1), middle (0) or right edge (1).
static func _label(root: Node3D, f: Transform3D, pos: Vector3, text: String, font_size: int, height: float, anchor: float) -> Label3D:
	var l := Label3D.new()
	l.font = GunPod.mono_font()
	l.font_size = font_size
	l.pixel_size = height / float(font_size)
	l.outline_size = 0
	l.modulate = GunPod.GREEN
	l.double_sided = false
	l.set_meta("anchor", anchor)
	l.set_meta("screen", true)
	l.transform = f * Transform3D(Basis.IDENTITY, pos)
	root.add_child(l)
	set_text(l, text)
	return l


## Change a display label's text, keeping it anchored where it was built.
static func set_text(l: Label3D, text: String) -> void:
	if l.text == text and not text.is_empty():
		return
	l.text = text
	var anchor := float(l.get_meta("anchor", 0.0))
	if anchor != 0.0:
		l.offset.x = -anchor * l.font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, l.font_size).x * 0.5


static func _no_shadows(n: Node) -> void:
	for c in n.get_children():
		if c is GeometryInstance3D:
			(c as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_no_shadows(c)


## The parts of a model built by build_model().
static func parts_of(model: Node3D) -> Dictionary:
	if model == null or not is_instance_valid(model) or not model.has_meta("parts"):
		return {}
	return model.get_meta("parts")


## Muzzle position in a crew member's local space (third person, ready).
static func held_muzzle(id: String) -> Vector3:
	return HELD_POS + (MUZZLES.get(id, MUZZLES[DEFAULT]) as Vector3)


# --- Casings -----------------------------------------------------------------------------------

## The mesh of a spent casing of `kind` (CASINGS): a case with its rim, lying along Y.
static func casing_mesh(kind: String) -> ArrayMesh:
	var key := "casing_" + kind
	if _cache.has(key):
		return _cache[key]
	var c: Array = CASINGS[kind]
	var r := float(c[0])
	var h := float(c[1])
	var mesh := ArrayMesh.new()
	var body := CylinderMesh.new()
	body.top_radius = r * (0.8 if kind == "rifle" or kind == "marksman" else 1.0)
	body.bottom_radius = r
	body.height = h * 0.86
	body.radial_segments = 8
	body.rings = 1
	var rim := CylinderMesh.new()
	rim.top_radius = r * 1.06
	rim.bottom_radius = r * 1.06
	rim.height = h * 0.14
	rim.radial_segments = 8
	rim.rings = 1
	var body_mat := Models.mat(c[2], 0.85 if kind != "shell" else 0.15, 0.3 if kind != "shell" else 0.55)
	var rim_mat := Models.mat(c[3], 0.85, 0.32)
	for pair: Array in [[body, Transform3D(Basis.IDENTITY, Vector3(0, h * 0.07, 0)), body_mat],
			[rim, Transform3D(Basis.IDENTITY, Vector3(0, -h * 0.43, 0)), rim_mat]]:
		var st := SurfaceTool.new()
		st.append_from(pair[0], 0, pair[1])
		st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, pair[2])
	_cache[key] = mesh
	return mesh


# --- Effects (every peer) ----------------------------------------------------------------------

## Tracers, impacts and the shot sound. `ends` holds one end point per pellet (world space),
## `normals` the surface normals there; bit i of `hit_mask` / `flesh_mask` says pellet i hit
## something / an alien. `local`: the shooter is the local crew member (they hear it in 2D: right at
## their ear a 3D sound would always play at its loudest); `pitch` raises the report (a heat weapon
## sounds hotter as it heats up). The heavy rounds (Marksman Rifle, Revolver, Shotgun) strike with
## bigger bursts of sparks and a thud into flesh.
static func shot_fx(id: String, from: Vector3, ends: PackedVector3Array, normals: PackedVector3Array, hit_mask: int, flesh_mask: int, local := false, pitch := 1.0) -> void:
	var d := def(id)
	var col: Color = d["color"]
	var flesh_any := false
	for i in ends.size():
		var hit := (hit_mask & (1 << i)) != 0
		var flesh := (flesh_mask & (1 << i)) != 0
		flesh_any = flesh_any or flesh
		var strengths := {"shotgun": 0.85, "rifle": 0.6, "smg": 0.6, "photon": 0.8, "revolver": 1.2, "marksman": 1.7}
		var strength := float(strengths.get(id, 1.0))
		var spark := Color(0.5, 0.95, 1.0) if id == "photon" else Color(1.0, 0.6, 0.3)
		var at := ends[i]
		var n := normals[i] if i < normals.size() else Vector3.UP
		var strike := func() -> void:
			Fx.impact(at, n, Color(0.6, 1.0, 0.3) if flesh else spark, strength * (1.2 if flesh else 1.0))
		match id:
			"marksman":
				Fx.tracer(from, ends[i], col, 0.014, 0.06)
			"photon":
				# A glowing bolt that flies to where the shot ends and strikes there.
				var b: Array = d["bolt"]
				Fx.bolt(from, ends[i], col, float(b[0]), float(b[1]), Game.mission.ship if Game.mission else null,
					strike if hit else Callable())
				hit = false
			"shotgun":
				Fx.tracer(from, ends[i], col, 0.008, 0.05)
			"rifle", "pistol", "smg", "revolver":
				# Only some rounds show a tracer, as with real ammunition.
				var share := {"rifle": 0.35, "smg": 0.3}
				if randf() < float(share.get(id, 0.5)):
					Fx.tracer(from, ends[i], col, 0.012, 0.045)
			_:
				Fx.tracer(from, ends[i], col, 0.02, 0.06)
		if hit:
			strike.call()
	if local:
		Sfx.play(str(d["sound"]), null, float(d["volume"]) - 5.0, float(d["pitch"]) * pitch)
	else:
		Sfx.play(str(d["sound"]), from, float(d["volume"]), float(d["pitch"]) * pitch)
	if flesh_any and ends.size() > 0:
		var heavy := id in ["marksman", "revolver", "shotgun"]
		Sfx.play("hit", ends[0], -4.0 if heavy else -8.0, 0.85 if heavy else 1.3)


## A lightning bolt along `points` (world space: the emitter, then every alien it jumped to; or the
## emitter and where it struck the wall). `charge` (0..1) makes it thicker and louder; `hits` how
## many of the points after the first are aliens; `local`: the local crew member let it go. It
## flickers: drawn three times with fresh zigzags, with a white-hot core, and every point it strikes
## flares and bursts into sparks; where it first strikes it cracks like thunder.
static func lightning_fx(points: PackedVector3Array, charge: float, hits: int, local := false) -> void:
	if points.size() < 2:
		return
	var col: Color = DEFS["lightning"]["color"]
	var width := lerpf(0.02, 0.05, charge)
	_bolt(points, col, width, 0.11)
	_bolt(points, Color(0.92, 0.97, 1.0), width * 0.35, 0.09)
	var r := Fx._root()
	if r:
		r.get_tree().create_timer(0.05).timeout.connect(func(): _bolt(points, col, width * 0.75, 0.08))
		r.get_tree().create_timer(0.1).timeout.connect(func(): _bolt(points, col, width * 0.5, 0.06))
	for i in range(1, points.size()):
		var flesh := i <= hits
		Fx.flash(points[i], col, 6.0 if flesh else 4.0, 9.0, 0.22)
		Fx.sparks(points[i], Color(0.75, 0.92, 1.0), 22 if flesh else 14, 8.0, 0.04, 0.45)
		Sfx.play("zap_hit", points[i], -3.0 if flesh else -6.0, randf_range(0.85, 1.05))
	Fx.flash(points[0], col, 6.0, 7.0, 0.16)
	Sfx.play("thunder", points[1], lerpf(-4.0, 1.0, charge), lerpf(1.15, 0.9, charge))
	if local:
		Sfx.play("zap", null, float(DEFS["lightning"]["volume"]) - 2.0, lerpf(1.05, 0.85, charge))
	else:
		Sfx.play("zap", points[0], float(DEFS["lightning"]["volume"]) + 2.0, lerpf(1.05, 0.85, charge))


## One drawing of a bolt: a jagged line between each pair of points, with short forks off it.
static func _bolt(points: PackedVector3Array, col: Color, width: float, life: float) -> void:
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		var d := b - a
		var length := d.length()
		if length < 0.05:
			continue
		var side := d.cross(Vector3.UP if absf(d.normalized().y) < 0.9 else Vector3.RIGHT).normalized()
		var up := side.cross(d).normalized()
		var steps := clampi(int(length / 0.6), 3, 14)
		var prev := a
		for k in range(1, steps + 1):
			var t := float(k) / steps
			var p := a.lerp(b, t)
			if k < steps:
				var amp := length * 0.07 * sin(t * PI)
				p += side * randf_range(-amp, amp) + up * randf_range(-amp, amp)
			Fx.tracer(prev, p, col, width, life)
			if k < steps and randf() < 0.3:
				var fork := p + (side * randf_range(-1.0, 1.0) + up * randf_range(-1.0, 1.0) + d.normalized() * 0.5).normalized() * length * randf_range(0.08, 0.18)
				Fx.tracer(p, fork, col, width * 0.45, life * 0.8)
			prev = p
