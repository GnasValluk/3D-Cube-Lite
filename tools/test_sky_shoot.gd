extends Node

## Render the real night sky (build_sky + update_sky) and save PNGs at several
## angles/times so we can visually evaluate star density, size, twinkle, moon.

func _ready() -> void:
	print("== sky_shoot ==")
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky: Array = SkyLight.build_sky()
	env.sky = sky[0]
	var mat := sky[1] as ShaderMaterial
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	for f in 8:
		SkyLight.update_sky(mat, 1.0, 0.0)
		await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute("res://tools/out")
	var i := 0
	for ang in [0.0, 45.0, 90.0]:
		var cam := Camera3D.new()
		cam.fov = 70.0
		cam.global_position = Vector3(0, 2, 0)
		# pitch toward sky: 45 / 0 / -45
		var target := Vector3(0, 100, 0).rotated(Vector3.RIGHT, deg_to_rad(0.0))
		cam.global_rotation = Vector3(deg_to_rad(-10.0), 0, 0)
		add_child(cam)
		await get_tree().process_frame
		for f in 5:
			SkyLight.update_sky(mat, 1.0, 0.0)
			await get_tree().process_frame
		await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		var p := "res://tools/out/sky_%d.png" % i
		img.save_png(p)
		print("saved " + p)
		await get_tree().process_frame
		cam.queue_free()
		i += 1
	# one with moon up high visible face-on
	var cam2 := Camera3D.new()
	cam2.fov = 70.0
	cam2.global_position = Vector3(0, 2, 0)
	cam2.look_at_from_position(Vector3(0, 2, 0), Vector3(0, 100, -1), Vector3(0, 0, 1))
	add_child(cam2)
	for f in 5:
		SkyLight.update_sky(mat, 1.0, 0.0)
		await get_tree().process_frame
	await get_tree().process_frame
	var im2 := get_viewport().get_texture().get_image()
	im2.save_png("res://tools/out/sky_moon.png")
	print("saved sky_moon.png")
	get_tree().quit(0)