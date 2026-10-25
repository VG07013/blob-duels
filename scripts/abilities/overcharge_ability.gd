class_name OverchargeAbility
extends DuelAbility

## Raises the fire rate for a few seconds. The host mirrors the window in the
## peer's state so it can enforce the faster shot interval.


func _init() -> void:
	id = "overcharge"
	cooldown_msec = ABILITY_TUNING.OVERCHARGE_COOLDOWN_MSEC
	duration_msec = ABILITY_TUNING.OVERCHARGE_DURATION_MSEC
	host_validated = true


func activate(game: Node, now: int) -> bool:
	begin_window(now)
	game.player.set_overcharge_active(true)
	game._spawn_impact_burst(game.player.global_position, Color(1.0, 0.38, 0.06), 0.92)
	return true


func expire(game: Node, now: int) -> void:
	game.player.set_overcharge_active(false)
	super(game, now)


func reset(game: Node) -> void:
	game.player.set_overcharge_active(false)
	super(game)


func server_activate(_game: Node, _peer_id: int, state: ServerPeerState, now: int) -> bool:
	var window_end := now + duration_msec
	state.overcharge_end_at = window_end
	state.ability_ready_at = window_end + cooldown_msec
	return true
