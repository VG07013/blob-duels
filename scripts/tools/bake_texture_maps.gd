extends SceneTree

## Bakes the derived texture set the renderer consumes but nobody hand-authors:
## tangent-space normal maps for every seamless albedo texture, plus the two
## panoramic sky-cover textures (cloud deck and star field) that lighting
## profiles reference. Deterministic: fixed seeds, committed outputs.
##
##   godot --headless --path . --script res://scripts/tools/bake_texture_maps.gd
##
## Re-run only when a source texture changes, then re-import the project.

const SVG_TARGET_SIZE := 512.0

## Strength is baked into the map so runtime materials use a flat 1.0 scale.
## Values follow the physical read of each surface: masonry and pebbles are
## deep, plastic and brushed metal are shallow.
const NORMAL_BAKES := [
	{"src": "res://assets/textures/concrete.png", "strength": 1.5},
	{"src": "res://assets/textures/asphalt.png", "strength": 1.7},
	{"src": "res://assets/environment/textures/brushed_metal.svg", "strength": 0.8},
	{"src": "res://assets/environment/textures/painted_panels.svg", "strength": 1.1},
	{"src": "res://assets/environment/textures/stone_blocks.svg", "strength": 2.2},
	{"src": "res://assets/environment/textures/toy_plastic.svg", "strength": 0.9},
	{"src": "res://assets/environment/textures/roof_shingles.svg", "strength": 2.0},
	{"src": "res://assets/environment/textures/fabric_weave.svg", "strength": 1.2},
	{"src": "res://assets/environment/textures/soil_pebbles.svg", "strength": 2.2},
	{"src": "res://assets/environment/textures/wood_grain.svg", "strength": 1.4},
]

const CLOUD_COVER_PATH := "res://assets/textures/sky_cloud_cover.png"
const STAR_FIELD_PATH := "res://assets/textures/sky_star_field.png"


func _initialize() -> void:
	var failures := 0
	for bake in NORMAL_BAKES:
		var src := str(bake["src"])
		var dst := src.get_basename() + "_normal.png"
		if _bake_normal_map(src, dst, float(bake["strength"])):
			print("baked %s" % dst)
		else:
			push_error("failed to bake %s" % dst)
			failures += 1
	if _bake_cloud_cover(CLOUD_COVER_PATH):
		print("baked %s" % CLOUD_COVER_PATH)
	else:
		push_error("failed to bake cloud cover")
		failures += 1
	if _bake_star_field(STAR_FIELD_PATH):
		print("baked %s" % STAR_FIELD_PATH)
	else:
		push_error("failed to bake star field")
		failures += 1
	quit(1 if failures > 0 else 0)


func _load_source(path: String) -> Image:
	if path.ends_with(".svg"):
		var bytes := FileAccess.get_file_as_bytes(path)
		if bytes.is_empty():
			return null
		var image := Image.new()
		if image.load_svg_from_buffer(bytes, 1.0) != OK:
			return null
		var rescale := SVG_TARGET_SIZE / float(maxi(image.get_width(), 1))
		if absf(rescale - 1.0) > 0.01 and image.load_svg_from_buffer(bytes, rescale) != OK:
			return null
		return image
	return Image.load_from_file(ProjectSettings.globalize_path(path))


func _bake_normal_map(source_path: String, output_path: String, strength: float) -> bool:
	var source := _load_source(source_path)
	if source == null:
		return false
	source.convert(Image.FORMAT_RGBA8)
	var width := source.get_width()
	var height_px := source.get_height()
	var heights := PackedFloat32Array()
	heights.resize(width * height_px)
	for y in height_px:
		for x in width:
			var pixel := source.get_pixel(x, y)
			heights[y * width + x] = pixel.r * 0.299 + pixel.g * 0.587 + pixel.b * 0.114
	heights = _box_blur_wrapped(heights, width, height_px)
	var normal_map := Image.create(width, height_px, false, Image.FORMAT_RGB8)
	for y in height_px:
		var up := posmod(y - 1, height_px) * width
		var down := posmod(y + 1, height_px) * width
		var row := y * width
		for x in width:
			var left := posmod(x - 1, width)
			var right := posmod(x + 1, width)
			# Sobel over the wrapped neighbourhood keeps the bake as seamless
			# as its source.
			var gx := (heights[up + right] + 2.0 * heights[row + right] + heights[down + right] \
				- heights[up + left] - 2.0 * heights[row + left] - heights[down + left]) / 8.0
			var gy := (heights[down + left] + 2.0 * heights[down + x] + heights[down + right] \
				- heights[up + left] - 2.0 * heights[up + x] - heights[up + right]) / 8.0
			# OpenGL-convention (Y+) encode, which is what Godot samples.
			var normal := Vector3(-gx * strength * 24.0, gy * strength * 24.0, 1.0).normalized()
			normal_map.set_pixel(x, y, Color(normal.x * 0.5 + 0.5, normal.y * 0.5 + 0.5, normal.z * 0.5 + 0.5))
	return normal_map.save_png(ProjectSettings.globalize_path(output_path)) == OK


func _box_blur_wrapped(values: PackedFloat32Array, width: int, height_px: int) -> PackedFloat32Array:
	var blurred := PackedFloat32Array()
	blurred.resize(values.size())
	for y in height_px:
		var up := posmod(y - 1, height_px) * width
		var down := posmod(y + 1, height_px) * width
		var row := y * width
		for x in width:
			var left := posmod(x - 1, width)
			var right := posmod(x + 1, width)
			blurred[row + x] = (
				values[up + left] + values[up + x] + values[up + right]
				+ values[row + left] + values[row + x] + values[row + right]
				+ values[down + left] + values[down + x] + values[down + right]
			) / 9.0
	return blurred


func _bake_cloud_cover(output_path: String) -> bool:
	var width := 1024
	var height_px := 512
	var noise := FastNoiseLite.new()
	noise.seed = 20260803
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 5
	noise.fractal_gain = 0.52
	noise.frequency = 1.0
	var image := Image.create(width, height_px, false, Image.FORMAT_RGBA8)
	for y in height_px:
		var v := float(y) / float(height_px)
		for x in width:
			# Sampling 3D noise around a cylinder keeps the panorama seamless
			# where the left and right edges meet.
			var angle := TAU * float(x) / float(width)
			var sample := noise.get_noise_3d(cos(angle) * 1.7, v * 3.1, sin(angle) * 1.7)
			var density := smoothstep(0.06, 0.62, sample * 0.5 + 0.5)
			# Thin the deck at the zenith, fade it fully by the horizon line so
			# fog owns the transition band.
			density *= 0.72 + 0.28 * smoothstep(0.0, 0.16, v)
			density *= smoothstep(0.52, 0.44, v)
			var body := 0.86 + 0.14 * smoothstep(0.2, 0.8, sample * 0.5 + 0.5)
			image.set_pixel(x, y, Color(body, body, minf(body * 1.02, 1.0), density))
	return image.save_png(ProjectSettings.globalize_path(output_path)) == OK


func _bake_star_field(output_path: String) -> bool:
	var width := 2048
	var height_px := 1024
	var image := Image.create(width, height_px, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260803
	for i in 1400:
		# Uniform directions avoid the pole clustering a naive (u, v) roll gets.
		var direction := Vector3(rng.randfn(), rng.randfn(), rng.randfn())
		if direction.length_squared() < 0.001:
			continue
		direction = direction.normalized()
		var u := 0.5 + atan2(direction.z, direction.x) / TAU
		var v := acos(clampf(direction.y, -1.0, 1.0)) / PI
		var center_x := int(u * width) % width
		var center_y := clampi(int(v * height_px), 0, height_px - 1)
		var brightness := pow(rng.randf(), 2.4)
		var sigma := 0.55 + brightness * 0.85
		var tint := Color(1.0, 1.0, 1.0)
		var roll := rng.randf()
		if roll < 0.14:
			tint = Color(0.72, 0.84, 1.0)
		elif roll < 0.24:
			tint = Color(1.0, 0.88, 0.7)
		var reach := maxi(1, int(ceil(sigma * 2.6)))
		for oy in range(-reach, reach + 1):
			var py := center_y + oy
			if py < 0 or py >= height_px:
				continue
			for ox in range(-reach, reach + 1):
				var px := posmod(center_x + ox, width)
				var falloff := exp(-float(ox * ox + oy * oy) / (2.0 * sigma * sigma))
				var alpha := clampf(brightness * falloff * (0.35 + 0.65 * brightness), 0.0, 1.0)
				var existing := image.get_pixel(px, py)
				if alpha > existing.a:
					image.set_pixel(px, py, Color(tint.r, tint.g, tint.b, alpha))
	return image.save_png(ProjectSettings.globalize_path(output_path)) == OK
