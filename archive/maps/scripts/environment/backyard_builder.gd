extends RefCounted

const D := 5.775
const GU := D * 0.5
const GEOMETRY := preload("res://scripts/environment/arena_blueprint_geometry.gd")
const BACKYARD_GEOMETRY := preload("res://scripts/environment/backyard_blueprint_geometry.gd")
const SPRINKLER := preload("res://scripts/interactables/backyard_sprinkler_pad.gd")
const MUSHROOM := preload("res://scripts/interactables/backyard_mushroom_pad.gd")

const HOSE_POSITIONS := [Vector2(15, 51), Vector2(69, 51), Vector2(15, 18), Vector2(69, 18)]
const PLANTER_POSITIONS := [Vector2(15, 44), Vector2(69, 44), Vector2(15, 26), Vector2(69, 26)]
const SPRINKLER_POSITIONS := [Vector2(22, 13), Vector2(62, 13), Vector2(12, 35), Vector2(72, 35), Vector2(22, 55), Vector2(62, 55)]
const MUSHROOM_POSITIONS := [Vector2(29, 21), Vector2(55, 21), Vector2(29, 51), Vector2(55, 51)]
const STONE_POSITIONS := [
	Vector2(42, 10), Vector2(41.5, 14), Vector2(42.5, 18), Vector2(41.5, 22), Vector2(42, 26),
	Vector2(42, 54), Vector2(42.5, 50), Vector2(41.5, 46), Vector2(42.5, 42), Vector2(42, 38),
	Vector2(18, 32), Vector2(22, 32.5), Vector2(26, 31.5), Vector2(30, 32),
	Vector2(54, 32), Vector2(58, 31.5), Vector2(62, 32.5), Vector2(66, 32),
	Vector2(28, 24), Vector2(56, 24),
]
# Level-design additions over the blueprint: sawn log stumps break the two long
# open lawn diagonals, and the picnic umbrella closes the spawn-to-spawn sightline.
const STUMP_POSITIONS := [Vector2(34, 44), Vector2(50, 20)]


func build(a) -> Dictionary:
	_build_lawn(a)
	_build_spawn_decks(a)
	_build_picnic_platform(a)
	_build_hose_ramps(a)
	_build_planter_cover(a)
	_build_log_stumps(a)
	_build_stepping_stones(a)
	_build_sprinklers(a)
	_build_mushrooms(a)
	_build_perimeter_garden(a)
	_build_flow(a)
	return {
		"identity": "Faithful oversized backyard garden from the supplied 84 x 64 GU blueprint",
		"landmark": "Central Picnic Platform",
		"routes": ["red spawn stone route", "blue spawn stone route", "left hose-planter route", "right hose-planter route", "sprinkler side route", "picnic deck contest", "stump diagonals", "umbrella bank ceiling"],
		"interactables": ["six sprinkler lift pads", "four momentum-preserving mushroom pads", "twenty stepping-stone bounce blocks", "four hose ramps"],
		"prop_families": ["timber decks and picnic furniture", "curved garden hoses", "stone bounce routes", "sprinklers and mushrooms", "planters and perimeter flowers", "patio umbrella and log stumps"],
		"flow_plan": [
			"Direct: spawn deck to central stepping stones to picnic platform",
			"Left and right: hose ramp to planter rebound to mushroom pad",
			"Wide: side sprinkler lift to stepping stones to picnic edge",
			"Diagonal: stump cover between stones and mushroom, then the hose launch",
		],
		"combat_spaces": [
			"Picnic platform is the readable central fighting landmark",
			"Planter pairs create short redirects without defensive dead ends",
			"Spawn decks remain open toward center and cannot become enclosed camps",
			"The umbrella base and canopy hide each spawn deck from the other and give the picnic contest a ceiling to bank shots off",
			"Log stumps turn the two longest lawn diagonals into peek-and-ricochet duels",
		],
		"blueprint": {
			"footprint_gu": Vector2(84, 64),
			"grass_gu": Vector2(76, 56),
			"gu_scale_d": 0.5,
			"unit_scale": GU,
			"roof_height_d": 5.8,
			"fence_height_d": 2.5,
			"spawn_centers_gu": [Vector2(42, 6), Vector2(42, 58)],
			"picnic_center_gu": Vector2(42, 32),
			"hose_centers_gu": HOSE_POSITIONS,
			"planter_centers_gu": PLANTER_POSITIONS,
			"sprinkler_centers_gu": SPRINKLER_POSITIONS,
			"mushroom_centers_gu": MUSHROOM_POSITIONS,
			"stump_centers_gu": STUMP_POSITIONS,
		},
	}


func _build_lawn(a) -> void:
	# The shell supplies the one continuous collision slab. These two ultra-thin layers
	# create the blueprint's lawn and broad mowing bands without collision seams.
	var lawn: MeshInstance3D = a.add_box("BackyardLawn", Vector3(0, 0.04, 0), Vector3(76 * GU, 0.08, 56 * GU), a.mat("backyard_grass"), false)
	_mark(lawn, "grass", Vector2(42, 32), Vector3(76, 0.08 / GU, 56))
	for x_gu in range(6, 79, 4):
		var dark: bool = posmod(x_gu, 8) == 0
		a.add_box("MowingBand", _world(float(x_gu), 32, 0.052), Vector3(3.85 * GU, 0.015, 55.6 * GU), a.mat("backyard_grass_dark") if dark else a.mat("backyard_grass_light"), false)


func _build_spawn_decks(a) -> void:
	for spec in [[Vector2(42, 6), true], [Vector2(42, 58), false]]:
		var grid := spec[0] as Vector2
		var is_red := bool(spec[1])
		var root: Node3D = a.add_landmark_root("RedSpawnDeck" if is_red else "BlueSpawnDeck")
		var team_material: Material = a.mat("backyard_red") if is_red else a.mat("backyard_blue")
		var deck_center: Vector3 = _world(grid.x, grid.y, 1.0)
		var deck: MeshInstance3D = a.add_box("SpawnDeck", deck_center, Vector3(12 * GU, 0.4 * D, 6 * GU), a.mat("backyard_wood"), true, Vector3.ZERO, root, a.surface("normal"))
		var deck_support_key := String(deck.name)
		a.mark_supported_structure(deck, deck_support_key)
		for side in [-1.0, 1.0]:
			a.add_ground_support("SpawnDeckFooting", Vector3(deck_center.x + side * 4.3 * GU, 0.4 * D, deck_center.z), Vector3(0.65 * D, 0.8 * D, 4.8 * GU), a.mat("backyard_wood_dark"), deck_support_key, a.surface("normal"))
		_mark(deck, "spawn_deck", grid, Vector3(12, 0.4 * D / GU, 6), {"team": "red" if is_red else "blue", "surface_height_d": 1.2})
		_add_deck_boards(a, root, grid, Vector2(12, 6), 1.215, team_material)
		var center_sign: float = -1.0 if is_red else 1.0
		var front_z: float = deck_center.z + center_sign * 3.7 * GU
		var ramp_center := Vector3(deck_center.x, 0, front_z + center_sign * 3.0 * GU)
		var ramp_yaw: float = 0.0 if is_red else PI
		var ramp: Node3D = GEOMETRY.add_curved_ramp(a, "SpawnGardenRamp", ramp_center, 4.0 * GU, 6.0 * GU, 1.2 * D, ramp_yaw, a.mat("backyard_wood"), a.surface("normal"), a.mat("backyard_wood_light"))
		_mark(ramp, "spawn_ramp", grid + Vector2(0, 5 if is_red else -5), Vector3(4, 1.2 * D / GU, 6))
		# Short open-front side rails, backed by square newel posts as shown in the sheet.
		for side in [-1.0, 1.0]:
			var rail_x: float = deck_center.x + side * 5.55 * GU
			var side_rail: MeshInstance3D = a.add_box("SpawnSideRail", Vector3(rail_x, 1.55 * D, deck_center.z - center_sign * 0.2 * GU), Vector3(0.32 * D, 0.7 * D, 4.6 * GU), a.mat("backyard_wood_light"), true, Vector3.ZERO, root, a.surface("bounce"))
			side_rail.add_to_group("duel_cover")
			a.add_box("SpawnNewel", Vector3(rail_x, 1.5 * D, deck_center.z + center_sign * 2.45 * GU), Vector3(0.58 * D, 1.0 * D, 0.58 * D), a.mat("backyard_wood_light"), true, Vector3.ZERO, root, a.surface("bounce"))
			_add_planter_pot(a, root, Vector3(rail_x - side * 0.35 * GU, 1.2 * D, deck_center.z - center_sign * 2.1 * GU), team_material)


func _build_picnic_platform(a) -> void:
	var root: Node3D = a.add_landmark_root("CenterPicnicPlatform")
	var deck: MeshInstance3D = a.add_box("PicnicDeck", Vector3(0, 0.85 * D, 0), Vector3(16 * GU, 0.5 * D, 14 * GU), a.mat("backyard_wood"), true, Vector3.ZERO, root, a.surface("normal"))
	var deck_support_key := String(deck.name)
	a.mark_supported_structure(deck, deck_support_key)
	for x_side in [-1.0, 1.0]:
		for z_side in [-1.0, 1.0]:
			a.add_ground_support("PicnicDeckFooting", Vector3(x_side * 6.1 * GU, 0.30 * D, z_side * 5.1 * GU), Vector3(0.7 * D, 0.60 * D, 0.7 * D), a.mat("backyard_wood_dark"), deck_support_key, a.surface("normal"))
	_mark(deck, "picnic_platform", Vector2(42, 32), Vector3(16, 0.5 * D / GU, 14), {"surface_height_d": 1.1})
	a.mark_elevated_route(deck, Vector3(-6.5 * GU, 1.1 * D, 0))
	_add_deck_boards(a, root, Vector2(42, 32), Vector2(16, 14), 1.11, a.mat("backyard_wood_light"))
	for side in [-1.0, 1.0]:
		var center := Vector3(0, 0, side * (7.0 * GU + 2.0 * GU))
		var yaw: float = PI if side > 0.0 else 0.0
		GEOMETRY.add_curved_ramp(a, "PicnicDeckRamp", center, 4.0 * GU, 4.0 * GU, 1.1 * D, yaw, a.mat("backyard_wood"), a.surface("normal"), a.mat("backyard_wood_light"))
	# Low, readable table: gingham top, two benches, four legs, and compact place settings.
	# The height values in the text conflict if treated as deck-relative. The drawing
	# clearly shows low bounce-over furniture, so 1.7D is the absolute tabletop surface.
	var table_top_y := 1.7 * D
	var table: MeshInstance3D = a.add_box("PicnicTableTop", Vector3(0, table_top_y - 0.12 * D, 0), Vector3(7 * GU, 0.24 * D, 4 * GU), a.mat("backyard_gingham"), true, Vector3.ZERO, root, a.surface("bounce"))
	table.add_to_group("duel_cover")
	for x in [-2.45 * GU, 2.45 * GU]:
		for z in [-1.15 * GU, 1.15 * GU]:
			a.add_box("PicnicTableLeg", Vector3(x, 1.38 * D, z), Vector3(0.42 * D, 0.55 * D, 0.42 * D), a.mat("backyard_wood_light"), true, Vector3(0, 0, signf(x * z) * 0.12), root, a.surface("bounce"))
	for z in [-2.85 * GU, 2.85 * GU]:
		a.add_box("PicnicBench", Vector3(0, 1.42 * D, z), Vector3(7.4 * GU, 0.28 * D, 1.0 * GU), a.mat("backyard_wood_light"), true, Vector3.ZERO, root, a.surface("bounce"))
	for corner in [Vector2(-7, -6), Vector2(7, -6), Vector2(-7, 6), Vector2(7, 6)]:
		_add_planter_pot(a, root, Vector3(corner.x * GU, 1.1 * D, corner.y * GU), a.mat("backyard_flower_yellow"))
	_build_table_settings(a, root, table_top_y)
	_build_picnic_umbrella(a, root, table_top_y)


func _build_picnic_umbrella(a, root: Node3D, table_top_y: float) -> void:
	# A weighted patio umbrella rises through the table. Its stone base is the
	# one solid thing on the flat spawn-to-spawn line above the tabletop, the pole
	# is a centre post to bank shots around, and the canopy is a solid ceiling over
	# the picnic contest that never reaches the deck routes below it.
	var base_center := Vector3(0, table_top_y + 0.16 * D, 0)
	var base: MeshInstance3D = a.add_cylinder("UmbrellaBase", base_center, 0.62 * D, 0.32 * D, a.mat("backyard_stone"), true, Vector3.ZERO, root, a.surface("bounce"))
	base.add_to_group("duel_cover")
	_mark(base, "umbrella_base", Vector2(42, 32), Vector3(1.24 * D / GU, 0.32 * D / GU, 1.24 * D / GU), {"sightline_break": true})
	a.add_cylinder("UmbrellaBaseInset", base_center + Vector3.UP * 0.17 * D, 0.5 * D, 0.03 * D, a.mat("backyard_stone_light"), false, Vector3.ZERO, root)
	var pole_bottom := table_top_y + 0.32 * D
	var pole_top := 3.25 * D
	a.add_cylinder("UmbrellaPole", Vector3(0, (pole_bottom + pole_top) * 0.5, 0), 0.09 * D, pole_top - pole_bottom, a.mat("backyard_wood_light"), true, Vector3.ZERO, root, a.surface("bounce"))
	for ring_height in [2.3, 2.9]:
		a.add_torus("UmbrellaPoleRing", Vector3(0, ring_height * D, 0), 0.09 * D, 0.14 * D, a.mat("backyard_wood_dark"), false, Vector3.ZERO, root)
	var canopy := BACKYARD_GEOMETRY.add_umbrella_canopy(a, "PicnicUmbrellaCanopy", Vector3(0, pole_top, 0), 2.4 * D, 0.55 * D, a.mat("backyard_gingham"), a.mat("backyard_red"), a.surface("bounce"))
	_mark(canopy, "umbrella_canopy", Vector2(42, 32), Vector3(4.8 * D / GU, 0.55 * D / GU, 4.8 * D / GU), {"bank_ceiling": true, "rim_height_d": 3.25})


func _build_hose_ramps(a) -> void:
	for index in range(HOSE_POSITIONS.size()):
		var grid: Vector2 = HOSE_POSITIONS[index]
		var world: Vector3 = _world(grid.x, grid.y, 0)
		var toward_center := -Vector3(world.x, 0.0, world.z).normalized()
		var yaw: float = atan2(toward_center.x, toward_center.z)
		var bend_sign := -signf(world.x)
		var ramp: Node3D = BACKYARD_GEOMETRY.add_curved_hose_ramp(a, "GardenHoseRamp", world, 2.2 * GU, 10.0 * GU, 1.4 * D, yaw, bend_sign, a.mat("backyard_hose"), a.mat("backyard_hose_light"), a.surface("ice"))
		_mark(ramp, "hose_ramp", grid, Vector3(2.2, 1.4 * D / GU, 10), {"launch_lip_d": 0.18, "curved_plan": true, "launches_inward": true})
		# The high end of the hose is walkable high ground; probe it just short of
		# the launch lip so the ray lands on the last collision segment's top.
		var probe_t := 0.9
		var probe_local := Vector3(bend_sign * 10.0 * GU * 0.62 * (probe_t * probe_t - 1.0 / 3.0), 1.4 * D * probe_t * probe_t * (3.0 - 2.0 * probe_t), lerpf(-5.0 * GU, 5.0 * GU, probe_t))
		a.mark_elevated_route(ramp, world + Basis(Vector3.UP, yaw) * probe_local)
		for end in [-1.0, 1.0]:
			var support_offset := Basis(Vector3.UP, yaw) * Vector3(0, 0.32 * D, end * 5.05 * GU)
			a.add_box("HoseWoodSupport", world + support_offset, Vector3(3.0 * GU, 0.65 * D, 0.55 * D), a.mat("backyard_wood_light"), true, Vector3(0, yaw, 0), null, a.surface("bounce"))


func _build_planter_cover(a) -> void:
	for grid in PLANTER_POSITIONS:
		var root: Node3D = a.add_landmark_root("PlanterCover")
		root.position = _world(grid.x, grid.y, 0)
		var body: MeshInstance3D = a.add_box("PlanterBody", Vector3(0, 0.625 * D, 0), Vector3(9 * GU, 1.25 * D, 2.5 * GU), a.mat("backyard_wood"), true, Vector3.ZERO, root, a.surface("bounce"))
		_mark(body, "planter_cover", grid, Vector3(9, 1.25 * D / GU, 2.5))
		body.add_to_group("duel_cover")
		for x in [-4.25, -2.1, 0.0, 2.1, 4.25]:
			a.add_box("PlanterSlat", Vector3(x * GU, 0.67 * D, -1.28 * GU), Vector3(0.17 * GU, 1.08 * D, 0.08 * D), a.mat("backyard_wood_light"), false, Vector3.ZERO, root)
		a.add_box("PlanterTopLip", Vector3(0, 1.28 * D, 0), Vector3(9.35 * GU, 0.18 * D, 2.85 * GU), a.mat("backyard_wood_light"), false, Vector3.ZERO, root)
		for flower_index in range(13):
			var x := lerpf(-4.0, 4.0, float(flower_index) / 12.0) * GU
			var z := (-0.55 if flower_index % 2 == 0 else 0.55) * GU
			var color: Material = [a.mat("backyard_flower_red"), a.mat("backyard_flower_yellow"), a.mat("backyard_flower_pink")][flower_index % 3]
			a.add_sphere("PlanterFlower", Vector3(x, 1.65 * D + sin(float(flower_index)) * 0.12 * D, z), 0.22 * D, color, false, root)


func _build_log_stumps(a) -> void:
	# Sawn log stumps stand in the two long open diagonals between the stone
	# route and the mushrooms: 1.55D of solid bark that hides a blob mid-approach
	# and gives the widest lawn lanes a ricochet post.
	for index in range(STUMP_POSITIONS.size()):
		var grid: Vector2 = STUMP_POSITIONS[index]
		var height := 1.55 * D
		var base := _world(grid.x, grid.y, 0)
		var stump: MeshInstance3D = a.add_cylinder("LogStump", base + Vector3.UP * height * 0.5, 0.95 * GU, height, a.mat("backyard_wood_dark"), true, Vector3.ZERO, null, a.surface("bounce"))
		_mark(stump, "log_stump", grid, Vector3(1.9, height / GU, 1.9), {"sightline_cover": true})
		stump.add_to_group("duel_cover")
		a.add_cylinder("LogStumpRings", base + Vector3.UP * (height + 0.02 * D), 0.86 * GU, 0.04 * D, a.mat("backyard_wood_light"), false)
		a.add_cylinder("LogStumpHeart", base + Vector3.UP * (height + 0.045 * D), 0.4 * GU, 0.03 * D, a.mat("backyard_wood"), false)
		for bark_index in range(6):
			var angle := TAU * float(bark_index) / 6.0 + float(index) * 0.4
			a.add_box("LogBark", base + Vector3(cos(angle), 0.0, sin(angle)) * 0.97 * GU + Vector3.UP * height * 0.5, Vector3(0.12 * GU, height * 0.92, 0.24 * GU), a.mat("backyard_wood"), false, Vector3(0, -angle, 0))


func _build_stepping_stones(a) -> void:
	for index in range(STONE_POSITIONS.size()):
		var grid: Vector2 = STONE_POSITIONS[index]
		var height_d := 0.25 + float(index % 3) * 0.10
		var world := _world(grid.x, grid.y, height_d * 0.5)
		var body: MeshInstance3D = a.add_cylinder("SteppingStone", world, 0.78 * GU, height_d * D, a.mat("backyard_stone"), true, Vector3.ZERO, null, a.surface("bounce"))
		body.scale.x = 1.10 + float(index % 2) * 0.08
		body.scale.z = 0.94 + float((index + 1) % 2) * 0.08
		_mark(body, "stepping_stone", grid, Vector3(1.5, height_d * D / GU, 1.5), {"bounce_strength": "medium_high"})
		a.add_cylinder("StoneTopInset", world + Vector3.UP * (height_d * D * 0.51), 0.65 * GU, 0.04 * D, a.mat("backyard_stone_light"), false)


func _build_sprinklers(a) -> void:
	for grid in SPRINKLER_POSITIONS:
		var pad: Area3D = SPRINKLER.new()
		pad.name = "SprinklerPad"
		pad.position = _world(grid.x, grid.y, 0.0)
		pad.set("pad_radius", 1.25 * GU)
		pad.set("influence_radius", 4.0 * GU)
		pad.set("upward_force", 112.0)
		pad.set("outward_force", 48.0)
		a.add_child(pad)
		_mark(pad, "sprinkler_pad", grid, Vector3(2.5, 0.25 * D / GU, 2.5), {"damage": false, "continuous": true})
		pad.add_to_group("intentional_interactable")
		pad.set_meta("duel_purpose", "Predictable upward and outward lift into nearby garden routes")
		pad.set_meta("leads_to_center", false)


func _build_mushrooms(a) -> void:
	for grid in MUSHROOM_POSITIONS:
		var pad: Area3D = MUSHROOM.new()
		pad.name = "MushroomBouncePad"
		pad.position = _world(grid.x, grid.y, 0.0)
		pad.set("cap_radius", 1.25 * GU)
		pad.set("total_height", 0.9 * D)
		pad.set("impulse_strength", 48.0)
		a.add_child(pad)
		_mark(pad, "mushroom_pad", grid, Vector3(2.5, 0.9 * D / GU, 2.5), {"momentum_preserving": true, "compresses": true})
		pad.add_to_group("intentional_interactable")
		pad.set_meta("duel_purpose", "Momentum-preserving angled bounce toward picnic or side chain")
		pad.set_meta("leads_to_center", false)


func _build_perimeter_garden(a) -> void:
	# Decoration stays in the narrow border strip only and never creates hidden collision.
	for side in [-1.0, 1.0]:
		for offset in range(-26, 27, 8):
			_add_flower_cluster(a, Vector3(side * 39.0 * GU, 0.18 * D, float(offset) * GU), offset)
		for offset in range(-34, 35, 10):
			_add_flower_cluster(a, Vector3(float(offset) * GU, 0.18 * D, side * 29.0 * GU), offset + 3)
	for grid in [Vector2(4, 4), Vector2(80, 4), Vector2(4, 60), Vector2(80, 60)]:
		_add_planter_pot(a, a.visual_root(), _world(grid.x, grid.y, 0.0), a.mat("backyard_flower_pink"))


func _build_flow(a) -> void:
	for side in [-1.0, 1.0]:
		a.add_flow_anchor("BackyardSpawnExit", Vector3(0, 0.35 * D, side * 10.0 * D), "spawn_exit", "center")
		a.add_flow_anchor("HoseFlank", Vector3(-27 * GU, 0.35 * D, side * 19 * GU), "flank_route", "left")
		a.add_flow_anchor("SprinklerFlank", Vector3(27 * GU, 0.35 * D, side * 19 * GU), "flank_route", "right")
		a.add_flow_anchor("LeftPicnicApproach", Vector3(-5 * GU, 1.1 * D, side * 9 * GU), "attack_route", "left")
		a.add_flow_anchor("RightPicnicApproach", Vector3(5 * GU, 1.1 * D, side * 9 * GU), "attack_route", "right")
	a.add_flow_anchor("PicnicContest", Vector3(0, 1.1 * D, 0), "center_contest", "center")


func _add_deck_boards(a, parent: Node3D, grid: Vector2, size_gu: Vector2, surface_d: float, accent: Material) -> void:
	var center := _world(grid.x, grid.y, surface_d)
	for x in range(int(-size_gu.x * 0.5) + 1, int(size_gu.x * 0.5)):
		a.add_box("DeckBoardSeam", center + Vector3(float(x) * GU, 0.025 * D, 0), Vector3(0.045 * D, 0.03 * D, size_gu.y * GU * 0.92), accent if posmod(x, 4) == 0 else a.mat("backyard_wood_dark"), false, Vector3.ZERO, parent)
	for side in [-1.0, 1.0]:
		a.add_box("DeckEdgeTrim", center + Vector3(side * size_gu.x * GU * 0.49, 0.08 * D, 0), Vector3(0.22 * D, 0.20 * D, size_gu.y * GU), a.mat("backyard_wood_light"), false, Vector3.ZERO, parent)


func _build_table_settings(a, parent: Node3D, table_top_y: float) -> void:
	for x in [-2.3, 0.0, 2.3]:
		for z in [-1.15, 1.15]:
			a.add_cylinder("PicnicPlate", Vector3(x * GU, table_top_y + 0.10 * D, z * GU), 0.38 * GU, 0.08 * D, a.mat("backyard_cream"), false, Vector3.ZERO, parent)
	for x in [-3.0, 3.0]:
		a.add_cylinder("PicnicCup", Vector3(x * GU, table_top_y + 0.28 * D, 0), 0.16 * GU, 0.45 * D, a.mat("backyard_blue"), false, Vector3.ZERO, parent)


func _add_planter_pot(a, parent: Node3D, position: Vector3, flower_material: Material) -> void:
	a.add_cylinder("TerracottaPot", position + Vector3.UP * 0.42 * D, 0.42 * D, 0.84 * D, a.mat("backyard_terracotta"), false, Vector3.ZERO, parent)
	a.add_sphere("PotFlowers", position + Vector3.UP * 1.02 * D, 0.52 * D, flower_material, false, parent)


func _add_flower_cluster(a, position: Vector3, seed_value: int) -> void:
	for index in range(5):
		var angle := float(index) * 2.399 + float(seed_value) * 0.17
		var radius := 0.18 * D + float(index % 2) * 0.15 * D
		var material: Material = [a.mat("backyard_flower_red"), a.mat("backyard_flower_yellow"), a.mat("backyard_flower_pink")][posmod(seed_value + index, 3)]
		a.add_sphere("BorderFlower", position + Vector3(cos(angle) * radius, float(index % 3) * 0.08 * D, sin(angle) * radius), 0.16 * D, material, false)


func _mark(node: Node, kind: String, grid: Vector2, size_gu := Vector3.ZERO, extra: Dictionary = {}) -> Node:
	if node == null:
		return node
	node.set_meta("backyard_kind", kind)
	node.set_meta("gu_position", grid)
	node.set_meta("gu_size", size_gu)
	for key in extra:
		node.set_meta(key, extra[key])
	return node


func _world(grid_x: float, grid_y: float, height_d: float) -> Vector3:
	return Vector3((grid_x - 42.0) * GU, height_d * D, (32.0 - grid_y) * GU)
