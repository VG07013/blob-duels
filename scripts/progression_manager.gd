extends Node

const COSMETIC_LIBRARY := preload("res://scripts/cosmetic_library.gd")

signal balance_changed(balance: int, delta: int)
signal reward_earned(breakdown: Array, total: int)
signal quest_completed(quest: Dictionary, reward: int)
signal quest_claimed(quest: Dictionary, reward: int)
signal inventory_changed

const SAVE_PATH := "user://blob_duels_progression.cfg"
const DAILY_REWARD := 75
const DAILY_SET_BONUS := 50
const BASE_MATCH_REWARD := 25
const ABILITY_CATALOG := [
	{"id": "dash", "name": "Dash", "rarity": "Basic", "price": 150, "tagline": "Turn momentum into distance", "description": "Burst 7m in your movement direction while keeping the duel fast and readable. 7 second cooldown.", "preview_mode": "ability_demo", "runtime_effect": "directional_dash"},
	{"id": "ricochet_shot", "name": "Ricochet Shot", "rarity": "Advanced", "price": 300, "tagline": "Make the walls your weapon", "description": "Charge your next shot for +10 damage and up to 3 bright, readable wall bounces.", "preview_mode": "ability_demo", "runtime_effect": "charged_ricochet"},
	{"id": "quick_charge", "name": "Quick Charge", "rarity": "Expert", "price": 500, "tagline": "Always first off the line", "description": "Passive: fling charge fills 20% faster without changing the maximum impact.", "preview_mode": "ability_demo", "runtime_effect": "charge_accelerator"},
	{"id": "blink", "name": "Blink", "rarity": "Expert", "price": 600, "tagline": "Skip the space between", "description": "Instantly teleport 5m while preserving all momentum. 18 second cooldown.", "preview_mode": "ability_demo", "runtime_effect": "momentum_blink"},
	{"id": "target_scanner", "name": "Target Scanner", "rarity": "Advanced", "price": 450, "tagline": "No rival stays hidden", "description": "Reveal enemies within 30m through walls for 5 seconds with a clear counterplay telegraph.", "preview_mode": "ability_demo", "runtime_effect": "radar_reveal"},
	{"id": "overcharge", "name": "Overcharge", "rarity": "Expert", "price": 600, "tagline": "Five seconds of pressure", "description": "Fire 30% faster for 5 seconds while damage stays unchanged and readable.", "preview_mode": "ability_demo", "runtime_effect": "fire_rate_overcharge"},
	{"id": "gravity_pulse", "name": "Gravity Pulse", "rarity": "Expert", "price": 650, "tagline": "Bend the incoming line", "description": "Curve enemy bullets away for 0.8 seconds within a visible 6m gravity field.", "preview_mode": "ability_demo", "runtime_effect": "projectile_deflection"},
	{"id": "rail_shot", "name": "Rail Shot", "rarity": "Expert", "price": 700, "tagline": "One line. One decision.", "description": "Charge for 1 second, then fire one near-instant precision shot for +15 damage.", "preview_mode": "ability_demo", "runtime_effect": "charged_rail"},
	{"id": "bounce_mine", "name": "Bounce Mine", "rarity": "Advanced", "price": 550, "tagline": "Reposition the whole fight", "description": "Deploy one bright bouncing mine that launches enemies without dealing damage.", "preview_mode": "ability_demo", "runtime_effect": "launch_mine"},
	{"id": "phase_bubble", "name": "Phase Bubble", "rarity": "Legendary", "price": 750, "tagline": "Let the bullets pass through", "description": "Enemy bullets pass through you for 4 seconds while your movement physics stay unchanged.", "preview_mode": "ability_demo", "runtime_effect": "projectile_phase"},
	{"id": "adrenaline", "name": "Adrenaline", "rarity": "Expert", "price": 650, "tagline": "Come alive under pressure", "description": "Passive: below 60% HP, gain 15% movement and fling charge speed.", "preview_mode": "ability_demo", "runtime_effect": "low_health_haste"},
]
const DAILY_POOL := [
	{"id": "play_matches", "title": "Play 3 Matches", "target": 3, "stat": "matches"},
	{"id": "eliminations", "title": "Get 5 Eliminations", "target": 5, "stat": "eliminations"},
	{"id": "bounce", "title": "Bounce 100 Times", "target": 100, "stat": "bounces"},
	{"id": "wins", "title": "Win 1 Match", "target": 1, "stat": "wins"},
	{"id": "damage", "title": "Deal 1,000 Damage", "target": 1000, "stat": "damage"},
]
const WEEKLY_POOL := [
	{"id": "weekly_matches", "title": "Play 20 Matches", "target": 20, "stat": "matches", "reward": 300},
	{"id": "weekly_eliminations", "title": "Get 100 Eliminations", "target": 100, "stat": "eliminations", "reward": 400},
	{"id": "weekly_bounce", "title": "Bounce 2,500 Times", "target": 2500, "stat": "bounces", "reward": 500},
	{"id": "weekly_wins", "title": "Win 10 Matches", "target": 10, "stat": "wins", "reward": 400},
	{"id": "weekly_damage", "title": "Deal 10,000 Damage", "target": 10000, "stat": "damage", "reward": 350},
]

var coins := 0
var owned: Dictionary = {}
var equipped: Dictionary = {}
var daily_quests: Array = []
var weekly_quests: Array = []
var _daily_key := ""
var _weekly_key := ""
var persistence_enabled := true


func _ready() -> void:
	_load()
	_ensure_starter_loadout()
	_refresh_quests_if_needed()


func get_balance() -> int:
	return coins


func get_items(category: String) -> Array:
	return (_catalog_for(category)).duplicate(true)


func is_owned(item_id: String) -> bool:
	return bool(owned.get(item_id, false))


func get_equipped(category: String) -> String:
	return str(equipped.get(category, ""))


func purchase(category: String, item_id: String) -> bool:
	var item := _find_item(category, item_id)
	if item.is_empty() or is_owned(item_id) or coins < int(item.get("price", 0)):
		return false
	coins -= int(item.get("price", 0))
	owned[item_id] = true
	equipped[category] = item_id
	_update_quests({"spent": int(item.get("price", 0))})
	_save()
	balance_changed.emit(coins, -int(item.get("price", 0)))
	inventory_changed.emit()
	return true


func equip(category: String, item_id: String) -> bool:
	if not is_owned(item_id) or _find_item(category, item_id).is_empty():
		return false
	equipped[category] = item_id
	_save()
	inventory_changed.emit()
	return true


func _ensure_starter_loadout() -> void:
	var starters := {"abilities": "dash", "skins": "classic_blue", "trails": "bubble", "kill_effects": "bubble_pop", "faces": "happy"}
	var changed := false
	for category in starters:
		var item_id := str(starters[category])
		if not bool(owned.get(item_id, false)):
			owned[item_id] = true
			changed = true
		var equipped_id := str(equipped.get(category, ""))
		if equipped_id.is_empty() or _find_item(category, equipped_id).is_empty():
			equipped[category] = item_id
			changed = true
	if changed:
		_save()


func record_stat(stat: String, amount := 1) -> void:
	if amount <= 0:
		return
	var rewards := _update_quests({stat: amount})
	var total := 0
	for reward in rewards:
		total += int((reward as Dictionary).get("amount", 0))
	if total > 0:
		coins += total
		_save()
		balance_changed.emit(coins, total)
		reward_earned.emit(rewards, total)


func claim_quest(group: String, quest_id: String) -> bool:
	var quests: Array = daily_quests if group == "daily" else weekly_quests
	for index in quests.size():
		var quest := quests[index] as Dictionary
		if str(quest.get("id", "")) != quest_id:
			continue
		if not bool(quest.get("completed", false)) or bool(quest.get("claimed", false)):
			return false
		quest["claimed"] = true
		quests[index] = quest
		var reward := int(quest.get("reward", 0))
		var bonus := _claim_daily_set_bonus_if_ready() if group == "daily" else 0
		coins += reward + bonus
		_save()
		balance_changed.emit(coins, reward + bonus)
		quest_claimed.emit(quest.duplicate(true), reward + bonus)
		return true
	return false


func award_match(stats: Dictionary) -> Dictionary:
	var breakdown: Array = [{"label": "Base Reward", "amount": BASE_MATCH_REWARD}]
	var placement := clampi(int(stats.get("placement", 2)), 1, 99)
	var placement_reward := 30 if placement == 1 else (20 if placement == 2 else (10 if placement == 3 else 0))
	if placement_reward > 0:
		breakdown.append({"label": "Placement Bonus", "amount": placement_reward})
	var eliminations := maxi(0, int(stats.get("eliminations", 0)))
	if eliminations > 0:
		breakdown.append({"label": "Eliminations", "amount": eliminations * 5})
	var tricks := mini(3, maxi(0, int(stats.get("trick_shots", 0))))
	if tricks > 0:
		breakdown.append({"label": "Trick Shots", "amount": tricks * 10})
	if bool(stats.get("survived", false)):
		breakdown.append({"label": "Survival Bonus", "amount": 15})
	if bool(stats.get("mvp", false)):
		breakdown.append({"label": "MVP Bonus", "amount": 20})
	var quest_rewards := _update_quests({
		"matches": 1,
		"wins": 1 if placement == 1 else 0,
		"eliminations": eliminations,
		"trick_shots": tricks,
		"damage": maxi(0, int(stats.get("damage", 0))),
	})
	for reward in quest_rewards:
		breakdown.append(reward)
	var total := 0
	for reward in breakdown:
		total += int((reward as Dictionary).get("amount", 0))
	coins += total
	_save()
	balance_changed.emit(coins, total)
	reward_earned.emit(breakdown, total)
	return {"breakdown": breakdown, "total": total, "balance": coins}


func _update_quests(stats: Dictionary) -> Array:
	_refresh_quests_if_needed()
	var rewarded: Array = []
	for quest_group in [daily_quests, weekly_quests]:
		for index in quest_group.size():
			var quest := quest_group[index] as Dictionary
			if bool(quest.get("claimed", false)) or bool(quest.get("completed", false)):
				continue
			var stat := str(quest.get("stat", ""))
			var amount := int(stats.get(stat, 0))
			if amount <= 0:
				continue
			quest["progress"] = mini(int(quest.get("target", 1)), int(quest.get("progress", 0)) + amount)
			if int(quest.get("progress", 0)) >= int(quest.get("target", 1)):
				quest["completed"] = true
				var reward := int(quest.get("reward", 0))
				quest_completed.emit(quest.duplicate(true), reward)
			quest_group[index] = quest
	_save()
	return rewarded


func _claim_daily_set_bonus_if_ready() -> int:
	var all_daily_done := not daily_quests.is_empty() and daily_quests.all(func(quest: Dictionary) -> bool: return bool(quest.get("claimed", false)))
	if not all_daily_done or bool(get_meta("daily_set_claimed", false)):
		return 0
	set_meta("daily_set_claimed", true)
	return DAILY_SET_BONUS


func _refresh_quests_if_needed() -> void:
	var now := Time.get_datetime_dict_from_system()
	var daily_key := "%04d-%02d-%02d" % [int(now.get("year", 1970)), int(now.get("month", 1)), int(now.get("day", 1))]
	var weekly_key := "week-%d" % int(floor(Time.get_unix_time_from_system() / 604800.0))
	if _daily_key != daily_key:
		_daily_key = daily_key
		daily_quests = _make_quests(DAILY_POOL, 3, DAILY_REWARD, daily_key)
		set_meta("daily_set_claimed", false)
	if _weekly_key != weekly_key:
		_weekly_key = weekly_key
		weekly_quests = _make_quests(WEEKLY_POOL, 5, -1, weekly_key)
	_save()


func _make_quests(pool: Array, count: int, default_reward: int, key: String) -> Array:
	var shuffled := pool.duplicate(true)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(key.hash())
	for index in range(shuffled.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var swap: Variant = shuffled[index]
		shuffled[index] = shuffled[swap_index]
		shuffled[swap_index] = swap
	var quests: Array = []
	for index in mini(count, shuffled.size()):
		var quest := shuffled[index] as Dictionary
		quest["progress"] = 0
		quest["completed"] = false
		quest["claimed"] = false
		quest["reward"] = default_reward if default_reward >= 0 else int(quest.get("reward", 300))
		quests.append(quest)
	return quests


func _find_item(category: String, item_id: String) -> Dictionary:
	for item_value in _catalog_for(category):
		var item := item_value as Dictionary
		if str(item.get("id", "")) == item_id:
			return item
	return {}


func _catalog_for(category: String) -> Array:
	if category == "abilities":
		return ABILITY_CATALOG
	return COSMETIC_LIBRARY.catalog().get(category, []) as Array


func _load() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	coins = maxi(0, int(config.get_value("progress", "coins", 0)))
	owned = config.get_value("progress", "owned", {}) as Dictionary
	equipped = config.get_value("progress", "equipped", {}) as Dictionary
	daily_quests = config.get_value("quests", "daily", []) as Array
	weekly_quests = config.get_value("quests", "weekly", []) as Array
	_daily_key = str(config.get_value("quests", "daily_key", ""))
	_weekly_key = str(config.get_value("quests", "weekly_key", ""))
	set_meta("daily_set_claimed", bool(config.get_value("quests", "daily_set_claimed", false)))
	_migrate_launch_cosmetics()


func _migrate_launch_cosmetics() -> void:
	var cosmetic_renames := {
		"bubblegum": "classic_blue", "ocean": "water", "nebula": "galaxy", "solar": "gold",
		"bubbles": "bubble", "electric": "lightning", "stardust": "stars", "rainbow_rush": "aurora_trail",
		"pop": "bubble_pop", "void": "portal_collapse", "mischief": "evil", "royal": "divine",
	}
	for legacy_id in cosmetic_renames:
		var launch_id := str(cosmetic_renames[legacy_id])
		if bool(owned.get(legacy_id, false)):
			owned[launch_id] = true
			owned.erase(legacy_id)
	for category in equipped:
		var item_id := str(equipped[category])
		if cosmetic_renames.has(item_id):
			equipped[category] = str(cosmetic_renames[item_id])
	var equipped_ability := str(equipped.get("abilities", ""))
	if equipped_ability == "shield_pop" or equipped_ability == "comet":
		equipped.erase("abilities")


func _save() -> void:
	if not persistence_enabled:
		return
	var config := ConfigFile.new()
	config.set_value("progress", "coins", coins)
	config.set_value("progress", "owned", owned)
	config.set_value("progress", "equipped", equipped)
	config.set_value("quests", "daily", daily_quests)
	config.set_value("quests", "weekly", weekly_quests)
	config.set_value("quests", "daily_key", _daily_key)
	config.set_value("quests", "weekly_key", _weekly_key)
	config.set_value("quests", "daily_set_claimed", bool(get_meta("daily_set_claimed", false)))
	config.save(SAVE_PATH)
