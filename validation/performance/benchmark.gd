extends Node2D

const VALID_MODES := ["none", "identity", "regular", "clear", "regular-tinted", "clear-tinted"]
const DEFAULT_WARMUP_FRAMES := 120
const DEFAULT_SAMPLE_FRAMES := 480

var _mode := "regular"
var _glass_count := 24
var _warmup_frames := DEFAULT_WARMUP_FRAMES
var _sample_frames := DEFAULT_SAMPLE_FRAMES
var _result_path := ""
var _shot_path := ""
var _frame_index := 0
var _last_frame_usec := 0
var _frame_times_ms: Array[float] = []
var _process_times_ms: Array[float] = []
var _draw_calls: Array[float] = []
var _surfaces: Array[LiquidGlassPanel] = []


func _ready() -> void:
	_parse_args(OS.get_cmdline_user_args())
	if _result_path.is_empty():
		printerr("LIQUID GLASS BENCH FAIL - --result needs an absolute JSON path")
		get_tree().quit(2)
		return
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	get_window().title = "Liquid Glass Benchmark"
	_build_dynamic_scene()
	_build_glass_surfaces()
	_last_frame_usec = Time.get_ticks_usec()


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var elapsed_ms := float(now - _last_frame_usec) / 1000.0
	_last_frame_usec = now
	_frame_index += 1
	_animate_surfaces(now)
	if _frame_index <= _warmup_frames:
		return
	_frame_times_ms.append(elapsed_ms)
	_process_times_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	_draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	if _frame_times_ms.size() >= _sample_frames:
		_finish()


func _parse_args(args: PackedStringArray) -> void:
	for raw_argument in args:
		var parts := raw_argument.split("=", true, 1)
		var key := parts[0]
		var value := parts[1] if parts.size() == 2 else ""
		match key:
			"--mode":
				if value in VALID_MODES:
					_mode = value
			"--count":
				if value.is_valid_int():
					_glass_count = maxi(value.to_int(), 0)
			"--warmup":
				if value.is_valid_int():
					_warmup_frames = maxi(value.to_int(), 1)
			"--frames":
				if value.is_valid_int():
					_sample_frames = maxi(value.to_int(), 1)
			"--result":
				if value.is_absolute_path() and value.get_extension().to_lower() == "json":
					_result_path = value
			"--shot":
				if value.is_absolute_path() and value.get_extension().to_lower() == "png":
					_shot_path = value


func _build_dynamic_scene() -> void:
	var background := TextureRect.new()
	background.position = Vector2.ZERO
	background.size = Vector2(1200.0, 800.0)
	background.texture = load("res://assets/backgrounds/harbour.png")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var material := ShaderMaterial.new()
	material.shader = load("res://validation/performance/dynamic_background.gdshader")
	background.material = material
	add_child(background)


func _build_glass_surfaces() -> void:
	if _mode == "none":
		return
	var columns := maxi(1, ceili(sqrt(float(_glass_count) * 1.5)))
	var rows := maxi(1, ceili(float(_glass_count) / float(columns)))
	var cell := Vector2(1160.0 / float(columns), 760.0 / float(rows))
	var surface_size := Vector2(minf(220.0, cell.x + 34.0), minf(104.0, cell.y + 26.0))
	for index in _glass_count:
		var column := index % columns
		var row := index / columns
		var glass := LiquidGlassPanel.new()
		glass.position = Vector2(20.0, 20.0) + Vector2(column, row) * cell
		glass.size = surface_size
		glass.corner_radius = minf(34.0, surface_size.y * 0.42)
		match _mode:
			"identity":
				glass.material_style = LiquidGlassPanel.MaterialStyle.IDENTITY
			"clear":
				glass.material_style = LiquidGlassPanel.MaterialStyle.CLEAR
			"regular-tinted":
				glass.material_style = LiquidGlassPanel.MaterialStyle.REGULAR_TINTED
			"clear-tinted":
				glass.material_style = LiquidGlassPanel.MaterialStyle.CLEAR_TINTED
			_:
				glass.material_style = LiquidGlassPanel.MaterialStyle.REGULAR
		add_child(glass)
		_surfaces.append(glass)


func _animate_surfaces(now_usec: int) -> void:
	var t := float(now_usec) / 1000000.0
	for index in _surfaces.size():
		var surface := _surfaces[index]
		var phase := t * 1.7 + float(index) * 0.61
		surface.position += Vector2(sin(phase), cos(phase * 0.83)) * 0.16


func _finish() -> void:
	_frame_times_ms.sort()
	_process_times_ms.sort()
	_draw_calls.sort()
	var result := {
		"mode": _mode,
		"glass_count": _glass_count,
		"capture_strategy": _capture_strategy(),
		"warmup_frames": _warmup_frames,
		"sample_frames": _sample_frames,
		"median_frame_ms": _percentile(_frame_times_ms, 0.50),
		"p95_frame_ms": _percentile(_frame_times_ms, 0.95),
		"p99_frame_ms": _percentile(_frame_times_ms, 0.99),
		"mean_frame_ms": _mean(_frame_times_ms),
		"median_fps": 1000.0 / maxf(_percentile(_frame_times_ms, 0.50), 0.001),
		"slow_frames_over_8_33_ms": _count_over(_frame_times_ms, 8.33),
		"slow_frames_over_12_5_ms": _count_over(_frame_times_ms, 12.5),
		"slow_frames_over_16_67_ms": _count_over(_frame_times_ms, 16.67),
		"median_process_ms": _percentile(_process_times_ms, 0.50),
		"median_draw_calls": _percentile(_draw_calls, 0.50),
		"renderer": RenderingServer.get_video_adapter_name(),
		"godot_version": Engine.get_version_info().get("string", "unknown"),
	}
	var file := FileAccess.open(_result_path, FileAccess.WRITE)
	if file == null:
		printerr("LIQUID GLASS BENCH FAIL - cannot write %s" % _result_path)
		get_tree().quit(1)
		return
	file.store_string(JSON.stringify(result, "\t"))
	file.close()
	if not _shot_path.is_empty():
		var image := get_viewport().get_texture().get_image()
		var image_error := image.save_png(_shot_path)
		if image_error != OK:
			printerr("LIQUID GLASS BENCH FAIL - cannot save %s" % _shot_path)
			get_tree().quit(1)
			return
	print("LIQUID GLASS BENCH OK %s" % JSON.stringify(result))
	get_tree().quit(0)


func _capture_strategy() -> String:
	for surface in _surfaces:
		if surface._back_buffer.copy_mode == BackBufferCopy.COPY_MODE_VIEWPORT:
			return "shared-viewport"
	for surface in _surfaces:
		if surface._back_buffer.copy_mode == BackBufferCopy.COPY_MODE_RECT:
			return "local-regions"
	return "disabled"


func _percentile(values: Array[float], percentile: float) -> float:
	if values.is_empty():
		return 0.0
	var index := clampi(roundi(float(values.size() - 1) * percentile), 0, values.size() - 1)
	return values[index]


func _mean(values: Array[float]) -> float:
	if values.is_empty():
		return 0.0
	var total := 0.0
	for value in values:
		total += value
	return total / float(values.size())


func _count_over(values: Array[float], threshold: float) -> int:
	var count := 0
	for value in values:
		if value > threshold:
			count += 1
	return count
