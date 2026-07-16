extends RefCounted


func build(a) -> Dictionary:
	var w: float = a.arena_half_width
	var l: float = a.arena_half_length
	_build_sanctuary_floor(a, w, l)
	_build_orrery(a)
	_build_colonnades(a, w, l)
	_build_duel_flow(a)
	_build_sky_details(a, w, l)
	_build_interactables(a, w)
	return {
		"identity": "Open-air wind sanctuary of pale stone, brass, and suspended sky machinery",
		"landmark": "Aeolian Orrery",
		"routes": ["fast gold meridian", "broken sun colonnade", "broken moon colonnade", "cloudstep reconnection", "inward wind vaults", "pilgrim relay segments", "orrery cover pockets"],
		"interactables": ["orrery rotating arm", "sun seal launch pads", "aeolian wind vaults", "cloudstep moving platforms", "pilgrim conveyors"],
		"prop_families": ["fluted columns", "brass orrery rings", "wind harps", "cloud terraces", "sun gates", "ceremonial braziers"],
		"flow_plan": ["Center: the gold meridian is the fastest and most exposed route", "Left: separated sun terraces provide measured cover windows", "Right: moon terraces trade safety for wind and cloudstep reconnections"],
		"combat_spaces": ["open spawn courts prevent defensive stalls", "broken colonnade islands create readable flank skirmishes", "the orrery dais anchors the central duel", "gold-trimmed inner shrines form brief reconnection cover"],
	}


func _build_sanctuary_floor(a, w: float, l: float) -> void:
	a.add_box("TempleCourt", Vector3(0, 0.12, 0), Vector3(w * 2.0 - 7.0, 0.24, l * 2.0 - 9.0), a.mat("marble"), true, Vector3.ZERO, null, a.surface("normal"))
	a.add_box("SacredRun", Vector3(0, 0.3, 0), Vector3(21, 0.1, l * 2.0 - 13.0), a.mat("white"), false)
	a.add_box("GoldMeridian", Vector3(0, 0.4, 0), Vector3(1.0, 0.1, l * 2.0 - 16.0), a.mat("gold"), false)
	for z in range(int(-l + 14), int(l - 13), 14):
		a.add_box("SunInlay", Vector3(0, 0.42, float(z)), Vector3(18, 0.1, 0.55), a.mat("gold"), false)
	for side in [-1.0, 1.0]:
		a.add_box("CloudMosaic", Vector3(side * 24.0, 0.31, 0), Vector3(14, 0.08, l * 1.7), a.mat("sky_blue"), false)
		for z in [-42.0, 42.0]:
			a.add_box("SkyGlass", Vector3(side * 24.0, 0.35, z), Vector3(13.0, 0.3, 22.0), a.mat("glass"), true, Vector3.ZERO, null, a.surface("ice"))


func _build_orrery(a) -> void:
	var landmark: Node3D = a.add_landmark_root("AeolianOrrery")
	a.add_cylinder("OrreryDais", Vector3(0, 0.24, 0), 11.0, 0.28, a.mat("stone"), true, Vector3.ZERO, landmark)
	a.add_cylinder("OrreryInlay", Vector3(0, 0.4, 0), 10.2, 0.08, a.mat("gold"), false, Vector3.ZERO, landmark)
	for index in range(8):
		var angle: float = TAU * float(index) / 8.0
		var p: Vector3 = Vector3(cos(angle) * 13.2, 7.5, sin(angle) * 13.2)
		a.add_cylinder("OrreryPost", p, 0.65, 5.0, a.mat("gold"), false, Vector3.ZERO, landmark)
	a.add_cylinder("OrreryAxis", Vector3(0, 16.0, 0), 2.6, 22.0, a.mat("gold"), true, Vector3.ZERO, landmark)
	a.add_torus("OrreryRingHorizontal", Vector3(0, 16, 0), 8.5, 9.5, a.mat("cyan"), false, Vector3.ZERO, landmark)
	a.add_torus("OrreryRingVertical", Vector3(0, 16, 0), 11.0, 12.0, a.mat("gold"), false, Vector3(PI * 0.5, 0, 0), landmark)
	a.add_torus("OrreryRingTilted", Vector3(0, 16, 0), 13.5, 14.3, a.mat("sky_blue"), false, Vector3(0.65, 0.35, 0), landmark)
	a.add_sphere("OrrerySun", Vector3(0, 16, 0), 4.1, a.mat("warm_light"), false, landmark)
	for index in range(4):
		var angle: float = TAU * float(index) / 4.0
		a.add_sphere("OrreryMoon", Vector3(cos(angle) * 11.5, 16 + sin(angle) * 5.0, sin(angle) * 11.5), 1.5, a.mat("cyan"), false, landmark)


func _build_colonnades(a, w: float, l: float) -> void:
	for side in [-1.0, 1.0]:
		for z in [-80.0, -58.0, -34.0, 34.0, 58.0, 80.0]:
			a.models.temple_column("TempleColumn", Vector3(side * (w - 7.0), 0, z), 16.0, a.mat("marble"), a.mat("gold"))
		for segment_z in [-64.0, 0.0, 64.0]:
			var segment_length: float = 32.0 if segment_z != 0.0 else 26.0
			a.add_box("ColonnadeIsland", Vector3(side * (w - 10.0), 9.0, segment_z), Vector3(11, 1.8, segment_length), a.mat("stone"), true)
			a.add_box("ColonnadeIslandRail", Vector3(side * (w - 15.0), 11.8, segment_z), Vector3(1.0, 5.5, segment_length), a.mat("gold"), false)
		for z in [-64.0, 0.0, 64.0]:
			a.add_ramp("ColonnadeRamp", Vector3(side * (w - 19.0), 4.3, z), Vector3(18, 2.0, 12), a.mat("white"), Vector3(0, 0, -side * 0.48))
	for z in [-52.0, 52.0]:
		a.models.truss_bridge("SunBridge", Vector3(0, 15.0, z), Vector3(w * 1.25, 1.6, 8), a.mat("marble"), a.mat("gold"))
		a.add_arch("SunGate", Vector3(0, 0, z - signf(z) * 13.0), 25.0, 17.0, a.mat("marble"), a.mat("gold"))


func _build_duel_flow(a) -> void:
	# Shrine blocks are offset so neither colonnade becomes a protected highway.
	a.add_duel_cover("NorthMeridianShrine", Vector3(-9, 2.2, -70), Vector3(10, 4.4, 5), a.mat("stone"), a.mat("gold"), "center", "attack_break")
	a.add_duel_cover("NorthSunShrine", Vector3(-21, 2.6, -56), Vector3(7, 5.2, 6), a.mat("marble"), a.mat("gold"), "left", "flank_peek", Vector3(0, 0.16, 0))
	a.add_duel_cover("NorthMoonShrine", Vector3(21, 2.6, -43), Vector3(7, 5.2, 6), a.mat("stone"), a.mat("sky_blue"), "right", "flank_peek", Vector3(0, -0.16, 0))
	a.add_duel_cover("NorthSunLink", Vector3(-22, 2.2, -15), Vector3(8, 4.4, 5), a.mat("marble"), a.mat("gold"), "left", "center_link")
	a.add_duel_cover("SouthMeridianShrine", Vector3(9, 2.2, 70), Vector3(10, 4.4, 5), a.mat("stone"), a.mat("gold"), "center", "attack_break")
	a.add_duel_cover("SouthMoonShrine", Vector3(21, 2.6, 56), Vector3(7, 5.2, 6), a.mat("marble"), a.mat("gold"), "right", "flank_peek", Vector3(0, 0.16, 0))
	a.add_duel_cover("SouthSunShrine", Vector3(-21, 2.6, 43), Vector3(7, 5.2, 6), a.mat("stone"), a.mat("sky_blue"), "left", "flank_peek", Vector3(0, -0.16, 0))
	a.add_duel_cover("SouthMoonLink", Vector3(22, 2.2, 15), Vector3(8, 4.4, 5), a.mat("marble"), a.mat("gold"), "right", "center_link")
	a.add_duel_cover("WestOrreryPocket", Vector3(-24, 2.4, -8), Vector3(7, 4.8, 5), a.mat("stone"), a.mat("sky_blue"), "left", "center_pocket", Vector3(0, -0.18, 0))
	a.add_duel_cover("EastOrreryPocket", Vector3(24, 2.4, 8), Vector3(7, 4.8, 5), a.mat("stone"), a.mat("gold"), "right", "center_pocket", Vector3(0, -0.18, 0))

	for z in [-74.0, -38.0, 38.0, 74.0]:
		var center_direction: Vector3 = Vector3(0, 0, -signf(z))
		a.add_flow_anchor("GoldMeridian", Vector3(0, 1, z), "attack_route", "center")
		a.add_route_chevron("GoldMeridian", Vector3(0, 0.4, z), center_direction, a.mat("gold"), 0.88)
	for z in [-78.0, -28.0, 28.0, 78.0]:
		var flank_x: float = 16.0 if absf(z) > 50.0 else 18.0
		for side in [-1.0, 1.0]:
			var lane: String = "left" if side < 0 else "right"
			var flank_direction := Vector3(-side * 0.5, 0, -signf(z)).normalized()
			a.add_flow_anchor("TempleFlank", Vector3(side * flank_x, 1, z), "flank_route", lane)
			a.add_route_chevron("TempleFlank", Vector3(side * flank_x, 0.42, z), flank_direction, a.mat("sky_blue"), 0.78)


func _build_sky_details(a, w: float, l: float) -> void:
	for z in [-80.0, -60.0, 60.0, 80.0]:
		for side in [-1.0, 1.0]:
			var x: float = side * 21.0
			a.add_trimmed_box("CloudTerrace", Vector3(x, 3.0, z), Vector3(18, 6, 13), a.mat("stone"), a.mat("gold"), false)
			a.add_cylinder("Brazier", Vector3(x, 8.2, z), 2.0, 4.0, a.mat("gold"), false)
			a.add_sphere("BrazierFlame", Vector3(x, 11.2, z), 1.6, a.mat("warm_light"), false)
	for z in range(int(-l + 12), int(l - 11), 20):
		a.models.lamp("TempleLamp", Vector3(-w + 3.0, 0, float(z)), 13.0, a.mat("gold"), a.mat("warm_light"))
		a.models.lamp("TempleLamp", Vector3(w - 3.0, 0, float(z)), 13.0, a.mat("gold"), a.mat("warm_light"))
	for position in [Vector3(-w - 12, 25, -82), Vector3(w + 13, 32, -38), Vector3(-w - 14, 36, 42), Vector3(w + 12, 28, 86)]:
		for offset in [Vector3.ZERO, Vector3(5, 1, 0), Vector3(-4, -1, 2)]:
			a.add_sphere("CloudBank", position + offset, 7.0, a.mat("cloud"), false)


func _build_interactables(a, w: float) -> void:
	var orrery_arm: Node3D = a.add_rotating_bumper(Vector3(0, 7.5, 0), 27.0, 0.7, 26.0, Color(0.94, 0.66, 0.2))
	a.mark_duel_interactable(orrery_arm, "sweeps the exposed orrery contest at a readable cadence", false)
	for z in [-76.0, 76.0]:
		var sun_seal: Area3D = a.add_launch_pad(Vector3(0, 0.6, z), Vector3(0, 0.48, -signf(z)), 58.0, Color(0.35, 0.78, 1.0))
		a.mark_duel_interactable(sun_seal, "launches a direct commitment down the gold meridian", true)
	for z in [-48.0, 48.0]:
		for side in [-1.0, 1.0]:
			var pilgrim_relay: Area3D = a.add_conveyor(Vector3(side * 17.0, 0.65, z), Vector3(9, 1, 18), Vector3(0, 0, -signf(z)), 66.0, Color(0.3, 0.74, 1.0))
			a.mark_duel_interactable(pilgrim_relay, "short inward pilgrimage from colonnade cover to the orrery", true)
	for side in [-1.0, 1.0]:
		var wind_z: float = -28.0 * side
		a.models.fan_unit("WindHarp", Vector3(side * (w - 7.0), 0, wind_z), -side * PI * 0.5, a.mat("gold"), a.mat("white"), a.mat("cyan"))
		var wind_direction: Vector3 = Vector3(-side, 0.24, side * 0.62).normalized()
		var wind_vault: Area3D = a.add_wind_zone(Vector3(side * (w - 19.0), 8.0, wind_z), Vector3(22, 15, 14), wind_direction, 112.0, Color(0.54, 0.88, 1.0))
		a.mark_duel_interactable(wind_vault, "bends the outer colonnade route diagonally into center", true)
		var platform_z: float = -43.0 * side
		var cloudstep: AnimatableBody3D = a.add_moving_platform(Vector3(side * 23.0, 6.0, platform_z), Vector3(-side * 10.0, 7.0, side * 12.0), Vector3(13, 1.4, 10), 4.0, Color(0.95, 0.76, 0.26), 0.5 if side > 0 else 0.0)
		a.mark_duel_interactable(cloudstep, "bridges a colonnade gap and returns toward the orrery", true)
