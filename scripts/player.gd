class_name BlobPlayer
extends RigidBody3D

const COSMETIC_LIBRARY := preload("res://scripts/cosmetic_library.gd")
const ABILITY_TUNING := preload("res://scripts/ability_tuning.gd")
const COMBAT_TUNING := preload("res://scripts/combat_tuning.gd")
const BLOB_MATERIAL_KIT := preload("res://scripts/blob_material_kit.gd")
const REMOTE_SNAPSHOT_BUFFER := preload("res://scripts/net/remote_snapshot_buffer.gd")
const NETWORK_TUNING := preload("res://scripts/net/network_tuning.gd")
## Skins whose emission pulses every frame. Kept as a shared lookup so the
## per-frame animation never allocates just to test membership.
const PULSING_SKIN_EFFECTS := {
	"lava": true, "plasma": true, "aurora": true, "galaxy": true, "neon": true,
	"black_hole": true, "dark_matter": true, "celestial": true, "crystal": true,
	"cyber": true, "gold": true,
}

signal health_changed(current_health: int, max_health: int)
signal fling_charge_started
signal fling_charge_updated(charge_ratio: float)
signal fling_maximum_reached
signal fling_released(charge_ratio: float)
signal fling_cooldown_updated(remaining_seconds: float, duration_seconds: float)
signal shoot_requested(origin: Vector3, direction: Vector3)
signal bounce_triggered(strength: float)
signal bounce_counted(strength: float)
## `strength` is the raw contact speed and drives presentation - impact bursts
## and hit audio - so it fires on every real contact including rolling.
## `severity` is how fast the blob is driving *into* the surface, and is what
## camera shake keys off, so gentle rolling stays visually quiet (BUG-030).
signal impact_event(world_position: Vector3, strength: float, severity: float)
signal damaged(amount: int)
signal respawned(world_position: Vector3)
signal knocked_out(peer_id: int)
signal network_collision_requested(target_peer_id: int, impulse: Vector3, damage: int)
## Advanced movement telemetry. `wall_kicked` carries the wall normal the blob
## launched away from; `slam_landed` carries the impact severity it emitted.
signal wall_kicked(wall_normal: Vector3)
signal slam_started
signal slam_landed(severity: float)
signal slide_state_changed(sliding: bool)
signal power_slide_changed(sliding: bool)
## The small hop a power slide pops out with when it ends on the ground.
signal power_slide_hopped
signal hotbar_slot_changed(slot: int)
signal air_jumped(direction: Vector3)
## A grounded bounce (Space on the floor); pads and wall kicks do not count.
signal jumped
## Touchdown after real airtime; `fall_speed` is the fastest downward speed
## reached in that flight. A slam's touchdown reports through `slam_landed`.
signal landed(fall_speed: float)

## Number of horizontal rays the wall-kick probe sweeps around the blob. Twelve
## (every 30 degrees) keeps the worst-case reach loss at cos(15 deg) ~ 3.4%.
const WALL_KICK_PROBE_DIRECTIONS := 12
## A slam has landed once the solver has scrubbed its downward speed below this
## fraction of the commanded slam speed while the ground cast is touching.
const SLAM_LANDED_SPEED_FRACTION := 0.5
## Airtime below this is a seam or a hop off a bump, not a landing.
const LANDING_MIN_AIRTIME := 0.14
## A slide that has slowed below this fraction of its entry threshold hands
## over to the ordinary brake early instead of coasting forever.
const SLIDE_EXIT_SPEED_FRACTION := 0.6
## Collision radius used when the scene's sphere shape cannot be read.
const BLOB_RADIUS_FALLBACK := 2.8875

@export_category("Ground Movement")
@export var ground_acceleration := 92.0
@export var ground_start_impulse := 6.5
@export var ground_control_speed := 42.0
@export var ground_counter_acceleration := 74.0
@export var idle_ground_drag := 2.0
@export var movement_roll_torque := 128.0
@export var movement_build_up_time := 0.42
@export_range(0.1, 1.0, 0.05) var movement_initial_acceleration_factor := 0.78
## Shape of the push-force falloff as ground speed nears ground_control_speed.
## 1 is linear (force fades the whole way up - mushy top end); higher holds
## full force until close to top speed, then tapers so it never overshoots.
@export_range(1.0, 6.0, 0.5) var ground_control_curve_exponent := 3.0
@export_range(0.0, 12.0, 0.1) var brake_drag := 3.6

@export_category("Air Movement")
@export var air_steering_strength := 0.58
@export var air_control_speed := 20.0
@export var air_momentum_decay := 0.04
@export var post_fling_drag := 0.25
@export var high_speed_drag := 0.48
@export var high_speed_drag_threshold := 45.0
@export var maximum_movement_speed := 96.0
@export var emergency_max_speed := 104.0

@export_category("Bounce Boost")
@export var bounce_boost_impulse := 56.0
@export var bounce_boost_cooldown := 0.18
@export var coyote_time := 0.18
@export var input_buffer_time := 0.12
@export var surface_bounce_min_speed := 2.5
@export var max_bounce_upward_speed := 52.0
@export_range(0.0, 89.0, 1.0) var ground_max_angle := 56.0

@export_category("Landing")
## Touchdowns slower than this vertically are rolling contact, never scrubbed.
@export var landing_scrub_min_speed := 4.0
## Vertical touchdown speed at which the full scrub applies.
@export var landing_scrub_full_speed := 16.0
## Fraction of planar speed a hard touchdown scrubs off. This is what settles a
## fling: the bouncy body hops along the floor for seconds with zero solver
## contacts, so idle drag alone never engaged and a launch coasted at 30 m/s
## long after its cooldown. Bunny-hopping (Space buffered before touchdown)
## skips the scrub, so keeping speed is a skill, not a default.
@export_range(0.0, 1.0, 0.05) var landing_scrub := 0.3
## After any floor touchdown, idle ground drag keeps applying for this long
## even while the bouncy body is between hops (ground cast touching, zero
## solver contacts). Hops land roughly once a second, so a post-fling skitter
## settles to controllable speed instead of coasting; a body that never touches
## the floor is untouched.
@export var ground_settle_window := 0.7

@export_category("Wall Kick")
## Gap between the blob's surface and a wall within which Space becomes a wall
## kick. Tight on purpose: you have to be *on* the wall, not vaguely near it.
@export var wall_kick_probe_distance := 1.2
## Impulse (N.s) straight away from the wall; over the 3.2 kg blob that is a
## 30 m/s push, so a kick reads as a real launch next to a 38 m/s ground band.
@export var wall_kick_impulse := 96.0
## Small upward component so a kick chain climbs instead of only skating.
@export var wall_kick_upward_impulse := 38.0
## Minimum spacing between kicks; short enough to chain between close walls.
@export var wall_kick_cooldown := 0.22
## Fraction of incoming planar speed kept (reflected off the wall) by a kick.
@export_range(0.0, 1.0, 0.05) var wall_kick_speed_retention := 0.5
## Surfaces whose normal tilts further than this from horizontal are floors or
## ceilings, never kickable walls.
@export_range(0.0, 89.0, 1.0) var wall_kick_max_surface_tilt := 40.0

@export_category("Slam")
## Downward speed the blob is driven to (and held at) for the whole dive.
@export var slam_downward_speed := 64.0
## Planar speed kept when the slam starts, so the dive goes straight down.
@export_range(0.0, 1.0, 0.05) var slam_planar_retention := 0.3
## Extra severity on top of the dive speed for the landing impact signal, so the
## camera shake clearly outranks an ordinary drop from the same height.
@export var slam_landing_severity_bonus := 22.0
## Landing burst strength relative to the dive speed.
@export var slam_landing_strength_scale := 1.5
## The bouncy physics material would trampoline a 64 m/s dive straight back up;
## a landed slam sticks unless a buffered bounce turns it into a slam-jump.
@export var slam_landing_rebound_speed := 4.0
@export var slam_cooldown := 0.5

@export_category("Momentum Slide")
## Planar speed above which holding brake on the ground slides instead of
## braking hard.
@export var slide_speed_threshold := 22.0
## How long a slide lasts before it hands over to the ordinary brake.
@export var slide_duration := 0.85
## Drag while sliding; must stay far below `brake_drag` for the slide to read.
@export_range(0.0, 12.0, 0.05) var slide_drag := 0.5
## Steering authority while sliding - a slide keeps its heading.
@export_range(0.0, 1.0, 0.05) var slide_steer_multiplier := 0.2
## Visual squash held while sliding (fed to the blob visual's impact channel).
@export_range(0.0, 1.0, 0.05) var slide_squash := 0.9
## Brake must be released for at least this long before another slide.
@export var slide_recovery_time := 0.35

@export_category("Power Slide")
## Holding slide (C) on the ground is a power slide: a burst of speed along the
## heading, low drag, a raised speed band and a committed line. It lasts while
## held, up to `power_slide_duration`, and ends with a small hop.
## Planar speed the entry burst adds along the heading.
@export var power_slide_entry_boost := 16.0
## The entry burst never lifts planar speed past this.
@export var power_slide_entry_speed_cap := 52.0
## Drag while power sliding; well under idle drag so the slide carries.
@export_range(0.0, 12.0, 0.05) var power_slide_drag := 0.15
## Steering authority while power sliding - a slide mostly keeps its line.
@export_range(0.0, 1.0, 0.05) var power_slide_steer_multiplier := 0.35
## Ground control speed scale while power sliding.
@export var power_slide_speed_multiplier := 1.25
## Longest a single power slide lasts before it pops out on its own.
@export var power_slide_duration := 1.4
## Upward speed of the hop when a power slide ends on the ground.
@export var power_slide_exit_hop := 7.0
## Visual squash held while power sliding.
@export_range(0.0, 1.0, 0.05) var power_slide_squash := 0.85
## Airtime a power slide survives (bumps, seams) before it ends.
@export var power_slide_air_grace := 0.2
## Once past this long, a power slide slower than the minimum ends.
@export var power_slide_min_time := 0.3
@export var power_slide_min_speed := 8.0
## Slide must be released for at least this long before another burst.
@export var power_slide_recovery_time := 0.45

@export_category("Air Control Curve")
## Steering authority left for a full mid-air reversal. Small corrections keep
## full authority; big heading changes cost most of it.
@export_range(0.0, 1.0, 0.05) var air_reversal_steering_factor := 0.35
## Shapes how quickly authority falls off as the requested turn widens.
@export_range(0.5, 4.0, 0.1) var air_control_curve_exponent := 1.6

@export_category("Speed Trail")
## Planar speed at which the speed-line trail starts emitting.
@export var trail_start_speed := 18.0
## Speed at which the trail reaches full density and lifetime.
@export var trail_full_speed := 76.0

@export_category("Fling")
@export var maximum_charge_time := 7.0
## "Fling does nothing" (twice): a normal ~1s press only reaches 14% of the
## 7s charge (pinned by contract), and the old 80 floor on a back-loaded curve
## launched at ~27 m/s - slower than the 42 m/s roll. The floor now launches
## past rolling speed (~53 m/s) and the curve is front-loaded (exponent < 1),
## so a 1s press is a real ~64 m/s launch while a full 7s charge still delivers
## the maximum ~87 m/s.
@export var minimum_fling_impulse := 170.0
@export var maximum_fling_impulse := 280.0
@export var charge_exponent := 0.55
@export var fling_upward_assist := 0.12
@export var fling_control_reduction_time := 0.32
@export var fling_control_multiplier := 0.28
@export var maximum_fling_charge_drag := 0.55
@export var fling_cooldown_duration := 3.0
## Grace period after a launch during which the anti-chaining drag stays off, so
## the impulse actually reads before momentum starts bleeding away.
@export var post_fling_carry_time := 0.35
## Release thrust: after the launch impulse the blob keeps accelerating along
## the fling direction for a burst whose top speed and length scale with the
## charge (same curve as the impulse). Top speed stays under the host's
## MAX_REMOTE_STATE_SPEED (138) so a boosted client is never rubber-banded.
@export var fling_thrust_min_speed := 72.0
@export var fling_thrust_max_speed := 128.0
@export var fling_thrust_acceleration := 320.0
@export var fling_thrust_min_duration := 0.22
@export var fling_thrust_max_duration := 0.55
## A one-frame drop in along-direction speed this large means the blob hit
## something; the thrust ends instead of grinding into the wall or target.
@export var fling_thrust_impact_speed_drop := 14.0

@export_category("Combat")
@export var max_health := 150
@export var shot_cooldown := 0.16
@export var shot_recoil_impulse := 18.0
@export var impact_damage_scale := 2.2
@export var velocity_damage_scale := 0.9
@export var collision_pair_cooldown := 0.16

var aim_yaw := 0.0
## Code-driven controls (scripts/blob_virtual_input.gd). While set, every
## action and axis read below comes from here instead of the Input singleton,
## so a bot runs the same movement code a human does. `input_enabled` keeps
## meaning "the human may drive this body".
var virtual_input: BlobVirtualInput
var aim_direction := Vector3.FORWARD
var health := 150
var fling_charge := 0.0
var local_controlled := true
var shooting_enabled := false
var input_enabled := true
var network_peer_id := 1
var display_name := "Player"
## Active hotbar slot (CombatTuning.SLOT_BLASTER / SLOT_BLOB). Local input sets
## it; a remote blob mirrors whatever its owner last reported.
var hotbar_slot := COMBAT_TUNING.SLOT_BLASTER
var blob_color := Color(0.02, 0.86, 1.0)

var _is_charging_fling := false
var _maximum_charge_announced := false
var _spawn_position := Vector3.ZERO
var _was_moving := false
var _movement_build_up := 0.0
var _movement_build_direction := Vector3.ZERO
## Practice-only training switches, driven by the practice control panel. They
## stay false everywhere else, so a duel is never affected.
var practice_unlimited_shots := false
var practice_skip_cooldowns := false

var _grounded := false
var _ground_normal := Vector3.UP
var _coyote_timer := 0.0
var _bounce_buffer_timer := 0.0
var _bounce_cooldown_timer := 0.0
var _shot_cooldown_timer := 0.0
var _post_fling_control_timer := 0.0
var _recent_fling_timer := 0.0
var _recent_fling_charge := 0.0
var _fling_cooldown_timer := 0.0
var _quick_blob_timer := 0.0
## Consecutive hits inside CombatTuning.HIT_CHAIN_WINDOW (juggle protection).
var _hit_chain_count := 0
var _hit_chain_timer := 0.0
var _fling_carry_timer := 0.0
var _fling_thrust_timer := 0.0
var _fling_thrust_direction := Vector3.ZERO
var _fling_thrust_target_speed := 0.0
var _fling_thrust_last_speed := 0.0
## Speed cap the emergency guard honours while a thrust burst (and its carry)
## is live; falls back to maximum_movement_speed once the carry ends.
var _fling_speed_limit := 0.0
var _upward_cap_exempt_timer := 0.0
var _ground_settle_timer := 0.0
var _wall_kick_cooldown_timer := 0.0
var _last_wall_kick_normal := Vector3.ZERO
var _wall_probe_query: PhysicsRayQueryParameters3D
var _collision_radius := BLOB_RADIUS_FALLBACK
var _slamming := false
var _slam_cooldown_timer := 0.0
var _sliding := false
var _slide_timer := 0.0
## True once a slide has expired while brake is still held; brake must be
## released before another slide can start.
var _slide_spent := false
var _slide_recovery_timer := 0.0
var _power_sliding := false
var _power_slide_timer := 0.0
var _power_slide_air_timer := 0.0
## True once a power slide has ended while slide is still held; it must be
## released before another can start.
var _power_slide_spent := false
var _power_slide_recovery_timer := 0.0
var _air_jumps_left := COMBAT_TUNING.BLOB_AIR_JUMPS
var _was_grounded := true
var _airtime := 0.0
var _peak_fall_speed := 0.0
var _collision_ready_at: Dictionary = {}
## Per-surface debounce for quest bounces, keyed by the body hit and stamped
## in physics time (`_physics_clock`), not wall-clock: headless runs step the
## simulation faster than real time, so a wall-clock window counted differently
## on every machine (physics_integration).
var _bounce_count_ready_at: Dictionary = {}
## Seconds of simulated physics since spawn; the clock every debounce reads.
var _physics_clock := 0.0
const BOUNCE_COUNT_DEBOUNCE_SECONDS := 0.1
var _network_target_position := Vector3.ZERO
var _network_target_rotation := Vector3.ZERO
## Host-stamped state history for a remote blob; see _update_remote_transform.
var _remote_snapshots: RemoteSnapshotBuffer = REMOTE_SNAPSHOT_BUFFER.new()
var _equipped_skin_id := "classic_blue"
var _equipped_trail_id := "bubble"
var _equipped_face_id := "happy"
var _equipped_kill_effect_id := "bubble_pop"
var _cosmetic_quality := 1
var _skin_profile: Dictionary = {}
var _skin_material: StandardMaterial3D
var _cosmetic_time := 0.0
var _cosmetic_light: OmniLight3D
var _trail_base_amount := 18
var _trail_base_lifetime := 0.95
var _equipped_ability_id := ""
var _overcharge_active := false
var _scanner_outline: MeshInstance3D
var _shooting_locked := false
var _phase_bubble_active := false
var _phase_bubble_visual: MeshInstance3D
var _adrenaline_active := false

@onready var nameplate_root: Node3D = $Nameplate
@onready var name_label: Label3D = $Nameplate/Name
@onready var health_fill: MeshInstance3D = $Nameplate/HealthFill
@onready var mesh: MeshInstance3D = $VisualRoot/Mesh
@onready var speed_trail: GPUParticles3D = $SpeedTrail
@onready var face_root: Node3D = $FaceRoot
@onready var ground_cast: ShapeCast3D = get_node_or_null("GroundCast") as ShapeCast3D


func _ready() -> void:
	can_sleep = false
	contact_monitor = true
	max_contacts_reported = 16
	body_entered.connect(_on_body_entered)
	$ContactArea.area_entered.connect(_on_contact_area_entered)
	health = max_health
	_network_target_position = global_position
	_network_target_rotation = rotation
	nameplate_root.visible = false
	_update_nameplate_transform()
	_update_health_billboard()
	_apply_saved_cosmetics()
	var collision_shape := get_node_or_null("Collision") as CollisionShape3D
	var sphere := collision_shape.shape as SphereShape3D if collision_shape != null else null
	if sphere != null:
		_collision_radius = sphere.radius


func _physics_process(delta: float) -> void:
	_update_nameplate_transform()
	_update_speed_trail()
	_update_cosmetic_animation(delta)
	_update_face()
	_update_adrenaline()
	if not local_controlled:
		# BUG-028: _update_nameplate_transform() already ran at the top of this
		# function; calling it again here was pure duplicated work for every
		# remote blob, every physics frame.
		_update_remote_transform(delta)
		return

	_tick_timers(delta)
	_update_ground_state(delta)
	# A slam already in flight lands even if control was pulled mid-dive.
	_update_slam_state()
	if not _accepts_input():
		_end_slide(false)
		_end_power_slide(false)
		_end_fling_thrust()
		_apply_momentum_decay(delta)
		_apply_bounce_height_cap()
		_apply_emergency_speed_guard()
		return

	_update_hotbar_input()
	_update_bounce_input()
	_apply_movement(delta)
	_apply_brake(delta)
	_update_power_slide(delta)
	_apply_fling_charge_drag()
	_update_fling_charge(delta)
	_apply_fling_thrust(delta)
	_update_shooting()
	_apply_momentum_decay(delta)
	_apply_bounce_height_cap()
	_apply_emergency_speed_guard()
	if virtual_input != null:
		virtual_input.end_frame()


## Human input on, or a controller script attached.
func _accepts_input() -> bool:
	return input_enabled or virtual_input != null


func _action_pressed(action: StringName) -> bool:
	return virtual_input.is_pressed(action) if virtual_input != null else Input.is_action_pressed(action)


func _action_just_pressed(action: StringName) -> bool:
	return virtual_input.is_just_pressed(action) if virtual_input != null else Input.is_action_just_pressed(action)


func _action_just_released(action: StringName) -> bool:
	return virtual_input.is_just_released(action) if virtual_input != null else Input.is_action_just_released(action)


func configure_local(peer_id: int) -> void:
	network_peer_id = peer_id
	local_controlled = true
	freeze = false
	collision_layer = 2
	collision_mask = 1


func configure_remote(peer_id: int, color: Color) -> void:
	network_peer_id = peer_id
	local_controlled = false
	freeze = true
	collision_layer = 2
	collision_mask = 0
	set_blob_color(color)
	_network_target_position = global_position
	_network_target_rotation = rotation
	_remote_snapshots.clear()


func set_player_identity(new_display_name: String, color: Color) -> void:
	var clean_name := new_display_name.strip_edges()
	var next_name := clean_name.left(16) if not clean_name.is_empty() else "Player"
	var identity_changed := next_name != display_name or not color.is_equal_approx(blob_color)
	display_name = next_name
	if not color.is_equal_approx(blob_color):
		set_blob_color(color)
	if identity_changed:
		_update_health_billboard()


func apply_network_identity(new_display_name: String, color: Color) -> void:
	set_player_identity(new_display_name, color)


## Feeds one replicated state. `host_time_msec` is the host clock the state
## was sampled at and goes into the snapshot buffer for delayed interpolation.
## Without a stamp (health-only updates from the host's own hit pipeline) the
## transform is applied immediately and the buffer restarts from it.
func apply_network_state(network_position: Vector3, body_rotation: Vector3, velocity: Vector3, current_health: int, facing_direction: Vector3, host_time_msec: int = -1) -> void:
	_network_target_position = network_position
	_network_target_rotation = body_rotation
	linear_velocity = velocity
	if host_time_msec >= 0:
		_remote_snapshots.push(network_position, body_rotation, velocity, host_time_msec)
	else:
		_remote_snapshots.clear()
		if not local_controlled:
			global_position = network_position
			rotation = body_rotation
	if facing_direction.length_squared() > 0.001:
		aim_direction = facing_direction.normalized()
	if health != current_health:
		if current_health < health:
			BLOB_MATERIAL_KIT.flash_hit(mesh)
		health = clampi(current_health, 0, max_health)
		health_changed.emit(health, max_health)
		_update_health_billboard()


func set_blob_color(color: Color) -> void:
	blob_color = color
	if mesh == null:
		return
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.28
	material.metallic = 0.05
	BLOB_MATERIAL_KIT.decorate(material, color)
	mesh.material_override = material
	BLOB_MATERIAL_KIT.apply_outline(mesh, color)
	name_label.modulate = color.lightened(0.3)
	var trail_mesh := speed_trail.draw_pass_1.duplicate() as PrimitiveMesh
	var trail_material := trail_mesh.material.duplicate() as StandardMaterial3D
	trail_material.albedo_color = Color(color.r, color.g, color.b, 0.72)
	trail_material.emission = color
	trail_mesh.material = trail_material
	speed_trail.draw_pass_1 = trail_mesh
	apply_equipped_cosmetics(_equipped_skin_id, _equipped_trail_id, _equipped_face_id, _equipped_kill_effect_id)


func apply_equipped_cosmetics(skin_id: String, trail_id: String, face_id: String, kill_effect_id: String) -> void:
	_equipped_skin_id = skin_id if not skin_id.is_empty() else "classic_blue"
	_equipped_trail_id = trail_id if not trail_id.is_empty() else "bubble"
	_equipped_face_id = face_id if not face_id.is_empty() else "happy"
	_equipped_kill_effect_id = kill_effect_id if not kill_effect_id.is_empty() else "bubble_pop"
	if mesh == null or speed_trail == null:
		return
	_skin_profile = COSMETIC_LIBRARY.skin_profile(_equipped_skin_id, blob_color)
	var primary := _skin_profile.get("primary", blob_color) as Color
	var secondary := _skin_profile.get("secondary", primary.lightened(0.4)) as Color
	var effect := str(_skin_profile.get("effect", "jelly"))
	_skin_material = StandardMaterial3D.new()
	_skin_material.albedo_color = primary
	_skin_material.roughness = 0.16 if effect in ["water", "ice", "crystal", "gold"] else 0.29
	_skin_material.metallic = 0.88 if effect in ["gold", "cyber", "crystal"] else 0.04
	_skin_material.emission_enabled = effect in ["lava", "galaxy", "crystal", "neon", "plasma", "cyber", "black_hole", "aurora", "gold", "rainbow", "dark_matter", "celestial"]
	_skin_material.emission = secondary
	_skin_material.emission_energy_multiplier = 0.45
	BLOB_MATERIAL_KIT.decorate(_skin_material, primary)
	mesh.material_override = _skin_material
	BLOB_MATERIAL_KIT.apply_outline(mesh, primary)
	_apply_trail_profile(COSMETIC_LIBRARY.trail_profile(_equipped_trail_id))
	_apply_face_profile(COSMETIC_LIBRARY.face_profile(_equipped_face_id))
	_apply_cosmetic_light(secondary, str(_skin_profile.get("rarity", "Common")))


func set_cosmetic_quality(quality: int) -> void:
	_cosmetic_quality = clampi(quality, 0, 3)
	apply_equipped_cosmetics(_equipped_skin_id, _equipped_trail_id, _equipped_face_id, _equipped_kill_effect_id)


func get_kill_effect_id() -> String:
	return _equipped_kill_effect_id


func get_skin_rarity() -> String:
	return str(_skin_profile.get("rarity", "Common"))


func get_skin_accent_color() -> Color:
	return _skin_profile.get("secondary", blob_color) as Color


func get_cosmetic_signature() -> Dictionary:
	return {
		"skin": _equipped_skin_id,
		"skin_effect": str(_skin_profile.get("effect", "jelly")),
		"trail": _equipped_trail_id,
		"trail_mesh": speed_trail.draw_pass_1.get_class() if speed_trail != null and speed_trail.draw_pass_1 != null else "",
		"face": _equipped_face_id,
		"face_accessories": face_root.get_node("CosmeticAccessories").get_child_count() if face_root != null and face_root.has_node("CosmeticAccessories") else 0,
		"kill_effect": _equipped_kill_effect_id,
	}


func _apply_saved_cosmetics() -> void:
	var progression := get_node_or_null("/root/Progression")
	if progression == null:
		apply_equipped_cosmetics(_equipped_skin_id, _equipped_trail_id, _equipped_face_id, _equipped_kill_effect_id)
		return
	apply_equipped_cosmetics(
		str(progression.call("get_equipped", "skins")),
		str(progression.call("get_equipped", "trails")),
		str(progression.call("get_equipped", "faces")),
		str(progression.call("get_equipped", "kill_effects")),
	)


func _apply_trail_profile(profile: Dictionary) -> void:
	var trail_color := profile.get("color", blob_color) as Color
	var rarity := str(profile.get("rarity", "Common"))
	var effect := str(profile.get("effect", "soft"))
	var lifetime_by_effect := {"spark": 0.42, "lightning": 0.5, "pixels": 0.68, "glitch": 0.55, "bubble": 1.15, "snow": 1.25, "leaves": 1.2, "sakura": 1.35, "notes": 1.15, "meteor": 0.72, "fire": 0.78, "aurora": 1.4, "galaxy": 1.25, "void": 0.9}
	_trail_base_lifetime = float(lifetime_by_effect.get(effect, 0.95))
	_trail_base_amount = [10, 18, 28, 40][_cosmetic_quality]
	if rarity in ["Epic", "Legendary"] and _cosmetic_quality >= 2:
		_trail_base_amount += 8
	if effect in ["spark", "lightning", "meteor", "fire"]:
		_trail_base_amount = maxi(8, int(_trail_base_amount * 0.72))
	speed_trail.lifetime = _trail_base_lifetime
	speed_trail.amount = _trail_base_amount
	var trail_mesh := _trail_mesh_for_effect(effect)
	var trail_material := StandardMaterial3D.new()
	trail_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	trail_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	trail_material.albedo_color = Color(trail_color.r, trail_color.g, trail_color.b, 0.7)
	trail_material.emission_enabled = true
	trail_material.emission = trail_color
	trail_material.emission_energy_multiplier = 0.55 if rarity in ["Common", "Rare"] else 1.15
	trail_mesh.material = trail_material
	speed_trail.draw_pass_1 = trail_mesh


func _trail_mesh_for_effect(effect: String) -> PrimitiveMesh:
	if effect in ["pixels", "glitch"]:
		var box := BoxMesh.new()
		box.size = Vector3(0.32, 0.32, 0.32) if effect == "pixels" else Vector3(0.42, 0.12, 0.18)
		return box
	if effect in ["leaves", "sakura", "notes", "aurora"]:
		var quad := QuadMesh.new()
		quad.size = Vector2(0.48, 0.24) if effect != "notes" else Vector2(0.32, 0.52)
		return quad
	if effect in ["lightning", "meteor", "fire", "spark"]:
		var streak := BoxMesh.new()
		streak.size = Vector3(0.12, 0.12, 0.72 if effect != "spark" else 0.34)
		return streak
	var sphere := SphereMesh.new()
	sphere.radius = 0.26 if effect == "bubble" else 0.2
	sphere.height = sphere.radius * 2.0
	sphere.radial_segments = 8
	sphere.rings = 4
	return sphere


func _apply_face_profile(profile: Dictionary) -> void:
	var face_color := profile.get("color", Color(0.04, 0.05, 0.07)) as Color
	var effect := str(profile.get("effect", "happy"))
	_reset_face_geometry()
	for node_name in ["LeftPupil", "RightPupil", "LeftHighlight", "RightHighlight"]:
		var node := face_root.get_node_or_null(node_name) as MeshInstance3D
		if node == null:
			continue
		var material := StandardMaterial3D.new()
		material.albedo_color = face_color
		material.roughness = 0.2
		material.emission_enabled = effect in ["robot", "fire", "frozen", "glitch", "cosmic", "void", "energy", "divine"]
		material.emission = face_color
		material.emission_energy_multiplier = 0.7 if material.emission_enabled else 0.0
		node.material_override = material
	var wink := effect == "wink"
	var right_eye := face_root.get_node_or_null("RightEyeWhite") as MeshInstance3D
	if right_eye != null:
		right_eye.visible = not wink
	var left_pupil := face_root.get_node_or_null("LeftPupil") as MeshInstance3D
	var right_pupil := face_root.get_node_or_null("RightPupil") as MeshInstance3D
	if effect in ["angry", "evil", "fire"]:
		left_pupil.rotation.z = -0.3
		right_pupil.rotation.z = 0.3
	if effect in ["surprised", "love", "cosmic", "divine"]:
		left_pupil.scale *= 1.35
		right_pupil.scale *= 1.35
	if effect in ["sleepy", "frozen"]:
		left_pupil.scale.y *= 0.35
		right_pupil.scale.y *= 0.35
	var smile_base := face_root.get_node_or_null("SmileBase") as MeshInstance3D
	if smile_base != null and effect in ["sad", "angry", "evil", "frozen"]:
		smile_base.rotation.z = -PI * 0.5
		smile_base.position.y = -0.5
	_rebuild_face_accessories(effect, face_color)


func _reset_face_geometry() -> void:
	var defaults := {
		"LeftPupil": [Vector3(-0.82, 0.6, -2.9), Vector3(0.46, 0.58, 0.3), 0.0],
		"RightPupil": [Vector3(0.82, 0.6, -2.9), Vector3(0.46, 0.58, 0.3), 0.0],
		"SmileBase": [Vector3(0, -0.84, -2.91), Vector3(0.7, 0.62, 0.62), PI * 0.5],
	}
	for node_name in defaults:
		var node := face_root.get_node_or_null(node_name) as MeshInstance3D
		if node == null:
			continue
		var values := defaults[node_name] as Array
		node.position = values[0]
		node.scale = values[1]
		node.rotation.z = float(values[2])
	var right_eye := face_root.get_node_or_null("RightEyeWhite") as MeshInstance3D
	if right_eye != null:
		right_eye.visible = true


func _rebuild_face_accessories(effect: String, color: Color) -> void:
	var old := face_root.get_node_or_null("CosmeticAccessories")
	if old != null:
		old.free()
	var root := Node3D.new()
	root.name = "CosmeticAccessories"
	face_root.add_child(root)
	match effect:
		"cool":
			_add_face_accessory(root, Vector3(0, 0.64, -3.03), Vector3(2.25, 0.44, 0.16), Color("080b12"))
		"pirate":
			_add_face_accessory(root, Vector3(-0.82, 0.64, -3.05), Vector3(0.72, 0.72, 0.18), Color("161116"), true)
			_add_face_accessory(root, Vector3(0, 0.95, -3.0), Vector3(2.7, 0.12, 0.12), Color("161116"))
		"nerd":
			_add_face_accessory(root, Vector3(-0.82, 0.64, -3.04), Vector3(0.94, 0.82, 0.14), color, true)
			_add_face_accessory(root, Vector3(0.82, 0.64, -3.04), Vector3(0.94, 0.82, 0.14), color, true)
			_add_face_accessory(root, Vector3(0, 0.64, -3.02), Vector3(0.52, 0.1, 0.1), color)
		"robot", "energy":
			_add_face_accessory(root, Vector3(0, 0.62, -3.05), Vector3(2.45, 0.72, 0.12), color)
		"love":
			_add_face_accessory(root, Vector3(-0.82, 0.65, -3.08), Vector3(0.42, 0.42, 0.14), color, true)
			_add_face_accessory(root, Vector3(0.82, 0.65, -3.08), Vector3(0.42, 0.42, 0.14), color, true)
		"divine":
			_add_face_accessory(root, Vector3(0, 2.35, -2.9), Vector3(1.4, 0.16, 0.16), color, true)


func _add_face_accessory(parent: Node3D, position_value: Vector3, scale_value: Vector3, color: Color, sphere := false) -> void:
	var instance := MeshInstance3D.new()
	var shape: PrimitiveMesh = SphereMesh.new() if sphere else BoxMesh.new()
	if shape is SphereMesh:
		(shape as SphereMesh).radius = 0.5
		(shape as SphereMesh).height = 1.0
	else:
		(shape as BoxMesh).size = Vector3.ONE
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.2
	material.emission_enabled = color.get_luminance() > 0.55
	material.emission = color
	material.emission_energy_multiplier = 0.6
	shape.material = material
	instance.mesh = shape
	instance.position = position_value
	instance.scale = scale_value
	parent.add_child(instance)


func _apply_cosmetic_light(color: Color, rarity: String) -> void:
	if rarity != "Legendary" or _cosmetic_quality < 2:
		if _cosmetic_light != null:
			_cosmetic_light.visible = false
		return
	if _cosmetic_light == null:
		_cosmetic_light = OmniLight3D.new()
		_cosmetic_light.name = "CosmeticGlow"
		_cosmetic_light.omni_range = 5.0
		_cosmetic_light.shadow_enabled = false
		add_child(_cosmetic_light)
	_cosmetic_light.visible = true
	_cosmetic_light.light_color = color
	_cosmetic_light.light_energy = 0.38


func _update_cosmetic_animation(delta: float) -> void:
	_cosmetic_time += delta
	if _skin_material == null:
		return
	var effect := str(_skin_profile.get("effect", "jelly"))
	# BUG-028: this used to build the pulsing-effect Array inline, allocating a
	# fresh 11-element Array per blob per physics frame purely to answer a
	# membership test. Most skins animate nothing, so bail before touching the
	# material at all.
	var is_rainbow := effect == "rainbow"
	var is_pulsing: bool = PULSING_SKIN_EFFECTS.has(effect)
	var lit := _cosmetic_light != null and _cosmetic_light.visible
	if not is_rainbow and not is_pulsing and not lit:
		return
	var pulse := 0.55 + sin(_cosmetic_time * 2.2) * 0.2
	if is_rainbow:
		_skin_material.albedo_color = Color.from_hsv(fposmod(_cosmetic_time * 0.14, 1.0), 0.72, 1.0)
		_skin_material.emission = Color.from_hsv(fposmod(_cosmetic_time * 0.14 + 0.18, 1.0), 0.58, 1.0)
	elif is_pulsing:
		_skin_material.emission = _skin_profile.get("secondary", blob_color) as Color
		_skin_material.emission_energy_multiplier = pulse
	if lit:
		_cosmetic_light.light_energy = 0.28 + pulse * 0.2


func get_movement_input() -> Vector2:
	if virtual_input != null:
		return virtual_input.move.limit_length(1.0)
	return Input.get_vector("move_left", "move_right", "move_forward", "move_back")


func get_charge_ratio() -> float:
	return clampf(fling_charge / maxf(maximum_charge_time, 0.001), 0.0, 1.0)


func get_fling_cooldown_remaining() -> float:
	return _fling_cooldown_timer


func get_fling_cooldown_duration() -> float:
	return fling_cooldown_duration


func get_fling_cooldown_ratio() -> float:
	return clampf(_fling_cooldown_timer / maxf(fling_cooldown_duration, 0.001), 0.0, 1.0)


func is_fling_ready() -> bool:
	return _fling_cooldown_timer <= 0.0


func can_fling() -> bool:
	return is_fling_ready() and _accepts_input() and local_controlled


func trigger_launch_visual(amount: float = 0.5) -> void:
	_launch_visual(amount)


func calculate_fling_strength(charge_ratio: float) -> float:
	var curved_charge := pow(clampf(charge_ratio, 0.0, 1.0), charge_exponent)
	return lerpf(minimum_fling_impulse, maximum_fling_impulse, curved_charge)


func calculate_fling_thrust_speed(charge_ratio: float) -> float:
	var curved_charge := pow(clampf(charge_ratio, 0.0, 1.0), charge_exponent)
	return lerpf(fling_thrust_min_speed, fling_thrust_max_speed, curved_charge)


func is_fling_thrusting() -> bool:
	return _fling_thrust_timer > 0.0


func is_grounded() -> bool:
	return _grounded


func request_shot_for_test() -> void:
	_emit_shot_request()


func set_shooting_enabled(enabled: bool) -> void:
	shooting_enabled = enabled


func respawn(spawn_position: Vector3) -> void:
	_spawn_position = spawn_position
	freeze = true
	global_position = spawn_position
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	reset_physics_interpolation()
	sleeping = false
	freeze = false
	health = max_health
	health_changed.emit(health, max_health)
	_update_health_billboard()
	cancel_active_charge()
	_coyote_timer = 0.0
	_bounce_buffer_timer = 0.0
	_bounce_cooldown_timer = 0.2
	_shot_cooldown_timer = 0.0
	_post_fling_control_timer = 0.0
	_recent_fling_timer = 0.0
	_fling_cooldown_timer = 0.0
	_fling_carry_timer = 0.0
	_end_fling_thrust()
	_fling_speed_limit = 0.0
	fling_cooldown_updated.emit(0.0, fling_cooldown_duration)
	_upward_cap_exempt_timer = 0.0
	_movement_build_up = 0.0
	_movement_build_direction = Vector3.ZERO
	_ground_settle_timer = 0.0
	_wall_kick_cooldown_timer = 0.0
	_last_wall_kick_normal = Vector3.ZERO
	_slamming = false
	_slam_cooldown_timer = 0.0
	_hit_chain_count = 0
	_hit_chain_timer = 0.0
	_end_slide(false)
	_slide_recovery_timer = 0.0
	_end_power_slide(false)
	_power_slide_recovery_timer = 0.0
	_bounce_count_ready_at.clear()
	_air_jumps_left = COMBAT_TUNING.BLOB_AIR_JUMPS
	_airtime = 0.0
	_peak_fall_speed = 0.0
	_hit_visual(0.12)
	respawned.emit(global_position)


func take_damage(amount: int, hit_direction: Vector3, knockback: float) -> void:
	if not local_controlled:
		return
	var launch_direction := (hit_direction.normalized() + Vector3.UP * 0.22).normalized()
	receive_collision_impact(amount, launch_direction * knockback * 1.18, true)


func receives_direct_damage() -> bool:
	return local_controlled


func apply_external_impulse(impulse: Vector3) -> void:
	if not local_controlled:
		return
	sleeping = false
	apply_central_impulse(impulse)
	_upward_cap_exempt_timer = 0.28
	_hit_visual(clampf(impulse.length() * 0.008, 0.08, 0.3))
	impact_event.emit(global_position, impulse.length(), impulse.length())


## `from_shot` marks projectile hits, which get juggle protection: a rapid
## chain of shots loses knockback, and only the first shot of a chain can pop
## a grounded blob up - every other shot pushes sideways but never higher, and
## never switches off the upward speed cap. Body slams, mines and shockwaves
## keep their full pop.
func receive_collision_impact(amount: int, impulse: Vector3, from_shot := false) -> void:
	if not local_controlled:
		return
	sleeping = false
	var chain_scale := 1.0
	if from_shot:
		_hit_chain_count = _hit_chain_count + 1 if _hit_chain_timer > 0.0 else 0
		_hit_chain_timer = COMBAT_TUNING.HIT_CHAIN_WINDOW
		chain_scale = maxf(pow(COMBAT_TUNING.HIT_CHAIN_FALLOFF, _hit_chain_count), COMBAT_TUNING.HIT_CHAIN_MIN_SCALE)
	var push := impulse * chain_scale
	if not from_shot or (_grounded and _hit_chain_count == 0):
		var lift := Vector3.UP * clampf(impulse.length() * 0.34, 8.0, 48.0) * chain_scale
		apply_central_impulse((push + lift) * 1.2)
		_upward_cap_exempt_timer = 0.32
	else:
		push.y = minf(push.y, 0.0)
		apply_central_impulse(push * 1.2)
	_hit_visual(clampf(impulse.length() * 0.007, 0.08, 0.32))
	play_hit_flex(impulse, impulse.length())
	impact_event.emit(global_position, impulse.length(), impulse.length())
	if amount <= 0 or health <= 0:
		return
	health = maxi(health - amount, 0)
	BLOB_MATERIAL_KIT.flash_hit(mesh)
	health_changed.emit(health, max_health)
	_update_health_billboard()
	damaged.emit(amount)
	if health <= 0:
		knocked_out.emit(network_peer_id)


func apply_bounce_pad(launch_impulse: float) -> void:
	if not local_controlled:
		return
	sleeping = false
	var upward_cancel := maxf(-linear_velocity.y * mass, 0.0)
	apply_central_impulse(Vector3.UP * (launch_impulse + upward_cancel))
	_post_fling_control_timer = maxf(_post_fling_control_timer, 0.08)
	_hit_visual(0.18)
	_launch_visual(0.72)
	bounce_counted.emit(launch_impulse)
	bounce_triggered.emit(launch_impulse)


func set_input_enabled(enabled: bool) -> void:
	input_enabled = enabled
	if not input_enabled:
		cancel_active_charge()
		_end_slide(false)
		_end_power_slide(false)


func cancel_active_charge() -> void:
	_is_charging_fling = false
	_maximum_charge_announced = false
	fling_charge = 0.0
	fling_charge_updated.emit(0.0)


func _tick_timers(delta: float) -> void:
	_physics_clock += delta
	_tick_quick_blob(delta)
	_hit_chain_timer = maxf(_hit_chain_timer - delta, 0.0)
	_bounce_buffer_timer = maxf(_bounce_buffer_timer - delta, 0.0)
	_bounce_cooldown_timer = maxf(_bounce_cooldown_timer - delta, 0.0)
	_shot_cooldown_timer = maxf(_shot_cooldown_timer - delta, 0.0)
	_post_fling_control_timer = maxf(_post_fling_control_timer - delta, 0.0)
	_recent_fling_timer = maxf(_recent_fling_timer - delta, 0.0)
	_fling_carry_timer = maxf(_fling_carry_timer - delta, 0.0)
	var previous_fling_cooldown := _fling_cooldown_timer
	_fling_cooldown_timer = maxf(_fling_cooldown_timer - delta, 0.0)
	if previous_fling_cooldown > 0.0:
		fling_cooldown_updated.emit(_fling_cooldown_timer, fling_cooldown_duration)
	_upward_cap_exempt_timer = maxf(_upward_cap_exempt_timer - delta, 0.0)
	_ground_settle_timer = maxf(_ground_settle_timer - delta, 0.0)
	_wall_kick_cooldown_timer = maxf(_wall_kick_cooldown_timer - delta, 0.0)
	_slam_cooldown_timer = maxf(_slam_cooldown_timer - delta, 0.0)
	_slide_recovery_timer = maxf(_slide_recovery_timer - delta, 0.0)
	_power_slide_recovery_timer = maxf(_power_slide_recovery_timer - delta, 0.0)


func _update_ground_state(delta: float) -> void:
	_grounded = false
	_ground_normal = Vector3.UP
	var minimum_up_dot := cos(deg_to_rad(ground_max_angle))
	if ground_cast != null:
		# The blob body rolls freely, but ground detection must always cast world-down.
		ground_cast.global_rotation = Vector3.ZERO
		ground_cast.force_shapecast_update()
		for index in range(ground_cast.get_collision_count()):
			var normal := ground_cast.get_collision_normal(index)
			if normal.dot(Vector3.UP) >= minimum_up_dot:
				_grounded = true
				_ground_normal = normal
				break
	elif get_contact_count() > 0 and absf(linear_velocity.y) < 3.5:
		_grounded = true
	if _grounded:
		_coyote_timer = coyote_time
		_air_jumps_left = COMBAT_TUNING.BLOB_AIR_JUMPS
	else:
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)
	_track_landing(delta)


func _track_landing(delta: float) -> void:
	if not _grounded:
		_airtime += delta
		_peak_fall_speed = maxf(_peak_fall_speed, -linear_velocity.y)
	elif not _was_grounded:
		if _airtime >= LANDING_MIN_AIRTIME and not _slamming:
			landed.emit(_peak_fall_speed)
		_airtime = 0.0
		_peak_fall_speed = 0.0
	_was_grounded = _grounded


func _update_bounce_input() -> void:
	if _action_just_pressed("bounce"):
		_bounce_buffer_timer = input_buffer_time
		_update_ground_state(0.0)
	if _bounce_buffer_timer <= 0.0:
		return
	if not _grounded and _coyote_timer <= 0.0:
		# Truly airborne: the same button becomes a slam (brake held) or a wall
		# kick (wall within reach). Neither available - keep the buffer so a
		# press just before touchdown still fires the ground bounce on landing.
		if _is_slam_requested() and _try_slam():
			return
		if _try_wall_kick():
			return
		if is_blob_mode() and _action_just_pressed("bounce"):
			_try_blob_air_jump()
		return
	if _bounce_cooldown_timer > 0.0 or _coyote_timer <= 0.0:
		return
	var launch_direction := (Vector3.UP * 0.74 + _ground_normal * 0.26).normalized()
	apply_central_impulse(launch_direction * bounce_boost_impulse)
	_bounce_buffer_timer = 0.0
	_bounce_cooldown_timer = bounce_boost_cooldown
	_coyote_timer = 0.0
	_hit_visual(0.12)
	_launch_visual(0.58)
	jumped.emit()
	bounce_counted.emit(bounce_boost_impulse)
	bounce_triggered.emit(bounce_boost_impulse)


func _apply_movement(delta: float) -> void:
	var movement_input := get_movement_input()
	var planar_velocity := Vector3(linear_velocity.x, 0.0, linear_velocity.z)
	if movement_input.length_squared() <= 0.001:
		_was_moving = false
		_movement_build_up = 0.0
		_movement_build_direction = Vector3.ZERO
		# Idle drag while rolling, and through the settle window between the
		# hops that follow a hard landing. A slide opts out - low drag
		# is the point of it.
		var touching_ground := get_contact_count() > 0 or _ground_settle_timer > 0.0
		if _grounded and touching_ground and not _sliding and not _power_sliding:
			apply_central_force(-planar_velocity * idle_ground_drag * mass)
		return

	var aim_basis := Basis(Vector3.UP, aim_yaw)
	var camera_forward := -aim_basis.z
	var camera_right := aim_basis.x
	var desired_direction := (camera_right * movement_input.x + camera_forward * -movement_input.y).normalized()
	# When direction changes sharply, preserve some build-up so turns feel responsive
	# instead of resetting to zero and suffering the full ramp-up delay again.
	if _movement_build_direction.length_squared() > 0.001 and _movement_build_direction.dot(desired_direction) < 0.72:
		_movement_build_up *= 0.6
	var control_multiplier := _charge_control_multiplier() * _post_fling_control_multiplier()
	if _sliding:
		# A slide keeps its heading; input only nudges it.
		control_multiplier *= slide_steer_multiplier
	elif _power_sliding:
		control_multiplier *= power_slide_steer_multiplier
	if not _grounded:
		_apply_air_steering(desired_direction, delta, control_multiplier)
		_was_moving = true
		_movement_build_up = 0.0
		_movement_build_direction = Vector3.ZERO
		return

	_movement_build_direction = desired_direction
	_movement_build_up = minf(_movement_build_up + delta, movement_build_up_time)
	if not _was_moving and _grounded:
		apply_central_impulse(desired_direction * ground_start_impulse * get_movement_multiplier() * control_multiplier)
	_was_moving = true

	var acceleration := ground_acceleration * get_movement_multiplier()
	var acceleration_factor := _movement_build_up_factor()
	var forward_speed := maxf(planar_velocity.dot(desired_direction), 0.0)
	# Ground input builds toward a controllable traversal band. Fling/impact
	# momentum above that band remains physical, but input can never amplify it.
	var speed_ratio := clampf(forward_speed / maxf(get_ground_control_speed(), 0.001), 0.0, 1.0)
	var control_headroom := 1.0 - pow(speed_ratio, ground_control_curve_exponent)
	acceleration_factor *= control_headroom

	if planar_velocity.length_squared() > 0.5 and planar_velocity.normalized().dot(desired_direction) < -0.18:
		acceleration += ground_counter_acceleration
		acceleration_factor = maxf(acceleration_factor, 0.42)
	apply_central_force(desired_direction * acceleration * mass * acceleration_factor * control_multiplier)
	var roll_axis := Vector3.UP.cross(desired_direction).normalized()
	apply_torque(roll_axis * movement_roll_torque * control_multiplier)


func _apply_air_steering(desired_direction: Vector3, delta: float, control_multiplier: float) -> void:
	# Force-based air control: applies a lateral steering force that redirects
	# existing momentum without adding net planar speed. This lets the physics
	# engine resolve the motion naturally instead of overriding velocity directly.
	var planar_velocity := Vector3(linear_velocity.x, 0.0, linear_velocity.z)
	var planar_speed := planar_velocity.length()
	if planar_speed <= 0.01:
		return
	var current_direction := planar_velocity.normalized()
	# Lateral component: how far "sideways" the desired direction is from current travel.
	var lateral := desired_direction - current_direction * desired_direction.dot(current_direction)
	if lateral.length_squared() <= 0.0001:
		return
	lateral = lateral.normalized()
	# Air-control curve: a small correction keeps full authority, a wide
	# reversal keeps only `air_reversal_steering_factor` of it, so committing to
	# a direction mid-air means something and precise adjustments stay crisp.
	var turn_ratio := clampf((1.0 - current_direction.dot(desired_direction)) * 0.5, 0.0, 1.0)
	var curve_gain := lerpf(1.0, air_reversal_steering_factor, pow(turn_ratio, air_control_curve_exponent))
	var steering_force := lateral * air_steering_strength * planar_speed * mass * control_multiplier * curve_gain * 4.0
	apply_central_force(steering_force)
	# Clamp planar speed so air input never amplifies momentum beyond entry speed.
	var next_planar := Vector3(linear_velocity.x, 0.0, linear_velocity.z)
	var next_speed := next_planar.length()
	if next_speed > planar_speed:
		var corrected := next_planar.normalized() * planar_speed
		linear_velocity = Vector3(corrected.x, linear_velocity.y, corrected.z)


func _movement_build_up_factor() -> float:
	var ratio := clampf(_movement_build_up / maxf(movement_build_up_time, 0.001), 0.0, 1.0)
	# Smoothstep keeps the opening movement deliberate while still reaching full force.
	var eased_ratio := ratio * ratio * (3.0 - 2.0 * ratio)
	return lerpf(movement_initial_acceleration_factor, 1.0, eased_ratio)


func _apply_brake(delta: float) -> void:
	if not _action_pressed("brake") or _is_charging_fling:
		_end_slide(false)
		return
	var planar_velocity := Vector3(linear_velocity.x, 0.0, linear_velocity.z)
	if planar_velocity.length_squared() <= 0.001:
		_end_slide(true)
		return
	# Above the slide threshold on the ground, brake is a low-drag momentum
	# slide first; it expires into the hard brake after `slide_duration`.
	var drag := slide_drag if _update_slide(delta, planar_velocity.length()) else brake_drag
	var retained_speed := exp(-maxf(drag, 0.0) * maxf(delta, 0.0))
	var next_planar_velocity := planar_velocity * retained_speed
	linear_velocity = Vector3(next_planar_velocity.x, linear_velocity.y, next_planar_velocity.z)


## Advances the slide state while brake is held. Returns true while sliding.
func _update_slide(delta: float, planar_speed: float) -> bool:
	if _sliding:
		_slide_timer += delta
		var exhausted := _slide_timer >= slide_duration
		var too_slow := planar_speed < slide_speed_threshold * SLIDE_EXIT_SPEED_FRACTION
		if exhausted or too_slow or not _grounded:
			_end_slide(true)
			return false
		# Hold the low stance: the visual's impact channel decays on its own,
		# so refreshing it every frame keeps the squash for the slide's length.
		_hit_visual(slide_squash)
		return true
	if _slide_spent or _slide_recovery_timer > 0.0 or not _grounded or planar_speed < slide_speed_threshold:
		return false
	_sliding = true
	_slide_timer = 0.0
	_hit_visual(slide_squash)
	slide_state_changed.emit(true)
	return true


## Leaves the slide. `spent` marks that brake is still held, so the next slide
## has to wait for a release; a plain release only starts the recovery timer.
func _end_slide(spent: bool) -> void:
	if _sliding:
		_sliding = false
		_slide_timer = 0.0
		_slide_recovery_timer = slide_recovery_time
		slide_state_changed.emit(false)
	_slide_spent = spent


func is_sliding() -> bool:
	return _sliding


## Power slide: hold slide on the ground for a burst of speed along a
## committed line. Brake, a fling charge or a slam cut it with no hop.
func _update_power_slide(delta: float) -> void:
	var held := _action_pressed("slide")
	if _is_charging_fling or _slamming or _action_pressed("brake"):
		_end_power_slide(held)
		return
	if not held:
		# Letting go is the ordinary way out, so it earns the hop.
		_end_power_slide(false, true)
		return
	if not _power_sliding:
		if not _power_slide_spent and _power_slide_recovery_timer <= 0.0 and _grounded:
			_start_power_slide()
		return
	_power_slide_timer += delta
	_power_slide_air_timer = 0.0 if _grounded else _power_slide_air_timer + delta
	if _power_slide_air_timer > power_slide_air_grace:
		_end_power_slide(true)
		return
	var planar_velocity := Vector3(linear_velocity.x, 0.0, linear_velocity.z)
	var too_slow := _power_slide_timer >= power_slide_min_time and planar_velocity.length() < power_slide_min_speed
	if too_slow or _power_slide_timer >= power_slide_duration:
		_end_power_slide(true, true)
		return
	var retained := planar_velocity * exp(-maxf(power_slide_drag, 0.0) * maxf(delta, 0.0))
	linear_velocity = Vector3(retained.x, linear_velocity.y, retained.z)
	# Hold the low stance: the impact channel decays on its own.
	_hit_visual(power_slide_squash)


func _start_power_slide() -> void:
	var planar_velocity := Vector3(linear_velocity.x, 0.0, linear_velocity.z)
	var heading := _input_world_direction()
	if heading.length_squared() <= 0.001:
		heading = planar_velocity.normalized() if planar_velocity.length_squared() > 1.0 else _forward_flat()
	var burst := clampf(power_slide_entry_speed_cap - planar_velocity.dot(heading), 0.0, power_slide_entry_boost)
	apply_central_impulse(heading * burst * mass)
	_power_sliding = true
	_power_slide_timer = 0.0
	_power_slide_air_timer = 0.0
	_hit_visual(power_slide_squash)
	_launch_visual(0.4)
	power_slide_changed.emit(true)


## Ends a power slide. `spent` marks that slide is still held, so the next one
## waits for a release. `hop` pops the blob up a little if it is on the ground.
func _end_power_slide(spent: bool, hop: bool = false) -> void:
	if _power_sliding:
		_power_sliding = false
		_power_slide_timer = 0.0
		_power_slide_air_timer = 0.0
		_power_slide_recovery_timer = power_slide_recovery_time
		if hop and _grounded:
			linear_velocity.y = maxf(linear_velocity.y, 0.0)
			apply_central_impulse(Vector3.UP * power_slide_exit_hop * mass)
			_launch_visual(0.45)
			power_slide_hopped.emit()
		power_slide_changed.emit(false)
	_power_slide_spent = spent


func is_power_sliding() -> bool:
	return _power_sliding


func is_slamming() -> bool:
	return _slamming


func is_wall_kick_ready() -> bool:
	return _wall_kick_cooldown_timer <= 0.0


## One-word movement state for telemetry and HUD readouts.
func get_movement_state() -> StringName:
	if _slamming:
		return &"slam"
	if _sliding:
		return &"slide"
	if _power_sliding:
		return &"power_slide"
	if _is_charging_fling:
		return &"charging"
	if _wall_kick_cooldown_timer > 0.0 and not _grounded:
		return &"wall_kick"
	return &"grounded" if _grounded else &"airborne"


## Slam is Space with brake held while airborne, or a dedicated `slam` action
## when the project binds one. This is the single input read the slam needs.
func _is_slam_requested() -> bool:
	if _action_pressed("brake"):
		return true
	return InputMap.has_action("slam") and _action_pressed("slam")


## Drives the blob straight down. Only valid while truly airborne (caller
## checks), once per `slam_cooldown`.
func _try_slam() -> bool:
	if _slamming or _slam_cooldown_timer > 0.0:
		return false
	sleeping = false
	var planar := Vector3(linear_velocity.x, 0.0, linear_velocity.z) * slam_planar_retention
	linear_velocity = Vector3(planar.x, -slam_downward_speed, planar.z)
	_slamming = true
	_bounce_buffer_timer = 0.0
	_hit_visual(0.1)
	_launch_visual(0.5)
	slam_started.emit()
	return true


## Keeps a slam diving until the solver has scrubbed the dive on a surface,
## then converts the touchdown into the heavy landing.
func _update_slam_state() -> void:
	if not _slamming:
		return
	var landed := _grounded and linear_velocity.y > -slam_downward_speed * SLAM_LANDED_SPEED_FRACTION
	if landed:
		_finish_slam_landing()
		return
	if linear_velocity.y > -slam_downward_speed:
		linear_velocity = Vector3(linear_velocity.x, -slam_downward_speed, linear_velocity.z)


func _finish_slam_landing() -> void:
	_slamming = false
	_slam_cooldown_timer = slam_cooldown
	# Refund the bounce so a buffered Space becomes a slam-jump, and reopen the
	# coyote window so that buffered press is honoured on this very frame.
	_bounce_cooldown_timer = 0.0
	_coyote_timer = coyote_time
	if linear_velocity.y > slam_landing_rebound_speed:
		linear_velocity = Vector3(linear_velocity.x, slam_landing_rebound_speed, linear_velocity.z)
	var strength := slam_downward_speed * slam_landing_strength_scale
	var severity := slam_downward_speed + slam_landing_severity_bonus
	_hit_visual(1.0)
	impact_event.emit(global_position, strength, severity)
	slam_landed.emit(severity)


## Sweeps horizontal rays around the blob and returns the normal of the
## nearest wall within `wall_kick_probe_distance` of its surface, or ZERO.
func _find_wall_kick_normal() -> Vector3:
	if not is_inside_tree():
		return Vector3.ZERO
	var space_state := get_world_3d().direct_space_state
	if space_state == null:
		return Vector3.ZERO
	if _wall_probe_query == null:
		_wall_probe_query = PhysicsRayQueryParameters3D.new()
		_wall_probe_query.collision_mask = collision_mask
		_wall_probe_query.exclude = [get_rid()]
	var reach := _collision_radius + wall_kick_probe_distance
	var max_normal_up := sin(deg_to_rad(wall_kick_max_surface_tilt))
	var origin := global_position
	var best_normal := Vector3.ZERO
	var best_distance := INF
	for index in range(WALL_KICK_PROBE_DIRECTIONS):
		var angle := TAU * float(index) / float(WALL_KICK_PROBE_DIRECTIONS)
		_wall_probe_query.from = origin
		_wall_probe_query.to = origin + Vector3(cos(angle), 0.0, sin(angle)) * reach
		var hit := space_state.intersect_ray(_wall_probe_query)
		if hit.is_empty():
			continue
		var normal := hit["normal"] as Vector3
		if absf(normal.y) > max_normal_up:
			continue
		var distance := origin.distance_to(hit["position"] as Vector3)
		if distance < best_distance:
			best_distance = distance
			best_normal = Vector3(normal.x, 0.0, normal.z).normalized()
	return best_normal


## Launches away from a nearby wall: the into-wall component of the incoming
## planar speed is reflected and scaled by `wall_kick_speed_retention`, then
## the kick impulse (lateral + small upward) is added on top.
func _try_wall_kick() -> bool:
	if _wall_kick_cooldown_timer > 0.0:
		return false
	var normal := _find_wall_kick_normal()
	if normal.length_squared() <= 0.001:
		return false
	sleeping = false
	var planar := Vector3(linear_velocity.x, 0.0, linear_velocity.z)
	var into_wall := minf(planar.dot(normal), 0.0)
	var reflected := (planar - 2.0 * into_wall * normal) * wall_kick_speed_retention
	var upward := maxf(linear_velocity.y, 0.0) * wall_kick_speed_retention + wall_kick_upward_impulse / mass
	var away := normal * (wall_kick_impulse / mass)
	linear_velocity = Vector3(reflected.x + away.x, upward, reflected.z + away.z)
	_last_wall_kick_normal = normal
	_wall_kick_cooldown_timer = wall_kick_cooldown
	_bounce_cooldown_timer = bounce_boost_cooldown
	_bounce_buffer_timer = 0.0
	_coyote_timer = 0.0
	_hit_visual(0.2)
	_launch_visual(0.7)
	bounce_counted.emit(wall_kick_impulse)
	bounce_triggered.emit(wall_kick_impulse)
	wall_kicked.emit(normal)
	return true


func _apply_fling_charge_drag() -> void:
	if not _is_charging_fling:
		return
	var charge_drag := maximum_fling_charge_drag * get_charge_ratio()
	if charge_drag <= 0.0:
		return
	apply_central_force(-linear_velocity * mass * charge_drag)


func _update_fling_charge(delta: float) -> void:
	if _action_just_pressed("charge_fling") and can_fling():
		_is_charging_fling = true
		_maximum_charge_announced = false
		fling_charge = 0.0
		fling_charge_started.emit()
	if _is_charging_fling and _action_pressed("charge_fling"):
		fling_charge = minf(fling_charge + delta * get_charge_rate_multiplier(), maximum_charge_time)
		var ratio := get_charge_ratio()
		fling_charge_updated.emit(ratio)
		if ratio >= 1.0 and not _maximum_charge_announced:
			_maximum_charge_announced = true
			fling_maximum_reached.emit()
	if _action_just_released("charge_fling") and _is_charging_fling:
		_release_fling(get_charge_ratio())


func _release_fling(charge_ratio: float) -> void:
	# The press was already gated by can_fling(), and the only thing that sets
	# the cooldown is this function - so re-checking is_fling_ready() here could
	# only ever swallow a charge the player legitimately built, with no
	# feedback. Void the charge on a real loss of control, nothing else.
	if not _accepts_input() or not local_controlled:
		cancel_active_charge()
		return
	var direction := aim_direction.normalized()
	if direction.length_squared() <= 0.001:
		direction = _forward_flat()
	direction = (direction + Vector3.UP * fling_upward_assist).normalized()
	var launch_strength := calculate_fling_strength(charge_ratio)
	var opposing_speed := maxf(-linear_velocity.dot(direction), 0.0)
	var correction_impulse := direction * opposing_speed * mass * 0.95
	apply_central_impulse(direction * launch_strength + correction_impulse)
	_post_fling_control_timer = fling_control_reduction_time * charge_ratio
	_recent_fling_timer = 0.65
	_fling_cooldown_timer = 0.0 if practice_skip_cooldowns else fling_cooldown_duration
	var curved_charge := pow(clampf(charge_ratio, 0.0, 1.0), charge_exponent)
	_fling_thrust_direction = direction
	_fling_thrust_target_speed = calculate_fling_thrust_speed(charge_ratio)
	_fling_thrust_timer = lerpf(fling_thrust_min_duration, fling_thrust_max_duration, curved_charge)
	_fling_thrust_last_speed = linear_velocity.dot(direction)
	_fling_speed_limit = _fling_thrust_target_speed + 4.0
	_fling_carry_timer = _fling_thrust_timer + post_fling_carry_time
	fling_cooldown_updated.emit(_fling_cooldown_timer, fling_cooldown_duration)
	_upward_cap_exempt_timer = 0.42
	_recent_fling_charge = charge_ratio
	_hit_visual(0.16)
	_launch_visual(0.34 + charge_ratio * 0.66)
	fling_released.emit(charge_ratio)
	cancel_active_charge()


func _apply_fling_thrust(delta: float) -> void:
	if _fling_thrust_timer <= 0.0:
		return
	_fling_thrust_timer = maxf(_fling_thrust_timer - delta, 0.0)
	var along_speed := linear_velocity.dot(_fling_thrust_direction)
	if _fling_thrust_last_speed - along_speed > fling_thrust_impact_speed_drop:
		_end_fling_thrust()
		return
	_fling_thrust_last_speed = along_speed
	var missing_speed := _fling_thrust_target_speed - along_speed
	if missing_speed <= 0.0:
		return
	# Never overshoot the target in one step: the last frame of the ramp only
	# adds what is missing, so the burst tops out cleanly at the charge speed.
	var acceleration := minf(fling_thrust_acceleration, missing_speed / maxf(delta, 0.001))
	apply_central_force(_fling_thrust_direction * acceleration * mass)
	sleeping = false


func _end_fling_thrust() -> void:
	_fling_thrust_timer = 0.0
	_fling_thrust_direction = Vector3.ZERO


func _update_shooting() -> void:
	if is_blob_mode():
		return
	if _action_just_pressed("shoot") and _shot_cooldown_timer <= 0.0:
		_emit_shot_request()


func _emit_shot_request() -> void:
	if not shooting_enabled or not input_enabled or not local_controlled or _shot_cooldown_timer > 0.0 or _shooting_locked or is_blob_mode():
		return
	var direction := aim_direction.normalized()
	if direction.length_squared() <= 0.001:
		direction = _forward_flat()
	var origin := global_position + direction * 3.75 + Vector3.UP * 0.25
	apply_central_impulse(-direction * shot_recoil_impulse + Vector3.UP * 1.4)
	_launch_visual(0.13)
	_shot_cooldown_timer = 0.0 if practice_unlimited_shots else shot_cooldown / get_fire_rate_multiplier()
	shoot_requested.emit(origin, direction)


func _charge_control_multiplier() -> float:
	if not _is_charging_fling:
		return 1.0
	var ratio := get_charge_ratio()
	return 1.0 if ratio <= 0.25 else lerpf(0.875, 0.5, (ratio - 0.25) / 0.75)


func set_equipped_ability(ability_id: String) -> void:
	_equipped_ability_id = ability_id


func get_equipped_ability() -> String:
	return _equipped_ability_id


func get_charge_rate_multiplier() -> float:
	var multiplier := ABILITY_TUNING.QUICK_CHARGE_MULTIPLIER if _equipped_ability_id == "quick_charge" else 1.0
	multiplier *= COMBAT_TUNING.BLOB_CHARGE_RATE_MULTIPLIER if is_blob_mode() else 1.0
	return multiplier * (ABILITY_TUNING.ADRENALINE_CHARGE_MULTIPLIER if _adrenaline_active else 1.0)


func get_movement_multiplier() -> float:
	var multiplier := COMBAT_TUNING.BLOB_SPEED_MULTIPLIER if is_blob_mode() else 1.0
	return multiplier * (ABILITY_TUNING.ADRENALINE_MOVEMENT_MULTIPLIER if _adrenaline_active else 1.0)


## Top of the input-driven ground speed band; the Blob slot raises it.
func get_ground_control_speed() -> float:
	var speed := ground_control_speed * (COMBAT_TUNING.BLOB_SPEED_MULTIPLIER if is_blob_mode() else 1.0)
	return speed * power_slide_speed_multiplier if _power_sliding else speed


## Hotbar ------------------------------------------------------------------

func set_hotbar_slot(slot: int) -> void:
	# Any explicit slot choice cancels a pending quick-blob snap-back.
	_quick_blob_timer = 0.0
	var safe_slot := clampi(slot, 0, COMBAT_TUNING.SLOT_COUNT - 1)
	if safe_slot == hotbar_slot:
		return
	hotbar_slot = safe_slot
	hotbar_slot_changed.emit(hotbar_slot)


## Equips the Blob for COMBAT_TUNING.QUICK_BLOB_SECONDS, then returns to the
## Blaster (see _tick_quick_blob).
func start_quick_blob() -> void:
	set_hotbar_slot(COMBAT_TUNING.SLOT_BLOB)
	_quick_blob_timer = COMBAT_TUNING.QUICK_BLOB_SECONDS


func _tick_quick_blob(delta: float) -> void:
	if _quick_blob_timer <= 0.0:
		return
	_quick_blob_timer -= delta
	if _quick_blob_timer <= 0.0:
		set_hotbar_slot(COMBAT_TUNING.SLOT_BLASTER)


func get_hotbar_slot() -> int:
	return hotbar_slot


func is_blob_mode() -> bool:
	return hotbar_slot == COMBAT_TUNING.SLOT_BLOB


func get_air_jumps_left() -> int:
	return _air_jumps_left


func _update_hotbar_input() -> void:
	if _action_just_pressed("slot_blaster"):
		set_hotbar_slot(COMBAT_TUNING.SLOT_BLASTER)
	elif _action_just_pressed("slot_blob"):
		set_hotbar_slot(COMBAT_TUNING.SLOT_BLOB)
	elif _action_just_pressed("quick_blob"):
		start_quick_blob()


## Blob-slot air jump: keeps the blob's planar speed but swings it onto the
## held movement direction (or keeps heading with no input), and pops it up.
## This is the instant direction change mid-flight.
func try_blob_air_jump_for_test() -> bool:
	return _try_blob_air_jump()


## The same air jump driven by an explicit world direction instead of the
## movement keys - how the bot swings back toward its target mid-flight.
func blob_air_jump_toward(world_direction: Vector3) -> bool:
	return _try_blob_air_jump(Vector3(world_direction.x, 0.0, world_direction.z).normalized())


func _try_blob_air_jump(direction_override := Vector3.ZERO) -> bool:
	if not is_blob_mode() or _air_jumps_left <= 0 or _grounded:
		return false
	var planar_velocity := Vector3(linear_velocity.x, 0.0, linear_velocity.z)
	var planar_speed := maxf(planar_velocity.length(), COMBAT_TUNING.BLOB_AIR_JUMP_MIN_PLANAR_SPEED)
	var direction := direction_override if direction_override.length_squared() > 0.001 else _input_world_direction()
	if direction.length_squared() <= 0.001:
		direction = planar_velocity.normalized() if planar_velocity.length_squared() > 0.01 else _forward_flat()
	var new_planar := direction * planar_speed
	linear_velocity = Vector3(new_planar.x, maxf(linear_velocity.y, 0.0) + COMBAT_TUNING.BLOB_AIR_JUMP_UP_SPEED, new_planar.z)
	sleeping = false
	_air_jumps_left -= 1
	_bounce_buffer_timer = 0.0
	_upward_cap_exempt_timer = maxf(_upward_cap_exempt_timer, 0.2)
	_hit_visual(0.14)
	_launch_visual(0.6)
	play_hit_flex(-direction, 60.0)
	air_jumped.emit(direction)
	bounce_triggered.emit(COMBAT_TUNING.BLOB_AIR_JUMP_UP_SPEED)
	return true


func _input_world_direction() -> Vector3:
	var movement_input := get_movement_input()
	if movement_input.length_squared() <= 0.001:
		return Vector3.ZERO
	var aim_basis := Basis(Vector3.UP, aim_yaw)
	return (aim_basis.x * movement_input.x - aim_basis.z * -movement_input.y).normalized()


## Visual-only dent/lean in the direction a hit pushes this blob. Safe to call
## on remote blobs, whose physics the host owns.
func play_hit_flex(push: Vector3, strength: float) -> void:
	var visual := get_node_or_null("VisualRoot") as BlobVisual
	if visual != null:
		visual.hit_flex(push, strength)


func is_adrenaline_active() -> bool:
	return _adrenaline_active


func get_adrenaline_fov_bonus() -> float:
	return ABILITY_TUNING.ADRENALINE_FOV_BONUS if _adrenaline_active else 0.0


func _update_adrenaline() -> void:
	_adrenaline_active = _equipped_ability_id == "adrenaline" and health > 0 and float(health) / maxf(float(max_health), 1.0) < ABILITY_TUNING.ADRENALINE_HEALTH_THRESHOLD


func set_overcharge_active(active: bool) -> void:
	_overcharge_active = active


func set_shooting_locked(locked: bool) -> void:
	_shooting_locked = locked


func get_fire_rate_multiplier() -> float:
	return ABILITY_TUNING.OVERCHARGE_FIRE_RATE_MULTIPLIER if _overcharge_active else 1.0


func set_scanner_highlight(enabled: bool) -> void:
	if _scanner_outline == null:
		_scanner_outline = MeshInstance3D.new()
		_scanner_outline.name = "ScannerOutline"
		_scanner_outline.mesh = SphereMesh.new()
		_scanner_outline.scale = Vector3.ONE * 1.19
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = Color(1.0, 0.08, 0.12, 0.3)
		material.emission_enabled = true
		material.emission = Color(1.0, 0.02, 0.06, 1.0)
		material.no_depth_test = true
		_scanner_outline.material_override = material
		$VisualRoot.add_child(_scanner_outline)
	_scanner_outline.visible = enabled


func set_phase_bubble(active: bool) -> void:
	_phase_bubble_active = active
	if _phase_bubble_visual == null:
		_phase_bubble_visual = MeshInstance3D.new()
		_phase_bubble_visual.name = "PhaseBubble"
		var bubble_mesh := SphereMesh.new()
		bubble_mesh.radius = 1.32
		bubble_mesh.height = 2.64
		_phase_bubble_visual.mesh = bubble_mesh
		var material := StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = Color(0.16, 0.8, 1.0, 0.14)
		material.emission_enabled = true
		material.emission = Color(0.1, 0.64, 1.0, 1.0)
		material.emission_energy_multiplier = 1.5
		_phase_bubble_visual.material_override = material
		$VisualRoot.add_child(_phase_bubble_visual)
	_phase_bubble_visual.visible = active


func receives_projectile_damage() -> bool:
	return not _phase_bubble_active


func _post_fling_control_multiplier() -> float:
	if _post_fling_control_timer <= 0.0 or fling_control_reduction_time <= 0.0:
		return 1.0
	var recovery := 1.0 - _post_fling_control_timer / fling_control_reduction_time
	return lerpf(fling_control_multiplier, 1.0, clampf(recovery, 0.0, 1.0))


func _apply_emergency_speed_guard() -> void:
	var speed := linear_velocity.length()
	var speed_limit := minf(maximum_movement_speed, emergency_max_speed)
	if _fling_carry_timer > 0.0:
		speed_limit = maxf(speed_limit, _fling_speed_limit)
	if speed > speed_limit:
		# Soft decay toward the cap instead of a hard snap — avoids jarring sudden stops.
		var decay_rate := 8.0
		var target_speed := lerpf(speed, speed_limit, 1.0 - exp(-decay_rate * get_physics_process_delta_time()))
		linear_velocity = linear_velocity.normalized() * target_speed


func _apply_momentum_decay(delta: float) -> void:
	var velocity := linear_velocity
	var speed := velocity.length()
	if speed <= 0.01:
		return
	var drag := 0.0
	if not _grounded:
		drag += air_momentum_decay
	# BUG-026: this used to read `post_fling_drag * get_fling_cooldown_ratio()`,
	# which is 1.0 on the launch frame - maximum drag applied at the exact
	# moment the impulse lands, decaying as the cooldown burned down. The fling
	# was fighting itself hardest when it should have carried. Invert it: no
	# drag during the carry window, then ramp up as the cooldown expires, so
	# speed has bled off by the time another fling is available. Same total
	# damping over the cooldown, non-chaining preserved, launch now reads.
	if _fling_cooldown_timer > 0.0 and _fling_carry_timer <= 0.0:
		drag += post_fling_drag * (1.0 - get_fling_cooldown_ratio())
	if speed > high_speed_drag_threshold and _fling_thrust_timer <= 0.0:
		var excess_ratio := clampf((speed - high_speed_drag_threshold) / maxf(maximum_movement_speed - high_speed_drag_threshold, 0.001), 0.0, 1.0)
		drag += high_speed_drag * excess_ratio
	if drag > 0.0:
		linear_velocity *= exp(-drag * delta)


func _apply_bounce_height_cap() -> void:
	if _upward_cap_exempt_timer > 0.0 or linear_velocity.y <= max_bounce_upward_speed:
		return
	linear_velocity = Vector3(linear_velocity.x, max_bounce_upward_speed, linear_velocity.z)


## Remote blobs replay the host's snapshots INTERPOLATION_DELAY_MSEC behind
## the host clock, so motion is what the host saw rather than a chase toward
## the newest packet. When the buffer runs dry the last snapshot coasts on its
## velocity for at most MAX_EXTRAPOLATION_MSEC, then holds; a respawn or blink
## clears the buffer and snaps.
func _update_remote_transform(_delta: float) -> void:
	if _remote_snapshots.is_empty():
		return
	_apply_remote_sample(_remote_render_time_msec())


## Host clock to render at: the session's ping-derived estimate when it has
## one, else the buffer's own arrival-based guess so a blob still moves before
## the first pong lands.
func _remote_render_time_msec() -> int:
	var local_now := Time.get_ticks_msec()
	var host_now := local_now
	var session := get_node_or_null("/root/NetworkSession") as DuelNetworkSession
	if session != null and session.has_clock_sync():
		host_now = session.get_host_time_msec()
	else:
		host_now = _remote_snapshots.estimate_host_time_msec(local_now)
	return host_now - NETWORK_TUNING.INTERPOLATION_DELAY_MSEC


## Positions the blob at `render_time_msec` on the host clock. Split from
## _update_remote_transform so a contract can drive it with synthetic times.
func _apply_remote_sample(render_time_msec: int) -> void:
	var sample := _remote_snapshots.sample(render_time_msec)
	if sample.mode == RemoteSnapshotBuffer.Mode.EMPTY:
		return
	_remote_snapshots.consume_teleport()
	global_position = sample.position
	rotation = sample.rotation
	linear_velocity = sample.velocity
	_network_target_position = sample.position
	_network_target_rotation = sample.rotation


## True when `body` is a surface the blob is currently resting on, as opposed to
## something it ran into. Uses the ground cast so a wall taken while grounded is
## still scored as a real impact.
func _is_floor_contact(body: Node) -> bool:
	if not _grounded or ground_cast == null:
		return false
	# The cast also reports a wall the body has just penetrated, so identity
	# alone is not enough: the surface must face up like a floor too.
	var minimum_up_dot := cos(deg_to_rad(ground_max_angle))
	for index in range(ground_cast.get_collision_count()):
		if ground_cast.get_collider(index) == body and ground_cast.get_collision_normal(index).dot(Vector3.UP) >= minimum_up_dot:
			return true
	return false


func _on_body_entered(body: Node) -> void:
	if not local_controlled:
		return
	var impact_strength := linear_velocity.length()
	# BUG-030: rolling along the floor re-fires body_entered constantly, and
	# total speed is the wrong severity measure - a blob cruising the ground at
	# 30 m/s is not impacting anything, but it used to emit an impact every
	# contact and shake the camera. Score a floor contact by how fast the blob
	# is driving *into* it (vertical closing speed) and everything else - walls,
	# props, airborne hits - by full speed.
	var floor_contact := _is_floor_contact(body)
	var impact_severity := absf(linear_velocity.y) if floor_contact else impact_strength
	if floor_contact:
		_ground_settle_timer = ground_settle_window
		_apply_landing_scrub(impact_severity)
	# BUG-030 follow-up: gate presentation on the original total-speed threshold
	# so particles and hit audio keep firing on every real contact, rolling
	# included. Only the shake consumes `impact_severity`.
	# A slam touchdown emits its own, heavier impact from _finish_slam_landing;
	# the generic contact event would only dilute it with a second burst.
	if impact_strength >= 7.0 and not _slamming:
		impact_event.emit(global_position, impact_strength, impact_severity)
	if impact_strength < surface_bounce_min_speed:
		return
	var body_id := body.get_instance_id()
	if _physics_clock >= float(_bounce_count_ready_at.get(body_id, 0.0)):
		_bounce_count_ready_at[body_id] = _physics_clock + BOUNCE_COUNT_DEBOUNCE_SECONDS
		bounce_counted.emit(impact_strength)


## Friction at touchdown: a hard landing scrubs a slice of planar speed scaled
## by how fast the blob came down. A buffered bounce (Space pressed just before
## touchdown) fires this same frame and keeps the momentum - the bunny hop.
func _apply_landing_scrub(vertical_speed: float) -> void:
	if _bounce_buffer_timer > 0.0 or landing_scrub <= 0.0:
		return
	var span := maxf(landing_scrub_full_speed - landing_scrub_min_speed, 0.001)
	var weight := clampf((vertical_speed - landing_scrub_min_speed) / span, 0.0, 1.0)
	if weight <= 0.0:
		return
	var retained := 1.0 - landing_scrub * weight
	linear_velocity = Vector3(linear_velocity.x * retained, linear_velocity.y, linear_velocity.z * retained)


func _restore_surface_collision_speed(retained_speed: float) -> void:
	# Legacy hook retained for interactables/tests. Surface impacts are intentionally
	# lossy now; never add energy back after the physics solver resolves a bounce.
	var allowed_speed := minf(retained_speed, maximum_movement_speed)
	if linear_velocity.length() > allowed_speed:
		linear_velocity = linear_velocity.normalized() * allowed_speed


func _on_contact_area_entered(area: Area3D) -> void:
	if not local_controlled:
		return
	var other := area.get_parent() as RigidBody3D
	if other == null or other == self:
		return
	var is_network_blob := other.is_in_group("network_blob")
	var target_peer_id := int(other.get("network_peer_id")) if is_network_blob else 0
	if is_network_blob:
		if network_peer_id >= target_peer_id:
			return
	elif other.get_instance_id() < get_instance_id():
		return

	var now := Time.get_ticks_msec()
	var pair_key := other.get_instance_id()
	if now < int(_collision_ready_at.get(pair_key, 0)):
		return
	_collision_ready_at[pair_key] = now + int(collision_pair_cooldown * 1000.0)

	var normal := (other.global_position - global_position).normalized()
	if normal.length_squared() < 0.01:
		return
	var relative_velocity := linear_velocity - other.linear_velocity
	var closing_speed := relative_velocity.dot(normal)
	if closing_speed < 3.0:
		return

	var self_toward := linear_velocity.dot(normal)
	var other_toward := -other.linear_velocity.dot(normal)
	var self_is_attacker := self_toward >= other_toward
	var attacker_speed := linear_velocity.length() if self_is_attacker else other.linear_velocity.length()
	var fling_multiplier := 1.0 + _recent_fling_charge * 1.15 if self_is_attacker and _recent_fling_timer > 0.0 else 1.0
	var attacker: Node = self if self_is_attacker else other
	var ram_multiplier := COMBAT_TUNING.BLOB_RAM_DAMAGE_MULTIPLIER if attacker.has_method("is_blob_mode") and bool(attacker.call("is_blob_mode")) else 1.0
	var raw_damage := maxf(closing_speed - 5.0, 0.0) * impact_damage_scale + maxf(attacker_speed - 13.0, 0.0) * velocity_damage_scale
	var collision_damage := 0 if raw_damage < 5.0 else clampi(int(round(raw_damage * fling_multiplier * ram_multiplier)), 5, 60)
	var impulse_strength := clampf(closing_speed * minf(mass, other.mass) * 1.9 * fling_multiplier, 14.0, 230.0)
	var impulse := (normal + Vector3.UP * 0.08).normalized() * impulse_strength
	var self_damage := 0 if self_is_attacker else collision_damage
	var other_damage := collision_damage if self_is_attacker else 0
	receive_collision_impact(self_damage, -impulse)
	if other.has_method("play_hit_flex"):
		other.call("play_hit_flex", impulse, impulse.length())
	if is_network_blob:
		network_collision_requested.emit(target_peer_id, impulse, other_damage)
	elif other.has_method("receive_collision_impact"):
		other.call("receive_collision_impact", other_damage, impulse)
	else:
		other.sleeping = false
		other.apply_central_impulse(impulse)


func _hit_visual(amount: float) -> void:
	var visual := get_node_or_null("VisualRoot") as BlobVisual
	if visual != null:
		visual.hit_reaction(amount)


func _launch_visual(amount: float) -> void:
	var visual := get_node_or_null("VisualRoot") as BlobVisual
	if visual != null:
		visual.set_launch_energy(amount)


func _update_speed_trail() -> void:
	if speed_trail != null:
		var speed_span := maxf(trail_full_speed - trail_start_speed, 0.001)
		var speed_ratio := clampf((linear_velocity.length() - trail_start_speed) / speed_span, 0.0, 1.0)
		# A slam dives at full trail density regardless of the speed mapping so
		# the ground pound reads from across the arena.
		if _slamming:
			speed_ratio = 1.0
		speed_trail.emitting = speed_ratio > 0.06 or _recent_fling_timer > 0.0 or _slamming
		# BUG-028: assigning GPUParticles3D.amount reallocates the particle
		# buffer and restarts the system, so writing it every frame was both a
		# per-frame allocation and a visible trail hitch. Only write on change.
		var next_amount := maxi(1, int(round(float(_trail_base_amount) * lerpf(0.55, 1.0, speed_ratio))))
		if speed_trail.amount != next_amount:
			speed_trail.amount = next_amount
		speed_trail.lifetime = _trail_base_lifetime * lerpf(0.55, 1.0, speed_ratio)


func _forward_flat() -> Vector3:
	var forward := -Basis(Vector3.UP, aim_yaw).z
	return Vector3(forward.x, 0.0, forward.z).normalized()


func _update_face() -> void:
	if face_root == null or not is_inside_tree():
		return
	var direction := aim_direction.normalized()
	if direction.length_squared() <= 0.001:
		direction = _forward_flat()
	var up := Vector3.FORWARD if absf(direction.dot(Vector3.UP)) > 0.97 else Vector3.UP
	# Rebuilt from scratch every frame: Node3D.look_at keeps the node's current
	# scale, so layering the flex onto the previous frame's basis compounded it
	# into a smeared face. Orientation first, then this frame's flex only.
	var face_basis := Basis.looking_at(direction, up)
	var visual := get_node_or_null("VisualRoot") as BlobVisual
	if visual != null:
		face_basis = visual.get_flex_basis() * face_basis
	face_root.global_transform = Transform3D(face_basis, global_position)


func _update_health_billboard() -> void:
	if name_label != null:
		name_label.text = display_name
	if health_fill != null:
		var health_ratio := clampf(float(health) / maxf(float(max_health), 1.0), 0.0, 1.0)
		health_fill.scale = Vector3(health_ratio, 1.0, 1.0)
		# Keep the left edge fixed so damage reads as a conventional depleting bar.
		health_fill.position.x = -1.38 * (1.0 - health_ratio)


func _update_nameplate_transform() -> void:
	if nameplate_root == null:
		return
	nameplate_root.global_position = global_position + Vector3.UP * 4.65
	# The fill and backing quads used to billboard per-material, which rotates
	# each quad around its own origin - at any viewing angle the two pivoted
	# apart and read as separate floating shapes. Orient the whole nameplate as
	# one rigid assembly instead (same camera-basis alignment BILLBOARD_ENABLED
	# uses), so the bar always stays fused.
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	if camera != null:
		nameplate_root.global_basis = camera.global_basis
	else:
		nameplate_root.global_rotation = Vector3.ZERO
	var active_camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	if active_camera != null:
		update_nameplate_for_camera(active_camera.global_position)


## Blobs carry no floating name tag or health bar (health lives in the HUD).
## The Nameplate node stays so the health fill keeps tracking for tests and
## previews, but it is never shown.
func update_nameplate_for_camera(_camera_position: Vector3) -> void:
	if nameplate_root != null:
		nameplate_root.visible = false
