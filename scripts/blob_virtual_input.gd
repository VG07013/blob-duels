class_name BlobVirtualInput
extends RefCounted

## A controller a script can hold instead of a human: the same actions and
## movement axis BlobPlayer reads from the Input singleton, fed by code. When a
## blob has one (`BlobPlayer.virtual_input`), every input read goes here, so a
## bot drives the exact movement code a player does - ramp-up, bounce buffer,
## coyote time, fling charge, power slide - instead of pushing the body with
## raw forces. Press / release edges persist until the body's next physics
## step consumes them (`end_frame`), so a one-tick tap is never lost to
## process ordering.

## Movement axis in the blob's aim frame: x right, y back (as Input.get_vector
## with move_left/right/forward/back returns it).
var move := Vector2.ZERO
var _held: Dictionary = {}
var _pressed: Dictionary = {}
var _released: Dictionary = {}


func press(action: StringName) -> void:
	if not bool(_held.get(action, false)):
		_pressed[action] = true
	_held[action] = true


func release(action: StringName) -> void:
	if bool(_held.get(action, false)):
		_released[action] = true
	_held[action] = false


## Holds or releases, whichever `held` asks for; edges fire only on change.
func set_held(action: StringName, held: bool) -> void:
	if held:
		press(action)
	else:
		release(action)


## A press and release in the same frame: the body sees both edges once.
func tap(action: StringName) -> void:
	_pressed[action] = true
	_released[action] = true
	_held[action] = false


func is_pressed(action: StringName) -> bool:
	return bool(_held.get(action, false))


func is_just_pressed(action: StringName) -> bool:
	return bool(_pressed.get(action, false))


func is_just_released(action: StringName) -> bool:
	return bool(_released.get(action, false))


## Called by the body once it has read this frame's input.
func end_frame() -> void:
	_pressed.clear()
	_released.clear()


func clear() -> void:
	move = Vector2.ZERO
	_held.clear()
	_pressed.clear()
	_released.clear()
