extends RefCounted

const GU := 11.55 # Literal blueprint scale: two blob diameters.
const GEOMETRY := preload("res://scripts/environment/neon_arcade_geometry.gd")


func build(a) -> Dictionary:
	_build_floor(a)
	_build_corner_towers(a)
	_build_ramps(a)
	_build_low_covers(a)
	_build_boost_pads(a)
	_build_center_bumper(a)
	_build_wall_facades(a)
	_build_wall_stations(a)
	_build_laser_gates(a)
	return {
		"identity": "Literal 3D reconstruction of the supplied Neon Arcade blueprint.",
		"landmark": "Concentric magenta center bumper at grid (9,9).",
		"routes": ["four clear diagonal corner ramps", "central bumper", "six low-cover lanes", "four inward boost pads", "stacked perimeter ledges", "timed wall gates"],
		"interactables": ["center bumper", "four boost pads", "sixteen stacked wall bumper pads", "four laser gates"],
		"prop_families": ["chamfered spawn towers", "purple low covers", "amber wall pads", "cyan/pink wall ledges"],
		"flow_plan": ["Ramps rise from the floor to the four corner towers.", "The four green pads point directly into the center bumper.", "The perimeter alternates ledges and pads at the exact cross-section heights shown in the blueprint."],
		"combat_spaces": ["Ten separated cover segments create readable central sightlines.", "The central disc remains the only circular obstacle.", "The four side gates are push zones rather than elimination hazards."],
		"blueprint": {
			"unit_scale": GU,
			"footprint_gu": Vector2(18, 18), "interior_gu": Vector2(16, 16),
			"wall_height_gu": 6.0, "roof_height_gu": 6.2, "floor_thickness_gu": 0.25,
			"source": "codex-clipboard-2e8129ab-5336-4843-948d-8033bac13b0e.png",
		},
	}


func _world(grid_x: float, grid_y: float, height := 0.0) -> Vector3:
	return Vector3((grid_x - 9.0) * GU, height, (grid_y - 9.0) * GU)


func _build_floor(a) -> void:
	# The reference has dark tiled metal with almost-flush circuit channels, not bright full-span stripes.
	var grid_material: Material = a.mat("blue_gray")
	for index in range(1, 18):
		var offset := (float(index) - 9.0) * GU
		a.add_box("FloorGridX", Vector3(offset, 0.012 * GU, 0), Vector3(0.022 * GU, 0.018 * GU, 16.0 * GU), grid_material, false)
		a.add_box("FloorGridY", Vector3(0, 0.012 * GU, offset), Vector3(16.0 * GU, 0.018 * GU, 0.022 * GU), grid_material, false)
	var traces := [
		[Vector2(3.0, 2.4), Vector2(3.0, 5.2), "neon_pink"], [Vector2(15.0, 2.4), Vector2(15.0, 5.2), "neon_cyan"],
		[Vector2(3.0, 12.8), Vector2(3.0, 15.6), "neon_cyan"], [Vector2(15.0, 12.8), Vector2(15.0, 15.6), "neon_pink"],
	]
	for trace in traces:
		var start := trace[0] as Vector2
		var end := trace[1] as Vector2
		var center := (start + end) * 0.5
		a.add_box("CircuitTrace", _world(center.x, center.y, 0.022 * GU), Vector3(0.06 * GU, 0.026 * GU, absf(end.y - start.y) * GU), a.mat(trace[2] as String), false)
	for position in [Vector2(6, 6), Vector2(12, 6), Vector2(6, 12), Vector2(12, 12)]:
		a.add_box("CircuitNode", _world(position.x, position.y, 0.026 * GU), Vector3(0.86 * GU, 0.028 * GU, 0.12 * GU), a.mat("white"), false, Vector3(0, PI * 0.25, 0))


func _build_corner_towers(a) -> void:
	var towers := [Vector2(2, 2), Vector2(16, 2), Vector2(2, 16), Vector2(16, 16)]
	for index in range(towers.size()):
		var grid := towers[index] as Vector2
		var pink := index == 0 or index == 3
		var accent: Material = a.mat("neon_pink") if pink else a.mat("neon_cyan")
		# The solid deck is the image's Z=3 mid-platform, so the 4-GU ramp connects without an invisible step.
		# Four solid crown struts complete the Z=6 tower silhouette while leaving the playable deck below the roof.
		var tower := GEOMETRY.add_chamfered_platform(a, "SpawnTower", _world(grid.x, grid.y), 3.0 * GU, 3.0 * GU, a.mat("dark_metal"), a.surface("normal"), accent)
		a.mark_neon_element(tower, "spawn_platform", grid, Vector3(3, 3, 3), {"image_team_color": "pink" if pink else "cyan", "top_silhouette_gu": 6.0})
		var toward_center := -_world(grid.x, grid.y).normalized()
		for offset in [Vector2(-1.12, -1.12), Vector2(1.12, -1.12), Vector2(-1.12, 1.12), Vector2(1.12, 1.12)]:
			# Keep the tall crown around the outside/sides of the pad, but leave the inner
			# ramp/launch lane open. The image reads this as an open elevated platform, not
			# a cage with a column through the player's camera.
			var offset_direction := Vector3(offset.x, 0.0, offset.y).normalized()
			if offset_direction.dot(toward_center) > 0.65:
				continue
			a.add_box("SpawnTowerStrut", _world(grid.x + offset.x, grid.y + offset.y, 4.5 * GU), Vector3(0.24 * GU, 3.0 * GU, 0.24 * GU), a.mat("dark_metal"), true)
		a.add_cylinder("SpawnCore", _world(grid.x, grid.y, 3.06 * GU), 0.82 * GU, 0.08 * GU, accent, false)
		a.add_torus("SpawnCrown", _world(grid.x, grid.y, 5.73 * GU), 0.86 * GU, 1.12 * GU, accent, false)
		var label := "1" if pink else "2"
		a.add_label(_world(grid.x, grid.y, 3.2 * GU), label, Color(1.0, 0.28, 0.72) if pink else Color(0.16, 0.9, 1.0), 40)


func _build_ramps(a) -> void:
	var corners := [Vector2(2, 2), Vector2(16, 2), Vector2(2, 16), Vector2(16, 16)]
	for grid_value in corners:
		var grid := grid_value as Vector2
		var tower := _world(grid.x, grid.y)
		var outward := tower.normalized()
		var midpoint := tower + -outward * 3.0 * GU + Vector3.UP * 0.02
		# The prism rises along its local +Z axis, so +Z must point outward toward the tower.
		var yaw := atan2(outward.x, outward.z)
		var ramp := GEOMETRY.add_ramp_prism(a, "CornerRamp", midpoint, 3.0 * GU, 3.0 * GU, 3.0 * GU, yaw, a.mat("dark_metal"), a.surface("bounce"), a.mat("violet_trim"))
		var ramp_grid := grid + Vector2(-outward.x, -outward.z) * 3.0
		a.mark_neon_element(ramp, "corner_ramp", ramp_grid, Vector3(3, 3, 3), {"top_height_gu": 3.0})
		_mark_overlap_footprint(ramp, ramp_grid, Vector2(3.0, 3.0), yaw)
		for stripe in [0.25, 0.5, 0.75]:
			var stripe_position: Vector3 = midpoint + outward * ((stripe - 0.5) * 2.5 * GU) + Vector3.UP * (stripe * 3.0 * GU + 0.10 * GU)
			a.add_box("RampChevron", stripe_position, Vector3(1.45 * GU, 0.05 * GU, 0.18 * GU), a.mat("warm_light"), false, Vector3(0, yaw, 0))


func _build_low_covers(a) -> void:
	# Ten separated segments retain the blueprint's central lanes while removing the
	# four L clusters that physically crossed the corner ramps and boost-pad exits.
	for position in [Vector2(7.25, 3.55), Vector2(10.75, 3.55), Vector2(2.9, 6.65), Vector2(15.1, 6.65), Vector2(2.9, 11.0), Vector2(15.1, 11.0), Vector2(7.25, 14.45), Vector2(10.75, 14.45)]:
		_add_cover(a, "LowCover", position, Vector3(2.0 * GU, 1.5 * GU, 1.0 * GU), Vector3.ZERO)
	for spec in [[Vector2(3.35, 9.0), Vector3(0.45 * GU, 1.5 * GU, 2.1 * GU)], [Vector2(14.65, 9.0), Vector3(0.45 * GU, 1.5 * GU, 2.1 * GU)]]:
		_add_cover(a, "MidCover", spec[0] as Vector2, spec[1] as Vector3, Vector3.ZERO)


func _add_cover(a, prefix: String, grid: Vector2, size: Vector3, rotation_value: Vector3) -> void:
	var cover: MeshInstance3D = a.add_box(prefix, _world(grid.x, grid.y, size.y * 0.5), size, a.mat("purple"), true, rotation_value, null, a.surface("bounce"))
	a.add_box(prefix + "NeonTrim", _world(grid.x, grid.y, size.y + 0.035 * GU), Vector3(size.x + 0.12 * GU, 0.07 * GU, size.z + 0.12 * GU), a.mat("violet_trim"), false, rotation_value)
	a.mark_neon_element(cover, "low_cover", grid, Vector3(size.x / GU, 1.5, size.z / GU), {"top_height_gu": 1.5, "solid": true})
	_mark_overlap_footprint(cover, grid, Vector2(size.x / GU, size.z / GU), rotation_value.y)
	cover.add_to_group("duel_cover")
	cover.set_meta("flow_lane", "left" if grid.x < 9.0 else "right")
	cover.set_meta("cover_role", "blueprint low cover")


func _build_boost_pads(a) -> void:
	for grid in [Vector2(6, 6), Vector2(12, 6), Vector2(6, 12), Vector2(12, 12)]:
		var base: MeshInstance3D = a.add_box("BoostBase", _world(grid.x, grid.y, 0.08 * GU), Vector3(1.5 * GU, 0.16 * GU, 1.5 * GU), a.mat("dark_metal"), true)
		# Three nested square decks, a raised neon rim, and the chevron are the image's
		# actual boost-pad construction -- not a generic glowing disc.
		a.add_box("BoostInset", _world(grid.x, grid.y, 0.16 * GU), Vector3(1.34 * GU, 0.05 * GU, 1.34 * GU), a.mat("black"), false)
		a.add_box("BoostGlow", _world(grid.x, grid.y, 0.19 * GU), Vector3(1.15 * GU, 0.045 * GU, 1.15 * GU), a.mat("neon_lime"), false)
		for edge in [[Vector3(0, 0, 0.62 * GU), Vector3(1.28 * GU, 0.09 * GU, 0.08 * GU)], [Vector3(0, 0, -0.62 * GU), Vector3(1.28 * GU, 0.09 * GU, 0.08 * GU)], [Vector3(0.62 * GU, 0, 0), Vector3(0.08 * GU, 0.09 * GU, 1.28 * GU)], [Vector3(-0.62 * GU, 0, 0), Vector3(0.08 * GU, 0.09 * GU, 1.28 * GU)]]:
			a.add_box("BoostRim", _world(grid.x, grid.y, 0.24 * GU) + edge[0], edge[1], a.mat("warm_light"), false)
		var inward := -_world(grid.x, grid.y).normalized()
		var boost: Area3D = a.add_launch_pad(_world(grid.x, grid.y, 0.30 * GU), inward + Vector3.UP * 0.34, 56.0, Color(0.62, 0.96, 0.10))
		var disc := boost.get_node_or_null("VisualRoot/Disc") as MeshInstance3D
		if disc != null:
			var square := BoxMesh.new()
			square.size = Vector3(1.1 * GU, 0.05 * GU, 1.1 * GU)
			disc.mesh = square
		var ring := boost.get_node_or_null("VisualRoot/Ring") as MeshInstance3D
		if ring != null:
			ring.visible = false
		a.add_route_chevron("BoostChevron", _world(grid.x, grid.y, 0.245 * GU), inward, a.mat("white"), 1.25)
		_add_glow_light(a, _world(grid.x, grid.y, 0.42 * GU), Color(0.62, 0.96, 0.10), 2.4, 4.2 * GU)
		a.mark_neon_element(boost, "boost_pad", grid, Vector3(1.5, 0.2, 1.5), {"launch_strength": "strong_medium", "emission_rank": 2, "direction": inward})
		_mark_overlap_footprint(boost, grid, Vector2(1.5, 1.5), 0.0)
		a.mark_duel_interactable(boost, "Square image-positioned boost pad launches toward the center", true)
		a.mark_neon_element(base, "boost_pad_base", grid, Vector3(1.5, 0.16, 1.5), {"solid": true})


func _build_center_bumper(a) -> void:
	var landmark: Node3D = a.add_landmark_root("NeonCenterBumper")
	a.add_cylinder("CenterDisc", Vector3.UP * 0.12 * GU, 1.5 * GU, 0.24 * GU, a.mat("dark_metal"), true, Vector3.ZERO, landmark, a.surface("bounce"))
	a.add_cylinder("CenterRecess", Vector3.UP * 0.255 * GU, 1.25 * GU, 0.06 * GU, a.mat("black"), false, Vector3.ZERO, landmark)
	a.add_torus("CenterOuterRing", Vector3.UP * 0.27 * GU, 1.18 * GU, 1.48 * GU, a.mat("neon_pink"), false, Vector3.ZERO, landmark)
	a.add_torus("CenterInnerRing", Vector3.UP * 0.31 * GU, 0.60 * GU, 0.82 * GU, a.mat("neon_cyan"), false, Vector3.ZERO, landmark)
	a.add_cylinder("CenterHotCore", Vector3.UP * 0.34 * GU, 0.43 * GU, 0.08 * GU, a.mat("warm_light"), false, Vector3.ZERO, landmark)
	for angle in [0.0, PI * 0.5, PI, PI * 1.5]:
		var spoke := Vector3(cos(angle), 0, sin(angle)) * 1.0 * GU
		a.add_box("CenterSpoke", spoke + Vector3.UP * 0.325 * GU, Vector3(0.48 * GU, 0.06 * GU, 0.13 * GU), a.mat("violet_trim"), false, Vector3(0, -angle, 0), landmark)
	# The center bumper is a low, wide saucer in the side profile -- never a pillar.
	var bumper: Area3D = a.add_directional_bumper(Vector3.UP * 0.44 * GU, Vector3(1.45 * GU, 0.30 * GU, 1.45 * GU), 86.0, Color(1.0, 0.10, 0.62), Vector3.ZERO, 5.2, true)
	_add_glow_light(a, Vector3.UP * 0.48 * GU, Color(1.0, 0.10, 0.62), 3.6, 6.0 * GU)
	bumper.add_to_group("map_landmark")
	a.mark_neon_element(bumper, "center_bumper", Vector2(9, 9), Vector3(1.45, 0.30, 1.45), {"launch_strength": "consistent", "emission_rank": 1, "solid": true})
	a.mark_duel_interactable(bumper, "Circular radial center bumper redirects impact direction", false)


func _build_wall_facades(a) -> void:
	for index in range(6):
		var coordinate := 1.5 + float(index) * 3.0
		var north_material: Material = a.mat("neon_pink") if coordinate < 9.0 else a.mat("neon_cyan")
		var south_material: Material = a.mat("neon_cyan") if coordinate < 9.0 else a.mat("neon_pink")
		_add_wall_panel(a, _world(coordinate, 0.42, 3.0 * GU), Vector3(2.55 * GU, 5.75 * GU, 0.11 * GU), north_material, Vector3.BACK)
		_add_wall_panel(a, _world(coordinate, 17.58, 3.0 * GU), Vector3(2.55 * GU, 5.75 * GU, 0.11 * GU), south_material, Vector3.FORWARD)
		_add_wall_panel(a, _world(0.42, coordinate, 3.0 * GU), Vector3(0.11 * GU, 5.75 * GU, 2.55 * GU), a.mat("neon_pink"), Vector3.RIGHT)
		_add_wall_panel(a, _world(17.58, coordinate, 3.0 * GU), Vector3(0.11 * GU, 5.75 * GU, 2.55 * GU), a.mat("neon_cyan"), Vector3.LEFT)


func _add_wall_panel(a, position: Vector3, size: Vector3, trim: Material, inward: Vector3) -> void:
	# Literal wall cross-section: black outer armor, a recessed dark-metal bay, protruding
	# ribs, then thin emissive rails.  The existing shell behind it supplies the continuous
	# solid collision; these pieces are its visible interior architecture.
	var along := Vector3.RIGHT if absf(inward.z) > 0.5 else Vector3.FORWARD
	var span := size.x if absf(inward.z) > 0.5 else size.z
	var depth_size := Vector3(span, size.y, 0.18 * GU) if absf(inward.z) > 0.5 else Vector3(0.18 * GU, size.y, span)
	var inset_size := Vector3(span * 0.76, 3.85 * GU, 0.14 * GU) if absf(inward.z) > 0.5 else Vector3(0.14 * GU, 3.85 * GU, span * 0.76)
	var rib_size := Vector3(0.16 * GU, 4.65 * GU, 0.18 * GU) if absf(inward.z) > 0.5 else Vector3(0.18 * GU, 4.65 * GU, 0.16 * GU)
	var rail_size := Vector3(span * 0.80, 0.075 * GU, 0.11 * GU) if absf(inward.z) > 0.5 else Vector3(0.11 * GU, 0.075 * GU, span * 0.80)
	# The armor is the rear hull.  The dark bay is physically and visually forward of it,
	# while the ribs project farther again; this is an actual recess between steps.
	GEOMETRY.add_chamfered_wall_module(a, "WallPanelArmor", position - inward * 0.12 * GU, span, size.y, depth_size.z if absf(inward.z) > 0.5 else depth_size.x, inward, a.mat("black"), a.surface("normal"))
	a.add_box("WallPanelRecess", position - inward * 0.01 * GU, inset_size, a.mat("dark_metal"), true, Vector3.ZERO, null, a.surface("normal"))
	for side in [-1.0, 1.0]:
		var rib_position: Vector3 = position + inward * 0.14 * GU + along * side * span * 0.36
		a.add_box("WallPanelRib", rib_position, rib_size, a.mat("blue_gray"), true, Vector3.ZERO, null, a.surface("normal"))
		a.add_box("WallPanelVerticalLED", rib_position + inward * 0.055 * GU, rib_size * Vector3(0.32, 0.72, 0.62), trim, false)
	for height in [-2.34, -0.38, 1.58, 2.55]:
		a.add_box("WallPanelLED", position + inward * 0.18 * GU + Vector3.UP * height * GU, rail_size, trim if height != -0.38 else a.mat("violet_trim"), false)
	# Small stepped bracket makes the alternating protrusion visible even between stations.
	var bracket_size := Vector3(span * 0.32, 0.34 * GU, 0.38 * GU) if absf(inward.z) > 0.5 else Vector3(0.38 * GU, 0.34 * GU, span * 0.32)
	a.add_box("WallPanelBracket", position + inward * 0.30 * GU + Vector3.UP * 0.55 * GU, bracket_size, a.mat("dark_metal"), true, Vector3.ZERO, null, a.surface("normal"))


func _build_wall_stations(a) -> void:
	for grid in [Vector2(5, 1), Vector2(13, 1)]:
		_add_wall_station(a, grid, Vector3(0, 0, 1), false, a.mat("neon_pink") if grid.x < 9.0 else a.mat("neon_cyan"))
	for grid in [Vector2(5, 17), Vector2(13, 17)]:
		_add_wall_station(a, grid, Vector3(0, 0, -1), false, a.mat("neon_cyan") if grid.x < 9.0 else a.mat("neon_pink"))
	for grid in [Vector2(1, 6), Vector2(1, 12)]:
		_add_wall_station(a, grid, Vector3(1, 0, 0), true, a.mat("neon_pink"))
	for grid in [Vector2(17, 6), Vector2(17, 12)]:
		_add_wall_station(a, grid, Vector3(-1, 0, 0), true, a.mat("neon_cyan"))


func _add_wall_station(a, grid: Vector2, normal: Vector3, side_wall: bool, ledge_material: Material) -> void:
	var pad_size := Vector3(1.5 * GU, 1.5 * GU, 0.20 * GU) if not side_wall else Vector3(0.20 * GU, 1.5 * GU, 1.5 * GU)
	var ledge_size := Vector3(GU, 0.16 * GU, 0.5 * GU) if not side_wall else Vector3(0.5 * GU, 0.16 * GU, GU)
	for height_gu in [1.5, 3.5]:
		var housing_size := pad_size + (Vector3(0.22 * GU, 0.22 * GU, 0.18 * GU) if not side_wall else Vector3(0.18 * GU, 0.22 * GU, 0.22 * GU))
		var housing_position := _world(grid.x, grid.y, height_gu * GU) + normal * 0.05 * GU
		a.add_box("WallBumperHousing", housing_position, housing_size, a.mat("black"), true, Vector3.ZERO, null, a.surface("normal"))
		a.add_box("WallBumperBackplate", housing_position + normal * 0.10 * GU, pad_size * Vector3(0.78, 0.78, 0.72), a.mat("dark_metal"), false)
		var bumper: Area3D = a.add_directional_bumper(_world(grid.x, grid.y, height_gu * GU) + normal * 0.16 * GU, pad_size, 64.0, Color(1.0, 0.42, 0.06), normal, 3.6)
		# Wall pads must face into the arena on every side.  The impulse is local to this
		# rotation, so the glowing frame, indicator LEDs, solid face, and launch direction agree.
		bumper.rotation.y = atan2(normal.x, normal.z)
		bumper.fixed_direction = Vector3.BACK
		_add_glow_light(a, _world(grid.x, grid.y, height_gu * GU) + normal * 0.72 * GU, Color(1.0, 0.42, 0.06), 1.65, 3.0 * GU)
		a.mark_neon_element(bumper, "wall_bumper", grid, Vector3(1.5, 1.5, 0.2), {"height_gu": height_gu, "emission_rank": 3, "solid": true})
		a.mark_duel_interactable(bumper, "Stacked amber wall bumper returns the player to the arena", false)
	for height_gu in [2.5, 4.5]:
		var ledge: MeshInstance3D = a.add_box("WallLedge", _world(grid.x, grid.y, height_gu * GU) + normal * 0.42 * GU, ledge_size, ledge_material, true, Vector3.ZERO, null, a.surface("bounce"))
		var ledge_glow_size := ledge_size * Vector3(0.72, 0.32, 0.42)
		a.add_box("WallLedgeLED", _world(grid.x, grid.y, height_gu * GU) + normal * 0.68 * GU + Vector3.UP * 0.10 * GU, ledge_glow_size, ledge_material, false)
		a.mark_neon_element(ledge, "wall_ledge", grid, Vector3(1, 0.5, 0.5), {"height_gu": height_gu, "solid": true})


func _build_laser_gates(a) -> void:
	for spec in [[Vector2(9, 0.52), Vector3.BACK, Vector3.ZERO], [Vector2(9, 17.48), Vector3.FORWARD, Vector3.ZERO], [Vector2(0.52, 9), Vector3.BACK, Vector3(0, PI * 0.5, 0)], [Vector2(17.48, 9), Vector3.FORWARD, Vector3(0, PI * 0.5, 0)]]:
		var grid := spec[0] as Vector2
		var rotation_value := spec[2] as Vector3
		var gate: Area3D = a.add_laser_gate(_world(grid.x, grid.y, 1.25 * GU), Vector3(3.0 * GU, 2.5 * GU, 0.08 * GU), spec[1] as Vector3, 48.0, Color(0.55, 0.24, 0.98), rotation_value)
		a.mark_neon_element(gate, "laser_gate", grid, Vector3(3, 2.5, 0.08), {"off_seconds": 5.0, "on_seconds": 3.0})
		_add_gate_frame(a, grid, rotation_value)
		a.mark_duel_interactable(gate, "Three-GU side laser pushes but never eliminates", false)


func _add_gate_frame(a, grid: Vector2, rotation_value: Vector3) -> void:
	var side_wall := not is_zero_approx(rotation_value.y)
	var post_size := Vector3(0.18 * GU, 2.5 * GU, 0.18 * GU)
	var lateral := Vector3.RIGHT if not side_wall else Vector3.FORWARD
	for sign_value in [-1.0, 1.0]:
		var post_position: Vector3 = _world(grid.x, grid.y, 1.25 * GU) + lateral * sign_value * 1.5 * GU
		a.add_box("LaserPost", post_position, post_size, a.mat("dark_metal"), true)
		a.add_box("LaserPostLED", post_position + Vector3.UP * 0.18 * GU, post_size * Vector3(0.64, 0.62, 0.64), a.mat("violet_trim"), false)
	var lintel_size := Vector3(3.18 * GU, 0.18 * GU, 0.18 * GU) if not side_wall else Vector3(0.18 * GU, 0.18 * GU, 3.18 * GU)
	a.add_box("LaserLintel", _world(grid.x, grid.y, 2.5 * GU), lintel_size, a.mat("dark_metal"), true)
	a.add_box("LaserLintelLED", _world(grid.x, grid.y, 2.62 * GU), lintel_size * Vector3(0.82, 0.34, 0.54), a.mat("violet_trim"), false)
	_add_glow_light(a, _world(grid.x, grid.y, 1.3 * GU), Color(0.55, 0.24, 0.98), 1.5, 4.5 * GU)


func _add_glow_light(a, position: Vector3, color: Color, energy: float, range_value: float) -> void:
	var light := OmniLight3D.new()
	light.name = "NeonArchitecturalGlow"
	light.position = position
	light.light_color = color
	light.light_energy = energy
	light.omni_range = range_value
	light.shadow_enabled = false
	a.visual_root().add_child(light)


func _mark_overlap_footprint(node: Node, center: Vector2, size: Vector2, yaw: float) -> void:
	node.add_to_group("overlap_audit")
	node.set_meta("footprint_center", center)
	node.set_meta("footprint_size", size)
	node.set_meta("footprint_yaw", yaw)
