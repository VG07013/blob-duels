class_name PracticeTraining
extends RefCounted

## Tuning tables for the practice training grounds - dummy behaviour modes,
## health presets, and the movement envelopes each mode is allowed to use.
## Pure data: no nodes, no engine calls, so contracts can read it headless.
##
## Distances are quoted in grid units (GU) to stay in the blueprint's language;
## the geometry module owns the GU -> world conversion.

const GEOMETRY := preload("res://scripts/environment/practice_facility_geometry.gd")

const GU := GEOMETRY.GU

## Behaviour modes -------------------------------------------------------------
## Static is the default: a dummy the player has not configured must hold still.
const MODE_STATIC := 0
const MODE_STRAFE := 1
const MODE_BOUNCE := 2
const MODE_DODGE := 3
const MODE_COMBAT := 4

const MODE_IDS: Array[int] = [MODE_STATIC, MODE_STRAFE, MODE_BOUNCE, MODE_DODGE, MODE_COMBAT]
const MODE_LABELS: Array[String] = ["Static", "Strafe", "Bounce", "Dodge", "Combat"]
const DEFAULT_MODE := MODE_STATIC

## Health presets ---------------------------------------------------------------
## -1 is the infinite sentinel and the default: training never stops for a
## respawn unless the player deliberately asks for a finite health pool.
const HEALTH_INFINITE := -1
const HEALTH_ONE_HIT := 1
const HEALTH_PRESETS: Array[int] = [HEALTH_INFINITE, 100, 250, 500, HEALTH_ONE_HIT]
const HEALTH_LABELS: Array[String] = ["Infinite", "100 HP", "250 HP", "500 HP", "One-hit"]
const DEFAULT_HEALTH := HEALTH_INFINITE
## Spec: a defeated dummy returns to its own station 1.5s later at full health.
const RESPAWN_DELAY := 1.5

## Movement speed dial ----------------------------------------------------------
const SPEED_SCALES: Array[float] = [0.5, 0.75, 1.0, 1.5, 2.0]
const SPEED_LABELS: Array[String] = ["Slow", "Relaxed", "Normal", "Fast", "Blitz"]
const DEFAULT_SPEED_SCALE := 1.0

## Strafe: a ~3 GU lane walked at medium speed, easing through each turn so the
## direction change reads as a slide rather than a snap.
const STRAFE_LANE_LENGTH := 3.0 * GU
const STRAFE_HALF_LANE := STRAFE_LANE_LENGTH * 0.5
const STRAFE_PERIOD := 3.4
const STRAFE_ACCEL := 46.0

## Bounce: repeated controlled hops that stay inside a 2.5 GU bubble around the
## station, for vertical tracking practice. The hop sets vertical speed outright
## instead of adding an impulse - the dummy's 0.94 bounce material would
## otherwise compound each hop into a launch.
const BOUNCE_LEASH := 2.5 * GU
const BOUNCE_INTERVAL := 1.05
## ~10.6 u/s peaks a shade under one blob diameter of rise at 9.8 gravity:
## readable vertical tracking, never a ceiling shot.
const BOUNCE_HOP_SPEED := 10.6
const BOUNCE_RECENTER_ACCEL := 26.0

## Dodge: only fires after the player holds a direct aim, then commits to one
## short sideways hop and goes quiet for the cooldown - never a constant jitter.
const DODGE_AIM_DOT := 0.984
const DODGE_AIM_DWELL := 0.45
const DODGE_COOLDOWN := 1.7
## Roughly a half-lane sidestep on the 3.2 mass dummy - enough to break a
## locked crosshair, short enough to stay a predictable tell.
const DODGE_IMPULSE := 26.0
const DODGE_LEASH := 2.0 * GU

## Combat: slow, readable return fire so the player can practise moving under
## pressure. Damage is off by default - the toggle lives on the practice panel.
const COMBAT_FIRE_INTERVAL := 1.6
const COMBAT_RANGE := 34.0 * GU
const COMBAT_AIM_SPREAD := 0.055
const COMBAT_MUZZLE_OFFSET := 3.75


static func mode_label(mode: int) -> String:
	return MODE_LABELS[mode] if mode >= 0 and mode < MODE_LABELS.size() else MODE_LABELS[DEFAULT_MODE]


static func health_label(preset: int) -> String:
	var index := HEALTH_PRESETS.find(preset)
	return HEALTH_LABELS[index] if index >= 0 else HEALTH_LABELS[0]


static func speed_label(scale: float) -> String:
	for index in range(SPEED_SCALES.size()):
		if is_equal_approx(SPEED_SCALES[index], scale):
			return SPEED_LABELS[index]
	return "%.2fx" % scale


## Health a dummy should carry for a preset. Infinite still needs a positive
## pool so the nameplate bar has something to draw.
static func health_pool_for(preset: int) -> int:
	if preset == HEALTH_INFINITE:
		return 500
	return maxi(preset, 1)
