extends Area3D

@export var launch_impulse := 34.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body.has_method("apply_bounce_pad"):
		body.call("apply_bounce_pad", launch_impulse)
