class_name BackyardMushroomPad
extends Area3D

@export var cap_radius := 3.609375
@export var total_height := 5.1975
@export var impulse_strength := 42.0
@export var cap_color := Color("D95243")

var _visual_root: Node3D
var _compression := 0.0


func _ready() -> void:
	add_to_group("map_interactable")
	add_to_group("backyard_mushroom")
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	body_entered.connect(_on_body_entered)
	_build_model()


func configure(radius_value: float, height_value: float, strength: float, color: Color) -> void:
	cap_radius = maxf(radius_value, 0.5)
	total_height = maxf(height_value, 1.0)
	impulse_strength = maxf(strength, 0.0)
	cap_color = color
	if is_node_ready():
		_rebuild()


func get_interaction_kind() -> StringName:
	return &"mushroom_pad"


func activate_body(body: Node3D) -> bool:
	var rigid := body as RigidBody3D
	if rigid == null or rigid.freeze:
		return false
	var cooldown_key := "backyard_mushroom_%d" % get_instance_id()
	var now := Time.get_ticks_msec()
	if now < int(rigid.get_meta(cooldown_key, 0)):
		return false
	rigid.set_meta(cooldown_key, now + 260)
	var incoming := rigid.linear_velocity
	var horizontal := Vector3(incoming.x, 0.0, incoming.z)
	var outward := rigid.global_position - global_position
	outward.y = 0.0
	if horizontal.length_squared() < 0.01:
		horizontal = outward
	if horizontal.length_squared() < 0.01:
		horizontal = Vector3.FORWARD
	# Preserve the approach vector while the convex cap contributes a strong upward normal.
	var direction := (horizontal.normalized() * 0.62 + Vector3.UP * 0.78).normalized()
	rigid.apply_central_impulse(direction * impulse_strength)
	rigid.sleeping = false
	_compression = 1.0
	return true


func _physics_process(delta: float) -> void:
	_compression = move_toward(_compression, 0.0, delta * 5.5)
	if _visual_root != null:
		var squash := 1.0 - _compression * 0.16
		_visual_root.scale = Vector3(1.0 + _compression * 0.07, squash, 1.0 + _compression * 0.07)


func _on_body_entered(body: Node3D) -> void:
	activate_body(body)


func _build_model() -> void:
	_visual_root = Node3D.new()
	_visual_root.name = "MushroomVisual"
	add_child(_visual_root)
	_rebuild()


func _rebuild() -> void:
	for child in get_children():
		if child != _visual_root:
			child.queue_free()
	for child in _visual_root.get_children():
		child.queue_free()
	var stem_height := total_height * 0.62
	var stem_radius := total_height * 0.39
	var cap_height := total_height * 0.45
	var stem := MeshInstance3D.new()
	stem.name = "CreamStem"
	var stem_mesh := CylinderMesh.new()
	stem_mesh.top_radius = stem_radius * 0.72
	stem_mesh.bottom_radius = stem_radius
	stem_mesh.height = stem_height
	stem_mesh.radial_segments = 24
	stem_mesh.material = _material(Color("E8D9B5"), 0.82)
	stem.mesh = stem_mesh
	stem.position.y = stem_height * 0.5
	_visual_root.add_child(stem)
	var cap := MeshInstance3D.new()
	cap.name = "ConvexRedCap"
	var cap_mesh := SphereMesh.new()
	cap_mesh.radius = cap_radius
	cap_mesh.height = cap_height
	cap_mesh.radial_segments = 32
	cap_mesh.rings = 12
	cap_mesh.material = _material(cap_color, 0.62)
	cap.mesh = cap_mesh
	cap.position.y = stem_height + cap_height * 0.18
	_visual_root.add_child(cap)
	for offset in [Vector3(-0.42, 0.5, -0.15), Vector3(0.35, 0.54, -0.28), Vector3(0.05, 0.58, 0.42), Vector3(-0.58, 0.42, 0.38), Vector3(0.62, 0.38, 0.18)]:
		var spot := MeshInstance3D.new()
		spot.name = "WhiteCapSpot"
		var spot_mesh := SphereMesh.new()
		spot_mesh.radius = cap_radius * 0.13
		spot_mesh.height = cap_radius * 0.10
		spot_mesh.radial_segments = 12
		spot_mesh.rings = 6
		spot_mesh.material = _material(Color("FFF4D9"), 0.76)
		spot.mesh = spot_mesh
		spot.position = Vector3(offset.x * cap_radius, stem_height + offset.y * cap_height, offset.z * cap_radius)
		_visual_root.add_child(spot)
	var solid := StaticBody3D.new()
	solid.name = "SolidMushroom"
	solid.collision_layer = 1
	solid.collision_mask = 2
	solid.physics_material_override = preload("res://assets/materials/physics/arena_bounce.tres")
	add_child(solid)
	var stem_collision := CollisionShape3D.new()
	stem_collision.name = "StemCollision"
	var stem_shape := CylinderShape3D.new()
	stem_shape.radius = stem_radius
	stem_shape.height = stem_height
	stem_collision.shape = stem_shape
	stem_collision.position.y = stem_height * 0.5
	solid.add_child(stem_collision)
	var cap_collision := CollisionShape3D.new()
	cap_collision.name = "CapCollision"
	var cap_shape := ConvexPolygonShape3D.new()
	var points := PackedVector3Array()
	for ring in range(3):
		var ring_radius: float = cap_radius * float([0.62, 1.0, 0.76][ring])
		var ring_y: float = stem_height + float([0.0, cap_height * 0.18, cap_height * 0.52][ring])
		for index in range(16):
			var angle := TAU * float(index) / 16.0
			points.append(Vector3(cos(angle) * ring_radius, ring_y, sin(angle) * ring_radius))
	points.append(Vector3(0, stem_height + cap_height * 0.64, 0))
	cap_shape.points = points
	cap_collision.shape = cap_shape
	solid.add_child(cap_collision)
	var detection := CollisionShape3D.new()
	detection.name = "BounceDetection"
	var detection_shape := CylinderShape3D.new()
	detection_shape.radius = cap_radius * 1.08
	detection_shape.height = total_height * 0.72
	detection.shape = detection_shape
	detection.position.y = total_height * 0.62
	add_child(detection)


func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material
