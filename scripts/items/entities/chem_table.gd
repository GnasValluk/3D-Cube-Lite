class_name ChemTable
extends CraftingStation

## Bàn Hoá Học — ống nghiệm, bình cầu, dung dịch màu, đèn cồn, chậu inox.
func _init() -> void:
	super._init(70, "chem_table")

func _setup_mesh() -> void:
	var wood      := _m(Color(0.50, 0.44, 0.38), 0.05, 0.82)
	var wood_d    := _m(Color(0.38, 0.31, 0.26), 0.05, 0.90)
	var metal     := _m(Color(0.44, 0.44, 0.49), 0.60, 0.40)
	var metal_hi  := _m(Color(0.64, 0.64, 0.70), 0.72, 0.30)
	var metal_d   := _m(Color(0.22, 0.22, 0.26), 0.50, 0.65)
	var glass     := _m(Color(0.78, 0.86, 0.94), 0.25, 0.15, true)
	var glass_c   := _m(Color(0.74, 0.88, 0.98), 0.30, 0.20, true)
	var liquid_r  := _m(Color(0.62, 0.36, 0.38), 0.18, 0.28, true)
	var liquid_b  := _m(Color(0.32, 0.40, 0.60), 0.18, 0.28, true)
	var liquid_g  := _m(Color(0.30, 0.56, 0.38), 0.18, 0.28, true)
	var liquid_y  := _m(Color(0.62, 0.56, 0.34), 0.18, 0.28, true)
	var flame     := _m(Color(0.62, 0.36, 0.20), 0.20, 0.60, true)
	var flame_hi  := _m(Color(0.30, 0.16, 0.12), 0.20, 0.80)
	var rust      := _m(Color(0.50, 0.32, 0.24), 0.48, 0.62)

	var tw := 2.00; var td := 1.00; var th := 0.12; var ty := 0.70
	var top_y := ty - th * 0.5

	# ---- Thick dark-wood top ----
	_box(self, Vector3(tw, th, td), Vector3(0, top_y, 0), wood_d)
	_box(self, Vector3(tw - 0.04, th * 0.5, td - 0.04), Vector3(0, top_y + th * 0.30, 0), wood)
	for i in range(3):
		var cx := -0.62 + i * 0.62
		_box(self, Vector3(0.62, th * 0.16, td - 0.06), Vector3(cx, top_y - th * 0.42, 0), metal_hi)

	# ---- Legs + base rails ----
	var lt := 0.10; var lh := ty - th
	for x in [-tw * 0.42, tw * 0.42]:
		for z in [-td * 0.42, td * 0.42]:
			_box(self, Vector3(lt, lh, lt), Vector3(x, lh * 0.5, z), metal_d)
			_box(self, Vector3(lt * 1.2, 0.06, lt * 1.2), Vector3(x, 0.03, z), metal_d)
	for gx in [-tw * 0.18, 0.0, tw * 0.18]:
		_box(self, Vector3(0.06, 0.04, td - 0.3), Vector3(gx, 0.34, 0), metal)

	# ---- Test tube rack (left) ----
	var rx := -0.58; var rz := -0.14
	_box(self, Vector3(0.30, 0.022, 0.05), Vector3(rx, top_y + 0.012, rz), metal)
	_box(self, Vector3(0.30, 0.022, 0.05), Vector3(rx, top_y + 0.062, rz), metal)
	var tubes := [liquid_r, liquid_b, liquid_g, liquid_y, liquid_b]
	for i in range(5):
		var cx := rx - 0.12 + i * 0.058
		if i == 0 or i == 4:
			continue
		_box(self, Vector3(0.028, 0.11, 0.028), Vector3(cx, top_y + 0.02, rz), glass)
		_box(self, Vector3(0.026, 0.05, 0.026), Vector3(cx, top_y + 0.008, rz), tubes[i])

	# ---- Beaker (center-left) ----
	var bx := -0.18; var bz := -0.16
	_box(self, Vector3(0.18, 0.13, 0.18), Vector3(bx, top_y + 0.02, bz), glass)
	_box(self, Vector3(0.16, 0.07, 0.16), Vector3(bx, top_y + 0.01, bz), liquid_b)
	_box(self, Vector3(0.032, 0.11, 0.032), Vector3(bx - 0.022, top_y + 0.09, bz), glass_c)
	# stirrer in beaker
	_box(self, Vector3(0.008, 0.09, 0.008), Vector3(bx, top_y + 0.02, bz), metal_hi)

	# ---- Triangle flask (center) ----
	var tx := -0.40; var tz := 0.20
	_box(self, Vector3(0.13, 0.11, 0.13), Vector3(tx, top_y + 0.018, tz), glass)
	_box(self, Vector3(0.11, 0.055, 0.11), Vector3(tx, top_y + 0.004, tz), liquid_g)
	_box(self, Vector3(0.022, 0.07, 0.022), Vector3(tx, top_y + 0.08, tz), glass_c)

	# ---- Bunsen burner (right front) ----
	var bx2 := 0.22; var bz2 := 0.16
	_box(self, Vector3(0.075, 0.10, 0.075), Vector3(bx2, top_y + 0.008, bz2), metal_d)
	_box(self, Vector3(0.065, 0.032, 0.065), Vector3(bx2, top_y + 0.06, bz2), flame)
	_box(self, Vector3(0.026, 0.032, 0.026), Vector3(bx2, top_y + 0.094, bz2), flame_hi)
	_box(self, Vector3(0.03, 0.036, 0.03), Vector3(bx2 - 0.032, top_y + 0.082, bz2), metal_hi)
	# tube leading to burner
	_box(self, Vector3(0.022, 0.14, 0.022), Vector3(bx2, top_y + 0.16, bz2 - 0.005), glass_c)

	# ---- Funnel + filter paper (center-right) ----
	var fx := 0.42; var fz := 0.24
	_box(self, Vector3(0.032, 0.14, 0.032), Vector3(fx, top_y + 0.01, fz), metal_hi)
	_box(self, Vector3(0.08, 0.06, 0.08), Vector3(fx, top_y + 0.07, fz), glass)

	# ---- Lab tray + spilled liquid (front) ----
	_box(self, Vector3(0.18, 0.045, 0.12), Vector3(0.10, top_y + 0.006, -0.20), glass_c)
	_box(self, Vector3(0.10, 0.012, 0.07), Vector3(0.10, top_y + 0.004, -0.20), liquid_r)

	# ---- Medicine cabinet under table ----
	var ub_y := ty - th - 0.07
	_box(self, Vector3(0.34, 0.08, 0.22), Vector3(-0.56, ub_y, -0.02), metal_d)
	_box(self, Vector3(0.35, 0.024, 0.23), Vector3(-0.56, ub_y + 0.044, -0.02), metal_hi)
	# glass bottles inside cabinet
	for k in range(3):
		var colc: Material = [liquid_r, liquid_b, liquid_g][k]
		_box(self, Vector3(0.024, 0.06, 0.024), Vector3(-0.56 - 0.05 + k * 0.05, ub_y + 0.03, -0.05), colc)

	# ---- Spilled chemical droplets + rust ----
	_box(self, Vector3(0.06, 0.008, 0.05), Vector3(0.30, top_y + 0.002, -0.26), liquid_y)
	_box(self, Vector3(0.07, 0.012, 0.06), Vector3(-0.24, top_y + 0.002, -0.24), rust)

	# ---- Collision ----
	var col := CollisionShape3D.new()
	var box_col := BoxShape3D.new()
	box_col.size = Vector3(2.3, 0.78, 1.2)
	col.shape = box_col
	col.position = Vector3(0, 0.39, 0)
	add_child(col)
