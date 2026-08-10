extends Node

## Suspect set: fog_height + fog_light_color. Start from the KNOWN-blue bisect env
## (fresh = real settings subset) and add these two, then toggle each on/off.

func _mid() -> Color:
	var img := get_viewport().get_texture().get_image()
	return img.get_pixel(img.get_width() / 2, int(img.get_height() * 0.1))

func _ready() -> void:
	print("== fog_suspect ==")
	if TimeSystem:
		TimeSystem.set_hour(12.0)
		TimeSystem.set_time_scale(0.0)
	var scene: PackedScene = load("res://scenes/open_world_real.tscn")
	var inst: Node = scene.instantiate()
	add_child(inst)
	for i in 25:
		await get_tree().process_frame
	var we := inst.get_node_or_null("WorldEnvironment") as WorldEnvironment
	var real: Environment = we.environment

	# Reproduce the known-BLUE env (bisect A) on a fresh Environment
	var a := Environment.new()
	a.background_mode = Environment.BG_SKY
	a.sky = SkyLight.build_sky()[0]
	SkyLight.update_sky(a.sky.sky_material as ShaderMaterial, 12.0, 0.0)
	a.tonemap_mode = real.tonemap_mode
	a.tonemap_exposure = real.tonemap_exposure
	a.tonemap_white = real.tonemap_white
	a.adjustment_enabled = real.adjustment_enabled
	a.glow_enabled = real.glow_enabled
	a.ambient_light_source = real.ambient_light_source
	a.ambient_light_color = real.ambient_light_color
	a.ambient_light_energy = real.ambient_light_energy
	we.environment = a
	for i in 5:
		await get_tree().process_frame
	print("0) baseline(no fog)     = %s" % str(_mid()))

	a.fog_enabled = true
	a.fog_density = 0.0
	for i in 5:
		await get_tree().process_frame
	print("1) fog enabled d=0      = %s" % str(_mid()))

	a.fog_height = 2.0
	a.fog_height_density = 0.0
	for i in 5:
		await get_tree().process_frame
	print("2) + fog_height 2.0     = %s" % str(_mid()))

	a.fog_light_color = Color(0.4, 0.42, 0.48)
	a.fog_sun_scatter = 0.0
	a.fog_aerial_perspective = 0.0
	for i in 5:
		await get_tree().process_frame
	print("3) + fog_light_color    = %s" % str(_mid()))

	a.fog_enabled = false
	for i in 5:
		await get_tree().process_frame
	print("4) fog enabled OFF      = %s" % str(_mid()))
	get_tree().quit(0)