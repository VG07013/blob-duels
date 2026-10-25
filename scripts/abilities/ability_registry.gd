class_name AbilityRegistry
extends RefCounted

## The one list of abilities the game knows how to run. Shop entries, HUD art
## and audio cues key off the same ids (see progression_manager.gd,
## ui/ability_hud.gd and audio_manager.gd).

const DASH := preload("res://scripts/abilities/dash_ability.gd")
const RICOCHET := preload("res://scripts/abilities/ricochet_ability.gd")
const BLINK := preload("res://scripts/abilities/blink_ability.gd")
const SCANNER := preload("res://scripts/abilities/scanner_ability.gd")
const OVERCHARGE := preload("res://scripts/abilities/overcharge_ability.gd")
const GRAVITY_PULSE := preload("res://scripts/abilities/gravity_pulse_ability.gd")
const RAIL_SHOT := preload("res://scripts/abilities/rail_shot_ability.gd")
const BOUNCE_MINE := preload("res://scripts/abilities/bounce_mine_ability.gd")
const PHASE_BUBBLE := preload("res://scripts/abilities/phase_bubble_ability.gd")
const SHOCKWAVE := preload("res://scripts/abilities/shockwave_ability.gd")
const PASSIVE := preload("res://scripts/abilities/passive_ability.gd")

const PASSIVE_IDS: Array[String] = ["quick_charge", "adrenaline"]


static func ids() -> Array[String]:
	var result: Array[String] = ["dash", "ricochet_shot", "blink", "target_scanner", "overcharge", "gravity_pulse", "rail_shot", "bounce_mine", "phase_bubble", "shockwave"]
	result.append_array(PASSIVE_IDS)
	return result


## Abilities whose effect the host must apply for a remote peer.
static func host_validated_ids() -> Array[String]:
	var result: Array[String] = []
	for ability_id in ids():
		var ability := create(ability_id)
		if ability != null and ability.host_validated:
			result.append(ability_id)
	return result


static func create(ability_id: String) -> DuelAbility:
	match ability_id:
		"dash":
			return DASH.new()
		"ricochet_shot":
			return RICOCHET.new()
		"blink":
			return BLINK.new()
		"target_scanner":
			return SCANNER.new()
		"overcharge":
			return OVERCHARGE.new()
		"gravity_pulse":
			return GRAVITY_PULSE.new()
		"rail_shot":
			return RAIL_SHOT.new()
		"bounce_mine":
			return BOUNCE_MINE.new()
		"phase_bubble":
			return PHASE_BUBBLE.new()
		"shockwave":
			return SHOCKWAVE.new()
		_:
			if PASSIVE_IDS.has(ability_id):
				return PASSIVE.new(ability_id)
			return null
