extends Node

## Check if we.environment object is REPLACED over time (identity + edit persist).

func _mid() -> Color:
	var img := get_viewport().get_texture().get_image()
	return img.get_pixel(img.get_width() / 2, int(img.get_height() * 0.1))

func _ready() -> void:
	print("== env_identity_over_time ==")
	if TimeSystem:
		TimeSystem.set_hour(12.0)
		TimeSystem.set_time_scale(0.0)
	var scene: PackedScene = load("res://scenes/open_world_real.tscn")
	var inst: Node = scene.instantiate()
	add_child(inst)
	var we := inst.get_node_or_null("WorldEnvironment") as WorldEnvironment
	var seen: Dictionary = {}
	for i in 40:
		await get_tree().process_frame
		var e: Environment = we.environment
		var id := e.get_instance_id()
		if not seen.has(id):
			seen[id] = i
			print("frame %d: env instance=%s (new!) mode=%s sky=%s" % [i, id, e.background_mode, str(e.sky != null)])
		if i in [5, 10, 20, 30, 39]:
			print("frame %d: mode=%s" % [i, we.environment.background_mode])

	# Now edit in place and check persistence after frames
	var env: Environment = we.environment
	var m := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = "shader_type sky; void sky() { COLOR = vec3(1.0, 0.0, 0.0); }"
	m.shader = sh
	env.background_mode = Environment.BG_SKY
	env.sky.sky_material = m
	for i in 8:
		await get_tree().process_frame
		if i in [0, 3, 7]:
			print("after edit frame %d: mode=%s shader_still_red=%s render=%s"
				% [i, we.environment.background_mode, str(we.environment.sky.sky_material.shader.code.contains("1.0, 0.0, 0.0")), _mid()])
	get_tree().quit(0)