class_name ServerPeerState
extends RefCounted

## Server-authoritative state for a single peer in a duel.
##
## The host owns every field here. Clients send requests; the host decides what
## actually happened and replicates the result. Grouping the fields per peer
## means a join, a round reset, or a disconnect touches one entry instead of
## eleven parallel dictionaries that each needed their own erase() line.

## Health the host believes this peer has. Authoritative over the client's
## own view, which is why _report_round_death cross-checks against it.
var health := 0

## Earliest tick this peer may fire again. Enforced host-side so a client
## cannot raise its own fire rate.
var shot_ready_at := 0
var ability_ready_at := 0

## Ability chosen at match setup. Validated once against the supported list,
## then treated as fixed for the session: _is_server_ability_request_allowed
## rejects any request that does not match it.
var equipped_ability := ""
var loadout_registered := false

var ricochet_loaded := false
var rail_charge_end_at := 0
var overcharge_end_at := 0
var phase_end_at := 0
var gravity_end_at := 0

## Hotbar slot the peer last reported (CombatTuning.SLOT_*). The host refuses
## shots while it is the Blob slot and uses it for the Blob ram bonus. It is
## the player's choice, so it survives match resets.
var hotbar_slot := 0

## The one bounce mine this peer may have live at a time.
var bounce_mine: Node = null

## Last position the host accepted from this peer, used to bound the next
## claimed step in _sanitize_remote_position. `has_reported_position` keeps the
## "never heard from" case distinct from "reported the origin".
var last_state_position := Vector3.ZERO
var last_state_msec := 0
var has_reported_position := false


## Every round starts with cooldowns and timed ability effects cleared, so a
## late-round cast never carries into the next round.
func reset_for_round() -> void:
	shot_ready_at = 0
	ability_ready_at = 0
	ricochet_loaded = false
	rail_charge_end_at = 0
	overcharge_end_at = 0
	phase_end_at = 0
	gravity_end_at = 0


## Resets everything a new match should start clean, while keeping the peer's
## registered loadout, which is chosen once at join and outlives the match.
func reset_for_match(full_health: int) -> void:
	health = full_health
	reset_for_round()
	last_state_position = Vector3.ZERO
	last_state_msec = 0
	has_reported_position = false


func note_position(world_position: Vector3, now_msec: int) -> void:
	last_state_position = world_position
	last_state_msec = now_msec
	has_reported_position = true


## Returns the accepted position, or `fallback` if this peer has not reported
## one yet, so callers keep the pre-registry behaviour of defaulting to spawn.
func position_or(fallback: Vector3) -> Vector3:
	return last_state_position if has_reported_position else fallback


func clear_bounce_mine() -> void:
	if is_instance_valid(bounce_mine):
		bounce_mine.queue_free()
	bounce_mine = null
