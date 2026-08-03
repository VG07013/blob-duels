extends SceneTree

const HUD_SCENE := preload("res://scenes/hud.tscn")
const PAUSE_SCENE := preload("res://scenes/ui/pause_menu.tscn")
const COIN_ICON_SCRIPT := preload("res://scripts/ui/coin_icon.gd")
const PROVIDED_COIN := preload("res://assets/ui/economy/blob-coin.png")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	await _test_pause_host_code()
	await _test_practice_clock_and_fling_meter()
	_test_authored_coin_asset()
	if failures.is_empty():
		print("BUG 012/013/018/022/024 UI CONTRACT PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _test_pause_host_code() -> void:
	var pause := PAUSE_SCENE.instantiate()
	pause.settings_path = "user://bug_ui_contract.cfg"
	root.add_child(pause)
	await process_frame
	var card := pause.find_child("HostCodeCard", true, false) as Control
	var value := pause.find_child("HostCodeValue", true, false) as Label
	_check(card != null and value != null, "Escape menu needs a dedicated host game-code card")
	pause.call("set_host_room_code", "ABCD-1234")
	_check(card != null and card.visible, "Host game-code card must appear for a non-empty code")
	_check(value != null and value.text == "ABCD-1234", "Escape menu must display the exact shareable game code")
	pause.call("set_host_room_code", "")
	_check(card != null and not card.visible, "Game-code card must stay hidden for guests and offline practice")
	pause.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://bug_ui_contract.cfg"))


func _test_practice_clock_and_fling_meter() -> void:
	var hud := HUD_SCENE.instantiate()
	root.add_child(hud)
	await process_frame
	hud.call("set_lobby_mode", false)
	hud.call("set_practice_mode", true)
	var timer := hud.find_child("TimerLabel", true, false) as Control
	var scoreboard := hud.find_child("Scoreboard", true, false) as Control
	_check(timer != null and not timer.visible, "Practice must suppress the timer even after entering gameplay HUD mode")
	_check(scoreboard != null and not scoreboard.visible, "Practice must suppress duel scoring chrome")
	hud.call("set_practice_mode", false)
	hud.call("set_duel_mode", true)
	_check(timer != null and timer.visible, "Leaving Practice must restore the duel timer")

	hud.call("set_fling_cooldown", 3.0, 3.0)
	var cooldown_panel := hud.find_child("FlingCooldownPanel", true, false) as Control
	var cooldown_bar := hud.find_child("FlingCooldownBar", true, false) as ProgressBar
	var cooldown_value := hud.find_child("FlingCooldownValue", true, false) as Label
	_check(cooldown_panel != null and cooldown_panel.visible, "Fling cooldown must have a visible dedicated HUD indicator")
	_check(cooldown_bar != null and is_equal_approx(cooldown_bar.value, 100.0), "Fling cooldown bar must start full")
	hud.call("set_fling_cooldown", 1.5, 3.0)
	_check(cooldown_bar != null and is_equal_approx(cooldown_bar.value, 50.0), "Fling cooldown bar must deplete with elapsed cooldown")
	_check(cooldown_value != null and "1.5" in cooldown_value.text, "Fling cooldown needs a readable time state")
	hud.call("set_fling_cooldown", 0.0, 3.0)
	_check(cooldown_panel != null and not cooldown_panel.visible, "Fling cooldown indicator must clear when fling is ready")
	hud.queue_free()
	await process_frame


func _test_authored_coin_asset() -> void:
	var icon := Control.new()
	icon.set_script(COIN_ICON_SCRIPT)
	root.add_child(icon)
	var source: Texture2D = icon.get("icon_texture") as Texture2D
	_check(source == PROVIDED_COIN, "Every economy mark must render the provided blob-coin.png asset")
	icon.queue_free()


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
