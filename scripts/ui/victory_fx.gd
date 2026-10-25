class_name VictoryFx
extends Control

## Presentation layer for the end-of-match flow, owned by DuelHud and drawn
## just beneath VictoryOverlay: letterbox bars and a winner callout while the
## camera celebrates, then a vignette, a team-coloured glow behind the title,
## and a confetti burst when the results arrive. Layout and motion only;
## DuelHud decides what the results say.

const LETTERBOX_SHARE := 0.11
const CONFETTI_AMOUNT := 150
const CONFETTI_LIFETIME := 3.4
const GOLD := Color(1.0, 0.8, 0.3)

var _top_bar: ColorRect
var _bottom_bar: ColorRect
var _callout: VBoxContainer
var _callout_shade: TextureRect
var _callout_eyebrow: Label
var _callout_title: Label
var _vignette: TextureRect
var _glow: TextureRect
var _confetti: CPUParticles2D
var _tween: Tween


func _init() -> void:
	name = "VictoryFx"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_vignette = TextureRect.new()
	_vignette.name = "Vignette"
	_vignette.texture = _radial_texture([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0.0, 0.01, 0.03, 0.78)], [0.0, 0.42, 1.0], Vector2(0.5, 0.5), Vector2(1.08, 1.08))
	_fill(_vignette)
	add_child(_vignette)
	_glow = TextureRect.new()
	_glow.name = "TitleGlow"
	_fill(_glow)
	_glow.anchor_bottom = 0.55
	add_child(_glow)
	# Keeps the callout legible over bright floors.
	_callout_shade = TextureRect.new()
	_callout_shade.name = "CalloutShade"
	var shade_gradient := Gradient.new()
	shade_gradient.colors = PackedColorArray([Color(0.0, 0.0, 0.02, 0.72), Color(0.0, 0.0, 0.02, 0.0)])
	var shade_texture := GradientTexture2D.new()
	shade_texture.gradient = shade_gradient
	shade_texture.fill_from = Vector2(0.5, 1.0)
	shade_texture.fill_to = Vector2(0.5, 0.0)
	_callout_shade.texture = shade_texture
	_fill(_callout_shade)
	_callout_shade.anchor_top = 0.62
	add_child(_callout_shade)
	_top_bar = _bar("TopBar")
	_top_bar.anchor_bottom = 0.0
	add_child(_top_bar)
	_bottom_bar = _bar("BottomBar")
	_bottom_bar.anchor_top = 1.0
	add_child(_bottom_bar)
	_callout = VBoxContainer.new()
	_callout.name = "WinnerCallout"
	_callout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_callout.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_callout.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_callout.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_callout.alignment = BoxContainer.ALIGNMENT_END
	_callout.add_theme_constant_override("separation", 2)
	add_child(_callout)
	_callout_eyebrow = _label(20, GOLD)
	_callout_eyebrow.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	_callout_eyebrow.add_theme_constant_override("outline_size", 6)
	_callout.add_child(_callout_eyebrow)
	_callout_title = _label(46, Color.WHITE)
	_callout_title.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	_callout_title.add_theme_constant_override("outline_size", 10)
	_callout.add_child(_callout_title)


func set_display_font(font: Font) -> void:
	for label in [_callout_eyebrow, _callout_title]:
		(label as Label).add_theme_font_override("font", font)


## Camera beat: bars slide in and the winner is named above the lower bar.
func play_cinematic(winner_name: String, accent: Color, local_won: bool, reduced_motion: bool) -> void:
	_kill_tween()
	visible = true
	_vignette.modulate.a = 0.0
	_glow.modulate.a = 0.0
	_callout_eyebrow.text = "VICTORY" if local_won else "MATCH OVER"
	_callout_eyebrow.add_theme_color_override("font_color", accent.lightened(0.25))
	_callout_title.text = ("%s WINS!" % winner_name.to_upper()) if not winner_name.is_empty() else ""
	_callout.visible = not _callout_title.text.is_empty()
	_callout_shade.visible = _callout.visible
	var bar_height := size.y * LETTERBOX_SHARE
	_callout.offset_bottom = -bar_height - 18.0
	_callout.offset_top = _callout.offset_bottom
	if reduced_motion:
		_set_bars(bar_height)
		_callout.modulate.a = 1.0
		_callout_shade.modulate.a = 1.0
		return
	_set_bars(0.0)
	_callout.modulate.a = 0.0
	_callout_shade.modulate.a = 0.0
	var rest_y := _callout.position.y
	_callout.position.y = rest_y + 26.0
	_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_tween.tween_method(_set_bars, 0.0, bar_height, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_interval(0.35)
	_tween.set_parallel(true)
	_tween.tween_property(_callout, "modulate:a", 1.0, 0.3)
	_tween.tween_property(_callout_shade, "modulate:a", 1.0, 0.4)
	_tween.tween_property(_callout, "position:y", rest_y, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Results beat: bars and callout clear the way, the vignette settles in, and
## a win gets a glow behind the title plus confetti in `confetti_parent`.
func reveal_results(accent: Color, local_won: bool, reduced_motion: bool, confetti_parent: Control, confetti_index: int) -> void:
	_kill_tween()
	visible = true
	var glow_color := accent if local_won else Color(0.35, 0.45, 0.62)
	_glow.texture = _radial_texture([Color(glow_color, 0.6 if local_won else 0.32), Color(glow_color, 0.0)], [0.0, 1.0], Vector2(0.5, 0.0), Vector2(0.5, 0.95))
	if reduced_motion:
		_set_bars(0.0)
		_callout.modulate.a = 0.0
		_callout_shade.modulate.a = 0.0
		_vignette.modulate.a = 1.0
		_glow.modulate.a = 1.0
		return
	_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	_tween.tween_method(_set_bars, _top_bar.offset_bottom, 0.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(_callout, "modulate:a", 0.0, 0.2)
	_tween.tween_property(_callout_shade, "modulate:a", 0.0, 0.3)
	_tween.tween_property(_vignette, "modulate:a", 1.0, 0.5)
	_tween.tween_property(_glow, "modulate:a", 1.0, 0.8).set_delay(0.1)
	if local_won:
		_burst_confetti(accent, confetti_parent, confetti_index)


func reset() -> void:
	_kill_tween()
	visible = false
	_set_bars(0.0)
	if _confetti != null and is_instance_valid(_confetti):
		_confetti.emitting = false
		_confetti.visible = false


func _burst_confetti(accent: Color, parent: Control, index: int) -> void:
	if _confetti == null or not is_instance_valid(_confetti):
		_confetti = _build_confetti()
	if _confetti.get_parent() != parent:
		if _confetti.get_parent() != null:
			_confetti.get_parent().remove_child(_confetti)
		parent.add_child(_confetti)
	parent.move_child(_confetti, clampi(index, 0, parent.get_child_count() - 1))
	var palette := Gradient.new()
	palette.offsets = PackedFloat32Array([0.0, 0.3, 0.55, 0.8, 1.0])
	palette.colors = PackedColorArray([accent, accent.lightened(0.35), GOLD, Color.WHITE, accent])
	_confetti.color_initial_ramp = palette
	_confetti.position = Vector2(parent.size.x * 0.5, -24.0)
	_confetti.emission_rect_extents = Vector2(parent.size.x * 0.5, 8.0)
	_confetti.visible = true
	_confetti.restart()


func _build_confetti() -> CPUParticles2D:
	var confetti := CPUParticles2D.new()
	confetti.name = "Confetti"
	confetti.one_shot = true
	confetti.emitting = false
	confetti.amount = CONFETTI_AMOUNT
	confetti.lifetime = CONFETTI_LIFETIME
	confetti.explosiveness = 0.82
	confetti.randomness = 0.6
	confetti.texture = _confetti_texture()
	confetti.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	confetti.direction = Vector2(0.0, 1.0)
	confetti.spread = 32.0
	confetti.initial_velocity_min = 90.0
	confetti.initial_velocity_max = 340.0
	confetti.gravity = Vector2(0.0, 360.0)
	confetti.damping_min = 14.0
	confetti.damping_max = 40.0
	confetti.angle_min = -180.0
	confetti.angle_max = 180.0
	confetti.angular_velocity_min = -420.0
	confetti.angular_velocity_max = 420.0
	confetti.scale_amount_min = 0.7
	confetti.scale_amount_max = 1.35
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.8, 1.0])
	fade.colors = PackedColorArray([Color.WHITE, Color.WHITE, Color(1, 1, 1, 0)])
	confetti.color_ramp = fade
	return confetti


func _set_bars(height: float) -> void:
	_top_bar.offset_bottom = height
	_bottom_bar.offset_top = -height


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()


func _bar(bar_name: String) -> ColorRect:
	var bar := ColorRect.new()
	bar.name = bar_name
	bar.color = Color(0.0, 0.0, 0.01, 0.94)
	_fill(bar)
	return bar


func _label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


static func _fill(control: Control) -> void:
	control.set_anchors_preset(Control.PRESET_FULL_RECT)
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if control is TextureRect:
		(control as TextureRect).expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		(control as TextureRect).stretch_mode = TextureRect.STRETCH_SCALE


static func _radial_texture(colors: Array, offsets: Array, from: Vector2, to: Vector2) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array(offsets)
	gradient.colors = PackedColorArray(colors)
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = from
	texture.fill_to = to
	texture.width = 256
	texture.height = 256
	return texture


static func _confetti_texture() -> ImageTexture:
	var image := Image.create(10, 5, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	return ImageTexture.create_from_image(image)
