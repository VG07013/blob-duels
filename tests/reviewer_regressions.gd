extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const WIND_SCENE := preload("res://scenes/interactables/wind_zone.tscn")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _run() -> void:
	var audio_manager := root.get_node("AudioManager")
	audio_manager.start_loop(&"wind", -14.0, 1.0, 0.6, &"fade_stop_regression")
	audio_manager.stop_loop(&"fade_stop_regression", 0.05)
	await create_timer(0.12).timeout
	_check(not audio_manager.is_loop_playing(&"fade_stop_regression"), "A loop cannot be stopped while its fade-in tween is active")

	var game := MAIN_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	var player := game.get_node("Player") as RigidBody3D
	game._apply_settings({"graphics_quality": 99, "effects_quality": -4, "shadow_quality": 99, "render_scale": 8.0})
	_check(int(game.get("_graphics_quality")) == 3, "Corrupt graphics quality is not clamped at the runtime boundary (Ultra is the ceiling)")
	_check(is_equal_approx(get_root().scaling_3d_scale, 1.25), "Corrupt render scale is not clamped at the runtime boundary")
	var no_token_flags := game._consume_server_shot_flags(2, 1000) as Dictionary
	_check(not bool(no_token_flags.get("ricochet")) and not bool(no_token_flags.get("rail")), "Remote shots gain privileged ability flags without a server token")
	var server_peers = game.get("_server_peers")
	server_peers.state_for(2).ricochet_loaded = true
	var ricochet_flags := game._consume_server_shot_flags(2, 1000) as Dictionary
	_check(bool(ricochet_flags.get("ricochet")) and not server_peers.state_for(2).ricochet_loaded, "Server ricochet tokens are not consumed exactly once")
	server_peers.state_for(2).equipped_ability = "ricochet_shot"
	server_peers.state_for(2).ability_ready_at = 0
	_check(not game._is_server_ability_request_allowed(2, "rail_shot", 1000), "Server accepts an ability outside the peer's locked match loadout")
	_check(game._is_server_ability_request_allowed(2, "ricochet_shot", 1000), "Server rejects the peer's locked match loadout ability")
	server_peers.state_for(2).rail_charge_end_at = 1500
	var early_rail_flags := game._consume_server_shot_flags(2, 1499) as Dictionary
	_check(not bool(early_rail_flags.get("rail")), "Server releases a Rail shot before its charge completes")
	var ready_rail_flags := game._consume_server_shot_flags(2, 1500) as Dictionary
	_check(bool(ready_rail_flags.get("rail")), "Server does not release a Rail shot when its charge completes")
	player.set_cosmetic_quality(0)
	player.call("_apply_trail_profile", {"color": Color.WHITE, "rarity": "Common"})
	player.linear_velocity = Vector3(80.0, 0.0, 0.0)
	player.call("_update_speed_trail")
	_check((player.get_node("SpeedTrail") as GPUParticles3D).amount <= 10, "Low cosmetic quality is overwritten by runtime trail animation")
	player.gravity_scale = 0.0
	player.linear_velocity = Vector3.ZERO
	player.request_shot_for_test()
	await physics_frame
	_check(player.linear_velocity.length() < 0.01, "Lobby shooting applies recoil before Game rejects the shot")

	var wind := WIND_SCENE.instantiate()
	game.add_child(wind)
	wind._on_body_entered(player)
	var world_loop_id: StringName = wind._audio_loop_id()
	_check(audio_manager.is_loop_playing(world_loop_id), "Wind zone did not start its managed world loop")
	wind.queue_free()
	await process_frame
	await create_timer(0.28).timeout
	_check(not audio_manager.is_loop_playing(world_loop_id), "Wind zone audio survives map teardown")

	game.set("_peer_spawn_slots", {1: 0, 2: 1})
	server_peers.state_for(1).health = 100
	server_peers.state_for(2).health = 40
	game.set("arena_started", true)
	game.set("_practice_mode", false)
	game.set("_match_timer_running", true)
	game.set("_match_time_remaining", 0.01)
	game._update_match_timer(0.02)
	_check(bool(game.get("_round_resolving")), "Duel timer expiry does not resolve the round")
	_check(int(game.get("_red_score")) == 1, "Duel timeout does not award the healthier team")

	game.queue_free()
	await process_frame
	audio_manager.stop_all_loops(0.0, false)
	if failures.is_empty():
		print("REVIEWER REGRESSIONS PASS: timeout, shot gating, audio tween stop, teardown cleanup")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
