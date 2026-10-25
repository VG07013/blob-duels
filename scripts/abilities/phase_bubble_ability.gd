class_name PhaseBubbleAbility
extends DuelAbility

## A few seconds of projectile immunity. Both the start and the end are
## replicated so remote visuals never go stale.


func _init() -> void:
	id = "phase_bubble"
	cooldown_msec = ABILITY_TUNING.PHASE_BUBBLE_COOLDOWN_MSEC
	duration_msec = ABILITY_TUNING.PHASE_BUBBLE_DURATION_MSEC
	host_validated = true


func activate(game: Node, now: int) -> bool:
	begin_window(now)
	game.player.set_phase_bubble(true)
	if DuelAbility.is_online_host(game):
		game._replicate_phase_bubble.rpc(game.local_peer_id, true)
	game._spawn_impact_burst(game.player.global_position, Color(0.12, 0.76, 1.0), 1.05)
	return true


func expire(game: Node, now: int) -> void:
	game.player.set_phase_bubble(false)
	if DuelAbility.is_online_host(game):
		game._replicate_phase_bubble.rpc(game.local_peer_id, false)
	super(game, now)


func reset(game: Node) -> void:
	game.player.set_phase_bubble(false)
	super(game)


func server_activate(game: Node, peer_id: int, state: ServerPeerState, now: int) -> bool:
	var window_end := now + duration_msec
	state.phase_end_at = window_end
	state.ability_ready_at = window_end + cooldown_msec
	var remote: Node = game.remote_players.get_node_or_null(game._remote_player_name(peer_id))
	if remote != null:
		remote.call("set_phase_bubble", true)
	game._replicate_phase_bubble.rpc(peer_id, true)
	return true
