class_name SpawnManager
extends Node3D

@export var arena_half_extent := 58.0
@export var fall_limit := -22.0
@export var lobby_center := Vector3(0.0, 0.0, 72.0)
@export var lobby_radius := 15.0

@onready var fallback_spawn: Marker3D = $FallbackSpawn

var _active_spawns: Array[Marker3D] = []
var _practice_half_extent := 58.0
var _practice_fall_limit := -22.0
var _arena_half_width := 58.0
var _arena_half_length := 58.0
var _using_authored_competitive_spawns := false


func _ready() -> void:
	_practice_half_extent = arena_half_extent
	_practice_fall_limit = fall_limit
	_arena_half_width = arena_half_extent
	_arena_half_length = arena_half_extent
	use_practice_map()


func use_practice_map() -> void:
	_active_spawns = _scene_spawn_points($ArenaSpawns)
	_using_authored_competitive_spawns = false
	arena_half_extent = _practice_half_extent
	_arena_half_width = _practice_half_extent
	_arena_half_length = _practice_half_extent
	fall_limit = _practice_fall_limit


func use_competitive_map(arena: Node3D) -> void:
	_active_spawns.clear()
	_using_authored_competitive_spawns = false
	if arena != null and arena.has_method("get_spawn_points"):
		for point in arena.call("get_spawn_points"):
			var marker := point as Marker3D
			if marker != null:
				_active_spawns.append(marker)
	_using_authored_competitive_spawns = not _active_spawns.is_empty()
	if arena != null:
		_arena_half_width = float(arena.get("arena_half_width"))
		_arena_half_length = float(arena.get("arena_half_length"))
		arena_half_extent = maxf(_arena_half_width, _arena_half_length)
		fall_limit = float(arena.get("fall_limit"))


func get_spawn_for_peer(peer_id: int) -> Vector3:
	return get_spawn_for_slot(0 if peer_id == 1 else 1)


func get_spawn_for_slot(slot: int) -> Vector3:
	if _active_spawns.is_empty():
		return get_fallback_spawn()
	var index := posmod(slot, _active_spawns.size())
	var preferred := _validated_spawn(_active_spawns[index].global_position)
	# The map was added in the same frame as the match starts.  Its static bodies have
	# not necessarily entered the physics query space yet, so a ray check here can falsely
	# discard a valid authored deck and send the player to the center fallback.  Competitive
	# map markers are authored alongside solid deck collision and are verified in map tests.
	if _using_authored_competitive_spawns:
		return preferred
	if _has_floor_below(preferred):
		return preferred
	for marker in _active_spawns:
		var alternate := _validated_spawn(marker.global_position)
		if _has_floor_below(alternate):
			return alternate
	return get_fallback_spawn()


func get_spawn_yaw_for_peer(peer_id: int) -> float:
	return get_spawn_yaw_for_slot(0 if peer_id == 1 else 1)


func get_spawn_yaw_for_slot(slot: int) -> float:
	if _active_spawns.is_empty():
		return 0.0
	return _active_spawns[posmod(slot, _active_spawns.size())].global_rotation.y


func get_fallback_spawn() -> Vector3:
	return fallback_spawn.global_position if fallback_spawn != null else Vector3(0.0, 4.0, 0.0)


func is_outside_arena(position: Vector3) -> bool:
	return position.y < fall_limit or abs(position.x) > _arena_half_width or abs(position.z) > _arena_half_length


func is_outside_lobby(position: Vector3) -> bool:
	var flat_offset := Vector2(position.x - lobby_center.x, position.z - lobby_center.z)
	return position.y < fall_limit or flat_offset.length() > lobby_radius


func _scene_spawn_points(root: Node) -> Array[Marker3D]:
	var spawns: Array[Marker3D] = []
	for child in root.get_children():
		var marker := child as Marker3D
		if marker != null:
			spawns.append(marker)
	return spawns


func _validated_spawn(candidate: Vector3) -> Vector3:
	if abs(candidate.x) >= _arena_half_width or abs(candidate.z) >= _arena_half_length or candidate.y <= 0.0:
		return get_fallback_spawn()
	return candidate


func _has_floor_below(candidate: Vector3) -> bool:
	if not is_inside_tree():
		return true
	var query := PhysicsRayQueryParameters3D.create(candidate, candidate + Vector3.DOWN * 24.0)
	query.collision_mask = 1
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()
