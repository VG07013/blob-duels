extends Control

const COSMETIC_LIBRARY := preload("res://scripts/cosmetic_library.gd")
const ABILITY_ICONS := {
	"dash": preload("res://assets/ui/abilities/dash.svg"),
	"ricochet_shot": preload("res://assets/ui/abilities/ricochet_shot.svg"),
	"quick_charge": preload("res://assets/ui/abilities/quick_charge.svg"),
	"blink": preload("res://assets/ui/abilities/blink.svg"),
	"target_scanner": preload("res://assets/ui/abilities/target_scanner.svg"),
	"overcharge": preload("res://assets/ui/abilities/overcharge.svg"),
	"gravity_pulse": preload("res://assets/ui/abilities/gravity_pulse.svg"),
	"rail_shot": preload("res://assets/ui/abilities/rail_shot.svg"),
	"bounce_mine": preload("res://assets/ui/abilities/bounce_mine.svg"),
	"phase_bubble": preload("res://assets/ui/abilities/phase_bubble.svg"),
	"adrenaline": preload("res://assets/ui/abilities/adrenaline.svg"),
	"shockwave": preload("res://assets/ui/abilities/shockwave.svg"),
}

var blob_color := Color(0.22, 0.58, 1.0)
var category := "skins"
var item_id := ""
var item_name := ""
var _phase := 0.0
var _elapsed := 0.0


func set_item(value_category: String, item: Dictionary, color: Color) -> void:
	category = value_category
	item_id = str(item.get("id", ""))
	item_name = str(item.get("name", item_id.capitalize()))
	blob_color = _cosmetic_color(color)
	_elapsed = 0.0
	queue_redraw()


func get_preview_signature() -> Dictionary:
	var signature := {"category": category, "id": item_id, "fingerprint": absi(item_id.hash()) + 1}
	match category:
		"abilities":
			signature["icon"] = ABILITY_ICONS.get(item_id)
		"skins":
			var profile := COSMETIC_LIBRARY.skin_profile(item_id, blob_color)
			signature.merge(profile, true)
		"trails":
			signature.merge(COSMETIC_LIBRARY.trail_profile(item_id), true)
		"faces":
			signature.merge(COSMETIC_LIBRARY.face_profile(item_id), true)
		"kill_effects":
			signature.merge(COSMETIC_LIBRARY.kill_profile(item_id), true)
			signature["effect"] = item_id
	return signature


func _cosmetic_color(fallback: Color) -> Color:
	match category:
		"skins":
			return COSMETIC_LIBRARY.skin_profile(item_id, fallback).get("primary", fallback) as Color
		"trails":
			return COSMETIC_LIBRARY.trail_profile(item_id).get("color", fallback) as Color
		"faces":
			return Color("24b6ed")
		"kill_effects":
			return COSMETIC_LIBRARY.kill_profile(item_id).get("color", fallback) as Color
	return fallback


func _process(delta: float) -> void:
	_elapsed += delta
	_phase = fmod(_phase + delta, TAU)
	queue_redraw()


func _draw() -> void:
	if category == "abilities":
		_draw_ability_preview()
		return
	if category == "kill_effects":
		_draw_kill_preview()
		return
	if not category in ["skins", "trails", "faces"]:
		_draw_identity_fallback()
		return
	var radius := minf(size.x, size.y) * 0.255
	var center := size * 0.5 + Vector2(sin(_phase * 0.72) * 9.0 if category == "trails" else 0.0, sin(_phase * 1.35) * 4.0)
	if category == "trails":
		_draw_trail(center, radius)
	_draw_blob(center, radius, blob_color, true)
	if category == "skins":
		_draw_skin(center, radius)
		_draw_default_face(center, radius)
	elif category == "faces":
		_draw_selected_face(center, radius)
	else:
		_draw_default_face(center, radius)


func _draw_blob(center: Vector2, radius: float, color: Color, show_orbits: bool) -> void:
	var glow := color.lightened(0.32)
	for index in range(5, 0, -1):
		draw_circle(center, radius + float(index) * 8.0, Color(glow.r, glow.g, glow.b, 0.012 * float(6 - index)))
	if show_orbits:
		for orbit_index in range(3):
			var angle := _phase * (0.85 + orbit_index * 0.12) + orbit_index * TAU / 3.0
			var point := center + Vector2(cos(angle) * radius * 1.42, sin(angle) * radius * 0.42)
			draw_circle(point, 3.0, Color(glow.r, glow.g, glow.b, 0.82))
	draw_circle(center + Vector2(0, radius * 0.13), radius, color.darkened(0.23))
	draw_circle(center, radius, color)
	draw_circle(center - Vector2(radius * 0.2, radius * 0.23), radius * 0.34, Color(1.0, 1.0, 1.0, 0.16))


func _draw_ability_preview() -> void:
	var icon := ABILITY_ICONS.get(item_id) as Texture2D
	var center := size * 0.5
	var extent := minf(size.x, size.y) * 0.38
	var pulse := 1.0 + sin(_phase * 2.0) * 0.035
	for ring in range(4, 0, -1):
		draw_circle(center, extent * (0.62 + ring * 0.13), Color(0.24, 0.7, 1.0, 0.025 * ring))
	draw_circle(center, extent * 0.72, Color(0.025, 0.045, 0.09, 0.96))
	draw_arc(center, extent * 0.76, -PI * 0.5, -PI * 0.5 + TAU * (0.7 + sin(_phase) * 0.08), 64, blob_color, 3.0, true)
	if icon != null:
		var icon_size := Vector2.ONE * extent * 1.08 * pulse
		draw_texture_rect(icon, Rect2(center - icon_size * 0.5, icon_size), false, Color.WHITE)
	else:
		_draw_identity_mark(center, extent * 0.72)


func _draw_skin(center: Vector2, radius: float) -> void:
	var profile := COSMETIC_LIBRARY.skin_profile(item_id, blob_color)
	var accent := profile.get("secondary", blob_color.lightened(0.35)) as Color
	var effect := str(profile.get("effect", "jelly"))
	match effect:
		"marble", "lava", "galaxy", "plasma", "dark_matter":
			for index in range(4):
				var y := center.y - radius * 0.62 + radius * 0.4 * index
				var wave := sin(_phase + index * 1.7) * radius * 0.12
				draw_arc(Vector2(center.x + wave, y), radius * (0.52 - absf(index - 1.5) * 0.08), 0.15, PI - 0.15, 18, accent, maxf(2.0, radius * 0.055), true)
		"ice", "crystal":
			for index in range(6):
				var angle := TAU * index / 6.0
				var tip := center + Vector2(cos(angle), sin(angle)) * radius * 0.8
				draw_line(center, tip, Color(accent, 0.72), maxf(1.0, radius * 0.035))
		"neon", "cyber":
			draw_arc(center, radius * 0.76, -2.8, -0.3, 28, accent, maxf(2.0, radius * 0.07), true)
			draw_line(center + Vector2(-radius * 0.72, radius * 0.25), center + Vector2(radius * 0.7, radius * 0.52), accent, maxf(2.0, radius * 0.055))
		"rainbow", "aurora", "celestial", "gold":
			for index in range(3):
				var shade := Color.from_hsv(fmod(float(item_id.hash() & 255) / 255.0 + index * 0.21 + _phase * 0.02, 1.0), 0.58, 1.0, 0.72)
				draw_arc(center, radius * (0.48 + index * 0.13), 0.1, PI - 0.1, 24, shade, maxf(2.0, radius * 0.055), true)
		_:
			draw_arc(center, radius * 0.77, PI * 0.9, PI * 1.75, 28, Color(accent, 0.62), maxf(2.0, radius * 0.055), true)


func _draw_trail(center: Vector2, radius: float) -> void:
	var profile := COSMETIC_LIBRARY.trail_profile(item_id)
	var color := profile.get("color", blob_color) as Color
	var effect := str(profile.get("effect", "soft"))
	for index in range(6, 0, -1):
		var progress := float(index) / 6.0
		var point := center + Vector2(-radius * (0.65 + progress * 2.7), sin(_phase * 2.2 + index * 0.9) * radius * 0.22)
		var particle_color := color
		if effect in ["rainbow", "aurora"]:
			particle_color = Color.from_hsv(fmod(_phase * 0.04 + progress * 0.62, 1.0), 0.72, 1.0)
		particle_color.a = 0.82 - progress * 0.58
		var particle_radius := radius * (0.22 - progress * 0.095)
		match effect:
			"pixels", "glitch":
				draw_rect(Rect2(point - Vector2.ONE * particle_radius, Vector2.ONE * particle_radius * 2.0), particle_color, true)
			"lightning", "meteor", "fire":
				draw_line(point, point - Vector2(radius * 0.5, sin(index) * radius * 0.25), particle_color, maxf(2.0, particle_radius))
			"bubble":
				draw_arc(point, particle_radius, 0, TAU, 18, particle_color, maxf(1.0, radius * 0.035), true)
			"ice":
				draw_colored_polygon(PackedVector2Array([point + Vector2(0, -particle_radius * 1.5), point + Vector2(particle_radius, 0), point + Vector2(0, particle_radius * 1.5), point + Vector2(-particle_radius, 0)]), particle_color)
			"snow":
				for arm in range(3):
					var direction := Vector2.from_angle(float(arm) * PI / 3.0) * particle_radius
					draw_line(point - direction, point + direction, particle_color, maxf(1.0, radius * 0.025))
			"leaves":
				var leaf_axis := Vector2.from_angle(_phase + float(index)) * particle_radius * 1.7
				var leaf_side := leaf_axis.orthogonal() * 0.38
				draw_colored_polygon(PackedVector2Array([point - leaf_axis, point + leaf_side, point + leaf_axis, point - leaf_side]), particle_color)
			"sakura":
				for petal in range(5):
					var petal_point := point + Vector2.from_angle(TAU * float(petal) / 5.0 + _phase) * particle_radius * 0.65
					draw_circle(petal_point, particle_radius * 0.48, Color(particle_color, particle_color.a * 0.92))
			"notes":
				draw_circle(point + Vector2(-particle_radius * 0.35, particle_radius * 0.45), particle_radius * 0.48, particle_color)
				draw_line(point, point + Vector2(0, -particle_radius * 1.25), particle_color, maxf(1.0, particle_radius * 0.32))
				draw_line(point, point + Vector2(particle_radius * 0.8, -particle_radius), particle_color, maxf(1.0, particle_radius * 0.24))
			"stars", "galaxy":
				draw_colored_polygon(_star_points(point, particle_radius * 1.4, particle_radius * 0.56, _phase + float(index)), particle_color)
			"aurora":
				draw_line(point - Vector2(radius * 0.42, particle_radius), point + Vector2(radius * 0.34, -particle_radius), particle_color, maxf(2.0, particle_radius * 0.8), true)
			"void":
				draw_colored_polygon(PackedVector2Array([point + Vector2(-particle_radius, -particle_radius * 0.4), point + Vector2(particle_radius * 0.2, -particle_radius), point + Vector2(particle_radius, particle_radius * 0.35), point + Vector2(-particle_radius * 0.45, particle_radius)]), particle_color)
			_:
				draw_circle(point, particle_radius, particle_color)


func _star_points(center: Vector2, outer_radius: float, inner_radius: float, rotation: float = 0.0) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(10):
		var point_radius := outer_radius if index % 2 == 0 else inner_radius
		points.append(center + Vector2.from_angle(rotation + float(index) * PI / 5.0) * point_radius)
	return points


func _draw_default_face(center: Vector2, radius: float) -> void:
	var ink := Color(0.035, 0.045, 0.075)
	var eye_y := center.y - radius * 0.14
	draw_circle(Vector2(center.x - radius * 0.27, eye_y), maxf(2.0, radius * 0.085), ink)
	draw_circle(Vector2(center.x + radius * 0.27, eye_y), maxf(2.0, radius * 0.085), ink)
	_draw_mouth(center, radius, "happy", ink)


func _draw_selected_face(center: Vector2, radius: float) -> void:
	var effect := str(COSMETIC_LIBRARY.face_profile(item_id).get("effect", item_id))
	var ink := COSMETIC_LIBRARY.face_profile(item_id).get("color", Color("111827")) as Color
	var eye_y := center.y - radius * 0.15
	match effect:
		"cool":
			draw_rect(Rect2(center + Vector2(-radius * 0.55, -radius * 0.34), Vector2(radius * 1.1, radius * 0.22)), Color(0.02, 0.03, 0.06, 0.96), true)
		"pirate":
			draw_circle(Vector2(center.x - radius * 0.27, eye_y), radius * 0.14, ink)
			draw_line(center + Vector2(-radius * 0.54, -radius * 0.36), center + Vector2(radius * 0.48, -radius * 0.02), ink, maxf(2.0, radius * 0.07))
			draw_circle(Vector2(center.x + radius * 0.27, eye_y), radius * 0.075, Color("111827"))
		"nerd", "robot", "energy":
			for side in [-1.0, 1.0]:
				draw_rect(Rect2(center + Vector2(side * radius * 0.29 - radius * 0.14, -radius * 0.3), Vector2(radius * 0.28, radius * 0.23)), Color(ink, 0.82), false, maxf(2.0, radius * 0.05))
		"love", "fire", "cosmic", "void", "divine":
			for side in [-1.0, 1.0]:
				var eye := Vector2(center.x + side * radius * 0.27, eye_y)
				draw_circle(eye, radius * 0.13, Color(ink, 0.86))
				draw_circle(eye - Vector2(radius * 0.04, radius * 0.04), radius * 0.04, Color.WHITE)
		"wink":
			draw_line(center + Vector2(-radius * 0.39, -radius * 0.15), center + Vector2(-radius * 0.15, -radius * 0.15), ink, maxf(2.0, radius * 0.06))
			draw_circle(Vector2(center.x + radius * 0.27, eye_y), radius * 0.085, ink)
		"sleepy":
			for side in [-1.0, 1.0]:
				draw_line(Vector2(center.x + side * radius * 0.39, eye_y), Vector2(center.x + side * radius * 0.15, eye_y + radius * 0.04), ink, maxf(2.0, radius * 0.055))
		_:
			for side in [-1.0, 1.0]:
				draw_circle(Vector2(center.x + side * radius * 0.27, eye_y), radius * (0.13 if effect == "surprised" else 0.085), ink)
	_draw_mouth(center, radius, effect, ink)


func _draw_mouth(center: Vector2, radius: float, expression: String, ink: Color) -> void:
	if expression == "surprised":
		draw_circle(center + Vector2(0, radius * 0.27), radius * 0.13, ink)
		return
	var points := PackedVector2Array()
	var sad := expression in ["sad", "angry", "evil", "frozen"]
	for index in range(10):
		var angle := lerpf(0.2, PI - 0.2, float(index) / 9.0)
		var direction := -1.0 if sad else 1.0
		points.append(center + Vector2(cos(angle) * radius * 0.37, sin(angle) * radius * 0.22 * direction + radius * (0.32 if sad else 0.11)))
	draw_polyline(points, ink, maxf(2.0, radius * 0.07), true)


func _draw_kill_preview() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.23
	var cycle := fmod(_elapsed, 2.6) / 2.6
	var death_amount := clampf((cycle - 0.28) / 0.22, 0.0, 1.0)
	if death_amount < 1.0:
		_draw_blob(center, radius * (1.0 - death_amount * 0.82), Color("24b6ed").lerp(blob_color, death_amount * 0.4), false)
		_draw_default_face(center, radius * (1.0 - death_amount * 0.82))
	if cycle > 0.24:
		_draw_kill_effect(center, radius, clampf((cycle - 0.24) / 0.5, 0.0, 1.0))


func _draw_kill_effect(center: Vector2, radius: float, progress: float) -> void:
	var color := COSMETIC_LIBRARY.kill_profile(item_id).get("color", blob_color) as Color
	var count := 12 if item_id in ["confetti_burst", "crystal_shatter", "pixel_explosion", "supernova"] else 8
	for index in range(count):
		var angle := TAU * float(index) / float(count) + float(item_id.hash() % 11) * 0.13
		var distance := radius * lerpf(0.25, 2.1, progress) * (0.74 + float(index % 3) * 0.13)
		var point := center + Vector2(cos(angle), sin(angle)) * distance
		var alpha := 1.0 - progress * 0.72
		var particle_color := Color.from_hsv(fmod(float(index) / count + 0.94, 1.0), 0.72, 1.0, alpha) if item_id in ["confetti_burst", "firework", "supernova"] else Color(color, alpha)
		match item_id:
			"bubble_pop":
				draw_arc(point, radius * 0.14, 0, TAU, 16, particle_color, maxf(1.0, radius * 0.035), true)
			"confetti_burst":
				var confetti_axis := Vector2.from_angle(angle + progress * 4.0) * radius * 0.13
				var confetti_side := confetti_axis.orthogonal() * 0.42
				draw_colored_polygon(PackedVector2Array([point - confetti_axis - confetti_side, point + confetti_axis - confetti_side, point + confetti_axis + confetti_side, point - confetti_axis + confetti_side]), particle_color)
			"slime_splash":
				draw_circle(point, radius * (0.1 + float(index % 3) * 0.025), particle_color)
			"smoke_puff":
				draw_circle(point, radius * (0.16 + float(index % 2) * 0.055), Color(particle_color, alpha * 0.42))
			"firework":
				draw_line(center + Vector2.from_angle(angle) * radius * 0.25, point, particle_color, maxf(1.0, radius * 0.035), true)
				draw_circle(point, radius * 0.045, particle_color)
			"crystal_shatter", "ice_break":
				var shard_axis := Vector2.from_angle(angle) * radius * 0.2
				var shard_side := shard_axis.orthogonal() * 0.26
				draw_colored_polygon(PackedVector2Array([point + shard_axis, point - shard_axis - shard_side, point - shard_axis + shard_side]), particle_color)
			"comic_boom":
				draw_rect(Rect2(point - Vector2.ONE * radius * 0.08, Vector2.ONE * radius * 0.16), particle_color, true)
			"lightning_strike":
				var midpoint := center.lerp(point, 0.52) + Vector2.from_angle(angle + PI * 0.5) * radius * 0.16
				draw_polyline(PackedVector2Array([center, midpoint, point]), particle_color, maxf(2.0, radius * 0.055), true)
			"pixel_explosion", "time_collapse":
				var block_size := radius * (0.17 if item_id == "pixel_explosion" else 0.11)
				draw_rect(Rect2(point - Vector2.ONE * block_size * 0.5, Vector2.ONE * block_size), particle_color, true)
			"ufo_beam":
				draw_line(point, point - Vector2(0, radius * 0.55), particle_color, maxf(2.0, radius * 0.06), true)
			"meteor_crash":
				draw_line(point - Vector2(radius * 0.42, radius * 0.62), point, particle_color, maxf(2.0, radius * 0.08), true)
			"supernova":
				draw_line(center, point, particle_color, maxf(2.0, radius * 0.045), true)
			_:
				draw_circle(point, radius * 0.075, particle_color)
	if item_id in ["black_hole_burst", "portal_collapse"]:
		draw_arc(center, radius * (0.4 + progress), 0, TAU, 36, Color(color, 1.0 - progress), maxf(2.0, radius * 0.09), true)
		draw_arc(center, radius * (0.2 + progress * 1.45), -progress * TAU, PI * 1.45 - progress * TAU, 32, Color(color.lightened(0.28), 0.88 - progress * 0.6), maxf(2.0, radius * 0.055), true)
	elif item_id == "ufo_beam":
		var beam_alpha := 0.7 * (1.0 - progress * 0.55)
		draw_colored_polygon(PackedVector2Array([center + Vector2(-radius * 0.72, -radius * 1.8), center + Vector2(radius * 0.72, -radius * 1.8), center + Vector2(radius * 0.34, radius * 0.52), center + Vector2(-radius * 0.34, radius * 0.52)]), Color(color, beam_alpha))
	elif item_id == "comic_boom":
		draw_colored_polygon(_star_points(center, radius * (0.65 + progress * 0.9), radius * (0.27 + progress * 0.34), progress), Color(color, 1.0 - progress * 0.58))
	elif item_id == "time_collapse":
		draw_arc(center, radius * (0.42 + progress * 0.56), -PI * 0.5, -PI * 0.5 + TAU * (1.0 - progress * 0.35), 36, Color(color, 1.0 - progress * 0.55), maxf(2.0, radius * 0.07), true)
		draw_line(center, center + Vector2.from_angle(-PI * 0.5 - progress * TAU) * radius * 0.68, Color(color, 1.0 - progress * 0.4), maxf(2.0, radius * 0.06), true)
	elif item_id == "supernova":
		draw_circle(center, radius * (0.2 + progress * 0.72), Color(color, 0.9 - progress * 0.66))


func _draw_identity_fallback() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.3
	var fingerprint := absi(item_id.hash()) + 1
	var hue := float(fingerprint % 997) / 997.0
	var color := Color.from_hsv(hue, 0.68, 0.95)
	draw_circle(center, radius, Color(color, 0.22))
	draw_arc(center, radius * 0.82, 0, TAU, 48, color, maxf(2.0, radius * 0.08), true)
	_draw_identity_mark(center, radius)


func _draw_identity_mark(center: Vector2, radius: float) -> void:
	var label := item_name.left(1).to_upper() if not item_name.is_empty() else "?"
	var font := ThemeDB.fallback_font
	var font_size := maxi(16, int(radius * 0.82))
	var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(font, center - Vector2(text_size.x * 0.5, -text_size.y * 0.32), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
