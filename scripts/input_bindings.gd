class_name InputBindings
extends RefCounted

# Single source of truth for rebindable actions, their default keyboard/mouse
# and gamepad events, the compact encoding persisted under [bindings] in the
# settings cfg, and the look/FOV tuning that game.gd reads. Nothing in here
# touches UI; PauseMenu owns the Controls tab and game.gd owns the camera.

const BINDINGS_SECTION := "bindings"
## Bumped when default bindings move in a way saved configs must follow.
const LAYOUT_VERSION := 2
const LAYOUT_VERSION_KEY := "layout_version"
const SLOT_KEYBOARD := "keyboard"
const SLOT_JOYPAD := "joypad"
const SLOTS := [SLOT_KEYBOARD, SLOT_JOYPAD]

# Right-stick look. Sensitivity is radians per second at full deflection; the
# deadzone is the radial deadzone handed to Input.get_vector.
const GAMEPAD_LOOK_DEADZONE := 0.2
const GAMEPAD_SENSITIVITY_DEFAULT := 2.4
const GAMEPAD_SENSITIVITY_MIN := 0.8
const GAMEPAD_SENSITIVITY_MAX := 6.0
const GAMEPAD_SENSITIVITY_STEP := 0.1
# How far an axis must travel before the rebind listener accepts it as a
# deliberate press (keeps stick drift from binding itself).
const REBIND_AXIS_THRESHOLD := 0.6

# Field of view. The setting is the third-person base (the default camera);
# first person keeps its historical +12 degrees on top of it. Fling kick,
# speed bonus, and charge tension all add on top of whichever base is active.
const FOV_MIN := 60.0
const FOV_MAX := 110.0
const FOV_DEFAULT := 76.0
const FOV_STEP := 1.0
const FIRST_PERSON_FOV_OFFSET := 12.0

# Ordered list drives the Controls tab. Every entry must have both slots in
# DEFAULTS; the contract test enforces that.
const REBINDABLE_ACTIONS: Array[Dictionary] = [
	{"action": "move_forward", "label": "Move forward"},
	{"action": "move_back", "label": "Move back"},
	{"action": "move_left", "label": "Move left"},
	{"action": "move_right", "label": "Move right"},
	{"action": "bounce", "label": "Bounce"},
	{"action": "brake", "label": "Brake"},
	{"action": "slide", "label": "Slide"},
	{"action": "charge_fling", "label": "Charge fling"},
	{"action": "shoot", "label": "Shoot"},
	{"action": "aim", "label": "Aim in"},
	{"action": "slot_blaster", "label": "Hotbar 1: Blaster"},
	{"action": "slot_blob", "label": "Hotbar 2: Blob"},
	{"action": "quick_blob", "label": "Quick blob"},
	{"action": "use_ability", "label": "Use power-up"},
	{"action": "toggle_camera", "label": "Toggle camera"},
	{"action": "practice_panel", "label": "Practice panel"},
	{"action": "pause", "label": "Pause / menu"},
]
# Right-stick look is analog-only; it lives in project.godot but is not
# rebindable from the menu.
const LOOK_ACTIONS: Array[String] = ["look_up", "look_down", "look_left", "look_right"]

# Encodings: "key:<physical_keycode>", "keycode:<keycode>", "mouse:<button>",
# "joybtn:<button>", "joyaxis:<axis>:<-1|1>". These mirror project.godot; a
# reset restores exactly this table.
const DEFAULTS := {
	"move_forward": {"keyboard": "key:87", "joypad": "joyaxis:1:-1"},
	"move_back": {"keyboard": "key:83", "joypad": "joyaxis:1:1"},
	"move_left": {"keyboard": "key:65", "joypad": "joyaxis:0:-1"},
	"move_right": {"keyboard": "key:68", "joypad": "joyaxis:0:1"},
	"bounce": {"keyboard": "key:32", "joypad": "joybtn:0"},
	"brake": {"keyboard": "key:4194325", "joypad": "joybtn:10"},
	"slide": {"keyboard": "key:67", "joypad": "joybtn:8"},
	"charge_fling": {"keyboard": "keycode:81", "joypad": "joybtn:9"},
	"shoot": {"keyboard": "mouse:1", "joypad": "joyaxis:5:1"},
	"aim": {"keyboard": "mouse:2", "joypad": "joyaxis:4:1"},
	"slot_blaster": {"keyboard": "keycode:49", "joypad": "joybtn:13"},
	"slot_blob": {"keyboard": "keycode:50", "joypad": "joybtn:14"},
	"quick_blob": {"keyboard": "keycode:70", "joypad": "joybtn:1"},
	"use_ability": {"keyboard": "keycode:69", "joypad": "joybtn:2"},
	"toggle_camera": {"keyboard": "keycode:4194336", "joypad": "joybtn:3"},
	"practice_panel": {"keyboard": "keycode:4194306", "joypad": "joybtn:4"},
	"pause": {"keyboard": "keycode:4194305", "joypad": "joybtn:6"},
}

const JOY_BUTTON_NAMES := {
	JOY_BUTTON_A: "A / Cross",
	JOY_BUTTON_B: "B / Circle",
	JOY_BUTTON_X: "X / Square",
	JOY_BUTTON_Y: "Y / Triangle",
	JOY_BUTTON_BACK: "Back / Select",
	JOY_BUTTON_GUIDE: "Guide",
	JOY_BUTTON_START: "Start",
	JOY_BUTTON_LEFT_STICK: "L3",
	JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_LEFT_SHOULDER: "LB",
	JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_DPAD_UP: "D-pad Up",
	JOY_BUTTON_DPAD_DOWN: "D-pad Down",
	JOY_BUTTON_DPAD_LEFT: "D-pad Left",
	JOY_BUTTON_DPAD_RIGHT: "D-pad Right",
}
const JOY_AXIS_NAMES := {
	JOY_AXIS_LEFT_X: ["LS Left", "LS Right"],
	JOY_AXIS_LEFT_Y: ["LS Up", "LS Down"],
	JOY_AXIS_RIGHT_X: ["RS Left", "RS Right"],
	JOY_AXIS_RIGHT_Y: ["RS Up", "RS Down"],
	JOY_AXIS_TRIGGER_LEFT: ["LT", "LT"],
	JOY_AXIS_TRIGGER_RIGHT: ["RT", "RT"],
}
const MOUSE_BUTTON_NAMES := {
	MOUSE_BUTTON_LEFT: "Left Click",
	MOUSE_BUTTON_RIGHT: "Right Click",
	MOUSE_BUTTON_MIDDLE: "Middle Click",
	MOUSE_BUTTON_WHEEL_UP: "Wheel Up",
	MOUSE_BUTTON_WHEEL_DOWN: "Wheel Down",
	MOUSE_BUTTON_XBUTTON1: "Mouse 4",
	MOUSE_BUTTON_XBUTTON2: "Mouse 5",
}


static func action_names() -> Array[String]:
	var names: Array[String] = []
	for entry in REBINDABLE_ACTIONS:
		names.append(str(entry["action"]))
	return names


static func label_for(action: String) -> String:
	for entry in REBINDABLE_ACTIONS:
		if str(entry["action"]) == action:
			return str(entry["label"])
	return action.capitalize()


static func default_bindings() -> Dictionary:
	return DEFAULTS.duplicate(true)


# Fills gaps with defaults and drops anything that does not decode, so a
# hand-edited or stale cfg can never leave an action unbound.
static func normalize(bindings: Dictionary) -> Dictionary:
	var normalized := default_bindings()
	for action in normalized:
		var stored: Variant = bindings.get(action, {})
		if not (stored is Dictionary):
			continue
		for slot in SLOTS:
			var code := str((stored as Dictionary).get(slot, ""))
			if decode_event(code) != null and slot_for_code(code) == slot:
				normalized[action][slot] = code
	return normalized


static func load_from_config(config: ConfigFile) -> Dictionary:
	var stored := {}
	if config.has_section(BINDINGS_SECTION):
		for action in config.get_section_keys(BINDINGS_SECTION):
			if action == LAYOUT_VERSION_KEY:
				continue
			stored[action] = config.get_value(BINDINGS_SECTION, action, {})
	if int(config.get_value(BINDINGS_SECTION, LAYOUT_VERSION_KEY, 1)) < LAYOUT_VERSION:
		_migrate_layout_v1(stored)
	return normalize(stored)


static func save_to_config(config: ConfigFile, bindings: Dictionary) -> void:
	for action in normalize(bindings):
		config.set_value(BINDINGS_SECTION, action, bindings[action].duplicate(true))
	config.set_value(BINDINGS_SECTION, LAYOUT_VERSION_KEY, LAYOUT_VERSION)


# Layout 1 charged the fling on right click / left trigger. Layout 2 gives
# those to "aim" and moves the fling to Q / LB, so a save that still holds the
# old defaults drops them and picks up the new ones. Custom choices survive.
static func _migrate_layout_v1(stored: Dictionary) -> void:
	var fling: Variant = stored.get("charge_fling", {})
	if not (fling is Dictionary):
		return
	var fling_slots := (fling as Dictionary).duplicate()
	if str(fling_slots.get(SLOT_KEYBOARD, "")) == "mouse:2":
		fling_slots.erase(SLOT_KEYBOARD)
	if str(fling_slots.get(SLOT_JOYPAD, "")) == "joyaxis:4:1":
		fling_slots.erase(SLOT_JOYPAD)
	stored["charge_fling"] = fling_slots


# Replaces every rebindable action's events with the bound pair. Actions the
# project does not define yet (e.g. "pause" on an older project.godot) are
# created so the game never dereferences a missing action.
static func apply_to_input_map(bindings: Dictionary) -> void:
	var normalized := normalize(bindings)
	for action in normalized:
		var action_name := StringName(action)
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
		InputMap.action_erase_events(action_name)
		for slot in SLOTS:
			var event := decode_event(str(normalized[action][slot]))
			if event != null:
				InputMap.action_add_event(action_name, event)


# Binds `code` into `action`'s slot. If another action already holds that
# code in the same slot, the two actions swap so nothing ends up unbound.
# Returns the name of the action that was swapped with, or "" when none.
static func assign(bindings: Dictionary, action: String, slot: String, code: String) -> String:
	if not bindings.has(action) or slot not in SLOTS or decode_event(code) == null or slot_for_code(code) != slot:
		return ""
	var previous := str(bindings[action][slot])
	var swapped_with := ""
	for other in bindings:
		if other != action and str(bindings[other][slot]) == code:
			bindings[other][slot] = previous
			swapped_with = str(other)
			break
	bindings[action][slot] = code
	return swapped_with


static func slot_for_code(code: String) -> String:
	if code.begins_with("key:") or code.begins_with("keycode:") or code.begins_with("mouse:"):
		return SLOT_KEYBOARD
	if code.begins_with("joybtn:") or code.begins_with("joyaxis:"):
		return SLOT_JOYPAD
	return ""


static func slot_for_event(event: InputEvent) -> String:
	if event is InputEventKey or event is InputEventMouseButton:
		return SLOT_KEYBOARD
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		return SLOT_JOYPAD
	return ""


# Turns a live event into a binding code, or "" when the event is not a
# deliberate press (releases, echoes, axis drift under the threshold).
static func encode_event(event: InputEvent) -> String:
	var key := event as InputEventKey
	if key != null:
		if not key.pressed or key.echo:
			return ""
		if key.physical_keycode != KEY_NONE:
			return "key:%d" % int(key.physical_keycode)
		if key.keycode != KEY_NONE:
			return "keycode:%d" % int(key.keycode)
		return ""
	var mouse := event as InputEventMouseButton
	if mouse != null:
		return "mouse:%d" % int(mouse.button_index) if mouse.pressed else ""
	var joy_button := event as InputEventJoypadButton
	if joy_button != null:
		return "joybtn:%d" % int(joy_button.button_index) if joy_button.pressed else ""
	var joy_motion := event as InputEventJoypadMotion
	if joy_motion != null:
		if absf(joy_motion.axis_value) < REBIND_AXIS_THRESHOLD:
			return ""
		return "joyaxis:%d:%d" % [int(joy_motion.axis), 1 if joy_motion.axis_value > 0.0 else -1]
	return ""


static func decode_event(code: String) -> InputEvent:
	var parts := code.split(":")
	if parts.size() < 2 or not parts[1].is_valid_int():
		return null
	var value := int(parts[1])
	match parts[0]:
		"key":
			if value <= 0:
				return null
			var key := InputEventKey.new()
			key.physical_keycode = value as Key
			return key
		"keycode":
			if value <= 0:
				return null
			var key := InputEventKey.new()
			key.keycode = value as Key
			return key
		"mouse":
			if value < MOUSE_BUTTON_LEFT or value > MOUSE_BUTTON_XBUTTON2:
				return null
			var mouse := InputEventMouseButton.new()
			mouse.button_index = value as MouseButton
			return mouse
		"joybtn":
			if value < 0 or value >= JOY_BUTTON_SDL_MAX:
				return null
			var joy_button := InputEventJoypadButton.new()
			joy_button.button_index = value as JoyButton
			return joy_button
		"joyaxis":
			if parts.size() < 3 or not parts[2].is_valid_int() or value < 0 or value >= JOY_AXIS_SDL_MAX:
				return null
			var sign_value := int(parts[2])
			if sign_value != 1 and sign_value != -1:
				return null
			var joy_motion := InputEventJoypadMotion.new()
			joy_motion.axis = value as JoyAxis
			joy_motion.axis_value = float(sign_value)
			return joy_motion
	return null


static func describe(code: String) -> String:
	var event := decode_event(code)
	if event == null:
		return "Unbound"
	var key := event as InputEventKey
	if key != null:
		var keycode := key.keycode
		# Layout-aware label where a real display server exists; the headless
		# server used by the contract suite does not implement the lookup.
		if keycode == KEY_NONE and DisplayServer.get_name() != "headless":
			keycode = DisplayServer.keyboard_get_keycode_from_physical(key.physical_keycode)
		if keycode == KEY_NONE:
			keycode = key.physical_keycode
		return OS.get_keycode_string(keycode)
	var mouse := event as InputEventMouseButton
	if mouse != null:
		return str(MOUSE_BUTTON_NAMES.get(mouse.button_index, "Mouse %d" % int(mouse.button_index)))
	var joy_button := event as InputEventJoypadButton
	if joy_button != null:
		return str(JOY_BUTTON_NAMES.get(joy_button.button_index, "Button %d" % int(joy_button.button_index)))
	var joy_motion := event as InputEventJoypadMotion
	if joy_motion != null:
		var names: Array = JOY_AXIS_NAMES.get(joy_motion.axis, ["Axis %d -" % int(joy_motion.axis), "Axis %d +" % int(joy_motion.axis)])
		return str(names[1] if joy_motion.axis_value > 0.0 else names[0])
	return "Unbound"


static func clamp_gamepad_sensitivity(value: float) -> float:
	return clampf(value, GAMEPAD_SENSITIVITY_MIN, GAMEPAD_SENSITIVITY_MAX)


static func clamp_fov(value: float) -> float:
	return clampf(value, FOV_MIN, FOV_MAX)
