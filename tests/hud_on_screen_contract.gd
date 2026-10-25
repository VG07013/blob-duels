extends SceneTree

## Product rule: no HUD panel may sit partly off screen, at any window shape
## the game supports (16:9, the 16:10 MacBook panel, 4:3, small windows and
## ultrawide). Every state that shows a panel is exercised: lobby pages, shop,
## quests, purchase confirmation, duel HUD with round intro and kill feed,
## coin rewards, pause menu, and the victory screen.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const WINDOW_SIZES: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1280, 832), Vector2i(1024, 768), Vector2i(900, 600), Vector2i(1920, 800)]
## Panels may draw a soft shadow or border a couple of pixels past their rect.
const EDGE_TOLERANCE := 2.0

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game := MAIN_SCENE.instantiate()
	root.add_child(game)
	await _frames(4)
	var hud := game.get_node("HUD")
	var pause_menu := game.get_node("PauseMenu")
	for window_size in WINDOW_SIZES:
		root.size = window_size
		await _frames(3)
		var tag := "%dx%d" % [window_size.x, window_size.y]
		_check_on_screen(hud.get("main_menu"), "Main menu (must cover the screen)", tag, true)
		for control_name in ["BotCard", "PracticeCard", "OnlineCard", "BlobStage", "NameInput", "ShopButton", "LoadoutCard", "QuitButton"]:
			_check_on_screen(hud.find_child(control_name, true, false), "Main menu %s" % control_name, tag)
		_check_on_screen(hud.drawer.get("_coin_chip"), "Coin balance chip", tag)
		_check_on_screen(hud.drawer.get("_quest_panel"), "Menu quest card", tag)
		hud.call("_show_progression_toast", "Quest complete", "Play 3 Matches")
		await _frames(2)
		_check_on_screen(hud.drawer.get("_toast_stack"), "Quest toast stack", tag)
		for drawer in ["shop", "quests"]:
			hud.call("_set_progression_open", drawer)
			await _frames(4)
			for child in hud.get_children():
				if child is Control and (child as Control).visible and str(child.name).to_lower().contains(drawer.left(4)):
					_check_on_screen(child, "%s drawer" % drawer.capitalize(), tag)
		hud.call("close_progression")
		await _frames(2)
		hud.call("set_fps_counter_visible", true)
		await _frames(2)
		_check_on_screen(hud.get("_fps_label"), "FPS counter", tag)
		hud.call("set_fps_counter_visible", false)

	root.size = Vector2i(1280, 832)
	await _frames(2)
	hud.call("_set_progression_open", "shop")
	await _frames(4)
	var first_item := (root.get_node("Progression").call("get_items", "abilities") as Array)[0] as Dictionary
	hud.drawer.call("_show_purchase_confirm", "abilities", first_item)
	await create_timer(0.35).timeout
	for window_size in WINDOW_SIZES:
		root.size = window_size
		await _frames(3)
		var modal := hud.find_child("PurchaseModal", true, false) as Control
		_check_on_screen(modal, "Purchase confirmation backdrop (must cover the screen)", "%dx%d" % [window_size.x, window_size.y], true)
		_check_on_screen(modal.get_child(1) if modal != null and modal.get_child_count() > 1 else null, "Purchase confirmation dialog", "%dx%d" % [window_size.x, window_size.y])
	var open_modal := hud.find_child("PurchaseModal", true, false)
	if open_modal != null:
		open_modal.queue_free()
	hud.call("close_progression")
	await _frames(2)

	game.call("_start_bot_match", 1)
	await _frames(6)
	var feedback := hud.get("_feedback") as Control
	feedback.call("show_round_intro", 1, 5, "Player", Color.RED, "Rival Bot", Color.CYAN, 0, 0)
	feedback.call("add_kill_feed_entry", "Player", Color.RED, "Rival Bot", Color.CYAN, "rail")
	await create_timer(0.35).timeout
	for window_size in WINDOW_SIZES:
		root.size = window_size
		await _frames(3)
		var tag := "%dx%d" % [window_size.x, window_size.y]
		_check_on_screen(feedback, "Feedback layer (must cover the screen)", tag, true)
		_check_on_screen(feedback.get_node("RoundIntro"), "Round intro card", tag)
		_check_on_screen(feedback.get_node("KillFeed"), "Kill feed", tag)
		_check_on_screen(hud.get("health_panel"), "Health bar", tag)
		_check_on_screen(hud.get("scoreboard"), "Scoreboard", tag)
		_check_on_screen(hud.get("_ability_panel"), "Ability badge", tag)
		game.call("_open_pause")
		await _frames(3)
		_check_on_screen(pause_menu.get_node("PausePanel"), "Pause menu", tag)
		game.call("_resume_from_pause")
		await _frames(2)

	root.size = Vector2i(1280, 832)
	game.set("_match_over", true)
	game.call("_start_victory_sequence", 0)
	await create_timer(4.2).timeout
	for window_size in WINDOW_SIZES:
		root.size = window_size
		await _frames(3)
		var tag := "%dx%d" % [window_size.x, window_size.y]
		_check_on_screen(hud.get("result_banner"), "Victory banner", tag)
		_check_on_screen(hud.get("roster_panel"), "Victory roster", tag)
		_check_on_screen(hud.get("_reward_panel"), "Match rewards card", tag)

	game.call("_return_to_lobby")
	await _frames(2)
	game.queue_free()
	await _frames(2)
	if _failures.is_empty():
		print("HUD ON SCREEN CONTRACT PASS")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _check_on_screen(value: Variant, label: String, tag: String, must_cover := false) -> void:
	var control := value as Control
	if control == null:
		_failures.append("%s must exist to be checked (%s)" % [label, tag])
		return
	if not control.is_visible_in_tree():
		return
	var viewport_rect := Rect2(Vector2.ZERO, control.get_viewport_rect().size)
	var rect := control.get_global_rect()
	if must_cover:
		if rect.size.x < viewport_rect.size.x - EDGE_TOLERANCE or rect.size.y < viewport_rect.size.y - EDGE_TOLERANCE:
			_failures.append("%s must span the whole screen at %s, got %s in %s" % [label, tag, rect, viewport_rect])
		return
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return
	var grown := viewport_rect.grow(EDGE_TOLERANCE)
	if not grown.encloses(rect):
		_failures.append("%s must stay fully on screen at %s, got %s in %s" % [label, tag, rect, viewport_rect])


func _frames(count: int) -> void:
	for i in count:
		await process_frame
