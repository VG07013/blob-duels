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
##
## Second "fling does nothing" report: a normal ~1s press only reached 14% of
## the 7s charge on a back-loaded curve and launched slower than plain rolling.
## A quick fling must now clearly out-pace rolling.

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

	# A quick press (about a second of charge) must launch well past rolling speed.
	for hold_seconds in [0.3, 1.0]:
		player.respawn(Vector3(0, 6.0, 0))
		await _physics_seconds(0.2)
		player.linear_velocity = Vector3.ZERO
		player.aim_direction = Vector3(0, 0, -1)
		player.call("_release_fling", hold_seconds / player.maximum_charge_time)
		await physics_frame
		var quick_speed := -player.linear_velocity.z
		_check(
			quick_speed > float(player.get("ground_control_speed")) * 1.25,
			"A %.1fs fling must launch well past rolling speed (%.0f), got %.1f m/s" % [hold_seconds, float(player.get("ground_control_speed")), quick_speed]
		)
	player.respawn(Vector3(0, 6.0, 0))
	await _physics_seconds(0.2)
	player.linear_velocity = Vector3.ZERO
	player.aim_direction = Vector3(0, 0, -1)
	player.call("_release_fling", 1.0)
	await physics_frame
	launch_speed = -player.linear_velocity.z

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

	# Releasing keeps accelerating the blob along the fling, harder with power.
	var peak_speeds: Array[float] = []
	for charge_ratio in [1.0 / 7.0, 1.0]:
		player.respawn(Vector3(0, 6.0, 0))
		await _physics_seconds(0.2)
		player.linear_velocity = Vector3.ZERO
		player.aim_direction = Vector3(0, 0, -1)
		player.call("_release_fling", charge_ratio)
		await physics_frame
		var release_speed := -player.linear_velocity.z
		var peak := release_speed
		for _frame in range(40):
			await physics_frame
			peak = maxf(peak, -player.linear_velocity.z)
		_check(peak > release_speed + 10.0, "A released fling must keep accelerating after the launch (%.1f -> %.1f m/s)" % [release_speed, peak])
		peak_speeds.append(peak)
	_check(peak_speeds[1] > 110.0, "A full-charge fling must thrust to high speed, got %.1f m/s" % peak_speeds[1])
	_check(peak_speeds[1] > peak_speeds[0] + 20.0, "Fling thrust must scale with charge (%.1f vs %.1f m/s)" % [peak_speeds[0], peak_speeds[1]])
	_check(peak_speeds[1] < 138.0, "Fling thrust must stay under the host's remote speed cap, got %.1f m/s" % peak_speeds[1])

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
