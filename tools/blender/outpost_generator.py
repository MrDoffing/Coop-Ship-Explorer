"""The outposts' gas generator (OutpostProps._generator): a V8 engine on a skid, in the piece's frame
(its floor point under the middle, the long side along z, the flywheel end at -z, the radiator at
+z; footprint 2.4 x 4.8 m).

Objects in the .gltf:
- "Skid": the base frame with its rails, cross members and drip tray (static).
- "Engine": the crankcase and sump, two banks of four finned cylinders, heads and valve covers, the
  intake and air filter, the exhaust manifolds up to the stacks' flanges (x +-0.85, z 0.6, y 2.4),
  the radiator with its grille and hoses, the bell housing, the starter and oil filter (the game
  shakes this while it runs).
- "Flywheel": the flywheel round its own centre (the game puts it at (0, 1.1, -2.15) and spins it
  about z): rim with the starter ring's teeth, spokes, hub and a painted index mark.
The control box, the pull starter, the exhaust stacks above the flanges and the lamp stay in code.

    blender -b -P tools/blender/outpost_generator.py
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lib  # noqa: E402

lib.reset()
K = lib.kind
K("Olive", (0.36, 0.4, 0.24), 0.3, 0.66, wear=0.55, grime=0.65, scratch=0.45, edge=0.015, streaks=0.4)
K("OliveDark", (0.24, 0.27, 0.17), 0.3, 0.7, wear=0.45, grime=0.7, scratch=0.4, edge=0.012)
K("Block", (0.22, 0.23, 0.21), 0.55, 0.55, wear=0.35, grime=0.8, scratch=0.3, edge=0.01, bare=(0.5, 0.5, 0.48))
K("Fins", (0.16, 0.16, 0.15), 0.6, 0.5, grime=0.75, wear=0.4, edge=0.004, bare=(0.55, 0.54, 0.5))
K("Steel", (0.5, 0.5, 0.48), 0.85, 0.4, grime=0.5, scratch=0.5)
K("Gunmetal", (0.17, 0.17, 0.18), 0.75, 0.45, wear=0.6, grime=0.6, scratch=0.5, bare=(0.6, 0.6, 0.6), edge=0.012)
K("Brass", (0.74, 0.54, 0.26), 0.9, 0.38, grime=0.55, scratch=0.35)
K("Rust", (0.36, 0.22, 0.13), 0.4, 0.8, grime=0.6, noise=0.25, wear=0.3, bare=(0.3, 0.27, 0.24), edge=0.01)
K("Rubber", (0.06, 0.06, 0.055), 0.0, 0.85, grime=0.5, noise=0.1)
K("Dark", (0.08, 0.08, 0.085), 0.45, 0.62, wear=0.3, grime=0.5, edge=0.01, bare=(0.45, 0.45, 0.45))
K("Stripes", (0.72, 0.54, 0.1), 0.2, 0.62, wear=0.6, grime=0.6, edge=0.01, stripes=(0, 0, 0, 0.16))
K("Yellow", (0.75, 0.56, 0.12), 0.2, 0.62, wear=0.55, grime=0.55, edge=0.01)
K("Red", (0.55, 0.12, 0.08), 0.2, 0.62, wear=0.5, grime=0.5, edge=0.01)
K("Oil", (0.03, 0.03, 0.025), 0.2, 0.15, noise=0.2)

HALF_Z = 2.4
WHEEL = (0.0, 1.1, -2.15)
TILT = 27.0


def hexbolt(part, pos, rot, r=0.018, h=0.016, kind="Steel"):
	part.cyl(pos, r, h, kind, rot=rot, sides=6, bevel=0.002, smooth=False)


# --- Skid ------------------------------------------------------------------------------------------
skid = lib.Part("Skid")
for sx in (-1.0, 1.0):
	# C-channel rails, hazard-striped on their outer faces.
	x = sx * 1.08
	skid.box((x, 0.18, 0), (0.22, 0.04, 4.8), "Gunmetal", bevel=0.006)
	skid.box((x, 0.02, 0), (0.22, 0.04, 4.8), "Gunmetal", bevel=0.006)
	skid.box((x + sx * 0.09, 0.1, 0), (0.04, 0.2, 4.8), "Gunmetal", bevel=0.006)
	skid.box((x + sx * 0.112, 0.1, 0), (0.004, 0.14, 4.7), "Stripes", bevel=0)
	for z in (-2.25, 2.25):
		skid.torus((x + sx * 0.14, 0.12, z), 0.05, 0.014, "Steel", rot=(0, 0, 90), maj_seg=16, min_seg=6)
for z in (-2.1, -1.2, -0.3, 0.6, 1.5, 2.2):
	skid.box((0, 0.12, z), (2.0, 0.16, 0.12), "Gunmetal", bevel=0.008)
# The drip tray, oily.
skid.box((0, 0.07, -0.35), (1.7, 0.03, 3.6), "Dark", bevel=0.004)
for sx in (-1.0, 1.0):
	skid.box((sx * 0.85, 0.11, -0.35), (0.03, 0.08, 3.6), "Dark", bevel=0.004)
for z in (-1.75, 1.05):
	skid.box((0, 0.11, z), (1.7, 0.08, 0.03), "Dark", bevel=0.004)
skid.cyl((0.3, 0.088, -0.6), 0.45, 0.004, "Oil", sides=20, bevel=0)
skid.cyl((-0.25, 0.088, 0.3), 0.3, 0.004, "Oil", sides=16, bevel=0)
# Engine mounts: rubber blocks under steel brackets.
for sx in (-1.0, 1.0):
	for z in (-1.35, 0.55):
		skid.box((sx * 0.7, 0.27, z), (0.26, 0.1, 0.3), "Rubber", bevel=0.01)
		skid.box((sx * 0.7, 0.35, z), (0.3, 0.05, 0.34), "Gunmetal", bevel=0.006)
skid_o = skid.build()

# --- Engine ----------------------------------------------------------------------------------------
eng = lib.Part("Engine")
# Crankcase and sump.
eng.box((0, 0.72, -0.45), (1.2, 0.64, 2.55), "Block", bevel=0.04)
eng.box((0, 0.44, -0.45), (1.04, 0.2, 2.3), "Gunmetal", bevel=0.02)
for z in (-1.55, -0.95, -0.35, 0.25, 0.75):
	eng.box((0, 0.44, z), (1.1, 0.06, 0.03), "Gunmetal", bevel=0.005)
for sx in (-1.0, 1.0):
	for i in range(9):
		hexbolt(eng, (sx * 0.53, 0.55, -1.6 + i * 0.29), (0, 0, 90), 0.014, 0.014)
	# Mount brackets down to the skid's.
	for z in (-1.35, 0.55):
		eng.box((sx * 0.64, 0.46, z), (0.12, 0.2, 0.26), "Block", bevel=0.01)
# Cylinder banks at +-TILT degrees, four cylinders each, finned barrels under one head per bank.
for sx in (-1.0, 1.0):
	a = math.radians(TILT) * sx
	ax = (math.sin(a), math.cos(a), 0.0)
	base = (sx * 0.3, 1.0, 0.0)

	def along(t, z):
		return (base[0] + ax[0] * t, base[1] + ax[1] * t, z)
	rot = (0, 0, -TILT * sx)
	for i in range(4):
		z = -1.35 + i * 0.62
		eng.cyl(along(0.18, z), 0.19, 0.36, "Block", rot=rot, sides=20)
		for f in range(6):
			eng.cyl(along(0.06 + f * 0.055, z), 0.245, 0.018, "Fins", rot=rot, sides=24, bevel=0.003)
		# Spark plug lead from the head's side.
		p = along(0.46, z)
		eng.strut((p[0] + sx * 0.18, p[1], z + 0.12), (p[0] + sx * 0.36, p[1] + 0.16, z + 0.2), 0.012, "Rubber", sides=6)
	with eng.at(along(0.47, -0.42), rot):
		eng.box((0, 0, 0), (0.5, 0.18, 2.5), "Block", bevel=0.025)
		eng.box((0, 0.13, 0), (0.38, 0.1, 2.36), "Brass", bevel=0.03)
		for i in range(5):
			eng.box((0, 0.185, -1.0 + i * 0.5), (0.3, 0.02, 0.05), "Brass", bevel=0.006)
		for i in range(10):
			for cx in (-0.17, 0.17):
				hexbolt(eng, (cx, 0.12, -1.13 + i * 0.25), (0, 0, 0), 0.015, 0.02)
		eng.cyl((0, 0.21, 1.0), 0.05, 0.08, "Dark", sides=12)
# Intake between the banks, the air filter on top.
eng.box((0, 1.42, -0.42), (0.34, 0.2, 2.2), "OliveDark", bevel=0.03)
for i in range(4):
	z = -1.35 + i * 0.62
	for sx in (-1.0, 1.0):
		eng.strut((0, 1.45, z), (sx * 0.36, 1.48, z), 0.05, "OliveDark", sides=10)
eng.cyl((0, 1.62, -0.6), 0.09, 0.2, "OliveDark", sides=16)
eng.cyl((0, 1.82, -0.6), 0.34, 0.24, "Olive", sides=28, bevel=0.015)
eng.cyl((0, 1.95, -0.6), 0.3, 0.03, "Gunmetal", sides=28, bevel=0.004)
eng.cyl((0, 1.98, -0.6), 0.05, 0.05, "Brass", sides=6, bevel=0.003)
eng.box((0, 1.82, -0.25), (0.22, 0.08, 0.005), "Yellow", bevel=0)
# Exhaust manifolds along the banks' outsides, up to the stacks' flanges.
for sx in (-1.0, 1.0):
	x = sx * 0.85
	for i in range(4):
		z = -1.35 + i * 0.62
		eng.strut((sx * 0.62, 1.42, z), (x, 1.56, z), 0.055, "Rust", sides=10)
	eng.strut((x, 1.56, -1.45), (x, 1.56, 0.62), 0.09, "Rust", sides=14)
	eng.sphere((x, 1.56, 0.6), 0.09, "Rust", segs=14, rings=8)
	eng.strut((x, 1.56, 0.6), (x, 2.4, 0.6), 0.1, "Rust", sides=14)
	eng.cyl((x, 2.37, 0.6), 0.15, 0.05, "Steel", sides=16)
	for k in range(6):
		b = math.tau * k / 6
		hexbolt(eng, (x + math.cos(b) * 0.12, 2.4, 0.6 + math.sin(b) * 0.12), (0, 0, 0), 0.012, 0.02)
	# Clamps holding the manifold down to the head.
	for z in (-1.0, 0.2):
		eng.torus((x, 1.56, z), 0.1, 0.012, "Steel", rot=(90, 0, 0), maj_seg=20, min_seg=6)
		eng.strut((x - sx * 0.05, 1.5, z), (sx * 0.72, 1.4, z), 0.015, "Steel", sides=6)
# Radiator at +z: shroud, core of fins behind slats, filler cap, hoses to the block.
eng.box((0, 1.0, 1.36), (1.9, 1.7, 0.46), "Olive", bevel=0.03)
eng.box((0, 1.0, 1.6), (1.66, 1.46, 0.04), "Fins", bevel=0)
for i in range(36):
	eng.box((-0.8 + i * 1.6 / 35, 1.0, 1.615), (0.008, 1.42, 0.03), "Dark", bevel=0)
for i in range(9):
	eng.box((0, 0.36 + i * 0.16, 1.645), (1.7, 0.04, 0.025), "OliveDark", rot=(-25, 0, 0), bevel=0.004)
for (cx, cy) in ((-0.9, 0.2), (0.9, 0.2), (-0.9, 1.8), (0.9, 1.8)):
	hexbolt(eng, (cx * 0.98, cy, 1.6), (90, 0, 0), 0.02, 0.02)
eng.cyl((0.5, 1.88, 1.36), 0.07, 0.08, "Brass", sides=14)
eng.strut((0.35, 1.62, 1.12), (0.25, 1.48, 0.62), 0.06, "Rubber", sides=12)
eng.strut((-0.4, 0.6, 1.12), (-0.35, 0.6, 0.75), 0.06, "Rubber", sides=12)
for z in (1.1, 0.68):
	eng.cyl((0.3, 1.55 + (z - 0.68) * 0.15, z), 0.07, 0.02, "Steel", rot=(80, 0, 0), sides=14)
# Bell housing at -z, its bolt ring, the starter motor and the oil filter.
eng.lathe([(0.0, -1.72), (0.56, -1.72), (0.6, -1.76), (0.6, -1.8), (0.48, -1.98), (0.3, -2.02), (0.0, -2.02)], "Block", axis="Z",
	center=(0, 1.1, 0), segs=40)
for k in range(12):
	b = math.tau * k / 12
	hexbolt(eng, (math.cos(b) * 0.57, 1.1 + math.sin(b) * 0.57, -1.81), (90, 0, 0), 0.016, 0.02)
eng.cyl((0.58, 0.72, -1.6), 0.13, 0.42, "Red", rot=(90, 0, 0), sides=18, bevel=0.01)
eng.cyl((0.58, 0.72, -1.38), 0.09, 0.06, "Steel", rot=(90, 0, 0), sides=18)
eng.cyl((-0.62, 0.62, -0.2), 0.1, 0.26, "Yellow", rot=(0, 0, 90), sides=18, bevel=0.01)
eng.cyl((-0.62, 0.62, -0.2), 0.105, 0.03, "Steel", rot=(0, 0, 90), sides=18)
eng.box((-0.605, 0.85, 0.3), (0.01, 0.12, 0.22), "Brass", bevel=0.002)
eng_o = eng.build()

# --- Flywheel (round its own centre, axis z) ------------------------------------------------------------
fw = lib.Part("Flywheel")
c = WHEEL
fw.lathe([(0.64, c[2] - 0.09), (0.78, c[2] - 0.09), (0.79, c[2] - 0.07), (0.79, c[2] + 0.07), (0.78, c[2] + 0.09), (0.64, c[2] + 0.09),
	(0.62, c[2] + 0.06), (0.62, c[2] - 0.06)], "Gunmetal", axis="Z", center=(c[0], c[1], 0), segs=64)
for k in range(72):
	b = math.tau * k / 72
	fw.box((c[0] + math.cos(b) * 0.8, c[1] + math.sin(b) * 0.8, c[2] + 0.06), (0.03, 0.024, 0.05), "Steel", rot=(0, 0, math.degrees(b)), bevel=0.004)
for k in range(5):
	b = math.tau * k / 5
	p0 = (c[0] + math.cos(b) * 0.16, c[1] + math.sin(b) * 0.16, c[2])
	p1 = (c[0] + math.cos(b) * 0.64, c[1] + math.sin(b) * 0.64, c[2])
	fw.box(((p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2, c[2]), (0.5, 0.11, 0.08), "Gunmetal", rot=(0, 0, math.degrees(b)), bevel=0.02)
fw.lathe([(0.0, c[2] - 0.15), (0.17, c[2] - 0.15), (0.2, c[2] - 0.11), (0.2, c[2] + 0.11), (0.17, c[2] + 0.15), (0.0, c[2] + 0.15)], "Brass",
	axis="Z", center=(c[0], c[1], 0), segs=32)
for k in range(6):
	b = math.tau * k / 6
	hexbolt(fw, (c[0] + math.cos(b) * 0.12, c[1] + math.sin(b) * 0.12, c[2] - 0.16), (90, 0, 0), 0.016, 0.02)
fw.box((c[0] + 0.71, c[1], c[2] - 0.091), (0.12, 0.05, 0.004), "Yellow", bevel=0)
fw_o = fw.build(origin=WHEEL)

objs = [skid_o, eng_o, fw_o]
lib.unwrap(objs, margin=0.002)
imgs = lib.bake(objs, 2048, "outpost_generator", ao_distance=0.3)
lib.finalize(objs, imgs)
lib.export(objs, os.path.join(lib.OUT, "outpost_generator", "outpost_generator.gltf"))
lib.preview("outpost_generator", (0, 1.1, -0.2), 7.5, [(-35, 20), (145, 25), (-90, 8), (0, 15)])
