class_name CompetitiveArena
extends Node3D

const BUILDER_SCRIPTS := [
	preload("res://scripts/environment/neon_arcade_builder.gd"),
	preload("res://scripts/environment/backyard_builder.gd"),
	preload("res://scripts/environment/arena_blueprint_builder.gd"),
	preload("res://scripts/environment/sky_temple_builder.gd"),
	preload("res://scripts/environment/toybox_builder.gd"),
]
const MODELS_SCRIPT := preload("res://scripts/environment/arena_models.gd")
const ASSET_LIBRARY := preload("res://scripts/environment/environment_asset_library.gd")
const ENVIRONMENT_ART := preload("res://scripts/environment/environment_art.gd")
const ENVIRONMENT_PRESENTATION := preload("res://scripts/environment/environment_presentation.gd")
const LAUNCH_PAD_SCENE := preload("res://scenes/interactables/launch_pad.tscn")
const WIND_ZONE_SCENE := preload("res://scenes/interactables/wind_zone.tscn")
const MOVING_PLATFORM_SCENE := preload("res://scenes/interactables/moving_platform.tscn")
const ROTATING_BUMPER_SCENE := preload("res://scenes/interactables/rotating_bumper.tscn")
const CONVEYOR_SCENE := preload("res://scenes/interactables/conveyor.tscn")
const DIRECTIONAL_BUMPER_SCRIPT := preload("res://scripts/interactables/directional_bumper.gd")
const LASER_GATE_SCRIPT := preload("res://scripts/interactables/laser_gate.gd")
const NORMAL_SURFACE: PhysicsMaterial = preload("res://assets/materials/physics/arena_normal.tres")
const BOUNCE_SURFACE: PhysicsMaterial = preload("res://assets/materials/physics/arena_bounce.tres")
const GRIP_SURFACE: PhysicsMaterial = preload("res://assets/materials/physics/arena_grip.tres")
const ICE_SURFACE: PhysicsMaterial = preload("res://assets/materials/physics/arena_ice.tres")
const AUTO_MODEL_COLLISION_BASE := {
	"arcade_machine": {"size": Vector3(1.55, 2.2, 1.25), "offset": Vector3(0, 1.1, 0)},
	"arcade_claw": {"size": Vector3(1.55, 2.35, 1.45), "offset": Vector3(0, 1.18, 0)},
	"arcade_pinball": {"size": Vector3(1.45, 1.35, 1.7), "offset": Vector3(0, 0.68, 0)},
	"arcade_dance": {"size": Vector3(1.65, 1.45, 1.45), "offset": Vector3(0, 0.72, 0)},
	"arcade_air_hockey": {"size": Vector3(1.9, 1.0, 1.35), "offset": Vector3(0, 0.5, 0)},
	"arcade_basketball": {"size": Vector3(1.55, 2.2, 1.35), "offset": Vector3(0, 1.1, 0)},
	"arcade_ticket": {"size": Vector3(1.5, 2.0, 1.25), "offset": Vector3(0, 1.0, 0)},
	"arcade_vending": {"size": Vector3(1.55, 2.3, 1.25), "offset": Vector3(0, 1.15, 0)},
	"arcade_prize_wheel": {"size": Vector3(1.65, 2.1, 1.35), "offset": Vector3(0, 1.05, 0)},
	"arcade_prizes": {"size": Vector3(1.65, 1.65, 1.65), "offset": Vector3(0, 0.82, 0)},
	"suburban_house_a": {"size": Vector3(2.35, 1.85, 2.1), "offset": Vector3(0, 0.92, 0)},
	"suburban_house_c": {"size": Vector3(2.35, 1.85, 2.1), "offset": Vector3(0, 0.92, 0)},
	"suburban_house_f": {"size": Vector3(2.35, 1.9, 2.2), "offset": Vector3(0, 0.95, 0)},
	"suburban_house_k": {"size": Vector3(2.35, 1.9, 2.2), "offset": Vector3(0, 0.95, 0)},
	"suburban_planter": {"size": Vector3(1.15, 0.9, 1.15), "offset": Vector3(0, 0.45, 0)},
	"suburban_tree_large": {"size": Vector3(0.9, 2.0, 0.9), "offset": Vector3(0, 1.0, 0)},
	"suburban_tree_small": {"size": Vector3(0.7, 1.5, 0.7), "offset": Vector3(0, 0.75, 0)},
	"suburban_fence": {"size": Vector3(2.1, 1.05, 0.28), "offset": Vector3(0, 0.52, 0)},
	"suburban_stones": {"size": Vector3(1.3, 0.3, 1.15), "offset": Vector3(0, 0.15, 0)},
	"factory_machine": {"size": Vector3(1.9, 1.55, 1.55), "offset": Vector3(0, 0.78, 0)},
	"factory_machine_fortified": {"size": Vector3(2.3, 1.6, 1.6), "offset": Vector3(0, 0.8, 0)},
	"factory_robot_a": {"size": Vector3(1.25, 1.9, 1.25), "offset": Vector3(0, 0.95, 0)},
	"factory_robot_b": {"size": Vector3(1.25, 1.9, 1.25), "offset": Vector3(0, 0.95, 0)},
	"factory_crane": {"size": Vector3(1.8, 2.8, 1.8), "offset": Vector3(0, 1.4, 0)},
	"factory_crane_magnet": {"size": Vector3(1.8, 2.8, 1.8), "offset": Vector3(0, 1.4, 0)},
	"factory_piston": {"size": Vector3(1.45, 1.8, 1.45), "offset": Vector3(0, 0.9, 0)},
	"factory_cog_a": {"size": Vector3(1.55, 1.55, 0.35), "offset": Vector3(0, 0, 0)},
	"factory_cog_c": {"size": Vector3(1.55, 1.55, 0.35), "offset": Vector3(0, 0, 0)},
	"factory_screen": {"size": Vector3(2.0, 1.65, 0.45), "offset": Vector3(0, 0.82, 0)},
	"factory_catwalk_stairs": {"size": Vector3(2.0, 1.4, 1.8), "offset": Vector3(0, 0.7, 0)},
	"factory_structure": {"size": Vector3(1.8, 2.4, 1.8), "offset": Vector3(0, 1.2, 0)},
	"building_wall_window": {"size": Vector3(2.1, 1.8, 0.35), "offset": Vector3(0, 0.9, 0)},
	"building_plating": {"size": Vector3(2.2, 1.7, 0.3), "offset": Vector3(0, 0.85, 0)},
	"temple_gate": {"size": Vector3(2.6, 2.5, 0.55), "offset": Vector3(0, 1.25, 0)},
	"temple_gate_bars": {"size": Vector3(2.6, 2.5, 0.55), "offset": Vector3(0, 1.25, 0)},
	"temple_wall_detail": {"size": Vector3(2.0, 1.75, 0.35), "offset": Vector3(0, 0.88, 0)},
	"temple_stairs": {"size": Vector3(2.2, 0.8, 2.1), "offset": Vector3(0, 0.4, 0)},
	"nature_statue_column": {"size": Vector3(1.05, 2.25, 1.05), "offset": Vector3(0, 1.12, 0)},
	"nature_statue_damaged": {"size": Vector3(1.05, 1.9, 1.05), "offset": Vector3(0, 0.95, 0)},
	"nature_obelisk": {"size": Vector3(0.9, 2.3, 0.9), "offset": Vector3(0, 1.15, 0)},
	"nature_statue_head": {"size": Vector3(1.1, 0.9, 1.1), "offset": Vector3(0, 0.45, 0)},
	"nature_rock": {"size": Vector3(1.25, 0.85, 1.25), "offset": Vector3(0, 0.42, 0)},
	"nature_pot": {"size": Vector3(1.0, 1.0, 1.0), "offset": Vector3(0, 0.5, 0)},
	"toy_racer": {"size": Vector3(1.8, 0.9, 2.25), "offset": Vector3(0, 0.45, 0)},
	"toy_vintage_racer": {"size": Vector3(1.8, 0.9, 2.25), "offset": Vector3(0, 0.45, 0)},
	"toy_monster_truck": {"size": Vector3(1.95, 1.15, 2.4), "offset": Vector3(0, 0.58, 0)},
	"toy_speedster": {"size": Vector3(1.85, 0.9, 2.25), "offset": Vector3(0, 0.45, 0)},
	"toy_track": {"size": Vector3(2.2, 0.35, 2.2), "offset": Vector3(0, 0.18, 0)},
	"toy_track_curve": {"size": Vector3(2.3, 0.35, 2.3), "offset": Vector3(0, 0.18, 0)},
	"toy_gate": {"size": Vector3(2.3, 1.8, 0.5), "offset": Vector3(0, 0.9, 0)},
	"toy_item_box": {"size": Vector3(1.25, 1.25, 1.25), "offset": Vector3(0, 0.62, 0)},
	"toy_cone": {"size": Vector3(0.8, 1.1, 0.8), "offset": Vector3(0, 0.55, 0)},
	"toy_support": {"size": Vector3(1.4, 1.1, 1.4), "offset": Vector3(0, 0.55, 0)},
}
const TURF_SHADER: Shader = preload("res://assets/materials/turf.gdshader")
const STRIPES_SHADER: Shader = preload("res://assets/materials/stripes.gdshader")
const DOTS_SHADER: Shader = preload("res://assets/materials/dots.gdshader")
const GRADIENT_SURFACE_SHADER: Shader = preload("res://assets/materials/gradient_surface.gdshader")
const CONCRETE_TEXTURE: Texture2D = preload("res://assets/textures/concrete.png")
const ASPHALT_TEXTURE: Texture2D = preload("res://assets/textures/asphalt.png")
const BRUSHED_METAL_TEXTURE: Texture2D = preload("res://assets/environment/textures/brushed_metal.svg")
const PAINTED_PANELS_TEXTURE: Texture2D = preload("res://assets/environment/textures/painted_panels.svg")
const STONE_BLOCKS_TEXTURE: Texture2D = preload("res://assets/environment/textures/stone_blocks.svg")
const TOY_PLASTIC_TEXTURE: Texture2D = preload("res://assets/environment/textures/toy_plastic.svg")
const ROOF_SHINGLES_TEXTURE: Texture2D = preload("res://assets/environment/textures/roof_shingles.svg")
const FABRIC_WEAVE_TEXTURE: Texture2D = preload("res://assets/environment/textures/fabric_weave.svg")
const SOIL_PEBBLES_TEXTURE: Texture2D = preload("res://assets/environment/textures/soil_pebbles.svg")
const WOOD_GRAIN_TEXTURE: Texture2D = preload("res://assets/environment/textures/wood_grain.svg")

@export_enum("Neon Arcade", "Backyard", "Arena", "Sky Temple", "Toybox") var theme_id := 0
@export var map_name := "Neon Arcade"
@export var arena_half_width := 40.0
@export var arena_half_length := 120.0
@export var arena_aspect_ratio := 3.0
@export var fall_limit := -30.0

var models
var _materials: Dictionary = {}
var _surfaces: Dictionary = {}
var _visuals: Node3D
var _model_visuals: Node3D
var _collision_body: StaticBody3D
var _surface_bodies: Node3D
var _spawn_points: Node3D
var _landmarks: Node3D
var _interactables: Node3D
var _flow_root: Node3D
var _map_audit: Dictionary = {}
var _counter := 0


func _ready() -> void:
	theme_id = clampi(theme_id, 0, BUILDER_SCRIPTS.size() - 1)
	if is_arena_blueprint():
		arena_aspect_ratio = 24.0 / 34.0
	arena_half_length = arena_half_width * arena_aspect_ratio
	_create_roots()
	_build_materials()
	models = MODELS_SCRIPT.new(self)
	_build_shell()
	var builder = BUILDER_SCRIPTS[theme_id].new()
	_map_audit = builder.call("build", self)
	if not is_neon_arcade() and not is_arena_blueprint():
		ENVIRONMENT_ART.decorate(self, theme_id)
	if not is_neon_arcade() and not is_arena_blueprint():
		var presentation := ENVIRONMENT_PRESENTATION.new()
		presentation.configure(theme_id, arena_half_width, arena_half_length)
		add_child(presentation)
	_build_spawn_points()
	_register_core_duel_flow()
	_add_boundary_identity()


func get_spawn_points() -> Array[Marker3D]:
	var points: Array[Marker3D] = []
	for child in _spawn_points.get_children():
		var marker := child as Marker3D
		if marker != null:
			points.append(marker)
	return points


func get_lighting_profile() -> Dictionary:
	var profiles := [
		{"sky_top": Color(0.012, 0.025, 0.095), "sky_horizon": Color(0.24, 0.075, 0.32), "ambient": Color(0.25, 0.38, 0.68), "ambient_energy": 0.48, "sun_color": Color(0.48, 0.68, 1.0), "sun_energy": 0.42, "sun_rotation": Vector3(-62, -28, 0), "sun_size": 12.0, "sun_curve": 0.06, "fog": Color(0.065, 0.04, 0.16), "fog_energy": 0.68, "fog_density": 0.00105, "fog_sky_affect": 0.42},
		{"sky_top": Color(0.055, 0.42, 0.92), "sky_horizon": Color(0.79, 0.94, 1.0), "ambient": Color(0.74, 0.86, 0.95), "ambient_energy": 0.52, "sun_color": Color(1.0, 0.9, 0.68), "sun_energy": 1.12, "sun_rotation": Vector3(-48, -38, 0), "sun_size": 20.0, "sun_curve": 0.09, "fog": Color(0.64, 0.84, 0.92), "fog_energy": 0.82, "fog_density": 0.00048, "fog_sky_affect": 0.23},
		{"sky_top": Color(0.1, 0.34, 0.7), "sky_horizon": Color(0.66, 0.82, 0.96), "ambient": Color(0.66, 0.76, 0.88), "ambient_energy": 0.5, "sun_color": Color(1.0, 0.78, 0.58), "sun_energy": 1.08, "sun_rotation": Vector3(-56, -58, 0), "sun_size": 15.0, "sun_curve": 0.065, "fog": Color(0.46, 0.62, 0.76), "fog_energy": 0.76, "fog_density": 0.00072, "fog_sky_affect": 0.3},
		{"sky_top": Color(0.08, 0.38, 0.82), "sky_horizon": Color(0.74, 0.9, 0.99), "ambient": Color(0.72, 0.83, 0.94), "ambient_energy": 0.48, "sun_color": Color(1.0, 0.86, 0.62), "sun_energy": 1.0, "sun_rotation": Vector3(-44, -22, 0), "sun_size": 24.0, "sun_curve": 0.12, "fog": Color(0.62, 0.79, 0.92), "fog_energy": 0.88, "fog_density": 0.00082, "fog_sky_affect": 0.38},
		{"sky_top": Color(0.07, 0.38, 0.84), "sky_horizon": Color(0.75, 0.91, 1.0), "ambient": Color(0.81, 0.79, 0.72), "ambient_energy": 0.54, "sun_color": Color(1.0, 0.78, 0.5), "sun_energy": 1.1, "sun_rotation": Vector3(-50, -46, 0), "sun_size": 21.0, "sun_curve": 0.1, "fog": Color(0.62, 0.81, 0.93), "fog_energy": 0.84, "fog_density": 0.0005, "fog_sky_affect": 0.24},
	]
	var profile := (profiles[theme_id] as Dictionary).duplicate(true)
	if is_arena_blueprint():
		# Bright, neutral televised lighting: team color identifies sides and movement hardware,
		# while graphite panels and white markings remain the dominant read.
		profile["sky_top"] = Color(0.055, 0.075, 0.105)
		profile["sky_horizon"] = Color(0.32, 0.38, 0.46)
		profile["ambient"] = Color(0.72, 0.77, 0.84)
		profile["ambient_energy"] = 0.72
		profile["sun_color"] = Color(1.0, 0.98, 0.93)
		profile["sun_energy"] = 1.2
		profile["sun_rotation"] = Vector3(-54, -34, 0)
		profile["sun_size"] = 18.0
		profile["fog"] = Color(0.16, 0.2, 0.25)
		profile["fog_energy"] = 0.16
		profile["fog_density"] = 0.00016
		profile["fog_sky_affect"] = 0.18
	if is_neon_arcade():
		profile["glow_enabled"] = true
		# Keep the image's hard neon edge definition: the center/boosts bloom, but the
		# dark metal floor and platform surfaces must remain readable.
		profile["glow_intensity"] = 1.08
		profile["glow_strength"] = 1.00
		profile["glow_bloom"] = 0.12
	return profile


func get_map_audit() -> Dictionary:
	return _map_audit.duplicate(true)


func get_neon_arcade_blueprint() -> Dictionary:
	return (_map_audit.get("blueprint", {}) as Dictionary).duplicate(true)


func is_neon_arcade() -> bool:
	return theme_id == 0 and map_name == "Neon Arcade"


func is_arena_blueprint() -> bool:
	return theme_id == 2 and map_name == "Arena"


func visual_root() -> Node3D:
	return _visuals


func mat(material_name: String) -> Material:
	return _materials.get(material_name, _materials["white"]) as Material


func surface(surface_name: String) -> PhysicsMaterial:
	return _surfaces.get(surface_name, NORMAL_SURFACE) as PhysicsMaterial


func add_landmark_root(landmark_name: String) -> Node3D:
	var root := Node3D.new()
	root.name = landmark_name
	root.add_to_group("map_landmark")
	_landmarks.add_child(root)
	return root


func add_flow_anchor(anchor_name: String, position: Vector3, role: String, lane: String) -> Marker3D:
	_counter += 1
	var marker := Marker3D.new()
	marker.name = "%sFlow%d" % [anchor_name, _counter]
	marker.position = position
	marker.set_meta("flow_role", role)
	marker.set_meta("flow_lane", lane)
	marker.add_to_group("duel_flow_anchor")
	_flow_root.add_child(marker)
	return marker


func add_duel_cover(
	prefix: String,
	position: Vector3,
	size: Vector3,
	body_material: Material,
	trim_material: Material,
	lane: String,
	cover_role: String,
	rotation_value := Vector3.ZERO,
) -> MeshInstance3D:
	var cover := add_box(prefix, position, size, body_material, true, rotation_value)
	add_box(prefix + "TopTrim", position + Vector3.UP * (size.y * 0.5 + 0.22), Vector3(size.x + 0.55, 0.44, size.z + 0.55), trim_material, false, rotation_value)
	cover.add_to_group("duel_cover")
	cover.set_meta("flow_lane", lane)
	cover.set_meta("cover_role", cover_role)
	add_flow_anchor(prefix + "Cover", position, "cover", lane)
	return cover


func add_route_chevron(prefix: String, position: Vector3, direction: Vector3, material: Material, scale_value := 1.0) -> void:
	var flat_direction := Vector3(direction.x, 0.0, direction.z).normalized()
	if flat_direction.length_squared() <= 0.001:
		return
	var yaw := atan2(-flat_direction.x, -flat_direction.z)
	var back := position - flat_direction * (1.8 * scale_value)
	add_box(prefix + "Left", back - Vector3(flat_direction.z, 0.0, -flat_direction.x) * 1.1 * scale_value, Vector3(0.5 * scale_value, 0.08, 3.0 * scale_value), material, false, Vector3(0, yaw - 0.58, 0))
	add_box(prefix + "Right", back + Vector3(flat_direction.z, 0.0, -flat_direction.x) * 1.1 * scale_value, Vector3(0.5 * scale_value, 0.08, 3.0 * scale_value), material, false, Vector3(0, yaw + 0.58, 0))


func mark_duel_interactable(node: Node3D, purpose: String, leads_to_center: bool) -> Node3D:
	if node == null:
		return null
	node.set_meta("duel_purpose", purpose)
	node.set_meta("leads_to_center", leads_to_center)
	node.add_to_group("intentional_interactable")
	return node


func mark_neon_element(node: Node, kind: String, gu_position: Vector2 = Vector2.ZERO, gu_size := Vector3.ZERO, extra: Dictionary = {}) -> Node:
	if node == null:
		return node
	node.set_meta("neon_kind", kind)
	node.set_meta("gu_position", gu_position)
	node.set_meta("gu_size", gu_size)
	for key in extra:
		node.set_meta(key, extra[key])
	return node


func add_model(model_id: String, position: Vector3, scale_value: Vector3, rotation_value := Vector3.ZERO, parent: Node3D = null, collision_size := Vector3.ZERO, physics_material: PhysicsMaterial = null, collision_center_offset := Vector3.ZERO) -> Node3D:
	var model := ASSET_LIBRARY.instantiate_model(model_id) as Node3D
	if model == null:
		return null
	_counter += 1
	model.name = "%sModel%d" % [model_id.to_pascal_case(), _counter]
	model.position = position
	model.rotation = rotation_value
	model.scale = scale_value
	var visual_parent := parent if parent != null else _model_visuals
	visual_parent.add_child(model)
	var effective_collision_size := collision_size
	var effective_collision_offset := collision_center_offset
	if effective_collision_size.length_squared() <= 0.001:
		var auto_collision := _auto_collision_for_model(model_id, scale_value)
		effective_collision_size = auto_collision.get("size", Vector3.ZERO) as Vector3
		effective_collision_offset = auto_collision.get("offset", Vector3.ZERO) as Vector3
	if effective_collision_size.length_squared() > 0.001:
		var shape := BoxShape3D.new()
		shape.size = effective_collision_size
		var collision_basis := Basis.from_euler(rotation_value)
		var collision_origin := position + collision_basis * effective_collision_offset
		_add_collision(model_id, shape, Transform3D(collision_basis, collision_origin), visual_parent, physics_material)
	return model


func add_box(prefix: String, position: Vector3, size: Vector3, material: Material, with_collision: bool, rotation_value := Vector3.ZERO, parent: Node3D = null, physics_material: PhysicsMaterial = null) -> MeshInstance3D:
	_counter += 1
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "%sVisual%d" % [prefix, _counter]
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	mesh_instance.mesh = mesh
	mesh_instance.position = position
	mesh_instance.rotation = rotation_value
	var visual_parent := parent if parent != null else _visuals
	visual_parent.add_child(mesh_instance)
	if with_collision:
		var shape := BoxShape3D.new()
		shape.size = size
		_add_collision(prefix, shape, Transform3D(Basis.from_euler(rotation_value), position), visual_parent, physics_material)
	return mesh_instance


func add_cylinder(prefix: String, position: Vector3, radius: float, height: float, material: Material, with_collision: bool, rotation_value := Vector3.ZERO, parent: Node3D = null, physics_material: PhysicsMaterial = null) -> MeshInstance3D:
	_counter += 1
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "%sVisual%d" % [prefix, _counter]
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 24
	mesh.material = material
	mesh_instance.mesh = mesh
	mesh_instance.position = position
	mesh_instance.rotation = rotation_value
	var visual_parent := parent if parent != null else _visuals
	visual_parent.add_child(mesh_instance)
	if with_collision:
		var shape := CylinderShape3D.new()
		shape.radius = radius
		shape.height = height
		_add_collision(prefix, shape, Transform3D(Basis.from_euler(rotation_value), position), visual_parent, physics_material)
	return mesh_instance


func add_sphere(prefix: String, position: Vector3, radius: float, material: Material, with_collision := false, parent: Node3D = null, physics_material: PhysicsMaterial = null) -> MeshInstance3D:
	_counter += 1
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "%sVisual%d" % [prefix, _counter]
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 10
	mesh.material = material
	mesh_instance.mesh = mesh
	mesh_instance.position = position
	var visual_parent := parent if parent != null else _visuals
	visual_parent.add_child(mesh_instance)
	if with_collision:
		var shape := SphereShape3D.new()
		shape.radius = radius
		_add_collision(prefix, shape, Transform3D(Basis.IDENTITY, position), visual_parent, physics_material)
	return mesh_instance


func add_torus(prefix: String, position: Vector3, inner_radius: float, outer_radius: float, material: Material, with_collision := false, rotation_value := Vector3.ZERO, parent: Node3D = null) -> MeshInstance3D:
	_counter += 1
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "%sVisual%d" % [prefix, _counter]
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = outer_radius
	mesh.rings = 18
	mesh.ring_segments = 36
	mesh.material = material
	mesh_instance.mesh = mesh
	mesh_instance.position = position
	mesh_instance.rotation = rotation_value
	var visual_parent := parent if parent != null else _visuals
	visual_parent.add_child(mesh_instance)
	if with_collision:
		var shape := CylinderShape3D.new()
		shape.radius = outer_radius
		shape.height = maxf(0.6, outer_radius - inner_radius)
		_add_collision(prefix, shape, Transform3D(Basis.from_euler(rotation_value), position), visual_parent, NORMAL_SURFACE)
	return mesh_instance


func add_pipe(prefix: String, position: Vector3, radius: float, length: float, material: Material, rotation_value := Vector3.ZERO, parent: Node3D = null, with_collision := false) -> MeshInstance3D:
	return add_cylinder(prefix, position, radius, length, material, with_collision, rotation_value, parent)


func add_trimmed_box(prefix: String, position: Vector3, size: Vector3, body_material: Material, trim_material: Material, with_collision: bool, parent: Node3D = null) -> void:
	add_box(prefix, position, size, body_material, with_collision, Vector3.ZERO, parent)
	add_box(prefix + "TopTrim", position + Vector3(0, size.y * 0.5 + 0.28, 0), Vector3(size.x + 0.7, 0.56, size.z + 0.7), trim_material, false, Vector3.ZERO, parent)
	add_box(prefix + "BottomTrim", position - Vector3(0, size.y * 0.5 - 0.28, 0), Vector3(size.x + 0.5, 0.56, size.z + 0.5), trim_material, false, Vector3.ZERO, parent)


func add_ramp(prefix: String, position: Vector3, size: Vector3, material: Material, rotation_value: Vector3, physics_material: PhysicsMaterial = null) -> void:
	add_box(prefix, position, size, material, true, rotation_value, null, physics_material)
	var ramp_basis := Basis.from_euler(rotation_value)
	var edge_a_offset := ramp_basis * Vector3(-size.x * 0.5 + 0.45, 1.0, 0)
	var edge_b_offset := ramp_basis * Vector3(size.x * 0.5 - 0.45, 1.0, 0)
	add_box(prefix + "EdgeA", position + edge_a_offset, Vector3(0.5, 2.0, size.z), mat("hazard"), false, rotation_value)
	add_box(prefix + "EdgeB", position + edge_b_offset, Vector3(0.5, 2.0, size.z), mat("hazard"), false, rotation_value)


func add_arch(prefix: String, position: Vector3, width: float, height: float, body_material: Material, trim_material: Material) -> void:
	add_box(prefix + "Left", position + Vector3(-width * 0.5, height * 0.5, 0), Vector3(3.5, height, 4.5), body_material, true)
	add_box(prefix + "Right", position + Vector3(width * 0.5, height * 0.5, 0), Vector3(3.5, height, 4.5), body_material, true)
	add_box(prefix + "Top", position + Vector3(0, height, 0), Vector3(width + 3.5, 3.5, 4.5), body_material, true)
	add_box(prefix + "Trim", position + Vector3(0, height + 2.0, 0), Vector3(width + 6.0, 0.55, 5.0), trim_material, false)


func add_label(position: Vector3, text_value: String, color: Color, font_size: int) -> void:
	_counter += 1
	var label := Label3D.new()
	label.name = "ArenaLabel%d" % _counter
	label.position = position
	label.text = text_value
	label.font_size = font_size
	label.outline_size = 7
	label.modulate = color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_visuals.add_child(label)


func add_launch_pad(position: Vector3, direction: Vector3, strength: float, color: Color) -> Area3D:
	_counter += 1
	var pad := LAUNCH_PAD_SCENE.instantiate() as Area3D
	pad.name = "LaunchPad%d" % _counter
	pad.position = position
	pad.call("configure", direction, strength, color)
	_interactables.add_child(pad)
	return pad


func add_wind_zone(position: Vector3, size: Vector3, direction: Vector3, strength: float, color: Color) -> Area3D:
	_counter += 1
	var zone := WIND_ZONE_SCENE.instantiate() as Area3D
	zone.name = "WindZone%d" % _counter
	zone.position = position
	zone.call("configure", size, direction, strength, color)
	_interactables.add_child(zone)
	return zone


func add_moving_platform(position: Vector3, offset: Vector3, size: Vector3, seconds: float, color: Color, phase := 0.0) -> AnimatableBody3D:
	_counter += 1
	var platform := MOVING_PLATFORM_SCENE.instantiate() as AnimatableBody3D
	platform.name = "MovingPlatform%d" % _counter
	platform.position = position
	platform.call("configure", size, offset, seconds, color, phase)
	_interactables.add_child(platform)
	return platform


func add_rotating_bumper(position: Vector3, length: float, speed: float, impulse: float, color: Color) -> Node3D:
	_counter += 1
	var bumper := ROTATING_BUMPER_SCENE.instantiate() as Node3D
	bumper.name = "RotatingBumper%d" % _counter
	bumper.position = position
	bumper.call("configure", length, speed, impulse, color)
	_interactables.add_child(bumper)
	return bumper


func add_conveyor(position: Vector3, size: Vector3, direction: Vector3, strength: float, color: Color) -> Area3D:
	_counter += 1
	var conveyor := CONVEYOR_SCENE.instantiate() as Area3D
	conveyor.name = "Conveyor%d" % _counter
	conveyor.position = position
	conveyor.call("configure", size, direction, strength, color)
	_interactables.add_child(conveyor)
	return conveyor


func add_directional_bumper(position: Vector3, size: Vector3, strength: float, color: Color, direction := Vector3.ZERO, glow_energy := 2.0, round_shape := false) -> Area3D:
	_counter += 1
	var bumper := DIRECTIONAL_BUMPER_SCRIPT.new() as Area3D
	bumper.name = "DirectionalBumper%d" % _counter
	bumper.position = position
	bumper.call("configure", size, strength, color, direction, glow_energy, round_shape)
	_interactables.add_child(bumper)
	return bumper


func add_laser_gate(position: Vector3, size: Vector3, direction: Vector3, strength: float, color: Color, rotation_value := Vector3.ZERO) -> Area3D:
	_counter += 1
	var gate := LASER_GATE_SCRIPT.new() as Area3D
	gate.name = "LaserGate%d" % _counter
	gate.position = position
	gate.rotation = rotation_value
	gate.call("configure", size, direction, strength, color)
	_interactables.add_child(gate)
	return gate


func _auto_collision_for_model(model_id: String, scale_value: Vector3) -> Dictionary:
	var base := AUTO_MODEL_COLLISION_BASE.get(model_id, {}) as Dictionary
	if base.is_empty():
		return {}
	var base_size := base.get("size", Vector3.ZERO) as Vector3
	var base_offset := base.get("offset", Vector3.ZERO) as Vector3
	var absolute_scale := Vector3(absf(scale_value.x), absf(scale_value.y), absf(scale_value.z))
	return {
		"size": Vector3(
			base_size.x * absolute_scale.x,
			base_size.y * absolute_scale.y,
			base_size.z * absolute_scale.z
		),
		"offset": Vector3(
			base_offset.x * scale_value.x,
			base_offset.y * scale_value.y,
			base_offset.z * scale_value.z
		),
	}


func _create_roots() -> void:
	_visuals = Node3D.new()
	_visuals.name = "AuthoredVisuals"
	add_child(_visuals)
	_model_visuals = Node3D.new()
	_model_visuals.name = "ModelVisuals"
	_visuals.add_child(_model_visuals)
	_collision_body = StaticBody3D.new()
	_collision_body.name = "ArenaCollision"
	_collision_body.collision_layer = 1
	_collision_body.collision_mask = 2
	_collision_body.physics_material_override = NORMAL_SURFACE
	add_child(_collision_body)
	_surface_bodies = Node3D.new()
	_surface_bodies.name = "SurfaceCollision"
	add_child(_surface_bodies)
	_spawn_points = Node3D.new()
	_spawn_points.name = "SpawnPoints"
	add_child(_spawn_points)
	_landmarks = Node3D.new()
	_landmarks.name = "Landmarks"
	_visuals.add_child(_landmarks)
	_interactables = Node3D.new()
	_interactables.name = "Interactables"
	add_child(_interactables)
	_flow_root = Node3D.new()
	_flow_root.name = "DuelFlow"
	add_child(_flow_root)


func _build_materials() -> void:
	_surfaces = {"normal": NORMAL_SURFACE, "bounce": BOUNCE_SURFACE, "grip": GRIP_SURFACE, "ice": ICE_SURFACE}
	var grass_material := _make_turf_material(Color(0.31, 0.6, 0.28), Color(0.1, 0.33, 0.15))
	var carpet_material := _make_dotted_material(Color(0.055, 0.035, 0.12), Color(0.22, 0.14, 0.42), 12.0, 0.085)
	var wood_material := _make_striped_material(Color(0.5, 0.29, 0.11), Color(0.34, 0.16, 0.045), 9.0, 0.88)
	var wood_dark_material := _make_striped_material(Color(0.31, 0.15, 0.055), Color(0.17, 0.07, 0.02), 11.0, 0.94)
	var wood_light_material := _make_striped_material(Color(0.74, 0.48, 0.21), Color(0.53, 0.3, 0.09), 8.0, 0.86)
	var wood_red_material := _make_striped_material(Color(0.7, 0.21, 0.13), Color(0.48, 0.1, 0.07), 8.0, 0.84)
	var rug_material := _make_dotted_material(Color(0.06, 0.37, 0.61), Color(0.14, 0.62, 0.78), 9.0, 0.12)
	_materials = {
		"black": _make_material(Color(0.018, 0.025, 0.038), 0.38, 0.46),
		"dark_metal": _make_textured_material(BRUSHED_METAL_TEXTURE, Color(0.07, 0.09, 0.13), 0.32, 6.0, 0.62),
		"blue_gray": _make_textured_material(PAINTED_PANELS_TEXTURE, Color(0.25, 0.34, 0.46), 0.58, 5.0, 0.3),
		"white": _make_textured_material(PAINTED_PANELS_TEXTURE, Color(0.92, 0.95, 0.97), 0.72, 5.0),
		"concrete": _make_textured_material(CONCRETE_TEXTURE, Color(0.48, 0.54, 0.61), 0.92, 7.0),
		"stone": _make_textured_material(STONE_BLOCKS_TEXTURE, Color(0.61, 0.63, 0.58), 0.92, 5.0),
		"marble": _make_textured_material(STONE_BLOCKS_TEXTURE, Color(0.76, 0.78, 0.71), 0.7, 4.0),
		"carpet": carpet_material,
		"court": _make_textured_material(ASPHALT_TEXTURE, Color(0.18, 0.21, 0.26), 0.8, 8.0),
		"wood": wood_material,
		"wood_dark": wood_dark_material,
		"wood_light": wood_light_material,
		"wood_red": wood_red_material,
		"roof_red": _make_textured_material(ROOF_SHINGLES_TEXTURE, Color(0.43, 0.1, 0.08), 0.9, 7.0),
		"roof_dark": _make_textured_material(ROOF_SHINGLES_TEXTURE, Color(0.12, 0.14, 0.17), 0.8, 7.0, 0.18),
		"grass": grass_material,
		"grass_light": _make_material(Color(0.29, 0.61, 0.27), 0.98),
		"grass_dark": _make_material(Color(0.12, 0.39, 0.17), 0.98),
		"hedge": _make_material(Color(0.05, 0.28, 0.1), 0.98),
		"leaves": _make_material(Color(0.06, 0.35, 0.14), 0.96),
		"leaves_light": _make_material(Color(0.22, 0.55, 0.19), 0.96),
		"soil": _make_textured_material(SOIL_PEBBLES_TEXTURE, Color(0.22, 0.1, 0.04), 1.0, 8.0),
		"terracotta": _make_textured_material(PAINTED_PANELS_TEXTURE, Color(0.74, 0.3, 0.14), 0.9, 4.0),
		"flowers": _make_material(Color(0.92, 0.25, 0.48), 0.86),
		"paper": _make_textured_material(FABRIC_WEAVE_TEXTURE, Color(0.98, 0.94, 0.82), 0.96, 6.0),
		"red": _make_textured_material(PAINTED_PANELS_TEXTURE, Color(0.82, 0.12, 0.16), 0.56, 5.0),
		"blue": _make_textured_material(PAINTED_PANELS_TEXTURE, Color(0.05, 0.33, 0.76), 0.54, 5.0),
		"yellow": _make_textured_material(PAINTED_PANELS_TEXTURE, Color(0.96, 0.66, 0.08), 0.62, 5.0),
		"green": _make_textured_material(PAINTED_PANELS_TEXTURE, Color(0.1, 0.55, 0.25), 0.68, 5.0),
		"purple": _make_textured_material(PAINTED_PANELS_TEXTURE, Color(0.38, 0.15, 0.62), 0.58, 5.0),
		"violet": _make_material(Color(0.28, 0.14, 0.5), 0.5, 0.12),
		"cyan": _make_material(Color(0.05, 0.64, 0.78), 0.44, 0.15, 0.75),
		"orange": _make_material(Color(0.95, 0.42, 0.08), 0.48, 0.12),
		"gold": _make_material(Color(0.88, 0.61, 0.16), 0.32, 0.62),
		"team_blue": _make_textured_material(PAINTED_PANELS_TEXTURE, Color(0.06, 0.34, 0.82), 0.52, 5.0, 0.12),
		"team_red": _make_textured_material(PAINTED_PANELS_TEXTURE, Color(0.84, 0.1, 0.14), 0.52, 5.0, 0.12),
		"glass": _make_material(Color(0.22, 0.66, 0.82, 0.52), 0.15, 0.18),
		"cloud": _make_material(Color(0.98, 0.99, 1.0), 1.0),
		"sky_blue": _make_material(Color(0.35, 0.72, 0.96), 0.5, 0.08),
		"hazard": _make_material(Color(0.96, 0.38, 0.08), 0.52, 0.08, 0.35),
		"launch": _make_material(Color(0.55, 0.88, 0.16), 0.48, 0.1, 0.5),
		"warm_light": _make_material(Color(1.0, 0.72, 0.22), 0.28, 0.08, 1.8),
		"neon_cyan": _make_material(Color(0.04, 0.76, 0.9), 0.28, 0.12, 1.65),
		"neon_pink": _make_material(Color(0.94, 0.08, 0.46), 0.28, 0.1, 1.55),
		"neon_lime": _make_material(Color(0.52, 0.9, 0.12), 0.32, 0.06, 1.25),
		"violet_trim": _make_material(Color(0.48, 0.25, 0.82), 0.36, 0.1, 0.65),
		"toy_red": _make_textured_material(TOY_PLASTIC_TEXTURE, Color(0.9, 0.16, 0.17), 0.68, 5.0),
		"toy_blue": _make_textured_material(TOY_PLASTIC_TEXTURE, Color(0.08, 0.42, 0.86), 0.66, 5.0),
		"toy_green": _make_textured_material(TOY_PLASTIC_TEXTURE, Color(0.12, 0.65, 0.3), 0.7, 5.0),
		"toy_yellow": _make_textured_material(TOY_PLASTIC_TEXTURE, Color(0.98, 0.72, 0.08), 0.68, 5.0),
		"rug_blue": rug_material,
	}
	if is_arena_blueprint():
		_materials["arena_floor"] = _make_textured_material(ASPHALT_TEXTURE, Color("242A2F"), 0.88, 8.0, 0.05)
		_materials["arena_wall"] = _make_textured_material(PAINTED_PANELS_TEXTURE, Color("30373E"), 0.58, 6.0, 0.38)
		_materials["arena_trim"] = _make_textured_material(BRUSHED_METAL_TEXTURE, Color("59616A"), 0.42, 5.0, 0.72)
		_materials["arena_marking"] = _make_material(Color("D3D7DA"), 0.48, 0.38)
		_materials["arena_blue"] = _make_material(Color("278CFF"), 0.34, 0.16, 0.42)
		_materials["arena_orange"] = _make_material(Color("F36B32"), 0.36, 0.14, 0.42)
	if theme_id == 3:
		_materials["white"] = _make_material(Color(0.7, 0.76, 0.78), 0.78)
		_materials["stone"] = _make_textured_material(STONE_BLOCKS_TEXTURE, Color(0.48, 0.52, 0.5), 0.94, 5.0)
		_materials["marble"] = _make_textured_material(STONE_BLOCKS_TEXTURE, Color(0.58, 0.63, 0.62), 0.76, 4.0)
		_materials["cloud"] = _make_material(Color(0.78, 0.84, 0.88), 1.0)
	var floor_textures := [FABRIC_WEAVE_TEXTURE, SOIL_PEBBLES_TEXTURE, ASPHALT_TEXTURE, STONE_BLOCKS_TEXTURE, TOY_PLASTIC_TEXTURE]
	var floor_colors := [
		[Color(0.025, 0.035, 0.1), Color(0.18, 0.04, 0.3)],
		[Color(0.08, 0.31, 0.12), Color(0.3, 0.62, 0.2)],
		[Color(0.07, 0.11, 0.16), Color(0.18, 0.27, 0.36)],
		[Color(0.38, 0.47, 0.5), Color(0.72, 0.77, 0.7)],
		[Color(0.04, 0.38, 0.75), Color(0.16, 0.72, 0.48)],
	]
	var wall_textures := [BRUSHED_METAL_TEXTURE, WOOD_GRAIN_TEXTURE, CONCRETE_TEXTURE, STONE_BLOCKS_TEXTURE, TOY_PLASTIC_TEXTURE]
	var wall_colors := [
		[Color(0.015, 0.02, 0.06), Color(0.11, 0.025, 0.18)],
		[Color(0.17, 0.07, 0.025), Color(0.48, 0.24, 0.08)],
		[Color(0.14, 0.2, 0.28), Color(0.34, 0.45, 0.58)],
		[Color(0.42, 0.5, 0.56), Color(0.68, 0.73, 0.7)],
		[Color(0.04, 0.3, 0.68), Color(0.1, 0.58, 0.9)],
	]
	var floor_pair := floor_colors[theme_id] as Array
	var wall_pair := wall_colors[theme_id] as Array
	_materials["floor"] = _make_gradient_material(floor_textures[theme_id], floor_pair[0], floor_pair[1], 8.0, 0.82, 0.05 if theme_id != 0 else 0.25)
	_materials["wall"] = _make_gradient_material(wall_textures[theme_id], wall_pair[0], wall_pair[1], 7.0, 0.7, 0.1 if theme_id != 0 else 0.35)


func _build_shell() -> void:
	if is_neon_arcade():
		_build_neon_arcade_shell()
		return
	if is_arena_blueprint():
		_build_arena_blueprint_shell()
		return
	var w := arena_half_width
	var l := arena_half_length
	add_box("Foundation", Vector3(0, -1.25, 0), Vector3(w * 2.0, 2.5, l * 2.0), mat("floor"), true, Vector3.ZERO, null, NORMAL_SURFACE)
	var wall_height := 34.0
	var thickness := 3.0
	add_box("NorthBoundary", Vector3(0, wall_height * 0.5, -l + thickness * 0.5), Vector3(w * 2.0, wall_height, thickness), mat("wall"), true)
	add_box("SouthBoundary", Vector3(0, wall_height * 0.5, l - thickness * 0.5), Vector3(w * 2.0, wall_height, thickness), mat("wall"), true)
	add_box("WestBoundary", Vector3(-w + thickness * 0.5, wall_height * 0.5, 0), Vector3(thickness, wall_height, l * 2.0 - thickness * 2.0), mat("wall"), true)
	add_box("EastBoundary", Vector3(w - thickness * 0.5, wall_height * 0.5, 0), Vector3(thickness, wall_height, l * 2.0 - thickness * 2.0), mat("wall"), true)
	var trim: Material = [mat("neon_cyan"), mat("wood_light"), mat("orange"), mat("gold"), mat("toy_yellow")][theme_id]
	for z in range(int(-l + 9), int(l - 8), 14):
		for side_value in [-1.0, 1.0]:
			var side: float = side_value
			var x: float = side * (w - 1.25)
			add_box("WallPilaster", Vector3(x, 13.0, float(z)), Vector3(0.55, 25.0, 1.3), trim, false)
			add_box("WallInset", Vector3(x - side * 0.18, 18.0, float(z + 5)), Vector3(0.45, 7.0, 8.0), mat("blue_gray"), false)
	for x in range(int(-w + 7), int(w - 6), 10):
		for side_value in [-1.0, 1.0]:
			var side: float = side_value
			var z: float = side * (l - 1.25)
			add_box("EndWallPilaster", Vector3(float(x), 13.0, z), Vector3(1.2, 25.0, 0.55), trim, false)
	add_box("WestTopRail", Vector3(-w + 1.2, wall_height + 0.8, 0), Vector3(2.4, 1.6, l * 2.0), trim, false)
	add_box("EastTopRail", Vector3(w - 1.2, wall_height + 0.8, 0), Vector3(2.4, 1.6, l * 2.0), trim, false)
	add_box("NorthTopRail", Vector3(0, wall_height + 0.8, -l + 1.2), Vector3(w * 2.0, 1.6, 2.4), trim, false)
	add_box("SouthTopRail", Vector3(0, wall_height + 0.8, l - 1.2), Vector3(w * 2.0, 1.6, 2.4), trim, false)


func _build_arena_blueprint_shell() -> void:
	# Literal 34D x 24D compact octagon.  D is one blob diameter, unlike Neon Arcade's 2D grid unit.
	var d := arena_half_width / 17.0
	var solid_height := 3.0 * d
	var glass_height := 2.0 * d
	var thickness := 0.75 * d
	add_box("ArenaSportsFloor", Vector3(0, -0.25 * d, 0), Vector3(34.0 * d, 0.5 * d, 24.0 * d), mat("arena_floor"), true, Vector3.ZERO, null, NORMAL_SURFACE)
	var points := [Vector2(3, 1), Vector2(31, 1), Vector2(33, 3), Vector2(33, 21), Vector2(31, 23), Vector2(3, 23), Vector2(1, 21), Vector2(1, 3)]
	for index in range(points.size()):
		var source_a := points[index] as Vector2
		var source_b := points[(index + 1) % points.size()] as Vector2
		var a := Vector3((source_a.x - 17.0) * d, 0, (12.0 - source_a.y) * d)
		var b := Vector3((source_b.x - 17.0) * d, 0, (12.0 - source_b.y) * d)
		var delta := b - a
		var center := (a + b) * 0.5
		var yaw := atan2(delta.x, delta.z)
		var wall_size := Vector3(thickness, solid_height, delta.length())
		add_box("ArenaPerimeterWall", center + Vector3.UP * solid_height * 0.5, wall_size, mat("arena_wall"), true, Vector3(0, yaw, 0), null, BOUNCE_SURFACE)
		# Three-depth industrial wall bay: the collision base, a recessed graphite panel,
		# then the pillared frame and top/bottom rails visible in the blueprint.
		var inward := -Vector3(center.x, 0.0, center.z).normalized()
		add_box("ArenaWallRecess", center + inward * (thickness * 0.52) + Vector3.UP * (1.52 * d), Vector3(0.13 * d, 1.55 * d, delta.length() * 0.70), mat("dark_metal"), false, Vector3(0, yaw, 0))
		add_box("ArenaWallTopRail", center + inward * (thickness * 0.60) + Vector3.UP * (2.87 * d), Vector3(thickness + 0.16 * d, 0.14 * d, delta.length() * 0.94), mat("arena_trim"), false, Vector3(0, yaw, 0))
		add_box("ArenaWallBottomRail", center + inward * (thickness * 0.60) + Vector3.UP * (0.22 * d), Vector3(thickness + 0.12 * d, 0.10 * d, delta.length() * 0.94), mat("arena_trim"), false, Vector3(0, yaw, 0))
		for fraction in [0.34, 0.66]:
			var brace := a.lerp(b, fraction)
			add_box("ArenaWallBrace", brace + inward * (thickness * 0.61) + Vector3.UP * (1.50 * d), Vector3(thickness * 0.48, 1.86 * d, 0.13 * d), mat("arena_trim"), false, Vector3(0, yaw, 0))
		add_box("ArenaUpperGlass", center + Vector3.UP * (solid_height + glass_height * 0.5), Vector3(0.18 * d, glass_height, delta.length()), mat("glass"), true, Vector3(0, yaw, 0), null, BOUNCE_SURFACE)
		var lower_color := mat("arena_blue") if center.z > 1.0 * d else (mat("arena_orange") if center.z < -1.0 * d else mat("arena_marking"))
		add_box("ArenaBoundaryLight", center + Vector3.UP * 0.15 * d, Vector3(0.08 * d, 0.12 * d, delta.length() * 0.94), lower_color, false, Vector3(0, yaw, 0))
		for fraction in [0.22, 0.5, 0.78]:
			var pillar_pos := a.lerp(b, fraction)
			add_box("ArenaWallPillar", pillar_pos + Vector3.UP * solid_height * 0.5, Vector3(0.95 * d, solid_height, 0.65 * d), mat("arena_trim"), true, Vector3(0, yaw, 0), null, BOUNCE_SURFACE)
	var roof_height := 5.0 * d
	var roof := add_box("ArenaTransparentRoof", Vector3(0, roof_height, 0), Vector3(32.0 * d, 0.18 * d, 22.0 * d), mat("glass"), true, Vector3.ZERO, null, ICE_SURFACE)
	roof.add_to_group("arena_roof")
	for x in range(-12, 13, 4):
		add_box("ArenaRoofFrameX", Vector3(float(x) * d, roof_height + 0.11 * d, 0), Vector3(0.06 * d, 0.08 * d, 22.0 * d), mat("arena_marking"), false)
	for z in range(-8, 9, 4):
		add_box("ArenaRoofFrameZ", Vector3(0, roof_height + 0.11 * d, float(z) * d), Vector3(32.0 * d, 0.08 * d, 0.06 * d), mat("arena_marking"), false)


func _build_neon_arcade_shell() -> void:
	var w := arena_half_width
	var l := arena_half_length
	var gu := w / 9.0
	var wall_height := gu * 6.0
	var wall_thickness := gu * 0.3
	var floor_thickness := gu * 0.25
	var roof_height := gu * 6.2
	add_box("NeonFoundation", Vector3(0, -floor_thickness * 0.5, 0), Vector3(w * 2.0, floor_thickness, l * 2.0), mat("dark_metal"), true, Vector3.ZERO, null, NORMAL_SURFACE)
	for side_value in [-1.0, 1.0]:
		var side: float = side_value
		add_box("NeonSideWall", Vector3(side * (w - wall_thickness * 0.5), wall_height * 0.5, 0), Vector3(wall_thickness, wall_height, l * 2.0), mat("wall"), true)
		add_box("NeonSideRail", Vector3(side * (w - wall_thickness * 0.5), wall_height + gu * 0.08, 0), Vector3(wall_thickness + gu * 0.08, gu * 0.16, l * 2.0), mat("neon_cyan") if side < 0.0 else mat("neon_pink"), false)
		add_box("NeonEndWall", Vector3(0, wall_height * 0.5, side * (l - wall_thickness * 0.5)), Vector3(w * 2.0, wall_height, wall_thickness), mat("wall"), true)
		add_box("NeonEndRail", Vector3(0, wall_height + gu * 0.08, side * (l - wall_thickness * 0.5)), Vector3(w * 2.0, gu * 0.16, wall_thickness + gu * 0.08), mat("violet_trim"), false)
	var roof := add_box("TransparentRoof", Vector3(0, roof_height, 0), Vector3(w * 2.0 - wall_thickness, gu * 0.1, l * 2.0 - wall_thickness), mat("glass"), true, Vector3.ZERO, null, BOUNCE_SURFACE)
	mark_neon_element(roof, "transparent_roof", Vector2(9, 9), Vector3(18, 0.1, 18), {"height_gu": 6.2, "bounce_preserving": true})
	for grid in range(-8, 9):
		var offset := float(grid) * gu
		var x_material: Material = mat("neon_cyan") if grid % 2 == 0 else mat("violet_trim")
		var z_material: Material = mat("neon_pink") if grid % 2 == 0 else mat("violet_trim")
		add_box("RoofFrameX", Vector3(offset, roof_height + gu * 0.055, 0), Vector3(gu * 0.045, gu * 0.08, l * 2.0), x_material, false)
		add_box("RoofFrameZ", Vector3(0, roof_height + gu * 0.055, offset), Vector3(w * 2.0, gu * 0.08, gu * 0.045), z_material, false)


func _build_spawn_points() -> void:
	if is_neon_arcade():
		var gu := arena_half_width / 9.0
		# The tower deck is Z=3 GU; add the actual 2.8875-unit blob radius, not 2.9 GU.
		# This keeps a spawn clear of the crown and the 6.2-GU roof while the ramp still
		# meets the same platform surface shown in the blueprint side profile.
		var blob_radius := 2.8875
		var deck_spawn_height := 3.0 * gu + blob_radius + 0.18
		# The two playable spawns are the blueprint's diagonal (2,2) and (16,16)
		# corner decks.  The other two illustrated towers remain movement structures.
		var towers := [Vector3(-7.0 * gu, deck_spawn_height, -7.0 * gu), Vector3(7.0 * gu, deck_spawn_height, 7.0 * gu)]
		# Start at the inside rim of the 3x3-GU deck. This is still on the blueprint
		# platform but avoids placing the camera inside its decorative glowing core.
		var positions: Array[Vector3] = []
		for tower in towers:
			var toward_center := -Vector3(tower.x, 0.0, tower.z).normalized()
			positions.append(tower + toward_center * 1.10 * gu)
		for index in range(positions.size()):
			var marker := Marker3D.new()
			marker.name = "RedSpawn" if index == 0 else "BlueSpawn"
			marker.position = positions[index]
			# Camera forward is local -Z.  Rotate that forward vector from each tower into
			# the center of the arena rather than out into the corner wall.
			marker.rotation.y = atan2(marker.position.x, marker.position.z)
			_spawn_points.add_child(marker)
		return
	if is_arena_blueprint():
		var d := arena_half_width / 17.0
		var blob_radius := 2.8875
		var positions := [Vector3(0, 1.2 * d + blob_radius + 0.16, 10.0 * d), Vector3(0, 1.2 * d + blob_radius + 0.16, -10.0 * d)]
		for index in range(positions.size()):
			var marker := Marker3D.new()
			marker.name = "BlueSpawn" if index == 0 else "OrangeSpawn"
			marker.position = positions[index]
			marker.rotation.y = 0.0 if index == 0 else PI
			_spawn_points.add_child(marker)
		return
	var positions := [Vector3(0, 4.2, arena_half_length - 14.0), Vector3(0, 4.2, -arena_half_length + 14.0)]
	for index in range(positions.size()):
		var marker := Marker3D.new()
		marker.name = "RedSpawn" if index == 0 else "BlueSpawn"
		marker.position = positions[index]
		marker.rotation.y = atan2(marker.position.x, marker.position.z)
		_spawn_points.add_child(marker)
		var team_material := mat("team_red") if index == 0 else mat("team_blue")
		add_cylinder("TeamSpawnPad", positions[index] + Vector3(0, -3.78, 0), 7.2, 0.48, team_material, false)
		var center_sign := -1.0 if index == 0 else 1.0
		add_box("SpawnBackstop", Vector3(0, 5.0, positions[index].z - center_sign * 7.5), Vector3(30, 10, 3), team_material, true)
		for side in [-1.0, 1.0]:
			add_box("SpawnWing", Vector3(side * 13.0, 4.0, positions[index].z + center_sign * 2.0), Vector3(5, 8, 19), team_material, true, Vector3(0, side * center_sign * 0.22, 0))


func _register_core_duel_flow() -> void:
	if is_neon_arcade():
		var gu := arena_half_width / 9.0
		add_flow_anchor("SouthWestSpawnExit", Vector3(-2.1 * gu, 1.0, -2.1 * gu), "spawn_exit", "left")
		add_flow_anchor("NorthEastSpawnExit", Vector3(2.1 * gu, 1.0, 2.1 * gu), "spawn_exit", "right")
		for spec in [[Vector3(-4.0 * gu, 1.0, 0.0), "left"], [Vector3(4.0 * gu, 1.0, 0.0), "right"], [Vector3(0.0, 1.0, -4.0 * gu), "left"], [Vector3(0.0, 1.0, 4.0 * gu), "right"]]:
			add_flow_anchor("NeonFlank", spec[0] as Vector3, "flank_route", spec[1] as String)
		for spec in [[Vector3(-2.55 * gu, 1.0, 0.0), "left"], [Vector3(2.55 * gu, 1.0, 0.0), "right"], [Vector3(0.0, 1.0, -2.55 * gu), "left"], [Vector3(0.0, 1.0, 2.55 * gu), "right"]]:
			add_flow_anchor("NeonApproach", spec[0] as Vector3, "attack_route", spec[1] as String)
		add_flow_anchor("NeonCenterContest", Vector3.ZERO, "center_contest", "center")
		return
	add_flow_anchor("BlueSpawnExit", Vector3(0, 1.0, -arena_half_length + 28.0), "spawn_exit", "center")
	add_flow_anchor("RedSpawnExit", Vector3(0, 1.0, arena_half_length - 28.0), "spawn_exit", "center")
	add_flow_anchor("CenterContest", Vector3(0, 1.0, 0), "center_contest", "center")


func _add_boundary_identity() -> void:
	if is_neon_arcade():
		for position in [Vector3(-arena_half_width * 0.46, 5.3 * (arena_half_width / 9.0), 0), Vector3(arena_half_width * 0.46, 5.3 * (arena_half_width / 9.0), 0)]:
			var light := OmniLight3D.new()
			light.position = position
			light.light_color = _accent_color()
			light.light_energy = 0.62
			light.omni_range = 32.0
			light.shadow_enabled = false
			light.add_to_group("presentation_light")
			_visuals.add_child(light)
		return
	add_label(Vector3(0, 25.0, -arena_half_length + 3.0), map_name.to_upper(), _accent_color(), 42)
	for position in [Vector3(-arena_half_width + 6, 18, 0), Vector3(arena_half_width - 6, 18, 0)]:
		var light := OmniLight3D.new()
		light.position = position
		light.light_color = _accent_color()
		light.light_energy = 1.2 if theme_id == 0 else 0.7
		light.omni_range = 44.0
		light.shadow_enabled = false
		light.add_to_group("presentation_light")
		_visuals.add_child(light)


func _add_collision(prefix: String, shape: Shape3D, local_transform: Transform3D, visual_parent: Node3D, physics_material: PhysicsMaterial) -> void:
	var target_body := _collision_body
	if physics_material != null and physics_material != NORMAL_SURFACE:
		target_body = StaticBody3D.new()
		target_body.name = "%sSurfaceBody%d" % [prefix, _counter]
		target_body.collision_layer = 1
		target_body.collision_mask = 2
		target_body.physics_material_override = physics_material
		_surface_bodies.add_child(target_body)
	var collision := CollisionShape3D.new()
	collision.name = "%sCollision%d" % [prefix, _counter]
	collision.shape = shape
	target_body.add_child(collision)
	var world_transform := visual_parent.global_transform * local_transform
	collision.transform = target_body.global_transform.affine_inverse() * world_transform


func _accent_color() -> Color:
	return [Color(0.16, 0.84, 0.96), Color(0.96, 0.7, 0.2), Color(0.98, 0.4, 0.12), Color(0.34, 0.72, 1.0), Color(0.98, 0.54, 0.18)][theme_id]


func _make_material(color: Color, roughness := 0.75, metallic := 0.0, emission_energy := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emission_energy > 0.0:
		material.emission_enabled = true
		material.emission = Color(color.r, color.g, color.b)
		material.emission_energy_multiplier = emission_energy
	return material


func _make_textured_material(texture: Texture2D, tint: Color, roughness: float, tile_scale: float, metallic := 0.0) -> StandardMaterial3D:
	var material := _make_material(tint, roughness, metallic)
	material.albedo_texture = texture
	material.uv1_scale = Vector3(tile_scale, tile_scale, tile_scale)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return material


func _make_gradient_material(texture: Texture2D, color_a: Color, color_b: Color, tile_scale: float, roughness: float, emission: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = GRADIENT_SURFACE_SHADER
	material.set_shader_parameter("detail_texture", texture)
	material.set_shader_parameter("color_a", color_a)
	material.set_shader_parameter("color_b", color_b)
	material.set_shader_parameter("gradient_axis", Vector2(0.28, 1.0))
	material.set_shader_parameter("tile_scale", tile_scale)
	material.set_shader_parameter("roughness_value", roughness)
	material.set_shader_parameter("metallic_value", 0.16 if theme_id in [0, 2] else 0.02)
	material.set_shader_parameter("emission_strength", emission)
	material.set_shader_parameter("pulse_speed", 0.7 if emission > 0.2 else 0.0)
	return material


func _make_turf_material(light_color: Color, dark_color: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = TURF_SHADER
	material.set_shader_parameter("grass_light", light_color)
	material.set_shader_parameter("grass_dark", dark_color)
	material.set_shader_parameter("tile_scale", 74.0)
	return material


func _make_striped_material(color_a: Color, color_b: Color, count: float, roughness: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = STRIPES_SHADER
	material.set_shader_parameter("color_a", color_a)
	material.set_shader_parameter("color_b", color_b)
	material.set_shader_parameter("stripe_count", count)
	material.set_shader_parameter("stripe_softness", 0.12)
	material.set_shader_parameter("roughness", roughness)
	return material


func _make_dotted_material(base_color: Color, dot_color: Color, count: float, radius: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = DOTS_SHADER
	material.set_shader_parameter("base_color", base_color)
	material.set_shader_parameter("dot_color", dot_color)
	material.set_shader_parameter("dot_count", count)
	material.set_shader_parameter("dot_radius", radius)
	return material
