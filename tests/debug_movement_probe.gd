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
	print("after bounce velocity=", player.linear_velocity, " grounded=", player.is_grounded(), " coyote=", player.get("_coyote_timer"))

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
