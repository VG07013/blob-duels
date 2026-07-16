class_name MapLaunchPad
extends Area3D

@export var impulse_strength := 46.0
@export var local_direction := Vector3(0.0, 0.7, -1.0)
@export var cooldown := 0.28
@export var pad_color := Color(0.1, 0.86, 1.0)

@onready var _disc: MeshInstance3D = $VisualRoot/Disc
@onready var _ring: MeshInstance3D = $VisualRoot/Ring
@onready var _arrow_root: Node3D = $VisualRoot/ArrowRoot

var _pulse_time := 0.0


func _ready() -> void:
	add_to_group("map_interactable")
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	body_entered.connect(_on_body_entered)
	_apply_visuals()


func configure(direction: Vector3, strength: float, color: Color) -> void:
	local_direction = direction.normalized() if direction.length_squared() > 0.001 else Vector3.UP
	impulse_strength = maxf(strength, 0.0)
	pad_color = color
	if is_node_ready():
		_apply_visuals()


func get_interaction_kind() -> StringName:
	return &"launch_pad"


func activate_body(body: Node3D) -> bool:
	var rigid_body := body as RigidBody3D
	if rigid_body == null or rigid_body.freeze:
		return false
	var cooldown_key := "map_launch_%d" % get_instance_id()
	var now := Time.get_ticks_msec()
	if now < int(rigid_body.get_meta(cooldown_key, 0)):
		return false
	rigid_body.set_meta(cooldown_key, now + int(cooldown * 1000.0))
	var world_direction := (global_basis * local_direction).normalized()
	rigid_body.apply_central_impulse(world_direction * impulse_strength)
	rigid_body.sleeping = false
	_pulse_time = 0.24
	var audio_manager := get_node_or_null("/root/AudioManager")
	if audio_manager != null:
		audio_manager.call("play_sfx_limited", &"launch_pad", 0.08, -2.0, randf_range(0.94, 1.06), &"map_launch")
	return true


func _physics_process(delta: float) -> void:
	_pulse_time = maxf(_pulse_time - delta, 0.0)
	var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.008) * 0.035
	if _pulse_time > 0.0:
		pulse += _pulse_time * 0.28
	$VisualRoot.scale = Vector3(pulse, 1.0, pulse)


func _on_body_entered(body: Node3D) -> void:
	activate_body(body)


func _apply_visuals() -> void:
	var base_material := _material(pad_color.darkened(0.46), 0.4, 0.28, 0.35)
	var glow_material := _material(pad_color, 0.3, 0.15, 2.2)
	_disc.material_override = base_material
	_ring.material_override = glow_material
	for child in _arrow_root.get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).material_override = glow_material
	var flat_direction := Vector3(local_direction.x, 0.0, local_direction.z)
	if flat_direction.length_squared() > 0.001:
		_arrow_root.rotation.y = atan2(-flat_direction.x, -flat_direction.z)


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
