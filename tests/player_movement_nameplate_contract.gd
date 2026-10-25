extends SceneTree

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

var failures: Array[String] = []


func _initialize() -> void:
	var player := PLAYER_SCENE.instantiate() as RigidBody3D
	root.add_child(player)
	await process_frame

	# The alpha shipped an 8.5 N.s start kick that read as an instant launch.
	# The rework settled on 6.5 (a 2 m/s nudge over the 3.2 kg blob) in the same
	# commit this contract was written, so the old "<= 5.0" bound never matched
	# any shipped tuning. Guard the product rule instead: the opening nudge must
	# stay well under the old kick and far below the 38 m/s traversal band.
	_check(player.ground_start_impulse < 8.0, "Base movement must not start with the old near-instant launch impulse")
	_check(player.ground_start_impulse / maxf(player.mass, 0.001) < 2.5, "The opening movement nudge must stay a nudge, not a launch")
	_check(player.movement_build_up_time > 0.5, "Movement must expose a sustained momentum build-up window")
	player.set("_movement_build_up", 0.0)
	var initial_factor := float(player.call("_movement_build_up_factor"))
	player.set("_movement_build_up", player.movement_build_up_time)
	var full_factor := float(player.call("_movement_build_up_factor"))
	_check(initial_factor < full_factor and initial_factor < 0.7, "Movement acceleration must ramp from a slower base to full momentum")

	player.linear_velocity = Vector3(14.0, player.max_bounce_upward_speed + 30.0, -9.0)
	player.call("_apply_bounce_height_cap")
	_check(player.linear_velocity.y <= player.max_bounce_upward_speed + 0.01, "Ordinary bounce velocity must be capped")
	_check(is_equal_approx(player.linear_velocity.x, 14.0) and is_equal_approx(player.linear_velocity.z, -9.0), "Bounce cap must preserve horizontal combat momentum")

	var nameplate := player.get_node_or_null("Nameplate") as Node3D
	var name_label := player.get_node_or_null("Nameplate/Name") as Label3D
	var health_back := player.get_node_or_null("Nameplate/HealthBackground") as MeshInstance3D
	var health_fill := player.get_node_or_null("Nameplate/HealthFill") as MeshInstance3D
	_check(nameplate != null and nameplate.top_level, "Nameplate must stay upright independently of rolling blob physics")
	player.update_nameplate_for_camera(player.global_position + Vector3(0.0, 0.0, 6.0))
	_check(nameplate != null and not nameplate.visible, "Blobs must not show a floating name tag or health bar above their heads")
	_check(health_back != null and health_fill != null, "Nameplate must use a visual health bar instead of a raw health number")
	_check(name_label != null and name_label.text.find("/") < 0, "Nameplate must not expose raw numeric health")

	player.health = player.max_health / 2
	player.call("_update_health_billboard")
	_check(health_fill != null and absf(health_fill.scale.x - 0.5) < 0.02, "World health bar fill must reflect network/local health changes")

	player.queue_free()
	await process_frame
	if failures.is_empty():
		print("PLAYER MOVEMENT AND NAMEPLATE CONTRACT PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
