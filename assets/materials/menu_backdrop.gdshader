// Main menu backdrop: a deep neon hall in one full-screen pass. Two slow team
// glows (orange left, cyan right), a perspective floor grid rolling toward
// the viewer, drifting orange / blue / white dots that echo the Skyline
// platform patterns, and a vignette. `reveal` drives the intro fade.
shader_type canvas_item;

uniform float reveal : hint_range(0.0, 1.0) = 1.0;
uniform float motion_scale : hint_range(0.0, 1.0) = 1.0;
uniform vec4 base_top : source_color = vec4(0.020, 0.030, 0.075, 1.0);
uniform vec4 base_bottom : source_color = vec4(0.030, 0.050, 0.115, 1.0);
uniform vec4 glow_left : source_color = vec4(1.0, 0.45, 0.08, 1.0);
uniform vec4 glow_right : source_color = vec4(0.02, 0.78, 1.0, 1.0);
uniform vec4 grid_color : source_color = vec4(0.18, 0.72, 1.0, 1.0);

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float soft_blob(vec2 p, vec2 center, float radius) {
	float d = length(p - center);
	return exp(-(d * d) / (radius * radius));
}

void fragment() {
	vec2 screen_size = 1.0 / SCREEN_PIXEL_SIZE;
	float aspect = screen_size.x / max(screen_size.y, 1.0);
	vec2 uv = UV;
	vec2 p = vec2((uv.x - 0.5) * aspect, uv.y - 0.5);
	float t = TIME * motion_scale;

	vec3 color = mix(base_top.rgb, base_bottom.rgb, smoothstep(0.0, 1.0, uv.y));

	// Team glows breathe and drift on slow Lissajous paths.
	vec2 left_center = vec2(-0.31 * aspect + sin(t * 0.21) * 0.08, 0.18 + cos(t * 0.17) * 0.07);
	vec2 right_center = vec2(0.31 * aspect + cos(t * 0.19) * 0.08, -0.22 + sin(t * 0.23) * 0.07);
	color += glow_left.rgb * soft_blob(p, left_center, 0.52) * (0.34 + 0.06 * sin(t * 0.7));
	color += glow_right.rgb * soft_blob(p, right_center, 0.56) * (0.30 + 0.06 * cos(t * 0.6));
	color += vec3(0.35, 0.2, 0.9) * soft_blob(p, vec2(0.0, 0.55), 0.45) * 0.10;

	// Perspective floor grid below the horizon, rolling toward the viewer.
	float horizon = 0.62;
	if (uv.y > horizon) {
		float depth = (uv.y - horizon) / (1.0 - horizon);
		float z = 1.0 / max(depth, 0.001);
		float x = (uv.x - 0.5) * z * 2.2;
		float rows = fract(z * 0.9 - t * 0.35);
		float cols = fract(x * 1.4);
		float row_width = fwidth(z * 0.9) * 1.2;
		float col_width = fwidth(x * 1.4) * 1.2;
		float row_line = 1.0 - smoothstep(0.0, row_width, min(rows, 1.0 - rows));
		float col_line = 1.0 - smoothstep(0.0, col_width, min(cols, 1.0 - cols));
		float fade = smoothstep(0.0, 0.6, depth);
		color += grid_color.rgb * (row_line * 0.5 + col_line * 0.4) * fade * 0.24;
		color = mix(color, color * 0.72, depth * 0.35);
	}
	// Horizon light line.
	color += grid_color.rgb * exp(-abs(uv.y - horizon) * 90.0) * 0.16;

	// Drifting dots: one candidate per cell, rising slowly with a sway.
	vec2 cell_uv = vec2(p.x * 9.0, p.y * 9.0 + t * 0.12);
	vec2 cell = floor(cell_uv);
	vec2 local = fract(cell_uv) - 0.5;
	float seed = hash21(cell);
	if (seed > 0.72) {
		vec2 offset = vec2(hash21(cell + 7.1) - 0.5, hash21(cell + 3.7) - 0.5) * 0.6;
		offset.x += sin(t * 0.8 + seed * 20.0) * 0.08;
		float size = mix(0.035, 0.09, hash21(cell + 1.3));
		float dot_mask = smoothstep(size, size * 0.4, length(local - offset));
		float pick = hash21(cell + 9.9);
		vec3 dot_color = pick < 0.4 ? glow_left.rgb : (pick < 0.8 ? glow_right.rgb : vec3(0.9, 0.95, 1.0));
		float twinkle = 0.55 + 0.45 * sin(t * 1.6 + seed * 40.0);
		color += dot_color * dot_mask * twinkle * 0.28 * (1.0 - smoothstep(0.35, 0.8, uv.y));
	}

	// Vignette and intro fade from black.
	float vignette = 1.0 - smoothstep(0.45, 1.25, length(p * vec2(0.85, 1.25)));
	color *= mix(0.55, 1.0, vignette);
	color *= reveal;
	COLOR = vec4(color, 1.0);
}
