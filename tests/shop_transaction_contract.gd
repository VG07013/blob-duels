extends SceneTree

const PROGRESSION_SCRIPT := preload("res://scripts/progression_manager.gd")

var failures: Array[String] = []
var balance_events: Array[Array] = []
var inventory_event_count := 0


func _initialize() -> void:
	var progression := PROGRESSION_SCRIPT.new()
	progression.set("persistence_enabled", false)
	progression.balance_changed.connect(_on_balance_changed)
	progression.inventory_changed.connect(_on_inventory_changed)

	_test_purchase_is_atomic(progression)
	_test_invalid_purchases_do_not_mutate_state(progression)
	_test_equip_requires_category_membership(progression)
	progression.free()
	_finish()


func _test_purchase_is_atomic(progression: Node) -> void:
	progression.set("coins", 175)
	progression.set("owned", {})
	progression.set("equipped", {})
	balance_events.clear()
	inventory_event_count = 0

	_check(bool(progression.call("purchase", "abilities", "dash")), "A valid affordable item must be purchasable")
	_check(int(progression.call("get_balance")) == 25, "Purchase must deduct the exact 150 Coin price once")
	_check(bool(progression.call("is_owned", "dash")), "A successful purchase must grant ownership")
	_check(str(progression.call("get_equipped", "abilities")) == "dash", "A successful purchase must equip the item in its own category")
	_check(balance_events.size() == 1 and int(balance_events[0][0]) == 25 and int(balance_events[0][1]) == -150, "Purchase must emit one exact balance delta")
	_check(inventory_event_count == 1, "Purchase must emit exactly one inventory change")

	var state_before_duplicate := _transaction_state(progression)
	_check(not bool(progression.call("purchase", "abilities", "dash")), "An owned item cannot be purchased twice")
	_check(_transaction_state(progression) == state_before_duplicate, "Rejected duplicate purchase must not mutate balance, ownership, or loadout")
	_check(balance_events.size() == 1 and inventory_event_count == 1, "Rejected duplicate purchase must not emit transaction signals")


func _test_invalid_purchases_do_not_mutate_state(progression: Node) -> void:
	progression.set("coins", 149)
	progression.set("owned", {})
	progression.set("equipped", {})
	balance_events.clear()
	inventory_event_count = 0
	var original_state := _transaction_state(progression)

	_check(not bool(progression.call("purchase", "abilities", "dash")), "An unaffordable purchase must be rejected")
	_check(not bool(progression.call("purchase", "skins", "dash")), "An item cannot be purchased through the wrong category")
	_check(not bool(progression.call("purchase", "not_a_category", "dash")), "An unknown category must be rejected")
	_check(not bool(progression.call("purchase", "abilities", "not_an_item")), "An unknown item must be rejected")
	_check(_transaction_state(progression) == original_state, "Every rejected purchase must leave the full transaction state unchanged")
	_check(balance_events.is_empty() and inventory_event_count == 0, "Rejected purchases must not emit balance or inventory signals")


func _test_equip_requires_category_membership(progression: Node) -> void:
	progression.set("coins", 10000)
	progression.set("owned", {})
	progression.set("equipped", {})
	balance_events.clear()
	inventory_event_count = 0
	_check(bool(progression.call("purchase", "skins", "classic_blue")), "Skin fixture purchase must succeed")
	_check(bool(progression.call("purchase", "abilities", "dash")), "Ability fixture purchase must succeed")

	var balance_before_equip := int(progression.call("get_balance"))
	var inventory_before_equip := inventory_event_count
	_check(bool(progression.call("equip", "skins", "classic_blue")), "An owned item must equip in its catalog category")
	_check(int(progression.call("get_balance")) == balance_before_equip, "Equipping an owned item must never spend Coins")
	_check(inventory_event_count == inventory_before_equip + 1, "A valid equip must emit one inventory change")

	var loadout_before_rejections := (progression.get("equipped") as Dictionary).duplicate(true)
	var inventory_before_rejections := inventory_event_count
	_check(not bool(progression.call("equip", "trails", "classic_blue")), "Owned skin must be rejected when equipped as a trail")
	_check(not bool(progression.call("equip", "skins", "dash")), "Owned ability must be rejected when equipped as a skin")
	_check(not bool(progression.call("equip", "not_a_category", "dash")), "Owned item must be rejected for an unknown category")
	(progression.get("owned") as Dictionary)["ghost_item"] = true
	_check(not bool(progression.call("equip", "abilities", "ghost_item")), "Ownership alone must not make an unknown item equippable")
	_check((progression.get("equipped") as Dictionary) == loadout_before_rejections, "Rejected cross-category equips must not alter any equipped slot")
	_check(int(progression.call("get_balance")) == balance_before_equip, "Rejected equips must never change the balance")
	_check(inventory_event_count == inventory_before_rejections, "Rejected equips must not emit inventory changes")


func _transaction_state(progression: Node) -> Dictionary:
	return {
		"coins": int(progression.call("get_balance")),
		"owned": (progression.get("owned") as Dictionary).duplicate(true),
		"equipped": (progression.get("equipped") as Dictionary).duplicate(true),
	}


func _on_balance_changed(balance: int, delta: int) -> void:
	balance_events.append([balance, delta])


func _on_inventory_changed() -> void:
	inventory_event_count += 1


func _finish() -> void:
	if failures.is_empty():
		print("SHOP TRANSACTION CONTRACT PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
