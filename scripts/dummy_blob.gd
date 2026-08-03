extends RigidBody3D

signal health_changed(current_health: int, max_health: int)

@export var max_health := 150
@export var respawn_delay := 0.55
@export var blob_color := Color(1.0, 0.38, 0.18, 1.0)
@export var display_name := ""

const FUNNY_NAMES: PackedStringArray = [
	"Bob", "Sir Bounces", "Jellybean", "Wobbleton",
	"Mochi", "Boop", "Captain Squish", "Pogo",
	"Noodle", "Sprinkles", "Bloop", "Pickles",
	"Gumdrop", "Tater Tot", "Biscuit", "Wiggles",
]

var health := 150
var _spawn_position := Vector3.ZERO
var _respawn_timer := 0.0
var _collision_ready_at: Dictionary = {}
@onready var nameplate_root: Node3D = $Nameplate
@onready var name_label: Label3D = $Nameplate/Name
@onready var health_fill: MeshInstance3D = $Nameplate/HealthFill
@onready var mesh: MeshInstance3D = $VisualRoot/Mesh
@onready var face_root: Node3D = $FaceRoot

var _face_direction := Vector3.FORWARD
var _scanner_outline: MeshInstance3D


func _ready() -> void:
	can_sleep = true
	contact_monitor = true
	max_contacts_reported = 12
	$ContactArea.area_entered.connect(_on_contact_area_entered)
	_spawn_position = global_position
	if display_name.strip_edges().is_empty():
		display_name = _stable_funny_name()
	health = max_health
	health_changed.emit(health, max_health)
	_apply_blob_color()
	_update_health_billboard()


func _physics_process(delta: float) -> void:
	if global_position.y < -15.0:
		respawn()

	if _respawn_timer > 0.0:
		_respawn_timer -= delta
		if _respawn_timer <= 0.0:
			respawn()
	var flat_velocity := Vector3(linear_velocity.x, 0.0, linear_velocity.z)
	if flat_velocity.length_squared() > 1.0:
		_face_direction = _face_direction.lerp(flat_velocity.normalized(), 1.0 - exp(-5.0 * delta)).normalized()
	_update_face()
	_update_nameplate_transform()


func take_damage(amount: int, hit_direction: Vector3, knockback: float) -> void:
	if _respawn_timer > 0.0:
		return

	health = max(health - amount, 0)
	health_changed.emit(health, max_health)
	_update_health_billboard()
	sleeping = false
	var launch_direction := (hit_direction.normalized() + Vector3.UP * 0.42).normalized()
	apply_central_impulse(launch_direction * knockback * 1.55)
	var visual := get_node_or_null("VisualRoot")
	if visual != null and visual.has_method("hit_reaction"):
		visual.hit_reaction(0.72)

	if health <= 0:
		_respawn_timer = respawn_delay


func receive_collision_impact(amount: int, impulse: Vector3) -> void:
	if _respawn_timer > 0.0:
		return
	sleeping = false
	var lift := Vector3.UP * clampf(impulse.length() * 0.36, 8.0, 50.0)
	apply_central_impulse((impulse + lift) * 1.2)
	var visual := get_node_or_null("VisualRoot")
	if visual != null and visual.has_method("hit_reaction"):
		visual.hit_reaction(clampf(impulse.length() * 0.012, 0.3, 0.9))
	if amount <= 0:
		return
	health = maxi(health - amount, 0)
	health_changed.emit(health, max_health)
	_update_health_billboard()
	if health <= 0:
		_respawn_timer = respawn_delay


func respawn() -> void:
	freeze = true
	global_position = _spawn_position
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	reset_physics_interpolation()
	sleeping = false
	freeze = false
	health = max_health
	_respawn_timer = 0.0
	health_changed.emit(health, max_health)
	_update_health_billboard()


func _update_health_billboard() -> void:
	if name_label != null:
		name_label.text = display_name
	if health_fill != null:
		var health_ratio := clampf(float(health) / maxf(float(max_health), 1.0), 0.0, 1.0)
		health_fill.scale = Vector3(health_ratio, 1.0, 1.0)


func _update_nameplate_transform() -> void:
	if nameplate_root == null:
		return
	nameplate_root.global_position = global_position + Vector3.UP * 5.35
	nameplate_root.global_rotation = Vector3.ZERO


func _stable_funny_name() -> String:
	# Scene-node identity makes names feel randomly assigned while remaining
	# deterministic across respawns, replays, and multiplayer test runs.
	var stable_hash := absi(String(name).hash())
	return FUNNY_NAMES[stable_hash % FUNNY_NAMES.size()]


func _apply_blob_color() -> void:
	if mesh == null:
		return

	var material := StandardMaterial3D.new()
	material.albedo_color = blob_color
	material.metallic = 0.08
	material.roughness = 0.28
	material.emission_enabled = true
	material.emission = blob_color.darkened(0.48)
	material.emission_energy_multiplier = 0.35
	mesh.material_override = material
	if name_label != null:
		name_label.modulate = blob_color.lightened(0.35)


func set_scanner_highlight(enabled: bool) -> void:
	if _scanner_outline == null:
		_scanner_outline = MeshInstance3D.new()
		_scanner_outline.name = "ScannerOutline"
		var outline_mesh := SphereMesh.new()
		outline_mesh.radius = 1.18
		outline_mesh.height = 2.36
		_scanner_outline.mesh = outline_mesh
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = Color(1.0, 0.12, 0.16, 0.3)
		material.emission_enabled = true
		material.emission = Color(1.0, 0.03, 0.08)
		material.emission_energy_multiplier = 1.8
		material.no_depth_test = true
		_scanner_outline.material_override = material
		$VisualRoot.add_child(_scanner_outline)
	_scanner_outline.visible = enabled


func _update_face() -> void:
	if face_root == null or not is_inside_tree():
		return
	face_root.global_position = global_position
	face_root.look_at(global_position + _face_direction, Vector3.UP)


func _on_contact_area_entered(area: Area3D) -> void:
	var other := area.get_parent() as RigidBody3D
	if other == null or other == self or other.get_instance_id() < get_instance_id():
		return
	if other.is_in_group("network_blob") and not bool(other.get("local_controlled")):
		return

	var now := Time.get_ticks_msec()
	if now < int(_collision_ready_at.get(other.get_instance_id(), 0)):
		return
	_collision_ready_at[other.get_instance_id()] = now + 160
	var normal := (other.global_position - global_position).normalized()
	if normal.length_squared() < 0.01:
		normal = linear_velocity.normalized()

	var relative_velocity := linear_velocity - other.linear_velocity
	var closing_speed: float = relative_velocity.dot(normal)
	if closing_speed < 3.0:
		return

	var impulse_strength: float = clampf(closing_speed * minf(mass, other.mass) * 1.9, 14.0, 230.0)
	var impulse := (normal + Vector3.UP * 0.08).normalized() * impulse_strength
	sleeping = false
	other.sleeping = false
	apply_central_impulse(-impulse)
	other.apply_central_impulse(impulse)
	var visual := get_node_or_null("VisualRoot")
	if visual != null and visual.has_method("hit_reaction"):
		visual.hit_reaction(clampf(impulse_strength * 0.012, 0.24, 0.72))
	var other_visual := other.get_node_or_null("VisualRoot")
	if other_visual != null and other_visual.has_method("hit_reaction"):
		other_visual.hit_reaction(clampf(impulse_strength * 0.012, 0.24, 0.72))
