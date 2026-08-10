extends Node

## Probe: what env does the ACTIVE camera see? And does the WE node's environment
## change after init? Try replacing the WE's environment with a fresh trivial red,
## then ALSO set camera.environment, and check.

func _snap() -> Array[Color]:
	var img := get_viewport().get_texture().get_image()
	var w := img.get_width()
	var h := img.get_height()
	return [
		img.get_pixel(w / 2, int(h * 0.05)),
		img.get_pixel(w / 2, int(h * 0.2)),
		img.get_pixel(w / 2, int(h * 0.4)),
		img.get_pixel(w / 2, int(h * 0.6)),
	]

func _ready() -> void:
	print("== probe_active_env ==")
	if TimeSystem:
		TimeSystem.set_hour(12.0)
		TimeSystem.set_time_scale(0.0)
	var scene: PackedScene = load("res://scenes/open_world_real.tscn")
	var inst: Node = scene.instantiate()
	add_child(inst)
	for i in 20:
		await get_tree().process_frame
	var we := inst.get_node_or_null("WorldEnvironment") as WorldEnvironment
	var cam: Camera3D = get_viewport().get_camera_3d()
	print("WE=%s cam=%s cam.env=%s" % [str(we), str(cam.name), str(cam.environment)])
	print("WE.environment set? %s mode=%s" % [str(we.environment != null), we.environment.background_mode if we.environment else "-"])

	print("--- step 1: make trivial RED env and assign to WE node ---")
	var env_red := Environment.new()
	env_red.background_mode = Environment.BG_COLOR
	env_red.background_color = Color(1, 0, 0)
	we.environment = env_red
	for i in 5:
		await get_tree().process_frame
	print("after WE.red = %s" % str(_snap()))
	print("  (top should be red if WE env is active)")
	get_tree().quit(0)