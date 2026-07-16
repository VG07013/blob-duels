class_name MapWindZone
extends Area3D

@export var zone_size := Vector3(12.0, 12.0, 28.0)
@export var local_direction := Vector3.FORWARD
@export var force_strength := 88.0
@export var wind_color := Color(0.42, 0.86, 1.0)

@onready var _collision: CollisionShape3D = $Collision
@onready var _volume: MeshInstance3D = $VisualRoot/Volume
@onready var _stripes: Node3D = $VisualRoot/AirStripes

var _bodies: Array[RigidBody3D] = []
var _flow_time := 0.0


func _ready() -> void:
	add_to_group("map_interactable")
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_apply_configuration()


func _exit_tree() -> void:
	var audio_manager := get_node_or_null("/root/AudioManager")
	if audio_manager != null:
		audio_manager.call("stop_loop", _audio_loop_id(), 0.12)
	_bodies.clear()


func configure(size: Vector3, direction: Vector3, strength: float, color: Color) -> void:
	zone_size = size.max(Vector3.ONE)
	local_direction = direction.normalized() if direction.length_squared() > 0.001 else Vector3.FORWARD
	force_strength = maxf(strength, 0.0)
	wind_color = color
	if is_node_ready():
		_apply_configuration()


func get_interaction_kind() -> StringName:
	return &"wind_zone"


func affect_body(body: Node3D) -> bool:
	var rigid_body := body as RigidBody3D
	if rigid_body == null or rigid_body.freeze:
		return false
	var world_direction := (global_basis * local_direction).normalized()
	rigid_body.apply_central_force(world_direction * force_strength * rigid_body.mass)
	rigid_body.sleeping = false
	return true


func _physics_process(delta: float) -> void:
	_flow_time += delta
	for body in _bodies.duplicate():
		if not is_instance_valid(body):
			_bodies.erase(body)
			continue
		affect_body(body)
	for index in range(_stripes.get_child_count()):
		var stripe := _stripes.get_child(index) as Node3D
		var phase := fposmod(_flow_time * 9.0 + float(index) * zone_size.z / 6.0, zone_size.z)
		stripe.position.z = -zone_size.z * 0.5 + phase


func _on_body_entered(body: Node3D) -> void:
	var rigid_body := body as RigidBody3D
	if rigid_body != null and not _bodies.has(rigid_body):
		_bodies.append(rigid_body)
		var audio_manager := get_node_or_null("/root/AudioManager")
		if audio_manager != null:
			audio_manager.call("set_world_loop", &"wind", 0.62, _audio_loop_id())


func _on_body_exited(body: Node3D) -> void:
	var rigid_body := body as RigidBody3D
	if rigid_body != null:
		_bodies.erase(rigid_body)
	if _bodies.is_empty():
		var audio_manager := get_node_or_null("/root/AudioManager")
		if audio_manager != null:
			audio_manager.call("stop_loop", _audio_loop_id(), 0.2)


func _audio_loop_id() -> StringName:
	return StringName("wind_%d" % get_instance_id())


func _apply_configuration() -> void:
	var shape := _collision.shape as BoxShape3D
	shape.size = zone_size
	var volume_mesh := _volume.mesh as BoxMesh
	volume_mesh.size = zone_size
	var volume_color := Color(wind_color, 0.075)
	var volume_material := StandardMaterial3D.new()
	volume_material.albedo_color = volume_color
	volume_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	volume_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_volume.material_override = volume_material
	var stripe_material := StandardMaterial3D.new()
	stripe_material.albedo_color = Color(wind_color, 0.42)
	stripe_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	stripe_material.emission_enabled = true
	stripe_material.emission = wind_color
	stripe_material.emission_energy_multiplier = 1.15
	for index in range(_stripes.get_child_count()):
		var stripe := _stripes.get_child(index) as MeshInstance3D
		stripe.position.x = lerpf(-zone_size.x * 0.32, zone_size.x * 0.32, float(index % 3) / 2.0)
		stripe.position.y = lerpf(-zone_size.y * 0.27, zone_size.y * 0.27, float(index / 3))
		stripe.scale = Vector3(zone_size.x * 0.12, 0.09, 1.0)
		stripe.material_override = stripe_material
