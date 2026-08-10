extends Node

## Compare: plain WorldEnvironment+sky vs RealWorldEnvironment script.
## Both pointing camera up (full sky). Samples center-top pixels.

func _mid_color() -> Color:
	var img := get_viewport().get_texture().get_image()
	return img.get_pixel(img.get_width() / 2, int(img.get_height() * 0.25))

func _ready() -> void:
	print("== sky_compare ==")
	var cam := Camera3D.new()
	cam.current = true
	add_child(cam)
	cam.global_position = Vector3(0, 5, 0)

	# A) plain world + sky at noon
	var we := WorldEnvironment.new()
	add_child(we)
	var sky_data := SkyLight.build_sky()
	SkyLight.update_sky(sky_data[1] as ShaderMaterial, 12.0, 0.0)
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky_data[0]
	we.environment = env
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	print("A plain noon sky  = %s" % str(_mid_color()))

	# B) RealWorldEnvironment script (with its own env built in _ready)
	var rw_script: GDScript = load("res://scripts/world/environment/real_world_environment.gd")
	var rw: WorldEnvironment = rw_script.new() as WorldEnvironment
	add_child(rw)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	print("B RealWorld  noon = %s" % str(_mid_color()))
	rw.queue_free()

	# C) RealWorldEnvironment but force sky update to noon
	var rw2: WorldEnvironment = rw_script.new() as WorldEnvironment
	add_child(rw2)
	rw2.set_process(false)
	await get_tree().process_frame
	var rwe := rw2 as RealWorldEnvironment
	SkyLight.update_sky(rwe._sky_mat, 12.0, 0.0)
	rw2.set_process(true)
	await get_tree().process_frame
	await get_tree().process_frame
	print("C RealWorld forced noon = %s" % str(_mid_color()))
	get_tree().quit(0)