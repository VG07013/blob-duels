extends SceneTree

## Guards the host-side peer state that used to live in eleven parallel
## dictionaries inside game.gd. The defaults here are load-bearing: every read
## site previously supplied its own fallback (max health, zero cooldown, spawn
## position), so an entry created on demand has to match those exactly.

const REGISTRY := preload("res://scripts/net/server_peer_registry.gd")

var failures: Array[String] = []


func _initialize() -> void:
	var registry = REGISTRY.new()
	registry.default_health = 150

	# An unknown peer must read as full health, not zero, because requests can
	# arrive before the join handler registers the peer.
	var fresh = registry.state_for(2)
	_check(fresh != null, "state_for must create an entry for an unknown peer")
	_check(fresh.health == 150, "A created entry must start at default_health")
	_check(fresh.shot_ready_at == 0, "A created entry must start with no shot cooldown")
	_check(fresh.ability_ready_at == 0, "A created entry must start with no ability cooldown")
	_check(fresh.equipped_ability == "", "A created entry must start with no equipped ability")
	_check(not fresh.loadout_registered, "A created entry must not count as having registered a loadout")
	_check(not fresh.has_reported_position, "A created entry must not claim a reported position")

	_check(registry.state_for(2) == fresh, "state_for must return the same instance for a known peer")
	_check(registry.has(2), "has must report a created peer")
	_check(registry.peek(99) == null, "peek must return null for an unknown peer rather than creating one")
	_check(not registry.has(99), "peek must not create an entry")

	# position_or keeps the old `.get(peer_id, spawn)` behaviour: fall back to
	# spawn until the peer has actually reported somewhere.
	var spawn := Vector3(4.0, 1.0, -9.0)
	_check(fresh.position_or(spawn) == spawn, "An unreported peer must fall back to the supplied spawn")
	fresh.note_position(Vector3.ZERO, 1234)
	_check(fresh.has_reported_position, "note_position must mark the peer as having reported")
	_check(fresh.position_or(spawn) == Vector3.ZERO, "A reported origin must not be mistaken for an unreported peer")
	_check(fresh.last_state_msec == 1234, "note_position must record the timestamp")

	# A loadout is registered once at join and must survive a match reset;
	# everything else about the peer must not.
	fresh.equipped_ability = "rail_shot"
	fresh.loadout_registered = true
	fresh.health = 25
	fresh.shot_ready_at = 9000
	fresh.ability_ready_at = 9000
	fresh.ricochet_loaded = true
	fresh.rail_charge_end_at = 9000
	fresh.overcharge_end_at = 9000
	fresh.phase_end_at = 9000
	fresh.gravity_end_at = 9000
	registry.reset_for_match()
	_check(fresh.equipped_ability == "rail_shot", "A match reset must keep the registered loadout")
	_check(fresh.loadout_registered, "A match reset must keep the loadout-registered flag")
	_check(fresh.health == 150, "A match reset must restore full health")
	_check(fresh.shot_ready_at == 0, "A match reset must clear the shot cooldown")
	_check(fresh.ability_ready_at == 0, "A match reset must clear the ability cooldown")
	_check(not fresh.ricochet_loaded, "A match reset must clear a loaded ricochet")
	_check(fresh.rail_charge_end_at == 0, "A match reset must clear the rail charge")
	_check(fresh.overcharge_end_at == 0, "A match reset must clear overcharge")
	_check(fresh.phase_end_at == 0, "A match reset must clear the phase bubble")
	_check(fresh.gravity_end_at == 0, "A match reset must clear the gravity pulse")
	_check(not fresh.has_reported_position, "A match reset must forget the last reported position")
	_check(registry.has(2), "A match reset must not drop connected peers")

	# A disconnect drops everything, which is what the eleven erase() calls did.
	registry.state_for(3)
	registry.remove(3)
	_check(not registry.has(3), "remove must drop the peer entirely")
	_check(registry.peek(3) == null, "A removed peer must not be readable")
	registry.remove(4)
	_check(not registry.has(4), "Removing an unknown peer must be a no-op")

	_check(registry.peer_ids().size() == 1, "peer_ids must list exactly the live peers")

	if failures.is_empty():
		print("SERVER PEER REGISTRY CONTRACT PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("SERVER PEER REGISTRY CONTRACT FAILURES: %d" % failures.size())
	quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
