extends RefCounted


func build(a) -> Dictionary:
	var w: float = a.arena_half_width
	var l: float = a.arena_half_length
	_build_playroom_floor(a, w, l)
	_build_clockwork_station(a)
	_build_block_routes(a, w, l)
	_build_duel_flow(a)
	_build_toy_props(a, w, l)
	_build_interactables(a, w)
	return {
		"identity": "Sunlit playroom rail yard assembled from chunky clockwork toys",
		"landmark": "Clockwork Rail Station",
		"routes": ["fast rail straight", "west block-fort flank", "east picture-book flank", "moving carriage reconnection", "inward rail boosters", "spring-drum opening", "broken upper block islands"],
		"interactables": ["clock hand bumper", "spring launch drums", "moving toy carriages", "rail conveyors", "pinwheel wind tunnels"],
		"prop_families": ["studded toy blocks", "clockwork train cars", "picture books", "wooden rail pieces", "stacking rings", "playroom lamps"],
		"flow_plan": ["Center: exposed rail sprint reaches the station first", "Left: staggered block forts create a protected but broken flank", "Right: picture-book cover trades distance for carriage and pinwheel reconnections"],
		"combat_spaces": ["clear spring-drum exits prevent spawn stalls", "alternating toy cover creates compact flank duels", "the station turntable is the shared center contest", "inner book covers support readable returns from both flanks"],
	}


func _build_playroom_floor(a, w: float, l: float) -> void:
	a.add_box("PlayRug", Vector3(0, 0.12, 0), Vector3(w * 2.0 - 8.0, 0.24, l * 2.0 - 10.0), a.mat("rug_blue"), true, Vector3.ZERO, null, a.surface("normal"))
	for x in range(int(-w + 8), int(w - 7), 12):
		for z in range(int(-l + 12), int(l - 11), 16):
			var palette: Array = [a.mat("toy_red"), a.mat("toy_yellow"), a.mat("toy_green"), a.mat("toy_blue")]
			var material: Material = palette[posmod(int(x / 12) + int(z / 16), palette.size())]
			a.add_box("RugPatch", Vector3(float(x), 0.3, float(z)), Vector3(10.8, 0.08, 14.8), material, false)
	for x in [-8.0, 8.0]:
		a.add_box("Rail", Vector3(x, 0.5, 0), Vector3(1.2, 0.55, l * 1.72), a.mat("dark_metal"), false)
	for z in range(-100, 101, 10):
		a.add_box("RailTie", Vector3(0, 0.38, float(z)), Vector3(22, 0.35, 1.2), a.mat("wood_dark"), false)
	for side in [-1.0, 1.0]:
		a.add_box("SpringMat", Vector3(side * 23.0, 0.34, -34.0 * side), Vector3(14.0, 0.3, 18.0), a.mat("toy_yellow"), true, Vector3.ZERO, null, a.surface("bounce"))


func _build_clockwork_station(a) -> void:
	var landmark: Node3D = a.add_landmark_root("ClockworkRailStation")
	a.add_cylinder("TurntableBase", Vector3(0, 0.24, 0), 11.0, 0.28, a.mat("wood_light"), true, Vector3.ZERO, landmark)
	a.add_torus("TurntableRail", Vector3(0, 0.4, 0), 9.0, 10.2, a.mat("dark_metal"), false, Vector3.ZERO, landmark)
	a.add_trimmed_box("StationHouse", Vector3(0, 15.0, 0), Vector3(24, 8, 18), a.mat("toy_green"), a.mat("toy_yellow"), true, landmark)
	a.add_box("StationRoofA", Vector3(-6.0, 20.0, 0), Vector3(14, 1.6, 22), a.mat("toy_red"), true, Vector3(0, 0, -0.5), landmark)
	a.add_box("StationRoofB", Vector3(6.0, 20.0, 0), Vector3(14, 1.6, 22), a.mat("toy_red"), true, Vector3(0, 0, 0.5), landmark)
	for x in [-7.0, 7.0]:
		a.add_box("StationWindow", Vector3(x, 12.5, -9.25), Vector3(5.0, 4.5, 0.4), a.mat("glass"), false, Vector3.ZERO, landmark)
	a.add_trimmed_box("ClockTower", Vector3(0, 29.0, 2.0), Vector3(10, 14, 10), a.mat("toy_blue"), a.mat("toy_yellow"), true, landmark)
	a.add_cylinder("ClockFace", Vector3(0, 31.0, -3.25), 3.7, 0.35, a.mat("white"), false, Vector3(PI * 0.5, 0, 0), landmark)
	for angle in [0.0, PI * 0.5]:
		a.add_box("ClockHand", Vector3(0, 31.0, -3.5), Vector3(0.45, 4.8, 0.25), a.mat("black"), false, Vector3(0, 0, angle), landmark)
	a.add_box("StationPlatformNorth", Vector3(0, 0.24, -17.0), Vector3(34, 0.28, 13), a.mat("wood_light"), true, Vector3.ZERO, landmark)
	a.add_box("StationPlatformSouth", Vector3(0, 0.24, 17.0), Vector3(34, 0.28, 13), a.mat("wood_light"), true, Vector3.ZERO, landmark)


func _build_block_routes(a, w: float, l: float) -> void:
	for side in [-1.0, 1.0]:
		for z in [-78.0, -56.0, -32.0, 32.0, 56.0, 78.0]:
			var palette: Array = [a.mat("toy_red"), a.mat("toy_blue"), a.mat("toy_green"), a.mat("toy_yellow")]
			var material: Material = palette[posmod(int(z / 28) + (0 if side < 0 else 2), palette.size())]
			a.models.toy_block("RouteBlock", Vector3(side * (w - 8.0), 0, z), Vector3(13, 9 + posmod(int(z), 3) * 2, 16), material, a.mat("white"))
		for z in [-62.0, 0.0, 62.0]:
			var ramp_material: Material = a.mat("toy_yellow") if z == 0.0 else (a.mat("toy_red") if z > 0 else a.mat("toy_blue"))
			a.add_ramp("BookRamp", Vector3(side * (w - 18.0), 5.0, z), Vector3(20, 2.3, 14), ramp_material, Vector3(0, 0, -side * 0.46))
		for segment_z in [-62.0, 0.0, 62.0]:
			var segment_length: float = 30.0 if segment_z != 0.0 else 24.0
			a.add_box("UpperBlockIsland", Vector3(side * (w - 10.0), 12.0, segment_z), Vector3(12, 1.6, segment_length), a.mat("wood_light"), true)
	a.models.truss_bridge("ClockBalcony", Vector3(0, 19.0, 0), Vector3(w * 1.32, 1.6, 8), a.mat("toy_blue"), a.mat("toy_yellow"))
	for z in [-48.0, 48.0]:
		a.add_arch("BlockGate", Vector3(0, 0, z), 23.0, 14.0, a.mat("toy_green"), a.mat("toy_yellow"))


func _build_duel_flow(a) -> void:
	# Alternating block and book shapes make each protected step easy to parse.
	a.add_duel_cover("NorthRailCrate", Vector3(-9, 2.2, -70), Vector3(10, 4.4, 5), a.mat("toy_yellow"), a.mat("white"), "center", "attack_break")
	a.add_duel_cover("NorthWestFort", Vector3(-21, 2.7, -55), Vector3(8, 5.4, 6), a.mat("toy_blue"), a.mat("toy_yellow"), "left", "flank_peek", Vector3(0, 0.14, 0))
	a.add_duel_cover("NorthEastBook", Vector3(21, 2.7, -38), Vector3(8, 5.4, 5.5), a.mat("toy_red"), a.mat("white"), "right", "flank_peek", Vector3(0, -0.14, 0))
	a.add_duel_cover("NorthWestLink", Vector3(-20, 2.3, -18), Vector3(8, 4.6, 5), a.mat("toy_green"), a.mat("toy_yellow"), "left", "center_link")
	a.add_duel_cover("SouthRailCrate", Vector3(9, 2.2, 70), Vector3(10, 4.4, 5), a.mat("toy_yellow"), a.mat("white"), "center", "attack_break")
	a.add_duel_cover("SouthEastFort", Vector3(21, 2.7, 55), Vector3(8, 5.4, 6), a.mat("toy_blue"), a.mat("toy_yellow"), "right", "flank_peek", Vector3(0, 0.14, 0))
	a.add_duel_cover("SouthWestBook", Vector3(-21, 2.7, 38), Vector3(8, 5.4, 5.5), a.mat("toy_red"), a.mat("white"), "left", "flank_peek", Vector3(0, -0.14, 0))
	a.add_duel_cover("SouthEastLink", Vector3(20, 2.3, 18), Vector3(8, 4.6, 5), a.mat("toy_green"), a.mat("toy_yellow"), "right", "center_link")
	a.add_duel_cover("WestStationPocket", Vector3(-24, 2.4, -8), Vector3(7, 4.8, 5), a.mat("toy_blue"), a.mat("white"), "left", "center_pocket", Vector3(0, -0.18, 0))
	a.add_duel_cover("EastStationPocket", Vector3(24, 2.4, 8), Vector3(7, 4.8, 5), a.mat("toy_red"), a.mat("white"), "right", "center_pocket", Vector3(0, -0.18, 0))
	for page_z in [-38.0, 38.0]:
		var page_x: float = -21.0 * signf(page_z)
		for stripe in [-2.4, 0.0, 2.4]:
			a.add_box("DuelBookPage", Vector3(page_x + stripe, 5.72, page_z), Vector3(1.8, 0.16, 4.5), a.mat("paper"), false)

	for z in [-74.0, -38.0, 38.0, 74.0]:
		var center_direction: Vector3 = Vector3(0, 0, -signf(z))
		a.add_flow_anchor("RailRush", Vector3(0, 1, z), "attack_route", "center")
		a.add_route_chevron("RailRush", Vector3(0, 0.42, z), center_direction, a.mat("toy_yellow"), 0.88)
	for z in [-92.0, -28.0, 28.0, 92.0]:
		for side in [-1.0, 1.0]:
			var lane: String = "left" if side < 0 else "right"
			var flank_direction := Vector3(-side * 0.5, 0, -signf(z)).normalized()
			a.add_flow_anchor("ToyFlank", Vector3(side * 10, 1, z), "flank_route", lane)
			a.add_route_chevron("ToyFlank", Vector3(side * 10, 0.44, z), flank_direction, a.mat("white"), 0.8)


func _build_toy_props(a, w: float, l: float) -> void:
	for z in [-82.0, 82.0]:
		for x in [-20.0, 20.0]:
			a.models.cargo_module("TrainCar", Vector3(x, 0, z), 0.0 if z < 0 else PI, a.mat("toy_red") if x < 0 else a.mat("toy_green"), a.mat("toy_yellow"), a.mat("cyan"))
	for z in [-72.0, 72.0]:
		for side in [-1.0, 1.0]:
			var x: float = side * 20.0
			for ring in range(4):
				a.add_torus("StackingRing", Vector3(x, 1.0 + ring * 1.4, z), 2.8 - ring * 0.35, 3.7 - ring * 0.35, [a.mat("toy_red"), a.mat("toy_yellow"), a.mat("toy_green"), a.mat("toy_blue")][ring], false)
	for z in range(int(-l + 12), int(l - 11), 20):
		a.models.lamp("PlayroomLamp", Vector3(-w + 3.0, 0, float(z)), 11.0, a.mat("wood_dark"), a.mat("warm_light"))
		a.models.lamp("PlayroomLamp", Vector3(w - 3.0, 0, float(z)), 11.0, a.mat("wood_dark"), a.mat("warm_light"))


func _build_interactables(a, w: float) -> void:
	var clock_hand: Node3D = a.add_rotating_bumper(Vector3(0, 6.0, 0), 29.0, 0.92, 27.0, Color(0.96, 0.24, 0.18))
	a.mark_duel_interactable(clock_hand, "keeps the station turntable dangerous and contestable", false)
	for z in [-77.0, 77.0]:
		var spring_drum: Area3D = a.add_launch_pad(Vector3(0, 0.62, z), Vector3(0, 0.52, -signf(z)), 56.0, Color(1.0, 0.7, 0.12))
		a.mark_duel_interactable(spring_drum, "springs a fast opening down the exposed rail straight", true)
	for z in [-43.0, 43.0]:
		for side in [-1.0, 1.0]:
			var rail_booster: Area3D = a.add_conveyor(Vector3(side * 8.0, 0.72, z), Vector3(6.5, 1.0, 18), Vector3(0, 0, -signf(z)), 72.0, Color(0.2, 0.72, 1.0))
			a.mark_duel_interactable(rail_booster, "short inward rail boost that ends before the station fight", true)
	for side in [-1.0, 1.0]:
		var carriage_z: float = -46.0 * side
		var carriage: AnimatableBody3D = a.add_moving_platform(Vector3(side * 23.0, 6.0, carriage_z), Vector3(-side * 11.0, 7.0, side * 12.0), Vector3(15, 1.5, 10), 3.5, Color(0.22, 0.72, 0.32), 0.5 if side > 0 else 0.0)
		a.mark_duel_interactable(carriage, "crosses a block-island gap and reconnects toward the station", true)
		var pinwheel_z: float = -24.0 * side
		a.models.fan_unit("ToyPinwheel", Vector3(side * (w - 7.0), 0, pinwheel_z), -side * PI * 0.5, a.mat("toy_yellow"), a.mat("toy_red"), a.mat("cyan"))
		var wind_direction: Vector3 = Vector3(-side, 0.16, side * 0.58).normalized()
		var pinwheel_tunnel: Area3D = a.add_wind_zone(Vector3(side * (w - 20.0), 7.0, pinwheel_z), Vector3(23, 13, 12), wind_direction, 94.0, Color(0.35, 0.82, 1.0))
		a.mark_duel_interactable(pinwheel_tunnel, "turns the outer book flank diagonally back to the station", true)
