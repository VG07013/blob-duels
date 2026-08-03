extends SceneTree

const HUD_SCENE := preload("res://scenes/hud.tscn")
const COSMETIC_LIBRARY := preload("res://scripts/cosmetic_library.gd")
const NETWORK_SESSION_SCRIPT := preload("res://scripts/network_session.gd")

const MAIN_ACTION_NAMES := ["PlayButton", "CustomizeButton", "DockQuestsButton", "SettingsButton"]
const MODE_ACTION_NAMES := ["HostChoice", "JoinChoice", "PracticeChoice"]

var failures: Array[String] = []


func _initialize() -> void:
	var hud := HUD_SCENE.instantiate()
	root.add_child(hud)
	await process_frame
	hud.call("set_lobby_mode", true)
	await process_frame

	_test_main_lobby_surface(hud)
	await _test_customize_surface(hud)
	await _test_play_and_session_surfaces(hud)
	_test_lobby_world_contracts()
	_test_room_code_contract()

	hud.queue_free()
	if failures.is_empty():
		print("LOBBY REDESIGN CONTRACT PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _test_main_lobby_surface(hud: Node) -> void:
	var lobby_panel := hud.find_child("LobbyPanel", true, false) as Control
	var play := hud.find_child("PlayButton", true, false) as Button
	var customize := hud.find_child("CustomizeButton", true, false) as Button
	_check(lobby_panel != null, "Lobby HUD must expose a dedicated LobbyPanel")
	_check(play != null and play.visible, "Lobby must open with a PLAY button")
	_check(customize != null and customize.visible, "Lobby must open with a separate CUSTOMIZE button")
	if lobby_panel != null:
		_check_visible_leaf_names(lobby_panel, MAIN_ACTION_NAMES, "Main lobby")
	if play != null and customize != null:
		_check(play.get_theme_stylebox("normal") != customize.get_theme_stylebox("normal"), "PLAY and CUSTOMIZE must have genuinely different button styling")
		_check(customize.get_theme_stylebox("normal") is StyleBoxFlat, "CUSTOMIZE must use a native translucent button style")
	_check(hud.find_child("DockShopButton", true, false) == null, "Main lobby must not duplicate the Shop shortcut")


func _test_customize_surface(hud: Node) -> void:
	var customize := hud.find_child("CustomizeButton", true, false) as Button
	if customize == null:
		return
	customize.pressed.emit()
	await process_frame
	var customize_menu := hud.find_child("CustomizeMenu", true, false) as Control
	_check(customize_menu != null and customize_menu.visible, "CUSTOMIZE must open its own customization surface")
	if customize_menu == null:
		return
	var name_inputs := _visible_nodes_of_type(customize_menu, "LineEdit")
	_check(name_inputs.size() == 1, "Customize must expose exactly one player-name field")
	var shop_button := customize_menu.find_child("ShopButton", true, false) as Button
	_check(shop_button != null and shop_button.is_visible_in_tree(), "Customize must include a SHOP button")
	_check(_find_close_button(customize_menu) != null, "Customize must include a CLOSE button")
	_check(_visible_nodes_of_type(customize_menu, "ColorPicker").is_empty(), "Customize must not expose a ColorPicker")
	var color_swatches := customize_menu.find_child("ColorSwatches", true, false) as Control
	_check(color_swatches != null and color_swatches.is_visible_in_tree(), "Customize must expose the live blob color swatches")
	if shop_button != null:
		shop_button.pressed.emit()
		await process_frame
		_check(bool(hud.call("is_progression_open")), "SHOP must open the existing shop surface")
		hud.call("close_progression")
	var close := _find_close_button(customize_menu)
	if close != null:
		close.pressed.emit()
		await process_frame
		_check((hud.find_child("PlayButton", true, false) as Control).visible, "Closing Customize must return to PLAY and CUSTOMIZE")


func _test_play_and_session_surfaces(hud: Node) -> void:
	var play := hud.find_child("PlayButton", true, false) as Button
	if play == null:
		return
	play.pressed.emit()
	await process_frame
	var chooser := hud.find_child("ModeChooser", true, false) as Control
	_check(chooser != null and chooser.visible, "PLAY must reveal the mode chooser")
	if chooser == null:
		return
	for action_name in MODE_ACTION_NAMES:
		var action := chooser.find_child(action_name, true, false) as Button
		_check(action != null and action.is_visible_in_tree(), "Mode chooser must include its own %s button" % action_name)
	_check(_find_close_button(chooser) != null, "Mode chooser must include a CLOSE button")
	_check_visible_leaf_names(chooser, MODE_ACTION_NAMES + ["FlowTitle", "FlowDetail", _find_close_button(chooser).name if _find_close_button(chooser) != null else "Close"], "Mode chooser")
	_test_native_button_styles(hud)

	var host_choice := chooser.find_child("HostChoice", true, false) as Button
	if host_choice != null:
		host_choice.pressed.emit()
		await process_frame
		var host_menu := hud.find_child("HostMenu", true, false) as Control
		_check(host_menu != null and host_menu.visible, "HOST must open its redesigned host surface")
		if host_menu != null:
			_check(_visible_nodes_of_type(host_menu, "OptionButton").size() == 1, "Host must show exactly one map picker")
			_check(_visible_named_like(host_menu, "code").size() == 1, "Host must show exactly one room code")
			_check(_visible_nodes_of_type(host_menu, "LineEdit").is_empty(), "Host must not ask for an address or extra text")
			_check(_find_close_button(host_menu) != null, "Host must include a CLOSE button")

	hud.call("_show_lobby_page", "chooser")
	var join_choice := chooser.find_child("JoinChoice", true, false) as Button
	if join_choice != null:
		join_choice.pressed.emit()
		await process_frame
		var join_menu := hud.find_child("JoinMenu", true, false) as Control
		_check(join_menu != null and join_menu.visible, "JOIN must open its redesigned join surface")
		if join_menu != null:
			var code_inputs := _visible_nodes_of_type(join_menu, "LineEdit")
			_check(code_inputs.size() == 1, "Join must ask for exactly one code")
			if code_inputs.size() == 1:
				var code_input := code_inputs[0] as LineEdit
				_check("code" in (code_input.name + " " + code_input.placeholder_text).to_lower(), "Join input must ask for a room code, not a host address")
				var submitted_codes: Array[String] = []
				hud.join_requested.connect(func(code: String) -> void: submitted_codes.append(code))
				code_input.text = "C0A8-012A"
				code_input.text_submitted.emit(code_input.text)
				_check(submitted_codes == ["C0A8-012A"], "Pressing Enter in the room-code field must submit the join request")
			_check(_visible_nodes_of_type(join_menu, "OptionButton").is_empty(), "Join must not show map or other settings")
			_check(_find_close_button(join_menu) != null, "Join must include a CLOSE button")


func _test_native_button_styles(hud: Node) -> void:
	for button_name in MAIN_ACTION_NAMES + MODE_ACTION_NAMES + ["ShopButton", "CopyButton"]:
		var button := hud.find_child(button_name, true, false) as Button
		if button == null:
			continue
		var native_style := button.get_theme_stylebox("normal")
		_check(native_style is StyleBoxFlat, "%s must use a crisp native StyleBoxFlat" % button_name)
		_check(not native_style is StyleBoxTexture, "%s must not use generated lobby artwork" % button_name)
		_check(button.custom_minimum_size.y <= 72.0, "%s must stay compact" % button_name)


func _test_lobby_world_contracts() -> void:
	var game_source := FileAccess.get_file_as_string("res://scripts/game.gd")
	_check("var third_person_enabled := true" in game_source, "Lobby must start in third-person automatically")
	_check("Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)" in game_source, "Lobby must start with the mouse unlocked")

	var lobby_source := FileAccess.get_file_as_string("res://scripts/lobby_room.gd")
	var main_scene_source := FileAccess.get_file_as_string("res://scenes/main.tscn")
	var room_radius := _first_number(lobby_source, "const\\s+ROOM_RADIUS\\s*:=\\s*([0-9.]+)")
	var lobby_bound := _first_number(main_scene_source, "lobby_radius\\s*=\\s*([0-9.]+)")
	_check(room_radius >= 38.0, "Lobby room radius must grow substantially beyond the old 26-unit room")
	_check(lobby_bound >= room_radius - 1.0, "Lobby respawn boundary must grow with the larger room")

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


func _check_visible_leaf_names(scope: Node, allowed_names: Array, surface_name: String) -> void:
	var visible_leaves: Array[String] = []
	_collect_visible_leaf_names(scope, visible_leaves)
	for leaf_name in visible_leaves:
		_check(leaf_name in allowed_names, "%s must not show extra lobby UI (%s)" % [surface_name, leaf_name])


func _collect_visible_leaf_names(node: Node, output: Array[String]) -> void:
	for child in node.get_children():
		if child is Control and not (child as Control).is_visible_in_tree():
			continue
		if child is Button or child is Label or child is LineEdit or child is OptionButton or child is TextureRect or child is ProgressBar:
			output.append(child.name)
		_collect_visible_leaf_names(child, output)


func _visible_nodes_of_type(scope: Node, type_name: String) -> Array[Node]:
	var matches: Array[Node] = []
	_collect_visible_type(scope, type_name, matches)
	return matches


func _collect_visible_type(node: Node, type_name: String, output: Array[Node]) -> void:
	for child in node.get_children():
		if child is Control and not (child as Control).is_visible_in_tree():
			continue
		if child.is_class(type_name):
			output.append(child)
		_collect_visible_type(child, type_name, output)


func _visible_named_like(scope: Node, fragment: String) -> Array[Node]:
	var matches: Array[Node] = []
	_collect_visible_named_like(scope, fragment.to_lower(), matches)
	return matches


func _collect_visible_named_like(node: Node, fragment: String, output: Array[Node]) -> void:
	for child in node.get_children():
		if child is Control and not (child as Control).is_visible_in_tree():
			continue
		if fragment in str(child.name).to_lower():
			output.append(child)
		_collect_visible_named_like(child, fragment, output)


func _find_close_button(scope: Node) -> Button:
	for candidate in scope.find_children("*", "Button", true, false):
		var button := candidate as Button
		if "close" in button.name.to_lower() or button.text.strip_edges().to_lower() == "close":
			return button
	return null


func _first_number(source: String, pattern: String) -> float:
	var expression := RegEx.create_from_string(pattern)
	var result := expression.search(source)
	return result.get_string(1).to_float() if result != null else -1.0


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
