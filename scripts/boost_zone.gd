class_name BoostZone
extends Area3D

var boost_impulse := Vector3.ZERO
var zone_size := Vector3(12, 1, 8)
var zone_color := Color(0.2, 0.9, 0.7)


func configure(size: Vector3, impulse: Vector3, color: Color) -> void:
	zone_size = size
	boost_impulse = impulse
	zone_color = color
	_build_visual()


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body is RigidBody3D:
		var rigid_body := body as RigidBody3D
		rigid_body.apply_central_impulse(boost_impulse)
		rigid_body.sleeping = false


func _build_visual() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = zone_color.darkened(0.18)
	material.roughness = 0.48
	material.emission_enabled = true
	material.emission = zone_color
	material.emission_energy_multiplier = 0.75
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = zone_size
	mesh.material = material
	mesh_instance.mesh = mesh
	add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(zone_size.x, maxf(zone_size.y, 1.2), zone_size.z)
	collision.shape = shape
	add_child(collision)
