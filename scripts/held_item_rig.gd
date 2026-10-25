class_name HeldItemRig
extends Node3D

## What the local player holds in first person, parented to the duel camera:
## the Blaster pistol on slot 1 and the two Blob fists on slot 2. Both are
## built here from primitives in the game's own chunky toy style (dark slate,
## one cyan accent, the fists in the blob's colour), drawn on top of the world
## so they never clip into walls, and animated with tweens: the pistol kicks
## on every shot, the fists alternate punches and squash on a hit, and the
## whole rig bobs with the blob's rolling speed. game.gd owns when it shows
## (first person, in a match, not during the victory cinematic).

const BLOB_MATERIAL_KIT := preload("res://scripts/blob_material_kit.gd")
const COMBAT_TUNING := preload("res://scripts/combat_tuning.gd")

## Slate body with one cyan accent, matching the Arena's palette.
const COLOR_BODY := Color(0.16, 0.19, 0.24)
const COLOR_BODY_LIGHT := Color(0.3, 0.34, 0.4)
const COLOR_ACCENT := Color(0.02, 0.82, 1.0)
const COLOR_GRIP := Color(0.09, 0.1, 0.13)
## Rest positions in camera space (x right, y up, z toward the viewer).
const PISTOL_REST := Vector3(0.44, -0.34, -0.92)
const PISTOL_REST_ROTATION := Vector3(0.0, -0.14, 0.0)
const FIST_LEFT_REST := Vector3(-0.46, -0.42, -0.88)
const FIST_RIGHT_REST := Vector3(0.46, -0.42, -0.88)
const FIST_RADIUS := 0.2
## Animation
const SHOT_KICK_BACK := 0.09
const SHOT_KICK_PITCH := 0.16
const SHOT_RECOVER_SECONDS := 0.16
const PUNCH_THRUST := 0.5
const PUNCH_OUT_SECONDS := 0.07
const PUNCH_BACK_SECONDS := 0.14
const PUNCH_HIT_SQUASH := 0.72
const SWAY_SPEED_FULL := 36.0
const SWAY_BOB_HEIGHT := 0.022
const SWAY_BOB_RATE := 9.5
const SWAY_AIR_LIFT := 0.03
const SWAY_SETTLE := 10.0

var pistol: Node3D
var fists: Node3D
var _fist_nodes: Array[Node3D] = []
var _fist_materials: Array[StandardMaterial3D] = []
var _slot := COMBAT_TUNING.SLOT_BLASTER
var _first_person := false
var _active := false
var _bob_phase := 0.0
var _bob_offset := Vector3.ZERO
var _pistol_tween: Tween
var _fist_tweens: Array = [null, null]
var _reduced_motion := false


func _ready() -> void:
	name = "HeldItems"
	pistol = _build_pistol()
	add_child(pistol)
	fists = _build_fists()
	add_child(fists)
	_refresh_visibility()


## Slot 1 shows the pistol, slot 2 the fists.
func set_slot(slot: int) -> void:
	_slot = slot
	_refresh_visibility()


func set_first_person(enabled: bool) -> void:
	_first_person = enabled
	_refresh_visibility()


## Whether a match is running: the rig stays hidden in the menu and during
## the victory cinematic however the camera is set.
func set_active(enabled: bool) -> void:
	_active = enabled
	_refresh_visibility()


func set_reduced_motion(enabled: bool) -> void:
	_reduced_motion = enabled


## The fists take the blob's own colour, with the same rubbery finish.
func set_blob_color(color: Color) -> void:
	for material in _fist_materials:
		BLOB_MATERIAL_KIT.decorate(material, color)
		material.no_depth_test = true
		material.render_priority = 2


func is_showing() -> bool:
	return visible


## The pistol kicks back and up, then settles.
func play_shot() -> void:
	if _reduced_motion or pistol == null:
		return
	if _pistol_tween != null and _pistol_tween.is_valid():
		_pistol_tween.kill()
	pistol.position = PISTOL_REST + Vector3(0.0, 0.015, SHOT_KICK_BACK)
	pistol.rotation = PISTOL_REST_ROTATION + Vector3(SHOT_KICK_PITCH, 0.0, 0.0)
	_pistol_tween = create_tween().set_parallel(true).set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_pistol_tween.tween_property(pistol, "position", PISTOL_REST, SHOT_RECOVER_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_pistol_tween.tween_property(pistol, "rotation", PISTOL_REST_ROTATION, SHOT_RECOVER_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## `hand` 0 is the left fist, 1 the right: it shoots forward and twists in,
## squashes if it landed, then comes back.
func play_punch(hand: int, hit: bool) -> void:
	if _fist_nodes.size() < 2:
		return
	var index := clampi(hand, 0, 1)
	var fist := _fist_nodes[index]
	var rest := FIST_LEFT_REST if index == 0 else FIST_RIGHT_REST
	if _reduced_motion:
		fist.position = rest
		return
	var previous := _fist_tweens[index] as Tween
	if previous != null and previous.is_valid():
		previous.kill()
	fist.position = rest
	fist.scale = Vector3.ONE
	var out := rest + Vector3(-rest.x * 0.55, 0.1, -PUNCH_THRUST)
	# Two steps: the thrust (with the squash on a hit), then the return. Fixed
	# physics steps keep the swing the same length whatever the frame rate.
	var tween := create_tween().set_parallel(true).set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(fist, "position", out, PUNCH_OUT_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if hit:
		tween.tween_property(fist, "scale", Vector3(1.25, 1.25, PUNCH_HIT_SQUASH), PUNCH_OUT_SECONDS)
	tween.chain()
	tween.tween_property(fist, "position", rest, PUNCH_BACK_SECONDS).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if hit:
		tween.tween_property(fist, "scale", Vector3.ONE, PUNCH_BACK_SECONDS).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_fist_tweens[index] = tween


## Bob with rolling speed; lift a touch while airborne.
func update_sway(delta: float, velocity: Vector3, grounded: bool) -> void:
	if not visible or _reduced_motion:
		_bob_offset = Vector3.ZERO
		return
	var planar_speed := Vector3(velocity.x, 0.0, velocity.z).length()
	var speed_ratio := clampf(planar_speed / SWAY_SPEED_FULL, 0.0, 1.0)
	_bob_phase += delta * SWAY_BOB_RATE * (0.4 + speed_ratio) * (1.0 if grounded else 0.3)
	var target := Vector3(sin(_bob_phase) * SWAY_BOB_HEIGHT * speed_ratio, absf(cos(_bob_phase)) * SWAY_BOB_HEIGHT * speed_ratio, 0.0)
	if not grounded:
		target.y += SWAY_AIR_LIFT * clampf(-velocity.y / 30.0, -1.0, 1.0)
	_bob_offset = _bob_offset.lerp(target, 1.0 - exp(-SWAY_SETTLE * delta))
	position = _bob_offset


func _refresh_visibility() -> void:
	visible = _first_person and _active
	if pistol != null:
		pistol.visible = _slot == COMBAT_TUNING.SLOT_BLASTER
	if fists != null:
		fists.visible = _slot == COMBAT_TUNING.SLOT_BLOB


## Model builders ---------------------------------------------------------------
## A chunky blaster pistol: boxy slide, round barrel with a glowing muzzle
## ring, raked grip, a trigger guard and a glowing power cell on each side.
func _build_pistol() -> Node3D:
	var root := Node3D.new()
	root.name = "Pistol"
	root.position = PISTOL_REST
	root.rotation = PISTOL_REST_ROTATION
	var body := _matte(COLOR_BODY, 0.55)
	var light := _matte(COLOR_BODY_LIGHT, 0.45)
	var grip := _matte(COLOR_GRIP, 0.8)
	var accent := _glow(COLOR_ACCENT, 1.6)
	# Slide and frame.
	_add_box(root, "Slide", Vector3(0.15, 0.13, 0.56), Vector3(0.0, 0.08, -0.08), body)
	_add_box(root, "SlideTop", Vector3(0.11, 0.05, 0.44), Vector3(0.0, 0.165, -0.1), light)
	_add_box(root, "Frame", Vector3(0.16, 0.1, 0.42), Vector3(0.0, -0.02, -0.02), light)
	_add_box(root, "Sight", Vector3(0.03, 0.05, 0.05), Vector3(0.0, 0.21, -0.3), grip)
	# Barrel and muzzle.
	_add_cylinder(root, "Barrel", 0.04, 0.3, Vector3(0.0, 0.08, -0.46), body)
	_add_cylinder(root, "MuzzleRing", 0.055, 0.04, Vector3(0.0, 0.08, -0.6), accent)
	_add_cylinder(root, "BarrelLip", 0.03, 0.06, Vector3(0.0, 0.08, -0.62), grip)
	# Grip, raked back, and the trigger guard under the frame.
	var grip_node := _add_box(root, "Grip", Vector3(0.13, 0.3, 0.17), Vector3(0.0, -0.2, 0.12), grip)
	grip_node.rotation = Vector3(0.28, 0.0, 0.0)
	_add_box(root, "GripCap", Vector3(0.15, 0.05, 0.19), Vector3(0.0, -0.34, 0.16), light)
	var guard := _add_torus(root, "TriggerGuard", 0.055, 0.012, Vector3(0.0, -0.1, -0.06), light)
	guard.rotation = Vector3(0.0, 0.0, PI * 0.5)
	_add_box(root, "Trigger", Vector3(0.025, 0.06, 0.02), Vector3(0.0, -0.09, -0.05), grip)
	# Power cells: the one glowing detail besides the muzzle.
	_add_box(root, "Cell", Vector3(0.03, 0.06, 0.18), Vector3(0.09, 0.07, -0.04), accent)
	_add_box(root, "CellWindow", Vector3(0.03, 0.06, 0.18), Vector3(-0.09, 0.07, -0.04), accent)
	return root


## Two big round fists in the blob's colour, four knuckle bumps and a thumb each.
func _build_fists() -> Node3D:
	var root := Node3D.new()
	root.name = "Fists"
	_fist_nodes.clear()
	_fist_materials.clear()
	for hand in 2:
		var fist := Node3D.new()
		fist.name = "LeftFist" if hand == 0 else "RightFist"
		fist.position = FIST_LEFT_REST if hand == 0 else FIST_RIGHT_REST
		var material := StandardMaterial3D.new()
		_fist_materials.append(material)
		var palm := MeshInstance3D.new()
		palm.name = "Palm"
		var sphere := SphereMesh.new()
		sphere.radius = FIST_RADIUS
		sphere.height = FIST_RADIUS * 2.0
		palm.mesh = sphere
		palm.material_override = material
		palm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fist.add_child(palm)
		var side := -1.0 if hand == 0 else 1.0
		for knuckle in 4:
			var bump := MeshInstance3D.new()
			bump.name = "Knuckle%d" % knuckle
			var bump_mesh := SphereMesh.new()
			bump_mesh.radius = FIST_RADIUS * 0.34
			bump_mesh.height = bump_mesh.radius * 2.0
			bump.mesh = bump_mesh
			bump.material_override = material
			bump.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var angle := lerpf(-0.55, 0.55, float(knuckle) / 3.0)
			bump.position = Vector3(sin(angle) * FIST_RADIUS * 0.85 * side, FIST_RADIUS * 0.45, -cos(angle) * FIST_RADIUS * 0.85)
			fist.add_child(bump)
		var thumb := MeshInstance3D.new()
		thumb.name = "Thumb"
		var thumb_mesh := CapsuleMesh.new()
		thumb_mesh.radius = FIST_RADIUS * 0.3
		thumb_mesh.height = FIST_RADIUS * 1.1
		thumb.mesh = thumb_mesh
		thumb.material_override = material
		thumb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		thumb.position = Vector3(-FIST_RADIUS * 0.75 * side, FIST_RADIUS * 0.25, -FIST_RADIUS * 0.3)
		thumb.rotation = Vector3(0.0, 0.0, 0.5 * side)
		fist.add_child(thumb)
		root.add_child(fist)
		_fist_nodes.append(fist)
	set_blob_color(Color(0.02, 0.86, 1.0))
	return root


func _add_box(parent: Node3D, part_name: String, size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _add_part(parent, part_name, mesh, at, material)


func _add_cylinder(parent: Node3D, part_name: String, radius: float, length: float, at: Vector3, material: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length
	var part := _add_part(parent, part_name, mesh, at, material)
	part.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	return part


func _add_torus(parent: Node3D, part_name: String, radius: float, tube: float, at: Vector3, material: Material) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - tube
	mesh.outer_radius = radius + tube
	return _add_part(parent, part_name, mesh, at, material)


func _add_part(parent: Node3D, part_name: String, mesh: Mesh, at: Vector3, material: Material) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = part_name
	part.mesh = mesh
	part.material_override = material
	part.position = at
	part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(part)
	return part


## Held parts draw over the world (no depth test) so walls never cut them.
func _matte(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = 0.15
	material.no_depth_test = true
	material.render_priority = 2
	return material


func _glow(color: Color, energy: float) -> StandardMaterial3D:
	var material := _matte(color, 0.3)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material
