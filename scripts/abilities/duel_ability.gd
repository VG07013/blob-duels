class_name DuelAbility
extends RefCounted

## One equippable ability.
##
## Two paths live here. The local path (`activate` / `tick` / `expire` /
## `interrupt`) runs on the blob that pressed the key and drives the HUD. The
## host path (`server_allowed` / `server_activate`) applies a remote peer's
## request against its `ServerPeerState`, which is the only state the host
## trusts. Adding an ability means one subclass plus a registry entry; game.gd
## never learns the ability's name.
##
## `game` is the running `scripts/game.gd` node. It is typed as Node because
## game.gd has no class_name, so subclasses reach its helpers by name.

const ABILITY_TUNING := preload("res://scripts/ability_tuning.gd")

var id := ""
## Time between the ability ending and it being usable again.
var cooldown_msec := 0
## Length of the active window, 0 for instant abilities.
var duration_msec := 0
## Online clients must ask the host before this ability takes effect.
var host_validated := false
## Passive abilities never activate; pressing the key only plays a cue.
var passive := false

## Earliest tick the ability may activate again.
var ready_at := 0
## End of the current active window, 0 while inactive.
var end_at := 0


## Runs the ability on the local blob. Returns false when nothing happened, in
## which case no cooldown starts, no sound plays and no stat is recorded.
func activate(_game: Node, _now: int) -> bool:
	return false


## Called every frame while the active window is open.
func tick(_game: Node, _now: int, _delta: float) -> void:
	pass


## Called once when the active window closes on its own.
func expire(_game: Node, now: int) -> void:
	end_at = 0
	ready_at = now + cooldown_msec


## Called when the blob is knocked out or the ability is swapped mid-match.
## Timed abilities fall back to a normal expiry; instant ones have nothing to
## clean up.
func interrupt(game: Node, now: int) -> void:
	if end_at > 0:
		expire(game, now)


## Clears every timer for a fresh match. Cooldowns are forgiven, not served.
func reset(_game: Node) -> void:
	ready_at = 0
	end_at = 0


func is_active(now: int) -> bool:
	return end_at > now


func active_remaining(now: int) -> int:
	return maxi(end_at - now, 0)


func cooldown_remaining(now: int) -> int:
	return maxi(ready_at - now, 0)


## True while an armed one-shot (ricochet) is waiting to be spent.
func is_loaded() -> bool:
	return false


## True while a placed object (bounce mine) is still live in the arena.
func is_deployed(_game: Node) -> bool:
	return false


## Rail Shot holds the trigger while it charges; nothing else does.
func locks_shooting(_now: int) -> bool:
	return false


## Host-side gate for a remote peer's request. Subclasses add their own rules on
## top of "equipped and off cooldown".
func server_allowed(state: ServerPeerState, now: int) -> bool:
	return state.equipped_ability == id and now >= state.ability_ready_at


## Host-side application of a validated remote request. Returns false when the
## ability has no host path, which `_request_network_ability` treats as a
## rejected request.
func server_activate(_game: Node, _peer_id: int, _state: ServerPeerState, _now: int) -> bool:
	return false


func begin_window(now: int) -> void:
	end_at = now + duration_msec


## Direction the blob is travelling, or facing when it is still. Shared by the
## movement abilities so a stationary dash and a moving dash feel the same.
static func travel_direction(game: Node, minimum_speed_squared: float = 0.5) -> Vector3:
	var direction: Vector3 = game.player.linear_velocity
	direction.y = 0.0
	if direction.length_squared() <= minimum_speed_squared:
		direction = game.player.aim_direction
		direction.y = 0.0
	return direction.normalized() if direction.length_squared() > 0.001 else Vector3.FORWARD


static func is_online_client(game: Node) -> bool:
	return game.network_session.is_online() and not game.multiplayer.is_server()


static func is_online_host(game: Node) -> bool:
	return game.network_session.is_online() and game.multiplayer.is_server()
