extends SceneTree

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

var failures: Array[String] = []
var world: Node3D
var player: RigidBody3D


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	world = Node3D.new()
	root.add_child(world)
	_add_box_body(Vector3(0.0, -1.0, 0.0), Vector3(120.0, 2.0, 120.0))
	_add_box_body(Vector3(-58.0, 13.0, 0.0), Vector3(4.0, 28.0, 120.0))
	_add_box_body(Vector3(58.0, 13.0, 0.0), Vector3(4.0, 28.0, 120.0))
	_add_box_body(Vector3(0.0, 13.0, -58.0), Vector3(120.0, 28.0, 4.0))
	_add_box_body(Vector3(0.0, 13.0, 58.0), Vector3(120.0, 28.0, 4.0))

	player = PLAYER_SCENE.instantiate() as RigidBody3D
	world.add_child(player)
	player.configure_local(1)
	await physics_frame

	await _test_air_control_does_not_accelerate()
	await _test_gravity_accelerates_fall()
	await _test_fling_cooldown()
	await _test_single_fling_settles()

	_release_movement_actions()
	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("PRIORITY MOVEMENT REGRESSION PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _test_air_control_does_not_accelerate() -> void:
	await _reset_player(Vector3(0.0, 80.0, 0.0))
	player.linear_velocity = Vector3(0.0, 0.0, -48.0)
	Input.action_press("move_forward")
	await _physics_seconds(0.75)
	Input.action_release("move_forward")
	var same_direction_speed := _horizontal_speed()
	_check(same_direction_speed <= 48.5, "Air input in the travel direction adds horizontal momentum")
	_check(same_direction_speed < 47.5, "Airborne horizontal momentum does not decay over time")

	await _reset_player(Vector3(0.0, 80.0, 0.0))
	player.linear_velocity = Vector3(0.0, 0.0, -40.0)
	Input.action_press("move_right")
	await _physics_seconds(0.75)
	Input.action_release("move_right")
	_check(_horizontal_speed() <= 40.5, "Air steering increases total horizontal speed")
	_check(absf(player.linear_velocity.x) >= 2.0, "Air input cannot redirect the blob's heading")


func _test_gravity_accelerates_fall() -> void:
	await _reset_player(Vector3(0.0, 100.0, 0.0))
	player.linear_velocity = Vector3.ZERO
	await _physics_seconds(0.25)
	var first_velocity := player.linear_velocity.y
	await _physics_seconds(0.25)
	var second_velocity := player.linear_velocity.y
	await _physics_seconds(0.25)
	var third_velocity := player.linear_velocity.y
	_check(first_velocity < -0.5, "Gravity does not begin accelerating the blob downward")
	_check(second_velocity < first_velocity - 0.5, "Fall speed stays constant during the second gravity sample")
	_check(third_velocity < second_velocity - 0.5, "Fall speed stays constant during the third gravity sample")


func _test_fling_cooldown() -> void:
	var required_methods := ["is_fling_ready", "get_fling_cooldown_ratio"]
	for method_name in required_methods:
		if not player.has_method(method_name):
			_check(false, "Player is missing the %s cooldown contract" % method_name)
	if not player.has_method("is_fling_ready") or not player.has_method("get_fling_cooldown_ratio"):
		return

	await _reset_player(Vector3(0.0, 8.0, 0.0))
	player.aim_direction = Vector3.FORWARD
	player.call("_release_fling", 1.0)
	await physics_frame
	var initial_ratio := float(player.call("get_fling_cooldown_ratio"))
	_check(not bool(player.call("is_fling_ready")), "Fling remains usable immediately after launch")
	_check(initial_ratio >= 0.94 and initial_ratio <= 1.0, "Fling cooldown does not begin with a full depleting bar")
	var launched_velocity := player.linear_velocity
	player.call("_release_fling", 1.0)
	await physics_frame
	_check(player.linear_velocity.distance_to(launched_velocity) < 3.0, "A second fling can launch during the three-second cooldown")

	await _physics_seconds(1.45)
	var middle_ratio := float(player.call("get_fling_cooldown_ratio"))
	_check(middle_ratio < initial_ratio and middle_ratio > 0.35, "Fling cooldown ratio does not deplete monotonically over time")
	await _physics_seconds(1.7)
	_check(bool(player.call("is_fling_ready")), "Fling is still locked after the three-second cooldown")
	_check(float(player.call("get_fling_cooldown_ratio")) <= 0.01, "Fling cooldown bar is not empty when fling becomes ready")


func _test_single_fling_settles() -> void:
	await _reset_player(Vector3(0.0, 4.5, 0.0))
	if player.has_method("is_fling_ready"):
		for _index in range(240):
			if bool(player.call("is_fling_ready")):
				break
			await physics_frame
	player.aim_direction = Vector3(0.72, 0.0, -0.69).normalized()
	player.call("_release_fling", 1.0)
	var peak_speed := _horizontal_speed()
	var late_peak := 0.0
	for frame_index in range(12 * 60):
		await physics_frame
		var speed := _horizontal_speed()
		peak_speed = maxf(peak_speed, speed)
		if frame_index >= 8 * 60:
			late_peak = maxf(late_peak, speed)
	var final_speed := _horizontal_speed()
	_check(peak_speed <= 160.0, "A full fling exceeds the bounded gameplay speed cap")
	_check(late_peak < peak_speed * 0.55, "Fling/bounce momentum keeps chaining near its launch peak")
	_check(final_speed <= 30.0, "A single fling does not settle back to controllable movement")


func _reset_player(position: Vector3) -> void:
	_release_movement_actions()
	player.respawn(position)
	await _physics_seconds(0.08)
	player.linear_velocity = Vector3.ZERO
	player.angular_velocity = Vector3.ZERO


func _physics_seconds(seconds: float) -> void:
	for _index in range(maxi(1, int(ceil(seconds * 60.0)))):
		await physics_frame


func _horizontal_speed() -> float:
	return Vector2(player.linear_velocity.x, player.linear_velocity.z).length()


func _release_movement_actions() -> void:
	for action_name in ["move_forward", "move_back", "move_left", "move_right", "charge_fling"]:
		Input.action_release(action_name)


func _add_box_body(position: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = position
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	world.add_child(body)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
