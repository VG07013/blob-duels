class_name PracticeArena
extends Node3D

## Scene root for the holo training facility - the practice/offline map.
##
## Thin by design: layout lives in PracticeFacilityGeometry, construction in
## practice_facility_builder. This node owns the two structural roots the rest
## of the game relies on (game.gd toggles PracticeCollision's layer when
## entering/leaving practice), the lighting profile, and the small animation
## registry that keeps the hub holograms alive.

const BUILDER := preload("res://scripts/environment/practice_facility_builder.gd")

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
## to the same lighting_contract ceilings as every competitive map. Near-black
## sky and low energies on purpose: the grid, holograms, and neon rings carry
## the scene, which is what makes practice read as a simulation.
func get_lighting_profile() -> Dictionary:
	return {
		"sky_top": Color(0.01, 0.02, 0.05),
		"sky_horizon": Color(0.02, 0.22, 0.30),
		"ambient": Color(0.35, 0.55, 0.70),
		"ambient_energy": 0.34,
		"sun_color": Color(0.55, 0.80, 1.0),
		"sun_energy": 0.5,
		"sun_rotation": Vector3(-60, -30, 0),
		"sun_size": 10.0,
		"sun_curve": 0.05,
		"fog": Color(0.02, 0.10, 0.16),
		"fog_energy": 0.5,
		"fog_density": 0.0009,
		"fog_sky_affect": 0.5,
		"glow_enabled": true,
		"glow_intensity": 1.15,
		"glow_strength": 1.0,
		"glow_bloom": 0.10,
	}


func register_spin(node: Node3D, speed: float, clockwise: bool) -> void:
	_spins.append({"node": node, "speed": speed, "clockwise": clockwise})


func register_bob(node: Node3D, speed: float, amplitude: float) -> void:
	_bobs.append({"node": node, "base": node.position, "speed": speed, "amplitude": amplitude})


func next_index() -> int:
	_next_index += 1
	return _next_index
