extends Control

var _title_font: Font
var _body_font: Font
var _rounded_font: Font


func _ready() -> void:
	_title_font = _apple_font(600, false)
	_body_font = _apple_font(500, false)
	_rounded_font = _apple_font(600, true)
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2(48.0, 48.0), 28.0, Color(1.0, 1.0, 1.0, 0.18), true, -1.0, true)
	draw_colored_polygon(
		PackedVector2Array([Vector2(41.0, 37.0), Vector2(59.0, 48.0), Vector2(41.0, 59.0)]),
		Color.WHITE
	)
	draw_string(_title_font, Vector2(92.0, 43.0), "Glass Horizon", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, Color.WHITE)
	draw_string(
		_body_font,
		Vector2(92.0, 64.0),
		"Harbour Sessions",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		14,
		Color(1.0, 1.0, 1.0, 0.72)
	)

	var heights := [10.0, 20.0, 15.0, 25.0]
	for index in heights.size():
		var height: float = heights[index]
		_draw_capsule(Rect2(346.0 + index * 7.0, 48.0 - height * 0.5, 4.0, height), Color(1.0, 1.0, 1.0, 0.90))
	draw_string(
		_rounded_font,
		Vector2(390.0, 53.0),
		"3:42",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		13,
		Color(1.0, 1.0, 1.0, 0.88)
	)


func _apple_font(weight: int, rounded: bool) -> Font:
	var source := FontFile.new()
	var path := "/System/Library/Fonts/SFNSRounded.ttf" if rounded else "/System/Library/Fonts/SFNS.ttf"
	if source.load_dynamic_font(path) != OK:
		var fallback := SystemFont.new()
		fallback.font_names = PackedStringArray(["sans-serif"])
		fallback.font_weight = weight
		return fallback
	source.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	source.hinting = TextServer.HINTING_LIGHT
	var variation := FontVariation.new()
	variation.base_font = source
	variation.variation_opentype = {"wght": weight}
	return variation


func _draw_capsule(rect: Rect2, color: Color) -> void:
	var radius := rect.size.x * 0.5
	draw_rect(Rect2(rect.position + Vector2(0.0, radius), Vector2(rect.size.x, rect.size.y - radius * 2.0)), color)
	draw_circle(Vector2(rect.position.x + radius, rect.position.y + radius), radius, color, true, -1.0, true)
	draw_circle(Vector2(rect.position.x + radius, rect.end.y - radius), radius, color, true, -1.0, true)
