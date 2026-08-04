extends SceneTree

## BUG-027 programmatic verification, standing in for eyes on the arena.
##
## Checks four things the rebuild could plausibly have got wrong:
##   1. Solid props do not interpenetrate (the "objects overlapping" report).
##   2. Every solid visual has collision and every collider has a visual (the
##      "invisible objects" report cuts both ways - a mesh with no collider you
##      fall through, a collider with no mesh you hit nothing).
##   3. The 5.776-unit blob fits through the gaps between solid props at play
##      height, so the rebuild cannot trap or pinch the player.
##   4. Nothing solid sits outside the playable bound, and the spawn points sit
##      inside it - the stale-bounds failure this bug was partly about.

const PRACTICE := preload("res://scenes/world/practice_arena.tscn")
const MAIN_SCENE := preload("res://scenes/main.tscn")

const BLOB_DIAMETER := 5.776
const PLAY_HALF_EXTENT := 157.0
## Overlap smaller than this is authored seating - a lamp post sunk into its
## sidewalk, a roof capping its tower - not the interpenetration this looks for.
const OVERLAP_TOLERANCE := 0.75
## Heights the blob actually occupies while rolling on the ground plane.
const PLAY_HEIGHTS := [2.9, 6.0, 9.0]
## A sphere cannot enter a slot narrower than its own diameter at all, so a very
## tight gap is just solid furniture - the back panel and bench of one bus stop,
## say. What actually misleads a player is a gap wide enough to read as a route
## but too narrow to take, so only that band is treated as a defect.
const MISLEADING_GAP_MINIMUM := 1.5
## The facility is table-authored from a single geometry module: zero
## interpenetration and zero misleading channels, enforced absolutely. The old
## city carried 34/29 as ratcheted debt - a from-scratch map has no excuse.
const MAX_KNOWN_OVERLAPS := 0
const MAX_KNOWN_PINCHES := 0

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var arena := PRACTICE.instantiate() as Node3D
	root.add_child(arena)
	await process_frame
	await process_frame

	var visuals := arena.get_node_or_null("PracticeVisuals")
	var collision := arena.get_node_or_null("PracticeCollision")
	_check(visuals != null and collision != null, "Practice arena must expose PracticeVisuals and PracticeCollision roots")
	if visuals == null or collision == null:
		_finish()
		return

	var meshes: Array[MeshInstance3D] = []
	for child in visuals.get_children():
		var instance := child as MeshInstance3D
		if instance != null:
			meshes.append(instance)
	var shapes: Array[CollisionShape3D] = []
	for child in collision.get_children():
		var shape := child as CollisionShape3D
		if shape != null:
			shapes.append(shape)

	var multimeshes := 0
	for child in visuals.get_children():
		if child is MultiMeshInstance3D:
			multimeshes += 1

	print("practice arena: %d MeshInstance3D, %d MultiMeshInstance3D, %d CollisionShape3D" % [meshes.size(), multimeshes, shapes.size()])
	_check(multimeshes > 0, "Repeated decorative geometry must be issued as MultiMesh, not one node per copy")

	# --- 1 + 3: solid prop overlap and gap width -----------------------------
	var solids: Array[Dictionary] = []
	for shape in shapes:
		var box := shape.shape as BoxShape3D
		if box == null:
			continue
		var half := box.size * 0.5
		var centre := shape.position
		# Skip the ground plate, the roof, and the perimeter shell: they are
		# meant to enclose everything else.
		if box.size.x > 400.0 and box.size.z > 400.0:
			continue
		# Only props the blob can actually reach can trap or clip it, so scope
		# the check to anything intersecting the playable box grown by a radius.
		var reach := PLAY_HALF_EXTENT + BLOB_DIAMETER * 0.5
		if centre.x - half.x > reach or centre.x + half.x < -reach:
			continue
		if centre.z - half.z > reach or centre.z + half.z < -reach:
			continue
		if absf(shape.rotation.y) > 0.01:
			continue
		solids.append({"name": shape.name, "min": centre - half, "max": centre + half, "centre": centre, "half": half})

	var overlaps := 0
	for i in range(solids.size()):
		for j in range(i + 1, solids.size()):
			var a: Dictionary = solids[i]
			var b: Dictionary = solids[j]
			var depth := _overlap_depth(a, b)
			if depth > OVERLAP_TOLERANCE:
				overlaps += 1
				if overlaps <= 8:
						print("  overlap %.2f units: %s vs %s" % [depth, a["name"], b["name"]])
	print("solid props compared: %d, interpenetrating pairs: %d" % [solids.size(), overlaps])
	# Ratchet, not zero. The authored layout carried 34 interpenetrating pairs
	# and 29 sub-blob channels before this rebuild - that is the "objects
	# overlapping each other" in the bug report, and clearing it completely
	# needs a hand-authored pass. These bounds lock in the improvement (28 / 20)
	# so the count can only go down from here.
	_check(overlaps <= MAX_KNOWN_OVERLAPS, "Solid props interpenetrate: %d pairs (budget %d)" % [overlaps, MAX_KNOWN_OVERLAPS])

	var pinch_count := 0
	for height in PLAY_HEIGHTS:
		var at_height: Array[Dictionary] = []
		for solid in solids:
			if float(solid["min"].y) <= height and float(solid["max"].y) >= height:
				at_height.append(solid)
		for i in range(at_height.size()):
			for j in range(i + 1, at_height.size()):
				var gap := _planar_gap(at_height[i], at_height[j])
				# Only a gap that is a real corridor matters: if the pair is far
				# apart on the other axis they do not form a channel at all.
				if gap >= MISLEADING_GAP_MINIMUM and gap < BLOB_DIAMETER and _forms_channel(at_height[i], at_height[j]):
					pinch_count += 1
	print("sub-blob-width channels found: %d" % pinch_count)
	_check(pinch_count <= MAX_KNOWN_PINCHES, "Misleading sub-blob channels: %d (budget %d)" % [pinch_count, MAX_KNOWN_PINCHES])

	# --- 2: visual/collision pairing ----------------------------------------
	var solid_props := _group_under(arena, "solid_visible_prop")
	var solid_prop_collisions := _group_under(arena, "solid_visible_prop_collision")
	_check(solid_props.size() == solid_prop_collisions.size(),
		"Every solid-looking prop needs matching collision (%d props vs %d colliders)" % [solid_props.size(), solid_prop_collisions.size()])
	var ramps := _group_under(arena, "closed_ramp")
	var ramp_collisions := _group_under(arena, "closed_ramp_collision")
	_check(ramps.size() == ramp_collisions.size(),
		"Every closed ramp needs one matching convex collider (%d ramps vs %d colliders)" % [ramps.size(), ramp_collisions.size()])
	for instance in meshes:
		_check(instance.mesh != null, "%s is an invisible MeshInstance3D with no mesh assigned" % instance.name)
	for shape in shapes:
		_check(shape.shape != null, "%s is a CollisionShape3D with no shape assigned" % shape.name)

	arena.queue_free()
	await process_frame

	# --- 4: bounds and spawns agree -----------------------------------------
	var game := MAIN_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	var spawn_manager := game.get_node("SpawnManager")
	var half_extent := float(spawn_manager.get("arena_half_extent"))
	_check(is_equal_approx(half_extent, 157.0), "Practice bound must match the rebuilt arena footprint, got %.1f" % half_extent)
	for slot in range(2):
		var spawn: Vector3 = spawn_manager.call("get_spawn_for_slot", slot)
		_check(not bool(spawn_manager.call("is_outside_arena", spawn)),
			"Spawn slot %d at %s is outside the arena bound it spawns into" % [slot, str(spawn)])
	game.queue_free()
	await process_frame

	_finish()


## Smallest penetration across the three axes. Two boxes only truly overlap when
## every axis overlaps; the shallowest axis is how far one would have to move.
func _overlap_depth(a: Dictionary, b: Dictionary) -> float:
	var depth := INF
	for axis in ["x", "y", "z"]:
		var low: float = maxf(float(a["min"][axis]), float(b["min"][axis]))
		var high: float = minf(float(a["max"][axis]), float(b["max"][axis]))
		if high <= low:
			return 0.0
		depth = minf(depth, high - low)
	return depth


## Horizontal clearance between two boxes on their closest separating axis.
func _planar_gap(a: Dictionary, b: Dictionary) -> float:
	var gap_x: float = maxf(float(a["min"].x) - float(b["max"].x), float(b["min"].x) - float(a["max"].x))
	var gap_z: float = maxf(float(a["min"].z) - float(b["max"].z), float(b["min"].z) - float(a["max"].z))
	return maxf(gap_x, gap_z)


## True when the pair actually brackets a corridor: they must overlap on the
## axis perpendicular to the gap, otherwise the blob simply goes around.
func _forms_channel(a: Dictionary, b: Dictionary) -> bool:
	var gap_x: float = maxf(float(a["min"].x) - float(b["max"].x), float(b["min"].x) - float(a["max"].x))
	var gap_z: float = maxf(float(a["min"].z) - float(b["max"].z), float(b["min"].z) - float(a["max"].z))
	if gap_x >= gap_z:
		return minf(float(a["max"].z), float(b["max"].z)) - maxf(float(a["min"].z), float(b["min"].z)) > 0.0
	return minf(float(a["max"].x), float(b["max"].x)) - maxf(float(a["min"].x), float(b["min"].x)) > 0.0


func _group_under(owner: Node, group_name: String) -> Array:
	return owner.get_tree().get_nodes_in_group(group_name).filter(func(node: Node) -> bool: return owner.is_ancestor_of(node))


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("PRACTICE ARENA GEOMETRY CONTRACT PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("PRACTICE ARENA GEOMETRY FAILURES: %d" % failures.size())
	quit(1)
