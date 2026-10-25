class_name VictoryDirector
extends RefCounted

## The match-end cinematic. game.gd hands over the moment a duel is decided:
## the camera cuts to the winner on its own spawn deck, a scripted celebration
## plays through the blob's VisualRoot (never its body), the camera pushes in
## and drifts along a line that was checked clear of scenery, and the results
## screen follows VICTORY_RESULTS_DELAY later. `active` is the one flag every
## input, camera and cursor path in game.gd consults while this owns the screen.

## Victory staging: the winner celebrates on its own spawn deck (always open
## floor on every map) and the camera searches for a clear line to it instead
## of using one fixed world point that sat inside scenery on several maps.
const VICTORY_CAMERA_DISTANCE := 17.0
const VICTORY_CAMERA_MIN_DISTANCE := 8.0
const VICTORY_CAMERA_HEIGHT := 5.5
const VICTORY_CAMERA_CLEARANCE := 1.1
const VICTORY_CAMERA_ANGLES_DEGREES := [0.0, 30.0, -30.0, 60.0, -60.0, 90.0, -90.0, 135.0, -135.0, 180.0]
## Celebration choreography, in seconds from the moment the camera cuts to
## the winner: [takeoff, airtime, apex height, full spins]. The first leap is
## the big one; after the last scripted hop the blob keeps an idle bounce going
## under the results screen.
const VICTORY_HOPS := [[0.3, 0.74, 4.6, 1.0], [1.26, 0.42, 2.1, 0.0], [1.86, 0.34, 1.1, 0.0]]
const VICTORY_IDLE_START := 2.9
const VICTORY_IDLE_PERIOD := 1.25
const VICTORY_IDLE_AIRTIME := 0.4
const VICTORY_IDLE_HEIGHT := 0.85
## Crouch before a hop and the squash-jiggle after landing.
const VICTORY_ANTICIPATION_TIME := 0.22
const VICTORY_ANTICIPATION_SQUASH := 0.3
const VICTORY_LANDING_SQUASH := 0.34
const VICTORY_TAKEOFF_STRETCH := 0.2
## Camera: starts high and wide, pushes in and drifts round the winner.
const VICTORY_CAMERA_PUSH_TIME := 2.6
const VICTORY_CAMERA_PUSH := 0.86
## Share of the blob's hop height the camera tilts up to follow.
const VICTORY_CAMERA_FOLLOW := 0.5
const VICTORY_CAMERA_RISE := 2.6
const VICTORY_CAMERA_ORBIT_DEGREES := 11.0
const VICTORY_CAMERA_ORBIT_SPEED := 0.32
const VICTORY_CAMERA_FOV_START := 66.0
const VICTORY_CAMERA_FOV_END := 56.0
## When the results UI slides in, relative to the camera cut.
const VICTORY_RESULTS_DELAY := 2.35
const VICTORY_TARGET_LIFT := 1.2
const VICTORY_FLOOR_PROBE_UP := 6.0
const VICTORY_FLOOR_PROBE_DOWN := 40.0
## World and scenery collision layers the camera must not sit inside.
const VICTORY_CAMERA_MASK := 1 | 8

var game: DuelGame
## True from the camera cut until a rematch or the lobby cancels the sequence.
var active := false
## Seconds since the camera cut; every pose and camera value is a function of it.
var elapsed := 0.0
var _camera_target := Vector3(0.0, 3.2, 0.0)
var _camera_position := Vector3(22.0, 8.0, 28.0)
var _blob: RigidBody3D
var _stage := Vector3.ZERO


func setup(owner_game: DuelGame) -> void:
	game = owner_game


func start(winning_team: int) -> void:
	if active or not game.arena_started:
		return
	active = true
	game._match_timer_running = false
	game.player.set_input_enabled(false)
	game.player.set_shooting_enabled(false)
	game.player.freeze = true
	for remote in game.remote_players.get_children():
		(remote as RigidBody3D).freeze = true
	game.pause_menu.close_pause()
	game.get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	game._set_player_mesh_visible(true)
	var local_team := game._team_for_peer(game.local_peer_id)
	var winner_body: RigidBody3D = game._body_for_team(winning_team)
	var winner_name := str(winner_body.get("display_name")) if winner_body != null else ""
	game.hud.begin_victory_cinematic(winner_name, DuelGame.RED_TEAM_COLOR if winning_team == DuelGame.TEAM_RED else DuelGame.BLUE_TEAM_COLOR, local_team == winning_team)
	game.audio_manager.stop_all_loops(0.18, true)
	game.audio_manager.set_music_context(&"victory" if local_team == winning_team else &"defeat", 0.75)
	var stage := _stage_position(winning_team, winner_body)
	_camera_target = stage + Vector3.UP * VICTORY_TARGET_LIFT
	_camera_position = _camera_spot(winning_team, _camera_target)
	elapsed = 0.0
	# Cut straight to the shot: easing in from the duel camera could sweep
	# through walls on the way. The push-in only ever moves closer along the
	# cleared line, so it cannot clip either.
	_update_camera()
	game.camera.position = Vector3.ZERO
	if winner_body != null:
		_begin_pose(winner_body, stage)
	game.audio_manager.play_sfx(&"round_start", -5.0, 0.84)
	_schedule_landing_effects(winning_team)
	await game.get_tree().create_timer(VICTORY_RESULTS_DELAY).timeout
	if not active:
		return
	var is_winner := local_team == winning_team
	game.hud.show_victory(is_winner, winning_team, game._build_match_roster())
	game._award_local_match_rewards(winning_team)
	var result_sound: StringName = &"victory_reveal" if is_winner else &"defeat_reveal"
	game.audio_manager.play_sfx(result_sound, -1.0, 1.0 if is_winner else 0.82)
	await game.get_tree().create_timer(1.35).timeout
	if active:
		game.audio_manager.play_sfx(&"roster_reveal", -7.0, 1.08)


## One frame of the celebration; game.gd calls it instead of its duel camera.
func process(delta: float) -> void:
	elapsed += delta
	_update_pose()
	_update_camera()


## Rematch or lobby: stop the sequence and hand the winner back to physics.
func cancel() -> void:
	active = false
	end_pose()


## Hands the winner's look back to physics (rematch, lobby).
func end_pose() -> void:
	if _blob != null and is_instance_valid(_blob):
		var visual := _blob.get_node_or_null("VisualRoot") as BlobVisual
		if visual != null:
			visual.set_celebration_pose(0.0, 0.0)
	_blob = null


## Starts high and wide on the cleared line, pushes in, and drifts slowly
## round the winner. `_camera_position` is the far end of the clear line, so
## every point used here is at or inside it.
func _update_camera() -> void:
	var push := _ease_out_cubic(clampf(elapsed / VICTORY_CAMERA_PUSH_TIME, 0.0, 1.0))
	var offset := _camera_position - _camera_target
	var orbit := sin(elapsed * VICTORY_CAMERA_ORBIT_SPEED) * deg_to_rad(VICTORY_CAMERA_ORBIT_DEGREES)
	var distance_scale := lerpf(1.0, VICTORY_CAMERA_PUSH, push)
	var rise := lerpf(VICTORY_CAMERA_RISE, 0.0, push)
	game.camera_rig.global_position = _camera_target + offset.rotated(Vector3.UP, orbit) * distance_scale + Vector3.UP * rise
	var follow := pose_at(elapsed).x * VICTORY_CAMERA_FOLLOW if _blob != null else 0.0
	game.camera_rig.look_at(_camera_target + Vector3.UP * follow, Vector3.UP)
	game.camera.position = Vector3.ZERO
	game.camera.fov = lerpf(VICTORY_CAMERA_FOV_START, VICTORY_CAMERA_FOV_END, push)


static func _ease_out_cubic(value: float) -> float:
	return 1.0 - pow(1.0 - value, 3.0)


## Plants the winner on its stage facing the camera; `_update_pose` then plays
## the celebration every frame from `elapsed`.
func _begin_pose(blob: RigidBody3D, stage: Vector3) -> void:
	_blob = blob
	_stage = stage
	blob.global_position = stage
	blob.linear_velocity = Vector3.ZERO
	blob.angular_velocity = Vector3.ZERO
	var look_direction := _camera_position - stage
	look_direction.y = 0.0
	look_direction = look_direction.normalized() if look_direction.length_squared() > 0.001 else Vector3.FORWARD
	blob.set("aim_direction", look_direction)
	blob.set("aim_yaw", atan2(-look_direction.x, -look_direction.z))
	_update_pose()


func _update_pose() -> void:
	if _blob == null or not is_instance_valid(_blob):
		return
	var pose := pose_at(elapsed)
	_blob.global_position = _stage + Vector3.UP * pose.x
	var visual := _blob.get_node_or_null("VisualRoot") as BlobVisual
	if visual != null:
		visual.set_celebration_pose(pose.y, pose.z)


## Height above the stage (x), squash (y, negative = stretch) and spin (z) at
## time `t`: the scripted hops, then an endless idle bounce.
static func pose_at(t: float) -> Vector3:
	var hops: Array = VICTORY_HOPS.duplicate()
	if t >= VICTORY_IDLE_START - VICTORY_ANTICIPATION_TIME:
		var index := maxi(0, int(floor((t - VICTORY_IDLE_START) / VICTORY_IDLE_PERIOD)))
		for extra in [index, index + 1]:
			hops.append([VICTORY_IDLE_START + extra * VICTORY_IDLE_PERIOD, VICTORY_IDLE_AIRTIME, VICTORY_IDLE_HEIGHT, 0.0])
	var peak := float((VICTORY_HOPS[0] as Array)[2])
	var last_landing := -100.0
	var last_strength := 0.0
	for hop_value in hops:
		var hop := hop_value as Array
		var takeoff := float(hop[0])
		var airtime := float(hop[1])
		var strength := float(hop[2]) / peak
		if t < takeoff:
			var crouch := 0.0
			var lead := takeoff - t
			if lead < VICTORY_ANTICIPATION_TIME:
				crouch = VICTORY_ANTICIPATION_SQUASH * sqrt(strength) * sin((1.0 - lead / VICTORY_ANTICIPATION_TIME) * PI * 0.5)
			return Vector3(0.0, maxf(crouch, _landing_squash(t - last_landing, last_strength)), 0.0)
		if t < takeoff + airtime:
			var u := (t - takeoff) / airtime
			var height := float(hop[2]) * 4.0 * u * (1.0 - u)
			# Stretched while moving fast (takeoff and fall), round at the apex.
			var stretch := -VICTORY_TAKEOFF_STRETCH * sqrt(strength) * absf(1.0 - 2.0 * u)
			var spin := TAU * float(hop[3]) * smoothstep(0.0, 1.0, u)
			return Vector3(height, stretch, spin)
		last_landing = takeoff + airtime
		last_strength = strength
	return Vector3(0.0, _landing_squash(t - last_landing, last_strength), 0.0)


## A damped jiggle after touchdown: flat first, then a small tall rebound.
static func _landing_squash(since_landing: float, strength: float) -> float:
	if since_landing < 0.0 or since_landing > 0.9:
		return 0.0
	return VICTORY_LANDING_SQUASH * sqrt(strength) * exp(-6.5 * since_landing) * cos(since_landing * 17.0)


## Dust, sound and a small camera kick on each scripted landing.
func _schedule_landing_effects(winning_team: int) -> void:
	var accent := DuelGame.RED_TEAM_COLOR if winning_team == DuelGame.TEAM_RED else DuelGame.BLUE_TEAM_COLOR
	for index in VICTORY_HOPS.size():
		var hop := VICTORY_HOPS[index] as Array
		var takeoff := float(hop[0])
		var landing := takeoff + float(hop[1])
		var strength := float(hop[2]) / float((VICTORY_HOPS[0] as Array)[2])
		game.get_tree().create_timer(takeoff).timeout.connect(func() -> void:
			if active:
				game.audio_manager.play_sfx(&"jump", -6.0 + strength * 3.0, 1.0 + (1.0 - strength) * 0.25)
		)
		game.get_tree().create_timer(landing).timeout.connect(func() -> void:
			if not active:
				return
			game.audio_manager.play_sfx(&"land", -4.0 + strength * 4.0, 0.95)
			game._spawn_impact_burst(_stage, accent, 0.8 + strength * 1.1)
			if index == 0:
				game._spawn_impact_burst(_stage + Vector3.UP * 1.4, Color(1.0, 0.86, 0.35), 1.2)
		)


## The winner's own spawn deck, resting on whatever floor is under it.
func _stage_position(winning_team: int, winner_body: Node3D) -> Vector3:
	var slot := _stage_slot(winning_team)
	var spawn: Vector3 = game.spawn_manager.get_spawn_for_slot(slot)
	var radius := float(winner_body.get("_collision_radius")) if winner_body != null and winner_body.get("_collision_radius") != null else 2.9
	# Every solid layer: spawn decks are not all on the world layer, and missing
	# the deck lands the stage on the ground underneath it.
	var query := PhysicsRayQueryParameters3D.create(spawn + Vector3.UP * VICTORY_FLOOR_PROBE_UP, spawn - Vector3.UP * VICTORY_FLOOR_PROBE_DOWN)
	var excluded: Array[RID] = []
	for blob in [game.player] + game.remote_players.get_children():
		if blob is CollisionObject3D:
			excluded.append((blob as CollisionObject3D).get_rid())
			var hurtbox := (blob as Node).get_node_or_null("Hurtbox") as CollisionObject3D
			if hurtbox != null:
				excluded.append(hurtbox.get_rid())
	query.exclude = excluded
	var hit := game.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return spawn
	return Vector3(spawn.x, (hit["position"] as Vector3).y + radius, spawn.z)


## The winning team's spawn slot, falling back to the team's default deck when
## no peer holds that team (a disconnected opponent).
func _stage_slot(winning_team: int) -> int:
	var peer_id := game._peer_for_team(winning_team)
	if peer_id > 0:
		return game._spawn_slot_for_peer(peer_id)
	return 0 if winning_team == DuelGame.TEAM_RED else 1


## Searches around the stage, starting in front of the spawn's facing, for
## the first camera spot with a clear view of the winner. If every direction
## is cramped, it takes the one with the most room.
func _camera_spot(winning_team: int, target: Vector3) -> Vector3:
	var yaw: float = game.spawn_manager.get_spawn_yaw_for_slot(_stage_slot(winning_team))
	var forward := Vector3(-sin(yaw), 0.0, -cos(yaw))
	var space := game.get_world_3d().direct_space_state
	var sphere := SphereShape3D.new()
	sphere.radius = VICTORY_CAMERA_CLEARANCE
	var excluded: Array[RID] = []
	for blob in [game.player] + game.remote_players.get_children():
		if blob is CollisionObject3D:
			excluded.append((blob as CollisionObject3D).get_rid())
	var best := target + forward * VICTORY_CAMERA_MIN_DISTANCE + Vector3.UP * VICTORY_CAMERA_HEIGHT
	var best_room := -1.0
	for angle in VICTORY_CAMERA_ANGLES_DEGREES:
		var direction := forward.rotated(Vector3.UP, deg_to_rad(float(angle)))
		var desired := target + direction * VICTORY_CAMERA_DISTANCE + Vector3.UP * VICTORY_CAMERA_HEIGHT
		var cast := PhysicsShapeQueryParameters3D.new()
		cast.shape = sphere
		cast.transform = Transform3D(Basis.IDENTITY, target)
		cast.motion = desired - target
		cast.collision_mask = VICTORY_CAMERA_MASK
		cast.exclude = excluded
		var fractions := space.cast_motion(cast)
		var safe_fraction := float(fractions[0]) if fractions.size() > 0 else 1.0
		var room := safe_fraction * VICTORY_CAMERA_DISTANCE
		if safe_fraction >= 0.999:
			return desired
		if room > best_room:
			best_room = room
			best = target + (desired - target) * safe_fraction
	return best
