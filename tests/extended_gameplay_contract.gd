extends SceneTree

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

var failures: Array[String] = []
var player: RigidBody3D


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _run() -> void:
	player = PLAYER_SCENE.instantiate() as RigidBody3D
	root.add_child(player)
	player.configure_local(1)
	player.gravity_scale = 0.0
	await process_frame

	_check_input(["move_forward"], Vector2(0.0, -1.0), "W")
	_check_input(["move_back"], Vector2(0.0, 1.0), "S")
	_check_input(["move_left"], Vector2(-1.0, 0.0), "A")
	_check_input(["move_right"], Vector2(1.0, 0.0), "D")
	_check_diagonal(["move_forward", "move_left"], Vector2(-1.0, -1.0), "W+A")
	_check_diagonal(["move_forward", "move_right"], Vector2(1.0, -1.0), "W+D")
	_check_diagonal(["move_back", "move_left"], Vector2(-1.0, 1.0), "S+A")
	_check_diagonal(["move_back", "move_right"], Vector2(1.0, 1.0), "S+D")
	_check_input(["move_forward", "move_back"], Vector2.ZERO, "W+S")
	_check_input(["move_left", "move_right"], Vector2.ZERO, "A+D")

	_release_all_movement()
	player.respawn(Vector3(0.0, 20.0, 0.0))
	player.gravity_scale = 0.0
	Input.action_press("move_right")
	await _physics_frames(24)
	Input.action_release("move_right")
	_check(player.linear_velocity.x > 0.5, "Air steering does not produce useful lateral control")

	player.linear_velocity = Vector3.ZERO
	player.set("_coyote_timer", 0.08)
	player.set("_bounce_buffer_timer", 0.08)
	player.set("_bounce_cooldown_timer", 0.0)
	player.call("_update_bounce_input")
	await physics_frame
	_check(player.linear_velocity.y > 5.0, "Coyote-time bounce does not launch the blob")

	player.linear_velocity = Vector3.ZERO
	player.set("_coyote_timer", 0.0)
	player.set("_bounce_buffer_timer", 0.09)
	player.set("_bounce_cooldown_timer", 0.0)
	player.call("_update_bounce_input")
	_check(player.linear_velocity.length() < 0.01, "Buffered bounce incorrectly creates an air jump")
	player.set("_coyote_timer", 0.12)
	player.call("_update_bounce_input")
	await physics_frame
	_check(player.linear_velocity.y > 5.0, "Buffered bounce does not fire when ground becomes available")

	var strengths: Array[float] = []
	for ratio in [0.0, 0.25, 0.5, 0.75, 1.0]:
		strengths.append(player.calculate_fling_strength(ratio))
	for index in range(1, strengths.size()):
		_check(strengths[index] > strengths[index - 1], "Fling charge tiers are not continuously increasing")
	_check(is_equal_approx(player.maximum_charge_time, 7.0), "Fling charge does not take 7 seconds to max")
	_check(strengths[4] >= 300.0, "Full-charge fling impulse is not a dramatic blast")

	player.set("_is_charging_fling", true)
	for sample in [[0.25, 1.0], [0.5, 0.75], [1.0, 0.5]]:
		player.fling_charge = player.maximum_charge_time * float(sample[0])
		_check(absf(float(player.call("_charge_control_multiplier")) - float(sample[1])) < 0.015, "Charge movement reduction is wrong at %d%%" % int(float(sample[0]) * 100.0))
	player.cancel_active_charge()

	player.linear_velocity = Vector3.ZERO
	player.aim_direction = Vector3(0.0, -1.0, 0.0)
	player.call("_release_fling", 1.0)
	await physics_frame
	_check(player.linear_velocity.y < -45.0, "Full 3D aim cannot fling steeply downward")
	_check(not player.has_node("VisualRoot/AimMarker"), "Player blob still has the protruding aim marker")

	_check(InputMap.has_action("toggle_camera"), "F5 camera toggle action is missing")
	var has_f5 := false
	for event in InputMap.action_get_events("toggle_camera"):
		var key := event as InputEventKey
		if key != null and key.keycode == KEY_F5:
			has_f5 = true
	_check(has_f5, "Third-person toggle is not mapped to F5")
	var r_is_bound := false
	for action in InputMap.get_actions():
		for event in InputMap.action_get_events(action):
			var key := event as InputEventKey
			if key != null and (key.keycode == KEY_R or key.physical_keycode == KEY_R):
				r_is_bound = true
	_check(not r_is_bound, "R must not trigger a gameplay action")

	_release_all_movement()
	player.queue_free()
	await process_frame
	if failures.is_empty():
		print("EXTENDED GAMEPLAY CONTRACT PASS: inputs, air, bounce buffer, fling curve, 3D aim, F5, no R")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _check_input(actions: Array[String], expected: Vector2, label: String) -> void:
	_release_all_movement()
	for action in actions:
		Input.action_press(action)
	var actual: Vector2 = player.get_movement_input()
	_check(actual.distance_to(expected) < 0.01, "%s input is incorrect" % label)


func _check_diagonal(actions: Array[String], direction: Vector2, label: String) -> void:
	_release_all_movement()
	for action in actions:
		Input.action_press(action)
	var actual: Vector2 = player.get_movement_input()
	_check(absf(actual.length() - 1.0) < 0.001, "%s diagonal is not normalized" % label)
	_check(actual.dot(direction.normalized()) > 0.999, "%s diagonal points in the wrong direction" % label)


func _release_all_movement() -> void:
	for action in ["move_forward", "move_back", "move_left", "move_right"]:
		Input.action_release(action)


func _physics_frames(count: int) -> void:
	for _index in range(count):
		await physics_frame
