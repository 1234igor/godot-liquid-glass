extends SceneTree

var _surfaces: Array[LiquidGlassPanel] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var host := Control.new()
	host.size = Vector2(1200.0, 800.0)
	root.add_child(host)
	for index in 3:
		var surface := LiquidGlassPanel.new()
		surface.position = Vector2(40.0 + index * 260.0, 80.0)
		surface.size = Vector2(220.0, 96.0)
		surface.z_index = [1, -1, 0][index]
		host.add_child(surface)
		_surfaces.append(surface)

	if not _expect_modes([0, 2, 0], "Z-ordered provider"):
		return
	_surfaces[1].warmth = 0.2
	if not _expect_modes([0, 2, 0], "warmth preserves provider"):
		return
	_surfaces[0].size = Vector2(40.0, 30.0)
	_surfaces[0].corner_radius = 64.0
	if not _expect_radius(_surfaces[0], 15.0):
		return
	_surfaces[1].material_style = LiquidGlassPanel.MaterialStyle.IDENTITY
	if not _expect_modes([0, 0, 2], "identity handoff"):
		return
	_surfaces[2].hide()
	if not _expect_modes([2, 0, 0], "visibility handoff"):
		return
	_surfaces[0].queue_free()
	await process_frame
	if not _expect_modes([0, 0], "provider removal"):
		return
	_surfaces[2].show()
	if not _expect_modes([0, 2], "provider restoration"):
		return
	print("CAPTURE STRATEGY OK - provider handoffs are synchronous")
	quit(0)


func _expect_modes(expected: Array[int], label: String) -> bool:
	var actual: Array[int] = []
	for surface in _surfaces:
		if is_instance_valid(surface):
			actual.append(surface._back_buffer.copy_mode)
	if actual == expected:
		return true
	printerr("CAPTURE STRATEGY FAIL - %s expected=%s actual=%s" % [label, expected, actual])
	quit(1)
	return false


func _expect_radius(surface: LiquidGlassPanel, expected: float) -> bool:
	var glass_radius: float = (surface._glass.material as ShaderMaterial).get_shader_parameter(
		"corner_radius"
	)
	var shadow_radius: float = (surface._shadow.material as ShaderMaterial).get_shader_parameter(
		"corner_radius"
	)
	if is_equal_approx(glass_radius, expected) and is_equal_approx(shadow_radius, expected):
		return true
	printerr(
		"CAPTURE STRATEGY FAIL - radius clamp expected=%s glass=%s shadow=%s"
		% [expected, glass_radius, shadow_radius]
	)
	quit(1)
	return false
