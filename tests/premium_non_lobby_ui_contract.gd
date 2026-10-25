extends SceneTree

const HUD_SCENE := preload("res://scenes/hud.tscn")
const PAUSE_SCENE := preload("res://scenes/ui/pause_menu.tscn")
const COIN_ICON_SCRIPT := preload("res://scripts/ui/coin_icon.gd")

const REFERENCE_VIEWPORT := Vector2(1280.0, 720.0)
## Menu action cards and the heading each must show.
const MENU_ACTION_CARDS := {"BotCard": "DUEL A BOT", "PracticeCard": "PRACTICE", "OnlineCard": "PLAY A FRIEND"}

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

	await _test_bounded_progression_surfaces(hud)
	_test_menu_action_cards(hud)
	_test_match_hud_readability(hud)
	await _test_victory_and_reward_flow(hud)
	await _test_reduced_motion_feedback(hud)

	hud.queue_free()
	await process_frame
	await _test_premium_settings_surface()

	if failures.is_empty():
		print("PREMIUM NON-LOBBY UI CONTRACT PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _test_bounded_progression_surfaces(hud: Node) -> void:
	for page in ["shop", "quests"]:
		hud.call("_set_progression_open", page)
		await process_frame
		var overlay := hud.find_child("ShopOverlay", true, false) as Control
		var drawer := hud.find_child("ProgressionDrawer", true, false) as PanelContainer
		_check(overlay != null and overlay.visible, "%s must open its dedicated overlay" % page.capitalize())
		_check(drawer != null, "%s must render in one named, bounded drawer" % page.capitalize())
		if drawer == null:
			continue
		_check(
			drawer.size.x <= REFERENCE_VIEWPORT.x * 0.74
			and drawer.size.y <= REFERENCE_VIEWPORT.y * 0.84,
			"%s drawer must preserve a meaningful view of the live lobby" % page.capitalize()
		)
		_check(_control_fits_viewport(drawer, REFERENCE_VIEWPORT, 24.0), "%s drawer must retain safe margins" % page.capitalize())
		_check(_is_translucent_flat_panel(drawer), "%s drawer must use a translucent native shell" % page.capitalize())
		_check(_has_deliberate_type_hierarchy(drawer), "%s needs a deliberate heading/body/metadata type hierarchy" % page.capitalize())
		_check(
			_max_nested_panel_depth(drawer) <= 3,
			"%s must avoid stacking decorative cards inside more decorative cards" % page.capitalize()
		)
		if page == "shop":
			_check(_has_visible_primary_action(drawer, ["BUY", "EQUIP", "OWNED", "SELECT"]), "Shop selection needs one unmistakable primary action")
			_check(_all_action_buttons_have_state_feedback(drawer), "Shop buttons need distinct hover, pressed, and disabled interaction states")
		else:
			_check(_has_label_fragment(drawer, "RESET"), "Quest board must communicate when objectives refresh")
			_check(drawer.find_children("*", "ProgressBar", true, false).size() >= 1, "Quest board must show progress visually")
			_check(_has_visible_primary_action(drawer, ["CLAIM", "COMPLETED"]), "Quest rewards need an explicit claim/completed state")
	hud.call("close_progression")
	await process_frame


func _test_menu_action_cards(hud: Node) -> void:
	for card_name in MENU_ACTION_CARDS:
		var card := hud.find_child(card_name, true, false) as MenuCard
		_check(card != null and card.is_visible_in_tree(), "%s must be on the main menu" % card_name)
		if card == null:
			continue
		_check(_has_clear_page_context(card, str(MENU_ACTION_CARDS[card_name])), "%s needs a visible heading, not an unexplained form" % card_name)
		_check(_interactive_control_count(card) <= 8, "%s must avoid control overload" % card_name)
		_check(_all_controls_have_comfortable_height(card.content), "%s controls must be compact but comfortably clickable" % card_name)


func _test_match_hud_readability(hud: Node) -> void:
	hud.call("set_lobby_mode", false)
	hud.call("set_duel_mode", true)
	hud.call("set_ability_state", "dash", 2500, false, false)
	var required_controls := {
		"HealthPanel": hud.find_child("HealthPanel", true, false),
		"Crosshair": hud.find_child("Crosshair", true, false),
		"TimerLabel": hud.find_child("TimerLabel", true, false),
		"Scoreboard": hud.find_child("Scoreboard", true, false),
		"AbilityHUD": hud.find_child("AbilityHUD", true, false),
	}
	for control_name in required_controls:
		var control := required_controls[control_name] as Control
		_check(control != null and control.visible, "Match HUD must expose %s during a duel" % control_name)
		if control != null:
			_check(_control_fits_viewport(control, REFERENCE_VIEWPORT, 8.0), "%s must remain inside gameplay safe bounds" % control_name)
	var main_menu := hud.find_child("MainMenu", true, false) as Control
	var quest_panel := hud.find_child("QuestPanel", true, false) as Control
	var coin_chip := hud.find_child("CoinBalance", true, false) as Control
	_check(main_menu != null and not main_menu.visible, "Match HUD must not retain the main menu")
	_check(quest_panel != null and not quest_panel.is_visible_in_tree(), "Match HUD must hide menu quest tracking")
	_check(coin_chip != null and not coin_chip.is_visible_in_tree(), "Match HUD must hide menu currency")
	var timer := required_controls["TimerLabel"] as Label
	var health := hud.find_child("HealthValue", true, false) as Label
	var cooldown := hud.find_child("Cooldown", true, false) as Label
	_check(timer != null and timer.get_theme_font_size("font_size") >= 20, "Match timer must be readable at a glance")
	_check(health != null and "/" in health.text and health.get_theme_font_size("font_size") >= 16, "Health must show current and maximum values legibly")
	_check(cooldown != null and not cooldown.text.is_empty(), "Ability HUD must communicate its current state without relying on color")


func _test_victory_and_reward_flow(hud: Node) -> void:
	var players := [
		{"name": "Player", "color": Color.CYAN, "team_color": Color.CYAN, "team_name": "BLUE", "eliminations": 4, "deaths": 2},
		{"name": "Rival", "color": Color.ORANGE, "team_color": Color.ORANGE, "team_name": "RED", "eliminations": 2, "deaths": 4},
	]
	hud.call("begin_victory_cinematic")
	hud.call("show_victory", false, 0, players)
	hud.call("show_match_rewards", {
		"breakdown": [
			{"label": "Match complete", "amount": 35},
			{"label": "Eliminations", "amount": 20},
		],
		"total": 55,
	})
	await process_frame
	var overlay := hud.find_child("VictoryOverlay", true, false) as Control
	var banner := hud.find_child("ResultBanner", true, false) as PanelContainer
	var result := banner.find_child("Label", true, false) as Label if banner != null else null
	var rewards := hud.find_child("MatchRewards", true, false) as PanelContainer
	_check(overlay != null and overlay.visible, "Match result must have a dedicated visible overlay")
	_check(banner != null and banner.size.x <= REFERENCE_VIEWPORT.x * 0.64, "Result banner must stay bounded instead of becoming a full-screen poster")
	_check(result != null and _is_direct_result_copy(result.text), "Result heading must communicate VICTORY or DEFEAT immediately")
	_check(rewards != null and rewards.visible, "Match rewards must appear within the result flow")
	if rewards != null:
		_check(rewards.size.x <= REFERENCE_VIEWPORT.x * 0.46 and rewards.size.y <= REFERENCE_VIEWPORT.y * 0.58, "Reward summary must remain a compact receipt")
		_check(_count_controls_with_script(rewards, COIN_ICON_SCRIPT) == 1, "Reward total must use the same authored coin mark as the economy UI")
		_check(_reward_total_has_priority(rewards), "Reward total must be visually stronger than individual reward rows")
	_check(_has_visible_primary_action(overlay, ["CONTINUE", "PLAY AGAIN", "MAIN MENU"]), "Result flow needs an obvious next action")


func _test_reduced_motion_feedback(hud: Node) -> void:
	hud.call("hide_victory")
	hud.call("apply_ui_settings", {"reduced_motion": true})
	hud.call("show_round_banner", "ROUND WON", Color.CYAN)
	var round_banner := hud.find_child("RoundBanner", true, false) as Control
	_check(round_banner != null and round_banner.scale.is_equal_approx(Vector2.ONE), "Reduced motion must remove round-banner scale entrances")
	hud.call("show_victory", true, 1, [])
	var result_banner := hud.find_child("ResultBanner", true, false) as Control
	_check(result_banner != null and result_banner.scale.is_equal_approx(Vector2.ONE), "Reduced motion must remove victory-banner zoom entrances")
	hud.call("apply_ui_settings", {"reduced_motion": false})
	await process_frame


func _test_premium_settings_surface() -> void:
	root.size = Vector2i(1280, 720)
	var settings_path := "user://blob_duels_premium_ui_contract.cfg"
	var pause := PAUSE_SCENE.instantiate()
	pause.settings_path = settings_path
	root.add_child(pause)
	await process_frame
	pause.call("open_pause")
	pause.call("show_settings")
	await process_frame
	var panel := pause.find_child("PausePanel", true, false) as PanelContainer
	var page := pause.find_child("SettingsPage", true, false) as Control
	var rows := pause.find_child("Rows", true, false) as VBoxContainer
	_check(panel != null and panel.size.x <= REFERENCE_VIEWPORT.x * 0.7 and panel.size.y <= REFERENCE_VIEWPORT.y * 0.8, "Settings must remain a bounded, world-preserving panel")
	_check(panel != null and _is_translucent_flat_panel(panel), "Settings shell must retain the transparent competitive-game treatment")
	_check(page != null and _has_deliberate_type_hierarchy(page), "Settings needs a clear title, section, row-label, and value hierarchy")
	if rows != null:
		var direct_row_cards := 0
		for child in rows.get_children():
			if child is PanelContainer:
				direct_row_cards += 1
		_check(direct_row_cards <= 2, "Settings must use spacing and dividers instead of wrapping every option in another card")
	_check(page != null and _all_action_buttons_have_state_feedback(page), "Settings controls need visible hover, pressed, checked, and disabled states")
	_check(_has_exact_label(page, "ACCESSIBILITY"), "Settings must expose accessibility as a first-class section")
	_check(_has_button_fragment(page, "RESET"), "Settings must provide a clear reset-to-defaults action")
	pause.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(settings_path))
	await process_frame


func _has_deliberate_type_hierarchy(scope: Node) -> bool:
	var sizes: Array[int] = []
	for candidate in scope.find_children("*", "Label", true, false):
		var label := candidate as Label
		if not label.is_visible_in_tree() or label.text.strip_edges().is_empty():
			continue
		var font_size := label.get_theme_font_size("font_size")
		if font_size not in sizes:
			sizes.append(font_size)
	if sizes.size() < 3:
		return false
	sizes.sort()
	return sizes[-1] - sizes[0] >= 8


func _max_nested_panel_depth(scope: Node, depth := 0) -> int:
	var local_depth := depth + (1 if scope is PanelContainer else 0)
	var result := local_depth
	for child in scope.get_children():
		if child is Control and (child as Control).visible:
			result = maxi(result, _max_nested_panel_depth(child, local_depth))
	return result


func _all_action_buttons_have_state_feedback(scope: Node) -> bool:
	for candidate in scope.find_children("*", "Button", true, false):
		var button := candidate as Button
		if not button.is_visible_in_tree() or button.flat:
			continue
		var normal := button.get_theme_stylebox("normal")
		var hover := button.get_theme_stylebox("hover")
		var pressed := button.get_theme_stylebox("pressed")
		var disabled := button.get_theme_stylebox("disabled")
		if normal == null or hover == null or pressed == null or disabled == null:
			return false
		if normal == hover or normal == pressed:
			return false
	return true


func _has_visible_primary_action(scope: Node, fragments: Array[String]) -> bool:
	for candidate in scope.find_children("*", "Button", true, false):
		var button := candidate as Button
		if not button.is_visible_in_tree():
			continue
		var upper := button.text.to_upper()
		for fragment in fragments:
			if fragment in upper:
				return true
	return false


func _has_clear_page_context(scope: Node, page: String) -> bool:
	var target := page.to_upper()
	for candidate in scope.find_children("*", "Label", true, false):
		var label := candidate as Label
		if label.is_visible_in_tree() and target in label.text.to_upper() and label.get_theme_font_size("font_size") >= 15:
			return true
	return false


func _interactive_control_count(scope: Node) -> int:
	var count := 0
	for candidate in scope.find_children("*", "Control", true, false):
		var control := candidate as Control
		if control.visible and (control is BaseButton or control is LineEdit or control is OptionButton):
			count += 1
	return count


func _all_controls_have_comfortable_height(scope: Node) -> bool:
	for candidate in scope.find_children("*", "Control", true, false):
		var control := candidate as Control
		if not control.visible or not (control is BaseButton or control is LineEdit or control is OptionButton):
			continue
		var height := maxf(control.size.y, control.get_combined_minimum_size().y)
		if height < 38.0 or height > 58.0:
			return false
	return true


func _control_fits_viewport(control: Control, viewport_size: Vector2, margin: float) -> bool:
	var rect := control.get_global_rect()
	var safe := Rect2(Vector2(margin, margin), viewport_size - Vector2.ONE * margin * 2.0).grow(1.0)
	return safe.encloses(rect)


func _is_translucent_flat_panel(panel: PanelContainer) -> bool:
	var style := panel.get_theme_stylebox("panel")
	return style is StyleBoxFlat and (style as StyleBoxFlat).bg_color.a < 0.96


func _is_direct_result_copy(value: String) -> bool:
	var normalized := value.strip_edges().trim_suffix("!").to_upper()
	return normalized in ["VICTORY", "DEFEAT", "YOU WIN", "YOU LOST"]


func _reward_total_has_priority(rewards: Node) -> bool:
	var total_size := 0
	var row_size := 0
	for candidate in rewards.find_children("*", "Label", true, false):
		var label := candidate as Label
		var upper := label.text.to_upper()
		if "TOTAL" in upper or "COINS" in upper:
			total_size = maxi(total_size, label.get_theme_font_size("font_size"))
		elif "+" in label.text:
			row_size = maxi(row_size, label.get_theme_font_size("font_size"))
	return total_size >= row_size + 2


func _count_controls_with_script(scope: Node, script: Script) -> int:
	var count := 0
	for candidate in scope.find_children("*", "Control", true, false):
		if candidate.get_script() == script:
			count += 1
	return count


func _has_label_fragment(scope: Node, fragment: String) -> bool:
	if scope == null:
		return false
	for candidate in scope.find_children("*", "Label", true, false):
		if fragment.to_upper() in str((candidate as Label).text).to_upper():
			return true
	return false


func _has_exact_label(scope: Node, text_value: String) -> bool:
	if scope == null:
		return false
	for candidate in scope.find_children("*", "Label", true, false):
		if str((candidate as Label).text).strip_edges().to_upper() == text_value.to_upper():
			return true
	return false


func _has_button_fragment(scope: Node, fragment: String) -> bool:
	if scope == null:
		return false
	for candidate in scope.find_children("*", "Button", true, false):
		if fragment.to_upper() in str((candidate as Button).text).to_upper():
			return true
	return false


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
