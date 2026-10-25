class_name MapJumpRing
extends Area3D

## A standing hoop that re-flings any blob threading it along the hoop axis.
##
## The ring is a pure trigger: it never has solid collision, so a blob passing
## through is never clipped by the tube, and the builder supplies whatever
## posts hold it up. The launch direction follows the blob's own travel along
## the axis, so one hoop serves both directions of a lane and can never throw
## a blob into the wall the hoop faces. Slow drifts through the hoop do
## nothing; it rewards a committed run.

@export var inner_radius := 5.775
@export var tube_radius := 0.7
@export var local_axis := Vector3.FORWARD
@export var speed_multiplier := 1.3
@export var minimum_exit_speed := 34.0
@export var maximum_exit_speed := 96.0
@export var minimum_entry_speed := 4.0
@export var upward_assist := 6.0
@export var ring_color := Color(0.15, 0.55, 1.0)
@export var glow_energy := 1.6
@export var cooldown := 0.35

var _pulse := 0.0
var _visual_root: Node3D
var _light: OmniLight3D


func _ready() -> void:
	add_to_group("map_interactable")
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	body_entered.connect(_on_body_entered)
	_build_model()


func configure(radius: float, tube: float, axis: Vector3, multiplier: float, exit_speed: float, color: Color) -> void:
	inner_radius = maxf(radius, 1.0)
	tube_radius = maxf(tube, 0.1)
	local_axis = axis.normalized() if axis.length_squared() > 0.001 else Vector3.FORWARD
	speed_multiplier = maxf(multiplier, 1.0)
	minimum_exit_speed = maxf(exit_speed, 0.0)
	ring_color = color


func get_interaction_kind() -> StringName:
	return &"jump_ring"


func activate_body(body: Node3D) -> bool:
	var rigid := body as RigidBody3D
	if rigid == null or rigid.freeze:
		return false
	var axis := (global_basis * local_axis).normalized()
	var along := rigid.linear_velocity.dot(axis)
	if absf(along) < minimum_entry_speed:
		return false
	var key := "jump_ring_%d" % get_instance_id()
	var now := Time.get_ticks_msec()
	if now < int(rigid.get_meta(key, 0)):
		return false
	rigid.set_meta(key, now + int(cooldown * 1000.0))
	var exit_speed := clampf(absf(along) * speed_multiplier, minimum_exit_speed, maximum_exit_speed)
	# Sideways drift is halved so the hoop straightens a run onto its lane;
	# upward momentum is kept and topped up so the exit arcs rather than skids.
	var lateral := rigid.linear_velocity - axis * along
	lateral.y = 0.0
	var vertical := maxf(rigid.linear_velocity.y, 0.0) + upward_assist
	rigid.linear_velocity = axis * signf(along) * exit_speed + lateral * 0.5 + Vector3.UP * vertical
	rigid.sleeping = false
	_pulse = 1.0
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null:
		audio.call("play_sfx_limited", &"launch_pad", 0.08, -4.0, 1.18, &"jump_ring")
	return true


func _physics_process(delta: float) -> void:
	_pulse = move_toward(_pulse, 0.0, delta * 5.0)
	if _visual_root != null:
		_visual_root.scale = Vector3.ONE * (1.0 + _pulse * 0.08)
	if _light != null:
		_light.light_energy = glow_energy * (0.55 + _pulse * 1.1)


func _on_body_entered(body: Node3D) -> void:
	activate_body(body)


func _build_model() -> void:
	# TorusMesh and CylinderShape3D both stand on local Y; rotate that onto the hoop axis.
	var orientation := Basis(Quaternion(Vector3.UP, local_axis))
	var trigger := CollisionShape3D.new()
	trigger.name = "RingTrigger"
	var trigger_shape := CylinderShape3D.new()
	trigger_shape.radius = inner_radius * 0.96
	trigger_shape.height = tube_radius * 2.0 + 1.2
	trigger.shape = trigger_shape
	trigger.basis = orientation
	add_child(trigger)
	_visual_root = Node3D.new()
	_visual_root.name = "HoopVisuals"
	_visual_root.basis = orientation
	add_child(_visual_root)
	var casing := MeshInstance3D.new()
	casing.name = "HoopCasing"
	var casing_mesh := TorusMesh.new()
	casing_mesh.inner_radius = inner_radius
	casing_mesh.outer_radius = inner_radius + tube_radius * 2.0
	casing_mesh.rings = 24
	casing_mesh.ring_segments = 48
	casing_mesh.material = _material(Color(0.14, 0.16, 0.2), 0.36, 0.72, 0.0)
	casing.mesh = casing_mesh
	_visual_root.add_child(casing)
	var core := MeshInstance3D.new()
	core.name = "HoopCore"
	var core_mesh := TorusMesh.new()
	core_mesh.inner_radius = inner_radius + tube_radius * 0.5
	core_mesh.outer_radius = inner_radius + tube_radius * 1.5
	core_mesh.rings = 20
	core_mesh.ring_segments = 48
	core_mesh.material = _material(ring_color, 0.24, 0.18, glow_energy)
	core.mesh = core_mesh
	_visual_root.add_child(core)
	for index in range(4):
		var angle := float(index) * PI * 0.5 + PI * 0.25
		var indicator := MeshInstance3D.new()
		indicator.name = "HoopIndicator%d" % (index + 1)
		var indicator_mesh := SphereMesh.new()
		indicator_mesh.radius = tube_radius * 0.9
		indicator_mesh.height = indicator_mesh.radius * 2.0
		indicator_mesh.radial_segments = 12
		indicator_mesh.rings = 8
		indicator_mesh.material = _material(Color(1.0, 0.86, 0.4), 0.3, 0.1, glow_energy * 0.8)
		indicator.mesh = indicator_mesh
		indicator.position = Vector3(cos(angle), 0.0, sin(angle)) * (inner_radius + tube_radius)
		_visual_root.add_child(indicator)
	_light = OmniLight3D.new()
	_light.name = "HoopGlow"
	_light.light_color = ring_color
	_light.light_energy = glow_energy * 0.55
	_light.omni_range = inner_radius * 3.2
	_light.shadow_enabled = false
	add_child(_light)


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
