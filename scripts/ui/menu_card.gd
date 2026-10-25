class_name MenuCard
extends PanelContainer

## One glass surface on the main menu. The look comes from
## `menu_card.gdshader`, drawn a little larger than the card so the hover glow
## can spill past its edge. A clickable card puts a flat full-size Button
## *behind* its content: the Button owns clicks, `disabled`, and the UI
## sounds, while labels on top ignore the mouse and inner controls (segments,
## inputs) still take their own clicks.

signal pressed

const CARD_SHADER: Shader = preload("res://assets/materials/menu_card.gdshader")
const GLOW_MARGIN := 26.0
const HOVER_SCALE := 1.018
const PRESS_SCALE := 0.975
const INTRO_SECONDS := 0.5

var accent := Color(0.02, 0.82, 1.0)
## Holds the hover glow on without a pointer: the shop's selected item, a
## quest that is ready to claim.
var highlighted := false
## The Button behind the content, or null for a passive card.
var hit_button: Button
## Where callers put the card's content.
var content: VBoxContainer

var _material := ShaderMaterial.new()
var _hover := 0.0
var _pressed_down := false
var _enabled_alpha := 1.0
var _touch_scale := 1.0
var _intro_clock := INTRO_SECONDS
var _reduced_motion := false


func _init(card_name: String, card_accent: Color, clickable: bool, padding := Vector4(18, 14, 18, 14), accent_strength := 0.22) -> void:
	name = card_name
	accent = card_accent
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	mouse_filter = Control.MOUSE_FILTER_PASS
	_material.shader = CARD_SHADER
	_material.set_shader_parameter("accent", accent)
	_material.set_shader_parameter("accent_strength", accent_strength)
	_material.set_shader_parameter("shine_enabled", 1.0 if clickable else 0.0)
	_material.set_shader_parameter("shine_offset", randf() * 5.5)
	material = _material
	if clickable:
		hit_button = Button.new()
		hit_button.name = card_name + "Hit"
		hit_button.flat = true
		hit_button.focus_mode = Control.FOCUS_NONE
		hit_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		for style_name in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
			hit_button.add_theme_stylebox_override(style_name, StyleBoxEmpty.new())
		hit_button.pressed.connect(func() -> void: pressed.emit())
		hit_button.button_down.connect(_set_pressed_down.bind(true))
		hit_button.button_up.connect(_set_pressed_down.bind(false))
		add_child(hit_button)
	var margin := MarginContainer.new()
	margin.name = "Padding"
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", int(padding.x))
	margin.add_theme_constant_override("margin_top", int(padding.y))
	margin.add_theme_constant_override("margin_right", int(padding.z))
	margin.add_theme_constant_override("margin_bottom", int(padding.w))
	add_child(margin)
	content = VBoxContainer.new()
	content.name = "Content"
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation", 8)
	margin.add_child(content)


func _ready() -> void:
	resized.connect(_sync_geometry)
	_sync_geometry()


func set_reduced_motion(enabled: bool) -> void:
	_reduced_motion = enabled
	_material.set_shader_parameter("motion_scale", 0.0 if enabled else 1.0)


func set_accent(value: Color) -> void:
	accent = value
	_material.set_shader_parameter("accent", accent)


func set_highlighted(enabled: bool) -> void:
	highlighted = enabled


## Pops the card in (fade plus a small overshoot) after `delay` seconds.
## Scale and alpha only: containers own position, so a slide would fight
## the layout.
func play_intro(delay: float) -> void:
	_intro_clock = -delay
	if not _reduced_motion:
		# Start pose now, not on the next _process, so the card never flashes
		# in at full opacity for a frame.
		modulate.a = 0.0
		scale = Vector2.ONE * 0.9


## Names the hit Button so the HUD and tests can find it as the action
## ("PracticeChoice", "BotChoice", ...).
func set_action_name(action_name: String, tooltip: String) -> void:
	if hit_button == null:
		return
	hit_button.name = action_name
	hit_button.tooltip_text = tooltip


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_intro_clock = minf(_intro_clock + delta, INTRO_SECONDS)
	var intro := 1.0 if _reduced_motion else clampf(_intro_clock / INTRO_SECONDS, 0.0, 1.0)
	var interactive := hit_button != null and not hit_button.disabled
	var hovered := get_global_rect().has_point(get_global_mouse_position())
	var target := 0.0
	if hovered:
		target = 1.0 if interactive else 0.35
	if highlighted:
		target = maxf(target, 0.62)
	_hover = move_toward(_hover, target, delta * 6.0)
	_material.set_shader_parameter("hover", _hover)
	_enabled_alpha = move_toward(_enabled_alpha, 1.0 if hit_button == null or interactive else 0.55, delta * 5.0)
	modulate.a = clampf(intro * 1.8, 0.0, 1.0) * _enabled_alpha
	var goal := 1.0
	if _pressed_down:
		goal = PRESS_SCALE
	elif hovered and interactive and not _reduced_motion:
		goal = HOVER_SCALE
	_touch_scale = lerpf(_touch_scale, goal, minf(1.0, delta * 14.0))
	scale = Vector2.ONE * _touch_scale * lerpf(0.9, 1.0, _ease_out_back(intro))


func _draw() -> void:
	draw_rect(Rect2(Vector2(-GLOW_MARGIN, -GLOW_MARGIN), size + Vector2.ONE * GLOW_MARGIN * 2.0), Color.WHITE)


func _sync_geometry() -> void:
	pivot_offset = size * 0.5
	_material.set_shader_parameter("card_size", size)
	queue_redraw()


func _set_pressed_down(down: bool) -> void:
	_pressed_down = down


static func _ease_out_back(t: float) -> float:
	return 1.0 + 2.70158 * pow(t - 1.0, 3.0) + 1.70158 * pow(t - 1.0, 2.0)
