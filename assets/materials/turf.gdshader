shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 grass_light : source_color = vec4(0.27, 0.68, 0.31, 1.0);
uniform vec4 grass_dark : source_color = vec4(0.14, 0.48, 0.22, 1.0);
uniform float tile_scale = 58.0;

float hash(vec2 value) {
	return fract(sin(dot(value, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 cell = floor(UV * tile_scale);
	float grain = hash(cell);
	float fleck = step(0.84, hash(cell + vec2(19.0, 7.0)));
	ALBEDO = mix(grass_dark.rgb, grass_light.rgb, 0.32 + grain * 0.55);
	ALBEDO += fleck * vec3(0.035, 0.055, 0.018);
	ROUGHNESS = 0.96;
}
