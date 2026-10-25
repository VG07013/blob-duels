class_name ToyboxBoostPad
extends Area3D

@export var pad_radius := 2.166
@export var pad_height := 0.4332
@export var local_direction := Vector3(0.5, 0.25, -1.0)
@export var impulse_strength := 46.0
@export var cooldown := 0.5

var _pulse := 0.0
var _visual_root: Node3D


func _ready() -> void:
	add_to_group("map_interactable")
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	body_entered.connect(_on_body_entered)
	_build_model()


func configure(direction: Vector3, strength: float) -> void:
	local_direction = direction.normalized() if direction.length_squared() > 0.001 else Vector3.UP
	impulse_strength = maxf(strength, 0.0)


func get_interaction_kind() -> StringName:
	return &"toybox_boost_pad"


func activate_body(body: Node3D) -> bool:
	var rigid := body as RigidBody3D
	if rigid == null or rigid.freeze:
		return false
	var key := "toybox_boost_%d" % get_instance_id()
	var now := Time.get_ticks_msec()
	if now < int(rigid.get_meta(key, 0)):
		return false
	rigid.set_meta(key, now + int(cooldown * 1000.0))
	var direction := (global_basis * local_direction).normalized()
	# Apply the same instantaneous momentum change deterministically so movement,
	# VFX, audio, and gameplay contracts all observe the launch on this frame.
	var effective_mass := maxf(rigid.mass, 0.001)
	rigid.linear_velocity += direction * (impulse_strength / effective_mass)
	rigid.sleeping = false
	_pulse = 1.0
	return true


func _physics_process(delta: float) -> void:
	_pulse = move_toward(_pulse, 0.0, delta * 5.0)
	if _visual_root != null:
		var scale_value := 1.0 + _pulse * 0.08
		_visual_root.scale = Vector3(scale_value, 1.0, scale_value)


func _on_body_entered(body: Node3D) -> void:
	activate_body(body)


func _build_model() -> void:
	var detection := CollisionShape3D.new()
	detection.name = "BoostTrigger"
	var detection_shape := CylinderShape3D.new()
	detection_shape.radius = pad_radius * 1.14
	detection_shape.height = 1.2
	detection.shape = detection_shape
	detection.position.y = 0.55
	add_child(detection)
	var solid := StaticBody3D.new()
	solid.name = "SolidPad"
	solid.collision_layer = 1
	solid.collision_mask = 2
	solid.physics_material_override = preload("res://assets/materials/physics/arena_ice.tres")
	add_child(solid)
	var collision := CollisionShape3D.new()
	collision.name = "PadCollision"
	var shape := CylinderShape3D.new()
	shape.radius = pad_radius
	shape.height = pad_height
	collision.shape = shape
	collision.position.y = pad_height * 0.5
	solid.add_child(collision)
	_visual_root = Node3D.new()
	_visual_root.name = "BoostVisual"
	add_child(_visual_root)
	_add_cylinder("DarkBase", pad_radius, pad_height, pad_height * 0.5, _material(Color("343942"), 0.74, 0.0))
	var ring := MeshInstance3D.new()
	ring.name = "YellowRing"
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = pad_radius * 0.58
	ring_mesh.outer_radius = pad_radius * 0.92
	ring_mesh.rings = 20
	ring_mesh.ring_segments = 36
	ring_mesh.material = _material(Color("F2BD27"), 0.58, 0.22)
	ring.mesh = ring_mesh
	ring.position.y = pad_height + 0.08
	_visual_root.add_child(ring)


func _add_cylinder(node_name: String, radius: float, height: float, y: float, material: Material) -> void:
	var visual := MeshInstance3D.new()
	visual.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 28
	mesh.material = material
	visual.mesh = mesh
	visual.position.y = y
	_visual_root.add_child(visual)


func _material(color: Color, roughness: float, emission: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	if emission > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission
	return material
