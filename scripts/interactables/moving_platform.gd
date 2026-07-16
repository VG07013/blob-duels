class_name MapMovingPlatform
extends AnimatableBody3D

@export var platform_size := Vector3(14.0, 1.4, 10.0)
@export var travel_offset := Vector3(0.0, 12.0, 0.0)
@export var cycle_time := 4.0
@export var phase_offset := 0.0
@export var platform_color := Color(0.95, 0.62, 0.12)

@onready var _collision: CollisionShape3D = $Collision
@onready var _deck: MeshInstance3D = $VisualRoot/Deck
@onready var _trim_top: MeshInstance3D = $VisualRoot/TrimTop
@onready var _trim_bottom: MeshInstance3D = $VisualRoot/TrimBottom

var _origin := Vector3.ZERO
var _elapsed := 0.0


func _ready() -> void:
	add_to_group("map_interactable")
	collision_layer = 1
	collision_mask = 2
	sync_to_physics = true
	_origin = position
	_elapsed = phase_offset * maxf(cycle_time, 0.1)
	_apply_configuration()


func configure(size: Vector3, offset: Vector3, seconds: float, color: Color, phase := 0.0) -> void:
	platform_size = size.max(Vector3.ONE)
	travel_offset = offset
	cycle_time = maxf(seconds, 0.5)
	platform_color = color
	phase_offset = phase
	if is_node_ready():
		_origin = position
		_elapsed = phase_offset * cycle_time
		_apply_configuration()


func get_interaction_kind() -> StringName:
	return &"moving_platform"


func _physics_process(delta: float) -> void:
	_elapsed = fposmod(_elapsed + delta, cycle_time)
	var t := _elapsed / cycle_time
	var eased := 0.5 - cos(t * TAU) * 0.5
	position = _origin + travel_offset * eased


func _apply_configuration() -> void:
	var shape := _collision.shape as BoxShape3D
	shape.size = platform_size
	var deck_mesh := _deck.mesh as BoxMesh
	deck_mesh.size = platform_size
	var trim_size := Vector3(platform_size.x + 0.8, 0.28, platform_size.z + 0.8)
	(_trim_top.mesh as BoxMesh).size = trim_size
	(_trim_bottom.mesh as BoxMesh).size = trim_size
	_trim_top.position.y = platform_size.y * 0.5 + 0.16
	_trim_bottom.position.y = -platform_size.y * 0.5 - 0.16
	_deck.material_override = _material(platform_color.darkened(0.36), 0.44, 0.48, 0.0)
	var trim_material := _material(platform_color, 0.28, 0.32, 1.5)
	_trim_top.material_override = trim_material
	_trim_bottom.material_override = trim_material


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

