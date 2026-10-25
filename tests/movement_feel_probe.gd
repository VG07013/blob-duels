extends SceneTree

## Telemetry only (excluded from the suite): drives a blob on an endless flat
## floor and prints time-to-speed, reversal time and coast-to-stop distance, so
## ground-movement tuning in player.gd can be compared before and after.



func _initialize() -> void:
	call_deferred("_run")


func _speed(p: RigidBody3D) -> float:
	return Vector2(p.linear_velocity.x, p.linear_velocity.z).length()


func _run() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.physics_material_override = load("res://assets/materials/physics/arena_normal.tres")
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4000, 2, 4000)
	shape.shape = box
	shape.position = Vector3(0, -1, 0)
	floor_body.add_child(shape)
	root.add_child(floor_body)
	var player := (load("res://scenes/player/player.tscn") as PackedScene).instantiate() as RigidBody3D
	root.add_child(player)
	await process_frame
	player.call("set_input_enabled", true)
	player.set("aim_yaw", 0.0)
	player.global_position = Vector3(0, 4, 0)
	player.linear_velocity = Vector3.ZERO
	for i in 120:
		await physics_frame
	# Accelerate forward (-Z) from rest.
	Input.action_press("move_forward")
	var t := 0.0
	var marks := {}
	var top := 0.0
	for i in 150:
		await physics_frame
		t += 1.0 / 60.0
		var s := _speed(player)
		top = maxf(top, s)
		for target in [10.0, 20.0, 30.0, 34.0, 36.0]:
			if s >= target and not marks.has(target):
				marks[target] = t
	print("ACCEL top %.1f after 2.5s; reach times %s" % [top, marks])
	# Reverse.
	Input.action_release("move_forward")
	Input.action_press("move_back")
	t = 0.0
	var reversed_at := -1.0
	for i in 120:
		await physics_frame
		t += 1.0 / 60.0
		if player.linear_velocity.z > 10.0 and reversed_at < 0.0:
			reversed_at = t
	print("REVERSE to +10 in %.2fs, speed after 2s %.1f" % [reversed_at, _speed(player)])
	# Release and coast.
	Input.action_release("move_back")
	var start := player.global_position
	t = 0.0
	var stop_at := -1.0
	for i in 240:
		await physics_frame
		t += 1.0 / 60.0
		if _speed(player) < 2.0 and stop_at < 0.0:
			stop_at = t
	print("STOP from coast: <2 u/s after %.2fs, slid %.1f" % [stop_at, (player.global_position - start).length()])
	quit(0)
