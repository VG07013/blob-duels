extends SceneTree

const GAME_PATH := "res://scripts/game.gd"

var failures: Array[String] = []


func _initialize() -> void:
	var source := FileAccess.get_file_as_string(GAME_PATH)
	_check(source.contains("func _force_first_person_camera()"), "matches and practice need an explicit first-person reset")
	_check(source.contains("func _enter_waiting_for_opponent()"), "hosting needs an explicit waiting state")
	_check(source.contains("func _begin_synchronized_round_countdown()"), "rounds need a server-owned synchronized countdown")
	_check(source.contains("for count in range(3, 0, -1)"), "round countdown must visibly run 3, 2, 1")
	_check(source.contains("func _assigned_spawn_for_local_player()"), "menu respawn needs a dedicated assigned-spawn resolver")
	_check(source.contains("elif not _round_countdown_active and not _round_resolving and not _match_over:"), "menu respawn must not unlock the player during countdown or round resolution")
	_check(source.contains("_respawn_player(false)\n\t\t_request_local_death(\"menu_respawn\")"), "live-duel menu respawn must immediately use the assigned spawn before reporting the round loss")
	_check(source.count("call_deferred(\"_begin_synchronized_round_countdown\")") >= 2, "peer join and setup request must both idempotently trigger the countdown")
	if failures.is_empty():
		print("MATCH STATE REGRESSION CONTRACT PASS")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
