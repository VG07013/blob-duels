extends RefCounted

## Node construction for Bounceground. Every number comes from
## BouncegroundGeometry; this file only turns those tables into nodes.
##
## Structure (built under the BouncegroundArena host):
## - BouncegroundVisuals: one Node3D per authored piece (walls, decks, ramps,
##   covers, mound), each holding its meshes. Route pieces carry
##   footprint_* metadata in the overlap_audit group.
## - One StaticBody3D per surface family, so a collider picks up its physics
##   material from its body: CourtCollision (normal), WallCollision (bounce),
##   RampCollision (grip), GlassCollision (ice - keeps momentum along the lid).
## - Interactables (launch pads), SpawnPoints, DuelFlow anchors.
##
## Returns the map audit dictionary consumed by the map contracts.

const GEOMETRY := preload("res://scripts/environment/bounceground_geometry.gd")
const TEXTURE_NORMALS := preload("res://scripts/environment/texture_normal_library.gd")
const LAUNCH_PAD_SCENE := preload("res://scenes/interactables/launch_pad.tscn")
const PAINTED_PANELS_TEXTURE: Texture2D = preload("res://assets/environment/textures/painted_panels.svg")
const TOY_PLASTIC_TEXTURE: Texture2D = preload("res://assets/environment/textures/toy_plastic.svg")
const CONCRETE_TEXTURE: Texture2D = preload("res://assets/textures/concrete.png")
const LINE_WIDTH := 0.5
const LINE_LIFT := 0.02

var _host: Node3D
var _visuals: Node3D
var _court_body: StaticBody3D
var _wall_body: StaticBody3D
var _ramp_body: StaticBody3D
var _glass_body: StaticBody3D
var _materials: Dictionary = {}
var _counter := 0


func build(host: Node3D) -> Dictionary:
	_host = host
	_visuals = host.get_node("BouncegroundVisuals") as Node3D
	_court_body = host.get_node("CourtCollision") as StaticBody3D
	_wall_body = host.get_node("WallCollision") as StaticBody3D
	_ramp_body = host.get_node("RampCollision") as StaticBody3D
	_glass_body = host.get_node("GlassCollision") as StaticBody3D
	_build_materials()
	_build_floor()
	_build_court_markings()
	_build_perimeter()
	_build_glass_lid()
	_build_spawn_decks()
	_build_side_decks()
	_build_ramps()
	_build_mound()
	_build_covers()
	_build_pads()
	_build_flow_anchors()
	return _audit()


## Materials -------------------------------------------------------------------

func _build_materials() -> void:
	_materials = {
		"court": _textured(CONCRETE_TEXTURE, GEOMETRY.COLOR_COURT, 0.9, 0.05),
		"lawn": _textured(CONCRETE_TEXTURE, GEOMETRY.COLOR_LAWN, 1.0, 0.03),
		"line": _matte(GEOMETRY.COLOR_LINE, 0.6),
		"wall": _textured(TOY_PLASTIC_TEXTURE, GEOMETRY.COLOR_WALL, 0.7, 0.12),
		"wall_base": _matte(GEOMETRY.COLOR_WALL_BASE, 0.8),
		"wall_trim": _glowing(GEOMETRY.COLOR_WALL_TRIM, 0.55),
		"deck": _textured(PAINTED_PANELS_TEXTURE, GEOMETRY.COLOR_DECK, 0.72, 0.1),
		"deck_side": _textured(PAINTED_PANELS_TEXTURE, GEOMETRY.COLOR_DECK_SIDE, 0.78, 0.1),
		"ramp": _textured(TOY_PLASTIC_TEXTURE, GEOMETRY.COLOR_RAMP, 0.82, 0.12),
		"chevron": _glowing(GEOMETRY.COLOR_CHEVRON, 0.35),
		"cover": _textured(TOY_PLASTIC_TEXTURE, GEOMETRY.COLOR_COVER, 0.7, 0.14),
		"cover_cap": _matte(GEOMETRY.COLOR_COVER_CAP, 0.6),
		"mound": _textured(TOY_PLASTIC_TEXTURE, GEOMETRY.COLOR_MOUND, 0.68, 0.14),
		"mound_top": _textured(TOY_PLASTIC_TEXTURE, GEOMETRY.COLOR_MOUND_TOP, 0.7, 0.14),
		"red": _textured(TOY_PLASTIC_TEXTURE, GEOMETRY.COLOR_RED, 0.62, 0.14),
		"blue": _textured(TOY_PLASTIC_TEXTURE, GEOMETRY.COLOR_BLUE, 0.62, 0.14),
		"red_glow": _glowing(GEOMETRY.COLOR_RED, 0.8),
		"blue_glow": _glowing(GEOMETRY.COLOR_BLUE, 0.8),
		"glass": _glass(GEOMETRY.COLOR_GLASS),
		"frame": _matte(GEOMETRY.COLOR_FRAME, 0.5),
	}


func _matte(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material


## World-space triplanar mapping keeps texture scale identical on every box,
## ramp and hull regardless of its size, and needs no mesh UVs.
func _textured(texture: Texture2D, tint: Color, roughness: float, world_scale: float) -> StandardMaterial3D:
	var material := _matte(tint, roughness)
	material.albedo_texture = texture
	material.uv1_triplanar = true
	material.uv1_world_triplanar = true
	material.uv1_scale = Vector3.ONE * world_scale
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var normal_map := TEXTURE_NORMALS.normal_for(texture)
	if normal_map != null:
		material.normal_enabled = true
		material.normal_texture = normal_map
	return material


func _glowing(color: Color, energy: float) -> StandardMaterial3D:
	var material := _matte(color, 0.45)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material


func _glass(color: Color) -> StandardMaterial3D:
	var material := _matte(color, 0.05)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.metallic_specular = 0.8
	return material


## Floor ---------------------------------------------------------------------------

func _build_floor() -> void:
	var piece := _piece("Court")
	var floor_size := Vector3(GEOMETRY.FOOTPRINT.x, GEOMETRY.FLOOR_THICKNESS, GEOMETRY.FOOTPRINT.y)
	_box(piece, "CourtFloor", Vector3(0.0, -GEOMETRY.FLOOR_THICKNESS * 0.5, 0.0), floor_size, _materials["court"], _court_body)
	# Open lawn out to the horizon, so the view through the glass lid shows
	# the court sitting on the ground rather than floating in the sky.
	var lawn := _box(piece, "Lawn", Vector3(0.0, -GEOMETRY.FLOOR_THICKNESS - 0.5, 0.0), Vector3(GEOMETRY.LAWN_SIZE, 1.0, GEOMETRY.LAWN_SIZE), _materials["lawn"], null)
	lawn.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _build_court_markings() -> void:
	var piece := _piece("CourtMarkings")
	var line: Material = _materials["line"]
	var inset := 4.0
	var run_x := GEOMETRY.INNER_X - inset
	var run_z := GEOMETRY.INNER_Z - inset
	# Boundary rectangle.
	for side in [-1.0, 1.0]:
		_line(piece, Vector3(side * run_x, 0.0, 0.0), Vector2(LINE_WIDTH, run_z * 2.0), line)
		_line(piece, Vector3(0.0, 0.0, side * run_z), Vector2(run_x * 2.0, LINE_WIDTH), line)
	# Halfway line broken by the mound, stopping short of the side decks.
	var half_start := GEOMETRY.MOUND_BASE_RADIUS + 3.0
	var half_end := GEOMETRY.SIDE_DECK_INNER_X - 3.0
	for side in [-1.0, 1.0]:
		_line(piece, Vector3(side * (half_start + half_end) * 0.5, 0.0, 0.0), Vector2(half_end - half_start, LINE_WIDTH), line)
	# Centre ring around the mound.
	_flat_ring(piece, "CentreRing", Vector3(0.0, LINE_LIFT, 0.0), GEOMETRY.MOUND_BASE_RADIUS + 2.0, LINE_WIDTH, line)
	# Team "keys" in front of each spawn ramp.
	for spawn in GEOMETRY.SPAWNS:
		var side := float(spawn["side"])
		var key_near := GEOMETRY.SPAWN_DECK_FRONT_Z - GEOMETRY.SPAWN_RAMP_RUN
		var key_far := key_near - 10.0
		var key_half := GEOMETRY.SPAWN_DECK_WIDTH * 0.5
		var team_line: Material = _materials["red_glow" if side > 0.0 else "blue_glow"]
		_line(piece, Vector3(0.0, 0.0, side * key_far), Vector2(key_half * 2.0, LINE_WIDTH), team_line)
		for x_side in [-1.0, 1.0]:
			_line(piece, Vector3(x_side * key_half, 0.0, side * (key_near + key_far) * 0.5), Vector2(LINE_WIDTH, key_near - key_far), team_line)


func _line(parent: Node3D, center: Vector3, size: Vector2, material: Material) -> void:
	var mesh := _box(parent, "CourtLine", center + Vector3.UP * LINE_LIFT, Vector3(size.x, 0.02, size.y), material, null)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## A painted ring lying flat: a torus squashed to a few centimetres.
func _flat_ring(parent: Node3D, prefix: String, center: Vector3, radius: float, width: float, material: Material) -> void:
	var ring := MeshInstance3D.new()
	ring.name = _name(prefix)
	var torus := TorusMesh.new()
	torus.inner_radius = radius
	torus.outer_radius = radius + width
	torus.rings = 64
	torus.ring_segments = 6
	ring.mesh = torus
	ring.material_override = material
	ring.scale = Vector3(1.0, 0.08, 1.0)
	ring.position = center
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(ring)


## Perimeter -----------------------------------------------------------------------

func _build_perimeter() -> void:
	var piece := _piece("PerimeterWalls")
	var height := GEOMETRY.WALL_HEIGHT
	var thickness := GEOMETRY.WALL_THICKNESS
	var long_x := GEOMETRY.HALF_WIDTH - thickness * 0.5
	var end_z := GEOMETRY.HALF_LENGTH - thickness * 0.5
	# [name, centre, size, inward normal, inner face length]
	var walls := [
		["WestWall", Vector3(-long_x, height * 0.5, 0.0), Vector3(thickness, height, GEOMETRY.FOOTPRINT.y), Vector3.RIGHT],
		["EastWall", Vector3(long_x, height * 0.5, 0.0), Vector3(thickness, height, GEOMETRY.FOOTPRINT.y), Vector3.LEFT],
		["RedEndWall", Vector3(0.0, height * 0.5, end_z), Vector3(GEOMETRY.INNER_X * 2.0, height, thickness), Vector3.FORWARD],
		["BlueEndWall", Vector3(0.0, height * 0.5, -end_z), Vector3(GEOMETRY.INNER_X * 2.0, height, thickness), Vector3.BACK],
	]
	for wall in walls:
		var wall_name := str(wall[0])
		var center := wall[1] as Vector3
		var size := wall[2] as Vector3
		var inward := wall[3] as Vector3
		_box(piece, wall_name, center, size, _materials["wall"], _wall_body)
		# Inner face dressing: a dark kick plate at the floor and a glowing
		# bounce stripe near the top, both a few centimetres proud of the face.
		var face := center + inward * (thickness * 0.5 + 0.04)
		var strip := Vector3(0.08, 0.0, GEOMETRY.INNER_Z * 2.0) if absf(inward.x) > 0.5 else Vector3(GEOMETRY.INNER_X * 2.0, 0.0, 0.08)
		_box(piece, wall_name + "KickPlate", Vector3(face.x, 0.6, face.z), Vector3(strip.x, 1.2, strip.z), _materials["wall_base"], null)
		_box(piece, wall_name + "BounceStripe", Vector3(face.x, height - 1.6, face.z), Vector3(strip.x, 0.7, strip.z), _materials["wall_trim"], null)
		_box(piece, wall_name + "Cap", center + Vector3.UP * (height * 0.5 + 0.2), Vector3(size.x + 0.4, 0.4, size.z + 0.4), _materials["frame"], null)
	# Rounded corner posts fill the four corners so nothing wedges there.
	for x_side in [-1.0, 1.0]:
		for z_side in [-1.0, 1.0]:
			var post := Vector3(x_side * GEOMETRY.INNER_X, 0.0, z_side * GEOMETRY.INNER_Z)
			_cylinder(piece, "CornerPost", post + Vector3.UP * height * 0.5, GEOMETRY.CORNER_POST_RADIUS, height, _materials["wall"], _wall_body)
			_cylinder(piece, "CornerPostCap", post + Vector3.UP * (height + 0.2), GEOMETRY.CORNER_POST_RADIUS + 0.2, 0.4, _materials["wall_trim"], null)


func _build_glass_lid() -> void:
	var piece := _piece("GlassLid")
	piece.add_to_group("arena_roof")
	var glass: Material = _materials["glass"]
	var glass_height := GEOMETRY.ROOF_HEIGHT - GEOMETRY.WALL_HEIGHT
	var glass_y := GEOMETRY.WALL_HEIGHT + glass_height * 0.5
	var t := GEOMETRY.GLASS_THICKNESS
	var x := GEOMETRY.HALF_WIDTH - GEOMETRY.WALL_THICKNESS * 0.5
	var z := GEOMETRY.HALF_LENGTH - GEOMETRY.WALL_THICKNESS * 0.5
	for side in [-1.0, 1.0]:
		_glass_panel(piece, "SideGlass", Vector3(side * x, glass_y, 0.0), Vector3(t, glass_height, GEOMETRY.FOOTPRINT.y), glass)
		_glass_panel(piece, "EndGlass", Vector3(0.0, glass_y, side * z), Vector3(GEOMETRY.FOOTPRINT.x, glass_height, t), glass)
	var roof_y := GEOMETRY.ROOF_HEIGHT + GEOMETRY.ROOF_THICKNESS * 0.5
	_glass_panel(piece, "RoofGlass", Vector3(0.0, roof_y, 0.0), Vector3(GEOMETRY.FOOTPRINT.x, GEOMETRY.ROOF_THICKNESS, GEOMETRY.FOOTPRINT.y), glass)
	# Thin frame bars give the near-invisible lid a readable edge.
	var frame: Material = _materials["frame"]
	var frame_y := GEOMETRY.ROOF_HEIGHT + GEOMETRY.ROOF_THICKNESS + 0.15
	var spacing := GEOMETRY.ROOF_FRAME_SPACING
	var x_steps := int(floor(GEOMETRY.HALF_WIDTH / spacing))
	var z_steps := int(floor(GEOMETRY.HALF_LENGTH / spacing))
	for index in range(-x_steps, x_steps + 1):
		_frame_bar(piece, Vector3(float(index) * spacing, frame_y, 0.0), Vector3(0.3, 0.3, GEOMETRY.FOOTPRINT.y), frame)
	for index in range(-z_steps, z_steps + 1):
		_frame_bar(piece, Vector3(0.0, frame_y, float(index) * spacing), Vector3(GEOMETRY.FOOTPRINT.x, 0.3, 0.3), frame)
	for x_side in [-1.0, 1.0]:
		for z_side in [-1.0, 1.0]:
			_frame_bar(piece, Vector3(x_side * x, glass_y, z_side * z), Vector3(0.5, glass_height, 0.5), frame)


func _glass_panel(parent: Node3D, prefix: String, center: Vector3, size: Vector3, material: Material) -> void:
	var mesh := _box(parent, prefix, center, size, material, _glass_body)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _frame_bar(parent: Node3D, center: Vector3, size: Vector3, material: Material) -> void:
	var mesh := _box(parent, "LidFrame", center, size, material, null)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Spawn decks and side decks ------------------------------------------------------

func _build_spawn_decks() -> void:
	for spawn in GEOMETRY.SPAWNS:
		var side := float(spawn["side"])
		var team := str(spawn["team"])
		var piece := _piece("%sSpawnDeck" % team.capitalize())
		var center := GEOMETRY.spawn_deck_center(side)
		var size := GEOMETRY.spawn_deck_size()
		var height := GEOMETRY.SPAWN_DECK_HEIGHT
		_box(piece, "DeckBody", GEOMETRY.world(center, height * 0.5), Vector3(size.x, height, size.y), _materials[team], _court_body)
		# Glowing lip along the front edge, laid on the top face.
		_box(piece, "DeckLip", Vector3(0.0, height + 0.05, side * (GEOMETRY.SPAWN_DECK_FRONT_Z + 0.4)), Vector3(size.x, 0.1, 0.8), _materials[team + "_glow"], null)
		_flat_ring(piece, "SpawnRing", Vector3(0.0, height + 0.03, side * GEOMETRY.SPAWN_MARKER_Z), 4.2, 0.6, _materials["line"])
		_mark_footprint(piece, center, size)
		var marker := Marker3D.new()
		marker.name = str(spawn["name"])
		marker.position = GEOMETRY.spawn_position(side)
		marker.rotation.y = GEOMETRY.spawn_yaw(side)
		_host.get_node("SpawnPoints").add_child(marker)


func _build_side_decks() -> void:
	for x_side in [-1.0, 1.0]:
		var piece := _piece("%sDeck" % ("West" if x_side < 0.0 else "East"))
		var center := Vector2(x_side * GEOMETRY.SIDE_DECK_CENTER_X, 0.0)
		var size := Vector2(GEOMETRY.SIDE_DECK_WIDTH, GEOMETRY.SIDE_DECK_HALF_Z * 2.0)
		var height := GEOMETRY.SIDE_DECK_HEIGHT
		_box(piece, "DeckBody", GEOMETRY.world(center, height * 0.5), Vector3(size.x, height, size.y), _materials["deck_side"], _court_body)
		# A thin top plate in the lighter deck colour reads as a walkable
		# surface against the darker sides.
		_box(piece, "DeckTop", GEOMETRY.world(center, height + 0.03), Vector3(size.x, 0.06, size.y), _materials["deck"], null)
		_box(piece, "DeckEdge", Vector3(x_side * (GEOMETRY.SIDE_DECK_INNER_X + 0.3), height + 0.08, 0.0), Vector3(0.6, 0.1, size.y), _materials["wall_trim"], null)
		_mark_footprint(piece, center, size)
		piece.add_to_group("elevated_route")
		piece.set_meta("deck_top", height)
		piece.set_meta("deck_probe", GEOMETRY.world(center, height))


## Ramps -------------------------------------------------------------------------------

func _build_ramps() -> void:
	var ramps: Array[Dictionary] = GEOMETRY.side_ramps()
	for spawn in GEOMETRY.SPAWNS:
		ramps.append(GEOMETRY.spawn_ramp(float(spawn["side"])))
	for ramp in ramps:
		_build_ramp(ramp)


## A closed wedge: flat on the floor, rising along Z from 0 at its low end to
## `height` where it meets its deck. Mesh and convex collider share vertices.
func _build_ramp(ramp: Dictionary) -> void:
	var ramp_name := str(ramp["name"])
	var piece := _piece(ramp_name)
	var center := ramp["center"] as Vector2
	var size := ramp["size"] as Vector2
	var height := float(ramp["height"])
	var rise := float(ramp["rise_toward"])
	var half_x := size.x * 0.5
	var low_z := -rise * size.y * 0.5
	var high_z := rise * size.y * 0.5
	# The low edge keeps a hair of thickness so the hull is never degenerate.
	var bottom := [Vector3(-half_x, 0.0, low_z), Vector3(half_x, 0.0, low_z), Vector3(half_x, 0.0, high_z), Vector3(-half_x, 0.0, high_z)]
	var top := [Vector3(-half_x, 0.02, low_z), Vector3(half_x, 0.02, low_z), Vector3(half_x, height, high_z), Vector3(-half_x, height, high_z)]
	var origin := GEOMETRY.world(center)
	_hull(piece, ramp_name + "Surface", origin, bottom, top, _materials["ramp"], _ramp_body)
	_mark_footprint(piece, center, size)
	# Chevrons pointing up the slope, laid on the surface.
	var slope := atan2(height, size.y)
	for t in [0.3, 0.62]:
		var z_local := lerpf(low_z, high_z, float(t))
		var chevron_center := origin + Vector3(0.0, height * float(t) + 0.06, z_local)
		for bar_sign in [-1.0, 1.0]:
			var bar := _box(piece, "RampChevron", chevron_center + Vector3(bar_sign * 1.4, 0.0, -rise * 0.7), Vector3(4.2, 0.06, 0.7), _materials["chevron"], null)
			# Yaw the bar flat first, then tilt it onto the slope, so it lies in the
			# ramp plane. Rotating about +X by -slope tilts up toward +Z travel.
			bar.basis = Basis(Vector3.RIGHT, -rise * slope) * Basis(Vector3.UP, bar_sign * rise * PI * 0.25)
			bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Centre mound ------------------------------------------------------------------------

func _build_mound() -> void:
	var piece := _piece("CentreMound")
	piece.add_to_group("map_landmark")
	var bottom: Array = []
	var top: Array = []
	for index in range(GEOMETRY.MOUND_SIDES):
		# Offset by half a step so a flat face, not a corner, faces each spawn.
		var angle := TAU * (float(index) + 0.5) / float(GEOMETRY.MOUND_SIDES)
		var direction := Vector3(cos(angle), 0.0, sin(angle))
		bottom.append(direction * GEOMETRY.MOUND_BASE_RADIUS)
		top.append(direction * GEOMETRY.MOUND_TOP_RADIUS + Vector3.UP * GEOMETRY.MOUND_HEIGHT)
	_hull(piece, "MoundSurface", Vector3.ZERO, bottom, top, _materials["mound"], _court_body)
	var cap := _cylinder(piece, "MoundCap", Vector3(0.0, GEOMETRY.MOUND_HEIGHT + 0.03, 0.0), GEOMETRY.MOUND_TOP_RADIUS * 0.82, 0.06, _materials["mound_top"], null)
	cap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var diameter := GEOMETRY.MOUND_BASE_RADIUS * 2.0
	_mark_footprint(piece, Vector2.ZERO, Vector2(diameter, diameter))


## Cover -------------------------------------------------------------------------------

func _build_covers() -> void:
	for cover in GEOMETRY.COVERS:
		var piece := _piece(str(cover["name"]))
		var center := cover["center"] as Vector2
		var size := cover["size"] as Vector2
		var height := GEOMETRY.COVER_HEIGHT
		var body := _box(piece, "CoverBody", GEOMETRY.world(center, height * 0.5), Vector3(size.x, height, size.y), _materials["cover"], _court_body)
		# The cap sits into the block with its top just proud of it, so a blob
		# resting on top is never visibly sunk into the trim.
		_box(piece, "CoverCap", GEOMETRY.world(center, height - 0.18), Vector3(size.x + 0.3, 0.4, size.y + 0.3), _materials["cover_cap"], null)
		body.add_to_group("duel_cover")
		body.set_meta("flow_lane", str(cover["lane"]))
		body.set_meta("cover_role", str(cover["role"]))
		_mark_footprint(piece, center, size)


## Launch pads -------------------------------------------------------------------------

func _build_pads() -> void:
	var interactables := _host.get_node("Interactables") as Node3D
	for pad_spec in GEOMETRY.PADS:
		var pad := LAUNCH_PAD_SCENE.instantiate() as Area3D
		pad.name = str(pad_spec["name"])
		pad.position = GEOMETRY.world(pad_spec["at"] as Vector2, float(pad_spec["height"]) + 0.05)
		var leads_to_center := bool(pad_spec["center"])
		var color := GEOMETRY.PAD_COLOR_FEED if leads_to_center else GEOMETRY.PAD_COLOR_DECK
		pad.call("configure", pad_spec["direction"] as Vector3, float(pad_spec["strength"]), color)
		pad.set_meta("duel_purpose", str(pad_spec["purpose"]))
		pad.set_meta("leads_to_center", leads_to_center)
		pad.add_to_group("intentional_interactable")
		interactables.add_child(pad)


## Duel flow ---------------------------------------------------------------------------

func _build_flow_anchors() -> void:
	var flow_root := _host.get_node("DuelFlow") as Node3D
	for anchor in GEOMETRY.FLOW_ANCHORS:
		var marker := Marker3D.new()
		marker.name = str(anchor["name"])
		marker.position = GEOMETRY.world(anchor["at"] as Vector2, float(anchor["height"]) + 1.0)
		marker.set_meta("flow_role", str(anchor["role"]))
		marker.set_meta("flow_lane", str(anchor["lane"]))
		marker.add_to_group("duel_flow_anchor")
		flow_root.add_child(marker)


func _audit() -> Dictionary:
	var pad_names: Array[String] = []
	for pad_spec in GEOMETRY.PADS:
		pad_names.append("%s (%s)" % [pad_spec["name"], pad_spec["purpose"]])
	return {
		"identity": "Bounceground: a big rubber sports court with bouncy padded walls and a glass lid",
		"landmark": "Centre mound",
		"routes": ["Centre lane over the mound", "West deck via its two ramps", "East deck via its two ramps"],
		"interactables": pad_names,
		"prop_families": ["court markings", "padded bounce walls", "glass lid", "team spawn decks"],
		"flow_plan": [
			"Spawn ramp down to the team key, feeder pad toward the mound",
			"Flank ramp up to a side deck, dive pad back into the centre",
			"Deck lift from beside the centre screens up to high ground",
		],
		"combat_spaces": [
			"Centre mound between the two screens",
			"Side decks overlooking the court",
			"Approach walls and flank blocks in each half",
		],
		"blueprint": {"footprint": GEOMETRY.FOOTPRINT},
	}


## Primitive helpers -------------------------------------------------------------------

func _piece(piece_name: String) -> Node3D:
	var piece := Node3D.new()
	piece.name = piece_name
	_visuals.add_child(piece)
	return piece


func _mark_footprint(piece: Node3D, center: Vector2, size: Vector2) -> void:
	piece.add_to_group("overlap_audit")
	piece.set_meta("footprint_center", center)
	piece.set_meta("footprint_size", size)
	piece.set_meta("footprint_yaw", 0.0)


func _box(parent: Node3D, prefix: String, center: Vector3, size: Vector3, material: Material, body: StaticBody3D) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.name = _name(prefix)
	instance.mesh = mesh
	instance.material_override = material
	instance.position = center
	parent.add_child(instance)
	if body != null:
		var shape := BoxShape3D.new()
		shape.size = size
		_collider(body, prefix, shape, center)
	return instance


func _cylinder(parent: Node3D, prefix: String, center: Vector3, radius: float, height: float, material: Material, body: StaticBody3D) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 32
	var instance := MeshInstance3D.new()
	instance.name = _name(prefix)
	instance.mesh = mesh
	instance.material_override = material
	instance.position = center
	parent.add_child(instance)
	if body != null:
		var shape := CylinderShape3D.new()
		shape.radius = radius
		shape.height = height
		_collider(body, prefix, shape, center)
	return instance


## Closed convex solid from two rings of equal length (bottom ring, top ring)
## wound the same way. Every face is wound so it renders from outside, making
## the mesh watertight; the convex collider uses the same points.
func _hull(parent: Node3D, prefix: String, origin: Vector3, bottom: Array, top: Array, material: Material, body: StaticBody3D) -> MeshInstance3D:
	var count := bottom.size()
	var centroid := Vector3.ZERO
	for point in bottom + top:
		centroid += point as Vector3
	centroid /= float(count * 2)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(count):
		var next := (index + 1) % count
		_face(surface, centroid, [bottom[index], bottom[next], top[next], top[index]])
	for index in range(1, count - 1):
		_face(surface, centroid, [bottom[0], bottom[index], bottom[index + 1]])
		_face(surface, centroid, [top[0], top[index], top[index + 1]])
	var instance := MeshInstance3D.new()
	instance.name = _name(prefix)
	instance.mesh = surface.commit()
	instance.material_override = material
	instance.position = origin
	parent.add_child(instance)
	var points := PackedVector3Array()
	for point in bottom + top:
		points.append(point as Vector3)
	var shape := ConvexPolygonShape3D.new()
	shape.points = points
	_collider(body, prefix, shape, origin)
	return instance


## Emits a planar polygon as a triangle fan with a flat normal facing away
## from `centroid`. Godot treats clockwise triangles as front faces, so each
## triangle's (b - a) x (c - a) must point opposite the outward normal.
func _face(surface: SurfaceTool, centroid: Vector3, polygon: Array) -> void:
	var a := polygon[0] as Vector3
	var face_center := Vector3.ZERO
	for point in polygon:
		face_center += point as Vector3
	face_center /= float(polygon.size())
	for index in range(1, polygon.size() - 1):
		var b := polygon[index] as Vector3
		var c := polygon[index + 1] as Vector3
		var normal := (b - a).cross(c - a)
		if normal.length_squared() < 0.0000001:
			continue
		normal = normal.normalized()
		if normal.dot(face_center - centroid) > 0.0:
			var swap := b
			b = c
			c = swap
		else:
			normal = -normal
		for vertex in [a, b, c]:
			surface.set_normal(normal)
			surface.add_vertex(vertex)


func _collider(body: StaticBody3D, prefix: String, shape: Shape3D, center: Vector3) -> void:
	var collision := CollisionShape3D.new()
	collision.name = _name(prefix + "Collision")
	collision.shape = shape
	collision.position = center
	body.add_child(collision)


func _name(prefix: String) -> String:
	_counter += 1
	return "%s%d" % [prefix, _counter]
