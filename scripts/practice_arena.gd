class_name PracticeArena
extends Node3D

## Scene root for the practice training grounds - the practice/offline map,
## rebuilt 1:1 from the "Practice Map - Blueprint" sheet.
##
## Thin by design: layout lives in PracticeFacilityGeometry (the blueprint
## coordinate table), construction in practice_facility_builder. This node owns
## the two structural roots the rest of the game relies on (game.gd toggles
## PracticeCollision's layer when entering/leaving practice) and the lighting
## profile. register_spin/register_bob stay available to the builder for any
## animated furniture.

const BUILDER := preload("res://scripts/environment/practice_facility_builder.gd")

var map_name := "Training Grounds"

var _next_index := 0
var _spins: Array[Dictionary] = []
var _bobs: Array[Dictionary] = []
var _elapsed := 0.0


func _ready() -> void:
	var visuals := Node3D.new()
	visuals.name = "PracticeVisuals"
	add_child(visuals)
	var collision := StaticBody3D.new()
	collision.name = "PracticeCollision"
	collision.collision_layer = 1
	collision.collision_mask = 0
	add_child(collision)
	BUILDER.new().build(self)


func _process(delta: float) -> void:
	_elapsed += delta
	for spin in _spins:
		var node := spin["node"] as Node3D
		if is_instance_valid(node):
			node.rotate_y(float(spin["speed"]) * delta * (1.0 if bool(spin["clockwise"]) else -1.0))
	for bob in _bobs:
		var node := bob["node"] as Node3D
		if is_instance_valid(node):
			var base := bob["base"] as Vector3
			node.position = base + Vector3.UP * sin(_elapsed * float(bob["speed"]) * TAU) * float(bob["amplitude"])


## The map owns its look. Consumed by game.gd on practice activation, and held
## to the same lighting_contract ceilings as every competitive map. Clean
## outdoor daylight on purpose: muted turf, soft clouds, and no glow pass -
## the training ground should read as a calm sports facility, not an arcade.
func get_lighting_profile() -> Dictionary:
	return {
		"sky_top": Color(0.24, 0.47, 0.78),
		"sky_horizon": Color(0.74, 0.85, 0.94),
		"ambient": Color(0.68, 0.74, 0.80),
		"ambient_energy": 0.5,
		"sun_color": Color(1.0, 0.96, 0.88),
		"sun_energy": 1.05,
		"sun_rotation": Vector3(-55, -35, 0),
		"sun_size": 4.0,
		"sun_curve": 0.12,
		"fog": Color(0.76, 0.85, 0.93),
		"fog_energy": 0.9,
		"fog_density": 0.0004,
		"fog_sky_affect": 0.15,
		"glow_enabled": false,
		"sky_cover": "clouds",
		"sky_cover_modulate": Color(1.0, 1.0, 1.0),
	}


func register_spin(node: Node3D, speed: float, clockwise: bool) -> void:
	_spins.append({"node": node, "speed": speed, "clockwise": clockwise})


func register_bob(node: Node3D, speed: float, amplitude: float) -> void:
	_bobs.append({"node": node, "base": node.position, "speed": speed, "amplitude": amplitude})


func next_index() -> int:
	_next_index += 1
	return _next_index
