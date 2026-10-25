class_name BlinkAbility
extends DuelAbility

## Teleports a short distance along the travel direction, stopping short of
## walls. A blocked blink is refused rather than half-applied.

## Bit mask of the world (1), remote blobs (2) and arena props (8).
const BLINK_COLLISION_MASK := 11
const MINIMUM_BLINK_DISTANCE := 0.35
const WALL_CLEARANCE := 0.85


func _init() -> void:
	id = "blink"
	cooldown_msec = ABILITY_TUNING.BLINK_COOLDOWN_MSEC


func activate(game: Node, now: int) -> bool:
	var direction := DuelAbility.travel_direction(game)
	var origin: Vector3 = game.player.global_position
	var destination: Vector3 = origin + direction * ABILITY_TUNING.BLINK_RANGE
	var query := PhysicsRayQueryParameters3D.create(origin, destination)
	query.collision_mask = BLINK_COLLISION_MASK
	var excluded: Array[RID] = [game.player.get_rid()]
	var hurtbox := game.player.get_node_or_null("Hurtbox") as CollisionObject3D
	if hurtbox != null:
		excluded.append(hurtbox.get_rid())
	query.exclude = excluded
	var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		destination = Vector3(hit.get("position", origin)) - direction * WALL_CLEARANCE
	if destination.distance_to(origin) < MINIMUM_BLINK_DISTANCE:
		return false
	game._spawn_impact_burst(origin, Color(0.62, 0.22, 1.0), 0.6)
	game.player.global_position = destination
	game.camera_rig.global_position = destination + Vector3(0.0, 1.8, 0.0)
	game._spawn_impact_burst(destination, Color(0.72, 0.32, 1.0), 0.78)
	ready_at = now + cooldown_msec
	return true
