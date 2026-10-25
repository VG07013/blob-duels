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

	# Stat recording runs on gameplay hot paths, so it must never write to disk
	# per event and must never move the balance - quest coins are paid on claim.
	economy.coins = 0
	# Settle the daily/weekly rotation keys first, otherwise the next stat
	# recording rotates the fixture quest away before it can be advanced.
	economy.call("_refresh_quests_if_needed")
	economy.daily_quests = [{"id": "hot", "title": "Hot", "target": 2, "progress": 0, "reward": 75, "stat": "bounces", "completed": false, "claimed": false}]
	economy.weekly_quests = []
	economy.call("save_now")
	economy.call("record_stat", "bounces", 1)
	_check(int(economy.call("get_balance")) == 0, "Recording a stat must not pay out coins directly")
	_check(bool(economy.call("has_unsaved_progress")), "Recording a stat must queue a save rather than writing immediately")
	economy.call("record_stat", "bounces", 1)
	var hot_quest := (economy.daily_quests[0] as Dictionary)
	_check(bool(hot_quest.get("completed", false)), "Reaching a quest target must mark it completed")
	_check(int(economy.call("get_balance")) == 0, "Completing a quest must not pay out until it is claimed")
	economy.call("save_now")
	_check(not bool(economy.call("has_unsaved_progress")), "save_now must flush the queued write")
	economy.call("record_stat", "bounces", 0)
	_check(not bool(economy.call("has_unsaved_progress")), "A no-op stat must not queue a write")

	# A corrupt or hand-edited save must cost progress, not the ability to launch.
	_check((economy.call("_dictionary_or_empty", "not-a-dictionary") as Dictionary).is_empty(), "A non-Dictionary save field must fall back to an empty Dictionary")
	_check((economy.call("_quest_array_or_empty", 7) as Array).is_empty(), "A non-Array quest field must fall back to an empty Array")
	_check((economy.call("_quest_array_or_empty", ["junk", {"id": "ok"}]) as Array).size() == 1, "Non-Dictionary quest entries must be dropped on load")

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
