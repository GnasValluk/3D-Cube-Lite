extends Node

## Full-scene capture at several hours with camera angled into the sky;
## prints a column of pixels to diagnose the flat-gray issue.

func _ready() -> void:
	print("== scene_hour_capture ==")
	if TimeSystem:
		TimeSystem.set_hour(12.0)
		TimeSystem.set_time_scale(0.0)
	var scene: PackedScene = load("res://scenes/open_world_real.tscn")
	var inst: Node = scene.instantiate()
	add_child(inst)
	var cam := inst.get_node("TPCameraRig/Camera3D") as Camera3D
	if cam:
		cam.current = true
		cam.set_pitch(-25.0) if cam.has_method("set_pitch") else null
	for i in 20:
		await get_tree().process_frame
	for hour in [12.0]:
		if TimeSystem:
			TimeSystem.set_hour(hour)
		for i in 6:
			await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		var w := img.get_width()
		var h := img.get_height()
		print("--- hour %4.1f ---" % hour)
		for j in 10:
			var y := int(h * (0.03 + 0.10 * j))
			var c := img.get_pixel(w / 2, y)
			print("  y=%3d%% rgb=(%.3f %.3f %.3f)" % [int(100 * y / h), c.r, c.g, c.b])
	get_tree().quit(0)