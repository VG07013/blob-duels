class_name BotOpponent
extends Node

## Drives a BlobPlayer body as the offline duel opponent.
##
## The bot is a real duel participant: game.gd registers it as peer
## BOT_PEER_ID with its own ServerPeerState, so hits, deaths and rounds run
## through the same host-authoritative paths a connected player uses. This
## node only decides where the body goes and when it asks to shoot; game.gd
## spawns the projectile and applies every consequence.

const TUNING := preload("res://scripts/bot_tuning.gd")
const COMBAT_TUNING := preload("res://scripts/combat_tuning.gd")
const PROJECTILE_SCRIPT := preload("res://scripts/projectile.gd")

signal shot_requested(origin: Vector3, direction: Vector3)

var body: RigidBody3D
var target: Node3D
var difficulty := TUNING.DEFAULT_DIFFICULTY

var _preset: Dictionary = {}
var _round_active := false
var _outside_arena: Callable
var _arena_center := Vector3.ZERO
var _fire_timer := 0.0
var _fling_timer := 0.0
var _strafe_time := 0.0
var _strafe_sign := 1.0
var _sight_time := 0.0
var _rng := RandomNumberGenerator.new()
## Blob-slot ram state: seconds left in the current charge, seconds until the
## bot may start another, and how long it has been airborne this flight.
var _blob_time_left := 0.0
var _blob_cooldown := 0.0
var _airtime := 0.0
var _air_jump_considered := false


func configure(blob: RigidBody3D, duel_target: Node3D, level: int, outside_arena: Callable, arena_center: Vector3) -> void:
	body = blob
	target = duel_target
	difficulty = clampi(level, TUNING.DIFFICULTY_EASY, TUNING.DIFFICULTY_HARD)
	_preset = TUNING.preset_for(difficulty)
	_outside_arena = outside_arena
	_arena_center = arena_center
	_rng.randomize()
	_reset_timers()


## Rounds start frozen at spawn and thaw on GO, exactly like the local blob.
func set_round_active(active: bool) -> void:
	_round_active = active
	if body == null or not is_instance_valid(body):
		return
	body.freeze = not active
	if active:
		body.sleeping = false
		_reset_timers()
	else:
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO


func is_round_active() -> bool:
	return _round_active


func _reset_timers() -> void:
	_fire_timer = float(_preset.get("reaction_seconds", 0.5))
	_fling_timer = float(_preset.get("fling_interval", 4.0)) * 0.5
	_strafe_time = 0.0
	_strafe_sign = 1.0 if _rng.randf() < 0.5 else -1.0
	_sight_time = 0.0
	_blob_time_left = 0.0
	_blob_cooldown = float(_preset.get("blob_cooldown_seconds", 3.0)) * 0.5
	_airtime = 0.0
	_air_jump_considered = false
	_set_slot(COMBAT_TUNING.SLOT_BLASTER)


func _physics_process(delta: float) -> void:
	if not _round_active or body == null or not is_instance_valid(body) or target == null or not is_instance_valid(target):
		return
	var to_target: Vector3 = target.global_position - body.global_position
	var flat_to_target := Vector3(to_target.x, 0.0, to_target.z)
	var distance := flat_to_target.length()
	var toward := flat_to_target.normalized() if distance > 0.001 else Vector3.FORWARD
	body.set("aim_direction", to_target.normalized() if to_target.length_squared() > 0.001 else toward)
	var has_sight := _has_line_of_sight()
	_sight_time = _sight_time + delta if has_sight else 0.0

	_update_slot(distance, has_sight, delta)
	_move(toward, distance, delta)
	_avoid_edge()
	_maybe_bounce(delta)
	_maybe_fling(toward, distance, has_sight, delta)
	_maybe_air_jump(flat_to_target, delta)
	_maybe_shoot(to_target, has_sight, distance, delta)


func is_blob_mode() -> bool:
	return body != null and body.has_method("is_blob_mode") and bool(body.call("is_blob_mode"))


## Swaps to the Blob to ram when the target is close, and back to the Blaster
## once the charge has run its course.
func _update_slot(distance: float, has_sight: bool, delta: float) -> void:
	_blob_cooldown = maxf(_blob_cooldown - delta, 0.0)
	if is_blob_mode():
		_blob_time_left -= delta
		if _blob_time_left <= 0.0:
			_end_blob_charge()
		return
	if _blob_cooldown <= 0.0 and has_sight and distance <= float(_preset.get("blob_ram_range", 14.0)):
		_start_blob_charge()


func _start_blob_charge() -> void:
	_set_slot(COMBAT_TUNING.SLOT_BLOB)
	_blob_time_left = float(_preset.get("blob_commit_seconds", 2.4))


func _end_blob_charge() -> void:
	_set_slot(COMBAT_TUNING.SLOT_BLASTER)
	_blob_time_left = 0.0
	_blob_cooldown = float(_preset.get("blob_cooldown_seconds", 3.0))


func _set_slot(slot: int) -> void:
	if body != null and body.has_method("set_hotbar_slot"):
		body.call("set_hotbar_slot", slot)


## Mid-flight in the Blob, a skilled bot spends its air jump to swing its
## momentum back onto the target when the flight is carrying it wide.
func _maybe_air_jump(flat_to_target: Vector3, delta: float) -> void:
	var grounded := body.has_method("is_grounded") and bool(body.call("is_grounded"))
	if grounded:
		_airtime = 0.0
		_air_jump_considered = false
		return
	_airtime += delta
	if not is_blob_mode() or _air_jump_considered or _airtime < TUNING.AIR_JUMP_MIN_AIRTIME:
		return
	var planar_velocity := Vector3(body.linear_velocity.x, 0.0, body.linear_velocity.z)
	if planar_velocity.length_squared() < 4.0 or flat_to_target.length_squared() < 0.01:
		return
	if planar_velocity.normalized().dot(flat_to_target.normalized()) >= TUNING.AIR_JUMP_REDIRECT_DOT:
		return
	# One roll per flight: a clumsy bot misses its window, a sharp one never does.
	_air_jump_considered = true
	if _rng.randf() <= float(_preset.get("air_jump_skill", 0.5)) and body.has_method("blob_air_jump_toward"):
		body.call("blob_air_jump_toward", flat_to_target.normalized())


## Circles the target at its preferred range, backing off when hurt.
func _move(toward: Vector3, distance: float, delta: float) -> void:
	_strafe_time += delta
	if _strafe_time >= float(_preset.get("strafe_period", 1.6)):
		_strafe_time = 0.0
		_strafe_sign = -_strafe_sign
	var lateral := Vector3.UP.cross(toward).normalized() * _strafe_sign * float(_preset.get("strafe_weight", 0.8))
	var preferred := float(_preset.get("preferred_range", 10.0))
	var slack := float(_preset.get("range_slack", 2.5))
	var radial := Vector3.ZERO
	var health_ratio := float(body.get("health")) / maxf(float(body.get("max_health")), 1.0)
	if is_blob_mode():
		# Ramming: drive straight through the target, barely weaving.
		var charge := toward + lateral * 0.2
		_steer_toward(body.global_position + charge.normalized() * TUNING.STEER_POINT_DISTANCE * COMBAT_TUNING.BLOB_SPEED_MULTIPLIER * 1.6, float(_preset.get("max_accel", 48.0)) * COMBAT_TUNING.BLOB_SPEED_MULTIPLIER)
		return
	if health_ratio <= float(_preset.get("retreat_health_ratio", 0.3)):
		radial = -toward
	elif distance > preferred + slack:
		radial = toward
	elif distance < preferred - slack:
		radial = -toward
	var heading := radial + lateral
	if heading.length_squared() < 0.001:
		return
	_steer_toward(body.global_position + heading.normalized() * TUNING.STEER_POINT_DISTANCE, float(_preset.get("max_accel", 48.0)))


## Horizontal proportional steering, capped as an acceleration so mass never
## turns a nudge into a launch (mirrors the practice dummy).
func _steer_toward(point: Vector3, max_accel: float) -> void:
	var to_point := point - body.global_position
	to_point.y = 0.0
	var desired := to_point * 2.6
	var current := Vector3(body.linear_velocity.x, 0.0, body.linear_velocity.z)
	var accel := (desired - current) * 4.0
	if accel.length_squared() < 0.0001:
		return
	body.sleeping = false
	body.apply_central_force(accel.limit_length(max_accel) * body.mass)


func _avoid_edge() -> void:
	if not _outside_arena.is_valid():
		return
	var predicted: Vector3 = body.global_position + body.linear_velocity * TUNING.EDGE_LOOKAHEAD_SECONDS
	if bool(_outside_arena.call(predicted)):
		_steer_toward(_arena_center, float(_preset.get("max_accel", 48.0)) * TUNING.EDGE_ESCAPE_ACCEL_MULTIPLIER)


func _maybe_bounce(delta: float) -> void:
	if not body.has_method("is_grounded") or not bool(body.call("is_grounded")):
		return
	if _rng.randf() < float(_preset.get("bounce_chance_per_second", 0.6)) * delta:
		body.sleeping = false
		body.apply_central_impulse(Vector3.UP * float(_preset.get("bounce_impulse", 48.0)))
		if body.has_method("trigger_launch_visual"):
			body.call("trigger_launch_visual", 0.4)


func _maybe_fling(toward: Vector3, distance: float, has_sight: bool, delta: float) -> void:
	_fling_timer -= delta
	if _fling_timer > 0.0:
		return
	if not has_sight or distance < float(_preset.get("fling_min_distance", 11.0)):
		return
	_fling_timer = float(_preset.get("fling_interval", 4.0)) * _rng.randf_range(0.8, 1.2)
	# A fling is a ram: swap to the Blob first so the hit lands harder and the
	# air jump is available to correct the flight.
	if not is_blob_mode():
		_start_blob_charge()
	var direction := (toward + Vector3.UP * TUNING.FLING_UPWARD_ASSIST).normalized()
	body.sleeping = false
	body.apply_central_impulse(direction * float(_preset.get("fling_strength", 150.0)))
	if body.has_method("trigger_launch_visual"):
		body.call("trigger_launch_visual", 0.9)


func _maybe_shoot(to_target: Vector3, has_sight: bool, distance: float, delta: float) -> void:
	_fire_timer -= delta
	if _fire_timer > 0.0 or not has_sight or is_blob_mode():
		return
	if distance > float(_preset.get("engage_range", 32.0)) or _sight_time < float(_preset.get("reaction_seconds", 0.5)):
		return
	_fire_timer = float(_preset.get("fire_interval", 0.55)) * _rng.randf_range(0.85, 1.15)
	var origin_guess: Vector3 = body.global_position + to_target.normalized() * TUNING.SHOT_MUZZLE_OFFSET + Vector3.UP * TUNING.SHOT_MUZZLE_HEIGHT
	var aim_point := predict_aim_point(origin_guess)
	var direction := (aim_point - origin_guess).normalized()
	if direction.length_squared() < 0.001:
		direction = to_target.normalized()
	direction = _with_aim_error(direction)
	var origin: Vector3 = body.global_position + direction * TUNING.SHOT_MUZZLE_OFFSET + Vector3.UP * TUNING.SHOT_MUZZLE_HEIGHT
	shot_requested.emit(origin, direction)


## Where to aim so a shot fired from `origin` meets the target: solves the
## intercept against the target's current velocity at the real shot speed,
## bends the lead with gravity while the target is airborne, then scales the
## lead by the difficulty's `prediction` (0 = aim at the body, 1 = full lead).
func predict_aim_point(origin: Vector3) -> Vector3:
	var target_position: Vector3 = target.global_position
	var target_velocity: Vector3 = target.get("linear_velocity") if target is RigidBody3D else Vector3.ZERO
	var flight_time := COMBAT_TUNING.intercept_time(origin, target_position, target_velocity, PROJECTILE_SCRIPT.BASE_SPEED)
	if flight_time <= 0.0:
		flight_time = origin.distance_to(target_position) / PROJECTILE_SCRIPT.BASE_SPEED
	var predicted := target_position + target_velocity * flight_time
	var airborne := target.has_method("is_grounded") and not bool(target.call("is_grounded"))
	if airborne:
		var gravity := float(ProjectSettings.get_setting("physics/3d/default_gravity", 9.8))
		var gravity_scale := float(target.get("gravity_scale")) if target is RigidBody3D else 1.0
		predicted.y -= 0.5 * gravity * gravity_scale * flight_time * flight_time
		# Never aim below the floor the target would land on.
		predicted.y = maxf(predicted.y, target_position.y - 6.0)
	return target_position.lerp(predicted, clampf(float(_preset.get("prediction", 1.0)), 0.0, 1.0))


func _with_aim_error(direction: Vector3) -> Vector3:
	var error := float(_preset.get("aim_error_radians", 0.08))
	if error <= 0.0:
		return direction
	var axis := direction.cross(Vector3.UP)
	if axis.length_squared() < 0.001:
		axis = Vector3.RIGHT
	axis = axis.normalized().rotated(direction, _rng.randf() * TAU)
	return direction.rotated(axis, _rng.randf_range(-error, error)).normalized()


func _has_line_of_sight() -> bool:
	if not body.is_inside_tree():
		return false
	var query := PhysicsRayQueryParameters3D.create(body.global_position, target.global_position, TUNING.LINE_OF_SIGHT_MASK)
	query.exclude = [body.get_rid()]
	return body.get_world_3d().direct_space_state.intersect_ray(query).is_empty()
