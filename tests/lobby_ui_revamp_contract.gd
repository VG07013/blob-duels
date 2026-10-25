extends SceneTree

const HUD_SCENE := preload("res://scenes/hud.tscn")
const PAUSE_SCENE := preload("res://scenes/ui/pause_menu.tscn")
const COIN_ICON_SCRIPT := preload("res://scripts/ui/coin_icon.gd")
const SHOP_PREVIEW_SCRIPT := preload("res://scripts/ui/shop_model_preview.gd")

const REFERENCE_VIEWPORT := Vector2(1280.0, 720.0)

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

	_test_progression_widgets(hud)
	_test_lobby_widget_suppression(hud)
	await _test_compact_progression_drawers(hud)

	hud.queue_free()
	await process_frame
	await _test_compact_pause_and_settings()

	if failures.is_empty():
		print("LOBBY UI REVAMP CONTRACT PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _test_progression_widgets(hud: Node) -> void:
	var coin_chip := hud.find_child("CoinBalance", true, false) as PanelContainer
	var quest_panel := hud.find_child("QuestPanel", true, false) as PanelContainer
	_check(coin_chip != null, "The menu must expose a dedicated coin counter")
	_check(quest_panel != null, "The menu must expose a dedicated daily-quest surface")
	if coin_chip != null:
		_check(
			coin_chip.size.x <= 190.0 and coin_chip.size.y <= 64.0,
			"Coin counter must remain a small glanceable HUD chip"
		)
		_check(_is_translucent_flat_panel(coin_chip, 0.9), "Coin counter must use a translucent bordered surface")
		_check(_count_controls_with_script(coin_chip, COIN_ICON_SCRIPT) == 1, "Coin counter must use the shared supplied blob-coin renderer")
		_check(_has_numeric_label(coin_chip), "Coin counter must present the balance as readable text")
	if quest_panel != null:
		_check(
			quest_panel.size.x <= 340.0 and quest_panel.size.y <= 230.0,
			"Daily quests must stay in a compact glanceable panel"
		)
		_check(_has_label_fragment(quest_panel, "TODAY"), "Quest surface must clearly identify today's daily rotation")
		_check(
			quest_panel.find_children("*", "ProgressBar", true, false).size() >= 1,
			"Daily quest surface must visualize objective progress"
		)


func _test_lobby_widget_suppression(hud: Node) -> void:
	_check(hud.has_method("set_lobby_ui_suppressed"), "Menu settings need a dedicated suppression path")
	if not hud.has_method("set_lobby_ui_suppressed"):
		return
	var menu := hud.find_child("MainMenu", true, false) as Control
	hud.call("set_lobby_ui_suppressed", true)
	_check(menu.visible and menu.modulate.v < 0.8, "Settings must sit over a dimmed menu, keeping it as the backdrop")
	_check(not menu.can_process(), "The dimmed menu must stop animating and taking input under settings")
	_check(not (hud.find_child("HealthPanel", true, false) as Control).visible, "Suppressing the menu must not enable the match health HUD")
	_check(not (hud.find_child("AbilityHUD", true, false) as Control).visible, "Suppressing the menu must not enable the match ability HUD")
	hud.call("set_lobby_ui_suppressed", false)
	_check(menu.modulate == Color.WHITE and menu.can_process(), "Closing settings must restore the menu")


func _test_compact_progression_drawers(hud: Node) -> void:
	hud.call("_set_progression_open", "shop")
	await process_frame
	var overlay := hud.find_child("ShopOverlay", true, false) as Control
	_check(overlay != null and overlay.visible, "Shop action must open the progression surface")
	if overlay == null:
		return
	var shop_drawer := _largest_panel(overlay)
	_check(shop_drawer != null, "Shop must render inside a bounded drawer panel")
	if shop_drawer != null:
		_test_drawer_bounds(shop_drawer, "Shop")
	_check(_full_rect_backdrop_alpha(overlay) <= 0.72, "Shop backdrop must stay transparent enough to keep the menu visible behind it")
	_check(
		_count_controls_with_script(overlay, SHOP_PREVIEW_SCRIPT) >= 1,
		"Shop must render the selected item on the real in-game blob model"
	)
	_check(
		_count_nodes_of_type(overlay, "SubViewport") == 1,
		"Shop must use one bounded model viewport instead of many expensive animated thumbnails"
	)

	hud.call("_set_progression_open", "quests")
	await process_frame
	var quest_drawer := _largest_panel(overlay)
	_check(quest_drawer != null, "Quest board must render inside a bounded drawer panel")
	if quest_drawer != null:
		_test_drawer_bounds(quest_drawer, "Quest board")
	_check(_has_label_fragment(overlay, "DAILY"), "Quest drawer must expose a daily quest view")
	_check(_has_label_fragment(overlay, "WEEKLY"), "Quest drawer must expose a weekly quest view")
	_check(
		overlay.find_children("*", "ProgressBar", true, false).size() >= 1,
		"Quest drawer must pair each objective with visible progress"
	)
	hud.call("close_progression")


func _test_drawer_bounds(drawer: PanelContainer, surface_name: String) -> void:
	_check(
		drawer.size.x <= REFERENCE_VIEWPORT.x * 0.72
		and drawer.size.y <= REFERENCE_VIEWPORT.y * 0.84,
		"%s drawer must not cover the whole screen" % surface_name
	)
	_check(_is_translucent_flat_panel(drawer, 0.94), "%s drawer must use a translucent game-UI shell" % surface_name)


func _test_compact_pause_and_settings() -> void:
	var settings_path := "user://blob_duels_lobby_ui_revamp_contract.cfg"
	var pause := PAUSE_SCENE.instantiate()
	pause.settings_path = settings_path
	root.add_child(pause)
	await process_frame
	pause.call("open_pause")
	await process_frame

	var pause_panel := pause.find_child("PausePanel", true, false) as PanelContainer
	var backdrop := pause.find_child("Backdrop", true, false) as ColorRect
	_check(pause_panel != null, "Escape menu must retain a dedicated pause panel")
	if pause_panel != null:
		_check(
			pause_panel.size.x <= REFERENCE_VIEWPORT.x * 0.65
			and pause_panel.size.y <= REFERENCE_VIEWPORT.y * 0.78,
			"Pause and settings must use a compact panel rather than dominating the screen"
		)
		_check(_is_translucent_flat_panel(pause_panel, 0.92), "Pause panel must use a translucent competitive-game surface")
		for action_name in ["LobbyButton", "RespawnButton", "ResumeButton"]:
			var action := pause_panel.find_child(action_name, true, false) as Button
			_check(action != null and action.custom_minimum_size.y <= 52.0, "%s must remain a compact pause action" % action_name)
	if backdrop != null:
		_check(backdrop.color.a <= 0.72, "Pause backdrop must keep the live match visibly present")

	pause.call("_show_page", 1)
	await process_frame
	var settings_page := pause.find_child("SettingsPage", true, false) as Control
	_check(settings_page != null and settings_page.visible, "Settings tab must open the settings surface")
	if settings_page != null:
		for section in ["CONTROLS", "AUDIO", "VIDEO"]:
			_check(_has_exact_label(settings_page, section), "Settings must group options under %s" % section)
		_check(settings_page.find_children("*", "HSlider", true, false).size() >= 3, "Settings must retain direct slider controls")
		_check(settings_page.find_children("*", "OptionButton", true, false).size() >= 3, "Settings must retain direct quality selectors")
		_check(settings_page.find_children("*", "CheckButton", true, false).size() >= 2, "Settings must retain direct on/off controls")

	pause.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(settings_path))
	await process_frame


func _is_translucent_flat_panel(panel: PanelContainer, maximum_alpha: float) -> bool:
	var style := panel.get_theme_stylebox("panel")
	return style is StyleBoxFlat and (style as StyleBoxFlat).bg_color.a <= maximum_alpha


func _largest_panel(scope: Node) -> PanelContainer:
	var largest: PanelContainer
	var largest_area := -1.0
	for candidate in scope.find_children("*", "PanelContainer", true, false):
		var panel := candidate as PanelContainer
		if not panel.is_visible_in_tree():
			continue
		var area := panel.size.x * panel.size.y
		if area > largest_area:
			largest = panel
			largest_area = area
	return largest


func _full_rect_backdrop_alpha(scope: Control) -> float:
	var maximum_alpha := 0.0
	for child_node in scope.get_children():
		var child := child_node as Control
		if child == null or child is PanelContainer:
			continue
		var fills_overlay := child.anchor_left <= 0.01 and child.anchor_top <= 0.01 and child.anchor_right >= 0.99 and child.anchor_bottom >= 0.99
		if not fills_overlay:
			continue
		if child is ColorRect:
			maximum_alpha = maxf(maximum_alpha, (child as ColorRect).color.a * child.modulate.a)
		elif child is TextureRect:
			var texture := (child as TextureRect).texture
			if texture is GradientTexture2D and (texture as GradientTexture2D).gradient != null:
				for color in (texture as GradientTexture2D).gradient.colors:
					maximum_alpha = maxf(maximum_alpha, color.a * child.modulate.a)
			else:
				maximum_alpha = maxf(maximum_alpha, child.modulate.a)
	return maximum_alpha


func _has_numeric_label(scope: Node) -> bool:
	for candidate in scope.find_children("*", "Label", true, false):
		var label_text := str((candidate as Label).text)
		for character in label_text:
			if str(character).is_valid_int():
				return true
	return false


func _has_label_fragment(scope: Node, fragment: String) -> bool:
	for candidate in scope.find_children("*", "Label", true, false):
		if fragment.to_upper() in str((candidate as Label).text).to_upper():
			return true
	for candidate in scope.find_children("*", "Button", true, false):
		if fragment.to_upper() in str((candidate as Button).text).to_upper():
			return true
	return false


func _has_exact_label(scope: Node, expected: String) -> bool:
	for candidate in scope.find_children("*", "Label", true, false):
		if str((candidate as Label).text).strip_edges().to_upper() == expected:
			return true
	return false


func _count_controls_with_script(scope: Node, script: Script) -> int:
	var count := 0
	for candidate in scope.find_children("*", "Control", true, false):
		if candidate.get_script() == script:
			count += 1
	return count


func _count_nodes_of_type(scope: Node, type_name: String) -> int:
	return scope.find_children("*", type_name, true, false).size()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
