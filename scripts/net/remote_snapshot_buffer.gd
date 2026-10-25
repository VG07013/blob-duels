class_name RemoteSnapshotBuffer
extends RefCounted

## Timestamped state history for one remote blob.
##
## The host stamps every replicated state with its own clock. Clients push
## those snapshots here and render the blob slightly in the past
## (NetworkTuning.INTERPOLATION_DELAY_MSEC), interpolating between the two
## snapshots that bracket the render time. That turns the old
## "lerp toward the newest packet" smoothing, which always lagged and visibly
## rubber-banded on jitter, into motion that replays exactly what the host saw.

const TUNING := preload("res://scripts/net/network_tuning.gd")

enum Mode {
	EMPTY,
	SNAP,
	INTERPOLATE,
	EXTRAPOLATE,
	HOLD,
}


class Snapshot:
	extends RefCounted
	var position := Vector3.ZERO
	var rotation := Vector3.ZERO
	var velocity := Vector3.ZERO
	var host_time_msec := 0
	var received_local_msec := 0


class Sample:
	extends RefCounted
	var position := Vector3.ZERO
	var rotation := Vector3.ZERO
	var velocity := Vector3.ZERO
	var mode: int = Mode.EMPTY


var _snapshots: Array[Snapshot] = []
var _teleport_pending := false


func clear() -> void:
	_snapshots.clear()
	_teleport_pending = false


func size() -> int:
	return _snapshots.size()


func is_empty() -> bool:
	return _snapshots.is_empty()


func latest() -> Snapshot:
	return _snapshots.back() if not _snapshots.is_empty() else null


## True when the most recent push was classified as a teleport and the render
## has not yet consumed it. Lets callers skip any visual smoothing on that frame.
func consume_teleport() -> bool:
	var pending := _teleport_pending
	_teleport_pending = false
	return pending


func push(position: Vector3, rotation: Vector3, velocity: Vector3, host_time_msec: int, received_local_msec: int = -1) -> void:
	var snapshot := Snapshot.new()
	snapshot.position = position
	snapshot.rotation = rotation
	snapshot.velocity = velocity
	snapshot.host_time_msec = host_time_msec
	snapshot.received_local_msec = received_local_msec if received_local_msec >= 0 else Time.get_ticks_msec()
	var previous := latest()
	if previous != null:
		# Unreliable-ordered delivery still hands us the odd stale packet.
		if host_time_msec <= previous.host_time_msec:
			return
		if _is_teleport(previous, snapshot):
			_snapshots.clear()
			_teleport_pending = true
	_snapshots.append(snapshot)


## Estimated host clock right now, derived from the newest snapshot's arrival.
## Used before the ping exchange has produced a proper offset; it assumes the
## last packet had zero latency, which errs toward rendering slightly late.
func estimate_host_time_msec(local_now_msec: int) -> int:
	var newest := latest()
	if newest == null:
		return local_now_msec
	return newest.host_time_msec + (local_now_msec - newest.received_local_msec)


func sample(render_time_msec: int) -> Sample:
	var result := Sample.new()
	_prune(render_time_msec)
	if _snapshots.is_empty():
		result.mode = Mode.EMPTY
		return result

	var first := _snapshots[0]
	if render_time_msec <= first.host_time_msec:
		_copy_snapshot(first, result)
		result.mode = Mode.SNAP
		return result

	var newest := _snapshots.back() as Snapshot
	if render_time_msec >= newest.host_time_msec:
		var overshoot_msec := mini(render_time_msec - newest.host_time_msec, TUNING.MAX_EXTRAPOLATION_MSEC)
		_copy_snapshot(newest, result)
		result.position = newest.position + newest.velocity * (float(overshoot_msec) / 1000.0)
		result.mode = Mode.HOLD if render_time_msec - newest.host_time_msec > TUNING.MAX_EXTRAPOLATION_MSEC else Mode.EXTRAPOLATE
		return result

	for index in range(1, _snapshots.size()):
		var after := _snapshots[index]
		if render_time_msec > after.host_time_msec:
			continue
		var before := _snapshots[index - 1]
		var span := maxi(after.host_time_msec - before.host_time_msec, 1)
		var weight := clampf(float(render_time_msec - before.host_time_msec) / float(span), 0.0, 1.0)
		result.position = before.position.lerp(after.position, weight)
		result.rotation = Vector3(
			lerp_angle(before.rotation.x, after.rotation.x, weight),
			lerp_angle(before.rotation.y, after.rotation.y, weight),
			lerp_angle(before.rotation.z, after.rotation.z, weight)
		)
		result.velocity = before.velocity.lerp(after.velocity, weight)
		result.mode = Mode.INTERPOLATE
		return result

	_copy_snapshot(newest, result)
	result.mode = Mode.SNAP
	return result


func _is_teleport(previous: Snapshot, next: Snapshot) -> bool:
	var distance := previous.position.distance_to(next.position)
	if distance >= TUNING.TELEPORT_DISTANCE:
		return true
	var elapsed := maxf(float(next.host_time_msec - previous.host_time_msec) / 1000.0, 0.001)
	return distance / elapsed > TUNING.TELEPORT_SPEED


## Drops snapshots that can no longer bracket the render time, keeping the one
## immediately before it so interpolation always has a left-hand neighbour.
func _prune(render_time_msec: int) -> void:
	while _snapshots.size() > 1 and _snapshots[1].host_time_msec <= render_time_msec:
		_snapshots.remove_at(0)


func _copy_snapshot(snapshot: Snapshot, into: Sample) -> void:
	into.position = snapshot.position
	into.rotation = snapshot.rotation
	into.velocity = snapshot.velocity
