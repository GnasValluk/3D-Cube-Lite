extends Node

## ASCII map of night sky (brightness bucketed) to SEE moon size + star dots,
## then trace 3 off-moon sky pixels over 40 frames for twinkle.

func _ready() -> void:
	print("== sky_map ==")
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
	var img := get_viewport().get_texture().get_image()
	var w := img.get_width()
	var hgt := img.get_height()
	var W := 64
	var H := 24
	for ry in H:
		var line: String = ""
		for rx in W:
			var c: Color = img.get_pixel(w * (rx + 0.5) / W, hgt * (ry + 0.5) / H)
			var b := (c.r + c.g + c.b) / 3.0
			var ch := "."
			if b > 0.9: ch = "M"
			elif b > 0.5: ch = "m"
			elif b > 0.2: ch = "#"
			elif b > 0.1: ch = "+"
			elif b > 0.06: ch = "*"
			elif b > 0.02: ch = ":"
			line += ch
		print(line)
	# trace off-moon pixels (upper-left quadrant, cols 6-20 rows 2-6)
	var pts := [Vector2i(110, 60), Vector2i(70, 50), Vector2i(150, 100), Vector2i(40, 80)]
	var lbl: String = ""
	for p in pts: lbl += "(%d,%d)" % [p.x, p.y]
	print("trace pts: %s" % lbl)
	for f in 40:
		SkyLight.update_sky(mat, 23.0, 0.0)
		var im := get_viewport().get_texture().get_image()
		var out: String = "f%03d" % f
		for p in pts:
			var c: Color = im.get_pixel(p.x, p.y)
			out += " %.3f" % ((c.r + c.g + c.b) / 3.0)
		print(out)
		await get_tree().process_frame
	get_tree().quit(0)