extends Node

## Decode out_sky_capture.png from raw bytes (file not imported in project).

func _ready() -> void:
	print("== png_decode ==")
	var f := FileAccess.open("res://out_sky_capture.png", FileAccess.READ)
	if f == null:
		print("ERROR: mo file that bai")
		get_tree().quit(1)
		return
	var bytes := f.get_buffer(f.get_length())
	var img := Image.new()
	var err := img.load_png_from_buffer(bytes)
	if err != OK:
		print("ERROR: load_png_from_buffer = %d" % err)
		get_tree().quit(1)
		return
	var w := img.get_width()
	var h := img.get_height()
	print("size %dx%d" % [w, h])
	for i in 8:
		var y := int(h * (0.06 + 0.11 * i))
		var c := img.get_pixel(w / 2, y)
		print("  y=%3d%% rgb=(%.3f %.3f %.3f)" % [int(100 * y / h), c.r, c.g, c.b])
	get_tree().quit(0)