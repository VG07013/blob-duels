class_name TextureNormalLibrary
extends RefCounted

## Maps each seamless albedo texture to the tangent-space normal map baked
## from it by scripts/tools/bake_texture_maps.gd. Keyed by resource path so
## the material factories pick up surface depth without threading a new
## argument through every material call site. Strength is baked into the
## maps themselves; consumers use them at flat 1.0 scale.

const NORMAL_MAPS := {
	"res://assets/textures/concrete.png": preload("res://assets/textures/concrete_normal.png"),
	"res://assets/textures/asphalt.png": preload("res://assets/textures/asphalt_normal.png"),
	"res://assets/environment/textures/brushed_metal.svg": preload("res://assets/environment/textures/brushed_metal_normal.png"),
	"res://assets/environment/textures/painted_panels.svg": preload("res://assets/environment/textures/painted_panels_normal.png"),
	"res://assets/environment/textures/stone_blocks.svg": preload("res://assets/environment/textures/stone_blocks_normal.png"),
	"res://assets/environment/textures/toy_plastic.svg": preload("res://assets/environment/textures/toy_plastic_normal.png"),
	"res://assets/environment/textures/roof_shingles.svg": preload("res://assets/environment/textures/roof_shingles_normal.png"),
	"res://assets/environment/textures/fabric_weave.svg": preload("res://assets/environment/textures/fabric_weave_normal.png"),
	"res://assets/environment/textures/soil_pebbles.svg": preload("res://assets/environment/textures/soil_pebbles_normal.png"),
	"res://assets/environment/textures/wood_grain.svg": preload("res://assets/environment/textures/wood_grain_normal.png"),
}


static func normal_for(albedo: Texture2D) -> Texture2D:
	if albedo == null:
		return null
	return NORMAL_MAPS.get(albedo.resource_path) as Texture2D
