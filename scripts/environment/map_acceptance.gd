extends SceneTree

const MAPS := {
	"neon_arcade": "res://scenes/world/maps/neon_arcade.tscn",
	"backyard": "res://scenes/world/maps/backyard.tscn",
	"arena": "res://scenes/world/maps/arena.tscn",
	"sky_temple": "res://scenes/world/maps/sky_temple.tscn",
	"toybox": "res://scenes/world/maps/toybox.tscn",
}

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for map_id: String in MAPS:
		await _audit_map(map_id, MAPS[map_id])
	if _failures.is_empty():
		print("MAP ACCEPTANCE PASS: authored arenas, landmarks, routes, and physics interactables")
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

	_expect(arena.has_method("get_spawn_points"), "%s: spawn API exists" % map_id)
	_expect(arena.has_method("get_lighting_profile"), "%s: lighting API exists" % map_id)
	_expect(arena.has_method("get_map_audit"), "%s: map audit API exists" % map_id)
	var is_neon := map_id == "neon_arcade"
	var is_arena_blueprint := map_id == "arena"
	if is_neon:
		_expect(is_equal_approx(float(arena.get("arena_half_length")), float(arena.get("arena_half_width"))), "%s: Neon Arcade uses the 18 x 18 GU square footprint" % map_id)
	elif is_arena_blueprint:
		_expect(is_equal_approx(float(arena.get("arena_half_length")), float(arena.get("arena_half_width")) * (24.0 / 34.0)), "%s: Arena uses the literal 34 x 24 blueprint footprint" % map_id)
	else:
		_expect(is_equal_approx(float(arena.get("arena_half_length")), float(arena.get("arena_half_width")) * 3.0), "%s: arena is 1:3" % map_id)

	if arena.has_method("get_spawn_points"):
		var spawns: Array = arena.call("get_spawn_points")
		_expect(spawns.size() == 2, "%s: exactly two duel spawns" % map_id)
		if spawns.size() == 2 and is_arena_blueprint:
			_expect(absf((spawns[0] as Marker3D).position.z - (spawns[1] as Marker3D).position.z) > float(arena.get("arena_half_length")) * 1.5, "%s: blueprint spawns oppose along the tournament axis" % map_id)
		elif spawns.size() == 2 and not is_neon:
			_expect(absf((spawns[0] as Marker3D).position.z - (spawns[1] as Marker3D).position.z) > float(arena.get("arena_half_width")) * 3.5, "%s: spawns oppose along long axis" % map_id)
		elif spawns.size() == 2:
			_expect((spawns[0] as Marker3D).position.x * (spawns[1] as Marker3D).position.x < 0.0 and (spawns[0] as Marker3D).position.z * (spawns[1] as Marker3D).position.z < 0.0, "%s: Neon Arcade spawns oppose diagonally" % map_id)

	var audit: Dictionary = arena.call("get_map_audit") if arena.has_method("get_map_audit") else {}
	for key in ["identity", "landmark", "routes", "interactables", "prop_families"]:
		_expect(audit.has(key), "%s: audit includes %s" % [map_id, key])
	_expect(not str(audit.get("identity", "")).is_empty(), "%s: identity is named" % map_id)
	_expect(not str(audit.get("landmark", "")).is_empty(), "%s: landmark is named" % map_id)
	_expect((audit.get("routes", []) as Array).size() >= 6, "%s: six route roles are documented" % map_id)
	_expect((audit.get("prop_families", []) as Array).size() >= 4, "%s: four prop families are documented" % map_id)

	var landmarks := _descendants_in_group(arena, "map_landmark")
	var interactables := _descendants_in_group(arena, "map_interactable")
	_expect(not landmarks.is_empty(), "%s: grouped landmark root exists" % map_id)
	_expect(interactables.size() >= 3, "%s: at least three grouped interactable instances" % map_id)
	var kinds: Dictionary = {}
	for interactable in interactables:
		_expect(interactable.has_method("get_interaction_kind"), "%s: %s exposes interaction kind" % [map_id, interactable.name])
		if interactable.has_method("get_interaction_kind"):
			kinds[interactable.call("get_interaction_kind")] = true
	_expect(kinds.size() >= (1 if is_arena_blueprint else 3), "%s: enough distinct interactive systems" % map_id)
	_expect((audit.get("interactables", []) as Array).size() >= (1 if is_arena_blueprint else 3), "%s: audit documents interactables" % map_id)

	var mesh_count := _count_type(arena, "MeshInstance3D")
	var collision_count := _count_type(arena, "CollisionShape3D")
	_expect(mesh_count >= 85, "%s: authored visual density (%d/85 meshes)" % [map_id, mesh_count])
	_expect(collision_count >= 25, "%s: route collision density (%d/25 shapes)" % [map_id, collision_count])
	arena.queue_free()
	await process_frame


func _descendants_in_group(root_node: Node, group_name: StringName) -> Array[Node]:
	var matches: Array[Node] = []
	for child in root_node.find_children("*", "", true, false):
		if child.is_in_group(group_name):
			matches.append(child)
	return matches


func _count_type(root_node: Node, type_name: String) -> int:
	var count := 0
	for child in root_node.find_children("*", type_name, true, false):
		count += 1
	return count


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
