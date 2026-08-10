extends Node

## Isolation: verify sun/moon dir and do a FINE scan of the moon's location.
## Compute where moon_dir projects on screen; sample that pixel region finely.

func _ready() -> void:
	print("== night_iso2 ==")
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
	for f in 6:
		SkyLight.update_sky(mat, 23.0, 0.0)
		await get_tree().process_frame

	var sun_dir: Vector3 = mat.get_shader_parameter("sun_dir")
	var moon_dir: Vector3 = mat.get_shader_parameter("moon_dir")
	print("sun_dir=%s moon_dir=%s moon_energy=%s" % [
		str(sun_dir), str(moon_dir), str(mat.get_shader_parameter("moon_energy"))])

	# project moon_dir into camera space to find screen coords
	var cam_t := cam.global_transform
	var cam_back := -cam_t.basis.z
	var up := cam_t.basis.y
	# screen ray construction: forward is cam_back
	var ndc := cam.unproject_position(cam.global_position + moon_dir * 100.0)
	print("moon unproject = %s (screen %dx%d)" % [str(ndc), get_viewport().get_visible_rect().size.x, get_viewport().get_visible_rect().size.y])

	# fine scan: 32x32 grid across moon screen region -> find max brightness pixel
	var img := get_viewport().get_texture().get_image()
	var w := img.get_width()
	var hgt := img.get_height()
	var best: float = -1.0
	var bestpx := Vector2i.ZERO
	for ry in range(0, hgt, 3):
		for rx in range(0, w, 3):
			var c: Color = img.get_pixel(rx, ry)
			var b := (c.r + c.g + c.b) / 3.0
			if b > best:
				best = b
				bestpx = Vector2i(rx, ry)
	print("max brightness=%f at px %s (that is w=%.2f h=%.2f)" % [best, str(bestpx), float(bestpx.x) / w, float(bestpx.y) / hgt])
	get_tree().quit(0)