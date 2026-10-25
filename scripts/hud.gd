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
## Shop category ids (Progression catalog keys) and their tab labels, in order.
const SHOP_CATEGORIES := [["abilities", "ABILITIES"], ["skins", "SKINS"], ["trails", "TRAILS"], ["kill_effects", "EFFECTS"], ["faces", "FACES"]]
const SHOP_ITEM_KINDS := {"abilities": "ABILITY", "skins": "SKIN", "trails": "TRAIL", "kill_effects": "KILL EFFECT", "faces": "FACE"}
const RARITY_COLORS := {"Common": Color(0.55, 0.6, 0.66), "Rare": Color(0.22, 0.58, 1.0), "Epic": Color(0.68, 0.34, 1.0), "Legendary": Color(1.0, 0.72, 0.16), "Basic": Color(0.32, 0.9, 0.46), "Advanced": Color(0.22, 0.58, 1.0), "Expert": Color(0.68, 0.34, 1.0)}
const SHOP_CARD_SIZE := Vector2(152, 206)
const SHOP_SPOTLIGHT_WIDTH := 282.0
## Owned / equipped / claimed.
const SHOP_MINT := Color(0.38, 1.0, 0.64)
## Prices the player cannot cover yet.
const SHOP_SHORT := Color(1.0, 0.48, 0.44)
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
]
@onready var health_bar: ProgressBar = $HealthPanel/HealthBar
@onready var health_value: Label = $HealthPanel/HealthBar/HealthValue
@onready var health_panel: PanelContainer = $HealthPanel
@onready var crosshair: Control = $Crosshair
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
var _fps_label: Label = null
var _ping_label: Label = null
var _fps_accumulator := 0.0
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
var _reward_panel: PanelContainer
var _shown_coin_balance := 0.0
var _coin_target_balance := 0
var _active_progression_page := "shop"
var _active_shop_category := "abilities"
var _selected_shop_item: Dictionary = {}
var _quests_showing_weekly := false
var _quest_reset_accumulator := 0.0
## Progression drawer (shop + quest board). The header is built once; the body
## below it rebuilds per page, and the shop / board keep their own slots so a
## category, item, or tab change only rebuilds what it touches.
var _drawer_body: VBoxContainer
var _drawer_title: Label
var _drawer_subtitle: Label
var _drawer_page_tabs: MenuSegmented
var _drawer_balance_chip: PanelContainer
var _drawer_balance_label: Label
var _drawer_shown_balance := 0
## True while a claim is sending coins to the header: the balance counts up
## when they land instead of on the balance_changed signal.
var _drawer_coin_flight := false
var _drawer_tween: Tween
var _drawer_size := Vector2(900, 600)
var _progression_closing := false
var _shop_scroll: ScrollContainer
var _shop_grid: GridContainer
var _shop_spotlight_slot: VBoxContainer
var _shop_section_label: Label
var _quest_board_slot: VBoxContainer
var _board_reset_label: Label
var _quest_ring_ratio := 0.0
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
var _quest_list: VBoxContainer
var _timer_pulse_tween: Tween
var _round_display_number := 1
var _last_red_score := 0
var _last_blue_score := 0
var _last_timer_second := -1
var _formatting_room_code := false
var _health_shell_style: StyleBoxFlat
var _reduced_motion := false
var _toast_stack: VBoxContainer
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
@onready var _ability_panel: Control = $AbilityHUD


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
	_create_toast_stack()
	_setup_progression_ui()
	get_viewport().size_changed.connect(_fit_progression_drawer)
	_apply_ui_font_tree(self)
	main_menu.configure_fonts(_display_font)
	_create_victory_layout()
	get_viewport().size_changed.connect(_layout_victory)


func set_ability_state(ability_id: String, cooldown_remaining_msec: int, loaded: bool, active: bool, active_remaining_msec: int = 0, deployed: bool = false) -> void:
	if _ability_panel == null:
		return
	_current_ability_id = ability_id
	_ability_panel.call("set_ability_state", ability_id, cooldown_remaining_msec, loaded, active, active_remaining_msec, deployed)
	_ability_panel.visible = not main_menu.visible and not ability_id.is_empty()


func apply_ui_settings(settings: Dictionary) -> void:
	_reduced_motion = bool(settings.get("reduced_motion", false))
	if _feedback != null:
		_feedback.set_reduced_motion(_reduced_motion)
	if _ability_panel != null and _ability_panel.has_method("set_reduced_motion"):
		_ability_panel.call("set_reduced_motion", _reduced_motion)
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


func bind_player(new_player) -> void:
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
		_hide_progression_now()
	if is_lobby:
		main_menu.modulate = Color.WHITE
		_refresh_menu_identity()
		_refresh_quest_panel(entering)
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
		_hide_progression_now()


func is_progression_open() -> bool:
	return _shop_overlay != null and _shop_overlay.visible and not _progression_closing


func close_progression() -> void:
	_set_shop_open(false)


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


## Shows the code(s) a host can hand out. The Internet code appears once
## NetworkSession's UPnP mapping has produced a public address; the LAN code
## is always listed as the fallback for players on the same network.
func _refresh_room_code() -> void:
	var network_session := get_node_or_null("/root/NetworkSession")
	var lan_code := "LOCAL"
	var internet_code := ""
	if network_session != null and network_session.has_method("get_host_room_code"):
		lan_code = str(network_session.call("get_host_room_code"))
	if network_session != null and network_session.has_method("get_public_room_code"):
		internet_code = str(network_session.call("get_public_room_code"))
	var copy_button := main_menu.copy_button
	if internet_code.is_empty():
		room_code.text = "LAN CODE  %s" % lan_code
		copy_button.text = "COPY LAN CODE"
		copy_button.tooltip_text = "Copy the LAN code to the clipboard"
	else:
		room_code.text = "INTERNET CODE  %s\nLAN CODE  %s" % [internet_code, lan_code]
		copy_button.text = "COPY INTERNET CODE"
		copy_button.tooltip_text = "Copy the Internet code to the clipboard"


func _copy_room_code() -> void:
	var network_session := get_node_or_null("/root/NetworkSession")
	var has_internet_code := network_session != null and network_session.has_method("has_public_address") and bool(network_session.call("has_public_address"))
	var code := ""
	if network_session != null and network_session.has_method("get_share_room_code"):
		code = str(network_session.call("get_share_room_code"))
	else:
		code = room_code.text.trim_prefix("LAN CODE").strip_edges()
	DisplayServer.clipboard_set(code)
	if has_internet_code:
		set_join_status("Internet code copied — send it to a friend anywhere", false)
	else:
		set_join_status("LAN code copied — send it to a player on your network", false)


## Small round-trip readout in the bottom-right corner of the duel HUD. Hidden
## whenever the session is offline or the lobby is up; colour tracks the
## thresholds in NetworkTuning.
func _create_ping_label() -> void:
	if _ping_label != null:
		return
	_ping_label = Label.new()
	_ping_label.name = "PingLabel"
	_ping_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_ping_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_ping_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_ping_label.offset_left = -132.0
	_ping_label.offset_top = -34.0
	_ping_label.offset_right = -16.0
	_ping_label.offset_bottom = -12.0
	_ping_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ping_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ping_label.add_theme_font_size_override("font_size", 15)
	_ping_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	_ping_label.add_theme_constant_override("outline_size", 5)
	_ping_label.z_index = 128
	_ping_label.visible = false
	add_child(_ping_label)
	var network_session := get_node_or_null("/root/NetworkSession")
	if network_session != null:
		if network_session.has_signal("ping_updated"):
			network_session.connect("ping_updated", _update_ping_label)
		if network_session.has_signal("state_changed"):
			network_session.connect("state_changed", func(_state: int, _message: String) -> void: _refresh_ping_visibility())
	main_menu.visibility_changed.connect(_refresh_ping_visibility)


func _update_ping_label(msec: int) -> void:
	if _ping_label == null:
		return
	_ping_label.text = "PING %d ms" % maxi(msec, 0)
	_ping_label.add_theme_color_override("font_color", ping_readout_color(msec))
	_refresh_ping_visibility()


func _refresh_ping_visibility() -> void:
	if _ping_label == null:
		return
	var network_session := get_node_or_null("/root/NetworkSession")
	var online := network_session != null and network_session.has_method("is_online") and bool(network_session.call("is_online"))
	var has_reading := network_session != null and network_session.has_method("get_ping_msec") and int(network_session.call("get_ping_msec")) >= 0
	_ping_label.visible = online and has_reading and not main_menu.visible


## Green under PING_GOOD_MSEC, amber under PING_FAIR_MSEC, red beyond.
static func ping_readout_color(msec: int) -> Color:
	if msec < NETWORK_TUNING.PING_GOOD_MSEC:
		return Color(0.62, 0.98, 0.76)
	if msec < NETWORK_TUNING.PING_FAIR_MSEC:
		return Color(1.0, 0.78, 0.32)
	return Color(1.0, 0.42, 0.42)


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
	if crosshair.has_method("flash_hit_confirm"):
		crosshair.call("flash_hit_confirm")
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
	if crosshair.has_method("apply_settings"):
		crosshair.call("apply_settings", settings)


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


func _setup_progression_ui() -> void:
	_progression = get_node_or_null("/root/Progression")
	if _progression == null:
		return
	_coin_target_balance = int(_progression.call("get_balance"))
	_shown_coin_balance = _coin_target_balance
	_progression.balance_changed.connect(_on_coin_balance_changed)
	_progression.quest_completed.connect(_on_quest_completed)
	_progression.inventory_changed.connect(_refresh_shop_if_open)
	_progression.inventory_changed.connect(_refresh_menu_identity)
	_create_coin_chip()
	_create_quest_panel()
	_create_shop_overlay()
	_create_reward_panel()


func _create_coin_chip() -> void:
	_coin_chip = PanelContainer.new()
	_coin_chip.name = "CoinBalance"
	_coin_chip.custom_minimum_size = Vector2(126, 46)
	_coin_chip.add_theme_stylebox_override("panel", _glass_panel_style(UI_TOKENS.COLOR_GOLD, UI_TOKENS.RADIUS_LG, 0.72))
	main_menu.coin_slot.add_child(_coin_chip)
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


## Today's dailies live on the menu's quest card; the HUD fills it because it
## owns the Progression wiring and the claim flow.
func _create_quest_panel() -> void:
	_quest_panel = main_menu.quest_card
	_quest_list = main_menu.quest_card.content
	_refresh_quest_panel()


## `fill_in` grows each bar from empty, timed to land after the menu intro.
func _refresh_quest_panel(fill_in := false) -> void:
	if _quest_list == null or _progression == null:
		return
	for child in _quest_list.get_children():
		_quest_list.remove_child(child)
		child.queue_free()
	var daily_quests := _progression.get("daily_quests") as Array
	var claimed_count := 0
	for quest_value in daily_quests:
		if bool((quest_value as Dictionary).get("claimed", false)):
			claimed_count += 1
	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quest_list.add_child(header)
	var title := Label.new()
	title.text = "TODAY  ·  %d / %d COMPLETE" % [claimed_count, daily_quests.size()]
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.5))
	header.add_child(title)
	_quest_reset_label = Label.new()
	_quest_reset_label.add_theme_font_size_override("font_size", 10)
	_quest_reset_label.add_theme_color_override("font_color", Color(0.58, 0.66, 0.76))
	header.add_child(_quest_reset_label)
	_update_quest_reset_label()
	if daily_quests.is_empty():
		var empty := Label.new()
		empty.text = "All daily quests complete"
		empty.add_theme_color_override("font_color", UI_TOKENS.COLOR_MUTED)
		_quest_list.add_child(empty)
	for index in daily_quests.size():
		_quest_list.add_child(_make_menu_quest_row(daily_quests[index] as Dictionary, fill_in, 0.6 + 0.1 * index))
	_apply_ui_font_tree(_quest_list)


func _make_menu_quest_row(quest: Dictionary, fill_in: bool, fill_delay: float) -> Control:
	var claimed := bool(quest.get("claimed", false))
	var completed := bool(quest.get("completed", false)) or claimed
	var target := maxi(1, int(quest.get("target", 1)))
	var progress := mini(target, int(quest.get("progress", 0)))
	var accent := Color(0.38, 1.0, 0.6) if claimed else (UI_TOKENS.COLOR_GOLD if completed else Color(0.25, 0.68, 1.0))
	var row := VBoxContainer.new()
	row.name = "Quest_%s" % str(quest.get("id", ""))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 4)
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override("separation", 8)
	row.add_child(line)
	var objective := Label.new()
	objective.text = str(quest.get("title", ""))
	objective.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	objective.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	objective.add_theme_font_size_override("font_size", 14)
	objective.add_theme_color_override("font_color", UI_TOKENS.COLOR_MUTED if claimed else UI_TOKENS.COLOR_TEXT)
	line.add_child(objective)
	if completed and not claimed:
		var claim := Button.new()
		claim.name = "Claim"
		claim.text = "CLAIM +%d" % int(quest.get("reward", 0))
		claim.focus_mode = Control.FOCUS_NONE
		claim.custom_minimum_size = Vector2(0, 26)
		claim.add_theme_font_size_override("font_size", 11)
		_apply_primary_shop_button_style(claim, UI_TOKENS.COLOR_GOLD)
		claim.pressed.connect(func() -> void:
			_claim_quest("daily", str(quest.get("id", "")), claim)
			_refresh_quest_panel()
		)
		PROGRESSION_FX.breathe(claim, 0.16)
		line.add_child(claim)
	else:
		var reward := Label.new()
		reward.text = "✓" if claimed else "+%d" % int(quest.get("reward", 0))
		reward.add_theme_font_size_override("font_size", 12)
		reward.add_theme_color_override("font_color", accent)
		line.add_child(reward)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 6)
	bar.show_percentage = false
	bar.max_value = target
	bar.value = progress
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("background", _progress_style(Color(0.025, 0.035, 0.07), Color(0.12, 0.2, 0.34)))
	var fill := _progress_style(accent, Color.TRANSPARENT)
	fill.shadow_color = Color(accent, 0.4)
	fill.shadow_size = 4
	bar.add_theme_stylebox_override("fill", fill)
	row.add_child(bar)
	if fill_in:
		PROGRESSION_FX.fill_bar(bar, 0.0, fill_delay)
	return row


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
	# Product rule: the shop and quest board are translucent drawers over the
	# live lobby, not full-screen pages - the backdrop and shell both stay
	# see-through and the drawer keeps a safe margin on every edge.
	shade.color = Color(0.004, 0.008, 0.018, 0.6)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.gui_input.connect(_on_progression_backdrop_input)
	_shop_overlay.add_child(shade)
	_shop_shell = PanelContainer.new()
	_shop_shell.name = "ProgressionDrawer"
	var shell_style := _elevated_panel_style(Color(0.012, 0.02, 0.042, 0.88), Color(0.34, 0.64, 1.0, 0.5), 26, Color(0.0, 0.0, 0.0, 0.6))
	shell_style.shadow_size = 28
	shell_style.shadow_offset = Vector2(0, 12)
	shell_style.content_margin_left = 24
	shell_style.content_margin_top = 18
	shell_style.content_margin_right = 24
	shell_style.content_margin_bottom = 22
	_shop_shell.add_theme_stylebox_override("panel", shell_style)
	_shop_overlay.add_child(_shop_shell)
	_shop_content = VBoxContainer.new()
	_shop_content.add_theme_constant_override("separation", 16)
	_shop_shell.add_child(_shop_content)
	_shop_content.add_child(_build_drawer_header())
	_drawer_body = VBoxContainer.new()
	_drawer_body.name = "DrawerBody"
	_drawer_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_drawer_body.add_theme_constant_override("separation", 12)
	_shop_content.add_child(_drawer_body)
	_fit_progression_drawer()


## Title, the Shop / Quests switch, the balance, and close. Built once and kept
## while the drawer lives, so the page switch can slide instead of snapping.
func _build_drawer_header() -> Control:
	var header := HBoxContainer.new()
	header.name = "DrawerHeader"
	header.custom_minimum_size = Vector2(0, 52)
	header.add_theme_constant_override("separation", 14)
	var title_stack := VBoxContainer.new()
	title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	title_stack.add_theme_constant_override("separation", 0)
	header.add_child(title_stack)
	_drawer_title = _drawer_label("", 28, UI_TOKENS.COLOR_TEXT)
	_drawer_title.name = "DrawerTitle"
	title_stack.add_child(_drawer_title)
	_drawer_subtitle = _drawer_label("", 10, Color(0.47, 0.64, 0.88))
	_drawer_subtitle.name = "DrawerSubtitle"
	_drawer_subtitle.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_stack.add_child(_drawer_subtitle)
	_drawer_page_tabs = MENU_SEGMENTED.new("DrawerPages", UI_TOKENS.COLOR_CYAN)
	_drawer_page_tabs.custom_minimum_size = Vector2(210, 40)
	_drawer_page_tabs.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_drawer_page_tabs.set_options(["SHOP", "QUESTS"], 0)
	_drawer_page_tabs.selection_changed.connect(func(index: int) -> void: _switch_progression_page("shop" if index == 0 else "quests"))
	header.add_child(_drawer_page_tabs)
	_drawer_balance_chip = PanelContainer.new()
	_drawer_balance_chip.name = "DrawerBalance"
	_drawer_balance_chip.custom_minimum_size = Vector2(128, 42)
	_drawer_balance_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var chip_style := _glass_panel_style(UI_TOKENS.COLOR_GOLD, 21, 0.74)
	chip_style.content_margin_left = 12
	chip_style.content_margin_right = 16
	chip_style.content_margin_top = 6
	chip_style.content_margin_bottom = 6
	_drawer_balance_chip.add_theme_stylebox_override("panel", chip_style)
	header.add_child(_drawer_balance_chip)
	var balance_row := HBoxContainer.new()
	balance_row.alignment = BoxContainer.ALIGNMENT_CENTER
	balance_row.add_theme_constant_override("separation", 8)
	_drawer_balance_chip.add_child(balance_row)
	balance_row.add_child(_coin_mark(22.0))
	_drawer_balance_label = _drawer_label("0", 20, UI_TOKENS.COLOR_TEXT)
	_drawer_balance_label.name = "DrawerBalanceValue"
	balance_row.add_child(_drawer_balance_label)
	var close := Button.new()
	close.name = "CloseDrawer"
	close.text = "✕"
	close.tooltip_text = "Close  (Esc)"
	close.custom_minimum_size = Vector2(42, 42)
	close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close.focus_mode = Control.FOCUS_NONE
	close.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close.add_theme_font_size_override("font_size", 16)
	_apply_utility_button_style(close, UI_TOKENS.COLOR_CYAN)
	close.pressed.connect(close_progression)
	PROGRESSION_FX.springy(close)
	header.add_child(close)
	return header


func _fit_progression_drawer() -> void:
	if _shop_shell == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	# Capped at roughly 70% x 83% of the 1280x720 reference so the lobby stays
	# visible around the drawer, and never closer than 24px to any edge.
	var drawer_size := Vector2(
		minf(900.0, viewport_size.x - 48.0),
		minf(600.0, viewport_size.y - 48.0)
	)
	drawer_size.x = maxf(drawer_size.x, minf(360.0, viewport_size.x - 48.0))
	drawer_size.y = maxf(drawer_size.y, minf(520.0, viewport_size.y - 48.0))
	_drawer_size = drawer_size
	_shop_shell.anchor_left = 0.5
	_shop_shell.anchor_top = 0.5
	_shop_shell.anchor_right = 0.5
	_shop_shell.anchor_bottom = 0.5
	_shop_shell.offset_left = -drawer_size.x * 0.5
	_shop_shell.offset_top = -drawer_size.y * 0.5
	_shop_shell.offset_right = drawer_size.x * 0.5
	_shop_shell.offset_bottom = drawer_size.y * 0.5
	_shop_shell.pivot_offset = drawer_size * 0.5


func _on_progression_backdrop_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		_set_shop_open(false)


func _set_progression_open(page: String) -> void:
	if _shop_overlay == null:
		return
	var opening := not _shop_overlay.visible or _progression_closing
	_active_progression_page = page
	_progression_closing = false
	_shop_overlay.visible = true
	# The drawer shows its own balance; never two coin counters at once.
	if _coin_chip != null:
		_coin_chip.visible = false
	if opening:
		_drawer_shown_balance = int(_progression.call("get_balance"))
		_drawer_balance_label.text = "%d" % _drawer_shown_balance
		_play_drawer_transition(true)
	_refresh_drawer_header()
	_build_progression(true)
	_apply_ui_font_tree(_shop_content)
	get_tree().paused = false


func _set_shop_open(open: bool) -> void:
	if open:
		_set_progression_open("shop")
		return
	if _shop_overlay == null or not _shop_overlay.visible or _progression_closing:
		return
	_progression_closing = true
	if _coin_chip != null:
		_coin_chip.visible = true
	if _lobby_mode_active:
		# The loadout may have changed while the drawer was open.
		_refresh_menu_identity()
		_refresh_quest_panel()
	_play_drawer_transition(false)


## Closes without the exit animation, for a mode change that takes the menu
## away underneath the drawer.
func _hide_progression_now() -> void:
	if _shop_overlay == null or not _shop_overlay.visible:
		return
	if _drawer_tween != null and _drawer_tween.is_valid():
		_drawer_tween.kill()
	_finish_drawer_close()
	if _coin_chip != null:
		_coin_chip.visible = true


## Opening: the backdrop fades up while the drawer scales in from 94% with a
## small overshoot. Closing runs a quicker reverse, then hides. Scale and
## alpha only, around the drawer's centre, so it never leaves its safe margin.
func _play_drawer_transition(opening: bool) -> void:
	if _drawer_tween != null and _drawer_tween.is_valid():
		_drawer_tween.kill()
	var backdrop := _shop_overlay.get_node("DrawerBackdrop") as ColorRect
	_shop_shell.pivot_offset = _shop_shell.size * 0.5
	if _reduced_motion:
		backdrop.modulate.a = 1.0
		_shop_shell.modulate.a = 1.0
		_shop_shell.scale = Vector2.ONE
		if not opening:
			_finish_drawer_close()
		return
	_drawer_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	if opening:
		backdrop.modulate.a = 0.0
		_shop_shell.modulate.a = 0.0
		_shop_shell.scale = Vector2.ONE * 0.94
		_drawer_tween.tween_property(backdrop, "modulate:a", 1.0, 0.22)
		_drawer_tween.tween_property(_shop_shell, "modulate:a", 1.0, 0.18)
		_drawer_tween.tween_property(_shop_shell, "scale", Vector2.ONE, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		return
	_drawer_tween.tween_property(backdrop, "modulate:a", 0.0, 0.18)
	_drawer_tween.tween_property(_shop_shell, "modulate:a", 0.0, 0.14)
	_drawer_tween.tween_property(_shop_shell, "scale", Vector2.ONE * 0.96, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_drawer_tween.chain().tween_callback(_finish_drawer_close)


func _finish_drawer_close() -> void:
	_progression_closing = false
	_shop_overlay.visible = false
	_shop_shell.scale = Vector2.ONE
	_shop_shell.modulate.a = 1.0
	(_shop_overlay.get_node("DrawerBackdrop") as ColorRect).modulate.a = 1.0
	# Nothing in a hidden drawer should keep running: the model preview owns a
	# SubViewport, and modals or coins in flight belong to the closed session.
	_clear_children(_drawer_body)
	for child in _shop_overlay.get_children():
		if child.name != &"DrawerBackdrop" and child != _shop_shell:
			child.queue_free()


func _switch_progression_page(page: String) -> void:
	if page == _active_progression_page:
		return
	_active_progression_page = page
	_refresh_drawer_header()
	PROGRESSION_FX.pop_in(_drawer_title, 0.0, 0.9)
	_build_progression(true)


func _refresh_drawer_header() -> void:
	var shop := _active_progression_page == "shop"
	_drawer_title.text = "BLOB SHOP" if shop else "QUEST BOARD"
	_drawer_subtitle.text = _shop_collection_copy() if shop else "PLAY  ·  PROGRESS  ·  GET PAID"
	_drawer_page_tabs.select(0 if shop else 1)


func _count_drawer_balance(balance: int) -> void:
	if _drawer_balance_label == null:
		return
	PROGRESSION_FX.count_label(_drawer_balance_label, _drawer_shown_balance, balance, "%d")
	_drawer_shown_balance = balance


func _shop_collection_copy() -> String:
	var owned_total := 0
	var item_total := 0
	for category_row in SHOP_CATEGORIES:
		for item_value in _progression.call("get_items", str(category_row[0])) as Array:
			item_total += 1
			if bool(_progression.call("is_owned", str((item_value as Dictionary).get("id", "")))):
				owned_total += 1
	return "BUILD YOUR BLOB  ·  %d / %d OWNED" % [owned_total, item_total]


## Rebuilds the page under the header. `intro` replays the staggered entrance;
## a refresh after a purchase or claim passes false so nothing re-pops.
func _build_progression(intro := false) -> void:
	if _drawer_body == null:
		return
	_clear_children(_drawer_body)
	if _active_progression_page == "quests":
		_build_quest_board(intro)
	else:
		_build_shop_workspace(intro)
	_apply_ui_font_tree(_drawer_body)


func _clear_children(parent: Node) -> void:
	if parent == null:
		return
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


## Shop: categories and the item grid on the left, the selected item on the
## real in-game blob on the right. Switching category or item rebuilds only
## the grid or the spotlight, so the category pill can glide between tabs.
func _build_shop_workspace(intro: bool) -> void:
	var workspace := HBoxContainer.new()
	workspace.name = "ShopWorkspace"
	workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace.add_theme_constant_override("separation", 16)
	_drawer_body.add_child(workspace)
	var browse := VBoxContainer.new()
	browse.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	browse.add_theme_constant_override("separation", 10)
	workspace.add_child(browse)
	var categories := MENU_SEGMENTED.new("ShopCategories", UI_TOKENS.COLOR_CYAN)
	categories.font_size = 11
	var labels: Array = []
	var selected_index := 0
	for index in SHOP_CATEGORIES.size():
		labels.append(SHOP_CATEGORIES[index][1])
		if SHOP_CATEGORIES[index][0] == _active_shop_category:
			selected_index = index
	categories.set_options(labels, selected_index)
	categories.selection_changed.connect(_on_shop_category_selected)
	browse.add_child(categories)
	_shop_section_label = _drawer_label("", 10, Color(0.5, 0.62, 0.8))
	browse.add_child(_shop_section_label)
	_shop_scroll = ScrollContainer.new()
	_shop_scroll.name = "ShopScroll"
	_shop_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_shop_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	browse.add_child(_shop_scroll)
	var gutter := MarginContainer.new()
	gutter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Room for the cards' hover glow and pop, which the scroll clip would cut.
	gutter.add_theme_constant_override("margin_left", 20)
	gutter.add_theme_constant_override("margin_top", 18)
	gutter.add_theme_constant_override("margin_right", 20)
	gutter.add_theme_constant_override("margin_bottom", 20)
	_shop_scroll.add_child(gutter)
	_shop_grid = GridContainer.new()
	_shop_grid.name = "ShopGrid"
	_shop_grid.columns = _shop_grid_columns()
	_shop_grid.add_theme_constant_override("h_separation", 12)
	_shop_grid.add_theme_constant_override("v_separation", 12)
	gutter.add_child(_shop_grid)
	_shop_spotlight_slot = VBoxContainer.new()
	_shop_spotlight_slot.name = "SpotlightSlot"
	_shop_spotlight_slot.custom_minimum_size = Vector2(SHOP_SPOTLIGHT_WIDTH, 0)
	workspace.add_child(_shop_spotlight_slot)
	_fill_shop_grid(intro)
	_fill_shop_spotlight(intro)


## Column count follows the drawer, not the window: the drawer is capped well
## below the viewport width, so a window-based count would overflow it.
func _shop_grid_columns() -> int:
	var available := _drawer_size.x - 48.0 - 16.0 - SHOP_SPOTLIGHT_WIDTH - 52.0
	return clampi(int((available + 12.0) / (SHOP_CARD_SIZE.x + 12.0)), 1, 3)


func _on_shop_category_selected(index: int) -> void:
	_active_shop_category = str(SHOP_CATEGORIES[index][0])
	_selected_shop_item = {}
	_shop_scroll.scroll_vertical = 0
	_fill_shop_grid(true)
	_fill_shop_spotlight(true)
	_apply_ui_font_tree(_drawer_body)


func _fill_shop_grid(intro: bool) -> void:
	_clear_children(_shop_grid)
	var items := _progression.call("get_items", _active_shop_category) as Array
	var owned_count := 0
	var selection_valid := false
	var equipped_id := str(_progression.call("get_equipped", _active_shop_category))
	var equipped_item: Dictionary = {}
	for item_value in items:
		var item := item_value as Dictionary
		var item_id := str(item.get("id", ""))
		if bool(_progression.call("is_owned", item_id)):
			owned_count += 1
		if item_id == str(_selected_shop_item.get("id", "")):
			selection_valid = true
		if item_id == equipped_id:
			equipped_item = item
	for category_row in SHOP_CATEGORIES:
		if category_row[0] == _active_shop_category:
			_shop_section_label.text = "%s  ·  %d / %d OWNED" % [category_row[1], owned_count, items.size()]
	# Opening a category shows what the blob wears right now.
	if not selection_valid:
		_selected_shop_item = equipped_item if not equipped_item.is_empty() else (items[0] as Dictionary if not items.is_empty() else {})
	for index in items.size():
		var card := _make_shop_item(_active_shop_category, items[index] as Dictionary)
		_shop_grid.add_child(card)
		if intro:
			card.play_intro(minf(0.035 * index, 0.42))


func _fill_shop_spotlight(intro: bool) -> void:
	_clear_children(_shop_spotlight_slot)
	var panel := _make_preview_panel(_active_shop_category, _selected_shop_item)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_shop_spotlight_slot.add_child(panel)
	if intro:
		PROGRESSION_FX.pop_in(panel, 0.04, 0.97)


func _shop_spotlight() -> Control:
	if _shop_spotlight_slot == null or not is_instance_valid(_shop_spotlight_slot) or _shop_spotlight_slot.get_child_count() == 0:
		return null
	return _shop_spotlight_slot.get_child(0) as Control


## One item tile. The whole card is the tap target (a MenuCard hit Button
## named CardHitTarget); it glows in its rarity colour while selected.
func _make_shop_item(category: String, item: Dictionary) -> MenuCard:
	var item_id := str(item.get("id", ""))
	var rarity := str(item.get("rarity", "Common"))
	var rarity_color: Color = RARITY_COLORS.get(rarity, Color.WHITE)
	var price := int(item.get("price", 0))
	var balance := int(_progression.call("get_balance"))
	var owned := bool(_progression.call("is_owned", item_id))
	var equipped := str(_progression.call("get_equipped", category)) == item_id
	var card := MENU_CARD.new("ShopItem_%s" % item_id, rarity_color, true, Vector4(10, 10, 10, 12), 0.2)
	card.custom_minimum_size = SHOP_CARD_SIZE
	card.set_reduced_motion(_reduced_motion)
	card.set_action_name("CardHitTarget", "Preview %s" % str(item.get("name", "item")))
	card.set_highlighted(item_id == str(_selected_shop_item.get("id", "")))
	card.pressed.connect(_select_shop_item.bind(item.duplicate(true)))
	card.content.add_theme_constant_override("separation", 6)
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(0, 100)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame_style := _panel_style(Color(0.008, 0.016, 0.04, 0.72), Color(rarity_color, 0.24), 12)
	frame_style.content_margin_left = 0
	frame_style.content_margin_top = 0
	frame_style.content_margin_right = 0
	frame_style.content_margin_bottom = 0
	frame.add_theme_stylebox_override("panel", frame_style)
	card.content.add_child(frame)
	var thumbnail := Control.new()
	thumbnail.name = "ItemPreview_%s" % item_id
	thumbnail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thumbnail.set_script(SHOP_CARD_PREVIEW_SCRIPT)
	thumbnail.call("set_item", category, item, rarity_color)
	frame.add_child(thumbnail)
	var tags := HBoxContainer.new()
	tags.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.content.add_child(tags)
	var rarity_label := _drawer_label(rarity.to_upper(), 9, rarity_color)
	rarity_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tags.add_child(rarity_label)
	if owned:
		tags.add_child(_drawer_label("EQUIPPED" if equipped else "OWNED", 9, SHOP_MINT if equipped else Color(0.6, 0.7, 0.84)))
	var name_label := _drawer_label(str(item.get("name", "Item")), 16, UI_TOKENS.COLOR_TEXT)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	card.content.add_child(name_label)
	var price_row := HBoxContainer.new()
	price_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price_row.add_theme_constant_override("separation", 6)
	card.content.add_child(price_row)
	if owned:
		price_row.add_child(_drawer_label("✓  ON YOUR BLOB" if equipped else "✓  IN YOUR LOCKER", 11, SHOP_MINT if equipped else UI_TOKENS.COLOR_MUTED))
		return card
	var affordable := balance >= price
	price_row.add_child(_coin_mark(16.0))
	price_row.add_child(_drawer_label("%d" % price, 14, UI_TOKENS.COLOR_GOLD if affordable else SHOP_SHORT))
	if not affordable:
		var need := _drawer_label("NEED %d" % (price - balance), 9, Color(SHOP_SHORT, 0.8))
		need.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		need.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		price_row.add_child(need)
	return card


## The selected item on the real in-game blob, its story, and one action.
func _make_preview_panel(category: String, item: Dictionary) -> PanelContainer:
	var rarity := str(item.get("rarity", "Common"))
	var accent: Color = RARITY_COLORS.get(rarity, Color.WHITE)
	var panel := PanelContainer.new()
	panel.name = "ItemSpotlight"
	var panel_style := _elevated_panel_style(Color(0.02, 0.034, 0.072, 0.9), Color(accent, 0.55), 20, Color(accent, 0.2))
	panel_style.shadow_size = 18
	panel_style.content_margin_left = 14
	panel_style.content_margin_top = 12
	panel_style.content_margin_right = 14
	panel_style.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", panel_style)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	panel.add_child(stack)
	var eyebrow := HBoxContainer.new()
	stack.add_child(eyebrow)
	eyebrow.add_theme_constant_override("separation", 7)
	var live_dot := Panel.new()
	live_dot.custom_minimum_size = Vector2(7, 7)
	live_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	live_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dot_style := StyleBoxFlat.new()
	dot_style.bg_color = SHOP_MINT
	dot_style.set_corner_radius_all(4)
	dot_style.shadow_color = Color(SHOP_MINT, 0.6)
	dot_style.shadow_size = 4
	live_dot.add_theme_stylebox_override("panel", dot_style)
	PROGRESSION_FX.breathe(live_dot, -0.55)
	eyebrow.add_child(live_dot)
	var live := _drawer_label("LIVE PREVIEW", 10, SHOP_MINT)
	live.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	eyebrow.add_child(live)
	eyebrow.add_child(_drawer_label("DRAG TO ROTATE", 9, Color(0.43, 0.58, 0.78)))
	var preview := SubViewportContainer.new()
	preview.name = "RealModelPreview"
	# Shorter drawers (small windows) give the model less room, never the copy.
	preview.custom_minimum_size = Vector2(0, clampf(_drawer_size.y - 420.0, 124.0, 196.0))
	preview.set_script(SHOP_MODEL_PREVIEW_SCRIPT)
	preview.call("set_item", category, item, accent)
	stack.add_child(preview)
	if category in ["abilities", "kill_effects"]:
		var replay := Button.new()
		replay.text = "REPLAY EFFECT" if category == "kill_effects" else "REPLAY PREVIEW"
		replay.custom_minimum_size = Vector2(0, 30)
		replay.focus_mode = Control.FOCUS_NONE
		replay.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		replay.add_theme_font_size_override("font_size", 11)
		_apply_utility_button_style(replay, accent)
		replay.pressed.connect(func() -> void: preview.call("replay"))
		PROGRESSION_FX.springy(replay)
		stack.add_child(replay)
	var name_label := _drawer_label(str(item.get("name", "Select an item")), 22, UI_TOKENS.COLOR_TEXT)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(name_label)
	var meta_row := HBoxContainer.new()
	stack.add_child(meta_row)
	var rarity_label := _drawer_label(rarity.to_upper(), 11, accent)
	rarity_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meta_row.add_child(rarity_label)
	meta_row.add_child(_drawer_label(str(SHOP_ITEM_KINDS.get(category, category.to_upper())), 10, Color(0.43, 0.58, 0.78)))
	var tagline := _drawer_label(str(item.get("tagline", "Make the arena yours.")), 13, Color(0.84, 0.91, 1.0))
	tagline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(tagline)
	var description := _drawer_label(str(item.get("description", "A cosmetic that makes your Blob unmistakable.")), 12, Color(0.66, 0.75, 0.88))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.max_lines_visible = 3
	description.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(description)
	stack.add_child(_make_spotlight_action(category, item))
	return panel


func _make_spotlight_action(category: String, item: Dictionary) -> Button:
	var item_id := str(item.get("id", ""))
	var price := int(item.get("price", 0))
	var owned := bool(_progression.call("is_owned", item_id))
	var equipped := str(_progression.call("get_equipped", category)) == item_id
	var affordable := int(_progression.call("get_balance")) >= price
	var action := Button.new()
	action.name = "SpotlightAction"
	action.custom_minimum_size = Vector2(0, 46)
	action.focus_mode = Control.FOCUS_NONE
	action.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_apply_primary_shop_button_style(action, SHOP_MINT if owned else UI_TOKENS.COLOR_GOLD)
	if equipped:
		action.text = "✓  EQUIPPED"
		action.disabled = true
		_apply_settled_button_style(action, SHOP_MINT)
	elif owned:
		action.text = "EQUIP"
	elif affordable:
		action.text = "BUY  ·  %d COINS" % price
		PROGRESSION_FX.breathe(action, 0.14)
	else:
		action.text = "NEED %d MORE COINS" % (price - int(_progression.call("get_balance")))
		action.disabled = true
		action.tooltip_text = "Win matches and claim quests to earn Coins"
	action.pressed.connect(_handle_shop_action.bind(category, item.duplicate(true)))
	PROGRESSION_FX.springy(action)
	return action


func _select_shop_item(item: Dictionary) -> void:
	var item_id := str(item.get("id", ""))
	if item_id == str(_selected_shop_item.get("id", "")):
		return
	_selected_shop_item = item
	if _shop_grid != null and is_instance_valid(_shop_grid):
		for card in _shop_grid.get_children():
			(card as MenuCard).set_highlighted(str(card.name) == "ShopItem_%s" % item_id)
	_fill_shop_spotlight(true)
	_apply_ui_font_tree(_shop_spotlight_slot)


func _handle_shop_action(category: String, item: Dictionary) -> void:
	var item_id := str(item.get("id", ""))
	if bool(_progression.call("is_owned", item_id)):
		# equip() raises inventory_changed, which rebuilds the page.
		if bool(_progression.call("equip", category, item_id)):
			_show_progression_toast("EQUIPPED", str(item.get("name", "")))
			PROGRESSION_FX.punch(_shop_spotlight(), 1.04)
		return
	_show_purchase_confirm(category, item)


func _show_purchase_confirm(category: String, item: Dictionary) -> void:
	if _shop_overlay == null:
		return
	var rarity_color: Color = RARITY_COLORS.get(str(item.get("rarity", "Common")), UI_TOKENS.COLOR_GOLD)
	var balance := int(_progression.call("get_balance"))
	var price := int(item.get("price", 0))
	var remaining := balance - price
	var modal := Control.new()
	modal.name = "PurchaseModal"
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	_shop_overlay.add_child(modal)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.0, 0.008, 0.024, 0.62)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.gui_input.connect(_cancel_purchase_modal.bind(modal))
	modal.add_child(shade)
	modal.gui_input.connect(_cancel_purchase_modal.bind(modal))
	var panel := PanelContainer.new()
	panel.name = "PurchaseDialog"
	# Centred by anchors and offsets; an absolute position here measured from
	# the screen's top-left and pushed the dialog off screen.
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -210
	panel.offset_right = 210
	panel.offset_top = -186
	panel.offset_bottom = 186
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.pivot_offset = Vector2(210, 186)
	var panel_style := _elevated_panel_style(Color(0.03, 0.045, 0.09, 0.97), Color(rarity_color, 0.8), 22, Color(rarity_color, 0.32))
	panel_style.shadow_size = 26
	panel_style.content_margin_left = 22
	panel_style.content_margin_right = 22
	panel_style.content_margin_top = 18
	panel_style.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", panel_style)
	modal.add_child(panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	panel.add_child(stack)
	var eyebrow := _drawer_label("UNLOCK  ·  %s" % str(item.get("rarity", "Common")).to_upper(), 10, rarity_color)
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(eyebrow)
	var title := _drawer_label(str(item.get("name", "Item")), 24, UI_TOKENS.COLOR_TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(title)
	var thumbnail := Control.new()
	thumbnail.custom_minimum_size = Vector2(0, 118)
	thumbnail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thumbnail.set_script(SHOP_CARD_PREVIEW_SCRIPT)
	thumbnail.call("set_item", category, item, rarity_color)
	stack.add_child(thumbnail)
	var price_row := HBoxContainer.new()
	price_row.alignment = BoxContainer.ALIGNMENT_CENTER
	price_row.add_theme_constant_override("separation", 8)
	stack.add_child(price_row)
	price_row.add_child(_coin_mark(26.0))
	price_row.add_child(_drawer_label("%d" % price, 26, UI_TOKENS.COLOR_GOLD))
	var after := _drawer_label("%d  →  %d AFTER PURCHASE" % [balance, remaining] if remaining >= 0 else "NEED %d MORE COINS" % absi(remaining), 11, UI_TOKENS.COLOR_MUTED if remaining >= 0 else SHOP_SHORT)
	after.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(after)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 12)
	stack.add_child(actions)
	var cancel := Button.new()
	cancel.text = "CANCEL"
	cancel.custom_minimum_size = Vector2(150, 44)
	cancel.focus_mode = Control.FOCUS_NONE
	_apply_utility_button_style(cancel, Color(0.68, 0.74, 0.84))
	cancel.pressed.connect(_dismiss_purchase_modal.bind(modal))
	PROGRESSION_FX.springy(cancel)
	actions.add_child(cancel)
	var confirm := Button.new()
	confirm.text = "BUY & EQUIP"
	confirm.custom_minimum_size = Vector2(150, 44)
	confirm.focus_mode = Control.FOCUS_NONE
	confirm.disabled = remaining < 0
	confirm.tooltip_text = "Earn %d more Coins to unlock this item" % absi(remaining) if confirm.disabled else ""
	_apply_primary_shop_button_style(confirm, UI_TOKENS.COLOR_GOLD)
	confirm.pressed.connect(_confirm_purchase.bind(category, item, modal))
	PROGRESSION_FX.springy(confirm)
	if not confirm.disabled:
		PROGRESSION_FX.breathe(confirm, 0.14)
	actions.add_child(confirm)
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null:
		audio.call("wire_ui_sounds", modal)
	_apply_ui_font_tree(modal)
	if _reduced_motion:
		return
	shade.modulate.a = 0.0
	panel.modulate.a = 0.0
	panel.scale = Vector2.ONE * 0.88
	var tween := modal.create_tween().set_parallel(true)
	tween.tween_property(shade, "modulate:a", 1.0, 0.16)
	tween.tween_property(panel, "modulate:a", 1.0, 0.14)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Coins leave the balance and pour into the item that was just bought.
func _confirm_purchase(category: String, item: Dictionary, modal: Control) -> void:
	var from := _drawer_balance_chip.get_global_rect().get_center()
	# purchase() raises balance_changed (the header counts down) and
	# inventory_changed (the page rebuilds with the item owned and equipped).
	if not bool(_progression.call("purchase", category, str(item.get("id", "")))):
		return
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null:
		audio.call("play_sfx", &"purchase", -7.0, 1.08)
	_show_progression_toast("ITEM PURCHASED", str(item.get("name", "")))
	_dismiss_purchase_modal(modal)
	var spotlight := _shop_spotlight()
	if spotlight != null:
		PROGRESSION_FX.coin_burst(_shop_overlay, from, spotlight.get_global_rect().get_center(), 7, PROGRESSION_FX.punch.bind(spotlight, 1.05))


func _dismiss_purchase_modal(modal: Control) -> void:
	if not is_instance_valid(modal) or modal.is_queued_for_deletion():
		return
	modal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _reduced_motion:
		modal.queue_free()
		return
	var tween := modal.create_tween()
	tween.tween_property(modal, "modulate:a", 0.0, 0.12)
	tween.tween_callback(modal.queue_free)


func _cancel_purchase_modal(event: InputEvent, modal: Control) -> void:
	if not is_instance_valid(modal):
		return
	var click := event as InputEventMouseButton
	if (click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT) or event.is_action_pressed("ui_cancel"):
		_dismiss_purchase_modal(modal)


## Quests: the Daily / Weekly switch and reset timer stay put; the summary
## and the objective list below them rebuild when the tab changes.
func _build_quest_board(intro: bool) -> void:
	var toolbar := HBoxContainer.new()
	toolbar.name = "QuestToolbar"
	toolbar.add_theme_constant_override("separation", 12)
	_drawer_body.add_child(toolbar)
	var tabs := MENU_SEGMENTED.new("QuestTabs", UI_TOKENS.COLOR_GOLD)
	tabs.custom_minimum_size = Vector2(240, 38)
	tabs.set_options(["DAILY", "WEEKLY"], 1 if _quests_showing_weekly else 0)
	tabs.selection_changed.connect(func(index: int) -> void: _set_quest_tab(index == 1))
	toolbar.add_child(tabs)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(spacer)
	_board_reset_label = _drawer_label("", 11, Color(0.6, 0.7, 0.84))
	_board_reset_label.name = "QuestResetTimer"
	_board_reset_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_board_reset_label.size_flags_vertical = Control.SIZE_FILL
	toolbar.add_child(_board_reset_label)
	_update_quest_reset_label()
	_quest_board_slot = VBoxContainer.new()
	_quest_board_slot.name = "QuestBoard"
	_quest_board_slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_quest_board_slot.add_theme_constant_override("separation", 12)
	_drawer_body.add_child(_quest_board_slot)
	_fill_quest_board(intro)


func _fill_quest_board(intro: bool) -> void:
	_clear_children(_quest_board_slot)
	var quests := _active_quests()
	var claimed_count := 0
	var ready_count := 0
	var ready_coins := 0
	for quest_value in quests:
		var quest := quest_value as Dictionary
		if bool(quest.get("claimed", false)):
			claimed_count += 1
		elif bool(quest.get("completed", false)):
			ready_count += 1
			ready_coins += int(quest.get("reward", 0))
	_quest_board_slot.add_child(_make_quest_summary(quests.size(), claimed_count, ready_count, ready_coins, intro))
	var scroll := ScrollContainer.new()
	scroll.name = "QuestScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_quest_board_slot.add_child(scroll)
	var scroll_gutter := MarginContainer.new()
	scroll_gutter.name = "QuestScrollGutter"
	scroll_gutter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Wide enough for a ready card's glow and for the scrollbar on the right.
	scroll_gutter.add_theme_constant_override("margin_left", 18)
	scroll_gutter.add_theme_constant_override("margin_top", 16)
	scroll_gutter.add_theme_constant_override("margin_right", 22)
	scroll_gutter.add_theme_constant_override("margin_bottom", 18)
	scroll.add_child(scroll_gutter)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll_gutter.add_child(list)
	if quests.is_empty():
		list.add_child(_drawer_label("No objectives right now. A fresh set arrives at the reset.", 13, UI_TOKENS.COLOR_MUTED))
	for index in quests.size():
		var card := _make_quest_card(quests[index] as Dictionary, intro, 0.12 + 0.07 * index)
		list.add_child(card)
		if intro:
			card.play_intro(0.08 + 0.07 * index)
	_apply_ui_font_tree(_quest_board_slot)


func _active_quests() -> Array:
	return (_progression.get("weekly_quests") as Array) if _quests_showing_weekly else (_progression.get("daily_quests") as Array)


func _make_quest_summary(total: int, claimed: int, ready: int, ready_coins: int, intro: bool) -> PanelContainer:
	var set_done := total > 0 and claimed == total
	var accent := SHOP_MINT if set_done else UI_TOKENS.COLOR_GOLD
	var summary := PanelContainer.new()
	summary.name = "QuestSummary"
	var style := _glass_panel_style(accent, 18, 0.6)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	summary.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	summary.add_child(row)
	var ring := PROGRESS_RING.new()
	ring.name = "SetProgress"
	ring.custom_minimum_size = Vector2(60, 60)
	ring.accent = accent
	ring.caption = "%d/%d" % [claimed, total]
	ring.caption_size = 14
	var ratio := float(claimed) / float(maxi(total, 1))
	ring.set_progress(0.0 if intro else _quest_ring_ratio, false)
	ring.set_progress(ratio, not _reduced_motion)
	_quest_ring_ratio = ratio
	row.add_child(ring)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	copy.add_theme_constant_override("separation", 2)
	row.add_child(copy)
	copy.add_child(_drawer_label("THIS WEEK'S OBJECTIVES" if _quests_showing_weekly else "TODAY'S OBJECTIVES", 16, UI_TOKENS.COLOR_TEXT))
	var detail := "Play naturally. Claim each reward the moment it's ready."
	var detail_color := Color(0.61, 0.72, 0.9)
	if ready > 0:
		detail = "%d READY  ·  +%d COINS WAITING" % [ready, ready_coins]
		detail_color = UI_TOKENS.COLOR_GOLD
	elif set_done:
		detail = "SET COMPLETE  ·  NICE WORK"
		detail_color = SHOP_MINT
	copy.add_child(_drawer_label(detail, 12, detail_color))
	if ready > 1:
		var claim_all := Button.new()
		claim_all.name = "ClaimAll"
		claim_all.text = "CLAIM ALL  +%d" % ready_coins
		claim_all.custom_minimum_size = Vector2(150, 42)
		claim_all.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		claim_all.focus_mode = Control.FOCUS_NONE
		claim_all.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_apply_primary_shop_button_style(claim_all, UI_TOKENS.COLOR_GOLD)
		claim_all.pressed.connect(func() -> void: _claim_all_quests(claim_all))
		PROGRESSION_FX.springy(claim_all)
		PROGRESSION_FX.breathe(claim_all, 0.14)
		row.add_child(claim_all)
	return summary


## One objective: a completion ring, the title with its count, a bar that
## fills on entry, and the reward button (disabled CLAIM while in progress,
## lit CLAIM when ready, COMPLETED once paid).
func _make_quest_card(quest: Dictionary, intro: bool, fill_delay: float) -> MenuCard:
	var claimed := bool(quest.get("claimed", false))
	var completed := bool(quest.get("completed", false)) or claimed
	var ready := completed and not claimed
	var target := maxi(1, int(quest.get("target", 1)))
	var progress := mini(target, int(quest.get("progress", 0)))
	var ratio := float(progress) / float(target)
	var accent := SHOP_MINT if claimed else (UI_TOKENS.COLOR_GOLD if completed else (Color(0.5, 0.58, 1.0) if _quests_showing_weekly else UI_TOKENS.COLOR_CYAN))
	var card := MENU_CARD.new("QuestCard_%s" % str(quest.get("id", "")), accent, false, Vector4(14, 12, 14, 12), 0.24 if ready else 0.12)
	card.custom_minimum_size = Vector2(0, 80)
	card.set_reduced_motion(_reduced_motion)
	card.set_highlighted(ready)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 14)
	card.content.add_child(row)
	var badge := PROGRESS_RING.new()
	badge.custom_minimum_size = Vector2(46, 46)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.accent = accent
	badge.thickness = 5.0
	badge.caption = "✓" if claimed else "%d%%" % int(round(ratio * 100.0))
	badge.caption_size = 10 if progress >= target else 11
	badge.set_progress(0.0 if intro else ratio, false)
	badge.set_progress(ratio, not _reduced_motion)
	row.add_child(badge)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.add_theme_constant_override("separation", 7)
	row.add_child(copy)
	var title_row := HBoxContainer.new()
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.add_child(title_row)
	var title := _drawer_label(str(quest.get("title", "Quest")), 15, UI_TOKENS.COLOR_MUTED if claimed else UI_TOKENS.COLOR_TEXT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_row.add_child(title)
	var status := "CLAIMED" if claimed else ("READY TO CLAIM" if ready else "%d / %d" % [progress, target])
	title_row.add_child(_drawer_label(status, 11, SHOP_MINT if claimed else (UI_TOKENS.COLOR_GOLD if ready else Color(0.63, 0.75, 0.93))))
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 8)
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.max_value = target
	bar.value = progress
	bar.add_theme_stylebox_override("background", _progress_style(Color(0.02, 0.03, 0.06), Color(0.14, 0.22, 0.38)))
	var fill := _progress_style(accent, Color.TRANSPARENT)
	fill.shadow_color = Color(accent, 0.45)
	fill.shadow_size = 5
	bar.add_theme_stylebox_override("fill", fill)
	copy.add_child(bar)
	if intro:
		PROGRESSION_FX.fill_bar(bar, 0.0, fill_delay)
	var reward := Button.new()
	reward.name = "QuestReward"
	reward.text = "COMPLETED" if claimed else "CLAIM  +%d" % int(quest.get("reward", 0))
	reward.custom_minimum_size = Vector2(138, 42)
	reward.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	reward.focus_mode = Control.FOCUS_NONE
	reward.disabled = not ready
	reward.add_theme_constant_override("icon_max_width", 16)
	_apply_primary_shop_button_style(reward, UI_TOKENS.COLOR_GOLD)
	if claimed:
		_apply_settled_button_style(reward, SHOP_MINT)
	else:
		reward.icon = COIN_ICON_SCRIPT.COIN_TEXTURE
	if ready:
		reward.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		reward.pressed.connect(_claim_quest.bind("weekly" if _quests_showing_weekly else "daily", str(quest.get("id", "")), reward))
		PROGRESSION_FX.breathe(reward, 0.16)
	PROGRESSION_FX.springy(reward)
	row.add_child(reward)
	return card


func _set_quest_tab(show_weekly: bool) -> void:
	if show_weekly == _quests_showing_weekly:
		return
	_quests_showing_weekly = show_weekly
	_quest_ring_ratio = 0.0
	if _quest_board_slot != null and is_instance_valid(_quest_board_slot) and _quest_board_slot.is_inside_tree():
		_update_quest_reset_label()
		_fill_quest_board(true)
	else:
		_build_progression(true)


## `source` is the button that asked; inside the drawer the coins fly from it
## into the header balance, which counts up as they land.
func _claim_quest(group: String, quest_id: String, source: Control = null) -> void:
	if _progression == null:
		return
	var in_drawer := is_progression_open()
	var from := source.get_global_rect().get_center() if is_instance_valid(source) else Vector2.ZERO
	_drawer_coin_flight = in_drawer
	var claimed := bool(_progression.call("claim_quest", group, quest_id))
	_drawer_coin_flight = false
	if claimed:
		_on_quests_claimed(from, in_drawer)


func _claim_all_quests(source: Control) -> void:
	var from := source.get_global_rect().get_center()
	var group := "weekly" if _quests_showing_weekly else "daily"
	var claimed_any := false
	_drawer_coin_flight = true
	for quest_value in _active_quests().duplicate():
		var quest := quest_value as Dictionary
		if bool(quest.get("completed", false)) and not bool(quest.get("claimed", false)):
			claimed_any = bool(_progression.call("claim_quest", group, str(quest.get("id", "")))) or claimed_any
	_drawer_coin_flight = false
	if claimed_any:
		_on_quests_claimed(from, true)


func _on_quests_claimed(from: Vector2, in_drawer: bool) -> void:
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null:
		audio.call("play_sfx", &"coin_collect", -8.0, 1.2)
	_show_progression_toast("QUEST CLAIMED", "Coins added to your balance")
	if not in_drawer:
		return
	_build_progression(false)
	var balance := int(_progression.call("get_balance"))
	var chip_center := _drawer_balance_chip.get_global_rect().get_center()
	PROGRESSION_FX.coin_burst(_shop_overlay, from if from != Vector2.ZERO else chip_center, chip_center, 8, func() -> void:
		_count_drawer_balance(balance)
		PROGRESSION_FX.punch(_drawer_balance_chip, 1.1)
	)


func _drawer_label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _coin_mark(edge: float) -> Control:
	var coin := Control.new()
	coin.custom_minimum_size = Vector2(edge, edge)
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	coin.set_script(COIN_ICON_SCRIPT)
	return coin


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


func _on_coin_balance_changed(balance: int, delta: int) -> void:
	_coin_target_balance = balance
	_pulse_coin_chip(delta > 0)
	if is_progression_open():
		if not _drawer_coin_flight:
			_count_drawer_balance(balance)
	elif delta > 0:
		_show_coin_earn(delta)
	_refresh_quest_panel()
	_refresh_menu_loadout()


func _on_quest_completed(quest: Dictionary, _reward: int) -> void:
	show_announcement("QUEST COMPLETE!  %s" % str(quest.get("title", "")), Color(0.35, 1.0, 0.56))
	_show_progression_toast("QUEST COMPLETE", str(quest.get("title", "")))


func _create_toast_stack() -> void:
	_toast_stack = VBoxContainer.new()
	_toast_stack.name = "ToastStack"
	_toast_stack.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	# Sits below the kill feed so a mid-match quest toast never covers it.
	_toast_stack.position = Vector2(-340, 168)
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
	if not is_progression_open():
		return
	_refresh_drawer_header()
	var scroll_offset := _shop_scroll.scroll_vertical if _active_progression_page == "shop" and is_instance_valid(_shop_scroll) else 0
	_build_progression(false)
	if scroll_offset <= 0:
		return
	# A purchase or equip rebuilds the grid; keep the player where they were
	# once the new grid has been laid out.
	await get_tree().process_frame
	if is_instance_valid(_shop_scroll):
		_shop_scroll.scroll_vertical = scroll_offset


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
	if _quest_reset_label != null:
		_quest_reset_label.text = _daily_reset_text()
	if _board_reset_label != null and is_instance_valid(_board_reset_label):
		_board_reset_label.text = "RESETS IN  %s" % (_weekly_reset_text() if _quests_showing_weekly else _daily_reset_text().trim_prefix("RESET  "))


func _daily_reset_text() -> String:
	var now := Time.get_time_dict_from_system()
	var remaining := maxi(0, 86400 - int(now.get("hour", 0)) * 3600 - int(now.get("minute", 0)) * 60 - int(now.get("second", 0)))
	return "RESET  %02d:%02d:%02d" % [remaining / 3600, (remaining % 3600) / 60, remaining % 60]


## Weekly quests rotate on whole Unix weeks (Progression's weekly key).
func _weekly_reset_text() -> String:
	var remaining := 604800 - (int(Time.get_unix_time_from_system()) % 604800)
	return "%dD  %02dH" % [remaining / 86400, (remaining % 86400) / 3600]


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
	code_input.text_changed.connect(_format_room_code_input)
	code_input.text_submitted.connect(func(_submitted_text: String) -> void: _submit_join())
	practice_button.pressed.connect(func() -> void: practice_requested.emit())
	bot_button.pressed.connect(func() -> void: bot_requested.emit(get_bot_difficulty()))
	match_format_button.pressed.connect(_cycle_match_format)
	_refresh_match_format_button()
	name_input.text_changed.connect(func(_new_text: String) -> void: _emit_identity())
	main_menu.copy_button.pressed.connect(_copy_room_code)
	main_menu.shop_button.pressed.connect(_set_progression_open.bind("shop"))
	main_menu.loadout_card.pressed.connect(_set_progression_open.bind("shop"))
	main_menu.quests_button.pressed.connect(_set_progression_open.bind("quests"))
	main_menu.settings_button.pressed.connect(func() -> void: settings_requested.emit())
	main_menu.quit_button.pressed.connect(func() -> void: get_tree().quit())
	var network_session := get_node_or_null("/root/NetworkSession")
	if network_session != null and network_session.has_signal("public_address_ready"):
		network_session.connect("public_address_ready", func(_code: String) -> void: _refresh_room_code())
	_create_ping_label()
	_refresh_room_code()


## Join doubles as Cancel while a connection attempt is in flight.
func _submit_join() -> void:
	var network_session := get_node_or_null("/root/NetworkSession")
	if network_session != null and network_session.has_method("is_joining") and bool(network_session.call("is_joining")):
		network_session.call("close_session")
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
