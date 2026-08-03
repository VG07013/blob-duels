extends SceneTree

const HUD_SCENE := preload("res://scenes/hud.tscn")
const PAUSE_SCENE := preload("res://scenes/ui/pause_menu.tscn")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var hud := HUD_SCENE.instantiate()
	root.add_child(hud)
	await process_frame
	hud.call("set_lobby_mode", true)
	await process_frame

	await _test_progression_layering(hud)
	await _test_shop_state_copy(hud)
	await _test_play_chooser_containment(hud)
	await _test_universal_toast(hud)
	await _test_match_hud(hud)
	await _test_victory_composition(hud)

	var pause := PAUSE_SCENE.instantiate()
	pause.settings_path = "user://premium_ui_settings_contract.cfg"
	root.add_child(pause)
	await process_frame
	_test_lobby_pause_context(pause)

	pause.queue_free()
	hud.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://premium_ui_settings_contract.cfg"))
	if failures.is_empty():
		print("PREMIUM UI SYSTEM CONTRACT PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _test_progression_layering(hud: Node) -> void:
	hud.call("_set_progression_open", "shop")
	await process_frame
	var coin_chip := hud.find_child("CoinBalance", true, false) as Control
	_check(coin_chip != null and not coin_chip.visible, "Progression drawer must hide the duplicate floating coin chip")
	hud.call("_set_progression_open", "quests")
	await process_frame
	var overlay := hud.find_child("ShopOverlay", true, false) as Control
	var quest_scroll := _first_visible_scroll(overlay)
	_check(quest_scroll != null, "Quest board must retain a scrollable quest list")
	if quest_scroll != null:
		_check(quest_scroll.get_node_or_null("QuestScrollGutter") != null, "Quest list needs a named right gutter so rows do not collide with the scrollbar")
	hud.call("close_progression")
	await process_frame


func _test_shop_state_copy(hud: Node) -> void:
	hud.call("_set_progression_open", "shop")
	await process_frame
	var overlay := hud.find_child("ShopOverlay", true, false) as Control
	var equipped_card := _card_with_label_fragment(overlay, "EQUIPPED")
	_check(equipped_card != null, "Shop must expose an equipped item state")
	if equipped_card != null:
		var action_copy := ""
		for child in equipped_card.find_children("*", "Button", true, false):
			action_copy += " " + str((child as Button).text)
		_check("COINS" not in action_copy, "Equipped shop cards must not repeat a purchase price")
	hud.call("close_progression")
	await process_frame


func _test_play_chooser_containment(hud: Node) -> void:
	hud.call("_show_lobby_page", "chooser")
	await create_timer(0.22).timeout
	var panel := hud.find_child("LobbyPanel", true, false) as PanelContainer
	var chooser := hud.find_child("ModeChooser", true, false) as Control
	_check(panel != null and chooser != null and panel.get_global_rect().grow(1.0).encloses(chooser.get_global_rect()), "Play chooser must fit inside its compact lobby shell")
	hud.call("_show_lobby_page", "play")
	await process_frame


func _test_universal_toast(hud: Node) -> void:
	hud.call("_show_progression_toast", "QUEST COMPLETE", "Bounce 100 Times")
	await process_frame
	var toast_stack := hud.find_child("ToastStack", true, false) as Control
	_check(toast_stack != null, "Progression feedback needs a universal ToastStack outside the shop overlay")
	if toast_stack != null:
		_check(toast_stack.get_child_count() == 1, "Universal toast feedback should create one contained message")


func _test_match_hud(hud: Node) -> void:
	hud.call("set_ability_state", "dash", 0, false, false)
	hud.call("set_lobby_mode", false)
	hud.call("set_duel_mode", true)
	await process_frame
	var scoreboard := hud.find_child("Scoreboard", true, false) as Control
	var health := hud.find_child("HealthPanel", true, false) as Control
	var charge := hud.find_child("ChargePanel", true, false) as Control
	_check(scoreboard.size.x <= 420.0 and scoreboard.size.y <= 54.0, "Match scoreboard must be a compact top rail")
	_check(health.size.x <= 270.0 and health.size.y <= 58.0, "Health HUD must be compact and edge-safe")
	_check(charge.size.x <= 300.0 and charge.size.y <= 42.0, "Fling meter must be a slim gameplay rail")


func _test_victory_composition(hud: Node) -> void:
	hud.call("set_duel_score", 5, 2)
	hud.call("show_victory", true, 0, [
		{"name": "Player", "team_name": "RED", "team_color": Color.RED, "color": Color(0.2, 0.9, 1.0), "eliminations": 5, "deaths": 2},
		{"name": "Rival", "team_name": "BLUE", "team_color": Color.BLUE, "color": Color(0.55, 0.4, 1.0), "eliminations": 2, "deaths": 5},
	])
	hud.call("show_match_rewards", {"breakdown": [{"label": "Match complete", "amount": 50}], "total": 50})
	await process_frame
	await process_frame
	var overlay := hud.find_child("VictoryOverlay", true, false) as Control
	var result := hud.find_child("ResultBanner", true, false) as Control
	var roster := hud.find_child("RosterPanel", true, false) as Control
	var rewards := hud.find_child("MatchRewards", true, false) as Control
	var result_label := result.get_node("Stack/Label") as Label
	var result_detail := result.get_node("Stack/Detail") as Label
	var shade := overlay.get_node("Shade") as ColorRect
	var result_style := result.get_theme_stylebox("panel") as StyleBoxFlat
	var result_stack := result.get_node("Stack") as VBoxContainer
	var reward_rows := rewards.get_node("Stack/Rows") as VBoxContainer
	_check(shade.color.a >= 0.32 and shade.color.a <= 0.5, "Results shade must preserve the world while separating the outcome")
	_check(result.size.x <= 600.0, "Result banner must not span most of the screen")
	_check(rewards != null and rewards.size.x <= 460.0, "Match rewards must fit a bounded results column")
	_check(not result.get_global_rect().intersects(roster.get_global_rect()), "Outcome and roster surfaces must not collide")
	_check(result_style != null and result_style.content_margin_left >= 16.0 and result_style.content_margin_top >= 14.0, "VICTORY needs deliberate inset spacing from the result frame")
	_check(result_stack.get_theme_constant("separation") >= 6, "Result heading and score detail need a clear vertical rhythm")
	_check(reward_rows.get_theme_constant("separation") >= 8, "Reward receipt rows need consistent scan spacing")
	if result_label != null and result_detail != null:
		_check(result_label.text == "VICTORY" and "5" in result_detail.text and "2" in result_detail.text, "Final result must separate the outcome from the actual final score")


func _test_lobby_pause_context(pause: Node) -> void:
	pause.call("set_context", false, false)
	var state_pill := pause.get_node("PausePanel/Content/Header/StatePill") as Control
	_check(not state_pill.visible, "Lobby settings must not duplicate the LOBBY action as a header pill")


func _first_visible_scroll(root_node: Node) -> ScrollContainer:
	for child in root_node.find_children("*", "ScrollContainer", true, false):
		if (child as ScrollContainer).visible:
			return child as ScrollContainer
	return null


func _card_with_label_fragment(root_node: Node, fragment: String) -> PanelContainer:
	for child in root_node.find_children("*", "Label", true, false):
		if fragment not in str((child as Label).text):
			continue
		var candidate := child.get_parent()
		while candidate != null and candidate != root_node:
			if candidate is PanelContainer and (candidate as PanelContainer).custom_minimum_size.y >= 100.0:
				return candidate as PanelContainer
			candidate = candidate.get_parent()
	return null


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
