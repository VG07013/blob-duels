class_name ToyboxBreakableBox
extends Area3D

@export var box_size := Vector3(5.776, 5.776, 5.776)
@export var break_speed := 15.0
@export var piece_lifetime := 2.0
@export var respawn_delay := 10.0

var _intact_root: Node3D
var _solid_collision: CollisionShape3D
var _broken := false


func _ready() -> void:
	add_to_group("map_interactable")
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	body_entered.connect(_on_body_entered)
	_build_model()


func get_interaction_kind() -> StringName:
	return &"toybox_breakable_box"


func strike_body(body: Node3D) -> bool:
	var rigid := body as RigidBody3D
	if rigid == null or rigid.freeze or _broken or rigid.linear_velocity.length() < break_speed:
		return false
	_break_box(rigid.linear_velocity)
	return true


func _on_body_entered(body: Node3D) -> void:
	strike_body(body)


func _build_model() -> void:
	var trigger := CollisionShape3D.new()
	trigger.name = "BreakTrigger"
	var trigger_shape := BoxShape3D.new()
	trigger_shape.size = box_size * 1.12
	trigger.shape = trigger_shape
	trigger.position.y = box_size.y * 0.5
	add_child(trigger)
	var solid := StaticBody3D.new()
	solid.name = "SolidBox"
	solid.collision_layer = 1
	solid.collision_mask = 2
	solid.physics_material_override = preload("res://assets/materials/physics/arena_normal.tres")
	add_child(solid)
	_solid_collision = CollisionShape3D.new()
	_solid_collision.name = "BoxCollision"
	var shape := BoxShape3D.new()
	shape.size = box_size
	_solid_collision.shape = shape
	_solid_collision.position.y = box_size.y * 0.5
	solid.add_child(_solid_collision)
	_intact_root = Node3D.new()
	_intact_root.name = "IntactToyBox"
	add_child(_intact_root)
	var body := MeshInstance3D.new()
	body.name = "PaintedWoodCube"
	var body_mesh := BoxMesh.new()
	body_mesh.size = box_size
	body_mesh.material = _material(Color("A87342"), 0.82)
	body.mesh = body_mesh
	body.position.y = box_size.y * 0.5
	_intact_root.add_child(body)
	for axis in range(2):
		for side in [-1.0, 1.0]:
			var batten := MeshInstance3D.new()
			batten.name = "WoodBatten"
			var batten_mesh := BoxMesh.new()
			batten_mesh.size = Vector3(box_size.x * (0.12 if axis == 0 else 0.82), box_size.y * 0.12, box_size.z * (0.82 if axis == 0 else 0.12))
			batten_mesh.material = _material(Color("C69A65"), 0.78)
			batten.mesh = batten_mesh
			batten.position = Vector3(0, box_size.y * (0.28 if side < 0.0 else 0.72), 0)
			_intact_root.add_child(batten)
	var badge := MeshInstance3D.new()
	badge.name = "PrintedCircle"
	var badge_mesh := CylinderMesh.new()
	badge_mesh.top_radius = box_size.x * 0.18
	badge_mesh.bottom_radius = box_size.x * 0.18
	badge_mesh.height = 0.08
	badge_mesh.radial_segments = 20
	badge_mesh.material = _material(Color("F2BD27"), 0.68)
	badge.mesh = badge_mesh
	badge.position = Vector3(0, box_size.y * 0.55, -box_size.z * 0.51)
	badge.rotation.x = PI * 0.5
	_intact_root.add_child(badge)


func _break_box(impact_velocity: Vector3) -> void:
	_broken = true
	_intact_root.visible = false
	_solid_collision.set_deferred("disabled", true)
	monitoring = false
	for index in range(4):
		var piece := RigidBody3D.new()
		piece.name = "ToyBoxPiece"
		piece.mass = 0.35
		piece.collision_layer = 1
		piece.collision_mask = 1 | 2
		piece.position = Vector3((index % 2 - 0.5) * box_size.x * 0.42, box_size.y * (0.3 + float(index / 2) * 0.42), (index / 2 - 0.5) * box_size.z * 0.42)
		var visual := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = box_size * Vector3(0.46, 0.44, 0.46)
		mesh.material = _material(Color("A87342"), 0.84)
		visual.mesh = mesh
		piece.add_child(visual)
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = mesh.size
		collision.shape = shape
		piece.add_child(collision)
		add_child(piece)
		piece.apply_central_impulse(impact_velocity.normalized() * 4.0 + Vector3((index % 2 - 0.5) * 4.0, 5.0 + index, (index / 2 - 0.5) * 4.0))
		var piece_timer := get_tree().create_timer(piece_lifetime)
		piece_timer.timeout.connect(piece.queue_free)
	var respawn_timer := get_tree().create_timer(respawn_delay)
	respawn_timer.timeout.connect(_respawn)


func _respawn() -> void:
	if not is_inside_tree():
		return
	_broken = false
	_intact_root.visible = true
	_solid_collision.set_deferred("disabled", false)
	monitoring = true


func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material
