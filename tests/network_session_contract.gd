extends SceneTree

## Guards the infrastructure-free Internet path of the NetworkSession autoload:
## the UPnP mapping state machine (driven by a fake router so no network is
## touched), the room-code encoding for public and private IPv4, and the
## ping/RTT smoothing plus host-clock offset that the snapshot interpolation
## relies on.

const HUD_SCENE := preload("res://scenes/hud.tscn")
const NETWORK_SESSION_SCRIPT := preload("res://scripts/network_session.gd")
const TUNING := preload("res://scripts/net/network_tuning.gd")

const PUBLIC_ADDRESS := "203.0.113.7"
const PUBLIC_CODE := "CB00-7107"

var failures: Array[String] = []


## Stand-in for Godot's UPNP with the same surface the session uses.
class FakeUpnp:
	extends RefCounted
	var discover_result := 0
	var map_result := 0
	var external_address := "203.0.113.7"
	var discover_calls := 0
	var mapped: Array = []
	var deleted: Array = []

	func discover(_timeout_msec: int, _ttl: int, _device_filter: String) -> int:
		discover_calls += 1
		return discover_result

	func add_port_mapping(port: int, _internal_port: int, _description: String, protocol: String, _duration: int) -> int:
		if map_result == 0:
			mapped.append([port, protocol])
		return map_result

	func query_external_address() -> String:
		return external_address

	func delete_port_mapping(port: int, protocol: String) -> int:
		deleted.append([port, protocol])
		return 0


func _init() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _run() -> void:
	var session := root.get_node_or_null("NetworkSession")
	if session == null:
		_fail_and_quit("NetworkSession autoload must be available to host a game")
		return
	var hud := HUD_SCENE.instantiate()
	root.add_child(hud)
	await process_frame

	await _test_upnp_success_path(session, hud)
	await _test_upnp_router_missing(session)
	await _test_upnp_carrier_nat(session)
	await _test_upnp_disabled(session)
	_test_stale_worker_unmaps(session)
	_test_room_code_round_trip()
	_test_public_ipv4_classifier()
	_test_ping_smoothing(session)
	_test_ping_hud(hud)

	session.call("close_session")
	await process_frame
	_finish()


func _test_port() -> int:
	return 20000 + (int(OS.get_process_id()) + 7) % 30000


func _await_upnp_settled(session: Node) -> void:
	for _frame in range(240):
		if int(session.get("upnp_state")) != NETWORK_SESSION_SCRIPT.UpnpState.DISCOVERING:
			return
		await process_frame


func _test_upnp_success_path(session: Node, hud: Node) -> void:
	var fake := FakeUpnp.new()
	fake.external_address = PUBLIC_ADDRESS
	session.set("upnp_enabled", true)
	session.set("_upnp_factory", func() -> Variant: return fake)
	var ready_codes: Array[String] = []
	var on_ready := func(code: String) -> void: ready_codes.append(code)
	session.connect("public_address_ready", on_ready)

	var port := _test_port()
	var host_result := int(session.call("host_game", port))
	if host_result != OK:
		_check(false, "Contract setup: could not open a local host session on port %d" % port)
		session.disconnect("public_address_ready", on_ready)
		return
	_check(int(session.get("upnp_state")) == NETWORK_SESSION_SCRIPT.UpnpState.DISCOVERING, "Hosting must start router discovery immediately")
	_check("LAN code:" in str(session.get("status_message")), "While the router is being asked, the host status must already show the LAN code")
	_check(str(session.call("get_public_room_code")).is_empty(), "No Internet code may be advertised before the router has answered")

	await _await_upnp_settled(session)
	_check(int(session.get("upnp_state")) == NETWORK_SESSION_SCRIPT.UpnpState.MAPPED, "A cooperative router must leave UPnP in the MAPPED state")
	_check(fake.mapped == [[port, "UDP"]], "Hosting must map exactly the game's UDP port on the router")
	_check(str(session.call("get_public_room_code")) == PUBLIC_CODE, "The Internet code must encode the router's public IPv4 with the room-code scheme")
	_check(ready_codes == [PUBLIC_CODE], "public_address_ready must fire once with the Internet code")
	_check(bool(session.call("has_public_address")), "has_public_address must report true once mapped")
	_check(str(session.call("get_share_room_code")) == PUBLIC_CODE, "The code a host is told to share must be the Internet code when one exists")
	var status := str(session.get("status_message"))
	_check(status.begins_with("Internet code: %s · LAN code: " % PUBLIC_CODE), "Host status must tell the host which code to share: 'Internet code: XXXX-XXXX · LAN code: YYYY'")
	_check("removed when hosting stops" in status, "Host status must keep the security note that the router mapping is removed when hosting stops")
	_check(int(session.get("state")) == NETWORK_SESSION_SCRIPT.SessionState.HOSTING, "UPnP success must not disturb the HOSTING session state")

	# The menu's room-code label must pick the Internet code up without a manual refresh.
	var room_code_label := hud.find_child("RoomCode", true, false) as Label
	_check(room_code_label.text.begins_with("INTERNET CODE  %s" % PUBLIC_CODE), "Menu room-code label must lead with the Internet code once it is ready")
	_check("LAN CODE" in room_code_label.text, "Menu room-code label must keep the LAN code as the fallback")
	var copy_button := hud.find_child("CopyButton", true, false) as Button
	_check(copy_button != null and copy_button.text == "COPY INTERNET CODE", "Copy button must offer the Internet code once it is ready")

	session.call("close_session")
	await process_frame
	_check(fake.deleted == [[port, "UDP"]], "Stopping hosting must remove the router mapping it created")
	_check(int(session.get("upnp_state")) == NETWORK_SESSION_SCRIPT.UpnpState.IDLE, "Closing the session must return UPnP to IDLE")
	_check(str(session.call("get_public_room_code")).is_empty(), "No Internet code may survive close_session")
	_check(str(session.call("get_share_room_code")) == str(session.call("get_host_room_code")), "With no mapping the shared code must fall back to the LAN code")
	hud.call("_refresh_room_code")
	_check(room_code_label.text.begins_with("LAN CODE  "), "Menu room-code label must fall back to the LAN code after hosting stops")
	_check(copy_button != null and copy_button.text == "COPY LAN CODE", "Copy button must fall back to the LAN code after hosting stops")
	session.disconnect("public_address_ready", on_ready)


func _test_upnp_router_missing(session: Node) -> void:
	var fake := FakeUpnp.new()
	fake.discover_result = UPNP.UPNP_RESULT_NO_DEVICES
	session.set("_upnp_factory", func() -> Variant: return fake)
	var port := _test_port()
	if int(session.call("host_game", port)) != OK:
		_check(false, "Contract setup: could not open a local host session for the no-router case")
		return
	await _await_upnp_settled(session)
	_check(int(session.get("upnp_state")) == NETWORK_SESSION_SCRIPT.UpnpState.FAILED, "No router answering must leave UPnP in the FAILED state")
	_check(fake.mapped.is_empty(), "No mapping may be attempted when discovery fails")
	_check(str(session.call("get_public_room_code")).is_empty(), "A failed discovery must not advertise an Internet code")
	var status := str(session.get("status_message"))
	_check("LAN code:" in status and "no Internet code" in status, "When UPnP fails the host must still be told the LAN code and that there is no Internet code")
	_check("UDP %d" % port in status, "When UPnP fails the host must be told which UDP port to forward by hand")
	_check(int(session.get("state")) == NETWORK_SESSION_SCRIPT.SessionState.HOSTING, "UPnP failure must keep the LAN session hosting")
	session.call("close_session")
	await process_frame
	_check(fake.deleted.is_empty(), "Nothing may be unmapped when nothing was mapped")


func _test_upnp_carrier_nat(session: Node) -> void:
	var fake := FakeUpnp.new()
	fake.external_address = "100.64.3.3"
	session.set("_upnp_factory", func() -> Variant: return fake)
	var port := _test_port()
	if int(session.call("host_game", port)) != OK:
		_check(false, "Contract setup: could not open a local host session for the carrier-NAT case")
		return
	await _await_upnp_settled(session)
	_check(int(session.get("upnp_state")) == NETWORK_SESSION_SCRIPT.UpnpState.FAILED, "A router without a public address must count as a UPnP failure")
	_check(fake.mapped.size() == 1 and fake.deleted.size() == 1, "A mapping behind carrier NAT must be removed immediately because it can never be reached")
	_check(str(session.call("get_public_room_code")).is_empty(), "A private WAN address must never become an Internet code")
	session.call("close_session")
	await process_frame


func _test_upnp_disabled(session: Node) -> void:
	var fake := FakeUpnp.new()
	session.set("_upnp_factory", func() -> Variant: return fake)
	session.set("upnp_enabled", false)
	var port := _test_port()
	if int(session.call("host_game", port)) != OK:
		_check(false, "Contract setup: could not open a local host session for the disabled case")
		session.set("upnp_enabled", true)
		return
	await process_frame
	_check(int(session.get("upnp_state")) == NETWORK_SESSION_SCRIPT.UpnpState.DISABLED, "upnp_enabled = false must report the DISABLED state")
	_check(fake.discover_calls == 0, "upnp_enabled = false must never touch the router")
	_check("LAN code:" in str(session.get("status_message")), "With UPnP off the host must still be given the LAN code")
	session.call("close_session")
	await process_frame
	session.set("upnp_enabled", true)


func _test_stale_worker_unmaps(session: Node) -> void:
	# A discovery that finishes after hosting stopped must tear down what it
	# opened rather than leave a silent hole in the router.
	var fake := FakeUpnp.new()
	var stale_generation := int(session.get("_upnp_generation")) - 1
	var state_before := int(session.get("upnp_state"))
	session.call("_on_upnp_worker_finished", stale_generation, {"ok": true, "address": PUBLIC_ADDRESS, "device": fake, "port": 4242})
	_check(fake.deleted == [[4242, "UDP"]], "A mapping completed after hosting stopped must be removed straight away")
	_check(int(session.get("upnp_state")) == state_before, "A stale worker result must not change the UPnP state")
	_check(str(session.call("get_public_room_code")).is_empty(), "A stale worker result must not advertise an Internet code")


func _test_room_code_round_trip() -> void:
	for address in ["203.0.113.7", "8.8.4.4", "192.168.1.42", "10.0.0.1", "172.16.5.9"]:
		var code := str(NETWORK_SESSION_SCRIPT.address_to_room_code(address))
		_check(code.length() == 9 and code[4] == "-", "Room codes must stay the XXXX-XXXX shape for %s" % address)
		_check(str(NETWORK_SESSION_SCRIPT.room_code_to_address(code)) == address, "Room code for %s must decode back to the same address" % address)
	_check(str(NETWORK_SESSION_SCRIPT.address_to_room_code(PUBLIC_ADDRESS)) == PUBLIC_CODE, "Public addresses must use the same encoding as LAN codes")
	_check(str(NETWORK_SESSION_SCRIPT.room_code_to_address("cb00-7107")) == PUBLIC_ADDRESS, "Room codes must decode case-insensitively")
	_check(str(NETWORK_SESSION_SCRIPT.room_code_to_address("CB007107")).is_empty(), "Room codes without the dash must be rejected")


func _test_public_ipv4_classifier() -> void:
	for address in ["203.0.113.7", "8.8.4.4", "1.2.3.4", "223.255.255.1"]:
		_check(bool(NETWORK_SESSION_SCRIPT._is_public_ipv4(address)), "%s must count as a public address" % address)
	for address in ["192.168.1.1", "10.0.0.1", "172.16.0.1", "172.31.255.255", "127.0.0.1", "0.0.0.0", "169.254.1.1", "100.64.0.1", "100.127.255.255", "224.0.0.1", "255.255.255.255", "", "not.an.ip", "1.2.3"]:
		_check(not bool(NETWORK_SESSION_SCRIPT._is_public_ipv4(address)), "%s must not count as a public address" % address)


func _test_ping_smoothing(session: Node) -> void:
	var updates: Array[int] = []
	var on_ping := func(msec: int) -> void: updates.append(msec)
	session.connect("ping_updated", on_ping)
	session.call("_reset_ping")
	_check(int(session.call("get_ping_msec")) == -1, "Ping must read -1 before the first pong so the HUD can hide it")

	session.call("_register_ping_sent", 1, 1000)
	session.call("_record_pong", 1, 0, 1050, false)
	_check(int(session.call("get_ping_msec")) == 50, "The first pong must seed the RTT readout directly")
	session.call("_register_ping_sent", 2, 2000)
	session.call("_record_pong", 2, 0, 2150, false)
	var expected := int(round(50.0 + TUNING.PING_SMOOTHING * (150.0 - 50.0)))
	_check(int(session.call("get_ping_msec")) == expected, "Later pongs must blend into the RTT with the tuned EMA weight")
	session.call("_record_pong", 2, 0, 2500, false)
	_check(int(session.call("get_ping_msec")) == expected, "A pong for an already-answered sequence must be ignored")
	session.call("_record_pong", 99, 0, 2500, false)
	_check(int(session.call("get_ping_msec")) == expected, "A pong for a sequence that was never sent must be ignored")
	_check(updates == [50, expected], "ping_updated must fire once per accepted pong with the smoothed value")

	_check(NETWORK_SESSION_SCRIPT.smooth_rtt(-1.0, 80.0, 0.25) == 80.0, "smooth_rtt must seed from the first sample")
	_check(is_equal_approx(NETWORK_SESSION_SCRIPT.smooth_rtt(80.0, 120.0, 0.25), 90.0), "smooth_rtt must apply an exponential moving average")

	session.call("_register_ping_sent", 3, 3000)
	session.call("_record_pong", 3, 10050, 3100, true)
	_check(is_equal_approx(float(session.call("get_host_clock_offset_msec")), 7000.0), "A host-answered pong must estimate the host clock as responder time minus half the round trip")

	session.call("_register_ping_sent", 4, 100)
	session.call("_register_ping_sent", 5, 100 + TUNING.PING_SAMPLE_TIMEOUT_MSEC + 1)
	_check(not (session.get("_ping_sent_at") as Dictionary).has(4), "Unanswered pings must be forgotten after the sample timeout")

	session.call("_reset_ping")
	_check(int(session.call("get_ping_msec")) == -1, "Resetting the session must clear the RTT readout")
	session.disconnect("ping_updated", on_ping)


func _test_ping_hud(hud: Node) -> void:
	var label := hud.get_node_or_null("PingLabel") as Label
	_check(label != null, "The duel HUD must carry a PingLabel")
	if label == null:
		return
	_check(not label.visible, "The ping readout must be hidden while offline")
	_check(label.anchor_left == 1.0 and label.anchor_top == 1.0, "The ping readout sits in the bottom-right corner of the duel HUD")
	hud.call("_update_ping_label", 42)
	_check(label.text == "PING 42 ms", "The ping readout must print the round trip in milliseconds")
	_check(not label.visible, "A ping reading must not surface the label while the session is offline")
	var green: Color = hud.ping_readout_color(TUNING.PING_GOOD_MSEC - 1)
	var amber: Color = hud.ping_readout_color(TUNING.PING_FAIR_MSEC - 1)
	var red: Color = hud.ping_readout_color(TUNING.PING_FAIR_MSEC)
	_check(green.g > green.r and green.g > green.b, "Pings under %d ms must read green" % TUNING.PING_GOOD_MSEC)
	_check(amber.r > amber.b and amber.g > amber.b and amber.r > amber.g, "Pings under %d ms must read amber" % TUNING.PING_FAIR_MSEC)
	_check(red.r > red.g and red.r > red.b, "Pings of %d ms or more must read red" % TUNING.PING_FAIR_MSEC)
	_check(TUNING.PING_GOOD_MSEC == 60 and TUNING.PING_FAIR_MSEC == 120, "Ping colour thresholds are 60 ms (green) and 120 ms (amber)")


func _fail_and_quit(message: String) -> void:
	push_error(message)
	quit(1)


func _finish() -> void:
	if failures.is_empty():
		print("NETWORK SESSION CONTRACT PASS")
		quit(0)
		return
	for failure in failures:
		push_error("NETWORK SESSION CONTRACT FAIL: %s" % failure)
	quit(1)
