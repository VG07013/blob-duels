class_name TrainingYardArena
extends Node3D

## Scene root for the Training Yard, the drill-hall competitive map. Thin by
## design: layout lives in TrainingYardGeometry, construction in
## training_yard_builder. This node owns the structural roots, the map API
## game.gd and SpawnManager read (spawn points, bounds, lighting), and the
## audit the map contracts use.

const GEOMETRY := preload("res://scripts/environment/training_yard_geometry.gd")
const BUILDER := preload("res://scripts/environment/training_yard_builder.gd")
const NORMAL_SURFACE: PhysicsMaterial = preload("res://assets/materials/physics/arena_normal.tres")
const BOUNCE_SURFACE: PhysicsMaterial = preload("res://assets/materials/physics/arena_bounce.tres")
const GRIP_SURFACE: PhysicsMaterial = preload("res://assets/materials/physics/arena_grip.tres")
const ICE_SURFACE: PhysicsMaterial = preload("res://assets/materials/physics/arena_ice.tres")

@export var map_name := "Training Yard"

## Read by SpawnManager.use_competitive_map for the out-of-bounds check.
var arena_half_width := GEOMETRY.HALF_WIDTH
var arena_half_length := GEOMETRY.HALF_LENGTH
var fall_limit := GEOMETRY.FALL_LIMIT

var _map_audit: Dictionary = {}


func _ready() -> void:
	var visuals := Node3D.new()
	visuals.name = "TrainingYardVisuals"
	add_child(visuals)
	for body_spec in [["CourtCollision", NORMAL_SURFACE], ["WallCollision", BOUNCE_SURFACE], ["RampCollision", GRIP_SURFACE], ["GlassCollision", ICE_SURFACE]]:
		var body := StaticBody3D.new()
		body.name = str(body_spec[0])
		body.collision_layer = 1
		body.collision_mask = 2
		body.physics_material_override = body_spec[1] as PhysicsMaterial
		add_child(body)
	for root_name in ["Interactables", "SpawnPoints", "DuelFlow"]:
		var root := Node3D.new()
		root.name = root_name
		add_child(root)
	_map_audit = BUILDER.new().build(self)


func get_spawn_points() -> Array[Marker3D]:
	var points: Array[Marker3D] = []
	for child in get_node("SpawnPoints").get_children():
		var marker := child as Marker3D
		if marker != null:
			points.append(marker)
	return points


func get_map_audit() -> Dictionary:
	return _map_audit.duplicate(true)


## A roofed drill hall: cool daylight through the glass, a neutral fill so
## the charcoal floor stays readable, and a light glow pass for the cyan
## lines and pads. Held to the lighting_contract ceilings like every map.
func get_lighting_profile() -> Dictionary:
	return {
		"sky_top": Color(0.2, 0.36, 0.62),
		"sky_horizon": Color(0.72, 0.82, 0.92),
		"ambient": Color(0.7, 0.76, 0.86),
		"ambient_energy": 0.6,
		"sun_color": Color(1.0, 0.97, 0.9),
		"sun_energy": 1.0,
		"sun_rotation": Vector3(-58, -24, 0),
		"sun_size": 5.0,
		"sun_curve": 0.1,
		"fog": Color(0.7, 0.78, 0.9),
		"fog_energy": 0.5,
		"fog_density": 0.0003,
		"fog_sky_affect": 0.12,
		"glow_enabled": true,
		"glow_intensity": 0.42,
		"glow_strength": 0.85,
		"glow_bloom": 0.0,
		"sky_cover": "clouds",
		"sky_cover_modulate": Color(1.0, 1.0, 1.0, 0.8),
	}
