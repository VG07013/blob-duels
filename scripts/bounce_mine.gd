extends RigidBody3D

const ABILITY_TUNING := preload("res://scripts/ability_tuning.gd")

signal detonated(world_position: Vector3)

var source: Node3D
var _armed := false
var _arm_timer := 0.0
var _lifetime := ABILITY_TUNING.BOUNCE_MINE_LIFETIME

@onready var trigger: Area3D = $Trigger
@onready var glow: OmniLight3D = $Glow


func _ready() -> void:
	trigger.body_entered.connect(_on_trigger_body_entered)


func configure(spawn_position: Vector3, direction: Vector3, mine_source: Node3D) -> void:
	global_position = spawn_position
	source = mine_source
	linear_velocity = direction.normalized() * 22.0 + Vector3.UP * 4.5


func _physics_process(delta: float) -> void:
	_lifetime -= delta
	if _lifetime <= 0.0 or global_position.y < -30.0:
		queue_free()
		return
	if not _armed and linear_velocity.length() < 3.0:
		_arm_timer += delta
		if _arm_timer >= ABILITY_TUNING.BOUNCE_MINE_ARM_DELAY:
			_armed = true
			glow.light_color = Color(1.0, 0.22, 0.04, 1.0)
			glow.light_energy = 2.2
	if _armed:
		glow.light_energy = 1.4 + sin(Time.get_ticks_msec() * 0.012) * 0.8


func _on_trigger_body_entered(body: Node3D) -> void:
	if not _armed or body == source:
		return
	if body.has_method("take_damage") or body.is_in_group("network_blob"):
		detonated.emit(global_position)
		queue_free()
