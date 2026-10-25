extends SceneTree

const MAPS := [
	preload("res://scenes/world/practice_arena.tscn"),
	preload("res://scenes/world/maps/bounceground.tscn"),
	preload("res://scenes/world/maps/training_yard.tscn"),
	preload("res://scenes/world/maps/skyline.tscn"),
]
const MAIN_SCENE := preload("res://scenes/main.tscn")

var _failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for packed_map in MAPS:
		var arena := packed_map.instantiate() as Node3D
		root.add_child(arena)
		await process_frame
		var profile := arena.call("get_lighting_profile") as Dictionary
		var label := str(arena.get("map_name"))
		_expect(float(profile.get("ambient_energy", 2.0)) <= 0.72, "%s ambient energy avoids washed-out materials" % label)
		_expect(float(profile.get("sun_energy", 2.0)) <= 1.2, "%s sun energy preserves surface detail" % label)
		# Glow is opt-in per map with an explicit key: a profile that omits it
		# inherits whatever the engine default happens to be, which is exactly
		# how Toybox's deliberate no-bloom look would get silently overridden.
		_expect(profile.has("glow_enabled"), "%s must declare glow_enabled explicitly" % label)
		arena.queue_free()
		await process_frame
	var game := MAIN_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	game.call("_apply_lighting_profile", {"fog_density": 0.0012})
	var settings := game.get_node("PauseMenu").call("get_settings") as Dictionary
	settings["graphics_quality"] = 2
	game.call("_apply_settings", settings)
	var environment := game.get_node("WorldEnvironment") as WorldEnvironment
	_expect(is_equal_approx(environment.environment.fog_density, 0.0012), "graphics settings preserve the active map fog profile")
	settings["graphics_quality"] = 1
	game.call("_apply_settings", settings)
	game.call("_apply_lighting_profile", {"fog_density": 0.0012})
	_expect(is_equal_approx(environment.environment.fog_density, 0.0012 * 0.82), "map activation preserves the selected fog-quality multiplier")
	game.queue_free()
	await process_frame
	if _failures.is_empty():
		print("LIGHTING CONTRACT PASS")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
