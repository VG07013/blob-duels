class_name NetworkStatusHud
extends Node

## The HUD's window onto NetworkSession: the LAN / Internet room codes shown
## to a host (and copied to the clipboard), the room-code field formatting, and
## the small ping readout in the duel HUD's bottom-right corner. DuelHud creates
## one in _create_main_menu; the menu controls it reads belong to the HUD.

const NETWORK_TUNING := preload("res://scripts/net/network_tuning.gd")

var hud: DuelHud
var _ping_label: Label = null
var _formatting_room_code := false


func setup(owner_hud: DuelHud) -> void:

	hud = owner_hud
	hud.code_input.text_changed.connect(_format_room_code_input)
	hud.main_menu.copy_button.pressed.connect(_copy_room_code)
	var network_session := get_node_or_null("/root/NetworkSession")
	if network_session != null and network_session.has_signal("public_address_ready"):
		network_session.connect("public_address_ready", func(_code: String) -> void: _refresh_room_code())
	_create_ping_label()
	_refresh_room_code()


## Shows the code(s) a host can hand out. The Internet code appears once
## NetworkSession's UPnP mapping has produced a public address; the LAN code
## is always listed as the fallback for players on the same network.
func _refresh_room_code() -> void:
	var network_session := get_node_or_null("/root/NetworkSession")
	var lan_code := "LOCAL"
	var internet_code := ""
	if network_session != null and network_session.has_method("get_host_room_code"):
		lan_code = str(network_session.call("get_host_room_code"))
	if network_session != null and network_session.has_method("get_public_room_code"):
		internet_code = str(network_session.call("get_public_room_code"))
	var copy_button := hud.main_menu.copy_button
	if internet_code.is_empty():
		hud.room_code.text = "LAN CODE  %s" % lan_code
		copy_button.text = "COPY LAN CODE"
		copy_button.tooltip_text = "Copy the LAN code to the clipboard"
	else:
		hud.room_code.text = "INTERNET CODE  %s\nLAN CODE  %s" % [internet_code, lan_code]
		copy_button.text = "COPY INTERNET CODE"
		copy_button.tooltip_text = "Copy the Internet code to the clipboard"


func _copy_room_code() -> void:
	var network_session := get_node_or_null("/root/NetworkSession")
	var has_internet_code := network_session != null and network_session.has_method("has_public_address") and bool(network_session.call("has_public_address"))
	var code := ""
	if network_session != null and network_session.has_method("get_share_room_code"):
		code = str(network_session.call("get_share_room_code"))
	else:
		code = hud.room_code.text.trim_prefix("LAN CODE").strip_edges()
	DisplayServer.clipboard_set(code)
	if has_internet_code:
		hud.set_join_status("Internet code copied — send it to a friend anywhere", false)
	else:
		hud.set_join_status("LAN code copied — send it to a player on your network", false)


## Small round-trip readout in the bottom-right corner of the duel HUD. Hidden
## whenever the session is offline or the lobby is up; colour tracks the
## thresholds in NetworkTuning.
func _create_ping_label() -> void:
	if _ping_label != null:
		return
	_ping_label = Label.new()
	_ping_label.name = "PingLabel"
	_ping_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_ping_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_ping_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_ping_label.offset_left = -132.0
	_ping_label.offset_top = -34.0
	_ping_label.offset_right = -16.0
	_ping_label.offset_bottom = -12.0
	_ping_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_ping_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ping_label.add_theme_font_size_override("font_size", 15)
	_ping_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	_ping_label.add_theme_constant_override("outline_size", 5)
	_ping_label.z_index = 128
	_ping_label.visible = false
	hud.add_child(_ping_label)
	var network_session := get_node_or_null("/root/NetworkSession")
	if network_session != null:
		if network_session.has_signal("ping_updated"):
			network_session.connect("ping_updated", _update_ping_label)
		if network_session.has_signal("state_changed"):
			network_session.connect("state_changed", func(_state: int, _message: String) -> void: _refresh_ping_visibility())
	hud.main_menu.visibility_changed.connect(_refresh_ping_visibility)


func _update_ping_label(msec: int) -> void:
	if _ping_label == null:
		return
	_ping_label.text = "PING %d ms" % maxi(msec, 0)
	_ping_label.add_theme_color_override("font_color", ping_readout_color(msec))
	_refresh_ping_visibility()


func _refresh_ping_visibility() -> void:
	if _ping_label == null:
		return
	var network_session := get_node_or_null("/root/NetworkSession")
	var online := network_session != null and network_session.has_method("is_online") and bool(network_session.call("is_online"))
	var has_reading := network_session != null and network_session.has_method("get_ping_msec") and int(network_session.call("get_ping_msec")) >= 0
	_ping_label.visible = online and has_reading and not hud.main_menu.visible


## Green under PING_GOOD_MSEC, amber under PING_FAIR_MSEC, red beyond.
static func ping_readout_color(msec: int) -> Color:
	if msec < NETWORK_TUNING.PING_GOOD_MSEC:
		return Color(0.62, 0.98, 0.76)
	if msec < NETWORK_TUNING.PING_FAIR_MSEC:
		return Color(1.0, 0.78, 0.32)
	return Color(1.0, 0.42, 0.42)


func _format_room_code_input(value: String) -> void:
	if _formatting_room_code:
		return
	var stripped := value.strip_edges()
	if "." in stripped:
		return
	var compact := ""
	for character in stripped.to_upper():
		if character in "0123456789ABCDEF":
			compact += character
			if compact.length() >= 8:
				break
	var formatted := compact
	if compact.length() > 4:
		formatted = compact.left(4) + "-" + compact.substr(4)
	if formatted == value:
		return
	_formatting_room_code = true
	hud.code_input.text = formatted
	hud.code_input.caret_column = formatted.length()
	_formatting_room_code = false
