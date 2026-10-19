"""The gun pod (GunPod): the ball's shell, frame and cabin, the receivers, one barrel (the game
places four), the collar it turns in and the heavy pod's armour plates.

Objects in the .gltf (all in GunPod's frames, see gun_pod.gd):
- "Pod": everything that swings with the pitch pivot (ball centre at the origin, -Z forward), except
  the glass, the reflector sight's glass, the screens, labels and lamps, which the game makes.
- "Armour": the heavy pod's extra plates (pitch frame).
- "Collar": the ring the ball sits in, on its mount (yaw frame).
- "Barrel" / "BarrelHot": one barrel from its breech (origin) to the muzzle 2 m out along -Z; the
  hot part (the bare barrel, which shows through the jacket's holes, and the flash hider) has its
  own material "Hot" so the game can make it glow.
Materials the game swaps: "Paint" (tinted with the ship's paint), "Accent" (the ship's accent
colour), "Hot" (glows with the barrels' heat).

    blender -b -P tools/blender/gun_pod.py
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lib  # noqa: E402
from lib import G  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

RADIUS = 1.05
BARREL_LEN = 2.0

lib.reset()
K = lib.kind
K("Paint", (0.92, 0.92, 0.9), 0.45, 0.52, wear=0.5, grime=0.55, plates=0.36, seam=0.0035, scratch=0.45, export_as="Paint", edge=0.02)
K("PaintIn", (0.85, 0.85, 0.83), 0.3, 0.7, grime=0.6, plates=0.36, seam=0.0035, scratch=0.3, export_as="Paint")
K("Frame", (0.4, 0.4, 0.35), 0.25, 0.58, wear=0.6, grime=0.5, scratch=0.5, edge=0.012)
K("Bolt", (0.52, 0.5, 0.46), 0.6, 0.42, grime=0.6)
K("Gunmetal", (0.12, 0.12, 0.13), 0.75, 0.42, wear=0.75, grime=0.45, scratch=0.6, bare=(0.62, 0.62, 0.64), edge=0.012)
K("Jacket", (0.16, 0.16, 0.17), 0.6, 0.5, wear=0.3, grime=0.55, scratch=0.35, bare=(0.45, 0.45, 0.46), edge=0.01)
K("Steel", (0.58, 0.59, 0.58), 0.85, 0.32, grime=0.35, scratch=0.5)
K("Olive", (0.29, 0.31, 0.25), 0.3, 0.7, wear=0.55, grime=0.6, plates=0.16, seam=0.0025, scratch=0.45, edge=0.01)
K("Dark", (0.09, 0.095, 0.1), 0.45, 0.62, wear=0.35, grime=0.35, edge=0.01, bare=(0.45, 0.45, 0.45))
K("Leather", (0.24, 0.16, 0.1), 0.05, 0.72, grime=0.6, noise=0.18, wear=0.35, bare=(0.4, 0.3, 0.21), edge=0.02)
K("Brass", (0.8, 0.6, 0.28), 0.9, 0.33, grime=0.5, scratch=0.3)
K("Hazard", (0.92, 0.72, 0.1), 0.2, 0.58, wear=0.65, grime=0.45, edge=0.008)
K("Stripes", (0.92, 0.72, 0.1), 0.2, 0.58, wear=0.6, grime=0.45, edge=0.01, stripes=(0, 0, 0, 0.09))
K("Floor", (0.24, 0.24, 0.23), 0.65, 0.55, plates=0.22, seam=0.003, grime=0.9, scratch=0.9, wear=0.5, edge=0.01)
K("Rubber", (0.07, 0.065, 0.06), 0.0, 0.85, grime=0.4, noise=0.1)
K("Lamp", (0.05, 0.05, 0.05), 0.0, 0.4, emit=(1.0, 0.15, 0.08, 1.5))
K("SightLamp", (0.05, 0.05, 0.05), 0.0, 0.4, emit=(1.0, 0.55, 0.15, 0.8))
K("Accent", (0.95, 0.95, 0.95), 0.3, 0.5, wear=0.55, grime=0.5, export_as="Accent", edge=0.01)
K("Hot", (0.13, 0.12, 0.11), 0.7, 0.45, wear=0.4, grime=0.5, scratch=0.4, bare=(0.55, 0.55, 0.55), export_as="Hot", edge=0.008)


def track(normal):
	"""A rotation taking Godot +Y (a lathe's axis) onto the Godot direction `normal`."""
	n = G(*normal).normalized()
	return n.to_track_quat("Z", "Y").to_matrix().to_4x4()


def rivet(part, pos, normal, r=0.013, kind="Bolt", segs=10):
	"""A domed rivet head on a surface facing `normal`."""
	prof = [(0.0, -0.002), (r, -0.002), (r, 0.002), (r * 0.75, r * 0.55), (r * 0.35, r * 0.78), (0.0, r * 0.82)]
	part.lathe(prof, kind, axis="Y", segs=segs, matrix=Matrix.Translation(G(*pos)) @ track(normal))


def hexbolt(part, pos, normal, r=0.016, h=0.012, kind="Bolt"):
	prof = [(0.0, 0.0), (r, 0.0), (r, h * 0.8), (r * 0.8, h), (0.0, h)]
	part.lathe(prof, kind, axis="Y", segs=6, matrix=Matrix.Translation(G(*pos)) @ track(normal))


def band(part, u, v, a0, a1, radius, width, thick, steps, kind, closed=False, bevel=0.006):
	"""A metal strip along a great circle of the ball (points u cos a + v sin a)."""
	u, v = Vector(u), Vector(v)
	n = u.cross(v).normalized()
	rings = []
	cnt = steps if closed else steps + 1
	for i in range(cnt):
		a = a0 + (a1 - a0) * i / steps
		r = (u * math.cos(a) + v * math.sin(a)).normalized()
		c = r * radius
		rings.append([tuple(c + r * thick * 0.5 + n * width * 0.5), tuple(c + r * thick * 0.5 - n * width * 0.5),
			tuple(c - r * thick * 0.5 - n * width * 0.5), tuple(c - r * thick * 0.5 + n * width * 0.5)])
	import bmesh
	bm = bmesh.new()
	vr = [[bm.verts.new(G(*p)) for p in ring] for ring in rings]
	links = list(zip(vr, vr[1:])) + ([(vr[-1], vr[0])] if closed else [])
	for a, b in links:
		for i in range(4):
			j = (i + 1) % 4
			bm.faces.new((a[i], a[j], b[j], b[i]))
	if not closed:
		bm.faces.new(vr[0])
		bm.faces.new(list(reversed(vr[-1])))
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	part.add_bmesh(bm, kind, bevel=bevel, segments=2, angle=60.0)


def band_rivets(part, u, v, radius, thick, count, full=False, inner=True, r=0.012):
	u, v = Vector(u), Vector(v)
	for i in range(count):
		a = (math.tau * i / count) if full else math.pi * (i + 0.5) / count
		d = (u * math.cos(a) + v * math.sin(a)).normalized()
		rivet(part, tuple(d * (radius + thick * 0.5)), tuple(d), r)
		if inner:
			rivet(part, tuple(d * (radius - thick * 0.5)), tuple(-d), r)


R, L, U, D, F, B = (1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, -1), (0, 0, 1)

# --- Pod (pitch frame) -----------------------------------------------------------------------------
pod = lib.Part("Pod")
# The shell: the back half of the ball, with an inner skin (seen from the seat) and a rim.
outer = [(RADIUS * 1.004 * math.sin(math.radians(t)), RADIUS * 1.004 * math.cos(math.radians(t))) for t in range(0, 91, 3)]
pod.lathe(outer + [(RADIUS - 0.018, 0.0)], "Paint", axis="Z", segs=72, closed=False)
inner = [(RADIUS - 0.018, 0.0)] + [((RADIUS - 0.018) * math.sin(math.radians(t)), (RADIUS - 0.018) * math.cos(math.radians(t))) for t in range(90, -1, -3)]
pod.lathe(inner, "PaintIn", axis="Z", segs=72, closed=False)

# Frame strips: the rim round the glass, four meridians and two cross strips over the glass,
# riveted inside and out; ribs over the shell.
band(pod, R, U, 0.0, math.tau, RADIUS + 0.012, 0.09, 0.05, 96, "Frame", closed=True)
band_rivets(pod, R, U, RADIUS + 0.012, 0.05, 28, full=True)
for yaw in (-1.08, -0.52, 0.52, 1.08):
	d = (math.sin(yaw), 0, -math.cos(yaw))
	band(pod, D, d, 0.0, math.pi, RADIUS + 0.01, 0.065, 0.04, 48, "Frame")
	band_rivets(pod, D, d, RADIUS + 0.01, 0.04, 9)
for elev in (0.45, -0.37):
	e = (0, math.sin(elev), -math.cos(elev))
	band(pod, L, e, 0.0, math.pi, RADIUS + 0.01, 0.065, 0.04, 48, "Frame")
	band_rivets(pod, L, e, RADIUS + 0.01, 0.04, 9)
band(pod, D, B, 0.0, math.pi, RADIUS + 0.012, 0.075, 0.035, 40, "Frame")
band(pod, L, B, 0.0, math.pi, RADIUS + 0.012, 0.075, 0.035, 40, "Frame")
band_rivets(pod, D, B, RADIUS + 0.012, 0.035, 10, inner=False)
band_rivets(pod, L, B, RADIUS + 0.012, 0.035, 10, inner=False)
# Rivet rows along the shell's plate seams.
for polar in (40, 68):
	for i in range(36):
		a = math.tau * i / 36
		t = math.radians(polar)
		d = Vector((math.cos(a) * math.sin(t), math.sin(a) * math.sin(t), math.cos(t)))
		rivet(pod, tuple(d * RADIUS * 1.004), tuple(d), 0.009)

# The hatch on top: a ring, the lid with its hinge and a handle.
pod.lathe([(0.0, RADIUS - 0.03), (0.24, RADIUS - 0.03), (0.24, RADIUS + 0.02), (0.22, RADIUS + 0.035), (0.0, RADIUS + 0.035)], "Frame", axis="Y", segs=40, bevel=0.004)
pod.lathe([(0.0, RADIUS + 0.03), (0.19, RADIUS + 0.03), (0.19, RADIUS + 0.05), (0.15, RADIUS + 0.065), (0.0, RADIUS + 0.07)], "Paint", axis="Y", segs=40)
for i in range(12):
	a = math.tau * i / 12
	hexbolt(pod, (math.cos(a) * 0.215, RADIUS + 0.035, math.sin(a) * 0.215), U, 0.011, 0.01)
pod.cyl((0, RADIUS + 0.06, 0.2), 0.022, 0.16, "Steel", rot=(0, 0, 90), sides=16)
pod.box((0, RADIUS + 0.05, 0.19), (0.18, 0.025, 0.05), "Dark")
pod.strut((-0.06, RADIUS + 0.07, -0.05), (-0.06, RADIUS + 0.11, -0.05), 0.008, "Steel")
pod.strut((0.06, RADIUS + 0.07, -0.05), (0.06, RADIUS + 0.11, -0.05), 0.008, "Steel")
pod.strut((-0.065, RADIUS + 0.11, -0.05), (0.065, RADIUS + 0.11, -0.05), 0.011, "Rubber")

# Trunnions: a flange on each side of the ball, the axle and the bracket out to the receiver.
for s in (-1.0, 1.0):
	pod.lathe([(0.0, s * (RADIUS - 0.06)), (0.33, s * (RADIUS - 0.06)), (0.33, s * (RADIUS + 0.02)), (0.31, s * (RADIUS + 0.04)),
		(0.0, s * (RADIUS + 0.04))], "Frame", axis="X", segs=40, bevel=0.004)
	pod.lathe([(0.0, s * (RADIUS + 0.03)), (0.16, s * (RADIUS + 0.03)), (0.16, s * 1.12), (0.14, s * 1.15), (0.0, s * 1.15)], "Steel", axis="X", segs=32)
	for i in range(10):
		a = math.tau * i / 10
		hexbolt(pod, (s * (RADIUS + 0.04), math.sin(a) * 0.26, math.cos(a) * 0.26), (s, 0, 0), 0.016, 0.014)
	pod.box((s * 1.11, 0, 0), (0.14, 0.24, 0.3), "Frame", bevel=0.012)
	for z in (-0.1, 0.1):
		for y in (-0.08, 0.08):
			hexbolt(pod, (s * 1.11, y, z + (0.05 if z > 0 else -0.05)), (0, 0, 1 if z > 0 else -1), 0.012, 0.01)

# The receivers: chamfered boxes with a hinged feed cover, side ribs and rivets, the charging
# handle, a recessed ejection port underneath, and the belt chute back into the ball.
for s in (-1.0, 1.0):
	x0, x1 = sorted((s * 1.15, s * 1.39))
	xc = s * 1.27
	rec = lib.Part("Rec")
	rec.profile([(-0.5, 0.2), (-0.47, 0.23), (0.32, 0.23), (0.4, 0.15), (0.4, -0.15), (0.34, -0.23), (-0.47, -0.23), (-0.5, -0.2)],
		x0, x1, "Gunmetal", bevel=0.008, segments=2)
	ro = rec.build()
	cut = lib.Part("Cut")
	cut.box((xc, -0.235, -0.15), (0.12, 0.05, 0.19), "Dark", bevel=0.01)
	cut.box((s * 1.39, 0.02, 0.05), (0.03, 0.035, 0.36), "Dark", bevel=0.008)
	lib.boolean(ro, cut.build())
	pod.merge_object(ro)
	pod.box((xc, -0.215, -0.15), (0.11, 0.005, 0.17), "Dark", bevel=0.002)
	# Feed cover and its hinge at the front, latch at the back.
	pod.profile([(-0.4, 0.23), (0.3, 0.23), (0.3, 0.255), (0.26, 0.265), (-0.36, 0.265), (-0.4, 0.25)], xc - 0.1, xc + 0.1, "Gunmetal", bevel=0.004)
	pod.cyl((xc, 0.25, -0.42), 0.018, 0.22, "Steel", rot=(0, 0, 90), sides=14)
	pod.box((xc, 0.262, 0.31), (0.06, 0.03, 0.04), "Steel", bevel=0.006)
	for z in (-0.25, -0.05, 0.15):
		pod.box((xc, 0.268, z), (0.17, 0.008, 0.02), "Gunmetal", bevel=0.003)
	# Front plate (the barrel trunnions) with collars for the two barrels.
	pod.box((xc, 0, -0.5), (0.27, 0.49, 0.045), "Frame", bevel=0.01)
	for y in (-0.12, 0.12):
		pod.lathe([(0.04, -0.47), (0.095, -0.47), (0.095, -0.53), (0.085, -0.545), (0.04, -0.545)], "Steel", axis="Z", center=(xc, y, 0), segs=24)
		for i in range(6):
			a = math.tau * i / 6 + 0.3
			hexbolt(pod, (xc + math.cos(a) * 0.075, y + math.sin(a) * 0.075, -0.545), F, 0.008, 0.008)
	# Ribs and rivets on the outboard side, and a maker's plate.
	xo = s * 1.39
	for z in (-0.35, -0.12, 0.12, 0.3):
		pod.box((s * 1.396, 0, z), (0.014, 0.4, 0.035), "Gunmetal", bevel=0.004)
	for z in (-0.44, 0.36):
		for y in (-0.18, -0.06, 0.06, 0.18):
			rivet(pod, (xo, y, z), (s, 0, 0), 0.008, "Gunmetal")
	pod.box((s * 1.392, -0.12, -0.23), (0.006, 0.07, 0.12), "Brass", bevel=0.002)
	# The charging handle in its slot.
	pod.box((s * 1.385, 0.02, 0.18), (0.03, 0.025, 0.05), "Steel", bevel=0.005)
	pod.strut((s * 1.39, 0.02, 0.18), (s * 1.45, 0.02, 0.18), 0.009, "Steel")
	pod.cyl((s * 1.455, 0.02, 0.18), 0.02, 0.05, "Rubber", rot=(90, 0, 0), sides=14)
	# Belt chute: linked segments from the receiver back to the ball, brass rounds showing.
	chute = [(s * 1.14, -0.06, 0.3), (s * 1.05, -0.12, 0.44), (s * 0.95, -0.17, 0.55), (s * 0.84, -0.21, 0.63)]
	for a, b in zip(chute, chute[1:]):
		av, bv = Vector(a), Vector(b)
		d = (bv - av).normalized()
		upv = Vector((0, 1, 0))
		xax = upv.cross(d).normalized()
		yax = d.cross(xax)
		with pod.at(tuple((av + bv) * 0.5), basis=lib.godot_basis(xax, yax, d)):
			ln = (bv - av).length
			pod.box((0, 0, 0), (0.12, 0.1, ln * 0.92), "Dark", bevel=0.01)
			pod.box((0, 0.052, 0), (0.09, 0.006, ln * 0.7), "Brass", bevel=0.002)
	for c in chute[1:-1]:
		pod.box(c, (0.135, 0.115, 0.03), "Steel", bevel=0.006)

# The cabin: the floor, the seat, the control desk with its switches and grips, and the sight.
pod.lathe([(0.0, -0.87), (0.64, -0.87), (0.64, -0.84), (0.62, -0.825), (0.0, -0.825)], "Floor", axis="Y", segs=48)
pod.box((0, -0.72, -0.45), (0.38, 0.03, 0.07), "Steel", bevel=0.006)
for x in (-0.15, 0.15):
	pod.strut((x, -0.825, -0.42), (x, -0.72, -0.45), 0.012, "Steel")
pod.lathe([(0.0, -0.825), (0.09, -0.825), (0.09, -0.8), (0.045, -0.78), (0.045, -0.62), (0.0, -0.62)], "Steel", axis="Y", center=(0, 0, 0.16), segs=20)
pod.box((0, -0.61, 0.16), (0.4, 0.03, 0.38), "Dark", bevel=0.008)
pod.box((0, -0.565, 0.16), (0.44, 0.07, 0.4), "Leather", bevel=0.03)
with pod.at((0, -0.24, 0.4), (12, 0, 0)):
	pod.box((0, 0, 0.02), (0.44, 0.57, 0.04), "Dark", bevel=0.01)
	pod.box((0, 0, -0.02), (0.42, 0.55, 0.06), "Leather", bevel=0.028)
	for y in (-0.12, 0.08):
		pod.box((0, y, -0.052), (0.36, 0.008, 0.01), "Leather", bevel=0.003)
with pod.at((0, 0.2, 0.26), (12, 0, 0)):
	pod.box((0, 0, 0), (0.24, 0.15, 0.07), "Leather", bevel=0.028)
	for x in (-0.07, 0.07):
		pod.strut((x, -0.07, 0.02), (x, -0.16, 0.05), 0.008, "Steel")
for x in (-0.23, 0.23):
	with pod.at((x, -0.4, 0.3), (-30, 0, 0)):
		pod.box((0, 0, 0), (0.035, 0.05, 0.5), "Steel", bevel=0.008)
		pod.box((0, 0.03, -0.05), (0.05, 0.025, 0.3), "Rubber", bevel=0.01)

# The control desk (sloping, rot 29.4 deg), the fascia under it, and the hand grips.
with pod.at((0, -0.31, -0.54), (29.4, 0, 0)):
	pod.box((0, 0, 0), (0.92, 0.05, 0.37), "Olive", bevel=0.01)
	pod.box((0, 0.02, 0.18), (0.94, 0.014, 0.025), "Stripes", bevel=0.004)
	pod.box((0, 0.026, -0.03), (0.86, 0.004, 0.24), "Dark", bevel=0.001)
	for i in range(6):
		x = -0.36 + i * 0.065 if i < 3 else 0.17 + (i - 3) * 0.065
		pod.box((x, 0.035, 0.07), (0.024, 0.022, 0.042), "Dark", bevel=0.004)
		with pod.at((x, 0.05, 0.068), (-28, 0, 0)):
			pod.cyl((0, 0.018, 0), 0.0035, 0.036, "Steel", sides=10)
			pod.sphere((0, 0.037, 0), 0.006, "Steel", segs=12, rings=6)
		pod.box((x, 0.029, 0.11), (0.03, 0.002, 0.012), "Brass", bevel=0.0005)
	for x in (-0.3, 0.3):
		prof = [(0.0, 0.025), (0.034, 0.025), (0.034, 0.03), (0.03, 0.045), (0.027, 0.06), (0.0, 0.062)]
		pod.lathe(prof, "Dark", axis="Y", center=(x, 0, -0.08), segs=18)
		pod.lathe([(0.0, 0.061), (0.006, 0.061), (0.006, 0.064), (0.0, 0.064)], "Steel", axis="Y", center=(x, 0, -0.08), segs=10)
		for i in range(10):
			a = math.tau * i / 10
			pod.box((x + math.cos(a) * 0.042, 0.028, -0.08 + math.sin(a) * 0.042), (0.004, 0.002, 0.008), "Steel", rot=(0, -math.degrees(a), 0), bevel=0)
	for x in (-0.44, 0.44):
		for z in (-0.16, 0.16):
			hexbolt(pod, (x, 0.025, z), U, 0.008, 0.006)
pod.box((0, -0.42, -0.74), (0.8, 0.38, 0.06), "Olive", bevel=0.01)
for x in (-0.36, 0.36):
	for y in (-0.57, -0.27):
		hexbolt(pod, (x, y, -0.71), B, 0.009, 0.007)
pod.box((0, -0.5, -0.705), (0.5, 0.12, 0.012), "Dark", bevel=0.003)
for i in range(7):
	pod.box((-0.18 + i * 0.06, -0.5, -0.698), (0.03, 0.08, 0.004), "Steel", bevel=0.001)
# The grips: a bar across, two spade grips with red firing buttons.
pod.strut((-0.24, -0.33, -0.42), (0.24, -0.33, -0.42), 0.017, "Steel")
for x in (-0.24, 0.24):
	pod.strut((x, -0.33, -0.42), (x * 1.15, -0.4, -0.6), 0.014, "Steel")
for x in (-0.19, 0.19):
	prof = [(0.0, -0.345), (0.026, -0.345), (0.024, -0.33), (0.025, -0.31), (0.022, -0.29), (0.025, -0.27), (0.022, -0.25),
		(0.025, -0.23), (0.024, -0.215), (0.0, -0.212)]
	pod.lathe(prof, "Rubber", axis="Y", center=(x, 0, -0.42), segs=16)
	pod.lathe([(0.0, -0.214), (0.021, -0.214), (0.021, -0.205), (0.0, -0.205)], "Steel", axis="Y", center=(x, 0, -0.42), segs=16)
	pod.sphere((x, -0.203, -0.42), 0.014, "Lamp", scale=(1, 0.55, 1), segs=14, rings=7)
# The reflector sight: the lamp housing on its post, the amber slit, the glass holder.
pod.cyl((0, -0.148, -0.49), 0.011, 0.325, "Steel", sides=12)
pod.lathe([(0.0, -0.3), (0.022, -0.3), (0.022, -0.29), (0.012, -0.28), (0.0, -0.28)], "Steel", axis="Y", center=(0, 0, -0.49), segs=12)
pod.box((0, 0.0375, -0.47), (0.05, 0.045, 0.12), "Frame", bevel=0.006)
for x in (-0.026, 0.026):
	for z in (-0.5, -0.44):
		hexbolt(pod, (x, 0.04, z), (math.copysign(1, x), 0, 0), 0.005, 0.004)
pod.box((0, 0.045, -0.4095), (0.03, 0.006, 0.002), "SightLamp", bevel=0)
pod.box((0, 0.063, -0.45), (0.132, 0.008, 0.02), "Frame", bevel=0.002)
for x in (-0.063, 0.063):
	pod.box((x, 0.145, -0.45), (0.007, 0.17, 0.01), "Frame", bevel=0.002)
	pod.cyl((x, 0.23, -0.45), 0.007, 0.012, "Steel", rot=(0, 0, 90), sides=10)

# The display housing on the desk (its screens, text and lamps are the game's).
with pod.at((0, -0.13, -0.745), (-23, 0, 0)):
	pod.box((0, 0, 0), (0.9, 0.2, 0.1), "Olive", bevel=0.012)
	pod.box((0, 0.104, 0.03), (0.92, 0.016, 0.07), "Dark", bevel=0.005)
	for x in (-0.228, 0.228):
		w, h, ow, oh = 0.31, 0.145, 0.335, 0.168
		for (cx, cy, sx, sy) in ((0, (h + oh) / 4, ow, (oh - h) / 2), (0, -(h + oh) / 4, ow, (oh - h) / 2),
				((w + ow) / 4, 0, (ow - w) / 2, h), (-(w + ow) / 4, 0, (ow - w) / 2, h)):
			pod.box((x + cx, -0.01 + cy, 0.054), (sx, sy, 0.008), "Dark", bevel=0.002)
		pod.box((x, -0.01, 0.0505), (w + 0.004, h + 0.004, 0.001), "Dark", bevel=0)
		for y in (-0.085, 0.065):
			for bx in (-0.155, 0.155):
				hexbolt(pod, (x + bx, y, 0.058), B, 0.006, 0.004)
	for lx, ly in ((-0.418, 0.04), (-0.418, -0.03), (0.418, 0.04), (0.418, -0.03)):
		pod.torus((lx, ly, 0.052), 0.016, 0.004, "Steel", rot=(90, 0, 0), maj_seg=20, min_seg=6)
	pod.box((0, -0.094, 0.0505), (0.38, 0.016, 0.002), "Dark", bevel=0)
pod_o = pod.build()

# --- Armour (heavy pods) -----------------------------------------------------------------------
arm = lib.Part("Armour")
for x in (-0.48, 0.48):
	for (y, z, h, tilt) in ((0.42, 0.88, 0.42, -25), (-0.4, 0.9, 0.36, 22)):
		with arm.at((x, y, z), (tilt, -x * 55.0, 0)):
			arm.box((0, 0, 0), (0.5, h, 0.08), "Frame", bevel=0.015)
			for cx in (-0.21, 0.21):
				for cy in (-h / 2 + 0.035, h / 2 - 0.035):
					hexbolt(arm, (cx, cy, 0.046), B, 0.013, 0.012)
arm_o = arm.build()

# --- Collar (yaw frame) ----------------------------------------------------------------------------
col = lib.Part("Collar")
col.lathe([(0.79, -0.81), (0.965, -0.81), (0.985, -0.79), (0.985, -0.73), (0.965, -0.71), (0.79, -0.71), (0.78, -0.72), (0.78, -0.8)],
	"Dark", axis="Y", segs=96, bevel=0.0)
col.lathe([(0.986, -0.775), (0.995, -0.775), (0.995, -0.745), (0.986, -0.745)], "Accent", axis="Y", segs=96)
for i in range(32):
	a = math.tau * i / 32
	hexbolt(col, (math.cos(a) * 0.93, -0.71, math.sin(a) * 0.93), U, 0.012, 0.01)
for i in range(4):
	a = math.tau * i / 4 + math.pi / 4
	d = Vector((math.cos(a), 0, math.sin(a)))
	with col.at(tuple(d * 0.92 + Vector((0, -0.79, 0))), (0, -math.degrees(a), 0)):
		col.box((0, 0, 0), (0.18, 0.14, 0.18), "Dark", bevel=0.012)
		col.box((0, -0.05, 0), (0.2, 0.03, 0.2), "Stripes", bevel=0.005)
	top = d * 0.84 + Vector((0, -0.84, 0))
	bot = d * 0.42 + Vector((0, -1.02, 0))
	mid = top.lerp(bot, 0.45)
	col.strut(tuple(top), tuple(mid), 0.045, "Dark", sides=14)
	col.strut(tuple(mid), tuple(bot), 0.026, "Steel", sides=14)
	col.strut(tuple(top.lerp(bot, 0.42)), tuple(top.lerp(bot, 0.48)), 0.052, "Steel", sides=14)
col_o = col.build()

# --- Barrel ------------------------------------------------------------------------------------------
# The perforated cooling jacket (round holes through it), its end rings, and the bare barrel and
# flash hider ("Hot").
bar = lib.Part("BarrelJacket")
bar.lathe([(0.064, 0.0), (0.072, 0.0), (0.072, -1.1), (0.064, -1.1)], "Jacket", axis="Z", segs=36)
jo = bar.build()
holes = lib.Part("Holes")
for j in range(7):
	for k in range(6):
		a = math.tau * k / 6 + (math.pi / 6 if j % 2 else 0.0)
		d = (math.cos(a), math.sin(a), 0)
		z = -0.16 - j * 0.13
		holes.strut((d[0] * 0.05, d[1] * 0.05, z), (d[0] * 0.09, d[1] * 0.09, z), 0.017, "Dark", sides=12)
lib.boolean(jo, holes.build())
barrel = lib.Part("Barrel")
barrel.merge_object(jo)
for z0, z1 in ((0.01, -0.05), (-1.06, -1.12)):
	barrel.lathe([(0.0365, z0), (0.082, z0), (0.084, (z0 + z1) / 2), (0.082, z1), (0.0365, z1)], "Gunmetal", axis="Z", segs=36)
for z in (-0.06, -1.05):
	for i in range(8):
		a = math.tau * i / 8 + math.pi / 8
		rivet(barrel, (math.cos(a) * 0.072, math.sin(a) * 0.072, z), (math.cos(a), math.sin(a), 0), 0.006, "Steel", segs=8)
barrel_o = barrel.build()

hot = lib.Part("BarrelHot")
hot.lathe([(0.0, 0.0), (0.034, 0.0), (0.034, -1.0), (0.037, -1.12), (0.036, -1.82), (0.0, -1.82)], "Hot", axis="Z", segs=24)
hider = lib.Part("Hider")
hider.lathe([(0.03, -1.79), (0.05, -1.79), (0.056, -1.82), (0.075, -2.0), (0.06, -2.0), (0.03, -1.83)], "Hot", axis="Z", segs=32)
ho = hider.build()
slots = lib.Part("Slots")
for k in range(4):
	a = math.tau * k / 4 + math.pi / 4
	slots.box((math.cos(a) * 0.065, math.sin(a) * 0.065, -1.95), (0.02, 0.06, 0.13), "Dark", rot=(0, 0, math.degrees(a) + 90), bevel=0.006)
lib.boolean(ho, slots.build())
hot.merge_object(ho)
hot_o = hot.build()

objs = [pod_o, arm_o, col_o, barrel_o, hot_o]
lib.unwrap(objs, margin=0.002)
imgs = lib.bake(objs, 4096, "gun_pod", ao_distance=0.25, emissive=True)
lib.finalize(objs, imgs)
lib.export(objs, os.path.join(lib.OUT, "gun_pod", "gun_pod.gltf"))

# Previews: the pod assembled with four barrels.
import bpy  # noqa: E402
barrel_o.hide_render = True
hot_o.hide_render = True
for p in ((-1.27, 0.12, -0.45), (1.27, 0.12, -0.45), (-1.27, -0.12, -0.45), (1.27, -0.12, -0.45)):
	for src in (barrel_o, hot_o):
		c = src.copy()
		c.location = G(*p)
		c.hide_render = False
		bpy.context.scene.collection.objects.link(c)
lib.preview("gun_pod", (0, -0.1, -0.6), 7.0, [(-30, 15), (150, 20), (-90, 5), (0, 60)])
