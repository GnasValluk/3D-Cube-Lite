extends Node

## Isolated night-sky render: static camera up, dump coarse brightness map
## (12x10 grid over screen) across frames with TIME advancing to catch stars,
## the moon glow, and twinkle. No scene / rig interference.

func _ready() -> void:
	print("== night_iso ==")
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky: Array = SkyLight.build_sky()
	env.sky = sky[0]
	var mat := sky[1] as ShaderMaterial
	for h in 24.0:
		pass
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var cam := Camera3D.new()
	cam.global_position = Vector3(0, 2, 0)
	cam.look_at(Vector3(0, 100, 0), Vector3(0, 0, 1))
	cam.fov = 70.0
	add_child(cam)
	# moon at zenith for hour 23; show per-star temporal variance too
	for f in 10:
		SkyLight.update_sky(mat, 23.0, 0.0)
		await get_tree().process_frame
	var grid: Array = []
	for f in 4:
		var img := get_viewport().get_texture().get_image()
		var row: Array = []
		for ry in 10:
			var line: String = ""
			for rx in 12:
				var c: Color = img.get_pixel(img.get_width() * (rx + 0.5) / 12.0,
					img.get_height() * (ry + 0.5) / 10.0)
				var b := (c.r + c.g + c.b) / 3.0
				line += ("%3d" % min(999, int(b * 1000))).pad_zeros(3) + " "
			row.append(line)
		grid.append(row)
		print("frame%d:" % f)
		for line in row:
			print("  " + line)
		await get_tree().process_frame
	get_tree().quit(0)