extends Node

## Dump every relevant property of the ready-built Sky vs a fresh build_sky Sky.

func _ready() -> void:
	print("== sky_res_diff ==")
	if TimeSystem:
		TimeSystem.set_hour(12.0)
		TimeSystem.set_time_scale(0.0)
	var scene: PackedScene = load("res://scenes/open_world_real.tscn")
	var inst: Node = scene.instantiate()
	add_child(inst)
	for i in 20:
		await get_tree().process_frame
	var rw := inst.get_node_or_null("WorldEnvironment") as RealWorldEnvironment
	var real_sky: Sky = rw.environment.sky
	var real_mat: ShaderMaterial = real_sky.sky_material as ShaderMaterial

	var fresh := SkyLight.build_sky()
	var fresh_sky: Sky = fresh[0]
	var fresh_mat: ShaderMaterial = fresh[1]
	SkyLight.update_sky(fresh_mat, 12.0, 0.0)

	print("REAL sky: process_mode=%d (REALTIME=%d INC=%d)" % [real_sky.process_mode, Sky.PROCESS_MODE_REALTIME, Sky.PROCESS_MODE_INCREMENTAL])
	print("REAL sky: radiance_size=%d reflection_size=%d" % [real_sky.radiance_size, real_sky.reflection_size])
	print("FRESH sky: process_mode=%d radiance_size=%d reflection_size=%d" % [fresh_sky.process_mode, fresh_sky.radiance_size, fresh_sky.reflection_size])
	print("same shader? real=%s fresh=%s" % [real_mat.shader.resource_path, fresh_mat.shader.resource_path])

	var props_sky := ["sky_top_color", "sky_horizon_color", "sky_curve", "sky_energy", "sun_dir", "sun_color", "sun_energy", "night_factor", "weather"]
	for p in props_sky:
		var rv: Variant = real_mat.get_shader_parameter(p)
		var fv: Variant = fresh_mat.get_shader_parameter(p)
		print("  %-20s real=%s  fresh=%s" % [p, str(rv), str(fv)])
	get_tree().quit(0)