extends SceneTree

## The practice map is image-locked to the "Practice Map - Blueprint" sheet:
## 28 x 15 grid units, 1 GU = 2.888 world units, world_x = (gx - 14) * GU,
## world_z = (7.5 - gy) * GU. This contract audits the coordinate table that
## came off the sheet - station positions, height bands, interaction
## directions, and the visible inventory - never just total counts.

const PRACTICE := preload("res://scenes/world/practice_arena.tscn")
const MAIN_SCENE := preload("res://scenes/main.tscn")
const GEOMETRY := preload("res://scripts/environment/practice_facility_geometry.gd")

const POSITION_TOLERANCE := 0.05
const HEIGHT_TOLERANCE := 0.05

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var arena := PRACTICE.instantiate() as Node3D
	root.add_child(arena)
	await process_frame
	await process_frame

	_check_dummy_stations(arena)
	_check_cover_blocks(arena)
	_check_hop_pads(arena)
	_check_rebound_panels(arena)
	_check_ramps(arena)
	_check_height_bands(arena)

	arena.queue_free()
	await process_frame

	await _check_main_scene_wiring()

	if failures.is_empty():
		print("PRACTICE BLUEPRINT CONTRACT PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("PRACTICE BLUEPRINT FAILURES: %d" % failures.size())
	quit(1)


## Eight dummy stations at the sheet coordinates, each marked by a red ring;
## B and G are the two raised stations with solid pedestals.
func _check_dummy_stations(arena: Node3D) -> void:
	for station_value in GEOMETRY.DUMMY_STATIONS:
		var station := station_value as Dictionary
		var letter := str(station["letter"])
		var expected := GEOMETRY.world(station["grid"] as Vector2)
		var ring := _mesh_with_prefix(arena, "StationRing" + letter)
		_check(ring != null, "Station %s needs its red target ring" % letter)
		if ring != null:
			_check(_flat_distance(ring.position, expected) <= POSITION_TOLERANCE,
				"Station %s ring must sit at blueprint %s, found %s" % [letter, str(expected), str(ring.position)])
			var material := ring.material_override as StandardMaterial3D
			_check(material != null and material.emission_enabled,
				"Station %s ring must read as a lit red target marker" % letter)
		var pedestal := _mesh_with_prefix(arena, "StationPedestal" + letter)
		if bool(station["raised"]):
			_check(pedestal != null, "Raised station %s needs its 0.4 GU pedestal" % letter)
			if pedestal != null:
				var cylinder := pedestal.mesh as CylinderMesh
				_check(cylinder != null and absf(cylinder.height - GEOMETRY.PEDESTAL_HEIGHT) <= HEIGHT_TOLERANCE,
					"Station %s pedestal must raise the dummy by exactly 0.4 GU" % letter)
		else:
			_check(pedestal == null, "Ground station %s must not grow a pedestal" % letter)


## Four low cover blocks, 3 x 1.8 x 1.2 GU, at the sheet coordinates.
func _check_cover_blocks(arena: Node3D) -> void:
	var blocks: Array[MeshInstance3D] = []
	for node in arena.find_children("CoverBlock_*", "MeshInstance3D", true, false):
		blocks.append(node as MeshInstance3D)
	_check(blocks.size() == 4, "Blueprint places exactly 4 low cover blocks, found %d" % blocks.size())
	for grid_position in GEOMETRY.COVER_GRID_POSITIONS:
		var expected := GEOMETRY.world(grid_position, GEOMETRY.COVER_SIZE.y * 0.5)
		var found := false
		for block in blocks:
			if _flat_distance(block.position, expected) <= POSITION_TOLERANCE:
				found = true
				var box := block.mesh as BoxMesh
				_check(box != null and box.size.is_equal_approx(GEOMETRY.COVER_SIZE),
					"Cover block at %s must be 3 x 1.8 x 1.2 GU" % str(grid_position))
		_check(found, "Blueprint cover block missing at grid %s" % str(grid_position))


## Twelve hop pads in four groups of three, tuned for small hops - the pads
## must never turn into launch pads.
func _check_hop_pads(arena: Node3D) -> void:
	var pads: Array[Area3D] = []
	for node in arena.find_children("HopPad_*", "Area3D", true, false):
		pads.append(node as Area3D)
	_check(pads.size() == 12, "Blueprint places 12 training hop pads, found %d" % pads.size())
	for grid_position in GEOMETRY.HOP_PAD_GRID_POSITIONS:
		var expected := GEOMETRY.world(grid_position)
		var found := false
		for pad in pads:
			if _flat_distance(pad.position, expected) <= POSITION_TOLERANCE:
				found = true
				_check(float(pad.get("launch_impulse")) <= 26.0,
					"Hop pad at %s must stay a small controlled hop, not a launch" % str(grid_position))
		_check(found, "Blueprint hop pad missing at grid %s" % str(grid_position))


## Four wall bounce panels at the wall centres, 1.5 GU up, each reflecting
## back into the arena with the specified 10 percent speed gain.
func _check_rebound_panels(arena: Node3D) -> void:
	var panels: Array[Area3D] = []
	for node_value in root.get_tree().get_nodes_in_group("practice_rebound_panel"):
		var node := node_value as Area3D
		if node != null and arena.is_ancestor_of(node):
			panels.append(node)
	_check(panels.size() == 4, "Blueprint places 4 wall bounce panels, found %d" % panels.size())
	for panel_spec in GEOMETRY.REBOUND_PANELS:
		var inward := (panel_spec["inward"] as Vector3).normalized()
		var expected: Vector3 = (panel_spec["face"] as Vector3) + inward * GEOMETRY.PANEL_PROTRUSION * 0.5
		var found := false
		for panel in panels:
			if panel.position.distance_to(expected) <= POSITION_TOLERANCE:
				found = true
				var panel_inward := (panel.get("inward") as Vector3).normalized()
				_check(panel_inward.dot(inward) > 0.99,
					"%s must reflect players back toward the arena centre" % panel.name)
				_check(absf(float(panel.get("speed_multiplier")) - GEOMETRY.PANEL_SPEED_MULTIPLIER) < 0.001,
					"%s must boost horizontal speed by exactly 10 percent" % panel.name)
				_check(float(panel.get("minimum_speed")) >= 4.0,
					"%s must ignore slow touches - panels fire only at meaningful speed" % panel.name)
				_check(absf(panel.position.y - GEOMETRY.PANEL_CENTER_Y) <= HEIGHT_TOLERANCE,
					"%s must centre 1.5 GU above the floor" % panel.name)
		_check(found, "Blueprint wall panel missing at %s" % str(expected))


## Side ramps crest at 1.6 GU one grid unit clear of their wall; every wedge
## aims squarely at its corner dummy station.
func _check_ramps(arena: Node3D) -> void:
	for ramp_spec in GEOMETRY.SIDE_RAMPS:
		var prefix := str(ramp_spec["prefix"])
		var crest := -INF
		var segments := 0
		for node in arena.find_children(prefix + "_*", "MeshInstance3D", true, false):
			var segment := node as MeshInstance3D
			if segment == null or segment.mesh == null:
				continue
			segments += 1
			crest = maxf(crest, segment.position.y + segment.mesh.get_aabb().end.y)
		_check(segments == GEOMETRY.SIDE_RAMP_SEGMENTS,
			"%s must be built from %d curved segments, found %d" % [prefix, GEOMETRY.SIDE_RAMP_SEGMENTS, segments])
		_check(absf(crest - GEOMETRY.SIDE_RAMP_HEIGHT) <= HEIGHT_TOLERANCE,
			"%s must crest at 1.6 GU, found %.3f" % [prefix, crest])
	for wedge_spec in GEOMETRY.WEDGES:
		var wedge := _mesh_with_prefix(arena, str(wedge_spec["prefix"]))
		_check(wedge != null, "%s missing" % str(wedge_spec["prefix"]))
		if wedge == null:
			continue
		var center := GEOMETRY.world(wedge_spec["grid"] as Vector2)
		_check(_flat_distance(wedge.position, center) <= POSITION_TOLERANCE,
			"%s must sit at blueprint grid %s" % [wedge.name, str(wedge_spec["grid"])])
		var station := GEOMETRY.station_by_letter(str(wedge_spec["aim_letter"]))
		var target := GEOMETRY.world(station["grid"] as Vector2)
		var direction := Vector3(target.x - center.x, 0.0, target.z - center.z).normalized()
		var expected_yaw := atan2(-direction.x, -direction.z)
		_check(absf(angle_difference(wedge.rotation.y, expected_yaw)) <= 0.02,
			"%s must launch toward dummy station %s" % [wedge.name, str(wedge_spec["aim_letter"])])


## Height bands measured with real physics rays: platform top at 0.6 GU,
## solid wall band to 3 GU, transparent enclosure to 5 GU, canopy at 5 GU.
func _check_height_bands(arena: Node3D) -> void:
	var space := arena.get_world_3d().direct_space_state

	var platform_hit := _ray(space, Vector3(0, 5, 0), Vector3(0, -5, 0))
	_check(not platform_hit.is_empty() and absf(float(platform_hit["position"].y) - GEOMETRY.PLATFORM_TOP_Y) <= HEIGHT_TOLERANCE,
		"Spawn platform top must sit exactly 0.6 GU above the turf")
	var skirt_hit := _ray(space, Vector3(GEOMETRY.PLATFORM_TOP_HALF_X + GEOMETRY.PLATFORM_SKIRT * 0.5, 5, 0), Vector3(0, -5.2, 0))
	_check(not skirt_hit.is_empty() and float(skirt_hit["position"].y) > 0.1 and float(skirt_hit["position"].y) < GEOMETRY.PLATFORM_TOP_Y,
		"Platform edges must ramp down to the turf, not drop vertically")

	var roof_hit := _ray(space, Vector3(0, GEOMETRY.PLATFORM_TOP_Y + 3.0, 0), Vector3(0, 30, 0))
	_check(not roof_hit.is_empty() and absf(float(roof_hit["position"].y) - GEOMETRY.ROOF_UNDERSIDE_Y) <= HEIGHT_TOLERANCE,
		"Canopy roof underside must close the arena at exactly 5 GU")

	var wall_hit := _ray(space, Vector3(20, GEOMETRY.PANEL_CENTER_Y, -10), Vector3(0, 0, -15))
	_check(not wall_hit.is_empty() and absf(absf(float(wall_hit["position"].z)) - GEOMETRY.WALL_INNER_Z) <= HEIGHT_TOLERANCE,
		"Solid wall band must present its inner face 7 GU from centre")
	var enclosure_hit := _ray(space, Vector3(20, 11.5, -10), Vector3(0, 0, -15))
	_check(not enclosure_hit.is_empty() and absf(absf(float(enclosure_hit["position"].z)) - GEOMETRY.WALL_INNER_Z) <= 0.1,
		"Transparent enclosure must keep the same inner face as the solid wall band")
	# Probe at z = 6: outside the side ramp's 3 GU width, inside the panel's
	# 5 GU width - at z = 0 the east side ramp legitimately fronts the panel.
	var panel_hit := _ray(space, Vector3(30, GEOMETRY.PANEL_CENTER_Y, 6), Vector3(15, 0, 0))
	var panel_face := GEOMETRY.WALL_INNER_X - GEOMETRY.PANEL_PROTRUSION
	_check(not panel_hit.is_empty() and absf(float(panel_hit["position"].x) - panel_face) <= HEIGHT_TOLERANCE,
		"East wall panel must protrude 0.15 GU past the wall face")

	var turf_hit := _ray(space, Vector3(12, 3, 0), Vector3(0, -4, 0))
	_check(not turf_hit.is_empty() and absf(float(turf_hit["position"].y)) <= 0.03,
		"Floor markings must stay visual only - the turf plane is the walking surface")


## main.tscn wiring: eight light-gray training dummies on the stations, and
## the single player spawn on the centre platform facing the sheet's top edge.
func _check_main_scene_wiring() -> void:
	var game := MAIN_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	var dummies: Array[RigidBody3D] = []
	for node_value in root.get_tree().get_nodes_in_group("training_dummy"):
		var dummy := node_value as RigidBody3D
		if dummy != null and game.is_ancestor_of(dummy):
			dummies.append(dummy)
	_check(dummies.size() == 8, "The blueprint stations eight training dummies, found %d" % dummies.size())
	var names: Dictionary = {}
	for station_value in GEOMETRY.DUMMY_STATIONS:
		var station := station_value as Dictionary
		var letter := str(station["letter"])
		var expected := GEOMETRY.world(station["grid"] as Vector2)
		var station_floor := GEOMETRY.station_floor_y(station)
		var found := false
		for dummy in dummies:
			if _flat_distance(dummy.position, expected) > POSITION_TOLERANCE:
				continue
			found = true
			_check(dummy.position.y > station_floor + 1.0,
				"Dummy %s must start above its station surface" % letter)
			var color := dummy.get("blob_color") as Color
			var neutral := Color("D6D8D9")
			_check(absf(color.r - neutral.r) < 0.03 and absf(color.g - neutral.g) < 0.03 and absf(color.b - neutral.b) < 0.03,
				"Dummy %s must wear the neutral light-gray training body" % letter)
			var display_name := str(dummy.get("display_name"))
			_check(not display_name.is_empty() and not names.has(display_name),
				"Dummy %s needs a unique player-facing name" % letter)
			names[display_name] = true
		_check(found, "No training dummy stationed at blueprint %s" % letter)

	var spawn_manager := game.get_node("SpawnManager")
	var spawn: Vector3 = spawn_manager.call("get_spawn_for_slot", 0)
	_check(absf(spawn.x) <= GEOMETRY.PLATFORM_TOP_HALF_X and absf(spawn.z) <= GEOMETRY.PLATFORM_TOP_HALF_Z,
		"The single player spawn must sit on the centre platform")
	var yaw := float(spawn_manager.call("get_spawn_yaw_for_slot", 0))
	_check(absf(yaw) < 0.01, "Player spawn must face the top of the blueprint (world -Z)")
	game.queue_free()
	await process_frame


func _ray(space: PhysicsDirectSpaceState3D, from: Vector3, offset: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, from + offset, 1)
	return space.intersect_ray(query)


func _flat_distance(actual: Vector3, expected: Vector3) -> float:
	return Vector2(actual.x - expected.x, actual.z - expected.z).length()


func _mesh_with_prefix(parent: Node, prefix: String) -> MeshInstance3D:
	for node in parent.find_children(prefix + "*", "MeshInstance3D", true, false):
		return node as MeshInstance3D
	return null


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
