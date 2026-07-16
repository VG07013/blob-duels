class_name ArenaBlueprintGeometry
extends RefCounted

## Continuous tournament-ramp geometry.  The curved top, visible shell, and
## collision hull share the same authored profile so no hidden box edges catch a Blob.

static func add_curved_ramp(a, prefix: String, position: Vector3, width: float, length: float, height: float, yaw: float, material: Material, surface_material: PhysicsMaterial, trim: Material) -> Node3D:
	var root := Node3D.new()
	root.name = prefix
	root.position = position
	root.rotation.y = yaw
	a.visual_root().add_child(root)
	var segments := 12
	var vertices := PackedVector3Array()
	for index in range(segments + 1):
		var t := float(index) / float(segments)
		var z := lerpf(-length * 0.5, length * 0.5, t)
		var y := height * t * t * (3.0 - 2.0 * t)
		vertices.append(Vector3(-width * 0.5, y, z))
		vertices.append(Vector3(width * 0.5, y, z))
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(segments):
		var left_a := vertices[index * 2]
		var right_a := vertices[index * 2 + 1]
		var left_b := vertices[(index + 1) * 2]
		var right_b := vertices[(index + 1) * 2 + 1]
		_triangle(surface, left_a, right_a, right_b)
		_triangle(surface, left_a, right_b, left_b)
		# Close the solid side shells down to the floor; this is one continuous ramp, not steps.
		_triangle(surface, left_a, left_b, Vector3(left_b.x, 0, left_b.z))
		_triangle(surface, left_a, Vector3(left_b.x, 0, left_b.z), Vector3(left_a.x, 0, left_a.z))
		_triangle(surface, right_a, Vector3(right_b.x, 0, right_b.z), right_b)
		_triangle(surface, right_a, Vector3(right_a.x, 0, right_a.z), Vector3(right_b.x, 0, right_b.z))
	_triangle(surface, Vector3(-width * 0.5, 0, -length * 0.5), Vector3(width * 0.5, 0, -length * 0.5), vertices[1])
	_triangle(surface, Vector3(-width * 0.5, 0, -length * 0.5), vertices[1], vertices[0])
	surface.generate_normals()
	var mesh := surface.commit()
	mesh.surface_set_material(0, material)
	var visual := MeshInstance3D.new()
	visual.name = prefix + "ContinuousSurface"
	visual.mesh = mesh
	root.add_child(visual)
	# Distinct industrial side rails sit just outside the solid hull and cannot create a catch.
	for side in [-1.0, 1.0]:
		var rail := MeshInstance3D.new()
		rail.name = prefix + "RaisedRail"
		var rail_mesh := BoxMesh.new()
		rail_mesh.size = Vector3(0.12 * width, 0.075 * height + 0.14, length * 0.94)
		rail_mesh.material = trim
		rail.mesh = rail_mesh
		rail.position = Vector3(side * (width * 0.5 + rail_mesh.size.x * 0.36), height * 0.54, 0)
		root.add_child(rail)
	var body := StaticBody3D.new()
	body.name = prefix + "Solid"
	body.position = position
	body.rotation.y = yaw
	body.collision_layer = 1
	body.collision_mask = 2
	body.physics_material_override = surface_material
	a.add_child(body)
	var collision := CollisionShape3D.new()
	var shape := ConvexPolygonShape3D.new()
	var hull := PackedVector3Array()
	for vertex in vertices:
		hull.append(vertex)
		hull.append(Vector3(vertex.x, 0, vertex.z))
	shape.points = hull
	collision.shape = shape
	body.add_child(collision)
	return root


static func add_beveled_redirect(a, prefix: String, position: Vector3, length: float, height: float, depth: float, yaw: float, body_material: Material, trim: Material, physics: PhysicsMaterial) -> Node3D:
	var root := Node3D.new()
	root.name = prefix
	root.position = position
	root.rotation.y = yaw
	a.visual_root().add_child(root)
	var base := MeshInstance3D.new()
	base.name = prefix + "BeveledBody"
	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(depth, height, length)
	base_mesh.material = body_material
	base.mesh = base_mesh
	root.add_child(base)
	for z in [-length * 0.5 + 0.34, length * 0.5 - 0.34]:
		var cap := MeshInstance3D.new()
		cap.name = prefix + "EndCap"
		var cap_mesh := BoxMesh.new()
		cap_mesh.size = Vector3(depth + 0.16, height * 0.82, 0.20)
		cap_mesh.material = trim
		cap.mesh = cap_mesh
		cap.position = Vector3(0, height * 0.08, z)
		cap.rotation.x = 0.12 * signf(z)
		root.add_child(cap)
	var upper := MeshInstance3D.new()
	upper.name = prefix + "TopEdge"
	var upper_mesh := BoxMesh.new()
	upper_mesh.size = Vector3(depth + 0.18, 0.11, length * 0.9)
	upper_mesh.material = trim
	upper.mesh = upper_mesh
	upper.position = Vector3(0, height * 0.5 + 0.06, 0)
	root.add_child(upper)
	var inset := MeshInstance3D.new()
	inset.name = prefix + "InsetFace"
	var inset_mesh := BoxMesh.new()
	inset_mesh.size = Vector3(0.05, height * 0.56, length * 0.68)
	inset_mesh.material = body_material
	inset.mesh = inset_mesh
	inset.position = Vector3(-depth * 0.53, 0.0, 0)
	root.add_child(inset)
	var body := StaticBody3D.new()
	body.name = prefix + "Solid"
	body.position = position
	body.rotation.y = yaw
	body.collision_layer = 1
	body.collision_mask = 2
	body.physics_material_override = physics
	a.add_child(body)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(depth, height, length)
	collision.shape = shape
	body.add_child(collision)
	return root


static func _triangle(surface: SurfaceTool, first: Vector3, second: Vector3, third: Vector3) -> void:
	surface.add_vertex(first)
	surface.add_vertex(second)
	surface.add_vertex(third)
