class_name PracticeReboundPanel
extends Area3D

## Wall bounce panel for the practice training grounds. Reflects a fast blob
## back into the arena: the wall-normal velocity component flips inward, the
## tangential component and all vertical momentum are preserved, and the
## horizontal speed gains 10 percent. Slow touches do nothing, and the panel
## never deals damage.
##
## Local axes: thickness along +X (the inward face), width along Z, height
## along Y. The builder yaws the node so local +X matches `inward`.

@export var panel_width := 14.44
@export var panel_height := 5.776
@export var panel_thickness := 0.4332
@export var inward := Vector3.RIGHT
@export var speed_multiplier := 1.10
@export var minimum_speed := 6.0

const FRAME_COLOR := Color("F17C24")
const CORE_COLOR := Color("8B9095")
const CHEVRON_COLOR := Color("C9CDD0")

var _pulse := 0.0
var _face_root: Node3D


func _ready() -> void:
	add_to_group("map_interactable")
	add_to_group("practice_rebound_panel")
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	body_entered.connect(_on_body_entered)
	_build_model()


func configure(direction: Vector3) -> void:
	inward = direction.normalized() if direction.length_squared() > 0.001 else Vector3.RIGHT


func get_interaction_kind() -> StringName:
	return &"practice_rebound_panel"


func activate_body(body: Node3D) -> bool:
	var rigid := body as RigidBody3D
	if rigid == null or rigid.freeze:
		return false
	var horizontal := Vector3(rigid.linear_velocity.x, 0.0, rigid.linear_velocity.z)
	if horizontal.length() < minimum_speed:
		return false
	var key := "practice_rebound_panel_%d" % get_instance_id()
	var now := Time.get_ticks_msec()
	if now < int(rigid.get_meta(key, 0)):
		return false
	rigid.set_meta(key, now + 260)
	var normal := Vector3(inward.x, 0.0, inward.z).normalized()
	# The wall-normal component always ends up pointing back into the arena;
	# tangential trick movement and vertical momentum survive untouched.
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
	if _face_root != null:
		_face_root.scale = Vector3.ONE * (1.0 + _pulse * 0.06)


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
	shape.size = Vector3(panel_thickness, panel_height, panel_width)
	collision.shape = shape
	solid.add_child(collision)
	# Trigger shell wraps the solid so the reflect fires before hard contact.
	var trigger := CollisionShape3D.new()
	trigger.name = "PanelTrigger"
	var trigger_shape := BoxShape3D.new()
	trigger_shape.size = Vector3(panel_thickness * 2.4, panel_height * 1.08, panel_width * 1.04)
	trigger.shape = trigger_shape
	trigger.position = Vector3(panel_thickness * 0.5, 0.0, 0.0)
	add_child(trigger)

	_face_root = Node3D.new()
	_face_root.name = "PanelFace"
	add_child(_face_root)
	var core := MeshInstance3D.new()
	core.name = "GrayCore"
	var core_mesh := BoxMesh.new()
	core_mesh.size = Vector3(panel_thickness, panel_height - 0.9, panel_width - 0.9)
	core_mesh.material = _material(CORE_COLOR, 0.62)
	core.mesh = core_mesh
	core.position = Vector3(0.06, 0.0, 0.0)
	_face_root.add_child(core)
	for vertical_sign in [-1.0, 1.0]:
		var rail := MeshInstance3D.new()
		rail.name = "FrameRail"
		var rail_mesh := BoxMesh.new()
		rail_mesh.size = Vector3(panel_thickness + 0.14, 0.45, panel_width)
		rail_mesh.material = _material(FRAME_COLOR, 0.5)
		rail.mesh = rail_mesh
		rail.position = Vector3(0.0, vertical_sign * (panel_height - 0.45) * 0.5, 0.0)
		_face_root.add_child(rail)
		var post := MeshInstance3D.new()
		post.name = "FramePost"
		var post_mesh := BoxMesh.new()
		post_mesh.size = Vector3(panel_thickness + 0.14, panel_height, 0.45)
		post_mesh.material = _material(FRAME_COLOR, 0.5)
		post.mesh = post_mesh
		post.position = Vector3(0.0, 0.0, vertical_sign * (panel_width - 0.45) * 0.5)
		_face_root.add_child(post)
	# Two light chevrons on the face mark it as an interactive rebound surface.
	for chevron_sign in [-1.0, 1.0]:
		for tilt in [-1.0, 1.0]:
			var bar := MeshInstance3D.new()
			bar.name = "ChevronBar"
			var bar_mesh := BoxMesh.new()
			bar_mesh.size = Vector3(0.1, 0.28, panel_width * 0.11)
			bar_mesh.material = _material(CHEVRON_COLOR, 0.55)
			bar.mesh = bar_mesh
			bar.position = Vector3(panel_thickness * 0.54, tilt * 0.32, chevron_sign * panel_width * 0.16 + tilt * -chevron_sign * panel_width * 0.05)
			bar.rotation.x = tilt * chevron_sign * 0.7
			_face_root.add_child(bar)


func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material
