extends SceneTree

const TOYBOX := preload("res://scenes/world/maps/toybox.tscn")
const OUTPUT_DIR := "res://artifacts/screenshots"

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	root.size = Vector2i(1280, 720)
	var world := _make_world()
	root.add_child(world)
	var arena := TOYBOX.instantiate() as Node3D
	world.add_child(arena)
	await process_frame
	await process_frame
	_apply_profile(world, arena.call("get_lighting_profile") as Dictionary)
	var camera := world.get_node("Camera") as Camera3D
	# Blueprint comparison: orthographic-like top-down framing with the complete
	# 64 x 128 footprint and canopy frame visible.
	camera.position = Vector3(0.0, 228.0, 0.1)
	camera.look_at(Vector3.ZERO, Vector3.FORWARD)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 202.0
	await _settle_render()
	_save("toybox_blueprint_overhead.png")
	# Three-quarter whole-map read shows depth, wall padding, roof height, and all
	# four symmetrical movement chains without flattening the authored models.
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.position = Vector3(91.0, 137.0, 157.0)
	camera.look_at(Vector3(0, 5.0, 0), Vector3.UP)
	camera.fov = 52.0
	await _settle_render()
	_save("toybox_blueprint_wide.png")
	# Center detail validates that the trampoline, beams, ramps, wedges, boxes,
	# and covers read as designed objects rather than unstyled primitives.
	camera.position = Vector3(58.0, 45.0, 74.0)
	camera.look_at(Vector3(0, 4.0, 0), Vector3.UP)
	camera.fov = 58.0
	await _settle_render()
	_save("toybox_blueprint_center.png")
	world.queue_free()
	await process_frame
	if _failures == 0:
		print("TOYBOX VISUAL CAPTURE PASS")
		quit(0)
		return
	quit(1)


func _make_world() -> Node3D:
	var world := Node3D.new()
	world.name = "ToyboxCaptureWorld"
	var world_environment := WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_environment.environment = environment
	world.add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 420.0
	world.add_child(sun)
	var camera := Camera3D.new()
	camera.name = "Camera"
	camera.current = true
	camera.near = 0.1
	camera.far = 1200.0
	world.add_child(camera)
	return world


func _apply_profile(world: Node3D, profile: Dictionary) -> void:
	var environment := (world.get_node("WorldEnvironment") as WorldEnvironment).environment
	var sky_material := environment.sky.sky_material as ProceduralSkyMaterial
	sky_material.sky_top_color = profile.get("sky_top", Color("A9D8F2"))
	sky_material.sky_horizon_color = profile.get("sky_horizon", Color("F4E9D2"))
	environment.ambient_light_color = profile.get("ambient", Color.WHITE)
	environment.ambient_light_energy = float(profile.get("ambient_energy", 0.76))
	environment.fog_enabled = false
	var sun := world.get_node("Sun") as DirectionalLight3D
	sun.light_color = profile.get("sun_color", Color.WHITE)
	sun.light_energy = float(profile.get("sun_energy", 1.12))
	sun.rotation_degrees = profile.get("sun_rotation", Vector3(-52, -34, 0))
	sky_material.sun_angle_max = float(profile.get("sun_size", 25.0))


func _settle_render() -> void:
	await process_frame
	await process_frame
	await process_frame
	await create_timer(0.08).timeout


func _save(file_name: String) -> void:
	var texture := root.get_texture()
	if texture == null:
		_failures += 1
		push_error("Toybox capture has no rendered viewport texture")
		return
	var image := texture.get_image()
	if image == null:
		_failures += 1
		push_error("Toybox capture has no rendered image")
		return
	var path := "%s/%s" % [OUTPUT_DIR, file_name]
	var error := image.save_png(path)
	if error != OK:
		_failures += 1
		push_error("Could not save %s: %s" % [path, error_string(error)])
