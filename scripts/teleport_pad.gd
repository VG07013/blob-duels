class_name TeleportPad
extends Area3D

var destination := Vector3.ZERO
var exit_direction := Vector3.FORWARD
var pad_color := Color(0.2, 0.85, 1.0)


func configure(target_position: Vector3, target_direction: Vector3, color: Color) -> void:
	destination = target_position
	exit_direction = target_direction.normalized()
	pad_color = color
	_build_visual()


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	var now := Time.get_ticks_msec()
	if now < int(body.get_meta("teleport_ready_at", 0)):
		return
	body.set_meta("teleport_ready_at", now + 650)
	body.global_position = destination
	if body is RigidBody3D:
		var rigid_body := body as RigidBody3D
		var speed := maxf(rigid_body.linear_velocity.length(), 16.0)
		rigid_body.linear_velocity = exit_direction * speed + Vector3.UP * 4.0
		rigid_body.sleeping = false
	body.reset_physics_interpolation()
	var audio_manager := get_node_or_null("/root/AudioManager")
	if audio_manager != null:
		audio_manager.call("play_sfx_limited", &"portal_teleport", 0.12, -2.0, randf_range(0.94, 1.08), &"map_teleport")


func _build_visual() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = pad_color.darkened(0.32)
	material.metallic = 0.28
	material.roughness = 0.3
	material.emission_enabled = true
	material.emission = pad_color
	material.emission_energy_multiplier = 1.25
	var mesh_instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 5.2
	mesh.bottom_radius = 5.2
	mesh.height = 0.45
	mesh.radial_segments = 32
	mesh.material = material
	mesh_instance.mesh = mesh
	add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 5.2
	shape.height = 1.1
	collision.shape = shape
	collision.position.y = 0.35
	add_child(collision)
