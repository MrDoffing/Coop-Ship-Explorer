class_name CaveGen
extends RefCounted
## Deterministic procedural asteroid cave for one mission seed.
##
## The main tunnel follows a noise-driven path along -Z (depth s = -z) with a varying radius and
## occasional large caverns where nests live. Narrow side tunnels that only the scout fits through
## branch off and end in chambers holding fuel crystals. Every few hundred metres the tunnel runs
## through a waystation: it straightens onto the station's axis, narrows and smooths out, and
## opens into a hall carved around the landing pad, sealed by bulkheads at both ends (see
## StationBuilder for its layout). Rock is a signed distance field (negative = open space,
## positive = rock) that build_chunk() polygonises with surface nets.
##
## Every peer builds identical geometry from the seed, so only chunk indices are replicated.
## Instances cache per-segment data and are not thread-safe: use one instance per thread.

const CELL := 1.5
const CHUNK_CELLS := 32
const CHUNK_LEN := CELL * CHUNK_CELLS
const SIDE_SEGMENT := 110.0
const CAVERN_SEGMENT := 230.0
## Main wall noise is only evaluated this close to the surface (it never exceeds this amplitude).
const MAIN_BAND := 9.5
const SIDE_BAND := 3.0
const SIDE_BLEND := 3.0
const BIG := 99.0
## The tunnel is closed off behind the start position.
const START_CAP := -14.0
## Waystations: the first one around STATION_FIRST metres deep, then every STATION_SPACING.
const STATION_FIRST := 290.0
const STATION_SPACING := 440.0
## Near a waystation the tunnel runs straight along the station's axis with this radius and only a
## little of its wall noise: fully within STATION_HOLD metres of the hall's ends, blending back into
## the wild cave over the next STATION_RAMP metres.
const STATION_RADIUS := 15.0
const STATION_NOISE := 0.15
const STATION_HOLD := 10.0
const STATION_RAMP := 70.0
const STATION_BLEND := 2.0
## No scout tunnels this close (in depth) to a waystation.
const STATION_CLEAR := 130.0

const ROCK_A := Color(0.52, 0.46, 0.4)
const ROCK_B := Color(0.36, 0.38, 0.44)
const ROCK_DEEP := Color(0.48, 0.32, 0.42)

var seed_value: int
var _path_x: FastNoiseLite
var _path_x2: FastNoiseLite
var _path_y: FastNoiseLite
var _path_y2: FastNoiseLite
var _rad: FastNoiseLite
var _wall: FastNoiseLite
var _wall_big: FastNoiseLite
var _tint: FastNoiseLite
var _side_cache: Dictionary = {}
var _cavern_cache: Dictionary = {}
var _station_cache: Dictionary = {}


func _init(p_seed: int) -> void:
	seed_value = p_seed
	_path_x = _make_noise(p_seed + 11, 0.0032, 1)
	_path_x2 = _make_noise(p_seed + 12, 0.011, 1)
	_path_y = _make_noise(p_seed + 13, 0.0042, 1)
	_path_y2 = _make_noise(p_seed + 14, 0.014, 1)
	_rad = _make_noise(p_seed + 15, 0.012, 2)
	_wall = _make_noise(p_seed + 16, 0.075, 3)
	_wall_big = _make_noise(p_seed + 17, 0.02, 2)
	_tint = _make_noise(p_seed + 18, 0.03, 2)


static func _make_noise(s: int, freq: float, octaves: int) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = s
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	n.fractal_type = FastNoiseLite.FRACTAL_FBM if octaves > 1 else FastNoiseLite.FRACTAL_NONE
	n.fractal_octaves = octaves
	return n


# --- Shape of the cave -------------------------------------------------------------------------

## Centre of the main tunnel (x, y) at depth s. Near a waystation it runs onto the station's axis.
func center(s: float) -> Vector2:
	var raw := _raw_center(s)
	var st := _station_near(s)
	if st.is_empty():
		return raw
	var w := station_weight(s, st)
	return raw.lerp(_station_line(s, st), w) if w > 0.0 else raw


## The noise-driven tunnel path, before waystations straighten it.
func _raw_center(s: float) -> Vector2:
	var ramp := smoothstep(10.0, 160.0, s)
	return Vector2(
		_path_x.get_noise_1d(s) * 44.0 + _path_x2.get_noise_1d(s) * 9.0,
		_path_y.get_noise_1d(s) * 20.0 + _path_y2.get_noise_1d(s) * 5.0) * ramp


func center3(s: float) -> Vector3:
	var c := center(s)
	return Vector3(c.x, c.y, -s)


## Direction of the tunnel at depth s (pointing deeper).
func tangent(s: float) -> Vector3:
	return (center3(s + 4.0) - center3(s - 4.0)).normalized()


## Main tunnel radius at depth s, before wall noise.
func radius(s: float) -> float:
	var r := 21.0 + _rad.get_noise_1d(s) * 6.0 + cavern_extra(s)
	r *= smoothstep(START_CAP - 22.0, START_CAP, s)
	var st := _station_near(s)
	if not st.is_empty():
		r = lerpf(r, STATION_RADIUS, station_weight(s, st))
	return r


## How much of the main wall noise is left at depth s (the tunnel is smooth near waystations).
func noise_scale(s: float) -> float:
	var st := _station_near(s)
	if st.is_empty():
		return 1.0
	return lerpf(1.0, STATION_NOISE, station_weight(s, st))


## The waystation whose approach reaches depth s, or {}. Cavern avoidance can move a station well
## away from its nominal depth, so the neighbours are checked too.
func _station_near(s: float) -> Dictionary:
	var k := int(round((s - STATION_FIRST) / STATION_SPACING))
	var best := {}
	var best_w := 0.0
	for kk in range(maxi(k - 1, 0), k + 2):
		var st := station(kk)
		var w := station_weight(s, st)
		if w > best_w:
			best_w = w
			best = st
	return best


## 0..1: how strongly waystation `st` straightens the tunnel at depth s.
func station_weight(s: float, st: Dictionary) -> float:
	var lo: float = st["s_entry"]
	var hi: float = st["s_exit"]
	if s >= lo - STATION_HOLD and s <= hi + STATION_HOLD:
		return 1.0
	var d := (lo - STATION_HOLD - s) if s < lo else (s - hi - STATION_HOLD)
	return 1.0 - smoothstep(0.0, STATION_RAMP, d)


## Point (x, y) at depth s on the straight line through waystation `st`'s gates.
func _station_line(s: float, st: Dictionary) -> Vector2:
	var p0: Vector3 = st["p0"]
	var f: Vector3 = st["f"]
	var l := p0 + f * ((s - float(st["s"])) / -f.z)
	return Vector2(l.x, l.y)


func cavern(k: int) -> Dictionary:
	if _cavern_cache.has(k):
		return _cavern_cache[k]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, k, "cavern"])
	var cv := {
		"s": k * CAVERN_SEGMENT + rng.randf_range(70.0, 170.0),
		"extra": rng.randf_range(9.0, 15.0),
		"half": rng.randf_range(32.0, 46.0),
	}
	_cavern_cache[k] = cv
	return cv


## Extra radius from nearby caverns (smooth bumps along the tunnel).
func cavern_extra(s: float) -> float:
	var k := int(floor(s / CAVERN_SEGMENT))
	var extra := 0.0
	for kk in range(k - 1, k + 2):
		if kk < 1:
			continue
		var cv := cavern(kk)
		var t: float = absf(s - float(cv["s"])) / float(cv["half"])
		if t < 1.0:
			extra += float(cv["extra"]) * 0.5 * (1.0 + cos(PI * t))
	return extra


## Scout tunnels branching from segment k: chains of capsules ending in a chamber.
func side_tunnels(k: int) -> Array:
	if _side_cache.has(k):
		return _side_cache[k]
	var out := []
	if k >= 0:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([seed_value, k, "side"])
		var count := 1 if rng.randf() < 0.8 else 2
		for i in count:
			var s0 := k * SIDE_SEGMENT + 40.0 + rng.randf_range(10.0, SIDE_SEGMENT - 10.0) * (float(i) + 1.0) / float(count)
			var tunnel := _make_side_tunnel(rng, s0)
			# Keep the rock around waystation hangars intact.
			if not near_station(s0, STATION_CLEAR):
				out.append(tunnel)
	_side_cache[k] = out
	return out


func _make_side_tunnel(rng: RandomNumberGenerator, s0: float) -> Dictionary:
	var c := center3(s0)
	var ang := rng.randf_range(0.0, TAU)
	var dir := Vector3(cos(ang), sin(ang) * 0.7, 0.0).normalized()
	var pts := PackedVector3Array()
	var p := c + dir * (radius(s0) - 7.0)
	pts.append(p)
	var heading := dir
	var segs := rng.randi_range(2, 3)
	for i in segs:
		var lateral := heading.cross(Vector3.FORWARD).normalized()
		heading = (heading + lateral * rng.randf_range(-0.55, 0.55) + Vector3(0, 0, rng.randf_range(-0.4, 0.4))).normalized()
		heading = (heading + dir * 0.6).normalized()
		p += heading * rng.randf_range(13.0, 18.0)
		pts.append(p)
	var tube_r := rng.randf_range(4.0, 4.6)
	var chamber_r := rng.randf_range(7.0, 8.5)
	var chamber := p + heading * (chamber_r * 0.6)
	var aabb := AABB(pts[0], Vector3.ZERO)
	for q in pts:
		aabb = aabb.expand(q)
	aabb = aabb.expand(chamber)
	aabb = aabb.grow(maxf(tube_r, chamber_r) + 8.0)
	return {"pts": pts, "r": tube_r, "chamber": chamber, "chamber_r": chamber_r, "aabb": aabb, "s": s0}


## Side tunnels whose bounds touch the depth range [s_lo, s_hi].
func side_tunnels_in(s_lo: float, s_hi: float) -> Array:
	var out := []
	for k in range(int(floor(s_lo / SIDE_SEGMENT)) - 2, int(floor(s_hi / SIDE_SEGMENT)) + 2):
		for t in side_tunnels(k):
			var bb: AABB = t["aabb"]
			if bb.end.z < -s_hi or bb.position.z > -s_lo:
				continue
			out.append(t)
	return out


## Waystation k: a hall built into the tunnel around a landing pad, sealed by a bulkhead at each
## end. Station-local frame: -z along the tunnel (deeper, towards the exit), y up, origin on top of
## the landing pad; the tunnel's centre line runs through both gates at y = StationBuilder.LINE_Y.
## "s_entry" / "s_exit" are the depths of the hall's two ends.
func station(k: int) -> Dictionary:
	if _station_cache.has(k):
		return _station_cache[k]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value, k, "station"])
	var s := STATION_FIRST + k * STATION_SPACING + rng.randf_range(-40.0, 40.0)
	# Stay clear of the caverns' middles where nests grow (best effort when two caverns are close).
	for pass_i in 2:
		for kk in range(int(floor(s / CAVERN_SEGMENT)) - 1, int(floor(s / CAVERN_SEGMENT)) + 2):
			if kk < 1:
				continue
			var cv := cavern(kk)
			var clear := float(cv["half"]) + 60.0
			var off := s - float(cv["s"])
			if absf(off) < clear:
				s = float(cv["s"]) + (clear if off >= 0.0 else -clear)
	# The frame follows the raw tunnel (the straightened path is derived from it).
	var raw := _raw_center(s)
	var p0 := Vector3(raw.x, raw.y, -s)
	var ahead := _raw_center(s + 4.0)
	var behind := _raw_center(s - 4.0)
	var t := (Vector3(ahead.x, ahead.y, -s - 4.0) - Vector3(behind.x, behind.y, -s + 4.0)).normalized()
	var f := Vector3(t.x, 0.0, t.z).normalized()
	var zf := -f
	var basis := Basis(Vector3.UP.cross(zf), Vector3.UP, zf)
	var xform := Transform3D(basis, p0 - Vector3(0, StationBuilder.LINE_Y, 0))
	var hmin := Vector3(-StationBuilder.HALL_HALF_X, StationBuilder.HALL_FLOOR, StationBuilder.HALL_EXIT)
	var hmax := Vector3(StationBuilder.HALL_HALF_X, StationBuilder.HALL_ROOF, StationBuilder.HALL_ENTRY)
	var aabb := AABB(xform * hmin, Vector3.ZERO)
	for i in 8:
		aabb = aabb.expand(xform * Vector3(hmax.x if (i & 1) != 0 else hmin.x, hmax.y if (i & 2) != 0 else hmin.y, hmax.z if (i & 4) != 0 else hmin.z))
	var c := -f.z
	var st := {
		"k": k, "s": s, "xform": xform, "inv": xform.affine_inverse(), "p0": p0, "f": f,
		"s_entry": s - StationBuilder.HALL_ENTRY * c, "s_exit": s - StationBuilder.HALL_EXIT * c,
		"aabb": aabb.grow(SIDE_BAND + STATION_BLEND),
		"hc": (hmin + hmax) * 0.5, "hh": (hmax - hmin) * 0.5,
		"name": "WAYSTATION %d" % (k + 1),
	}
	_station_cache[k] = st
	return st


## Waystations whose carved rock touches the depth range [s_lo, s_hi].
func stations_in(s_lo: float, s_hi: float) -> Array:
	var out := []
	var k0 := int(floor((s_lo - STATION_FIRST - 160.0) / STATION_SPACING))
	var k1 := int(floor((s_hi - STATION_FIRST + 160.0) / STATION_SPACING))
	for k in range(maxi(k0, 0), k1 + 1):
		var st := station(k)
		var bb: AABB = st["aabb"]
		if bb.end.z < -s_hi or bb.position.z > -s_lo:
			continue
		out.append(st)
	return out


## True if a waystation lies within `dist` metres of depth s.
func near_station(s: float, dist: float) -> bool:
	var k := int(round((s - STATION_FIRST) / STATION_SPACING))
	for kk in range(k - 1, k + 2):
		if kk >= 0 and absf(float(station(kk)["s"]) - s) < dist:
			return true
	return false


## Signed distance to the rock carved away for a waystation's hall.
func station_raw(p: Vector3, st: Dictionary) -> float:
	var l: Vector3 = (st["inv"] as Transform3D) * p
	return _round_box(l - (st["hc"] as Vector3), st["hh"], StationBuilder.HALL_ROUND)


static func _round_box(p: Vector3, half: Vector3, r: float) -> float:
	var q := p.abs() - half + Vector3(r, r, r)
	return Vector3(maxf(q.x, 0.0), maxf(q.y, 0.0), maxf(q.z, 0.0)).length() + minf(maxf(q.x, maxf(q.y, q.z)), 0.0) - r


static func _seg_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)


static func smin(a: float, b: float, k: float) -> float:
	var h := maxf(k - absf(a - b), 0.0) / k
	return minf(a, b) - h * h * k * 0.25


func side_raw(p: Vector3, t: Dictionary) -> float:
	var pts: PackedVector3Array = t["pts"]
	var r: float = t["r"]
	var d := BIG
	for i in pts.size() - 1:
		d = smin(d, _seg_dist(p, pts[i], pts[i + 1]) - r, 2.0)
	return smin(d, p.distance_to(t["chamber"]) - float(t["chamber_r"]), 4.0)


func main_noise(x: float, y: float, z: float) -> float:
	return _wall.get_noise_3d(x, y, z) * 3.6 + _wall_big.get_noise_3d(x, y, z) * 5.0


func side_noise(x: float, y: float, z: float) -> float:
	return _wall.get_noise_3d(x, y, z) * 1.1


## Signed distance to rock at a world point (negative inside the cave).
func sdf(p: Vector3) -> float:
	var s := -p.z
	var c := center(s)
	var d := Vector2(p.x - c.x, p.y - c.y).length() - radius(s)
	if absf(d) < MAIN_BAND:
		d += main_noise(p.x, p.y, p.z) * noise_scale(s)
	for t in side_tunnels_in(s - 1.0, s + 1.0):
		var bb: AABB = t["aabb"]
		if bb.has_point(p):
			var ds := side_raw(p, t)
			if absf(ds) < SIDE_BAND:
				ds += side_noise(p.x, p.y, p.z)
			d = smin(d, ds, SIDE_BLEND)
	for st in stations_in(s - 1.0, s + 1.0):
		var bb: AABB = st["aabb"]
		if bb.has_point(p):
			var dw := station_raw(p, st)
			if absf(dw) < SIDE_BAND:
				dw += side_noise(p.x, p.y, p.z) * 0.6
			d = smin(d, dw, STATION_BLEND)
	return d


## Direction away from the nearest rock (the SDF gradient, pointing into open space).
func open_dir(p: Vector3) -> Vector3:
	var e := 0.8
	var g := Vector3(
		sdf(p + Vector3(e, 0, 0)) - sdf(p - Vector3(e, 0, 0)),
		sdf(p + Vector3(0, e, 0)) - sdf(p - Vector3(0, e, 0)),
		sdf(p + Vector3(0, 0, e)) - sdf(p - Vector3(0, 0, e)))
	return -g.normalized() if g.length_squared() > 1e-8 else Vector3.ZERO


# --- Chunk polygonisation ----------------------------------------------------------------------

## Build the rock surface for chunk n (depth n*CHUNK_LEN .. (n+1)*CHUNK_LEN).
## Returns mesh arrays plus collision faces. Grid points are aligned to a global lattice, so the
## shared boundary layers of neighbouring chunks produce identical vertices (no cracks).
func build_chunk(n: int) -> Dictionary:
	var k0 := n * CHUNK_CELLS
	var kmin := k0 - 1
	var nz := CHUNK_CELLS + 2
	var s_lo := kmin * CELL
	var s_hi := (kmin + nz - 1) * CELL

	var slice_c := PackedVector2Array()
	var slice_r := PackedFloat32Array()
	var slice_n := PackedFloat32Array()
	var xmin := INF
	var xmax := -INF
	var ymin := INF
	var ymax := -INF
	for kk in nz:
		var s := (kmin + kk) * CELL
		var c := center(s)
		var r := radius(s)
		slice_c.append(c)
		slice_r.append(r)
		slice_n.append(noise_scale(s))
		var ext := r + MAIN_BAND + CELL
		xmin = minf(xmin, c.x - ext)
		xmax = maxf(xmax, c.x + ext)
		ymin = minf(ymin, c.y - ext)
		ymax = maxf(ymax, c.y + ext)
	var tunnels := side_tunnels_in(s_lo, s_hi)
	var stations := stations_in(s_lo, s_hi)
	for t in tunnels + stations:
		var bb: AABB = t["aabb"]
		xmin = minf(xmin, bb.position.x)
		xmax = maxf(xmax, bb.end.x)
		ymin = minf(ymin, bb.position.y)
		ymax = maxf(ymax, bb.end.y)
	var i0 := int(floor(xmin / CELL)) - 1
	var i1 := int(ceil(xmax / CELL)) + 1
	var j0 := int(floor(ymin / CELL)) - 1
	var j1 := int(ceil(ymax / CELL)) + 1
	var nx := i1 - i0 + 1
	var ny := j1 - j0 + 1

	var vals := PackedFloat32Array()
	vals.resize(nx * ny * nz)
	vals.fill(BIG)

	# Main tunnel: per depth slice, only the square around the tunnel is evaluated.
	for kk in nz:
		var z := -(kmin + kk) * CELL
		var c := slice_c[kk]
		var r := slice_r[kk]
		var ns := slice_n[kk]
		if r < 0.5:
			continue
		var ext := r + MAIN_BAND + CELL
		var ia := maxi(0, int(floor((c.x - ext) / CELL)) - i0)
		var ib := mini(nx - 1, int(ceil((c.x + ext) / CELL)) - i0)
		var ja := maxi(0, int(floor((c.y - ext) / CELL)) - j0)
		var jb := mini(ny - 1, int(ceil((c.y + ext) / CELL)) - j0)
		for jj in range(ja, jb + 1):
			var y := (j0 + jj) * CELL
			var dy := y - c.y
			var row := (kk * ny + jj) * nx
			for ii in range(ia, ib + 1):
				var x := (i0 + ii) * CELL
				var dx := x - c.x
				var d := sqrt(dx * dx + dy * dy) - r
				if d < MAIN_BAND and d > -MAIN_BAND:
					d += main_noise(x, y, z) * ns
				vals[row + ii] = d

	# Side tunnels, blended in with a smooth union.
	for t in tunnels:
		var bb: AABB = t["aabb"]
		var ia := maxi(0, int(floor(bb.position.x / CELL)) - i0)
		var ib := mini(nx - 1, int(ceil(bb.end.x / CELL)) - i0)
		var ja := maxi(0, int(floor(bb.position.y / CELL)) - j0)
		var jb := mini(ny - 1, int(ceil(bb.end.y / CELL)) - j0)
		var ka := maxi(0, int(floor(-bb.end.z / CELL)) - kmin)
		var kb := mini(nz - 1, int(ceil(-bb.position.z / CELL)) - kmin)
		for kk in range(ka, kb + 1):
			var z := -(kmin + kk) * CELL
			for jj in range(ja, jb + 1):
				var y := (j0 + jj) * CELL
				var row := (kk * ny + jj) * nx
				for ii in range(ia, ib + 1):
					var x := (i0 + ii) * CELL
					var ds := side_raw(Vector3(x, y, z), t)
					if ds < SIDE_BAND and ds > -SIDE_BAND:
						ds += side_noise(x, y, z)
					vals[row + ii] = smin(vals[row + ii], ds, SIDE_BLEND)

	# Waystation halls: flat, lightly roughened rock.
	for st in stations:
		var bb: AABB = st["aabb"]
		var ia := maxi(0, int(floor(bb.position.x / CELL)) - i0)
		var ib := mini(nx - 1, int(ceil(bb.end.x / CELL)) - i0)
		var ja := maxi(0, int(floor(bb.position.y / CELL)) - j0)
		var jb := mini(ny - 1, int(ceil(bb.end.y / CELL)) - j0)
		var ka := maxi(0, int(floor(-bb.end.z / CELL)) - kmin)
		var kb := mini(nz - 1, int(ceil(-bb.position.z / CELL)) - kmin)
		for kk in range(ka, kb + 1):
			var z := -(kmin + kk) * CELL
			for jj in range(ja, jb + 1):
				var y := (j0 + jj) * CELL
				var row := (kk * ny + jj) * nx
				for ii in range(ia, ib + 1):
					var x := (i0 + ii) * CELL
					var dw := station_raw(Vector3(x, y, z), st)
					if dw < SIDE_BAND and dw > -SIDE_BAND:
						dw += side_noise(x, y, z) * 0.6
					vals[row + ii] = smin(vals[row + ii], dw, STATION_BLEND)

	return _surface_nets(vals, nx, ny, nz, i0, j0, kmin)


func _surface_nets(vals: PackedFloat32Array, nx: int, ny: int, nz: int, i0: int, j0: int, kmin: int) -> Dictionary:
	var cnx := nx - 1
	var cny := ny - 1
	var cell_ids := PackedInt32Array()
	cell_ids.resize(cnx * cny * (nz - 1))
	cell_ids.fill(-1)
	var ctx := {
		"vals": vals, "nx": nx, "ny": ny, "cnx": cnx, "cny": cny, "ids": cell_ids,
		"ox": i0 * CELL, "oy": j0 * CELL, "oz": -kmin * CELL,
		"verts": PackedVector3Array(), "norms": PackedVector3Array(),
	}
	var indices := PackedInt32Array()
	var plane := nx * ny
	# Edges on point layers 1..CHUNK_CELLS belong to this chunk; layers 0 and CHUNK_CELLS+1 are
	# shared with the neighbours and only provide cell corners.
	for kk in range(1, CHUNK_CELLS + 1):
		for jj in range(1, ny - 1):
			var row := (kk * ny + jj) * nx
			for ii in range(1, nx - 1):
				var i := row + ii
				var neg := vals[i] < 0.0
				if neg != (vals[i + 1] < 0.0):
					_quad(ctx, indices, Vector3(-1, 0, 0) if neg else Vector3(1, 0, 0),
						_cell(ctx, ii, jj - 1, kk - 1), _cell(ctx, ii, jj, kk - 1),
						_cell(ctx, ii, jj, kk), _cell(ctx, ii, jj - 1, kk))
				if neg != (vals[i + nx] < 0.0):
					_quad(ctx, indices, Vector3(0, -1, 0) if neg else Vector3(0, 1, 0),
						_cell(ctx, ii - 1, jj, kk - 1), _cell(ctx, ii, jj, kk - 1),
						_cell(ctx, ii, jj, kk), _cell(ctx, ii - 1, jj, kk))
				if neg != (vals[i + plane] < 0.0):
					_quad(ctx, indices, Vector3(0, 0, 1) if neg else Vector3(0, 0, -1),
						_cell(ctx, ii - 1, jj - 1, kk), _cell(ctx, ii, jj - 1, kk),
						_cell(ctx, ii, jj, kk), _cell(ctx, ii - 1, jj, kk))

	var verts: PackedVector3Array = ctx["verts"]
	var norms: PackedVector3Array = ctx["norms"]
	var colors := PackedColorArray()
	colors.resize(verts.size())
	for v in verts.size():
		var p := verts[v]
		var ao := _occlusion(ctx, p + norms[v] * 2.5)
		var t := _tint.get_noise_3d(p.x, p.y, p.z) * 0.5 + 0.5
		var base := ROCK_A.lerp(ROCK_B, t)
		base = base.lerp(ROCK_DEEP, clampf(-p.z / 1600.0, 0.0, 0.7))
		colors[v] = base * (0.35 + 0.65 * ao)
	var faces := PackedVector3Array()
	faces.resize(indices.size())
	for f in indices.size():
		faces[f] = verts[indices[f]]
	return {"verts": verts, "norms": norms, "colors": colors, "indices": indices, "faces": faces}


## Vertex for grid cell (ci, cj, ck): average of the cell's edge crossings.
func _cell(ctx: Dictionary, ci: int, cj: int, ck: int) -> int:
	var ids: PackedInt32Array = ctx["ids"]
	var cnx: int = ctx["cnx"]
	var cidx: int = (ck * int(ctx["cny"]) + cj) * cnx + ci
	if ids[cidx] >= 0:
		return ids[cidx]
	var vals: PackedFloat32Array = ctx["vals"]
	var nx: int = ctx["nx"]
	var ny: int = ctx["ny"]
	var b := (ck * ny + cj) * nx + ci
	var b2 := b + nx * ny
	var v000 := vals[b]
	var v100 := vals[b + 1]
	var v010 := vals[b + nx]
	var v110 := vals[b + nx + 1]
	var v001 := vals[b2]
	var v101 := vals[b2 + 1]
	var v011 := vals[b2 + nx]
	var v111 := vals[b2 + nx + 1]
	var sum := Vector3.ZERO
	var cnt := 0
	# Edges along x.
	if (v000 < 0.0) != (v100 < 0.0):
		sum += Vector3(v000 / (v000 - v100), 0, 0)
		cnt += 1
	if (v010 < 0.0) != (v110 < 0.0):
		sum += Vector3(v010 / (v010 - v110), 1, 0)
		cnt += 1
	if (v001 < 0.0) != (v101 < 0.0):
		sum += Vector3(v001 / (v001 - v101), 0, 1)
		cnt += 1
	if (v011 < 0.0) != (v111 < 0.0):
		sum += Vector3(v011 / (v011 - v111), 1, 1)
		cnt += 1
	# Edges along y.
	if (v000 < 0.0) != (v010 < 0.0):
		sum += Vector3(0, v000 / (v000 - v010), 0)
		cnt += 1
	if (v100 < 0.0) != (v110 < 0.0):
		sum += Vector3(1, v100 / (v100 - v110), 0)
		cnt += 1
	if (v001 < 0.0) != (v011 < 0.0):
		sum += Vector3(0, v001 / (v001 - v011), 1)
		cnt += 1
	if (v101 < 0.0) != (v111 < 0.0):
		sum += Vector3(1, v101 / (v101 - v111), 1)
		cnt += 1
	# Edges along the depth axis.
	if (v000 < 0.0) != (v001 < 0.0):
		sum += Vector3(0, 0, v000 / (v000 - v001))
		cnt += 1
	if (v100 < 0.0) != (v101 < 0.0):
		sum += Vector3(1, 0, v100 / (v100 - v101))
		cnt += 1
	if (v010 < 0.0) != (v011 < 0.0):
		sum += Vector3(0, 1, v010 / (v010 - v011))
		cnt += 1
	if (v110 < 0.0) != (v111 < 0.0):
		sum += Vector3(1, 1, v110 / (v110 - v111))
		cnt += 1
	var local := sum / float(maxi(cnt, 1)) if cnt > 0 else Vector3(0.5, 0.5, 0.5)
	var pos := Vector3(
		float(ctx["ox"]) + (ci + local.x) * CELL,
		float(ctx["oy"]) + (cj + local.y) * CELL,
		float(ctx["oz"]) - (ck + local.z) * CELL)
	var gx := (v100 - v000) + (v110 - v010) + (v101 - v001) + (v111 - v011)
	var gy := (v010 - v000) + (v110 - v100) + (v011 - v001) + (v111 - v101)
	var gk := (v001 - v000) + (v101 - v100) + (v011 - v010) + (v111 - v110)
	# Grid depth runs along -z; the normal points down the gradient, into open space.
	var nrm := Vector3(-gx, -gy, gk)
	nrm = nrm.normalized() if nrm.length_squared() > 1e-12 else Vector3.UP
	var verts: PackedVector3Array = ctx["verts"]
	var norms: PackedVector3Array = ctx["norms"]
	verts.append(pos)
	norms.append(nrm)
	var id := verts.size() - 1
	ids[cidx] = id
	return id


## Two triangles for the quad around a sign-changing edge, facing `facing` (towards open space).
func _quad(ctx: Dictionary, indices: PackedInt32Array, facing: Vector3, a: int, b: int, c: int, d: int) -> void:
	var verts: PackedVector3Array = ctx["verts"]
	var n := (verts[c] - verts[a]).cross(verts[d] - verts[b])
	# Godot front faces are clockwise, i.e. the right-handed normal points away from the viewer.
	if n.dot(facing) > 0.0:
		indices.append_array(PackedInt32Array([a, c, b, a, d, c]))
	else:
		indices.append_array(PackedInt32Array([a, b, c, a, c, d]))


## Ambient occlusion estimate: how open the space is at a point near the surface (0..1).
func _occlusion(ctx: Dictionary, p: Vector3) -> float:
	var vals: PackedFloat32Array = ctx["vals"]
	var nx: int = ctx["nx"]
	var ny: int = ctx["ny"]
	var fx := (p.x - float(ctx["ox"])) / CELL
	var fy := (p.y - float(ctx["oy"])) / CELL
	var fz := (float(ctx["oz"]) - p.z) / CELL
	var ix := int(floor(fx))
	var iy := int(floor(fy))
	var iz := int(floor(fz))
	var nzc := vals.size() / (nx * ny)
	if ix < 0 or iy < 0 or iz < 0 or ix >= nx - 1 or iy >= ny - 1 or iz >= nzc - 1:
		return 1.0
	var tx := fx - ix
	var ty := fy - iy
	var tz := fz - iz
	var b := (iz * ny + iy) * nx + ix
	var b2 := b + nx * ny
	var c00 := lerpf(vals[b], vals[b + 1], tx)
	var c10 := lerpf(vals[b + nx], vals[b + nx + 1], tx)
	var c01 := lerpf(vals[b2], vals[b2 + 1], tx)
	var c11 := lerpf(vals[b2 + nx], vals[b2 + nx + 1], tx)
	var d := lerpf(lerpf(c00, c10, ty), lerpf(c01, c11, ty), tz)
	return clampf(-d / 2.5, 0.0, 1.0)
