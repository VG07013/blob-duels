extends SceneTree

## BUG-026: fling did nothing.
##
## The fling cooldown system added `drag += post_fling_drag *
## get_fling_cooldown_ratio()` to the momentum decay. That ratio is 1.0 on the
## launch frame, so the anti-chaining drag hit at full strength exactly when the
## impulse landed and eased off as the cooldown burned down - backwards. The
## launch was damped hardest at t=0.
##
## Pins the corrected shape: the launch carries first, drag ramps in afterwards,
## and momentum has still bled off by the time another fling is available.

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

var failures: Array[String] = []
var player: RigidBody3D
var world: Node3D


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	world = Node3D.new()
	root.add_child(world)
	player = PLAYER_SCENE.instantiate() as RigidBody3D
	world.add_child(player)
	await physics_frame
	player.gravity_scale = 0.0

	# A full-charge fling must actually launch the blob.
	player.respawn(Vector3(0, 6.0, 0))
	await _physics_seconds(0.2)
	player.linear_velocity = Vector3.ZERO
	player.aim_direction = Vector3(0, 0, -1)
	player.call("_release_fling", 1.0)
	await physics_frame
	var launch_speed := -player.linear_velocity.z
	_check(launch_speed > 60.0, "A full-charge fling must launch the blob, got %.1f m/s" % launch_speed)

	# The carry window must preserve the launch rather than eating it instantly.
	await _physics_seconds(0.25)
	var carried_speed := -player.linear_velocity.z
	_check(
		carried_speed > launch_speed * 0.82,
		"Post-fling drag must not cancel the launch during the carry window (%.1f -> %.1f m/s)" % [launch_speed, carried_speed]
	)

	# ...but momentum must still decay, so flings do not chain.
	await _physics_seconds(2.4)
	var settled_speed := -player.linear_velocity.z
	_check(settled_speed < carried_speed, "Fling momentum must decay instead of persisting")
	_check(
		float(player.call("get_fling_cooldown_ratio")) < 0.2,
		"Fling cooldown must be nearly recovered after the cooldown duration"
	)

	# A charge that was legitimately started must not be silently swallowed on
	# release: the only thing that sets the cooldown is the release itself.
	player.respawn(Vector3(0, 6.0, 0))
	await _physics_seconds(0.2)
	player.linear_velocity = Vector3.ZERO
	player.aim_direction = Vector3(0, 0, -1)
	player.set("_is_charging_fling", true)
	player.fling_charge = player.maximum_charge_time
	player.call("_release_fling", 1.0)
	await physics_frame
	_check(-player.linear_velocity.z > 60.0, "A legitimately built charge must always launch on release")

	# The cooldown bar still drives off the same timer.
	_check(float(player.call("get_fling_cooldown_ratio")) > 0.9, "Releasing a fling must refill the cooldown bar")
	_check(not bool(player.call("is_fling_ready")), "Fling must be unavailable while the cooldown bar is draining")

	player.queue_free()
	await process_frame

	if failures.is_empty():
		print("FLING REGRESSION CONTRACT PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("FLING REGRESSION CONTRACT FAILURES: %d" % failures.size())
	quit(1)


func _physics_seconds(seconds: float) -> void:
	for _index in range(maxi(1, int(ceil(seconds * 60.0)))):
		await physics_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
