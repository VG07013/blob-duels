shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D detail_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D detail_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float normal_strength : hint_range(0.0, 2.0) = 0.0;
uniform vec4 color_a : source_color = vec4(0.1, 0.2, 0.5, 1.0);
uniform vec4 color_b : source_color = vec4(0.1, 0.7, 0.8, 1.0);
uniform vec2 gradient_axis = vec2(0.35, 1.0);
uniform float tile_scale : hint_range(1.0, 24.0) = 6.0;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.72;
uniform float metallic_value : hint_range(0.0, 1.0) = 0.05;
uniform float emission_strength : hint_range(0.0, 3.0) = 0.0;
uniform float pulse_speed : hint_range(0.0, 5.0) = 0.0;

void fragment() {
	vec2 axis = normalize(gradient_axis);
	float gradient = dot(UV - vec2(0.5), axis) + 0.5;
	gradient += sin((UV.x + UV.y) * 12.0) * 0.025;
	gradient = smoothstep(0.04, 0.96, clamp(gradient, 0.0, 1.0));
	vec3 detail = texture(detail_texture, UV * tile_scale).rgb;
	float detail_light = dot(detail, vec3(0.299, 0.587, 0.114));
	vec3 base = mix(color_a.rgb, color_b.rgb, gradient);
	ALBEDO = base * mix(0.72, 1.16, detail_light);
	ROUGHNESS = roughness_value;
	METALLIC = metallic_value;
	NORMAL_MAP = texture(detail_normal, UV * tile_scale).rgb;
	NORMAL_MAP_DEPTH = normal_strength;
	float pulse = pulse_speed > 0.0 ? 0.86 + sin(TIME * pulse_speed + UV.x * 4.0) * 0.14 : 1.0;
	EMISSION = base * emission_strength * pulse;
}
