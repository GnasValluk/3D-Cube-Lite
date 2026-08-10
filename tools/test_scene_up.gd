extends Node

## Full scene, custom camera straight up, sample + count env nodes.

func _ready() -> void:
	print("== scene_up ==")
	if TimeSystem:
		TimeSystem.set_hour(12.0)
		TimeSystem.set_time_scale(0.0)
	var scene: PackedScene = load("res://scenes/open_world_real.tscn")
	var inst: Node = scene.instantiate()
	add_child(inst)
	for i in 15:
		await get_tree().process_frame
	var envs := inst.find_children("*", "WorldEnvironment", true, false)
	print("WorldEnvironment nodes: %d" % envs.size())
	var cam := Camera3D.new()
	cam.current = true
	cam.rotation_degrees = Vector3(90, 0, 0)
	add_child(cam)
	for i in 8:
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	var w := img.get_width()
	var h := img.get_height()
	for j in 6:
		var y := int(h * (0.1 + 0.15 * j))
		var c := img.get_pixel(w / 2, y)
		print("  y=%3d%% rgb=(%.3f %.3f %.3f)" % [int(100 * y / h), c.r, c.g, c.b])
	get_tree().quit(0)