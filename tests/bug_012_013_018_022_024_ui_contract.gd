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

	# The fling meter (one rail above the health pill) carries the cooldown.
	var meter := hud.call("get_fling_meter") as Control
	hud.call("set_fling_cooldown", 3.0, 3.0)
	_check(meter != null and meter.is_visible_in_tree(), "Fling cooldown must show on the fling meter")
	_check(meter != null and bool(meter.call("is_on_cooldown")) and is_zero_approx(float(meter.call("get_fill_ratio"))), "A fresh fling cooldown must start the meter empty")
	hud.call("set_fling_cooldown", 1.5, 3.0)
	_check(meter != null and is_equal_approx(float(meter.call("get_fill_ratio")), 0.5), "The fling meter must refill as the cooldown runs down")
	_check(meter != null and "1.5" in str(meter.call("get_state_text")), "Fling cooldown needs a readable time state")
	hud.call("set_fling_cooldown", 0.0, 3.0)
	_check(meter != null and not bool(meter.call("is_on_cooldown")) and str(meter.call("get_state_text")) == "FLING READY", "The fling meter must read ready once the cooldown ends")
	var cooldown_panel := hud.find_child("FlingCooldownPanel", true, false) as Control
	_check(cooldown_panel == null or not cooldown_panel.visible, "The old separate cooldown bar must stay hidden")
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
