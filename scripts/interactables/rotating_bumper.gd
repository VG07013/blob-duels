class_name MapRotatingBumper
extends Node3D

@export var arm_length := 26.0
@export var rotation_speed := 1.2
@export var impact_impulse := 24.0
@export var bumper_color := Color(1.0, 0.28, 0.16)
@export var cooldown := 0.24

@onready var _spinner: AnimatableBody3D = $Spinner
@onready var _arm: MeshInstance3D = $Spinner/Arm
@onready var _arm_collision: CollisionShape3D = $Spinner/Collision
@onready var _hit_collision: CollisionShape3D = $Spinner/HitArea/Collision
@onready var _hub: MeshInstance3D = $Hub


func _ready() -> void:
	add_to_group("map_interactable")
	$Spinner/HitArea.collision_layer = 0
	$Spinner/HitArea.collision_mask = 2
	$Spinner/HitArea.monitoring = true
	$Spinner/HitArea.body_entered.connect(_on_body_entered)
	_apply_configuration()


func configure(length: float, speed: float, impulse: float, color: Color) -> void:
	arm_length = maxf(length, 4.0)
	rotation_speed = speed
	impact_impulse = maxf(impulse, 0.0)
	bumper_color = color
	if is_node_ready():
		_apply_configuration()


func get_interaction_kind() -> StringName:
	return &"rotating_bumper"


func activate_body(body: Node3D) -> bool:
	var rigid_body := body as RigidBody3D
	if rigid_body == null or rigid_body.freeze:
		return false
	var cooldown_key := "map_bumper_%d" % get_instance_id()
	var now := Time.get_ticks_msec()
	if now < int(rigid_body.get_meta(cooldown_key, 0)):
		return false
	rigid_body.set_meta(cooldown_key, now + int(cooldown * 1000.0))
	var radial := rigid_body.global_position - global_position
	radial.y = 0.0
	if radial.length_squared() < 0.01:
		radial = global_basis.x
	var tangent := Vector3.UP.cross(radial.normalized()) * signf(rotation_speed)
	var direction := (radial.normalized() * 0.72 + tangent * 0.46 + Vector3.UP * 0.34).normalized()
	rigid_body.apply_central_impulse(direction * impact_impulse)
	rigid_body.sleeping = false
	var audio_manager := get_node_or_null("/root/AudioManager")
	if audio_manager != null:
		audio_manager.call("play_impact", &"hard", clampf(impact_impulse / 36.0, 0.25, 1.0))
		audio_manager.call("play_sfx_limited", &"bumper_hit", 0.08, -3.0, randf_range(0.9, 1.08), &"map_bumper")
	return true


func _physics_process(delta: float) -> void:
	_spinner.rotate_y(rotation_speed * delta)


func _on_body_entered(body: Node3D) -> void:
	activate_body(body)


func _apply_configuration() -> void:
	var size := Vector3(arm_length, 1.8, 2.8)
	(_arm.mesh as BoxMesh).size = size
	(_arm_collision.shape as BoxShape3D).size = size
	(_hit_collision.shape as BoxShape3D).size = size + Vector3(0.8, 1.0, 0.8)
	var arm_material := _material(bumper_color, 0.38, 0.35, 1.2)
	_arm.material_override = arm_material
	_hub.material_override = _material(bumper_color.darkened(0.5), 0.32, 0.62, 0.0)


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
