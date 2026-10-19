"""Decal textures (res://assets/decals) and the tileable hull plating (res://assets/textures).

Grime, wear, battle damage and laser burns are drawn with numpy noise; the stencilled names, the
registrations, the warnings and the symbols are rendered from fonts and flat shapes in Blender, then
weathered. Decals are painted by Godot's Decal nodes (see scripts/fx/marks.gd); a texture "x" can
come with "x_n" (normals), "x_e" (emission) and "x_orm" (occlusion, roughness, metallic).

White textures are tinted by the decal's colour in the game (names, markings); the others keep
their own colours.

    blender -b -P tools/blender/decals.py
"""

import math
import os
import sys

import bpy
import numpy as np
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lib  # noqa: E402

DECALS = os.path.join(lib.ROOT, "assets", "decals")
TEXTURES = os.path.join(lib.ROOT, "assets", "textures")
FONTS = "C:/Windows/Fonts/"
STENCIL = FONTS + "STENCIL.TTF"
# (Bahnschrift, a variable font, loses parts of some letters in Blender.)
PLAIN = FONTS + "arialbd.ttf"

# Ship names and registrations (ShipTypes "name" / "reg").
NAMES = {"prospector": "PROSPECTOR", "vanguard": "VANGUARD CARRIER", "excavator": "EXCAVATOR", "dreadnought": "DREADNOUGHT"}
REGS = {"prospector": "MF-114", "vanguard": "SC-207", "excavator": "XV-330", "dreadnought": "BD-001"}
# Small painted warnings.
WORDS = {"no_step": "NO STEP", "crew_hatch": "CREW HATCH", "keep_clear": "KEEP CLEAR", "cargo_ramp": "CARGO RAMP",
	"tractor_field": "TRACTOR FIELD", "scout_bay": "SCOUT BAY", "fuel": "FUEL", "jet_blast": "DANGER  JET BLAST"}


# --- Images ----------------------------------------------------------------------------------------

def save(name, rgba, folder=DECALS, normal=False, vram=False):
	"""Save an (h, w, 4) float array (row 0 at the top) as <folder>/<name>.png, with a Godot import
	file: decal textures stay lossless (the renderer copies them into its decal atlas anyway); the
	plating is VRAM-compressed with mipmaps."""
	os.makedirs(folder, exist_ok=True)
	rgba = np.clip(rgba, 0.0, 1.0)
	h, w = rgba.shape[:2]
	img = bpy.data.images.new(name, w, h, alpha=True)
	img.pixels.foreach_set(np.ascontiguousarray(rgba[::-1]).astype(np.float32).ravel())
	path = os.path.join(folder, name + ".png")
	img.filepath_raw = path
	img.file_format = "PNG"
	img.save()
	bpy.data.images.remove(img)
	lib.write_import(path, normal=normal, vram=vram)
	print("[decals]", name, w, h, flush=True)


def rgba(color, alpha):
	h, w = alpha.shape
	out = np.empty((h, w, 4), np.float32)
	for i in range(3):
		out[..., i] = color[i] if np.isscalar(color[i]) else color[i]
	out[..., 3] = alpha
	return out


def mix_rgb(a, b, t):
	return a + (b - a) * t[..., None]


def smooth(e0, e1, x):
	t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


def vnoise(h, w, cell, rng, periodic=False):
	"""Value noise with lattice spacing `cell` pixels (periodic: wraps at the edges, h and w must be
	multiples of cell)."""
	cell = max(1, int(cell))
	if periodic:
		gh, gw = h // cell, w // cell
		grid = rng.random((gh, gw))
	else:
		gh, gw = h // cell + 2, w // cell + 2
		grid = rng.random((gh, gw))
	y = np.arange(h) / cell
	x = np.arange(w) / cell
	y0 = np.floor(y).astype(int)
	x0 = np.floor(x).astype(int)
	fy = y - y0
	fx = x - x0
	fy = fy * fy * (3 - 2 * fy)
	fx = fx * fx * (3 - 2 * fx)
	y1, x1 = y0 + 1, x0 + 1
	if periodic:
		y0, y1, x0, x1 = y0 % gh, y1 % gh, x0 % gw, x1 % gw
	a = grid[np.ix_(y0, x0)]
	b = grid[np.ix_(y0, x1)]
	c = grid[np.ix_(y1, x0)]
	d = grid[np.ix_(y1, x1)]
	sx = fx[None, :]
	sy = fy[:, None]
	return (a + (b - a) * sx) * (1 - sy) + (c + (d - c) * sx) * sy


def fbm(h, w, cell, octaves, rng, periodic=False, gain=0.5):
	total = np.zeros((h, w))
	amp, norm = 1.0, 0.0
	for o in range(octaves):
		total += amp * vnoise(h, w, max(1, cell // (2 ** o)), rng, periodic)
		norm += amp
		amp *= gain
	return total / norm


def blur(a, r, passes=3, periodic=False):
	"""A soft blur: box filters of radius r, a few times."""
	r = int(r)
	if r < 1:
		return a
	out = a.astype(np.float64)
	for _ in range(passes):
		for axis in (0, 1):
			if periodic:
				acc = sum(np.roll(out, k, axis) for k in range(-r, r + 1))
				out = acc / (2 * r + 1)
			else:
				pad = [(0, 0), (0, 0)]
				pad[axis] = (r, r)
				p = np.pad(out, pad, mode="edge")
				c = np.cumsum(p, axis=axis)
				c = np.insert(c, 0, 0, axis=axis)
				n = out.shape[axis]
				idx_hi = np.arange(n) + 2 * r + 1
				idx_lo = np.arange(n)
				out = (np.take(c, idx_hi, axis=axis) - np.take(c, idx_lo, axis=axis)) / (2 * r + 1)
	return out


def grid(h, w):
	"""Pixel centres in -1..1 (x right, y down)."""
	y = (np.arange(h) + 0.5) / h * 2 - 1
	x = (np.arange(w) + 0.5) / w * 2 - 1
	return np.meshgrid(x, y)


def normal_from_height(hgt, strength, periodic=False):
	"""Tangent-space normals (OpenGL style: green up) from a height map."""
	if periodic:
		gx = (np.roll(hgt, -1, 1) - np.roll(hgt, 1, 1)) * 0.5
		gy = (np.roll(hgt, -1, 0) - np.roll(hgt, 1, 0)) * 0.5
	else:
		gy, gx = np.gradient(hgt)
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


def edge_falloff(h, w, margin=0.18):
	"""1 in the middle, 0 at the borders (so a decal never shows its box)."""
	x, y = grid(h, w)
	fx = smooth(1.0, 1.0 - margin * 2, np.abs(x))
	fy = smooth(1.0, 1.0 - margin * 2, np.abs(y))
	return fx * fy


def jagged_radius(h, w, rng, rough=0.25, cell=24):
	"""Distance from the centre (0..1 at the edge of the inscribed circle) with a ragged outline."""
	x, y = grid(h, w)
	r = np.sqrt(x * x + y * y)
	n = fbm(h, w, cell, 4, rng) - 0.5
	return r * (1.0 + n * rough * 2)


def lines(h, w, segs, width):
	"""Distance (pixels) to the nearest of the segments [(x0, y0, x1, y1)] in pixel coordinates."""
	yy, xx = np.mgrid[0:h, 0:w].astype(np.float64) + 0.5
	d = np.full((h, w), 1e9)
	for (x0, y0, x1, y1) in segs:
		dx, dy = x1 - x0, y1 - y0
		ln2 = max(dx * dx + dy * dy, 1e-9)
		t = np.clip(((xx - x0) * dx + (yy - y0) * dy) / ln2, 0, 1)
		px, py = x0 + t * dx, y0 + t * dy
		d = np.minimum(d, np.sqrt((xx - px) ** 2 + (yy - py) ** 2))
	return d


def const(name, color):
	"""A tiny one-colour texture (an ORM for decals whose texture alpha says where it applies)."""
	save(name, np.full((4, 4, 4), (*color, 1.0), np.float32))


# --- Grime and wear (the motherships' hulls) ------------------------------------------------------------

def grime(name, seed, stretch=1.0, color=(0.17, 0.15, 0.12), density=0.85):
	rng = np.random.default_rng(seed)
	s = 256
	n = fbm(s, s, 64, 5, rng)
	fine = fbm(s, s, 16, 3, rng)
	x, y = grid(s, s)
	r = np.sqrt((x / stretch) ** 2 + (y * stretch) ** 2)
	shape = smooth(1.0, 0.35, r + (n - 0.5) * 0.9)
	a = smooth(0.15, 0.85, shape * (0.55 + n * 0.7)) * (0.55 + 0.45 * fine) * density
	a *= edge_falloff(s, s, 0.08)
	col = np.array(color)
	c = rgba(col, a)
	c[..., :3] *= (0.75 + 0.5 * fine)[..., None]
	save(name, c)


def streaks(name, seed, color=(0.14, 0.12, 0.1), runs=9):
	"""Dirt run down from the top edge in uneven drips."""
	rng = np.random.default_rng(seed)
	h, w = 512, 128
	yy = (np.arange(h) + 0.5) / h
	xx = np.arange(w) + 0.5
	a = np.zeros((h, w))
	for _ in range(runs):
		cx = rng.uniform(10, w - 10)
		wd = rng.uniform(2.5, 9.0)
		length = rng.uniform(0.35, 1.0)
		strength = rng.uniform(0.35, 1.0)
		wob = (vnoise(h, 1, 40, rng)[:, 0] - 0.5) * 10
		prof = np.exp(-((xx[None, :] - cx - wob[:, None]) / wd) ** 2)
		fade = smooth(length, length * 0.25, yy)[:, None] * smooth(0.0, 0.04, yy)[:, None]
		a = np.maximum(a, prof * fade * strength)
	n = fbm(h, w, 32, 4, rng)
	wash = smooth(0.95, 0.1, yy)[:, None] * smooth(0.0, 0.05, yy)[:, None] * 0.35 * n
	a = np.clip(a * (0.6 + 0.6 * n) + wash, 0, 1) * edge_falloff(h, w, 0.02)
	x, _ = grid(h, w)
	a *= smooth(1.0, 0.75, np.abs(x))
	save(name, rgba(np.array(color), a * 0.9))


def soot(name, seed):
	"""A plume of soot from a nozzle at the left, spreading to the right."""
	rng = np.random.default_rng(seed)
	h, w = 128, 256
	x, y = grid(h, w)
	u = (x + 1) * 0.5
	spread = 0.15 + u * 0.75
	n = fbm(h, w, 32, 5, rng)
	a = np.exp(-(y / spread) ** 2 * 2.2) * smooth(0.0, 0.08, u) * smooth(1.0, 0.45, u + (n - 0.5) * 0.4)
	a = np.clip(a * (0.65 + 0.7 * n), 0, 1) * edge_falloff(h, w, 0.04)
	save(name, rgba(np.array((0.035, 0.032, 0.03)), a * 0.95))


def soot_round(name, seed):
	rng = np.random.default_rng(seed)
	s = 256
	r = jagged_radius(s, s, rng, 0.35, 32)
	n = fbm(s, s, 24, 4, rng)
	a = smooth(1.0, 0.15, r) * (0.55 + 0.6 * n)
	save(name, rgba(np.array((0.04, 0.035, 0.03)), np.clip(a, 0, 1) * 0.9 * edge_falloff(s, s, 0.05)))


def chips(name, seed):
	"""Chipped paint showing bare metal, thicker towards the middle."""
	rng = np.random.default_rng(seed)
	s = 256
	n = fbm(s, s, 20, 4, rng)
	x, y = grid(s, s)
	r = np.sqrt(x * x + y * y)
	thresh = 0.56 + r * 0.22
	chip = smooth(thresh, thresh + 0.02, n)
	rim = smooth(thresh - 0.05, thresh, n) - chip
	a = np.clip(chip + rim * 0.6, 0, 1) * edge_falloff(s, s, 0.05)
	col = mix_rgb(np.broadcast_to(np.array((0.62, 0.62, 0.6)), (s, s, 3)), np.broadcast_to(np.array((0.18, 0.16, 0.14)), (s, s, 3)),
		np.clip(rim / 0.6, 0, 1))
	out = np.concatenate([col, a[..., None]], axis=2)
	save(name, out)


def dirt_splash(name, seed):
	"""Dust and mud kicked up on the belly: a blotch and droplets round it."""
	rng = np.random.default_rng(seed)
	s = 256
	x, y = grid(s, s)
	r = jagged_radius(s, s, rng, 0.45, 32)
	a = smooth(0.9, 0.2, r) * 0.7
	yy, xx = np.mgrid[0:s, 0:s] + 0.5
	for _ in range(80):
		ang = rng.uniform(0, math.tau)
		dist = rng.uniform(0.3, 0.95) * s * 0.48
		cx = s / 2 + math.cos(ang) * dist
		cy = s / 2 + math.sin(ang) * dist
		rad = rng.uniform(1.2, 4.5) * (1.2 - dist / (s * 0.5))
		d = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2)
		a = np.maximum(a, smooth(rad + 1, rad - 0.5, d) * 0.75)
	n = fbm(s, s, 16, 3, rng)
	a *= (0.7 + 0.5 * n) * edge_falloff(s, s, 0.03)
	save(name, rgba(np.array((0.26, 0.21, 0.15)), np.clip(a, 0, 1)))


# --- Battle damage (hull) --------------------------------------------------------------------------------

def dmg_acid(name, seed):
	"""Alien spit eating into the paint: a pitted dark crater, a yellow-green stain round it, and
	sizzling speckles that glow while it is fresh."""
	rng = np.random.default_rng(seed)
	s = 256
	r = jagged_radius(s, s, rng, 0.4, 28)
	n = fbm(s, s, 12, 4, rng)
	pits = smooth(0.55, 0.75, fbm(s, s, 6, 2, rng))
	core = smooth(0.6, 0.25, r)
	stain = smooth(1.0, 0.55, r) * (1 - core * 0.7)
	a = np.clip(smooth(1.0, 0.75, r) * (0.75 + 0.4 * n), 0, 1)
	col = np.zeros((s, s, 3))
	col[:] = (0.42, 0.45, 0.1)
	col = mix_rgb(col, np.broadcast_to(np.array((0.05, 0.045, 0.03)), (s, s, 3)), np.clip(core * (0.8 + 0.4 * pits), 0, 1))
	col *= (0.8 + 0.3 * n)[..., None]
	save(name, np.concatenate([col, (a * edge_falloff(s, s, 0.04))[..., None]], axis=2))
	hgt = -core * 0.6 - pits * core * 0.8 + stain * 0.1
	save(name + "_n", normal_from_height(blur(hgt, 1), 18.0))
	glow = smooth(0.62, 0.8, fbm(s, s, 8, 3, rng)) * core
	e = rgba(np.array((0.6, 1.0, 0.15)), np.ones((s, s)))
	e[..., :3] *= glow[..., None]
	save(name + "_e", e)


def dmg_claw(name, seed):
	"""Claw gouges: three or four grooves through the paint to bright metal."""
	rng = np.random.default_rng(seed)
	s = 256
	segs = []
	count = rng.integers(3, 5)
	ang = rng.uniform(-0.35, 0.35)
	for i in range(count):
		off = (i - (count - 1) / 2) * rng.uniform(26, 34)
		x0, y0 = s / 2 + off - 70 * math.sin(ang), 30
		x1, y1 = s / 2 + off + 70 * math.sin(ang) + rng.uniform(-10, 10), s - 30 - rng.uniform(0, 40)
		mx, my = (x0 + x1) / 2 + rng.uniform(-8, 8), (y0 + y1) / 2
		segs.append((x0, y0, mx, my))
		segs.append((mx, my, x1, y1))
	d = lines(s, s, segs, 1)
	n = fbm(s, s, 8, 3, rng)
	groove = smooth(6.0, 2.0, d + (n - 0.5) * 3)
	halo = smooth(16.0, 4.0, d + (n - 0.5) * 8)
	a = np.clip(groove + halo * 0.55, 0, 1) * edge_falloff(s, s, 0.06)
	col = mix_rgb(np.broadcast_to(np.array((0.2, 0.18, 0.16)), (s, s, 3)), np.broadcast_to(np.array((0.7, 0.7, 0.68)), (s, s, 3)), groove)
	save(name, np.concatenate([col, a[..., None]], axis=2))
	save(name + "_n", normal_from_height(blur(-groove, 1), 6.0))


def dmg_dent(name, seed):
	"""A dent from a hard knock: a bowl with paint crazed and scuffed off round it."""
	rng = np.random.default_rng(seed)
	s = 256
	r = jagged_radius(s, s, rng, 0.25, 32)
	x, y = grid(s, s)
	bowl = np.exp(-(r / 0.45) ** 2)
	segs = []
	for _ in range(int(rng.integers(4, 7))):
		ang = rng.uniform(0, math.tau)
		px, py, rad = s / 2, s / 2, 0.0
		while rad < s * 0.36:
			step = rng.uniform(8, 16)
			ang += rng.uniform(-0.6, 0.6)
			nx, ny = px + math.cos(ang) * step, py + math.sin(ang) * step
			segs.append((px, py, nx, ny))
			px, py = nx, ny
			rad = math.hypot(px - s / 2, py - s / 2)
	cracks = smooth(1.8, 0.4, lines(s, s, segs, 1)) * smooth(0.95, 0.5, r)
	n = fbm(s, s, 10, 4, rng)
	scuff = smooth(0.5, 0.65, n) * smooth(0.9, 0.3, r)
	a = np.clip(smooth(1.0, 0.6, r) * 0.55 + scuff * 0.6 + cracks * 0.7, 0, 1) * edge_falloff(s, s, 0.05)
	col = np.zeros((s, s, 3))
	col[:] = (0.24, 0.23, 0.22)
	col = mix_rgb(col, np.broadcast_to(np.array((0.6, 0.6, 0.58)), (s, s, 3)), scuff)
	col = mix_rgb(col, np.broadcast_to(np.array((0.06, 0.06, 0.06)), (s, s, 3)), np.clip(cracks, 0, 1))
	save(name, np.concatenate([col, a[..., None]], axis=2))
	save(name + "_n", normal_from_height(blur(-bowl * 22 - cracks * 1.5, 1), 1.4))


def dmg_scrape(name, seed):
	"""Grinding along rock: long scratches to bare metal and a smear of rock dust, left to right."""
	rng = np.random.default_rng(seed)
	h, w = 128, 512
	segs = []
	for _ in range(46):
		y = rng.uniform(16, h - 16)
		x0 = rng.uniform(10, w * 0.5)
		x1 = x0 + rng.uniform(w * 0.2, w * 0.6)
		segs.append((x0, y, min(x1, w - 10), y + rng.uniform(-3, 3)))
	d = lines(h, w, segs, 1)
	n = fbm(h, w, 16, 4, rng)
	scratch = smooth(1.6, 0.4, d)
	_, yv = grid(h, w)
	xv, _ = grid(h, w)
	smear = smooth(1.0, 0.3, np.abs(yv)) * smooth(1.0, 0.5, np.abs(xv)) * (0.4 + 0.6 * n)
	a = np.clip(scratch * 0.9 + smear * 0.55, 0, 1) * edge_falloff(h, w, 0.03)
	col = mix_rgb(np.broadcast_to(np.array((0.2, 0.19, 0.18)), (h, w, 3)), np.broadcast_to(np.array((0.72, 0.72, 0.7)), (h, w, 3)), scratch)
	save(name, np.concatenate([col, a[..., None]], axis=2))
	save(name + "_n", normal_from_height(blur(-scratch, 1), 3.0))


# --- Laser burns (cave rock) ------------------------------------------------------------------------------

def burn_rock(name, seed):
	"""Rock melted by the mining laser: a glassy black pool with a crust of soot round it, its core
	glowing while hot (the game fades the emission as it cools)."""
	rng = np.random.default_rng(seed)
	s = 256
	r = jagged_radius(s, s, rng, 0.35, 24)
	n = fbm(s, s, 12, 4, rng)
	pool = smooth(0.55, 0.38, r)
	sootr = smooth(1.0, 0.45, r)
	a = np.clip(sootr * (0.6 + 0.5 * n) + pool, 0, 1) * edge_falloff(s, s, 0.04)
	col = np.zeros((s, s, 3))
	col[:] = (0.07, 0.065, 0.06)
	col = mix_rgb(col, np.broadcast_to(np.array((0.015, 0.014, 0.014)), (s, s, 3)), pool)
	col *= (0.8 + 0.4 * n)[..., None]
	save(name, np.concatenate([col, a[..., None]], axis=2))
	ripple = np.sin(r * 40 + n * 6) * 0.15 * pool + pool * 0.5 - smooth(0.62, 0.5, r) * 0.3
	bubbles = smooth(0.7, 0.8, fbm(s, s, 5, 2, rng)) * pool * 0.4
	save(name + "_n", normal_from_height(blur(ripple + bubbles, 1), 9.0))
	orm = np.zeros((s, s, 4), np.float32)
	orm[..., 0] = 1.0 - sootr * 0.3
	orm[..., 1] = 0.92 - pool * 0.8
	orm[..., 2] = 0.0
	orm[..., 3] = 1.0
	save(name + "_orm", orm)
	veins = smooth(0.47, 0.5, fbm(s, s, 16, 3, rng)) * (1 - smooth(0.47, 0.53, fbm(s, s, 16, 3, rng)))
	heat = np.clip(smooth(0.7, 0.0, r) * 1.2 + veins * smooth(0.95, 0.3, r) * 0.7, 0, 1)
	col_e = np.zeros((s, s, 3))
	col_e[:] = (1.0, 0.42, 0.08)
	col_e = mix_rgb(col_e, np.broadcast_to(np.array((1.0, 0.9, 0.6)), (s, s, 3)), smooth(0.3, 0.0, r))
	col_e *= heat[..., None]
	save(name + "_e", np.concatenate([col_e, np.ones((s, s, 1))], axis=2))


# --- Stencils: names, registrations, warnings, symbols ------------------------------------------------------

_EMIT = None


def _emit_mat():
	global _EMIT
	if _EMIT is None or _EMIT.name not in bpy.data.materials:
		m = bpy.data.materials.new("White")
		m.use_nodes = True
		t = m.node_tree
		t.nodes.clear()
		e = t.nodes.new("ShaderNodeEmission")
		e.inputs["Strength"].default_value = 1.0
		e.inputs["Color"].default_value = (1, 1, 1, 1)
		o = t.nodes.new("ShaderNodeOutputMaterial")
		t.links.new(e.outputs[0], o.inputs[0])
		_EMIT = m
	return _EMIT


def _clear():
	for o in list(bpy.data.objects):
		bpy.data.objects.remove(o)


def text_obj(body, font, x=0.0, y=0.0, size=1.0, spacing=1.0):
	cu = bpy.data.curves.new("T", "FONT")
	cu.body = body
	cu.font = bpy.data.fonts.load(font, check_existing=True)
	cu.size = size
	cu.space_character = spacing
	cu.align_x = "CENTER"
	cu.align_y = "CENTER"
	ob = bpy.data.objects.new("T", cu)
	ob.location = (x, y, 0)
	ob.data.materials.append(_emit_mat())
	bpy.context.scene.collection.objects.link(ob)
	return ob


def poly_obj(rings):
	"""A flat filled shape: the first ring is the outline, the rest holes are not supported, so
	shapes with holes are built from several outlines (each a list of (x, y))."""
	import bmesh
	me = bpy.data.meshes.new("P")
	bm = bmesh.new()
	for ring in rings:
		vs = [bm.verts.new((x, y, 0)) for x, y in ring]
		bm.faces.new(vs)
	bmesh.ops.triangulate(bm, faces=bm.faces[:])
	bm.to_mesh(me)
	bm.free()
	me.materials.append(_emit_mat())
	ob = bpy.data.objects.new("P", me)
	bpy.context.scene.collection.objects.link(ob)
	return ob


def annulus(cx, cy, r0, r1, segs=96, a0=0.0, a1=math.tau):
	"""Quads between two circles (a ring), as outlines for poly_obj."""
	out = []
	for i in range(segs):
		t0 = a0 + (a1 - a0) * i / segs
		t1 = a0 + (a1 - a0) * (i + 1) / segs
		out.append([(cx + math.cos(t0) * r0, cy + math.sin(t0) * r0), (cx + math.cos(t0) * r1, cy + math.sin(t0) * r1),
			(cx + math.cos(t1) * r1, cy + math.sin(t1) * r1), (cx + math.cos(t1) * r0, cy + math.sin(t1) * r0)])
	return out


def star(cx, cy, r, points=5):
	pts = []
	for i in range(points * 2):
		a = math.pi / 2 + math.pi * i / points
		rr = r if i % 2 == 0 else r * 0.42
		pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
	return [[(cx, cy), pts[i], pts[(i + 1) % len(pts)]] for i in range(len(pts))]


def render(px_h, pad=0.06, square=False):
	"""Render the white shapes in the scene from above to an (h, w) coverage array."""
	scene = bpy.context.scene
	bpy.context.view_layer.update()
	lo = np.array([1e9, 1e9])
	hi = np.array([-1e9, -1e9])
	for o in scene.objects:
		if o.type in ("FONT", "MESH"):
			for c in o.bound_box:
				p = o.matrix_world @ Vector(c)
				lo = np.minimum(lo, (p.x, p.y))
				hi = np.maximum(hi, (p.x, p.y))
	size = hi - lo
	if square:
		size[:] = size.max()
	w = size[0] * (1 + 2 * pad)
	h = size[1] * (1 + 2 * pad) if not square else w
	ctr = (lo + hi) / 2
	cam_d = bpy.data.cameras.new("C")
	cam_d.type = "ORTHO"
	cam_d.ortho_scale = max(w, h)
	cam = bpy.data.objects.new("C", cam_d)
	cam.location = (ctr[0], ctr[1], 10)
	scene.collection.objects.link(cam)
	scene.camera = cam
	scene.render.resolution_y = px_h
	scene.render.resolution_x = max(8, int(round(px_h * w / h)))
	scene.render.resolution_percentage = 100
	scene.render.film_transparent = True
	scene.render.image_settings.color_mode = "RGBA"
	scene.view_settings.view_transform = "Standard"
	scene.cycles.samples = 16
	scene.cycles.use_denoising = False
	scene.cycles.filter_width = 1.0
	path = os.path.join(lib.PREVIEW, "_stencil.png")
	os.makedirs(lib.PREVIEW, exist_ok=True)
	scene.render.filepath = path
	bpy.ops.render.render(write_still=True)
	img = bpy.data.images.load(path, check_existing=False)
	px = np.array(img.pixels[:], np.float32).reshape(img.size[1], img.size[0], 4)[::-1]
	bpy.data.images.remove(img)
	bpy.data.objects.remove(cam)
	_clear()
	return px[..., 3]


def weather(a, seed, chips=0.5, cell=None):
	"""Painted, then worn: small flakes off where the noise is high, and the paint is uneven."""
	rng = np.random.default_rng(seed)
	h, w = a.shape
	cell = cell or max(4, h // 10)
	n = fbm(h, w, cell, 4, rng)
	lim = 0.78 - chips * 0.06
	flakes = smooth(lim, lim + 0.03, n)
	uneven = 0.84 + 0.16 * fbm(h, w, max(2, cell // 3), 3, rng)
	return a * (1 - flakes * 0.85) * uneven


def stencil_text(name, body, font, px_h, seed, spacing=1.0, chips=0.5):
	text_obj(body, font, spacing=spacing)
	a = render(px_h)
	a = weather(a, seed, chips)
	save(name, rgba(np.ones(3), a))


def symbols():
	# Hazard triangle with an exclamation mark.
	tri = [(0, 1.0), (-1.1, -0.9), (1.1, -0.9)]
	inner = [(0, 0.62), (-0.8, -0.72), (0.8, -0.72)]
	edges = []
	for i in range(3):
		j = (i + 1) % 3
		edges.append([tri[i], tri[j], inner[j], inner[i]])
	poly_obj(edges)
	poly_obj([[(-0.08, 0.38), (0.08, 0.38), (0.06, -0.25), (-0.06, -0.25)]])
	poly_obj(annulus(0, -0.44, 0.0, 0.09, 24))
	save("sym_hazard", rgba(np.ones(3), weather(render(256, square=True), 11, 0.4)))
	# An arrow pointing right.
	poly_obj([[(-1.0, 0.18), (0.3, 0.18), (0.3, 0.5), (1.0, 0.0), (0.3, -0.5), (0.3, -0.18), (-1.0, -0.18)]])
	save("sym_arrow", rgba(np.ones(3), weather(render(128), 12, 0.4)))
	# The mining guild's emblem: a ring, a cut crystal over two crossed picks, three stars.
	poly_obj(annulus(0, 0, 0.86, 1.0))
	poly_obj(annulus(0, 0, 0.72, 0.76))
	for sgn in (-1, 1):
		ang = math.radians(48 * sgn)
		dx, dy = math.sin(ang), math.cos(ang)
		px, py = -dy * 0.035, dx * 0.035
		hx, hy = dx * 0.62, dy * 0.62
		poly_obj([[(-hx + px, -hy - 0.1 + py), (hx + px, hy - 0.1 + py), (hx - px, hy - 0.1 - py), (-hx - px, -hy - 0.1 - py)]])
		tip = (hx - 0.1 * sgn, hy - 0.1)
		poly_obj([[(tip[0] - dy * 0.2, tip[1] + dx * 0.2), (tip[0] + dy * 0.22, tip[1] - dx * 0.22), (tip[0] + dx * 0.09, tip[1] + dy * 0.09)]])
	poly_obj([[(0, 0.5), (0.24, 0.24), (0.24, -0.2), (0, -0.44), (0.0, 0.5)]])
	poly_obj([[(-0.02, 0.5), (-0.02, -0.44), (-0.24, -0.2), (-0.24, 0.24)]])
	for i, ang in enumerate((-0.42, 0.0, 0.42)):
		poly_obj(star(math.sin(ang) * 0.52, -math.cos(ang) * 0.52 - 0.02, 0.085))
	save("sym_emblem", rgba(np.ones(3), weather(render(512, square=True), 13, 0.35)))
	# A lifting point: ring and cross.
	poly_obj(annulus(0, 0, 0.78, 1.0))
	poly_obj([[(-0.06, -0.65), (0.06, -0.65), (0.06, 0.65), (-0.06, 0.65)], [(-0.65, -0.06), (0.65, -0.06), (0.65, 0.06), (-0.65, 0.06)]])
	save("sym_ring", rgba(np.ones(3), weather(render(256, square=True), 14, 0.4)))


def walkway():
	"""Two dashed lines either side of a walkway (yellow, baked in), stretched along its length."""
	h, w = 64, 1024
	a = np.zeros((h, w))
	xs = np.arange(w)
	dash = ((xs // 48) % 2 == 0).astype(float)
	for y0 in (6, h - 14):
		a[y0:y0 + 8, :] = dash[None, :]
	a = blur(a, 1, 1)
	a = weather(a, 21, 0.6, 16) * edge_falloff(h, w, 0.005)
	save("walkway", rgba(np.array((0.95, 0.76, 0.15)), a))


def chevrons():
	"""Yellow and black hazard stripes (colours baked in)."""
	h, w = 64, 512
	yy, xx = np.mgrid[0:h, 0:w]
	band = (((xx + yy) // 32) % 2 == 0)
	col = np.where(band[..., None], np.array((0.95, 0.74, 0.1)), np.array((0.03, 0.03, 0.03)))
	a = weather(np.ones((h, w)), 22, 0.5, 16)
	save("chevrons", np.concatenate([col, a[..., None]], axis=2))


# --- Hull plating (tileable) -----------------------------------------------------------------------------

def plating():
	"""Painted hull plates, 4 m to the tile at 1024 px: rows of plates of uneven widths, seams, rivet
	lines, a slight tone per plate. Near-white: the material's colour paints it."""
	rng = np.random.default_rng(31)
	s = 1024
	rows = [208, 200, 208, 200, 208]
	plate_id = np.zeros((s, s), int)
	seam_d = np.full((s, s), 1e9)
	rivet = np.zeros((s, s))
	tint = np.zeros((s, s))
	bulge = np.zeros((s, s))
	y0 = 0
	pid = 0
	xx = np.arange(s)
	for r, rh in enumerate(rows):
		widths = []
		left = s
		while left > 0:
			wv = int(rng.integers(230, 430))
			if left - wv < 200:
				wv = left
			widths.append(wv)
			left -= wv
		off = int(rng.integers(0, s))
		edges = np.cumsum([0] + widths)
		ys = np.arange(y0, y0 + rh)
		xpos = (xx + off) % s
		idx = np.searchsorted(edges, xpos, side="right") - 1
		left_e = edges[idx]
		right_e = edges[idx + 1]
		dx = np.minimum(xpos - left_e, right_e - xpos)
		dy = np.minimum(ys - y0, y0 + rh - ys)
		seam_d[y0:y0 + rh, :] = np.minimum(dx[None, :], dy[:, None])
		shades = rng.normal(0.0, 0.03, len(widths))
		tint[y0:y0 + rh, :] = shades[idx][None, :]
		u = (xpos - left_e) / (right_e - left_e)
		v = (ys - y0) / rh
		bulge[y0:y0 + rh, :] = (np.sin(u * math.pi)[None, :] * np.sin(v * math.pi)[:, None])
		plate_id[y0:y0 + rh, :] = (idx + pid)[None, :]
		# Rivets: a line 9 px in from each plate's top and bottom edge, every 32 px.
		for yr in (y0 + 9, y0 + rh - 10):
			for xr in range(0, s, 32):
				cx = (xr - off) % s
				rivet_d = np.sqrt(((xx - cx + s // 2) % s - s // 2)[None, :] ** 2 + (np.arange(s) - yr)[:, None] ** 2)
				rivet = np.maximum(rivet, smooth(3.4, 1.6, rivet_d))
		y0 += rh
		pid += len(widths)
	seam = smooth(2.6, 0.8, seam_d)
	noise = fbm(s, s, 128, 6, rng, periodic=True)
	fine = fbm(s, s, 16, 3, rng, periodic=True)
	base = 0.9 + tint + (noise - 0.5) * 0.05 + (fine - 0.5) * 0.025
	alb = np.clip(base - seam * 0.5 + rivet * 0.03, 0, 1)
	col = np.stack([alb, alb, alb * 0.985, np.ones((s, s))], axis=2)
	save("hull_plating_albedo", col, TEXTURES, vram=True)
	hgt = bulge * 1.2 - seam * 2.2 + rivet * 1.4 + (noise - 0.5) * 0.6
	save("hull_plating_normal", normal_from_height(blur(hgt, 1, 2, periodic=True), 2.2, periodic=True), TEXTURES, normal=True, vram=True)
	orm = np.zeros((s, s, 4), np.float32)
	orm[..., 0] = 1.0 - seam * 0.45
	orm[..., 1] = np.clip(0.5 + (fine - 0.5) * 0.12 + (noise - 0.5) * 0.12 + seam * 0.2 - rivet * 0.1, 0, 1)
	orm[..., 2] = 0.25 + rivet * 0.3
	orm[..., 3] = 1.0
	save("hull_plating_orm", orm, TEXTURES, vram=True)


# --- Run ----------------------------------------------------------------------------------------------------

lib.reset()
_clear()
os.makedirs(DECALS, exist_ok=True)
const("orm_matte", (1.0, 0.92, 0.0))
const("orm_metal", (1.0, 0.35, 1.0))
const("orm_paint", (1.0, 0.55, 0.1))
grime("grime_a", 1)
grime("grime_b", 2, stretch=1.6)
grime("grime_c", 3, stretch=0.8, color=(0.2, 0.17, 0.13))
streaks("streaks_a", 4)
streaks("streaks_b", 5, runs=14)
streaks("rust", 6, color=(0.36, 0.18, 0.08), runs=7)
soot("soot", 7)
soot_round("soot_round", 8)
chips("chips", 9)
dirt_splash("dirt", 10)
dmg_acid("dmg_acid_a", 41)
dmg_acid("dmg_acid_b", 42)
dmg_claw("dmg_claw", 43)
dmg_dent("dmg_dent", 44)
dmg_scrape("dmg_scrape", 45)
burn_rock("burn_a", 51)
burn_rock("burn_b", 52)
for sid, nm in NAMES.items():
	stencil_text("name_" + sid, nm, STENCIL, 160, 60 + len(nm), spacing=1.05, chips=0.45)
for sid, rg in REGS.items():
	stencil_text("reg_" + sid, rg, STENCIL, 160, 70 + len(rg), spacing=1.05, chips=0.45)
for key, word in WORDS.items():
	stencil_text("txt_" + key, word, PLAIN, 96, 80 + len(word), chips=0.3)
symbols()
walkway()
chevrons()
plating()
print("[decals] done", flush=True)
