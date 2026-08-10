extends Node

## Sample viewport pixels of real scene at noon, print row colors (sky row areas).

func _ready() -> void:
	print("== pixel_probe ==")
	if TimeSystem:
		TimeSystem.set_hour(12.0)
		TimeSystem.set_time_scale(0.0)
	var scene: PackedScene = load("res://scenes/open_world_real.tscn")
	var inst: Node = scene.instantiate()
	add_child(inst)
	for i in 25:
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	var w := img.get_width()
	var h := img.get_height()
	for row in [int(h * 0.05), int(h * 0.15), int(h * 0.3), int(h * 0.5), int(h * 0.85)]:
		var vals: Array = []
		for col_r in range(5):
			var col := int(w * (col_r + 0.5) / 5.0)
			var p: Color = img.get_pixel(col, row)
			vals.append("%.2f,%.2f,%.2f" % [p.r, p.g, p.b])
		print("row %.2f: %s" % [float(row) / h, " | ".join(vals)])
	get_tree().quit(0)