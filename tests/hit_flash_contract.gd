extends SceneTree

## Product rule: taking damage makes a blob flash red with a red outline for a
## split second, whether it is your own blob, the opponent as you see it over
## the network, or a practice dummy. Knockback without damage does not flash.

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const DUMMY_SCENE := preload("res://scenes/player/dummy_blob.tscn")
const COMBAT_TUNING := preload("res://scripts/combat_tuning.gd")
const BLOB_MATERIAL_KIT := preload("res://scripts/blob_material_kit.gd")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)

	var local := PLAYER_SCENE.instantiate() as RigidBody3D
	world.add_child(local)
	local.configure_local(1)
	local.respawn(Vector3(0, 3.0, 0))
	await physics_frame
	var local_mesh := local.get("mesh") as MeshInstance3D

	local.receive_collision_impact(0, Vector3(1, 0, 0) * 60.0, true)
	_expect(not BLOB_MATERIAL_KIT.is_hit_flashing(local_mesh), "Knockback without damage must not flash the blob red")

	local.receive_collision_impact(10, Vector3(1, 0, 0) * 60.0, true)
	_expect(BLOB_MATERIAL_KIT.is_hit_flashing(local_mesh), "A damaged blob must flash red with an outline")
	_expect(local_mesh.material_overlay != null, "A damaged blob's body must be tinted red while flashing")
	await create_timer(COMBAT_TUNING.HIT_FLASH_SECONDS + 0.15).timeout
	_expect(not BLOB_MATERIAL_KIT.is_hit_flashing(local_mesh), "The hit flash must only last a moment")
	_expect(local_mesh.material_overlay == null, "The red tint must clear once the hit flash ends")

	var remote := PLAYER_SCENE.instantiate() as RigidBody3D
	world.add_child(remote)
	remote.configure_remote(2, Color(0.2, 0.5, 1.0))
	await physics_frame
	var remote_mesh := remote.get("mesh") as MeshInstance3D
	var remote_health := int(remote.get("health"))
	remote.apply_network_state(remote.global_position, Vector3.ZERO, Vector3.ZERO, remote_health, Vector3.FORWARD)
	_expect(not BLOB_MATERIAL_KIT.is_hit_flashing(remote_mesh), "An unchanged replicated health must not flash the opponent")
	remote.apply_network_state(remote.global_position, Vector3.ZERO, Vector3.ZERO, remote_health - 15, Vector3.FORWARD)
	_expect(BLOB_MATERIAL_KIT.is_hit_flashing(remote_mesh), "Damaging the opponent must flash them red on the attacker's screen")

	var dummy := DUMMY_SCENE.instantiate() as RigidBody3D
	world.add_child(dummy)
	await physics_frame
	dummy.take_damage(12, Vector3.FORWARD, 10.0)
	_expect(BLOB_MATERIAL_KIT.is_hit_flashing(dummy.get("mesh") as MeshInstance3D), "A damaged practice dummy must flash red with an outline")

	world.queue_free()
	await process_frame
	_finish()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("hit_flash_contract: ok")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
