extends SceneTree

const MAPS := {
	"neon_arcade": "res://scenes/world/maps/neon_arcade.tscn",
	"backyard": "res://scenes/world/maps/backyard.tscn",
	"arena": "res://scenes/world/maps/arena.tscn",
	"sky_temple": "res://scenes/world/maps/sky_temple.tscn",
	"toybox": "res://scenes/world/maps/toybox.tscn",
}

const MAX_ENVIRONMENT_MODELS := 26
const MIN_SOLID_ENVIRONMENT_MODELS := 8

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for map_id: String in MAPS:
		await _audit_map(map_id, MAPS[map_id])
	if _failures.is_empty():
		print("MAP CLARITY CONTRACT PASS")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _audit_map(map_id: String, scene_path: String) -> void:
	var packed := load(scene_path) as PackedScene
	_expect(packed != null, "%s: scene loads" % map_id)
	if packed == null:
		return
	var arena := packed.instantiate() as Node3D
	root.add_child(arena)
	await process_frame
	await physics_frame

	var models := _descendants_in_group(arena, "environment_model")
	_expect(models.size() <= MAX_ENVIRONMENT_MODELS, "%s: decoration count is uncluttered (%d/%d)" % [map_id, models.size(), MAX_ENVIRONMENT_MODELS])

	var solid_models := 0
	var reachable_models := 0
	for model in models:
		var model_node := model as Node3D
		if model_node == null:
			continue
		if model_node.global_position.y > 4.0:
			continue
		reachable_models += 1
		if _model_has_solid_footprint(arena, model_node):
			solid_models += 1
	_expect(solid_models >= mini(MIN_SOLID_ENVIRONMENT_MODELS, reachable_models), "%s: reachable imported props have solid collision footprints (%d/%d)" % [map_id, solid_models, reachable_models])

	arena.queue_free()
	await process_frame


func _model_has_solid_footprint(arena: Node3D, model: Node3D) -> bool:
	var probe := SphereShape3D.new()
	probe.radius = 1.35
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = probe
	query.transform = Transform3D(Basis.IDENTITY, model.global_position + Vector3.UP * 2.6)
	query.collision_mask = 1
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return not arena.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func _descendants_in_group(root_node: Node, group_name: StringName) -> Array[Node]:
	var matches: Array[Node] = []
	for child in root_node.find_children("*", "", true, false):
		if child.is_in_group(group_name):
			matches.append(child)
	return matches


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
