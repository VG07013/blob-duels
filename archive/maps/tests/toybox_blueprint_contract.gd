extends SceneTree

const TOYBOX := preload("res://scenes/world/maps/toybox.tscn")
const D := 5.776
const GU := 1.444

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var arena := TOYBOX.instantiate() as Node3D
	root.add_child(arena)
	await process_frame
	await physics_frame
	var blueprint := (arena.call("get_map_audit") as Dictionary).get("blueprint", {}) as Dictionary
	_check(blueprint.get("footprint_gu", Vector2.ZERO) == Vector2(64, 128), "Toybox uses the exact 64 x 128 GU blueprint footprint")
	_check(is_equal_approx(float(blueprint.get("gu_scale_d", 0.0)), 0.25), "Toybox keeps 1 GU equal to 0.25 blob diameters")
	_check(is_equal_approx(float(blueprint.get("roof_height_gu", 0.0)), 18.0), "Toybox roof is exactly 18 GU high")
	_check(is_equal_approx(float(blueprint.get("wall_height_gu", 0.0)), 10.0), "Toybox padded walls are exactly 10 GU high")
	_check(_elements(arena, "foam_tile").size() == 128, "Toybox floor has the image's 8 x 16 foam tile grid")
	_check(_elements(arena, "spawn_platform").size() == 2, "Toybox has exactly two raised semicircular spawns")
	_check(_elements(arena, "center_trampoline").size() == 1, "Toybox has one center trampoline")
	_check(_elements(arena, "balance_beam").size() == 4, "Toybox has four purple balance beams")
	_check(_elements(arena, "wedge_block").size() == 4, "Toybox has four green wedge blocks")
	_check(_elements(arena, "launch_ramp").size() == 4, "Toybox has four orange launch ramps")
	_check(_elements(arena, "low_cover").size() == 4, "Toybox has four blue low cover blocks")
	_check(_elements(arena, "boost_pad").size() == 4, "Toybox has four boost pads")
	_check(_elements(arena, "breakable_box").size() == 4, "Toybox has four respawning breakable boxes")
	_check(_elements(arena, "wall_bumper").size() == 4, "Toybox has four powered wall bumper panels")
	_check(_elements(arena, "padded_wall_section").size() >= 40, "Toybox perimeter exposes its repeated padded color blocks")
	_check(_elements(arena, "transparent_roof").size() == 1, "Toybox has one full-coverage collision roof")
	var roof_elements := _elements(arena, "transparent_roof")
	if not roof_elements.is_empty():
		_check(is_equal_approx((roof_elements[0].get_meta("gu_size", Vector3.ZERO) as Vector3).y, 0.4), "Toybox roof collision is exactly 0.4 GU thick")
	_check(_has_grid_position(arena, "center_trampoline", Vector2(32, 64)), "Trampoline is centered at blueprint (32,64)")
	for expected in [Vector2(32, 25), Vector2(32, 103), Vector2(24, 64), Vector2(40, 64)]:
		_check(_has_grid_position(arena, "balance_beam", expected), "Balance beam is missing blueprint coordinate %s" % expected)
	for expected in [Vector2(25, 27), Vector2(39, 27), Vector2(25, 88), Vector2(39, 88)]:
		_check(_has_grid_position(arena, "wedge_block", expected), "Wedge is missing blueprint coordinate %s" % expected)
	for expected in [Vector2(18, 26), Vector2(46, 26), Vector2(18, 89), Vector2(46, 89)]:
		_check(_has_grid_position(arena, "launch_ramp", expected), "Launch ramp is missing blueprint coordinate %s" % expected)
	for expected in [Vector2(11, 10), Vector2(53, 10), Vector2(11, 116), Vector2(53, 116)]:
		_check(_has_grid_position(arena, "boost_pad", expected), "Boost pad is missing blueprint coordinate %s" % expected)
	for expected in [Vector2(17, 10), Vector2(47, 10), Vector2(17, 116), Vector2(47, 116)]:
		_check(_has_grid_position(arena, "breakable_box", expected), "Breakable box is missing blueprint coordinate %s" % expected)
	for expected in [Vector2(2, 39), Vector2(62, 39), Vector2(2, 88), Vector2(62, 88)]:
		_check(_has_grid_position(arena, "wall_bumper", expected), "Wall bumper is missing blueprint coordinate %s" % expected)
	var spawns := arena.call("get_spawn_points") as Array
	_check(spawns.size() == 2, "Toybox exposes exactly two functional spawns")
	if spawns.size() == 2:
		_check(is_equal_approx((spawns[0] as Marker3D).position.z, 59.0 * GU), "Player 1 blue spawn is at blueprint (32,5)")
		_check(is_equal_approx((spawns[1] as Marker3D).position.z, -59.0 * GU), "Player 2 red spawn is at blueprint (32,123)")
		for spawn_value in spawns:
			var spawn := spawn_value as Marker3D
			var forward := -spawn.global_basis.z.normalized()
			var toward_center := -Vector3(spawn.position.x, 0.0, spawn.position.z).normalized()
			_check(forward.dot(toward_center) > 0.98, "Both Toybox spawn cameras face directly down the center lane")
	# Probe the actual physics world at every gameplay-sized visible surface. This
	# catches a mesh/collider mismatch even when visual metadata and counts are right.
	var minimum_surface_height_gu := {
		"spawn_platform": 3.8, "center_trampoline": 1.7, "balance_beam": 2.7,
		"wedge_block": 2.0, "launch_ramp": 1.5, "low_cover": 3.2,
		"boost_pad": 0.15, "breakable_box": 3.7,
	}
	for kind in minimum_surface_height_gu:
		for element in _elements(arena, kind):
			_check(_vertical_surface_probe(arena, element as Node3D, float(minimum_surface_height_gu[kind]) * GU), "%s at %s has no solid collision matching its visible surface" % [kind, element.get_meta("gu_position", Vector2.ZERO)])
	_test_surface_footprints(arena)
	for element in _elements(arena, "wall_bumper"):
		_check(_wall_bumper_probe(arena, element as Node3D), "Wall bumper at %s is not the first solid surface hit from inside the arena" % element.get_meta("gu_position", Vector2.ZERO))
	var probe := RigidBody3D.new()
	probe.mass = 2.0
	probe.gravity_scale = 0.0
	probe.collision_layer = 2
	probe.collision_mask = 1
	root.add_child(probe)
	await physics_frame
	var trampoline := _first(arena, "center_trampoline")
	if trampoline != null:
		probe.linear_velocity = Vector3(14.0, -4.0, 6.0)
		_check(trampoline.has_node("SolidTrampoline/BounceSurfaceCollision"), "Center trampoline has a solid collision surface")
		_check(trampoline.call("activate_body", probe), "Center trampoline accepts a live blob body")
		_check(probe.linear_velocity.y >= 40.0 and Vector2(probe.linear_velocity.x, probe.linear_velocity.z).length() > 15.0, "Trampoline launches strongly while preserving horizontal momentum")
	var boost := _first(arena, "boost_pad")
	if boost != null:
		probe.linear_velocity = Vector3.ZERO
		_check(boost.has_node("SolidPad/PadCollision"), "Boost pad has a solid physical base")
		_check(boost.call("activate_body", probe), "Boost pad accepts a live blob body")
		_check(Vector2(probe.linear_velocity.x, probe.linear_velocity.z).length() > 8.0 and probe.linear_velocity.y > 3.0, "Boost pad launches diagonally inward with medium strength")
	var bumper := _first(arena, "wall_bumper")
	if bumper != null:
		probe.linear_velocity = Vector3(18.0, 7.0, 2.0)
		_check(bumper.has_node("SolidPanel/PanelCollision"), "Wall bumper panel is physically solid")
		_check(bumper.call("activate_body", probe), "Wall bumper reflects a meaningful incoming hit")
		_check(probe.linear_velocity.y == 7.0 and Vector2(probe.linear_velocity.x, probe.linear_velocity.z).length() > 18.0, "Wall bumper preserves vertical speed and adds ten percent horizontal speed")
	var breakable := _first(arena, "breakable_box")
	if breakable != null:
		_check(breakable.has_node("SolidBox/BoxCollision"), "Breakable toy box blocks movement while intact")
		_check(breakable.has_method("strike_body") and is_equal_approx(float(breakable.get("respawn_delay")), 10.0), "Breakable box supports speed-gated breaking and ten-second respawn")
	probe.queue_free()
	_check(_static_body_count(arena) >= 35, "Every gameplay-sized Toybox object has solid collision")
	arena.free()
	if failures.is_empty():
		print("TOYBOX BLUEPRINT CONTRACT PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _elements(arena: Node, kind: String) -> Array[Node]:
	var matches: Array[Node] = []
	for node in arena.find_children("*", "Node", true, false):
		if String(node.get_meta("toybox_kind", "")) == kind:
			matches.append(node)
	return matches


func _first(arena: Node, kind: String) -> Node:
	var matches := _elements(arena, kind)
	return matches[0] if not matches.is_empty() else null


func _has_grid_position(arena: Node, kind: String, expected: Vector2) -> bool:
	for node in _elements(arena, kind):
		if (node.get_meta("gu_position", Vector2.ZERO) as Vector2).distance_to(expected) < 0.03:
			return true
	return false


func _static_body_count(arena: Node) -> int:
	return arena.find_children("*", "StaticBody3D", true, false).size()


func _vertical_surface_probe(arena: Node3D, element: Node3D, minimum_y: float) -> bool:
	return _surface_probe_at(arena, element, Vector2.ZERO, minimum_y)


func _surface_probe_at(arena: Node3D, element: Node3D, local_xz: Vector2, minimum_y: float) -> bool:
	var world_point := element.to_global(Vector3(local_xz.x, 0, local_xz.y))
	var start := Vector3(world_point.x, maxf(element.global_position.y, 0.0) + 12.0 * GU, world_point.z)
	var end := Vector3(world_point.x, -0.2 * GU, world_point.z)
	var query := PhysicsRayQueryParameters3D.create(start, end, 1)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit := arena.get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and (hit.get("position", Vector3.ZERO) as Vector3).y >= minimum_y


func _test_surface_footprints(arena: Node3D) -> void:
	for ramp in _elements(arena, "launch_ramp"):
		var solid := ramp.get_meta("solid_body") as StaticBody3D
		_check(solid != null, "Ramp at %s owns no dedicated solid body" % ramp.get_meta("gu_position", Vector2.ZERO))
		if solid != null:
			var collisions := solid.find_children("*", "CollisionShape3D", true, false)
			_check(collisions.size() == 24, "Ramp at %s must use exactly 24 smooth shared-edge convex collision segments" % ramp.get_meta("gu_position", Vector2.ZERO))
			for collision_value in collisions:
				var collision := collision_value as CollisionShape3D
				_check(collision.shape is ConvexPolygonShape3D, "Ramp collision segments must be convex prisms, never boxes or stairs")
		for x_gu in [-2.4, 0.0, 2.4]:
			for z_gu in [-5.0, -2.5, 0.0, 2.5, 5.0]:
				_check(_surface_probe_at(arena, ramp as Node3D, Vector2(x_gu, z_gu) * GU, 0.01 * GU), "Ramp at %s has a collision gap near local (%s,%s) GU" % [ramp.get_meta("gu_position", Vector2.ZERO), x_gu, z_gu])
	for wedge in _elements(arena, "wedge_block"):
		for x_gu in [-2.2, 0.0, 2.2]:
			for z_gu in [-2.6, 0.0, 2.6]:
				_check(_surface_probe_at(arena, wedge as Node3D, Vector2(x_gu, z_gu) * GU, 0.25 * GU), "Wedge at %s has a collision gap near its footprint edge" % wedge.get_meta("gu_position", Vector2.ZERO))
	for deck in _elements(arena, "spawn_platform"):
		for point_gu in [Vector2(-4.5, -1.2), Vector2(0, -1.2), Vector2(4.5, -1.2), Vector2(-4.5, 0.6), Vector2(0, 4.5), Vector2(4.5, 0.6)]:
			_check(_surface_probe_at(arena, deck as Node3D, point_gu * GU, 3.8 * GU), "Spawn deck at %s is not solid across its 12 x 8 GU D-shaped footprint" % deck.get_meta("gu_position", Vector2.ZERO))
	for kind in ["balance_beam", "low_cover"]:
		for element in _elements(arena, kind):
			var size_gu := element.get_meta("gu_size", Vector3.ZERO) as Vector3
			for x_sign in [-1.0, 1.0]:
				for z_sign in [-1.0, 1.0]:
					var point := Vector2(x_sign * size_gu.x * 0.34, z_sign * size_gu.z * 0.34) * GU
					_check(_surface_probe_at(arena, element as Node3D, point, (size_gu.y - 0.3) * GU), "%s at %s is not solid at a visible corner" % [kind, element.get_meta("gu_position", Vector2.ZERO)])
	for trampoline in _elements(arena, "center_trampoline"):
		for point_gu in [Vector2(-4, 0), Vector2(4, 0), Vector2(0, -4), Vector2(0, 4)]:
			_check(_surface_probe_at(arena, trampoline as Node3D, point_gu * GU, 1.7 * GU), "Trampoline frame has an off-center collision hole")
	for pad in _elements(arena, "boost_pad"):
		for point_gu in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
			_check(_surface_probe_at(arena, pad as Node3D, point_gu * GU, 0.15 * GU), "Boost pad at %s has an off-center collision hole" % pad.get_meta("gu_position", Vector2.ZERO))
	for box in _elements(arena, "breakable_box"):
		for x_sign in [-1.0, 1.0]:
			for z_sign in [-1.0, 1.0]:
				_check(_surface_probe_at(arena, box as Node3D, Vector2(x_sign, z_sign) * 1.35 * GU, 3.7 * GU), "Breakable box at %s is not solid at a visible corner" % box.get_meta("gu_position", Vector2.ZERO))


func _wall_bumper_probe(arena: Node3D, element: Node3D) -> bool:
	var start := Vector3(0, 5.0 * GU, element.global_position.z)
	var end := Vector3(element.global_position.x * 1.08, 5.0 * GU, element.global_position.z)
	var query := PhysicsRayQueryParameters3D.create(start, end, 1)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit := arena.get_world_3d().direct_space_state.intersect_ray(query)
	var collider := hit.get("collider") as Node
	return collider != null and collider.name == "SolidPanel"


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
