class_name ProgressionDrawer
extends Node

## Everything Progression-facing in the HUD: the coin chip and the menu quest
## card, the translucent drawer that holds the Shop and the Quest Board, the
## purchase and claim flows, and the quest / coin toasts. DuelHud creates one
## of these in _setup_progression_ui and forwards the handful of calls the menu
## and the pause flow make (open, close, is open, toast); the layout, motion and
## Progression wiring live here. Controls are still added to the HUD layer, so
## they draw over the menu and under the victory overlay exactly as before.

const COIN_ICON_SCRIPT := preload("res://scripts/ui/coin_icon.gd")
const SHOP_CARD_PREVIEW_SCRIPT := preload("res://scripts/shop_blob_preview.gd")
const SHOP_MODEL_PREVIEW_SCRIPT := preload("res://scripts/ui/shop_model_preview.gd")
const UI_TOKENS := preload("res://scripts/ui/ui_tokens.gd")
const MENU_CARD := preload("res://scripts/ui/menu_card.gd")
const MENU_SEGMENTED := preload("res://scripts/ui/menu_segmented.gd")
const PROGRESS_RING := preload("res://scripts/ui/progress_ring.gd")
const PROGRESSION_FX := preload("res://scripts/ui/progression_fx.gd")
## Rarity accents, shared with the results screen through DuelHud.RARITY_COLORS.
const RARITY_COLORS := DuelHud.RARITY_COLORS
## Shop category ids (Progression catalog keys) and their tab labels, in order.
const SHOP_CATEGORIES := [["abilities", "ABILITIES"], ["skins", "SKINS"], ["trails", "TRAILS"], ["kill_effects", "EFFECTS"], ["faces", "FACES"]]
const SHOP_ITEM_KINDS := {"abilities": "ABILITY", "skins": "SKIN", "trails": "TRAIL", "kill_effects": "KILL EFFECT", "faces": "FACE"}
const SHOP_CARD_SIZE := Vector2(152, 206)
const SHOP_SPOTLIGHT_WIDTH := 282.0
## Owned / equipped / claimed.
const SHOP_MINT := Color(0.38, 1.0, 0.64)
## Prices the player cannot cover yet.
const SHOP_SHORT := Color(1.0, 0.48, 0.44)

var hud: DuelHud
## The Progression autoload; null in headless runs without it, in which case
## nothing is built and every entry point is a no-op.
var _progression: Node
var _coin_balance_label: Label
var _coin_chip: PanelContainer
var _coin_icon: Control
var _shop_overlay: Control
var _shop_shell: PanelContainer
var _shop_content: VBoxContainer
var _quest_panel: PanelContainer
var _quest_reset_label: Label
var _shown_coin_balance := 0.0
var _coin_target_balance := 0
var _active_progression_page := "shop"
var _active_shop_category := "abilities"
var _selected_shop_item: Dictionary = {}
var _quests_showing_weekly := false
var _quest_reset_accumulator := 0.0
## Progression drawer (shop + quest board). The header is built once; the body
## below it rebuilds per page, and the shop / board keep their own slots so a
## category, item, or tab change only rebuilds what it touches.
var _drawer_body: VBoxContainer
var _drawer_title: Label
var _drawer_subtitle: Label
var _drawer_page_tabs: MenuSegmented
var _drawer_balance_chip: PanelContainer
var _drawer_balance_label: Label
var _drawer_shown_balance := 0
## True while a claim is sending coins to the header: the balance counts up
## when they land instead of on the balance_changed signal.
var _drawer_coin_flight := false
var _drawer_tween: Tween
var _drawer_size := Vector2(900, 600)
var _progression_closing := false
var _shop_scroll: ScrollContainer
var _shop_grid: GridContainer
var _shop_spotlight_slot: VBoxContainer
var _shop_section_label: Label
var _quest_board_slot: VBoxContainer
var _board_reset_label: Label
var _quest_ring_ratio := 0.0
var _quest_list: VBoxContainer
var _toast_stack: VBoxContainer


func setup(owner_hud: DuelHud, progression: Node) -> void:

	hud = owner_hud
	_progression = progression
	_create_toast_stack()
	if _progression == null:
		return
	_coin_target_balance = int(_progression.call("get_balance"))
	_shown_coin_balance = _coin_target_balance
	_progression.balance_changed.connect(_on_coin_balance_changed)
	_progression.quest_completed.connect(_on_quest_completed)
	_progression.inventory_changed.connect(_refresh_shop_if_open)
	_create_coin_chip()
	_create_quest_panel()
	_create_shop_overlay()
	get_viewport().size_changed.connect(_fit_progression_drawer)


## The quest reset countdown ticks once a second; the balance counts toward
## its target so purchases and claims are seen to move it.
func _process(delta: float) -> void:
	_quest_reset_accumulator += delta
	if _quest_reset_accumulator >= 1.0:
		_quest_reset_accumulator = 0.0
		_update_quest_reset_label()
	if absf(_shown_coin_balance - float(_coin_target_balance)) > 0.05:
		_shown_coin_balance = move_toward(_shown_coin_balance, float(_coin_target_balance), maxf(80.0, absf(_coin_target_balance - _shown_coin_balance) * 7.0) * delta)
		_update_coin_label()


func is_progression_open() -> bool:
	return _shop_overlay != null and _shop_overlay.visible and not _progression_closing


func close_progression() -> void:
	_set_shop_open(false)


func _create_coin_chip() -> void:
	_coin_chip = PanelContainer.new()
	_coin_chip.name = "CoinBalance"
	_coin_chip.custom_minimum_size = Vector2(126, 46)
	_coin_chip.add_theme_stylebox_override("panel", hud._glass_panel_style(UI_TOKENS.COLOR_GOLD, UI_TOKENS.RADIUS_LG, 0.72))
	hud.main_menu.coin_slot.add_child(_coin_chip)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", UI_TOKENS.SPACE_SM)
	_coin_chip.add_child(row)
	_coin_icon = Control.new()
	_coin_icon.name = "CoinMark"
	_coin_icon.custom_minimum_size = Vector2(30, 30)
	_coin_icon.set_script(COIN_ICON_SCRIPT)
	row.add_child(_coin_icon)
	_coin_balance_label = Label.new()
	_coin_balance_label.name = "CoinValue"
	_coin_balance_label.add_theme_font_size_override("font_size", 23)
	_coin_balance_label.add_theme_color_override("font_color", UI_TOKENS.COLOR_TEXT)
	row.add_child(_coin_balance_label)
	var open_shop := Button.new()
	open_shop.name = "OpenShop"
	open_shop.set_anchors_preset(Control.PRESET_FULL_RECT)
	open_shop.flat = true
	open_shop.focus_mode = Control.FOCUS_NONE
	open_shop.tooltip_text = "Open the Blob Shop"
	open_shop.pressed.connect(_set_progression_open.bind("shop"))
	_coin_chip.add_child(open_shop)
	_update_coin_label()


## Today's dailies live on the menu's quest card; the HUD fills it because it
## owns the Progression wiring and the claim flow.
func _create_quest_panel() -> void:
	_quest_panel = hud.main_menu.quest_card
	_quest_list = hud.main_menu.quest_card.content
	_refresh_quest_panel()


## `fill_in` grows each bar from empty, timed to land after the menu intro.
func _refresh_quest_panel(fill_in := false) -> void:
	if _quest_list == null or _progression == null:
		return
	for child in _quest_list.get_children():
		_quest_list.remove_child(child)
		child.queue_free()
	var daily_quests := _progression.get("daily_quests") as Array
	var claimed_count := 0
	for quest_value in daily_quests:
		if bool((quest_value as Dictionary).get("claimed", false)):
			claimed_count += 1
	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quest_list.add_child(header)
	var title := Label.new()
	title.text = "TODAY  ·  %d / %d COMPLETE" % [claimed_count, daily_quests.size()]
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.5))
	header.add_child(title)
	_quest_reset_label = Label.new()
	_quest_reset_label.add_theme_font_size_override("font_size", 10)
	_quest_reset_label.add_theme_color_override("font_color", Color(0.58, 0.66, 0.76))
	header.add_child(_quest_reset_label)
	_update_quest_reset_label()
	if daily_quests.is_empty():
		var empty := Label.new()
		empty.text = "All daily quests complete"
		empty.add_theme_color_override("font_color", UI_TOKENS.COLOR_MUTED)
		_quest_list.add_child(empty)
	for index in daily_quests.size():
		_quest_list.add_child(_make_menu_quest_row(daily_quests[index] as Dictionary, fill_in, 0.6 + 0.1 * index))
	hud._apply_ui_font_tree(_quest_list)


func _make_menu_quest_row(quest: Dictionary, fill_in: bool, fill_delay: float) -> Control:
	var claimed := bool(quest.get("claimed", false))
	var completed := bool(quest.get("completed", false)) or claimed
	var target := maxi(1, int(quest.get("target", 1)))
	var progress := mini(target, int(quest.get("progress", 0)))
	var accent := Color(0.38, 1.0, 0.6) if claimed else (UI_TOKENS.COLOR_GOLD if completed else Color(0.25, 0.68, 1.0))
	var row := VBoxContainer.new()
	row.name = "Quest_%s" % str(quest.get("id", ""))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 4)
	var line := HBoxContainer.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.add_theme_constant_override("separation", 8)
	row.add_child(line)
	var objective := Label.new()
	objective.text = str(quest.get("title", ""))
	objective.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	objective.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	objective.add_theme_font_size_override("font_size", 14)
	objective.add_theme_color_override("font_color", UI_TOKENS.COLOR_MUTED if claimed else UI_TOKENS.COLOR_TEXT)
	line.add_child(objective)
	if completed and not claimed:
		var claim := Button.new()
		claim.name = "Claim"
		claim.text = "CLAIM +%d" % int(quest.get("reward", 0))
		claim.focus_mode = Control.FOCUS_NONE
		claim.custom_minimum_size = Vector2(0, 26)
		claim.add_theme_font_size_override("font_size", 11)
		hud._apply_primary_shop_button_style(claim, UI_TOKENS.COLOR_GOLD)
		claim.pressed.connect(func() -> void:
			_claim_quest("daily", str(quest.get("id", "")), claim)
			_refresh_quest_panel()
		)
		PROGRESSION_FX.breathe(claim, 0.16)
		line.add_child(claim)
	else:
		var reward := Label.new()
		reward.text = "✓" if claimed else "+%d" % int(quest.get("reward", 0))
		reward.add_theme_font_size_override("font_size", 12)
		reward.add_theme_color_override("font_color", accent)
		line.add_child(reward)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 6)
	bar.show_percentage = false
	bar.max_value = target
	bar.value = progress
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override("background", hud._progress_style(Color(0.025, 0.035, 0.07), Color(0.12, 0.2, 0.34)))
	var fill := hud._progress_style(accent, Color.TRANSPARENT)
	fill.shadow_color = Color(accent, 0.4)
	fill.shadow_size = 4
	bar.add_theme_stylebox_override("fill", fill)
	row.add_child(bar)
	if fill_in:
		PROGRESSION_FX.fill_bar(bar, 0.0, fill_delay)
	return row


func _create_shop_overlay() -> void:
	_shop_overlay = Control.new()
	_shop_overlay.name = "ShopOverlay"
	_shop_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shop_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_shop_overlay.visible = false
	hud.add_child(_shop_overlay)
	var shade := ColorRect.new()
	shade.name = "DrawerBackdrop"
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Product rule: the shop and quest board are translucent drawers over the
	# live lobby, not full-screen pages - the backdrop and shell both stay
	# see-through and the drawer keeps a safe margin on every edge.
	shade.color = Color(0.004, 0.008, 0.018, 0.6)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.gui_input.connect(_on_progression_backdrop_input)
	_shop_overlay.add_child(shade)
	_shop_shell = PanelContainer.new()
	_shop_shell.name = "ProgressionDrawer"
	var shell_style := hud._elevated_panel_style(Color(0.012, 0.02, 0.042, 0.88), Color(0.34, 0.64, 1.0, 0.5), 26, Color(0.0, 0.0, 0.0, 0.6))
	shell_style.shadow_size = 28
	shell_style.shadow_offset = Vector2(0, 12)
	shell_style.content_margin_left = 24
	shell_style.content_margin_top = 18
	shell_style.content_margin_right = 24
	shell_style.content_margin_bottom = 22
	_shop_shell.add_theme_stylebox_override("panel", shell_style)
	_shop_overlay.add_child(_shop_shell)
	_shop_content = VBoxContainer.new()
	_shop_content.add_theme_constant_override("separation", 16)
	_shop_shell.add_child(_shop_content)
	_shop_content.add_child(_build_drawer_header())
	_drawer_body = VBoxContainer.new()
	_drawer_body.name = "DrawerBody"
	_drawer_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_drawer_body.add_theme_constant_override("separation", 12)
	_shop_content.add_child(_drawer_body)
	_fit_progression_drawer()


## Title, the Shop / Quests switch, the balance, and close. Built once and kept
## while the drawer lives, so the page switch can slide instead of snapping.
func _build_drawer_header() -> Control:
	var header := HBoxContainer.new()
	header.name = "DrawerHeader"
	header.custom_minimum_size = Vector2(0, 52)
	header.add_theme_constant_override("separation", 14)
	var title_stack := VBoxContainer.new()
	title_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	title_stack.add_theme_constant_override("separation", 0)
	header.add_child(title_stack)
	_drawer_title = _drawer_label("", 28, UI_TOKENS.COLOR_TEXT)
	_drawer_title.name = "DrawerTitle"
	title_stack.add_child(_drawer_title)
	_drawer_subtitle = _drawer_label("", 10, Color(0.47, 0.64, 0.88))
	_drawer_subtitle.name = "DrawerSubtitle"
	_drawer_subtitle.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_stack.add_child(_drawer_subtitle)
	_drawer_page_tabs = MENU_SEGMENTED.new("DrawerPages", UI_TOKENS.COLOR_CYAN)
	_drawer_page_tabs.custom_minimum_size = Vector2(210, 40)
	_drawer_page_tabs.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_drawer_page_tabs.set_options(["SHOP", "QUESTS"], 0)
	_drawer_page_tabs.selection_changed.connect(func(index: int) -> void: _switch_progression_page("shop" if index == 0 else "quests"))
	header.add_child(_drawer_page_tabs)
	_drawer_balance_chip = PanelContainer.new()
	_drawer_balance_chip.name = "DrawerBalance"
	_drawer_balance_chip.custom_minimum_size = Vector2(128, 42)
	_drawer_balance_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var chip_style := hud._glass_panel_style(UI_TOKENS.COLOR_GOLD, 21, 0.74)
	chip_style.content_margin_left = 12
	chip_style.content_margin_right = 16
	chip_style.content_margin_top = 6
	chip_style.content_margin_bottom = 6
	_drawer_balance_chip.add_theme_stylebox_override("panel", chip_style)
	header.add_child(_drawer_balance_chip)
	var balance_row := HBoxContainer.new()
	balance_row.alignment = BoxContainer.ALIGNMENT_CENTER
	balance_row.add_theme_constant_override("separation", 8)
	_drawer_balance_chip.add_child(balance_row)
	balance_row.add_child(_coin_mark(22.0))
	_drawer_balance_label = _drawer_label("0", 20, UI_TOKENS.COLOR_TEXT)
	_drawer_balance_label.name = "DrawerBalanceValue"
	balance_row.add_child(_drawer_balance_label)
	var close := Button.new()
	close.name = "CloseDrawer"
	close.text = "✕"
	close.tooltip_text = "Close  (Esc)"
	close.custom_minimum_size = Vector2(42, 42)
	close.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close.focus_mode = Control.FOCUS_NONE
	close.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	close.add_theme_font_size_override("font_size", 16)
	hud._apply_utility_button_style(close, UI_TOKENS.COLOR_CYAN)
	close.pressed.connect(close_progression)
	PROGRESSION_FX.springy(close)
	header.add_child(close)
	return header


func _fit_progression_drawer() -> void:
	if _shop_shell == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	# Capped at roughly 70% x 83% of the 1280x720 reference so the lobby stays
	# visible around the drawer, and never closer than 24px to any edge.
	var drawer_size := Vector2(
		minf(900.0, viewport_size.x - 48.0),
		minf(600.0, viewport_size.y - 48.0)
	)
	drawer_size.x = maxf(drawer_size.x, minf(360.0, viewport_size.x - 48.0))
	drawer_size.y = maxf(drawer_size.y, minf(520.0, viewport_size.y - 48.0))
	_drawer_size = drawer_size
	_shop_shell.anchor_left = 0.5
	_shop_shell.anchor_top = 0.5
	_shop_shell.anchor_right = 0.5
	_shop_shell.anchor_bottom = 0.5
	_shop_shell.offset_left = -drawer_size.x * 0.5
	_shop_shell.offset_top = -drawer_size.y * 0.5
	_shop_shell.offset_right = drawer_size.x * 0.5
	_shop_shell.offset_bottom = drawer_size.y * 0.5
	_shop_shell.pivot_offset = drawer_size * 0.5


func _on_progression_backdrop_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		_set_shop_open(false)


func _set_progression_open(page: String) -> void:
	if _shop_overlay == null:
		return
	var opening := not _shop_overlay.visible or _progression_closing
	_active_progression_page = page
	_progression_closing = false
	_shop_overlay.visible = true
	# The drawer shows its own balance; never two coin counters at once.
	if _coin_chip != null:
		_coin_chip.visible = false
	if opening:
		_drawer_shown_balance = int(_progression.call("get_balance"))
		_drawer_balance_label.text = "%d" % _drawer_shown_balance
		_play_drawer_transition(true)
	_refresh_drawer_header()
	_build_progression(true)
	hud._apply_ui_font_tree(_shop_content)
	get_tree().paused = false


func _set_shop_open(open: bool) -> void:
	if open:
		_set_progression_open("shop")
		return
	if _shop_overlay == null or not _shop_overlay.visible or _progression_closing:
		return
	_progression_closing = true
	if _coin_chip != null:
		_coin_chip.visible = true
	if hud._lobby_mode_active:
		# The loadout may have changed while the drawer was open.
		hud._refresh_menu_identity()
		_refresh_quest_panel()
	_play_drawer_transition(false)


## Closes without the exit animation, for a mode change that takes the menu
## away underneath the drawer.
func _hide_progression_now() -> void:
	if _shop_overlay == null or not _shop_overlay.visible:
		return
	if _drawer_tween != null and _drawer_tween.is_valid():
		_drawer_tween.kill()
	_finish_drawer_close()
	if _coin_chip != null:
		_coin_chip.visible = true


## Opening: the backdrop fades up while the drawer scales in from 94% with a
## small overshoot. Closing runs a quicker reverse, then hides. Scale and
## alpha only, around the drawer's centre, so it never leaves its safe margin.
func _play_drawer_transition(opening: bool) -> void:
	if _drawer_tween != null and _drawer_tween.is_valid():
		_drawer_tween.kill()
	var backdrop := _shop_overlay.get_node("DrawerBackdrop") as ColorRect
	_shop_shell.pivot_offset = _shop_shell.size * 0.5
	if hud._reduced_motion:
		backdrop.modulate.a = 1.0
		_shop_shell.modulate.a = 1.0
		_shop_shell.scale = Vector2.ONE
		if not opening:
			_finish_drawer_close()
		return
	_drawer_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	if opening:
		backdrop.modulate.a = 0.0
		_shop_shell.modulate.a = 0.0
		_shop_shell.scale = Vector2.ONE * 0.94
		_drawer_tween.tween_property(backdrop, "modulate:a", 1.0, 0.22)
		_drawer_tween.tween_property(_shop_shell, "modulate:a", 1.0, 0.18)
		_drawer_tween.tween_property(_shop_shell, "scale", Vector2.ONE, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		return
	_drawer_tween.tween_property(backdrop, "modulate:a", 0.0, 0.18)
	_drawer_tween.tween_property(_shop_shell, "modulate:a", 0.0, 0.14)
	_drawer_tween.tween_property(_shop_shell, "scale", Vector2.ONE * 0.96, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_drawer_tween.chain().tween_callback(_finish_drawer_close)


func _finish_drawer_close() -> void:
	_progression_closing = false
	_shop_overlay.visible = false
	_shop_shell.scale = Vector2.ONE
	_shop_shell.modulate.a = 1.0
	(_shop_overlay.get_node("DrawerBackdrop") as ColorRect).modulate.a = 1.0
	# Nothing in a hidden drawer should keep running: the model preview owns a
	# SubViewport, and modals or coins in flight belong to the closed session.
	_clear_children(_drawer_body)
	for child in _shop_overlay.get_children():
		if child.name != &"DrawerBackdrop" and child != _shop_shell:
			child.queue_free()


func _switch_progression_page(page: String) -> void:
	if page == _active_progression_page:
		return
	_active_progression_page = page
	_refresh_drawer_header()
	PROGRESSION_FX.pop_in(_drawer_title, 0.0, 0.9)
	_build_progression(true)


func _refresh_drawer_header() -> void:
	var shop := _active_progression_page == "shop"
	_drawer_title.text = "BLOB SHOP" if shop else "QUEST BOARD"
	_drawer_subtitle.text = _shop_collection_copy() if shop else "PLAY  ·  PROGRESS  ·  GET PAID"
	_drawer_page_tabs.select(0 if shop else 1)


func _count_drawer_balance(balance: int) -> void:
	if _drawer_balance_label == null:
		return
	PROGRESSION_FX.count_label(_drawer_balance_label, _drawer_shown_balance, balance, "%d")
	_drawer_shown_balance = balance


func _shop_collection_copy() -> String:
	var owned_total := 0
	var item_total := 0
	for category_row in SHOP_CATEGORIES:
		for item_value in _progression.call("get_items", str(category_row[0])) as Array:
			item_total += 1
			if bool(_progression.call("is_owned", str((item_value as Dictionary).get("id", "")))):
				owned_total += 1
	return "BUILD YOUR BLOB  ·  %d / %d OWNED" % [owned_total, item_total]


## Rebuilds the page under the header. `intro` replays the staggered entrance;
## a refresh after a purchase or claim passes false so nothing re-pops.
func _build_progression(intro := false) -> void:
	if _drawer_body == null:
		return
	_clear_children(_drawer_body)
	if _active_progression_page == "quests":
		_build_quest_board(intro)
	else:
		_build_shop_workspace(intro)
	hud._apply_ui_font_tree(_drawer_body)


func _clear_children(parent: Node) -> void:
	if parent == null:
		return
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()


## Shop: categories and the item grid on the left, the selected item on the
## real in-game blob on the right. Switching category or item rebuilds only
## the grid or the spotlight, so the category pill can glide between tabs.
func _build_shop_workspace(intro: bool) -> void:
	var workspace := HBoxContainer.new()
	workspace.name = "ShopWorkspace"
	workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace.add_theme_constant_override("separation", 16)
	_drawer_body.add_child(workspace)
	var browse := VBoxContainer.new()
	browse.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	browse.add_theme_constant_override("separation", 10)
	workspace.add_child(browse)
	var categories := MENU_SEGMENTED.new("ShopCategories", UI_TOKENS.COLOR_CYAN)
	categories.font_size = 11
	var labels: Array = []
	var selected_index := 0
	for index in SHOP_CATEGORIES.size():
		labels.append(SHOP_CATEGORIES[index][1])
		if SHOP_CATEGORIES[index][0] == _active_shop_category:
			selected_index = index
	categories.set_options(labels, selected_index)
	categories.selection_changed.connect(_on_shop_category_selected)
	browse.add_child(categories)
	_shop_section_label = _drawer_label("", 10, Color(0.5, 0.62, 0.8))
	browse.add_child(_shop_section_label)
	_shop_scroll = ScrollContainer.new()
	_shop_scroll.name = "ShopScroll"
	_shop_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_shop_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	browse.add_child(_shop_scroll)
	var gutter := MarginContainer.new()
	gutter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Room for the cards' hover glow and pop, which the scroll clip would cut.
	gutter.add_theme_constant_override("margin_left", 20)
	gutter.add_theme_constant_override("margin_top", 18)
	gutter.add_theme_constant_override("margin_right", 20)
	gutter.add_theme_constant_override("margin_bottom", 20)
	_shop_scroll.add_child(gutter)
	_shop_grid = GridContainer.new()
	_shop_grid.name = "ShopGrid"
	_shop_grid.columns = _shop_grid_columns()
	_shop_grid.add_theme_constant_override("h_separation", 12)
	_shop_grid.add_theme_constant_override("v_separation", 12)
	gutter.add_child(_shop_grid)
	_shop_spotlight_slot = VBoxContainer.new()
	_shop_spotlight_slot.name = "SpotlightSlot"
	_shop_spotlight_slot.custom_minimum_size = Vector2(SHOP_SPOTLIGHT_WIDTH, 0)
	workspace.add_child(_shop_spotlight_slot)
	_fill_shop_grid(intro)
	_fill_shop_spotlight(intro)


## Column count follows the drawer, not the window: the drawer is capped well
## below the viewport width, so a window-based count would overflow it.
func _shop_grid_columns() -> int:
	var available := _drawer_size.x - 48.0 - 16.0 - SHOP_SPOTLIGHT_WIDTH - 52.0
	return clampi(int((available + 12.0) / (SHOP_CARD_SIZE.x + 12.0)), 1, 3)


func _on_shop_category_selected(index: int) -> void:
	_active_shop_category = str(SHOP_CATEGORIES[index][0])
	_selected_shop_item = {}
	_shop_scroll.scroll_vertical = 0
	_fill_shop_grid(true)
	_fill_shop_spotlight(true)
	hud._apply_ui_font_tree(_drawer_body)


func _fill_shop_grid(intro: bool) -> void:
	_clear_children(_shop_grid)
	var items := _progression.call("get_items", _active_shop_category) as Array
	var owned_count := 0
	var selection_valid := false
	var equipped_id := str(_progression.call("get_equipped", _active_shop_category))
	var equipped_item: Dictionary = {}
	for item_value in items:
		var item := item_value as Dictionary
		var item_id := str(item.get("id", ""))
		if bool(_progression.call("is_owned", item_id)):
			owned_count += 1
		if item_id == str(_selected_shop_item.get("id", "")):
			selection_valid = true
		if item_id == equipped_id:
			equipped_item = item
	for category_row in SHOP_CATEGORIES:
		if category_row[0] == _active_shop_category:
			_shop_section_label.text = "%s  ·  %d / %d OWNED" % [category_row[1], owned_count, items.size()]
	# Opening a category shows what the blob wears right now.
	if not selection_valid:
		_selected_shop_item = equipped_item if not equipped_item.is_empty() else (items[0] as Dictionary if not items.is_empty() else {})
	for index in items.size():
		var card := _make_shop_item(_active_shop_category, items[index] as Dictionary)
		_shop_grid.add_child(card)
		if intro:
			card.play_intro(minf(0.035 * index, 0.42))


func _fill_shop_spotlight(intro: bool) -> void:
	_clear_children(_shop_spotlight_slot)
	var panel := _make_preview_panel(_active_shop_category, _selected_shop_item)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_shop_spotlight_slot.add_child(panel)
	if intro:
		PROGRESSION_FX.pop_in(panel, 0.04, 0.97)


func _shop_spotlight() -> Control:
	if _shop_spotlight_slot == null or not is_instance_valid(_shop_spotlight_slot) or _shop_spotlight_slot.get_child_count() == 0:
		return null
	return _shop_spotlight_slot.get_child(0) as Control


## One item tile. The whole card is the tap target (a MenuCard hit Button
## named CardHitTarget); it glows in its rarity colour while selected.
func _make_shop_item(category: String, item: Dictionary) -> MenuCard:
	var item_id := str(item.get("id", ""))
	var rarity := str(item.get("rarity", "Common"))
	var rarity_color: Color = RARITY_COLORS.get(rarity, Color.WHITE)
	var price := int(item.get("price", 0))
	var balance := int(_progression.call("get_balance"))
	var owned := bool(_progression.call("is_owned", item_id))
	var equipped := str(_progression.call("get_equipped", category)) == item_id
	var card := MENU_CARD.new("ShopItem_%s" % item_id, rarity_color, true, Vector4(10, 10, 10, 12), 0.2)
	card.custom_minimum_size = SHOP_CARD_SIZE
	card.set_reduced_motion(hud._reduced_motion)
	card.set_action_name("CardHitTarget", "Preview %s" % str(item.get("name", "item")))
	card.set_highlighted(item_id == str(_selected_shop_item.get("id", "")))
	card.pressed.connect(_select_shop_item.bind(item.duplicate(true)))
	card.content.add_theme_constant_override("separation", 6)
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(0, 100)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame_style := hud._panel_style(Color(0.008, 0.016, 0.04, 0.72), Color(rarity_color, 0.24), 12)
	frame_style.content_margin_left = 0
	frame_style.content_margin_top = 0
	frame_style.content_margin_right = 0
	frame_style.content_margin_bottom = 0
	frame.add_theme_stylebox_override("panel", frame_style)
	card.content.add_child(frame)
	var thumbnail := Control.new()
	thumbnail.name = "ItemPreview_%s" % item_id
	thumbnail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thumbnail.set_script(SHOP_CARD_PREVIEW_SCRIPT)
	thumbnail.call("set_item", category, item, rarity_color)
	frame.add_child(thumbnail)
	var tags := HBoxContainer.new()
	tags.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.content.add_child(tags)
	var rarity_label := _drawer_label(rarity.to_upper(), 9, rarity_color)
	rarity_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tags.add_child(rarity_label)
	if owned:
		tags.add_child(_drawer_label("EQUIPPED" if equipped else "OWNED", 9, SHOP_MINT if equipped else Color(0.6, 0.7, 0.84)))
	var name_label := _drawer_label(str(item.get("name", "Item")), 16, UI_TOKENS.COLOR_TEXT)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	card.content.add_child(name_label)
	var price_row := HBoxContainer.new()
	price_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	price_row.add_theme_constant_override("separation", 6)
	card.content.add_child(price_row)
	if owned:
		price_row.add_child(_drawer_label("✓  ON YOUR BLOB" if equipped else "✓  IN YOUR LOCKER", 11, SHOP_MINT if equipped else UI_TOKENS.COLOR_MUTED))
		return card
	var affordable := balance >= price
	price_row.add_child(_coin_mark(16.0))
	price_row.add_child(_drawer_label("%d" % price, 14, UI_TOKENS.COLOR_GOLD if affordable else SHOP_SHORT))
	if not affordable:
		var need := _drawer_label("NEED %d" % (price - balance), 9, Color(SHOP_SHORT, 0.8))
		need.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		need.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		price_row.add_child(need)
	return card


## The selected item on the real in-game blob, its story, and one action.
func _make_preview_panel(category: String, item: Dictionary) -> PanelContainer:
	var rarity := str(item.get("rarity", "Common"))
	var accent: Color = RARITY_COLORS.get(rarity, Color.WHITE)
	var panel := PanelContainer.new()
	panel.name = "ItemSpotlight"
	var panel_style := hud._elevated_panel_style(Color(0.02, 0.034, 0.072, 0.9), Color(accent, 0.55), 20, Color(accent, 0.2))
	panel_style.shadow_size = 18
	panel_style.content_margin_left = 14
	panel_style.content_margin_top = 12
	panel_style.content_margin_right = 14
	panel_style.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", panel_style)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 6)
	panel.add_child(stack)
	var eyebrow := HBoxContainer.new()
	stack.add_child(eyebrow)
	eyebrow.add_theme_constant_override("separation", 7)
	var live_dot := Panel.new()
	live_dot.custom_minimum_size = Vector2(7, 7)
	live_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	live_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dot_style := StyleBoxFlat.new()
	dot_style.bg_color = SHOP_MINT
	dot_style.set_corner_radius_all(4)
	dot_style.shadow_color = Color(SHOP_MINT, 0.6)
	dot_style.shadow_size = 4
	live_dot.add_theme_stylebox_override("panel", dot_style)
	PROGRESSION_FX.breathe(live_dot, -0.55)
	eyebrow.add_child(live_dot)
	var live := _drawer_label("LIVE PREVIEW", 10, SHOP_MINT)
	live.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	eyebrow.add_child(live)
	eyebrow.add_child(_drawer_label("DRAG TO ROTATE", 9, Color(0.43, 0.58, 0.78)))
	var preview := SubViewportContainer.new()
	preview.name = "RealModelPreview"
	# Shorter drawers (small windows) give the model less room, never the copy.
	preview.custom_minimum_size = Vector2(0, clampf(_drawer_size.y - 420.0, 124.0, 196.0))
	preview.set_script(SHOP_MODEL_PREVIEW_SCRIPT)
	preview.call("set_item", category, item, accent)
	stack.add_child(preview)
	if category in ["abilities", "kill_effects"]:
		var replay := Button.new()
		replay.text = "REPLAY EFFECT" if category == "kill_effects" else "REPLAY PREVIEW"
		replay.custom_minimum_size = Vector2(0, 30)
		replay.focus_mode = Control.FOCUS_NONE
		replay.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		replay.add_theme_font_size_override("font_size", 11)
		hud._apply_utility_button_style(replay, accent)
		replay.pressed.connect(func() -> void: preview.call("replay"))
		PROGRESSION_FX.springy(replay)
		stack.add_child(replay)
	var name_label := _drawer_label(str(item.get("name", "Select an item")), 22, UI_TOKENS.COLOR_TEXT)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(name_label)
	var meta_row := HBoxContainer.new()
	stack.add_child(meta_row)
	var rarity_label := _drawer_label(rarity.to_upper(), 11, accent)
	rarity_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meta_row.add_child(rarity_label)
	meta_row.add_child(_drawer_label(str(SHOP_ITEM_KINDS.get(category, category.to_upper())), 10, Color(0.43, 0.58, 0.78)))
	var tagline := _drawer_label(str(item.get("tagline", "Make the arena yours.")), 13, Color(0.84, 0.91, 1.0))
	tagline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack.add_child(tagline)
	var description := _drawer_label(str(item.get("description", "A cosmetic that makes your Blob unmistakable.")), 12, Color(0.66, 0.75, 0.88))
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.max_lines_visible = 3
	description.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.add_child(description)
	stack.add_child(_make_spotlight_action(category, item))
	return panel


func _make_spotlight_action(category: String, item: Dictionary) -> Button:
	var item_id := str(item.get("id", ""))
	var price := int(item.get("price", 0))
	var owned := bool(_progression.call("is_owned", item_id))
	var equipped := str(_progression.call("get_equipped", category)) == item_id
	var affordable := int(_progression.call("get_balance")) >= price
	var action := Button.new()
	action.name = "SpotlightAction"
	action.custom_minimum_size = Vector2(0, 46)
	action.focus_mode = Control.FOCUS_NONE
	action.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	hud._apply_primary_shop_button_style(action, SHOP_MINT if owned else UI_TOKENS.COLOR_GOLD)
	if equipped:
		action.text = "✓  EQUIPPED"
		action.disabled = true
		hud._apply_settled_button_style(action, SHOP_MINT)
	elif owned:
		action.text = "EQUIP"
	elif affordable:
		action.text = "BUY  ·  %d COINS" % price
		PROGRESSION_FX.breathe(action, 0.14)
	else:
		action.text = "NEED %d MORE COINS" % (price - int(_progression.call("get_balance")))
		action.disabled = true
		action.tooltip_text = "Win matches and claim quests to earn Coins"
	action.pressed.connect(_handle_shop_action.bind(category, item.duplicate(true)))
	PROGRESSION_FX.springy(action)
	return action


func _select_shop_item(item: Dictionary) -> void:
	var item_id := str(item.get("id", ""))
	if item_id == str(_selected_shop_item.get("id", "")):
		return
	_selected_shop_item = item
	if _shop_grid != null and is_instance_valid(_shop_grid):
		for card in _shop_grid.get_children():
			(card as MenuCard).set_highlighted(str(card.name) == "ShopItem_%s" % item_id)
	_fill_shop_spotlight(true)
	hud._apply_ui_font_tree(_shop_spotlight_slot)


func _handle_shop_action(category: String, item: Dictionary) -> void:
	var item_id := str(item.get("id", ""))
	if bool(_progression.call("is_owned", item_id)):
		# equip() raises inventory_changed, which rebuilds the page.
		if bool(_progression.call("equip", category, item_id)):
			_show_progression_toast("EQUIPPED", str(item.get("name", "")))
			PROGRESSION_FX.punch(_shop_spotlight(), 1.04)
		return
	_show_purchase_confirm(category, item)


func _show_purchase_confirm(category: String, item: Dictionary) -> void:
	if _shop_overlay == null:
		return
	var rarity_color: Color = RARITY_COLORS.get(str(item.get("rarity", "Common")), UI_TOKENS.COLOR_GOLD)
	var balance := int(_progression.call("get_balance"))
	var price := int(item.get("price", 0))
	var remaining := balance - price
	var modal := Control.new()
	modal.name = "PurchaseModal"
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	_shop_overlay.add_child(modal)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.0, 0.008, 0.024, 0.62)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.gui_input.connect(_cancel_purchase_modal.bind(modal))
	modal.add_child(shade)
	modal.gui_input.connect(_cancel_purchase_modal.bind(modal))
	var panel := PanelContainer.new()
	panel.name = "PurchaseDialog"
	# Centred by anchors and offsets; an absolute position here measured from
	# the screen's top-left and pushed the dialog off screen.
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -210
	panel.offset_right = 210
	panel.offset_top = -186
	panel.offset_bottom = 186
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.pivot_offset = Vector2(210, 186)
	var panel_style := hud._elevated_panel_style(Color(0.03, 0.045, 0.09, 0.97), Color(rarity_color, 0.8), 22, Color(rarity_color, 0.32))
	panel_style.shadow_size = 26
	panel_style.content_margin_left = 22
	panel_style.content_margin_right = 22
	panel_style.content_margin_top = 18
	panel_style.content_margin_bottom = 20
	panel.add_theme_stylebox_override("panel", panel_style)
	modal.add_child(panel)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	panel.add_child(stack)
	var eyebrow := _drawer_label("UNLOCK  ·  %s" % str(item.get("rarity", "Common")).to_upper(), 10, rarity_color)
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(eyebrow)
	var title := _drawer_label(str(item.get("name", "Item")), 24, UI_TOKENS.COLOR_TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(title)
	var thumbnail := Control.new()
	thumbnail.custom_minimum_size = Vector2(0, 118)
	thumbnail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thumbnail.set_script(SHOP_CARD_PREVIEW_SCRIPT)
	thumbnail.call("set_item", category, item, rarity_color)
	stack.add_child(thumbnail)
	var price_row := HBoxContainer.new()
	price_row.alignment = BoxContainer.ALIGNMENT_CENTER
	price_row.add_theme_constant_override("separation", 8)
	stack.add_child(price_row)
	price_row.add_child(_coin_mark(26.0))
	price_row.add_child(_drawer_label("%d" % price, 26, UI_TOKENS.COLOR_GOLD))
	var after := _drawer_label("%d  →  %d AFTER PURCHASE" % [balance, remaining] if remaining >= 0 else "NEED %d MORE COINS" % absi(remaining), 11, UI_TOKENS.COLOR_MUTED if remaining >= 0 else SHOP_SHORT)
	after.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(after)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 12)
	stack.add_child(actions)
	var cancel := Button.new()
	cancel.text = "CANCEL"
	cancel.custom_minimum_size = Vector2(150, 44)
	cancel.focus_mode = Control.FOCUS_NONE
	hud._apply_utility_button_style(cancel, Color(0.68, 0.74, 0.84))
	cancel.pressed.connect(_dismiss_purchase_modal.bind(modal))
	PROGRESSION_FX.springy(cancel)
	actions.add_child(cancel)
	var confirm := Button.new()
	confirm.text = "BUY & EQUIP"
	confirm.custom_minimum_size = Vector2(150, 44)
	confirm.focus_mode = Control.FOCUS_NONE
	confirm.disabled = remaining < 0
	confirm.tooltip_text = "Earn %d more Coins to unlock this item" % absi(remaining) if confirm.disabled else ""
	hud._apply_primary_shop_button_style(confirm, UI_TOKENS.COLOR_GOLD)
	confirm.pressed.connect(_confirm_purchase.bind(category, item, modal))
	PROGRESSION_FX.springy(confirm)
	if not confirm.disabled:
		PROGRESSION_FX.breathe(confirm, 0.14)
	actions.add_child(confirm)
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null:
		audio.call("wire_ui_sounds", modal)
	hud._apply_ui_font_tree(modal)
	if hud._reduced_motion:
		return
	shade.modulate.a = 0.0
	panel.modulate.a = 0.0
	panel.scale = Vector2.ONE * 0.88
	var tween := modal.create_tween().set_parallel(true)
	tween.tween_property(shade, "modulate:a", 1.0, 0.16)
	tween.tween_property(panel, "modulate:a", 1.0, 0.14)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Coins leave the balance and pour into the item that was just bought.
func _confirm_purchase(category: String, item: Dictionary, modal: Control) -> void:
	var from := _drawer_balance_chip.get_global_rect().get_center()
	# purchase() raises balance_changed (the header counts down) and
	# inventory_changed (the page rebuilds with the item owned and equipped).
	if not bool(_progression.call("purchase", category, str(item.get("id", "")))):
		return
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null:
		audio.call("play_sfx", &"purchase", -7.0, 1.08)
	_show_progression_toast("ITEM PURCHASED", str(item.get("name", "")))
	_dismiss_purchase_modal(modal)
	var spotlight := _shop_spotlight()
	if spotlight != null:
		PROGRESSION_FX.coin_burst(_shop_overlay, from, spotlight.get_global_rect().get_center(), 7, PROGRESSION_FX.punch.bind(spotlight, 1.05))


func _dismiss_purchase_modal(modal: Control) -> void:
	if not is_instance_valid(modal) or modal.is_queued_for_deletion():
		return
	modal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if hud._reduced_motion:
		modal.queue_free()
		return
	var tween := modal.create_tween()
	tween.tween_property(modal, "modulate:a", 0.0, 0.12)
	tween.tween_callback(modal.queue_free)


func _cancel_purchase_modal(event: InputEvent, modal: Control) -> void:
	if not is_instance_valid(modal):
		return
	var click := event as InputEventMouseButton
	if (click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT) or event.is_action_pressed("ui_cancel"):
		_dismiss_purchase_modal(modal)


## Quests: the Daily / Weekly switch and reset timer stay put; the summary
## and the objective list below them rebuild when the tab changes.
func _build_quest_board(intro: bool) -> void:
	var toolbar := HBoxContainer.new()
	toolbar.name = "QuestToolbar"
	toolbar.add_theme_constant_override("separation", 12)
	_drawer_body.add_child(toolbar)
	var tabs := MENU_SEGMENTED.new("QuestTabs", UI_TOKENS.COLOR_GOLD)
	tabs.custom_minimum_size = Vector2(240, 38)
	tabs.set_options(["DAILY", "WEEKLY"], 1 if _quests_showing_weekly else 0)
	tabs.selection_changed.connect(func(index: int) -> void: _set_quest_tab(index == 1))
	toolbar.add_child(tabs)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(spacer)
	_board_reset_label = _drawer_label("", 11, Color(0.6, 0.7, 0.84))
	_board_reset_label.name = "QuestResetTimer"
	_board_reset_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_board_reset_label.size_flags_vertical = Control.SIZE_FILL
	toolbar.add_child(_board_reset_label)
	_update_quest_reset_label()
	_quest_board_slot = VBoxContainer.new()
	_quest_board_slot.name = "QuestBoard"
	_quest_board_slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_quest_board_slot.add_theme_constant_override("separation", 12)
	_drawer_body.add_child(_quest_board_slot)
	_fill_quest_board(intro)


func _fill_quest_board(intro: bool) -> void:
	_clear_children(_quest_board_slot)
	var quests := _active_quests()
	var claimed_count := 0
	var ready_count := 0
	var ready_coins := 0
	for quest_value in quests:
		var quest := quest_value as Dictionary
		if bool(quest.get("claimed", false)):
			claimed_count += 1
		elif bool(quest.get("completed", false)):
			ready_count += 1
			ready_coins += int(quest.get("reward", 0))
	_quest_board_slot.add_child(_make_quest_summary(quests.size(), claimed_count, ready_count, ready_coins, intro))
	var scroll := ScrollContainer.new()
	scroll.name = "QuestScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_quest_board_slot.add_child(scroll)
	var scroll_gutter := MarginContainer.new()
	scroll_gutter.name = "QuestScrollGutter"
	scroll_gutter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Wide enough for a ready card's glow and for the scrollbar on the right.
	scroll_gutter.add_theme_constant_override("margin_left", 18)
	scroll_gutter.add_theme_constant_override("margin_top", 16)
	scroll_gutter.add_theme_constant_override("margin_right", 22)
	scroll_gutter.add_theme_constant_override("margin_bottom", 18)
	scroll.add_child(scroll_gutter)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll_gutter.add_child(list)
	if quests.is_empty():
		list.add_child(_drawer_label("No objectives right now. A fresh set arrives at the reset.", 13, UI_TOKENS.COLOR_MUTED))
	for index in quests.size():
		var card := _make_quest_card(quests[index] as Dictionary, intro, 0.12 + 0.07 * index)
		list.add_child(card)
		if intro:
			card.play_intro(0.08 + 0.07 * index)
	hud._apply_ui_font_tree(_quest_board_slot)


func _active_quests() -> Array:
	return (_progression.get("weekly_quests") as Array) if _quests_showing_weekly else (_progression.get("daily_quests") as Array)


func _make_quest_summary(total: int, claimed: int, ready: int, ready_coins: int, intro: bool) -> PanelContainer:
	var set_done := total > 0 and claimed == total
	var accent := SHOP_MINT if set_done else UI_TOKENS.COLOR_GOLD
	var summary := PanelContainer.new()
	summary.name = "QuestSummary"
	var style := hud._glass_panel_style(accent, 18, 0.6)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	summary.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	summary.add_child(row)
	var ring := PROGRESS_RING.new()
	ring.name = "SetProgress"
	ring.custom_minimum_size = Vector2(60, 60)
	ring.accent = accent
	ring.caption = "%d/%d" % [claimed, total]
	ring.caption_size = 14
	var ratio := float(claimed) / float(maxi(total, 1))
	ring.set_progress(0.0 if intro else _quest_ring_ratio, false)
	ring.set_progress(ratio, not hud._reduced_motion)
	_quest_ring_ratio = ratio
	row.add_child(ring)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	copy.add_theme_constant_override("separation", 2)
	row.add_child(copy)
	copy.add_child(_drawer_label("THIS WEEK'S OBJECTIVES" if _quests_showing_weekly else "TODAY'S OBJECTIVES", 16, UI_TOKENS.COLOR_TEXT))
	var detail := "Play naturally. Claim each reward the moment it's ready."
	var detail_color := Color(0.61, 0.72, 0.9)
	if ready > 0:
		detail = "%d READY  ·  +%d COINS WAITING" % [ready, ready_coins]
		detail_color = UI_TOKENS.COLOR_GOLD
	elif set_done:
		detail = "SET COMPLETE  ·  NICE WORK"
		detail_color = SHOP_MINT
	copy.add_child(_drawer_label(detail, 12, detail_color))
	if ready > 1:
		var claim_all := Button.new()
		claim_all.name = "ClaimAll"
		claim_all.text = "CLAIM ALL  +%d" % ready_coins
		claim_all.custom_minimum_size = Vector2(150, 42)
		claim_all.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		claim_all.focus_mode = Control.FOCUS_NONE
		claim_all.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		hud._apply_primary_shop_button_style(claim_all, UI_TOKENS.COLOR_GOLD)
		claim_all.pressed.connect(func() -> void: _claim_all_quests(claim_all))
		PROGRESSION_FX.springy(claim_all)
		PROGRESSION_FX.breathe(claim_all, 0.14)
		row.add_child(claim_all)
	return summary


## One objective: a completion ring, the title with its count, a bar that
## fills on entry, and the reward button (disabled CLAIM while in progress,
## lit CLAIM when ready, COMPLETED once paid).
func _make_quest_card(quest: Dictionary, intro: bool, fill_delay: float) -> MenuCard:
	var claimed := bool(quest.get("claimed", false))
	var completed := bool(quest.get("completed", false)) or claimed
	var ready := completed and not claimed
	var target := maxi(1, int(quest.get("target", 1)))
	var progress := mini(target, int(quest.get("progress", 0)))
	var ratio := float(progress) / float(target)
	var accent := SHOP_MINT if claimed else (UI_TOKENS.COLOR_GOLD if completed else (Color(0.5, 0.58, 1.0) if _quests_showing_weekly else UI_TOKENS.COLOR_CYAN))
	var card := MENU_CARD.new("QuestCard_%s" % str(quest.get("id", "")), accent, false, Vector4(14, 12, 14, 12), 0.24 if ready else 0.12)
	card.custom_minimum_size = Vector2(0, 80)
	card.set_reduced_motion(hud._reduced_motion)
	card.set_highlighted(ready)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 14)
	card.content.add_child(row)
	var badge := PROGRESS_RING.new()
	badge.custom_minimum_size = Vector2(46, 46)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.accent = accent
	badge.thickness = 5.0
	badge.caption = "✓" if claimed else "%d%%" % int(round(ratio * 100.0))
	badge.caption_size = 10 if progress >= target else 11
	badge.set_progress(0.0 if intro else ratio, false)
	badge.set_progress(ratio, not hud._reduced_motion)
	row.add_child(badge)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	copy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.add_theme_constant_override("separation", 7)
	row.add_child(copy)
	var title_row := HBoxContainer.new()
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	copy.add_child(title_row)
	var title := _drawer_label(str(quest.get("title", "Quest")), 15, UI_TOKENS.COLOR_MUTED if claimed else UI_TOKENS.COLOR_TEXT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_row.add_child(title)
	var status := "CLAIMED" if claimed else ("READY TO CLAIM" if ready else "%d / %d" % [progress, target])
	title_row.add_child(_drawer_label(status, 11, SHOP_MINT if claimed else (UI_TOKENS.COLOR_GOLD if ready else Color(0.63, 0.75, 0.93))))
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 8)
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.max_value = target
	bar.value = progress
	bar.add_theme_stylebox_override("background", hud._progress_style(Color(0.02, 0.03, 0.06), Color(0.14, 0.22, 0.38)))
	var fill := hud._progress_style(accent, Color.TRANSPARENT)
	fill.shadow_color = Color(accent, 0.45)
	fill.shadow_size = 5
	bar.add_theme_stylebox_override("fill", fill)
	copy.add_child(bar)
	if intro:
		PROGRESSION_FX.fill_bar(bar, 0.0, fill_delay)
	var reward := Button.new()
	reward.name = "QuestReward"
	reward.text = "COMPLETED" if claimed else "CLAIM  +%d" % int(quest.get("reward", 0))
	reward.custom_minimum_size = Vector2(138, 42)
	reward.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	reward.focus_mode = Control.FOCUS_NONE
	reward.disabled = not ready
	reward.add_theme_constant_override("icon_max_width", 16)
	hud._apply_primary_shop_button_style(reward, UI_TOKENS.COLOR_GOLD)
	if claimed:
		hud._apply_settled_button_style(reward, SHOP_MINT)
	else:
		reward.icon = COIN_ICON_SCRIPT.COIN_TEXTURE
	if ready:
		reward.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		reward.pressed.connect(_claim_quest.bind("weekly" if _quests_showing_weekly else "daily", str(quest.get("id", "")), reward))
		PROGRESSION_FX.breathe(reward, 0.16)
	PROGRESSION_FX.springy(reward)
	row.add_child(reward)
	return card


func _set_quest_tab(show_weekly: bool) -> void:
	if show_weekly == _quests_showing_weekly:
		return
	_quests_showing_weekly = show_weekly
	_quest_ring_ratio = 0.0
	if _quest_board_slot != null and is_instance_valid(_quest_board_slot) and _quest_board_slot.is_inside_tree():
		_update_quest_reset_label()
		_fill_quest_board(true)
	else:
		_build_progression(true)


## `source` is the button that asked; inside the drawer the coins fly from it
## into the header balance, which counts up as they land.
func _claim_quest(group: String, quest_id: String, source: Control = null) -> void:
	if _progression == null:
		return
	var in_drawer := is_progression_open()
	var from := source.get_global_rect().get_center() if is_instance_valid(source) else Vector2.ZERO
	_drawer_coin_flight = in_drawer
	var claimed := bool(_progression.call("claim_quest", group, quest_id))
	_drawer_coin_flight = false
	if claimed:
		_on_quests_claimed(from, in_drawer)


func _claim_all_quests(source: Control) -> void:
	var from := source.get_global_rect().get_center()
	var group := "weekly" if _quests_showing_weekly else "daily"
	var claimed_any := false
	_drawer_coin_flight = true
	for quest_value in _active_quests().duplicate():
		var quest := quest_value as Dictionary
		if bool(quest.get("completed", false)) and not bool(quest.get("claimed", false)):
			claimed_any = bool(_progression.call("claim_quest", group, str(quest.get("id", "")))) or claimed_any
	_drawer_coin_flight = false
	if claimed_any:
		_on_quests_claimed(from, true)


func _on_quests_claimed(from: Vector2, in_drawer: bool) -> void:
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null:
		audio.call("play_sfx", &"coin_collect", -8.0, 1.2)
	_show_progression_toast("QUEST CLAIMED", "Coins added to your balance")
	if not in_drawer:
		return
	_build_progression(false)
	var balance := int(_progression.call("get_balance"))
	var chip_center := _drawer_balance_chip.get_global_rect().get_center()
	PROGRESSION_FX.coin_burst(_shop_overlay, from if from != Vector2.ZERO else chip_center, chip_center, 8, func() -> void:
		_count_drawer_balance(balance)
		PROGRESSION_FX.punch(_drawer_balance_chip, 1.1)
	)


func _drawer_label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _coin_mark(edge: float) -> Control:
	var coin := Control.new()
	coin.custom_minimum_size = Vector2(edge, edge)
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	coin.set_script(COIN_ICON_SCRIPT)
	return coin


func _on_coin_balance_changed(balance: int, delta: int) -> void:
	_coin_target_balance = balance
	_pulse_coin_chip(delta > 0)
	if is_progression_open():
		if not _drawer_coin_flight:
			_count_drawer_balance(balance)
	elif delta > 0:
		_show_coin_earn(delta)
	_refresh_quest_panel()
	hud._refresh_menu_loadout()


func _on_quest_completed(quest: Dictionary, _reward: int) -> void:
	hud.show_announcement("QUEST COMPLETE!  %s" % str(quest.get("title", "")), Color(0.35, 1.0, 0.56))
	_show_progression_toast("QUEST COMPLETE", str(quest.get("title", "")))


func _create_toast_stack() -> void:
	_toast_stack = VBoxContainer.new()
	_toast_stack.name = "ToastStack"
	_toast_stack.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	# Sits below the kill feed so a mid-match quest toast never covers it.
	_toast_stack.position = Vector2(-340, 168)
	_toast_stack.custom_minimum_size = Vector2(316, 0)
	_toast_stack.add_theme_constant_override("separation", 8)
	_toast_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(_toast_stack)


func _show_progression_toast(title: String, detail: String) -> void:
	if _toast_stack == null:
		return
	hud.move_child(_toast_stack, hud.get_child_count() - 1)
	if _toast_stack.get_child_count() >= 3:
		_toast_stack.get_child(0).free()
	var toast := PanelContainer.new()
	toast.name = "ToastMessage"
	toast.custom_minimum_size = Vector2(316, 68)
	toast.modulate.a = 0.0
	toast.add_theme_stylebox_override("panel", hud._glass_panel_style(Color(0.32, 0.95, 0.61), 12, 0.9))
	_toast_stack.add_child(toast)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	toast.add_child(row)
	var status_rail := ColorRect.new()
	status_rail.custom_minimum_size = Vector2(3, 0)
	status_rail.color = Color(0.32, 0.95, 0.61)
	status_rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(status_rail)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.alignment = BoxContainer.ALIGNMENT_CENTER
	copy.add_theme_constant_override("separation", 1)
	row.add_child(copy)
	var title_label := Label.new()
	title_label.text = title
	title_label.add_theme_font_size_override("font_size", 13)
	title_label.add_theme_color_override("font_color", Color(0.88, 1.0, 0.94))
	copy.add_child(title_label)
	var detail_label := Label.new()
	detail_label.text = detail
	detail_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	detail_label.add_theme_font_size_override("font_size", 12)
	detail_label.add_theme_color_override("font_color", Color(0.64, 0.72, 0.81))
	copy.add_child(detail_label)
	hud._apply_ui_font_tree(toast)
	toast.position.x = 12.0
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	tween.tween_property(toast, "modulate:a", 1.0, 0.06 if hud._reduced_motion else 0.14)
	tween.tween_property(toast, "position:x", 0.0, 0.01 if hud._reduced_motion else 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.set_parallel(false)
	tween.tween_interval(2.6)
	tween.tween_property(toast, "modulate:a", 0.0, 0.06 if hud._reduced_motion else 0.16)
	tween.tween_callback(toast.queue_free)


func _show_coin_earn(amount: int) -> void:
	var floating := Label.new()
	floating.text = "+%d COINS" % amount
	floating.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	floating.position = Vector2(-210, 86)
	floating.add_theme_font_size_override("font_size", 21)
	floating.add_theme_color_override("font_color", Color(1.0, 0.82, 0.25))
	hud.add_child(floating)
	var primary_coin := Control.new()
	primary_coin.set_script(COIN_ICON_SCRIPT)
	primary_coin.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	primary_coin.position = Vector2(-210, 80)
	primary_coin.size = Vector2(30, 30)
	primary_coin.pivot_offset = Vector2(15, 15)
	primary_coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(primary_coin)
	var coin_tween := create_tween()
	coin_tween.set_parallel(true)
	coin_tween.tween_property(primary_coin, "position", Vector2(-145, 34), 0.64).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	coin_tween.tween_property(primary_coin, "rotation", TAU, 0.64)
	coin_tween.tween_property(primary_coin, "scale", Vector2(1.24, 1.24), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	coin_tween.set_parallel(false)
	coin_tween.tween_property(primary_coin, "scale", Vector2(0.18, 0.18), 0.16)
	coin_tween.tween_callback(primary_coin.queue_free)
	for index in 4:
		var particle := Control.new()
		particle.set_script(COIN_ICON_SCRIPT)
		particle.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		particle.position = Vector2(-142, 92)
		particle.size = Vector2(20, 20)
		particle.pivot_offset = Vector2(10, 10)
		particle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hud.add_child(particle)
		var angle := TAU * float(index) / 4.0
		var destination := particle.position + Vector2(cos(angle), sin(angle)) * 42.0
		var particle_tween := create_tween()
		particle_tween.set_parallel(true)
		particle_tween.tween_property(particle, "position", destination, 0.48).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		particle_tween.tween_property(particle, "rotation", TAU * (1.0 if index % 2 == 0 else -1.0), 0.48)
		particle_tween.tween_property(particle, "modulate:a", 0.0, 0.46).set_delay(0.18)
		particle_tween.set_parallel(false)
		particle_tween.tween_callback(particle.queue_free)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(floating, "position:y", 48.0, 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(floating, "modulate:a", 0.0, 0.75).set_delay(0.35)
	tween.set_parallel(false)
	tween.tween_callback(floating.queue_free)
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null:
		audio.call("play_sfx", &"coin_collect", -10.0, 1.12)


func _refresh_shop_if_open() -> void:
	if not is_progression_open():
		return
	_refresh_drawer_header()
	var scroll_offset := _shop_scroll.scroll_vertical if _active_progression_page == "shop" and is_instance_valid(_shop_scroll) else 0
	_build_progression(false)
	if scroll_offset <= 0:
		return
	# A purchase or equip rebuilds the grid; keep the player where they were
	# once the new grid has been laid out.
	await get_tree().process_frame
	if is_instance_valid(_shop_scroll):
		_shop_scroll.scroll_vertical = scroll_offset


func _pulse_coin_chip(earned: bool) -> void:
	if _coin_chip == null:
		return
	_coin_chip.pivot_offset = _coin_chip.size * 0.5
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_coin_chip, "scale", Vector2(1.1, 1.1), 0.11).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if _coin_icon != null and earned:
		tween.tween_property(_coin_icon, "rotation", TAU * 0.45, 0.2)
	tween.set_parallel(false)
	tween.tween_property(_coin_chip, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _update_coin_label() -> void:
	if _coin_balance_label != null:
		_coin_balance_label.text = "%d" % int(round(_shown_coin_balance))


func _update_quest_reset_label() -> void:
	if _quest_reset_label != null:
		_quest_reset_label.text = _daily_reset_text()
	if _board_reset_label != null and is_instance_valid(_board_reset_label):
		_board_reset_label.text = "RESETS IN  %s" % (_weekly_reset_text() if _quests_showing_weekly else _daily_reset_text().trim_prefix("RESET  "))


func _daily_reset_text() -> String:
	var now := Time.get_time_dict_from_system()
	var remaining := maxi(0, 86400 - int(now.get("hour", 0)) * 3600 - int(now.get("minute", 0)) * 60 - int(now.get("second", 0)))
	return "RESET  %02d:%02d:%02d" % [remaining / 3600, (remaining % 3600) / 60, remaining % 60]


## Weekly quests rotate on whole Unix weeks (Progression's weekly key).
func _weekly_reset_text() -> String:
	var remaining := 604800 - (int(Time.get_unix_time_from_system()) % 604800)
	return "%dD  %02dH" % [remaining / 86400, (remaining % 86400) / 3600]
