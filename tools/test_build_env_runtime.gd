extends Node

## Compare in ONE run: (A) scene-built env, (B) runtime _build_env(), (C) fresh env.

func _ready() -> void:
	print("== build_env_runtime ==")
	if TimeSystem:
		TimeSystem.set_hour(12.0)
		TimeSystem.set_time_scale(0.0)
	var scene: PackedScene = load("res://scenes/open_world_real.tscn")
	var inst: Node = scene.instantiate()
	add_child(inst)
	for i in 30:
		await get_tree().process_frame
	var we := inst.get_node_or_null("WorldEnvironment") as WorldEnvironment

	var c := get_viewport().get_texture().get_image().get_pixel(247, 27)
	print("A: scene-built env      : (%.3f, %.3f, %.3f)" % [c.r, c.g, c.b])

	we.call("_build_env")
	await get_tree().process_frame
	await get_tree().process_frame
	var c2 := get_viewport().get_texture().get_image().get_pixel(247, 27)
	print("B: runtime _build_env   : (%.3f, %.3f, %.3f)" % [c2.r, c2.g, c2.b])

	var fresh := Environment.new()
	fresh.background_mode = Environment.BG_SKY
	fresh.sky = SkyLight.build_sky()[0]
	SkyLight.update_sky(fresh.sky.sky_material as ShaderMaterial, 12.0, 0.0)
	we.environment = fresh
	await get_tree().process_frame
	await get_tree().process_frame
	var c3 := get_viewport().get_texture().get_image().get_pixel(247, 27)
	print("C: fresh env (build_sky): (%.3f, %.3f, %.3f)" % [c3.r, c3.g, c3.b])
	get_tree().quit(0)