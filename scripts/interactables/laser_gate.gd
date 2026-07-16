class_name NeonLaserGate
extends Area3D

@export var gate_size := Vector3(34.65, 28.88, 1.15)
@export var local_push_direction := Vector3.FORWARD
@export var push_strength := 34.0
@export var off_duration := 5.0
@export var on_duration := 3.0
@export var gate_color := Color(0.52, 0.24, 0.9)

var _elapsed := 0.0
var _is_active := false
var _beam: MeshInstance3D
var _core_beam: MeshInstance3D
var _frame: MeshInstance3D
var _light: OmniLight3D


func _ready() -> void:
	add_to_group("map_interactable")
	collision_layer = 0
	collision_mask = 2
	body_entered.connect(_on_body_entered)
	_build_visuals()
	_set_active(false)


func configure(size_value: Vector3, direction: Vector3, strength: float, color: Color) -> void:
	gate_size = size_value
	local_push_direction = direction.normalized() if direction.length_squared() > 0.001 else Vector3.FORWARD
	push_strength = maxf(strength, 0.0)
	gate_color = color
	if is_node_ready():
		_rebuild()


func get_interaction_kind() -> StringName:
	return &"laser_gate"


func is_gate_active() -> bool:
	return _is_active


func _physics_process(delta: float) -> void:
	_elapsed = fmod(_elapsed + delta, off_duration + on_duration)
	var should_be_active := _elapsed >= off_duration
	if should_be_active != _is_active:
		_set_active(should_be_active)
		if _is_active:
			for body in get_overlapping_bodies():
				_push_body(body as Node3D)


func _on_body_entered(body: Node3D) -> void:
	if _is_active:
		_push_body(body)


func _push_body(body: Node3D) -> void:
	var rigid_body := body as RigidBody3D
	if rigid_body == null or rigid_body.freeze:
		return
	var cooldown_key := "laser_gate_%d" % get_instance_id()
	var now := Time.get_ticks_msec()
	if now < int(rigid_body.get_meta(cooldown_key, 0)):
		return
	rigid_body.set_meta(cooldown_key, now + 240)
	var direction := (global_basis * local_push_direction).normalized()
	rigid_body.apply_central_impulse((direction + Vector3.UP * 0.12).normalized() * push_strength)
	rigid_body.sleeping = false


func _set_active(active: bool) -> void:
	_is_active = active
	monitoring = active
	if _beam != null:
		_beam.visible = active
	if _core_beam != null:
		_core_beam.visible = active
	if _light != null:
		_light.visible = active
	if _frame != null:
		_frame.material_override = _material(gate_color, 1.1 if active else 0.28)


func _build_visuals() -> void:
	_beam = MeshInstance3D.new()
	_beam.name = "LaserBeam"
	add_child(_beam)
	_core_beam = MeshInstance3D.new()
	_core_beam.name = "LaserCore"
	add_child(_core_beam)
	_frame = MeshInstance3D.new()
	_frame.name = "GateFrame"
	add_child(_frame)
	_light = OmniLight3D.new()
	_light.name = "LaserGlow"
	_light.shadow_enabled = false
	add_child(_light)
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	add_child(collision)
	_rebuild()


func _rebuild() -> void:
	if _beam == null:
		return
	var beam_mesh := BoxMesh.new()
	beam_mesh.size = gate_size
	beam_mesh.material = _material(gate_color, 3.4)
	_beam.mesh = beam_mesh
	var core_mesh := BoxMesh.new()
	core_mesh.size = Vector3(gate_size.x * 0.74, gate_size.y * 0.74, gate_size.z * 1.8)
	core_mesh.material = _material(Color(0.98, 0.84, 1.0), 4.6)
	_core_beam.mesh = core_mesh
	var frame_mesh := BoxMesh.new()
	frame_mesh.size = Vector3(gate_size.x + 1.0, 0.48, gate_size.z + 0.5)
	_frame.mesh = frame_mesh
	_frame.position.y = gate_size.y * 0.5
	_frame.material_override = _material(gate_color.darkened(0.35), 1.35)
	_light.light_color = gate_color
	_light.light_energy = 1.7
	_light.omni_range = maxf(gate_size.x, gate_size.y) * 1.35
	var collision := get_node_or_null("Collision") as CollisionShape3D
	if collision != null:
		var shape := BoxShape3D.new()
		shape.size = gate_size
		collision.shape = shape


func _material(color: Color, emission: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color.r, color.g, color.b, 0.76)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = emission
	return material
