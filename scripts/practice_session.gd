class_name PracticeSession
extends Node

## Owns everything about a practice run that is not map geometry: the shared
## dummy configuration, the training toggles, and the shooting statistics the
## practice HUD reads.
##
## One controller for all eight stations on purpose - the spec asks for a single
## central panel, not eight physical terminals, so every dummy takes its mode,
## health preset, and speed from here.

const TRAINING := preload("res://scripts/practice_training.gd")

signal stats_changed
signal config_changed
signal dummy_shot_requested(dummy: Node3D, origin: Vector3, direction: Vector3)

## Shared dummy configuration ---------------------------------------------------
var dummy_mode := TRAINING.DEFAULT_MODE
var dummy_health_preset := TRAINING.DEFAULT_HEALTH
var dummy_movement_enabled := true
var dummy_shooting_enabled := true
## Return fire is harmless until the player asks for it, per the spec's
## "damage can be disabled by default".
var dummy_damage_enabled := false
var damage_numbers_enabled := true
var dummy_speed_scale := TRAINING.DEFAULT_SPEED_SCALE

## Player-side training toggles --------------------------------------------------
var player_invincible := true
var infinite_ammo := false
var cooldowns_enabled := true

## Statistics --------------------------------------------------------------------
var shots_fired := 0
var shots_hit := 0
var damage_dealt := 0
var current_streak := 0
var best_streak := 0
var best_combo := 0
var elapsed_time := 0.0

var _active := false
var _combo := 0
var _combo_timer := 0.0
var _player: BlobPlayer = null
var _dummies: Array[DummyBlob] = []

## A combo is a chain of scoring beats - hits, flings, and bounces - that keeps
## going while the player lands something every few seconds.
const COMBO_WINDOW := 2.6


func _process(delta: float) -> void:
	if not _active:
		return
	elapsed_time += delta
	if _combo > 0:
		_combo_timer -= delta
		if _combo_timer <= 0.0:
			_combo = 0
	# The HUD redraws from this signal; time and speed change every frame.
	stats_changed.emit()


## Lifecycle ---------------------------------------------------------------------
## begin() is called when the practice map activates and end() when the player
## leaves, so a duel never carries practice state.
func begin(player: BlobPlayer, dummies: Array[DummyBlob]) -> void:
	_player = player
	_bind_dummies(dummies)
	reset_stats()
	_active = true
	apply_dummy_config()
	config_changed.emit()


func end() -> void:
	_active = false
	_player = null
	_dummies.clear()


func is_active() -> bool:
	return _active


func _bind_dummies(dummies: Array[DummyBlob]) -> void:
	_dummies = dummies.duplicate()
	for dummy in _dummies:
		if not is_instance_valid(dummy):
			continue
		dummy.set_practice_target(_player)
		if not dummy.shot_requested.is_connected(_on_dummy_shot_requested):
			dummy.shot_requested.connect(_on_dummy_shot_requested.bind(dummy))


func _on_dummy_shot_requested(origin: Vector3, direction: Vector3, dummy: Node3D) -> void:
	if not _active:
		return
	dummy_shot_requested.emit(dummy, origin, direction)


## Configuration -----------------------------------------------------------------
## Every setter funnels into apply_dummy_config so the eight stations can never
## drift out of sync with the panel the player is reading.
func apply_dummy_config() -> void:
	for dummy in _dummies:
		if not is_instance_valid(dummy):
			continue
		dummy.configure_training(
			dummy_mode,
			dummy_health_preset,
			dummy_movement_enabled,
			dummy_shooting_enabled,
			damage_numbers_enabled,
			dummy_speed_scale,
		)
		dummy.set_practice_target(_player)


func set_dummy_mode(mode: int) -> void:
	dummy_mode = mode if TRAINING.MODE_IDS.has(mode) else TRAINING.DEFAULT_MODE
	apply_dummy_config()
	config_changed.emit()


func cycle_dummy_mode() -> void:
	var index := TRAINING.MODE_IDS.find(dummy_mode)
	set_dummy_mode(TRAINING.MODE_IDS[(index + 1) % TRAINING.MODE_IDS.size()])


func set_dummy_health_preset(preset: int) -> void:
	dummy_health_preset = preset if TRAINING.HEALTH_PRESETS.has(preset) else TRAINING.DEFAULT_HEALTH
	apply_dummy_config()
	config_changed.emit()


func set_dummy_speed_scale(scale: float) -> void:
	dummy_speed_scale = clampf(scale, 0.25, 3.0)
	apply_dummy_config()
	config_changed.emit()


func set_dummy_movement_enabled(enabled: bool) -> void:
	dummy_movement_enabled = enabled
	apply_dummy_config()
	config_changed.emit()


func set_dummy_shooting_enabled(enabled: bool) -> void:
	dummy_shooting_enabled = enabled
	apply_dummy_config()
	config_changed.emit()


func set_damage_numbers_enabled(enabled: bool) -> void:
	damage_numbers_enabled = enabled
	apply_dummy_config()
	config_changed.emit()


func set_player_invincible(enabled: bool) -> void:
	player_invincible = enabled
	config_changed.emit()


func set_infinite_ammo(enabled: bool) -> void:
	infinite_ammo = enabled
	config_changed.emit()


func set_cooldowns_enabled(enabled: bool) -> void:
	cooldowns_enabled = enabled
	config_changed.emit()


## Statistics --------------------------------------------------------------------
func note_shot_fired() -> void:
	if not _active:
		return
	shots_fired += 1
	stats_changed.emit()


## A hit lands: accuracy, streak, and combo all advance together.
func note_dummy_hit(damage: int) -> void:
	if not _active:
		return
	shots_hit += 1
	damage_dealt += maxi(damage, 0)
	current_streak += 1
	best_streak = maxi(best_streak, current_streak)
	note_combo_beat()
	stats_changed.emit()


## A resolved shot that found something other than a dummy breaks the streak.
## Shots that simply expire in the air are still counted against accuracy.
func note_shot_missed() -> void:
	if not _active:
		return
	current_streak = 0
	stats_changed.emit()


## Flings and bounce-pad launches extend the same chain as hits, which is what
## the spec's combo practice mode is counting.
func note_combo_beat() -> void:
	if not _active:
		return
	_combo += 1
	_combo_timer = COMBO_WINDOW
	best_combo = maxi(best_combo, _combo)


func get_combo() -> int:
	return _combo


func get_accuracy() -> float:
	return 0.0 if shots_fired <= 0 else float(shots_hit) / float(shots_fired) * 100.0


func get_player_speed() -> float:
	if _player == null or not is_instance_valid(_player):
		return 0.0
	return _player.linear_velocity.length()


func reset_stats() -> void:
	shots_fired = 0
	shots_hit = 0
	damage_dealt = 0
	current_streak = 0
	best_streak = 0
	best_combo = 0
	elapsed_time = 0.0
	_combo = 0
	_combo_timer = 0.0
	stats_changed.emit()


func reset_timer() -> void:
	elapsed_time = 0.0
	stats_changed.emit()


## Puts every station back on its blueprint mark at full health without
## disturbing the run's statistics.
func reset_dummies() -> void:
	for dummy in _dummies:
		if is_instance_valid(dummy):
			dummy.respawn()
	apply_dummy_config()


func get_dummies() -> Array[DummyBlob]:
	return _dummies
