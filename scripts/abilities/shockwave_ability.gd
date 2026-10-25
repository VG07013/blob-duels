class_name ShockwaveAbility
extends DuelAbility

## A radial shove that throws every nearby blob away and hops the caster. It
## is the escape tool: strong enough to break a corner trap, too slow to spam.


func _init() -> void:
	id = "shockwave"
	cooldown_msec = ABILITY_TUNING.SHOCKWAVE_COOLDOWN_MSEC
	host_validated = true


func activate(game: Node, now: int) -> bool:
	var origin: Vector3 = game.player.global_position
	if DuelAbility.is_online_client(game):
		game._request_network_ability.rpc_id(1, id)
	else:
		_push_others(game, game.local_peer_id, origin)
	game.player.apply_central_impulse(Vector3.UP * ABILITY_TUNING.SHOCKWAVE_SELF_HOP)
	game.player.trigger_launch_visual(0.6)
	game._spawn_impact_burst(origin, Color(1.0, 0.82, 0.22), 1.6)
	game._add_camera_shake(0.16)
	ready_at = now + cooldown_msec
	return true


func server_activate(game: Node, peer_id: int, state: ServerPeerState, now: int) -> bool:
	var caster := game.remote_players.get_node_or_null(game._remote_player_name(peer_id)) as Node3D
	if caster == null:
		return false
	state.ability_ready_at = now + cooldown_msec
	_push_others(game, peer_id, caster.global_position)
	game._spawn_impact_burst(caster.global_position, Color(1.0, 0.82, 0.22), 1.6)
	return true


## Applies the shove to every blob except the caster. Networked blobs go
## through the host's impact path so their health and position stay
## authoritative; practice dummies take it directly.
func _push_others(game: Node, caster_peer_id: int, origin: Vector3) -> void:
	var radius: float = ABILITY_TUNING.SHOCKWAVE_RADIUS
	var candidates: Array[Node] = [game.player]
	candidates.append_array(game.remote_players.get_children())
	candidates.append_array(game.get_tree().get_nodes_in_group("training_dummy"))
	for candidate in candidates:
		var target := candidate as Node3D
		if target == null:
			continue
		var offset: Vector3 = target.global_position - origin
		var distance := offset.length()
		if distance > radius or distance < 0.001:
			continue
		var falloff := 1.0 - distance / (radius * ABILITY_TUNING.SHOCKWAVE_FALLOFF_STRETCH)
		var impulse := (offset.normalized() + Vector3.UP * ABILITY_TUNING.SHOCKWAVE_LIFT).normalized() * ABILITY_TUNING.SHOCKWAVE_STRENGTH * falloff
		if target.is_in_group("network_blob"):
			var target_peer_id := int(target.get("network_peer_id"))
			if target_peer_id == caster_peer_id:
				continue
			if target == game.player:
				game.player.receive_collision_impact(0, impulse)
			else:
				game._apply_server_peer_impact(target_peer_id, 0, impulse, false)
		elif target.has_method("receive_collision_impact"):
			target.call("receive_collision_impact", 0, impulse)
