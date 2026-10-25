class_name DuelHud
extends CanvasLayer

const BLOB_AVATAR_SCRIPT := preload("res://scripts/blob_avatar.gd")
const COIN_ICON_SCRIPT := preload("res://scripts/ui/coin_icon.gd")
const SHOP_CARD_PREVIEW_SCRIPT := preload("res://scripts/shop_blob_preview.gd")
const SHOP_MODEL_PREVIEW_SCRIPT := preload("res://scripts/ui/shop_model_preview.gd")
const UI_TOKENS := preload("res://scripts/ui/ui_tokens.gd")
const HOTBAR_HUD := preload("res://scripts/ui/hotbar_hud.gd")
const MATCH_BAR := preload("res://scripts/ui/match_bar.gd")
const HEALTH_PILL := preload("res://scripts/ui/health_pill.gd")
const FLING_METER := preload("res://scripts/ui/fling_meter.gd")
const MAIN_MENU := preload("res://scripts/ui/main_menu.gd")
const ABILITY_HUD_SCRIPT := preload("res://scripts/ui/ability_hud.gd")
const MENU_CARD := preload("res://scripts/ui/menu_card.gd")
const MENU_SEGMENTED := preload("res://scripts/ui/menu_segmented.gd")
const PROGRESS_RING := preload("res://scripts/ui/progress_ring.gd")
const PROGRESSION_FX := preload("res://scripts/ui/progression_fx.gd")
const VICTORY_FX := preload("res://scripts/ui/victory_fx.gd")
## Round result kinds for show_round_result, from the local player's view.
const ROUND_RESULT_DRAW := MATCH_BAR.RESULT_DRAW
const ROUND_RESULT_WON := MATCH_BAR.RESULT_WON
const ROUND_RESULT_LOST := MATCH_BAR.RESULT_LOST
## Chunky rounded display face for the big in-match numbers (scores, timer,
## health), falling back through heavy system faces on other platforms.
const DISPLAY_FONT_NAMES := ["SF Pro Rounded", "Arial Rounded MT Bold", "Nunito", "Varela Round", "Segoe UI Black", "Arial Black", "Helvetica Neue"]
## Health pill in the bottom-left corner: big and very rounded.
const HEALTH_PILL_SIZE := Vector2(420, 64)
const FLING_METER_SIZE := Vector2(280, 36)
const FLING_METER_GAP := 10.0
const HUD_EDGE_MARGIN := 28.0
const NETWORK_TUNING := preload("res://scripts/net/network_tuning.gd")
const DUEL_FEEDBACK_SCRIPT := preload("res://scripts/ui/duel_feedback.gd")

signal host_requested
signal join_requested(room_code: String)
signal practice_requested
signal identity_changed(display_name: String, color: Color)
signal settings_requested
signal return_to_lobby_requested
signal rematch_requested
## Lobby asked for an offline duel against the bot at this difficulty.
signal bot_requested(difficulty: int)
## Host changed first-to or round length in the host menu.
signal match_format_changed(score_to_win: int, round_seconds: float)

const SCORE_TO_WIN := 5
# Hit-marker variants: colour, the scale the marker pops to, and how long it
# lingers. Eliminations and ability hits must read heavier than a plain hit.
const HIT_MARKER_VARIANTS := {
	"hit": {"color": Color(1.0, 0.72, 0.18), "scale": 1.0, "duration": 0.18},
	"ricochet": {"color": Color(1.0, 0.52, 0.12), "scale": 1.18, "duration": 0.26},
	"rail": {"color": Color(0.56, 0.95, 1.0), "scale": 1.32, "duration": 0.32},
	"elimination": {"color": Color(1.0, 0.24, 0.26), "scale": 1.6, "duration": 0.5},
}
const REWARD_QUEST_TICK_LIMIT := 2
const RARITY_COLORS := {"Common": Color(0.55, 0.6, 0.66), "Rare": Color(0.22, 0.58, 1.0), "Epic": Color(0.68, 0.34, 1.0), "Legendary": Color(1.0, 0.72, 0.16), "Basic": Color(0.32, 0.9, 0.46), "Advanced": Color(0.22, 0.58, 1.0), "Expert": Color(0.68, 0.34, 1.0)}
## TEAM 0 is presented as the Orange team.
const TEAM_RED_COLOR := Color(1.0, 0.5, 0.08, 1.0)
const TEAM_BLUE_ACCENT := Color(0.18, 0.55, 1.0)
const DEFEAT_ACCENT := Color(0.42, 0.5, 0.64)
## Results screen widths; _layout_victory scales the columns to fit.
const VICTORY_BANNER_WIDTH := 560.0
const VICTORY_ROSTER_WIDTH := 360.0
const VICTORY_REWARDS_WIDTH := 440.0
const TEAM_BLUE_COLOR := Color(0.02, 0.82, 1.0, 1.0)

const BLOB_COLORS := [
	Color(0.02, 0.86, 1.0),
	Color(1.0, 0.28, 0.42),
	Color(1.0, 0.72, 0.12),
	Color(0.54, 0.34, 1.0),
	Color(0.34, 0.86, 0.3),
]
const COMPETITIVE_MAPS := [
	["skyline", "Arena"],
	["bounceground", "Bounceground"],
	["training_yard", "Training Yard"],
]
@onready var health_bar: ProgressBar = $HealthPanel/HealthBar
@onready var health_value: Label = $HealthPanel/HealthBar/HealthValue
@onready var health_panel: PanelContainer = $HealthPanel
@onready var crosshair: DuelCrosshair = $Crosshair
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

var player: BlobPlayer = null
var _shown_health := 150.0
var _fill_style := StyleBoxFlat.new()
var _charge_fill_style := StyleBoxFlat.new()
var _hit_marker_time := 0.0
var _damage_flash_time := 0.0
var _announcement_time := 0.0
var _announcement_tween: Tween
var _announcement_queue: Array[Dictionary] = []
var _last_observed_health := -1
var _fps_label: Label = null
var _fps_accumulator := 0.0
var _duel_mode := false
var _practice_mode_active := false
var _lobby_mode_active := false
var _current_ability_id := ""
var _round_banner_style := StyleBoxFlat.new()
var _progression: Node
## Coins, the menu quest card, the Shop / Quest Board drawer and the toasts
## (scripts/ui/progression_drawer.gd). The HUD forwards open / close / toast.
## Both helpers type their back-reference as DuelHud, so they are reached
## through their class names: preloading them here would be a parse cycle.
var drawer: ProgressionDrawer
## Room codes and the ping readout (scripts/ui/network_status.gd).
var network_status: NetworkStatusHud
var _reward_panel: PanelContainer
var _selected_color_index := 0
## The full-screen pre-game menu, built in code (scripts/ui/main_menu.gd).
## The fields below are its controls; the HUD owns what they do.
var main_menu: MainMenu
var name_input: LineEdit
var code_input: LineEdit
var room_code: Label
var host_button: Button
var join_button: Button
var practice_button: Button
var bot_button: Button
var match_format_button: Button
## "host" or "join": which request the connection status describes.
var _last_connection_action := ""
var _timer_pulse_tween: Tween
var _round_display_number := 1
var _last_red_score := 0
var _last_blue_score := 0
var _last_timer_second := -1
var _health_shell_style: StyleBoxFlat
var _reduced_motion := false
var _ui_font: SystemFont
var _feedback: DuelFeedbackLayer
var _hit_marker_kind := "hit"
var _hit_marker_duration := 0.18
var _rematch_button: Button
## 1 Blaster / 2 Blob slot bar, left of the fling meter on the same row.
var _hotbar: HotbarHud
var _match_bar: MatchBar
var _health_pill: HealthPill
var _display_font: SystemFont
var _fling_meter: FlingMeter
var _fling_charge_ratio := 0.0
var _fling_cooldown_remaining := 0.0
var _fling_cooldown_duration := 3.0
@onready var _ability_panel: AbilityHud = $AbilityHUD


func _ready() -> void:
	_ui_font = SystemFont.new()
	_ui_font.font_names = PackedStringArray(["SF Pro Display", "Avenir Next", "Helvetica Neue", "Arial"])
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
	_display_font = SystemFont.new()
	_display_font.font_names = PackedStringArray(DISPLAY_FONT_NAMES)
	_display_font.font_weight = 850
	_create_match_bar()
	_create_health_pill()
	_create_fling_meter()
	_create_hotbar()
	announcement.add_theme_stylebox_override("normal", _announcement_style(Color(0.3, 0.9, 1.0)))
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
	_create_main_menu()
	_create_feedback_layer()
	_setup_progression_ui()
	_apply_ui_font_tree(self)
	main_menu.configure_fonts(_display_font)
	_create_victory_layout()
	get_viewport().size_changed.connect(_layout_victory)


func set_ability_state(ability_id: String, cooldown_remaining_msec: int, loaded: bool, active: bool, active_remaining_msec: int = 0, deployed: bool = false) -> void:
	if _ability_panel == null:
		return
	_current_ability_id = ability_id
	_ability_panel.set_ability_state(ability_id, cooldown_remaining_msec, loaded, active, active_remaining_msec, deployed)
	_ability_panel.visible = not main_menu.visible and not ability_id.is_empty()


func apply_ui_settings(settings: Dictionary) -> void:
	_reduced_motion = bool(settings.get("reduced_motion", false))
	if _feedback != null:
		_feedback.set_reduced_motion(_reduced_motion)
	if _ability_panel != null:
		_ability_panel.set_reduced_motion(_reduced_motion)
	main_menu.set_reduced_motion(_reduced_motion)
	PROGRESSION_FX.reduced_motion = _reduced_motion
	set_fps_counter_visible(bool(settings.get("show_fps", false)))


## Refreshed a few times a second rather than every frame: a Label text change
## forces a re-layout, and doing that 60+ times a second to display the frame
## rate would itself cost frames.
func _update_fps_counter(delta: float) -> void:
	if _fps_label == null or not _fps_label.visible:
		return
	_fps_accumulator += delta
	if _fps_accumulator < 0.25:
		return
	_fps_accumulator = 0.0
	var frames_per_second := Engine.get_frames_per_second()
	_fps_label.text = "%d FPS" % frames_per_second
	var readout_color := Color(0.62, 0.98, 0.76)
	if frames_per_second < 30:
		readout_color = Color(1.0, 0.42, 0.42)
	elif frames_per_second < 55:
		readout_color = Color(1.0, 0.82, 0.36)
	_fps_label.add_theme_color_override("font_color", readout_color)


## BUG-029: FPS readout, toggled from Settings. Built in code so it sits above
## every HUD page without having to be wired into each one, and left hidden (and
## not processing) until asked for.
func set_fps_counter_visible(enabled: bool) -> void:
	if enabled and _fps_label == null:
		_fps_label = Label.new()
		_fps_label.name = "FpsCounter"
		_fps_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		_fps_label.position = Vector2(-104.0, 8.0)
		_fps_label.custom_minimum_size = Vector2(96.0, 0.0)
		_fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fps_label.add_theme_font_size_override("font_size", 15)
		_fps_label.add_theme_color_override("font_color", Color(0.62, 0.98, 0.76))
		_fps_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
		_fps_label.add_theme_constant_override("outline_size", 5)
		_fps_label.z_index = 128
		add_child(_fps_label)
	if _fps_label != null:
		_fps_label.visible = enabled
		_fps_accumulator = 0.0


func bind_player(new_player: BlobPlayer) -> void:
	player = new_player
	if _hotbar != null:
		_hotbar.bind_player(new_player)


func get_hotbar() -> HotbarHud:
	return _hotbar


func _create_hotbar() -> void:
	_hotbar = HOTBAR_HUD.new()
	_hotbar.name = "Hotbar"
	add_child(_hotbar)
	# Bottom-right corner, where the health bar used to live. The ability
	# circle joins as the third item.
	_hotbar.anchor_left = 1.0
	_hotbar.anchor_right = 1.0
	_hotbar.anchor_top = 1.0
	_hotbar.anchor_bottom = 1.0
	_hotbar.offset_right = -HUD_EDGE_MARGIN
	_hotbar.offset_left = -HUD_EDGE_MARGIN
	_hotbar.offset_bottom = -HUD_EDGE_MARGIN
	_hotbar.offset_top = -HUD_EDGE_MARGIN
	_hotbar.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_hotbar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hotbar.attach_ability(_ability_panel)
	_hotbar.visible = false


func _create_match_bar() -> void:
	_match_bar = MATCH_BAR.new()
	_match_bar.setup(self, scoreboard as HBoxContainer, red_score_panel, red_score_value, blue_score_panel, blue_score_value, score_target_label.get_parent() as PanelContainer, score_target_label, timer_label, _display_font)
	_match_bar.set_scores(0, 0)


func _create_health_pill() -> void:
	# The old bar and its "150 / 150" label stay in the scene only as data
	# holders; the pill draws the health.
	health_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	health_bar.visible = false
	health_panel.anchor_left = 0.0
	health_panel.anchor_right = 0.0
	health_panel.anchor_top = 1.0
	health_panel.anchor_bottom = 1.0
	health_panel.offset_left = HUD_EDGE_MARGIN
	health_panel.offset_right = HUD_EDGE_MARGIN + HEALTH_PILL_SIZE.x
	health_panel.offset_bottom = -HUD_EDGE_MARGIN
	health_panel.offset_top = -HUD_EDGE_MARGIN - HEALTH_PILL_SIZE.y
	health_panel.grow_horizontal = Control.GROW_DIRECTION_END
	health_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_health_pill = HEALTH_PILL.new()
	_health_pill.name = "HealthPill"
	_health_pill.custom_minimum_size = HEALTH_PILL_SIZE
	_health_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_health_pill.set_display_font(_display_font, 36)
	health_panel.add_child(_health_pill)


## The fling rail sits just above the health pill. The old ChargeBar and the
## separate FlingCooldownPanel stay in the scene only as data holders.
func _create_fling_meter() -> void:
	charge_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	charge_bar.visible = false
	fling_cooldown_panel.visible = false
	charge_panel.anchor_left = 0.0
	charge_panel.anchor_right = 0.0
	charge_panel.anchor_top = 1.0
	charge_panel.anchor_bottom = 1.0
	charge_panel.offset_left = HUD_EDGE_MARGIN
	charge_panel.offset_right = HUD_EDGE_MARGIN + FLING_METER_SIZE.x
	charge_panel.offset_bottom = -HUD_EDGE_MARGIN - HEALTH_PILL_SIZE.y - FLING_METER_GAP
	charge_panel.offset_top = charge_panel.offset_bottom - FLING_METER_SIZE.y
	charge_panel.grow_horizontal = Control.GROW_DIRECTION_END
	charge_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_fling_meter = FLING_METER.new()
	_fling_meter.name = "FlingMeter"
	_fling_meter.custom_minimum_size = FLING_METER_SIZE
	_fling_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fling_meter.set_display_font(_display_font, 18)
	charge_panel.add_child(_fling_meter)


func get_fling_meter() -> FlingMeter:
	return _fling_meter


func get_health_pill() -> HealthPill:
	return _health_pill


func get_match_bar() -> MatchBar:
	return _match_bar


func set_lobby_mode(is_lobby: bool) -> void:
	var entering := is_lobby and not main_menu.visible
	_lobby_mode_active = is_lobby
	main_menu.visible = is_lobby
	health_panel.visible = not is_lobby
	if _ability_panel != null:
		_ability_panel.visible = not is_lobby and not _current_ability_id.is_empty()
	crosshair.visible = not is_lobby
	charge_panel.visible = not is_lobby
	if _hotbar != null:
		_hotbar.visible = not is_lobby
	timer_label.visible = not is_lobby and not _practice_mode_active
	scoreboard.visible = not is_lobby and _duel_mode and not _practice_mode_active
	if is_lobby:
		fling_cooldown_panel.visible = false
	if not is_lobby:
		drawer._hide_progression_now()
	if is_lobby:
		main_menu.modulate = Color.WHITE
		_refresh_menu_identity()
		drawer._refresh_quest_panel(entering)
		if entering:
			main_menu.play_intro()
		announcement.visible = false
		round_banner.visible = false
		hide_victory()
		if _feedback != null:
			_feedback.reset()


## Settings opened from the menu sit over it: the menu stays as the backdrop
## but dims and stops taking input until the pause panel closes.
func set_lobby_ui_suppressed(suppressed: bool) -> void:
	if not _lobby_mode_active:
		return
	main_menu.modulate = Color(0.55, 0.58, 0.66) if suppressed else Color.WHITE
	main_menu.process_mode = Node.PROCESS_MODE_DISABLED if suppressed else Node.PROCESS_MODE_INHERIT
	if suppressed:
		drawer._hide_progression_now()


## The camera's celebration beat before the results: gameplay HUD off,
## letterbox bars in, and the winner named. `winner_name` may be empty.
func begin_victory_cinematic(winner_name: String = "", accent: Color = TEAM_RED_COLOR, local_won: bool = true) -> void:
	_victory_cinematic_active = true
	if _victory_fx != null:
		_victory_fx.play_cinematic(winner_name, accent, local_won, _reduced_motion)
	health_panel.visible = false
	if _ability_panel != null:
		_ability_panel.visible = false
	crosshair.visible = false
	charge_panel.visible = false
	if _hotbar != null:
		_hotbar.visible = false
	fling_cooldown_panel.visible = false
	timer_label.visible = false
	scoreboard.visible = false
	round_banner.visible = false
	if _feedback != null:
		_feedback.reset()
	# Leftover countdown or match-flow callouts would sit on top of the
	# result card; quest news still arrives as toasts.
	_announcement_queue.clear()
	announcement.visible = false
	_announcement_time = 0.0


func set_duel_mode(enabled: bool) -> void:
	_duel_mode = enabled
	scoreboard.visible = enabled and not main_menu.visible and not _practice_mode_active
	timer_label.visible = not main_menu.visible and not _practice_mode_active


func set_practice_mode(enabled: bool) -> void:
	_practice_mode_active = enabled
	timer_label.visible = not enabled and not main_menu.visible
	scoreboard.visible = not enabled and _duel_mode and not main_menu.visible
	if enabled:
		fling_cooldown_panel.visible = false


func set_fling_cooldown(remaining_seconds: float, duration_seconds: float = 3.0) -> void:
	var safe_duration := maxf(duration_seconds, 0.001)
	var safe_remaining := clampf(remaining_seconds, 0.0, safe_duration)
	fling_cooldown_bar.value = safe_remaining / safe_duration * 100.0
	fling_cooldown_value.text = "FLING COOLDOWN  %.1fs" % safe_remaining
	_fling_cooldown_remaining = safe_remaining
	_fling_cooldown_duration = safe_duration
	if _fling_meter != null:
		_fling_meter.set_state(_fling_charge_ratio, safe_remaining, safe_duration)


func set_duel_score(red_score: int, blue_score: int, scoring_team := -1) -> void:
	_last_red_score = red_score
	_last_blue_score = blue_score
	if _match_bar != null:
		_match_bar.set_scores(red_score, blue_score)
	if scoring_team == 0:
		_pulse_score_panel(red_score_panel)
	elif scoring_team == 1:
		_pulse_score_panel(blue_score_panel)


func set_round_number(round_number: int) -> void:
	_round_display_number = maxi(1, round_number)


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
	bot_button.disabled = loading
	name_input.editable = not loading
	code_input.editable = not loading
	host_button.tooltip_text = message
	join_button.tooltip_text = message
	var status_color := Color(0.44, 0.9, 1.0) if loading else (Color(1.0, 0.48, 0.5) if _is_error_status(message) else Color(0.66, 0.78, 0.92))
	main_menu.set_connection_status(message, status_color, loading or _has_actionable_connection_status(message))
	host_button.text = "HOST A DUEL"
	join_button.text = "JOIN"
	var lower_message := message.to_lower()
	if loading:
		if _last_connection_action == "host":
			host_button.text = "STARTING..."
		elif _last_connection_action == "join":
			join_button.text = "CANCEL"
			join_button.disabled = false
	elif _last_connection_action == "host" and ("failed" in lower_message or "could not" in lower_message or "not valid" in lower_message):
		host_button.text = "HOST FAILED — TRY AGAIN"
	elif "join failed" in lower_message or "could not" in lower_message or "not valid" in lower_message:
		join_button.text = "RETRY"


func get_player_name() -> String:
	var clean_name := name_input.text.strip_edges()
	return clean_name if not clean_name.is_empty() else "Player"


func get_player_color() -> Color:
	return BLOB_COLORS[clampi(_selected_color_index, 0, BLOB_COLORS.size() - 1)]


func _select_player_color(index: int) -> void:
	_selected_color_index = clampi(index, 0, BLOB_COLORS.size() - 1)
	main_menu.set_selected_swatch(_selected_color_index)
	_refresh_menu_identity()
	_emit_identity()


func _is_error_status(message: String) -> bool:
	var lower := message.to_lower()
	return "failed" in lower or "could not" in lower or "not valid" in lower or "disconnected" in lower


func _has_actionable_connection_status(message: String) -> bool:
	var lower := message.strip_edges().to_lower()
	return not lower.is_empty() and lower not in ["choose host, join, or practice", "choose how you want to play"]


func get_host_address() -> String:
	return code_input.text.strip_edges()


func get_selected_map_id() -> String:
	var index := main_menu.get_selected_map_index()
	return str(COMPETITIVE_MAPS[clampi(index, 0, COMPETITIVE_MAPS.size() - 1)][0])


## `kind` is one of HIT_MARKER_VARIANTS: "hit", "ricochet", "rail", or
## "elimination". Heavier kinds pop larger, recolour the marker, and linger.
func show_hit_marker(kind := "hit") -> void:
	var variant := HIT_MARKER_VARIANTS.get(kind, HIT_MARKER_VARIANTS["hit"]) as Dictionary
	_hit_marker_kind = kind if HIT_MARKER_VARIANTS.has(kind) else "hit"
	_hit_marker_duration = float(variant.get("duration", 0.18))
	_hit_marker_time = _hit_marker_duration
	var color := variant.get("color", Color(1.0, 0.72, 0.18)) as Color
	for child in hit_marker.get_children():
		var rect := child as ColorRect
		if rect != null:
			rect.color = color
	var target_scale := float(variant.get("scale", 1.0))
	hit_marker.visible = true
	hit_marker.pivot_offset = hit_marker.size * 0.5
	hit_marker.scale = Vector2.ONE * target_scale if _reduced_motion else Vector2.ONE * target_scale * 0.62
	crosshair.flash_hit_confirm()
	if not _reduced_motion:
		var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_property(hit_marker, "scale", Vector2.ONE * target_scale, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if _hit_marker_kind == "elimination" and _feedback != null:
		_feedback.flash_elimination_ring()
	_play_hit_confirm_sound(_hit_marker_kind)


## The shooter's audible confirm: a ding per connect, pitched by hit kind,
## and a flourish for the finishing blow.
func _play_hit_confirm_sound(kind: String) -> void:
	var audio := get_node_or_null("/root/AudioManager")
	if audio == null:
		return
	if kind == "elimination":
		audio.call("play_sfx", &"elimination", -2.0)
		return
	var pitch := 1.0
	match kind:
		"rail":
			pitch = 0.8
		"ricochet":
			pitch = 1.18
	audio.call("play_sfx", &"hit_confirm", -7.0, pitch + randf_range(-0.03, 0.03))


func get_hit_marker_kind() -> String:
	return _hit_marker_kind


## Floating damage number at the impact point; hits sharing `target_key`
## add into one running total. Off-screen or camera-less
## impacts (headless tests, hits behind the camera) land just above the
## crosshair so the feedback is never silently dropped.
func show_damage_number(amount: int, world_position: Vector3, kind := "hit", target_key := "") -> void:
	if _feedback == null or amount <= 0:
		return
	var screen_position := get_viewport().get_visible_rect().size * 0.5 + Vector2(0.0, -48.0)
	var camera := get_viewport().get_camera_3d()
	if camera != null and not camera.is_position_behind(world_position):
		screen_position = camera.unproject_position(world_position)
	_feedback.show_damage_number_at(amount, screen_position, kind, target_key)


## Points an arc around the crosshair toward the damage source. Without a
## camera the world direction cannot be projected, so nothing is shown.
func show_damage_direction(world_direction: Vector3) -> void:
	if _feedback == null or world_direction.length_squared() <= 0.0001:
		return
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var local := camera.global_basis.inverse() * world_direction.normalized()
	# Camera space looks down -Z; straight ahead is angle 0 (screen up).
	_feedback.show_damage_direction_angle(atan2(local.x, -local.z))


func add_kill_feed_entry(killer_name: String, killer_color: Color, victim_name: String, victim_color: Color, cause := "shot") -> void:
	if _feedback != null:
		_feedback.add_kill_feed_entry(killer_name, killer_color, victim_name, victim_color, cause)


func add_feed_message(text: String, color: Color = Color(0.72, 0.8, 0.9)) -> void:
	if _feedback != null:
		_feedback.add_feed_message(text, color)


func get_feedback_layer() -> DuelFeedbackLayer:
	return _feedback


func _create_feedback_layer() -> void:
	_feedback = DUEL_FEEDBACK_SCRIPT.new() as DuelFeedbackLayer
	add_child(_feedback)
	_feedback.set_ui_font(_ui_font)
	_feedback.set_reduced_motion(_reduced_motion)


## The round-intro card rides on the countdown: the first countdown beat in a
## duel shows it, "GO!" clears it. Names and colours come from the blobs in
## the arena so the HUD needs no extra wiring from the match flow.
func _sync_round_intro(_message: String) -> void:
	# The round-intro card is retired: the top bar already shows the score
	# and the countdown now lives in the timer box.
	if _feedback != null:
		_feedback.hide_round_intro()


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
	if _victory_cinematic_active:
		return
	if _announcement_tween != null and _announcement_tween.is_valid():
		_announcement_tween.kill()
	_sync_round_intro(message)
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
	if _match_bar != null:
		_match_bar.set_time(seconds_remaining)


## One beat of the round-start countdown, shown inside the match-timer box.
func show_countdown_beat(text: String) -> void:
	if _victory_cinematic_active or _match_bar == null:
		return
	_match_bar.countdown_beat(text)


## The round result takes over the timer box: it grows big, pushes the score
## boxes aside, and turns green (won), red (lost) or grey (draw).
func show_round_result(kind: int) -> void:
	if _match_bar == null:
		return
	var text := "DRAW"
	if kind == ROUND_RESULT_WON:
		text = "ROUND WON!"
	elif kind == ROUND_RESULT_LOST:
		text = "ROUND LOST"
	_match_bar.show_result(kind, text)


func reset_round_result() -> void:
	if _match_bar != null:
		_match_bar.reset_result()


func _pulse_match_timer() -> void:
	if _timer_pulse_tween != null and _timer_pulse_tween.is_valid():
		_timer_pulse_tween.kill()
	timer_label.pivot_offset = timer_label.size * 0.5
	_timer_pulse_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_timer_pulse_tween.tween_property(timer_label, "scale", Vector2(1.16, 1.16), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_timer_pulse_tween.tween_property(timer_label, "scale", Vector2.ONE, 0.18)


func apply_crosshair_settings(settings: Dictionary) -> void:
	crosshair.apply_settings(settings)


func show_victory(is_winner: bool, winning_team: int, players: Array) -> void:
	var team_color := TEAM_RED_COLOR if winning_team == 0 else TEAM_BLUE_ACCENT
	var accent := team_color if is_winner else DEFEAT_ACCENT
	_victory_winning_team = winning_team
	_victory_eyebrow.text = "MATCH COMPLETE" if is_winner else "MATCH OVER"
	_victory_eyebrow.add_theme_color_override("font_color", team_color.lightened(0.3) if is_winner else UI_TOKENS.COLOR_MUTED)
	result_label.text = "VICTORY" if is_winner else "DEFEAT"
	result_label.add_theme_color_override("font_color", Color.WHITE if is_winner else Color(0.8, 0.84, 0.92))
	result_label.add_theme_color_override("font_outline_color", accent.darkened(0.25) if is_winner else Color(0.2, 0.25, 0.34))
	result_detail.text = "ORANGE  %d  —  %d  BLUE" % [_last_red_score, _last_blue_score]
	_victory_accent_bar.color = accent
	victory_overlay.visible = true
	victory_overlay.modulate.a = 0.0
	result_banner.pivot_offset = result_banner.size * 0.5
	_build_roster(players)
	if _reward_panel != null:
		_reward_panel.visible = false
	_layout_victory()
	if _victory_fx != null:
		_victory_fx.reveal_results(team_color, is_winner, _reduced_motion, victory_overlay, 1)
	roster_panel.visible = true
	if _reduced_motion:
		victory_overlay.modulate.a = 1.0
		result_banner.scale = Vector2.ONE
		_victory_accent_bar.scale.x = 1.0
		return
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	tween.tween_property(victory_overlay, "modulate:a", 1.0, 0.3)
	# The title slams in from oversized, then the accent line draws out.
	result_banner.scale = Vector2(1.45, 1.45)
	result_banner.modulate.a = 0.0
	tween.tween_property(result_banner, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(result_banner, "modulate:a", 1.0, 0.22)
	_victory_accent_bar.scale.x = 0.0
	tween.tween_property(_victory_accent_bar, "scale:x", 1.0, 0.45).set_delay(0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	result_detail.modulate.a = 0.0
	tween.tween_property(result_detail, "modulate:a", 1.0, 0.3).set_delay(0.42)
	_slide_in(roster_panel, 1.0, 0.75)


func hide_victory() -> void:
	var was_cinematic := _victory_cinematic_active
	_victory_cinematic_active = false
	# The cinematic hid the gameplay HUD; a rematch needs it back.
	if was_cinematic and not _lobby_mode_active:
		set_lobby_mode(false)
	victory_overlay.visible = false
	roster_panel.visible = false
	if _reward_panel != null:
		_reward_panel.visible = false
	if _victory_fx != null:
		_victory_fx.reset()


## Results layout: the title centred at the top, the receipt on the left and
## the scoreboard on the right, both under the title and scaled down together
## when the window is too short, so the celebrating blob stays in the middle.
func _layout_victory() -> void:
	if victory_overlay == null or not victory_overlay.visible:
		return
	var view := get_viewport().get_visible_rect().size
	var margin := clampf(view.x * 0.035, 20.0, 56.0)
	var banner_size := result_banner.get_combined_minimum_size()
	banner_size.x = minf(VICTORY_BANNER_WIDTH, view.x - margin * 2.0)
	result_banner.size = banner_size
	result_banner.position = Vector2((view.x - banner_size.x) * 0.5, clampf(view.y * 0.035, 12.0, 40.0))
	result_banner.pivot_offset = banner_size * 0.5
	var column_top := result_banner.position.y + banner_size.y + 12.0
	var available := Vector2(view.x - margin * 2.0, view.y - column_top - margin * 0.6)
	var columns: Array[Control] = [roster_panel]
	if _reward_panel != null:
		columns.append(_reward_panel)
	var tallest := 0.0
	for column in columns:
		column.size = Vector2(column.size.x, 0.0)
		column.size = column.get_combined_minimum_size().max(Vector2(column.custom_minimum_size.x, 0.0))
		tallest = maxf(tallest, column.size.y)
	var needed_width := VICTORY_ROSTER_WIDTH + (VICTORY_REWARDS_WIDTH if _reward_panel != null else 0.0) + 160.0
	var fit := minf(1.0, minf(available.y / maxf(tallest, 1.0), available.x / needed_width))
	for column in columns:
		column.scale = Vector2.ONE * fit
		var scaled := column.size * fit
		var y := column_top + maxf(0.0, (available.y - scaled.y) * 0.5)
		var x := margin if column == _reward_panel else view.x - margin - scaled.x
		column.position = Vector2(x, y)
		column.set_meta("rest_x", x)


## Fades a results column in while it glides from its side of the screen.
func _slide_in(column: Control, direction: float, delay: float) -> void:
	var rest_x := float(column.get_meta("rest_x", column.position.x))
	if _reduced_motion:
		column.modulate.a = 1.0
		column.position.x = rest_x
		return
	column.modulate.a = 0.0
	column.position.x = rest_x + 48.0 * direction
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	tween.tween_property(column, "modulate:a", 1.0, 0.3).set_delay(delay)
	tween.tween_property(column, "position:x", rest_x, 0.45).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## Builds the parts of the results screen hud.tscn does not carry: the
## effects layer under the overlay, and the eyebrow + accent line in the title.
func _create_victory_layout() -> void:
	_victory_fx = VICTORY_FX.new()
	add_child(_victory_fx)
	move_child(_victory_fx, victory_overlay.get_index())
	_victory_fx.set_display_font(_display_font)
	(victory_overlay.get_node("Shade") as ColorRect).color = Color(0.01, 0.015, 0.03, 0.34)
	result_banner.set_anchors_preset(Control.PRESET_TOP_LEFT)
	var banner_style := StyleBoxFlat.new()
	banner_style.draw_center = false
	banner_style.content_margin_left = UI_TOKENS.SPACE_LG
	banner_style.content_margin_right = UI_TOKENS.SPACE_LG
	banner_style.content_margin_top = UI_TOKENS.SPACE_LG
	banner_style.content_margin_bottom = UI_TOKENS.SPACE_MD
	result_banner.add_theme_stylebox_override("panel", banner_style)
	var stack := result_banner.get_node("Stack") as VBoxContainer
	stack.add_theme_constant_override("separation", UI_TOKENS.SPACE_SM)
	_victory_eyebrow = Label.new()
	_victory_eyebrow.name = "Eyebrow"
	_victory_eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_victory_eyebrow.add_theme_font_override("font", _tracked_font(_ui_font, 4))
	_victory_eyebrow.add_theme_font_size_override("font_size", 14)
	stack.add_child(_victory_eyebrow)
	stack.move_child(_victory_eyebrow, 0)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.add_theme_font_override("font", _tracked_font(_display_font, 6))
	result_label.add_theme_font_size_override("font_size", 78)
	result_label.add_theme_constant_override("outline_size", 14)
	result_label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.02, 0.45))
	result_label.add_theme_constant_override("shadow_outline_size", 14)
	result_label.add_theme_constant_override("shadow_offset_x", 0)
	result_label.add_theme_constant_override("shadow_offset_y", 7)
	_victory_accent_bar = ColorRect.new()
	_victory_accent_bar.name = "AccentBar"
	_victory_accent_bar.custom_minimum_size = Vector2(220, 4)
	_victory_accent_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_victory_accent_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_victory_accent_bar.resized.connect(func() -> void: _victory_accent_bar.pivot_offset = _victory_accent_bar.size * 0.5)
	stack.add_child(_victory_accent_bar)
	stack.move_child(_victory_accent_bar, result_label.get_index() + 1)
	result_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_detail.add_theme_font_override("font", _tracked_font(_display_font, 2))
	result_detail.add_theme_font_size_override("font_size", 22)
	result_detail.add_theme_color_override("font_color", Color(0.86, 0.9, 0.97))
	roster_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	roster_panel.custom_minimum_size = Vector2(VICTORY_ROSTER_WIDTH, 0)
	roster_panel.add_theme_stylebox_override("panel", _results_card_style(Color(0.55, 0.68, 0.9)))
	var roster_header := roster_panel.get_node("Stack/Header") as Label
	roster_header.text = "SCOREBOARD"
	roster_header.add_theme_font_override("font", _tracked_font(_ui_font, 3))
	roster_header.add_theme_font_size_override("font_size", 14)
	roster_header.add_theme_color_override("font_color", Color(0.7, 0.8, 0.95))
	(roster_panel.get_node("Stack/Divider") as ColorRect).color = Color(0.4, 0.5, 0.66, 0.35)


## A copy of `base` with extra letter spacing, for uppercase headings.
func _tracked_font(base: Font, spacing: int) -> FontVariation:
	var font := FontVariation.new()
	font.base_font = base
	font.spacing_glyph = spacing
	return font


func _results_card_style(accent: Color) -> StyleBoxFlat:
	var style := _glass_panel_style(accent, UI_TOKENS.RADIUS_LG, 0.84)
	style.border_color = Color(accent, 0.3)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.4)
	style.shadow_size = 18
	style.shadow_offset = Vector2(0, 8)
	return style


## Post-match receipt: staggered breakdown rows, a counting total, the quest
## objectives that moved this match, and the cheapest unowned item as a
## concrete "next unlock" bar. `reward` is the Dictionary award_match returns;
## the quest and unlock sections simply stay hidden when it lacks them.
func show_match_rewards(reward: Dictionary) -> void:
	if _reward_panel == null:
		return
	var header := _reward_panel.get_node("Stack/Header") as Label
	header.text = "MATCH REWARDS"
	var rows := _reward_panel.get_node("Stack/Rows") as VBoxContainer
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	var breakdown := reward.get("breakdown", []) as Array
	var step := 0.04 if _reduced_motion else 0.2
	for index in breakdown.size():
		var entry := breakdown[index] as Dictionary
		var row := HBoxContainer.new()
		row.name = "RewardRow%d" % index
		var row_label := Label.new()
		row_label.text = str(entry.get("label", "Reward"))
		row_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row_label.add_theme_font_size_override("font_size", 14)
		row_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
		row.add_child(row_label)
		var amount_label := Label.new()
		amount_label.text = "+%d" % int(entry.get("amount", 0))
		amount_label.add_theme_font_size_override("font_size", 14)
		amount_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.25))
		row.add_child(amount_label)
		row.modulate.a = 0.0
		rows.add_child(row)
		var reveal := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		reveal.tween_interval(0.3 + index * step)
		reveal.tween_property(row, "modulate:a", 1.0, 0.16)
	var total := HBoxContainer.new()
	total.name = "TotalRow"
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
	total_value.name = "TotalValue"
	total_value.text = "+0 COINS"
	total_value.add_theme_font_size_override("font_size", 20)
	total_value.add_theme_color_override("font_color", Color(1.0, 0.79, 0.2))
	total.add_child(total_value)
	total.modulate.a = 0.0
	rows.add_child(total)
	var total_delay := 0.5 + breakdown.size() * step
	var total_tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	total_tween.tween_interval(total_delay)
	total_tween.tween_property(total, "modulate:a", 1.0, 0.14)
	total_tween.tween_method(func(value: float) -> void: total_value.text = "+%d COINS" % int(round(value)), 0.0, float(total_amount), 0.1 if _reduced_motion else 0.58).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_build_reward_quest_ticks(reward.get("quest_ticks", []) as Array, total_delay + 0.3)
	var next_unlock := reward.get("next_unlock", {}) as Dictionary
	if next_unlock.is_empty() and _progression != null and _progression.has_method("get_next_unlock"):
		next_unlock = _progression.call("get_next_unlock") as Dictionary
	_build_reward_next_unlock(next_unlock, total_amount, total_delay + 0.4)
	_reward_panel.visible = true
	_apply_ui_font_tree(_reward_panel)
	(_reward_panel.get_node("Stack/Header") as Label).add_theme_font_override("font", _tracked_font(_ui_font, 3))
	_layout_victory()
	_slide_in(_reward_panel, -1.0, 0.6)


func _build_reward_quest_ticks(ticks: Array, delay: float) -> void:
	var section := _reward_panel.get_node("Stack/QuestTicks") as VBoxContainer
	for child in section.get_children():
		section.remove_child(child)
		child.queue_free()
	section.visible = not ticks.is_empty()
	if ticks.is_empty():
		return
	var eyebrow := Label.new()
	eyebrow.text = "QUEST PROGRESS THIS MATCH"
	eyebrow.add_theme_font_size_override("font_size", 10)
	eyebrow.add_theme_color_override("font_color", Color(0.55, 0.78, 0.68))
	section.add_child(eyebrow)
	var shown := mini(REWARD_QUEST_TICK_LIMIT, ticks.size())
	for index in shown:
		var tick := ticks[index] as Dictionary
		var row := HBoxContainer.new()
		row.name = "QuestTick%d" % index
		var title := Label.new()
		title.text = str(tick.get("title", "Quest"))
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		title.add_theme_font_size_override("font_size", 12)
		title.add_theme_color_override("font_color", Color(0.86, 0.92, 1.0))
		row.add_child(title)
		var progress := Label.new()
		var completed := bool(tick.get("completed", false))
		progress.text = "READY TO CLAIM" if completed else "+%d   %d / %d" % [int(tick.get("delta", 0)), int(tick.get("progress", 0)), int(tick.get("target", 1))]
		progress.add_theme_font_size_override("font_size", 12)
		progress.add_theme_color_override("font_color", Color(1.0, 0.78, 0.2) if completed else UI_TOKENS.COLOR_MINT)
		row.add_child(progress)
		row.modulate.a = 0.0
		section.add_child(row)
		var reveal := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		reveal.tween_interval(delay + index * 0.12)
		reveal.tween_property(row, "modulate:a", 1.0, 0.16)
	if ticks.size() > shown:
		var more := Label.new()
		more.text = "+%d more on the quest board" % (ticks.size() - shown)
		more.add_theme_font_size_override("font_size", 10)
		more.add_theme_color_override("font_color", UI_TOKENS.COLOR_MUTED)
		section.add_child(more)


func _build_reward_next_unlock(next_unlock: Dictionary, earned: int, delay: float) -> void:
	var section := _reward_panel.get_node("Stack/NextUnlock") as VBoxContainer
	for child in section.get_children():
		section.remove_child(child)
		child.queue_free()
	section.visible = not next_unlock.is_empty()
	if next_unlock.is_empty():
		return
	var price := maxi(1, int(next_unlock.get("price", 1)))
	var balance := clampi(int(next_unlock.get("balance", 0)), 0, price)
	var previous := clampi(balance - maxi(0, earned), 0, price)
	var row := HBoxContainer.new()
	section.add_child(row)
	var title := Label.new()
	title.name = "NextUnlockTitle"
	title.text = "NEXT UNLOCK  ·  %s" % str(next_unlock.get("name", "")).to_upper()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", Color(0.74, 0.86, 1.0))
	row.add_child(title)
	var readout := Label.new()
	readout.name = "NextUnlockReadout"
	readout.text = "%d / %d" % [previous, price]
	readout.add_theme_font_size_override("font_size", 11)
	readout.add_theme_color_override("font_color", Color(1.0, 0.82, 0.3) if balance >= price else Color(0.86, 0.92, 1.0))
	row.add_child(readout)
	var bar := ProgressBar.new()
	bar.name = "NextUnlockBar"
	bar.custom_minimum_size = Vector2(0, 8)
	bar.show_percentage = false
	bar.max_value = price
	bar.value = previous
	bar.add_theme_stylebox_override("background", _progress_style(Color(0.025, 0.035, 0.07), Color(0.14, 0.22, 0.36)))
	bar.add_theme_stylebox_override("fill", _progress_style(Color(1.0, 0.76, 0.22), Color.TRANSPARENT))
	section.add_child(bar)
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_interval(delay)
	tween.tween_method(func(value: float) -> void:
		bar.value = value
		readout.text = "%d / %d" % [int(round(value)), price]
	, float(previous), float(balance), 0.1 if _reduced_motion else 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Progression UI ---------------------------------------------------------------
## The drawer owns coins, quests, the shop and the toasts; the HUD keeps the
## entry points the menu, the pause flow and the contracts call.
func _setup_progression_ui() -> void:
	_progression = get_node_or_null("/root/Progression")
	drawer = ProgressionDrawer.new()
	drawer.name = "ProgressionUi"
	add_child(drawer)
	drawer.setup(self, _progression)
	if _progression == null:
		return
	_progression.inventory_changed.connect(_refresh_menu_identity)
	_create_reward_panel()


func is_progression_open() -> bool:
	return drawer.is_progression_open()


func close_progression() -> void:
	drawer.close_progression()


func _set_progression_open(page: String) -> void:
	drawer._set_progression_open(page)


func _show_progression_toast(title: String, detail: String = "") -> void:
	drawer._show_progression_toast(title, detail)


func _create_reward_panel() -> void:
	_reward_panel = PanelContainer.new()
	_reward_panel.name = "MatchRewards"
	_reward_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_reward_panel.custom_minimum_size = Vector2(VICTORY_REWARDS_WIDTH, 0)
	_reward_panel.add_theme_stylebox_override("panel", _results_card_style(UI_TOKENS.COLOR_GOLD))
	victory_overlay.add_child(_reward_panel)
	var stack := VBoxContainer.new()
	stack.name = "Stack"
	stack.add_theme_constant_override("separation", 10)
	_reward_panel.add_child(stack)
	var title := Label.new()
	title.name = "Header"
	title.text = "MATCH REWARDS"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", UI_TOKENS.COLOR_GOLD)
	stack.add_child(title)
	var rows := VBoxContainer.new()
	rows.name = "Rows"
	rows.add_theme_constant_override("separation", UI_TOKENS.SPACE_SM)
	stack.add_child(rows)
	var quest_ticks := VBoxContainer.new()
	quest_ticks.name = "QuestTicks"
	quest_ticks.visible = false
	quest_ticks.add_theme_constant_override("separation", 4)
	stack.add_child(quest_ticks)
	var next_unlock := VBoxContainer.new()
	next_unlock.name = "NextUnlock"
	next_unlock.visible = false
	next_unlock.add_theme_constant_override("separation", 4)
	stack.add_child(next_unlock)
	var actions := HBoxContainer.new()
	actions.name = "Actions"
	actions.add_theme_constant_override("separation", UI_TOKENS.SPACE_SM)
	var actions_gap := Control.new()
	actions_gap.custom_minimum_size = Vector2(0, 2)
	stack.add_child(actions_gap)
	stack.add_child(actions)
	_rematch_button = Button.new()
	_rematch_button.name = "RematchButton"
	_rematch_button.text = "REMATCH"
	_rematch_button.custom_minimum_size = Vector2(0, 48)
	_rematch_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rematch_button.focus_mode = Control.FOCUS_NONE
	_rematch_button.tooltip_text = "Play the same opponent again"
	_apply_primary_shop_button_style(_rematch_button, Color(1.0, 0.76, 0.22))
	_rematch_button.add_theme_font_size_override("font_size", 16)
	_rematch_button.pressed.connect(func() -> void: rematch_requested.emit())
	actions.add_child(_rematch_button)
	var return_button := Button.new()
	return_button.name = "ReturnToLobbyButton"
	return_button.text = "MAIN MENU"
	return_button.custom_minimum_size = Vector2(0, 48)
	return_button.add_theme_font_size_override("font_size", 16)
	return_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return_button.focus_mode = Control.FOCUS_NONE
	_apply_utility_button_style(return_button, Color(0.34, 0.92, 0.78))
	return_button.pressed.connect(func() -> void: return_to_lobby_requested.emit())
	actions.add_child(return_button)


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
	button.add_theme_stylebox_override("disabled", _panel_style(Color(0.05, 0.06, 0.085, 0.6), Color(0.2, 0.24, 0.32, 0.5), 10))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", Color(0.86, 0.91, 0.97))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(0.45, 0.5, 0.58))


## A finished state (equipped, claimed) shown on a disabled button: calm and
## positive rather than the greyed-out look of an action you cannot take yet.
func _apply_settled_button_style(button: Button, accent: Color) -> void:
	button.add_theme_stylebox_override("disabled", _panel_style(Color(accent.r * 0.12, accent.g * 0.12, accent.b * 0.12, 0.85), Color(accent, 0.55), 12))
	button.add_theme_color_override("font_disabled_color", accent)


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


## One scoreboard row per player: blob, name and team, and the match stats
## inline. The winner's row is lit gold and tagged.
func _build_roster(players: Array) -> void:
	for child in roster_players.get_children():
		roster_players.remove_child(child)
		child.queue_free()
	for index in players.size():
		var entry := players[index] as Dictionary
		var team := int(entry.get("team", 0 if str(entry.get("team_name", "ORANGE")) in ["ORANGE", "RED"] else 1))
		var row := _roster_row(entry, team == _victory_winning_team)
		row.name = "RosterRow%d" % index
		roster_players.add_child(row)
		if not _reduced_motion:
			row.modulate.a = 0.0
			var reveal := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			reveal.tween_interval(0.95 + index * 0.12)
			reveal.tween_property(row, "modulate:a", 1.0, 0.25)
	_apply_ui_font_tree(roster_panel)
	(roster_panel.get_node("Stack/Header") as Label).add_theme_font_override("font", _tracked_font(_ui_font, 3))
	for value_label in roster_players.find_children("StatValue*", "Label", true, false):
		(value_label as Label).add_theme_font_override("font", _display_font)


func _roster_row(entry: Dictionary, is_winner: bool) -> PanelContainer:
	var team_tint: Color = entry.get("team_color", Color.WHITE)
	var row := PanelContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := _panel_style(Color(0.06, 0.075, 0.11, 0.9), Color(0.3, 0.37, 0.48, 0.45), UI_TOKENS.RADIUS_MD)
	if is_winner:
		style.bg_color = Color(0.13, 0.11, 0.06, 0.92)
		style.border_color = Color(UI_TOKENS.COLOR_GOLD, 0.75)
		style.shadow_color = Color(UI_TOKENS.COLOR_GOLD, 0.16)
		style.shadow_size = 10
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	row.add_theme_stylebox_override("panel", style)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	row.add_child(stack)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	stack.add_child(top)
	var avatar := Control.new()
	avatar.set_script(BLOB_AVATAR_SCRIPT)
	avatar.custom_minimum_size = Vector2(40, 40)
	avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	avatar.call("set_color", entry.get("color", Color.WHITE))
	top.add_child(avatar)
	var identity := VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.alignment = BoxContainer.ALIGNMENT_CENTER
	identity.add_theme_constant_override("separation", 0)
	top.add_child(identity)
	var name_label := Label.new()
	name_label.text = str(entry.get("name", "Player"))
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.add_theme_font_size_override("font_size", 17)
	name_label.add_theme_color_override("font_color", UI_TOKENS.COLOR_TEXT)
	identity.add_child(name_label)
	var team_label := Label.new()
	team_label.text = "%s TEAM%s" % [str(entry.get("team_name", "ORANGE")), "  ·  YOU" if bool(entry.get("is_local", false)) else ""]
	team_label.add_theme_font_size_override("font_size", 11)
	team_label.add_theme_color_override("font_color", team_tint.lightened(0.15))
	identity.add_child(team_label)
	if is_winner:
		var tag := Label.new()
		tag.text = "WINNER"
		tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tag.add_theme_font_size_override("font_size", 11)
		tag.add_theme_color_override("font_color", Color(0.1, 0.07, 0.01))
		var tag_style := _panel_style(UI_TOKENS.COLOR_GOLD, UI_TOKENS.COLOR_GOLD, 8)
		tag_style.content_margin_left = 8
		tag_style.content_margin_right = 8
		tag_style.content_margin_top = 2
		tag_style.content_margin_bottom = 2
		tag.add_theme_stylebox_override("normal", tag_style)
		top.add_child(tag)
	var stats := HBoxContainer.new()
	stats.add_theme_constant_override("separation", 6)
	stack.add_child(stats)
	var eliminations := int(entry.get("eliminations", 0))
	var deaths := int(entry.get("deaths", 0))
	stats.add_child(_stat_chip("ELIMS", str(eliminations)))
	stats.add_child(_stat_chip("DEATHS", str(deaths)))
	if entry.has("damage"):
		stats.add_child(_stat_chip("DAMAGE", str(int(entry.get("damage", 0)))))
	else:
		stats.add_child(_stat_chip("E / D", "%.1f" % (float(eliminations) / maxf(float(deaths), 1.0))))
	return row


func _stat_chip(caption: String, value: String) -> PanelContainer:
	var chip := PanelContainer.new()
	chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := _panel_style(Color(0.0, 0.0, 0.0, 0.28), Color(0, 0, 0, 0), UI_TOKENS.RADIUS_SM)
	style.content_margin_top = 4
	style.content_margin_bottom = 5
	style.content_margin_left = 8
	style.content_margin_right = 8
	chip.add_theme_stylebox_override("panel", style)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", -2)
	chip.add_child(stack)
	var value_label := Label.new()
	value_label.name = "StatValue"
	value_label.text = value
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value_label.add_theme_font_size_override("font_size", 20)
	value_label.add_theme_color_override("font_color", UI_TOKENS.COLOR_TEXT)
	stack.add_child(value_label)
	var caption_label := Label.new()
	caption_label.text = caption
	caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption_label.add_theme_font_size_override("font_size", 10)
	caption_label.add_theme_color_override("font_color", UI_TOKENS.COLOR_MUTED)
	stack.add_child(caption_label)
	return chip


func _apply_ui_font_tree(scope: Node) -> void:
	if _ui_font == null or scope == null:
		return
	if scope is Control:
		(scope as Control).add_theme_font_override("font", _ui_font)
	for candidate in scope.find_children("*", "Control", true, false):
		(candidate as Control).add_theme_font_override("font", _ui_font)


func _emit_identity() -> void:
	identity_changed.emit(get_player_name(), get_player_color())


## Builds the full-screen pre-game menu behind every other HUD layer and wires
## its controls to the same requests the game already listens for.
func _create_main_menu() -> void:
	main_menu = MAIN_MENU.new()
	main_menu.visible = false
	add_child(main_menu)
	move_child(main_menu, 0)
	name_input = main_menu.name_input
	code_input = main_menu.code_input
	room_code = main_menu.room_code_label
	host_button = main_menu.host_button
	join_button = main_menu.join_button
	practice_button = main_menu.practice_button
	bot_button = main_menu.bot_button
	match_format_button = main_menu.format_button
	var map_labels: Array = []
	for map_entry in COMPETITIVE_MAPS:
		map_labels.append(str(map_entry[1]).to_upper())
	main_menu.set_map_options(map_labels, 0)
	var difficulty_labels: Array = []
	for option in BOT_DIFFICULTY_OPTIONS:
		difficulty_labels.append(str(option[0]))
	main_menu.set_difficulty_options(difficulty_labels, DEFAULT_BOT_DIFFICULTY_INDEX)
	main_menu.set_swatches(BLOB_COLORS, _selected_color_index)
	main_menu.swatch_pressed.connect(_select_player_color)
	host_button.pressed.connect(func() -> void:
		_last_connection_action = "host"
		host_requested.emit()
	)
	join_button.pressed.connect(_submit_join)
	code_input.text_submitted.connect(func(_submitted_text: String) -> void: _submit_join())
	practice_button.pressed.connect(func() -> void: practice_requested.emit())
	bot_button.pressed.connect(func() -> void: bot_requested.emit(get_bot_difficulty()))
	match_format_button.pressed.connect(_cycle_match_format)
	_refresh_match_format_button()
	name_input.text_changed.connect(func(_new_text: String) -> void: _emit_identity())
	main_menu.shop_button.pressed.connect(_set_progression_open.bind("shop"))
	main_menu.loadout_card.pressed.connect(_set_progression_open.bind("shop"))
	main_menu.quests_button.pressed.connect(_set_progression_open.bind("quests"))
	main_menu.settings_button.pressed.connect(func() -> void: settings_requested.emit())
	main_menu.quit_button.pressed.connect(func() -> void: get_tree().quit())
	network_status = NetworkStatusHud.new()
	network_status.name = "NetworkStatus"
	add_child(network_status)
	network_status.setup(self)
	var network_session := get_node_or_null("/root/NetworkSession")


## Join doubles as Cancel while a connection attempt is in flight.
func _submit_join() -> void:
	var network_session := get_node_or_null("/root/NetworkSession") as DuelNetworkSession
	if network_session != null and network_session.is_joining():
		network_session.close_session()
		set_join_status("Join cancelled", false)
		return
	if join_button.disabled:
		return
	_last_connection_action = "join"
	join_requested.emit(code_input.text.strip_edges())


func _refresh_menu_identity() -> void:
	if main_menu == null:
		return
	main_menu.show_identity(get_player_color())
	_refresh_menu_loadout()


## The loadout card: the equipped power-up and how close the balance is to
## the cheapest thing not owned yet.
func _refresh_menu_loadout() -> void:
	if main_menu == null or _progression == null:
		return
	var ability_id := str(_progression.call("get_equipped", "abilities"))
	var ability_title := ability_id.replace("_", " ").to_upper()
	for item_value in _progression.call("get_items", "abilities") as Array:
		var item := item_value as Dictionary
		if str(item.get("id", "")) == ability_id:
			ability_title = str(item.get("name", ability_title)).to_upper()
	var next_unlock := _progression.call("get_next_unlock") as Dictionary
	if next_unlock.is_empty():
		main_menu.set_loadout(ABILITY_HUD_SCRIPT.get_icon(ability_id), ability_title, "", "", -1.0)
		return
	var price := maxi(1, int(next_unlock.get("price", 1)))
	var balance := int(_progression.call("get_balance"))
	var detail := "READY TO BUY" if balance >= price else "%d / %d" % [balance, price]
	main_menu.set_loadout(
		ABILITY_HUD_SCRIPT.get_icon(ability_id),
		ability_title,
		"NEXT UNLOCK  ·  %s" % str(next_unlock.get("name", "")).to_upper(),
		detail,
		float(balance) / float(price)
	)


func _process(delta: float) -> void:
	_update_fps_counter(delta)
	_hit_marker_time = maxf(_hit_marker_time - delta, 0.0)
	_damage_flash_time = maxf(_damage_flash_time - delta, 0.0)
	_announcement_time = maxf(_announcement_time - delta, 0.0)
	hit_marker.modulate.a = clampf(_hit_marker_time / maxf(_hit_marker_duration * 0.66, 0.01), 0.0, 1.0)
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
	set_fling_cooldown(player.get_fling_cooldown_remaining(), player.get_fling_cooldown_duration())

	_shown_health = move_toward(_shown_health, player.health, 420.0 * delta)
	if _last_observed_health >= 0 and player.health < _last_observed_health:
		health_panel.pivot_offset = health_panel.size * 0.5
		var health_tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		health_tween.tween_property(health_panel, "scale", Vector2(1.04, 1.04), 0.08)
		health_tween.tween_property(health_panel, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_last_observed_health = player.health
	health_bar.max_value = player.max_health
	health_bar.value = _shown_health
	health_value.text = str(player.health)
	if _health_pill != null:
		_health_pill.set_health(player.health, player.max_health, _shown_health / maxf(float(player.max_health), 1.0))
	if _match_bar != null:
		_match_bar.sync_layout()
	var charge_ratio: float = player.get_charge_ratio()
	_fling_charge_ratio = charge_ratio
	if _fling_meter != null:
		_fling_meter.set_state(charge_ratio, _fling_cooldown_remaining, _fling_cooldown_duration)
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
	crosshair.set_dynamic_state(charge_ratio, player.linear_velocity.length() / maxf(player.ground_control_speed, 1.0))

	var ratio: float = float(player.health) / float(player.max_health)
	var health_color: Color
	if ratio > 0.6:
		health_color = Color(0.18, 0.9, 0.56, 1.0)
	elif ratio > 0.3:
		health_color = Color(0.98, 0.72, 0.2, 1.0)
	else:
		health_color = Color(1.0, 0.28, 0.32, 1.0)

	_fill_style.bg_color = health_color
	if _feedback != null:
		# The vignette only belongs in live play: never over the lobby, the
		# victory overlay, or a dead blob waiting on the round result.
		var in_play: bool = health_panel.visible and not main_menu.visible and not victory_overlay.visible and int(player.health) > 0
		_feedback.set_low_health_ratio(ratio if in_play else 1.0)


func set_camera_mode(_is_third_person: bool) -> void:
	pass


## Set while the victory cinematic owns the screen; callouts wait it out.
var _victory_cinematic_active := false
var _victory_fx: VictoryFx
var _victory_eyebrow: Label
var _victory_accent_bar: ColorRect
var _victory_winning_team := 0


## Match format ------------------------------------------------------------------
## The host chooses first-to and round length; every client shows the same
## values because they arrive with the match setup.
var _match_score_to_win := 5
var _match_round_seconds := 180.0


func set_match_format(score_to_win: int, round_seconds: float) -> void:
	_match_score_to_win = maxi(score_to_win, 1)
	_match_round_seconds = maxf(round_seconds, 1.0)


func get_match_format_text() -> String:
	return "FIRST TO %d · %d:%02d ROUNDS" % [_match_score_to_win, int(_match_round_seconds) / 60, int(_match_round_seconds) % 60]


## Bot duel and match format ----------------------------------------------------
## The main menu shows difficulty as a segmented control on the bot card and
## the format as a cycling button beside the arena picker; these tables are
## what those controls mean.
const BOT_DIFFICULTY_OPTIONS := [["EASY", 0], ["NORMAL", 1], ["HARD", 2]]
const DEFAULT_BOT_DIFFICULTY_INDEX := 1
## Format presets: [button label, first-to, round seconds], cycled by one
## compact button.
const MATCH_FORMAT_OPTIONS := [
	["FIRST TO 1", 1, 90.0],
	["FIRST TO 3", 3, 90.0],
	["FIRST TO 5", 5, 90.0],
	["FIRST TO 7", 7, 90.0],
	["FIRST TO 10", 10, 90.0],
]
const DEFAULT_MATCH_FORMAT_INDEX := 2
const FORMAT_BUTTON_MIN_WIDTH := 118.0

var _match_format_index := DEFAULT_MATCH_FORMAT_INDEX


func get_bot_difficulty() -> int:
	var index := main_menu.get_selected_difficulty_index()
	if index < 0 or index >= BOT_DIFFICULTY_OPTIONS.size():
		index = DEFAULT_BOT_DIFFICULTY_INDEX
	return int(BOT_DIFFICULTY_OPTIONS[index][1])


func _cycle_match_format() -> void:
	_match_format_index = (_match_format_index + 1) % MATCH_FORMAT_OPTIONS.size()
	_refresh_match_format_button()
	_emit_match_format()


func _refresh_match_format_button() -> void:
	if match_format_button == null:
		return
	var option: Array = MATCH_FORMAT_OPTIONS[_match_format_index]
	match_format_button.text = str(option[0])
	var seconds := int(float(option[2]))
	match_format_button.tooltip_text = "%s · %d:%02d rounds. Click to change." % [str(option[0]).capitalize(), seconds / 60, seconds % 60]


func _emit_match_format() -> void:
	match_format_changed.emit(get_selected_score_to_win(), get_selected_round_seconds())


func _selected_match_format() -> Array:
	return MATCH_FORMAT_OPTIONS[clampi(_match_format_index, 0, MATCH_FORMAT_OPTIONS.size() - 1)]


func get_selected_score_to_win() -> int:
	return int(_selected_match_format()[1])


func get_selected_round_seconds() -> float:
	return float(_selected_match_format()[2])
