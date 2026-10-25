extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _run() -> void:
	var game := MAIN_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	game._start_practice_match()
	await process_frame
	var player := game.get_node("Player") as RigidBody3D
	var dummy := game.get_node("DummyStationA") as RigidBody3D
	# Open turf lane east of the platform: low enough that the knocked dummy
	# never reaches the 5 GU canopy, clear of cover blocks, pads, and ramps.
	dummy.global_position = Vector3(11.0, 3.2, 0)
	dummy.linear_velocity = Vector3.ZERO
	dummy.reset_physics_interpolation()
	# Practice dummies default to infinite health, so the damage path needs a
	# finite pool to be observable at all.
	dummy.set_health_preset(250)
	player.global_position = Vector3(23.0, 3.2, 0)
	player.linear_velocity = Vector3.ZERO
	player.reset_physics_interpolation()
	var shot_direction := (dummy.global_position - player.global_position).normalized()
	player.aim_direction = shot_direction
	var recoil_before := player.linear_velocity.dot(shot_direction)
	player.request_shot_for_test()
	await physics_frame
	var recoil_after := player.linear_velocity.dot(shot_direction)
	# Track the peak rise: a faster shot lands sooner, so a single sample at the
	# end of the window can catch the dummy already falling back from its pop.
	var peak_rise := -INF
	for frame in range(roundi(0.42 * Engine.physics_ticks_per_second)):
		await physics_frame
		peak_rise = maxf(peak_rise, dummy.linear_velocity.y)
	_check(dummy.health < dummy.max_health, "Projectile does not damage a dummy")
	_check(dummy.linear_velocity.length() > 18.0, "Projectile does not visibly launch a dummy")
	_check(peak_rise > 5.0, "Projectile hit does not pop the dummy into a bounce")
	_check(recoil_after < recoil_before - 1.0, "Shooting does not recoil the player")

	game._open_pause()
	await process_frame
	game._resume_from_pause()
	await _physics_seconds(0.22)
	_check(game.get_node("HUD/Crosshair").visible, "Crosshair does not return after pause")
	var projectile_count_before := game.get_node("Projectiles").get_child_count()
	player.request_shot_for_test()
	await physics_frame
	_check(game.get_node("Projectiles").get_child_count() > projectile_count_before, "Shooting does not return after pause/resume")

	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("SHOOTING INTEGRATION PASS: damage, knockback, recoil, pause recovery")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _physics_seconds(seconds: float) -> void:
	for _index in range(maxi(1, int(ceil(seconds * 60.0)))):
		await physics_frame
