extends RigidBody3D

const COSMETIC_LIBRARY := preload("res://scripts/cosmetic_library.gd")
const ABILITY_TUNING := preload("res://scripts/ability_tuning.gd")

signal health_changed(current_health: int, max_health: int)
signal fling_charge_started
signal fling_charge_updated(charge_ratio: float)
signal fling_maximum_reached
signal fling_released(charge_ratio: float)
signal shoot_requested(origin: Vector3, direction: Vector3)
signal bounce_triggered(strength: float)
signal impact_event(world_position: Vector3, strength: float)
signal damaged(amount: int)
signal respawned(world_position: Vector3)
signal knocked_out(peer_id: int)
signal network_collision_requested(target_peer_id: int, impulse: Vector3, damage: int)

@export_category("Ground Movement")
@export var ground_acceleration := 78.0
@export var ground_start_impulse := 8.5
@export var ground_control_speed := 30.0
@export var ground_counter_acceleration := 44.0
@export var idle_ground_drag := 0.18
@export var movement_roll_torque := 128.0

@export_category("Air Movement")
@export var air_acceleration := 22.0
@export var air_steering_strength := 0.38
@export var air_control_speed := 20.0
@export var emergency_max_speed := 138.0

@export_category("Bounce Boost")
@export var bounce_boost_impulse := 56.0
@export var bounce_boost_cooldown := 0.18
@export var coyote_time := 0.18
@export var input_buffer_time := 0.10
@export_range(0.0, 89.0, 1.0) var ground_max_angle := 56.0

@export_category("Fling")
@export var maximum_charge_time := 7.0
@export var minimum_fling_impulse := 14.0
@export var maximum_fling_impulse := 310.0
@export var charge_exponent := 1.35
@export var fling_upward_assist := 0.12
@export var fling_control_reduction_time := 0.32
@export var fling_control_multiplier := 0.28

@export_category("Combat")
@export var max_health := 150
@export var shot_cooldown := 0.16
@export var shot_recoil_impulse := 18.0
@export var impact_damage_scale := 2.2
@export var velocity_damage_scale := 0.9
@export var collision_pair_cooldown := 0.16

var aim_yaw := 0.0
var aim_direction := Vector3.FORWARD
var health := 150
var fling_charge := 0.0
var local_controlled := true
var shooting_enabled := false
var input_enabled := true
var network_peer_id := 1
var display_name := "Player"
var blob_color := Color(0.05, 0.69, 0.96)

var _is_charging_fling := false
var _maximum_charge_announced := false
var _spawn_position := Vector3.ZERO
var _was_moving := false
var _grounded := false
var _ground_normal := Vector3.UP
var _coyote_timer := 0.0
var _bounce_buffer_timer := 0.0
var _bounce_cooldown_timer := 0.0
var _shot_cooldown_timer := 0.0
var _post_fling_control_timer := 0.0
var _recent_fling_timer := 0.0
var _recent_fling_charge := 0.0
var _collision_ready_at: Dictionary = {}
var _network_target_position := Vector3.ZERO
var _network_target_rotation := Vector3.ZERO
var _equipped_skin_id := "classic_blue"
var _equipped_trail_id := "bubble"
var _equipped_face_id := "happy"
var _equipped_kill_effect_id := "bubble_pop"
var _cosmetic_quality := 1
var _skin_profile: Dictionary = {}
var _skin_material: StandardMaterial3D
var _cosmetic_time := 0.0
var _cosmetic_light: OmniLight3D
var _trail_base_amount := 18
var _trail_base_lifetime := 0.95
var _equipped_ability_id := ""
var _overcharge_active := false
var _scanner_outline: MeshInstance3D
var _shooting_locked := false
var _phase_bubble_active := false
var _phase_bubble_visual: MeshInstance3D
var _adrenaline_active := false

@onready var health_billboard: Label3D = $HealthBillboard
@onready var mesh: MeshInstance3D = $VisualRoot/Mesh
@onready var speed_trail: GPUParticles3D = $SpeedTrail
@onready var face_root: Node3D = $FaceRoot
@onready var ground_cast: ShapeCast3D = get_node_or_null("GroundCast") as ShapeCast3D


func _ready() -> void:
	can_sleep = false
	contact_monitor = true
	max_contacts_reported = 16
	body_entered.connect(_on_body_entered)
	$ContactArea.area_entered.connect(_on_contact_area_entered)
	health = max_health
	_network_target_position = global_position
	_network_target_rotation = rotation
	_update_health_billboard()
	_apply_saved_cosmetics()


func _physics_process(delta: float) -> void:
	_update_speed_trail()
	_update_cosmetic_animation(delta)
	_update_face()
	_update_adrenaline()
	if not local_controlled:
		_update_remote_transform(delta)
		return

	_tick_timers(delta)
	_update_ground_state(delta)
	if not input_enabled:
		return

	_update_bounce_input()
	_apply_movement(delta)
	_update_fling_charge(delta)
	_update_shooting()
	_apply_emergency_speed_guard()


func configure_local(peer_id: int) -> void:
	network_peer_id = peer_id
	local_controlled = true
	freeze = false
	collision_layer = 2
	collision_mask = 1


func configure_remote(peer_id: int, color: Color) -> void:
	network_peer_id = peer_id
	local_controlled = false
	freeze = true
	collision_layer = 2
	collision_mask = 0
	set_blob_color(color)
	_network_target_position = global_position
	_network_target_rotation = rotation


func set_player_identity(new_display_name: String, color: Color) -> void:
	var clean_name := new_display_name.strip_edges()
	var next_name := clean_name.left(16) if not clean_name.is_empty() else "Player"
	var identity_changed := next_name != display_name or not color.is_equal_approx(blob_color)
	display_name = next_name
	if not color.is_equal_approx(blob_color):
		set_blob_color(color)
	if identity_changed:
		_update_health_billboard()


func apply_network_identity(new_display_name: String, color: Color) -> void:
	set_player_identity(new_display_name, color)


func apply_network_state(network_position: Vector3, body_rotation: Vector3, velocity: Vector3, current_health: int, facing_direction: Vector3) -> void:
	_network_target_position = network_position
	_network_target_rotation = body_rotation
	linear_velocity = velocity
	if facing_direction.length_squared() > 0.001:
		aim_direction = facing_direction.normalized()
	if health != current_health:
		health = clampi(current_health, 0, max_health)
		health_changed.emit(health, max_health)
		_update_health_billboard()


func set_blob_color(color: Color) -> void:
	blob_color = color
	if mesh == null:
		return
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.28
	material.metallic = 0.05
	material.clearcoat_enabled = true
	material.clearcoat = 0.55
	material.clearcoat_roughness = 0.22
	mesh.material_override = material
	health_billboard.modulate = color.lightened(0.3)
	var trail_mesh := speed_trail.draw_pass_1.duplicate() as SphereMesh
	var trail_material := trail_mesh.material.duplicate() as StandardMaterial3D
	trail_material.albedo_color = Color(color.r, color.g, color.b, 0.72)
	trail_material.emission = color
	trail_mesh.material = trail_material
	speed_trail.draw_pass_1 = trail_mesh
	apply_equipped_cosmetics(_equipped_skin_id, _equipped_trail_id, _equipped_face_id, _equipped_kill_effect_id)


func apply_equipped_cosmetics(skin_id: String, trail_id: String, face_id: String, kill_effect_id: String) -> void:
	_equipped_skin_id = skin_id if not skin_id.is_empty() else "classic_blue"
	_equipped_trail_id = trail_id if not trail_id.is_empty() else "bubble"
	_equipped_face_id = face_id if not face_id.is_empty() else "happy"
	_equipped_kill_effect_id = kill_effect_id if not kill_effect_id.is_empty() else "bubble_pop"
	if mesh == null or speed_trail == null:
		return
	_skin_profile = COSMETIC_LIBRARY.skin_profile(_equipped_skin_id, blob_color)
	var primary := _skin_profile.get("primary", blob_color) as Color
	var secondary := _skin_profile.get("secondary", primary.lightened(0.4)) as Color
	var effect := str(_skin_profile.get("effect", "jelly"))
	_skin_material = StandardMaterial3D.new()
	_skin_material.albedo_color = primary
	_skin_material.roughness = 0.16 if effect in ["water", "ice", "crystal", "gold"] else 0.29
	_skin_material.metallic = 0.88 if effect in ["gold", "cyber", "crystal"] else 0.04
	_skin_material.clearcoat_enabled = true
	_skin_material.clearcoat = 0.72
	_skin_material.clearcoat_roughness = 0.12
	_skin_material.emission_enabled = effect in ["lava", "galaxy", "crystal", "neon", "plasma", "cyber", "black_hole", "aurora", "gold", "rainbow", "dark_matter", "celestial"]
	_skin_material.emission = secondary
	_skin_material.emission_energy_multiplier = 0.45
	mesh.material_override = _skin_material
	_apply_trail_profile(COSMETIC_LIBRARY.trail_profile(_equipped_trail_id))
	_apply_face_profile(COSMETIC_LIBRARY.face_profile(_equipped_face_id))
	_apply_cosmetic_light(secondary, str(_skin_profile.get("rarity", "Common")))


func set_cosmetic_quality(quality: int) -> void:
	_cosmetic_quality = clampi(quality, 0, 3)
	apply_equipped_cosmetics(_equipped_skin_id, _equipped_trail_id, _equipped_face_id, _equipped_kill_effect_id)


func get_kill_effect_id() -> String:
	return _equipped_kill_effect_id


func get_skin_rarity() -> String:
	return str(_skin_profile.get("rarity", "Common"))


func get_skin_accent_color() -> Color:
	return _skin_profile.get("secondary", blob_color) as Color


func _apply_saved_cosmetics() -> void:
	var progression := get_node_or_null("/root/Progression")
	if progression == null:
		apply_equipped_cosmetics(_equipped_skin_id, _equipped_trail_id, _equipped_face_id, _equipped_kill_effect_id)
		return
	apply_equipped_cosmetics(
		str(progression.call("get_equipped", "skins")),
		str(progression.call("get_equipped", "trails")),
		str(progression.call("get_equipped", "faces")),
		str(progression.call("get_equipped", "kill_effects")),
	)


func _apply_trail_profile(profile: Dictionary) -> void:
	var trail_color := profile.get("color", blob_color) as Color
	var rarity := str(profile.get("rarity", "Common"))
	_trail_base_lifetime = 0.95
	_trail_base_amount = [10, 18, 28, 40][_cosmetic_quality]
	if rarity in ["Epic", "Legendary"] and _cosmetic_quality >= 2:
		_trail_base_amount += 8
	speed_trail.lifetime = _trail_base_lifetime
	speed_trail.amount = _trail_base_amount
	var trail_mesh := speed_trail.draw_pass_1.duplicate() as SphereMesh
	var trail_material := StandardMaterial3D.new()
	trail_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	trail_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	trail_material.albedo_color = Color(trail_color.r, trail_color.g, trail_color.b, 0.7)
	trail_material.emission_enabled = true
	trail_material.emission = trail_color
	trail_material.emission_energy_multiplier = 0.55 if rarity in ["Common", "Rare"] else 1.15
	trail_mesh.material = trail_material
	speed_trail.draw_pass_1 = trail_mesh


func _apply_face_profile(profile: Dictionary) -> void:
	var face_color := profile.get("color", Color(0.04, 0.05, 0.07)) as Color
	var effect := str(profile.get("effect", "happy"))
	for node_name in ["LeftPupil", "RightPupil", "LeftHighlight", "RightHighlight"]:
		var node := face_root.get_node_or_null(node_name) as MeshInstance3D
		if node == null:
			continue
		var material := StandardMaterial3D.new()
		material.albedo_color = face_color
		material.roughness = 0.2
		material.emission_enabled = effect in ["robot", "fire", "frozen", "glitch", "cosmic", "void", "energy", "divine"]
		material.emission = face_color
		material.emission_energy_multiplier = 0.7 if material.emission_enabled else 0.0
		node.material_override = material
	var wink := effect == "wink"
	var right_eye := face_root.get_node_or_null("RightEyeWhite") as MeshInstance3D
	if right_eye != null:
		right_eye.visible = not wink


func _apply_cosmetic_light(color: Color, rarity: String) -> void:
	if rarity != "Legendary" or _cosmetic_quality < 2:
		if _cosmetic_light != null:
			_cosmetic_light.visible = false
		return
	if _cosmetic_light == null:
		_cosmetic_light = OmniLight3D.new()
		_cosmetic_light.name = "CosmeticGlow"
		_cosmetic_light.omni_range = 5.0
		_cosmetic_light.shadow_enabled = false
		add_child(_cosmetic_light)
	_cosmetic_light.visible = true
	_cosmetic_light.light_color = color
	_cosmetic_light.light_energy = 0.38


func _update_cosmetic_animation(delta: float) -> void:
	_cosmetic_time += delta
	if _skin_material == null:
		return
	var effect := str(_skin_profile.get("effect", "jelly"))
	var secondary := _skin_profile.get("secondary", blob_color) as Color
	var pulse := 0.55 + sin(_cosmetic_time * 2.2) * 0.2
	if effect == "rainbow":
		_skin_material.albedo_color = Color.from_hsv(fposmod(_cosmetic_time * 0.14, 1.0), 0.72, 1.0)
		_skin_material.emission = Color.from_hsv(fposmod(_cosmetic_time * 0.14 + 0.18, 1.0), 0.58, 1.0)
	elif effect in ["lava", "plasma", "aurora", "galaxy", "neon", "black_hole", "dark_matter", "celestial", "crystal", "cyber", "gold"]:
		_skin_material.emission = secondary
		_skin_material.emission_energy_multiplier = pulse
	if _cosmetic_light != null and _cosmetic_light.visible:
		_cosmetic_light.light_energy = 0.28 + pulse * 0.2


func get_movement_input() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_forward", "move_back")


func get_charge_ratio() -> float:
	return clampf(fling_charge / maxf(maximum_charge_time, 0.001), 0.0, 1.0)


func trigger_launch_visual(amount: float = 0.5) -> void:
	_launch_visual(amount)


func calculate_fling_strength(charge_ratio: float) -> float:
	var curved_charge := pow(clampf(charge_ratio, 0.0, 1.0), charge_exponent)
	return lerpf(minimum_fling_impulse, maximum_fling_impulse, curved_charge)


func is_grounded() -> bool:
	return _grounded


func request_shot_for_test() -> void:
	_emit_shot_request()


func set_shooting_enabled(enabled: bool) -> void:
	shooting_enabled = enabled


func respawn(spawn_position: Vector3) -> void:
	_spawn_position = spawn_position
	freeze = true
	global_position = spawn_position
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	reset_physics_interpolation()
	sleeping = false
	freeze = false
	health = max_health
	health_changed.emit(health, max_health)
	_update_health_billboard()
	cancel_active_charge()
	_coyote_timer = 0.0
	_bounce_buffer_timer = 0.0
	_bounce_cooldown_timer = 0.2
	_shot_cooldown_timer = 0.0
	_post_fling_control_timer = 0.0
	_recent_fling_timer = 0.0
	_hit_visual(0.12)
	respawned.emit(global_position)


func take_damage(amount: int, hit_direction: Vector3, knockback: float) -> void:
	if not local_controlled:
		return
	var launch_direction := (hit_direction.normalized() + Vector3.UP * 0.22).normalized()
	receive_collision_impact(amount, launch_direction * knockback * 1.18)


func receives_direct_damage() -> bool:
	return local_controlled


func apply_external_impulse(impulse: Vector3) -> void:
	if not local_controlled:
		return
	sleeping = false
	apply_central_impulse(impulse)
	_hit_visual(clampf(impulse.length() * 0.008, 0.08, 0.3))
	impact_event.emit(global_position, impulse.length())


func receive_collision_impact(amount: int, impulse: Vector3) -> void:
	if not local_controlled:
		return
	sleeping = false
	var lift := Vector3.UP * clampf(impulse.length() * 0.34, 8.0, 48.0)
	apply_central_impulse((impulse + lift) * 1.2)
	_hit_visual(clampf(impulse.length() * 0.007, 0.08, 0.32))
	impact_event.emit(global_position, impulse.length())
	if amount <= 0 or health <= 0:
		return
	health = maxi(health - amount, 0)
	health_changed.emit(health, max_health)
	_update_health_billboard()
	damaged.emit(amount)
	if health <= 0:
		knocked_out.emit(network_peer_id)


func apply_bounce_pad(launch_impulse: float) -> void:
	if not local_controlled:
		return
	sleeping = false
	var upward_cancel := maxf(-linear_velocity.y * mass, 0.0)
	apply_central_impulse(Vector3.UP * (launch_impulse + upward_cancel))
	_post_fling_control_timer = maxf(_post_fling_control_timer, 0.08)
	_hit_visual(0.18)
	_launch_visual(0.72)
	bounce_triggered.emit(launch_impulse)


func set_input_enabled(enabled: bool) -> void:
	input_enabled = enabled
	if not input_enabled:
		cancel_active_charge()


func cancel_active_charge() -> void:
	_is_charging_fling = false
	_maximum_charge_announced = false
	fling_charge = 0.0
	fling_charge_updated.emit(0.0)


func _tick_timers(delta: float) -> void:
	_bounce_buffer_timer = maxf(_bounce_buffer_timer - delta, 0.0)
	_bounce_cooldown_timer = maxf(_bounce_cooldown_timer - delta, 0.0)
	_shot_cooldown_timer = maxf(_shot_cooldown_timer - delta, 0.0)
	_post_fling_control_timer = maxf(_post_fling_control_timer - delta, 0.0)
	_recent_fling_timer = maxf(_recent_fling_timer - delta, 0.0)


func _update_ground_state(delta: float) -> void:
	_grounded = false
	_ground_normal = Vector3.UP
	var minimum_up_dot := cos(deg_to_rad(ground_max_angle))
	if ground_cast != null:
		# The blob body rolls freely, but ground detection must always cast world-down.
		ground_cast.global_rotation = Vector3.ZERO
		ground_cast.force_shapecast_update()
		for index in range(ground_cast.get_collision_count()):
			var normal := ground_cast.get_collision_normal(index)
			if normal.dot(Vector3.UP) >= minimum_up_dot:
				_grounded = true
				_ground_normal = normal
				break
	elif get_contact_count() > 0 and absf(linear_velocity.y) < 3.5:
		_grounded = true
	if _grounded:
		_coyote_timer = coyote_time
	else:
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)


func _update_bounce_input() -> void:
	if Input.is_action_just_pressed("bounce"):
		_bounce_buffer_timer = input_buffer_time
		_update_ground_state(0.0)
	if _bounce_buffer_timer <= 0.0 or _bounce_cooldown_timer > 0.0 or _coyote_timer <= 0.0:
		return
	var launch_direction := (Vector3.UP * 0.74 + _ground_normal * 0.26).normalized()
	apply_central_impulse(launch_direction * bounce_boost_impulse)
	_bounce_buffer_timer = 0.0
	_bounce_cooldown_timer = bounce_boost_cooldown
	_coyote_timer = 0.0
	_hit_visual(0.12)
	_launch_visual(0.58)
	bounce_triggered.emit(bounce_boost_impulse)


func _apply_movement(_delta: float) -> void:
	var movement_input := get_movement_input()
	var planar_velocity := Vector3(linear_velocity.x, 0.0, linear_velocity.z)
	if movement_input.length_squared() <= 0.001:
		_was_moving = false
		if _grounded and _post_fling_control_timer <= 0.0:
			apply_central_force(-planar_velocity * idle_ground_drag * mass)
		return

	var aim_basis := Basis(Vector3.UP, aim_yaw)
	var camera_forward := -aim_basis.z
	var camera_right := aim_basis.x
	var desired_direction := (camera_right * movement_input.x + camera_forward * -movement_input.y).normalized()
	var control_multiplier := _charge_control_multiplier() * _post_fling_control_multiplier()
	if not _was_moving and _grounded:
		apply_central_impulse(desired_direction * ground_start_impulse * get_movement_multiplier() * control_multiplier)
	_was_moving = true

	var acceleration := (ground_acceleration if _grounded else air_acceleration) * get_movement_multiplier()
	var control_speed := (ground_control_speed if _grounded else air_control_speed) * get_movement_multiplier()
	var speed_along_input := planar_velocity.dot(desired_direction)
	var acceleration_factor := 1.0
	if speed_along_input >= control_speed:
		acceleration_factor = 0.12 if _grounded else air_steering_strength * 0.18
	elif not _grounded:
		acceleration_factor = air_steering_strength

	if planar_velocity.length_squared() > 0.5 and planar_velocity.normalized().dot(desired_direction) < -0.18:
		acceleration += ground_counter_acceleration if _grounded else ground_counter_acceleration * 0.22
	apply_central_force(desired_direction * acceleration * mass * acceleration_factor * control_multiplier)
	if _grounded:
		var roll_axis := Vector3.UP.cross(desired_direction).normalized()
		apply_torque(roll_axis * movement_roll_torque * control_multiplier)


func _update_fling_charge(delta: float) -> void:
	if Input.is_action_just_pressed("charge_fling"):
		_is_charging_fling = true
		_maximum_charge_announced = false
		fling_charge = 0.0
		fling_charge_started.emit()
	if _is_charging_fling and Input.is_action_pressed("charge_fling"):
		fling_charge = minf(fling_charge + delta * get_charge_rate_multiplier(), maximum_charge_time)
		var ratio := get_charge_ratio()
		fling_charge_updated.emit(ratio)
		if ratio >= 1.0 and not _maximum_charge_announced:
			_maximum_charge_announced = true
			fling_maximum_reached.emit()
	if Input.is_action_just_released("charge_fling") and _is_charging_fling:
		_release_fling(get_charge_ratio())


func _release_fling(charge_ratio: float) -> void:
	var direction := aim_direction.normalized()
	if direction.length_squared() <= 0.001:
		direction = _forward_flat()
	direction = (direction + Vector3.UP * fling_upward_assist).normalized()
	var launch_strength := calculate_fling_strength(charge_ratio)
	var opposing_speed := maxf(-linear_velocity.dot(direction), 0.0)
	var correction_impulse := direction * opposing_speed * mass * 0.95
	apply_central_impulse(direction * launch_strength + correction_impulse)
	_post_fling_control_timer = fling_control_reduction_time * charge_ratio
	_recent_fling_timer = 0.65
	_recent_fling_charge = charge_ratio
	_hit_visual(0.16)
	_launch_visual(0.34 + charge_ratio * 0.66)
	fling_released.emit(charge_ratio)
	cancel_active_charge()


func _update_shooting() -> void:
	if Input.is_action_just_pressed("shoot") and _shot_cooldown_timer <= 0.0:
		_emit_shot_request()


func _emit_shot_request() -> void:
	if not shooting_enabled or not input_enabled or not local_controlled or _shot_cooldown_timer > 0.0 or _shooting_locked:
		return
	var direction := aim_direction.normalized()
	if direction.length_squared() <= 0.001:
		direction = _forward_flat()
	var origin := global_position + direction * 3.75 + Vector3.UP * 0.25
	apply_central_impulse(-direction * shot_recoil_impulse + Vector3.UP * 1.4)
	_launch_visual(0.13)
	_shot_cooldown_timer = shot_cooldown / get_fire_rate_multiplier()
	shoot_requested.emit(origin, direction)


func _charge_control_multiplier() -> float:
	if not _is_charging_fling:
		return 1.0
	var ratio := get_charge_ratio()
	return 1.0 if ratio <= 0.25 else lerpf(0.875, 0.5, (ratio - 0.25) / 0.75)


func set_equipped_ability(ability_id: String) -> void:
	_equipped_ability_id = ability_id


func get_equipped_ability() -> String:
	return _equipped_ability_id


func get_charge_rate_multiplier() -> float:
	var multiplier := ABILITY_TUNING.QUICK_CHARGE_MULTIPLIER if _equipped_ability_id == "quick_charge" else 1.0
	return multiplier * (ABILITY_TUNING.ADRENALINE_CHARGE_MULTIPLIER if _adrenaline_active else 1.0)


func get_movement_multiplier() -> float:
	return ABILITY_TUNING.ADRENALINE_MOVEMENT_MULTIPLIER if _adrenaline_active else 1.0


func is_adrenaline_active() -> bool:
	return _adrenaline_active


func get_adrenaline_fov_bonus() -> float:
	return ABILITY_TUNING.ADRENALINE_FOV_BONUS if _adrenaline_active else 0.0


func _update_adrenaline() -> void:
	_adrenaline_active = _equipped_ability_id == "adrenaline" and health > 0 and float(health) / maxf(float(max_health), 1.0) < ABILITY_TUNING.ADRENALINE_HEALTH_THRESHOLD


func set_overcharge_active(active: bool) -> void:
	_overcharge_active = active


func set_shooting_locked(locked: bool) -> void:
	_shooting_locked = locked


func get_fire_rate_multiplier() -> float:
	return ABILITY_TUNING.OVERCHARGE_FIRE_RATE_MULTIPLIER if _overcharge_active else 1.0


func set_scanner_highlight(enabled: bool) -> void:
	if _scanner_outline == null:
		_scanner_outline = MeshInstance3D.new()
		_scanner_outline.name = "ScannerOutline"
		_scanner_outline.mesh = SphereMesh.new()
		_scanner_outline.scale = Vector3.ONE * 1.19
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = Color(1.0, 0.08, 0.12, 0.3)
		material.emission_enabled = true
		material.emission = Color(1.0, 0.02, 0.06, 1.0)
		material.no_depth_test = true
		_scanner_outline.material_override = material
		$VisualRoot.add_child(_scanner_outline)
	_scanner_outline.visible = enabled


func set_phase_bubble(active: bool) -> void:
	_phase_bubble_active = active
	if _phase_bubble_visual == null:
		_phase_bubble_visual = MeshInstance3D.new()
		_phase_bubble_visual.name = "PhaseBubble"
		var bubble_mesh := SphereMesh.new()
		bubble_mesh.radius = 1.32
		bubble_mesh.height = 2.64
		_phase_bubble_visual.mesh = bubble_mesh
		var material := StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = Color(0.16, 0.8, 1.0, 0.14)
		material.emission_enabled = true
		material.emission = Color(0.1, 0.64, 1.0, 1.0)
		material.emission_energy_multiplier = 1.5
		_phase_bubble_visual.material_override = material
		$VisualRoot.add_child(_phase_bubble_visual)
	_phase_bubble_visual.visible = active


func receives_projectile_damage() -> bool:
	return not _phase_bubble_active


func _post_fling_control_multiplier() -> float:
	if _post_fling_control_timer <= 0.0 or fling_control_reduction_time <= 0.0:
		return 1.0
	var recovery := 1.0 - _post_fling_control_timer / fling_control_reduction_time
	return lerpf(fling_control_multiplier, 1.0, clampf(recovery, 0.0, 1.0))


func _apply_emergency_speed_guard() -> void:
	var speed := linear_velocity.length()
	if speed > emergency_max_speed:
		linear_velocity = linear_velocity.normalized() * emergency_max_speed


func _update_remote_transform(delta: float) -> void:
	global_position = global_position.lerp(_network_target_position, 1.0 - exp(-18.0 * delta))
	rotation = Vector3(
		lerp_angle(rotation.x, _network_target_rotation.x, 1.0 - exp(-18.0 * delta)),
		lerp_angle(rotation.y, _network_target_rotation.y, 1.0 - exp(-18.0 * delta)),
		lerp_angle(rotation.z, _network_target_rotation.z, 1.0 - exp(-18.0 * delta))
	)


func _on_body_entered(_body: Node) -> void:
	if not local_controlled:
		return
	var impact_strength := linear_velocity.length()
	if impact_strength >= 7.0:
		impact_event.emit(global_position, impact_strength)


func _on_contact_area_entered(area: Area3D) -> void:
	if not local_controlled:
		return
	var other := area.get_parent() as RigidBody3D
	if other == null or other == self:
		return
	var is_network_blob := other.is_in_group("network_blob")
	var target_peer_id := int(other.get("network_peer_id")) if is_network_blob else 0
	if is_network_blob:
		if network_peer_id >= target_peer_id:
			return
	elif other.get_instance_id() < get_instance_id():
		return

	var now := Time.get_ticks_msec()
	var pair_key := other.get_instance_id()
	if now < int(_collision_ready_at.get(pair_key, 0)):
		return
	_collision_ready_at[pair_key] = now + int(collision_pair_cooldown * 1000.0)

	var normal := (other.global_position - global_position).normalized()
	if normal.length_squared() < 0.01:
		return
	var relative_velocity := linear_velocity - other.linear_velocity
	var closing_speed := relative_velocity.dot(normal)
	if closing_speed < 3.0:
		return

	var self_toward := linear_velocity.dot(normal)
	var other_toward := -other.linear_velocity.dot(normal)
	var self_is_attacker := self_toward >= other_toward
	var attacker_speed := linear_velocity.length() if self_is_attacker else other.linear_velocity.length()
	var fling_multiplier := 1.0 + _recent_fling_charge * 1.15 if self_is_attacker and _recent_fling_timer > 0.0 else 1.0
	var raw_damage := maxf(closing_speed - 5.0, 0.0) * impact_damage_scale + maxf(attacker_speed - 13.0, 0.0) * velocity_damage_scale
	var collision_damage := 0 if raw_damage < 5.0 else clampi(int(round(raw_damage * fling_multiplier)), 5, 60)
	var impulse_strength := clampf(closing_speed * minf(mass, other.mass) * 1.9 * fling_multiplier, 14.0, 230.0)
	var impulse := (normal + Vector3.UP * 0.08).normalized() * impulse_strength
	var self_damage := 0 if self_is_attacker else collision_damage
	var other_damage := collision_damage if self_is_attacker else 0
	receive_collision_impact(self_damage, -impulse)
	if is_network_blob:
		network_collision_requested.emit(target_peer_id, impulse, other_damage)
	elif other.has_method("receive_collision_impact"):
		other.call("receive_collision_impact", other_damage, impulse)
	else:
		other.sleeping = false
		other.apply_central_impulse(impulse)


func _hit_visual(amount: float) -> void:
	var visual := get_node_or_null("VisualRoot")
	if visual != null and visual.has_method("hit_reaction"):
		visual.hit_reaction(amount)


func _launch_visual(amount: float) -> void:
	var visual := get_node_or_null("VisualRoot")
	if visual != null and visual.has_method("set_launch_energy"):
		visual.set_launch_energy(amount)


func _update_speed_trail() -> void:
	if speed_trail != null:
		var speed_ratio := clampf((linear_velocity.length() - 18.0) / 58.0, 0.0, 1.0)
		speed_trail.emitting = speed_ratio > 0.06 or _recent_fling_timer > 0.0
		speed_trail.amount = maxi(1, int(round(float(_trail_base_amount) * lerpf(0.55, 1.0, speed_ratio))))
		speed_trail.lifetime = _trail_base_lifetime * lerpf(0.55, 1.0, speed_ratio)


func _forward_flat() -> Vector3:
	var forward := -Basis(Vector3.UP, aim_yaw).z
	return Vector3(forward.x, 0.0, forward.z).normalized()


func _update_face() -> void:
	if face_root == null or not is_inside_tree():
		return
	face_root.global_position = global_position
	var direction := aim_direction.normalized()
	if direction.length_squared() <= 0.001:
		direction = _forward_flat()
	var up := Vector3.FORWARD if absf(direction.dot(Vector3.UP)) > 0.97 else Vector3.UP
	face_root.look_at(global_position + direction, up)


func _update_health_billboard() -> void:
	if health_billboard != null:
		health_billboard.text = "%s\n%d / %d" % [display_name, health, max_health]
