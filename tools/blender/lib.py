"""Shared helpers for the asset scripts: build parts in Godot's coordinates, give them procedural
materials ("kinds"), bake those into one texture atlas per asset and export a .gltf for Godot.

Coordinates: every helper takes Godot ship/model-local coordinates (+Y up, -Z forward, metres) and
converts them with G(), so the numbers can be copied straight from the GDScript. The glTF exporter
(+Y up) turns them back into exactly those Godot coordinates.

Run an asset script with Blender 4.2:  blender -b -P tools/blender/<asset>.py
"""

import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Euler, Matrix, Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "models")
PREVIEW = os.path.join(ROOT, "tools", "blender", "previews")


# --- Scene ---------------------------------------------------------------------------------------

def reset():
	bpy.ops.wm.read_factory_settings(use_empty=True)
	scene = bpy.context.scene
	scene.render.engine = "CYCLES"
	try:
		prefs = bpy.context.preferences.addons["cycles"].preferences
		for kind in ("OPTIX", "CUDA"):
			try:
				prefs.compute_device_type = kind
				prefs.get_devices()
				if any(d.type == kind for d in prefs.devices):
					break
			except TypeError:
				continue
		for d in prefs.devices:
			d.use = d.type != "CPU"
		scene.cycles.device = "GPU"
	except Exception as e:  # CPU is fine, only slower.
		print("[lib] GPU setup failed:", e)
	scene.cycles.samples = 16
	scene.render.bake.margin = 6
	scene.unit_settings.system = "METRIC"
	ensure_world()


def G(x, y, z):
	"""A Godot point (x, y, z) in Blender's frame."""
	return Vector((x, -z, y))


def GR(rx, ry, rz):
	"""A Godot rotation in degrees, as Models.euler() makes it (Basis.from_euler, order YXZ), as a
	Blender matrix."""
	# Godot's Basis.from_euler(v) default order is EULER_ORDER_YXZ: R = Ry * Rx * Rz.
	rx, ry, rz = math.radians(rx), math.radians(ry), math.radians(rz)
	gm = _gy(ry) @ _gx(rx) @ _gz(rz)
	return _to_blender(gm)


def _gx(a):
	return Matrix(((1, 0, 0), (0, math.cos(a), -math.sin(a)), (0, math.sin(a), math.cos(a))))


def _gy(a):
	return Matrix(((math.cos(a), 0, math.sin(a)), (0, 1, 0), (-math.sin(a), 0, math.cos(a))))


def _gz(a):
	return Matrix(((math.cos(a), -math.sin(a), 0), (math.sin(a), math.cos(a), 0), (0, 0, 1)))


# Godot -> Blender change of basis: b = C g, with C mapping (x, y, z) to (x, -z, y).
_C = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))


def _to_blender(gm):
	return _C @ gm @ _C.transposed()


def godot_basis(x_axis, y_axis, z_axis):
	"""A Godot basis from its three axis vectors (Godot coordinates) as a Blender matrix."""
	gm = Matrix(((x_axis[0], y_axis[0], z_axis[0]), (x_axis[1], y_axis[1], z_axis[1]), (x_axis[2], y_axis[2], z_axis[2])))
	return _to_blender(gm)


# --- Materials: procedural kinds -----------------------------------------------------------------

## Emission is baked divided by this (8-bit textures stop at 1) and the exported material's
## emission strength puts it back, so lamps can glow brighter than white.
EMIT_SCALE = 6.0

KINDS = {}


def kind(name, base, metal=0.3, rough=0.6, wear=0.0, grime=0.0, plates=0.0, scratch=0.0, emit=None,
		bare=(0.55, 0.55, 0.53), noise=0.06, seam=0.004, grime_color=(0.3, 0.27, 0.22), stripes=None,
		export_as=None, cull=True, edge=0.03, streaks=0.0, seam_dark=0.55):
	"""Define a material kind.
	- base, metal, rough: the paint or surface.
	- wear: how much paint is chipped off the edges (showing `bare` metal); grime: dirt in creases
	  and low spots; streaks: dirt run down the sides in vertical streaks; plates: size of the panel plating pattern in metres (0: none) with seams `seam`
	  wide; scratch: fine scratches; noise: blotchy tone variation.
	- emit: (r, g, b, strength) for a lit surface (windows, lamps).
	- stripes: (r, g, b, period) yellow-black style hazard stripes across the surface.
	- export_as: the material name in the .gltf (several kinds may share one, e.g. "Paint" for parts
	  the game tints); defaults to the kind's own name.
	"""
	# Colours are given like the game's (sRGB, as in Color(...) in GDScript); the bake works in linear.
	if emit:
		emit = (*lin(emit[:3]), emit[3])
	KINDS[name] = dict(name=name, base=lin(base), metal=metal, rough=rough, wear=wear, grime=grime, plates=plates,
		scratch=scratch, emit=emit, bare=lin(bare), noise=noise, seam=seam, grime_color=lin(grime_color), stripes=stripes,
		export_as=export_as or name, cull=cull, edge=edge, streaks=streaks, seam_dark=seam_dark)


def lin(c):
	return tuple(((v + 0.055) / 1.055) ** 2.4 if v > 0.04045 else v / 12.92 for v in c[:3])


def _node(tree, type_name, loc=(0, 0), **props):
	n = tree.nodes.new(type_name)
	n.location = loc
	for k, v in props.items():
		setattr(n, k, v)
	return n


def _math(tree, op, a, b=None, loc=(0, 0), clamp=False):
	n = _node(tree, "ShaderNodeMath", loc, operation=op, use_clamp=clamp)
	_feed(tree, n.inputs[0], a)
	if b is not None:
		_feed(tree, n.inputs[1], b)
	return n.outputs[0]


def _feed(tree, sock, v):
	if isinstance(v, (int, float)):
		sock.default_value = v
	elif isinstance(v, tuple):
		sock.default_value = v
	else:
		tree.links.new(v, sock)


def _mix_color(tree, fac, a, b, loc=(0, 0)):
	n = _node(tree, "ShaderNodeMix", loc, data_type="RGBA", blend_type="MIX")
	_feed(tree, n.inputs["Factor"], fac)
	_feed(tree, n.inputs[6], a)
	_feed(tree, n.inputs[7], b)
	return n.outputs[2]


def _mix_float(tree, fac, a, b, loc=(0, 0)):
	n = _node(tree, "ShaderNodeMix", loc, data_type="FLOAT")
	_feed(tree, n.inputs["Factor"], fac)
	_feed(tree, n.inputs[2], a)
	_feed(tree, n.inputs[3], b)
	return n.outputs[0]


def _rgba(c):
	return (c[0], c[1], c[2], 1.0)


def make_material(k):
	"""A Blender material for a kind: procedural nodes that Cycles evaluates while baking. The
	channels come out on emission shaders the bake switches between (see bake())."""
	m = bpy.data.materials.new("K_" + k["name"])
	m.use_nodes = True
	m.use_backface_culling = k["cull"]
	t = m.node_tree
	t.nodes.clear()
	tc = _node(t, "ShaderNodeTexCoord", (-1600, 0))
	geo = _node(t, "ShaderNodeNewGeometry", (-1600, -300))
	obj = tc.outputs["Object"]

	# Blotchy tone variation over the surface.
	n1 = _node(t, "ShaderNodeTexNoise", (-1300, 300))
	n1.inputs["Scale"].default_value = 1.6
	n1.inputs["Detail"].default_value = 6.0
	t.links.new(obj, n1.inputs["Vector"])
	tone = _math(t, "MULTIPLY_ADD", n1.outputs["Fac"], k["noise"] * 2.0, loc=(-1100, 300))
	tone_in = tone.node.inputs[2]
	tone_in.default_value = 1.0 - k["noise"]
	base = _node(t, "ShaderNodeMix", (-900, 300), data_type="RGBA", blend_type="MULTIPLY")
	base.inputs["Factor"].default_value = 1.0
	base.inputs[6].default_value = _rgba(k["base"])
	t.links.new(tone, base.inputs[7])
	color = base.outputs[2]

	height = None
	# Panel plating: staggered plates on whichever axis plane the surface faces, a seam between
	# them, and each plate a slightly different shade.
	if k["plates"] > 0.0:
		sep = _node(t, "ShaderNodeSeparateXYZ", (-1400, -600))
		t.links.new(obj, sep.inputs[0])
		nsep = _node(t, "ShaderNodeSeparateXYZ", (-1400, -800))
		t.links.new(geo.outputs["Normal"], nsep.inputs[0])
		# Dominant axis masks from the true normal.
		ax = [_math(t, "ABSOLUTE", nsep.outputs[i], loc=(-1250, -800 - i * 60)) for i in range(3)]
		mx = _math(t, "GREATER_THAN", ax[0], _math(t, "MAXIMUM", ax[1], ax[2], loc=(-1100, -760)), loc=(-950, -760))
		my = _math(t, "MULTIPLY", _math(t, "SUBTRACT", 1.0, mx, loc=(-950, -820)),
			_math(t, "GREATER_THAN", ax[1], ax[2], loc=(-1100, -880)), loc=(-800, -840))
		mz = _math(t, "SUBTRACT", _math(t, "SUBTRACT", 1.0, mx, loc=(-800, -900)), my, loc=(-650, -900))
		bricks = []
		for i, (u, v) in enumerate(((1, 2), (0, 2), (0, 1))):
			comb = _node(t, "ShaderNodeCombineXYZ", (-1200, -500 - i * 200))
			t.links.new(sep.outputs[u], comb.inputs[0])
			t.links.new(sep.outputs[v], comb.inputs[1])
			br = _node(t, "ShaderNodeTexBrick", (-1000, -450 - i * 220))
			# Plates of uneven widths: every third row squashed, rows offset unevenly.
			br.offset = 0.5
			br.offset_frequency = 2
			br.squash = 0.65
			br.squash_frequency = 3
			br.inputs["Scale"].default_value = 1.0 / k["plates"]
			br.inputs["Mortar Size"].default_value = k["seam"] / k["plates"]
			br.inputs["Mortar Smooth"].default_value = 0.3
			br.inputs["Brick Width"].default_value = 2.0
			br.inputs["Row Height"].default_value = 0.75
			br.inputs["Bias"].default_value = 0.0
			br.inputs["Color1"].default_value = (1.0, 1.0, 1.0, 1)
			br.inputs["Color2"].default_value = (0.82, 0.82, 0.82, 1)
			t.links.new(comb.outputs[0], br.inputs["Vector"])
			bricks.append(br)
		masks = [mx, my, mz]
		fac = None
		shade = None
		for br, mk in zip(bricks, masks):
			f = _math(t, "MULTIPLY", br.outputs["Fac"], mk, loc=(-700, -500))
			c = _node(t, "ShaderNodeVectorMath", (-700, -560), operation="SCALE")
			t.links.new(br.outputs["Color"], c.inputs[0])
			t.links.new(mk, c.inputs["Scale"])
			fac = f if fac is None else _math(t, "ADD", fac, f, loc=(-550, -500))
			if shade is None:
				shade = c.outputs[0]
			else:
				add = _node(t, "ShaderNodeVectorMath", (-550, -560), operation="ADD")
				t.links.new(shade, add.inputs[0])
				t.links.new(c.outputs[0], add.inputs[1])
				shade = add.outputs[0]
		mul = _node(t, "ShaderNodeMix", (-450, 200), data_type="RGBA", blend_type="MULTIPLY")
		mul.inputs["Factor"].default_value = 1.0
		t.links.new(color, mul.inputs[6])
		t.links.new(shade, mul.inputs[7])
		color = mul.outputs[2]
		# Darker seams.
		color = _mix_color(t, _math(t, "MULTIPLY", fac, k["seam_dark"], loc=(-400, 0)), color, (0.05, 0.05, 0.05, 1), loc=(-300, 200))
		height = _math(t, "SUBTRACT", 1.0, fac, loc=(-400, -400))

	if k["stripes"]:
		sr, sg, sb, period = k["stripes"]
		wave = _node(t, "ShaderNodeTexWave", (-1200, 600), wave_type="BANDS", bands_direction="DIAGONAL", wave_profile="SAW")
		wave.inputs["Scale"].default_value = 1.0 / period
		t.links.new(obj, wave.inputs["Vector"])
		band = _math(t, "GREATER_THAN", wave.outputs["Fac"], 0.5, loc=(-1000, 600))
		color = _mix_color(t, band, color, (0.03, 0.03, 0.03, 1), loc=(-250, 400))

	metal = k["metal"]
	rough = k["rough"]
	metal_s = None
	rough_s = None

	# Edge wear: paint chipped off sharp edges, where the bevel normal leans away from the face.
	if k["wear"] > 0.0:
		# Occlusion seen from inside the surface is high on convex edges and corners.
		inn = _node(t, "ShaderNodeAmbientOcclusion", (-1300, -1100), samples=16, inside=True, only_local=True)
		inn.inputs["Distance"].default_value = k.get("edge", 0.03)
		edge = _math(t, "SUBTRACT", 1.0, inn.outputs["AO"], loc=(-950, -1100))
		edge = _math(t, "MULTIPLY", edge, 2.2, loc=(-800, -1100), clamp=True)
		# ...but parts sunk into each other look the same to it, so it also has to be where the
		# surface really bends: the bevel node's rounded normal leans away from the facet's own.
		bev = _node(t, "ShaderNodeBevel", (-1300, -950), samples=8)
		bev.inputs["Radius"].default_value = k.get("edge", 0.03)
		dot = _node(t, "ShaderNodeVectorMath", (-1100, -950), operation="DOT_PRODUCT")
		t.links.new(bev.outputs[0], dot.inputs[0])
		t.links.new(geo.outputs["True Normal"], dot.inputs[1])
		lean = _node(t, "ShaderNodeMapRange", (-950, -950))
		lean.inputs["From Min"].default_value = 0.988
		lean.inputs["From Max"].default_value = 0.95
		t.links.new(dot.outputs["Value"], lean.inputs["Value"])
		edge = _math(t, "MULTIPLY", edge, lean.outputs[0], loc=(-700, -1000))
		wn = _node(t, "ShaderNodeTexNoise", (-1100, -1300))
		wn.inputs["Scale"].default_value = 9.0
		wn.inputs["Detail"].default_value = 8.0
		wn.inputs["Roughness"].default_value = 0.7
		t.links.new(obj, wn.inputs["Vector"])
		chip = _math(t, "MULTIPLY", edge, _math(t, "POWER", wn.outputs["Fac"], 1.5, loc=(-900, -1300)), loc=(-650, -1150))
		chip = _math(t, "MULTIPLY", chip, k["wear"] * 2.0, loc=(-500, -1150))
		wear = _node(t, "ShaderNodeMapRange", (-350, -1150))
		wear.inputs["From Min"].default_value = 0.45
		wear.inputs["From Max"].default_value = 0.6
		t.links.new(chip, wear.inputs["Value"])
		wmask = wear.outputs[0]
		color = _mix_color(t, wmask, color, _rgba(k["bare"]), loc=(-150, 200))
		metal_s = _mix_float(t, wmask, metal, 1.0, loc=(-150, -100))
		rough_s = _mix_float(t, wmask, rough, 0.32, loc=(-150, -200))
		# Chips are a hair lower than the paint.
		wh = _math(t, "MULTIPLY", wmask, -0.4, loc=(-150, -1300))
		height = wh if height is None else _math(t, "ADD", height, wh, loc=(0, -1300))

	if k["scratch"] > 0.0:
		sn = _node(t, "ShaderNodeTexNoise", (-1100, -1500))
		sn.inputs["Scale"].default_value = 3.0
		sn.inputs["Detail"].default_value = 2.0
		mp = _node(t, "ShaderNodeMapping", (-1300, -1500))
		mp.inputs["Scale"].default_value = (2.0, 60.0, 2.0)
		mp.inputs["Rotation"].default_value = (0.3, 0.5, 0.2)
		t.links.new(obj, mp.inputs["Vector"])
		t.links.new(mp.outputs[0], sn.inputs["Vector"])
		s = _node(t, "ShaderNodeMapRange", (-900, -1500))
		s.inputs["From Min"].default_value = 0.66
		s.inputs["From Max"].default_value = 0.7
		t.links.new(sn.outputs["Fac"], s.inputs["Value"])
		smask = _math(t, "MULTIPLY", s.outputs[0], k["scratch"], loc=(-700, -1500))
		color = _mix_color(t, _math(t, "MULTIPLY", smask, 0.5, loc=(-600, -1600)), color, _rgba(k["bare"]), loc=(-50, 200))
		rough_s = _mix_float(t, smask, rough_s if rough_s is not None else rough, 0.3, loc=(-50, -200))

	# Grime: dirt in creases (ambient occlusion) and blotches, more of it lower down.
	if k["grime"] > 0.0:
		ao = _node(t, "ShaderNodeAmbientOcclusion", (-1300, -1800), samples=16, only_local=False)
		ao.inputs["Distance"].default_value = 0.15
		cav = _math(t, "SUBTRACT", 1.0, ao.outputs["AO"], loc=(-1100, -1800))
		gn = _node(t, "ShaderNodeTexNoise", (-1300, -2000))
		gn.inputs["Scale"].default_value = 2.5
		gn.inputs["Detail"].default_value = 8.0
		t.links.new(obj, gn.inputs["Vector"])
		blot = _node(t, "ShaderNodeMapRange", (-1100, -2000))
		blot.inputs["From Min"].default_value = 0.5
		blot.inputs["From Max"].default_value = 0.8
		t.links.new(gn.outputs["Fac"], blot.inputs["Value"])
		g = _math(t, "ADD", _math(t, "MULTIPLY", cav, 1.6, loc=(-950, -1800)), _math(t, "MULTIPLY", blot.outputs[0], 0.35, loc=(-950, -2000)), loc=(-800, -1900))
		g = _math(t, "MULTIPLY", g, _math(t, "ADD", gn.outputs["Fac"], 0.3, loc=(-800, -2050)), loc=(-650, -1900))
		g = _math(t, "MULTIPLY", g, k["grime"], loc=(-500, -1900), clamp=True)
		if k["streaks"] > 0.0:
			# Vertical runs: noise squashed along the up axis (Blender Z).
			mp = _node(t, "ShaderNodeMapping", (-1300, -2300))
			mp.inputs["Scale"].default_value = (9.0, 9.0, 0.45)
			t.links.new(obj, mp.inputs["Vector"])
			sn = _node(t, "ShaderNodeTexNoise", (-1100, -2300))
			sn.inputs["Scale"].default_value = 1.5
			sn.inputs["Detail"].default_value = 4.0
			t.links.new(mp.outputs[0], sn.inputs["Vector"])
			st = _node(t, "ShaderNodeMapRange", (-900, -2300))
			st.inputs["From Min"].default_value = 0.48
			st.inputs["From Max"].default_value = 0.72
			t.links.new(sn.outputs["Fac"], st.inputs["Value"])
			g = _math(t, "ADD", g, _math(t, "MULTIPLY", st.outputs[0], k["streaks"], loc=(-700, -2300)), loc=(-400, -2000), clamp=True)
		color = _mix_color(t, g, color, _rgba(k["grime_color"]), loc=(50, 200))
		rough_s = _mix_float(t, g, rough_s if rough_s is not None else rough, 0.9, loc=(50, -200))
		metal_s = _mix_float(t, g, metal_s if metal_s is not None else metal, 0.0, loc=(50, -100))

	# Outputs on fixed emission nodes: bake() links one at a time to the output.
	out = _node(t, "ShaderNodeOutputMaterial", (900, 0))
	ch = {}
	ch["color"] = _emission(t, color, (600, 300))
	ch["metal"] = _emission(t, metal_s if metal_s is not None else metal, (600, 150))
	ch["rough"] = _emission(t, rough_s if rough_s is not None else rough, (600, 0))
	if k["emit"]:
		er, eg, eb, es = k["emit"]
		e = es / EMIT_SCALE
		ch["emit"] = _emission(t, (er * e, eg * e, eb * e, 1.0), (600, -150))
	else:
		ch["emit"] = _emission(t, (0.0, 0.0, 0.0, 1.0), (600, -150))
	# Normal: a principled shader with the bump, for the normal bake.
	p = _node(t, "ShaderNodeBsdfPrincipled", (600, -400))
	if height is not None:
		bump = _node(t, "ShaderNodeBump", (350, -500))
		bump.inputs["Strength"].default_value = 1.0
		bump.inputs["Distance"].default_value = 0.004
		t.links.new(height, bump.inputs["Height"])
		t.links.new(bump.outputs[0], p.inputs["Normal"])
	ch["normal"] = p
	for key, n in ch.items():
		n.name = "CH_" + key
	t.links.new(ch["color"].outputs[0], out.inputs[0])
	m["kind"] = k["name"]
	return m


def _emission(t, value, loc):
	e = _node(t, "ShaderNodeEmission", loc)
	e.inputs["Strength"].default_value = 1.0
	if isinstance(value, (int, float)):
		e.inputs["Color"].default_value = (value, value, value, 1.0)
	elif isinstance(value, tuple):
		e.inputs["Color"].default_value = value
	else:
		t.links.new(value, e.inputs["Color"])
	return e


_mat_cache = {}


def mat(name):
	if name not in _mat_cache:
		_mat_cache[name] = make_material(KINDS[name])
	return _mat_cache[name]


# --- Mesh building -------------------------------------------------------------------------------

class Part:
	"""Geometry collected into one bmesh per material, then turned into an object. Helpers take
	Godot coordinates. Pieces can carry a bevel (width in metres) applied per piece before merging,
	so flat-shaded primitives get softly rounded edges that catch the light."""

	def __init__(self, name):
		self.name = name
		self.bm = bmesh.new()
		self.mats = []
		self._mat_index = {}
		self.frame = None

	def at(self, pos=(0, 0, 0), rot=(0, 0, 0), basis=None):
		"""Place the next pieces in a local frame (Godot position and rotation, like a Transform3D
		in the GDScript): `with part.at(...):`."""
		part = self
		m = Matrix.Translation(G(*pos)) @ (basis if basis is not None else GR(*rot)).to_4x4()

		class _Frame:
			def __enter__(self):
				self.prev = part.frame
				part.frame = m if self.prev is None else self.prev @ m

			def __exit__(self, *a):
				part.frame = self.prev
		return _Frame()

	def _mi(self, kind_name):
		if kind_name not in self._mat_index:
			self._mat_index[kind_name] = len(self.mats)
			self.mats.append(kind_name)
		return self._mat_index[kind_name]

	def add_bmesh(self, piece, kind_name, matrix=None, bevel=0.0, segments=2, smooth=False, angle=35.0):
		"""Merge a bmesh `piece` (Blender coordinates) into this part."""
		if matrix is not None:
			piece.transform(matrix)
		if self.frame is not None:
			piece.transform(self.frame)
		if bevel > 0.0:
			edges = [e for e in piece.edges if e.calc_face_angle(0.0) > math.radians(angle)]
			if edges:
				bmesh.ops.bevel(piece, geom=edges, offset=bevel, segments=segments, profile=0.5, affect="EDGES", clamp_overlap=True)
		mi = self._mi(kind_name)
		for f in piece.faces:
			f.material_index = mi
			f.smooth = smooth
		me = bpy.data.meshes.new("tmp")
		piece.to_mesh(me)
		piece.free()
		self.bm.from_mesh(me)
		bpy.data.meshes.remove(me)
		return mi

	def box(self, pos, size, kind_name, rot=(0, 0, 0), bevel=0.01, basis=None):
		"""A box at Godot `pos`, Godot `size` (x, y, z), rotated by Godot degrees `rot` (or a Blender
		matrix `basis`)."""
		bm = bmesh.new()
		bmesh.ops.create_cube(bm, size=1.0)
		s = Matrix.Diagonal((size[0], size[2], size[1], 1.0))
		r = (basis if basis is not None else GR(*rot)).to_4x4()
		m = Matrix.Translation(G(*pos)) @ r @ s
		self.add_bmesh(bm, kind_name, m, bevel=min(bevel, min(size) * 0.45))

	def cyl(self, pos, r, h, kind_name, rot=(0, 0, 0), top=None, sides=24, bevel=0.006, basis=None, smooth=True, caps=True):
		"""A cylinder along its local Godot Y (like Godot's CylinderMesh): radius r at the bottom,
		`top` at the top."""
		bm = bmesh.new()
		top = r if top is None else top
		bmesh.ops.create_cone(bm, cap_ends=caps, cap_tris=False, segments=sides, radius1=r, radius2=top, depth=h)
		# create_cone is along Blender Z, which is Godot Y. Good.
		rm = (basis if basis is not None else GR(*rot)).to_4x4()
		m = Matrix.Translation(G(*pos)) @ rm
		self.add_bmesh(bm, kind_name, m, bevel=min(bevel, h * 0.4, r * 0.4) if bevel else 0.0, smooth=smooth)

	def strut(self, a, b, r, kind_name, sides=12, bevel=0.0):
		a = Vector(a)
		b = Vector(b)
		d = b - a
		ln = d.length
		y = d / ln
		x = y.cross(Vector((0, 0, -1)) if abs(y.dot(Vector((0, 0, -1)))) < 0.95 else Vector((1, 0, 0))).normalized()
		z = x.cross(y)
		self.cyl(tuple((a + b) * 0.5), r, ln, kind_name, basis=godot_basis(x, y, z), sides=sides, bevel=bevel)

	def sphere(self, pos, r, kind_name, scale=(1, 1, 1), segs=24, rings=12):
		bm = bmesh.new()
		bmesh.ops.create_uvsphere(bm, u_segments=segs, v_segments=rings, radius=r)
		m = Matrix.Translation(G(*pos)) @ Matrix.Diagonal((scale[0], scale[2], scale[1], 1.0))
		self.add_bmesh(bm, kind_name, m, smooth=True)

	def torus(self, pos, major, minor, kind_name, rot=(0, 0, 0), maj_seg=48, min_seg=12, scale=(1, 1, 1)):
		bm = bmesh.new()
		for i in range(maj_seg):
			a = math.tau * i / maj_seg
			for j in range(min_seg):
				b = math.tau * j / min_seg
				rr = major + minor * math.cos(b)
				bm.verts.new((rr * math.cos(a), rr * math.sin(a), minor * math.sin(b)))
		bm.verts.ensure_lookup_table()
		for i in range(maj_seg):
			for j in range(min_seg):
				i2 = (i + 1) % maj_seg
				j2 = (j + 1) % min_seg
				bm.faces.new((bm.verts[i * min_seg + j], bm.verts[i2 * min_seg + j], bm.verts[i2 * min_seg + j2], bm.verts[i * min_seg + j2]))
		bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
		m = Matrix.Translation(G(*pos)) @ GR(*rot).to_4x4() @ Matrix.Diagonal((scale[0], scale[2], scale[1], 1.0))
		self.add_bmesh(bm, kind_name, m, smooth=True)

	def profile(self, pts, x0, x1, kind_name, bevel=0.004, segments=2, matrix=None, plane="ZY"):
		"""A side-profile extrusion: polygon `pts` in the Godot (z, y) plane (or "XZ": (x, z) seen
		from above, or "XY": (x, y) seen from the front), extruded across the remaining axis from
		x0 to x1. The standard way to make gun parts and brackets."""
		bm = bmesh.new()
		vs = []
		for p in pts:
			if plane == "ZY":
				vs.append(bm.verts.new(G(x0, p[1], p[0])))
			elif plane == "XZ":
				vs.append(bm.verts.new(G(p[0], x0, p[1])))
			else:
				vs.append(bm.verts.new(G(p[0], p[1], x0)))
		f = bm.faces.new(vs)
		if plane == "ZY":
			d = G(x1 - x0, 0, 0)
		elif plane == "XZ":
			d = G(0, x1 - x0, 0)
		else:
			d = G(0, 0, x1 - x0)
		r = bmesh.ops.extrude_face_region(bm, geom=[f])
		verts = [e for e in r["geom"] if isinstance(e, bmesh.types.BMVert)]
		bmesh.ops.translate(bm, vec=d, verts=verts)
		bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
		self.add_bmesh(bm, kind_name, matrix, bevel=bevel, segments=segments)

	def loft(self, rings, kind_name, cap_start=True, cap_end=True, smooth=False, bevel=0.0, angle=35.0):
		"""Faces through rings of Godot points (each ring the same count, closed loops)."""
		bm = bmesh.new()
		vr = [[bm.verts.new(G(*p)) for p in ring] for ring in rings]
		n = len(rings[0])
		for a, b in zip(vr, vr[1:]):
			for i in range(n):
				j = (i + 1) % n
				bm.faces.new((a[i], a[j], b[j], b[i]))
		if cap_start:
			bm.faces.new(vr[0])
		if cap_end:
			bm.faces.new(list(reversed(vr[-1])))
		bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
		self.add_bmesh(bm, kind_name, bevel=bevel, smooth=smooth, angle=angle)

	def lathe(self, profile, kind_name, axis="Z", center=(0, 0, 0), segs=32, bevel=0.0, angle=35.0, matrix=None, closed=True):
		"""A turned part: the profile [(radius, along), ...] spun round a Godot axis ("X", "Y" or
		"Z") through `center` (closed: its last point joins its first). Use it for barrels, collars,
		knobs and nozzles."""
		bm = bmesh.new()
		rings = []
		for i in range(segs):
			a = math.tau * i / segs
			ring = []
			for r, h in profile:
				c, s_ = math.cos(a) * r, math.sin(a) * r
				if axis == "Z":
					p = (c, s_, h)
				elif axis == "Y":
					p = (c, h, s_)
				else:
					p = (h, c, s_)
				ring.append(bm.verts.new(G(p[0] + center[0], p[1] + center[1], p[2] + center[2])))
			rings.append(ring)
		n = len(profile)
		for i in range(segs):
			a, b = rings[i], rings[(i + 1) % segs]
			for j in range(n if closed else n - 1):
				k = (j + 1) % n
				if profile[j][0] <= 1e-6 and profile[k][0] <= 1e-6:
					continue
				vs = [a[j], b[j], b[k], a[k]]
				uniq = []
				for v in vs:
					if all((v.co - u.co).length > 1e-7 for u in uniq):
						uniq.append(v)
				if len(uniq) >= 3:
					try:
						bm.faces.new(uniq)
					except ValueError:
						pass
		bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
		bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
		self.add_bmesh(bm, kind_name, matrix, bevel=bevel, angle=angle, smooth=True)

	def merge_object(self, o):
		"""Merge another object's mesh (built with kinds, e.g. after a boolean) into this part and
		delete it."""
		me = o.data.copy()
		me.transform(o.matrix_world)
		remap = [self._mi(m.get("kind", m.name)) for m in me.materials]
		piece = bmesh.new()
		piece.from_mesh(me)
		for f in piece.faces:
			f.material_index = remap[f.material_index] if remap else 0
		tmp = bpy.data.meshes.new("tmp")
		piece.to_mesh(tmp)
		piece.free()
		self.bm.from_mesh(tmp)
		bpy.data.meshes.remove(tmp)
		bpy.data.meshes.remove(me)
		old = o.data
		bpy.data.objects.remove(o)
		bpy.data.meshes.remove(old)

	def mesh_piece(self, verts, faces, kind_name, smooth=False, bevel=0.0):
		"""Raw geometry: Godot points and faces (index lists)."""
		bm = bmesh.new()
		vs = [bm.verts.new(G(*p)) for p in verts]
		for f in faces:
			bm.faces.new([vs[i] for i in f])
		bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
		self.add_bmesh(bm, kind_name, bevel=bevel, smooth=smooth)

	def build(self, origin=(0, 0, 0), sharp=48.0):
		"""The object, its origin at Godot `origin` (its mesh moved so the geometry stays put).
		Shading: smooth, with edges sharper than `sharp` degrees kept hard, and normals weighted
		towards the big faces so bevelled boxes shade flat with soft rims."""
		me = bpy.data.meshes.new(self.name)
		lim = math.radians(sharp)
		for e in self.bm.edges:
			e.smooth = not (e.is_manifold and e.calc_face_angle(0.0) > lim) and e.is_manifold
		for f in self.bm.faces:
			f.smooth = True
		# Tangents (for the normal map) need triangles or quads.
		bmesh.ops.triangulate(self.bm, faces=[f for f in self.bm.faces if len(f.verts) > 4], quad_method="BEAUTY", ngon_method="BEAUTY")
		self.bm.to_mesh(me)
		self.bm.free()
		for k in self.mats:
			me.materials.append(mat(k))
		o = bpy.data.objects.new(self.name, me)
		bpy.context.scene.collection.objects.link(o)
		off = G(*origin)
		if off.length > 0.0:
			me.transform(Matrix.Translation(-off))
			o.location = off
		wn = o.modifiers.new("WeightedNormal", "WEIGHTED_NORMAL")
		wn.keep_sharp = True
		wn.weight = 80
		return o


def boolean(o, cutter, op="DIFFERENCE"):
	"""Cut `cutter` out of object `o` (both built Parts) and delete the cutter."""
	md = o.modifiers.new("Bool", "BOOLEAN")
	md.operation = op
	md.solver = "EXACT"
	md.object = cutter
	bpy.context.view_layer.objects.active = o
	for m in list(o.modifiers):
		if m.type == "WEIGHTED_NORMAL":
			o.modifiers.remove(m)
	o.modifiers.move(len(o.modifiers) - 1, 0)
	bpy.ops.object.modifier_apply(modifier=md.name)
	old = cutter.data
	bpy.data.objects.remove(cutter)
	bpy.data.meshes.remove(old)
	return o


def weld(o, dist=0.0002):
	bm = bmesh.new()
	bm.from_mesh(o.data)
	bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=dist)
	bm.to_mesh(o.data)
	bm.free()


# --- Baking --------------------------------------------------------------------------------------

def unwrap(objs, margin=0.003, angle=60.0):
	bpy.ops.object.select_all(action="DESELECT")
	for o in objs:
		o.select_set(True)
		if not o.data.uv_layers:
			o.data.uv_layers.new(name="UVMap")
	bpy.context.view_layer.objects.active = objs[0]
	bpy.ops.object.mode_set(mode="EDIT")
	bpy.ops.mesh.select_all(action="SELECT")
	bpy.ops.uv.smart_project(angle_limit=math.radians(angle), island_margin=margin, area_weight=0.0, scale_to_bounds=False)
	try:
		bpy.ops.uv.pack_islands(margin=margin, rotate=True, shape_method="CONCAVE")
	except TypeError:
		bpy.ops.uv.pack_islands(margin=margin, rotate=True)
	bpy.ops.object.mode_set(mode="OBJECT")


def _new_image(name, size, data=False, alpha=False):
	img = bpy.data.images.new(name, size, size, alpha=alpha, float_buffer=False)
	if data:
		img.colorspace_settings.name = "Non-Color"
	return img


def _set_bake_target(objs, img):
	for o in objs:
		for slot in o.material_slots:
			t = slot.material.node_tree
			n = t.nodes.get("BAKE_TARGET")
			if n is None:
				n = t.nodes.new("ShaderNodeTexImage")
				n.name = "BAKE_TARGET"
				n.location = (900, -500)
			n.image = img
			t.nodes.active = n
			n.select = True


def _link_channel(objs, key):
	done = set()
	for o in objs:
		for slot in o.material_slots:
			m = slot.material
			if m.name in done:
				continue
			done.add(m.name)
			t = m.node_tree
			out = next(n for n in t.nodes if n.type == "OUTPUT_MATERIAL")
			src = t.nodes["CH_" + key]
			t.links.new(src.outputs[0], out.inputs[0])


def bake(objs, size, name, hide=(), ao_distance=0.4, ao_samples=256, emissive=False):
	"""Bake the procedural kinds of `objs` into one atlas: albedo (with soft ambient occlusion
	worked in), ORM (occlusion, roughness, metallic), tangent normals and, with `emissive`, an
	emission map. Returns the images."""
	scene = bpy.context.scene
	for o in hide:
		o.hide_render = True
	bpy.ops.object.select_all(action="DESELECT")
	for o in objs:
		o.select_set(True)
	bpy.context.view_layer.objects.active = objs[0]
	imgs = {}

	def run(key, kind_type, img, samples=1, **kw):
		_set_bake_target(objs, img)
		if key:
			_link_channel(objs, key)
		scene.cycles.samples = samples
		print("[lib] baking", name, kind_type, key or "", flush=True)
		bpy.ops.object.bake(type=kind_type, margin=scene.render.bake.margin, **kw)

	col = _new_image(name + "_albedo", size)
	run("color", "EMIT", col, samples=64)
	imgs["albedo"] = col
	rough = _new_image(name + "_rough", size, data=True)
	run("rough", "EMIT", rough, samples=16)
	metal = _new_image(name + "_metal", size, data=True)
	run("metal", "EMIT", metal, samples=16)
	ao = _new_image(name + "_ao", size, data=True)
	scene.world.light_settings.distance = ao_distance
	run("normal", "AO", ao, samples=ao_samples)
	nrm = _new_image(name + "_normal", size, data=True)
	run("normal", "NORMAL", nrm, samples=16, normal_space="TANGENT")
	imgs["normal"] = nrm
	if emissive:
		em = _new_image(name + "_emission", size)
		run("emit", "EMIT", em, samples=16)
		imgs["emission"] = em
	for o in hide:
		o.hide_render = False

	# Combine: albedo darkened gently by the occlusion, ORM packed the way glTF wants it.
	px = size * size * 4
	a = np.empty(px, dtype=np.float32)
	col.pixels.foreach_get(a)
	o_ = np.empty(px, dtype=np.float32)
	ao.pixels.foreach_get(o_)
	r_ = np.empty(px, dtype=np.float32)
	rough.pixels.foreach_get(r_)
	m_ = np.empty(px, dtype=np.float32)
	metal.pixels.foreach_get(m_)
	occ = o_[0::4]
	shade = 0.35 + 0.65 * occ
	for c in range(3):
		a[c::4] *= shade
	col.pixels.foreach_set(a)
	orm = _new_image(name + "_orm", size, data=True)
	op = np.ones(px, dtype=np.float32)
	op[0::4] = occ
	op[1::4] = r_[0::4]
	op[2::4] = m_[0::4]
	orm.pixels.foreach_set(op)
	imgs["orm"] = orm
	for k, img in imgs.items():
		img.update()
		path = os.path.join(PREVIEW, "tex", img.name + ".png")
		os.makedirs(os.path.dirname(path), exist_ok=True)
		img.filepath_raw = path
		img.file_format = "PNG"
		img.save()
	return imgs


def _gltf_output_group():
	g = bpy.data.node_groups.get("glTF Material Output")
	if g is None:
		g = bpy.data.node_groups.new("glTF Material Output", "ShaderNodeTree")
		g.interface.new_socket("Occlusion", in_out="INPUT", socket_type="NodeSocketFloat")
		g.interface.new_socket("Thickness", in_out="INPUT", socket_type="NodeSocketFloat")
	return g


def finalize(objs, imgs, extra=None):
	"""Swap every material's procedural tree for a plain one reading the baked atlas (what the glTF
	exporter understands), and merge kinds that share an export name."""
	extra = extra or {}
	built = {}
	for o in objs:
		for i, slot in enumerate(o.material_slots):
			k = KINDS[slot.material.get("kind", slot.material.name)]
			name = k["export_as"]
			if name not in built:
				built[name] = _export_material(name, imgs, k, extra.get(name))
			slot.material = built[name]
	# Collapse duplicate slots.
	for o in objs:
		bpy.context.view_layer.objects.active = o
		bpy.ops.object.select_all(action="DESELECT")
		o.select_set(True)
		bpy.ops.object.material_slot_remove_unused()


def _export_material(name, imgs, k, extra):
	m = bpy.data.materials.new(name + "_x")
	m.name = name
	m.use_nodes = True
	m.use_backface_culling = k["cull"]
	t = m.node_tree
	t.nodes.clear()
	out = _node(t, "ShaderNodeOutputMaterial", (600, 0))
	p = _node(t, "ShaderNodeBsdfPrincipled", (300, 0))
	t.links.new(p.outputs[0], out.inputs[0])
	alb = _node(t, "ShaderNodeTexImage", (-400, 300), image=imgs["albedo"])
	t.links.new(alb.outputs[0], p.inputs["Base Color"])
	orm = _node(t, "ShaderNodeTexImage", (-400, 0), image=imgs["orm"])
	sep = _node(t, "ShaderNodeSeparateColor", (-150, 0))
	t.links.new(orm.outputs[0], sep.inputs[0])
	t.links.new(sep.outputs[1], p.inputs["Roughness"])
	t.links.new(sep.outputs[2], p.inputs["Metallic"])
	grp = _node(t, "ShaderNodeGroup", (300, -400))
	grp.node_tree = _gltf_output_group()
	t.links.new(sep.outputs[0], grp.inputs["Occlusion"])
	nm = _node(t, "ShaderNodeTexImage", (-400, -300), image=imgs["normal"])
	nmap = _node(t, "ShaderNodeNormalMap", (-100, -300))
	t.links.new(nm.outputs[0], nmap.inputs["Color"])
	t.links.new(nmap.outputs[0], p.inputs["Normal"])
	if k["emit"] and "emission" in imgs:
		em = _node(t, "ShaderNodeTexImage", (-400, -600), image=imgs["emission"])
		t.links.new(em.outputs[0], p.inputs["Emission Color"])
		p.inputs["Emission Strength"].default_value = EMIT_SCALE
	return m


def export(objs, path):
	os.makedirs(os.path.dirname(path), exist_ok=True)
	bpy.ops.object.select_all(action="DESELECT")
	for o in objs:
		o.select_set(True)
	# .gltf with its textures as separate PNGs next to it: Godot would otherwise extract a second
	# copy of every texture embedded in a .glb file.
	bpy.ops.export_scene.gltf(filepath=path, export_format="GLTF_SEPARATE", use_selection=True, export_apply=True,
		export_yup=True, export_tangents=True, export_image_format="AUTO", export_materials="EXPORT",
		export_cameras=False, export_lights=False)
	folder = os.path.dirname(path)
	for f in os.listdir(folder):
		if f.endswith(".png"):
			write_import(os.path.join(folder, f), normal="_normal" in f)
	print("[lib] exported", path, flush=True)


def write_import(png, normal=False, vram=True):
	"""Write Godot's import settings for a texture: VRAM-compressed with mipmaps for model and
	material textures (the editor's automatic 3D detection never sees textures that are only loaded
	from code, and left the Prospector's uncompressed and without mipmaps), lossless for decals
	(the renderer copies those into its own decal atlas). Old imports of it are dropped so Godot
	reimports it."""
	rel = os.path.relpath(png, ROOT).replace(os.sep, "/")
	lines = ["[remap]", "", 'importer="texture"', 'type="CompressedTexture2D"', "", "[deps]", "",
		'source_file="res://%s"' % rel, "", "[params]", "",
		"compress/mode=%d" % (2 if vram else 0), "compress/high_quality=false", "compress/lossy_quality=0.7",
		"compress/normal_map=%d" % (1 if normal else 0), "mipmaps/generate=%s" % ("true" if vram else "false"),
		"mipmaps/limit=-1", "process/fix_alpha_border=true", "detect_3d/compress_to=0", ""]
	with open(png + ".import", "w", newline="\n") as f:
		f.write("\n".join(lines))
	imported = os.path.join(ROOT, ".godot", "imported")
	if os.path.isdir(imported):
		base = os.path.basename(png) + "-"
		for f in os.listdir(imported):
			if f.startswith(base):
				os.remove(os.path.join(imported, f))


# --- Previews ------------------------------------------------------------------------------------

def preview(name, target, distance, views, size=(1200, 800), lens=50, extra_light=1.0):
	"""Render the finished (baked) asset from a few angles into tools/blender/previews/<name>_<i>.png.
	`views`: list of (azimuth, elevation) in degrees around Godot point `target`; azimuth 0 looks
	at the front (from -Z), 90 from the right (+X)."""
	scene = bpy.context.scene
	scene.cycles.samples = 64
	scene.cycles.use_denoising = True
	scene.render.resolution_x, scene.render.resolution_y = size
	scene.render.film_transparent = False
	w = scene.world
	w.use_nodes = True
	bg = w.node_tree.nodes.get("Background")
	bg.inputs[0].default_value = (0.05, 0.055, 0.065, 1)
	bg.inputs[1].default_value = 0.6
	tgt = G(*target)
	lights = []
	for loc, energy, color in (((4, -6, 7), 900, (1.0, 0.93, 0.85)), ((-6, -2, 2), 300, (0.7, 0.8, 1.0)), ((2, 8, 4), 500, (1.0, 1.0, 1.0))):
		ld = bpy.data.lights.new("L", "AREA")
		ld.energy = energy * extra_light * (distance / 6.0) ** 2
		ld.color = color
		ld.size = distance * 0.6
		lo = bpy.data.objects.new("L", ld)
		lo.location = tgt + Vector(loc) * (distance / 6.0)
		_aim(lo, tgt)
		scene.collection.objects.link(lo)
		lights.append(lo)
	cd = bpy.data.cameras.new("Cam")
	cd.lens = lens
	cam = bpy.data.objects.new("Cam", cd)
	scene.collection.objects.link(cam)
	scene.camera = cam
	os.makedirs(PREVIEW, exist_ok=True)
	for i, (az, el) in enumerate(views):
		a = math.radians(az)
		e = math.radians(el)
		# Godot direction from the target to the camera: front is -Z.
		d = Vector((math.sin(a) * math.cos(e), math.sin(e), -math.cos(a) * math.cos(e)))
		cam.location = tgt + G(*(d * distance))
		_aim(cam, tgt)
		scene.render.filepath = os.path.join(PREVIEW, "%s_%d.png" % (name, i))
		bpy.ops.render.render(write_still=True)
		print("[lib] preview", scene.render.filepath, flush=True)
	for lo in lights:
		bpy.data.objects.remove(lo)
	bpy.data.objects.remove(cam)


def _aim(o, target):
	d = target - o.location
	o.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()


def ensure_world():
	scene = bpy.context.scene
	if scene.world is None:
		scene.world = bpy.data.worlds.new("World")
	scene.world.use_nodes = True
