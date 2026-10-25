class_name BackyardSprinklerPad
extends Area3D

@export var pad_radius := 3.609375
@export var influence_radius := 11.55
@export var upward_force := 96.0
@export var outward_force := 44.0
@export var water_color := Color("43B7E8")

var _bodies: Array[RigidBody3D] = []
var _spray_root: Node3D
var _pulse := 0.0


func _ready() -> void:
	add_to_group("map_interactable")
	add_to_group("backyard_sprinkler")
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_build_model()


func configure(radius_value: float, influence_value: float, up_force: float, radial_force: float, color: Color) -> void:
	pad_radius = maxf(radius_value, 0.5)
	influence_radius = maxf(influence_value, pad_radius)
	upward_force = maxf(up_force, 0.0)
	outward_force = maxf(radial_force, 0.0)
	water_color = color
	if is_node_ready():
		_rebuild()


func get_interaction_kind() -> StringName:
	return &"sprinkler_pad"


func affect_body(body: Node3D) -> bool:
	var rigid := body as RigidBody3D
	if rigid == null or rigid.freeze:
		return false
	var offset := rigid.global_position - global_position
	var horizontal := Vector3(offset.x, 0.0, offset.z)
	var radial := horizontal.normalized() if horizontal.length_squared() > 0.01 else Vector3.FORWARD
	var falloff := clampf(1.0 - horizontal.length() / influence_radius, 0.28, 1.0)
	var force := Vector3.UP * upward_force + radial * outward_force
	rigid.apply_central_force(force * rigid.mass * falloff)
	rigid.sleeping = false
	return true


func _physics_process(delta: float) -> void:
	_pulse += delta
	for body in _bodies.duplicate():
		if not is_instance_valid(body):
			_bodies.erase(body)
			continue
		affect_body(body)
	if _spray_root != null:
		_spray_root.rotation.y = _pulse * 0.42
		var breathe := 1.0 + sin(_pulse * 4.0) * 0.025
		_spray_root.scale = Vector3(breathe, 1.0, breathe)


func _on_body_entered(body: Node3D) -> void:
	var rigid := body as RigidBody3D
	if rigid != null and not _bodies.has(rigid):
		_bodies.append(rigid)


func _on_body_exited(body: Node3D) -> void:
	var rigid := body as RigidBody3D
	if rigid != null:
		_bodies.erase(rigid)


func _build_model() -> void:
	_spray_root = Node3D.new()
	_spray_root.name = "WaterSpray"
	add_child(_spray_root)
	_rebuild()


func _rebuild() -> void:
	for child in get_children():
		if child != _spray_root:
			child.queue_free()
	if _spray_root != null:
		for child in _spray_root.get_children():
			child.queue_free()
	var detection := CollisionShape3D.new()
	detection.name = "InfluenceCollision"
	var detection_shape := CylinderShape3D.new()
	detection_shape.radius = influence_radius
	detection_shape.height = 3.6
	detection.shape = detection_shape
	detection.position.y = 1.65
	add_child(detection)
	var base := StaticBody3D.new()
	base.name = "SolidBase"
	base.collision_layer = 1
	base.collision_mask = 2
	base.physics_material_override = preload("res://assets/materials/physics/arena_bounce.tres")
	add_child(base)
	var base_collision := CollisionShape3D.new()
	base_collision.name = "CollisionShape3D"
	var base_shape := CylinderShape3D.new()
	base_shape.radius = pad_radius
	base_shape.height = 0.72
	base_collision.shape = base_shape
	base_collision.position.y = 0.36
	base.add_child(base_collision)
	_add_cylinder("BlueSteelBase", pad_radius, 0.72, 0.36, _material(Color("286B85"), 0.35, 0.38, 0.0), self)
	_add_cylinder("WaterBasin", pad_radius * 0.72, 0.22, 0.80, _material(water_color, 0.18, 0.15, 1.3), self)
	_add_torus("WaterRing", pad_radius * 0.72, pad_radius * 0.90, 0.94, _material(water_color.lightened(0.28), 0.15, 0.08, 1.7), self)
	_add_cylinder("Nozzle", pad_radius * 0.13, 1.25, 1.42, _material(Color("B6DCE7"), 0.3, 0.62, 0.0), self)
	for index in range(8):
		var angle := TAU * float(index) / 8.0
		var root := Vector3(cos(angle), 0.0, sin(angle))
		_add_water_segment(root * pad_radius * 0.18 + Vector3.UP * 1.75, root * pad_radius * 0.92 + Vector3.UP * 3.7, 0.095)
		_add_water_segment(root * pad_radius * 0.92 + Vector3.UP * 3.7, root * influence_radius * 0.72 + Vector3.UP * 0.95, 0.075)
	var light := OmniLight3D.new()
	light.name = "WaterSparkle"
	light.position.y = 1.4
	light.light_color = water_color
	light.light_energy = 0.42
	light.omni_range = pad_radius * 3.2
	light.shadow_enabled = false
	add_child(light)


func _add_water_segment(start: Vector3, finish: Vector3, radius: float) -> void:
	var delta := finish - start
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "WaterArc"
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius * 1.25
	mesh.height = delta.length()
	mesh.radial_segments = 8
	mesh.material = _material(Color(water_color, 0.55), 0.08, 0.0, 1.5)
	mesh_instance.mesh = mesh
	mesh_instance.position = (start + finish) * 0.5
	mesh_instance.quaternion = Quaternion(Vector3.UP, delta.normalized())
	_spray_root.add_child(mesh_instance)


func _add_cylinder(node_name: String, radius: float, height: float, y: float, material: Material, parent: Node) -> void:
	var visual := MeshInstance3D.new()
	visual.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 32
	mesh.material = material
	visual.mesh = mesh
	visual.position.y = y
	parent.add_child(visual)


func _add_torus(node_name: String, inner_radius: float, outer_radius: float, y: float, material: Material, parent: Node) -> void:
	var visual := MeshInstance3D.new()
	visual.name = node_name
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = outer_radius
	mesh.rings = 24
	mesh.ring_segments = 40
	mesh.material = material
	visual.mesh = mesh
	visual.position.y = y
	parent.add_child(visual)


func _material(color: Color, roughness: float, metallic: float, emission: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emission > 0.0:
		material.emission_enabled = true
		material.emission = Color(color.r, color.g, color.b)
		material.emission_energy_multiplier = emission
	return material
