extends CanvasLayer

const BLOB_AVATAR_SCRIPT := preload("res://scripts/blob_avatar.gd")
const LOBBY_BANNER_TEXTURE := preload("res://assets/ui/art/lobby-banner.png")
const COIN_TEXTURE := preload("res://assets/ui/economy/blob-coin.png")
const SHOP_BLOB_PREVIEW_SCRIPT := preload("res://scripts/shop_blob_preview.gd")

signal host_requested
signal join_requested(address: String)
signal practice_requested
signal identity_changed(display_name: String, color: Color)

const BLOB_COLORS := [
	Color(0.05, 0.69, 0.96),
	Color(1.0, 0.28, 0.42),
	Color(1.0, 0.72, 0.12),
	Color(0.54, 0.34, 1.0),
	Color(0.34, 0.86, 0.3),
]
const COLOR_NAMES := ["Cyan", "Coral", "Gold", "Violet", "Lime"]
const COMPETITIVE_MAPS := [
	["neon_arcade", "Neon Arcade"],
	["backyard", "Backyard"],
	["arena", "Arena"],
	["sky_temple", "Sky Temple"],
	["toybox", "Toybox"],
]

@onready var health_bar: ProgressBar = $HealthPanel/HealthBar
@onready var health_value: Label = $HealthPanel/HealthBar/HealthValue
@onready var health_panel: PanelContainer = $HealthPanel
@onready var crosshair: Control = $Crosshair
@onready var lobby_panel: PanelContainer = $LobbyPanel
@onready var lobby_stack: VBoxContainer = $LobbyPanel/LobbyStack
@onready var name_input: LineEdit = $LobbyPanel/LobbyStack/IdentityRow/NameInput
@onready var color_swatches: HBoxContainer = $LobbyPanel/LobbyStack/IdentityRow/ColorSwatches
@onready var address_input: LineEdit = $LobbyPanel/LobbyStack/AddressInput
@onready var map_picker: OptionButton = $LobbyPanel/LobbyStack/MapRow/MapPicker
@onready var status_label: Label = $LobbyPanel/LobbyStack/StatusLabel
@onready var host_button: Button = $LobbyPanel/LobbyStack/SessionButtons/HostButton
@onready var join_button: Button = $LobbyPanel/LobbyStack/SessionButtons/JoinButton
@onready var practice_button: Button = $LobbyPanel/LobbyStack/PracticeButton
@onready var hit_marker: Control = $HitMarker
@onready var damage_flash: ColorRect = $DamageFlash
@onready var charge_panel: PanelContainer = $ChargePanel
@onready var charge_bar: ProgressBar = $ChargePanel/ChargeBar
@onready var charge_value: Label = $ChargePanel/ChargeBar/ChargeValue
@onready var timer_label: Label = $TimerLabel
@onready var announcement: Label = $Announcement
@onready var scoreboard: HBoxContainer = $Scoreboard
@onready var red_score_panel: PanelContainer = $Scoreboard/RedScore
@onready var red_score_value: Label = $Scoreboard/RedScore/Value
@onready var blue_score_panel: PanelContainer = $Scoreboard/BlueScore
@onready var blue_score_value: Label = $Scoreboard/BlueScore/Value
@onready var round_banner: PanelContainer = $RoundBanner
@onready var round_banner_label: Label = $RoundBanner/Label
@onready var victory_overlay: Control = $VictoryOverlay
@onready var result_banner: PanelContainer = $VictoryOverlay/ResultBanner
@onready var result_label: Label = $VictoryOverlay/ResultBanner/Label
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
var _ability_was_ready := false
var _ability_pulse_tween: Tween
var _selected_color_index := 0
var _duel_mode := false
var _round_banner_style := StyleBoxFlat.new()
var _progression: Node
var _coin_balance_label: Label
var _coin_chip: PanelContainer
var _coin_icon: TextureRect
var _shop_overlay: Control
var _shop_content: VBoxContainer
var _quest_panel: PanelContainer
var _reward_panel: PanelContainer
var _shown_coin_balance := 0.0
var _coin_target_balance := 0
var _active_progression_page := "shop"
var _active_shop_category := "abilities"
var _selected_shop_item: Dictionary = {}
var _quests_showing_weekly := false
var _ability_panel: PanelContainer
var _ability_title: Label
var _ability_status: Label
var _ability_bar: ProgressBar


func _ready() -> void:
	_install_lobby_art()
	_fill_style.corner_radius_top_left = 8
	_fill_style.corner_radius_top_right = 8
	_fill_style.corner_radius_bottom_right = 8
	_fill_style.corner_radius_bottom_left = 8
	health_bar.add_theme_stylebox_override("fill", _fill_style)
	_charge_fill_style.bg_color = Color(0.12, 0.78, 1.0, 1.0)
	_charge_fill_style.corner_radius_top_left = 6
	_charge_fill_style.corner_radius_top_right = 6
	_charge_fill_style.corner_radius_bottom_right = 6
	_charge_fill_style.corner_radius_bottom_left = 6
	charge_bar.add_theme_stylebox_override("fill", _charge_fill_style)
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
	_configure_color_swatches()
	_configure_map_picker()
	host_button.pressed.connect(func() -> void: host_requested.emit())
	join_button.pressed.connect(func() -> void: join_requested.emit(address_input.text))
	practice_button.pressed.connect(func() -> void: practice_requested.emit())
	name_input.text_changed.connect(func(_new_text: String) -> void: _emit_identity())
	$VictoryOverlay/StatsPanel/Stack/Top/Close.pressed.connect(_close_stats)
	_setup_progression_ui()
	_setup_ability_ui()


func _setup_ability_ui() -> void:
	_ability_panel = PanelContainer.new()
	_ability_panel.name = "AbilityPanel"
	_ability_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_ability_panel.position = Vector2(-328, -162)
	_ability_panel.size = Vector2(296, 54)
	_ability_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.07, 0.12, 0.92)
	style.border_color = Color(0.2, 0.7, 1.0, 0.86)
	style.set_border_width_all(2)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	_ability_panel.add_theme_stylebox_override("panel", style)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 1)
	_ability_panel.add_child(stack)
	_ability_title = Label.new()
	_ability_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ability_title.add_theme_font_size_override("font_size", 16)
	stack.add_child(_ability_title)
	_ability_bar = ProgressBar.new()
	_ability_bar.max_value = 1.0
	_ability_bar.show_percentage = false
	_ability_bar.custom_minimum_size = Vector2(260, 8)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.18, 0.7, 1.0, 1.0)
	fill.corner_radius_top_left = 4
	fill.corner_radius_top_right = 4
	fill.corner_radius_bottom_left = 4
	fill.corner_radius_bottom_right = 4
	_ability_bar.add_theme_stylebox_override("fill", fill)
	stack.add_child(_ability_bar)
	_ability_status = Label.new()
	_ability_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ability_status.add_theme_font_size_override("font_size", 12)
	stack.add_child(_ability_status)
	add_child(_ability_panel)
	_ability_panel.visible = false


func set_ability_state(ability_id: String, cooldown_remaining_msec: int, loaded: bool, active: bool, active_remaining_msec: int = 0, deployed: bool = false) -> void:
	if _ability_panel == null:
		return
	_ability_panel.visible = not lobby_panel.visible and not ability_id.is_empty()
	if ability_id.is_empty():
		_ability_was_ready = false
		return
	var display := {"dash": "⚡ DASH", "ricochet_shot": "↗ RICOCHET SHOT", "quick_charge": "✦ QUICK CHARGE", "blink": "✧ BLINK", "target_scanner": "◉ TARGET SCANNER", "overcharge": "✹ OVERCHARGE", "gravity_pulse": "◌ GRAVITY PULSE", "rail_shot": "━ RAIL SHOT", "bounce_mine": "● BOUNCE MINE", "phase_bubble": "◯ PHASE BUBBLE", "adrenaline": "♥ ADRENALINE"}
	_ability_title.text = str(display.get(ability_id, "ABILITY"))
	if ability_id == "quick_charge":
		_ability_bar.value = 1.0
		_ability_status.text = "PASSIVE • FLING CHARGES 20% FASTER"
		_ability_was_ready = false
		return
	if ability_id == "adrenaline":
		_ability_bar.value = 1.0 if active else 0.0
		_ability_status.text = "ACTIVE • MOVE +15% • CHARGE +15%" if active else "PASSIVE • ARMS BELOW 60% HP"
		_ability_was_ready = false
		return
	if loaded:
		_ability_bar.value = 1.0
		_ability_status.text = "LOADED • NEXT SHOT BOUNCES 3×"
		_update_ability_ready_feedback(true)
		return
	if deployed:
		_ability_bar.value = 1.0
		_ability_status.text = "DEPLOYED • ONE MINE ACTIVE"
		_update_ability_ready_feedback(false)
		return
	if active:
		_ability_bar.value = 1.0
		_ability_status.text = "ACTIVE %.1fs" % (float(active_remaining_msec) / 1000.0)
		_update_ability_ready_feedback(false)
		return
	var totals := {"dash": 7000.0, "ricochet_shot": 10000.0, "blink": 18000.0, "target_scanner": 20000.0, "overcharge": 15000.0, "gravity_pulse": 16000.0, "rail_shot": 15000.0, "bounce_mine": 18000.0, "phase_bubble": 25000.0}
	var total := float(totals.get(ability_id, 10000.0))
	_ability_bar.value = 1.0 - clampf(float(cooldown_remaining_msec) / total, 0.0, 1.0)
	_ability_status.text = "READY • PRESS E" if cooldown_remaining_msec <= 0 else "RECHARGING %.1fs" % (float(cooldown_remaining_msec) / 1000.0)
	_update_ability_ready_feedback(cooldown_remaining_msec <= 0)


func _update_ability_ready_feedback(is_ready: bool) -> void:
	if is_ready and not _ability_was_ready and _ability_panel != null and _ability_panel.visible:
		if _ability_pulse_tween != null and _ability_pulse_tween.is_valid():
			_ability_pulse_tween.kill()
		_ability_panel.pivot_offset = _ability_panel.size * 0.5
		_ability_panel.scale = Vector2(0.94, 0.94)
		_ability_panel.modulate = Color(0.72, 0.96, 1.0, 1.0)
		_ability_pulse_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_ability_pulse_tween.set_parallel(true)
		_ability_pulse_tween.tween_property(_ability_panel, "scale", Vector2(1.06, 1.06), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_ability_pulse_tween.tween_property(_ability_panel, "modulate", Color.WHITE, 0.3)
		_ability_pulse_tween.set_parallel(false)
		_ability_pulse_tween.tween_property(_ability_panel, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		var audio := get_node_or_null("/root/AudioManager")
		if audio != null:
			audio.call("play_sfx", &"ability_ready", -9.0, 1.08)
	_ability_was_ready = is_ready


func _install_lobby_art() -> void:
	var art_shell := PanelContainer.new()
	art_shell.name = "LobbyArt"
	art_shell.custom_minimum_size = Vector2(0, 118)
	art_shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	art_shell.clip_contents = true
	art_shell.add_theme_stylebox_override("panel", _image_panel_style())
	var art := TextureRect.new()
	art.texture = LOBBY_BANNER_TEXTURE
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_shell.add_child(art)
	lobby_stack.add_child(art_shell)
	lobby_stack.move_child(art_shell, 1)


func _image_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.045, 0.065, 1.0)
	style.border_color = Color(0.32, 0.45, 0.58, 0.52)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	return style


func bind_player(new_player) -> void:
	player = new_player


func set_lobby_mode(is_lobby: bool) -> void:
	lobby_panel.visible = is_lobby
	health_panel.visible = not is_lobby
	if _ability_panel != null:
		_ability_panel.visible = not is_lobby
	crosshair.visible = not is_lobby
	charge_panel.visible = not is_lobby
	timer_label.visible = not is_lobby
	scoreboard.visible = not is_lobby and _duel_mode
	if _coin_chip != null:
		_coin_chip.visible = is_lobby
	if _quest_panel != null:
		_quest_panel.visible = is_lobby
	if not is_lobby and _shop_overlay != null:
		_shop_overlay.visible = false
	if is_lobby:
		announcement.visible = false
		round_banner.visible = false
		hide_victory()


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
	timer_label.visible = false
	scoreboard.visible = false
	round_banner.visible = false


func set_duel_mode(enabled: bool) -> void:
	_duel_mode = enabled
	scoreboard.visible = enabled and not lobby_panel.visible


func set_duel_score(red_score: int, blue_score: int, scoring_team := -1) -> void:
	red_score_value.text = "RED  %d" % red_score
	blue_score_value.text = "BLUE  %d" % blue_score
	if scoring_team == 0:
		_pulse_score_panel(red_score_panel)
	elif scoring_team == 1:
		_pulse_score_panel(blue_score_panel)


func show_round_banner(message: String, color: Color) -> void:
	_round_banner_style.bg_color = Color(color.r * 0.76, color.g * 0.76, color.b * 0.76, 0.97)
	_round_banner_style.border_color = color.lightened(0.32)
	round_banner_label.text = message
	round_banner.visible = true
	round_banner.modulate = Color(1, 1, 1, 0)
	round_banner.scale = Vector2(0.86, 0.86)
	round_banner.pivot_offset = round_banner.size * 0.5
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	tween.tween_property(round_banner, "modulate:a", 1.0, 0.18)
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
	status_label.text = message
	host_button.disabled = loading
	join_button.disabled = loading
	practice_button.disabled = loading
	name_input.editable = not loading
	address_input.editable = not loading
	map_picker.disabled = loading
	for child in color_swatches.get_children():
		var button := child as Button
		if button != null:
			button.disabled = loading


func get_player_name() -> String:
	var clean_name := name_input.text.strip_edges()
	return clean_name if not clean_name.is_empty() else "Player"


func get_player_color() -> Color:
	return BLOB_COLORS[_selected_color_index]


func get_host_address() -> String:
	var clean_address := address_input.text.strip_edges()
	return clean_address if not clean_address.is_empty() else "127.0.0.1"


func get_selected_map_id() -> String:
	if map_picker.selected < 0:
		return "neon_arcade"
	return str(map_picker.get_item_metadata(map_picker.selected))


func show_hit_marker() -> void:
	_hit_marker_time = 0.18
	hit_marker.visible = true
	hit_marker.pivot_offset = hit_marker.size * 0.5
	hit_marker.scale = Vector2(0.62, 0.62)
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


func apply_crosshair_settings(settings: Dictionary) -> void:
	if crosshair.has_method("apply_settings"):
		crosshair.call("apply_settings", settings)


func show_victory(is_winner: bool, winning_team: int, players: Array) -> void:
	var team_color := Color(0.94, 0.12, 0.18) if winning_team == 0 else Color(0.06, 0.42, 0.96)
	result_label.text = "YOU WIN!" if is_winner else "Better luck next time..."
	result_label.add_theme_color_override("font_color", Color.WHITE if is_winner else Color(0.9, 0.93, 0.98))
	var result_style := result_banner.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	result_style.bg_color = Color(team_color.r * 0.64, team_color.g * 0.64, team_color.b * 0.64, 0.97) if is_winner else Color(0.055, 0.065, 0.085, 0.97)
	result_style.border_color = team_color.lightened(0.28) if is_winner else Color(0.38, 0.44, 0.52)
	result_banner.add_theme_stylebox_override("panel", result_style)
	victory_overlay.visible = true
	victory_overlay.modulate.a = 0.0
	result_banner.scale = Vector2(0.82, 0.82)
	result_banner.pivot_offset = result_banner.size * 0.5
	roster_panel.visible = false
	stats_panel.visible = false
	_build_roster(players)
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	tween.tween_property(victory_overlay, "modulate:a", 1.0, 0.35)
	tween.tween_property(result_banner, "scale", Vector2.ONE, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.set_parallel(false)
	tween.tween_interval(1.25)
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
		var row := Label.new()
		row.text = "%s                                      +%d" % [str(entry.get("label", "Reward")), int(entry.get("amount", 0))]
		row.add_theme_font_size_override("font_size", 16)
		row.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
		row.modulate.a = 0.0
		rows.add_child(row)
		var reveal := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		reveal.tween_interval(0.35 + index * 0.24)
		reveal.tween_property(row, "modulate:a", 1.0, 0.18)
	var total := Label.new()
	var total_amount := int(reward.get("total", 0))
	total.text = "TOTAL                                      +0  COINS"
	total.add_theme_font_size_override("font_size", 19)
	total.add_theme_color_override("font_color", Color(1.0, 0.79, 0.2))
	total.modulate.a = 0.0
	rows.add_child(total)
	var total_tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	total_tween.tween_interval(0.65 + breakdown.size() * 0.24)
	total_tween.tween_property(total, "modulate:a", 1.0, 0.14)
	total_tween.tween_method(func(value: float) -> void: total.text = "TOTAL                                      +%d  COINS" % int(round(value)), 0.0, float(total_amount), 0.58).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_reward_panel.visible = true
	_reward_panel.modulate.a = 0.0
	var panel_tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	panel_tween.tween_interval(0.72)
	panel_tween.tween_property(_reward_panel, "modulate:a", 1.0, 0.24)


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
	_create_lobby_progression_actions()
	_create_shop_overlay()
	_create_reward_panel()


func _create_coin_chip() -> void:
	_coin_chip = PanelContainer.new()
	_coin_chip.name = "CoinBalance"
	_coin_chip.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_coin_chip.position = Vector2(-165, 24)
	_coin_chip.size = Vector2(135, 50)
	_coin_chip.add_theme_stylebox_override("panel", _elevated_panel_style(Color(0.055, 0.065, 0.105, 0.94), Color(1.0, 0.72, 0.16, 0.8), 16, Color(1.0, 0.64, 0.12, 0.26)))
	add_child(_coin_chip)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	_coin_chip.add_child(row)
	_coin_icon = TextureRect.new()
	_coin_icon.texture = COIN_TEXTURE
	_coin_icon.custom_minimum_size = Vector2(32, 32)
	_coin_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_coin_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(_coin_icon)
	_coin_balance_label = Label.new()
	_coin_balance_label.add_theme_font_size_override("font_size", 20)
	_coin_balance_label.add_theme_color_override("font_color", Color(1.0, 0.83, 0.3))
	row.add_child(_coin_balance_label)
	_update_coin_label()


func _create_lobby_progression_actions() -> void:
	var actions := HBoxContainer.new()
	actions.name = "ProgressionActions"
	actions.custom_minimum_size = Vector2(0, 48)
	actions.add_theme_constant_override("separation", 10)
	var shop_button := Button.new()
	shop_button.text = "SHOP"
	shop_button.tooltip_text = "Browse cosmetics and balanced abilities"
	shop_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_button.add_theme_font_size_override("font_size", 16)
	shop_button.add_theme_stylebox_override("normal", _panel_style(Color(0.14, 0.28, 0.58, 0.98), Color(0.4, 0.78, 1.0), 12))
	shop_button.add_theme_stylebox_override("hover", _panel_style(Color(0.2, 0.4, 0.78, 1.0), Color(0.66, 0.9, 1.0), 12))
	shop_button.pressed.connect(func() -> void: _set_progression_open("shop"))
	actions.add_child(shop_button)
	var quests_button := Button.new()
	quests_button.text = "QUESTS"
	quests_button.tooltip_text = "Track daily and weekly rewards"
	quests_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quests_button.add_theme_font_size_override("font_size", 16)
	quests_button.add_theme_stylebox_override("normal", _panel_style(Color(0.115, 0.16, 0.25, 0.98), Color(0.42, 0.53, 0.73), 12))
	quests_button.add_theme_stylebox_override("hover", _panel_style(Color(0.18, 0.25, 0.39, 1.0), Color(0.62, 0.76, 0.98), 12))
	quests_button.pressed.connect(func() -> void: _set_progression_open("quests"))
	actions.add_child(quests_button)
	lobby_stack.add_child(actions)
	lobby_stack.move_child(actions, 3)


func _create_quest_panel() -> void:
	_quest_panel = PanelContainer.new()
	_quest_panel.name = "QuestPanel"
	_quest_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_quest_panel.position = Vector2(-328, 96)
	_quest_panel.size = Vector2(298, 188)
	_quest_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.035, 0.05, 0.09, 0.94), Color(0.24, 0.6, 0.83), 12))
	add_child(_quest_panel)
	_refresh_quest_panel()


func _refresh_quest_panel() -> void:
	if _quest_panel == null or _progression == null:
		return
	for child in _quest_panel.get_children():
		child.queue_free()
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	_quest_panel.add_child(stack)
	var title := Label.new()
	title.text = "DAILY QUESTS  •  75 COINS EACH"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(0.5, 0.86, 1.0))
	stack.add_child(title)
	for quest_value in _progression.get("daily_quests") as Array:
		var quest := quest_value as Dictionary
		var label := Label.new()
		var done := bool(quest.get("claimed", false))
		label.text = ("✓ " if done else "• ") + "%s  %d / %d" % [str(quest.get("title", "Quest")), int(quest.get("progress", 0)), int(quest.get("target", 1))]
		label.add_theme_font_size_override("font_size", 13)
		label.add_theme_color_override("font_color", Color(0.35, 0.94, 0.54) if done else Color(0.86, 0.91, 1.0))
		stack.add_child(label)


func _create_shop_overlay() -> void:
	_shop_overlay = Control.new()
	_shop_overlay.name = "ShopOverlay"
	_shop_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shop_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_shop_overlay.visible = false
	add_child(_shop_overlay)
	var shade := TextureRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.43, 1.0])
	gradient.colors = PackedColorArray([Color(0.02, 0.045, 0.13, 0.985), Color(0.10, 0.055, 0.21, 0.97), Color(0.035, 0.09, 0.19, 0.985)])
	var gradient_texture := GradientTexture2D.new()
	gradient_texture.gradient = gradient
	gradient_texture.fill_from = Vector2(0.0, 0.0)
	gradient_texture.fill_to = Vector2(1.0, 1.0)
	gradient_texture.width = 1280
	gradient_texture.height = 720
	shade.texture = gradient_texture
	_shop_overlay.add_child(shade)
	for index in range(18):
		var particle := ColorRect.new()
		particle.color = Color(0.35 + 0.03 * (index % 3), 0.62, 1.0, 0.07 + 0.01 * (index % 4)) if index % 2 == 0 else Color(0.8, 0.38, 1.0, 0.06 + 0.01 * (index % 4))
		particle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		particle.position = Vector2(45 + (index * 97) % 1130, 36 + (index * 151) % 640)
		particle.size = Vector2(2 + (index % 3), 2 + (index % 3))
		_shop_overlay.add_child(particle)
	var shell := PanelContainer.new()
	shell.set_anchors_preset(Control.PRESET_CENTER)
	shell.position = Vector2(-540, -320)
	shell.size = Vector2(1080, 640)
	shell.add_theme_stylebox_override("panel", _elevated_panel_style(Color(0.045, 0.06, 0.13, 0.98), Color(0.34, 0.55, 0.88), 20, Color(0.22, 0.46, 1.0, 0.24)))
	_shop_overlay.add_child(shell)
	_shop_content = VBoxContainer.new()
	_shop_content.add_theme_constant_override("separation", 12)
	shell.add_child(_shop_content)


func _set_progression_open(page: String) -> void:
	if _shop_overlay == null:
		return
	_active_progression_page = page
	_shop_overlay.visible = true
	_build_progression()
	get_tree().paused = false


func _set_shop_open(open: bool) -> void:
	if open:
		_set_progression_open("shop")
	elif _shop_overlay != null:
		_shop_overlay.visible = false


func _build_shop(active_category: String) -> void:
	_active_progression_page = "shop"
	_active_shop_category = active_category
	_build_progression()


func _build_progression() -> void:
	for child in _shop_content.get_children():
		child.queue_free()
	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, 54)
	_shop_content.add_child(header)
	var back := Button.new()
	back.text = "‹  LOBBY"
	back.custom_minimum_size = Vector2(102, 44)
	back.pressed.connect(func() -> void: _set_shop_open(false))
	header.add_child(back)
	var title := Label.new()
	title.text = "BLOB SHOP" if _active_progression_page == "shop" else "QUEST BOARD"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 27)
	title.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0))
	header.add_child(title)
	var balance := Label.new()
	balance.text = "%s   •   BLOB COINS  %d" % [name_input.text if not name_input.text.is_empty() else "PLAYER", int(_progression.call("get_balance"))]
	balance.add_theme_font_size_override("font_size", 17)
	balance.add_theme_color_override("font_color", Color(1.0, 0.8, 0.26))
	header.add_child(balance)
	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 1)
	divider.color = Color(0.28, 0.38, 0.58, 0.65)
	_shop_content.add_child(divider)
	if _active_progression_page == "quests":
		_build_quest_board()
		return
	_build_shop_workspace()


func _build_shop_workspace() -> void:
	var workspace := HBoxContainer.new()
	workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace.add_theme_constant_override("separation", 16)
	_shop_content.add_child(workspace)
	var navigation := VBoxContainer.new()
	navigation.custom_minimum_size = Vector2(168, 0)
	navigation.add_theme_constant_override("separation", 8)
	workspace.add_child(navigation)
	var nav_title := Label.new()
	nav_title.text = "CATEGORIES"
	nav_title.add_theme_font_size_override("font_size", 12)
	nav_title.add_theme_color_override("font_color", Color(0.5, 0.64, 0.86))
	navigation.add_child(nav_title)
	var labels := {"abilities": "⚡  Abilities", "skins": "🫧  Skins", "trails": "🌈  Trails", "kill_effects": "💥  Effects", "faces": "😀  Faces"}
	for category in labels:
		var tab := Button.new()
		tab.text = str(labels[category])
		tab.alignment = HORIZONTAL_ALIGNMENT_LEFT
		tab.custom_minimum_size = Vector2(0, 46)
		tab.button_pressed = category == _active_shop_category
		tab.toggle_mode = true
		tab.add_theme_stylebox_override("normal", _panel_style(Color(0.11, 0.14, 0.23) if category == _active_shop_category else Color(0.055, 0.07, 0.13), Color(0.36, 0.65, 1.0) if category == _active_shop_category else Color(0.18, 0.26, 0.4), 10))
		tab.pressed.connect(_build_shop.bind(str(category)))
		navigation.add_child(tab)
	var quest_link := Button.new()
	quest_link.text = "✓  Daily quests"
	quest_link.alignment = HORIZONTAL_ALIGNMENT_LEFT
	quest_link.custom_minimum_size = Vector2(0, 44)
	quest_link.pressed.connect(_set_progression_open.bind("quests"))
	navigation.add_child(quest_link)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(575, 0)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	workspace.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 3
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
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(174, 188)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.pivot_offset = Vector2(87, 94)
	var selected := str(item.get("id", "")) == str(_selected_shop_item.get("id", ""))
	var item_id := str(item.get("id", ""))
	var owned := bool(_progression.call("is_owned", item_id))
	var equipped := str(_progression.call("get_equipped", category)) == item_id
	var affordable := owned or int(_progression.call("get_balance")) >= int(item.get("price", 0))
	var base_color := Color(0.1, 0.13, 0.22) if selected else Color(0.065, 0.08, 0.13)
	if not affordable:
		base_color = base_color.darkened(0.42)
	card.add_theme_stylebox_override("panel", _elevated_panel_style(base_color, rarity_colors.get(rarity, Color.WHITE).darkened(0.38) if not affordable else rarity_colors.get(rarity, Color.WHITE), 14, rarity_colors.get(rarity, Color.WHITE) if selected else Color.TRANSPARENT))
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 4)
	card.add_child(stack)
	var thumbnail := Control.new()
	thumbnail.custom_minimum_size = Vector2(0, 70)
	thumbnail.set_script(SHOP_BLOB_PREVIEW_SCRIPT)
	thumbnail.call("set_item", category, item, rarity_colors.get(rarity, Color.WHITE))
	thumbnail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(thumbnail)
	var name_label := Label.new()
	name_label.text = str(item.get("name", "Item"))
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(name_label)
	var details := HBoxContainer.new()
	details.alignment = BoxContainer.ALIGNMENT_CENTER
	var rarity_label := Label.new()
	rarity_label.text = rarity.to_upper()
	rarity_label.add_theme_font_size_override("font_size", 11)
	rarity_label.add_theme_color_override("font_color", rarity_colors.get(rarity, Color.WHITE).darkened(0.32) if not affordable else rarity_colors.get(rarity, Color.WHITE))
	details.add_child(rarity_label)
	var status := Label.new()
	status.text = "  •  EQUIPPED" if equipped else ("  •  OWNED" if owned else ("  •  LOCKED" if not affordable else ""))
	status.add_theme_font_size_override("font_size", 10)
	status.add_theme_color_override("font_color", Color(0.4, 1.0, 0.61) if owned else Color(1.0, 0.45, 0.48))
	details.add_child(status)
	stack.add_child(details)
	var inspect := Button.new()
	inspect.text = "SELECT  •  %d 🪙" % int(item.get("price", 0))
	inspect.tooltip_text = "Not enough Coins" if not affordable else "Inspect %s" % str(item.get("name", "item"))
	inspect.pressed.connect(_select_shop_item.bind(item.duplicate(true)))
	inspect.mouse_entered.connect(_animate_shop_card.bind(card, true))
	inspect.mouse_exited.connect(_animate_shop_card.bind(card, false))
	stack.add_child(inspect)
	return card


func _make_preview_panel(category: String, item: Dictionary) -> PanelContainer:
	var rarity := str(item.get("rarity", "Common"))
	var colors := {"Common": Color(0.55, 0.6, 0.66), "Rare": Color(0.22, 0.58, 1.0), "Epic": Color(0.68, 0.34, 1.0), "Legendary": Color(1.0, 0.72, 0.16), "Basic": Color(0.32, 0.9, 0.46), "Advanced": Color(0.22, 0.58, 1.0), "Expert": Color(0.68, 0.34, 1.0)}
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(260, 0)
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.065, 0.08, 0.15), colors.get(rarity, Color.WHITE), 16))
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 12)
	panel.add_child(stack)
	var preview := Control.new()
	preview.custom_minimum_size = Vector2(0, 154)
	preview.set_script(SHOP_BLOB_PREVIEW_SCRIPT)
	preview.call("set_item", category, item, colors.get(rarity, Color.WHITE))
	stack.add_child(preview)
	var preview_hint := Label.new()
	preview_hint.text = "LIVE PREVIEW  •  IDLE DISPLAY"
	preview_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_hint.add_theme_font_size_override("font_size", 10)
	preview_hint.add_theme_color_override("font_color", Color(0.46, 0.64, 0.88))
	stack.add_child(preview_hint)
	var name_label := Label.new()
	name_label.text = str(item.get("name", "Select an item"))
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_label.add_theme_font_size_override("font_size", 22)
	stack.add_child(name_label)
	var rarity_label := Label.new()
	rarity_label.text = rarity.to_upper()
	rarity_label.add_theme_font_size_override("font_size", 13)
	rarity_label.add_theme_color_override("font_color", colors.get(rarity, Color.WHITE))
	stack.add_child(rarity_label)
	var description := Label.new()
	description.text = str(item.get("description", "A cosmetic that makes your Blob unmistakable."))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_size_override("font_size", 13)
	description.add_theme_color_override("font_color", Color(0.7, 0.78, 0.9))
	stack.add_child(description)
	var item_id := str(item.get("id", ""))
	var owned := bool(_progression.call("is_owned", item_id))
	var equipped := str(_progression.call("get_equipped", category)) == item_id
	var action := Button.new()
	action.custom_minimum_size = Vector2(0, 48)
	action.text = "✓ EQUIPPED" if equipped else ("EQUIP NOW" if owned else "BUY FOR  %d COINS" % int(item.get("price", 0)))
	action.disabled = not owned and int(_progression.call("get_balance")) < int(item.get("price", 0))
	action.tooltip_text = "Not enough Coins" if action.disabled else ""
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
	modal.add_child(shade)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-190, -132)
	panel.size = Vector2(380, 264)
	panel.scale = Vector2(0.92, 0.92)
	panel.pivot_offset = panel.size * 0.5
	panel.add_theme_stylebox_override("panel", _elevated_panel_style(Color(0.065, 0.085, 0.16, 0.99), Color(1.0, 0.72, 0.18), 20, Color(1.0, 0.62, 0.12, 0.34)))
	modal.add_child(panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 12)
	panel.add_child(stack)
	var title := Label.new()
	title.text = "PURCHASE ITEM?"
	title.add_theme_font_size_override("font_size", 22)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(title)
	var preview := Control.new()
	preview.custom_minimum_size = Vector2(0, 72)
	preview.set_script(SHOP_BLOB_PREVIEW_SCRIPT)
	preview.call("set_item", category, item, Color(1.0, 0.72, 0.18))
	stack.add_child(preview)
	var description := Label.new()
	description.text = "%s\n%d BLOB COINS" % [str(item.get("name", "Item")), int(item.get("price", 0))]
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.add_theme_font_size_override("font_size", 16)
	description.add_theme_color_override("font_color", Color(1.0, 0.83, 0.32))
	stack.add_child(description)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 12)
	stack.add_child(actions)
	var cancel := Button.new()
	cancel.text = "CANCEL"
	cancel.custom_minimum_size = Vector2(124, 42)
	cancel.pressed.connect(modal.queue_free)
	actions.add_child(cancel)
	var confirm := Button.new()
	confirm.text = "BUY NOW"
	confirm.custom_minimum_size = Vector2(124, 42)
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
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(panel, "modulate:a", 1.0, 0.16)


func _build_quest_board() -> void:
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
	subtitle.text = "Daily quests refresh every day" if not _quests_showing_weekly else "Weekly quests refresh every week"
	subtitle.add_theme_color_override("font_color", Color(0.57, 0.69, 0.9))
	_shop_content.add_child(subtitle)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 12)
	_shop_content.add_child(list)
	var quests: Array = (_progression.get("weekly_quests") as Array) if _quests_showing_weekly else (_progression.get("daily_quests") as Array)
	for quest_value in quests:
		var quest := quest_value as Dictionary
		var claimed := bool(quest.get("claimed", false))
		var completed := bool(quest.get("completed", false)) or claimed
		var target := maxi(1, int(quest.get("target", 1)))
		var progress := mini(target, int(quest.get("progress", 0)))
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(0, 94)
		var quest_color := Color(0.38, 1.0, 0.6) if claimed else (Color(1.0, 0.7, 0.18) if completed else (Color(0.4, 0.54, 1.0) if _quests_showing_weekly else Color(0.25, 0.68, 1.0)))
		card.add_theme_stylebox_override("panel", _elevated_panel_style(Color(0.08, 0.1, 0.17), quest_color, 14, Color(quest_color.r, quest_color.g, quest_color.b, 0.18)))
		var stack := VBoxContainer.new()
		stack.add_theme_constant_override("separation", 6)
		card.add_child(stack)
		var row := HBoxContainer.new()
		stack.add_child(row)
		var text := Label.new()
		text.text = ("✓  " if claimed else ("★  " if completed else "◌  ")) + str(quest.get("title", "Quest"))
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		text.add_theme_font_size_override("font_size", 17)
		row.add_child(text)
		var reward := Button.new()
		reward.text = "✓ COMPLETED" if claimed else ("CLAIM  +%d 🪙" % int(quest.get("reward", 0)) if completed else "+%d 🪙" % int(quest.get("reward", 0)))
		reward.disabled = not completed or claimed
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
		progress_label.text = "COMPLETED" if claimed else ("READY TO CLAIM" if completed else "%d / %d" % [progress, target])
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
	_reward_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_reward_panel.position = Vector2(-260, -372)
	_reward_panel.size = Vector2(520, 340)
	_reward_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.04, 0.055, 0.09, 0.98), Color(1.0, 0.68, 0.18), 14))
	victory_overlay.add_child(_reward_panel)
	var stack := VBoxContainer.new()
	stack.name = "Stack"
	_reward_panel.add_child(stack)
	var title := Label.new()
	title.name = "Header"
	title.text = "MATCH REWARDS"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(1.0, 0.8, 0.25))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(title)
	var rows := VBoxContainer.new()
	rows.name = "Rows"
	rows.add_theme_constant_override("separation", 4)
	stack.add_child(rows)


func _on_coin_balance_changed(balance: int, delta: int) -> void:
	_coin_target_balance = balance
	_pulse_coin_chip(delta > 0)
	if delta > 0 and lobby_panel.visible:
		_show_coin_earn(delta)
	_refresh_quest_panel()


func _on_quest_completed(quest: Dictionary, _reward: int) -> void:
	show_announcement("QUEST COMPLETE!  %s" % str(quest.get("title", "")), Color(0.35, 1.0, 0.56))
	_show_progression_toast("QUEST COMPLETE", str(quest.get("title", "")))


func _show_progression_toast(title: String, detail: String) -> void:
	if _shop_overlay == null or not _shop_overlay.visible:
		return
	var toast := PanelContainer.new()
	toast.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	toast.position = Vector2(-330, 36)
	toast.size = Vector2(290, 70)
	toast.modulate.a = 0.0
	toast.add_theme_stylebox_override("panel", _panel_style(Color(0.08, 0.15, 0.18, 0.98), Color(0.32, 0.95, 0.61), 14))
	_shop_overlay.add_child(toast)
	var label := Label.new()
	label.text = "%s\n%s" % [title, detail]
	label.add_theme_font_size_override("font_size", 14)
	toast.add_child(label)
	var tween := create_tween()
	tween.tween_property(toast, "modulate:a", 1.0, 0.16)
	tween.tween_interval(2.6)
	tween.tween_property(toast, "modulate:a", 0.0, 0.18)
	tween.tween_callback(toast.queue_free)


func _show_coin_earn(amount: int) -> void:
	var floating := Label.new()
	floating.text = "+%d COINS" % amount
	floating.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	floating.position = Vector2(-210, 86)
	floating.add_theme_font_size_override("font_size", 21)
	floating.add_theme_color_override("font_color", Color(1.0, 0.82, 0.25))
	add_child(floating)
	var primary_coin := TextureRect.new()
	primary_coin.texture = COIN_TEXTURE
	primary_coin.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	primary_coin.position = Vector2(-210, 80)
	primary_coin.size = Vector2(30, 30)
	primary_coin.pivot_offset = Vector2(15, 15)
	primary_coin.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	primary_coin.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
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
		var particle := TextureRect.new()
		particle.texture = COIN_TEXTURE
		particle.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		particle.position = Vector2(-142, 92)
		particle.size = Vector2(20, 20)
		particle.pivot_offset = Vector2(10, 10)
		particle.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		particle.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
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
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(card, "scale", Vector2(1.045, 1.045) if hovered else Vector2.ONE, 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "position:y", -4.0 if hovered else 0.0, 0.13).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


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
	roster_panel.modulate.a = 0.0
	roster_panel.position.x += 36.0
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	tween.tween_property(roster_panel, "modulate:a", 1.0, 0.24)
	tween.tween_property(roster_panel, "position:x", roster_panel.position.x - 36.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _build_roster(players: Array) -> void:
	for child in roster_players.get_children():
		child.queue_free()
	for entry_value in players:
		var entry := entry_value as Dictionary
		var blob_tint: Color = entry.get("color", Color.WHITE)
		var team_tint: Color = entry.get("team_color", Color.WHITE)
		var button := Button.new()
		button.custom_minimum_size = Vector2(0, 68)
		button.focus_mode = Control.FOCUS_NONE
		button.text = ""
		button.add_theme_stylebox_override("normal", _roster_button_style(false))
		button.add_theme_stylebox_override("hover", _roster_button_style(true))
		button.add_theme_stylebox_override("pressed", _roster_button_style(true))
		var avatar := Control.new()
		avatar.set_script(BLOB_AVATAR_SCRIPT)
		avatar.position = Vector2(10, 7)
		avatar.size = Vector2(54, 54)
		avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		avatar.call("set_color", blob_tint)
		button.add_child(avatar)
		var label := Label.new()
		label.position = Vector2(76, 8)
		label.size = Vector2(210, 52)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.text = "%s\n%s TEAM" % [str(entry.get("name", "Player")), str(entry.get("team_name", "RED"))]
		label.add_theme_font_size_override("font_size", 17)
		label.add_theme_color_override("font_color", team_tint)
		button.add_child(label)
		button.pressed.connect(_open_stats.bind(entry))
		roster_players.add_child(button)


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


func _configure_color_swatches() -> void:
	for index in range(BLOB_COLORS.size()):
		var button := Button.new()
		button.name = "Color_%d" % index
		button.custom_minimum_size = Vector2(34, 34)
		button.toggle_mode = true
		button.tooltip_text = COLOR_NAMES[index]
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_stylebox_override("normal", _swatch_style(BLOB_COLORS[index], false, false))
		button.add_theme_stylebox_override("hover", _swatch_style(BLOB_COLORS[index], true, false))
		button.add_theme_stylebox_override("pressed", _swatch_style(BLOB_COLORS[index], false, true))
		button.add_theme_stylebox_override("disabled", _swatch_style(BLOB_COLORS[index].darkened(0.45), false, false))
		button.pressed.connect(_select_color.bind(index))
		color_swatches.add_child(button)
	_update_swatch_selection()


func _configure_map_picker() -> void:
	map_picker.clear()
	for map_entry in COMPETITIVE_MAPS:
		map_picker.add_item(str(map_entry[1]))
		map_picker.set_item_metadata(map_picker.item_count - 1, str(map_entry[0]))
	map_picker.select(0)


func _swatch_style(color: Color, hovered: bool, selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color.lightened(0.12) if hovered else color
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_right = 8
	style.corner_radius_bottom_left = 8
	style.border_width_left = 3 if selected else 1
	style.border_width_top = 3 if selected else 1
	style.border_width_right = 3 if selected else 1
	style.border_width_bottom = 3 if selected else 1
	style.border_color = Color(0.98, 1.0, 1.0, 1.0) if selected else Color(0.04, 0.06, 0.09, 0.82)
	return style


func _select_color(index: int) -> void:
	_selected_color_index = clampi(index, 0, BLOB_COLORS.size() - 1)
	_update_swatch_selection()
	_emit_identity()


func _update_swatch_selection() -> void:
	for index in range(color_swatches.get_child_count()):
		var button := color_swatches.get_child(index) as Button
		if button == null:
			continue
		var selected := index == _selected_color_index
		button.set_pressed_no_signal(selected)
		button.add_theme_stylebox_override("normal", _swatch_style(BLOB_COLORS[index], false, selected))


func _emit_identity() -> void:
	identity_changed.emit(get_player_name(), get_player_color())


func _process(delta: float) -> void:
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
	charge_value.text = "FLING  %d%%" % int(round(charge_ratio * 100.0))
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


func set_camera_mode(_is_third_person: bool) -> void:
	pass
