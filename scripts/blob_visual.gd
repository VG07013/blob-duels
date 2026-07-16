extends Node3D

@export_range(0.0, 0.2, 0.005) var maximum_lean := 0.085
@export_range(0.0, 0.1, 0.002) var idle_wobble := 0.012
@export_range(1.0, 20.0, 0.5) var response_speed := 9.0
@export_range(0.0, 0.3, 0.01) var speed_stretch := 0.14
@export_range(0.0, 0.35, 0.01) var impact_squash := 0.24

@onready var body := get_parent() as RigidBody3D

var _impact_energy := 0.0
var _launch_energy := 0.0
var _landing_energy := 0.0
var _previous_velocity := Vector3.ZERO
var _visual_yaw := 0.0
var _wobble_time := 0.0
var _was_grounded := false


func _ready() -> void:
	scale = Vector3.ONE
	if body != null:
		global_position = body.global_position
		_visual_yaw = body.global_rotation.y
		_previous_velocity = body.linear_velocity


func hit_reaction(amount: float = 0.35) -> void:
	_impact_energy = maxf(_impact_energy, clampf(amount, 0.0, 1.0))


func set_launch_energy(amount: float = 0.35) -> void:
	_launch_energy = maxf(_launch_energy, clampf(amount, 0.0, 1.0))


func _physics_process(delta: float) -> void:
	if body == null:
		return

	# The presentation node follows the physics body without ever deforming it.
	global_position = body.global_position

	var velocity := body.linear_velocity
	var flat_velocity := Vector3(velocity.x, 0.0, velocity.z)
	var flat_speed := flat_velocity.length()
	var acceleration := (velocity - _previous_velocity) / maxf(delta, 0.001)
	acceleration.y = 0.0
	acceleration = acceleration.limit_length(45.0)

	if flat_speed > 0.45:
		var target_yaw := atan2(-flat_velocity.x, -flat_velocity.z)
		_visual_yaw = lerp_angle(_visual_yaw, target_yaw, 1.0 - exp(-6.5 * delta))

	var facing_forward := Vector3(-sin(_visual_yaw), 0.0, -cos(_visual_yaw))
	var facing_right := Vector3(cos(_visual_yaw), 0.0, -sin(_visual_yaw))
	var speed_ratio := clampf(flat_speed / 32.0, 0.0, 1.0)
	var forward_lean := -acceleration.dot(facing_forward) * 0.0017 - speed_ratio * 0.018
	var side_lean := -acceleration.dot(facing_right) * 0.0021

	_wobble_time += delta * (2.0 + speed_ratio * 2.4)
	_impact_energy = move_toward(_impact_energy, 0.0, delta * 2.6)
	_launch_energy = move_toward(_launch_energy, 0.0, delta * 3.8)
	_landing_energy = move_toward(_landing_energy, 0.0, delta * 4.6)
	var grounded := body.has_method("is_grounded") and bool(body.call("is_grounded"))
	if grounded and not _was_grounded and _previous_velocity.y < -4.0:
		_landing_energy = clampf(absf(_previous_velocity.y) * 0.045, 0.12, 1.0)
		_impact_energy = maxf(_impact_energy, _landing_energy * 0.72)
	_was_grounded = grounded
	var wobble_strength := idle_wobble + _impact_energy * 0.055
	var target_pitch := clampf(forward_lean + sin(_wobble_time) * wobble_strength, -maximum_lean, maximum_lean)
	var target_roll := clampf(side_lean + cos(_wobble_time * 0.82) * wobble_strength * 0.72, -maximum_lean, maximum_lean)
	var blend := 1.0 - exp(-response_speed * delta)
	rotation = Vector3(
		lerp_angle(rotation.x, target_pitch, blend),
		_visual_yaw,
		lerp_angle(rotation.z, target_roll, blend)
	)
	var impact_amount := _impact_energy * impact_squash + _landing_energy * 0.11
	var forward_scale := 1.0 + speed_ratio * speed_stretch + _launch_energy * 0.13 - impact_amount * 0.04
	var side_scale := 1.0 - speed_ratio * speed_stretch * 0.42 - _launch_energy * 0.05 + impact_amount * 0.38
	var height_scale := 1.0 - speed_ratio * 0.028 - impact_amount + _launch_energy * 0.045
	var target_scale := Vector3(side_scale, height_scale, forward_scale)
	scale = scale.lerp(target_scale, 1.0 - exp(-15.0 * delta))
	_previous_velocity = velocity
