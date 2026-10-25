extends SceneTree

## Product rules for the bot as a duel opponent: it drives its body through
## the same controls a player has (never raw forces), it closes on a target
## it can see instead of standing still, it turns to face that target, and a
## shot it sees coming makes it sidestep. Difficulty is data, so the hard
## preset is used throughout and the rng is seeded for repeatable rolls.

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const PROJECTILE_SCENE := preload("res://scenes/player/projectile.tscn")
const BOT_OPPONENT := preload("res://scripts/bot_opponent.gd")
const BOT_TUNING := preload("res://scripts/bot_tuning.gd")

var _failures: Array[String] = []
var _world: Node3D
var _projectiles: Node3D


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_world = Node3D.new()
	root.add_child(_world)
	_projectiles = Node3D.new()
	_projectiles.name = "Projectiles"
	_world.add_child(_projectiles)
	_add_floor()
	_test_virtual_input_edges()
	await _test_bot_drives_through_controls()
	await _test_bot_closes_and_faces()
	await _test_bot_dodges_incoming_shot()
	if _failures.is_empty():
		print("BOT BEHAVIOUR CONTRACT PASS")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_virtual_input_edges() -> void:
	var controls := BlobVirtualInput.new()
	controls.press("bounce")
	_expect(controls.is_pressed("bounce") and controls.is_just_pressed("bounce"), "A press must read as held and as a press edge")
	controls.end_frame()
	_expect(controls.is_pressed("bounce") and not controls.is_just_pressed("bounce"), "After the body reads a frame the press edge clears but the hold stays")
	controls.release("bounce")
	_expect(controls.is_just_released("bounce") and not controls.is_pressed("bounce"), "A release must read as a release edge")
	controls.tap("brake")
	_expect(controls.is_just_pressed("brake") and controls.is_just_released("brake") and not controls.is_pressed("brake"), "A tap must show both edges and no hold")


func _test_bot_drives_through_controls() -> void:
	var bot_body := await _spawn_player(Vector3(0, 2.9, 0))
	bot_body.set_input_enabled(false)
	var target := await _spawn_player(Vector3(0, 2.9, -30))
	target.set_input_enabled(false)
	var bot := _make_bot(bot_body, target)
	bot.set_round_active(true)
	for frame in 10:
		await physics_frame
	_expect(bot_body.virtual_input == bot.controls, "The bot must drive its body through BlobVirtualInput, not forces")
	_expect(bot.controls.move.length() > 0.5, "A bot that sees a distant target must push its movement stick toward it")
	_cleanup([bot, bot_body, target])
	await process_frame


func _test_bot_closes_and_faces() -> void:
	var bot_body := await _spawn_player(Vector3(0, 2.9, 0))
	bot_body.set_input_enabled(false)
	var target := await _spawn_player(Vector3(30, 2.9, -30))
	target.set_input_enabled(false)
	target.freeze = true
	var bot := _make_bot(bot_body, target)
	bot.set_round_active(true)
	var start_distance := bot_body.global_position.distance_to(target.global_position)
	var peak_speed := 0.0
	var closest := start_distance
	var facing_dot := -1.0
	for frame in int(2.5 * 60.0):
		await physics_frame
		if frame == 30:
			# Half a second in, still well short of the target: it must be looking at it.
			var toward := target.global_position - bot_body.global_position
			var facing := -Basis(Vector3.UP, bot_body.aim_yaw).z
			facing_dot = facing.dot(Vector3(toward.x, 0.0, toward.z).normalized())
		peak_speed = maxf(peak_speed, Vector3(bot_body.linear_velocity.x, 0.0, bot_body.linear_velocity.z).length())
		closest = minf(closest, bot_body.global_position.distance_to(target.global_position))
	_expect(peak_speed > 8.0, "The bot must actually roll (peak planar speed %.1f)" % peak_speed)
	# It rams straight through and may fly past, so judge the closest approach.
	_expect(closest < start_distance - 20.0, "A bot out of its engage band must close on the target (start %.1f, closest %.1f)" % [start_distance, closest])
	_expect(facing_dot > 0.9, "The bot must turn to face its target (dot %.2f)" % facing_dot)
	_cleanup([bot, bot_body, target])
	await process_frame


func _test_bot_dodges_incoming_shot() -> void:
	var bot_body := await _spawn_player(Vector3(0, 2.9, 0))
	bot_body.set_input_enabled(false)
	var target := await _spawn_player(Vector3(0, 2.9, -40))
	target.set_input_enabled(false)
	target.freeze = true
	var bot := _make_bot(bot_body, target)
	(bot.get("_rng") as RandomNumberGenerator).seed = 7
	bot.set_round_active(true)
	await physics_frame
	# A shot from the target, flying straight at the bot's body.
	var shot := PROJECTILE_SCENE.instantiate()
	_projectiles.add_child(shot)
	shot.configure(Vector3(0, 2.9, -30), Vector3.BACK, target, false)
	var dodged := false
	var dodge_direction := Vector3.ZERO
	for frame in 12:
		await physics_frame
		if float(bot.get("_dodge_timer")) > 0.0:
			dodged = true
			dodge_direction = bot.get("_dodge_direction")
			break
	_expect(dodged, "A hard bot must react to a shot flying at it")
	_expect(absf(dodge_direction.x) > 0.9, "The dodge must cross the shot's line, not run along it")
	_expect(bot.controls.move.length() > 0.5, "A dodge must move the stick")
	_cleanup([bot, bot_body, target])
	await process_frame


func _make_bot(bot_body: BlobPlayer, target: Node3D) -> BotOpponent:
	var bot := BOT_OPPONENT.new()
	_world.add_child(bot)
	bot.configure(bot_body, target, BOT_TUNING.DIFFICULTY_HARD, func(_p: Vector3) -> bool: return false, Vector3.ZERO, _projectiles)
	return bot


func _spawn_player(position: Vector3) -> BlobPlayer:
	var blob := PLAYER_SCENE.instantiate() as BlobPlayer
	_world.add_child(blob)
	blob.configure_local(1)
	blob.global_position = position
	await physics_frame
	return blob


func _cleanup(nodes: Array) -> void:
	for node in nodes:
		(node as Node).queue_free()


func _add_floor() -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(400, 2, 400)
	shape.shape = box
	shape.position = Vector3(0, -1, 0)
	body.add_child(shape)
	_world.add_child(body)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
