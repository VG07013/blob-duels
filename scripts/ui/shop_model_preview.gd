extends SubViewportContainer

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const ABILITY_HUD_SCRIPT := preload("res://scripts/ui/ability_hud.gd")
const COSMETIC_LIBRARY := preload("res://scripts/cosmetic_library.gd")
const IMPACT_BURST_SCENE := preload("res://scenes/effects/impact_burst.tscn")

var _category := "skins"
var _item: Dictionary = {}
var _preview_player: RigidBody3D
var _model_root: Node3D
var _viewport: SubViewport
var _ability_icon: TextureRect
var _camera: Camera3D
var _phase := 0.0
var _yaw := 0.0
var _dragging := false
var _effect_clock := 0.0
var _last_pointer_x := 0.0


func set_item(category: String, item: Dictionary, _accent: Color = Color.WHITE) -> void:
	_category = category
	_item = item.duplicate(true)
	if is_node_ready():
		_apply_item()


func get_preview_signature() -> Dictionary:
	var item_id := str(_item.get("id", ""))
	var runtime_effect := str(_item.get("runtime_effect", item_id))
	return {
		"category": _category,
		"id": item_id,
		"visual_signature": "%s:%s:%s" % [_category, item_id, runtime_effect],
		"uses_player_scene": _preview_player != null,
		"uses_subviewport": _viewport != null,
		"renderer": "runtime_player" if _category != "abilities" else "ability_vignette",
		"runtime_effect": runtime_effect,
		"interactive_rotation": true,
	}


func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_build_preview_world()
	_apply_item()


func _process(delta: float) -> void:
	_phase = fmod(_phase + delta, TAU)
	_effect_clock += delta
	if _model_root != null:
		if not _dragging:
			_yaw = lerpf(_yaw, sin(_phase * 0.42) * 0.34, minf(1.0, delta * 1.4))
		_model_root.rotation.y = _yaw
		_model_root.position.y = sin(_phase * 1.2) * 0.08
	if _preview_player != null:
		var trail := _preview_player.get_node_or_null("SpeedTrail") as GPUParticles3D
		if trail != null:
			trail.emitting = _category == "trails"
	if _category == "kill_effects" and _effect_clock >= 2.35:
		replay()


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		_dragging = button.pressed
		_last_pointer_x = button.position.x
		accept_event()
		return
	var motion := event as InputEventMouseMotion
	if motion != null and _dragging:
		_yaw += (motion.position.x - _last_pointer_x) * 0.012
		_last_pointer_x = motion.position.x
		accept_event()


func replay() -> void:
	_effect_clock = 0.0
	if _category == "kill_effects":
		_spawn_preview_effect(str(_item.get("id", "bubble_pop")))
	elif _category == "abilities" and _ability_icon != null:
		var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		_ability_icon.scale = Vector2(0.82, 0.82)
		tween.tween_property(_ability_icon, "scale", Vector2(1.12, 1.12), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(_ability_icon, "scale", Vector2.ONE, 0.2)


func _build_preview_world() -> void:
	_viewport = SubViewport.new()
	_viewport.name = "ModelViewport"
	_viewport.size = Vector2i(420, 320)
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)

	_model_root = Node3D.new()
	_model_root.name = "PreviewRig"
	_viewport.add_child(_model_root)

	var environment := WorldEnvironment.new()
	var environment_resource := Environment.new()
	environment_resource.background_mode = Environment.BG_COLOR
	environment_resource.background_color = Color(0.025, 0.032, 0.05, 0.0)
	environment_resource.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment_resource.ambient_light_color = Color(0.48, 0.62, 0.82)
	environment_resource.ambient_light_energy = 0.72
	environment.environment = environment_resource
	_viewport.add_child(environment)

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-34.0, -28.0, 0.0)
	key_light.light_color = Color(0.82, 0.93, 1.0)
	key_light.light_energy = 1.25
	_viewport.add_child(key_light)

	var rim_light := OmniLight3D.new()
	rim_light.position = Vector3(-4.5, 3.5, 3.5)
	rim_light.light_color = Color(0.2, 0.82, 1.0)
	rim_light.light_energy = 3.0
	rim_light.omni_range = 11.0
	_viewport.add_child(rim_light)

	_camera = Camera3D.new()
	_camera.fov = 40.0
	_viewport.add_child(_camera)
	_camera.look_at_from_position(Vector3(0.0, 0.4, 10.5), Vector3(0.0, 0.1, 0.0), Vector3.UP)

	_preview_player = PLAYER_SCENE.instantiate() as RigidBody3D
	_preview_player.name = "InGameBlobModel"
	_model_root.add_child(_preview_player)
	_preview_player.freeze = true
	_preview_player.collision_layer = 0
	_preview_player.collision_mask = 0
	_preview_player.set_process_input(false)
	_preview_player.set_process_unhandled_input(false)
	_preview_player.set_physics_process(false)
	var visual_root := _preview_player.get_node_or_null("VisualRoot") as Node3D
	var face_root := _preview_player.get_node_or_null("FaceRoot") as Node3D
	if visual_root != null:
		visual_root.top_level = false
		visual_root.position = Vector3.ZERO
	if face_root != null:
		face_root.top_level = false
		face_root.position = Vector3.ZERO
	var nameplate := _preview_player.get_node_or_null("Nameplate") as Node3D
	if nameplate != null:
		nameplate.visible = false
	for area_path in ["Hurtbox", "ContactArea"]:
		var area := _preview_player.get_node_or_null(area_path) as Area3D
		if area != null:
			area.monitoring = false
			area.monitorable = false

	_ability_icon = TextureRect.new()
	_ability_icon.name = "AbilityIcon"
	_ability_icon.set_anchors_preset(Control.PRESET_CENTER)
	_ability_icon.position = Vector2(-46, -46)
	_ability_icon.size = Vector2(92, 92)
	_ability_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ability_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_ability_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ability_icon.visible = false
	add_child(_ability_icon)


func _apply_item() -> void:
	if _preview_player == null:
		return
	var progression := get_node_or_null("/root/Progression")
	var skin_id := "classic_blue"
	var trail_id := "bubble"
	var face_id := "happy"
	var kill_id := "bubble_pop"
	if progression != null:
		skin_id = str(progression.call("get_equipped", "skins"))
		trail_id = str(progression.call("get_equipped", "trails"))
		face_id = str(progression.call("get_equipped", "faces"))
		kill_id = str(progression.call("get_equipped", "kill_effects"))
	var item_id := str(_item.get("id", ""))
	match _category:
		"skins": skin_id = item_id
		"trails": trail_id = item_id
		"faces": face_id = item_id
		"kill_effects": kill_id = item_id
	_preview_player.call("set_blob_color", Color(0.02, 0.86, 1.0))
	_preview_player.call("apply_equipped_cosmetics", skin_id, trail_id, face_id, kill_id)
	_ability_icon.visible = _category == "abilities"
	_ability_icon.texture = ABILITY_HUD_SCRIPT.get_icon(item_id) if _category == "abilities" else null
	_ability_icon.pivot_offset = _ability_icon.size * 0.5
	_model_root.visible = true
	if _camera != null:
		var distance := 8.7 if _category == "faces" else 10.5
		_camera.fov = 34.0 if _category == "faces" else 40.0
		_camera.look_at_from_position(Vector3(0.0, 0.45, distance), Vector3(0.0, 0.15, 0.0), Vector3.UP)
	_effect_clock = 2.0 if _category == "kill_effects" else 0.0
	if _category == "kill_effects":
		call_deferred("replay")


func _spawn_preview_effect(effect_id: String) -> void:
	if _viewport == null:
		return
	var profile := COSMETIC_LIBRARY.kill_profile(effect_id)
	var effect := IMPACT_BURST_SCENE.instantiate()
	_viewport.add_child(effect)
	effect.call("configure", Vector3(0.0, 0.0, 0.0), profile.get("color", Color.WHITE), 1.35, 2, effect_id)
