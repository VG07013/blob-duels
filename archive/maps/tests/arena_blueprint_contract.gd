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
	# Level-design layer over the blueprint: the dividers carry the gantry deck,
	# a ramp on each flank reaches it, and each flank pocket has a speed hoop.
	_check(get_nodes_in_group("arena_center_gantry").size() == 1, "Arena has one center gantry deck bridging the dividers")
	_check(get_nodes_in_group("arena_gantry_ramp").size() == 2, "Arena has one gantry ramp per flank")
	_check(get_nodes_in_group("arena_speed_hoop").size() == 2, "Arena has one flank speed hoop per side")
	var gantry_decks := get_nodes_in_group("arena_center_gantry")
	if gantry_decks.size() == 1:
		var deck := gantry_decks[0] as MeshInstance3D
		var deck_mesh := deck.mesh as BoxMesh
		var underside := deck.position.y - deck_mesh.size.y * 0.5
		_check(underside >= 1.5 * D - 0.01, "The centre rebound gap under the gantry stays at least 1.5D tall for floor play")
		_check(deck.position.y + deck_mesh.size.y * 0.5 <= 2.0 * D, "The gantry deck stays below the redirect walls' 2D silhouette")
	var probe := RigidBody3D.new()
	probe.mass = 2.0
	probe.gravity_scale = 0.0
	probe.collision_layer = 2
	probe.collision_mask = 1
	get_root().add_child(probe)
	await physics_frame
	for hoop_value in get_nodes_in_group("arena_speed_hoop"):
		var hoop := hoop_value as Node3D
		probe.global_position = hoop.global_position
		probe.linear_velocity = Vector3(3.0, 0.0, -18.0)
		_check(hoop.call("activate_body", probe), "Speed hoop accepts a committed run through it")
		_check(probe.linear_velocity.z <= -30.0 and probe.linear_velocity.y > 0.0, "Speed hoop re-flings a run in its own direction of travel with lift")
		probe.linear_velocity = Vector3(0.0, 0.0, 1.5)
		_check(not hoop.call("activate_body", probe), "Speed hoop ignores a slow drift so it only rewards a committed run")
	probe.queue_free()
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
