extends SceneTree

const PROGRESSION_SCRIPT := preload("res://scripts/progression_manager.gd")
const PREVIEW_SCRIPT := preload("res://scripts/ui/shop_model_preview.gd")

const CATEGORIES := ["abilities", "skins", "trails", "kill_effects", "faces"]
const PLAYER_PROPERTY_BY_CATEGORY := {
	"skins": "_equipped_skin_id",
	"trails": "_equipped_trail_id",
	"kill_effects": "_equipped_kill_effect_id",
	"faces": "_equipped_face_id",
}

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var progression := PROGRESSION_SCRIPT.new()
	progression.set("persistence_enabled", false)
	var preview := SubViewportContainer.new()
	preview.name = "ExhaustiveShopPreview"
	preview.size = Vector2(420, 320)
	preview.set_script(PREVIEW_SCRIPT)
	root.add_child(preview)
	await process_frame

	var tested_ids: Dictionary = {}
	var visual_signatures: Dictionary = {}
	for category_value in CATEGORIES:
		var category := str(category_value)
		var items := progression.call("get_items", category) as Array
		for item_value in items:
			var item := item_value as Dictionary
			await _validate_preview_item(preview, category, item, tested_ids, visual_signatures)

	_check(tested_ids.size() == 89, "Preview runtime must exercise all 89 catalog items, exercised %d" % tested_ids.size())
	_check(visual_signatures.size() == 89, "Every shop item must expose a distinct non-empty visual_signature, got %d" % visual_signatures.size())
	_check(preview.find_children("*", "SubViewport", true, false).size() == 1, "Cycling all items must retain exactly one bounded SubViewport")
	_check(preview.find_children("*", "RigidBody3D", true, false).filter(func(node: Node) -> bool: return node.name == "InGameBlobModel").size() == 1, "Cycling all items must retain exactly one real preview blob")
	progression.free()
	preview.queue_free()
	await process_frame
	_finish()


func _validate_preview_item(preview: SubViewportContainer, category: String, item: Dictionary, tested_ids: Dictionary, visual_signatures: Dictionary) -> void:
	var item_id := str(item.get("id", ""))
	var label := "%s/%s" % [category, item_id]
	preview.call("set_item", category, item, _rarity_color(str(item.get("rarity", ""))))
	await process_frame

	var signature := preview.call("get_preview_signature") as Dictionary
	_check(str(signature.get("category", "")) == category, "%s preview reports the wrong category" % label)
	_check(str(signature.get("id", "")) == item_id, "%s preview reports the wrong item identity" % label)
	_check(bool(signature.get("uses_player_scene", false)), "%s preview must use the real in-game player scene" % label)
	_check(bool(signature.get("uses_subviewport", false)), "%s preview must render inside a bounded SubViewport" % label)
	var visual_signature := str(signature.get("visual_signature", "")).strip_edges()
	_check(not visual_signature.is_empty(), "%s preview must expose a non-empty visual_signature proving its visual variant was applied" % label)
	_check(not visual_signatures.has(visual_signature), "%s preview reuses the complete visual_signature of %s" % [label, str(visual_signatures.get(visual_signature, "another item"))])
	if not visual_signature.is_empty():
		visual_signatures[visual_signature] = label

	var model := preview.find_child("InGameBlobModel", true, false) as RigidBody3D
	_check(model != null, "%s preview is missing the real in-game blob" % label)
	if model != null:
		_check(model.freeze and model.collision_layer == 0 and model.collision_mask == 0, "%s preview blob must remain frozen and collision-free" % label)
		var nameplate := model.get_node_or_null("Nameplate") as Node3D
		_check(nameplate == null or not nameplate.visible, "%s preview must hide gameplay nameplate UI" % label)
		if PLAYER_PROPERTY_BY_CATEGORY.has(category):
			var property_name := str(PLAYER_PROPERTY_BY_CATEGORY[category])
			_check(str(model.get(property_name)) == item_id, "%s was not applied to the real preview blob property %s" % [label, property_name])

	var ability_icon := preview.find_child("AbilityIcon", true, false) as TextureRect
	if category == "abilities":
		_check(ability_icon != null and ability_icon.visible, "%s ability preview needs a visible item icon" % label)
		_check(ability_icon != null and ability_icon.texture != null, "%s ability preview icon asset failed to load" % label)
		if ability_icon != null and ability_icon.texture != null:
			_check(ability_icon.texture.resource_path.get_file().get_basename() == item_id, "%s preview loaded the wrong ability icon asset" % label)
	else:
		_check(ability_icon == null or not ability_icon.visible, "%s cosmetic preview must not leak the ability icon overlay" % label)

	tested_ids[item_id] = category


func _rarity_color(rarity: String) -> Color:
	match rarity:
		"Basic", "Common":
			return Color("62d3ff")
		"Advanced", "Rare":
			return Color("3d8cff")
		"Expert", "Epic":
			return Color("a566ff")
		"Legendary":
			return Color("ffbf43")
	return Color.WHITE


func _finish() -> void:
	if failures.is_empty():
		print("SHOP ALL ITEMS PREVIEW CONTRACT PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
