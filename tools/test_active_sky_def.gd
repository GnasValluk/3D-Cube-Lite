extends Node

## Definitive: with the scene untouched (own cameras), does editing the ACTIVE sky
## material in-place change the render? Replace e.sky.sky_material with a trivial
## green shader and set BG_COLOR blue, then replace whole env.

func _mid() -> Color:
	var img := get_viewport().get_texture().get_image()
	return img.get_pixel(img.get_width() / 2, int(img.get_height() * 0.1))

func _ready() -> void:
	print("== active_sky_def ==")
	if TimeSystem:
		TimeSystem.set_hour(12.0)
		TimeSystem.set_time_scale(0.0)
	var scene: PackedScene = load("res://scenes/open_world_real.tscn")
	var inst: Node = scene.instantiate()
	add_child(inst)
	for i in 20:
		await get_tree().process_frame
	var we := inst.get_node_or_null("WorldEnvironment") as WorldEnvironment
	var cam: Camera3D = get_viewport().get_camera_3d()
	var e: Environment = we.environment
	print("cam=%s WE.env.mode=%d BG_SKY=%d sky_set=%s"
		% [cam.name, e.background_mode, Environment.BG_SKY, str(e.sky != null)])

	# 1) in-place sky material swap -> green
	var m := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = "shader_type sky; void sky() { COLOR = vec3(0.0, 1.0, 0.0); }"
	m.shader = sh
	e.sky.sky_material = m
	for i in 4:
		await get_tree().process_frame
	print("1) in-place green sky = %s (expect green)" % str(_mid()))

	# 2) in-place BG_COLOR blue
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0, 0, 1)
	for i in 4:
		await get_tree().process_frame
	print("2) in-place blue bg   = %s (expect blue)" % str(_mid()))

	# 3) replace whole env resource with red
	var red := Environment.new()
	red.background_mode = Environment.BG_COLOR
	red.background_color = Color(1, 0, 0)
	we.environment = red
	for i in 4:
		await get_tree().process_frame
	print("3) replaced red env  = %s (expect red)" % str(_mid()))
	get_tree().quit(0)