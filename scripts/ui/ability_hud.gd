extends Control

const ICONS := {
	"dash": preload("res://assets/ui/abilities/dash.svg"),
	"ricochet_shot": preload("res://assets/ui/abilities/ricochet_shot.svg"),
	"quick_charge": preload("res://assets/ui/abilities/quick_charge.svg"),
	"blink": preload("res://assets/ui/abilities/blink.svg"),
	"target_scanner": preload("res://assets/ui/abilities/target_scanner.svg"),
	"overcharge": preload("res://assets/ui/abilities/overcharge.svg"),
	"gravity_pulse": preload("res://assets/ui/abilities/gravity_pulse.svg"),
	"rail_shot": preload("res://assets/ui/abilities/rail_shot.svg"),
	"bounce_mine": preload("res://assets/ui/abilities/bounce_mine.svg"),
	"phase_bubble": preload("res://assets/ui/abilities/phase_bubble.svg"),
	"adrenaline": preload("res://assets/ui/abilities/adrenaline.svg"),
}
const NAMES := {
	"dash": "DASH",
	"ricochet_shot": "RICOCHET SHOT",
	"quick_charge": "QUICK CHARGE",
	"blink": "BLINK",
	"target_scanner": "TARGET SCANNER",
	"overcharge": "OVERCHARGE",
	"gravity_pulse": "GRAVITY PULSE",
	"rail_shot": "RAIL SHOT",
	"bounce_mine": "BOUNCE MINE",
	"phase_bubble": "PHASE BUBBLE",
	"adrenaline": "ADRENALINE",
}
const COOLDOWNS := {
	"dash": 7000.0,
	"ricochet_shot": 10000.0,
	"blink": 18000.0,
	"target_scanner": 20000.0,
	"overcharge": 15000.0,
	"gravity_pulse": 16000.0,
	"rail_shot": 15000.0,
	"bounce_mine": 18000.0,
	"phase_bubble": 25000.0,
}
const COLORS := {
	"dash": Color("36c9ff"),
	"ricochet_shot": Color("ffb52e"),
	"quick_charge": Color("43e29c"),
	"blink": Color("a87bff"),
	"target_scanner": Color("ff5c82"),
	"overcharge": Color("ff7a35"),
	"gravity_pulse": Color("7788ff"),
	"rail_shot": Color("37e0cf"),
	"bounce_mine": Color("e2d843"),
	"phase_bubble": Color("5ac8fa"),
	"adrenaline": Color("ff4b58"),
}

@onready var icon: TextureRect = $Icon
@onready var cooldown: Label = $Cooldown
@onready var ability_name: Label = $AbilityName

var _ability_id := ""
var _progress := 1.0
var _unavailable := false
var _state_text := "READY"
var _was_ready := false
var _ready_tween: Tween


static func get_icon(ability_id: String) -> Texture2D:
	return ICONS.get(ability_id) as Texture2D


func set_ability_state(ability_id: String, cooldown_remaining_msec: int, loaded: bool, active: bool, active_remaining_msec: int = 0, deployed: bool = false) -> void:
	visible = not ability_id.is_empty()
	if ability_id.is_empty():
		_was_ready = false
		return
	_ability_id = ability_id
	icon.texture = ICONS.get(ability_id)
	ability_name.text = str(NAMES.get(ability_id, "ABILITY"))
	var passive := ability_id in ["quick_charge", "adrenaline"]
	var remaining := active_remaining_msec if active and active_remaining_msec > 0 else cooldown_remaining_msec
	var total := float(COOLDOWNS.get(ability_id, 1.0))
	_progress = 1.0 if passive or loaded or deployed else 1.0 - clampf(float(cooldown_remaining_msec) / total, 0.0, 1.0)
	_unavailable = active or loaded or deployed or cooldown_remaining_msec > 0
	icon.modulate = Color(0.72, 0.76, 0.84, 0.46) if _unavailable else Color.WHITE
	_state_text = "PASSIVE" if passive else ("LOADED" if loaded else ("DEPLOYED" if deployed else ("ACTIVE" if active else ("READY" if cooldown_remaining_msec <= 0 else "COOLDOWN"))))
	cooldown.visible = true
	cooldown.text = "%.1f" % (float(remaining) / 1000.0) if remaining > 0 and _unavailable else _state_text
	cooldown.add_theme_font_size_override("font_size", 20 if remaining > 0 and _unavailable else 12)
	var ready := not _unavailable and not passive and not loaded and not deployed
	if ready and not _was_ready:
		_animate_ready()
	_was_ready = ready
	queue_redraw()


func _draw() -> void:
	var diameter := minf(size.x, minf(size.y, 120.0))
	var center := Vector2(60.0, 60.0) if size.x >= 120.0 else size * 0.5
	var outer_radius := maxf(diameter * 0.433, 32.0)
	var ring_radius := outer_radius - 2.0
	var accent: Color = COLORS.get(_ability_id, Color("36c9ff"))
	var base := Color("111827") if not _unavailable else Color("242832")
	draw_circle(center, outer_radius, Color(0.015, 0.02, 0.035, 0.82))
	draw_circle(center, outer_radius - 4.0, base)
	if _unavailable:
		draw_circle(center, outer_radius * 0.46, Color(0.025, 0.03, 0.045, 0.72))
	var ring_color := accent if not _unavailable else accent.darkened(0.2)
	draw_arc(center, ring_radius, -PI * 0.5, -PI * 0.5 + TAU * _progress, 64, ring_color, 5.0, true)
	draw_arc(center, ring_radius - 6.0, 0.0, TAU, 64, Color(1, 1, 1, 0.1), 1.0, true)
	for index in 4:
		var angle := -PI * 0.5 + float(index) * PI * 0.5
		var inner := center + Vector2(cos(angle), sin(angle)) * (ring_radius - 3.0)
		var outer := center + Vector2(cos(angle), sin(angle)) * (ring_radius + 3.0)
		draw_line(inner, outer, Color(accent.r, accent.g, accent.b, 0.62), 2.0, true)


func _animate_ready() -> void:
	if _ready_tween != null and _ready_tween.is_valid():
		_ready_tween.kill()
	pivot_offset = size * 0.5
	scale = Vector2(0.84, 0.84)
	modulate = Color(0.72, 1.0, 0.92)
	_ready_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_ready_tween.set_parallel(true)
	_ready_tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_ready_tween.tween_property(self, "modulate", Color.WHITE, 0.3)
	_ready_tween.set_parallel(false)
	_ready_tween.tween_property(self, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
