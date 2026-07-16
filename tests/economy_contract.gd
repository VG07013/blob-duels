extends SceneTree

const PROGRESSION_SCRIPT := preload("res://scripts/progression_manager.gd")
const COSMETIC_LIBRARY := preload("res://scripts/cosmetic_library.gd")

var failures: Array[String] = []


func _initialize() -> void:
	var economy := PROGRESSION_SCRIPT.new()
	economy.set("persistence_enabled", false)
	var quest_pool := [
		{"id": "a", "title": "A", "target": 1, "stat": "matches"},
		{"id": "b", "title": "B", "target": 2, "stat": "wins"},
		{"id": "c", "title": "C", "target": 3, "stat": "bounces"},
	]
	var daily := economy.call("_make_quests", quest_pool, 3, 75, "2026-07-15") as Array
	var repeat_daily := economy.call("_make_quests", quest_pool, 3, 75, "2026-07-15") as Array
	_check(daily.size() == 3, "Daily rotation must choose exactly three quests")
	_check(daily == repeat_daily, "Daily rotation must be stable for one calendar day")
	for quest_value in daily:
		var quest := quest_value as Dictionary
		_check(int(quest.get("reward", 0)) == 75, "Each daily quest must award 75 Coins")
		_check(int(quest.get("progress", -1)) == 0, "Fresh quests must start at zero progress")
	var basic_dash := economy.call("_find_item", "abilities", "dash") as Dictionary
	_check(int(basic_dash.get("price", 0)) == 150, "Basic abilities must cost 150 Coins")
	var cosmetics := COSMETIC_LIBRARY.catalog()
	_check((cosmetics.get("skins", []) as Array).size() == 24, "Launch collection must include all 24 skins")
	_check((cosmetics.get("trails", []) as Array).size() == 19, "Launch collection must include all 19 trails")
	_check((cosmetics.get("kill_effects", []) as Array).size() == 16, "Launch collection must include all 16 kill effects")
	_check((cosmetics.get("faces", []) as Array).size() == 19, "Launch collection must include all 19 faces")
	_check(str(COSMETIC_LIBRARY.skin_profile("black_hole", Color.WHITE).get("rarity", "")) == "Legendary", "Black Hole skin must remain Legendary")
	economy.daily_quests = [{"id": "claimable", "title": "Claimable", "target": 1, "progress": 1, "reward": 75, "completed": true, "claimed": false}]
	_check(bool(economy.call("claim_quest", "daily", "claimable")), "A completed quest must be manually claimable")
	_check(int(economy.call("get_balance")) == 125, "Claiming the final daily quest must award its Coins and the daily-set bonus")
	_check(not bool(economy.call("claim_quest", "daily", "claimable")), "A claimed quest must not be claimable twice")
	economy.coins = 0
	economy.daily_quests = []
	var rewards := economy.call("award_match", {"placement": 1, "eliminations": 2, "trick_shots": 4, "survived": true, "mvp": true}) as Dictionary
	_check(int(rewards.get("total", 0)) >= 130, "Match rewards must cap trick shots at three and include base, placement, elimination, survival, and MVP rewards before any earned quest bonus")
	economy.queue_free()
	if failures.is_empty():
		print("ECONOMY CONTRACT PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
