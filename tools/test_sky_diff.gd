extends Node

## Full-frame pixel diff between consecutive frames. If ANY pixel differs when
## star_time advances, twinkle works; we then zoom on those pixels.

func _ready() -> void:
	print("== sky_diff ==")
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
	var prev := get_viewport().get_texture().get_image()
	for f in 30:
		SkyLight.update_sky(mat, 23.0, 0.0)
		await get_tree().process_frame
		var now := get_viewport().get_texture().get_image()
		var changed := 0
		var maxd := 0.0
		var maxp := Vector2i.ZERO
		for y in now.get_height():
			for x in now.get_width():
				var a: Color = prev.get_pixel(x, y)
				var b: Color = now.get_pixel(x, y)
				var d: float = abs(a.r - b.r) + abs(a.g - b.g) + abs(a.b - b.b)
				if d > 0.001:
					changed += 1
					if d > maxd:
						maxd = d
						maxp = Vector2i(x, y)
		print("f%03d changed=%d maxd=%.3f @%dx%d" % [f, changed, maxd, maxp.x, maxp.y])
		prev = now
	get_tree().quit(0)