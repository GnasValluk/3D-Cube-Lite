extends Node

## Screenshot capture: render world with environment, save PNG of viewport.

func _ready() -> void:
	print("== sky_capture ==")
	var scene: PackedScene = load("res://scenes/open_world_real.tscn")
	var inst: Node = scene.instantiate()
	add_child(inst)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	# chờ vài frame để sky initted + chắc chắn world gen không crash
	for i in 15:
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://out_sky_capture.png")
	print("saved out_sky_capture.png %dx%d" % [img.get_width(), img.get_height()])
	get_tree().quit(0)