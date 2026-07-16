extends SceneTree

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const MAIN_SCENE := preload("res://scenes/main.tscn")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _has_property(target: Object, property_name: StringName) -> bool:
	for property in target.get_property_list():
		if property.name == property_name:
			return true
	return false


func _run() -> void:
	var player := PLAYER_SCENE.instantiate() as RigidBody3D
	root.add_child(player)
	await process_frame

	_check(InputMap.has_action("shoot"), "Left-mouse shoot action is missing")
	_check(player.has_method("get_movement_input"), "Movement input helper is missing")
	_check(player.has_method("calculate_fling_strength"), "Continuous fling curve helper is missing")
	_check(player.has_method("is_grounded"), "Reliable grounded state is missing")
	_check(player.has_method("request_shot_for_test"), "Shooting request path is missing")
	var has_charge_time := _has_property(player, &"maximum_charge_time")
	_check(has_charge_time, "Modern fling charge timing property is missing")
	if has_charge_time:
		_check(is_equal_approx(float(player.get("maximum_charge_time")), 7.0), "Fling charge must take 7 seconds to max")

	if player.has_method("calculate_fling_strength"):
		var tap := float(player.call("calculate_fling_strength", 0.0))
		var quarter := float(player.call("calculate_fling_strength", 0.25))
		var middle := float(player.call("calculate_fling_strength", 0.5))
		var high := float(player.call("calculate_fling_strength", 0.75))
		var full := float(player.call("calculate_fling_strength", 1.0))
		_check(tap < quarter and quarter < middle and middle < high and high < full, "Fling strength is not continuous")
		_check(full >= 300.0, "Full fling is not a dramatic blast for the blob mass")

	var physics_material := player.physics_material_override
	_check(physics_material != null, "Blob physics material is missing")
	if physics_material != null:
		_check(physics_material.bounce >= 0.92, "Blob bounce is too low")
		_check(physics_material.friction <= 0.18, "Blob friction is too high")
	_check(not player.has_node("VisualRoot/AimMarker"), "Player blob still has the protruding aim marker")

	Input.action_press("move_forward")
	Input.action_press("move_left")
	if player.has_method("get_movement_input"):
		var diagonal: Vector2 = player.call("get_movement_input")
		_check(diagonal.length() > 0.99 and diagonal.length() <= 1.001, "Diagonal movement is not normalized")
	Input.action_press("move_back")
	if player.has_method("get_movement_input"):
		var canceled: Vector2 = player.call("get_movement_input")
		_check(absf(canceled.y) <= 0.001 and canceled.x < -0.9, "Opposite movement keys do not cancel")
	Input.action_release("move_forward")
	Input.action_release("move_back")
	Input.action_release("move_left")

	var game := MAIN_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	_check(game.has_method("_handle_local_shot"), "Game has no local projectile firing owner")
	_check(game.has_method("_request_network_shot"), "Multiplayer projectile request RPC is missing")

	player.queue_free()
	game.queue_free()
	await process_frame

	if failures.is_empty():
		print("GAMEPLAY ACCEPTANCE PASS")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("GAMEPLAY ACCEPTANCE FAILURES: %d" % failures.size())
		quit(1)
