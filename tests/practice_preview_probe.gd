extends SceneTree

## Scratch renderer for the holo facility - wide + per-zone shots with the
## map's own lighting profile. _probe suffix keeps it out of the suite.
## Run WITHOUT --headless.

const PRACTICE := preload("res://scenes/world/practice_arena.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var world := Node3D.new()
	root.add_child(world)
	var arena := PRACTICE.instantiate() as Node3D
	world.add_child(arena)
	await process_frame

	var profile := arena.call("get_lighting_profile") as Dictionary
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = profile["sky_top"]
	sky_material.sky_horizon_color = profile["sky_horizon"]
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = profile["ambient"]
	environment.ambient_light_energy = profile["ambient_energy"]
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_white = 6.0
	environment.adjustment_enabled = true
	environment.adjustment_saturation = 1.12
	environment.adjustment_contrast = 1.06
	environment.glow_enabled = true
	environment.glow_intensity = float(profile["glow_intensity"])
	environment.glow_strength = float(profile["glow_strength"])
	environment.glow_bloom = float(profile["glow_bloom"])
	environment.fog_enabled = true
	environment.fog_light_color = profile["fog"]
	environment.fog_light_energy = profile["fog_energy"]
	environment.fog_density = profile["fog_density"]
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	world.add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = profile["sun_rotation"]
	sun.light_color = profile["sun_color"]
	sun.light_energy = profile["sun_energy"]
	sun.shadow_enabled = true
	world.add_child(sun)
	var camera := Camera3D.new()
	camera.far = 2000.0
	world.add_child(camera)
	camera.current = true

	var shots := [
		{"name": "holo_wide", "from": Vector3(118, 46, 132), "at": Vector3(-20, 4, -20)},
		{"name": "holo_hub", "from": Vector3(30, 12, 42), "at": Vector3(0, 8, 0)},
		{"name": "holo_fling_range", "from": Vector3(-4, 7, -40), "at": Vector3(-100, 6, -40)},
		{"name": "holo_towers", "from": Vector3(-62, 26, -62), "at": Vector3(0, 14, -112)},
		{"name": "holo_gallery", "from": Vector3(66, 20, 96), "at": Vector3(120, 4, 45)},
	]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/screenshots"))
	for shot in shots:
		camera.global_position = shot["from"]
		camera.look_at(shot["at"] as Vector3, Vector3.UP)
		for _settle in range(14):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://artifacts/screenshots/%s.png" % shot["name"]))
		print("saved %s" % shot["name"])
	quit(0)
