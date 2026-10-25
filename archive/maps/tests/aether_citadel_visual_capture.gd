extends SceneTree

const AETHER := preload("res://scenes/world/maps/sky_temple.tscn")
const OUTPUT_DIR := "res://artifacts/screenshots"

var _failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	root.size = Vector2i(1440, 900)
	var world := _make_world()
	root.add_child(world)
	var arena := AETHER.instantiate() as Node3D
	world.add_child(arena)
	await process_frame
	await process_frame
	_apply_profile(world, arena.call("get_lighting_profile") as Dictionary)
	var camera := world.get_node("Camera") as Camera3D
	# Blueprint comparison view: full 48 x 72 GU footprint in orthographic projection.
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 238.0
	camera.position = Vector3(0, 300, 0.1)
	camera.look_at(Vector3.ZERO, Vector3.FORWARD)
	await _settle_render()
	_save("aether_citadel_blueprint_overhead.png")
	# Three-quarter exterior read exposes wall layering, terraces, curved ramps, and roof height.
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.position = Vector3(142, 190, 238)
	camera.look_at(Vector3(0, 13, 0), Vector3.UP)
	camera.fov = 50
	await _settle_render()
	_save("aether_citadel_blueprint_wide.png")
	# Center composition validates the crown, pylon rhythm, wind arches, and low walls.
	camera.position = Vector3(92, 76, 124)
	camera.look_at(Vector3(0, 8, 0), Vector3.UP)
	camera.fov = 55
	await _settle_render()
	_save("aether_citadel_blueprint_center.png")
	# Low wall/roof profile confirms the 4 GU parapet and full-height stormglass enclosure.
	camera.position = Vector3(150, 38, 4)
	camera.look_at(Vector3(0, 25, 0), Vector3.UP)
	camera.fov = 54
	await _settle_render()
	_save("aether_citadel_wall_profile.png")
	world.queue_free()
	await process_frame
	if _failures == 0:
		print("AETHER CITADEL VISUAL CAPTURE PASS")
		quit(0)
		return
	quit(1)


func _make_world() -> Node3D:
	var world := Node3D.new()
	world.name = "AetherCaptureWorld"
	var world_environment := WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# Match the shipped look (main.tscn): ACES + adjustments, so captures
	# represent in-game color.
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_white = 6.0
	environment.adjustment_enabled = true
	environment.adjustment_saturation = 1.12
	environment.adjustment_contrast = 1.06
	world_environment.environment = environment
	world.add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 520.0
	world.add_child(sun)
	var camera := Camera3D.new()
	camera.name = "Camera"
	camera.current = true
	camera.near = 0.1
	camera.far = 1400.0
	world.add_child(camera)
	return world


func _apply_profile(world: Node3D, profile: Dictionary) -> void:
	var environment := (world.get_node("WorldEnvironment") as WorldEnvironment).environment
	var sky_material := environment.sky.sky_material as ProceduralSkyMaterial
	sky_material.sky_top_color = profile.get("sky_top", Color("3C77BE"))
	sky_material.sky_horizon_color = profile.get("sky_horizon", Color("D9F3FA"))
	environment.ambient_light_color = profile.get("ambient", Color("DCEAF1"))
	environment.ambient_light_energy = float(profile.get("ambient_energy", 0.62))
	environment.fog_enabled = false
	var sun := world.get_node("Sun") as DirectionalLight3D
	sun.light_color = profile.get("sun_color", Color("FFF3D2"))
	sun.light_energy = float(profile.get("sun_energy", 1.14))
	sun.rotation_degrees = profile.get("sun_rotation", Vector3(-48, -28, 0))
	sky_material.sun_angle_max = float(profile.get("sun_size", 20.0))


func _settle_render() -> void:
	await process_frame
	await process_frame
	await process_frame
	await create_timer(0.12).timeout


func _save(file_name: String) -> void:
	var texture := root.get_texture()
	if texture == null:
		_failures += 1
		push_error("Aether capture has no viewport texture")
		return
	var image := texture.get_image()
	if image == null:
		_failures += 1
		push_error("Aether capture has no image")
		return
	var path := "%s/%s" % [OUTPUT_DIR, file_name]
	var error := image.save_png(path)
	if error != OK:
		_failures += 1
		push_error("Could not save %s: %s" % [path, error_string(error)])
