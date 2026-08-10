extends Node

## If replacing whole env with BG_SKY+green renders green, sky pipeline works when
## resource is swapped. Then the bug is IN-PLACE material edits not propagating.

func _mid() -> Color:
	var img := get_viewport().get_texture().get_image()
	return img.get_pixel(img.get_width() / 2, int(img.get_height() * 0.1))

func _ready() -> void:
	print("== replace_env_sky ==")
	if TimeSystem:
		TimeSystem.set_hour(12.0)
		TimeSystem.set_time_scale(0.0)
	var scene: PackedScene = load("res://scenes/open_world_real.tscn")
	var inst: Node = scene.instantiate()
	add_child(inst)
	for i in 20:
		await get_tree().process_frame
	var we := inst.get_node_or_null("WorldEnvironment") as WorldEnvironment

	var m := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = "shader_type sky; void sky() { COLOR = vec3(0.0, 1.0, 0.0); }"
	m.shader = sh
	var sky := Sky.new()
	sky.sky_material = m
	sky.process_mode = Sky.PROCESS_MODE_REALTIME
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.fog_enabled = false
	we.environment = env
	for i in 6:
		await get_tree().process_frame
	print("replaced env w/ green sky = %s (expect GREEN)" % str(_mid()))

	var m2 := ShaderMaterial.new()
	var sh2 := Shader.new()
	sh2.code = "shader_type sky;" + "void sky() { float y=normalize(EYEDIR).y; COLOR=vec3(y,y,1.0); }"
	m2.shader = sh2
	sky.sky_material = m2
	for i in 6:
		await get_tree().process_frame
	print("swapped sky material in-place = %s (expect gradient blue)" % str(_mid()))
	get_tree().quit(0)