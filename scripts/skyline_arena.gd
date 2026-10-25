class_name SkylineArena
extends Node3D

## Scene root for the Arena map (internal id "skyline"; "arena" is an
## archived map id that save migration still retargets): a tall, wide, fully
## enclosed duel court (110-unit walls under a solid trussed roof) modelled in
## Blender (assets/models/maps/generate_skyline.py -> skyline.glb). The glb
## carries all the visuals; this host adds collision from those meshes by name
## prefix, the spawn markers, and the map API game.gd and SpawnManager read.

const MODEL: PackedScene = preload("res://assets/models/maps/skyline.glb")
const NORMAL_SURFACE: PhysicsMaterial = preload("res://assets/materials/physics/arena_normal.tres")
const BOUNCE_SURFACE: PhysicsMaterial = preload("res://assets/materials/physics/arena_bounce.tres")
const GRIP_SURFACE: PhysicsMaterial = preload("res://assets/materials/physics/arena_grip.tres")
const ICE_SURFACE: PhysicsMaterial = preload("res://assets/materials/physics/arena_ice.tres")

const BLOB_RADIUS := 2.8875
const HALF_EXTENT := 140.0
const SPAWN_DECK_HEIGHT := 3.0
const SPAWN_MARKER_Z := 128.0
## Shadowless straight-down fill that stands in for the preview's area light.
const CEILING_FILL_ENERGY := 0.35
## Mesh-name prefix (set in the Blender script) -> collision body. Deco_ meshes
## are visual only.
const COLLISION_FAMILIES := {
	"Floor_": "CourtCollision",
	"Deck_": "CourtCollision",
	"Block_": "CourtCollision",
	"Wall_": "WallCollision",
	"Ramp_": "RampCollision",
	"Roof_": "RoofCollision",
}
## The solid roof, its trusses and the trim / neon / poster layers never cast
## shadows, so daylight reaches the court evenly under the closed ceiling.
const SHADOWLESS_PREFIXES := ["Roof_", "Deco_", "Wall_Truss"]

@export var map_name := "Arena"

## Read by SpawnManager.use_competitive_map for the out-of-bounds check.
var arena_half_width := HALF_EXTENT
var arena_half_length := HALF_EXTENT
var fall_limit := -30.0

var _map_audit: Dictionary = {}


func _ready() -> void:
	var visuals := MODEL.instantiate() as Node3D
	visuals.name = "SkylineVisuals"
	add_child(visuals)
	var bodies := {}
	for body_spec in [["CourtCollision", NORMAL_SURFACE], ["WallCollision", BOUNCE_SURFACE], ["RampCollision", GRIP_SURFACE], ["RoofCollision", ICE_SURFACE]]:
		var body := StaticBody3D.new()
		body.name = str(body_spec[0])
		body.collision_layer = 1
		body.collision_mask = 2
		body.physics_material_override = body_spec[1] as PhysicsMaterial
		add_child(body)
		bodies[body.name] = body
	var shape_count := 0
	for mesh_instance in visuals.find_children("*", "MeshInstance3D", true, false):
		for prefix in SHADOWLESS_PREFIXES:
			if mesh_instance.name.begins_with(prefix):
				(mesh_instance as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var family := _collision_family(mesh_instance.name)
		if family.is_empty():
			continue
		var shape := CollisionShape3D.new()
		shape.name = mesh_instance.name
		shape.shape = (mesh_instance as MeshInstance3D).mesh.create_trimesh_shape()
		shape.transform = _model_transform(mesh_instance, visuals)
		(bodies[family] as StaticBody3D).add_child(shape)
		shape_count += 1
	var fill := DirectionalLight3D.new()
	fill.name = "CeilingFill"
	fill.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	fill.light_energy = CEILING_FILL_ENERGY
	fill.light_color = Color(0.96, 0.97, 1.0)
	fill.shadow_enabled = false
	add_child(fill)
	var spawn_root := Node3D.new()
	spawn_root.name = "SpawnPoints"
	add_child(spawn_root)
	for spec in [["RedSpawn", 1.0], ["BlueSpawn", -1.0]]:
		var marker := Marker3D.new()
		marker.name = str(spec[0])
		var side := float(spec[1])
		marker.position = Vector3(0.0, SPAWN_DECK_HEIGHT + BLOB_RADIUS + 0.16, side * SPAWN_MARKER_Z)
		# Camera forward is local -Z: the +Z (red) spawn looks down the court.
		marker.rotation.y = 0.0 if side > 0.0 else PI
		spawn_root.add_child(marker)
	_map_audit = {
		"collision_shapes": shape_count,
		"blueprint": {"footprint": Vector2(HALF_EXTENT * 2.0, HALF_EXTENT * 2.0)},
	}


func get_spawn_points() -> Array[Marker3D]:
	var points: Array[Marker3D] = []
	for child in get_node("SpawnPoints").get_children():
		var marker := child as Marker3D
		if marker != null:
			points.append(marker)
	return points


func get_map_audit() -> Dictionary:
	return _map_audit.duplicate(true)


## Bright, soft studio light that matches the Blender preview render: a
## near-overhead white sun, a strong neutral fill, raised exposure, and a
## shadowless top-down CeilingFill light (added in _ready) standing in for
## the preview's big area light under the roof.
func get_lighting_profile() -> Dictionary:
	return {
		"sky_top": Color(0.3, 0.32, 0.42),
		"sky_horizon": Color(0.62, 0.64, 0.72),
		"ambient": Color(0.9, 0.92, 1.0),
		"ambient_energy": 0.72,
		"ambient_sky_contribution": 0.1,
		"exposure": 1.15,
		"sun_color": Color(1.0, 0.98, 0.95),
		"sun_energy": 1.15,
		"sun_rotation": Vector3(-78, -24, 0),
		"sun_size": 4.0,
		"sun_curve": 0.1,
		"fog": Color(0.8, 0.82, 0.9),
		"fog_energy": 0.4,
		"fog_density": 0.00015,
		"fog_sky_affect": 0.0,
		"glow_enabled": true,
		"glow_intensity": 0.4,
		"glow_strength": 0.85,
		"glow_bloom": 0.0,
	}


func _collision_family(mesh_name: String) -> String:
	for prefix in COLLISION_FAMILIES:
		if mesh_name.begins_with(prefix):
			return str(COLLISION_FAMILIES[prefix])
	return ""


## Mesh transform relative to this host, so collision lines up wherever the
## map is parented.
func _model_transform(node: Node, model_root: Node3D) -> Transform3D:
	var xform := Transform3D.IDENTITY
	var cursor := node
	while cursor != null and cursor != model_root:
		if cursor is Node3D:
			xform = (cursor as Node3D).transform * xform
		cursor = cursor.get_parent()
	return model_root.transform * xform
