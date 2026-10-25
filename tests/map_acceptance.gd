extends SceneTree

const MAPS := [
	preload("res://scenes/world/maps/bounceground.tscn"),
]

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for packed_map in MAPS:
		var arena := packed_map.instantiate() as Node3D
		root.add_child(arena)
		await process_frame
		var map_label := str(arena.get("map_name"))
		var interactables := get_nodes_in_group("map_interactable").filter(func(node: Node) -> bool: return arena.is_ancestor_of(node))
		var landmarks := get_nodes_in_group("map_landmark").filter(func(node: Node) -> bool: return arena.is_ancestor_of(node))
		if interactables.size() < 3:
			failures.append("%s has fewer than three working interactables" % map_label)
		if landmarks.is_empty():
			failures.append("%s has no gameplay landmark" % map_label)
		if not arena.has_method("get_map_audit"):
			failures.append("%s has no authored map audit metadata" % map_label)
		else:
			var audit := arena.call("get_map_audit") as Dictionary
			for key in ["identity", "landmark", "routes", "interactables", "prop_families"]:
				if not audit.has(key) or audit[key] == null:
					failures.append("%s audit is missing %s" % [map_label, key])
		arena.queue_free()
		await process_frame

	if failures.is_empty():
		print("MAP ACCEPTANCE PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("MAP ACCEPTANCE FAILURES: %d" % failures.size())
		quit(1)
