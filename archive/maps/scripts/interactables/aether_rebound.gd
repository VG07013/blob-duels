class_name AetherRebound
extends Area3D

@export var round_shape := true
@export var fixed_direction := Vector3.ZERO
@export var horizontal_multiplier := 1.08
@export var radius := 4.332
@export var height := 8.664
@export var box_size := Vector3(1.444, 11.552, 20.216)

var _flash := 0.0
var _glow_visual: MeshInstance3D


func configure(is_round: bool, direction: Vector3, multiplier: float, size: Vector3 = Vector3.ZERO) -> void:
	round_shape = is_round
	fixed_direction = direction.normalized() if direction.length_squared() > 0.001 else Vector3.ZERO
	horizontal_multiplier = multiplier
	if not is_round and size != Vector3.ZERO:
		box_size = size


func _ready() -> void:
	add_to_group("map_interactable")
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(activate_body)
	_build_model()


func get_interaction_kind() -> StringName:
	return &"aether_rebound"


func activate_body(body: Node3D) -> bool:
	var rigid := body as RigidBody3D
	if rigid == null or rigid.freeze:
		return false
	var incoming := Vector3(rigid.linear_velocity.x, 0, rigid.linear_velocity.z)
	if incoming.length() < 0.5:
		return false
	var direction := fixed_direction
	if direction == Vector3.ZERO:
		direction = Vector3(rigid.global_position.x - global_position.x, 0, rigid.global_position.z - global_position.z).normalized()
		if direction.length_squared() < 0.01:
			direction = -incoming.normalized()
	var speed := clampf(incoming.length() * horizontal_multiplier, 14.0, 76.0)
	rigid.linear_velocity = direction.normalized() * speed + Vector3.UP * rigid.linear_velocity.y
	rigid.sleeping = false
	_flash = 1.0
	return true


func _physics_process(delta: float) -> void:
	_flash = move_toward(_flash, 0.0, delta * 6.0)
	if _glow_visual != null:
		_glow_visual.scale = Vector3.ONE * (1.0 + _flash * 0.10)


func _build_model() -> void:
	var trigger := CollisionShape3D.new()
	var solid_collision := CollisionShape3D.new()
	if round_shape:
		var trigger_shape := CylinderShape3D.new()
		trigger_shape.radius = radius * 1.12
		trigger_shape.height = height
		trigger.shape = trigger_shape
		var solid_shape := CylinderShape3D.new()
		solid_shape.radius = radius
		solid_shape.height = height
		solid_collision.shape = solid_shape
	else:
		var trigger_box := BoxShape3D.new()
		trigger_box.size = box_size + Vector3(0.8, 0.5, 0.8)
		trigger.shape = trigger_box
		var solid_box := BoxShape3D.new()
		solid_box.size = box_size
		solid_collision.shape = solid_box
	trigger.position.y = height * 0.5 if round_shape else 0.0
	add_child(trigger)
	var solid := StaticBody3D.new()
	solid.name = "SolidReboundHousing"
	solid.collision_layer = 1
	solid.collision_mask = 2
	solid.physics_material_override = preload("res://assets/materials/physics/arena_bounce.tres")
	add_child(solid)
	solid_collision.position.y = height * 0.5 if round_shape else 0.0
	solid.add_child(solid_collision)
	_glow_visual = MeshInstance3D.new()
	_glow_visual.name = "CyanReboundCore"
	var mesh: PrimitiveMesh
	if round_shape:
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = radius * 0.68
		cylinder.bottom_radius = radius * 0.78
		cylinder.height = height * 0.72
		cylinder.radial_segments = 32
		mesh = cylinder
		_glow_visual.position.y = height * 0.57
	else:
		var box := BoxMesh.new()
		box.size = box_size * Vector3(1.22, 0.72, 0.72)
		mesh = box
	mesh.material = _material(Color("48CDE8"), 0.25, 1.35)
	_glow_visual.mesh = mesh
	add_child(_glow_visual)
	var casing := MeshInstance3D.new()
	casing.name = "IvoryGoldReboundCasing"
	var casing_mesh: PrimitiveMesh
	if round_shape:
		var casing_cylinder := CylinderMesh.new()
		casing_cylinder.top_radius = radius
		casing_cylinder.bottom_radius = radius * 1.08
		casing_cylinder.height = height * 0.24
		casing_cylinder.radial_segments = 32
		casing_mesh = casing_cylinder
		casing.position.y = height * 0.12
	else:
		var casing_box := BoxMesh.new()
		casing_box.size = box_size
		casing_mesh = casing_box
	casing_mesh.material = _material(Color("E8E0CF"), 0.7, 0.0)
	casing.mesh = casing_mesh
	add_child(casing)
	move_child(casing, _glow_visual.get_index())
	if round_shape:
		var ring := MeshInstance3D.new()
		ring.name = "GoldPylonCrownRing"
		var torus := TorusMesh.new()
		torus.inner_radius = radius * 0.70
		torus.outer_radius = radius * 0.93
		torus.rings = 20
		torus.ring_segments = 36
		torus.material = _material(Color("E6AF3A"), 0.26, 0.72)
		ring.mesh = torus
		ring.position.y = height * 0.94
		add_child(ring)


func _material(color: Color, roughness: float, emission: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	if emission > 0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission
	return material
