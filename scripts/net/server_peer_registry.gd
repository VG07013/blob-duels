class_name ServerPeerRegistry
extends RefCounted

## Owns the ServerPeerState for every peer the host is simulating.
##
## Only meaningful on the host: clients never populate this. Entries are created
## on demand so a request that arrives before the join handler still sees sane
## defaults rather than a missing key.

const PEER_STATE := preload("res://scripts/net/server_peer_state.gd")

## Health a freshly created entry starts at. Set once from Player.max_health so
## an on-demand entry matches what the old `.get(peer_id, player.max_health)`
## defaults returned.
var default_health := 0

var _states: Dictionary = {}


func _init(starting_health: int = 0) -> void:
	default_health = starting_health


## Returns this peer's state, creating it if the peer is new.
func state_for(peer_id: int) -> ServerPeerState:
	var existing := _states.get(peer_id) as ServerPeerState
	if existing != null:
		return existing
	var created := PEER_STATE.new() as ServerPeerState
	created.health = default_health
	_states[peer_id] = created
	return created


## Returns this peer's state, or null when the peer is unknown. Use when the
## absence of a peer is meaningful and a fresh entry would be wrong.
func peek(peer_id: int) -> ServerPeerState:
	return _states.get(peer_id) as ServerPeerState


func has(peer_id: int) -> bool:
	return _states.has(peer_id)


func peer_ids() -> Array:
	return _states.keys()


## Drops a peer entirely, freeing any mine it still owns. Used on disconnect,
## where the old code needed eleven separate erase() calls.
func remove(peer_id: int) -> void:
	var state := peek(peer_id)
	if state == null:
		return
	state.clear_bounce_mine()
	_states.erase(peer_id)


## Resets every peer for a new match without forgetting who is connected or
## which ability they registered at join.
func reset_for_match() -> void:
	for state_value in _states.values():
		var state := state_value as ServerPeerState
		state.clear_bounce_mine()
		state.reset_for_match(default_health)
