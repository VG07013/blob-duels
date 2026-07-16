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
	_set_state(SessionState.FAILED, "Join failed - check the address and host")


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
