extends SceneTree

## Product rules for the held items: the first-person rig shows the pistol on
## the Blaster slot and the two fists on the Blob slot, only in first person
## during a match; clicking in the Blob slot throws a punch (never a shot)
## that alternates hands, hurts and shoves a blob in reach, misses one out of
## reach, and waits out its cooldown.

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const DUMMY_SCENE := preload("res://scenes/player/dummy_blob.tscn")
const COMBAT_TUNING := preload("res://scripts/combat_tuning.gd")

var _failures: Array[String] = []
var _world: Node3D


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_world = Node3D.new()
	root.add_child(_world)
	_add_floor()
	await _test_rig_shows_the_right_item()
	await _test_punch_hits_in_reach()
	await _test_punch_rules()
	if _failures.is_empty():
		print("HELD ITEMS CONTRACT PASS")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_rig_shows_the_right_item() -> void:
	var camera := Camera3D.new()
	_world.add_child(camera)
	var rig := HeldItemRig.new()
	camera.add_child(rig)
	await process_frame
	_expect(rig.get_node_or_null("Pistol") != null and rig.get_node_or_null("Pistol/Barrel") != null and rig.get_node_or_null("Pistol/Grip") != null, "The pistol model must be built under the rig with a barrel and a grip")
	_expect(rig.get_node_or_null("Fists/LeftFist") != null and rig.get_node_or_null("Fists/RightFist") != null, "Both fists must be built under the rig")
	_expect(rig.get_node("Fists/LeftFist").get_child_count() >= 5, "A fist must be chunky: a palm plus knuckles")
	_expect(not rig.visible, "The rig must stay hidden until a first-person match")
	rig.set_first_person(true)
	_expect(not rig.visible, "First person alone must not show the rig outside a match")
	rig.set_active(true)
	_expect(rig.visible and rig.pistol.visible and not rig.fists.visible, "In a first-person match the Blaster slot must show the pistol only")
	rig.set_slot(COMBAT_TUNING.SLOT_BLOB)
	_expect(rig.fists.visible and not rig.pistol.visible, "The Blob slot must show the fists only")
	rig.set_first_person(false)
	_expect(not rig.visible, "Third person must hide the held items")
	rig.set_first_person(true)
	rig.play_punch(0, true)
	var left := rig.get_node("Fists/LeftFist") as Node3D
	var furthest := left.position.z
	for frame in 8:
		await physics_frame
		furthest = minf(furthest, left.position.z)
	_expect(furthest < HeldItemRig.FIST_LEFT_REST.z - 0.05, "A punch must thrust the fist forward")
	for frame in 30:
		await physics_frame
	_expect(left.position.is_equal_approx(HeldItemRig.FIST_LEFT_REST), "The fist must come back to rest after a punch")
	camera.queue_free()
	await process_frame


func _test_punch_hits_in_reach() -> void:
	var player := await _spawn_player(Vector3(0, 2.9, 0))
	var dummy := DUMMY_SCENE.instantiate() as RigidBody3D
	_world.add_child(dummy)
	dummy.global_position = Vector3(0, 2.9, -(COMBAT_TUNING.PUNCH_REACH + 0.5))
	# Training dummies default to infinite health; give this one a real bar.
	dummy.set("health_preset", 250)
	dummy.set("max_health", 250)
	dummy.set("health", 250)
	await physics_frame
	var full_health := int(dummy.get("health"))
	player.set_hotbar_slot(COMBAT_TUNING.SLOT_BLOB)
	player.aim_direction = Vector3.FORWARD
	var punches: Array = []
	player.punched.connect(func(hand: int, hit: bool, _at: Vector3) -> void: punches.append([hand, hit]))
	var shots := [0]
	player.shoot_requested.connect(func(_o: Vector3, _d: Vector3) -> void: shots[0] += 1)
	_expect(player.call("_throw_punch"), "A punch at a blob in reach must land")
	await physics_frame
	_expect(int(dummy.get("health")) == full_health - COMBAT_TUNING.PUNCH_DAMAGE, "A landed punch must deal PUNCH_DAMAGE")
	_expect(dummy.linear_velocity.z < -4.0, "A landed punch must shove the target away")
	_expect(punches.size() == 1 and bool(punches[0][1]), "The punch must report a hit for the HUD and the fist animation")
	_expect(shots[0] == 0, "A punch must never be a shot")
	player.queue_free()
	dummy.queue_free()
	await process_frame


func _test_punch_rules() -> void:
	var player := await _spawn_player(Vector3(0, 2.9, 0))
	var dummy := DUMMY_SCENE.instantiate() as RigidBody3D
	_world.add_child(dummy)
	dummy.global_position = Vector3(0, 2.9, -(COMBAT_TUNING.PUNCH_REACH + COMBAT_TUNING.PUNCH_RADIUS + 8.0))
	await physics_frame
	var full_health := int(dummy.get("health"))
	player.aim_direction = Vector3.FORWARD
	var hands: Array = []
	player.punched.connect(func(hand: int, _hit: bool, _at: Vector3) -> void: hands.append(hand))
	_expect(not bool(player.call("_throw_punch")), "The Blaster slot must not punch")
	player.set_hotbar_slot(COMBAT_TUNING.SLOT_BLOB)
	player.call("_throw_punch")
	await physics_frame
	_expect(int(dummy.get("health")) == full_health, "A punch at a blob out of reach must miss")
	_expect(hands.size() == 1, "A miss still swings")
	_expect(not bool(player.call("_throw_punch")), "A second punch inside the cooldown must wait")
	for frame in int(COMBAT_TUNING.PUNCH_COOLDOWN * 60.0) + 3:
		await physics_frame
	player.call("_throw_punch")
	_expect(hands.size() == 2 and hands[0] != hands[1], "Punches must alternate hands")
	player.queue_free()
	dummy.queue_free()
	await process_frame


func _spawn_player(position: Vector3) -> BlobPlayer:
	var blob := PLAYER_SCENE.instantiate() as BlobPlayer
	_world.add_child(blob)
	blob.configure_local(1)
	blob.set_shooting_enabled(true)
	blob.global_position = position
	await physics_frame
	return blob


func _add_floor() -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(400, 2, 400)
	shape.shape = box
	shape.position = Vector3(0, -1, 0)
	body.add_child(shape)
	_world.add_child(body)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
