extends SceneTree

const MAPS := [
	preload("res://scenes/world/maps/neon_arcade.tscn"),
	preload("res://scenes/world/maps/backyard.tscn"),
	preload("res://scenes/world/maps/arena.tscn"),
	preload("res://scenes/world/maps/sky_temple.tscn"),
	preload("res://scenes/world/maps/toybox.tscn"),
]

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for packed_map in MAPS:
		var arena := packed_map.instantiate() as Node3D
		root.add_child(arena)
		await process_frame
		await physics_frame
		var label := str(arena.get("map_name"))
		for spawn in arena.call("get_spawn_points") as Array:
			var marker := spawn as Marker3D
			var start := marker.global_position + Vector3.UP * 1.0
			var toward_center := Vector3(-start.x, 0.0, -start.z).normalized()
			var query := PhysicsRayQueryParameters3D.create(start, start + toward_center * 13.0)
			query.collision_mask = 1
			query.hit_from_inside = true
			var hit := root.world_3d.direct_space_state.intersect_ray(query)
			_expect(hit.is_empty(), "%s spawn has a clear 13m launch lane" % label)
		arena.queue_free()
		await process_frame
	if _failures.is_empty():
		print("SPAWN SAFETY INTEGRATION PASS")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
