class_name ProgressRing
extends Control

## A circular meter: a dim track, an accent arc that eases toward its target,
## and a bright cap on the leading end. The quest board uses it for how much
## of the current set is claimed, with the count drawn in the middle.

const EASE_RATE := 6.0

var accent := Color(1.0, 0.8, 0.34)
var thickness := 7.0
var caption := ""
var caption_size := 15
var _target := 0.0
var _shown := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## `animate` false jumps straight to the value (reduced motion, or a refresh
## that should not replay the fill).
func set_progress(ratio: float, animate := true) -> void:
	_target = clampf(ratio, 0.0, 1.0)
	if not animate:
		_shown = _target
	set_process(not is_equal_approx(_shown, _target))
	queue_redraw()


func _process(delta: float) -> void:
	_shown = lerpf(_shown, _target, minf(1.0, delta * EASE_RATE))
	if absf(_shown - _target) < 0.002:
		_shown = _target
		set_process(false)
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.5 - thickness * 0.5 - 4.0
	if radius <= 0.0:
		return
	draw_arc(center, radius, 0.0, TAU, 64, Color(0.2, 0.28, 0.42, 0.55), thickness, true)
	if _shown > 0.001:
		var start := -PI * 0.5
		var finish := start + TAU * _shown
		draw_arc(center, radius, start, finish, 64, Color(accent, 0.25), thickness + 6.0, true)
		draw_arc(center, radius, start, finish, 64, accent, thickness, true)
		draw_circle(center + Vector2(cos(finish), sin(finish)) * radius, thickness * 0.62, accent.lightened(0.45))
	if caption.is_empty():
		return
	var font := get_theme_font(&"font", &"Label")
	var text_width := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, caption_size).x
	var baseline := center + Vector2(-text_width * 0.5, (font.get_ascent(caption_size) - font.get_descent(caption_size)) * 0.5)
	draw_string(font, baseline, caption, HORIZONTAL_ALIGNMENT_LEFT, -1, caption_size, Color(0.96, 0.98, 1.0))
