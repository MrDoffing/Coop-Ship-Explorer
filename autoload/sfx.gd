extends Node
## Procedurally synthesised sound effects, so the game ships without audio files.
##
## Sounds are generated once at startup from small recipes (swept oscillators plus filtered
## noise) and played through pooled 2D/3D players. Looping sounds are fetched with stream().

const RATE := 22050
const POOL_3D := 28
const POOL_2D := 8

var _streams: Dictionary = {}
var _pool3d: Array[AudioStreamPlayer3D] = []
var _pool2d: Array[AudioStreamPlayer] = []
var _next3d := 0
var _next2d := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_build_sounds()
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


func _build_sounds() -> void:
	_add("pulse", 0.16, {"wave": "sine", "f0": 1500.0, "f1": 240.0, "tone": 0.7, "noise": 0.12, "lp0": 0.4, "lp1": 0.1, "decay": 2.0})
	_add("flak", 0.24, {"wave": "sine", "f0": 180.0, "f1": 55.0, "tone": 0.35, "noise": 0.95, "lp0": 0.3, "lp1": 0.04, "decay": 2.4})
	_add("plasma", 0.42, {"wave": "sine", "f0": 440.0, "f1": 110.0, "tone": 0.8, "noise": 0.12, "lp0": 0.2, "lp1": 0.05, "vib_f": 28.0, "vib_a": 0.15, "decay": 1.5})
	_add("rail", 0.38, {"wave": "saw", "f0": 2600.0, "f1": 260.0, "tone": 0.45, "noise": 0.45, "lp0": 0.8, "lp1": 0.08, "decay": 3.0})
	_add("scout_shot", 0.09, {"wave": "square", "f0": 1150.0, "f1": 480.0, "tone": 0.35, "noise": 0.05, "decay": 2.0})
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
	_add("alarm", 0.9, {"wave": "square", "f0": 660.0, "f1": 660.0, "tone": 0.3, "two_tone": 520.0, "decay": 0.0})
	_add("mine_loop", 1.0, {"wave": "saw", "f0": 110.0, "f1": 110.0, "tone": 0.3, "noise": 0.3, "lp0": 0.3, "lp1": 0.3, "vib_f": 6.0, "vib_a": 0.04, "decay": 0.0}, true)
	_add("engine_loop", 2.0, {"wave": "saw", "f0": 46.0, "f1": 46.0, "tone": 0.35, "noise": 0.4, "lp0": 0.05, "lp1": 0.05, "decay": 0.0}, true)
	_add("scout_loop", 1.0, {"wave": "saw", "f0": 92.0, "f1": 92.0, "tone": 0.25, "noise": 0.3, "lp0": 0.12, "lp1": 0.12, "decay": 0.0}, true)


func _add(id: String, dur: float, cfg: Dictionary, loop := false) -> void:
	_streams[id] = _to_wav(_synth(dur, cfg), loop)


## Generate samples for one recipe: a swept oscillator, low-passed noise and an envelope.
func _synth(dur: float, cfg: Dictionary) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var wave: String = cfg.get("wave", "")
	var f0: float = cfg.get("f0", 440.0)
	var f1: float = cfg.get("f1", f0)
	var tone: float = cfg.get("tone", 0.0)
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
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(cfg)
	var phase := 0.0
	var lp := 0.0
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
		var a := lerpf(lp0, lp1, x)
		lp += a * (rng.randf_range(-1.0, 1.0) - lp)
		var v := osc * tone + lp * noise_amp * (1.0 + (1.0 - a) * 1.5)
		var env := minf(1.0, t / attack) if attack > 0.0 else 1.0
		if decay > 0.0:
			env *= pow(1.0 - x, decay)
		if gate_f > 0.0 and sin(TAU * gate_f * t) < 0.0:
			env *= 0.25
		out[i] = clampf(v * env * gain, -1.0, 1.0)
	return out


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
