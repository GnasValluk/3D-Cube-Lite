extends Node

## Check sky shader output more thoroughly at noon + heights.

func _sample_grid() -> void:
	var img := get_viewport().get_texture().get_image()
	var w := img.get_width()
	var h := img.get_height()
	for i in 8:
		var y := int(h * (0.06 + 0.11 * i))
		var c := img.get_pixel(w / 2, y)
		print("  y=%3d%% rgb=(%.3f %.3f %.3f)" % [int(100 * y / h), c.r, c.g, c.b])

func _ready() -> void:
	print("== sky_grid ==")
	var we := WorldEnvironment.new()
	add_child(we)
	var cam := Camera3D.new()
	cam.current = true
	add_child(cam)
	cam.global_position = Vector3(0, 6, 8)
	cam.look_at(Vector3(0, 0, 0))
	await get_tree().process_frame
	var sky_data := SkyLight.build_sky()
	var mat: ShaderMaterial = sky_data[1]
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky_data[0]
	we.environment = env
	await get_tree().process_frame
	SkyLight.update_sky(mat, 12.0, 0.0)
	await get_tree().process_frame
	await get_tree().process_frame
	print("NOON:")
	_sample_grid()
	print("sun_dir=%s sun_energy=%s" % [str(mat.get_shader_parameter("sun_dir")), str(mat.get_shader_parameter("sun_energy"))])
	print("sky_energy=%s" % str(mat.get_shader_parameter("sky_energy")))
	get_tree().quit(0)