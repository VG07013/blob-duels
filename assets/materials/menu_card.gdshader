// Main menu card surface: a rounded glass panel with a diagonal accent
// wash, a periodic light sweep, and an outer glow that grows on hover.
// MenuCard draws one quad `glow_margin` px larger than itself on every side,
// so the glow can spill outside the card rect.
shader_type canvas_item;

uniform vec2 card_size = vec2(320.0, 120.0);
uniform float corner_radius = 18.0;
uniform vec4 fill_top : source_color = vec4(0.06, 0.09, 0.17, 0.82);
uniform vec4 fill_bottom : source_color = vec4(0.03, 0.05, 0.10, 0.82);
uniform vec4 accent : source_color = vec4(0.02, 0.82, 1.0, 1.0);
uniform float accent_strength : hint_range(0.0, 1.0) = 0.25;
uniform float hover : hint_range(0.0, 1.0) = 0.0;
uniform float shine_enabled : hint_range(0.0, 1.0) = 1.0;
uniform float shine_offset = 0.0;
uniform float motion_scale : hint_range(0.0, 1.0) = 1.0;

varying vec2 local_pos;

void vertex() {
	local_pos = VERTEX;
}

float rounded_box(vec2 p, vec2 half_size, float radius) {
	vec2 q = abs(p) - half_size + radius;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
}

void fragment() {
	vec2 center = card_size * 0.5;
	float d = rounded_box(local_pos - center, card_size * 0.5, corner_radius);
	float inside = 1.0 - smoothstep(-1.0, 1.0, d);
	vec2 uv = clamp(local_pos / card_size, 0.0, 1.0);

	// Glass fill with the accent washing in from the top-left corner.
	vec4 fill = mix(fill_top, fill_bottom, uv.y);
	float wash = clamp((1.0 - uv.x * 0.7 - uv.y * 0.5) * accent_strength * (1.0 + hover * 0.6), 0.0, 1.0);
	vec3 rgb = fill.rgb + accent.rgb * wash * 0.55;

	// Light sweep: a slanted band crossing every few seconds.
	float cycle = fract((TIME * motion_scale + shine_offset) / 5.5);
	float band_pos = mix(-0.4, 1.6, cycle);
	float band = exp(-pow((uv.x + uv.y * 0.35 - band_pos) * 7.0, 2.0));
	rgb += vec3(1.0) * band * 0.10 * shine_enabled * (0.6 + hover * 0.4);

	// Top highlight and hairline border that warms toward the accent on hover.
	rgb += vec3(1.0) * smoothstep(0.35, 0.0, uv.y) * 0.035;
	float border = (1.0 - smoothstep(0.0, 1.6, abs(d + 1.0))) * inside;
	vec3 border_color = mix(vec3(0.5, 0.62, 0.8), accent.rgb, 0.45 + hover * 0.55);
	rgb = mix(rgb, border_color, border * (0.42 + hover * 0.5));

	// Soft shadow plus hover glow beyond the rounded rect.
	float outside = max(d, 0.0);
	float shadow = exp(-outside / 10.0) * 0.27 * (1.0 - inside);
	float glow = exp(-outside / (6.0 + hover * 8.0)) * hover * 0.55 * (1.0 - inside);

	float surface_alpha = inside * fill.a;
	float halo_alpha = shadow + glow;
	vec3 halo_rgb = accent.rgb * glow / max(halo_alpha, 0.0001);
	float out_alpha = surface_alpha + halo_alpha * (1.0 - surface_alpha);
	vec3 out_rgb = (rgb * surface_alpha + halo_rgb * halo_alpha * (1.0 - surface_alpha)) / max(out_alpha, 0.0001);
	COLOR = vec4(out_rgb, out_alpha);
}
