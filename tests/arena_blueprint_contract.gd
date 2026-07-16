extends SceneTree

const ARENA_SCENE := preload("res://scenes/world/maps/arena.tscn")
const D := 5.775

var failures: Array[String] = []


func _initialize() -> void:
	var arena := ARENA_SCENE.instantiate() as Node3D
	get_root().add_child(arena)
	await process_frame
	await physics_frame
	var blueprint := arena.call("get_map_audit").get("blueprint", {}) as Dictionary
	_check(blueprint.get("footprint_d", Vector2.ZERO) == Vector2(34, 24), "Arena uses the exact 34D x 24D blueprint footprint")
	_check(is_equal_approx(float(blueprint.get("roof_d", 0.0)), 5.0), "Arena roof is at 5D")
	var spawns := arena.call("get_spawn_points") as Array
	_check(spawns.size() == 2, "Arena exposes exactly two clear north-south spawns")
	if spawns.size() == 2:
		_check(is_equal_approx((spawns[0] as Marker3D).position.z, 10.0 * D), "Blue spawn is at blueprint (17,2)")
		_check(is_equal_approx((spawns[1] as Marker3D).position.z, -10.0 * D), "Orange spawn is at blueprint (17,22)")
	_check(get_nodes_in_group("arena_launch_strip").size() == 8, "Arena has the eight source-drawn wall launch strips")
	_check(get_nodes_in_group("arena_diagonal_ramp").size() == 4, "Arena has four diagonal side ramps")
	_check(get_nodes_in_group("arena_redirect_wall").size() == 4, "Arena has four angled redirect walls")
	_check(get_nodes_in_group("arena_center_divider").size() == 2, "Arena has two center divider walls")
	_check(get_nodes_in_group("arena_roof").size() == 1, "Arena has one collision roof")
	_check(_count(arena, "Collision") >= 20, "Arena's visible floor and perimeter are solid")
	arena.queue_free()
	if failures.is_empty():
		print("ARENA BLUEPRINT CONTRACT PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _count(root: Node, token: String) -> int:
	var total := 0
	if root.name.contains(token):
		total += 1
	for child in root.get_children():
		total += _count(child, token)
	return total


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
