extends Node

## Sample sky pixels from captured PNG — print RGB at several screen positions.

func _ready() -> void:
	print("== sky_pixel_check ==")
	var img := load("res://out_sky_capture.png") as Image
	if img == null:
		print("ERROR: khong load duoc png")
		get_tree().quit(1)
		return
	var w := img.get_width()
	var h := img.get_height()
	print("size %dx%d" % [w, h])
	for i in 5:
		var y := int(h * (0.15 + 0.18 * i))
		var c := img.get_pixel(w / 2, y)
		print("y=%.2f  rgb=(%.2f, %.2f, %.2f)" % [float(y) / float(h), c.r, c.g, c.b])
	get_tree().quit(0)