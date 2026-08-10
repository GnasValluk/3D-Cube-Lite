extends Node

## Diagnose: full scene, disable rain cloud boxes, sample sky column.

func _ready() -> void:
	print("== scene_no_clouds ==")
	if TimeSystem:
		TimeSystem.set_hour(12.0)
		TimeSystem.set_time_scale(0.0)
	var scene: PackedScene = load("res://scenes/open_world_real.tscn")
	var inst: Node = scene.instantiate()
	add_child(inst)
	for i in 15:
		await get_tree().process_frame
	# disable cloud + rain visuals
	var rm := inst.get_node_or_null("RainManager") as Node
	if rm:
		for ch in rm.get_children():
			ch.set("visible", false)
			ch.set("emitting", false)
		print("RainManager children hidden")
	for i in 8:
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	var w := img.get_width()
	var h := img.get_height()
	for j in 8:
		var y := int(h * (0.03 + 0.12 * j))
		var c := img.get_pixel(w / 2, y)
		print("  y=%3d%% rgb=(%.3f %.3f %.3f)" % [int(100 * y / h), c.r, c.g, c.b])
	var env := inst.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if env:
		var rw := env as RealWorldEnvironment
		if rw and rw._sky_mat:
			print("sky uniforms: top=%s energy=%s"
				% [str(rw._sky_mat.get_shader_parameter("sky_top_color")), str(rw._sky_mat.get_shader_parameter("sky_energy"))])
	get_tree().quit(0)