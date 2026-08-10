extends Node

## Decisive: in full scene, force sky uniforms to extreme colors and check render.
## If sky still renders gray/pink -> sky not being drawn at all.

func _sample_up() -> Color:
	var img := get_viewport().get_texture().get_image()
	return img.get_pixel(img.get_width() / 2, int(img.get_height() * 0.15))

func _ready() -> void:
	print("== force_sky_extreme ==")
	if TimeSystem:
		TimeSystem.set_hour(12.0)
		TimeSystem.set_time_scale(0.0)
	var scene: PackedScene = load("res://scenes/open_world_real.tscn")
	var inst: Node = scene.instantiate()
	add_child(inst)
	for i in 20:
		await get_tree().process_frame
	var env := inst.get_node_or_null("WorldEnvironment") as WorldEnvironment
	var mat: ShaderMaterial = (env as RealWorldEnvironment)._sky_mat
	var cam := Camera3D.new()
	cam.current = true
	cam.rotation_degrees = Vector3(90, 0, 0)
	cam.global_position = Vector3(0, 3, 0)
	add_child(cam)
	for i in 4:
		await get_tree().process_frame
	print("baseline up = %s" % str(_sample_up()))

	# Force pure colors
	mat.set_shader_parameter("sky_top_color", Color(1, 0, 0))
	mat.set_shader_parameter("sky_horizon_color", Color(0, 1, 0))
	mat.set_shader_parameter("ground_bottom_color", Color(1, 0, 1))
	mat.set_shader_parameter("ground_horizon_color", Color(1, 0, 1))
	mat.set_shader_parameter("sky_energy", 1.0)
	mat.set_shader_parameter("sun_energy", 0.0)
	mat.set_shader_parameter("moon_energy", 0.0)
	mat.set_shader_parameter("night_factor", 0.0)
	mat.set_shader_parameter("weather", 0.0)
	for i in 4:
		await get_tree().process_frame
	print("after force top should be red = %s" % str(_sample_up()))
	get_tree().quit(0)