extends SceneTree

const BACKYARD := preload("res://scenes/world/maps/backyard.tscn")
const D := 5.775

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var arena := BACKYARD.instantiate() as Node3D
	root.add_child(arena)
	await process_frame
	await physics_frame
	var blueprint := arena.call("get_map_audit").get("blueprint", {}) as Dictionary
	_check(blueprint.get("footprint_gu", Vector2.ZERO) == Vector2(84, 64), "Backyard uses the exact 84 x 64 GU footprint")
	_check(is_equal_approx(float(blueprint.get("gu_scale_d", 0.0)), 0.5), "Backyard keeps 1 GU equal to 0.5 blob diameters")
	_check(is_equal_approx(float(blueprint.get("roof_height_d", 0.0)), 5.8), "Backyard roof is raised to 5.8D")
	_check(_elements(arena, "spawn_deck").size() == 2, "Backyard has exactly two authored spawn decks")
	_check(_elements(arena, "picnic_platform").size() == 1, "Backyard has one central picnic platform")
	_check(_elements(arena, "hose_ramp").size() == 4, "Backyard has four curved hose ramps")
	_check(_elements(arena, "planter_cover").size() == 4, "Backyard has four planter cover walls")
	_check(_elements(arena, "stepping_stone").size() == 20, "Backyard has exactly twenty stepping-stone bounce blocks")
	_check(_elements(arena, "sprinkler_pad").size() == 6, "Backyard has exactly six sprinkler pads")
	_check(_elements(arena, "mushroom_pad").size() == 4, "Backyard has exactly four mushroom bounce pads")
	_check(_elements(arena, "perimeter_fence_section").size() >= 12, "Backyard perimeter uses solid authored fence sections")
	_check(_elements(arena, "transparent_roof").size() == 1, "Backyard has one complete transparent collision roof")
	var roof_elements := _elements(arena, "transparent_roof")
	if not roof_elements.is_empty():
		_check((roof_elements[0].get_meta("gu_size", Vector3.ZERO) as Vector3) == Vector3(84, 0.2, 64), "Backyard roof collision covers the entire 84 x 64 GU enclosure")
	_check(_has_grid_position(arena, "picnic_platform", Vector2(42, 32)), "Picnic platform is centered at blueprint coordinate (42,32)")
	for expected in [Vector2(15, 51), Vector2(69, 51), Vector2(15, 18), Vector2(69, 18)]:
		_check(_has_grid_position(arena, "hose_ramp", expected), "Hose ramp is missing blueprint coordinate %s" % expected)
	for hose in _elements(arena, "hose_ramp"):
		_check(bool(hose.get_meta("curved_plan", false)) and float(hose.get_meta("plan_curve_world", 0.0)) > 2.5 * D, "Every hose needs a visible plan-view curve")
		_check(int(hose.get_meta("curve_collision_segments", 0)) >= 8, "Every curved hose needs overlapped tangent convex collision")
	for expected in [Vector2(22, 13), Vector2(62, 13), Vector2(12, 35), Vector2(72, 35), Vector2(22, 55), Vector2(62, 55)]:
		_check(_has_grid_position(arena, "sprinkler_pad", expected), "Sprinkler is missing blueprint coordinate %s" % expected)
	for expected in [Vector2(29, 21), Vector2(55, 21), Vector2(29, 51), Vector2(55, 51)]:
		_check(_has_grid_position(arena, "mushroom_pad", expected), "Mushroom is missing blueprint coordinate %s" % expected)
	var spawns := arena.call("get_spawn_points") as Array
	_check(spawns.size() == 2, "Backyard exposes exactly two functional spawns")
	if spawns.size() == 2:
		_check(is_equal_approx((spawns[0] as Marker3D).position.z, 13.0 * D), "Player 1 red spawn is on the bottom deck at (42,6)")
		_check(is_equal_approx((spawns[1] as Marker3D).position.z, -13.0 * D), "Player 2 blue spawn is on the top deck at (42,58)")
		for spawn_value in spawns:
			var spawn := spawn_value as Marker3D
			var forward := -spawn.global_basis.z.normalized()
			var toward_center := -Vector3(spawn.position.x, 0.0, spawn.position.z).normalized()
			_check(forward.dot(toward_center) > 0.98, "Both spawn cameras face directly toward center")
	for sprinkler in _elements(arena, "sprinkler_pad"):
		_check(sprinkler.has_method("affect_body"), "Every sprinkler provides its continuous movement force")
		_check((sprinkler as Node).has_node("SolidBase/CollisionShape3D"), "Every sprinkler pad has a solid base collider")
	for mushroom in _elements(arena, "mushroom_pad"):
		_check(mushroom.has_method("activate_body"), "Every mushroom provides directional momentum bounce")
		_check((mushroom as Node).has_node("SolidMushroom/CapCollision"), "Every mushroom cap uses solid convex collision")
	var physics_probe := RigidBody3D.new()
	physics_probe.mass = 2.0
	physics_probe.gravity_scale = 0.0
	physics_probe.collision_layer = 2
	physics_probe.collision_mask = 1
	root.add_child(physics_probe)
	await physics_frame
	var sprinklers := _elements(arena, "sprinkler_pad")
	if not sprinklers.is_empty():
		var sprinkler := sprinklers[0]
		physics_probe.global_position = (sprinkler as Node3D).global_position + Vector3(2.0, 1.0, 0.0)
		_check(sprinkler.call("affect_body", physics_probe), "Sprinkler accepts a live blob body")
		await physics_frame
		_check(physics_probe.linear_velocity.y > 0.15 and physics_probe.linear_velocity.x > 0.05, "Sprinkler force is strongly upward and predictably outward")
	physics_probe.linear_velocity = Vector3(11.0, 0.0, 4.0)
	var mushrooms := _elements(arena, "mushroom_pad")
	if not mushrooms.is_empty():
		var mushroom := mushrooms[0]
		physics_probe.global_position = (mushroom as Node3D).global_position + Vector3(1.0, 2.0, 0.0)
		_check(mushroom.call("activate_body", physics_probe), "Mushroom accepts a live blob body")
		await physics_frame
		_check(physics_probe.linear_velocity.y > 12.0 and physics_probe.linear_velocity.x > 11.0, "Mushroom gives a strong angled launch while preserving incoming momentum")
	physics_probe.queue_free()
	_check(_static_body_count(arena) >= 45, "All gameplay-sized Backyard props have solid collision")
	arena.free()
	if failures.is_empty():
		print("BACKYARD BLUEPRINT CONTRACT PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _elements(arena: Node, kind: String) -> Array[Node]:
	var matches: Array[Node] = []
	for node in arena.find_children("*", "Node", true, false):
		if String(node.get_meta("backyard_kind", "")) == kind:
			matches.append(node)
	return matches


func _has_grid_position(arena: Node, kind: String, expected: Vector2) -> bool:
	for node in _elements(arena, kind):
		var actual := node.get_meta("gu_position", Vector2.ZERO) as Vector2
		if actual.distance_to(expected) < 0.03:
			return true
	return false


func _static_body_count(arena: Node) -> int:
	return arena.find_children("*", "StaticBody3D", true, false).size()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
