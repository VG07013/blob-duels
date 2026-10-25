extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const OUTPUT_DIR := "res://artifacts/screenshots"

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	root.size = Vector2i(1280, 720)
	var game := MAIN_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	var player := game.get_node("Player") as RigidBody3D
	player.freeze = true
	var hud := game.get_node("HUD")
	var pause := game.get_node("PauseMenu")
	var camera_rig := game.get_node("CameraRig") as Node3D
	var camera := game.get_node("CameraRig/Camera3D") as Camera3D
	game.call("_set_player_mesh_visible", true)
	camera.position = Vector3.ZERO
	camera_rig.global_position = Vector3(12.0, 8.0, 637.0)
	camera_rig.look_at(Vector3(0.0, 4.5, 620.0), Vector3.UP)
	camera.fov = 67.0

	# The menu's entrance runs ~1.5s; capture it settled.
	await create_timer(1.8).timeout
	await _settle()
	_save("main_menu.png")

	game.get_viewport().disable_3d = false
	game.get_node("PracticeArena").visible = true
	hud.call("set_lobby_mode", false)
	hud.call("set_duel_mode", true)
	hud.call("set_round_number", 4)
	hud.call("set_duel_score", 3, 2)
	hud.call("set_match_time", 74.0)
	hud.call("set_ability_state", "dash", 2600, false, false)
	hud.call("set_fling_cooldown", 2.4, 3.0)
	player.global_position = Vector3(0.0, 5.0, 56.0)
	game.call("_set_player_mesh_visible", false)
	camera_rig.global_position = player.global_position + Vector3.UP * 1.8
	camera_rig.rotation = Vector3(-0.04, 0.0, 0.0)
	camera.fov = 88.0
	await _settle()
	_save("premium_match_hud.png")
	_save("premium_fling_cooldown.png")

	hud.call("set_duel_score", 5, 2)
	hud.call("begin_victory_cinematic")
	hud.call("show_victory", true, 0, [
		{"name": "Player", "color": Color(0.2, 0.9, 1.0), "team_name": "RED", "team_color": Color(0.94, 0.12, 0.18), "eliminations": 5, "deaths": 2},
		{"name": "Rival", "color": Color(0.55, 0.4, 1.0), "team_name": "BLUE", "team_color": Color(0.06, 0.42, 0.96), "eliminations": 2, "deaths": 5},
	])
	hud.call("show_match_rewards", {
		"breakdown": [
			{"label": "Match complete", "amount": 35},
			{"label": "Eliminations", "amount": 20},
			{"label": "Victory bonus", "amount": 25},
		],
		"total": 80,
	})
	await create_timer(2.15).timeout
	await _settle()
	_save("premium_results.png")

	hud.call("hide_victory")
	pause.call("set_context", true, false, "dash", null)
	pause.call("set_host_room_code", "BLOB-7421")
	pause.call("open_pause")
	await _settle()
	_save("premium_pause_host_code.png")
	pause.call("show_settings")
	await _settle()
	_save("premium_settings.png")

	pause.call("close_pause")
	game.call("_activate_practice_map")
	hud.call("set_practice_mode", true)
	player.global_position = Vector3(0.0, 5.0, 55.0)
	game.call("_set_player_mesh_visible", true)
	camera_rig.global_position = Vector3(0.0, 15.0, 80.0)
	camera_rig.look_at(Vector3(0.0, 5.0, -20.0), Vector3.UP)
	camera.fov = 72.0
	await _settle()
	_save("premium_practice_nameplates.png")

	root.size = Vector2i(960, 540)
	game.call("_set_player_mesh_visible", false)
	hud.call("set_practice_mode", false)
	hud.call("set_lobby_mode", false)
	hud.call("set_duel_mode", true)
	hud.call("set_fling_cooldown", 1.5, 3.0)
	await _settle()
	_save("premium_match_hud_compact_960x540.png")
	pause.call("set_context", true, false, "dash", null)
	pause.call("set_host_room_code", "BLOB-7421")
	pause.call("open_pause")
	await _settle()
	_save("premium_pause_host_code_compact_960x540.png")

	game.queue_free()
	await process_frame
	if _failures == 0:
		print("PREMIUM UI VISUAL CAPTURE PASS")
		quit(0)
	else:
		quit(1)


func _settle() -> void:
	for _index in 8:
		await process_frame
	await create_timer(0.08).timeout


func _save(filename: String) -> void:
	var texture := root.get_texture()
	if texture == null:
		_failures += 1
		push_error("No rendered viewport texture for %s" % filename)
		return
	var image := texture.get_image()
	if image == null:
		_failures += 1
		push_error("No rendered viewport image for %s" % filename)
		return
	var error := image.save_png(ProjectSettings.globalize_path("%s/%s" % [OUTPUT_DIR, filename]))
	if error != OK:
		_failures += 1
		push_error("Could not save %s" % filename)
