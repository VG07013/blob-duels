class_name CityArena
extends Node3D

const ARENA_SIZE := 1000.0
const HALF_EXTENT := ARENA_SIZE * 0.5
const BOUNCE_PAD_SCENE: PackedScene = preload("res://scenes/world/bounce_pad.tscn")
const ASPHALT_TEXTURE: Texture2D = preload("res://assets/textures/asphalt.png")
const CONCRETE_TEXTURE: Texture2D = preload("res://assets/textures/concrete.png")
const WINDOWS_TEXTURE: Texture2D = preload("res://assets/textures/windows_grid.png")
const BLOB_LEAGUE_TEXTURE: Texture2D = preload("res://assets/textures/billboard_blob_league.png")
const FLING_CITY_TEXTURE: Texture2D = preload("res://assets/textures/billboard_fling_city.png")

var _materials: Dictionary = {}
var _visuals: Node3D
var _collision_body: StaticBody3D
var _name_counter := 0


func _ready() -> void:
	_build_materials()
	_visuals = Node3D.new()
	_visuals.name = "CityVisuals"
	add_child(_visuals)
	_collision_body = StaticBody3D.new()
	_collision_body.name = "CityCollision"
	_collision_body.collision_layer = 1
	_collision_body.collision_mask = 0
	add_child(_collision_body)
	_build_ground_and_roads()
	_build_city_blocks()
	_build_central_plaza()
	_build_rooftop_routes()
	_build_overpass()
	_build_park()
	_build_street_details()
	_build_spawn_zones()
	_build_boundaries()
	_build_practice_roof_and_ceiling_detail()
	_build_clouds()
	_build_landmark_lights()


func _build_materials() -> void:
	_materials.asphalt = _make_textured_material(ASPHALT_TEXTURE, Color(0.62, 0.68, 0.76), 0.94, Vector3(64, 64, 64))
	_materials.road = _make_textured_material(ASPHALT_TEXTURE, Color(0.82, 0.86, 0.92), 0.9, Vector3(36, 36, 36))
	_materials.concrete = _make_textured_material(CONCRETE_TEXTURE, Color(0.72, 0.75, 0.78), 0.92, Vector3(8, 8, 8))
	_materials.concrete_light = _make_textured_material(CONCRETE_TEXTURE, Color(1.0, 1.0, 0.96), 0.88, Vector3(10, 10, 10))
	_materials.metal = _make_material(Color(0.2, 0.24, 0.29), 0.3, 0.72)
	_materials.glass = _make_material(Color(0.08, 0.31, 0.48), 0.15, 0.54)
	_materials.window_warm = _make_window_material(Color(1.0, 0.83, 0.68), 0.72)
	_materials.window_cool = _make_window_material(Color(0.72, 0.9, 1.0), 0.62)
	_materials.coral = _make_material(Color(0.9, 0.25, 0.29), 0.68, 0.04)
	_materials.teal = _make_material(Color(0.03, 0.58, 0.62), 0.62, 0.08)
	_materials.blue = _make_material(Color(0.12, 0.38, 0.78), 0.58, 0.08)
	_materials.violet = _make_material(Color(0.39, 0.24, 0.72), 0.6, 0.06)
	_materials.yellow = _make_material(Color(1.0, 0.68, 0.12), 0.65, 0.02)
	_materials.white_paint = _make_material(Color(0.94, 0.95, 0.91), 0.62, 0.0)
	_materials.grass = _make_material(Color(0.16, 0.48, 0.24), 0.96, 0.0)
	_materials.leaves = _make_material(Color(0.08, 0.38, 0.2), 0.9, 0.0)
	_materials.wood = _make_material(Color(0.38, 0.18, 0.07), 0.9, 0.0)
	_materials.water = _make_material(Color(0.04, 0.36, 0.62), 0.22, 0.12)
	_materials.cloud = _make_material(Color(0.98, 0.99, 1.0), 1.0, 0.0)
	_materials.roof_glass = _make_material(Color(0.48, 0.78, 0.94, 0.14), 0.18, 0.08)
	_materials.neon_cyan = _make_emissive_material(Color(0.04, 0.9, 0.95), 2.2)
	_materials.neon_pink = _make_emissive_material(Color(1.0, 0.12, 0.5), 2.0)
	_materials.spawn_blue = _make_emissive_material(Color(0.08, 0.68, 1.0), 1.7)
	_materials.spawn_red = _make_emissive_material(Color(1.0, 0.2, 0.32), 1.7)
	_materials.billboard_blob = _make_billboard_material(BLOB_LEAGUE_TEXTURE)
	_materials.billboard_fling = _make_billboard_material(FLING_CITY_TEXTURE)


func _build_ground_and_roads() -> void:
	_add_box("ArenaGround", Vector3(0, -1.0, 0), Vector3(ARENA_SIZE, 2.0, ARENA_SIZE), _materials.asphalt, true)

	# Four broad roads make the city easy to read; secondary roads form chase loops.
	_add_box("RoadEastWest", Vector3(0, 0.03, 0), Vector3(920, 0.06, 82), _materials.road, false)
	_add_box("RoadNorthSouth", Vector3(0, 0.04, 0), Vector3(82, 0.08, 920), _materials.road, false)
	for offset in [-245.0, 245.0]:
		_add_box("SecondaryRoadEW", Vector3(0, 0.03, offset), Vector3(920, 0.06, 54), _materials.road, false)
		_add_box("SecondaryRoadNS", Vector3(offset, 0.04, 0), Vector3(54, 0.08, 920), _materials.road, false)

	for offset in [-14.0, 14.0]:
		_add_box("CenterLaneEW", Vector3(0, 0.09, offset), Vector3(900, 0.04, 0.8), _materials.yellow, false)
		_add_box("CenterLaneNS", Vector3(offset, 0.1, 0), Vector3(0.8, 0.04, 900), _materials.yellow, false)
	for offset in [-245.0, 245.0]:
		_add_box("SecondaryLaneEW", Vector3(0, 0.09, offset), Vector3(900, 0.04, 0.65), _materials.white_paint, false)
		_add_box("SecondaryLaneNS", Vector3(offset, 0.1, 0), Vector3(0.65, 0.04, 900), _materials.white_paint, false)


func _build_city_blocks() -> void:
	var coordinates: Array[float] = [-390.0, -310.0, -165.0, 165.0, 310.0, 390.0]
	var building_materials: Array[String] = ["blue", "teal", "coral", "violet"]
	var building_index := 0
	for x in coordinates:
		for z in coordinates:
			if x < -220.0 and z > 220.0:
				continue
			if abs(x) < 200.0 and abs(z) < 200.0:
				continue

			var seed_value: int = absi(int(x * 3.0 + z * 5.0))
			var width: float = 52.0 + float(seed_value % 3) * 9.0
			var depth: float = 50.0 + float(int(seed_value / 3) % 3) * 10.0
			var edge_bonus: float = 55.0 if absf(x) > 300.0 or absf(z) > 300.0 else 0.0
			var height: float = 48.0 + float(seed_value % 5) * 16.0 + edge_bonus
			var material_key: String = building_materials[building_index % building_materials.size()]
			_add_building("Tower_%02d" % building_index, Vector3(x, 0, z), Vector3(width, height, depth), _materials[material_key], building_index)
			building_index += 1

	# Medium structures tighten sightlines without blocking the primary streets.
	var cover_positions := [
		Vector3(-105, 0, -265), Vector3(105, 0, -265),
		Vector3(-105, 0, 265), Vector3(105, 0, 265),
		Vector3(-265, 0, -105), Vector3(-265, 0, 105),
		Vector3(265, 0, -105), Vector3(265, 0, 105),
	]
	for index in range(cover_positions.size()):
		var position: Vector3 = cover_positions[index]
		var size := Vector3(58, 30 + (index % 3) * 8, 48)
		_add_building("MidBlock_%02d" % index, position, size, _materials[["teal", "coral", "blue"][index % 3]], 100 + index)


func _add_building(prefix: String, ground_position: Vector3, size: Vector3, material: Material, style_index: int) -> void:
	_add_box(prefix + "_Sidewalk", ground_position + Vector3(0, 0.3, 0), Vector3(size.x + 14, 0.6, size.z + 14), _materials.concrete_light, true)
	var center := ground_position + Vector3(0, 0.6 + size.y * 0.5, 0)
	_add_box(prefix, center, size, material, true)
	_add_box(prefix + "_Roof", ground_position + Vector3(0, size.y + 1.0, 0), Vector3(size.x + 3, 1.0, size.z + 3), _materials.metal, true)

	var window_material: Material = _materials.window_warm if style_index % 2 == 0 else _materials.window_cool
	for band_index in range(4):
		var band_y := 8.0 + float(band_index) * maxf(7.0, (size.y - 14.0) / 4.0)
		if band_y >= size.y - 3.0:
			continue
		_add_box(prefix + "_WindowsFront", ground_position + Vector3(0, band_y, size.z * 0.5 + 0.12), Vector3(size.x * 0.72, 2.4, 0.24), window_material, false)
		_add_box(prefix + "_WindowsBack", ground_position + Vector3(0, band_y, -size.z * 0.5 - 0.12), Vector3(size.x * 0.72, 2.4, 0.24), window_material, false)

	if size.y > 90.0:
		var sign_material: Material = _materials.billboard_fling if style_index % 2 == 0 else _materials.billboard_blob
		_add_billboard(
			prefix + "_Sign",
			ground_position + Vector3(0, minf(size.y * 0.62, 72.0), size.z * 0.5 + 0.55),
			Vector2(size.x * 0.72, size.x * 0.36),
			sign_material
		)


func _build_central_plaza() -> void:
	_add_box("CentralPlaza", Vector3(0, 0.28, 0), Vector3(224, 0.56, 224), _materials.concrete_light, true)
	for corner in [Vector3(-82, 1.0, -82), Vector3(82, 1.0, -82), Vector3(-82, 1.0, 82), Vector3(82, 1.0, 82)]:
		_add_cylinder("PlazaPlanter", corner, 12.0, 2.0, _materials.concrete, true)
		_add_cylinder("PlazaTreeTrunk", corner + Vector3(0, 5.0, 0), 1.8, 8.0, _materials.wood, true)
		_add_sphere("PlazaTreeTop", corner + Vector3(0, 11.0, 0), 6.5, _materials.leaves, true)

	# The landmark sits just north of the exact center so the fallback spawn at (0, 6, 0) stays safe.
	_add_cylinder("EnergyPool", Vector3(0, 0.7, -38), 30.0, 1.4, _materials.water, true)
	_add_cylinder("EnergyCoreBase", Vector3(0, 2.0, -38), 12.0, 4.0, _materials.metal, true)
	_add_cylinder("EnergyCore", Vector3(0, 15.0, -38), 5.0, 26.0, _materials.neon_cyan, true)
	_add_cylinder("EnergyRingLow", Vector3(0, 7.0, -38), 17.0, 0.8, _materials.neon_pink, false)
	_add_cylinder("EnergyRingHigh", Vector3(0, 22.0, -38), 12.0, 0.6, _materials.neon_cyan, false)
	_add_world_label("CentralPlazaLabel", Vector3(0, 31, -38), "BLOB PLAZA", Color(0.92, 0.98, 1.0), 58)

	var barrier_positions := [Vector3(-58, 2.0, 58), Vector3(58, 2.0, 58), Vector3(-58, 2.0, -98), Vector3(58, 2.0, -98)]
	for index in range(barrier_positions.size()):
		_add_box("PlazaCover", barrier_positions[index], Vector3(28, 4, 7), _materials.yellow if index % 2 == 0 else _materials.coral, true, Vector3(0, 0.35 if index % 2 == 0 else -0.35, 0))


func _build_rooftop_routes() -> void:
	_add_low_rooftop("WestDeck", Vector3(-150, 0, 0), Vector3(82, 20, 70), _materials.teal)
	_add_bounce_pad(Vector3(-150, 22.0, 0))
	_add_ramp("WestDeckRamp", Vector3(-72, 10.39391, 0), Vector3(78, 3, 36), _materials.yellow, Vector3(0, 0, -0.245))
	_add_low_rooftop("EastDeck", Vector3(150, 0, 0), Vector3(82, 20, 70), _materials.coral)
	_add_bounce_pad(Vector3(150, 22.0, 0))
	_add_ramp("EastDeckRamp", Vector3(72, 10.39391, 0), Vector3(78, 3, 36), _materials.yellow, Vector3(0, 0, 0.245))
	_add_low_rooftop("NorthDeck", Vector3(0, 0, -155), Vector3(70, 24, 78), _materials.blue)
	_add_bounce_pad(Vector3(0, 26.0, -155))
	_add_ramp("NorthDeckRamp", Vector3(0, 13.460839, -76), Vector3(36, 3, 82), _materials.neon_pink, Vector3(0.255, 0, 0))
	_add_low_rooftop("SouthDeck", Vector3(0, 0, 155), Vector3(70, 24, 78), _materials.violet)
	_add_bounce_pad(Vector3(0, 26.0, 155))
	_add_ramp("SouthDeckRamp", Vector3(0, 13.460839, 76), Vector3(36, 3, 82), _materials.neon_cyan, Vector3(-0.255, 0, 0))

	# Narrow upper bridge is a visible risk/reward route across the northern chase zone.
	_add_box("SkyBridge", Vector3(0, 38, -310), Vector3(160, 4, 18), _materials.metal, true)
	var sky_bridge := _mesh_with_prefix("SkyBridge_")
	if sky_bridge != null:
		sky_bridge.add_to_group("supported_elevated_structure")
		sky_bridge.set_meta("support_key", "practice_sky_bridge")
	for x in [-56.0, 56.0]:
		var pier := _add_box("SkyBridgePier", Vector3(x, 18, -310), Vector3(10, 36, 11), _materials.concrete, true)
		_mark_structural_support(pier, "practice_sky_bridge")
	_add_box("SkyBridgeRailLeft", Vector3(0, 41, -318), Vector3(160, 5, 2), _materials.neon_cyan, true)
	_add_box("SkyBridgeRailRight", Vector3(0, 41, -302), Vector3(160, 5, 2), _materials.neon_pink, true)
	_add_ramp("SkyBridgeWestRamp", Vector3(-118, 17.894495, -310), Vector3(82, 4, 18), _materials.yellow, Vector3(0, 0, 0.46))
	_add_ramp("SkyBridgeEastRamp", Vector3(118, 17.894495, -310), Vector3(82, 4, 18), _materials.yellow, Vector3(0, 0, -0.46))
	_add_bounce_pad(Vector3(0, 42.0, -310), 40.0)


func _add_low_rooftop(prefix: String, ground_position: Vector3, size: Vector3, material: Material) -> void:
	_add_box(prefix, ground_position + Vector3(0, size.y * 0.5, 0), size, material, true)
	_add_box(prefix + "Roof", ground_position + Vector3(0, size.y + 0.8, 0), Vector3(size.x + 4, 1.6, size.z + 4), _materials.concrete_light, true)
	for offset in [-1.0, 1.0]:
		_add_cylinder(prefix + "Vent", ground_position + Vector3(offset * size.x * 0.28, size.y + 4.0, 0), 2.6, 6.0, _materials.metal, true)


func _add_bounce_pad(position: Vector3, impulse: float = 34.0) -> void:
	var pad := BOUNCE_PAD_SCENE.instantiate() as Area3D
	pad.name = _unique_name("BouncePad")
	pad.position = position
	pad.launch_impulse = impulse
	add_child(pad)


func _build_overpass() -> void:
	_add_box("SouthOverpass", Vector3(0, 18, 245), Vector3(310, 4, 28), _materials.concrete, true)
	for x in [-100.0, 0.0, 100.0]:
		var support := _add_box("OverpassSupport", Vector3(x, 8, 245), Vector3(8, 16, 8), _materials.metal, true)
		_mark_structural_support(support, "practice_overpass")
	_add_ramp("OverpassWestRamp", Vector3(-190, 8.513373, 245), Vector3(78, 4, 28), _materials.coral, Vector3(0, 0, 0.24))
	_add_ramp("OverpassEastRamp", Vector3(190, 8.513373, 245), Vector3(78, 4, 28), _materials.teal, Vector3(0, 0, -0.24))
	for x in range(-130, 131, 52):
		_add_box("OverpassBarrier", Vector3(x, 22, 258), Vector3(34, 4, 3), _materials.yellow, true)


func _build_park() -> void:
	var center := Vector3(-310, 0, 320)
	_add_box("CityPark", center + Vector3(0, 0.25, 0), Vector3(170, 0.5, 150), _materials.grass, true)
	_add_box("ParkPathEW", center + Vector3(0, 0.55, 0), Vector3(158, 0.25, 18), _materials.concrete_light, true)
	_add_box("ParkPathNS", center + Vector3(0, 0.56, 0), Vector3(18, 0.26, 138), _materials.concrete_light, true)
	var tree_offsets := [Vector3(-55, 0, -45), Vector3(55, 0, -45), Vector3(-55, 0, 45), Vector3(55, 0, 45), Vector3(-30, 0, 62), Vector3(30, 0, 62)]
	for offset in tree_offsets:
		_add_cylinder("ParkTreeTrunk", center + offset + Vector3(0, 5, 0), 2.0, 10.0, _materials.wood, true)
		_add_sphere("ParkTreeTop", center + offset + Vector3(0, 13, 0), 7.5, _materials.leaves, true)
	for offset in [Vector3(-36, 1.5, -12), Vector3(36, 1.5, 12)]:
		_add_box("ParkBenchSeat", center + offset, Vector3(22, 2.5, 5), _materials.wood, true)
		_add_box("ParkBenchBack", center + offset + Vector3(0, 4, 2), Vector3(22, 5, 2), _materials.wood, true)
	_add_world_label("ParkLabel", center + Vector3(0, 24, -62), "BOUNCE PARK", Color(0.83, 1.0, 0.78), 44)


func _build_street_details() -> void:
	for coordinate in range(-420, 421, 70):
		if abs(coordinate) < 90:
			continue
		_add_street_light(Vector3(-36, 0, coordinate))
		_add_street_light(Vector3(36, 0, coordinate))
		_add_street_light(Vector3(coordinate, 0, -36))
		_add_street_light(Vector3(coordinate, 0, 36))

	_add_bus_stop("WestBusStop", Vector3(-250, 0, -72), 0.0)
	_add_bus_stop("EastBusStop", Vector3(250, 0, 72), PI)
	_add_bus_stop("NorthBusStop", Vector3(72, 0, -250), -PI * 0.5)
	_add_bus_stop("SouthBusStop", Vector3(-72, 0, 250), PI * 0.5)

	var cone_positions := [Vector3(-210, 2, -22), Vector3(-195, 2, -22), Vector3(195, 2, 22), Vector3(210, 2, 22)]
	for position in cone_positions:
		_add_cylinder("ConstructionCone", position, 2.2, 4.0, _materials.coral, true)

	# Four diagonal vents preserve the plaza detail without intersecting the four traversal decks.
	for index in range(4):
		var angle := TAU * (float(index) + 0.5) / 4.0
		var vent_position := Vector3(cos(angle) * 105.0, 2.5, sin(angle) * 105.0)
		_add_cylinder("PlazaVent", vent_position, 3.2, 5.0, _materials.metal, true)


func _add_street_light(position: Vector3) -> void:
	_add_cylinder("StreetLightPole", position + Vector3(0, 7, 0), 0.65, 14.0, _materials.metal, true)
	_add_box("StreetLightArm", position + Vector3(2.8, 13.5, 0), Vector3(5.6, 0.7, 0.7), _materials.metal, false)
	_add_sphere("StreetLightGlow", position + Vector3(5.2, 12.8, 0), 1.4, _materials.window_warm)


func _add_bus_stop(prefix: String, position: Vector3, yaw: float) -> void:
	var rotation := Vector3(0, yaw, 0)
	_add_box(prefix + "Back", position + Vector3(0, 5, 0), Vector3(24, 10, 1.2), _materials.glass, true, rotation)
	_add_box(prefix + "Roof", position + Vector3(0, 10.5, 2.8), Vector3(26, 1.2, 7), _materials.metal, true, rotation)
	_add_box(prefix + "Bench", position + Vector3(0, 2.2, 3), Vector3(16, 2.4, 4), _materials.yellow, true, rotation)


func _build_spawn_zones() -> void:
	_add_cylinder("HostSpawnPad", Vector3(-360, 0.7, 0), 22.0, 1.4, _materials.spawn_blue, true)
	_add_cylinder("ClientSpawnPad", Vector3(360, 0.7, 0), 22.0, 1.4, _materials.spawn_red, true)
	_add_box("HostSpawnShield", Vector3(-405, 10, 0), Vector3(8, 20, 80), _materials.blue, true)
	_add_box("ClientSpawnShield", Vector3(405, 10, 0), Vector3(8, 20, 80), _materials.coral, true)
	_add_world_label("HostSpawnLabel", Vector3(-360, 17, 0), "BLUE SPAWN", Color(0.45, 0.85, 1.0), 36)
	_add_world_label("ClientSpawnLabel", Vector3(360, 17, 0), "RED SPAWN", Color(1.0, 0.58, 0.62), 36)


func _build_boundaries() -> void:
	# Water and barriers communicate the boundary. Four floor-to-roof walls make
	# Practice genuinely enclosed, so a strong fling cannot escape over a low curb.
	_add_box("NorthWater", Vector3(0, -0.2, -478), Vector3(960, 0.5, 36), _materials.water, false)
	_add_box("SouthWater", Vector3(0, -0.2, 478), Vector3(960, 0.5, 36), _materials.water, false)
	_add_box("WestWater", Vector3(-478, -0.18, 0), Vector3(36, 0.5, 960), _materials.water, false)
	_add_box("EastWater", Vector3(478, -0.18, 0), Vector3(36, 0.5, 960), _materials.water, false)
	_add_perimeter_wall("NorthPerimeterWall", Vector3(0, 105, -494), Vector3(1000, 210, 8))
	_add_perimeter_wall("SouthPerimeterWall", Vector3(0, 105, 494), Vector3(1000, 210, 8))
	_add_perimeter_wall("WestPerimeterWall", Vector3(-494, 105, 0), Vector3(8, 210, 1000))
	_add_perimeter_wall("EastPerimeterWall", Vector3(494, 105, 0), Vector3(8, 210, 1000))
	# Opaque lower kick-walls clearly communicate the boundary at player height;
	# transparent upper panels preserve the skyline and existing city detail.
	_add_box("NorthConstructionKickWall", Vector3(0, 14, -493), Vector3(1000, 28, 6), _materials.yellow, false)
	_add_box("SouthConstructionKickWall", Vector3(0, 14, 493), Vector3(1000, 28, 6), _materials.yellow, false)
	_add_box("WestConstructionKickWall", Vector3(-493, 14, 0), Vector3(6, 28, 1000), _materials.coral, false)
	_add_box("EastConstructionKickWall", Vector3(493, 14, 0), Vector3(6, 28, 1000), _materials.teal, false)
	for coordinate in range(-440, 441, 80):
		_add_box("BoundaryBarrierN", Vector3(coordinate, 4, -458), Vector3(54, 8, 5), _materials.concrete_light if coordinate % 160 == 0 else _materials.metal, true)
		_add_box("BoundaryBarrierS", Vector3(coordinate, 4, 458), Vector3(54, 8, 5), _materials.concrete_light if coordinate % 160 == 0 else _materials.metal, true)
		_add_box("BoundaryBarrierW", Vector3(-458, 4, coordinate), Vector3(5, 8, 54), _materials.concrete_light if coordinate % 160 == 0 else _materials.metal, true)
		_add_box("BoundaryBarrierE", Vector3(458, 4, coordinate), Vector3(5, 8, 54), _materials.concrete_light if coordinate % 160 == 0 else _materials.metal, true)


func _add_perimeter_wall(prefix: String, position: Vector3, size: Vector3) -> void:
	var wall := _add_box(prefix, position, size, _materials.roof_glass, false)
	wall.add_to_group("practice_perimeter_wall")
	var wall_shape := BoxShape3D.new()
	wall_shape.size = size
	var wall_collision := _add_collision_shape(prefix, position, Vector3.ZERO, wall_shape)
	wall_collision.add_to_group("practice_perimeter_wall_collision")


func _build_practice_roof_and_ceiling_detail() -> void:
	# The practice city is an indoor training simulation. A translucent roof keeps
	# the skyline visible while giving high bounces a real, readable ceiling.
	var roof_height := 210.0
	var roof := _add_box("PracticeArenaRoof", Vector3(0, roof_height, 0), Vector3(980, 3.0, 980), _materials.roof_glass, false)
	roof.add_to_group("arena_roof")
	var roof_shape := BoxShape3D.new()
	roof_shape.size = Vector3(980, 3.0, 980)
	var roof_collision := _add_collision_shape("PracticeArenaRoof", Vector3(0, roof_height, 0), Vector3.ZERO, roof_shape)
	roof_collision.add_to_group("arena_roof_collision")

	# Eight perimeter columns make the roof read as constructed rather than a
	# floating glass plane, without adding blockers to the central movement lanes.
	for position in [
		Vector3(-462, roof_height * 0.5, -462), Vector3(0, roof_height * 0.5, -462), Vector3(462, roof_height * 0.5, -462),
		Vector3(-462, roof_height * 0.5, 462), Vector3(0, roof_height * 0.5, 462), Vector3(462, roof_height * 0.5, 462),
		Vector3(-462, roof_height * 0.5, 0), Vector3(462, roof_height * 0.5, 0),
	]:
		var column := _add_box("RoofSupportColumn", position, Vector3(9, roof_height, 9), _materials.metal, true)
		_mark_structural_support(column, "practice_roof")

	# Cross-bay trusses, suspended light bars, and service drops add a second
	# architectural layer above the existing streets and rooftops.
	for offset in range(-360, 361, 120):
		var x_truss := _add_box("RoofTrussX", Vector3(float(offset), roof_height - 3.0, 0), Vector3(4, 5, 930), _materials.metal, false)
		_mark_practice_detail(x_truss)
		var z_truss := _add_box("RoofTrussZ", Vector3(0, roof_height - 2.7, float(offset)), Vector3(930, 4.4, 4), _materials.metal, false)
		_mark_practice_detail(z_truss)
	for x in [-300.0, -100.0, 100.0, 300.0]:
		for z in [-245.0, 245.0]:
			var drop := _add_box("CeilingServiceDrop", Vector3(x, roof_height - 10.0, z), Vector3(1.2, 16, 1.2), _materials.metal, false)
			_mark_practice_detail(drop)
			var fixture := _add_box("CeilingLightBar", Vector3(x, roof_height - 18.0, z), Vector3(32, 1.6, 4), _materials.neon_cyan if x < 0 else _materials.neon_pink, false)
			_mark_practice_detail(fixture)


func _mark_structural_support(node: Node, support_key: String) -> void:
	node.add_to_group("structural_support")
	node.set_meta("support_key", support_key)


func _mark_practice_detail(node: Node) -> void:
	node.add_to_group("practice_environment_detail")


func _mesh_with_prefix(prefix: String) -> MeshInstance3D:
	for child in _visuals.get_children():
		if child is MeshInstance3D and String(child.name).begins_with(prefix):
			return child as MeshInstance3D
	return null


func _build_landmark_lights() -> void:
	for position in [Vector3(-72, 24, -38), Vector3(72, 24, -38), Vector3(0, 24, 36)]:
		var light := OmniLight3D.new()
		light.name = _unique_name("PlazaLight")
		light.position = position
		light.light_color = Color(0.22, 0.82, 1.0) if position.x <= 0.0 else Color(1.0, 0.32, 0.55)
		light.light_energy = 3.2
		light.omni_range = 95.0
		light.shadow_enabled = false
		add_child(light)


func _build_clouds() -> void:
	var cloud_centers: Array[Vector3] = [
		Vector3(-260, 255, -250),
		Vector3(210, 285, -120),
		Vector3(285, 245, 270),
		Vector3(-120, 295, 260),
	]
	for center in cloud_centers:
		_add_sphere("CloudPuff", center + Vector3(-22, 0, 0), 24.0, _materials.cloud)
		_add_sphere("CloudPuff", center + Vector3(0, 9, 0), 31.0, _materials.cloud)
		_add_sphere("CloudPuff", center + Vector3(27, 2, 4), 26.0, _materials.cloud)


func _make_material(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _make_emissive_material(color: Color, energy: float) -> StandardMaterial3D:
	var material := _make_material(color, 0.34, 0.08)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material


func _make_textured_material(texture: Texture2D, tint: Color, roughness: float, uv_scale: Vector3) -> StandardMaterial3D:
	var material := _make_material(tint, roughness, 0.0)
	material.albedo_texture = texture
	material.uv1_scale = uv_scale
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return material


func _make_window_material(tint: Color, energy: float) -> StandardMaterial3D:
	var material := _make_textured_material(WINDOWS_TEXTURE, tint, 0.28, Vector3(5, 1, 1))
	material.emission_enabled = true
	material.emission = tint
	material.emission_texture = WINDOWS_TEXTURE
	material.emission_energy_multiplier = energy
	return material


func _make_billboard_material(texture: Texture2D) -> StandardMaterial3D:
	var material := _make_material(Color.WHITE, 0.42, 0.0)
	material.albedo_texture = texture
	material.emission_enabled = true
	material.emission = Color.WHITE
	material.emission_texture = texture
	material.emission_energy_multiplier = 0.42
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return material


func _add_box(prefix: String, position: Vector3, size: Vector3, material: Material, collision: bool, rotation: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh_resource := BoxMesh.new()
	mesh_resource.size = size
	var instance := MeshInstance3D.new()
	instance.name = _unique_name(prefix)
	instance.mesh = mesh_resource
	instance.material_override = material
	instance.position = position
	instance.rotation = rotation
	# BUG-028: non-collidable boxes here are pure decoration - window bands,
	# trim, signage backing. They were still rendered into the directional
	# shadow map, which at a 700m shadow distance meant hundreds of extra
	# shadow-pass draws for geometry that casts nothing a player can see.
	if not collision:
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visuals.add_child(instance)
	if collision:
		var shape_resource := BoxShape3D.new()
		shape_resource.size = size
		_add_collision_shape(prefix, position, rotation, shape_resource)
	return instance


func _add_ramp(prefix: String, position: Vector3, size: Vector3, material: Material, rotation: Vector3) -> MeshInstance3D:
	var runs_on_x := size.x >= size.z
	var run_length := size.x if runs_on_x else size.z
	var width := size.z if runs_on_x else size.x
	var slope_angle := rotation.z if runs_on_x else rotation.x
	var high_sign := signf(slope_angle) if runs_on_x else -signf(slope_angle)
	var rise := tan(absf(slope_angle)) * run_length
	var half_thickness := cos(absf(slope_angle)) * size.y * 0.5
	var underside_y := -rise * 0.5 - half_thickness
	var low_surface_y := -rise * 0.5 + half_thickness
	var high_surface_y := rise * 0.5 + half_thickness
	var half_run := run_length * 0.5
	var half_width := width * 0.5
	var low_axis := -high_sign * half_run
	var high_axis := high_sign * half_run
	var points := PackedVector3Array()
	if runs_on_x:
		points = PackedVector3Array([
			Vector3(low_axis, underside_y, -half_width), Vector3(low_axis, underside_y, half_width),
			Vector3(high_axis, underside_y, -half_width), Vector3(high_axis, underside_y, half_width),
			Vector3(low_axis, low_surface_y, -half_width), Vector3(low_axis, low_surface_y, half_width),
			Vector3(high_axis, high_surface_y, -half_width), Vector3(high_axis, high_surface_y, half_width),
		])
	else:
		points = PackedVector3Array([
			Vector3(-half_width, underside_y, low_axis), Vector3(half_width, underside_y, low_axis),
			Vector3(-half_width, underside_y, high_axis), Vector3(half_width, underside_y, high_axis),
			Vector3(-half_width, low_surface_y, low_axis), Vector3(half_width, low_surface_y, low_axis),
			Vector3(-half_width, high_surface_y, high_axis), Vector3(half_width, high_surface_y, high_axis),
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
	var instance := MeshInstance3D.new()
	instance.name = _unique_name(prefix)
	instance.mesh = mesh_resource
	instance.position = position
	instance.add_to_group("closed_ramp")
	_visuals.add_child(instance)
	var shape_resource := ConvexPolygonShape3D.new()
	shape_resource.points = points
	var collision := _add_collision_shape(prefix, position, Vector3.ZERO, shape_resource)
	collision.add_to_group("closed_ramp_collision")
	return instance


func _add_triangle(surface: SurfaceTool, first: Vector3, second: Vector3, third: Vector3) -> void:
	surface.add_vertex(first)
	surface.add_vertex(second)
	surface.add_vertex(third)


func _add_cylinder(prefix: String, position: Vector3, radius: float, height: float, material: Material, collision: bool) -> MeshInstance3D:
	var mesh_resource := CylinderMesh.new()
	mesh_resource.top_radius = radius
	mesh_resource.bottom_radius = radius
	mesh_resource.height = height
	mesh_resource.radial_segments = 24
	var instance := MeshInstance3D.new()
	instance.name = _unique_name(prefix)
	instance.mesh = mesh_resource
	instance.material_override = material
	instance.position = position
	_visuals.add_child(instance)
	if collision:
		var shape_resource := CylinderShape3D.new()
		shape_resource.radius = radius
		shape_resource.height = height
		_add_collision_shape(prefix, position, Vector3.ZERO, shape_resource)
	return instance


func _add_sphere(prefix: String, position: Vector3, radius: float, material: Material, collision: bool = false) -> MeshInstance3D:
	var mesh_resource := SphereMesh.new()
	mesh_resource.radius = radius
	mesh_resource.height = radius * 2.0
	mesh_resource.radial_segments = 20
	mesh_resource.rings = 10
	var instance := MeshInstance3D.new()
	instance.name = _unique_name(prefix)
	instance.mesh = mesh_resource
	instance.material_override = material
	instance.position = position
	if material == _materials.cloud:
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visuals.add_child(instance)
	if collision:
		instance.add_to_group("solid_visible_prop")
		var shape_resource := SphereShape3D.new()
		shape_resource.radius = radius
		var collision_shape := _add_collision_shape(prefix, position, Vector3.ZERO, shape_resource)
		collision_shape.add_to_group("solid_visible_prop_collision")
	return instance


func _add_billboard(prefix: String, position: Vector3, size: Vector2, material: Material) -> void:
	_add_box(prefix + "Frame", position - Vector3(0, 0, 0.22), Vector3(size.x + 1.4, size.y + 1.4, 0.6), _materials.metal, false)
	var quad := QuadMesh.new()
	quad.size = size
	var instance := MeshInstance3D.new()
	instance.name = _unique_name(prefix + "Art")
	instance.mesh = quad
	instance.material_override = material
	instance.position = position + Vector3(0, 0, 0.12)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visuals.add_child(instance)


func _add_world_label(prefix: String, position: Vector3, text: String, color: Color, font_size: int) -> void:
	var label := Label3D.new()
	label.name = _unique_name(prefix)
	label.position = position
	label.text = text
	label.font_size = font_size
	label.outline_size = 10
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_visuals.add_child(label)


func _add_collision_shape(prefix: String, position: Vector3, rotation: Vector3, shape: Shape3D) -> CollisionShape3D:
	var collision := CollisionShape3D.new()
	collision.name = _unique_name(prefix + "Collision")
	collision.position = position
	collision.rotation = rotation
	collision.shape = shape
	_collision_body.add_child(collision)
	return collision


func _unique_name(prefix: String) -> String:
	_name_counter += 1
	return "%s_%03d" % [prefix, _name_counter]
