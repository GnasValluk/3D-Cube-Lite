extends Node

## Detailed pixel dump: full scene, camera straight up at origin, dump 20x12 grid with exact RGB.

func _ready() -> void:
	print("== dump_up_grid ==")
	if TimeSystem:
		TimeSystem.set_hour(12.0)
		TimeSystem.set_time_scale(0.0)
	var scene: PackedScene = load("res://scenes/open_world_real.tscn")
	var inst: Node = scene.instantiate()
	add_child(inst)
	for i in 20:
		await get_tree().process_frame
	var cam := Camera3D.new()
	cam.current = true
	cam.rotation_degrees = Vector3(90, 0, 0)
	cam.global_position = Vector3(0, 2, 0)
	add_child(cam)
	for i in 6:
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	var w := img.get_width()
	var h := img.get_height()
	var cols := 12
	var rows := 10
	for r in rows:
		var line := ""
		for c in cols:
			var px := img.get_pixel(int((c + 0.5) * w / cols), int((r + 0.5) * h / rows))
			line += "(%d,%d,%d) " % [int(px.r * 255), int(px.g * 255), int(px.b * 255)]
		print(line)
	get_tree().quit(0)