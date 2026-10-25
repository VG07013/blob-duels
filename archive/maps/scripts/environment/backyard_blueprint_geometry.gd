class_name BackyardBlueprintGeometry
extends RefCounted

## ---------------------------------------------------------------------------
## BACKYARD (84 x 64 GU garden, 1 GU = half blob) - flow audit
## Lanes: the centre stone route (spawn deck -> stepping stones -> picnic deck),
##   two hose-planter-mushroom chains per half and the wide sprinkler side lanes.
## Vertical routes: the picnic deck (1.1D), four curved hose ramps (1.4D, all
##   launching inward) and the spawn decks (1.2D); the umbrella canopy is a
##   ceiling for bank shots, not a perch.
## Cover: 4 planters, 2 log stumps, the picnic table and umbrella base, 4
##   spawn side rails (11 pieces).
## Signature mechanic: sprinkler lifts and momentum-preserving mushroom pads.
## Known dead zones: the lawn diagonals between stones and mushrooms were the
##   longest open kill lanes (now broken by the stumps), and the fence corners.
## ---------------------------------------------------------------------------


static func add_umbrella_canopy(a, prefix: String, position: Vector3, radius: float, rise: float, material: Material, trim_material: Material, physics: PhysicsMaterial) -> Node3D:
	# A shallow twelve-panel cone: the visible shell and the convex hull share the
	# same rim, apex and underside, so a shot banks off exactly what it sees.
	var root := Node3D.new()
	root.name = prefix
	root.position = position
	a.visual_root().add_child(root)
	var segments := 12
	var rim := PackedVector3Array()
	for index in range(segments):
		var angle := TAU * float(index) / float(segments)
		rim.append(Vector3(cos(angle) * radius, 0.0, sin(angle) * radius))
	var apex := Vector3(0.0, rise, 0.0)
	var underside := Vector3(0.0, rise * 0.35, 0.0)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(segments):
		var start := rim[index]
		var finish := rim[(index + 1) % segments]
		_triangle(surface, start, finish, apex)
		_triangle(surface, start, underside, finish)
	surface.generate_normals()
	var mesh := surface.commit()
	mesh.surface_set_material(0, material)
	var visual := MeshInstance3D.new()
	visual.name = prefix + "CanopyShell"
	visual.mesh = mesh
	root.add_child(visual)
	for index in range(segments):
		var angle := TAU * (float(index) + 0.5) / float(segments)
		var scallop := MeshInstance3D.new()
		scallop.name = "CanopyScallop"
		var scallop_mesh := SphereMesh.new()
		scallop_mesh.radius = radius * 0.05
		scallop_mesh.height = scallop_mesh.radius * 2.0
		scallop_mesh.radial_segments = 10
		scallop_mesh.rings = 6
		scallop_mesh.material = trim_material
		scallop.mesh = scallop_mesh
		scallop.position = Vector3(cos(angle) * radius * 0.985, -radius * 0.035, sin(angle) * radius * 0.985)
		root.add_child(scallop)
	var finial := MeshInstance3D.new()
	finial.name = "CanopyFinial"
	var finial_mesh := SphereMesh.new()
	finial_mesh.radius = radius * 0.06
	finial_mesh.height = finial_mesh.radius * 2.0
	finial_mesh.material = trim_material
	finial.mesh = finial_mesh
	finial.position = apex + Vector3.UP * radius * 0.04
	root.add_child(finial)
	var body := StaticBody3D.new()
	body.name = prefix + "Solid"
	body.position = position
	body.collision_layer = 1
	body.collision_mask = 2
	body.physics_material_override = physics
	a.add_child(body)
	var collision := CollisionShape3D.new()
	collision.name = prefix + "Collision"
	var shape := ConvexPolygonShape3D.new()
	var points := PackedVector3Array()
	for point in rim:
		points.append(point)
	points.append(apex)
	points.append(underside)
	shape.points = points
	collision.shape = shape
	body.add_child(collision)
	root.set_meta("closed_mesh", true)
	root.set_meta("solid_body", body)
	return root


static func add_curved_hose_ramp(a, prefix: String, position: Vector3, width: float, length: float, height: float, yaw: float, bend_sign: float, body_material: Material, trim_material: Material, physics: PhysicsMaterial) -> Node3D:
	var root := Node3D.new()
	root.name = prefix
	root.position = position
	root.rotation.y = yaw
	a.visual_root().add_child(root)
	var segment_count := 10
	var centers := PackedVector3Array()
	for index in range(segment_count + 1):
		var t := float(index) / float(segment_count)
		var local_z := lerpf(-length * 0.5, length * 0.5, t)
		# A plan-view quadratic bend produces the blueprint hose's readable inward elbow.
		# Subtracting one third keeps the supplied blueprint coordinate at the curve centroid.
		var local_x := bend_sign * length * 0.62 * (t * t - 1.0 / 3.0)
		var local_y := height * t * t * (3.0 - 2.0 * t)
		centers.append(Vector3(local_x, local_y, local_z))
	var lefts := PackedVector3Array()
	var rights := PackedVector3Array()
	for index in range(centers.size()):
		var before := centers[maxi(index - 1, 0)]
		var after := centers[mini(index + 1, centers.size() - 1)]
		var tangent := Vector3(after.x - before.x, 0.0, after.z - before.z).normalized()
		var normal := Vector3(-tangent.z, 0.0, tangent.x)
		lefts.append(centers[index] - normal * width * 0.5)
		rights.append(centers[index] + normal * width * 0.5)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(segment_count):
		var left_a := lefts[index]
		var right_a := rights[index]
		var left_b := lefts[index + 1]
		var right_b := rights[index + 1]
		_triangle(surface, left_a, right_a, right_b)
		_triangle(surface, left_a, right_b, left_b)
		_triangle(surface, left_a, left_b, Vector3(left_b.x, 0, left_b.z))
		_triangle(surface, left_a, Vector3(left_b.x, 0, left_b.z), Vector3(left_a.x, 0, left_a.z))
		_triangle(surface, right_a, Vector3(right_b.x, 0, right_b.z), right_b)
		_triangle(surface, right_a, Vector3(right_a.x, 0, right_a.z), Vector3(right_b.x, 0, right_b.z))
		_triangle(surface, Vector3(left_a.x, 0, left_a.z), Vector3(right_b.x, 0, right_b.z), Vector3(right_a.x, 0, right_a.z))
		_triangle(surface, Vector3(left_a.x, 0, left_a.z), Vector3(left_b.x, 0, left_b.z), Vector3(right_b.x, 0, right_b.z))
	surface.generate_normals()
	var mesh := surface.commit()
	mesh.surface_set_material(0, body_material)
	var visual := MeshInstance3D.new()
	visual.name = prefix + "CurvedPlayableSurface"
	visual.mesh = mesh
	root.add_child(visual)
	var body := StaticBody3D.new()
	body.name = prefix + "SegmentedSolid"
	body.position = position
	body.rotation.y = yaw
	body.collision_layer = 1
	body.collision_mask = 2
	body.physics_material_override = physics
	a.add_child(body)
	for index in range(segment_count):
		var collision := CollisionShape3D.new()
		collision.name = prefix + "CurveCollision%d" % (index + 1)
		var shape := ConvexPolygonShape3D.new()
		var overlap := 0.05
		var left_a := lefts[index].lerp(lefts[maxi(index - 1, 0)], overlap)
		var right_a := rights[index].lerp(rights[maxi(index - 1, 0)], overlap)
		var left_b := lefts[index + 1].lerp(lefts[mini(index + 2, segment_count)], overlap)
		var right_b := rights[index + 1].lerp(rights[mini(index + 2, segment_count)], overlap)
		shape.points = PackedVector3Array([
			left_a, right_a, left_b, right_b,
			Vector3(left_a.x, -0.08, left_a.z), Vector3(right_a.x, -0.08, right_a.z),
			Vector3(left_b.x, -0.08, left_b.z), Vector3(right_b.x, -0.08, right_b.z),
		])
		collision.shape = shape
		body.add_child(collision)
	# Twin continuous hose tubes are visual rails outside the playable inset.
	for side in [-1.0, 1.0]:
		for index in range(segment_count):
			var start := lefts[index] if side < 0.0 else rights[index]
			var finish := lefts[index + 1] if side < 0.0 else rights[index + 1]
			_add_tube(root, start + Vector3.UP * 0.18, finish + Vector3.UP * 0.18, width * 0.13, trim_material)
			_add_joint(root, finish + Vector3.UP * 0.18, width * 0.13, trim_material)
	root.set_meta("curve_collision_segments", segment_count)
	root.set_meta("plan_curve_world", absf(centers[centers.size() - 1].x - centers[0].x))
	root.set_meta("high_end_local", centers[centers.size() - 1])
	root.set_meta("low_end_local", centers[0])
	return root


static func _add_tube(parent: Node3D, start: Vector3, finish: Vector3, radius: float, material: Material) -> void:
	var delta := finish - start
	var visual := MeshInstance3D.new()
	visual.name = "ContinuousHoseTube"
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = delta.length() * 1.035
	mesh.radial_segments = 18
	mesh.material = material
	visual.mesh = mesh
	visual.position = (start + finish) * 0.5
	visual.quaternion = Quaternion(Vector3.UP, delta.normalized())
	parent.add_child(visual)


static func _add_joint(parent: Node3D, position: Vector3, radius: float, material: Material) -> void:
	var visual := MeshInstance3D.new()
	visual.name = "HoseJoint"
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 14
	mesh.rings = 8
	mesh.material = material
	visual.mesh = mesh
	visual.position = position
	parent.add_child(visual)


static func _triangle(surface: SurfaceTool, first: Vector3, second: Vector3, third: Vector3) -> void:
	surface.add_vertex(first)
	surface.add_vertex(second)
	surface.add_vertex(third)
