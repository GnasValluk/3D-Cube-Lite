extends Node

## Print actual pixel RGB at core/edge points across frames (TIME advancing).
## Detect whether sky shader reacts to TIME at all (twinkle) and how wide moon glow is.

func _ready() -> void:
	print("== night_px ==")
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky: Array = SkyLight.build_sky()
	env.sky = sky[0]
	var mat := sky[1] as ShaderMaterial
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var cam := Camera3D.new()
	cam.fov = 70.0
	add_child(cam)
	cam.global_position = Vector3(0, 2, 0)
	cam.look_at_from_position(Vector3(0, 2, 0), Vector3(0, 100, 0), Vector3(0, 0, 1))
	for f in 8:
		SkyLight.update_sky(mat, 23.0, 0.0)
		await get_tree().process_frame
	var img0 := get_viewport().get_texture().get_image()
	var w := img0.get_width()
	var hgt := img0.get_height()
	var pts := {
		"center": Vector2(w / 2, hgt / 2),
		"up1": Vector2(w / 2, hgt * 0.15),
		"up2": Vector2(w / 2, hgt * 0.08),
		"edge": Vector2(w * 0.97, hgt * 0.5),
		"corner": Vector2(w * 0.95, hgt * 0.1),
		"left": Vector2(w * 0.1, hgt * 0.5),
	}
	for f in 8:
		var out: String = "f%d" % f
		var img := get_viewport().get_texture().get_image()
		for k in pts:
			var c: Color = img.get_pixel(int(pts[k].x), int(pts[k].y))
			out += "  %s(%.2f,%.2f,%.2f)" % [k, c.r, c.g, c.b]
		print(out)
		await get_tree().process_frame
	get_tree().quit(0)