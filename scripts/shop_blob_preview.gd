extends Control

const COSMETIC_LIBRARY := preload("res://scripts/cosmetic_library.gd")

## A lightweight, procedural product preview.  Keeping it in UI-space makes the
## shop fast while still showing a tangible version of every cosmetic category.

var blob_color := Color(0.22, 0.58, 1.0)
var category := "skins"
var item_id := ""
var _phase := 0.0


func set_item(value_category: String, item: Dictionary, color: Color) -> void:
	category = value_category
	item_id = str(item.get("id", ""))
	blob_color = _cosmetic_color(color)
	queue_redraw()


func _cosmetic_color(fallback: Color) -> Color:
	if category == "skins":
		return COSMETIC_LIBRARY.skin_profile(item_id, fallback).get("primary", fallback) as Color
	if category == "trails":
		return COSMETIC_LIBRARY.trail_profile(item_id).get("color", fallback) as Color
	if category == "faces":
		return COSMETIC_LIBRARY.face_profile(item_id).get("color", fallback) as Color
	if category == "kill_effects":
		return COSMETIC_LIBRARY.kill_profile(item_id).get("color", fallback) as Color
	return fallback


func _process(delta: float) -> void:
	_phase = fmod(_phase + delta, TAU)
	queue_redraw()


func _draw() -> void:
	var radius := minf(size.x, size.y) * 0.255
	var center := size * 0.5 + Vector2(0, sin(_phase * 1.35) * 4.0)
	var glow := blob_color.lightened(0.32)
	for index in range(5, 0, -1):
		draw_circle(center, radius + float(index) * 8.0, Color(glow.r, glow.g, glow.b, 0.012 * float(6 - index)))
	# Orbit rings make the object feel presented rather than dropped into a card.
	for orbit_index in range(3):
		var angle := _phase * (0.85 + orbit_index * 0.12) + orbit_index * TAU / 3.0
		var point := center + Vector2(cos(angle) * radius * 1.42, sin(angle) * radius * 0.42)
		draw_circle(point, 3.0, Color(glow.r, glow.g, glow.b, 0.82))
	draw_circle(center + Vector2(0, radius * 0.13), radius, blob_color.darkened(0.23))
	draw_circle(center, radius, blob_color)
	draw_circle(center - Vector2(radius * 0.2, radius * 0.23), radius * 0.34, Color(1.0, 1.0, 1.0, 0.16))
	_draw_category_detail(center, radius)
	var eye_y := center.y - radius * 0.14
	draw_circle(Vector2(center.x - radius * 0.27, eye_y), maxf(2.0, radius * 0.085), Color(0.035, 0.045, 0.075))
	draw_circle(Vector2(center.x + radius * 0.27, eye_y), maxf(2.0, radius * 0.085), Color(0.035, 0.045, 0.075))
	var smile := PackedVector2Array()
	for index in range(10):
		var angle := lerpf(0.2, PI - 0.2, float(index) / 9.0)
		smile.append(center + Vector2(cos(angle) * radius * 0.37, sin(angle) * radius * 0.26 + radius * 0.11))
	draw_polyline(smile, Color(0.035, 0.045, 0.075), maxf(2.0, radius * 0.07), true)


func _draw_category_detail(center: Vector2, radius: float) -> void:
	if category == "trails":
		for index in range(4):
			var trail_color := Color.from_hsv(fmod(float(index) * 0.16 + _phase * 0.04, 1.0), 0.72, 1.0, 0.66 - index * 0.12)
			draw_circle(center + Vector2(-radius * (1.05 + index * 0.34), sin(_phase * 1.7 + index) * radius * 0.18), radius * (0.22 - index * 0.03), trail_color)
	elif category == "kill_effects":
		for index in range(8):
			var angle := TAU * float(index) / 8.0 + _phase * 0.55
			var start := center + Vector2(cos(angle), sin(angle)) * radius * 1.08
			var end := center + Vector2(cos(angle), sin(angle)) * radius * 1.5
			draw_line(start, end, Color(blob_color.r, blob_color.g, blob_color.b, 0.76), maxf(2.0, radius * 0.07))
	elif category == "faces":
		# The selected face gets a visible crown/shade accent above the normal face.
		if item_id == "cool":
			draw_rect(Rect2(center + Vector2(-radius * 0.52, -radius * 0.31), Vector2(radius * 1.04, radius * 0.16)), Color(0.04, 0.06, 0.11, 0.9), true)
		elif item_id in ["royal", "divine"]:
			var crown := PackedVector2Array([center + Vector2(-radius * 0.48, -radius * 0.65), center + Vector2(-radius * 0.22, -radius * 1.0), center, center + Vector2(radius * 0.22, -radius * 1.0), center + Vector2(radius * 0.48, -radius * 0.65)])
			draw_polyline(crown, Color(1.0, 0.77, 0.2), maxf(2.0, radius * 0.08), true)
	elif category == "abilities":
		var bolt := PackedVector2Array([center + Vector2(radius * 0.1, -radius * 1.28), center + Vector2(-radius * 0.34, -radius * 0.38), center + Vector2(radius * 0.05, -radius * 0.38), center + Vector2(-radius * 0.14, radius * 0.38), center + Vector2(radius * 0.43, -radius * 0.49), center + Vector2(radius * 0.1, -radius * 0.49)])
		draw_colored_polygon(bolt, Color(0.84, 0.95, 1.0, 0.86))
