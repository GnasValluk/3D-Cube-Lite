extends Node

## Smoke test: sky tự vẽ mặt trời bằng shader (SkyLight.update_sky) và thế giới
## có đúng 1 DirectionalLight3D "SunLight" (bóng đổ), KHÔNG còn ambient light.
## Kiểm tra real_world_environment + twilight_environment build sky ShaderMaterial
## với uniforms hợp lệ, và scene có SunLight + ambient_light_energy = 0.

var _failures: int = 0

func _check(ok: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if ok else "FAIL", label])
	if not ok:
		_failures += 1

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

	# 3. Scene real có đúng 1 DirectionalLight3D "SunLight" + không ambient.
	var scene := load("res://scenes/open_world_real.tscn")
	var inst: Node = scene.instantiate()
	add_child(inst)
	await get_tree().process_frame
	await get_tree().process_frame
	var dirs := inst.find_children("*", "DirectionalLight3D", true, false)
	_check(dirs.size() == 1, "open_world_real có đúng 1 DirectionalLight3D (có %d)" % dirs.size())
	if dirs.size() == 1:
		var sun := dirs[0] as DirectionalLight3D
		_check(sun.name == "SunLight", "DirectionalLight3D tên 'SunLight' (có '%s')" % sun.name)
		_check(sun.shadow_enabled, "SunLight bật shadow")
	var env := inst.get_node_or_null("WorldEnvironment") as WorldEnvironment
	_check(env != null, "WorldEnvironment tồn tại")
	if env:
		var rw := env as RealWorldEnvironment
		_check(rw._sky_mat != null and rw._sky_mat is ShaderMaterial, "real_world_environment._sky_mat là ShaderMaterial")
		_check(absf(env.environment.ambient_light_energy) < 0.001, "ambient_light_energy = 0 (có %g)" % env.environment.ambient_light_energy)
	inst.queue_free()
	await get_tree().process_frame

	# 4. Twilight (hub/main) cũng có SunLight + không ambient.
	var tw_script: GDScript = load("res://scripts/world/environment/twilight_environment.gd") as GDScript
	var tw: Node = tw_script.new()
	add_child(tw)
	await get_tree().process_frame
	await get_tree().process_frame
	var tw_sun := tw.get_node_or_null("SunLight") as DirectionalLight3D
	_check(tw_sun != null and tw_sun.shadow_enabled, "twilight có SunLight + shadow")
	_check(absf(tw.environment.ambient_light_energy) < 0.001, "twilight ambient_light_energy = 0")
	_check(tw._sky_mat is ShaderMaterial, "twilight_environment._sky_mat là ShaderMaterial")
	tw.queue_free()
	await get_tree().process_frame

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	get_tree().quit(0 if _failures == 0 else 1)
