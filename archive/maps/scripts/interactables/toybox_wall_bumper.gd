class_name ToyboxWallBumper
extends Area3D

@export var panel_size := Vector3(0.722, 7.22, 11.552)
@export var inward := Vector3.RIGHT
@export var speed_multiplier := 1.10
@export var minimum_speed := 2.0

var _pulse := 0.0
var _arrow_root: Node3D


func _ready() -> void:
	add_to_group("map_interactable")
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	body_entered.connect(_on_body_entered)
	_build_model()


func configure(direction: Vector3) -> void:
	inward = direction.normalized() if direction.length_squared() > 0.001 else Vector3.RIGHT


func get_interaction_kind() -> StringName:
	return &"toybox_wall_bumper"


func activate_body(body: Node3D) -> bool:
	var rigid := body as RigidBody3D
	if rigid == null or rigid.freeze:
		return false
	var horizontal := Vector3(rigid.linear_velocity.x, 0.0, rigid.linear_velocity.z)
	if horizontal.length() < minimum_speed:
		return false
	var key := "toybox_wall_bumper_%d" % get_instance_id()
	var now := Time.get_ticks_msec()
	if now < int(rigid.get_meta(key, 0)):
		return false
	rigid.set_meta(key, now + 260)
	var normal := Vector3(inward.x, 0.0, inward.z).normalized()
	# Preserve tangential trick-movement while making the wall-normal component
	# unconditionally point back into the arena.
	var normal_speed := horizontal.dot(normal)
	var tangent := horizontal - normal * normal_speed
	var reflected := (tangent + normal * absf(normal_speed)) * speed_multiplier
	reflected = reflected.limit_length(138.0)
	rigid.linear_velocity = Vector3(reflected.x, rigid.linear_velocity.y, reflected.z)
	rigid.sleeping = false
	_pulse = 1.0
	return true


func _physics_process(delta: float) -> void:
	_pulse = move_toward(_pulse, 0.0, delta * 6.0)
	if _arrow_root != null:
		_arrow_root.scale = Vector3.ONE * (1.0 + _pulse * 0.08)


func _on_body_entered(body: Node3D) -> void:
	activate_body(body)


func _build_model() -> void:
	var solid := StaticBody3D.new()
	solid.name = "SolidPanel"
	solid.collision_layer = 1
	solid.collision_mask = 2
	solid.physics_material_override = preload("res://assets/materials/physics/arena_bounce.tres")
	add_child(solid)
	var collision := CollisionShape3D.new()
	collision.name = "PanelCollision"
	var shape := BoxShape3D.new()
	shape.size = panel_size
	collision.shape = shape
	solid.add_child(collision)
	var trigger := CollisionShape3D.new()
	trigger.name = "PanelTrigger"
	var trigger_shape := BoxShape3D.new()
	trigger_shape.size = panel_size * Vector3(1.35, 1.10, 1.08)
	trigger.shape = trigger_shape
	add_child(trigger)
	var panel := MeshInstance3D.new()
	panel.name = "BluePaddedHousing"
	var panel_mesh := BoxMesh.new()
	panel_mesh.size = panel_size
	panel_mesh.material = _material(Color("3F79C8"), 0.72)
	panel.mesh = panel_mesh
	add_child(panel)
	_arrow_root = Node3D.new()
	_arrow_root.name = "WhiteArrow"
	add_child(_arrow_root)
	var face_offset := Vector3(inward.x, 0.0, inward.z) * (panel_size.x * 0.56)
	for y_offset in [-0.18, 0.18]:
		for tilt in [-1.0, 1.0]:
			var bar := MeshInstance3D.new()
			bar.name = "ArrowChevron"
			var bar_mesh := BoxMesh.new()
			bar_mesh.size = Vector3(0.12, panel_size.y * 0.16, panel_size.z * 0.36)
			bar_mesh.material = _material(Color("F5F7F8"), 0.68)
			bar.mesh = bar_mesh
			bar.position = face_offset + Vector3.UP * y_offset * panel_size.y
			bar.rotation.x = tilt * 0.62
			_arrow_root.add_child(bar)


func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material
