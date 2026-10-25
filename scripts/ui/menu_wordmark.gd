class_name MenuWordmark
extends Control

## The "BLOB DUELS" logo, drawn letter by letter so each glyph can drop in
## with an overshoot on entry and then ride a slow wave. Word colours follow
## the two teams: cyan for BLOB, orange for DUELS.

const WORDS := [["BLOB", Color(0.2, 0.86, 1.0)], ["DUELS", Color(1.0, 0.56, 0.16)]]
const WORD_GAP := 0.32
const LETTER_STAGGER := 0.055
const LETTER_DROP_SECONDS := 0.55
const DROP_HEIGHT := 46.0
const WAVE_PIXELS := 2.6

var font: Font
var font_size := 52

var _time := 0.0
var _intro_time := 999.0
var _reduced_motion := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_refresh_minimum_size()


func configure(display_font: Font, size_px: int) -> void:
	font = display_font
	font_size = size_px
	_refresh_minimum_size()
	queue_redraw()


func set_reduced_motion(enabled: bool) -> void:
	_reduced_motion = enabled


func play_intro(delay := 0.0) -> void:
	_intro_time = -delay


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_time += delta
	_intro_time += delta
	queue_redraw()


func _draw() -> void:
	var draw_font := _font()
	var ascent := draw_font.get_ascent(font_size)
	var x := 0.0
	var index := 0
	for word_index in WORDS.size():
		var word := str(WORDS[word_index][0])
		var color := WORDS[word_index][1] as Color
		for character in word:
			var advance := draw_font.get_string_size(character, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			var progress := 1.0 if _reduced_motion else clampf((_intro_time - index * LETTER_STAGGER) / LETTER_DROP_SECONDS, 0.0, 1.0)
			var eased := _ease_out_back(progress)
			var wave := 0.0 if _reduced_motion else sin(_time * 2.1 - index * 0.55) * WAVE_PIXELS
			var offset_y := (1.0 - eased) * -DROP_HEIGHT + wave
			var squash := 1.0 + (1.0 - eased) * 0.25
			var alpha := clampf(progress * 2.5, 0.0, 1.0)
			var glyph_center := Vector2(x + advance * 0.5, ascent * 0.55)
			draw_set_transform(glyph_center + Vector2(0.0, offset_y), 0.0, Vector2(1.0 / squash, squash))
			var origin := Vector2(-advance * 0.5, ascent * 0.45)
			draw_string(draw_font, origin + Vector2(0.0, 5.0), character, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(color.darkened(0.62), alpha))
			draw_string_outline(draw_font, origin, character, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 9, Color(0.01, 0.02, 0.05, 0.9 * alpha))
			draw_string(draw_font, origin, character, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(color.lightened(0.12), alpha))
			x += advance
			index += 1
		x += font_size * WORD_GAP
	draw_set_transform(Vector2.ZERO)


func _font() -> Font:
	return font if font != null else get_theme_default_font()


func _refresh_minimum_size() -> void:
	var draw_font := _font()
	var width := 0.0
	for word in WORDS:
		width += draw_font.get_string_size(str(word[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	width += font_size * WORD_GAP * (WORDS.size() - 1)
	custom_minimum_size = Vector2(ceilf(width + 8.0), ceilf(draw_font.get_height(font_size) + 8.0))


static func _ease_out_back(t: float) -> float:
	var c1 := 1.70158
	var c3 := c1 + 1.0
	return 1.0 + c3 * pow(t - 1.0, 3.0) + c1 * pow(t - 1.0, 2.0)
