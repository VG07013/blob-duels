extends SceneTree

const PRACTICE := preload("res://scenes/world/practice_arena.tscn")
const MAPS := {
	"Bounceground": preload("res://scenes/world/maps/bounceground.tscn"),
}

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _check_practice_roof_and_detail()
	for map_name in MAPS:
		await _check_map_supports(map_name, MAPS[map_name] as PackedScene)
	if failures.is_empty():
		print("MAP SUPPORT + PRACTICE ROOF CONTRACT PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _check_practice_roof_and_detail() -> void:
	var practice := PRACTICE.instantiate() as Node3D
	root.add_child(practice)
	await process_frame
	var roofs := _owned_group(practice, "arena_roof")
	var roof_collisions := _owned_group(practice, "arena_roof_collision")
	var details := _owned_group(practice, "practice_environment_detail")
	var supports := _owned_group(practice, "structural_support")
	_check(roofs.size() == 1, "Practice needs one visible roof spanning the playable city")
	_check(roof_collisions.size() == roofs.size(), "Practice roof must have matching collision")
	_check(details.size() >= 16, "Practice needs a deliberate environmental-detail pass, not only basic traversal blocks")
	_check(supports.size() >= 8, "Practice elevated structures and roof need visible supports down to ground")
	practice.queue_free()
	await process_frame


func _check_map_supports(map_name: String, packed: PackedScene) -> void:
	var arena := packed.instantiate() as Node3D
	root.add_child(arena)
	await process_frame
	var elevated := _owned_group(arena, "supported_elevated_structure")
	var supports := _owned_group(arena, "structural_support")
	# Every raised Bounceground piece is a solid block down to the court, so
	# nothing needs struts; what matters is that the lid exists and is solid.
	var roofs := _owned_group(arena, "arena_roof")
	_check(roofs.size() == 1, "%s needs one glass lid so full-charge flings stay in the court" % map_name)
	var glass := arena.get_node_or_null("GlassCollision") as StaticBody3D
	_check(glass != null and glass.get_child_count() >= 5, "%s glass walls and roof must all have collision" % map_name)
	for structure_value in elevated:
		var structure := structure_value as Node
		var support_key := String(structure.get_meta("support_key", ""))
		_check(not support_key.is_empty(), "%s is missing its support linkage" % structure.name)
		_check(supports.any(func(node: Node) -> bool: return String(node.get_meta("support_key", "")) == support_key), "%s has no matching ground support" % structure.name)
	arena.queue_free()
	await process_frame


func _owned_group(owner: Node, group_name: String) -> Array[Node]:
	var result: Array[Node] = []
	for node_value in owner.get_tree().get_nodes_in_group(group_name):
		var node := node_value as Node
		if owner.is_ancestor_of(node):
			result.append(node)
	return result


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
