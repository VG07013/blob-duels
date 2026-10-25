extends SceneTree

## Product rules for the duel combat loop: the default control layout (Q fling,
## E power-up, right-click aim, 1/2 hotbar, F quick blob), shot damage
## falloff, the quick blob that snaps back to the Blaster, the Blob
## slot's speed / charge / ram / air-jump perks and its no-shooting rule, hit
## flex on the blob visual, and a bot that leads moving targets.

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const PROJECTILE_SCENE := preload("res://scenes/player/projectile.tscn")
const PROJECTILE_SCRIPT := preload("res://scripts/projectile.gd")
const INPUT_BINDINGS := preload("res://scripts/input_bindings.gd")
const COMBAT_TUNING := preload("res://scripts/combat_tuning.gd")
const BOT_OPPONENT := preload("res://scripts/bot_opponent.gd")
const BOT_TUNING := preload("res://scripts/bot_tuning.gd")

var _failures: Array[String] = []
var _world: Node3D


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_world = Node3D.new()
	root.add_child(_world)
	_add_floor()
	_test_control_layout()
	await _test_shot_falloff()
	await _test_blob_slot_perks()
	await _test_quick_blob()
	await _test_blob_air_jump()
	await _test_blob_ram_bonus()
	await _test_hit_flex()
	await _test_bot_leads_moving_targets()
	await _test_bot_uses_blob_slot()
	await _test_bot_air_jumps_back_to_target()
	if _failures.is_empty():
		print("HOTBAR COMBAT CONTRACT PASS")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _test_control_layout() -> void:
	var defaults := INPUT_BINDINGS.default_bindings()
	_expect(str(defaults["charge_fling"]["keyboard"]) == "keycode:%d" % KEY_Q, "Fling charge must default to Q")
	_expect(str(defaults["use_ability"]["keyboard"]) == "keycode:%d" % KEY_E, "The power-up must default to E")
	_expect(str(defaults["aim"]["keyboard"]) == "mouse:%d" % MOUSE_BUTTON_RIGHT, "Aiming in must default to right click")
	_expect(str(defaults["slot_blaster"]["keyboard"]) == "keycode:%d" % KEY_1, "Hotbar slot 1 (Blaster) must default to the 1 key")
	_expect(str(defaults["slot_blob"]["keyboard"]) == "keycode:%d" % KEY_2, "Hotbar slot 2 (Blob) must default to the 2 key")
	_expect(str(defaults.get("quick_blob", {}).get("keyboard", "")) == "keycode:%d" % KEY_F, "Quick blob must default to the F key")
	# A save from the old layout still holds right click on the fling.
	var old_save := ConfigFile.new()
	old_save.set_value(INPUT_BINDINGS.BINDINGS_SECTION, "charge_fling", {"keyboard": "mouse:2", "joypad": "joyaxis:4:1"})
	var migrated := INPUT_BINDINGS.load_from_config(old_save)
	_expect(str(migrated["charge_fling"]["keyboard"]) == "keycode:%d" % KEY_Q, "An old save's right-click fling must move to Q so right click can aim")
	var custom_save := ConfigFile.new()
	custom_save.set_value(INPUT_BINDINGS.BINDINGS_SECTION, "charge_fling", {"keyboard": "keycode:%d" % KEY_F, "joypad": "joybtn:9"})
	_expect(str(INPUT_BINDINGS.load_from_config(custom_save)["charge_fling"]["keyboard"]) == "keycode:%d" % KEY_F, "A player's own fling binding must survive the layout migration")


func _test_shot_falloff() -> void:
	_expect(is_equal_approx(COMBAT_TUNING.shot_falloff(COMBAT_TUNING.SHOT_FALLOFF_START * 0.5), 1.0), "Close shots must deal full damage")
	_expect(COMBAT_TUNING.shot_falloff(50.0) < 1.0 and COMBAT_TUNING.shot_falloff(50.0) > COMBAT_TUNING.SHOT_FALLOFF_MIN_RATIO, "Mid-range shots must lose some damage")
	_expect(is_equal_approx(COMBAT_TUNING.shot_falloff(400.0), COMBAT_TUNING.SHOT_FALLOFF_MIN_RATIO), "Long shots must bottom out at the minimum damage share, never zero")
	_expect(PROJECTILE_SCRIPT.BASE_SPEED >= 200.0, "Bullets must travel quickly")
	var shot := PROJECTILE_SCENE.instantiate()
	# Placed before entering the tree so it never spawns inside the floor.
	shot.position = Vector3(0, 3, 0)
	_world.add_child(shot)
	await process_frame
	shot.configure(Vector3(0, 3, 0), Vector3.FORWARD, null, true, false, false)
	for frame in 12:
		await physics_frame
	_expect(shot.get_distance_travelled() > 30.0, "A projectile must track how far it has flown")
	_expect(shot.get_falloff_ratio() < 1.0, "A projectile past the falloff start must hit for less")
	shot.configure(Vector3(0, 3, 0), Vector3.FORWARD, null, true, false, true)
	for frame in 4:
		await physics_frame
	_expect(is_equal_approx(shot.get_falloff_ratio(), 1.0), "Rail shots are the long-range power-up and must not fall off")
	shot.queue_free()


func _test_blob_slot_perks() -> void:
	var blob := await _spawn_player(Vector3(0, 3, 0))
	var fired := [0]
	blob.shoot_requested.connect(func(_origin: Vector3, _direction: Vector3) -> void: fired[0] += 1)
	blob.set_shooting_enabled(true)
	var base_charge: float = blob.get_charge_rate_multiplier()
	var base_speed: float = blob.get_ground_control_speed()
	blob.request_shot_for_test()
	_expect(fired[0] == 1, "The Blaster slot must shoot")
	blob.set("_shot_cooldown_timer", 0.0)
	blob.set_hotbar_slot(COMBAT_TUNING.SLOT_BLOB)
	_expect(blob.is_blob_mode(), "Selecting slot 2 must switch to the Blob")
	blob.request_shot_for_test()
	_expect(fired[0] == 1, "The Blob slot must not shoot")
	_expect(blob.get_ground_control_speed() > base_speed, "The Blob slot must roll faster")
	_expect(blob.get_charge_rate_multiplier() > base_charge, "The Blob slot must charge its fling faster")
	blob.set_hotbar_slot(COMBAT_TUNING.SLOT_BLASTER)
	_expect(is_equal_approx(blob.get_ground_control_speed(), base_speed), "Switching back to the Blaster must drop the Blob speed boost")
	blob.queue_free()
	await process_frame


func _test_quick_blob() -> void:
	var blob := await _spawn_player(Vector3(0, 3, 0))
	blob.set_hotbar_slot(COMBAT_TUNING.SLOT_BLASTER)
	blob.start_quick_blob()
	_expect(blob.is_blob_mode(), "Quick blob must switch to the Blob straight away")
	var frames_before_expiry := int(COMBAT_TUNING.QUICK_BLOB_SECONDS * Engine.physics_ticks_per_second) - 4
	for _i in frames_before_expiry:
		await physics_frame
	_expect(blob.is_blob_mode(), "Quick blob must hold the Blob for its full %.1fs" % COMBAT_TUNING.QUICK_BLOB_SECONDS)
	for _i in 10:
		await physics_frame
	_expect(blob.get_hotbar_slot() == COMBAT_TUNING.SLOT_BLASTER, "Quick blob must return to the Blaster after %.1fs" % COMBAT_TUNING.QUICK_BLOB_SECONDS)
	# Picking a slot by hand cancels the snap-back.
	blob.start_quick_blob()
	blob.set_hotbar_slot(COMBAT_TUNING.SLOT_BLOB)
	for _i in int(COMBAT_TUNING.QUICK_BLOB_SECONDS * Engine.physics_ticks_per_second) + 10:
		await physics_frame
	_expect(blob.is_blob_mode(), "Choosing the Blob by hand during a quick blob must keep the Blob equipped")
	blob.queue_free()
	await process_frame


func _test_blob_air_jump() -> void:
	var blob := await _spawn_player(Vector3(0, 30, 0))
	blob.set("aim_yaw", 0.0)
	blob.linear_velocity = Vector3(34.0, -6.0, 0.0)
	await physics_frame
	await physics_frame
	_expect(not blob.try_blob_air_jump_for_test(), "The Blaster slot must not grant an air jump")
	blob.set_hotbar_slot(COMBAT_TUNING.SLOT_BLOB)
	blob.linear_velocity = Vector3(34.0, -6.0, 0.0)
	Input.action_press("move_forward")
	var jumped: bool = blob.try_blob_air_jump_for_test()
	Input.action_release("move_forward")
	var planar := Vector2(blob.linear_velocity.x, blob.linear_velocity.z)
	_expect(jumped, "The Blob slot must grant an air jump")
	_expect(planar.normalized().dot(Vector2(0, -1)) > 0.98, "An air jump must swing momentum onto the held direction instantly")
	_expect(planar.length() >= 33.0, "An air jump must keep the blob's speed while changing its direction")
	_expect(blob.linear_velocity.y >= COMBAT_TUNING.BLOB_AIR_JUMP_UP_SPEED - 0.5, "An air jump must pop the blob upward")
	_expect(not blob.try_blob_air_jump_for_test(), "Only one air jump per airtime")
	blob.queue_free()
	await process_frame


func _test_blob_ram_bonus() -> void:
	var plain_damage := await _ram_damage(false)
	var blob_damage := await _ram_damage(true)
	_expect(plain_damage > 0, "Ramming into a blob must deal damage")
	_expect(blob_damage > plain_damage, "Ramming in the Blob slot must deal more damage (%d vs %d)" % [blob_damage, plain_damage])


func _ram_damage(blob_mode: bool) -> int:
	var attacker := await _spawn_player(Vector3(-12, 2.9, 40))
	var victim := await _spawn_player(Vector3(0, 2.9, 40))
	# Two local blobs with one peer id would each defer the pair to the other;
	# a plain local victim takes the impact directly, as the bot does.
	victim.remove_from_group("network_blob")
	attacker.set_input_enabled(false)
	victim.set_input_enabled(false)
	if blob_mode:
		attacker.set_hotbar_slot(COMBAT_TUNING.SLOT_BLOB)
	var start_health: int = victim.health
	for frame in 40:
		# A moderate ram: fast rams already hit the 60-damage cap either way.
		if frame < 6:
			attacker.linear_velocity = Vector3(20.0, attacker.linear_velocity.y, 0.0)
		await physics_frame
	var damage: int = start_health - victim.health
	attacker.queue_free()
	victim.queue_free()
	await process_frame
	return damage


func _test_hit_flex() -> void:
	var blob := await _spawn_player(Vector3(0, 3, -40))
	var visual := blob.get_node("VisualRoot")
	var face := blob.get_node("FaceRoot") as Node3D
	var worst_face_stretch := 1.0
	var peak := 0.0
	# Several hits back to back: the face must bend with the body each frame
	# without the flex stacking up into a smeared face.
	for hit in 3:
		blob.receive_collision_impact(10, Vector3(160, 0, 0))
		for frame in 20:
			await physics_frame
			peak = maxf(peak, absf(float(visual.call("get_flex_amount"))))
			var face_scale := face.global_basis.get_scale()
			worst_face_stretch = maxf(worst_face_stretch, maxf(face_scale.x, maxf(face_scale.y, face_scale.z)) / maxf(minf(face_scale.x, minf(face_scale.y, face_scale.z)), 0.001))
	_expect(worst_face_stretch < 2.0, "The face must bend with a hit, never smear (worst stretch %.2f)" % worst_face_stretch)
	_expect(peak > 0.05, "Taking a hit must visibly dent and flex the blob")
	for frame in 150:
		await physics_frame
	_expect(absf(float(visual.call("get_flex_amount"))) < 0.02, "A hit flex must spring back to rest")
	_expect((face.global_basis.get_scale() - Vector3.ONE).length() < 0.05, "The face must return to its normal shape once the flex settles")
	blob.queue_free()
	await process_frame


func _test_bot_leads_moving_targets() -> void:
	var target := RigidBody3D.new()
	target.gravity_scale = 0.0
	target.freeze = true
	_world.add_child(target)
	target.global_position = Vector3(40, 3, 0)
	target.linear_velocity = Vector3(0, 0, 28)
	var bot = BOT_OPPONENT.new()
	_world.add_child(bot)
	bot.configure(null, target, BOT_TUNING.DIFFICULTY_HARD, func(_p: Vector3) -> bool: return false, Vector3.ZERO)
	var origin := Vector3(0, 3, 0)
	var aim: Vector3 = bot.predict_aim_point(origin)
	var direction := (aim - origin).normalized()
	var flight := COMBAT_TUNING.intercept_time(origin, target.global_position, target.linear_velocity, PROJECTILE_SCRIPT.BASE_SPEED)
	var shot_end := origin + direction * PROJECTILE_SCRIPT.BASE_SPEED * flight
	var target_end := target.global_position + target.linear_velocity * flight
	_expect(flight > 0.0, "The bot must find an intercept against a catchable target")
	_expect(shot_end.distance_to(target_end) < 1.0, "A hard bot must lead a moving target so its shot arrives where the target will be")
	bot.configure(null, target, BOT_TUNING.DIFFICULTY_EASY, func(_p: Vector3) -> bool: return false, Vector3.ZERO)
	var easy_aim: Vector3 = bot.predict_aim_point(origin)
	_expect(easy_aim.distance_to(target.global_position) < aim.distance_to(target.global_position), "An easy bot must lead less than a hard one")
	bot.queue_free()
	target.queue_free()
	await process_frame


func _test_bot_uses_blob_slot() -> void:
	var bot_body := await _spawn_player(Vector3(0, 2.9, 80))
	bot_body.set_input_enabled(false)
	var target := await _spawn_player(Vector3(9, 2.9, 80))
	target.set_input_enabled(false)
	var bot = BOT_OPPONENT.new()
	_world.add_child(bot)
	var shots := [0]
	bot.shot_requested.connect(func(_origin: Vector3, _direction: Vector3) -> void: shots[0] += 1)
	bot.configure(bot_body, target, BOT_TUNING.DIFFICULTY_HARD, func(_p: Vector3) -> bool: return false, Vector3.ZERO)
	_expect(not bot_body.is_blob_mode(), "The bot must start a round on the Blaster")
	bot.set_round_active(true)
	# A round opens with half a ram cooldown, so the bot never rams off spawn.
	var opening_cooldown := float(BOT_TUNING.preset_for(BOT_TUNING.DIFFICULTY_HARD)["blob_cooldown_seconds"]) * 0.5
	var swapped := false
	for frame in range(int(opening_cooldown * 60.0) + 20):
		# Hold the target inside ram range while the cooldown runs down.
		target.global_position = bot_body.global_position + Vector3(9, 0, 0)
		await physics_frame
		if bot_body.is_blob_mode():
			swapped = true
			break
	_expect(swapped, "A bot that closes to ram range must swap to the Blob")
	var shots_while_blob: int = shots[0]
	for frame in 30:
		await physics_frame
	_expect(shots[0] == shots_while_blob, "A bot in the Blob slot must not shoot")
	var commit := float(BOT_TUNING.preset_for(BOT_TUNING.DIFFICULTY_HARD)["blob_commit_seconds"])
	# Pull the target out of ram range so the charge can end and stay ended.
	# (A hard bot may fling - another ram - soon after, so look for the swap
	# back at any point rather than sampling one frame.)
	target.global_position = Vector3(90, 2.9, 80)
	var returned := false
	for frame in range(int(commit * 60.0) + 30):
		await physics_frame
		if not bot_body.is_blob_mode():
			returned = true
			break
	_expect(returned, "The bot must swap back to the Blaster once its ram charge ends")
	bot.queue_free()
	bot_body.queue_free()
	target.queue_free()
	await process_frame


func _test_bot_air_jumps_back_to_target() -> void:
	var bot_body := await _spawn_player(Vector3(-60, 40, 0))
	bot_body.set_input_enabled(false)
	var target := RigidBody3D.new()
	target.freeze = true
	_world.add_child(target)
	target.global_position = Vector3(-60, 40, -70)
	var bot = BOT_OPPONENT.new()
	_world.add_child(bot)
	bot.configure(bot_body, target, BOT_TUNING.DIFFICULTY_HARD, func(_p: Vector3) -> bool: return false, Vector3.ZERO)
	bot.set_round_active(true)
	bot.call("_start_blob_charge")
	# Flying sideways, well off the line to a target straight ahead (-Z).
	bot_body.linear_velocity = Vector3(32, 0, 0)
	var jumps := [0]
	bot_body.air_jumped.connect(func(_direction: Vector3) -> void: jumps[0] += 1)
	for frame in 30:
		await physics_frame
	var planar := Vector3(bot_body.linear_velocity.x, 0.0, bot_body.linear_velocity.z)
	_expect(jumps[0] == 1, "A hard bot flying wide in the Blob must spend its air jump")
	_expect(planar.normalized().dot(Vector3.FORWARD) > 0.8, "The bot's air jump must swing it back toward its target")
	bot.queue_free()
	bot_body.queue_free()
	target.queue_free()
	await process_frame


func _spawn_player(position: Vector3) -> RigidBody3D:
	var blob := PLAYER_SCENE.instantiate() as RigidBody3D
	_world.add_child(blob)
	blob.configure_local(1)
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
