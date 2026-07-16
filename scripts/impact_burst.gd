extends Node3D

@onready var particles: GPUParticles3D = $Particles

var _burst_color := Color.WHITE
var _burst_scale := 1.0
var _quality := 2
var _shockwave: MeshInstance3D
var _shockwave_material: StandardMaterial3D
var _flash: OmniLight3D


func configure(world_position: Vector3, color: Color, burst_scale: float = 1.0, quality: int = 2) -> void:
	global_position = world_position
	_burst_color = color
	_burst_scale = burst_scale
	_quality = clampi(quality, 0, 2)


func _ready() -> void:
	call_deferred("_start_burst")


func _start_burst() -> void:
	var mesh := particles.draw_pass_1.duplicate() as SphereMesh
	var material := mesh.material.duplicate() as StandardMaterial3D
	material.albedo_color = _burst_color
	material.emission = _burst_color
	mesh.material = material
	particles.draw_pass_1 = mesh
	particles.amount = maxi(6, int(18.0 * _burst_scale * [0.45, 0.72, 1.0][_quality]))
	particles.scale = Vector3.ONE * _burst_scale
	if _quality > 0:
		_create_shockwave()
	particles.restart()
	particles.emitting = true
	await get_tree().create_timer(particles.lifetime + 0.2).timeout
	queue_free()


func _create_shockwave() -> void:
	_shockwave = MeshInstance3D.new()
	_shockwave.name = "Shockwave"
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.38
	mesh.outer_radius = 0.56
	mesh.rings = 12
	mesh.ring_segments = 20
	_shockwave.mesh = mesh
	_shockwave_material = StandardMaterial3D.new()
	_shockwave_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_shockwave_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_shockwave_material.albedo_color = Color(_burst_color.r, _burst_color.g, _burst_color.b, 0.82)
	_shockwave_material.emission_enabled = true
	_shockwave_material.emission = _burst_color
	_shockwave_material.emission_energy_multiplier = 2.4
	_shockwave.material_override = _shockwave_material
	_shockwave.scale = Vector3.ONE * maxf(0.4, _burst_scale * 0.3)
	add_child(_shockwave)

	_flash = OmniLight3D.new()
	_flash.name = "ImpactFlash"
	_flash.light_color = _burst_color
	_flash.light_energy = 2.2 * _burst_scale
	_flash.omni_range = 4.5 * _burst_scale
	_flash.shadow_enabled = false
	add_child(_flash)

	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel(true)
	tween.tween_property(_shockwave, "scale", Vector3.ONE * maxf(1.1, _burst_scale * 2.5), 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_method(_set_shockwave_alpha, 0.82, 0.0, 0.3)
	tween.tween_property(_flash, "light_energy", 0.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _set_shockwave_alpha(alpha: float) -> void:
	if is_instance_valid(_shockwave_material):
		var color := _shockwave_material.albedo_color
		color.a = alpha
		_shockwave_material.albedo_color = color
