extends Node

## Isolation: (A) does WorldEnvironment apply to viewport? (B) does custom sky
## shader output anything? Uses pure color background vs sky.

func _sample_mid() -> Color:
	var img := get_viewport().get_texture().get_image()
	return img.get_pixel(img.get_width() / 2, int(img.get_height() * 0.3))

func _ready() -> void:
	print("== sky_isolate ==")
	# A) pure red clear color
	var we := WorldEnvironment.new()
	add_child(we)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(1, 0, 0)
	we.environment = env
	var cam := Camera3D.new()
	cam.current = true
	add_child(cam)
	await get_tree().process_frame
	await get_tree().process_frame
	print("BG_COLOR red sample = %s (expect red)" % str(_sample_mid()))

	# B) custom sky shader alone
	var sky_data := SkyLight.build_sky()
	var mat: ShaderMaterial = sky_data[1]
	SkyLight.update_sky(mat, 12.0, 0.0)
	var env2 := Environment.new()
	env2.background_mode = Environment.BG_SKY
	env2.sky = sky_data[0]
	we.environment = env2
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	print("sky shader noon sample = %s" % str(_sample_mid()))
	print("uniform sky_top_color = %s" % str(mat.get_shader_parameter("sky_top_color")))
	get_tree().quit(0)