extends SceneTree

## Diagnostic, not a contract: prints the measured fling launch speed for a range
## of charge holds so the curve can be judged in m/s rather than raw impulse.
## Excluded from the suite by the _probe suffix.

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var player := PLAYER_SCENE.instantiate() as RigidBody3D
	world.add_child(player)
	await physics_frame
	player.gravity_scale = 0.0

	var roll_reference: float = float(player.get("ground_control_speed"))
	print("mass=%.2f  max_charge_time=%.1fs  roll speed reference=%.1f m/s" % [player.mass, player.get("maximum_charge_time"), roll_reference])
	print("hold(s)  ratio   impulse   launch(m/s)")
	for hold in [0.15, 0.35, 0.75, 1.75, 3.5, 5.25, 7.0]:
		var ratio: float = clampf(hold / float(player.get("maximum_charge_time")), 0.0, 1.0)
		player.respawn(Vector3(0, 6, 0))
		for _i in range(12):
			await physics_frame
		player.linear_velocity = Vector3.ZERO
		player.aim_direction = Vector3(0, 0, -1)
		var impulse: float = float(player.call("calculate_fling_strength", ratio))
		player.call("_release_fling", ratio)
		await physics_frame
		print("%5.2f    %.3f   %6.1f    %6.1f" % [hold, ratio, impulse, -player.linear_velocity.z])

	quit(0)
