class_name ArenaModels
extends RefCounted

var arena


func _init(owner) -> void:
	arena = owner


func arcade_cabinet(prefix: String, position: Vector3, facing: float, body: Material, trim: Material, screen: Material) -> Node3D:
	var root := _model_root(prefix, position, facing)
	arena.add_model("arcade_machine", Vector3.ZERO, Vector3.ONE * 5.2, Vector3.ZERO, root, Vector3(7.4, 10.4, 5.8), null, Vector3(0, 5.2, 0))
	return root


func generator(prefix: String, position: Vector3, yaw: float, body: Material, trim: Material, glow: Material) -> Node3D:
	var root := _model_root(prefix, position, yaw)
	arena.add_model("factory_machine_fortified", Vector3.ZERO, Vector3.ONE * 5.0, Vector3.ZERO, root, Vector3(11.5, 8.0, 8.0), null, Vector3(0, 4.0, 0))
	return root


func fan_unit(prefix: String, position: Vector3, yaw: float, frame: Material, blade: Material, glow: Material) -> Node3D:
	var root := _model_root(prefix, position, yaw)
	for x in [-6.5, 6.5]:
		arena.add_box(prefix + "Post", Vector3(x, 7.0, 0), Vector3(1.3, 14.0, 2.0), frame, true, Vector3.ZERO, root)
	for y in [0.8, 13.2]:
		arena.add_box(prefix + "Frame", Vector3(0, y, 0), Vector3(14.3, 1.3, 2.0), frame, true, Vector3.ZERO, root)
	arena.add_torus(prefix + "FanRing", Vector3(0, 7.0, -0.1), 4.7, 6.1, glow, false, Vector3(PI * 0.5, 0, 0), root)
	arena.add_cylinder(prefix + "Hub", Vector3(0, 7.0, -0.1), 1.35, 2.0, frame, false, Vector3(PI * 0.5, 0, 0), root)
	for index in range(4):
		arena.add_box(prefix + "Blade", Vector3(0, 7.0, -0.2), Vector3(1.3, 8.0, 0.55), blade, false, Vector3(0, 0, float(index) * PI * 0.5 + 0.35), root)
	return root


func truss_bridge(prefix: String, position: Vector3, size: Vector3, material: Material, trim: Material) -> Node3D:
	var root := _model_root(prefix, position, 0.0)
	arena.add_box(prefix + "Deck", Vector3.ZERO, size, material, true, Vector3.ZERO, root)
	for side in [-1.0, 1.0]:
		var x: float = side * (size.x * 0.5 - 0.65)
		arena.add_box(prefix + "Rail", Vector3(x, 3.1, 0), Vector3(1.1, 5.2, size.z), trim, false, Vector3.ZERO, root)
		for z in range(int(-size.z * 0.5 + 5.0), int(size.z * 0.5), 10):
			arena.add_box(prefix + "Brace", Vector3(x, 3.4, float(z)), Vector3(1.2, 7.5, 0.7), trim, false, Vector3(0.62, 0, 0), root)
	return root


func garden_shed(prefix: String, position: Vector3, yaw: float, wall: Material, trim: Material, roof: Material) -> Node3D:
	var root := _model_root(prefix, position, yaw)
	var house_id := "suburban_house_c" if prefix.begins_with("Blue") else "suburban_house_a"
	arena.add_model(house_id, Vector3.ZERO, Vector3.ONE * 8.2, Vector3.ZERO, root, Vector3(18, 14, 16), null, Vector3(0, 7.0, 0))
	return root


func tree(prefix: String, position: Vector3, scale_value: float, trunk: Material, leaves: Material) -> Node3D:
	var root := _model_root(prefix, position, 0.0)
	var model_scale := 8.0 * scale_value
	arena.add_model("suburban_tree_large", Vector3.ZERO, Vector3.ONE * model_scale, Vector3.ZERO, root, Vector3(5.0, 15.0, 5.0) * scale_value, null, Vector3(0, 7.5 * scale_value, 0))
	return root


func stadium_barrier(prefix: String, position: Vector3, yaw: float, body: Material, trim: Material, light_material: Material) -> Node3D:
	var root := _model_root(prefix, position, yaw)
	arena.add_model("space_barrier", Vector3.ZERO, Vector3.ONE * 6.0, Vector3.ZERO, root, Vector3(14, 6.0, 5), null, Vector3(0, 3.0, 0))
	return root


func temple_column(prefix: String, position: Vector3, height: float, stone: Material, trim: Material) -> Node3D:
	var root := _model_root(prefix, position, 0.0)
	arena.add_model("nature_statue_column", Vector3.ZERO, Vector3.ONE * (height * 0.42), Vector3.ZERO, root, Vector3(7.0, height + 3.0, 7.0), null, Vector3(0, (height + 3.0) * 0.5, 0))
	return root


func cargo_module(prefix: String, position: Vector3, yaw: float, body: Material, trim: Material, panel: Material) -> Node3D:
	var root := _model_root(prefix, position, yaw)
	arena.add_model("space_container", Vector3.ZERO, Vector3.ONE * 7.0, Vector3.ZERO, root, Vector3(13, 9, 18), null, Vector3(0, 4.5, 0))
	return root


func toy_block(prefix: String, position: Vector3, size: Vector3, body: Material, inset: Material) -> Node3D:
	var root := _model_root(prefix, position, 0.0)
	var model_scale := minf(size.x, size.z) * 0.72
	arena.add_model("toy_item_box", Vector3.ZERO, Vector3.ONE * model_scale, Vector3.ZERO, root, size, null, Vector3(0, size.y * 0.5, 0))
	return root


func lamp(prefix: String, position: Vector3, height: float, frame: Material, glow: Material) -> Node3D:
	var root := _model_root(prefix, position, 0.0)
	arena.add_cylinder(prefix + "Pole", Vector3(0, height * 0.5, 0), 0.45, height, frame, false, Vector3.ZERO, root)
	arena.add_box(prefix + "Arm", Vector3(1.8, height, 0), Vector3(3.6, 0.5, 0.5), frame, false, Vector3.ZERO, root)
	arena.add_sphere(prefix + "Glow", Vector3(3.3, height - 0.4, 0), 0.9, glow, false, root)
	return root


func _model_root(prefix: String, position: Vector3, yaw: float) -> Node3D:
	var root := Node3D.new()
	root.name = prefix
	root.position = position
	root.rotation.y = yaw
	arena.visual_root().add_child(root)
	return root
