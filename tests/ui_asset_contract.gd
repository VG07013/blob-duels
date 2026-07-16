extends SceneTree

const SCRIPT_PATHS := [
	"res://scripts/hud.gd",
	"res://scripts/pause_menu.gd",
]
const REQUIRED_UI_ART := [
	"res://assets/ui/art/lobby-banner.png",
	"res://assets/ui/art/pause-session-card.png",
	"res://assets/ui/art/guide-movement.png",
	"res://assets/ui/art/guide-attacks.png",
]

var failures: Array[String] = []


func _initialize() -> void:
	for script_path in SCRIPT_PATHS:
		var source := FileAccess.get_file_as_string(script_path)
		_check(not source.is_empty(), "%s must be readable" % script_path)
		_check("res://artifacts/" not in source, "%s must not depend on ignored artifact output" % script_path)
	for asset_path in REQUIRED_UI_ART:
		_check(ResourceLoader.exists(asset_path, "Texture2D"), "%s must be a tracked texture resource" % asset_path)

	if failures.is_empty():
		print("UI ASSET CONTRACT PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
