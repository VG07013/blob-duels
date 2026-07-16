extends SceneTree

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const PROJECTILE_SCENE := preload("res://scenes/player/projectile.tscn")
const HUD_SCENE := preload("res://scenes/hud.tscn")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var player := PLAYER_SCENE.instantiate()
	root.add_child(player)
	await process_frame
	var visual := player.get_node("VisualRoot") as Node3D
	_check(visual.has_method("hit_reaction"), "blob visual needs a reusable impact reaction")
	_check(visual.has_method("set_launch_energy"), "blob visual needs a launch reaction for bounces and flings")
	player.linear_velocity = Vector3(0.0, 0.0, 42.0)
	await physics_frame
	_check(visual.scale.z > visual.scale.x, "high-speed blobs should stretch in their direction of travel")
	visual.call("hit_reaction", 1.0)
	await physics_frame
	_check(visual.scale.y < 1.0, "hard impacts should briefly squash the blob")
	player.queue_free()

	var projectile := PROJECTILE_SCENE.instantiate()
	_check(projectile.has_signal("ricocheted"), "ricochet shots need a presentation signal")
	_check(projectile.has_signal("phase_absorbed"), "phase shields need a clean projectile-resolution signal")
	projectile.queue_free()

	var hud := HUD_SCENE.instantiate()
	root.add_child(hud)
	await process_frame
	hud.call("show_announcement", "DASH!", Color(0.35, 1.0, 0.56))
	var announcement := hud.get_node("Announcement") as Control
	_check(announcement.visible, "announcements must remain visible while their entrance animation plays")
	_check(announcement.scale.x > 0.8 and announcement.scale.x < 1.0, "announcements should begin with a readable animated entrance scale")
	hud.queue_free()

	if failures.is_empty():
		print("FEEL POLISH CONTRACT PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
