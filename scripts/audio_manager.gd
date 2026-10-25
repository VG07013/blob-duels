extends Node

signal music_context_changed(context: StringName)
signal managed_loop_started(loop_id: StringName)
signal managed_loop_stopped(loop_id: StringName)

const SILENT_DB := -60.0
const DEFAULT_MUSIC_FADE := 0.8

## A value is one stream, or an Array of recorded variants picked at random
## per play so repeated actions do not sound machine-identical.
const STREAMS := {
	&"ui_hover": preload("res://assets/audio/ui_hover.wav"),
	&"ui_click": preload("res://assets/audio/ui_click.wav"),
	&"ui_back": preload("res://assets/audio/ui_back.wav"),
	&"ui_open": preload("res://assets/audio/ui_open.wav"),
	&"ui_close": preload("res://assets/audio/ui_close.wav"),
	&"coin_collect": preload("res://assets/audio/ui_open.wav"),
	&"purchase": preload("res://assets/audio/victory.wav"),
	&"shoot": preload("res://assets/audio/shoot.wav"),
	&"projectile_fire": preload("res://assets/audio/projectile_fire.wav"),
	&"projectile_impact": preload("res://assets/audio/projectile_impact.wav"),
	&"damage": preload("res://assets/audio/damage.wav"),
	&"low_health": preload("res://assets/audio/low_health_loop.wav"),
	&"blob_bounce": preload("res://assets/audio/blob_bounce.wav"),
	&"blob_hard_impact": preload("res://assets/audio/blob_hard_impact.wav"),
	&"wall_impact": preload("res://assets/audio/wall_impact.wav"),
	&"blob_collision": preload("res://assets/audio/blob_collision.wav"),
	&"charge_low": preload("res://assets/audio/charge_low.wav"),
	&"charge_loop": preload("res://assets/audio/charge_loop.wav"),
	&"charge_max": preload("res://assets/audio/charge_max.wav"),
	&"fling_charge": preload("res://assets/audio/fling_charge.wav"),
	&"fling_release": preload("res://assets/audio/fling_release.wav"),
	&"fling_full_launch": preload("res://assets/audio/fling_full_launch.wav"),
	&"air_rush": preload("res://assets/audio/air_rush_loop.wav"),
	&"launch_pad": preload("res://assets/audio/launch_pad.wav"),
	&"wind": preload("res://assets/audio/wind_loop.wav"),
	&"machinery": preload("res://assets/audio/machinery_loop.wav"),
	&"display_chirp": preload("res://assets/audio/display_chirp.wav"),
	&"machinery_pulse": preload("res://assets/audio/machinery_pulse.wav"),
	&"portal_teleport": preload("res://assets/audio/portal_teleport.wav"),
	&"bumper_hit": preload("res://assets/audio/bumper_hit.wav"),
	&"conveyor_rail": preload("res://assets/audio/conveyor_rail.wav"),
	&"ambient_sparkle": preload("res://assets/audio/ambient_sparkle.wav"),
	&"respawn": preload("res://assets/audio/respawn.wav"),
	&"round_start": preload("res://assets/audio/round_start.wav"),
	&"round_end": preload("res://assets/audio/round_end.wav"),
	&"victory": preload("res://assets/audio/victory.wav"),
	&"defeat": preload("res://assets/audio/defeat.wav"),
	&"victory_reveal": preload("res://assets/audio/victory.wav"),
	&"defeat_reveal": preload("res://assets/audio/defeat.wav"),
	&"roster_reveal": preload("res://assets/audio/round_start.wav"),
	&"crosshair_save": preload("res://assets/audio/ui_click.wav"),
	&"city_ambience": preload("res://assets/audio/city_ambience.wav"),
	&"ability_ready": preload("res://assets/audio/charge_max.wav"),
	&"ability_dash": preload("res://assets/audio/launch_pad.wav"),
	&"ability_ricochet": preload("res://assets/audio/bumper_hit.wav"),
	&"ability_blink": preload("res://assets/audio/portal_teleport.wav"),
	&"ability_scan": preload("res://assets/audio/display_chirp.wav"),
	&"ability_pulse": preload("res://assets/audio/machinery_pulse.wav"),
	&"ability_phase": preload("res://assets/audio/ambient_sparkle.wav"),
	&"reward_tick": preload("res://assets/audio/ui_open.wav"),
	&"jump": preload("res://assets/audio/kenney/slime_jump.wav"),
	&"air_jump": preload("res://assets/audio/air_jump.wav"),
	&"land": [preload("res://assets/audio/kenney/impactSoft_heavy_000.ogg"), preload("res://assets/audio/kenney/impactSoft_heavy_001.ogg"), preload("res://assets/audio/kenney/impactSoft_heavy_002.ogg"), preload("res://assets/audio/kenney/impactSoft_heavy_003.ogg")],
	&"roll": preload("res://assets/audio/roll_loop.wav"),
	&"slide": preload("res://assets/audio/slide_loop.wav"),
	&"slide_start": preload("res://assets/audio/slide_start.wav"),
	&"slide_hop": preload("res://assets/audio/slide_hop.wav"),
	&"slam_dive": preload("res://assets/audio/slam_dive.wav"),
	&"slam_impact": [preload("res://assets/audio/kenney/impactPunch_heavy_000.ogg"), preload("res://assets/audio/kenney/impactPunch_heavy_001.ogg"), preload("res://assets/audio/kenney/impactPunch_heavy_002.ogg")],
	&"wall_kick": [preload("res://assets/audio/kenney/impactGeneric_light_000.ogg"), preload("res://assets/audio/kenney/impactGeneric_light_001.ogg"), preload("res://assets/audio/kenney/impactGeneric_light_002.ogg")],
	&"blaster_fire": [preload("res://assets/audio/kenney/laserSmall_000.ogg"), preload("res://assets/audio/kenney/laserSmall_001.ogg"), preload("res://assets/audio/kenney/laserSmall_002.ogg"), preload("res://assets/audio/kenney/laserSmall_003.ogg")],
	&"hit_confirm": preload("res://assets/audio/hit_confirm.wav"),
	&"elimination": preload("res://assets/audio/kenney/confirmation_002.ogg"),
	&"hurt": [preload("res://assets/audio/kenney/impactPunch_medium_000.ogg"), preload("res://assets/audio/kenney/impactPunch_medium_001.ogg"), preload("res://assets/audio/kenney/impactPunch_medium_002.ogg")],
	&"knockout": [preload("res://assets/audio/kenney/explosionCrunch_000.ogg"), preload("res://assets/audio/kenney/explosionCrunch_001.ogg")],
	&"equip_swap": preload("res://assets/audio/kenney/switch_002.ogg"),
	&"explosion": preload("res://assets/audio/kenney/explosion_low.wav"),
	&"punch_swing": preload("res://assets/audio/punch_swing.wav"),
	&"punch_hit": preload("res://assets/audio/punch_hit.wav"),
}

## One-shot movement / combat cues grouped for the audio contract.
const MOVEMENT_SFX_KEYS: Array[StringName] = [&"jump", &"air_jump", &"land", &"slam_dive", &"slam_impact", &"wall_kick", &"slide_start", &"slide_hop"]
const COMBAT_SFX_KEYS: Array[StringName] = [&"blaster_fire", &"hit_confirm", &"elimination", &"hurt", &"knockout", &"equip_swap", &"explosion", &"punch_swing", &"punch_hit"]

## Positional cues (the opponent's jumps, shots...) fade out past this range.
const POSITIONAL_SFX_MAX_DISTANCE := 140.0
const POSITIONAL_SFX_UNIT_SIZE := 14.0

## Keyed by competitive map id (game.gd COMPETITIVE_MAP_SCENES).
const MAP_MUSIC_THEMES := {
	&"bounceground": preload("res://assets/audio/music_match_bounceground.wav"),
	# The Training Yard shares the Bounceground track until it gets its own.
	&"training_yard": preload("res://assets/audio/music_match_bounceground.wav"),
	&"skyline": preload("res://assets/audio/music_match_skyline.wav"),
}

## Music plays only in these contexts; every other context (match, practice,
## victory, defeat, intensity) fades the music out so gameplay is sfx-only.
const AUDIBLE_MUSIC_CONTEXTS: Array[StringName] = [&"lobby"]
const MUSIC_CONTEXTS := {
	&"lobby": [
		preload("res://assets/audio/music_lobby.wav"),
		preload("res://assets/audio/music_lobby_b.wav"),
		preload("res://assets/audio/music_lobby_c.wav"),
	],
	&"practice": [preload("res://assets/audio/music_practice.wav")],
	&"match": [
		preload("res://assets/audio/music_match_a.wav"),
		preload("res://assets/audio/music_match_b.wav"),
		preload("res://assets/audio/music_match_neon_arcade.wav"),
		preload("res://assets/audio/music_match_backyard.wav"),
		preload("res://assets/audio/music_match_arena.wav"),
		preload("res://assets/audio/music_match_sky_temple.wav"),
		preload("res://assets/audio/music_match_toybox.wav"),
	],
	&"intensity": [preload("res://assets/audio/music_intensity.wav")],
	&"victory": [preload("res://assets/audio/music_victory.wav")],
	&"defeat": [preload("res://assets/audio/music_defeat.wav")],
}

const MUSIC_LEVELS := {
	&"lobby": -5.0,
	&"practice": -4.5,
	&"match": -3.5,
	&"intensity": -2.5,
	&"victory": -3.0,
	&"defeat": -4.0,
}

const DEFAULT_SFX_COOLDOWNS := {
	&"ui_hover": 0.025,
	&"projectile_impact": 0.025,
	&"blob_bounce": 0.045,
	&"blob_hard_impact": 0.09,
	&"wall_impact": 0.09,
	&"blob_collision": 0.11,
	&"display_chirp": 0.05,
	&"machinery_pulse": 0.08,
	&"portal_teleport": 0.12,
	&"bumper_hit": 0.07,
	&"conveyor_rail": 0.05,
	&"ambient_sparkle": 0.08,
	&"ability_ready": 0.16,
	&"reward_tick": 0.08,
	&"jump": 0.06,
	&"air_jump": 0.06,
	&"land": 0.12,
	&"wall_kick": 0.08,
	&"hit_confirm": 0.04,
	&"hurt": 0.07,
	&"equip_swap": 0.05,
}

const ABILITY_SFX_PROFILES := {
	"dash": {"key": &"ability_dash", "pitch": 1.1},
	"ricochet_shot": {"key": &"ability_ricochet", "pitch": 1.0},
	"blink": {"key": &"ability_blink", "pitch": 1.0},
	"target_scanner": {"key": &"ability_scan", "pitch": 1.0},
	"overcharge": {"key": &"charge_max", "pitch": 1.08},
	"gravity_pulse": {"key": &"ability_pulse", "pitch": 0.92},
	"rail_shot": {"key": &"fling_charge", "pitch": 0.74},
	"bounce_mine": {"key": &"blob_bounce", "pitch": 1.16},
	"phase_bubble": {"key": &"ability_phase", "pitch": 0.84},
	"shockwave": {"key": &"wall_impact", "pitch": 0.62},
}

var _music_players: Array[AudioStreamPlayer] = []
var _active_music_index := 0
var _music_tween: Tween
var _current_music_context: StringName = &""
var _context_before_intensity: StringName = &"match"
var _music_variant_cursors: Dictionary = {}
var _map_music_theme: StringName = &""
var _managed_loops: Dictionary = {}
var _loop_tweens: Dictionary = {}
var _loops_stopping: Dictionary = {}
var _sfx_last_played_msec: Dictionary = {}
var _charge_max_announced := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus(&"Music")
	_ensure_bus(&"SFX")
	_music_players = [
		_make_music_player("MusicPrimary"),
		_make_music_player("MusicSecondary"),
	]
	set_music_context(&"lobby", 0.0)
	var ambience := start_loop(&"city_ambience", -19.0, 1.0, 0.0, &"base_ambience")
	if ambience != null:
		ambience.bus = &"Music"


func _exit_tree() -> void:
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	for tween_value in _loop_tweens.values():
		var loop_tween := tween_value as Tween
		if loop_tween != null and loop_tween.is_valid():
			loop_tween.kill()
	for child in get_children():
		var player := child as AudioStreamPlayer
		if player == null:
			continue
		player.stop()
		player.stream = null
	_music_players.clear()
	_managed_loops.clear()
	_loop_tweens.clear()
	_loops_stopping.clear()


func play_sfx(key: StringName, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	if DEFAULT_SFX_COOLDOWNS.has(key):
		play_sfx_limited(key, float(DEFAULT_SFX_COOLDOWNS[key]), volume_db, pitch_scale)
		return
	var stream := _stream_for(key)
	if stream == null:
		push_warning("Unknown Blob Duels SFX key: %s" % key)
		return
	_spawn_sfx(key, stream, volume_db, pitch_scale)


func play_sfx_limited(
	key: StringName,
	cooldown_seconds: float = 0.08,
	volume_db: float = 0.0,
	pitch_scale: float = 1.0,
	cooldown_group: StringName = &"",
) -> bool:
	var stream := _stream_for(key)
	if stream == null:
		push_warning("Unknown Blob Duels SFX key: %s" % key)
		return false
	var group := cooldown_group if not cooldown_group.is_empty() else key
	var now := Time.get_ticks_msec()
	var last_played := int(_sfx_last_played_msec.get(group, -1000000))
	if now - last_played < int(maxf(cooldown_seconds, 0.0) * 1000.0):
		return false
	_sfx_last_played_msec[group] = now
	_spawn_sfx(key, stream, volume_db, pitch_scale)
	return true


func set_music_context(context: StringName, fade_duration: float = DEFAULT_MUSIC_FADE, restart: bool = false) -> bool:
	if not MUSIC_CONTEXTS.has(context):
		push_warning("Unknown Blob Duels music context: %s" % context)
		return false
	if not AUDIBLE_MUSIC_CONTEXTS.has(context):
		if context != _current_music_context:
			stop_music(fade_duration)
			_current_music_context = context
			music_context_changed.emit(context)
		return true
	var current_player := _music_players[_active_music_index]
	if context == _current_music_context and current_player.playing and not restart:
		return true

	var incoming_index := _active_music_index if _current_music_context.is_empty() else 1 - _active_music_index
	var incoming_player := _music_players[incoming_index]
	var stream := _next_music_stream(context)
	incoming_player.stream = stream
	incoming_player.pitch_scale = 1.0
	incoming_player.volume_db = SILENT_DB if fade_duration > 0.0 else float(MUSIC_LEVELS[context])
	incoming_player.play()

	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	if fade_duration > 0.0:
		_music_tween = create_tween().set_parallel(true)
		_music_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_music_tween.tween_property(incoming_player, "volume_db", float(MUSIC_LEVELS[context]), fade_duration)
		if incoming_player != current_player and current_player.playing:
			_music_tween.tween_property(current_player, "volume_db", SILENT_DB, fade_duration)
			_music_tween.finished.connect(_stop_music_player_if_inactive.bind(current_player))
	elif incoming_player != current_player:
		current_player.stop()

	_active_music_index = incoming_index
	_current_music_context = context
	music_context_changed.emit(context)
	return true


func play_music_context(context: StringName, fade_duration: float = DEFAULT_MUSIC_FADE, restart: bool = false) -> bool:
	return set_music_context(context, fade_duration, restart)


func set_music_intensity(enabled: bool, fade_duration: float = 0.55) -> void:
	if enabled:
		if _current_music_context != &"intensity":
			_context_before_intensity = _current_music_context if not _current_music_context.is_empty() else &"match"
		set_music_context(&"intensity", fade_duration)
	elif _current_music_context == &"intensity":
		set_music_context(_context_before_intensity, fade_duration)


func stop_music(fade_duration: float = DEFAULT_MUSIC_FADE) -> void:
	var player := _music_players[_active_music_index]
	var inactive_player := _music_players[1 - _active_music_index]
	_current_music_context = &""
	if fade_duration <= 0.0:
		player.stop()
		inactive_player.stop()
		return
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	inactive_player.stop()
	_music_tween = create_tween()
	_music_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_music_tween.tween_property(player, "volume_db", SILENT_DB, fade_duration)
	_music_tween.tween_callback(player.stop)


func get_music_context() -> StringName:
	return _current_music_context


## True while any music player is producing sound (a fade-out still counts
## until it finishes).
func is_music_audible() -> bool:
	for player in _music_players:
		if player.playing and player.volume_db > SILENT_DB + 0.5:
			return true
	return false


func get_active_music_stream_path() -> String:
	if _music_players.is_empty():
		return ""
	var stream := _music_players[_active_music_index].stream
	return stream.resource_path if stream != null else ""


func get_music_variant_count(context: StringName) -> int:
	if not MUSIC_CONTEXTS.has(context):
		return 0
	return (MUSIC_CONTEXTS[context] as Array).size()


func set_map_music_theme(theme: StringName, fade_duration: float = DEFAULT_MUSIC_FADE, restart_match: bool = true) -> bool:
	if not theme.is_empty() and not MAP_MUSIC_THEMES.has(theme):
		push_warning("Unknown Blob Duels map music theme: %s" % theme)
		return false
	_map_music_theme = theme
	if restart_match and _current_music_context == &"match":
		set_music_context(&"match", fade_duration, true)
	return true


func get_map_music_theme() -> StringName:
	return _map_music_theme


func has_sfx(key: StringName) -> bool:
	return STREAMS.has(key)


func play_ability_sfx(ability_id: String) -> void:
	var profile := ABILITY_SFX_PROFILES.get(ability_id, {}) as Dictionary
	if profile.is_empty():
		return
	var key := profile.get("key", &"") as StringName
	var pitch := float(profile.get("pitch", 1.0))
	play_sfx_limited(key, 0.08, -6.0, pitch, StringName("ability_%s" % ability_id))


func get_ability_sfx_signature(ability_id: String) -> String:
	var profile := ABILITY_SFX_PROFILES.get(ability_id, {}) as Dictionary
	return str(profile.get("key", &""))


func start_loop(
	key: StringName,
	volume_db: float = 0.0,
	pitch_scale: float = 1.0,
	fade_duration: float = 0.15,
	loop_id: StringName = &"",
) -> AudioStreamPlayer:
	var stream := _stream_for(key)
	if stream == null:
		push_warning("Unknown Blob Duels loop key: %s" % key)
		return null
	var resolved_id := loop_id if not loop_id.is_empty() else key
	var existing := _managed_loops.get(resolved_id) as AudioStreamPlayer
	if is_instance_valid(existing):
		_loops_stopping.erase(resolved_id)
		_cancel_loop_tween(resolved_id)
		set_loop_parameters(resolved_id, volume_db, pitch_scale, fade_duration)
		return existing

	var player := AudioStreamPlayer.new()
	player.name = "Loop_%s" % resolved_id
	player.bus = &"SFX"
	player.stream = stream
	player.pitch_scale = clampf(pitch_scale, 0.1, 4.0)
	player.volume_db = SILENT_DB if fade_duration > 0.0 else volume_db
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(player)
	_managed_loops[resolved_id] = player
	player.finished.connect(_restart_managed_loop.bind(resolved_id, player))
	player.play()
	_fade_loop_property(resolved_id, player, volume_db, fade_duration)
	managed_loop_started.emit(resolved_id)
	return player


func set_loop_parameters(
	loop_id: StringName,
	volume_db: float,
	pitch_scale: float = 1.0,
	fade_duration: float = 0.08,
) -> bool:
	var player := _managed_loops.get(loop_id) as AudioStreamPlayer
	if not is_instance_valid(player):
		return false
	player.pitch_scale = clampf(pitch_scale, 0.1, 4.0)
	_fade_loop_property(loop_id, player, volume_db, fade_duration)
	return true


func stop_loop(loop_id: StringName, fade_duration: float = 0.15) -> bool:
	var player := _managed_loops.get(loop_id) as AudioStreamPlayer
	if not is_instance_valid(player):
		return false
	if _loops_stopping.has(loop_id):
		return true
	var interrupted_tween := _loop_tweens.has(loop_id)
	_cancel_loop_tween(loop_id)
	if interrupted_tween or fade_duration <= 0.0:
		_finish_loop_stop(loop_id, player)
		return true
	_loops_stopping[loop_id] = true
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_loop_tweens[loop_id] = tween
	tween.tween_property(player, "volume_db", SILENT_DB, fade_duration)
	tween.tween_callback(_finish_loop_stop.bind(loop_id, player))
	return true


func stop_all_loops(fade_duration: float = 0.15, keep_base_ambience: bool = true) -> void:
	for value in _managed_loops.keys().duplicate():
		var loop_id := StringName(value)
		if keep_base_ambience and loop_id == &"base_ambience":
			continue
		stop_loop(loop_id, fade_duration)


func is_loop_playing(loop_id: StringName) -> bool:
	var player := _managed_loops.get(loop_id) as AudioStreamPlayer
	return is_instance_valid(player) and player.playing


func update_charge_audio(charge_amount: float) -> void:
	var amount := clampf(charge_amount, 0.0, 1.0)
	if amount <= 0.001:
		cancel_charge_audio()
		return
	if not is_loop_playing(&"player_charge"):
		play_sfx_limited(&"charge_low", 0.2, -7.0, 0.9, &"charge_start")
		start_loop(&"charge_loop", -16.0, 0.78, 0.08, &"player_charge")
	set_loop_parameters(&"player_charge", lerpf(-16.0, -2.5, amount), lerpf(0.78, 1.62, amount), 0.0)
	if amount >= 0.995 and not _charge_max_announced:
		_charge_max_announced = true
		play_sfx(&"charge_max", -1.5)


func finish_charge_audio(charge_amount: float, launched: bool = true) -> void:
	var amount := clampf(charge_amount, 0.0, 1.0)
	stop_loop(&"player_charge", 0.06)
	_charge_max_announced = false
	if not launched:
		return
	if amount >= 0.9:
		play_sfx(&"fling_full_launch", -0.5, lerpf(0.92, 1.06, amount))
	else:
		play_sfx(&"fling_release", lerpf(-10.0, -2.5, amount), lerpf(0.82, 1.12, amount))


func cancel_charge_audio() -> void:
	stop_loop(&"player_charge", 0.08)
	_charge_max_announced = false


func set_air_rush(amount: float) -> void:
	var strength := clampf(amount, 0.0, 1.0)
	if strength < 0.06:
		stop_loop(&"player_air_rush", 0.18)
		return
	if not is_loop_playing(&"player_air_rush"):
		start_loop(&"air_rush", -24.0, 0.78, 0.12, &"player_air_rush")
	set_loop_parameters(&"player_air_rush", lerpf(-24.0, -5.0, strength), lerpf(0.78, 1.42, strength), 0.0)


## Ground contact loops for the local blob: a rumble that follows rolling
## speed (0..1), a scrape while a brake slide is held, and a faster, louder
## scrape while a power slide is held. All stop at zero.
func set_movement_audio(roll_amount: float, sliding: bool, power_sliding: bool = false) -> void:
	var roll := clampf(roll_amount, 0.0, 1.0)
	if roll < 0.04 or sliding or power_sliding:
		stop_loop(&"player_roll", 0.12)
	else:
		if not is_loop_playing(&"player_roll"):
			start_loop(&"roll", -30.0, 0.7, 0.08, &"player_roll")
		set_loop_parameters(&"player_roll", lerpf(-26.0, -9.0, roll), lerpf(0.7, 1.35, roll), 0.0)
	if sliding and not power_sliding:
		if not is_loop_playing(&"player_slide"):
			start_loop(&"slide", -9.0, 1.0, 0.04, &"player_slide")
		set_loop_parameters(&"player_slide", lerpf(-14.0, -6.0, roll), lerpf(0.85, 1.2, roll), 0.0)
	else:
		stop_loop(&"player_slide", 0.1)
	if power_sliding:
		if not is_loop_playing(&"player_power_slide"):
			start_loop(&"slide", -8.0, 1.1, 0.03, &"player_power_slide")
		set_loop_parameters(&"player_power_slide", lerpf(-11.0, -3.0, roll), lerpf(1.0, 1.45, roll), 0.0)
	else:
		stop_loop(&"player_power_slide", 0.1)


## Plays a one-shot from a world position (heard relative to the active
## camera), for sounds made by blobs other than the local player.
func play_sfx_at(
	key: StringName,
	world_position: Vector3,
	volume_db: float = 0.0,
	pitch_scale: float = 1.0,
	cooldown_seconds: float = 0.0,
	cooldown_group: StringName = &"",
) -> bool:
	if not world_position.is_finite():
		return false
	var stream := _stream_for(key)
	if stream == null:
		push_warning("Unknown Blob Duels SFX key: %s" % key)
		return false
	if cooldown_seconds > 0.0:
		var group := cooldown_group if not cooldown_group.is_empty() else StringName("at_%s" % key)
		var now := Time.get_ticks_msec()
		if now - int(_sfx_last_played_msec.get(group, -1000000)) < int(cooldown_seconds * 1000.0):
			return false
		_sfx_last_played_msec[group] = now
	var player := AudioStreamPlayer3D.new()
	player.name = "SFX3D_%s" % key
	player.bus = &"SFX"
	player.stream = stream
	player.volume_db = clampf(volume_db, SILENT_DB, 12.0)
	player.pitch_scale = clampf(pitch_scale, 0.1, 4.0)
	player.unit_size = POSITIONAL_SFX_UNIT_SIZE
	player.max_distance = POSITIONAL_SFX_MAX_DISTANCE
	player.attenuation_filter_cutoff_hz = 9000.0
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(player)
	player.global_position = world_position
	player.finished.connect(player.queue_free)
	player.play()
	return true


func set_world_loop(kind: StringName, amount: float, loop_id: StringName = &"") -> bool:
	if kind not in [&"wind", &"machinery"]:
		return false
	var resolved_id := loop_id if not loop_id.is_empty() else kind
	var strength := clampf(amount, 0.0, 1.0)
	if strength <= 0.001:
		return stop_loop(resolved_id, 0.2)
	if not is_loop_playing(resolved_id):
		start_loop(kind, -24.0, 0.85, 0.2, resolved_id)
	return set_loop_parameters(resolved_id, lerpf(-24.0, -7.0, strength), lerpf(0.85, 1.18, strength), 0.0)


func play_impact(kind: StringName, strength: float) -> bool:
	var amount := clampf(strength, 0.0, 1.0)
	if amount < 0.06:
		return false
	var key := &"blob_bounce"
	var cooldown := 0.07
	match kind:
		&"wall":
			key = &"wall_impact"
			cooldown = 0.1
		&"blob":
			key = &"blob_collision"
			cooldown = 0.12
		&"hard":
			key = &"blob_hard_impact"
			cooldown = 0.1
	return play_sfx_limited(key, cooldown, lerpf(-15.0, 0.0, amount), lerpf(0.82, 1.18, amount), StringName("impact_%s" % kind))


func wire_ui_sounds(root_node: Node) -> void:
	for node in root_node.find_children("*", "Button", true, false):
		var button := node as Button
		if button == null or button.has_meta("audio_wired"):
			continue
		button.set_meta("audio_wired", true)
		button.mouse_entered.connect(func() -> void: play_sfx_limited(&"ui_hover", 0.025, -8.0))
		button.pressed.connect(func() -> void: play_sfx(&"ui_click", -5.0))


func _stream_for(key: StringName) -> AudioStream:
	var entry: Variant = STREAMS.get(key)
	if entry is Array:
		var variants := entry as Array
		return null if variants.is_empty() else variants[randi() % variants.size()] as AudioStream
	return entry as AudioStream


func _spawn_sfx(key: StringName, stream: AudioStream, volume_db: float, pitch_scale: float) -> void:
	var player := AudioStreamPlayer.new()
	player.name = "SFX_%s" % key
	player.bus = &"SFX"
	player.stream = stream
	player.volume_db = clampf(volume_db, SILENT_DB, 12.0)
	player.pitch_scale = clampf(pitch_scale, 0.1, 4.0)
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func _ensure_bus(bus_name: StringName) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)


func _make_music_player(node_name: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = node_name
	player.bus = &"Music"
	player.volume_db = SILENT_DB
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(player)
	player.finished.connect(_restart_music_if_active.bind(player))
	return player


func _next_music_stream(context: StringName) -> AudioStream:
	if context == &"match" and MAP_MUSIC_THEMES.has(_map_music_theme):
		return MAP_MUSIC_THEMES[_map_music_theme] as AudioStream
	var variants := MUSIC_CONTEXTS[context] as Array
	var cursor := int(_music_variant_cursors.get(context, 0))
	_music_variant_cursors[context] = (cursor + 1) % variants.size()
	return variants[cursor] as AudioStream


func _restart_music_if_active(player: AudioStreamPlayer) -> void:
	if _current_music_context.is_empty():
		return
	if player == _music_players[_active_music_index]:
		player.stream = _next_music_stream(_current_music_context)
		player.play()


func _stop_music_player_if_inactive(player: AudioStreamPlayer) -> void:
	if player != _music_players[_active_music_index]:
		player.stop()


func _restart_managed_loop(loop_id: StringName, player: AudioStreamPlayer) -> void:
	if _managed_loops.get(loop_id) == player:
		player.play()


func _fade_loop_property(loop_id: StringName, player: AudioStreamPlayer, volume_db: float, duration: float) -> void:
	_cancel_loop_tween(loop_id)
	var target := clampf(volume_db, SILENT_DB, 12.0)
	if duration <= 0.0:
		player.volume_db = target
		return
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_loop_tweens[loop_id] = tween
	tween.tween_property(player, "volume_db", target, duration)
	tween.finished.connect(_clear_loop_tween.bind(loop_id, tween))


func _cancel_loop_tween(loop_id: StringName) -> void:
	var tween := _loop_tweens.get(loop_id) as Tween
	if tween != null and tween.is_valid():
		tween.kill()
	_loop_tweens.erase(loop_id)


func _clear_loop_tween(loop_id: StringName, tween: Tween) -> void:
	if _loop_tweens.get(loop_id) == tween:
		_loop_tweens.erase(loop_id)


func _finish_loop_stop(loop_id: StringName, player: AudioStreamPlayer) -> void:
	_loops_stopping.erase(loop_id)
	if _managed_loops.get(loop_id) != player:
		return
	_managed_loops.erase(loop_id)
	_loop_tweens.erase(loop_id)
	player.stop()
	player.queue_free()
	managed_loop_stopped.emit(loop_id)
