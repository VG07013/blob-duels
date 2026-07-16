extends Node3D

@export var minimum_blink_interval := 2.2
@export var maximum_blink_interval := 4.8
@export var blink_duration := 0.16
@export_range(0.0, 0.2, 0.01) var pupil_look_distance := 0.075

@onready var _blink_nodes: Array[Node3D] = [
	$LeftEyeWhite,
	$RightEyeWhite,
	$LeftPupil,
	$RightPupil,
	$LeftHighlight,
	$RightHighlight,
]

var _base_scales: Dictionary = {}
var _base_positions: Dictionary = {}
var _blink_timer := 0.0
var _blink_elapsed := -1.0
var _random := RandomNumberGenerator.new()


func _ready() -> void:
	_random.seed = get_instance_id()
	for node in _blink_nodes:
		_base_scales[node] = node.scale
		_base_positions[node] = node.position
	_schedule_blink()


func _process(delta: float) -> void:
	_update_pupil_focus(delta)
	if _blink_elapsed >= 0.0:
		_blink_elapsed += delta
		var progress := clampf(_blink_elapsed / maxf(blink_duration, 0.01), 0.0, 1.0)
		_set_eye_openness(1.0 - sin(progress * PI) * 0.92)
		if progress >= 1.0:
			_blink_elapsed = -1.0
			_set_eye_openness(1.0)
			_schedule_blink()
		return
	_blink_timer -= delta
	if _blink_timer <= 0.0:
		trigger_blink()


func trigger_blink() -> void:
	_blink_elapsed = 0.0


func _set_eye_openness(openness: float) -> void:
	var safe_openness := clampf(openness, 0.08, 1.0)
	for node in _blink_nodes:
		var base_scale: Vector3 = _base_scales.get(node, Vector3.ONE)
		node.scale = Vector3(base_scale.x, base_scale.y * safe_openness, base_scale.z)


func _schedule_blink() -> void:
	_blink_timer = _random.randf_range(minimum_blink_interval, maximum_blink_interval)


func _update_pupil_focus(delta: float) -> void:
	var body := get_parent() as RigidBody3D
	if body == null:
		return
	var local_motion := body.linear_velocity
	var target_offset := Vector3.ZERO
	if local_motion.length_squared() > 2.0:
		target_offset.x = clampf(local_motion.x * 0.003, -pupil_look_distance, pupil_look_distance)
		target_offset.y = clampf(local_motion.y * 0.0015, -pupil_look_distance * 0.38, pupil_look_distance * 0.38)
	for node_name in ["LeftPupil", "RightPupil", "LeftHighlight", "RightHighlight"]:
		var node := get_node_or_null(NodePath(node_name)) as Node3D
		if node == null:
			continue
		var base_position: Vector3 = _base_positions.get(node, node.position)
		node.position = node.position.lerp(base_position + target_offset, 1.0 - exp(-11.0 * delta))
