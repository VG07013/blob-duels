class_name DuelFeedbackLayer
extends Control

## Combat feedback that sits on top of the duel HUD: pooled floating damage
## numbers, the kill feed, the low-health vignette, the directional damage arc,
## the elimination ring, and the round-intro card. Owned and driven by DuelHud;
## everything here is presentation only and knows nothing about the network.

const KILL_FEED_MAX := 3
const KILL_FEED_LIFETIME := 4.0
const DAMAGE_NUMBER_POOL_SIZE := 12
## Hits on the same target within this window add into one running number.
## Untagged hits (no target key) merge when they land this close on screen.
const DAMAGE_NUMBER_COMBO_WINDOW_MSEC := 1000
const DAMAGE_NUMBER_COMBO_RADIUS := 96.0
const DAMAGE_NUMBER_RISE := 38.0
const LOW_HEALTH_VIGNETTE_RATIO := 0.3
const DAMAGE_DIRECTION_LIFETIME := 0.9
const DAMAGE_DIRECTION_RADIUS := 76.0
const ELIMINATION_RING_LIFETIME := 0.55
const CAUSE_LABELS := {
	"shot": "",
	"ricochet": "RICOCHET",
	"rail": "RAIL",
	"collision": "SLAM",
	"knockout": "KNOCKOUT",
	"interactable": "INTERACTABLE",
}

var _reduced_motion := false
var _ui_font: Font
var _feed: VBoxContainer
var _numbers_root: Control
var _number_pool: Array[Label] = []
var _number_cursor := 0
## Live running totals: target key -> {"label", "total", "time", "position"}.
var _combos: Dictionary = {}
var _vignette: TextureRect
var _vignette_active := false
var _vignette_phase := 0.0
var _direction_angle := 0.0
var _direction_time := 0.0
var _elimination_ring_time := 0.0
var _round_intro: PanelContainer
var _round_intro_title: Label
var _round_intro_red: Label
var _round_intro_blue: Label
var _round_intro_score: Label
var _round_intro_key := ""
var _round_intro_tween: Tween


class FeedArrow extends Control:
	var tint := Color(0.78, 0.86, 0.96)

	func _ready() -> void:
		custom_minimum_size = Vector2(26, 12)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var mid_y := size.y * 0.5
		var tail := Vector2(2.0, mid_y)
		var head := Vector2(size.x - 2.0, mid_y)
		draw_line(tail, head, tint, 2.0, true)
		draw_line(head, head + Vector2(-6.0, -5.0), tint, 2.0, true)
		draw_line(head, head + Vector2(-6.0, 5.0), tint, 2.0, true)


func _ready() -> void:
	name = "DuelFeedback"
	# Anchors and offsets together: anchors alone left the layer zero-sized, so
	# every centred or right-aligned child measured from the top-left corner.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_create_vignette()
	_create_damage_numbers()
	_create_kill_feed()
	_create_round_intro()


func set_reduced_motion(enabled: bool) -> void:
	_reduced_motion = enabled


func is_reduced_motion() -> bool:
	return _reduced_motion


func set_ui_font(font: Font) -> void:
	_ui_font = font
	if font == null:
		return
	for label in _number_pool:
		label.add_theme_font_override("font", font)
	if _round_intro != null:
		for candidate in _round_intro.find_children("*", "Control", true, false):
			(candidate as Control).add_theme_font_override("font", font)


## Hides everything transient. Called on lobby return and at the victory
## cinematic so a stale feed never sits over the results.
func reset() -> void:
	for child in _feed.get_children():
		child.free()
	for label in _number_pool:
		label.visible = false
	_combos.clear()
	_direction_time = 0.0
	_elimination_ring_time = 0.0
	_vignette_active = false
	_vignette.visible = false
	hide_round_intro()
	queue_redraw()


# --- Damage numbers -----------------------------------------------------------

func _create_damage_numbers() -> void:
	_numbers_root = Control.new()
	_numbers_root.name = "DamageNumbers"
	_numbers_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_numbers_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_numbers_root)
	for index in DAMAGE_NUMBER_POOL_SIZE:
		var label := Label.new()
		label.name = "DamageNumber%d" % index
		label.visible = false
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_outline_color", Color(0.01, 0.02, 0.04, 0.92))
		label.add_theme_constant_override("outline_size", 6)
		_numbers_root.add_child(label)
		_number_pool.append(label)


func damage_number_pool_size() -> int:
	return _number_pool.size()


func active_damage_number_count() -> int:
	var count := 0
	for label in _number_pool:
		if label.visible:
			count += 1
	return count


## Colour and size scale with the hit so a rail crit reads differently from a
## chip shot even before the number is parsed.
func damage_number_style(amount: int, kind: String) -> Dictionary:
	var color := Color(0.96, 0.98, 1.0)
	var font_size := 18
	if amount >= 40:
		color = Color(1.0, 0.36, 0.28)
		font_size = 26
	elif amount >= 25:
		color = Color(1.0, 0.78, 0.22)
		font_size = 22
	match kind:
		"rail":
			color = Color(0.58, 0.96, 1.0)
			font_size = maxi(font_size, 26)
		"ricochet":
			color = Color(1.0, 0.6, 0.18)
			font_size = maxi(font_size, 22)
		"elimination":
			color = Color(1.0, 0.28, 0.3)
			font_size = maxi(font_size, 28)
	return {"color": color, "font_size": font_size}


## Shows a floating damage number. Repeated hits on the same target (same
## `target_key`, or for untagged hits the same screen spot) within
## DAMAGE_NUMBER_COMBO_WINDOW_MSEC add into one running total that re-pops at
## the latest impact, instead of spawning a pile of numbers.
func show_damage_number_at(amount: int, screen_position: Vector2, kind := "hit", target_key := "") -> Label:
	if amount <= 0:
		return null
	var now := Time.get_ticks_msec()
	var combo_key := _combo_key_for(target_key, screen_position, now)
	var combo := _combos.get(combo_key, {}) as Dictionary
	var label := combo.get("label") as Label
	var total := amount
	if label != null and label.visible and now - int(combo.get("time", 0)) <= DAMAGE_NUMBER_COMBO_WINDOW_MSEC:
		total += int(combo.get("total", 0))
	else:
		label = _number_pool[_number_cursor]
		_number_cursor = (_number_cursor + 1) % _number_pool.size()
		_forget_label(label)
	_combos[combo_key] = {"label": label, "total": total, "time": now, "position": screen_position}
	_pop_number(label, total, screen_position, kind)
	return label


func _combo_key_for(target_key: String, screen_position: Vector2, now: int) -> String:
	if not target_key.is_empty():
		return target_key
	for key in _combos:
		var combo := _combos[key] as Dictionary
		if str(key).begins_with("@") and now - int(combo.get("time", 0)) <= DAMAGE_NUMBER_COMBO_WINDOW_MSEC \
				and (combo.get("position", Vector2.ZERO) as Vector2).distance_to(screen_position) <= DAMAGE_NUMBER_COMBO_RADIUS:
			return str(key)
	return "@%d" % now


## A pooled label is being recycled: drop any running total still pointing at it.
func _forget_label(label: Label) -> void:
	for key in _combos.keys():
		if (_combos[key] as Dictionary).get("label") == label:
			_combos.erase(key)


func _pop_number(label: Label, total: int, screen_position: Vector2, kind: String) -> void:
	var existing := label.get_meta(&"number_tween") as Tween if label.has_meta(&"number_tween") else null
	if existing != null and existing.is_valid():
		existing.kill()
	var style := damage_number_style(total, kind)
	label.text = "%d" % total
	label.add_theme_font_size_override("font_size", int(style.get("font_size", 18)))
	label.add_theme_color_override("font_color", style.get("color", Color.WHITE))
	if _ui_font != null:
		label.add_theme_font_override("font", _ui_font)
	label.size = Vector2(96, 32)
	label.pivot_offset = label.size * 0.5
	var start := screen_position - label.size * 0.5 + Vector2(0.0, -20.0)
	label.position = start
	label.modulate = Color(1, 1, 1, 1)
	label.scale = Vector2.ONE if _reduced_motion else Vector2(0.7, 0.7)
	label.visible = true
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	label.set_meta(&"number_tween", tween)
	tween.set_parallel(true)
	if not _reduced_motion:
		tween.tween_property(label, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(label, "position:y", start.y - DAMAGE_NUMBER_RISE, 0.72).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(label, "modulate:a", 0.0, 0.42).set_delay(0.3)
	else:
		tween.tween_property(label, "modulate:a", 0.0, 0.3).set_delay(0.25)
	tween.set_parallel(false)
	tween.tween_callback(func() -> void: label.visible = false)


# --- Kill feed ------------------------------------------------------------------

const KILL_FEED_WIDTH := 332.0
const KILL_FEED_RIGHT_MARGIN := 24.0
## Below the coin chip and the quest toasts' first slot.
const KILL_FEED_TOP := 56.0


func _create_kill_feed() -> void:
	_feed = VBoxContainer.new()
	_feed.name = "KillFeed"
	_feed.anchor_left = 1.0
	_feed.anchor_right = 1.0
	_feed.anchor_top = 0.0
	_feed.anchor_bottom = 0.0
	_feed.offset_left = -KILL_FEED_RIGHT_MARGIN - KILL_FEED_WIDTH
	_feed.offset_right = -KILL_FEED_RIGHT_MARGIN
	_feed.offset_top = KILL_FEED_TOP
	_feed.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_feed.custom_minimum_size = Vector2(KILL_FEED_WIDTH, 0)
	_feed.alignment = BoxContainer.ALIGNMENT_BEGIN
	_feed.add_theme_constant_override("separation", 6)
	_feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_feed)


func feed_entry_count() -> int:
	return _feed.get_child_count()


func feed_entries() -> Array:
	return _feed.get_children()


## "Killer -> Victim (CAUSE)". Colours are the blobs' own so the line reads at
## a glance which side scored.
func add_kill_feed_entry(killer_name: String, killer_color: Color, victim_name: String, victim_color: Color, cause := "shot") -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_child(_feed_label(killer_name, killer_color.lightened(0.15), 14))
	var arrow := FeedArrow.new()
	arrow.tint = Color(0.8, 0.88, 0.98)
	row.add_child(arrow)
	row.add_child(_feed_label(victim_name, victim_color.lightened(0.15), 14))
	var cause_text := str(CAUSE_LABELS.get(cause, cause.to_upper()))
	if not cause_text.is_empty():
		var cause_label := _feed_label("(%s)" % cause_text, Color(0.66, 0.74, 0.84), 11)
		row.add_child(cause_label)
	return _push_feed_row(row, killer_color)


## Free-form line for deaths without a scorer ("Rival fell out of the arena").
func add_feed_message(text: String, color: Color) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_child(_feed_label(text, color.lightened(0.1), 13))
	return _push_feed_row(row, color)


func _feed_label(text: String, color: Color, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.01, 0.02, 0.04, 0.9))
	label.add_theme_constant_override("outline_size", 4)
	if _ui_font != null:
		label.add_theme_font_override("font", _ui_font)
	return label


func _push_feed_row(row: Control, accent: Color) -> Control:
	while _feed.get_child_count() >= KILL_FEED_MAX:
		_feed.get_child(0).free()
	var entry := PanelContainer.new()
	entry.name = "FeedEntry"
	entry.mouse_filter = Control.MOUSE_FILTER_IGNORE
	entry.size_flags_horizontal = Control.SIZE_SHRINK_END
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.03, 0.055, 0.72)
	style.border_color = Color(accent.r, accent.g, accent.b, 0.55)
	style.border_width_right = 3
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	entry.add_theme_stylebox_override("panel", style)
	entry.add_child(row)
	entry.set_meta(&"expires_at", Time.get_ticks_msec() + int(KILL_FEED_LIFETIME * 1000.0))
	_feed.add_child(entry)
	entry.modulate.a = 0.0
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(entry, "modulate:a", 1.0, 0.05 if _reduced_motion else 0.14)
	tween.tween_interval(KILL_FEED_LIFETIME)
	tween.tween_property(entry, "modulate:a", 0.0, 0.08 if _reduced_motion else 0.32)
	tween.tween_callback(func() -> void:
		if is_instance_valid(entry):
			entry.queue_free()
	)
	return entry


# --- Low-health vignette --------------------------------------------------------

func _create_vignette() -> void:
	_vignette = TextureRect.new()
	_vignette.name = "LowHealthVignette"
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vignette.visible = false
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.58, 1.0])
	gradient.colors = PackedColorArray([Color(0.6, 0.02, 0.05, 0.0), Color(0.62, 0.03, 0.06, 0.0), Color(0.7, 0.04, 0.08, 0.62)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 1.0)
	texture.width = 256
	texture.height = 256
	_vignette.texture = texture
	add_child(_vignette)


## Health ratio below LOW_HEALTH_VIGNETTE_RATIO edges the screen in red; the
## alpha breathes slowly unless reduced motion is on.
func set_low_health_ratio(ratio: float) -> void:
	var active := ratio < LOW_HEALTH_VIGNETTE_RATIO
	if active == _vignette_active:
		return
	_vignette_active = active
	_vignette.visible = active
	_vignette.modulate.a = 1.0
	_vignette_phase = 0.0


func is_low_health_vignette_active() -> bool:
	return _vignette_active


# --- Directional damage + elimination ring ---------------------------------------

## `screen_angle` is radians clockwise from straight up, so 0 points ahead and
## PI * 0.5 points to the player's right.
func show_damage_direction_angle(screen_angle: float) -> void:
	_direction_angle = screen_angle
	_direction_time = DAMAGE_DIRECTION_LIFETIME * (0.55 if _reduced_motion else 1.0)
	queue_redraw()


func is_damage_direction_active() -> bool:
	return _direction_time > 0.0


func damage_direction_angle() -> float:
	return _direction_angle


func flash_elimination_ring() -> void:
	_elimination_ring_time = ELIMINATION_RING_LIFETIME * (0.5 if _reduced_motion else 1.0)
	queue_redraw()


func is_elimination_ring_active() -> bool:
	return _elimination_ring_time > 0.0


func _draw() -> void:
	var center := size * 0.5
	if _direction_time > 0.0:
		var life := clampf(_direction_time / DAMAGE_DIRECTION_LIFETIME, 0.0, 1.0)
		var start := _direction_angle - PI * 0.5 - 0.42
		var end := _direction_angle - PI * 0.5 + 0.42
		var radius := DAMAGE_DIRECTION_RADIUS + (0.0 if _reduced_motion else (1.0 - life) * 10.0)
		draw_arc(center, radius, start, end, 24, Color(1.0, 0.22, 0.24, life * 0.9), 6.0, true)
		draw_arc(center, radius + 7.0, start + 0.12, end - 0.12, 20, Color(1.0, 0.5, 0.5, life * 0.35), 2.0, true)
	if _elimination_ring_time > 0.0:
		var ring_life := clampf(_elimination_ring_time / ELIMINATION_RING_LIFETIME, 0.0, 1.0)
		var growth := 1.0 - ring_life
		var radius := 26.0 + (0.0 if _reduced_motion else growth * 54.0)
		draw_arc(center, radius, 0.0, TAU, 48, Color(1.0, 0.28, 0.3, ring_life * 0.85), 4.0, true)


func _process(delta: float) -> void:
	var needs_redraw := false
	if _direction_time > 0.0:
		_direction_time = maxf(_direction_time - delta, 0.0)
		needs_redraw = true
	if _elimination_ring_time > 0.0:
		_elimination_ring_time = maxf(_elimination_ring_time - delta, 0.0)
		needs_redraw = true
	if _vignette_active and not _reduced_motion:
		_vignette_phase += delta * 2.4
		_vignette.modulate.a = 0.78 + 0.22 * (0.5 + 0.5 * sin(_vignette_phase))
	if needs_redraw:
		queue_redraw()


# --- Round intro card -------------------------------------------------------------

const ROUND_INTRO_HALF_WIDTH := 230.0
## Just under the countdown banner (hud.tscn Announcement ends at 238).
const ROUND_INTRO_TOP := 250.0
const ROUND_INTRO_HEIGHT := 84.0


func _create_round_intro() -> void:
	_round_intro = PanelContainer.new()
	_round_intro.name = "RoundIntro"
	# Offsets, not position: assigning position after the anchors converted it
	# against the layer's size at creation and parked the card off the left
	# edge of the screen. It sits centred just under the countdown banner.
	_round_intro.anchor_left = 0.5
	_round_intro.anchor_right = 0.5
	_round_intro.anchor_top = 0.0
	_round_intro.anchor_bottom = 0.0
	_round_intro.offset_left = -ROUND_INTRO_HALF_WIDTH
	_round_intro.offset_right = ROUND_INTRO_HALF_WIDTH
	_round_intro.offset_top = ROUND_INTRO_TOP
	_round_intro.offset_bottom = ROUND_INTRO_TOP + ROUND_INTRO_HEIGHT
	_round_intro.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_round_intro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_round_intro.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.03, 0.055, 0.84)
	style.border_color = Color(0.34, 0.78, 1.0, 0.5)
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	_round_intro.add_theme_stylebox_override("panel", style)
	add_child(_round_intro)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 4)
	_round_intro.add_child(stack)
	_round_intro_title = Label.new()
	_round_intro_title.name = "Title"
	_round_intro_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_round_intro_title.add_theme_font_size_override("font_size", 13)
	_round_intro_title.add_theme_color_override("font_color", Color(0.7, 0.86, 1.0))
	stack.add_child(_round_intro_title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	stack.add_child(row)
	_round_intro_red = Label.new()
	_round_intro_red.name = "RedName"
	_round_intro_red.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_round_intro_red.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_round_intro_red.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_round_intro_red.add_theme_font_size_override("font_size", 19)
	row.add_child(_round_intro_red)
	_round_intro_score = Label.new()
	_round_intro_score.name = "Score"
	_round_intro_score.custom_minimum_size = Vector2(88, 0)
	_round_intro_score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_round_intro_score.add_theme_font_size_override("font_size", 24)
	_round_intro_score.add_theme_color_override("font_color", Color(0.96, 0.98, 1.0))
	row.add_child(_round_intro_score)
	_round_intro_blue = Label.new()
	_round_intro_blue.name = "BlueName"
	_round_intro_blue.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_round_intro_blue.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_round_intro_blue.add_theme_font_size_override("font_size", 19)
	row.add_child(_round_intro_blue)


## Shown for the countdown of each round. Re-calling with the same round and
## score is a no-op so the three countdown beats do not restart the entrance.
func show_round_intro(round_number: int, score_target: int, red_name: String, red_color: Color, blue_name: String, blue_color: Color, red_score: int, blue_score: int) -> void:
	var key := "%d:%d:%d" % [round_number, red_score, blue_score]
	if _round_intro.visible and _round_intro_key == key:
		return
	_round_intro_key = key
	_round_intro_title.text = "ROUND %d  ·  FIRST TO %d" % [maxi(1, round_number), score_target]
	_round_intro_red.text = red_name
	_round_intro_red.add_theme_color_override("font_color", red_color.lightened(0.25))
	_round_intro_blue.text = blue_name
	_round_intro_blue.add_theme_color_override("font_color", blue_color.lightened(0.25))
	_round_intro_score.text = "%d  —  %d" % [red_score, blue_score]
	if _round_intro_tween != null and _round_intro_tween.is_valid():
		_round_intro_tween.kill()
	_round_intro.visible = true
	_round_intro.pivot_offset = _round_intro.size * 0.5
	_round_intro.modulate.a = 0.0
	_round_intro.scale = Vector2.ONE if _reduced_motion else Vector2(0.92, 0.92)
	_round_intro_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_round_intro_tween.set_parallel(true)
	_round_intro_tween.tween_property(_round_intro, "modulate:a", 1.0, 0.06 if _reduced_motion else 0.2)
	if not _reduced_motion:
		_round_intro_tween.tween_property(_round_intro, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func hide_round_intro() -> void:
	_round_intro_key = ""
	if not _round_intro.visible:
		return
	if _round_intro_tween != null and _round_intro_tween.is_valid():
		_round_intro_tween.kill()
	if _reduced_motion:
		_round_intro.visible = false
		return
	_round_intro_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_round_intro_tween.tween_property(_round_intro, "modulate:a", 0.0, 0.22)
	_round_intro_tween.tween_callback(func() -> void: _round_intro.visible = false)


func is_round_intro_visible() -> bool:
	return _round_intro.visible and _round_intro_key != ""


func round_intro_title() -> String:
	return _round_intro_title.text
