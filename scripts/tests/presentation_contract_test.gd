extends SceneTree

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const DUMMY_SCENE := preload("res://scenes/player/dummy_blob.tscn")
const PAUSE_SCENE := preload("res://scenes/ui/pause_menu.tscn")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_check_blob_scene(PLAYER_SCENE.instantiate(), true)
	_check_blob_scene(DUMMY_SCENE.instantiate(), false)
	await _check_pause_menu()

	if _failures.is_empty():
		print("PRESENTATION CONTRACT PASS")
		quit(0)
		return

	for failure in _failures:
		push_error(failure)
	quit(1)


func _check_blob_scene(blob: RigidBody3D, is_player: bool) -> void:
	root.add_child(blob)
	var label := "player" if is_player else "dummy"
	var ground_cast := blob.get_node_or_null("GroundCast") as ShapeCast3D
	_expect(ground_cast != null, "%s needs GroundCast" % label)
	if ground_cast != null:
		_expect(ground_cast.enabled, "%s GroundCast must be enabled" % label)
		_expect(ground_cast.exclude_parent, "%s GroundCast must exclude its parent" % label)
		_expect(ground_cast.collision_mask == 1, "%s GroundCast must use collision mask 1" % label)
		_expect(ground_cast.target_position.is_equal_approx(Vector3(0, -3.35, 0)), "%s GroundCast target is incorrect" % label)
		_expect(is_equal_approx(ground_cast.margin, 0.2), "%s GroundCast margin is incorrect" % label)
		var sphere := ground_cast.shape as SphereShape3D
		_expect(sphere != null and is_equal_approx(sphere.radius, 2.45), "%s GroundCast needs a 2.45 radius sphere" % label)

	var material := blob.physics_material_override
	_expect(material != null and is_equal_approx(material.friction, 0.12), "%s friction must be 0.12" % label)
	_expect(material != null and is_equal_approx(material.bounce, 0.94), "%s bounce must be 0.94" % label)
	if is_player:
		_expect(is_equal_approx(blob.linear_damp, 0.06), "player linear damp must be 0.06")
		_expect(is_equal_approx(blob.angular_damp, 0.28), "player angular damp must be 0.28")

	var visual_root := blob.get_node("VisualRoot") as Node3D
	_expect(visual_root.scale.is_equal_approx(Vector3.ONE), "%s visual must start undeformed" % label)
	blob.linear_velocity = Vector3(18, -7, 11)
	visual_root.call("hit_reaction", 0.9)
	visual_root.call("_physics_process", 0.016)
	_expect(visual_root.scale.y < visual_root.scale.x, "%s visual must visibly react at speed" % label)
	_expect(visual_root.scale.y < 1.0, "%s visual must squash after an impact" % label)
	var visual_scale_before_blink := visual_root.scale
	_expect(blob.has_node("FaceRoot/LeftEyeWhite"), "%s needs a readable left eye" % label)
	_expect(blob.has_node("FaceRoot/RightEyeWhite"), "%s needs a readable right eye" % label)
	_expect(blob.has_node("FaceRoot/LeftPupil"), "%s needs a left pupil" % label)
	_expect(blob.has_node("FaceRoot/RightPupil"), "%s needs a right pupil" % label)
	_expect(blob.has_node("FaceRoot/SmileLeft"), "%s needs a small smile" % label)
	_expect(not blob.has_node("FaceRoot/SmileCenter"), "%s must not keep the oversized old mouth" % label)
	if is_player:
		_expect(not blob.has_node("VisualRoot/AimMarker"), "player must not keep the protruding aim marker")
	var face_root := blob.get_node("FaceRoot") as Node3D
	_expect(face_root.has_method("trigger_blink"), "%s face needs a friendly blink animation" % label)
	if face_root.has_method("trigger_blink"):
		var eye := face_root.get_node("LeftEyeWhite") as Node3D
		var original_eye_scale := eye.scale
		face_root.call("trigger_blink")
		face_root.call("_process", 0.08)
		_expect(eye.scale.y < original_eye_scale.y * 0.3, "%s blink does not visibly close the eyes" % label)
		_expect(visual_root.scale.is_equal_approx(visual_scale_before_blink), "%s blink must not alter the body reaction" % label)
	blob.free()


func _check_pause_menu() -> void:
	var pause_menu := PAUSE_SCENE.instantiate()
	pause_menu.settings_path = "user://blob_duels_test_settings.cfg"
	root.add_child(pause_menu)
	var actions := pause_menu.get_node("PausePanel/Content/Actions")
	_expect(actions.get_child_count() == 3, "pause menu must have exactly three bottom actions")
	var action_names: Array[String] = []
	for child in actions.get_children():
		action_names.append(child.name)
	_expect(action_names == ["LobbyButton", "RespawnButton", "ResumeButton"], "pause actions must remain Lobby, Respawn, Resume")
	_expect(pause_menu.has_node("PausePanel/Content/Pages/MatchPage"), "pause menu must preserve Match page")
	_expect(pause_menu.has_node("PausePanel/Content/Pages/SettingsPage"), "pause menu must preserve Settings page")
	_expect(pause_menu.has_node("PausePanel/Content/Pages/CrosshairPage"), "pause menu must preserve Crosshair page")
	var settings: Dictionary = pause_menu.call("get_settings")
	for key in [
		"mouse_sensitivity", "master_volume", "music_volume", "sfx_volume",
		"graphics_quality", "render_scale_index", "render_scale", "fullscreen",
		"vsync", "shadow_quality", "camera_shake", "active_crosshair_slot",
		"crosshair_length", "crosshair_thickness", "crosshair_gap", "crosshair_dot",
		"crosshair_dot_size", "crosshair_outline", "crosshair_outline_thickness",
		"crosshair_color_index", "crosshair_color_value", "crosshair_opacity",
		"crosshair_dynamic", "crosshair_dynamic_amount", "crosshair_rotation",
	]:
		_expect(settings.has(key), "pause menu lost persistent setting: %s" % key)
	pause_menu.call("_select_crosshair_slot", 2)
	_expect(int(pause_menu.call("get_settings").get("active_crosshair_slot")) == 2, "crosshair slot selection must persist")
	for viewport_size in [Vector2i(1280, 720), Vector2i(1440, 900), Vector2i(1920, 1080)]:
		root.size = viewport_size
		pause_menu.call("_fit_to_viewport")
		var panel := pause_menu.get_node("PausePanel") as PanelContainer
		var panel_width := panel.offset_right - panel.offset_left
		var panel_height := panel.offset_bottom - panel.offset_top
		_expect(panel_width <= viewport_size.x - 48.0, "pause menu overflows at %s" % viewport_size)
		_expect(panel_height <= viewport_size.y - 36.0, "pause menu overflows vertically at %s" % viewport_size)
	pause_menu.free()
	await process_frame
	var reloaded_menu := PAUSE_SCENE.instantiate()
	reloaded_menu.settings_path = "user://blob_duels_test_settings.cfg"
	root.add_child(reloaded_menu)
	await process_frame
	var reloaded_slot := int(reloaded_menu.call("get_settings").get("active_crosshair_slot"))
	_expect(reloaded_slot == 2, "crosshair slot selection does not survive a settings reload (got %d)" % reloaded_slot)
	reloaded_menu.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://blob_duels_test_settings.cfg"))


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
