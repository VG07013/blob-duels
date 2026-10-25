extends SceneTree

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const DUMMY_SCENE := preload("res://scenes/player/dummy_blob.tscn")

var failures: Array[String] = []
var world: Node3D
var player: RigidBody3D
var counted_bounces := 0


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _run() -> void:
	world = Node3D.new()
	root.add_child(world)
	_add_floor()
	player = PLAYER_SCENE.instantiate() as RigidBody3D
	world.add_child(player)
	player.configure_local(1)
	await _reset_player(Vector3(0, 3.0, 0))

	Input.action_press("move_forward")
	Input.action_press("move_left")
	await _physics_seconds(0.12)
	var early_speed := Vector2(player.linear_velocity.x, player.linear_velocity.z).length()
	await _physics_seconds(0.38)
	var mid_speed := Vector2(player.linear_velocity.x, player.linear_velocity.z).length()
	await _physics_seconds(0.90)
	Input.action_release("move_forward")
	Input.action_release("move_left")
	var diagonal_velocity := Vector2(player.linear_velocity.x, player.linear_velocity.z)
	_check(absf(diagonal_velocity.x) > 2.0 and absf(diagonal_velocity.y) > 2.0, "W+A does not accelerate on both axes")
	_check(absf(absf(diagonal_velocity.x) - absf(diagonal_velocity.y)) < 2.2, "Diagonal acceleration is not normalized")
	_check(early_speed < mid_speed and mid_speed < diagonal_velocity.length(), "Held movement does not build momentum over time")
	_check(early_speed < 14.0, "Base movement still reaches high speed too instantly")
	_check(diagonal_velocity.length() > 25.0, "Sustained movement does not build to a useful speed")
	var release_speed := diagonal_velocity.length()
	await _physics_seconds(0.18)
	var preserved_speed := Vector2(player.linear_velocity.x, player.linear_velocity.z).length()
	_check(preserved_speed >= release_speed * 0.68, "Releasing movement erases momentum")

	await _reset_player(Vector3(0, 3.0, 0))
	Input.action_press("move_forward")
	Input.action_press("move_back")
	await _physics_seconds(0.35)
	Input.action_release("move_forward")
	Input.action_release("move_back")
	_check(Vector2(player.linear_velocity.x, player.linear_velocity.z).length() < 1.2, "W+S does not cancel")

	await _reset_player(Vector3(0, 3.0, 0))
	player.linear_velocity = Vector3(0, 0, -36.0)
	Input.action_press("move_forward")
	await _physics_seconds(0.5)
	Input.action_release("move_forward")
	_check(-player.linear_velocity.z <= player.ground_control_speed + 0.5, "Ground input amplifies existing momentum beyond the controllable traversal band")
	_check(-player.linear_velocity.z >= 28.0, "Ground movement over-brakes useful existing momentum")

	await _reset_player(Vector3(0, 20.0, 24.0))
	player.gravity_scale = 0.0
	player.linear_velocity = Vector3(0, 0, -60.0)
	await _physics_seconds(0.75)
	_check(-player.linear_velocity.z < 60.0 and -player.linear_velocity.z > 40.0, "Air momentum must decay gradually instead of staying constant or stopping abruptly")

	player.linear_velocity = Vector3(0, 0, -60.0)
	Input.action_press("move_forward")
	await _physics_seconds(0.75)
	Input.action_release("move_forward")
	_check(-player.linear_velocity.z <= 60.0 and -player.linear_velocity.z > 40.0, "Held air input adds speed instead of only steering decaying momentum")

	player.linear_velocity = Vector3(0, 0, -60.0)
	player.set("_is_charging_fling", true)
	player.fling_charge = player.maximum_charge_time
	await _physics_seconds(0.5)
	_check(-player.linear_velocity.z <= 48.0, "Full fling charge does not apply its intentional movement drag")
	player.cancel_active_charge()
	player.gravity_scale = 1.0

	await _reset_player(Vector3(0, 3.0, 0))
	await _wait_for_bounce_ready()
	Input.action_press("bounce")
	await physics_frame
	Input.action_release("bounce")
	await physics_frame
	_check(player.linear_velocity.y > 7.0, "Ground bounce boost is not responsive")

	counted_bounces = 0
	player.bounce_counted.connect(_on_bounce_counted)
	var counted_surface := StaticBody3D.new()
	player.respawn(Vector3(0, 30.0, 24.0))
	player.gravity_scale = 0.0
	player.linear_velocity = Vector3(0, -20.0, 0)
	player.call("_on_body_entered", counted_surface)
	player.call("_on_body_entered", counted_surface)
	_check(counted_bounces == 1, "One surface contact is counted as more than one quest bounce")
	await _physics_seconds(0.13)
	player.call("_on_body_entered", counted_surface)
	_check(counted_bounces == 2, "A later bounce from the same surface is not counted")
	counted_surface.free()
	player.gravity_scale = 1.0

	var launch_speeds: Array[float] = []
	for charge in [0.05, 0.5, 1.0]:
		await _reset_player(Vector3(0, 6.0, 0))
		player.aim_direction = Vector3(0, 0, -1)
		player.call("_release_fling", charge)
		await physics_frame
		launch_speeds.append(-player.linear_velocity.z)
	_check(launch_speeds[0] < launch_speeds[1] and launch_speeds[1] < launch_speeds[2], "Fling launch velocities do not scale continuously")
	_check(launch_speeds[2] > 80.0, "Full charge does not send the blob shooting forward")

	_add_wall(Vector3(0, 5, -18), Vector3(24, 12, 2))
	await _reset_player(Vector3(0, 4.0, -4.0))
	player.gravity_scale = 0.0
	var bounce_count_before_wall := counted_bounces
	player.linear_velocity = Vector3(4, 0, -40)
	await _physics_seconds(0.75)
	_check(player.linear_velocity.z > 8.0, "High-speed wall impact does not ricochet")
	_check(player.linear_velocity.length() > 18.0 and player.linear_velocity.length() < 39.0, "Wall ricochet must retain useful direction while dissipating runaway energy")
	_check(counted_bounces >= bounce_count_before_wall + 1, "A real wall ricochet is not counted as a bounce")
	player.gravity_scale = 1.0

	var dummy := DUMMY_SCENE.instantiate() as RigidBody3D
	world.add_child(dummy)
	player.respawn(Vector3(-9, 4.0, 8))
	dummy.global_position = Vector3(9, 4.0, 8)
	dummy.linear_velocity = Vector3(-5, 0, 0)
	dummy.reset_physics_interpolation()
	player.linear_velocity = Vector3(34, 0, 0)
	await _physics_seconds(0.55)
	_check(dummy.linear_velocity.x > 24.0, "Fast blob collision does not launch the target")
	_check(dummy.linear_velocity.y > 2.0, "Fast blob collision does not add enough bouncy lift")
	_check(player.linear_velocity.x < 2.0, "Attacker does not receive equal-and-opposite reaction")

	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("PHYSICS INTEGRATION PASS: diagonals, cancellation, momentum, bounce, fling, ricochet, blob reaction")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _reset_player(position: Vector3) -> void:
	player.respawn(position)
	await _physics_seconds(0.28)
	player.linear_velocity = Vector3.ZERO
	player.angular_velocity = Vector3.ZERO


func _on_bounce_counted(_strength: float) -> void:
	counted_bounces += 1


func _physics_seconds(seconds: float) -> void:
	var frames := maxi(1, int(ceil(seconds * 60.0)))
	for _index in range(frames):
		await physics_frame


func _wait_for_bounce_ready() -> void:
	for _index in range(60):
		if bool(player.call("is_grounded")) and float(player.get("_bounce_cooldown_timer")) <= 0.0:
			return
		await physics_frame
	_check(false, "Player never became ready for a ground bounce")


func _add_floor() -> void:
	var floor := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(80, 2, 80)
	collision.shape = shape
	collision.position.y = -1.0
	floor.add_child(collision)
	world.add_child(floor)


func _add_wall(position: Vector3, size: Vector3) -> void:
	var wall := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	wall.position = position
	wall.add_child(collision)
	world.add_child(wall)
