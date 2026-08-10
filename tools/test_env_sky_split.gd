extends Node

## Decisive bisect of stale resource: new Environment object REUSING the real
## scene's sky (same Sky resource) vs reusing sky material. If new-env+old-sky
## renders blue, the Environment RID was stale; if gray, the Sky is stale.

func _ready() -> void:
	print("== env_sky_split ==")
	if TimeSystem:
		TimeSystem.set_hour(12.0)
		TimeSystem.set_time_scale(0.0)
	var scene: PackedScene = load("res://scenes/open_world_real.tscn")
	var inst: Node = scene.instantiate()
	add_child(inst)
	for i in 30:
		await get_tree().process_frame
	var we := inst.get_node_or_null("WorldEnvironment") as WorldEnvironment
	var real: Environment = we.environment
	print("real env sky: %s  mat: %s  process_mode: %d" % [
		real.sky.get_instance_id(),
		real.sky.sky_material.get_instance_id(),
		real.sky.process_mode])

	# New Environment object, SAME Sky resource (reuse real.sky)
	var e2 := Environment.new()
	e2.background_mode = Environment.BG_SKY
	e2.sky = real.sky
	SkyLight.update_sky(e2.sky.sky_material as ShaderMaterial, 12.0, 0.0)
	we.environment = e2
	await get_tree().process_frame
	await get_tree().process_frame
	var c := get_viewport().get_texture().get_image().get_pixel(247, 27)
	print("A: new env + real sky : (%.3f, %.3f, %.3f)" % [c.r, c.g, c.b])
	get_tree().quit(0)