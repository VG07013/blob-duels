extends SceneTree

## Product rules for the offline bot duel: the bot is a full duel participant
## (spawn slot, authoritative health, deaths, rounds), it fires through the
## host shot path with the host's fire-rate cap, every difficulty preset is
## complete and ordered, and leaving the match removes every trace of it.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const BOT_TUNING := preload("res://scripts/bot_tuning.gd")
const BOT_PEER_ID := 2

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_presets()
	await _test_bot_duel()
	if _failures.is_empty():
		print("BOT DUEL CONTRACT PASS")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_presets() -> void:
	var required := ["reaction_seconds", "aim_error_radians", "fire_interval", "prediction", "engage_range", "preferred_range", "range_slack", "turn_speed", "strafe_period", "strafe_weight", "bounce_chance_per_second", "fling_interval", "fling_charge_seconds", "fling_min_distance", "retreat_health_ratio", "blob_ram_range", "blob_commit_seconds", "blob_cooldown_seconds", "air_jump_skill", "dodge_skill", "slide_skill", "slam_skill"]
	for difficulty in [BOT_TUNING.DIFFICULTY_EASY, BOT_TUNING.DIFFICULTY_NORMAL, BOT_TUNING.DIFFICULTY_HARD]:
		var preset := BOT_TUNING.preset_for(difficulty)
		for key in required:
			_expect(preset.has(key), "Bot difficulty %d must define %s" % [difficulty, key])
	var easy := BOT_TUNING.preset_for(BOT_TUNING.DIFFICULTY_EASY)
	var normal := BOT_TUNING.preset_for(BOT_TUNING.DIFFICULTY_NORMAL)
	var hard := BOT_TUNING.preset_for(BOT_TUNING.DIFFICULTY_HARD)
	_expect(float(easy["reaction_seconds"]) > float(normal["reaction_seconds"]) and float(normal["reaction_seconds"]) > float(hard["reaction_seconds"]), "Harder bots must react faster")
	_expect(float(easy["aim_error_radians"]) > float(normal["aim_error_radians"]) and float(normal["aim_error_radians"]) > float(hard["aim_error_radians"]), "Harder bots must aim tighter")
	_expect(float(easy["fire_interval"]) > float(normal["fire_interval"]) and float(normal["fire_interval"]) > float(hard["fire_interval"]), "Harder bots must fire more often")
	_expect(float(easy["air_jump_skill"]) < float(normal["air_jump_skill"]) and float(normal["air_jump_skill"]) <= float(hard["air_jump_skill"]), "Harder bots must use Blob air jumps more reliably")
	_expect(float(easy["prediction"]) < float(normal["prediction"]) and float(normal["prediction"]) <= float(hard["prediction"]), "Harder bots must lead a moving target more accurately")
	_expect(float(easy["dodge_skill"]) < float(normal["dodge_skill"]) and float(normal["dodge_skill"]) < float(hard["dodge_skill"]), "Harder bots must dodge incoming shots more often")
	_expect(float(easy["turn_speed"]) < float(normal["turn_speed"]) and float(normal["turn_speed"]) < float(hard["turn_speed"]), "Harder bots must turn onto the target faster")
	_expect(BOT_TUNING.difficulty_from_id("hard") == BOT_TUNING.DIFFICULTY_HARD and BOT_TUNING.difficulty_from_id("nope") == BOT_TUNING.DEFAULT_DIFFICULTY, "Unknown difficulty ids must fall back to the default")
	_expect(BOT_TUNING.preset_for(99) == BOT_TUNING.preset_for(BOT_TUNING.DIFFICULTY_HARD), "Out-of-range difficulties must clamp to the nearest preset")


func _test_bot_duel() -> void:
	var game := MAIN_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.call("_start_bot_match", BOT_TUNING.DIFFICULTY_NORMAL)
	await process_frame
	await process_frame
	var remote_players := game.get_node("RemotePlayers") as Node
	var bot_body := remote_players.get_node_or_null("Peer_%d" % BOT_PEER_ID) as RigidBody3D
	_expect(bool(game.get("_bot_active")), "Starting a bot match must mark the bot active")
	_expect(bot_body != null, "A bot duel must spawn the bot as remote peer %d" % BOT_PEER_ID)
	_expect((game.get("_peer_spawn_slots") as Dictionary).has(BOT_PEER_ID), "The bot must own a spawn slot like a connected peer")
	_expect(bool(game.call("_duel_has_opponent")), "A bot counts as an opponent so rounds can start offline")
	_expect(bool(game.call("_is_duel_participant", BOT_PEER_ID)), "The bot must be a duel participant for hits and deaths")
	_expect(not bool(game.get("_practice_mode")), "A bot duel is a duel, never practice")
	if bot_body == null:
		game.queue_free()
		await process_frame
		return
	_expect(str(bot_body.get("display_name")) == BOT_TUNING.BOT_DISPLAY_NAME, "The bot must be named so the roster can show it")
	_expect(bool(bot_body.get("local_controlled")) and not bool(bot_body.get("input_enabled")), "The bot body must simulate locally without reading player input")
	_expect(bool(game.get("_round_countdown_active")), "A bot duel must begin its round countdown without waiting for a peer")
	# Countdown is three real seconds; give it a little slack.
	await create_timer(3.6).timeout
	var bot := game.get_node_or_null("BotOpponent")
	_expect(bot != null and bool(bot.call("is_round_active")), "The bot must start acting when the round goes live")
	_expect(not bot_body.freeze, "The bot body must thaw on GO")
	_expect(bool(game.get("_match_timer_running")), "The round clock must run during a bot duel")

	var projectiles := game.get_node("Projectiles") as Node
	var before := projectiles.get_child_count()
	game.call("_on_bot_shot_requested", bot_body.global_position + Vector3(0.0, 0.5, 3.0), Vector3.FORWARD)
	game.call("_on_bot_shot_requested", bot_body.global_position + Vector3(0.0, 0.5, 3.0), Vector3.FORWARD)
	_expect(projectiles.get_child_count() == before + 1, "Bot shots must respect the host fire-rate cap (one projectile per cooldown)")

	var registry = game.get("_server_peers")
	var bot_state = registry.call("state_for", BOT_PEER_ID)
	var full_health := int(bot_state.get("health"))
	game.call("_apply_server_peer_impact", BOT_PEER_ID, 30, Vector3(0.0, 0.0, 20.0), true)
	_expect(int(bot_state.get("health")) == full_health - 30, "Damage to the bot must land on its authoritative state")
	_expect(int(bot_body.get("health")) == full_health - 30, "The bot body must show the authoritative health")

	var red_before := int(game.get("_red_score"))
	for _hit in range(6):
		game.call("_apply_server_peer_impact", BOT_PEER_ID, 60, Vector3(0.0, 0.0, 20.0), true)
	await create_timer(0.35).timeout
	_expect(int(game.get("_red_score")) == red_before + 1, "Eliminating the bot must score the round for the player")
	_expect(bot != null and not bool(bot.call("is_round_active")), "The bot must stop acting while a round resolves")

	game.call("_return_to_lobby")
	await process_frame
	await process_frame
	_expect(not bool(game.get("_bot_active")), "Returning to the lobby must end the bot match")
	_expect(remote_players.get_node_or_null("Peer_%d" % BOT_PEER_ID) == null, "Returning to the lobby must remove the bot body")
	_expect(game.get_node_or_null("BotOpponent") == null, "Returning to the lobby must remove the bot controller")
	_expect(not (game.get("_peer_spawn_slots") as Dictionary).has(BOT_PEER_ID), "Returning to the lobby must free the bot's spawn slot")
	game.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
