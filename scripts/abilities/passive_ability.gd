class_name PassiveAbility
extends DuelAbility

## Adrenaline and Quick Charge live on the player script as permanent
## modifiers. Pressing the key only acknowledges that.


func _init(passive_id: String) -> void:
	id = passive_id
	passive = true
