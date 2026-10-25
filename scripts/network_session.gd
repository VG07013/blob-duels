## The NetworkSession autoload. The class name differs from the autoload so
## fixed callers can type it (a class_name equal to an autoload is an error).
class_name DuelNetworkSession
extends Node

signal state_changed(state: int, message: String)
signal session_ready(is_host: bool)
signal peer_joined(peer_id: int)
signal peer_left(peer_id: int)
## Fired on the host once UPnP has mapped the port and the router reported a
## public IPv4. `room_code` is the Internet code to share.
signal public_address_ready(room_code: String)
signal upnp_state_changed(upnp_state: int)
## Smoothed round-trip time to the other peer, in milliseconds.
signal ping_updated(msec: int)

enum SessionState {
	OFFLINE,
	HOSTING,
	JOINING,
	CONNECTED,
	FAILED,
}

## Lifecycle of the automatic router port mapping. DISABLED is the opt-out;
## IDLE means nothing is mapped (offline or hosting stopped).
enum UpnpState {
	DISABLED,
	IDLE,
	DISCOVERING,
	MAPPED,
	FAILED,
}

const DEFAULT_PORT := 7359
const MAX_CLIENTS := 1
const TUNING := preload("res://scripts/net/network_tuning.gd")

var state := SessionState.OFFLINE
var status_message := "Offline"

## Set false to skip router discovery entirely (tests, or a player who
## port-forwards by hand). Read once per host_game call.
var upnp_enabled := true
var upnp_state := UpnpState.IDLE
## Short human reason for the last UPnP failure, empty otherwise.
var upnp_failure_reason := ""

## Builds the UPNP object the worker talks to. Tests swap in a fake with the
## same discover / add_port_mapping / query_external_address /
## delete_port_mapping surface so the state machine runs without a router.
var _upnp_factory: Callable = Callable(self, "_create_upnp")
## Every hosting attempt gets a fresh generation; a worker that finishes for
## an older generation unmaps whatever it created and is otherwise ignored.
var _upnp_generation := 0
var _upnp_threads: Array[Thread] = []
## The device object that holds the live mapping, kept so close_session can
## remove it. Untyped because it is either a UPNP or a test fake.
var _upnp_device: Variant = null
var _upnp_mapped_port := 0
var _public_address := ""
var _hosting_port := 0

var _ping_timer := 0.0
var _ping_sequence := 0
## sequence -> local Time.get_ticks_msec() when the ping went out. The RTT is
## always computed from this record, never from anything the peer echoes.
var _ping_sent_at: Dictionary = {}
var _ping_msec := -1.0
## host_clock - local_clock, estimated from pongs the host answered.
var _host_clock_offset_msec := 0.0
var _clock_synced := false


func _ready() -> void:
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)


func _exit_tree() -> void:
	# App quit: the router must never keep a hole open for a game that is gone.
	_release_upnp_mapping()
	_upnp_generation += 1
	_join_upnp_threads(true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_release_upnp_mapping()


func _process(delta: float) -> void:
	_join_upnp_threads(false)
	if not is_online():
		return
	var peers := multiplayer.get_peers()
	if peers.is_empty():
		return
	_ping_timer += delta
	if _ping_timer < TUNING.PING_INTERVAL_SEC:
		return
	_ping_timer = 0.0
	_send_ping(peers)


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
	_hosting_port = port
	_begin_upnp_mapping(port)
	_set_state(SessionState.HOSTING, _compose_host_status())
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


## The Internet code (public IPv4, same encoding as the LAN code) once UPnP
## has mapped the port; empty until then or when mapping failed.
func get_public_room_code() -> String:
	if _public_address.is_empty():
		return ""
	return address_to_room_code(_public_address)


func get_public_address() -> String:
	return _public_address


## The one code a host should hand out: the Internet code when the router
## cooperated, the LAN code otherwise.
func get_share_room_code() -> String:
	var public_code := get_public_room_code()
	return public_code if not public_code.is_empty() else get_host_room_code()


func has_public_address() -> bool:
	return upnp_state == UpnpState.MAPPED and not _public_address.is_empty()


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


## True for a globally routable IPv4: rejects private, loopback, link-local,
## carrier-grade NAT (100.64/10), unspecified and multicast ranges. A router
## whose WAN side is one of these cannot be reached from the Internet, so a
## mapping there would only produce a code that never connects.
static func _is_public_ipv4(address: String) -> bool:
	var octets := address.strip_edges().split(".")
	if octets.size() != 4:
		return false
	for octet_text in octets:
		if not str(octet_text).is_valid_int() or int(octet_text) < 0 or int(octet_text) > 255:
			return false
	var first := int(octets[0])
	var second := int(octets[1])
	if first == 0 or first == 10 or first == 127 or first >= 224:
		return false
	if first == 172 and second >= 16 and second <= 31:
		return false
	if first == 192 and second == 168:
		return false
	if first == 169 and second == 254:
		return false
	if first == 100 and second >= 64 and second <= 127:
		return false
	return true


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
	# Security note: the router mapping lives exactly as long as hosting does.
	_release_upnp_mapping()
	_upnp_generation += 1
	_hosting_port = 0
	_set_upnp_state(UpnpState.IDLE, "")
	_reset_ping()
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
	_reset_ping()
	_set_state(SessionState.CONNECTED, "Connected - entering arena")
	session_ready.emit(false)


func _on_connection_failed() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_set_state(SessionState.FAILED, "Join failed - check the room code and host")


func _on_server_disconnected() -> void:
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_reset_ping()
	_set_state(SessionState.FAILED, "Host disconnected")


func _on_peer_connected(peer_id: int) -> void:
	if multiplayer.is_server():
		_reset_ping()
		_set_state(SessionState.CONNECTED, "Player connected - match ready")
	peer_joined.emit(peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	if multiplayer.is_server():
		_reset_ping()
		_set_state(SessionState.HOSTING, "Player left · " + _compose_host_status())
	peer_left.emit(peer_id)


# --- UPnP -------------------------------------------------------------------


func get_upnp_state() -> int:
	return upnp_state


func _create_upnp() -> Variant:
	return UPNP.new()


func _set_upnp_state(new_state: int, failure_reason: String) -> void:
	upnp_state = new_state as UpnpState
	upnp_failure_reason = failure_reason
	upnp_state_changed.emit(upnp_state)


## Status line for the lobby while hosting. Always names the code to share.
func _compose_host_status() -> String:
	var lan_code := get_host_room_code()
	match upnp_state:
		UpnpState.MAPPED:
			return "Internet code: %s · LAN code: %s — share the Internet code (router mapping is removed when hosting stops)" % [get_public_room_code(), lan_code]
		UpnpState.DISCOVERING:
			return "Hosting on port %d · LAN code: %s · asking your router for an Internet code..." % [_hosting_port, lan_code]
		UpnpState.FAILED:
			return "LAN code: %s · no Internet code (%s) — forward UDP %d by hand to play over the Internet" % [lan_code, upnp_failure_reason, _hosting_port]
		UpnpState.DISABLED:
			return "Hosting on port %d · LAN code: %s (UPnP off: forward UDP %d by hand to play over the Internet)" % [_hosting_port, lan_code, _hosting_port]
		_:
			return "Hosting on port %d · LAN code: %s" % [_hosting_port, lan_code]


func _begin_upnp_mapping(port: int) -> void:
	_public_address = ""
	if not upnp_enabled:
		_set_upnp_state(UpnpState.DISABLED, "")
		return
	_upnp_generation += 1
	_set_upnp_state(UpnpState.DISCOVERING, "")
	var thread := Thread.new()
	var start_result := thread.start(_upnp_worker.bind(port, _upnp_generation))
	if start_result != OK:
		_set_upnp_state(UpnpState.FAILED, "could not start router discovery")
		return
	_upnp_threads.append(thread)


## Runs off the main thread: UPNP.discover blocks for its whole timeout when
## no gateway answers. Touches nothing on the node; results come back through
## call_deferred so state changes happen on the main thread.
func _upnp_worker(port: int, generation: int) -> void:
	var report := _perform_upnp_mapping(port)
	call_deferred("_on_upnp_worker_finished", generation, report)


## Pure mapping attempt against whatever the factory hands back. Returns a
## report dictionary so the same routine serves the thread and a synchronous
## test. On success "device" holds the object that owns the mapping.
func _perform_upnp_mapping(port: int) -> Dictionary:
	var upnp: Variant = _upnp_factory.call()
	if upnp == null:
		return {"ok": false, "reason": "UPnP unavailable"}
	var discover_result: int = upnp.discover(TUNING.UPNP_DISCOVER_TIMEOUT_MSEC, TUNING.UPNP_DISCOVER_TTL, "InternetGatewayDevice")
	if discover_result != UPNP.UPNP_RESULT_SUCCESS:
		return {"ok": false, "reason": "no UPnP router answered"}
	var map_result: int = upnp.add_port_mapping(port, port, TUNING.UPNP_MAPPING_DESCRIPTION, "UDP", 0)
	if map_result != UPNP.UPNP_RESULT_SUCCESS:
		return {"ok": false, "reason": "router refused the port mapping"}
	var external_address := str(upnp.query_external_address()).strip_edges()
	if not _is_public_ipv4(external_address):
		# Behind carrier NAT or a double router: the mapping cannot be reached,
		# so do not leave it open.
		upnp.delete_port_mapping(port, "UDP")
		return {"ok": false, "reason": "router has no public address (carrier NAT?)"}
	return {"ok": true, "address": external_address, "device": upnp, "port": port}


func _on_upnp_worker_finished(generation: int, report: Dictionary) -> void:
	var succeeded := bool(report.get("ok", false))
	if generation != _upnp_generation:
		# Hosting stopped (or restarted) while the router was still thinking.
		if succeeded:
			report["device"].delete_port_mapping(int(report.get("port", 0)), "UDP")
		return
	if not succeeded:
		_set_upnp_state(UpnpState.FAILED, str(report.get("reason", "unknown error")))
		if state == SessionState.HOSTING:
			_set_state(SessionState.HOSTING, _compose_host_status())
		return
	_upnp_device = report["device"]
	_upnp_mapped_port = int(report.get("port", 0))
	_public_address = str(report.get("address", ""))
	_set_upnp_state(UpnpState.MAPPED, "")
	if state == SessionState.HOSTING:
		_set_state(SessionState.HOSTING, _compose_host_status())
	public_address_ready.emit(get_public_room_code())


func _release_upnp_mapping() -> void:
	if _upnp_device != null and _upnp_mapped_port > 0:
		_upnp_device.delete_port_mapping(_upnp_mapped_port, "UDP")
	_upnp_device = null
	_upnp_mapped_port = 0
	_public_address = ""


## Reaps finished worker threads. With `block` true it waits for running ones
## too, which only happens at app exit.
func _join_upnp_threads(block: bool) -> void:
	var remaining: Array[Thread] = []
	for thread in _upnp_threads:
		if thread.is_started() and (block or not thread.is_alive()):
			thread.wait_to_finish()
		elif thread.is_started():
			remaining.append(thread)
	_upnp_threads = remaining


# --- Ping -------------------------------------------------------------------


## Smoothed round-trip time in milliseconds, or -1 before the first pong.
func get_ping_msec() -> int:
	if _ping_msec < 0.0:
		return -1
	return int(round(_ping_msec))


## True once this peer can convert local time into the host's clock. Always
## true on the host, whose clock is the reference.
func has_clock_sync() -> bool:
	return multiplayer.is_server() or _clock_synced


## The host's Time.get_ticks_msec() as estimated right now. Remote blobs are
## rendered against this clock so their snapshots line up with the host's
## stamps.
func get_host_time_msec() -> int:
	var now := Time.get_ticks_msec()
	if multiplayer.is_server() or not _clock_synced:
		return now
	return now + int(round(_host_clock_offset_msec))


func get_host_clock_offset_msec() -> float:
	return _host_clock_offset_msec


func _reset_ping() -> void:
	_ping_timer = 0.0
	_ping_sent_at.clear()
	_ping_msec = -1.0
	_host_clock_offset_msec = 0.0
	_clock_synced = false


func _send_ping(peers: PackedInt32Array) -> void:
	_ping_sequence += 1
	var now := Time.get_ticks_msec()
	_register_ping_sent(_ping_sequence, now)
	for peer_id in peers:
		_ping.rpc_id(peer_id, _ping_sequence)


func _register_ping_sent(sequence: int, sent_msec: int) -> void:
	_ping_sent_at[sequence] = sent_msec
	_prune_ping_samples(sent_msec)


func _prune_ping_samples(now_msec: int) -> void:
	var expired: Array = []
	for sequence in _ping_sent_at:
		if now_msec - int(_ping_sent_at[sequence]) > TUNING.PING_SAMPLE_TIMEOUT_MSEC:
			expired.append(sequence)
	for sequence in expired:
		_ping_sent_at.erase(sequence)


## Both peers ping each other, so this runs on host and client alike. The
## sender check is the guard the CLAUDE.md rule asks for: only a peer ENet
## has actually admitted gets an answer, and one ping yields one pong, so a
## flood cannot be amplified.
@rpc("any_peer", "call_remote", "unreliable")
func _ping(sequence: int) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0 or not multiplayer.get_peers().has(sender):
		return
	_pong.rpc_id(sender, sequence, Time.get_ticks_msec())


@rpc("any_peer", "call_remote", "unreliable")
func _pong(sequence: int, responder_msec: int) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0 or not multiplayer.get_peers().has(sender):
		return
	var answered_by_host := sender == 1 and not multiplayer.is_server()
	_record_pong(sequence, responder_msec, Time.get_ticks_msec(), answered_by_host)


## Folds one pong into the smoothed RTT. `responder_msec` is the answering
## peer's clock at reply time; when the host answered, that also refines the
## host-clock offset (half the round trip is assumed to be the return leg).
## Unknown or already-answered sequence numbers are dropped, so a peer cannot
## forge a latency reading.
func _record_pong(sequence: int, responder_msec: int, now_msec: int, answered_by_host: bool) -> void:
	if not _ping_sent_at.has(sequence):
		return
	var sent_msec := int(_ping_sent_at[sequence])
	_ping_sent_at.erase(sequence)
	var rtt := maxi(now_msec - sent_msec, 0)
	_ping_msec = smooth_rtt(_ping_msec, float(rtt), TUNING.PING_SMOOTHING)
	if answered_by_host:
		var offset := float(responder_msec) - (float(sent_msec) + float(rtt) * 0.5)
		_host_clock_offset_msec = offset if not _clock_synced else lerpf(_host_clock_offset_msec, offset, TUNING.PING_SMOOTHING)
		_clock_synced = true
	ping_updated.emit(get_ping_msec())


## Exponential moving average; the first sample seeds it outright.
static func smooth_rtt(previous: float, sample: float, alpha: float) -> float:
	if previous < 0.0:
		return sample
	return lerpf(previous, sample, clampf(alpha, 0.0, 1.0))
