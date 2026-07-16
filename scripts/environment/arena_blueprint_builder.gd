extends RefCounted

const D := 5.775 # One blueprint grid cell is one Blob collision diameter.
const GEOMETRY := preload("res://scripts/environment/arena_blueprint_geometry.gd")
const WALL_LAUNCH_STRIP := preload("res://scripts/interactables/wall_launch_strip.gd")


func build(a) -> Dictionary:
	_build_floor_markings(a)
	_build_spawns_and_rush(a)
	_build_side_ramps(a)
	_build_redirects(a)
	_build_launch_strips_and_ledges(a)
	_build_wall_facades(a)
	return {
		"identity": "Literal compact industrial tournament Arena from the supplied coordinate blueprint.",
		"landmark": "Two central divider walls at grid (15.4,12) and (18.6,12).",
		"routes": ["blue rush ramp", "orange rush ramp", "four diagonal side ramps", "four angled redirect walls", "eight perimeter launch strips", "center rebound gap"],
		"interactables": ["eight velocity-reflecting wall launch strips"],
		"prop_families": ["rubber court markings", "reinforced perimeter bays", "rush ramps", "redirect walls", "transparent enclosure"],
		"flow_plan": ["Both spawn ramps open straight into the central lanes.", "Diagonal ramps feed the redirect walls instead of the corners.", "Wall strips turn incoming speed back toward combat."],
		"combat_spaces": ["The center divider creates two short rebound lanes.", "No side route ends in a dead end.", "Spawns retain a clear immediate line of sight."],
		"blueprint": {"unit_d": D, "footprint_d": Vector2(34, 24), "solid_wall_d": 3.0, "roof_d": 5.0, "source": "codex-clipboard-923ec33a-ce55-4a14-9216-de08c83f4728.png"},
	}


func _world(grid_x: float, grid_y: float, height := 0.0) -> Vector3:
	return Vector3((grid_x - 17.0) * D, height, (12.0 - grid_y) * D)


func _build_floor_markings(a) -> void:
	for grid_x in range(5, 31, 4):
		for grid_y in range(4, 22, 4):
			_add_plus(a, _world(float(grid_x), float(grid_y), 0.012 * D), 0.65 * D)
	_add_plus(a, Vector3(0, 0.014 * D, 0), 1.5 * D)


func _add_plus(a, position: Vector3, size: float) -> void:
	a.add_box("CourtPlusH", position, Vector3(size, 0.022 * D, size * 0.22), a.mat("arena_trim"), false)
	a.add_box("CourtPlusV", position, Vector3(size * 0.22, 0.024 * D, size), a.mat("arena_trim"), false)


func _build_spawns_and_rush(a) -> void:
	for spec in [[2.0, "arena_blue", "BLUE SPAWN"], [22.0, "arena_orange", "ORANGE SPAWN"]]:
		var grid_y := float(spec[0])
		var material: Material = a.mat(spec[1] as String)
		var platform_center := _world(17.0, grid_y, 0.95 * D)
		a.add_box("SpawnPlatform", platform_center, Vector3(6.0 * D, 0.5 * D, 3.0 * D), a.mat("arena_wall"), true, Vector3.ZERO, null, a.surface("bounce"))
		a.add_box("SpawnAccentInset", platform_center + Vector3.UP * 0.28 * D, Vector3(5.5 * D, 0.06 * D, 2.5 * D), material, false)
		for side in [-1.0, 1.0]:
			a.add_box("SpawnRearBarrier", platform_center + Vector3(side * 2.45 * D, 0.62 * D, signf(_world(17.0, grid_y).z) * 1.12 * D), Vector3(1.0 * D, 0.8 * D, 0.4 * D), a.mat("arena_trim"), true)
		a.add_label(platform_center + Vector3.UP * 0.36 * D, spec[2] as String, Color(0.72, 0.86, 1.0) if grid_y < 12.0 else Color(1.0, 0.74, 0.56), 28)
	# High end is local +Z: bottom ramp faces south toward center, top ramp uses a 180-degree flip.
	_add_rush_ramp(a, _world(17.0, 5.5), 0.0, a.mat("arena_blue"), "BlueRushRamp")
	_add_rush_ramp(a, _world(17.0, 18.5), PI, a.mat("arena_orange"), "OrangeRushRamp")


func _add_rush_ramp(a, center: Vector3, yaw: float, accent: Material, prefix: String) -> void:
	var ramp := GEOMETRY.add_curved_ramp(a, prefix, center, 8.0 * D, 5.0 * D, 1.2 * D, yaw, a.mat("arena_wall"), a.surface("bounce"), accent)
	ramp.add_to_group("duel_cover")
	for fraction in [0.3, 0.5, 0.7]:
		var offset := Basis(Vector3.UP, yaw) * Vector3(0, fraction * 1.2 * D + 0.05 * D, (fraction - 0.5) * 4.0 * D)
		a.add_route_chevron(prefix + "Chevron", center + offset, Basis(Vector3.UP, yaw) * Vector3.FORWARD, accent, 0.8)
	# Smooth visual launch lip at the floor end; the ramp's convex hull remains the only collision surface.
	var floor_end := center - Basis(Vector3.UP, yaw) * Vector3.FORWARD * 2.5 * D
	a.add_cylinder(prefix + "LaunchLip", floor_end + Vector3.UP * 0.08 * D, 1.65 * D, 0.16 * D, accent, false)
	a.add_flow_anchor(prefix, center, "attack_route", "center")


func _build_side_ramps(a) -> void:
	var specs := [
		[Vector2(7.5, 5.5), -PI * 0.25, "arena_blue"], [Vector2(26.5, 5.5), PI * 0.25, "arena_blue"],
		[Vector2(7.5, 18.5), -PI * 0.75, "arena_orange"], [Vector2(26.5, 18.5), PI * 0.75, "arena_orange"],
	]
	for spec in specs:
		var grid := spec[0] as Vector2
		var yaw := float(spec[1])
		var accent: Material = a.mat(spec[2] as String)
		var ramp: Node3D = GEOMETRY.add_curved_ramp(a, "DiagonalSideRamp", _world(grid.x, grid.y), 5.0 * D, 3.5 * D, 0.9 * D, yaw, a.mat("arena_wall"), a.surface("bounce"), accent)
		ramp.add_to_group("duel_cover")
		ramp.add_to_group("arena_diagonal_ramp")
		a.add_flow_anchor("DiagonalRamp", _world(grid.x, grid.y), "flank_route", "left" if grid.x < 17.0 else "right")


func _build_redirects(a) -> void:
	var specs := [[Vector2(11.5, 8.5), -PI * 0.25], [Vector2(22.5, 8.5), PI * 0.25], [Vector2(11.5, 15.5), PI * 0.25], [Vector2(22.5, 15.5), -PI * 0.25]]
	for spec in specs:
		var grid := spec[0] as Vector2
		var yaw := float(spec[1])
		var accent: Material = a.mat("arena_blue") if grid.y < 12.0 else a.mat("arena_orange")
		var wall: Node3D = GEOMETRY.add_beveled_redirect(a, "AngledRedirectWall", _world(grid.x, grid.y, D), 6.0 * D, 2.0 * D, 0.6 * D, yaw, a.mat("arena_wall"), accent, a.surface("bounce"))
		wall.add_to_group("duel_cover")
		wall.add_to_group("arena_redirect_wall")
		a.add_box("RedirectTopRail", _world(grid.x, grid.y, 2.05 * D), Vector3(0.72 * D, 0.10 * D, 6.0 * D), accent, false, Vector3(0, yaw, 0))
		a.add_flow_anchor("RedirectWall", _world(grid.x, grid.y), "rebound_route", "left" if grid.x < 17.0 else "right")
	var landmark: Node3D = a.add_landmark_root("CentralDividerLandmark")
	for grid_x in [15.4, 18.6]:
		var divider: MeshInstance3D = a.add_box("CenterDivider", _world(grid_x, 12.0, 0.75 * D), Vector3(0.7 * D, 1.5 * D, 2.0 * D), a.mat("arena_trim"), true, Vector3.ZERO, landmark, a.surface("bounce"))
		divider.add_to_group("arena_center_divider")
		divider.add_to_group("duel_cover")
		a.add_box("CenterDividerTrim", _world(grid_x, 12.0, 1.54 * D), Vector3(0.5 * D, 0.06 * D, 1.75 * D), a.mat("arena_marking"), false, Vector3.ZERO, landmark)


func _build_launch_strips_and_ledges(a) -> void:
	for grid_y in [5.5, 10.0, 14.0, 18.5]:
		for grid_x in [3.2, 30.8]:
			var inward := Vector3.RIGHT if grid_x < 17.0 else Vector3.LEFT
			var color := Color("278CFF") if grid_y < 12.0 else Color("F36B32")
			var strip := WALL_LAUNCH_STRIP.new() as Area3D
			strip.name = "WallLaunchStrip"
			strip.position = _world(grid_x, grid_y, 1.5 * D) + inward * 0.12 * D
			strip.call("configure", Vector3(1.5 * D, 2.0 * D, 0.15 * D), inward, color)
			strip.add_to_group("arena_launch_strip")
			a._interactables.add_child(strip)
			a.mark_duel_interactable(strip, "Reflects fast incoming momentum back into the arena", true)
	for grid_y in [7.75, 12.0, 16.25]:
		for grid_x in [2.9, 31.1]:
			a.add_box("PassiveWallLedge", _world(grid_x, grid_y, 1.4 * D), Vector3(0.35 * D, 0.18 * D, 1.2 * D), a.mat("arena_trim"), true, Vector3.ZERO, null, a.surface("bounce"))
	for grid in [Vector2(4.1, 2.7), Vector2(29.9, 2.7), Vector2(4.1, 21.3), Vector2(29.9, 21.3)]:
		a.add_box("CornerPassiveLedge", _world(grid.x, grid.y, 1.4 * D), Vector3(1.2 * D, 0.18 * D, 0.35 * D), a.mat("arena_trim"), true, Vector3.ZERO, null, a.surface("bounce"))


func _build_wall_facades(a) -> void:
	for grid_y in [4.0, 8.0, 12.0, 16.0, 20.0]:
		for grid_x in [1.45, 32.55]:
			var x_inset := 0.2 * D if grid_x < 17.0 else -0.2 * D
			a.add_box("WallRecessPanel", _world(grid_x, grid_y, 1.65 * D) + Vector3(x_inset, 0, 0), Vector3(0.12 * D, 1.65 * D, 2.6 * D), a.mat("arena_wall"), false)
			_add_plus(a, _world(grid_x + (0.2 if grid_x < 17.0 else -0.2), grid_y, 1.68 * D), 0.55 * D)
