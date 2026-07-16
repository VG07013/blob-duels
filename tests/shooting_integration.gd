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
	var dummy := game.get_node("DummyRose") as RigidBody3D
	dummy.global_position = Vector3(0, 14.0, 0)
	dummy.linear_velocity = Vector3.ZERO
	dummy.reset_physics_interpolation()
	player.global_position = Vector3(0, 14.0, 25.0)
	player.linear_velocity = Vector3.ZERO
	player.reset_physics_interpolation()
	var shot_direction := (dummy.global_position - player.global_position).normalized()
	player.aim_direction = shot_direction
	var recoil_before := player.linear_velocity.dot(shot_direction)
	player.request_shot_for_test()
	await physics_frame
	var recoil_after := player.linear_velocity.dot(shot_direction)
	await _physics_seconds(0.42)
	_check(dummy.health < dummy.max_health, "Projectile does not damage a dummy")
	_check(dummy.linear_velocity.length() > 18.0, "Projectile does not visibly launch a dummy")
	_check(dummy.linear_velocity.y > 5.0, "Projectile hit does not pop the dummy into a bounce")
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
