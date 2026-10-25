extends SceneTree

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

var failures: Array[String] = []
var world: Node3D
var player: RigidBody3D
var fling_charge_start_count := 0
var fling_release_count := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var brake_was_configured := InputMap.has_action("brake")
	_check(brake_was_configured, "A dedicated brake input action is missing")
	if not brake_was_configured:
		InputMap.add_action("brake")
	_check(_brake_uses_shift(), "Brake must be bound to Shift")

	world = Node3D.new()
	root.add_child(world)
	player = PLAYER_SCENE.instantiate() as RigidBody3D
	world.add_child(player)
	player.configure_local(1)
	player.fling_charge_started.connect(_on_fling_charge_started)
	player.fling_released.connect(_on_fling_released)
	await physics_frame

	_check(player.has_method("_apply_brake"), "Player is missing dedicated brake handling")
	if player.has_method("_apply_brake"):
		player.cancel_active_charge()
		player.linear_velocity = Vector3(36.0, 17.0, -18.0)
		var starting_planar_speed := _planar_speed()
		var starting_vertical_speed := player.linear_velocity.y
		Input.action_press("brake")
		player.call("_apply_brake", 0.35)
		player.call("_update_fling_charge", 0.35)
		Input.action_release("brake")

		_check(_planar_speed() < starting_planar_speed * 0.7, "Holding brake does not substantially slow horizontal movement")
		_check(is_equal_approx(player.linear_velocity.y, starting_vertical_speed), "Brake changes vertical movement")
		_check(player.get_charge_ratio() <= 0.001, "Brake builds fling charge")
		_check(fling_charge_start_count == 0, "Brake starts a fling charge")
		_check(fling_release_count == 0, "Releasing brake launches a fling")

		var released_velocity := player.linear_velocity
		player.call("_apply_brake", 0.35)
		_check(player.linear_velocity.is_equal_approx(released_velocity), "Brake keeps slowing movement after Shift is released")

		player.set("_is_charging_fling", true)
		player.linear_velocity = Vector3(12.0, 5.0, -9.0)
		var charging_velocity := player.linear_velocity
		Input.action_press("brake")
		player.call("_apply_brake", 0.35)
		Input.action_release("brake")
		_check(player.linear_velocity.is_equal_approx(charging_velocity), "Brake stacks extra drag onto an active fling charge")
		player.cancel_active_charge()

		player.gravity_scale = 0.0
		player.linear_velocity = Vector3(30.0, 0.0, 0.0)
		await _physics_seconds(0.25)
		var unbraked_physics_speed := _planar_speed()
		player.linear_velocity = Vector3(30.0, 0.0, 0.0)
		Input.action_press("brake")
		await _physics_seconds(0.25)
		Input.action_release("brake")
		_check(_planar_speed() < unbraked_physics_speed * 0.65, "Physics processing does not apply the held brake")

	Input.action_release("brake")
	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("PLAYER BRAKE CONTRACT PASS: Shift slows planar movement without charging or releasing a fling")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _brake_uses_shift() -> bool:
	if not InputMap.has_action("brake"):
		return false
	for event in InputMap.action_get_events("brake"):
		var key_event := event as InputEventKey
		if (
			key_event != null
			and (key_event.keycode == KEY_SHIFT or key_event.physical_keycode == KEY_SHIFT)
			and key_event.location != KeyLocation.KEY_LOCATION_RIGHT
		):
			return true
	return false


func _planar_speed() -> float:
	return Vector2(player.linear_velocity.x, player.linear_velocity.z).length()


func _physics_seconds(seconds: float) -> void:
	for _index in range(maxi(1, int(ceil(seconds * 60.0)))):
		await physics_frame


func _on_fling_released(_charge_ratio: float) -> void:
	fling_release_count += 1


func _on_fling_charge_started() -> void:
	fling_charge_start_count += 1


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
