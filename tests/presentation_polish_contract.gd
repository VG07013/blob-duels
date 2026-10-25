extends SceneTree

const MAPS := {
	"Bounceground": preload("res://scenes/world/maps/bounceground.tscn"),
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
		_check(arena.get_node_or_null("Presentation") == null, "%s keeps a clean court with no ambient presentation layer" % map_name)
		arena.queue_free()
		await process_frame

	var game := MAIN_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	var menu := game.get_node("HUD/MainMenu") as Control
	var backdrop := menu.get_node_or_null("Backdrop") as ColorRect
	_check(backdrop != null and backdrop.material is ShaderMaterial, "The main menu needs its animated backdrop")
	if backdrop != null and backdrop.material is ShaderMaterial:
		var code := ((backdrop.material as ShaderMaterial).shader as Shader).code
		_check("TIME" in code, "The menu backdrop must move on its own, not sit as a still gradient")
	_check(menu.find_child("BlobStage", true, false) is MenuBlobStage, "The menu must show the player's blob as a live hero model")
	var cards := 0
	for candidate in menu.find_children("*", "PanelContainer", true, false):
		if candidate is MenuCard:
			cards += 1
	_check(cards >= 6, "The menu's surfaces must be the animated MenuCard glass (found %d)" % cards)
	game.queue_free()
	await process_frame

	if failures.is_empty():
		print("PRESENTATION POLISH CONTRACT PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
