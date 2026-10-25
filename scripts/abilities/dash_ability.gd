class_name DashAbility
extends DuelAbility

## A short burst along the blob's travel direction. Purely local: it only moves
## the blob that pressed it, and the host validates the resulting position like
## any other movement.


func _init() -> void:
	id = "dash"
	cooldown_msec = ABILITY_TUNING.DASH_COOLDOWN_MSEC
	duration_msec = ABILITY_TUNING.DASH_DURATION_MSEC


func activate(game: Node, now: int) -> bool:
	var direction := DuelAbility.travel_direction(game)
	game.player.apply_central_impulse(direction * ABILITY_TUNING.DASH_IMPULSE + Vector3.UP * ABILITY_TUNING.DASH_LIFT)
	game.player.trigger_launch_visual(0.88)
	game._fling_fov_kick = maxf(game._fling_fov_kick, ABILITY_TUNING.DASH_FOV_KICK)
	game._spawn_impact_burst(game.player.global_position, Color(0.12, 0.6, 1.0), 0.85)
	begin_window(now)
	return true
