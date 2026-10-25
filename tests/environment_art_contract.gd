extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const MAP_SCENES := {
	"Bounceground": preload("res://scenes/world/maps/bounceground.tscn"),
}

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := MAIN_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	var player := game.get_node("Player") as RigidBody3D
	_check(game.get_node_or_null("Lobby") == null, "The walkable 3D lobby is retired; the main menu replaces it")
	_check(not game.get_node("PracticeArena").visible, "Practice city must not load behind the main menu")
	_check(game.get_viewport().disable_3d, "The opaque main menu must skip 3D rendering")
	_check(player.freeze and not bool(player.get("input_enabled")), "The local blob waits frozen with input off while the menu is up")
	game.call("_start_practice_match")
	await physics_frame
	await process_frame
	_check(not game.get_viewport().disable_3d, "Starting a match must bring 3D rendering back")
	_check(game.get_node("PracticeArena").visible, "Practice city is hidden after entering practice")
	_check(not player.freeze and bool(player.get("input_enabled")), "Starting a match must hand the blob back to the player")
	game.call("_return_to_lobby")
	await physics_frame
	await process_frame
	_check(game.get_viewport().disable_3d, "Returning to the menu must stop 3D rendering again")
	_check(not game.get_node("PracticeArena").visible, "Practice city remains visible after returning to the menu")
	_check(player.freeze and not bool(player.get("input_enabled")), "Returning to the menu must park the blob again")
	game.free()

	for map_name in MAP_SCENES:
		var arena := (MAP_SCENES[map_name] as PackedScene).instantiate()
		root.add_child(arena)
		await process_frame
		var model_roots := _model_roots(arena)
		# Bounceground is deliberately clean: authored court geometry only, no
		# imported decorative models cluttering sightlines.
		_check(model_roots.is_empty(), "%s should not add generic decorative models over its authored court" % map_name)
		var footprint := ((arena.call("get_map_audit") as Dictionary).get("blueprint", {}) as Dictionary).get("footprint", Vector2.ZERO) as Vector2
		_check(footprint.x >= 100.0 and footprint.y >= 100.0, "%s must be big enough for full-charge flings (footprint %s)" % [map_name, footprint])
		_check(_textured_mesh_count(arena) >= 8, "%s needs visible textured mesh surfaces" % map_name)
		arena.free()

	if failures.is_empty():
		print("ENVIRONMENT ART CONTRACT PASS: menu world parking, imported models, and textured surfaces")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _model_roots(parent: Node) -> Array[Node]:
	var models: Array[Node] = []
	for node in parent.find_children("*", "Node3D", true, false):
		if node.is_in_group("environment_model"):
			models.append(node)
	return models


func _textured_mesh_count(parent: Node) -> int:
	var count := 0
	for node in parent.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface_index in range(mesh_instance.mesh.get_surface_count()):
			var material := mesh_instance.get_active_material(surface_index) as BaseMaterial3D
			if material != null and material.albedo_texture != null:
				count += 1
				break
	return count


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
