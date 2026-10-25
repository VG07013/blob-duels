class_name RicochetAbility
extends DuelAbility

## Arms the next shot to bounce off the arena. The cooldown starts when the
## shot is spent, not when it is armed, so a loaded ricochet cannot be re-armed.


var _loaded := false


func _init() -> void:
	id = "ricochet_shot"
	cooldown_msec = ABILITY_TUNING.RICOCHET_COOLDOWN_MSEC
	host_validated = true


func activate(_game: Node, _now: int) -> bool:
	if _loaded:
		return false
	_loaded = true
	return true


func is_loaded() -> bool:
	return _loaded


## Spends the armed shot. Returns true when the outgoing projectile should
## ricochet.
func consume(now: int) -> bool:
	if not _loaded:
		return false
	_loaded = false
	ready_at = now + cooldown_msec
	return true


func interrupt(_game: Node, now: int) -> void:
	consume(now)


func reset(_game: Node) -> void:
	super(_game)
	_loaded = false


func server_allowed(state: ServerPeerState, now: int) -> bool:
	return super(state, now) and not state.ricochet_loaded


func server_activate(_game: Node, _peer_id: int, state: ServerPeerState, _now: int) -> bool:
	state.ricochet_loaded = true
	return true
