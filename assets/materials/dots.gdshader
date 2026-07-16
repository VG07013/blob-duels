shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 base_color : source_color = vec4(0.94, 0.34, 0.36, 1.0);
uniform vec4 dot_color : source_color = vec4(1.0, 0.78, 0.48, 1.0);
uniform float dot_count = 7.0;
uniform float dot_radius = 0.19;

void fragment() {
	vec2 cell = fract(UV * dot_count) - vec2(0.5);
	float dot_mask = 1.0 - smoothstep(dot_radius - 0.025, dot_radius + 0.025, length(cell));
	ALBEDO = mix(base_color.rgb, dot_color.rgb, dot_mask);
	ROUGHNESS = 0.76;
}
