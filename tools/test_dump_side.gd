extends Node

func _ready() -> void:
	print("== dump ==")
	var img := Image.load_from_file("res://tools/out/props_side.png")
	if img == null:
		get_tree().quit(1)
		return
	var w := img.get_width()
	var h := img.get_height()
	# ASCII 60x18: ký tự theo độ lệch so với nền
	var bg := img.get_pixel(3, 3)
	var out := ""
	for gy in range(18):
		var row := ""
		for gx in range(60):
			var x := int(gx * w / 60.0)
			var y := int(gy * h / 18.0)
			var c: Color = img.get_pixel(x, y)
			var dbg: float = absf(c.r - bg.r) + absf(c.g - bg.g) + absf(c.b - bg.b)
			var ch := "."
			if dbg > 0.6: ch = "#"
			elif dbg > 0.35: ch = "o"
			elif dbg > 0.12: ch = "+"
			row += ch
		out += row + "\n"
	print(out)
	print("bg=%s" % bg.to_html())
	get_tree().quit(0)