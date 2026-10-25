extends SceneTree

const AETHER_CITADEL := preload("res://scenes/world/maps/sky_temple.tscn")
const D := 5.776
const GU := 2.888

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var arena := AETHER_CITADEL.instantiate() as Node3D
	root.add_child(arena)
	await process_frame
	await physics_frame
	var audit := arena.call("get_map_audit") as Dictionary
	var blueprint := audit.get("blueprint", {}) as Dictionary
	_check(String(arena.get("map_name")) == "Aether Citadel", "Sky Temple slot is renamed Aether Citadel")
	_check(blueprint.get("footprint_gu", Vector2.ZERO) == Vector2(48, 72), "Aether Citadel uses the approved 48 x 72 GU footprint")
	_check(blueprint.get("interior_gu", Vector2.ZERO) == Vector2(44, 68), "Aether Citadel preserves the approved 44 x 68 GU interior")
	_check(is_equal_approx(float(blueprint.get("gu_scale_d", 0.0)), 0.5), "Aether Citadel keeps 1 GU equal to 0.5 blob diameters")
	_check(is_equal_approx(float(blueprint.get("roof_height_gu", 0.0)), 14.5), "Stormglass roof is exactly 14.5 GU high")
	_check(is_equal_approx(float(blueprint.get("solid_wall_height_gu", 0.0)), 4.0), "Solid parapet is exactly 4 GU high")
	var expected_counts := {
		"continuous_floor": 1, "spawn_sanctum": 2, "aether_crown": 1,
		"crescent_wing_terrace": 2, "ascension_ramp": 4, "boost_pad": 4,
		"wind_arch": 4, "rebound_pylon": 8, "low_wing_wall": 6,
		"wingstream_rail": 4, "wall_rebound_fin": 12, "skyrail_ledge": 8,
		"wall_module": 8, "transparent_roof": 1,
	}
	for kind in expected_counts:
		_check(_elements(arena, kind).size() == int(expected_counts[kind]), "Aether Citadel needs exactly %d %s objects" % [expected_counts[kind], kind])
	_check(_has_grid_position(arena, "aether_crown", Vector2(24, 36)), "Aether Crown must remain at blueprint center (24,36)")
	for expected in [Vector2(24, 6), Vector2(24, 66)]:
		_check(_has_grid_position(arena, "spawn_sanctum", expected), "Spawn Sanctum missing approved coordinate %s" % expected)
	for expected in [Vector2(6, 36), Vector2(42, 36)]:
		_check(_has_grid_position(arena, "crescent_wing_terrace", expected), "Crescent terrace missing approved coordinate %s" % expected)
	for expected in [Vector2(6, 20), Vector2(42, 20), Vector2(6, 52), Vector2(42, 52)]:
		_check(_has_grid_position(arena, "ascension_ramp", expected), "Ascension ramp missing approved coordinate %s" % expected)
	for expected in [Vector2(19, 11), Vector2(29, 11), Vector2(19, 61), Vector2(29, 61)]:
		_check(_has_grid_position(arena, "boost_pad", expected), "Sun-Seal boost missing approved coordinate %s" % expected)
	for expected in [Vector2(15, 18), Vector2(33, 18), Vector2(15, 54), Vector2(33, 54)]:
		_check(_has_grid_position(arena, "wind_arch", expected), "Wind Arch missing approved coordinate %s" % expected)
	for expected in [Vector2(17, 25), Vector2(31, 25), Vector2(15, 33), Vector2(33, 33), Vector2(15, 39), Vector2(33, 39), Vector2(17, 47), Vector2(31, 47)]:
		_check(_has_grid_position(arena, "rebound_pylon", expected), "Rebound pylon missing approved coordinate %s" % expected)
	var spawns := arena.call("get_spawn_points") as Array
	_check(spawns.size() == 2, "Aether Citadel exposes exactly two playable spawns")
	if spawns.size() == 2:
		_check(is_equal_approx((spawns[0] as Marker3D).position.z, 30.0 * GU), "Dawn spawn remains at blueprint (24,6)")
		_check(is_equal_approx((spawns[1] as Marker3D).position.z, -30.0 * GU), "Dusk spawn remains at blueprint (24,66)")
		for spawn_value in spawns:
			var spawn := spawn_value as Marker3D
			var forward := -spawn.global_basis.z.normalized()
			var toward_center := -Vector3(spawn.position.x, 0, spawn.position.z).normalized()
			_check(forward.dot(toward_center) > 0.98, "Both Aether Citadel spawn cameras face center")
	_check(_group_descendants(arena, &"environment_model").is_empty(), "Aether Citadel must not receive generic prop decoration")
	_check(arena.get_node_or_null("Presentation") == null, "Aether Citadel reserves every object for the approved blueprint")
	var roof_elements := _elements(arena, "transparent_roof")
	if not roof_elements.is_empty():
		_check(is_equal_approx((roof_elements[0].get_meta("gu_size", Vector3.ZERO) as Vector3).y, 0.4), "Stormglass roof collision is exactly 0.4 GU thick")
	var probe := RigidBody3D.new()
	probe.mass = 2.0
	probe.gravity_scale = 0.0
	probe.collision_layer = 2
	probe.collision_mask = 1
	root.add_child(probe)
	await physics_frame
	var vortex := _first(arena, "aether_crown")
	if vortex != null:
		_check(vortex.has_method("activate_body"), "Aether Crown exposes its vortex interaction")
		var vortex_trigger := vortex.get_child(0) as CollisionShape3D
		var vortex_trigger_shape := vortex_trigger.shape as CylinderShape3D if vortex_trigger != null else null
		_check(vortex_trigger_shape != null and vortex_trigger.position.y - vortex_trigger_shape.height * 0.5 <= 4.34 and vortex_trigger.position.y + vortex_trigger_shape.height * 0.5 >= 8.4, "Aether Crown trigger must overlap both its solid top and a touching blob center")
		probe.linear_velocity = Vector3(12, -3, 5)
		_check(vortex.call("activate_body", probe), "Aether vortex accepts a live blob body")
		_check(probe.linear_velocity.y > 32.0 and Vector2(probe.linear_velocity.x, probe.linear_velocity.z).length() > 13.0, "Aether vortex launches strongly while preserving horizontal movement")
	var boost := _first(arena, "boost_pad")
	if boost != null:
		probe.linear_velocity = Vector3.ZERO
		_check(boost.has_method("activate_body") and boost.call("activate_body", probe), "Sun-Seal boost accepts a live blob body")
		_check(probe.linear_velocity.y > 3.0 and Vector2(probe.linear_velocity.x, probe.linear_velocity.z).length() > 8.0, "Sun-Seal applies a medium upward-diagonal launch")
	var fin := _first(arena, "wall_rebound_fin")
	if fin != null:
		probe.linear_velocity = Vector3(-18, 7, 2)
		_check(fin.has_method("activate_body") and fin.call("activate_body", probe), "Wall rebound fin accepts a meaningful hit")
		_check(is_equal_approx(probe.linear_velocity.y, 7.0) and Vector2(probe.linear_velocity.x, probe.linear_velocity.z).length() > 18.0, "Wall fin preserves vertical speed and increases horizontal speed")
	for wall_fin in _elements(arena, "wall_rebound_fin"):
		var inward := wall_fin.get("fixed_direction") as Vector3
		var toward_center := -Vector3((wall_fin as Node3D).position.x, 0, (wall_fin as Node3D).position.z).normalized()
		_check(inward.dot(toward_center) > 0.67, "%s must always reflect through its wall normal into the arena" % wall_fin.name)
	var wind_zones := _interaction_kind(arena, &"wind_zone")
	_check(wind_zones.size() == 4, "All four Wind Arches need active wind volumes")
	for wind_zone in wind_zones:
		var source_gu := wind_zone.get_meta("aether_wind_source_gu", Vector2.ZERO) as Vector2
		var target_gu := wind_zone.get_meta("aether_wind_target_gu", Vector2.ZERO) as Vector2
		var expected_direction := Vector3(target_gu.x - source_gu.x, 0, -(target_gu.y - source_gu.y)).normalized()
		var configured := wind_zone.get("local_direction") as Vector3
		var actual_direction := Vector3(configured.x, 0, configured.z).normalized()
		_check(actual_direction.dot(expected_direction) > 0.98, "%s must push from its approved source toward its approved target" % wind_zone.name)
	probe.queue_free()
	_check(_static_body_count(arena) >= 65, "All gameplay-sized Aether Citadel geometry is physically solid")
	arena.queue_free()
	await process_frame
	if failures.is_empty():
		print("AETHER CITADEL BLUEPRINT CONTRACT PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _elements(arena: Node, kind: String) -> Array[Node]:
	var matches: Array[Node] = []
	for node in arena.find_children("*", "Node", true, false):
		if String(node.get_meta("aether_kind", "")) == kind:
			matches.append(node)
	return matches


func _first(arena: Node, kind: String) -> Node:
	var matches := _elements(arena, kind)
	return matches[0] if not matches.is_empty() else null


func _has_grid_position(arena: Node, kind: String, expected: Vector2) -> bool:
	for node in _elements(arena, kind):
		if (node.get_meta("gu_position", Vector2.ZERO) as Vector2).distance_to(expected) < 0.03:
			return true
	return false


func _group_descendants(arena: Node, group_name: StringName) -> Array[Node]:
	var matches: Array[Node] = []
	for node in arena.find_children("*", "Node", true, false):
		if node.is_in_group(group_name):
			matches.append(node)
	return matches


func _interaction_kind(arena: Node, kind: StringName) -> Array[Node]:
	var matches: Array[Node] = []
	for node in _group_descendants(arena, &"map_interactable"):
		if node.has_method("get_interaction_kind") and node.call("get_interaction_kind") == kind:
			matches.append(node)
	return matches


func _static_body_count(arena: Node) -> int:
	return arena.find_children("*", "StaticBody3D", true, false).size()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
