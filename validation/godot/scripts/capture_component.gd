extends SceneTree

# Capture the public component, rather than a separately assembled shader scene.
const GlassPanel = preload("res://addons/liquid_glass/liquid_glass_panel.gd")
const Contents = preload("res://validation/godot/scripts/playback_contents.gd")
const VARIANTS := ["regular", "clear", "regular-tinted", "clear-tinted", "identity"]
const BACKGROUNDS := ["harbour", "city-night", "prism", "facade"]


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	var variant := "clear"
	var background := "harbour"
	var output := ""
	var state := "rest"
	var capture_scale := 2
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--variant="):
			variant = argument.trim_prefix("--variant=")
		elif argument.begins_with("--background="):
			background = argument.trim_prefix("--background=")
		elif argument.begins_with("--shot="):
			output = argument.trim_prefix("--shot=")
		elif argument.begins_with("--state="):
			state = argument.trim_prefix("--state=")
		elif argument.begins_with("--scale="):
			capture_scale = argument.trim_prefix("--scale=").to_int()
	if variant not in VARIANTS or background not in BACKGROUNDS or state not in ["rest", "hover", "pressed"] or capture_scale not in [1, 2] or not output.is_absolute_path():
		printerr("Invalid variant, background, or absolute output path")
		print("COMPONENT EXIT 1")
		quit(1)
		return
	root.size = Vector2i(1200, 800) * capture_scale
	var scene := Node2D.new()
	scene.scale = Vector2.ONE * capture_scale
	root.add_child(scene)
	var backdrop := TextureRect.new()
	backdrop.texture = load("res://assets/backgrounds/%s.png" % background)
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.size = Vector2(1200, 800)
	scene.add_child(backdrop)
	var panel := GlassPanel.new()
	panel.position = Vector2(380, 602)
	panel.size = Vector2(440, 96)
	panel.corner_radius = 34
	panel.material_style = VARIANTS.find(variant)
	scene.add_child(panel)
	panel.set_interaction_energy(0.48 if state == "hover" else (1.0 if state == "pressed" else 0.0))
	panel.content_layer.add_child(Contents.new())
	for frame in 20:
		await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(output)
	print("COMPONENT EXIT %d" % (0 if error == OK else 1))
	quit(0 if error == OK else 1)
