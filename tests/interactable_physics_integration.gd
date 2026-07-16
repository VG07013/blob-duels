extends SceneTree

const LAUNCH_PAD := preload("res://scenes/interactables/launch_pad.tscn")
const WIND_ZONE := preload("res://scenes/interactables/wind_zone.tscn")
const CONVEYOR := preload("res://scenes/interactables/conveyor.tscn")
const BUMPER := preload("res://scenes/interactables/rotating_bumper.tscn")
const MOVING_PLATFORM := preload("res://scenes/interactables/moving_platform.tscn")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var body := _make_body()
	root.add_child(body)
	await physics_frame
	var audio_manager := root.get_node("AudioManager")

	var launch_pad := LAUNCH_PAD.instantiate()
	root.add_child(launch_pad)
	launch_pad.call("configure", Vector3(0.0, 0.7, -1.0), 54.0, Color.CYAN)
	var sfx_before := audio_manager.get_child_count()
	_expect(launch_pad.call("activate_body", body), "launch pad accepts a live rigid body")
	await physics_frame
	_expect(body.linear_velocity.y > 5.0 and body.linear_velocity.z < -5.0, "launch pad applies a directional launch impulse")
	_expect(audio_manager.get_child_count() > sfx_before, "launch pad triggers launch audio")

	body.linear_velocity = Vector3.ZERO
	var wind_zone := WIND_ZONE.instantiate()
	root.add_child(wind_zone)
	wind_zone.call("configure", Vector3(12, 10, 24), Vector3.RIGHT, 92.0, Color.SKY_BLUE)
	wind_zone.call("_on_body_entered", body)
	await physics_frame
	await physics_frame
	_expect(body.linear_velocity.x > 0.1, "wind zone applies sustained force")
	_expect(audio_manager.call("is_loop_playing", StringName("wind_%d" % wind_zone.get_instance_id())), "wind zone starts local wind audio")
	wind_zone.call("_on_body_exited", body)

	body.linear_velocity = Vector3.ZERO
	var conveyor := CONVEYOR.instantiate()
	root.add_child(conveyor)
	conveyor.call("configure", Vector3(14, 1, 28), Vector3.BACK, 68.0, Color.ORANGE)
	conveyor.call("_on_body_entered", body)
	await physics_frame
	await physics_frame
	_expect(body.linear_velocity.z > 0.1, "conveyor applies sustained directional force")
	_expect(audio_manager.call("is_loop_playing", StringName("machinery_%d" % conveyor.get_instance_id())), "conveyor starts machinery audio")
	conveyor.call("_on_body_exited", body)

	body.linear_velocity = Vector3.ZERO
	var bumper := BUMPER.instantiate()
	root.add_child(bumper)
	body.global_position = bumper.global_position + Vector3(5.0, 0.0, 0.0)
	sfx_before = audio_manager.get_child_count()
	_expect(bumper.call("activate_body", body), "rotating bumper accepts a live rigid body")
	await physics_frame
	_expect(body.linear_velocity.length() > 3.0 and body.linear_velocity.y > 0.0, "rotating bumper flings the body tangentially and upward")
	_expect(audio_manager.get_child_count() > sfx_before, "rotating bumper triggers impact audio")

	var moving_platform := MOVING_PLATFORM.instantiate()
	root.add_child(moving_platform)
	moving_platform.call("configure", Vector3(12, 1.2, 8), Vector3(0, 10, 0), 4.0, Color.GOLD, 0.0)
	var start_position: Vector3 = moving_platform.position
	moving_platform.call("_physics_process", 1.0)
	await physics_frame
	_expect(moving_platform.position.distance_to(start_position) > 1.0, "moving platform traverses its configured route")

	for node in [launch_pad, wind_zone, conveyor, bumper, moving_platform, body]:
		node.queue_free()
	await process_frame
	if _failures.is_empty():
		print("INTERACTABLE PHYSICS INTEGRATION PASS")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _make_body() -> RigidBody3D:
	var body := RigidBody3D.new()
	body.mass = 2.0
	body.gravity_scale = 0.0
	body.collision_layer = 2
	body.collision_mask = 1
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 2.0
	collision.shape = shape
	body.add_child(collision)
	return body


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
