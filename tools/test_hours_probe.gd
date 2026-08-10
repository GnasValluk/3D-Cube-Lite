extends Node

## Probe sky colors across key hours: 7 noon 18 21 0.

func _ready() -> void:
	print("== hours_probe ==")
	if TimeSystem:
		TimeSystem.set_time_scale(0.0)
	var scene: PackedScene = load("res://scenes/open_world_real.tscn")
	var inst: Node = scene.instantiate()
	add_child(inst)
	for h in [7.0, 12.0, 18.0, 21.0, 0.0]:
		if TimeSystem:
			TimeSystem.set_hour(h)
		for i in 6:
			await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		var top: Color = img.get_pixel(247, int(img.get_height() * 0.05))
		var hor: Color = img.get_pixel(247, int(img.get_height() * 0.5))
		print("h%4.1f top=(%.3f,%.3f,%.3f) hor=(%.3f,%.3f,%.3f)"
			% [h, top.r, top.g, top.b, hor.r, hor.g, hor.b])
	get_tree().quit(0)