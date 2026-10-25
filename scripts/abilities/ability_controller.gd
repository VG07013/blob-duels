class_name AbilityController
extends RefCounted

## Owns the local blob's equipped ability instance and the host-side ability
## table. game.gd talks to this instead of to any ability by name.

const REGISTRY := preload("res://scripts/abilities/ability_registry.gd")

var current: DuelAbility = null
## Stateless host-side instances, one per id, used to validate and apply
## remote peers' requests against their ServerPeerState.
var _server_abilities: Dictionary = {}


## Makes `ability_id` the equipped ability, interrupting whatever was active
## before if the id changed. Returns null for an unknown id.
func ensure(game: Node, ability_id: String, now: int) -> DuelAbility:
	if current != null and current.id == ability_id:
		return current
	if current != null:
		current.interrupt(game, now)
		current.reset(game)
	current = REGISTRY.create(ability_id)
	return current


func process(game: Node, now: int, delta: float) -> void:
	if current == null or current.end_at <= 0:
		return
	if now >= current.end_at:
		current.expire(game, now)
	else:
		current.tick(game, now, delta)


func interrupt(game: Node, now: int) -> void:
	if current != null:
		current.interrupt(game, now)


func reset(game: Node) -> void:
	if current != null:
		current.reset(game)


func is_active(now: int) -> bool:
	return current != null and current.is_active(now)


func locks_shooting(now: int) -> bool:
	return current != null and current.locks_shooting(now)


## Spends an armed ricochet shot if the equipped ability is one.
func consume_ricochet(now: int) -> bool:
	var ricochet := current as RicochetAbility
	return ricochet != null and ricochet.consume(now)


func server_ability(ability_id: String) -> DuelAbility:
	if not _server_abilities.has(ability_id):
		var ability := REGISTRY.create(ability_id)
		if ability == null:
			return null
		_server_abilities[ability_id] = ability
	return _server_abilities[ability_id]


## Host-side entry point for a remote peer's request. Returns true when the
## request was valid and applied.
func server_request(game: Node, peer_id: int, ability_id: String, state: ServerPeerState, now: int) -> bool:
	if not bool(game._is_server_ability_request_allowed(peer_id, ability_id, now)):
		return false
	return server_ability(ability_id).server_activate(game, peer_id, state, now)
