extends Node3D

const LOBBY_SPAWN_POSITION := Vector3(0.0, 1.8, 634.0)
const BASE_CANVAS_SIZE := Vector2i(1280, 720)
const MINIMUM_WINDOW_SIZE := Vector2i(640, 360)
const PLAYER_SCENE: PackedScene = preload("res://scenes/player/player.tscn")
const PROJECTILE_SCENE: PackedScene = preload("res://scenes/player/projectile.tscn")
const BOUNCE_MINE_SCENE: PackedScene = preload("res://scenes/effects/bounce_mine.tscn")
const IMPACT_BURST_SCENE: PackedScene = preload("res://scenes/effects/impact_burst.tscn")
const COSMETIC_LIBRARY := preload("res://scripts/cosmetic_library.gd")
const ABILITY_TUNING := preload("res://scripts/ability_tuning.gd")
const COMPETITIVE_MAP_SCENES := {
	"neon_arcade": preload("res://scenes/world/maps/neon_arcade.tscn"),
	"backyard": preload("res://scenes/world/maps/backyard.tscn"),
	"arena": preload("res://scenes/world/maps/arena.tscn"),
	"sky_temple": preload("res://scenes/world/maps/sky_temple.tscn"),
	"toybox": preload("res://scenes/world/maps/toybox.tscn"),
}
const MAP_DISPLAY_NAMES := {
	"neon_arcade": "Neon Arcade",
	"backyard": "Backyard",
	"arena": "Arena",
	"sky_temple": "Sky Temple",
	"toybox": "Toybox",
}
const TEAM_RED := 0
const TEAM_BLUE := 1
const SCORE_TO_WIN := 5
const DRAW_WINDOW_MSEC := 35
const DEATH_RESOLUTION_MSEC := 90
const MAX_REMOTE_STATE_SPEED := 92.0
const MAX_REMOTE_STATE_STEP := 50.0
const MIN_REMOTE_STATE_INTERVAL_MSEC := 25
const REMOTE_STATE_LEEWAY := 0.35
const NETWORK_SHOT_COOLDOWN_MSEC := 160
const RED_TEAM_COLOR := Color(0.94, 0.12, 0.18, 1.0)
const BLUE_TEAM_COLOR := Color(0.06, 0.42, 0.96, 1.0)
const REMOTE_COLORS := [
	Color(1.0, 0.28, 0.42, 1.0),
	Color(1.0, 0.72, 0.12, 1.0),
	Color(0.54, 0.34, 1.0, 1.0),
]

@export var mouse_sensitivity := 0.0025
@export var camera_follow_speed := 14.0
@export var network_sync_rate := 20.0
@export_range(0.0, 1.0, 0.05) var camera_shake_scale := 0.72
@export var match_duration := 180.0

@onready var player = $Player
@onready var camera_rig: Node3D = $CameraRig
@onready var camera: Camera3D = $CameraRig/Camera3D
@onready var hud = $HUD
@onready var lobby: Node3D = $Lobby
@onready var practice_arena: Node3D = $CityArena
@onready var competitive_map_root: Node3D = $CompetitiveMapRoot
@onready var lobby_room: StaticBody3D = $Lobby/Room
@onready var join_pad: Area3D = $Lobby/JoinPad
@onready var spawn_manager: Node3D = $SpawnManager
@onready var remote_players: Node3D = $RemotePlayers
@onready var projectiles: Node3D = $Projectiles
@onready var network_session: Node = get_node("/root/NetworkSession")
@onready var pause_menu = $PauseMenu
@onready var sun: DirectionalLight3D = $Sun
@onready var world_environment: WorldEnvironment = $WorldEnvironment
@onready var audio_manager: Node = get_node("/root/AudioManager")

var camera_yaw := 0.0
var camera_pitch := 0.0
var third_person_enabled := false
var arena_started := false
var local_peer_id := 1
var _network_sync_accumulator := 0.0
var _camera_base_position := Vector3.ZERO
var _camera_shake_amount := 0.0
var _camera_shake_time := 0.0
var _fling_fov_kick := 0.0
var _match_time_remaining := 180.0
var _match_timer_running := false
var _practice_mode := false
var _selected_map_id := "neon_arcade"
var _current_competitive_map: Node3D
var _peer_spawn_slots: Dictionary = {1: 0}
var _red_score := 0
var _blue_score := 0
var _round_number := 1
var _round_resolving := false
var _match_over := false
var _local_death_reported := false
var _pending_deaths: Dictionary = {}
var _death_resolution_deadline := 0
var _player_stats: Dictionary = {}
var _victory_sequence_active := false
var _victory_camera_target := Vector3(0.0, 3.2, 0.0)
var _victory_camera_position := Vector3(22.0, 8.0, 28.0)
var _peer_shot_ready_at: Dictionary = {}
var _server_peer_ability_ready_at: Dictionary = {}
var _server_peer_equipped_ability: Dictionary = {}
var _server_peer_ricochet_loaded: Dictionary = {}
var _server_peer_rail_charge_end_at: Dictionary = {}
var _server_peer_overcharge_end_at: Dictionary = {}
var _server_peer_phase_end_at: Dictionary = {}
var _server_peer_gravity_end_at: Dictionary = {}
var _server_peer_bounce_mines: Dictionary = {}
var _server_peer_health: Dictionary = {}
var _peer_last_state_position: Dictionary = {}
var _peer_last_state_msec: Dictionary = {}
var _active_lighting_profile: Dictionary = {}
var _graphics_quality := 1
var _effects_quality := 1
var _match_reward_awarded := false
var _ability_ready_at := 0
var _dash_end_at := 0
var _ricochet_loaded := false
var _scanner_end_at := 0
var _overcharge_end_at := 0
var _scanned_targets: Array[Node3D] = []
var _gravity_pulse_end_at := 0
var _rail_charge_end_at := 0
var _active_bounce_mine: Node3D
var _phase_bubble_end_at := 0



func _ready() -> void:
	_configure_scalable_canvas()
	_ensure_input_actions()
	_connect_session_signals()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	player.configure_local(1)
	player.set_shooting_enabled(false)
	player.fling_released.connect(_on_player_fling_released)
	player.fling_charge_started.connect(_on_player_fling_charge_started)
	player.fling_maximum_reached.connect(_on_player_fling_maximum_reached)
	player.fling_charge_updated.connect(_on_player_fling_charge_updated)
	player.shoot_requested.connect(_handle_local_shot)
	player.bounce_triggered.connect(_on_player_bounce_triggered)
	player.impact_event.connect(_on_player_impact)
	player.damaged.connect(_on_player_damaged)
	player.respawned.connect(_on_player_respawned)
	player.knocked_out.connect(_on_player_knocked_out)
	player.network_collision_requested.connect(_on_network_collision_requested)
	player.respawn(LOBBY_SPAWN_POSITION)
	join_pad.body_entered.connect(_on_join_pad_body_entered)
	hud.bind_player(player)
	hud.host_requested.connect(_on_host_requested)
	hud.join_requested.connect(_on_join_requested)
	hud.practice_requested.connect(_start_practice_match)
	hud.identity_changed.connect(_on_identity_changed)
	_apply_lobby_identity()
	hud.set_lobby_mode(true)
	hud.set_join_status("Choose Host, Join, or Practice", false)
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
		camera_yaw -= motion.relative.x * mouse_sensitivity
		camera_pitch = clamp(camera_pitch - motion.relative.y * mouse_sensitivity, -PI * 0.495, PI * 0.495)

	if event.is_action_pressed("ui_cancel"):
		if hud.is_progression_open():
			hud.close_progression()
			get_viewport().set_input_as_handled()
			return
		if pause_menu.is_open():
			pause_menu.handle_escape()
		else:
			_open_pause()
		get_viewport().set_input_as_handled()
		return

	if not _victory_sequence_active and event.is_action_pressed("toggle_camera"):
		third_person_enabled = not third_person_enabled
		_apply_camera_mode()

	if event.is_action_pressed("use_ability"):
		_use_equipped_ability()

	var mouse_button := event as InputEventMouseButton
	if arena_started and mouse_button != null and mouse_button.pressed and Input.get_mouse_mode() == Input.MOUSE_MODE_VISIBLE:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _process(delta: float) -> void:
	if _victory_sequence_active:
		_update_player_audio()
		_update_victory_camera(delta)
		return
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
	_process_pending_round_death()
	_process_ability_state()
	_apply_gravity_pulse(delta)

	if arena_started and spawn_manager.is_outside_arena(player.global_position):
		if _practice_mode:
			_respawn_player(false)
		else:
			_request_local_death("fall")
	elif not arena_started and spawn_manager.is_outside_lobby(player.global_position):
		player.respawn(LOBBY_SPAWN_POSITION)


func _physics_process(delta: float) -> void:
	if not arena_started or not network_session.is_online():
		return

	_network_sync_accumulator += delta
	if _network_sync_accumulator < 1.0 / network_sync_rate:
		return
	_network_sync_accumulator = 0.0

	if multiplayer.is_server():
		_broadcast_player_state.rpc(local_peer_id, player.global_position, player.rotation, player.linear_velocity, player.health, player.display_name, player.blob_color, player.aim_direction)
	else:
		_submit_player_state.rpc_id(1, player.global_position, player.rotation, player.linear_velocity, player.health, player.display_name, player.blob_color, player.aim_direction)


func _on_host_requested() -> void:
	_apply_lobby_identity()
	_selected_map_id = _validated_map_id(hud.get_selected_map_id())
	_peer_spawn_slots = {1: 0}
	hud.set_join_status("Starting host...", true)
	var result: Error = network_session.host_game()
	if result != OK:
		hud.set_join_status("Host failed on port 7359", false)


func _on_join_requested(address: String) -> void:
	_apply_lobby_identity()
	hud.set_join_status("Connecting to %s..." % address, true)
	var result: Error = network_session.join_game(address)
	if result != OK:
		hud.set_join_status("Could not start connection", false)


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
	local_peer_id = 1
	_clear_remote_players()
	player.configure_local(local_peer_id)
	_practice_mode = true
	_peer_spawn_slots = {1: 0}
	_activate_practice_map()
	_start_arena_for_peer(local_peer_id)


func _on_network_session_ready(is_host: bool) -> void:
	local_peer_id = multiplayer.get_unique_id()
	_clear_remote_players()
	player.configure_local(local_peer_id)
	_practice_mode = false
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
		_server_peer_health[peer_id] = player.max_health
		_peer_last_state_position[peer_id] = spawn_manager.get_spawn_for_slot(_spawn_slot_for_peer(peer_id))
		_peer_last_state_msec[peer_id] = Time.get_ticks_msec()
		_receive_match_setup.rpc(_selected_map_id, _peer_spawn_slots, _red_score, _blue_score)
	if arena_started:
		_ensure_remote_player(peer_id)


func _on_network_peer_left(peer_id: int) -> void:
	_peer_spawn_slots.erase(peer_id)
	_server_peer_health.erase(peer_id)
	_peer_last_state_position.erase(peer_id)
	_peer_last_state_msec.erase(peer_id)
	_peer_shot_ready_at.erase(peer_id)
	_server_peer_ability_ready_at.erase(peer_id)
	_server_peer_equipped_ability.erase(peer_id)
	_server_peer_ricochet_loaded.erase(peer_id)
	_server_peer_rail_charge_end_at.erase(peer_id)
	_server_peer_overcharge_end_at.erase(peer_id)
	_server_peer_phase_end_at.erase(peer_id)
	_server_peer_gravity_end_at.erase(peer_id)
	var peer_mine := _server_peer_bounce_mines.get(peer_id) as Node
	if is_instance_valid(peer_mine):
		peer_mine.queue_free()
	_server_peer_bounce_mines.erase(peer_id)
	var remote := remote_players.get_node_or_null(_remote_player_name(peer_id))
	if remote != null:
		remote.queue_free()
	if multiplayer.is_server() and network_session.is_online():
		_receive_match_setup.rpc(_selected_map_id, _peer_spawn_slots, _red_score, _blue_score)


@rpc("any_peer", "call_remote", "reliable")
func _request_match_setup(equipped_ability: String = "") -> void:
	if not multiplayer.is_server():
		return
	var requester_id := multiplayer.get_remote_sender_id()
	_assign_spawn_slot(requester_id)
	_register_server_peer_loadout(requester_id, equipped_ability)
	_receive_match_setup.rpc_id(requester_id, _selected_map_id, _peer_spawn_slots, _red_score, _blue_score)


func _register_server_peer_loadout(peer_id: int, equipped_ability: String) -> void:
	if _server_peer_equipped_ability.has(peer_id):
		return
	var supported := ["ricochet_shot", "rail_shot", "overcharge", "phase_bubble", "gravity_pulse", "bounce_mine"]
	_server_peer_equipped_ability[peer_id] = equipped_ability if supported.has(equipped_ability) else ""


@rpc("authority", "call_remote", "reliable")
func _receive_match_setup(map_id: String, spawn_slots: Dictionary, red_score: int, blue_score: int) -> void:
	_selected_map_id = _validated_map_id(map_id)
	_peer_spawn_slots = spawn_slots.duplicate()
	_red_score = clampi(red_score, 0, SCORE_TO_WIN)
	_blue_score = clampi(blue_score, 0, SCORE_TO_WIN)
	local_peer_id = multiplayer.get_unique_id()
	_practice_mode = false
	_activate_competitive_map(_selected_map_id)
	if not arena_started:
		_start_arena_for_peer(local_peer_id)
	else:
		_respawn_player(false)
	if local_peer_id != 1:
		_ensure_remote_player(1)


func _start_arena_for_peer(peer_id: int) -> void:
	arena_started = true
	_match_time_remaining = match_duration
	_match_timer_running = true
	var spawn_slot := _spawn_slot_for_peer(peer_id)
	_apply_local_team_identity()
	camera_yaw = spawn_manager.get_spawn_yaw_for_slot(spawn_slot)
	camera_pitch = 0.0
	player.respawn(spawn_manager.get_spawn_for_slot(spawn_slot))
	player.set_shooting_enabled(true)
	join_pad.set_deferred("monitoring", false)
	lobby_room.set_deferred("collision_layer", 0)
	lobby.visible = false
	hud.set_lobby_mode(false)
	hud.set_duel_mode(not _practice_mode)
	hud.set_duel_score(_red_score, _blue_score)
	hud.set_match_time(_match_time_remaining)
	var announcement_text := "PRACTICE" if _practice_mode else str(MAP_DISPLAY_NAMES.get(_selected_map_id, "ROUND START")).to_upper()
	hud.show_announcement(announcement_text, Color(0.3, 0.9, 1.0))
	audio_manager.set_music_context(&"practice" if _practice_mode else &"match", 0.7)
	audio_manager.play_sfx(&"round_start", -2.0)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _respawn_player(_lose_life: bool = false) -> void:
	var spawn_slot := _spawn_slot_for_peer(local_peer_id)
	var spawn_position: Vector3 = spawn_manager.get_spawn_for_slot(spawn_slot) if arena_started else LOBBY_SPAWN_POSITION
	if arena_started:
		camera_yaw = spawn_manager.get_spawn_yaw_for_slot(spawn_slot)
		camera_pitch = 0.0
	player.respawn(spawn_position)


func _on_join_pad_body_entered(body: Node3D) -> void:
	if arena_started or body != player:
		return
	_on_join_requested(hud.get_host_address())


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


func _apply_remote_state(peer_id: int, network_position: Vector3, body_rotation: Vector3, velocity: Vector3, current_health: int, display_name: String, color: Color, facing_direction: Vector3) -> void:
	if peer_id == local_peer_id:
		return
	var remote = _ensure_remote_player(peer_id)
	if _victory_sequence_active:
		remote.apply_network_identity(display_name, color)
		return
	remote.apply_network_state(network_position, body_rotation, velocity, current_health, facing_direction)
	remote.apply_network_identity(display_name, color)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _submit_player_state(network_position: Vector3, body_rotation: Vector3, _velocity: Vector3, _current_health: int, display_name: String, color: Color, facing_direction: Vector3) -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if not multiplayer.get_peers().has(peer_id):
		return
	var now := Time.get_ticks_msec()
	var previous_position: Vector3 = _peer_last_state_position.get(peer_id, spawn_manager.get_spawn_for_slot(_spawn_slot_for_peer(peer_id)))
	var previous_msec := int(_peer_last_state_msec.get(peer_id, now))
	var safe_position := _sanitize_remote_position(peer_id, network_position, now)
	var safe_rotation := body_rotation if body_rotation.is_finite() else Vector3.ZERO
	var safe_velocity := _derive_remote_velocity(previous_position, safe_position, previous_msec, now)
	var safe_health := int(_server_peer_health.get(peer_id, player.max_health))
	var safe_name := display_name.strip_edges().left(24)
	if safe_name.is_empty():
		safe_name = "Player %d" % peer_id
	var safe_color := _sanitize_player_color(color)
	var safe_facing := facing_direction.normalized() if facing_direction.is_finite() and facing_direction.length_squared() > 0.001 else Vector3.FORWARD
	_apply_remote_state(peer_id, safe_position, safe_rotation, safe_velocity, safe_health, safe_name, safe_color, safe_facing)
	_broadcast_player_state.rpc(peer_id, safe_position, safe_rotation, safe_velocity, safe_health, safe_name, safe_color, safe_facing)
	if not _practice_mode and not _round_resolving and spawn_manager.is_outside_arena(safe_position):
		_register_round_death(peer_id, "fall")


func _sanitize_remote_position(peer_id: int, claimed_position: Vector3, now_msec: int) -> Vector3:
	var fallback: Vector3 = _peer_last_state_position.get(peer_id, spawn_manager.get_spawn_for_slot(_spawn_slot_for_peer(peer_id)))
	if not claimed_position.is_finite():
		return fallback
	var last_msec := int(_peer_last_state_msec.get(peer_id, now_msec))
	if now_msec - last_msec < MIN_REMOTE_STATE_INTERVAL_MSEC:
		return fallback
	var elapsed := clampf(float(now_msec - last_msec) / 1000.0, 0.0, 0.5)
	var maximum_step := minf(MAX_REMOTE_STATE_STEP, MAX_REMOTE_STATE_SPEED * elapsed + REMOTE_STATE_LEEWAY)
	var delta := claimed_position - fallback
	var safe_position := fallback + delta.limit_length(maximum_step)
	_peer_last_state_position[peer_id] = safe_position
	_peer_last_state_msec[peer_id] = now_msec
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


@rpc("authority", "call_remote", "unreliable_ordered")
func _broadcast_player_state(peer_id: int, network_position: Vector3, body_rotation: Vector3, velocity: Vector3, current_health: int, display_name: String, color: Color, facing_direction: Vector3) -> void:
	_apply_remote_state(peer_id, network_position, body_rotation, velocity, current_health, display_name, color, facing_direction)


func _on_network_collision_requested(target_peer_id: int, impulse: Vector3, damage: int) -> void:
	if not network_session.is_online() or target_peer_id <= 0:
		return
	var safe_impulse := impulse.limit_length(230.0)
	var safe_damage := clampi(damage, 0, 60)
	if multiplayer.is_server() and multiplayer.get_peers().has(target_peer_id):
		_apply_server_peer_impact(target_peer_id, safe_damage, safe_impulse, false)


@rpc("authority", "call_remote", "reliable")
func _receive_network_collision(impulse: Vector3, damage: int) -> void:
	player.receive_collision_impact(clampi(damage, 0, 60), impulse.limit_length(230.0))


func _handle_local_shot(origin: Vector3, direction: Vector3) -> void:
	if not arena_started or _round_resolving or _match_over or not player.input_enabled:
		return
	var safe_direction := direction.normalized()
	if safe_direction.length_squared() <= 0.001:
		return
	audio_manager.play_sfx(&"projectile_fire", -3.0, 0.96 + randf() * 0.08)
	_add_camera_shake(0.12)
	_spawn_impact_burst(origin - safe_direction * 0.35, Color(1.0, 0.68, 0.18), 0.26)
	if _rail_charge_end_at > Time.get_ticks_msec():
		return
	var ricochet := _consume_ricochet_shot()
	if not network_session.is_online():
		_spawn_projectile(local_peer_id, origin, safe_direction, true, ricochet)
	elif multiplayer.is_server():
		_server_spawn_shot(local_peer_id, origin, safe_direction, ricochet)
	else:
		_request_network_shot.rpc_id(1, origin, safe_direction, ricochet)


@rpc("any_peer", "call_remote", "reliable")
func _request_network_shot(origin: Vector3, direction: Vector3, _requested_ricochet: bool = false, _requested_rail: bool = false) -> void:
	if not multiplayer.is_server() or not arena_started or _round_resolving or _match_over:
		return
	var shooter_peer_id := multiplayer.get_remote_sender_id()
	var shooter = remote_players.get_node_or_null(_remote_player_name(shooter_peer_id))
	if shooter == null or not origin.is_finite() or not direction.is_finite() or direction.length_squared() <= 0.001:
		return
	if origin.distance_to(shooter.global_position) > 8.0:
		return
	var now := Time.get_ticks_msec()
	var rail_charge_end := int(_server_peer_rail_charge_end_at.get(shooter_peer_id, 0))
	if rail_charge_end > now:
		return
	if now < int(_peer_shot_ready_at.get(shooter_peer_id, 0)):
		return
	var shot_interval := NETWORK_SHOT_COOLDOWN_MSEC
	if now < int(_server_peer_overcharge_end_at.get(shooter_peer_id, 0)):
		shot_interval = int(round(float(NETWORK_SHOT_COOLDOWN_MSEC) / ABILITY_TUNING.OVERCHARGE_FIRE_RATE_MULTIPLIER))
	_peer_shot_ready_at[shooter_peer_id] = now + shot_interval
	var safe_direction := direction.normalized()
	var authoritative_origin: Vector3 = shooter.global_position + safe_direction * 3.75 + Vector3.UP * 0.25
	var shot_flags := _consume_server_shot_flags(shooter_peer_id, now)
	_server_spawn_shot(shooter_peer_id, authoritative_origin, safe_direction, bool(shot_flags.get("ricochet", false)), bool(shot_flags.get("rail", false)))


@rpc("any_peer", "call_remote", "reliable")
func _request_network_ability(ability_id: String) -> void:
	if not multiplayer.is_server() or not arena_started or _round_resolving or _match_over:
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if not multiplayer.get_peers().has(peer_id):
		return
	var now := Time.get_ticks_msec()
	if not _is_server_ability_request_allowed(peer_id, ability_id, now):
		return
	match ability_id:
		"ricochet_shot":
			_server_peer_ricochet_loaded[peer_id] = true
		"rail_shot":
			_server_peer_rail_charge_end_at[peer_id] = now + ABILITY_TUNING.RAIL_SHOT_CHARGE_MSEC
		"overcharge":
			var overcharge_end := now + ABILITY_TUNING.OVERCHARGE_DURATION_MSEC
			_server_peer_overcharge_end_at[peer_id] = overcharge_end
			_server_peer_ability_ready_at[peer_id] = overcharge_end + ABILITY_TUNING.OVERCHARGE_COOLDOWN_MSEC
		"phase_bubble":
			var phase_end := now + ABILITY_TUNING.PHASE_BUBBLE_DURATION_MSEC
			_server_peer_phase_end_at[peer_id] = phase_end
			_server_peer_ability_ready_at[peer_id] = phase_end + ABILITY_TUNING.PHASE_BUBBLE_COOLDOWN_MSEC
			var phase_player := remote_players.get_node_or_null(_remote_player_name(peer_id))
			if phase_player != null:
				phase_player.call("set_phase_bubble", true)
		"gravity_pulse":
			var gravity_end := now + ABILITY_TUNING.GRAVITY_PULSE_DURATION_MSEC
			_server_peer_gravity_end_at[peer_id] = gravity_end
			_server_peer_ability_ready_at[peer_id] = gravity_end + ABILITY_TUNING.GRAVITY_PULSE_COOLDOWN_MSEC
		"bounce_mine":
			_server_peer_ability_ready_at[peer_id] = now + ABILITY_TUNING.BOUNCE_MINE_COOLDOWN_MSEC
			_spawn_remote_bounce_mine(peer_id)
		_:
			return


func _is_server_ability_request_allowed(peer_id: int, ability_id: String, now: int) -> bool:
	if str(_server_peer_equipped_ability.get(peer_id, "")) != ability_id:
		return false
	if now < int(_server_peer_ability_ready_at.get(peer_id, 0)):
		return false
	if ability_id == "ricochet_shot" and bool(_server_peer_ricochet_loaded.get(peer_id, false)):
		return false
	if ability_id == "rail_shot" and int(_server_peer_rail_charge_end_at.get(peer_id, 0)) > 0:
		return false
	return true


func _consume_server_shot_flags(peer_id: int, now: int) -> Dictionary:
	var flags := {"ricochet": false, "rail": false}
	var rail_ready_at := int(_server_peer_rail_charge_end_at.get(peer_id, 0))
	if rail_ready_at > 0 and now >= rail_ready_at:
		flags["rail"] = true
		_server_peer_rail_charge_end_at.erase(peer_id)
		_server_peer_ability_ready_at[peer_id] = now + ABILITY_TUNING.RAIL_SHOT_COOLDOWN_MSEC
		return flags
	if bool(_server_peer_ricochet_loaded.get(peer_id, false)):
		flags["ricochet"] = true
		_server_peer_ricochet_loaded.erase(peer_id)
		_server_peer_ability_ready_at[peer_id] = now + ABILITY_TUNING.RICOCHET_COOLDOWN_MSEC
	return flags


func _server_spawn_shot(shooter_peer_id: int, origin: Vector3, direction: Vector3, ricochet: bool = false, rail: bool = false) -> void:
	_spawn_projectile(shooter_peer_id, origin, direction, true, ricochet, rail)
	_replicate_shot.rpc(shooter_peer_id, origin, direction, ricochet, rail)


@rpc("authority", "call_remote", "reliable")
func _replicate_shot(shooter_peer_id: int, origin: Vector3, direction: Vector3, ricochet: bool = false, rail: bool = false) -> void:
	_spawn_projectile(shooter_peer_id, origin, direction, false, ricochet, rail)


func _spawn_projectile(shooter_peer_id: int, origin: Vector3, direction: Vector3, authoritative: bool, ricochet: bool = false, rail: bool = false) -> void:
	var projectile = PROJECTILE_SCENE.instantiate()
	projectile.name = "Shot_%d_%d" % [shooter_peer_id, Time.get_ticks_usec()]
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
		audio_manager.play_sfx_limited(&"projectile_fire", 0.05, -10.0, 0.9 + randf() * 0.08, &"remote_projectile_fire")


func _on_visual_projectile_hit(_target: Node3D, world_position: Vector3, _damage_target: bool, _impact_direction: Vector3, _damage: int, _knockback: float) -> void:
	_spawn_impact_burst(world_position, Color(1.0, 0.42, 0.08), 0.58)
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
	if not damage_target or target == null:
		return
	var impulse_direction := (impact_direction.normalized() + Vector3.UP * 0.18).normalized()
	var impulse := impulse_direction * knockback
	if target.is_in_group("network_blob"):
		var target_peer_id := int(target.get("network_peer_id"))
		if target_peer_id == local_peer_id:
			player.receive_collision_impact(damage, impulse)
		elif multiplayer.is_server() and multiplayer.get_peers().has(target_peer_id):
			_apply_server_peer_impact(target_peer_id, damage, impulse, true)
	else:
		target.call("take_damage", damage, impact_direction, knockback)
	_record_peer_damage(shooter_peer_id, damage, projectile != null and projectile.has_method("is_ricochet_shot") and bool(projectile.call("is_ricochet_shot")))
	if shooter_peer_id == local_peer_id:
		hud.show_hit_marker()
	elif multiplayer.is_server() and multiplayer.get_peers().has(shooter_peer_id):
		_confirm_shot_hit.rpc_id(shooter_peer_id)


@rpc("authority", "call_remote", "reliable")
func _receive_projectile_hit(damage: int, impulse: Vector3) -> void:
	player.receive_collision_impact(clampi(damage, 0, 60), impulse.limit_length(150.0))


func _apply_server_peer_impact(peer_id: int, damage: int, impulse: Vector3, projectile_hit: bool) -> void:
	if not multiplayer.is_server() or not multiplayer.get_peers().has(peer_id):
		return
	var safe_damage := clampi(damage, 0, 60)
	var impulse_limit := 150.0 if projectile_hit else 230.0
	var safe_impulse := impulse.limit_length(impulse_limit)
	var current_health := int(_server_peer_health.get(peer_id, player.max_health))
	var next_health := maxi(current_health - safe_damage, 0)
	_server_peer_health[peer_id] = next_health
	var remote = remote_players.get_node_or_null(_remote_player_name(peer_id))
	if remote != null:
		remote.apply_network_state(remote.global_position, remote.rotation, remote.linear_velocity, next_health, remote.aim_direction)
	if projectile_hit:
		_receive_projectile_hit.rpc_id(peer_id, safe_damage, safe_impulse)
	else:
		_receive_network_collision.rpc_id(peer_id, safe_impulse, safe_damage)
	if next_health <= 0 and current_health > 0 and not _practice_mode:
		_register_round_death(peer_id, "health")


@rpc("authority", "call_remote", "reliable")
func _confirm_shot_hit() -> void:
	hud.show_hit_marker()


func _on_player_fling_released(charge_ratio: float) -> void:
	_add_camera_shake(0.18 + charge_ratio * 0.44)
	_fling_fov_kick = maxf(_fling_fov_kick, charge_ratio * 8.0)
	_spawn_impact_burst(player.global_position, Color(0.08, 0.76, 1.0), 0.52 + charge_ratio * 0.42)
	audio_manager.finish_charge_audio(charge_ratio, true)


func _use_equipped_ability() -> void:
	if not arena_started or _round_resolving or _match_over or not player.input_enabled:
		return
	var progression := get_node_or_null("/root/Progression")
	if progression == null:
		return
	var ability := str(progression.call("get_equipped", "abilities"))
	if ability.is_empty():
		hud.show_announcement("EQUIP AN ABILITY IN THE SHOP", Color(0.96, 0.75, 0.3))
		return
	if ability == "quick_charge":
		hud.show_announcement("QUICK CHARGE IS ACTIVE", Color(0.3, 1.0, 0.5))
		return
	var now := Time.get_ticks_msec()
	if now < _ability_ready_at or _ricochet_loaded or _has_active_timed_ability(now):
		return
	var activated := true
	match ability:
		"dash":
			var direction: Vector3 = player.linear_velocity
			direction.y = 0.0
			if direction.length_squared() <= 0.5:
				direction = player.aim_direction
				direction.y = 0.0
			direction = direction.normalized() if direction.length_squared() > 0.01 else Vector3.FORWARD
			player.apply_central_impulse(direction * 42.0 + Vector3.UP * 2.5)
			player.trigger_launch_visual(0.88)
			_dash_end_at = now + ABILITY_TUNING.DASH_DURATION_MSEC
			_fling_fov_kick = maxf(_fling_fov_kick, 8.0)
			_spawn_impact_burst(player.global_position, Color(0.12, 0.6, 1.0), 0.85)
			hud.show_announcement("DASH!", Color(0.35, 1.0, 0.56))
		"ricochet_shot":
			_ricochet_loaded = true
			hud.show_announcement("RICOCHET LOADED", Color(0.22, 0.72, 1.0))
		"blink":
			activated = _activate_blink()
			if activated:
				_ability_ready_at = now + ABILITY_TUNING.BLINK_COOLDOWN_MSEC
		"target_scanner":
			_activate_target_scanner(now)
		"overcharge":
			_activate_overcharge(now)
		"gravity_pulse":
			_gravity_pulse_end_at = now + ABILITY_TUNING.GRAVITY_PULSE_DURATION_MSEC
			_spawn_impact_burst(player.global_position, Color(0.42, 0.12, 0.82), 1.1)
			hud.show_announcement("GRAVITY PULSE", Color(0.64, 0.3, 1.0))
		"rail_shot":
			_rail_charge_end_at = now + ABILITY_TUNING.RAIL_SHOT_CHARGE_MSEC
			player.set_shooting_locked(true)
			hud.show_announcement("RAIL CHARGING", Color(0.95, 0.98, 1.0))
		"bounce_mine":
			_spawn_bounce_mine()
			_ability_ready_at = now + ABILITY_TUNING.BOUNCE_MINE_COOLDOWN_MSEC
		"phase_bubble":
			_phase_bubble_end_at = now + ABILITY_TUNING.PHASE_BUBBLE_DURATION_MSEC
			player.set_phase_bubble(true)
			_spawn_impact_burst(player.global_position, Color(0.12, 0.76, 1.0), 1.05)
			hud.show_announcement("PHASE BUBBLE", Color(0.32, 0.84, 1.0))
		"adrenaline":
			hud.show_announcement("ADRENALINE ARMS BELOW 60% HP", Color(1.0, 0.28, 0.28))
		_:
			return
	if not activated:
		return
	if network_session.is_online() and not multiplayer.is_server() and ability in ["ricochet_shot", "rail_shot", "overcharge", "phase_bubble", "gravity_pulse", "bounce_mine"]:
		_request_network_ability.rpc_id(1, ability)
	audio_manager.play_ability_sfx(ability)
	progression.call("record_stat", "abilities", 1)


func _process_ability_state() -> void:
	var progression := get_node_or_null("/root/Progression")
	if progression == null:
		return
	var now := Time.get_ticks_msec()
	if multiplayer.is_server():
		_expire_server_peer_abilities(now)
	if _dash_end_at > 0 and now >= _dash_end_at:
		_dash_end_at = 0
		_ability_ready_at = now + ABILITY_TUNING.DASH_COOLDOWN_MSEC
	if _scanner_end_at > 0 and now >= _scanner_end_at:
		_end_target_scanner(now)
	elif _scanner_end_at > now:
		for target in _scanned_targets.duplicate():
			if not is_instance_valid(target) or int(target.get("health")) <= 0:
				if is_instance_valid(target) and target.has_method("set_scanner_highlight"):
					target.call("set_scanner_highlight", false)
				_scanned_targets.erase(target)
	if _overcharge_end_at > 0 and now >= _overcharge_end_at:
		_end_overcharge(now)
	if _gravity_pulse_end_at > 0 and now >= _gravity_pulse_end_at:
		_gravity_pulse_end_at = 0
		_ability_ready_at = now + ABILITY_TUNING.GRAVITY_PULSE_COOLDOWN_MSEC
	if _rail_charge_end_at > 0 and now >= _rail_charge_end_at:
		_fire_rail_shot(now)
	if _phase_bubble_end_at > 0 and now >= _phase_bubble_end_at:
		_phase_bubble_end_at = 0
		player.set_phase_bubble(false)
		_ability_ready_at = now + ABILITY_TUNING.PHASE_BUBBLE_COOLDOWN_MSEC
	if hud.has_method("set_ability_state"):
		var ability := str(progression.call("get_equipped", "abilities"))
		var active: bool = _dash_end_at > now or _scanner_end_at > now or _overcharge_end_at > now or _gravity_pulse_end_at > now or _rail_charge_end_at > now or _phase_bubble_end_at > now or (ability == "adrenaline" and bool(player.is_adrenaline_active()))
		var active_remaining := maxi(maxi(maxi(_scanner_end_at - now, _overcharge_end_at - now), _dash_end_at - now), maxi(maxi(_gravity_pulse_end_at - now, _rail_charge_end_at - now), _phase_bubble_end_at - now))
		var deployed := is_instance_valid(_active_bounce_mine)
		hud.call("set_ability_state", ability, maxi(_ability_ready_at - now, 0), _ricochet_loaded, active, active_remaining, deployed)


func _consume_ricochet_shot() -> bool:
	if not _ricochet_loaded:
		return false
	_ricochet_loaded = false
	_ability_ready_at = Time.get_ticks_msec() + ABILITY_TUNING.RICOCHET_COOLDOWN_MSEC
	hud.show_announcement("RICOCHET FIRED", Color(0.22, 0.72, 1.0))
	return true


func _activate_blink() -> bool:
	var direction: Vector3 = player.linear_velocity
	direction.y = 0.0
	if direction.length_squared() <= 0.5:
		direction = player.aim_direction
		direction.y = 0.0
	direction = direction.normalized() if direction.length_squared() > 0.001 else Vector3.FORWARD
	var origin: Vector3 = player.global_position
	var destination: Vector3 = origin + direction * ABILITY_TUNING.BLINK_RANGE
	var query := PhysicsRayQueryParameters3D.create(origin, destination)
	query.collision_mask = 11
	var excluded: Array[RID] = [player.get_rid()]
	var hurtbox := player.get_node_or_null("Hurtbox") as CollisionObject3D
	if hurtbox != null:
		excluded.append(hurtbox.get_rid())
	query.exclude = excluded
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		destination = Vector3(hit.get("position", origin)) - direction * 0.85
	if destination.distance_to(origin) < 0.35:
		hud.show_announcement("BLINK BLOCKED", Color(0.7, 0.42, 1.0))
		return false
	_spawn_impact_burst(origin, Color(0.62, 0.22, 1.0), 0.6)
	player.global_position = destination
	camera_rig.global_position = destination + Vector3(0.0, 1.8, 0.0)
	_spawn_impact_burst(destination, Color(0.72, 0.32, 1.0), 0.78)
	hud.show_announcement("BLINK", Color(0.72, 0.4, 1.0))
	return true


func _has_active_timed_ability(now: int) -> bool:
	return _dash_end_at > now or _scanner_end_at > now or _overcharge_end_at > now or _gravity_pulse_end_at > now or _rail_charge_end_at > now or _phase_bubble_end_at > now


func _activate_target_scanner(now: int) -> void:
	_scanned_targets.clear()
	for remote_value in remote_players.get_children():
		var remote := remote_value as Node3D
		if remote != null and remote.global_position.distance_to(player.global_position) <= ABILITY_TUNING.SCANNER_RADIUS:
			_scanned_targets.append(remote)
			if remote.has_method("set_scanner_highlight"):
				remote.call("set_scanner_highlight", true)
	_scanner_end_at = now + ABILITY_TUNING.SCANNER_DURATION_MSEC
	_spawn_impact_burst(player.global_position, Color(0.08, 0.58, 1.0), 1.35)
	hud.show_announcement("SCAN PULSE", Color(0.18, 0.68, 1.0))


func _end_target_scanner(now: int) -> void:
	for target in _scanned_targets:
		if is_instance_valid(target) and target.has_method("set_scanner_highlight"):
			target.call("set_scanner_highlight", false)
	_scanned_targets.clear()
	_scanner_end_at = 0
	_ability_ready_at = now + ABILITY_TUNING.SCANNER_COOLDOWN_MSEC


func _activate_overcharge(now: int) -> void:
	_overcharge_end_at = now + ABILITY_TUNING.OVERCHARGE_DURATION_MSEC
	player.set_overcharge_active(true)
	_spawn_impact_burst(player.global_position, Color(1.0, 0.38, 0.06), 0.92)
	hud.show_announcement("OVERCHARGE", Color(1.0, 0.5, 0.12))


func _end_overcharge(now: int) -> void:
	player.set_overcharge_active(false)
	_overcharge_end_at = 0
	_ability_ready_at = now + ABILITY_TUNING.OVERCHARGE_COOLDOWN_MSEC


func _apply_gravity_pulse(delta: float) -> void:
	var now := Time.get_ticks_msec()
	if _gravity_pulse_end_at > now:
		_deflect_projectiles_around(player, delta)
	if multiplayer.is_server():
		for peer_id_value in _server_peer_gravity_end_at.keys():
			if int(_server_peer_gravity_end_at.get(peer_id_value, 0)) <= now:
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


func _expire_server_peer_abilities(now: int) -> void:
	for peer_id_value in _server_peer_phase_end_at.keys():
		if int(_server_peer_phase_end_at.get(peer_id_value, 0)) > now:
			continue
		var peer_id := int(peer_id_value)
		var remote := remote_players.get_node_or_null(_remote_player_name(peer_id))
		if remote != null:
			remote.call("set_phase_bubble", false)
		_server_peer_phase_end_at.erase(peer_id)
	for peer_id_value in _server_peer_overcharge_end_at.keys():
		if int(_server_peer_overcharge_end_at.get(peer_id_value, 0)) <= now:
			_server_peer_overcharge_end_at.erase(peer_id_value)
	for peer_id_value in _server_peer_gravity_end_at.keys():
		if int(_server_peer_gravity_end_at.get(peer_id_value, 0)) <= now:
			_server_peer_gravity_end_at.erase(peer_id_value)


func _fire_rail_shot(now: int) -> void:
	_rail_charge_end_at = 0
	player.set_shooting_locked(false)
	var direction: Vector3 = player.aim_direction.normalized()
	if direction.length_squared() <= 0.001:
		direction = Vector3.FORWARD
	var origin: Vector3 = player.global_position + direction * 3.75 + Vector3.UP * 0.25
	if not network_session.is_online():
		_spawn_projectile(local_peer_id, origin, direction, true, false, true)
	elif multiplayer.is_server():
		_server_spawn_shot(local_peer_id, origin, direction, false, true)
	else:
		_request_network_shot.rpc_id(1, origin, direction, false, true)
	_ability_ready_at = now + ABILITY_TUNING.RAIL_SHOT_COOLDOWN_MSEC
	_spawn_impact_burst(player.global_position, Color(0.95, 0.98, 1.0), 1.05)
	_add_camera_shake(0.08)
	audio_manager.play_sfx(&"projectile_fire", -1.5, 0.72)
	hud.show_announcement("RAIL SHOT", Color(0.98, 0.98, 1.0))


func _spawn_bounce_mine() -> void:
	if is_instance_valid(_active_bounce_mine):
		_active_bounce_mine.queue_free()
	var mine := BOUNCE_MINE_SCENE.instantiate()
	projectiles.add_child(mine)
	mine.configure(player.global_position + player.aim_direction.normalized() * 2.0 + Vector3.UP * 0.3, player.aim_direction, player)
	mine.detonated.connect(_on_bounce_mine_detonated)
	_active_bounce_mine = mine
	_spawn_impact_burst(player.global_position, Color(1.0, 0.35, 0.06), 0.52)
	hud.show_announcement("MINE DEPLOYED", Color(1.0, 0.48, 0.12))


func _spawn_remote_bounce_mine(peer_id: int) -> void:
	var owner := remote_players.get_node_or_null(_remote_player_name(peer_id)) as Node3D
	if owner == null:
		return
	var existing := _server_peer_bounce_mines.get(peer_id) as Node
	if is_instance_valid(existing):
		existing.queue_free()
	var direction: Vector3 = owner.get("aim_direction")
	if direction.length_squared() <= 0.001:
		direction = Vector3.FORWARD
	var mine := BOUNCE_MINE_SCENE.instantiate()
	projectiles.add_child(mine)
	mine.configure(owner.global_position + direction.normalized() * 2.0 + Vector3.UP * 0.3, direction, owner)
	mine.detonated.connect(_on_remote_bounce_mine_detonated.bind(peer_id, mine))
	_server_peer_bounce_mines[peer_id] = mine


func _on_remote_bounce_mine_detonated(world_position: Vector3, peer_id: int, mine: Node) -> void:
	if _server_peer_bounce_mines.get(peer_id) == mine:
		_server_peer_bounce_mines.erase(peer_id)
	var offset: Vector3 = player.global_position - world_position
	var distance: float = offset.length()
	if distance <= 4.5:
		var direction: Vector3 = (offset.normalized() + Vector3.UP * 0.32).normalized()
		var impulse: Vector3 = direction * ABILITY_TUNING.BOUNCE_MINE_LAUNCH_STRENGTH * (1.0 - distance / 6.0)
		player.receive_collision_impact(0, impulse)
	_spawn_impact_burst(world_position, Color(1.0, 0.36, 0.06), 1.35)


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
			if multiplayer.is_server() and multiplayer.get_peers().has(peer_id):
				_apply_server_peer_impact(peer_id, 0, impulse, false)
		elif target.has_method("apply_central_impulse"):
			target.call("apply_central_impulse", impulse)
	_spawn_impact_burst(world_position, Color(1.0, 0.36, 0.06), 1.35)


func _on_player_fling_charge_updated(charge_ratio: float) -> void:
	audio_manager.update_charge_audio(charge_ratio)


func _on_player_fling_charge_started() -> void:
	_spawn_impact_burst(player.global_position - Vector3.UP * 0.8, Color(0.22, 0.78, 1.0), 0.28)
	audio_manager.play_sfx_limited(&"fling_charge", 0.14, -10.0, 0.94, &"fling_charge_start")


func _on_player_fling_maximum_reached() -> void:
	_fling_fov_kick = maxf(_fling_fov_kick, 3.5)
	_spawn_impact_burst(player.global_position, Color(0.85, 0.98, 1.0), 0.48)
	hud.show_announcement("MAX FLING", Color(0.82, 0.96, 1.0))


func _on_player_bounce_triggered(strength: float) -> void:
	var progression := get_node_or_null("/root/Progression")
	if arena_started and progression != null:
		progression.call("record_stat", "bounces", 1)
	_add_camera_shake(clampf(strength * 0.012, 0.08, 0.34))
	_spawn_impact_burst(player.global_position - Vector3.UP * 0.9, Color(0.2, 0.92, 0.78), clampf(strength * 0.025, 0.35, 0.85))
	audio_manager.play_impact(&"bounce", clampf(strength / 42.0, 0.0, 1.0))


func _on_player_impact(world_position: Vector3, strength: float) -> void:
	_add_camera_shake(clampf((strength - 7.0) * 0.025, 0.1, 0.62))
	_spawn_impact_burst(world_position, Color(1.0, 0.48, 0.16), clampf(strength * 0.025, 0.45, 1.0))
	audio_manager.play_impact(&"hard" if strength >= 15.0 else &"wall", clampf(strength / 48.0, 0.0, 1.0))


func _on_player_damaged(_amount: int) -> void:
	_add_camera_shake(0.58)
	hud.show_damage_feedback()
	audio_manager.play_sfx_limited(&"damage", 0.08, -3.0, 0.96 + randf() * 0.08)
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
	if _ricochet_loaded:
		_ricochet_loaded = false
		_ability_ready_at = Time.get_ticks_msec() + ABILITY_TUNING.RICOCHET_COOLDOWN_MSEC
	if _scanner_end_at > 0:
		_end_target_scanner(Time.get_ticks_msec())
	if _overcharge_end_at > 0:
		_end_overcharge(Time.get_ticks_msec())
	if _gravity_pulse_end_at > 0:
		_gravity_pulse_end_at = 0
		_ability_ready_at = Time.get_ticks_msec() + ABILITY_TUNING.GRAVITY_PULSE_COOLDOWN_MSEC
	if _rail_charge_end_at > 0:
		_rail_charge_end_at = 0
		player.set_shooting_locked(false)
		_ability_ready_at = Time.get_ticks_msec() + ABILITY_TUNING.RAIL_SHOT_COOLDOWN_MSEC
	if _phase_bubble_end_at > 0:
		_phase_bubble_end_at = 0
		player.set_phase_bubble(false)
		_ability_ready_at = Time.get_ticks_msec() + ABILITY_TUNING.PHASE_BUBBLE_COOLDOWN_MSEC
	_spawn_kill_effect(player.global_position, player.get_kill_effect_id())
	_request_local_death("health")


func _open_pause() -> void:
	pause_menu.set_context(arena_started and not _practice_mode, arena_started and _practice_mode)
	pause_menu.open_pause()
	player.set_input_enabled(false)
	audio_manager.cancel_charge_audio()
	if not network_session.is_online():
		get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _resume_from_pause() -> void:
	get_tree().paused = false
	pause_menu.close_pause()
	player.set_input_enabled(not _round_resolving and not _match_over)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED if arena_started else Input.MOUSE_MODE_VISIBLE)


func _on_pause_respawn_requested() -> void:
	_resume_from_pause()
	if not arena_started:
		return
	if _practice_mode:
		_respawn_player(false)
	else:
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
	verified = verified or (safe_reason == "health" and int(_server_peer_health.get(peer_id, player.max_health)) <= 0)
	verified = verified or (safe_reason == "fall" and remote != null and spawn_manager.is_outside_arena(remote.global_position))
	if verified:
		_register_round_death(peer_id, safe_reason)


func _register_round_death(peer_id: int, reason: String) -> void:
	if _round_resolving or _match_over or _pending_deaths.has(peer_id):
		return
	if peer_id != 1 and not multiplayer.get_peers().has(peer_id):
		return
	var recorded_at := Time.get_ticks_msec()
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
	_match_over = _red_score >= SCORE_TO_WIN or _blue_score >= SCORE_TO_WIN
	_apply_round_result(_red_score, _blue_score, winning_team, is_draw, _match_over)
	_receive_round_result.rpc(_red_score, _blue_score, winning_team, is_draw, _match_over, _player_stats)
	await get_tree().create_timer(2.0).timeout
	if _match_over or not arena_started:
		return
	_round_number += 1
	_apply_round_reset(_round_number, _red_score, _blue_score)
	_receive_round_reset.rpc(_round_number, _red_score, _blue_score)


@rpc("authority", "call_remote", "reliable")
func _receive_round_result(red_score: int, blue_score: int, winning_team: int, is_draw: bool, match_over: bool, player_stats: Dictionary) -> void:
	_player_stats = player_stats.duplicate(true)
	_apply_round_result(red_score, blue_score, winning_team, is_draw, match_over)


func _apply_round_result(red_score: int, blue_score: int, winning_team: int, is_draw: bool, match_over: bool) -> void:
	_red_score = clampi(red_score, 0, SCORE_TO_WIN)
	_blue_score = clampi(blue_score, 0, SCORE_TO_WIN)
	_round_resolving = true
	_match_over = match_over
	_local_death_reported = true
	_match_timer_running = false
	_clear_projectiles()
	player.set_input_enabled(false)
	player.set_shooting_enabled(false)
	player.freeze = true
	hud.set_duel_score(_red_score, _blue_score, winning_team)
	if is_draw:
		hud.show_round_banner("DRAW", Color(0.66, 0.72, 0.82))
	elif winning_team == TEAM_RED:
		hud.show_round_banner("Red Team Won!", RED_TEAM_COLOR)
	else:
		hud.show_round_banner("Blue Team Won!", BLUE_TEAM_COLOR)
	audio_manager.play_sfx(&"round_end", -2.0)
	if match_over and winning_team >= 0:
		call_deferred("_start_victory_sequence", winning_team)


@rpc("authority", "call_remote", "reliable")
func _receive_round_reset(round_number: int, red_score: int, blue_score: int) -> void:
	_apply_round_reset(round_number, red_score, blue_score)


func _apply_round_reset(round_number: int, red_score: int, blue_score: int) -> void:
	_round_number = maxi(1, round_number)
	_red_score = clampi(red_score, 0, SCORE_TO_WIN)
	_blue_score = clampi(blue_score, 0, SCORE_TO_WIN)
	_round_resolving = false
	_local_death_reported = false
	_pending_deaths.clear()
	player.freeze = false
	player.sleeping = false
	player.set_input_enabled(true)
	player.set_shooting_enabled(true)
	_match_time_remaining = match_duration
	_match_timer_running = true
	if multiplayer.is_server():
		for peer_key in _peer_spawn_slots:
			_server_peer_health[int(peer_key)] = player.max_health
	_respawn_player(false)
	hud.set_duel_score(_red_score, _blue_score)
	hud.show_announcement("ROUND %d" % _round_number, Color(0.86, 0.92, 1.0))


func _reset_duel_match_state() -> void:
	_red_score = 0
	_blue_score = 0
	_round_number = 1
	_round_resolving = false
	_match_over = false
	_local_death_reported = false
	_pending_deaths.clear()
	_death_resolution_deadline = 0
	_player_stats.clear()
	_server_peer_health.clear()
	_peer_last_state_position.clear()
	_peer_last_state_msec.clear()
	_peer_shot_ready_at.clear()
	_server_peer_ability_ready_at.clear()
	_server_peer_ricochet_loaded.clear()
	_server_peer_rail_charge_end_at.clear()
	_server_peer_overcharge_end_at.clear()
	_server_peer_phase_end_at.clear()
	_server_peer_gravity_end_at.clear()
	for mine_value in _server_peer_bounce_mines.values():
		var mine := mine_value as Node
		if is_instance_valid(mine):
			mine.queue_free()
	_server_peer_bounce_mines.clear()
	_ensure_player_stats(1)
	_server_peer_health[1] = player.max_health
	_victory_sequence_active = false
	_match_reward_awarded = false
	_reset_ability_state()
	hud.hide_victory()
	if player != null:
		player.freeze = false
		player.sleeping = false
	hud.set_duel_score(_red_score, _blue_score)


func _reset_ability_state() -> void:
	_ability_ready_at = 0
	_dash_end_at = 0
	_ricochet_loaded = false
	_scanner_end_at = 0
	_overcharge_end_at = 0
	_gravity_pulse_end_at = 0
	_rail_charge_end_at = 0
	_phase_bubble_end_at = 0
	_scanned_targets.clear()
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
	if not network_session.is_online():
		return false
	return not multiplayer.get_peers().is_empty() if multiplayer.is_server() else multiplayer.get_unique_id() != 1


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
	hud.begin_victory_cinematic()
	var local_team := _team_for_peer(local_peer_id)
	audio_manager.stop_all_loops(0.18, true)
	audio_manager.set_music_context(&"victory" if local_team == winning_team else &"defeat", 0.75)
	var side := -1.0 if local_team == TEAM_RED else 1.0
	_victory_camera_position = Vector3(22.0 * side, 8.5, 30.0 * side)
	_victory_camera_target = Vector3(0.0, 3.4, 0.0)
	camera.position = Vector3.ZERO
	camera.fov = 74.0
	var winner_body: RigidBody3D = _body_for_team(winning_team)
	if winner_body != null:
		_animate_winning_blob(winner_body, winning_team)
	audio_manager.play_sfx(&"round_start", -5.0, 0.84)
	await get_tree().create_timer(2.35).timeout
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
	}) as Dictionary
	hud.show_match_rewards(reward)


func _update_victory_camera(delta: float) -> void:
	var blend := 1.0 - exp(-4.5 * delta)
	camera_rig.global_position = camera_rig.global_position.lerp(_victory_camera_position, blend)
	camera_rig.look_at(_victory_camera_target, Vector3.UP)
	camera.position = Vector3.ZERO


func _body_for_team(team: int) -> RigidBody3D:
	if _team_for_peer(local_peer_id) == team:
		return player as RigidBody3D
	for child in remote_players.get_children():
		if _team_for_peer(int(child.get("network_peer_id"))) == team:
			return child as RigidBody3D
	return player as RigidBody3D


func _animate_winning_blob(blob: RigidBody3D, winning_team: int) -> void:
	var spawn_slot := 0 if winning_team == TEAM_RED else 1
	var start: Vector3 = spawn_manager.get_spawn_for_slot(spawn_slot).lerp(Vector3.ZERO, 0.58)
	start.y = 3.2
	blob.global_position = start
	blob.linear_velocity = Vector3.ZERO
	blob.angular_velocity = Vector3.ZERO
	var target := Vector3(0.0, 3.2, 0.0)
	var tween := create_tween()
	for step in range(1, 5):
		var ratio := float(step) / 4.0
		var landing: Vector3 = start.lerp(target, ratio)
		var apex: Vector3 = start.lerp(target, ratio - 0.125)
		apex.y = 6.2 - ratio * 1.2
		tween.tween_property(blob, "global_position", apex, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(blob, "global_position", landing, 0.16).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void:
		var look_direction := (_victory_camera_position - blob.global_position).normalized()
		blob.set("aim_direction", look_direction)
		blob.set("aim_yaw", atan2(-look_direction.x, -look_direction.z))
		blob.call("_update_face")
	)


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
			"team_name": "RED" if team == TEAM_RED else "BLUE",
			"team_color": RED_TEAM_COLOR if team == TEAM_RED else BLUE_TEAM_COLOR,
			"eliminations": int(stats.get("eliminations", 0)),
			"deaths": int(stats.get("deaths", 0)),
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
		_match_timer_running = true
		_respawn_player(false)
		hud.show_announcement("MATCH RESTARTED", Color(0.3, 0.88, 1.0))


func _return_to_lobby() -> void:
	get_tree().paused = false
	pause_menu.close_pause()
	network_session.close_session()
	_clear_projectiles()
	_clear_remote_players()
	arena_started = false
	_match_timer_running = false
	local_peer_id = 1
	_peer_spawn_slots = {1: 0}
	_practice_mode = false
	_victory_sequence_active = false
	_reset_duel_match_state()
	_activate_practice_map()
	lobby.visible = true
	_set_practice_world_enabled(false)
	lobby_room.set_deferred("collision_layer", 1)
	join_pad.set_deferred("monitoring", true)
	player.configure_local(local_peer_id)
	_apply_lobby_identity()
	player.set_input_enabled(true)
	player.set_shooting_enabled(false)
	player.respawn(LOBBY_SPAWN_POSITION)
	_apply_camera_mode()
	hud.set_lobby_mode(true)
	hud.set_duel_mode(false)
	hud.set_join_status("Choose Host, Join, or Practice", false)
	audio_manager.stop_all_loops(0.18, true)
	audio_manager.call("set_map_music_theme", &"", 0.0, false)
	audio_manager.set_music_context(&"lobby", 0.65)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _activate_practice_map() -> void:
	_clear_competitive_map()
	audio_manager.call("set_map_music_theme", &"", 0.0, false)
	_set_practice_world_enabled(true)
	spawn_manager.use_practice_map()
	_apply_lighting_profile({
		"sky_top": Color(0.12, 0.48, 0.92), "sky_horizon": Color(0.72, 0.9, 1.0),
		"ambient": Color(0.84, 0.9, 0.96), "ambient_energy": 0.56,
		"sun_color": Color(1.0, 0.93, 0.8), "sun_energy": 1.14, "fog": Color(0.62, 0.8, 0.93),
	})


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
	var city_collision := practice_arena.get_node_or_null("CityCollision") as StaticBody3D
	if city_collision != null:
		city_collision.collision_layer = 1 if enabled else 0
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
	return map_id if COMPETITIVE_MAP_SCENES.has(map_id) else "neon_arcade"


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
	environment.fog_light_color = profile.get("fog", Color(0.62, 0.8, 0.93))
	environment.fog_light_energy = float(profile.get("fog_energy", 0.82))
	environment.fog_density = _effective_fog_density(profile)
	environment.fog_sky_affect = float(profile.get("fog_sky_affect", 0.3))
	environment.glow_enabled = bool(profile.get("glow_enabled", false)) and _graphics_quality > 0
	environment.glow_intensity = float(profile.get("glow_intensity", 0.8))
	environment.glow_strength = float(profile.get("glow_strength", 1.0)) * (0.74 if _graphics_quality == 1 else 1.0)
	environment.glow_bloom = float(profile.get("glow_bloom", 0.0)) * (0.6 if _graphics_quality == 1 else 1.0)
	sun.light_color = profile.get("sun_color", Color.WHITE)
	sun.light_energy = float(profile.get("sun_energy", 1.4))
	sun.rotation_degrees = profile.get("sun_rotation", Vector3(-52.0, -34.0, 0.0))
	if sky_material != null:
		sky_material.sun_angle_max = float(profile.get("sun_size", 18.0))
		sky_material.sun_curve = float(profile.get("sun_curve", 0.08))


func _apply_settings(settings: Dictionary) -> void:
	mouse_sensitivity = clampf(float(settings.get("mouse_sensitivity", 0.0025)), 0.0008, 0.006)
	set_camera_shake_scale(clampf(float(settings.get("camera_shake", 0.72)), 0.0, 1.0))
	hud.apply_crosshair_settings(settings)
	get_viewport().scaling_3d_scale = clampf(float(settings.get("render_scale", 1.0)), 0.75, 1.25)

	var wants_fullscreen := bool(settings.get("fullscreen", false))
	get_window().mode = Window.MODE_FULLSCREEN if wants_fullscreen else Window.MODE_WINDOWED
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if bool(settings.get("vsync", true)) else DisplayServer.VSYNC_DISABLED)

	var quality := clampi(int(settings.get("graphics_quality", 1)), 0, 2)
	_graphics_quality = quality
	_effects_quality = clampi(int(settings.get("effects_quality", quality)), 0, 2)
	if player != null:
		player.set_cosmetic_quality(quality)
	var shadow_setting := clampi(int(settings.get("shadow_quality", 2)), 0, 2)
	sun.shadow_enabled = shadow_setting > 0
	sun.directional_shadow_max_distance = 350.0 if shadow_setting == 1 else 700.0
	world_environment.environment.fog_enabled = quality > 0
	world_environment.environment.fog_density = _effective_fog_density(_active_lighting_profile)
	world_environment.environment.glow_enabled = quality > 0 and bool(_active_lighting_profile.get("glow_enabled", false))

	_set_audio_bus_volume("Master", float(settings.get("master_volume", 0.85)))
	_set_audio_bus_volume("Music", float(settings.get("music_volume", 0.55)))
	_set_audio_bus_volume("SFX", float(settings.get("sfx_volume", 0.8)))


func _effective_fog_density(profile: Dictionary) -> float:
	var profile_density := float(profile.get("fog_density", 0.00065))
	return profile_density * ([0.0, 0.82, 1.0][_graphics_quality])


func _set_audio_bus_volume(bus_name: StringName, linear_volume: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index >= 0:
		AudioServer.set_bus_volume_db(bus_index, linear_to_db(clampf(linear_volume, 0.001, 1.0)))


func _update_match_timer(delta: float) -> void:
	if not _match_timer_running or not arena_started:
		return
	_match_time_remaining = maxf(_match_time_remaining - delta, 0.0)
	hud.set_match_time(_match_time_remaining)
	if _match_time_remaining <= 0.0:
		_match_timer_running = false
		hud.show_announcement("TIME", Color(1.0, 0.74, 0.2))
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
	if red_health == blue_health:
		_resolve_duel_round(-1, true)
		return
	var loser_peer_id := blue_peer_id if red_health > blue_health else red_peer_id
	_pending_deaths[loser_peer_id] = {"time": Time.get_ticks_msec(), "reason": "timeout"}
	_resolve_duel_round(loser_peer_id, false)


func _authoritative_health_for_peer(peer_id: int) -> int:
	if peer_id == 1 and multiplayer.is_server():
		return player.health
	return int(_server_peer_health.get(peer_id, player.max_health))


func _spawn_impact_burst(world_position: Vector3, color: Color, effect_scale: float) -> void:
	var effect = IMPACT_BURST_SCENE.instantiate()
	add_child(effect)
	effect.configure(world_position, color, effect_scale, _effects_quality)


func _spawn_kill_effect(world_position: Vector3, effect_id: String) -> void:
	var profile := COSMETIC_LIBRARY.kill_profile(effect_id)
	var color := profile.get("color", Color(1.0, 0.7, 0.2)) as Color
	var rarity := str(profile.get("rarity", "Common"))
	var scale := 1.0 if rarity == "Common" else (1.22 if rarity == "Rare" else (1.48 if rarity == "Epic" else 1.78))
	_spawn_impact_burst(world_position, color, scale)
	if rarity in ["Epic", "Legendary"] and _graphics_quality >= 1:
		_spawn_impact_burst(world_position + Vector3.UP * 1.1, color.lightened(0.22), scale * 0.72)
	if rarity == "Legendary" and _graphics_quality >= 2:
		_spawn_impact_burst(world_position + Vector3.UP * 2.0, Color.WHITE, scale * 0.42)


func _clear_projectiles() -> void:
	for projectile in projectiles.get_children():
		projectile.queue_free()


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
		camera.fov = 76.0
		_set_player_mesh_visible(true)
	else:
		_camera_base_position = Vector3(0.0, 0.65, 0.0)
		camera.fov = 88.0
		_set_player_mesh_visible(false)
	camera.position = _camera_base_position


func _update_speed_fov(delta: float) -> void:
	var base_fov := 76.0 if third_person_enabled else 88.0
	var speed_bonus := clampf((player.linear_velocity.length() - 14.0) * 0.22, 0.0, 10.0)
	var charge_tension: float = player.get_charge_ratio() * 2.0 + player.get_adrenaline_fov_bonus()
	_fling_fov_kick = move_toward(_fling_fov_kick, 0.0, delta * 14.0)
	var target_fov: float = base_fov + speed_bonus + charge_tension + _fling_fov_kick
	camera.fov = lerpf(camera.fov, target_fov, 1.0 - exp(-8.0 * delta))


func _update_player_audio() -> void:
	if not arena_started or _victory_sequence_active:
		audio_manager.set_air_rush(0.0)
		audio_manager.stop_loop(&"player_low_health", 0.12)
		return
	var rush_amount := clampf((player.linear_velocity.length() - 18.0) / 54.0, 0.0, 1.0)
	audio_manager.set_air_rush(rush_amount)
	if player.health > int(player.max_health * 0.25):
		audio_manager.stop_loop(&"player_low_health", 0.12)
	if not _practice_mode and not _match_over:
		var high_stakes := maxi(_red_score, _blue_score) >= SCORE_TO_WIN - 1 or _match_time_remaining <= 45.0
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
