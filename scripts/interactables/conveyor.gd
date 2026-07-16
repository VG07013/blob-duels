class_name MapConveyor
extends Area3D

@export var surface_size := Vector3(16.0, 1.0, 28.0)
@export var local_direction := Vector3.FORWARD
@export var force_strength := 62.0
@export var conveyor_color := Color(0.96, 0.66, 0.12)

@onready var _area_collision: CollisionShape3D = $AreaCollision
@onready var _floor_collision: CollisionShape3D = $Floor/Collision
@onready var _deck: MeshInstance3D = $Floor/Deck
@onready var _arrows: Node3D = $Floor/Arrows

var _bodies: Array[RigidBody3D] = []
var _scroll_time := 0.0


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
	surface_size = size.max(Vector3.ONE)
	local_direction = direction.normalized() if direction.length_squared() > 0.001 else Vector3.FORWARD
	force_strength = maxf(strength, 0.0)
	conveyor_color = color
	if is_node_ready():
		_apply_configuration()


func get_interaction_kind() -> StringName:
	return &"conveyor"


func affect_body(body: Node3D) -> bool:
	var rigid_body := body as RigidBody3D
	if rigid_body == null or rigid_body.freeze:
		return false
	var direction := (global_basis * local_direction).normalized()
	rigid_body.apply_central_force(direction * force_strength * rigid_body.mass)
	rigid_body.sleeping = false
	return true


func _physics_process(delta: float) -> void:
	_scroll_time += delta
	for body in _bodies.duplicate():
		if not is_instance_valid(body):
			_bodies.erase(body)
			continue
		affect_body(body)
	for index in range(_arrows.get_child_count()):
		var arrow := _arrows.get_child(index) as Node3D
		arrow.position.z = -surface_size.z * 0.42 + fposmod(_scroll_time * 7.0 + float(index) * surface_size.z / 4.0, surface_size.z * 0.84)


func _on_body_entered(body: Node3D) -> void:
	var rigid_body := body as RigidBody3D
	if rigid_body != null and not _bodies.has(rigid_body):
		_bodies.append(rigid_body)
		var audio_manager := get_node_or_null("/root/AudioManager")
		if audio_manager != null:
			audio_manager.call("set_world_loop", &"machinery", 0.48, _audio_loop_id())
			audio_manager.call("play_sfx_limited", &"conveyor_rail", 0.12, -8.0, randf_range(0.94, 1.06), &"map_conveyor")


func _on_body_exited(body: Node3D) -> void:
	var rigid_body := body as RigidBody3D
	if rigid_body != null:
		_bodies.erase(rigid_body)
	if _bodies.is_empty():
		var audio_manager := get_node_or_null("/root/AudioManager")
		if audio_manager != null:
			audio_manager.call("stop_loop", _audio_loop_id(), 0.2)


func _audio_loop_id() -> StringName:
	return StringName("machinery_%d" % get_instance_id())


func _apply_configuration() -> void:
	var area_size := surface_size + Vector3(0.0, 3.0, 0.0)
	(_area_collision.shape as BoxShape3D).size = area_size
	_area_collision.position.y = 1.5
	(_floor_collision.shape as BoxShape3D).size = surface_size
	(_deck.mesh as BoxMesh).size = surface_size
	_deck.material_override = _material(conveyor_color.darkened(0.55), 0.5, 0.44, 0.0)
	var arrow_material := _material(conveyor_color, 0.28, 0.14, 1.65)
	for index in range(_arrows.get_child_count()):
		var arrow := _arrows.get_child(index) as MeshInstance3D
		arrow.position.x = 0.0
		arrow.position.y = surface_size.y * 0.5 + 0.08
		arrow.scale.x = surface_size.x * 0.46
		arrow.material_override = arrow_material


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
