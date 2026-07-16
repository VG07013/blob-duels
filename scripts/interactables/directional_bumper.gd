class_name DirectionalBumper
extends Area3D

@export var bumper_size := Vector3(11.55, 11.55, 2.31)
@export var impulse_strength := 52.0
@export var fixed_direction := Vector3.ZERO
@export var bumper_color := Color(0.96, 0.08, 0.46)
@export var glow_energy := 2.0
@export var cooldown := 0.22
@export var round_shape := false

var _visual: MeshInstance3D
var _bezel: MeshInstance3D
var _core: MeshInstance3D
var _solid_body: StaticBody3D
var _light: OmniLight3D
var _indicator_leds: Array[MeshInstance3D] = []
var _bezel_segments: Array[MeshInstance3D] = []


func _ready() -> void:
	add_to_group("map_interactable")
	collision_layer = 0
	collision_mask = 2
	monitoring = true
	body_entered.connect(_on_body_entered)
	_build_visuals()


func configure(size_value: Vector3, strength: float, color: Color, direction := Vector3.ZERO, emission := 2.0, use_round_shape := false) -> void:
	bumper_size = size_value
	impulse_strength = maxf(strength, 0.0)
	bumper_color = color
	fixed_direction = direction.normalized() if direction.length_squared() > 0.001 else Vector3.ZERO
	glow_energy = emission
	round_shape = use_round_shape
	if is_node_ready():
		_rebuild()


func get_interaction_kind() -> StringName:
	return &"directional_bumper"


func activate_body(body: Node3D) -> bool:
	var rigid_body := body as RigidBody3D
	if rigid_body == null or rigid_body.freeze:
		return false
	var cooldown_key := "directional_bumper_%d" % get_instance_id()
	var now := Time.get_ticks_msec()
	if now < int(rigid_body.get_meta(cooldown_key, 0)):
		return false
	rigid_body.set_meta(cooldown_key, now + int(cooldown * 1000.0))
	# Fixed directions are authored in local space so a wall pad's visible face, collider,
	# indicator frame, and impulse all rotate together on each arena side.
	var direction := global_basis * fixed_direction
	if direction.length_squared() <= 0.001:
		direction = rigid_body.global_position - global_position
		direction.y = 0.0
	if direction.length_squared() <= 0.001:
		direction = Vector3.FORWARD
	direction = (direction.normalized() + Vector3.UP * 0.24).normalized()
	rigid_body.apply_central_impulse(direction * impulse_strength)
	rigid_body.sleeping = false
	return true


func _on_body_entered(body: Node3D) -> void:
	activate_body(body)


func _build_visuals() -> void:
	_visual = MeshInstance3D.new()
	_visual.name = "BumperHousing"
	add_child(_visual)
	_bezel = MeshInstance3D.new()
	_bezel.name = "BumperBezel"
	add_child(_bezel)
	_core = MeshInstance3D.new()
	_core.name = "BumperCore"
	add_child(_core)
	for index in range(4):
		var segment := MeshInstance3D.new()
		segment.name = "BumperFrameSegment%d" % (index + 1)
		add_child(segment)
		_bezel_segments.append(segment)
	_light = OmniLight3D.new()
	_light.name = "BumperGlow"
	_light.shadow_enabled = false
	add_child(_light)
	for index in range(4):
		var indicator := MeshInstance3D.new()
		indicator.name = "BumperIndicator%d" % (index + 1)
		add_child(indicator)
		_indicator_leds.append(indicator)
	var detection := CollisionShape3D.new()
	detection.name = "DetectionCollision"
	add_child(detection)
	_solid_body = StaticBody3D.new()
	_solid_body.name = "SolidBumper"
	_solid_body.collision_layer = 1
	_solid_body.collision_mask = 2
	add_child(_solid_body)
	var solid_collision := CollisionShape3D.new()
	solid_collision.name = "SolidCollision"
	_solid_body.add_child(solid_collision)
	_rebuild()


func _rebuild() -> void:
	if _visual == null:
		return
	var indicator_radius := 0.0
	if round_shape:
		var radius := maxf(bumper_size.x, bumper_size.z) * 0.5
		indicator_radius = radius
		var housing := CylinderMesh.new()
		housing.top_radius = radius
		housing.bottom_radius = radius
		housing.height = bumper_size.y
		housing.radial_segments = 32
		housing.material = _material(bumper_color.darkened(0.62), 0.3)
		_visual.mesh = housing
		var core_mesh := CylinderMesh.new()
		core_mesh.top_radius = radius * 0.64
		core_mesh.bottom_radius = radius * 0.64
		core_mesh.height = bumper_size.y * 1.12
		core_mesh.radial_segments = 32
		core_mesh.material = _material(bumper_color, glow_energy)
		_core.mesh = core_mesh
		var bezel_mesh := TorusMesh.new()
		bezel_mesh.inner_radius = radius * 0.70
		bezel_mesh.outer_radius = radius * 0.91
		bezel_mesh.rings = 24
		bezel_mesh.ring_segments = 40
		bezel_mesh.material = _material(bumper_color.lightened(0.14), glow_energy * 0.72)
		_bezel.mesh = bezel_mesh
		_bezel.position.y = bumper_size.y * 0.52
		_bezel.visible = true
		for segment in _bezel_segments:
			segment.visible = false
	else:
		var housing := BoxMesh.new()
		housing.size = bumper_size
		housing.material = _material(bumper_color.darkened(0.62), 0.3)
		_visual.mesh = housing
		var core_mesh := BoxMesh.new()
		core_mesh.size = bumper_size * Vector3(0.72, 0.72, 1.12)
		core_mesh.material = _material(bumper_color, glow_energy)
		_core.mesh = core_mesh
		# A real open frame: four separate rails leave the hot core visibly inset rather
		# than covering it with one opaque slab.
		_bezel.visible = false
		var frame_depth := maxf(0.12, bumper_size.z * 0.18)
		var frame_thickness := maxf(0.18, minf(bumper_size.x, bumper_size.y) * 0.13)
		for index in range(_bezel_segments.size()):
			var segment := _bezel_segments[index]
			var segment_mesh := BoxMesh.new()
			segment_mesh.material = _material(bumper_color.lightened(0.12), glow_energy * 0.64)
			if index < 2:
				segment_mesh.size = Vector3(frame_thickness, bumper_size.y * 0.90, frame_depth)
				segment.position = Vector3((-1.0 if index == 0 else 1.0) * bumper_size.x * 0.42, 0.0, bumper_size.z * 0.58)
			else:
				segment_mesh.size = Vector3(bumper_size.x * 0.90, frame_thickness, frame_depth)
				segment.position = Vector3(0.0, (-1.0 if index == 2 else 1.0) * bumper_size.y * 0.42, bumper_size.z * 0.58)
			segment.mesh = segment_mesh
			segment.visible = true
	_rebuild_indicators(indicator_radius)
	if _light != null:
		_light.light_color = bumper_color
		_light.light_energy = maxf(0.5, glow_energy * 0.54)
		_light.omni_range = maxf(bumper_size.x, maxf(bumper_size.y, bumper_size.z)) * 3.0
	for collision in [get_node_or_null("DetectionCollision") as CollisionShape3D, _solid_body.get_node_or_null("SolidCollision") as CollisionShape3D]:
		if collision == null:
			continue
		var detection_scale := 1.12 if collision.name == "DetectionCollision" else 1.0
		var shape: Shape3D
		if round_shape:
			var cylinder_shape := CylinderShape3D.new()
			cylinder_shape.radius = maxf(bumper_size.x, bumper_size.z) * 0.5 * detection_scale
			cylinder_shape.height = bumper_size.y * detection_scale
			shape = cylinder_shape
		else:
			var box_shape := BoxShape3D.new()
			box_shape.size = bumper_size * detection_scale
			shape = box_shape
		collision.shape = shape


func _rebuild_indicators(round_radius: float) -> void:
	for index in range(_indicator_leds.size()):
		var indicator := _indicator_leds[index]
		var mesh := SphereMesh.new()
		mesh.radius = maxf(0.18, minf(bumper_size.x, minf(bumper_size.y, bumper_size.z)) * 0.075)
		mesh.height = mesh.radius * 2.0
		mesh.radial_segments = 12
		mesh.rings = 8
		mesh.material = _material(Color(1.0, 0.84, 0.38), glow_energy * 0.76)
		indicator.mesh = mesh
		var angle := float(index) * PI * 0.5 + PI * 0.25
		if round_shape:
			indicator.position = Vector3(cos(angle), 0.0, sin(angle)) * round_radius * 0.78 + Vector3.UP * bumper_size.y * 0.56
		else:
			var x_sign := -1.0 if index == 0 or index == 3 else 1.0
			var y_sign := -1.0 if index < 2 else 1.0
			indicator.position = Vector3(bumper_size.x * 0.27 * x_sign, bumper_size.y * 0.27 * y_sign, bumper_size.z * 0.58)


func _material(color: Color, emission: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.28
	material.metallic = 0.42
	material.emission_enabled = emission > 0.0
	material.emission = color
	material.emission_energy_multiplier = emission
	return material
