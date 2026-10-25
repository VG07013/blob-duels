class_name RailShotAbility
extends DuelAbility

## Locks the trigger for a one-second charge, then fires a heavy piercing shot
## along the aim line. The active window is the charge; expiry is the shot.


func _init() -> void:
	id = "rail_shot"
	cooldown_msec = ABILITY_TUNING.RAIL_SHOT_COOLDOWN_MSEC
	duration_msec = ABILITY_TUNING.RAIL_SHOT_CHARGE_MSEC
	host_validated = true


func activate(game: Node, now: int) -> bool:
	begin_window(now)
	game.player.set_shooting_locked(true)
	game._show_rail_telegraph()
	return true


func tick(game: Node, _now: int, _delta: float) -> void:
	game._update_rail_telegraph()


func locks_shooting(now: int) -> bool:
	return is_active(now)


## The charge completing is the shot.
func expire(game: Node, now: int) -> void:
	_release(game)
	var direction: Vector3 = game.player.aim_direction.normalized()
	if direction.length_squared() <= 0.001:
		direction = Vector3.FORWARD
	var origin: Vector3 = game.player.global_position + direction * 3.75 + Vector3.UP * 0.25
	if not game.network_session.is_online():
		game._spawn_projectile(game.local_peer_id, origin, direction, true, false, true)
	elif game.multiplayer.is_server():
		game._server_spawn_shot(game.local_peer_id, origin, direction, false, true)
	else:
		game._request_network_shot.rpc_id(1, origin, direction, false, true)
	game._spawn_impact_burst(game.player.global_position, Color(0.95, 0.98, 1.0), 1.05)
	game._add_camera_shake(0.08)
	game.audio_manager.play_sfx(&"projectile_fire", -1.5, 0.72)
	super(game, now)


## A knockout mid-charge loses the shot but still pays the cooldown.
func interrupt(game: Node, now: int) -> void:
	if end_at <= 0:
		return
	_release(game)
	end_at = 0
	ready_at = now + cooldown_msec


func reset(game: Node) -> void:
	_release(game)
	super(game)


func _release(game: Node) -> void:
	game._clear_rail_telegraph()
	game.player.set_shooting_locked(false)


func server_allowed(state: ServerPeerState, now: int) -> bool:
	return super(state, now) and state.rail_charge_end_at == 0


func server_activate(_game: Node, _peer_id: int, state: ServerPeerState, now: int) -> bool:
	state.rail_charge_end_at = now + duration_msec
	return true
