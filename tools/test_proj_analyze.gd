extends Node

const COL_NONE := Color(0, 0, 0, 0)
var _bg := COL_NONE

func _ready() -> void:
	print("== proj_analyze ==")
	var img := Image.load_from_file("res://tools/out/props_side.png")
	if img == null:
		print("load fail")
		get_tree().quit(1)
		return
	var w := img.get_width()
	var h := img.get_height()
	_bg = img.get_pixel(3, 3)
	print("img %dx%d bg=%s" % [w, h, _bg.to_html()])

	var thr := 0.22
	var cols_used: Array[bool] = []
	cols_used.resize(w)
	cols_used.fill(false)
	for x in range(w):
		var cnt := 0
		for y in range(h):
			if dbg2(img.get_pixel(x, y)) > thr:
				cnt += 1
		if cnt > 15:
			cols_used[x] = true
	var clusters: Array[Dictionary] = []
	var xi := 0
	while xi < w:
		if not cols_used[xi]:
			xi += 1
			continue
		var x0 := xi
		while xi < w and cols_used[xi]:
			xi += 1
		clusters.append({"start": x0, "end": xi - 1})
	print("clusters:", clusters)
	if clusters.is_empty():
		get_tree().quit(0)
		return
	for cl in clusters:
		var x0: int = cl["start"]
		var x1: int = cl["end"]
		var y_top := h
		var y_bot := 0
		for y in range(h):
			for xx in range(x0, x1 + 1):
				if dbg2(img.get_pixel(xx, y)) > thr:
					y_top = mini(y_top, y)
					y_bot = maxi(y_bot, y)
		var n := 0
		var bg_like := 0
		var belly_rows := 0
		var belly_sum_cov := 0.0
		var belly_min_cov := 1.0
		var worst_gap_run := 0
		for y in range(y_top, y_bot + 1):
			var row_tree := 0
			var row_w := 0
			var run := 0
			var best_run := 0
			var saw_tree := false
			for xx in range(x0, x1 + 1):
				row_w += 1
				if dbg2(img.get_pixel(xx, y)) > thr:
					row_tree += 1
					saw_tree = true
					run = 0
				else:
					if saw_tree:
						run += 1
					best_run = maxi(best_run, run)
			n += row_tree
			bg_like += row_w - row_tree
			var cov := float(row_tree) / maxf(row_w, 1.0)
			if cov >= 0.40:
				belly_rows += 1
				belly_sum_cov += cov
				belly_min_cov = minf(belly_min_cov, cov)
				worst_gap_run = maxi(worst_gap_run, best_run)
		var total := (y_bot - y_top + 1) * (x1 - x0 + 1)
		var belly_avg := belly_sum_cov / maxf(belly_rows, 1.0)
		print("col %d..%d belly?%d avgcov=%.2f mincov=%.2f worstbgap=%d gap=%.2f" % [x0, x1, belly_rows, belly_avg, belly_min_cov, worst_gap_run, float(bg_like) / maxf(total, 1)])
	get_tree().quit(0)

func dbg2(c: Color) -> float:
	return absf(c.r - _bg.r) + absf(c.g - _bg.g) + absf(c.b - _bg.b)