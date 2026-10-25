extends SceneTree

const MAPS := {
	"Bounceground": preload("res://scenes/world/maps/bounceground.tscn"),
	"Training Yard": preload("res://scenes/world/maps/training_yard.tscn"),
}

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for map_name in MAPS:
		var arena := (MAPS[map_name] as PackedScene).instantiate() as Node3D
		root.add_child(arena)
		await process_frame
		_validate_map_flow(map_name, arena)
		arena.queue_free()
		await process_frame
	if _failures.is_empty():
		print("DUEL FLOW CONTRACT PASS")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _validate_map_flow(map_name: String, arena: Node3D) -> void:
	var anchors := _group_descendants(arena, &"duel_flow_anchor")
	var covers := _group_descendants(arena, &"duel_cover")
	var interactables := _group_descendants(arena, &"intentional_interactable")
	var roles: Dictionary = {}
	var lanes: Dictionary = {}
	for anchor in anchors:
		var role := String(anchor.get_meta("flow_role", ""))
		var lane := String(anchor.get_meta("flow_lane", ""))
		roles[role] = int(roles.get(role, 0)) + 1
		lanes[lane] = true
	_expect(int(roles.get("spawn_exit", 0)) >= 2, "%s needs two authored spawn exits" % map_name)
	_expect(int(roles.get("center_contest", 0)) >= 1, "%s needs a defined center contest" % map_name)
	_expect(int(roles.get("flank_route", 0)) >= 4, "%s needs readable protected flank routes" % map_name)
	_expect(int(roles.get("attack_route", 0)) >= 4, "%s needs deliberate attack-route anchors" % map_name)
	_expect(lanes.has("center") and lanes.has("left") and lanes.has("right"), "%s needs center, left, and right route language" % map_name)
	for anchor in anchors:
		var role := String(anchor.get_meta("flow_role", ""))
		if role in ["spawn_exit", "attack_route", "flank_route"]:
			_expect(_anchor_has_blob_clearance(arena, anchor as Node3D), "%s route anchor %s is blocked for a full-size blob" % [map_name, anchor.name])
	_expect(_routes_are_rotationally_fair(anchors), "%s route anchors need equivalent north/south travel geometry" % map_name)
	_expect(covers.size() >= 8, "%s needs at least eight intentional combat-cover pieces" % map_name)
	var north_cover := 0
	var south_cover := 0
	var center_cover := 0
	for cover in covers:
		var position := (cover as Node3D).position
		if position.z < -12.0:
			north_cover += 1
		elif position.z > 12.0:
			south_cover += 1
		else:
			center_cover += 1
		_expect(absf(position.z) <= float(arena.get("arena_half_length")) - 24.0, "%s cover must not create a spawn-adjacent stall pocket" % map_name)
	_expect(north_cover >= 3 and south_cover >= 3 and center_cover >= 2, "%s cover must support both approaches and the center fight" % map_name)
	_expect(interactables.size() >= 7, "%s needs at least seven purposeful interactables" % map_name)
	var center_feeders := 0
	for interactable in interactables:
		var purpose := String(interactable.get_meta("duel_purpose", ""))
		_expect(not purpose.is_empty(), "%s has an interactable without a combat purpose" % map_name)
		if bool(interactable.get_meta("leads_to_center", false)):
			if _physically_feeds_center(interactable as Node3D):
				center_feeders += 1
			else:
				_failures.append("%s marks %s as center-leading but its configured motion points elsewhere" % [map_name, interactable.name])
	_expect(center_feeders >= 4, "%s needs at least four interactables that feed the center fight" % map_name)
	var audit := arena.call("get_map_audit") as Dictionary
	_expect(audit.has("flow_plan") and (audit.get("flow_plan", []) as Array).size() >= 3, "%s audit needs a three-route flow plan" % map_name)
	_expect(audit.has("combat_spaces") and (audit.get("combat_spaces", []) as Array).size() >= 3, "%s audit needs authored attack, cover, and center spaces" % map_name)


func _group_descendants(arena: Node, group_name: StringName) -> Array[Node]:
	var matches: Array[Node] = []
	for node in arena.find_children("*", "Node", true, false):
		if node.is_in_group(group_name):
			matches.append(node)
	return matches


func _physically_feeds_center(interactable: Node3D) -> bool:
	var flat_position := Vector3(interactable.position.x, 0.0, interactable.position.z)
	if flat_position.length() <= 22.0:
		return true
	var toward_center := -flat_position.normalized()
	var kind := StringName(interactable.call("get_interaction_kind")) if interactable.has_method("get_interaction_kind") else &""
	if kind in [&"launch_pad", &"conveyor", &"wind_zone"]:
		var configured := interactable.get("local_direction") as Vector3
		var flat_direction := Vector3(configured.x, 0.0, configured.z).normalized()
		return flat_direction.dot(toward_center) >= 0.35
	if kind == &"moving_platform":
		var offset := interactable.get("travel_offset") as Vector3
		var flat_offset := Vector3(offset.x, 0.0, offset.z).normalized()
		return flat_offset.dot(toward_center) >= 0.35
	return false


func _anchor_has_blob_clearance(arena: Node3D, anchor: Node3D) -> bool:
	var space_state := arena.get_world_3d().direct_space_state
	var ray_start := Vector3(anchor.global_position.x, 12.0, anchor.global_position.z)
	var ray_end := Vector3(anchor.global_position.x, -2.0, anchor.global_position.z)
	var floor_hit := space_state.intersect_ray(PhysicsRayQueryParameters3D.create(ray_start, ray_end, 1))
	if floor_hit.is_empty():
		return false
	var floor_y := float((floor_hit.get("position", Vector3.ZERO) as Vector3).y)
	var probe := SphereShape3D.new()
	probe.radius = 2.9
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = probe
	# Ground the probe on authored floor insets instead of inheriting marker height.
	var grounded_center := Vector3(anchor.global_position.x, floor_y + probe.radius + 0.05, anchor.global_position.z)
	query.transform = Transform3D(Basis.IDENTITY, grounded_center)
	query.collision_mask = 1
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var floor_rid: RID = floor_hit.get("rid", RID())
	if floor_rid.is_valid():
		query.exclude = [floor_rid]
	return space_state.intersect_shape(query, 1).is_empty()


func _routes_are_rotationally_fair(anchors: Array[Node]) -> bool:
	for anchor in anchors:
		var role := String(anchor.get_meta("flow_role", ""))
		if role not in ["spawn_exit", "attack_route", "flank_route"]:
			continue
		var lane := String(anchor.get_meta("flow_lane", ""))
		var position := (anchor as Node3D).position
		var mirrored_lane := lane
		if lane == "left":
			mirrored_lane = "right"
		elif lane == "right":
			mirrored_lane = "left"
		var found_pair := false
		for candidate in anchors:
			if String(candidate.get_meta("flow_role", "")) != role:
				continue
			if String(candidate.get_meta("flow_lane", "")) != mirrored_lane:
				continue
			var pair_sum := (candidate as Node3D).position + position
			if Vector2(pair_sum.x, pair_sum.z).length() <= 1.0:
				found_pair = true
				break
		if not found_pair:
			return false
	return true


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
