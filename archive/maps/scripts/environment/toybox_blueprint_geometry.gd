class_name ToyboxBlueprintGeometry
extends RefCounted

## ---------------------------------------------------------------------------
## TOYBOX (64 x 128 GU foam play mat, 1 GU = quarter blob) - flow audit
## Lanes: centre lane (spawn descent -> balance beam -> trampoline -> mirror),
##   ramp lanes (boost pad -> plastic launch ramp -> green wedge -> centre) and
##   wall lanes (launch ramp -> powered wall bumper -> centre beam).
## Vertical routes: spawn decks (4 GU), the wall toy shelves (6 GU) reached by
##   a foam wedge at each end, the alphabet block perches (8.8 GU) and the
##   trampoline launch. Every blueprint piece is lower than one blob (4 GU),
##   so the shelves and block stacks are what give the map readable high ground.
## Cover: 4 beams, 4 blue low covers, 4 breakable boxes, 2 block stacks, 2
##   shelves. Only the block stacks are taller than a blob, so they are the
##   pieces that hide each spawn from the other down the centre lane.
## Signature mechanic: the momentum-preserving centre trampoline, kept alive by
##   wall bumpers; the shelf dive (shelf -> trampoline) is the high-ground commit.
## Known dead zones: the corners behind the breakable boxes (grid y < 8 and
##   > 120) and the floor strips outside the shelf ramps at grid y 44-47 / 81-84.
## ---------------------------------------------------------------------------


static func add_beveled_box(a, prefix: String, position: Vector3, size: Vector3, bevel: float, material: Material, physics: PhysicsMaterial) -> Node3D:
	var half_x := size.x * 0.5
	var half_z := size.z * 0.5
	var cut := minf(bevel, minf(half_x, half_z) * 0.42)
	var polygon := PackedVector2Array([
		Vector2(-half_x + cut, -half_z), Vector2(half_x - cut, -half_z),
		Vector2(half_x, -half_z + cut), Vector2(half_x, half_z - cut),
		Vector2(half_x - cut, half_z), Vector2(-half_x + cut, half_z),
		Vector2(-half_x, half_z - cut), Vector2(-half_x, -half_z + cut),
	])
	return _add_extruded_polygon(a, prefix, position, polygon, size.y, material, physics)


static func add_semicircle_platform(a, prefix: String, position: Vector3, radius: float, thickness: float, yaw: float, material: Material, physics: PhysicsMaterial) -> Node3D:
	# A true D-shape: the rounded face projects 6 GU toward play and the 2 GU
	# straight-back section keeps the blueprint center safely on the solid deck.
	var back_depth := radius / 3.0
	var polygon := PackedVector2Array([Vector2(-radius, -back_depth), Vector2(-radius, 0)])
	for index in range(1, 12):
		var angle := PI - PI * float(index) / 12.0
		polygon.append(Vector2(cos(angle) * radius, sin(angle) * radius))
	polygon.append(Vector2(radius, 0))
	polygon.append(Vector2(radius, -back_depth))
	var root := _add_extruded_polygon(a, prefix, position, polygon, thickness, material, physics)
	root.rotation.y = yaw
	var solid := root.get_meta("solid_body") as StaticBody3D
	if solid != null:
		solid.rotation.y = yaw
	return root


static func add_wedge(a, prefix: String, position: Vector3, width: float, length: float, low_height: float, high_height: float, yaw: float, material: Material, trim: Material, physics: PhysicsMaterial) -> Node3D:
	var root := Node3D.new()
	root.name = prefix
	root.position = position
	root.rotation.y = yaw
	a.visual_root().add_child(root)
	var points := PackedVector3Array([
		Vector3(-width * 0.5, 0, -length * 0.5), Vector3(width * 0.5, 0, -length * 0.5),
		Vector3(-width * 0.5, 0, length * 0.5), Vector3(width * 0.5, 0, length * 0.5),
		Vector3(-width * 0.5, low_height, -length * 0.5), Vector3(width * 0.5, low_height, -length * 0.5),
		Vector3(-width * 0.5, high_height, length * 0.5), Vector3(width * 0.5, high_height, length * 0.5),
	])
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	_quad(surface, points[4], points[5], points[7], points[6])
	_quad(surface, points[0], points[2], points[3], points[1])
	_quad(surface, points[0], points[1], points[5], points[4])
	_quad(surface, points[2], points[6], points[7], points[3])
	_quad(surface, points[0], points[4], points[6], points[2])
	_quad(surface, points[1], points[3], points[7], points[5])
	surface.generate_normals()
	var mesh := surface.commit()
	mesh.surface_set_material(0, material)
	var visual := MeshInstance3D.new()
	visual.name = prefix + "TriangularPrism"
	visual.mesh = mesh
	root.add_child(visual)
	var top_trim := MeshInstance3D.new()
	top_trim.name = prefix + "SoftTopTrim"
	var trim_mesh := BoxMesh.new()
	trim_mesh.size = Vector3(width * 0.92, 0.11, length * 0.86)
	trim_mesh.material = trim
	top_trim.mesh = trim_mesh
	top_trim.position = Vector3(0, (low_height + high_height) * 0.5 + 0.08, 0)
	top_trim.rotation.x = -atan2(high_height - low_height, length)
	root.add_child(top_trim)
	var solid := _add_convex_body(a, prefix, position, yaw, points, physics)
	root.set_meta("solid_body", solid)
	return root


static func add_curved_ramp(a, prefix: String, position: Vector3, width: float, length: float, height: float, lip_height: float, yaw: float, material: Material, trim: Material, physics: PhysicsMaterial) -> Node3D:
	var root := Node3D.new()
	root.name = prefix
	root.position = position
	root.rotation.y = yaw
	a.visual_root().add_child(root)
	var segments := 24
	var vertices := PackedVector3Array()
	for index in range(segments + 1):
		var t := float(index) / float(segments)
		var z := lerpf(-length * 0.5, length * 0.5, t)
		var y := height * t * t * (3.0 - 2.0 * t)
		if index == segments:
			y += lip_height
		vertices.append(Vector3(-width * 0.5, y, z))
		vertices.append(Vector3(width * 0.5, y, z))
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(segments):
		var left_a := vertices[index * 2]
		var right_a := vertices[index * 2 + 1]
		var left_b := vertices[(index + 1) * 2]
		var right_b := vertices[(index + 1) * 2 + 1]
		_quad(surface, left_a, right_a, right_b, left_b)
		_quad(surface, left_a, left_b, Vector3(left_b.x, 0, left_b.z), Vector3(left_a.x, 0, left_a.z))
		_quad(surface, right_a, Vector3(right_a.x, 0, right_a.z), Vector3(right_b.x, 0, right_b.z), right_b)
		_quad(surface, Vector3(left_a.x, 0, left_a.z), Vector3(left_b.x, 0, left_b.z), Vector3(right_b.x, 0, right_b.z), Vector3(right_a.x, 0, right_a.z))
	var low_left := vertices[0]
	var low_right := vertices[1]
	var high_left := vertices[vertices.size() - 2]
	var high_right := vertices[vertices.size() - 1]
	_quad(surface, Vector3(low_left.x, 0, low_left.z), low_left, low_right, Vector3(low_right.x, 0, low_right.z))
	_quad(surface, Vector3(high_left.x, 0, high_left.z), Vector3(high_right.x, 0, high_right.z), high_right, high_left)
	surface.generate_normals()
	var mesh := surface.commit()
	mesh.surface_set_material(0, material)
	var visual := MeshInstance3D.new()
	visual.name = prefix + "ContinuousSurface"
	visual.mesh = mesh
	root.add_child(visual)
	for side in [-1.0, 1.0]:
		var rail := MeshInstance3D.new()
		rail.name = prefix + "PaddedRail"
		var rail_mesh := BoxMesh.new()
		rail_mesh.size = Vector3(width * 0.10, 0.18, length * 0.92)
		rail_mesh.material = trim
		rail.mesh = rail_mesh
		rail.position = Vector3(side * width * 0.48, height * 0.54, 0)
		root.add_child(rail)
	var solid := _add_curved_ramp_collision(a, prefix, position, yaw, width, vertices, physics)
	root.set_meta("solid_body", solid)
	return root


static func _add_curved_ramp_collision(a, prefix: String, position: Vector3, yaw: float, width: float, vertices: PackedVector3Array, physics: PhysicsMaterial) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = prefix + "SegmentedSolid"
	body.position = position
	body.rotation.y = yaw
	body.collision_layer = 1
	body.collision_mask = 2
	body.physics_material_override = physics
	a.add_child(body)
	var segment_count := vertices.size() / 2 - 1
	for index in range(segment_count):
		var left_a := vertices[index * 2]
		var right_a := vertices[index * 2 + 1]
		var left_b := vertices[(index + 1) * 2]
		var right_b := vertices[(index + 1) * 2 + 1]
		var collision := CollisionShape3D.new()
		collision.name = "%sRampCollision%02d" % [prefix, index]
		var shape := ConvexPolygonShape3D.new()
		shape.points = PackedVector3Array([
			left_a, right_a, left_b, right_b,
			left_a - Vector3.UP * 0.34, right_a - Vector3.UP * 0.34,
			left_b - Vector3.UP * 0.34, right_b - Vector3.UP * 0.34,
		])
		collision.shape = shape
		body.add_child(collision)
	return body


static func _add_extruded_polygon(a, prefix: String, position: Vector3, polygon: PackedVector2Array, height: float, material: Material, physics: PhysicsMaterial) -> Node3D:
	var root := Node3D.new()
	root.name = prefix
	root.position = position
	a.visual_root().add_child(root)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(1, polygon.size() - 1):
		_triangle(surface, Vector3(polygon[0].x, height, polygon[0].y), Vector3(polygon[index].x, height, polygon[index].y), Vector3(polygon[index + 1].x, height, polygon[index + 1].y))
		_triangle(surface, Vector3(polygon[0].x, 0, polygon[0].y), Vector3(polygon[index + 1].x, 0, polygon[index + 1].y), Vector3(polygon[index].x, 0, polygon[index].y))
	for index in range(polygon.size()):
		var next := (index + 1) % polygon.size()
		_quad(surface,
			Vector3(polygon[index].x, 0, polygon[index].y), Vector3(polygon[next].x, 0, polygon[next].y),
			Vector3(polygon[next].x, height, polygon[next].y), Vector3(polygon[index].x, height, polygon[index].y))
	surface.generate_normals()
	var mesh := surface.commit()
	mesh.surface_set_material(0, material)
	var visual := MeshInstance3D.new()
	visual.name = prefix + "BeveledVisual"
	visual.mesh = mesh
	root.add_child(visual)
	var points := PackedVector3Array()
	for point in polygon:
		points.append(Vector3(point.x, 0, point.y))
		points.append(Vector3(point.x, height, point.y))
	var body := _add_convex_body(a, prefix, position, 0.0, points, physics)
	root.set_meta("solid_body", body)
	return root


static func _add_convex_body(a, prefix: String, position: Vector3, yaw: float, points: PackedVector3Array, physics: PhysicsMaterial) -> StaticBody3D:
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
