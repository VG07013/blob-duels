class_name AetherVortex
extends Area3D

@export var vertical_speed := 42.0
@export var horizontal_multiplier := 1.08
@export var radial_speed := 9.0

var _pulse := 0.0
var _rings: Node3D


func _ready() -> void:
	add_to_group("map_interactable")
	add_to_group("map_landmark")
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(activate_body)
	_build_model()


func get_interaction_kind() -> StringName:
	return &"aether_vortex"


func activate_body(body: Node3D) -> bool:
	var rigid := body as RigidBody3D
	if rigid == null or rigid.freeze:
		return false
	var horizontal := Vector3(rigid.linear_velocity.x, 0, rigid.linear_velocity.z) * horizontal_multiplier
	var radial := Vector3(rigid.global_position.x - global_position.x, 0, rigid.global_position.z - global_position.z)
	if radial.length_squared() < 0.01:
		radial = horizontal.normalized() if horizontal.length_squared() > 0.01 else Vector3.FORWARD
	horizontal += radial.normalized() * radial_speed
	if horizontal.length() > 72.0:
		horizontal = horizontal.normalized() * 72.0
	rigid.linear_velocity = horizontal + Vector3.UP * vertical_speed
	rigid.sleeping = false
	_pulse = 1.0
	return true


func _physics_process(delta: float) -> void:
	_pulse = move_toward(_pulse, 0.0, delta * 3.6)
	if _rings != null:
		_rings.rotation.y += delta * (0.55 + _pulse * 1.4)
		_rings.scale = Vector3.ONE * (1.0 + _pulse * 0.06)


func _build_model() -> void:
	var trigger := CollisionShape3D.new()
	var trigger_shape := CylinderShape3D.new()
	trigger_shape.radius = 17.328
	trigger_shape.height = 4.4
	trigger.shape = trigger_shape
	# Begin at the crown surface and extend through a standing blob's center so the
	# gameplay trigger cannot be hidden inside the solid visual housing.
	trigger.position.y = 6.45
	add_child(trigger)
	var solid := StaticBody3D.new()
	solid.name = "SolidAetherCrown"
	solid.collision_layer = 1
	solid.collision_mask = 2
	solid.physics_material_override = preload("res://assets/materials/physics/arena_bounce.tres")
	add_child(solid)
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 17.328
	shape.height = 4.332
	collision.shape = shape
	collision.position.y = 2.166
	solid.add_child(collision)
	_add_cylinder("NavyCrownBase", 17.328, 3.1, 1.55, _material(Color("0B1730"), 0.72, 0.0))
	_add_cylinder("IvoryCrownFace", 15.6, 1.3, 3.75, _material(Color("E8E0CF"), 0.66, 0.0))
	_rings = Node3D.new()
	_rings.name = "ConcentricAetherRings"
	add_child(_rings)
	for spec in [[5.2, 7.1, "48CDE8"], [8.4, 10.4, "E6AF3A"], [12.0, 14.7, "7657B5"]]:
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = float(spec[0])
		torus.outer_radius = float(spec[1])
		torus.rings = 30
		torus.ring_segments = 56
		torus.material = _material(Color(String(spec[2])), 0.24, 1.2)
		ring.mesh = torus
		ring.position.y = 4.62
		_rings.add_child(ring)
	var core := MeshInstance3D.new()
	core.name = "WhiteVortexCore"
	var core_mesh := CylinderMesh.new()
	core_mesh.top_radius = 4.2
	core_mesh.bottom_radius = 5.1
	core_mesh.height = 1.0
	core_mesh.radial_segments = 40
	core_mesh.material = _material(Color("F4F8FA"), 0.18, 2.2)
	core.mesh = core_mesh
	core.position.y = 4.52
	add_child(core)


func _add_cylinder(node_name: String, radius: float, height: float, y: float, material: Material) -> void:
	var visual := MeshInstance3D.new()
	visual.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 56
	mesh.material = material
	visual.mesh = mesh
	visual.position.y = y
	add_child(visual)


func _material(color: Color, roughness: float, emission: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	if emission > 0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission
	return material
