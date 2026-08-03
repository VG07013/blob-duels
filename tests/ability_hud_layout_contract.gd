extends SceneTree

const HUD_SCENE := preload("res://scenes/hud.tscn")

var failures: Array[String] = []


func _initialize() -> void:
	var hud := HUD_SCENE.instantiate()
	root.add_child(hud)
	await process_frame
	var ability := hud.get_node_or_null("AbilityHUD") as Control
	var health := hud.get_node_or_null("HealthPanel") as Control
	_check(ability != null and health != null, "HUD must contain ability and health controls")
	if ability != null and health != null:
		_check(ability.anchor_left == 0.0 and ability.anchor_right == 0.0, "Ability HUD must anchor to the bottom-left corner")
		_check(ability.position.x >= 24.0, "Ability HUD must keep a safe left screen margin")
		_check(not ability.get_global_rect().intersects(health.get_global_rect()), "Ability HUD must not overlap the health panel")
		hud.call("set_ability_state", "", 0, false, false)
		hud.call("set_lobby_mode", false)
		_check(not ability.visible, "Arena entry must not force an empty ability HUD visible")
		hud.call("set_ability_state", "dash", 0, false, false)
		_check(ability.visible, "An equipped ability must become visible outside the lobby")
	hud.queue_free()
	await process_frame
	if failures.is_empty():
		print("ABILITY HUD LAYOUT CONTRACT PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
