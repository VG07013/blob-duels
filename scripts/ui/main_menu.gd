class_name MainMenu
extends Control

## The pre-game screen: everything a player needs before a duel on one page.
## Left: how to play (match setup, bot duel, practice, host / join). Centre:
## the player's own blob hopping on a pedestal with name, colour and loadout.
## Right: today's quests and a rotating controls tip. Top: logo, coins,
## settings and quit.
##
## MainMenu owns layout and motion only. DuelHud owns what the controls mean:
## it reads the public fields below, wires their signals, mounts its coin
## chip into `coin_slot`, and fills `quest_card.content`.

signal map_selected(index: int)
signal difficulty_selected(index: int)
signal swatch_pressed(index: int)

const MENU_CARD := preload("res://scripts/ui/menu_card.gd")
const MENU_WORDMARK := preload("res://scripts/ui/menu_wordmark.gd")
const MENU_BLOB_STAGE := preload("res://scripts/ui/menu_blob_stage.gd")
const MENU_SEGMENTED := preload("res://scripts/ui/menu_segmented.gd")
const BACKDROP_SHADER: Shader = preload("res://assets/materials/menu_backdrop.gdshader")
const UI_TOKENS := preload("res://scripts/ui/ui_tokens.gd")

const ORANGE := Color(1.0, 0.5, 0.08)
const CYAN := Color(0.02, 0.82, 1.0)
const MINT := Color(0.36, 0.95, 0.7)
const SIDE_COLUMN_WIDTH := 404.0
const QUEST_COLUMN_WIDTH := 318.0
const INTRO_STAGGER := 0.07
const TIP_SECONDS := 6.0
## Each tip names its bound action so the text follows the player's rebinds.
const TIPS := [
	["charge_fling", "Hold %s to charge a fling. Even a quick tap launches you past rolling speed."],
	["bounce", "Press %s to bounce. Walls on every map throw you back harder."],
	["quick_blob", "Press %s for a quick blob, then you snap back to the Blaster."],
	["use_ability", "Press %s to fire your equipped power-up. Swap it in the Loadout."],
	["toggle_camera", "Press %s to swap between first and third person."],
	["brake", "Hold %s to brake. Ramps grip, roofs are ice."],
	["slide", "Hold %s to power slide for a burst of speed. Let go to hop out of it."],
]

var name_input: LineEdit
var code_input: LineEdit
var room_code_label: Label
var copy_button: Button
var host_button: Button
var join_button: Button
var practice_button: Button
var bot_button: Button
var format_button: Button
var settings_button: Button
var quests_button: Button
var shop_button: Button
var quit_button: Button
var connection_status: Label
var color_swatches: HBoxContainer
var coin_slot: HBoxContainer
var quest_card: MenuCard
var loadout_card: MenuCard
var stage: MenuBlobStage

var _backdrop_material := ShaderMaterial.new()
var _wordmark: MenuWordmark
var _map_segments: MenuSegmented
var _difficulty_segments: MenuSegmented
var _cards: Array[MenuCard] = []
var _fade_items: Array[Control] = []
var _display_labels: Array[Label] = []
var _tip_label: Label
var _loadout_icon: TextureRect
var _loadout_name: Label
var _unlock_name: Label
var _unlock_detail: Label
var _unlock_bar: ProgressBar
var _tip_index := 0
var _tip_clock := 0.0
var _intro_tween: Tween
var _reduced_motion := false


func _ready() -> void:
	name = "MainMenu"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_backdrop()
	_build_layout()


## Titles use the rounded display face. The HUD's blanket font pass runs
## first, so this re-applies it afterwards.
func configure_fonts(display_font: Font) -> void:
	_wordmark.configure(display_font, 50)
	for label in _display_labels:
		label.add_theme_font_override("font", display_font)
	name_input.add_theme_font_override("font", display_font)


func set_reduced_motion(enabled: bool) -> void:
	_reduced_motion = enabled
	_backdrop_material.set_shader_parameter("motion_scale", 0.0 if enabled else 1.0)
	_wordmark.set_reduced_motion(enabled)
	stage.set_reduced_motion(enabled)
	for card in _cards:
		card.set_reduced_motion(enabled)


func set_map_options(labels: Array, selected: int) -> void:
	_map_segments.set_options(labels, selected)


func get_selected_map_index() -> int:
	return _map_segments.selected


func set_difficulty_options(labels: Array, selected: int) -> void:
	_difficulty_segments.set_options(labels, selected)


func get_selected_difficulty_index() -> int:
	return _difficulty_segments.selected


func set_swatches(colors: Array, selected: int) -> void:
	for child in color_swatches.get_children():
		color_swatches.remove_child(child)
		child.queue_free()
	for index in colors.size():
		var swatch := Button.new()
		swatch.name = "Color%d" % index
		swatch.custom_minimum_size = Vector2(34, 34)
		swatch.tooltip_text = "Use blob color %d" % (index + 1)
		swatch.focus_mode = Control.FOCUS_NONE
		swatch.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		swatch.set_meta("swatch_color", colors[index])
		swatch.pressed.connect(func() -> void: swatch_pressed.emit(index))
		color_swatches.add_child(swatch)
	set_selected_swatch(selected)


func set_selected_swatch(index: int) -> void:
	for child_index in color_swatches.get_child_count():
		var swatch := color_swatches.get_child(child_index) as Button
		var color := swatch.get_meta("swatch_color", Color.WHITE) as Color
		var selected := child_index == index
		swatch.add_theme_stylebox_override("normal", _swatch_style(color, selected))
		swatch.add_theme_stylebox_override("hover", _swatch_style(color.lightened(0.12), true))
		swatch.add_theme_stylebox_override("pressed", _swatch_style(color.darkened(0.1), true))
		swatch.pivot_offset = swatch.custom_minimum_size * 0.5
		var target := Vector2.ONE * (1.14 if selected else 1.0)
		if _reduced_motion or not swatch.is_inside_tree():
			swatch.scale = target
			continue
		var tween := swatch.create_tween()
		tween.tween_property(swatch, "scale", target, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func show_identity(color: Color) -> void:
	stage.show_identity(color)


## `unlock_ratio` < 0 hides the next-unlock row (everything owned).
func set_loadout(icon: Texture2D, ability_title: String, unlock_title: String, unlock_detail: String, unlock_ratio: float) -> void:
	_loadout_icon.texture = icon
	_loadout_icon.visible = icon != null
	_loadout_name.text = ability_title
	var has_unlock := unlock_ratio >= 0.0
	_unlock_name.visible = has_unlock
	_unlock_detail.visible = has_unlock
	_unlock_bar.visible = has_unlock
	_unlock_name.text = unlock_title
	_unlock_detail.text = unlock_detail
	_unlock_bar.value = clampf(unlock_ratio, 0.0, 1.0)


func set_connection_status(message: String, color: Color, shown: bool) -> void:
	connection_status.text = message
	connection_status.add_theme_color_override("font_color", color)
	connection_status.visible = shown


## Entrance choreography: the hall fades up, the logo letters drop in, the
## cards pop in column by column, and the blob lands on its pedestal.
func play_intro() -> void:
	if _intro_tween != null and _intro_tween.is_valid():
		_intro_tween.kill()
	_tip_clock = 0.0
	if _reduced_motion:
		_set_reveal(1.0)
		_wordmark.play_intro(0.0)
		for item in _fade_items:
			item.modulate.a = 1.0
		stage.scale = Vector2.ONE
		stage.modulate.a = 1.0
		for card in _cards:
			card.play_intro(0.0)
		return
	_set_reveal(0.0)
	_wordmark.play_intro(0.12)
	for card_index in _cards.size():
		_cards[card_index].play_intro(0.25 + card_index * INTRO_STAGGER)
	_intro_tween = create_tween().set_parallel(true)
	_intro_tween.tween_method(_set_reveal, 0.0, 1.0, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	for item_index in _fade_items.size():
		var item := _fade_items[item_index]
		item.modulate.a = 0.0
		_intro_tween.tween_property(item, "modulate:a", 1.0, 0.45).set_delay(0.35 + item_index * 0.05)
	stage.pivot_offset = stage.size * Vector2(0.5, 0.85)
	stage.scale = Vector2(0.7, 0.7)
	stage.modulate.a = 0.0
	_intro_tween.tween_property(stage, "modulate:a", 1.0, 0.35).set_delay(0.3)
	_intro_tween.tween_property(stage, "scale", Vector2.ONE, 0.8).set_delay(0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_tip_clock += delta
	if _tip_clock >= TIP_SECONDS:
		_tip_clock = 0.0
		_advance_tip()


func _set_reveal(value: float) -> void:
	_backdrop_material.set_shader_parameter("reveal", value)


## Layout ----------------------------------------------------------------------
func _build_backdrop() -> void:
	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop_material.shader = BACKDROP_SHADER
	backdrop.material = _backdrop_material
	add_child(backdrop)


func _build_layout() -> void:
	var frame := MarginContainer.new()
	frame.name = "Frame"
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in [["margin_left", 40], ["margin_right", 40], ["margin_top", 22], ["margin_bottom", 18]]:
		frame.add_theme_constant_override(str(side[0]), int(side[1]))
	add_child(frame)
	var layout := VBoxContainer.new()
	layout.name = "Layout"
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_theme_constant_override("separation", 14)
	frame.add_child(layout)
	layout.add_child(_build_top_bar())
	var body := HBoxContainer.new()
	body.name = "Body"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_theme_constant_override("separation", 26)
	layout.add_child(body)
	body.add_child(_build_play_column())
	body.add_child(_build_hero_column())
	body.add_child(_build_quest_column())
	layout.add_child(_build_footer())


func _build_top_bar() -> Control:
	var bar := HBoxContainer.new()
	bar.name = "TopBar"
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_constant_override("separation", 12)
	var brand := VBoxContainer.new()
	brand.name = "Brand"
	brand.mouse_filter = Control.MOUSE_FILTER_IGNORE
	brand.add_theme_constant_override("separation", -6)
	bar.add_child(brand)
	_wordmark = MENU_WORDMARK.new()
	_wordmark.name = "Wordmark"
	brand.add_child(_wordmark)
	var tagline := _label("PHYSICS-FIRST 1V1 ARENA  ·  ALPHA", 12, UI_TOKENS.COLOR_MUTED)
	tagline.name = "Tagline"
	brand.add_child(tagline)
	_fade_items.append(tagline)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(spacer)
	coin_slot = HBoxContainer.new()
	coin_slot.name = "CoinSlot"
	coin_slot.alignment = BoxContainer.ALIGNMENT_CENTER
	coin_slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	coin_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(coin_slot)
	_fade_items.append(coin_slot)
	settings_button = _pill_button("SettingsButton", "SETTINGS", Color(0.68, 0.74, 0.9), false)
	settings_button.tooltip_text = "Open game settings"
	quit_button = _pill_button("QuitButton", "QUIT", Color(1.0, 0.42, 0.45), false)
	quit_button.tooltip_text = "Quit Blob Duels"
	for button in [settings_button, quit_button]:
		(button as Button).custom_minimum_size = Vector2(0, 42)
		(button as Button).size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.add_child(button)
		_fade_items.append(button)
	return bar


func _build_play_column() -> Control:
	var column := VBoxContainer.new()
	column.name = "PlayColumn"
	column.custom_minimum_size = Vector2(SIDE_COLUMN_WIDTH, 0)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 12)
	column.add_child(_section_header("PLAY", CYAN))

	var setup := _card("MatchSetup", Color(0.55, 0.62, 1.0), false, Vector4(12, 10, 12, 10), 0.12)
	var setup_row := HBoxContainer.new()
	setup_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	setup_row.add_theme_constant_override("separation", 10)
	setup.content.add_child(setup_row)
	_map_segments = MENU_SEGMENTED.new("MapPicker", CYAN)
	_map_segments.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map_segments.tooltip_text = "Arena for bot duels and hosted rooms"
	_map_segments.selection_changed.connect(func(index: int) -> void: map_selected.emit(index))
	setup_row.add_child(_map_segments)
	format_button = _pill_button("FormatButton", "FIRST TO 5", Color(0.55, 0.62, 1.0), false)
	format_button.custom_minimum_size = Vector2(118, 38)
	setup_row.add_child(format_button)
	column.add_child(setup)

	var bot := _card("BotCard", ORANGE, true, Vector4(20, 14, 18, 14), 0.4)
	bot.set_action_name("BotChoice", "Duel the AI offline on the selected arena")
	bot_button = bot.hit_button
	bot.content.add_child(_card_heading("DUEL A BOT", "Offline 1v1 against the AI  ·  full match rules", ORANGE))
	_difficulty_segments = MENU_SEGMENTED.new("BotDifficulty", ORANGE)
	_difficulty_segments.selection_changed.connect(func(index: int) -> void: difficulty_selected.emit(index))
	bot.content.add_child(_difficulty_segments)
	column.add_child(bot)

	var practice := _card("PracticeCard", MINT, true, Vector4(20, 14, 18, 14), 0.32)
	practice.set_action_name("PracticeChoice", "Train on the holo training grounds")
	practice_button = practice.hit_button
	practice.content.add_child(_card_heading("PRACTICE", "Holo training grounds  ·  8 dummy stations", MINT))
	column.add_child(practice)

	column.add_child(_build_online_card())
	return column


func _build_online_card() -> MenuCard:
	var online := _card("OnlineCard", CYAN, false, Vector4(18, 14, 18, 14), 0.2)
	online.content.add_child(_card_heading("PLAY A FRIEND", "Direct connection  ·  share your code", CYAN, false))
	var host_row := HBoxContainer.new()
	host_row.name = "HostRow"
	host_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host_row.add_theme_constant_override("separation", 8)
	online.content.add_child(host_row)
	room_code_label = _label("LAN CODE  LOCAL", 14, UI_TOKENS.COLOR_TEXT)
	room_code_label.name = "RoomCode"
	room_code_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	room_code_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	host_row.add_child(room_code_label)
	copy_button = _pill_button("CopyButton", "COPY LAN CODE", CYAN, false)
	copy_button.custom_minimum_size = Vector2(0, 38)
	copy_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	host_row.add_child(copy_button)
	host_button = _pill_button("StartHost", "HOST A DUEL", CYAN, true)
	host_button.custom_minimum_size = Vector2(0, 40)
	online.content.add_child(host_button)
	var join_row := HBoxContainer.new()
	join_row.name = "JoinRow"
	join_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	join_row.add_theme_constant_override("separation", 8)
	online.content.add_child(join_row)
	code_input = LineEdit.new()
	code_input.name = "CodeInput"
	code_input.placeholder_text = "ROOM CODE  e.g. C0A8-012A"
	code_input.custom_minimum_size = Vector2(0, 40)
	code_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	code_input.max_length = 21
	_style_line_edit(code_input, CYAN, 15)
	join_row.add_child(code_input)
	join_button = _pill_button("StartJoin", "JOIN", CYAN, false)
	join_button.custom_minimum_size = Vector2(96, 40)
	join_row.add_child(join_button)
	connection_status = _label("", 12, UI_TOKENS.COLOR_MUTED)
	connection_status.name = "ConnectionStatus"
	connection_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	connection_status.visible = false
	online.content.add_child(connection_status)
	return online


func _build_hero_column() -> Control:
	var column := VBoxContainer.new()
	column.name = "HeroColumn"
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 10)
	stage = MENU_BLOB_STAGE.new()
	stage.name = "BlobStage"
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.custom_minimum_size = Vector2(260, 220)
	stage.tooltip_text = "Drag to spin your blob"
	column.add_child(stage)
	name_input = LineEdit.new()
	name_input.name = "NameInput"
	name_input.placeholder_text = "YOUR NAME"
	name_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_input.max_length = 16
	name_input.custom_minimum_size = Vector2(280, 48)
	name_input.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_style_line_edit(name_input, CYAN, 22)
	column.add_child(name_input)
	_fade_items.append(name_input)
	color_swatches = HBoxContainer.new()
	color_swatches.name = "ColorSwatches"
	color_swatches.alignment = BoxContainer.ALIGNMENT_CENTER
	color_swatches.custom_minimum_size = Vector2(0, 40)
	color_swatches.add_theme_constant_override("separation", 12)
	column.add_child(color_swatches)
	_fade_items.append(color_swatches)
	shop_button = _pill_button("ShopButton", "LOADOUT  &  SHOP", UI_TOKENS.COLOR_GOLD, false)
	shop_button.custom_minimum_size = Vector2(240, 42)
	shop_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	shop_button.tooltip_text = "Equip power-ups and cosmetics"
	column.add_child(shop_button)
	_fade_items.append(shop_button)
	return column


func _build_quest_column() -> Control:
	var column := VBoxContainer.new()
	column.name = "QuestColumn"
	column.custom_minimum_size = Vector2(QUEST_COLUMN_WIDTH, 0)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 12)
	column.add_child(_section_header("TODAY", UI_TOKENS.COLOR_GOLD))
	quest_card = _card("QuestPanel", UI_TOKENS.COLOR_GOLD, false, Vector4(16, 14, 16, 14), 0.16)
	column.add_child(quest_card)
	quests_button = _pill_button("DockQuestsButton", "ALL QUESTS  &  REWARDS", MINT, false)
	quests_button.custom_minimum_size = Vector2(0, 40)
	quests_button.tooltip_text = "Track daily and weekly rewards"
	column.add_child(quests_button)
	_fade_items.append(quests_button)
	var tip_card := _card("TipCard", Color(0.6, 0.5, 1.0), false, Vector4(16, 12, 16, 14), 0.18)
	tip_card.content.add_child(_label("HOW TO PLAY", 11, Color(0.74, 0.68, 1.0)))
	_tip_label = _label("", 14, UI_TOKENS.COLOR_TEXT)
	_tip_label.name = "TipText"
	_tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_label.custom_minimum_size = Vector2(0, 58)
	_tip_label.text = _tip_text(0)
	tip_card.content.add_child(_tip_label)
	column.add_child(tip_card)
	column.add_child(_build_loadout_card())
	return column


func _build_loadout_card() -> MenuCard:
	loadout_card = _card("LoadoutCard", UI_TOKENS.COLOR_GOLD, true, Vector4(16, 12, 16, 14), 0.2)
	loadout_card.set_action_name("LoadoutButton", "Open the loadout and shop")
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	loadout_card.content.add_child(row)
	_loadout_icon = TextureRect.new()
	_loadout_icon.custom_minimum_size = Vector2(40, 40)
	_loadout_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_loadout_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_loadout_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_loadout_icon)
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation", 0)
	row.add_child(stack)
	stack.add_child(_label("EQUIPPED POWER-UP", 11, Color(1.0, 0.86, 0.5)))
	_loadout_name = _label("", 17, UI_TOKENS.COLOR_TEXT)
	_loadout_name.name = "LoadoutName"
	_display_labels.append(_loadout_name)
	stack.add_child(_loadout_name)
	var arrow := _label("›", 30, UI_TOKENS.COLOR_GOLD)
	arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_display_labels.append(arrow)
	row.add_child(arrow)
	var unlock_row := HBoxContainer.new()
	unlock_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	loadout_card.content.add_child(unlock_row)
	_unlock_name = _label("", 12, UI_TOKENS.COLOR_MUTED)
	_unlock_name.name = "NextUnlock"
	_unlock_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_unlock_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	unlock_row.add_child(_unlock_name)
	_unlock_detail = _label("", 12, UI_TOKENS.COLOR_GOLD)
	unlock_row.add_child(_unlock_detail)
	_unlock_bar = ProgressBar.new()
	_unlock_bar.custom_minimum_size = Vector2(0, 6)
	_unlock_bar.max_value = 1.0
	_unlock_bar.step = 0.0
	_unlock_bar.show_percentage = false
	_unlock_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_unlock_bar.add_theme_stylebox_override("background", _bar_style(Color(0.025, 0.035, 0.07)))
	_unlock_bar.add_theme_stylebox_override("fill", _bar_style(UI_TOKENS.COLOR_GOLD))
	loadout_card.content.add_child(_unlock_bar)
	return loadout_card


func _build_footer() -> Control:
	var footer := HBoxContainer.new()
	footer.name = "Footer"
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var left := _label("DIRECT P2P  ·  UDP 7359  ·  TRUSTED FRIENDS ALPHA", 11, Color(0.45, 0.52, 0.64))
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(left)
	footer.add_child(_label("ESC  SETTINGS", 11, Color(0.45, 0.52, 0.64)))
	_fade_items.append(footer)
	return footer


## Building blocks -------------------------------------------------------------
func _card(card_name: String, accent: Color, clickable: bool, padding: Vector4, accent_strength: float) -> MenuCard:
	var card: MenuCard = MENU_CARD.new(card_name, accent, clickable, padding, accent_strength)
	_cards.append(card)
	return card


func _card_heading(title_text: String, detail_text: String, accent: Color, with_arrow := true) -> Control:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation", 0)
	row.add_child(stack)
	var title := _label(title_text, 22, UI_TOKENS.COLOR_TEXT)
	title.name = "Title"
	_display_labels.append(title)
	stack.add_child(title)
	var detail := _label(detail_text, 12, accent.lerp(UI_TOKENS.COLOR_MUTED, 0.45))
	detail.name = "Detail"
	stack.add_child(detail)
	if with_arrow:
		var arrow := _label("›", 34, accent)
		arrow.name = "Arrow"
		arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_display_labels.append(arrow)
		row.add_child(arrow)
	return row


func _section_header(text: String, accent: Color) -> Control:
	var row := HBoxContainer.new()
	row.name = "%sHeader" % text.capitalize().replace(" ", "")
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	var bar := ColorRect.new()
	bar.color = accent
	bar.custom_minimum_size = Vector2(4, 14)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(bar)
	var label := _label(text, 13, accent.lightened(0.25))
	_display_labels.append(label)
	row.add_child(label)
	_fade_items.append(row)
	return row


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _pill_button(button_name: String, text: String, accent: Color, primary: bool) -> Button:
	var button := Button.new()
	button.name = button_name
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.custom_minimum_size = Vector2(0, 38)
	button.add_theme_font_size_override("font_size", 13)
	if primary:
		button.add_theme_stylebox_override("normal", _flat(accent.darkened(0.12), accent.lightened(0.25), 12, 1))
		button.add_theme_stylebox_override("hover", _flat(accent.lightened(0.08), Color.WHITE, 12, 1))
		button.add_theme_stylebox_override("pressed", _flat(accent.darkened(0.3), accent, 12, 1))
		button.add_theme_color_override("font_color", Color(0.01, 0.03, 0.06))
		button.add_theme_color_override("font_hover_color", Color(0.01, 0.02, 0.04))
		button.add_theme_color_override("font_pressed_color", Color(0.01, 0.02, 0.04))
	else:
		button.add_theme_stylebox_override("normal", _flat(Color(0.06, 0.08, 0.14, 0.78), Color(accent.r, accent.g, accent.b, 0.36), 12, 1))
		button.add_theme_stylebox_override("hover", _flat(Color(accent.r * 0.18, accent.g * 0.18, accent.b * 0.18 + 0.06, 0.94), accent, 12, 1))
		button.add_theme_stylebox_override("pressed", _flat(Color(0.03, 0.04, 0.08, 0.98), accent, 12, 2))
		button.add_theme_color_override("font_color", Color(0.88, 0.93, 1.0))
		button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_stylebox_override("disabled", _flat(Color(0.06, 0.07, 0.1, 0.8), Color(0.2, 0.24, 0.32, 0.6), 12, 1))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_color_override("font_disabled_color", Color(0.46, 0.5, 0.58))
	button.mouse_entered.connect(_tween_button_scale.bind(button, 1.04))
	button.mouse_exited.connect(_tween_button_scale.bind(button, 1.0))
	button.button_down.connect(_tween_button_scale.bind(button, 0.96))
	button.button_up.connect(_tween_button_scale.bind(button, 1.0))
	return button


func _tween_button_scale(button: Button, target: float) -> void:
	if _reduced_motion or button.disabled:
		button.scale = Vector2.ONE
		return
	button.pivot_offset = button.size * 0.5
	var tween := button.create_tween()
	tween.tween_property(button, "scale", Vector2.ONE * target, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _style_line_edit(field: LineEdit, accent: Color, font_size: int) -> void:
	field.add_theme_stylebox_override("normal", _flat(Color(0.03, 0.045, 0.09, 0.86), Color(0.36, 0.46, 0.62, 0.5), 12, 1, 14))
	field.add_theme_stylebox_override("focus", _flat(Color(0.04, 0.06, 0.12, 0.95), accent, 12, 2, 14))
	field.add_theme_stylebox_override("read_only", _flat(Color(0.04, 0.05, 0.08, 0.7), Color(0.2, 0.24, 0.32, 0.5), 12, 1, 14))
	field.add_theme_font_size_override("font_size", font_size)
	field.add_theme_color_override("font_color", UI_TOKENS.COLOR_TEXT)
	field.add_theme_color_override("font_placeholder_color", Color(0.45, 0.52, 0.64))
	field.add_theme_color_override("caret_color", accent)


func _flat(background: Color, border: Color, radius: int, border_width: int, horizontal_padding := 12) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = horizontal_padding
	style.content_margin_right = horizontal_padding
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	return style


func _bar_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(3)
	return style


func _swatch_style(color: Color, selected: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color.WHITE if selected else color.darkened(0.45)
	style.set_border_width_all(3 if selected else 1)
	style.set_corner_radius_all(17)
	style.shadow_color = Color(color.r, color.g, color.b, 0.55) if selected else Color.TRANSPARENT
	style.shadow_size = 10 if selected else 0
	return style


## Tips ------------------------------------------------------------------------
func _advance_tip() -> void:
	_tip_index = (_tip_index + 1) % TIPS.size()
	if _reduced_motion:
		_tip_label.text = _tip_text(_tip_index)
		return
	var tween := create_tween()
	tween.tween_property(_tip_label, "modulate:a", 0.0, 0.25)
	tween.tween_callback(func() -> void: _tip_label.text = _tip_text(_tip_index))
	tween.tween_property(_tip_label, "modulate:a", 1.0, 0.35)


func _tip_text(index: int) -> String:
	var tip: Array = TIPS[index]
	return str(tip[1]) % _binding_name(str(tip[0]))


func _binding_name(action: String) -> String:
	if not InputMap.has_action(action):
		return "?"
	for event in InputMap.action_get_events(action):
		if event is InputEventKey or event is InputEventMouseButton:
			return event.as_text().replace(" (Physical)", "").replace(" - Physical", "").to_upper()
	return "?"
