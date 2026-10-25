class_name HealthPill
extends Control

## The duel health bar from the "Blob Duels health" mockup: a thick black
## outlined pill with a grey track, a rounded fill that carries its own
## outline, and the health number riding the right end of the fill. The fill
## steps from lime at full health through yellow and orange to red-orange.

const OUTLINE := 5.0
const TRACK_COLOR := Color("B3B3B3")
const OUTLINE_COLOR := Color("0A0A0A")
const TEXT_COLOR := Color("0A0A0A")
## [health ratio, colour] stops read off the mockup (150/120/100/75/50/25 HP).
const COLOR_STOPS := [
	[1.0, Color("95FF00")],
	[0.8, Color("B8FF00")],
	[0.667, Color("EAFF00")],
	[0.5, Color("FFD500")],
	[0.333, Color("FF8C00")],
	[0.167, Color("FF4500")],
	[0.0, Color("E8200C")],
]

var _current := 150
var _maximum := 150
## Eased fill ratio so damage slides down rather than snapping.
var _shown_ratio := 1.0
var _font: Font
var _font_size := 34


func set_display_font(font: Font, font_size: int) -> void:
	_font = font
	_font_size = font_size
	queue_redraw()


func set_health(current: int, maximum: int, shown_ratio: float) -> void:
	_current = maxi(current, 0)
	_maximum = maxi(maximum, 1)
	_shown_ratio = clampf(shown_ratio, 0.0, 1.0)
	queue_redraw()


func get_health_text() -> String:
	return str(_current)


func get_font_size() -> int:
	return _font_size


func get_fill_color() -> Color:
	return color_for_ratio(float(_current) / float(_maximum))


static func color_for_ratio(ratio: float) -> Color:
	var clamped := clampf(ratio, 0.0, 1.0)
	for index in range(COLOR_STOPS.size() - 1):
		var upper: Array = COLOR_STOPS[index]
		var lower: Array = COLOR_STOPS[index + 1]
		if clamped <= float(upper[0]) and clamped >= float(lower[0]):
			var span := maxf(float(upper[0]) - float(lower[0]), 0.0001)
			return (lower[1] as Color).lerp(upper[1] as Color, (clamped - float(lower[0])) / span)
	return COLOR_STOPS[0][1]


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	var radius := size.y * 0.5
	# Outer outline, then the grey track inset inside it.
	_draw_pill(rect, radius, OUTLINE_COLOR)
	var inner := rect.grow(-OUTLINE)
	_draw_pill(inner, inner.size.y * 0.5, TRACK_COLOR)
	if _current <= 0:
		return
	# The fill is its own outlined pill, never narrower than a full circle
	# plus the number, so even low health reads.
	var text := get_health_text()
	var font := _font if _font != null else get_theme_default_font()
	var text_width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size).x
	var minimum_width := size.y + text_width + 8.0
	var fill_width := clampf(size.x * _shown_ratio, minimum_width, size.x)
	var fill := Rect2(Vector2.ZERO, Vector2(fill_width, size.y))
	_draw_pill(fill, radius, OUTLINE_COLOR)
	var fill_inner := fill.grow(-OUTLINE)
	_draw_pill(fill_inner, fill_inner.size.y * 0.5, get_fill_color())
	# Soft top sheen keeps the flat colour from looking like a placeholder.
	var sheen := Rect2(fill_inner.position + Vector2(fill_inner.size.y * 0.35, 3.0), Vector2(maxf(fill_inner.size.x - fill_inner.size.y * 0.7, 0.0), fill_inner.size.y * 0.24))
	if sheen.size.x > 0.0:
		_draw_pill(sheen, sheen.size.y * 0.5, Color(1, 1, 1, 0.28))
	var ascent := font.get_ascent(_font_size)
	var descent := font.get_descent(_font_size)
	var baseline := size.y * 0.5 + (ascent - descent) * 0.5
	var text_x := fill.end.x - radius * 0.55 - text_width
	draw_string(font, Vector2(text_x, baseline), text, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size, TEXT_COLOR)


func _draw_pill(rect: Rect2, radius: float, color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(int(radius))
	style.anti_aliasing = true
	draw_style_box(style, rect)
