extends SceneTree

## Product rule: getting shot repeatedly must never juggle a blob helplessly
## into the air. Only the first hit of a chain can pop a grounded blob up;
## every other hit pushes sideways but adds no lift and never switches off the
## upward speed cap; and a rapid chain of hits has diminishing knockback.

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const COMBAT_TUNING := preload("res://scripts/combat_tuning.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var floor_body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(400, 2, 400)
	shape.shape = box
	floor_body.add_child(shape)
	floor_body.position = Vector3(0, -1, 0)
	world.add_child(floor_body)
	var blob := PLAYER_SCENE.instantiate() as RigidBody3D
	world.add_child(blob)
	blob.configure_local(1)
	blob.respawn(Vector3(0, 3.0, 0))
	for _i in 40:
		await physics_frame

	# A stream of shots from one side, at the real fire rate, for 3 seconds.
	var peak_height := blob.global_position.y
	var hit_interval := 10
	for frame in 180:
		if frame % hit_interval == 0:
			blob.receive_collision_impact(0, Vector3(1, 0.18, 0).normalized() * 60.0, true)
		await physics_frame
		peak_height = maxf(peak_height, blob.global_position.y)
	_expect(peak_height < COMBAT_TUNING.HIT_JUGGLE_MAX_HEIGHT, "Being shot repeatedly must not launch a blob into the air (peaked %.1f units up)" % peak_height)

	# Airborne hits add no lift.
	blob.respawn(Vector3(0, 30.0, 0))
	blob.gravity_scale = 0.0
	await physics_frame
	blob.linear_velocity = Vector3.ZERO
	blob.receive_collision_impact(0, Vector3(1, 0.18, 0).normalized() * 60.0, true)
	await physics_frame
	_expect(blob.linear_velocity.y <= 0.5, "A hit on an airborne blob must not push it higher (vy %.1f)" % blob.linear_velocity.y)
	_expect(absf(blob.linear_velocity.x) > 3.0, "A hit on an airborne blob must still knock it sideways")

	# Rapid hit chains lose knockback.
	blob.linear_velocity = Vector3.ZERO
	blob.set("_hit_chain_count", 0)
	blob.receive_collision_impact(0, Vector3(1, 0, 0) * 60.0, true)
	await physics_frame
	var first_push := blob.linear_velocity.x
	for _i in 4:
		blob.linear_velocity = Vector3.ZERO
		blob.receive_collision_impact(0, Vector3(1, 0, 0) * 60.0, true)
		await physics_frame
	_expect(blob.linear_velocity.x < first_push * 0.7, "A rapid chain of hits must have diminishing knockback (%.1f vs first %.1f)" % [blob.linear_velocity.x, first_push])

	# Body slams are not shots: they keep their full pop even mid-chain.
	blob.respawn(Vector3(0, 3.0, 0))
	blob.gravity_scale = 1.0
	for _i in 30:
		await physics_frame
	blob.receive_collision_impact(0, Vector3(1, 0, 0) * 60.0, true)
	blob.linear_velocity = Vector3.ZERO
	blob.receive_collision_impact(0, Vector3(1, 0, 0) * 120.0)
	await physics_frame
	_expect(blob.linear_velocity.y > 3.0, "A body slam must keep its pop even right after a shot")

	blob.queue_free()
	world.queue_free()
	await process_frame
	if _failures.is_empty():
		print("HIT JUGGLE CONTRACT PASS")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
