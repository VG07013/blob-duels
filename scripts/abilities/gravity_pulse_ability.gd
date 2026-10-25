class_name GravityPulseAbility
extends DuelAbility

## Bends incoming projectiles around the blob for a moment. The host runs the
## same deflection for remote peers from their state window.


func _init() -> void:
	id = "gravity_pulse"
	cooldown_msec = ABILITY_TUNING.GRAVITY_PULSE_COOLDOWN_MSEC
	duration_msec = ABILITY_TUNING.GRAVITY_PULSE_DURATION_MSEC
	host_validated = true


func activate(game: Node, now: int) -> bool:
	begin_window(now)
	game._spawn_impact_burst(game.player.global_position, Color(0.42, 0.12, 0.82), 1.1)
	return true


func tick(game: Node, _now: int, delta: float) -> void:
	game._deflect_projectiles_around(game.player, delta)


func server_activate(_game: Node, _peer_id: int, state: ServerPeerState, now: int) -> bool:
	var window_end := now + duration_msec
	state.gravity_end_at = window_end
	state.ability_ready_at = window_end + cooldown_msec
	return true
