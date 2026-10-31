"""Furniture for the outposts' rooms (OutpostProps), each in its piece's frame: the floor point under
its middle, facing +z (into the room for pieces against a wall).

Objects in the .gltf:
- "Crate": a military crate 0.85 x 0.75 x 0.85 (the game scales it to other sizes): ribbed steel
  panels in an angle frame, corner guards, latches, side handles, a stencil band and stencil marks.
- "AmmoBox": an ammunition can 0.48 x 0.3 x 0.6: ribbed body, clamp lid, carry handle, yellow band.
- "SecurityDesk": the security desk 3.2 x 1.5 x 1.5: pedestal with drawers, desktop with a rubber
  bumper, switch panel, keyboard, and the monitor bank with four recessed CRT bays (the game lays
  the camera feeds into the bays at (x, 1.38, -0.215), tilted back 6 degrees, 0.64 x 0.46).
- "Chair": an operator's swivel chair.
- "WeaponBench": a heavy bench 2.3 x 1.0 x 1.2 with a vise, a stripped rifle, a toolbox and tools.
- "Shelf": steel shelving 2.2 x 2.4 x 0.7 (uprights, four decks, cross bracing; the game stocks it).

    blender -b -P tools/blender/outpost_props.py
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lib  # noqa: E402

lib.reset()
K = lib.kind
K("Olive", (0.36, 0.4, 0.24), 0.3, 0.66, wear=0.5, grime=0.55, scratch=0.45, edge=0.012, streaks=0.3)
K("OliveDark", (0.24, 0.27, 0.17), 0.3, 0.7, wear=0.45, grime=0.6, scratch=0.4, edge=0.01)
K("Khaki", (0.42, 0.4, 0.3), 0.25, 0.7, wear=0.45, grime=0.55, scratch=0.4, edge=0.01)
K("Steel", (0.5, 0.5, 0.48), 0.85, 0.42, grime=0.5, scratch=0.5)
K("Gunmetal", (0.17, 0.17, 0.18), 0.75, 0.45, wear=0.6, grime=0.55, scratch=0.5, bare=(0.6, 0.6, 0.6), edge=0.01)
K("Brass", (0.66, 0.5, 0.28), 0.9, 0.42, grime=0.55, scratch=0.35)
K("Rubber", (0.06, 0.06, 0.055), 0.0, 0.85, grime=0.45, noise=0.1)
K("Vinyl", (0.2, 0.17, 0.12), 0.05, 0.6, grime=0.5, noise=0.15, wear=0.3, bare=(0.3, 0.26, 0.2), edge=0.015)
K("Dark", (0.08, 0.08, 0.085), 0.45, 0.62, wear=0.3, grime=0.45, edge=0.008, bare=(0.45, 0.45, 0.45))
K("Glass", (0.03, 0.035, 0.035), 0.0, 0.08)
K("Yellow", (0.75, 0.56, 0.12), 0.2, 0.62, wear=0.55, grime=0.5, edge=0.008)
K("Stripes", (0.72, 0.54, 0.1), 0.2, 0.62, wear=0.6, grime=0.55, edge=0.008, stripes=(0, 0, 0, 0.1))
K("Red", (0.5, 0.11, 0.07), 0.2, 0.6, wear=0.55, grime=0.5, edge=0.01)
K("Stencil", (0.08, 0.08, 0.07), 0.1, 0.8, grime=0.3, noise=0.2)
K("Amber", (0.1, 0.06, 0.02), 0.0, 0.4, emit=(1.0, 0.6, 0.22, 0.6))


def hexbolt(part, pos, rot, r=0.012, h=0.012, kind="Steel"):
	part.cyl(pos, r, h, kind, rot=rot, sides=6, bevel=0.0015, smooth=False)


# --- Crate (0.85 x 0.75 x 0.85, floor at y 0) ---------------------------------------------------------
cr = lib.Part("Crate")
W, H, D = 0.85, 0.75, 0.85
cr.box((0, H / 2, 0), (W - 0.04, H - 0.04, D - 0.04), "Olive", bevel=0.01)
# Ribs on the four sides and the lid.
for i in range(4):
	t = -0.3 + i * 0.2
	for sz in (-1.0, 1.0):
		cr.box((t, H / 2, sz * (D / 2 - 0.012)), (0.05, H - 0.14, 0.02), "Olive", bevel=0.006)
	for sx in (-1.0, 1.0):
		cr.box((sx * (W / 2 - 0.012), H / 2, t), (0.02, H - 0.14, 0.05), "Olive", bevel=0.006)
	cr.box((t, H - 0.012, 0), (0.05, 0.02, D - 0.14), "Olive", bevel=0.006)
# Angle frame along every edge, corner guards.
for sx in (-1.0, 1.0):
	for sz in (-1.0, 1.0):
		cr.box((sx * (W / 2 - 0.02), H / 2, sz * (D / 2 - 0.02)), (0.05, H, 0.05), "Gunmetal", bevel=0.006)
		for y in (0.03, H - 0.03):
			cr.box((sx * (W / 2 - 0.03), y, sz * (D / 2 - 0.03)), (0.09, 0.07, 0.09), "Steel", bevel=0.01)
	for y in (0.02, H - 0.02):
		cr.box((sx * (W / 2 - 0.02), y, 0), (0.05, 0.045, D - 0.08), "Gunmetal", bevel=0.006)
for sz in (-1.0, 1.0):
	for y in (0.02, H - 0.02):
		cr.box((0, y, sz * (D / 2 - 0.02)), (W - 0.08, 0.045, 0.05), "Gunmetal", bevel=0.006)
# Latches front and back, handles on the sides.
for sz in (-1.0, 1.0):
	for lx in (-0.22, 0.22):
		cr.box((lx, H - 0.09, sz * (D / 2 + 0.005)), (0.07, 0.1, 0.02), "Steel", bevel=0.004)
		cr.cyl((lx, H - 0.05, sz * (D / 2 + 0.012)), 0.012, 0.06, "Steel", rot=(0, 0, 90), sides=8)
	# Stencil band and marks (a lot number, an arrow).
	cr.box((0, H * 0.52, sz * (D / 2 + 0.002)), (W - 0.12, 0.09, 0.004), "Yellow", bevel=0)
	for k in range(7):
		cr.box((-0.24 + k * 0.07, H * 0.52, sz * (D / 2 + 0.004)), (0.04, 0.05, 0.002), "Stencil", bevel=0)
	cr.box((0.25, H * 0.3, sz * (D / 2 + 0.002)), (0.12, 0.03, 0.002), "Stencil", bevel=0)
	cr.box((0.25, H * 0.22, sz * (D / 2 + 0.002)), (0.03, 0.12, 0.002), "Stencil", bevel=0)
for sx in (-1.0, 1.0):
	cr.box((sx * (W / 2 + 0.01), H * 0.62, 0), (0.02, 0.05, 0.26), "Gunmetal", bevel=0.004)
	cr.cyl((sx * (W / 2 + 0.035), H * 0.62, 0), 0.014, 0.2, "Steel", rot=(90, 0, 0), sides=8)
cr_o = cr.build()

# --- Ammo box (0.48 x 0.3 x 0.6) ------------------------------------------------------------------------
am = lib.Part("AmmoBox")
W, H, D = 0.48, 0.3, 0.6
am.box((0, H / 2 - 0.01, 0), (W, H - 0.02, D), "OliveDark", bevel=0.012)
am.box((0, H - 0.015, 0), (W + 0.02, 0.03, D + 0.02), "OliveDark", bevel=0.008)
for sx in (-1.0, 1.0):
	for k in range(3):
		am.box((sx * (W / 2 + 0.004), H * 0.45, -0.18 + k * 0.18), (0.01, H * 0.6, 0.04), "OliveDark", bevel=0.003)
am.box((0, H * 0.55, D / 2 + 0.003), (W - 0.04, 0.05, 0.004), "Yellow", bevel=0)
for k in range(5):
	am.box((-0.12 + k * 0.06, H * 0.33, D / 2 + 0.003), (0.035, 0.035, 0.002), "Stencil", bevel=0)
am.box((0, H - 0.04, D / 2 + 0.012), (0.12, 0.08, 0.02), "Steel", bevel=0.004)
am.cyl((0, H + 0.005, 0), 0.016, 0.22, "Gunmetal", rot=(0, 0, 90), sides=8)
for sx in (-0.11, 0.11):
	am.box((sx, H, 0), (0.025, 0.03, 0.03), "Gunmetal", bevel=0.004)
am_o = am.build()

# --- Security desk (3.2 x 1.5 x 1.5) ---------------------------------------------------------------------
sd = lib.Part("SecurityDesk")
# Pedestal: a long body with drawer units at the ends, a recessed kick.
sd.box((0, 0.47, -0.27), (3.1, 0.82, 0.94), "Olive", bevel=0.015)
sd.box((0, 0.05, -0.22), (3.0, 0.1, 0.9), "Dark", bevel=0.005)
for sx in (-1.0, 1.0):
	cx = sx * 1.25
	sd.box((cx, 0.47, 0.205), (0.6, 0.8, 0.02), "OliveDark", bevel=0.004)
	for k in range(3):
		y = 0.2 + k * 0.25
		sd.box((cx, y, 0.22), (0.54, 0.2, 0.02), "Olive", bevel=0.006)
		sd.box((cx, y + 0.05, 0.24), (0.18, 0.025, 0.025), "Steel", bevel=0.004)
		sd.box((cx, y - 0.04, 0.232), (0.1, 0.04, 0.002), "Khaki", bevel=0)
for k in range(3):
	sd.box((-0.6 + k * 0.6, 0.5, 0.2), (0.012, 0.7, 0.012), "OliveDark", bevel=0)
# Desktop and its bumper.
sd.box((0, 0.93, 0), (3.26, 0.06, 1.5), "Gunmetal", bevel=0.01)
sd.cyl((0, 0.93, 0.75), 0.035, 3.26, "Rubber", rot=(0, 0, 90), sides=12)
# Switch panel sloping up to the monitors.
with sd.at((0, 1.0, -0.12), (-18, 0, 0)):
	sd.box((0, 0, 0), (3.0, 0.05, 0.26), "OliveDark", bevel=0.006)
	for k in range(22):
		x = -1.4 + k * (2.8 / 21)
		if k % 5 == 2:
			sd.cyl((x, 0.03, 0.02), 0.022, 0.025, "Amber", sides=12)
			sd.cyl((x, 0.028, 0.02), 0.028, 0.012, "Steel", sides=12)
			continue
		sd.box((x, 0.03, -0.04), (0.04, 0.02, 0.05), "Steel", bevel=0.003)
		sd.cyl((x, 0.05, -0.04), 0.006, 0.05, "Steel", rot=(15 if k % 2 else -15, 0, 0), sides=6)
		sd.cyl((x, 0.035, 0.06), 0.018, 0.03, "Dark", sides=12)
# Keyboard.
with sd.at((0, 0.98, 0.35), (-6, 0, 0)):
	sd.box((0, 0, 0), (1.92, 0.04, 0.3), "Dark", bevel=0.008)
	for r in range(4):
		for c in range(18):
			sd.box((-0.85 + c * 0.1, 0.025, -0.1 + r * 0.065), (0.08, 0.02, 0.05), "Khaki", bevel=0.004)
# Monitor bank: housing, hood and four recessed CRT bays.
sd.box((0, 1.35, -0.5), (3.1, 0.8, 0.32), "Olive", bevel=0.015)
sd.box((0, 1.79, -0.42), (3.18, 0.08, 0.5), "OliveDark", bevel=0.01)
for k in range(12):
	sd.box((-1.4 + k * 0.255, 1.74, -0.67), (0.18, 0.025, 0.012), "Dark", bevel=0)
for i in range(4):
	sx = -3.2 * 0.375 + i * 3.2 * 0.25
	with sd.at((sx, 1.38, -0.23), (-6, 0, 0)):
		ow, oh, iw, ih = 0.74, 0.6, 0.64, 0.46
		sd.box((0, (oh + ih) / 4, -0.03), (ow, (oh - ih) / 2, 0.08), "Gunmetal", bevel=0.01)
		sd.box((0, -(oh + ih) / 4, -0.03), (ow, (oh - ih) / 2, 0.08), "Gunmetal", bevel=0.01)
		for s in (-1.0, 1.0):
			sd.box((s * (ow + iw) / 4, 0, -0.03), ((ow - iw) / 2, ih, 0.08), "Gunmetal", bevel=0.01)
		sd.box((0, 0, -0.07), (iw, ih, 0.02), "Glass", bevel=0)
		for s in (-1.0, 1.0):
			hexbolt(sd, (s * (ow / 2 - 0.02), oh / 2 - 0.02, 0.012), (90, 0, 0))
			hexbolt(sd, (s * (ow / 2 - 0.02), -oh / 2 + 0.02, 0.012), (90, 0, 0))
		sd.box((-0.22, -oh / 2 + 0.035, 0.012), (0.1, 0.02, 0.004), "Khaki", bevel=0)
		sd.cyl((0.25, -oh / 2 + 0.035, 0.014), 0.012, 0.012, "Steel", rot=(90, 0, 0), sides=10)
# Cables from the bank down behind the desk.
for k in range(5):
	sd.strut((-1.0 + k * 0.5, 1.0, -0.69), (-0.9 + k * 0.45, 0.1, -0.72), 0.018, "Rubber", sides=6)
sd_o = sd.build()

# --- Chair -------------------------------------------------------------------------------------------------
ch = lib.Part("Chair")
ch.box((0, 0.5, 0), (0.5, 0.08, 0.5), "Vinyl", bevel=0.03)
ch.box((0, 0.45, 0), (0.4, 0.04, 0.4), "Gunmetal", bevel=0.006)
with ch.at((0, 0.86, 0.24), (-8, 0, 0)):
	ch.box((0, 0, 0), (0.46, 0.5, 0.07), "Vinyl", bevel=0.03)
	ch.box((0, 0, 0.04), (0.4, 0.44, 0.02), "Gunmetal", bevel=0.006)
ch.strut((0, 0.47, 0.18), (0, 0.66, 0.27), 0.02, "Gunmetal", sides=8)
ch.cyl((0, 0.3, 0), 0.04, 0.3, "Steel", sides=12)
ch.cyl((0, 0.14, 0), 0.05, 0.08, "Dark", sides=12)
for k in range(5):
	a = math.tau * k / 5
	tip = (math.cos(a) * 0.3, 0.06, math.sin(a) * 0.3)
	ch.strut((0, 0.1, 0), tip, 0.022, "Dark", sides=6)
	ch.sphere((tip[0], 0.035, tip[2]), 0.035, "Rubber", segs=10, rings=6)
for s in (-1.0, 1.0):
	ch.box((s * 0.27, 0.66, -0.02), (0.05, 0.04, 0.32), "Rubber", bevel=0.015)
	ch.strut((s * 0.25, 0.5, 0.05), (s * 0.27, 0.64, -0.02), 0.015, "Gunmetal", sides=6)
ch_o = ch.build()

# --- Weapon bench (2.3 x 1.0 x 1.2) -----------------------------------------------------------------------
wb = lib.Part("WeaponBench")
wb.box((0, 0.9, 0), (2.3, 0.07, 1.2), "Gunmetal", bevel=0.01)
wb.box((0, 0.94, 0), (2.0, 0.01, 0.9), "Rubber", bevel=0.002)
for sx in (-1.0, 1.0):
	for sz in (-1.0, 1.0):
		wb.box((sx * 1.05, 0.43, sz * 0.5), (0.08, 0.86, 0.08), "Olive", bevel=0.008)
		wb.box((sx * 1.05, 0.02, sz * 0.5), (0.14, 0.04, 0.14), "Dark", bevel=0.004)
	wb.box((sx * 1.05, 0.25, 0), (0.06, 0.06, 0.95), "Olive", bevel=0.006)
	wb.strut((sx * 1.05, 0.3, -0.45), (sx * 1.05, 0.82, 0.45), 0.018, "OliveDark", sides=6)
wb.box((0, 0.28, 0), (2.05, 0.03, 1.0), "OliveDark", bevel=0.005)
# Drawer unit under the top.
wb.box((-0.6, 0.72, 0), (0.7, 0.3, 1.0), "Olive", bevel=0.01)
for k in range(2):
	wb.box((-0.6, 0.65 + k * 0.14, 0.505), (0.64, 0.11, 0.01), "OliveDark", bevel=0.003)
	wb.box((-0.6, 0.68 + k * 0.14, 0.52), (0.16, 0.02, 0.02), "Steel", bevel=0.003)
# Ammo can on the lower shelf.
wb.box((0.55, 0.43, 0.1), (0.3, 0.26, 0.5), "OliveDark", bevel=0.01)
wb.box((0.55, 0.43, 0.355), (0.26, 0.04, 0.004), "Yellow", bevel=0)
# Vise at the +x end.
with wb.at((0.95, 0.95, 0.42), (0, 0, 0)):
	wb.box((0, 0.04, 0), (0.18, 0.08, 0.22), "Red", bevel=0.01)
	wb.box((0, 0.13, -0.05), (0.2, 0.12, 0.06), "Red", bevel=0.01)
	wb.box((0, 0.13, 0.06), (0.2, 0.12, 0.06), "Red", bevel=0.01)
	wb.cyl((0, 0.1, 0.18), 0.012, 0.22, "Steel", rot=(90, 0, 0), sides=8)
	wb.cyl((0, 0.1, 0.29), 0.012, 0.16, "Steel", rot=(0, 0, 90), sides=8)
# The rifle in pieces on a cloth: receiver, barrel, stock, magazine, bolt, springs.
wb.box((-0.3, 0.955, 0.0), (1.2, 0.006, 0.5), "Khaki", rot=(0, 6, 0), bevel=0)
wb.box((-0.35, 1.0, 0.0), (0.42, 0.08, 0.1), "Gunmetal", rot=(0, 8, 0), bevel=0.01)
wb.cyl((0.12, 0.985, 0.08), 0.018, 0.55, "Dark", rot=(0, 8, 90), sides=10)
wb.box((-0.75, 0.985, -0.02), (0.3, 0.06, 0.07), "Dark", rot=(0, -4, 0), bevel=0.01)
wb.box((-0.3, 0.975, -0.18), (0.08, 0.04, 0.2), "Dark", rot=(0, 30, 0), bevel=0.006)
wb.cyl((-0.05, 0.97, -0.15), 0.012, 0.14, "Steel", rot=(0, 70, 90), sides=8)
for k in range(5):
	wb.cyl((-0.6 + k * 0.03, 0.968, 0.2), 0.008, 0.02, "Brass", sides=8)
# Toolbox and tools.
wb.box((0.7, 1.03, -0.3), (0.45, 0.2, 0.24), "Red", bevel=0.012)
wb.box((0.7, 1.14, -0.3), (0.47, 0.02, 0.26), "Red", bevel=0.005)
wb.cyl((0.7, 1.19, -0.3), 0.01, 0.24, "Dark", rot=(0, 0, 90), sides=8)
for sx in (-0.1, 0.1):
	wb.box((0.7 + sx, 1.165, -0.3), (0.02, 0.05, 0.02), "Dark", bevel=0.003)
wb.box((0.35, 0.965, 0.25), (0.22, 0.012, 0.03), "Steel", rot=(0, 25, 0), bevel=0.003)
wb.box((0.4, 0.965, 0.32), (0.18, 0.012, 0.025), "Steel", rot=(0, -10, 0), bevel=0.003)
wb_o = wb.build()

# --- Shelf frame (2.2 x 2.4 x 0.7) -------------------------------------------------------------------------
sh = lib.Part("Shelf")
W, H, D = 2.2, 2.4, 0.7
for sx in (-1.0, 1.0):
	for sz in (-1.0, 1.0):
		x, z = sx * (W / 2 - 0.035), sz * (D / 2 - 0.035)
		sh.box((x, H / 2, z), (0.06, H, 0.012), "Gunmetal", bevel=0.002)
		sh.box((x - sx * 0.024, H / 2, z - sz * 0.0), (0.012, H, 0.06), "Gunmetal", bevel=0.002)
		for k in range(16):
			sh.box((x, 0.12 + k * 0.14, z + sz * 0.007), (0.022, 0.04, 0.004), "Dark", bevel=0)
		sh.box((x, 0.01, z), (0.1, 0.02, 0.1), "Steel", bevel=0.003)
for i in range(4):
	y = 0.12 + i * (H - 0.2) / 3.0
	sh.box((0, y, 0), (W - 0.04, 0.03, D - 0.04), "OliveDark", bevel=0.004)
	for sz in (-1.0, 1.0):
		sh.box((0, y + 0.02, sz * (D / 2 - 0.03)), (W - 0.02, 0.06, 0.02), "Brass" if sz > 0 else "Gunmetal", bevel=0.004)
	for sx in (-1.0, 1.0):
		sh.box((sx * (W / 2 - 0.03), y, 0), (0.02, 0.06, D - 0.04), "Gunmetal", bevel=0.004)
	sh.box((-0.7, y + 0.02, D / 2 - 0.02), (0.1, 0.04, 0.004), "Khaki", bevel=0)
	sh.box((0.6, y + 0.02, D / 2 - 0.02), (0.1, 0.04, 0.004), "Khaki", bevel=0)
# Cross bracing at the back.
for (a, b) in (((-W / 2 + 0.04, 0.15), (W / 2 - 0.04, H - 0.15)), ((W / 2 - 0.04, 0.15), (-W / 2 + 0.04, H - 0.15))):
	sh.strut((a[0], a[1], -D / 2 + 0.02), (b[0], b[1], -D / 2 + 0.02), 0.008, "Steel", sides=6)
sh_o = sh.build()

objs = [cr_o, am_o, sd_o, ch_o, wb_o, sh_o]
lib.unwrap(objs, margin=0.002)
imgs = lib.bake(objs, 4096, "outpost_props", ao_distance=0.2, emissive=True)
lib.finalize(objs, imgs)
lib.export(objs, os.path.join(lib.OUT, "outpost_props", "outpost_props.gltf"))
# Previews: lay the pieces out side by side.
for o, at in ((cr_o, (-3.2, 0, 1.5)), (am_o, (-2.0, 0, 1.6)), (ch_o, (-0.8, 0, 1.6)), (sd_o, (1.2, 0, 1.5)), (wb_o, (-1.6, 0, -1.2)), (sh_o, (1.4, 0, -1.4))):
	o.location = lib.G(*at)
lib.preview("outpost_props", (-0.6, 0.8, 0.2), 9.0, [(-20, 25), (25, 15)])
