extends SceneTree

const NEON_ARCADE := preload("res://scenes/world/maps/neon_arcade.tscn")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var arena := NEON_ARCADE.instantiate() as Node3D
	root.add_child(arena)
	await process_frame
	var blueprint := arena.call("get_neon_arcade_blueprint") as Dictionary
	_check(blueprint.get("footprint_gu") == Vector2(18, 18), "Neon Arcade footprint must be 18 x 18 GU")
	_check(blueprint.get("interior_gu") == Vector2(16, 16), "Neon Arcade interior must be 16 x 16 GU")
	_check(is_equal_approx(float(blueprint.get("wall_height_gu", 0.0)), 6.0), "Neon Arcade walls must be 6 GU")
	_check(is_equal_approx(float(blueprint.get("roof_height_gu", 0.0)), 6.2), "Neon Arcade roof must be 6.2 GU")
	_check(is_equal_approx(float(blueprint.get("floor_thickness_gu", 0.0)), 0.25), "Neon Arcade floor must be 0.25 GU")
	_check(_count(arena, "center_bumper") == 1, "Neon Arcade needs exactly one center bumper")
	_check(_count(arena, "bounce_block") == 0, "The literal blueprint has no invented bounce-block props")
	_check(_count(arena, "low_cover") == 18, "Neon Arcade needs the eighteen image-positioned purple low-cover segments")
	_check(_count(arena, "boost_pad") == 4, "Neon Arcade needs exactly four boost pads")
	_check(_count(arena, "laser_gate") == 4, "Neon Arcade needs exactly four laser gates")
	_check(_count(arena, "corner_ramp") == 4, "Neon Arcade needs exactly four corner ramps")
	_check(_count(arena, "wall_bumper") == 16, "Neon Arcade needs exactly sixteen wall bumpers")
	_check(_count(arena, "wall_ledge") == 16, "Neon Arcade needs exactly sixteen wall ledges")
	_check(_count(arena, "spawn_platform") == 4, "Neon Arcade has the four colored corner towers shown in the image")
	_check(_count(arena, "transparent_roof") == 1, "Neon Arcade needs one transparent roof")
	var center := _first(arena, "center_bumper") as Area3D
	var wall_bumper := _first(arena, "wall_bumper") as Area3D
	var roof := _first(arena, "transparent_roof")
	_check(center != null and is_equal_approx(float(center.get("impulse_strength")), 86.0), "center bumper needs a strong, consistent launch strength")
	_check(wall_bumper != null and float(wall_bumper.get("impulse_strength")) < float(center.get("impulse_strength")), "wall bumpers must be weaker than the center bumper")
	_check(center != null and center.has_node("SolidBumper/SolidCollision"), "center bumper must have a solid physical collider")
	for bumper in _elements(arena, "wall_bumper"):
		_check((bumper as Area3D).has_node("SolidBumper/SolidCollision"), "every wall bumper must be solid")
		var bumper_node := bumper as Node3D
		var bumper_direction := bumper_node.global_basis * (bumper.get("fixed_direction") as Vector3)
		var bumper_to_center := -Vector3(bumper_node.position.x, 0.0, bumper_node.position.z).normalized()
		_check(bumper_direction.normalized().dot(bumper_to_center) > 0.85, "every wall bumper face and impulse must point inward")
	if wall_bumper != null:
		var physics_probe := RigidBody3D.new()
		physics_probe.mass = 2.0
		physics_probe.gravity_scale = 0.0
		physics_probe.collision_layer = 2
		root.add_child(physics_probe)
		await physics_frame
		physics_probe.global_position = (wall_bumper as Node3D).global_position
		var probe_direction := (wall_bumper as Node3D).global_basis * (wall_bumper.get("fixed_direction") as Vector3)
		_check(wall_bumper.call("activate_body", physics_probe), "wall bumper accepts a live body")
		await physics_frame
		_check(physics_probe.linear_velocity.dot(probe_direction.normalized()) > 10.0, "wall bumper applies its rotated inward impulse")
		physics_probe.queue_free()
	_check(_static_body_count(arena) >= 40, "blueprint towers, ramps, covers, walls, and frames need solid collision bodies")
	_check(roof != null and bool(roof.get_meta("bounce_preserving", false)), "transparent roof needs bounce-preserving collision")
	for gate in _elements(arena, "laser_gate"):
		_check(is_equal_approx(float(gate.get("off_duration")), 5.0) and is_equal_approx(float(gate.get("on_duration")), 3.0), "laser gates cycle 5 seconds off and 3 seconds on")
		_check(is_equal_approx(float(gate.get("push_strength")), 48.0), "laser gates need the stronger but non-lethal image-map push")
		var gate_node := gate as Node3D
		var gate_direction := gate_node.global_basis * (gate.get("local_push_direction") as Vector3)
		var gate_to_center := -Vector3(gate_node.position.x, 0.0, gate_node.position.z).normalized()
		_check(gate_direction.normalized().dot(gate_to_center) > 0.9, "laser gates must push inward, never into the walls")
	for boost in _elements(arena, "boost_pad"):
		var toward_center := -((boost as Node3D).position * Vector3(1.0, 0.0, 1.0)).normalized()
		var configured := boost.get("local_direction") as Vector3
		_check(configured.normalized().dot(toward_center) > 0.65, "boost pads must launch toward center")
		_check(is_equal_approx(float(boost.get("impulse_strength")), 56.0), "boost pads need the strengthened medium launch")
	for bumper in _elements(arena, "wall_bumper"):
		_check(is_equal_approx(float(bumper.get("impulse_strength")), 64.0), "wall bumpers need the stronger inward redirect")
	_check(_has_grid_position(arena, "boost_pad", Vector2(6, 6)) and _has_grid_position(arena, "boost_pad", Vector2(12, 6)) and _has_grid_position(arena, "boost_pad", Vector2(6, 12)) and _has_grid_position(arena, "boost_pad", Vector2(12, 12)), "boost pads must use the image's four 6/12-grid positions")
	_check(_has_grid_position(arena, "laser_gate", Vector2(9, 0.52)) and _has_grid_position(arena, "laser_gate", Vector2(9, 17.48)), "north and south laser gates must sit at image boundary midpoints")
	var spawns := arena.call("get_spawn_points") as Array
	_check(spawns.size() == 2, "Neon Arcade exposes exactly two spawns")
	if spawns.size() == 2:
		_check((spawns[0] as Marker3D).position.x < 0.0 and (spawns[0] as Marker3D).position.z < 0.0, "first functional spawn sits on the visible pink P1 tower")
		_check((spawns[1] as Marker3D).position.x > 0.0 and (spawns[1] as Marker3D).position.z > 0.0, "second functional spawn sits on the blueprint's diagonal south-east tower")
		var unit_scale := float(blueprint.get("unit_scale", 11.55))
		var expected_deck_spawn_height := 3.0 * unit_scale + 2.8875 + 0.18
		_check(is_equal_approx((spawns[0] as Marker3D).position.y, expected_deck_spawn_height) and is_equal_approx((spawns[1] as Marker3D).position.y, expected_deck_spawn_height), "spawns must sit on the 3-GU deck, clear of crown and roof geometry")
		for spawn_value in spawns:
			var spawn := spawn_value as Marker3D
			_check(Vector2(spawn.position.x, spawn.position.z).length() < 8.9 * unit_scale, "spawn must be on the platform's inside rim, never inside the glowing core or wall")
			var forward_to_center := -spawn.global_basis.z.normalized()
			var spawn_to_center := -Vector3(spawn.position.x, 0.0, spawn.position.z).normalized()
			_check(forward_to_center.dot(spawn_to_center) > 0.98, "spawn view must face directly into the arena, not into its corner wall")
	arena.free()
	if failures.is_empty():
		print("NEON ARCADE BLUEPRINT CONTRACT PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _count(arena: Node, kind: String) -> int:
	return _elements(arena, kind).size()


func _elements(arena: Node, kind: String) -> Array[Node]:
	var matches: Array[Node] = []
	for node in arena.find_children("*", "Node", true, false):
		if String(node.get_meta("neon_kind", "")) == kind:
			matches.append(node)
	return matches


func _first(arena: Node, kind: String) -> Node:
	var matches := _elements(arena, kind)
	return matches[0] if not matches.is_empty() else null


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
