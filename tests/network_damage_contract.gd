extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _run() -> void:
	var game := MAIN_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	game._start_practice_match()
	await physics_frame

	var player := game.get_node("Player") as RigidBody3D
	player.set_input_enabled(false)
	player.gravity_scale = 0.0
	player.linear_velocity = Vector3.ZERO
	player.health = player.max_health
	game._receive_projectile_hit(999, Vector3(999.0, 0.0, 0.0))
	await physics_frame
	_check(player.health == player.max_health - 60, "Network projectile damage is not clamped to 60")
	_check(player.linear_velocity.length() > 45.0, "Network projectile receipt does not apply visible knockback")
	_check(player.linear_velocity.length() <= player.emergency_max_speed + 0.1, "Network projectile receipt bypasses the emergency speed guard")

	player.linear_velocity = Vector3.ZERO
	player.health = player.max_health
	game._receive_network_collision(Vector3(999.0, 0.0, 0.0), 999)
	await physics_frame
	_check(player.health == player.max_health - 60, "Network blob collision damage is not clamped to 60")
	_check(player.linear_velocity.length() > 80.0, "Network blob collision does not apply strong knockback")
	_check(player.linear_velocity.length() <= player.emergency_max_speed + 0.1, "Network collision receipt bypasses the emergency speed guard")

	var projectiles := game.get_node("Projectiles")
	var projectile_count_before := projectiles.get_child_count()
	game._replicate_shot(2, player.global_position + Vector3(0.0, 80.0, 0.0), Vector3.FORWARD)
	await process_frame
	_check(projectiles.get_child_count() == projectile_count_before + 1, "Replicated network shot does not create a client-side projectile")

	game.set("_peer_spawn_slots", {1: 0, 2: 1})
	game.set("_peer_last_state_position", {2: Vector3.ZERO})
	game.set("_peer_last_state_msec", {2: 1000})
	var clamped_position: Vector3 = game._sanitize_remote_position(2, Vector3(1000.0, 0.0, 0.0), 1050)
	_check(clamped_position.length() <= 5.0, "Remote movement validation accepts an impossible teleport")
	var spammed_position: Vector3 = game._sanitize_remote_position(2, Vector3(1000.0, 0.0, 0.0), 1060)
	_check(spammed_position.is_equal_approx(clamped_position), "Remote movement validation accepts state-RPC spam")
	var derived_velocity: Vector3 = game._derive_remote_velocity(Vector3.ZERO, clamped_position, 1000, 1050)
	_check(derived_velocity.length() <= game.MAX_REMOTE_STATE_SPEED + 0.01, "Remote movement derives an impossible server velocity")
	_check(not derived_velocity.is_equal_approx(Vector3(0.0, 0.0, 92.0)), "Remote movement still trusts a spoofed client velocity")
	var safe_color: Color = game._sanitize_player_color(Color(5.0, -2.0, 0.5, 0.0))
	_check(safe_color.r <= 1.0 and safe_color.g >= 0.079 and safe_color.a >= 0.999, "Remote identity color is not sanitized")

	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("NETWORK DAMAGE CONTRACT PASS: RPC clamps, knockback, shot replication, state validation")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
