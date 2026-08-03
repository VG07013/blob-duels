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
	var camera_rig := game.get_node("CameraRig") as Node3D
	var camera := game.get_node("CameraRig/Camera3D") as Camera3D
	game.call("_set_player_mesh_visible", true)
	camera.position = Vector3.ZERO
	camera_rig.global_position = Vector3(12.0, 8.0, 637.0)
	camera_rig.look_at(Vector3(0.0, 4.5, 620.0), Vector3.UP)
	camera.fov = 67.0

	await _settle()
	_save("lobby_ui_revamp.png")
	var hud := game.get_node("HUD")
	hud.call("_set_progression_open", "shop")
	await _settle()
	_save("shop_ui_revamp.png")
	hud.call("_set_progression_open", "quests")
	await _settle()
	_save("quests_ui_revamp.png")
	hud.call("close_progression")
	hud.call("set_lobby_ui_suppressed", true)
	var pause := game.get_node("PauseMenu")
	pause.call("set_context", false, false)
	pause.call("open_pause")
	pause.call("show_settings")
	await _settle()
	_save("settings_ui_revamp.png")

	game.queue_free()
	await process_frame
	if _failures == 0:
		print("UI REVAMP VISUAL CAPTURE PASS")
		quit(0)
	else:
		quit(1)


func _settle() -> void:
	for _index in 6:
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
