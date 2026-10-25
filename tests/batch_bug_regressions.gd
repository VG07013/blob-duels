extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const HUD_SCENE := preload("res://scenes/hud.tscn")
const BOUNCE_MINE_SCENE := preload("res://scenes/effects/bounce_mine.tscn")

const GAME_SOURCE_PATH := "res://scripts/game.gd"
const AUDIO_BUSES := [&"Master", &"Music", &"SFX"]

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_network_replication_contracts()
	await _test_invalid_room_code_clears_session()
	await _test_progression_hud_contracts()
	await _test_game_runtime_contracts()

	if failures.is_empty():
		print("BATCH BUG REGRESSIONS PASS: network authority, progression feedback, audio, identity, scanner")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _test_network_replication_contracts() -> void:
	var source := FileAccess.get_file_as_string(GAME_SOURCE_PATH)
	_check(not source.is_empty(), "Regression setup: game.gd could not be read")

	var spawn_mine_source := _function_source(source, "_server_spawn_bounce_mine")
	_check(
		"_replicate_bounce_mine.rpc" in spawn_mine_source and "func _replicate_bounce_mine" in source,
		"BUG 1: a host bounce mine has no authority RPC path, so clients never see its deployment"
	)

	# Abilities live in scripts/abilities/, one file each; the rules below
	# guard the same replication order they enforced when the logic sat in
	# game.gd.
	var mine_source := FileAccess.get_file_as_string("res://scripts/abilities/bounce_mine_ability.gd")
	var mine_activate := _function_source(mine_source, "activate")
	var client_guard := mine_activate.find("DuelAbility.is_online_client(game)")
	var network_request := mine_activate.find("_request_network_ability.rpc_id")
	var authoritative_spawn := mine_activate.find("_spawn_bounce_mine()")
	_check(
		client_guard >= 0 and network_request > client_guard and authoritative_spawn > network_request,
		"BUG 2: an online client still spawns a fake local bounce mine before server authorization"
	)

	var phase_source := FileAccess.get_file_as_string("res://scripts/abilities/phase_bubble_ability.gd")
	_check(
		"_replicate_phase_bubble.rpc" in _function_source(phase_source, "activate")
		and "_replicate_phase_bubble.rpc" in _function_source(phase_source, "expire")
		and "func _replicate_phase_bubble" in source,
		"BUG 3: phase-bubble activation or expiry is not replicated, leaving remote visuals stale or invisible"
	)

	var deflection_source := _function_source(source, "_deflect_projectiles_around")
	_check(
		"_replicate_projectile_deflection.rpc" in deflection_source
		and "func _replicate_projectile_deflection" in source,
		"BUG 4: gravity-pulse projectile deflections have no replication event, so client visuals diverge"
	)


func _test_invalid_room_code_clears_session() -> void:
	var session := root.get_node_or_null("NetworkSession")
	if session == null:
		_check(false, "BUG 8: NetworkSession autoload is unavailable for invalid-code cleanup")
		return
	var test_port := 20000 + int(OS.get_process_id()) % 30000
	var host_result := int(session.call("host_game", test_port))
	if host_result != OK:
		_check(false, "Regression setup: could not open a temporary local session for invalid-code cleanup")
		return
	var join_result := int(session.call("join_game_by_code", "NOT-A-CODE"))
	var peer: MultiplayerPeer = session.get_multiplayer().multiplayer_peer
	_check(
		join_result == ERR_INVALID_PARAMETER
		and peer is OfflineMultiplayerPeer
		and "not valid" in str(session.get("status_message")).to_lower(),
		"BUG 8: rejecting an invalid room code leaves the previous network peer/session active"
	)
	session.call("close_session")
	await process_frame


func _test_progression_hud_contracts() -> void:
	var hud := HUD_SCENE.instantiate()
	root.add_child(hud)
	await process_frame

	var coin_chip := hud.find_child("CoinBalance", true, false) as Control
	var quest_panel := hud.find_child("QuestPanel", true, false) as Control
	_check(
		coin_chip != null and quest_panel != null,
		"BUG 5: coin and quest constructors are never invoked, leaving both progression HUD pieces absent"
	)

	hud.call("_on_coin_balance_changed", 125, 25)
	await process_frame
	_check(
		_has_visible_label_text(hud, "+25 COINS"),
		"BUG 6: earning a positive coin delta never triggers the coin-earned animation/copy"
	)

	var initial_color := hud.call("get_player_color") as Color
	var emitted_colors: Array[Color] = []
	hud.identity_changed.connect(func(_display_name: String, color: Color) -> void: emitted_colors.append(color))
	hud.call("_select_player_color", 1)
	var selected_color := hud.call("get_player_color") as Color
	_check(
		not selected_color.is_equal_approx(initial_color)
		and not emitted_colors.is_empty()
		and emitted_colors.back().is_equal_approx(selected_color),
		"BUG 9: selecting a menu color does not change or emit the player's identity color"
	)

	hud.queue_free()
	await process_frame


func _test_game_runtime_contracts() -> void:
	var replica_mine := BOUNCE_MINE_SCENE.instantiate() as RigidBody3D
	root.add_child(replica_mine)
	replica_mine.call("configure", Vector3.ZERO, Vector3.FORWARD, null, false)
	var replica_trigger := replica_mine.get_node("Trigger") as Area3D
	_check(
		replica_mine.collision_layer == 0
		and replica_mine.collision_mask == 1
		and not replica_trigger.monitoring,
		"BUG 2: a replicated visual mine still has player collision or trigger monitoring on the client"
	)
	replica_mine.queue_free()
	await process_frame

	var game := MAIN_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame

	var bus_state: Dictionary = {}
	for bus_name in AUDIO_BUSES:
		var bus_index := AudioServer.get_bus_index(bus_name)
		if bus_index < 0:
			continue
		bus_state[bus_name] = {
			"mute": AudioServer.is_bus_mute(bus_index),
			"volume_db": AudioServer.get_bus_volume_db(bus_index),
		}
		game.call("_set_audio_bus_volume", bus_name, 0.0)
		_check(
			AudioServer.is_bus_mute(bus_index),
			"BUG 7: setting %s volume to zero only lowers dB and does not truly mute the bus" % bus_name
		)
	for bus_name in bus_state:
		var bus_index := AudioServer.get_bus_index(bus_name)
		var previous := bus_state[bus_name] as Dictionary
		AudioServer.set_bus_volume_db(bus_index, float(previous.get("volume_db", 0.0)))
		AudioServer.set_bus_mute(bus_index, bool(previous.get("mute", false)))

	var dummy := game.get_tree().get_first_node_in_group("training_dummy") as Node3D
	var player := game.get_node("Player") as Node3D
	if dummy == null or player == null:
		_check(false, "BUG 10: practice scanner test cannot find the local player and a training dummy")
	else:
		game.call("_start_practice_match")
		player.global_position = dummy.global_position + Vector3(2.0, 0.0, 0.0)
		game.call("_activate_target_scanner", Time.get_ticks_msec())
		var scanned_targets := game.get("_scanned_targets") as Array
		_check(
			dummy in scanned_targets,
			"BUG 10: Target Scanner ignores nearby training dummies, making the ability inert in Practice"
		)

	game.queue_free()
	await process_frame


func _function_source(source: String, function_name: String) -> String:
	var start := source.find("func %s(" % function_name)
	if start < 0:
		return ""
	var next_function := source.find("\nfunc ", start + 1)
	return source.substr(start) if next_function < 0 else source.substr(start, next_function - start)


func _between(source: String, start_marker: String, end_marker: String) -> String:
	var start := source.find(start_marker)
	if start < 0:
		return ""
	var end := source.find(end_marker, start + start_marker.length())
	return source.substr(start) if end < 0 else source.substr(start, end - start)


func _has_visible_label_text(parent: Node, expected_text: String) -> bool:
	for candidate in parent.find_children("*", "Label", true, false):
		var label := candidate as Label
		if label.is_visible_in_tree() and expected_text in label.text:
			return true
	return false


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
