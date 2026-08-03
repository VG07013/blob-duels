extends SceneTree

const ARENA := preload("res://scenes/world/maps/arena.tscn")
const NEON_ARCADE := preload("res://scenes/world/maps/neon_arcade.tscn")
const PRACTICE := preload("res://scenes/world/city_arena.tscn")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _check_authored_footprints("Arena", ARENA)
	await _check_authored_footprints("Neon Arcade", NEON_ARCADE)
	await _check_practice_geometry()
	if failures.is_empty():
		print("MAP GEOMETRY CONTRACT PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _check_authored_footprints(label: String, packed: PackedScene) -> void:
	var arena := packed.instantiate() as Node3D
	root.add_child(arena)
	await process_frame
	var footprints: Array[Node] = []
	for node in arena.find_children("*", "Node3D", true, false):
		if node.is_in_group("overlap_audit"):
			footprints.append(node)
	_check(footprints.size() >= 8, "%s must expose its important route footprints to overlap auditing" % label)
	for first_index in range(footprints.size()):
		for second_index in range(first_index + 1, footprints.size()):
			var first := footprints[first_index] as Node3D
			var second := footprints[second_index] as Node3D
			_check(not _footprints_overlap(first, second), "%s has intersecting authored geometry: %s and %s" % [label, first.name, second.name])
	if label in ["Arena", "Neon Arcade"]:
		for footprint in footprints:
			if not String(footprint.name).contains("Ramp"):
				continue
			var surface_pattern := "*ContinuousSurface*" if label == "Arena" else "*Surface*"
			var surfaces := footprint.find_children(surface_pattern, "MeshInstance3D", true, false)
			_check(surfaces.size() == 1 and _mesh_is_closed((surfaces[0] as MeshInstance3D).mesh), "%s must have a closed visible shell, including its underside and high end" % footprint.name)
	arena.queue_free()
	await process_frame


func _footprints_overlap(first: Node3D, second: Node3D) -> bool:
	var first_center := first.get_meta("footprint_center", Vector2.ZERO) as Vector2
	var second_center := second.get_meta("footprint_center", Vector2.ZERO) as Vector2
	var first_size := first.get_meta("footprint_size", Vector2.ZERO) as Vector2
	var second_size := second.get_meta("footprint_size", Vector2.ZERO) as Vector2
	var first_yaw := float(first.get_meta("footprint_yaw", 0.0))
	var second_yaw := float(second.get_meta("footprint_yaw", 0.0))
	var first_axes := [Vector2(cos(first_yaw), -sin(first_yaw)), Vector2(sin(first_yaw), cos(first_yaw))]
	var second_axes := [Vector2(cos(second_yaw), -sin(second_yaw)), Vector2(sin(second_yaw), cos(second_yaw))]
	for axis_value in first_axes + second_axes:
		var axis := axis_value as Vector2
		var first_radius := absf(first_axes[0].dot(axis)) * first_size.x * 0.5 + absf(first_axes[1].dot(axis)) * first_size.y * 0.5
		var second_radius := absf(second_axes[0].dot(axis)) * second_size.x * 0.5 + absf(second_axes[1].dot(axis)) * second_size.y * 0.5
		if absf((second_center - first_center).dot(axis)) >= first_radius + second_radius - 0.01:
			return false
	return true


func _check_practice_geometry() -> void:
	var practice := PRACTICE.instantiate() as Node3D
	root.add_child(practice)
	await process_frame
	var ramps := practice.get_tree().get_nodes_in_group("closed_ramp").filter(func(node: Node) -> bool: return practice.is_ancestor_of(node))
	var ramp_collisions := practice.get_tree().get_nodes_in_group("closed_ramp_collision").filter(func(node: Node) -> bool: return practice.is_ancestor_of(node))
	_check(ramps.size() == 8, "Practice must build all eight traversal ramps as closed wedge meshes")
	_check(ramp_collisions.size() == ramps.size(), "Every closed practice ramp needs one matching convex collider")
	for ramp_value in ramps:
		var ramp := ramp_value as MeshInstance3D
		_check(ramp != null and ramp.mesh != null and _mesh_is_closed(ramp.mesh), "%s must be a watertight wedge with a visible underside" % ramp_value.name)
		if ramp != null and ramp.mesh != null:
			var expected_landing_heights := {
				"WestDeckRamp_": 21.6,
				"EastDeckRamp_": 21.6,
				"NorthDeckRamp_": 25.6,
				"SouthDeckRamp_": 25.6,
				"SkyBridgeWestRamp_": 40.0,
				"SkyBridgeEastRamp_": 40.0,
			}
			for prefix in expected_landing_heights:
				if not String(ramp.name).begins_with(prefix):
					continue
				var high_edge_y := ramp.position.y + ramp.mesh.get_aabb().end.y
				_check(absf(high_edge_y - float(expected_landing_heights[prefix])) <= 1.0, "%s must meet its landing without a collision lip" % ramp.name)
	for collision_value in ramp_collisions:
		var collision := collision_value as CollisionShape3D
		var convex := collision.shape as ConvexPolygonShape3D if collision != null else null
		_check(convex != null and convex.points.size() == 8, "%s must use the same eight-point ramp-prism volume as its visible ramp" % collision_value.name)
	var solid_props := practice.get_tree().get_nodes_in_group("solid_visible_prop").filter(func(node: Node) -> bool: return practice.is_ancestor_of(node))
	var solid_prop_collisions := practice.get_tree().get_nodes_in_group("solid_visible_prop_collision").filter(func(node: Node) -> bool: return practice.is_ancestor_of(node))
	_check(solid_props.size() >= 10, "Practice tree canopies must be classified as reachable solid-looking props")
	_check(solid_prop_collisions.size() == solid_props.size(), "Every reachable solid-looking practice prop must have matching collision")
	var landing_pairs := {
		"WestDeckRamp_": "WestDeckRoof_", "EastDeckRamp_": "EastDeckRoof_",
		"NorthDeckRamp_": "NorthDeckRoof_", "SouthDeckRamp_": "SouthDeckRoof_",
		"SkyBridgeWestRamp_": "SkyBridge_", "SkyBridgeEastRamp_": "SkyBridge_",
		"OverpassWestRamp_": "SouthOverpass_", "OverpassEastRamp_": "SouthOverpass_",
	}
	for ramp_value in ramps:
		var ramp := ramp_value as MeshInstance3D
		for ramp_prefix in landing_pairs:
			if not String(ramp.name).begins_with(ramp_prefix):
				continue
			var landing := _mesh_with_prefix(practice, landing_pairs[ramp_prefix] as String)
			_check(landing != null and absf(_mesh_top_y(ramp) - _box_top_y(landing)) < 0.05, "%s must meet the top of %s without a collision lip" % [ramp.name, landing_pairs[ramp_prefix]])
	var deck_meshes: Array[MeshInstance3D] = []
	for node in practice.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := node as MeshInstance3D
		if ["WestDeck_", "EastDeck_", "NorthDeck_", "SouthDeck_"].any(func(prefix: String) -> bool: return String(mesh_node.name).begins_with(prefix)):
			deck_meshes.append(mesh_node)
	for node in practice.find_children("*", "MeshInstance3D", true, false):
		var vent := node as MeshInstance3D
		if not String(vent.name).begins_with("PlazaVent_"):
			continue
		for deck in deck_meshes:
			_check(not _circle_overlaps_box_xz(vent.position, 3.2, deck), "%s overlaps the playable rooftop %s" % [vent.name, deck.name])
	practice.queue_free()
	await process_frame


func _mesh_is_closed(mesh: Mesh) -> bool:
	var faces := mesh.get_faces()
	if faces.size() < 12 or faces.size() % 3 != 0:
		return false
	var edge_counts: Dictionary = {}
	for index in range(0, faces.size(), 3):
		if (faces[index + 1] - faces[index]).cross(faces[index + 2] - faces[index]).length_squared() < 0.000001:
			continue
		for edge in [[faces[index], faces[index + 1]], [faces[index + 1], faces[index + 2]], [faces[index + 2], faces[index]]]:
			var first := _vertex_key(edge[0] as Vector3)
			var second := _vertex_key(edge[1] as Vector3)
			var key := "%s|%s" % [first, second] if first < second else "%s|%s" % [second, first]
			edge_counts[key] = int(edge_counts.get(key, 0)) + 1
	for key in edge_counts:
		if int(edge_counts[key]) != 2:
			return false
	return true


func _vertex_key(vertex: Vector3) -> String:
	return "%d,%d,%d" % [roundi(vertex.x * 1000.0), roundi(vertex.y * 1000.0), roundi(vertex.z * 1000.0)]


func _circle_overlaps_box_xz(center: Vector3, radius: float, box: MeshInstance3D) -> bool:
	var box_mesh := box.mesh as BoxMesh
	if box_mesh == null:
		return false
	var delta := Vector2(center.x - box.position.x, center.z - box.position.z)
	return absf(delta.x) < box_mesh.size.x * 0.5 + radius and absf(delta.y) < box_mesh.size.z * 0.5 + radius


func _mesh_with_prefix(parent: Node, prefix: String) -> MeshInstance3D:
	for node in parent.find_children("*", "MeshInstance3D", true, false):
		if String(node.name).begins_with(prefix):
			return node as MeshInstance3D
	return null


func _mesh_top_y(mesh_instance: MeshInstance3D) -> float:
	var top := -INF
	for face_vertex in mesh_instance.mesh.get_faces():
		top = maxf(top, (mesh_instance.transform * face_vertex).y)
	return top


func _box_top_y(mesh_instance: MeshInstance3D) -> float:
	var box := mesh_instance.mesh as BoxMesh
	return mesh_instance.position.y + box.size.y * 0.5 if box != null else -INF


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
