class_name BotOpponent
extends Node

## Drives a BlobPlayer body as the offline duel opponent.
##
## The bot is a real duel participant: game.gd registers it as peer
## BOT_PEER_ID with its own ServerPeerState, so hits, deaths and rounds run
## through the same host-authoritative paths a connected player uses. This
## node only decides what a player would do and feeds it to the body as
## controls (BlobVirtualInput): a movement stick, hops, brake, power slide and
## fling charge all run the body's own movement code, so the bot rolls, ramps
## up, buffers bounces and flings exactly like a human. game.gd spawns its
## projectiles and applies every consequence.
##
## Each physics step it perceives (distance, line of sight, incoming shots,
## walls and drops ahead), picks a heading - ram, kite, chase or orbit - then
## layers a dodge on top, and finally decides on hops, slams, slides, flings
## and shots. Difficulty only changes the numbers in BotTuning.

const TUNING := preload("res://scripts/bot_tuning.gd")
const COMBAT_TUNING := preload("res://scripts/combat_tuning.gd")
const PROJECTILE_SCRIPT := preload("res://scripts/projectile.gd")

signal shot_requested(origin: Vector3, direction: Vector3)

var body: BlobPlayer
var target: Node3D
var difficulty := TUNING.DEFAULT_DIFFICULTY
## The stick and buttons the body reads instead of the Input singleton.
var controls := BlobVirtualInput.new()
## Where live projectiles are parented; null means the bot cannot see shots.
var projectiles_root: Node

var _preset: Dictionary = {}
var _round_active := false
var _outside_arena: Callable
var _arena_center := Vector3.ZERO
var _rng := RandomNumberGenerator.new()
var _fire_timer := 0.0
var _fling_timer := 0.0
var _strafe_time := 0.0
var _strafe_sign := 1.0
var _sight_time := 0.0
var _lost_sight_time := 0.0
var _last_seen_position := Vector3.ZERO
var _facing_yaw := 0.0
## Blob-slot ram state: seconds left in the current charge, seconds until the
## bot may start another, and how long it has been airborne this flight.
var _blob_time_left := 0.0
var _blob_cooldown := 0.0
var _airtime := 0.0
var _air_jump_considered := false
var _slam_considered := false
var _wall_kick_considered := false
## Committed short actions, in seconds left.
var _dodge_timer := 0.0
var _dodge_direction := Vector3.ZERO
var _fling_charge_left := 0.0
var _slide_hold_left := 0.0
var _brake_hold_left := 0.0
var _hop_cooldown := 0.0
var _punch_timer := 0.0
var _threat_id := 0


func configure(blob: BlobPlayer, duel_target: Node3D, level: int, outside_arena: Callable, arena_center: Vector3, projectiles: Node = null) -> void:
	body = blob
	target = duel_target
	difficulty = clampi(level, TUNING.DIFFICULTY_EASY, TUNING.DIFFICULTY_HARD)
	_preset = TUNING.preset_for(difficulty)
	_outside_arena = outside_arena
	_arena_center = arena_center
	projectiles_root = projectiles
	_rng.randomize()
	if body != null:
		body.virtual_input = controls
		_facing_yaw = body.aim_yaw
	_reset_timers()


## Rounds start frozen at spawn and thaw on GO, exactly like the local blob.
func set_round_active(active: bool) -> void:
	_round_active = active
	controls.clear()
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
	_lost_sight_time = 0.0
	_blob_time_left = 0.0
	_blob_cooldown = float(_preset.get("blob_cooldown_seconds", 3.0)) * 0.5
	_airtime = 0.0
	_air_jump_considered = false
	_slam_considered = false
	_wall_kick_considered = false
	_dodge_timer = 0.0
	_fling_charge_left = 0.0
	_slide_hold_left = 0.0
	_brake_hold_left = 0.0
	_hop_cooldown = 0.0
	_set_slot(COMBAT_TUNING.SLOT_BLASTER)


func _physics_process(delta: float) -> void:
	if not _round_active or body == null or not is_instance_valid(body) or target == null or not is_instance_valid(target):
		return
	var to_target: Vector3 = target.global_position - body.global_position
	var flat_to_target := Vector3(to_target.x, 0.0, to_target.z)
	var distance := flat_to_target.length()
	var toward := flat_to_target.normalized() if distance > 0.001 else Vector3.FORWARD
	var has_sight := _has_line_of_sight()
	if has_sight:
		_sight_time += delta
		_lost_sight_time = 0.0
		_last_seen_position = target.global_position
	else:
		_sight_time = 0.0
		_lost_sight_time += delta
	_tick_timers(delta)
	_update_facing(to_target, toward, delta)
	_update_slot(distance, has_sight, delta)
	var heading := _choose_heading(toward, distance, has_sight, delta)
	heading = _avoid_edge(heading)
	heading = _apply_dodge(heading, delta)
	_apply_heading(heading)
	_update_jumps(heading, flat_to_target, to_target, delta)
	_update_fling(distance, has_sight, delta)
	_update_slide(distance, has_sight, heading)
	_maybe_air_jump(flat_to_target, delta)
	_maybe_punch(distance)
	_maybe_shoot(to_target, has_sight, distance)
	controls.set_held("brake", _brake_hold_left > 0.0)


func is_blob_mode() -> bool:
	return body != null and body.is_blob_mode()


func _tick_timers(delta: float) -> void:
	_fire_timer -= delta
	_fling_timer -= delta
	_blob_cooldown = maxf(_blob_cooldown - delta, 0.0)
	_dodge_timer = maxf(_dodge_timer - delta, 0.0)
	_slide_hold_left = maxf(_slide_hold_left - delta, 0.0)
	_brake_hold_left = maxf(_brake_hold_left - delta, 0.0)
	_hop_cooldown = maxf(_hop_cooldown - delta, 0.0)
	_punch_timer = maxf(_punch_timer - delta, 0.0)


## Swings the facing onto the target at the preset's turn speed; movement is
## read in this frame, so a slow turn also means a slow course correction.
func _update_facing(to_target: Vector3, toward: Vector3, delta: float) -> void:
	var target_yaw := atan2(-toward.x, -toward.z)
	var blend := 1.0 - exp(-float(_preset.get("turn_speed", 7.0)) * delta)
	_facing_yaw = lerp_angle(_facing_yaw, target_yaw, blend)
	body.aim_yaw = _facing_yaw
	body.aim_direction = to_target.normalized() if to_target.length_squared() > 0.001 else toward


## Swaps to the Blob to ram when the target is close, and back to the Blaster
## once the charge has run its course.
func _update_slot(distance: float, has_sight: bool, _delta: float) -> void:
	if is_blob_mode():
		_blob_time_left -= _delta
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
	if body != null:
		body.set_hotbar_slot(slot)


## Where to go this step, as a flat world direction (or zero to hold still):
## ram through the target in the Blob, kite when hurt, chase a target it has
## lost or that is out of range, otherwise orbit at its preferred range.
func _choose_heading(toward: Vector3, distance: float, has_sight: bool, delta: float) -> Vector3:
	_strafe_time += delta
	if _strafe_time >= float(_preset.get("strafe_period", 1.6)):
		_strafe_time = -_rng.randf_range(0.0, 0.4)
		_strafe_sign = -_strafe_sign
	var lateral := Vector3.UP.cross(toward).normalized() * _strafe_sign * float(_preset.get("strafe_weight", 0.8))
	if is_blob_mode():
		return (toward + lateral * 0.2).normalized()
	var health_ratio := float(body.health) / maxf(float(body.max_health), 1.0)
	if health_ratio <= float(_preset.get("retreat_health_ratio", 0.3)):
		return (-toward + lateral * 0.6).normalized()
	if not has_sight and _lost_sight_time >= TUNING.LOST_SIGHT_CHASE_SECONDS:
		var to_seen := _last_seen_position - body.global_position
		to_seen.y = 0.0
		return to_seen.normalized() if to_seen.length_squared() > 1.0 else toward
	if distance > float(_preset.get("engage_range", 32.0)):
		return (toward + lateral * 0.25).normalized()
	var preferred := float(_preset.get("preferred_range", 10.0))
	var slack := float(_preset.get("range_slack", 2.5))
	var radial := Vector3.ZERO
	if distance > preferred + slack:
		radial = toward
	elif distance < preferred - slack:
		radial = -toward
	var heading := radial + lateral
	return heading.normalized() if heading.length_squared() > 0.001 else Vector3.ZERO


## A heading that would carry the bot off the arena is replaced by the way
## back to the centre, with a brake tap when it is already moving fast.
func _avoid_edge(heading: Vector3) -> Vector3:
	if not _outside_arena.is_valid():
		return heading
	var predicted: Vector3 = body.global_position + body.linear_velocity * TUNING.EDGE_LOOKAHEAD_SECONDS
	if not bool(_outside_arena.call(predicted)):
		return heading
	var to_center := _arena_center - body.global_position
	to_center.y = 0.0
	if body.linear_velocity.length() > TUNING.EDGE_BRAKE_SPEED and body.is_grounded():
		_brake_hold_left = maxf(_brake_hold_left, 0.15)
	return to_center.normalized() if to_center.length_squared() > 0.001 else heading


## Watches live shots: one that will pass close triggers a committed sidestep
## (and sometimes a hop) across its line, with a skill roll per threat.
func _apply_dodge(heading: Vector3, _delta: float) -> Vector3:
	if _dodge_timer <= 0.0:
		var threat := _incoming_threat()
		if not threat.is_empty() and int(threat["id"]) != _threat_id:
			_threat_id = int(threat["id"])
			if _rng.randf() <= float(_preset.get("dodge_skill", 0.5)):
				var shot_direction := (threat["velocity"] as Vector3).normalized()
				var side := Vector3.UP.cross(shot_direction).normalized()
				var offset := body.global_position - (threat["closest"] as Vector3)
				if offset.dot(side) < 0.0:
					side = -side
				_dodge_direction = side
				_dodge_timer = TUNING.DODGE_SECONDS
				if body.is_grounded() and _rng.randf() < TUNING.DODGE_HOP_CHANCE:
					_hop()
	if _dodge_timer > 0.0:
		return (heading * 0.3 + _dodge_direction).normalized()
	return heading


## The nearest projectile from someone else whose path passes within
## THREAT_MISS_DISTANCE in the next THREAT_LOOKAHEAD_SECONDS.
func _incoming_threat() -> Dictionary:
	if projectiles_root == null or not is_instance_valid(projectiles_root):
		return {}
	var best: Dictionary = {}
	var best_time := INF
	for child in projectiles_root.get_children():
		var projectile := child as Node3D
		if projectile == null or projectile.get("source") == body:
			continue
		var velocity: Vector3 = projectile.get("velocity") if projectile.get("velocity") != null else Vector3.ZERO
		var speed := velocity.length()
		if speed < 0.01:
			continue
		var relative := body.global_position - projectile.global_position
		var time_to_pass := relative.dot(velocity) / (speed * speed)
		if time_to_pass < 0.0 or time_to_pass > TUNING.THREAT_LOOKAHEAD_SECONDS:
			continue
		var closest := projectile.global_position + velocity * time_to_pass
		if closest.distance_to(body.global_position) > TUNING.THREAT_MISS_DISTANCE:
			continue
		if time_to_pass < best_time:
			best_time = time_to_pass
			best = {"id": projectile.get_instance_id(), "velocity": velocity, "closest": closest}
	return best


## Turns a world heading into the stick the body reads in its aim frame.
func _apply_heading(heading: Vector3) -> void:
	if heading.length_squared() < 0.001:
		controls.move = Vector2.ZERO
		return
	var aim_basis := Basis(Vector3.UP, body.aim_yaw)
	var forward := -aim_basis.z
	var right := aim_basis.x
	controls.move = Vector2(heading.dot(right), -heading.dot(forward)).limit_length(1.0)


## Hops over what is in the way and now and then for the fun of it; in the
## air, kicks off a wall it is about to hit or drops a slam onto a target
## below. Slam and wall kick are each rolled once per flight.
func _update_jumps(heading: Vector3, flat_to_target: Vector3, to_target: Vector3, _delta: float) -> void:
	if body.is_grounded():
		_slam_considered = false
		_wall_kick_considered = false
		if _hop_cooldown > 0.0:
			return
		if heading.length_squared() > 0.001 and _probe_blocked(heading, TUNING.OBSTACLE_PROBE_DISTANCE):
			_hop()
		elif _rng.randf() < float(_preset.get("bounce_chance_per_second", 0.6)) * _delta:
			_hop()
		return
	if is_blob_mode() or _fling_charge_left > 0.0:
		return
	if not _slam_considered and -to_target.y >= TUNING.SLAM_MIN_HEIGHT_ABOVE and flat_to_target.length() <= TUNING.SLAM_MAX_FLAT_DISTANCE:
		_slam_considered = true
		if _rng.randf() <= float(_preset.get("slam_skill", 0.3)):
			_brake_hold_left = TUNING.SLAM_BRAKE_HOLD_SECONDS
			controls.set_held("brake", true)
			controls.tap("bounce")
			return
	var planar_velocity := Vector3(body.linear_velocity.x, 0.0, body.linear_velocity.z)
	if not _wall_kick_considered and planar_velocity.length_squared() > 25.0 and _probe_blocked(planar_velocity.normalized(), TUNING.WALL_KICK_PROBE_DISTANCE):
		_wall_kick_considered = true
		if _rng.randf() <= float(_preset.get("dodge_skill", 0.5)):
			controls.tap("bounce")


func _hop() -> void:
	controls.tap("bounce")
	_hop_cooldown = TUNING.HOP_COOLDOWN_SECONDS


## A horizontal probe at body height along `direction`.
func _probe_blocked(direction: Vector3, distance: float) -> bool:
	if not body.is_inside_tree():
		return false
	var from := body.global_position + Vector3.UP * 0.5
	var query := PhysicsRayQueryParameters3D.create(from, from + direction * distance, TUNING.LINE_OF_SIGHT_MASK)
	query.exclude = [body.get_rid()]
	var hit := body.get_world_3d().direct_space_state.intersect_ray(query)
	# A floor or gentle ramp under the probe is not an obstacle.
	return not hit.is_empty() and absf((hit["normal"] as Vector3).y) < 0.6


## Charges a real fling at a distant target: swaps to the Blob so the ram
## lands harder and the air jump can correct the flight, holds the charge for
## the preset's time, then releases through the body's own fling path.
func _update_fling(distance: float, has_sight: bool, delta: float) -> void:
	if _fling_charge_left > 0.0:
		_fling_charge_left -= delta
		if _fling_charge_left <= 0.0:
			controls.release("charge_fling")
		return
	if _fling_timer > 0.0 or not has_sight or distance < float(_preset.get("fling_min_distance", 11.0)):
		return
	if not body.can_fling() or not body.is_grounded():
		return
	_fling_timer = float(_preset.get("fling_interval", 4.0)) * _rng.randf_range(0.8, 1.2)
	if not is_blob_mode():
		_start_blob_charge()
	_fling_charge_left = float(_preset.get("fling_charge_seconds", 0.6))
	controls.press("charge_fling")


## Power slides to close a long gap on the ground, the way a player holds C.
func _update_slide(distance: float, has_sight: bool, heading: Vector3) -> void:
	if _slide_hold_left <= 0.0 and body.is_grounded() and not is_blob_mode() and _fling_charge_left <= 0.0 \
			and heading.length_squared() > 0.001 and (distance >= TUNING.SLIDE_MIN_DISTANCE or not has_sight) \
			and _rng.randf() < float(_preset.get("slide_skill", 0.5)) * get_physics_process_delta_time():
		_slide_hold_left = TUNING.SLIDE_HOLD_SECONDS
	controls.set_held("slide", _slide_hold_left > 0.0)


## Mid-flight in the Blob, a skilled bot spends its air jump to swing its
## momentum back onto the target when the flight is carrying it wide.
func _maybe_air_jump(flat_to_target: Vector3, delta: float) -> void:
	if body.is_grounded():
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
	if _rng.randf() <= float(_preset.get("air_jump_skill", 0.5)):
		body.blob_air_jump_toward(flat_to_target.normalized())


## In the Blob, a target inside fist reach gets punched like a player would click.
func _maybe_punch(distance: float) -> void:
	if not is_blob_mode() or _punch_timer > 0.0 or distance > COMBAT_TUNING.PUNCH_REACH + 1.0:
		return
	_punch_timer = TUNING.PUNCH_INTERVAL
	controls.tap("shoot")


func _maybe_shoot(to_target: Vector3, has_sight: bool, distance: float) -> void:
	if _fire_timer > 0.0 or not has_sight or is_blob_mode() or _fling_charge_left > 0.0:
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
