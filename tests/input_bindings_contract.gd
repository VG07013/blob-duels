extends SceneTree

## Input bindings contract: every gameplay action ships with both a keyboard/
## mouse and a gamepad default, bindings survive a save/load round trip through
## the settings cfg, conflicts swap instead of unbinding, reset restores the
## project defaults, the rebind listener honours Escape and device slots, and
## the FOV / gamepad sensitivity settings clamp on both the menu and game side.

const PAUSE_SCENE := preload("res://scenes/ui/pause_menu.tscn")
const MAIN_SCENE := preload("res://scenes/main.tscn")
const INPUT_BINDINGS := preload("res://scripts/input_bindings.gd")
const CFG_PATH := "user://blob_duels_input_bindings_contract.cfg"

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_remove_cfg()
	# Project defaults are checked before any PauseMenu applies stored bindings.
	_test_project_defaults()
	await _test_round_trip_swap_and_reset()
	await _test_rebind_listener()
	await _test_settings_clamps()
	await _test_game_applies_look_and_fov()
	_remove_cfg()
	if failures.is_empty():
		print("INPUT BINDINGS CONTRACT PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _test_project_defaults() -> void:
	for action in INPUT_BINDINGS.action_names():
		_check(InputMap.has_action(action), "project.godot must define the gameplay action '%s'" % action)
		if not InputMap.has_action(action):
			continue
		var has_keyboard := false
		var has_joypad := false
		for event in InputMap.action_get_events(action):
			has_keyboard = has_keyboard or event is InputEventKey or event is InputEventMouseButton
			has_joypad = has_joypad or event is InputEventJoypadButton or event is InputEventJoypadMotion
		_check(has_keyboard, "gameplay action '%s' must ship with a keyboard or mouse binding" % action)
		_check(has_joypad, "gameplay action '%s' must ship with a gamepad binding" % action)
		var defaults: Dictionary = INPUT_BINDINGS.DEFAULTS.get(action, {})
		for slot in INPUT_BINDINGS.SLOTS:
			var code := str(defaults.get(slot, ""))
			var event := INPUT_BINDINGS.decode_event(code)
			_check(event != null, "default %s binding for '%s' must decode" % [slot, action])
			_check(INPUT_BINDINGS.slot_for_code(code) == slot, "default %s binding for '%s' must belong to that device slot" % [slot, action])
			if event != null:
				_check(InputMap.action_has_event(action, event), "reset defaults for '%s' (%s) must mirror project.godot" % [action, code])
	for look_action in INPUT_BINDINGS.LOOK_ACTIONS:
		_check(InputMap.has_action(look_action), "right-stick look action '%s' must exist" % look_action)
		var has_axis := false
		if InputMap.has_action(look_action):
			for event in InputMap.action_get_events(look_action):
				has_axis = has_axis or event is InputEventJoypadMotion
		_check(has_axis, "look action '%s' must be driven by a joypad axis" % look_action)
	_check(INPUT_BINDINGS.GAMEPAD_LOOK_DEADZONE > 0.0 and INPUT_BINDINGS.GAMEPAD_LOOK_DEADZONE < 0.5, "stick look deadzone must reject drift without eating half the stick")


func _test_round_trip_swap_and_reset() -> void:
	var first := await _spawn_pause()
	first.call("_assign_binding", "shoot", "keyboard", "key:70")
	var bindings: Dictionary = first.call("get_bindings")
	_check(str(bindings["shoot"]["keyboard"]) == "key:70", "rebinding shoot must store the new key")
	_check(_action_has_code("shoot", "key:70"), "rebinding must reach InputMap immediately")
	_check(not _action_has_code("shoot", "mouse:1"), "rebinding must replace the previous keyboard/mouse event")
	_check(_action_has_code("shoot", "joyaxis:5:1"), "rebinding the keyboard slot must leave the gamepad slot alone")

	first.call("_assign_binding", "bounce", "keyboard", "key:87")
	bindings = first.call("get_bindings")
	_check(str(bindings["bounce"]["keyboard"]) == "key:87", "binding a key already in use must give it to the requested action")
	_check(str(bindings["move_forward"]["keyboard"]) == "key:32", "a keyboard conflict must swap so the other action keeps a binding")
	first.call("_assign_binding", "use_ability", "joypad", "joybtn:0")
	bindings = first.call("get_bindings")
	_check(str(bindings["use_ability"]["joypad"]) == "joybtn:0" and str(bindings["bounce"]["joypad"]) == "joybtn:2", "a gamepad conflict must swap within the gamepad slot")

	var config := ConfigFile.new()
	_check(config.load(CFG_PATH) == OK and config.has_section_key("bindings", "shoot"), "bindings must persist under a [bindings] section of the settings cfg")
	first.free()

	var second := await _spawn_pause()
	var reloaded: Dictionary = second.call("get_bindings")
	_check(reloaded == bindings, "bindings must round-trip through save and load unchanged")
	_check(_action_has_code("shoot", "key:70") and _action_has_code("bounce", "key:87"), "loaded bindings must be applied to InputMap at startup")

	second.call("_reset_bindings")
	_check(second.call("get_bindings") == INPUT_BINDINGS.DEFAULTS, "reset must restore the default binding table")
	_check(_action_has_code("shoot", "mouse:1") and _action_has_code("move_forward", "key:87"), "reset must restore InputMap to the defaults")
	second.free()

	var third := await _spawn_pause()
	_check(third.call("get_bindings") == INPUT_BINDINGS.DEFAULTS, "a reset must persist across relaunch")
	third.free()


func _test_rebind_listener() -> void:
	var pause := await _spawn_pause()
	var page := pause.get_node_or_null("PausePanel/Content/Pages/ControlsPage")
	_check(pause.get_node_or_null("PausePanel/Content/Tabs/ControlsTab") is Button, "escape menu must offer a Controls tab")
	_check(page != null, "escape menu must have a Controls page")
	if page != null:
		for action in INPUT_BINDINGS.action_names():
			for slot in INPUT_BINDINGS.SLOTS:
				var button := page.find_child("Rebind_%s_%s" % [action, slot], true, false) as Button
				_check(button != null, "Controls page needs a rebind button for '%s' (%s)" % [action, slot])
				if button != null:
					_check(not button.text.is_empty() and button.text != "UNBOUND", "rebind button for '%s' (%s) must show the current binding" % [action, slot])
		_check(page.find_child("ResetBindingsButton", true, false) != null, "Controls page must offer a reset-to-defaults action")

	pause.call("_begin_rebind", "brake", "keyboard")
	_check(bool(pause.call("is_rebinding")), "clicking a binding must start listening")
	var joy := InputEventJoypadButton.new()
	joy.button_index = JOY_BUTTON_B
	joy.pressed = true
	pause.call("_input", joy)
	_check(bool(pause.call("is_rebinding")), "a gamepad press must not satisfy a keyboard rebind")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	pause.call("_input", escape)
	_check(not bool(pause.call("is_rebinding")), "Escape must cancel a rebind")
	_check(str(pause.call("get_bindings")["brake"]["keyboard"]) == "key:4194325", "a cancelled rebind must leave the binding untouched")

	pause.call("_begin_rebind", "brake", "keyboard")
	var release := InputEventKey.new()
	release.physical_keycode = KEY_F
	release.pressed = false
	pause.call("_input", release)
	_check(bool(pause.call("is_rebinding")), "a key release must not bind")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_F
	key.pressed = true
	pause.call("_input", key)
	_check(not bool(pause.call("is_rebinding")), "a key press must finish the rebind")
	_check(str(pause.call("get_bindings")["brake"]["keyboard"]) == "key:%d" % int(KEY_F), "the listened key must become the binding")

	pause.call("_begin_rebind", "brake", "joypad")
	var drift := InputEventJoypadMotion.new()
	drift.axis = JOY_AXIS_TRIGGER_LEFT
	drift.axis_value = 0.3
	pause.call("_input", drift)
	_check(bool(pause.call("is_rebinding")), "stick drift under the threshold must not bind")
	var pull := InputEventJoypadMotion.new()
	pull.axis = JOY_AXIS_TRIGGER_LEFT
	pull.axis_value = 0.9
	pause.call("_input", pull)
	var bindings: Dictionary = pause.call("get_bindings")
	_check(str(bindings["brake"]["joypad"]) == "joyaxis:4:1", "a full trigger pull must bind as that axis direction")
	_check(str(bindings["aim"]["joypad"]) == "joybtn:10", "taking a trigger from another action must hand it the old button")
	pause.call("_reset_bindings")
	pause.free()


func _test_settings_clamps() -> void:
	var config := ConfigFile.new()
	config.set_value("settings", "fov", 200.0)
	config.set_value("settings", "gamepad_sensitivity", 99.0)
	config.set_value("settings", "invert_look", true)
	config.save(CFG_PATH)
	var pause := await _spawn_pause()
	var settings: Dictionary = pause.call("get_settings")
	_check(is_equal_approx(float(settings["fov"]), INPUT_BINDINGS.FOV_MAX), "FOV must clamp to the %d degree ceiling" % int(INPUT_BINDINGS.FOV_MAX))
	_check(is_equal_approx(float(settings["gamepad_sensitivity"]), INPUT_BINDINGS.GAMEPAD_SENSITIVITY_MAX), "gamepad sensitivity must clamp to its ceiling")
	_check(bool(settings["invert_look"]), "invert look must round-trip as a bool")
	var fov_slider: HSlider = null
	for candidate in pause.find_children("*", "HSlider", true, false):
		var slider := candidate as HSlider
		if is_equal_approx(slider.min_value, INPUT_BINDINGS.FOV_MIN) and is_equal_approx(slider.max_value, INPUT_BINDINGS.FOV_MAX):
			fov_slider = slider
	_check(fov_slider != null, "Settings must expose a 60-110 degree FOV slider")
	pause.free()

	config.set_value("settings", "fov", 10.0)
	config.save(CFG_PATH)
	pause = await _spawn_pause()
	_check(is_equal_approx(float(pause.call("get_settings")["fov"]), INPUT_BINDINGS.FOV_MIN), "FOV must clamp to the %d degree floor" % int(INPUT_BINDINGS.FOV_MIN))
	pause.free()

	_remove_cfg()
	pause = await _spawn_pause()
	_check(is_equal_approx(float(pause.call("get_settings")["fov"]), INPUT_BINDINGS.FOV_DEFAULT), "default FOV must match the stock camera")
	pause.free()


func _test_game_applies_look_and_fov() -> void:
	var game := MAIN_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	var settings: Dictionary = game.get_node("PauseMenu").call("get_settings")
	var camera := game.get_node("CameraRig/Camera3D") as Camera3D
	_check(camera != null, "main scene must expose its camera at CameraRig/Camera3D")
	game.set("third_person_enabled", true)
	game.call("_apply_settings", settings)
	_check(is_equal_approx(float(game.call("_camera_base_fov")), INPUT_BINDINGS.FOV_DEFAULT), "stock settings must leave the third-person FOV at its historical value")
	game.set("third_person_enabled", false)
	_check(is_equal_approx(float(game.call("_camera_base_fov")), INPUT_BINDINGS.FOV_DEFAULT + INPUT_BINDINGS.FIRST_PERSON_FOV_OFFSET), "first person must keep its offset above the FOV setting")
	game.set("third_person_enabled", true)

	settings["fov"] = 500.0
	settings["gamepad_sensitivity"] = -3.0
	settings["invert_look"] = true
	game.call("_apply_settings", settings)
	_check(is_equal_approx(float(game.get("_base_fov")), INPUT_BINDINGS.FOV_MAX), "game must clamp an out-of-range FOV setting")
	_check(is_equal_approx(float(game.get("_gamepad_sensitivity")), INPUT_BINDINGS.GAMEPAD_SENSITIVITY_MIN), "game must clamp an out-of-range gamepad sensitivity")
	_check(is_equal_approx(float(game.call("_look_pitch_sign")), -1.0), "invert look must flip the pitch direction for every look device")

	settings["fov"] = 90.0
	settings["invert_look"] = false
	game.call("_apply_settings", settings)
	if camera != null:
		camera.fov = 90.0
		game.set("_fling_fov_kick", 8.0)
		game.call("_update_speed_fov", 0.1)
		_check(camera.fov > 90.0, "fling FOV kick must add on top of the configured base FOV")
	game.free()


func _spawn_pause() -> Node:
	var pause := PAUSE_SCENE.instantiate()
	pause.set("settings_path", CFG_PATH)
	root.add_child(pause)
	await process_frame
	return pause


func _action_has_code(action: String, code: String) -> bool:
	var event := INPUT_BINDINGS.decode_event(code)
	return event != null and InputMap.action_has_event(action, event)


func _remove_cfg() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(CFG_PATH))


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
