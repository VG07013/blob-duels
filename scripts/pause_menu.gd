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
const SESSION_CARD_TEXTURE := preload("res://assets/ui/art/pause-session-card.png")
const GUIDE_MOVEMENT_TEXTURE := preload("res://assets/ui/art/guide-movement.png")
const GUIDE_ATTACKS_TEXTURE := preload("res://assets/ui/art/guide-attacks.png")

@onready var match_page: Control = $PausePanel/Content/Pages/MatchPage
@onready var match_stack: VBoxContainer = $PausePanel/Content/Pages/MatchPage/Stack
@onready var settings_page: Control = $PausePanel/Content/Pages/SettingsPage
@onready var crosshair_page: Control = $PausePanel/Content/Pages/CrosshairPage
@onready var backdrop: ColorRect = $Backdrop
@onready var pause_panel: PanelContainer = $PausePanel
@onready var state_label: Label = $PausePanel/Content/Header/StatePill/State
@onready var match_tab: Button = $PausePanel/Content/Tabs/MatchTab
@onready var settings_tab: Button = $PausePanel/Content/Tabs/SettingsTab
@onready var crosshair_tab: Button = $PausePanel/Content/Tabs/CrosshairTab
@onready var crosshair_preview_panel: PanelContainer = $PausePanel/Content/Pages/CrosshairPage/Layout/Preview
@onready var preview_crosshair: Control = $PausePanel/Content/Pages/CrosshairPage/Layout/Preview/PreviewStack/Crosshair
@onready var settings_rows: VBoxContainer = $PausePanel/Content/Pages/SettingsPage/Scroll/Rows
@onready var crosshair_rows: VBoxContainer = $PausePanel/Content/Pages/CrosshairPage/Layout/Editor/RowsScroll/Rows

var _settings: Dictionary = {}
var _active_slot := 1
var _ui_font: SystemFont
var _active_page_index := -1
var _page_tween: Tween
@export var settings_path := SETTINGS_PATH


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_ui_font = SystemFont.new()
	_ui_font.font_names = PackedStringArray(["SF Pro Display", "Avenir Next", "Helvetica Neue", "Arial"])
	_settings = _load_settings()
	_active_slot = clampi(int(_settings.get("active_crosshair_slot", 1)), 1, 3)
	_connect_navigation()
	_install_match_art()
	_build_general_settings()
	_build_crosshair_settings()
	_apply_preview()
	get_viewport().size_changed.connect(_fit_to_viewport)
	_fit_to_viewport()


func _install_match_art() -> void:
	var session_card := _new_image_card(SESSION_CARD_TEXTURE, 0, "SessionArt", 156.0)
	match_stack.add_child(session_card)
	match_stack.move_child(session_card, 2)

	var guide_grid := GridContainer.new()
	guide_grid.name = "GuideCards"
	guide_grid.columns = 2
	guide_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	guide_grid.add_theme_constant_override("h_separation", 12)
	guide_grid.add_theme_constant_override("v_separation", 10)
	guide_grid.add_child(_new_guide_card(GUIDE_MOVEMENT_TEXTURE, "Move + bounce", "WASD to steer. Space gives your blob a quick lift."))
	guide_grid.add_child(_new_guide_card(GUIDE_ATTACKS_TEXTURE, "Fling + shoot", "Hold right click to charge. Left click fires while you aim."))
	match_stack.add_child(guide_grid)
	match_stack.move_child(guide_grid, 6)


func _new_image_card(texture: Texture2D, min_height: float, name_value: String, height: float) -> PanelContainer:
	var shell := PanelContainer.new()
	shell.name = name_value
	shell.custom_minimum_size = Vector2(0, maxf(min_height, height))
	shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.clip_contents = true
	shell.add_theme_stylebox_override("panel", _image_card_style())
	var image := TextureRect.new()
	image.texture = texture
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shell.add_child(image)
	return shell


func _new_guide_card(texture: Texture2D, title: String, body: String) -> PanelContainer:
	var shell := PanelContainer.new()
	shell.custom_minimum_size = Vector2(0, 118)
	shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.clip_contents = true
	shell.add_theme_stylebox_override("panel", _image_card_style())
	var stack := HBoxContainer.new()
	stack.add_theme_constant_override("separation", 12)
	shell.add_child(stack)
	var image := TextureRect.new()
	image.texture = texture
	image.custom_minimum_size = Vector2(138, 92)
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(image)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	copy.add_theme_constant_override("separation", 5)
	stack.add_child(copy)
	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_font_override("font", _ui_font)
	title_label.add_theme_font_size_override("font_size", 17)
	title_label.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0))
	copy.add_child(title_label)
	var body_label := Label.new()
	body_label.text = body
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.add_theme_font_override("font", _ui_font)
	body_label.add_theme_font_size_override("font_size", 13)
	body_label.add_theme_color_override("font_color", Color(0.68, 0.76, 0.84))
	copy.add_child(body_label)
	return shell


func _image_card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.055, 0.078, 0.96)
	style.border_color = Color(0.32, 0.42, 0.54, 0.46)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.content_margin_left = 12.0
	style.content_margin_top = 12.0
	style.content_margin_right = 12.0
	style.content_margin_bottom = 12.0
	return style


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
	backdrop.modulate.a = 0.0
	pause_panel.modulate.a = 0.0
	pause_panel.scale = Vector2(0.96, 0.96)
	pause_panel.pivot_offset = pause_panel.size * 0.5
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	tween.tween_property(backdrop, "modulate:a", 1.0, 0.16)
	tween.tween_property(pause_panel, "modulate:a", 1.0, 0.16)
	tween.tween_property(pause_panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_show_page(0)
	$PausePanel/Content/Actions/ResumeButton.grab_focus()


func set_context(is_duel: bool, is_practice: bool) -> void:
	var match_rule := $PausePanel/Content/Pages/MatchPage/Stack/MatchRule as Label
	var respawn_rule := $PausePanel/Content/Pages/MatchPage/Stack/RespawnRule as Label
	if is_duel:
		state_label.text = "DUEL PAUSED"
		match_rule.text = "RED VS BLUE  |  FIRST TO 5"
		respawn_rule.text = "Respawning during a duel awards the opposing team a point."
	elif is_practice:
		state_label.text = "PRACTICE PAUSED"
		match_rule.text = "PRACTICE"
		respawn_rule.text = "Respawn returns your blob to the practice spawn."
	else:
		state_label.text = "LOBBY PAUSED"
		match_rule.text = "LOBBY"
		respawn_rule.text = "Resume rolling or return to the lobby center."


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
	next_page.position.x = 18.0
	_page_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_page_tween.set_parallel(true)
	_page_tween.tween_property(next_page, "modulate:a", 1.0, 0.16)
	_page_tween.tween_property(next_page, "position:x", 0.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
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
	_add_section_header(settings_rows, "CONTROLS")
	_add_slider_row(settings_rows, "Mouse sensitivity", "mouse_sensitivity", 0.0008, 0.006, 0.0001, 1000.0)
	_add_slider_row(settings_rows, "Camera shake", "camera_shake", 0.0, 1.0, 0.05, 100.0)
	_add_section_header(settings_rows, "AUDIO")
	_add_slider_row(settings_rows, "Master volume", "master_volume", 0.0, 1.0, 0.05, 100.0)
	_add_slider_row(settings_rows, "Music volume", "music_volume", 0.0, 1.0, 0.05, 100.0)
	_add_slider_row(settings_rows, "Sound effects", "sfx_volume", 0.0, 1.0, 0.05, 100.0)
	_add_section_header(settings_rows, "VIDEO")
	_add_option_row(settings_rows, "Graphics quality", "graphics_quality", ["Low", "Balanced", "High"])
	_add_option_row(settings_rows, "Effects density", "effects_quality", ["Low", "Balanced", "High"])
	_add_option_row(settings_rows, "Shadow quality", "shadow_quality", ["Off", "Medium", "High"])
	_add_option_row(settings_rows, "Render scale", "render_scale_index", ["75%", "100%", "125%"])
	_add_toggle_row(settings_rows, "Fullscreen", "fullscreen")
	_add_toggle_row(settings_rows, "Vertical sync", "vsync")


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
	slider.custom_minimum_size = Vector2(220, 30)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value = float(_settings.get(key, minimum))
	row.add_child(slider)
	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(64, 30)
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
	var shell := PanelContainer.new()
	shell.custom_minimum_size = Vector2(0, 46)
	shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.add_theme_stylebox_override("panel", _row_style())
	parent.add_child(shell)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	shell.add_child(row)
	return row


func _add_section_header(parent: VBoxContainer, title: String) -> void:
	var label := Label.new()
	label.text = title
	label.custom_minimum_size = Vector2(0, 25)
	label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_font_override("font", _ui_font)
	label.add_theme_color_override("font_color", Color(0.34, 0.83, 0.86))
	parent.add_child(label)


func _setting_label(text_value: String) -> Label:
	var label := Label.new()
	label.text = text_value
	label.custom_minimum_size = Vector2(210, 30)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_font_override("font", _ui_font)
	label.add_theme_color_override("font_color", Color(0.84, 0.89, 0.95))
	return label


func _row_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.075, 0.09, 0.12, 0.76)
	style.border_color = Color(0.3, 0.36, 0.45, 0.25)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
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
	settings_applied.emit(get_settings())


func _select_crosshair_slot(slot: int) -> void:
	_save_current_crosshair_slot()
	_active_slot = clampi(slot, 1, 3)
	_settings["active_crosshair_slot"] = _active_slot
	_load_crosshair_slot(_active_slot)
	_build_crosshair_settings()
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


func _fit_to_viewport() -> void:
	if pause_panel == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var panel_width := minf(1180.0, viewport_size.x - 48.0)
	var panel_height := minf(760.0, viewport_size.y - 36.0)
	pause_panel.offset_left = -panel_width * 0.5
	pause_panel.offset_right = panel_width * 0.5
	pause_panel.offset_top = -panel_height * 0.5
	pause_panel.offset_bottom = panel_height * 0.5
	var compact := panel_width < 980.0
	crosshair_preview_panel.custom_minimum_size.x = 230.0 if compact else 310.0
	preview_crosshair.custom_minimum_size = Vector2(220, 220) if compact else Vector2(270, 270)
	var guide_cards := get_node_or_null("PausePanel/Content/Pages/MatchPage/Stack/GuideCards") as GridContainer
	if guide_cards != null:
		guide_cards.columns = 1 if compact else 2
	var crosshair_layout := get_node_or_null("PausePanel/Content/Pages/CrosshairPage/Layout") as GridContainer
	if crosshair_layout != null:
		crosshair_layout.columns = 1 if compact else 2


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
