extends Node2D

const VARIANTS := ["regular", "clear", "regular-tinted", "clear-tinted", "identity"]
const BACKGROUNDS := ["harbour", "city-night", "prism", "facade"]
const STATES := ["rest", "hover", "pressed"]
const DEFAULT_CAPTURE_FRAMES := 20
const MAX_CAPTURE_FRAMES := 600
const GLASS_SOURCE_RECT := Rect2i(760, 1204, 880, 192)

@onready var backdrop: TextureRect = $Backdrop
@onready var shadow: ColorRect = $Shadow
@onready var glass: ColorRect = $Glass

var _variant := "regular"
var _background := "harbour"
var _state := "rest"
var _state_locked := false
var _shot_path := ""
var _capture_frames := DEFAULT_CAPTURE_FRAMES
var _parse_error := ""


func _ready() -> void:
	_parse_args(OS.get_cmdline_user_args())
	if not _parse_error.is_empty():
		printerr("LIQUID GLASS FAIL - %s" % _parse_error)
		get_tree().quit(2)
		return

	var capture_scale := 2.0 if not _shot_path.is_empty() else 1.0
	if capture_scale > 1.0:
		get_window().size = Vector2i(2400, 1600)
		scale = Vector2(capture_scale, capture_scale)
	get_window().title = "Liquid Glass Godot - %s - %s" % [_title(_variant), _title(_background)]
	backdrop.texture = load("res://assets/backgrounds/%s.png" % _background)
	_configure_material(capture_scale)
	glass.mouse_entered.connect(_on_mouse_entered)
	glass.mouse_exited.connect(_on_mouse_exited)
	glass.gui_input.connect(_on_glass_input)

	if not _shot_path.is_empty():
		_capture_after_frames.call_deferred()


func _parse_args(args: PackedStringArray) -> void:
	for raw_argument in args:
		var argument := raw_argument
		var value := ""
		var equals := argument.find("=")
		if equals >= 0:
			value = argument.substr(equals + 1)
			argument = argument.substr(0, equals)
		match argument:
			"--variant":
				_variant = _validated(value, VARIANTS, "variant")
			"--background":
				_background = _validated(value, BACKGROUNDS, "background")
			"--state":
				_state = _validated(value, STATES, "state")
				_state_locked = true
			"--shot":
				if value.is_empty():
					_fail("--shot needs an absolute PNG path")
				elif not value.is_absolute_path() or value.get_extension().to_lower() != "png":
					_fail("--shot must be an absolute .png path, got %s" % value)
				else:
					_shot_path = value
			"--frames":
				if not value.is_valid_int() or value.to_int() < 1 or value.to_int() > MAX_CAPTURE_FRAMES:
					_fail("--frames must be 1..%d" % MAX_CAPTURE_FRAMES)
				else:
					_capture_frames = value.to_int()
			_:
				_fail("unknown argument %s" % raw_argument)


func _validated(value: String, allowed: Array, label: String) -> String:
	if value in allowed:
		return value
	_fail("--%s must be one of %s, got %s" % [label, ", ".join(allowed), value])
	return allowed[0]


func _fail(message: String) -> void:
	if _parse_error.is_empty():
		_parse_error = message


func _configure_material(capture_scale: float) -> void:
	var material := glass.material as ShaderMaterial
	var clear := _variant == "clear" or _variant == "clear-tinted"
	var tinted := _variant == "regular-tinted" or _variant == "clear-tinted"
	var identity := _variant == "identity"
	material.set_shader_parameter("is_clear", 1.0 if clear else 0.0)
	material.set_shader_parameter("is_tinted", 1.0 if tinted else 0.0)
	material.set_shader_parameter("is_identity", 1.0 if identity else 0.0)
	material.set_shader_parameter("warmth", 0.0 if clear else _background_warmth())
	material.set_shader_parameter("interaction_energy", _state_energy(_state))
	material.set_shader_parameter("render_scale", capture_scale)
	material.set_shader_parameter("screen_pixel_size", Vector2(1.0 / (1200.0 * capture_scale), 1.0 / (800.0 * capture_scale)))
	shadow.visible = not identity


func _background_warmth() -> float:
	var image := (backdrop.texture as Texture2D).get_image()
	var total := 0.0
	var count := 0
	for y in range(GLASS_SOURCE_RECT.position.y, GLASS_SOURCE_RECT.end.y, 4):
		for x in range(GLASS_SOURCE_RECT.position.x, GLASS_SOURCE_RECT.end.x, 4):
			var color := image.get_pixel(x, y)
			var high: float = maxf(color.r, maxf(color.g, color.b))
			var low: float = minf(color.r, minf(color.g, color.b))
			total += (high - low) * 255.0
			count += 1
	var average_chroma: float = total / float(maxi(count, 1))
	var saturation_response: float = clampf((average_chroma - 10.0) / 46.0, 0.0, 1.0)
	return 0.55 + 0.45 * saturation_response


func _state_energy(state: String) -> float:
	match state:
		"hover":
			return 0.48
		"pressed":
			return 1.0
		_:
			return 0.0


func _set_state(next_state: String) -> void:
	if _state_locked or _variant == "identity" or _state == next_state:
		return
	_state = next_state
	(glass.material as ShaderMaterial).set_shader_parameter("interaction_energy", _state_energy(_state))


func _on_mouse_entered() -> void:
	if _state != "pressed":
		_set_state("hover")


func _on_mouse_exited() -> void:
	_set_state("rest")


func _on_glass_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_set_state("pressed" if event.pressed else "hover")


func _capture_after_frames() -> void:
	for _frame in _capture_frames:
		await get_tree().process_frame
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(_shot_path)
	if error != OK:
		printerr("LIQUID GLASS FAIL - could not save %s (error %d)" % [_shot_path, error])
		get_tree().quit(1)
		return
	print(
		"LIQUID GLASS OK variant=%s background=%s state=%s size=%dx%d shot=%s"
		% [_variant, _background, _state, image.get_width(), image.get_height(), _shot_path]
	)
	get_tree().quit(0)


func _title(value: String) -> String:
	return value.replace("-", " ").capitalize()
