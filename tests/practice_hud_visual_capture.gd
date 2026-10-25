extends SceneTree

## Renders the practice HUD - the always-on statistics card and the control
## panel behind Tab - so the layout can be eyeballed instead of trusted. The
## panel is built entirely in code, so nothing about its size or overlap is
## visible from a headless assertion.
##
## Needs a rendering device: run WITHOUT --headless.
##   godot --path . --script res://tests/practice_hud_visual_capture.gd

const PRACTICE_HUD := preload("res://scripts/ui/practice_hud.gd")
const SESSION_SCRIPT := preload("res://scripts/practice_session.gd")
const TRAINING := preload("res://scripts/practice_training.gd")
const OUTPUT_DIR := "res://artifacts/screenshots"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))

	# A flat backdrop so the card's own contrast is what shows up in the PNG.
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.10, 0.16, 0.12)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(backdrop)

	var session := SESSION_SCRIPT.new() as PracticeSession
	root.add_child(session)
	session.begin(null, [] as Array[DummyBlob])

	var hud := PRACTICE_HUD.new() as PracticeHud
	root.add_child(hud)
	hud.bind_session(session)
	hud.set_practice_active(true)
	hud.set_weapon_label("Blaster + Rail Shot")

	# A plausible mid-run scoreline, so every row renders at realistic width.
	session.set_dummy_mode(TRAINING.MODE_STRAFE)
	for _shot in range(37):
		session.note_shot_fired()
	for _hit in range(29):
		session.note_dummy_hit(30)
	session.note_shot_missed()

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	await _capture(hud, "practice_hud_stats.png")
	hud.set_panel_open(true)
	await _capture(hud, "practice_hud_controls.png")

	print("PRACTICE HUD CAPTURE DONE")
	quit(0)


func _capture(hud: PracticeHud, file_name: String) -> void:
	for _warmup in range(8):
		await process_frame
	# Process frames advance even when the compositor skips presenting, so the
	# grab has to wait on the draw itself or it saves a stale frame.
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := "%s/%s" % [OUTPUT_DIR, file_name]
	image.save_png(path)
	print("wrote %s (%dx%d), panel_open=%s" % [path, image.get_width(), image.get_height(), str(hud.is_panel_open())])
