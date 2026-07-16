extends SceneTree

const AUDIO_MANAGER_SCRIPT := preload("res://scripts/audio_manager.gd")
const ABILITY_TUNING := preload("res://scripts/ability_tuning.gd")
const PROJECTILE_SCENE := preload("res://scenes/player/projectile.tscn")
const HUD_SCENE := preload("res://scenes/hud.tscn")
const PAUSE_SCENE := preload("res://scenes/ui/pause_menu.tscn")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var audio := AUDIO_MANAGER_SCRIPT.new()
	for key in [&"ability_ready", &"ability_dash", &"ability_ricochet", &"ability_blink", &"ability_phase", &"reward_tick"]:
		_check(audio.has_sfx(key), "%s feedback sound is not registered" % key)
	audio.queue_free()

	var projectile := PROJECTILE_SCENE.instantiate()
	root.add_child(projectile)
	await process_frame
	projectile.damage = 30
	projectile.configure(Vector3.ZERO, Vector3.FORWARD, null, false, true, false)
	_check(projectile.damage == 40, "ricochet shot must receive exactly one +10 damage bonus")
	projectile.configure(Vector3.ZERO, Vector3.FORWARD, null, false, false, true)
	_check(projectile.speed == ABILITY_TUNING.RAIL_SHOT_SPEED, "rail shots must use their tuned travel speed")
	projectile.configure(Vector3.ZERO, Vector3.FORWARD, null, false, false, false)
	_check(projectile.damage == 30, "reconfigured projectile damage must reset to its base value")
	_check(projectile.speed == 150.0, "reconfigured projectiles must reset their base speed")
	projectile.queue_free()

	var hud := HUD_SCENE.instantiate()
	root.add_child(hud)
	await process_frame
	hud.call("show_announcement", "FIRST", Color.WHITE)
	hud.call("show_announcement", "SECOND", Color(0.2, 0.9, 1.0))
	_check((hud.get("_announcement_queue") as Array).size() == 1, "announcements must queue instead of replacing each other")
	hud.queue_free()

	var pause := PAUSE_SCENE.instantiate()
	pause.settings_path = "user://blob_duels_polish_settings.cfg"
	root.add_child(pause)
	await process_frame
	pause.call("open_pause")
	_check(pause.visible and pause.get_node("PausePanel").scale.x < 1.0, "pause menu should begin with an entrance animation")
	pause.queue_free()

	if failures.is_empty():
		print("POLISH SYSTEMS CONTRACT PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
