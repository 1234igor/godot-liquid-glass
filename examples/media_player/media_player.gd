extends Node2D

const MATERIALS := [
	LiquidGlassPanel.MaterialStyle.REGULAR,
	LiquidGlassPanel.MaterialStyle.CLEAR,
	LiquidGlassPanel.MaterialStyle.REGULAR_TINTED,
	LiquidGlassPanel.MaterialStyle.CLEAR_TINTED,
	LiquidGlassPanel.MaterialStyle.IDENTITY,
]

var _material_index := 0
var _surfaces: Array[LiquidGlassPanel] = []
var _shot_path := ""


func _ready() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--shot="):
			_shot_path = argument.trim_prefix("--shot=")
	get_window().title = "Horizon"
	_make_navigation()
	_make_player()
	_make_action()
	if not _shot_path.is_empty():
		_capture_after_frames.call_deferred()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.pressed and not event.echo and event.keycode == KEY_M:
		_material_index = (_material_index + 1) % MATERIALS.size()
		for surface in _surfaces:
			surface.set_material_style(MATERIALS[_material_index])


func _make_navigation() -> void:
	var glass := _surface(Vector2(48.0, 42.0), Vector2(382.0, 58.0), 24.0)
	glass.material_style = LiquidGlassPanel.MaterialStyle.CLEAR
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 26)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for title in ["Library", "Radio", "Favorites"]:
		row.add_child(_label(title, 15, Color(1.0, 1.0, 1.0, 0.92)))
	glass.content_layer.add_child(row)


func _make_player() -> void:
	var glass := _surface(Vector2(310.0, 638.0), Vector2(580.0, 110.0), 38.0)
	# The row is inset so the leading and trailing labels clear the glass edge,
	# where the lens distortion is strongest and text stops being readable.
	var inset := MarginContainer.new()
	inset.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right"]:
		inset.add_theme_constant_override(side, 28)
	glass.content_layer.add_child(inset)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var play := _label("PLAY", 13, Color.WHITE)
	play.custom_minimum_size = Vector2(58.0, 0.0)
	row.add_child(play)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	copy.add_theme_constant_override("separation", 4)
	copy.add_child(_label("Glass Horizon", 20, Color.WHITE))
	copy.add_child(_label("Harbour Sessions", 14, Color(1.0, 1.0, 1.0, 0.70)))
	row.add_child(copy)
	row.add_child(_label("03:42", 14, Color(1.0, 1.0, 1.0, 0.88)))
	inset.add_child(row)


func _make_action() -> void:
	var glass := _surface(Vector2(1090.0, 42.0), Vector2(64.0, 58.0), 24.0)
	glass.material_style = LiquidGlassPanel.MaterialStyle.CLEAR
	var label := _label("+", 28, Color.WHITE)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	glass.content_layer.add_child(label)


func _surface(position: Vector2, surface_size: Vector2, radius: float) -> LiquidGlassPanel:
	var glass := LiquidGlassPanel.new()
	glass.position = position
	glass.size = surface_size
	glass.corner_radius = radius
	add_child(glass)
	_surfaces.append(glass)
	return glass


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return label


func _capture_after_frames() -> void:
	for _frame in 8:
		await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(_shot_path)
	if error != OK:
		printerr("LIQUID GLASS APP FAIL - capture error %d" % error)
		get_tree().quit(1)
		return
	print("LIQUID GLASS APP OK size=%dx%d shot=%s" % [image.get_width(), image.get_height(), _shot_path])
	get_tree().quit(0)
