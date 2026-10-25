class_name NeonArcadeGeometry
extends RefCounted

## ---------------------------------------------------------------------------
## NEON ARCADE (18 x 18 GU square, 1 GU = two blobs) - flow audit
## Lanes: the two playable towers sit on one diagonal; the four boost pads feed
##   the centre bumper, six low-cover lanes cross the middle, and the perimeter
##   alternates wall bumpers and ledges with a laser gate on each side.
## Vertical routes: four corner towers (3 GU decks on their ramps) and the
##   stacked wall ledges at 2.5 / 4.5 GU; the centre bumper is a low saucer.
## Cover: 8 low covers, 2 mid covers, the hanging centre marquee (11 pieces).
## Signature mechanic: the radial centre bumper plus timed laser gates; the
##   marquee above the bumper is the bank ceiling for shots over the centre.
## Known dead zones: the two unplayable towers (16,2) and (2,16) are pure
##   movement structures, and the wall-ledge stacks are tiny perches rather
##   than routes between towers.
## ---------------------------------------------------------------------------


static func add_chamfered_platform(a, prefix: String, position: Vector3, width: float, height: float, material: Material, collision_material: PhysicsMaterial, trim_material: Material) -> Node3D:
	var root := Node3D.new()
	root.name = prefix
	a.visual_root().add_child(root)
	var half := width * 0.5
	var cut := width * 0.22
	var footprint := PackedVector3Array([
		Vector3(-half + cut, 0.0, -half), Vector3(half - cut, 0.0, -half), Vector3(half, 0.0, -half + cut), Vector3(half, 0.0, half - cut),
		Vector3(half - cut, 0.0, half), Vector3(-half + cut, 0.0, half), Vector3(-half, 0.0, half - cut), Vector3(-half, 0.0, -half + cut),
	])
	# The glowing cap is part of the platform's height, not stacked on top of
	# it: a cap above the collision top had blobs sinking 2.6 units into the
	# spawn towers.
	var trim_height := height * 0.075
	var mesh := _extrude_polygon(footprint, height - trim_height, material)
	var visual := MeshInstance3D.new()
	visual.name = prefix + "Body"
	visual.mesh = mesh
	visual.position = position
	root.add_child(visual)
	var trim := MeshInstance3D.new()
	trim.name = prefix + "TopTrim"
	trim.mesh = _extrude_polygon(footprint, trim_height, trim_material)
	trim.position = position + Vector3.UP * (height - trim_height)
	root.add_child(trim)
	_add_convex_collision(a, prefix, position, footprint, height, collision_material)
	return root


static func add_ramp_prism(a, prefix: String, position: Vector3, width: float, length: float, height: float, yaw: float, material: Material, collision_material: PhysicsMaterial, trim_material: Material) -> Node3D:
	var root := Node3D.new()
	root.name = prefix
	a.visual_root().add_child(root)
	var half_width := width * 0.5
	var half_length := length * 0.5
	var vertices := PackedVector3Array([
		Vector3(-half_width, 0.0, -half_length), Vector3(half_width, 0.0, -half_length), Vector3(half_width, 0.0, half_length), Vector3(-half_width, 0.0, half_length),
		Vector3(-half_width, 0.0, -half_length), Vector3(half_width, 0.0, -half_length), Vector3(half_width, height, half_length), Vector3(-half_width, height, half_length),
	])
	var visual := MeshInstance3D.new()
	visual.name = prefix + "Surface"
	visual.mesh = _mesh_from_vertices(vertices, material)
	visual.position = position
	visual.rotation.y = yaw
	root.add_child(visual)
	var basis := Basis(Vector3.UP, yaw)
	for side in [-1.0, 1.0]:
		var rail := MeshInstance3D.new()
		rail.name = prefix + "NeonSideRail"
		var rail_mesh := BoxMesh.new()
		rail_mesh.size = Vector3(0.035 * width, 0.035 * height, length)
		rail_mesh.material = trim_material
		rail.mesh = rail_mesh
		rail.position = position + basis * Vector3(side * (half_width + 0.035 * width), height * 0.52, 0.0)
		rail.rotation.y = yaw
		root.add_child(rail)
	var body := StaticBody3D.new()
	body.name = prefix + "Solid"
	body.position = position
	body.rotation.y = yaw
	body.collision_layer = 1
	body.collision_mask = 2
	body.physics_material_override = collision_material
	a.add_child(body)
	var collision := CollisionShape3D.new()
	var shape := ConvexPolygonShape3D.new()
	shape.points = vertices
	collision.shape = shape
	body.add_child(collision)
	return root


static func add_chamfered_wall_module(a, prefix: String, position: Vector3, span: float, height: float, depth: float, inward: Vector3, material: Material, collision_material: PhysicsMaterial) -> Node3D:
	# A vertically chamfered, extruded wall bay.  Unlike a flat plane, its eight-sided
	# silhouette catches light at the top/bottom corners and uses the exact same hull for
	# visible geometry and the solid collision volume.
	var root := Node3D.new()
	root.name = prefix
	a.visual_root().add_child(root)
	var along := Vector3.RIGHT if absf(inward.z) > 0.5 else Vector3.FORWARD
	var half_span := span * 0.5
	var half_height := height * 0.5
	var cut := minf(span * 0.14, height * 0.14)
	var profile := PackedVector3Array([
		along * (-half_span + cut) + Vector3.UP * -half_height,
		along * (half_span - cut) + Vector3.UP * -half_height,
		along * half_span + Vector3.UP * (-half_height + cut),
		along * half_span + Vector3.UP * (half_height - cut),
		along * (half_span - cut) + Vector3.UP * half_height,
		along * (-half_span + cut) + Vector3.UP * half_height,
		along * -half_span + Vector3.UP * (half_height - cut),
		along * -half_span + Vector3.UP * (-half_height + cut),
	])
	var vertices := PackedVector3Array()
	for point in profile:
		vertices.append(point - inward * depth * 0.5)
	for point in profile:
		vertices.append(point + inward * depth * 0.5)
	var visual := MeshInstance3D.new()
	visual.name = prefix + "Mesh"
	visual.mesh = _mesh_from_vertices(vertices, material)
	visual.position = position
	root.add_child(visual)
	var body := StaticBody3D.new()
	body.name = prefix + "Solid"
	body.position = position
	body.collision_layer = 1
	body.collision_mask = 2
	body.physics_material_override = collision_material
	a.add_child(body)
	var collision := CollisionShape3D.new()
	var shape := ConvexPolygonShape3D.new()
	shape.points = vertices
	collision.shape = shape
	body.add_child(collision)
	return root


static func _extrude_polygon(footprint: PackedVector3Array, height: float, material: Material) -> ArrayMesh:
	var vertices := PackedVector3Array()
	for point in footprint:
		vertices.append(point)
	for point in footprint:
		vertices.append(point + Vector3.UP * height)
	return _mesh_from_vertices(vertices, material)


static func _mesh_from_vertices(vertices: PackedVector3Array, material: Material) -> ArrayMesh:
	var count := vertices.size() / 2
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(1, count - 1):
		_surface_triangle(surface, vertices[0], vertices[index + 1], vertices[index])
		_surface_triangle(surface, vertices[count], vertices[count + index], vertices[count + index + 1])
	for index in range(count):
		var next := (index + 1) % count
		_surface_triangle(surface, vertices[index], vertices[next], vertices[count + next])
		_surface_triangle(surface, vertices[index], vertices[count + next], vertices[count + index])
	surface.generate_normals()
	var mesh := surface.commit()
	mesh.surface_set_material(0, material)
	return mesh


static func _surface_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	surface.add_vertex(a)
	surface.add_vertex(b)
	surface.add_vertex(c)


static func _add_convex_collision(a, prefix: String, position: Vector3, footprint: PackedVector3Array, height: float, material: PhysicsMaterial) -> void:
	var points := PackedVector3Array()
	for point in footprint:
		points.append(point)
	for point in footprint:
		points.append(point + Vector3.UP * height)
	var body := StaticBody3D.new()
	body.name = prefix + "Solid"
	body.position = position
	body.collision_layer = 1
	body.collision_mask = 2
	body.physics_material_override = material
	a.add_child(body)
	var collision := CollisionShape3D.new()
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	collision.shape = shape
	body.add_child(collision)
