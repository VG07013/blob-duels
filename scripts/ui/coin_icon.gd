extends Control

const COIN_TEXTURE := preload("res://assets/ui/economy/blob-coin.png")

@export var icon_texture: Texture2D = COIN_TEXTURE
@export var accent := Color(1.0, 0.78, 0.24)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(24, 24)


func set_accent(value: Color) -> void:
	accent = value
	queue_redraw()


func _draw() -> void:
	if icon_texture == null:
		return
	var edge := minf(size.x, size.y)
	var icon_rect := Rect2((size - Vector2.ONE * edge) * 0.5, Vector2.ONE * edge)
	draw_texture_rect(icon_texture, icon_rect, false)
	var center := size * 0.5
	draw_arc(center, edge * 0.46, 0.0, TAU, 48, Color(accent, 0.72), maxf(1.0, edge * 0.045), true)
