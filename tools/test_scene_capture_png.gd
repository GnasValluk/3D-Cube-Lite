extends Node

## Save full-scene noon screenshot as PNG for direct visual inspection.

func _ready() -> void:
	print("== scene_capture_png ==")
	if TimeSystem:
		TimeSystem.set_hour(12.0)
		TimeSystem.set_time_scale(0.0)
	var scene: PackedScene = load("res://scenes/open_world_real.tscn")
	var inst: Node = scene.instantiate()
	add_child(inst)
	for i in 25:
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://out_scene_noon.png")
	print("saved out_scene_noon.png %dx%d" % [img.get_width(), img.get_height()])
	get_tree().quit(0)