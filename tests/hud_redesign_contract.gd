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
	hud.call("set_lobby_mode", true)

	var menu := hud.get_node_or_null("MainMenu") as Control
	_check(menu != null and menu.visible, "The pre-game HUD must be the one-page main menu")
	for control_name in ["PracticeChoice", "BotChoice", "StartHost", "StartJoin", "CodeInput"]:
		var control := hud.find_child(control_name, true, false) as Control
		_check(control != null and control.is_visible_in_tree(), "%s must be reachable without any page navigation" % control_name)

	var practice_count := [0]
	hud.practice_requested.connect(func() -> void: practice_count[0] += 1)
	var practice := hud.find_child("PracticeChoice", true, false) as Button
	if practice != null:
		practice.pressed.emit()
	_check(practice_count[0] == 1, "Practice must launch with one click from the menu")

	var ability := hud.find_child("AbilityHUD", true, false) as Control
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
		_check(not cooldown.visible or cooldown.text.is_empty(), "A ready ability shows only its bright icon and full ring - no READY caption")

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
