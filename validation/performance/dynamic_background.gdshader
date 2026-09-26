shader_type canvas_item;
render_mode unshaded;

// A continuously changing photographic scene. Every visible pixel moves while
// keeping the background work inexpensive enough to expose glass overhead.
void fragment() {
	float t = TIME;
	vec2 primary_uv = fract(UV + vec2(t * 0.031, sin(t * 0.71) * 0.025));
	vec2 detail_uv = fract(UV * 1.37 + vec2(-t * 0.019, cos(t * 0.53) * 0.018));
	vec3 primary = texture(TEXTURE, primary_uv).rgb;
	vec3 detail = texture(TEXTURE, detail_uv).rgb;
	float pulse = 0.94 + 0.06 * sin(t * 1.9 + UV.x * 9.0 + UV.y * 6.0);
	COLOR = vec4(mix(primary, detail, 0.18) * pulse, 1.0);
}
