extends SceneTree

const OUTPUT_DIR := "res://artifacts/screenshots"
const MAPS := {
	"bounceground": preload("res://scenes/world/maps/bounceground.tscn"),
	"training_yard": preload("res://scenes/world/maps/training_yard.tscn"),
}
const PRACTICE_SCENE := preload("res://scenes/world/practice_arena.tscn")
const MAIN_SCENE := preload("res://scenes/main.tscn")
const DETAIL_MODEL_IDS := {
	"bounceground": "",
	"training_yard": "",
}

var _capture_failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	root.size = Vector2i(1280, 720)
	for map_id: String in MAPS:
		await _capture_duel_map(map_id, MAPS[map_id])
	await _capture_practice_map()
	await _capture_game_ui()
	await _capture_gameplay_moments()
	if _capture_failures > 0:
		push_error("VISUAL CAPTURE FAILED: %d image(s) could not be saved" % _capture_failures)
		quit(1)
		return
	print("VISUAL CAPTURE PASS: %s" % ProjectSettings.globalize_path(OUTPUT_DIR))
	quit(0)


func _capture_duel_map(map_id: String, packed_map: PackedScene) -> void:
	var world := _make_world()
	root.add_child(world)
	var arena := packed_map.instantiate() as Node3D
	world.add_child(arena)
	await process_frame
	await process_frame
	_apply_profile(world, arena.call("get_lighting_profile") as Dictionary)
	var camera := world.get_node("Camera") as Camera3D
	var half_width: float = float(arena.get("arena_half_width"))
	var half_length: float = float(arena.get("arena_half_length"))
	camera.position = Vector3(half_width * 1.7, half_width * 3.1, half_length * 1.4)
	camera.look_at(Vector3(0.0, 5.0, 0.0), Vector3.UP)
	camera.fov = 55.0
	await _settle_render()
	_save_viewport("%s_wide.png" % map_id)

	camera.position = Vector3(0.0, maxf(half_length * 1.16, 250.0), 0.1)
	camera.look_at(Vector3.ZERO, Vector3.FORWARD)
	camera.fov = 56.0
	await _settle_render()
	_save_viewport("%s_flow_overhead.png" % map_id)

	camera.position = Vector3(half_width * 0.82, 25.0, half_length * 0.34)
	camera.look_at(Vector3(0.0, 5.0, 0.0), Vector3.UP)
	camera.fov = 62.0
	await _settle_render()
	_save_viewport("%s_center_combat.png" % map_id)

	var interactable := _descendant_by_interaction_kind(arena, &"launch_pad") as Node3D
	if interactable == null:
		interactable = _first_descendant_in_group(arena, &"map_interactable") as Node3D
	if interactable != null:
		var target := interactable.global_position + Vector3.UP * 1.5
		camera.global_position = target + Vector3(15.0, 10.0, 19.0)
		camera.look_at(target, Vector3.UP)
		camera.fov = 58.0
		await _settle_render()
		_save_viewport("%s_interactive.png" % map_id)

	var spawns := arena.call("get_spawn_points") as Array
	for spawn_index in range(spawns.size()):
		var spawn := spawns[spawn_index] as Marker3D
		camera.global_position = spawn.global_position + Vector3.UP * 2.4
		camera.look_at(Vector3(0.0, 5.0, 0.0), Vector3.UP)
		camera.fov = 88.0
		await _settle_render()
		var team_label := "red" if spawn.name.begins_with("Red") else "blue"
		_save_viewport("%s_player_%s.png" % [map_id, team_label])
		if spawn_index == 0:
			_save_viewport("%s_player.png" % map_id)

	var detail_model := _model_by_id(arena, String(DETAIL_MODEL_IDS.get(map_id, ""))) as Node3D
	if detail_model != null:
		var detail_target := detail_model.global_position + Vector3.UP * 4.0
		var toward_center := Vector3(-detail_target.x, 0.0, -detail_target.z).normalized()
		var lateral := toward_center.cross(Vector3.UP).normalized()
		camera.global_position = detail_target + toward_center * 18.0 + lateral * 5.0 + Vector3.UP * 8.0
		camera.look_at(detail_target, Vector3.UP)
		camera.fov = 54.0
		await _settle_render()
		_save_viewport("%s_model_detail.png" % map_id)

	var display := _first_descendant_in_group(arena, &"world_display") as Node3D
	if display != null:
		var display_target := display.global_position
		camera.global_position = display_target + Vector3(0.0, -1.0, 22.0)
		camera.look_at(display_target, Vector3.UP)
		camera.fov = 48.0
		await _settle_render()
		_save_viewport("%s_display.png" % map_id)
	world.queue_free()
	await process_frame


func _capture_practice_map() -> void:
	var world := _make_world()
	root.add_child(world)
	var practice := PRACTICE_SCENE.instantiate() as Node3D
	world.add_child(practice)
	await process_frame
	await process_frame
	_apply_profile(world, practice.call("get_lighting_profile") as Dictionary)
	var camera := world.get_node("Camera") as Camera3D
	# Blueprint-comparison angles: the straight-down overhead mirrors the
	# reference sheet, the rest walk the training stations.
	var shots := [
		{"file": "practice_facility_wide.png", "from": Vector3(52.0, 40.0, 58.0), "at": Vector3(0.0, 2.0, 0.0), "fov": 55.0},
		{"file": "practice_overhead.png", "from": Vector3(0.0, 108.0, 0.1), "at": Vector3(0.0, 0.0, 0.0), "fov": 50.0},
		{"file": "practice_center_platform.png", "from": Vector3(14.0, 8.0, 16.0), "at": Vector3(0.0, 1.7, 0.0), "fov": 60.0},
		{"file": "practice_wall_panels.png", "from": Vector3(-22.0, 5.0, 0.0), "at": Vector3(-39.0, 4.3, 0.0), "fov": 60.0},
		{"file": "practice_dummy_lanes.png", "from": Vector3(0.0, 8.0, 4.0), "at": Vector3(0.0, 3.0, -15.9), "fov": 62.0},
	]
	for shot in shots:
		camera.position = shot["from"] as Vector3
		camera.look_at(shot["at"] as Vector3, Vector3.UP)
		camera.fov = float(shot["fov"])
		await _settle_render()
		_save_viewport(str(shot["file"]))
	world.queue_free()
	await process_frame


func _capture_game_ui() -> void:
	var game := MAIN_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	var player := game.get_node("Player") as RigidBody3D
	player.freeze = true
	var camera_rig := game.get_node("CameraRig") as Node3D
	var camera := game.get_node("CameraRig/Camera3D") as Camera3D
	game.call("_set_player_mesh_visible", true)
	camera.position = Vector3.ZERO
	camera_rig.global_position = Vector3(0.0, 7.0, 638.0)
	camera_rig.look_at(Vector3(0.0, 4.5, 620.0), Vector3.UP)
	camera.fov = 64.0
	await _settle_render()
	_save_viewport("lobby_interior.png")
	for view_index in range(3):
		var angle := -PI * 0.5 + float(view_index) * PI * 0.5
		camera_rig.global_position = Vector3(sin(angle) * 16.0, 6.5, 620.0 + cos(angle) * 16.0)
		camera_rig.look_at(Vector3(0.0, 4.5, 620.0), Vector3.UP)
		await _settle_render()
		_save_viewport("lobby_interior_%02d.png" % view_index)

	var pause_menu := game.get_node("PauseMenu")
	pause_menu.call("set_context", false, false)
	pause_menu.call("open_pause")
	await _settle_render()
	_save_viewport("pause_1280x720.png")
	root.size = Vector2i(1440, 900)
	pause_menu.call("_fit_to_viewport")
	await _settle_render()
	_save_viewport("pause_1440x900.png")
	root.size = Vector2i(1920, 1080)
	pause_menu.call("_fit_to_viewport")
	await _settle_render()
	_save_viewport("pause_1920x1080.png")
	pause_menu.call("_show_page", 1)
	await _settle_render()
	_save_viewport("settings_1920x1080.png")
	pause_menu.call("_show_page", 2)
	await _settle_render()
	_save_viewport("crosshair_editor_1920x1080.png")

	pause_menu.call("close_pause")
	root.size = Vector2i(1280, 720)
	game.get_viewport().disable_3d = false
	game.get_node("PracticeArena").visible = true
	game.get_node("HUD").call("set_lobby_mode", false)
	game.get_node("HUD").call("set_duel_mode", false)
	player.global_position = Vector3(0.0, 5.0, 56.0)
	game.call("_set_player_mesh_visible", false)
	camera_rig.global_position = player.global_position + Vector3.UP * 1.8
	camera_rig.rotation = Vector3(-0.04, 0.0, 0.0)
	camera.fov = 88.0
	player.set("fling_charge", float(player.get("maximum_charge_time")) * 0.25)
	player.fling_charge_updated.emit(0.25)
	await _settle_render()
	_save_viewport("fling_charge_25.png")
	player.set("fling_charge", float(player.get("maximum_charge_time")))
	player.fling_charge_updated.emit(1.0)
	await _settle_render()
	_save_viewport("fling_charge_full.png")
	var roster := [
		{"name": "Player", "color": Color(0.94, 0.12, 0.18), "team_name": "RED", "team_color": Color(0.94, 0.12, 0.18), "eliminations": 5, "deaths": 2},
		{"name": "Rival", "color": Color(0.06, 0.42, 0.96), "team_name": "BLUE", "team_color": Color(0.06, 0.42, 0.96), "eliminations": 2, "deaths": 5},
	]
	var hud := game.get_node("HUD")
	hud.call("begin_victory_cinematic")
	hud.call("show_victory", true, 0, roster)
	await create_timer(1.7).timeout
	await _settle_render()
	_save_viewport("victory_screen.png")
	game.queue_free()
	await process_frame


func _capture_gameplay_moments() -> void:
	root.size = Vector2i(1280, 720)
	var game := MAIN_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.call("_start_practice_match")
	await _physics_frames(3)
	var player := game.get_node("Player") as RigidBody3D
	var dummy := game.get_node("DummyStationA") as RigidBody3D
	player.gravity_scale = 0.0
	dummy.gravity_scale = 0.0
	player.global_position = Vector3(0.0, 8.0, 14.0)
	player.linear_velocity = Vector3.ZERO
	dummy.global_position = Vector3(0.0, 8.0, 0.0)
	dummy.linear_velocity = Vector3.ZERO
	game.set("camera_yaw", 0.0)
	game.set("camera_pitch", 0.0)
	player.set("aim_direction", Vector3.FORWARD)
	player.call("request_shot_for_test")
	await _physics_frames(9)
	await _settle_render()
	_save_viewport("projectile_hit.png")

	player.respawn(Vector3(0.0, 8.0, 11.0))
	dummy.call("respawn")
	dummy.global_position = Vector3(0.0, 8.0, 0.0)
	dummy.linear_velocity = Vector3.ZERO
	player.linear_velocity = Vector3(0.0, 0.0, -68.0)
	await _physics_frames(6)
	game.set_process(false)
	game.call("_set_player_mesh_visible", true)
	var camera_rig := game.get_node("CameraRig") as Node3D
	var camera := game.get_node("CameraRig/Camera3D") as Camera3D
	camera.position = Vector3.ZERO
	camera_rig.global_position = Vector3(14.0, 15.0, 21.0)
	camera_rig.look_at(Vector3(0.0, 8.0, 4.0), Vector3.UP)
	camera.fov = 68.0
	game.get_node("HUD/Announcement").visible = false
	await _settle_render()
	_save_viewport("blob_collision.png")
	game.set_process(true)

	game.set("_selected_map_id", "bounceground")
	game.call("_activate_competitive_map", "bounceground")
	game.set("_practice_mode", true)
	game.call("_start_arena_for_peer", 1)
	await _physics_frames(3)
	var arena = game.get("_current_competitive_map")
	var half_width := float(arena.get("arena_half_width"))
	player.gravity_scale = 0.0
	player.global_position = Vector3(half_width - 6.5, 8.0, 0.0)
	player.linear_velocity = Vector3(76.0, 0.0, 0.0)
	game.set("camera_yaw", -PI * 0.5)
	game.set("camera_pitch", 0.0)
	await _physics_frames(7)
	game.set_process(false)
	game.call("_set_player_mesh_visible", true)
	camera.position = Vector3.ZERO
	camera_rig.global_position = player.global_position + Vector3(-18.0, 12.0, -22.0)
	camera_rig.look_at(player.global_position + Vector3(0.0, 1.0, 0.0), Vector3.UP)
	camera.fov = 66.0
	game.get_node("HUD/Announcement").visible = false
	await _settle_render()
	_save_viewport("wall_ricochet.png")
	game.set_process(true)

	player.respawn(Vector3(0.0, 6.0, 22.0))
	player.linear_velocity = Vector3(0.0, 0.0, -26.0)
	game.set("camera_yaw", 0.0)
	game.set("camera_pitch", -0.08)
	game.set("third_person_enabled", true)
	game.call("_apply_camera_mode")
	game.get_node("HUD/Announcement").visible = false
	await _physics_frames(5)
	await _settle_render()
	_save_viewport("third_person_gameplay.png")
	game.queue_free()
	await process_frame


func _make_world() -> Node3D:
	var world := Node3D.new()
	world.name = "CaptureWorld"
	var world_environment := WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_energy = 0.86
	# Mirror the shipped environment in scenes/main.tscn - captures that render
	# through a different tonemap stop representing the game.
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_white = 6.0
	environment.adjustment_enabled = true
	environment.adjustment_saturation = 1.12
	environment.adjustment_contrast = 1.06
	environment.glow_enabled = true
	environment.glow_intensity = 0.5
	environment.glow_strength = 0.9
	environment.fog_enabled = true
	environment.fog_density = 0.00045
	world_environment.environment = environment
	world.add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation = Vector3(-0.92, -0.58, 0.0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 900.0
	world.add_child(sun)
	var camera := Camera3D.new()
	camera.name = "Camera"
	camera.current = true
	camera.near = 0.1
	camera.far = 3000.0
	world.add_child(camera)
	return world


func _apply_profile(world: Node3D, profile: Dictionary) -> void:
	var environment := (world.get_node("WorldEnvironment") as WorldEnvironment).environment
	var sky_material := environment.sky.sky_material as ProceduralSkyMaterial
	sky_material.sky_top_color = profile.get("sky_top", Color(0.12, 0.48, 0.92))
	sky_material.sky_horizon_color = profile.get("sky_horizon", Color(0.72, 0.9, 1.0))
	environment.ambient_light_color = profile.get("ambient", Color.WHITE)
	environment.ambient_light_energy = float(profile.get("ambient_energy", 0.86))
	environment.fog_light_color = profile.get("fog", Color(0.62, 0.8, 0.93))
	environment.fog_light_energy = float(profile.get("fog_energy", 0.82))
	environment.fog_density = float(profile.get("fog_density", 0.00065))
	environment.fog_sky_affect = float(profile.get("fog_sky_affect", 0.3))
	var sun := world.get_node("Sun") as DirectionalLight3D
	sun.light_color = profile.get("sun_color", Color.WHITE)
	sun.light_energy = float(profile.get("sun_energy", 1.4))
	sun.rotation_degrees = profile.get("sun_rotation", Vector3(-52.0, -34.0, 0.0))
	sky_material.sun_angle_max = float(profile.get("sun_size", 18.0))
	sky_material.sun_curve = float(profile.get("sun_curve", 0.08))
	# Same glow handling as game.gd _apply_lighting_profile, so a map's authored
	# bloom (or its deliberate absence - Toybox) shows in its captures.
	environment.glow_enabled = bool(profile.get("glow_enabled", true))
	environment.glow_intensity = float(profile.get("glow_intensity", 0.5))
	environment.glow_strength = float(profile.get("glow_strength", 0.9))
	environment.glow_bloom = float(profile.get("glow_bloom", 0.0))
	# Same sky-cover handling as game.gd, so cloud decks and star fields show.
	var game_script := load("res://scripts/game.gd") as GDScript
	var covers: Dictionary = game_script.SKY_COVER_TEXTURES
	sky_material.sky_cover = covers.get(str(profile.get("sky_cover", ""))) as Texture2D
	sky_material.sky_cover_modulate = profile.get("sky_cover_modulate", Color.WHITE) as Color


func _settle_render() -> void:
	await process_frame
	await process_frame
	await process_frame
	await create_timer(0.05).timeout
	# Process frames advance even when the compositor skips presenting (occluded
	# window, throttling), so a grab right after them can read a stale buffer -
	# entire capture sections came out as byte-identical repeats of one frame.
	# frame_post_draw blocks until a frame is genuinely drawn.
	await RenderingServer.frame_post_draw


func _physics_frames(count: int) -> void:
	for _index in range(count):
		await physics_frame


func _save_viewport(file_name: String) -> void:
	var image := root.get_texture().get_image()
	var path := "%s/%s" % [OUTPUT_DIR, file_name]
	var error := image.save_png(path)
	if error != OK:
		_capture_failures += 1
		push_error("Could not save visual capture %s: %s" % [path, error_string(error)])


func _first_descendant_in_group(node: Node, group_name: StringName) -> Node:
	for descendant in node.find_children("*", "", true, false):
		if descendant.is_in_group(group_name):
			return descendant
	return null


func _descendant_by_interaction_kind(node: Node, kind: StringName) -> Node:
	for descendant in node.find_children("*", "", true, false):
		if descendant.has_method("get_interaction_kind") and descendant.call("get_interaction_kind") == kind:
			return descendant
	return null


func _model_by_id(node: Node, model_id: String) -> Node:
	var closest: Node3D = null
	var closest_distance := INF
	for descendant in node.find_children("*", "Node3D", true, false):
		if String(descendant.get_meta("model_id", "")) == model_id:
			var model := descendant as Node3D
			var distance := Vector2(model.global_position.x, model.global_position.z).length_squared()
			if distance < closest_distance:
				closest = model
				closest_distance = distance
	return closest
