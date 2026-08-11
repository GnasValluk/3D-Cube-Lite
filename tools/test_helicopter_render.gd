extends Node3D

## test_helicopter_render — Render trực thăng cứu hộ: entity đầy đủ + mini model
## cầm tay, chụp PNG để verify. Chạy qua tools/test_helicopter_render.tscn.

const _Heli = preload("res://scripts/items/entities/rescue_helicopter.gd")

const SHOTS: Array[Dictionary] = [
	{"y": 1.0,  "pitch": -12.0, "name": "heli_side"},
	{"y": 0.0,  "pitch": -8.0,  "name": "heli_front"},
]

func _make_cam() -> Camera3D:
	var cam := Camera3D.new()
	cam.current = true
	cam.fov = 55.0
	cam.position = Vector3(0, 4.2, 9.5)
	add_child(cam)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.light_energy = 1.4
	add_child(sun)
	var amb := DirectionalLight3D.new()
	amb.rotation_degrees = Vector3(20, -40, 0)
	amb.light_energy = 0.5
	amb.light_color = Color(0.8, 0.85, 1.0)
	add_child(amb)
	var env := Environment.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.9, 0.9, 0.95)
	env.ambient_light_energy = 0.8
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	return cam

func _shot(cam: Camera3D, pitch: float, name: String) -> void:
	cam.rotation_degrees = Vector3(pitch, 0, 0)
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png("res://.godot/test_heli_%s.png" % name)
	var coverage := _coverage(img)
	print("shot %s -> err=%d  coverage=%d%%  (non-bg px=%d)" % [name, err, coverage, _non_bg(img)])

func _non_bg(img: Image) -> int:
	var n := 0
	for x in range(0, img.get_width(), 4):
		for y in range(0, img.get_height(), 4):
			var c := img.get_pixel(x, y)
			if c.a > 0.05 and (c.r + c.g + c.b) / 3.0 < 0.90:
				n += 1
	return n

func _coverage(img: Image) -> int:
	var total := 0
	var n := 0
	for x in range(0, img.get_width(), 4):
		for y in range(0, img.get_height(), 4):
			total += 1
			var c := img.get_pixel(x, y)
			if c.a > 0.05 and (c.r + c.g + c.b) / 3.0 < 0.90:
				n += 1
	return int(float(n) / float(maxi(total, 1)) * 100.0)

## Đếm pixel có màu đỏ/trắng của trực thăng (phân biệt với nền xám đơn sắc).
func _model_px(img: Image) -> int:
	var red := 0
	var white := 0
	for x in range(0, img.get_width(), 3):
		for y in range(0, img.get_height(), 3):
			var c := img.get_pixel(x, y)
			if c.r > 0.55 and c.g < 0.30 and c.b < 0.30 and c.r > c.g * 2.0:
				red += 1
			elif c.r > 0.80 and c.g > 0.75 and c.b > 0.70:
				white += 1
	return red + white

func _ready() -> void:
	print("== test_helicopter_render ==")
	var heli: Node = _Heli.new()
	heli.name = "RenderHeli"
	add_child(heli)
	heli.global_position = Vector3(0, 1.2, 0)
	heli.rotation.y = 0.0
	await get_tree().process_frame
	await get_tree().process_frame

	var cam := _make_cam()
	for s in SHOTS:
		await get_tree().process_frame
		_shot(cam, s["pitch"], s["name"])
		await get_tree().process_frame

	var mini := Node3D.new()
	ItemMesh.build(mini, "rescue_helicopter")
	mini.position = Vector3(0, 0.5, 0)
	add_child(mini)
	cam.position = Vector3(0, 2.6, 4.0)
	await get_tree().process_frame
	_shot(cam, -12.0, "heli_mini")

	var fail: int = 0
	for s in SHOTS:
		var img := Image.load_from_file("res://.godot/test_heli_%s.png" % s["name"])
		var cvg := _coverage(img)
		var mp := _model_px(img)
		print("verify %s coverage=%d%% model_px=%d" % [s["name"], cvg, mp])
		if mp < 100:
			fail += 1
	print("RENDER | %s" % ["PASS" if fail == 0 else "FAIL"])
	get_tree().quit(0 if fail == 0 else 1)
