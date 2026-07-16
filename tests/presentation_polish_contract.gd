extends SceneTree

const MAPS := {
	"Neon Arcade": preload("res://scenes/world/maps/neon_arcade.tscn"),
	"Backyard": preload("res://scenes/world/maps/backyard.tscn"),
	"Arena": preload("res://scenes/world/maps/arena.tscn"),
	"Sky Temple": preload("res://scenes/world/maps/sky_temple.tscn"),
	"Toybox": preload("res://scenes/world/maps/toybox.tscn"),
}
const MAIN_SCENE := preload("res://scenes/main.tscn")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for map_name in MAPS:
		var arena := (MAPS[map_name] as PackedScene).instantiate()
		root.add_child(arena)
		await process_frame
		var presentation := arena.get_node_or_null("Presentation")
		if map_name in ["Neon Arcade", "Arena"]:
			_check(presentation == null, "%s should reserve every arena object for its literal movement blueprint" % map_name)
			arena.queue_free()
			await process_frame
			continue
		_check(presentation != null, "%s has no presentation layer" % map_name)
		if presentation != null:
			_check(_group_count(presentation, &"world_display") >= 3, "%s needs at least three live displays" % map_name)
			_check(_displays_are_readable(presentation), "%s live display copy is not readable in-world" % map_name)
			_check(_group_count(presentation, &"animated_map_prop") >= 6, "%s needs more ambient motion" % map_name)
			_check(_group_count(presentation, &"presentation_light") >= 3, "%s needs a complete accent-light rig" % map_name)
			_check(_group_count(presentation, &"ambient_vfx") >= 8, "%s needs richer lightweight ambient VFX" % map_name)
			_check(presentation.process_mode != Node.PROCESS_MODE_DISABLED, "%s presentation animation is disabled" % map_name)
		arena.queue_free()
		await process_frame

	var game := MAIN_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	var lobby := game.get_node("Lobby")
	_check(lobby.has_node("AmbientMotion"), "Lobby has no animated presentation root")
	_check(_group_count(lobby, &"animated_lobby_prop") >= 6, "Lobby needs more animated details")
	_check(_group_count(lobby, &"presentation_light") >= 5, "Lobby accent lighting is incomplete")
	game.queue_free()
	await process_frame

	if failures.is_empty():
		print("PRESENTATION POLISH CONTRACT PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _group_count(parent: Node, group_name: StringName) -> int:
	var count := 0
	for node in parent.find_children("*", "Node", true, false):
		if node.is_in_group(group_name):
			count += 1
	return count


func _displays_are_readable(parent: Node) -> bool:
	for candidate in parent.find_children("*", "Node3D", true, false):
		if not candidate.is_in_group(&"world_display"):
			continue
		var message := candidate.get_node_or_null("Message") as Label3D
		var status := candidate.get_node_or_null("Status") as Label3D
		var message_back := candidate.get_node_or_null("MessageBack") as Label3D
		var status_back := candidate.get_node_or_null("StatusBack") as Label3D
		if message == null or status == null or message_back == null or status_back == null:
			return false
		if message.text.is_empty() or message.pixel_size < 0.025 or message.no_depth_test:
			return false
		if status.text.is_empty() or status.pixel_size < 0.02 or status.no_depth_test:
			return false
		if message.position.z * message_back.position.z >= 0.0 or status.position.z * status_back.position.z >= 0.0:
			return false
	return true


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
