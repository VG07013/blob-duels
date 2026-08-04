extends SceneTree

## BUG-025: damage applied but the nameplate health bar never moved.
##
## The GDScript was always correct - it sets health_fill.scale.x from the health
## ratio. The bar was billboarded, and Godot's billboard vertex path rebuilds the
## modelview basis from the camera, which discards the node's scale unless the
## material sets billboard_keep_scale. So the scale was computed on the CPU and
## thrown away on the GPU, which is why the blob still died on schedule.
##
## Asserts both halves: the material keeps scale, and the script actually drives
## the fill from health.

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const DUMMY_SCENE := preload("res://scenes/player/dummy_blob.tscn")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for entry in [{"scene": PLAYER_SCENE, "label": "Player"}, {"scene": DUMMY_SCENE, "label": "Dummy"}]:
		var blob := (entry["scene"] as PackedScene).instantiate()
		root.add_child(blob)
		await process_frame

		var fill := blob.get_node_or_null("Nameplate/HealthFill") as MeshInstance3D
		_check(fill != null, "%s must have a Nameplate/HealthFill to show damage" % entry["label"])
		if fill != null:
			var material := (fill.mesh as PrimitiveMesh).material as BaseMaterial3D
			_check(material != null, "%s health fill must carry a material" % entry["label"])
			# Two regressions live here. Billboarding without keep_scale made the
			# GPU discard the fill's scale (the bar never moved); billboarding
			# per-material at all made each quad rotate around its own origin, so
			# fill and backing drifted apart at any viewing angle and read as two
			# separate shapes. The bar quads must not self-billboard - the
			# Nameplate node orients the whole assembly toward the camera.
			var background := blob.get_node_or_null("Nameplate/HealthBackground") as MeshInstance3D
			_check(background != null, "%s must keep the bar backing quad" % entry["label"])
			for bar_part in [fill, background]:
				if bar_part == null:
					continue
				var part_material := (bar_part.mesh as PrimitiveMesh).material as BaseMaterial3D
				_check(
					part_material != null and part_material.billboard_mode == BaseMaterial3D.BILLBOARD_DISABLED,
					"%s %s must not billboard per-material; the nameplate node orients the fused bar" % [entry["label"], bar_part.name]
				)

			var full_width := fill.scale.x
			blob.set("health", int(blob.get("max_health")) / 2)
			blob.call("_update_health_billboard")
			_check(fill.scale.x < full_width, "%s health fill must narrow when health drops" % entry["label"])
			_check(is_equal_approx(fill.scale.x, 0.5), "%s health fill width must track the health ratio" % entry["label"])

			var half_offset := fill.position.x
			blob.set("health", 0)
			blob.call("_update_health_billboard")
			_check(is_zero_approx(fill.scale.x), "%s health fill must be empty at zero health" % entry["label"])
			# Left-anchored depletion: the bar shrinks leftward, so the origin
			# keeps sliding negative rather than staying centred.
			_check(fill.position.x < half_offset, "%s health fill must deplete from the left edge, not its centre" % entry["label"])

		blob.queue_free()
		await process_frame

	if failures.is_empty():
		print("HEALTH BAR CONTRACT PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("HEALTH BAR CONTRACT FAILURES: %d" % failures.size())
	quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
