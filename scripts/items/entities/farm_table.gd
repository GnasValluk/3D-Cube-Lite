class_name FarmTable
extends CraftingStation

## Bàn Nông Nghiệp — khay đất, chậu cây, bình tưới, cuốc/xẻng, bao hạt.
func _init() -> void:
	super._init(60, "farm_table")

func _setup_mesh() -> void:
	var wood      := _m(Color(0.54, 0.36, 0.18), 0.05, 0.82)
	var wood_d    := _m(Color(0.38, 0.24, 0.11), 0.05, 0.90)
	var wood_l    := _m(Color(0.60, 0.42, 0.24), 0.05, 0.78)
	var soil      := _m(Color(0.32, 0.24, 0.16), 0.05, 0.93)
	var soil_wet  := _m(Color(0.22, 0.16, 0.11), 0.05, 0.88)
	var leaf      := _m(Color(0.18, 0.48, 0.20), 0.05, 0.80, true)
	var leaf_d    := _m(Color(0.11, 0.32, 0.14), 0.05, 0.88)
	var stem      := _m(Color(0.16, 0.32, 0.14), 0.05, 0.85)
	var can_m     := _m(Color(0.40, 0.34, 0.28), 0.50, 0.50)
	var can_hi    := _m(Color(0.66, 0.58, 0.48), 0.70, 0.40)
	var metal     := _m(Color(0.30, 0.30, 0.34), 0.48, 0.50)
	var sack      := _m(Color(0.58, 0.48, 0.34), 0.05, 0.88)
	var tomato    := _m(Color(0.74, 0.24, 0.20), 0.05, 0.78, true)
	var onion     := _m(Color(0.68, 0.44, 0.24), 0.05, 0.82)

	var tw := 2.00; var td := 1.00; var th := 0.12; var ty := 0.68
	var top_y := ty - th * 0.5

	# ---- Thick wood-plank top ----
	_box(self, Vector3(tw, th, td), Vector3(0, top_y, 0), wood)
	for i in range(3):
		var cx := -0.62 + i * 0.62
		_box(self, Vector3(0.62, th * 0.55, td - 0.08), Vector3(cx, top_y + th * 0.28, 0), wood_l)
	for i in range(2):
		var sx := -0.62 + i * 1.24
		_box(self, Vector3(th * 0.5, th * 0.32, td - 0.08), Vector3(sx, top_y + th * 0.60, 0), metal)

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

	# ---- Seed tray (center-left) ----
	var tx := -0.62; var tz := 0.0
	_box(self, Vector3(0.46, 0.04, 0.28), Vector3(tx, top_y + 0.018, tz), wood_d)
	_box(self, Vector3(0.44, 0.024, 0.26), Vector3(tx, top_y + 0.042, tz), soil_wet)
	for j in range(2):
		var pz := -0.06 + j * 0.12
		_box(self, Vector3(0.09, 0.055, 0.09), Vector3(tx, top_y + 0.064, tz + pz), soil)
		_box(self, Vector3(0.05, 0.09, 0.05), Vector3(tx, top_y + 01.0, tz + pz), stem)

	# ---- Watering can (center) ----
	var cx := 0.0; var cz := -0.18
	_box(self, Vector3(0.22, 0.13, 0.14), Vector3(cx, top_y + 0.02, cz), can_m)
	_box(self, Vector3(0.20, 0.05, 0.12), Vector3(cx, top_y + 0.008, cz), soil_wet)
	_box(self, Vector3(0.024, 0.26, 0.024), Vector3(cx + 0.12, top_y + 0.07, cz), can_hi)
	_box(self, Vector3(0.034, 0.034, 0.06), Vector3(cx - 0.11, top_y + 0.12, cz - 0.03), can_hi)

	# ---- Hoe + rake (right front) ----
	var hx := 0.30; var hz := 0.22
	_box(self, Vector3(0.03, 0.30, 0.03), Vector3(hx, top_y + 0.02, hz), wood)
	_box(self, Vector3(0.18, 0.05, 0.03), Vector3(hx + 0.08, top_y + 0.02, hz), metal)
	_box(self, Vector3(0.03, 0.11, 0.03), Vector3(hx, top_y + 0.17, hz + 0.005), wood)
	_box(self, Vector3(0.24, 0.024, 0.012), Vector3(hx + 0.06, top_y + 0.26, hz), metal)

	# ---- Seed bag (right front corner) ----
	var bbx := 0.28; var bbz := 0.20
	_box(self, Vector3(0.18, 0.22, 0.14), Vector3(bbx, top_y + 0.02, bbz), sack)
	_box(self, Vector3(0.18, 0.05, 0.14), Vector3(bbx, top_y + 0.13, bbz), soil_wet)
	_box(self, Vector3(0.07, 0.018, 0.04), Vector3(bbx + 0.03, top_y + 0.15, bbz), soil)

	# ---- Harvest basket (right mid) ----
	var rb_x := 0.56; var rb_z := -0.14
	_box(self, Vector3(0.22, 0.09, 0.16), Vector3(rb_x, top_y + 0.02, rb_z), wood_d)
	_box(self, Vector3(0.20, 0.06, 0.14), Vector3(rb_x, top_y + 0.058, rb_z), wood_l)
	# woven slats
	for i in range(3):
		_box(self, Vector3(0.05, 0.055, 0.05), Vector3(rb_x - 0.07 + i * 0.07, top_y + 0.03, rb_z + 0.02), leaf_d)
	_box(self, Vector3(0.09, 0.024, 0.036), Vector3(rb_x + 0.03, top_y + 0.042, rb_z), tomato)

	# ---- Potted sprouting plant (left front) ----
	var pzx := -0.30; var pzz := 0.20
	_box(self, Vector3(0.11, 0.10, 0.11), Vector3(pzx, top_y + 0.005, pzz), wood_d)
	_box(self, Vector3(0.09, 0.032, 0.09), Vector3(pzx, top_y + 0.055, pzz), soil)
	_box(self, Vector3(0.026, 0.16, 0.026), Vector3(pzx, top_y + 0.09, pzz), stem)
	_box(self, Vector3(0.09, 0.028, 0.06), Vector3(pzx, top_y + 0.16, pzz), leaf)

	# ---- Scattered produce ----
	_box(self, Vector3(0.058, 0.052, 0.058), Vector3(-0.52, top_y + 0.01, 0.16), tomato)
	_box(self, Vector3(0.052, 0.02, 0.052), Vector3(-0.42, top_y + 0.006, 0.13), onion)

	# ---- Collision ----
	var col := CollisionShape3D.new()
	var box_col := BoxShape3D.new()
	box_col.size = Vector3(2.2, 0.75, 1.2)
	col.shape = box_col
	col.position = Vector3(0, 0.38, 0)
	add_child(col)
