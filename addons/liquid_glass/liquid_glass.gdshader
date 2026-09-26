shader_type canvas_item;
render_mode unshaded;

// The live framebuffer behind this CanvasItem. A trilinear mip sample supplies
// the broad diffusion lobe without repeated screen reads.
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform vec2 size_points = vec2(440.0, 96.0);
uniform vec2 screen_pixel_size = vec2(0.0004166667, 0.000625);
uniform float corner_radius = 34.0;
uniform float render_scale = 2.0;
uniform float is_clear = 0.0;
uniform float is_tinted = 0.0;
uniform float is_identity = 0.0;
uniform float warmth = 0.75;
uniform float interaction_energy = 0.0;

float rounded_rect_sdf(vec2 point, vec2 half_inner, float radius) {
	vec2 q = abs(point) - half_inner;
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - radius;
}

vec3 refracted_sample(vec2 uv, vec2 normal, float lens) {
	float displacement_points = mix(3.2, 26.0, is_clear) * lens;
	vec2 sample_uv = clamp(
		uv - normal * displacement_points * render_scale * screen_pixel_size,
		vec2(0.001),
		vec2(0.999)
	);
	if (is_clear > 0.5) {
		return textureLod(screen_texture, sample_uv, 0.0).rgb;
	}

	// The mip lobe is deliberately narrower than a generic frosted-glass blur;
	// native Regular Glass preserves broad shapes and high-contrast edges.
	return textureLod(screen_texture, sample_uv, 3.25).rgb;
}

void fragment() {
	vec2 point = UV * size_points - size_points * 0.5;
	vec2 half_inner = size_points * 0.5 - vec2(corner_radius);
	float sdf = rounded_rect_sdf(point, half_inner, corner_radius);
	float distance_inside = -sdf;
	float epsilon = 0.5;
	vec2 gradient = vec2(
		rounded_rect_sdf(point + vec2(epsilon, 0.0), half_inner, corner_radius)
			- rounded_rect_sdf(point - vec2(epsilon, 0.0), half_inner, corner_radius),
		rounded_rect_sdf(point + vec2(0.0, epsilon), half_inner, corner_radius)
			- rounded_rect_sdf(point - vec2(0.0, epsilon), half_inner, corner_radius)
	);
	vec2 normal = gradient / max(length(gradient), 0.0001);
	float bevel = mix(15.0, 16.0, is_clear);
	float edge = distance_inside >= 0.0 ? clamp(1.0 - distance_inside / bevel, 0.0, 1.0) : 0.0;
	float lens = smoothstep(0.0, 1.0, edge);
	vec3 color = refracted_sample(SCREEN_UV, normal, lens);
	float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));

	if (is_clear > 0.5) {
		color = vec3(
			0.724344 * color.r - 0.171892 * color.g + 0.127461 * color.b + 40.8984 / 255.0,
			0.069654 * color.r + 0.514368 * color.g + 0.096509 * color.b + 39.1233 / 255.0,
			0.067487 * color.r - 0.101700 * color.g + 0.723461 * color.b + 34.4699 / 255.0
		);
	} else {
		color = vec3(luma) + (color - vec3(luma)) * 1.05;
		color = color * 1.01 + vec3(2.0 / 255.0);
	}

	float top_left_light = clamp((-normal.x - normal.y) * 0.5 + 0.5, 0.0, 1.0);
	float bright_rim = is_clear > 0.5
		? pow(edge, 6.0) * (0.12 + 0.58 * top_left_light)
		: pow(edge, 5.0) * (0.06 + 0.18 * top_left_light);
	float inner_glow = pow(edge, 1.7) * mix(0.025, 0.008, is_clear);
	float tint_amount = mix(0.56, 0.0, is_clear) + inner_glow + interaction_energy * 0.025;
	float dark_rim = pow(edge, 4.0) * (1.0 - top_left_light) * mix(0.04, 0.13, is_clear);
	vec3 body_tint = vec3(1.0, 1.0 - 17.0 / 255.0 * warmth, 1.0 - 42.0 / 255.0 * warmth);
	color = mix(color, body_tint, tint_amount);
	color = mix(color, vec3(1.0), bright_rim) * (1.0 - dark_rim);

	if (is_clear < 0.5) {
		vec3 fitted = vec3(
			1.677902 * color.r - 0.618335 * color.g - 0.180438 * color.b + 6.82167 / 255.0,
			-0.178502 * color.r + 1.112136 * color.g - 0.101458 * color.b + 29.125513 / 255.0,
			-0.077173 * color.r - 0.230698 * color.g + 1.197948 * color.b + 25.698877 / 255.0
		);
		color = mix(color, fitted, 1.0 - edge * edge);
	}

	if (is_tinted > 0.5) {
		if (is_clear > 0.5) {
			color = vec3(
				0.053004 * color.r + 0.209435 * color.g - 0.008474 * color.b + 176.3245 / 255.0,
				0.099248 * color.r + 0.323315 * color.g - 0.025185 * color.b - 50.8425 / 255.0,
				0.100361 * color.r + 0.345083 * color.g - 0.016379 * color.b - 22.3261 / 255.0
			);
		} else {
			color = vec3(
				0.054469 * color.r + 0.190262 * color.g + 0.026954 * color.b + 211.7142 / 255.0,
				0.178054 * color.r + 0.507345 * color.g - 0.211269 * color.b - 95.3155 / 255.0,
				0.155782 * color.r + 0.465979 * color.g - 0.131520 * color.b - 55.3333 / 255.0
			);
		}
	}

	float interaction_glow = interaction_energy * (0.055 + pow(edge, 2.2) * 0.12);
	color = mix(color, vec3(1.0), interaction_glow);
	float alpha = clamp(distance_inside * render_scale, 0.0, 1.0) * (1.0 - is_identity);
	COLOR = vec4(clamp(color, vec3(0.0), vec3(1.0)), alpha);
}
