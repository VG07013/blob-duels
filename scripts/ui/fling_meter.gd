class_name FlingMeter
extends Control

## The fling rail, drawn in the same style as HealthPill: a thick black
## outlined pill on a grey track with a rounded, sheened fill. One widget
## covers every fling state:
##   ready     - full cyan fill, "FLING READY"
##   charging  - fill grows with the charge, cyan -> lime -> yellow -> orange,
##               "FLING 45%" and "MAX!" at full charge
##   cooldown  - slate fill refilling as the cooldown runs, "FLING 1.5s"

const OUTLINE := 4.0
const TRACK_COLOR := Color("B3B3B3")
const OUTLINE_COLOR := Color("0A0A0A")
const TEXT_COLOR := Color("0A0A0A")
const READY_COLOR := Color("22D3FF")
const COOLDOWN_COLOR := Color("7A8BA8")
## [charge ratio, colour] stops for a building charge.
const CHARGE_STOPS := [
	[0.0, Color("22D3FF")],
	[0.33, Color("95FF00")],
	[0.66, Color("FFD500")],
	[1.0, Color("FF7A1A")],
]

var _charge := 0.0
var _cooldown_remaining := 0.0
var _cooldown_duration := 3.0
var _font: Font
var _font_size := 18


func set_display_font(font: Font, font_size: int) -> void:
	_font = font
	_font_size = font_size
	queue_redraw()


func set_state(charge_ratio: float, cooldown_remaining: float, cooldown_duration: float) -> void:
	_charge = clampf(charge_ratio, 0.0, 1.0)
	_cooldown_duration = maxf(cooldown_duration, 0.001)
	_cooldown_remaining = clampf(cooldown_remaining, 0.0, _cooldown_duration)
	queue_redraw()


func is_on_cooldown() -> bool:
	return _cooldown_remaining > 0.001


func is_charging() -> bool:
	return _charge > 0.001 and not is_on_cooldown()


## Fill ratio shown: cooldown refills from empty, a charge grows, ready is full.
func get_fill_ratio() -> float:
	if is_on_cooldown():
		return 1.0 - _cooldown_remaining / _cooldown_duration
	if is_charging():
		return _charge
	return 1.0


func get_state_text() -> String:
	if is_on_cooldown():
		return "FLING  %.1fs" % _cooldown_remaining
	if is_charging():
		return "MAX!" if _charge >= 0.999 else "FLING  %d%%" % int(round(_charge * 100.0))
	return "FLING READY"


func get_fill_color() -> Color:
	if is_on_cooldown():
		return COOLDOWN_COLOR
	if is_charging():
		return color_for_charge(_charge)
	return READY_COLOR


static func color_for_charge(ratio: float) -> Color:
	var clamped := clampf(ratio, 0.0, 1.0)
	for index in range(CHARGE_STOPS.size() - 1):
		var lower: Array = CHARGE_STOPS[index]
		var upper: Array = CHARGE_STOPS[index + 1]
		if clamped >= float(lower[0]) and clamped <= float(upper[0]):
			var span := maxf(float(upper[0]) - float(lower[0]), 0.0001)
			return (lower[1] as Color).lerp(upper[1] as Color, (clamped - float(lower[0])) / span)
	return CHARGE_STOPS[CHARGE_STOPS.size() - 1][1]


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var radius := size.y * 0.5
	_draw_pill(rect, radius, OUTLINE_COLOR)
	var inner := rect.grow(-OUTLINE)
	_draw_pill(inner, inner.size.y * 0.5, TRACK_COLOR)
	var ratio := get_fill_ratio()
	if ratio > 0.001:
		# Never narrower than a full circle, so a fresh charge still reads.
		var fill := Rect2(Vector2.ZERO, Vector2(clampf(size.x * ratio, size.y, size.x), size.y))
		_draw_pill(fill, radius, OUTLINE_COLOR)
		var fill_inner := fill.grow(-OUTLINE)
		_draw_pill(fill_inner, fill_inner.size.y * 0.5, get_fill_color())
		var sheen := Rect2(fill_inner.position + Vector2(fill_inner.size.y * 0.35, 2.0), Vector2(maxf(fill_inner.size.x - fill_inner.size.y * 0.7, 0.0), fill_inner.size.y * 0.24))
		if sheen.size.x > 0.0:
			_draw_pill(sheen, sheen.size.y * 0.5, Color(1, 1, 1, 0.28))
	var font := _font if _font != null else get_theme_default_font()
	var text := get_state_text()
	var text_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size).x
	var baseline := size.y * 0.5 + (font.get_ascent(_font_size) - font.get_descent(_font_size)) * 0.5
	draw_string(font, Vector2((size.x - text_width) * 0.5, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size, TEXT_COLOR)


func _draw_pill(rect: Rect2, radius: float, color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(int(radius))
	style.anti_aliasing = true
	draw_style_box(style, rect)
