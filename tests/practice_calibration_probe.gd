extends SceneTree

## Measures, in the real training grounds with the real player physics:
##   1. where a tap fling and a full fling come to rest launched east from the
##      centre spawn platform (how much lane the 28 GU blueprint gives), and
##   2. the apex height a blob reaches off each bounce-pad impulse value
##      (calibrates the hop pads - the blueprint wants small hops only).
## _probe suffix: telemetry, not a contract.

const PRACTICE := preload("res://scenes/world/practice_arena.tscn")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

var player: RigidBody3D


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var arena := PRACTICE.instantiate() as Node3D
	world.add_child(arena)
	player = PLAYER_SCENE.instantiate() as RigidBody3D
	world.add_child(player)
	await physics_frame
	await physics_frame

	print("=== FLING LANDINGS launched +X from the centre platform (rest after decay) ===")
	for sample in [["tap 0.15s", 0.021], ["hold 1.75s", 0.25], ["hold 3.5s", 0.5], ["FULL 7s", 1.0]]:
		var distance := await _measure_fling(float(sample[1]))
		print("%-11s ratio %.3f -> stops %.1f units down-range (x=%.1f)" % [sample[0], float(sample[1]), distance, distance])

	print("=== BOUNCE PAD APEX by impulse (rise above launch point) ===")
	for impulse in [34.0, 50.0, 60.0, 70.0, 80.0, 90.0]:
		var rise := await _measure_pad_apex(impulse)
		print("impulse %5.1f -> apex +%.1f" % [impulse, rise])

	quit(0)


func _measure_fling(ratio: float) -> float:
	player.respawn(Vector3(0, 4.6, 0))
	await _physics_seconds(0.4)
	player.linear_velocity = Vector3.ZERO
	player.angular_velocity = Vector3.ZERO
	player.aim_direction = Vector3(1, 0, 0)
	player.call("_release_fling", ratio)
	var settled := 0
	for _tick in range(60 * 14):
		await physics_frame
		if player.linear_velocity.length() < 0.8:
			settled += 1
			if settled > 30:
				break
		else:
			settled = 0
	return player.global_position.x


func _measure_pad_apex(impulse: float) -> float:
	player.respawn(Vector3(12, 3.5, 0))
	await _physics_seconds(0.4)
	player.linear_velocity = Vector3.ZERO
	var start_y := player.global_position.y
	player.call("apply_bounce_pad", impulse)
	var apex := start_y
	for _tick in range(60 * 4):
		await physics_frame
		apex = maxf(apex, player.global_position.y)
		if player.linear_velocity.y < 0.0 and player.global_position.y < apex - 1.0:
			break
	return apex - start_y


func _physics_seconds(seconds: float) -> void:
	for _index in range(maxi(1, int(ceil(seconds * 60.0)))):
		await physics_frame
