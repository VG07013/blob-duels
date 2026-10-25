extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := MAIN_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	var audio_manager := root.get_node("AudioManager")
	var player := game.get_node("Player") as RigidBody3D

	_expect(audio_manager.call("get_music_context") == &"lobby", "lobby opens with lobby music")
	_expect(audio_manager.call("get_music_variant_count", &"lobby") >= 3, "lobby music has a richer rotating playlist")
	_expect(bool(audio_manager.call("is_music_audible")), "The lobby plays music")
	for sfx_key in [&"display_chirp", &"machinery_pulse", &"portal_teleport", &"bumper_hit", &"conveyor_rail", &"ambient_sparkle"]:
		_expect(audio_manager.call("has_sfx", sfx_key), "%s procedural SFX is registered" % sfx_key)
	# Music is lobby-only: every gameplay context is silent.
	for context in [&"match", &"practice", &"victory", &"defeat", &"intensity"]:
		audio_manager.call("set_music_context", &"lobby", 0.0)
		audio_manager.call("set_music_context", context, 0.0)
		_expect(not bool(audio_manager.call("is_music_audible")), "Music must be lobby-only; the %s context must be silent" % context)
	audio_manager.call("set_music_context", &"lobby", 0.0)
	game.call("_activate_competitive_map", "skyline")
	await process_frame
	player.fling_charge_updated.emit(0.55)
	await process_frame
	_expect(audio_manager.call("is_loop_playing", &"player_charge"), "charge signal drives the managed charge loop")
	player.fling_released.emit(1.0)
	await create_timer(0.12).timeout
	_expect(not audio_manager.call("is_loop_playing", &"player_charge"), "fling release stops the charge loop")

	game.set("_practice_mode", true)
	game.call("_start_arena_for_peer", 1)
	await process_frame
	await create_timer(1.0).timeout
	_expect(not bool(audio_manager.call("is_music_audible")), "Entering the arena must fade the lobby music out")
	player.linear_velocity = Vector3(72.0, 4.0, 0.0)
	game.call("_update_player_audio")
	await process_frame
	_expect(audio_manager.call("is_loop_playing", &"player_air_rush"), "high-speed movement starts air-rush audio")
	for sfx_key in audio_manager.get("MOVEMENT_SFX_KEYS") + audio_manager.get("COMBAT_SFX_KEYS"):
		_expect(audio_manager.call("has_sfx", sfx_key), "Every movement and combat action must have a sound; %s is missing" % sfx_key)
	var voices_before := audio_manager.get_child_count()
	player.jumped.emit()
	player.air_jumped.emit(Vector3.FORWARD)
	player.landed.emit(30.0)
	player.slam_landed.emit(80.0)
	await process_frame
	_expect(audio_manager.get_child_count() >= voices_before + 4, "Jumping, double jumping, landing and slamming must each play a sound")
	player.freeze = false
	player.set("_grounded", true)
	player.linear_velocity = Vector3(24.0, 0.0, 0.0)
	game.call("_update_player_audio")
	await process_frame
	_expect(audio_manager.call("is_loop_playing", &"player_roll"), "Rolling along the ground must play the rolling rumble")
	voices_before = audio_manager.get_child_count()
	game.get("hud").call("show_hit_marker", "hit")
	await process_frame
	_expect(audio_manager.get_child_count() > voices_before, "Landing a hit must play a hit-confirm sound for the shooter")

	game.call("_return_to_lobby")
	await create_timer(0.25).timeout
	_expect(audio_manager.call("get_music_context") == &"lobby" and bool(audio_manager.call("is_music_audible")), "returning to lobby restores lobby music")
	_expect(not audio_manager.call("is_loop_playing", &"player_air_rush"), "returning to lobby stops air-rush audio")
	_expect(not audio_manager.call("is_loop_playing", &"player_roll"), "Returning to the lobby must stop the rolling rumble")

	game.queue_free()
	await process_frame
	if _failures.is_empty():
		print("AUDIO LIFECYCLE INTEGRATION PASS")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
