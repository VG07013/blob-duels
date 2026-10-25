extends SceneTree

const PROGRESSION_SCRIPT := preload("res://scripts/progression_manager.gd")
const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

var failures: Array[String] = []


func _initialize() -> void:
	var economy := PROGRESSION_SCRIPT.new()
	# The live shop only stocks Dash; this contract guards the full ability data.
	economy.set("stock_full_catalog", true)
	var dash := economy.call("_find_item", "abilities", "dash") as Dictionary
	var ricochet := economy.call("_find_item", "abilities", "ricochet_shot") as Dictionary
	var quick_charge := economy.call("_find_item", "abilities", "quick_charge") as Dictionary
	_check(int(dash.get("price", 0)) == 150, "Dash must cost 150 Coins")
	_check(int(ricochet.get("price", 0)) == 300, "Ricochet Shot must cost 300 Coins")
	_check(int(quick_charge.get("price", 0)) == 500, "Quick Charge must cost 500 Coins")
	_check((economy.call("get_items", "abilities") as Array).size() == 12, "All twelve launch abilities should be available")
	var blink := economy.call("_find_item", "abilities", "blink") as Dictionary
	var scanner := economy.call("_find_item", "abilities", "target_scanner") as Dictionary
	var overcharge := economy.call("_find_item", "abilities", "overcharge") as Dictionary
	_check(not blink.is_empty() and not scanner.is_empty() and not overcharge.is_empty(), "Part 2 abilities must be shop-ready")
	var gravity := economy.call("_find_item", "abilities", "gravity_pulse") as Dictionary
	var rail := economy.call("_find_item", "abilities", "rail_shot") as Dictionary
	var mine := economy.call("_find_item", "abilities", "bounce_mine") as Dictionary
	_check(not gravity.is_empty() and not rail.is_empty() and not mine.is_empty(), "Part 3 abilities must be shop-ready")
	var phase_bubble := economy.call("_find_item", "abilities", "phase_bubble") as Dictionary
	var adrenaline := economy.call("_find_item", "abilities", "adrenaline") as Dictionary
	_check(not phase_bubble.is_empty() and not adrenaline.is_empty(), "Part 4 abilities must be shop-ready")
	var player := PLAYER_SCENE.instantiate()
	player.set_equipped_ability("quick_charge")
	_check(is_equal_approx(player.get_charge_rate_multiplier(), 1.2), "Quick Charge must fill 20% faster")
	player.set_equipped_ability("dash")
	_check(is_equal_approx(player.get_charge_rate_multiplier(), 1.0), "Other abilities must not change fling charge")
	player.set_overcharge_active(true)
	_check(is_equal_approx(player.get_fire_rate_multiplier(), 1.3), "Overcharge must raise fire rate by 30%")
	player.set_equipped_ability("adrenaline")
	player.health = 80
	player.call("_update_adrenaline")
	_check(is_equal_approx(player.get_movement_multiplier(), 1.15), "Adrenaline must grant 15% movement below 60% HP")
	_check(is_equal_approx(player.get_charge_rate_multiplier(), 1.15), "Adrenaline must grant 15% faster fling charge")
	economy.queue_free()
	player.queue_free()
	if failures.is_empty():
		print("ABILITY CONTRACT PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
