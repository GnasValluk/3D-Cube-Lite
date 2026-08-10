extends Node

## Root cause probe: does WorldEnvironment re-register its environment if assigned
## AFTER it is already in tree / via defer? Toggle null->env to force re-register.

func _ready() -> void:
	print("== rereg_probe ==")
	if TimeSystem:
		TimeSystem.set_hour(12.0)
		TimeSystem.set_time_scale(0.0)
	var scene: PackedScene = load("res://scenes/open_world_real.tscn")
	var inst: Node = scene.instantiate()
	add_child(inst)
	for i in 30:
		await get_tree().process_frame
	var we := inst.get_node_or_null("WorldEnvironment") as WorldEnvironment
	var env: Environment = we.environment
	print("we.environment instance: %s" % env.get_instance_id())

	# 1) Force re-register same env: null then back
	we.environment = null
	await get_tree().process_frame
	we.environment = env
	await get_tree().process_frame
	var c := get_viewport().get_texture().get_image().get_pixel(247, 27)
	print("after null->env re-register: (%.3f, %.3f, %.3f)" % [c.r, c.g, c.b])

	# 2) Fresh env via build_sky, assigned later (known-good path)
	var fresh := Environment.new()
	fresh.background_mode = Environment.BG_SKY
	fresh.sky = SkyLight.build_sky()[0]
	SkyLight.update_sky(fresh.sky.sky_material as ShaderMaterial, 12.0, 0.0)
	we.environment = fresh
	await get_tree().process_frame
	await get_tree().process_frame
	var c2 := get_viewport().get_texture().get_image().get_pixel(247, 27)
	print("after fresh env: (%.3f, %.3f, %.3f)" % [c2.r, c2.g, c2.b])
	get_tree().quit(0)