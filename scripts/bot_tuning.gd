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

## The bot drives its body through BlobVirtualInput, so every number here is
## about decisions, not forces: the body's own movement tuning does the rest.
##
## reaction_seconds: line of sight the bot needs before it opens fire.
## aim_error_radians: cone half-angle applied per shot.
## fire_interval: seconds between shots (jittered ±15%).
## prediction: share of the true intercept lead it uses (0 body, 1 perfect).
## engage_range / preferred_range / range_slack: the band it fights from.
## turn_speed: how fast (rad/s) it swings its facing onto the target.
## strafe_period / strafe_weight: how often it reverses its circle and how
## much of its movement is sideways while engaging.
## bounce_chance_per_second: idle hops while grounded.
## fling_interval / fling_min_distance / fling_charge_seconds: how often it
## charges a fling at a distant target, and how long it holds the charge.
## retreat_health_ratio: below this share of health it kites instead.
## Blob: inside blob_ram_range it swaps to the Blob and rams for
## blob_commit_seconds, then waits blob_cooldown_seconds. air_jump_skill is
## the chance it spends the air jump to swing a wide flight back on target.
## dodge_skill: chance it sidesteps (or hops over) a shot it sees coming.
## slide_skill: chance per second it power slides to close a long gap.
## slam_skill: chance it drops a slam when it is above a close target.
const PRESETS := {
	DIFFICULTY_EASY: {
		"reaction_seconds": 0.9,
		"aim_error_radians": 0.16,
		"fire_interval": 0.9,
		"prediction": 0.35,
		"engage_range": 26.0,
		"preferred_range": 12.0,
		"range_slack": 3.0,
		"turn_speed": 4.0,
		"strafe_period": 2.4,
		"strafe_weight": 0.55,
		"bounce_chance_per_second": 0.25,
		"fling_interval": 6.5,
		"fling_min_distance": 14.0,
		"fling_charge_seconds": 0.35,
		"retreat_health_ratio": 0.25,
		"blob_ram_range": 10.0,
		"blob_commit_seconds": 1.8,
		"blob_cooldown_seconds": 5.0,
		"air_jump_skill": 0.25,
		"dodge_skill": 0.2,
		"slide_skill": 0.1,
		"slam_skill": 0.0,
	},
	DIFFICULTY_NORMAL: {
		"reaction_seconds": 0.45,
		"aim_error_radians": 0.08,
		"fire_interval": 0.55,
		"prediction": 0.8,
		"engage_range": 32.0,
		"preferred_range": 10.0,
		"range_slack": 2.5,
		"turn_speed": 7.0,
		"strafe_period": 1.6,
		"strafe_weight": 0.8,
		"bounce_chance_per_second": 0.6,
		"fling_interval": 4.0,
		"fling_min_distance": 11.0,
		"fling_charge_seconds": 0.6,
		"retreat_health_ratio": 0.35,
		"blob_ram_range": 14.0,
		"blob_commit_seconds": 2.4,
		"blob_cooldown_seconds": 3.2,
		"air_jump_skill": 0.65,
		"dodge_skill": 0.55,
		"slide_skill": 0.5,
		"slam_skill": 0.35,
	},
	DIFFICULTY_HARD: {
		"reaction_seconds": 0.2,
		"aim_error_radians": 0.035,
		"fire_interval": 0.34,
		"prediction": 1.0,
		"engage_range": 40.0,
		"preferred_range": 9.0,
		"range_slack": 2.0,
		"turn_speed": 12.0,
		"strafe_period": 1.1,
		"strafe_weight": 1.0,
		"bounce_chance_per_second": 1.1,
		"fling_interval": 2.6,
		"fling_min_distance": 9.0,
		"fling_charge_seconds": 0.9,
		"retreat_health_ratio": 0.4,
		"blob_ram_range": 18.0,
		"blob_commit_seconds": 3.0,
		"blob_cooldown_seconds": 2.0,
		"air_jump_skill": 1.0,
		"dodge_skill": 0.9,
		"slide_skill": 0.9,
		"slam_skill": 0.8,
	},
}

## Shots leave from the same muzzle offset the player uses, so the bot cannot
## fire through cover a player could not.
const SHOT_MUZZLE_OFFSET := 3.75
const SHOT_MUZZLE_HEIGHT := 0.25
## How far ahead along its velocity the bot looks before steering away from a
## drop, and the speed above which it also brakes to stop in time.
const EDGE_LOOKAHEAD_SECONDS := 0.6
const EDGE_BRAKE_SPEED := 20.0
## World collision layer used for line-of-sight and obstacle probes.
const LINE_OF_SIGHT_MASK := 1
## Horizontal probe for a wall in the way of the chosen heading; a hit while
## grounded means hop, a hit while airborne means a wall kick is available.
const OBSTACLE_PROBE_DISTANCE := 7.0
const WALL_KICK_PROBE_DISTANCE := 2.6
## Seconds without sight before the bot stops orbiting and goes looking.
const LOST_SIGHT_CHASE_SECONDS := 0.3
## Incoming shots: how far ahead the bot projects them and how close a pass
## counts as a threat worth dodging. A dodge is a short committed sidestep.
const THREAT_LOOKAHEAD_SECONDS := 0.7
const THREAT_MISS_DISTANCE := 5.0
const DODGE_SECONDS := 0.35
const DODGE_HOP_CHANCE := 0.5
## Slam only when it is this far above a target this close.
const SLAM_MIN_HEIGHT_ABOVE := 5.0
const SLAM_MAX_FLAT_DISTANCE := 7.0
const SLAM_BRAKE_HOLD_SECONDS := 0.3
## Power slide only when the gap is long enough to be worth it.
const SLIDE_MIN_DISTANCE := 22.0
const SLIDE_HOLD_SECONDS := 1.0
## Minimum seconds between deliberate hops, so the bot never pogo-sticks.
const HOP_COOLDOWN_SECONDS := 0.5
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
