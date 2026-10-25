class_name LobbyRoom
extends Node3D

const ROOM_RADIUS := 40.0
const WALL_HEIGHT := 24.0
const WALL_SEGMENTS := 32
const TEXTURE_NORMALS := preload("res://scripts/environment/texture_normal_library.gd")
const BLOB_MATERIAL_KIT := preload("res://scripts/blob_material_kit.gd")
const CONCRETE_TEXTURE: Texture2D = preload("res://assets/textures/concrete.png")
const WOOD_GRAIN_TEXTURE: Texture2D = preload("res://assets/environment/textures/wood_grain.svg")
const PAINTED_PANELS_TEXTURE: Texture2D = preload("res://assets/environment/textures/painted_panels.svg")
const FABRIC_WEAVE_TEXTURE: Texture2D = preload("res://assets/environment/textures/fabric_weave.svg")
const ASSET_LIBRARY := preload("res://scripts/environment/environment_asset_library.gd")
const GRADIENT_SURFACE_SHADER: Shader = preload("res://assets/materials/gradient_surface.gdshader")

@onready var room: StaticBody3D = $Room
@onready var join_pad: Area3D = $JoinPad

var _wood_light: StandardMaterial3D
var _wood_mid: StandardMaterial3D
var _wood_dark: StandardMaterial3D
var _floor_material: Material
var _ceiling_material: StandardMaterial3D
var _join_material: StandardMaterial3D
var _accent_materials: Array[StandardMaterial3D] = []
var _interior_shell: Node3D
var _ambient_motion: Node3D
var _elapsed := 0.0
var _accent_lights: Array[OmniLight3D] = []


func _ready() -> void:
	var room_physics := PhysicsMaterial.new()
	room_physics.friction = 0.16
	room_physics.bounce = 0.94
	room.physics_material_override = room_physics
	_interior_shell = Node3D.new()
	_interior_shell.name = "InteriorShell"
	add_child(_interior_shell)
	_build_materials()
	_build_floor_and_ceiling()
	_build_round_walls()
	_build_interior_architecture()
	_build_join_pad()
	_build_obstacles()
	_build_champion_trophy()
	_build_furnished_bays()
	_build_signage()
	_build_lighting()
	_build_ambient_motion()


func _process(delta: float) -> void:
	_elapsed += delta
	var fan := _interior_shell.get_node_or_null("LobbyCeilingFan") as Node3D
	if fan != null:
		fan.rotation.y = _elapsed * 1.1
	var halo := room.get_node_or_null("TrophyHalo") as Node3D
	if halo != null:
		halo.rotation.y = _elapsed * 0.9
		halo.position.y = 5.05 + sin(_elapsed * 1.3) * 0.12
	for child in _ambient_motion.get_children():
		var animated := child as Node3D
		var phase := float(animated.get_meta("phase", 0.0))
		animated.rotation.y = sin(_elapsed * 0.38 + phase) * 0.16
		var base_position := animated.get_meta("base_position", animated.position) as Vector3
		animated.position = base_position + Vector3.UP * sin(_elapsed * 0.9 + phase) * 0.22
	for light in _accent_lights:
		var phase := float(light.get_meta("phase", 0.0))
		light.light_energy = 1.65 + sin(_elapsed * 1.15 + phase) * 0.22
	_join_material.emission_energy_multiplier = 1.85 + sin(_elapsed * 1.7) * 0.28


func _build_materials() -> void:
	_wood_light = _textured_material(WOOD_GRAIN_TEXTURE, Color(0.75, 0.5, 0.26), 0.84, 4.0)
	_wood_mid = _textured_material(WOOD_GRAIN_TEXTURE, Color(0.5, 0.27, 0.11), 0.9, 4.0)
	_wood_dark = _textured_material(WOOD_GRAIN_TEXTURE, Color(0.25, 0.1, 0.035), 0.96, 4.0)
	_floor_material = _gradient_material(CONCRETE_TEXTURE, Color(0.16, 0.24, 0.32), Color(0.54, 0.63, 0.68), 12.0, 0.86, 0.04)
	_ceiling_material = _textured_material(PAINTED_PANELS_TEXTURE, Color(0.19, 0.23, 0.28), 0.82, 7.0)
	_join_material = _emissive_material(Color(0.1, 0.88, 0.56), 1.7)
	_accent_materials.clear()
	_accent_materials.append(_material(Color(0.12, 0.56, 0.92), 0.64))
	_accent_materials.append(_material(Color(0.94, 0.31, 0.28), 0.66))
	_accent_materials.append(_material(Color(1.0, 0.7, 0.16), 0.68))
	_accent_materials.append(_material(Color(0.52, 0.3, 0.86), 0.64))
	_accent_materials.append(_material(Color(0.08, 0.68, 0.58), 0.66))


func _build_floor_and_ceiling() -> void:
	_add_cylinder(room, "Floor", Vector3(0, -0.6, 0), ROOM_RADIUS, 1.2, _floor_material, true)
	_add_cylinder(room, "Ceiling", Vector3(0, WALL_HEIGHT + 0.55, 0), ROOM_RADIUS, 1.1, _ceiling_material, true)

	# Concentric bands break up the floor and guide the player toward the center.
	for ring_index in range(3):
		var ring_radius := 8.5 + float(ring_index) * 5.2
		_add_cylinder(room, "FloorBand_%d" % ring_index, Vector3(0, 0.065 - ring_index * 0.012, 0), ring_radius, 0.07, _accent_materials[ring_index], false)


func _build_round_walls() -> void:
	var chord_width := TAU * (ROOM_RADIUS - 0.8) / float(WALL_SEGMENTS) + 0.34
	for index in range(WALL_SEGMENTS):
		var angle := TAU * float(index) / float(WALL_SEGMENTS)
		var position := Vector3(sin(angle) * (ROOM_RADIUS - 0.8), WALL_HEIGHT * 0.5, cos(angle) * (ROOM_RADIUS - 0.8))
		var rotation := Vector3(0, angle, 0)
		var panel_material := _wood_light if index % 3 == 0 else (_wood_mid if index % 3 == 1 else _wood_dark)
		_add_box(room, "Wall_%02d" % index, position, Vector3(chord_width, WALL_HEIGHT, 1.7), panel_material, true, rotation)

		# Horizontal trim gives each wooden section visible construction detail.
		for trim_y in [2.8, 7.0, 11.2, 15.4, 19.2]:
			var trim_position := Vector3(position.x, trim_y, position.z) - Vector3(sin(angle), 0, cos(angle)) * 0.91
			_add_box(room, "WallTrim_%02d" % index, trim_position, Vector3(chord_width - 0.22, 0.18, 0.14), _wood_dark, false, rotation)


func _build_interior_architecture() -> void:
	# A second visual layer creates a deliberate interior instead of an arena platform in open space.
	for index in range(12):
		var angle := TAU * float(index) / 12.0
		var inward := Vector3(-sin(angle), 0, -cos(angle))
		var position := Vector3(sin(angle) * 37.5, 11.5, cos(angle) * 37.5)
		_add_box(_interior_shell, "InteriorPillar_%02d" % index, position, Vector3(1.5, 19.0, 1.5), _accent_materials[index % _accent_materials.size()], false, Vector3(0, angle, 0))
		_add_box(_interior_shell, "WallSconce_%02d" % index, position + inward * 0.95 + Vector3(0, 2.8, 0), Vector3(1.1, 2.4, 0.38), _join_material, false, Vector3(0, angle, 0))
	for index in range(6):
		var angle := TAU * float(index) / 6.0
		var beam_position := Vector3(sin(angle) * 16.0, WALL_HEIGHT - 1.1, cos(angle) * 16.0)
		_add_box(_interior_shell, "CeilingBeam_%02d" % index, beam_position, Vector3(2.0, 1.0, 32.0), _wood_dark, false, Vector3(0, angle, 0))


func _build_furnished_bays() -> void:
	var props := [
		["lobby_sofa", -2.6, 4.6], ["lobby_table", -2.1, 4.3], ["lobby_lamp", -1.6, 4.2],
		["lobby_bookcase", -1.05, 4.6], ["lobby_books", -0.72, 4.4], ["lobby_chair", -0.35, 4.6],
		["lobby_tv", 0.05, 4.7], ["lobby_speaker", 0.42, 4.3], ["lobby_bench", 0.78, 4.5],
		["lobby_plant", 1.15, 4.7], ["lobby_coat_rack", 1.52, 4.4], ["lobby_bear", 1.88, 4.5],
		["lobby_sofa", 2.25, 4.6], ["lobby_chair", 2.62, 4.6], ["lobby_rug", 2.95, 4.8],
	]
	for index in range(props.size()):
		var data: Array = props[index]
		var model_id: String = data[0]
		var angle: float = data[1]
		var model_scale: float = data[2]
		var root := ASSET_LIBRARY.instantiate_model(model_id)
		if root == null:
			continue
		root.name = "LobbyProp_%02d_%s" % [index, model_id]
		root.position = Vector3(sin(angle) * 31.5, 0.08, cos(angle) * 31.5)
		root.rotation.y = angle + PI
		root.scale = Vector3.ONE * model_scale
		_interior_shell.add_child(root)
	var fan := ASSET_LIBRARY.instantiate_model("lobby_fan")
	if fan != null:
		fan.name = "LobbyCeilingFan"
		fan.position = Vector3(0, WALL_HEIGHT - 2.0, 0)
		fan.scale = Vector3.ONE * 4.2
		fan.add_to_group("animated_lobby_prop")
		_interior_shell.add_child(fan)


func _build_join_pad() -> void:
	_add_cylinder(join_pad, "Pad", Vector3(0, 0.24, 0), 6.2, 0.48, _join_material, true)
	_add_cylinder(join_pad, "PadCore", Vector3(0, 0.51, 0), 4.7, 0.08, _emissive_material(Color(0.32, 1.0, 0.72), 2.4), false)
	for index in range(12):
		var angle := TAU * float(index) / 12.0
		var marker_position := Vector3(sin(angle) * 5.45, 0.62, cos(angle) * 5.45)
		_add_sphere(join_pad, "PadMarker_%02d" % index, marker_position, 0.22, _accent_materials[index % _accent_materials.size()])


func _build_obstacles() -> void:
	var obstacle_data := [
		[Vector3(-13.5, 1.5, 7.0), Vector3(4.6, 3.0, 4.6), 0.28],
		[Vector3(13.0, 1.15, 6.2), Vector3(5.2, 2.3, 3.8), -0.35],
		[Vector3(-11.0, 0.85, -11.5), Vector3(3.2, 1.7, 6.0), 0.62],
		[Vector3(12.5, 1.8, -10.0), Vector3(3.8, 3.6, 3.8), -0.18],
	]
	for index in range(obstacle_data.size()):
		var data: Array = obstacle_data[index]
		var obstacle_position: Vector3 = data[0]
		var obstacle_size: Vector3 = data[1]
		var obstacle_yaw: float = data[2]
		_add_box(room, "ColorCrate_%02d" % index, obstacle_position, obstacle_size, _accent_materials[index], true, Vector3(0, obstacle_yaw, 0))
		_add_box(room, "CrateCap_%02d" % index, obstacle_position + Vector3(0, obstacle_size.y * 0.5 + 0.09, 0), Vector3(obstacle_size.x + 0.2, 0.18, obstacle_size.z + 0.2), _wood_light, false, Vector3(0, obstacle_yaw, 0))

	for index in range(6):
		var angle := TAU * float(index) / 6.0 + 0.35
		var position := Vector3(sin(angle) * 27.5, 1.2, cos(angle) * 27.5)
		_add_cylinder(room, "ColorPost_%02d" % index, position, 0.9, 2.4, _accent_materials[(index + 2) % _accent_materials.size()], true)


## Hero centerpiece: a golden champion-blob statue on a lit plinth at the back
## of the lobby. Built in the arena material layers - dark base, inset recess,
## emissive trim, bright core - so it reads as a monument, not a colored box.
func _build_champion_trophy() -> void:
	var base_z := -22.0
	var gold := _material(Color(0.94, 0.76, 0.28), 0.24)
	gold.metallic = 0.92
	gold.emission_enabled = true
	gold.emission = Color(0.9, 0.62, 0.16)
	gold.emission_energy_multiplier = 0.22
	var dark_base := _material(Color(0.08, 0.09, 0.12), 0.42)
	dark_base.metallic = 0.55
	var recess := _material(Color(0.035, 0.04, 0.055), 0.6)
	var face_dark := _material(Color(0.03, 0.04, 0.06), 0.35)
	_add_cylinder(room, "TrophyPlinth", Vector3(0, 0.3, base_z), 2.35, 0.6, dark_base, true)
	_add_cylinder(room, "TrophyStep", Vector3(0, 0.75, base_z), 1.95, 0.3, dark_base, false)
	_add_cylinder(room, "TrophyRecess", Vector3(0, 1.02, base_z), 1.58, 0.24, recess, false)
	_add_cylinder(room, "TrophyTrim", Vector3(0, 1.02, base_z), 1.62, 0.06, _emissive_material(Color(0.3, 0.95, 0.85), 2.2), false)
	_add_cylinder(room, "TrophyColumn", Vector3(0, 1.7, base_z), 1.28, 1.15, dark_base, false)
	_add_cylinder(room, "TrophyCap", Vector3(0, 2.4, base_z), 1.72, 0.26, gold, false)
	var blob := MeshInstance3D.new()
	blob.name = "TrophyBlob"
	var blob_mesh := SphereMesh.new()
	blob_mesh.radius = 1.25
	blob_mesh.height = 2.5
	blob_mesh.radial_segments = 48
	blob_mesh.rings = 24
	blob.mesh = blob_mesh
	blob.material_override = BLOB_MATERIAL_KIT.decorate(gold.duplicate() as StandardMaterial3D, Color(0.94, 0.76, 0.28))
	blob.position = Vector3(0, 3.6, base_z)
	blob.scale = Vector3(1.0, 0.86, 1.0)
	room.add_child(blob)
	_add_sphere(room, "TrophyEyeLeft", Vector3(-0.42, 3.92, base_z + 1.06), 0.14, face_dark)
	_add_sphere(room, "TrophyEyeRight", Vector3(0.42, 3.92, base_z + 1.06), 0.14, face_dark)
	_add_box(room, "TrophySmile", Vector3(0, 3.34, base_z + 1.14), Vector3(0.55, 0.1, 0.1), face_dark, false)
	var halo := Node3D.new()
	halo.name = "TrophyHalo"
	halo.position = Vector3(0, 5.05, base_z)
	halo.add_to_group("animated_lobby_prop")
	room.add_child(halo)
	var halo_mesh := MeshInstance3D.new()
	halo_mesh.name = "Ring"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.72
	torus.outer_radius = 0.95
	halo_mesh.mesh = torus
	halo_mesh.material_override = _emissive_material(Color(1.0, 0.82, 0.34), 1.7)
	halo.add_child(halo_mesh)
	var glow := OmniLight3D.new()
	glow.name = "TrophyGlow"
	glow.position = Vector3(0, 4.4, base_z + 1.6)
	glow.light_color = Color(1.0, 0.8, 0.42)
	glow.light_energy = 0.9
	glow.omni_range = 9.0
	glow.shadow_enabled = false
	glow.add_to_group("presentation_light")
	room.add_child(glow)
	var plaque := Label3D.new()
	plaque.name = "TrophyPlaque"
	plaque.position = Vector3(0, 6.3, base_z)
	plaque.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	plaque.text = "CHAMPION"
	plaque.font_size = 44
	plaque.outline_size = 10
	plaque.modulate = Color(1.0, 0.85, 0.42)
	room.add_child(plaque)


func _build_signage() -> void:
	var join_label := Label3D.new()
	join_label.name = "JoinLabel"
	join_label.position = Vector3(0, 5.2, 0)
	join_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	join_label.text = "PLAY"
	join_label.font_size = 76
	join_label.outline_size = 14
	join_label.modulate = Color(0.64, 1.0, 0.84)
	add_child(join_label)

	var hint := Label3D.new()
	hint.name = "JoinHint"
	hint.position = Vector3(0, 3.55, 0)
	hint.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	hint.text = "ROLL ONTO THE PAD TO CHOOSE A MODE"
	hint.font_size = 34
	hint.outline_size = 9
	hint.modulate = Color(0.84, 0.91, 0.96)
	add_child(hint)


func _build_lighting() -> void:
	var center_light := OmniLight3D.new()
	center_light.name = "CenterLight"
	center_light.position = Vector3(0, 7.4, 0)
	center_light.light_color = Color(1.0, 0.82, 0.64)
	center_light.light_energy = 4.2
	center_light.omni_range = 34.0
	center_light.shadow_enabled = true
	center_light.add_to_group("presentation_light")
	add_child(center_light)

	for index in range(5):
		var angle := TAU * float(index) / 5.0
		var light := OmniLight3D.new()
		light.name = "AccentLight_%02d" % index
		light.position = Vector3(sin(angle) * 28.0, 3.2, cos(angle) * 28.0)
		light.light_color = _accent_materials[index].albedo_color
		light.light_energy = 1.8
		light.omni_range = 12.0
		light.shadow_enabled = false
		light.set_meta("phase", float(index) * 1.2)
		light.add_to_group("presentation_light")
		add_child(light)
		_accent_lights.append(light)


func _build_ambient_motion() -> void:
	_ambient_motion = Node3D.new()
	_ambient_motion.name = "AmbientMotion"
	add_child(_ambient_motion)
	for index in range(8):
		var angle := TAU * float(index) / 8.0 + 0.2
		var pendant := Node3D.new()
		pendant.name = "ColorPendant_%02d" % index
		pendant.position = Vector3(sin(angle) * 22.0, WALL_HEIGHT - 3.2, cos(angle) * 22.0)
		pendant.set_meta("base_position", pendant.position)
		pendant.set_meta("phase", float(index) * 0.78)
		pendant.add_to_group("animated_lobby_prop")
		_ambient_motion.add_child(pendant)
		_add_cylinder(pendant, "Cord", Vector3(0, 1.35, 0), 0.07, 2.7, _wood_dark, false)
		var color := _accent_materials[index % _accent_materials.size()].albedo_color
		_add_sphere(pendant, "Glow", Vector3.ZERO, 0.52, _emissive_material(color, 2.0))
		var light := OmniLight3D.new()
		light.name = "PendantLight"
		light.light_color = color
		light.light_energy = 0.55
		light.omni_range = 7.0
		light.shadow_enabled = false
		light.add_to_group("presentation_light")
		pendant.add_child(light)


func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material


func _textured_material(texture: Texture2D, color: Color, roughness: float, tile_scale: float) -> StandardMaterial3D:
	var material := _material(color, roughness)
	material.albedo_texture = texture
	material.uv1_scale = Vector3(tile_scale, tile_scale, tile_scale)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var normal_map := TEXTURE_NORMALS.normal_for(texture)
	if normal_map != null:
		material.normal_enabled = true
		material.normal_texture = normal_map
	return material


func _gradient_material(texture: Texture2D, color_a: Color, color_b: Color, tile_scale: float, roughness: float, emission: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = GRADIENT_SURFACE_SHADER
	material.set_shader_parameter("detail_texture", texture)
	material.set_shader_parameter("color_a", color_a)
	material.set_shader_parameter("color_b", color_b)
	material.set_shader_parameter("gradient_axis", Vector2(0.35, 1.0))
	material.set_shader_parameter("tile_scale", tile_scale)
	material.set_shader_parameter("roughness_value", roughness)
	material.set_shader_parameter("metallic_value", 0.05)
	material.set_shader_parameter("emission_strength", emission)
	var normal_map := TEXTURE_NORMALS.normal_for(texture)
	if normal_map != null:
		material.set_shader_parameter("detail_normal", normal_map)
		material.set_shader_parameter("normal_strength", 0.55)
	return material


func _emissive_material(color: Color, energy: float) -> StandardMaterial3D:
	var material := _material(color, 0.35)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material


func _add_box(parent: Node3D, node_name: String, position: Vector3, size: Vector3, material: Material, with_collision: bool, rotation: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = position
	instance.rotation = rotation
	instance.mesh = mesh
	instance.material_override = material
	parent.add_child(instance)
	if with_collision:
		var shape := BoxShape3D.new()
		shape.size = size
		_add_collision(parent, node_name + "Collision", position, rotation, shape)
	return instance


func _add_cylinder(parent: Node3D, node_name: String, position: Vector3, radius: float, height: float, material: Material, with_collision: bool) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 64
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = position
	instance.mesh = mesh
	instance.material_override = material
	parent.add_child(instance)
	if with_collision:
		var shape := CylinderShape3D.new()
		shape.radius = radius
		shape.height = height
		_add_collision(parent, node_name + "Collision", position, Vector3.ZERO, shape)
	return instance


func _add_sphere(parent: Node3D, node_name: String, position: Vector3, radius: float, material: Material) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = position
	instance.mesh = mesh
	instance.material_override = material
	parent.add_child(instance)


func _add_collision(parent: Node3D, node_name: String, position: Vector3, rotation: Vector3, shape: Shape3D) -> void:
	var collision := CollisionShape3D.new()
	collision.name = node_name
	collision.position = position
	collision.rotation = rotation
	collision.shape = shape
	parent.add_child(collision)
