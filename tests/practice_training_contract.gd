extends SceneTree

## The practice map is a training facility, not a duel arena. This contract
## protects the training rules the blueprint spec sets out: what a dummy does
## when nobody has configured it, how each behaviour mode is allowed to move,
## what the health presets mean, and what the practice HUD is counting.

const DUMMY_SCENE := preload("res://scenes/player/dummy_blob.tscn")
const SESSION_SCRIPT := preload("res://scripts/practice_session.gd")
const TRAINING := preload("res://scripts/practice_training.gd")
const GEOMETRY := preload("res://scripts/environment/practice_facility_geometry.gd")
const AIM_STAND_IN := preload("res://tests/support/aim_stand_in.gd")
const MAIN_SCENE := preload("res://scenes/main.tscn")

var failures: Array[String] = []
var world: Node3D


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	world = Node3D.new()
	root.add_child(world)
	_add_floor()

	_check_defaults()
	await _check_health_presets()
	await _check_defeat_and_respawn()
	await _check_static_holds_station()
	await _check_strafe_lane()
	await _check_bounce_leash()
	await _check_dodge_discipline()
	await _check_combat_gate()
	_check_session_statistics()
	_check_session_applies_config()
	await _check_practice_state_never_leaks()

	world.queue_free()
	if failures.is_empty():
		print("PRACTICE TRAINING CONTRACT PASSED")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("PRACTICE TRAINING FAILURES: %d" % failures.size())
	quit(1)


## A dummy nobody has configured must be a still target with a health pool that
## never runs out - that is what "static and infinite by default" buys.
func _check_defaults() -> void:
	var dummy := _spawn_dummy(Vector3.ZERO)
	_check(dummy.training_mode == TRAINING.MODE_STATIC,
		"Training dummies must default to static mode for basic aim practice")
	_check(dummy.has_infinite_health(),
		"Training dummies must default to infinite health so practice never stops for a respawn")
	_check(is_equal_approx(dummy.respawn_delay, 1.5),
		"A defeated dummy must return after exactly 1.5 seconds")
	dummy.queue_free()


## Infinite absorbs, the finite pools drain, and one-hit means one hit.
func _check_health_presets() -> void:
	var dummy := _spawn_dummy(Vector3(0, 3, 0))
	await process_frame
	dummy.take_damage(60, Vector3.RIGHT, 0.0)
	_check(dummy.health == dummy.max_health,
		"Infinite health must absorb damage without draining the dummy's bar")

	for preset in [100, 250, 500]:
		dummy.set_health_preset(preset)
		_check(dummy.max_health == preset,
			"Selecting the %d health preset must give the dummy exactly that pool" % preset)
		dummy.take_damage(40, Vector3.RIGHT, 0.0)
		_check(dummy.health == preset - 40,
			"The %d health preset must take real damage" % preset)

	dummy.set_health_preset(TRAINING.HEALTH_ONE_HIT)
	dummy.take_damage(1, Vector3.RIGHT, 0.0)
	_check(dummy.health <= 0, "One-hit mode must drop the dummy on a single hit")
	dummy.queue_free()
	await process_frame


## Defeat pops the dummy off the field, then puts it back on its own station at
## full health - no drift, no rewards.
func _check_defeat_and_respawn() -> void:
	var station := Vector3(6.0, 3.0, -4.0)
	var dummy := _spawn_dummy(station)
	await process_frame
	dummy.set_health_preset(TRAINING.HEALTH_ONE_HIT)
	dummy.take_damage(5, Vector3.RIGHT, 0.0)
	await process_frame
	_check(dummy.collision_layer == 0,
		"A popped dummy must stop absorbing shots while it is away")
	var visual := dummy.get_node_or_null("VisualRoot") as Node3D
	_check(visual != null and not visual.visible, "A defeated dummy must visibly pop rather than stand there dead")

	dummy.respawn()
	await process_frame
	_check(dummy.health == dummy.max_health, "A respawned dummy must come back at full health")
	_check(dummy.global_position.distance_to(station) < 0.05,
		"A respawned dummy must return to its own blueprint station")
	_check(dummy.collision_layer == 2, "A respawned dummy must be shootable again")
	dummy.queue_free()
	await process_frame


func _check_static_holds_station() -> void:
	var station := Vector3(0, 3.0, 0)
	var dummy := _spawn_dummy(station)
	dummy.configure_training(TRAINING.MODE_STATIC, TRAINING.DEFAULT_HEALTH, true, false, true, 1.0)
	await _physics_seconds(1.5)
	_check(_flat_distance(dummy.global_position, station) < 0.6,
		"Static dummies must hold their station so basic aim practice has a fixed target")
	dummy.queue_free()
	await process_frame


## Strafe walks a ~3 GU lane. The dummy has to actually travel, and it must not
## wander outside the lane the spec gives it.
func _check_strafe_lane() -> void:
	var station := Vector3(0, 3.0, 0)
	var dummy := _spawn_dummy(station)
	dummy.configure_training(TRAINING.MODE_STRAFE, TRAINING.DEFAULT_HEALTH, true, false, true, 1.0)
	var travelled := 0.0
	for _step in range(8):
		await _physics_seconds(0.5)
		travelled = maxf(travelled, _flat_distance(dummy.global_position, station))
		_check(_flat_distance(dummy.global_position, station) <= TRAINING.STRAFE_HALF_LANE + GEOMETRY.GU * 0.5,
			"A strafing dummy must stay inside its 3 GU lane, not wander the arena")
	_check(travelled > GEOMETRY.GU * 0.5,
		"A strafing dummy must actually move across its lane")
	dummy.queue_free()
	await process_frame


## Bounce is for vertical tracking: the dummy must leave the ground and stay
## inside its 2.5 GU bubble instead of launching away.
func _check_bounce_leash() -> void:
	var station := Vector3(0, 3.0, 0)
	var dummy := _spawn_dummy(station)
	dummy.configure_training(TRAINING.MODE_BOUNCE, TRAINING.DEFAULT_HEALTH, true, false, true, 1.0)
	var peak := -INF
	var drift := 0.0
	for _step in range(12):
		await _physics_seconds(0.25)
		peak = maxf(peak, dummy.global_position.y)
		drift = maxf(drift, _flat_distance(dummy.global_position, station))
	_check(peak > station.y + 0.5, "A bouncing dummy must leave the ground for vertical tracking practice")
	_check(peak < station.y + GEOMETRY.BLOB_DIAMETER * 2.0,
		"Bounce mode must stay a controlled hop, not a launch to the canopy")
	_check(drift <= TRAINING.BOUNCE_LEASH,
		"A bouncing dummy must stay within 2.5 GU of its station")
	dummy.queue_free()
	await process_frame


## Dodge must be a reaction, not a fidget: nothing happens until the player has
## held a direct aim, and then only one hop per cooldown.
func _check_dodge_discipline() -> void:
	var station := Vector3(0, 3.0, 0)
	var dummy := _spawn_dummy(station)
	dummy.configure_training(TRAINING.MODE_DODGE, TRAINING.DEFAULT_HEALTH, true, false, true, 1.0)

	var looker := AIM_STAND_IN.new() as Node3D
	looker.name = "AimStandIn"
	world.add_child(looker)
	looker.global_position = station + Vector3(0, 0, 24.0)
	dummy.set_practice_target(looker)

	# Nobody aiming at it yet: the stand-in looks the other way.
	looker.aim_direction = Vector3(1, 0, 0)
	await _physics_seconds(1.2)
	_check(_flat_distance(dummy.global_position, station) < 0.6,
		"A dodge dummy must sit still until the player actually aims at it")

	looker.aim_direction = (station - looker.global_position).normalized()
	await _physics_seconds(TRAINING.DODGE_AIM_DWELL + 0.45)
	var dodged := _flat_distance(dummy.global_position, station)
	_check(dodged > 0.5, "A dodge dummy must break a sustained lock with a sidestep")
	_check(dodged <= TRAINING.DODGE_LEASH + GEOMETRY.GU,
		"Dodges must stay short and predictable, not carry the dummy off its station")
	dummy.queue_free()
	looker.queue_free()
	await process_frame


## Combat mode is the only mode that shoots back, and the panel's shooting
## toggle has to be able to silence it.
func _check_combat_gate() -> void:
	var station := Vector3(0, 3.0, 0)
	var dummy := _spawn_dummy(station)
	var shots: Array[Vector3] = []
	dummy.shot_requested.connect(func(origin: Vector3, _direction: Vector3) -> void: shots.append(origin))

	var looker := AIM_STAND_IN.new() as Node3D
	looker.name = "CombatStandIn"
	world.add_child(looker)
	looker.global_position = station + Vector3(0, 0, 20.0)
	dummy.set_practice_target(looker)

	dummy.configure_training(TRAINING.MODE_COMBAT, TRAINING.DEFAULT_HEALTH, true, false, true, 1.0)
	await _physics_seconds(TRAINING.COMBAT_FIRE_INTERVAL + 0.5)
	_check(shots.is_empty(), "Turning dummy shooting off must silence combat mode entirely")

	dummy.configure_training(TRAINING.MODE_COMBAT, TRAINING.DEFAULT_HEALTH, true, true, true, 1.0)
	await _physics_seconds(TRAINING.COMBAT_FIRE_INTERVAL + 0.5)
	_check(not shots.is_empty(), "Combat mode must return fire so the player can practise moving under pressure")

	# Other modes never shoot - combat is the only pressure mode.
	shots.clear()
	dummy.configure_training(TRAINING.MODE_STATIC, TRAINING.DEFAULT_HEALTH, true, true, true, 1.0)
	await _physics_seconds(TRAINING.COMBAT_FIRE_INTERVAL + 0.5)
	_check(shots.is_empty(), "Static dummies must never shoot back")

	dummy.queue_free()
	looker.queue_free()
	await process_frame


## The practice HUD's numbers all come from the session, so the session is where
## the accuracy, streak, and combo rules are pinned down.
func _check_session_statistics() -> void:
	var session := SESSION_SCRIPT.new() as PracticeSession
	world.add_child(session)
	session.begin(null, [] as Array[DummyBlob])

	_check(session.dummy_mode == TRAINING.MODE_STATIC and session.dummy_health_preset == TRAINING.HEALTH_INFINITE,
		"A fresh practice session must start on the spec's defaults: static dummies, infinite health")
	_check(not session.dummy_damage_enabled,
		"Dummy return fire must be harmless until the player turns damage on")

	session.note_shot_fired()
	session.note_dummy_hit(30)
	session.note_shot_fired()
	session.note_dummy_hit(20)
	_check(session.shots_fired == 2 and session.shots_hit == 2, "Every shot and hit must be counted")
	_check(is_equal_approx(session.get_accuracy(), 100.0), "Two hits from two shots must read as 100% accuracy")
	_check(session.damage_dealt == 50, "Damage dealt must total every hit")
	_check(session.current_streak == 2 and session.best_streak == 2, "Consecutive hits must build the streak")

	session.note_shot_fired()
	session.note_shot_missed()
	_check(session.current_streak == 0, "A miss must break the current streak")
	_check(session.best_streak == 2, "A miss must not erase the best streak of the run")
	_check(absf(session.get_accuracy() - 66.6667) < 0.01, "Accuracy must be hits over shots fired")
	_check(session.best_combo >= 2, "Chained hits must register as a combo")

	session.reset_stats()
	_check(session.shots_fired == 0 and session.shots_hit == 0 and session.damage_dealt == 0
		and session.best_streak == 0 and session.best_combo == 0 and is_equal_approx(session.elapsed_time, 0.0),
		"Reset statistics must clear the whole run, not just part of it")

	session.end()
	_check(not session.is_active(), "Leaving practice must stop the session counting")
	session.queue_free()


## One panel drives all eight stations - that is why the spec bans eight
## physical terminals.
func _check_session_applies_config() -> void:
	var session := SESSION_SCRIPT.new() as PracticeSession
	world.add_child(session)
	var dummies: Array[DummyBlob] = []
	for index in range(8):
		var dummy := _spawn_dummy(Vector3(float(index) * 8.0, 3.0, 0.0))
		dummies.append(dummy)
	session.begin(null, dummies)

	session.set_dummy_mode(TRAINING.MODE_STRAFE)
	session.set_dummy_health_preset(250)
	session.set_damage_numbers_enabled(false)
	session.set_dummy_speed_scale(1.5)
	for dummy in dummies:
		_check(dummy.training_mode == TRAINING.MODE_STRAFE,
			"%s must follow the shared behaviour set on the practice panel" % dummy.name)
		_check(dummy.max_health == 250, "%s must follow the shared health preset" % dummy.name)
		_check(not dummy.damage_numbers_enabled, "%s must honour the damage-number toggle" % dummy.name)
		_check(is_equal_approx(dummy.speed_scale, 1.5), "%s must follow the shared movement speed" % dummy.name)

	session.set_dummy_movement_enabled(false)
	for dummy in dummies:
		_check(not dummy.movement_enabled, "%s must freeze when dummy movement is toggled off" % dummy.name)

	session.end()
	session.queue_free()
	for dummy in dummies:
		dummy.queue_free()


## Practice is a mode the player leaves. Nothing it switches on - the control
## panel, its aim lock, the training-only player switches - may survive the trip
## back to the lobby, or the next duel starts crippled.
func _check_practice_state_never_leaks() -> void:
	var game := MAIN_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	game._start_practice_match()
	await process_frame

	var hud := game.get_node("PracticeHud") as PracticeHud
	var session := game.get_node("PracticeSession") as PracticeSession
	var arena_player := game.get_node("Player") as BlobPlayer
	_check(hud.visible, "The practice HUD must be on screen while training")
	_check(session.is_active(), "Entering practice must start the session counting")

	hud.set_panel_open(true)
	session.set_infinite_ammo(true)
	session.set_cooldowns_enabled(false)
	await process_frame
	_check(arena_player.practice_unlimited_shots,
		"The infinite ammo switch must actually reach the player")
	_check(arena_player.practice_skip_cooldowns,
		"The cooldown switch must actually reach the player")

	game._return_to_lobby()
	await process_frame
	_check(not session.is_active(), "Leaving practice must stop the session")
	_check(not hud.visible, "The practice HUD must never show outside practice")
	_check(not hud.is_panel_open(), "The practice control panel must close on the way out")
	_check(not arena_player.practice_unlimited_shots and not arena_player.practice_skip_cooldowns,
		"Training switches must not follow the player into a duel")
	_check(not bool(arena_player.get("_shooting_locked")),
		"Leaving practice with the panel open must not leave the player unable to shoot")

	game.queue_free()
	await process_frame


func _spawn_dummy(spawn_position: Vector3) -> DummyBlob:
	var dummy := DUMMY_SCENE.instantiate() as DummyBlob
	dummy.position = spawn_position
	world.add_child(dummy)
	return dummy


func _flat_distance(actual: Vector3, expected: Vector3) -> float:
	return Vector2(actual.x - expected.x, actual.z - expected.z).length()


func _physics_seconds(seconds: float) -> void:
	var frames := maxi(1, int(ceil(seconds * 60.0)))
	for _index in range(frames):
		await physics_frame


func _add_floor() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.name = "TrainingFloor"
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(200, 2, 200)
	collision.shape = shape
	collision.position.y = -1.0
	floor_body.add_child(collision)
	world.add_child(floor_body)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
