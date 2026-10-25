extends SceneTree

## Product rules for the duel's top bar and round flow: rounds last 1:30, a
## timeout goes to the blob with more health and a tie is settled at random
## (never a draw), the countdown and the round result both live in the timer
## box, a result grows the box and colours it green/red with ROUND WON! /
## ROUND LOST, the losing blob vanishes until the next countdown, and team 0
## is presented as Orange.

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
	_expect(is_equal_approx(float(game.get("match_duration")), 90.0), "Every round must last a minute and thirty seconds")
	await _test_timer_box(hud)
	_test_timeout_tie_never_draws(game)
	await _test_round_loser_vanishes(game)
	_test_orange_team(game)
	game.queue_free()
	await process_frame
	if _failures.is_empty():
		print("MATCH BAR CONTRACT PASS")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_timer_box(hud: Node) -> void:
	hud.call("set_lobby_mode", false)
	hud.call("set_duel_mode", true)
	var bar = hud.call("get_match_bar")
	hud.call("set_match_time", 90.0)
	_expect(str(bar.call("get_timer_text")) == "1:30", "The timer box must show the round clock as m:ss")
	hud.call("show_countdown_beat", "2")
	_expect(str(bar.call("get_timer_text")) == "2", "Countdown beats must show in the timer box")
	var spacer := hud.get_node("Scoreboard/Target") as Control
	var resting_width := spacer.custom_minimum_size.x
	hud.call("show_round_result", DuelHud.ROUND_RESULT_WON)
	# Animations are timed in seconds, and headless frames outrun real time.
	await create_timer(0.8).timeout
	_expect(str(bar.call("get_timer_text")) == "ROUND WON!", "Winning a round must read ROUND WON! in the timer box")
	_expect(spacer.custom_minimum_size.x > resting_width * 2.0, "A round result must grow the timer box well past its normal size")
	var style := (hud.get_node("TimerLabel") as Label).get_theme_stylebox("normal") as StyleBoxFlat
	_expect(style != null and style.bg_color.g > style.bg_color.r and style.bg_color.g > 0.5, "A won round must turn the box green")
	hud.call("show_countdown_beat", "1")
	_expect(str(bar.call("get_timer_text")) == "ROUND WON!", "A late countdown beat must not overwrite the round result")
	hud.call("reset_round_result")
	hud.call("show_round_result", DuelHud.ROUND_RESULT_LOST)
	# Animations are timed in seconds, and headless frames outrun real time.
	await create_timer(0.8).timeout
	_expect(str(bar.call("get_timer_text")) == "ROUND LOST", "Losing a round must read ROUND LOST in the timer box")
	_expect(style != null and style.bg_color.r > style.bg_color.g and style.bg_color.r > 0.5, "A lost round must turn the box red")
	hud.call("reset_round_result")
	await create_timer(0.6).timeout
	_expect(is_equal_approx(spacer.custom_minimum_size.x, resting_width), "The timer box must shrink back for the next round")


func _test_timeout_tie_never_draws(game: Node) -> void:
	for attempt in 6:
		game.set("_practice_mode", false)
		game.set("arena_started", true)
		game.set("_peer_spawn_slots", {1: 0, 2: 1})
		var server_peers = game.get("_server_peers")
		(game.get_node("Player") as Node).set("health", 80)
		server_peers.state_for(2).health = 80
		game.set("_red_score", 0)
		game.set("_blue_score", 0)
		game.set("_round_resolving", false)
		game.set("_match_over", false)
		game.call("_resolve_duel_timeout")
		var total := int(game.get("_red_score")) + int(game.get("_blue_score"))
		_expect(total == 1, "A timeout with equal health must still hand one team the round, never a draw")


func _test_round_loser_vanishes(game: Node) -> void:
	game.call("_start_bot_match", 1)
	for frame in 10:
		await process_frame
	var bot := game.get_node("RemotePlayers").get_child(0) as Node3D
	var visual := bot.get_node("VisualRoot") as Node3D
	game.set("_bot", null)
	game.call("_apply_round_result", 1, 0, 0, false, false)
	_expect(not visual.visible, "The blob that lost the round must disappear")
	game.call("_restore_round_losers")
	_expect(visual.visible, "The losing blob must come back for the next round")


func _test_orange_team(game: Node) -> void:
	var constants := (game.get_script() as Script).get_script_constant_map()
	var orange := constants["RED_TEAM_COLOR"] as Color
	_expect(orange.r > 0.9 and orange.g > 0.35 and orange.g < 0.7 and orange.b < 0.25, "Team 0 must be the Orange team")
	var roster := game.call("_build_match_roster") as Array
	for entry in roster:
		_expect(str((entry as Dictionary).get("team_name", "")) != "RED", "No player may be shown on a RED team any more")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
