extends SceneTree

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

var failures: Array[String] = []
var world: Node3D
var player: RigidBody3D


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	world = Node3D.new()
	root.add_child(world)
	_add_floor()
	player = PLAYER_SCENE.instantiate() as RigidBody3D
	world.add_child(player)
	player.configure_local(1)
	await _reset_player(Vector3(0.0, 18.0, 0.0))

	# Air input may turn existing momentum, but must never add planar speed.
	player.gravity_scale = 0.0
	player.linear_velocity = Vector3(0.0, 0.0, -42.0)
	Input.action_press("move_right")
	var airborne_start_speed := _planar_speed()
	await _physics_seconds(0.75)
	Input.action_release("move_right")
	var airborne_end_speed := _planar_speed()
	_check(airborne_end_speed <= airborne_start_speed + 0.5, "Air steering adds horizontal momentum")
	_check(player.linear_velocity.x > 1.0, "Air steering cannot redirect existing momentum")

	# Gravity must continuously accelerate the fall rather than clamp to a floaty speed.
	await _reset_player(Vector3(0.0, 80.0, 0.0))
	player.gravity_scale = 1.0
	player.linear_velocity = Vector3.ZERO
	await _physics_seconds(0.35)
	var early_fall_speed := -player.linear_velocity.y
	await _physics_seconds(0.55)
	var later_fall_speed := -player.linear_velocity.y
	_check(early_fall_speed > 2.0 and later_fall_speed > early_fall_speed * 2.0, "Fall velocity does not accelerate under gravity")

	# A fling starts a three-second lockout and cannot be chained during it.
	await _reset_player(Vector3(0.0, 10.0, 0.0))
	player.gravity_scale = 0.0
	player.aim_direction = Vector3.FORWARD
	_check(player.can_fling(), "Fling is unavailable from a clean spawn")
	player.call("_release_fling", 1.0)
	var first_fling_speed := player.linear_velocity.length()
	_check(not player.can_fling(), "Fling remains usable immediately after launch")
	_check(absf(player.get_fling_cooldown_ratio() - 1.0) < 0.02, "Fling cooldown indicator does not start full")
	player.call("_release_fling", 1.0)
	_check(player.linear_velocity.length() <= first_fling_speed + 0.1, "Cooldown allows chained fling impulse")
	await _physics_seconds(1.5)
	_check(player.get_fling_cooldown_ratio() < 0.58 and player.get_fling_cooldown_ratio() > 0.38, "Fling cooldown does not deplete over three seconds")
	await _physics_seconds(1.65)
	_check(player.can_fling() and player.get_fling_cooldown_ratio() <= 0.001, "Fling does not unlock after three seconds")

	# Playtest-like launch: a full fling must be useful, bounded, and settle without input.
	await _reset_player(Vector3(0.0, 3.2, 0.0))
	player.gravity_scale = 1.0
	player.aim_direction = Vector3(0.0, 0.06, -1.0).normalized()
	player.call("_release_fling", 1.0)
	var peak_speed := player.linear_velocity.length()
	for _index in range(12 * 60):
		await physics_frame
		peak_speed = maxf(peak_speed, player.linear_velocity.length())
	var settled_fling_speed := _planar_speed()
	_check(peak_speed <= player.maximum_movement_speed + 1.0, "A fling or bounce exceeds the bounded movement speed")
	_check(settled_fling_speed < 9.0, "A single fling does not settle back toward normal movement")

	# Ground movement remains deliberate but reaches combat-useful speed after buildup.
	await _reset_player(Vector3(0.0, 3.2, 0.0))
	Input.action_press("move_forward")
	await _physics_seconds(0.18)
	var ground_early_speed := _planar_speed()
	await _physics_seconds(1.35)
	Input.action_release("move_forward")
	var ground_late_speed := _planar_speed()
	_check(ground_early_speed < 22.0, "Ground movement still launches at near-top speed")
	_check(ground_late_speed > ground_early_speed + 5.0, "Ground movement no longer builds useful momentum")
	_check(ground_late_speed <= player.ground_control_speed + 3.0, "Ground buildup overshoots the controllable traversal band")
	_check(ground_late_speed <= player.maximum_movement_speed + 0.1, "Ground buildup can exceed the movement speed bound")

	# Name must sit above the health bar, scale down, and disappear at range.
	var nameplate := player.get_node("Nameplate") as Node3D
	var name_label := player.get_node("Nameplate/Name") as Label3D
	var health_back := player.get_node("Nameplate/HealthBackground") as MeshInstance3D
	_check(name_label.position.y > health_back.position.y + 0.25, "Player name is not positioned above the health bar")
	_check(not name_label.fixed_size, "Name tag still uses oversized fixed screen-space rendering")
	player.update_nameplate_for_camera(player.global_position + Vector3(0.0, 0.0, 8.0))
	var near_scale := nameplate.scale.x
	player.update_nameplate_for_camera(player.global_position + Vector3(0.0, 0.0, 40.0))
	var far_scale := nameplate.scale.x
	_check(nameplate.visible and far_scale < near_scale, "Nameplate does not shrink with camera distance")
	player.update_nameplate_for_camera(player.global_position + Vector3(0.0, 0.0, 80.0))
	_check(not nameplate.visible, "Nameplate remains visible beyond its maximum readable distance")

	Input.action_release("move_forward")
	Input.action_release("move_right")
	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("MOVEMENT REWORK CONTRACT PASS: air %.1f->%.1f, fall %.1f->%.1f, fling peak %.1f settled %.1f, ground %.1f->%.1f" % [airborne_start_speed, airborne_end_speed, early_fall_speed, later_fall_speed, peak_speed, settled_fling_speed, ground_early_speed, ground_late_speed])
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _reset_player(position: Vector3) -> void:
	player.respawn(position)
	await _physics_seconds(0.25)
	player.linear_velocity = Vector3.ZERO
	player.angular_velocity = Vector3.ZERO


func _planar_speed() -> float:
	return Vector2(player.linear_velocity.x, player.linear_velocity.z).length()


func _physics_seconds(seconds: float) -> void:
	for _index in range(maxi(1, int(ceil(seconds * 60.0)))):
		await physics_frame


func _add_floor() -> void:
	var floor := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(180.0, 2.0, 180.0)
	collision.shape = shape
	collision.position.y = -1.0
	floor.add_child(collision)
	world.add_child(floor)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
