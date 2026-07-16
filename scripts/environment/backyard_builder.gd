extends RefCounted


func build(a) -> Dictionary:
	var w: float = a.arena_half_width
	var l: float = a.arena_half_length
	_build_lawn(a, w, l)
	_build_treehouse_landmark(a)
	_build_garden_routes(a, w, l)
	_build_props(a, w, l)
	_build_duel_cover(a)
	_build_duel_flow(a)
	_build_interactables(a, w)
	return {
		"identity": "Sunny oversized garden playground with hand-built timber routes",
		"landmark": "Whirligig Treehouse",
		"routes": ["exposed stepping-stone sprint", "west hedge pockets", "east potting path", "pergola attack overlooks", "treehouse patio contest", "mower-strip reconnection"],
		"interactables": ["sprinkler rotating bumper", "trampoline launch pads", "wheelbarrow lifts", "pinwheel gust lanes", "mower-strip conveyor"],
		"prop_families": ["garden sheds", "hedges and trees", "timber pergolas", "planters and tools", "stone paths", "watering machinery"],
		"flow_plan": [
			"Center: stepping stones and trampolines create the quickest exposed patio entry",
			"Left: separated hedge and planter pockets protect movement but force open crossings",
			"Right: potting benches and pergola overlooks mirror the flank value before reconnecting center",
		],
		"combat_spaces": [
			"Mown center straight is a fast attack lane watched from both garden flanks",
			"Broken hedge pockets support short resets without creating a continuous safe tunnel",
			"Treehouse patio mixes low planter cover with sprinkler and cross-lane pressure",
		],
	}


func _build_lawn(a, w: float, l: float) -> void:
	a.add_box("SoftLawn", Vector3(0, 0.1, 0), Vector3(w * 2.0 - 7.0, 0.2, l * 2.0 - 9.0), a.mat("grass"), false)
	for x in range(int(-w + 8), int(w - 7), 10):
		var stripe: Material = a.mat("grass_light") if posmod(x, 20) == 0 else a.mat("grass_dark")
		a.add_box("MownStripe", Vector3(float(x), 0.19, 0), Vector3(9.4, 0.04, l * 2.0 - 14.0), stripe, false)
	for side in [-1.0, 1.0]:
		a.add_box("GardenFlankTrail", Vector3(side * 27.0, 0.24, 0), Vector3(12.0, 0.06, l * 1.62), a.mat("soil"), false)
	for z in range(int(-l + 15), int(l - 14), 14):
		a.add_box("StonePaver", Vector3(0, 0.28, float(z)), Vector3(12.0, 0.35, 8.5), a.mat("stone"), true, Vector3(0, sin(float(z)) * 0.025, 0), null, a.surface("grip"))
	for z in [-88.0, -58.0, 58.0, 88.0]:
		a.add_box("PathFork", Vector3(0, 0.26, z), Vector3(w * 1.2, 0.3, 7.0), a.mat("stone"), true, Vector3.ZERO, null, a.surface("grip"))


func _build_treehouse_landmark(a) -> void:
	var landmark: Node3D = a.add_landmark_root("WhirligigTreehouse")
	a.add_cylinder("TreehouseTrunk", Vector3(0, 9.0, 0), 4.2, 18.0, a.mat("wood_dark"), true, Vector3.ZERO, landmark)
	for angle in [-0.62, 0.62]:
		a.add_pipe("TreeBranch", Vector3(sin(angle) * 4.5, 16.0, cos(angle) * 3.0), 1.5, 10.0, a.mat("wood_dark"), Vector3(0, 0, angle), landmark)
	a.add_trimmed_box("TreehouseCabin", Vector3(0, 19.0, 0), Vector3(22, 12, 18), a.mat("wood_red"), a.mat("wood_light"), true, landmark)
	for x in [-6.0, 6.0]:
		a.add_box("TreehouseWindow", Vector3(x, 20.5, -9.2), Vector3(5.0, 4.2, 0.4), a.mat("glass"), false, Vector3.ZERO, landmark)
	a.add_box("TreehouseRoofA", Vector3(-5.4, 27.0, 0), Vector3(13, 1.4, 21), a.mat("roof_red"), true, Vector3(0, 0, -0.5), landmark)
	a.add_box("TreehouseRoofB", Vector3(5.4, 27.0, 0), Vector3(13, 1.4, 21), a.mat("roof_red"), true, Vector3(0, 0, 0.5), landmark)
	for z in [-13.0, 13.0]:
		a.add_box("TreehouseDeck", Vector3(0, 14.0, z), Vector3(28, 1.6, 8), a.mat("wood_light"), true, Vector3.ZERO, landmark)
	for index in range(6):
		var angle: float = TAU * float(index) / 6.0
		a.add_box("WhirligigBlade", Vector3(0, 24.0, 9.8), Vector3(1.5, 11.0, 0.5), a.mat("yellow") if index % 2 == 0 else a.mat("blue"), false, Vector3(0, 0, angle), landmark)
	a.add_cylinder("WhirligigHub", Vector3(0, 24.0, 10.0), 1.8, 1.3, a.mat("red"), false, Vector3(PI * 0.5, 0, 0), landmark)
	a.add_ramp("TreehouseNorthRamp", Vector3(0, 6.5, -23.0), Vector3(15, 2.0, 30), a.mat("wood_light"), Vector3(-0.42, 0, 0))
	a.add_ramp("TreehouseSouthRamp", Vector3(0, 6.5, 23.0), Vector3(15, 2.0, 30), a.mat("wood_light"), Vector3(0.42, 0, 0))


func _build_garden_routes(a, w: float, l: float) -> void:
	for side in [-1.0, 1.0]:
		var x: float = side * (w - 6.5)
		for z in [-68.0, -30.0, 30.0, 68.0]:
			a.add_trimmed_box("HedgeIsland", Vector3(x, 4.5, z), Vector3(9, 9, 14), a.mat("hedge"), a.mat("leaves_light"), true)
		for z in [-50.0, 50.0]:
			a.add_box("PergolaOverlook", Vector3(side * 28.0, 7.0, z), Vector3(14, 1.4, 12), a.mat("wood_light"), true)
			a.add_ramp("PergolaRamp", Vector3(side * 20.0, 3.5, z), Vector3(16, 1.8, 10), a.mat("wood_light"), Vector3(0, 0, -side * 0.4))
	for z in [-45.0, 45.0]:
		a.add_arch("GardenAttackGate", Vector3(0, 0, z), 24.0, 13.0, a.mat("wood_light"), a.mat("white"))


func _build_props(a, w: float, l: float) -> void:
	a.models.garden_shed("RedPottingShed", Vector3(-32, 0, -78), 0.0, a.mat("wood_red"), a.mat("white"), a.mat("roof_dark"))
	a.models.garden_shed("BlueToolShed", Vector3(32, 0, 78), PI, a.mat("blue"), a.mat("white"), a.mat("roof_dark"))
	for position in [Vector3(-w + 7, 0, -92), Vector3(w - 7, 0, -92), Vector3(-w + 7, 0, 92), Vector3(w - 7, 0, 92)]:
		a.models.tree("ShadeTree", position, 0.78, a.mat("wood_dark"), a.mat("leaves"))
	for z in [-42.0, 42.0]:
		for side in [-1.0, 1.0]:
			var x: float = side * 35.0
			a.add_cylinder("TerracottaPot", Vector3(x, 1.7, z), 3.2, 3.4, a.mat("terracotta"), true)
			a.add_sphere("FlowerBush", Vector3(x, 5.2, z), 3.4, a.mat("flowers") if side > 0 else a.mat("leaves_light"), false)
	for z in range(int(-l + 12), int(l - 11), 20):
		a.models.lamp("GardenLamp", Vector3(-w + 3.0, 0, float(z)), 10.0, a.mat("wood_dark"), a.mat("warm_light"))
		a.models.lamp("GardenLamp", Vector3(w - 3.0, 0, float(z)), 10.0, a.mat("wood_dark"), a.mat("warm_light"))


func _build_duel_cover(a) -> void:
	a.add_duel_cover("NorthWestHedge", Vector3(-27, 3.5, -72), Vector3(8, 7, 9), a.mat("hedge"), a.mat("leaves_light"), "left", "flank pocket", Vector3(0, 0.12, 0))
	a.add_duel_cover("NorthEastBench", Vector3(25, 2.5, -52), Vector3(11, 5, 6), a.mat("wood_dark"), a.mat("white"), "right", "cross-lane peek", Vector3(0, -0.18, 0))
	a.add_duel_cover("NorthCenterPlanter", Vector3(-9, 2.25, -31), Vector3(12, 4.5, 5.5), a.mat("wood_light"), a.mat("flowers"), "center", "attack staging", Vector3(0, 0.22, 0))
	a.add_duel_cover("NorthRightTrellis", Vector3(28, 2.75, -19), Vector3(8, 5.5, 6), a.mat("wood_light"), a.mat("white"), "right", "patio breach", Vector3(0, -0.15, 0))
	a.add_duel_cover("SouthLeftTrellis", Vector3(-28, 2.75, 19), Vector3(8, 5.5, 6), a.mat("wood_light"), a.mat("white"), "left", "patio breach", Vector3(0, -0.15, 0))
	a.add_duel_cover("SouthCenterPlanter", Vector3(9, 2.25, 31), Vector3(12, 4.5, 5.5), a.mat("wood_light"), a.mat("flowers"), "center", "attack staging", Vector3(0, 0.22, 0))
	a.add_duel_cover("SouthWestBench", Vector3(-25, 2.5, 52), Vector3(11, 5, 6), a.mat("wood_dark"), a.mat("white"), "left", "cross-lane peek", Vector3(0, -0.18, 0))
	a.add_duel_cover("SouthEastHedge", Vector3(27, 3.5, 72), Vector3(8, 7, 9), a.mat("hedge"), a.mat("leaves_light"), "right", "flank pocket", Vector3(0, 0.12, 0))
	a.add_duel_cover("WestPatioCrate", Vector3(-23, 2.25, -8), Vector3(9, 4.5, 5), a.mat("wood_red"), a.mat("white"), "left", "center duel", Vector3(0, 0.28, 0))
	a.add_duel_cover("EastPatioCrate", Vector3(23, 2.25, 8), Vector3(9, 4.5, 5), a.mat("blue"), a.mat("white"), "right", "center duel", Vector3(0, 0.28, 0))


func _build_duel_flow(a) -> void:
	for approach_side in [-1.0, 1.0]:
		var approach_z: float = approach_side * 92.0
		var flank_entry_z: float = approach_side * 78.0
		var breach_z: float = approach_side * 34.0
		var inward: Vector3 = Vector3(0, 0, -approach_side)
		a.add_flow_anchor("StoneSprint", Vector3(0, 0.7, approach_z), "attack_route", "center")
		a.add_flow_anchor("LeftGardenEntry", Vector3(-16, 0.7, flank_entry_z), "flank_route", "left")
		a.add_flow_anchor("RightGardenEntry", Vector3(16, 0.7, flank_entry_z), "flank_route", "right")
		a.add_flow_anchor("LeftHedgePocket", Vector3(-27, 0.7, breach_z), "flank_route", "left")
		a.add_flow_anchor("RightPottingPocket", Vector3(27, 0.7, breach_z), "flank_route", "right")
		var left_attack_x: float = -19.0 if approach_side < 0.0 else -13.0
		var right_attack_x: float = 13.0 if approach_side < 0.0 else 19.0
		a.add_flow_anchor("LeftPatioAttack", Vector3(left_attack_x, 0.7, breach_z), "attack_route", "left")
		a.add_flow_anchor("RightPatioAttack", Vector3(right_attack_x, 0.7, breach_z), "attack_route", "right")
		a.add_route_chevron("StoneSprintRoute", Vector3(0, 0.48, approach_side * 100.0), inward, a.mat("yellow"), 1.1)
		a.add_route_chevron("LeftGardenRoute", Vector3(-16, 0.42, flank_entry_z), Vector3(0.22, 0, -approach_side), a.mat("white"), 0.85)
		a.add_route_chevron("RightGardenRoute", Vector3(16, 0.42, flank_entry_z), Vector3(-0.22, 0, -approach_side), a.mat("white"), 0.85)


func _build_interactables(a, w: float) -> void:
	# The center sprinkler sweeps the patio and creates a readable collision rhythm.
	var bumper: Node3D = a.add_rotating_bumper(Vector3(0, 5.0, 0), 24.0, 0.82, 24.0, Color(0.18, 0.68, 0.96))
	a.mark_duel_interactable(bumper, "Sprinkler sweeper prevents passive control of the treehouse patio", false)
	for z in [-88.0, 88.0]:
		var pad: Area3D = a.add_launch_pad(Vector3(0, 0.6, z), Vector3(0, 0.62, -signf(z) * 0.68), 50.0, Color(0.98, 0.56, 0.2))
		a.mark_duel_interactable(pad, "Trampoline commits the exposed stone sprint toward center", true)
	for side in [-1.0, 1.0]:
		a.models.fan_unit("GardenPinwheel", Vector3(side * (w - 7.0), 0, -32.0 * side), -side * PI * 0.5, a.mat("wood_light"), a.mat("yellow"), a.mat("cyan"))
		var wind: Area3D = a.add_wind_zone(Vector3(side * 27.0, 6.0, -32.0 * side), Vector3(18, 11, 12), Vector3(-side, 0.16, side * 0.28), 88.0, Color(0.5, 0.88, 1.0))
		a.mark_duel_interactable(wind, "Pinwheel gust ends the hedge pocket with an inward patio attack", true)
		var lift: AnimatableBody3D = a.add_moving_platform(Vector3(side * 27.0, 4.5, 50.0 * side), Vector3(-side * 16.0, 8.0, -side * 18.0), Vector3(13, 1.5, 9), 4.2, Color(0.7, 0.4, 0.12), 0.5 if side > 0 else 0.0)
		a.mark_duel_interactable(lift, "Wheelbarrow lift carries the pergola attacker back toward center", true)
		var mower_direction: Vector3 = Vector3(-side, 0, side * 0.48).normalized()
		var mower: Area3D = a.add_conveyor(Vector3(side * 25.0, 0.6, -12.0 * side), Vector3(11, 1, 25), mower_direction, 62.0, Color(0.92, 0.68, 0.14))
		a.mark_duel_interactable(mower, "Mower strip breaks the side route and reconnects it to the patio", true)
		a.add_route_chevron("MowerFeed", Vector3(side * 25.0, 1.15, -12.0 * side), mower_direction, a.mat("yellow"), 0.72)
