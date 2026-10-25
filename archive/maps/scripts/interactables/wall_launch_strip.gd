class_name ArenaWallLaunchStrip
extends Area3D

var strip_size := Vector3(8.66, 11.55, 0.87)
var inward := Vector3.RIGHT
var strip_color := Color(0.153, 0.549, 1.0)
var speed_multiplier := 1.15
var _cooldowns: Dictionary = {}
var _core: MeshInstance3D
var _flash: OmniLight3D
var _pulse_time := 0.0


func configure(size: Vector3, direction: Vector3, color: Color) -> void:
	strip_size = size
	inward = direction.normalized()
	strip_color = color


func _ready() -> void:
	add_to_group("map_interactable")
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	body_entered.connect(_on_body_entered)
	_build_solid_housing()


func get_interaction_kind() -> StringName:
	return &"wall_launch_strip"


func _build_solid_housing() -> void:
	var normal := Vector3(inward.x, 0.0, inward.z).normalized()
	var yaw := atan2(normal.x, normal.z)
	var body := StaticBody3D.new()
	body.name = "SolidHousing"
	body.collision_layer = 1
	body.collision_mask = 2
	body.physics_material_override = preload("res://assets/materials/physics/arena_bounce.tres")
	add_child(body)
	var solid := CollisionShape3D.new()
	var solid_shape := BoxShape3D.new()
	solid_shape.size = strip_size
	solid.shape = solid_shape
	solid.rotation.y = yaw
	body.add_child(solid)
	var trigger := CollisionShape3D.new()
	var trigger_shape := BoxShape3D.new()
	trigger_shape.size = strip_size + Vector3(0.35, 0.35, 0.5)
	trigger.shape = trigger_shape
	trigger.rotation.y = yaw
	add_child(trigger)
	var base := MeshInstance3D.new()
	var base_mesh := BoxMesh.new()
	base_mesh.size = strip_size + Vector3(0.35, 0.35, 0.08)
	base_mesh.material = _material(Color(0.12, 0.14, 0.17), 0.55, 0.42, 0.0)
	base.mesh = base_mesh
	base.rotation.y = yaw
	add_child(base)
	var core := MeshInstance3D.new()
	var core_mesh := BoxMesh.new()
	core_mesh.size = strip_size * Vector3(0.68, 0.68, 0.42)
	core_mesh.material = _material(strip_color, 0.28, 0.18, 1.55)
	core.mesh = core_mesh
	core.position = normal * (strip_size.z * 0.52)
	core.rotation.y = yaw
	add_child(core)
	_core = core
	for side in [-1.0, 1.0]:
		var bracket := MeshInstance3D.new()
		bracket.name = "MechanicalBracket"
		var bracket_mesh := BoxMesh.new()
		bracket_mesh.size = Vector3(strip_size.x * 0.12, strip_size.y * 1.12, strip_size.z * 2.0)
		bracket_mesh.material = _material(Color(0.32, 0.36, 0.4), 0.34, 0.68, 0.0)
		bracket.mesh = bracket_mesh
		bracket.position = Vector3(side * strip_size.x * 0.48, 0, -normal.z * 0.02)
		bracket.rotation.y = yaw
		add_child(bracket)
	for offset in [-0.28, 0.0, 0.28]:
		var arrow := MeshInstance3D.new()
		var arrow_mesh := BoxMesh.new()
		arrow_mesh.size = Vector3(strip_size.x * 0.12, strip_size.y * 0.12, 0.08)
		arrow_mesh.material = _material(Color(0.96, 0.98, 1.0), 0.35, 0.1, 1.3)
		arrow.mesh = arrow_mesh
		arrow.position = normal * (strip_size.z * 0.76) + Vector3.UP * offset * strip_size.y
		arrow.rotation.y = yaw
		add_child(arrow)
	_flash = OmniLight3D.new()
	_flash.light_color = strip_color
	_flash.light_energy = 0.32
	_flash.omni_range = maxf(strip_size.x, strip_size.y) * 1.35
	_flash.position = normal * (strip_size.z * 1.4)
	add_child(_flash)


func _process(delta: float) -> void:
	_pulse_time = maxf(0.0, _pulse_time - delta)
	if _core != null:
		var pulse := 1.0 + _pulse_time * 0.24
		_core.scale = Vector3(1.0, pulse, 1.0)
	if _flash != null:
		_flash.light_energy = 0.32 + _pulse_time * 2.2


func _on_body_entered(body: Node3D) -> void:
	var rigid := body as RigidBody3D
	if rigid == null or rigid.freeze:
		return
	var horizontal := Vector3(rigid.linear_velocity.x, 0.0, rigid.linear_velocity.z)
	if horizontal.length() < 2.0:
		return
	var key := rigid.get_instance_id()
	var now := Time.get_ticks_msec()
	if now < int(_cooldowns.get(key, 0)):
		return
	_cooldowns[key] = now + 280
	var normal := Vector3(inward.x, 0.0, inward.z).normalized()
	var reflected := horizontal.bounce(-normal) * speed_multiplier
	var capped := reflected.limit_length(138.0)
	rigid.linear_velocity = Vector3(capped.x, rigid.linear_velocity.y * 0.94, capped.z)
	rigid.sleeping = false
	_pulse_time = 0.18
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null:
		audio.call("play_sfx_limited", &"launch_pad", 0.08, -7.0, 1.08, &"wall_strip")


func _material(color: Color, roughness: float, metallic: float, emission: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	if emission > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission
	return material
