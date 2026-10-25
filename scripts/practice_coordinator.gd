class_name PracticeCoordinator
extends RefCounted

## The practice map's wiring between game.gd and the training layer: entering
## and leaving a practice match, turning the practice world on and off under
## the competitive maps, and the PracticeSession / PracticeHud signals. The
## session owns dummy configuration and shooting statistics; the practice HUD
## reads it. Both are torn down on the way out so a duel never inherits
## training settings. game.gd keeps `_practice_mode` because forty duel paths
## branch on it; everything that only matters in practice lives here.

var game: DuelGame


func setup(owner_game: DuelGame) -> void:
	game = owner_game
	game.practice_hud.reset_position_requested.connect(_on_reset_position)
	game.practice_hud.panel_visibility_changed.connect(_on_panel_visibility_changed)
	game.practice_session.dummy_shot_requested.connect(_on_dummy_shot_requested)
	game.practice_session.config_changed.connect(_on_config_changed)


func start_match() -> void:
	game._apply_lobby_identity()
	game.network_session.close_session()
	game._end_bot_match()
	game.local_peer_id = 1
	game._clear_remote_players()
	game.player.configure_local(game.local_peer_id)
	game._practice_mode = true
	game._peer_spawn_slots = {1: 0}
	activate_map()
	begin_session()
	game._start_arena_for_peer(game.local_peer_id)


func begin_session() -> void:
	var dummies: Array[DummyBlob] = []
	for node in game.get_tree().get_nodes_in_group("training_dummy"):
		var dummy := node as DummyBlob
		if dummy != null:
			dummies.append(dummy)
	game.practice_session.begin(game.player, dummies)
	game.practice_hud.set_practice_active(true)
	game.practice_hud.set_weapon_label(_weapon_label())
	_apply_player_switches()


func end_session() -> void:
	game.practice_session.end()
	game.practice_hud.set_practice_active(false)
	game.player.practice_unlimited_shots = false
	game.player.practice_skip_cooldowns = false
	# The panel's own visibility handler is already disarmed by this point
	# (_practice_mode is false), so the aim lock it set is cleared here rather
	# than left to whichever exit path happens to reset ability state.
	game.player.set_shooting_locked(false)


## Swaps the practice world in under the player and hands it the lighting.
func activate_map() -> void:
	game._clear_competitive_map()
	game.audio_manager.call("set_map_music_theme", &"", 0.0, false)
	set_world_enabled(true)
	game.spawn_manager.use_practice_map()
	# The map owns its look, same as every competitive arena.
	game._apply_lighting_profile(game.practice_arena.get_lighting_profile())


## The practice facility stays in main.tscn under every competitive map, so
## its visuals, collision and dummies are switched rather than freed.
func set_world_enabled(enabled: bool) -> void:
	game.practice_arena.visible = enabled
	var practice_collision := game.practice_arena.get_node_or_null("PracticeCollision") as StaticBody3D
	if practice_collision != null:
		practice_collision.collision_layer = 1 if enabled else 0
	for node in game.get_tree().get_nodes_in_group("training_dummy"):
		var dummy := node as RigidBody3D
		if dummy == null:
			continue
		dummy.visible = enabled
		dummy.freeze = not enabled
		dummy.collision_layer = 2 if enabled else 0
		var hurtbox := dummy.get_node_or_null("Hurtbox") as Area3D
		if hurtbox != null:
			hurtbox.collision_layer = 8 if enabled else 0
		var contact_area := dummy.get_node_or_null("ContactArea") as Area3D
		if contact_area != null:
			contact_area.collision_layer = 16 if enabled else 0
			contact_area.collision_mask = 16 if enabled else 0
		if enabled and dummy.has_method("respawn"):
			dummy.call("respawn")


func _weapon_label() -> String:
	var ability := game.player.get_equipped_ability()
	return "Blaster" if ability.is_empty() else "Blaster + %s" % ability.capitalize()


func _apply_player_switches() -> void:
	game.player.practice_unlimited_shots = game.practice_session.infinite_ammo
	game.player.practice_skip_cooldowns = not game.practice_session.cooldowns_enabled


func _on_config_changed() -> void:
	if game._practice_mode:
		_apply_player_switches()


func _on_reset_position() -> void:
	game._respawn_player(false)


## Opening the panel needs the cursor back; closing it returns to mouse-look.
func _on_panel_visibility_changed(panel_visible: bool) -> void:
	if not game._practice_mode:
		return
	if panel_visible:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	elif game.arena_started and not game.pause_menu.visible:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	game.player.set_shooting_locked(panel_visible)


## Combat-mode return fire. The dummy asks, the game spawns - so whether the
## shot can hurt the player stays one decision in one place.
func _on_dummy_shot_requested(dummy: Node3D, origin: Vector3, direction: Vector3) -> void:
	if not game._practice_mode or not game.arena_started:
		return
	var can_damage := game.practice_session.dummy_damage_enabled and not game.practice_session.player_invincible
	var projectile = DuelGame.PROJECTILE_SCENE.instantiate()
	projectile.name = "DummyShot_%s_%d" % [dummy.name, Time.get_ticks_usec()]
	game.projectiles.add_child(projectile)
	projectile.configure(origin, direction.normalized(), dummy, can_damage)
	projectile.hit_confirmed.connect(game._on_visual_projectile_hit)
	game.audio_manager.play_sfx_limited(&"projectile_fire", 0.06, -14.0, 1.06, &"dummy_projectile_fire")
