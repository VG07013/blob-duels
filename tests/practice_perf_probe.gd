extends SceneTree

## BUG-028 measurement harness. Loads the real main scene, drops into the
## practice arena, and samples Godot's Performance counters over a fixed window.
##
## Needs a rendering device: run WITHOUT --headless.
##   godot --path . --script res://tests/practice_perf_probe.gd

const MAIN_SCENE := preload("res://scenes/main.tscn")

const WARMUP_FRAMES := 90
const SAMPLE_FRAMES := 300


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var game := MAIN_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	game.call("_start_practice_match")

	for _warmup in range(WARMUP_FRAMES):
		await process_frame

	var fps_total := 0.0
	var frame_total := 0.0
	var process_total := 0.0
	var physics_total := 0.0
	var draw_calls_total := 0.0
	var objects_total := 0.0
	var primitives_total := 0.0
	var worst_frame := 0.0
	var fps_minimum := 100000.0

	for _sample in range(SAMPLE_FRAMES):
		await process_frame
		var fps := Performance.get_monitor(Performance.TIME_FPS)
		var frame_time := Performance.get_monitor(Performance.TIME_PROCESS) + Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
		fps_total += fps
		fps_minimum = minf(fps_minimum, fps)
		frame_total += frame_time
		worst_frame = maxf(worst_frame, frame_time)
		process_total += Performance.get_monitor(Performance.TIME_PROCESS)
		physics_total += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
		draw_calls_total += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		objects_total += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
		primitives_total += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)

	var samples := float(SAMPLE_FRAMES)
	print("=== PRACTICE ARENA PROFILE (%d frames) ===" % SAMPLE_FRAMES)
	print("avg FPS                : %.1f" % (fps_total / samples))
	print("min FPS                : %.1f" % fps_minimum)
	print("avg script time (ms)   : %.3f  (process %.3f + physics %.3f)" % [
		(frame_total / samples) * 1000.0,
		(process_total / samples) * 1000.0,
		(physics_total / samples) * 1000.0,
	])
	print("worst script frame (ms): %.3f" % (worst_frame * 1000.0))
	print("avg draw calls / frame : %.0f" % (draw_calls_total / samples))
	print("avg objects / frame    : %.0f" % (objects_total / samples))
	print("avg primitives / frame : %.0f" % (primitives_total / samples))
	print("video memory (MB)      : %.1f" % (Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0))
	print("orphan nodes           : %d" % int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)))

	var arena := game.get_node_or_null("CityArena")
	if arena != null:
		var meshes := _count_of_type(arena, "MeshInstance3D")
		var multimeshes := _count_of_type(arena, "MultiMeshInstance3D")
		var shapes := _count_of_type(arena, "CollisionShape3D")
		print("practice arena         : %d MeshInstance3D, %d MultiMeshInstance3D, %d CollisionShape3D" % [meshes, multimeshes, shapes])

	quit(0)


func _count_of_type(node: Node, type_name: String) -> int:
	var total := 1 if node.is_class(type_name) else 0
	for child in node.get_children():
		total += _count_of_type(child, type_name)
	return total
