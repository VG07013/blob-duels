extends RefCounted

## Node construction for the holo training facility. All layout numbers come
## from PracticeFacilityGeometry; this file only turns tables into nodes.
##
## Hierarchy contract (asserted by practice_arena_geometry_contract): every
## MeshInstance3D is a DIRECT child of the host's PracticeVisuals root and every
## CollisionShape3D a DIRECT child of PracticeCollision. Bounce pads (Area3D)
## and lights hang off the scene root.

const GEOMETRY := preload("res://scripts/environment/practice_facility_geometry.gd")
const BOUNCE_PAD_SCENE: PackedScene = preload("res://scenes/world/bounce_pad.tscn")
const HOLO_FLOOR_SHADER: Shader = preload("res://assets/materials/holo_floor.gdshader")
const HOLO_WALL_SHADER: Shader = preload("res://assets/materials/holo_wall.gdshader")
const HOLOGRAM_DISPLAY_SHADER: Shader = preload("res://assets/materials/hologram_display.gdshader")

var _host: Node3D
var _deck_material: StandardMaterial3D
var _trim_materials: Dictionary = {}


func build(host: Node3D) -> void:
	_host = host
	_deck_material = _matte(GEOMETRY.COLOR_DECK, 0.55, 0.25)
	_build_shell()
	_build_hub()
	_build_fling_range()
	_build_ricochet_gallery()
	_build_bounce_towers()
	_build_spar_ring()
	_build_ramps()
	_build_signage()
	_build_dummy_spotlights()
	_build_bounce_pads()


## Shell -----------------------------------------------------------------------

func _build_shell() -> void:
	var floor_material := ShaderMaterial.new()
	floor_material.shader = HOLO_FLOOR_SHADER
	var ground := _add_box("FacilityGround", GEOMETRY.GROUND_CENTER, GEOMETRY.GROUND_SIZE, floor_material, true)
	ground.add_to_group("practice_environment_detail")

	var wall_material := ShaderMaterial.new()
	wall_material.shader = HOLO_WALL_SHADER
	var wall_specs := [
		{"name": "NorthPerimeterWall", "center": Vector3(0, GEOMETRY.WALL_CENTER_Y, -GEOMETRY.WALL_INNER - 1.0), "size": GEOMETRY.WALL_SIZE},
		{"name": "SouthPerimeterWall", "center": Vector3(0, GEOMETRY.WALL_CENTER_Y, GEOMETRY.WALL_INNER + 1.0), "size": GEOMETRY.WALL_SIZE},
		# E/W walls are 4 units shorter so they butt against the N/S walls'
		# inner faces instead of interpenetrating at the corners.
		{"name": "WestPerimeterWall", "center": Vector3(-GEOMETRY.WALL_INNER - 1.0, GEOMETRY.WALL_CENTER_Y, 0), "size": Vector3(GEOMETRY.WALL_SIZE.z, GEOMETRY.WALL_SIZE.y, GEOMETRY.WALL_SIZE.x - 4.0)},
		{"name": "EastPerimeterWall", "center": Vector3(GEOMETRY.WALL_INNER + 1.0, GEOMETRY.WALL_CENTER_Y, 0), "size": Vector3(GEOMETRY.WALL_SIZE.z, GEOMETRY.WALL_SIZE.y, GEOMETRY.WALL_SIZE.x - 4.0)},
	]
	for spec in wall_specs:
		# The hologram sheet is see-through; the collision is a plain solid box.
		# The room stays escape-proof no matter what the shader draws.
		var wall := _add_box(str(spec["name"]), spec["center"] as Vector3, spec["size"] as Vector3, wall_material, false)
		wall.add_to_group("practice_perimeter_wall")
		var wall_shape := _add_box_collision(str(spec["name"]), spec["center"] as Vector3, spec["size"] as Vector3)
		wall_shape.add_to_group("practice_perimeter_wall_collision")

	var roof_center := Vector3(0, GEOMETRY.ROOF_UNDERSIDE_Y + GEOMETRY.ROOF_SIZE.y * 0.5, 0)
	var roof := _add_box("FacilityRoof", roof_center, GEOMETRY.ROOF_SIZE, _matte(Color(0.02, 0.03, 0.05), 0.8, 0.0), false)
	roof.add_to_group("arena_roof")
	var roof_shape := _add_box_collision("FacilityRoof", roof_center, GEOMETRY.ROOF_SIZE)
	roof_shape.add_to_group("arena_roof_collision")
	_build_roof_light_strips()

	for pylon_position in GEOMETRY.PYLON_POSITIONS:
		var pylon := _add_box("SupportPylon", pylon_position, GEOMETRY.PYLON_SIZE, _deck_material, true, "structural_support")
		pylon.add_to_group("solid_visible_prop")
		_last_collision.add_to_group("solid_visible_prop_collision")
		# Emissive trim edge makes the pylons read against the dark shell.
		var trim := _add_box("SupportPylonTrim", pylon_position + Vector3(0, 0, 0.1), Vector3(GEOMETRY.PYLON_SIZE.x + 0.3, GEOMETRY.PYLON_SIZE.y, 0.2), _emissive(GEOMETRY.COLOR_STRUCTURE, 1.4), false)
		trim.add_to_group("practice_environment_detail")


## One MultiMesh of emissive strips across the roof underside - satisfies the
## "repeated decoration is batched" contract and lights the ceiling plane.
func _build_roof_light_strips() -> void:
	var strip := BoxMesh.new()
	strip.size = Vector3(24.0, 0.3, 1.2)
	strip.material = _emissive(GEOMETRY.COLOR_STRUCTURE, 1.1)
	var transforms: Array[Transform3D] = []
	for x in [-120.0, -40.0, 40.0, 120.0]:
		for z in [-120.0, -60.0, 0.0, 60.0, 120.0]:
			transforms.append(Transform3D(Basis.IDENTITY, Vector3(x, GEOMETRY.ROOF_UNDERSIDE_Y - 0.6, z)))
	var lights := _add_multimesh("RoofLightStrips", strip, transforms)
	lights.add_to_group("practice_environment_detail")


## Centre hub ------------------------------------------------------------------

func _build_hub() -> void:
	for ring_spec in GEOMETRY.HUB_FLOOR_RINGS:
		var ring := _add_torus("HubFloorRing", Vector3(0, 0.06, 0), float(ring_spec["radius"]), 0.15, _emissive(ring_spec["color"] as Color, 1.8), true)
		ring.add_to_group("practice_environment_detail")
	# The spinning core floats well above the fallback drop at (0, 6, 0).
	for index in range(GEOMETRY.HUB_CORE_RING_RADII.size()):
		var core_ring := _add_torus("HubCoreRing", Vector3(0, GEOMETRY.HUB_CORE_BASE_Y + float(index) * 2.0, 0), GEOMETRY.HUB_CORE_RING_RADII[index], 0.12, _emissive(GEOMETRY.COLOR_STRUCTURE if index % 2 == 0 else GEOMETRY.COLOR_TARGET, 2.0), false)
		core_ring.add_to_group("practice_environment_detail")
		_host.call("register_spin", core_ring, 0.35 + float(index) * 0.2, index % 2 == 0)
	var core := _add_sphere("HubCore", Vector3(0, GEOMETRY.HUB_CORE_BASE_Y + 2.0, 0), 1.1, _emissive(Color.WHITE, 2.4))
	core.add_to_group("practice_environment_detail")
	_host.call("register_bob", core, 0.8, 0.35)
	for disc_position in GEOMETRY.SPAWN_DISC_POSITIONS:
		var disc := _add_cylinder("SpawnDisc", disc_position, 3.0, 0.1, _emissive(GEOMETRY.COLOR_SAFE, 1.5), false)
		disc.add_to_group("practice_environment_detail")


## Zone 1 - fling range --------------------------------------------------------

func _build_fling_range() -> void:
	var tee := _add_cylinder("RangeTee", GEOMETRY.RANGE_TEE, 3.0, 0.12, _emissive(GEOMETRY.COLOR_MOVEMENT, 1.6), false)
	tee.add_to_group("practice_environment_detail")
	for rail_z in GEOMETRY.RANGE_RAIL_Z:
		var rail := _add_box("RangeRail", Vector3(GEOMETRY.RANGE_RAIL_CENTER_X, 0.1, float(rail_z)), GEOMETRY.RANGE_RAIL_SIZE, _emissive(GEOMETRY.COLOR_MOVEMENT, 1.0), false)
		rail.add_to_group("practice_environment_detail")

	var tick := BoxMesh.new()
	tick.size = GEOMETRY.RANGE_TICK_SIZE
	tick.material = _emissive(GEOMETRY.COLOR_STRUCTURE, 1.2)
	var tick_transforms: Array[Transform3D] = []
	for tick_x in GEOMETRY.RANGE_TICK_XS:
		tick_transforms.append(Transform3D(Basis.IDENTITY, Vector3(tick_x, 0.08, GEOMETRY.RANGE_LANE_Z)))
	var ticks := _add_multimesh("RangeTicks", tick, tick_transforms)
	ticks.add_to_group("practice_environment_detail")
	for index in range(GEOMETRY.RANGE_TICK_XS.size()):
		_add_label("RangeTickLabel", Vector3(GEOMETRY.RANGE_TICK_XS[index], 1.6, GEOMETRY.RANGE_LANE_Z - 14.5), "%dm" % [(index + 1) * 20], GEOMETRY.COLOR_STRUCTURE, 48)

	# TAP / FULL SEND arcs - x positions re-measured during calibration.
	var tap_arc := _add_box("RangeTapArc", Vector3(GEOMETRY.RANGE_TAP_ARC_X, 0.09, GEOMETRY.RANGE_LANE_Z), Vector3(1.1, 0.1, 28.0), _emissive(GEOMETRY.COLOR_SAFE, 1.8), false)
	tap_arc.add_to_group("practice_environment_detail")
	_add_label("RangeTapLabel", Vector3(GEOMETRY.RANGE_TAP_ARC_X, 3.2, GEOMETRY.RANGE_LANE_Z - 15.5), "TAP", GEOMETRY.COLOR_SAFE, 64)
	var full_arc := _add_box("RangeFullArc", Vector3(GEOMETRY.RANGE_FULL_ARC_X, 0.09, GEOMETRY.RANGE_LANE_Z), Vector3(1.1, 0.1, 28.0), _emissive(GEOMETRY.COLOR_TARGET, 1.8), false)
	full_arc.add_to_group("practice_environment_detail")
	_add_label("RangeFullLabel", Vector3(GEOMETRY.RANGE_FULL_ARC_X, 3.2, GEOMETRY.RANGE_LANE_Z - 15.5), "FULL SEND", GEOMETRY.COLOR_TARGET, 64)

	for ring_spec in GEOMETRY.RANGE_RINGS:
		_add_target_ring("RangeTargetRing", ring_spec["center"] as Vector3, float(ring_spec["radius"]))
	for ring_spec in GEOMETRY.EXTRA_RINGS:
		_add_target_ring("BonusTargetRing", ring_spec["center"] as Vector3, float(ring_spec["radius"]))
	_add_deck("RangeDeck", GEOMETRY.RANGE_DECK)


## Zone 2 - ricochet gallery ---------------------------------------------------

func _build_ricochet_gallery() -> void:
	for wall_spec in GEOMETRY.GALLERY_BANK_WALLS:
		var yaw: float = deg_to_rad(float(wall_spec["yaw_degrees"]))
		var bank := _add_box("GalleryBankWall", wall_spec["center"] as Vector3, GEOMETRY.GALLERY_BANK_SIZE, _deck_material, false, "", Vector3(0, yaw, 0))
		bank.add_to_group("solid_visible_prop")
		var bank_shape := _add_box_collision("GalleryBankWall", wall_spec["center"] as Vector3, GEOMETRY.GALLERY_BANK_SIZE, Vector3(0, yaw, 0))
		bank_shape.add_to_group("solid_visible_prop_collision")
		var edge := _add_box("GalleryBankEdge", (wall_spec["center"] as Vector3) + Vector3(0, GEOMETRY.GALLERY_BANK_SIZE.y * 0.5 + 0.15, 0), Vector3(GEOMETRY.GALLERY_BANK_SIZE.x, 0.3, GEOMETRY.GALLERY_BANK_SIZE.z), _emissive(GEOMETRY.COLOR_TARGET, 1.5), false, "", Vector3(0, yaw, 0))
		edge.add_to_group("practice_environment_detail")

	var chevron := PrismMesh.new()
	chevron.size = Vector3(3.0, 0.08, 2.0)
	chevron.material = _emissive(GEOMETRY.COLOR_TARGET, 1.1)
	var chevron_transforms: Array[Transform3D] = []
	for chevron_position in GEOMETRY.GALLERY_CHEVRON_POSITIONS:
		chevron_transforms.append(Transform3D(Basis.IDENTITY, chevron_position))
	var chevrons := _add_multimesh("GalleryChevrons", chevron, chevron_transforms)
	chevrons.add_to_group("practice_environment_detail")
	_add_deck("GalleryDeck", GEOMETRY.GALLERY_DECK)


## Zone 3 - bounce towers ------------------------------------------------------

func _build_bounce_towers() -> void:
	for deck_spec in GEOMETRY.TOWER_DECKS:
		_add_deck(str(deck_spec["prefix"]), deck_spec)


## Zone 4 - spar ring ----------------------------------------------------------

func _build_spar_ring() -> void:
	var floor_ring := _add_torus("SparFloorRing", GEOMETRY.SPAR_RING_CENTER, GEOMETRY.SPAR_RING_RADIUS, 0.18, _emissive(GEOMETRY.COLOR_TARGET, 1.6), true)
	floor_ring.add_to_group("practice_environment_detail")
	for ring_spec in GEOMETRY.SPAR_RINGS:
		_add_target_ring("SparTargetRing", ring_spec["center"] as Vector3, float(ring_spec["radius"]))
	_add_deck("SparDeck", GEOMETRY.SPAR_DECK)


## Ramps -----------------------------------------------------------------------

func _build_ramps() -> void:
	for ramp_spec in GEOMETRY.RAMPS:
		_add_closed_ramp(str(ramp_spec["prefix"]), ramp_spec["foot"] as Vector3, ramp_spec["toward"] as Vector3, GEOMETRY.deck_top_y(str(ramp_spec["deck"])))


## A watertight wedge whose top edge meets the deck with no collision lip, plus
## an 8-point convex collider built from the same vertices.
func _add_closed_ramp(prefix: String, foot: Vector3, toward: Vector3, deck_top: float) -> void:
	var runs_on_x := absf(toward.x) > 0.5
	var axis_sign := signf(toward.x if runs_on_x else toward.z)
	var half_run := GEOMETRY.RAMP_RUN * 0.5
	var half_width := GEOMETRY.RAMP_WIDTH * 0.5
	var slope_angle := atan(deck_top / GEOMETRY.RAMP_RUN)
	var half_thickness := cos(slope_angle) * GEOMETRY.RAMP_THICKNESS * 0.5
	var rise := deck_top
	var underside_y := -rise * 0.5 - half_thickness
	var low_surface_y := -rise * 0.5 + half_thickness
	var high_surface_y := rise * 0.5 + half_thickness
	var low_axis := -axis_sign * half_run
	var high_axis := axis_sign * half_run
	var points: PackedVector3Array
	if runs_on_x:
		points = PackedVector3Array([
			Vector3(low_axis, underside_y, -half_width), Vector3(low_axis, underside_y, half_width),
			Vector3(high_axis, underside_y, -half_width), Vector3(high_axis, underside_y, half_width),
			Vector3(low_axis, low_surface_y, -half_width), Vector3(low_axis, low_surface_y, half_width),
			Vector3(high_axis, high_surface_y, -half_width), Vector3(high_axis, high_surface_y, half_width),
		])
	else:
		points = PackedVector3Array([
			Vector3(-half_width, underside_y, low_axis), Vector3(half_width, underside_y, low_axis),
			Vector3(-half_width, underside_y, high_axis), Vector3(half_width, underside_y, high_axis),
			Vector3(-half_width, low_surface_y, low_axis), Vector3(half_width, low_surface_y, low_axis),
			Vector3(-half_width, high_surface_y, high_axis), Vector3(half_width, high_surface_y, high_axis),
		])
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_triangle(surface, points[0], points[3], points[2])
	_add_triangle(surface, points[0], points[1], points[3])
	_add_triangle(surface, points[4], points[7], points[5])
	_add_triangle(surface, points[4], points[6], points[7])
	_add_triangle(surface, points[0], points[5], points[1])
	_add_triangle(surface, points[0], points[4], points[5])
	_add_triangle(surface, points[2], points[7], points[6])
	_add_triangle(surface, points[2], points[3], points[7])
	_add_triangle(surface, points[0], points[6], points[4])
	_add_triangle(surface, points[0], points[2], points[6])
	_add_triangle(surface, points[1], points[7], points[3])
	_add_triangle(surface, points[1], points[5], points[7])
	surface.generate_normals()
	var mesh_resource := surface.commit()
	mesh_resource.surface_set_material(0, _emissive(GEOMETRY.COLOR_MOVEMENT, 0.55))

	var center := foot + toward * half_run
	# position.y + aabb.end.y must equal deck_top (the no-lip contract).
	var position := Vector3(center.x, deck_top * 0.5 - half_thickness, center.z)
	var instance := MeshInstance3D.new()
	instance.name = _unique_name(prefix)
	instance.mesh = mesh_resource
	instance.position = position
	instance.add_to_group("closed_ramp")
	_visuals().add_child(instance)

	var convex := ConvexPolygonShape3D.new()
	convex.points = points
	var shape := CollisionShape3D.new()
	shape.name = _unique_name(prefix + "Collision")
	shape.shape = convex
	shape.position = position
	shape.add_to_group("closed_ramp_collision")
	_collision_root().add_child(shape)


func _add_triangle(surface: SurfaceTool, first: Vector3, second: Vector3, third: Vector3) -> void:
	surface.add_vertex(first)
	surface.add_vertex(second)
	surface.add_vertex(third)


## Signage & spotlights --------------------------------------------------------

func _build_signage() -> void:
	for sign_spec in GEOMETRY.ZONE_SIGNS:
		var sign_label := _add_label("ZoneSign", sign_spec["position"] as Vector3, str(sign_spec["text"]), sign_spec["color"] as Color, 96, false)
		sign_label.rotation_degrees = Vector3(0, float(sign_spec["yaw_degrees"]), 0)
		sign_label.add_to_group("training_zone_label")
		# A hologram jumbotron panel behind each sign sells the simulation.
		var panel_material := ShaderMaterial.new()
		panel_material.shader = HOLOGRAM_DISPLAY_SHADER
		panel_material.set_shader_parameter("color_a", Color(sign_spec["color"] as Color, 1.0))
		panel_material.set_shader_parameter("color_b", Color(GEOMETRY.COLOR_STRUCTURE, 1.0))
		panel_material.set_shader_parameter("emission_strength", 1.4)
		var panel_offset := Vector3(0, 0, -0.6).rotated(Vector3.UP, deg_to_rad(float(sign_spec["yaw_degrees"])))
		var panel := _add_box("ZoneSignPanel", (sign_spec["position"] as Vector3) + panel_offset, Vector3(14.0, 5.0, 0.3), panel_material, false, "", Vector3(0, deg_to_rad(float(sign_spec["yaw_degrees"])), 0))
		panel.add_to_group("practice_environment_detail")


func _build_dummy_spotlights() -> void:
	# Bright discs under each fixed dummy position: keeps the dummies readable
	# against the dark floor and marks them as sanctioned targets.
	for dummy_position in GEOMETRY.DUMMY_POSITIONS:
		var spotlight := _add_cylinder("DummySpotlight", Vector3(dummy_position.x, 0.05, dummy_position.z), 4.2, 0.08, _emissive(GEOMETRY.COLOR_TARGET, 1.1), false)
		spotlight.add_to_group("practice_environment_detail")


func _build_bounce_pads() -> void:
	for pad_spec in GEOMETRY.BOUNCE_PADS:
		var pad := BOUNCE_PAD_SCENE.instantiate() as Area3D
		pad.name = _unique_name("BouncePad")
		pad.position = pad_spec["position"] as Vector3
		pad.launch_impulse = float(pad_spec["impulse"])
		_host.add_child(pad)


## Shared pieces ----------------------------------------------------------------

## An upright neon ring on a slim collidable stand. Rings themselves have no
## collision - shots and blobs pass through the hoop.
func _add_target_ring(prefix: String, center: Vector3, radius: float) -> void:
	var ring := _add_torus(prefix, center, radius, 0.25, _emissive(GEOMETRY.COLOR_TARGET, 2.0), false, true)
	ring.add_to_group("training_target_ring")
	ring.add_to_group("practice_environment_detail")
	var stand_height := center.y - radius
	if stand_height > 0.5:
		var stand_center := Vector3(center.x, stand_height * 0.5, center.z)
		var stand_size := Vector3(0.5, stand_height, 0.5)
		var stand := _add_box(prefix + "Stand", stand_center, stand_size, _deck_material, true)
		stand.add_to_group("solid_visible_prop")
		_last_collision.add_to_group("solid_visible_prop_collision")


func _add_deck(prefix: String, deck_spec: Dictionary) -> void:
	var center := deck_spec["center"] as Vector3
	var size := deck_spec["size"] as Vector3
	var deck := _add_box(prefix, center, size, _deck_material, true)
	deck.add_to_group("solid_visible_prop")
	_last_collision.add_to_group("solid_visible_prop_collision")
	var rim := _add_box(prefix + "Rim", center + Vector3(0, size.y * 0.5 + 0.1, 0), Vector3(size.x + 0.4, 0.2, size.z + 0.4), _emissive(GEOMETRY.COLOR_MOVEMENT, 1.2), false)
	rim.add_to_group("practice_environment_detail")
	# Corner legs ground every deck: they touch the deck underside and the
	# floor exactly (no interpenetration - the geometry contract ratchet is 0).
	var leg_height := center.y - size.y * 0.5
	if leg_height > 1.0:
		for corner in [Vector3(-1, 0, -1), Vector3(1, 0, 1)]:
			var leg_position := Vector3(center.x + corner.x * (size.x * 0.5 - 1.0), leg_height * 0.5, center.z + corner.z * (size.z * 0.5 - 1.0))
			var leg := _add_box(prefix + "Leg", leg_position, Vector3(1.4, leg_height, 1.4), _deck_material, true, "structural_support")
			leg.add_to_group("solid_visible_prop")
			_last_collision.add_to_group("solid_visible_prop_collision")


## Primitive helpers ------------------------------------------------------------

var _last_collision: CollisionShape3D


func _add_box(prefix: String, position: Vector3, size: Vector3, material: Material, collision: bool, support_group: String = "", rotation: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.name = _unique_name(prefix)
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position
	instance.rotation = rotation
	if not collision:
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if not support_group.is_empty():
		instance.add_to_group(support_group)
	_visuals().add_child(instance)
	if collision:
		_last_collision = _add_box_collision(prefix, position, size, rotation)
	return instance


func _add_box_collision(prefix: String, position: Vector3, size: Vector3, rotation: Vector3 = Vector3.ZERO) -> CollisionShape3D:
	var shape_resource := BoxShape3D.new()
	shape_resource.size = size
	var shape := CollisionShape3D.new()
	shape.name = _unique_name(prefix + "Collision")
	shape.shape = shape_resource
	shape.position = position
	shape.rotation = rotation
	_collision_root().add_child(shape)
	return shape


func _add_cylinder(prefix: String, position: Vector3, radius: float, height: float, material: Material, collision: bool) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 32
	var instance := MeshInstance3D.new()
	instance.name = _unique_name(prefix)
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visuals().add_child(instance)
	if collision:
		var shape_resource := CylinderShape3D.new()
		shape_resource.radius = radius
		shape_resource.height = height
		var shape := CollisionShape3D.new()
		shape.name = _unique_name(prefix + "Collision")
		shape.shape = shape_resource
		shape.position = position
		_collision_root().add_child(shape)
		_last_collision = shape
	return instance


func _add_torus(prefix: String, position: Vector3, radius: float, tube: float, material: Material, flat_on_floor: bool, upright: bool = false) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - tube
	mesh.outer_radius = radius + tube
	var instance := MeshInstance3D.new()
	instance.name = _unique_name(prefix)
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position
	if upright:
		# Torus lies in XZ by default; stand it in the XY plane facing the lane.
		instance.rotation_degrees = Vector3(90, 90, 0)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visuals().add_child(instance)
	return instance


func _add_sphere(prefix: String, position: Vector3, radius: float, material: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 24
	mesh.rings = 12
	var instance := MeshInstance3D.new()
	instance.name = _unique_name(prefix)
	instance.mesh = mesh
	instance.material_override = material
	instance.position = position
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visuals().add_child(instance)
	return instance


func _add_multimesh(prefix: String, mesh: Mesh, transforms: Array[Transform3D]) -> MultiMeshInstance3D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for index in range(transforms.size()):
		multimesh.set_instance_transform(index, transforms[index])
	var instance := MultiMeshInstance3D.new()
	instance.name = _unique_name(prefix)
	instance.multimesh = multimesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visuals().add_child(instance)
	return instance


func _add_label(prefix: String, position: Vector3, text: String, color: Color, font_size: int, billboard: bool = true) -> Label3D:
	var label := Label3D.new()
	label.name = _unique_name(prefix)
	label.position = position
	label.text = text
	label.font_size = font_size
	label.outline_size = 10
	label.modulate = color
	if billboard:
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_visuals().add_child(label)
	return label


func _matte(color: Color, roughness: float, metallic: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material


func _emissive(color: Color, energy: float) -> StandardMaterial3D:
	var material := _matte(color.darkened(0.12), 0.34, 0.12)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material


func _visuals() -> Node3D:
	return _host.get_node("PracticeVisuals") as Node3D


func _collision_root() -> StaticBody3D:
	return _host.get_node("PracticeCollision") as StaticBody3D


func _unique_name(prefix: String) -> String:
	return "%s_%03d" % [prefix, _host.call("next_index")]
