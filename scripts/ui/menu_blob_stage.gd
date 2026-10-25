class_name MenuBlobStage
extends "res://scripts/ui/shop_model_preview.gd"

## The main menu's hero: the player's real blob (same scene and cosmetics the
## shop preview uses) hopping on a glowing pedestal. Every hop squashes on
## take-off and landing; every third hop adds a full spin. Dragging still
## turns the blob by hand.

const BLOB_RADIUS := 2.8875
const HOP_PERIOD := 2.1
const HOP_HEIGHT := 1.5
const SPIN_EVERY := 3

var _clock := 0.0
var _reduced_motion := false
var _ring_material := StandardMaterial3D.new()
var _shadow: MeshInstance3D
var _squash_nodes: Array[Node3D] = []


func _ready() -> void:
	# A category the base class does not override: the equipped loadout shows.
	_category = "hero"
	super()
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_PARENT_VISIBLE
	_viewport.msaa_3d = Viewport.MSAA_4X
	for node_name in ["VisualRoot", "FaceRoot"]:
		var visual := _preview_player.get_node_or_null(node_name) as Node3D
		if visual != null:
			# BlobVisual rebuilds its basis every physics frame; the stage
			# drives the squash instead.
			visual.set_physics_process(false)
			_squash_nodes.append(visual)
	_build_pedestal()


func set_reduced_motion(enabled: bool) -> void:
	_reduced_motion = enabled


## Re-applies colour and the equipped cosmetics, e.g. after a swatch pick or
## a shop purchase.
func show_identity(color: Color) -> void:
	blob_tint = color
	_ring_material.albedo_color = color.lightened(0.2)
	_ring_material.emission = color
	_apply_item()


func _apply_item() -> void:
	super()
	if _camera != null:
		_camera.fov = 34.0
		_camera.look_at_from_position(Vector3(0.0, 2.6, 17.0), Vector3(0.0, 0.2, 0.0), Vector3.UP)


func _process(delta: float) -> void:
	if _model_root == null or not is_visible_in_tree():
		return
	_clock += delta
	var height := 0.0
	var squash := Vector2.ONE
	var spin := 0.0
	if _reduced_motion:
		height = 0.25 + sin(_clock * 1.4) * 0.18
	else:
		var hop_index := int(_clock / HOP_PERIOD)
		var u := fmod(_clock, HOP_PERIOD) / HOP_PERIOD
		if u < 0.12:
			var anticipation := sin(u / 0.12 * PI * 0.5)
			squash = Vector2(1.0 + 0.12 * anticipation, 1.0 - 0.15 * anticipation)
		elif u < 0.62:
			var x := (u - 0.12) / 0.5
			height = 4.0 * x * (1.0 - x) * HOP_HEIGHT
			var stretch := absf(1.0 - 2.0 * x)
			squash = Vector2(1.0 - 0.06 * stretch, 1.0 + 0.1 * stretch)
			if hop_index % SPIN_EVERY == SPIN_EVERY - 1:
				spin = _smoothstep(x) * TAU
		elif u < 0.84:
			var k := (u - 0.62) / 0.22
			var wobble := cos(k * PI * 3.0) * (1.0 - k)
			squash = Vector2(1.0 + 0.14 * wobble, 1.0 - 0.18 * wobble)
		else:
			var breathe := sin((u - 0.84) / 0.16 * PI) * 0.015
			squash = Vector2(1.0 + breathe, 1.0 - breathe)
	if not _dragging:
		_yaw = lerpf(_yaw, sin(_clock * 0.45) * 0.4, minf(1.0, delta * 1.6))
	# The face is modelled on -Z; turn it toward the camera.
	_model_root.rotation.y = PI + _yaw + spin
	_model_root.position.y = height
	# Squash only the meshes, about the blob's base so it stays planted: Jolt
	# rejects non-uniform scale on the body's collision shapes.
	for visual in _squash_nodes:
		visual.scale = Vector3(squash.x, squash.y, squash.x)
		visual.position.y = -BLOB_RADIUS * (1.0 - squash.y)
	if _shadow != null:
		var lift := clampf(height / HOP_HEIGHT, 0.0, 1.0)
		_shadow.scale = Vector3.ONE * (1.0 - 0.35 * lift) * squash.x
		_shadow.transparency = 0.2 + 0.5 * lift
	_ring_material.emission_energy_multiplier = 1.6 + sin(_clock * 2.4) * 0.5


func _build_pedestal() -> void:
	var floor_y := -BLOB_RADIUS - 0.02
	var disc := MeshInstance3D.new()
	disc.name = "PedestalDisc"
	var disc_mesh := CylinderMesh.new()
	disc_mesh.top_radius = 3.7
	disc_mesh.bottom_radius = 3.4
	disc_mesh.height = 0.6
	disc.mesh = disc_mesh
	var disc_material := StandardMaterial3D.new()
	disc_material.albedo_color = Color(0.05, 0.08, 0.16)
	disc_material.metallic = 0.4
	disc_material.roughness = 0.35
	disc.material_override = disc_material
	disc.position = Vector3(0.0, floor_y - 0.3, 0.0)
	_viewport.add_child(disc)

	var ring := MeshInstance3D.new()
	ring.name = "PedestalRing"
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 3.62
	ring_mesh.outer_radius = 3.8
	ring.mesh = ring_mesh
	_ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring_material.emission_enabled = true
	_ring_material.albedo_color = blob_tint.lightened(0.2)
	_ring_material.emission = blob_tint
	ring.material_override = _ring_material
	ring.position = Vector3(0.0, floor_y + 0.02, 0.0)
	_viewport.add_child(ring)

	_shadow = MeshInstance3D.new()
	_shadow.name = "BlobShadow"
	var shadow_mesh := PlaneMesh.new()
	shadow_mesh.size = Vector2(6.4, 6.4)
	_shadow.mesh = shadow_mesh
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.0, 0.0, 0.0, 0.7))
	gradient.set_color(1, Color(0.0, 0.0, 0.0, 0.0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	var shadow_material := StandardMaterial3D.new()
	shadow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_material.albedo_texture = texture
	_shadow.material_override = shadow_material
	_shadow.position = Vector3(0.0, floor_y + 0.04, 0.0)
	_viewport.add_child(_shadow)


static func _smoothstep(x: float) -> float:
	return x * x * (3.0 - 2.0 * x)
