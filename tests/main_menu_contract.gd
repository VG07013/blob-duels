extends SceneTree

## The pre-game screen is one full-screen main menu with everything on a
## single page: no Play -> chooser -> host/join page hopping, no walkable lobby.

const HUD_SCENE := preload("res://scenes/hud.tscn")
const COSMETIC_LIBRARY := preload("res://scripts/cosmetic_library.gd")
const NETWORK_SESSION_SCRIPT := preload("res://scripts/network_session.gd")
const COIN_ICON_SCRIPT := preload("res://scripts/ui/coin_icon.gd")

## Every one of these must be on screen at once, straight after the menu opens.
const ONE_PAGE_CONTROLS := [
	"PracticeChoice", "BotChoice", "BotDifficulty", "MapPicker", "FormatButton",
	"StartHost", "RoomCode", "CopyButton", "CodeInput", "StartJoin",
	"NameInput", "ColorSwatches", "ShopButton", "BlobStage",
	"CoinBalance", "QuestPanel", "DockQuestsButton", "LoadoutButton",
	"SettingsButton", "QuitButton",
]
## The old paged lobby. None of it may come back.
const RETIRED_NAMES := ["LobbyPanel", "PlayButton", "CustomizeButton", "ModeChooser", "CustomizeMenu", "HostMenu", "JoinMenu", "HostChoice", "JoinChoice", "DockShopButton"]

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
	await process_frame

	_test_one_page_menu(hud)
	await _test_actions(hud)
	await _test_identity(hud)
	await _test_motion(hud)
	_test_menu_hides_for_play(hud)
	_test_start_state_contracts()
	_test_room_code_contract()

	hud.queue_free()
	if failures.is_empty():
		print("MAIN MENU CONTRACT PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _test_one_page_menu(hud: Node) -> void:
	var menu := hud.find_child("MainMenu", true, false) as Control
	_check(menu != null and menu.visible, "The pre-game screen must be the full-screen MainMenu")
	if menu == null:
		return
	var screen := Rect2(Vector2.ZERO, Vector2(root.size))
	_check(menu.get_global_rect().size.is_equal_approx(screen.size), "The main menu must cover the whole screen")
	for control_name in ONE_PAGE_CONTROLS:
		var control := hud.find_child(control_name, true, false) as Control
		_check(control != null and control.is_visible_in_tree(), "%s must be visible on the one-page menu without navigating" % control_name)
		if control != null and control.is_visible_in_tree():
			_check(screen.encloses(control.get_global_rect()), "%s must sit fully on screen at 1280x720" % control_name)
	for retired in RETIRED_NAMES:
		_check(hud.find_child(retired, true, false) == null, "The paged lobby's %s must not come back" % retired)
	_check(menu.find_children("*", "ColorPicker", true, false).is_empty(), "Colour stays a curated swatch row, never a ColorPicker")
	_check(_visible_of_type(menu, "LineEdit").size() == 2, "The menu asks for exactly two texts: a name and a room code")
	var code_input := hud.find_child("CodeInput", true, false) as LineEdit
	if code_input != null:
		_check("code" in code_input.placeholder_text.to_lower(), "The join field must ask for a room code, not a host address")

	var coin_chip := hud.find_child("CoinBalance", true, false) as Control
	var coin_value := hud.find_child("CoinValue", true, false) as Label
	_check(coin_chip != null and menu.is_ancestor_of(coin_chip), "The coin balance belongs to the menu's top bar")
	_check(coin_value != null and coin_value.get_theme_font_size("font_size") >= 22, "The coin value needs strong metric typography")
	var has_coin_art := false
	if coin_chip != null:
		for candidate in coin_chip.find_children("*", "Control", true, false):
			has_coin_art = has_coin_art or candidate.get_script() == COIN_ICON_SCRIPT
	_check(has_coin_art, "Every coin readout must use the supplied little-blob coin")
	_check(not _visible_text(menu).contains("BLOB COINS"), "The balance shows only the icon and number")
	var quest_panel := hud.find_child("QuestPanel", true, false) as Control
	if quest_panel != null:
		_check(_visible_text(quest_panel).contains("TODAY"), "The quest card must name today's daily rotation")
		_check(quest_panel.find_children("*", "ProgressBar", true, false).size() >= 1, "Every listed quest shows its progress")


func _test_actions(hud: Node) -> void:
	var events: Array[String] = []
	hud.connect("practice_requested", func() -> void: events.append("practice"))
	hud.connect("bot_requested", func(difficulty: int) -> void: events.append("bot:%d" % difficulty))
	hud.connect("host_requested", func() -> void: events.append("host"))
	hud.connect("join_requested", func(code: String) -> void: events.append("join:%s" % code))
	hud.connect("settings_requested", func() -> void: events.append("settings"))

	(hud.find_child("PracticeChoice", true, false) as Button).pressed.emit()
	var hard := hud.find_child("BotDifficulty", true, false).get_child(2) as Button
	hard.button_pressed = true
	(hud.find_child("BotChoice", true, false) as Button).pressed.emit()
	(hud.find_child("StartHost", true, false) as Button).pressed.emit()
	var code_input := hud.find_child("CodeInput", true, false) as LineEdit
	code_input.text = "C0A8-012A"
	code_input.text_submitted.emit(code_input.text)
	(hud.find_child("SettingsButton", true, false) as Button).pressed.emit()
	_check(events == ["practice", "bot:2", "host", "join:C0A8-012A", "settings"], "Each menu action must raise its request straight from the one page (got %s)" % [events])

	var map_picker := hud.find_child("MapPicker", true, false)
	(map_picker.get_child(1) as Button).button_pressed = true
	_check(str(hud.call("get_selected_map_id")) == "bounceground", "Picking a map segment must change the duel map")
	(map_picker.get_child(0) as Button).button_pressed = true
	_check(str(hud.call("get_selected_map_id")) == "skyline", "Arena (skyline) is the first map segment")

	(hud.find_child("ShopButton", true, false) as Button).pressed.emit()
	await process_frame
	_check(bool(hud.call("is_progression_open")), "LOADOUT & SHOP must open the shop drawer")
	_check((hud.find_child("MainMenu", true, false) as Control).visible, "The shop drawer opens over the menu, not instead of it")
	hud.call("close_progression")


func _test_identity(hud: Node) -> void:
	var colors: Array[Color] = []
	hud.connect("identity_changed", func(_player_name: String, color: Color) -> void: colors.append(color))
	var swatches := hud.find_child("ColorSwatches", true, false)
	_check(swatches != null and swatches.get_child_count() >= 4, "The menu offers the curated blob colours")
	if swatches == null or swatches.get_child_count() < 2:
		return
	(swatches.get_child(1) as Button).pressed.emit()
	await process_frame
	var picked := hud.call("get_player_color") as Color
	_check(not colors.is_empty() and colors[-1] == picked, "Picking a swatch must update the player's identity")
	var stage := hud.find_child("BlobStage", true, false)
	_check(stage != null and (stage.get("blob_tint") as Color) == picked, "The hero blob must wear the picked colour")
	var name_input := hud.find_child("NameInput", true, false) as LineEdit
	name_input.text = "Rival"
	name_input.text_changed.emit("Rival")
	_check(str(hud.call("get_player_name")) == "Rival", "The name field sets the duel name")


func _test_motion(hud: Node) -> void:
	var menu := hud.find_child("MainMenu", true, false) as Control
	var backdrop := menu.find_child("Backdrop", true, false) as ColorRect
	_check(backdrop != null and backdrop.material is ShaderMaterial, "The menu backdrop must be the animated shader hall")
	_check(menu.find_child("Wordmark", true, false) is MenuWordmark, "The logo must be the animated wordmark")
	var rig := menu.find_child("PreviewRig", true, false) as Node3D
	var heights: Array[float] = []
	for _sample in 14:
		heights.append(rig.position.y)
		await create_timer(0.12).timeout
	_check(heights.max() - heights.min() > 0.3, "The hero blob must hop on its pedestal")

	hud.call("set_lobby_mode", false)
	hud.call("set_lobby_mode", true)
	await process_frame
	var card := menu.find_child("BotCard", true, false) as Control
	_check(card.modulate.a < 0.5, "Opening the menu must play the entrance: cards start faded")
	await create_timer(1.6).timeout
	_check(card.modulate.a > 0.95 and card.scale.is_equal_approx(Vector2.ONE), "Every card must settle fully in after the entrance")

	hud.call("apply_ui_settings", {"reduced_motion": true})
	hud.call("set_lobby_mode", false)
	hud.call("set_lobby_mode", true)
	await process_frame
	await process_frame
	_check(card.modulate.a > 0.95, "Reduced motion must skip the entrance")
	hud.call("apply_ui_settings", {"reduced_motion": false})


func _test_menu_hides_for_play(hud: Node) -> void:
	hud.call("set_lobby_mode", false)
	var menu := hud.find_child("MainMenu", true, false) as Control
	_check(not menu.visible, "The menu must get out of the way once a match starts")
	hud.call("set_lobby_mode", true)


func _test_start_state_contracts() -> void:
	var game_source := FileAccess.get_file_as_string("res://scripts/game.gd")
	_check("var third_person_enabled := true" in game_source, "Matches start from third-person automatically")
	_check("Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)" in game_source, "The menu must start with the mouse unlocked")
	var player_source := FileAccess.get_file_as_string("res://scripts/player.gd")
	var default_color := _first_color(player_source, "var\\s+blob_color\\s*:=\\s*Color\\(([^)]+)\\)")
	_check(_is_bright_cyan(default_color), "Default blue blob must be brighter and more cyan")
	var classic_profile := COSMETIC_LIBRARY.skin_profile("classic_blue", Color.WHITE)
	_check(_is_bright_cyan(classic_profile.get("primary", Color.BLACK) as Color), "Classic Blue shop skin must match the brighter cyan default")


func _test_room_code_contract() -> void:
	var room_code := str(NETWORK_SESSION_SCRIPT.address_to_room_code("192.168.1.42"))
	_check(room_code == "C0A8-012A", "Host room code must be short, stable, and easy to share")
	_check(str(NETWORK_SESSION_SCRIPT.room_code_to_address(room_code)) == "192.168.1.42", "Join room code must decode to the host LAN address")
	_check(str(NETWORK_SESSION_SCRIPT.room_code_to_address("NOT-A-CODE")).is_empty(), "Join must reject malformed room codes")
	_check(str(NETWORK_SESSION_SCRIPT.room_code_to_address("C0A8012A")).is_empty(), "Join must require the displayed room-code format")
	var session := NETWORK_SESSION_SCRIPT.new()
	_check(bool(session.call("_is_connectable_ipv4", "203.0.113.42")), "Port-forwarded internet matches must continue accepting a public IPv4 address")
	_check(not bool(session.call("_is_connectable_ipv4", "239.1.2.3")), "Join must reject multicast targets")
	_check(not bool(session.call("_is_connectable_ipv4", "203.0.113.+42")), "Join must reject signed or malformed IPv4 octets")
	session.free()


func _visible_of_type(scope: Node, type_name: String) -> Array[Node]:
	var matches: Array[Node] = []
	for candidate in scope.find_children("*", type_name, true, false):
		if (candidate as Control).is_visible_in_tree():
			matches.append(candidate)
	return matches


func _visible_text(scope: Node) -> String:
	var result := ""
	for candidate in scope.find_children("*", "Label", true, false):
		var label := candidate as Label
		if label.is_visible_in_tree():
			result += label.text.to_upper() + " "
	return result


func _first_color(source: String, pattern: String) -> Color:
	var expression := RegEx.create_from_string(pattern)
	var result := expression.search(source)
	if result == null:
		return Color.BLACK
	var channels := result.get_string(1).split(",")
	if channels.size() < 3:
		return Color.BLACK
	return Color(channels[0].to_float(), channels[1].to_float(), channels[2].to_float(), 1.0)


func _is_bright_cyan(color: Color) -> bool:
	return color.r <= 0.18 and color.g >= 0.78 and color.b >= 0.94 and color.b > color.g


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
