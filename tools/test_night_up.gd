extends Node

## Render test đêm nhìn lên: verify sao lấp lánh (2 frame khác time) + mặt trăng.

func _ready() -> void:
	print("== night_up ==")
	if TimeSystem:
		TimeSystem.set_hour(23.0)
		TimeSystem.set_time_scale(0.0)
	var scene: PackedScene = load("res://scenes/open_world_real.tscn")
	var inst: Node = scene.instantiate()
	add_child(inst)
	for i in 30:
		await get_tree().process_frame
	var cam := get_viewport().get_camera_3d()
	if cam:
		cam.global_position = Vector3(0, 10, 0)
		cam.look_at(Vector3(0, 100, 0))
	for f in 8:
		await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		var w := img.get_width()
		var hgt := img.get_height()
		var vals: Array = []
		for row_r in 6:
			var row := int(hgt * 0.05 + row_r * hgt * 0.06)
			var p: Color = img.get_pixel(w / 2, row)
			vals.append("r%.1f(%.2f,%.2f,%.2f)" % [row_r * 0.06 + 0.05, p.r, p.g, p.b])
		print("frame%d: %s" % [f, " ".join(vals)])
	get_tree().quit(0)