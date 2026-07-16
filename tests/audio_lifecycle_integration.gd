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
	_expect(audio_manager.call("get_music_variant_count", &"match") >= 5, "match music rotates through every map theme")
	for theme in [&"neon_arcade", &"backyard", &"arena", &"sky_temple", &"toybox"]:
		_expect(audio_manager.call("set_map_music_theme", theme, 0.0, false), "%s map music theme is selectable" % theme)
		_expect(audio_manager.call("get_map_music_theme") == theme, "%s map music theme is retained" % theme)
	_expect(audio_manager.call("set_map_music_theme", &"arena_factory", 0.0, false), "arena factory alias selects map music")
	_expect(audio_manager.call("get_map_music_theme") == &"arena", "arena factory alias resolves to the arena map id")
	_expect(not audio_manager.call("set_map_music_theme", &"unknown_map", 0.0, false), "unknown map music themes are rejected")
	for sfx_key in [&"display_chirp", &"machinery_pulse", &"portal_teleport", &"bumper_hit", &"conveyor_rail", &"ambient_sparkle"]:
		_expect(audio_manager.call("has_sfx", sfx_key), "%s procedural SFX is registered" % sfx_key)
	audio_manager.call("set_map_music_theme", &"neon_arcade", 0.0, false)
	audio_manager.call("set_music_context", &"match", 0.0, true)
	var neon_track := String(audio_manager.call("get_active_music_stream_path"))
	game.call("_activate_competitive_map", "backyard")
	await process_frame
	var backyard_track := String(audio_manager.call("get_active_music_stream_path"))
	_expect(neon_track != backyard_track and backyard_track.contains("backyard"), "changing an active duel map immediately switches its music")
	player.fling_charge_updated.emit(0.55)
	await process_frame
	_expect(audio_manager.call("is_loop_playing", &"player_charge"), "charge signal drives the managed charge loop")
	player.fling_released.emit(1.0)
	await create_timer(0.12).timeout
	_expect(not audio_manager.call("is_loop_playing", &"player_charge"), "fling release stops the charge loop")

	game.set("_practice_mode", true)
	game.call("_start_arena_for_peer", 1)
	await process_frame
	_expect(audio_manager.call("get_music_context") == &"practice", "practice mode selects practice music")
	player.linear_velocity = Vector3(72.0, 4.0, 0.0)
	game.call("_update_player_audio")
	await process_frame
	_expect(audio_manager.call("is_loop_playing", &"player_air_rush"), "high-speed movement starts air-rush audio")

	game.call("_return_to_lobby")
	await create_timer(0.25).timeout
	_expect(audio_manager.call("get_music_context") == &"lobby", "returning to lobby restores lobby music")
	_expect(not audio_manager.call("is_loop_playing", &"player_air_rush"), "returning to lobby stops air-rush audio")

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
