class_name EnvironmentArt
extends RefCounted


static func decorate(arena, theme_id: int) -> void:
	match theme_id:
		0:
			_decorate_neon_arcade(arena)
		1:
			_decorate_backyard(arena)
		2:
			_decorate_arena(arena)
		3:
			_decorate_sky_temple(arena)
		4:
			_decorate_toybox(arena)


static func _decorate_neon_arcade(a) -> void:
	var cabinet_ids := [
		"arcade_machine", "arcade_claw", "arcade_pinball", "arcade_dance",
		"arcade_air_hockey", "arcade_basketball", "arcade_ticket", "arcade_vending",
	]
	var z_positions := [-96.0, -48.0, 48.0, 96.0]
	for side_index in range(2):
		var side := -1.0 if side_index == 0 else 1.0
		for index in range(z_positions.size()):
			var model_id: String = cabinet_ids[(index + side_index * 3) % cabinet_ids.size()]
			a.add_model(model_id, Vector3(side * 32.5, 10.9, z_positions[index]), Vector3.ONE * 4.6, Vector3(0, -side * PI * 0.5, 0))
	for z in [-62.0, 62.0]:
		a.add_model("arcade_prize_wheel", Vector3(-20.0, 1.5, z), Vector3.ONE * 4.4, Vector3(0, PI if z > 0.0 else 0.0, 0))
	a.add_model("arcade_claw", Vector3(-17.0, 0.2, -52.0), Vector3.ONE * 7.2, Vector3(0, -0.35, 0), null, Vector3(6.0, 10.0, 6.0), null, Vector3(0, 5.0, 0))
	a.add_model("arcade_pinball", Vector3(17.0, 0.2, 52.0), Vector3.ONE * 7.0, Vector3(0, PI - 0.35, 0), null, Vector3(6.0, 8.0, 7.0), null, Vector3(0, 4.0, 0))


static func _decorate_backyard(a) -> void:
	var houses := ["suburban_house_a", "suburban_house_c", "suburban_house_f", "suburban_house_k"]
	var house_positions := [
		Vector3(-31.5, 0, -102), Vector3(31.5, 0, 102),
	]
	for index in range(house_positions.size()):
		var position: Vector3 = house_positions[index]
		a.add_model(houses[index], position, Vector3.ONE * 7.5, Vector3(0, PI * 0.5 * float(index % 2) + (PI if position.z > 0.0 else 0.0), 0))
	for z in [-80.0, -36.0, 36.0, 80.0]:
		for side in [-1.0, 1.0]:
			var tree_id := "suburban_tree_large" if int(absf(z)) % 3 == 0 else "suburban_tree_small"
			a.add_model(tree_id, Vector3(side * 33.0, 0, z), Vector3.ONE * (7.0 if tree_id.ends_with("large") else 6.0), Vector3(0, z * 0.02, 0))
	for z in [-54.0, 54.0]:
		a.add_model("suburban_planter", Vector3(-26.0, 0, z), Vector3.ONE * 5.2, Vector3(0, PI * 0.5, 0))
		a.add_model("suburban_stones", Vector3(26.0, 0.15, z), Vector3.ONE * 6.0, Vector3(0, -0.3, 0))
	a.add_model("suburban_house_f", Vector3(-22.0, 0, -54.0), Vector3.ONE * 8.5, Vector3(0, 0.25, 0), null, Vector3(12.0, 12.0, 12.0), null, Vector3(0, 6.0, 0))
	a.add_model("suburban_planter", Vector3(20.0, 0, 54.0), Vector3.ONE * 7.0, Vector3(0, -0.4, 0), null, Vector3(8.0, 5.0, 8.0), null, Vector3(0, 2.5, 0))


static func _decorate_arena(a) -> void:
	var machinery := [
		"factory_machine", "factory_machine_fortified", "factory_robot_a", "factory_robot_b",
		"factory_crane", "factory_crane_magnet", "factory_piston", "factory_screen",
	]
	var z_positions := [-96.0, -48.0, 48.0, 96.0]
	for side_index in range(2):
		var side := -1.0 if side_index == 0 else 1.0
		for index in range(z_positions.size()):
			var model_id: String = machinery[(index + side_index * 4) % machinery.size()]
			a.add_model(model_id, Vector3(side * 32.0, 0.5, z_positions[index]), Vector3.ONE * 5.2, Vector3(0, -side * PI * 0.5, 0))
	for z in [-34.0, 34.0]:
		a.add_model("factory_cog_a", Vector3(-29.0, 6.0, z), Vector3.ONE * 5.0, Vector3(PI * 0.5, 0, 0))
		a.add_model("factory_cog_c", Vector3(29.0, 6.0, z), Vector3.ONE * 5.0, Vector3(PI * 0.5, 0, 0))
	a.add_model("factory_robot_a", Vector3(-18.0, 0.2, -34.0), Vector3.ONE * 7.0, Vector3(0, 0.4, 0), null, Vector3(8.0, 10.0, 8.0), null, Vector3(0, 5.0, 0))
	a.add_model("factory_robot_b", Vector3(18.0, 0.2, 34.0), Vector3.ONE * 7.0, Vector3(0, PI + 0.4, 0), null, Vector3(8.0, 10.0, 8.0), null, Vector3(0, 5.0, 0))
	for z in [-84.0, 84.0]:
		a.add_model("building_wall_window", Vector3(-35.0, 5.5, z), Vector3.ONE * 7.0, Vector3(0, PI * 0.5, 0))
		a.add_model("building_plating", Vector3(35.0, 5.5, z), Vector3.ONE * 7.0, Vector3(0, -PI * 0.5, 0))


static func _decorate_sky_temple(a) -> void:
	for z in [-72.0, 72.0]:
		var gate_id := "temple_gate" if int(absf(z)) % 3 == 0 else "temple_gate_bars"
		a.add_model(gate_id, Vector3(-31.0, 0, z), Vector3.ONE * 5.5, Vector3(0, PI * 0.5, 0))
		a.add_model("temple_wall_detail", Vector3(31.0, 5.0, z), Vector3.ONE * 6.0, Vector3(0, -PI * 0.5, 0))
	for z in [-78.0, 78.0]:
		a.add_model("nature_statue_column", Vector3(-21.0, 0, z), Vector3.ONE * 7.0)
		a.add_model("nature_statue_damaged", Vector3(21.0, 0, z), Vector3.ONE * 7.0, Vector3(0, PI, 0))
	for z in [-58.0, 58.0]:
		a.add_model("nature_obelisk", Vector3(-29.0, 0, z), Vector3.ONE * 6.5)
		a.add_model("nature_statue_head", Vector3(29.0, 0, z), Vector3.ONE * 6.5, Vector3(0, -0.4, 0))
	a.add_model("temple_gate", Vector3(-31.0, 0, 0), Vector3.ONE * 5.5, Vector3(0, PI * 0.5, 0))
	a.add_model("temple_wall_detail", Vector3(31.0, 5.0, 0), Vector3.ONE * 6.0, Vector3(0, -PI * 0.5, 0))
static func _decorate_toybox(a) -> void:
	var vehicles := ["toy_racer", "toy_vintage_racer", "toy_monster_truck", "toy_speedster"]
	for side_index in range(2):
		var side := -1.0 if side_index == 0 else 1.0
		for index in range(2):
			var z: float = [-64.0, 64.0][index]
			a.add_model(vehicles[(index + side_index) % vehicles.size()], Vector3(side * 29.0, 1.0, z), Vector3.ONE * 6.0, Vector3(0, -side * PI * 0.5, 0))
	for z in [-74.0, 74.0]:
		a.add_model("toy_track_curve", Vector3(-20.0, 0.35, z), Vector3.ONE * 5.8, Vector3(0, PI * 0.5, 0))
		a.add_model("toy_track", Vector3(20.0, 0.35, z), Vector3.ONE * 5.8, Vector3(0, PI * 0.5, 0))
