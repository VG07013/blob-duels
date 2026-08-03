extends CanvasLayer

signal resume_requested
signal respawn_requested
signal back_to_lobby_requested
signal settings_applied(settings: Dictionary)

const SETTINGS_PATH := "user://blob_duels_settings.cfg"
const CROSSHAIR_KEYS := [
	"crosshair_length", "crosshair_thickness", "crosshair_gap", "crosshair_dot",
	"crosshair_dot_size", "crosshair_outline", "crosshair_outline_thickness",
	"crosshair_color_index", "crosshair_color_value", "crosshair_opacity",
	"crosshair_dynamic", "crosshair_dynamic_amount", "crosshair_rotation",
]
const CROSSHAIR_COLORS := [
	Color.WHITE, Color(0.2, 0.92, 1.0), Color(0.25, 1.0, 0.42),
	Color(1.0, 0.82, 0.16), Color(1.0, 0.26, 0.4), Color(0.92, 0.28, 1.0),
]
@onready var match_page: Control = $PausePanel/Content/Pages/MatchPage
@onready var settings_page: Control = $PausePanel/Content/Pages/SettingsPage
@onready var crosshair_page: Control = $PausePanel/Content/Pages/CrosshairPage
@onready var backdrop: ColorRect = $Backdrop
@onready var pause_panel: PanelContainer = $PausePanel
@onready var state_pill: PanelContainer = $PausePanel/Content/Header/StatePill
@onready var state_label: Label = $PausePanel/Content/Header/StatePill/State
@onready var match_tab: Button = $PausePanel/Content/Tabs/MatchTab
@onready var settings_tab: Button = $PausePanel/Content/Tabs/SettingsTab
@onready var crosshair_tab: Button = $PausePanel/Content/Tabs/CrosshairTab
@onready var crosshair_preview_panel: PanelContainer = $PausePanel/Content/Pages/CrosshairPage/Layout/Preview
@onready var preview_crosshair: Control = $PausePanel/Content/Pages/CrosshairPage/Layout/Preview/PreviewStack/Crosshair
@onready var settings_rows: VBoxContainer = $PausePanel/Content/Pages/SettingsPage/Scroll/Rows
@onready var crosshair_rows: VBoxContainer = $PausePanel/Content/Pages/CrosshairPage/Layout/Editor/RowsScroll/Rows
@onready var ability_card: PanelContainer = $PausePanel/Content/Pages/MatchPage/Stack/AbilityCard
@onready var ability_icon: TextureRect = $PausePanel/Content/Pages/MatchPage/Stack/AbilityCard/Row/Icon
@onready var ability_name: Label = $PausePanel/Content/Pages/MatchPage/Stack/AbilityCard/Row/Copy/Name
@onready var host_code_card: PanelContainer = $PausePanel/Content/Pages/MatchPage/Stack/HostCodeCard
@onready var host_code_value: Label = $PausePanel/Content/Pages/MatchPage/Stack/HostCodeCard/Row/Copy/HostCodeValue

var _settings: Dictionary = {}
var _active_slot := 1
var _ui_font: SystemFont
var _active_page_index := -1
var _page_tween: Tween
var _save_status: Label
@export var settings_path := SETTINGS_PATH


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_ui_font = SystemFont.new()
	_ui_font.font_names = PackedStringArray(["SF Pro Display", "Avenir Next", "Helvetica Neue", "Arial"])
	_settings = _load_settings()
	_active_slot = clampi(int(_settings.get("active_crosshair_slot", 1)), 1, 3)
	_apply_compact_visual_system()
	_connect_navigation()
	_build_general_settings()
	_build_crosshair_settings()
	_disable_keyboard_focus()
	_apply_preview()
	get_viewport().size_changed.connect(_fit_to_viewport)
	_fit_to_viewport()


func _apply_compact_visual_system() -> void:
	backdrop.color = Color(0.006, 0.01, 0.018, 0.46)
	var shell := StyleBoxFlat.new()
	shell.bg_color = Color(0.025, 0.034, 0.052, 0.88)
	shell.border_color = Color(0.48, 0.64, 0.82, 0.38)
	shell.set_border_width_all(1)
	shell.set_corner_radius_all(16)
	shell.content_margin_left = 22.0
	shell.content_margin_top = 18.0
	shell.content_margin_right = 22.0
	shell.content_margin_bottom = 18.0
	shell.shadow_color = Color(0.0, 0.0, 0.0, 0.38)
	shell.shadow_size = 14
	shell.shadow_offset = Vector2(0, 6)
	pause_panel.add_theme_stylebox_override("panel", shell)
	var header := pause_panel.get_node("Content/Header") as Control
	header.custom_minimum_size.y = 46.0
	var pages := pause_panel.get_node("Content/Pages") as Control
	pages.custom_minimum_size.y = 300.0
	for tab in [match_tab, settings_tab, crosshair_tab]:
		tab.custom_minimum_size = Vector2(138, 40)
	for action_path in ["Content/Actions/LobbyButton", "Content/Actions/RespawnButton", "Content/Actions/ResumeButton"]:
		var action := pause_panel.get_node(action_path) as Button
		action.custom_minimum_size.y = 48.0


func _connect_navigation() -> void:
	$PausePanel/Content/Actions/ResumeButton.pressed.connect(func() -> void: resume_requested.emit())
	$PausePanel/Content/Actions/RespawnButton.pressed.connect(func() -> void: respawn_requested.emit())
	$PausePanel/Content/Actions/LobbyButton.pressed.connect(func() -> void: back_to_lobby_requested.emit())
	$PausePanel/Content/Tabs/MatchTab.pressed.connect(_show_page.bind(0))
	$PausePanel/Content/Tabs/SettingsTab.pressed.connect(_show_page.bind(1))
	$PausePanel/Content/Tabs/CrosshairTab.pressed.connect(_show_page.bind(2))
	for slot in range(1, 4):
		var button := get_node("PausePanel/Content/Pages/CrosshairPage/Layout/Editor/Slots/Slot%d" % slot) as Button
		button.pressed.connect(_select_crosshair_slot.bind(slot))


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		resume_requested.emit()
		get_viewport().set_input_as_handled()


func open_pause() -> void:
	visible = true
	get_viewport().gui_release_focus()
	backdrop.modulate.a = 0.0
	pause_panel.modulate.a = 0.0
	pause_panel.scale = Vector2(0.96, 0.96)
	pause_panel.pivot_offset = pause_panel.size * 0.5
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	var reduced_motion := bool(_settings.get("reduced_motion", false))
	tween.set_parallel(true)
	tween.tween_property(backdrop, "modulate:a", 1.0, 0.08 if reduced_motion else 0.16)
	tween.tween_property(pause_panel, "modulate:a", 1.0, 0.08 if reduced_motion else 0.16)
	tween.tween_property(pause_panel, "scale", Vector2.ONE, 0.01 if reduced_motion else 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_show_page(0)


func show_settings() -> void:
	_show_page(1)


func set_context(is_duel: bool, is_practice: bool, equipped_ability_id: String = "", equipped_ability_icon: Texture2D = null) -> void:
	var match_rule := $PausePanel/Content/Pages/MatchPage/Stack/MatchRule as Label
	var respawn_rule := $PausePanel/Content/Pages/MatchPage/Stack/RespawnRule as Label
	var respawn_button := $PausePanel/Content/Actions/RespawnButton as Button
	state_pill.visible = is_practice
	respawn_button.visible = is_duel or is_practice
	if is_duel:
		state_label.text = ""
		match_rule.text = "RED VS BLUE  |  FIRST TO 5"
		respawn_rule.text = "Respawning during a duel awards the opposing team a point."
	elif is_practice:
		state_label.text = "PRACTICE"
		match_rule.text = "PRACTICE"
		respawn_rule.text = "Respawn returns your blob to the practice spawn."
	else:
		state_label.text = "LOBBY"
		match_rule.text = "LOBBY"
		respawn_rule.text = "Resume rolling or return to the lobby center."
	set_equipped_ability(equipped_ability_id, equipped_ability_icon)


func set_equipped_ability(ability_id: String, icon: Texture2D = null) -> void:
	var clean_id := ability_id.strip_edges()
	ability_card.visible = not clean_id.is_empty()
	ability_icon.texture = icon
	ability_icon.visible = icon != null
	if clean_id.is_empty():
		ability_name.text = "No ability equipped"
		return
	var words := clean_id.replace("_", " ").split(" ", false)
	for index in words.size():
		words[index] = str(words[index]).capitalize()
	ability_name.text = " ".join(words)


func set_host_room_code(code: String) -> void:
	var clean_code := code.strip_edges().to_upper()
	host_code_value.text = clean_code
	host_code_card.visible = not clean_code.is_empty()
	_fit_to_viewport()


func _disable_keyboard_focus() -> void:
	for child in pause_panel.find_children("*", "Control", true, false):
		var control := child as Control
		if control is BaseButton or control is LineEdit or control is Range or control is ScrollContainer:
			control.focus_mode = Control.FOCUS_NONE


func close_pause() -> void:
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null:
		audio.call("play_sfx", &"ui_close", -10.0)
	visible = false


func is_open() -> bool:
	return visible


func handle_escape() -> void:
	resume_requested.emit()


func get_settings() -> Dictionary:
	return _settings.duplicate(true)


func _show_page(index: int) -> void:
	var pages := [match_page, settings_page, crosshair_page]
	var safe_index := clampi(index, 0, pages.size() - 1)
	var next_page := pages[safe_index] as Control
	if _page_tween != null and _page_tween.is_valid():
		_page_tween.kill()
	for page_value in pages:
		var page := page_value as Control
		if page != next_page:
			page.visible = false
	next_page.visible = true
	next_page.modulate.a = 0.0
	_page_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_page_tween.tween_property(next_page, "modulate:a", 1.0, 0.01 if bool(_settings.get("reduced_motion", false)) else 0.16)
	var header_title := $PausePanel/Content/Header/BrandBlock/Title as Label
	header_title.text = ["Match menu", "Settings", "Crosshair"][safe_index]
	match_tab.button_pressed = index == 0
	settings_tab.button_pressed = index == 1
	crosshair_tab.button_pressed = index == 2
	if safe_index != _active_page_index:
		var audio := get_node_or_null("/root/AudioManager")
		if audio != null and _active_page_index >= 0:
			audio.call("play_sfx", &"ui_open", -11.0, 1.08)
	_active_page_index = safe_index


func _build_general_settings() -> void:
	_clear_children(settings_rows)
	_add_section_header(settings_rows, "CONTROLS", "Tune the feel of aiming and camera movement.")
	_add_slider_row(settings_rows, "Mouse sensitivity", "mouse_sensitivity", 0.0008, 0.006, 0.0001, 10000.0)
	_add_section_header(settings_rows, "AUDIO", "Changes apply immediately.")
	_add_slider_row(settings_rows, "Master volume", "master_volume", 0.0, 1.0, 0.05, 100.0)
	_add_slider_row(settings_rows, "Music volume", "music_volume", 0.0, 1.0, 0.05, 100.0)
	_add_slider_row(settings_rows, "Sound effects", "sfx_volume", 0.0, 1.0, 0.05, 100.0)
	_add_section_header(settings_rows, "VIDEO", "Balance clarity, effects, and performance.")
	_add_option_row(settings_rows, "Graphics quality", "graphics_quality", ["Low", "Balanced", "High"])
	_add_option_row(settings_rows, "Effects density", "effects_quality", ["Low", "Balanced", "High"])
	_add_option_row(settings_rows, "Shadow quality", "shadow_quality", ["Off", "Medium", "High"])
	_add_option_row(settings_rows, "Render scale", "render_scale_index", ["75%", "100%", "125%"])
	_add_toggle_row(settings_rows, "Fullscreen", "fullscreen")
	_add_toggle_row(settings_rows, "Vertical sync", "vsync")
	_add_section_header(settings_rows, "ACCESSIBILITY", "Reduce visual movement without changing gameplay.")
	_add_slider_row(settings_rows, "Camera shake", "camera_shake", 0.0, 1.0, 0.05, 100.0)
	_add_toggle_row(settings_rows, "Reduced motion", "reduced_motion")
	_add_settings_footer()


func _build_crosshair_settings() -> void:
	_clear_children(crosshair_rows)
	_add_section_header(crosshair_rows, "SHAPE")
	_add_slider_row(crosshair_rows, "Line length", "crosshair_length", 2.0, 18.0, 1.0, 1.0)
	_add_slider_row(crosshair_rows, "Thickness", "crosshair_thickness", 1.0, 5.0, 0.5, 1.0)
	_add_slider_row(crosshair_rows, "Center gap", "crosshair_gap", 0.0, 16.0, 1.0, 1.0)
	_add_slider_row(crosshair_rows, "Rotation", "crosshair_rotation", 0.0, 45.0, 1.0, 1.0)
	_add_section_header(crosshair_rows, "APPEARANCE")
	_add_slider_row(crosshair_rows, "Opacity", "crosshair_opacity", 0.2, 1.0, 0.05, 100.0)
	_add_option_row(crosshair_rows, "Color", "crosshair_color_index", ["White", "Cyan", "Green", "Gold", "Red", "Magenta"])
	_add_toggle_row(crosshair_rows, "Center dot", "crosshair_dot")
	_add_slider_row(crosshair_rows, "Dot size", "crosshair_dot_size", 1.0, 6.0, 0.5, 1.0)
	_add_toggle_row(crosshair_rows, "Dark outline", "crosshair_outline")
	_add_slider_row(crosshair_rows, "Outline width", "crosshair_outline_thickness", 0.5, 3.0, 0.5, 1.0)
	_add_section_header(crosshair_rows, "MOTION")
	_add_toggle_row(crosshair_rows, "Charge response", "crosshair_dynamic")
	_add_slider_row(crosshair_rows, "Response amount", "crosshair_dynamic_amount", 0.0, 12.0, 1.0, 1.0)
	_update_slot_buttons()


func _add_slider_row(parent: VBoxContainer, label_text: String, key: String, minimum: float, maximum: float, step: float, display_scale: float) -> void:
	var row := _new_setting_row(parent)
	var label := _setting_label(label_text)
	row.add_child(label)
	var slider := HSlider.new()
	slider.custom_minimum_size = Vector2(150, 30)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value = float(_settings.get(key, minimum))
	row.add_child(slider)
	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(56, 30)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value_label.add_theme_font_size_override("font_size", 14)
	value_label.add_theme_font_override("font", _ui_font)
	value_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	_set_slider_label(value_label, slider.value, display_scale)
	row.add_child(value_label)
	slider.value_changed.connect(func(value: float) -> void:
		_settings[key] = value
		_set_slider_label(value_label, value, display_scale)
		_settings_changed(key)
	)


func _add_toggle_row(parent: VBoxContainer, label_text: String, key: String) -> void:
	var row := _new_setting_row(parent)
	row.add_child(_setting_label(label_text))
	var toggle := CheckButton.new()
	toggle.custom_minimum_size = Vector2(96, 32)
	toggle.text = "ON" if bool(_settings.get(key, false)) else "OFF"
	toggle.button_pressed = bool(_settings.get(key, false))
	toggle.add_theme_color_override("font_color", Color(0.68, 0.76, 0.84))
	toggle.add_theme_color_override("font_pressed_color", Color(0.36, 0.95, 0.84))
	toggle.add_theme_font_size_override("font_size", 14)
	toggle.add_theme_font_override("font", _ui_font)
	toggle.add_theme_stylebox_override("normal", _control_style(Color(0.06, 0.075, 0.1, 0.66), Color(0.28, 0.36, 0.46, 0.54)))
	toggle.add_theme_stylebox_override("hover", _control_style(Color(0.085, 0.11, 0.14, 0.92), Color(0.3, 0.76, 0.82, 0.78)))
	toggle.add_theme_stylebox_override("pressed", _control_style(Color(0.055, 0.16, 0.16, 0.96), Color(0.32, 0.92, 0.8, 0.9)))
	toggle.add_theme_stylebox_override("disabled", _control_style(Color(0.045, 0.05, 0.065, 0.56), Color(0.18, 0.2, 0.24, 0.5)))
	toggle.toggled.connect(func(enabled: bool) -> void:
		_settings[key] = enabled
		toggle.text = "ON" if enabled else "OFF"
		_settings_changed(key)
	)
	row.add_child(toggle)


func _add_option_row(parent: VBoxContainer, label_text: String, key: String, options: Array) -> void:
	var row := _new_setting_row(parent)
	row.add_child(_setting_label(label_text))
	var picker := OptionButton.new()
	picker.custom_minimum_size = Vector2(184, 34)
	picker.add_theme_font_size_override("font_size", 14)
	picker.add_theme_font_override("font", _ui_font)
	picker.add_theme_color_override("font_color", Color(0.86, 0.91, 0.96))
	picker.add_theme_stylebox_override("normal", _control_style(Color(0.09, 0.11, 0.15), Color(0.3, 0.38, 0.48)))
	picker.add_theme_stylebox_override("hover", _control_style(Color(0.12, 0.15, 0.2), Color(0.35, 0.78, 0.88)))
	picker.add_theme_stylebox_override("pressed", _control_style(Color(0.06, 0.075, 0.1), Color(0.31, 0.84, 0.89)))
	picker.add_theme_stylebox_override("disabled", _control_style(Color(0.045, 0.05, 0.065, 0.7), Color(0.18, 0.2, 0.24)))
	for option in options:
		picker.add_item(str(option))
	picker.select(clampi(int(_settings.get(key, 0)), 0, options.size() - 1))
	picker.item_selected.connect(func(index: int) -> void:
		_settings[key] = index
		if key == "crosshair_color_index":
			_settings["crosshair_color_value"] = CROSSHAIR_COLORS[index]
		if key == "render_scale_index":
			_settings["render_scale"] = [0.75, 1.0, 1.25][index]
		_settings_changed(key)
	)
	row.add_child(picker)


func _new_setting_row(parent: VBoxContainer) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 46)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 14)
	parent.add_child(row)
	return row


func _add_section_header(parent: VBoxContainer, title: String, detail: String = "") -> void:
	var header := VBoxContainer.new()
	header.add_theme_constant_override("separation", -1)
	parent.add_child(header)
	var label := Label.new()
	label.text = title
	label.custom_minimum_size = Vector2(0, 25)
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_font_override("font", _ui_font)
	label.add_theme_color_override("font_color", Color(0.34, 0.83, 0.86))
	header.add_child(label)
	if not detail.is_empty():
		var description := Label.new()
		description.text = detail
		description.add_theme_font_size_override("font_size", 11)
		description.add_theme_font_override("font", _ui_font)
		description.add_theme_color_override("font_color", Color(0.52, 0.61, 0.72))
		header.add_child(description)


func _add_settings_footer() -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 44)
	row.add_theme_constant_override("separation", 12)
	settings_rows.add_child(row)
	_save_status = Label.new()
	_save_status.text = "SAVED AUTOMATICALLY"
	_save_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_save_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_save_status.add_theme_font_size_override("font_size", 11)
	_save_status.add_theme_color_override("font_color", Color(0.42, 0.86, 0.72))
	row.add_child(_save_status)
	var reset := Button.new()
	reset.name = "ResetSettingsButton"
	reset.text = "RESET TO DEFAULTS"
	reset.custom_minimum_size = Vector2(164, 38)
	reset.focus_mode = Control.FOCUS_NONE
	reset.add_theme_stylebox_override("normal", _control_style(Color(0.12, 0.075, 0.09, 0.9), Color(0.55, 0.24, 0.3)))
	reset.add_theme_stylebox_override("hover", _control_style(Color(0.2, 0.09, 0.12, 1.0), Color(0.9, 0.38, 0.46)))
	reset.add_theme_stylebox_override("pressed", _control_style(Color(0.08, 0.045, 0.06, 1.0), Color(1.0, 0.45, 0.52)))
	reset.add_theme_stylebox_override("disabled", _control_style(Color(0.06, 0.055, 0.065, 0.72), Color(0.2, 0.2, 0.24)))
	reset.pressed.connect(_reset_general_settings)
	row.add_child(reset)


func _reset_general_settings() -> void:
	var preserved_slot := _active_slot
	_settings = _default_settings()
	_active_slot = preserved_slot
	_settings["active_crosshair_slot"] = preserved_slot
	_build_general_settings()
	_build_crosshair_settings()
	_disable_keyboard_focus()
	_apply_preview()
	_save_settings()
	settings_applied.emit(get_settings())


func _setting_label(text_value: String) -> Label:
	var label := Label.new()
	label.text = text_value
	label.custom_minimum_size = Vector2(160, 30)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 19)
	label.add_theme_font_override("font", _ui_font)
	label.add_theme_color_override("font_color", Color(0.84, 0.89, 0.95))
	return label


func _row_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.068, 0.095, 0.68)
	style.border_color = Color(0.3, 0.48, 0.62, 0.18)
	style.border_width_bottom = 1
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.content_margin_left = 14.0
	style.content_margin_top = 6.0
	style.content_margin_right = 14.0
	style.content_margin_bottom = 6.0
	return style


func _control_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_right = 7
	style.corner_radius_bottom_left = 7
	style.content_margin_left = 12.0
	style.content_margin_right = 10.0
	return style


func _set_slider_label(label: Label, value: float, display_scale: float) -> void:
	label.text = "%d%%" % int(round(value * display_scale)) if display_scale >= 10.0 else ("%.1f" % value)


func _settings_changed(key: String) -> void:
	if key.begins_with("crosshair_"):
		_save_current_crosshair_slot()
	_apply_preview()
	_save_settings()
	if _save_status != null:
		_save_status.text = "SAVED"
	settings_applied.emit(get_settings())


func _select_crosshair_slot(slot: int) -> void:
	_save_current_crosshair_slot()
	_active_slot = clampi(slot, 1, 3)
	_settings["active_crosshair_slot"] = _active_slot
	_load_crosshair_slot(_active_slot)
	_build_crosshair_settings()
	_disable_keyboard_focus()
	_apply_preview()
	_save_settings()
	settings_applied.emit(get_settings())


func _save_current_crosshair_slot() -> void:
	var config := ConfigFile.new()
	config.load(settings_path)
	for key in CROSSHAIR_KEYS:
		config.set_value("crosshair_slot_%d" % _active_slot, key, _settings.get(key))
	config.save(settings_path)


func _load_crosshair_slot(slot: int) -> void:
	var config := ConfigFile.new()
	if config.load(settings_path) != OK:
		return
	for key in CROSSHAIR_KEYS:
		_settings[key] = config.get_value("crosshair_slot_%d" % slot, key, _default_settings().get(key))


func _update_slot_buttons() -> void:
	for slot in range(1, 4):
		var button := get_node("PausePanel/Content/Pages/CrosshairPage/Layout/Editor/Slots/Slot%d" % slot) as Button
		button.text = "SLOT %d%s" % [slot, "  ACTIVE" if slot == _active_slot else ""]


func _apply_preview() -> void:
	if preview_crosshair != null and preview_crosshair.has_method("apply_settings"):
		preview_crosshair.call("apply_settings", _settings)
		preview_crosshair.call("set_dynamic_state", 0.55 if bool(_settings.get("crosshair_dynamic", true)) else 0.0, 0.0)


func _clear_children(parent: Node) -> void:
	for child in parent.get_children():
		child.free()


func _fit_to_viewport(viewport_size_override := Vector2.ZERO) -> void:
	if pause_panel == null:
		return
	var viewport_size: Vector2 = viewport_size_override if viewport_size_override != Vector2.ZERO else get_viewport().get_visible_rect().size
	var compact := viewport_size.x < 760.0 or viewport_size.y < 540.0
	var horizontal_gutter := 48.0 if compact else 64.0
	var vertical_gutter := 36.0 if compact else 56.0
	var panel_width := minf(780.0, viewport_size.x - horizontal_gutter)
	var panel_height := minf(540.0, viewport_size.y - vertical_gutter)
	var shell_style := pause_panel.get_theme_stylebox("panel") as StyleBoxFlat
	if shell_style != null:
		shell_style.content_margin_left = 6.0 if compact else 22.0
		shell_style.content_margin_top = 6.0 if compact else 18.0
		shell_style.content_margin_right = 6.0 if compact else 22.0
		shell_style.content_margin_bottom = 6.0 if compact else 18.0
	var content := pause_panel.get_node("Content") as VBoxContainer
	content.add_theme_constant_override("separation", 3 if compact else 12)
	var header := pause_panel.get_node("Content/Header") as Control
	header.custom_minimum_size.y = 28.0 if compact else 46.0
	var title := pause_panel.get_node("Content/Header/BrandBlock/Title") as Label
	title.add_theme_font_size_override("font_size", 20 if compact else 26)
	var pages := pause_panel.get_node("Content/Pages") as Control
	pages.custom_minimum_size.y = 168.0 if compact else 300.0
	var match_stack := pause_panel.get_node("Content/Pages/MatchPage/Stack") as VBoxContainer
	match_stack.add_theme_constant_override("separation", 4 if compact else (8 if host_code_card.visible else 14))
	var match_kicker := pause_panel.get_node("Content/Pages/MatchPage/Stack/Kicker") as Label
	match_kicker.visible = not compact
	var match_title := pause_panel.get_node("Content/Pages/MatchPage/Stack/Title") as Label
	match_title.add_theme_font_size_override("font_size", 20 if compact else (28 if host_code_card.visible else 34))
	var ability_card := pause_panel.get_node("Content/Pages/MatchPage/Stack/AbilityCard") as PanelContainer
	ability_card.custom_minimum_size.y = 44.0 if compact else (58.0 if host_code_card.visible else 72.0)
	var ability_icon_control := pause_panel.get_node("Content/Pages/MatchPage/Stack/AbilityCard/Row/Icon") as TextureRect
	ability_icon_control.custom_minimum_size = Vector2(32, 32) if compact else Vector2(46, 46)
	host_code_card.custom_minimum_size.y = 44.0 if compact else 58.0
	host_code_value.add_theme_font_size_override("font_size", 16 if compact else 20)
	var host_code_hint := host_code_card.get_node("Row/Hint") as Label
	host_code_hint.visible = not compact
	var match_rule := pause_panel.get_node("Content/Pages/MatchPage/Stack/MatchRule") as Label
	match_rule.add_theme_font_size_override("font_size", 14 if compact else 17)
	var respawn_rule := pause_panel.get_node("Content/Pages/MatchPage/Stack/RespawnRule") as Label
	respawn_rule.visible = not compact
	respawn_rule.add_theme_font_size_override("font_size", 13 if host_code_card.visible else 15)
	for page_path in ["Content/Pages/MatchPage", "Content/Pages/SettingsPage", "Content/Pages/CrosshairPage"]:
		var page := pause_panel.get_node(page_path) as PanelContainer
		var page_style := page.get_theme_stylebox("panel") as StyleBoxFlat
		if page_style != null:
			page_style.content_margin_left = 6.0 if compact else 22.0
			page_style.content_margin_top = 6.0 if compact else 20.0
			page_style.content_margin_right = 6.0 if compact else 22.0
			page_style.content_margin_bottom = 6.0 if compact else 20.0
	for tab in [match_tab, settings_tab, crosshair_tab]:
		tab.custom_minimum_size = Vector2(96, 30) if compact else Vector2(138, 40)
	for action_path in ["Content/Actions/LobbyButton", "Content/Actions/RespawnButton", "Content/Actions/ResumeButton"]:
		var action := pause_panel.get_node(action_path) as Button
		action.custom_minimum_size.y = 32.0 if compact else 48.0
	pause_panel.offset_left = -panel_width * 0.5
	pause_panel.offset_right = panel_width * 0.5
	pause_panel.offset_top = -panel_height * 0.5
	pause_panel.offset_bottom = panel_height * 0.5
	var narrow := compact or panel_width < 760.0
	crosshair_preview_panel.visible = not narrow
	crosshair_preview_panel.custom_minimum_size.x = 230.0
	preview_crosshair.custom_minimum_size = Vector2(220, 220)
	var crosshair_layout := get_node_or_null("PausePanel/Content/Pages/CrosshairPage/Layout") as GridContainer
	if crosshair_layout != null:
		crosshair_layout.columns = 1 if narrow else 2


func _default_settings() -> Dictionary:
	return {
		"mouse_sensitivity": 0.0025,
		"master_volume": 0.85,
		"music_volume": 0.55,
		"sfx_volume": 0.8,
		"graphics_quality": 1,
		"effects_quality": 1,
		"render_scale_index": 1,
		"render_scale": 1.0,
		"fullscreen": false,
		"vsync": true,
		"shadow_quality": 2,
		"camera_shake": 0.72,
		"reduced_motion": false,
		"active_crosshair_slot": 1,
		"crosshair_length": 8.0,
		"crosshair_thickness": 1.5,
		"crosshair_gap": 5.0,
		"crosshair_dot": true,
		"crosshair_dot_size": 2.0,
		"crosshair_outline": true,
		"crosshair_outline_thickness": 1.0,
		"crosshair_color_index": 0,
		"crosshair_color_value": Color.WHITE,
		"crosshair_opacity": 1.0,
		"crosshair_dynamic": true,
		"crosshair_dynamic_amount": 5.0,
		"crosshair_rotation": 0.0,
	}


func _load_settings() -> Dictionary:
	var settings := _default_settings()
	var config := ConfigFile.new()
	if config.load(settings_path) != OK:
		return settings
	for key in settings:
		settings[key] = config.get_value("settings", key, settings[key])
	var active_slot := clampi(int(settings.get("active_crosshair_slot", 1)), 1, 3)
	for key in CROSSHAIR_KEYS:
		settings[key] = config.get_value("crosshair_slot_%d" % active_slot, key, settings[key])
	return _normalize_settings(settings)


func _normalize_settings(settings: Dictionary) -> Dictionary:
	var normalized := settings.duplicate(true)
	normalized["mouse_sensitivity"] = clampf(float(normalized.get("mouse_sensitivity", 0.0025)), 0.0008, 0.006)
	for key in ["master_volume", "music_volume", "sfx_volume", "camera_shake"]:
		normalized[key] = clampf(float(normalized.get(key, 0.0)), 0.0, 1.0)
	for key in ["graphics_quality", "effects_quality", "shadow_quality", "render_scale_index"]:
		normalized[key] = clampi(int(normalized.get(key, 1)), 0, 2)
	normalized["render_scale"] = [0.75, 1.0, 1.25][int(normalized["render_scale_index"])]
	normalized["active_crosshair_slot"] = clampi(int(normalized.get("active_crosshair_slot", 1)), 1, 3)
	normalized["crosshair_length"] = clampf(float(normalized.get("crosshair_length", 8.0)), 2.0, 18.0)
	normalized["crosshair_thickness"] = clampf(float(normalized.get("crosshair_thickness", 1.5)), 1.0, 5.0)
	normalized["crosshair_gap"] = clampf(float(normalized.get("crosshair_gap", 5.0)), 0.0, 16.0)
	normalized["crosshair_dot_size"] = clampf(float(normalized.get("crosshair_dot_size", 2.0)), 1.0, 6.0)
	normalized["crosshair_outline_thickness"] = clampf(float(normalized.get("crosshair_outline_thickness", 1.0)), 0.5, 3.0)
	normalized["crosshair_color_index"] = clampi(int(normalized.get("crosshair_color_index", 0)), 0, CROSSHAIR_COLORS.size() - 1)
	normalized["crosshair_color_value"] = CROSSHAIR_COLORS[int(normalized["crosshair_color_index"])]
	normalized["crosshair_opacity"] = clampf(float(normalized.get("crosshair_opacity", 1.0)), 0.2, 1.0)
	normalized["crosshair_dynamic_amount"] = clampf(float(normalized.get("crosshair_dynamic_amount", 5.0)), 0.0, 12.0)
	normalized["crosshair_rotation"] = clampf(float(normalized.get("crosshair_rotation", 0.0)), 0.0, 45.0)
	return normalized


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.load(settings_path)
	for key in _settings:
		config.set_value("settings", key, _settings[key])
	for key in CROSSHAIR_KEYS:
		config.set_value("crosshair_slot_%d" % _active_slot, key, _settings.get(key))
	config.save(settings_path)
