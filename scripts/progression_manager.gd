extends Node

const COSMETIC_LIBRARY := preload("res://scripts/cosmetic_library.gd")

signal balance_changed(balance: int, delta: int)
signal reward_earned(breakdown: Array, total: int)
signal quest_completed(quest: Dictionary, reward: int)
signal quest_claimed(quest: Dictionary, reward: int)
signal inventory_changed

const SAVE_PATH := "user://blob_duels_progression.cfg"
# Stat recording runs on gameplay hot paths (every bounce, every damage tick),
# so those writes are coalesced instead of hitting the disk per event.
# Deliberate player actions - purchases, equips, quest claims - still save
# immediately via save_now().
const SAVE_DEBOUNCE_SECONDS := 2.0
const DAILY_REWARD := 75
const DAILY_SET_BONUS := 50
const BASE_MATCH_REWARD := 25
const ELIMINATION_REWARD := 5
const TRICK_SHOT_REWARD := 10
# Damage pays 1 Coin per DAMAGE_PER_COIN dealt, capped so a long stalemate
# never out-earns a decisive win.
const DAMAGE_PER_COIN := 40
const DAMAGE_REWARD_CAP := 25
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
	{"id": "shockwave", "name": "Shockwave", "rarity": "Advanced", "price": 400, "tagline": "Break the corner trap", "description": "Throw every nearby blob away from you and hop clear. 7m radius, 14 second cooldown.", "preview_mode": "ability_demo", "runtime_effect": "radial_shove"},
	{"id": "adrenaline", "name": "Adrenaline", "rarity": "Expert", "price": 650, "tagline": "Come alive under pressure", "description": "Passive: below 60% HP, gain 15% movement and fling charge speed.", "preview_mode": "ability_demo", "runtime_effect": "low_health_haste"},
]
# Quest pools mix volume quests (play, bounce, deal damage) with skill-shaped
# quests that teach a specific mechanic. A skill quest that needs an ability
# declares it under "requires" and is left out of the rotation until the
# player owns that ability, so a fresh account never draws a dead objective.
#
# Skill stats and where game.gd records them:
#   flawless_rounds           - won a round without taking damage
#   ricochet_hits             - ricochet-shot hits landed (round-result delta)
#   rail_eliminations         - round won by a rail-shot knockout
#   interactable_eliminations - round won right after using a map interactable
#   bounce_rounds             - rounds with at least BOUNCE_ROUND_TARGET bounces
#   wins_<map_id>             - match wins per arena (award_match)
const BOUNCE_ROUND_TARGET := 10
const DAILY_POOL := [
	{"id": "play_matches", "title": "Play 3 Matches", "target": 3, "stat": "matches"},
	{"id": "eliminations", "title": "Get 5 Eliminations", "target": 5, "stat": "eliminations"},
	{"id": "bounce", "title": "Bounce 100 Times", "target": 100, "stat": "bounces"},
	{"id": "wins", "title": "Win 1 Match", "target": 1, "stat": "wins"},
	{"id": "damage", "title": "Deal 1,000 Damage", "target": 1000, "stat": "damage"},
	{"id": "flawless_round", "title": "Win a Round Without Taking Damage", "target": 1, "stat": "flawless_rounds"},
	{"id": "ricochet_hits", "title": "Land 3 Ricochet Hits", "target": 3, "stat": "ricochet_hits", "requires": "ricochet_shot"},
	{"id": "rail_elimination", "title": "Eliminate With a Rail Shot", "target": 1, "stat": "rail_eliminations", "requires": "rail_shot"},
	{"id": "interactable_score", "title": "Score Using a Map Interactable", "target": 1, "stat": "interactable_eliminations"},
	{"id": "bounce_round", "title": "Bounce 10 Times in One Round", "target": 1, "stat": "bounce_rounds"},
	{"id": "bounceground_win", "title": "Win a Match on Bounceground", "target": 1, "stat": "wins_bounceground"},
]
const WEEKLY_POOL := [
	{"id": "weekly_matches", "title": "Play 20 Matches", "target": 20, "stat": "matches", "reward": 300},
	{"id": "weekly_eliminations", "title": "Get 100 Eliminations", "target": 100, "stat": "eliminations", "reward": 400},
	{"id": "weekly_bounce", "title": "Bounce 2,500 Times", "target": 2500, "stat": "bounces", "reward": 500},
	{"id": "weekly_wins", "title": "Win 10 Matches", "target": 10, "stat": "wins", "reward": 400},
	{"id": "weekly_damage", "title": "Deal 10,000 Damage", "target": 10000, "stat": "damage", "reward": 350},
	{"id": "weekly_flawless", "title": "Win 5 Rounds Without Taking Damage", "target": 5, "stat": "flawless_rounds", "reward": 400},
	{"id": "weekly_ricochet", "title": "Land 25 Ricochet Hits", "target": 25, "stat": "ricochet_hits", "reward": 350, "requires": "ricochet_shot"},
	{"id": "weekly_rail", "title": "Get 5 Rail Shot Eliminations", "target": 5, "stat": "rail_eliminations", "reward": 400, "requires": "rail_shot"},
	{"id": "weekly_interactable", "title": "Score 3 Times Using Map Interactables", "target": 3, "stat": "interactable_eliminations", "reward": 350},
	{"id": "weekly_bounce_rounds", "title": "Bounce 10 Times in a Round, 5 Times", "target": 5, "stat": "bounce_rounds", "reward": 300},
	{"id": "weekly_bounceground_wins", "title": "Win 3 Matches on Bounceground", "target": 3, "stat": "wins_bounceground", "reward": 350},
]
## Maps moved to archive/maps/ can no longer be won on. A saved quest that
## still asks for one is retargeted at the live map instead of sitting stuck
## until the quest set rolls over.
const ARCHIVED_MAP_NAMES := {
	"neon_arcade": "Neon Arcade",
	"backyard": "Backyard",
	"arena": "Arena",
	"sky_temple": "Aether Citadel",
	"toybox": "Toybox",
}
const LIVE_MAP_ID := "bounceground"
const LIVE_MAP_NAME := "Bounceground"
const COSMETIC_CATEGORIES := ["skins", "trails", "kill_effects", "faces"]
# Every account starts owning and wearing this loadout, so the shop always has
# something equipped to compare against. Clearing `stock_full_catalog` cuts the
# shop down to just these items (the alpha ran that way for a while).
const STARTER_LOADOUT := {"abilities": "dash", "skins": "classic_blue", "trails": "bubble", "kill_effects": "bubble_pop", "faces": "happy"}

var coins := 0
var owned: Dictionary = {}
var equipped: Dictionary = {}
var daily_quests: Array = []
var weekly_quests: Array = []
var _daily_key := ""
var _weekly_key := ""
var persistence_enabled := true
var stock_full_catalog := true

var _dirty := false
var _dirty_seconds := 0.0
# Running totals for the current process, keyed by stat. Never persisted:
# they exist so gameplay code can measure a window ("bounces this round")
# without owning its own counters.
var _session_totals: Dictionary = {}
# Quest progress at the last match award, keyed "group/id". The rewards card
# diffs against this to list the objectives that moved during the match.
var _quest_progress_marks: Dictionary = {}


func _ready() -> void:
	_load()
	_ensure_starter_loadout()
	_refresh_quests_if_needed()
	_mark_quest_progress()


func _process(delta: float) -> void:
	if not _dirty:
		return
	_dirty_seconds += delta
	if _dirty_seconds >= SAVE_DEBOUNCE_SECONDS:
		save_now()


func _notification(what: int) -> void:
	# Never let a debounced write outlive the process.
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		save_now()


func _exit_tree() -> void:
	save_now()


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
	_queue_save()
	save_now()
	balance_changed.emit(coins, -int(item.get("price", 0)))
	inventory_changed.emit()
	return true


func equip(category: String, item_id: String) -> bool:
	if not is_owned(item_id) or _find_item(category, item_id).is_empty():
		return false
	equipped[category] = item_id
	_queue_save()
	save_now()
	inventory_changed.emit()
	return true


func _ensure_starter_loadout() -> void:
	var changed := false
	for category in STARTER_LOADOUT:
		var item_id := str(STARTER_LOADOUT[category])
		if not bool(owned.get(item_id, false)):
			owned[item_id] = true
			changed = true
		var equipped_id := str(equipped.get(category, ""))
		if equipped_id.is_empty() or _find_item(category, equipped_id).is_empty():
			equipped[category] = item_id
			changed = true
	if changed:
		_queue_save()


## Advances quest progress. Completing a quest does not pay out on its own -
## the player claims it from the HUD - so this never touches the balance.
func record_stat(stat: String, amount := 1) -> void:
	if amount <= 0:
		return
	_session_totals[stat] = int(_session_totals.get(stat, 0)) + amount
	_update_quests({stat: amount})


## Total recorded for a stat since launch. Gameplay code snapshots this at a
## round boundary to measure per-round windows without extra counters.
func get_session_total(stat: String) -> int:
	return int(_session_totals.get(stat, 0))


## The cheapest cosmetic the player does not own yet, so the rewards card can
## point at a concrete next goal. Falls back to abilities once every cosmetic
## is owned, and returns an empty Dictionary when there is nothing left.
func get_next_unlock() -> Dictionary:
	var best: Dictionary = {}
	for category_value in COSMETIC_CATEGORIES + ["abilities"]:
		var category := str(category_value)
		if not best.is_empty() and category == "abilities":
			break
		for item_value in _catalog_for(category):
			var item := item_value as Dictionary
			if is_owned(str(item.get("id", ""))):
				continue
			var price := int(item.get("price", 0))
			if best.is_empty() or price < int(best.get("price", 0)):
				best = {
					"id": str(item.get("id", "")),
					"name": str(item.get("name", "")),
					"category": category,
					"rarity": str(item.get("rarity", "")),
					"price": price,
				}
	if not best.is_empty():
		best["balance"] = coins
	return best


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
		_queue_save()
		save_now()
		balance_changed.emit(coins, reward + bonus)
		quest_claimed.emit(quest.duplicate(true), reward + bonus)
		return true
	return false


func award_match(stats: Dictionary) -> Dictionary:
	var breakdown: Array = [{"label": "Base Reward", "amount": BASE_MATCH_REWARD}]
	var placement := clampi(int(stats.get("placement", 2)), 1, 99)
	var placement_reward := 30 if placement == 1 else (20 if placement == 2 else (10 if placement == 3 else 0))
	if placement_reward > 0:
		breakdown.append({"label": "Win Bonus" if placement == 1 else "Runner-Up Bonus", "amount": placement_reward})
	var eliminations := maxi(0, int(stats.get("eliminations", 0)))
	if eliminations > 0:
		breakdown.append({"label": "Eliminations  x%d" % eliminations, "amount": eliminations * ELIMINATION_REWARD})
	var damage := maxi(0, int(stats.get("damage", 0)))
	var damage_reward := mini(DAMAGE_REWARD_CAP, damage / DAMAGE_PER_COIN)
	if damage_reward > 0:
		breakdown.append({"label": "Damage Dealt  %d" % damage, "amount": damage_reward})
	var tricks := mini(3, maxi(0, int(stats.get("trick_shots", 0))))
	if tricks > 0:
		breakdown.append({"label": "Trick Shots  x%d" % tricks, "amount": tricks * TRICK_SHOT_REWARD})
	if bool(stats.get("survived", false)):
		breakdown.append({"label": "Survival Bonus", "amount": 15})
	if bool(stats.get("mvp", false)):
		breakdown.append({"label": "MVP Bonus", "amount": 20})
	# Quest progress advances here, but quest coins are paid on claim, so they
	# are deliberately absent from this breakdown.
	var quest_stats := {
		"matches": 1,
		"wins": 1 if placement == 1 else 0,
		"eliminations": eliminations,
		"trick_shots": tricks,
		"damage": damage,
	}
	var map_id := str(stats.get("map_id", "")).strip_edges()
	if not map_id.is_empty():
		quest_stats["wins_%s" % map_id] = 1 if placement == 1 else 0
	_update_quests(quest_stats)
	var total := 0
	for reward in breakdown:
		total += int((reward as Dictionary).get("amount", 0))
	coins += total
	var quest_ticks := _quest_ticks_since_mark()
	_mark_quest_progress()
	_queue_save()
	save_now()
	balance_changed.emit(coins, total)
	reward_earned.emit(breakdown, total)
	return {
		"breakdown": breakdown,
		"total": total,
		"balance": coins,
		"quest_ticks": quest_ticks,
		"next_unlock": get_next_unlock(),
	}


## Snapshot every active quest's progress so the next match award can report
## exactly which objectives advanced.
func _mark_quest_progress() -> void:
	_quest_progress_marks.clear()
	for group_data in [["daily", daily_quests], ["weekly", weekly_quests]]:
		for quest_value in group_data[1] as Array:
			var quest := quest_value as Dictionary
			_quest_progress_marks["%s/%s" % [str(group_data[0]), str(quest.get("id", ""))]] = int(quest.get("progress", 0))


## Quests whose progress moved since the last mark, oldest group first, each
## carrying the delta so the card can show "+2" next to the bar.
func _quest_ticks_since_mark() -> Array:
	var ticks: Array = []
	for group_data in [["daily", daily_quests], ["weekly", weekly_quests]]:
		var group := str(group_data[0])
		for quest_value in group_data[1] as Array:
			var quest := quest_value as Dictionary
			var key := "%s/%s" % [group, str(quest.get("id", ""))]
			var progress := int(quest.get("progress", 0))
			var previous := int(_quest_progress_marks.get(key, 0))
			if progress <= previous:
				continue
			ticks.append({
				"group": group,
				"id": str(quest.get("id", "")),
				"title": str(quest.get("title", "")),
				"progress": progress,
				"previous": previous,
				"delta": progress - previous,
				"target": maxi(1, int(quest.get("target", 1))),
				"reward": int(quest.get("reward", 0)),
				"completed": bool(quest.get("completed", false)),
			})
	return ticks


func _update_quests(stats: Dictionary) -> void:
	_refresh_quests_if_needed()
	var advanced := false
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
				quest_completed.emit(quest.duplicate(true), int(quest.get("reward", 0)))
			quest_group[index] = quest
			advanced = true
	if advanced:
		_queue_save()


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
	var rotated := false
	if _daily_key != daily_key:
		_daily_key = daily_key
		daily_quests = _make_quests(DAILY_POOL, 3, DAILY_REWARD, daily_key)
		set_meta("daily_set_claimed", false)
		rotated = true
	if _weekly_key != weekly_key:
		_weekly_key = weekly_key
		weekly_quests = _make_quests(WEEKLY_POOL, 5, -1, weekly_key)
		rotated = true
	if rotated:
		_mark_quest_progress()
		_queue_save()


## Skill quests that need an unowned ability are dropped before the seeded
## shuffle, so the rotation stays deterministic for a given loadout and never
## hands out an objective the player cannot attempt.
func _eligible_pool(pool: Array) -> Array:
	var eligible: Array = []
	for quest_value in pool:
		var quest := quest_value as Dictionary
		var required := str(quest.get("requires", ""))
		if required.is_empty() or is_owned(required):
			eligible.append(quest)
	return eligible


func _make_quests(pool: Array, count: int, default_reward: int, key: String) -> Array:
	var shuffled := _eligible_pool(pool).duplicate(true)
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
	var full_catalog := ABILITY_CATALOG if category == "abilities" else COSMETIC_LIBRARY.catalog().get(category, []) as Array
	if stock_full_catalog:
		return full_catalog
	var starter_id := str(STARTER_LOADOUT.get(category, ""))
	return full_catalog.filter(func(item: Dictionary) -> bool: return str(item.get("id", "")) == starter_id)


func _load() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	# A hand-edited or truncated save can hold the wrong type for any of these,
	# and `as Dictionary` would silently yield null and crash on first use.
	# Fall back to an empty collection instead, so a corrupt save costs progress
	# rather than the ability to launch.
	coins = maxi(0, int(config.get_value("progress", "coins", 0)))
	owned = _dictionary_or_empty(config.get_value("progress", "owned", {}))
	equipped = _dictionary_or_empty(config.get_value("progress", "equipped", {}))
	daily_quests = _quest_array_or_empty(config.get_value("quests", "daily", []))
	weekly_quests = _quest_array_or_empty(config.get_value("quests", "weekly", []))
	_daily_key = str(config.get_value("quests", "daily_key", ""))
	_weekly_key = str(config.get_value("quests", "weekly_key", ""))
	set_meta("daily_set_claimed", bool(config.get_value("quests", "daily_set_claimed", false)))
	_migrate_launch_cosmetics()
	_retarget_archived_map_quests()


func _dictionary_or_empty(value: Variant) -> Dictionary:
	if value is Dictionary:
		return value as Dictionary
	return {}


## Quest entries are read back as Dictionaries all through this file, so drop
## any element that is not one rather than failing later on a cast.
func _quest_array_or_empty(value: Variant) -> Array:
	if not (value is Array):
		return []
	var quests: Array = []
	for entry in value as Array:
		if entry is Dictionary:
			quests.append(entry)
	return quests


func _retarget_archived_map_quests() -> void:
	for quest_group in [daily_quests, weekly_quests]:
		for quest_value in quest_group:
			var quest := quest_value as Dictionary
			var stat := str(quest.get("stat", ""))
			var map_id := stat.trim_prefix("wins_")
			if not stat.begins_with("wins_") or not ARCHIVED_MAP_NAMES.has(map_id):
				continue
			quest["stat"] = "wins_%s" % LIVE_MAP_ID
			quest["title"] = str(quest.get("title", "")).replace(str(ARCHIVED_MAP_NAMES[map_id]), LIVE_MAP_NAME)


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


## Queues a write instead of performing one. Safe to call on hot paths.
func _queue_save() -> void:
	_dirty = true


## Writes immediately if anything is pending. Use for player-visible
## transactions where losing the last few seconds would be a real loss.
func save_now() -> void:
	if not _dirty:
		return
	_dirty = false
	_dirty_seconds = 0.0
	if persistence_enabled:
		_write_save_file()


func has_unsaved_progress() -> bool:
	return _dirty


func _write_save_file() -> void:
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
