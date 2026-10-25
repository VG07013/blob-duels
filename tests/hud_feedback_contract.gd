extends SceneTree

## Duel feedback layer: hit-marker variants, pooled damage numbers, the kill
## feed, the low-health vignette, the directional damage arc, the round-intro
## card, and the post-match rewards receipt.

const HUD_SCENE := preload("res://scenes/hud.tscn")
const PROGRESSION_SCRIPT := preload("res://scripts/progression_manager.gd")
const FEEDBACK_SCRIPT := preload("res://scripts/ui/duel_feedback.gd")
const REFERENCE_VIEWPORT := Vector2(1280, 720)

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var hud := HUD_SCENE.instantiate()
	root.add_child(hud)
	await process_frame
	hud.call("set_lobby_mode", false)
	hud.call("set_duel_mode", true)
	await process_frame
	var feedback := hud.call("get_feedback_layer") as Control
	_check(feedback != null and feedback.name == "DuelFeedback", "Duel HUD must own one DuelFeedback layer for combat feedback")
	if feedback != null:
		_test_kill_feed(hud, feedback)
		_test_damage_numbers(feedback)
		_test_vignette_and_direction(feedback)
		_test_hit_marker_variants(hud, feedback)
		await _test_reduced_motion(hud, feedback)
		await _test_round_intro(hud, feedback)
	await _test_rewards_card(hud)
	_test_ability_label(hud)
	hud.queue_free()
	await process_frame
	if failures.is_empty():
		print("HUD FEEDBACK CONTRACT PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _test_kill_feed(hud: Node, feedback: Control) -> void:
	for index in 4:
		hud.call("add_kill_feed_entry", "Vihaan", Color.CYAN, "Rival %d" % index, Color.RED, "rail")
	_check(int(feedback.call("feed_entry_count")) == 3, "Kill feed must keep at most three entries, dropping the oldest")
	hud.call("add_feed_message", "Rival fell out of the arena", Color.WHITE)
	_check(int(feedback.call("feed_entry_count")) == 3, "Free-form feed lines must respect the same three-entry cap")
	_check(is_equal_approx(float(FEEDBACK_SCRIPT.KILL_FEED_LIFETIME), 4.0), "Feed entries must fade after four seconds")
	var entries := feedback.call("feed_entries") as Array
	if not entries.is_empty():
		var newest := entries[entries.size() - 1] as Control
		var remaining := int(newest.get_meta("expires_at", 0)) - Time.get_ticks_msec()
		_check(remaining > 3800 and remaining <= 4000, "Each feed entry must carry a four-second expiry from the moment it appears")
		var oldest := entries[0] as Control
		_check(_has_label_fragment(oldest, "(RAIL)"), "Kill feed lines must name the ability that scored the elimination")
		_check(_has_label_fragment(oldest, "Vihaan") and _has_label_fragment(oldest, "Rival"), "Kill feed lines must name both the scorer and the victim")
	feedback.call("reset")
	_check(int(feedback.call("feed_entry_count")) == 0, "Leaving the arena must clear the kill feed")


func _test_damage_numbers(feedback: Control) -> void:
	var pool_size := int(feedback.call("damage_number_pool_size"))
	var pool_root := feedback.get_node_or_null("DamageNumbers") as Control
	_check(pool_size == FEEDBACK_SCRIPT.DAMAGE_NUMBER_POOL_SIZE and pool_root != null, "Damage numbers must come from a fixed, pre-built pool")
	for index in pool_size + 8:
		feedback.call("show_damage_number_at", 30, Vector2(640, 360), "hit")
	_check(pool_root != null and pool_root.get_child_count() == pool_size, "A burst of hits must reuse pooled labels rather than allocate new ones")
	_check(int(feedback.call("active_damage_number_count")) <= pool_size, "Active damage numbers can never exceed the pool")
	feedback.call("reset")
	var first := feedback.call("show_damage_number_at", 30, Vector2(200, 200), "hit", "target_a") as Label
	var second := feedback.call("show_damage_number_at", 25, Vector2(214, 190), "hit", "target_a") as Label
	_check(first != null and first == second, "Repeated hits on one target must add into a single number, not spawn a new one")
	_check(second != null and second.text == "55", "The combined number must show the running total (30 + 25 = 55)")
	_check(int(feedback.call("active_damage_number_count")) == 1, "Repeated hits on one target must leave exactly one number on screen")
	var other := feedback.call("show_damage_number_at", 30, Vector2(900, 400), "hit", "target_b") as Label
	_check(other != null and other != first and other.text == "30", "A different target must get its own number")
	feedback.call("reset")
	_check(feedback.call("show_damage_number_at", 0, Vector2.ZERO, "hit") == null, "Zero damage must not spawn a number")
	var small := feedback.call("damage_number_style", 10, "hit") as Dictionary
	var large := feedback.call("damage_number_style", 45, "hit") as Dictionary
	_check(int(large.get("font_size", 0)) > int(small.get("font_size", 0)), "Bigger hits must render as bigger numbers")
	_check(large.get("color", Color.WHITE) != small.get("color", Color.WHITE), "Damage number colour must change with the size of the hit")
	var rail := feedback.call("damage_number_style", 30, "rail") as Dictionary
	_check(rail.get("color", Color.WHITE) != (feedback.call("damage_number_style", 30, "hit") as Dictionary).get("color", Color.WHITE), "Rail hits must use their own damage-number colour")


func _test_vignette_and_direction(feedback: Control) -> void:
	feedback.call("set_low_health_ratio", 0.31)
	_check(not bool(feedback.call("is_low_health_vignette_active")), "Low-health vignette must stay hidden at or above 30% health")
	feedback.call("set_low_health_ratio", 0.29)
	_check(bool(feedback.call("is_low_health_vignette_active")), "Low-health vignette must appear below 30% health")
	var vignette := feedback.get_node_or_null("LowHealthVignette") as TextureRect
	_check(vignette != null and vignette.visible and vignette.texture is GradientTexture2D, "Low-health vignette must be a screen-edge gradient, not a flat flash")
	feedback.call("set_low_health_ratio", 1.0)
	_check(not bool(feedback.call("is_low_health_vignette_active")), "Healing back above the threshold must clear the vignette")
	feedback.call("show_damage_direction_angle", 1.2)
	_check(bool(feedback.call("is_damage_direction_active")) and is_equal_approx(float(feedback.call("damage_direction_angle")), 1.2), "Directional damage arc must point at the angle of the damage source")


func _test_hit_marker_variants(hud: Node, feedback: Control) -> void:
	var variants := hud.get("HIT_MARKER_VARIANTS") as Dictionary
	var plain := variants.get("hit", {}) as Dictionary
	var elimination := variants.get("elimination", {}) as Dictionary
	var rail := variants.get("rail", {}) as Dictionary
	_check(float(elimination.get("scale", 0.0)) > float(plain.get("scale", 0.0)) and float(elimination.get("duration", 0.0)) > float(plain.get("duration", 0.0)), "Elimination hit marker must be heavier and linger longer than a plain hit")
	_check(float(rail.get("scale", 0.0)) > float(plain.get("scale", 0.0)) and rail.get("color", Color.WHITE) != plain.get("color", Color.WHITE), "Rail hit marker must be distinct from a plain hit")
	hud.call("show_hit_marker", "elimination")
	_check(str(hud.call("get_hit_marker_kind")) == "elimination", "Hit marker must remember which variant is showing")
	_check(bool(feedback.call("is_elimination_ring_active")), "Elimination must add a ring flash around the crosshair")
	var marker := hud.find_child("HitMarker", true, false) as Control
	var slash := marker.get_node_or_null("Slash") as ColorRect if marker != null else null
	_check(slash != null and slash.color.is_equal_approx(elimination.get("color", Color.WHITE)), "Elimination must recolour the hit marker")
	hud.call("show_hit_marker", "bogus")
	_check(str(hud.call("get_hit_marker_kind")) == "hit", "Unknown hit kinds must fall back to the plain marker")


func _test_reduced_motion(hud: Node, feedback: Control) -> void:
	hud.call("apply_ui_settings", {"reduced_motion": true})
	_check(bool(feedback.call("is_reduced_motion")), "Reduced motion must reach the feedback layer")
	hud.call("show_hit_marker", "rail")
	var marker := hud.find_child("HitMarker", true, false) as Control
	var rail_scale := float((hud.get("HIT_MARKER_VARIANTS") as Dictionary).get("rail", {}).get("scale", 1.0))
	_check(marker != null and marker.scale.is_equal_approx(Vector2.ONE * rail_scale), "Reduced motion must skip the hit-marker scale entrance")
	var label := feedback.call("show_damage_number_at", 30, Vector2(300, 300), "hit") as Label
	_check(label != null and label.scale.is_equal_approx(Vector2.ONE), "Reduced motion must skip the damage-number pop")
	var start_y := label.position.y if label != null else 0.0
	await process_frame
	await process_frame
	_check(label != null and is_equal_approx(label.position.y, start_y), "Reduced motion must keep damage numbers from rising")
	hud.call("apply_ui_settings", {"reduced_motion": false})


func _test_round_intro(hud: Node, feedback: Control) -> void:
	hud.call("set_round_number", 3)
	hud.call("set_duel_score", 2, 1)
	hud.call("show_countdown_beat", "3")
	var bar = hud.call("get_match_bar")
	_check(bar != null and str(bar.call("get_timer_text")) == "3", "The round countdown must count down inside the match-timer box")
	_check(not bool(feedback.call("is_round_intro_visible")), "The countdown must not bring up a separate round-intro card")
	hud.call("show_countdown_beat", "GO!")
	_check(bar != null and str(bar.call("get_timer_text")) == "GO!", "The countdown must end on GO! in the timer box")
	await process_frame


func _test_rewards_card(hud: Node) -> void:
	var economy := PROGRESSION_SCRIPT.new()
	economy.set("persistence_enabled", false)
	economy.coins = 0
	economy.call("_refresh_quests_if_needed")
	economy.daily_quests = [
		{"id": "elims", "title": "Get 5 Eliminations", "target": 5, "progress": 0, "reward": 75, "stat": "eliminations", "completed": false, "claimed": false},
		{"id": "bounceground", "title": "Win a Match on Bounceground", "target": 1, "progress": 0, "reward": 75, "stat": "wins_bounceground", "completed": false, "claimed": false},
		{"id": "idle", "title": "Bounce 100 Times", "target": 100, "progress": 0, "reward": 75, "stat": "bounces", "completed": false, "claimed": false},
	]
	economy.weekly_quests = []
	economy.call("_mark_quest_progress")
	var reward := economy.call("award_match", {"placement": 1, "eliminations": 2, "damage": 400, "trick_shots": 1, "survived": false, "mvp": false, "map_id": "bounceground"}) as Dictionary
	var breakdown := reward.get("breakdown", []) as Array
	var summed := 0
	var labels: Array[String] = []
	for entry_value in breakdown:
		var entry := entry_value as Dictionary
		summed += int(entry.get("amount", 0))
		labels.append(str(entry.get("label", "")))
	_check(summed == int(reward.get("total", -1)), "Reward breakdown rows must add up to the total")
	_check(labels.any(func(label: String) -> bool: return label.begins_with("Win Bonus")), "A won match must show a Win Bonus row")
	_check(labels.any(func(label: String) -> bool: return label.begins_with("Eliminations")), "Eliminations must appear as their own reward row")
	_check(_row_amount(breakdown, "Damage Dealt") == 10, "Damage must pay one Coin per 40 dealt (400 damage = 10 Coins)")
	_check(int(reward.get("total", 0)) == 25 + 30 + 10 + 10 + 10, "Base, win, elimination, damage and trick-shot rows must total 85 Coins for this match")
	var ticks := reward.get("quest_ticks", []) as Array
	_check(ticks.size() == 2, "Only quests that advanced this match may appear as progress ticks")
	if ticks.size() == 2:
		var elim_tick := ticks[0] as Dictionary
		_check(int(elim_tick.get("delta", 0)) == 2 and int(elim_tick.get("progress", 0)) == 2, "Quest ticks must report how far the objective moved this match")
		_check(bool((ticks[1] as Dictionary).get("completed", false)), "A quest finished by the match must be flagged ready to claim")
	_check(int(economy.call("get_balance")) == int(reward.get("total", 0)), "Quest ticks must not pay out - quest coins are paid on claim")
	var next_unlock := reward.get("next_unlock", {}) as Dictionary
	_check(int(next_unlock.get("price", 0)) == 50 and str(next_unlock.get("category", "")) == "faces", "Next unlock must be the cheapest cosmetic the player does not own")
	hud.call("set_duel_score", 5, 2)
	hud.call("show_victory", true, 0, [])
	hud.call("show_match_rewards", reward)
	await process_frame
	await process_frame
	var rewards := hud.find_child("MatchRewards", true, false) as PanelContainer
	_check(rewards != null and rewards.visible, "Match rewards card must appear with the result")
	if rewards != null:
		var rows := rewards.get_node("Stack/Rows") as VBoxContainer
		_check(rows.get_child_count() == breakdown.size() + 1, "Rewards card must render every breakdown row plus the total")
		var quest_section := rewards.get_node("Stack/QuestTicks") as Control
		_check(quest_section.visible and quest_section.get_node_or_null("QuestTick0") != null, "Rewards card must list the quest objectives that advanced")
		var unlock_section := rewards.get_node("Stack/NextUnlock") as Control
		var unlock_title := unlock_section.find_child("NextUnlockTitle", true, false) as Label
		var unlock_bar := unlock_section.find_child("NextUnlockBar", true, false) as ProgressBar
		_check(unlock_section.visible and unlock_title != null and str(next_unlock.get("name", "")).to_upper() in unlock_title.text, "Rewards card must name the next unlock")
		_check(unlock_bar != null and is_equal_approx(unlock_bar.max_value, float(next_unlock.get("price", 0))), "Next-unlock bar must be scaled to the item price")
		_check(rewards.size.x <= 460.0 and rewards.size.y <= REFERENCE_VIEWPORT.y * 0.58, "Rewards card must stay a compact receipt even with quest and unlock rows")
		var rematch := rewards.find_child("RematchButton", true, false) as Button
		var back := rewards.find_child("ReturnToLobbyButton", true, false) as Button
		_check(rematch != null and back != null, "Rewards card must offer Rematch and Return to Lobby")
		_check(hud.has_signal("rematch_requested"), "DuelHud must expose a rematch_requested signal for the match flow")
		var rematch_count := [0]
		hud.connect("rematch_requested", func() -> void: rematch_count[0] += 1)
		if rematch != null:
			rematch.pressed.emit()
		_check(rematch_count[0] == 1, "Pressing Rematch must emit rematch_requested exactly once")
	hud.call("show_match_rewards", {"breakdown": [{"label": "Match complete", "amount": 50}], "total": 50})
	await process_frame
	if rewards != null:
		_check(not (rewards.get_node("Stack/QuestTicks") as Control).visible, "A reward without quest ticks must hide the quest section")
	hud.call("hide_victory")
	economy.free()


func _test_ability_label(hud: Node) -> void:
	hud.call("set_lobby_mode", false)
	hud.call("set_ability_state", "dash", 0, false, false)
	var ability := hud.find_child("AbilityHUD", true, false) as Control
	var name_label := ability.get_node_or_null("AbilityName") as Label if ability != null else null
	var badge := ability.get_node_or_null("KeyBadge/Label") as Label if ability != null else null
	var keybind := str(ability.call("keybind_text")) if ability != null else ""
	_check(not keybind.is_empty(), "Ability HUD must resolve the ability keybind from the InputMap")
	_check(name_label == null or not name_label.visible, "The ability slot must not spell out its name - just the icon and its key")
	_check(badge != null and badge.text == keybind, "Key badge must show the bound key")
	hud.call("set_ability_state", "dash", 3000, false, false)
	hud.call("set_ability_state", "dash", 0, false, false)
	_check(bool(ability.call("is_ready_flash_active")), "A cooldown completing must trigger the ready flash")


func _row_amount(breakdown: Array, prefix: String) -> int:
	for entry_value in breakdown:
		var entry := entry_value as Dictionary
		if str(entry.get("label", "")).begins_with(prefix):
			return int(entry.get("amount", 0))
	return -1


func _has_label_fragment(scope: Node, fragment: String) -> bool:
	for candidate in scope.find_children("*", "Label", true, false):
		if fragment in (candidate as Label).text:
			return true
	return false


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
