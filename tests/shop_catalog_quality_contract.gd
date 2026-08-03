extends SceneTree

const PROGRESSION_SCRIPT := preload("res://scripts/progression_manager.gd")
const PREVIEW_SCRIPT := preload("res://scripts/ui/shop_model_preview.gd")

const CATEGORIES := ["abilities", "skins", "trails", "kill_effects", "faces"]
const VALID_RARITIES := ["Basic", "Advanced", "Expert", "Common", "Rare", "Epic", "Legendary"]
const EXPECTED_ITEM_COUNT := 89

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var progression := PROGRESSION_SCRIPT.new()
	progression.persistence_enabled = false
	root.add_child(progression)
	await process_frame
	_test_catalog_quality(progression)
	_test_transactions(progression)
	await _test_every_preview(progression)
	progression.queue_free()
	if failures.is_empty():
		print("SHOP CATALOG QUALITY CONTRACT PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _test_catalog_quality(progression: Node) -> void:
	var seen_ids := {}
	var total := 0
	for category in CATEGORIES:
		var items := progression.call("get_items", category) as Array
		_check(not items.is_empty(), "%s catalog is empty" % category)
		for item_value in items:
			var item := item_value as Dictionary
			var item_id := str(item.get("id", ""))
			total += 1
			_check(not item_id.is_empty(), "%s contains an item without an id" % category)
			_check(not seen_ids.has(item_id), "Duplicate shop id: %s" % item_id)
			seen_ids[item_id] = category
			_check(str(item.get("name", "")).length() >= 3, "%s has an invalid name" % item_id)
			_check(str(item.get("rarity", "")) in VALID_RARITIES, "%s has an invalid rarity" % item_id)
			_check(int(item.get("price", 0)) > 0, "%s must have a positive price" % item_id)
			var description := str(item.get("description", ""))
			_check(description.length() >= 28, "%s needs authored product copy" % item_id)
			_check(not description.to_lower().contains(" cosmetic • "), "%s still uses generic catalog copy" % item_id)
			_check(str(item.get("tagline", "")).length() >= 8, "%s needs a premium tagline" % item_id)
			_check(not str(item.get("preview_mode", "")).is_empty(), "%s needs preview metadata" % item_id)
			_check(not str(item.get("runtime_effect", "")).is_empty(), "%s needs runtime renderer metadata" % item_id)
	_check(total == EXPECTED_ITEM_COUNT, "Expected %d shop items, found %d" % [EXPECTED_ITEM_COUNT, total])


func _test_transactions(progression: Node) -> void:
	progression.set("coins", 1000000)
	for category in CATEGORIES:
		var items := progression.call("get_items", category) as Array
		for item_value in items:
			var item := item_value as Dictionary
			var item_id := str(item.get("id", ""))
			if not bool(progression.call("is_owned", item_id)):
				var before := int(progression.call("get_balance"))
				_check(bool(progression.call("purchase", category, item_id)), "Purchase failed for %s" % item_id)
				_check(int(progression.call("get_balance")) == before - int(item.get("price", 0)), "Incorrect balance delta for %s" % item_id)
			_check(bool(progression.call("equip", category, item_id)), "Equip failed for %s" % item_id)
			_check(str(progression.call("get_equipped", category)) == item_id, "Equipped id mismatch for %s" % item_id)
	var skin_items := progression.call("get_items", "skins") as Array
	if not skin_items.is_empty():
		var skin_id := str((skin_items[0] as Dictionary).get("id", ""))
		_check(not bool(progression.call("equip", "trails", skin_id)), "Cross-category equip must be rejected")


func _test_every_preview(progression: Node) -> void:
	var preview := SubViewportContainer.new()
	preview.size = Vector2(320, 240)
	preview.set_script(PREVIEW_SCRIPT)
	root.add_child(preview)
	await process_frame
	for category in CATEGORIES:
		for item_value in progression.call("get_items", category) as Array:
			var item := item_value as Dictionary
			preview.call("set_item", category, item, Color.WHITE)
			await process_frame
			var signature := preview.call("get_preview_signature") as Dictionary
			_check(str(signature.get("id", "")) == str(item.get("id", "")), "Preview identity mismatch for %s" % str(item.get("id", "")))
			_check(str(signature.get("renderer", "")).length() >= 3, "Preview renderer missing for %s" % str(item.get("id", "")))
			if category != "abilities":
				var runtime_player := preview.find_child("InGameBlobModel", true, false)
				_check(runtime_player != null, "Runtime player missing for %s" % str(item.get("id", "")))
				if runtime_player != null:
					var runtime_signature := runtime_player.call("get_cosmetic_signature") as Dictionary
					var signature_key: String = {"skins": "skin", "trails": "trail", "faces": "face", "kill_effects": "kill_effect"}.get(category, "")
					_check(str(runtime_signature.get(signature_key, "")) == str(item.get("id", "")), "Runtime renderer did not apply %s" % str(item.get("id", "")))
			if category == "kill_effects":
				preview.call("replay")
				await process_frame
				_check(preview.find_children("*", "GPUParticles3D", true, false).size() > 0, "Kill effect did not emit for %s" % str(item.get("id", "")))
	_check(preview.find_children("*", "SubViewport", true, false).size() == 1, "Preview must keep exactly one SubViewport after all items")
	preview.queue_free()
	await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
