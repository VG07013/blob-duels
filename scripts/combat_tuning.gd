class_name CombatTuning
extends RefCounted

## Tuning for the core duel loop: the two-slot hotbar, shot damage falloff,
## aim-in, hit flex, and how the bot leads its shots. Ability numbers stay in
## ability_tuning.gd; this file is everything a blob can do without one.

## Hotbar slots. Slot 1 shoots; slot 2 turns the blob itself into the weapon.
const SLOT_BLASTER := 0
const SLOT_BLOB := 1
const SLOT_COUNT := 2
const SLOT_NAMES := ["Blaster", "Blob"]
## Quick blob (F): the Blob slot is equipped for this long, then the hotbar
## snaps back to the Blaster.
const QUICK_BLOB_SECONDS := 0.5

## Juggle protection for hits (shots and body slams). Hits within
## HIT_CHAIN_WINDOW of the last one form a chain; each link scales knockback by
## HIT_CHAIN_FALLOFF, never below HIT_CHAIN_MIN_SCALE. A stream of shots must
## never lift a blob more than HIT_JUGGLE_MAX_HEIGHT units (hit_juggle_contract).
const HIT_CHAIN_WINDOW := 0.9
const HIT_CHAIN_FALLOFF := 0.75
const HIT_CHAIN_MIN_SCALE := 0.35
const HIT_JUGGLE_MAX_HEIGHT := 12.0

## Blob slot: faster rolling, a quicker fling charge, harder rams, and one
## redirecting air jump per airtime. Shooting is off while it is held.
const BLOB_SPEED_MULTIPLIER := 1.25
const BLOB_CHARGE_RATE_MULTIPLIER := 1.6
const BLOB_RAM_DAMAGE_MULTIPLIER := 1.5
## Air jump: the blob keeps its planar speed but swings it onto the held
## movement direction, and gets this much upward speed.
const BLOB_AIR_JUMP_UP_SPEED := 22.0
## Planar speed an air jump guarantees even from a near standstill, so a
## redirect always goes somewhere.
const BLOB_AIR_JUMP_MIN_PLANAR_SPEED := 18.0
const BLOB_AIR_JUMPS := 1

## Shot damage and knockback fall off with distance travelled: full strength
## up to FALLOFF_START, easing linearly to FALLOFF_MIN_RATIO at FALLOFF_END and
## flat beyond it.
const SHOT_FALLOFF_START := 20.0
const SHOT_FALLOFF_END := 80.0
const SHOT_FALLOFF_MIN_RATIO := 0.45

## Aim-in (right click / left trigger): tighter view and slower look.
const AIM_FOV_MULTIPLIER := 0.72
const AIM_SENSITIVITY_MULTIPLIER := 0.62
const AIM_BLEND_SPEED := 14.0

## Hit flex: a damped spring on the blob's visual (body and face together)
## that dents it along the hit direction, bulges it sideways and leans it with
## the push, then jiggles back. A kick is the peak dent it produces: a full
## blaster hit (~160 impulse) reaches the cap. Low damping on purpose, so the
## wobble rings for about a second and actually reads at duel distance.
const FLEX_STIFFNESS := 120.0
const FLEX_DAMPING := 4.0
const FLEX_KICK_PER_IMPULSE := 0.0028
const FLEX_MAX_KICK := 0.45
const FLEX_MAX_DENT := 0.4
const FLEX_MAX_LEAN := 0.5
const FLEX_LEAN_PER_DENT := 1.2

## Hit flash: on taking damage the body tints red and a bright red outline
## pops around it, both fading out over HIT_FLASH_SECONDS.
const HIT_FLASH_SECONDS := 0.18
const HIT_FLASH_COLOR := Color(1.0, 0.08, 0.06)
const HIT_FLASH_TINT_ALPHA := 0.65
const HIT_FLASH_OUTLINE_SCALE := 1.1


## Damage/knockback multiplier for a shot that has flown `distance` units.
static func shot_falloff(distance: float) -> float:
	if distance <= SHOT_FALLOFF_START:
		return 1.0
	var t := clampf((distance - SHOT_FALLOFF_START) / (SHOT_FALLOFF_END - SHOT_FALLOFF_START), 0.0, 1.0)
	return lerpf(1.0, SHOT_FALLOFF_MIN_RATIO, t)


## Earliest time a shot fired from `origin` at `shot_speed` can meet a target
## at `target_position` moving at constant `target_velocity`, or -1 when it
## can never catch it. Standard intercept: |P + V t| = s t.
static func intercept_time(origin: Vector3, target_position: Vector3, target_velocity: Vector3, shot_speed: float) -> float:
	var offset := target_position - origin
	var a := target_velocity.dot(target_velocity) - shot_speed * shot_speed
	var b := 2.0 * offset.dot(target_velocity)
	var c := offset.dot(offset)
	if absf(a) < 0.0001:
		return -c / b if b < 0.0 else -1.0
	var discriminant := b * b - 4.0 * a * c
	if discriminant < 0.0:
		return -1.0
	var root := sqrt(discriminant)
	var best := INF
	for candidate in [(-b - root) / (2.0 * a), (-b + root) / (2.0 * a)]:
		if candidate > 0.0 and candidate < best:
			best = candidate
	return best if best < INF else -1.0
