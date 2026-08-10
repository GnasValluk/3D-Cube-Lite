extends Node

## Take the REAL world env, reassign the SAME env object but with a fresh Sky
## (build_sky + noon uniforms). Then toggle settings one at a time.

func _mid() -> Color:
	var img := get_viewport().get_texture().get_image()
	return img.get_pixel(img.get_width() / 2, int(img.get_height() * 0.1))

func _ready() -> void:
	print("== real_settings_bisect ==")
	if TimeSystem:
		TimeSystem.set_hour(12.0)
		TimeSystem.set_time_scale(0.0)
	var scene: PackedScene = load("res://scenes/open_world_real.tscn")
	var inst: Node = scene.instantiate()
	add_child(inst)
	for i in 20:
		await get_tree().process_frame
	var we := inst.get_node_or_null("WorldEnvironment") as WorldEnvironment
	var real: Environment = we.environment
	print("real env tonemap=%d fog=%s adj=%s glow=%s amb_en=%s"
		% [real.tonemap_mode, str(real.fog_enabled), str(real.adjustment_enabled), str(real.glow_enabled), str(real.ambient_light_energy)])
	print("buf real env = %s" % str(_mid()))

	# A) fresh env copying real settings but Sky rebuilt with build_sky
	var a := Environment.new()
	a.background_mode = Environment.BG_SKY
	a.sky = SkyLight.build_sky()[0]
	SkyLight.update_sky(a.sky.sky_material as ShaderMaterial, 12.0, 0.0)
	a.tonemap_mode = real.tonemap_mode
	a.tonemap_exposure = real.tonemap_exposure
	a.tonemap_white = real.tonemap_white
	a.adjustment_enabled = real.adjustment_enabled
	a.adjustment_brightness = real.adjustment_brightness
	a.adjustment_contrast = real.adjustment_contrast
	a.adjustment_saturation = real.adjustment_saturation
	a.glow_enabled = real.glow_enabled
	a.fog_enabled = real.fog_enabled
	a.fog_density = real.fog_density
	a.fog_height_density = real.fog_height_density
	a.ambient_light_source = real.ambient_light_source
	a.ambient_light_color = real.ambient_light_color
	a.ambient_light_energy = real.ambient_light_energy
	we.environment = a
	for i in 6:
		await get_tree().process_frame
	print("A) fresh env = real settings + build_sky = %s" % str(_mid()))

	# B) strip fog
	a.fog_enabled = false
	for i in 4:
		await get_tree().process_frame
	print("B) fog off = %s" % str(_mid()))

	# C) strip tonemap -> LINEAR
	a.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	for i in 4:
		await get_tree().process_frame
	print("C) tonemap linear = %s" % str(_mid()))

	# D) strip adjustment
	a.adjustment_enabled = false
	for i in 4:
		await get_tree().process_frame
	print("D) adj off = %s" % str(_mid()))

	# E) strip glow + ambient
	a.glow_enabled = false
	a.ambient_light_energy = 0.0
	for i in 4:
		await get_tree().process_frame
	print("E) glow+amb off = %s" % str(_mid()))
	get_tree().quit(0)