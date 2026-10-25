# Builds the Arena map (internal id "skyline") in Blender and exports
# skyline.glb beside this file.
#
#   /Applications/Blender.app/Contents/MacOS/Blender -b --python assets/models/maps/generate_skyline.py
#
# A big, open hall: 120-unit pillared walls under a solid trussed roof, one
# cyan accent colour, platform tops patterned with orange / blue / black dots
# (some joined by lines), and a poster in every lower wall bay - solid orange on
# the red (+z) half, solid blue on the blue half. Custom art dropped into
# posters/ (see posters/README.md) lands in seeded random eye-level bays.
#
# Layout is authored in Godot coordinates (x right, y up, z toward the red
# spawn) and converted on the way in, so numbers here match skyline_arena.gd.
# Pieces are joined per (prefix, material) before export. The prefix drives
# collision in Godot (skyline_arena.gd):
#   Floor_/Deck_/Block_ -> normal surface    Wall_ -> bounce surface
#   Ramp_               -> grip surface      Roof_ -> ice surface, no shadow
#   Deco_               -> visual only
import math
import os
import random

import bmesh
import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "skyline.glb")
POSTER_DIR = os.path.join(HERE, "posters")

HALF = 140.0          # inner court half-extent (280 x 280 court)
WALL_T = 4.0
WALL_H = 120.0        # walls run all the way up to the roof
CHAMFER = 20.0
# Court pieces.
TOWER_H = 18.0
TOWER_C = 100.0       # tower centre |x| and |z|
TOWER_HALF = 20.0
TOWER_RAMP_END = 20.0 # tower ramps run inward along x down to |x| = 20
RAMP_W = 18.0
BRIDGE_W = 16.0
PLATEAU_HALF = 32.0
PLATEAU_H = 7.0
PLATEAU_RAMP_RUN = 24.0
PLATEAU_RAMP_W = 22.0
SPAWN_DECK_H = 3.0
SPAWN_DECK_FRONT = 118.0
SPAWN_DECK_HALF_W = 26.0
SPIRE_HALF = 5.0
SPIRE_H = 70.0
COVERS = (((62.0, 48.0), 0.0), ((-62.0, -48.0), 0.0), ((48.0, -62.0), 90.0), ((-48.0, 62.0), 90.0))
COVER_SIZE = (32.0, 12.0, 4.0)
# Walls: a cornice ledge tops each storey; panels fill the pilaster bays.
STOREYS = ((18.0, 50.0), (56.0, 88.0), (94.0, 116.0))
PILASTER_STEP = 24.0
TRUSS_STEP = 40.0
# Posters: 2:3 portrait, one per bay in the two lower storeys.
POSTER_W, POSTER_H = 16.0, 24.0
# Custom art takes seeded random eye-level bays; an orange_/blue_ file-name
# prefix keeps a poster on that team's half of the hall.
POSTER_SEED = 11

# Platform-top pattern: a grid of dots, some cells left empty, some
# neighbours joined by a line. Seeded so every export is identical.
DOT_STEP = 5.0
DOT_FILL = 0.38
DOT_LINE_CHANCE = 0.2
DOT_RADIUS = (0.35, 0.6)
DOT_LINE_WIDTH = 0.14
DOT_COLOURS = (("dot_orange", 0.4), ("dot_blue", 0.4), ("dot_black", 0.2))
# Finishing detail that gives the big shapes a readable blob-sized scale.
FLOOR_TILE = 20.0
FLOOR_BORDER = 10.0
DADO = (4.5, 15.5)          # lower wall panel band, below the first posters
PLATFORM_GROOVE_STEP = 8.0
PATTERN_SEED = 7

CORNERS = ((1, 1), (-1, 1), (-1, -1), (1, -1))
WALLS = (("x", 1), ("z", 1), ("x", -1), ("z", -1))


def g2b(x, y, z):
	"""Godot (x, y-up, z) -> Blender (x, y, z-up)."""
	return (x, -z, y)


def srgb(hex_str):
	h = hex_str.lstrip("#")
	c = [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
	return tuple(v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4 for v in c)


def material(name, hex_color, emission=0.0, roughness=0.6, metallic=0.0):
	color = srgb(hex_color)
	mat = bpy.data.materials.new(name)
	bsdf = mat.node_tree.nodes["Principled BSDF"]
	bsdf.inputs["Base Color"].default_value = (*color, 1.0)
	bsdf.inputs["Roughness"].default_value = roughness
	bsdf.inputs["Metallic"].default_value = metallic
	if emission > 0.0:
		bsdf.inputs["Emission Color"].default_value = (*color, 1.0)
		bsdf.inputs["Emission Strength"].default_value = emission
	return mat


def image_material(name, path):
	"""Material showing one custom poster image, lightly self-lit."""
	mat = bpy.data.materials.new(name)
	nodes, links = mat.node_tree.nodes, mat.node_tree.links
	bsdf = nodes["Principled BSDF"]
	tex = nodes.new("ShaderNodeTexImage")
	tex.image = bpy.data.images.load(path)
	tex.image.pack()
	links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
	links.new(tex.outputs["Color"], bsdf.inputs["Emission Color"])
	bsdf.inputs["Emission Strength"].default_value = 0.35
	bsdf.inputs["Roughness"].default_value = 0.8
	return mat


MAT = {}
CUSTOM_POSTERS = []   # (material, team or None)
POSTER_ASSIGNMENT = {}  # (wall_index, bay) -> custom poster material


def make_materials():
	MAT.update({
		"floor": material("Floor", "1C2442", roughness=0.8),
		"wall": material("Wall", "141A33", roughness=0.5),
		"wall_trim": material("WallTrim", "0C1024", roughness=0.4, metallic=0.3),
		"wall_panel": material("WallPanel", "1E2749", roughness=0.45),
		"pilaster": material("Pilaster", "2A3563", roughness=0.4, metallic=0.2),
		"window": material("Window", "8FD8FF", emission=2.0),
		"roof": material("Roof", "10152C", roughness=0.6),
		"deck": material("Deck", "D3D9E6", roughness=0.6),
		"deck_side": material("DeckSide", "56628C", roughness=0.6),
		"ramp": material("Ramp", "BCC4D8", roughness=0.65),
		"cover": material("Cover", "2B3766", roughness=0.5),
		"truss": material("Truss", "333E68", roughness=0.35, metallic=0.5),
		"cyan": material("NeonCyan", "22E6FF", emission=3.5),
		"red": material("TeamRed", "E4574B", emission=1.2),
		"blue": material("TeamBlue", "3C8DDE", emission=1.2),
		# Muted a few steps toward the deck white so the pattern blends in.
		"dot_orange": material("DotOrange", "E1A47E", roughness=0.7),
		"dot_blue": material("DotBlue", "93ADDB", roughness=0.7),
		"dot_black": material("DotBlack", "6B7390", roughness=0.7),
		"floor_seam": material("FloorSeam", "161D38", roughness=0.85),
		"floor_border": material("FloorBorder", "18203D", roughness=0.8),
		"coping": material("Coping", "EEF1F7", roughness=0.5),
		"kick": material("Kick", "232B4D", roughness=0.55),
		"groove": material("Groove", "46517A", roughness=0.6),
		"curb": material("Curb", "7D89AD", roughness=0.55),
		"poster_orange": material("PosterOrange", "FF7A1A", emission=0.3, roughness=0.8),
		"poster_blue": material("PosterBlue", "2E86FF", emission=0.3, roughness=0.8),
	})
	if os.path.isdir(POSTER_DIR):
		files = sorted(f for f in os.listdir(POSTER_DIR) if f.lower().endswith((".png", ".jpg", ".jpeg")))
		for index, filename in enumerate(files):
			team = next((t for t in ("orange", "blue") if filename.lower().startswith(t + "_")), None)
			CUSTOM_POSTERS.append((image_material("PosterCustom%d" % index, os.path.join(POSTER_DIR, filename)), team))


def assign_custom_posters(bays):
	"""Scatter the custom posters over random eye-level bays, one per bay."""
	rng = random.Random(POSTER_SEED)
	free = {"orange": [], "blue": []}
	for wall_index, (axis, s) in enumerate(WALLS):
		for bay in range(bays):
			red_half = (s > 0) if axis == "z" else (bay >= bays / 2)
			free["orange" if red_half else "blue"].append((wall_index, bay))
	for team in free:
		rng.shuffle(free[team])
	# Team posters claim their own half first, then the rest go anywhere.
	for mat, team in sorted(CUSTOM_POSTERS, key=lambda entry: entry[1] is None):
		pool = [team] if team else rng.sample(sorted(free), len(free))
		for half in pool:
			if free[half]:
				POSTER_ASSIGNMENT[free[half].pop()] = mat
				break


def add_mesh(name, verts, faces, mat):
	mesh = bpy.data.meshes.new(name)
	mesh.from_pydata([g2b(*v) for v in verts], [], faces)
	mesh.update()
	bm = bmesh.new()
	bm.from_mesh(mesh)
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	bm.to_mesh(mesh)
	bm.free()
	mesh.materials.append(mat)
	obj = bpy.data.objects.new(name, mesh)
	bpy.context.scene.collection.objects.link(obj)
	return obj


def box(name, center, size, mat, yaw_deg=0.0):
	cx, cy, cz = center
	hx, hy, hz = size[0] / 2, size[1] / 2, size[2] / 2
	c, s = math.cos(math.radians(yaw_deg)), math.sin(math.radians(yaw_deg))
	verts = []
	for dy in (-hy, hy):
		for dx, dz in ((-hx, -hz), (hx, -hz), (hx, hz), (-hx, hz)):
			verts.append((cx + dx * c + dz * s, cy + dy, cz - dx * s + dz * c))
	faces = [(0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)]
	return add_mesh(name, verts, faces, mat)


def slab(name, x0, x1, z0, z1, y0, y1, mat):
	x0, x1 = sorted((x0, x1))
	z0, z1 = sorted((z0, z1))
	y0, y1 = sorted((y0, y1))
	return box(name, ((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), (x1 - x0, y1 - y0, z1 - z0), mat)


def ramp(name, low, high, width, height, mat):
	"""Solid wedge from `low` (x, z) at floor level up to `high` (x, z) at `height`."""
	lx, lz = low
	hx, hz = high
	dx, dz = hx - lx, hz - lz
	length = math.hypot(dx, dz)
	px, pz = -dz / length * width / 2, dx / length * width / 2
	verts = [
		(lx + px, 0.0, lz + pz), (lx - px, 0.0, lz - pz),
		(hx - px, 0.0, hz - pz), (hx + px, 0.0, hz + pz),
		(hx - px, height, hz - pz), (hx + px, height, hz + pz),
	]
	faces = [(0, 1, 2, 3), (1, 4, 2), (0, 3, 5), (0, 5, 4, 1), (3, 2, 4, 5)]
	return add_mesh(name, verts, faces, mat)


def face_slab(name, side_axis, sign, along0, along1, y0, y1, depth0, depth1, mat):
	"""Slab hugging the inner face of a side wall; depth is measured inward
	from the wall face and `along` runs parallel to the wall."""
	a = sign * (HALF - depth0)
	b = sign * (HALF - depth1)
	if side_axis == "x":
		return slab(name, a, b, along0, along1, y0, y1, mat)
	return slab(name, along0, along1, a, b, y0, y1, mat)


def poster(name, side_axis, sign, along, y, mat, depth=0.32):
	"""Flat 2:3 poster on a side wall's inner face, UVs spanning the image."""
	d = sign * (HALF - depth)
	if side_axis == "x":
		center, right = (d, y, along), (0.0, 0.0, float(sign))
	else:
		center, right = (along, y, d), (-float(sign), 0.0, 0.0)
	hw, hh = POSTER_W / 2, POSTER_H / 2
	corners = [
		(center[0] + right[0] * sx * hw, y + sy * hh, center[2] + right[2] * sx * hw)
		for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1))
	]
	mesh = bpy.data.meshes.new(name)
	mesh.from_pydata([g2b(*v) for v in corners], [], [(0, 1, 2, 3)])
	uv = mesh.uv_layers.new(name="UVMap")
	for loop, coord in zip(mesh.loops, ((0.0, 0.0), (1.0, 0.0), (1.0, 1.0), (0.0, 1.0))):
		uv.data[loop.index].uv = coord
	mesh.update()
	mesh.materials.append(mat)
	obj = bpy.data.objects.new(name, mesh)
	bpy.context.scene.collection.objects.link(obj)
	return obj


def place_poster(tag, wall_index, axis, s, bay, storey, along, y):
	mat = POSTER_ASSIGNMENT.get((wall_index, bay)) if storey == 0 else None
	if mat is None:
		red_half = (s > 0) if axis == "z" else (along > 0)
		mat = MAT["poster_orange" if red_half else "poster_blue"]
	poster("Deco_Poster%s_%d_%d" % (tag, bay, storey), axis, s, along, y, mat)


def chamfer_piece(name, corner, inset, thickness, length, y0, y1, mat, along=0.0):
	"""Box on a chamfered corner, `inset` measured inward from its inner face
	and `along` sliding it sideways along the face from its midpoint."""
	cx, cz = corner
	mid = HALF - CHAMFER / 2          # the chamfer face passes through (mid, mid)
	d = inset + thickness / 2
	ax, az = -cx / math.sqrt(2), cz / math.sqrt(2)
	pos = (cx * (mid - d / math.sqrt(2)) + ax * along, (y0 + y1) / 2, cz * (mid - d / math.sqrt(2)) + az * along)
	return box(name, pos, (length, y1 - y0, thickness), mat, yaw_deg=45 if cx * cz > 0 else -45)


def build_shell():
	outer = HALF + WALL_T
	slab("Floor_Court", -outer, outer, -outer, outer, -1.0, 0.0, MAT["floor"])

	# Structural walls: four sides plus chamfered corners, floor to roof.
	span = HALF - CHAMFER
	for s in (1, -1):
		slab("Wall_SideX%d" % s, s * HALF, s * outer, -span, span, 0.0, WALL_H, MAT["wall"])
		slab("Wall_SideZ%d" % s, -span, span, s * HALF, s * outer, 0.0, WALL_H, MAT["wall"])
	diag = CHAMFER * math.sqrt(2)
	for i, corner in enumerate(CORNERS):
		chamfer_piece("Wall_Corner%d" % i, corner, -WALL_T, WALL_T, diag + WALL_T * 2.5, 0.0, WALL_H, MAT["wall"])
		cx, cz = corner
		slab("Wall_CornerFill%d" % i, cx * (HALF - CHAMFER / 2), cx * outer, cz * (HALF - CHAMFER / 2), cz * outer, 0.0, WALL_H, MAT["wall"])
		chamfer_piece("Wall_ChamferPlinth%d" % i, corner, 0.0, 1.0, diag, 0.0, 3.0, MAT["wall_trim"])
		for k, (_, top) in enumerate(STOREYS):
			chamfer_piece("Wall_ChamferCornice%d_%d" % (i, k), corner, 0.0, 2.2, diag, top, top + 2.5, MAT["wall_trim"])

	# Wall faces: plinth, cornices with one cyan strip, pilasters, panels,
	# posters in the two lower storeys and window slits up top.
	bays = int(span * 2 / PILASTER_STEP)
	bay_w = span * 2 / bays
	assign_custom_posters(bays)
	for wall_index, (axis, s) in enumerate(WALLS):
		tag = "%s%d" % (axis.upper(), s)
		face_slab("Wall_Plinth" + tag, axis, s, -span, span, 0.0, 3.0, 0.0, 1.0, MAT["wall_trim"])
		face_slab("Deco_PlinthGlow" + tag, axis, s, -span, span, 2.4, 2.9, 1.0, 1.08, MAT["cyan"])
		for k, (_, top) in enumerate(STOREYS):
			face_slab("Wall_Cornice%s_%d" % (tag, k), axis, s, -span, span, top, top + 2.5, 0.0, 2.2, MAT["wall_trim"])
			face_slab("Deco_CorniceGlow%s_%d" % (tag, k), axis, s, -span, span, top - 0.5, top, 0.0, 1.6, MAT["cyan"])
		for k in range(bays + 1):
			p = -span + k * bay_w
			face_slab("Wall_Pilaster%s_%d" % (tag, k), axis, s, p - 2.0, p + 2.0, 3.0, WALL_H, 0.0, 1.5, MAT["pilaster"])
			if k == bays:
				break
			b0, b1 = p + 2.8, p + bay_w - 2.8
			for n, (y0, y1) in enumerate(STOREYS):
				face_slab("Deco_Panel%s_%d_%d" % (tag, k, n), axis, s, b0, b1, y0 + 1.0, y1 - 1.0, 0.0, 0.25, MAT["wall_panel"])
				if n == 2:
					mid = (b0 + b1) / 2
					for w in (-4.0, 0.0, 4.0):
						face_slab("Deco_Window%s_%d_%d" % (tag, k, w), axis, s, mid + w - 1.0, mid + w + 1.0, y0 + 4.0, y1 - 4.0, 0.25, 0.32, MAT["window"])
				else:
					place_poster(tag, wall_index, axis, s, k, n, (b0 + b1) / 2, (y0 + y1) / 2)

	# Solid roof on an even truss grid. The roof slab casts no shadow in Godot,
	# so daylight still reaches the court while the hall reads as closed in.
	slab("Roof_Ceiling", -outer - 2, outer + 2, -outer - 2, outer + 2, WALL_H, WALL_H + 2.0, MAT["roof"])
	steps = int(HALF * 2 / TRUSS_STEP)
	for k in range(1, steps + 1):
		p = -HALF + (k - 0.5) * (HALF * 2 / steps)
		slab("Wall_TrussX%d" % k, -HALF, HALF, p - 1.2, p + 1.2, WALL_H - 3.5, WALL_H, MAT["truss"])
		slab("Wall_TrussZ%d" % k, p - 1.2, p + 1.2, -HALF, HALF, WALL_H - 3.5, WALL_H, MAT["truss"])
		slab("Deco_TrussGlowX%d" % k, -HALF, HALF, p - 0.35, p + 0.35, WALL_H - 3.62, WALL_H - 3.5, MAT["cyan"])
		slab("Deco_TrussGlowZ%d" % k, p - 0.35, p + 0.35, -HALF, HALF, WALL_H - 3.62, WALL_H - 3.5, MAT["cyan"])


def build_court():
	# Corner towers, each with a long grip ramp running inward along x.
	for i, (cx, cz) in enumerate(CORNERS):
		tx, tz = cx * TOWER_C, cz * TOWER_C
		slab("Deck_Tower%d" % i, tx - TOWER_HALF, tx + TOWER_HALF, tz - TOWER_HALF, tz + TOWER_HALF, 0.0, TOWER_H, MAT["deck_side"])
		slab("Deco_TowerTop%d" % i, tx - TOWER_HALF, tx + TOWER_HALF, tz - TOWER_HALF, tz + TOWER_HALF, TOWER_H, TOWER_H + 0.05, MAT["deck"])
		slab("Deco_TowerEdge%d" % i, tx - TOWER_HALF - 0.32, tx + TOWER_HALF + 0.32, tz - TOWER_HALF - 0.32, tz + TOWER_HALF + 0.32, TOWER_H - 0.95, TOWER_H - 0.7, MAT["cyan"])
		inner_x = tx - cx * TOWER_HALF
		ramp("Ramp_Tower%d" % i, (cx * TOWER_RAMP_END, tz), (inner_x, tz), RAMP_W, TOWER_H, MAT["ramp"])

	# Skybridges link each tower pair along the side walls, on three piers.
	for s in (1, -1):
		bx = s * TOWER_C
		z0, z1 = -TOWER_C + TOWER_HALF, TOWER_C - TOWER_HALF
		slab("Deck_Bridge%d" % s, bx - BRIDGE_W / 2, bx + BRIDGE_W / 2, z0, z1, TOWER_H - 1.8, TOWER_H, MAT["deck"])
		for edge in (-1, 1):
			ex = bx + edge * (BRIDGE_W / 2 - 0.6)
			slab("Wall_BridgeRail%d_%d" % (s, edge), ex - 0.6, ex + 0.6, z0, z1, TOWER_H, TOWER_H + 2.0, MAT["cover"])
		for pz in (-40.0, 0.0, 40.0):
			slab("Block_Pier%d_%d" % (s, pz), bx - 3.5, bx + 3.5, pz - 3.5, pz + 3.5, 0.0, TOWER_H - 1.8, MAT["deck_side"])

	# Centre plateau with a ramp on every side and a beacon spire.
	slab("Deck_Plateau", -PLATEAU_HALF, PLATEAU_HALF, -PLATEAU_HALF, PLATEAU_HALF, 0.0, PLATEAU_H, MAT["deck_side"])
	slab("Deco_PlateauTop", -PLATEAU_HALF, PLATEAU_HALF, -PLATEAU_HALF, PLATEAU_HALF, PLATEAU_H, PLATEAU_H + 0.05, MAT["deck"])
	slab("Deco_PlateauEdge", -PLATEAU_HALF - 0.32, PLATEAU_HALF + 0.32, -PLATEAU_HALF - 0.32, PLATEAU_HALF + 0.32, PLATEAU_H - 0.95, PLATEAU_H - 0.7, MAT["cyan"])
	for i, (dx, dz) in enumerate(((1, 0), (-1, 0), (0, 1), (0, -1))):
		foot = PLATEAU_HALF + PLATEAU_RAMP_RUN
		ramp("Ramp_Plateau%d" % i, (dx * foot, dz * foot), (dx * PLATEAU_HALF, dz * PLATEAU_HALF), PLATEAU_RAMP_W, PLATEAU_H, MAT["ramp"])
	slab("Block_SpireBase", -SPIRE_HALF - 2, SPIRE_HALF + 2, -SPIRE_HALF - 2, SPIRE_HALF + 2, PLATEAU_H, PLATEAU_H + 5.0, MAT["wall_trim"])
	slab("Block_Spire", -SPIRE_HALF, SPIRE_HALF, -SPIRE_HALF, SPIRE_HALF, PLATEAU_H + 5.0, PLATEAU_H + SPIRE_H, MAT["wall"])
	for y in (PLATEAU_H + SPIRE_H * 0.45, PLATEAU_H + SPIRE_H - 1.5):
		slab("Deco_SpireRing%.0f" % y, -SPIRE_HALF - 0.2, SPIRE_HALF + 0.2, -SPIRE_HALF - 0.2, SPIRE_HALF + 0.2, y, y + 1.5, MAT["cyan"])

	# Team spawn decks: red at +z, blue at -z; a narrow ramp down the middle.
	for s, team in ((1, "red"), (-1, "blue")):
		zf, zb = s * SPAWN_DECK_FRONT, s * (HALF - 2.0)
		slab("Deck_Spawn_%s" % team, -SPAWN_DECK_HALF_W, SPAWN_DECK_HALF_W, zf, zb, 0.0, SPAWN_DECK_H, MAT["deck"])
		slab("Deco_SpawnStripe_%s" % team, -SPAWN_DECK_HALF_W - 0.1, SPAWN_DECK_HALF_W + 0.1, zf, zf + s * 0.8, SPAWN_DECK_H - 1.0, SPAWN_DECK_H + 0.02, MAT[team])
		ramp("Ramp_Spawn_%s" % team, (0.0, zf - s * 10.0), (0.0, zf), 12.0, SPAWN_DECK_H, MAT["ramp"])

	# Four big cover walls, point-symmetric through the origin.
	for i, ((x, z), yaw) in enumerate(COVERS):
		box("Block_Cover%d" % i, (x, COVER_SIZE[1] / 2, z), COVER_SIZE, MAT["cover"], yaw_deg=yaw)


def dot(name, x, z, y, radius, mat, sides=10, thickness=0.06):
	"""Flat round stud lying on a platform top."""
	ring = [(x + math.cos(k / sides * math.tau) * radius, z + math.sin(k / sides * math.tau) * radius) for k in range(sides)]
	verts = [(px, y, pz) for px, pz in ring] + [(px, y + thickness, pz) for px, pz in ring]
	faces = [tuple(range(sides)), tuple(range(sides, sides * 2))]
	faces += [(k, (k + 1) % sides, sides + (k + 1) % sides, sides + k) for k in range(sides)]
	return add_mesh(name, verts, faces, mat)


def pattern(tag, x0, x1, z0, z1, y, rng, keep_out=None):
	"""Dot grid on a platform top (world rect x0..x1, z0..z1 at height y),
	randomly coloured, with occasional lines joining neighbouring dots."""
	cols = max(1, int((x1 - x0) // DOT_STEP))
	rows = max(1, int((z1 - z0) // DOT_STEP))
	ox = x0 + ((x1 - x0) - (cols - 1) * DOT_STEP) / 2
	oz = z0 + ((z1 - z0) - (rows - 1) * DOT_STEP) / 2
	grid = {}
	for c in range(cols):
		for r in range(rows):
			x, z = ox + c * DOT_STEP, oz + r * DOT_STEP
			if keep_out is not None and abs(x) < keep_out and abs(z) < keep_out:
				continue
			if rng.random() > DOT_FILL:
				continue
			pick, acc = rng.random(), 0.0
			for key, weight in DOT_COLOURS:
				acc += weight
				if pick <= acc:
					break
			grid[(c, r)] = (x, z, key)
			dot("Deco_Dot%s_%d_%d" % (tag, c, r), x, z, y + 0.02, rng.uniform(*DOT_RADIUS), MAT[key], thickness=0.03)
	for (c, r), (x, z, key) in grid.items():
		for dc, dr in ((1, 0), (0, 1), (1, 1)):
			other = grid.get((c + dc, r + dr))
			if other is None or rng.random() > DOT_LINE_CHANCE * (0.5 if dc and dr else 1.0):
				continue
			ox2, oz2 = other[0], other[1]
			length = math.hypot(ox2 - x, oz2 - z)
			yaw = math.degrees(math.atan2(-(oz2 - z), ox2 - x))
			box("Deco_DotLine%s_%d_%d_%d%d" % (tag, c, r, dc, dr), ((x + ox2) / 2, y + 0.03, (z + oz2) / 2), (length, 0.02, DOT_LINE_WIDTH), MAT[key], yaw_deg=yaw)


def build_patterns():
	rng = random.Random(PATTERN_SEED)
	m = 2.5
	for i, (cx, cz) in enumerate(CORNERS):
		tx, tz = cx * TOWER_C, cz * TOWER_C
		pattern("Tower%d" % i, tx - TOWER_HALF + m, tx + TOWER_HALF - m, tz - TOWER_HALF + m, tz + TOWER_HALF - m, TOWER_H + 0.05, rng)
	for s in (1, -1):
		bx = s * TOWER_C
		pattern("Bridge%d" % s, bx - BRIDGE_W / 2 + m, bx + BRIDGE_W / 2 - m, -TOWER_C + TOWER_HALF + m, TOWER_C - TOWER_HALF - m, TOWER_H, rng)
	pattern("Plateau", -PLATEAU_HALF + m, PLATEAU_HALF - m, -PLATEAU_HALF + m, PLATEAU_HALF - m, PLATEAU_H + 0.05, rng, keep_out=SPIRE_HALF + 4.5)
	for s, team in ((1, "red"), (-1, "blue")):
		pattern("Spawn_%s" % team, -SPAWN_DECK_HALF_W + m, SPAWN_DECK_HALF_W - m, min(s * SPAWN_DECK_FRONT, s * (HALF - 2.0)) + m, max(s * SPAWN_DECK_FRONT, s * (HALF - 2.0)) - m, SPAWN_DECK_H, rng)


def sloped_bar(name, low, high, height, offset, width, below, above, mat):
	"""A bar that follows a ramp's slope along one edge (a curb): `low`/`high`
	are the ramp's (x, z) centreline ends, `offset` the sideways distance of
	the bar's centre, rising from 0 at `low` to `height` at `high`."""
	lx, lz = low
	hx, hz = high
	length = math.hypot(hx - lx, hz - lz)
	px, pz = -(hz - lz) / length, (hx - lx) / length
	verts = []
	for bottom in (True, False):
		for (x, z, y) in ((lx, lz, 0.0), (hx, hz, height)):
			for side in (-1, 1):
				o = offset + side * width / 2
				verts.append((x + px * o, (y - below) if bottom else (y + above), z + pz * o))
	# verts: bottom [low-, low+, high-, high+], top [same]
	faces = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 2, 6, 4), (1, 5, 7, 3), (0, 4, 5, 1), (2, 3, 7, 6)]
	return add_mesh(name, verts, faces, mat)


def platform_finish(tag, x0, x1, z0, z1, top, grooves=True):
	"""Pale coping around a platform's top edge, a dark kick plate at its
	base, and evenly spaced vertical grooves on its sides."""
	o = 0.3
	for name, a, b, c, d in (("N", x0 - o, x1 + o, z1 - 0.2, z1 + o), ("S", x0 - o, x1 + o, z0 - o, z0 + 0.2),
			("E", x1 - 0.2, x1 + o, z0, z1), ("W", x0 - o, x0 + 0.2, z0, z1)):
		slab("Deco_Coping%s%s" % (tag, name), a, b, c, d, top - 0.55, top + 0.03, MAT["coping"])
		if top > 1.6:
			ka, kb = (a, b) if name in "NS" else (a, b)
			slab("Deco_Kick%s%s" % (tag, name), ka, kb, c, d, 0.0, 1.0, MAT["kick"])
	if not grooves or top < 4.0:
		return
	for axis_len, fixed, along0, along1, horizontal in ((x1 - x0, (z0, z1), x0, x1, True), (z1 - z0, (x0, x1), z0, z1, False)):
		count = int(axis_len // PLATFORM_GROOVE_STEP)
		if count < 2:
			continue
		step = axis_len / count
		for k in range(1, count):
			p = along0 + k * step
			for f in fixed:
				d = 0.12 if f == fixed[1] else -0.12
				if horizontal:
					slab("Deco_Groove%s_%d_%d" % (tag, k, f), p - 0.18, p + 0.18, f, f + d, 1.4, top - 0.9, MAT["groove"])
				else:
					slab("Deco_Groove%s_v%d_%d" % (tag, k, f), f, f + d, p - 0.18, p + 0.18, 1.4, top - 0.9, MAT["groove"])


def ramp_curbs(tag, low, high, width, height):
	for side in (-1, 1):
		sloped_bar("Deco_Curb%s_%d" % (tag, side), low, high, height, side * (width / 2 + 0.3), 0.7, 0.5, 0.35, MAT["curb"])


def build_finish():
	# Floor: a darker border walkway along the walls and faint tile seams.
	b = HALF - FLOOR_BORDER
	for s in (1, -1):
		slab("Deco_FloorBorderX%d" % s, s * b, s * HALF, -HALF, HALF, 0.0, 0.02, MAT["floor_border"])
		slab("Deco_FloorBorderZ%d" % s, -b, b, s * b, s * HALF, 0.0, 0.02, MAT["floor_border"])
	steps = int(b * 2 / FLOOR_TILE)
	for k in range(1, steps):
		p = -b + k * (b * 2 / steps)
		slab("Deco_SeamX%d" % k, -b, b, p - 0.15, p + 0.15, 0.0, 0.025, MAT["floor_seam"])
		slab("Deco_SeamZ%d" % k, p - 0.15, p + 0.15, -b, b, 0.0, 0.025, MAT["floor_seam"])

	# Chamfered corners carry the same wall treatment as the sides, so the
	# panels, glow strips and posters wrap round instead of stopping dead.
	diag = CHAMFER * math.sqrt(2)
	panel_len = diag - 5.6
	for i, corner in enumerate(CORNERS):
		red_half = corner[1] > 0
		chamfer_piece("Deco_ChamferPlinthGlow%d" % i, corner, 1.0, 0.08, diag, 2.4, 2.9, MAT["cyan"])
		chamfer_piece("Wall_ChamferDadoRail%d" % i, corner, 0.0, 1.1, diag, DADO[1] + 0.5, DADO[1] + 1.6, MAT["wall_trim"])
		chamfer_piece("Deco_ChamferDado%d" % i, corner, 0.0, 0.25, panel_len, DADO[0], DADO[1], MAT["wall_panel"])
		for k, (y0, y1) in enumerate(STOREYS):
			chamfer_piece("Deco_ChamferCorniceGlow%d_%d" % (i, k), corner, 0.0, 1.6, diag, y1 - 0.5, y1, MAT["cyan"])
			chamfer_piece("Deco_ChamferPanel%d_%d" % (i, k), corner, 0.0, 0.25, panel_len, y0 + 1.0, y1 - 1.0, MAT["wall_panel"])
			if k == 2:
				for w in (-4.0, 0.0, 4.0):
					chamfer_piece("Deco_ChamferWindow%d_%d" % (i, w), corner, 0.25, 0.07, 2.0, y0 + 4.0, y1 - 4.0, MAT["window"], along=w)
			else:
				mid_y = (y0 + y1) / 2
				chamfer_piece("Deco_ChamferPoster%d_%d" % (i, k), corner, 0.25, 0.07, POSTER_W, mid_y - POSTER_H / 2, mid_y + POSTER_H / 2, MAT["poster_orange" if red_half else "poster_blue"])

	# Lower wall: a dado band of panels with a rail, so the first few
	# blob-heights of wall carry detail at eye level.
	span = HALF - CHAMFER
	bays = int(span * 2 / PILASTER_STEP)
	bay_w = span * 2 / bays
	for axis, s in WALLS:
		tag = "%s%d" % (axis.upper(), s)
		face_slab("Wall_DadoRail" + tag, axis, s, -span, span, DADO[1] + 0.5, DADO[1] + 1.6, 0.0, 1.1, MAT["wall_trim"])
		for k in range(bays):
			p = -span + k * bay_w
			face_slab("Deco_Dado%s_%d" % (tag, k), axis, s, p + 2.8, p + bay_w - 2.8, DADO[0], DADO[1], 0.0, 0.25, MAT["wall_panel"])

	# Platforms: coping, kick plates and side grooves.
	for i, (cx, cz) in enumerate(CORNERS):
		tx, tz = cx * TOWER_C, cz * TOWER_C
		platform_finish("Tower%d" % i, tx - TOWER_HALF, tx + TOWER_HALF, tz - TOWER_HALF, tz + TOWER_HALF, TOWER_H)
		inner_x = tx - cx * TOWER_HALF
		ramp_curbs("Tower%d" % i, (cx * TOWER_RAMP_END, tz), (inner_x, tz), RAMP_W, TOWER_H)
	for s in (1, -1):
		bx = s * TOWER_C
		platform_finish("Bridge%d" % s, bx - BRIDGE_W / 2, bx + BRIDGE_W / 2, -TOWER_C + TOWER_HALF, TOWER_C - TOWER_HALF, TOWER_H, grooves=False)
	platform_finish("Plateau", -PLATEAU_HALF, PLATEAU_HALF, -PLATEAU_HALF, PLATEAU_HALF, PLATEAU_H)
	for i, (dx, dz) in enumerate(((1, 0), (-1, 0), (0, 1), (0, -1))):
		foot = PLATEAU_HALF + PLATEAU_RAMP_RUN
		ramp_curbs("Plateau%d" % i, (dx * foot, dz * foot), (dx * PLATEAU_HALF, dz * PLATEAU_HALF), PLATEAU_RAMP_W, PLATEAU_H)
	for s, team in ((1, "red"), (-1, "blue")):
		zf, zb = s * SPAWN_DECK_FRONT, s * (HALF - 2.0)
		platform_finish("Spawn_%s" % team, -SPAWN_DECK_HALF_W, SPAWN_DECK_HALF_W, min(zf, zb), max(zf, zb), SPAWN_DECK_H, grooves=False)
		ramp_curbs("Spawn_%s" % team, (0.0, zf - s * 10.0), (0.0, zf), 12.0, SPAWN_DECK_H)

	# Cover walls: a dark cap and base, the cyan reduced to a thin inset line.
	for i, ((x, z), yaw) in enumerate(COVERS):
		L, H, T = COVER_SIZE
		box("Deco_CoverCap%d" % i, (x, H + 0.2, z), (L + 0.5, 0.4, T + 0.5), MAT["kick"], yaw_deg=yaw)
		box("Deco_CoverBase%d" % i, (x, 0.5, z), (L + 0.4, 1.0, T + 0.4), MAT["kick"], yaw_deg=yaw)
		for side in (-1, 1):
			c, sn = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
			ox, oz = sn * side * (T / 2 + 0.05), c * side * (T / 2 + 0.05)
			box("Deco_CoverLine%d_%d" % (i, side), (x + ox, H - 1.6, z + oz), (L - 3.0, 0.25, 0.1), MAT["cyan"], yaw_deg=yaw)

	# Spire: vertical grooves on every face.
	for k in (-2.5, 0.0, 2.5):
		for s in (1, -1):
			slab("Deco_SpireGrooveX%d_%.0f" % (s, k), s * SPIRE_HALF, s * (SPIRE_HALF + 0.1), k - 0.15, k + 0.15, PLATEAU_H + 6.0, PLATEAU_H + SPIRE_H - 3.0, MAT["groove"])
			slab("Deco_SpireGrooveZ%d_%.0f" % (s, k), k - 0.15, k + 0.15, s * SPIRE_HALF, s * (SPIRE_HALF + 0.1), PLATEAU_H + 6.0, PLATEAU_H + SPIRE_H - 3.0, MAT["groove"])


def join_by_family():
	"""Merge objects sharing a collision prefix and material into one mesh."""
	groups = {}
	for obj in list(bpy.context.scene.objects):
		if obj.type != "MESH":
			continue
		prefix = obj.name.split("_", 1)[0]
		groups.setdefault((prefix, obj.data.materials[0].name), []).append(obj)
	for (prefix, mat_name), objs in groups.items():
		bpy.ops.object.select_all(action="DESELECT")
		for obj in objs:
			obj.select_set(True)
		bpy.context.view_layer.objects.active = objs[0]
		if len(objs) > 1:
			bpy.ops.object.join()
		joined = bpy.context.view_layer.objects.active
		joined.name = "%s_%s" % (prefix, mat_name)
		joined.data.name = joined.name


def preview(path):
	import mathutils
	scene = bpy.context.scene
	cam_data = bpy.data.cameras.new("PreviewCam")
	cam_data.lens = 16
	cam_data.clip_end = 2000
	cam = bpy.data.objects.new("PreviewCam", cam_data)
	scene.collection.objects.link(cam)
	cam.location = g2b(-90.0, 50.0, 135.0)
	target = mathutils.Vector(g2b(10.0, 4.0, 10.0))
	cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()
	scene.camera = cam
	# Blender has no "no shadow" roof, so light the hall from under the ceiling.
	light_data = bpy.data.lights.new("PreviewLight", "AREA")
	light_data.energy = 1200000.0
	light_data.size = 240.0
	light = bpy.data.objects.new("PreviewLight", light_data)
	light.location = g2b(0.0, WALL_H - 8.0, 0.0)
	scene.collection.objects.link(light)
	world = bpy.data.worlds.new("PreviewWorld")
	world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.12, 0.1, 0.25, 1)
	world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.9
	scene.world = world
	scene.render.engine = "BLENDER_EEVEE"
	scene.render.resolution_x, scene.render.resolution_y = 1400, 900
	scene.render.filepath = path
	bpy.ops.render.render(write_still=True)
	for obj in (cam, light):
		bpy.data.objects.remove(obj)


if __name__ == "__main__":
	bpy.ops.wm.read_factory_settings(use_empty=True)
	make_materials()
	build_shell()
	build_court()
	build_finish()
	build_patterns()
	join_by_family()
	preview_dir = os.environ.get("SKYLINE_PREVIEW_DIR", "")
	if preview_dir:
		preview(os.path.join(preview_dir, "skyline_inside.png"))
	bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_apply=True, export_yup=True)
	save_path = os.environ.get("SKYLINE_BLEND", "")
	if save_path:
		bpy.ops.wm.save_as_mainfile(filepath=save_path)
	print("SKYLINE exported %s (%d objects, %d custom posters)" % (OUT, len(bpy.data.objects), len(CUSTOM_POSTERS)))
