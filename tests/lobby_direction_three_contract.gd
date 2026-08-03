extends SceneTree

const HUD_SCENE := preload("res://scenes/hud.tscn")
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

	var coin_chip := hud.find_child("CoinBalance", true, false) as PanelContainer
	var quest_panel := hud.find_child("QuestPanel", true, false) as PanelContainer
	var coin_value := hud.find_child("CoinValue", true, false) as Label
	_check(coin_chip != null, "Direction 3 needs a compact coin balance")
	_check(coin_value != null and coin_value.get_theme_font_size("font_size") >= 22, "Coin value needs stronger metric typography")
	_check(not _visible_text(hud).contains("BLOB COINS"), "The lobby balance must show only the icon and number")
	_check(hud.find_child("DockShopButton", true, false) == null, "The main lobby rail must not duplicate the shop entry")
	_check(quest_panel != null, "Direction 3 needs the tracked quest card")
	if quest_panel != null:
		var style := quest_panel.get_theme_stylebox("panel") as StyleBoxFlat
		_check(style != null and style.bg_color.a >= 0.25 and style.bg_color.a <= 0.62, "Quest glass must be visibly semi-transparent")
	var coin_source := FileAccess.get_file_as_string("res://scripts/ui/coin_icon.gd")
	_check("res://assets/ui/economy/blob-coin.png" in coin_source, "Every coin renderer must use the supplied little-blob artwork")

	for page in ["chooser", "host", "join"]:
		hud.call("_show_lobby_page", page)
		await create_timer(0.22).timeout
		var panel := hud.find_child("LobbyPanel", true, false) as PanelContainer
		_check(panel.size.x <= 460.0 and panel.size.y <= 320.0, "%s must stay inside the compact lobby shell" % page.capitalize())

	hud.queue_free()
	if failures.is_empty():
		print("LOBBY DIRECTION THREE CONTRACT PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _visible_text(root_node: Node) -> String:
	var result := ""
	for child in root_node.find_children("*", "Label", true, false):
		var label := child as Label
		if label.is_visible_in_tree():
			result += label.text.to_upper() + " "
	return result


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
