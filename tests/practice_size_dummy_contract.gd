extends SceneTree

const PRACTICE_SCENE := preload("res://scenes/world/practice_arena.tscn")
const DUMMY_SCENE := preload("res://scenes/player/dummy_blob.tscn")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var root := Node3D.new()
	get_root().add_child(root)
	var practice := PRACTICE_SCENE.instantiate() as Node3D
	root.add_child(practice)
	await physics_frame
	await physics_frame

	# The "smaller map" rule, in world space: the old city's plate spanned
	# +/-160 world units after its 0.32 scale trick; the facility is authored
	# 1:1 and must stay in the same envelope while covering the +/-115 spawns.
	var ground: MeshInstance3D = null
	for node in practice.find_children("FacilityGround*", "MeshInstance3D", true, false):
		ground = node as MeshInstance3D
	_check(ground != null and ground.mesh is BoxMesh, "Practice needs its single ground plate")
	if ground != null and ground.mesh is BoxMesh:
		var world_half := (ground.mesh as BoxMesh).size.x * 0.5 * practice.scale.x
		_check(world_half >= 140.0 and world_half <= 160.0, "Practice ground half-extent must stay within [140, 160] world units, got %.1f" % world_half)
	var walls := _owned_group(practice, "practice_perimeter_wall")
	var wall_collisions := _owned_group(practice, "practice_perimeter_wall_collision")
	_check(walls.size() == 4, "Practice needs four visible perimeter walls")
	_check(wall_collisions.size() == 4, "Every Practice perimeter wall needs solid collision")
	for wall_value in walls:
		var wall := wall_value as MeshInstance3D
		var wall_mesh := wall.mesh as BoxMesh
		_check(wall_mesh != null and wall_mesh.size.y * practice.scale.x >= 64.0, "%s must close the arena from floor to roof" % wall.name)

	var names: Dictionary = {}
	for index in range(5):
		var dummy := DUMMY_SCENE.instantiate() as RigidBody3D
		dummy.name = ["DummyRose", "DummyGold", "DummyLime", "DummyViolet", "DummyOrange"][index]
		dummy.position = Vector3(index * 12.0, 5.0, index * -9.0)
		root.add_child(dummy)
		await process_frame
		var dummy_name := str(dummy.get("display_name"))
		_check(not dummy_name.is_empty() and not dummy_name.begins_with("Dummy"), "%s needs a funny player-facing name" % dummy.name)
		_check(not names.has(dummy_name), "Practice dummy names should be unique in the standard five-dummy setup")
		names[dummy_name] = true
		var nameplate := dummy.get_node_or_null("Nameplate") as Node3D
		var name_label := dummy.get_node_or_null("Nameplate/Name") as Label3D
		var health_background := dummy.get_node_or_null("Nameplate/HealthBackground") as MeshInstance3D
		var health_fill := dummy.get_node_or_null("Nameplate/HealthFill") as MeshInstance3D
		_check(nameplate != null and nameplate.top_level, "%s needs a stable top-level nameplate" % dummy.name)
		_check(name_label != null and name_label.text == dummy_name, "%s name must render above its health bar" % dummy.name)
		_check(health_background != null and health_fill != null, "%s needs a visual health bar, not a raw health number" % dummy.name)
		dummy.call("take_damage", 30, Vector3.RIGHT, 0.0)
		_check(health_fill != null and is_equal_approx(health_fill.scale.x, 0.8), "%s health fill must track health visually" % dummy.name)

	root.queue_free()
	if _failures.is_empty():
		print("PRACTICE SIZE + DUMMY CONTRACT PASSED")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _owned_group(owner: Node, group_name: StringName) -> Array[Node]:
	return get_nodes_in_group(group_name).filter(func(node: Node) -> bool: return owner.is_ancestor_of(node))


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
