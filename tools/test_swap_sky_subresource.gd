extends Node

## In full scene, replace we.environment.sky with a NEW Sky+green material (same env object).
## If green renders -> env object active, sky swap works. If still gray -> active env differs.

func _mid() -> Color:
	var img := get_viewport().get_texture().get_image()
	return img.get_pixel(img.get_width() / 2, int(img.get_height() * 0.1))

func _ready() -> void:
	print("== swap_sky_subresource ==")
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
	print("env instance=%s mode=%s" % [env.get_instance_id(), env.background_mode])
	print("buf A (noon, unchanged) = %s" % str(_mid()))

	var m := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = "shader_type sky; void sky() { COLOR = vec3(0.0, 1.0, 0.0); }"
	m.shader = sh
	var sky := Sky.new()
	sky.sky_material = m
	sky.process_mode = Sky.PROCESS_MODE_REALTIME
	env.sky = sky
	for i in 6:
		await get_tree().process_frame
	print("after env.sky=new green sky = %s (expect green)" % str(_mid()))
	print("env.sky is still same env? %s mode=%s" % [str(we.environment.sky == sky), we.environment.background_mode])
	get_tree().quit(0)