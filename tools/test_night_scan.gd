extends Node

## Night render probe: sample a grid across the whole sky region for MAX
## brightness (catch stars + moon), over frames with TIME advancing (twinkle).

func _ready() -> void:
	print("== night_scan ==")
	if TimeSystem:
		TimeSystem.set_hour(23.0)
		TimeSystem.set_time_scale(1.0)
	var scene: PackedScene = load("res://scenes/open_world_real.tscn")
	var inst: Node = scene.instantiate()
	add_child(inst)
	for i in 30:
		await get_tree().process_frame
	var cam := get_viewport().get_camera_3d()
	if cam:
		cam.global_position = Vector3(0, 10, 0)
		cam.look_at(Vector3(0, 100, 0))
	await get_tree().process_frame
	var w := 0
	var hgt := 0
	var frames: Array = []
	for f in 6:
		var img := get_viewport().get_texture().get_image()
		w = img.get_width()
		hgt = img.get_height()
		var arr: Array = []
		for rx in 16:
			for ry in 12:
				arr.append((img.get_pixel(w * (rx + 0.5) / 16.0, hgt * (0.5 + ry * 0.04)).r
				+ img.get_pixel(w * (rx + 0.5) / 16.0, hgt * (0.5 + ry * 0.04)).g
				+ img.get_pixel(w * (rx + 0.5) / 16.0, hgt * (0.5 + ry * 0.04)).b) / 3.0)
		frames.append(arr)
		await get_tree().process_frame
	# per-cell brightness delta across frames (twinkle indicator)
	var maxb: float = frames[0].max()
	var idx: int = frames[0].find(maxb)
	var cell_x := (idx % 16) / 16.0
	var cell_y := 0.5 + (idx / 16) * 0.04
	var per_frame: Array = []
	for f in frames:
		per_frame.append(f[idx])
	print("brightest frame0: br=%.3f at (x=%.2f y=%.2f) per_frame=%s"
		% [maxb, cell_x, cell_y, str(per_frame)])
	# average brightness across sky region per frame
	var avg0: float = 0.0
	for v in frames[0]: avg0 += v
	print("sky avg br frame0 = %.4f" % (avg0 / frames[0].size()))
	get_tree().quit(0)