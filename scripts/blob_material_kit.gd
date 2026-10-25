class_name BlobMaterialKit
extends RefCounted

const COMBAT_TUNING := preload("res://scripts/combat_tuning.gd")

## Shared "gel" finish for every blob body material. Blobs are the stars of
## the arena, so each colour path (team colour, skins, dummies) routes through
## here: the rim keeps their silhouette readable against any map, the
## backlight fakes light bleeding through the jelly, and the clearcoat gives
## the wet-candy highlight.


static func decorate(material: StandardMaterial3D, base_color: Color) -> StandardMaterial3D:
	material.clearcoat_enabled = true
	material.clearcoat = 0.68
	material.clearcoat_roughness = 0.13
	material.rim_enabled = true
	material.rim = 0.5
	material.rim_tint = 0.5
	# Metal skins read as solid, not jelly: fade the translucency out with
	# metallic instead of hard-switching so mixed skins stay coherent.
	var translucency := 1.0 - material.metallic
	material.backlight_enabled = translucency > 0.05
	material.backlight = Color(base_color.lightened(0.4) * (0.34 * translucency), 1.0)
	# Visibility floor: a faint self-glow keeps blobs readable in shadowed or
	# dark-map areas. Skins that author their own emission (lava, neon, ...)
	# keep it - this only fills the gap for unlit bodies.
	if not material.emission_enabled:
		material.emission_enabled = true
		material.emission = base_color
		material.emission_energy_multiplier = 0.26
	return material


## Cartoon inverted-hull outline: an unshaded, front-culled copy of the body
## sphere, slightly inflated, in a darkened shade of the blob's colour. Child
## of the body mesh so it inherits squash-and-stretch. Re-entrant: repeated
## calls (team colour then skin swap) reuse the shell and just recolour it.
static func apply_outline(body_mesh: MeshInstance3D, base_color: Color) -> void:
	if body_mesh == null:
		return
	var shell := body_mesh.get_node_or_null("OutlineShell") as MeshInstance3D
	if shell == null:
		shell = MeshInstance3D.new()
		shell.name = "OutlineShell"
		shell.mesh = body_mesh.mesh
		shell.scale = Vector3.ONE * 1.045
		shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		body_mesh.add_child(shell)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_FRONT
	material.albedo_color = base_color.darkened(0.68)
	shell.material_override = material


## Damage feedback: tints the body red through `material_overlay` and pops a
## bright red inverted-hull outline, then fades both out. Lives on its own
## overlay and shell, so a skin or colour swap mid-flash never fights it.
## Repeat hits restart the flash from full strength.
static func flash_hit(body_mesh: MeshInstance3D) -> void:
	if body_mesh == null or not body_mesh.is_inside_tree():
		return
	var tint := body_mesh.get_meta("hit_flash_tint", null) as StandardMaterial3D
	if tint == null:
		tint = StandardMaterial3D.new()
		tint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		tint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		body_mesh.set_meta("hit_flash_tint", tint)
	var outline := body_mesh.get_node_or_null("HitFlashOutline") as MeshInstance3D
	if outline == null:
		outline = MeshInstance3D.new()
		outline.name = "HitFlashOutline"
		outline.mesh = body_mesh.mesh
		outline.scale = Vector3.ONE * COMBAT_TUNING.HIT_FLASH_OUTLINE_SCALE
		outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var shell_material := StandardMaterial3D.new()
		shell_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		shell_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		shell_material.cull_mode = BaseMaterial3D.CULL_FRONT
		outline.material_override = shell_material
		body_mesh.add_child(outline)
	var outline_material := outline.material_override as StandardMaterial3D
	var previous := body_mesh.get_meta("hit_flash_tween", null) as Tween
	if previous != null and previous.is_valid():
		previous.kill()
	var color := COMBAT_TUNING.HIT_FLASH_COLOR
	tint.albedo_color = Color(color, COMBAT_TUNING.HIT_FLASH_TINT_ALPHA)
	outline_material.albedo_color = Color(color, 1.0)
	body_mesh.material_overlay = tint
	outline.visible = true
	var tween := body_mesh.create_tween().set_parallel(true)
	tween.tween_property(tint, "albedo_color:a", 0.0, COMBAT_TUNING.HIT_FLASH_SECONDS).set_ease(Tween.EASE_IN)
	tween.tween_property(outline_material, "albedo_color:a", 0.0, COMBAT_TUNING.HIT_FLASH_SECONDS).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(func() -> void:
		body_mesh.material_overlay = null
		outline.visible = false
	)
	body_mesh.set_meta("hit_flash_tween", tween)


static func is_hit_flashing(body_mesh: MeshInstance3D) -> bool:
	if body_mesh == null:
		return false
	var outline := body_mesh.get_node_or_null("HitFlashOutline") as MeshInstance3D
	return outline != null and outline.visible
