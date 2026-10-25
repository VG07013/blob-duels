class_name EnvironmentPresentation
extends Node3D

const DISPLAY_SHADER: Shader = preload("res://assets/materials/hologram_display.gdshader")
const ASSET_LIBRARY := preload("res://scripts/environment/environment_asset_library.gd")

const THEME_PRIMARY := [
	Color(0.02, 0.82, 0.94), Color(0.2, 0.72, 0.34), Color(1.0, 0.44, 0.08),
	Color(0.32, 0.72, 1.0), Color(1.0, 0.7, 0.1),
]
const THEME_SECONDARY := [
	Color(0.96, 0.08, 0.48), Color(1.0, 0.68, 0.18), Color(0.12, 0.58, 0.96),
	Color(0.88, 0.7, 0.22), Color(0.96, 0.18, 0.3),
]
const THEME_MESSAGES := [
	["READY PLAYER", "COMBO ROUTE ONLINE", "FLING METER: HOT", "BONUS ROUND"],
	["BACKYARD BASH", "WIND: PLAYFUL", "GARDEN ROUTE OPEN", "WATCH THE RAMPS"],
	["DUEL SYSTEM LIVE", "FACTORY FLOOR ACTIVE", "IMPACT LEVEL: HIGH", "RED  VS  BLUE"],
	["TEMPLE PATH OPEN", "SKY CURRENT RISING", "ANCIENT GATE ACTIVE", "BOUNCE WITH HONOR"],
	["TOYBOX TURBO", "TRACK SWITCH ACTIVE", "BIG AIR READY", "PLAY NICE. HIT HARD."],
]

var _theme_id := 0
var _half_width := 40.0
var _half_length := 120.0
var _elapsed := 0.0
var _display_elapsed := 0.0
var _ambient_audio_elapsed := 0.0
var _display_cursor := 0
var _motion_root: Node3D
var _display_root: Node3D
var _vfx_root: Node3D
var _light_root: Node3D
var _animated_nodes: Array[Node3D] = []
var _vfx_nodes: Array[Node3D] = []
var _accent_lights: Array[OmniLight3D] = []


func configure(theme_id: int, half_width: float, half_length: float) -> void:
	_theme_id = clampi(theme_id, 0, THEME_PRIMARY.size() - 1)
	_half_width = half_width
	_half_length = half_length
	name = "Presentation"


func _ready() -> void:
	_create_roots()
	_build_displays()
	_build_accent_lights()
	_build_ambient_vfx()
	_build_theme_motion()


func _process(delta: float) -> void:
	_elapsed += delta
	_display_elapsed += delta
	_ambient_audio_elapsed += delta
	_update_motion()
	_update_lights()
	if _display_elapsed >= 2.8:
		_display_elapsed = 0.0
		_display_cursor = (_display_cursor + 1) % (THEME_MESSAGES[_theme_id] as Array).size()
		_update_display_copy()
		_play_world_sfx(&"display_chirp", -21.0, 0.92 + _theme_id * 0.045, &"presentation_display")
	if _ambient_audio_elapsed >= 6.4:
		_ambient_audio_elapsed = 0.0
		var ambience_key := &"machinery_pulse" if _theme_id == 2 else &"ambient_sparkle"
		_play_world_sfx(ambience_key, -24.0 if _theme_id != 2 else -20.0, 0.88 + _theme_id * 0.05, &"presentation_ambience")


func _create_roots() -> void:
	_motion_root = Node3D.new()
	_motion_root.name = "AmbientMotion"
	add_child(_motion_root)
	_display_root = Node3D.new()
	_display_root.name = "LiveDisplays"
	add_child(_display_root)
	_vfx_root = Node3D.new()
	_vfx_root.name = "AmbientVFX"
	add_child(_vfx_root)
	_light_root = Node3D.new()
	_light_root.name = "AccentLights"
	add_child(_light_root)


func _build_displays() -> void:
	_add_display("CenterDisplay", Vector3(0, 20.0, 0), Vector3(20.0, 7.0, 0.55), 0)
	_add_display("NorthDisplay", Vector3(0, 18.5, -_half_length * 0.6), Vector3(18.0, 6.4, 0.55), 1)
	_add_display("SouthDisplay", Vector3(0, 18.5, _half_length * 0.6), Vector3(18.0, 6.4, 0.55), 2)
	_update_display_copy()


func _add_display(node_name: String, position: Vector3, panel_size: Vector3, message_offset: int) -> void:
	var root := Node3D.new()
	root.name = node_name
	root.position = position
	root.set_meta("message_offset", message_offset)
	root.add_to_group("world_display")
	_display_root.add_child(root)

	var panel := MeshInstance3D.new()
	panel.name = "AnimatedPanel"
	var panel_mesh := BoxMesh.new()
	panel_mesh.size = panel_size
	panel.mesh = panel_mesh
	panel.material_override = _display_material(message_offset)
	root.add_child(panel)

	var frame_material := _emissive_material(THEME_PRIMARY[_theme_id], 1.35)
	var horizontal := panel_size.x > panel_size.z
	if horizontal:
		_add_box(root, "FrameTop", Vector3(0, panel_size.y * 0.5 + 0.28, 0), Vector3(panel_size.x + 0.9, 0.42, panel_size.z + 0.4), frame_material)
		_add_box(root, "FrameBottom", Vector3(0, -panel_size.y * 0.5 - 0.28, 0), Vector3(panel_size.x + 0.9, 0.42, panel_size.z + 0.4), frame_material)
	else:
		_add_box(root, "FrameTop", Vector3(0, panel_size.y * 0.5 + 0.28, 0), Vector3(panel_size.x + 0.4, 0.42, panel_size.z + 0.9), frame_material)
		_add_box(root, "FrameBottom", Vector3(0, -panel_size.y * 0.5 - 0.28, 0), Vector3(panel_size.x + 0.4, 0.42, panel_size.z + 0.9), frame_material)

	var label := Label3D.new()
	label.name = "Message"
	label.position = Vector3(0, 0.5, panel_size.z * 0.5 + 0.06)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 64
	label.pixel_size = 0.04
	label.outline_size = 12
	label.modulate = Color(0.94, 0.98, 1.0)
	root.add_child(label)
	var label_back := label.duplicate() as Label3D
	label_back.name = "MessageBack"
	label_back.position.z = -label.position.z
	root.add_child(label_back)
	var sublabel := Label3D.new()
	sublabel.name = "Status"
	sublabel.position = Vector3(0, -1.55, panel_size.z * 0.5 + 0.07)
	sublabel.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sublabel.font_size = 34
	sublabel.pixel_size = 0.032
	sublabel.outline_size = 8
	sublabel.modulate = THEME_SECONDARY[_theme_id].lightened(0.2)
	sublabel.text = "LIVE  //  BLOB DUELS"
	root.add_child(sublabel)
	var sublabel_back := sublabel.duplicate() as Label3D
	sublabel_back.name = "StatusBack"
	sublabel_back.position.z = -sublabel.position.z
	root.add_child(sublabel_back)


func _update_display_copy() -> void:
	var messages := THEME_MESSAGES[_theme_id] as Array
	for child in _display_root.get_children():
		var offset := int(child.get_meta("message_offset", 0))
		var copy := String(messages[(_display_cursor + offset) % messages.size()])
		for label_name in ["Message", "MessageBack"]:
			var label := child.get_node_or_null(label_name) as Label3D
			if label != null:
				label.text = copy


func _build_accent_lights() -> void:
	var positions := [
		Vector3(-_half_width * 0.58, 10.0, -_half_length * 0.42),
		Vector3(_half_width * 0.58, 10.0, -_half_length * 0.12),
		Vector3(-_half_width * 0.58, 10.0, _half_length * 0.18),
		Vector3(_half_width * 0.58, 10.0, _half_length * 0.46),
	]
	for index in range(positions.size()):
		var light := OmniLight3D.new()
		light.name = "PresentationLight_%02d" % index
		light.position = positions[index]
		light.light_color = THEME_PRIMARY[_theme_id] if index % 2 == 0 else THEME_SECONDARY[_theme_id]
		light.light_energy = 0.7 if _theme_id != 0 else 1.05
		light.omni_range = 20.0
		light.shadow_enabled = false
		light.set_meta("base_energy", light.light_energy)
		light.set_meta("phase", float(index) * 1.4)
		light.add_to_group("presentation_light")
		_light_root.add_child(light)
		_accent_lights.append(light)


func _build_ambient_vfx() -> void:
	var material := _emissive_material(THEME_PRIMARY[_theme_id].lightened(0.12), 1.4 if _theme_id == 0 else 0.7)
	for index in range(12):
		var side := -1.0 if index % 2 == 0 else 1.0
		var progress := float(index) / 11.0
		var mote := _add_sphere(
			_vfx_root,
			"AmbientMote_%02d" % index,
			Vector3(side * _half_width * (0.52 + 0.12 * sin(float(index))), 5.0 + float(index % 4) * 2.0, lerpf(-_half_length * 0.76, _half_length * 0.76, progress)),
			0.18 + float(index % 3) * 0.07,
			material,
		)
		mote.set_meta("motion", "bob")
		mote.set_meta("base_position", mote.position)
		mote.set_meta("amplitude", 0.45 + float(index % 3) * 0.18)
		mote.set_meta("speed", 0.85 + float(index % 4) * 0.17)
		mote.set_meta("phase", float(index) * 0.62)
		mote.add_to_group("ambient_vfx")
		mote.add_to_group("animated_map_prop")
		_vfx_nodes.append(mote)


func _build_theme_motion() -> void:
	match _theme_id:
		0:
			_build_neon_motion()
		1:
			_build_backyard_motion()
		2:
			_build_factory_motion()
		3:
			_build_temple_motion()
		4:
			_build_toy_motion()


func _build_neon_motion() -> void:
	for index in range(3):
		var ring := _add_torus(_motion_root, "HologramRing_%02d" % index, Vector3(0, 9.0 + index * 1.2, 0), 3.8 + index * 1.25, 0.13, _emissive_material(THEME_PRIMARY[_theme_id] if index % 2 == 0 else THEME_SECONDARY[_theme_id], 2.0))
		ring.rotation.x = PI * 0.5 if index % 2 == 0 else 0.35
		_register_spin(ring, Vector3(0.3 if index % 2 else 0.0, 1.0, 0.5), 0.55 + index * 0.22)
	var orb := _add_sphere(_motion_root, "ArcadeCore", Vector3(0, 10.4, 0), 1.35, _emissive_material(Color(1.0, 0.86, 0.16), 2.2))
	_register_bob(orb, 0.75, 1.4, 0.0)


func _build_backyard_motion() -> void:
	for side in [-1.0, 1.0]:
		var windmill := Node3D.new()
		windmill.name = "GardenPinwheel"
		windmill.position = Vector3(side * (_half_width - 7.0), 11.0, side * 28.0)
		_motion_root.add_child(windmill)
		_add_cylinder(windmill, "Pole", Vector3(0, -5.2, 0), 0.28, 10.5, _material(Color(0.48, 0.24, 0.08), 0.82))
		var blades := Node3D.new()
		blades.name = "Blades"
		windmill.add_child(blades)
		for blade_index in range(4):
			var blade_color: Color = (THEME_SECONDARY[_theme_id] as Color).lerp(THEME_PRIMARY[_theme_id] as Color, float(blade_index) / 4.0)
			var blade := _add_box(blades, "Blade_%d" % blade_index, Vector3(0, 2.2, 0), Vector3(1.15, 4.8, 0.32), _material(blade_color, 0.64))
			blade.rotation.z = blade_index * PI * 0.5
		_register_spin(blades, Vector3.FORWARD, 1.25 * side)
	for index in range(3):
		var cloud := _make_cloud(Vector3(-_half_width * 0.45 + index * _half_width * 0.45, 25.0 + index, -_half_length * 0.5 + index * 48.0), 2.4 + index * 0.25)
		cloud.set_meta("motion", "travel_x")
		cloud.set_meta("base_position", cloud.position)
		cloud.set_meta("amplitude", _half_width * 0.7)
		cloud.set_meta("speed", 0.18 + index * 0.04)
		cloud.set_meta("phase", float(index) * 1.7)
		_animated_nodes.append(cloud)


func _build_factory_motion() -> void:
	for index in range(4):
		var piston := Node3D.new()
		piston.name = "FactoryPiston_%02d" % index
		piston.position = Vector3((-1.0 if index % 2 == 0 else 1.0) * (_half_width - 8.0), 5.0, -54.0 + index * 36.0)
		_motion_root.add_child(piston)
		_add_cylinder(piston, "Housing", Vector3.ZERO, 1.7, 5.0, _material(Color(0.16, 0.21, 0.28), 0.38, 0.62))
		_add_cylinder(piston, "Head", Vector3(0, 3.1, 0), 2.4, 1.0, _emissive_material(THEME_SECONDARY[_theme_id], 0.65))
		_register_bob(piston, 1.6, 1.4 + index * 0.12, float(index) * 1.1)
	for index in range(2):
		var beacon := _add_torus(_motion_root, "WarningRotor_%02d" % index, Vector3(0, 13.0, -32.0 + index * 64.0), 4.8, 0.22, _emissive_material(THEME_PRIMARY[_theme_id], 1.7))
		beacon.rotation.x = PI * 0.5
		_register_spin(beacon, Vector3.UP, 1.1 if index == 0 else -1.1)


func _build_temple_motion() -> void:
	for index in range(3):
		var rune := _add_torus(_motion_root, "RuneRing_%02d" % index, Vector3(0, 11.0 + index * 1.2, -36.0 + index * 36.0), 3.2 + index * 0.45, 0.18, _emissive_material(THEME_SECONDARY[_theme_id] if index % 2 else THEME_PRIMARY[_theme_id], 1.35))
		rune.rotation.x = 0.35 + index * 0.42
		_register_spin(rune, Vector3(0.3, 1.0, 0.2), 0.42 + index * 0.18)
		var crystal := _add_sphere(_motion_root, "SkyCrystal_%02d" % index, rune.position, 0.8 + index * 0.16, _emissive_material(Color(0.78, 0.94, 1.0), 1.6))
		_register_bob(crystal, 1.1, 0.8 + index * 0.16, float(index) * 1.3)


func _build_toy_motion() -> void:
	for index in range(2):
		var vehicle := ASSET_LIBRARY.instantiate_model("toy_speedster" if index == 0 else "toy_monster_truck")
		if vehicle == null:
			continue
		vehicle.name = "TrackVehicle_%02d" % index
		vehicle.position = Vector3(-_half_width + 6.0 + index * (_half_width * 2.0 - 12.0), 1.0, 0)
		vehicle.scale = Vector3.ONE * 5.0
		vehicle.rotation.y = 0.0 if index == 0 else PI
		_motion_root.add_child(vehicle)
		vehicle.set_meta("motion", "travel_z")
		vehicle.set_meta("base_position", vehicle.position)
		vehicle.set_meta("amplitude", _half_length * 0.7)
		vehicle.set_meta("speed", 0.34 + index * 0.08)
		vehicle.set_meta("phase", float(index) * PI)
		vehicle.add_to_group("animated_map_prop")
		_animated_nodes.append(vehicle)
	for index in range(2):
		var wheel := _add_torus(_motion_root, "ToySpinner_%02d" % index, Vector3(0, 10.0, -42.0 + index * 84.0), 4.2, 0.36, _emissive_material(THEME_SECONDARY[_theme_id] if index else THEME_PRIMARY[_theme_id], 1.0))
		wheel.rotation.x = PI * 0.5
		_register_spin(wheel, Vector3.UP, 0.8 if index == 0 else -0.8)


func _update_motion() -> void:
	for moving in _animated_nodes:
		var speed := float(moving.get_meta("speed", 1.0))
		var phase := float(moving.get_meta("phase", 0.0))
		match String(moving.get_meta("motion")):
			"spin":
				var axis := moving.get_meta("axis", Vector3.UP) as Vector3
				moving.quaternion = Quaternion(axis.normalized(), _elapsed * speed + phase)
			"bob":
				var base_position := moving.get_meta("base_position", moving.position) as Vector3
				moving.position = base_position + Vector3.UP * sin(_elapsed * speed + phase) * float(moving.get_meta("amplitude", 0.7))
			"travel_x":
				var base_x := moving.get_meta("base_position", moving.position) as Vector3
				moving.position = base_x + Vector3.RIGHT * sin(_elapsed * speed + phase) * float(moving.get_meta("amplitude", 12.0))
			"travel_z":
				var base_z := moving.get_meta("base_position", moving.position) as Vector3
				moving.position = base_z + Vector3.FORWARD * sin(_elapsed * speed + phase) * float(moving.get_meta("amplitude", 30.0))
	for mote in _vfx_nodes:
		var base := mote.get_meta("base_position", mote.position) as Vector3
		var speed := float(mote.get_meta("speed", 1.0))
		var phase := float(mote.get_meta("phase", 0.0))
		mote.position = base + Vector3.UP * sin(_elapsed * speed + phase) * float(mote.get_meta("amplitude", 0.5))


func _update_lights() -> void:
	for light in _accent_lights:
		var base_energy := float(light.get_meta("base_energy", 0.7))
		var phase := float(light.get_meta("phase", 0.0))
		light.light_energy = base_energy * (0.86 + sin(_elapsed * 1.25 + phase) * 0.14)


func _play_world_sfx(key: StringName, volume_db: float, pitch_scale: float, cooldown_group: StringName) -> void:
	var audio_manager := get_node_or_null("/root/AudioManager")
	if audio_manager != null:
		audio_manager.call("play_sfx_limited", key, 2.5, volume_db, pitch_scale, cooldown_group)


func _register_spin(node: Node3D, axis: Vector3, speed: float) -> void:
	node.set_meta("motion", "spin")
	node.set_meta("axis", axis)
	node.set_meta("speed", speed)
	node.set_meta("phase", node.rotation.length())
	node.add_to_group("animated_map_prop")
	_animated_nodes.append(node)


func _register_bob(node: Node3D, amplitude: float, speed: float, phase: float) -> void:
	node.set_meta("motion", "bob")
	node.set_meta("base_position", node.position)
	node.set_meta("amplitude", amplitude)
	node.set_meta("speed", speed)
	node.set_meta("phase", phase)
	node.add_to_group("animated_map_prop")
	_animated_nodes.append(node)


func _make_cloud(position: Vector3, scale_value: float) -> Node3D:
	var cloud := Node3D.new()
	cloud.name = "MovingCloud"
	cloud.position = position
	_motion_root.add_child(cloud)
	var cloud_material := _material(Color(0.91, 0.96, 1.0), 1.0)
	for index in range(5):
		_add_sphere(cloud, "Puff_%02d" % index, Vector3((index - 2) * 1.1, sin(float(index)) * 0.35, 0), scale_value * (0.55 + float(index % 2) * 0.15), cloud_material)
	cloud.add_to_group("animated_map_prop")
	return cloud


func _display_material(offset: int) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = DISPLAY_SHADER
	material.set_shader_parameter("color_a", THEME_PRIMARY[_theme_id].darkened(0.42))
	material.set_shader_parameter("color_b", THEME_SECONDARY[_theme_id].darkened(0.34))
	material.set_shader_parameter("emission_strength", 1.25 if _theme_id != 0 else 1.8)
	material.set_shader_parameter("scan_speed", 0.55 + offset * 0.18)
	return material


func _material(color: Color, roughness: float, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material


func _emissive_material(color: Color, energy: float) -> StandardMaterial3D:
	var material := _material(color.darkened(0.12), 0.34, 0.12)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material


func _add_box(parent: Node3D, node_name: String, position: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = position
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	instance.mesh = mesh
	parent.add_child(instance)
	return instance


func _add_cylinder(parent: Node3D, node_name: String, position: Vector3, radius: float, height: float, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = position
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 24
	mesh.material = material
	instance.mesh = mesh
	parent.add_child(instance)
	return instance


func _add_sphere(parent: Node3D, node_name: String, position: Vector3, radius: float, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = position
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	mesh.material = material
	instance.mesh = mesh
	parent.add_child(instance)
	return instance


func _add_torus(parent: Node3D, node_name: String, position: Vector3, outer_radius: float, inner_radius: float, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = position
	var mesh := TorusMesh.new()
	mesh.outer_radius = outer_radius
	mesh.inner_radius = inner_radius
	mesh.rings = 18
	mesh.ring_segments = 32
	mesh.material = material
	instance.mesh = mesh
	parent.add_child(instance)
	return instance
