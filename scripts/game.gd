extends Node3D

## Where the local blob waits, frozen, while the main menu is up. Far from
## every map so nothing there can touch it.
const MENU_PARK_POSITION := Vector3(0.0, 1.8, 634.0)
const BASE_CANVAS_SIZE := Vector2i(1280, 720)
const MINIMUM_WINDOW_SIZE := Vector2i(640, 360)
const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const PROJECTILE_SCENE: PackedScene = preload("res://scenes/player/projectile.tscn")
const BOUNCE_MINE_SCENE: PackedScene = preload("res://scenes/effects/bounce_mine.tscn")
const IMPACT_BURST_SCENE: PackedScene = preload("res://scenes/effects/impact_burst.tscn")
const COSMETIC_LIBRARY := preload("res://scripts/cosmetic_library.gd")
const ABILITY_TUNING := preload("res://scripts/ability_tuning.gd")
const ABILITY_CONTROLLER := preload("res://scripts/abilities/ability_controller.gd")
const ABILITY_REGISTRY := preload("res://scripts/abilities/ability_registry.gd")
const ABILITY_HUD_SCRIPT := preload("res://scripts/ui/ability_hud.gd")
const SERVER_PEER_REGISTRY := preload("res://scripts/net/server_peer_registry.gd")
const BOT_OPPONENT := preload("res://scripts/bot_opponent.gd")
const BOT_TUNING := preload("res://scripts/bot_tuning.gd")
const INPUT_BINDINGS := preload("res://scripts/input_bindings.gd")
const COMBAT_TUNING := preload("res://scripts/combat_tuning.gd")
## Panoramic sky-cover textures lighting profiles opt into by name (see
## scripts/tools/bake_texture_maps.gd for how they are produced).
const SKY_COVER_TEXTURES := {
	"clouds": preload("res://assets/textures/sky_cloud_cover.png"),
	"stars": preload("res://assets/textures/sky_star_field.png"),
}
## Competitive maps: Bounceground and Arena (id "skyline", Blender-built); older maps live in archive/maps/.
const DEFAULT_MAP_ID := "skyline"
const COMPETITIVE_MAP_SCENES := {
	"skyline": preload("res://scenes/world/maps/skyline.tscn"),
	"bounceground": preload("res://scenes/world/maps/bounceground.tscn"),
}
const MAP_DISPLAY_NAMES := {
	"bounceground": "Bounceground",
	"skyline": "Arena",
}
const TEAM_RED := 0
const TEAM_BLUE := 1
## Default first-to score; the host can change it per match (see
## set_match_format), and every clamp reads _score_to_win.
const SCORE_TO_WIN := 5
const MIN_SCORE_TO_WIN := 1
const MAX_SCORE_TO_WIN := 15
const MIN_ROUND_SECONDS := 30.0
## Share of ambient light taken from the sky; the rest is the profile colour.
const DEFAULT_AMBIENT_SKY_CONTRIBUTION := 0.3
## Victory staging: the winner celebrates on its own spawn deck (always open
## floor on every map) and the camera searches for a clear line to it instead
## of using one fixed world point that sat inside scenery on several maps.
const VICTORY_CAMERA_DISTANCE := 17.0
const VICTORY_CAMERA_MIN_DISTANCE := 8.0
const VICTORY_CAMERA_HEIGHT := 5.5
const VICTORY_CAMERA_CLEARANCE := 1.1
const VICTORY_CAMERA_ANGLES_DEGREES := [0.0, 30.0, -30.0, 60.0, -60.0, 90.0, -90.0, 135.0, -135.0, 180.0]
## Celebration choreography, in seconds from the moment the camera cuts to
## the winner: [takeoff, airtime, apex height, full spins]. The first leap is
## the big one; after the last scripted hop the blob keeps an idle bounce going
## under the results screen.
const VICTORY_HOPS := [[0.3, 0.74, 4.6, 1.0], [1.26, 0.42, 2.1, 0.0], [1.86, 0.34, 1.1, 0.0]]
const VICTORY_IDLE_START := 2.9
const VICTORY_IDLE_PERIOD := 1.25
const VICTORY_IDLE_AIRTIME := 0.4
const VICTORY_IDLE_HEIGHT := 0.85
## Crouch before a hop and the squash-jiggle after landing.
const VICTORY_ANTICIPATION_TIME := 0.22
const VICTORY_ANTICIPATION_SQUASH := 0.3
const VICTORY_LANDING_SQUASH := 0.34
const VICTORY_TAKEOFF_STRETCH := 0.2
## Camera: starts high and wide, pushes in and drifts round the winner.
const VICTORY_CAMERA_PUSH_TIME := 2.6
const VICTORY_CAMERA_PUSH := 0.86
## Share of the blob's hop height the camera tilts up to follow.
const VICTORY_CAMERA_FOLLOW := 0.5
const VICTORY_CAMERA_RISE := 2.6
const VICTORY_CAMERA_ORBIT_DEGREES := 11.0
const VICTORY_CAMERA_ORBIT_SPEED := 0.32
const VICTORY_CAMERA_FOV_START := 66.0
const VICTORY_CAMERA_FOV_END := 56.0
## When the results UI slides in, relative to the camera cut.
const VICTORY_RESULTS_DELAY := 2.35
const VICTORY_TARGET_LIFT := 1.2
const VICTORY_FLOOR_PROBE_UP := 6.0
const VICTORY_FLOOR_PROBE_DOWN := 40.0
## World and scenery collision layers the camera must not sit inside.
const VICTORY_CAMERA_MASK := 1 | 8
const MIN_EXPOSURE := 0.6
const MAX_EXPOSURE := 1.6
const MAX_ROUND_SECONDS := 600.0
## Peer id reserved for the offline bot. Real ENet clients never receive it
## because the bot only exists while the session is offline.
const BOT_PEER_ID := 2
## Impacts gentler than this never shake the camera (BUG-030). Landings and
## wall hits clear it easily; rolling contacts do not.
const IMPACT_SHAKE_MIN_STRENGTH := 9.0
## Volume that tells _on_opponent_movement_cue to stay quiet.
const SILENT_CUE_DB := -80.0
const DRAW_WINDOW_MSEC := 35
const DEATH_RESOLUTION_MSEC := 90
const ROUND_COUNTDOWN_SECONDS := 3
const MAX_REMOTE_STATE_SPEED := 138.0
const MAX_REMOTE_STATE_STEP := 50.0
const MIN_REMOTE_STATE_INTERVAL_MSEC := 25
const REMOTE_STATE_LEEWAY := 0.35
const NETWORK_SHOT_COOLDOWN_MSEC := 160
## TEAM_RED is shown to players as the Orange team; the constant names stay
## so every team lookup keeps working.
const RED_TEAM_COLOR := Color(1.0, 0.5, 0.08, 1.0)
const BLUE_TEAM_COLOR := Color(0.02, 0.82, 1.0, 1.0)
const REMOTE_COLORS := [
	Color(1.0, 0.28, 0.42, 1.0),
	Color(1.0, 0.72, 0.12, 1.0),
	Color(0.54, 0.34, 1.0, 1.0),
]

@export var mouse_sensitivity := 0.0025
@export var camera_follow_speed := 14.0
@export var network_sync_rate := 30.0
@export_range(0.0, 1.0, 0.05) var camera_shake_scale := 0.72
## Every round is a minute and a half. When it runs out, the blob with more
## health takes the round (a tie is settled at random, never a draw).
@export var match_duration := 90.0

@onready var player: BlobPlayer = $Player
@onready var camera_rig: Node3D = $CameraRig
@onready var camera: Camera3D = $CameraRig/Camera3D
@onready var hud: DuelHud = $HUD
@onready var practice_arena: PracticeArena = $PracticeArena
@onready var practice_session: PracticeSession = $PracticeSession
@onready var practice_hud: PracticeHud = $PracticeHud
@onready var competitive_map_root: Node3D = $CompetitiveMapRoot
@onready var spawn_manager: Node3D = $SpawnManager
@onready var remote_players: Node3D = $RemotePlayers
@onready var projectiles: Node3D = $Projectiles
@onready var network_session: Node = get_node("/root/NetworkSession")
@onready var pause_menu: PauseMenu = $PauseMenu
@onready var sun: DirectionalLight3D = $Sun
@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var audio_manager: Node = get_node("/root/AudioManager")

var camera_yaw := 0.0
var camera_pitch := 0.0
var third_person_enabled := true
var arena_started := false
var local_peer_id := 1
var _network_sync_accumulator := 0.0
var _camera_base_position := Vector3.ZERO
var _camera_shake_amount := 0.0
var _camera_shake_time := 0.0
var _fling_fov_kick := 0.0
## 0 = hip view, 1 = fully aimed in (right click / left trigger). Eased, so
## the zoom and the slower look both blend rather than snap.
var _aim_blend := 0.0
## Blobs hidden for losing the current round; restored at the next countdown.
var _hidden_round_losers: Array[Dictionary] = []
# Look/FOV settings applied through _apply_settings; tuning lives in InputBindings.
var _gamepad_sensitivity: float = INPUT_BINDINGS.GAMEPAD_SENSITIVITY_DEFAULT
var _invert_look := false
var _base_fov: float = INPUT_BINDINGS.FOV_DEFAULT
var _match_time_remaining := 90.0
var _match_timer_running := false
var _practice_mode := false
var _selected_map_id := DEFAULT_MAP_ID
var _current_competitive_map: Node3D
var _peer_spawn_slots: Dictionary = {1: 0}
var _red_score := 0
var _blue_score := 0
var _round_number := 1
var _round_resolving := false
var _match_over := false
var _waiting_for_opponent := false
var _round_countdown_active := false
var _round_countdown_generation := 0
var _local_death_reported := false
var _pending_deaths: Dictionary = {}
var _death_resolution_deadline := 0
var _player_stats: Dictionary = {}
var _victory_sequence_active := false
var _victory_camera_target := Vector3(0.0, 3.2, 0.0)
var _victory_camera_position := Vector3(22.0, 8.0, 28.0)
var _victory_elapsed := 0.0
var _victory_blob: RigidBody3D
var _victory_stage := Vector3.ZERO
## Host-side authority over every connected peer: health, cooldowns, ability
## timers, and the last accepted position. Only populated when this instance is
## the server.
var _server_peers := SERVER_PEER_REGISTRY.new()
var _visual_bounce_mines: Dictionary = {}
var _active_lighting_profile: Dictionary = {}
var _graphics_quality := 1
var _effects_quality := 1
var _match_reward_awarded := false
var _score_to_win := SCORE_TO_WIN
## The offline bot opponent, present only during a bot duel.
var _bot: BotOpponent
var _bot_active := false
var _lobby_hud_suppressed_for_pause := false
## Feedback and quest bookkeeping only - never authoritative. `_stat_last_hit`
## is keyed by the peer that was hit: {shooter, kind, time}. The round counters
## reset in _apply_round_result, so the first round of a match starts clean.
var _stat_last_hit: Dictionary = {}
var _stat_round_damage_taken := 0
var _stat_round_bounce_mark := 0
var _stat_round_trick_shots := 0
const STAT_HIT_MEMORY_MSEC := 4000
const STAT_INTERACTABLE_MEMORY_MSEC := 5000
const STAT_INTERACTABLE_META_PREFIXES := ["map_launch_", "directional_bumper_", "laser_gate_", "map_bumper_"]
## The equipped ability's runtime plus the host-side ability table. Every
## ability lives in scripts/abilities/; game.gd only forwards events.
var _abilities := ABILITY_CONTROLLER.new()
var _active_bounce_mine: Node3D
## Blobs highlighted by the Target Scanner, exposed for the practice contract.
var _scanned_targets: Array[Node3D]:
	get:
		var scanner := _abilities.current as ScannerAbility
		return scanner.scanned_targets if scanner != null else []
var _last_fling_charge_tier := 0
## Process frame of the last dedicated movement cue (jump, air jump, wall
## kick, slam), so the generic bounce boing does not double it.
var _movement_cue_frame := -1
var _rail_telegraph: MeshInstance3D



func _ready() -> void:
	_configure_scalable_canvas()
	_ensure_input_actions()
	_connect_session_signals()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	# On-demand peer entries start at full health, matching the defaults the
	# per-peer dictionaries used to supply at every read site.
	_server_peers.default_health = player.max_health
	player.configure_local(1)
	player.set_shooting_enabled(false)
	player.fling_released.connect(_on_player_fling_released)
	player.fling_charge_started.connect(_on_player_fling_charge_started)
	player.fling_maximum_reached.connect(_on_player_fling_maximum_reached)
	player.fling_charge_updated.connect(_on_player_fling_charge_updated)
	player.shoot_requested.connect(_handle_local_shot)
	player.bounce_counted.connect(_on_player_bounce_counted)
	player.bounce_triggered.connect(_on_player_bounce_triggered)
	player.impact_event.connect(_on_player_impact)
	player.damaged.connect(_on_player_damaged)
	player.respawned.connect(_on_player_respawned)
	player.knocked_out.connect(_on_player_knocked_out)
	player.network_collision_requested.connect(_on_network_collision_requested)
	player.hotbar_slot_changed.connect(_on_local_hotbar_slot_changed)
	player.jumped.connect(_on_player_jumped)
	player.air_jumped.connect(_on_player_air_jumped)
	player.landed.connect(_on_player_landed)
	player.wall_kicked.connect(_on_player_wall_kicked)
	player.slam_started.connect(_on_player_slam_started)
	player.slam_landed.connect(_on_player_slam_landed)
	player.power_slide_changed.connect(_on_player_power_slide_changed)
	player.power_slide_hopped.connect(_on_player_power_slide_hopped)
	hud.bind_player(player)
	hud.host_requested.connect(_on_host_requested)
	hud.join_requested.connect(_on_join_requested)
	hud.practice_requested.connect(_start_practice_match)
	hud.bot_requested.connect(_start_bot_match)
	hud.rematch_requested.connect(_on_rematch_requested)
	hud.match_format_changed.connect(set_match_format)
	hud.settings_requested.connect(_open_lobby_settings)
	hud.return_to_lobby_requested.connect(_return_to_lobby)
	hud.identity_changed.connect(_on_identity_changed)
	_apply_lobby_identity()
	hud.set_lobby_mode(true)
	hud.set_join_status("Choose Host, Join, or Practice", false)
	practice_hud.bind_session(practice_session)
	practice_hud.reset_position_requested.connect(_on_practice_reset_position)
	practice_hud.clear_projectiles_requested.connect(_clear_projectiles)
	practice_hud.panel_visibility_changed.connect(_on_practice_panel_visibility_changed)
	practice_session.dummy_shot_requested.connect(_on_dummy_shot_requested)
	practice_session.config_changed.connect(_on_practice_config_changed)
	pause_menu.resume_requested.connect(_resume_from_pause)
	pause_menu.respawn_requested.connect(_on_pause_respawn_requested)
	pause_menu.back_to_lobby_requested.connect(_return_to_lobby)
	pause_menu.settings_applied.connect(_apply_settings)
	audio_manager.wire_ui_sounds(hud)
	var progression := get_node_or_null("/root/Progression")
	if progression != null:
		progression.inventory_changed.connect(_apply_local_cosmetics)
	_apply_local_cosmetics()
	audio_manager.wire_ui_sounds(pause_menu)
	_apply_settings(pause_menu.get_settings())
	_apply_camera_mode()
	_set_practice_world_enabled(false)
	_set_menu_world_parked(true)
	audio_manager.set_music_context(&"lobby", 0.0)


func _configure_scalable_canvas() -> void:
	var root_window := get_tree().root
	root_window.content_scale_size = BASE_CANVAS_SIZE
	root_window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root_window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root_window.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_FRACTIONAL
	root_window.content_scale_factor = 1.0
	root_window.min_size = MINIMUM_WINDOW_SIZE


func _connect_session_signals() -> void:
	network_session.state_changed.connect(_on_network_state_changed)
	network_session.session_ready.connect(_on_network_session_ready)
	network_session.peer_joined.connect(_on_network_peer_joined)
	network_session.peer_left.connect(_on_network_peer_left)


func _unhandled_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if not _victory_sequence_active and motion != null and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		var look_sensitivity := mouse_sensitivity * _aim_sensitivity_factor()
		camera_yaw -= motion.relative.x * look_sensitivity
		camera_pitch = clamp(camera_pitch - motion.relative.y * look_sensitivity * _look_pitch_sign(), -PI * 0.495, PI * 0.495)

	if event.is_action_pressed("pause"):
		if hud.is_progression_open():
			hud.close_progression()
			get_viewport().set_input_as_handled()
			return
		if pause_menu.is_open():
			pause_menu.handle_escape()
		elif not arena_started:
			# The main menu has nothing to pause; Esc goes straight to settings.
			_open_lobby_settings()
		else:
			_open_pause()
		get_viewport().set_input_as_handled()
		return

	if _practice_mode and arena_started and event.is_action_pressed("practice_panel"):
		practice_hud.toggle_panel()
		get_viewport().set_input_as_handled()
		return

	if arena_started and not _victory_sequence_active and event.is_action_pressed("toggle_camera"):
		third_person_enabled = not third_person_enabled
		_apply_camera_mode()

	if event.is_action_pressed("use_ability"):
		_use_equipped_ability()

	var mouse_button := event as InputEventMouseButton
	# The results screen needs the cursor for Rematch / Main Menu.
	if arena_started and not _victory_sequence_active and mouse_button != null and mouse_button.pressed and Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
		# The practice panel needs the cursor; clicking a control there must not
		# yank mouse-look back.
		if not practice_hud.is_panel_open():
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _process(delta: float) -> void:
	if _victory_sequence_active:
		_victory_elapsed += delta
		_update_player_audio()
		_update_victory_pose()
		_update_victory_camera(delta)
		return
	_apply_gamepad_look(delta)
	player.aim_yaw = camera_yaw
	player.aim_direction = -camera_rig.global_transform.basis.z.normalized()

	var target_position: Vector3 = player.global_position + Vector3(0.0, 1.8, 0.0)
	if third_person_enabled:
		var t := 1.0 - exp(-camera_follow_speed * delta)
		camera_rig.global_position = camera_rig.global_position.lerp(target_position, t)
	else:
		camera_rig.global_position = target_position
	camera_rig.rotation = Vector3(camera_pitch, camera_yaw, 0.0)
	_update_speed_fov(delta)
	_update_player_audio()
	_update_camera_shake(delta)
	_update_match_timer(delta)
	_update_fling_cooldown_hud()
	_process_pending_round_death()
	_process_bot()
	_process_ability_state(delta)
	_apply_remote_gravity_pulses(delta)

	if arena_started and spawn_manager.is_outside_arena(player.global_position):
		if _practice_mode:
			_respawn_player(false)
		else:
			_request_local_death("fall")


func _physics_process(delta: float) -> void:
	if not arena_started or not network_session.is_online():
		return

	_network_sync_accumulator += delta
	if _network_sync_accumulator < 1.0 / network_sync_rate:
		return
	_network_sync_accumulator = 0.0

	if multiplayer.is_server():
		_broadcast_player_state.rpc(local_peer_id, player.global_position, player.rotation, player.linear_velocity, player.health, player.display_name, player.blob_color, player.aim_direction, Time.get_ticks_msec())
	else:
		_submit_player_state.rpc_id(1, player.global_position, player.rotation, player.linear_velocity, player.health, player.display_name, player.blob_color, player.aim_direction)


func _on_host_requested() -> void:
	_apply_lobby_identity()
	_end_bot_match()
	set_match_format(hud.get_selected_score_to_win(), hud.get_selected_round_seconds())
	_selected_map_id = _validated_map_id(hud.get_selected_map_id())
	_peer_spawn_slots = {1: 0}
	hud.set_join_status("Starting host...", true)
	var result: Error = network_session.host_game()
	if result != OK:
		hud.set_join_status(str(network_session.get("status_message")), false)


func _on_join_requested(room_code: String) -> void:
	_apply_lobby_identity()
	_end_bot_match()
	hud.set_join_status("Connecting with code %s..." % room_code, true)
	var result: Error = network_session.join_game_by_code(room_code)
	if result != OK:
		hud.set_join_status(str(network_session.get("status_message")), false)


func _on_identity_changed(display_name: String, color: Color) -> void:
	if not arena_started:
		player.set_player_identity(display_name, color)


func _apply_lobby_identity() -> void:
	player.set_player_identity(hud.get_player_name(), hud.get_player_color())
	_apply_local_cosmetics()


func _apply_local_cosmetics() -> void:
	var progression := get_node_or_null("/root/Progression")
	if progression == null or player == null:
		return
	player.apply_equipped_cosmetics(
		str(progression.call("get_equipped", "skins")),
		str(progression.call("get_equipped", "trails")),
		str(progression.call("get_equipped", "faces")),
		str(progression.call("get_equipped", "kill_effects")),
	)
	player.set_cosmetic_quality(_graphics_quality)
	player.set_equipped_ability(str(progression.call("get_equipped", "abilities")))


func _start_practice_match() -> void:
	_apply_lobby_identity()
	network_session.close_session()
	_end_bot_match()
	local_peer_id = 1
	_clear_remote_players()
	player.configure_local(local_peer_id)
	_practice_mode = true
	_peer_spawn_slots = {1: 0}
	_activate_practice_map()
	_begin_practice_session()
	_start_arena_for_peer(local_peer_id)


## Practice session ------------------------------------------------------------
## The session owns dummy configuration and shooting statistics; the practice
## HUD reads it. Both are torn down on the way out so a duel never inherits
## training settings.
## Bot duel ---------------------------------------------------------------------
## An offline duel against BotOpponent. The bot is registered as peer
## BOT_PEER_ID with its own authoritative state, so every round, hit and death
## runs through the same host paths a connected player uses.
func _start_bot_match(difficulty: int = BOT_TUNING.DEFAULT_DIFFICULTY) -> void:
	_apply_lobby_identity()
	network_session.close_session()
	_end_bot_match()
	local_peer_id = 1
	_clear_remote_players()
	player.configure_local(local_peer_id)
	_practice_mode = false
	_end_practice_session()
	hud.set_practice_mode(false)
	_selected_map_id = _validated_map_id(hud.get_selected_map_id())
	_peer_spawn_slots = {1: 0}
	_reset_duel_match_state()
	_bot_active = true
	_assign_spawn_slot(BOT_PEER_ID)
	_ensure_player_stats(BOT_PEER_ID)
	var bot_state := _server_peers.state_for(BOT_PEER_ID)
	bot_state.health = player.max_health
	bot_state.note_position(spawn_manager.get_spawn_for_slot(_spawn_slot_for_peer(BOT_PEER_ID)), Time.get_ticks_msec())
	_activate_competitive_map(_selected_map_id)
	_start_arena_for_peer(local_peer_id)
	var body := _ensure_remote_player(BOT_PEER_ID) as RigidBody3D
	body.configure_local(BOT_PEER_ID)
	body.set_input_enabled(false)
	body.set_shooting_enabled(false)
	body.freeze = true
	var bot_color: Color = BLUE_TEAM_COLOR if _team_for_peer(BOT_PEER_ID) == TEAM_BLUE else RED_TEAM_COLOR
	body.apply_network_identity(BOT_TUNING.BOT_DISPLAY_NAME, bot_color)
	body.network_collision_requested.connect(_on_bot_collision_requested)
	_connect_opponent_movement_audio(body)
	_bot = BOT_OPPONENT.new()
	_bot.name = "BotOpponent"
	add_child(_bot)
	_bot.configure(body, player, difficulty, spawn_manager.is_outside_arena, Vector3.ZERO)
	_bot.shot_requested.connect(_on_bot_shot_requested)
	call_deferred("_begin_synchronized_round_countdown")


func _end_bot_match() -> void:
	if not _bot_active and _bot == null:
		return
	_bot_active = false
	if _bot != null:
		_bot.set_round_active(false)
		_bot.queue_free()
		_bot = null
	_peer_spawn_slots.erase(BOT_PEER_ID)
	_server_peers.remove(BOT_PEER_ID)
	var body := remote_players.get_node_or_null(_remote_player_name(BOT_PEER_ID))
	if body != null:
		body.queue_free()


func _is_bot_round_live() -> bool:
	return _bot_active and _bot != null and arena_started and not _waiting_for_opponent and not _round_countdown_active and not _round_resolving and not _match_over


## Mirrors the bot body's simulated health into its authoritative state and
## reports falls, the two things a connected client would otherwise send.
func _process_bot() -> void:
	if not _is_bot_round_live():
		return
	var body := _bot.body
	if body == null or not is_instance_valid(body):
		return
	var state := _server_peers.state_for(BOT_PEER_ID)
	var body_health := int(body.get("health"))
	if body_health < state.health:
		state.health = body_health
	if state.health <= 0:
		_register_round_death(BOT_PEER_ID, "health")
	elif spawn_manager.is_outside_arena(body.global_position):
		_register_round_death(BOT_PEER_ID, "fall")


func _on_bot_shot_requested(origin: Vector3, direction: Vector3) -> void:
	if not _is_bot_round_live() or not origin.is_finite() or not direction.is_finite():
		return
	var bot_body := remote_players.get_node_or_null(_remote_player_name(BOT_PEER_ID))
	if bot_body != null and bot_body.has_method("is_blob_mode") and bool(bot_body.call("is_blob_mode")):
		return
	var now := Time.get_ticks_msec()
	var state := _server_peers.state_for(BOT_PEER_ID)
	if now < state.shot_ready_at:
		return
	state.shot_ready_at = now + NETWORK_SHOT_COOLDOWN_MSEC
	_spawn_projectile(BOT_PEER_ID, origin, direction.normalized(), true)


## The bot body arbitrates blob collisions like any higher-id peer; its
## requests land on the local player directly.
func _on_bot_collision_requested(target_peer_id: int, impulse: Vector3, damage: int) -> void:
	if not _is_bot_round_live() or target_peer_id != local_peer_id:
		return
	player.receive_collision_impact(clampi(damage, 0, 60), impulse.limit_length(230.0))


func _begin_practice_session() -> void:
	var dummies: Array[DummyBlob] = []
	for node in get_tree().get_nodes_in_group("training_dummy"):
		var dummy := node as DummyBlob
		if dummy != null:
			dummies.append(dummy)
	practice_session.begin(player, dummies)
	practice_hud.set_practice_active(true)
	practice_hud.set_weapon_label(_practice_weapon_label())
	_apply_practice_player_switches()


func _end_practice_session() -> void:
	practice_session.end()
	practice_hud.set_practice_active(false)
	player.practice_unlimited_shots = false
	player.practice_skip_cooldowns = false
	# The panel's own visibility handler is already disarmed by this point
	# (_practice_mode is false), so the aim lock it set is cleared here rather
	# than left to whichever exit path happens to reset ability state.
	player.set_shooting_locked(false)


func _practice_weapon_label() -> String:
	var ability := player.get_equipped_ability()
	return "Blaster" if ability.is_empty() else "Blaster + %s" % ability.capitalize()


func _apply_practice_player_switches() -> void:
	player.practice_unlimited_shots = practice_session.infinite_ammo
	player.practice_skip_cooldowns = not practice_session.cooldowns_enabled


func _on_practice_config_changed() -> void:
	if _practice_mode:
		_apply_practice_player_switches()


func _on_practice_reset_position() -> void:
	_respawn_player(false)


## Opening the panel needs the cursor back; closing it returns to mouse-look.
func _on_practice_panel_visibility_changed(panel_visible: bool) -> void:
	if not _practice_mode:
		return
	if panel_visible:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	elif arena_started and not pause_menu.visible:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	player.set_shooting_locked(panel_visible)


## Combat-mode return fire. The dummy asks, the game spawns - so whether the
## shot can hurt the player stays one decision in one place.
func _on_dummy_shot_requested(dummy: Node3D, origin: Vector3, direction: Vector3) -> void:
	if not _practice_mode or not arena_started:
		return
	var can_damage := practice_session.dummy_damage_enabled and not practice_session.player_invincible
	var projectile = PROJECTILE_SCENE.instantiate()
	projectile.name = "DummyShot_%s_%d" % [dummy.name, Time.get_ticks_usec()]
	projectiles.add_child(projectile)
	projectile.configure(origin, direction.normalized(), dummy, can_damage)
	projectile.hit_confirmed.connect(_on_visual_projectile_hit)
	audio_manager.play_sfx_limited(&"projectile_fire", 0.06, -14.0, 1.06, &"dummy_projectile_fire")


func _on_network_session_ready(is_host: bool) -> void:
	local_peer_id = multiplayer.get_unique_id()
	_clear_remote_players()
	player.configure_local(local_peer_id)
	_practice_mode = false
	_end_practice_session()
	if is_host:
		_peer_spawn_slots = {1: 0}
		_reset_duel_match_state()
		_activate_competitive_map(_selected_map_id)
		_start_arena_for_peer(local_peer_id)
	else:
		hud.set_join_status("Connected - loading host map...", true)
		_request_match_setup.rpc_id(1, player.get_equipped_ability())


func _on_network_state_changed(_state: int, message: String) -> void:
	hud.set_join_status(message, network_session.is_joining())


func _on_network_peer_joined(peer_id: int) -> void:
	if peer_id == local_peer_id:
		return
	if multiplayer.is_server():
		_assign_spawn_slot(peer_id)
		_ensure_player_stats(peer_id)
		var joined_state := _server_peers.state_for(peer_id)
		joined_state.health = player.max_health
		joined_state.note_position(spawn_manager.get_spawn_for_slot(_spawn_slot_for_peer(peer_id)), Time.get_ticks_msec())
		_receive_match_setup.rpc(_selected_map_id, _peer_spawn_slots, _red_score, _blue_score, _score_to_win, match_duration)
		call_deferred("_begin_synchronized_round_countdown")
	if arena_started:
		_ensure_remote_player(peer_id)


func _on_network_peer_left(peer_id: int) -> void:
	_peer_spawn_slots.erase(peer_id)
	# remove() frees the peer's authoritative mine along with its state.
	_server_peers.remove(peer_id)
	var visual_mine := _visual_bounce_mines.get(peer_id) as Node
	if is_instance_valid(visual_mine):
		visual_mine.queue_free()
	if _active_bounce_mine == visual_mine:
		_active_bounce_mine = null
	_visual_bounce_mines.erase(peer_id)
	var remote := remote_players.get_node_or_null(_remote_player_name(peer_id))
	if remote != null:
		remote.queue_free()
	if multiplayer.is_server() and network_session.is_online():
		_enter_waiting_for_opponent()


@rpc("any_peer", "call_remote", "reliable")
func _request_match_setup(equipped_ability: String = "") -> void:
	if not multiplayer.is_server():
		return
	var requester_id := multiplayer.get_remote_sender_id()
	_assign_spawn_slot(requester_id)
	_register_server_peer_loadout(requester_id, equipped_ability)
	_receive_match_setup.rpc_id(requester_id, _selected_map_id, _peer_spawn_slots, _red_score, _blue_score, _score_to_win, match_duration)
	call_deferred("_begin_synchronized_round_countdown")


func _register_server_peer_loadout(peer_id: int, equipped_ability: String) -> void:
	var state := _server_peers.state_for(peer_id)
	if state.loadout_registered:
		return
	var supported := ABILITY_REGISTRY.host_validated_ids()
	state.equipped_ability = equipped_ability if supported.has(equipped_ability) else ""
	state.loadout_registered = true


@rpc("authority", "call_remote", "reliable")
func _receive_match_setup(map_id: String, spawn_slots: Dictionary, red_score: int, blue_score: int, score_to_win: int = SCORE_TO_WIN, round_seconds: float = 180.0) -> void:
	# The host has just (re)built this peer's state; tell it which slot is up.
	_on_local_hotbar_slot_changed(player.get_hotbar_slot())
	_selected_map_id = _validated_map_id(map_id)
	_apply_match_format(score_to_win, round_seconds)
	_peer_spawn_slots = spawn_slots.duplicate()
	_red_score = clampi(red_score, 0, _score_to_win)
	_blue_score = clampi(blue_score, 0, _score_to_win)
	local_peer_id = multiplayer.get_unique_id()
	_practice_mode = false
	_end_practice_session()
	hud.set_practice_mode(false)
	_activate_competitive_map(_selected_map_id)
	if not arena_started:
		_start_arena_for_peer(local_peer_id)
	else:
		_force_first_person_camera()
		_respawn_player(false)
	if local_peer_id != 1:
		_ensure_remote_player(1)


## Host-side match format. Clients receive it with the match setup, so the
## host is the only place it is ever chosen.
func set_match_format(score_to_win: int, round_seconds: float) -> void:
	if network_session.is_online() and not multiplayer.is_server():
		return
	_apply_match_format(score_to_win, round_seconds)


func _apply_match_format(score_to_win: int, round_seconds: float) -> void:
	_score_to_win = clampi(score_to_win, MIN_SCORE_TO_WIN, MAX_SCORE_TO_WIN)
	match_duration = clampf(round_seconds, MIN_ROUND_SECONDS, MAX_ROUND_SECONDS)
	if not _match_timer_running:
		_match_time_remaining = match_duration
	hud.set_match_format(_score_to_win, match_duration)


func get_match_format() -> Dictionary:
	return {"score_to_win": _score_to_win, "round_seconds": match_duration}


func _start_arena_for_peer(peer_id: int) -> void:
	arena_started = true
	_match_time_remaining = match_duration
	_match_timer_running = false
	var spawn_slot := _spawn_slot_for_peer(peer_id)
	_apply_local_team_identity()
	camera_yaw = spawn_manager.get_spawn_yaw_for_slot(spawn_slot)
	camera_pitch = 0.0
	_set_menu_world_parked(false)
	player.respawn(spawn_manager.get_spawn_for_slot(spawn_slot))
	_force_first_person_camera()
	player.set_shooting_enabled(_practice_mode)
	hud.set_lobby_mode(false)
	hud.set_practice_mode(_practice_mode)
	hud.set_duel_mode(false)
	hud.set_round_number(_round_number)
	hud.set_duel_score(_red_score, _blue_score)
	hud.set_match_time(_match_time_remaining)
	_set_match_clock_visible(false)
	var announcement_text := "PRACTICE" if _practice_mode else "WAITING FOR OPPONENT"
	hud.show_announcement(announcement_text, Color(0.3, 0.9, 1.0))
	audio_manager.set_music_context(&"practice" if _practice_mode else &"match", 0.7)
	audio_manager.play_sfx(&"round_start", -2.0)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if not _practice_mode:
		_enter_waiting_for_opponent()


func _respawn_player(_lose_life: bool = false) -> void:
	var spawn_slot := _spawn_slot_for_peer(local_peer_id)
	var spawn_position: Vector3 = _assigned_spawn_for_local_player() if arena_started else MENU_PARK_POSITION
	if arena_started:
		camera_yaw = spawn_manager.get_spawn_yaw_for_slot(spawn_slot)
		camera_pitch = 0.0
	player.respawn(spawn_position)


func _assigned_spawn_for_local_player() -> Vector3:
	return spawn_manager.get_spawn_for_slot(_spawn_slot_for_peer(local_peer_id))


func _force_first_person_camera() -> void:
	third_person_enabled = false
	_apply_camera_mode()


func _set_match_clock_visible(visible: bool) -> void:
	var timer := hud.get_node_or_null("TimerLabel") as CanvasItem
	if timer != null:
		timer.visible = visible


func _update_fling_cooldown_hud() -> void:
	hud.set_fling_cooldown(player.get_fling_cooldown_remaining(), player.get_fling_cooldown_duration())


func _enter_waiting_for_opponent() -> void:
	if _practice_mode or not arena_started:
		return
	_round_countdown_generation += 1
	_round_countdown_active = false
	_waiting_for_opponent = true
	_round_resolving = false
	_local_death_reported = false
	_pending_deaths.clear()
	_match_timer_running = false
	player.freeze = false
	player.sleeping = false
	player.set_input_enabled(true)
	player.set_shooting_enabled(false)
	hud.set_duel_mode(false)
	_set_match_clock_visible(false)
	hud.show_announcement("WAITING FOR OPPONENT", Color(0.72, 0.8, 0.9))


func _begin_synchronized_round_countdown() -> void:
	if not multiplayer.is_server() or not arena_started or _practice_mode or _match_over:
		return
	if not _duel_has_opponent() or _round_countdown_active:
		return
	_round_countdown_generation += 1
	var generation := _round_countdown_generation
	_receive_round_countdown.rpc(_round_number, _red_score, _blue_score, generation)
	_run_round_countdown(_round_number, _red_score, _blue_score, generation)


@rpc("authority", "call_remote", "reliable")
func _receive_round_countdown(round_number: int, red_score: int, blue_score: int, generation: int) -> void:
	_run_round_countdown(round_number, red_score, blue_score, generation)


func _run_round_countdown(round_number: int, red_score: int, blue_score: int, generation: int) -> void:
	if generation < _round_countdown_generation or not arena_started:
		return
	_round_countdown_generation = generation
	_round_number = maxi(1, round_number)
	_red_score = clampi(red_score, 0, _score_to_win)
	_blue_score = clampi(blue_score, 0, _score_to_win)
	_waiting_for_opponent = false
	_round_countdown_active = true
	_round_resolving = true
	_local_death_reported = false
	_pending_deaths.clear()
	_match_time_remaining = match_duration
	_match_timer_running = false
	_clear_projectiles()
	_restore_round_losers()
	hud.reset_round_result()
	_force_first_person_camera()
	_position_all_players_at_assigned_spawns()
	# Every round starts with cooldowns cleared, for the local blob and (on
	# the host) for every duelist's authoritative state.
	_reset_ability_state()
	if multiplayer.is_server():
		_server_peers.reset_for_round()
	player.set_input_enabled(false)
	player.set_shooting_enabled(false)
	player.freeze = true
	hud.set_duel_mode(true)
	hud.set_round_number(_round_number)
	hud.set_duel_score(_red_score, _blue_score)
	hud.set_match_time(_match_time_remaining)
	_set_match_clock_visible(true)
	for count in range(3, 0, -1):
		if generation != _round_countdown_generation or not arena_started:
			return
		hud.show_countdown_beat(str(count))
		audio_manager.play_sfx(&"round_start", -6.0, 0.92 + float(3 - count) * 0.04)
		await get_tree().create_timer(1.0).timeout
	if generation != _round_countdown_generation or not arena_started:
		return
	_round_countdown_active = false
	_round_resolving = false
	player.freeze = false
	player.sleeping = false
	player.set_input_enabled(true)
	player.set_shooting_enabled(true)
	_match_timer_running = true
	if _bot != null:
		_bot.set_round_active(true)
	hud.show_countdown_beat("GO!")


func _position_all_players_at_assigned_spawns() -> void:
	_respawn_player(false)
	for peer_key in _peer_spawn_slots:
		var peer_id := int(peer_key)
		var spawn_position: Vector3 = spawn_manager.get_spawn_for_slot(_spawn_slot_for_peer(peer_id))
		if multiplayer.is_server():
			_server_peers.state_for(peer_id).note_position(spawn_position, Time.get_ticks_msec())
		if peer_id == local_peer_id:
			continue
		var remote := _ensure_remote_player(peer_id) as RigidBody3D
		remote.freeze = true
		remote.global_position = spawn_position
		remote.linear_velocity = Vector3.ZERO
		remote.angular_velocity = Vector3.ZERO
		remote.reset_physics_interpolation()
		if _is_bot_peer(peer_id):
			remote.apply_network_state(spawn_position, Vector3.ZERO, Vector3.ZERO, player.max_health, Vector3.FORWARD)
			_server_peers.state_for(peer_id).health = player.max_health


func _ensure_remote_player(peer_id: int):
	var existing = remote_players.get_node_or_null(_remote_player_name(peer_id))
	if existing != null:
		return existing

	var remote = PLAYER_SCENE.instantiate()
	remote.name = _remote_player_name(peer_id)
	remote_players.add_child(remote)
	remote.global_position = spawn_manager.get_spawn_for_slot(_spawn_slot_for_peer(peer_id))
	remote.configure_remote(peer_id, REMOTE_COLORS[abs(peer_id) % REMOTE_COLORS.size()])
	return remote


func _clear_remote_players() -> void:
	for child in remote_players.get_children():
		child.queue_free()


func _remote_player_name(peer_id: int) -> String:
	return "Peer_%d" % peer_id


## `host_time_msec` is the host clock the state was sampled at; remote blobs
## interpolate against it (RemoteSnapshotBuffer). -1 applies the transform
## immediately, which only the host's own hit pipeline relies on.
func _apply_remote_state(peer_id: int, network_position: Vector3, body_rotation: Vector3, velocity: Vector3, current_health: int, display_name: String, color: Color, facing_direction: Vector3, host_time_msec: int = -1) -> void:
	if peer_id == local_peer_id:
		return
	var remote = _ensure_remote_player(peer_id)
	if _victory_sequence_active:
		remote.apply_network_identity(display_name, color)
		return
	if _round_countdown_active:
		var spawn_position: Vector3 = spawn_manager.get_spawn_for_slot(_spawn_slot_for_peer(peer_id))
		remote.apply_network_state(spawn_position, body_rotation, Vector3.ZERO, current_health, facing_direction, host_time_msec)
	else:
		remote.apply_network_state(network_position, body_rotation, velocity, current_health, facing_direction, host_time_msec)
	remote.apply_network_identity(display_name, color)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _submit_player_state(network_position: Vector3, body_rotation: Vector3, _velocity: Vector3, _current_health: int, display_name: String, color: Color, facing_direction: Vector3) -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if not multiplayer.get_peers().has(peer_id):
		return
	var now := Time.get_ticks_msec()
	var state := _server_peers.state_for(peer_id)
	var previous_position: Vector3 = state.position_or(spawn_manager.get_spawn_for_slot(_spawn_slot_for_peer(peer_id)))
	var previous_msec := state.last_state_msec if state.has_reported_position else now
	var safe_position := _sanitize_remote_position(peer_id, network_position, now)
	var safe_rotation := body_rotation if body_rotation.is_finite() else Vector3.ZERO
	var safe_velocity := _derive_remote_velocity(previous_position, safe_position, previous_msec, now)
	var safe_health := state.health
	var safe_name := display_name.strip_edges().left(24)
	if safe_name.is_empty():
		safe_name = "Player %d" % peer_id
	var safe_color := _sanitize_player_color(color)
	var safe_facing := facing_direction.normalized() if facing_direction.is_finite() and facing_direction.length_squared() > 0.001 else Vector3.FORWARD
	_apply_remote_state(peer_id, safe_position, safe_rotation, safe_velocity, safe_health, safe_name, safe_color, safe_facing, now)
	_broadcast_player_state.rpc(peer_id, safe_position, safe_rotation, safe_velocity, safe_health, safe_name, safe_color, safe_facing, now)
	if not _practice_mode and not _waiting_for_opponent and not _round_resolving and spawn_manager.is_outside_arena(safe_position):
		_register_round_death(peer_id, "fall")


func _sanitize_remote_position(peer_id: int, claimed_position: Vector3, now_msec: int) -> Vector3:
	var state := _server_peers.state_for(peer_id)
	var fallback: Vector3 = state.position_or(spawn_manager.get_spawn_for_slot(_spawn_slot_for_peer(peer_id)))
	if not claimed_position.is_finite():
		return fallback
	var last_msec := state.last_state_msec if state.has_reported_position else now_msec
	if now_msec - last_msec < MIN_REMOTE_STATE_INTERVAL_MSEC:
		return fallback
	var elapsed := clampf(float(now_msec - last_msec) / 1000.0, 0.0, 0.5)
	var maximum_step := minf(MAX_REMOTE_STATE_STEP, MAX_REMOTE_STATE_SPEED * elapsed + REMOTE_STATE_LEEWAY)
	var delta := claimed_position - fallback
	var safe_position := fallback + delta.limit_length(maximum_step)
	state.note_position(safe_position, now_msec)
	return safe_position


func _derive_remote_velocity(previous_position: Vector3, accepted_position: Vector3, previous_msec: int, now_msec: int) -> Vector3:
	var elapsed_msec := now_msec - previous_msec
	if elapsed_msec < MIN_REMOTE_STATE_INTERVAL_MSEC:
		return Vector3.ZERO
	var elapsed := clampf(float(elapsed_msec) / 1000.0, 0.001, 0.5)
	return ((accepted_position - previous_position) / elapsed).limit_length(MAX_REMOTE_STATE_SPEED)


func _sanitize_player_color(color: Color) -> Color:
	var red := clampf(color.r, 0.08, 1.0) if is_finite(color.r) else 0.3
	var green := clampf(color.g, 0.08, 1.0) if is_finite(color.g) else 0.7
	var blue := clampf(color.b, 0.08, 1.0) if is_finite(color.b) else 1.0
	return Color(red, green, blue, 1.0)


## Host -> clients. `host_time_msec` is the host's Time.get_ticks_msec() when
## the state was sampled; clients map it onto their own clock through the
## ping-derived offset in NetworkSession.
@rpc("authority", "call_remote", "unreliable_ordered")
func _broadcast_player_state(peer_id: int, network_position: Vector3, body_rotation: Vector3, velocity: Vector3, current_health: int, display_name: String, color: Color, facing_direction: Vector3, host_time_msec: int) -> void:
	_apply_remote_state(peer_id, network_position, body_rotation, velocity, current_health, display_name, color, facing_direction, host_time_msec)


func _on_network_collision_requested(target_peer_id: int, impulse: Vector3, damage: int) -> void:
	if not network_session.is_online() or target_peer_id <= 0 or _waiting_for_opponent or _round_countdown_active:
		return
	var safe_impulse := impulse.limit_length(230.0)
	var safe_damage := clampi(damage, 0, 60)
	if multiplayer.is_server() and multiplayer.get_peers().has(target_peer_id):
		_apply_server_peer_impact(target_peer_id, safe_damage, safe_impulse, false)


func _on_local_hotbar_slot_changed(slot: int) -> void:
	if arena_started:
		audio_manager.play_sfx(&"equip_swap", -9.0, 1.0 if slot == 0 else 0.86)
	if network_session.is_online() and not multiplayer.is_server() and multiplayer.multiplayer_peer != null:
		_report_hotbar_slot.rpc_id(1, slot)


## A client tells the host which hotbar slot it holds. The host only stores
## a clamped copy: it gates that peer's shot requests and its Blob ram bonus.
@rpc("any_peer", "call_remote", "reliable")
func _report_hotbar_slot(slot: int) -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if not multiplayer.get_peers().has(peer_id):
		return
	var safe_slot := clampi(slot, 0, COMBAT_TUNING.SLOT_COUNT - 1)
	_server_peers.state_for(peer_id).hotbar_slot = safe_slot
	var remote := remote_players.get_node_or_null(_remote_player_name(peer_id))
	if remote != null and remote.has_method("set_hotbar_slot"):
		remote.call("set_hotbar_slot", safe_slot)


@rpc("authority", "call_remote", "reliable")
func _receive_network_collision(impulse: Vector3, damage: int) -> void:
	if _waiting_for_opponent or _round_countdown_active:
		return
	player.receive_collision_impact(clampi(damage, 0, 60), impulse.limit_length(230.0))


func _handle_local_shot(origin: Vector3, direction: Vector3) -> void:
	if not arena_started or _waiting_for_opponent or _round_countdown_active or _round_resolving or _match_over or not player.input_enabled:
		return
	var safe_direction := direction.normalized()
	if safe_direction.length_squared() <= 0.001:
		return
	if _practice_mode:
		practice_session.note_shot_fired()
	audio_manager.play_sfx(&"blaster_fire", -4.0, 0.95 + randf() * 0.1)
	_add_camera_shake(0.12)
	_spawn_impact_burst(origin - safe_direction * 0.35, Color(1.0, 0.68, 0.18), 0.26)
	var now := Time.get_ticks_msec()
	if _abilities.locks_shooting(now):
		return
	var ricochet := _abilities.consume_ricochet(now)
	if not network_session.is_online():
		_spawn_projectile(local_peer_id, origin, safe_direction, true, ricochet)
	elif multiplayer.is_server():
		_server_spawn_shot(local_peer_id, origin, safe_direction, ricochet)
	else:
		_request_network_shot.rpc_id(1, origin, safe_direction, ricochet)


@rpc("any_peer", "call_remote", "reliable")
func _request_network_shot(origin: Vector3, direction: Vector3, _requested_ricochet: bool = false, _requested_rail: bool = false) -> void:
	if not multiplayer.is_server() or not arena_started or _waiting_for_opponent or _round_countdown_active or _round_resolving or _match_over:
		return
	var shooter_peer_id := multiplayer.get_remote_sender_id()
	var shooter = remote_players.get_node_or_null(_remote_player_name(shooter_peer_id))
	if shooter == null or not origin.is_finite() or not direction.is_finite() or direction.length_squared() <= 0.001:
		return
	if origin.distance_to(shooter.global_position) > 8.0:
		return
	var now := Time.get_ticks_msec()
	var state := _server_peers.state_for(shooter_peer_id)
	if state.hotbar_slot == COMBAT_TUNING.SLOT_BLOB:
		return
	if state.rail_charge_end_at > now:
		return
	if now < state.shot_ready_at:
		return
	var shot_interval := NETWORK_SHOT_COOLDOWN_MSEC
	if now < state.overcharge_end_at:
		shot_interval = int(round(float(NETWORK_SHOT_COOLDOWN_MSEC) / ABILITY_TUNING.OVERCHARGE_FIRE_RATE_MULTIPLIER))
	state.shot_ready_at = now + shot_interval
	var safe_direction := direction.normalized()
	var authoritative_origin: Vector3 = shooter.global_position + safe_direction * 3.75 + Vector3.UP * 0.25
	var shot_flags := _consume_server_shot_flags(shooter_peer_id, now)
	_server_spawn_shot(shooter_peer_id, authoritative_origin, safe_direction, bool(shot_flags.get("ricochet", false)), bool(shot_flags.get("rail", false)))


@rpc("any_peer", "call_remote", "reliable")
func _request_network_ability(ability_id: String) -> void:
	if not multiplayer.is_server() or not arena_started or _waiting_for_opponent or _round_countdown_active or _round_resolving or _match_over:
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if not multiplayer.get_peers().has(peer_id):
		return
	var now := Time.get_ticks_msec()
	var state := _server_peers.state_for(peer_id)
	_abilities.server_request(self, peer_id, ability_id, state, now)


## Host-side gate: the peer's locked loadout ability, off cooldown, and not
## already armed or charging. The rules live on each ability class.
func _is_server_ability_request_allowed(peer_id: int, ability_id: String, now: int) -> bool:
	var ability := _abilities.server_ability(ability_id)
	return ability != null and ability.host_validated and ability.server_allowed(_server_peers.state_for(peer_id), now)


func _consume_server_shot_flags(peer_id: int, now: int) -> Dictionary:
	var flags := {"ricochet": false, "rail": false}
	var state := _server_peers.state_for(peer_id)
	if state.rail_charge_end_at > 0 and now >= state.rail_charge_end_at:
		flags["rail"] = true
		state.rail_charge_end_at = 0
		state.ability_ready_at = now + ABILITY_TUNING.RAIL_SHOT_COOLDOWN_MSEC
		return flags
	if state.ricochet_loaded:
		flags["ricochet"] = true
		state.ricochet_loaded = false
		state.ability_ready_at = now + ABILITY_TUNING.RICOCHET_COOLDOWN_MSEC
	return flags


func _server_spawn_shot(shooter_peer_id: int, origin: Vector3, direction: Vector3, ricochet: bool = false, rail: bool = false) -> void:
	var projectile_id := "Shot_%d_%d" % [shooter_peer_id, Time.get_ticks_usec()]
	_spawn_projectile(shooter_peer_id, origin, direction, true, ricochet, rail, projectile_id)
	_replicate_shot.rpc(shooter_peer_id, origin, direction, ricochet, rail, projectile_id)


@rpc("authority", "call_remote", "reliable")
func _replicate_shot(shooter_peer_id: int, origin: Vector3, direction: Vector3, ricochet: bool = false, rail: bool = false, projectile_id: String = "") -> void:
	_spawn_projectile(shooter_peer_id, origin, direction, false, ricochet, rail, projectile_id)


func _spawn_projectile(shooter_peer_id: int, origin: Vector3, direction: Vector3, authoritative: bool, ricochet: bool = false, rail: bool = false, projectile_id: String = "") -> void:
	var projectile = PROJECTILE_SCENE.instantiate()
	projectile.name = projectile_id if not projectile_id.is_empty() else "Shot_%d_%d" % [shooter_peer_id, Time.get_ticks_usec()]
	projectiles.add_child(projectile)
	var source = player if shooter_peer_id == local_peer_id else remote_players.get_node_or_null(_remote_player_name(shooter_peer_id))
	projectile.configure(origin, direction.normalized(), source, false, ricochet, rail)
	projectile.ricocheted.connect(_on_projectile_ricochet.bind(shooter_peer_id))
	projectile.phase_absorbed.connect(_on_projectile_phase_absorbed)
	if authoritative:
		projectile.hit_confirmed.connect(_on_authoritative_projectile_hit.bind(shooter_peer_id, projectile))
	else:
		projectile.hit_confirmed.connect(_on_visual_projectile_hit)
	if shooter_peer_id != local_peer_id:
		audio_manager.play_sfx_at(&"blaster_fire", origin, -2.0, 0.84 + randf() * 0.08, 0.05, &"remote_projectile_fire")


func _on_visual_projectile_hit(target: Node3D, world_position: Vector3, _damage_target: bool, impact_direction: Vector3, _damage: int, knockback: float) -> void:
	_spawn_impact_burst(world_position, Color(1.0, 0.42, 0.08), 0.58)
	# Locally simulated blobs flex through their own impact path; a remote
	# blob's physics lives on its owner, so show the dent here.
	if target != null and target.is_in_group("network_blob") and not bool(target.get("local_controlled")) and target.has_method("play_hit_flex"):
		target.call("play_hit_flex", impact_direction, knockback)
	audio_manager.play_sfx(&"projectile_impact", -6.0, 0.94 + randf() * 0.1)


func _on_projectile_ricochet(world_position: Vector3, _surface_normal: Vector3, shooter_peer_id: int) -> void:
	_spawn_impact_burst(world_position, Color(0.22, 0.72, 1.0), 0.38)
	audio_manager.play_sfx_limited(&"wall_impact", 0.06, -10.0, 1.18, &"ricochet_ping")
	if shooter_peer_id == local_peer_id:
		_add_camera_shake(0.055)


func _on_projectile_phase_absorbed(world_position: Vector3) -> void:
	_spawn_impact_burst(world_position, Color(0.2, 0.8, 1.0), 0.32)
	audio_manager.play_sfx_limited(&"projectile_impact", 0.06, -12.0, 1.34, &"phase_absorb")


func _on_authoritative_projectile_hit(target: Node3D, world_position: Vector3, damage_target: bool, impact_direction: Vector3, damage: int, knockback: float, shooter_peer_id: int, projectile: Node) -> void:
	_on_visual_projectile_hit(target, world_position, damage_target, impact_direction, damage, knockback)
	if _practice_mode and shooter_peer_id == local_peer_id:
		# Anything that is not a training dummy - wall, canopy, cover block -
		# is a miss, and a miss breaks the streak.
		if target != null and target.is_in_group("training_dummy"):
			practice_session.note_dummy_hit(damage)
		else:
			practice_session.note_shot_missed()
	if not damage_target or target == null:
		return
	# Classify the hit for feedback and the kill feed before the death can
	# register below. A rail projectile is the only one flying at RAIL_SHOT_SPEED.
	var ricochet_hit := projectile != null and projectile.has_method("is_ricochet_shot") and bool(projectile.call("is_ricochet_shot"))
	var hit_kind := "shot"
	if ricochet_hit:
		hit_kind = "ricochet"
	elif projectile != null and float(projectile.get("speed")) >= ABILITY_TUNING.RAIL_SHOT_SPEED - 0.5:
		hit_kind = "rail"
	if target.is_in_group("network_blob"):
		_stat_last_hit[int(target.get("network_peer_id"))] = {"shooter": shooter_peer_id, "kind": hit_kind, "time": Time.get_ticks_msec()}
	var impulse_direction := (impact_direction.normalized() + Vector3.UP * 0.18).normalized()
	var impulse := impulse_direction * knockback
	if target.is_in_group("network_blob"):
		var target_peer_id := int(target.get("network_peer_id"))
		if target_peer_id == local_peer_id:
			player.receive_collision_impact(damage, impulse, true)
		elif multiplayer.is_server() and _is_duel_participant(target_peer_id):
			_apply_server_peer_impact(target_peer_id, damage, impulse, true)
	else:
		target.call("take_damage", damage, impact_direction, knockback)
	_record_peer_damage(shooter_peer_id, damage, ricochet_hit)
	if shooter_peer_id == local_peer_id:
		hud.show_hit_marker("hit" if hit_kind == "shot" else hit_kind)
		hud.show_damage_number(damage, world_position, "hit" if hit_kind == "shot" else hit_kind, str(target.get_instance_id()))
	elif multiplayer.is_server() and multiplayer.get_peers().has(shooter_peer_id):
		_confirm_shot_hit.rpc_id(shooter_peer_id)


@rpc("authority", "call_remote", "reliable")
func _receive_projectile_hit(damage: int, impulse: Vector3) -> void:
	player.receive_collision_impact(clampi(damage, 0, 60), impulse.limit_length(150.0), true)


func _apply_server_peer_impact(peer_id: int, damage: int, impulse: Vector3, projectile_hit: bool) -> void:
	if not multiplayer.is_server() or _waiting_for_opponent or _round_countdown_active or not _is_duel_participant(peer_id):
		return
	var safe_damage := clampi(damage, 0, 60)
	var impulse_limit := 150.0 if projectile_hit else 230.0
	var safe_impulse := impulse.limit_length(impulse_limit)
	var state := _server_peers.state_for(peer_id)
	var current_health := state.health
	var next_health := maxi(current_health - safe_damage, 0)
	state.health = next_health
	var remote = remote_players.get_node_or_null(_remote_player_name(peer_id))
	if remote != null:
		remote.apply_network_state(remote.global_position, remote.rotation, remote.linear_velocity, next_health, remote.aim_direction)
	if _is_bot_peer(peer_id):
		# The bot body simulates locally, so the hit lands on it directly;
		# the health it shows was already set from the authoritative state.
		if remote != null:
			remote.receive_collision_impact(0, safe_impulse, projectile_hit)
	elif projectile_hit:
		_receive_projectile_hit.rpc_id(peer_id, safe_damage, safe_impulse)
	else:
		_receive_network_collision.rpc_id(peer_id, safe_impulse, safe_damage)
		# Body slams have no projectile, so the feed cause is stamped here; the
		# other blob is the only thing that can request a collision on a peer.
		_stat_last_hit[peer_id] = {"shooter": local_peer_id, "kind": "collision", "time": Time.get_ticks_msec()}
	if next_health <= 0 and current_health > 0 and not _practice_mode:
		_register_round_death(peer_id, "health")


@rpc("authority", "call_remote", "reliable")
func _confirm_shot_hit() -> void:
	hud.show_hit_marker()


func _on_player_fling_released(charge_ratio: float) -> void:
	if _practice_mode:
		practice_session.note_combo_beat()
	_last_fling_charge_tier = 0
	_add_camera_shake(0.18 + charge_ratio * 0.44)
	_fling_fov_kick = maxf(_fling_fov_kick, charge_ratio * 8.0)
	_spawn_impact_burst(player.global_position, Color(0.08, 0.76, 1.0), 0.52 + charge_ratio * 0.42)
	audio_manager.finish_charge_audio(charge_ratio, true)


func _use_equipped_ability() -> void:
	if not arena_started or _waiting_for_opponent or _round_countdown_active or _round_resolving or _match_over or not player.input_enabled:
		return
	var progression := get_node_or_null("/root/Progression")
	if progression == null:
		return
	var ability_id := str(progression.call("get_equipped", "abilities"))
	if ability_id.is_empty():
		hud.show_announcement("EQUIP AN ABILITY IN THE SHOP", Color(0.96, 0.75, 0.3))
		return
	var now := Time.get_ticks_msec()
	var ability := _abilities.ensure(self, ability_id, now)
	if ability == null:
		return
	if ability.passive:
		audio_manager.play_sfx_limited(&"ui_close", 0.14, -14.0, 0.9, &"ability_passive")
		return
	# The practice panel's cooldown switch lets the player rehearse an ability
	# back to back instead of waiting out its duel timer.
	if _practice_mode and not practice_session.cooldowns_enabled:
		ability.ready_at = 0
	if now < ability.ready_at or ability.is_loaded() or ability.is_active(now):
		audio_manager.play_sfx_limited(&"ui_close", 0.14, -14.0, 0.84, &"ability_denied")
		return
	if not ability.activate(self, now):
		audio_manager.play_sfx_limited(&"ui_close", 0.14, -14.0, 0.84, &"ability_denied")
		return
	# Bounce Mine and Shockwave send their own request from activate() because
	# they need the host to spawn or apply something; the timed abilities only
	# need the host to mirror their window.
	if ability.host_validated and DuelAbility.is_online_client(self) and not ability_id in ["bounce_mine", "shockwave"]:
		_request_network_ability.rpc_id(1, ability_id)
	audio_manager.play_ability_sfx(ability_id)
	progression.call("record_stat", "abilities", 1)


func _process_ability_state(delta: float) -> void:
	var progression := get_node_or_null("/root/Progression")
	if progression == null:
		return
	var now := Time.get_ticks_msec()
	if multiplayer.is_server():
		_expire_server_peer_abilities(now)
	var ability_id := str(progression.call("get_equipped", "abilities"))
	var ability := _abilities.ensure(self, ability_id, now) if not ability_id.is_empty() else null
	_abilities.process(self, now, delta)
	var active := false
	var active_remaining := 0
	var cooldown_remaining := 0
	var loaded := false
	var deployed := false
	if ability != null:
		active = ability.is_active(now) or (ability_id == "adrenaline" and bool(player.is_adrenaline_active()))
		active_remaining = ability.active_remaining(now)
		cooldown_remaining = ability.cooldown_remaining(now)
		loaded = ability.is_loaded()
		deployed = ability.is_deployed(self)
	hud.set_ability_state(ability_id, cooldown_remaining, loaded, active, active_remaining, deployed)


## Practice-contract entry point: runs the scanner regardless of loadout.
func _activate_target_scanner(now: int) -> void:
	var scanner := _abilities.ensure(self, "target_scanner", now)
	if scanner != null:
		scanner.activate(self, now)


## The local blob's pulse runs from its ability tick; this mirrors the host's
## view of every remote peer's window.
func _apply_remote_gravity_pulses(delta: float) -> void:
	if not multiplayer.is_server():
		return
	var now := Time.get_ticks_msec()
	for peer_id_value in _server_peers.peer_ids():
		if _server_peers.state_for(int(peer_id_value)).gravity_end_at <= now:
			continue
		var remote := remote_players.get_node_or_null(_remote_player_name(int(peer_id_value))) as Node3D
		if remote != null:
			_deflect_projectiles_around(remote, delta)


func _deflect_projectiles_around(owner: Node3D, delta: float) -> void:
	for projectile_value in projectiles.get_children():
		var projectile := projectile_value as Node3D
		if projectile != null and projectile.has_method("deflect_from") and projectile.get("source") != owner:
			if projectile.global_position.distance_to(owner.global_position) <= ABILITY_TUNING.GRAVITY_PULSE_RADIUS:
				projectile.call("deflect_from", owner.global_position, ABILITY_TUNING.GRAVITY_PULSE_CURVE_STRENGTH, delta)
				if multiplayer.is_server() and network_session.is_online():
					_replicate_projectile_deflection.rpc(projectile.name, projectile.global_position, projectile.get("velocity"))


@rpc("authority", "call_remote", "unreliable_ordered")
func _replicate_projectile_deflection(projectile_id: String, world_position: Vector3, velocity: Vector3) -> void:
	var projectile := projectiles.get_node_or_null(NodePath(projectile_id)) as Node3D
	if projectile == null or not world_position.is_finite() or not velocity.is_finite():
		return
	projectile.global_position = world_position
	projectile.set("velocity", velocity)
	if velocity.length_squared() > 0.001:
		projectile.look_at(world_position + velocity.normalized(), Vector3.UP)


@rpc("authority", "call_remote", "reliable")
func _replicate_phase_bubble(peer_id: int, active: bool) -> void:
	var target = player if peer_id == local_peer_id else remote_players.get_node_or_null(_remote_player_name(peer_id))
	if target != null and target.has_method("set_phase_bubble"):
		target.call("set_phase_bubble", active)


func _expire_server_peer_abilities(now: int) -> void:
	for peer_id_value in _server_peers.peer_ids():
		var peer_id := int(peer_id_value)
		var state := _server_peers.state_for(peer_id)
		# A phase bubble that has run out has to be replicated down, so it is
		# the only expiry here with a visible side effect. Zero means "expired
		# and already announced", which is why it is skipped.
		if state.phase_end_at > 0 and state.phase_end_at <= now:
			var remote := remote_players.get_node_or_null(_remote_player_name(peer_id))
			if remote != null:
				remote.call("set_phase_bubble", false)
			_replicate_phase_bubble.rpc(peer_id, false)
			state.phase_end_at = 0
		if state.overcharge_end_at <= now:
			state.overcharge_end_at = 0
		if state.gravity_end_at <= now:
			state.gravity_end_at = 0


func _show_rail_telegraph() -> void:
	_clear_rail_telegraph()
	var beam_mesh := BoxMesh.new()
	beam_mesh.size = Vector3(0.09, 0.09, 52.0)
	var beam_material := StandardMaterial3D.new()
	beam_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	beam_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_material.albedo_color = Color(0.82, 0.94, 1.0, 0.42)
	beam_material.emission_enabled = true
	beam_material.emission = Color(0.5, 0.86, 1.0)
	beam_material.emission_energy_multiplier = 2.4
	beam_mesh.material = beam_material
	_rail_telegraph = MeshInstance3D.new()
	_rail_telegraph.name = "RailTelegraph"
	_rail_telegraph.mesh = beam_mesh
	_rail_telegraph.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_rail_telegraph)
	_update_rail_telegraph()


func _update_rail_telegraph() -> void:
	if not is_instance_valid(_rail_telegraph):
		return
	var direction: Vector3 = player.aim_direction.normalized()
	if direction.length_squared() <= 0.001:
		direction = Vector3.FORWARD
	var origin: Vector3 = player.global_position + Vector3.UP * 0.25 + direction * 3.75
	_rail_telegraph.global_position = origin + direction * 26.0
	_rail_telegraph.look_at(_rail_telegraph.global_position + direction, Vector3.UP)
	var pulse := 0.72 + sin(float(Time.get_ticks_msec()) * 0.018) * 0.22
	_rail_telegraph.modulate = Color(1.0, 1.0, 1.0, pulse)


func _clear_rail_telegraph() -> void:
	if is_instance_valid(_rail_telegraph):
		_rail_telegraph.queue_free()
	_rail_telegraph = null


func _spawn_scan_wave() -> void:
	var wave := MeshInstance3D.new()
	wave.name = "TargetScannerWave"
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(0.12, 0.68, 1.0, 0.26)
	material.emission_enabled = true
	material.emission = Color(0.06, 0.42, 1.0)
	material.emission_energy_multiplier = 1.8
	sphere.material = material
	wave.mesh = sphere
	wave.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(wave)
	wave.global_position = player.global_position
	var radius: float = ABILITY_TUNING.SCANNER_RADIUS
	var tween := wave.create_tween().set_parallel(true)
	tween.tween_property(wave, "scale", Vector3.ONE * radius, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(wave, "transparency", 1.0, 0.42)
	tween.chain().tween_callback(wave.queue_free)


func _spawn_bounce_mine() -> void:
	if is_instance_valid(_active_bounce_mine):
		_active_bounce_mine.queue_free()
	var mine := BOUNCE_MINE_SCENE.instantiate()
	projectiles.add_child(mine)
	mine.configure(player.global_position + player.aim_direction.normalized() * 2.0 + Vector3.UP * 0.3, player.aim_direction, player)
	mine.detonated.connect(_on_bounce_mine_detonated)
	_active_bounce_mine = mine
	_spawn_impact_burst(player.global_position, Color(1.0, 0.35, 0.06), 0.52)


func _server_spawn_bounce_mine(peer_id: int) -> void:
	var owner := player as Node3D if peer_id == local_peer_id else remote_players.get_node_or_null(_remote_player_name(peer_id)) as Node3D
	if owner == null:
		return
	var state := _server_peers.state_for(peer_id)
	state.clear_bounce_mine()
	var direction: Vector3 = owner.get("aim_direction")
	if direction.length_squared() <= 0.001:
		direction = Vector3.FORWARD
	var mine := BOUNCE_MINE_SCENE.instantiate()
	projectiles.add_child(mine)
	var spawn_position := owner.global_position + direction.normalized() * 2.0 + Vector3.UP * 0.3
	mine.configure(spawn_position, direction, owner, true)
	mine.detonated.connect(_on_authoritative_bounce_mine_detonated.bind(peer_id, mine))
	state.bounce_mine = mine
	if peer_id == local_peer_id:
		_active_bounce_mine = mine
	_replicate_bounce_mine.rpc(peer_id, spawn_position, direction)


@rpc("authority", "call_remote", "reliable")
func _replicate_bounce_mine(peer_id: int, spawn_position: Vector3, direction: Vector3) -> void:
	var existing := _visual_bounce_mines.get(peer_id) as Node
	if is_instance_valid(existing):
		existing.queue_free()
	var source := player as Node3D if peer_id == local_peer_id else remote_players.get_node_or_null(_remote_player_name(peer_id)) as Node3D
	if source == null:
		return
	var mine := BOUNCE_MINE_SCENE.instantiate()
	projectiles.add_child(mine)
	mine.configure(spawn_position, direction, source, false)
	_visual_bounce_mines[peer_id] = mine
	if peer_id == local_peer_id:
		_active_bounce_mine = mine


func _on_authoritative_bounce_mine_detonated(world_position: Vector3, peer_id: int, mine: Node) -> void:
	var detonated_state := _server_peers.peek(peer_id)
	if detonated_state != null and detonated_state.bounce_mine == mine:
		detonated_state.bounce_mine = null
	if _active_bounce_mine == mine:
		_active_bounce_mine = null
	for candidate_value in [player] + remote_players.get_children():
		var target := candidate_value as Node3D
		if target == null or int(target.get("network_peer_id")) == peer_id:
			continue
		var offset: Vector3 = target.global_position - world_position
		var distance := offset.length()
		if distance > 4.5:
			continue
		var launch_direction := (offset.normalized() + Vector3.UP * 0.32).normalized()
		var impulse := launch_direction * ABILITY_TUNING.BOUNCE_MINE_LAUNCH_STRENGTH * (1.0 - distance / 6.0)
		if target == player:
			player.receive_collision_impact(0, impulse)
		elif target.is_in_group("network_blob"):
			_apply_server_peer_impact(int(target.get("network_peer_id")), 0, impulse, false)
	_spawn_impact_burst(world_position, Color(1.0, 0.36, 0.06), 1.35)
	audio_manager.play_sfx_at(&"explosion", world_position, 0.0, 1.0, 0.05, &"mine_detonation")
	_replicate_bounce_mine_detonation.rpc(peer_id, world_position)


@rpc("authority", "call_remote", "reliable")
func _replicate_bounce_mine_detonation(peer_id: int, world_position: Vector3) -> void:
	var mine := _visual_bounce_mines.get(peer_id) as Node
	if is_instance_valid(mine):
		mine.queue_free()
	if _active_bounce_mine == mine:
		_active_bounce_mine = null
	_visual_bounce_mines.erase(peer_id)
	_spawn_impact_burst(world_position, Color(1.0, 0.36, 0.06), 1.35)
	audio_manager.play_sfx_at(&"explosion", world_position, 0.0, 1.0, 0.05, &"mine_detonation")


func _on_bounce_mine_detonated(world_position: Vector3) -> void:
	if is_instance_valid(_active_bounce_mine):
		_active_bounce_mine = null
	for candidate_value in [player] + remote_players.get_children():
		var target := candidate_value as Node3D
		if target == null or target == player:
			continue
		var offset := target.global_position - world_position
		var distance := offset.length()
		if distance > 4.5:
			continue
		var direction := (offset.normalized() + Vector3.UP * 0.32).normalized()
		var impulse := direction * ABILITY_TUNING.BOUNCE_MINE_LAUNCH_STRENGTH * (1.0 - distance / 6.0)
		if target.is_in_group("network_blob"):
			var peer_id := int(target.get("network_peer_id"))
			if multiplayer.is_server() and _is_duel_participant(peer_id):
				_apply_server_peer_impact(peer_id, 0, impulse, false)
		elif target.has_method("apply_central_impulse"):
			target.call("apply_central_impulse", impulse)
	_spawn_impact_burst(world_position, Color(1.0, 0.36, 0.06), 1.35)
	audio_manager.play_sfx_at(&"explosion", world_position, 0.0, 1.0, 0.05, &"mine_detonation")


func _on_player_fling_charge_updated(charge_ratio: float) -> void:
	audio_manager.update_charge_audio(charge_ratio)
	var tier := clampi(int(floor(charge_ratio * 4.0 + 0.001)), 0, 4)
	if tier > _last_fling_charge_tier:
		_last_fling_charge_tier = tier
		_spawn_impact_burst(player.global_position - Vector3.UP * 0.7, Color(0.2, 0.8, 1.0).lerp(Color(1.0, 0.7, 0.16), charge_ratio), 0.18 + charge_ratio * 0.18)
		audio_manager.play_sfx_limited(&"fling_charge", 0.08, -16.0 + charge_ratio * 4.0, 0.86 + float(tier) * 0.08, &"fling_charge_tier")


func _on_player_fling_charge_started() -> void:
	_last_fling_charge_tier = 0
	_spawn_impact_burst(player.global_position - Vector3.UP * 0.8, Color(0.22, 0.78, 1.0), 0.28)
	audio_manager.play_sfx_limited(&"fling_charge", 0.14, -10.0, 0.94, &"fling_charge_start")


func _on_player_fling_maximum_reached() -> void:
	_fling_fov_kick = maxf(_fling_fov_kick, 3.5)
	_spawn_impact_burst(player.global_position, Color(0.85, 0.98, 1.0), 0.48)
	hud.show_announcement("MAX FLING", Color(0.82, 0.96, 1.0))


func _on_player_bounce_triggered(strength: float) -> void:
	# Same floor problem as the impact handler: a gentle roll-over-a-seam bounce
	# should not shake at all.
	if strength >= IMPACT_SHAKE_MIN_STRENGTH:
		_add_camera_shake(clampf(strength * 0.012, 0.0, 0.34))
	_spawn_impact_burst(player.global_position - Vector3.UP * 0.9, Color(0.2, 0.92, 0.78), clampf(strength * 0.025, 0.35, 0.85))
	# Jumps, air jumps and wall kicks have their own cue; wall kicks emit
	# after this signal, so the generic boing is decided at end of frame.
	call_deferred("_play_generic_bounce_audio", strength, Engine.get_process_frames())


func _play_generic_bounce_audio(strength: float, frame: int) -> void:
	if _movement_cue_frame == frame:
		return
	audio_manager.play_impact(&"bounce", clampf(strength / 42.0, 0.0, 1.0))


func _mark_movement_cue() -> void:
	_movement_cue_frame = Engine.get_process_frames()


func _on_player_jumped() -> void:
	_mark_movement_cue()
	audio_manager.play_sfx(&"jump", -6.0, 1.1 + randf() * 0.15)


func _on_player_air_jumped(_direction: Vector3) -> void:
	_mark_movement_cue()
	audio_manager.play_sfx(&"air_jump", -4.0, 0.96 + randf() * 0.08)


func _on_player_landed(fall_speed: float) -> void:
	var weight := clampf((fall_speed - 6.0) / 40.0, 0.0, 1.0)
	if fall_speed < 4.0:
		return
	audio_manager.play_sfx(&"land", lerpf(-16.0, -2.0, weight), lerpf(1.12, 0.78, weight))


func _on_player_wall_kicked(_wall_normal: Vector3) -> void:
	_mark_movement_cue()
	audio_manager.play_sfx(&"wall_kick", -4.0, 0.94 + randf() * 0.12)


func _on_player_slam_started() -> void:
	_mark_movement_cue()
	audio_manager.play_sfx(&"slam_dive", -5.0)


func _on_player_power_slide_changed(sliding: bool) -> void:
	if not sliding:
		return
	_mark_movement_cue()
	audio_manager.play_sfx(&"slide_start", -4.0, 0.95 + randf() * 0.1)


func _on_player_power_slide_hopped() -> void:
	_mark_movement_cue()
	audio_manager.play_sfx(&"slide_hop", -6.0, 0.95 + randf() * 0.1)


func _on_player_slam_landed(severity: float) -> void:
	audio_manager.play_sfx(&"slam_impact", -1.0, clampf(1.1 - severity * 0.004, 0.82, 1.05))


## The bot simulates locally, so its movement signals fire here; they play
## from its position so the rival's jumps and slams are heard, not just seen.
func _connect_opponent_movement_audio(body: Node) -> void:
	var blob := body as BlobPlayer
	if blob == null or blob.has_meta(&"movement_audio_wired"):
		return
	blob.set_meta(&"movement_audio_wired", true)
	blob.jumped.connect(_on_opponent_movement_cue.bind(blob, &"jump", -2.0))
	blob.air_jumped.connect(func(_direction: Vector3) -> void: _on_opponent_movement_cue(blob, &"air_jump", -1.0))
	blob.landed.connect(func(fall_speed: float) -> void: _on_opponent_movement_cue(blob, &"land", -4.0 if fall_speed >= 8.0 else SILENT_CUE_DB))
	blob.wall_kicked.connect(func(_normal: Vector3) -> void: _on_opponent_movement_cue(blob, &"wall_kick", -1.0))
	blob.slam_started.connect(_on_opponent_movement_cue.bind(blob, &"slam_dive", -2.0))
	blob.slam_landed.connect(func(_severity: float) -> void: _on_opponent_movement_cue(blob, &"slam_impact", 2.0))
	blob.power_slide_changed.connect(func(sliding: bool) -> void: _on_opponent_movement_cue(blob, &"slide_start", -2.0 if sliding else SILENT_CUE_DB))
	blob.power_slide_hopped.connect(_on_opponent_movement_cue.bind(blob, &"slide_hop", -5.0))


func _on_opponent_movement_cue(blob: Node3D, key: StringName, volume_db: float) -> void:
	if not is_instance_valid(blob) or not arena_started or volume_db <= SILENT_CUE_DB:
		return
	audio_manager.play_sfx_at(key, blob.global_position, volume_db, 0.9 + randf() * 0.12, 0.06, StringName("opponent_%s" % key))


func _on_player_bounce_counted(_strength: float) -> void:
	if _practice_mode:
		practice_session.note_combo_beat()
	var progression := get_node_or_null("/root/Progression")
	if arena_started and progression != null:
		progression.call("record_stat", "bounces", 1)


func _on_player_impact(world_position: Vector3, strength: float, severity: float) -> void:
	# BUG-030: the lower clamp bound was 0.1, so every impact shook the camera by
	# a fixed minimum no matter how gentle - including the stream of contacts
	# generated by simply rolling. Shake now keys off `severity` (how fast the
	# blob drives into the surface) and scales from zero, while the burst and
	# audio below stay on `strength` so rolling still looks and sounds the same.
	if severity >= IMPACT_SHAKE_MIN_STRENGTH:
		_add_camera_shake(clampf((severity - IMPACT_SHAKE_MIN_STRENGTH) * 0.025, 0.0, 0.62))
	_spawn_impact_burst(world_position, Color(1.0, 0.48, 0.16), clampf(strength * 0.025, 0.45, 1.0))
	audio_manager.play_impact(&"hard" if strength >= 15.0 else &"wall", clampf(strength / 48.0, 0.0, 1.0))


func _on_player_damaged(amount: int) -> void:
	_add_camera_shake(0.58)
	hud.show_damage_feedback()
	_stat_round_damage_taken += maxi(0, amount)
	# In a duel the damage source is the rival, so the indicator points at the
	# rival blob; the hit's own impact direction is the fallback in practice.
	var source_direction := Vector3.ZERO
	for remote in remote_players.get_children():
		source_direction = (remote as Node3D).global_position - player.global_position
		break
	if source_direction.length_squared() <= 0.01:
		var last_hit := _stat_last_hit.get(local_peer_id, {}) as Dictionary
		if Time.get_ticks_msec() - int(last_hit.get("time", -STAT_HIT_MEMORY_MSEC)) <= STAT_HIT_MEMORY_MSEC:
			source_direction = -player.linear_velocity
	if source_direction.length_squared() > 0.01:
		hud.show_damage_direction(source_direction)
	audio_manager.play_sfx_limited(&"damage", 0.08, -6.0, 0.96 + randf() * 0.08)
	audio_manager.play_sfx(&"hurt", clampf(-8.0 + float(amount) * 0.2, -8.0, -1.0), 0.92 + randf() * 0.14)
	if player.health <= int(player.max_health * 0.25):
		audio_manager.start_loop(&"low_health", -18.0, 1.0, 0.15, &"player_low_health")
	else:
		audio_manager.stop_loop(&"player_low_health", 0.12)


func _on_player_respawned(world_position: Vector3) -> void:
	_spawn_impact_burst(world_position, Color(0.2, 0.82, 1.0), 1.35)
	if player.get_skin_rarity() == "Legendary":
		_spawn_impact_burst(world_position + Vector3.UP * 1.2, player.get_skin_accent_color(), 1.1)
	audio_manager.stop_loop(&"player_low_health", 0.12)
	audio_manager.play_sfx(&"respawn", -3.0)
	if arena_started and _practice_mode:
		hud.show_announcement("RESPAWNED", Color(0.42, 0.9, 1.0))


func _on_player_knocked_out(_peer_id: int) -> void:
	_abilities.interrupt(self, Time.get_ticks_msec())
	audio_manager.play_sfx(&"knockout", -2.0)
	_spawn_kill_effect(player.global_position, player.get_kill_effect_id())
	_request_local_death("health")


func _open_pause() -> void:
	_lobby_hud_suppressed_for_pause = not arena_started
	if _lobby_hud_suppressed_for_pause:
		hud.set_lobby_ui_suppressed(true)
	var ability_id: String = str(player.get_equipped_ability())
	pause_menu.set_host_room_code(_room_code_for_pause())
	pause_menu.set_context(
		arena_started and not _practice_mode,
		arena_started and _practice_mode,
		ability_id,
		ABILITY_HUD_SCRIPT.get_icon(ability_id)
	)
	pause_menu.open_pause()
	player.set_input_enabled(false)
	audio_manager.cancel_charge_audio()
	if not network_session.is_online():
		get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _room_code_for_pause() -> String:
	if not network_session.is_online() or not multiplayer.is_server():
		return ""
	return str(network_session.call("get_share_room_code"))


func _open_lobby_settings() -> void:
	if hud.is_progression_open():
		hud.close_progression()
	_open_pause()
	pause_menu.show_settings()


func _resume_from_pause() -> void:
	get_tree().paused = false
	pause_menu.close_pause()
	if _lobby_hud_suppressed_for_pause:
		hud.set_lobby_ui_suppressed(false)
	_lobby_hud_suppressed_for_pause = false
	player.set_input_enabled(not _round_resolving and not _match_over)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED if arena_started and not _victory_sequence_active else Input.MOUSE_MODE_VISIBLE)


func _on_pause_respawn_requested() -> void:
	_resume_from_pause()
	if not arena_started:
		return
	if _practice_mode:
		_respawn_player(false)
	elif _waiting_for_opponent:
		_respawn_player(false)
	elif not _round_countdown_active and not _round_resolving and not _match_over:
		_respawn_player(false)
		_request_local_death("menu_respawn")


func _request_local_death(reason: String) -> void:
	if not arena_started or _practice_mode or _round_resolving or _match_over or _local_death_reported:
		return
	if not _duel_has_opponent():
		_respawn_player(false)
		hud.show_announcement("WAITING FOR OPPONENT", Color(0.72, 0.8, 0.9))
		return
	_local_death_reported = true
	player.set_input_enabled(false)
	player.freeze = true
	if multiplayer.is_server():
		_register_round_death(local_peer_id, reason)
	else:
		_report_round_death.rpc_id(1, reason)


@rpc("any_peer", "call_remote", "reliable")
func _report_round_death(reason: String) -> void:
	if not multiplayer.is_server() or _round_resolving or _match_over:
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if not multiplayer.get_peers().has(peer_id):
		return
	var safe_reason := reason.left(24)
	var remote = remote_players.get_node_or_null(_remote_player_name(peer_id))
	var verified := safe_reason == "menu_respawn"
	verified = verified or (safe_reason == "health" and _server_peers.state_for(peer_id).health <= 0)
	verified = verified or (safe_reason == "fall" and remote != null and spawn_manager.is_outside_arena(remote.global_position))
	if verified:
		_register_round_death(peer_id, safe_reason)


func _register_round_death(peer_id: int, reason: String) -> void:
	if _round_resolving or _match_over or _pending_deaths.has(peer_id):
		return
	if peer_id != 1 and not _is_duel_participant(peer_id):
		return
	var recorded_at := Time.get_ticks_msec()
	# Stamp the cause on the replicated stats so both peers can build the kill
	# feed entry and skill-quest stats from the round result alone.
	_ensure_player_stats(peer_id)
	var death_stats := _player_stats[peer_id] as Dictionary
	var last_hit := _stat_last_hit.get(peer_id, {}) as Dictionary
	var hit_is_recent := not last_hit.is_empty() and recorded_at - int(last_hit.get("time", 0)) <= STAT_HIT_MEMORY_MSEC
	var cause := reason
	if reason == "health" and hit_is_recent:
		cause = "health:%s" % str(last_hit.get("kind", "shot"))
	elif reason == "fall" and hit_is_recent:
		cause = "fall:knockout"
	death_stats["last_death_cause"] = cause
	death_stats["last_death_by"] = int(last_hit.get("shooter", -1)) if hit_is_recent else -1
	_player_stats[peer_id] = death_stats
	_pending_deaths[peer_id] = {"time": recorded_at, "reason": reason}
	if _pending_deaths.size() == 1:
		_death_resolution_deadline = recorded_at + DEATH_RESOLUTION_MSEC
		return

	var first_peer_id := -1
	var first_time := 9223372036854775807
	var last_time := 0
	for pending_peer_id in _pending_deaths:
		var death_time := int((_pending_deaths[pending_peer_id] as Dictionary).get("time", recorded_at))
		if death_time < first_time:
			first_time = death_time
			first_peer_id = int(pending_peer_id)
		last_time = maxi(last_time, death_time)
	if last_time - first_time <= DRAW_WINDOW_MSEC:
		_resolve_duel_round(-1, true)
	else:
		_resolve_duel_round(first_peer_id, false)


func _process_pending_round_death() -> void:
	if not multiplayer.is_server() or _round_resolving or _pending_deaths.is_empty():
		return
	if Time.get_ticks_msec() < _death_resolution_deadline:
		return
	var first_peer_id := -1
	var first_time := 9223372036854775807
	for pending_peer_id in _pending_deaths:
		var death_time := int((_pending_deaths[pending_peer_id] as Dictionary).get("time", first_time))
		if death_time < first_time:
			first_time = death_time
			first_peer_id = int(pending_peer_id)
	_resolve_duel_round(first_peer_id, false)


func _resolve_duel_round(loser_peer_id: int, is_draw: bool) -> void:
	if _round_resolving or _match_over:
		return
	_round_resolving = true
	var dead_peer_ids: Array = _pending_deaths.keys()
	_pending_deaths.clear()
	var winning_team := -1
	if is_draw:
		for dead_peer_value in dead_peer_ids:
			var dead_peer_id := int(dead_peer_value)
			_ensure_player_stats(dead_peer_id)
			var draw_stats := _player_stats[dead_peer_id] as Dictionary
			draw_stats["deaths"] = int(draw_stats.get("deaths", 0)) + 1
			_player_stats[dead_peer_id] = draw_stats
	else:
		winning_team = TEAM_BLUE if _team_for_peer(loser_peer_id) == TEAM_RED else TEAM_RED
		_ensure_player_stats(loser_peer_id)
		var loser_stats := _player_stats[loser_peer_id] as Dictionary
		loser_stats["deaths"] = int(loser_stats.get("deaths", 0)) + 1
		_player_stats[loser_peer_id] = loser_stats
		var winner_peer_id := _peer_for_team(winning_team)
		if winner_peer_id > 0:
			_ensure_player_stats(winner_peer_id)
			var winner_stats := _player_stats[winner_peer_id] as Dictionary
			winner_stats["eliminations"] = int(winner_stats.get("eliminations", 0)) + 1
			_player_stats[winner_peer_id] = winner_stats
		if winning_team == TEAM_RED:
			_red_score += 1
		else:
			_blue_score += 1
	_match_over = _red_score >= _score_to_win or _blue_score >= _score_to_win
	_apply_round_result(_red_score, _blue_score, winning_team, is_draw, _match_over)
	_receive_round_result.rpc(_red_score, _blue_score, winning_team, is_draw, _match_over, _player_stats)
	await get_tree().create_timer(2.0).timeout
	if _match_over or not arena_started:
		return
	_round_number += 1
	for peer_key in _peer_spawn_slots:
		_server_peers.state_for(int(peer_key)).health = player.max_health
	_begin_synchronized_round_countdown()


@rpc("authority", "call_remote", "reliable")
func _receive_round_result(red_score: int, blue_score: int, winning_team: int, is_draw: bool, match_over: bool, player_stats: Dictionary) -> void:
	_player_stats = player_stats.duplicate(true)
	_apply_round_result(red_score, blue_score, winning_team, is_draw, match_over)


func _apply_round_result(red_score: int, blue_score: int, winning_team: int, is_draw: bool, match_over: bool) -> void:
	_red_score = clampi(red_score, 0, _score_to_win)
	_blue_score = clampi(blue_score, 0, _score_to_win)
	_round_resolving = true
	_match_over = match_over
	_local_death_reported = true
	_match_timer_running = false
	_clear_projectiles()
	player.set_input_enabled(false)
	player.set_shooting_enabled(false)
	player.freeze = true
	if _bot != null:
		_bot.set_round_active(false)
	hud.set_duel_score(_red_score, _blue_score, winning_team)
	hud.set_round_number(_round_number)
	# The round result takes over the match-timer box: it grows, the scores
	# slide aside, and it turns green (won) or red (lost). The losing blob pops
	# out of the arena until the next countdown.
	if is_draw:
		hud.show_round_result(DuelHud.ROUND_RESULT_DRAW)
	else:
		var local_won := winning_team == _team_for_peer(local_peer_id)
		hud.show_round_result(DuelHud.ROUND_RESULT_WON if local_won else DuelHud.ROUND_RESULT_LOST)
		_hide_round_loser(TEAM_BLUE if winning_team == TEAM_RED else TEAM_RED)
	audio_manager.play_sfx(&"round_end", -2.0)
	_feed_and_record_round(winning_team, is_draw)
	if match_over and winning_team >= 0:
		call_deferred("_start_victory_sequence", winning_team)


## Pops the losing blob out of view (a burst in its colour, then hidden)
## until the next round's countdown puts everyone back.
func _hide_round_loser(losing_team: int) -> void:
	var loser := _body_for_team(losing_team)
	if loser == null or not is_instance_valid(loser):
		return
	var loser_color: Color = loser.get("blob_color") if loser.get("blob_color") is Color else Color.WHITE
	_spawn_impact_burst(loser.global_position, loser_color, 1.4)
	for part_name in ["VisualRoot", "FaceRoot", "Nameplate", "SpeedTrail"]:
		var part := loser.get_node_or_null(part_name) as Node3D
		if part == null:
			continue
		# Remember what was showing, so restoring never un-hides the local
		# blob's own body in first person.
		_hidden_round_losers.append({"part": part, "visible": part.visible})
		part.visible = false


func _restore_round_losers() -> void:
	for entry in _hidden_round_losers:
		var part := entry.get("part") as Node3D
		if is_instance_valid(part):
			part.visible = bool(entry.get("visible", true))
	_hidden_round_losers.clear()


## Kill feed line plus the skill-quest stats for the round that just ended.
## Runs on host and client from the replicated stats, so nothing here is
## authoritative - it only reads what _register_round_death stamped.
func _feed_and_record_round(winning_team: int, is_draw: bool) -> void:
	var identity := func(peer_id: int) -> Dictionary:
		var body = player if peer_id == local_peer_id else remote_players.get_node_or_null(_remote_player_name(peer_id))
		var fallback_color := RED_TEAM_COLOR if _team_for_peer(peer_id) == TEAM_RED else BLUE_TEAM_COLOR
		return {
			"name": str(body.get("display_name")) if body != null else "Player %d" % peer_id,
			"color": body.get("blob_color") if body != null and body.get("blob_color") is Color else fallback_color,
		}
	if is_draw:
		hud.add_feed_message("Double knockout - round drawn", Color(0.72, 0.8, 0.9))
	else:
		var loser_peer := _peer_for_team(TEAM_BLUE if winning_team == TEAM_RED else TEAM_RED)
		var winner_peer := _peer_for_team(winning_team)
		var loser := identity.call(loser_peer) as Dictionary
		var winner := identity.call(winner_peer) as Dictionary
		var cause := str((_player_stats.get(loser_peer, {}) as Dictionary).get("last_death_cause", "health"))
		if cause == "fall":
			hud.add_feed_message("%s fell out of the arena" % str(loser.get("name")), loser.get("color") as Color)
		elif cause == "menu_respawn":
			hud.add_feed_message("%s forfeited the round" % str(loser.get("name")), loser.get("color") as Color)
		else:
			var feed_cause := "knockout" if cause == "fall:knockout" else cause.trim_prefix("health:")
			hud.add_kill_feed_entry(str(winner.get("name")), winner.get("color") as Color, str(loser.get("name")), loser.get("color") as Color, feed_cause)
		var local_won := _team_for_peer(local_peer_id) == winning_team
		if local_won and cause.begins_with("health"):
			hud.show_hit_marker("elimination")
		var progression := get_node_or_null("/root/Progression")
		if progression != null and not _practice_mode and local_won:
			if _stat_round_damage_taken <= 0:
				progression.call("record_stat", "flawless_rounds", 1)
			if cause == "health:rail":
				progression.call("record_stat", "rail_eliminations", 1)
			var used_interactable := false
			var now := Time.get_ticks_msec()
			for meta_key in player.get_meta_list():
				for prefix in STAT_INTERACTABLE_META_PREFIXES:
					if str(meta_key).begins_with(prefix) and int(player.get_meta(meta_key, 0)) >= now - STAT_INTERACTABLE_MEMORY_MSEC:
						used_interactable = true
			if used_interactable:
				progression.call("record_stat", "interactable_eliminations", 1)
	var progression := get_node_or_null("/root/Progression")
	if progression != null and not _practice_mode:
		# Ricochet hits and bounces are measured as round deltas: trick shots
		# arrive with the replicated stats, bounces from the session total.
		var local_stats := _player_stats.get(local_peer_id, {}) as Dictionary
		var trick_shots := int(local_stats.get("trick_shots", 0))
		var trick_delta := trick_shots - _stat_round_trick_shots if trick_shots >= _stat_round_trick_shots else trick_shots
		if trick_delta > 0:
			progression.call("record_stat", "ricochet_hits", trick_delta)
		_stat_round_trick_shots = trick_shots
		var bounce_total := int(progression.call("get_session_total", "bounces"))
		if bounce_total - _stat_round_bounce_mark >= int(progression.get("BOUNCE_ROUND_TARGET")):
			progression.call("record_stat", "bounce_rounds", 1)
		_stat_round_bounce_mark = bounce_total
	_stat_round_damage_taken = 0


func _reset_duel_match_state() -> void:
	_red_score = 0
	_blue_score = 0
	_round_number = 1
	_round_resolving = false
	_match_over = false
	_waiting_for_opponent = false
	_round_countdown_active = false
	_round_countdown_generation += 1
	_local_death_reported = false
	_pending_deaths.clear()
	_death_resolution_deadline = 0
	_player_stats.clear()
	# Resets health, cooldowns, ability timers, and mines for every peer while
	# keeping the loadout each one registered at join.
	_server_peers.reset_for_match()
	_ensure_player_stats(1)
	_server_peers.state_for(1).health = player.max_health
	_victory_sequence_active = false
	_end_victory_pose()
	_match_reward_awarded = false
	_reset_ability_state()
	hud.hide_victory()
	if player != null:
		player.freeze = false
		player.sleeping = false
	hud.set_duel_score(_red_score, _blue_score)
	hud.set_round_number(_round_number)


func _reset_ability_state() -> void:
	_abilities.reset(self)
	_clear_rail_telegraph()
	if is_instance_valid(_active_bounce_mine):
		_active_bounce_mine.queue_free()
	_active_bounce_mine = null
	player.set_overcharge_active(false)
	player.set_phase_bubble(false)
	player.set_shooting_locked(false)


func _record_peer_damage(peer_id: int, amount: int, trick_shot: bool) -> void:
	if amount <= 0:
		return
	_ensure_player_stats(peer_id)
	var stats := _player_stats[peer_id] as Dictionary
	stats["damage"] = int(stats.get("damage", 0)) + amount
	if trick_shot:
		stats["trick_shots"] = int(stats.get("trick_shots", 0)) + 1
	_player_stats[peer_id] = stats
	if peer_id == local_peer_id and not _practice_mode:
		var progression := get_node_or_null("/root/Progression")
		if progression != null:
			progression.call("record_stat", "damage", amount)


func _duel_has_opponent() -> bool:
	if _bot_active:
		return true
	if not network_session.is_online():
		return false
	return not multiplayer.get_peers().is_empty() if multiplayer.is_server() else multiplayer.get_unique_id() != 1


## True for every peer the host is responsible for: connected clients and, in
## an offline bot duel, the bot itself.
func _is_duel_participant(peer_id: int) -> bool:
	if _bot_active and peer_id == BOT_PEER_ID:
		return true
	return multiplayer.get_peers().has(peer_id)


func _is_bot_peer(peer_id: int) -> bool:
	return _bot_active and peer_id == BOT_PEER_ID


func _team_for_peer(peer_id: int) -> int:
	return TEAM_RED if _spawn_slot_for_peer(peer_id) == 0 else TEAM_BLUE


func _peer_for_team(team: int) -> int:
	for peer_key in _peer_spawn_slots:
		var peer_id := int(peer_key)
		if _team_for_peer(peer_id) == team:
			return peer_id
	return -1


func _ensure_player_stats(peer_id: int) -> void:
	if peer_id > 0 and not _player_stats.has(peer_id):
		_player_stats[peer_id] = {"eliminations": 0, "deaths": 0, "damage": 0, "trick_shots": 0}


func _start_victory_sequence(winning_team: int) -> void:
	if _victory_sequence_active or not arena_started:
		return
	_victory_sequence_active = true
	_match_timer_running = false
	player.set_input_enabled(false)
	player.set_shooting_enabled(false)
	player.freeze = true
	for remote in remote_players.get_children():
		(remote as RigidBody3D).freeze = true
	pause_menu.close_pause()
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_set_player_mesh_visible(true)
	var local_team := _team_for_peer(local_peer_id)
	var winner_body: RigidBody3D = _body_for_team(winning_team)
	var winner_name := str(winner_body.get("display_name")) if winner_body != null else ""
	hud.begin_victory_cinematic(winner_name, RED_TEAM_COLOR if winning_team == TEAM_RED else BLUE_TEAM_COLOR, local_team == winning_team)
	audio_manager.stop_all_loops(0.18, true)
	audio_manager.set_music_context(&"victory" if local_team == winning_team else &"defeat", 0.75)
	var stage := _victory_stage_position(winning_team, winner_body)
	_victory_camera_target = stage + Vector3.UP * VICTORY_TARGET_LIFT
	_victory_camera_position = _victory_camera_spot(winning_team, _victory_camera_target, winner_body)
	_victory_elapsed = 0.0
	# Cut straight to the shot: easing in from the duel camera could sweep
	# through walls on the way. The push-in only ever moves closer along the
	# cleared line, so it cannot clip either.
	_update_victory_camera(0.0)
	camera.position = Vector3.ZERO
	if winner_body != null:
		_begin_victory_pose(winner_body, stage)
	audio_manager.play_sfx(&"round_start", -5.0, 0.84)
	_schedule_victory_landing_effects(winning_team)
	await get_tree().create_timer(VICTORY_RESULTS_DELAY).timeout
	if not _victory_sequence_active:
		return
	var is_winner := local_team == winning_team
	hud.show_victory(is_winner, winning_team, _build_match_roster())
	_award_local_match_rewards(winning_team)
	var result_sound: StringName = &"victory_reveal" if is_winner else &"defeat_reveal"
	audio_manager.play_sfx(result_sound, -1.0, 1.0 if is_winner else 0.82)
	await get_tree().create_timer(1.35).timeout
	if _victory_sequence_active:
		audio_manager.play_sfx(&"roster_reveal", -7.0, 1.08)


func _award_local_match_rewards(winning_team: int) -> void:
	if _match_reward_awarded or _practice_mode:
		return
	_match_reward_awarded = true
	var progression := get_node_or_null("/root/Progression")
	if progression == null:
		return
	var local_stats := _player_stats.get(local_peer_id, {"eliminations": 0, "deaths": 0, "damage": 0, "trick_shots": 0}) as Dictionary
	var local_eliminations := int(local_stats.get("eliminations", 0))
	var local_deaths := int(local_stats.get("deaths", 0))
	var highest_eliminations := 0
	for stats_value in _player_stats.values():
		highest_eliminations = maxi(highest_eliminations, int((stats_value as Dictionary).get("eliminations", 0)))
	var reward := progression.call("award_match", {
		"placement": 1 if _team_for_peer(local_peer_id) == winning_team else 2,
		"eliminations": local_eliminations,
		"trick_shots": int(local_stats.get("trick_shots", 0)),
		"damage": int(local_stats.get("damage", 0)),
		"survived": local_deaths == 0,
		"mvp": local_eliminations > 0 and local_eliminations >= highest_eliminations,
		"map_id": _selected_map_id,
	}) as Dictionary
	hud.show_match_rewards(reward)


## Starts high and wide on the cleared line, pushes in, and drifts slowly
## round the winner. `_victory_camera_position` is the far end of the clear
## line, so every point used here is at or inside it.
func _update_victory_camera(_delta: float) -> void:
	var push := _ease_out_cubic(clampf(_victory_elapsed / VICTORY_CAMERA_PUSH_TIME, 0.0, 1.0))
	var offset := _victory_camera_position - _victory_camera_target
	var orbit := sin(_victory_elapsed * VICTORY_CAMERA_ORBIT_SPEED) * deg_to_rad(VICTORY_CAMERA_ORBIT_DEGREES)
	var distance_scale := lerpf(1.0, VICTORY_CAMERA_PUSH, push)
	var rise := lerpf(VICTORY_CAMERA_RISE, 0.0, push)
	camera_rig.global_position = _victory_camera_target + offset.rotated(Vector3.UP, orbit) * distance_scale + Vector3.UP * rise
	var follow := _victory_pose_at(_victory_elapsed).x * VICTORY_CAMERA_FOLLOW if _victory_blob != null else 0.0
	camera_rig.look_at(_victory_camera_target + Vector3.UP * follow, Vector3.UP)
	camera.position = Vector3.ZERO
	camera.fov = lerpf(VICTORY_CAMERA_FOV_START, VICTORY_CAMERA_FOV_END, push)


static func _ease_out_cubic(value: float) -> float:
	return 1.0 - pow(1.0 - value, 3.0)


func _body_for_team(team: int) -> RigidBody3D:
	if _team_for_peer(local_peer_id) == team:
		return player as RigidBody3D
	for child in remote_players.get_children():
		if _team_for_peer(int(child.get("network_peer_id"))) == team:
			return child as RigidBody3D
	return player as RigidBody3D


## Plants the winner on its stage facing the camera; `_update_victory_pose`
## then plays the celebration every frame from `_victory_elapsed`.
func _begin_victory_pose(blob: RigidBody3D, stage: Vector3) -> void:
	_victory_blob = blob
	_victory_stage = stage
	blob.global_position = stage
	blob.linear_velocity = Vector3.ZERO
	blob.angular_velocity = Vector3.ZERO
	var look_direction := _victory_camera_position - stage
	look_direction.y = 0.0
	look_direction = look_direction.normalized() if look_direction.length_squared() > 0.001 else Vector3.FORWARD
	blob.set("aim_direction", look_direction)
	blob.set("aim_yaw", atan2(-look_direction.x, -look_direction.z))
	_update_victory_pose()


func _update_victory_pose() -> void:
	if _victory_blob == null or not is_instance_valid(_victory_blob):
		return
	var pose := _victory_pose_at(_victory_elapsed)
	_victory_blob.global_position = _victory_stage + Vector3.UP * pose.x
	var visual := _victory_blob.get_node_or_null("VisualRoot")
	if visual != null and visual.has_method("set_celebration_pose"):
		visual.call("set_celebration_pose", pose.y, pose.z)


## Hands the winner's look back to physics (rematch, lobby).
func _end_victory_pose() -> void:
	if _victory_blob != null and is_instance_valid(_victory_blob):
		var visual := _victory_blob.get_node_or_null("VisualRoot")
		if visual != null and visual.has_method("set_celebration_pose"):
			visual.call("set_celebration_pose", 0.0, 0.0)
	_victory_blob = null


## Height above the stage (x), squash (y, negative = stretch) and spin (z) at
## time `t`: the scripted hops, then an endless idle bounce.
static func _victory_pose_at(t: float) -> Vector3:
	var hops: Array = VICTORY_HOPS.duplicate()
	if t >= VICTORY_IDLE_START - VICTORY_ANTICIPATION_TIME:
		var index := maxi(0, int(floor((t - VICTORY_IDLE_START) / VICTORY_IDLE_PERIOD)))
		for extra in [index, index + 1]:
			hops.append([VICTORY_IDLE_START + extra * VICTORY_IDLE_PERIOD, VICTORY_IDLE_AIRTIME, VICTORY_IDLE_HEIGHT, 0.0])
	var peak := float((VICTORY_HOPS[0] as Array)[2])
	var last_landing := -100.0
	var last_strength := 0.0
	for hop_value in hops:
		var hop := hop_value as Array
		var takeoff := float(hop[0])
		var airtime := float(hop[1])
		var strength := float(hop[2]) / peak
		if t < takeoff:
			var crouch := 0.0
			var lead := takeoff - t
			if lead < VICTORY_ANTICIPATION_TIME:
				crouch = VICTORY_ANTICIPATION_SQUASH * sqrt(strength) * sin((1.0 - lead / VICTORY_ANTICIPATION_TIME) * PI * 0.5)
			return Vector3(0.0, maxf(crouch, _victory_landing_squash(t - last_landing, last_strength)), 0.0)
		if t < takeoff + airtime:
			var u := (t - takeoff) / airtime
			var height := float(hop[2]) * 4.0 * u * (1.0 - u)
			# Stretched while moving fast (takeoff and fall), round at the apex.
			var stretch := -VICTORY_TAKEOFF_STRETCH * sqrt(strength) * absf(1.0 - 2.0 * u)
			var spin := TAU * float(hop[3]) * smoothstep(0.0, 1.0, u)
			return Vector3(height, stretch, spin)
		last_landing = takeoff + airtime
		last_strength = strength
	return Vector3(0.0, _victory_landing_squash(t - last_landing, last_strength), 0.0)


## A damped jiggle after touchdown: flat first, then a small tall rebound.
static func _victory_landing_squash(since_landing: float, strength: float) -> float:
	if since_landing < 0.0 or since_landing > 0.9:
		return 0.0
	return VICTORY_LANDING_SQUASH * sqrt(strength) * exp(-6.5 * since_landing) * cos(since_landing * 17.0)


## Dust, sound and a small camera kick on each scripted landing.
func _schedule_victory_landing_effects(winning_team: int) -> void:
	var accent := RED_TEAM_COLOR if winning_team == TEAM_RED else BLUE_TEAM_COLOR
	for index in VICTORY_HOPS.size():
		var hop := VICTORY_HOPS[index] as Array
		var takeoff := float(hop[0])
		var landing := takeoff + float(hop[1])
		var strength := float(hop[2]) / float((VICTORY_HOPS[0] as Array)[2])
		get_tree().create_timer(takeoff).timeout.connect(func() -> void:
			if _victory_sequence_active:
				audio_manager.play_sfx(&"jump", -6.0 + strength * 3.0, 1.0 + (1.0 - strength) * 0.25)
		)
		get_tree().create_timer(landing).timeout.connect(func() -> void:
			if not _victory_sequence_active:
				return
			audio_manager.play_sfx(&"land", -4.0 + strength * 4.0, 0.95)
			_spawn_impact_burst(_victory_stage, accent, 0.8 + strength * 1.1)
			if index == 0:
				_spawn_impact_burst(_victory_stage + Vector3.UP * 1.4, Color(1.0, 0.86, 0.35), 1.2)
		)


## The winner's own spawn deck, resting on whatever floor is under it.
func _victory_stage_position(winning_team: int, winner_body: Node3D) -> Vector3:
	var slot := _spawn_slot_for_peer(_peer_for_team(winning_team)) if _peer_for_team(winning_team) > 0 else (0 if winning_team == TEAM_RED else 1)
	var spawn: Vector3 = spawn_manager.get_spawn_for_slot(slot)
	var radius := float(winner_body.get("_collision_radius")) if winner_body != null and winner_body.get("_collision_radius") != null else 2.9
	# Every solid layer: spawn decks are not all on the world layer, and missing
	# the deck lands the stage on the ground underneath it.
	var query := PhysicsRayQueryParameters3D.create(spawn + Vector3.UP * VICTORY_FLOOR_PROBE_UP, spawn - Vector3.UP * VICTORY_FLOOR_PROBE_DOWN)
	var excluded: Array[RID] = []
	for blob in [player] + remote_players.get_children():
		if blob is CollisionObject3D:
			excluded.append((blob as CollisionObject3D).get_rid())
			var hurtbox := (blob as Node).get_node_or_null("Hurtbox") as CollisionObject3D
			if hurtbox != null:
				excluded.append(hurtbox.get_rid())
	query.exclude = excluded
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return spawn
	return Vector3(spawn.x, (hit["position"] as Vector3).y + radius, spawn.z)


## Searches around the stage, starting in front of the spawn's facing, for
## the first camera spot with a clear view of the winner. If every direction
## is cramped, it takes the one with the most room.
func _victory_camera_spot(winning_team: int, target: Vector3, winner_body: Node3D) -> Vector3:
	var slot := _spawn_slot_for_peer(_peer_for_team(winning_team)) if _peer_for_team(winning_team) > 0 else (0 if winning_team == TEAM_RED else 1)
	var yaw: float = spawn_manager.get_spawn_yaw_for_slot(slot)
	var forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var space := get_world_3d().direct_space_state
	var sphere := SphereShape3D.new()
	sphere.radius = VICTORY_CAMERA_CLEARANCE
	var excluded: Array[RID] = []
	for blob in [player] + remote_players.get_children():
		if blob is CollisionObject3D:
			excluded.append((blob as CollisionObject3D).get_rid())
	var best := target + forward * VICTORY_CAMERA_MIN_DISTANCE + Vector3.UP * VICTORY_CAMERA_HEIGHT
	var best_room := -1.0
	for angle in VICTORY_CAMERA_ANGLES_DEGREES:
		var direction := forward.rotated(Vector3.UP, deg_to_rad(float(angle)))
		var desired := target + direction * VICTORY_CAMERA_DISTANCE + Vector3.UP * VICTORY_CAMERA_HEIGHT
		var cast := PhysicsShapeQueryParameters3D.new()
		cast.shape = sphere
		cast.transform = Transform3D(Basis.IDENTITY, target)
		cast.motion = desired - target
		cast.collision_mask = VICTORY_CAMERA_MASK
		cast.exclude = excluded
		var fractions := space.cast_motion(cast)
		var safe_fraction := float(fractions[0]) if fractions.size() > 0 else 1.0
		var room := safe_fraction * VICTORY_CAMERA_DISTANCE
		if safe_fraction >= 0.999:
			return desired
		if room > best_room:
			best_room = room
			best = target + (desired - target) * safe_fraction
	return best


func _build_match_roster() -> Array:
	var roster: Array = []
	var peer_ids: Array[int] = []
	for peer_key in _peer_spawn_slots:
		peer_ids.append(int(peer_key))
	peer_ids.sort()
	for peer_id in peer_ids:
		var body = player if peer_id == local_peer_id else remote_players.get_node_or_null(_remote_player_name(peer_id))
		var team := _team_for_peer(peer_id)
		var stats := _player_stats.get(peer_id, {"eliminations": 0, "deaths": 0}) as Dictionary
		var body_color: Color = body.get("blob_color") if body != null else (RED_TEAM_COLOR if team == TEAM_RED else BLUE_TEAM_COLOR)
		roster.append({
			"name": str(body.get("display_name")) if body != null else "Player %d" % peer_id,
			"color": body_color,
			"team_name": "ORANGE" if team == TEAM_RED else "BLUE",
			"team_color": RED_TEAM_COLOR if team == TEAM_RED else BLUE_TEAM_COLOR,
			"eliminations": int(stats.get("eliminations", 0)),
			"deaths": int(stats.get("deaths", 0)),
			"damage": int(stats.get("damage", 0)),
			"team": team,
			"is_local": peer_id == local_peer_id,
		})
	return roster


func _apply_local_team_identity() -> void:
	if _practice_mode:
		return
	var team_color := RED_TEAM_COLOR if _team_for_peer(local_peer_id) == TEAM_RED else BLUE_TEAM_COLOR
	player.set_player_identity(player.display_name, team_color)


func _restart_match() -> void:
	_resume_from_pause()
	if arena_started:
		_match_time_remaining = match_duration
		_match_timer_running = not _practice_mode
		_set_match_clock_visible(not _practice_mode)
		_respawn_player(false)
		hud.show_announcement("MATCH RESTARTED", Color(0.3, 0.88, 1.0))


## Rematch -----------------------------------------------------------------------
## Keeps every peer, loadout and the chosen map; only the scoreboard resets.
func _on_rematch_requested() -> void:
	if not arena_started or not _match_over or _practice_mode:
		return
	if network_session.is_online() and not multiplayer.is_server():
		_request_rematch.rpc_id(1)
		return
	_start_rematch()


@rpc("any_peer", "call_remote", "reliable")
func _request_rematch() -> void:
	if not multiplayer.is_server() or not arena_started or not _match_over:
		return
	if not multiplayer.get_peers().has(multiplayer.get_remote_sender_id()):
		return
	_start_rematch()


func _start_rematch() -> void:
	if not multiplayer.is_server() or not arena_started or not _match_over:
		return
	_apply_rematch_reset()
	if network_session.is_online():
		_receive_rematch.rpc()
	call_deferred("_begin_synchronized_round_countdown")


@rpc("authority", "call_remote", "reliable")
func _receive_rematch() -> void:
	_apply_rematch_reset()


func _apply_rematch_reset() -> void:
	_victory_sequence_active = false
	_clear_projectiles()
	_reset_duel_match_state()
	for peer_key in _peer_spawn_slots:
		_ensure_player_stats(int(peer_key))
	for remote in remote_players.get_children():
		(remote as RigidBody3D).freeze = true
	camera.fov = 74.0
	hud.set_duel_mode(false)
	hud.show_announcement("REMATCH", Color(0.3, 0.9, 1.0))
	audio_manager.set_music_context(&"match", 0.7)
	if not network_session.is_online() and not _bot_active:
		return
	_force_first_person_camera()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _return_to_lobby() -> void:
	get_tree().paused = false
	_restore_round_losers()
	hud.reset_round_result()
	pause_menu.close_pause()
	_lobby_hud_suppressed_for_pause = false
	network_session.close_session()
	_end_bot_match()
	_clear_projectiles()
	_clear_remote_players()
	arena_started = false
	_match_timer_running = false
	local_peer_id = 1
	_peer_spawn_slots = {1: 0}
	_practice_mode = false
	_end_practice_session()
	_victory_sequence_active = false
	_reset_duel_match_state()
	_activate_practice_map()
	_set_practice_world_enabled(false)
	player.configure_local(local_peer_id)
	_apply_lobby_identity()
	player.set_shooting_enabled(false)
	_set_menu_world_parked(true)
	third_person_enabled = true
	_apply_camera_mode()
	hud.set_lobby_mode(true)
	hud.set_duel_mode(false)
	hud.set_practice_mode(false)
	hud.set_join_status("Choose Host, Join, or Practice", false)
	audio_manager.stop_all_loops(0.18, true)
	audio_manager.call("set_map_music_theme", &"", 0.0, false)
	audio_manager.set_music_context(&"lobby", 0.65)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


## The main menu is an opaque full-screen page, so while it is up the root
## viewport skips 3D rendering and the local blob waits frozen with input off.
## Starting any match unparks it; the arena respawn places it.
func _set_menu_world_parked(parked: bool) -> void:
	get_viewport().disable_3d = parked
	player.set_input_enabled(not parked)
	if parked:
		player.respawn(MENU_PARK_POSITION)
		player.freeze = true


func _activate_practice_map() -> void:
	_clear_competitive_map()
	audio_manager.call("set_map_music_theme", &"", 0.0, false)
	_set_practice_world_enabled(true)
	spawn_manager.use_practice_map()
	# The map owns its look, same as every competitive arena.
	_apply_lighting_profile(practice_arena.get_lighting_profile())


func _activate_competitive_map(map_id: String) -> void:
	var safe_map_id := _validated_map_id(map_id)
	audio_manager.call("set_map_music_theme", StringName(safe_map_id), 0.35, true)
	if _current_competitive_map != null and is_instance_valid(_current_competitive_map) and str(_current_competitive_map.get_meta("map_id", "")) == safe_map_id:
		spawn_manager.use_competitive_map(_current_competitive_map)
		return
	_clear_competitive_map()
	_set_practice_world_enabled(false)
	var packed_scene := COMPETITIVE_MAP_SCENES[safe_map_id] as PackedScene
	_current_competitive_map = packed_scene.instantiate() as Node3D
	_current_competitive_map.set_meta("map_id", safe_map_id)
	competitive_map_root.add_child(_current_competitive_map)
	spawn_manager.use_competitive_map(_current_competitive_map)
	_apply_lighting_profile(_current_competitive_map.call("get_lighting_profile") as Dictionary)


func _clear_competitive_map() -> void:
	if _current_competitive_map == null or not is_instance_valid(_current_competitive_map):
		_current_competitive_map = null
		return
	if _current_competitive_map.get_parent() != null:
		_current_competitive_map.get_parent().remove_child(_current_competitive_map)
	_current_competitive_map.queue_free()
	_current_competitive_map = null


func _set_practice_world_enabled(enabled: bool) -> void:
	practice_arena.visible = enabled
	var practice_collision := practice_arena.get_node_or_null("PracticeCollision") as StaticBody3D
	if practice_collision != null:
		practice_collision.collision_layer = 1 if enabled else 0
	for node in get_tree().get_nodes_in_group("training_dummy"):
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


func _validated_map_id(map_id: String) -> String:
	return map_id if COMPETITIVE_MAP_SCENES.has(map_id) else DEFAULT_MAP_ID


func _assign_spawn_slot(peer_id: int) -> void:
	if peer_id <= 0 or _peer_spawn_slots.has(peer_id):
		return
	for slot in range(4):
		if not _peer_spawn_slots.values().has(slot):
			_peer_spawn_slots[peer_id] = slot
			return
	_peer_spawn_slots[peer_id] = posmod(peer_id, 4)


func _spawn_slot_for_peer(peer_id: int) -> int:
	if _peer_spawn_slots.has(peer_id):
		return int(_peer_spawn_slots[peer_id])
	for key in _peer_spawn_slots:
		if int(key) == peer_id:
			return int(_peer_spawn_slots[key])
	return 0 if peer_id == 1 else posmod(peer_id - 1, 4)


func _apply_lighting_profile(profile: Dictionary) -> void:
	_active_lighting_profile = profile.duplicate(true)
	var environment := world_environment.environment
	var sky_material := environment.sky.sky_material as ProceduralSkyMaterial
	if sky_material != null:
		sky_material.sky_top_color = profile.get("sky_top", Color(0.12, 0.48, 0.92))
		sky_material.sky_horizon_color = profile.get("sky_horizon", Color(0.72, 0.9, 1.0))
	environment.ambient_light_color = profile.get("ambient", Color.WHITE)
	environment.ambient_light_energy = float(profile.get("ambient_energy", 0.72))
	# The environment lights from the sky, which on its own ignores the
	# profile's ambient colour: a night sky left Arena black and flat, a white
	# cloud sky washed out Aether Citadel and Toybox. The profile colour now
	# carries most of the fill, and the sky only tints it.
	environment.ambient_light_sky_contribution = clampf(float(profile.get("ambient_sky_contribution", DEFAULT_AMBIENT_SKY_CONTRIBUTION)), 0.0, 1.0)
	environment.tonemap_exposure = clampf(float(profile.get("exposure", 1.0)), MIN_EXPOSURE, MAX_EXPOSURE)
	environment.fog_light_color = profile.get("fog", Color(0.62, 0.8, 0.93))
	environment.fog_light_energy = float(profile.get("fog_energy", 0.82))
	environment.fog_density = _effective_fog_density(profile)
	environment.fog_sky_affect = float(profile.get("fog_sky_affect", 0.3))
	# Glow defaults on: every map profile now declares glow_enabled explicitly
	# (lighting_contract enforces it), so this default only covers ad-hoc dicts.
	environment.glow_enabled = bool(profile.get("glow_enabled", true)) and _graphics_quality > 0
	environment.glow_intensity = float(profile.get("glow_intensity", 0.5))
	environment.glow_strength = float(profile.get("glow_strength", 0.9)) * (0.74 if _graphics_quality == 1 else 1.0)
	environment.glow_bloom = float(profile.get("glow_bloom", 0.0)) * (0.6 if _graphics_quality == 1 else 1.0)
	sun.light_color = profile.get("sun_color", Color.WHITE)
	sun.light_energy = float(profile.get("sun_energy", 1.4))
	sun.rotation_degrees = profile.get("sun_rotation", Vector3(-52.0, -34.0, 0.0))
	if sky_material != null:
		sky_material.sun_angle_max = float(profile.get("sun_size", 18.0))
		sky_material.sun_curve = float(profile.get("sun_curve", 0.08))
		# Sky cover is opt-in per profile: an unknown or absent key clears it.
		sky_material.sky_cover = SKY_COVER_TEXTURES.get(str(profile.get("sky_cover", ""))) as Texture2D
		sky_material.sky_cover_modulate = profile.get("sky_cover_modulate", Color.WHITE) as Color


func _apply_settings(settings: Dictionary) -> void:
	mouse_sensitivity = clampf(float(settings.get("mouse_sensitivity", 0.0025)), 0.0008, 0.006)
	_gamepad_sensitivity = INPUT_BINDINGS.clamp_gamepad_sensitivity(float(settings.get("gamepad_sensitivity", INPUT_BINDINGS.GAMEPAD_SENSITIVITY_DEFAULT)))
	_invert_look = bool(settings.get("invert_look", false))
	_base_fov = INPUT_BINDINGS.clamp_fov(float(settings.get("fov", INPUT_BINDINGS.FOV_DEFAULT)))
	set_camera_shake_scale(clampf(float(settings.get("camera_shake", 0.72)), 0.0, 1.0))
	hud.apply_crosshair_settings(settings)
	hud.apply_ui_settings(settings)
	get_viewport().scaling_3d_scale = clampf(float(settings.get("render_scale", 1.0)), 0.75, 1.25)

	var wants_fullscreen := bool(settings.get("fullscreen", false))
	get_window().mode = Window.MODE_FULLSCREEN if wants_fullscreen else Window.MODE_WINDOWED
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if bool(settings.get("vsync", true)) else DisplayServer.VSYNC_DISABLED)

	var quality := clampi(int(settings.get("graphics_quality", 1)), 0, 3)
	_graphics_quality = quality
	_effects_quality = clampi(int(settings.get("effects_quality", quality)), 0, 3)
	# MSAA rides the existing quality tier: geometry edges are the game's whole
	# look (primitives + emissive trim), and MSAA is cheap on Apple TBDR. Low
	# keeps it off for weak Macs; Ultra buys 8x for maximum edge crispness;
	# render scale stays the escape hatch.
	get_viewport().msaa_3d = ([Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X, Viewport.MSAA_8X][quality]) as Viewport.MSAA
	# Shadow sharpness scales with the same tier: atlas resolution buys crisp
	# contact edges, the soft-shadow filter buys smooth penumbras on top.
	var shadow_atlas_size: int = [2048, 4096, 4096, 8192][quality]
	RenderingServer.directional_shadow_atlas_set_size(shadow_atlas_size, true)
	get_viewport().positional_shadow_atlas_size = shadow_atlas_size
	RenderingServer.directional_soft_shadow_filter_set_quality(([
		RenderingServer.SHADOW_QUALITY_HARD,
		RenderingServer.SHADOW_QUALITY_SOFT_LOW,
		RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM,
		RenderingServer.SHADOW_QUALITY_SOFT_HIGH,
	][quality]) as RenderingServer.ShadowQuality)
	if player != null:
		player.set_cosmetic_quality(quality)
	var shadow_setting := clampi(int(settings.get("shadow_quality", 2)), 0, 2)
	sun.shadow_enabled = shadow_setting > 0
	sun.directional_shadow_max_distance = 350.0 if shadow_setting == 1 else 700.0
	world_environment.environment.fog_enabled = quality > 0
	world_environment.environment.fog_density = _effective_fog_density(_active_lighting_profile)
	# Same default as _apply_lighting_profile: a profile-less context (lobby,
	# startup) keeps the scene's authored glow instead of silently losing it.
	world_environment.environment.glow_enabled = quality > 0 and bool(_active_lighting_profile.get("glow_enabled", true))

	_set_audio_bus_volume("Master", float(settings.get("master_volume", 0.85)))
	_set_audio_bus_volume("Music", float(settings.get("music_volume", 0.55)))
	_set_audio_bus_volume("SFX", float(settings.get("sfx_volume", 0.8)))


func _effective_fog_density(profile: Dictionary) -> float:
	var profile_density := float(profile.get("fog_density", 0.00065))
	return profile_density * ([0.0, 0.82, 1.0, 1.0][_graphics_quality])


func _set_audio_bus_volume(bus_name: StringName, linear_volume: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index >= 0:
		var clamped_volume := clampf(linear_volume, 0.0, 1.0)
		AudioServer.set_bus_mute(bus_index, clamped_volume <= 0.0)
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(maxf(clamped_volume, 0.001)))


func _update_match_timer(delta: float) -> void:
	if _practice_mode:
		_match_timer_running = false
		_set_match_clock_visible(false)
		return
	if not _match_timer_running or not arena_started:
		return
	_match_time_remaining = maxf(_match_time_remaining - delta, 0.0)
	hud.set_match_time(_match_time_remaining)
	if _match_time_remaining <= 0.0:
		_match_timer_running = false
		if not _practice_mode and multiplayer.is_server():
			_resolve_duel_timeout()


func _resolve_duel_timeout() -> void:
	if _practice_mode or _round_resolving or _match_over:
		return
	var red_peer_id := _peer_for_team(TEAM_RED)
	var blue_peer_id := _peer_for_team(TEAM_BLUE)
	if red_peer_id <= 0 or blue_peer_id <= 0:
		_match_time_remaining = match_duration
		_match_timer_running = true
		hud.show_announcement("WAITING FOR OPPONENT", Color(0.72, 0.8, 0.9))
		return
	var red_health := _authoritative_health_for_peer(red_peer_id)
	var blue_health := _authoritative_health_for_peer(blue_peer_id)
	# More health takes the round; equal health is a coin flip, never a draw.
	var red_wins := red_health > blue_health if red_health != blue_health else randf() < 0.5
	var loser_peer_id := blue_peer_id if red_wins else red_peer_id
	_pending_deaths[loser_peer_id] = {"time": Time.get_ticks_msec(), "reason": "timeout"}
	_resolve_duel_round(loser_peer_id, false)


func _authoritative_health_for_peer(peer_id: int) -> int:
	if peer_id == local_peer_id and multiplayer.is_server():
		return player.health
	return _server_peers.state_for(peer_id).health


func _spawn_impact_burst(world_position: Vector3, color: Color, effect_scale: float) -> void:
	var effect = IMPACT_BURST_SCENE.instantiate()
	add_child(effect)
	effect.configure(world_position, color, effect_scale, _effects_quality)


func _spawn_kill_effect(world_position: Vector3, effect_id: String) -> void:
	var profile := COSMETIC_LIBRARY.kill_profile(effect_id)
	var color := profile.get("color", Color(1.0, 0.7, 0.2)) as Color
	var rarity := str(profile.get("rarity", "Common"))
	var scale := 1.0 if rarity == "Common" else (1.22 if rarity == "Rare" else (1.48 if rarity == "Epic" else 1.78))
	var effect = IMPACT_BURST_SCENE.instantiate()
	add_child(effect)
	effect.configure(world_position, color, scale, _effects_quality, effect_id)
	if rarity in ["Epic", "Legendary"] and _graphics_quality >= 1:
		var echo = IMPACT_BURST_SCENE.instantiate()
		add_child(echo)
		echo.configure(world_position + Vector3.UP * 1.1, color.lightened(0.22), scale * 0.72, _effects_quality, effect_id)
	if rarity == "Legendary" and _graphics_quality >= 2:
		var crown = IMPACT_BURST_SCENE.instantiate()
		add_child(crown)
		crown.configure(world_position + Vector3.UP * 2.0, Color.WHITE, scale * 0.42, _effects_quality, effect_id)


func _clear_projectiles() -> void:
	for projectile in projectiles.get_children():
		projectile.queue_free()
	_active_bounce_mine = null
	_visual_bounce_mines.clear()


func set_camera_shake_scale(value: float) -> void:
	camera_shake_scale = clampf(value, 0.0, 1.0)
	if camera_shake_scale <= 0.0:
		_camera_shake_amount = 0.0


func _add_camera_shake(amount: float) -> void:
	_camera_shake_amount = maxf(_camera_shake_amount, amount * camera_shake_scale)


func _update_camera_shake(delta: float) -> void:
	_camera_shake_time += delta * 38.0
	_camera_shake_amount = move_toward(_camera_shake_amount, 0.0, delta * 2.6)
	var offset := Vector3(
		sin(_camera_shake_time * 1.17),
		cos(_camera_shake_time * 1.63),
		sin(_camera_shake_time * 0.83) * 0.35
	) * _camera_shake_amount
	camera.position = _get_safe_camera_position() + offset


func _get_safe_camera_position() -> Vector3:
	if not third_person_enabled:
		return _camera_base_position
	var ray_start := camera_rig.global_position + Vector3.UP * 0.35
	var desired_world_position := camera_rig.to_global(_camera_base_position)
	var query := PhysicsRayQueryParameters3D.create(ray_start, desired_world_position)
	query.collision_mask = 1
	query.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return _camera_base_position
	var hit_position: Vector3 = hit.position
	var hit_normal: Vector3 = hit.normal
	return camera_rig.to_local(hit_position + hit_normal * 0.45)


func _apply_camera_mode() -> void:
	if third_person_enabled:
		_camera_base_position = Vector3(0.0, 2.8, 20.0)
		camera.fov = _camera_base_fov()
		_set_player_mesh_visible(true)
	else:
		_camera_base_position = Vector3(0.0, 0.65, 0.0)
		camera.fov = _camera_base_fov()
		_set_player_mesh_visible(false)
	camera.position = _camera_base_position


func _update_speed_fov(delta: float) -> void:
	var base_fov := _camera_base_fov()
	var speed_bonus := clampf((player.linear_velocity.length() - 14.0) * 0.22, 0.0, 10.0)
	var charge_tension: float = player.get_charge_ratio() * 2.0 + player.get_adrenaline_fov_bonus()
	_fling_fov_kick = move_toward(_fling_fov_kick, 0.0, delta * 14.0)
	var aiming := arena_started and player.input_enabled and not _victory_sequence_active and Input.is_action_pressed("aim")
	_aim_blend = move_toward(_aim_blend, 1.0 if aiming else 0.0, delta * COMBAT_TUNING.AIM_BLEND_SPEED * 0.5)
	var aim_zoom := lerpf(1.0, COMBAT_TUNING.AIM_FOV_MULTIPLIER, _aim_blend)
	# Aiming in also damps the speed/charge FOV swell so the zoom stays steady.
	var target_fov: float = (base_fov + (speed_bonus + charge_tension + _fling_fov_kick) * (1.0 - _aim_blend * 0.7)) * aim_zoom
	camera.fov = lerpf(camera.fov, target_fov, 1.0 - exp(-8.0 * delta))


func is_aiming_in() -> bool:
	return _aim_blend > 0.5


func _aim_sensitivity_factor() -> float:
	return lerpf(1.0, COMBAT_TUNING.AIM_SENSITIVITY_MULTIPLIER, _aim_blend)


# The FOV setting is the third-person base; first person keeps its historical
# offset on top so the two camera modes stay the same distance apart.
func _camera_base_fov() -> float:
	return _base_fov if third_person_enabled else _base_fov + INPUT_BINDINGS.FIRST_PERSON_FOV_OFFSET


func _look_pitch_sign() -> float:
	return -1.0 if _invert_look else 1.0


# Right-stick look, gated exactly like mouse look (captured cursor, no victory
# sequence) so menus and the practice panel never steal camera control.
func _apply_gamepad_look(delta: float) -> void:
	if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		return
	var look := Input.get_vector("look_left", "look_right", "look_up", "look_down", INPUT_BINDINGS.GAMEPAD_LOOK_DEADZONE)
	if look == Vector2.ZERO:
		return
	var look_sensitivity := _gamepad_sensitivity * _aim_sensitivity_factor()
	camera_yaw -= look.x * look_sensitivity * delta
	camera_pitch = clamp(camera_pitch - look.y * look_sensitivity * delta * _look_pitch_sign(), -PI * 0.495, PI * 0.495)


func _update_player_audio() -> void:
	if not arena_started or _victory_sequence_active:
		audio_manager.set_air_rush(0.0)
		audio_manager.set_movement_audio(0.0, false)
		audio_manager.stop_loop(&"player_low_health", 0.12)
		return
	# Airborne, even a modest flight whistles; on the ground only real speed
	# rushes, and the rolling rumble carries the rest.
	var speed: float = player.linear_velocity.length()
	var grounded: bool = player.is_grounded()
	var rush_floor := 18.0 if grounded else 8.0
	var rush_amount := clampf((speed - rush_floor) / 54.0, 0.0, 1.0)
	audio_manager.set_air_rush(rush_amount)
	var planar_speed := Vector2(player.linear_velocity.x, player.linear_velocity.z).length()
	var roll_amount := clampf((planar_speed - 1.5) / 34.0, 0.0, 1.0) if grounded and not player.freeze else 0.0
	audio_manager.set_movement_audio(roll_amount, grounded and player.is_sliding(), player.is_power_sliding() and not player.freeze)
	if player.health > int(player.max_health * 0.25):
		audio_manager.stop_loop(&"player_low_health", 0.12)
	if not _practice_mode and not _match_over:
		var high_stakes := maxi(_red_score, _blue_score) >= _score_to_win - 1 or _match_time_remaining <= 45.0
		audio_manager.set_music_intensity(high_stakes, 0.55)


func _set_player_mesh_visible(is_visible: bool) -> void:
	var mesh := player.get_node_or_null("VisualRoot/Mesh") as MeshInstance3D
	var marker := player.get_node_or_null("VisualRoot/AimMarker") as MeshInstance3D
	var health_billboard := player.get_node_or_null("HealthBillboard") as Label3D
	var face_root := player.get_node_or_null("FaceRoot") as Node3D
	if mesh != null:
		mesh.visible = is_visible
	if marker != null:
		marker.visible = is_visible
	if health_billboard != null:
		health_billboard.visible = is_visible
	if face_root != null:
		face_root.visible = is_visible


func _ensure_input_actions() -> void:
	_ensure_key_action("toggle_camera", KEY_F5)


func _ensure_key_action(action_name: StringName, keycode: Key) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

	for event in InputMap.action_get_events(action_name):
		var key_event := event as InputEventKey
		if key_event != null and key_event.keycode == keycode:
			return

	var new_event := InputEventKey.new()
	new_event.keycode = keycode
	InputMap.action_add_event(action_name, new_event)
