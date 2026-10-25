extends SceneTree

const MAIN_SCENE := preload("res://scenes/main.tscn")
const TEST_TIMEOUT := 24.0

var _role := "host"
var _game: Node3D
var _player: RigidBody3D
var _elapsed := 0.0
var _ready_elapsed := -1.0
var _shot_fired := false
var _shot_replicated := false
var _health_dropped := false
var _knockback_seen := false
var _fling_tested := false
var _fling_speed := 0.0
var _remote_seen := false


func _initialize() -> void:
	Engine.max_fps = 60
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--role="):
			_role = argument.trim_prefix("--role=")
	call_deferred("_run")


func _run() -> void:
	_game = MAIN_SCENE.instantiate() as Node3D
	root.add_child(_game)
	await process_frame
	_player = _game.get_node("Player") as RigidBody3D
	_game.get_node("Projectiles").child_entered_tree.connect(func(_projectile: Node) -> void: _shot_replicated = true)
	var session := root.get_node("NetworkSession")
	session.state_changed.connect(func(state: int, message: String) -> void: print("NETWORK TRACE role=%s state=%d message=%s" % [_role, state, message]))
	if _role == "host":
		_game.set("_selected_map_id", "bounceground")
		var host_error: Error = session.call("host_game", 7361)
		if host_error != OK:
			_fail("host could not bind test port: %s" % error_string(host_error))
			return
	else:
		await create_timer(0.65).timeout
		var join_error: Error = session.call("join_game", "127.0.0.1", 7361)
		if join_error != OK:
			_fail("client could not start connection: %s" % error_string(join_error))
			return

	while _elapsed < TEST_TIMEOUT:
		await process_frame
		var delta := 1.0 / 60.0
		_elapsed += delta
		_poll_network_state()
		if _ready_elapsed >= 0.0:
			var phase := _elapsed - _ready_elapsed
			if phase < 1.8:
				_hold_local_test_position()
			if phase >= 2.0 and not _shot_fired:
				_fire_at_remote()
			if phase >= 5.0 and not _fling_tested:
				_test_full_fling()
			if phase >= 6.0 and _network_requirements_met():
				_print_pass()
				return
	var network_session := root.get_node("NetworkSession")
	_fail("timed out; state=%s message=%s remote=%s shot=%s replicated=%s health=%s knockback=%s fling=%.1f" % [network_session.get("state"), network_session.get("status_message"), _remote_seen, _shot_fired, _shot_replicated, _health_dropped, _knockback_seen, _fling_speed])


func _poll_network_state() -> void:
	if _round_live():
		_remote_seen = true
		if _ready_elapsed < 0.0:
			_ready_elapsed = _elapsed
			_place_local_player()
	if _game.get_node("Projectiles").get_child_count() > 0:
		_shot_replicated = true
	if _player.health < _player.max_health:
		_health_dropped = true
	if _health_dropped and _player.linear_velocity.length() > 4.0:
		_knockback_seen = true
	if _fling_tested:
		_fling_speed = maxf(_fling_speed, _player.linear_velocity.length())


func _place_local_player() -> void:
	_player.gravity_scale = 0.0
	_player.respawn(_test_position())
	_player.linear_velocity = Vector3.ZERO


func _hold_local_test_position() -> void:
	_player.global_position = _test_position()
	_player.linear_velocity = Vector3.ZERO
	_player.angular_velocity = Vector3.ZERO


func _test_position() -> Vector3:
	var x := -14.0 if _role == "host" else 14.0
	return Vector3(x, 15.0, 40.0)


func _fire_at_remote() -> void:
	if not _round_live():
		return
	var remote_players := _game.get_node("RemotePlayers")
	if remote_players.get_child_count() <= 0:
		return
	var remote := remote_players.get_child(0) as RigidBody3D
	if remote == null:
		return
	var direction := (remote.global_position - _player.global_position).normalized()
	if direction.length_squared() <= 0.001:
		return
	print("NETWORK TRACE role=%s firing local=%s remote=%s direction=%s" % [_role, _player.global_position, remote.global_position, direction])
	_player.aim_direction = direction
	_player.call("request_shot_for_test")
	_shot_fired = true


func _test_full_fling() -> void:
	_player.linear_velocity = Vector3.ZERO
	_player.aim_direction = Vector3(0.0, 0.05, 1.0 if _role == "host" else -1.0).normalized()
	_player.call("_release_fling", 1.0)
	_fling_tested = true
	_fling_speed = _player.linear_velocity.length()


func _network_requirements_met() -> bool:
	return _remote_seen and _shot_fired and _shot_replicated and _health_dropped and _knockback_seen and _fling_speed >= 35.0


func _round_live() -> bool:
	return (
		_game.get("arena_started") == true
		and _game.get("_waiting_for_opponent") == false
		and _game.get("_round_countdown_active") == false
		and _game.get("_round_resolving") == false
		and bool(_player.get("shooting_enabled"))
		and _game.get_node("RemotePlayers").get_child_count() > 0
	)


func _print_pass() -> void:
	print("TWO CLIENT NETWORK PASS role=%s health=%d knockback=%s full_fling_speed=%.1f" % [_role, _player.health, _knockback_seen, _fling_speed])
	root.get_node("NetworkSession").call("close_session")
	quit(0)


func _fail(message: String) -> void:
	push_error("TWO CLIENT NETWORK FAIL role=%s: %s" % [_role, message])
	root.get_node("NetworkSession").call("close_session")
	quit(1)
