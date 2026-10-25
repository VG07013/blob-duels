extends SceneTree

## Renders the shop and quest drawer for review: the shop settled and mid
## entrance, the purchase dialog, and the quest board with one reward ready.
## Needs a display (not part of the headless suite).

const MAIN_SCENE := preload("res://scenes/main.tscn")
const OUTPUT_DIR := "res://artifacts/screenshots"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	root.size = Vector2i(1280, 720)
	var game := MAIN_SCENE.instantiate()
	root.add_child(game)
	await _frames(2)
	game.set_process(false)
	game.set_physics_process(false)
	var hud := game.get_node("HUD")
	var progression := root.get_node("Progression")
	await create_timer(1.6).timeout

	hud.call("_set_progression_open", "shop")
	await create_timer(0.12).timeout
	await _save("drawer_shop_entrance.png")
	await create_timer(1.2).timeout
	await _save("drawer_shop.png")
	var items := progression.call("get_items", "skins") as Array
	(hud.find_child("ShopCategories", true, false).get_child(1) as Button).button_pressed = true
	await create_timer(0.3).timeout
	hud.drawer.call("_select_shop_item", items[3])
	await create_timer(1.0).timeout
	await _save("drawer_shop_skins.png")
	hud.drawer.call("_show_purchase_confirm", "skins", items[3])
	await create_timer(0.6).timeout
	await _save("drawer_purchase.png")
	var modal := hud.find_child("PurchaseModal", true, false)
	if modal != null:
		modal.free()

	# Mark one daily objective done so the board shows a claimable reward.
	for quest_value in progression.get("daily_quests") as Array:
		var quest := quest_value as Dictionary
		if not bool(quest.get("claimed", false)):
			quest["progress"] = int(quest.get("target", 1))
			quest["completed"] = true
			break
	hud.drawer.call("_switch_progression_page", "quests")
	await create_timer(1.4).timeout
	await _save("drawer_quests.png")
	(hud.find_child("QuestTabs", true, false).get_child(1) as Button).button_pressed = true
	await create_timer(1.4).timeout
	await _save("drawer_quests_weekly.png")
	hud.call("close_progression")
	await _frames(2)

	game.queue_free()
	await process_frame
	print("PROGRESSION DRAWER VISUAL CAPTURE PASS")
	quit(0)


func _frames(count: int) -> void:
	for _index in count:
		await process_frame


func _save(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("%s/%s" % [OUTPUT_DIR, file_name])
