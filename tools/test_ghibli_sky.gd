extends Node

## Render bầu trời Ghibli voxel mới ở các giờ khác nhau + vài góc nhìn.

var _cam: Camera3D

func _ready() -> void:
	print("== ghibli_sky ==")
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky: Array = SkyLight.build_sky()
	env.sky = sky[0]
	var mat := sky[1] as ShaderMaterial
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	_cam = Camera3D.new()
	_cam.fov = 70.0
	_cam.current = true
	add_child(_cam)

	DirAccess.make_dir_recursive_absolute("res://tools/out")

	for slot in [["noon", 12.0, -5.0], ["dusk", 18.5, 0.0], ["night", 0.0, -15.0], ["dawn", 6.2, 8.0]]:
		var name: String = slot[0]
		var hour: float = slot[1]
		var yaw: float = slot[2]
		for f in 6:
			SkyLight.update_sky(mat, hour, 0.0, 14.8)
			await get_tree().process_frame
		_cam.global_rotation = Vector3(deg_to_rad(-20.0), deg_to_rad(yaw), 0)
		for f in 3:
			await get_tree().process_frame
		await _shot("ghibli_" + name)

	# Trưa nhìn lên để thấy mây overhead
	for f in 6:
		SkyLight.update_sky(mat, 14.0, 0.0, 14.8)
		await get_tree().process_frame
	_cam.global_rotation = Vector3(deg_to_rad(-70.0), deg_to_rad(20.0), 0)
	for f in 3:
		await get_tree().process_frame
	await _shot("ghibli_overhead")

	# Mưa nhẹ ngày
	for f in 6:
		SkyLight.update_sky(mat, 13.0, 0.5, 14.8)
		await get_tree().process_frame
	_cam.global_rotation = Vector3(deg_to_rad(-20.0), deg_to_rad(0.0), 0)
	for f in 3:
		await get_tree().process_frame
	await _shot("ghibli_rain")

	print("TOTAL done")
	get_tree().quit(0)

func _shot(name: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://tools/out/%s.png" % name)
	print("saved res://tools/out/%s.png" % name)
