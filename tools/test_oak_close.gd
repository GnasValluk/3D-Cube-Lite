extends Node

## Soi chi tiết 1 cây sồi: camera sát tán, dump ASCII nhiều dòng để xác nhận
## các cube LEAF_SCALE (0.20) chạm khít trên lưới 0.1875 — không còn vệt nền
## lọt giữa các voxel như bản 0.0625 cũ.

const _Oak = preload("res://scripts/world/props/oak_prop.gd")

var _cam: Camera3D

func _ready() -> void:
	print("== oak_close ==")
	_cam = Camera3D.new()
	_cam.fov = 45.0
	_cam.current = true
	add_child(_cam)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-60, -30, 0)
	add_child(light)
	var ws := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.40, 0.42, 0.48)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.6
	ws.environment = env
	add_child(ws)

	var tree: Node = _Oak.new()
	tree.setup("plains")
	add_child(tree)
	tree.set_birth_age_days(999.0)
	for c in tree.find_children("*", "MultiMeshInstance3D", true, false):
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		c.material_override = mat

	await get_tree().process_frame
	await get_tree().process_frame
	# nhìn ngang sát thân ở độ cao giữa tán
	_cam.position = Vector3(-1.2, 4.0, 0.001)
	_cam.look_at(Vector3(0, 4.0, 0), Vector3.UP)
	await get_tree().process_frame
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://tools/out/oak_close.png")
	# dump ASCII chi tiết
	var w := img.get_width()
	var h := img.get_height()
	var bg := img.get_pixel(1, 1)
	var out := ""
	for gy in range(34):
		var row := ""
		for gx in range(90):
			var x := int(gx * w / 90.0)
			var y := int(gy * h / 34.0)
			var c: Color = img.get_pixel(x, y)
			var dbg: float = absf(c.r - bg.r) + absf(c.g - bg.g) + absf(c.b - bg.b)
			var ch := "."
			if dbg > 0.6: ch = "#"
			elif dbg > 0.35: ch = "o"
			elif dbg > 0.14: ch = "+"
			row += ch
		out += row + "\n"
	print(out)
	get_tree().quit(0)