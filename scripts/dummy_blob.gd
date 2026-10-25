class_name DummyBlob
extends RigidBody3D

const BLOB_MATERIAL_KIT := preload("res://scripts/blob_material_kit.gd")
const TRAINING := preload("res://scripts/practice_training.gd")

signal health_changed(current_health: int, max_health: int)
signal damage_taken(amount: int, world_position: Vector3)
signal defeated(world_position: Vector3)
signal shot_requested(origin: Vector3, direction: Vector3)

@export var max_health := 150
@export var respawn_delay := TRAINING.RESPAWN_DELAY
@export var blob_color := Color(1.0, 0.38, 0.18, 1.0)
@export var display_name := ""

const FUNNY_NAMES: PackedStringArray = [
	"Bob", "Sir Bounces", "Jellybean", "Wobbleton",
	"Mochi", "Boop", "Captain Squish", "Pogo",
	"Noodle", "Sprinkles", "Bloop", "Pickles",
	"Gumdrop", "Tater Tot", "Biscuit", "Wiggles",
]

var health := 150
## Training configuration. The practice session owns these - a dummy left alone
## holds still with an infinite health pool, which is the spec's default.
var training_mode := TRAINING.DEFAULT_MODE
var health_preset := TRAINING.DEFAULT_HEALTH
var movement_enabled := true
var dummy_shooting_enabled := false
var damage_numbers_enabled := true
var speed_scale := TRAINING.DEFAULT_SPEED_SCALE

var _spawn_position := Vector3.ZERO
var _respawn_timer := 0.0
var _collision_ready_at: Dictionary = {}
var _practice_target: Node3D = null
var _lane_axis := Vector3.RIGHT
var _mode_time := 0.0
var _bounce_timer := 0.0
var _aim_dwell := 0.0
var _dodge_cooldown := 0.0
var _dodge_sign := 1.0
var _fire_timer := 0.0
var _defeated := false
var _flash_tween: Tween
@onready var nameplate_root: Node3D = $Nameplate
@onready var name_label: Label3D = $Nameplate/Name
@onready var health_fill: MeshInstance3D = $Nameplate/HealthFill
@onready var mesh: MeshInstance3D = $VisualRoot/Mesh
@onready var face_root: Node3D = $FaceRoot

var _face_direction := Vector3.FORWARD
var _scanner_outline: MeshInstance3D


func _ready() -> void:
	can_sleep = true
	contact_monitor = true
	max_contacts_reported = 12
	$ContactArea.area_entered.connect(_on_contact_area_entered)
	_spawn_position = global_position
	if display_name.strip_edges().is_empty():
		display_name = _stable_funny_name()
	# Strafe lanes run along the blueprint's X axis, matching the sheet's
	# left-to-right dummy rows. The phase offset keeps the eight dummies from
	# sliding in lockstep, which would read as one animated wall.
	_mode_time = float(absi(String(name).hash()) % 1000) * 0.001 * TRAINING.STRAFE_PERIOD
	_apply_health_preset()
	health_changed.emit(health, max_health)
	_apply_blob_color()
	_update_health_billboard()


func _physics_process(delta: float) -> void:
	if global_position.y < -15.0:
		respawn()

	if _respawn_timer > 0.0:
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			respawn()
	else:
		_update_training_behaviour(delta)
	var flat_velocity := Vector3(linear_velocity.x, 0.0, linear_velocity.z)
	if flat_velocity.length_squared() > 1.0:
		_face_direction = _face_direction.lerp(flat_velocity.normalized(), 1.0 - exp(-5.0 * delta)).normalized()
	_update_face()
	_update_nameplate_transform()


## Training configuration ------------------------------------------------------
## The practice session drives all of these; a dummy nobody configures keeps the
## spec's defaults (static, infinite health).


func configure_training(mode: int, preset: int, move: bool, shoot: bool, numbers: bool, scale: float) -> void:
	set_training_mode(mode)
	set_health_preset(preset)
	movement_enabled = move
	dummy_shooting_enabled = shoot
	damage_numbers_enabled = numbers
	speed_scale = maxf(scale, 0.05)


func set_training_mode(mode: int) -> void:
	if not TRAINING.MODE_IDS.has(mode):
		mode = TRAINING.DEFAULT_MODE
	if mode == training_mode:
		return
	training_mode = mode
	_aim_dwell = 0.0
	_bounce_timer = 0.0
	_fire_timer = 0.0
	# Leaving a movement mode should park the dummy, not let it coast off its
	# station on the last frame's momentum.
	if mode == TRAINING.MODE_STATIC or mode == TRAINING.MODE_COMBAT:
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO


## Swapping presets re-pools health immediately so the player never has to shoot
## a dummy down to see the new setting take effect.
func set_health_preset(preset: int) -> void:
	if not TRAINING.HEALTH_PRESETS.has(preset):
		preset = TRAINING.DEFAULT_HEALTH
	health_preset = preset
	_apply_health_preset()
	health_changed.emit(health, max_health)
	_update_health_billboard()


func set_practice_target(target: Node3D) -> void:
	_practice_target = target


func has_infinite_health() -> bool:
	return health_preset == TRAINING.HEALTH_INFINITE


func _apply_health_preset() -> void:
	max_health = TRAINING.health_pool_for(health_preset)
	health = max_health
	_defeated = false


## Behaviour modes -------------------------------------------------------------
## Every mode steers with forces and impulses rather than teleporting, so a shot
## still knocks the dummy off its pattern and it eases back on its own.
func _update_training_behaviour(delta: float) -> void:
	if freeze or not movement_enabled:
		_aim_dwell = 0.0
		return
	_mode_time += delta * speed_scale
	_dodge_cooldown = maxf(_dodge_cooldown - delta, 0.0)
	if training_mode == TRAINING.MODE_STRAFE:
		_update_strafe()
	elif training_mode == TRAINING.MODE_BOUNCE:
		_update_bounce(delta)
	elif training_mode == TRAINING.MODE_DODGE:
		_update_dodge(delta)
	elif training_mode == TRAINING.MODE_COMBAT:
		_update_combat(delta)


## A ~3 GU lane walked on a sine, so both turns ease instead of snapping.
func _update_strafe() -> void:
	var offset := sin(_mode_time * TAU / TRAINING.STRAFE_PERIOD) * TRAINING.STRAFE_HALF_LANE
	_steer_toward(_spawn_position + _lane_axis * offset, TRAINING.STRAFE_ACCEL)


func _update_bounce(delta: float) -> void:
	_steer_toward(_spawn_position, TRAINING.BOUNCE_RECENTER_ACCEL)
	_bounce_timer -= delta * speed_scale
	if _bounce_timer > 0.0 or not _is_grounded():
		return
	_bounce_timer = TRAINING.BOUNCE_INTERVAL
	sleeping = false
	linear_velocity.y = TRAINING.BOUNCE_HOP_SPEED


## Dodges only after the player holds a direct aim, then commits to one sidestep
## and goes quiet for the cooldown - never a constant jitter.
func _update_dodge(delta: float) -> void:
	if _flat_offset_from_spawn().length() > TRAINING.DODGE_LEASH:
		_steer_toward(_spawn_position, TRAINING.BOUNCE_RECENTER_ACCEL)
	if _is_player_aiming_here():
		_aim_dwell += delta
	else:
		_aim_dwell = maxf(_aim_dwell - delta * 2.0, 0.0)
	if _aim_dwell < TRAINING.DODGE_AIM_DWELL or _dodge_cooldown > 0.0:
		return
	_aim_dwell = 0.0
	_dodge_cooldown = TRAINING.DODGE_COOLDOWN
	var lateral := _lateral_from_player()
	if lateral.length_squared() < 0.01:
		return
	# Alternate sides, but always dodge back toward the station once the last
	# hop pushed the dummy past its leash.
	var offset := _flat_offset_from_spawn()
	if offset.length() > TRAINING.DODGE_LEASH * 0.5:
		_dodge_sign = -1.0 if offset.dot(lateral) > 0.0 else 1.0
	sleeping = false
	apply_central_impulse(lateral * _dodge_sign * TRAINING.DODGE_IMPULSE)
	_dodge_sign = -_dodge_sign


## Simple return fire so the player can practise moving under pressure. The
## projectile itself is spawned by the practice session, which owns whether the
## shot is allowed to deal damage.
func _update_combat(delta: float) -> void:
	if not dummy_shooting_enabled or _practice_target == null or not is_instance_valid(_practice_target):
		return
	_fire_timer -= delta * speed_scale
	if _fire_timer > 0.0:
		return
	var to_target := _practice_target.global_position - global_position
	if to_target.length() > TRAINING.COMBAT_RANGE or not _has_line_of_sight():
		return
	_fire_timer = TRAINING.COMBAT_FIRE_INTERVAL
	var spread := Vector3(
		randf_range(-1.0, 1.0), randf_range(-0.4, 0.4), randf_range(-1.0, 1.0)
	) * TRAINING.COMBAT_AIM_SPREAD
	var direction := (to_target.normalized() + spread).normalized()
	shot_requested.emit(global_position + direction * TRAINING.COMBAT_MUZZLE_OFFSET, direction)


## Horizontal-only proportional steering, capped as an acceleration so mass
## changes never turn a nudge into a launch.
func _steer_toward(target: Vector3, max_accel: float) -> void:
	var to_target := target - global_position
	to_target.y = 0.0
	var desired := to_target * 2.6
	var current := Vector3(linear_velocity.x, 0.0, linear_velocity.z)
	var accel := (desired - current) * 4.0
	if accel.length_squared() < 0.0001:
		return
	sleeping = false
	apply_central_force(accel.limit_length(max_accel) * mass)


func _flat_offset_from_spawn() -> Vector3:
	var offset := global_position - _spawn_position
	offset.y = 0.0
	return offset


func _is_grounded() -> bool:
	var cast := get_node_or_null("GroundCast") as ShapeCast3D
	return cast != null and cast.is_colliding()


func _is_player_aiming_here() -> bool:
	if _practice_target == null or not is_instance_valid(_practice_target):
		return false
	var aim_value: Variant = _practice_target.get("aim_direction")
	if typeof(aim_value) != TYPE_VECTOR3:
		return false
	var aim := aim_value as Vector3
	if aim.length_squared() < 0.001:
		return false
	var to_self := global_position - _practice_target.global_position
	if to_self.length_squared() < 0.001:
		return false
	return aim.normalized().dot(to_self.normalized()) >= TRAINING.DODGE_AIM_DOT


func _lateral_from_player() -> Vector3:
	var to_self := global_position - _practice_target.global_position
	to_self.y = 0.0
	if to_self.length_squared() < 0.001:
		return Vector3.ZERO
	return to_self.normalized().cross(Vector3.UP).normalized()


## Cover matters: a dummy behind a blueprint cover block holds its fire.
func _has_line_of_sight() -> bool:
	if not is_inside_tree():
		return false
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		global_position, _practice_target.global_position, 1
	)
	query.exclude = [get_rid()]
	return space.intersect_ray(query).is_empty()


func take_damage(amount: int, hit_direction: Vector3, knockback: float) -> void:
	if _respawn_timer > 0.0:
		return

	_register_damage(amount)
	sleeping = false
	var launch_direction := (hit_direction.normalized() + Vector3.UP * 0.42).normalized()
	apply_central_impulse(launch_direction * knockback * 1.55)
	var visual := get_node_or_null("VisualRoot")
	if visual != null and visual.has_method("hit_reaction"):
		visual.hit_reaction(0.72)

	if health <= 0:
		_begin_defeat()


func receive_collision_impact(amount: int, impulse: Vector3) -> void:
	if _respawn_timer > 0.0:
		return
	sleeping = false
	var lift := Vector3.UP * clampf(impulse.length() * 0.36, 8.0, 50.0)
	apply_central_impulse((impulse + lift) * 1.2)
	var visual := get_node_or_null("VisualRoot")
	if visual != null and visual.has_method("hit_reaction"):
		visual.hit_reaction(clampf(impulse.length() * 0.012, 0.3, 0.9))
	_register_damage(amount)
	if health <= 0:
		_begin_defeat()


## One place where a hit becomes numbers. Infinite health absorbs the hit but
## still reports it, so the floating number and the practice HUD's damage total
## read the same in every health mode.
func _register_damage(amount: int) -> void:
	if amount <= 0:
		return
	damage_taken.emit(amount, global_position)
	_flash_hit()
	BLOB_MATERIAL_KIT.flash_hit(mesh)
	if damage_numbers_enabled:
		_spawn_damage_number(amount)
	if has_infinite_health():
		return
	health = maxi(health - amount, 0)
	health_changed.emit(health, max_health)
	_update_health_billboard()


## Finite-health defeat: pop, vanish, and return to the same station at full
## health after the respawn delay. Practice never pays out coins or scores.
func _begin_defeat() -> void:
	if _defeated:
		return
	_defeated = true
	_respawn_timer = respawn_delay
	defeated.emit(global_position)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	_set_body_active(false)


func respawn() -> void:
	freeze = true
	global_position = _spawn_position
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	reset_physics_interpolation()
	sleeping = false
	freeze = false
	health = max_health
	_respawn_timer = 0.0
	_defeated = false
	_bounce_timer = 0.0
	_aim_dwell = 0.0
	_dodge_cooldown = 0.0
	_set_body_active(true)
	health_changed.emit(health, max_health)
	_update_health_billboard()


## Popped dummies stop being shootable while they are gone, so a stray shot into
## an empty station is scored as the miss it is.
func _set_body_active(active: bool) -> void:
	collision_layer = 2 if active else 0
	for child_name in ["VisualRoot", "FaceRoot", "Nameplate"]:
		var child := get_node_or_null(child_name) as Node3D
		if child != null:
			child.visible = active
	var hurtbox := get_node_or_null("Hurtbox") as Area3D
	if hurtbox != null:
		hurtbox.collision_layer = 8 if active else 0


## Brief emission pop on the body, paired with the squash from hit_reaction, so
## a hit reads instantly and the dummy is back to normal by the next shot.
func _flash_hit() -> void:
	if mesh == null:
		return
	var material := mesh.material_override as StandardMaterial3D
	if material == null or not material.emission_enabled:
		return
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	material.emission_energy_multiplier = 2.4
	_flash_tween = create_tween()
	_flash_tween.tween_property(material, "emission_energy_multiplier", 0.35, 0.22)


## Floating damage readout, spawned into the world so several hits stack up the
## way the spec's "display damage number" implies.
func _spawn_damage_number(amount: int) -> void:
	if not is_inside_tree():
		return
	var label := Label3D.new()
	label.text = str(amount)
	label.font_size = 44
	label.outline_size = 14
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.modulate = Color(1.0, 0.86, 0.42)
	label.outline_modulate = Color(0.06, 0.05, 0.03, 0.9)
	label.top_level = true
	get_parent().add_child(label)
	label.global_position = global_position + Vector3.UP * 3.2 + Vector3(
		randf_range(-0.9, 0.9), 0.0, randf_range(-0.9, 0.9)
	)
	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y + 3.4, 0.75).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "modulate:a", 0.0, 0.75).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(label.queue_free)


func _update_health_billboard() -> void:
	if name_label != null:
		name_label.text = display_name
	if health_fill != null:
		var health_ratio := clampf(float(health) / maxf(float(max_health), 1.0), 0.0, 1.0)
		health_fill.scale = Vector3(health_ratio, 1.0, 1.0)
		# Keep the left edge fixed so damage reads as a conventional depleting
		# bar instead of shrinking toward its centre. 1.8 is half the fill
		# quad's 3.6 width.
		health_fill.position.x = -1.8 * (1.0 - health_ratio)


func _update_nameplate_transform() -> void:
	if nameplate_root == null:
		return
	nameplate_root.global_position = global_position + Vector3.UP * 5.35
	# Same node-level billboarding as BlobPlayer: the bar quads no longer
	# billboard per-material, so the assembly must face the camera as one unit.
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	if camera != null:
		nameplate_root.global_basis = camera.global_basis
	else:
		nameplate_root.global_rotation = Vector3.ZERO


func _stable_funny_name() -> String:
	# Scene-node identity makes names feel randomly assigned while remaining
	# deterministic across respawns, replays, and multiplayer test runs.
	var stable_hash := absi(String(name).hash())
	return FUNNY_NAMES[stable_hash % FUNNY_NAMES.size()]


func _apply_blob_color() -> void:
	if mesh == null:
		return

	var material := StandardMaterial3D.new()
	material.albedo_color = blob_color
	material.metallic = 0.08
	material.roughness = 0.28
	material.emission_enabled = true
	material.emission = blob_color.darkened(0.48)
	material.emission_energy_multiplier = 0.35
	BLOB_MATERIAL_KIT.decorate(material, blob_color)
	mesh.material_override = material
	BLOB_MATERIAL_KIT.apply_outline(mesh, blob_color)
	if name_label != null:
		name_label.modulate = blob_color.lightened(0.35)


func set_scanner_highlight(enabled: bool) -> void:
	if _scanner_outline == null:
		_scanner_outline = MeshInstance3D.new()
		_scanner_outline.name = "ScannerOutline"
		var outline_mesh := SphereMesh.new()
		outline_mesh.radius = 1.18
		outline_mesh.height = 2.36
		_scanner_outline.mesh = outline_mesh
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = Color(1.0, 0.12, 0.16, 0.3)
		material.emission_enabled = true
		material.emission = Color(1.0, 0.03, 0.08)
		material.emission_energy_multiplier = 1.8
		material.no_depth_test = true
		_scanner_outline.material_override = material
		$VisualRoot.add_child(_scanner_outline)
	_scanner_outline.visible = enabled


func _update_face() -> void:
	if face_root == null or not is_inside_tree():
		return
	face_root.global_position = global_position
	face_root.look_at(global_position + _face_direction, Vector3.UP)


func _on_contact_area_entered(area: Area3D) -> void:
	var other := area.get_parent() as RigidBody3D
	if other == null or other == self or other.get_instance_id() < get_instance_id():
		return
	if other.is_in_group("network_blob") and not bool(other.get("local_controlled")):
		return

	var now := Time.get_ticks_msec()
	if now < int(_collision_ready_at.get(other.get_instance_id(), 0)):
		return
	_collision_ready_at[other.get_instance_id()] = now + 160
	var normal := (other.global_position - global_position).normalized()
	if normal.length_squared() < 0.01:
		normal = linear_velocity.normalized()

	var relative_velocity := linear_velocity - other.linear_velocity
	var closing_speed: float = relative_velocity.dot(normal)
	if closing_speed < 3.0:
		return

	var impulse_strength: float = clampf(closing_speed * minf(mass, other.mass) * 1.9, 14.0, 230.0)
	var impulse := (normal + Vector3.UP * 0.08).normalized() * impulse_strength
	sleeping = false
	other.sleeping = false
	apply_central_impulse(-impulse)
	other.apply_central_impulse(impulse)
	var visual := get_node_or_null("VisualRoot")
	if visual != null and visual.has_method("hit_reaction"):
		visual.hit_reaction(clampf(impulse_strength * 0.012, 0.24, 0.72))
	var other_visual := other.get_node_or_null("VisualRoot")
	if other_visual != null and other_visual.has_method("hit_reaction"):
		other_visual.hit_reaction(clampf(impulse_strength * 0.012, 0.24, 0.72))
