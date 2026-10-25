extends SceneTree

const HUD_SCENE := preload("res://scenes/hud.tscn")

var failures: Array[String] = []


func _initialize() -> void:
	var hud := HUD_SCENE.instantiate()
	root.add_child(hud)
	await process_frame
	var ability := hud.find_child("AbilityHUD", true, false) as Control
	var health := hud.get_node_or_null("HealthPanel") as Control
	var hotbar := hud.get_node_or_null("Hotbar") as Control
	_check(ability != null and health != null and hotbar != null, "HUD must contain ability, health and hotbar controls")
	if ability != null and health != null and hotbar != null:
		_check(ability.get_parent() == hotbar and ability.get_index() == hotbar.get_child_count() - 1, "The ability must sit in the hotbar as its third item, after Blaster and Blob")
		_check(hotbar.anchor_left == 1.0 and hotbar.anchor_top == 1.0, "The hotbar must anchor to the bottom-right corner")
		_check(health.anchor_left == 0.0 and health.anchor_top == 1.0, "Health must anchor to the bottom-left corner")
		hud.call("set_lobby_mode", false)
		hud.call("set_ability_state", "dash", 0, false, false)
		await process_frame
		_check(not ability.get_global_rect().intersects(health.get_global_rect()), "The ability must not overlap the health bar")
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
