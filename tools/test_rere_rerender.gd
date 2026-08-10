extends Node

## Does the sky shader re-render per frame? Toggle sky_energy drastically each
## frame and watch pixels. Distinguishes static-sky vs TIME-frozen.

func _ready() -> void:
	print("== re_render_check ==")
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky: Array = SkyLight.build_sky()
	env.sky = sky[0]
	var mat := sky[1] as ShaderMaterial
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var cam := Camera3D.new()
	cam.fov = 70.0
	add_child(cam)
	cam.global_position = Vector3(0, 2, 0)
	cam.look_at_from_position(Vector3(0, 2, 0), Vector3(0, 100, 0), Vector3(0, 0, 1))
	for f in 8:
		SkyLight.update_sky(mat, 23.0, 0.0)
		await get_tree().process_frame
	var img0 := get_viewport().get_texture().get_image()
	var c0: Color = img0.get_pixel(120, 160)
	mat.set_shader_parameter("sky_energy", 0.0)
	await get_tree().process_frame
	await get_tree().process_frame
	var img1 := get_viewport().get_texture().get_image()
	var c1: Color = img1.get_pixel(120, 160)
	mat.set_shader_parameter("sky_energy", 1.0)
	await get_tree().process_frame
	await get_tree().process_frame
	var img2 := get_viewport().get_texture().get_image()
	var c2: Color = img2.get_pixel(120, 160)
	print("px(120,160): energy1=%.3f  energy0=%.3f  energy1again=%.3f" % [(c0.r + c0.g + c0.b) / 3.0, (c1.r + c1.g + c1.b) / 3.0, (c2.r + c2.g + c2.b) / 3.0])
	get_tree().quit(0)