extends SceneTree

## Skill-shaped quests: every pool quest must point at a stat the game really
## records, ability-gated quests must stay out of the rotation until the
## ability is owned, per-map wins and the new round stats must advance quests,
## and none of it may pay out before a claim.

const PROGRESSION_SCRIPT := preload("res://scripts/progression_manager.gd")

var failures: Array[String] = []


func _initialize() -> void:
	_test_every_pool_stat_is_recorded()
	_test_ability_gated_rotation()
	_test_new_stats_advance_quests()
	_test_per_map_wins_and_ticks()
	_test_archived_map_quests_retarget()
	_test_next_unlock()
	_test_shop_is_stocked()
	if failures.is_empty():
		print("PROGRESSION QUESTS CONTRACT PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _test_every_pool_stat_is_recorded() -> void:
	var sources := _script_sources("res://scripts")
	var progression_source := FileAccess.get_file_as_string("res://scripts/progression_manager.gd")
	var award_block := progression_source.substr(progression_source.find("func award_match"))
	award_block = award_block.substr(0, award_block.find("func _mark_quest_progress"))
	var pools: Array = PROGRESSION_SCRIPT.DAILY_POOL + PROGRESSION_SCRIPT.WEEKLY_POOL
	_check(pools.size() >= 20, "Quest pools must offer enough variety that a rotation never repeats the same handful")
	var seen_ids: Dictionary = {}
	for quest_value in pools:
		var quest := quest_value as Dictionary
		var quest_id := str(quest.get("id", ""))
		_check(not seen_ids.has(quest_id), "Quest ids must be unique across both pools (%s)" % quest_id)
		seen_ids[quest_id] = true
		var stat := str(quest.get("stat", ""))
		_check(not stat.is_empty() and int(quest.get("target", 0)) > 0, "Every quest must name a stat and a positive target (%s)" % quest_id)
		var recorded := 'record_stat", "%s"' % stat in sources or 'record_stat("%s"' % stat in sources
		recorded = recorded or ('"%s":' % stat) in award_block
		recorded = recorded or (stat.begins_with("wins_") and '"wins_%s"' in award_block)
		_check(recorded, "Quest '%s' references stat '%s' that nothing in scripts/ records" % [str(quest.get("title", quest_id)), stat])
		var required := str(quest.get("requires", ""))
		if not required.is_empty():
			var known := false
			for ability_value in PROGRESSION_SCRIPT.ABILITY_CATALOG:
				if str((ability_value as Dictionary).get("id", "")) == required:
					known = true
			_check(known, "Quest '%s' requires an ability that is not in the catalog" % quest_id)
	var titles := pools.map(func(quest: Dictionary) -> String: return str(quest.get("title", "")))
	for expected in ["Win a Round Without Taking Damage", "Land 3 Ricochet Hits", "Eliminate With a Rail Shot", "Score Using a Map Interactable", "Win a Match on Bounceground", "Bounce 10 Times in One Round"]:
		_check(expected in titles, "Quest pools must teach the game with '%s'" % expected)


func _test_ability_gated_rotation() -> void:
	var economy := PROGRESSION_SCRIPT.new()
	economy.set("persistence_enabled", false)
	economy.call("_ensure_starter_loadout")
	var eligible := economy.call("_eligible_pool", PROGRESSION_SCRIPT.DAILY_POOL) as Array
	var eligible_ids := eligible.map(func(quest: Dictionary) -> String: return str(quest.get("id", "")))
	_check("rail_elimination" not in eligible_ids, "A rail-shot quest must not rotate in while Rail Shot is unowned")
	_check("ricochet_hits" not in eligible_ids, "A ricochet quest must not rotate in while Ricochet Shot is unowned")
	_check("flawless_round" in eligible_ids and "bounce_round" in eligible_ids, "Quests with no ability requirement must always be eligible")
	economy.owned["rail_shot"] = true
	eligible = economy.call("_eligible_pool", PROGRESSION_SCRIPT.DAILY_POOL) as Array
	eligible_ids = eligible.map(func(quest: Dictionary) -> String: return str(quest.get("id", "")))
	_check("rail_elimination" in eligible_ids, "Owning Rail Shot must make its quest eligible")
	var gated_pool := [
		{"id": "a", "title": "A", "target": 1, "stat": "matches"},
		{"id": "b", "title": "B", "target": 1, "stat": "rail_eliminations", "requires": "phase_bubble"},
	]
	var quests := economy.call("_make_quests", gated_pool, 3, 75, "2026-09-21") as Array
	_check(quests.size() == 1 and str((quests[0] as Dictionary).get("id", "")) == "a", "Rotation must draw only from eligible quests")
	var repeat := economy.call("_make_quests", gated_pool, 3, 75, "2026-09-21") as Array
	_check(quests == repeat, "Gating must keep the rotation deterministic for the day")
	economy.free()


func _test_new_stats_advance_quests() -> void:
	var economy := PROGRESSION_SCRIPT.new()
	economy.set("persistence_enabled", false)
	economy.coins = 0
	economy.call("_refresh_quests_if_needed")
	economy.daily_quests = [
		{"id": "flawless", "title": "Flawless", "target": 1, "progress": 0, "reward": 75, "stat": "flawless_rounds", "completed": false, "claimed": false},
		{"id": "ricochet", "title": "Ricochet", "target": 3, "progress": 0, "reward": 75, "stat": "ricochet_hits", "completed": false, "claimed": false},
		{"id": "rail", "title": "Rail", "target": 1, "progress": 0, "reward": 75, "stat": "rail_eliminations", "completed": false, "claimed": false},
	]
	economy.weekly_quests = [
		{"id": "interact", "title": "Interact", "target": 3, "progress": 0, "reward": 300, "stat": "interactable_eliminations", "completed": false, "claimed": false},
		{"id": "bounce_rounds", "title": "Bounce rounds", "target": 5, "progress": 0, "reward": 300, "stat": "bounce_rounds", "completed": false, "claimed": false},
	]
	economy.call("record_stat", "flawless_rounds", 1)
	economy.call("record_stat", "ricochet_hits", 2)
	economy.call("record_stat", "rail_eliminations", 1)
	economy.call("record_stat", "interactable_eliminations", 1)
	economy.call("record_stat", "bounce_rounds", 1)
	_check(bool((economy.daily_quests[0] as Dictionary).get("completed", false)), "A flawless round must complete the flawless-round quest")
	_check(int((economy.daily_quests[1] as Dictionary).get("progress", 0)) == 2, "Ricochet hits must advance the ricochet quest by the amount recorded")
	_check(bool((economy.daily_quests[2] as Dictionary).get("completed", false)), "A rail elimination must complete the rail quest")
	_check(int((economy.weekly_quests[0] as Dictionary).get("progress", 0)) == 1, "Interactable scores must advance the weekly interactable quest")
	_check(int((economy.weekly_quests[1] as Dictionary).get("progress", 0)) == 1, "A ten-bounce round must advance the bounce-round quest")
	_check(int(economy.call("get_balance")) == 0, "Skill quests must not pay out until claimed")
	_check(int(economy.call("get_session_total", "ricochet_hits")) == 2, "Session totals must accumulate recorded stats")
	_check(int(economy.call("get_session_total", "never_recorded")) == 0, "Unknown stats must report a zero session total")
	_check(int(PROGRESSION_SCRIPT.BOUNCE_ROUND_TARGET) == 10, "A bounce round is ten bounces in a single round")
	economy.free()


func _test_per_map_wins_and_ticks() -> void:
	var economy := PROGRESSION_SCRIPT.new()
	economy.set("persistence_enabled", false)
	economy.coins = 0
	economy.call("_refresh_quests_if_needed")
	economy.daily_quests = [
		{"id": "bounceground", "title": "Bounceground", "target": 1, "progress": 0, "reward": 75, "stat": "wins_bounceground", "completed": false, "claimed": false},
		{"id": "other_map", "title": "Other Map", "target": 3, "progress": 0, "reward": 75, "stat": "wins_other_map", "completed": false, "claimed": false},
	]
	economy.weekly_quests = []
	economy.call("_mark_quest_progress")
	economy.call("award_match", {"placement": 2, "map_id": "bounceground"})
	_check(int((economy.daily_quests[0] as Dictionary).get("progress", 0)) == 0, "Losing on a map must not count as a win on that map")
	var win := economy.call("award_match", {"placement": 1, "map_id": "bounceground"}) as Dictionary
	_check(bool((economy.daily_quests[0] as Dictionary).get("completed", false)), "Winning on Bounceground must complete the Bounceground quest")
	_check(int((economy.daily_quests[1] as Dictionary).get("progress", 0)) == 0, "A win on one map must not advance another map's quest")
	var ticks := win.get("quest_ticks", []) as Array
	_check(ticks.size() == 1 and str((ticks[0] as Dictionary).get("id", "")) == "bounceground", "Match rewards must list only the quests that advanced during that match")
	var idle := economy.call("award_match", {"placement": 2, "map_id": "bounceground"}) as Dictionary
	_check((idle.get("quest_ticks", []) as Array).is_empty(), "A match that advances nothing must report no quest ticks")
	economy.free()


func _test_archived_map_quests_retarget() -> void:
	var economy := PROGRESSION_SCRIPT.new()
	economy.set("persistence_enabled", false)
	economy.daily_quests = [
		{"id": "aether_win", "title": "Win a Match on Aether Citadel", "target": 1, "progress": 0, "reward": 75, "stat": "wins_sky_temple", "completed": false, "claimed": false},
	]
	economy.weekly_quests = [
		{"id": "weekly_neon_wins", "title": "Win 3 Matches on Neon Arcade", "target": 3, "progress": 1, "reward": 350, "stat": "wins_neon_arcade", "completed": false, "claimed": false},
		{"id": "weekly_wins", "title": "Win 10 Matches", "target": 10, "progress": 0, "reward": 400, "stat": "wins", "completed": false, "claimed": false},
	]
	economy.call("_retarget_archived_map_quests")
	var daily := economy.daily_quests[0] as Dictionary
	var weekly := economy.weekly_quests[0] as Dictionary
	_check(str(daily.get("stat", "")) == "wins_bounceground" and str(daily.get("title", "")) == "Win a Match on Bounceground", "A saved quest for an archived map must retarget to Bounceground so it can still be completed")
	_check(str(weekly.get("stat", "")) == "wins_bounceground" and int(weekly.get("progress", 0)) == 1, "Retargeting an archived-map quest must keep the progress already earned")
	_check(str((economy.weekly_quests[1] as Dictionary).get("stat", "")) == "wins", "Quests that are not about a specific map must be left alone")
	economy.free()


func _test_shop_is_stocked() -> void:
	var economy := PROGRESSION_SCRIPT.new()
	economy.set("persistence_enabled", false)
	economy.call("_ensure_starter_loadout")
	var starters := PROGRESSION_SCRIPT.STARTER_LOADOUT as Dictionary
	for category in starters:
		var items := economy.call("get_items", category) as Array
		_check(items.size() > 1, "The shop must stock more than the default %s, or coins have nothing to buy" % category)
		var has_starter := false
		for item_value in items:
			has_starter = has_starter or str((item_value as Dictionary).get("id", "")) == str(starters[category])
		_check(has_starter, "The default %s must stay in the shop as the owned baseline" % category)
		_check(bool(economy.owned.get(str(starters[category]), false)), "A fresh account must own the default %s" % category)
		_check(str(economy.call("get_equipped", category)) == str(starters[category]), "A fresh account must wear the default %s" % category)
	_check(not (economy.call("get_next_unlock") as Dictionary).is_empty(), "A fresh account must have a next unlock to work toward")
	economy.coins = 100000
	_check(bool(economy.call("purchase", "skins", "gold")) and bool(economy.call("equip", "skins", "gold")), "A stocked legendary skin must be purchasable and equippable")
	economy.set("stock_full_catalog", false)
	_check((economy.call("get_items", "skins") as Array).size() == 1, "Clearing stock_full_catalog must cut the shop back to the starter loadout")
	economy.free()


func _test_next_unlock() -> void:
	var economy := PROGRESSION_SCRIPT.new()
	economy.set("persistence_enabled", false)
	economy.set("stock_full_catalog", true)
	economy.call("_ensure_starter_loadout")
	economy.coins = 340
	var next := economy.call("get_next_unlock") as Dictionary
	_check(int(next.get("price", 0)) == 50 and str(next.get("category", "")) == "faces", "Next unlock must be the cheapest unowned cosmetic (a 50 Coin face on a fresh account)")
	_check(int(next.get("balance", -1)) == 340, "Next unlock must report the current balance for its progress bar")
	for category in ["skins", "trails", "kill_effects", "faces"]:
		for item_value in economy.call("get_items", category) as Array:
			economy.owned[str((item_value as Dictionary).get("id", ""))] = true
	next = economy.call("get_next_unlock") as Dictionary
	_check(str(next.get("category", "")) == "abilities", "Once every cosmetic is owned the next unlock must fall back to abilities")
	for item_value in economy.call("get_items", "abilities") as Array:
		economy.owned[str((item_value as Dictionary).get("id", ""))] = true
	_check((economy.call("get_next_unlock") as Dictionary).is_empty(), "A fully unlocked account must report no next unlock")
	economy.free()


func _script_sources(directory: String) -> String:
	var combined := ""
	var dir := DirAccess.open(directory)
	if dir == null:
		return combined
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		var path := directory.path_join(entry)
		if dir.current_is_dir():
			if not entry.begins_with("."):
				combined += _script_sources(path)
		elif entry.ends_with(".gd"):
			combined += FileAccess.get_file_as_string(path)
		entry = dir.get_next()
	dir.list_dir_end()
	return combined


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
