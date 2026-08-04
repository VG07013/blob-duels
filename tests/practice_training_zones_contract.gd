extends SceneTree

## The holo training facility's identity: practice must read as a labeled
## training simulation, not just a room. Guards the four zones, the target
## furniture, the calibrated range markers, and the "hologram walls you cannot
## fall through" invariant.

const PRACTICE := preload("res://scenes/world/practice_arena.tscn")

const ZONE_NAMES := ["FLING RANGE", "RICOCHET GALLERY", "BOUNCE TOWERS", "SPAR RING"]
const DUMMY_POSITIONS := [
	Vector3(-60, 2, -35), Vector3(60, 2, 35), Vector3(-130, 2, -40),
	Vector3(130, 2, 50), Vector3(0, 2, -105),
]
const PLAY_BOUND := 157.0

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var arena := PRACTICE.instantiate() as Node3D
	root.add_child(arena)
	await process_frame
	await process_frame

	# Zones are labeled - every zone name present as fixed signage.
	var labels := _owned_group(arena, "training_zone_label")
	var texts: Array[String] = []
	for label_value in labels:
		var label := label_value as Label3D
		if label != null:
			texts.append(label.text)
	for zone_name in ZONE_NAMES:
		_check(texts.has(zone_name), "Practice must label its %s zone" % zone_name)

	# Target furniture: neon rings you can shoot and fling through.
	var rings := _owned_group(arena, "training_target_ring")
	_check(rings.size() >= 7, "Practice needs at least 7 target rings, found %d" % rings.size())
	for ring_value in rings:
		var ring := ring_value as MeshInstance3D
		var material := ring.material_override as StandardMaterial3D
		_check(material != null and material.emission_enabled and material.emission_energy_multiplier >= 1.5,
			"%s must glow hard enough to read as a target" % ring.name)

	# Exactly 5 bounce pads chained through the tower zone.
	var pads := arena.find_children("BouncePad*", "Area3D", true, false)
	_check(pads.size() == 5, "Practice must place exactly 5 bounce pads, found %d" % pads.size())

	# Fling-range distance ticks march strictly away from the tee.
	var visuals := arena.get_node("PracticeVisuals")
	var tick_node: MultiMeshInstance3D = null
	for child in visuals.get_children():
		if child is MultiMeshInstance3D and String(child.name).begins_with("RangeTicks"):
			tick_node = child
	_check(tick_node != null, "Practice must batch its range ticks as one MultiMesh")
	# The tick MultiMesh's transforms cannot be read back under the headless
	# renderer, so the monotonic march is asserted on the tick labels, which are
	# real nodes and the part a player actually reads.
	var tick_label_xs: Array[float] = []
	for child in visuals.get_children():
		if child is Label3D and String(child.name).begins_with("RangeTickLabel"):
			tick_label_xs.append((child as Label3D).position.x)
	_check(tick_label_xs.size() >= 6, "Fling range needs at least six labeled distance ticks")
	var previous_x := 0.0
	for tick_x in tick_label_xs:
		_check(tick_x < previous_x, "Range tick labels must march strictly down-range from the tee")
		previous_x = tick_x

	# Every fixed dummy position sits inside the map with real floor beneath.
	var space := arena.get_world_3d().direct_space_state
	for dummy_position in DUMMY_POSITIONS:
		_check(absf(dummy_position.x) < PLAY_BOUND and absf(dummy_position.z) < PLAY_BOUND,
			"Dummy at %s must sit inside the play bound" % str(dummy_position))
		var query := PhysicsRayQueryParameters3D.create(dummy_position + Vector3.UP, dummy_position + Vector3.DOWN * 4.0, 1)
		_check(not space.intersect_ray(query).is_empty(), "Dummy at %s needs solid floor beneath it" % str(dummy_position))

	# Hologram walls: see-through material, solid collision. Both halves matter -
	# transparency is the aesthetic, the solid box is what keeps flings in bounds.
	var walls := _owned_group(arena, "practice_perimeter_wall")
	var wall_collisions := _owned_group(arena, "practice_perimeter_wall_collision")
	_check(walls.size() == 4, "Practice needs four hologram perimeter walls")
	_check(wall_collisions.size() == 4, "Every hologram wall needs solid collision")
	for wall_value in walls:
		var wall := wall_value as MeshInstance3D
		var shader := wall.material_override as ShaderMaterial
		_check(shader != null and shader.shader != null and shader.shader.resource_path.ends_with("holo_wall.gdshader"),
			"%s must use the hologram wall shader" % wall.name)
	for collision_value in wall_collisions:
		var shape := collision_value as CollisionShape3D
		_check(shape != null and shape.shape is BoxShape3D, "%s must stay a plain solid box" % collision_value.name)

	# The map owns a lighting profile that passes the same ceilings as live maps.
	var profile := arena.call("get_lighting_profile") as Dictionary
	_check(bool(profile.get("glow_enabled", false)), "Practice lighting must enable glow - emissives carry the scene")
	_check(float(profile.get("ambient_energy", 2.0)) <= 0.72, "Practice ambient energy must respect the lighting ceiling")
	_check(float(profile.get("sun_energy", 2.0)) <= 1.2, "Practice sun energy must respect the lighting ceiling")

	arena.queue_free()
	await process_frame

	if failures.is_empty():
		print("PRACTICE TRAINING ZONES CONTRACT PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("PRACTICE TRAINING ZONES FAILURES: %d" % failures.size())
	quit(1)


func _owned_group(owner: Node, group_name: String) -> Array:
	return owner.get_tree().get_nodes_in_group(group_name).filter(func(node: Node) -> bool: return owner.is_ancestor_of(node))


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
