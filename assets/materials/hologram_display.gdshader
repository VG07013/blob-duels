shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 color_a : source_color = vec4(0.03, 0.65, 0.95, 1.0);
uniform vec4 color_b : source_color = vec4(0.65, 0.08, 0.95, 1.0);
uniform float emission_strength : hint_range(0.0, 5.0) = 1.8;
uniform float scan_speed : hint_range(0.0, 5.0) = 0.8;
uniform float grid_scale : hint_range(2.0, 80.0) = 24.0;

void fragment() {
	float diagonal = clamp(UV.x * 0.68 + (1.0 - UV.y) * 0.32, 0.0, 1.0);
	vec3 base = mix(color_a.rgb, color_b.rgb, smoothstep(0.05, 0.95, diagonal));
	float scan = 0.84 + 0.16 * sin((UV.y * grid_scale - TIME * scan_speed) * 6.28318);
	float grid_x = smoothstep(0.92, 1.0, sin(UV.x * grid_scale * 3.14159) * 0.5 + 0.5);
	float grid_y = smoothstep(0.94, 1.0, sin(UV.y * grid_scale * 3.14159) * 0.5 + 0.5);
	float grid = max(grid_x, grid_y) * 0.16;
	float edge = smoothstep(0.0, 0.08, UV.x) * smoothstep(0.0, 0.08, 1.0 - UV.x);
	edge *= smoothstep(0.0, 0.12, UV.y) * smoothstep(0.0, 0.12, 1.0 - UV.y);
	ALBEDO = base * (scan + grid) * (0.72 + edge * 0.28);
	ROUGHNESS = 0.24;
	METALLIC = 0.18;
	EMISSION = base * emission_strength * (0.64 + scan * 0.36 + grid);
}
