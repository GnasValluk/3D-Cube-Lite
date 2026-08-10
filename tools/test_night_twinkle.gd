extends Node

## Isolation night: fine full-screen scan over frames; report per-cell brightness
## variance across TIME (twinkle) and count bright star-like cells.

func _ready() -> void:
	print("== night_twinkle ==")
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

	# 40x20 grid; store brightness per cell over 10 frames (TIME advances)
	var wx := 40
	var hy := 20
	var cell_v: Array = []  # per-cell list of b over frames
	for i in wx * hy:
		cell_v.append([])
	for f in 10:
		var img := get_viewport().get_texture().get_image()
		for ry in hy:
			for rx in wx:
				var c: Color = img.get_pixel(img.get_width() * (rx + 0.5) / wx,
					img.get_height() * (ry + 0.5) / hy)
				cell_v[ry * wx + rx].append((c.r + c.g + c.b) / 3.0)
		await get_tree().process_frame
	var bright: int = 0
	for v in cell_v:
		if v.max() > 0.06:
			bright += 1
	var twinkling: int = 0
	for v in cell_v:
		if v.max() > 0.06 and v.max() - v.min() > 0.03:
			twinkling += 1
	# print map of cells that twinkle
	print("bright cells=%d/%d  twinkling among them=%d" % [bright, wx * hy, twinkling])
	var row: String = ""
	for ry in hy:
		row = ""
		for rx in wx:
			var v: Array = cell_v[ry * wx + rx]
			if v.max() < 0.06:
				row += "."
			elif v.max() - v.min() > 0.06:
				row += "T"  # strong twinkle
			elif v.max() - v.min() > 0.03:
				row += "t"
			else:
				row += "#"  # bright constant
		print("  " + row)
	get_tree().quit(0)