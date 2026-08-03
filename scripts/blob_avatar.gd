extends Control

@export var blob_color := Color(0.02, 0.86, 1.0)


func set_color(value: Color) -> void:
	blob_color = value
	queue_redraw()


func _draw() -> void:
	var radius := minf(size.x, size.y) * 0.39
	var center := size * 0.5 + Vector2(0, radius * 0.08)
	draw_circle(center + Vector2(0, radius * 0.12), radius, blob_color.darkened(0.18))
	draw_circle(center, radius, blob_color)
	var eye_y := center.y - radius * 0.18
	draw_circle(Vector2(center.x - radius * 0.28, eye_y), maxf(1.5, radius * 0.08), Color(0.04, 0.05, 0.07))
	draw_circle(Vector2(center.x + radius * 0.28, eye_y), maxf(1.5, radius * 0.08), Color(0.04, 0.05, 0.07))
	var smile := PackedVector2Array()
	for index in range(9):
		var angle := lerpf(0.18, PI - 0.18, float(index) / 8.0)
		smile.append(center + Vector2(cos(angle), sin(angle)) * Vector2(radius * 0.38, radius * 0.27))
	draw_polyline(smile, Color(0.04, 0.05, 0.07), maxf(1.5, radius * 0.07), true)
