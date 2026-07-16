extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const MAP_SCENES := {
	"Neon Arcade": preload("res://scenes/world/maps/neon_arcade.tscn"),
	"Backyard": preload("res://scenes/world/maps/backyard.tscn"),
	"Arena": preload("res://scenes/world/maps/arena.tscn"),
	"Sky Temple": preload("res://scenes/world/maps/sky_temple.tscn"),
	"Toybox": preload("res://scenes/world/maps/toybox.tscn"),
}

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := MAIN_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	_check(game.get_node("Lobby").visible, "Lobby is not visible on project start")
	_check(not game.get_node("CityArena").visible, "Practice city remains visible behind the lobby")
	_check(game.get_node("Lobby").has_node("InteriorShell"), "Lobby has no sealed InteriorShell")
	_check(_model_roots(game.get_node("Lobby")).size() >= 12, "Lobby does not contain enough authored model props")
	_check(game.get_node("Lobby/Room").collision_layer == 1, "Lobby collision is disabled on project start")
	game.call("_start_practice_match")
	await physics_frame
	await process_frame
	_check(not game.get_node("Lobby").visible, "Lobby remains visible after entering practice")
	_check(game.get_node("CityArena").visible, "Practice city is hidden after entering practice")
	_check(game.get_node("Lobby/Room").collision_layer == 0, "Lobby collision remains active during practice")
	game.call("_return_to_lobby")
	await physics_frame
	await process_frame
	_check(game.get_node("Lobby").visible, "Lobby does not return after leaving practice")
	_check(not game.get_node("CityArena").visible, "Practice city remains visible after returning to lobby")
	_check(game.get_node("Lobby/Room").collision_layer == 1, "Lobby collision does not return with the lobby")
	game.free()

	for map_name in MAP_SCENES:
		var arena := (MAP_SCENES[map_name] as PackedScene).instantiate()
		root.add_child(arena)
		await process_frame
		var model_roots := _model_roots(arena)
		if map_name in ["Neon Arcade", "Arena"]:
			_check(model_roots.is_empty(), "%s should not add generic decorative models over its literal blueprint" % map_name)
			if map_name == "Neon Arcade":
				_check((arena.call("get_neon_arcade_blueprint") as Dictionary).get("footprint_gu", Vector2.ZERO) == Vector2(18, 18), "Neon Arcade blueprint metadata is missing")
			else:
				_check(((arena.call("get_map_audit") as Dictionary).get("blueprint", {}) as Dictionary).get("footprint_d", Vector2.ZERO) == Vector2(34, 24), "Arena blueprint metadata is missing")
			arena.free()
			continue
		var unique_sources: Dictionary = {}
		for model_root in model_roots:
			unique_sources[String(model_root.get_meta("model_source", ""))] = true
		_check(model_roots.size() >= 8, "%s needs at least 8 authored model instances" % map_name)
		_check(model_roots.size() <= 26, "%s has too many authored model instances for clear 1v1 play" % map_name)
		_check(unique_sources.size() >= 4, "%s needs at least 4 distinct authored model assets" % map_name)
		_check(_textured_model_count(model_roots) >= 6, "%s imported models lost their palette textures" % map_name)
		_check(_textured_mesh_count(arena) >= 8, "%s needs visible textured mesh surfaces" % map_name)
		arena.free()

	if failures.is_empty():
		print("ENVIRONMENT ART CONTRACT PASS: sealed lobby, imported models, and textured surfaces")
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


func _textured_model_count(model_roots: Array[Node]) -> int:
	var count := 0
	for model_root in model_roots:
		if _textured_mesh_count(model_root) > 0:
			count += 1
	return count


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
