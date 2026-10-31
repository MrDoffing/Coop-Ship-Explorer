"""The gun pods' Multiple Rocket Launcher System (GunPod, weapon "mrls"): a launcher box either side of
the pod, eight tubes in each (two across, four high). Each box is bolted over the receiver's mount
and closes round the heavy machine gun's receiver (part of the pod's own model), so a pod carrying
rockets shows the boxes instead. In GunPod's pitch frame (the ball's centre at the origin, -Z
forward); the tubes' places are GunPod.MRLS_TUBES.

Objects in the .gltf:
- "Launchers": both boxes: the case in the ship's paint with steel bands, rivets and a hazard stripe
  round the front, the tubes' mouths front and back (short dark recesses; the rockets showing in them
  are the game's), a mounting plate with bolts against the pod's bracket, a stencilled plate and a
  firing cable into the ball.
Materials the game swaps: "Paint" (tinted with the ship's paint, as the pod's shell).

    blender -b -P tools/blender/mrls.py
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lib  # noqa: E402

# The box (one side; the other mirrored): its middle across, its depth range and size.
BOX_X = 1.31
BOX_W = 0.38
BOX_H = 0.66
FRONT = -0.62
BACK = 0.48
# The tubes: columns either side of the box's middle, rows top to bottom, their radius, and how deep
# the recesses go in from each face.
COLS = (-0.095, 0.095)
ROWS = (0.24, 0.08, -0.08, -0.24)
TUBE_R = 0.066
RECESS = 0.05

lib.reset()
K = lib.kind
K("Paint", (0.92, 0.92, 0.9), 0.45, 0.52, wear=0.5, grime=0.55, plates=0.36, seam=0.0035, scratch=0.45, export_as="Paint", edge=0.02)
K("Gunmetal", (0.12, 0.12, 0.13), 0.75, 0.42, wear=0.75, grime=0.45, scratch=0.6, bare=(0.62, 0.62, 0.64), edge=0.012)
K("Steel", (0.58, 0.59, 0.58), 0.85, 0.32, grime=0.35, scratch=0.5)
K("Dark", (0.04, 0.04, 0.045), 0.3, 0.8, grime=0.3)
K("Soot", (0.05, 0.045, 0.04), 0.1, 0.9, grime=0.2, noise=0.2)
K("Bolt", (0.52, 0.5, 0.46), 0.6, 0.42, grime=0.6)
K("Stripes", (0.92, 0.72, 0.1), 0.2, 0.58, wear=0.6, grime=0.45, edge=0.01, stripes=(0, 0, 0, 0.09))
K("Plate", (0.75, 0.72, 0.62), 0.4, 0.5, wear=0.4, grime=0.5, edge=0.005)
K("Rubber", (0.07, 0.065, 0.06), 0.0, 0.85, grime=0.4, noise=0.1)


def hexbolt(part, pos, axis_rot, r=0.014, h=0.012):
	part.cyl(pos, r, h, "Bolt", rot=axis_rot, sides=6, bevel=0.002, smooth=False)


launchers = lib.Part("Launchers")
for s in (-1.0, 1.0):
	cx = s * BOX_X
	mid_z = (FRONT + BACK) * 0.5
	case = lib.Part("Case")
	case.box((cx, 0, mid_z), (BOX_W, BOX_H, BACK - FRONT), "Paint", bevel=0.02)
	co = case.build()
	# The tubes' mouths, front and back (none overlaps another, or the boolean throws the case away).
	cut = lib.Part("Tubes")
	for col in COLS:
		for row in ROWS:
			for z in (FRONT, BACK):
				cut.cyl((cx + col, row, z), TUBE_R, RECESS * 2.0, "Dark", rot=(90, 0, 0), sides=24, bevel=0.0)
	lib.boolean(co, cut.build())
	launchers.merge_object(co)
	for col in COLS:
		for row in ROWS:
			# The bottom of each recess (sooty at the back, where the rockets' motors light), and a
			# steel lip round each mouth.
			for z, inward, kind in ((FRONT, 1.0, "Dark"), (BACK, -1.0, "Soot")):
				launchers.cyl((cx + col, row, z + inward * (RECESS - 0.004)), TUBE_R + 0.002, 0.008, kind, rot=(90, 0, 0), sides=24, bevel=0.0)
				launchers.torus((cx + col, row, z - inward * 0.002), TUBE_R + 0.006, 0.006, "Steel", rot=(90, 0, 0), maj_seg=28, min_seg=6)
	# Steel bands round the case, riveted.
	for z in (FRONT + 0.06, mid_z, BACK - 0.06):
		launchers.box((cx, 0, z), (BOX_W + 0.024, BOX_H + 0.024, 0.05), "Gunmetal", bevel=0.006)
		for y in (-BOX_H * 0.5 - 0.012, BOX_H * 0.5 + 0.012):
			for dx in (-0.12, 0.0, 0.12):
				hexbolt(launchers, (cx + dx, y, z), (0, 0, 0), 0.01, 0.01)
	# A hazard stripe round the front face.
	for (dx, dy, w, h) in ((0, BOX_H * 0.5 - 0.012, BOX_W - 0.03, 0.016), (0, -BOX_H * 0.5 + 0.012, BOX_W - 0.03, 0.016),
			(BOX_W * 0.5 - 0.012, 0, 0.016, BOX_H - 0.03), (-BOX_W * 0.5 + 0.012, 0, 0.016, BOX_H - 0.03)):
		launchers.box((cx + dx, dy, FRONT - 0.003), (w, h, 0.006), "Stripes", bevel=0.0)
	# The mounting plate against the pod's bracket (on the box's inboard face), its bolts.
	inner = cx - s * BOX_W * 0.5
	launchers.box((inner - s * 0.012, 0, 0.0), (0.024, 0.3, 0.42), "Gunmetal", bevel=0.006)
	for y in (-0.11, 0.11):
		for z in (-0.16, 0.0, 0.16):
			hexbolt(launchers, (inner - s * 0.026, y, z), (0, 0, 90), 0.013, 0.012)
	# A stencilled plate on the outboard face and the firing cable back into the ball.
	outer = cx + s * BOX_W * 0.5
	launchers.box((outer + s * 0.003, 0.12, -0.24), (0.006, 0.12, 0.26), "Plate", bevel=0.002)
	for k in range(3):
		launchers.box((outer + s * 0.007, 0.15 - k * 0.03, -0.24), (0.002, 0.012, 0.2 - k * 0.04), "Dark", bevel=0.0)
	launchers.strut((inner, -0.18, 0.38), (s * 0.98, -0.3, 0.5), 0.022, "Rubber", sides=10)
	launchers.strut((s * 0.98, -0.3, 0.5), (s * 0.86, -0.36, 0.56), 0.022, "Rubber", sides=10)
launchers_o = launchers.build()

objs = [launchers_o]
lib.unwrap(objs, margin=0.003)
imgs = lib.bake(objs, 2048, "mrls", ao_distance=0.15)
lib.finalize(objs, imgs)
lib.export(objs, os.path.join(lib.OUT, "mrls", "mrls.gltf"))
lib.preview("mrls", (0, 0, -0.1), 4.2, [(-30, 15), (150, 20), (-90, 5), (0, 60)])
