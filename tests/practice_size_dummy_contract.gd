extends SceneTree

const PRACTICE_SCENE := preload("res://scenes/world/practice_arena.tscn")
const DUMMY_SCENE := preload("res://scenes/player/dummy_blob.tscn")

## The eight station names wired into scenes/main.tscn - the training roster
## reads as characters, not targets.
const DUMMY_NAMES: PackedStringArray = [
	"Bob", "Sir Bounces", "Jellybean", "Wobbleton",
	"Mochi", "Boop", "Captain Squish", "Pogo",
]

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var root_node := Node3D.new()
	get_root().add_child(root_node)
	var practice := PRACTICE_SCENE.instantiate() as Node3D
	root_node.add_child(practice)
	await physics_frame
	await physics_frame

	# The compact-map rule, in world space: the turf must span exactly the
	# 28 x 15 GU blueprint footprint (1 GU = 2.888), keeping every dummy
	# quickly reachable from the centre spawn.
	var ground: MeshInstance3D = null
	for node in practice.find_children("FacilityGround*", "MeshInstance3D", true, false):
		ground = node as MeshInstance3D
	_check(ground != null and ground.mesh is BoxMesh, "Practice needs its single turf plate")
	if ground != null and ground.mesh is BoxMesh:
		var turf := ground.mesh as BoxMesh
		_check(absf(turf.size.x - 80.864) <= 0.01, "Turf width must span 28 GU (80.864 units), got %.3f" % turf.size.x)
		_check(absf(turf.size.z - 43.32) <= 0.01, "Turf length must span 15 GU (43.32 units), got %.3f" % turf.size.z)
	var walls := _owned_group(practice, "practice_perimeter_wall")
	var wall_collisions := _owned_group(practice, "practice_perimeter_wall_collision")
	_check(walls.size() == 4, "Practice needs four visible perimeter walls")
	_check(wall_collisions.size() == 4, "Every Practice perimeter wall needs solid collision")
	for wall_value in walls:
		var wall := wall_value as MeshInstance3D
		var wall_mesh := wall.mesh as BoxMesh
		_check(wall_mesh != null and absf(wall_mesh.size.y - 8.664) <= 0.01, "%s must stand exactly 3 GU of solid padding" % wall.name)
	# Above the solid band the arena stays closed by glass: the transparent
	# enclosure and canopy carry real collision up to 5 GU.
	var enclosure := _owned_group(practice, "practice_enclosure_wall")
	var enclosure_collisions := _owned_group(practice, "practice_enclosure_wall_collision")
	_check(enclosure.size() == 4, "Practice needs four transparent enclosure panes")
	_check(enclosure_collisions.size() == 4, "Every enclosure pane needs solid collision")
	for pane_value in enclosure:
		var pane := pane_value as MeshInstance3D
		var material := pane.material_override as StandardMaterial3D
		_check(material != null and material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA and material.albedo_color.a < 0.3,
			"%s must stay highly transparent - the enclosure is invisible fencing, not a wall" % pane.name)
	for pane_value in enclosure_collisions:
		var shape := pane_value as CollisionShape3D
		var box := shape.shape as BoxShape3D if shape != null else null
		_check(box != null and absf(shape.position.y + box.size.y * 0.5 - 14.44) <= 0.01,
			"%s must close the air gap up to the 5 GU canopy" % pane_value.name)

	var names: Dictionary = {}
	for index in range(DUMMY_NAMES.size()):
		var dummy := DUMMY_SCENE.instantiate() as RigidBody3D
		dummy.name = "DummyStation%c" % (65 + index)
		dummy.set("display_name", DUMMY_NAMES[index])
		dummy.position = Vector3(float(index) * 9.0, 5.0, float(index) * -4.0)
		root_node.add_child(dummy)
		await process_frame
		var dummy_name := str(dummy.get("display_name"))
		_check(not dummy_name.is_empty() and not dummy_name.begins_with("Dummy"), "%s needs a funny player-facing name" % dummy.name)
		_check(not names.has(dummy_name), "Practice dummy names should be unique across the eight-station roster")
		names[dummy_name] = true
		var nameplate := dummy.get_node_or_null("Nameplate") as Node3D
		var name_label := dummy.get_node_or_null("Nameplate/Name") as Label3D
		var health_background := dummy.get_node_or_null("Nameplate/HealthBackground") as MeshInstance3D
		var health_fill := dummy.get_node_or_null("Nameplate/HealthFill") as MeshInstance3D
		var target_icon := dummy.get_node_or_null("Nameplate/TargetIcon") as Label3D
		_check(nameplate != null and nameplate.top_level, "%s needs a stable top-level nameplate" % dummy.name)
		_check(name_label != null and name_label.text == dummy_name, "%s name must render above its health bar" % dummy.name)
		_check(health_background != null and health_fill != null, "%s needs a visual health bar, not a raw health number" % dummy.name)
		_check(target_icon != null and not target_icon.text.is_empty(), "%s needs the red target icon above its head" % dummy.name)
		# Dummies default to infinite health, so a hit reads as feedback without
		# draining the bar; the bar only tracks damage on a finite preset.
		dummy.call("take_damage", 30, Vector3.RIGHT, 0.0)
		_check(health_fill != null and is_equal_approx(health_fill.scale.x, 1.0),
			"%s must shrug off damage while set to infinite health" % dummy.name)
		dummy.call("set_health_preset", 250)
		dummy.call("take_damage", 50, Vector3.RIGHT, 0.0)
		_check(health_fill != null and is_equal_approx(health_fill.scale.x, 0.8), "%s health fill must track health visually" % dummy.name)

	root_node.queue_free()
	if _failures.is_empty():
		print("PRACTICE SIZE + DUMMY CONTRACT PASSED")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _owned_group(owner: Node, group_name: StringName) -> Array[Node]:
	return get_nodes_in_group(group_name).filter(func(node: Node) -> bool: return owner.is_ancestor_of(node))


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
