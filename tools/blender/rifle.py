"""The Pulse Rifle (CrewWeapons "rifle"): a stubby, boxy ballistic rifle in the M41A mould.

Objects in the .gltf (the weapon's frame: origin at its middle, barrel along -Z, the sight line on
x = 0; see CrewWeapons._build_rifle):
- "Body": everything fixed: receiver, shroud, barrel, launcher tube, grip, stock, reflex sight frame.
- "Mag": the magazine, its origin where the game's "Mag" node is (it drops out on a reload).
- "Bolt": the bolt handle on the right, which runs back with every shot.
The game adds the sight's glass and reticle, the ammo counter, the muzzle flash. Material
"Accent" is swapped for the owner's colour.

    blender -b -P tools/blender/rifle.py
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lib  # noqa: E402

MAG_AT = (0, -0.06, -0.075)

lib.reset()
K = lib.kind
K("Olive", (0.27, 0.29, 0.21), 0.25, 0.68, wear=0.7, grime=0.45, scratch=0.6, bare=(0.3, 0.31, 0.31), edge=0.004, noise=0.08)
K("Dark", (0.13, 0.135, 0.14), 0.6, 0.45, wear=0.6, grime=0.4, scratch=0.5, bare=(0.45, 0.45, 0.46), edge=0.003)
K("Steel", (0.33, 0.34, 0.35), 0.85, 0.3, grime=0.35, scratch=0.5, wear=0.3, bare=(0.6, 0.6, 0.6), edge=0.002)
K("Gun", (0.18, 0.19, 0.2), 0.75, 0.38, wear=0.6, grime=0.4, scratch=0.5, bare=(0.5, 0.5, 0.5), edge=0.003)
K("Grip", (0.1, 0.088, 0.075), 0.05, 0.85, grime=0.5, noise=0.2, wear=0.3, bare=(0.2, 0.18, 0.16), edge=0.003)
K("Black", (0.025, 0.025, 0.025), 0.2, 0.85, grime=0.2)
K("Brass", (0.78, 0.58, 0.25), 0.9, 0.3, grime=0.3)
K("Accent", (0.95, 0.95, 0.95), 0.0, 0.5, export_as="Accent")


def screw(part, pos, side, r=0.003):
	"""A screw head on the left (side -1) or right (side 1) face at `pos`."""
	prof = [(0.0, 0.0), (r, 0.0), (r, 0.0012), (r * 0.7, 0.0018), (0.0, 0.0018)]
	part.lathe([(rr, side * h) for rr, h in prof], "Steel", axis="X", center=pos, segs=10)


body = lib.Part("Body")

# Upper receiver, with an ejection port cut in its right side and a slot for the bolt handle.
up = lib.Part("Upper")
up.profile([(-0.235, 0.044), (0.165, 0.044), (0.19, 0.03), (0.19, -0.006), (-0.235, -0.006)], -0.033, 0.033, "Olive", bevel=0.003)
uo = up.build()
cut = lib.Part("Cut")
cut.box((0.036, 0.021, -0.04), (0.014, 0.019, 0.056), "Dark", bevel=0.002)
cut.box((0.036, 0.025, 0.045), (0.014, 0.008, 0.075), "Dark", bevel=0.0015)
lib.boolean(uo, cut.build())
body.merge_object(uo)
body.box((0.026, 0.021, -0.04), (0.004, 0.019, 0.054), "Dark", bevel=0.0008)
body.box((0.0285, 0.021, -0.04), (0.002, 0.004, 0.01), "Brass", bevel=0.0005)
# The rail on top in front of the sight (the ammo counter sits behind it).
for z0, z1 in ((-0.22, -0.005),):
	body.box((0, 0.047, (z0 + z1) / 2), (0.03, 0.006, z1 - z0), "Gun", bevel=0.0012)
	z = z0 + 0.006
	while z < z1 - 0.004:
		body.box((0, 0.052, z), (0.034, 0.004, 0.006), "Gun", bevel=0.0008)
		z += 0.012
# Pins and screws along the receiver.
for z in (-0.2, -0.13, 0.12):
	for s in (-1, 1):
		screw(body, (s * 0.033, 0.006, z), s, 0.0035)

# Lower receiver with the flared magazine well and the trigger guard.
body.profile([(-0.118, -0.006), (0.155, -0.006), (0.155, -0.035), (0.13, -0.05), (0.06, -0.056), (-0.035, -0.056), (-0.042, -0.07),
	(-0.112, -0.07), (-0.122, -0.04)], -0.03, 0.03, "Dark", bevel=0.0025)
body.profile([(-0.108, -0.07), (-0.04, -0.07), (-0.036, -0.078), (-0.112, -0.078)], -0.024, 0.024, "Dark", bevel=0.0015)
gd = lib.Part("Guard")
gd.profile([(0.0, -0.056), (0.004, -0.085), (0.02, -0.092), (0.062, -0.092), (0.068, -0.08), (0.068, -0.056)], -0.006, 0.006, "Dark", bevel=0.0015)
go = gd.build()
gc = lib.Part("GCut")
gc.profile([(0.008, -0.05), (0.01, -0.081), (0.022, -0.086), (0.058, -0.086), (0.06, -0.05)], -0.02, 0.02, "Dark", bevel=0.0)
lib.boolean(go, gc.build())
body.merge_object(go)
body.profile([(0.018, -0.056), (0.026, -0.056), (0.026, -0.064), (0.03, -0.074), (0.026, -0.078), (0.021, -0.07)], -0.004, 0.004, "Steel", bevel=0.0008)
body.cyl((0.0, -0.045, 0.1), 0.0035, 0.064, "Steel", rot=(0, 0, 90), sides=8)

# The pistol grip: raked back, with finger grooves.
body.profile([(0.066, -0.056), (0.112, -0.056), (0.13, -0.09), (0.146, -0.148), (0.146, -0.158), (0.105, -0.158),
	(0.1, -0.15), (0.092, -0.135), (0.094, -0.122), (0.086, -0.108), (0.088, -0.094), (0.078, -0.08), (0.072, -0.066)],
	-0.0175, 0.0175, "Grip", bevel=0.004, segments=3)

# The barrel shroud: a big chamfered box with slots right through it, the barrel showing inside.
sh = lib.Part("Shroud")
sh.profile([(-0.452, 0.026), (-0.443, 0.036), (-0.212, 0.036), (-0.205, 0.028), (-0.205, -0.034), (-0.452, -0.034)], -0.036, 0.036, "Olive", bevel=0.003)
so = sh.build()
cut = lib.Part("Slots")
for i in range(4):
	z = -0.255 - i * 0.045
	cut.box((0, 0.002, z), (0.1, 0.018, 0.026), "Dark", bevel=0.006)
cut.box((0, 0.0, -0.46), (0.03, 0.03, 0.03), "Dark", bevel=0.0)
lib.boolean(so, cut.build())
body.merge_object(so)
body.box((-0.0365, 0.03, -0.33), (0.002, 0.004, 0.2), "Gun", bevel=0.0006)
body.box((0.0365, 0.03, -0.33), (0.002, 0.004, 0.2), "Gun", bevel=0.0006)
for z in (-0.22, -0.44):
	for s in (-1, 1):
		screw(body, (s * 0.036, -0.022, z), s, 0.003)

# The barrel, from the receiver out through the shroud, and its slotted muzzle brake.
body.lathe([(0.0, -0.2), (0.011, -0.2), (0.011, -0.535), (0.0, -0.535)], "Steel", axis="Z", segs=20)
mb = lib.Part("Brake")
mb.lathe([(0.0, -0.53), (0.0165, -0.53), (0.0165, -0.58), (0.014, -0.586), (0.006, -0.586), (0.006, -0.56), (0.0, -0.56)], "Gun", axis="Z", segs=24)
mo = mb.build()
cut = lib.Part("BrakeCut")
for i in range(3):
	z = -0.543 - i * 0.012
	cut.box((0, 0, z), (0.05, 0.007, 0.006), "Dark", bevel=0.0)
lib.boolean(mo, cut.build())
body.merge_object(mo)

# The launcher tube under the shroud, with its sleeve and front ring.
body.lathe([(0.0, -0.215), (0.022, -0.215), (0.022, -0.44), (0.019, -0.445), (0.0, -0.445)], "Dark", axis="Z", center=(0, -0.058, 0), segs=24)
body.lathe([(0.0225, -0.25), (0.025, -0.25), (0.025, -0.36), (0.0225, -0.36)], "Grip", axis="Z", center=(0, -0.058, 0), segs=24)
for z in (-0.265, -0.29, -0.315, -0.34):
	body.lathe([(0.0245, z), (0.0262, z - 0.003), (0.0245, z - 0.006)], "Grip", axis="Z", center=(0, -0.058, 0), segs=24)
body.lathe([(0.012, -0.437), (0.023, -0.437), (0.023, -0.447), (0.012, -0.447)], "Steel", axis="Z", center=(0, -0.058, 0), segs=24)
body.box((0, -0.04, -0.33), (0.026, 0.012, 0.2), "Dark", bevel=0.002)
body.box((0, -0.085, -0.43), (0.01, 0.012, 0.02), "Steel", bevel=0.002)

# The collapsed stock: two rods back to the butt, and its rubber pad.
for x in (-0.012, 0.012):
	body.strut((x, -0.012, 0.185), (x, -0.012, 0.36), 0.0065, "Steel", sides=12)
body.box((0, -0.008, 0.19), (0.05, 0.03, 0.012), "Dark", bevel=0.003)
body.profile([(0.33, 0.026), (0.392, 0.026), (0.392, -0.05), (0.33, -0.05), (0.32, -0.02), (0.32, 0.0)], -0.021, 0.021, "Olive", bevel=0.004)
body.box((0, -0.012, 0.4), (0.05, 0.088, 0.016), "Grip", bevel=0.005)
for y in (-0.04, -0.02, 0.0, 0.02):
	body.box((0, y, 0.409), (0.048, 0.003, 0.003), "Grip", bevel=0.001)

# The reflex sight: riser, base, the two posts and top bar holding the glass, and a hood.
body.box((0, 0.059, 0.02), (0.032, 0.03, 0.044), "Dark", bevel=0.003)
body.box((0, 0.0745, 0.02), (0.044, 0.005, 0.018), "Dark", bevel=0.0015)
for x in (-0.0185, 0.0185):
	body.profile([(0.012, 0.075), (0.028, 0.075), (0.026, 0.137), (0.014, 0.137)], x - 0.0022, x + 0.0022, "Dark", bevel=0.0008)
	screw(body, (x + (0.0022 if x > 0 else -0.0022), 0.082, 0.02), 1 if x > 0 else -1, 0.0022)
body.box((0, 0.138, 0.02), (0.042, 0.005, 0.016), "Dark", bevel=0.0015)
body.cyl((0.023, 0.06, 0.02), 0.006, 0.006, "Gun", rot=(0, 0, 90), sides=12)

# The owner's colour stripe along the right side.
body.box((0.0335, 0.034, 0.0), (0.0015, 0.004, 0.13), "Accent", bevel=0.0004)
# Sling loops.
body.torus((0, -0.057, 0.362), 0.008, 0.0018, "Steel", rot=(0, 0, 90), maj_seg=16, min_seg=6)
body.torus((0, -0.085, -0.4), 0.008, 0.0018, "Steel", rot=(0, 0, 90), maj_seg=16, min_seg=6)
body_o = body.build()

# --- The magazine --------------------------------------------------------------------------------
mag = lib.Part("Mag")
mx, my, mz = MAG_AT
mag.profile([(mz - 0.031, my + 0.012), (mz + 0.031, my + 0.012), (mz + 0.033, my - 0.098), (mz - 0.029, my - 0.098)], -0.019, 0.019, "Dark", bevel=0.002)
mag.box((0, my - 0.106, mz + 0.002), (0.043, 0.012, 0.068), "Steel", bevel=0.003)
for i in range(4):
	mag.box((0, my - 0.02 - i * 0.02, mz), (0.0395, 0.004, 0.058), "Dark", bevel=0.001)
mag.box((0.006, my + 0.016, mz), (0.012, 0.006, 0.05), "Brass", bevel=0.002)
mag.box((-0.006, my + 0.014, mz), (0.012, 0.006, 0.05), "Brass", bevel=0.002)
mag_o = mag.build(origin=MAG_AT)

# --- The bolt handle -----------------------------------------------------------------------------
bolt = lib.Part("Bolt")
bolt.box((0.034, 0.025, 0.02), (0.012, 0.006, 0.014), "Steel", bevel=0.0015)
bolt.lathe([(0.0, 0.034), (0.006, 0.034), (0.007, 0.046), (0.0055, 0.05), (0.0, 0.05)], "Gun", axis="X", center=(0, 0.025, 0.022), segs=14)
bolt_o = bolt.build()

objs = [body_o, mag_o, bolt_o]
lib.unwrap(objs, margin=0.003)
imgs = lib.bake(objs, 2048, "rifle", ao_distance=0.03)
lib.finalize(objs, imgs)
lib.export(objs, os.path.join(lib.OUT, "rifle", "rifle.gltf"))
lib.preview("rifle", (0, -0.02, -0.1), 1.2, [(-90, 5), (-35, 20), (140, 25), (90, 0)])
