extends Node

signal state_changed(state: int, message: String)
signal session_ready(is_host: bool)
signal peer_joined(peer_id: int)
signal peer_left(peer_id: int)

enum SessionState {
	OFFLINE,
	HOSTING,
	JOINING,
	CONNECTED,
	FAILED,
}

const DEFAULT_PORT := 7359
const MAX_CLIENTS := 1

var state := SessionState.OFFLINE
var status_message := "Offline"


func _ready() -> void:
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)


func host_game(port: int = DEFAULT_PORT) -> Error:
	close_session()
	if port < 1 or port > 65535:
		_set_state(SessionState.FAILED, "Host port is not valid")
		return ERR_INVALID_PARAMETER
	var peer := ENetMultiplayerPeer.new()
	var result := peer.create_server(port, MAX_CLIENTS)
	if result != OK:
		_set_state(SessionState.FAILED, "Could not host on port %d" % port)
		return result

	multiplayer.multiplayer_peer = peer
	_set_state(SessionState.HOSTING, "Hosting on port %d - waiting for players" % port)
	session_ready.emit(true)
	return OK


func join_game(address: String, port: int = DEFAULT_PORT) -> Error:
	close_session()
	if port < 1 or port > 65535:
		_set_state(SessionState.FAILED, "Join port is not valid")
		return ERR_INVALID_PARAMETER
	var clean_address := address.strip_edges()
	if clean_address.is_empty():
		clean_address = "127.0.0.1"

	var peer := ENetMultiplayerPeer.new()
	var result := peer.create_client(clean_address, port)
	if result != OK:
		_set_state(SessionState.FAILED, "Could not start connection")
		return result

	multiplayer.multiplayer_peer = peer
	_set_state(SessionState.JOINING, "Joining %s:%d..." % [clean_address, port])
	return OK


func join_game_by_code(room_code: String, port: int = DEFAULT_PORT) -> Error:
	# A new join attempt owns the session state, even when validation fails.
	# Otherwise an old ENet peer can keep running behind a FAILED UI state.
	close_session()
	var clean_code := room_code.strip_edges()
	var address := clean_code if _is_connectable_ipv4(clean_code) else room_code_to_address(clean_code)
	if address.is_empty() or not _is_connectable_ipv4(address):
		_set_state(SessionState.FAILED, "That room code is not valid")
		return ERR_INVALID_PARAMETER
	return join_game(address, port)


func get_host_room_code() -> String:
	var best_address := ""
	var best_score := 1000
	for interface_value in IP.get_local_interfaces():
		var interface_data := interface_value as Dictionary
		var interface_name := str(interface_data.get("name", "")).to_lower()
		var friendly_name := str(interface_data.get("friendly", "")).to_lower()
		if _is_virtual_interface(interface_name + " " + friendly_name):
			continue
		for address_value in interface_data.get("addresses", []):
			var address := str(address_value)
			if not _is_private_ipv4(address):
				continue
			var score := _interface_score(interface_name, friendly_name, address)
			if score < best_score:
				best_address = address
				best_score = score
	if not best_address.is_empty():
		return address_to_room_code(best_address)
	return address_to_room_code("127.0.0.1")


static func address_to_room_code(address: String) -> String:
	var octets := address.strip_edges().split(".")
	if octets.size() != 4:
		return ""
	var encoded: Array[String] = []
	for octet_text in octets:
		if not str(octet_text).is_valid_int():
			return ""
		var octet := int(octet_text)
		if octet < 0 or octet > 255:
			return ""
		encoded.append("%02X" % octet)
	return "%s%s-%s%s" % encoded


static func room_code_to_address(room_code: String) -> String:
	var clean_code := room_code.strip_edges().to_upper()
	var room_code_pattern := RegEx.create_from_string("^[0-9A-F]{4}-[0-9A-F]{4}$")
	if room_code_pattern.search(clean_code) == null:
		return ""
	var compact := clean_code.replace("-", "")
	var octets: Array[String] = []
	for index in range(0, 8, 2):
		octets.append(str(compact.substr(index, 2).hex_to_int()))
	return ".".join(octets)


func _is_private_ipv4(address: String) -> bool:
	var octets := address.split(".")
	if octets.size() != 4:
		return false
	var first := int(octets[0])
	var second := int(octets[1])
	return first == 10 or (first == 172 and second >= 16 and second <= 31) or (first == 192 and second == 168)


func _is_connectable_ipv4(address: String) -> bool:
	var ipv4_pattern := RegEx.create_from_string("^[0-9]{1,3}(\\.[0-9]{1,3}){3}$")
	if ipv4_pattern.search(address) == null:
		return false
	var octets := address.split(".")
	if octets.size() != 4:
		return false
	for octet_text in octets:
		if not str(octet_text).is_valid_int():
			return false
		var octet := int(octet_text)
		if octet < 0 or octet > 255:
			return false
	var first := int(octets[0])
	return first > 0 and first < 224 and address != "255.255.255.255"


func _is_virtual_interface(label: String) -> bool:
	for marker in ["utun", "tun", "tap", "vpn", "vbox", "vmnet", "docker", "loopback"]:
		if marker in label:
			return true
	return false


func _interface_score(interface_name: String, friendly_name: String, address: String) -> int:
	var label := interface_name + " " + friendly_name
	var adapter_score := 0 if interface_name.begins_with("en") or "wi-fi" in label or "ethernet" in label else 20
	var address_score := 0 if address.begins_with("192.168.") else (2 if address.begins_with("10.") else 4)
	return adapter_score + address_score


func close_session() -> void:
	var peer := multiplayer.multiplayer_peer
	if peer != null:
		peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_set_state(SessionState.OFFLINE, "Offline")


func is_online() -> bool:
	return state == SessionState.HOSTING or state == SessionState.CONNECTED


func is_joining() -> bool:
	return state == SessionState.JOINING


func _set_state(new_state: int, message: String) -> void:
	state = new_state as SessionState
	status_message = message
	state_changed.emit(state, status_message)


func _on_connected_to_server() -> void:
	_set_state(SessionState.CONNECTED, "Connected - entering arena")
	session_ready.emit(false)


func _on_connection_failed() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_set_state(SessionState.FAILED, "Join failed - check the room code and host")


func _on_server_disconnected() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_set_state(SessionState.FAILED, "Host disconnected")


func _on_peer_connected(peer_id: int) -> void:
	if multiplayer.is_server():
		_set_state(SessionState.CONNECTED, "Player connected - match ready")
	peer_joined.emit(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	if multiplayer.is_server():
		_set_state(SessionState.HOSTING, "Player left - waiting for players")
	peer_left.emit(peer_id)
