extends SceneTree

## Product rules for the match format and rematch flow: the host picks
## first-to and round length within safe bounds, clients cannot override it,
## every clamp reads the chosen score, a rematch keeps the opponent while
## resetting only the scoreboard and brings the gameplay HUD back, every new
## round starts with cooldowns cleared, and Arena is the default duel map.

const MAIN_SCENE := preload("res://scenes/main.tscn")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := MAIN_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	var hud := game.get_node("HUD")

	var default_format := game.call("get_match_format") as Dictionary
	_expect(int(default_format.get("score_to_win", 0)) == 5, "Matches default to first to 5")
	game.call("set_match_format", 3, 90.0)
	var format := game.call("get_match_format") as Dictionary
	_expect(int(format.get("score_to_win", 0)) == 3 and is_equal_approx(float(format.get("round_seconds", 0.0)), 90.0), "The host can choose first-to and round length")
	_expect(str(hud.call("get_match_format_text")).begins_with("FIRST TO 3"), "The HUD must describe the chosen match format")
	game.call("set_match_format", 0, 5.0)
	format = game.call("get_match_format") as Dictionary
	_expect(int(format.get("score_to_win", 0)) == 1 and float(format.get("round_seconds", 0.0)) >= 30.0, "Match format must clamp to at least first to 1 and 30 second rounds")
	game.call("set_match_format", 99, 99999.0)
	format = game.call("get_match_format") as Dictionary
	_expect(int(format.get("score_to_win", 0)) == 15 and float(format.get("round_seconds", 0.0)) <= 600.0, "Match format must clamp to at most first to 15 and 10 minute rounds")
	game.call("set_match_format", 3, 120.0)
	_expect(is_equal_approx(float(game.get("_match_time_remaining")), 120.0), "Changing the round length before a match resets the clock")

	var bot_card := game.get_node("HUD/MainMenu").find_child("BotCard", true, false) as Node
	_expect(bot_card != null and bot_card.find_child("BotChoice", true, false) != null and bot_card.find_child("BotDifficulty", true, false) != null, "The menu must offer a bot duel with a difficulty picker")
	_expect(int(hud.call("get_bot_difficulty")) == 1, "Bot duels default to normal difficulty")
	_expect(hud.has_signal("bot_requested") and hud.has_signal("match_format_changed"), "The lobby must announce bot and format choices to the game")
	var match_setup := game.get_node("HUD/MainMenu").find_child("MatchSetup", true, false) as Node
	_expect(match_setup != null and match_setup.find_child("FormatButton", true, false) != null and match_setup.find_child("MapPicker", true, false) != null, "The menu's match setup must offer the map and the match format together")
	_expect(int(hud.call("get_selected_score_to_win")) == 5 and is_equal_approx(float(hud.call("get_selected_round_seconds")), 90.0), "Host format pickers default to first to 5 with 1:30 rounds")

	_expect(str(hud.call("get_selected_map_id")) == "skyline", "Arena must be the default duel map in the lobby")
	_expect(str(game.get("_selected_map_id")) == "skyline", "Arena must be the default duel map before the lobby is touched")

	# A bot duel exercises the rematch flow without a network peer.
	game.call("_start_bot_match", 1)
	await process_frame
	await process_frame
	var controller := game.get("_abilities") as Object
	var ability := controller.get("current") as Object
	var bot_state := game.get("_server_peers").call("state_for", 2) as Object
	var far_future := Time.get_ticks_msec() + 600000
	if ability != null:
		ability.set("ready_at", far_future)
	bot_state.set("ability_ready_at", far_future)
	bot_state.set("shot_ready_at", far_future)
	game.set("_round_countdown_active", false)
	game.call("_begin_synchronized_round_countdown")
	await process_frame
	_expect(ability == null or int(ability.get("ready_at")) == 0, "A new round must reset the player's ability cooldown")
	_expect(int(bot_state.get("ability_ready_at")) == 0 and int(bot_state.get("shot_ready_at")) == 0, "A new round must reset every duelist's cooldowns on the host")
	_expect(ability != null, "A bot duel must equip the player's ability so its cooldown can be checked")

	# The match ended: the victory screen hides the gameplay HUD.
	hud.call("begin_victory_cinematic")
	game.set("_red_score", 3)
	game.set("_blue_score", 1)
	game.set("_match_over", true)
	game.set("_round_countdown_active", false)
	game.call("_on_rematch_requested")
	await process_frame
	await process_frame
	_expect(int(game.get("_red_score")) == 0 and int(game.get("_blue_score")) == 0, "A rematch resets the scoreboard")
	_expect(not bool(game.get("_match_over")), "A rematch clears the match-over state")
	_expect(bool(game.get("_bot_active")), "A rematch keeps the opponent")
	_expect(game.get_node("RemotePlayers").get_node_or_null("Peer_2") != null, "A rematch keeps the opponent's body")
	_expect(bool(game.get("_round_countdown_active")), "A rematch starts a fresh round countdown")
	for hud_path in ["HealthPanel", "Crosshair"]:
		_expect((hud.get_node(hud_path) as CanvasItem).visible, "A rematch must bring back the gameplay HUD (%s)" % hud_path)
	var format_after := game.call("get_match_format") as Dictionary
	_expect(int(format_after.get("score_to_win", 0)) == 3, "A rematch keeps the chosen match format")

	game.call("_return_to_lobby")
	await process_frame
	game.queue_free()
	await process_frame
	if _failures.is_empty():
		print("MATCH FORMAT CONTRACT PASS")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
