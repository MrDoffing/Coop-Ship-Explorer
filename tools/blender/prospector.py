"""The Prospector's exterior (ShipTypes "prospector"), in ship-local space (+Y up, -Z forward, the
deck floor at y = 0).

The hull is lofted through exactly the sections in ship_types.gd, so the interior, the collision
boxes, the glazed nose and everything the game places on the hull still fit. Copy any change to
those numbers here.

Objects in the .gltf:
- "Hull": the hull, its rear cap round the cargo door and the chin under the glazing. It is not
  baked: its material "Hull" is swapped in the game for the tiling hull plating
  (Models.hull_plating), and its grime and wear are decals (ShipMarks), which cost far less memory
  than a baked texture the size of a ship.
- "Fittings": everything on it: belts, armour skirts, hatches, the spine, roof equipment, engines,
  gun pod towers, the scout dock, landing gear bays, the tractor emitter, lamps and windows.
The game still makes: the glazing and its frames, the gun pods and mining laser, the cameras, the
landing legs, the auto turret hardpoints, the engine glow, blinking lights, lights, and the decals
(name, markings, grime, damage).

    blender -b -P tools/blender/prospector.py
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import bmesh  # noqa: E402
import lib  # noqa: E402
from lib import G  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

# --- From ship_types.gd / ship_builder.gd ------------------------------------------------------------
SECTIONS = [[-10.25, 4.0, 2.62, 1.4], [-9.2, 4.4, 2.95, 1.4], [-7.4, 4.7, 3.05, 1.4], [-6.6, 7.3, 3.25, 1.4],
	[7.0, 7.4, 3.3, 1.4], [10.4, 6.6, 3.0, 1.4], [11.8, 5.0, 2.3, 1.4]]
NOSE = [[-10.25, 4.0, 2.62, 1.4], [-11.45, 3.35, 2.15, 1.5], [-12.5, 2.25, 1.62, 1.48]]
SILL = 0.35
CHAMFER = 0.3
C = 1.0 - CHAMFER
DOOR_HALF_W = 1.4
DOOR_H = 2.8
RAMP_HINGE_Z = 11.8
GUN_PODS = [(-10.0, 1.9, -5.0), (10.0, 1.9, -5.0)]
POD_MOUNT_TOP = 1.02
POD_TOWER_DROP = 2.7
MINING = (0, -0.75, -13.0)
SCOUT_DOCK = (0, -3.15, 3.5)
LEGS = [(-3.4, -1.7, -7.0), (3.4, -1.7, -7.0), (-4.6, -1.7, 8.6), (4.6, -1.7, 8.6)]
HATCHES = [(0, 4.75, -2.0), (-4.2, 4.75, 3.0), (0, 4.75, 7.2)]
COLLECTOR = (0, -2.0, -2.0)


def section_at(z):
	if z <= SECTIONS[0][0]:
		return SECTIONS[0][1:]
	for a, b in zip(SECTIONS, SECTIONS[1:]):
		if z <= b[0]:
			t = (z - a[0]) / max(b[0] - a[0], 0.001)
			return [a[i] + (b[i] - a[i]) * t for i in (1, 2, 3)]
	return SECTIONS[-1][1:]


def top_y(z):
	w, h, yc = section_at(z)
	return yc + h


def bottom_y(z):
	w, h, yc = section_at(z)
	return yc - h


def hull_x_at(z, y):
	w, h, yc = section_at(z)
	dy = abs(y - yc)
	if dy >= h:
		return 0.0
	if dy <= h * C:
		return w
	return w + (w * C - w) * (dy - h * C) / (h * CHAMFER)


def octagon(z, w, h, yc, grow=0.0):
	"""The hull's octagon at z, grown outwards by `grow` (along each face's normal)."""
	pts = [(w, h * C), (w * C, h), (-w * C, h), (-w, h * C), (-w, -h * C), (-w * C, -h), (w * C, -h), (w, -h * C)]
	if grow:
		out = []
		n = len(pts)
		for i in range(n):
			p = Vector(pts[i])
			a = Vector(pts[i - 1])
			b = Vector(pts[(i + 1) % n])
			n1 = Vector(((p - a).y, -(p - a).x)).normalized()
			n2 = Vector(((b - p).y, -(b - p).x)).normalized()
			if n1.dot(p) < 0:
				n1, n2 = -n1, -n2
			m = (n1 + n2).normalized()
			out.append(tuple(p + m * grow / max(m.dot(n1), 0.2)))
		pts = out
	return [(x, y + yc, z) for x, y in pts]


# --- Kinds ----------------------------------------------------------------------------------------
lib.reset()
K = lib.kind
K("Hull", (0.62, 0.64, 0.68), 0.25, 0.5, wear=0.35, grime=0.6, streaks=0.5, plates=1.4, seam=0.012, scratch=0.3, edge=0.08, noise=0.08, seam_dark=0.3)
K("HullDark", (0.52, 0.54, 0.58), 0.3, 0.5, wear=0.4, grime=0.5, streaks=0.35, plates=0.7, seam=0.01, scratch=0.3, edge=0.04)
K("Accent", (0.95, 0.5, 0.12), 0.3, 0.5, wear=0.5, grime=0.4, streaks=0.3, edge=0.03)
K("Dark", (0.14, 0.15, 0.18), 0.6, 0.5, wear=0.4, grime=0.45, edge=0.03, bare=(0.45, 0.46, 0.48))
K("Mid", (0.32, 0.34, 0.38), 0.6, 0.45, wear=0.45, grime=0.5, streaks=0.25, edge=0.03, plates=0.6, seam=0.008)
K("Steel", (0.55, 0.57, 0.6), 0.8, 0.3, grime=0.4, scratch=0.4)
K("Black", (0.07, 0.07, 0.08), 0.4, 0.65, grime=0.3)
K("Hazard", (0.95, 0.74, 0.1), 0.3, 0.5, wear=0.55, grime=0.5, edge=0.02)
K("Stripes", (0.95, 0.74, 0.1), 0.3, 0.5, wear=0.5, grime=0.5, edge=0.02, stripes=(0, 0, 0, 0.32))
K("Nozzle", (0.28, 0.26, 0.25), 0.85, 0.42, grime=0.8, wear=0.0, edge=0.03, scratch=0.2, grime_color=(0.08, 0.07, 0.06))
K("Rubber", (0.05, 0.05, 0.05), 0.0, 0.8, grime=0.3)
K("Window", (0.1, 0.08, 0.05), 0.0, 0.3, emit=(1.0, 0.84, 0.58, 1.5))
K("RedLamp", (0.05, 0.05, 0.05), 0.0, 0.4, emit=(1.0, 0.15, 0.1, 5.0))
K("GreenLamp", (0.05, 0.05, 0.05), 0.0, 0.4, emit=(0.2, 1.0, 0.3, 5.0))
K("WhiteLamp", (0.05, 0.05, 0.05), 0.0, 0.3, emit=(1.0, 0.95, 0.85, 4.0))
K("AmberLamp", (0.05, 0.05, 0.05), 0.0, 0.4, emit=(1.0, 0.6, 0.15, 4.0))
K("Cyan", (0.05, 0.05, 0.05), 0.0, 0.4, emit=(0.35, 0.85, 1.0, 2.5))


def rivet(part, pos, normal, r=0.03, kind="Steel"):
	prof = [(0.0, -0.005), (r, -0.005), (r, 0.006), (r * 0.7, r * 0.5), (0.0, r * 0.65)]
	n = G(*normal).normalized()
	part.lathe(prof, kind, axis="Y", segs=8, matrix=Matrix.Translation(G(*pos)) @ n.to_track_quat("Z", "Y").to_matrix().to_4x4())


def face_box(part, center, normal, along, size, kind, bevel=0.02):
	"""A box on a face: `size` = (across, out of the face, along `along`)."""
	n = Vector(normal).normalized()
	a = Vector(along).normalized()
	a = (a - n * a.dot(n)).normalized()
	x = n.cross(a)
	part.box(center, size, kind, basis=lib.godot_basis(x, n, a), bevel=bevel)


def edge_normal(p, q, yc):
	d = Vector(q) - Vector(p)
	n = Vector((d.y, -d.x)).normalized()
	mid = (Vector(p) + Vector(q)) * 0.5 - Vector((0, yc))
	return n if n.dot(mid) > 0 else -n


# --- Hull ----------------------------------------------------------------------------------------------
hull = lib.Part("Hull")
hull.loft([octagon(s[0], s[1], s[2], s[3]) for s in SECTIONS], "Hull", cap_start=False, cap_end=False, bevel=0.07, angle=20.0)


def clip(poly, a, b, c):
	"""Sutherland-Hodgman: keep the part of `poly` (2D) where a x + b y + c >= 0."""
	out = []
	for i in range(len(poly)):
		p, q = poly[i - 1], poly[i]
		fp, fq = a * p[0] + b * p[1] + c, a * q[0] + b * q[1] + c
		if fq >= 0:
			if fp < 0:
				t = fp / (fp - fq)
				out.append((p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t))
			out.append(q)
		elif fp >= 0:
			t = fp / (fp - fq)
			out.append((p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t))
	return out


# The rear cap with the cargo door cut out of it.
s = SECTIONS[-1]
ring = [(p[0], p[1]) for p in octagon(*s)]
zc = s[0]
y0, y1, hw = -0.05, DOOR_H + 0.15, DOOR_HALF_W
for piece in (clip(ring, -1, 0, -hw), clip(ring, 1, 0, -hw), clip(clip(clip(ring, 1, 0, hw), -1, 0, hw), 0, 1, -y1),
		clip(clip(clip(ring, 1, 0, hw), -1, 0, hw), 0, -1, y0)):
	if len(piece) >= 3:
		hull.mesh_piece([(x, y, zc) for x, y in piece], [list(range(len(piece)))], "Hull")


# The chin: the nose below the sill, closed at the front (ShipBuilder.nose_bottom).
def nose_bottom(r):
	z, w, h, yc = r
	return [(w, SILL, z), (w, min(yc - h * C, SILL), z), (w * C, min(yc - h, SILL), z), (-w * C, min(yc - h, SILL), z),
		(-w, min(yc - h * C, SILL), z), (-w, SILL, z)]


bots = [nose_bottom(r) for r in NOSE]
verts = [p for b in bots for p in b]
faces = []
for i in range(len(bots) - 1):
	for k in range(5):
		a, b2 = i * 6 + k, i * 6 + k + 1
		faces.append([a, b2, b2 + 6, a + 6])
last = (len(bots) - 1) * 6
faces.append([last + k for k in range(6)])
hull.mesh_piece(verts, faces, "Hull")
hull_o = hull.build(sharp=40.0)

# --- Fittings ------------------------------------------------------------------------------------------
fit = lib.Part("Fittings")

# Belts round the hull where its sections meet (not over the sides where the name is painted).
for z, sides in ((-6.45, True), (7.0, False), (10.4, False)):
	w, h, yc = section_at(z)
	pts = octagon(z, w, h, yc)
	for i in range(8):
		p, q = pts[i], pts[(i + 1) % 8]
		n2 = edge_normal(p[:2], q[:2], yc)
		if not sides and abs(n2.x) > 0.99:
			continue
		n = Vector((n2.x, n2.y, 0))
		mid = (Vector(p) + Vector(q)) * 0.5 + n * 0.035
		ln = (Vector(p) - Vector(q)).length
		face_box(fit, tuple(mid), tuple(n), (q[0] - p[0], q[1] - p[1], 0), (0.3, 0.07, ln + 0.06), "Mid", bevel=0.02)
		for f in (0.15, 0.5, 0.85):
			rp = Vector(p).lerp(Vector(q), f) + n * 0.072
			for dz in (-0.1, 0.1):
				rivet(fit, (rp.x, rp.y, rp.z + dz), tuple(n), 0.025)


def side_plate(side, z0, z1, ya, yb, kind="HullDark", t=0.03, rivets=True):
	"""An armour plate on the hull's vertical side between z0..z1 and heights ya..yb."""
	xa, xb = hull_x_at(z0, (ya + yb) / 2), hull_x_at(z1, (ya + yb) / 2)
	along = Vector((side * (xb - xa), 0, z1 - z0)).normalized()
	n = Vector((along.z, 0, -along.x)).normalized()
	if n.x * side < 0:
		n = -n
	c = Vector((side * (xa + xb) / 2, (ya + yb) / 2, (z0 + z1) / 2)) + n * (t / 2)
	ln = Vector((xb - xa, 0, z1 - z0)).length
	face_box(fit, tuple(c), tuple(n), tuple(along), (yb - ya, t, ln), kind, bevel=0.012)
	if rivets:
		for f in (0.06, 0.5, 0.94):
			for y in (ya + 0.06, yb - 0.06):
				p = c + along * (f - 0.5) * ln + n * (t / 2)
				rivet(fit, (p.x, y, p.z), tuple(n), 0.022)


for side in (-1, 1):
	# Armour skirt along the lower side, plate by plate.
	z = -6.2
	while z < 9.6:
		z1 = min(z + 1.75, 9.9)
		side_plate(side, z + 0.03, z1 - 0.03, -0.82, 0.05)
		z = z1
	# The accent stripe high up and a dark stripe low down (as before), and a plate band at the top.
	side_plate(side, -5.5, 6.5, 2.99, 3.31, "Accent", t=0.025, rivets=False)
	side_plate(side, -5.5, 6.5, 0.13, 0.27, "Dark", t=0.02, rivets=False)
	# Round portholes along the crew deck, lit from inside.
	for i in range(5):
		pz = 1.6 + i * 1.3
		x = hull_x_at(pz, 2.62)
		ring = [(0.0, 0.0), (0.2, 0.0), (0.2, 0.04), (0.17, 0.07), (0.15, 0.07), (0.15, 0.03), (0.0, 0.03)]
		fit.lathe([(r, side * h) for r, h in ring], "Steel", axis="X", center=(side * (x - 0.01), 2.62, pz), segs=24)
		fit.lathe([(0.0, 0.0), (0.152, 0.0), (0.152, side * 0.035), (0.0, side * 0.035)], "Window", axis="X", center=(side * (x - 0.01), 2.62, pz), segs=24)
		for k in range(6):
			a = math.tau * k / 6
			rivet(fit, (side * (x + 0.04), 2.62 + math.sin(a) * 0.185, pz + math.cos(a) * 0.185), (side, 0, 0), 0.014)
	# The gunnery window's frame (open: the gunner looks out through it).
	xw = hull_x_at(-2.5, 1.8)
	for dz in (-1.55, 1.55):
		fit.box((side * (xw + 0.04), 1.8, -2.5 + dz), (0.08, 1.7, 0.14), "Dark", bevel=0.02)
	for dy in (-0.78, 0.78):
		fit.box((side * (xw + 0.04), 1.8 + dy, -2.5), (0.08, 0.14, 3.24), "Dark", bevel=0.02)
	for dz in (-1.55, 1.55):
		for y in (1.2, 1.8, 2.4):
			rivet(fit, (side * (xw + 0.08), y, -2.5 + dz), (side, 0, 0), 0.025)
	fit.box((side * (xw + 0.05), 2.68, -2.5), (0.12, 0.05, 3.5), "Dark", bevel=0.015)
	# Vents on the tapering stern quarter.
	zv, yv = 9.4, 1.2
	xa, xb = hull_x_at(zv - 0.6, yv), hull_x_at(zv + 0.6, yv)
	along = Vector((side * (xb - xa), 0, 1.2)).normalized()
	n = Vector((along.z, 0, -along.x)).normalized()
	if n.x * side < 0:
		n = -n
	base = Vector((side * hull_x_at(zv, yv), yv, zv))
	face_box(fit, tuple(base + n * 0.02), tuple(n), tuple(along), (1.0, 0.04, 1.25), "Black", bevel=0.01)
	for i in range(6):
		off = (i - 2.5) * 0.18
		face_box(fit, tuple(base + n * 0.05 + along * off), tuple(n), tuple(along), (0.9, 0.05, 0.07), "Mid", bevel=0.01)
	# Navigation lights on the shoulders, red to port and green to starboard.
	fit.lathe([(0.0, 0.0), (0.2, 0.0), (0.2, side * 0.08), (0.0, side * 0.08)], "Dark", axis="X", center=(side * 7.36, 3.6, -6.4), segs=16)
	fit.sphere((side * 7.45, 3.6, -6.4), 0.13, "GreenLamp" if side > 0 else "RedLamp", segs=16, rings=8)

# Roof: shoulder plates, hatches, the dorsal spine, equipment.
for side in (-1, 1):
	for (x, z, sx, sz) in ((4.2, -1.2, 1.6, 3.0), (4.4, 8.4, 1.4, 2.4)):
		y = top_y(z)
		fit.box((side * x, y + 0.03, z), (sx, 0.06, sz), "HullDark", bevel=0.02)
		for cx in (-sx / 2 + 0.08, sx / 2 - 0.08):
			for cz in (-sz / 2 + 0.08, 0, sz / 2 - 0.08):
				rivet(fit, (side * x + cx, y + 0.06, z + cz), (0, 1, 0), 0.025)

for hx, hy, hz in HATCHES:
	y = top_y(hz)
	fit.lathe([(0.0, y - 0.02), (0.82, y - 0.02), (0.82, y + 0.05), (0.76, y + 0.08), (0.0, y + 0.08)], "Mid", axis="Y", center=(hx, 0, hz), segs=40)
	fit.lathe([(0.0, y + 0.07), (0.66, y + 0.07), (0.66, y + 0.11), (0.6, y + 0.13), (0.0, y + 0.135)], "HullDark", axis="Y", center=(hx, 0, hz), segs=40)
	fit.lathe([(0.0, y + 0.13), (0.62, y + 0.13), (0.62, y + 0.135), (0.0, y + 0.135)], "Stripes", axis="Y", center=(hx, 0, hz), segs=40)
	fit.lathe([(0.0, y + 0.134), (0.5, y + 0.134), (0.5, y + 0.14), (0.0, y + 0.14)], "HullDark", axis="Y", center=(hx, 0, hz), segs=40)
	for k in range(16):
		a = math.tau * k / 16
		rivet(fit, (hx + math.cos(a) * 0.74, y + 0.08, hz + math.sin(a) * 0.74), (0, 1, 0), 0.025)
	fit.box((hx, y + 0.12, hz + 0.72), (0.5, 0.1, 0.12), "Dark", bevel=0.02)
	fit.cyl((hx, y + 0.16, hz + 0.72), 0.045, 0.55, "Steel", rot=(0, 0, 90))
	fit.torus((hx, y + 0.2, hz), 0.2, 0.025, "Steel", maj_seg=24, min_seg=8)
	for a in (0, math.pi / 2):
		fit.strut((hx + math.cos(a) * 0.2, y + 0.2, hz + math.sin(a) * 0.2), (hx - math.cos(a) * 0.2, y + 0.2, hz - math.sin(a) * 0.2), 0.015, "Steel")
	fit.cyl((hx, y + 0.17, hz), 0.04, 0.07, "Steel")

# The dorsal spine: a raised housing with vent grilles and a red lamp at the front.
spine = [(-0.68, 0.0), (0.68, 0.0), (0.56, 0.26), (-0.56, 0.26)]
ys = top_y(2.6) - 0.02
fit.profile([(x, ys + y) for x, y in spine], -0.85, 6.05, "Mid", bevel=0.03, plane="XY")
for i in range(6):
	z = -0.3 + i * 1.0
	fit.box((0, ys + 0.262, z), (0.9, 0.012, 0.6), "Black", bevel=0.0)
	for j in range(5):
		fit.box((0, ys + 0.275, z - 0.24 + j * 0.12), (0.88, 0.02, 0.04), "Dark", bevel=0.006)
fit.lathe([(0.0, ys + 0.26), (0.12, ys + 0.26), (0.12, ys + 0.3), (0.0, ys + 0.3)], "Dark", axis="Y", center=(0, 0, -0.9), segs=16)
fit.sphere((0, ys + 0.33, -0.9), 0.09, "RedLamp", segs=16, rings=8)

# Roof equipment: a box with a lid, a tank rack, pipes, the dish's platform and the antenna bases.
for (x, z, sx, sy, sz) in ((-3.5, -1.0, 1.2, 0.4, 1.4), (3.0, 8.0, 1.6, 0.3, 2.2)):
	y = top_y(z)
	fit.box((x, y + sy / 2, z), (sx, sy, sz), "Mid", bevel=0.03)
	fit.box((x, y + sy + 0.03, z), (sx - 0.2, 0.06, sz - 0.2), "Dark", bevel=0.02)
	for cx in (-1, 1):
		fit.box((x + cx * (sx / 2 + 0.01), y + sy * 0.55, z), (0.03, 0.06, 0.3), "Steel", bevel=0.01)
y = top_y(-4.5)
fit.box((4.5, y + 0.12, -4.5), (0.8, 0.24, 2.4), "Dark", bevel=0.03)
for i in range(3):
	zt = -5.3 + i * 0.8
	fit.lathe([(0.0, y + 0.2), (0.3, y + 0.2), (0.32, y + 0.3), (0.32, y + 0.55), (0.26, y + 0.62), (0.0, y + 0.63)], "Steel", axis="Y", center=(4.5, 0, zt), segs=24)
	fit.torus((4.5, y + 0.42, zt), 0.325, 0.02, "Dark", maj_seg=24, min_seg=6)
	fit.cyl((4.5, y + 0.66, zt), 0.04, 0.06, "Hazard")
y = top_y(4.4)
fit.cyl((-1.6, y + 0.2, 4.4), 0.12, 6.0, "Steel", rot=(90, 0, 0), sides=20)
fit.cyl((-1.95, y + 0.16, 4.4), 0.08, 6.0, "Accent", rot=(90, 0, 0), sides=16)
for z in (1.8, 3.4, 5.0, 6.8):
	fit.box((-1.75, y + 0.08, z), (0.6, 0.16, 0.12), "Dark", bevel=0.02)
	fit.torus((-1.6, y + 0.2, z), 0.13, 0.018, "Dark", rot=(90, 0, 0), maj_seg=20, min_seg=6)
	fit.torus((-1.95, y + 0.16, z), 0.09, 0.016, "Dark", rot=(90, 0, 0), maj_seg=20, min_seg=6)
for z in (1.4, 7.4):
	fit.lathe([(0.0, -0.0), (0.17, 0.0), (0.17, 0.06), (0.14, 0.09), (0.0, 0.09)], "Steel", axis="Z", center=(-1.6, y + 0.2, z if z > 2 else z - 0.09), segs=20)

# Antenna masts (their blinking tips are the game's) and the sensor dish.
for (x, z, hgt) in ((-2.5, 9.0, 1.8), (-2.2, 9.7, 1.1)):
	y = top_y(z)
	fit.lathe([(0.0, y - 0.02), (0.2, y - 0.02), (0.2, y + 0.06), (0.12, y + 0.16), (0.0, y + 0.16)], "Dark", axis="Y", center=(x, 0, z), segs=16)
	fit.cyl((x, y + 0.16 + hgt / 2, z), 0.045, hgt, "Steel", top=0.022, sides=10)
	for i in range(2):
		hy = y + hgt * (0.45 + i * 0.25)
		fit.box((x, hy, z), (0.5 - i * 0.15, 0.03, 0.03), "Steel", bevel=0.008)
		for s_ in (-1, 1):
			fit.sphere((x + s_ * (0.25 - i * 0.075), hy, z), 0.02, "Dark", segs=8, rings=4)
y = top_y(8.0) + 0.3
fit.cyl((3.0, y + 0.25, 8.0), 0.12, 0.5, "Dark", sides=16)
with fit.at((3.0, y + 0.55, 8.0), (-35, 30, 0)):
	prof = [(0.0, 0.02)] + [(0.7 * t / 10, 0.02 + 0.22 * (t / 10) ** 2) for t in range(1, 11)] + \
		[(0.72, 0.25)] + [(0.7 * t / 10, 0.0 + 0.22 * (t / 10) ** 2) for t in range(10, 0, -1)] + [(0.0, 0.0)]
	fit.lathe(prof, "Steel", axis="Y", segs=32)
	fit.torus((0, 0.245, 0), 0.71, 0.02, "Dark", maj_seg=40, min_seg=6)
	for k in range(3):
		a = math.tau * k / 3
		fit.strut((math.cos(a) * 0.62, 0.2, math.sin(a) * 0.62), (0, 0.55, 0), 0.012, "Steel")
	fit.cyl((0, 0.58, 0), 0.05, 0.1, "Dark", sides=12)
	fit.cyl((0, -0.06, 0), 0.1, 0.14, "Dark", sides=16)

# Attitude thruster blocks with their nozzles.
for side in (-1, 1):
	for (pos, dirs) in (((side * 6.7, 4.05, -6.0), ((side, 0, 0), (0, 1, 0), (0, 0, -1))),
			((side * 6.1, 3.75, 10.0), ((side, 0, 0), (0, 1, 0), (0, 0, 1)))):
		fit.box(pos, (0.62, 0.44, 0.62), "Mid", bevel=0.04)
		fit.box((pos[0], pos[1] + 0.23, pos[2]), (0.5, 0.04, 0.5), "Dark", bevel=0.01)
		for d in dirs:
			dv = Vector(d)
			c = Vector(pos) + dv * 0.31
			n = G(*dv).normalized()
			fit.lathe([(0.06, 0.0), (0.08, 0.0), (0.08, 0.05), (0.14, 0.2), (0.12, 0.2), (0.06, 0.06)], "Nozzle", axis="Y", segs=16,
				matrix=Matrix.Translation(G(*c)) @ n.to_track_quat("Z", "Y").to_matrix().to_4x4())

# Gun pod towers: a box girder out of the hull with lightening holes, a brace under it, and the
# column up to the pod's collar with hazard bands and hydraulic lines.
for (px, py, pz) in GUN_PODS:
	sx = 1 if px > 0 else -1
	top = py - POD_MOUNT_TOP
	arm_y = py - POD_TOWER_DROP
	root_x = sx * (hull_x_at(pz, arm_y) - 0.5)
	end_x = px + sx * 0.3
	arm = lib.Part("Arm")
	x0, x1 = sorted((root_x, end_x))
	arm.box(((x0 + x1) / 2, arm_y, pz), (x1 - x0, 0.52, 0.5), "Mid", bevel=0.03)
	ao = arm.build()
	holes = lib.Part("Holes")
	for k in range(4):
		hx = root_x + (px - root_x) * (0.18 + k * 0.2)
		holes.cyl((hx, arm_y, pz), 0.14, 0.7, "Dark", rot=(90, 0, 0), sides=20)
	holes.box(((x0 + x1) / 2, arm_y, pz), (x1 - x0 - 0.3, 0.4, 0.38), "Dark", bevel=0.0)
	lib.boolean(ao, holes.build())
	fit.merge_object(ao)
	fit.box(((x0 + x1) / 2, arm_y + 0.275, pz), (x1 - x0 - 0.1, 0.03, 0.38), "Accent", bevel=0.01)
	fit.box(((x0 + x1) / 2, arm_y - 0.12, pz + 0.28), (x1 - x0 - 0.2, 0.08, 0.06), "Black", bevel=0.01)
	for k in range(5):
		rivet(fit, (root_x + (px - root_x) * (0.08 + k * 0.2), arm_y + 0.2, pz - 0.252), (0, 0, -1), 0.025)
		rivet(fit, (root_x + (px - root_x) * (0.08 + k * 0.2), arm_y - 0.2, pz - 0.252), (0, 0, -1), 0.025)
	brace_y = arm_y - 0.8
	fit.strut((sx * (hull_x_at(pz, brace_y) - 0.15), brace_y, pz), (px - sx * 0.3, arm_y - 0.22, pz), 0.09, "Dark", sides=12)
	fit.box((sx * (hull_x_at(pz, brace_y) - 0.05), brace_y, pz), (0.2, 0.3, 0.4), "Dark", bevel=0.02)
	fit.box((root_x - sx * 0.1, arm_y, pz), (0.12, 0.7, 0.7), "Dark", bevel=0.02)
	fit.lathe([(0.0, arm_y + 0.2), (0.48, arm_y + 0.2), (0.48, arm_y + 0.3), (0.36, arm_y + 0.36), (0.36, top - 0.12),
		(0.5, top - 0.1), (0.5, top), (0.0, top)], "Mid", axis="Y", center=(px, 0, pz), segs=32)
	for k in range(2):
		fit.lathe([(0.0, arm_y + 0.75 + k * 0.5), (0.372, arm_y + 0.75 + k * 0.5), (0.372, arm_y + 0.99 + k * 0.5), (0.0, arm_y + 0.99 + k * 0.5)],
			"Stripes", axis="Y", center=(px, 0, pz), segs=32)
	for k in range(12):
		a = math.tau * k / 12
		rivet(fit, (px + math.cos(a) * 0.43, top + 0.0, pz + math.sin(a) * 0.43), (0, 1, 0), 0.025)
	for dz in (-0.15, 0.15):
		fit.strut((px - sx * 0.38, arm_y + 0.3, pz + dz), (px - sx * 0.38, top - 0.15, pz + dz), 0.03, "Black", sides=8)
		for yy in (arm_y + 0.6, top - 0.4):
			fit.box((px - sx * 0.37, yy, pz + dz), (0.06, 0.05, 0.08), "Steel", bevel=0.01)

# The mining laser's pylon under the chin, and the headlamps on the chin's front.
mz = MINING[2] + 0.82
top = SILL - 0.05
bot = MINING[1] + 0.25
fit.profile([(mz - 0.3, top), (mz + 0.3, top), (mz + 0.3, bot + 0.1), (mz + 0.2, bot), (mz - 0.24, bot), (mz - 0.3, bot + 0.06)], -0.28, 0.28, "Mid", bevel=0.03)
fit.box((0, bot + 0.12, mz), (0.585, 0.08, 0.62), "Stripes", bevel=0.01)
for x in (-0.2, 0.2):
	fit.strut((x, top - 0.05, mz - 0.31), (x, bot + 0.2, mz - 0.31), 0.025, "Black", sides=8)
fit.box((0, 0.12, -12.53), (1.12, 0.28, 0.12), "Dark", bevel=0.025)
for sxl in (-1, 1):
	cx = sxl * 1.1 * 0.27
	fit.lathe([(0.0, -12.55), (0.13, -12.55), (0.13, -12.6), (0.115, -12.61), (0.0, -12.61)], "Steel", axis="Z", center=(cx, 0.12, 0), segs=24)
	fit.lathe([(0.0, -12.6), (0.1, -12.6), (0.1, -12.615), (0.0, -12.62)], "WhiteLamp", axis="Z", center=(cx, 0.12, 0), segs=24)
for i in range(3):
	fit.box((0, 0.06 + i * 0.06, -12.6), (0.14, 0.014, 0.014), "Steel", bevel=0.004)

# The scout dock under the belly: a plate, the cradle rails and the launch light.
py_ = bottom_y(SCOUT_DOCK[2]) - 0.04
fit.box((0, py_ + 0.02, SCOUT_DOCK[2]), (3.8, 0.12, 5.8), "Dark", bevel=0.03)
fit.box((0, py_ - 0.045, SCOUT_DOCK[2]), (3.4, 0.02, 5.4), "Black", bevel=0.0)
for x in (-1.5, 1.5):
	hy = abs(py_ - SCOUT_DOCK[1] - 0.62) + 0.1
	fit.box((x, (py_ + SCOUT_DOCK[1] + 0.62) * 0.5, SCOUT_DOCK[2]), (0.25, hy, 3.2), "Mid", bevel=0.03)
	fit.box((x, SCOUT_DOCK[1] + 0.62 - 0.02, SCOUT_DOCK[2]), (0.32, 0.06, 3.3), "Stripes", bevel=0.01)
	for dz in (-1.2, 0, 1.2):
		fit.strut((x, py_, SCOUT_DOCK[2] + dz), (x * 0.6, py_ - 0.02, SCOUT_DOCK[2] + dz + 0.4), 0.04, "Steel")
fit.box((0, py_ - 0.06, SCOUT_DOCK[2] - 3.1), (3.0, 0.08, 0.3), "Accent", bevel=0.02)
fit.sphere((0, py_ - 0.09, SCOUT_DOCK[2] + 3.3), 0.12, "GreenLamp", segs=16, rings=8)

# Landing gear bays (the legs fold flat into them).
for (lx, ly, lz) in LEGS:
	by = bottom_y(lz)
	d = 1.0 if lz < 0 else -1.0
	cz = lz + d * 1.15
	fit.box((lx, by - 0.02, cz), (1.2, 0.04, 3.1), "Black", bevel=0.01)
	for x in (-0.62, 0.62):
		fit.box((lx + x, by - 0.04, cz), (0.08, 0.06, 3.2), "Stripes", bevel=0.01)
	for z in (-1.58, 1.58):
		fit.box((lx, by - 0.04, cz + z), (1.32, 0.06, 0.08), "Dark", bevel=0.01)

# The tractor field emitter under the belly.
cx, _, cz = COLLECTOR
cy = bottom_y(cz)
fit.lathe([(0.0, cy + 0.02), (1.15, cy + 0.02), (1.15, cy - 0.1), (1.0, cy - 0.14), (0.8, cy - 0.14), (0.8, cy - 0.1), (0.0, cy - 0.1)], "Dark", axis="Y", center=(cx, 0, cz), segs=48)
fit.lathe([(0.7, cy - 0.12), (0.78, cy - 0.12), (0.78, cy - 0.16), (0.7, cy - 0.16)], "Cyan", axis="Y", center=(cx, 0, cz), segs=48)
fit.lathe([(0.0, cy - 0.1), (0.45, cy - 0.1), (0.4, cy - 0.22), (0.15, cy - 0.3), (0.0, cy - 0.3)], "Steel", axis="Y", center=(cx, 0, cz), segs=32)
for k in range(8):
	a = math.tau * k / 8
	fit.box((cx + math.cos(a) * 0.62, cy - 0.12, cz + math.sin(a) * 0.62), (0.3, 0.05, 0.06), "Mid", rot=(0, -math.degrees(a), 0), bevel=0.01)

# Belly hatch outline and the belly antenna.
yb = bottom_y(-5.5)
fit.box((0, yb - 0.02, -5.5), (3.4, 0.04, 2.6), "HullDark", bevel=0.01)
fit.box((0, yb - 0.045, -5.5 - 1.15), (3.0, 0.02, 0.12), "Stripes", bevel=0.0)
yb = bottom_y(9.3)
fit.lathe([(0.0, yb + 0.02), (0.12, yb + 0.02), (0.12, yb - 0.06), (0.0, yb - 0.06)], "Dark", axis="Y", center=(2.2, 0, 9.3), segs=12)
fit.cyl((2.2, yb - 0.45, 9.3), 0.035, 0.8, "Steel", top=0.02, sides=8)

# Engines: housings either side of the cargo door, two nacelles on pylons. Their glow is the game's.
for side in (-1, 1):
	fit.box((side * 2.2, 1.3, 12.3), (1.4, 3.0, 1.6), "Mid", bevel=0.04)
	fit.box((side * 2.2, 1.3, 13.12), (1.1, 2.6, 0.06), "Dark", bevel=0.01)
	for i in range(5):
		fit.box((side * 2.2, 0.4 + i * 0.45, 13.16), (0.9, 0.06, 0.04), "Mid", bevel=0.01)
	ex, ey = side * 4.5, 1.1
	prof = [(0.0, 10.5), (1.1, 10.5), (1.12, 10.42), (1.62, 10.45), (1.66, 10.6), (1.6, 10.78), (1.58, 13.55), (1.64, 13.6), (1.64, 13.82),
		(1.48, 13.86), (1.3, 14.66), (1.24, 14.72), (1.08, 14.7), (0.98, 14.3), (0.0, 14.3)]
	fit.lathe(prof, "Mid", axis="Z", center=(ex, ey, 0), segs=48)
	fit.lathe([(1.475, 13.85), (1.49, 13.85), (1.3, 14.66), (1.29, 14.66)], "Nozzle", axis="Z", center=(ex, ey, 0), segs=48)
	fit.lathe([(1.0, 14.31), (1.08, 14.69), (1.06, 14.7), (0.97, 14.32)], "Nozzle", axis="Z", center=(ex, ey, 0), segs=48)
	fit.lathe([(0.0, 14.2), (0.47, 14.2), (0.45, 14.3), (0.12, 14.64), (0.0, 14.66)], "Nozzle", axis="Z", center=(ex, ey, 0), segs=32)
	fit.lathe([(0.0, 10.46), (1.08, 10.46), (1.08, 10.5), (0.0, 10.5)], "Black", axis="Z", center=(ex, ey, 0), segs=32)
	for zb in (11.4, 12.3, 13.2):
		fit.lathe([(1.58, zb - 0.06), (1.63, zb - 0.05), (1.63, zb + 0.05), (1.58, zb + 0.06)], "Steel", axis="Z", center=(ex, ey, 0), segs=48)
	for i in range(8):
		a = math.tau * i / 8 + math.pi / 8
		r = 1.6
		fit.box((ex + math.cos(a) * (r + 0.12), ey + math.sin(a) * (r + 0.12), 12.0), (0.06, 0.26, 2.0), "Dark",
			rot=(0, 0, math.degrees(a) - 90.0), bevel=0.015)
	fit.box((side * 6.0, 1.1, 11.0), (0.6, 0.5, 2.0), "Dark", bevel=0.03)
	fit.box((side * 4.5, 2.75, 11.6), (0.5, 0.4, 2.2), "Mid", bevel=0.03)
	fit.strut((side * 3.4, 2.4, 11.2), (side * 4.2, 2.6, 12.4), 0.05, "Black", sides=8)
	fit.strut((side * 3.3, 2.2, 11.4), (side * 4.0, 2.5, 13.2), 0.04, "Black", sides=8)

# The cargo door frame on the stern: an accent lintel, striped posts and amber lamps.
zd = RAMP_HINGE_Z + 0.06
fit.box((0, DOOR_H + 0.32, zd), (DOOR_HALF_W * 2 + 0.34, 0.18, 0.14), "Accent", bevel=0.03)
for side in (-1, 1):
	fit.box((side * (DOOR_HALF_W + 0.17), DOOR_H * 0.5, zd), (0.24, DOOR_H + 0.25, 0.12), "Stripes", bevel=0.02)
	fit.lathe([(0.0, zd), (0.1, zd), (0.1, zd + 0.06), (0.0, zd + 0.06)], "Dark", axis="Z", center=(side * (DOOR_HALF_W - 0.15), DOOR_H + 0.5, 0), segs=16)
	fit.sphere((side * (DOOR_HALF_W - 0.15), DOOR_H + 0.5, zd + 0.07), 0.07, "AmberLamp", segs=12, rings=6)
fit_o = fit.build()

# --- Bake and export -----------------------------------------------------------------------------------
lib.unwrap([fit_o], margin=0.002)
fimgs = lib.bake([fit_o], 4096, "prospector_fit", ao_distance=0.8, ao_samples=256, emissive=True)
lib.finalize([fit_o], fimgs)
# The hull: one plain material for the game to replace.
import bpy  # noqa: E402
plain = bpy.data.materials.new("Hull_x")
plain.name = "Hull"
plain.use_backface_culling = True
plain.diffuse_color = (0.62, 0.64, 0.68, 1.0)
hull_o.data.materials.clear()
hull_o.data.materials.append(plain)
lib.export([hull_o, fit_o], os.path.join(lib.OUT, "prospector", "prospector.gltf"))
lib.preview("prospector", (0, 1.0, 0.5), 34.0, [(-40, 20), (135, 20), (-90, 3), (20, 70), (200, -25)], size=(1400, 900))
