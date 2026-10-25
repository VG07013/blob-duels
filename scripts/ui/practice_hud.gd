class_name PracticeHud
extends CanvasLayer

## The practice-only HUD: a live statistics card that is always on screen while
## training, plus the single control panel the spec asks for in place of eight
## physical terminals. Deliberately separate from DuelHud - nothing here should
## ever appear in a duel.

const UI_TOKENS := preload("res://scripts/ui/ui_tokens.gd")
const TRAINING := preload("res://scripts/practice_training.gd")

signal reset_position_requested
signal clear_projectiles_requested
signal panel_visibility_changed(panel_visible: bool)

const STAT_ROWS: Array[String] = [
	"Weapon", "Shots fired", "Shots hit", "Accuracy", "Streak",
	"Damage", "Time", "Dummy mode", "Speed", "Best combo",
]

var _session: PracticeSession = null
var _stat_values: Dictionary = {}
var _stat_card: PanelContainer
var _control_panel: PanelContainer
var _mode_picker: OptionButton
var _health_picker: OptionButton
var _speed_picker: OptionButton
var _toggles: Dictionary = {}
var _weapon_name := "Blaster"
var _syncing := false


func _ready() -> void:
	layer = 3
	_build_stat_card()
	_build_control_panel()
	set_panel_open(false)
	visible = false


## game.gd owns the session; the HUD only reads it and pushes the player's
## choices back through its setters.
func bind_session(session: PracticeSession) -> void:
	if _session == session:
		return
	if _session != null and is_instance_valid(_session):
		if _session.stats_changed.is_connected(_refresh_stats):
			_session.stats_changed.disconnect(_refresh_stats)
		if _session.config_changed.is_connected(_sync_controls):
			_session.config_changed.disconnect(_sync_controls)
	_session = session
	if _session == null:
		return
	_session.stats_changed.connect(_refresh_stats)
	_session.config_changed.connect(_sync_controls)
	_sync_controls()
	_refresh_stats()


func set_practice_active(active: bool) -> void:
	visible = active
	if not active:
		set_panel_open(false)


func set_weapon_label(weapon_name: String) -> void:
	_weapon_name = weapon_name.strip_edges()
	if _weapon_name.is_empty():
		_weapon_name = "Blaster"
	_refresh_stats()


func is_panel_open() -> bool:
	return _control_panel != null and _control_panel.visible


func toggle_panel() -> void:
	set_panel_open(not is_panel_open())


func set_panel_open(open: bool) -> void:
	if _control_panel == null or _control_panel.visible == open:
		return
	_control_panel.visible = open
	panel_visibility_changed.emit(open)


## Statistics card ---------------------------------------------------------------
func _build_stat_card() -> void:
	_stat_card = PanelContainer.new()
	_stat_card.name = "PracticeStats"
	_stat_card.add_theme_stylebox_override("panel", _card_style())
	_stat_card.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_stat_card.position = Vector2(-268.0, 24.0)
	_stat_card.custom_minimum_size = Vector2(244.0, 0.0)
	_stat_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stat_card)

	var stack := VBoxContainer.new()
	stack.name = "Stack"
	stack.add_theme_constant_override("separation", UI_TOKENS.SPACE_XS)
	_stat_card.add_child(stack)

	var heading := Label.new()
	heading.name = "Heading"
	heading.text = "TRAINING"
	heading.add_theme_font_size_override("font_size", 13)
	heading.add_theme_color_override("font_color", UI_TOKENS.COLOR_CYAN)
	stack.add_child(heading)

	for row_name in STAT_ROWS:
		var row := HBoxContainer.new()
		row.name = row_name.replace(" ", "")
		row.add_theme_constant_override("separation", UI_TOKENS.SPACE_SM)
		stack.add_child(row)

		var label := Label.new()
		label.name = "Label"
		label.text = row_name
		label.add_theme_font_size_override("font_size", 13)
		label.add_theme_color_override("font_color", UI_TOKENS.COLOR_MUTED)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)

		var value := Label.new()
		value.name = "Value"
		value.text = "-"
		value.add_theme_font_size_override("font_size", 13)
		value.add_theme_color_override("font_color", UI_TOKENS.COLOR_TEXT)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(value)
		_stat_values[row_name] = value

	var hint := Label.new()
	hint.name = "Hint"
	hint.text = "Tab - practice controls"
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", UI_TOKENS.COLOR_MUTED)
	stack.add_child(hint)


func _refresh_stats() -> void:
	if _session == null or not is_instance_valid(_session):
		return
	_set_stat("Weapon", _weapon_name)
	_set_stat("Shots fired", str(_session.shots_fired))
	_set_stat("Shots hit", str(_session.shots_hit))
	_set_stat("Accuracy", "%.1f%%" % _session.get_accuracy())
	_set_stat("Streak", "%d (best %d)" % [_session.current_streak, _session.best_streak])
	_set_stat("Damage", str(_session.damage_dealt))
	_set_stat("Time", _format_time(_session.elapsed_time))
	_set_stat("Dummy mode", TRAINING.mode_label(_session.dummy_mode))
	_set_stat("Speed", "%.1f u/s" % _session.get_player_speed())
	_set_stat("Best combo", str(_session.best_combo))


func _set_stat(row_name: String, value: String) -> void:
	var label := _stat_values.get(row_name) as Label
	if label != null:
		label.text = value


func _format_time(seconds: float) -> String:
	var whole := int(seconds)
	return "%d:%02d.%d" % [whole / 60, whole % 60, int(fmod(seconds, 1.0) * 10.0)]


## Control panel -----------------------------------------------------------------
func _build_control_panel() -> void:
	# Centred in its own full-rect container: the panel is a deliberate stop
	# (aiming is locked while it is open) and centring keeps it clear of the
	# statistics card no matter how tall the control list grows.
	var centre := CenterContainer.new()
	centre.name = "ControlLayer"
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centre)

	_control_panel = PanelContainer.new()
	_control_panel.name = "PracticeControls"
	_control_panel.add_theme_stylebox_override("panel", _card_style(0.97))
	_control_panel.custom_minimum_size = Vector2(348.0, 0.0)
	centre.add_child(_control_panel)

	var stack := VBoxContainer.new()
	stack.name = "Stack"
	stack.add_theme_constant_override("separation", UI_TOKENS.SPACE_SM)
	_control_panel.add_child(stack)

	var heading := Label.new()
	heading.name = "Heading"
	heading.text = "PRACTICE CONTROLS"
	heading.add_theme_font_size_override("font_size", 14)
	heading.add_theme_color_override("font_color", UI_TOKENS.COLOR_CYAN)
	stack.add_child(heading)

	_mode_picker = _add_picker(stack, "DummyBehaviour", "Dummy behaviour", TRAINING.MODE_LABELS)
	_mode_picker.item_selected.connect(_on_mode_selected)
	_health_picker = _add_picker(stack, "DummyHealth", "Dummy health", TRAINING.HEALTH_LABELS)
	_health_picker.item_selected.connect(_on_health_selected)
	_speed_picker = _add_picker(stack, "DummySpeed", "Movement speed", TRAINING.SPEED_LABELS)
	_speed_picker.item_selected.connect(_on_speed_selected)

	_add_toggle(stack, "DummyMovement", "Dummy movement", _on_movement_toggled)
	_add_toggle(stack, "DummyShooting", "Dummy shooting", _on_shooting_toggled)
	_add_toggle(stack, "DamageNumbers", "Damage numbers", _on_damage_numbers_toggled)
	_add_toggle(stack, "PlayerInvincible", "Player invincibility", _on_invincible_toggled)
	_add_toggle(stack, "InfiniteAmmo", "Infinite ammo", _on_infinite_ammo_toggled)
	_add_toggle(stack, "Cooldowns", "Cooldowns", _on_cooldowns_toggled)

	var actions := GridContainer.new()
	actions.name = "Actions"
	actions.columns = 2
	actions.add_theme_constant_override("h_separation", UI_TOKENS.SPACE_SM)
	actions.add_theme_constant_override("v_separation", UI_TOKENS.SPACE_SM)
	stack.add_child(actions)

	_add_action(actions, "ResetPosition", "Reset position", func() -> void: reset_position_requested.emit())
	_add_action(actions, "ResetDummies", "Reset dummies", _on_reset_dummies)
	_add_action(actions, "ResetStats", "Reset stats", _on_reset_stats)
	_add_action(actions, "ResetTimer", "Reset timer", _on_reset_timer)
	_add_action(actions, "ClearProjectiles", "Clear shots", func() -> void: clear_projectiles_requested.emit())
	_add_action(actions, "CloseControls", "Close", func() -> void: set_panel_open(false))


func _add_picker(parent: Node, node_name: String, caption: String, options: Array[String]) -> OptionButton:
	var row := HBoxContainer.new()
	row.name = node_name
	row.add_theme_constant_override("separation", UI_TOKENS.SPACE_SM)
	parent.add_child(row)

	var label := Label.new()
	label.name = "Label"
	label.text = caption
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", UI_TOKENS.COLOR_MUTED)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	var picker := OptionButton.new()
	picker.name = "Picker"
	picker.add_theme_font_size_override("font_size", 13)
	picker.custom_minimum_size = Vector2(132.0, 0.0)
	picker.focus_mode = Control.FOCUS_NONE
	for option in options:
		picker.add_item(option)
	row.add_child(picker)
	return picker


func _add_toggle(parent: Node, node_name: String, caption: String, handler: Callable) -> void:
	var toggle := CheckButton.new()
	toggle.name = node_name
	toggle.text = caption
	toggle.add_theme_font_size_override("font_size", 13)
	toggle.focus_mode = Control.FOCUS_NONE
	toggle.toggled.connect(handler)
	parent.add_child(toggle)
	_toggles[node_name] = toggle


func _add_action(parent: Node, node_name: String, caption: String, handler: Callable) -> void:
	var button := Button.new()
	button.name = node_name
	button.text = caption
	button.add_theme_font_size_override("font_size", 13)
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(handler)
	parent.add_child(button)


## Pushes session state into the widgets. _syncing guards the round trip so
## refreshing the panel never re-fires the setters it is displaying.
func _sync_controls() -> void:
	if _session == null or not is_instance_valid(_session):
		return
	_syncing = true
	_mode_picker.selected = TRAINING.MODE_IDS.find(_session.dummy_mode)
	_health_picker.selected = TRAINING.HEALTH_PRESETS.find(_session.dummy_health_preset)
	var speed_index := TRAINING.SPEED_SCALES.find(_session.dummy_speed_scale)
	_speed_picker.selected = speed_index if speed_index >= 0 else TRAINING.SPEED_SCALES.find(TRAINING.DEFAULT_SPEED_SCALE)
	_set_toggle("DummyMovement", _session.dummy_movement_enabled)
	_set_toggle("DummyShooting", _session.dummy_shooting_enabled)
	_set_toggle("DamageNumbers", _session.damage_numbers_enabled)
	_set_toggle("PlayerInvincible", _session.player_invincible)
	_set_toggle("InfiniteAmmo", _session.infinite_ammo)
	_set_toggle("Cooldowns", _session.cooldowns_enabled)
	_syncing = false
	_refresh_stats()


func _set_toggle(node_name: String, pressed: bool) -> void:
	var toggle := _toggles.get(node_name) as CheckButton
	if toggle != null:
		toggle.button_pressed = pressed


func _on_mode_selected(index: int) -> void:
	if _syncing or _session == null:
		return
	_session.set_dummy_mode(TRAINING.MODE_IDS[index])


func _on_health_selected(index: int) -> void:
	if _syncing or _session == null:
		return
	_session.set_dummy_health_preset(TRAINING.HEALTH_PRESETS[index])


func _on_speed_selected(index: int) -> void:
	if _syncing or _session == null:
		return
	_session.set_dummy_speed_scale(TRAINING.SPEED_SCALES[index])


func _on_movement_toggled(pressed: bool) -> void:
	if _syncing or _session == null:
		return
	_session.set_dummy_movement_enabled(pressed)


func _on_shooting_toggled(pressed: bool) -> void:
	if _syncing or _session == null:
		return
	_session.set_dummy_shooting_enabled(pressed)


func _on_damage_numbers_toggled(pressed: bool) -> void:
	if _syncing or _session == null:
		return
	_session.set_damage_numbers_enabled(pressed)


func _on_invincible_toggled(pressed: bool) -> void:
	if _syncing or _session == null:
		return
	_session.set_player_invincible(pressed)


func _on_infinite_ammo_toggled(pressed: bool) -> void:
	if _syncing or _session == null:
		return
	_session.set_infinite_ammo(pressed)


func _on_cooldowns_toggled(pressed: bool) -> void:
	if _syncing or _session == null:
		return
	_session.set_cooldowns_enabled(pressed)


func _on_reset_dummies() -> void:
	if _session != null:
		_session.reset_dummies()


func _on_reset_stats() -> void:
	if _session != null:
		_session.reset_stats()


func _on_reset_timer() -> void:
	if _session != null:
		_session.reset_timer()


func _card_style(opacity: float = 0.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = UI_TOKENS.COLOR_INK
	if opacity > 0.0:
		style.bg_color.a = opacity
	style.corner_radius_top_left = UI_TOKENS.RADIUS_MD
	style.corner_radius_top_right = UI_TOKENS.RADIUS_MD
	style.corner_radius_bottom_left = UI_TOKENS.RADIUS_MD
	style.corner_radius_bottom_right = UI_TOKENS.RADIUS_MD
	style.content_margin_left = UI_TOKENS.SPACE_MD
	style.content_margin_right = UI_TOKENS.SPACE_MD
	style.content_margin_top = UI_TOKENS.SPACE_MD
	style.content_margin_bottom = UI_TOKENS.SPACE_MD
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = Color(UI_TOKENS.COLOR_CYAN.r, UI_TOKENS.COLOR_CYAN.g, UI_TOKENS.COLOR_CYAN.b, 0.22)
	return style
