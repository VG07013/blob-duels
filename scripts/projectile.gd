extends Area3D

const ABILITY_TUNING := preload("res://scripts/ability_tuning.gd")

signal hit_confirmed(target: Node3D, world_position: Vector3, damage_target: bool, impact_direction: Vector3, damage: int, knockback: float)
signal ricocheted(world_position: Vector3, surface_normal: Vector3)
signal phase_absorbed(world_position: Vector3)

@export var speed := 150.0
@export var lifetime := 2.4
@export var hit_impulse := 135.0
@export var damage := 30

var velocity := Vector3.ZERO
var source: Node
var _has_hit := false
var _damage_enabled := true
var _ricochet_enabled := false
var _ricochet_bounces_remaining := 0
var _base_damage := 0
var _base_speed := 0.0
var _visual_time := 0.0
var _base_mesh_scale := Vector3.ONE
var _active_mesh_scale := Vector3.ONE
var _ricochet_scale := 1.0
var _base_mesh_material: Material
var _base_glow_color := Color.WHITE
var _base_glow_energy := 1.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	var visual := get_node_or_null("Mesh") as MeshInstance3D
	if visual != null:
		_base_mesh_scale = visual.scale
		_active_mesh_scale = _base_mesh_scale
		_base_mesh_material = visual.material_override
	var glow := get_node_or_null("Glow") as OmniLight3D
	if glow != null:
		_base_glow_color = glow.light_color
		_base_glow_energy = glow.light_energy


func configure(spawn_position: Vector3, direction: Vector3, shot_source: Node, damage_enabled: bool = true, ricochet_enabled: bool = false, rail_enabled: bool = false) -> void:
	if _base_damage <= 0:
		_base_damage = damage
	if _base_speed <= 0.0:
		_base_speed = speed
	damage = _base_damage
	speed = _base_speed
	_visual_time = 0.0
	_ricochet_scale = 1.0
	global_position = spawn_position
	velocity = direction.normalized() * speed
	source = shot_source
	_damage_enabled = damage_enabled
	_ricochet_enabled = ricochet_enabled
	_ricochet_bounces_remaining = 3 if ricochet_enabled else 0
	var visual := get_node_or_null("Mesh") as MeshInstance3D
	if visual != null:
		visual.scale = _base_mesh_scale
		visual.material_override = _base_mesh_material
	_active_mesh_scale = _base_mesh_scale
	var glow := get_node_or_null("Glow") as OmniLight3D
	if glow != null:
		glow.light_color = _base_glow_color
		glow.light_energy = _base_glow_energy
	if ricochet_enabled:
		damage += 10
		if visual != null:
			var material := StandardMaterial3D.new()
			material.albedo_color = Color(0.28, 0.78, 1.0, 1.0)
			material.emission_enabled = true
			material.emission = Color(0.08, 0.52, 1.0, 1.0)
			visual.material_override = material
		if glow != null:
			glow.light_color = Color(0.18, 0.65, 1.0, 1.0)
	if rail_enabled:
		speed = ABILITY_TUNING.RAIL_SHOT_SPEED
		velocity = direction.normalized() * speed
		damage += ABILITY_TUNING.RAIL_SHOT_DAMAGE_BONUS
		var rail_visual := get_node_or_null("Mesh") as MeshInstance3D
		if rail_visual != null:
			rail_visual.scale = Vector3(0.24, 0.24, 2.8)
			_active_mesh_scale = rail_visual.scale
			var rail_material := StandardMaterial3D.new()
			rail_material.albedo_color = Color(0.96, 0.98, 1.0, 1.0)
			rail_material.emission_enabled = true
			rail_material.emission = Color(0.85, 0.94, 1.0, 1.0)
			rail_material.emission_energy_multiplier = 4.0
			rail_visual.material_override = rail_material
	look_at(global_position + direction, Vector3.UP)


func _physics_process(delta: float) -> void:
	_update_visual_pulse(delta)
	var next_position := global_position + velocity * delta
	var query := PhysicsRayQueryParameters3D.create(global_position, next_position)
	query.collision_mask = 11
	query.collide_with_areas = true
	if source != null:
		var excluded: Array[RID] = []
		var source_body := source as CollisionObject3D
		var source_hurtbox := source.get_node_or_null("Hurtbox") as CollisionObject3D
		if source_body != null:
			excluded.append(source_body.get_rid())
		if source_hurtbox != null:
			excluded.append(source_hurtbox.get_rid())
		query.exclude = excluded
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var collider := hit.get("collider") as Node3D
		var body := _resolve_target(collider)
		if _can_ricochet(body):
			_ricochet(Vector3(hit.get("normal", Vector3.UP)))
			return
		if body != null:
			_on_body_entered(body)
		return

	global_position = next_position
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()


func _on_body_entered(body: Node3D) -> void:
	if _has_hit or body == source:
		return
	if body.has_method("receives_projectile_damage") and not bool(body.call("receives_projectile_damage")):
		_has_hit = true
		phase_absorbed.emit(global_position)
		queue_free()
		return
	_has_hit = true

	var impact_direction := velocity.normalized()
	var impact_vector := impact_direction * hit_impulse + Vector3.UP * (12.0 + hit_impulse * 0.18)
	var damage_target := body.has_method("take_damage")
	if damage_target and _damage_enabled:
		var direct_damage := not body.has_method("receives_direct_damage") or bool(body.call("receives_direct_damage"))
		if direct_damage:
			body.take_damage(damage, impact_direction, hit_impulse)
	elif _damage_enabled:
		var rigid_body := body as RigidBody3D
		if rigid_body != null:
			rigid_body.apply_central_impulse(impact_vector)

	hit_confirmed.emit(body, global_position, damage_target, impact_direction, damage, hit_impulse)
	queue_free()


func _on_area_entered(area: Area3D) -> void:
	var target := _resolve_target(area)
	if target != null:
		_on_body_entered(target)


func _resolve_target(collider: Node3D) -> Node3D:
	if collider is Area3D and collider.is_in_group("blob_hurtbox"):
		return collider.get_parent() as Node3D
	return collider


func _can_ricochet(body: Node3D) -> bool:
	if not _ricochet_enabled or _ricochet_bounces_remaining <= 0 or body == null:
		return false
	return not body.has_method("take_damage") and not body.is_in_group("network_blob")


func _ricochet(normal: Vector3) -> void:
	var safe_normal := normal.normalized()
	if safe_normal.length_squared() <= 0.001:
		safe_normal = Vector3.UP
	velocity = velocity.bounce(safe_normal) * 0.95
	_ricochet_bounces_remaining -= 1
	ricocheted.emit(global_position, safe_normal)
	var visual := get_node_or_null("Mesh") as MeshInstance3D
	if visual != null:
		_ricochet_scale = 1.38
	var trail := get_node_or_null("Trail") as GPUParticles3D
	if trail != null:
		trail.restart()
	global_position += velocity.normalized() * 0.08
	look_at(global_position + velocity.normalized(), Vector3.UP)


func deflect_from(center: Vector3, strength: float, delta: float) -> void:
	var away := global_position - center
	if away.length_squared() <= 0.001:
		return
	var speed_ratio := clampf(150.0 / maxf(velocity.length(), 1.0), 0.18, 1.0)
	velocity += away.normalized() * strength * speed_ratio * delta
	velocity = velocity.normalized() * speed
	look_at(global_position + velocity.normalized(), Vector3.UP)


func is_ricochet_shot() -> bool:
	return _ricochet_enabled


func _update_visual_pulse(delta: float) -> void:
	_visual_time += delta
	var visual := get_node_or_null("Mesh") as MeshInstance3D
	var glow := get_node_or_null("Glow") as OmniLight3D
	if visual == null:
		return
	var pulse := 1.0 + sin(_visual_time * (16.0 if _ricochet_enabled else 11.0)) * (0.06 if _ricochet_enabled else 0.035)
	_ricochet_scale = move_toward(_ricochet_scale, 1.0, delta * 6.5)
	visual.scale = _active_mesh_scale * pulse * _ricochet_scale
	if glow != null:
		glow.light_energy = (2.35 if _ricochet_enabled else 1.35) + sin(_visual_time * 12.0) * 0.24
