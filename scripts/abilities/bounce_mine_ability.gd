class_name BounceMineAbility
extends DuelAbility

## Drops a mine that launches whoever triggers it. Online, only the host spawns
## the authoritative mine; a client asks first and receives the replicated one.


func _init() -> void:
	id = "bounce_mine"
	cooldown_msec = ABILITY_TUNING.BOUNCE_MINE_COOLDOWN_MSEC
	host_validated = true


func activate(game: Node, now: int) -> bool:
	if DuelAbility.is_online_client(game):
		game._request_network_ability.rpc_id(1, id)
	elif DuelAbility.is_online_host(game):
		game._server_peers.state_for(game.local_peer_id).ability_ready_at = now + cooldown_msec
		game._server_spawn_bounce_mine(game.local_peer_id)
	else:
		game._spawn_bounce_mine()
	ready_at = now + cooldown_msec
	return true


func is_deployed(game: Node) -> bool:
	return is_instance_valid(game._active_bounce_mine)


func reset(game: Node) -> void:
	if is_instance_valid(game._active_bounce_mine):
		game._active_bounce_mine.queue_free()
	game._active_bounce_mine = null
	super(game)


func server_activate(game: Node, peer_id: int, state: ServerPeerState, now: int) -> bool:
	state.ability_ready_at = now + cooldown_msec
	game._server_spawn_bounce_mine(peer_id)
	return true
