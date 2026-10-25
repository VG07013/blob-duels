extends SceneTree

## Guards how remote blobs are rendered from host-stamped snapshots: the blob
## sits INTERPOLATION_DELAY_MSEC behind the host clock between the two
## bracketing snapshots, coasts on velocity for at most MAX_EXTRAPOLATION_MSEC
## when packets stop, and snaps instead of sliding across a respawn or blink.

const BUFFER := preload("res://scripts/net/remote_snapshot_buffer.gd")
const TUNING := preload("res://scripts/net/network_tuning.gd")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _run() -> void:
	_test_tuning_is_sane()
	_test_interpolates_between_bracketing_snapshots()
	_test_extrapolation_is_capped()
	_test_stale_packets_are_dropped()
	_test_teleport_snaps()
	_test_rotation_takes_the_short_way()
	_test_host_time_estimate()
	await _test_player_renders_at_delayed_time()
	_finish()


func _filled_buffer() -> RemoteSnapshotBuffer:
	# 30 Hz-ish cadence, constant 30 u/s along +X.
	var buffer := BUFFER.new() as RemoteSnapshotBuffer
	buffer.push(Vector3(0.0, 0.0, 0.0), Vector3.ZERO, Vector3(30.0, 0.0, 0.0), 0, 0)
	buffer.push(Vector3(1.0, 0.0, 0.0), Vector3.ZERO, Vector3(30.0, 0.0, 0.0), 33, 33)
	buffer.push(Vector3(2.0, 0.0, 0.0), Vector3.ZERO, Vector3(30.0, 0.0, 0.0), 66, 66)
	buffer.push(Vector3(3.0, 0.0, 0.0), Vector3.ZERO, Vector3(30.0, 0.0, 0.0), 100, 100)
	return buffer


func _test_tuning_is_sane() -> void:
	_check(TUNING.INTERPOLATION_DELAY_MSEC >= 66 and TUNING.INTERPOLATION_DELAY_MSEC <= 150, "Remote blobs render roughly 100 ms behind the host so one lost packet is bridged")
	_check(TUNING.MAX_EXTRAPOLATION_MSEC >= 100 and TUNING.MAX_EXTRAPOLATION_MSEC <= 200, "Velocity extrapolation must stop after roughly 150 ms")
	_check(TUNING.TELEPORT_SPEED > 138.0, "The teleport threshold must sit above the host's remote speed cap so real movement never snaps")


func _test_interpolates_between_bracketing_snapshots() -> void:
	var buffer := _filled_buffer()
	var empty := BUFFER.new() as RemoteSnapshotBuffer
	_check(empty.sample(50).mode == RemoteSnapshotBuffer.Mode.EMPTY, "An empty buffer must report EMPTY rather than invent a position")

	var sample := buffer.sample(50)
	_check(sample.mode == RemoteSnapshotBuffer.Mode.INTERPOLATE, "A render time between two snapshots must interpolate")
	var expected_x := 1.0 + (50.0 - 33.0) / (66.0 - 33.0)
	_check(is_equal_approx(sample.position.x, expected_x), "Interpolation must place the blob proportionally between the bracketing snapshots (got %.3f, want %.3f)" % [sample.position.x, expected_x])
	_check(is_equal_approx(sample.velocity.x, 30.0), "Interpolation must carry the snapshot velocity through")
	_check(buffer.size() == 3, "Snapshots older than the left-hand bracket must be pruned")

	var start := _filled_buffer().sample(-10)
	_check(start.mode == RemoteSnapshotBuffer.Mode.SNAP and is_equal_approx(start.position.x, 0.0), "A render time before the first snapshot must hold at that snapshot")


func _test_extrapolation_is_capped() -> void:
	var buffer := _filled_buffer()
	var coasting := buffer.sample(200)
	_check(coasting.mode == RemoteSnapshotBuffer.Mode.EXTRAPOLATE, "A render time past the newest snapshot must extrapolate while within the cap")
	_check(is_equal_approx(coasting.position.x, 3.0 + 30.0 * 0.1), "Extrapolation must advance the last snapshot along its velocity")
	var cap_seconds := float(TUNING.MAX_EXTRAPOLATION_MSEC) / 1000.0
	var held := buffer.sample(100 + TUNING.MAX_EXTRAPOLATION_MSEC + 1)
	_check(held.mode == RemoteSnapshotBuffer.Mode.HOLD, "Past the extrapolation cap the blob must hold instead of drifting")
	_check(is_equal_approx(held.position.x, 3.0 + 30.0 * cap_seconds), "The held position must be exactly the capped extrapolation")
	var much_later := buffer.sample(2000)
	_check(is_equal_approx(much_later.position.x, held.position.x), "Holding must not keep advancing however long packets stay away")
	_check(buffer.size() == 1, "Extrapolation must keep only the newest snapshot")


func _test_stale_packets_are_dropped() -> void:
	var buffer := _filled_buffer()
	buffer.push(Vector3(9.0, 0.0, 0.0), Vector3.ZERO, Vector3.ZERO, 90, 120)
	_check(buffer.size() == 4, "A snapshot older than the newest one must be ignored (unreliable delivery reorders)")
	_check(is_equal_approx(buffer.latest().position.x, 3.0), "A stale snapshot must not replace the newest state")


func _test_teleport_snaps() -> void:
	var buffer := BUFFER.new() as RemoteSnapshotBuffer
	buffer.push(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, 0, 0)
	buffer.push(Vector3(4.0, 0.0, 0.0), Vector3.ZERO, Vector3.ZERO, 33, 33)
	_check(buffer.size() == 2 and not buffer.consume_teleport(), "Movement under the teleport speed must interpolate normally (4 u in 33 ms)")

	buffer.push(Vector3(4.0 + TUNING.TELEPORT_DISTANCE, 0.0, 0.0), Vector3.ZERO, Vector3.ZERO, 66, 66)
	_check(buffer.size() == 1, "A jump past TELEPORT_DISTANCE must discard the history so nothing slides across it")
	_check(buffer.consume_teleport(), "A teleport must be reported once so the renderer can skip smoothing")
	_check(not buffer.consume_teleport(), "The teleport flag must clear after being consumed")
	var snapped := buffer.sample(40)
	_check(snapped.mode == RemoteSnapshotBuffer.Mode.SNAP and is_equal_approx(snapped.position.x, 4.0 + TUNING.TELEPORT_DISTANCE), "After a teleport the delayed render time must snap to the new position")

	var fast := BUFFER.new() as RemoteSnapshotBuffer
	fast.push(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, 0, 0)
	var blink_distance := (TUNING.TELEPORT_SPEED + 20.0) * 0.033
	fast.push(Vector3(blink_distance, 0.0, 0.0), Vector3.ZERO, Vector3.ZERO, 33, 33)
	_check(fast.size() == 1 and fast.consume_teleport(), "A short hop faster than TELEPORT_SPEED (a blink) must snap rather than slide")


func _test_rotation_takes_the_short_way() -> void:
	var buffer := BUFFER.new() as RemoteSnapshotBuffer
	buffer.push(Vector3.ZERO, Vector3(0.0, 3.0, 0.0), Vector3.ZERO, 0, 0)
	buffer.push(Vector3.ZERO, Vector3(0.0, -3.0, 0.0), Vector3.ZERO, 100, 100)
	var sample := buffer.sample(50)
	_check(absf(absf(sample.rotation.y) - PI) < 0.01, "Rotation must interpolate across the wrap-around instead of spinning the long way")


func _test_host_time_estimate() -> void:
	var buffer := BUFFER.new() as RemoteSnapshotBuffer
	_check(buffer.estimate_host_time_msec(500) == 500, "Without snapshots the host clock estimate must fall back to local time")
	buffer.push(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, 10000, 500)
	_check(buffer.estimate_host_time_msec(600) == 10100, "Before ping sync the host clock is estimated from the newest snapshot's arrival")


func _test_player_renders_at_delayed_time() -> void:
	var player := PLAYER_SCENE.instantiate()
	root.add_child(player)
	await process_frame
	player.configure_remote(2, Color(1.0, 0.3, 0.4))
	player.global_position = Vector3(100.0, 100.0, 100.0)
	player.apply_network_state(Vector3(0.0, 5.0, 0.0), Vector3.ZERO, Vector3(30.0, 0.0, 0.0), 100, Vector3.FORWARD, 1000)
	player.apply_network_state(Vector3(1.0, 5.0, 0.0), Vector3.ZERO, Vector3(30.0, 0.0, 0.0), 100, Vector3.FORWARD, 1033)
	player.apply_network_state(Vector3(2.0, 5.0, 0.0), Vector3.ZERO, Vector3(30.0, 0.0, 0.0), 100, Vector3.FORWARD, 1066)
	player._apply_remote_sample(1050)
	var expected_x := 1.0 + (1050.0 - 1033.0) / 33.0
	_check(is_equal_approx(player.global_position.x, expected_x) and is_equal_approx(player.global_position.y, 5.0), "A remote blob must render at the interpolated position for the delayed host time")
	_check(is_equal_approx(player.linear_velocity.x, 30.0), "A remote blob must carry the interpolated velocity for trails and animation")
	_check(int(player.get("_remote_snapshots").size()) == 2, "The remote blob must keep only the snapshots that can still bracket the render time")

	player.apply_network_state(Vector3(50.0, 5.0, 0.0), Vector3.ZERO, Vector3.ZERO, 100, Vector3.FORWARD, 1100)
	player._apply_remote_sample(1040)
	_check(is_equal_approx(player.global_position.x, 50.0), "A respawn-sized jump must snap the remote blob instead of sliding it across the arena")

	player.apply_network_state(Vector3(-7.0, 5.0, 3.0), Vector3.ZERO, Vector3.ZERO, 60, Vector3.FORWARD)
	_check(player.global_position.is_equal_approx(Vector3(-7.0, 5.0, 3.0)), "An unstamped state (host hit pipeline) must apply immediately")
	_check(player.health == 60, "Network state must still apply health")
	_check(bool(player.get("_remote_snapshots").is_empty()), "An unstamped state must restart the snapshot history")

	player.configure_remote(2, Color(1.0, 0.3, 0.4))
	_check(bool(player.get("_remote_snapshots").is_empty()), "Reconfiguring a remote blob must clear stale snapshots")
	player.queue_free()


func _finish() -> void:
	if failures.is_empty():
		print("REMOTE INTERPOLATION CONTRACT PASS")
		quit(0)
		return
	for failure in failures:
		push_error("REMOTE INTERPOLATION CONTRACT FAIL: %s" % failure)
	quit(1)
