extends Node

## Test the sky with PROCESS_MODE_UPDATE (rebuild manually) in full scene.

func _ready() -> void:
	print("== sky_mode_cmp ==")
	var tab := "\t"
	var we := WorldEnvironment.new()
	add_child(we)
	var cam := Camera3D.new()
	cam.current = true
	cam.rotation_degrees = Vector3(90, 0, 0)
	add_child(cam)
	await get_tree().process_frame

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY

	# INCREMENTAL (như build_sky hiện tại)
	var mat_inc := ShaderMaterial.new()
	mat_inc.shader = preload("res://scripts/world/environment/sky.gdshader")
	var sky_inc := Sky.new()
	sky_inc.sky_material = mat_inc
	sky_inc.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	SkyLight.update_sky(mat_inc, 12.0, 0.0)
	env.sky = sky_inc
	we.environment = env
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	var c1 := img.get_pixel(img.get_width() / 2, int(img.get_height() * 0.2))
	print("INCREMENTAL zenith = %s" % str(c1))

	# UPDATE (luôn render lại)
	var mat_up := ShaderMaterial.new()
	mat_up.shader = preload("res://scripts/world/environment/sky.gdshader")
	var sky_up := Sky.new()
	sky_up.sky_material = mat_up
	sky_up.process_mode = Sky.PROCESS_MODE_UPDATE
	SkyLight.update_sky(mat_up, 12.0, 0.0)
	env.sky = sky_up
	we.environment = env
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	img = get_viewport().get_texture().get_image()
	var c2 := img.get_pixel(img.get_width() / 2, int(img.get_height() * 0.2))
	print("UPDATE zenith = %s" % str(c2))
	get_tree().quit(0)