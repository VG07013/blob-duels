extends SceneTree

## Renders the real end-of-match flow (bot duel, forced win) at several beats
## so the victory cinematic and results screen can be reviewed. Needs a display.
## Pass `-- --defeat` to capture the losing side.

const MAIN_SCENE := preload("res://scenes/main.tscn")
const OUTPUT_DIR := "res://artifacts/victory_shots"
const BEATS := [0.25, 0.6, 1.0, 1.7, 2.5, 3.0, 3.6, 5.0]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	root.size = Vector2i(1600, 900)
	var game := MAIN_SCENE.instantiate()
	root.add_child(game)
	await create_timer(0.6).timeout
	game.call("_start_bot_match")
	await create_timer(5.0).timeout
	var won := not OS.get_cmdline_user_args().has("--defeat")
	var winning_team := 0 if won else 1
	var target := int(game.get("_score_to_win"))
	var red := target if won else 2
	var blue := 3 if won else target
	game.set("_player_stats", {1: {"eliminations": red, "deaths": blue, "damage": 900, "trick_shots": 1}, 2: {"eliminations": blue, "deaths": red, "damage": 600, "trick_shots": 0}})
	# Sample rewards instead of award_match, so a capture never touches the save.
	game.set("_match_reward_awarded", true)
	game.call("_apply_round_result", red, blue, winning_team, false, true)
	create_timer(float((game.get_script() as Script).get_script_constant_map()["VICTORY_RESULTS_DELAY"]) + 0.05).timeout.connect(func() -> void:
		game.get_node("HUD").call("show_match_rewards", {
			"breakdown": [
				{"label": "Base Reward", "amount": 25},
				{"label": "Win Bonus" if won else "Runner-Up Bonus", "amount": 30 if won else 20},
				{"label": "Eliminations  x%d" % red, "amount": red * 5},
				{"label": "Damage Dealt  900", "amount": 22},
			],
			"total": 77 + red * 5,
			"quest_ticks": [{"title": "Get 100 Eliminations", "delta": red, "progress": 45, "target": 100, "completed": false}],
		})
	)
	var elapsed := 0.0
	for index in BEATS.size():
		await create_timer(float(BEATS[index]) - elapsed).timeout
		elapsed = float(BEATS[index])
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		image.save_png(ProjectSettings.globalize_path("%s/%s_%02d_%.1fs.png" % [OUTPUT_DIR, "win" if won else "loss", index, elapsed]))
	print("Mouse mode: ", Input.get_mouse_mode())
	quit(0)
