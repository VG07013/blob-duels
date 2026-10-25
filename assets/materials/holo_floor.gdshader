shader_type spatial;
// Practice facility floor: near-black glossy plate with an emissive world-space
// grid. Metallic + low roughness picks up the sky reflection the shared
// Environment already provides (reflected_light_source = SKY), which reads as a
// "wet" holo sheen on the Mobile renderer without needing SSR.

uniform vec3 base_color: source_color = vec3(0.02, 0.03, 0.05);
uniform vec3 grid_color: source_color = vec3(0.10, 0.85, 1.0);
uniform float major_spacing = 10.0;
uniform float minor_spacing = 2.5;
uniform float major_emission = 1.6;
uniform float minor_emission = 0.45;
uniform float pulse_emission = 0.4;
uniform float pulse_speed = 0.35;
uniform float pulse_spacing = 46.0;

varying vec3 world_position;


void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}


// Antialiased distance to the nearest grid line for a given spacing.
float grid_line(vec2 position, float spacing, float half_width) {
	vec2 to_line = abs(fract(position / spacing + 0.5) - 0.5) * spacing;
	float nearest = min(to_line.x, to_line.y);
	float aa = fwidth(nearest);
	return 1.0 - smoothstep(half_width - aa, half_width + aa, nearest);
}


void fragment() {
	ALBEDO = base_color;
	METALLIC = 0.6;
	ROUGHNESS = 0.25;

	float major = grid_line(world_position.xz, major_spacing, 0.09);
	float minor = grid_line(world_position.xz, minor_spacing, 0.045);
	// A slow ring of light breathing outward from the hub sells "simulation".
	float radial = distance(world_position.xz, vec2(0.0));
	float pulse = pow(0.5 + 0.5 * sin(radial / pulse_spacing * 6.2831 - TIME * pulse_speed * 6.2831), 6.0);

	vec3 emission = grid_color * (major * major_emission + minor * minor_emission);
	emission += grid_color * pulse * pulse_emission * (0.25 + 0.75 * major);
	EMISSION = emission;
}
