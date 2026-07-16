extends Control

var line_length := 8.0
var line_thickness := 1.5
var center_gap := 5.0
var dot_enabled := true
var dot_size := 2.0
var outline_enabled := true
var outline_thickness := 1.0
var crosshair_color := Color.WHITE
var crosshair_opacity := 1.0
var dynamic_enabled := true
var dynamic_amount := 5.0
var rotation_degrees_value := 0.0
var _dynamic_ratio := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func apply_settings(settings: Dictionary) -> void:
	line_length = clampf(float(settings.get("crosshair_length", 8.0)), 2.0, 18.0)
	line_thickness = clampf(float(settings.get("crosshair_thickness", 1.5)), 1.0, 5.0)
	center_gap = clampf(float(settings.get("crosshair_gap", 5.0)), 0.0, 16.0)
	dot_enabled = bool(settings.get("crosshair_dot", true))
	dot_size = clampf(float(settings.get("crosshair_dot_size", 2.0)), 1.0, 6.0)
	outline_enabled = bool(settings.get("crosshair_outline", true))
	outline_thickness = clampf(float(settings.get("crosshair_outline_thickness", 1.0)), 0.5, 3.0)
	var requested_color: Variant = settings.get("crosshair_color_value", Color.WHITE)
	crosshair_color = requested_color if requested_color is Color else Color.WHITE
	crosshair_opacity = clampf(float(settings.get("crosshair_opacity", 1.0)), 0.2, 1.0)
	dynamic_enabled = bool(settings.get("crosshair_dynamic", true))
	dynamic_amount = clampf(float(settings.get("crosshair_dynamic_amount", 5.0)), 0.0, 14.0)
	rotation_degrees_value = clampf(float(settings.get("crosshair_rotation", 0.0)), -45.0, 45.0)
	queue_redraw()


func set_dynamic_state(charge_ratio: float, speed_ratio: float) -> void:
	var target := maxf(clampf(charge_ratio, 0.0, 1.0), clampf(speed_ratio, 0.0, 1.0) * 0.55) if dynamic_enabled else 0.0
	_dynamic_ratio = move_toward(_dynamic_ratio, target, get_process_delta_time() * 7.0)
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var spread := center_gap + dynamic_amount * _dynamic_ratio
	var tint := Color(crosshair_color.r, crosshair_color.g, crosshair_color.b, crosshair_opacity)
	var directions := [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]
	var rotation_radians := deg_to_rad(rotation_degrees_value)
	for direction in directions:
		var rotated: Vector2 = direction.rotated(rotation_radians)
		var start := center + rotated * spread
		var finish := center + rotated * (spread + line_length)
		if outline_enabled:
			draw_line(start, finish, Color(0.01, 0.015, 0.02, crosshair_opacity * 0.9), line_thickness + outline_thickness * 2.0, true)
		draw_line(start, finish, tint, line_thickness, true)
	if dot_enabled:
		if outline_enabled:
			draw_circle(center, dot_size + outline_thickness, Color(0.01, 0.015, 0.02, crosshair_opacity * 0.9), true)
		draw_circle(center, dot_size, tint, true)
