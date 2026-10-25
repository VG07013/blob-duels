extends SceneTree

const PROGRESSION_SCRIPT := preload("res://scripts/progression_manager.gd")
const ITEM_PREVIEW_SCRIPT := preload("res://scripts/shop_blob_preview.gd")
const OUTPUT_DIR := "res://artifacts/screenshots/shop_items"
const CATEGORIES := ["abilities", "skins", "trails", "kill_effects", "faces"]
const CATEGORY_TITLES := {
	"abilities": "ABILITY LOADOUT",
	"skins": "BLOB SKINS",
	"trails": "MOVEMENT TRAILS",
	"kill_effects": "K.O. EFFECTS",
	"faces": "BLOB FACES",
}
const RARITY_COLORS := {
	"Common": Color("8a98aa"),
	"Rare": Color("3594ff"),
	"Epic": Color("ad58ff"),
	"Legendary": Color("ffba2b"),
	"Basic": Color("4ee47a"),
	"Advanced": Color("3594ff"),
	"Expert": Color("ad58ff"),
}

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	DisplayServer.window_set_size(Vector2i(1280, 720))
	root.size = Vector2i(1280, 720)
	var progression := PROGRESSION_SCRIPT.new()
	progression.persistence_enabled = false
	root.add_child(progression)
	await process_frame
	for category in CATEGORIES:
		await _capture_category(progression, category)
	progression.queue_free()
	await process_frame
	if _failures.is_empty():
		print("SHOP ITEM VISUAL CAPTURE PASS — 89 ITEMS")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _capture_category(progression: Node, category: String) -> void:
	var canvas := Control.new()
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(canvas)
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color("060b18")
	canvas.add_child(background)
	var title := Label.new()
	title.position = Vector2(36, 16)
	title.size = Vector2(1200, 36)
	title.text = "%s  •  EVERY ITEM" % str(CATEGORY_TITLES.get(category, category.to_upper()))
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("f4f8ff"))
	canvas.add_child(title)
	var items := progression.call("get_items", category) as Array
	for index in items.size():
		var item := items[index] as Dictionary
		var column := index % 6
		var row := index / 6
		var card := _make_item_card(category, item)
		card.position = Vector2(36 + column * 202, 60 + row * 158)
		canvas.add_child(card)
	for _frame in 12:
		await process_frame
	await create_timer(1.25 if category == "kill_effects" else 0.12).timeout
	RenderingServer.force_draw()
	await process_frame
	var image := root.get_texture().get_image()
	if image == null:
		_failures.append("Could not render %s contact sheet" % category)
	else:
		var output_path := ProjectSettings.globalize_path("%s/%s_contact_sheet.png" % [OUTPUT_DIR, category])
		var error := image.save_png(output_path)
		if error != OK:
			_failures.append("Could not save %s" % output_path)
	canvas.queue_free()
	await process_frame


func _make_item_card(category: String, item: Dictionary) -> PanelContainer:
	var rarity := str(item.get("rarity", "Common"))
	var accent: Color = RARITY_COLORS.get(rarity, Color.WHITE)
	var card := PanelContainer.new()
	card.size = Vector2(190, 146)
	card.custom_minimum_size = card.size
	var style := StyleBoxFlat.new()
	style.bg_color = Color("0d162b")
	style.border_color = Color(accent, 0.66)
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	style.content_margin_left = 8
	style.content_margin_top = 6
	style.content_margin_right = 8
	style.content_margin_bottom = 7
	card.add_theme_stylebox_override("panel", style)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 2)
	card.add_child(stack)
	var preview := Control.new()
	preview.custom_minimum_size = Vector2(0, 92)
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.set_script(ITEM_PREVIEW_SCRIPT)
	preview.call("set_item", category, item, accent)
	stack.add_child(preview)
	var name := Label.new()
	name.text = str(item.get("name", "Item"))
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name.add_theme_font_size_override("font_size", 13)
	name.add_theme_color_override("font_color", Color("f2f6ff"))
	stack.add_child(name)
	var metadata := Label.new()
	metadata.text = "%s  •  %d" % [rarity.to_upper(), int(item.get("price", 0))]
	metadata.add_theme_font_size_override("font_size", 9)
	metadata.add_theme_color_override("font_color", accent)
	stack.add_child(metadata)
	return card
