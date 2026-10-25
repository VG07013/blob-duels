extends RefCounted

const GEOMETRY := preload("res://scripts/environment/aether_citadel_geometry.gd")
const VORTEX := preload("res://scripts/interactables/aether_vortex.gd")
const BOOST := preload("res://scripts/interactables/aether_boost_pad.gd")
const REBOUND := preload("res://scripts/interactables/aether_rebound.gd")

const D := 5.776
const GU := D * 0.5


func build(a) -> Dictionary:
	_build_floor(a)
	_build_spawn_sanctums(a)
	_build_crown(a)
	_build_wing_terraces(a)
	_build_ascension_ramps(a)
	_build_sun_seals(a)
	_build_wind_arches(a)
	_build_rebound_pylons(a)
	_build_low_wing_walls(a)
	_build_wingstream_rails(a)
	_build_wall_rebound_fins(a)
	_build_skyrail_ledges(a)
	_build_seraph_pillars(a)
	_build_route_language(a)
	return {
		"identity": "Aether Citadel, a radiant floating mastery arena of navy stone, ivory wings, gold seams, and cyan stormglass",
		"landmark": "Aether Crown vortex",
		"routes": ["Dawn descent", "Dusk descent", "west crescent chain", "east crescent chain", "upper wind diagonal", "lower wind diagonal", "crown aerial contest", "wall-fin recovery loop", "meridian pillar split"],
		"interactables": ["Aether Crown", "Sun-Seal boosts", "Wind Arches", "rebound pylons", "Wingstream rails", "wall rebound fins"],
		"prop_families": ["ivory wing masonry", "gold celestial mechanisms", "cyan stormglass", "violet and amber route inlays", "ivory seraph pillars"],
		"flow_plan": ["Every route retains a continuous floor below it", "Wall fins return momentum inward", "Four ascension ramps connect the two crescent terraces", "No moving, random, or timed hazards", "A seraph pillar splits each meridian descent into two sides before the crown"],
		"combat_spaces": ["open spawn sanctums", "readable crown ring", "paired wing terraces", "wide diagonal wind lanes", "the seraph pillars hide each sanctum from the other and are the meridian's ricochet posts"],
		"blueprint": {
			"footprint_gu": Vector2(48, 72), "interior_gu": Vector2(44, 68), "gu_scale_d": 0.5,
			"floor_thickness_gu": 0.5, "solid_wall_height_gu": 4.0, "roof_height_gu": 14.5,
			"approved_image": "res://artifacts/blueprints/aether_citadel_blueprint.png",
		},
	}


func _world(grid: Vector2, height_gu := 0.0) -> Vector3:
	return Vector3((grid.x - 24.0) * GU, height_gu * GU, (36.0 - grid.y) * GU)


func _mark(node: Node, kind: String, grid: Vector2, size := Vector3.ZERO, extra: Dictionary = {}) -> Node:
	node.set_meta("aether_kind", kind)
	node.set_meta("gu_position", grid)
	node.set_meta("gu_size", size)
	for key in extra:
		node.set_meta(key, extra[key])
	return node


func _build_floor(a) -> void:
	var floor_polygon := GEOMETRY.clipped_rectangle(48.0 * GU, 72.0 * GU, 3.0 * GU)
	var floor := GEOMETRY.add_extruded_polygon(a, "AetherContinuousFloor", Vector3(0, -0.5 * GU, 0), floor_polygon, 0.5 * GU, a.mat("aether_ivory"), a.surface("normal"))
	_mark(floor, "continuous_floor", Vector2(24, 36), Vector3(48, 0.5, 72), {"closed_mesh": true, "continuous_collision": true})
	# Long architectural inlays reproduce the blueprint's winged central axis without
	# subdividing the authoritative floor collision.
	a.add_box("IvoryMeridian", Vector3(0, 0.04 * GU, 0), Vector3(8.0 * GU, 0.08 * GU, 48.0 * GU), a.mat("aether_white"), false)
	a.add_box("GoldMeridianSeam", Vector3(0, 0.10 * GU, 0), Vector3(0.22 * GU, 0.05 * GU, 49.0 * GU), a.mat("aether_gold"), false)
	for z_gu in [-26.0, -18.0, -10.0, 10.0, 18.0, 26.0]:
		for side in [-1.0, 1.0]:
			a.add_box("WingFloorFeather", Vector3(side * 9.5 * GU, 0.07 * GU, z_gu * GU), Vector3(9.5 * GU, 0.07 * GU, 0.45 * GU), a.mat("aether_blue"), false, Vector3(0, side * signf(z_gu) * 0.24, 0))
	for z_gu in [-14.0, -7.0, 7.0, 14.0]:
		a.add_box("VioletFlightLane", Vector3(0, 0.13 * GU, z_gu * GU), Vector3(6.8 * GU, 0.06 * GU, 0.24 * GU), a.mat("aether_violet"), false)
	for pylon_grid in [Vector2(17, 25), Vector2(31, 25), Vector2(15, 33), Vector2(33, 33), Vector2(15, 39), Vector2(33, 39), Vector2(17, 47), Vector2(31, 47)]:
		_add_floor_inlay(a, Vector2(24, 36), pylon_grid, a.mat("aether_gold"))


func _build_spawn_sanctums(a) -> void:
	for spec in [[Vector2(24, 6), false], [Vector2(24, 66), true]]:
		var grid := spec[0] as Vector2
		var platform := GEOMETRY.add_d_platform(a, "DawnSpawnSanctum" if grid.y < 36 else "DuskSpawnSanctum", _world(grid), 12.0 * GU, 8.0 * GU, 4.0 * GU, bool(spec[1]), a.mat("aether_ivory"), a.surface("normal"))
		_mark(platform, "spawn_sanctum", grid, Vector3(12, 4, 8), {"closed_mesh": true})
		a.mark_elevated_route(platform, _world(grid, 4.0))
		var team_material: Material = a.mat("aether_cyan") if grid.y < 36 else a.mat("aether_amber")
		a.add_cylinder("SpawnHalo", _world(grid, 4.06), 2.15 * GU, 0.18 * GU, team_material, false)
		for side in [-1.0, 1.0]:
			a.add_cylinder("SanctumFinial", _world(grid) + Vector3(side * 5.0 * GU, 4.75 * GU, 0), 0.42 * GU, 1.5 * GU, a.mat("aether_gold"), true, Vector3.ZERO, null, a.surface("bounce"))
		var back_sign := 1.0 if grid.y < 36 else -1.0
		a.add_box("SanctumOuterGuard", _world(grid, 4.72) + Vector3(0, 0, back_sign * 3.55 * GU), Vector3(10.5 * GU, 1.45 * GU, 0.34 * GU), a.mat("aether_ivory"), true, Vector3.ZERO, null, a.surface("bounce"))
		for side in [-1.0, 1.0]:
			a.add_box("SanctumWingGuard", _world(grid, 4.72) + Vector3(side * 5.18 * GU, 0, back_sign * 1.55 * GU), Vector3(0.34 * GU, 1.45 * GU, 4.2 * GU), a.mat("aether_ivory"), true, Vector3.ZERO, null, a.surface("bounce"))
			a.add_box("SanctumGuardGoldCap", _world(grid, 5.47) + Vector3(side * 5.18 * GU, 0, back_sign * 1.55 * GU), Vector3(0.42 * GU, 0.12 * GU, 4.25 * GU), a.mat("aether_gold"), false)
		var ramp_grid := Vector2(24, 10) if grid.y < 36 else Vector2(24, 62)
		var yaw := 0.0 if grid.y < 36 else PI
		GEOMETRY.add_curved_ramp(a, "SanctumCurvedDescent", _world(ramp_grid), 6.0 * GU, 8.0 * GU, 4.0 * GU, 0.0, yaw, a.mat("aether_ivory"), a.mat("aether_gold"), a.surface("normal"))


func _build_crown(a) -> void:
	var crown := VORTEX.new() as Area3D
	crown.name = "AetherCrownVortex"
	crown.position = _world(Vector2(24, 36))
	a.add_child(crown)
	_mark(crown, "aether_crown", Vector2(24, 36), Vector3(12, 1.5, 12), {"horizontal_multiplier": 1.08, "strong_vertical": true})


func _build_wing_terraces(a) -> void:
	for grid in [Vector2(6, 36), Vector2(42, 36)]:
		var terrace := GEOMETRY.add_crescent_terrace(a, "WestCrescentTerrace" if grid.x < 24 else "EastCrescentTerrace", _world(grid), 11.0 * GU, 7.25 * GU, 4.0 * GU, grid.x < 24, a.mat("aether_ivory"), a.mat("aether_gold"), a.surface("normal"))
		_mark(terrace, "crescent_wing_terrace", grid, Vector3(8, 4, 22), {"open_inward": true, "outer_rail_only": true})
		# The crescent's mass sits on its centre-angle side (toward the arena for
		# both wings), so probe the deck mid-way between the inner and outer arcs.
		a.mark_elevated_route(terrace, _world(grid, 4.0) + Vector3((9.1 if grid.x < 24 else -9.1) * GU, 0, 0))


func _build_ascension_ramps(a) -> void:
	for grid in [Vector2(6, 20), Vector2(42, 20), Vector2(6, 52), Vector2(42, 52)]:
		var yaw := -PI * 0.5 if grid.x < 24 else PI * 0.5
		var ramp := GEOMETRY.add_bowed_ramp(a, "AscensionRamp", _world(grid), 6.0 * GU, 10.0 * GU, 4.0 * GU, 0.5 * GU, yaw, -1.0 if grid.y < 36 else 1.0, a.mat("aether_ivory"), a.mat("aether_gold"), a.surface("normal"))
		_mark(ramp, "ascension_ramp", grid, Vector3(6, 4.5, 10), {"smooth_curve": true, "momentum_preserving": true})


func _build_sun_seals(a) -> void:
	var pairs := [
		[Vector2(19, 11), Vector2(17, 25)], [Vector2(29, 11), Vector2(31, 25)],
		[Vector2(19, 61), Vector2(17, 47)], [Vector2(29, 61), Vector2(31, 47)],
	]
	for pair in pairs:
		var grid := pair[0] as Vector2
		var target := pair[1] as Vector2
		var boost := BOOST.new() as Area3D
		boost.name = "SunSealBoost"
		boost.position = _world(grid)
		boost.configure((_world(target) - _world(grid)).normalized() + Vector3.UP * 0.34, 31.0)
		a.add_child(boost)
		_mark(boost, "boost_pad", grid, Vector3(3, 0.3, 3), {"target_gu": target, "strength": "medium"})


func _build_wind_arches(a) -> void:
	var specs := [
		[Vector2(15, 18), Vector2(8, 29)], [Vector2(33, 18), Vector2(40, 29)],
		[Vector2(15, 54), Vector2(8, 43)], [Vector2(33, 54), Vector2(40, 43)],
	]
	for spec in specs:
		var grid := spec[0] as Vector2
		var target := spec[1] as Vector2
		var root := Node3D.new()
		root.name = "WindArchHousing"
		root.position = _world(grid)
		a.visual_root().add_child(root)
		_mark(root, "wind_arch", grid, Vector3(6, 5, 2), {"target_gu": target, "solid_housing": true})
		var direction := (_world(target) - _world(grid)).normalized()
		var yaw := atan2(direction.x, direction.z)
		root.rotation.y = yaw
		for side in [-1.0, 1.0]:
			a.add_box("WindArchPier", Vector3(side * 3.0 * GU, 2.5 * GU, 0), Vector3(0.85 * GU, 5.0 * GU, 2.0 * GU), a.mat("aether_ivory"), true, Vector3.ZERO, root, a.surface("bounce"))
			a.add_box("WindArchGoldReveal", Vector3(side * 2.52 * GU, 2.5 * GU, -1.02 * GU), Vector3(0.12 * GU, 3.8 * GU, 0.12 * GU), a.mat("aether_gold"), false, Vector3.ZERO, root)
		a.add_box("WindArchLintel", Vector3(0, 4.65 * GU, 0), Vector3(6.6 * GU, 0.7 * GU, 2.0 * GU), a.mat("aether_ivory"), true, Vector3.ZERO, root, a.surface("bounce"))
		a.add_torus("WindArchHalo", Vector3(0, 2.55 * GU, 0), 1.7 * GU, 2.35 * GU, a.mat("aether_cyan"), false, Vector3(PI * 0.5, 0, 0), root)
		for side in [-1.0, 1.0]:
			for feather_index in range(4):
				var spread := float(feather_index) - 1.5
				a.add_box("WindArchFeather", Vector3(side * (3.2 + feather_index * 0.46) * GU, (2.8 - absf(spread) * 0.28) * GU, 0.16 * GU), Vector3((1.6 + feather_index * 0.18) * GU, 0.28 * GU, 0.55 * GU), a.mat("aether_ivory"), false, Vector3(0, 0, side * spread * 0.16), root)
		var zone := a.add_wind_zone(_world(grid, 2.35), Vector3(5.1 * GU, 4.3 * GU, 5.0 * GU), direction + Vector3.UP * 0.12, 138.0, Color("48CDE8")) as Area3D
		zone.set_meta("aether_wind_source_gu", grid)
		zone.set_meta("aether_wind_target_gu", target)
		a.mark_duel_interactable(zone, "deterministic diagonal wind route through a solid celestial arch", true)


func _build_rebound_pylons(a) -> void:
	var grids := [Vector2(17, 25), Vector2(31, 25), Vector2(15, 33), Vector2(33, 33), Vector2(15, 39), Vector2(33, 39), Vector2(17, 47), Vector2(31, 47)]
	for grid in grids:
		var pylon := REBOUND.new() as Area3D
		pylon.name = "RadialReboundPylon"
		pylon.position = _world(grid)
		pylon.configure(true, Vector3.ZERO, 1.08)
		a.add_child(pylon)
		_mark(pylon, "rebound_pylon", grid, Vector3(3, 3, 3), {"vertical_preserved": true})


func _build_low_wing_walls(a) -> void:
	var specs := [
		[Vector2(20, 22), 25.0], [Vector2(28, 22), -25.0], [Vector2(12.5, 36), 90.0],
		[Vector2(35.5, 36), 90.0], [Vector2(20, 50), -25.0], [Vector2(28, 50), 25.0],
	]
	for spec in specs:
		var grid := spec[0] as Vector2
		var yaw := deg_to_rad(float(spec[1]))
		var wall := GEOMETRY.add_crescent_terrace(a, "LowWingWall", _world(grid), 2.8 * GU, 1.65 * GU, 1.5 * GU, grid.x < 24, a.mat("aether_ivory"), a.mat("aether_gold"), a.surface("bounce"), yaw, false)
		_mark(wall, "low_wing_wall", grid, Vector3(5, 1.5, 1.2), {"yaw_degrees": spec[1], "vaultable": true})
		wall.add_to_group("duel_cover")
		wall.set_meta("flow_lane", "left" if grid.x < 24 else ("right" if grid.x > 24 else "center"))


func _build_seraph_pillars(a) -> void:
	# Two ivory seraph pillars stand on the meridian between each sanctum descent
	# and the crown approach. They are the only objects taller than a sanctum on
	# the centre line: each splits the direct lane into two readable sides, hides
	# the far sanctum from a blob on the near one, and is a ricochet post for
	# bank shots down the meridian. Nothing is placed over the crown's launch.
	for grid in [Vector2(24, 17.5), Vector2(24, 54.5)]:
		var base := _world(grid)
		var column: MeshInstance3D = a.add_cylinder("SeraphPillar", base + Vector3.UP * 3.25 * GU, 1.25 * GU, 6.5 * GU, a.mat("aether_ivory"), true, Vector3.ZERO, null, a.surface("bounce"))
		_mark(column, "seraph_pillar", grid, Vector3(2.5, 6.5, 2.5), {"sightline_break": true, "meridian_split": true})
		column.add_to_group("duel_cover")
		column.set_meta("flow_lane", "center")
		column.set_meta("cover_role", "meridian_post")
		a.add_torus("SeraphBaseRing", base + Vector3.UP * 0.12 * GU, 1.25 * GU, 1.55 * GU, a.mat("aether_gold"), false)
		a.add_cylinder("SeraphNavyBand", base + Vector3.UP * 3.25 * GU, 1.28 * GU, 0.5 * GU, a.mat("aether_navy"), false)
		a.add_torus("SeraphCapital", base + Vector3.UP * 6.25 * GU, 1.2 * GU, 1.5 * GU, a.mat("aether_gold"), false)
		a.add_torus("SeraphHalo", base + Vector3.UP * 7.3 * GU, 1.55 * GU, 1.85 * GU, a.mat("aether_cyan"), false)
		for side in [-1.0, 1.0]:
			a.add_box("SeraphGoldSeam", base + Vector3(side * 1.26 * GU, 3.25 * GU, 0), Vector3(0.06 * GU, 5.6 * GU, 0.16 * GU), a.mat("aether_gold"), false)
			a.add_box("SeraphWing", base + Vector3(side * 1.75 * GU, 5.5 * GU, 0), Vector3(1.1 * GU, 0.2 * GU, 0.45 * GU), a.mat("aether_white"), false, Vector3(0, 0, side * 0.32))


func _build_wingstream_rails(a) -> void:
	for grid in [Vector2(6, 31), Vector2(42, 31), Vector2(6, 41), Vector2(42, 41)]:
		var toward_map_y := 1.0 if grid.y < 36 else -1.0
		var world_direction := Vector3(0, 0, -toward_map_y)
		var rail := a.add_conveyor(_world(grid, 0.24), Vector3(4.0 * GU, 0.48 * GU, 6.0 * GU), world_direction, 74.0, Color("48CDE8")) as Area3D
		_mark(rail, "wingstream_rail", grid, Vector3(4, 0.48, 6), {"horizontal_only": true, "map_y_direction": toward_map_y})
		a.mark_duel_interactable(rail, "short deterministic wingstream link between terrace and crown", true)


func _build_wall_rebound_fins(a) -> void:
	var specs: Array = []
	for y in [14.0, 29.0, 43.0, 58.0]:
		specs.append([Vector2(2, y), Vector3.RIGHT, 0.0])
		specs.append([Vector2(46, y), Vector3.LEFT, 0.0])
	for x in [16.0, 32.0]:
		specs.append([Vector2(x, 2), Vector3.FORWARD, PI * 0.5])
		specs.append([Vector2(x, 70), Vector3.BACK, PI * 0.5])
	for spec in specs:
		var grid := spec[0] as Vector2
		var fin := REBOUND.new() as Area3D
		fin.name = "WallReboundFin"
		fin.position = _world(grid, 2.0)
		fin.rotation.y = float(spec[2])
		fin.configure(false, spec[1] as Vector3, 1.10, Vector3(0.5 * GU, 4.0 * GU, 7.0 * GU))
		a.add_child(fin)
		_mark(fin, "wall_rebound_fin", grid, Vector3(0.5, 4, 7), {"vertical_preserved": true, "inward_reflection": true})


func _build_skyrail_ledges(a) -> void:
	for y in [7.0, 22.0, 50.0, 65.0]:
		for grid in [Vector2(2.7, y), Vector2(45.3, y)]:
			var ledge := a.add_box("SkyrailLedge", _world(grid, 5.325), Vector3(0.75 * GU, 0.35 * GU, 6.0 * GU), a.mat("aether_gold"), true, Vector3.ZERO, null, a.surface("bounce")) as MeshInstance3D
			_mark(ledge, "skyrail_ledge", grid, Vector3(0.75, 0.35, 6), {"top_height_gu": 5.5})


func _build_route_language(a) -> void:
	for grid in [Vector2(24, 15), Vector2(24, 27), Vector2(24, 45), Vector2(24, 57)]:
		a.add_flow_anchor("AetherMeridian", _world(grid, 0.4), "attack_route", "center")
	for grid in [Vector2(9, 24), Vector2(39, 24), Vector2(9, 48), Vector2(39, 48)]:
		a.add_flow_anchor("AetherWingRoute", _world(grid, 0.4), "flank_route", "left" if grid.x < 24 else "right")
	a.add_flow_anchor("AetherCrownContest", _world(Vector2(24, 36), 1.6), "center_contest", "center")


func _add_floor_inlay(a, from_grid: Vector2, to_grid: Vector2, material: Material) -> void:
	var start := _world(from_grid, 0.15)
	var finish := _world(to_grid, 0.15)
	var delta := finish - start
	var center := (start + finish) * 0.5
	var yaw := atan2(delta.x, delta.z)
	a.add_box("CelestialRouteInlay", center, Vector3(0.11 * GU, 0.045 * GU, delta.length()), material, false, Vector3(0, yaw, 0))
