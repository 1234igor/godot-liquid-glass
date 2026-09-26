shader_type canvas_item;
render_mode unshaded;

uniform vec2 bounds_points = vec2(548.0, 180.0);
uniform vec2 glass_origin = vec2(54.0, 54.0);
uniform vec2 glass_size = vec2(440.0, 96.0);
uniform float corner_radius = 34.0;
uniform float opacity = 0.22;

float rounded_rect_sdf(vec2 point, vec2 half_size, float radius) {
	vec2 q = abs(point) - (half_size - vec2(radius));
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - radius;
}

void fragment() {
	vec2 point = UV * bounds_points;
	vec2 shadow_center = glass_origin + glass_size * 0.5 + vec2(0.0, 8.0);
	float distance = rounded_rect_sdf(point - shadow_center, glass_size * 0.5, corner_radius);
	// SwiftUI's 24 pt blur with -6 pt spread, kept outside the material itself.
	float outside = max(distance + 6.0, 0.0);
	float shadow = exp(-outside * outside / (2.0 * 12.0 * 12.0)) * opacity;
	COLOR = vec4(0.0, 0.0, 0.0, shadow);
}
