extends RefCounted

const D := 5.776
const GU := 1.444
const GEOMETRY := preload("res://scripts/environment/toybox_blueprint_geometry.gd")
const TRAMPOLINE := preload("res://scripts/interactables/toybox_trampoline.gd")
const BOOST_PAD := preload("res://scripts/interactables/toybox_boost_pad.gd")
const WALL_BUMPER := preload("res://scripts/interactables/toybox_wall_bumper.gd")
const BREAKABLE_BOX := preload("res://scripts/interactables/toybox_breakable_box.gd")

const BEAM_SPECS := [
	[Vector2(32, 25), Vector3(12, 3, 2.5)], [Vector2(32, 103), Vector3(12, 3, 2.5)],
	[Vector2(24, 64), Vector3(2.5, 3, 14)], [Vector2(40, 64), Vector3(2.5, 3, 14)],
]
const WEDGE_POSITIONS := [Vector2(25, 27), Vector2(39, 27), Vector2(25, 88), Vector2(39, 88)]
const RAMP_POSITIONS := [Vector2(18, 26), Vector2(46, 26), Vector2(18, 89), Vector2(46, 89)]
const COVER_POSITIONS := [Vector2(13, 38), Vector2(51, 38), Vector2(13, 84), Vector2(51, 84)]
const BOOST_POSITIONS := [Vector2(11, 10), Vector2(53, 10), Vector2(11, 116), Vector2(53, 116)]
const BOX_POSITIONS := [Vector2(17, 10), Vector2(47, 10), Vector2(17, 116), Vector2(47, 116)]
const BUMPER_POSITIONS := [Vector2(2, 39), Vector2(62, 39), Vector2(2, 88), Vector2(62, 88)]
# Level-design additions over the blueprint: every drawn piece is lower than a
# blob, so the wall shelves supply high ground and the block stacks supply cover.
const SHELF_POSITIONS := [Vector2(5.5, 64), Vector2(58.5, 64)]
const SHELF_RAMP_POSITIONS := [Vector2(5.5, 51.5), Vector2(58.5, 51.5), Vector2(5.5, 76.5), Vector2(58.5, 76.5)]
const BLOCK_STACK_POSITIONS := [Vector2(30.4, 44), Vector2(33.6, 84)]


func build(a) -> Dictionary:
	_build_foam_floor(a)
	_build_spawns(a)
	_build_trampoline(a)
	_build_beams(a)
	_build_wedges(a)
	_build_ramps(a)
	_build_covers(a)
	_build_wall_shelves(a)
	_build_block_stacks(a)
	_build_boost_pads(a)
	_build_breakable_boxes(a)
	_build_wall_bumpers(a)
	_build_flow(a)
	return {
		"identity": "Literal oversized foam-play-mat Toybox from the supplied 64 x 128 GU blueprint",
		"landmark": "Orange Center Trampoline",
		"routes": ["blue spawn direct route", "red spawn direct route", "upper-left ramp route", "upper-right ramp route", "lower-left wall route", "lower-right wall route", "west toy shelf perch", "east toy shelf perch"],
		"interactables": ["center momentum trampoline", "four directional boost pads", "four powered wall bumper panels", "four respawning breakable toy boxes"],
		"prop_families": ["interlocking foam tiles", "padded perimeter blocks", "plastic ramps and wedges", "purple balance beams", "simple wooden toy boxes", "wall-mounted toy shelves", "stacked alphabet blocks"],
		"flow_plan": [
			"Direct: spawn to center lane to trampoline to opponent",
			"Ramp: spawn boost to main ramp to wedge to center",
			"Wall: ramp to wall bumper to center beam to opponent",
			"High: foam wedge to toy shelf, then dive onto the trampoline",
		],
		"combat_spaces": [
			"Trampoline and four beams form the readable central fight",
			"Low blue covers support quick recovery without hiding players",
			"Breakable boxes briefly shape spawn-side routes without permanent camping",
			"Alphabet block stacks are the only pieces taller than a blob: they split the center lane and hide each spawn from the other",
			"The toy shelves are the high ground over the beams; holding one trades the wall bumper lane for a view of the trampoline",
		],
		"blueprint": {
			"footprint_gu": Vector2(64, 128), "interior_gu": Vector2(58, 118),
			"gu_scale_d": 0.25, "unit_scale": GU, "wall_height_gu": 10.0,
			"roof_height_gu": 18.0, "floor_thickness_gu": 1.0,
			"spawn_centers_gu": [Vector2(32, 5), Vector2(32, 123)],
			"trampoline_center_gu": Vector2(32, 64), "beam_specs": BEAM_SPECS,
			"wedge_centers_gu": WEDGE_POSITIONS, "ramp_centers_gu": RAMP_POSITIONS,
			"cover_centers_gu": COVER_POSITIONS, "boost_centers_gu": BOOST_POSITIONS,
			"box_centers_gu": BOX_POSITIONS, "wall_bumper_centers_gu": BUMPER_POSITIONS,
			"shelf_centers_gu": SHELF_POSITIONS, "shelf_ramp_centers_gu": SHELF_RAMP_POSITIONS,
			"block_stack_centers_gu": BLOCK_STACK_POSITIONS,
		},
	}


func _build_foam_floor(a) -> void:
	var palette := [a.mat("toybox_red"), a.mat("toybox_blue"), a.mat("toybox_yellow"), a.mat("toybox_green"), a.mat("toybox_orange"), a.mat("toybox_purple")]
	for row in range(16):
		for column in range(8):
			var grid := Vector2(4 + column * 8, 4 + row * 8)
			var material: Material = palette[posmod(column + row * 2, palette.size())]
			var tile: MeshInstance3D = a.add_box("FoamPuzzleTile", _world(grid.x, grid.y, 0.04), Vector3(7.88 * GU, 0.08 * GU, 7.88 * GU), material, false)
			_mark(tile, "foam_tile", grid, Vector3(8, 0.08, 8), {"collision": "continuous_floor_only"})
			# Interlocking tabs are shallow visual overlays; they never fragment floor collision.
			if column < 7:
				a.add_cylinder("PuzzleTabX", _world(grid.x + 4, grid.y + (1.1 if row % 2 == 0 else -1.1), 0.095), 0.62 * GU, 0.035 * GU, material, false)
			if row < 15:
				a.add_cylinder("PuzzleTabZ", _world(grid.x + (1.1 if column % 2 == 0 else -1.1), grid.y + 4, 0.095), 0.62 * GU, 0.035 * GU, material, false)


func _build_spawns(a) -> void:
	for spec in [[Vector2(32, 5), true], [Vector2(32, 123), false]]:
		var grid := spec[0] as Vector2
		var is_blue := bool(spec[1])
		var toward_center := -Vector3(_world(grid.x, grid.y, 0).x, 0, _world(grid.x, grid.y, 0).z).normalized()
		var platform_yaw := atan2(toward_center.x, toward_center.z)
		var root := GEOMETRY.add_semicircle_platform(a, "BlueSpawnPlatform" if is_blue else "RedSpawnPlatform", _world(grid.x, grid.y, 3.0), 6.0 * GU, 1.0 * GU, platform_yaw, a.mat("toybox_blue") if is_blue else a.mat("toybox_red"), a.surface("normal"))
		_mark(root, "spawn_platform", grid, Vector3(12, 1, 8), {"team": "blue" if is_blue else "red", "surface_height_gu": 4.0})
		var support_key := "toybox_spawn_%s" % ("blue" if is_blue else "red")
		root.add_to_group("supported_elevated_structure")
		root.set_meta("support_key", support_key)
		var basis := Basis(Vector3.UP, platform_yaw)
		var plinth: MeshInstance3D = a.add_box(
			"SpawnGroundPlinth",
			_world(grid.x, grid.y, 1.25),
			Vector3(9.0 * GU, 2.5 * GU, 5.0 * GU),
			a.mat("toybox_blue_dark") if is_blue else a.mat("toybox_red_dark"),
			true,
			Vector3(0, platform_yaw, 0),
			null,
			a.surface("normal")
		)
		plinth.add_to_group("structural_support")
		plinth.set_meta("support_key", support_key)
		for side in [-1.0, 1.0]:
			var local := Vector3(side * 5.2 * GU, 3.5 * GU, -1.2 * GU)
			a.add_box("SpawnSideSupport", _world(grid.x, grid.y, 0) + basis * local, Vector3(1.7 * GU, 1.0 * GU, 5.0 * GU), a.mat("toybox_blue_dark") if is_blue else a.mat("toybox_red_dark"), true, Vector3(0, platform_yaw, 0), null, a.surface("normal"))
		var outward := -toward_center
		var ramp_center := _world(grid.x, grid.y, 0) + toward_center * 6.5 * GU
		var ramp_yaw := atan2(outward.x, outward.z)
		var ramp := GEOMETRY.add_curved_ramp(a, "SpawnDescent", ramp_center, 6.0 * GU, 5.0 * GU, 4.0 * GU, 0.0, ramp_yaw, a.mat("toybox_blue") if is_blue else a.mat("toybox_red"), a.mat("toybox_light_blue") if is_blue else a.mat("toybox_pink"), a.surface("normal"))
		_mark(ramp, "spawn_descent", grid + Vector2(0, 6 if is_blue else -6), Vector3(6, 4, 5))


func _build_trampoline(a) -> void:
	var trampoline: Area3D = TRAMPOLINE.new()
	trampoline.name = "CenterTrampoline"
	trampoline.position = _world(32, 64, 0)
	trampoline.set("outer_radius", 6.0 * GU)
	trampoline.set("bounce_radius", 4.5 * GU)
	trampoline.set("surface_height", 2.0 * GU)
	a.add_child(trampoline)
	_mark(trampoline, "center_trampoline", Vector2(32, 64), Vector3(12, 2.5, 12), {"horizontal_multiplier": 1.08, "compression_gu": 0.5})
	trampoline.add_to_group("map_landmark")
	trampoline.add_to_group("intentional_interactable")
	trampoline.set_meta("duel_purpose", "Strong vertical center launch that preserves the direct route")
	trampoline.set_meta("leads_to_center", true)


func _build_beams(a) -> void:
	for spec in BEAM_SPECS:
		var grid := spec[0] as Vector2
		var size_gu := spec[1] as Vector3
		var beam := GEOMETRY.add_beveled_box(a, "PurpleBalanceBeam", _world(grid.x, grid.y, 0), Vector3(size_gu.x * GU, size_gu.y * GU, size_gu.z * GU), 0.55 * GU, a.mat("toybox_purple"), a.surface("normal"))
		_mark(beam, "balance_beam", grid, size_gu, {"surface_height_gu": 3.0})
		beam.add_to_group("duel_cover")


func _build_wedges(a) -> void:
	for grid in WEDGE_POSITIONS:
		var world := _world(grid.x, grid.y, 0)
		var outward := Vector3(world.x, 0, world.z).normalized()
		var yaw := atan2(outward.x, outward.z)
		var wedge := GEOMETRY.add_wedge(a, "GreenWedgeBlock", world, 6.0 * GU, 7.0 * GU, 0.5 * GU, 5.0 * GU, yaw, a.mat("toybox_green"), a.mat("toybox_green_light"), a.surface("ice"))
		_mark(wedge, "wedge_block", grid, Vector3(6, 5, 7), {"points_toward_center": true, "scripted_force": false})


func _build_ramps(a) -> void:
	for index in range(RAMP_POSITIONS.size()):
		var grid: Vector2 = RAMP_POSITIONS[index]
		var world := _world(grid.x, grid.y, 0)
		var toward_center := -Vector3(world.x, 0, world.z).normalized()
		var yaw := atan2(toward_center.x, toward_center.z)
		var body_material: Material = a.mat("toybox_yellow") if index in [0, 3] else a.mat("toybox_orange")
		var ramp := GEOMETRY.add_curved_ramp(a, "PlasticLaunchRamp", world, 6.0 * GU, 12.0 * GU, 4.3 * GU, 0.7 * GU, yaw, body_material, a.mat("toybox_yellow_light"), a.surface("ice"))
		_mark(ramp, "launch_ramp", grid, Vector3(6, 5, 12), {"yaw_to_center": yaw, "lip_rise_gu": 0.7, "smooth_convex": true})
		_add_ramp_arrows(a, ramp, 6.0 * GU, 12.0 * GU, 5.0 * GU)


func _build_covers(a) -> void:
	for grid in COVER_POSITIONS:
		var cover := GEOMETRY.add_beveled_box(a, "BlueLowCover", _world(grid.x, grid.y, 0), Vector3(5.0 * GU, 3.5 * GU, 4.0 * GU), 0.48 * GU, a.mat("toybox_blue"), a.surface("bounce"))
		_mark(cover, "low_cover", grid, Vector3(5, 3.5, 4))
		cover.add_to_group("duel_cover")


func _build_wall_shelves(a) -> void:
	# Every blueprint piece is lower than a blob, so the two wall-mounted toy
	# shelves are the map's real high ground: a 6 GU deck hanging over the outer
	# edge of each side balance beam, reached by a foam wedge at either end and
	# left by a dive toward the trampoline. Legs run to the floor so the shelf
	# reads as furniture rather than a floating slab.
	var palette := [a.mat("toybox_yellow_light"), a.mat("toybox_pink"), a.mat("toybox_light_blue")]
	for index in range(SHELF_POSITIONS.size()):
		var grid: Vector2 = SHELF_POSITIONS[index]
		var left_side := grid.x < 32.0
		var inward := 1.0 if left_side else -1.0
		var support_key := "toybox_shelf_%s" % ("west" if left_side else "east")
		var deck := GEOMETRY.add_beveled_box(a, "WallToyShelf", _world(grid.x, grid.y, 5.0), Vector3(5.9 * GU, 1.0 * GU, 16.0 * GU), 0.45 * GU, a.mat("toybox_wood"), a.surface("normal"))
		_mark(deck, "wall_shelf", grid, Vector3(5.9, 1, 16), {"surface_height_gu": 6.0, "lane": "left" if left_side else "right"})
		deck.add_to_group("duel_cover")
		deck.add_to_group("supported_elevated_structure")
		deck.set_meta("support_key", support_key)
		a.mark_elevated_route(deck, _world(grid.x, grid.y, 6.0))
		for z_offset in [-6.5, 6.5]:
			a.add_ground_support("ShelfLeg", _world(grid.x - inward * 2.0, grid.y + z_offset, 2.5), Vector3(1.2 * GU, 5.0 * GU, 1.2 * GU), a.mat("toybox_tan"), support_key, a.surface("normal"))
		# A solid back rail against the padded wall stops a blob wedging into the
		# wall seam; the front lip and face panels are flush colour, not fake rails.
		a.add_box("ShelfBackRail", _world(grid.x - inward * 2.75, grid.y, 6.5), Vector3(0.3 * GU, 1.0 * GU, 15.4 * GU), a.mat("toybox_tan"), true, Vector3.ZERO, null, a.surface("bounce"))
		a.add_box("ShelfFrontLip", _world(grid.x + inward * 2.7, grid.y, 6.02), Vector3(0.35 * GU, 0.04 * GU, 15.2 * GU), a.mat("toybox_yellow_light"), false)
		for panel_index in range(3):
			a.add_box("ShelfFacePanel", _world(grid.x + inward * 2.96, grid.y - 5.0 + 5.0 * float(panel_index), 5.5), Vector3(0.06 * GU, 0.6 * GU, 3.2 * GU), palette[(panel_index + index) % palette.size()], false)
		a.add_flow_anchor("ToyboxShelfPerch", _world(grid.x, grid.y, 6.0), "flank_route", "left" if left_side else "right")
	for index in range(SHELF_RAMP_POSITIONS.size()):
		var grid: Vector2 = SHELF_RAMP_POSITIONS[index]
		# The wedge rises along local +Z, so it must point at the shelf: world -Z
		# for the north ramps (smaller grid y) and world +Z for the south ones.
		var yaw := PI if grid.y < 64.0 else 0.0
		var body_material: Material = a.mat("toybox_green") if index % 2 == 0 else a.mat("toybox_orange")
		var wedge := GEOMETRY.add_wedge(a, "ShelfFoamRamp", _world(grid.x, grid.y, 0), 5.0 * GU, 9.0 * GU, 0.4 * GU, 6.0 * GU, yaw, body_material, a.mat("toybox_yellow_light"), a.surface("normal"))
		_mark(wedge, "shelf_ramp", grid, Vector3(5, 6, 9), {"feeds_shelf": true, "yaw": yaw})


func _build_block_stacks(a) -> void:
	# Two stacked alphabet blocks sit just off the centre line, mirrored through
	# the trampoline. They break the spawn-to-spawn sightline down the middle,
	# split the direct lane into two sides, and their top is a perch taller than
	# any blueprint piece.
	var faces := [a.mat("toybox_yellow_light"), a.mat("toybox_pink"), a.mat("toybox_light_blue"), a.mat("toybox_green_light")]
	for index in range(BLOCK_STACK_POSITIONS.size()):
		var grid: Vector2 = BLOCK_STACK_POSITIONS[index]
		var lower_size := 4.6
		var lower := GEOMETRY.add_beveled_box(a, "AlphabetBlockLower", _world(grid.x, grid.y, 0), Vector3.ONE * lower_size * GU, 0.42 * GU, a.mat("toybox_red") if index == 0 else a.mat("toybox_blue"), a.surface("bounce"))
		_mark(lower, "block_stack", grid, Vector3.ONE * lower_size, {"tier": 0})
		lower.add_to_group("duel_cover")
		_add_block_face_insets(a, _world(grid.x, grid.y, lower_size * 0.5), lower_size, faces, index)
		var upper_size := 4.2
		var upper_grid := grid + Vector2(0.4 if index == 0 else -0.4, 0.0)
		var upper := GEOMETRY.add_beveled_box(a, "AlphabetBlockUpper", _world(upper_grid.x, upper_grid.y, lower_size), Vector3.ONE * upper_size * GU, 0.4 * GU, a.mat("toybox_yellow") if index == 0 else a.mat("toybox_green"), a.surface("bounce"))
		_mark(upper, "block_stack", upper_grid, Vector3.ONE * upper_size, {"tier": 1})
		upper.add_to_group("duel_cover")
		a.mark_elevated_route(upper, _world(upper_grid.x, upper_grid.y, lower_size + upper_size))
		_add_block_face_insets(a, _world(upper_grid.x, upper_grid.y, lower_size + upper_size * 0.5), upper_size, faces, index + 2)


func _add_block_face_insets(a, center: Vector3, size_gu: float, faces: Array, seed_value: int) -> void:
	var inset := (size_gu * 0.5 - 0.02) * GU
	var panel := size_gu * 0.5 * GU
	for face_index in range(4):
		var material: Material = faces[(face_index + seed_value) % faces.size()]
		match face_index:
			0:
				a.add_box("BlockFaceInset", center + Vector3(inset, 0, 0), Vector3(0.08 * GU, panel, panel), material, false)
			1:
				a.add_box("BlockFaceInset", center - Vector3(inset, 0, 0), Vector3(0.08 * GU, panel, panel), material, false)
			2:
				a.add_box("BlockFaceInset", center + Vector3(0, 0, inset), Vector3(panel, panel, 0.08 * GU), material, false)
			3:
				a.add_box("BlockFaceInset", center - Vector3(0, 0, inset), Vector3(panel, panel, 0.08 * GU), material, false)


func _build_boost_pads(a) -> void:
	for grid in BOOST_POSITIONS:
		var world := _world(grid.x, grid.y, 0)
		var toward_center := -Vector3(world.x, 0, world.z).normalized()
		var pad: Area3D = BOOST_PAD.new()
		pad.name = "ToyboxBoostPad"
		pad.position = world
		pad.set("pad_radius", 1.5 * GU)
		pad.set("pad_height", 0.3 * GU)
		pad.set("local_direction", (toward_center + Vector3.UP * 0.28).normalized())
		pad.set("impulse_strength", 46.0)
		pad.set("cooldown", 0.5)
		a.add_child(pad)
		_mark(pad, "boost_pad", grid, Vector3(3, 0.3, 3), {"launches_inward": true, "cooldown": 0.5})
		pad.add_to_group("intentional_interactable")
		pad.set_meta("duel_purpose", "Medium diagonal entry into a Toybox side route")
		pad.set_meta("leads_to_center", true)


func _build_breakable_boxes(a) -> void:
	for grid in BOX_POSITIONS:
		var box: Area3D = BREAKABLE_BOX.new()
		box.name = "BreakableToyBox"
		box.position = _world(grid.x, grid.y, 0)
		box.set("box_size", Vector3.ONE * 4.0 * GU)
		a.add_child(box)
		_mark(box, "breakable_box", grid, Vector3(4, 4, 4), {"piece_count": 4, "piece_lifetime": 2.0, "respawn_delay": 10.0})
		box.add_to_group("intentional_interactable")
		box.set_meta("duel_purpose", "Temporary solid spawn-side blocker that opens after a fast hit")
		box.set_meta("leads_to_center", false)


func _build_wall_bumpers(a) -> void:
	for grid in BUMPER_POSITIONS:
		var left_side: bool = grid.x < 32.0
		var bumper: Area3D = WALL_BUMPER.new()
		bumper.name = "ToyboxWallBumper"
		bumper.position = _world(grid.x, grid.y, 5.0)
		# Blueprint coordinates identify the wall bay; the pad itself protrudes from
		# that bay into play so its blue face and white chevrons remain visible.
		bumper.position.x = (-29.72 if left_side else 29.72) * GU
		bumper.set("panel_size", Vector3(0.5 * GU, 5.0 * GU, 8.0 * GU))
		bumper.set("inward", Vector3.RIGHT if left_side else Vector3.LEFT)
		a.add_child(bumper)
		_mark(bumper, "wall_bumper", grid, Vector3(0.5, 5, 8), {"horizontal_multiplier": 1.10, "preserves_vertical": true})
		bumper.add_to_group("intentional_interactable")
		bumper.set_meta("duel_purpose", "Powered padded wall redirect back into the center lane")
		bumper.set_meta("leads_to_center", true)


func _build_flow(a) -> void:
	for side in [-1.0, 1.0]:
		a.add_flow_anchor("ToyboxSpawnExit", Vector3(0, 0.5 * GU, side * 54 * GU), "spawn_exit", "center")
		a.add_flow_anchor("ToyboxDirect", Vector3(0, 0.5 * GU, side * 35 * GU), "attack_route", "center")
		a.add_flow_anchor("ToyboxLeftRamp", Vector3(-14 * GU, 0.5 * GU, side * 38 * GU), "flank_route", "left")
		a.add_flow_anchor("ToyboxRightRamp", Vector3(14 * GU, 0.5 * GU, side * 38 * GU), "flank_route", "right")
		a.add_flow_anchor("ToyboxLeftWall", Vector3(-25 * GU, 0.5 * GU, side * 23 * GU), "attack_route", "left")
		a.add_flow_anchor("ToyboxRightWall", Vector3(25 * GU, 0.5 * GU, side * 23 * GU), "attack_route", "right")
	a.add_flow_anchor("ToyboxTrampolineContest", Vector3(0, 2 * GU, 0), "center_contest", "center")


func _add_ramp_arrows(a, ramp: Node3D, width: float, length: float, height: float) -> void:
	for arrow_index in [-1.0, 1.0]:
		var z: float = arrow_index * length * 0.18
		var t: float = z / length + 0.5
		var y: float = height * t * t * (3.0 - 2.0 * t) + 0.16
		for side in [-1.0, 1.0]:
			var bar := MeshInstance3D.new()
			bar.name = "RampDirectionArrow"
			var mesh := BoxMesh.new()
			mesh.size = Vector3(width * 0.10, 0.10, length * 0.26)
			mesh.material = a.mat("toybox_yellow_light")
			bar.mesh = mesh
			bar.position = Vector3(side * width * 0.15, y, z)
			bar.rotation.y = side * 0.58
			bar.rotation.x = -atan2(height, length)
			ramp.add_child(bar)


func _mark(node: Node, kind: String, grid: Vector2, size_gu := Vector3.ZERO, extra: Dictionary = {}) -> Node:
	if node == null:
		return node
	node.set_meta("toybox_kind", kind)
	node.set_meta("gu_position", grid)
	node.set_meta("gu_size", size_gu)
	for key in extra:
		node.set_meta(key, extra[key])
	return node


func _world(grid_x: float, grid_y: float, height_gu: float) -> Vector3:
	return Vector3((grid_x - 32.0) * GU, height_gu * GU, (64.0 - grid_y) * GU)
