extends Node

## Sample the moon-edge / star-field brightness over 30 frames to measure
## TIME-driven twinkle amplitude directly.

func _ready() -> void:
	print("== twinkle_trace ==")
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
	# candidate: brightest pixel outside moon core region (right-of-center area)
	var img0 := get_viewport().get_texture().get_image()
	var w := img0.get_width()
	var hgt := img0.get_height()
	# find 5 brightest pixels overall for tracing
	var map: Dictionary = {}
	for ry in range(0, hgt, 2):
		for rx in range(0, w, 2):
			var c: Color = img0.get_pixel(rx, ry)
			map[Vector2i(rx, ry)] = (c.r + c.g + c.b) / 3.0
	var sorted_keys: Array = map.keys()
	sorted_keys.sort_custom(func(a, b): return map[a] > map[b])
	var trace: Array = sorted_keys.slice(0, 8)
	var tracelbl: String = ""
	for k in trace:
		tracelbl += "(%d,%d)" % [k.x, k.y]
	print("tracing pixels: %s" % tracelbl)
	for f in 30:
		var img := get_viewport().get_texture().get_image()
		var out: String = "f%02d" % f
		for k in trace:
			var c: Color = img.get_pixel(k.x, k.y)
			out += " %.3f" % ((c.r + c.g + c.b) / 3.0)
		print(out)
		await get_tree().process_frame
	get_tree().quit(0)