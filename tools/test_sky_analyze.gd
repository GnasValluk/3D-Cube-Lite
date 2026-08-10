extends Node

## Numeric analysis of saved night-sky PNGs: count star pixels by brightness
## threshold, cluster into blobs (size in pixels), check temporal variation.

func _ready() -> void:
	print("== sky_analyze ==")
	var path := "res://tools/out/sky_1.png"
	var prev_path := "res://tools/out/sky_2.png"
	var img := Image.load_from_file(path)
	var prev := Image.load_from_file(prev_path)
	if img == null or prev == null:
		print("load failed")
		get_tree().quit(1)
		return
	var w := img.get_width()
	var h := img.get_height()
	print("size %dx%d" % [w, h])
	# classify: how many pixels exceed star-brightness thresholds outside moon blob
	var thresh: Array = [0.15, 0.30, 0.50, 0.80]
	for t in thresh:
		var cnt := 0
		for y in h:
			for x in w:
				var c: Color = img.get_pixel(x, y)
				var b := maxf(c.r, maxf(c.g, c.b))
				if b > float(t):
					cnt += 1
		print("bright>%.2f : %d px" % [t, cnt])
	# find brightest pixel + its coords, and count blobs of star size (1-3px)
	var maxb := 0.0
	var maxp := Vector2i.ZERO
	for y in h:
		for x in w:
			var c: Color = img.get_pixel(x, y)
			var b := maxf(c.r, maxf(c.g, c.b))
			if b > maxb:
				maxb = b
				maxp = Vector2i(x, y)
	print("maxbright %.3f @ %d,%d" % [maxb, maxp.x, maxp.y])
	# variance: count pixels whose brightness differs from prev frame >0.05
	var diffcnt := 0
	var diffmax := 0.0
	for y in h:
		for x in w:
			var a: Color = img.get_pixel(x, y)
			var b: Color = prev.get_pixel(x, y)
			var d: float = absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)
			if d > 0.05:
				diffcnt += 1
				diffmax = maxf(diffmax, d)
	print("pixels differing from prev frame >0.05: %d (max delta %.3f)" % [diffcnt, diffmax])
	get_tree().quit(0)