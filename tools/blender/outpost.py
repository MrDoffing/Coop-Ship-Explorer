"""Tiling textures for the abandoned outposts (res://assets/textures, used by DerelictBuilder):

- outpost_wall: olive-drab steel wall panels, 1 m wide and 2 m tall to the 2 m tile: the lower part
  of each ribbed, the upper part a raised inset panel, rivets along the seams, the paint chipped at
  the edges and the ribs' crests, grime gathered low down and run down in streaks.
- outpost_floor: steel tread plate, plates of 1 m with the raised diamond pattern, worn shiny on
  top, dirt in the seams and patches of rust.
- outpost_grate: bar grating for the corridors and the pier, 1 m to the tile: bearing bars with
  cross rods over a dark pit.

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
	noise = fbm(s, s, 128, 5, rng)
	fine = fbm(s, s, 16, 3, rng)
	dirt = smooth(0.48, 0.75, noise) * 0.8 + seam * 0.6
	rust = smooth(0.66, 0.8, fbm(s, s, 64, 4, rng)) * 0.7
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
	dirt = smooth(0.45, 0.8, noise) * 0.7
	steel = 0.42 + (fine - 0.5) * 0.1
	pit = 0.025
	r = mix(pit, mix(steel, 0.12, dirt), solid)
	g = mix(pit, mix(steel, 0.11, dirt), solid)
	bl = mix(pit, mix(steel * 0.97, 0.09, dirt), solid)
	albedo = rgb(r, g, bl)
	height = bar * 1.5 + rod * 1.0 - (1.0 - solid) * 1.5
	ao = np.clip(0.15 + solid * 0.85 - rod * bar * 0.1, 0, 1)
	rough = np.clip(mix(1.0, 0.45 + dirt * 0.35, solid), 0, 1)
	metal = np.clip(solid * (0.85 - dirt * 0.5), 0, 1)
	save_set("outpost_grate", albedo, height, 3.0, ao, rough, metal)


wall()
floor()
grate()
print("[outpost] done", flush=True)
