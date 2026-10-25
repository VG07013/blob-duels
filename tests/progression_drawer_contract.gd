extends SceneTree

## The animated shop / quest drawer: its tabs drive real state, closing is
## immediate as far as the game is concerned, a claim pays out from the board,
## and reduced motion shows everything at rest.

const HUD_SCENE := preload("res://scenes/hud.tscn")
const PROGRESSION_SCRIPT := preload("res://scripts/progression_manager.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	# The HUD binds to /root/Progression, which is the autoload when the
	# project runs. This test claims a quest, so it must never write the
	# player's real save: persistence goes off before anything changes.
	var progression := root.get_node_or_null("Progression")
	var created_progression := progression == null
	if created_progression:
		progression = PROGRESSION_SCRIPT.new()
		progression.name = "Progression"
	progression.set("persistence_enabled", false)
	if created_progression:
		root.add_child(progression)
	await process_frame
	var hud := HUD_SCENE.instantiate()
	root.add_child(hud)
	await process_frame
	await _test_close_is_immediate(hud)
	await _test_category_tabs(hud, progression)
	await _test_page_tabs(hud)
	await _test_claim_from_board(hud, progression)
	await _test_reduced_motion(hud)
	hud.queue_free()
	if created_progression:
		progression.queue_free()
	await process_frame
	if failures.is_empty():
		print("PROGRESSION DRAWER CONTRACT PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _test_close_is_immediate(hud: Node) -> void:
	hud.call("_set_progression_open", "shop")
	await process_frame
	_check(bool(hud.call("is_progression_open")), "Opening the shop must report the drawer open")
	hud.call("close_progression")
	_check(not bool(hud.call("is_progression_open")), "Closing must count as closed at once, while the exit animation plays")
	await create_timer(0.4).timeout
	var overlay := hud.find_child("ShopOverlay", true, false) as Control
	_check(overlay != null and not overlay.visible, "The drawer must be hidden once its exit animation ends")
	_check(overlay.find_children("*", "SubViewport", true, false).is_empty(), "A closed drawer must not keep its model preview viewport alive")
	hud.call("_set_progression_open", "shop")
	hud.call("close_progression")
	hud.call("_set_progression_open", "quests")
	await create_timer(0.4).timeout
	_check(bool(hud.call("is_progression_open")) and overlay.visible, "Reopening during the exit animation must cancel the close")
	hud.call("close_progression")
	await create_timer(0.4).timeout


func _test_category_tabs(hud: Node, progression: Node) -> void:
	hud.call("_set_progression_open", "shop")
	await process_frame
	var categories := hud.find_child("ShopCategories", true, false)
	_check(categories != null and categories.get_child_count() == 5, "The shop must offer its five categories as tabs")
	if categories == null:
		return
	(categories.get_child(1) as Button).button_pressed = true
	await process_frame
	_check(str(hud.get("_active_shop_category")) == "skins", "Pressing the Skins tab must show skins")
	var selected := hud.get("_selected_shop_item") as Dictionary
	_check(str(selected.get("id", "")) == str(progression.call("get_equipped", "skins")), "A category must open on the item the blob is wearing")
	var overlay := hud.find_child("ShopOverlay", true, false) as Control
	_check(overlay.find_children("*", "SubViewport", true, false).size() == 1, "Switching category must keep exactly one model viewport")
	var skin_count := (progression.call("get_items", "skins") as Array).size()
	_check(hud.find_children("ShopItem_*", "PanelContainer", true, false).size() == skin_count, "The grid must show every item in the chosen category")
	(categories.get_child(0) as Button).button_pressed = true
	await process_frame
	hud.call("close_progression")
	await create_timer(0.4).timeout


func _test_page_tabs(hud: Node) -> void:
	hud.call("_set_progression_open", "shop")
	await process_frame
	var pages := hud.find_child("DrawerPages", true, false)
	_check(pages != null, "The drawer header must switch between Shop and Quests")
	if pages != null:
		(pages.get_child(1) as Button).button_pressed = true
		await process_frame
		_check(str(hud.get("_active_progression_page")) == "quests", "The Quests tab must open the quest board")
		_check(hud.find_child("QuestTabs", true, false) != null, "The quest board must offer Daily and Weekly")
		_check(hud.find_children("ShopItem_*", "PanelContainer", true, false).is_empty(), "Leaving the shop must remove its item grid")
	hud.call("close_progression")
	await create_timer(0.4).timeout


func _test_claim_from_board(hud: Node, progression: Node) -> void:
	var daily := progression.get("daily_quests") as Array
	_check(not daily.is_empty(), "Progression must deal daily quests")
	if daily.is_empty():
		return
	# The autoload loads the player's real save, which may already hold
	# finished objectives. Exactly one quest must be ready, or the board
	# offers several CLAIM buttons and the test presses one it did not set up.
	for index in daily.size():
		var other := daily[index] as Dictionary
		other["claimed"] = false
		other["completed"] = false
		other["progress"] = 0
	var quest := daily[0] as Dictionary
	quest["progress"] = int(quest.get("target", 1))
	quest["completed"] = true
	var balance_before := int(progression.call("get_balance"))
	hud.call("_set_progression_open", "quests")
	await process_frame
	var claim: Button = null
	for candidate in hud.find_children("QuestReward", "Button", true, false):
		var button := candidate as Button
		if not button.disabled and "CLAIM" in button.text:
			claim = button
	_check(claim != null, "A finished objective must offer an enabled CLAIM button")
	if claim == null:
		return
	claim.pressed.emit()
	await process_frame
	_check(bool(quest.get("claimed", false)), "Pressing CLAIM must claim the objective")
	_check(int(progression.call("get_balance")) == balance_before + int(quest.get("reward", 0)), "Claiming must pay the objective's reward")
	var completed_shown := false
	for candidate in hud.find_children("QuestReward", "Button", true, false):
		if (candidate as Button).text == "COMPLETED":
			completed_shown = true
	_check(completed_shown, "The board must show the claimed objective as COMPLETED")
	# Coins fly for about a second, then the header counts up.
	await create_timer(2.2).timeout
	var balance_label := hud.find_child("DrawerBalanceValue", true, false) as Label
	_check(balance_label != null and balance_label.text == "%d" % int(progression.call("get_balance")), "The drawer balance must land on the new total after the claim")
	hud.call("close_progression")
	await create_timer(0.4).timeout


func _test_reduced_motion(hud: Node) -> void:
	hud.call("apply_ui_settings", {"reduced_motion": true})
	hud.call("_set_progression_open", "shop")
	await process_frame
	var drawer := hud.find_child("ProgressionDrawer", true, false) as Control
	_check(drawer.scale.is_equal_approx(Vector2.ONE) and is_equal_approx(drawer.modulate.a, 1.0), "Reduced motion must open the drawer at rest, with no scale-in")
	for card in hud.find_children("ShopItem_*", "PanelContainer", true, false):
		if not is_equal_approx((card as Control).modulate.a, 1.0):
			_check(false, "Reduced motion must show shop cards without the staggered fade")
			break
	hud.call("close_progression")
	_check(not (hud.find_child("ShopOverlay", true, false) as Control).visible, "Reduced motion must close the drawer instantly")
	hud.call("apply_ui_settings", {"reduced_motion": false})


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
