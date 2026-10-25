extends RefCounted

## Node construction for the practice training grounds. All layout numbers
## come from PracticeFacilityGeometry (the blueprint coordinate table); this
## file only turns tables into nodes.
##
## Hierarchy contract (asserted by practice_arena_geometry_contract): every
## MeshInstance3D is a DIRECT child of the host's PracticeVisuals root and
## every CollisionShape3D a DIRECT child of PracticeCollision. Interactables
## (hop pads, rebound panels) are Area3D scenes hanging off the scene root and
## own their internal solid/trigger pairing.

const GEOMETRY := preload("res://scripts/environment/practice_facility_geometry.gd")
const BOUNCE_PAD_SCRIPT := preload("res://scripts/bounce_pad.gd")
const REBOUND_PANEL_SCRIPT := preload("res://scripts/interactables/practice_rebound_panel.gd")

var _host: Node3D
var _block_material: StandardMaterial3D
var _orange_material: StandardMaterial3D
var _blue_material: StandardMaterial3D
var _white_material: StandardMaterial3D


func build(host: Node3D) -> void:
	_host = host
	_block_material = _matte(GEOMETRY.COLOR_BLOCK, 0.68, 0.05)
	_orange_material = _matte(GEOMETRY.COLOR_ORANGE, 0.5, 0.0)
	_blue_material = _matte(GEOMETRY.COLOR_BLUE, 0.55, 0.0)
	_white_material = _matte(GEOMETRY.COLOR_WHITE, 0.5, 0.0)
	_build_floor()
	_build_perimeter_walls()
	_build_enclosure_and_roof()
	_build_floor_markings()
	_build_center_platform()
	_build_cover_blocks()
	_build_side_ramps()
	_build_wedge_ramps()
	_build_dummy_stations()
	_build_hop_pads()
	_build_rebound_panels()


## Floor -------------------------------------------------------------------------

func _build_floor() -> void:
	var turf := _add_box("FacilityGround", Vector3(0.0, -GEOMETRY.FLOOR_SIZE.y * 0.5, 0.0), GEOMETRY.FLOOR_SIZE, _matte(GEOMETRY.COLOR_TURF, 0.96, 0.0), true)
	turf.add_to_group("practice_environment_detail")
	# Surrounding lawn keeps the outdoor facility grounded instead of floating;
	# its top is flush with the turf underside so the two plates never overlap.
	var apron_center := Vector3(0.0, GEOMETRY.APRON_TOP_Y - GEOMETRY.APRON_SIZE.y * 0.5, 0.0)
	var apron := _add_box("PerimeterApron", apron_center, GEOMETRY.APRON_SIZE, _matte(GEOMETRY.COLOR_TURF_DARK, 1.0, 0.0), true)
	apron.add_to_group("practice_environment_detail")


## Perimeter walls ----------------------------------------------------------------

func _build_perimeter_walls() -> void:
	var wall_material := _matte(GEOMETRY.COLOR_WALL, 0.82, 0.04)
	var half_height := GEOMETRY.WALL_HEIGHT * 0.5
	var north_south_length := GEOMETRY.FLOOR_SIZE.x
	var east_west_length := GEOMETRY.FLOOR_SIZE.z - GEOMETRY.WALL_THICKNESS * 2.0
	var wall_center_z := GEOMETRY.WALL_INNER_Z + GEOMETRY.WALL_THICKNESS * 0.5
	var wall_center_x := GEOMETRY.WALL_INNER_X + GEOMETRY.WALL_THICKNESS * 0.5
	var wall_specs := [
		{"name": "NorthPerimeterWall", "center": Vector3(0, half_height, -wall_center_z), "size": Vector3(north_south_length, GEOMETRY.WALL_HEIGHT, GEOMETRY.WALL_THICKNESS)},
		{"name": "SouthPerimeterWall", "center": Vector3(0, half_height, wall_center_z), "size": Vector3(north_south_length, GEOMETRY.WALL_HEIGHT, GEOMETRY.WALL_THICKNESS)},
		{"name": "WestPerimeterWall", "center": Vector3(-wall_center_x, half_height, 0), "size": Vector3(GEOMETRY.WALL_THICKNESS, GEOMETRY.WALL_HEIGHT, east_west_length)},
		{"name": "EastPerimeterWall", "center": Vector3(wall_center_x, half_height, 0), "size": Vector3(GEOMETRY.WALL_THICKNESS, GEOMETRY.WALL_HEIGHT, east_west_length)},
	]
	for spec in wall_specs:
		var wall := _add_box(str(spec["name"]), spec["center"] as Vector3, spec["size"] as Vector3, wall_material, false)
		wall.add_to_group("practice_perimeter_wall")
		var wall_shape := _add_box_collision(str(spec["name"]), spec["center"] as Vector3, spec["size"] as Vector3)
		wall_shape.add_to_group("practice_perimeter_wall_collision")

	# Rounded inner corners: quarter-proud cylinders centred on each corner.
	for x_sign in [-1.0, 1.0]:
		for z_sign in [-1.0, 1.0]:
			var corner_position := Vector3(x_sign * GEOMETRY.WALL_INNER_X, half_height, z_sign * GEOMETRY.WALL_INNER_Z)
			var corner := _add_cylinder("CornerRound", corner_position, GEOMETRY.CORNER_ROUND_RADIUS, GEOMETRY.WALL_HEIGHT, _matte(GEOMETRY.COLOR_WALL_TRIM, 0.78, 0.04), true)
			corner.add_to_group("solid_visible_prop")
			_last_collision.add_to_group("solid_visible_prop_collision")

	_build_wall_dressing()


## Layered wall dressing per the inside-view panel: padded charcoal blocks,
## a gray central rebound module, orange divider posts, dark base trim, and a
## light top cap. Decoration only - the four wall boxes carry all collision.
func _build_wall_dressing() -> void:
	var trim_length_ns := GEOMETRY.FLOOR_SIZE.x - GEOMETRY.WALL_THICKNESS * 2.0
	var trim_length_ew := GEOMETRY.FLOOR_SIZE.z - GEOMETRY.WALL_THICKNESS * 2.0

	# Padded panel blocks, one MultiMesh across all four walls.
	var pad_mesh := BoxMesh.new()
	pad_mesh.size = Vector3(6.6, 2.35, 0.24)
	pad_mesh.material = _matte(Color("2C3237"), 0.9, 0.0)
	var pad_transforms: Array[Transform3D] = []
	var side_basis := Basis(Vector3.UP, PI * 0.5)
	for row_y in [2.3, 5.4]:
		for x_offset in [11.1, 18.5, 25.9, 33.3]:
			for x_sign in [-1.0, 1.0]:
				pad_transforms.append(Transform3D(Basis.IDENTITY, Vector3(x_sign * x_offset, row_y, -GEOMETRY.WALL_INNER_Z)))
				pad_transforms.append(Transform3D(Basis.IDENTITY, Vector3(x_sign * x_offset, row_y, GEOMETRY.WALL_INNER_Z)))
		for z_offset in [11.1, 16.6]:
			for z_sign in [-1.0, 1.0]:
				pad_transforms.append(Transform3D(side_basis, Vector3(-GEOMETRY.WALL_INNER_X, row_y, z_sign * z_offset)))
				pad_transforms.append(Transform3D(side_basis, Vector3(GEOMETRY.WALL_INNER_X, row_y, z_sign * z_offset)))
	var padding := _add_multimesh("WallPadding", pad_mesh, pad_transforms)
	padding.add_to_group("practice_environment_detail")

	# Gray central module behind each rebound panel, full solid-wall height.
	var module_material := _matte(Color("6E747A"), 0.7, 0.05)
	for panel_spec in GEOMETRY.REBOUND_PANELS:
		var inward := panel_spec["inward"] as Vector3
		var face := panel_spec["face"] as Vector3
		var along_x := absf(inward.z) > 0.5
		var module_size := Vector3(15.9, GEOMETRY.WALL_HEIGHT, 0.3) if along_x else Vector3(0.3, GEOMETRY.WALL_HEIGHT, 15.9)
		var module := _add_box("WallCoreModule", Vector3(face.x, GEOMETRY.WALL_HEIGHT * 0.5, face.z), module_size, module_material, false)
		module.add_to_group("practice_environment_detail")

	# Orange divider posts run ground to roof; they visually carry the canopy.
	var post_height := GEOMETRY.ROOF_UNDERSIDE_Y
	var post_specs: Array[Dictionary] = []
	for x_sign in [-1.0, 1.0]:
		for z_sign in [-1.0, 1.0]:
			post_specs.append({"position": Vector3(x_sign * (GEOMETRY.WALL_INNER_X - 0.54), post_height * 0.5, z_sign * (GEOMETRY.WALL_INNER_Z - 0.54)), "size": Vector3(1.0, post_height, 1.0)})
		for post_x in [-8.6, 8.6]:
			post_specs.append({"position": Vector3(post_x, post_height * 0.5, x_sign * (GEOMETRY.WALL_INNER_Z + 0.3)), "size": Vector3(0.9, post_height, 0.85)})
		for post_z in [-8.6, 8.6]:
			post_specs.append({"position": Vector3(x_sign * (GEOMETRY.WALL_INNER_X + 0.3), post_height * 0.5, post_z), "size": Vector3(0.85, post_height, 0.9)})
	for post_spec in post_specs:
		var post := _add_box("SupportPost", post_spec["position"] as Vector3, post_spec["size"] as Vector3, _orange_material, false, "structural_support")
		post.add_to_group("practice_environment_detail")

	# Dark base trim and light top cap, one strip per wall.
	var trim_material := _matte(GEOMETRY.COLOR_BASE_TRIM, 0.94, 0.0)
	var cap_material := _matte(GEOMETRY.COLOR_LIGHT_PANEL, 0.55, 0.05)
	var cap_y := GEOMETRY.WALL_HEIGHT + 0.175
	for z_sign in [-1.0, 1.0]:
		var trim := _add_box("WallBaseTrim", Vector3(0, 0.45, z_sign * GEOMETRY.WALL_INNER_Z), Vector3(trim_length_ns, 0.9, 0.16), trim_material, false)
		trim.add_to_group("practice_environment_detail")
		var cap := _add_box("WallTopCap", Vector3(0, cap_y, z_sign * (GEOMETRY.WALL_INNER_Z + GEOMETRY.WALL_THICKNESS * 0.5)), Vector3(GEOMETRY.FLOOR_SIZE.x + 0.3, 0.35, GEOMETRY.WALL_THICKNESS + 0.3), cap_material, false)
		cap.add_to_group("practice_environment_detail")
	for x_sign in [-1.0, 1.0]:
		var trim := _add_box("WallBaseTrim", Vector3(x_sign * GEOMETRY.WALL_INNER_X, 0.45, 0), Vector3(0.16, 0.9, trim_length_ew), trim_material, false)
		trim.add_to_group("practice_environment_detail")
		var cap := _add_box("WallTopCap", Vector3(x_sign * (GEOMETRY.WALL_INNER_X + GEOMETRY.WALL_THICKNESS * 0.5), cap_y, 0), Vector3(GEOMETRY.WALL_THICKNESS + 0.3, 0.35, GEOMETRY.FLOOR_SIZE.z + 0.3), cap_material, false)
		cap.add_to_group("practice_environment_detail")


## Transparent upper enclosure and canopy roof ------------------------------------

func _build_enclosure_and_roof() -> void:
	var glass := _glass_material(Color(0.86, 0.91, 0.96, 0.13))
	var enclosure_height := GEOMETRY.ENCLOSURE_TOP_Y - GEOMETRY.ENCLOSURE_BASE_Y
	var enclosure_y := GEOMETRY.ENCLOSURE_BASE_Y + enclosure_height * 0.5
	var half_thickness := GEOMETRY.ENCLOSURE_THICKNESS * 0.5
	var enclosure_specs := [
		{"name": "EnclosureNorth", "center": Vector3(0, enclosure_y, -(GEOMETRY.WALL_INNER_Z + half_thickness)), "size": Vector3(GEOMETRY.FLOOR_SIZE.x, enclosure_height, GEOMETRY.ENCLOSURE_THICKNESS)},
		{"name": "EnclosureSouth", "center": Vector3(0, enclosure_y, GEOMETRY.WALL_INNER_Z + half_thickness), "size": Vector3(GEOMETRY.FLOOR_SIZE.x, enclosure_height, GEOMETRY.ENCLOSURE_THICKNESS)},
		{"name": "EnclosureWest", "center": Vector3(-(GEOMETRY.WALL_INNER_X + half_thickness), enclosure_y, 0), "size": Vector3(GEOMETRY.ENCLOSURE_THICKNESS, enclosure_height, GEOMETRY.WALL_INNER_Z * 2.0)},
		{"name": "EnclosureEast", "center": Vector3(GEOMETRY.WALL_INNER_X + half_thickness, enclosure_y, 0), "size": Vector3(GEOMETRY.ENCLOSURE_THICKNESS, enclosure_height, GEOMETRY.WALL_INNER_Z * 2.0)},
	]
	for spec in enclosure_specs:
		var pane := _add_box(str(spec["name"]), spec["center"] as Vector3, spec["size"] as Vector3, glass, false)
		pane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pane.add_to_group("practice_enclosure_wall")
		var pane_shape := _add_box_collision(str(spec["name"]), spec["center"] as Vector3, spec["size"] as Vector3)
		pane_shape.add_to_group("practice_enclosure_wall_collision")

	var roof_center := Vector3(0, GEOMETRY.ROOF_UNDERSIDE_Y + GEOMETRY.ROOF_SIZE.y * 0.5, 0)
	var roof := _add_box("CanopyRoof", roof_center, GEOMETRY.ROOF_SIZE, _glass_material(Color(0.66, 0.79, 0.91, 0.2)), false)
	roof.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	roof.add_to_group("arena_roof")
	var roof_shape := _add_box_collision("CanopyRoof", roof_center, GEOMETRY.ROOF_SIZE)
	roof_shape.add_to_group("arena_roof_collision")

	# Thin white frame around the roof edge plus batched mullion strips.
	var frame_y := GEOMETRY.ROOF_UNDERSIDE_Y + GEOMETRY.ROOF_SIZE.y + 0.175
	for z_sign in [-1.0, 1.0]:
		var rim := _add_box("RoofFrameRim", Vector3(0, frame_y, z_sign * (GEOMETRY.FLOOR_SIZE.z * 0.5 - 0.45)), Vector3(GEOMETRY.FLOOR_SIZE.x, 0.35, 0.9), _white_material, false)
		rim.add_to_group("practice_environment_detail")
	for x_sign in [-1.0, 1.0]:
		var rim := _add_box("RoofFrameRim", Vector3(x_sign * (GEOMETRY.FLOOR_SIZE.x * 0.5 - 0.45), frame_y, 0), Vector3(0.9, 0.35, GEOMETRY.FLOOR_SIZE.z - 1.8), _white_material, false)
		rim.add_to_group("practice_environment_detail")
	var mullion_mesh := BoxMesh.new()
	mullion_mesh.size = Vector3(0.3, 0.12, GEOMETRY.FLOOR_SIZE.z)
	mullion_mesh.material = _white_material
	var mullion_transforms: Array[Transform3D] = []
	for mullion_x in [-34.656, -23.104, -11.552, 11.552, 23.104, 34.656]:
		mullion_transforms.append(Transform3D(Basis.IDENTITY, Vector3(mullion_x, frame_y - 0.1, 0)))
	var mullions := _add_multimesh("RoofMullions", mullion_mesh, mullion_transforms)
	mullions.add_to_group("practice_environment_detail")
	var spine := _add_box("RoofSpine", Vector3(0, frame_y - 0.1, 0), Vector3(GEOMETRY.FLOOR_SIZE.x, 0.12, 0.3), _white_material, false)
	spine.add_to_group("practice_environment_detail")


## Floor markings (visual only) ----------------------------------------------------

func _build_floor_markings() -> void:
	var line_material := _matte(GEOMETRY.COLOR_GRID_LINE, 0.9, 0.0)
	# 1 GU training grid, batched per orientation.
	var line_ns_mesh := BoxMesh.new()
	line_ns_mesh.size = Vector3(GEOMETRY.GRID_LINE_WIDTH, 0.02, GEOMETRY.WALL_INNER_Z * 2.0)
	line_ns_mesh.material = line_material
	var ns_transforms: Array[Transform3D] = []
	for grid_x in range(1, 28):
		ns_transforms.append(Transform3D(Basis.IDENTITY, GEOMETRY.world(Vector2(float(grid_x), 7.5), 0.011)))
	var ns_lines := _add_multimesh("GridLinesNS", line_ns_mesh, ns_transforms)
	ns_lines.add_to_group("practice_environment_detail")
	var line_ew_mesh := BoxMesh.new()
	line_ew_mesh.size = Vector3(GEOMETRY.WALL_INNER_X * 2.0, 0.02, GEOMETRY.GRID_LINE_WIDTH)
	line_ew_mesh.material = line_material
	var ew_transforms: Array[Transform3D] = []
	for grid_y in range(1, 15):
		ew_transforms.append(Transform3D(Basis.IDENTITY, GEOMETRY.world(Vector2(14.0, float(grid_y)), 0.011)))
	var ew_lines := _add_multimesh("GridLinesEW", line_ew_mesh, ew_transforms)
	ew_lines.add_to_group("practice_environment_detail")

	# Dashed blue crosshair through the centre; dashes stop at the platform.
	var dash_mesh := BoxMesh.new()
	dash_mesh.size = Vector3(0.65 * GEOMETRY.GU, 0.03, GEOMETRY.CROSSHAIR_LINE_WIDTH)
	dash_mesh.material = _blue_material
	var dash_transforms: Array[Transform3D] = []
	var upright := Basis(Vector3.UP, PI * 0.5)
	for step in range(int(GEOMETRY.CROSSHAIR_X_SPAN.y - GEOMETRY.CROSSHAIR_X_SPAN.x)):
		var dash_position := GEOMETRY.world(Vector2(GEOMETRY.CROSSHAIR_X_SPAN.x + 0.5 + float(step), 7.5), 0.022)
		if absf(dash_position.x) > GEOMETRY.PLATFORM_TOP_HALF_X + GEOMETRY.PLATFORM_SKIRT + 0.8:
			dash_transforms.append(Transform3D(Basis.IDENTITY, dash_position))
	for step in range(int(GEOMETRY.CROSSHAIR_Y_SPAN.y - GEOMETRY.CROSSHAIR_Y_SPAN.x)):
		var dash_position := GEOMETRY.world(Vector2(14.0, GEOMETRY.CROSSHAIR_Y_SPAN.x + 0.5 + float(step)), 0.022)
		if absf(dash_position.z) > GEOMETRY.PLATFORM_TOP_HALF_Z + GEOMETRY.PLATFORM_SKIRT + 0.8:
			dash_transforms.append(Transform3D(upright, dash_position))
	var dashes := _add_multimesh("CrosshairDashes", dash_mesh, dash_transforms)
	dashes.add_to_group("practice_environment_detail")

	# Shooting-zone circle around the spawn platform.
	var circle := _add_torus("ShootingCircle", Vector3(0, 0.02, 0), GEOMETRY.SHOOTING_CIRCLE_RADIUS, 0.1, _matte(GEOMETRY.COLOR_BLUE, 0.6, 0.0), true)
	circle.add_to_group("practice_environment_detail")


## Centre spawn platform ------------------------------------------------------------

## Octagonal frustum: flat top, four beveled corners, ramped skirt on every
## side, built as one watertight mesh with an identical 16-point convex hull.
func _build_center_platform() -> void:
	var top_y := GEOMETRY.PLATFORM_TOP_Y
	var top_ring := _octagon_ring(GEOMETRY.PLATFORM_TOP_HALF_X, GEOMETRY.PLATFORM_TOP_HALF_Z, GEOMETRY.PLATFORM_CORNER_CUT, top_y)
	var base_ring := _octagon_ring(GEOMETRY.PLATFORM_TOP_HALF_X + GEOMETRY.PLATFORM_SKIRT, GEOMETRY.PLATFORM_TOP_HALF_Z + GEOMETRY.PLATFORM_SKIRT, GEOMETRY.PLATFORM_CORNER_CUT, 0.0)
	var points := PackedVector3Array()
	for vertex in top_ring + base_ring:
		points.append(vertex)

	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top_center := Vector3(0, top_y, 0)
	var base_center := Vector3(0, 0, 0)
	for index in range(8):
		var next_index := (index + 1) % 8
		# Top fan (facing up), skirt quads (facing out), base fan (facing down).
		_add_triangle(surface, top_center, top_ring[index], top_ring[next_index])
		_add_triangle(surface, top_ring[index], base_ring[index], base_ring[next_index])
		_add_triangle(surface, top_ring[index], base_ring[next_index], top_ring[next_index])
		_add_triangle(surface, base_center, base_ring[next_index], base_ring[index])
	surface.generate_normals()
	var mesh_resource := surface.commit()
	mesh_resource.surface_set_material(0, _matte(Color("B9BEC2"), 0.6, 0.05))

	var platform := MeshInstance3D.new()
	platform.name = _unique_name("SpawnPlatform")
	platform.mesh = mesh_resource
	platform.add_to_group("solid_visible_prop")
	_visuals().add_child(platform)
	var convex := ConvexPolygonShape3D.new()
	convex.points = points
	var shape := CollisionShape3D.new()
	shape.name = _unique_name("SpawnPlatformCollision")
	shape.shape = convex
	shape.add_to_group("solid_visible_prop_collision")
	_collision_root().add_child(shape)

	# Blue spawn markings on the platform top.
	var ring := _add_torus("PlatformRing", Vector3(0, top_y + 0.015, 0), 4.4, 0.09, _blue_material, true)
	ring.add_to_group("practice_environment_detail")
	var disc := _add_cylinder("PlatformSpawnDisc", Vector3(0, top_y + 0.012, 0), 1.0, 0.02, _blue_material, false)
	disc.add_to_group("practice_environment_detail")


## Octagon vertex ring (CCW seen from above), matching the blueprint platform:
## full-width edges on X and Z, 45-degree corner cuts.
func _octagon_ring(half_x: float, half_z: float, corner_cut: float, height: float) -> Array[Vector3]:
	return [
		Vector3(half_x, height, half_z - corner_cut),
		Vector3(half_x - corner_cut, height, half_z),
		Vector3(-(half_x - corner_cut), height, half_z),
		Vector3(-half_x, height, half_z - corner_cut),
		Vector3(-half_x, height, -(half_z - corner_cut)),
		Vector3(-(half_x - corner_cut), height, -half_z),
		Vector3(half_x - corner_cut, height, -half_z),
		Vector3(half_x, height, -(half_z - corner_cut)),
	]


## Low cover blocks -----------------------------------------------------------------

func _build_cover_blocks() -> void:
	var top_material := _matte(GEOMETRY.COLOR_LIGHT_PANEL, 0.58, 0.05)
	for grid_position in GEOMETRY.COVER_GRID_POSITIONS:
		var center := GEOMETRY.world(grid_position, GEOMETRY.COVER_SIZE.y * 0.5)
		var block := _add_box("CoverBlock", center, GEOMETRY.COVER_SIZE, _block_material, true)
		block.add_to_group("solid_visible_prop")
		_last_collision.add_to_group("solid_visible_prop_collision")
		var top := _add_box("CoverBlockTop", Vector3(center.x, GEOMETRY.COVER_SIZE.y + 0.06, center.z), Vector3(GEOMETRY.COVER_SIZE.x - 0.5, 0.12, GEOMETRY.COVER_SIZE.z - 0.5), top_material, false)
		top.add_to_group("practice_environment_detail")
		for x_sign in [-1.0, 1.0]:
			for z_sign in [-1.0, 1.0]:
				var post_position := Vector3(center.x + x_sign * (GEOMETRY.COVER_SIZE.x * 0.5 - 0.3), center.y, center.z + z_sign * (GEOMETRY.COVER_SIZE.z * 0.5 - 0.3))
				var post := _add_box("CoverCornerAccent", post_position, Vector3(0.5, GEOMETRY.COVER_SIZE.y + 0.04, 0.5), _orange_material, false)
				post.add_to_group("practice_environment_detail")


## Broad side ramps ------------------------------------------------------------------

## Curved launch ramps: a parabolic rise toward the wall, approximated with
## four convex prism segments whose shared edges keep the surface continuous.
func _build_side_ramps() -> void:
	for ramp_spec in GEOMETRY.SIDE_RAMPS:
		var prefix := str(ramp_spec["prefix"])
		var travel_sign := float(ramp_spec["sign"])
		var center := GEOMETRY.world(ramp_spec["grid_center"] as Vector2)
		var entry_x := center.x - travel_sign * GEOMETRY.SIDE_RAMP_RUN * 0.5
		var segment_run := GEOMETRY.SIDE_RAMP_RUN / float(GEOMETRY.SIDE_RAMP_SEGMENTS)
		for segment in range(GEOMETRY.SIDE_RAMP_SEGMENTS):
			var t_near := float(segment) / float(GEOMETRY.SIDE_RAMP_SEGMENTS)
			var t_far := float(segment + 1) / float(GEOMETRY.SIDE_RAMP_SEGMENTS)
			var near_height := maxf(GEOMETRY.SIDE_RAMP_HEIGHT * t_near * t_near, 0.02)
			var far_height := GEOMETRY.SIDE_RAMP_HEIGHT * t_far * t_far
			var near_x := entry_x + travel_sign * segment_run * float(segment)
			var far_x := near_x + travel_sign * segment_run
			_add_convex_prism(prefix, minf(near_x, far_x), maxf(near_x, far_x),
				near_height if travel_sign > 0.0 else far_height,
				far_height if travel_sign > 0.0 else near_height,
				GEOMETRY.SIDE_RAMP_WIDTH, center.z, _block_material)
		_add_ramp_arrows(center, travel_sign)


## One convex prism slice: rectangular footprint [low_x, high_x] x width, flat
## bottom on the floor, top edge rising from height_at_low to height_at_high.
func _add_convex_prism(prefix: String, low_x: float, high_x: float, height_at_low: float, height_at_high: float, width: float, center_z: float, material: Material) -> void:
	var half_width := width * 0.5
	var half_run := (high_x - low_x) * 0.5
	var center_x := (low_x + high_x) * 0.5
	var points := PackedVector3Array([
		Vector3(-half_run, 0, -half_width), Vector3(-half_run, 0, half_width),
		Vector3(half_run, 0, -half_width), Vector3(half_run, 0, half_width),
		Vector3(-half_run, height_at_low, -half_width), Vector3(-half_run, height_at_low, half_width),
		Vector3(half_run, height_at_high, -half_width), Vector3(half_run, height_at_high, half_width),
	])
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_triangle(surface, points[0], points[3], points[2])
	_add_triangle(surface, points[0], points[1], points[3])
	_add_triangle(surface, points[4], points[7], points[5])
	_add_triangle(surface, points[4], points[6], points[7])
	_add_triangle(surface, points[0], points[5], points[1])
	_add_triangle(surface, points[0], points[4], points[5])
	_add_triangle(surface, points[2], points[7], points[6])
	_add_triangle(surface, points[2], points[3], points[7])
	_add_triangle(surface, points[0], points[6], points[4])
	_add_triangle(surface, points[0], points[2], points[6])
	_add_triangle(surface, points[1], points[7], points[3])
	_add_triangle(surface, points[1], points[5], points[7])
	surface.generate_normals()
	var mesh_resource := surface.commit()
	mesh_resource.surface_set_material(0, material)

	var position := Vector3(center_x, 0, center_z)
	var instance := MeshInstance3D.new()
	instance.name = _unique_name(prefix)
	instance.mesh = mesh_resource
	instance.position = position
	instance.add_to_group("closed_ramp")
	_visuals().add_child(instance)
	var convex := ConvexPolygonShape3D.new()
	convex.points = points
	var shape := CollisionShape3D.new()
	shape.name = _unique_name(prefix + "Collision")
	shape.shape = convex
	shape.position = position
	shape.add_to_group("closed_ramp_collision")
	_collision_root().add_child(shape)


## Blue directional arrows on a side ramp surface, batched with the wedge
## arrows into one MultiMesh built lazily on first use.
var _arrow_transforms: Array[Transform3D] = []


func _add_ramp_arrows(ramp_center: Vector3, travel_sign: float) -> void:
	for t in [0.4, 0.75]:
		var local_x := (float(t) - 0.5) * GEOMETRY.SIDE_RAMP_RUN
		var surface_y := GEOMETRY.SIDE_RAMP_HEIGHT * float(t) * float(t) + 0.09
		var slope := atan2(2.0 * GEOMETRY.SIDE_RAMP_HEIGHT * float(t), GEOMETRY.SIDE_RAMP_RUN)
		var pitch := Basis(Vector3.FORWARD, -travel_sign * slope)
		var arrow_position := Vector3(ramp_center.x + travel_sign * local_x, surface_y, ramp_center.z)
		for bar_sign in [-1.0, 1.0]:
			# Two bars form a chevron whose apex points up-ramp, matching the
			# blueprint's travel arrows.
			var yaw := Basis(Vector3.UP, -bar_sign * PI * 0.25 + (PI if travel_sign > 0.0 else 0.0))
			var offset := pitch * Vector3(travel_sign * 0.45, 0.0, bar_sign * 0.62)
			_arrow_transforms.append(Transform3D(pitch * yaw, arrow_position + offset))


func _add_wedge_arrow(wedge_position: Vector3, yaw_angle: float) -> void:
	var pitch := Basis(Vector3.RIGHT, atan2(GEOMETRY.WEDGE_HEIGHT, GEOMETRY.WEDGE_RUN))
	var wedge_basis := Basis(Vector3.UP, yaw_angle)
	var surface_center := wedge_position + wedge_basis * Vector3(0, GEOMETRY.WEDGE_HEIGHT * 0.5 + 0.1, 0)
	for bar_sign in [-1.0, 1.0]:
		var yaw := Basis(Vector3.UP, bar_sign * PI * 0.25 + PI * 0.5)
		var offset := wedge_basis * pitch * Vector3(bar_sign * 0.62, 0.0, -0.45)
		_arrow_transforms.append(Transform3D(wedge_basis * pitch * yaw, surface_center + offset))


func _commit_arrows() -> void:
	var bar_mesh := BoxMesh.new()
	bar_mesh.size = Vector3(1.7, 0.06, 0.34)
	bar_mesh.material = _blue_material
	var arrows := _add_multimesh("DirectionArrows", bar_mesh, _arrow_transforms)
	arrows.add_to_group("practice_environment_detail")


## Wedge ramps -----------------------------------------------------------------------

func _build_wedge_ramps() -> void:
	for wedge_spec in GEOMETRY.WEDGES:
		var center := GEOMETRY.world(wedge_spec["grid"] as Vector2)
		var station := GEOMETRY.station_by_letter(str(wedge_spec["aim_letter"]))
		var target := GEOMETRY.world(station["grid"] as Vector2)
		var direction := Vector3(target.x - center.x, 0.0, target.z - center.z).normalized()
		var yaw_angle := atan2(-direction.x, -direction.z)
		_add_closed_wedge(str(wedge_spec["prefix"]), center, yaw_angle)
		_add_wedge_arrow(center, yaw_angle)
	_commit_arrows()


## Watertight wedge rising toward local -Z, rotated to aim at its dummy lane;
## the 8-point convex collider shares the same vertices and rotation.
func _add_closed_wedge(prefix: String, center: Vector3, yaw_angle: float) -> void:
	var half_width := GEOMETRY.WEDGE_WIDTH * 0.5
	var half_run := GEOMETRY.WEDGE_RUN * 0.5
	# Same point/triangle scheme as the proven closed-ramp wedge (entry edge at
	# local +Z, high edge at local -Z), so the winding renders outward.
	var points := PackedVector3Array([
		Vector3(-half_width, 0, half_run), Vector3(half_width, 0, half_run),
		Vector3(-half_width, 0, -half_run), Vector3(half_width, 0, -half_run),
		Vector3(-half_width, 0.02, half_run), Vector3(half_width, 0.02, half_run),
		Vector3(-half_width, GEOMETRY.WEDGE_HEIGHT, -half_run), Vector3(half_width, GEOMETRY.WEDGE_HEIGHT, -half_run),
	])
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_triangle(surface, points[0], points[3], points[2])
	_add_triangle(surface, points[0], points[1], points[3])
	_add_triangle(surface, points[4], points[7], points[5])
	_add_triangle(surface, points[4], points[6], points[7])
	_add_triangle(surface, points[0], points[5], points[1])
	_add_triangle(surface, points[0], points[4], points[5])
	_add_triangle(surface, points[2], points[7], points[6])
	_add_triangle(surface, points[2], points[3], points[7])
	_add_triangle(surface, points[0], points[6], points[4])
	_add_triangle(surface, points[0], points[2], points[6])
	_add_triangle(surface, points[1], points[7], points[3])
	_add_triangle(surface, points[1], points[5], points[7])
	surface.generate_normals()
	var mesh_resource := surface.commit()
	mesh_resource.surface_set_material(0, _block_material)

	var instance := MeshInstance3D.new()
	instance.name = _unique_name(prefix)
	instance.mesh = mesh_resource
	instance.position = center
	instance.rotation = Vector3(0, yaw_angle, 0)
	instance.add_to_group("closed_ramp")
	_visuals().add_child(instance)
	var convex := ConvexPolygonShape3D.new()
	convex.points = points
	var shape := CollisionShape3D.new()
	shape.name = _unique_name(prefix + "Collision")
	shape.shape = convex
	shape.position = center
	shape.rotation = Vector3(0, yaw_angle, 0)
	shape.add_to_group("closed_ramp_collision")
	_collision_root().add_child(shape)


## Dummy stations --------------------------------------------------------------------

func _build_dummy_stations() -> void:
	var base_material := _matte(Color("2E3438"), 0.85, 0.0)
	var ring_material := _emissive(GEOMETRY.COLOR_RED, 0.8)
	for station_value in GEOMETRY.DUMMY_STATIONS:
		var station := station_value as Dictionary
		var letter := str(station["letter"])
		var floor_y := GEOMETRY.station_floor_y(station)
		var center := GEOMETRY.world(station["grid"] as Vector2)
		if bool(station["raised"]):
			var pedestal := _add_cylinder("StationPedestal" + letter, Vector3(center.x, GEOMETRY.PEDESTAL_HEIGHT * 0.5, center.z), GEOMETRY.PEDESTAL_RADIUS, GEOMETRY.PEDESTAL_HEIGHT, _matte(GEOMETRY.COLOR_WALL_TRIM, 0.7, 0.05), true)
			pedestal.add_to_group("solid_visible_prop")
			_last_collision.add_to_group("solid_visible_prop_collision")
			var trim := _add_torus("StationPedestalTrim" + letter, Vector3(center.x, GEOMETRY.PEDESTAL_HEIGHT - 0.03, center.z), GEOMETRY.PEDESTAL_RADIUS, 0.07, _matte(GEOMETRY.COLOR_ORANGE, 0.55, 0.0), true)
			trim.add_to_group("practice_environment_detail")
		var base_disc := _add_cylinder("StationBase" + letter, Vector3(center.x, floor_y + 0.045, center.z), GEOMETRY.STATION_RING_RADIUS + 0.35, 0.09, base_material, false)
		base_disc.add_to_group("practice_environment_detail")
		var ring := _add_torus("StationRing" + letter, Vector3(center.x, floor_y + 0.1, center.z), GEOMETRY.STATION_RING_RADIUS, 0.11, ring_material, true)
		ring.add_to_group("training_target_ring")
		ring.add_to_group("practice_environment_detail")


## Training hop pads -----------------------------------------------------------------

func _build_hop_pads() -> void:
	var puck_material := _matte(Color("9BA1A6"), 0.6, 0.08)
	var band_material := _matte(GEOMETRY.COLOR_BLUE, 0.5, 0.0)
	var cross_mesh := BoxMesh.new()
	cross_mesh.size = Vector3(1.4, 0.045, 0.34)
	cross_mesh.material = _blue_material
	var cross_transforms: Array[Transform3D] = []
	var upright := Basis(Vector3.UP, PI * 0.5)
	for grid_position in GEOMETRY.HOP_PAD_GRID_POSITIONS:
		var center := GEOMETRY.world(grid_position)
		var puck := _add_cylinder("HopPadPuck", Vector3(center.x, GEOMETRY.HOP_PAD_HEIGHT * 0.5, center.z), GEOMETRY.HOP_PAD_RADIUS, GEOMETRY.HOP_PAD_HEIGHT, puck_material, true)
		puck.add_to_group("solid_visible_prop")
		_last_collision.add_to_group("solid_visible_prop_collision")
		var band := _add_torus("HopPadBand", Vector3(center.x, GEOMETRY.HOP_PAD_HEIGHT - 0.04, center.z), GEOMETRY.HOP_PAD_RADIUS - 0.06, 0.06, band_material, true)
		band.add_to_group("practice_environment_detail")
		var cross_y := GEOMETRY.HOP_PAD_HEIGHT + 0.035
		cross_transforms.append(Transform3D(Basis.IDENTITY, Vector3(center.x, cross_y, center.z)))
		cross_transforms.append(Transform3D(upright, Vector3(center.x, cross_y, center.z)))

		var pad := Area3D.new()
		pad.set_script(BOUNCE_PAD_SCRIPT)
		pad.name = _unique_name("HopPad")
		pad.collision_layer = 0
		pad.collision_mask = 2
		pad.monitoring = true
		pad.position = Vector3(center.x, 0, center.z)
		pad.set("launch_impulse", GEOMETRY.HOP_PAD_IMPULSE)
		var trigger := CollisionShape3D.new()
		trigger.name = "Trigger"
		var trigger_shape := CylinderShape3D.new()
		trigger_shape.radius = GEOMETRY.HOP_PAD_RADIUS
		trigger_shape.height = 1.4
		trigger.shape = trigger_shape
		trigger.position = Vector3(0, GEOMETRY.HOP_PAD_HEIGHT + 0.55, 0)
		pad.add_child(trigger)
		_host.add_child(pad)
	var crosses := _add_multimesh("HopPadCross", cross_mesh, cross_transforms)
	crosses.add_to_group("practice_environment_detail")


## Wall bounce panels ----------------------------------------------------------------

func _build_rebound_panels() -> void:
	for panel_spec in GEOMETRY.REBOUND_PANELS:
		var inward := (panel_spec["inward"] as Vector3).normalized()
		var face := panel_spec["face"] as Vector3
		var panel := Area3D.new()
		panel.set_script(REBOUND_PANEL_SCRIPT)
		panel.name = str(panel_spec["name"])
		panel.collision_layer = 0
		panel.collision_mask = 2
		panel.monitoring = true
		panel.set("panel_width", GEOMETRY.PANEL_WIDTH)
		panel.set("panel_height", GEOMETRY.PANEL_HEIGHT)
		panel.set("panel_thickness", GEOMETRY.PANEL_PROTRUSION)
		panel.set("inward", inward)
		panel.set("speed_multiplier", GEOMETRY.PANEL_SPEED_MULTIPLIER)
		panel.set("minimum_speed", GEOMETRY.PANEL_MINIMUM_SPEED)
		panel.position = face + inward * GEOMETRY.PANEL_PROTRUSION * 0.5
		# Local +X is the panel's inward face.
		panel.rotation = Vector3(0, atan2(inward.z, inward.x) * -1.0, 0)
		_host.add_child(panel)


## Primitive helpers ------------------------------------------------------------------

var _last_collision: CollisionShape3D


func _add_box(prefix: String, position: Vector3, size: Vector3, material: Material, collision: bool, support_group: String = "", rotation: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.name = _unique_name(prefix)
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position
	instance.rotation = rotation
	if not collision:
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if not support_group.is_empty():
		instance.add_to_group(support_group)
	_visuals().add_child(instance)
	if collision:
		_last_collision = _add_box_collision(prefix, position, size, rotation)
	return instance


func _add_box_collision(prefix: String, position: Vector3, size: Vector3, rotation: Vector3 = Vector3.ZERO) -> CollisionShape3D:
	var shape_resource := BoxShape3D.new()
	shape_resource.size = size
	var shape := CollisionShape3D.new()
	shape.name = _unique_name(prefix + "Collision")
	shape.shape = shape_resource
	shape.position = position
	shape.rotation = rotation
	_collision_root().add_child(shape)
	return shape


func _add_cylinder(prefix: String, position: Vector3, radius: float, height: float, material: Material, collision: bool) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 32
	var instance := MeshInstance3D.new()
	instance.name = _unique_name(prefix)
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position
	if not collision:
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visuals().add_child(instance)
	if collision:
		var shape_resource := CylinderShape3D.new()
		shape_resource.radius = radius
		shape_resource.height = height
		var shape := CollisionShape3D.new()
		shape.name = _unique_name(prefix + "Collision")
		shape.shape = shape_resource
		shape.position = position
		_collision_root().add_child(shape)
		_last_collision = shape
	return instance


func _add_torus(prefix: String, position: Vector3, radius: float, tube: float, material: Material, flat_on_floor: bool, upright: bool = false) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - tube
	mesh.outer_radius = radius + tube
	var instance := MeshInstance3D.new()
	instance.name = _unique_name(prefix)
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position
	if upright:
		instance.rotation_degrees = Vector3(90, 90, 0)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visuals().add_child(instance)
	return instance


func _add_multimesh(prefix: String, mesh: Mesh, transforms: Array[Transform3D]) -> MultiMeshInstance3D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for index in range(transforms.size()):
		multimesh.set_instance_transform(index, transforms[index])
	var instance := MultiMeshInstance3D.new()
	instance.name = _unique_name(prefix)
	instance.multimesh = multimesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visuals().add_child(instance)
	return instance


func _add_triangle(surface: SurfaceTool, first: Vector3, second: Vector3, third: Vector3) -> void:
	surface.add_vertex(first)
	surface.add_vertex(second)
	surface.add_vertex(third)


func _matte(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material


func _emissive(color: Color, energy: float) -> StandardMaterial3D:
	var material := _matte(color.darkened(0.1), 0.5, 0.0)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material


func _glass_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.roughness = 0.06
	material.metallic = 0.0
	return material


func _visuals() -> Node3D:
	return _host.get_node("PracticeVisuals") as Node3D


func _collision_root() -> StaticBody3D:
	return _host.get_node("PracticeCollision") as StaticBody3D


func _unique_name(prefix: String) -> String:
	return "%s_%03d" % [prefix, _host.call("next_index")]
