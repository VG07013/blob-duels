class_name BotTuning
extends RefCounted

## Tuning for the offline bot opponent. Each difficulty is a full preset so a
## change to one level never leaks into another; behaviour code reads these,
## never inline numbers.

const DIFFICULTY_EASY := 0
const DIFFICULTY_NORMAL := 1
const DIFFICULTY_HARD := 2
const DIFFICULTY_IDS: Array[String] = ["easy", "normal", "hard"]
const DEFAULT_DIFFICULTY := DIFFICULTY_NORMAL

const BOT_DISPLAY_NAME := "Rival Bot"

## Seconds the bot must keep line of sight before it starts firing.
## Aim error is a cone half-angle in radians applied per shot.
## Blob behaviour: inside blob_ram_range (or when it flings) the bot swaps to
## the Blob slot and charges in to ram for blob_commit_seconds, then swaps
## back to the Blaster and waits blob_cooldown_seconds before ramming again.
## air_jump_skill is the chance it spends its air jump to swing back toward
## the target when a Blob flight is carrying it the wrong way.
## Fire interval is seconds between shots. Prediction is how much of the true
## intercept lead the bot uses (BotOpponent.predict_aim_point solves it from
## the target's velocity and the real shot speed): 0 aims at the body, 1 leads
## perfectly.
const PRESETS := {
	DIFFICULTY_EASY: {
		"reaction_seconds": 0.9,
		"aim_error_radians": 0.16,
		"fire_interval": 0.9,
		"prediction": 0.35,
		"engage_range": 26.0,
		"preferred_range": 12.0,
		"range_slack": 3.0,
		"max_accel": 34.0,
		"strafe_period": 2.4,
		"strafe_weight": 0.55,
		"bounce_chance_per_second": 0.25,
		"bounce_impulse": 40.0,
		"fling_interval": 6.5,
		"fling_strength": 110.0,
		"fling_min_distance": 14.0,
		"retreat_health_ratio": 0.25,
		"blob_ram_range": 10.0,
		"blob_commit_seconds": 1.8,
		"blob_cooldown_seconds": 5.0,
		"air_jump_skill": 0.25,
	},
	DIFFICULTY_NORMAL: {
		"reaction_seconds": 0.45,
		"aim_error_radians": 0.08,
		"fire_interval": 0.55,
		"prediction": 0.8,
		"engage_range": 32.0,
		"preferred_range": 10.0,
		"range_slack": 2.5,
		"max_accel": 48.0,
		"strafe_period": 1.6,
		"strafe_weight": 0.8,
		"bounce_chance_per_second": 0.6,
		"bounce_impulse": 48.0,
		"fling_interval": 4.0,
		"fling_strength": 150.0,
		"fling_min_distance": 11.0,
		"retreat_health_ratio": 0.35,
		"blob_ram_range": 14.0,
		"blob_commit_seconds": 2.4,
		"blob_cooldown_seconds": 3.2,
		"air_jump_skill": 0.65,
	},
	DIFFICULTY_HARD: {
		"reaction_seconds": 0.2,
		"aim_error_radians": 0.035,
		"fire_interval": 0.34,
		"prediction": 1.0,
		"engage_range": 40.0,
		"preferred_range": 9.0,
		"range_slack": 2.0,
		"max_accel": 62.0,
		"strafe_period": 1.1,
		"strafe_weight": 1.0,
		"bounce_chance_per_second": 1.1,
		"bounce_impulse": 54.0,
		"fling_interval": 2.6,
		"fling_strength": 190.0,
		"fling_min_distance": 9.0,
		"retreat_health_ratio": 0.4,
		"blob_ram_range": 18.0,
		"blob_commit_seconds": 3.0,
		"blob_cooldown_seconds": 2.0,
		"air_jump_skill": 1.0,
	},
}

## Shots leave from the same muzzle offset the player uses, so the bot cannot
## fire through cover a player could not.
const SHOT_MUZZLE_OFFSET := 3.75
const SHOT_MUZZLE_HEIGHT := 0.25
## How far ahead along its velocity the bot looks before steering away from a
## drop.
const EDGE_LOOKAHEAD_SECONDS := 0.6
const EDGE_ESCAPE_ACCEL_MULTIPLIER := 2.0
## Distance of the point the bot steers toward each frame; only the direction
## matters, this keeps the proportional steering saturated.
const STEER_POINT_DISTANCE := 6.0
## World collision layer used for line-of-sight checks.
const LINE_OF_SIGHT_MASK := 1
const FLING_UPWARD_ASSIST := 0.12
## An airborne Blob bot whose heading points this far off the target (dot of
## flight direction and direction to target) considers an air-jump redirect.
const AIR_JUMP_REDIRECT_DOT := 0.55
## Seconds of flight before it decides, so a jump is not burned on takeoff.
const AIR_JUMP_MIN_AIRTIME := 0.18


static func preset_for(difficulty: int) -> Dictionary:
	return PRESETS.get(clampi(difficulty, DIFFICULTY_EASY, DIFFICULTY_HARD), PRESETS[DEFAULT_DIFFICULTY])


static func difficulty_from_id(difficulty_id: String) -> int:
	var index := DIFFICULTY_IDS.find(difficulty_id)
	return index if index >= 0 else DEFAULT_DIFFICULTY
