extends Node

## Render full scene at noon, print ASCII-ish coarse color map (16x10).

func _ready() -> void:
	print("== scene_pixel_map ==")
	if TimeSystem:
		TimeSystem.set_hour(12.0)
		TimeSystem.set_time_scale(0.0)
	var scene: PackedScene = load("res://scenes/open_world_real.tscn")
	var inst: Node = scene.instantiate()
	add_child(inst)
	for i in 15:
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	var w := img.get_width()
	var h := img.get_height()
	var cs := 16
	var rs := 10
	for r in rs:
		var line := ""
		for c in cs:
			var px := img.get_pixel(int((c + 0.5) * w / cs), int((r + 0.5) * h / rs))
			var ch := "."
			var lum: float = px.r * 0.3 + px.g * 0.6 + px.b * 0.1
			if px.r > px.b and px.r > 0.5:
				ch = "R"   # đỏ
			elif lum > 0.7:
				ch = "#"   # sáng
			elif lum > 0.4:
				ch = "o"   # trung
			elif lum > 0.15:
				ch = "*"   # tối
			else:
				ch = " "
			line += ch
		print(line)
	get_tree().quit(0)