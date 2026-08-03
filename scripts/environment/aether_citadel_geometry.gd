class_name AetherCitadelGeometry
extends RefCounted


static func add_extruded_polygon(a, prefix: String, position: Vector3, polygon: PackedVector2Array, height: float, material: Material, physics: PhysicsMaterial, yaw := 0.0) -> Node3D:
	var root := Node3D.new()
	root.name = prefix
	root.position = position
	root.rotation.y = yaw
	a.visual_root().add_child(root)
	var mesh := _extruded_mesh(polygon, height, material)
	var visual := MeshInstance3D.new()
	visual.name = prefix + "ClosedModel"
	visual.mesh = mesh
	root.add_child(visual)
	var points := PackedVector3Array()
	for point in polygon:
		points.append(Vector3(point.x, 0, point.y))
		points.append(Vector3(point.x, height, point.y))
	var body := _convex_body(a, prefix, position, yaw, points, physics)
	root.set_meta("solid_body", body)
	return root


static func add_d_platform(a, prefix: String, position: Vector3, width: float, depth: float, height: float, toward_positive_z: bool, material: Material, physics: PhysicsMaterial) -> Node3D:
	var radius := width * 0.5
	var straight_depth := depth - radius
	var polygon := PackedVector2Array()
	var sign_z := 1.0 if toward_positive_z else -1.0
	polygon.append(Vector2(-radius, -sign_z * straight_depth))
	polygon.append(Vector2(radius, -sign_z * straight_depth))
	for index in range(13):
		var angle := float(index) / 12.0 * PI
		var x := cos(angle) * radius
		var z := sin(angle) * radius * sign_z
		polygon.append(Vector2(x, z))
	return add_extruded_polygon(a, prefix, position, polygon, height, material, physics)


static func add_curved_ramp(a, prefix: String, position: Vector3, width: float, length: float, height: float, lip: float, yaw: float, material: Material, trim: Material, physics: PhysicsMaterial) -> Node3D:
	var root := Node3D.new()
	root.name = prefix
	root.position = position
	root.rotation.y = yaw
	a.visual_root().add_child(root)
	var segments := 24
	var profile := PackedVector3Array()
	for index in range(segments + 1):
		var t := float(index) / float(segments)
		var smooth := t * t * (3.0 - 2.0 * t)
		var y := height * smooth + (lip * pow(t, 10.0))
		profile.append(Vector3(-width * 0.5, y, lerpf(-length * 0.5, length * 0.5, t)))
		profile.append(Vector3(width * 0.5, y, lerpf(-length * 0.5, length * 0.5, t)))
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(segments):
		var la := profile[index * 2]
		var ra := profile[index * 2 + 1]
		var lb := profile[(index + 1) * 2]
		var rb := profile[(index + 1) * 2 + 1]
		_quad(surface, la, ra, rb, lb)
		_quad(surface, la, lb, Vector3(lb.x, 0, lb.z), Vector3(la.x, 0, la.z))
		_quad(surface, ra, Vector3(ra.x, 0, ra.z), Vector3(rb.x, 0, rb.z), rb)
		_quad(surface, Vector3(la.x, 0, la.z), Vector3(lb.x, 0, lb.z), Vector3(rb.x, 0, rb.z), Vector3(ra.x, 0, ra.z))
		var points := PackedVector3Array([
			la, ra, lb, rb,
			Vector3(la.x, minf(0.0, la.y - 0.48), la.z), Vector3(ra.x, minf(0.0, ra.y - 0.48), ra.z),
			Vector3(lb.x, minf(0.0, lb.y - 0.48), lb.z), Vector3(rb.x, minf(0.0, rb.y - 0.48), rb.z),
		])
		_convex_body(a, "%sSegment%02d" % [prefix, index], position, yaw, points, physics)
	surface.generate_normals()
	var mesh := surface.commit()
	mesh.surface_set_material(0, material)
	var visual := MeshInstance3D.new()
	visual.name = prefix + "ContinuousCurvedShell"
	visual.mesh = mesh
	root.add_child(visual)
	for side in [-1.0, 1.0]:
		var rail := MeshInstance3D.new()
		rail.name = prefix + "GoldEdgeRail"
		var rail_mesh := BoxMesh.new()
		rail_mesh.size = Vector3(width * 0.055, 0.18, length * 0.94)
		rail_mesh.material = trim
		rail.mesh = rail_mesh
		rail.position = Vector3(side * width * 0.49, height * 0.48, 0)
		rail.rotation.x = -atan2(height, length)
		root.add_child(rail)
	root.set_meta("segment_count", segments)
	root.set_meta("closed_mesh", true)
	return root


static func add_bowed_ramp(a, prefix: String, position: Vector3, width: float, length: float, height: float, lip: float, yaw: float, bow_direction: float, material: Material, trim: Material, physics: PhysicsMaterial) -> Node3D:
	var root := Node3D.new()
	root.name = prefix
	root.position = position
	root.rotation.y = yaw
	a.visual_root().add_child(root)
	var segments := 24
	var left := PackedVector3Array()
	var right := PackedVector3Array()
	var arc := 1.05
	var radius := length / (2.0 * sin(arc * 0.5))
	for index in range(segments + 1):
		var t := float(index) / float(segments)
		var angle := lerpf(-arc * 0.5, arc * 0.5, t)
		var center := Vector3(bow_direction * (radius * cos(angle) - radius * cos(arc * 0.5)), 0, radius * sin(angle))
		var tangent := Vector3(-bow_direction * sin(angle), 0, cos(angle)).normalized()
		var normal := Vector3(tangent.z, 0, -tangent.x)
		var smooth := t * t * (3.0 - 2.0 * t)
		center.y = height * smooth + lip * pow(t, 10.0)
		left.append(center - normal * width * 0.5)
		right.append(center + normal * width * 0.5)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var trim_surface := SurfaceTool.new()
	trim_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(segments):
		var la := left[index]
		var ra := right[index]
		var lb := left[index + 1]
		var rb := right[index + 1]
		_quad(surface, la, ra, rb, lb)
		_quad(surface, la, lb, Vector3(lb.x, 0, lb.z), Vector3(la.x, 0, la.z))
		_quad(surface, ra, Vector3(ra.x, 0, ra.z), Vector3(rb.x, 0, rb.z), rb)
		_quad(surface, Vector3(la.x, 0, la.z), Vector3(lb.x, 0, lb.z), Vector3(rb.x, 0, rb.z), Vector3(ra.x, 0, ra.z))
		var edge_width := width * 0.055
		_quad(trim_surface, la + Vector3.UP * 0.10, la.lerp(ra, edge_width / width) + Vector3.UP * 0.10, lb.lerp(rb, edge_width / width) + Vector3.UP * 0.10, lb + Vector3.UP * 0.10)
		_quad(trim_surface, ra + Vector3.UP * 0.10, ra.lerp(la, edge_width / width) + Vector3.UP * 0.10, rb.lerp(lb, edge_width / width) + Vector3.UP * 0.10, rb + Vector3.UP * 0.10)
		var points := PackedVector3Array([
			la, ra, lb, rb,
			Vector3(la.x, minf(0.0, la.y - 0.48), la.z), Vector3(ra.x, minf(0.0, ra.y - 0.48), ra.z),
			Vector3(lb.x, minf(0.0, lb.y - 0.48), lb.z), Vector3(rb.x, minf(0.0, rb.y - 0.48), rb.z),
		])
		_convex_body(a, "%sBowedSegment%02d" % [prefix, index], position, yaw, points, physics)
	surface.generate_normals()
	var mesh := surface.commit()
	mesh.surface_set_material(0, material)
	var visual := MeshInstance3D.new()
	visual.name = prefix + "BowedContinuousShell"
	visual.mesh = mesh
	root.add_child(visual)
	trim_surface.generate_normals()
	var trim_mesh := trim_surface.commit()
	trim_mesh.surface_set_material(0, trim)
	var trim_visual := MeshInstance3D.new()
	trim_visual.name = prefix + "ContinuousGoldEdges"
	trim_visual.mesh = trim_mesh
	root.add_child(trim_visual)
	root.set_meta("segment_count", segments)
	root.set_meta("closed_mesh", true)
	return root


static func add_crescent_terrace(a, prefix: String, position: Vector3, outer_radius: float, inner_radius: float, height: float, open_to_right: bool, material: Material, trim: Material, physics: PhysicsMaterial, yaw := 0.0, with_rail := true) -> Node3D:
	var root := Node3D.new()
	root.name = prefix
	root.position = position
	root.rotation.y = yaw
	a.visual_root().add_child(root)
	var center_angle := 0.0 if open_to_right else PI
	var segments := 18
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var trim_surface := SurfaceTool.new()
	trim_surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var edge_width := minf((outer_radius - inner_radius) * 0.14, outer_radius * 0.035)
	for index in range(segments):
		var a0 := center_angle - PI * 0.48 + PI * 0.96 * float(index) / float(segments)
		var a1 := center_angle - PI * 0.48 + PI * 0.96 * float(index + 1) / float(segments)
		var polygon := PackedVector2Array([
			Vector2(cos(a0), sin(a0)) * inner_radius,
			Vector2(cos(a0), sin(a0)) * outer_radius,
			Vector2(cos(a1), sin(a1)) * outer_radius,
			Vector2(cos(a1), sin(a1)) * inner_radius,
		])
		var inner_a := Vector3(polygon[0].x, 0, polygon[0].y)
		var outer_a := Vector3(polygon[1].x, 0, polygon[1].y)
		var outer_b := Vector3(polygon[2].x, 0, polygon[2].y)
		var inner_b := Vector3(polygon[3].x, 0, polygon[3].y)
		_quad(surface, inner_a + Vector3.UP * height, outer_a + Vector3.UP * height, outer_b + Vector3.UP * height, inner_b + Vector3.UP * height)
		_quad(surface, inner_a, inner_b, outer_b, outer_a)
		_quad(surface, outer_a, outer_b, outer_b + Vector3.UP * height, outer_a + Vector3.UP * height)
		_quad(surface, inner_b, inner_a, inner_a + Vector3.UP * height, inner_b + Vector3.UP * height)
		var outer_trim_a := outer_a.lerp(inner_a, edge_width / (outer_radius - inner_radius)) + Vector3.UP * (height + 0.08)
		var outer_trim_b := outer_b.lerp(inner_b, edge_width / (outer_radius - inner_radius)) + Vector3.UP * (height + 0.08)
		_quad(trim_surface, outer_a + Vector3.UP * (height + 0.08), outer_trim_a, outer_trim_b, outer_b + Vector3.UP * (height + 0.08))
		var inner_trim_a := inner_a.lerp(outer_a, edge_width / (outer_radius - inner_radius)) + Vector3.UP * (height + 0.08)
		var inner_trim_b := inner_b.lerp(outer_b, edge_width / (outer_radius - inner_radius)) + Vector3.UP * (height + 0.08)
		_quad(trim_surface, inner_a + Vector3.UP * (height + 0.08), inner_b + Vector3.UP * (height + 0.08), inner_trim_b, inner_trim_a)
		if index == 0:
			_quad(surface, inner_a, outer_a, outer_a + Vector3.UP * height, inner_a + Vector3.UP * height)
		if index == segments - 1:
			_quad(surface, outer_b, inner_b, inner_b + Vector3.UP * height, outer_b + Vector3.UP * height)
		var points := PackedVector3Array()
		for point in polygon:
			points.append(Vector3(point.x, 0, point.y))
			points.append(Vector3(point.x, height, point.y))
		_convex_body(a, "%sWingSolid%02d" % [prefix, index], position, yaw, points, physics)
	surface.generate_normals()
	var mesh := surface.commit()
	mesh.surface_set_material(0, material)
	var visual := MeshInstance3D.new()
	visual.name = prefix + "ContinuousWingShell"
	visual.mesh = mesh
	root.add_child(visual)
	trim_surface.generate_normals()
	var trim_mesh := trim_surface.commit()
	trim_mesh.surface_set_material(0, trim)
	var trim_visual := MeshInstance3D.new()
	trim_visual.name = prefix + "ContinuousGoldInlay"
	trim_visual.mesh = trim_mesh
	root.add_child(trim_visual)
	# Only the outside arc is railed; the inward crescent stays a movement exit.
	if with_rail:
		for index in range(10):
			var angle := center_angle - PI * 0.46 + PI * 0.92 * float(index) / 9.0
			var rail_position := Vector3(cos(angle) * outer_radius, height + 1.25, sin(angle) * outer_radius)
			var post := MeshInstance3D.new()
			post.name = "SkyrailPost"
			var post_mesh := CylinderMesh.new()
			post_mesh.top_radius = 0.22
			post_mesh.bottom_radius = 0.32
			post_mesh.height = 2.5
			post_mesh.material = trim
			post.mesh = post_mesh
			post.position = rail_position
			root.add_child(post)
	root.set_meta("closed_mesh", true)
	return root


static func clipped_rectangle(width: float, length: float, clip: float) -> PackedVector2Array:
	var x := width * 0.5
	var z := length * 0.5
	return PackedVector2Array([
		Vector2(-x + clip, -z), Vector2(x - clip, -z), Vector2(x, -z + clip), Vector2(x, z - clip),
		Vector2(x - clip, z), Vector2(-x + clip, z), Vector2(-x, z - clip), Vector2(-x, -z + clip),
	])


static func _extruded_mesh(polygon: PackedVector2Array, height: float, material: Material) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(1, polygon.size() - 1):
		_triangle(surface, Vector3(polygon[0].x, height, polygon[0].y), Vector3(polygon[index].x, height, polygon[index].y), Vector3(polygon[index + 1].x, height, polygon[index + 1].y))
		_triangle(surface, Vector3(polygon[0].x, 0, polygon[0].y), Vector3(polygon[index + 1].x, 0, polygon[index + 1].y), Vector3(polygon[index].x, 0, polygon[index].y))
	for index in range(polygon.size()):
		var next := (index + 1) % polygon.size()
		_quad(surface, Vector3(polygon[index].x, 0, polygon[index].y), Vector3(polygon[next].x, 0, polygon[next].y), Vector3(polygon[next].x, height, polygon[next].y), Vector3(polygon[index].x, height, polygon[index].y))
	surface.generate_normals()
	var mesh := surface.commit()
	mesh.surface_set_material(0, material)
	return mesh


static func _convex_body(a, prefix: String, position: Vector3, yaw: float, points: PackedVector3Array, physics: PhysicsMaterial) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = prefix + "Solid"
	body.position = position
	body.rotation.y = yaw
	body.collision_layer = 1
	body.collision_mask = 2
	body.physics_material_override = physics
	a.add_child(body)
	var collision := CollisionShape3D.new()
	collision.name = prefix + "Collision"
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	collision.shape = shape
	body.add_child(collision)
	return body


static func _quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	_triangle(surface, a, b, c)
	_triangle(surface, a, c, d)


static func _triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	surface.add_vertex(a)
	surface.add_vertex(b)
	surface.add_vertex(c)
