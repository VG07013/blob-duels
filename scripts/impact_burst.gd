extends Node3D

@onready var particles: GPUParticles3D = $Particles

var _burst_color := Color.WHITE
var _burst_scale := 1.0
var _quality := 2
var _style_id := "impact"
var _shockwave: MeshInstance3D
var _shockwave_material: StandardMaterial3D
var _flash: OmniLight3D


func configure(world_position: Vector3, color: Color, burst_scale: float = 1.0, quality: int = 2, style_id: String = "impact") -> void:
	global_position = world_position
	_burst_color = color
	_burst_scale = burst_scale
	_quality = clampi(quality, 0, 3)
	_style_id = style_id


func _ready() -> void:
	call_deferred("_start_burst")


func _start_burst() -> void:
	var mesh := _particle_mesh_for_style()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = _burst_color
	material.emission_enabled = true
	material.emission = _burst_color
	material.emission_energy_multiplier = 1.8 if _style_id != "smoke_puff" else 0.35
	mesh.material = material
	particles.draw_pass_1 = mesh
	var density := 1.35 if _style_id in ["confetti_burst", "pixel_explosion", "crystal_shatter", "supernova"] else 1.0
	particles.amount = maxi(6, int(18.0 * density * _burst_scale * [0.45, 0.72, 1.0, 1.35][_quality]))
	particles.scale = Vector3.ONE * _burst_scale
	if _quality > 0:
		_create_shockwave()
	particles.restart()
	particles.emitting = true
	await get_tree().create_timer(particles.lifetime + 0.2).timeout
	queue_free()


func _particle_mesh_for_style() -> PrimitiveMesh:
	if _style_id in ["confetti_burst", "sakura", "comic_boom"]:
		var quad := QuadMesh.new()
		quad.size = Vector2(0.22, 0.42)
		return quad
	if _style_id in ["pixel_explosion", "time_collapse", "crystal_shatter", "ice_break"]:
		var box := BoxMesh.new()
		box.size = Vector3(0.2, 0.2, 0.2) if _style_id == "pixel_explosion" else Vector3(0.12, 0.46, 0.12)
		return box
	if _style_id in ["lightning_strike", "meteor_crash", "firework"]:
		var streak := BoxMesh.new()
		streak.size = Vector3(0.08, 0.7, 0.08)
		return streak
	if _style_id == "ufo_beam":
		var beam := CylinderMesh.new()
		beam.top_radius = 0.08
		beam.bottom_radius = 0.16
		beam.height = 0.72
		return beam
	var sphere := SphereMesh.new()
	sphere.radius = 0.16 if _style_id == "bubble_pop" else 0.1
	sphere.height = sphere.radius * 2.0
	sphere.radial_segments = 8
	sphere.rings = 5
	return sphere


func _create_shockwave() -> void:
	_shockwave = MeshInstance3D.new()
	_shockwave.name = "Shockwave"
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.28 if _style_id in ["portal_collapse", "black_hole_burst", "time_collapse"] else 0.38
	mesh.outer_radius = 0.7 if _style_id in ["supernova", "meteor_crash"] else 0.56
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
	if _style_id in ["lightning_strike", "ufo_beam", "meteor_crash"]:
		_create_vertical_accent()

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


func _create_vertical_accent() -> void:
	var accent := MeshInstance3D.new()
	accent.name = "StyleAccent"
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.05 if _style_id == "lightning_strike" else 0.38
	mesh.bottom_radius = 0.18 if _style_id == "lightning_strike" else 0.72
	mesh.height = 5.8 if _style_id != "meteor_crash" else 2.4
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(_burst_color.r, _burst_color.g, _burst_color.b, 0.68)
	material.emission_enabled = true
	material.emission = _burst_color
	material.emission_energy_multiplier = 2.6
	mesh.material = material
	accent.mesh = mesh
	accent.position.y = mesh.height * 0.5
	add_child(accent)
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(accent, "scale", Vector3(0.02, 1.0, 0.02), 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _set_shockwave_alpha(alpha: float) -> void:
	if is_instance_valid(_shockwave_material):
		var color := _shockwave_material.albedo_color
		color.a = alpha
		_shockwave_material.albedo_color = color
