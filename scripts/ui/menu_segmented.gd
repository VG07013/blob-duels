class_name MenuSegmented
extends HBoxContainer

## A row of toggle segments with one accent pill that glides to the pick.
## The menu uses it for the map and bot-difficulty pickers; the progression
## drawer uses it for its Shop / Quests switch, the shop categories, and
## Daily / Weekly. Layout and motion only: callers decide what an index means.

signal selection_changed(index: int)

var selected := 0
var accent := Color.WHITE
var font_size := 12
var _group := ButtonGroup.new()
var _pill_rect := Rect2()
var _pill_ready := false
var _track := StyleBoxFlat.new()
var _pill := StyleBoxFlat.new()


func _init(control_name: String, accent_color: Color) -> void:
	name = control_name
	accent = accent_color
	custom_minimum_size = Vector2(0, 38)
	add_theme_constant_override("separation", 2)
	_track.bg_color = Color(0.02, 0.03, 0.07, 0.72)
	_track.border_color = Color(accent.r, accent.g, accent.b, 0.22)
	_track.set_border_width_all(1)
	_track.set_corner_radius_all(11)
	_pill.bg_color = accent
	_pill.set_corner_radius_all(9)
	_pill.shadow_color = Color(accent.r, accent.g, accent.b, 0.4)
	_pill.shadow_size = 6


func set_options(labels: Array, selected_index: int) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	for index in labels.size():
		var segment := Button.new()
		segment.name = "Segment%d" % index
		segment.text = str(labels[index])
		segment.toggle_mode = true
		segment.button_group = _group
		segment.focus_mode = Control.FOCUS_NONE
		segment.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		segment.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		segment.add_theme_font_size_override("font_size", font_size)
		for style_name in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
			segment.add_theme_stylebox_override(style_name, StyleBoxEmpty.new())
		segment.add_theme_color_override("font_color", Color(0.66, 0.73, 0.86))
		segment.add_theme_color_override("font_hover_color", Color.WHITE)
		segment.add_theme_color_override("font_pressed_color", Color(0.02, 0.03, 0.06))
		segment.add_theme_color_override("font_hover_pressed_color", Color(0.02, 0.03, 0.06))
		segment.toggled.connect(_on_segment_toggled.bind(index))
		add_child(segment)
	_pill_ready = false
	select(selected_index)


func select(index: int) -> void:
	if index < 0 or index >= get_child_count():
		return
	selected = index
	# set_pressed_no_signal bypasses the ButtonGroup, so release the others
	# here or two segments would both draw as pressed.
	for child_index in get_child_count():
		(get_child(child_index) as Button).set_pressed_no_signal(child_index == index)


func _on_segment_toggled(pressed: bool, index: int) -> void:
	if pressed and index != selected:
		selected = index
		selection_changed.emit(index)


func _process(delta: float) -> void:
	if not is_visible_in_tree() or get_child_count() == 0:
		return
	var target := (get_child(clampi(selected, 0, get_child_count() - 1)) as Control).get_rect()
	if not _pill_ready:
		_pill_rect = target
		_pill_ready = target.size.x > 0.0
	else:
		var t := minf(1.0, delta * 14.0)
		_pill_rect = Rect2(_pill_rect.position.lerp(target.position, t), _pill_rect.size.lerp(target.size, t))
	queue_redraw()


func _draw() -> void:
	draw_style_box(_track, Rect2(Vector2.ZERO, size))
	if _pill_ready:
		draw_style_box(_pill, _pill_rect.grow(-3.0))
