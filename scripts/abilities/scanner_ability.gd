class_name ScannerAbility
extends DuelAbility

## Highlights every blob within range for a few seconds. Purely a local
## information ability, so it needs no host path.


var scanned_targets: Array[Node3D] = []


func _init() -> void:
	id = "target_scanner"
	cooldown_msec = ABILITY_TUNING.SCANNER_COOLDOWN_MSEC
	duration_msec = ABILITY_TUNING.SCANNER_DURATION_MSEC


func activate(game: Node, now: int) -> bool:
	scanned_targets.clear()
	var candidates: Array[Node] = game.remote_players.get_children()
	if game._practice_mode:
		candidates.append_array(game.get_tree().get_nodes_in_group("training_dummy"))
	for candidate in candidates:
		var target := candidate as Node3D
		if target != null and target.global_position.distance_to(game.player.global_position) <= ABILITY_TUNING.SCANNER_RADIUS:
			scanned_targets.append(target)
			if target.has_method("set_scanner_highlight"):
				target.call("set_scanner_highlight", true)
	begin_window(now)
	game._spawn_scan_wave()
	game._spawn_impact_burst(game.player.global_position, Color(0.08, 0.58, 1.0), 1.35)
	return true


func tick(_game: Node, _now: int, _delta: float) -> void:
	for target in scanned_targets.duplicate():
		if not is_instance_valid(target) or int(target.get("health")) <= 0:
			if is_instance_valid(target) and target.has_method("set_scanner_highlight"):
				target.call("set_scanner_highlight", false)
			scanned_targets.erase(target)


func expire(game: Node, now: int) -> void:
	_clear_highlights()
	super(game, now)


func reset(game: Node) -> void:
	_clear_highlights()
	super(game)


func _clear_highlights() -> void:
	for target in scanned_targets:
		if is_instance_valid(target) and target.has_method("set_scanner_highlight"):
			target.call("set_scanner_highlight", false)
	scanned_targets.clear()
