extends Node

## Check: does the WorldEnvironment's ACTIVE sky material == rw._sky_mat?
## Also check background energy, tonemap, and current camera.

func _ready() -> void:
	print("== sky_identity ==")
	if TimeSystem:
		TimeSystem.set_hour(12.0)
		TimeSystem.set_time_scale(0.0)
	var scene: PackedScene = load("res://scenes/open_world_real.tscn")
	var inst: Node = scene.instantiate()
	add_child(inst)
	for i in 12:
		await get_tree().process_frame
	var env := inst.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if env == null:
		print("no env")
		get_tree().quit(1)
		return
	var rw := env as RealWorldEnvironment
	var e: Environment = rw.environment
	var sky: Sky = e.sky
	print("rw._sky_mat == env.sky.sky_material ? %s" % str(rw._sky_mat == sky.sky_material))
	print("env.sky.sky_material is ShaderMaterial ? %s" % str(sky.sky_material is ShaderMaterial))
	print("env.background_mode=%d BG_SKY=%d" % [e.background_mode, Environment.BG_SKY])
	print("env.background_energy_multiplier=%s" % str(e.background_energy_multiplier))
	print("env.tonemap_mode=%d exposure=%s" % [e.tonemap_mode, str(e.tonemap_exposure)])
	print("env.adjustment enabled=%s bright=%s cont=%s sat=%s" % [str(e.adjustment_enabled), str(e.adjustment_brightness), str(e.adjustment_contrast), str(e.adjustment_saturation)])
	var cam: Camera3D = get_viewport().get_camera_3d()
	print("current cam=%s pos=%s rot=%s" % [cam.name if cam else "none", cam.global_position if cam else "-", cam.rotation_degrees if cam else "-"])
	if cam:
		print("cam env override? %s" % str(cam.environment))
	get_tree().quit(0)