extends SceneTree

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const MAIN_SCENE := preload("res://scenes/main.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var floor := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(80, 2, 80)
	collision.shape = shape
	collision.position.y = -1.0
	floor.add_child(collision)
	world.add_child(floor)
	var player := PLAYER_SCENE.instantiate() as RigidBody3D
	world.add_child(player)
	player.configure_local(1)
	player.respawn(Vector3(0, 3.0, 0))
	for _index in range(17):
		await physics_frame
	player.linear_velocity = Vector3.ZERO
	player.angular_velocity = Vector3.ZERO
	print("grounded before input=", player.is_grounded(), " y=", player.global_position.y, " coyote=", player.get("_coyote_timer"))
	Input.action_press("bounce")
	await physics_frame
	Input.action_release("bounce")
	await physics_frame
	print("after bounce velocity=", player.linear_velocity, " grounded=", player.is_grounded(), " coyote=", player.get("_coyote_timer"), " state=", player.get_movement_state())

	# Advanced movement telemetry: slam, slide, and wall kick states.
	player.respawn(Vector3(0, 30.0, 0))
	for _index in range(17):
		await physics_frame
	Input.action_press("brake")
	Input.action_press("bounce")
	# A press registers on the following physics step, so wait two frames.
	await physics_frame
	await physics_frame
	Input.action_release("bounce")
	print("slam start state=", player.get_movement_state(), " slamming=", player.is_slamming(), " vy=", player.linear_velocity.y)
	Input.action_release("brake")
	for _index in range(90):
		await physics_frame
		if not player.is_slamming():
			break
	print("slam landed state=", player.get_movement_state(), " vy=", player.linear_velocity.y, " bounce_cd=", player.get("_bounce_cooldown_timer"), " slam_cd=", player.get("_slam_cooldown_timer"))

	player.linear_velocity = Vector3(40.0, 0.0, 0.0)
	Input.action_press("brake")
	for _index in range(12):
		await physics_frame
	print("slide state=", player.get_movement_state(), " sliding=", player.is_sliding(), " planar=", Vector2(player.linear_velocity.x, player.linear_velocity.z).length(), " slide_t=", player.get("_slide_timer"))
	for _index in range(60):
		await physics_frame
	print("slide expired state=", player.get_movement_state(), " spent=", player.get("_slide_spent"), " planar=", Vector2(player.linear_velocity.x, player.linear_velocity.z).length())
	Input.action_release("brake")

	var wall := StaticBody3D.new()
	var wall_shape := CollisionShape3D.new()
	var wall_box := BoxShape3D.new()
	wall_box.size = Vector3(2.0, 40.0, 40.0)
	wall_shape.shape = wall_box
	wall.add_child(wall_shape)
	wall.position = Vector3(20.0, 20.0, 0.0)
	world.add_child(wall)
	player.respawn(Vector3(15.5, 12.0, 0.0))
	await physics_frame
	player.gravity_scale = 0.0
	player.linear_velocity = Vector3(4.0, -2.0, 0.0)
	await physics_frame
	print("wall probe normal=", player.call("_find_wall_kick_normal"), " ready=", player.is_wall_kick_ready())
	Input.action_press("bounce")
	await physics_frame
	await physics_frame
	Input.action_release("bounce")
	print("wall kick state=", player.get_movement_state(), " velocity=", player.linear_velocity, " kick_cd=", player.get("_wall_kick_cooldown_timer"))
	player.gravity_scale = 1.8

	var game := MAIN_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	game._start_practice_match()
	await physics_frame
	var game_player := game.get_node("Player") as RigidBody3D
	game_player.set_input_enabled(false)
	game_player.gravity_scale = 0.0
	game_player.linear_velocity = Vector3.ZERO
	game_player.health = game_player.max_health
	game._receive_projectile_hit(999, Vector3(999.0, 0.0, 0.0))
	await physics_frame
	print("network projectile velocity=", game_player.linear_velocity, " speed=", game_player.linear_velocity.length(), " max=", game_player.emergency_max_speed)
	game_player.linear_velocity = Vector3.ZERO
	game._receive_network_collision(Vector3(999.0, 0.0, 0.0), 999)
	await physics_frame
	print("network collision velocity=", game_player.linear_velocity, " speed=", game_player.linear_velocity.length(), " max=", game_player.emergency_max_speed)
	quit(0)
