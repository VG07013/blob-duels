extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")

const ACTIVATION_BANNERS := [
	"DASH!",
	"RICOCHET LOADED",
	"BLINK",
	"SCAN PULSE",
	"OVERCHARGE",
	"GRAVITY PULSE",
	"RAIL CHARGING",
	"RAIL SHOT",
	"MINE DEPLOYED",
	"PHASE BUBBLE",
	"ADRENALINE ARMS",
]

const ACTIVE_ABILITIES := [
	"dash",
	"ricochet_shot",
	"blink",
	"target_scanner",
	"overcharge",
	"gravity_pulse",
	"rail_shot",
	"bounce_mine",
	"phase_bubble",
]

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := MAIN_SCENE.instantiate()
	root.add_child(game)
	await process_frame

	_test_practice_has_no_clock(game)
	_test_host_room_code_bridge(game)
	_test_health_timeout_is_authoritative(game)
	_test_ability_feedback_is_audio_only()

	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("DUEL PAUSE ABILITY CONTRACT PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _test_practice_has_no_clock(game: Node) -> void:
	game.call("_start_practice_match")
	var timer := game.get_node("HUD/TimerLabel") as CanvasItem
	_check(not bool(game.get("_match_timer_running")), "Practice must never run the duel timer")
	_check(not timer.visible, "Practice must hide the duel timer")
	var remaining := float(game.get("_match_time_remaining"))
	game.call("_update_match_timer", 5.0)
	_check(is_equal_approx(float(game.get("_match_time_remaining")), remaining), "Practice time must not tick down even if timer state is stale")


func _test_host_room_code_bridge(game: Node) -> void:
	var session := root.get_node("NetworkSession")
	game.set("_practice_mode", false)
	session.set("state", 1) # NetworkSession.SessionState.HOSTING
	var code := str(game.call("_room_code_for_pause"))
	_check(not code.is_empty(), "A host must expose its shareable room code to the Escape menu")
	_check(code.length() == 9 and code.substr(4, 1) == "-", "Escape-menu room code must use the same XXXX-XXXX join format")
	game.call("_open_pause")
	var pause := game.get_node("PauseMenu")
	var card := pause.get_node("PausePanel/Content/Pages/MatchPage/Stack/HostCodeCard") as CanvasItem
	var value := pause.get_node("PausePanel/Content/Pages/MatchPage/Stack/HostCodeCard/Row/Copy/HostCodeValue") as Label
	_check(card.visible and value.text == code, "Opening the host Escape menu must render the current shareable code")
	game.call("_resume_from_pause")
	session.set("state", 0)
	_check(str(game.call("_room_code_for_pause")).is_empty(), "Non-host Escape menus must not expose a stale host code")
	game.call("_open_pause")
	_check(not card.visible, "Opening a non-host Escape menu must clear the previous host code")
	game.call("_resume_from_pause")


func _test_health_timeout_is_authoritative(game: Node) -> void:
	game.set("_practice_mode", false)
	game.set("arena_started", true)
	game.set("_peer_spawn_slots", {1: 0, 2: 1})
	var server_peers = game.get("_server_peers")
	server_peers.state_for(1).health = 100
	server_peers.state_for(2).health = 34
	game.set("_red_score", 0)
	game.set("_blue_score", 0)
	game.set("_round_resolving", false)
	game.set("_match_over", false)
	game.call("_resolve_duel_timeout")
	_check(int(game.get("_red_score")) == 1 and int(game.get("_blue_score")) == 0, "Timeout must award the round to the team with more authoritative health")
	_check(bool(game.get("_round_resolving")), "Timeout result must enter the synchronized round-result state")


func _test_ability_feedback_is_audio_only() -> void:
	var game_source := FileAccess.get_file_as_string("res://scripts/game.gd")
	for banner in ACTIVATION_BANNERS:
		_check(not game_source.contains("hud.show_announcement(\"%s" % banner), "Ability activation banner still exists: %s" % banner)
	var audio_manager := root.get_node("AudioManager")
	var signatures: Dictionary = {}
	for ability in ACTIVE_ABILITIES:
		var signature := str(audio_manager.call("get_ability_sfx_signature", ability))
		_check(not signature.is_empty(), "%s needs an activation sound" % ability)
		_check(not signatures.has(signature), "%s shares its activation sound with %s" % [ability, signatures.get(signature, "another ability")])
		signatures[signature] = ability


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
