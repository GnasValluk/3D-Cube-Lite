extends Node

## Dense scan of night sky: count bright pixels (stars) and pixels whose
## brightness oscillates over frames (twinkle). Confirms stars exist + TIME runs.

func _ready() -> void:
	print("== dense_scan ==")
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

	var img0 := get_viewport().get_texture().get_image()
	var w := img0.get_width()
	var hgt := img0.get_height()
	var b0: Array = []
	var b1: Array = []
	for ry in hgt:
		for rx in w:
			var c: Color = img0.get_pixel(rx, ry)
			b0.append((c.r + c.g + c.b) / 3.0)
	await get_tree().process_frame
	for ry in hgt:
		for rx in w:
			var c: Color = img0.get_pixel(rx, ry)
			b1.append((c.r + c.g + c.b) / 3.0)
	var bright: int = 0
	var oscillate: int = 0
	var maxb: float = 0.0
	for i in range(w * hgt):
		if b1[i] > 0.08:
			bright += 1
		if abs(b1[i] - b0[i]) > 0.04:
			oscillate += 1
		if b1[i] > maxb:
			maxb = b1[i]
	print("size=%dx%d  bright(>0.08)=%d  oscillating(>0.04delta)=%d  maxb=%.3f"
		% [w, hgt, bright, oscillate, maxb])
	get_tree().quit(0)