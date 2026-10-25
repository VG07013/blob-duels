class_name HotbarHud
extends HBoxContainer

## The hotbar from the "Blob Duels Hotbar" mockup, bottom-right and large:
## pale shield-shaped cards whose icons spill past the card edge. Slot 1 is
## the Blaster (a glossy orange bullet), slot 2 the Blob (a smiley blob drawn
## in the player's own blob colour). The equipped ability rides along as the
## third item (attach_ability). The active slot lifts and gets a white rim.

const COMBAT_TUNING := preload("res://scripts/combat_tuning.gd")
const CARD_SIZE := Vector2(104, 116)
const CARD_COLOR := Color("E8F3FC")
const CARD_EDGE := Color("C9DDF0")
const ACTIVE_RIM := Color.WHITE
const BULLET := Color("FF6A13")
const BULLET_SHADE := Color("D9460A")
const FACE_INK := Color("1F1F1F")
const ACTIVE_LIFT := 10.0
## Inactive cards dim rather than fade, so the icons keep their punch.
const INACTIVE_TINT := Color(0.8, 0.82, 0.88, 1.0)

var _cards: Array[Control] = []
var _active := COMBAT_TUNING.SLOT_BLASTER
var _player: Node
var _blob_color := Color("B8E9FF")
var _lift := [0.0, 0.0]


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_END
	add_theme_constant_override("separation", 14)
	for index in range(COMBAT_TUNING.SLOT_COUNT):
		var card := Control.new()
		card.name = "Slot%d" % (index + 1)
		card.custom_minimum_size = CARD_SIZE
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.draw.connect(_draw_card.bind(card, index))
		add_child(card)
		_cards.append(card)
	_refresh()


func bind_player(player: Node) -> void:
	if player == null or not player.has_signal("hotbar_slot_changed"):
		return
	_player = player
	if not player.is_connected("hotbar_slot_changed", set_active_slot):
		player.connect("hotbar_slot_changed", set_active_slot)
	set_active_slot(int(player.call("get_hotbar_slot")))
	_sync_blob_color()


## Adds the ability widget as the hotbar's third item so it lines up with the
## two slots.
func attach_ability(ability: Control) -> void:
	if ability == null:
		return
	if ability.get_parent() != null:
		ability.get_parent().remove_child(ability)
	ability.custom_minimum_size = Vector2(CARD_SIZE.y, CARD_SIZE.y)
	ability.size_flags_vertical = Control.SIZE_SHRINK_END
	add_child(ability)


func set_active_slot(slot: int) -> void:
	_active = clampi(slot, 0, COMBAT_TUNING.SLOT_COUNT - 1)
	_refresh()


func get_active_slot() -> int:
	return _active


func get_blob_icon_color() -> Color:
	return _blob_color


func _process(delta: float) -> void:
	_sync_blob_color()
	# Ease the active card up and the other back down.
	var moved := false
	for index in range(_cards.size()):
		var target := ACTIVE_LIFT if index == _active else 0.0
		var next := move_toward(float(_lift[index]), target, delta * 90.0)
		if not is_equal_approx(next, float(_lift[index])):
			_lift[index] = next
			moved = true
	if moved:
		for card in _cards:
			card.queue_redraw()


func _sync_blob_color() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var color: Variant = _player.get("blob_color")
	if color is Color and not (color as Color).is_equal_approx(_blob_color):
		_blob_color = color
		if _cards.size() > COMBAT_TUNING.SLOT_BLOB:
			_cards[COMBAT_TUNING.SLOT_BLOB].queue_redraw()


func _refresh() -> void:
	for index in range(_cards.size()):
		_cards[index].modulate = Color.WHITE if index == _active else INACTIVE_TINT
		_cards[index].queue_redraw()


func _draw_card(card: Control, index: int) -> void:
	var active := index == _active
	var lift := float(_lift[index])
	var offset := Vector2(0, -lift)
	var shield := _shield_points(Rect2(offset, CARD_SIZE))
	if active:
		# Soft glow + white rim around the selected card.
		card.draw_colored_polygon(_shield_points(Rect2(offset - Vector2(4, 4), CARD_SIZE + Vector2(8, 8))), Color(1, 1, 1, 0.35))
		card.draw_polyline(_closed(shield), ACTIVE_RIM, 5.0, true)
	card.draw_colored_polygon(shield, CARD_COLOR)
	card.draw_polyline(_closed(shield), CARD_EDGE if not active else ACTIVE_RIM, 2.0, true)
	var center := offset + Vector2(CARD_SIZE.x * 0.5, CARD_SIZE.y * 0.42)
	if index == COMBAT_TUNING.SLOT_BLASTER:
		_draw_bullet(card, center)
	else:
		_draw_blob(card, center)


## Rounded-top card that narrows to a soft point at the bottom, like the
## mockup's pocket shield.
func _shield_points(rect: Rect2) -> PackedVector2Array:
	var points := PackedVector2Array()
	var radius := 12.0
	var side_bottom := rect.position.y + rect.size.y * 0.84
	var tip := Vector2(rect.position.x + rect.size.x * 0.5, rect.end.y)
	var top_left := rect.position + Vector2(radius, radius)
	var top_right := Vector2(rect.end.x - radius, rect.position.y + radius)
	for step in range(0, 7):
		var angle := PI + (PI * 0.5) * float(step) / 6.0
		points.append(top_left + Vector2(cos(angle), sin(angle)) * radius)
	for step in range(0, 7):
		var angle := PI * 1.5 + (PI * 0.5) * float(step) / 6.0
		points.append(top_right + Vector2(cos(angle), sin(angle)) * radius)
	points.append(Vector2(rect.end.x, side_bottom))
	points.append(tip + Vector2(6, -1.5))
	points.append(tip)
	points.append(tip + Vector2(-6, -1.5))
	points.append(Vector2(rect.position.x, side_bottom))
	return points


func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var closed := points.duplicate()
	closed.append(points[0])
	return closed


## Glossy orange bullet, tilted up to the right and spilling past the card:
## a fat capsule with a round nose, a lighter top band, a shaded belly, and a
## bright specular spot near the nose.
func _draw_bullet(card: Control, center: Vector2) -> void:
	var length := CARD_SIZE.x * 1.12
	var radius := CARD_SIZE.x * 0.25
	var axis := Vector2(cos(-0.6), sin(-0.6))
	var normal := Vector2(-axis.y, axis.x)
	var nose := center + axis * (length * 0.5 - radius)
	var tail := center - axis * (length * 0.5 - radius * 0.55)
	card.draw_colored_polygon(_capsule(tail, nose, radius, radius * 0.55, axis, normal, -1.0, 1.0), BULLET)
	# Shaded belly (the half toward the normal, i.e. below the axis on screen).
	card.draw_colored_polygon(_capsule(tail, nose, radius, radius * 0.55, axis, normal, 0.15, 1.0), BULLET_SHADE)
	# Lighter top band.
	card.draw_colored_polygon(_capsule(tail + axis * radius * 0.4, nose, radius * 0.92, radius * 0.5, axis, normal, -0.92, -0.45), BULLET.lightened(0.22))
	# Specular spot on the nose.
	card.draw_set_transform(nose - normal * radius * 0.42 + axis * radius * 0.28, axis.angle(), Vector2(1.0, 0.55))
	card.draw_circle(Vector2.ZERO, radius * 0.3, Color(1, 1, 1, 0.9))
	card.draw_set_transform(Vector2.ZERO)


## Slice of a capsule between two lateral fractions (-1 = far side, 1 = near
## side along `normal`): a round nose of `nose_radius` at `nose`, a softly
## rounded tail of `tail_radius` at `tail`.
func _capsule(tail: Vector2, nose: Vector2, nose_radius: float, tail_radius: float, axis: Vector2, normal: Vector2, from_side: float, to_side: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var from_angle := asin(clampf(from_side, -1.0, 1.0))
	var to_angle := asin(clampf(to_side, -1.0, 1.0))
	for step in range(0, 17):
		var angle := lerpf(from_angle, to_angle, float(step) / 16.0)
		points.append(nose + (axis * cos(angle) + normal * sin(angle)) * nose_radius)
	for step in range(0, 17):
		var angle := lerpf(to_angle, from_angle, float(step) / 16.0)
		points.append(tail + (-axis * cos(angle) * 0.45 + normal * sin(angle)) * (nose_radius if absf(sin(angle)) > 0.0 else tail_radius) * 1.0)
	return points


## The player's blob: a soft lumpy circle in their colour with the mockup's
## simple face (two upright eyes and a smile).
func _draw_blob(card: Control, center: Vector2) -> void:
	var radius := CARD_SIZE.x * 0.44
	var body := PackedVector2Array()
	for step in range(0, 40):
		var angle := TAU * float(step) / 40.0
		# A slight lumpy wobble so it reads as a blob, not a circle.
		var wobble := 1.0 + 0.045 * sin(angle * 3.0 + 0.6) + 0.03 * cos(angle * 2.0)
		var squash := Vector2(1.04, 0.94)
		body.append(center + Vector2(cos(angle), sin(angle)) * radius * wobble * squash)
	card.draw_colored_polygon(body, _blob_color)
	card.draw_polyline(_closed(body), _blob_color.darkened(0.18), 2.0, true)
	var eye_top := center + Vector2(0, -radius * 0.36)
	for side in [-1.0, 1.0]:
		var eye_x: float = center.x + float(side) * radius * 0.26
		card.draw_line(Vector2(eye_x, eye_top.y), Vector2(eye_x, eye_top.y + radius * 0.34), FACE_INK, 4.0, true)
	card.draw_arc(center + Vector2(0, radius * 0.02), radius * 0.3, deg_to_rad(30), deg_to_rad(150), 16, FACE_INK, 4.0, true)
