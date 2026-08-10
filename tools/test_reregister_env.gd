extends Node

## Test: does re-assigning we.environment = we.environment (re-register) make
## in-place edits to the built env take effect? Then drive hour to verify gradient.

func _mid() -> Color:
	var img := get_viewport().get_texture().get_image()
	return img.get_pixel(img.get_width() / 2, int(img.get_height() * 0.1))

func _ready() -> void:
	print("== reregister_env ==")
	if TimeSystem:
		TimeSystem.set_hour(12.0)
		TimeSystem.set_time_scale(0.0)
	var scene: PackedScene = load("res://scenes/open_world_real.tscn")
	var inst: Node = scene.instantiate()
	add_child(inst)
	for i in 20:
		await get_tree().process_frame
	var we := inst.get_node_or_null("WorldEnvironment") as WorldEnvironment
	var env: Environment = we.environment
	var rw := we as RealWorldEnvironment
	print("buf before   = %s" % str(_mid()))

	# Re-assign same object to force node re-register
	we.environment = env
	for i in 6:
		await get_tree().process_frame
	print("buf after re-register = %s" % str(_mid()))

	# Now manually push noon via the script's own path and check
	rw.set_process(false)
	SkyLight.update_sky(rw._sky_mat, 12.0, 0.0)
	for i in 4:
		await get_tree().process_frame
	print("after update_sky(noon) = %s" % str(_mid()))
	print("sky_top uniform set? %s" % str(rw._sky_mat.get_shader_parameter("sky_top_color")))
	get_tree().quit(0)