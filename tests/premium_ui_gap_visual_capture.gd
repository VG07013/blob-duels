extends SceneTree

const HUD_SCENE := preload("res://scenes/hud.tscn")
const PAUSE_SCENE := preload("res://scenes/ui/pause_menu.tscn")
const MAIN_SCENE := preload("res://scenes/main.tscn")
const OUTPUT_DIR := "res://artifacts/screenshots"

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	await _capture_ui_at_size(Vector2i(1280, 720), "1280x720")
	await _capture_ui_at_size(Vector2i(960, 540), "960x540")
	await _capture_practice_nameplates()
	print("PREMIUM UI GAP VISUAL CAPTURE PASS" if _failures == 0 else "PREMIUM UI GAP VISUAL CAPTURE FAILED")
	quit(0 if _failures == 0 else 1)


func _capture_ui_at_size(viewport_size: Vector2i, suffix: String) -> void:
	DisplayServer.window_set_size(viewport_size)
	root.size = viewport_size
	var background := ColorRect.new()
	background.color = Color(0.025, 0.06, 0.105)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)
	var hud := HUD_SCENE.instantiate()
	root.add_child(hud)
	await _settle()
	hud.call("set_lobby_mode", false)
	hud.call("set_duel_mode", true)
	hud.call("set_round_number", 3)
	hud.call("set_duel_score", 2, 1)
	hud.call("set_match_time", 83.0)
	hud.call("set_ability_state", "dash", 1800, false, false)
	hud.call("set_fling_cooldown", 1.8, 3.0)
	await _settle()
	_save("premium_fling_cooldown_%s.png" % suffix)

	hud.call("set_lobby_mode", true)
	hud.call("_set_progression_open", "shop")
	hud.call("_show_purchase_confirm", "abilities", {
		"id": "gravity_pulse",
		"name": "Gravity Pulse",
		"price": 450,
		"description": "Pull nearby rivals inward, then release them with a shockwave.",
	})
	await _settle()
	_save("premium_purchase_modal_%s.png" % suffix)
	hud.call("close_progression")
	hud.call("set_lobby_mode", false)
	hud.call("begin_victory_cinematic")
	var pause := PAUSE_SCENE.instantiate()
	pause.settings_path = "user://premium_gap_capture.cfg"
	root.add_child(pause)
	await _settle()
	pause.call("set_context", true, false, "dash", null)
	pause.call("set_host_room_code", "BLOB-7421")
	pause.call("open_pause")
	await _settle()
	_save("premium_pause_host_code_%s.png" % suffix)
	pause.queue_free()
	hud.queue_free()
	background.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://premium_gap_capture.cfg"))


func _capture_practice_nameplates() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	root.size = Vector2i(1280, 720)
	var game := MAIN_SCENE.instantiate()
	root.add_child(game)
	await _settle()
	game.set_process(false)
	game.set_physics_process(false)
	game.call("_activate_practice_map")
	var hud := game.get_node("HUD")
	hud.call("set_lobby_mode", false)
	hud.call("set_practice_mode", true)
	var player := game.get_node("Player") as RigidBody3D
	player.freeze = true
	player.global_position = Vector3(0.0, 5.0, 50.0)
	game.call("_set_player_mesh_visible", true)
	var rig := game.get_node("CameraRig") as Node3D
	var camera := game.get_node("CameraRig/Camera3D") as Camera3D
	camera.position = Vector3.ZERO
	rig.global_position = Vector3(0.0, 20.0, 90.0)
	rig.look_at(Vector3(0.0, 5.0, -25.0), Vector3.UP)
	camera.fov = 72.0
	await _settle()
	_save("premium_practice_nameplates_1280x720.png")
	game.queue_free()
	await process_frame


func _settle() -> void:
	for _index in 10:
		await process_frame
	await create_timer(0.1).timeout
	RenderingServer.force_draw()
	await process_frame


func _save(filename: String) -> void:
	RenderingServer.force_draw()
	var image := root.get_texture().get_image()
	if image == null:
		_failures += 1
		push_error("Could not read rendered image for %s" % filename)
		return
	var error := image.save_png(ProjectSettings.globalize_path("%s/%s" % [OUTPUT_DIR, filename]))
	if error != OK:
		_failures += 1
		push_error("Could not save %s" % filename)
