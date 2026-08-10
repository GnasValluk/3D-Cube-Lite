extends Node

## Decisive: does duplicating the REAL ready-built Environment and re-assigning
## it via we.environment fix the render? Original frozen, duplicate fresh?

func _ready() -> void:
	print("== dup_env ==")
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
	print("real env instance: %s" % real.get_instance_id())
	print("we.environment == real: %s" % (we.environment == real))

	var d := we.environment.duplicate(true) as Environment
	print("duplicate instance: %s  background=%s sky=%s" % [
		d.get_instance_id(), d.background_mode, (d.sky != null)])
	# refresh uniforms on the duplicate's sky material
	if d.sky and d.sky.sky_material:
		SkyLight.update_sky(d.sky.sky_material as ShaderMaterial, 12.0, 0.0)
	we.environment = d
	for i in 10:
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	var c := img.get_pixel(img.get_width() / 2, int(img.get_height() * 0.1))
	print("after duplicate assign center-top: (%.3f, %.3f, %.3f)" % [c.r, c.g, c.b])
	get_tree().quit(0)