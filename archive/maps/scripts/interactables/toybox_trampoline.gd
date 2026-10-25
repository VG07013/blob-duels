class_name ToyboxTrampoline
extends Area3D

@export var outer_radius := 8.664
@export var bounce_radius := 6.498
@export var surface_height := 2.888
@export var launch_speed := 44.0
@export var horizontal_multiplier := 1.08
@export var safe_speed := 138.0

var _visual_root: Node3D
var _compression := 0.0


func _ready() -> void:
	add_to_group("map_interactable")
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	body_entered.connect(_on_body_entered)
	_build_model()


func get_interaction_kind() -> StringName:
	return &"toybox_trampoline"


func activate_body(body: Node3D) -> bool:
	var rigid := body as RigidBody3D
	if rigid == null or rigid.freeze:
		return false
	var cooldown_key := "toybox_trampoline_%d" % get_instance_id()
	var now := Time.get_ticks_msec()
	if now < int(rigid.get_meta(cooldown_key, 0)):
		return false
	rigid.set_meta(cooldown_key, now + 220)
	var horizontal := Vector3(rigid.linear_velocity.x, 0.0, rigid.linear_velocity.z) * horizontal_multiplier
	horizontal = horizontal.limit_length(safe_speed * 0.84)
	rigid.linear_velocity = Vector3(horizontal.x, maxf(rigid.linear_velocity.y, launch_speed), horizontal.z).limit_length(safe_speed)
	rigid.sleeping = false
	_compression = 1.0
	return true


func _physics_process(delta: float) -> void:
	_compression = move_toward(_compression, 0.0, delta / 0.2)
	if _visual_root != null:
		_visual_root.position.y = -_compression * 0.722
		_visual_root.scale = Vector3(1.0 + _compression * 0.025, 1.0 - _compression * 0.08, 1.0 + _compression * 0.025)


func _on_body_entered(body: Node3D) -> void:
	activate_body(body)


func _build_model() -> void:
	var trigger := CollisionShape3D.new()
	trigger.name = "BounceTrigger"
	var trigger_shape := CylinderShape3D.new()
	trigger_shape.radius = bounce_radius * 1.12
	trigger_shape.height = 2.2
	trigger.shape = trigger_shape
	trigger.position.y = surface_height + 0.75
	add_child(trigger)
	var solid := StaticBody3D.new()
	solid.name = "SolidTrampoline"
	solid.collision_layer = 1
	solid.collision_mask = 2
	solid.physics_material_override = preload("res://assets/materials/physics/arena_bounce.tres")
	add_child(solid)
	var surface_collision := CollisionShape3D.new()
	surface_collision.name = "BounceSurfaceCollision"
	var surface_shape := CylinderShape3D.new()
	surface_shape.radius = outer_radius
	surface_shape.height = 0.72
	surface_collision.shape = surface_shape
	surface_collision.position.y = surface_height - 0.36
	solid.add_child(surface_collision)
	_visual_root = Node3D.new()
	_visual_root.name = "TrampolineVisual"
	add_child(_visual_root)
	_add_cylinder("OrangeFrameBase", outer_radius, 0.72, surface_height - 0.36, _material(Color("C65F13"), 0.78, 0.0), _visual_root)
	_add_cylinder("DarkBounceSurface", bounce_radius, 0.36, surface_height + 0.03, _material(Color("30343A"), 0.72, 0.0), _visual_root)
	_add_torus("OrangePaddedRim", bounce_radius, outer_radius, surface_height + 0.28, _material(Color("ED842C"), 0.68, 0.08), _visual_root)
	for index in range(16):
		var angle := TAU * float(index) / 16.0
		var bolt := MeshInstance3D.new()
		bolt.name = "ToyBolt"
		var bolt_mesh := SphereMesh.new()
		bolt_mesh.radius = 0.14
		bolt_mesh.height = 0.28
		bolt_mesh.radial_segments = 10
		bolt_mesh.rings = 6
		bolt_mesh.material = _material(Color("F7C566"), 0.55, 0.0)
		bolt.mesh = bolt_mesh
		bolt.position = Vector3(cos(angle) * outer_radius * 0.88, surface_height + 0.48, sin(angle) * outer_radius * 0.88)
		_visual_root.add_child(bolt)


func _add_cylinder(node_name: String, radius: float, height: float, y: float, material: Material, parent: Node) -> void:
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
	parent.add_child(visual)


func _add_torus(node_name: String, inner_radius: float, outer_radius_value: float, y: float, material: Material, parent: Node) -> void:
	var visual := MeshInstance3D.new()
	visual.name = node_name
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = outer_radius_value
	mesh.rings = 28
	mesh.ring_segments = 48
	mesh.material = material
	visual.mesh = mesh
	visual.position.y = y
	parent.add_child(visual)


func _material(color: Color, roughness: float, emission: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	if emission > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission
	return material
