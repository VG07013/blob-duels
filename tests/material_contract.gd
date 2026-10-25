extends SceneTree

const MAPS := [
	preload("res://scenes/world/maps/bounceground.tscn"),
	preload("res://scenes/world/maps/training_yard.tscn"),
]

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for packed_map in MAPS:
		var arena := packed_map.instantiate() as Node3D
		root.add_child(arena)
		await process_frame
		var label := str(arena.get("map_name"))
		var textured := 0
		for node in arena.find_children("*", "MeshInstance3D", true, false):
			var material := (node as MeshInstance3D).material_override as StandardMaterial3D
			if material != null and material.albedo_texture != null:
				textured += 1
		_expect(textured >= 12, "%s walls, decks, ramps and cover need tiled material textures, not flat colour (%d)" % [label, textured])
		arena.queue_free()
		await process_frame

	var found_surface_families: Dictionary = {}
	for packed_map in MAPS:
		var map := packed_map.instantiate() as Node3D
		root.add_child(map)
		await process_frame
		for child in map.find_children("*", "StaticBody3D", true, false):
			var body := child as StaticBody3D
			var material := body.physics_material_override
			if material == null:
				continue
			if material.bounce >= 0.95:
				found_surface_families["bounce"] = true
			elif material.friction >= 0.7:
				found_surface_families["grip"] = true
			elif material.friction <= 0.02:
				found_surface_families["ice"] = true
			else:
				found_surface_families["normal"] = true
		map.queue_free()
		await process_frame
	for surface_name in ["normal", "bounce", "grip", "ice"]:
		_expect(found_surface_families.has(surface_name), "Playable maps do not place the %s surface family" % surface_name)
	if _failures.is_empty():
		print("MATERIAL CONTRACT PASS")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
