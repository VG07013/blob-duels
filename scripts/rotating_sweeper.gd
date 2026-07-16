class_name RotatingSweeper
extends AnimatableBody3D

var arm_length := 30.0
var rotation_speed := 0.9
var arm_color := Color(0.9, 0.2, 0.2)


func configure(length: float, speed: float, color: Color) -> void:
	arm_length = length
	rotation_speed = speed
	arm_color = color
	_build_body()


func _ready() -> void:
	collision_layer = 1
	collision_mask = 2
	sync_to_physics = true


func _physics_process(delta: float) -> void:
	rotate_y(rotation_speed * delta)


func _build_body() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = arm_color
	material.roughness = 0.52
	material.metallic = 0.18
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(arm_length, 1.4, 2.2)
	mesh.material = material
	mesh_instance.mesh = mesh
	add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(arm_length, 1.4, 2.2)
	collision.shape = shape
	add_child(collision)
