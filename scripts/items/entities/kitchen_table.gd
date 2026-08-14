class_name KitchenTable
extends CraftingStation

## Bàn Làm Bếp — mặt đá, thớt, dao, nồi, chảo, đĩa, nguyên liệu nấu ăn.
func _init() -> void:
	super._init(60, "kitchen_table")

func _setup_mesh() -> void:
	var wood      := _m(Color(0.56, 0.38, 0.20), 0.05, 0.80)
	var wood_d    := _m(Color(0.42, 0.27, 0.14), 0.05, 0.88)
	var wood_l    := _m(Color(0.62, 0.44, 0.26), 0.05, 0.76)
	var stone     := _m(Color(0.58, 0.57, 0.55), 0.20, 0.55)
	var stone_line:= _m(Color(0.46, 0.45, 0.43), 0.20, 0.55)
	var iron      := _m(Color(0.30, 0.30, 0.34), 0.50, 0.45)
	var iron_hi   := _m(Color(0.48, 0.49, 0.54), 0.68, 0.34)
	var copper    := _m(Color(0.68, 0.44, 0.24), 0.65, 0.34)
	var cutting   := _m(Color(0.64, 0.46, 0.26), 0.05, 0.74)
	var plate     := _m(Color(0.90, 0.90, 0.90), 0.18, 0.40)
	var plate_in  := _m(Color(0.94, 0.94, 0.96), 0.18, 0.36)
	var bowl      := _m(Color(0.68, 0.66, 0.62), 0.26, 0.40)
	var tomato    := _m(Color(0.74, 0.24, 0.20), 0.05, 0.78, true)
	var onion     := _m(Color(0.70, 0.42, 0.24), 0.05, 0.80)
	var leaf      := _m(Color(0.20, 0.50, 0.22), 0.05, 0.80, true)
	var flour     := _m(Color(0.92, 0.88, 0.80), 0.05, 0.90)
	var sack      := _m(Color(0.64, 0.54, 0.40), 0.05, 0.88)
	var herb      := _m(Color(0.50, 0.38, 0.18), 0.05, 0.82)

	var tw := 2.00; var td := 1.00; var th := 0.12; var ty := 0.70
	var top_y := ty - th * 0.5

	# ---- Thick wooden top with stone inlay ----
	_box(self, Vector3(tw, th, td), Vector3(0, top_y, 0), wood)
	_box(self, Vector3(tw - 0.04, th * 0.55, td - 0.04), Vector3(0, top_y + th * 0.30, 0), stone)
	# stone seam lines
	_box(self, Vector3(th * 0.38, th * 0.20, td - 0.06), Vector3(-0.42, top_y + th * 0.48, 0), stone_line)
	_box(self, Vector3(th * 0.38, th * 0.20, td - 0.06), Vector3(0.42, top_y + th * 0.48, 0), stone_line)

	# ---- Chunky legs + apron ----
	var lt := 0.10; var lh := ty - th
	for x in [-tw * 0.42, tw * 0.42]:
		for z in [-td * 0.42, td * 0.42]:
			_box(self, Vector3(lt, lh, lt), Vector3(x, lh * 0.5, z), wood_d)
			_box(self, Vector3(lt * 1.1, 0.06, lt * 1.1), Vector3(x, 0.03, z), wood_d)
	var arz := td * 0.42 + 0.04
	_box(self, Vector3(tw - 0.3, 0.05, lt * 0.6), Vector3(0, 0.30, -arz), wood_d)
	_box(self, Vector3(tw - 0.3, 0.05, lt * 0.6), Vector3(0, 0.30, arz), wood_d)
	_box(self, Vector3(lt * 0.6, 0.05, td - 0.3), Vector3(-tw * 0.42 - 0.03, 0.30, 0), wood_d)
	_box(self, Vector3(lt * 0.6, 0.05, td - 0.3), Vector3(tw * 0.42 + 0.03, 0.30, 0), wood_d)

	# ---- Cutting board + knife (left front) ----
	var cxb := -0.60; var czb := -0.02
	_box(self, Vector3(0.26, 0.034, 0.19), Vector3(cxb, top_y + 0.012, czb), cutting)
	_box(self, Vector3(0.028, 0.026, 0.10), Vector3(cxb + 0.11, top_y + 0.014, czb + 0.036), iron)
	_box(self, Vector3(0.022, 0.036, 0.022), Vector3(cxb + 0.11, top_y + 0.024, czb + 0.036), wood_l)

	# ---- Onion + tomato ----
	_box(self, Vector3(0.06, 0.05, 0.06), Vector3(cxb - 0.066, top_y + 0.024, czb + 0.046), tomato)
	_box(self, Vector3(0.052, 0.008, 0.052), Vector3(cxb - 0.14, top_y + 0.02, czb + 0.036), onion)
	_box(self, Vector3(0.06, 0.01, 0.038), Vector3(cxb - 0.066, top_y + 0.052, czb + 0.046), leaf)

	# ---- Pot (center) ----
	var nx := 0.0; var nz := 0.0
	_box(self, Vector3(0.22, 0.11, 0.17), Vector3(nx, top_y + 0.02, nz), iron)
	_box(self, Vector3(0.23, 0.03, 0.18), Vector3(nx, top_y + 0.09, nz), iron)
	_box(self, Vector3(0.045, 0.016, 0.036), Vector3(nx - 0.08, top_y + 0.098, nz), iron_hi)
	_box(self, Vector3(0.11, 0.022, 0.036), Vector3(nx, top_y + 0.098, nz + 0.058), iron_hi)
	# pot handle wood grip
	_box(self, Vector3(0.03, 0.16, 0.03), Vector3(nx + 0.11, top_y + 0.04, nz), wood_l)

	# ---- Pan (right) ----
	var px := 0.52; var pz := 0.0
	_box(self, Vector3(0.20, 0.034, 0.18), Vector3(px, top_y + 0.018, pz), iron_hi)
	_box(self, Vector3(0.19, 0.016, 0.17), Vector3(px, top_y + 0.038, pz), iron)
	_box(self, Vector3(0.032, 0.018, 0.018), Vector3(px - 0.09, top_y + 0.036, pz + 0.024), copper)

	# ---- Plates & bowl (right front) ----
	var dx := 0.30; var dz := -0.16
	_box(self, Vector3(0.11, 0.022, 0.11), Vector3(dx, top_y + 0.008, dz), plate)
	_box(self, Vector3(0.08, 0.01, 0.08), Vector3(dx, top_y + 0.018, dz), plate_in)
	_box(self, Vector3(0.09, 0.055, 0.09), Vector3(dx + 0.17, top_y + 0.012, dz + 0.042), bowl)
	_box(self, Vector3(0.084, 0.018, 0.084), Vector3(dx + 0.17, top_y + 0.048, dz + 0.042), plate)

	# ---- Flour bag (right front corner) ----
	var bx := 0.56; var bz := 0.16
	_box(self, Vector3(0.16, 0.16, 0.12), Vector3(bx, top_y + 0.012, bz), sack)
	_box(self, Vector3(0.16, 0.034, 0.12), Vector3(bx, top_y + 0.098, bz), flour)
	_box(self, Vector3(0.06, 0.016, 0.032), Vector3(bx - 0.032, top_y + 0.116, bz), herb)

	# ---- Spice jars (front edge) ----
	for i in range(3):
		var jx := -0.20 + i * 0.22
		_box(self, Vector3(0.026, 0.044, 0.026), Vector3(jx, top_y + 0.008, -0.44), iron_hi)
		var jar_cols := [flour, herb, tomato]
		_box(self, Vector3(0.020, 0.026, 0.020), Vector3(jx, top_y + 0.032, -0.44), jar_cols[i])

	# ---- Hanging tool rail (back) ----
	for side in [-1, 1]:
		var sx: float = side * 0.46
		_box(self, Vector3(0.26, 0.026, 0.034), Vector3(sx, top_y + 0.058, -0.36), wood_d)
		_box(self, Vector3(0.03, 0.016, 0.06), Vector3(sx - 0.054, top_y + 0.076, -0.36), iron_hi)
		_box(self, Vector3(0.024, 0.066, 0.022), Vector3(sx + 0.06, top_y + 0.076, -0.36), copper)

	# ---- Storage crate under table ----
	var ub_y := ty - th - 0.07
	_box(self, Vector3(0.40, 0.08, 0.28), Vector3(0.0, ub_y, -0.02), wood_d)
	_box(self, Vector3(0.41, 0.024, 0.29), Vector3(0.0, ub_y + 0.044, -0.02), iron_hi)
	_box(self, Vector3(0.12, 0.016, 0.06), Vector3(0.0, ub_y + 0.058, -0.06), herb)

	# ---- Collision ----
	var col := CollisionShape3D.new()
	var box_col := BoxShape3D.new()
	box_col.size = Vector3(2.3, 0.78, 1.2)
	col.shape = box_col
	col.position = Vector3(0, 0.39, 0)
	add_child(col)
