class_name BlobVisual
extends Node3D

const COMBAT_TUNING := preload("res://scripts/combat_tuning.gd")

@export_range(0.0, 0.2, 0.005) var maximum_lean := 0.085
@export_range(0.0, 0.1, 0.002) var idle_wobble := 0.012
@export_range(1.0, 20.0, 0.5) var response_speed := 9.0
@export_range(0.0, 0.3, 0.01) var speed_stretch := 0.14
@export_range(0.0, 0.35, 0.01) var impact_squash := 0.24

@onready var body := get_parent() as RigidBody3D

## How far above the ground the blob can float before its contact shadow
## fades out entirely. Matches the tallest launch arcs that still read as
## "over this spot".
const GROUND_SHADOW_RANGE := 26.0
const GROUND_SHADOW_SIZE := 6.6

var _impact_energy := 0.0
var _launch_energy := 0.0
var _landing_energy := 0.0
var _previous_velocity := Vector3.ZERO
var _visual_yaw := 0.0
var _wobble_time := 0.0
var _was_grounded := false
var _ground_shadow: MeshInstance3D
var _ground_shadow_material: StandardMaterial3D
var _shadow_query: PhysicsRayQueryParameters3D
## Presentation state kept separately from the node transform, because the
## hit flex composes a non-orthogonal squash on top and a sheared basis cannot
## be read back as rotation + scale.
var _pitch := 0.0
var _roll := 0.0
var _body_scale := Vector3.ONE
## Hit flex spring: a dent of signed size _flex_amount along world _flex_dir.
var _flex_dir := Vector3.FORWARD
var _flex_amount := 0.0
var _flex_speed := 0.0
## Scripted victory pose layered on top of the physics-driven look: positive
## squash flattens, negative stretches tall, and spin turns about the vertical.
var _celebrate_squash := 0.0
var _celebrate_spin := 0.0


func _ready() -> void:
	scale = Vector3.ONE
	_body_scale = Vector3.ONE
	if body != null:
		global_position = body.global_position
		_visual_yaw = body.global_rotation.y
		_previous_velocity = body.linear_velocity
	_build_ground_shadow()


func _build_ground_shadow() -> void:
	_ground_shadow = MeshInstance3D.new()
	_ground_shadow.name = "GroundShadow"
	# The shadow hugs the floor below the body, never the squash-and-stretch
	# transform of this node, so it opts out of the parent transform entirely.
	_ground_shadow.top_level = true
	_ground_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var plane := PlaneMesh.new()
	plane.size = Vector2(GROUND_SHADOW_SIZE, GROUND_SHADOW_SIZE)
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	gradient.colors = PackedColorArray([
		Color(1.0, 1.0, 1.0, 1.0), Color(1.0, 1.0, 1.0, 0.55), Color(1.0, 1.0, 1.0, 0.0),
	])
	var falloff := GradientTexture2D.new()
	falloff.gradient = gradient
	falloff.fill = GradientTexture2D.FILL_RADIAL
	falloff.fill_from = Vector2(0.5, 0.5)
	falloff.fill_to = Vector2(0.5, 0.02)
	_ground_shadow_material = StandardMaterial3D.new()
	_ground_shadow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ground_shadow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ground_shadow_material.albedo_color = Color(0.0, 0.0, 0.0, 0.4)
	_ground_shadow_material.albedo_texture = falloff
	plane.material = _ground_shadow_material
	_ground_shadow.mesh = plane
	_ground_shadow.visible = false
	add_child(_ground_shadow)


func hit_reaction(amount: float = 0.35) -> void:
	_impact_energy = maxf(_impact_energy, clampf(amount, 0.0, 1.0))


## Dents the blob along `world_direction` (the way the hit pushes it) and
## leans it that way; the spring then jiggles it back through a stretch.
## `strength` is the impulse size, so bigger hits flex harder.
func hit_flex(world_direction: Vector3, strength: float) -> void:
	if world_direction.length_squared() < 0.0001:
		return
	var direction := world_direction.normalized()
	# Blend into an in-flight flex rather than snapping its axis around.
	var carried := _flex_dir * _flex_amount
	_flex_dir = direction
	_flex_amount = carried.dot(direction)
	var kick := clampf(strength * COMBAT_TUNING.FLEX_KICK_PER_IMPULSE, 0.0, COMBAT_TUNING.FLEX_MAX_KICK)
	# A spring launched at speed k * omega from rest peaks near k.
	_flex_speed += kick * sqrt(COMBAT_TUNING.FLEX_STIFFNESS)
	_impact_energy = maxf(_impact_energy, clampf(kick, 0.0, 0.5))


func get_flex_amount() -> float:
	return _flex_amount


## The world-space lean+squash currently applied, so the face (a separate
## top-level node) can bend with the body instead of floating rigidly on it.
func get_flex_basis() -> Basis:
	return _celebration_basis() * _flex_basis()


## Drives the victory celebration without touching the body (Jolt rejects
## non-uniform scale). Pass zeros to hand control back to physics.
func set_celebration_pose(squash: float, spin: float) -> void:
	_celebrate_squash = clampf(squash, -0.45, 0.45)
	_celebrate_spin = spin


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
	_pitch = lerp_angle(_pitch, target_pitch, blend)
	_roll = lerp_angle(_roll, target_roll, blend)
	var impact_amount := _impact_energy * impact_squash + _landing_energy * 0.11
	var forward_scale := 1.0 + speed_ratio * speed_stretch + _launch_energy * 0.13 - impact_amount * 0.04
	var side_scale := 1.0 - speed_ratio * speed_stretch * 0.42 - _launch_energy * 0.05 + impact_amount * 0.38
	var height_scale := 1.0 - speed_ratio * 0.028 - impact_amount + _launch_energy * 0.045
	var target_scale := Vector3(side_scale, height_scale, forward_scale)
	_body_scale = _body_scale.lerp(target_scale, 1.0 - exp(-15.0 * delta))
	_update_flex(delta)
	basis = _celebration_basis() * _flex_basis() * Basis.from_euler(Vector3(_pitch, _visual_yaw, _roll)) * Basis.from_scale(_body_scale)
	_previous_velocity = velocity
	_update_ground_shadow()


func _update_flex(delta: float) -> void:
	var acceleration := -COMBAT_TUNING.FLEX_STIFFNESS * _flex_amount - COMBAT_TUNING.FLEX_DAMPING * _flex_speed
	_flex_speed += acceleration * delta
	_flex_amount += _flex_speed * delta
	if absf(_flex_amount) < 0.0005 and absf(_flex_speed) < 0.005:
		_flex_amount = 0.0
		_flex_speed = 0.0


## World-space lean toward the push times a squash along it: compressed on
## the hit axis, bulged across it (negative amounts stretch on the rebound).
func _flex_basis() -> Basis:
	if _flex_amount == 0.0:
		return Basis.IDENTITY
	var dent := clampf(_flex_amount, -COMBAT_TUNING.FLEX_MAX_DENT, COMBAT_TUNING.FLEX_MAX_DENT)
	var d := _flex_dir
	var along := 1.0 - dent
	var across := 1.0 + dent * 0.5
	# S = across * I + (along - across) * d d^T
	var squash := Basis(
		Vector3(across, 0, 0) + d * d.x * (along - across),
		Vector3(0, across, 0) + d * d.y * (along - across),
		Vector3(0, 0, across) + d * d.z * (along - across)
	)
	var lean_axis := Vector3.UP.cross(d)
	if lean_axis.length_squared() < 0.0001:
		return squash
	var lean := clampf(_flex_amount * COMBAT_TUNING.FLEX_LEAN_PER_DENT, -COMBAT_TUNING.FLEX_MAX_LEAN, COMBAT_TUNING.FLEX_MAX_LEAN)
	return Basis(lean_axis.normalized(), lean) * squash


func _celebration_basis() -> Basis:
	if _celebrate_squash == 0.0 and _celebrate_spin == 0.0:
		return Basis.IDENTITY
	var squash := Vector3(1.0 + _celebrate_squash * 0.55, 1.0 - _celebrate_squash, 1.0 + _celebrate_squash * 0.55)
	return Basis(Vector3.UP, _celebrate_spin) * Basis.from_scale(squash)


func _update_ground_shadow() -> void:
	if _ground_shadow == null or body == null or not body.is_inside_tree():
		return
	var space_state := body.get_world_3d().direct_space_state
	if space_state == null:
		return
	if _shadow_query == null:
		_shadow_query = PhysicsRayQueryParameters3D.new()
		_shadow_query.collision_mask = 1
		_shadow_query.exclude = [body.get_rid()]
	_shadow_query.from = body.global_position
	_shadow_query.to = body.global_position + Vector3.DOWN * (GROUND_SHADOW_RANGE + 4.0)
	var hit := space_state.intersect_ray(_shadow_query)
	if hit.is_empty():
		_ground_shadow.visible = false
		return
	var ground_point := hit["position"] as Vector3
	var clearance := maxf(body.global_position.y - ground_point.y - 2.9, 0.0)
	var closeness := clampf(1.0 - clearance / GROUND_SHADOW_RANGE, 0.0, 1.0)
	if closeness <= 0.02:
		_ground_shadow.visible = false
		return
	_ground_shadow.visible = true
	var up := (hit.get("normal", Vector3.UP) as Vector3).normalized()
	if up.length_squared() < 0.5:
		up = Vector3.UP
	var reference := Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.92 else Vector3.RIGHT
	var x_axis := reference.cross(up).normalized()
	var z_axis := x_axis.cross(up).normalized()
	var spread := lerpf(0.4, 1.0, closeness)
	_ground_shadow.global_transform = Transform3D(
		Basis(x_axis, up, z_axis) * Basis.from_scale(Vector3(spread, 1.0, spread)),
		ground_point + up * 0.07
	)
	var shadow_color := _ground_shadow_material.albedo_color
	shadow_color.a = 0.42 * (0.2 + 0.8 * closeness)
	_ground_shadow_material.albedo_color = shadow_color
