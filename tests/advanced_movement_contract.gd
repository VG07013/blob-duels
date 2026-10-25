extends SceneTree

## Advanced movement contract: wall kick, slam, and momentum slide.
##
## Product rules protected here:
## - Space while airborne next to a wall is a wall kick that launches away
##   from the wall, only near walls, on a short chainable cooldown, with an
##   impulse bounded by its tuning.
## - Brake + Space while airborne is a slam: a straight-down dive that is
##   never available on the ground, whose landing outranks an ordinary drop
##   in impact severity and refunds the bounce.
## - Holding brake on the ground above the slide threshold is a low-drag
##   momentum slide that expires into the hard brake; below the threshold the
##   brake stays a brake.
## - Holding slide (C) on the ground is a power slide: a burst of speed, a
##   raised speed band, far less drag than an idle blob, never from mid-air;
##   releasing it pops a small hop, brake cuts it with none.
## - The air-control curve keeps small corrections precise and makes wide
##   reversals costly, and a pre-landing Space still buffers into a bounce.

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

var failures: Array[String] = []
var world: Node3D
var player: RigidBody3D
var wall_kick_normals: Array[Vector3] = []
var slam_starts := 0
var slam_landed_severities: Array[float] = []
var impact_severities: Array[float] = []
var bounce_triggers := 0
var slide_changes: Array[bool] = []
var slide_hops := 0


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	world = Node3D.new()
	root.add_child(world)
	_add_box(Vector3(0.0, -1.0, 0.0), Vector3(400.0, 2.0, 400.0))
	# A tall wall whose -X face sits at x = 19.
	_add_box(Vector3(20.0, 20.0, 0.0), Vector3(2.0, 40.0, 60.0))

	player = PLAYER_SCENE.instantiate() as RigidBody3D
	world.add_child(player)
	player.configure_local(1)
	player.wall_kicked.connect(func(normal: Vector3) -> void: wall_kick_normals.append(normal))
	player.slam_started.connect(func() -> void: slam_starts += 1)
	player.slam_landed.connect(func(severity: float) -> void: slam_landed_severities.append(severity))
	player.impact_event.connect(func(_position: Vector3, _strength: float, severity: float) -> void: impact_severities.append(severity))
	player.bounce_triggered.connect(func(_strength: float) -> void: bounce_triggers += 1)
	player.power_slide_changed.connect(func(sliding: bool) -> void: slide_changes.append(sliding))
	player.power_slide_hopped.connect(func() -> void: slide_hops += 1)
	await physics_frame

	await _test_wall_kick()
	await _test_slam()
	await _test_slide()
	await _test_power_slide()
	await _test_air_control_curve()
	await _test_bounce_buffer_survives_new_moves()

	_release_all()
	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("ADVANCED MOVEMENT CONTRACT PASS: wall kick, slam, slide, power slide, air-control curve, bounce buffer")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _test_wall_kick() -> void:
	var radius := float(player.get("_collision_radius"))
	var kick_speed: float = player.wall_kick_impulse / player.mass
	var lift_speed: float = player.wall_kick_upward_impulse / player.mass

	# Far from any wall, an airborne Space is not a kick.
	await _place_airborne(Vector3(4.0, 14.0, 0.0), Vector3(30.0, -5.0, 0.0))
	await _press("bounce")
	_check(wall_kick_normals.is_empty(), "Wall kick must only trigger within reach of a wall")
	_check(player.linear_velocity.x > 25.0, "An airborne Space far from walls must not alter momentum")

	# Hugging the wall (gap 0.61 units), the same press kicks away from it.
	var hugging_x := 19.0 - radius - 0.61
	await _place_airborne(Vector3(hugging_x, 14.0, 0.0), Vector3(30.0, -5.0, 0.0))
	await _press("bounce")
	_check(wall_kick_normals.size() == 1, "Space while airborne beside a wall must wall kick")
	if wall_kick_normals.size() == 1:
		_check(wall_kick_normals[0].dot(Vector3.LEFT) > 0.95, "Wall kick must launch away from the wall it touched")
	var away_speed := -player.linear_velocity.x
	var minimum_away: float = kick_speed - 0.5
	var maximum_away: float = kick_speed + 30.0 * player.wall_kick_speed_retention + 0.5
	_check(away_speed >= minimum_away and away_speed <= maximum_away, "Wall kick lateral speed must stay within its tuning bounds (%.1f not in [%.1f, %.1f])" % [away_speed, minimum_away, maximum_away])
	_check(player.linear_velocity.y > lift_speed * 0.6 and player.linear_velocity.y <= lift_speed + 0.5, "Wall kick must add its small upward component")
	_check(player.wall_kick_speed_retention > 0.0 and away_speed > kick_speed + 1.0, "Wall kick must preserve a fraction of incoming speed")
	_check(bounce_triggers >= 1, "A wall kick must announce itself as a bounce for feedback")

	# Immediately again (teleported back, no respawn so the cooldown is live):
	# the cooldown blocks the chain until it lapses.
	await _teleport_airborne(Vector3(hugging_x, 14.0, 0.0))
	await _press("bounce")
	_check(wall_kick_normals.size() == 1, "Wall kick cooldown must block an immediate second kick")
	await _physics_seconds(player.wall_kick_cooldown + 0.05)
	await _teleport_airborne(Vector3(hugging_x, 14.0, 0.0))
	await _press("bounce")
	_check(wall_kick_normals.size() == 2, "Wall kicks must chain once the short cooldown lapses")

	# Slightly out of reach: no kick.
	var out_of_reach_x: float = 19.0 - radius - player.wall_kick_probe_distance - 0.4
	await _place_airborne(Vector3(out_of_reach_x, 14.0, 0.0), Vector3.ZERO)
	await _press("bounce")
	_check(wall_kick_normals.size() == 2, "Wall kick probe must not reach beyond its tuned distance")
	player.gravity_scale = 1.8


func _teleport_airborne(position: Vector3) -> void:
	player.global_position = position
	player.linear_velocity = Vector3.ZERO
	player.angular_velocity = Vector3.ZERO
	player.reset_physics_interpolation()
	await physics_frame
	await physics_frame


func _test_slam() -> void:
	# On the ground, brake + Space is an ordinary bounce, never a slam.
	await _reset_player(Vector3(0.0, 3.0, 0.0))
	await _wait_for_bounce_ready()
	Input.action_press("brake")
	await _press("bounce")
	Input.action_release("brake")
	_check(slam_starts == 0, "Slam must be unavailable while grounded")
	_check(not player.is_slamming(), "Grounded brake + Space must not enter the slam state")

	# Airborne, brake + Space drives straight down.
	await _place_airborne(Vector3(-30.0, 30.0, 0.0), Vector3(12.0, 2.0, 0.0))
	Input.action_press("brake")
	await _press("bounce")
	Input.action_release("brake")
	_check(slam_starts == 1, "Brake + Space while airborne must start a slam")
	_check(player.is_slamming(), "Slam state must be reported while diving")
	_check(player.linear_velocity.y <= -player.slam_downward_speed + 0.5, "Slam must reach its tuned downward speed immediately")
	_check(absf(player.linear_velocity.x) < 12.0, "Slam must shed most planar speed so the dive goes straight down")
	await _physics_seconds(0.2)
	_check(player.linear_velocity.y <= -player.slam_downward_speed + 0.5, "Slam must hold its downward speed for the whole dive")

	# Let it land under gravity and compare with an ordinary drop.
	player.gravity_scale = 1.8
	impact_severities.clear()
	var landed := await _wait_until(func() -> bool: return not player.is_slamming(), 3.0)
	_check(landed, "A slam must land within a few seconds")
	_check(slam_landed_severities.size() == 1, "Slam landing must emit exactly one landing signal")
	var slam_severity := _max_of(impact_severities)
	_check(player.linear_velocity.y <= player.slam_landing_rebound_speed + 0.5, "A landed slam must stick instead of trampolining off the bouncy body")
	_check(float(player.get("_bounce_cooldown_timer")) <= 0.001, "Slam landing must refund the bounce cooldown")
	_check(float(player.get("_slam_cooldown_timer")) > 0.0, "Slam must start its cooldown on landing")

	impact_severities.clear()
	await _place_airborne(Vector3(-30.0, 30.0, 0.0), Vector3.ZERO)
	player.gravity_scale = 1.8
	await _wait_until(func() -> bool: return not impact_severities.is_empty(), 3.0)
	await _physics_seconds(0.3)
	var drop_severity := _max_of(impact_severities)
	_check(drop_severity > 0.0, "An ordinary drop from slam height must still register a landing impact")
	_check(slam_severity > drop_severity + 10.0, "Slam landing severity must clearly outrank an ordinary landing from the same height (%.1f vs %.1f)" % [slam_severity, drop_severity])
	_check(slam_severity >= player.slam_downward_speed, "Slam landing severity must be at least the dive speed")


func _test_slide() -> void:
	_check(player.slide_drag < player.brake_drag * 0.5, "Slide drag must be far below brake drag")

	# Below the threshold, brake is just a brake.
	await _reset_player(Vector3(0.0, 3.0, 0.0))
	player.linear_velocity = Vector3(player.slide_speed_threshold * 0.5, 0.0, 0.0)
	Input.action_press("brake")
	await _physics_seconds(0.15)
	_check(not player.is_sliding(), "Brake below the slide threshold must not slide")
	Input.action_release("brake")
	await _physics_seconds(player.slide_recovery_time + 0.1)

	# Above it, brake becomes a low-drag slide that keeps its heading.
	await _reset_player(Vector3(0.0, 3.0, 0.0))
	player.linear_velocity = Vector3(40.0, 0.0, 0.0)
	Input.action_press("brake")
	await _physics_seconds(0.3)
	_check(player.is_sliding(), "Brake above the slide threshold on the ground must slide")
	var slid_speed := _planar_speed()
	var hard_brake_speed: float = 40.0 * exp(-player.brake_drag * 0.3)
	_check(slid_speed > hard_brake_speed + 8.0, "A slide must shed far less speed than the hard brake (%.1f vs brake %.1f)" % [slid_speed, hard_brake_speed])
	_check(slid_speed > 28.0, "A slide must keep most of its momentum through its opening")
	_check(absf(player.linear_velocity.z) < 2.0, "A slide must keep its heading")
	var visual := player.get_node("VisualRoot") as Node3D
	_check(visual.scale.y < 0.9, "Sliding must visibly lower the blob (squash)")

	# Then it expires into the hard brake while brake is still held.
	await _physics_seconds(player.slide_duration)
	_check(not player.is_sliding(), "A slide must expire after its duration")
	_check(bool(player.get("_slide_spent")), "An expired slide must not restart until brake is released")
	var before_brake := _planar_speed()
	await _physics_seconds(0.2)
	var after_brake := _planar_speed()
	_check(after_brake < before_brake * exp(-player.brake_drag * 0.2) + 1.0, "An expired slide must hand over to the hard brake")
	Input.action_release("brake")


func _test_power_slide() -> void:
	_check(player.power_slide_drag < player.idle_ground_drag * 0.5, "Power slide drag must be far below idle ground drag")

	# From a standstill, holding slide bursts the blob forward, low to the ground.
	await _reset_player(Vector3(0.0, 3.0, 0.0))
	slide_changes.clear()
	slide_hops = 0
	Input.action_press("slide")
	await _physics_seconds(0.1)
	_check(player.is_power_sliding(), "Holding slide on the ground must start a power slide")
	_check(slide_changes == [true], "Starting a power slide must announce it once (for its sound)")
	_check(_planar_speed() > player.power_slide_entry_boost * 0.6, "A power slide must burst forward (%.1f)" % _planar_speed())
	var visual := player.get_node("VisualRoot") as Node3D
	_check(visual.scale.y < 0.9, "Power sliding must visibly lower the blob (squash)")

	# It is faster than running: the speed band rises and speed carries.
	_check(player.get_ground_control_speed() > player.ground_control_speed, "A power slide must raise the ground speed band")
	player.linear_velocity = Vector3(30.0, player.linear_velocity.y, 0.0)
	await _physics_seconds(0.4)
	var slid_speed := _planar_speed()
	_check(slid_speed > 30.0 * exp(-player.idle_ground_drag * 0.4) + 6.0, "A power slide must carry far more speed than an idle blob (%.1f)" % slid_speed)

	# Letting go ends it with a small hop upward.
	Input.action_release("slide")
	await physics_frame
	await physics_frame
	_check(not player.is_power_sliding(), "Releasing slide must end the power slide")
	_check(slide_hops == 1, "Ending a power slide on the ground must pop a hop")
	_check(player.linear_velocity.y > player.power_slide_exit_hop * 0.5, "The exit hop must lift the blob (vy %.1f)" % player.linear_velocity.y)
	_check(player.linear_velocity.y < player.bounce_boost_impulse, "The exit hop must stay small next to a real bounce")
	await _physics_seconds(player.power_slide_recovery_time + 0.4)

	# Brake cuts a power slide without the hop.
	await _reset_player(Vector3(0.0, 3.0, 0.0))
	slide_hops = 0
	Input.action_press("slide")
	await _physics_seconds(0.15)
	Input.action_press("brake")
	await _physics_seconds(0.05)
	_check(not player.is_power_sliding(), "Brake must cut a power slide")
	_check(slide_hops == 0, "A braked power slide must not hop")
	_release_all()

	# Never from mid-air.
	await _place_airborne(Vector3(-40.0, 40.0, 40.0), Vector3(0.0, 0.0, -20.0))
	Input.action_press("slide")
	await _physics_seconds(0.1)
	_check(not player.is_power_sliding(), "A power slide must not start in mid-air")
	Input.action_release("slide")
	player.gravity_scale = 1.8


func _test_air_control_curve() -> void:
	# Both requests are equally "lateral" to the current heading once normalized;
	# the curve is what makes the wide one turn less.
	var gentle := await _measure_air_turn(Vector3(-0.7071, 0.0, -0.7071))
	var wide := await _measure_air_turn(Vector3(0.7071, 0.0, 0.7071))
	_check(gentle > 0.02, "Small airborne corrections must still redirect momentum")
	_check(wide < gentle * 0.8, "Wide mid-air reversals must cost steering authority (wide %.3f vs gentle %.3f rad)" % [wide, gentle])
	player.gravity_scale = 1.8


func _test_bounce_buffer_survives_new_moves() -> void:
	# Space pressed just before touchdown, without brake and away from walls,
	# must still buffer into the ground bounce - not a slam, not a kick.
	await _reset_player(Vector3(-40.0, 3.0, 20.0))
	await _wait_for_bounce_ready()
	player.global_position = Vector3(-40.0, 9.0, 20.0)
	player.reset_physics_interpolation()
	player.linear_velocity = Vector3(0.0, -20.0, 0.0)
	await physics_frame
	await physics_frame
	var triggers_before := bounce_triggers
	var slams_before := slam_starts
	var kicks_before := wall_kick_normals.size()
	Input.action_press("bounce")
	await physics_frame
	Input.action_release("bounce")
	await _physics_seconds(0.4)
	_check(bounce_triggers > triggers_before, "A pre-landing Space must still buffer into a ground bounce")
	_check(slam_starts == slams_before and wall_kick_normals.size() == kicks_before, "A buffered bounce must not be mistaken for a slam or wall kick")
	_check(player.linear_velocity.y > 3.0 or player.global_position.y > 3.5, "The buffered bounce must actually lift the blob")


func _measure_air_turn(desired_world_direction: Vector3) -> float:
	await _place_airborne(Vector3(-40.0, 40.0, 40.0), Vector3(0.0, 0.0, -40.0))
	player.aim_yaw = 0.0
	# Camera-relative input: +x = right (+X), -y = forward (-Z).
	var input := Vector2(desired_world_direction.x, desired_world_direction.z)
	_press_direction(input)
	await _physics_seconds(0.3)
	_release_all()
	var heading := Vector3(player.linear_velocity.x, 0.0, player.linear_velocity.z).normalized()
	return absf(Vector3.FORWARD.signed_angle_to(heading, Vector3.UP))


func _press_direction(input: Vector2) -> void:
	if input.x > 0.1:
		Input.action_press("move_right")
	elif input.x < -0.1:
		Input.action_press("move_left")
	if input.y > 0.1:
		Input.action_press("move_back")
	elif input.y < -0.1:
		Input.action_press("move_forward")


func _release_all() -> void:
	for action_name in ["move_forward", "move_back", "move_left", "move_right", "bounce", "brake", "slide", "charge_fling"]:
		Input.action_release(action_name)


func _press(action_name: String) -> void:
	Input.action_press(action_name)
	await physics_frame
	Input.action_release(action_name)
	await physics_frame


func _place_airborne(position: Vector3, velocity: Vector3) -> void:
	_release_all()
	player.respawn(position)
	player.gravity_scale = 0.0
	await physics_frame
	await _physics_seconds(0.3)
	player.linear_velocity = velocity
	player.angular_velocity = Vector3.ZERO
	await physics_frame
	await physics_frame


func _reset_player(position: Vector3) -> void:
	_release_all()
	player.gravity_scale = 1.8
	player.respawn(position)
	await _physics_seconds(0.3)
	player.linear_velocity = Vector3.ZERO
	player.angular_velocity = Vector3.ZERO


func _wait_for_bounce_ready() -> void:
	for _index in range(90):
		if player.is_grounded() and float(player.get("_bounce_cooldown_timer")) <= 0.0:
			return
		await physics_frame
	_check(false, "Player never became ready for a ground bounce")


func _wait_until(predicate: Callable, seconds: float) -> bool:
	for _index in range(maxi(1, int(ceil(seconds * 60.0)))):
		if predicate.call():
			return true
		await physics_frame
	return predicate.call()


func _physics_seconds(seconds: float) -> void:
	for _index in range(maxi(1, int(ceil(seconds * 60.0)))):
		await physics_frame


func _planar_speed() -> float:
	return Vector2(player.linear_velocity.x, player.linear_velocity.z).length()


func _max_of(values: Array[float]) -> float:
	var best := 0.0
	for value in values:
		best = maxf(best, value)
	return best


func _add_box(position: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = position
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	world.add_child(body)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
