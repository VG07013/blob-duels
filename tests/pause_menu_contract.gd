extends SceneTree

const PAUSE_SCENE := preload("res://scenes/ui/pause_menu.tscn")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var pause := PAUSE_SCENE.instantiate()
	pause.settings_path = "user://blob_duels_pause_contract.cfg"
	root.add_child(pause)
	await process_frame

	var ability_texture := GradientTexture1D.new()
	pause.call("set_context", true, false, "phase_bubble", ability_texture)
	_check(not _contains_paused_copy(pause), "multiplayer escape menu must not claim that the duel is paused")
	_check(not pause.get_node("PausePanel/Content/Header/StatePill").visible, "multiplayer escape menu must not show a duel-state pill")
	_check(str(pause.get_node("PausePanel/Content/Pages/MatchPage/Stack/Title").text) != "Take a breather", "escape menu must not use the oversized breather screen copy")

	var ability_card := pause.get_node("PausePanel/Content/Pages/MatchPage/Stack/AbilityCard") as Control
	var ability_icon := pause.get_node("PausePanel/Content/Pages/MatchPage/Stack/AbilityCard/Row/Icon") as TextureRect
	var ability_name := pause.get_node("PausePanel/Content/Pages/MatchPage/Stack/AbilityCard/Row/Copy/Name") as Label
	_check(ability_card.visible, "equipped ability card must be visible")
	_check(ability_icon.texture == ability_texture, "escape menu must display the equipped ability icon")
	_check(ability_name.text == "Phase Bubble", "equipped ability name must be human readable")
	pause.call("set_context", true, false)
	_check(not ability_card.visible, "opening a context without an ability must clear a stale ability card")
	pause.call("set_equipped_ability", "phase_bubble", ability_texture)

	pause.call("open_pause")
	_check(root.gui_get_focus_owner() == null, "opening escape menu must not keyboard-focus a button")
	_check(_all_interactive_controls_disable_focus(pause), "escape menu controls must not accept keyboard focus")
	pause.call("_select_crosshair_slot", 2)
	_check(_all_interactive_controls_disable_focus(pause), "rebuilt crosshair controls must not accept keyboard focus")
	_check(pause.get_node_or_null("PausePanel/Content/Tabs/ControlsTab") is Button, "escape menu must offer a Controls tab beside Match, Settings, and Crosshair")
	_check(pause.get_node_or_null("PausePanel/Content/Pages/ControlsPage") != null, "escape menu must have a Controls page for key rebinding")
	pause.call("_show_page", 3)
	_check(str(pause.get_node("PausePanel/Content/Header/BrandBlock/Title").text) == "Controls", "Controls tab must title the header")
	pause.call("_reset_bindings")
	_check(_all_interactive_controls_disable_focus(pause), "rebuilt binding controls must not accept keyboard focus")

	for viewport_size in [Vector2i(640, 360), Vector2i(1280, 720), Vector2i(1440, 900), Vector2i(1920, 1080)]:
		root.size = viewport_size
		pause.call("_fit_to_viewport", Vector2(viewport_size))
		await process_frame
		var panel := pause.get_node("PausePanel") as PanelContainer
		_check(panel.get_combined_minimum_size().y <= minf(540.0, viewport_size.y - 24.0), "escape menu minimum height exceeds its responsive cap at %s" % viewport_size)
		_check(panel.size.x <= minf(900.0, viewport_size.x - 48.0) + 1.0, "escape menu is too wide at %s" % viewport_size)
		_check(panel.size.y <= minf(620.0, viewport_size.y - 36.0) + 1.0, "escape menu is too tall at %s" % viewport_size)
		for page_index in 4:
			pause.call("_show_page", page_index)
			await process_frame
			_check(_visible_descendants_fit(panel), "escape menu page %d clips at %s" % [page_index, viewport_size])

	pause.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://blob_duels_pause_contract.cfg"))
	if failures.is_empty():
		print("PAUSE MENU CONTRACT PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _contains_paused_copy(root_node: Node) -> bool:
	for child in root_node.find_children("*", "Label", true, false):
		if "PAUSED" in str((child as Label).text).to_upper():
			return true
	return false


func _all_interactive_controls_disable_focus(root_node: Node) -> bool:
	for child in root_node.find_children("*", "Control", true, false):
		var control := child as Control
		if control is BaseButton or control is LineEdit or control is Range or control is ScrollContainer:
			if control.focus_mode != Control.FOCUS_NONE:
				return false
	return true


func _visible_descendants_fit(panel: Control) -> bool:
	return _children_fit_parent(panel)


func _children_fit_parent(parent: Control) -> bool:
	if parent is ScrollContainer:
		return true
	var bounds := Rect2(Vector2.ZERO, parent.size).grow(1.0)
	for child_node in parent.get_children():
		var child := child_node as Control
		if child == null or not child.visible:
			continue
		if not bounds.encloses(Rect2(child.position, child.size)):
			print("PAUSE LOCAL CLIP: %s parent_size=%s child_rect=%s child_min=%s" % [str(parent.get_path_to(child)), parent.size, Rect2(child.position, child.size), child.get_combined_minimum_size()])
			for grandchild in child.get_children():
				if grandchild is Control:
					print("  CHILD: %s size=%s min=%s" % [str(grandchild.name), (grandchild as Control).size, (grandchild as Control).get_combined_minimum_size()])
			return false
		if not _children_fit_parent(child):
			return false
	return true


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
