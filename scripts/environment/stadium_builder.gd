extends RefCounted


func build(a) -> Dictionary:
	var w: float = a.arena_half_width
	var l: float = a.arena_half_length
	_build_court(a, w, l)
	_build_power_crown(a)
	_build_stands_and_routes(a, w, l)
	_build_duel_flow(a)
	_build_equipment(a, w, l)
	_build_interactables(a, w)
	return {
		"identity": "Bright televised blob-sport stadium with industrial competition hardware",
		"landmark": "Power Crown scoring reactor",
		"routes": ["fast crown rush", "west broadcast flank", "east service flank", "suspended scoring bridge", "inward conveyor relays", "launch-gate recovery", "staggered broadcast cover"],
		"interactables": ["power crown sweepers", "team launch gates", "sideline conveyors", "scoreboard lifts", "cross-court wind gates"],
		"prop_families": ["stadium barriers", "grandstands", "score pylons", "broadcast gantries", "equipment cargo", "team tunnels"],
		"flow_plan": ["Center: exposed sprint through the Power Crown", "Left: broadcast barriers protect a broken west approach", "Right: service cover and movement relays reconnect to the crown"],
		"combat_spaces": ["spawn exits stay open until the first midfield barrier", "staggered flank cover creates short peek-to-peek duels", "the Power Crown remains the high-risk center contest", "inner sideline cover forms two readable reconnection pockets"],
	}


func _build_court(a, w: float, l: float) -> void:
	a.add_box("CourtSurface", Vector3(0, 0.12, 0), Vector3(w * 2.0 - 8.0, 0.24, l * 2.0 - 10.0), a.mat("court"), true, Vector3.ZERO, null, a.surface("normal"))
	a.add_box("CenterStripe", Vector3(0, 0.3, 0), Vector3(w * 2.0 - 10.0, 0.08, 0.8), a.mat("white"), false)
	for x in [-25.0, 25.0]:
		a.add_box("Sideline", Vector3(x, 0.31, 0), Vector3(0.7, 0.08, l * 2.0 - 16), a.mat("white"), false)
	for z in range(int(-l + 16), int(l - 15), 16):
		var color: Material = a.mat("team_blue") if z < 0 else a.mat("team_red")
		a.add_box("TeamHash", Vector3(0, 0.32, float(z)), Vector3(11, 0.09, 0.65), color, false)
	for z in [-92.0, -64.0, 64.0, 92.0]:
		a.add_cylinder("CourtMark", Vector3(0, 0.35, z), 8.5, 0.08, a.mat("white"), false)
		a.add_cylinder("CourtMarkInset", Vector3(0, 0.4, z), 6.5, 0.09, a.mat("court"), false)


func _build_power_crown(a) -> void:
	var landmark: Node3D = a.add_landmark_root("PowerCrown")
	a.add_cylinder("CrownPit", Vector3(0, 0.24, 0), 11.0, 0.28, a.mat("dark_metal"), true, Vector3.ZERO, landmark)
	a.add_cylinder("CrownRing", Vector3(0, 0.4, 0), 10.2, 0.08, a.mat("hazard"), false, Vector3.ZERO, landmark)
	for index in range(6):
		var angle: float = TAU * float(index) / 6.0
		var p: Vector3 = Vector3(cos(angle) * 14.0, 5.5, sin(angle) * 14.0)
		a.add_trimmed_box("CrownPylon", p, Vector3(4.2, 8, 4.2), a.mat("orange"), a.mat("dark_metal"), true, landmark)
	a.add_cylinder("CrownMast", Vector3(0, 13.0, 0), 3.6, 20.0, a.mat("dark_metal"), true, Vector3.ZERO, landmark)
	a.add_torus("CrownHalo", Vector3(0, 21.0, 0), 8.0, 9.3, a.mat("warm_light"), false, Vector3(PI * 0.5, 0, 0), landmark)
	for index in range(4):
		var angle: float = TAU * float(index) / 4.0
		a.add_box("CrownBlade", Vector3(cos(angle) * 7.0, 21.0 + sin(angle) * 7.0, 0), Vector3(2.0, 6.5, 1.0), a.mat("orange"), false, Vector3(0, 0, -angle), landmark)
	a.add_sphere("CrownCore", Vector3(0, 21.0, 0), 3.1, a.mat("cyan"), false, landmark)


func _build_stands_and_routes(a, w: float, l: float) -> void:
	for side in [-1.0, 1.0]:
		for tier in range(3):
			var x: float = side * (w - 4.0 - float(tier) * 3.1)
			var height: float = 3.0 + float(tier) * 3.0
			for segment_z in [-66.0, 0.0, 66.0]:
				var segment_length: float = 34.0 - float(tier) * 2.0 if segment_z != 0.0 else 26.0 - float(tier) * 2.0
				a.add_box("GrandstandIsland", Vector3(x, height * 0.5, segment_z), Vector3(6.0, height, segment_length), a.mat("concrete") if tier < 2 else a.mat("blue_gray"), true)
				for seat_offset in [-7.0, 7.0]:
					var seat_z: float = segment_z + seat_offset
					var seat: Material = a.mat("team_blue") if seat_z < 0 else a.mat("team_red")
					a.add_box("SeatBank", Vector3(x - side * 0.3, height + 0.6, seat_z), Vector3(5.7, 1.0, 9.0), seat, false)
		for z in [-66.0, 0.0, 66.0]:
			a.add_ramp("StandRamp", Vector3(side * (w - 15.0), 5.2, z), Vector3(20, 2.0, 11), a.mat("hazard"), Vector3(0, 0, -side * 0.5))
	a.models.truss_bridge("ScoreBridge", Vector3(0, 17.0, 0), Vector3(w * 1.42, 1.8, 8), a.mat("dark_metal"), a.mat("orange"))
	for z in [-48.0, 48.0]:
		a.add_arch("TeamTunnel", Vector3(0, 0, z), 25.0, 13.0, a.mat("team_blue") if z < 0 else a.mat("team_red"), a.mat("white"))


func _build_duel_flow(a) -> void:
	# Low broadcast barricades stagger sightlines without sealing any lane.
	a.add_duel_cover("NorthCenterBroadcast", Vector3(-9, 2.1, -68), Vector3(11, 4.2, 5.2), a.mat("dark_metal"), a.mat("orange"), "center", "attack_break")
	a.add_duel_cover("NorthWestBroadcast", Vector3(-20, 2.5, -52), Vector3(8, 5, 6), a.mat("blue_gray"), a.mat("team_blue"), "left", "flank_peek", Vector3(0, 0.14, 0))
	a.add_duel_cover("NorthEastBroadcast", Vector3(20, 2.5, -36), Vector3(8, 5, 6), a.mat("dark_metal"), a.mat("orange"), "right", "flank_peek", Vector3(0, -0.14, 0))
	a.add_duel_cover("NorthWestLink", Vector3(-20, 2.2, -20), Vector3(9, 4.4, 5.5), a.mat("blue_gray"), a.mat("orange"), "left", "center_link")
	a.add_duel_cover("SouthCenterBroadcast", Vector3(9, 2.1, 68), Vector3(11, 4.2, 5.2), a.mat("dark_metal"), a.mat("orange"), "center", "attack_break")
	a.add_duel_cover("SouthEastBroadcast", Vector3(20, 2.5, 52), Vector3(8, 5, 6), a.mat("blue_gray"), a.mat("team_red"), "right", "flank_peek", Vector3(0, 0.14, 0))
	a.add_duel_cover("SouthWestBroadcast", Vector3(-20, 2.5, 36), Vector3(8, 5, 6), a.mat("dark_metal"), a.mat("orange"), "left", "flank_peek", Vector3(0, -0.14, 0))
	a.add_duel_cover("SouthEastLink", Vector3(20, 2.2, 20), Vector3(9, 4.4, 5.5), a.mat("blue_gray"), a.mat("orange"), "right", "center_link")
	a.add_duel_cover("WestCrownPocket", Vector3(-24, 2.3, -7), Vector3(7, 4.6, 5), a.mat("dark_metal"), a.mat("team_blue"), "left", "center_pocket", Vector3(0, -0.18, 0))
	a.add_duel_cover("EastCrownPocket", Vector3(24, 2.3, 7), Vector3(7, 4.6, 5), a.mat("dark_metal"), a.mat("team_red"), "right", "center_pocket", Vector3(0, -0.18, 0))

	for z in [-72.0, -36.0, 36.0, 72.0]:
		var center_direction: Vector3 = Vector3(0, 0, -signf(z))
		a.add_flow_anchor("CenterRush", Vector3(0, 1, z), "attack_route", "center")
		a.add_route_chevron("CenterRush", Vector3(0, 0.38, z), center_direction, a.mat("white"), 0.9)
	for z in [-92.0, -36.0, 36.0, 92.0]:
		var flank_x: float = 22.0 if absf(z) > 50.0 else 8.0
		for side in [-1.0, 1.0]:
			var lane: String = "left" if side < 0 else "right"
			var flank_direction := Vector3(-side * 0.45, 0, -signf(z)).normalized()
			a.add_flow_anchor("BroadcastFlank", Vector3(side * flank_x, 1, z), "flank_route", lane)
			a.add_route_chevron("BroadcastFlank", Vector3(side * flank_x, 0.4, z), flank_direction, a.mat("orange"), 0.82)


func _build_equipment(a, w: float, l: float) -> void:
	for side in [-1.0, 1.0]:
		for z in [-82.0, -60.0, -30.0, 30.0, 60.0, 82.0]:
			a.models.stadium_barrier("Barrier", Vector3(side * 25.0, 0, z), -side * PI * 0.5, a.mat("dark_metal"), a.mat("orange"), a.mat("warm_light"))
	for z in [-72.0, 72.0]:
		for x in [-17.0, 17.0]:
			a.models.cargo_module("TeamEquipment", Vector3(x, 0, z), 0.0 if z < 0 else PI, a.mat("team_blue") if z < 0 else a.mat("team_red"), a.mat("white"), a.mat("cyan"))
	for z in range(int(-l + 14), int(l - 13), 18):
		a.models.lamp("BroadcastLamp", Vector3(-w + 2.8, 0, float(z)), 16.0, a.mat("dark_metal"), a.mat("warm_light"))
		a.models.lamp("BroadcastLamp", Vector3(w - 2.8, 0, float(z)), 16.0, a.mat("dark_metal"), a.mat("warm_light"))
	for z in [-88.0, 88.0]:
		var desk_x: float = -22.0 if z < 0.0 else 22.0
		a.add_trimmed_box("ScoreDesk", Vector3(desk_x, 5.0, z), Vector3(26, 10, 9), a.mat("orange"), a.mat("dark_metal"), false)
		for x in [-7.0, 0.0, 7.0]:
			a.add_box("ScoreScreen", Vector3(desk_x + x, 6.0, z - signf(z) * 4.7), Vector3(5.0, 3.0, 0.35), a.mat("cyan"), false)


func _build_interactables(a, w: float) -> void:
	var crown_bumper: Node3D = a.add_rotating_bumper(Vector3(0, 6.0, 0), 31.0, 1.05, 30.0, Color(1.0, 0.3, 0.12))
	a.mark_duel_interactable(crown_bumper, "punishes players who linger in the exposed crown contest", false)
	for z in [-78.0, 78.0]:
		var launch_pad: Area3D = a.add_launch_pad(Vector3(0, 0.62, z), Vector3(0, 0.32, -signf(z)), 60.0, Color(0.12, 0.65, 1.0) if z < 0 else Color(1.0, 0.22, 0.25))
		a.mark_duel_interactable(launch_pad, "accelerates a committed center-lane opening", true)
	for z in [-46.0, 46.0]:
		for side in [-1.0, 1.0]:
			var conveyor: Area3D = a.add_conveyor(Vector3(side * 16.5, 0.65, z), Vector3(9, 1, 19), Vector3(0, 0, -signf(z)), 78.0, Color(1.0, 0.66, 0.08))
			a.mark_duel_interactable(conveyor, "short inward relay from a protected flank to midfield", true)
	for side in [-1.0, 1.0]:
		var platform_z: float = -45.0 * side
		var platform: AnimatableBody3D = a.add_moving_platform(Vector3(side * 24.0, 5.0, platform_z), Vector3(-side * 11.0, 7.0, side * 10.0), Vector3(13, 1.5, 9), 3.7, Color(0.12, 0.68, 0.95), 0.5 if side > 0 else 0.0)
		a.mark_duel_interactable(platform, "carries the outer scoring flank back toward the crown bridge", true)
		var fan_z: float = -26.0 * side
		a.models.fan_unit("CrossCourtFan", Vector3(side * (w - 7.0), 0, fan_z), -side * PI * 0.5, a.mat("dark_metal"), a.mat("orange"), a.mat("cyan"))
		var wind_direction: Vector3 = Vector3(-side, 0.12, side * 0.55).normalized()
		var wind_zone: Area3D = a.add_wind_zone(Vector3(side * (w - 20.0), 7.0, fan_z), Vector3(23, 13, 12), wind_direction, 98.0, Color(0.25, 0.78, 1.0))
		a.mark_duel_interactable(wind_zone, "cuts the outer lane diagonally into the crown contest", true)
