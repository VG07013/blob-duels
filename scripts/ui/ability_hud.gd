extends Control

const ICONS := {
	"dash": preload("res://assets/ui/abilities/dash.svg"),
	"ricochet_shot": preload("res://assets/ui/abilities/ricochet_shot.svg"),
	"quick_charge": preload("res://assets/ui/abilities/quick_charge.svg"),
	"blink": preload("res://assets/ui/abilities/blink.svg"),
	"target_scanner": preload("res://assets/ui/abilities/target_scanner.svg"),
	"overcharge": preload("res://assets/ui/abilities/overcharge.svg"),
	"gravity_pulse": preload("res://assets/ui/abilities/gravity_pulse.svg"),
	"rail_shot": preload("res://assets/ui/abilities/rail_shot.svg"),
	"bounce_mine": preload("res://assets/ui/abilities/bounce_mine.svg"),
	"phase_bubble": preload("res://assets/ui/abilities/phase_bubble.svg"),
	"adrenaline": preload("res://assets/ui/abilities/adrenaline.svg"),
	"shockwave": preload("res://assets/ui/abilities/shockwave.svg"),
}
const NAMES := {
	"dash": "DASH",
	"ricochet_shot": "RICOCHET SHOT",
	"quick_charge": "QUICK CHARGE",
	"blink": "BLINK",
	"target_scanner": "TARGET SCANNER",
	"overcharge": "OVERCHARGE",
	"gravity_pulse": "GRAVITY PULSE",
	"rail_shot": "RAIL SHOT",
	"bounce_mine": "BOUNCE MINE",
	"phase_bubble": "PHASE BUBBLE",
	"adrenaline": "ADRENALINE",
	"shockwave": "SHOCKWAVE",
}
const COOLDOWNS := {
	"dash": 7000.0,
	"ricochet_shot": 10000.0,
	"blink": 18000.0,
	"target_scanner": 20000.0,
	"overcharge": 15000.0,
	"gravity_pulse": 16000.0,
	"rail_shot": 15000.0,
	"bounce_mine": 18000.0,
	"phase_bubble": 25000.0,
	"shockwave": 14000.0,
}
const COLORS := {
	"dash": Color("36c9ff"),
	"ricochet_shot": Color("ffb52e"),
	"quick_charge": Color("43e29c"),
	"blink": Color("a87bff"),
	"target_scanner": Color("ff5c82"),
	"overcharge": Color("ff7a35"),
	"gravity_pulse": Color("7788ff"),
	"rail_shot": Color("37e0cf"),
	"bounce_mine": Color("e2d843"),
	"phase_bubble": Color("5ac8fa"),
	"adrenaline": Color("ff4b58"),
	"shockwave": Color("ffd23a"),
}

const ABILITY_ACTION := &"use_ability"
const DEFAULT_KEYBIND := "E"
## Matches the hotbar cards it sits beside: pale face, soft edge, dark key tab.
const FACE_COLOR := Color("E8F3FC")
const FACE_EDGE := Color("C9DDF0")
const BADGE_COLOR := Color("141A2A")
const BADGE_SIZE := 34.0

@onready var icon: TextureRect = $Icon
@onready var cooldown: Label = $Cooldown
@onready var ability_name: Label = $AbilityName
@onready var key_badge_label: Label = $KeyBadge/Label

var _ability_id := ""
var _progress := 1.0
var _unavailable := false
var _state_text := "READY"
var _was_ready := false
var _ready_tween: Tween
var _reduced_motion := false
# 1.0 right as a cooldown completes, easing to 0.0 as the flash ring expands
# and fades. Drawn on top of the cooldown ring.
var _ready_flash := 0.0


func _ready() -> void:
	# The ability is the hotbar's third item: a circle with its key tab and
	# nothing else - no ability name, no "READY" caption.
	ability_name.visible = false
	cooldown.visible = false
	cooldown.add_theme_color_override("font_color", BADGE_COLOR)
	cooldown.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.9))
	cooldown.add_theme_constant_override("outline_size", 6)
	resized.connect(_layout)
	_layout()
	_style_badge()


static func get_icon(ability_id: String) -> Texture2D:
	return ICONS.get(ability_id) as Texture2D


func set_reduced_motion(enabled: bool) -> void:
	_reduced_motion = enabled


## The key bound to the ability action, read from the live InputMap so a
## rebind in Settings is reflected without touching the HUD.
static func keybind_text() -> String:
	if not InputMap.has_action(ABILITY_ACTION):
		return DEFAULT_KEYBIND
	for event in InputMap.action_get_events(ABILITY_ACTION):
		var key := event as InputEventKey
		if key != null:
			var keycode := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
			if keycode != KEY_NONE:
				return OS.get_keycode_string(keycode).to_upper()
	return DEFAULT_KEYBIND


static func display_label(ability_id: String) -> String:
	return "%s  ·  %s" % [str(NAMES.get(ability_id, "ABILITY")), keybind_text()]


func is_ready_flash_active() -> bool:
	return _ready_flash > 0.0


func set_ability_state(ability_id: String, cooldown_remaining_msec: int, loaded: bool, active: bool, active_remaining_msec: int = 0, deployed: bool = false) -> void:
	visible = not ability_id.is_empty()
	if ability_id.is_empty():
		_was_ready = false
		return
	_ability_id = ability_id
	icon.texture = ICONS.get(ability_id)
	ability_name.text = display_label(ability_id)
	ability_name.visible = false
	if key_badge_label != null:
		key_badge_label.text = keybind_text()
	var passive := ability_id in ["quick_charge", "adrenaline"]
	var remaining := active_remaining_msec if active and active_remaining_msec > 0 else cooldown_remaining_msec
	var total := float(COOLDOWNS.get(ability_id, 1.0))
	_progress = 1.0 if passive or loaded or deployed else 1.0 - clampf(float(cooldown_remaining_msec) / total, 0.0, 1.0)
	_unavailable = active or loaded or deployed or cooldown_remaining_msec > 0
	var accent: Color = COLORS.get(ability_id, Color("36c9ff"))
	icon.modulate = Color(0.55, 0.6, 0.7, 0.45) if _unavailable else accent.darkened(0.15)
	_state_text = "PASSIVE" if passive else ("LOADED" if loaded else ("DEPLOYED" if deployed else ("ACTIVE" if active else ("READY" if cooldown_remaining_msec <= 0 else "COOLDOWN"))))
	# Only a countdown number ever shows on the circle; ready is just the
	# bright icon and full ring.
	var counting := remaining > 0 and _unavailable
	cooldown.visible = counting
	cooldown.text = "%.1f" % (float(remaining) / 1000.0) if counting else ""
	cooldown.add_theme_font_size_override("font_size", 28)
	var ready := not _unavailable and not passive and not loaded and not deployed
	if ready and not _was_ready:
		_animate_ready()
	_was_ready = ready
	queue_redraw()


func get_state_text() -> String:
	return _state_text


func _layout() -> void:
	var diameter := minf(size.x, size.y)
	var center := size * 0.5
	var icon_size := diameter * 0.48
	icon.position = center - Vector2.ONE * icon_size * 0.5
	icon.size = Vector2.ONE * icon_size
	cooldown.position = center - Vector2(diameter * 0.4, diameter * 0.2)
	cooldown.size = Vector2(diameter * 0.8, diameter * 0.4)
	var badge := key_badge_label.get_parent() as Control
	badge.position = Vector2(0.0, 0.0)
	badge.size = Vector2.ONE * BADGE_SIZE
	queue_redraw()


func _style_badge() -> void:
	var badge := key_badge_label.get_parent() as PanelContainer
	var style := StyleBoxFlat.new()
	style.bg_color = BADGE_COLOR
	style.border_color = Color.WHITE
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.anti_aliasing = true
	badge.add_theme_stylebox_override("panel", style)
	key_badge_label.add_theme_font_size_override("font_size", 20)
	key_badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_badge_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


func _draw() -> void:
	var diameter := minf(size.x, size.y)
	var center := size * 0.5
	var radius := diameter * 0.5 - 3.0
	var accent: Color = COLORS.get(_ability_id, Color("36c9ff"))
	draw_circle(center, radius + 2.0, FACE_EDGE)
	draw_circle(center, radius, FACE_COLOR)
	if _unavailable and _progress < 1.0:
		# Cooldown sweep: the part still recharging is shaded, clockwise from
		# the top, so the remaining time reads at a glance.
		var start_angle := -PI * 0.5 + TAU * _progress
		var points := PackedVector2Array([center])
		for step in range(0, 33):
			var angle := lerpf(start_angle, -PI * 0.5 + TAU, float(step) / 32.0)
			points.append(center + Vector2(cos(angle), sin(angle)) * radius)
		if points.size() >= 3:
			draw_colored_polygon(points, Color(0.08, 0.1, 0.16, 0.38))
	var ring_color := accent if not _unavailable else accent.darkened(0.25)
	draw_arc(center, radius - 3.0, -PI * 0.5, -PI * 0.5 + TAU * _progress, 64, ring_color, 6.0, true)
	if _ready_flash > 0.0:
		var growth := 1.0 - _ready_flash
		var flash_radius := radius + (2.0 if _reduced_motion else growth * 20.0)
		draw_arc(center, flash_radius, 0.0, TAU, 64, Color(1.0, 1.0, 1.0, _ready_flash * 0.9), 3.0, true)
		draw_circle(center, radius, Color(accent.r, accent.g, accent.b, _ready_flash * 0.25))


func _set_ready_flash(value: float) -> void:
	_ready_flash = value
	queue_redraw()


func _animate_ready() -> void:
	if _ready_tween != null and _ready_tween.is_valid():
		_ready_tween.kill()
	pivot_offset = size * 0.5
	# Light the flash on this frame; the tween below only fades it out.
	_set_ready_flash(1.0)
	_ready_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	if _reduced_motion:
		scale = Vector2.ONE
		modulate = Color(0.86, 1.0, 0.96)
		_ready_tween.set_parallel(true)
		_ready_tween.tween_method(_set_ready_flash, 1.0, 0.0, 0.3)
		_ready_tween.tween_property(self, "modulate", Color.WHITE, 0.3)
		return
	scale = Vector2(0.84, 0.84)
	modulate = Color(0.72, 1.0, 0.92)
	_ready_tween.set_parallel(true)
	_ready_tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_ready_tween.tween_property(self, "modulate", Color.WHITE, 0.3)
	_ready_tween.tween_method(_set_ready_flash, 1.0, 0.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_ready_tween.set_parallel(false)
	_ready_tween.tween_property(self, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Two subtle after-beats so the eye catches the ready state even if the
	# initial pop happened mid-fling.
	for beat in 2:
		_ready_tween.tween_property(self, "scale", Vector2(1.04, 1.04), 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_ready_tween.tween_property(self, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
