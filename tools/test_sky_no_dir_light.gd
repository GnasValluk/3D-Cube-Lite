extends Node

## Smoke test: sky tự vẽ mặt trời/mặt trăng bằng shader (SkyLight.update_sky)
## và thế giới có đúng 2 DirectionalLight3D: "SunLight" (trưa vàng ấm dịu) +
## "MoonLight" (ban đêm trăng sáng thật), KHÔNG còn ambient light nặng.
## Kiểm tra real_world_environment + twilight_environment build sky ShaderMaterial
## với uniforms hợp lệ, và scene có SunLight + MoonLight + ambient fill nhẹ.

var _failures: int = 0

func _check(ok: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		_failures += 1

func _check_moon_cycle(rw: Node) -> void:
	# 0h: trăng lên đỉnh, đêm tối → trăng rọi sáng thế giới.
	rw._update_sun(0.0, 1.0)
	_check(rw._moon != null, "real_world_environment có _moon")
	if rw._moon:
		_check(rw._moon.visible, "0h MoonLight hiển thị (trăng trên cao)")
		_check(rw._moon.light_energy > 0.0, "0h MoonLight rọi sáng (energy %.3f)" % rw._moon.light_energy)
		_check(rw._sun.light_energy <= 0.001, "0h SunLight tắt (%.3f)" % rw._sun.light_energy)
	# 12h: trưa → trăng lặn, tắt hẳn.
	rw._update_sun(12.0, 1.0)
	_check(not rw._moon.visible or rw._moon.light_energy <= 0.0, "trưa MoonLight tắt")
	_check(rw._sun.light_energy > 0.0, "trưa SunLight sáng (%.3f)" % rw._sun.light_energy)

func _ready() -> void:
	print("== test_sky_no_dir_light ==")

	# 1. SkyLight.build_sky trả ShaderMaterial (không phải ProceduralSkyMaterial).
	var sky_data := SkyLight.build_sky()
	var sky: Sky = sky_data[0]
	var mat: ShaderMaterial = sky_data[1]
	_check(sky.sky_material == mat, "Sky.sky_material là ShaderMaterial")
	_check(mat.shader != null, "ShaderMaterial có shader sky.gdshader")

	# 2. update_sky đẩy uniforms — không cần DirectionalLight3D.
	SkyLight.update_sky(mat, 12.0, 0.0)
	_check(mat.get_shader_parameter("sun_dir") is Vector3, "uniform sun_dir là Vector3")
	var sun_dir: Vector3 = mat.get_shader_parameter("sun_dir")
	_check(sun_dir.length() > 0.9, "sun_dir chuẩn hóa")
	var top: Color = mat.get_shader_parameter("sky_top_color")
	_check(top.r > 0.1, "ban ngày sky_top_color sáng (không đen)")
	_check(mat.get_shader_parameter("sun_energy") > 1.0, "trưa sun_energy > 1")
	_check(mat.get_shader_parameter("night_factor") < 0.1, "trưa night_factor ~ 0")

	SkyLight.update_sky(mat, 0.0, 0.0)
	_check(mat.get_shader_parameter("night_factor") > 0.8, "0h night_factor cao")
	var top_night: Color = mat.get_shader_parameter("sky_top_color")
	_check(top_night.r < 0.1, "đêm sky_top_color tối")
	_check(mat.get_shader_parameter("sun_energy") < 0.1, "đêm sun_energy ~ 0")

	# 3. Cả 2 thế giới (open_world mặc định + open_world_real) dùng real_world_environment:
	# SunLight + MoonLight + mây thể tích thật, ambient nhẹ.
	for scene_path in ["res://scenes/open_world.tscn", "res://scenes/open_world_real.tscn"]:
		var inst: Node = load(scene_path).instantiate()
		add_child(inst)
		await get_tree().process_frame
		await get_tree().process_frame
		var label := "default" if scene_path.ends_with("open_world.tscn") else "real"
		var dirs := inst.find_children("*", "DirectionalLight3D", true, false)
		_check(dirs.size() == 2, "%s: SunLight + MoonLight (có %d)" % [label, dirs.size()])
		var sun_found := false
		var moon_found := false
		for d in dirs:
			var dl := d as DirectionalLight3D
			if dl.name == "SunLight":
				sun_found = true
				_check(dl.shadow_enabled, "%s: SunLight bật shadow" % label)
			elif dl.name == "MoonLight":
				moon_found = true
				_check(dl.shadow_enabled, "%s: MoonLight bật shadow" % label)
				_check(dl.light_color.b > dl.light_color.r, "%s: MoonLight ánh sáng mát (trắng xanh)" % label)
		_check(sun_found, "%s: có DirectionalLight3D tên 'SunLight'" % label)
		_check(moon_found, "%s: có DirectionalLight3D tên 'MoonLight'" % label)
		var env := inst.get_node_or_null("WorldEnvironment") as WorldEnvironment
		_check(env != null, "%s: WorldEnvironment tồn tại" % label)
		if env:
			var rw := env as RealWorldEnvironment
			_check(rw._sky_mat != null and rw._sky_mat is ShaderMaterial, "%s: real_world_environment._sky_mat là ShaderMaterial" % label)
			_check(absf(env.environment.ambient_light_energy) <= 0.35, "%s: ambient = fill nhẹ dịu bóng (có %.2f)" % [label, env.environment.ambient_light_energy])
			_check(rw._sun.light_color.g > rw._sun.light_color.b, "%s: trưa SunLight ngả vàng ấm (color %s)" % [label, rw._sun.light_color.to_html()])
			_check_moon_cycle(rw)
		# Mây thể tích thật (VolumetricClouds) + nút bật/tắt ở setting đồ hoạ.
		var clouds_node := inst.get_node_or_null("VolumetricClouds")
		_check(clouds_node != null, "%s: có VolumetricClouds (mây thể tích)" % label)
		if clouds_node:
			var was_on: bool = SettingsManager.clouds_enabled if SettingsManager else true
			if SettingsManager:
				SettingsManager.clouds_enabled = true
			await get_tree().process_frame
			_check(clouds_node.visible, "%s: bật mây → VolumetricClouds hiện" % label)
			if SettingsManager:
				SettingsManager.clouds_enabled = false
			await get_tree().process_frame
			_check(not clouds_node.visible, "%s: tắt mây → ẩn VolumetricClouds" % label)
			if SettingsManager:
				SettingsManager.clouds_enabled = true
			await get_tree().process_frame
			_check(clouds_node.visible, "%s: bật lại mây → VolumetricClouds hiện lại" % label)
			if SettingsManager:
				SettingsManager.clouds_enabled = was_on
		inst.queue_free()
		await get_tree().process_frame

	# 4. Twilight (hub/main) cũng có SunLight + MoonLight + không ambient.
	var tw_script: GDScript = load("res://scripts/world/environment/twilight_environment.gd") as GDScript
	var tw: Node = tw_script.new()
	add_child(tw)
	await get_tree().process_frame
	await get_tree().process_frame
	var tw_sun := tw.get_node_or_null("SunLight") as DirectionalLight3D
	var tw_moon := tw.get_node_or_null("MoonLight") as DirectionalLight3D
	_check(tw_sun != null and tw_sun.shadow_enabled, "twilight có SunLight + shadow")
	_check(tw_moon != null and tw_moon.shadow_enabled, "twilight có MoonLight + shadow")
	_check(absf(tw.environment.ambient_light_energy) <= 0.35, "twilight ambient = fill nhẹ dịu bóng (có %.2f)" % tw.environment.ambient_light_energy)
	_check(tw._sky_mat is ShaderMaterial, "twilight_environment._sky_mat là ShaderMaterial")
	if tw is Node and tw._moon != null:
		_check_moon_cycle(tw)
	tw.queue_free()
	await get_tree().process_frame

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(0 if _failures == 0 else 1)
