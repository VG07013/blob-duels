shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
// Practice facility perimeter: a translucent hologram sheet. Purely visual -
// the wall's collision is a plain solid BoxShape, so the room is escape-proof
// no matter what this shader does. unshaded + depth_draw_never sidesteps the
// Mobile renderer's transparency-sorting artifacts at the pylon corners.

uniform vec3 holo_color: source_color = vec3(0.10, 0.85, 1.0);
uniform float base_alpha = 0.04;
uniform float fresnel_alpha = 0.30;
uniform float cell_size = 4.0;
uniform float cell_line_alpha = 0.07;
uniform float scan_speed = 0.06;
uniform float scan_band_alpha = 0.06;
uniform float emission_energy = 0.55;

varying vec3 world_position;


void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}


void fragment() {
	// Brighten toward grazing angles so the sheet reads as a boundary field.
	float facing = abs(dot(normalize(VIEW), normalize(NORMAL)));
	float fresnel = pow(1.0 - facing, 2.0);

	// Grid cells in world space so all four walls share one continuous pattern.
	vec2 sheet = vec2(world_position.x + world_position.z, world_position.y);
	vec2 to_line = abs(fract(sheet / cell_size + 0.5) - 0.5) * cell_size;
	float nearest = min(to_line.x, to_line.y);
	float aa = fwidth(nearest);
	float cell = 1.0 - smoothstep(0.05 - aa, 0.05 + aa, nearest);

	// A soft band scanning upward, looping over the wall height.
	float scan = pow(0.5 + 0.5 * sin((world_position.y * 0.09 - TIME * scan_speed) * 6.2831), 8.0);

	float alpha = base_alpha + fresnel * fresnel_alpha + cell * cell_line_alpha + scan * scan_band_alpha;
	ALBEDO = holo_color;
	EMISSION = holo_color * emission_energy * (0.35 + fresnel + cell * 0.8 + scan);
	ALPHA = clamp(alpha, 0.0, 0.4);
}
