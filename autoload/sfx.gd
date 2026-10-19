extends Node
## Procedurally synthesised sound effects, so the game ships without audio files.
##
## Sounds are generated once at startup from small recipes (swept oscillators plus filtered
## noise) and played through pooled 2D/3D players. Looping sounds are fetched with stream().
##
## Sounds reach a listener who is shut in muffled when they come from outside: from inside the
## mothership (walking about or at any of its stations) through the hull, from a gun pod or a scout's
## cockpit through the glass. Each 3D sound goes through the bus for where it is and where the
## listener is (bus_for): the pooled players' and those of the sounds out in the world handed to
## track() (engines, lasers, bulkhead doors...) are re-routed every frame.

const RATE := 22050
const POOL_3D := 28
const POOL_2D := 8
## The muffling buses: a low-pass (cutoff in Hz) and a level (dB) for sounds heard through the
## mothership's hull, and lighter ones for sounds heard through glass.
const HULL_BUS := &"Hull"
const GLASS_BUS := &"Glass"
const HULL_CUTOFF := 600.0
const HULL_DB := -5.0
const GLASS_CUTOFF := 1500.0
const GLASS_DB := -2.0
## A sound this close to a gun pod's ball (m) is in the pod, this close to a flying scout in it.
const POD_REACH := 1.4
const SCOUT_REACH := 3.0
## Group of the world's sound players whose bus follows the listener (see track()).
const TRACKED := &"sfx_tracked"

var _streams: Dictionary = {}
var _pool3d: Array[AudioStreamPlayer3D] = []
var _pool2d: Array[AudioStreamPlayer] = []
var _next3d := 0
var _next2d := 0
var _rng := RandomNumberGenerator.new()
## Where the local listener is shut in (see listener_space()), worked out once a frame.
var _listener := ""


func _ready() -> void:
	_build_sounds()
	_add_bus(HULL_BUS, HULL_CUTOFF, HULL_DB)
	_add_bus(GLASS_BUS, GLASS_CUTOFF, GLASS_DB)
	for i in POOL_3D:
		var p := AudioStreamPlayer3D.new()
		p.max_distance = 260.0
		p.unit_size = 14.0
		add_child(p)
		_pool3d.append(p)
	for i in POOL_2D:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool2d.append(p)


func _process(_delta: float) -> void:
	_listener = listener_space()
	for p in _pool3d:
		if p.playing:
			_route(p)
	for n in get_tree().get_nodes_in_group(TRACKED):
		var p := n as AudioStreamPlayer3D
		if p and p.is_inside_tree():
			_route(p)


## Play a one-shot sound. With a position it is spatialised, otherwise it plays in 2D.
func play(id: String, pos: Variant = null, volume_db := 0.0, pitch := 1.0) -> void:
	if not _streams.has(id):
		return
	var variation := _rng.randf_range(0.94, 1.06)
	if pos is Vector3:
		var p := _pool3d[_next3d]
		_next3d = (_next3d + 1) % _pool3d.size()
		p.stream = _streams[id]
		p.global_position = pos
		p.volume_db = volume_db
		p.pitch_scale = pitch * variation
		_route(p)
		p.play()
	else:
		var p := _pool2d[_next2d]
		_next2d = (_next2d + 1) % _pool2d.size()
		p.stream = _streams[id]
		p.volume_db = volume_db
		p.pitch_scale = pitch * variation
		p.play()


func stream(id: String) -> AudioStream:
	return _streams.get(id)


# --- Muffling ----------------------------------------------------------------------------------

## Hand a sound player out in the world to the muffling: its bus then follows the listener.
func track(p: AudioStreamPlayer3D) -> void:
	p.add_to_group(TRACKED)


## Where the local listener is shut in: "ship" (aboard the mothership, walking or at a station),
## "pod:<station>" (in a gun pod), "scout:<index>" (flying a scout), or "" (out in the open, or
## knocked out).
func listener_space() -> String:
	var m := Game.mission as MissionLevel
	if m == null or m.ship == null or m.local_player == null:
		return ""
	var lp := m.local_player
	if not lp.alive or not m.ship.alive:
		return ""
	if lp.station != "":
		match m.ship.station_kind(lp.station):
			"gun":
				return "pod:" + lp.station
			"scout":
				var sc := m.scout_at(lp.station)
				if sc and sc.state == Scout.State.FLYING:
					return "scout:%d" % sc.index
		return "ship"
	return "ship" if m.ship.is_aboard(lp.position) else ""


## Where a sound at `pos` is, in the same terms as listener_space(): aboard the mothership, in a
## gun pod, at a flying scout, or outside ("").
func space_of(pos: Vector3) -> String:
	var m := Game.mission as MissionLevel
	if m == null or m.ship == null:
		return ""
	var ship := m.ship
	if ship.is_aboard(ship.to_local(pos)):
		return "ship"
	for id: String in ship.gun_stations():
		var pod := ship.turrets.get(id) as Node3D
		if pod and pod.global_position.distance_to(pos) < POD_REACH:
			return "pod:" + id
	for sc in m.flying_scouts():
		if sc.global_position.distance_to(pos) < SCOUT_REACH:
			return "scout:%d" % sc.index
	return ""


## The bus a sound at `pos` plays through: straight to Master where the listener is, muffled through
## the hull (listener aboard the mothership) or the glass (in a gun pod or a scout) from elsewhere.
func bus_for(pos: Vector3) -> StringName:
	if _listener == "" or space_of(pos) == _listener:
		return &"Master"
	return HULL_BUS if _listener == "ship" else GLASS_BUS


func _route(p: AudioStreamPlayer3D) -> void:
	var bus := bus_for(p.global_position)
	if p.bus != bus:
		p.bus = bus


func _add_bus(bus_name: StringName, cutoff: float, db: float) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var i := AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, bus_name)
	AudioServer.set_bus_send(i, &"Master")
	AudioServer.set_bus_volume_db(i, db)
	var lp := AudioEffectLowPassFilter.new()
	lp.cutoff_hz = cutoff
	AudioServer.add_bus_effect(i, lp)


# --- Recipes -----------------------------------------------------------------------------------

func _build_sounds() -> void:
	_add("pulse", 0.16, {"wave": "sine", "f0": 1500.0, "f1": 240.0, "tone": 0.7, "noise": 0.12, "lp0": 0.4, "lp1": 0.1, "decay": 2.0})
	_add("flak", 0.24, {"wave": "sine", "f0": 180.0, "f1": 55.0, "tone": 0.35, "noise": 0.95, "lp0": 0.3, "lp1": 0.04, "decay": 2.4})
	_add("plasma", 0.42, {"wave": "sine", "f0": 440.0, "f1": 110.0, "tone": 0.8, "noise": 0.12, "lp0": 0.2, "lp1": 0.05, "vib_f": 28.0, "vib_a": 0.15, "decay": 1.5})
	_add("rail", 0.38, {"wave": "saw", "f0": 2600.0, "f1": 260.0, "tone": 0.45, "noise": 0.45, "lp0": 0.8, "lp1": 0.08, "decay": 3.0})
	_add("blaster", 0.13, {"wave": "square", "f0": 950.0, "f1": 210.0, "tone": 0.4, "noise": 0.12, "lp0": 0.5, "lp1": 0.2, "decay": 2.0})
	_add("hit", 0.07, {"noise": 0.85, "lp0": 0.7, "lp1": 0.3, "decay": 3.0})
	_add("explosion", 1.5, {"wave": "sine", "f0": 75.0, "f1": 28.0, "tone": 0.45, "noise": 1.0, "lp0": 0.16, "lp1": 0.015, "decay": 1.8, "gain": 1.0})
	_add("small_explosion", 0.6, {"wave": "sine", "f0": 110.0, "f1": 40.0, "tone": 0.35, "noise": 1.0, "lp0": 0.25, "lp1": 0.04, "decay": 2.0})
	_add("spit", 0.32, {"wave": "sine", "f0": 280.0, "f1": 560.0, "tone": 0.4, "noise": 0.6, "lp0": 0.35, "lp1": 0.12, "vib_f": 18.0, "vib_a": 0.3, "decay": 1.5})
	_add("shield_hit", 0.45, {"wave": "sine", "f0": 260.0, "f1": 170.0, "tone": 0.6, "noise": 0.25, "lp0": 0.6, "lp1": 0.1, "vib_f": 11.0, "vib_a": 0.08, "decay": 2.0})
	_add("hull_hit", 0.36, {"wave": "sine", "f0": 120.0, "f1": 42.0, "tone": 0.9, "noise": 0.55, "lp0": 0.18, "lp1": 0.04, "decay": 2.4})
	_add("pickup", 0.18, {"wave": "sine", "f0": 700.0, "f1": 1500.0, "tone": 0.55, "decay": 1.2})
	_add("fuel_pickup", 0.28, {"wave": "tri", "f0": 380.0, "f1": 980.0, "tone": 0.6, "decay": 1.3})
	_add("repair", 0.22, {"wave": "square", "f0": 1700.0, "f1": 1500.0, "tone": 0.12, "noise": 0.5, "lp0": 0.7, "lp1": 0.5, "gate_f": 28.0, "decay": 0.8})
	_add("screech", 0.55, {"wave": "saw", "f0": 900.0, "f1": 650.0, "tone": 0.3, "noise": 0.2, "lp0": 0.5, "lp1": 0.3, "vib_f": 38.0, "vib_a": 0.22, "decay": 1.0})
	_add("ui", 0.05, {"wave": "sine", "f0": 1300.0, "f1": 1100.0, "tone": 0.4, "decay": 2.0})
	_add("dock", 0.45, {"wave": "sine", "f0": 160.0, "f1": 85.0, "tone": 0.7, "noise": 0.45, "lp0": 0.3, "lp1": 0.05, "decay": 2.5})
	_add("launch", 0.8, {"noise": 0.8, "lp0": 0.04, "lp1": 0.35, "wave": "sine", "f0": 120.0, "f1": 260.0, "tone": 0.25, "attack": 0.25, "decay": 1.2})
	_add("egg_burst", 0.55, {"wave": "sine", "f0": 220.0, "f1": 70.0, "tone": 0.5, "noise": 0.8, "lp0": 0.3, "lp1": 0.05, "decay": 1.8})
	_add("breach", 0.8, {"wave": "saw", "f0": 320.0, "f1": 190.0, "tone": 0.35, "noise": 0.5, "lp0": 0.4, "lp1": 0.15, "vib_f": 55.0, "vib_a": 0.3, "decay": 1.2})
	_add("death", 1.0, {"wave": "sine", "f0": 420.0, "f1": 55.0, "tone": 0.6, "noise": 0.2, "lp0": 0.2, "lp1": 0.05, "decay": 1.2})
	_add("scratch", 0.25, {"noise": 0.7, "lp0": 0.9, "lp1": 0.6, "gate_f": 45.0, "wave": "saw", "f0": 2400.0, "f1": 1800.0, "tone": 0.1, "decay": 1.0})
	_add("blast", 1.6, {"wave": "saw", "f0": 1800.0, "f1": 35.0, "tone": 0.5, "noise": 1.0, "lp0": 0.6, "lp1": 0.02, "vib_f": 45.0, "vib_a": 0.15, "decay": 1.4, "gain": 1.0})
	_add("servo", 1.4, {"wave": "saw", "f0": 120.0, "f1": 170.0, "tone": 0.3, "noise": 0.35, "lp0": 0.1, "lp1": 0.16, "vib_f": 9.0, "vib_a": 0.05, "attack": 0.15, "decay": 0.7})
	_add("install", 0.7, {"wave": "tri", "f0": 520.0, "f1": 1040.0, "tone": 0.6, "noise": 0.15, "lp0": 0.6, "lp1": 0.4, "decay": 1.4})
	# Hand weapons: the pistol's crack, the revolver's deeper bark, the submachine gun's short sharp
	# rap, the pulse rifle's bark, the photon rifle's humming snap, the marksman rifle's heavy crack
	# falling into a boom, the shotgun's boom and the grenade launcher's hollow thump; the lightning
	# thrower's bolt cracking and crackling where it strikes (and the thunder where it first hits), and
	# the hum of its charge (pitched up as it charges, see CrewMember).
	_add("pistol", 0.22, {"wave": "square", "f0": 520.0, "f1": 80.0, "tone": 0.4, "noise": 1.0, "lp0": 0.85, "lp1": 0.06, "decay": 3.2, "gain": 1.0})
	_add("revolver", 0.36, {"wave": "square", "f0": 360.0, "f1": 50.0, "tone": 0.45, "tone_lp": 0.5, "noise": 1.0, "lp0": 0.82, "lp1": 0.04,
		"decay": 2.5, "gain": 1.0})
	_add("smg", 0.12, {"wave": "square", "f0": 460.0, "f1": 85.0, "tone": 0.35, "noise": 1.0, "lp0": 0.8, "lp1": 0.08, "decay": 4.4, "gain": 1.0})
	_add("rifle", 0.16, {"wave": "square", "f0": 400.0, "f1": 70.0, "tone": 0.35, "noise": 1.0, "lp0": 0.8, "lp1": 0.07, "decay": 3.8, "gain": 1.0})
	_add("photon", 0.17, {"wave": "saw", "f0": 1300.0, "f1": 240.0, "tone": 1.0, "tone_lp": 0.3, "harm": 0.35, "noise": 0.7, "lp0": 0.6,
		"lp1": 0.15, "vib_f": 40.0, "vib_a": 0.05, "attack": 0.002, "decay": 2.6, "gain": 1.0})
	_add("marksman", 0.5, {"wave": "square", "f0": 260.0, "f1": 40.0, "tone": 0.5, "tone_lp": 0.35, "noise": 1.0, "lp0": 0.72, "lp1": 0.035,
		"decay": 2.2, "gain": 1.0})
	_add("shotgun", 0.45, {"wave": "sine", "f0": 140.0, "f1": 42.0, "tone": 0.7, "noise": 1.0, "lp0": 0.75, "lp1": 0.03, "decay": 2.3, "gain": 1.0})
	_add("mgl", 0.3, {"wave": "sine", "f0": 170.0, "f1": 65.0, "tone": 0.9, "harm": 0.2, "noise": 0.55, "lp0": 0.3, "lp1": 0.05,
		"attack": 0.001, "decay": 3.0, "gain": 1.0})
	_add("thunder", 0.9, {"wave": "sine", "f0": 95.0, "f1": 36.0, "tone": 0.7, "noise": 1.0, "lp0": 0.65, "lp1": 0.02, "attack": 0.0006,
		"decay": 2.2, "gain": 1.0})
	_add("zap", 0.4, {"wave": "saw", "f0": 2800.0, "f1": 300.0, "tone": 0.35, "tone_lp": 0.5, "noise": 1.0, "lp0": 0.95, "lp1": 0.2, "gate_f": 70.0,
		"attack": 0.001, "decay": 2.2, "gain": 1.0})
	_add("zap_hit", 0.22, {"noise": 1.0, "lp0": 0.9, "lp1": 0.4, "gate_f": 90.0, "wave": "saw", "f0": 1600.0, "f1": 500.0, "tone": 0.25,
		"tone_lp": 0.5, "decay": 3.0})
	_add("charge_loop", 1.0, {"wave": "saw", "f0": 110.0, "f1": 110.0, "tone": 0.3, "harm": 0.4, "tone_lp": 0.25, "noise": 0.25, "lp0": 0.5,
		"lp1": 0.5, "trem_f": 30.0, "trem_a": 0.3, "decay": 0.0, "gain": 0.7}, true)
	# Magazine swaps: the old magazine coming out, the new one clicking home, the slide or bolt racked
	# and the shotgun's pump; spent casings, shotgun shells and a magazine landing on the floor; the
	# ring as the last round leaves a magazine and the hollow tick of the last few; and the hollow
	# click of the hammer on an empty magazine.
	_add("mag_out", 0.14, {"wave": "square", "f0": 900.0, "f1": 500.0, "tone": 0.2, "tone_lp": 0.4, "noise": 0.7, "lp0": 0.85, "lp1": 0.35, "decay": 3.2})
	_add("mag_in", 0.1, {"wave": "square", "f0": 1300.0, "f1": 380.0, "tone": 0.3, "tone_lp": 0.4, "noise": 0.9, "lp0": 0.95, "lp1": 0.3,
		"attack": 0.001, "decay": 4.5, "gain": 1.0})
	_add("rack", 0.2, {"wave": "square", "f0": 1600.0, "f1": 600.0, "tone": 0.3, "tone_lp": 0.4, "noise": 0.9, "lp0": 0.9, "lp1": 0.4, "gate_f": 9.0,
		"attack": 0.001, "decay": 2.5, "gain": 1.0})
	_add("pump", 0.3, {"noise": 0.8, "lp0": 0.6, "lp1": 0.3, "wave": "square", "f0": 420.0, "f1": 260.0, "tone": 0.25, "tone_lp": 0.3, "gate_f": 6.0,
		"attack": 0.002, "decay": 1.6, "gain": 0.9})
	_add("casing", 0.14, {"wave": "sine", "f0": 3100.0, "f1": 2850.0, "tone": 0.5, "harm": 0.35, "noise": 0.15, "lp0": 0.9, "lp1": 0.6,
		"attack": 0.0005, "decay": 7.0})
	_add("shell_drop", 0.1, {"wave": "sine", "f0": 1250.0, "f1": 900.0, "tone": 0.45, "harm": 0.2, "noise": 0.4, "lp0": 0.5, "lp1": 0.3,
		"attack": 0.0005, "decay": 6.0})
	_add("mag_drop", 0.28, {"wave": "square", "f0": 300.0, "f1": 190.0, "tone": 0.3, "tone_lp": 0.3, "noise": 0.7, "lp0": 0.5, "lp1": 0.12,
		"attack": 0.0008, "decay": 3.4, "gain": 1.0})
	_add("mag_ping", 0.35, {"wave": "sine", "f0": 2300.0, "f1": 2250.0, "tone": 0.45, "harm": 0.3, "noise": 0.15, "lp0": 0.9, "lp1": 0.6,
		"attack": 0.0008, "decay": 3.5})
	_add("low_ammo", 0.06, {"wave": "sine", "f0": 900.0, "f1": 700.0, "tone": 0.4, "noise": 0.4, "lp0": 0.8, "lp1": 0.4, "attack": 0.0005, "decay": 6.0})
	_add("dry_fire", 0.1, {"wave": "sine", "f0": 620.0, "f1": 430.0, "tone": 0.55, "harm": 0.4, "noise": 0.5, "lp0": 0.95, "lp1": 0.2,
		"attack": 0.0005, "decay": 5.5})
	# Cylinders: the revolver's (or the grenade launcher's) cylinder swinging out on its crane and
	# snapping shut, and a moon clip of spent cases landing (a jangle).
	_add("cyl_open", 0.08, {"wave": "square", "f0": 1500.0, "f1": 1000.0, "tone": 0.25, "tone_lp": 0.45, "noise": 0.75, "lp0": 0.9,
		"lp1": 0.4, "attack": 0.0008, "decay": 4.0})
	_add("cyl_close", 0.1, {"wave": "square", "f0": 1100.0, "f1": 420.0, "tone": 0.35, "tone_lp": 0.4, "noise": 0.9, "lp0": 0.95,
		"lp1": 0.3, "attack": 0.0006, "decay": 4.5, "gain": 1.0})
	_add("moonclip", 0.3, {"wave": "sine", "f0": 2700.0, "f1": 2500.0, "tone": 0.45, "harm": 0.3, "noise": 0.35, "lp0": 0.9, "lp1": 0.6,
		"gate_f": 45.0, "attack": 0.0005, "decay": 3.5})
	# Grenades: one clunking off a wall or the floor, and going off (a sharp bang falling into a
	# rumble).
	_add("grenade_bounce", 0.14, {"wave": "square", "f0": 480.0, "f1": 360.0, "tone": 0.25, "tone_lp": 0.35, "noise": 0.5, "lp0": 0.55,
		"lp1": 0.2, "attack": 0.0008, "decay": 4.5})
	_add("grenade_blast", 1.2, {"wave": "sine", "f0": 85.0, "f1": 30.0, "tone": 0.5, "noise": 1.0, "lp0": 0.35, "lp1": 0.015,
		"attack": 0.001, "decay": 1.9, "gain": 1.0})
	# Heat weapons: steam venting (a burst of it when overheated), the click as it is cold again, and
	# the fizzle of a trigger pulled while it is locked.
	_add("vent", 1.1, {"noise": 0.85, "lp0": 0.85, "lp1": 0.7, "trem_f": 14.0, "trem_a": 0.2, "attack": 0.03, "decay": 1.3})
	_add("overheat_vent", 1.6, {"noise": 1.0, "lp0": 0.9, "lp1": 0.6, "attack": 0.005, "decay": 1.1, "gain": 1.0})
	_add("vent_done", 0.18, {"wave": "sine", "f0": 1800.0, "f1": 1700.0, "tone": 0.35, "harm": 0.2, "noise": 0.3, "lp0": 0.9, "lp1": 0.5, "decay": 4.0})
	_add("fizzle", 0.25, {"noise": 0.7, "lp0": 0.7, "lp1": 0.4, "gate_f": 40.0, "wave": "saw", "f0": 300.0, "f1": 180.0, "tone": 0.2,
		"tone_lp": 0.4, "decay": 2.0})
	# The suit: the visor's motor, the hiss as it seals and as it opens; the scanner swinging up, its
	# ping (like a boat's radar), the blip of an alien painted on its screen, and the static it shows
	# aboard the ship.
	_add("visor_servo", 0.65, {"wave": "saw", "f0": 150.0, "f1": 210.0, "tone": 0.25, "tone_lp": 0.2, "noise": 0.25, "lp0": 0.2, "lp1": 0.25,
		"vib_f": 18.0, "vib_a": 0.02, "attack": 0.05, "decay": 0.6})
	_add("visor_seal", 0.6, {"noise": 0.8, "lp0": 0.75, "lp1": 0.5, "attack": 0.002, "decay": 2.4, "wave": "sine", "f0": 90.0, "f1": 60.0, "tone": 0.4})
	_add("visor_unseal", 0.5, {"noise": 0.9, "lp0": 0.85, "lp1": 0.5, "attack": 0.001, "decay": 2.0, "wave": "sine", "f0": 140.0, "f1": 80.0, "tone": 0.3})
	_add("scan_whirr", 0.3, {"wave": "saw", "f0": 260.0, "f1": 340.0, "tone": 0.2, "tone_lp": 0.3, "noise": 0.2, "lp0": 0.3, "lp1": 0.3,
		"attack": 0.02, "decay": 1.2})
	_add("scan_ping", 1.0, {"wave": "sine", "f0": 900.0, "f1": 880.0, "tone": 0.55, "harm": 0.12, "attack": 0.003, "decay": 2.6,
		"vib_f": 5.0, "vib_a": 0.004})
	_add("scan_blip", 0.12, {"wave": "sine", "f0": 1300.0, "f1": 1260.0, "tone": 0.5, "harm": 0.1, "attack": 0.002, "decay": 3.5})
	_add("scan_static", 1.0, {"noise": 0.6, "lp0": 0.7, "lp1": 0.7, "trem_f": 9.0, "trem_a": 0.35, "decay": 0.0, "gain": 0.6}, true)
	_add("alarm", 0.9, {"wave": "square", "f0": 660.0, "f1": 660.0, "tone": 0.3, "two_tone": 520.0, "decay": 0.0})
	# Gun pods: the heavy machine gun's bark (a crack falling into a thump; it rises in pitch as the
	# barrels heat up, see GunPod.HOT_PITCH), the old belt rattling out and the bolt slamming home
	# on a new one, the overheat buzzer, a hiss of the hot gun hurting the weapon systems, and the
	# pod's traversing motors.
	_add("hmg", 0.2, {"wave": "square", "f0": 150.0, "f1": 46.0, "tone": 0.45, "noise": 1.0, "lp0": 0.85, "lp1": 0.05, "decay": 3.4, "gain": 1.0})
	_add("belt_out", 1.1, {"wave": "square", "f0": 210.0, "f1": 140.0, "tone": 0.18, "noise": 0.75, "lp0": 0.5, "lp1": 0.3, "gate_f": 15.0, "decay": 0.6})
	_add("belt_in", 0.32, {"wave": "square", "f0": 700.0, "f1": 120.0, "tone": 0.35, "noise": 0.9, "lp0": 0.9, "lp1": 0.1, "decay": 4.0, "gain": 1.0})
	_add("overheat", 0.16, {"wave": "saw", "f0": 380.0, "f1": 380.0, "tone": 0.5, "noise": 0.1, "lp0": 0.6, "lp1": 0.6, "decay": 0.3})
	_add("sizzle", 0.6, {"noise": 0.75, "lp0": 0.95, "lp1": 0.85, "trem_f": 30.0, "trem_a": 0.5, "decay": 1.2})
	# The motors' low whine with a slow wobble (the first version's), its sawtooth low-passed (two
	# poles at about 550 Hz) and its rumble too (two poles at about 400 Hz), so it hums rather than
	# screeches.
	_add("pod_servo", 1.0, {"wave": "saw", "f0": 96.0, "f1": 96.0, "tone": 0.22, "harm": 0.35, "tone_lp": 0.145, "noise": 0.4,
		"lp0": 0.11, "lp1": 0.11, "noise_lp2": true, "vib_f": 7.0, "vib_a": 0.015, "decay": 0.0, "gain": 0.75}, true)
	# The cockpit: the ship's motion tracker pinging before an ambush, the klaxon when the hostility
	# surges, the hull grinding along rock, the thrust lever's notches, a toggle switch and the big
	# red button going down.
	_add("tracker", 0.32, {"wave": "sine", "f0": 1250.0, "f1": 1180.0, "tone": 0.6, "harm": 0.18, "attack": 0.003, "decay": 3.2})
	_add("klaxon", 1.3, {"wave": "saw", "f0": 150.0, "f1": 235.0, "tone": 0.55, "harm": 0.4, "noise": 0.12, "lp0": 0.35, "lp1": 0.3,
		"vib_f": 6.0, "vib_a": 0.02, "attack": 0.06, "decay": 0.9, "gain": 0.85})
	_add("scrape", 0.55, {"wave": "saw", "f0": 1350.0, "f1": 1050.0, "tone": 0.12, "noise": 0.9, "lp0": 0.5, "lp1": 0.25,
		"vib_f": 23.0, "vib_a": 0.08, "trem_f": 17.0, "trem_a": 0.6, "attack": 0.03, "decay": 1.1})
	_add("lever", 0.05, {"wave": "square", "f0": 1900.0, "f1": 1300.0, "tone": 0.25, "noise": 0.5, "lp0": 0.8, "lp1": 0.5, "decay": 3.0})
	_add("switch", 0.04, {"wave": "square", "f0": 2600.0, "f1": 2100.0, "tone": 0.3, "noise": 0.45, "lp0": 0.9, "lp1": 0.6, "decay": 3.5})
	_add("clunk", 0.32, {"wave": "sine", "f0": 150.0, "f1": 62.0, "tone": 0.7, "noise": 0.55, "lp0": 0.45, "lp1": 0.06, "decay": 2.6})
	# The scout: its cannons' bang, a missile dropping off its pylon and lighting up, the rocket's
	# roar in flight, the seeker's beeps while it locks on and its steady tone once locked, a dull
	# buzz when there is nothing to fire, the alarm while the hull is critical, the windscreen
	# cracking, and the booster kicking in and roaring.
	_add("scout_gun", 0.16, {"wave": "square", "f0": 260.0, "f1": 70.0, "tone": 0.35, "noise": 0.95, "lp0": 0.9, "lp1": 0.07, "decay": 3.8, "gain": 1.0})
	_add("missile_launch", 0.9, {"noise": 1.0, "lp0": 0.08, "lp1": 0.5, "wave": "saw", "f0": 90.0, "f1": 140.0, "tone": 0.2, "tone_lp": 0.2,
		"attack": 0.02, "decay": 1.6, "gain": 1.0})
	_add("missile_loop", 1.0, {"noise": 0.9, "lp0": 0.35, "lp1": 0.35, "wave": "saw", "f0": 60.0, "f1": 60.0, "tone": 0.15, "tone_lp": 0.15,
		"trem_f": 23.0, "trem_a": 0.25, "decay": 0.0, "gain": 0.7}, true)
	_add("lock_beep", 0.07, {"wave": "sine", "f0": 950.0, "f1": 950.0, "tone": 0.6, "harm": 0.2, "attack": 0.003, "decay": 1.0})
	_add("lock_tone", 0.5, {"wave": "sine", "f0": 1500.0, "f1": 1500.0, "tone": 0.4, "harm": 0.15, "decay": 0.0, "gain": 0.6}, true)
	_add("deny", 0.18, {"wave": "square", "f0": 180.0, "f1": 160.0, "tone": 0.3, "tone_lp": 0.3, "gate_f": 30.0, "decay": 0.8})
	_add("warn", 0.6, {"wave": "square", "f0": 880.0, "f1": 880.0, "tone": 0.3, "tone_lp": 0.35, "two_tone": 660.0, "decay": 0.4})
	_add("glass_crack", 0.45, {"noise": 1.0, "lp0": 0.95, "lp1": 0.5, "wave": "sine", "f0": 3200.0, "f1": 2400.0, "tone": 0.25, "gate_f": 60.0,
		"attack": 0.001, "decay": 4.0, "gain": 1.0})
	_add("boost_on", 0.6, {"noise": 0.9, "lp0": 0.05, "lp1": 0.3, "wave": "sine", "f0": 70.0, "f1": 140.0, "tone": 0.4, "attack": 0.04, "decay": 1.5})
	_add("boost_loop", 1.0, {"noise": 1.0, "lp0": 0.1, "lp1": 0.1, "wave": "saw", "f0": 48.0, "f1": 48.0, "tone": 0.35, "tone_lp": 0.12,
		"trem_f": 11.0, "trem_a": 0.15, "decay": 0.0, "gain": 0.9}, true)
	# A soft, warm hum with a slow shimmer (frequencies are whole cycles per loop, so it loops seamlessly).
	_add("mine_loop", 1.0, {"wave": "sine", "f0": 180.0, "f1": 180.0, "tone": 0.3, "harm": 0.12, "noise": 0.06, "lp0": 0.08, "lp1": 0.08,
		"vib_f": 3.0, "vib_a": 0.006, "trem_f": 5.0, "trem_a": 0.18, "decay": 0.0, "gain": 0.55}, true)
	_add("engine_loop", 2.0, {"wave": "saw", "f0": 46.0, "f1": 46.0, "tone": 0.35, "noise": 0.4, "lp0": 0.05, "lp1": 0.05, "decay": 0.0}, true)
	_add("scout_loop", 1.0, {"wave": "saw", "f0": 92.0, "f1": 92.0, "tone": 0.25, "noise": 0.3, "lp0": 0.12, "lp1": 0.12, "decay": 0.0}, true)
	# Waystation bulkhead doors: a heavy rumble while they move and a clang when they stop.
	_add("gate_loop", 2.0, {"wave": "saw", "f0": 38.0, "f1": 38.0, "tone": 0.3, "noise": 0.7, "lp0": 0.035, "lp1": 0.035,
		"vib_f": 2.0, "vib_a": 0.05, "trem_f": 7.0, "trem_a": 0.25, "decay": 0.0, "gain": 0.8}, true)
	_add("gate_clang", 1.3, {"wave": "sine", "f0": 95.0, "f1": 52.0, "tone": 0.6, "harm": 0.3, "noise": 0.8, "lp0": 0.35, "lp1": 0.04, "decay": 2.6, "gain": 1.0})
	_add("buy", 0.32, {"wave": "tri", "f0": 880.0, "f1": 1760.0, "tone": 0.5, "harm": 0.25, "decay": 1.6, "two_tone": 1320.0})
	# Abandoned stations: a sealed door grinding up, a lockdown shutter slamming down and its
	# whooping alarm, the service hatch of a keypad lock, and the generator: its starter coughing
	# the engine over, catching, and chugging away.
	_add("door_grind", 2.0, {"wave": "saw", "f0": 62.0, "f1": 62.0, "tone": 0.3, "harm": 0.3, "tone_lp": 0.1, "noise": 0.8, "lp0": 0.08,
		"lp1": 0.08, "trem_f": 11.0, "trem_a": 0.35, "vib_f": 3.0, "vib_a": 0.04, "decay": 0.0, "gain": 0.75}, true)
	_add("shutter_slam", 1.4, {"wave": "sine", "f0": 140.0, "f1": 45.0, "tone": 0.7, "harm": 0.4, "noise": 1.0, "lp0": 0.6, "lp1": 0.03,
		"attack": 0.001, "decay": 2.4, "gain": 1.0})
	_add("lockdown_alarm", 2.5, {"wave": "square", "f0": 520.0, "f1": 520.0, "tone": 0.28, "tone_lp": 0.3, "vib_f": 1.2, "vib_a": 0.25,
		"decay": 0.0, "gain": 0.6}, true)
	_add("hatch_open", 0.25, {"wave": "square", "f0": 900.0, "f1": 700.0, "tone": 0.2, "tone_lp": 0.4, "noise": 0.6, "lp0": 0.8, "lp1": 0.3,
		"attack": 0.001, "decay": 3.5})
	_add("gen_cough", 1.2, {"wave": "saw", "f0": 48.0, "f1": 30.0, "tone": 0.5, "tone_lp": 0.15, "noise": 0.7, "lp0": 0.2, "lp1": 0.05,
		"gate_f": 9.0, "attack": 0.01, "decay": 1.6, "gain": 1.0})
	_add("gen_start", 1.6, {"wave": "saw", "f0": 30.0, "f1": 60.0, "tone": 0.55, "tone_lp": 0.15, "noise": 0.6, "lp0": 0.15, "lp1": 0.15,
		"gate_f": 12.0, "attack": 0.02, "decay": 0.6, "gain": 1.0})
	_add("generator_loop", 1.0, {"wave": "saw", "f0": 55.0, "f1": 55.0, "tone": 0.4, "harm": 0.3, "tone_lp": 0.12, "noise": 0.5, "lp0": 0.1,
		"lp1": 0.1, "trem_f": 14.0, "trem_a": 0.45, "decay": 0.0, "gain": 0.8}, true)
	# Their aliens: acid sizzling where it lands, the stalker's shriek, a barnacle catching someone
	# (a wet slurp) and chewing, a crawler springing, an acid spider's hiss as it rears up to spit.
	_add("acid_hit", 0.5, {"noise": 0.8, "lp0": 0.9, "lp1": 0.7, "trem_f": 35.0, "trem_a": 0.5, "attack": 0.002, "decay": 2.2})
	_add("stalker_shriek", 0.9, {"wave": "saw", "f0": 720.0, "f1": 480.0, "tone": 0.3, "tone_lp": 0.35, "harm": 0.3, "noise": 0.5,
		"lp0": 0.5, "lp1": 0.2, "vib_f": 32.0, "vib_a": 0.08, "attack": 0.02, "decay": 1.4, "gain": 0.85})
	_add("barnacle_grab", 0.5, {"noise": 0.9, "lp0": 0.3, "lp1": 0.6, "wave": "sine", "f0": 220.0, "f1": 90.0, "tone": 0.5, "attack": 0.005, "decay": 1.8})
	_add("barnacle_chew", 0.35, {"noise": 0.8, "lp0": 0.5, "lp1": 0.2, "gate_f": 18.0, "wave": "sine", "f0": 130.0, "f1": 80.0, "tone": 0.35,
		"decay": 2.0})
	# A drop falling from a barnacle's maw onto the floor: a small wet plop (its only tell).
	_add("barnacle_drip", 0.16, {"wave": "sine", "f0": 1250.0, "f1": 380.0, "tone": 0.6, "noise": 0.2, "lp0": 0.35, "lp1": 0.15,
		"attack": 0.002, "decay": 4.0})
	_add("crawler_leap", 0.3, {"noise": 0.8, "lp0": 0.7, "lp1": 0.9, "wave": "saw", "f0": 1400.0, "f1": 2000.0, "tone": 0.12, "tone_lp": 0.5,
		"attack": 0.003, "decay": 2.5})
	_add("spider_hiss", 0.5, {"noise": 0.9, "lp0": 0.6, "lp1": 0.8, "wave": "saw", "f0": 300.0, "f1": 420.0, "tone": 0.15, "tone_lp": 0.3,
		"vib_f": 20.0, "vib_a": 0.2, "attack": 0.05, "decay": 1.2})


func _add(id: String, dur: float, cfg: Dictionary, loop := false) -> void:
	if loop and not cfg.has("attack"):
		# No fade-in on loops, or every repeat would start with a tiny dip.
		cfg["attack"] = 0.0
	_streams[id] = _to_wav(_synth(dur, cfg), loop)


## Generate samples for one recipe: a swept oscillator (plus an optional second harmonic, and an
## optional two-pole low-pass on it, "tone_lp"), low-passed noise (two poles with "noise_lp2"),
## tremolo and an envelope.
func _synth(dur: float, cfg: Dictionary) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var wave: String = cfg.get("wave", "")
	var f0: float = cfg.get("f0", 440.0)
	var f1: float = cfg.get("f1", f0)
	var tone: float = cfg.get("tone", 0.0)
	var tone_lp: float = cfg.get("tone_lp", 0.0)
	var noise_amp: float = cfg.get("noise", 0.0)
	var lp0: float = cfg.get("lp0", 1.0)
	var lp1: float = cfg.get("lp1", lp0)
	var vib_f: float = cfg.get("vib_f", 0.0)
	var vib_a: float = cfg.get("vib_a", 0.0)
	var attack: float = cfg.get("attack", 0.004)
	var decay: float = cfg.get("decay", 1.5)
	var gate_f: float = cfg.get("gate_f", 0.0)
	var two_tone: float = cfg.get("two_tone", 0.0)
	var gain: float = cfg.get("gain", 0.9)
	var harm: float = cfg.get("harm", 0.0)
	var trem_f: float = cfg.get("trem_f", 0.0)
	var trem_a: float = cfg.get("trem_a", 0.0)
	var noise_lp2: bool = cfg.get("noise_lp2", false)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(cfg)
	var phase := 0.0
	var lp := 0.0
	var lp2 := 0.0
	# The oscillator, the noise and the envelope, kept apart until the oscillator is filtered.
	var oscs := PackedFloat32Array()
	oscs.resize(n)
	var envs := PackedFloat32Array()
	envs.resize(n)
	for i in n:
		var t := float(i) / RATE
		var x := float(i) / n
		var f := f0 * pow(f1 / f0, x) if f0 > 0.0 and f1 > 0.0 else f0
		if two_tone > 0.0 and int(t / 0.225) % 2 == 1:
			f = two_tone
		if vib_f > 0.0:
			f *= 1.0 + sin(TAU * vib_f * t) * vib_a
		phase = fmod(phase + f / RATE, 1.0)
		var osc := 0.0
		match wave:
			"sine":
				osc = sin(TAU * phase)
			"square":
				osc = 1.0 if phase < 0.5 else -1.0
			"saw":
				osc = phase * 2.0 - 1.0
			"tri":
				osc = 1.0 - absf(phase * 4.0 - 2.0)
		if harm > 0.0:
			osc += sin(TAU * phase * 2.0) * harm
		oscs[i] = osc * tone
		var a := lerpf(lp0, lp1, x)
		lp += a * (rng.randf_range(-1.0, 1.0) - lp)
		lp2 += a * (lp - lp2)
		out[i] = (lp2 if noise_lp2 else lp) * noise_amp * (1.0 + (1.0 - a) * 1.5)
		var env := minf(1.0, t / attack) if attack > 0.0 else 1.0
		if trem_f > 0.0:
			env *= 1.0 - trem_a * (0.5 + 0.5 * sin(TAU * trem_f * t))
		if decay > 0.0:
			env *= pow(1.0 - x, decay)
		if gate_f > 0.0 and sin(TAU * gate_f * t) < 0.0:
			env *= 0.25
		envs[i] = env
	if tone_lp > 0.0:
		_lowpass2(oscs, tone_lp)
	for i in n:
		out[i] = clampf((oscs[i] + out[i]) * envs[i] * gain, -1.0, 1.0)
	return out


## Two one-pole low-passes in a row (coefficient `a`) over `s`, in place. It runs over the sound
## twice, so a loop's filter has settled by its start and it loops without a click.
static func _lowpass2(s: PackedFloat32Array, a: float) -> void:
	var y1 := 0.0
	var y2 := 0.0
	for v in s:
		y1 += a * (v - y1)
		y2 += a * (y1 - y2)
	for i in s.size():
		y1 += a * (s[i] - y1)
		y2 += a * (y1 - y2)
		s[i] = y2


func _to_wav(samples: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(samples[i] * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = data
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = samples.size()
	return s
