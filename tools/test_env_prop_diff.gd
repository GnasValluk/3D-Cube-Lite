extends Node

## Full property diff: real ready-built Environment vs fresh copy w/ build_sky sky.

func _ready() -> void:
	print("== env_prop_diff ==")
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
	var fresh := Environment.new()
	fresh.background_mode = Environment.BG_SKY
	fresh.sky = SkyLight.build_sky()[0]
	SkyLight.update_sky(fresh.sky.sky_material as ShaderMaterial, 12.0, 0.0)

	var props := [
		"background_mode", "background_color", "background_energy_multiplier",
		"ambient_light_source", "ambient_light_color", "ambient_light_energy",
		"fog_enabled", "fog_density", "fog_height", "fog_height_density", "fog_light_color", "fog_sun_scatter",
		"tonemap_mode", "tonemap_exposure", "tonemap_white",
		"adjustment_enabled", "adjustment_brightness", "adjustment_contrast", "adjustment_saturation",
		"glow_enabled", "glow_intensity", "glow_strength", "glow_hdr_threshold", "glow_hdr_scale",
		"ssao_enabled", "volumetric_fog_enabled",
	]
	for p in props:
		var rv: Variant = real.get(p)
		var fv: Variant = fresh.get(p)
		if str(rv) != str(fv):
			print("DIFF %-28s real=%s  fresh=%s" % [p, str(rv), str(fv)])
	print("(no DIFF lines above => identical)")
	get_tree().quit(0)