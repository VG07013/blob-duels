shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec4 color_a : source_color = vec4(1.0, 0.77, 0.2, 1.0);
uniform vec4 color_b : source_color = vec4(1.0, 0.48, 0.18, 1.0);
uniform float stripe_count = 8.0;
uniform float stripe_softness = 0.035;
uniform float roughness = 0.72;

void fragment() {
	float band = fract(UV.x * stripe_count);
	float stripe = smoothstep(0.5 - stripe_softness, 0.5 + stripe_softness, band);
	ALBEDO = mix(color_a.rgb, color_b.rgb, stripe);
	ROUGHNESS = roughness;
}
