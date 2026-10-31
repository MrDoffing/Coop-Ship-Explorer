"""The crew's hand weapons (CrewWeapons) other than the Pulse Rifle (rifle.py): Pistol, Revolver,
Submachine Gun, Photon Rifle, Marksman Rifle, Shotgun, Multiple Grenade Launcher and Storm Lance
("lightning"). One asset per weapon: assets/models/weapon_<id>/weapon_<id>.gltf.

Every object is in the frame of the node the game hangs it on (see CrewWeapons._build_<id>): the
weapon's frame has its origin at its middle, the barrel along -Z and the sight line on x = 0; the
moving parts ("Slide", "Bolt", "Pump", "Mag", "Hammer", "Crane", "Cylinder", "Clip", "Rounds",
"Nose", "Vent") have their origin where the game's node is, so they move as before. The game still
makes the sights' glowing dots and beads, the sight glass and reticles, the marksman rifle's scope,
the photon rifle's glass chamber, the display on top at the back and the muzzle flash. Materials
named "Accent" take the owner's colour, "Glow" the weapon's heat or charge glow.

    blender -b -P tools/blender/weapons.py -- pistol revolver ...   (no names: all of them)
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lib  # noqa: E402

ALL = ["pistol", "dual", "revolver", "smg", "photon", "marksman", "shotgun", "mgl", "lightning"]


def kinds():
	K = lib.kind
	K("Gun", (0.17, 0.18, 0.19), 0.78, 0.36, wear=0.6, grime=0.4, scratch=0.55, bare=(0.52, 0.52, 0.53), edge=0.0025)
	K("Dark", (0.11, 0.115, 0.12), 0.6, 0.45, wear=0.5, grime=0.4, scratch=0.45, bare=(0.45, 0.45, 0.46), edge=0.002)
	K("Steel", (0.34, 0.35, 0.36), 0.85, 0.3, grime=0.35, scratch=0.5, wear=0.3, bare=(0.6, 0.6, 0.6), edge=0.0015)
	K("Black", (0.02, 0.02, 0.02), 0.2, 0.85, grime=0.15)
	K("Olive", (0.27, 0.29, 0.21), 0.25, 0.68, wear=0.65, grime=0.45, scratch=0.6, bare=(0.3, 0.31, 0.31), edge=0.003, noise=0.08)
	K("Grip", (0.09, 0.08, 0.07), 0.05, 0.85, grime=0.5, noise=0.2, wear=0.3, bare=(0.2, 0.18, 0.16), edge=0.002)
	K("Wood", (0.34, 0.2, 0.1), 0.05, 0.62, grime=0.5, noise=0.3, wear=0.4, bare=(0.45, 0.3, 0.16), edge=0.002, scratch=0.4)
	K("Brass", (0.78, 0.58, 0.25), 0.9, 0.3, grime=0.3, scratch=0.3)
	K("Copper", (0.72, 0.4, 0.2), 0.88, 0.32, grime=0.35, scratch=0.3)
	K("Ceramic", (0.8, 0.78, 0.72), 0.0, 0.45, grime=0.45, noise=0.08)
	K("Nose", (0.3, 0.32, 0.22), 0.25, 0.6, grime=0.3, wear=0.3, bare=(0.4, 0.4, 0.38), edge=0.002)
	K("Red", (0.55, 0.08, 0.06), 0.15, 0.6, grime=0.3, wear=0.3, bare=(0.7, 0.55, 0.3), edge=0.002)
	K("Stainless", (0.6, 0.6, 0.58), 0.9, 0.27, grime=0.45, scratch=0.65, wear=0.2, bare=(0.75, 0.75, 0.74), edge=0.0015, noise=0.04)
	K("Glow", (0.08, 0.08, 0.09), 0.4, 0.5, export_as="Glow")
	K("Accent", (0.95, 0.95, 0.95), 0.0, 0.5, export_as="Accent")


def screw(part, pos, side, r=0.0025):
	"""A slotted screw head on the left (side -1) or right (side 1) face at `pos`."""
	prof = [(0.0, 0.0), (r, 0.0), (r, 0.0009), (r * 0.65, 0.0014), (0.0, 0.0014)]
	part.lathe([(rr, side * h) for rr, h in prof], "Steel", axis="X", center=pos, segs=10)


def ring(part, pos, inner, outer, kind, segs=32):
	"""A ring round the Z axis (a sight's ring), like the game's _ring()."""
	part.torus(pos, (inner + outer) * 0.5, (outer - inner) * 0.5, kind, rot=(90, 0, 0), maj_seg=segs, min_seg=8)


def tube_z(part, cx, cy, z0, z1, r_out, r_in, kind, segs=28):
	"""A tube along Z from z0 to z1 (z0 < z1), open at both ends."""
	part.lathe([(r_in, z0), (r_out, z0), (r_out, z1), (r_in, z1)], kind, axis="Z", center=(cx, cy, 0), segs=segs)


def disc_z(part, cx, cy, z, r, h, kind, segs=24):
	part.cyl((cx, cy, z), r, h, kind, rot=(90, 0, 0), sides=segs, bevel=min(0.0006, h * 0.3))


def trigger(part, x, y, z, rot=15):
	part.box((x, y, z), (0.005, 0.017, 0.006), "Steel", rot=(rot, 0, 0), bevel=0.0015)


def guard(part, z0, z1, y_top, depth, width=0.009):
	"""A trigger guard: a loop under the frame from z0 (front) to z1 (back), `depth` below y_top."""
	g = lib.Part("Guard")
	g.profile([(z0, y_top), (z0 + 0.004, y_top - depth), (z0 + 0.016, y_top - depth - 0.005), (z1 - 0.004, y_top - depth - 0.005),
		(z1, y_top - depth + 0.006), (z1, y_top)], -width * 0.5, width * 0.5, "Dark", bevel=0.0012)
	go = g.build()
	c = lib.Part("GuardCut")
	c.profile([(z0 + 0.006, y_top + 0.01), (z0 + 0.008, y_top - depth + 0.004), (z0 + 0.018, y_top - depth), (z1 - 0.006, y_top - depth),
		(z1 - 0.005, y_top + 0.01)], -0.03, 0.03, "Dark", bevel=0.0)
	lib.boolean(go, c.build())
	part.merge_object(go)


def finish(name, objs, size, target, distance, views):
	lib.unwrap(objs, margin=0.004)
	imgs = lib.bake(objs, size, "weapon_" + name, ao_distance=0.02)
	lib.finalize(objs, imgs)
	lib.export(objs, os.path.join(lib.OUT, "weapon_" + name, "weapon_" + name + ".gltf"))
	lib.preview("weapon_" + name, target, distance, views)


def local(o, pos, rot):
	"""Turn object `o` (built in the weapon's frame, origin at 0) into the frame of a node at `pos`
	turned by Godot degrees `rot` (its mesh then in that frame, as the game shows it)."""
	from mathutils import Matrix
	m = Matrix.Translation(lib.G(*pos)) @ lib.GR(*rot).to_4x4()
	o.data.transform(m.inverted())
	o.matrix_world = m
	return o


# --- Pistol --------------------------------------------------------------------------------------

def pistol():
	body = lib.Part("Body")
	# The frame: dust cover over the trigger guard, the front of the grip (its back stops short of the
	# display, which sits behind it).
	body.profile([(-0.112, 0.03), (0.074, 0.03), (0.08, 0.024), (0.08, 0.0), (0.07, -0.006),
		(-0.04, -0.006), (-0.07, 0.004), (-0.112, 0.006)], -0.021, 0.021, "Dark", bevel=0.0018)
	guard(body, -0.048, -0.004, -0.004, 0.024)
	trigger(body, 0, -0.01, -0.016)
	# The grip frame (raked back 14 degrees) with its panels, screws and the magazine well's flare.
	with body.at((0, -0.055, 0.045), (-14, 0, 0)):
		body.box((0, 0.0, 0), (0.036, 0.112, 0.054), "Dark", bevel=0.003)
		body.box((0, -0.054, 0), (0.04, 0.008, 0.058), "Dark", bevel=0.002)
		for s in (-1, 1):
			body.box((s * 0.0195, 0.002, 0.001), (0.004, 0.086, 0.046), "Wood", bevel=0.0015)
			for k in range(5):
				body.box((s * 0.0218, -0.03 + k * 0.016, 0.001), (0.0012, 0.003, 0.04), "Wood", bevel=0.0004)
			screw(body, (s * 0.0216, 0.03, 0.001), s, 0.0022)
			screw(body, (s * 0.0216, -0.03, 0.001), s, 0.0022)
		body.box((0, 0.0, 0.0285), (0.03, 0.09, 0.004), "Dark", bevel=0.0012)
		for k in range(8):
			body.box((0, -0.035 + k * 0.01, 0.0302), (0.026, 0.0025, 0.0012), "Black", bevel=0)
	# The barrel's muzzle and bushing ahead of the slide, the hammer, the levers on the left, the
	# magazine release and the owner's stripe.
	body.lathe([(0.0, -0.126), (0.011, -0.126), (0.011, -0.136), (0.0095, -0.138), (0.0055, -0.138), (0.0055, -0.133), (0.0, -0.133)],
		"Steel", axis="Z", center=(0, 0.045, 0), segs=20)
	body.cyl((0, 0.045, -0.1375), 0.0055, 0.001, "Black", rot=(90, 0, 0), sides=16, bevel=0)
	with body.at((0, 0.05, 0.08), (25, 0, 0)):
		body.box((0, 0.0, 0), (0.008, 0.016, 0.008), "Gun", bevel=0.0015)
		body.box((0, 0.009, 0.004), (0.011, 0.005, 0.009), "Gun", bevel=0.0012)
	body.box((-0.0222, 0.033, 0.0), (0.0025, 0.007, 0.034), "Gun", bevel=0.001)
	body.cyl((-0.0225, 0.033, -0.016), 0.004, 0.003, "Gun", rot=(0, 0, 90), sides=12, bevel=0.0008)
	body.box((-0.0222, 0.037, 0.06), (0.003, 0.008, 0.016), "Gun", bevel=0.001)
	body.cyl((-0.0215, 0.0, 0.035), 0.004, 0.003, "Steel", rot=(0, 0, 90), sides=12, bevel=0.0008)
	body.box((-0.0212, 0.012, 0.04), (0.002, 0.008, 0.06), "Accent", bevel=0.0004)
	body_o = body.build()

	# The slide: chamfered on top, serrations at the back, the ejection port on the right, the sights.
	sl = lib.Part("SlideBody")
	sl.profile([(-0.023, 0.029), (0.023, 0.029), (0.023, 0.058), (0.016, 0.067), (-0.016, 0.067), (-0.023, 0.058)], -0.13, 0.07, "Gun",
		bevel=0.0015, plane="XY")
	slo = sl.build()
	cut = lib.Part("SlideCut")
	cut.box((0.026, 0.054, -0.03), (0.012, 0.014, 0.032), "Dark", bevel=0.0)
	cut.cyl((0, 0.045, -0.13), 0.0115, 0.01, "Dark", rot=(90, 0, 0), sides=20, bevel=0)
	for k in range(6):
		z = 0.036 + k * 0.0055
		for s in (-1, 1):
			cut.box((s * 0.024, 0.048, z), (0.004, 0.034, 0.0022), "Dark", bevel=0.0)
	lib.boolean(slo, cut.build())
	slide = lib.Part("Slide")
	slide.merge_object(slo)
	slide.box((0.0195, 0.0535, -0.03), (0.003, 0.011, 0.03), "Black", bevel=0)
	slide.lathe([(0.0, -0.045), (0.0075, -0.045), (0.0075, -0.015), (0.0, -0.015)], "Brass", axis="Z", center=(0.012, 0.05, 0), segs=12)
	for x in (-0.011, 0.011):
		slide.box((x, 0.072, 0.058), (0.007, 0.012, 0.008), "Dark", bevel=0.0012)
	slide.box((0, 0.068, 0.058), (0.03, 0.004, 0.009), "Dark", bevel=0.0012)
	slide.profile([(-0.124, 0.066), (-0.113, 0.066), (-0.113, 0.077), (-0.118, 0.077)], -0.0025, 0.0025, "Dark", bevel=0.0008)
	slide_o = slide.build()

	mag = lib.Part("Mag")
	with mag.at((0, -0.055, 0.045), (-14, 0, 0)):
		mag.box((0, -0.005, 0), (0.03, 0.1, 0.042), "Steel", bevel=0.002)
		mag.box((0, -0.058, 0.0), (0.036, 0.009, 0.052), "Dark", bevel=0.002)
		mag.box((0, 0.046, -0.004), (0.026, 0.004, 0.034), "Steel", bevel=0.001)
		mag.cyl((0, 0.05, -0.004), 0.0048, 0.03, "Brass", rot=(90, 0, 0), sides=12, bevel=0.0008)
		for s in (-1, 1):
			for k in range(3):
				mag.cyl((s * 0.0152, -0.03 + k * 0.022, 0.004), 0.0025, 0.0008, "Black", rot=(0, 0, 90), sides=8, bevel=0)
	mag_o = local(mag.build(), (0, -0.055, 0.045), (-14, 0, 0))
	finish("pistol", [body_o, slide_o, mag_o], 1024, (0, 0.0, -0.02), 0.5, [(-90, 5), (-35, 20), (140, 25), (90, 0)])


# --- Dual pistols --------------------------------------------------------------------------------

def dual():
	"""A slim stainless service pistol with an open-top slide (the barrel shows through it); the game
	puts one in each hand. Body, Slide and Mag in the pistol's frames (the Mag's node at the grip)."""
	body = lib.Part("Body")
	# The frame: the dust cover over the trigger guard, the front of the grip; it stops short of the
	# display behind the hammer.
	body.profile([(-0.106, 0.03), (0.07, 0.03), (0.076, 0.024), (0.076, 0.0), (0.066, -0.006),
		(-0.036, -0.006), (-0.062, 0.003), (-0.106, 0.006)], -0.0185, 0.0185, "Stainless", bevel=0.0016)
	# The trigger guard, squared off in front with a finger hook under it, and the trigger.
	g = lib.Part("Guard")
	g.profile([(-0.05, -0.004), (-0.052, -0.026), (-0.048, -0.031), (-0.008, -0.031), (-0.002, -0.022), (-0.002, -0.004)],
		-0.0045, 0.0045, "Stainless", bevel=0.0012)
	go = g.build()
	c = lib.Part("GuardCut")
	c.profile([(-0.044, 0.01), (-0.045, -0.024), (-0.042, -0.026), (-0.011, -0.026), (-0.007, -0.02), (-0.007, 0.01)], -0.03, 0.03,
		"Stainless", bevel=0.0)
	lib.boolean(go, c.build())
	body.merge_object(go)
	body.profile([(-0.052, -0.03), (-0.046, -0.03), (-0.05, -0.038), (-0.055, -0.035)], -0.0035, 0.0035, "Stainless", bevel=0.001)
	trigger(body, 0, -0.012, -0.022, 20)
	# The grip (raked back 15 degrees): the frame, wraparound black panels with checkering, screws.
	with body.at((0, -0.055, 0.043), (-15, 0, 0)):
		body.box((0, 0.0, 0), (0.032, 0.112, 0.05), "Stainless", bevel=0.003)
		body.box((0, -0.054, 0), (0.035, 0.008, 0.053), "Stainless", bevel=0.002)
		for s in (-1, 1):
			body.box((s * 0.0175, 0.003, 0.002), (0.004, 0.092, 0.048), "Grip", bevel=0.0018)
			for k in range(7):
				body.box((s * 0.0197, -0.03 + k * 0.01, 0.002), (0.0012, 0.0024, 0.04), "Black", bevel=0.0003)
			screw(body, (s * 0.0196, 0.028, 0.002), s, 0.0021)
			screw(body, (s * 0.0196, -0.033, 0.002), s, 0.0021)
		body.box((0, 0.003, 0.0262), (0.026, 0.092, 0.004), "Grip", bevel=0.0012)
		for k in range(8):
			body.box((0, -0.034 + k * 0.01, 0.0284), (0.022, 0.0024, 0.0012), "Black", bevel=0)
	# The barrel, which shows through the open top of the slide, and its bore.
	body.lathe([(0.0, -0.137), (0.0103, -0.137), (0.0103, -0.004), (0.0, -0.004)], "Gun", axis="Z", center=(0, 0.045, 0), segs=20)
	body.cyl((0, 0.045, -0.1375), 0.0055, 0.001, "Black", rot=(90, 0, 0), sides=16, bevel=0)
	# The hammer: a round spur with a hole through it.
	with body.at((0, 0.052, 0.076), (18, 0, 0)):
		body.box((0, -0.002, 0), (0.007, 0.016, 0.008), "Gun", bevel=0.0015)
		body.cyl((0, 0.009, 0.003), 0.0075, 0.007, "Gun", rot=(0, 0, 90), sides=16, bevel=0.0012)
		for s in (-1, 1):
			body.cyl((s * 0.0036, 0.009, 0.003), 0.0028, 0.0008, "Black", rot=(0, 0, 90), sides=10, bevel=0)
	# The takedown lever over the trigger, the magazine release behind the guard, the owner's stripe.
	body.box((-0.019, 0.02, -0.034), (0.0025, 0.007, 0.022), "Gun", bevel=0.001)
	body.cyl((-0.0195, 0.02, -0.044), 0.0035, 0.003, "Gun", rot=(0, 0, 90), sides=12, bevel=0.0008)
	body.box((-0.0192, -0.004, 0.006), (0.003, 0.009, 0.008), "Gun", bevel=0.001)
	body.box((0.0192, 0.012, 0.03), (0.0015, 0.006, 0.05), "Accent", bevel=0.0004)
	body_o = body.build()

	# The slide: open on top from behind the front sight's bridge back to the breech, so the barrel
	# shows; the ejection port on the right, serrations at the back, the decocking levers either
	# side, the sights.
	sl = lib.Part("SlideBody")
	sl.profile([(-0.0195, 0.029), (0.0195, 0.029), (0.0195, 0.058), (0.0135, 0.066), (-0.0135, 0.066), (-0.0195, 0.058)], -0.136, 0.068,
		"Stainless", bevel=0.0014, plane="XY")
	slo = sl.build()
	# (The cutters must not overlap each other, or the boolean throws the slide away.)
	cut = lib.Part("SlideCut")
	cut.box((0, 0.062, -0.069), (0.026, 0.034, 0.08), "Dark", bevel=0.0)
	cut.box((0.021, 0.052, -0.012), (0.012, 0.014, 0.03), "Dark", bevel=0.0)
	cut.cyl((0, 0.045, -0.136), 0.0108, 0.01, "Dark", rot=(90, 0, 0), sides=20, bevel=0)
	for k in range(7):
		z = 0.03 + k * 0.0052
		for s in (-1, 1):
			cut.box((s * 0.0205, 0.047, z), (0.004, 0.03, 0.0022), "Dark", bevel=0.0)
	lib.boolean(slo, cut.build())
	# The walls either side of the open top dip lower, so more of the barrel shows (a second pass).
	dip = lib.Part("SlideDip")
	dip.box((0, 0.07, -0.069), (0.05, 0.02, 0.072), "Dark", bevel=0.0)
	lib.boolean(slo, dip.build())
	slide = lib.Part("Slide")
	slide.merge_object(slo)
	slide.lathe([(0.0, -0.04), (0.0068, -0.04), (0.0068, -0.012), (0.0, -0.012)], "Brass", axis="Z", center=(0.011, 0.05, 0), segs=12)
	slide.profile([(-0.131, 0.065), (-0.118, 0.065), (-0.118, 0.0745), (-0.124, 0.0745)], -0.0018, 0.0018, "Gun", bevel=0.0006)
	for x in (-0.0095, 0.0095):
		slide.box((x, 0.071, 0.058), (0.006, 0.011, 0.008), "Gun", bevel=0.001)
	slide.box((0, 0.067, 0.058), (0.026, 0.004, 0.009), "Gun", bevel=0.001)
	for s in (-1, 1):
		slide.cyl((s * 0.0205, 0.059, 0.052), 0.0048, 0.004, "Gun", rot=(0, 0, 90), sides=14, bevel=0.0008)
		slide.box((s * 0.0215, 0.064, 0.05), (0.0028, 0.0045, 0.015), "Gun", bevel=0.0008)
	slide_o = slide.build()

	mag = lib.Part("Mag")
	with mag.at((0, -0.055, 0.043), (-15, 0, 0)):
		mag.box((0, -0.005, 0), (0.027, 0.1, 0.04), "Steel", bevel=0.002)
		mag.box((0, -0.058, 0.0), (0.033, 0.009, 0.05), "Black", bevel=0.002)
		mag.box((0, 0.046, -0.004), (0.023, 0.004, 0.032), "Steel", bevel=0.001)
		mag.cyl((0, 0.05, -0.004), 0.0046, 0.028, "Brass", rot=(90, 0, 0), sides=12, bevel=0.0008)
		for s in (-1, 1):
			for k in range(3):
				mag.cyl((s * 0.0137, -0.03 + k * 0.022, 0.004), 0.0024, 0.0008, "Black", rot=(0, 0, 90), sides=8, bevel=0)
	mag_o = local(mag.build(), (0, -0.055, 0.043), (-15, 0, 0))
	finish("dual", [body_o, slide_o, mag_o], 1024, (0, 0.0, -0.02), 0.5, [(-90, 5), (-35, 20), (140, 25), (90, 0)])


# --- Revolver ------------------------------------------------------------------------------------

REV_AXIS = 0.022
REV_CRANE = (-0.004, REV_AXIS - 0.028, -0.001)
REV_CYL = (0.0, REV_AXIS, -0.001)


def revolver():
	body = lib.Part("Body")
	# The frame round the cylinder's window: top strap, recoil shield, the front the barrel screws in.
	fr = lib.Part("Frame")
	fr.profile([(-0.041, 0.0585), (0.03, 0.0585), (0.045, 0.05), (0.045, 0.028), (0.04, -0.012), (-0.041, -0.012)], -0.014, 0.014, "Gun", bevel=0.0018)
	fro = fr.build()
	cut = lib.Part("Window")
	cut.box((0, 0.0225, -0.0005), (0.05, 0.049, 0.051), "Gun", bevel=0.0)
	lib.boolean(fro, cut.build())
	body.merge_object(fro)
	# The rear sight's notch along the top strap.
	for x in (-0.0045, 0.0045):
		body.box((x, 0.0605, 0.016), (0.0035, 0.004, 0.01), "Dark", bevel=0.0006)
	# The barrel, its vented rib with the front sight's ramp, the lug under it with the ejector rod.
	body.lathe([(0.0, -0.04), (0.0088, -0.04), (0.0088, -0.168), (0.0078, -0.172), (0.0048, -0.172), (0.0048, -0.168), (0.0, -0.168)],
		"Steel", axis="Z", center=(0, 0.036, 0), segs=24)
	body.cyl((0, 0.036, -0.1715), 0.0048, 0.001, "Black", rot=(90, 0, 0), sides=16, bevel=0)
	body.box((0, 0.0465, -0.106), (0.009, 0.004, 0.13), "Gun", bevel=0.0008)
	for i in range(4):
		body.box((0, 0.0466, -0.06 - i * 0.03), (0.0094, 0.0026, 0.012), "Black", bevel=0)
	body.profile([(-0.168, 0.0485), (-0.152, 0.0485), (-0.152, 0.0605), (-0.158, 0.0605)], -0.00175, 0.00175, "Dark", bevel=0.0006)
	body.profile([(-0.16, 0.03), (-0.045, 0.03), (-0.04, 0.016), (-0.16, 0.016), (-0.163, 0.023)], -0.006, 0.006, "Gun", bevel=0.0015)
	body.cyl((0, 0.018, -0.155), 0.002, 0.012, "Steel", rot=(90, 0, 0), sides=10)
	# Screws on the side plate.
	for (y, z) in ((0.006, 0.02), (-0.006, -0.025), (0.045, 0.036)):
		screw(body, (0.014, y, z), 1, 0.002)
	# The grip: the frame's strap and wooden panels, the guard and trigger.
	with body.at((0, -0.056, 0.048), (-18, 0, 0)):
		body.box((0, 0.0, 0), (0.03, 0.1, 0.04), "Gun", bevel=0.003)
		for s in (-1, 1):
			body.box((s * 0.0158, -0.002, 0.001), (0.004, 0.084, 0.036), "Wood", bevel=0.0018)
			screw(body, (s * 0.0178, 0.0, 0.001), s, 0.0021)
		body.box((0, -0.05, 0.0), (0.032, 0.006, 0.042), "Gun", bevel=0.0015)
		body.torus((0, -0.056, 0.0), 0.004, 0.0012, "Steel", rot=(0, 0, 90), maj_seg=12, min_seg=6)
	guard(body, -0.024, 0.01, -0.012, 0.022, 0.008)
	trigger(body, 0, -0.016, 0.006)
	body.box((-0.0145, 0.022, 0.035), (0.002, 0.03, 0.006), "Accent", bevel=0.0004)
	# The crane's hinge pin (the crane swings out on it).
	body.cyl((REV_CRANE[0], REV_CRANE[1], -0.012), 0.0028, 0.05, "Steel", rot=(90, 0, 0), sides=10)
	body_o = body.build()

	ham = lib.Part("Hammer")
	with ham.at((0, 0.05, 0.036)):
		ham.box((0, 0.004, 0.003), (0.007, 0.014, 0.008), "Dark", bevel=0.0012)
		ham.box((0, 0.011, 0.01), (0.01, 0.004, 0.012), "Dark", rot=(-20, 0, 0), bevel=0.001)
		for k in range(3):
			ham.box((0, 0.0132, 0.006 + k * 0.003), (0.0102, 0.0008, 0.0012), "Black", rot=(-20, 0, 0), bevel=0)
	ham_o = ham.build(origin=(0, 0.05, 0.036))

	crane = lib.Part("Crane")
	cx, cy, cz = REV_CRANE
	crane.box((cx + 0.002, (cy + REV_AXIS) * 0.5, -0.026), (0.006, REV_AXIS - cy + 0.004, 0.005), "Gun", bevel=0.0012)
	crane.cyl((0, REV_AXIS, -0.026), 0.0045, 0.006, "Gun", rot=(90, 0, 0), sides=14, bevel=0.001)
	crane.cyl((0, REV_AXIS, -0.035), 0.0025, 0.014, "Steel", rot=(90, 0, 0), sides=10)
	crane_o = crane.build(origin=REV_CRANE)

	cyl = lib.Part("CylBody")
	cyl.lathe([(0.0, -0.023), (0.0205, -0.023), (0.0225, -0.021), (0.0225, 0.021), (0.0205, 0.023), (0.0, 0.023)], "Gun", axis="Z",
		center=(REV_CYL[0], REV_CYL[1], REV_CYL[2]), segs=36)
	cyo = cyl.build()
	cut = lib.Part("Flutes")
	for k in range(6):
		f = math.pi * 0.5 + k * math.tau / 6.0 + math.tau / 12.0
		cut.cyl((math.cos(f) * 0.0262, REV_CYL[1] + math.sin(f) * 0.0262, REV_CYL[2] + 0.002), 0.0052, 0.034, "Gun", rot=(90, 0, 0), sides=14, bevel=0)
	lib.boolean(cyo, cut.build())
	cylinder = lib.Part("Cylinder")
	cylinder.merge_object(cyo)
	for k in range(6):
		a = math.pi * 0.5 + k * math.tau / 6.0
		disc_z(cylinder, math.cos(a) * 0.014, REV_CYL[1] + math.sin(a) * 0.014, REV_CYL[2] - 0.0232, 0.0056, 0.0012, "Black", 14)
	disc_z(cylinder, 0, REV_CYL[1], REV_CYL[2] - 0.0245, 0.004, 0.003, "Steel", 14)
	cyl_o = cylinder.build(origin=REV_CYL)

	clip = lib.Part("Clip")
	at = (REV_CYL[0], REV_CYL[1], REV_CYL[2] + 0.0232)
	star = []
	for k in range(12):
		a = math.pi * 0.5 + k * math.tau / 12.0
		r = 0.0185 if k % 2 == 0 else 0.0105
		star.append((at[0] + math.cos(a) * r, at[1] + math.sin(a) * r))
	clip.profile(star, at[2] + 0.0001, at[2] + 0.0013, "Dark", bevel=0.0003, plane="XY")
	for k in range(6):
		a = math.pi * 0.5 + k * math.tau / 6.0
		px, py = at[0] + math.cos(a) * 0.014, at[1] + math.sin(a) * 0.014
		clip.lathe([(0.0, at[2] - 0.028), (0.0052, at[2] - 0.028), (0.0055, at[2] - 0.004), (0.0062, at[2] + 0.0011), (0.0062, at[2] + 0.0023),
			(0.0, at[2] + 0.0023)], "Brass", axis="Z", center=(px, py, 0), segs=14)
		disc_z(clip, px, py, at[2] + 0.0025, 0.0018, 0.0005, "Copper", 10)
	clip_o = clip.build(origin=at)
	finish("revolver", [body_o, ham_o, crane_o, cyl_o, clip_o], 1024, (0, 0.01, -0.04), 0.45, [(-90, 5), (-35, 20), (140, 25), (90, 0)])


# --- Submachine gun ------------------------------------------------------------------------------

def smg():
	bore = 0.012
	body = lib.Part("Body")
	# The stamped receiver, chamfered along its top, with the bolt's slot and the ejection port cut.
	rc = lib.Part("Receiver")
	rc.profile([(-0.024, -0.028), (0.024, -0.028), (0.024, 0.022), (0.018, 0.028), (-0.018, 0.028), (-0.024, 0.022)], -0.125, 0.125, "Gun",
		bevel=0.0015, plane="XY")
	rco = rc.build()
	cut = lib.Part("RCut")
	cut.box((0.025, 0.008, 0.02), (0.006, 0.006, 0.09), "Gun", bevel=0.0)
	cut.box((0.025, 0.019, -0.065), (0.006, 0.012, 0.03), "Gun", bevel=0.0)
	lib.boolean(rco, cut.build())
	body.merge_object(rco)
	body.box((0.02, 0.008, 0.02), (0.004, 0.006, 0.09), "Black", bevel=0)
	body.box((0.02, 0.019, -0.065), (0.004, 0.012, 0.03), "Black", bevel=0)
	body.box((0, 0.032, 0.01), (0.044, 0.008, 0.2), "Dark", bevel=0.0012)
	body.box((0, -0.004, 0.128), (0.044, 0.046, 0.008), "Dark", bevel=0.0015)
	for (y, z) in ((0.015, 0.11), (-0.015, 0.11), (0.015, -0.11), (-0.015, -0.11)):
		screw(body, (0.024, y, z), 1, 0.0022)
		screw(body, (-0.024, y, z), -1, 0.0022)
	# The cooling jacket: a slotted tube round the barrel, a slanted lip over the muzzle.
	jk = lib.Part("Jacket")
	tube_z(jk, 0, bore, -0.345, -0.125, 0.021, 0.0175, "Gun", 28)
	jko = jk.build()
	cut = lib.Part("Slots")
	for k in range(7):
		z = -0.15 - k * 0.028
		cut.box((0, bore, z), (0.06, 0.007, 0.013), "Gun", bevel=0.0)
		cut.box((0, bore, z - 0.014), (0.007, 0.06, 0.011), "Gun", bevel=0.0)
	lib.boolean(jko, cut.build())
	body.merge_object(jko)
	body.lathe([(0.0, -0.125), (0.0072, -0.125), (0.0072, -0.346), (0.0, -0.346)], "Steel", axis="Z", center=(0, bore, 0), segs=16)
	body.cyl((0, bore, -0.3465), 0.0062, 0.001, "Black", rot=(90, 0, 0), sides=14, bevel=0)
	body.box((0, bore + 0.019, -0.35), (0.046, 0.028, 0.008), "Dark", rot=(-35, 0, 0), bevel=0.0012)
	body.lathe([(0.0175, -0.13), (0.0225, -0.13), (0.0225, -0.122), (0.0175, -0.122)], "Dark", axis="Z", center=(0, bore, 0), segs=28)
	# The magazine well round the drum's neck.
	body.box((0, -0.034, -0.075), (0.032, 0.014, 0.044), "Dark", bevel=0.0015)
	# The wooden pistol grip with finger grooves, the guard and trigger, the owner's stripe.
	with body.at((0, -0.072, 0.078), (-15, 0, 0)):
		body.profile([(-0.022, 0.05), (0.022, 0.05), (0.024, -0.05), (-0.012, -0.05), (-0.02, -0.03), (-0.017, -0.012), (-0.022, 0.006),
			(-0.019, 0.024), (-0.024, 0.04)], -0.017, 0.017, "Wood", bevel=0.003, segments=3)
		body.box((0, -0.051, 0.002), (0.036, 0.004, 0.048), "Dark", bevel=0.001)
	guard(body, 0.006, 0.054, -0.028, 0.02, 0.008)
	trigger(body, 0, -0.036, 0.034)
	body.box((-0.0245, 0.0, 0.03), (0.002, 0.01, 0.12), "Accent", bevel=0.0004)
	# The peep sight on its post at the back, the hooded post at the front.
	body.box((0, 0.0425, 0.095), (0.006, 0.013, 0.004), "Dark", bevel=0.0008)
	ring(body, (0, 0.056, 0.095), 0.0035, 0.0075, "Dark")
	body.box((0, 0.0445, -0.33), (0.0025, 0.023, 0.004), "Dark", bevel=0.0005)
	ring(body, (0, 0.054, -0.33), 0.009, 0.0115, "Dark")
	body.box((0, 0.0385, -0.33), (0.024, 0.011, 0.006), "Dark", bevel=0.001)
	# Sling loops.
	body.torus((0, -0.03, 0.12), 0.007, 0.0016, "Steel", rot=(0, 0, 90), maj_seg=14, min_seg=6)
	body.torus((0, bore - 0.024, -0.3), 0.007, 0.0016, "Steel", rot=(0, 0, 90), maj_seg=14, min_seg=6)
	body_o = body.build()

	bolt = lib.Part("Bolt")
	b0 = (0.0255, 0.008, -0.02)
	bolt.lathe([(0.0, 0.0), (0.0035, 0.0), (0.0035, 0.006), (0.005, 0.007), (0.005, 0.012), (0.0, 0.012)], "Steel", axis="X",
		center=b0, segs=14)
	bolt_o = bolt.build(origin=b0)

	mag = lib.Part("Mag")
	m0 = (0, -0.028, -0.075)
	with mag.at(m0):
		mag.box((0, -0.01, 0), (0.026, 0.03, 0.036), "Dark", bevel=0.0015)
		mag.lathe([(0.0, -0.02), (0.05, -0.02), (0.054, -0.016), (0.054, 0.016), (0.05, 0.02), (0.0, 0.02)], "Steel", axis="X",
			center=(0, -0.07, -0.006), segs=40)
		for x in (-0.014, 0.014):
			mag.lathe([(0.053, x - 0.002), (0.0555, x - 0.002), (0.0555, x + 0.002), (0.053, x + 0.002)], "Dark", axis="X",
				center=(0, -0.07, -0.006), segs=40)
		mag.lathe([(0.0, -0.023), (0.012, -0.023), (0.012, -0.019), (0.0, -0.019)], "Dark", axis="X", center=(0, -0.07, -0.006), segs=20)
		mag.box((-0.0245, -0.07, -0.006), (0.003, 0.004, 0.022), "Steel", bevel=0.0008)
		for k in range(6):
			a = k * math.tau / 6
			mag.cyl((0.02, -0.07 + math.cos(a) * 0.044, -0.006 + math.sin(a) * 0.044), 0.002, 0.002, "Steel", rot=(0, 0, 90), sides=8, bevel=0)
	mag_o = mag.build(origin=m0)
	finish("smg", [body_o, bolt_o, mag_o], 2048, (0, -0.02, -0.08), 0.8, [(-90, 5), (-35, 20), (140, 25), (90, 0)])


# --- Photon rifle --------------------------------------------------------------------------------

def photon():
	body = lib.Part("Body")
	body.profile([(-0.03, -0.04), (0.03, -0.04), (0.03, 0.032), (0.022, 0.04), (-0.022, 0.04), (-0.03, 0.032)], -0.14, 0.2, "Olive",
		bevel=0.0025, plane="XY")
	body.box((0, 0.042, 0.04), (0.05, 0.006, 0.2), "Dark", bevel=0.0012)
	for z in (-0.1, 0.0, 0.1):
		for s in (-1, 1):
			screw(body, (s * 0.03, 0.022, z), s, 0.0025)
	# The emitter: a collar on the body, the copper core through cooling fins (they glow with the
	# heat), a slotted shroud and the lens at its end.
	body.lathe([(0.0, -0.152), (0.02, -0.152), (0.024, -0.146), (0.024, -0.138), (0.0, -0.138)], "Dark", axis="Z", segs=28)
	body.lathe([(0.0, -0.47), (0.012, -0.47), (0.012, -0.15), (0.0, -0.15)], "Copper", axis="Z", segs=20)
	for k in range(9):
		z = -0.17 - k * 0.032
		body.lathe([(0.012, z - 0.0025), (0.024, z - 0.0025), (0.026, z), (0.024, z + 0.0025), (0.012, z + 0.0025)], "Glow", axis="Z", segs=28)
	sh = lib.Part("Shroud")
	tube_z(sh, 0, 0, -0.505, -0.465, 0.028, 0.019, "Dark", 28)
	sho = sh.build()
	cut = lib.Part("ShroudCut")
	for k in range(6):
		a = k * math.tau / 6
		cut.box((math.cos(a) * 0.028, math.sin(a) * 0.028, -0.485), (0.012, 0.012, 0.02), "Dark", rot=(0, 0, math.degrees(a)), bevel=0.0)
	lib.boolean(sho, cut.build())
	body.merge_object(sho)
	body.lathe([(0.0, -0.5075), (0.017, -0.5075), (0.017, -0.505), (0.0, -0.505)], "Glow", axis="Z", segs=24)
	# The photon chamber on the left: end caps and the glowing core (the game adds its glass).
	for z in (-0.095, 0.075):
		disc_z(body, -0.037, 0.012, z, 0.016, 0.012, "Steel", 20)
	body.lathe([(0.0, -0.09), (0.0055, -0.09), (0.0055, 0.07), (0.0, 0.07)], "Glow", axis="Z", center=(-0.037, 0.012, 0), segs=14)
	body.box((-0.032, 0.012, -0.01), (0.006, 0.006, 0.17), "Dark", bevel=0.001)
	# Capacitor cans on the right with ceramic tips and their cables into the body.
	for z in (-0.07, 0.01):
		body.lathe([(0.0, z - 0.035), (0.015, z - 0.035), (0.015, z + 0.035), (0.0, z + 0.035)], "Steel", axis="Z", center=(0.037, -0.005, 0), segs=20)
		for zz in (z - 0.02, z + 0.02):
			body.lathe([(0.0148, zz - 0.002), (0.0158, zz - 0.002), (0.0158, zz + 0.002), (0.0148, zz + 0.002)], "Dark", axis="Z",
				center=(0.037, -0.005, 0), segs=20)
		disc_z(body, 0.037, -0.005, z - 0.036, 0.009, 0.004, "Ceramic", 16)
		body.strut((0.037, -0.005, z + 0.036), (0.031, -0.015, z + 0.05), 0.0025, "Grip", sides=6)
	# The grips and the owner's stripe.
	with body.at((0, -0.085, 0.13), (-15, 0, 0)):
		body.profile([(-0.024, 0.05), (0.024, 0.05), (0.026, -0.05), (-0.014, -0.05), (-0.022, -0.03), (-0.019, -0.01), (-0.024, 0.01),
			(-0.021, 0.03)], -0.018, 0.018, "Grip", bevel=0.003, segments=3)
	body.box((0, -0.072, -0.1), (0.032, 0.07, 0.035), "Grip", bevel=0.004)
	guard(body, 0.065, 0.11, -0.04, 0.02, 0.008)
	trigger(body, 0, -0.048, 0.09)
	body.box((0.0302, -0.03, 0.12), (0.002, 0.012, 0.12), "Accent", bevel=0.0004)
	# The holographic sight: a round housing on a base, an adjuster on its right (glass and its
	# ring are the game's, at (0, 0.074, 0)).
	body.box((0, 0.049, 0.0), (0.05, 0.008, 0.044), "Dark", bevel=0.0015)
	body.box((0, 0.0535, 0.0), (0.018, 0.006, 0.03), "Dark", bevel=0.0012)
	body.lathe([(0.0215, -0.017), (0.0265, -0.017), (0.0275, -0.012), (0.0275, 0.016), (0.0215, 0.016)], "Dark", axis="Z",
		center=(0, 0.074, 0), segs=40)
	body.lathe([(0.0262, -0.03), (0.0272, -0.03), (0.0272, -0.017), (0.0262, -0.017)], "Dark", axis="Z", center=(0, 0.074, 0), segs=40)
	body.cyl((0.03, 0.074, 0.0), 0.0055, 0.008, "Steel", rot=(0, 0, 90), sides=14, bevel=0.001)
	body.cyl((0, 0.1035, 0.0), 0.0045, 0.006, "Steel", sides=14, bevel=0.001)
	body_o = body.build()

	vent = lib.Part("Vent")
	v0 = (0.031, 0.025, 0.12)
	with vent.at(v0):
		vent.box((0.002, -0.015, 0), (0.004, 0.03, 0.08), "Steel", bevel=0.001)
		for k in range(5):
			vent.box((0.0045, -0.015, -0.03 + k * 0.015), (0.002, 0.024, 0.004), "Dark", bevel=0.0005)
	vent_o = vent.build(origin=v0)
	finish("photon", [body_o, vent_o], 2048, (0, 0.0, -0.13), 1.0, [(-90, 5), (-35, 20), (140, 25), (90, 0)])


# --- Marksman rifle ------------------------------------------------------------------------------

def marksman():
	bore = 0.006
	body = lib.Part("Body")
	rc = lib.Part("Receiver")
	rc.profile([(-0.025, -0.033), (0.025, -0.033), (0.025, 0.025), (0.019, 0.033), (-0.019, 0.033), (-0.025, 0.025)], -0.09, 0.13, "Gun",
		bevel=0.0015, plane="XY")
	rco = rc.build()
	cut = lib.Part("RCut")
	cut.box((0.026, 0.012, 0.06), (0.006, 0.008, 0.1), "Gun", bevel=0.0)
	cut.box((0.026, 0.02, -0.03), (0.006, 0.014, 0.04), "Gun", bevel=0.0)
	lib.boolean(rco, cut.build())
	body.merge_object(rco)
	body.box((0.021, 0.012, 0.06), (0.004, 0.008, 0.1), "Black", bevel=0)
	body.box((0.021, 0.02, -0.03), (0.004, 0.014, 0.04), "Black", bevel=0)
	body.box((0, 0.034, 0.035), (0.016, 0.004, 0.11), "Dark", bevel=0.0008)
	for z in (0.0, 0.03, 0.06):
		body.box((0, 0.0365, z), (0.018, 0.002, 0.005), "Dark", bevel=0.0004)
	# The wooden handguard with its vents, the steel ring at its front.
	body.profile([(-0.028, -0.027), (0.028, -0.027), (0.028, 0.015), (0.02, 0.023), (-0.02, 0.023), (-0.028, 0.015)], -0.31, -0.09, "Wood",
		bevel=0.003, plane="XY")
	for k in range(4):
		for s in (-1, 1):
			body.box((s * 0.0285, 0.0, -0.13 - k * 0.04), (0.0015, 0.008, 0.024), "Black", bevel=0.0004)
	body.box((0, -0.002, -0.305), (0.058, 0.052, 0.012), "Steel", bevel=0.0015)
	# The barrel, a little tapered, the gas block, the ported brake and its bore.
	body.lathe([(0.0, -0.31), (0.0105, -0.31), (0.0095, -0.63), (0.0, -0.63)], "Gun", axis="Z", center=(0, bore, 0), segs=20)
	body.box((0, 0.019, -0.34), (0.02, 0.022, 0.02), "Dark", bevel=0.0015)
	br = lib.Part("Brake")
	br.lathe([(0.0, -0.63), (0.016, -0.63), (0.016, -0.666), (0.013, -0.67), (0.0055, -0.67), (0.0055, -0.66), (0.0, -0.66)], "Dark", axis="Z",
		center=(0, bore, 0), segs=24)
	bro = br.build()
	cut = lib.Part("BrakeCut")
	for z in (-0.642, -0.654):
		cut.box((0, bore, z), (0.05, 0.007, 0.007), "Dark", bevel=0.0)
	lib.boolean(bro, cut.build())
	body.merge_object(bro)
	body.cyl((0, bore, -0.6698), 0.0055, 0.001, "Black", rot=(90, 0, 0), sides=14, bevel=0)
	# The grip, the guard and trigger, the owner's stripe.
	with body.at((0, -0.08, 0.1), (-15, 0, 0)):
		body.profile([(-0.024, 0.05), (0.024, 0.05), (0.026, -0.05), (-0.014, -0.05), (-0.022, -0.03), (-0.019, -0.01), (-0.024, 0.01),
			(-0.021, 0.03)], -0.018, 0.018, "Wood", bevel=0.003, segments=3)
	guard(body, 0.02, 0.07, -0.033, 0.022, 0.008)
	trigger(body, 0, -0.04, 0.045)
	body.box((-0.0257, -0.005, 0.03), (0.002, 0.012, 0.12), "Accent", bevel=0.0004)
	for z in (-0.06, 0.1):
		for s in (-1, 1):
			screw(body, (s * 0.025, -0.02, z), s, 0.0024)
	body.torus((0, -0.03, -0.27), 0.007, 0.0016, "Steel", rot=(0, 0, 90), maj_seg=14, min_seg=6)
	body_o = body.build()

	bolt = lib.Part("Bolt")
	b0 = (0.0265, 0.012, 0.02)
	with bolt.at(b0):
		bolt.box((0.006, 0, 0), (0.012, 0.01, 0.012), "Steel", bevel=0.0015)
		bolt.sphere((0.013, 0, 0), 0.007, "Steel", segs=14, rings=8)
	bolt_o = bolt.build(origin=b0)

	mag = lib.Part("Mag")
	m0 = (0, -0.04, -0.04)
	with mag.at(m0):
		mag.box((0, -0.04, 0), (0.03, 0.09, 0.07), "Dark", rot=(8, 0, 0), bevel=0.002)
		mag.box((0, -0.085, 0.006), (0.034, 0.008, 0.076), "Steel", rot=(8, 0, 0), bevel=0.0015)
		for k in range(3):
			mag.box((0, -0.065 + k * 0.022, 0.003 * k - 0.002), (0.0315, 0.003, 0.064), "Dark", rot=(8, 0, 0), bevel=0.0005)
	mag_o = mag.build(origin=m0)
	finish("marksman", [body_o, bolt_o, mag_o], 2048, (0, -0.0, -0.18), 1.2, [(-90, 5), (-35, 20), (140, 25), (90, 0)])


# --- Shotgun -------------------------------------------------------------------------------------

def shotgun():
	body = lib.Part("Body")
	rc = lib.Part("Receiver")
	rc.profile([(-0.14, 0.04), (0.14, 0.04), (0.14, -0.04), (0.11, -0.04), (0.095, -0.025), (-0.12, -0.025), (-0.14, -0.012)], -0.032, 0.032,
		"Dark", bevel=0.002)
	rco = rc.build()
	cut = lib.Part("Port")
	cut.box((0.034, 0.02, -0.01), (0.008, 0.026, 0.07), "Dark", bevel=0.0)
	lib.boolean(rco, cut.build())
	body.merge_object(rco)
	body.box((0.029, 0.02, -0.01), (0.004, 0.026, 0.07), "Black", bevel=0)
	body.box((0, 0.042, -0.0), (0.03, 0.004, 0.24), "Gun", bevel=0.001)
	for (y, z) in ((0.025, 0.1), (-0.01, 0.1), (0.025, -0.1)):
		screw(body, (0.032, y, z), 1, 0.0026)
		screw(body, (-0.032, y, z), -1, 0.0026)
	# The barrel and its bore, the vent rib with the front post (its bead is the game's), the magazine
	# well under the receiver.
	body.lathe([(0.0, -0.12), (0.016, -0.12), (0.016, -0.516), (0.0145, -0.52), (0.011, -0.52), (0.011, -0.51), (0.0, -0.51)], "Gun", axis="Z",
		center=(0, 0.025, 0), segs=28)
	body.cyl((0, 0.025, -0.5195), 0.011, 0.001, "Black", rot=(90, 0, 0), sides=20, bevel=0)
	body.box((0, 0.0445, -0.3), (0.008, 0.004, 0.34), "Dark", bevel=0.0008)
	for k in range(8):
		body.box((0, 0.0425, -0.15 - k * 0.042), (0.004, 0.006, 0.006), "Dark", bevel=0.0005)
	body.box((0, 0.0595, -0.468), (0.005, 0.029, 0.006), "Dark", bevel=0.0008)
	body.box((0, -0.03, -0.05), (0.056, 0.012, 0.09), "Dark", bevel=0.0015)
	# The ghost ring on its post at the back.
	ring(body, (0, 0.074, 0.09), 0.008, 0.012, "Dark")
	body.box((0, 0.053, 0.09), (0.008, 0.026, 0.008), "Dark", bevel=0.001)
	# The pistol grip, the butt plate, guard and trigger, the owner's stripe.
	with body.at((0, -0.075, 0.1), (-15, 0, 0)):
		body.profile([(-0.024, 0.05), (0.024, 0.05), (0.026, -0.05), (-0.014, -0.05), (-0.022, -0.03), (-0.019, -0.01), (-0.024, 0.01),
			(-0.021, 0.03)], -0.018, 0.018, "Wood", bevel=0.003, segments=3)
	body.box((0, -0.002, 0.148), (0.05, 0.07, 0.016), "Grip", bevel=0.004)
	guard(body, 0.04, 0.09, -0.025, 0.022, 0.009)
	trigger(body, 0, -0.033, 0.064)
	body.box((0.0322, 0.0, 0.0), (0.002, 0.012, 0.15), "Accent", bevel=0.0004)
	body.torus((0, -0.03, 0.135), 0.007, 0.0016, "Steel", rot=(0, 0, 90), maj_seg=14, min_seg=6)
	body_o = body.build()

	pump = lib.Part("Pump")
	pump.lathe([(0.0175, -0.345), (0.026, -0.345), (0.028, -0.34), (0.028, -0.2), (0.026, -0.195), (0.0175, -0.195)], "Grip", axis="Z",
		center=(0, -0.003, 0), segs=28)
	for i in range(3):
		z = -0.32 + i * 0.05
		pump.lathe([(0.0275, z - 0.003), (0.0285, z - 0.003), (0.0285, z + 0.003), (0.0275, z + 0.003)], "Black", axis="Z",
			center=(0, -0.003, 0), segs=28)
	for x in (-0.012, 0.012):
		pump.box((x, -0.02, -0.165), (0.004, 0.005, 0.07), "Steel", bevel=0.0008)
	pump_o = pump.build()

	mag = lib.Part("Mag")
	m0 = (0, -0.04, -0.05)
	with mag.at(m0):
		mag.box((0, -0.05, 0), (0.05, 0.1, 0.085), "Dark", bevel=0.002)
		mag.box((0, -0.102, 0), (0.054, 0.008, 0.089), "Steel", bevel=0.0015)
		for k in range(3):
			mag.box((0, -0.075 + k * 0.025, 0.0), (0.0515, 0.004, 0.08), "Dark", bevel=0.0005)
		mag.lathe([(0.0, -0.035), (0.009, -0.035), (0.009, 0.02), (0.0, 0.02)], "Red", axis="Z", center=(0, 0.005, 0), segs=16)
		mag.lathe([(0.0, 0.02), (0.0095, 0.02), (0.0095, 0.025), (0.0, 0.025)], "Brass", axis="Z", center=(0, 0.005, 0), segs=16)
	mag_o = mag.build(origin=m0)
	finish("shotgun", [body_o, pump_o, mag_o], 2048, (0, -0.0, -0.15), 1.0, [(-90, 5), (-35, 20), (140, 25), (90, 0)])


# --- Multiple grenade launcher --------------------------------------------------------------------

MGL_BORE = 0.03
MGL_AXIS = MGL_BORE - 0.046
MGL_CRANE = (-0.02, MGL_AXIS - 0.05, -0.015)
MGL_CYL = (0.0, MGL_AXIS, -0.015)


def mgl():
	bore = MGL_BORE
	body = lib.Part("Body")
	# The frame: the strap over the cylinder, the front and rear plates (rounded), the rail under it,
	# the trigger housing.
	body.box((0, 0.062, -0.015), (0.05, 0.014, 0.17), "Dark", bevel=0.002)
	for (z, t) in ((-0.09, 0.016), (0.063, 0.018)):
		pl = [(-0.035, 0.062), (0.035, 0.062), (0.035, -0.07), (0.025, -0.085), (-0.025, -0.085), (-0.035, -0.07)]
		body.profile(pl, z - t * 0.5, z + t * 0.5, "Olive", bevel=0.0025, plane="XY")
		for (x, y) in ((-0.026, 0.05), (0.026, 0.05), (-0.026, -0.07), (0.026, -0.07)):
			body.cyl((x, y, z + (-t * 0.5 - 0.001 if z < 0 else t * 0.5 + 0.001)), 0.0035, 0.002, "Steel", rot=(90, 0, 0), sides=6, bevel=0)
	body.box((0, -0.092, -0.015), (0.03, 0.01, 0.17), "Dark", bevel=0.0015)
	body.box((0, -0.1, 0.07), (0.036, 0.03, 0.07), "Dark", bevel=0.002)
	body.box((-0.0352, -0.03, 0.063), (0.002, 0.05, 0.012), "Accent", bevel=0.0004)
	# The crane's hinge pin, low on the left.
	body.cyl((MGL_CRANE[0], MGL_CRANE[1], MGL_CRANE[2]), 0.005, 0.15, "Steel", rot=(90, 0, 0), sides=12)
	# The barrel: a thick tube with its rings, open at the muzzle, the foregrip under it.
	tube_z(body, 0, bore, -0.265, -0.095, 0.026, 0.0205, "Gun", 32)
	body.lathe([(0.0, -0.2), (0.0205, -0.2), (0.0205, -0.198), (0.0, -0.198)], "Black", axis="Z", center=(0, bore, 0), segs=24)
	for z in (-0.13, -0.2, -0.255):
		body.lathe([(0.0255, z - 0.005), (0.0285, z - 0.005), (0.0285, z + 0.005), (0.0255, z + 0.005)], "Dark", axis="Z", center=(0, bore, 0), segs=32)
	body.box((0, -0.035, -0.19), (0.03, 0.075, 0.035), "Grip", bevel=0.004)
	body.box((0, 0.0, -0.19), (0.022, 0.012, 0.03), "Dark", bevel=0.0015)
	for k in range(4):
		body.box((0, -0.06 + k * 0.016, -0.172), (0.031, 0.004, 0.002), "Black", bevel=0)
	# The pistol grip, guard and trigger.
	with body.at((0, -0.16, 0.1), (-15, 0, 0)):
		body.profile([(-0.025, 0.05), (0.025, 0.05), (0.027, -0.05), (-0.015, -0.05), (-0.023, -0.03), (-0.02, -0.01), (-0.025, 0.01),
			(-0.022, 0.03)], -0.018, 0.018, "Grip", bevel=0.003, segments=3)
	guard(body, 0.02, 0.07, -0.115, 0.024, 0.008)
	trigger(body, 0, -0.122, 0.048)
	# The ring sight with its cross wires on a post, the post the bead sits on at the back.
	ring(body, (0, 0.125, -0.1), 0.018, 0.0215, "Dark", 40)
	body.box((0, 0.125, -0.1), (0.036, 0.0012, 0.0012), "Dark", bevel=0)
	body.box((0, 0.125, -0.1), (0.0012, 0.036, 0.0012), "Dark", bevel=0)
	body.box((0, 0.0865, -0.1), (0.006, 0.035, 0.006), "Dark", bevel=0.001)
	body.box((0, 0.0955, 0.06), (0.006, 0.053, 0.006), "Dark", bevel=0.001)
	body.torus((0, -0.098, 0.1), 0.007, 0.0016, "Steel", rot=(0, 0, 90), maj_seg=14, min_seg=6)
	body_o = body.build()

	crane = lib.Part("Crane")
	cx, cy, cz = MGL_CRANE
	for z in (cz - 0.07, cz + 0.06):
		crane.strut((cx, cy, z), (MGL_CYL[0], MGL_CYL[1], z), 0.006, "Gun", sides=8)
		crane.cyl((cx, cy, z), 0.008, 0.008, "Gun", rot=(90, 0, 0), sides=12)
	crane_o = crane.build(origin=MGL_CRANE)

	cyl = lib.Part("CylBody")
	c = MGL_CYL
	cyl.lathe([(0.0, -0.064), (0.067, -0.064), (0.0705, -0.06), (0.0705, 0.06), (0.067, 0.064), (0.0, 0.064)], "Olive", axis="Z",
		center=(c[0], c[1], c[2]), segs=48)
	cyo = cyl.build()
	cut = lib.Part("Flutes")
	for k in range(6):
		f = math.pi * 0.5 + k * math.tau / 6.0 + math.tau / 12.0
		cut.cyl((c[0] + math.cos(f) * 0.078, c[1] + math.sin(f) * 0.078, c[2]), 0.012, 0.11, "Olive", rot=(90, 0, 0), sides=16, bevel=0)
	lib.boolean(cyo, cut.build())
	cylinder = lib.Part("Cylinder")
	cylinder.merge_object(cyo)
	disc_z(cylinder, c[0], c[1], c[2] - 0.066, 0.012, 0.006, "Steel", 20)
	for k in range(6):
		a = math.pi * 0.5 + k * math.tau / 6.0
		px, py = c[0] + math.cos(a) * 0.046, c[1] + math.sin(a) * 0.046
		disc_z(cylinder, px, py, c[2] - 0.0642, 0.0195, 0.0012, "Black", 20)
		ring(cylinder, (px, py, c[2] - 0.064), 0.0195, 0.0225, "Dark", 20)
	cyl_o = cylinder.build(origin=MGL_CYL)

	rounds = lib.Part("Rounds")
	for k in range(6):
		a = math.pi * 0.5 + k * math.tau / 6.0
		px, py = c[0] + math.cos(a) * 0.046, c[1] + math.sin(a) * 0.046
		disc_z(rounds, px, py, c[2] + 0.0645, 0.0185, 0.0012, "Steel", 20)
		disc_z(rounds, px, py, c[2] + 0.0652, 0.004, 0.0006, "Brass", 12)
	rounds_o = rounds.build(origin=MGL_CYL)

	# A round's nose, as it shows in its chamber's mouth (the game puts six of them there): olive
	# drab with a brass ring, its fuse cap domed forward.
	nose = lib.Part("Nose")
	nose.lathe([(0.0, 0.0008), (0.0172, 0.0008), (0.0172, -0.0004), (0.012, -0.0018), (0.005, -0.0026), (0.0, -0.0028)], "Nose", axis="Z", segs=24)
	nose.torus((0, 0, -0.0002), 0.015, 0.0013, "Brass", rot=(90, 0, 0), maj_seg=24, min_seg=6)
	nose_o = nose.build()
	finish("mgl", [body_o, crane_o, cyl_o, rounds_o, nose_o], 2048, (0, -0.02, -0.06), 0.85, [(-90, 5), (-35, 20), (140, 25), (90, 0)])


# --- Storm lance ---------------------------------------------------------------------------------

def lightning():
	body = lib.Part("Body")
	body.profile([(-0.0425, -0.0475), (0.0425, -0.0475), (0.0425, 0.04), (0.035, 0.0475), (-0.035, 0.0475), (-0.0425, 0.04)], -0.15, 0.19, "Olive",
		bevel=0.003, plane="XY")
	for z in (-0.12, 0.16):
		for s in (-1, 1):
			screw(body, (s * 0.0425, 0.03, z), s, 0.0028)
			screw(body, (s * 0.0425, -0.03, z), s, 0.0028)
	# Four capacitor cans along the sides, banded, with ceramic tips; cables from them to the rod.
	for x in (-0.052, 0.052):
		for z in (-0.06, 0.06):
			body.lathe([(0.0, z - 0.04), (0.02, z - 0.04), (0.02, z + 0.04), (0.0, z + 0.04)], "Steel", axis="Z", center=(x, 0.005, 0), segs=24)
			for zz in (z - 0.025, z + 0.025):
				body.lathe([(0.0198, zz - 0.0025), (0.0212, zz - 0.0025), (0.0212, zz + 0.0025), (0.0198, zz + 0.0025)], "Dark", axis="Z",
					center=(x, 0.005, 0), segs=24)
			disc_z(body, x, 0.005, z - 0.041, 0.012, 0.004, "Ceramic", 16)
		body.strut((x, 0.005, -0.101), (x * 0.4, 0.004, -0.17), 0.003, "Grip", sides=6)
	# The copper rod wound with its coils (they glow with the charge), the ceramic insulator stack.
	body.lathe([(0.0, -0.38), (0.012, -0.38), (0.012, -0.16), (0.0, -0.16)], "Copper", axis="Z", segs=20)
	for z in (-0.2, -0.245, -0.29, -0.335):
		body.torus((0, 0, z), 0.018, 0.004, "Glow", rot=(90, 0, 0), maj_seg=28, min_seg=8)
		for k in range(8):
			a = k * math.tau / 8
			body.box((math.cos(a) * 0.0135, math.sin(a) * 0.0135, z), (0.002, 0.002, 0.012), "Copper", rot=(0, 0, math.degrees(a)), bevel=0)
	for i in range(3):
		z = -0.158 - i * 0.008
		disc_z(body, 0, 0, z, 0.03 - i * 0.003, 0.006, "Ceramic", 28)
	# The prongs the bolt leaps from, their glowing tips; the bracket holding them.
	body.box((0, 0, -0.36), (0.07, 0.016, 0.016), "Dark", bevel=0.002)
	for x in (-0.03, 0.03):
		body.strut((x, 0, -0.355), (x * 0.95, 0, -0.44), 0.006, "Dark", sides=8)
		body.box((x, 0, -0.38), (0.012, 0.02, 0.03), "Dark", bevel=0.002)
		body.sphere((x * 0.87, 0, -0.448), 0.009, "Glow", segs=16, rings=10)
	# The grips and the owner's stripe.
	with body.at((0, -0.085, 0.1), (-15, 0, 0)):
		body.profile([(-0.024, 0.05), (0.024, 0.05), (0.026, -0.05), (-0.014, -0.05), (-0.022, -0.03), (-0.019, -0.01), (-0.024, 0.01),
			(-0.021, 0.03)], -0.018, 0.018, "Grip", bevel=0.003, segments=3)
	body.box((0, -0.07, -0.12), (0.032, 0.07, 0.035), "Grip", bevel=0.004)
	guard(body, 0.03, 0.08, -0.0475, 0.02, 0.008)
	trigger(body, 0, -0.056, 0.055)
	body.box((0.0432, -0.02, 0.12), (0.002, 0.012, 0.12), "Accent", bevel=0.0004)
	# The open ring sight at the front and the notch at the back.
	ring(body, (0, 0.1, -0.15), 0.014, 0.017, "Dark", 32)
	body.box((0, 0.066, -0.15), (0.006, 0.037, 0.006), "Dark", bevel=0.001)
	body.box((0, 0.07, 0.12), (0.024, 0.044, 0.008), "Dark", bevel=0.0015)
	for x in (-0.008, 0.008):
		body.box((x, 0.098, 0.12), (0.005, 0.012, 0.008), "Dark", bevel=0.0008)
	body_o = body.build()

	vent = lib.Part("Vent")
	v0 = (0, 0.0485, 0.02)
	with vent.at(v0):
		vent.box((0, 0.002, 0.03), (0.05, 0.004, 0.06), "Steel", bevel=0.001)
		for k in range(5):
			vent.box((0, 0.0045, 0.008 + k * 0.011), (0.04, 0.002, 0.004), "Dark", bevel=0.0005)
		vent.cyl((0, 0.0, 0.0), 0.003, 0.05, "Steel", rot=(0, 0, 90), sides=10)
	vent_o = vent.build(origin=v0)
	finish("lightning", [body_o, vent_o], 2048, (0, 0.0, -0.1), 0.95, [(-90, 5), (-35, 20), (140, 25), (90, 0)])


BUILDERS = {"pistol": pistol, "dual": dual, "revolver": revolver, "smg": smg, "photon": photon, "marksman": marksman, "shotgun": shotgun,
	"mgl": mgl, "lightning": lightning}

args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
which = [a for a in args if a in BUILDERS] or ALL
if len(which) != 1:
	# One weapon per Blender run (each build starts from an empty scene); run the rest one by one.
	import subprocess
	for name in which:
		subprocess.run([sys.argv[0], "-b", "-P", os.path.abspath(__file__), "--", name], check=True)
else:
	lib.reset()
	kinds()
	BUILDERS[which[0]]()
