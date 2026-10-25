class_name ProgressionFx
extends RefCounted

## Motion for the shop and quest drawer: entrances, springy buttons, count-ups,
## a breathing call-to-action, and coins that fly to the balance. All static;
## every tween is created on the node it animates, so it dies with that node
## when the drawer rebuilds. Container children only ever animate
## scale and alpha - their container owns position.

const COIN_ICON_SCRIPT := preload("res://scripts/ui/coin_icon.gd")

## Mirrors the reduced-motion setting (DuelHud.apply_ui_settings). Read when
## an effect plays, not when it is wired, so a long-lived button picks up a
## settings change.
static var reduced_motion := false


## Fades and scales a control up from `from_scale` after `delay` seconds.
static func pop_in(control: Control, delay: float, from_scale := 0.94) -> void:
	if reduced_motion or not is_instance_valid(control):
		return
	control.modulate.a = 0.0
	control.scale = Vector2.ONE * from_scale
	var tween := control.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_interval(delay)
	tween.tween_callback(func() -> void: control.pivot_offset = control.size * 0.5)
	tween.set_parallel(true)
	tween.tween_property(control, "modulate:a", 1.0, 0.22)
	tween.tween_property(control, "scale", Vector2.ONE, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Gives a button the menu's hover lift and press squash.
static func springy(button: Button) -> void:
	button.mouse_entered.connect(_spring.bind(button, 1.04))
	button.mouse_exited.connect(_spring.bind(button, 1.0))
	button.button_down.connect(_spring.bind(button, 0.95))
	button.button_up.connect(_spring.bind(button, 1.0))


## A slow brightness pulse that draws the eye to a ready action.
static func breathe(item: CanvasItem, strength := 0.22) -> void:
	if reduced_motion:
		return
	var tween := item.create_tween().set_loops()
	tween.tween_property(item, "self_modulate", Color(1.0 + strength, 1.0 + strength, 1.0 + strength), 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(item, "self_modulate", Color.WHITE, 0.75).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Grows a progress bar from `from_value` to the value it holds now.
static func fill_bar(bar: Range, from_value: float, delay: float) -> void:
	var target := bar.value
	if reduced_motion or is_equal_approx(from_value, target):
		return
	bar.value = from_value
	var tween := bar.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_interval(delay)
	tween.tween_property(bar, "value", target, 0.7).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)


## Rolls a label's number from `from_value` to `to_value` through `pattern`
## (one %d), with a pop when it lands.
static func count_label(label: Label, from_value: int, to_value: int, pattern: String) -> void:
	if reduced_motion or from_value == to_value:
		label.text = pattern % to_value
		return
	var tween := label.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_method(func(value: float) -> void: label.text = pattern % int(round(value)), float(from_value), float(to_value), 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void: label.pivot_offset = label.size * 0.5)
	tween.tween_property(label, "scale", Vector2.ONE * 1.18, 0.08)
	tween.tween_property(label, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Throws `count` coins from `from_global` along an arc into `to_global`,
## then calls `on_arrive` once. The coins live on `host`, a full-rect layer.
static func coin_burst(host: Control, from_global: Vector2, to_global: Vector2, count: int, on_arrive: Callable = Callable()) -> void:
	if reduced_motion or not is_instance_valid(host):
		if on_arrive.is_valid():
			on_arrive.call()
		return
	var to_local := host.get_global_transform().affine_inverse()
	var start := to_local * from_global
	var finish := to_local * to_global
	for index in count:
		var coin := Control.new()
		coin.name = "FlyingCoin"
		coin.set_script(COIN_ICON_SCRIPT)
		coin.size = Vector2.ONE * 22.0
		coin.pivot_offset = coin.size * 0.5
		coin.position = start - coin.size * 0.5
		coin.scale = Vector2.ZERO
		host.add_child(coin)
		var bend := start.lerp(finish, 0.35) + Vector2(randf_range(-70.0, 70.0), randf_range(-90.0, -30.0))
		var tween := coin.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_interval(float(index) * 0.045)
		tween.tween_property(coin, "scale", Vector2.ONE * 1.1, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_method(func(t: float) -> void:
			coin.position = start.lerp(bend, t).lerp(bend.lerp(finish, t), t) - coin.size * 0.5
			coin.rotation = t * TAU
			coin.scale = Vector2.ONE * lerpf(1.1, 0.55, t)
		, 0.0, 1.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		if index == count - 1 and on_arrive.is_valid():
			tween.tween_callback(on_arrive)
		tween.tween_callback(coin.queue_free)


## A quick elastic scale kick for a control that just changed state.
static func punch(control: Control, amount := 1.08) -> void:
	if reduced_motion or not is_instance_valid(control):
		return
	control.pivot_offset = control.size * 0.5
	var tween := control.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(control, "scale", Vector2.ONE * amount, 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


static func _spring(button: Button, target: float) -> void:
	if reduced_motion or button.disabled:
		button.scale = Vector2.ONE
		return
	button.pivot_offset = button.size * 0.5
	var tween := button.create_tween()
	tween.tween_property(button, "scale", Vector2.ONE * target, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
