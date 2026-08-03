extends SceneTree

const HUD_SCENE := preload("res://scenes/hud.tscn")
const PREVIEW_SCRIPT := preload("res://scripts/ui/shop_model_preview.gd")
const PROGRESSION_SCRIPT := preload("res://scripts/progression_manager.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_item_specific_previews()
	await _test_shop_hover_is_layout_safe()
	await _test_shop_card_tap_selects_preview()
	if failures.is_empty():
		print("SHOP PREVIEW CONTRACT PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _test_item_specific_previews() -> void:
	var preview := SubViewportContainer.new()
	preview.size = Vector2(320, 240)
	preview.set_script(PREVIEW_SCRIPT)
	root.add_child(preview)
	await process_frame
	preview.call("set_item", "abilities", {"id": "blink", "name": "Blink"}, Color.WHITE)
	var ability := preview.call("get_preview_signature") as Dictionary
	_check(str(ability.get("id", "")) == "blink", "Ability preview identity is not the selected item")
	_check(bool(ability.get("uses_player_scene", false)), "Shop preview must instantiate the actual player scene")
	_check(bool(ability.get("uses_subviewport", false)), "Shop preview must use a bounded SubViewport")
	_check(preview.find_children("*", "SubViewport", true, false).size() == 1, "Selected item preview must own exactly one SubViewport")
	var model := preview.find_child("InGameBlobModel", true, false) as RigidBody3D
	_check(model != null, "Shop preview is missing the real in-game blob")
	if model != null:
		_check(model.freeze and model.collision_layer == 0 and model.collision_mask == 0, "Preview blob must be frozen and collision-free")
		_check(not model.get_node("Nameplate").visible, "Preview blob must hide gameplay nameplate UI")

	preview.call("set_item", "skins", {"id": "lava", "name": "Lava"}, Color.WHITE)
	var skin := preview.call("get_preview_signature") as Dictionary
	_check(str(skin.get("id", "")) == "lava", "Skin preview does not apply the selected item identity")

	preview.call("set_item", "trails", {"id": "meteor", "name": "Meteor"}, Color.WHITE)
	var trail := preview.call("get_preview_signature") as Dictionary
	_check(str(trail.get("id", "")) == "meteor", "Trail preview does not render the selected trail identity")

	preview.call("set_item", "faces", {"id": "pirate", "name": "Pirate"}, Color.WHITE)
	var face := preview.call("get_preview_signature") as Dictionary
	_check(str(face.get("id", "")) == "pirate", "Face preview does not render the selected face identity")

	preview.call("set_item", "kill_effects", {"id": "crystal_shatter", "name": "Crystal Shatter"}, Color.WHITE)
	var kill := preview.call("get_preview_signature") as Dictionary
	_check(str(kill.get("id", "")) == "crystal_shatter", "Kill-effect preview does not identify the selected effect")

	preview.call("set_item", "future_category", {"id": "unique_relic", "name": "Unique Relic"}, Color.WHITE)
	var fallback := preview.call("get_preview_signature") as Dictionary
	_check(str(fallback.get("id", "")) == "unique_relic", "Unknown shop categories must still retain item-specific identity")
	preview.queue_free()
	await process_frame


func _test_shop_hover_is_layout_safe() -> void:
	var hud := HUD_SCENE.instantiate()
	root.add_child(hud)
	await process_frame
	var card := PanelContainer.new()
	var grid := GridContainer.new()
	grid.add_child(card)
	hud.add_child(grid)
	await process_frame
	var layout_position := card.position
	hud.call("_animate_shop_card", card, true)
	hud.call("_animate_shop_card", card, false)
	hud.call("_animate_shop_card", card, true)
	hud.call("_animate_shop_card", card, false)
	await create_timer(0.2).timeout
	_check(card.position.is_equal_approx(layout_position), "Shop hover must not tween layout-controlled card position")
	_check(card.scale.is_equal_approx(Vector2.ONE), "Shop hover must restore the card scale after interrupted tweens")
	_check(card.z_index == 0, "Shop hover must restore the card's normal sibling layer")
	hud.queue_free()
	await process_frame


func _test_shop_card_tap_selects_preview() -> void:
	var progression := root.get_node_or_null("Progression")
	var created_progression := false
	if progression == null:
		progression = PROGRESSION_SCRIPT.new()
		progression.name = "Progression"
		progression.set("persistence_enabled", false)
		root.add_child(progression)
		created_progression = true
	await process_frame
	var hud := HUD_SCENE.instantiate()
	root.add_child(hud)
	await process_frame
	hud.call("_set_progression_open", "shop")
	await process_frame
	var shell := hud.find_child("ProgressionDrawer", true, false) as PanelContainer
	_check(shell != null, "Shop shell must exist when the shop opens")
	if shell != null:
		var viewport_width := root.get_viewport().get_visible_rect().size.x
		_check(shell.size.x >= minf(1180.0, viewport_width - 42.0), "Shop shell must use a premium full-screen store width")
	var hit_targets := hud.find_children("CardHitTarget", "Button", true, false)
	_check(hit_targets.size() >= 2, "Shop must expose full-card tap targets for item previews")
	if hit_targets.size() >= 2:
		var second_hit := hit_targets[1] as Button
		var card := second_hit.get_parent()
		var expected_id := str(card.name).trim_prefix("ShopItem_")
		_check(card.find_child("ItemPreview_%s" % expected_id, true, false) != null, "Shop item cards must render item thumbnails")
		second_hit.pressed.emit()
		await process_frame
		var selected := hud.get("_selected_shop_item") as Dictionary
		_check(str(selected.get("id", "")) == expected_id, "Tapping a shop card must update the live preview selection")
	hud.queue_free()
	if created_progression and is_instance_valid(progression):
		progression.queue_free()
	await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
