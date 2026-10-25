extends SceneTree

const PROGRESSION_SCRIPT := preload("res://scripts/progression_manager.gd")
const COSMETIC_LIBRARY := preload("res://scripts/cosmetic_library.gd")

const EXPECTED_COUNTS := {
	"abilities": 12,
	"skins": 24,
	"trails": 19,
	"kill_effects": 16,
	"faces": 19,
}
const COSMETIC_CATEGORIES := ["skins", "trails", "kill_effects", "faces"]
const VALID_RARITIES := {
	"abilities": ["Basic", "Advanced", "Expert", "Legendary"],
	"skins": ["Common", "Rare", "Epic", "Legendary"],
	"trails": ["Common", "Rare", "Epic", "Legendary"],
	"kill_effects": ["Common", "Rare", "Epic", "Legendary"],
	"faces": ["Common", "Rare", "Epic", "Legendary"],
}

var failures: Array[String] = []


func _initialize() -> void:
	var progression := PROGRESSION_SCRIPT.new()
	progression.set("persistence_enabled", false)
	# The live shop only stocks the starter items; this guards the full data set.
	progression.set("stock_full_catalog", true)
	var all_ids: Dictionary = {}
	var total_items := 0

	for category_value in EXPECTED_COUNTS:
		var category := str(category_value)
		var items := progression.call("get_items", category) as Array
		var expected_count := int(EXPECTED_COUNTS[category])
		_check(items.size() == expected_count, "%s must contain exactly %d launch items, got %d" % [category, expected_count, items.size()])
		total_items += items.size()
		_validate_category(category, items, all_ids)
		_validate_catalog_is_a_deep_copy(progression, category, items)

	_check(total_items == 90, "The complete shop must expose exactly 90 items, got %d" % total_items)
	_check(all_ids.size() == 90, "All 90 item IDs must be globally unique because ownership is keyed by item ID")
	progression.free()
	_finish()


func _validate_category(category: String, items: Array, all_ids: Dictionary) -> void:
	var descriptions: Dictionary = {}
	var profile_signatures: Dictionary = {}
	var id_pattern := RegEx.new()
	id_pattern.compile("^[a-z0-9]+(?:_[a-z0-9]+)*$")

	for item_value in items:
		var item := item_value as Dictionary
		var item_id := str(item.get("id", ""))
		var item_name := str(item.get("name", ""))
		var rarity := str(item.get("rarity", ""))
		var description := str(item.get("description", "")).strip_edges()
		var label := "%s/%s" % [category, item_id if not item_id.is_empty() else "<missing-id>"]

		_check(not item_id.is_empty() and id_pattern.search(item_id) != null, "%s needs a stable snake_case ID" % label)
		_check(not all_ids.has(item_id), "%s duplicates the globally owned item ID '%s'" % [label, item_id])
		all_ids[item_id] = category
		_check(item_name.length() >= 3, "%s needs a player-facing display name" % label)
		_check((VALID_RARITIES[category] as Array).has(rarity), "%s has unsupported rarity '%s'" % [label, rarity])
		_check(int(item.get("price", 0)) > 0, "%s must have a positive Coin price" % label)
		_check(description.length() >= 32, "%s needs a polished, item-specific description of at least 32 characters" % label)
		_check(not descriptions.has(description), "%s reuses another item's description; every shop item needs distinct flavor copy" % label)
		descriptions[description] = item_id

		if category in COSMETIC_CATEGORIES:
			var profile := _profile_for(category, item_id)
			_check(not profile.is_empty(), "%s is missing its runtime cosmetic profile" % label)
			_check(str(profile.get("rarity", "")) == rarity, "%s catalog rarity and runtime profile rarity disagree" % label)
			var profile_signature := _profile_signature(category, profile)
			_check(not profile_signature.is_empty(), "%s has an incomplete runtime visual profile" % label)
			_check(not profile_signatures.has(profile_signature), "%s reuses the complete visual profile of %s" % [label, str(profile_signatures.get(profile_signature, "another item"))])
			profile_signatures[profile_signature] = item_id


func _validate_catalog_is_a_deep_copy(progression: Node, category: String, items: Array) -> void:
	if items.is_empty():
		return
	var original_name := str((items[0] as Dictionary).get("name", ""))
	(items[0] as Dictionary)["name"] = "MUTATED TEST ITEM"
	var fresh_items := progression.call("get_items", category) as Array
	_check(str((fresh_items[0] as Dictionary).get("name", "")) == original_name, "%s catalog callers must receive a deep copy" % category)


func _profile_for(category: String, item_id: String) -> Dictionary:
	match category:
		"skins":
			return COSMETIC_LIBRARY.skin_profile(item_id, Color.MAGENTA)
		"trails":
			return COSMETIC_LIBRARY.trail_profile(item_id)
		"faces":
			return COSMETIC_LIBRARY.face_profile(item_id)
		"kill_effects":
			return COSMETIC_LIBRARY.kill_profile(item_id)
	return {}


func _profile_signature(category: String, profile: Dictionary) -> String:
	match category:
		"skins":
			var primary: Color = profile.get("primary", Color.TRANSPARENT)
			var secondary: Color = profile.get("secondary", Color.TRANSPARENT)
			return "%s|%s|%s" % [primary.to_html(true), secondary.to_html(true), str(profile.get("effect", ""))]
		"trails":
			var trail_color: Color = profile.get("color", Color.TRANSPARENT)
			return "%s|%s" % [trail_color.to_html(true), str(profile.get("effect", ""))]
		"faces":
			var face_color: Color = profile.get("color", Color.TRANSPARENT)
			return "%s|%s" % [face_color.to_html(true), str(profile.get("effect", ""))]
		"kill_effects":
			var effect_color: Color = profile.get("color", Color.TRANSPARENT)
			return effect_color.to_html(true)
	return ""


func _finish() -> void:
	if failures.is_empty():
		print("SHOP CATALOG INTEGRITY CONTRACT PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
