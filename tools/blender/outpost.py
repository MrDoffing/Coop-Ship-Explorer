"""Tiling textures for the abandoned outposts (res://assets/textures, used by DerelictBuilder):

- outpost_wall: olive-drab steel wall panels, 1 m wide and 2 m tall to the 2 m tile: the lower part
  of each ribbed, the upper part a raised inset panel, rivets along the seams, the paint chipped at
  the edges and the ribs' crests, grime gathered low down and run down in streaks.
- outpost_floor: steel tread plate, plates of 1 m with the raised diamond pattern, worn shiny on
  top, dirt in the seams and patches of rust.
- outpost_grate: bar grating for the corridors and the pier, 1 m to the tile: bearing bars with
  cross rods, the gaps cut out (alpha) so the trench under it shows.
- outpost_paint / outpost_bare: near-white worn painted steel and bare metal, tinted per material
  (the frames, pipes and furniture).
- outpost_hazard: worn yellow and black stripes.

Each comes as <name>_albedo, <name>_orm (occlusion, roughness, metallic) and <name>_normal, drawn
with numpy (the helpers are the same as decals.py's); Blender only writes the PNGs.

    blender -b -P tools/blender/outpost.py
"""

import math
import os
import sys

import bpy
import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lib  # noqa: E402

TEXTURES = os.path.join(lib.ROOT, "assets", "textures")


# --- Helpers (as in decals.py) ---------------------------------------------------------------------

def save(name, rgba, normal=False):
	"""Save an (h, w, 4) float array (row 0 at the top) as assets/textures/<name>.png, VRAM-compressed
	with mipmaps in Godot."""
	os.makedirs(TEXTURES, exist_ok=True)
	rgba = np.clip(rgba, 0.0, 1.0)
	h, w = rgba.shape[:2]
	img = bpy.data.images.new(name, w, h, alpha=True)
	img.pixels.foreach_set(np.ascontiguousarray(rgba[::-1]).astype(np.float32).ravel())
	path = os.path.join(TEXTURES, name + ".png")
	img.filepath_raw = path
	img.file_format = "PNG"
	img.save()
	bpy.data.images.remove(img)
	lib.write_import(path, normal=normal, vram=True)
	print("[outpost]", name, w, h, flush=True)


def smooth(e0, e1, x):
	t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


def vnoise(h, w, cell, rng):
	"""Periodic value noise with lattice spacing `cell` pixels (h and w multiples of cell)."""
	cell = max(1, int(cell))
	gh, gw = max(1, h // cell), max(1, w // cell)
	grid = rng.random((gh, gw))
	y = np.arange(h) / cell
	x = np.arange(w) / cell
	y0 = np.floor(y).astype(int)
	x0 = np.floor(x).astype(int)
	fy = y - y0
	fx = x - x0
	fy = fy * fy * (3 - 2 * fy)
	fx = fx * fx * (3 - 2 * fx)
	y1, x1 = (y0 + 1) % gh, (x0 + 1) % gw
	y0, x0 = y0 % gh, x0 % gw
	a = grid[np.ix_(y0, x0)]
	b = grid[np.ix_(y0, x1)]
	c = grid[np.ix_(y1, x0)]
	d = grid[np.ix_(y1, x1)]
	sx = fx[None, :]
	sy = fy[:, None]
	return (a + (b - a) * sx) * (1 - sy) + (c + (d - c) * sx) * sy


def fbm(h, w, cell, octaves, rng, gain=0.5):
	total = np.zeros((h, w))
	amp, norm = 1.0, 0.0
	for o in range(octaves):
		total += amp * vnoise(h, w, max(1, cell // (2 ** o)), rng)
		norm += amp
		amp *= gain
	return total / norm


def blur(a, r, passes=2):
	"""A soft periodic blur: box filters of radius r, a few times."""
	r = int(r)
	out = a.astype(np.float64)
	if r < 1:
		return out
	for _ in range(passes):
		for axis in (0, 1):
			out = sum(np.roll(out, k, axis) for k in range(-r, r + 1)) / (2 * r + 1)
	return out


def normal_from_height(hgt, strength):
	"""Tangent-space normals (OpenGL style: green up) from a periodic height map."""
	gx = (np.roll(hgt, -1, 1) - np.roll(hgt, 1, 1)) * 0.5
	gy = (np.roll(hgt, -1, 0) - np.roll(hgt, 1, 0)) * 0.5
	nx = -gx * strength
	ny = gy * strength
	nz = np.ones_like(hgt)
	ln = np.sqrt(nx * nx + ny * ny + nz * nz)
	out = np.empty(hgt.shape + (4,), np.float32)
	out[..., 0] = nx / ln * 0.5 + 0.5
	out[..., 1] = ny / ln * 0.5 + 0.5
	out[..., 2] = nz / ln * 0.5 + 0.5
	out[..., 3] = 1.0
	return out


def rgb(*parts):
	"""Stack r, g, b (and alpha 1) arrays into an (h, w, 4) image."""
	h, w = parts[0].shape
	out = np.ones((h, w, 4), np.float32)
	for i in range(3):
		out[..., i] = parts[i]
	return out


def mix(a, b, t):
	return a + (b - a) * t


def periodic_dist(n, period):
	"""Distance (pixels) of each of n pixels to the nearest multiple of `period`."""
	x = np.arange(n) % period
	return np.minimum(x, period - x)


def save_set(name, albedo, height, strength, ao, rough, metal):
	save(name + "_albedo", albedo)
	save(name + "_normal", normal_from_height(blur(height, 1, 1), strength), normal=True)
	save(name + "_orm", rgb(ao, rough, metal))


# --- Wall panels -------------------------------------------------------------------------------------

def wall():
	"""2 m to the tile at 1024 px: panels 1 m wide (512 px) and the whole tile tall."""
	rng = np.random.default_rng(71)
	s = 1024
	pw = 512
	yy, xx = np.mgrid[0:s, 0:s].astype(np.float64)
	# Seams: between the panels side by side, and at the top and bottom of the tile.
	seam_d = np.minimum(periodic_dist(s, pw)[None, :].repeat(s, 0), periodic_dist(s, s)[:, None].repeat(s, 1))
	seam = smooth(3.0, 1.0, seam_d)
	# Each panel's own tone.
	panel = (xx // pw).astype(int)
	tone = np.array([0.0, 0.035])[panel % 2] + rng.normal(0.0, 0.015, 1)[0]
	u = (xx % pw) / pw
	v = yy / s
	# The lower 40%: horizontal ribs every 5 cm; above it, a raised inset panel with a bevelled edge.
	ribbed = v > 0.6
	rib = np.where(ribbed, 0.5 + 0.5 * np.cos((yy - s * 0.6) / (s * 0.025) * math.pi * 2.0), 0.0)
	rib *= smooth(0.0, 0.03, u) * smooth(1.0, 0.97, u)
	inset_u = np.minimum(u - 0.08, 0.92 - u)
	inset_v = np.minimum(v - 0.07, 0.53 - v)
	inset_d = np.minimum(inset_u, inset_v)
	inset = smooth(0.0, 0.012, inset_d)
	# A band between the two parts and rivets along every seam and the band.
	band = smooth(5.0, 2.0, np.abs(yy - s * 0.6))
	rivet = np.zeros((s, s))
	for col in (10, pw - 11, pw + 10, s - 11):
		d = np.sqrt((xx - col) ** 2 + ((yy - 24) % 48 - 24) ** 2)
		rivet = np.maximum(rivet, smooth(4.0, 2.0, d))
	for row in (int(s * 0.6) - 9, int(s * 0.6) + 9, 9, s - 10):
		d = np.sqrt(((xx - 20) % 40 - 20) ** 2 + (yy - row) ** 2)
		rivet = np.maximum(rivet, smooth(3.5, 1.8, d))
	noise = fbm(s, s, 128, 5, rng)
	fine = fbm(s, s, 16, 3, rng)
	# Chipped paint: at the seams, the ribs' crests, the inset's edge and the rivets, where the
	# noise says so.
	edges = np.maximum.reduce([smooth(10.0, 2.0, seam_d), smooth(0.85, 1.0, rib) * ribbed * 0.55, smooth(0.02, 0.0, np.abs(inset_d)) * 0.7,
		rivet * 0.6])
	chip = smooth(0.68, 0.76, edges * 0.55 + noise * 0.55 + (fine - 0.5) * 0.4)
	# Grime: gathered at the bottom of each panel, run down in streaks, and in the grooves.
	streak = blur(np.repeat(rng.random((1, s // 4)), 4, 1).repeat(s, 0), 3, 1)
	low = smooth(0.45, 1.0, v)
	grime = np.clip(low * 0.55 + (streak - 0.5) * 0.6 * smooth(0.0, 0.5, v) + seam * 0.5 + (1.0 - inset) * 0.15 * (v < 0.6), 0, 1)
	grime *= 0.6 + 0.4 * noise
	paint = np.array([0.31, 0.33, 0.2])
	bare = np.array([0.46, 0.43, 0.37])
	rust = np.array([0.36, 0.2, 0.1])
	dirt = np.array([0.12, 0.11, 0.08])
	col = np.zeros((s, s, 3))
	for i in range(3):
		c = paint[i] * (1.0 + tone + (noise - 0.5) * 0.18 + (fine - 0.5) * 0.06)
		c = mix(c, mix(bare[i], rust[i], smooth(0.55, 0.75, fine)), chip)
		c = mix(c, dirt[i], grime * 0.65)
		c = c * (1.0 - seam * 0.6) * (1.0 - rib * ribbed * 0.08)
		col[..., i] = c
	albedo = np.concatenate([col, np.ones((s, s, 1))], axis=2)
	height = inset * 1.2 + rib * ribbed * 1.6 + rivet * 1.4 - seam * 2.5 - band * 0.8 + (noise - 0.5) * 0.3 - chip * 0.2
	ao = np.clip(1.0 - seam * 0.6 - (1.0 - rib) * ribbed * 0.25 - band * 0.3 - grime * 0.15, 0, 1)
	rough = np.clip(0.72 - chip * 0.3 + grime * 0.12 + (fine - 0.5) * 0.08, 0, 1)
	metal = np.clip(0.12 + chip * 0.6, 0, 1)
	save_set("outpost_wall", albedo, height, 2.6, ao, rough, metal)


# --- Tread plate floor ---------------------------------------------------------------------------------

def floor():
	"""2 m to the tile at 1024 px: plates of 1 m, a raised diamond pattern at 6 cm."""
	rng = np.random.default_rng(72)
	s = 1024
	yy, xx = np.mgrid[0:s, 0:s].astype(np.float64)
	seam_d = np.minimum(periodic_dist(s, 512)[None, :].repeat(s, 0), periodic_dist(s, 512)[:, None].repeat(s, 1))
	seam = smooth(3.0, 1.0, seam_d)
	# Diamonds: elongated bumps on a lattice, every other one turned.
	pitch = 32.0
	cx = np.floor(xx / pitch)
	cy = np.floor(yy / pitch)
	lx = (xx % pitch) / pitch - 0.5
	ly = (yy % pitch) / pitch - 0.5
	turn = (cx + cy) % 2 == 0
	a = np.where(turn, lx + ly, lx - ly)
	b = np.where(turn, lx - ly, lx + ly)
	dia = smooth(0.12, 0.06, np.sqrt((a / 0.42) ** 2 + (b / 0.11) ** 2) * 0.12)
	noise = fbm(s, s, 256, 6, rng)
	fine = fbm(s, s, 16, 3, rng)
	# Dirt: a soft wash with little contrast (big dark blotches repeat visibly every tile), packed
	# into the seams and the diamonds' feet.
	dirt = smooth(0.4, 0.85, noise) * 0.38 + seam * 0.6 + (1.0 - dia) * smooth(0.45, 0.7, fine) * 0.12
	rust = smooth(0.7, 0.84, fbm(s, s, 64, 4, rng)) * 0.55
	worn = dia * smooth(0.3, 0.7, fine)
	steel = 0.37 + (noise - 0.5) * 0.08 + worn * 0.12
	r = mix(mix(steel, 0.34, rust), 0.1, dirt * 0.6)
	g = mix(mix(steel, 0.2, rust), 0.095, dirt * 0.6)
	bl = mix(mix(steel * 0.98, 0.1, rust), 0.08, dirt * 0.6)
	albedo = rgb(r * (1 - seam * 0.5), g * (1 - seam * 0.5), bl * (1 - seam * 0.5))
	height = dia * 1.2 - seam * 2.0 + (noise - 0.5) * 0.2
	ao = np.clip(1.0 - seam * 0.6 - (1.0 - dia) * 0.12 - dirt * 0.1, 0, 1)
	rough = np.clip(0.55 - worn * 0.25 + dirt * 0.3 + rust * 0.25, 0, 1)
	metal = np.clip(0.8 - dirt * 0.5 - rust * 0.6, 0, 1)
	save_set("outpost_floor", albedo, height, 2.0, ao, rough, metal)


# --- Bar grating ----------------------------------------------------------------------------------------

def grate():
	"""1 m to the tile at 512 px: bearing bars every 3.3 cm (17 px), cross rods every 10 cm."""
	rng = np.random.default_rng(73)
	s = 512
	yy, xx = np.mgrid[0:s, 0:s].astype(np.float64)
	bar_d = periodic_dist(s, 17)[None, :].repeat(s, 0).astype(np.float64)
	rod_d = periodic_dist(s, 51)[:, None].repeat(s, 1).astype(np.float64)
	bar = smooth(3.2, 2.0, bar_d)
	rod = smooth(2.2, 1.2, rod_d)
	solid = np.maximum(bar, rod * 0.9)
	noise = fbm(s, s, 64, 4, rng)
	fine = fbm(s, s, 8, 2, rng)
	dirt = smooth(0.5, 0.85, noise) * 0.45
	# Worn bare steel on the bars' tops, a darker galvanised grey on the rods. The gaps are cut out
	# (alpha), so whatever lies under the grating shows through.
	steel = 0.52 + (fine - 0.5) * 0.12 + bar * 0.06
	r = mix(0.1, mix(steel, 0.2, dirt), solid)
	g = mix(0.1, mix(steel * 0.98, 0.18, dirt), solid)
	bl = mix(0.1, mix(steel * 0.93, 0.14, dirt), solid)
	albedo = rgb(r, g, bl)
	albedo[..., 3] = smooth(0.35, 0.6, solid)
	height = bar * 1.5 + rod * 1.0 - (1.0 - solid) * 1.5
	ao = np.clip(0.35 + solid * 0.65 - rod * bar * 0.15, 0, 1)
	rough = np.clip(mix(1.0, 0.4 + dirt * 0.35, solid), 0, 1)
	metal = np.clip(solid * (0.9 - dirt * 0.5), 0, 1)
	save_set("outpost_grate", albedo, height, 3.0, ao, rough, metal)


# --- Tintable worn surfaces for the frames, props and fittings ------------------------------------------

def paint():
	"""Painted steel, 1 m to the tile at 512 px, near white so a material's tint gives its colour
	(olive drab, khaki, red, white enamel): brush marks and a mottled tone, chips down to dark bare
	steel, scratches, and grime gathered in patches. Rough and non-metallic but where chipped."""
	rng = np.random.default_rng(74)
	s = 512
	noise = fbm(s, s, 128, 5, rng)
	mottle = fbm(s, s, 32, 3, rng)
	fine = fbm(s, s, 8, 2, rng)
	# Brush strokes: faint streaks one way.
	brush = blur(np.repeat(rng.random((s, 1)), s, 1), 0, 1) * 0.5 + blur(rng.random((s, s)), 1, 1) * 0.5
	chips = smooth(0.755, 0.775, noise * 0.6 + fine * 0.4)
	chip_rim = smooth(0.72, 0.755, noise * 0.6 + fine * 0.4) - chips
	# Scratches: short straight lines at random angles.
	scratch = np.zeros((s, s))
	yy, xx = np.mgrid[0:s, 0:s].astype(np.float64)
	for _ in range(28):
		cx, cy = rng.random(2) * s
		a = rng.random() * math.pi
		ln = rng.uniform(8, 35)
		dx, dy = math.cos(a), math.sin(a)
		px = (xx - cx + s / 2) % s - s / 2
		py = (yy - cy + s / 2) % s - s / 2
		t = np.clip(px * dx + py * dy, -ln, ln)
		d = np.sqrt((px - t * dx) ** 2 + (py - t * dy) ** 2)
		scratch = np.maximum(scratch, smooth(1.0, 0.2, d) * rng.uniform(0.2, 0.55))
	grime = smooth(0.5, 0.85, fbm(s, s, 256, 4, rng)) * 0.28 + smooth(0.65, 0.9, mottle) * 0.1
	base = 0.68 * (1.0 + (mottle - 0.5) * 0.16 + (brush - 0.5) * 0.08)
	# Chips show a lighter grey-brown primer and steel, never black.
	bare = 0.52 + (fine - 0.5) * 0.08
	v = mix(base, bare, np.maximum(chips, scratch * 0.7))
	v = v * (1.0 - chip_rim * 0.18) * (1.0 - grime * 0.5)
	# Grime is a warm brown, not just darker: a little more red than blue.
	albedo = rgb(v * (1.0 + grime * 0.08), v, v * (1.0 - grime * 0.12))
	height = (1.0 - chips) * 0.8 - scratch * 0.3 + (brush - 0.5) * 0.15 + (noise - 0.5) * 0.1
	ao = np.clip(1.0 - chip_rim * 0.3 - grime * 0.2, 0, 1)
	rough = np.clip(0.72 + (fine - 0.5) * 0.1 - chips * 0.25 + grime * 0.12, 0, 1)
	metal = np.clip(np.maximum(chips, scratch * 0.8), 0, 1)
	save_set("outpost_paint", albedo, height, 1.6, ao, rough, metal)


def bare():
	"""Bare worn metal (steel, gunmetal, bronze by tint), 1 m to the tile at 512 px: brushed grain,
	scuffs worn shiny, dull oxidised patches and grime. Metallic throughout."""
	rng = np.random.default_rng(75)
	s = 512
	grain = blur(np.repeat(rng.random((s, 1)), s, 1), 1, 1) * 0.6 + blur(rng.random((s, s)), 0, 1) * 0.4
	noise = fbm(s, s, 128, 5, rng)
	fine = fbm(s, s, 16, 3, rng)
	scuff = smooth(0.6, 0.75, fbm(s, s, 32, 3, rng))
	oxide = smooth(0.55, 0.8, noise) * 0.7
	grime = smooth(0.5, 0.85, fbm(s, s, 256, 4, rng)) * 0.6
	v = 0.72 * (1.0 + (grain - 0.5) * 0.12 + (fine - 0.5) * 0.1 + scuff * 0.12)
	v = v * (1.0 - oxide * 0.35) * (1.0 - grime * 0.5)
	albedo = rgb(v * (1.0 + grime * 0.05), v, v * (1.0 - oxide * 0.06 - grime * 0.1))
	height = (grain - 0.5) * 0.3 + (noise - 0.5) * 0.2
	ao = np.clip(1.0 - grime * 0.25, 0, 1)
	rough = np.clip(0.6 + oxide * 0.2 + grime * 0.15 - scuff * 0.12 + (grain - 0.5) * 0.08, 0, 1)
	metal = np.clip(0.95 - oxide * 0.35 - grime * 0.4, 0, 1)
	save_set("outpost_bare", albedo, height, 1.0, ao, rough, metal)


def hazard():
	"""Yellow and black hazard stripes at 45 degrees, painted on steel: 0.5 m to the tile at 512 px
	(stripes 12.5 cm wide), worn through at random and grimy, the yellow a dull ochre rather than a
	bright one."""
	rng = np.random.default_rng(76)
	s = 512
	yy, xx = np.mgrid[0:s, 0:s].astype(np.float64)
	period = s / 2.0
	t = ((xx + yy) % period) / period
	edge = np.minimum(np.abs(t - 0.25), np.abs(t - 0.75))
	band = smooth(-1.5, 1.5, (0.25 - np.abs(t - 0.5)) * period * 1.0)
	noise = fbm(s, s, 128, 5, rng)
	fine = fbm(s, s, 8, 2, rng)
	worn = smooth(0.64, 0.7, noise * 0.6 + fine * 0.4)
	grime = smooth(0.4, 0.85, fbm(s, s, 256, 4, rng)) * 0.5
	yellow = np.array([0.62, 0.46, 0.1])
	black = np.array([0.05, 0.05, 0.045])
	steel = np.array([0.32, 0.31, 0.29])
	col = np.zeros((s, s, 4), np.float32)
	for i in range(3):
		c = mix(black[i], yellow[i] * (1.0 + (fine - 0.5) * 0.15), band)
		c = mix(c, steel[i], worn)
		col[..., i] = c * (1.0 - grime * 0.6)
	col[..., 3] = 1.0
	height = (1.0 - worn) * 0.6 + (noise - 0.5) * 0.15 - smooth(2.0, 0.0, edge * period) * 0.05
	ao = np.clip(1.0 - grime * 0.2, 0, 1)
	rough = np.clip(0.7 - worn * 0.2 + grime * 0.15, 0, 1)
	metal = np.clip(worn * 0.8, 0, 1)
	save_set("outpost_hazard", col, height, 1.4, ao, rough, metal)


only = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
for fn in (wall, floor, grate, paint, bare, hazard):
	if not only or fn.__name__ in only:
		fn()
print("[outpost] done", flush=True)
