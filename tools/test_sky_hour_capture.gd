extends Node

## Render sky on D3D12 at several hours, sample viewport pixels in-memory.
## No DirectionalLight3D needed — validates the custom shader sky produces
## distinct day/night/dawn colors.

func _sample_pixels() -> Array:
	var img := get_viewport().get_texture().get_image()
	var w := img.get_width()
	var h := img.get_height()
	var out: Array = []
	for i in 6:
		var y := int(h * (0.1 + 0.14 * i))
		var c := img.get_pixel(w / 2, y)
		out.append([round(c.r * 255.0) / 255.0, round(c.g * 255.0) / 255.0, round(c.b * 255.0) / 255.0])
	return out

func _ready() -> void:
	print("== sky_hour_capture ==")
	var env_script: GDScript = load("res://scripts/world/environment/real_world_environment.gd")
	var we: WorldEnvironment = env_script.new() as WorldEnvironment
	add_child(we)
	we.set_process(false)
	var cam := Camera3D.new()
	cam.current = true
	add_child(cam)
	cam.global_position = Vector3(0, 6, 8)
	cam.look_at(Vector3(0, 0, 0))
	await get_tree().process_frame
	await get_tree().process_frame
	var rw := we as RealWorldEnvironment
	for hour in [6.0, 8.0, 10.0, 12.0, 15.0, 16.5, 17.5, 18.5, 21.0, 0.0]:
		# giả lập giờ bằng cách tự push uniform trực tiếp lên sky material
		var mat: ShaderMaterial = rw._sky_mat
		SkyLight.update_sky(mat, hour, 0.0, 7.0)
		await get_tree().process_frame
		await get_tree().process_frame
		var top: Color = mat.get_shader_parameter("sky_top_color")
		var hor: Color = mat.get_shader_parameter("sky_horizon_color")
		var sun: Color = mat.get_shader_parameter("sun_color")
		var phase: float = mat.get_shader_parameter("moon_phase")
		var ecl: float = mat.get_shader_parameter("moon_eclipse")
		print("hour %5.1f topR=%.2f topB=%.2f horR=%.2f sunR=%.2f sunG=%.2f moon_phase=%.2f ecl=%.2f" % [hour, top.r, top.b, hor.r, sun.r, sun.g, phase, ecl])
	get_tree().quit(0)