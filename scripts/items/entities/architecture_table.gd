class_name ArchitectureTable
extends CraftingStation

## Bàn Kiến Trúc — lô sổ bản đồ, thước thẳng, góc 45°, thước dây, bản mô nhà mini.
func _init() -> void:
	super._init(70, "architecture_table")

func _setup_mesh() -> void:
	var wood      := _m(Color(0.48, 0.34, 0.18), 0.05, 0.82)
	var wood_d    := _m(Color(0.36, 0.24, 0.11), 0.05, 0.90)
	var wood_l    := _m(Color(0.58, 0.42, 0.26), 0.05, 0.78)
	var metal     := _m(Color(0.28, 0.29, 0.33), 0.52, 0.46)
	var metal_hi  := _m(Color(0.50, 0.51, 0.56), 0.70, 0.32)
	var steel     := _m(Color(0.34, 0.35, 0.40), 0.58, 0.44)
	var brass     := _m(Color(0.60, 0.46, 0.20), 0.66, 0.38)
	var parchment := _m(Color(0.92, 0.89, 0.80), 0.10, 0.85)
	var paper     := _m(Color(0.88, 0.84, 0.70), 0.10, 0.88)
	var grid      := _m(Color(0.30, 0.26, 0.20), 0.10, 0.85)
	var ink       := _m(Color(0.12, 0.12, 0.16), 0.40, 0.35)
	var plan_rol  := _m(Color(0.60, 0.36, 0.20), 0.10, 0.82)
	var house_mat := _m(Color(0.66, 0.42, 0.24), 0.18, 0.60)
	var roof      := _m(Color(0.48, 0.28, 0.20), 0.24, 0.65)
	var window    := _m(Color(0.48, 0.56, 0.62), 0.30, 0.25, true)
	var hinge     := _m(Color(0.42, 0.42, 0.48), 0.66, 0.36)

	var tw := 2.10; var td := 1.05; var th := 0.12; var ty := 0.72
	var top_y := ty - th * 0.5

	# ---- Thick 3-plank drafting top ----
	_box(self, Vector3(tw, th, td), Vector3(0, top_y, 0), wood)
	for i in range(3):
		var cx := -0.68 + i * 0.68
		_box(self, Vector3(0.66, th * 0.55, td - 0.08), Vector3(cx, top_y + th * 0.28, 0), wood_l)
	for i in range(2):
		var sx := -0.68 + i * 1.36
		_box(self, Vector3(th * 0.5, th * 0.32, td - 0.08), Vector3(sx, top_y + th * 0.60, 0), metal)
	# drafting surface inset with faint grid
	_box(self, Vector3(tw - 0.08, th * 0.18, td - 0.08), Vector3(0, top_y + th * 0.74, 0), grid)
	for gx in [-0.52, -0.18, 0.16, 0.50]:
		_box(self, Vector3(0.006, 0.002, td - 0.10), Vector3(gx, top_y + th * 0.84, 0), ink)
		_box(self, Vector3(0.006, 0.002, td - 0.10), Vector3(gx, top_y + th * 0.90, 0), ink)

	# ---- Chunky legs + apron ----
	var lt := 0.10; var lh := ty - th
	for x in [-tw * 0.42, tw * 0.42]:
		for z in [-td * 0.42, td * 0.42]:
			_box(self, Vector3(lt, lh, lt), Vector3(x, lh * 0.5, z), wood_d)
			_box(self, Vector3(lt * 1.1, 0.06, lt * 1.1), Vector3(x, 0.03, z), wood_d)
	var arz := td * 0.42 + 0.04
	_box(self, Vector3(tw - 0.3, 0.05, lt * 0.6), Vector3(0, 0.30, -arz), wood_d)
	_box(self, Vector3(tw - 0.3, 0.05, lt * 0.6), Vector3(0, 0.30, arz), wood_d)

	# ---- T-square + triangle (left edge) ----
	var tsq_x := -0.66; var tsq_z := -0.18
	_box(self, Vector3(0.02, 0.016, 0.82), Vector3(tsq_x, top_y + 0.014, 0), steel)
	_box(self, Vector3(0.016, 0.62, 0.02), Vector3(tsq_x, top_y + 0.33, -0.10), steel)
	# triangle ruler 45-45-90
	var ax := -0.52; var az := -0.12
	_box(self, Vector3(0.016, 0.46, 0.016), Vector3(ax, top_y + 0.014, az), brass)
	_box(self, Vector3(0.016, 0.46, 0.016), Vector3(ax, top_y + 0.014, az + 0.28), brass)
	_box(self, Vector3(0.016, 0.46, 0.016), Vector3(ax + 0.28, top_y + 0.014, az), brass)

	# ---- Compass (center-left) ----
	var cx := -0.18; var cz := 0.06
	_box(self, Vector3(0.09, 0.016, 0.09), Vector3(cx, top_y + 0.014, cz), metal_hi)
	_box(self, Vector3(0.018, 0.058, 0.018), Vector3(cx, top_y + 0.044, cz), metal)
	_box(self, Vector3(0.016, 0.016, 0.016), Vector3(cx + 0.042, top_y + 0.024, cz), ink)

	# ---- Rolled plans (center back) ----
	var rx := 0.0; var rz := 0.24
	var roll_w := 0.10
	for k in range(3):
		var col := plan_rol if k == 1 else parchment
		_box(self, Vector3(roll_w, 0.024, 0.036), Vector3(rx + (k - 1) * 0.14, top_y + 0.012, rz), col)
	# ribbon holding plans
	_box(self, Vector3(0.30, 0.010, 0.008), Vector3(rx, top_y + 0.034, rz), ink)

	# ---- Drafting triangle on T-square ----
	_box(self, Vector3(0.012, 0.012, 0.26), Vector3(tsq_x + 0.10, top_y + 0.020, -0.06), brass)

	# ---- Measuring wheel (right front) ----
	var mw := 0.58; var mwz := -0.18
	_box(self, Vector3(0.07, 0.08, 0.07), Vector3(mw, top_y + 0.018, mwz), metal)
	for i in range(6):
		var ang := deg_to_rad(i * 60.0)
		_box(self, Vector3(0.07, 0.028, 0.014), Vector3(mw + sin(ang) * 0.04, top_y + 0.018, mwz + cos(ang) * 0.04), steel)

	# ---- Pencil cup + pencils (right front corner) ----
	var pcx := 0.30; var pcz := 0.16
	_box(self, Vector3(0.07, 0.07, 0.07), Vector3(pcx, top_y + 0.018, pcz), metal_hi)
	var pen_red   := _m(Color(0.90, 0.25, 0.20), 0.40, 0.35)
	var pen_blue  := _m(Color(0.20, 0.40, 0.90), 0.40, 0.35)
	var pencil_cols := [brass, pen_red, pen_blue, paper]
	for i in range(4):
		_box(self, Vector3(0.01, 0.05, 0.012), Vector3(pcx, top_y + 0.05, pcz - 0.018 + i * 0.014), pencil_cols[i])

	# ---- Miniature house model (back-right, centerpiece) ----
	var mx := 0.46; var mz := 0.22
	var mh := 0.16
	# base
	_box(self, Vector3(0.26, 0.04, 0.20), Vector3(mx, top_y + 0.042, mz), house_mat)
	# walls
	_box(self, Vector3(0.26, mh, 0.022), Vector3(mx, top_y + 0.042 + mh * 0.5, mz + 0.089), house_mat)
	_box(self, Vector3(0.022, mh, 0.20), Vector3(mx + 0.119, top_y + 0.042 + mh * 0.5, mz), house_mat)
	_box(self, Vector3(0.022, mh, 0.20), Vector3(mx - 0.119, top_y + 0.042 + mh * 0.5, mz), house_mat)
	# roof (gable)
	_box(self, Vector3(0.28, 0.026, 0.22), Vector3(mx, top_y + mh + 0.05, mz), roof)
	# windows
	_box(self, Vector3(0.048, 0.048, 0.01), Vector3(mx - 0.072, top_y + 0.11, mz + 0.09), window)
	_box(self, Vector3(0.048, 0.048, 0.01), Vector3(mx + 0.072, top_y + 0.11, mz + 0.09), window)

	# ---- Storage ledger box (under table, right) ----
	var ub_y := ty - th - 0.07
	_box(self, Vector3(0.32, 0.08, 0.22), Vector3(0.60, ub_y, 0.0), wood_d)
	_box(self, Vector3(0.33, 0.024, 0.23), Vector3(0.60, ub_y + 0.044, 0.0), metal)
	for k in range(2):
		_box(self, Vector3(0.28, 0.018, 0.014), Vector3(0.60, ub_y + 0.018 + k * 0.022, -0.04), parchment)

	# ---- Collision ----
	var col := CollisionShape3D.new()
	var box_col := BoxShape3D.new()
	box_col.size = Vector3(2.3, 0.80, 1.2)
	col.shape = box_col
	col.position = Vector3(0, 0.40, 0)
	add_child(col)
