extends Node

## Đo bán kính đĩa mặt trời/trăng: đọc sun_dir/moon_dir từ shader,
## xoay camera nhìn thẳng vào đó rồi đếm pixel sáng xung quanh tâm.

func _ready() -> void:
	print("== measure2 ==")
	var env_script: GDScript = load("res://scripts/world/environment/real_world_environment.gd")
	var we: WorldEnvironment = env_script.new() as WorldEnvironment
	add_child(we)
	we.set_process(false)
	var cam := Camera3D.new()
	cam.current = true
	cam.fov = 60.0
	add_child(cam)
	for i in 4:
		await get_tree().process_frame
	var rw := we as RealWorldEnvironment
	var mat: ShaderMaterial = rw._sky_mat

	SkyLight.update_sky(mat, 12.0, 0.0, 14.8)
	await _measure(cam, mat, "sun_noon", "sun_dir")
	SkyLight.update_sky(mat, 17.0, 0.0, 14.8)
	await _measure(cam, mat, "sun_dusk", "sun_dir")
	SkyLight.update_sky(mat, 22.0, 0.0, 14.8)
	await _measure(cam, mat, "moon_night", "moon_dir")
	SkyLight.update_sky(mat, 0.0, 0.0, 14.8)
	await _measure(cam, mat, "moon_midnight", "moon_dir")
	# dayf=0 (ngày 0 game) lúc 22h — đêm PHẢI vẫn thấy trăng.
	SkyLight.update_sky(mat, 22.0, 0.0, 0.0)
	await _measure(cam, mat, "moon_day0_night", "moon_dir")

	print("TOTAL done")
	get_tree().quit(0)

func _measure(cam: Camera3D, mat: ShaderMaterial, name: String, key: String) -> void:
	var dir: Vector3 = mat.get_shader_parameter(key).normalized()
	cam.global_position = -dir * 10.0
	var up := Vector3.UP if abs(dir.y) < 0.9 else Vector3.FORWARD
	cam.look_at(Vector3.ZERO, up)
	for i in 3:
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	var w := img.get_width()
	var h := img.get_height()
	var cx := w / 2
	var cy := h / 2
	var count := 0
	var total := 0.0
	for x in range(cx - 150, cx + 151):
		for y in range(cy - 150, cy + 151):
			var c := img.get_pixel(x, y)
			var lum := c.r + c.g + c.b
			total += lum
			if lum > 1.9:
				count += 1
	var radius := sqrt(float(count) / PI)
	print("%s: dir=%s bright_px=%d approx_radius=%.1fpx meanLum=%.3f" % [name, dir, count, radius, total / (301.0 * 301.0)])
