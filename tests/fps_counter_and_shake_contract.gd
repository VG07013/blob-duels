extends SceneTree

## BUG-029: the FPS readout must appear, update, and disappear from the Settings
## toggle - and persist through the settings round trip.
## BUG-030: rolling must stop shaking the camera WITHOUT going silent. The shake
## keys off closing speed into a surface; the impact burst and hit audio still
## key off raw contact speed, so they fire on every real contact as before.

const MAIN_SCENE := preload("res://scenes/main.tscn")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := MAIN_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	game.call("_start_practice_match")
	for _warmup in range(10):
		await process_frame

	var hud := game.get_node("HUD")
	var pause_menu := game.get_node("PauseMenu")

	# --- BUG-029 ------------------------------------------------------------
	var settings: Dictionary = pause_menu.call("get_settings")
	_check(settings.has("show_fps"), "Settings must expose a show_fps toggle")

	settings["show_fps"] = false
	game.call("_apply_settings", settings)
	await process_frame
	var label := hud.get_node_or_null("FpsCounter") as Label
	_check(label == null or not label.visible, "FPS counter must stay hidden while the setting is off")

	settings["show_fps"] = true
	game.call("_apply_settings", settings)
	for _tick in range(40):
		await process_frame
	label = hud.get_node_or_null("FpsCounter") as Label
	_check(label != null, "Enabling the setting must create the FPS counter")
	if label != null:
		_check(label.visible, "FPS counter must be visible when enabled")
		_check(label.text.ends_with("FPS") and label.text.length() > 3, "FPS counter must show a live reading, got '%s'" % label.text)
		print("BUG-029 readout: '%s'" % label.text)

	settings["show_fps"] = false
	game.call("_apply_settings", settings)
	await process_frame
	_check(label == null or not label.visible, "Disabling the setting must hide the FPS counter again")

	# --- BUG-030 ------------------------------------------------------------
	var player := game.get_node("Player")
	# A rolling contact: fast along the ground, barely moving into it.
	game.set("_camera_shake_amount", 0.0)
	# Impact bursts are parented straight to the game root.
	var effects_before := game.get_child_count()
	game.call("_on_player_impact", player.global_position, 30.0, 0.4)
	await process_frame
	_check(is_zero_approx(float(game.get("_camera_shake_amount"))), "Rolling along the ground must not shake the camera")
	_check(game.get_child_count() > effects_before, "Rolling contact must still spawn its impact burst")

	# A real landing: driving hard into the surface.
	game.set("_camera_shake_amount", 0.0)
	game.call("_on_player_impact", player.global_position, 30.0, 26.0)
	await process_frame
	_check(float(game.get("_camera_shake_amount")) > 0.0, "A hard impact must still shake the camera")
	print("BUG-030 shake: rolling=0.0, hard impact=%.3f" % float(game.get("_camera_shake_amount")))

	# The signal must carry both measures so the two can stay decoupled.
	var signal_args := 0
	for entry in player.get_signal_list():
		if String(entry["name"]) == "impact_event":
			signal_args = (entry["args"] as Array).size()
	_check(signal_args == 3, "impact_event must carry position, strength and severity, got %d args" % signal_args)

	game.queue_free()
	await process_frame

	if failures.is_empty():
		print("FPS COUNTER AND SHAKE CONTRACT PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("FPS COUNTER AND SHAKE FAILURES: %d" % failures.size())
	quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
