class_name AetherBoostPad
extends Area3D

@export var launch_direction := Vector3(0, 0.34, -1)
@export var launch_speed := 30.0

var _pulse := 0.0
var _visual_root: Node3D


func configure(direction: Vector3, speed: float) -> void:
	launch_direction = direction.normalized()
	launch_speed = speed


func _ready() -> void:
	add_to_group("map_interactable")
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(activate_body)
	_build_model()


func get_interaction_kind() -> StringName:
	return &"aether_boost_pad"


func activate_body(body: Node3D) -> bool:
	var rigid := body as RigidBody3D
	if rigid == null or rigid.freeze:
		return false
	var direction := (global_basis * launch_direction).normalized()
	var horizontal := Vector3(direction.x, 0, direction.z).normalized()
	rigid.linear_velocity = horizontal * launch_speed + Vector3.UP * maxf(7.5, launch_speed * 0.28)
	rigid.sleeping = false
	_pulse = 1.0
	return true


func _physics_process(delta: float) -> void:
	_pulse = move_toward(_pulse, 0.0, delta * 5.0)
	if _visual_root != null:
		_visual_root.scale = Vector3.ONE * (1.0 + _pulse * 0.08)


func _build_model() -> void:
	var trigger := CollisionShape3D.new()
	var trigger_shape := CylinderShape3D.new()
	trigger_shape.radius = 4.9
	trigger_shape.height = 2.2
	trigger.shape = trigger_shape
	trigger.position.y = 1.0
	add_child(trigger)
	var solid := StaticBody3D.new()
	solid.name = "SolidSunSealHousing"
	solid.collision_layer = 1
	solid.collision_mask = 2
	solid.physics_material_override = preload("res://assets/materials/physics/arena_ice.tres")
	add_child(solid)
	var solid_collision := CollisionShape3D.new()
	var solid_shape := CylinderShape3D.new()
	solid_shape.radius = 4.332
	solid_shape.height = 0.8664
	solid_collision.shape = solid_shape
	solid_collision.position.y = 0.4332
	solid.add_child(solid_collision)
	_visual_root = Node3D.new()
	_visual_root.name = "LayeredSunSealModel"
	add_child(_visual_root)
	_add_cylinder("NavyPlinth", 4.45, 0.72, 0.36, _material(Color("0B1730"), 0.72, 0.0))
	_add_cylinder("IvoryInset", 3.7, 0.84, 0.78, _material(Color("E8E0CF"), 0.68, 0.0))
	var ring := MeshInstance3D.new()
	ring.name = "RadiantGoldRing"
	var torus := TorusMesh.new()
	torus.inner_radius = 2.55
	torus.outer_radius = 3.55
	torus.rings = 24
	torus.ring_segments = 40
	torus.material = _material(Color("E6AF3A"), 0.28, 1.25)
	ring.mesh = torus
	ring.position.y = 1.24
	_visual_root.add_child(ring)
	for index in range(3):
		var arrow := MeshInstance3D.new()
		arrow.name = "CyanLaunchChevron"
		var arrow_mesh := PrismMesh.new()
		arrow_mesh.size = Vector3(1.1, 0.18, 1.9)
		arrow_mesh.material = _material(Color("48CDE8"), 0.24, 1.55)
		arrow.mesh = arrow_mesh
		arrow.position = Vector3(0, 1.28, -1.4 + index * 1.35)
		arrow.rotation.x = PI * 0.5
		_visual_root.add_child(arrow)


func _add_cylinder(node_name: String, radius: float, height: float, y: float, material: Material) -> void:
	var visual := MeshInstance3D.new()
	visual.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 40
	mesh.material = material
	visual.mesh = mesh
	visual.position.y = y
	_visual_root.add_child(visual)


func _material(color: Color, roughness: float, emission: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	if emission > 0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission
	return material
