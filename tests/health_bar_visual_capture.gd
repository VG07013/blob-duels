extends SceneTree

## BUG-025 verification. The bug lived entirely on the GPU - health_fill.scale
## was always correct in GDScript, and the billboard vertex path discarded it -
## so a headless assertion on .scale proves nothing. This renders the blob at a
## range of health values, measures the lit fill in *pixels*, and writes PNGs.
##
## Needs a rendering device: run WITHOUT --headless.
##   godot --path . --script res://tests/health_bar_visual_capture.gd

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const OUTPUT_DIR := "res://artifacts/screenshots"


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(960, 540))
	var world := Node3D.new()
	root.add_child(world)

	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.03, 0.06)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 1.0
	environment.environment = env
	world.add_child(environment)

	var blob := PLAYER_SCENE.instantiate() as RigidBody3D
	world.add_child(blob)
	blob.freeze = true
	blob.global_position = Vector3.ZERO

	var camera := Camera3D.new()
	world.add_child(camera)
	# Frame the nameplate bar, which sits ~4.65 units above the blob centre.
	camera.global_position = Vector3(0, 4.65, 12.0)
	camera.look_at(Vector3(0, 4.65, 0), Vector3.UP)
	camera.current = true

	for _warmup in range(12):
		await process_frame

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	print("BUG-025 health bar render check")
	print("health   scale.x   lit fill width (px)")
	var widths: Array[int] = []
	for health_value in [150, 112, 75, 37, 0]:
		blob.set("health", health_value)
		blob.call("_update_health_billboard")
		for _settle in range(4):
			await process_frame
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		var width := _measure_fill_width(image)
		widths.append(width)
		print("%6d   %.3f     %d" % [health_value, blob.get("health_fill").scale.x, width])
		image.save_png("%s/health_bar_%03d.png" % [ProjectSettings.globalize_path(OUTPUT_DIR), health_value])

	# Fused-bar check: from an oblique angle the two quads used to pivot apart.
	# Render one angled shot at half health for eyeballing alongside the sweep.
	blob.set("health", 75)
	blob.call("_update_health_billboard")
	camera.global_position = Vector3(9.0, 7.5, 9.0)
	camera.look_at(Vector3(0, 4.65, 0), Vector3.UP)
	for _settle in range(6):
		await process_frame
	await RenderingServer.frame_post_draw
	var angled := root.get_texture().get_image()
	angled.save_png("%s/health_bar_angled_075.png" % ProjectSettings.globalize_path(OUTPUT_DIR))
	print("angled fill width: %d px" % _measure_fill_width(angled))

	# Light backdrop makes the dark backing quad visible, so fill-inside-backing
	# alignment can actually be judged in the PNG.
	env.background_color = Color(0.82, 0.86, 0.9)
	camera.global_position = Vector3(6.0, 6.2, 10.5)
	camera.look_at(Vector3(0, 4.65, 0), Vector3.UP)
	for _settle in range(6):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/health_bar_fused_light.png" % ProjectSettings.globalize_path(OUTPUT_DIR))
	env.background_color = Color(0.02, 0.03, 0.06)

	var strictly_shrinking := true
	for index in range(1, widths.size()):
		if widths[index] >= widths[index - 1]:
			strictly_shrinking = false
	print("RENDERED FILL WIDTHS: %s" % str(widths))
	if strictly_shrinking and widths[0] > 0 and widths[widths.size() - 1] == 0:
		print("HEALTH BAR VISUAL CHECK PASS - the rendered bar depletes with health")
		quit(0)
		return
	push_error("Rendered health bar did not deplete: widths %s" % str(widths))
	quit(1)


## Counts the widest run of the fill's green on any scanline. The fill material
## is a saturated green (0.14, 0.95, 0.45); the dark background and the near
## black bar backing are nowhere near it.
func _measure_fill_width(image: Image) -> int:
	var best := 0
	for y in range(image.get_height()):
		var run := 0
		for x in range(image.get_width()):
			var pixel := image.get_pixel(x, y)
			if pixel.g > 0.45 and pixel.g > pixel.r * 1.6 and pixel.g > pixel.b * 1.6:
				run += 1
			else:
				best = maxi(best, run)
				run = 0
		best = maxi(best, run)
	return best
