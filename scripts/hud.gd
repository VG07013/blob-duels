extends CanvasLayer

const BLOB_AVATAR_SCRIPT := preload("res://scripts/blob_avatar.gd")
const COIN_ICON_SCRIPT := preload("res://scripts/ui/coin_icon.gd")
const SHOP_CARD_PREVIEW_SCRIPT := preload("res://scripts/shop_blob_preview.gd")
const SHOP_MODEL_PREVIEW_SCRIPT := preload("res://scripts/ui/shop_model_preview.gd")
const UI_TOKENS := preload("res://scripts/ui/ui_tokens.gd")

signal host_requested
signal join_requested(room_code: String)
signal practice_requested
signal identity_changed(display_name: String, color: Color)
signal settings_requested
signal return_to_lobby_requested

const BLOB_COLORS := [
	Color(0.02, 0.86, 1.0),
	Color(1.0, 0.28, 0.42),
	Color(1.0, 0.72, 0.12),
	Color(0.54, 0.34, 1.0),
	Color(0.34, 0.86, 0.3),
]
const COMPETITIVE_MAPS := [
	["neon_arcade", "Neon Arcade"],
	["backyard", "Backyard"],
	["arena", "Arena"],
	["sky_temple", "Aether Citadel"],
	["toybox", "Toybox"],
]

@onready var health_bar: ProgressBar = $HealthPanel/HealthBar
@onready var health_value: Label = $HealthPanel/HealthBar/HealthValue
@onready var health_panel: PanelContainer = $HealthPanel
@onready var crosshair: Control = $Crosshair
@onready var lobby_panel: PanelContainer = $LobbyPanel
@onready var lobby_stack: VBoxContainer = $LobbyPanel/LobbyStack
@onready var customize_button: Button = $LobbyPanel/LobbyStack/CustomizeButton
@onready var customize_menu: VBoxContainer = $LobbyPanel/LobbyStack/CustomizeMenu
@onready var name_input: LineEdit = $LobbyPanel/LobbyStack/CustomizeMenu/NameInput
@onready var play_button: Button = $LobbyPanel/LobbyStack/PlayButton
@onready var mode_chooser: VBoxContainer = $LobbyPanel/LobbyStack/ModeChooser
@onready var host_menu: VBoxContainer = $LobbyPanel/LobbyStack/HostMenu
@onready var join_menu: VBoxContainer = $LobbyPanel/LobbyStack/JoinMenu
@onready var code_input: LineEdit = $LobbyPanel/LobbyStack/JoinMenu/CodeInput
@onready var map_picker: OptionButton = $LobbyPanel/LobbyStack/HostMenu/MapRow/MapPicker
@onready var room_code: Label = $LobbyPanel/LobbyStack/HostMenu/RoomCode
@onready var host_button: Button = $LobbyPanel/LobbyStack/HostMenu/Actions/StartHost
@onready var join_button: Button = $LobbyPanel/LobbyStack/JoinMenu/Actions/StartJoin
@onready var practice_button: Button = $LobbyPanel/LobbyStack/ModeChooser/Choices/PracticeChoice
@onready var hit_marker: Control = $HitMarker
@onready var damage_flash: ColorRect = $DamageFlash
@onready var charge_panel: PanelContainer = $ChargePanel
@onready var charge_bar: ProgressBar = $ChargePanel/ChargeBar
@onready var charge_value: Label = $ChargePanel/ChargeBar/ChargeValue
@onready var fling_cooldown_panel: PanelContainer = $FlingCooldownPanel
@onready var fling_cooldown_bar: ProgressBar = $FlingCooldownPanel/FlingCooldownBar
@onready var fling_cooldown_value: Label = $FlingCooldownPanel/FlingCooldownBar/FlingCooldownValue
@onready var timer_label: Label = $TimerLabel
@onready var announcement: Label = $Announcement
@onready var scoreboard: HBoxContainer = $Scoreboard
@onready var red_score_panel: PanelContainer = $Scoreboard/RedScore
@onready var red_score_value: Label = $Scoreboard/RedScore/Value
@onready var blue_score_panel: PanelContainer = $Scoreboard/BlueScore
@onready var blue_score_value: Label = $Scoreboard/BlueScore/Value
@onready var score_target_label: Label = $Scoreboard/Target/Label
@onready var round_banner: PanelContainer = $RoundBanner
@onready var round_banner_label: Label = $RoundBanner/Label
@onready var victory_overlay: Control = $VictoryOverlay
@onready var result_banner: PanelContainer = $VictoryOverlay/ResultBanner
@onready var result_label: Label = $VictoryOverlay/ResultBanner/Stack/Label
@onready var result_detail: Label = $VictoryOverlay/ResultBanner/Stack/Detail
@onready var roster_panel: PanelContainer = $VictoryOverlay/RosterPanel
@onready var roster_players: VBoxContainer = $VictoryOverlay/RosterPanel/Stack/Players
@onready var stats_panel: PanelContainer = $VictoryOverlay/StatsPanel
@onready var stats_name: Label = $VictoryOverlay/StatsPanel/Stack/Top/Name
@onready var stats_eliminations: Label = $VictoryOverlay/StatsPanel/Stack/Eliminations
@onready var stats_deaths: Label = $VictoryOverlay/StatsPanel/Stack/Deaths
@onready var stats_ratio: Label = $VictoryOverlay/StatsPanel/Stack/Ratio

var player = null
var _shown_health := 150.0
var _fill_style := StyleBoxFlat.new()
var _charge_fill_style := StyleBoxFlat.new()
var _hit_marker_time := 0.0
var _damage_flash_time := 0.0
var _announcement_time := 0.0
var _announcement_tween: Tween
var _announcement_queue: Array[Dictionary] = []
var _last_observed_health := -1
var _duel_mode := false
var _practice_mode_active := false
var _lobby_mode_active := false
var _current_ability_id := ""
var _round_banner_style := StyleBoxFlat.new()
var _progression: Node
var _coin_balance_label: Label
var _coin_chip: PanelContainer
var _coin_icon: Control
var _shop_overlay: Control
var _shop_shell: PanelContainer
var _shop_content: VBoxContainer
var _quest_panel: PanelContainer
var _quest_reset_label: Label
var _progression_actions: HBoxContainer
var _reward_panel: PanelContainer
var _shown_coin_balance := 0.0
var _coin_target_balance := 0
var _active_progression_page := "shop"
var _active_shop_category := "abilities"
var _selected_shop_item: Dictionary = {}
var _quests_showing_weekly := false
var _quest_reset_accumulator := 0.0
var _selected_color_index := 0
var _color_swatches: HBoxContainer
var _connection_status: Label
var _lobby_page_tween: Tween
var _timer_pulse_tween: Tween
var _round_display_number := 1
var _last_red_score := 0
var _last_blue_score := 0
var _last_timer_second := -1
var _formatting_room_code := false
var _active_lobby_page := "play"
var _health_shell_style: StyleBoxFlat
var _reduced_motion := false
var _toast_stack: VBoxContainer
var _ui_font: SystemFont
@onready var _ability_panel: Control = $AbilityHUD


func _ready() -> void:
	_ui_font = SystemFont.new()
	_ui_font.font_names = PackedStringArray(["SF Pro Display", "Avenir Next", "Helvetica Neue", "Arial"])
	_fill_style.corner_radius_top_left = 8
	_fill_style.corner_radius_top_right = 8
	_fill_style.corner_radius_bottom_right = 8
	_fill_style.corner_radius_bottom_left = 8
	health_bar.add_theme_stylebox_override("fill", _fill_style)
	_health_shell_style = health_panel.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	health_panel.add_theme_stylebox_override("panel", _health_shell_style)
	_charge_fill_style.bg_color = Color(0.12, 0.78, 1.0, 1.0)
	_charge_fill_style.corner_radius_top_left = 6
	_charge_fill_style.corner_radius_top_right = 6
	_charge_fill_style.corner_radius_bottom_right = 6
	_charge_fill_style.corner_radius_bottom_left = 6
	charge_bar.add_theme_stylebox_override("fill", _charge_fill_style)
	announcement.add_theme_stylebox_override("normal", _announcement_style(Color(0.3, 0.9, 1.0)))
	timer_label.add_theme_stylebox_override("normal", _timer_style(Color(0.3, 0.82, 1.0, 0.8)))
	_round_banner_style.corner_radius_top_left = 8
	_round_banner_style.corner_radius_top_right = 8
	_round_banner_style.corner_radius_bottom_right = 8
	_round_banner_style.corner_radius_bottom_left = 8
	_round_banner_style.border_width_left = 2
	_round_banner_style.border_width_top = 2
	_round_banner_style.border_width_right = 2
	_round_banner_style.border_width_bottom = 2
	_round_banner_style.shadow_color = Color(0, 0, 0, 0.45)
	_round_banner_style.shadow_size = 16
	_round_banner_style.shadow_offset = Vector2(0, 7)
	round_banner.add_theme_stylebox_override("panel", _round_banner_style)
	_configure_map_picker()
	_configure_color_swatches()
	_create_connection_status()
	_create_room_code_copy_action()
	_decorate_secondary_lobby_flows()
	_style_lobby_actions()
	var mode_choices := $LobbyPanel/LobbyStack/ModeChooser/Choices as BoxContainer
	mode_choices.move_child(practice_button, 0)
	play_button.pressed.connect(_show_lobby_page.bind("chooser"))
	customize_button.pressed.connect(_show_lobby_page.bind("customize"))
	$LobbyPanel/LobbyStack/ModeChooser/Choices/HostChoice.pressed.connect(_show_lobby_page.bind("host"))
	$LobbyPanel/LobbyStack/ModeChooser/Choices/JoinChoice.pressed.connect(_show_lobby_page.bind("join"))
	$LobbyPanel/LobbyStack/ModeChooser/Close.pressed.connect(_show_lobby_page.bind("play"))
	$LobbyPanel/LobbyStack/CustomizeMenu/Close.pressed.connect(_show_lobby_page.bind("play"))
	$LobbyPanel/LobbyStack/CustomizeMenu/ShopButton.pressed.connect(func() -> void: _set_progression_open("shop"))
	$LobbyPanel/LobbyStack/HostMenu/Actions/Close.pressed.connect(_show_lobby_page.bind("chooser"))
	$LobbyPanel/LobbyStack/JoinMenu/Actions/Close.pressed.connect(_close_join_menu)
	host_button.pressed.connect(func() -> void: host_requested.emit())
	join_button.pressed.connect(func() -> void: join_requested.emit(code_input.text.strip_edges()))
	code_input.text_changed.connect(_format_room_code_input)
	code_input.text_submitted.connect(func(_submitted_text: String) -> void:
		if not join_button.disabled:
			join_requested.emit(code_input.text.strip_edges())
	)
	practice_button.pressed.connect(func() -> void: practice_requested.emit())
	name_input.text_changed.connect(func(_new_text: String) -> void: _emit_identity())
	$VictoryOverlay/StatsPanel/Stack/Top/Close.pressed.connect(_close_stats)
	_create_toast_stack()
	_setup_progression_ui()
	get_viewport().size_changed.connect(_fit_lobby_layout)
	_fit_lobby_layout()
	_show_lobby_page("play")
	_apply_ui_font_tree(self)


func _style_lobby_actions() -> void:
	var image_buttons: Array[Button] = [
		play_button,
		customize_button,
		$LobbyPanel/LobbyStack/ModeChooser/Choices/HostChoice,
		$LobbyPanel/LobbyStack/ModeChooser/Choices/JoinChoice,
		practice_button,
		$LobbyPanel/LobbyStack/CustomizeMenu/ShopButton,
	]
	for button in image_buttons:
		button.mouse_entered.connect(_animate_image_button.bind(button, true))
		button.mouse_exited.connect(_animate_image_button.bind(button, false))
		button.button_down.connect(_press_image_button.bind(button, true))
		button.button_up.connect(_press_image_button.bind(button, false))


func _press_image_button(button: Button, pressed: bool) -> void:
	button.pivot_offset = button.size * 0.5
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(button, "scale", Vector2(0.975, 0.975) if pressed else Vector2.ONE, 0.09)


func _animate_image_button(button: Button, hovered: bool) -> void:
	button.pivot_offset = button.size * 0.5
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	tween.tween_property(button, "scale", Vector2(1.018, 1.018) if hovered else Vector2.ONE, 0.12)
	tween.tween_property(button, "modulate", Color(1.08, 1.08, 1.08, 1.0) if hovered else Color.WHITE, 0.12)


func set_ability_state(ability_id: String, cooldown_remaining_msec: int, loaded: bool, active: bool, active_remaining_msec: int = 0, deployed: bool = false) -> void:
	if _ability_panel == null:
		return
	_current_ability_id = ability_id
	_ability_panel.call("set_ability_state", ability_id, cooldown_remaining_msec, loaded, active, active_remaining_msec, deployed)
	_ability_panel.visible = not lobby_panel.visible and not ability_id.is_empty()


func _show_lobby_page(page: String) -> void:
	_active_lobby_page = page
	var panel_height: float = {
		"play": 200.0,
		"chooser": 300.0,
		"customize": 286.0,
		"host": 286.0,
		"join": 220.0,
	}.get(page, 176.0)
	play_button.visible = page == "play"
	customize_button.visible = page == "play"
	if _progression_actions != null:
		_progression_actions.visible = page == "play"
	mode_chooser.visible = page == "chooser"
	customize_menu.visible = page == "customize"
	host_menu.visible = page == "host"
	join_menu.visible = page == "join"
	if _connection_status != null:
		_connection_status.visible = page in ["host", "join"] and _has_actionable_connection_status(_connection_status.text)
	if _lobby_page_tween != null and _lobby_page_tween.is_valid():
		_lobby_page_tween.kill()
	var target_top := lobby_panel.offset_bottom - panel_height
	_lobby_page_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	var duration := 0.01 if _reduced_motion else 0.18
	_lobby_page_tween.tween_property(lobby_panel, "offset_top", target_top, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if page == "host":
		_refresh_room_code()


func _fit_lobby_layout() -> void:
	if lobby_panel == null:
		return
	var viewport_width := get_viewport().get_visible_rect().size.x
	var panel_width := minf(460.0, viewport_width - 32.0)
	lobby_panel.offset_left = -panel_width * 0.5
	lobby_panel.offset_right = panel_width * 0.5
	_fit_progression_drawer()


func apply_ui_settings(settings: Dictionary) -> void:
	_reduced_motion = bool(settings.get("reduced_motion", false))


func open_play_menu() -> void:
	if _shop_overlay != null:
		_shop_overlay.visible = false
	_show_lobby_page("chooser")


func _close_join_menu() -> void:
	var network_session := get_node_or_null("/root/NetworkSession")
	if network_session != null and network_session.has_method("is_joining") and bool(network_session.call("is_joining")):
		network_session.call("close_session")
	set_join_status("Choose Host, Join, or Practice", false)
	_show_lobby_page("chooser")


func bind_player(new_player) -> void:
	player = new_player


func set_lobby_mode(is_lobby: bool) -> void:
	_lobby_mode_active = is_lobby
	lobby_panel.visible = is_lobby
	health_panel.visible = not is_lobby
	if _ability_panel != null:
		_ability_panel.visible = not is_lobby and not _current_ability_id.is_empty()
	crosshair.visible = not is_lobby
	charge_panel.visible = not is_lobby
	timer_label.visible = not is_lobby and not _practice_mode_active
	scoreboard.visible = not is_lobby and _duel_mode and not _practice_mode_active
	if is_lobby:
		fling_cooldown_panel.visible = false
	if _coin_chip != null:
		_coin_chip.visible = is_lobby
	if _quest_panel != null:
		_quest_panel.visible = is_lobby
	if not is_lobby and _shop_overlay != null:
		_shop_overlay.visible = false
	if is_lobby:
		_show_lobby_page("play")
		announcement.visible = false
		round_banner.visible = false
		hide_victory()


func set_lobby_ui_suppressed(suppressed: bool) -> void:
	if not _lobby_mode_active:
		return
	lobby_panel.visible = not suppressed
	if _coin_chip != null:
		_coin_chip.visible = not suppressed
	if _quest_panel != null:
		_quest_panel.visible = not suppressed
	if suppressed and _shop_overlay != null:
		_shop_overlay.visible = false


func is_progression_open() -> bool:
	return _shop_overlay != null and _shop_overlay.visible


func close_progression() -> void:
	_set_shop_open(false)


func begin_victory_cinematic() -> void:
	health_panel.visible = false
	if _ability_panel != null:
		_ability_panel.visible = false
	crosshair.visible = false
	charge_panel.visible = false
	fling_cooldown_panel.visible = false
	timer_label.visible = false
	scoreboard.visible = false
	round_banner.visible = false


func set_duel_mode(enabled: bool) -> void:
	_duel_mode = enabled
	scoreboard.visible = enabled and not lobby_panel.visible and not _practice_mode_active
	timer_label.visible = not lobby_panel.visible and not _practice_mode_active


func set_practice_mode(enabled: bool) -> void:
	_practice_mode_active = enabled
	timer_label.visible = not enabled and not lobby_panel.visible
	scoreboard.visible = not enabled and _duel_mode and not lobby_panel.visible
	if enabled:
		fling_cooldown_panel.visible = false


func set_fling_cooldown(remaining_seconds: float, duration_seconds: float = 3.0) -> void:
	var safe_duration := maxf(duration_seconds, 0.001)
	var safe_remaining := clampf(remaining_seconds, 0.0, safe_duration)
	fling_cooldown_bar.value = safe_remaining / safe_duration * 100.0
	fling_cooldown_value.text = "FLING COOLDOWN  %.1fs" % safe_remaining
	fling_cooldown_panel.visible = safe_remaining > 0.001 and not lobby_panel.visible


func set_duel_score(red_score: int, blue_score: int, scoring_team := -1) -> void:
	_last_red_score = red_score
	_last_blue_score = blue_score
	red_score_value.text = "RED  %d" % red_score
	blue_score_value.text = "%d  BLUE" % blue_score
	score_target_label.text = "ROUND %d\nFIRST TO 5" % _round_display_number
	if scoring_team == 0:
		_pulse_score_panel(red_score_panel)
	elif scoring_team == 1:
		_pulse_score_panel(blue_score_panel)


func set_round_number(round_number: int) -> void:
	_round_display_number = maxi(1, round_number)
	score_target_label.text = "ROUND %d\nFIRST TO 5" % _round_display_number


func _score_pips(score: int) -> String:
	return "▰".repeat(clampi(score, 0, 5)) + "▱".repeat(5 - clampi(score, 0, 5))


func show_round_banner(message: String, color: Color) -> void:
	_round_banner_style.bg_color = Color(color.r * 0.76, color.g * 0.76, color.b * 0.76, 0.97)
	_round_banner_style.border_color = color.lightened(0.32)
	_round_banner_style.shadow_color = Color(color.r, color.g, color.b, 0.38)
	round_banner_label.text = message
	round_banner.visible = true
	round_banner.modulate = Color(1, 1, 1, 0)
	round_banner.scale = Vector2.ONE if _reduced_motion else Vector2(0.86, 0.86)
	round_banner.pivot_offset = round_banner.size * 0.5
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	tween.tween_property(round_banner, "modulate:a", 1.0, 0.06 if _reduced_motion else 0.18)
	if not _reduced_motion:
		tween.tween_property(round_banner, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.set_parallel(false)
	tween.tween_interval(1.45)
	tween.tween_property(round_banner, "modulate:a", 0.0, 0.28)
	tween.tween_callback(func() -> void: round_banner.visible = false)


func _pulse_score_panel(panel: Control) -> void:
	panel.pivot_offset = panel.size * 0.5
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(panel, "scale", Vector2(1.16, 1.16), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func set_join_status(message: String, loading: bool) -> void:
	host_button.disabled = loading
	join_button.disabled = loading
	practice_button.disabled = loading
	name_input.editable = not loading
	code_input.editable = not loading
	map_picker.disabled = loading
	host_button.tooltip_text = message
	join_button.tooltip_text = message
	if _connection_status != null:
		_connection_status.text = message
		_connection_status.add_theme_color_override("font_color", Color(0.44, 0.9, 1.0) if loading else (Color(1.0, 0.48, 0.5) if _is_error_status(message) else Color(0.66, 0.78, 0.92)))
		_connection_status.visible = _active_lobby_page in ["host", "join"] and (loading or _has_actionable_connection_status(message))
	if loading:
		host_button.text = "STARTING..." if host_menu.visible else "START HOSTING"
		join_button.text = "CONNECTING..." if join_menu.visible else "JOIN GAME"
	else:
		host_button.text = "START HOSTING"
		join_button.text = "JOIN GAME"
		var lower_message := message.to_lower()
		if host_menu.visible and ("failed" in lower_message or "could not" in lower_message or "not valid" in lower_message):
			host_button.text = "HOST FAILED — TRY AGAIN"
		elif "join failed" in lower_message or "could not" in lower_message or "not valid" in lower_message:
			join_button.text = "INVALID CODE — TRY AGAIN" if "valid" in lower_message else "JOIN FAILED — TRY AGAIN"


func get_player_name() -> String:
	var clean_name := name_input.text.strip_edges()
	return clean_name if not clean_name.is_empty() else "Player"


func get_player_color() -> Color:
	return BLOB_COLORS[clampi(_selected_color_index, 0, BLOB_COLORS.size() - 1)]


func _configure_color_swatches() -> void:
	_color_swatches = HBoxContainer.new()
	_color_swatches.name = "ColorSwatches"
	_color_swatches.custom_minimum_size = Vector2(0, 50)
	_color_swatches.alignment = BoxContainer.ALIGNMENT_CENTER
	_color_swatches.add_theme_constant_override("separation", 10)
	customize_menu.add_child(_color_swatches)
	customize_menu.move_child(_color_swatches, 1)
	for index in BLOB_COLORS.size():
		var swatch := Button.new()
		swatch.name = "Color%d" % index
		swatch.custom_minimum_size = Vector2(44, 44)
		swatch.tooltip_text = "Use blob color %d" % (index + 1)
		swatch.focus_mode = Control.FOCUS_NONE
		swatch.add_theme_stylebox_override("normal", _color_swatch_style(BLOB_COLORS[index], index == _selected_color_index))
		swatch.add_theme_stylebox_override("hover", _color_swatch_style(BLOB_COLORS[index].lightened(0.12), true))
		swatch.pressed.connect(_select_player_color.bind(index))
		_color_swatches.add_child(swatch)


func _select_player_color(index: int) -> void:
	_selected_color_index = clampi(index, 0, BLOB_COLORS.size() - 1)
	for child_index in _color_swatches.get_child_count():
		var swatch := _color_swatches.get_child(child_index) as Button
		if swatch != null:
			swatch.add_theme_stylebox_override("normal", _color_swatch_style(BLOB_COLORS[child_index], child_index == _selected_color_index))
	_emit_identity()


func _color_swatch_style(color: Color, selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color.WHITE if selected else color.darkened(0.45)
	style.set_border_width_all(3 if selected else 1)
	style.set_corner_radius_all(22)
	style.shadow_color = Color(color.r, color.g, color.b, 0.42) if selected else Color.TRANSPARENT
	style.shadow_size = 9 if selected else 0
	return style


func _create_connection_status() -> void:
	_connection_status = Label.new()
	_connection_status.name = "ConnectionStatus"
	_connection_status.text = "Choose how you want to play"
	_connection_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_connection_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_connection_status.add_theme_font_size_override("font_size", 13)
	_connection_status.add_theme_color_override("font_color", Color(0.66, 0.78, 0.92))
	_connection_status.visible = false
	lobby_stack.add_child(_connection_status)
	lobby_stack.move_child(_connection_status, 2)


func _decorate_secondary_lobby_flows() -> void:
	_add_flow_context(mode_chooser, "CHOOSE YOUR ARENA", "Practice instantly, host a room, or join a friend with their code.")
	_add_flow_context(customize_menu, "CUSTOMIZE BLOB", "Your display name and loadout follow you into every duel.")
	_add_flow_context(host_menu, "HOST A DUEL", "Choose the arena, then share the LAN code with your rival.")
	_add_flow_context(join_menu, "JOIN WITH CODE", "Enter the host's room code to connect directly.")


func _add_flow_context(menu: VBoxContainer, title_text: String, detail_text: String) -> void:
	var context := VBoxContainer.new()
	context.name = "FlowContext"
	context.add_theme_constant_override("separation", 1)
	menu.add_child(context)
	menu.move_child(context, 0)
	var title := Label.new()
	title.name = "FlowTitle"
	title.text = title_text
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.93, 0.97, 1.0))
	context.add_child(title)
	var detail := Label.new()
	detail.name = "FlowDetail"
	detail.text = detail_text
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_theme_font_size_override("font_size", 12)
	detail.add_theme_color_override("font_color", Color(0.58, 0.69, 0.82))
	context.add_child(detail)


func _is_error_status(message: String) -> bool:
	var lower := message.to_lower()
	return "failed" in lower or "could not" in lower or "not valid" in lower or "disconnected" in lower


func _has_actionable_connection_status(message: String) -> bool:
	var lower := message.strip_edges().to_lower()
	return not lower.is_empty() and lower not in ["choose host, join, or practice", "choose how you want to play"]


func get_host_address() -> String:
	return code_input.text.strip_edges()


func _refresh_room_code() -> void:
	var network_session := get_node_or_null("/root/NetworkSession")
	var code := "LOCAL"
	if network_session != null and network_session.has_method("get_host_room_code"):
		code = str(network_session.call("get_host_room_code"))
	room_code.text = "LAN CODE  %s" % code


func _create_room_code_copy_action() -> void:
	var copy_button := Button.new()
	copy_button.name = "CopyButton"
	copy_button.text = "COPY LAN CODE"
	copy_button.custom_minimum_size = Vector2(0, 42)
	copy_button.focus_mode = Control.FOCUS_NONE
	copy_button.tooltip_text = "Copy the LAN code to the clipboard"
	_apply_utility_button_style(copy_button, UI_TOKENS.COLOR_CYAN)
	copy_button.pressed.connect(_copy_room_code)
	host_menu.add_child(copy_button)
	host_menu.move_child(copy_button, host_menu.get_child_count() - 2)


func _copy_room_code() -> void:
	var code := room_code.text.trim_prefix("LAN CODE").strip_edges()
	DisplayServer.clipboard_set(code)
	set_join_status("LAN code copied — send it to a player on your network", false)


func _format_room_code_input(value: String) -> void:
	if _formatting_room_code:
		return
	var stripped := value.strip_edges()
	if "." in stripped:
		return
	var compact := ""
	for character in stripped.to_upper():
		if character in "0123456789ABCDEF":
			compact += character
			if compact.length() >= 8:
				break
	var formatted := compact
	if compact.length() > 4:
		formatted = compact.left(4) + "-" + compact.substr(4)
	if formatted == value:
		return
	_formatting_room_code = true
	code_input.text = formatted
	code_input.caret_column = formatted.length()
	_formatting_room_code = false


func get_selected_map_id() -> String:
	if map_picker.selected < 0:
		return "neon_arcade"
	return str(map_picker.get_item_metadata(map_picker.selected))


func show_hit_marker() -> void:
	_hit_marker_time = 0.18
	hit_marker.visible = true
	hit_marker.pivot_offset = hit_marker.size * 0.5
	hit_marker.scale = Vector2(0.62, 0.62)
	if crosshair.has_method("flash_hit_confirm"):
		crosshair.call("flash_hit_confirm")
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(hit_marker, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func show_damage_feedback() -> void:
	_damage_flash_time = 0.28
	damage_flash.visible = true
	health_panel.pivot_offset = health_panel.size * 0.5
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(health_panel, "scale", Vector2(1.055, 1.055), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(health_panel, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func show_announcement(message: String, color: Color = Color.WHITE) -> void:
	if _announcement_time > 0.12 and announcement.visible:
		if _announcement_queue.size() < 3:
			_announcement_queue.append({"message": message, "color": color})
		return
	_show_announcement_now(message, color)


func _show_announcement_now(message: String, color: Color) -> void:
	if _announcement_tween != null and _announcement_tween.is_valid():
		_announcement_tween.kill()
	announcement.text = message
	announcement.add_theme_stylebox_override("normal", _announcement_style(color))
	announcement.modulate = Color(color.r, color.g, color.b, 0.0)
	announcement.visible = true
	announcement.pivot_offset = announcement.size * 0.5
	announcement.scale = Vector2(0.88, 0.88)
	_announcement_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_announcement_tween.set_parallel(true)
	_announcement_tween.tween_property(announcement, "modulate:a", 1.0, 0.14)
	_announcement_tween.tween_property(announcement, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_announcement_time = 1.5


func set_match_time(seconds_remaining: float) -> void:
	var whole_seconds := maxi(0, int(ceil(seconds_remaining)))
	timer_label.text = "%02d:%02d" % [whole_seconds / 60, whole_seconds % 60]
	var urgent := whole_seconds <= 30
	var timer_color := Color(1.0, 0.34, 0.3) if urgent else Color(0.94, 0.98, 1.0)
	timer_label.add_theme_color_override("font_color", timer_color)
	timer_label.add_theme_stylebox_override("normal", _timer_style(Color(timer_color.r, timer_color.g, timer_color.b, 0.78)))
	if urgent and whole_seconds != _last_timer_second and whole_seconds % 5 == 0:
		_pulse_match_timer()
	_last_timer_second = whole_seconds


func _pulse_match_timer() -> void:
	if _timer_pulse_tween != null and _timer_pulse_tween.is_valid():
		_timer_pulse_tween.kill()
	timer_label.pivot_offset = timer_label.size * 0.5
	_timer_pulse_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_timer_pulse_tween.tween_property(timer_label, "scale", Vector2(1.16, 1.16), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_timer_pulse_tween.tween_property(timer_label, "scale", Vector2.ONE, 0.18)


func apply_crosshair_settings(settings: Dictionary) -> void:
	if crosshair.has_method("apply_settings"):
		crosshair.call("apply_settings", settings)


func show_victory(is_winner: bool, winning_team: int, players: Array) -> void:
	var team_color := Color(0.94, 0.12, 0.18) if winning_team == 0 else Color(0.06, 0.42, 0.96)
	var result_word := "VICTORY" if is_winner else "DEFEAT"
	result_label.text = result_word
	result_detail.text = "RED %d  —  %d BLUE    ·    MATCH COMPLETE" % [_last_red_score, _last_blue_score]
	result_label.add_theme_color_override("font_color", Color.WHITE if is_winner else Color(0.9, 0.93, 0.98))
	var result_style := result_banner.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	result_style.bg_color = Color(0.018, 0.027, 0.045, 0.9)
	result_style.border_color = Color(team_color.r, team_color.g, team_color.b, 0.78) if is_winner else Color(0.38, 0.44, 0.52)
	result_style.shadow_color = Color(team_color.r, team_color.g, team_color.b, 0.16)
	result_style.shadow_size = 12
	result_style.content_margin_left = UI_TOKENS.SPACE_LG
	result_style.content_margin_top = UI_TOKENS.SPACE_LG
	result_style.content_margin_right = UI_TOKENS.SPACE_LG
	result_style.content_margin_bottom = UI_TOKENS.SPACE_LG
	result_banner.add_theme_stylebox_override("panel", result_style)
	victory_overlay.visible = true
	victory_overlay.modulate.a = 0.0
	result_banner.scale = Vector2.ONE if _reduced_motion else Vector2(0.82, 0.82)
	result_banner.pivot_offset = result_banner.size * 0.5
	roster_panel.visible = false
	stats_panel.visible = false
	_build_roster(players)
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	var enter_time := 0.08 if _reduced_motion else 0.3
	tween.tween_property(victory_overlay, "modulate:a", 1.0, enter_time)
	if not _reduced_motion:
		tween.tween_property(result_banner, "scale", Vector2.ONE, 0.36).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.set_parallel(false)
	tween.tween_interval(0.2 if _reduced_motion else 0.72)
	tween.tween_callback(_reveal_roster)
	if _reward_panel != null:
		_reward_panel.visible = false


func hide_victory() -> void:
	victory_overlay.visible = false
	roster_panel.visible = false
	stats_panel.visible = false
	if _reward_panel != null:
		_reward_panel.visible = false


func show_match_rewards(reward: Dictionary) -> void:
	if _reward_panel == null:
		return
	var header := _reward_panel.get_node("Stack/Header") as Label
	header.text = "MATCH REWARDS"
	for child in _reward_panel.get_node("Stack/Rows").get_children():
		child.queue_free()
	var rows := _reward_panel.get_node("Stack/Rows") as VBoxContainer
	var breakdown := reward.get("breakdown", []) as Array
	for index in breakdown.size():
		var entry := breakdown[index] as Dictionary
		var row := HBoxContainer.new()
		var row_label := Label.new()
		row_label.text = str(entry.get("label", "Reward"))
		row_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row_label.add_theme_font_size_override("font_size", 16)
		row_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
		row.add_child(row_label)
		var amount_label := Label.new()
		amount_label.text = "+%d" % int(entry.get("amount", 0))
		amount_label.add_theme_font_size_override("font_size", 16)
		amount_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.25))
		row.add_child(amount_label)
		row.modulate.a = 0.0
		rows.add_child(row)
		var reveal := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		reveal.tween_interval(0.35 + index * 0.24)
		reveal.tween_property(row, "modulate:a", 1.0, 0.18)
	var total := HBoxContainer.new()
	var total_amount := int(reward.get("total", 0))
	var total_title := Label.new()
	total_title.text = "TOTAL"
	total_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	total_title.add_theme_font_size_override("font_size", 20)
	total.add_child(total_title)
	var total_coin := Control.new()
	total_coin.name = "RewardCoinMark"
	total_coin.custom_minimum_size = Vector2(24, 24)
	total_coin.set_script(COIN_ICON_SCRIPT)
	total_coin.call("set_accent", Color(1.0, 0.79, 0.2))
	total.add_child(total_coin)
	var total_value := Label.new()
	total_value.text = "+0 COINS"
	total_value.add_theme_font_size_override("font_size", 20)
	total_value.add_theme_color_override("font_color", Color(1.0, 0.79, 0.2))
	total.add_child(total_value)
	total.modulate.a = 0.0
	rows.add_child(total)
	var total_tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	total_tween.tween_interval(0.65 + breakdown.size() * 0.24)
	total_tween.tween_property(total, "modulate:a", 1.0, 0.14)
	total_tween.tween_method(func(value: float) -> void: total_value.text = "+%d COINS" % int(round(value)), 0.0, float(total_amount), 0.58).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_reward_panel.visible = true
	_reward_panel.modulate.a = 0.0
	var panel_tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	panel_tween.tween_interval(0.72)
	panel_tween.tween_property(_reward_panel, "modulate:a", 1.0, 0.24)
	_apply_ui_font_tree(_reward_panel)


func _setup_progression_ui() -> void:
	_progression = get_node_or_null("/root/Progression")
	if _progression == null:
		return
	_coin_target_balance = int(_progression.call("get_balance"))
	_shown_coin_balance = _coin_target_balance
	_progression.balance_changed.connect(_on_coin_balance_changed)
	_progression.quest_completed.connect(_on_quest_completed)
	_progression.inventory_changed.connect(_refresh_shop_if_open)
	_create_coin_chip()
	_create_quest_panel()
	_create_lobby_progression_actions()
	_create_shop_overlay()
	_create_reward_panel()


func _create_coin_chip() -> void:
	_coin_chip = PanelContainer.new()
	_coin_chip.name = "CoinBalance"
	_coin_chip.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_coin_chip.position = Vector2(-150, 22)
	_coin_chip.size = Vector2(126, 50)
	_coin_chip.add_theme_stylebox_override("panel", _glass_panel_style(UI_TOKENS.COLOR_GOLD, UI_TOKENS.RADIUS_LG, 0.72))
	add_child(_coin_chip)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", UI_TOKENS.SPACE_SM)
	_coin_chip.add_child(row)
	_coin_icon = Control.new()
	_coin_icon.name = "CoinMark"
	_coin_icon.custom_minimum_size = Vector2(30, 30)
	_coin_icon.set_script(COIN_ICON_SCRIPT)
	row.add_child(_coin_icon)
	_coin_balance_label = Label.new()
	_coin_balance_label.name = "CoinValue"
	_coin_balance_label.add_theme_font_size_override("font_size", 23)
	_coin_balance_label.add_theme_color_override("font_color", UI_TOKENS.COLOR_TEXT)
	row.add_child(_coin_balance_label)
	var open_shop := Button.new()
	open_shop.name = "OpenShop"
	open_shop.set_anchors_preset(Control.PRESET_FULL_RECT)
	open_shop.flat = true
	open_shop.focus_mode = Control.FOCUS_NONE
	open_shop.tooltip_text = "Open the Blob Shop"
	open_shop.pressed.connect(_set_progression_open.bind("shop"))
	_coin_chip.add_child(open_shop)
	_update_coin_label()


func _create_lobby_progression_actions() -> void:
	_progression_actions = HBoxContainer.new()
	_progression_actions.name = "ProgressionActions"
	_progression_actions.custom_minimum_size = Vector2(0, 42)
	_progression_actions.add_theme_constant_override("separation", UI_TOKENS.SPACE_SM)
	var quests_button := Button.new()
	quests_button.name = "DockQuestsButton"
	quests_button.text = "QUESTS"
	quests_button.tooltip_text = "Track daily and weekly rewards"
	quests_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quests_button.focus_mode = Control.FOCUS_NONE
	quests_button.add_theme_font_size_override("font_size", 13)
	_apply_utility_button_style(quests_button, Color(0.42, 0.86, 0.62))
	quests_button.pressed.connect(func() -> void: _set_progression_open("quests"))
	_progression_actions.add_child(quests_button)
	var settings_button := Button.new()
	settings_button.name = "SettingsButton"
	settings_button.text = "SETTINGS"
	settings_button.tooltip_text = "Open game settings"
	settings_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_button.focus_mode = Control.FOCUS_NONE
	settings_button.add_theme_font_size_override("font_size", 13)
	_apply_utility_button_style(settings_button, Color(0.68, 0.72, 0.82))
	settings_button.pressed.connect(func() -> void: settings_requested.emit())
	_progression_actions.add_child(settings_button)
	lobby_stack.add_child(_progression_actions)
	lobby_stack.move_child(_progression_actions, 2)


func _create_quest_panel() -> void:
	_quest_panel = PanelContainer.new()
	_quest_panel.name = "QuestPanel"
	_quest_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_quest_panel.position = Vector2(24, 92)
	_quest_panel.size = Vector2(286, 160)
	_quest_panel.add_theme_stylebox_override("panel", _glass_panel_style(UI_TOKENS.COLOR_CYAN, UI_TOKENS.RADIUS_LG, 0.54))
	add_child(_quest_panel)
	_refresh_quest_panel()


func _refresh_quest_panel() -> void:
	if _quest_panel == null or _progression == null:
		return
	for child in _quest_panel.get_children():
		child.queue_free()
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", UI_TOKENS.SPACE_SM)
	_quest_panel.add_child(stack)
	var header := HBoxContainer.new()
	stack.add_child(header)
	var title := Label.new()
	title.text = "TODAY"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", Color(0.74, 0.9, 1.0))
	header.add_child(title)
	_quest_reset_label = Label.new()
	_quest_reset_label.add_theme_font_size_override("font_size", 10)
	_quest_reset_label.add_theme_color_override("font_color", Color(0.58, 0.66, 0.76))
	header.add_child(_quest_reset_label)
	_update_quest_reset_label()
	var completed_count := 0
	for quest_value in _progression.get("daily_quests") as Array:
		var quest := quest_value as Dictionary
		if bool(quest.get("claimed", false)):
			completed_count += 1
	title.text = "TODAY  ·  %d / 3 COMPLETE" % completed_count
	var featured: Dictionary = {}
	for quest_value in _progression.get("daily_quests") as Array:
		var candidate := quest_value as Dictionary
		if not bool(candidate.get("claimed", false)):
			featured = candidate
			break
	if featured.is_empty() and not (_progression.get("daily_quests") as Array).is_empty():
		featured = (_progression.get("daily_quests") as Array)[0]
	var row := HBoxContainer.new()
	stack.add_child(row)
	var objective := Label.new()
	objective.text = str(featured.get("title", "All daily quests complete"))
	objective.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	objective.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	objective.add_theme_font_size_override("font_size", 15)
	objective.add_theme_color_override("font_color", UI_TOKENS.COLOR_TEXT)
	row.add_child(objective)
	var reward := Label.new()
	reward.text = "+%d" % int(featured.get("reward", 0))
	reward.add_theme_font_size_override("font_size", 11)
	reward.add_theme_color_override("font_color", UI_TOKENS.COLOR_GOLD)
	row.add_child(reward)
	var progress := ProgressBar.new()
	progress.custom_minimum_size = Vector2(0, 6)
	progress.show_percentage = false
	progress.max_value = maxi(1, int(featured.get("target", 1)))
	progress.value = mini(int(progress.max_value), int(featured.get("progress", 0)))
	progress.add_theme_stylebox_override("background", _progress_style(Color(0.025, 0.035, 0.07), Color(0.12, 0.2, 0.34)))
	progress.add_theme_stylebox_override("fill", _progress_style(UI_TOKENS.COLOR_MINT, Color.TRANSPARENT))
	stack.add_child(progress)
	var view_all := Button.new()
	view_all.text = "VIEW ALL  →"
	view_all.custom_minimum_size = Vector2(0, 28)
	view_all.focus_mode = Control.FOCUS_NONE
	view_all.add_theme_font_size_override("font_size", 11)
	_apply_utility_button_style(view_all, Color(0.3, 0.72, 1.0))
	view_all.pressed.connect(_set_progression_open.bind("quests"))
	stack.add_child(view_all)


func _create_shop_overlay() -> void:
	_shop_overlay = Control.new()
	_shop_overlay.name = "ShopOverlay"
	_shop_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shop_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_shop_overlay.visible = false
	add_child(_shop_overlay)
	var shade := ColorRect.new()
	shade.name = "DrawerBackdrop"
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.004, 0.008, 0.018, 0.82)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.gui_input.connect(_on_progression_backdrop_input)
	_shop_overlay.add_child(shade)
	_shop_shell = PanelContainer.new()
	_shop_shell.name = "ProgressionDrawer"
	_shop_shell.set_anchors_preset(Control.PRESET_CENTER)
	var shell_style := _elevated_panel_style(Color(0.015, 0.023, 0.047, 0.985), Color(0.32, 0.62, 1.0, 0.86), 22, Color(0.0, 0.0, 0.0, 0.66))
	shell_style.content_margin_left = 24
	shell_style.content_margin_top = 18
	shell_style.content_margin_right = 24
	shell_style.content_margin_bottom = 22
	_shop_shell.add_theme_stylebox_override("panel", shell_style)
	_shop_overlay.add_child(_shop_shell)
	_shop_content = VBoxContainer.new()
	_shop_content.add_theme_constant_override("separation", 14)
	_shop_shell.add_child(_shop_content)
	_fit_progression_drawer()


func _fit_progression_drawer() -> void:
	if _shop_shell == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var drawer_size := Vector2(
		minf(1180.0, viewport_size.x - 40.0),
		minf(680.0, viewport_size.y - 32.0)
	)
	drawer_size.x = maxf(drawer_size.x, minf(360.0, viewport_size.x - 18.0))
	drawer_size.y = maxf(drawer_size.y, minf(520.0, viewport_size.y - 18.0))
	_shop_shell.anchor_left = 0.5
	_shop_shell.anchor_top = 0.5
	_shop_shell.anchor_right = 0.5
	_shop_shell.anchor_bottom = 0.5
	_shop_shell.offset_left = -drawer_size.x * 0.5
	_shop_shell.offset_top = -drawer_size.y * 0.5
	_shop_shell.offset_right = drawer_size.x * 0.5
	_shop_shell.offset_bottom = drawer_size.y * 0.5


func _on_progression_backdrop_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		_set_shop_open(false)


func _set_progression_open(page: String) -> void:
	if _shop_overlay == null:
		return
	_active_progression_page = page
	_shop_overlay.visible = true
	lobby_panel.visible = false
	if _coin_chip != null:
		_coin_chip.visible = false
	if _quest_panel != null:
		_quest_panel.visible = false
	_build_progression()
	get_tree().paused = false


func _set_shop_open(open: bool) -> void:
	if open:
		_set_progression_open("shop")
	elif _shop_overlay != null:
		_shop_overlay.visible = false
		lobby_panel.visible = _lobby_mode_active
		if _coin_chip != null:
			_coin_chip.visible = _lobby_mode_active
		if _quest_panel != null:
			_quest_panel.visible = _lobby_mode_active


func _build_shop(active_category: String) -> void:
	_active_progression_page = "shop"
	_active_shop_category = active_category
	_build_progression()


func _shop_collection_copy() -> String:
	var owned_total := 0
	var item_total := 0
	for category in ["abilities", "skins", "trails", "kill_effects", "faces"]:
		for item_value in _progression.call("get_items", category) as Array:
			var item := item_value as Dictionary
			item_total += 1
			if bool(_progression.call("is_owned", str(item.get("id", "")))):
				owned_total += 1
	return "BUILD YOUR BLOB. %d / %d OWNED. TAP ANY ITEM TO PREVIEW." % [owned_total, item_total]


func _build_progression() -> void:
	for child in _shop_content.get_children():
		child.queue_free()
	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, 62)
	header.add_theme_constant_override("separation", 16)
	_shop_content.add_child(header)
	var back := Button.new()
	back.text = "BACK"
	back.custom_minimum_size = Vector2(92, 44)
	back.focus_mode = Control.FOCUS_NONE
	_apply_utility_button_style(back, Color(0.34, 0.72, 0.94))
	back.pressed.connect(func() -> void: _set_shop_open(false))
	header.add_child(back)
	var title_stack := VBoxContainer.new()
	title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_stack.add_theme_constant_override("separation", -2)
	header.add_child(title_stack)
	var title := Label.new()
	title.text = "BLOB SHOP" if _active_progression_page == "shop" else "QUEST BOARD"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0))
	title_stack.add_child(title)
	var subtitle := Label.new()
	subtitle.text = _shop_collection_copy() if _active_progression_page == "shop" else "PLAY. PROGRESS. GET PAID."
	subtitle.add_theme_font_size_override("font_size", 10)
	subtitle.add_theme_color_override("font_color", Color(0.43, 0.62, 0.88))
	title_stack.add_child(subtitle)
	var balance_chip := PanelContainer.new()
	balance_chip.name = "DrawerBalance"
	balance_chip.custom_minimum_size = Vector2(156, 44)
	balance_chip.add_theme_stylebox_override("panel", _glass_panel_style(Color(1.0, 0.75, 0.18), 14, 0.74))
	header.add_child(balance_chip)
	var balance_row := HBoxContainer.new()
	balance_row.add_theme_constant_override("separation", 8)
	balance_chip.add_child(balance_row)
	var coin_mark := Control.new()
	coin_mark.custom_minimum_size = Vector2(22, 22)
	coin_mark.set_script(COIN_ICON_SCRIPT)
	coin_mark.call("set_accent", Color(1.0, 0.77, 0.16))
	balance_row.add_child(coin_mark)
	var balance_value := Label.new()
	balance_value.text = "%d" % int(_progression.call("get_balance"))
	balance_value.add_theme_font_size_override("font_size", 21)
	balance_value.add_theme_color_override("font_color", UI_TOKENS.COLOR_TEXT)
	balance_row.add_child(balance_value)
	var balance_word := Label.new()
	balance_word.text = "COINS"
	balance_word.add_theme_font_size_override("font_size", 9)
	balance_word.add_theme_color_override("font_color", Color(0.78, 0.68, 0.39))
	balance_row.add_child(balance_word)
	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 1)
	divider.color = Color(0.28, 0.38, 0.58, 0.65)
	_shop_content.add_child(divider)
	if _active_progression_page == "quests":
		_build_quest_board()
		_apply_ui_font_tree(_shop_content)
		return
	_build_shop_workspace()
	_apply_ui_font_tree(_shop_content)


func _build_shop_workspace() -> void:
	var workspace := HBoxContainer.new()
	workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace.add_theme_constant_override("separation", 16)
	_shop_content.add_child(workspace)
	var navigation := VBoxContainer.new()
	navigation.custom_minimum_size = Vector2(148, 0)
	navigation.add_theme_constant_override("separation", 8)
	workspace.add_child(navigation)
	var nav_title := Label.new()
	nav_title.text = "CATEGORIES"
	nav_title.add_theme_font_size_override("font_size", 12)
	nav_title.add_theme_color_override("font_color", Color(0.5, 0.64, 0.86))
	navigation.add_child(nav_title)
	var labels := {"abilities": "Abilities", "skins": "Skins", "trails": "Trails", "kill_effects": "Effects", "faces": "Faces"}
	for category in labels:
		var category_items := _progression.call("get_items", str(category)) as Array
		var owned_count := 0
		for category_item_value in category_items:
			var category_item := category_item_value as Dictionary
			if bool(_progression.call("is_owned", str(category_item.get("id", "")))):
				owned_count += 1
		var tab := Button.new()
		tab.text = "%s\n%d / %d" % [str(labels[category]).to_upper(), owned_count, category_items.size()]
		tab.alignment = HORIZONTAL_ALIGNMENT_LEFT
		tab.custom_minimum_size = Vector2(0, 52)
		tab.focus_mode = Control.FOCUS_NONE
		tab.button_pressed = category == _active_shop_category
		tab.toggle_mode = true
		tab.add_theme_font_size_override("font_size", 11)
		tab.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0) if category == _active_shop_category else Color(0.55, 0.66, 0.82))
		tab.add_theme_stylebox_override("normal", _panel_style(Color(0.095, 0.135, 0.235) if category == _active_shop_category else Color(0.035, 0.05, 0.095), Color(0.35, 0.72, 1.0) if category == _active_shop_category else Color(0.12, 0.19, 0.31), 12))
		tab.add_theme_stylebox_override("hover", _panel_style(Color(0.08, 0.11, 0.19), Color(0.3, 0.56, 0.88), 12))
		tab.pressed.connect(_build_shop.bind(str(category)))
		navigation.add_child(tab)
	var quest_link := Button.new()
	quest_link.text = "EARN COINS  →"
	quest_link.alignment = HORIZONTAL_ALIGNMENT_LEFT
	quest_link.custom_minimum_size = Vector2(0, 46)
	quest_link.focus_mode = Control.FOCUS_NONE
	_apply_utility_button_style(quest_link, Color(1.0, 0.72, 0.18))
	quest_link.pressed.connect(_set_progression_open.bind("quests"))
	navigation.add_child(quest_link)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(396, 0)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	workspace.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 3 if get_viewport().get_visible_rect().size.x >= 1060.0 else 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(grid)
	var items := _progression.call("get_items", _active_shop_category) as Array
	if _selected_shop_item.is_empty() or not items.any(func(item: Dictionary) -> bool: return str(item.get("id", "")) == str(_selected_shop_item.get("id", ""))):
		_selected_shop_item = items[0] as Dictionary if not items.is_empty() else {}
	for item_value in items:
		grid.add_child(_make_shop_item(_active_shop_category, item_value as Dictionary))
	workspace.add_child(_make_preview_panel(_active_shop_category, _selected_shop_item))


func _make_shop_item(category: String, item: Dictionary) -> Control:
	var rarity_colors := {"Common": Color(0.55, 0.6, 0.66), "Rare": Color(0.22, 0.58, 1.0), "Epic": Color(0.68, 0.34, 1.0), "Legendary": Color(1.0, 0.72, 0.16), "Basic": Color(0.32, 0.9, 0.46), "Advanced": Color(0.22, 0.58, 1.0), "Expert": Color(0.68, 0.34, 1.0)}
	var rarity := str(item.get("rarity", "Common"))
	var card_root := Control.new()
	card_root.name = "ShopItem_%s" % str(item.get("id", ""))
	card_root.custom_minimum_size = Vector2(184, 220)
	card_root.mouse_filter = Control.MOUSE_FILTER_STOP
	card_root.pivot_offset = Vector2(92, 110)
	var card := PanelContainer.new()
	card.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.custom_minimum_size = card_root.custom_minimum_size
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_root.add_child(card)
	var selected := str(item.get("id", "")) == str(_selected_shop_item.get("id", ""))
	var item_id := str(item.get("id", ""))
	var owned := bool(_progression.call("is_owned", item_id))
	var equipped := str(_progression.call("get_equipped", category)) == item_id
	var affordable := owned or int(_progression.call("get_balance")) >= int(item.get("price", 0))
	var base_color := Color(0.075, 0.11, 0.19) if selected else Color(0.035, 0.052, 0.095)
	if not affordable:
		base_color = base_color.darkened(0.18)
	var rarity_color: Color = rarity_colors.get(rarity, Color.WHITE)
	var card_style := _elevated_panel_style(
		base_color,
		Color(rarity_color.r, rarity_color.g, rarity_color.b, 0.8) if selected else Color(0.16, 0.25, 0.4, 0.8),
		18,
		Color(rarity_color.r, rarity_color.g, rarity_color.b, 0.18) if selected else Color(0.0, 0.0, 0.0, 0.18)
	)
	card_style.border_width_left = 3 if selected else 1
	card_style.shadow_size = 7 if selected else 0
	card.add_theme_stylebox_override("panel", card_style)
	var stack := VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation", 6)
	card.add_child(stack)
	var preview_frame := PanelContainer.new()
	preview_frame.custom_minimum_size = Vector2(0, 88)
	var preview_style := _panel_style(Color(0.012, 0.024, 0.055, 0.94), Color(rarity_color.r, rarity_color.g, rarity_color.b, 0.26), 14)
	preview_style.content_margin_left = 0
	preview_style.content_margin_top = 0
	preview_style.content_margin_right = 0
	preview_style.content_margin_bottom = 0
	preview_frame.add_theme_stylebox_override("panel", preview_style)
	stack.add_child(preview_frame)
	var card_preview := Control.new()
	card_preview.name = "ItemPreview_%s" % item_id
	card_preview.set_anchors_preset(Control.PRESET_FULL_RECT)
	card_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_preview.set_script(SHOP_CARD_PREVIEW_SCRIPT)
	card_preview.call("set_item", category, item, rarity_color)
	preview_frame.add_child(card_preview)
	var badge_row := HBoxContainer.new()
	badge_row.add_theme_constant_override("separation", 6)
	stack.add_child(badge_row)
	var rarity_label := Label.new()
	rarity_label.text = rarity.to_upper()
	rarity_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rarity_label.add_theme_font_size_override("font_size", 9)
	rarity_label.add_theme_color_override("font_color", rarity_color)
	badge_row.add_child(rarity_label)
	var status := Label.new()
	status.text = "EQUIPPED" if equipped else ("OWNED" if owned else "")
	status.add_theme_font_size_override("font_size", 9)
	status.add_theme_color_override("font_color", Color(0.42, 1.0, 0.62))
	badge_row.add_child(status)
	var name_label := Label.new()
	name_label.text = str(item.get("name", "Item"))
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.tooltip_text = name_label.text
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0))
	stack.add_child(name_label)
	var tagline := Label.new()
	tagline.text = str(item.get("tagline", "Arena-ready style."))
	tagline.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tagline.add_theme_font_size_override("font_size", 10)
	tagline.add_theme_color_override("font_color", Color(0.53, 0.65, 0.82))
	stack.add_child(tagline)
	var inspect := Button.new()
	inspect.text = "SELECTED" if selected else ("PREVIEW" if owned else ("PREVIEW  ·  %d" % int(item.get("price", 0)) if affordable else "NEED %d" % (int(item.get("price", 0)) - int(_progression.call("get_balance")))))
	inspect.custom_minimum_size = Vector2(0, 34)
	inspect.focus_mode = Control.FOCUS_NONE
	inspect.tooltip_text = "Preview %s" % str(item.get("name", "item"))
	_apply_utility_button_style(inspect, rarity_color)
	inspect.pressed.connect(_select_shop_item.bind(item.duplicate(true)))
	stack.add_child(inspect)
	var hit := Button.new()
	hit.name = "CardHitTarget"
	hit.set_anchors_preset(Control.PRESET_FULL_RECT)
	hit.flat = true
	hit.focus_mode = Control.FOCUS_NONE
	hit.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	hit.tooltip_text = "Preview %s" % str(item.get("name", "item"))
	hit.pressed.connect(_select_shop_item.bind(item.duplicate(true)))
	hit.mouse_entered.connect(_animate_shop_card.bind(card_root, true))
	hit.mouse_exited.connect(_animate_shop_card.bind(card_root, false))
	card_root.add_child(hit)
	return card_root


func _make_preview_panel(category: String, item: Dictionary) -> PanelContainer:
	var rarity := str(item.get("rarity", "Common"))
	var colors := {"Common": Color(0.55, 0.6, 0.66), "Rare": Color(0.22, 0.58, 1.0), "Epic": Color(0.68, 0.34, 1.0), "Legendary": Color(1.0, 0.72, 0.16), "Basic": Color(0.32, 0.9, 0.46), "Advanced": Color(0.22, 0.58, 1.0), "Expert": Color(0.68, 0.34, 1.0)}
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(330, 0)
	var panel_style := _elevated_panel_style(Color(0.025, 0.04, 0.082, 0.985), Color(colors.get(rarity, Color.WHITE), 0.62), 20, Color(colors.get(rarity, Color.WHITE), 0.16))
	panel_style.content_margin_left = 18
	panel_style.content_margin_top = 16
	panel_style.content_margin_right = 18
	panel_style.content_margin_bottom = 18
	panel.add_theme_stylebox_override("panel", panel_style)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	panel.add_child(stack)
	var eyebrow := HBoxContainer.new()
	stack.add_child(eyebrow)
	var live := Label.new()
	live.text = "LIVE PREVIEW"
	live.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	live.add_theme_font_size_override("font_size", 10)
	live.add_theme_color_override("font_color", Color(0.35, 1.0, 0.63))
	eyebrow.add_child(live)
	var drag_hint := Label.new()
	drag_hint.text = "DRAG TO ROTATE"
	drag_hint.add_theme_font_size_override("font_size", 9)
	drag_hint.add_theme_color_override("font_color", Color(0.43, 0.58, 0.78))
	eyebrow.add_child(drag_hint)
	var preview := SubViewportContainer.new()
	preview.name = "RealModelPreview"
	preview.custom_minimum_size = Vector2(0, 214)
	preview.set_script(SHOP_MODEL_PREVIEW_SCRIPT)
	preview.call("set_item", category, item, colors.get(rarity, Color.WHITE))
	stack.add_child(preview)
	if category in ["abilities", "kill_effects"]:
		var replay := Button.new()
		replay.text = "REPLAY EFFECT" if category == "kill_effects" else "REPLAY PREVIEW"
		replay.custom_minimum_size = Vector2(0, 32)
		replay.focus_mode = Control.FOCUS_NONE
		_apply_utility_button_style(replay, colors.get(rarity, Color.WHITE))
		replay.pressed.connect(func() -> void: preview.call("replay"))
		stack.add_child(replay)
	var name_label := Label.new()
	name_label.text = str(item.get("name", "Select an item"))
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_font_size_override("font_size", 25)
	name_label.add_theme_color_override("font_color", Color(0.97, 0.98, 1.0))
	stack.add_child(name_label)
	var meta_row := HBoxContainer.new()
	stack.add_child(meta_row)
	var rarity_label := Label.new()
	rarity_label.text = rarity.to_upper()
	rarity_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rarity_label.add_theme_font_size_override("font_size", 11)
	rarity_label.add_theme_color_override("font_color", colors.get(rarity, Color.WHITE))
	meta_row.add_child(rarity_label)
	var category_label := Label.new()
	category_label.text = category.replace("_", " ").trim_suffix("s").to_upper()
	category_label.add_theme_font_size_override("font_size", 10)
	category_label.add_theme_color_override("font_color", Color(0.43, 0.58, 0.78))
	meta_row.add_child(category_label)
	var tagline := Label.new()
	tagline.text = str(item.get("tagline", "Make the arena yours."))
	tagline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tagline.add_theme_font_size_override("font_size", 13)
	tagline.add_theme_color_override("font_color", Color(0.82, 0.9, 1.0))
	stack.add_child(tagline)
	var description := Label.new()
	description.text = str(item.get("description", "A cosmetic that makes your Blob unmistakable."))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_size_override("font_size", 12)
	description.add_theme_color_override("font_color", Color(0.7, 0.78, 0.9))
	description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(description)
	var item_id := str(item.get("id", ""))
	var owned := bool(_progression.call("is_owned", item_id))
	var equipped := str(_progression.call("get_equipped", category)) == item_id
	var action := Button.new()
	action.custom_minimum_size = Vector2(0, 44)
	action.focus_mode = Control.FOCUS_NONE
	action.text = "EQUIPPED" if equipped else ("EQUIP NOW" if owned else "BUY & EQUIP  ·  %d COINS" % int(item.get("price", 0)))
	action.disabled = not owned and int(_progression.call("get_balance")) < int(item.get("price", 0))
	action.tooltip_text = "Not enough Coins" if action.disabled else ""
	var action_accent := Color(0.35, 1.0, 0.58) if owned else Color(1.0, 0.72, 0.18)
	_apply_primary_shop_button_style(action, action_accent)
	action.pressed.connect(_handle_shop_action.bind(category, item.duplicate(true)))
	stack.add_child(action)
	return panel


func _select_shop_item(item: Dictionary) -> void:
	_selected_shop_item = item
	_build_progression()


func _handle_shop_action(category: String, item: Dictionary) -> void:
	var item_id := str(item.get("id", ""))
	if bool(_progression.call("is_owned", item_id)):
		if bool(_progression.call("equip", category, item_id)):
			_show_progression_toast("EQUIPPED", str(item.get("name", "")))
			_build_progression()
		return
	_show_purchase_confirm(category, item)


func _show_purchase_confirm(category: String, item: Dictionary) -> void:
	if _shop_overlay == null:
		return
	var modal := Control.new()
	modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	_shop_overlay.add_child(modal)
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.0, 0.0, 0.0, 0.58)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.gui_input.connect(_cancel_purchase_modal.bind(modal))
	modal.add_child(shade)
	modal.gui_input.connect(_cancel_purchase_modal.bind(modal))
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-220, -170)
	panel.size = Vector2(440, 340)
	panel.scale = Vector2(0.92, 0.92)
	panel.pivot_offset = panel.size * 0.5
	panel.add_theme_stylebox_override("panel", _elevated_panel_style(Color(0.065, 0.085, 0.16, 0.99), Color(1.0, 0.72, 0.18), 20, Color(1.0, 0.62, 0.12, 0.34)))
	modal.add_child(panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	panel.add_child(stack)
	var title := Label.new()
	title.text = "UNLOCK %s?" % str(item.get("name", "ITEM")).to_upper()
	title.add_theme_font_size_override("font_size", 23)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(title)
	var thumbnail := Control.new()
	thumbnail.custom_minimum_size = Vector2(0, 112)
	thumbnail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thumbnail.set_script(SHOP_CARD_PREVIEW_SCRIPT)
	thumbnail.call("set_item", category, item, Color(1.0, 0.72, 0.18))
	stack.add_child(thumbnail)
	var description := Label.new()
	var current_balance := int(_progression.call("get_balance"))
	var price := int(item.get("price", 0))
	var remaining := current_balance - price
	var balance_copy := "%d REMAINING" % remaining if remaining >= 0 else "NEED %d MORE" % absi(remaining)
	description.text = "%s\n%d COINS  •  %s" % [str(item.get("tagline", "Ready for the arena.")), price, balance_copy]
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.add_theme_font_size_override("font_size", 13)
	description.add_theme_color_override("font_color", Color(1.0, 0.83, 0.32))
	stack.add_child(description)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 12)
	stack.add_child(actions)
	var cancel := Button.new()
	cancel.text = "CANCEL"
	cancel.custom_minimum_size = Vector2(124, 42)
	_apply_utility_button_style(cancel, Color(0.68, 0.74, 0.84))
	cancel.pressed.connect(modal.queue_free)
	actions.add_child(cancel)
	var confirm := Button.new()
	confirm.text = "BUY & EQUIP"
	confirm.custom_minimum_size = Vector2(124, 42)
	confirm.disabled = remaining < 0
	confirm.tooltip_text = "Earn %d more Coins to unlock this item" % absi(remaining) if confirm.disabled else ""
	_apply_primary_shop_button_style(confirm, Color(1.0, 0.72, 0.18))
	confirm.pressed.connect(func() -> void:
		if bool(_progression.call("purchase", category, str(item.get("id", "")))):
			var audio := get_node_or_null("/root/AudioManager")
			if audio != null:
				audio.call("play_sfx", &"purchase", -7.0, 1.08)
			_show_progression_toast("ITEM PURCHASED", str(item.get("name", "")))
			modal.queue_free()
			_build_progression()
	)
	actions.add_child(confirm)
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null:
		audio.call("wire_ui_sounds", modal)
	_apply_ui_font_tree(modal)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "modulate:a", 1.0, 0.16)


func _cancel_purchase_modal(event: InputEvent, modal: Control) -> void:
	if not is_instance_valid(modal):
		return
	var click := event as InputEventMouseButton
	if (click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT) or event.is_action_pressed("ui_cancel"):
		modal.queue_free()


func _build_quest_board() -> void:
	var hero := PanelContainer.new()
	hero.custom_minimum_size = Vector2(0, 66)
	hero.add_theme_stylebox_override("panel", _glass_panel_style(Color(0.33, 0.68, 1.0), 14, 0.72))
	_shop_content.add_child(hero)
	var hero_row := HBoxContainer.new()
	hero_row.add_theme_constant_override("separation", 12)
	hero.add_child(hero_row)
	var hero_mark := Label.new()
	hero_mark.text = "24H"
	hero_mark.custom_minimum_size = Vector2(48, 40)
	hero_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hero_mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hero_mark.add_theme_font_size_override("font_size", 14)
	hero_mark.add_theme_color_override("font_color", Color(0.55, 0.82, 1.0))
	hero_row.add_child(hero_mark)
	var hero_copy := VBoxContainer.new()
	hero_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hero_row.add_child(hero_copy)
	var hero_title := Label.new()
	hero_title.text = "TODAY'S OBJECTIVES"
	hero_title.add_theme_font_size_override("font_size", 16)
	hero_copy.add_child(hero_title)
	var hero_subtitle := Label.new()
	hero_subtitle.text = "Play naturally. Claim rewards when each objective is ready."
	hero_subtitle.add_theme_font_size_override("font_size", 12)
	hero_subtitle.add_theme_color_override("font_color", Color(0.61, 0.72, 0.9))
	hero_copy.add_child(hero_subtitle)
	var reset_copy := Label.new()
	reset_copy.text = _daily_reset_text()
	reset_copy.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	reset_copy.add_theme_font_size_override("font_size", 12)
	reset_copy.add_theme_color_override("font_color", Color(0.67, 0.76, 0.88))
	hero_row.add_child(reset_copy)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	_shop_content.add_child(tabs)
	for tab_data in [[false, "DAILY"], [true, "WEEKLY"]]:
		var button := Button.new()
		button.text = str(tab_data[1])
		button.toggle_mode = true
		button.button_pressed = _quests_showing_weekly == bool(tab_data[0])
		button.custom_minimum_size = Vector2(132, 42)
		button.pressed.connect(_set_quest_tab.bind(bool(tab_data[0])))
		tabs.add_child(button)
	var subtitle := Label.new()
	subtitle.text = "A fresh set every day" if not _quests_showing_weekly else "Longer objectives with larger rewards"
	subtitle.add_theme_color_override("font_color", Color(0.57, 0.69, 0.9))
	_shop_content.add_child(subtitle)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_shop_content.add_child(scroll)
	var scroll_gutter := MarginContainer.new()
	scroll_gutter.name = "QuestScrollGutter"
	scroll_gutter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_gutter.add_theme_constant_override("margin_right", 14)
	scroll.add_child(scroll_gutter)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll_gutter.add_child(list)
	var quests: Array = (_progression.get("weekly_quests") as Array) if _quests_showing_weekly else (_progression.get("daily_quests") as Array)
	for quest_value in quests:
		var quest := quest_value as Dictionary
		var claimed := bool(quest.get("claimed", false))
		var completed := bool(quest.get("completed", false)) or claimed
		var target := maxi(1, int(quest.get("target", 1)))
		var progress := mini(target, int(quest.get("progress", 0)))
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(0, 88)
		var quest_color := Color(0.38, 1.0, 0.6) if claimed else (Color(1.0, 0.7, 0.18) if completed else (Color(0.4, 0.54, 1.0) if _quests_showing_weekly else Color(0.25, 0.68, 1.0)))
		var card_style := _panel_style(Color(0.042, 0.055, 0.086, 0.88), Color(quest_color.r, quest_color.g, quest_color.b, 0.34), 11)
		card_style.border_width_left = 3 if completed else 1
		card_style.content_margin_top = 9
		card_style.content_margin_bottom = 9
		card.add_theme_stylebox_override("panel", card_style)
		var stack := VBoxContainer.new()
		stack.add_theme_constant_override("separation", 6)
		card.add_child(stack)
		var row := HBoxContainer.new()
		stack.add_child(row)
		var text := Label.new()
		text.text = str(quest.get("title", "Quest"))
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.add_theme_font_size_override("font_size", 16)
		row.add_child(text)
		var reward := Button.new()
		reward.text = "CLAIMED" if claimed else ("CLAIM +%d" % int(quest.get("reward", 0)) if completed else "+%d COINS" % int(quest.get("reward", 0)))
		reward.disabled = not completed or claimed
		reward.focus_mode = Control.FOCUS_NONE
		reward.add_theme_font_size_override("font_size", 14)
		reward.add_theme_color_override("font_color", Color(0.42, 1.0, 0.62) if claimed else Color(1.0, 0.78, 0.2))
		if completed and not claimed:
			reward.pressed.connect(_claim_quest.bind("weekly" if _quests_showing_weekly else "daily", str(quest.get("id", ""))))
		row.add_child(reward)
		var progress_bar := ProgressBar.new()
		progress_bar.custom_minimum_size = Vector2(0, 12)
		progress_bar.max_value = target
		progress_bar.value = progress
		progress_bar.show_percentage = false
		progress_bar.add_theme_stylebox_override("background", _progress_style(Color(0.025, 0.035, 0.07), Color(0.16, 0.25, 0.45)))
		progress_bar.add_theme_stylebox_override("fill", _progress_style(quest_color, Color.TRANSPARENT))
		stack.add_child(progress_bar)
		var progress_label := Label.new()
		progress_label.text = "CLAIMED" if claimed else ("READY TO CLAIM" if completed else "IN PROGRESS  ·  %d / %d" % [progress, target])
		progress_label.add_theme_font_size_override("font_size", 13)
		progress_label.add_theme_color_override("font_color", Color(0.38, 0.96, 0.6) if claimed else (Color(1.0, 0.78, 0.2) if completed else Color(0.63, 0.75, 0.93)))
		stack.add_child(progress_label)
		list.add_child(card)


func _set_quest_tab(show_weekly: bool) -> void:
	_quests_showing_weekly = show_weekly
	_build_progression()


func _claim_quest(group: String, quest_id: String) -> void:
	if _progression == null or not bool(_progression.call("claim_quest", group, quest_id)):
		return
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null:
		audio.call("play_sfx", &"coin_collect", -8.0, 1.2)
	_show_progression_toast("QUEST CLAIMED", "Coins added to your balance")
	_build_progression()


func _create_reward_panel() -> void:
	_reward_panel = PanelContainer.new()
	_reward_panel.name = "MatchRewards"
	_reward_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_reward_panel.position = Vector2(56, 212)
	_reward_panel.size = Vector2(440, 272)
	_reward_panel.add_theme_stylebox_override("panel", _glass_panel_style(Color(1.0, 0.68, 0.18), 14, 0.9))
	victory_overlay.add_child(_reward_panel)
	var stack := VBoxContainer.new()
	stack.name = "Stack"
	stack.add_theme_constant_override("separation", UI_TOKENS.SPACE_MD)
	_reward_panel.add_child(stack)
	var title := Label.new()
	title.name = "Header"
	title.text = "MATCH REWARDS"
	title.add_theme_font_size_override("font_size", 19)
	title.add_theme_color_override("font_color", Color(1.0, 0.8, 0.25))
	stack.add_child(title)
	var rows := VBoxContainer.new()
	rows.name = "Rows"
	rows.add_theme_constant_override("separation", UI_TOKENS.SPACE_SM)
	stack.add_child(rows)
	var return_button := Button.new()
	return_button.name = "ReturnToLobbyButton"
	return_button.text = "RETURN TO LOBBY"
	return_button.custom_minimum_size = Vector2(0, 46)
	return_button.focus_mode = Control.FOCUS_NONE
	_apply_utility_button_style(return_button, Color(0.34, 0.92, 0.78))
	return_button.pressed.connect(func() -> void: return_to_lobby_requested.emit())
	stack.add_child(return_button)


func _on_coin_balance_changed(balance: int, delta: int) -> void:
	_coin_target_balance = balance
	_pulse_coin_chip(delta > 0)
	if delta > 0:
		_show_coin_earn(delta)
	_refresh_quest_panel()


func _on_quest_completed(quest: Dictionary, _reward: int) -> void:
	show_announcement("QUEST COMPLETE!  %s" % str(quest.get("title", "")), Color(0.35, 1.0, 0.56))
	_show_progression_toast("QUEST COMPLETE", str(quest.get("title", "")))


func _create_toast_stack() -> void:
	_toast_stack = VBoxContainer.new()
	_toast_stack.name = "ToastStack"
	_toast_stack.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_toast_stack.position = Vector2(-340, 92)
	_toast_stack.custom_minimum_size = Vector2(316, 0)
	_toast_stack.add_theme_constant_override("separation", 8)
	_toast_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_toast_stack)


func _show_progression_toast(title: String, detail: String) -> void:
	if _toast_stack == null:
		return
	move_child(_toast_stack, get_child_count() - 1)
	if _toast_stack.get_child_count() >= 3:
		_toast_stack.get_child(0).free()
	var toast := PanelContainer.new()
	toast.name = "ToastMessage"
	toast.custom_minimum_size = Vector2(316, 68)
	toast.modulate.a = 0.0
	toast.add_theme_stylebox_override("panel", _glass_panel_style(Color(0.32, 0.95, 0.61), 12, 0.9))
	_toast_stack.add_child(toast)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	toast.add_child(row)
	var status_rail := ColorRect.new()
	status_rail.custom_minimum_size = Vector2(3, 0)
	status_rail.color = Color(0.32, 0.95, 0.61)
	status_rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(status_rail)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	copy.add_theme_constant_override("separation", 1)
	row.add_child(copy)
	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 13)
	title_label.add_theme_color_override("font_color", Color(0.88, 1.0, 0.94))
	copy.add_child(title_label)
	var detail_label := Label.new()
	detail_label.text = detail
	detail_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	detail_label.add_theme_font_size_override("font_size", 12)
	detail_label.add_theme_color_override("font_color", Color(0.64, 0.72, 0.81))
	copy.add_child(detail_label)
	_apply_ui_font_tree(toast)
	toast.position.x = 12.0
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	tween.tween_property(toast, "modulate:a", 1.0, 0.06 if _reduced_motion else 0.14)
	tween.tween_property(toast, "position:x", 0.0, 0.01 if _reduced_motion else 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.set_parallel(false)
	tween.tween_interval(2.6)
	tween.tween_property(toast, "modulate:a", 0.0, 0.06 if _reduced_motion else 0.16)
	tween.tween_callback(toast.queue_free)


func _show_coin_earn(amount: int) -> void:
	var floating := Label.new()
	floating.text = "+%d COINS" % amount
	floating.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	floating.position = Vector2(-210, 86)
	floating.add_theme_font_size_override("font_size", 21)
	floating.add_theme_color_override("font_color", Color(1.0, 0.82, 0.25))
	add_child(floating)
	var primary_coin := Control.new()
	primary_coin.set_script(COIN_ICON_SCRIPT)
	primary_coin.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	primary_coin.position = Vector2(-210, 80)
	primary_coin.size = Vector2(30, 30)
	primary_coin.pivot_offset = Vector2(15, 15)
	primary_coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(primary_coin)
	var coin_tween := create_tween()
	coin_tween.set_parallel(true)
	coin_tween.tween_property(primary_coin, "position", Vector2(-145, 34), 0.64).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	coin_tween.tween_property(primary_coin, "rotation", TAU, 0.64)
	coin_tween.tween_property(primary_coin, "scale", Vector2(1.24, 1.24), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	coin_tween.set_parallel(false)
	coin_tween.tween_property(primary_coin, "scale", Vector2(0.18, 0.18), 0.16)
	coin_tween.tween_callback(primary_coin.queue_free)
	for index in 4:
		var particle := Control.new()
		particle.set_script(COIN_ICON_SCRIPT)
		particle.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		particle.position = Vector2(-142, 92)
		particle.size = Vector2(20, 20)
		particle.pivot_offset = Vector2(10, 10)
		particle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(particle)
		var angle := TAU * float(index) / 4.0
		var destination := particle.position + Vector2(cos(angle), sin(angle)) * 42.0
		var particle_tween := create_tween()
		particle_tween.set_parallel(true)
		particle_tween.tween_property(particle, "position", destination, 0.48).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		particle_tween.tween_property(particle, "rotation", TAU * (1.0 if index % 2 == 0 else -1.0), 0.48)
		particle_tween.tween_property(particle, "modulate:a", 0.0, 0.46).set_delay(0.18)
		particle_tween.set_parallel(false)
		particle_tween.tween_callback(particle.queue_free)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(floating, "position:y", 48.0, 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(floating, "modulate:a", 0.0, 0.75).set_delay(0.35)
	tween.set_parallel(false)
	tween.tween_callback(floating.queue_free)
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null:
		audio.call("play_sfx", &"coin_collect", -10.0, 1.12)


func _refresh_shop_if_open() -> void:
	if _shop_overlay != null and _shop_overlay.visible:
		_build_progression()


func _animate_shop_card(card: Control, hovered: bool) -> void:
	if not is_instance_valid(card):
		return
	var active_tween := card.get_meta(&"shop_hover_tween") as Tween if card.has_meta(&"shop_hover_tween") else null
	if active_tween != null and active_tween.is_valid():
		active_tween.kill()
	# GridContainer owns card position. Moving or enlarging the card here fights the
	# layout pass and can also paint it over its siblings, so hover is color-only.
	card.scale = Vector2.ONE
	card.z_index = 0
	var tween := card.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	card.set_meta(&"shop_hover_tween", tween)
	tween.tween_property(card, "modulate", Color(1.08, 1.08, 1.08, 1.0) if hovered else Color.WHITE, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _pulse_coin_chip(earned: bool) -> void:
	if _coin_chip == null:
		return
	_coin_chip.pivot_offset = _coin_chip.size * 0.5
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_coin_chip, "scale", Vector2(1.1, 1.1), 0.11).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if _coin_icon != null and earned:
		tween.tween_property(_coin_icon, "rotation", TAU * 0.45, 0.2)
	tween.set_parallel(false)
	tween.tween_property(_coin_chip, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _update_coin_label() -> void:
	if _coin_balance_label != null:
		_coin_balance_label.text = "%d" % int(round(_shown_coin_balance))


func _update_quest_reset_label() -> void:
	if _quest_reset_label == null:
		return
	_quest_reset_label.text = _daily_reset_text()


func _daily_reset_text() -> String:
	var now := Time.get_time_dict_from_system()
	var remaining := maxi(0, 86400 - int(now.get("hour", 0)) * 3600 - int(now.get("minute", 0)) * 60 - int(now.get("second", 0)))
	return "RESET  %02d:%02d:%02d" % [remaining / 3600, (remaining % 3600) / 60, remaining % 60]


func _glass_panel_style(accent: Color, radius: int, alpha: float) -> StyleBoxFlat:
	var style := _panel_style(Color(0.025, 0.035, 0.055, alpha), Color(accent.r, accent.g, accent.b, 0.42), radius)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.32)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0, 4)
	return style


func _apply_utility_button_style(button: Button, accent: Color) -> void:
	button.add_theme_stylebox_override("normal", _panel_style(Color(0.055, 0.07, 0.105, 0.78), Color(accent.r, accent.g, accent.b, 0.28), 10))
	button.add_theme_stylebox_override("hover", _panel_style(Color(0.085, 0.11, 0.16, 0.94), Color(accent.r, accent.g, accent.b, 0.78), 10))
	button.add_theme_stylebox_override("pressed", _panel_style(Color(0.04, 0.055, 0.08, 0.98), accent, 10))
	button.add_theme_color_override("font_color", Color(0.86, 0.91, 0.97))
	button.add_theme_color_override("font_hover_color", Color.WHITE)


func _apply_primary_shop_button_style(button: Button, accent: Color) -> void:
	var normal := _panel_style(Color(accent.r * 0.72, accent.g * 0.72, accent.b * 0.72, 0.96), accent.lightened(0.18), 12)
	normal.shadow_color = Color(accent.r, accent.g, accent.b, 0.26)
	normal.shadow_size = 8
	normal.shadow_offset = Vector2(0, 3)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", _panel_style(accent.lightened(0.04), Color.WHITE, 12))
	button.add_theme_stylebox_override("pressed", _panel_style(accent.darkened(0.24), accent, 12))
	button.add_theme_stylebox_override("disabled", _panel_style(Color(0.065, 0.075, 0.1, 0.9), Color(0.18, 0.22, 0.3), 12))
	button.add_theme_color_override("font_color", Color(0.025, 0.035, 0.055))
	button.add_theme_color_override("font_hover_color", Color(0.01, 0.02, 0.035))
	button.add_theme_color_override("font_disabled_color", Color(0.42, 0.46, 0.54))
	button.add_theme_font_size_override("font_size", 13)


func _panel_style(background: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = 14
	style.content_margin_top = 12
	style.content_margin_right = 14
	style.content_margin_bottom = 12
	return style


func _announcement_style(accent: Color) -> StyleBoxFlat:
	var style := _panel_style(Color(0.018, 0.028, 0.055, 0.88), Color(accent.r, accent.g, accent.b, 0.72), 14)
	style.content_margin_left = 22
	style.content_margin_right = 22
	style.shadow_color = Color(accent.r, accent.g, accent.b, 0.22)
	style.shadow_size = 12
	return style


func _timer_style(accent: Color) -> StyleBoxFlat:
	var style := _panel_style(Color(0.02, 0.03, 0.055, 0.86), accent, 12)
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	style.content_margin_left = 12
	style.content_margin_right = 12
	return style


func _elevated_panel_style(background: Color, border: Color, radius: int, shadow: Color) -> StyleBoxFlat:
	var style := _panel_style(background, border, radius)
	style.shadow_color = shadow
	style.shadow_size = 12
	style.shadow_offset = Vector2(0, 5)
	return style


func _progress_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	return style


func _reveal_roster() -> void:
	roster_panel.visible = true
	if _reduced_motion:
		roster_panel.modulate.a = 1.0
		return
	roster_panel.modulate.a = 0.0
	roster_panel.position.x += 36.0
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	tween.tween_property(roster_panel, "modulate:a", 1.0, 0.24)
	tween.tween_property(roster_panel, "position:x", roster_panel.position.x - 36.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _build_roster(players: Array) -> void:
	var roster_height := clampf(120.0 + players.size() * 68.0, 240.0, 440.0)
	roster_panel.offset_top = -roster_height * 0.5
	roster_panel.offset_bottom = roster_height * 0.5
	for child in roster_players.get_children():
		child.queue_free()
	for entry_value in players:
		var entry := entry_value as Dictionary
		var blob_tint: Color = entry.get("color", Color.WHITE)
		var team_tint: Color = entry.get("team_color", Color.WHITE)
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 60)
		button.focus_mode = Control.FOCUS_NONE
		button.text = ""
		button.add_theme_stylebox_override("normal", _roster_button_style(false))
		button.add_theme_stylebox_override("hover", _roster_button_style(true))
		button.add_theme_stylebox_override("pressed", _roster_button_style(true))
		var avatar := Control.new()
		avatar.set_script(BLOB_AVATAR_SCRIPT)
		avatar.position = Vector2(10, 6)
		avatar.size = Vector2(48, 48)
		avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		avatar.call("set_color", blob_tint)
		button.add_child(avatar)
		var label := Label.new()
		label.position = Vector2(70, 5)
		label.size = Vector2(236, 50)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.text = "%s\n%s TEAM" % [str(entry.get("name", "Player")), str(entry.get("team_name", "RED"))]
		label.add_theme_font_size_override("font_size", 15)
		label.add_theme_color_override("font_color", team_tint)
		button.add_child(label)
		button.pressed.connect(_open_stats.bind(entry))
		roster_players.add_child(button)
	_apply_ui_font_tree(roster_panel)


func _apply_ui_font_tree(scope: Node) -> void:
	if _ui_font == null or scope == null:
		return
	if scope is Control:
		(scope as Control).add_theme_font_override("font", _ui_font)
	for candidate in scope.find_children("*", "Control", true, false):
		(candidate as Control).add_theme_font_override("font", _ui_font)


func _roster_button_style(hovered: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.105, 0.125, 0.16, 0.98) if hovered else Color(0.055, 0.07, 0.1, 0.94)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.42, 0.5, 0.61, 0.82) if hovered else Color(0.25, 0.31, 0.4, 0.72)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	return style


func _open_stats(entry: Dictionary) -> void:
	var eliminations := int(entry.get("eliminations", 0))
	var deaths := int(entry.get("deaths", 0))
	stats_name.text = str(entry.get("name", "Player"))
	var team_tint: Color = entry.get("team_color", Color.WHITE)
	stats_name.add_theme_color_override("font_color", team_tint)
	stats_eliminations.text = "Eliminations        %d" % eliminations
	stats_deaths.text = "Deaths                 %d" % deaths
	stats_ratio.text = "E/D Ratio            %.2f" % (float(eliminations) / maxf(float(deaths), 1.0))
	stats_panel.visible = true
	var manager := get_node_or_null("/root/AudioManager")
	if manager != null:
		manager.call("play_sfx", &"ui_click", -5.0, 1.05)


func _close_stats() -> void:
	stats_panel.visible = false


func _configure_map_picker() -> void:
	map_picker.clear()
	for map_entry in COMPETITIVE_MAPS:
		map_picker.add_item(str(map_entry[1]))
		map_picker.set_item_metadata(map_picker.item_count - 1, str(map_entry[0]))
	map_picker.select(0)


func _emit_identity() -> void:
	identity_changed.emit(get_player_name(), get_player_color())


func _process(delta: float) -> void:
	_quest_reset_accumulator += delta
	if _quest_reset_accumulator >= 1.0:
		_quest_reset_accumulator = 0.0
		_update_quest_reset_label()
	if absf(_shown_coin_balance - float(_coin_target_balance)) > 0.05:
		_shown_coin_balance = move_toward(_shown_coin_balance, float(_coin_target_balance), maxf(80.0, absf(_coin_target_balance - _shown_coin_balance) * 7.0) * delta)
		_update_coin_label()
	_hit_marker_time = maxf(_hit_marker_time - delta, 0.0)
	_damage_flash_time = maxf(_damage_flash_time - delta, 0.0)
	_announcement_time = maxf(_announcement_time - delta, 0.0)
	hit_marker.modulate.a = clampf(_hit_marker_time / 0.12, 0.0, 1.0)
	damage_flash.modulate.a = clampf(_damage_flash_time / 0.2, 0.0, 1.0)
	if _hit_marker_time <= 0.0:
		hit_marker.visible = false
	if _damage_flash_time <= 0.0:
		damage_flash.visible = false
	if _announcement_time <= 0.0:
		if _announcement_queue.is_empty():
			announcement.visible = false
		else:
			var queued: Dictionary = _announcement_queue.pop_front() as Dictionary
			var queued_color := queued.get("color", Color.WHITE) as Color
			_show_announcement_now(str(queued.get("message", "")), queued_color)

	if player == null:
		return
	if player.has_method("get_fling_cooldown_remaining") and player.has_method("get_fling_cooldown_duration"):
		set_fling_cooldown(
			float(player.call("get_fling_cooldown_remaining")),
			float(player.call("get_fling_cooldown_duration"))
		)

	_shown_health = move_toward(_shown_health, player.health, 420.0 * delta)
	if _last_observed_health >= 0 and player.health < _last_observed_health:
		health_panel.pivot_offset = health_panel.size * 0.5
		var health_tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		health_tween.tween_property(health_panel, "scale", Vector2(1.04, 1.04), 0.08)
		health_tween.tween_property(health_panel, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_last_observed_health = player.health
	health_bar.max_value = player.max_health
	health_bar.value = _shown_health
	health_value.text = "%d / %d" % [player.health, player.max_health]
	var charge_ratio: float = player.get_charge_ratio()
	charge_bar.value = charge_ratio * 100.0
	charge_value.text = "FLING READY" if charge_ratio >= 0.999 else "FLING  %d%%" % int(round(charge_ratio * 100.0))
	var charge_color := Color(0.12, 0.78, 1.0)
	if charge_ratio >= 0.75:
		charge_color = Color(1.0, 0.72, 0.18)
	elif charge_ratio >= 0.5:
		charge_color = Color(0.44, 0.92, 0.5)
	elif charge_ratio >= 0.25:
		charge_color = Color(0.22, 0.88, 0.88)
	_charge_fill_style.bg_color = charge_color
	charge_value.add_theme_color_override("font_color", charge_color.lightened(0.45))
	if crosshair.has_method("set_dynamic_state"):
		crosshair.call("set_dynamic_state", charge_ratio, player.linear_velocity.length() / maxf(player.ground_control_speed, 1.0))

	var ratio: float = float(player.health) / float(player.max_health)
	var health_color: Color
	if ratio > 0.6:
		health_color = Color(0.18, 0.9, 0.56, 1.0)
	elif ratio > 0.3:
		health_color = Color(0.98, 0.72, 0.2, 1.0)
	else:
		health_color = Color(1.0, 0.28, 0.32, 1.0)

	_fill_style.bg_color = health_color
	health_value.add_theme_color_override("font_color", health_color.lightened(0.52))
	if _health_shell_style != null:
		_health_shell_style.border_color = Color(health_color.r, health_color.g, health_color.b, 0.82)
		_health_shell_style.shadow_color = Color(health_color.r, health_color.g, health_color.b, 0.18 if ratio > 0.3 else 0.38)


func set_camera_mode(_is_third_person: bool) -> void:
	pass
