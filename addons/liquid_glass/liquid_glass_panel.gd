class_name LiquidGlassPanel
extends Control

const CAPTURE_GROUP := &"_liquid_glass_capture_panels"

enum MaterialStyle {
	REGULAR,
	CLEAR,
	REGULAR_TINTED,
	CLEAR_TINTED,
	IDENTITY,
}

@export var material_style := MaterialStyle.REGULAR:
	set(value):
		material_style = value
		_apply_material()
		if is_inside_tree():
			_refresh_capture_strategy()
@export_range(0.0, 1.0, 0.01) var warmth := 0.75:
	set(value):
		warmth = value
		_apply_material()
@export_range(0.0, 64.0, 1.0) var corner_radius := 34.0:
	set(value):
		corner_radius = value
		_apply_geometry()

var content_layer: Control
var _back_buffer: BackBufferCopy
var _shadow: ColorRect
var _glass: ColorRect
var _interaction_energy := 0.0
var _pressed := false


func _init() -> void:
	_build_layers()


func _ready() -> void:
	clip_contents = false
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	add_to_group(CAPTURE_GROUP)
	resized.connect(_apply_geometry)
	get_viewport().size_changed.connect(_apply_geometry)
	visibility_changed.connect(_refresh_capture_strategy)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)
	_apply_geometry()
	_apply_material()
	_refresh_capture_strategy()


func _exit_tree() -> void:
	remove_from_group(CAPTURE_GROUP)
	var peers := _capture_peers()
	if not peers.is_empty():
		peers[0]._refresh_capture_strategy()


func set_material_style(style: MaterialStyle) -> void:
	material_style = style


func set_interaction_energy(energy: float) -> void:
	_interaction_energy = clampf(energy, 0.0, 1.0)
	if is_instance_valid(_glass):
		(_glass.material as ShaderMaterial).set_shader_parameter(
			"interaction_energy", _interaction_energy
		)


func _build_layers() -> void:
	_back_buffer = BackBufferCopy.new()
	_back_buffer.copy_mode = BackBufferCopy.COPY_MODE_DISABLED
	add_child(_back_buffer)

	_shadow = ColorRect.new()
	_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shadow_material := ShaderMaterial.new()
	shadow_material.shader = load("res://addons/liquid_glass/glass_shadow.gdshader")
	_shadow.material = shadow_material
	add_child(_shadow)

	_glass = ColorRect.new()
	_glass.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var glass_material := ShaderMaterial.new()
	glass_material.shader = load("res://addons/liquid_glass/liquid_glass.gdshader")
	_glass.material = glass_material
	add_child(_glass)

	content_layer = Control.new()
	content_layer.name = "Content"
	content_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content_layer)


func _apply_geometry() -> void:
	if not is_instance_valid(_glass) or size.x <= 0.0 or size.y <= 0.0:
		return
	var margin := Vector2(54.0, 54.0)
	var effective_radius := clampf(corner_radius, 0.0, minf(size.x, size.y) * 0.5)
	_shadow.position = -margin
	_shadow.size = size + Vector2(108.0, 84.0)
	var shadow_material := _shadow.material as ShaderMaterial
	shadow_material.set_shader_parameter("bounds_points", _shadow.size)
	shadow_material.set_shader_parameter("glass_origin", margin)
	shadow_material.set_shader_parameter("glass_size", size)
	shadow_material.set_shader_parameter("corner_radius", effective_radius)
	var material := _glass.material as ShaderMaterial
	material.set_shader_parameter("size_points", size)
	material.set_shader_parameter("corner_radius", effective_radius)
	if is_inside_tree():
		material.set_shader_parameter("screen_pixel_size", Vector2.ONE / get_viewport_rect().size)
		material.set_shader_parameter("render_scale", get_window().content_scale_factor)


func _apply_material() -> void:
	if not is_instance_valid(_glass):
		return
	var clear := material_style == MaterialStyle.CLEAR or material_style == MaterialStyle.CLEAR_TINTED
	var tinted := material_style == MaterialStyle.REGULAR_TINTED or material_style == MaterialStyle.CLEAR_TINTED
	var identity := material_style == MaterialStyle.IDENTITY
	var material := _glass.material as ShaderMaterial
	material.set_shader_parameter("is_clear", 1.0 if clear else 0.0)
	material.set_shader_parameter("is_tinted", 1.0 if tinted else 0.0)
	material.set_shader_parameter("is_identity", 1.0 if identity else 0.0)
	material.set_shader_parameter("warmth", 0.0 if clear else warmth)
	material.set_shader_parameter("interaction_energy", _interaction_energy)
	_glass.visible = not identity
	_shadow.visible = not identity


func _refresh_capture_strategy() -> void:
	if not is_inside_tree():
		return
	var peers := _capture_peers()
	for peer in peers:
		peer._back_buffer.copy_mode = BackBufferCopy.COPY_MODE_DISABLED
	for peer in peers:
		if peer.is_visible_in_tree() and peer.material_style != MaterialStyle.IDENTITY:
			peer._back_buffer.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
			return


func _capture_peers() -> Array[LiquidGlassPanel]:
	var peers: Array[LiquidGlassPanel] = []
	if not is_inside_tree():
		return peers
	for node in get_tree().get_nodes_in_group(CAPTURE_GROUP):
		if node == self and is_queued_for_deletion():
			continue
		if (
			node is not LiquidGlassPanel
			or node.get_viewport() != get_viewport()
			or node.get_canvas() != get_canvas()
		):
			continue
		peers.append(node)
	peers.sort_custom(_draws_before)
	return peers


func _draws_before(left: LiquidGlassPanel, right: LiquidGlassPanel) -> bool:
	var left_z := _effective_z_index(left)
	var right_z := _effective_z_index(right)
	if left_z != right_z:
		return left_z < right_z
	return right.is_greater_than(left)


func _effective_z_index(item: CanvasItem) -> int:
	var value := item.z_index
	if not item.z_as_relative:
		return value
	var parent := item.get_parent()
	if parent is CanvasItem and parent.get_canvas() == item.get_canvas():
		value += _effective_z_index(parent)
	return value


func _on_mouse_entered() -> void:
	if not _pressed:
		set_interaction_energy(0.48)


func _on_mouse_exited() -> void:
	_pressed = false
	set_interaction_energy(0.0)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_pressed = event.pressed
		set_interaction_energy(1.0 if _pressed else 0.48)
