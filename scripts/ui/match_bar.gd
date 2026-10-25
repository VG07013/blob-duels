class_name MatchBar
extends RefCounted

## The duel's top bar: [ORANGE score] [match timer] [BLUE score], big and
## vibrant. The timer box also carries the 3-2-1-GO countdown and the round
## result: on a result it grows to many times its size (pushing the score
## boxes aside), drops the clock, and fades to green "ROUND WON!" or red
## "ROUND LOST".
##
## Built over the existing scoreboard nodes so their paths stay stable: the
## old centre "target" panel becomes an invisible spacer inside the HBox, and
## the TimerLabel is laid over that spacer every frame. Growing the spacer is
## what slides the score boxes outward.

const ORANGE := Color("FF7A1A")
const BLUE := Color("1E88FF")
const TIMER_BG := Color("141A2A")
const TIMER_BORDER := Color(1, 1, 1, 0.28)
const WON := Color("22C55E")
const LOST := Color("EF4444")
const DRAW := Color("8A94A6")
const TEXT := Color.WHITE
const URGENT_TEXT := Color("FFD54A")
const GO_TEXT := Color("7CFF6B")

const SCORE_SIZE := Vector2(112, 72)
const TIMER_SIZE := Vector2(176, 72)
const RESULT_SIZE := Vector2(500, 112)
const SCORE_FONT := 46
const TIMER_FONT := 42
const RESULT_FONT := 60

enum Mode { TIME, COUNTDOWN, RESULT }

## Round result kinds, from the local player's point of view.
const RESULT_DRAW := 0
const RESULT_WON := 1
const RESULT_LOST := 2

var _host: Node
var _scoreboard: HBoxContainer
var _orange_panel: PanelContainer
var _orange_value: Label
var _blue_panel: PanelContainer
var _blue_value: Label
var _spacer: PanelContainer
var _timer: Label
var _timer_style: StyleBoxFlat
var _font: Font
var _reduced_motion := false
var _mode := Mode.TIME
var _last_time_text := "1:30"
var _tween: Tween
var _beat_tween: Tween


func setup(host: Node, scoreboard: HBoxContainer, orange_panel: PanelContainer, orange_value: Label, blue_panel: PanelContainer, blue_value: Label, spacer: PanelContainer, spacer_label: Label, timer: Label, font: Font) -> void:
	_host = host
	_scoreboard = scoreboard
	_orange_panel = orange_panel
	_orange_value = orange_value
	_blue_panel = blue_panel
	_blue_value = blue_value
	_spacer = spacer
	_timer = timer
	_font = font
	# Size to content and grow from the centre, so a growing timer box pushes
	# both score boxes outward evenly.
	_scoreboard.offset_left = 0.0
	_scoreboard.offset_right = 0.0
	_scoreboard.offset_top = 16.0
	_scoreboard.offset_bottom = 16.0
	_scoreboard.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_scoreboard.alignment = BoxContainer.ALIGNMENT_CENTER
	_scoreboard.add_theme_constant_override("separation", 10)
	_style_score(_orange_panel, _orange_value, ORANGE)
	_style_score(_blue_panel, _blue_value, BLUE)
	_spacer.custom_minimum_size = TIMER_SIZE
	_spacer.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	spacer_label.text = ""
	spacer_label.visible = false
	_timer_style = _box_style(TIMER_BG, TIMER_BORDER)
	_timer.add_theme_stylebox_override("normal", _timer_style)
	_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_apply_label_font(_timer, TIMER_FONT, TEXT)
	_timer.text = _last_time_text


func set_reduced_motion(enabled: bool) -> void:
	_reduced_motion = enabled


func set_scores(orange_score: int, blue_score: int) -> void:
	_orange_value.text = str(orange_score)
	_blue_value.text = str(blue_score)


func set_time(seconds_remaining: float) -> void:
	var whole := maxi(0, int(ceil(seconds_remaining)))
	_last_time_text = "%d:%02d" % [whole / 60, whole % 60]
	if _mode != Mode.TIME:
		return
	_timer.text = _last_time_text
	_timer.add_theme_color_override("font_color", URGENT_TEXT if whole <= 10 else TEXT)


func get_mode() -> int:
	return _mode


## One beat of the round-start countdown ("3", "2", "1", "GO!"), shown in the
## timer box itself. "GO!" hands the box back to the clock shortly after.
func countdown_beat(text: String) -> void:
	# A result owns the box until reset_result() hands it back.
	if _mode == Mode.RESULT:
		return
	_mode = Mode.COUNTDOWN
	_timer.text = text
	var is_go := text == "GO!"
	_timer.add_theme_color_override("font_color", GO_TEXT if is_go else TEXT)
	_pop(_timer)
	if not is_go:
		return
	var hand_back := _host.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	hand_back.tween_interval(0.7)
	hand_back.tween_callback(_return_to_clock)


## Round over: the clock disappears and the box grows big, sliding the score
## boxes aside, while its colour eases to green (won), red (lost) or grey.
func show_result(kind: int, text: String) -> void:
	_mode = Mode.RESULT
	var target := DRAW
	if kind == RESULT_WON:
		target = WON
	elif kind == RESULT_LOST:
		target = LOST
	_timer.text = text
	_timer.add_theme_color_override("font_color", TEXT)
	_kill(_tween)
	_tween = _host.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	var duration := 0.12 if _reduced_motion else 0.55
	_tween.tween_property(_spacer, "custom_minimum_size", RESULT_SIZE, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_timer_style, "bg_color", target, duration * 1.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(_timer_style, "border_color", target.lightened(0.45), duration * 1.3)
	_tween.tween_property(_timer_style, "shadow_color", Color(target.r, target.g, target.b, 0.55), duration * 1.3)
	_tween.tween_method(_set_timer_font_size, float(TIMER_FONT), float(RESULT_FONT), duration)


## Back to a normal clock for the next round's countdown.
func reset_result() -> void:
	if _mode != Mode.RESULT and _spacer.custom_minimum_size == TIMER_SIZE:
		return
	_mode = Mode.TIME
	_kill(_tween)
	_tween = _host.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	var duration := 0.08 if _reduced_motion else 0.35
	_tween.tween_property(_spacer, "custom_minimum_size", TIMER_SIZE, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_timer_style, "bg_color", TIMER_BG, duration)
	_tween.tween_property(_timer_style, "border_color", TIMER_BORDER, duration)
	_tween.tween_property(_timer_style, "shadow_color", Color(0, 0, 0, 0.35), duration)
	_tween.tween_method(_set_timer_font_size, float(RESULT_FONT), float(TIMER_FONT), duration)
	_timer.text = _last_time_text


func is_showing_result() -> bool:
	return _mode == Mode.RESULT


func get_timer_text() -> String:
	return _timer.text


## Lays the timer box over the spacer. Called every frame by the HUD.
func sync_layout() -> void:
	if not _scoreboard.is_visible_in_tree():
		return
	_timer.global_position = _spacer.global_position
	_timer.size = _spacer.size
	_timer.pivot_offset = _timer.size * 0.5


func _return_to_clock() -> void:
	if _mode != Mode.COUNTDOWN:
		return
	_mode = Mode.TIME
	_timer.text = _last_time_text
	_timer.add_theme_color_override("font_color", TEXT)


func _set_timer_font_size(value: float) -> void:
	_timer.add_theme_font_size_override("font_size", int(round(value)))


func _pop(target: Control) -> void:
	if _reduced_motion:
		return
	_kill(_beat_tween)
	target.pivot_offset = target.size * 0.5
	target.scale = Vector2(1.35, 1.35)
	_beat_tween = _host.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_beat_tween.tween_property(target, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _style_score(panel: PanelContainer, value: Label, color: Color) -> void:
	panel.custom_minimum_size = SCORE_SIZE
	panel.add_theme_stylebox_override("panel", _box_style(color, color.lightened(0.4)))
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_apply_label_font(value, SCORE_FONT, TEXT)


func _apply_label_font(label: Label, font_size: int, color: Color) -> void:
	if _font != null:
		label.add_theme_font_override("font", _font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
	label.add_theme_constant_override("outline_size", 8)


func _box_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(3)
	style.set_corner_radius_all(20)
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 10
	style.shadow_offset = Vector2(0, 4)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.anti_aliasing = true
	return style


func _kill(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()
