extends SceneTree

const HUD_SCENE := preload("res://scenes/hud.tscn")

const ABILITY_IDS := [
	"dash",
	"ricochet_shot",
	"quick_charge",
	"blink",
	"target_scanner",
	"overcharge",
	"gravity_pulse",
	"rail_shot",
	"bounce_mine",
	"phase_bubble",
	"adrenaline",
]

var failures: Array[String] = []


func _initialize() -> void:
	var hud := HUD_SCENE.instantiate()
	root.add_child(hud)
	await process_frame

	var play := hud.get_node_or_null("LobbyPanel/LobbyStack/PlayButton") as Button
	var chooser := hud.get_node_or_null("LobbyPanel/LobbyStack/ModeChooser") as Control
	var host_menu := hud.get_node_or_null("LobbyPanel/LobbyStack/HostMenu") as Control
	var join_menu := hud.get_node_or_null("LobbyPanel/LobbyStack/JoinMenu") as Control
	_check(play != null and play.visible, "Lobby must default to one prominent PLAY button")
	_check(chooser != null and not chooser.visible, "Mode chooser must be hidden until PLAY is clicked")
	_check(host_menu != null and not host_menu.visible, "Host controls must be hidden by default")
	_check(join_menu != null and not join_menu.visible, "Join controls must be hidden by default")
	if play != null:
		play.pressed.emit()
	_check(not play.visible and chooser.visible, "PLAY must replace itself with the three-mode chooser")
	hud.call("_show_lobby_page", "play")
	hud.call("open_play_menu")
	_check(chooser.visible and not play.visible, "Lobby play pad API must open the same chooser")

	var practice_count := [0]
	hud.practice_requested.connect(func() -> void: practice_count[0] += 1)
	var practice := hud.get_node_or_null("LobbyPanel/LobbyStack/ModeChooser/Choices/PracticeChoice") as Button
	if practice != null:
		practice.pressed.emit()
	_check(practice_count[0] == 1, "Practice must launch immediately from the chooser")

	play.pressed.emit()
	var host_choice := hud.get_node_or_null("LobbyPanel/LobbyStack/ModeChooser/Choices/HostChoice") as Button
	if host_choice != null:
		host_choice.pressed.emit()
	_check(host_menu.visible and not chooser.visible and not join_menu.visible, "Host must open only host controls")
	var join_choice := hud.get_node_or_null("LobbyPanel/LobbyStack/ModeChooser/Choices/JoinChoice") as Button
	hud.call("_show_lobby_page", "chooser")
	if join_choice != null:
		join_choice.pressed.emit()
	_check(join_menu.visible and not chooser.visible and not host_menu.visible, "Join must open only join controls")

	var ability := hud.get_node_or_null("AbilityHUD") as Control
	_check(ability != null, "HUD must include the circular AbilityHUD control")
	if ability != null:
		_check(ability.size.x == ability.size.y, "Ability control must use a square circular footprint")
		_check(ability.get_node_or_null("KeyBadge") != null, "Ability control must include an overlapping key badge")
		_check(ability.get_node_or_null("Icon") is TextureRect, "Ability control must render a vector icon")
		_check(ability.get_node_or_null("Cooldown") is Label, "Ability control must show cooldown seconds inside the circle")
		hud.call("set_lobby_mode", false)
		hud.call("set_ability_state", "dash", 5200, false, false)
		var icon := ability.get_node("Icon") as TextureRect
		var cooldown := ability.get_node("Cooldown") as Label
		_check(icon.texture != null, "Equipped ability must load its vector icon")
		_check(icon.modulate.a < 0.5 and cooldown.visible, "Cooldown must gray the icon and show an internal countdown")
		hud.call("set_ability_state", "dash", 0, false, false)
		_check(cooldown.visible and cooldown.text == "READY", "Ready state must replace the countdown with a clear READY label")

	for ability_id in ABILITY_IDS:
		_check(ResourceLoader.exists("res://assets/ui/abilities/%s.svg" % ability_id, "Texture2D"), "%s must have an original vector icon" % ability_id)

	var hud_source := FileAccess.get_file_as_string("res://scripts/hud.gd")
	for emoji in ["⚡", "↗", "✦", "✧", "◉", "✹", "◌", "━", "●", "◯", "♥", "🪙"]:
		_check(emoji not in hud_source, "HUD must use image assets instead of emoji glyphs (%s)" % emoji)
	var coin_source := FileAccess.get_file_as_string("res://scripts/ui/coin_icon.gd")
	_check("blob-coin.png" in coin_source, "Coin UI must use the supplied smiling blob-coin artwork")
	_check("draw_string" not in coin_source, "Coin UI must not fall back to the old letter-B mark")

	hud.queue_free()
	if failures.is_empty():
		print("HUD REDESIGN CONTRACT PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
