class_name StructuresMesh

static func _cs(v: float, s: float) -> float:
	return v * s

# ── CHEST ───────────────────────────────────────────────────────────────────
static func chest(p: Node3D) -> void:
	const SCX: float = 2.84; const SCY: float = 4.17; const SCZ: float = 3.21

	var wood       := Color(0.42, 0.26, 0.14)
	var wood_lid   := Color(0.47, 0.30, 0.17)
	var plank_dark := Color(0.28, 0.14, 0.07)
	var metal      := Color(0.25, 0.22, 0.20)
	var rivet      := Color(0.35, 0.32, 0.30)
	var lock_gold  := Color(0.75, 0.60, 0.20)
	var hinge      := Color(0.32, 0.28, 0.26)

	var bw := _cs(1.76, SCX); var bh := _cs(0.36, SCY); var bd := _cs(0.78, SCZ)
	var bx := 0.0; var bz := 0.0; var by := bh * 0.5

	ItemMeshShared.add_cube(p, bx, by, bz, bw, bh, bd, wood)

	var fz := bd * 0.5 + _cs(0.005, SCZ)
	var sx := bw * 0.5 + _cs(0.005, SCX)

	for xv in [-0.60, -0.30, 0, 0.30, 0.60]:
		ItemMeshShared.add_cube(p, _cs(xv, SCX), by, fz, _cs(0.02, SCX), _cs(0.26, SCY), _cs(0.01, SCZ), plank_dark)
	for zv in [-0.20, 0.20]:
		ItemMeshShared.add_cube(p, -sx, by, _cs(zv, SCZ), _cs(0.01, SCX), _cs(0.26, SCY), _cs(0.02, SCZ), plank_dark)
		ItemMeshShared.add_cube(p, sx, by, _cs(zv, SCZ), _cs(0.01, SCX), _cs(0.26, SCY), _cs(0.02, SCZ), plank_dark)

	var bhv := _cs(0.04, SCY); var bdv := _cs(0.06, SCZ)
	var byb := _cs(0.06, SCY); var byt := _cs(0.30, SCY)

	for byv in [byb, byt]:
		ItemMeshShared.add_cube(p, bx, byv, fz, bw + _cs(0.04, SCX), bhv, bdv, metal)
		ItemMeshShared.add_cube(p, -sx, byv, bz, _cs(0.06, SCX), bhv, bd - _cs(0.04, SCZ), metal)
		ItemMeshShared.add_cube(p, sx, byv, bz, _cs(0.06, SCX), bhv, bd - _cs(0.04, SCZ), metal)

	for xv in [-0.54, -0.18, 0.18, 0.54]:
		for yv in [byb, byt]:
			ItemMeshShared.add_cube(p, _cs(xv, SCX), yv, fz + _cs(0.03, SCZ), _cs(0.04, SCX), _cs(0.03, SCY), _cs(0.04, SCZ), rivet)

	var lwv := _cs(0.16, SCX); var lhv := _cs(0.14, SCY); var ldv := _cs(0.08, SCZ)
	ItemMeshShared.add_cube(p, bx, by, fz + _cs(0.04, SCZ), lwv, lhv, ldv, lock_gold)
	ItemMeshShared.add_cube(p, bx, by + lhv * 0.5 + _cs(0.02, SCY), fz + _cs(0.04, SCZ), _cs(0.08, SCX), _cs(0.04, SCY), _cs(0.04, SCZ), metal)

	var hz := -(bd * 0.5 + _cs(0.01, SCZ))
	ItemMeshShared.add_cube(p, _cs(-0.50, SCX), by, hz, _cs(0.06, SCX), _cs(0.10, SCY), _cs(0.04, SCZ), hinge)
	ItemMeshShared.add_cube(p, _cs(0.50, SCX), by, hz, _cs(0.06, SCX), _cs(0.10, SCY), _cs(0.04, SCZ), hinge)

	var lw := bw + _cs(0.08, SCX); var lh := _cs(0.06, SCY); var ld := bd + _cs(0.06, SCZ)
	var lid_y := bh + lh * 0.5
	ItemMeshShared.add_cube(p, bx, lid_y, bz + ld * 0.5, lw, lh, ld, wood_lid)
	ItemMeshShared.add_cube(p, bx, lid_y, bz + ld * 0.5 - _cs(0.02, SCZ), lw + _cs(0.02, SCX), lh * 0.5, _cs(0.04, SCZ), metal)
	for xv in [-0.54, -0.18, 0.18, 0.54]:
		ItemMeshShared.add_cube(p, _cs(xv, SCX), lid_y, bz + ld * 0.5, _cs(0.03, SCX), _cs(0.02, SCY), _cs(0.03, SCZ), rivet)


# ── CRAFTING TABLE ──────────────────────────────────────────────────────────
static func crafting_table(p: Node3D) -> void:
	const SC: float = 2.78

	var wood       := Color(0.42, 0.26, 0.14)
	var wood_dark  := Color(0.35, 0.20, 0.10)
	var wood_light := Color(0.50, 0.32, 0.17)
	var metal      := Color(0.22, 0.22, 0.25)
	var anvil_mat  := Color(0.28, 0.28, 0.32)
	var fire_glow  := Color(0.70, 0.20, 0.05)
	var fire_hot   := Color(0.90, 0.55, 0.10)
	var grid_mark  := Color(0.28, 0.16, 0.08)
	var gold_coin  := Color(0.80, 0.65, 0.15)
	var scrap      := Color(0.30, 0.30, 0.32)
	var gem_blue   := Color(0.15, 0.40, 0.80)
	var bottle_red := Color(0.70, 0.15, 0.15)
	var bottle_grn := Color(0.15, 0.55, 0.25)

	var tw := 5.0; var td := 2.36; var th := _cs(0.05, SC)
	var ty := _cs(0.65, SC)

	ItemMeshShared.add_cube(p, 0, ty - th * 0.5, 0, tw, th, td, wood)

	var lt := _cs(0.05, SC); var lh := ty - th
	for xv in [-tw * 0.5 + lt * 0.6, tw * 0.5 - lt * 0.6]:
		for zv in [-td * 0.5 + lt * 0.6, td * 0.5 - lt * 0.6]:
			ItemMeshShared.add_cube(p, xv, lh * 0.5, zv, lt * 0.7, lh, lt * 0.7, wood_dark)

	ItemMeshShared.add_cube(p, 0, _cs(0.15, SC), -td * 0.5 + lt * 0.6, tw - _cs(0.24, SC), _cs(0.03, SC), _cs(0.04, SC), wood_dark)
	ItemMeshShared.add_cube(p, 0, _cs(0.15, SC), td * 0.5 - lt * 0.6, tw - _cs(0.24, SC), _cs(0.03, SC), _cs(0.04, SC), wood_dark)

	var gc := _cs(0.42, SC) * 2.86; var cell := gc / 3.0
	ItemMeshShared.add_cube(p, 0, ty, 0, gc + _cs(0.04, SC), _cs(0.01, SC), gc + _cs(0.04, SC), grid_mark)
	for row in range(3):
		for col in range(3):
			var cx := (col - 1) * cell; var cz := (row - 1) * cell
			ItemMeshShared.add_cube(p, cx, ty + _cs(0.005, SC), cz, cell - _cs(0.02, SC), _cs(0.01, SC), cell - _cs(0.02, SC), wood_light)

	var fx := _cs(0.52, SC); var fz := _cs(-0.12, SC)
	ItemMeshShared.add_cube(p, fx, ty + _cs(0.06, SC), fz, _cs(0.26, SC), _cs(0.12, SC), _cs(0.22, SC), metal)
	ItemMeshShared.add_cube(p, fx, ty + _cs(0.14, SC), fz, _cs(0.16, SC), _cs(0.04, SC), _cs(0.14, SC), fire_glow)
	ItemMeshShared.add_cube(p, fx, ty + _cs(0.17, SC), fz, _cs(0.08, SC), _cs(0.02, SC), _cs(0.07, SC), fire_hot)
	ItemMeshShared.add_cube(p, fx, ty + _cs(0.13, SC), fz, _cs(0.26, SC), _cs(0.02, SC), _cs(0.22, SC), metal)

	var ax := _cs(0.75, SC); var az := _cs(-0.12, SC)
	ItemMeshShared.add_cube(p, ax, ty + _cs(0.08, SC), az, _cs(0.12, SC), _cs(0.06, SC), _cs(0.09, SC), anvil_mat)
	ItemMeshShared.add_cube(p, ax, ty + _cs(0.14, SC), az, _cs(0.08, SC), _cs(0.04, SC), _cs(0.06, SC), anvil_mat)
	ItemMeshShared.add_cube(p, ax, ty + _cs(0.06, SC), az, _cs(0.10, SC), _cs(0.02, SC), _cs(0.07, SC), metal)

	var apx := _cs(0.46, SC); var apz := _cs(0.28, SC)
	ItemMeshShared.add_cube(p, apx, ty + _cs(0.03, SC), apz, _cs(0.18, SC), _cs(0.02, SC), _cs(0.12, SC), wood_dark)
	ItemMeshShared.add_cube(p, apx - _cs(0.05, SC), ty + _cs(0.065, SC), apz, _cs(0.02, SC), _cs(0.05, SC), _cs(0.02, SC), bottle_red)
	ItemMeshShared.add_cube(p, apx, ty + _cs(0.07, SC), apz, _cs(0.02, SC), _cs(0.06, SC), _cs(0.02, SC), bottle_grn)
	ItemMeshShared.add_cube(p, apx + _cs(0.05, SC), ty + _cs(0.065, SC), apz, _cs(0.02, SC), _cs(0.05, SC), _cs(0.02, SC), Color(0.55, 0.65, 0.75))

	ItemMeshShared.add_cube(p, _cs(-0.50, SC), ty + _cs(0.01, SC), _cs(-0.18, SC), _cs(0.06, SC), _cs(0.02, SC), _cs(0.06, SC), gold_coin)
	ItemMeshShared.add_cube(p, _cs(-0.38, SC), ty + _cs(0.01, SC), _cs(-0.12, SC), _cs(0.06, SC), _cs(0.02, SC), _cs(0.06, SC), gold_coin)
	ItemMeshShared.add_cube(p, _cs(-0.44, SC), ty + _cs(0.03, SC), _cs(-0.15, SC), _cs(0.06, SC), _cs(0.04, SC), _cs(0.06, SC), gold_coin)
	ItemMeshShared.add_cube(p, _cs(-0.55, SC), ty + _cs(0.005, SC), _cs(0.12, SC), _cs(0.04, SC), _cs(0.01, SC), _cs(0.07, SC), scrap)
	ItemMeshShared.add_cube(p, _cs(-0.60, SC), ty + _cs(0.02, SC), _cs(0.02, SC), _cs(0.04, SC), _cs(0.04, SC), _cs(0.04, SC), gem_blue)

	var uby := ty - th - _cs(0.06, SC)
	ItemMeshShared.add_cube(p, _cs(-0.55, SC), uby, _cs(-0.20, SC), _cs(0.12, SC), _cs(0.05, SC), _cs(0.10, SC), wood_dark)
	ItemMeshShared.add_cube(p, _cs(-0.55, SC), uby, _cs(0.20, SC), _cs(0.12, SC), _cs(0.05, SC), _cs(0.10, SC), wood_dark)

	var dry := ty - th - _cs(0.04, SC)
	ItemMeshShared.add_cube(p, _cs(-0.30, SC), dry, td * 0.5 - _cs(0.04, SC), _cs(0.14, SC), _cs(0.04, SC), _cs(0.08, SC), wood_light)
	ItemMeshShared.add_cube(p, _cs(-0.30, SC), dry + _cs(0.02, SC), td * 0.5 - _cs(0.02, SC), _cs(0.14, SC), _cs(0.02, SC), _cs(0.02, SC), Color(0.25, 0.18, 0.10))


# ── TOOL TABLE ──────────────────────────────────────────────────────────────
static func tool_table(p: Node3D) -> void:
	const SC: float = 2.78

	var wood       := Color(0.46, 0.28, 0.13)
	var wood_dark  := Color(0.36, 0.20, 0.09)
	var wood_light := Color(0.55, 0.36, 0.17)
	var steel      := Color(0.30, 0.30, 0.35)
	var steel_hi   := Color(0.50, 0.51, 0.57)
	var handle     := Color(0.52, 0.36, 0.18)

	var tw := 5.0; var td := 2.36; var th := _cs(0.05, SC)
	var ty := _cs(0.65, SC)

	ItemMeshShared.add_cube(p, 0, ty - th * 0.5, 0, tw, th, td, wood)

	var lt := _cs(0.05, SC); var lh := ty - th
	for xv in [-tw * 0.5 + lt * 0.6, tw * 0.5 - lt * 0.6]:
		for zv in [-td * 0.5 + lt * 0.6, td * 0.5 - lt * 0.6]:
			ItemMeshShared.add_cube(p, xv, lh * 0.5, zv, lt * 0.7, lh, lt * 0.7, wood_dark)

	ItemMeshShared.add_cube(p, 0, _cs(0.15, SC), -td * 0.5 + lt * 0.6, tw - _cs(0.24, SC), _cs(0.03, SC), _cs(0.04, SC), wood_dark)
	ItemMeshShared.add_cube(p, 0, _cs(0.15, SC), td * 0.5 - lt * 0.6, tw - _cs(0.24, SC), _cs(0.03, SC), _cs(0.04, SC), wood_dark)

	# Đe mini
	var ax := _cs(0.72, SC); var az := _cs(-0.12, SC)
	ItemMeshShared.add_cube(p, ax, ty + _cs(0.07, SC), az, _cs(0.14, SC), _cs(0.05, SC), _cs(0.10, SC), steel)
	ItemMeshShared.add_cube(p, ax, ty + _cs(0.14, SC), az, _cs(0.09, SC), _cs(0.04, SC), _cs(0.07, SC), steel_hi)
	ItemMeshShared.add_cube(p, ax, ty + _cs(0.06, SC), az, _cs(0.12, SC), _cs(0.02, SC), _cs(0.08, SC), steel_hi)

	# Búa + cưa trên mặt
	ItemMeshShared.add_cube(p, _cs(-0.58, SC), ty + _cs(0.02, SC), _cs(0.10, SC), _cs(0.12, SC), _cs(0.04, SC), _cs(0.04, SC), steel_hi)
	ItemMeshShared.add_cube(p, _cs(-0.58, SC), ty + _cs(0.045, SC), _cs(0.10, SC), _cs(0.04, SC), _cs(0.03, SC), _cs(0.03, SC), handle)
	ItemMeshShared.add_cube(p, _cs(-0.42, SC), ty + _cs(0.02, SC), _cs(0.10, SC), _cs(0.04, SC), _cs(0.05, SC), _cs(0.03, SC), steel)

	# Kẹp chữ C
	var cx := _cs(0.10, SC); var cz := _cs(-0.30, SC)
	ItemMeshShared.add_cube(p, cx, ty + _cs(0.03, SC), cz, _cs(0.08, SC), _cs(0.04, SC), _cs(0.04, SC), steel)
	ItemMeshShared.add_cube(p, cx, ty + _cs(0.07, SC), cz, _cs(0.08, SC), _cs(0.03, SC), _cs(0.04, SC), steel_hi)

	# Kệ treo dụng cụ
	for s in [-1, 1]:
		var sx: float = s * _cs(0.45, SC)
		ItemMeshShared.add_cube(p, sx, ty + _cs(0.06, SC), _cs(-0.30, SC), _cs(0.26, SC), _cs(0.02, SC), _cs(0.03, SC), wood_dark)
		ItemMeshShared.add_cube(p, sx - _cs(0.08, SC), ty + _cs(0.10, SC), _cs(-0.30, SC), _cs(0.02, SC), _cs(0.07, SC), _cs(0.02, SC), steel)
		ItemMeshShared.add_cube(p, sx - _cs(0.08, SC), ty + _cs(0.14, SC), _cs(-0.30, SC), _cs(0.07, SC), _cs(0.03, SC), _cs(0.02, SC), steel_hi)
		ItemMeshShared.add_cube(p, sx + _cs(0.08, SC), ty + _cs(0.13, SC), _cs(-0.30, SC), _cs(0.02, SC), _cs(0.08, SC), _cs(0.02, SC), steel)

	# Ván lót mặt bàn
	ItemMeshShared.add_cube(p, 0, ty + _cs(0.005, SC), 0, tw - _cs(0.4, SC), _cs(0.008, SC), td - _cs(0.1, SC), wood_light)

	# Va li dụng cụ
	var ub_y := ty - th - _cs(0.06, SC)
	ItemMeshShared.add_cube(p, _cs(-0.45, SC), ub_y, _cs(0.10, SC), _cs(0.30, SC), _cs(0.06, SC), _cs(0.20, SC), wood_dark)
	ItemMeshShared.add_cube(p, _cs(-0.45, SC), ub_y + _cs(0.03, SC), _cs(0.10, SC), _cs(0.31, SC), _cs(0.02, SC), _cs(0.21, SC), steel_hi)


# ── MECH TABLE ──────────────────────────────────────────────────────────────
static func mech_table(p: Node3D) -> void:
	const SC: float = 2.78

	var steel      := Color(0.32, 0.34, 0.40)
	var steel_hi   := Color(0.55, 0.56, 0.62)
	var steel_dark := Color(0.20, 0.21, 0.26)
	var copper     := Color(0.72, 0.45, 0.20)
	var rust       := Color(0.40, 0.30, 0.22)

	var tw := 5.0; var td := 2.36; var th := _cs(0.06, SC)
	var ty := _cs(0.70, SC)

	ItemMeshShared.add_cube(p, 0, ty - th * 0.5, 0, tw, th, td, steel_dark)
	ItemMeshShared.add_cube(p, 0, ty + _cs(0.005, SC), 0, tw - _cs(0.2, SC), _cs(0.012, SC), td - _cs(0.2, SC), steel)

	var lt := _cs(0.07, SC); var lh := ty - th
	for xv in [-tw * 0.5 + lt * 0.6, tw * 0.5 - lt * 0.6]:
		for zv in [-td * 0.5 + lt * 0.6, td * 0.5 - lt * 0.6]:
			ItemMeshShared.add_cube(p, xv, lh * 0.5, zv, lt, lh, lt, steel_dark)

	ItemMeshShared.add_cube(p, 0, _cs(0.22, SC), -td * 0.5 + lt * 0.6, tw - _cs(0.3, SC), _cs(0.02, SC), lt * 0.8, steel_dark)
	ItemMeshShared.add_cube(p, 0, _cs(0.22, SC), td * 0.5 - lt * 0.6, tw - _cs(0.3, SC), _cs(0.02, SC), lt * 0.8, steel_dark)

	# Bánh răng lớn
	var gx := _cs(-0.62, SC); var gz := _cs(0.10, SC)
	ItemMeshShared.add_cube(p, gx, ty + _cs(0.06, SC), gz, _cs(0.20, SC), _cs(0.05, SC), _cs(0.07, SC), steel_hi)
	ItemMeshShared.add_cube(p, gx, ty + _cs(0.06, SC), gz, _cs(0.30, SC), _cs(0.05, SC), _cs(0.05, SC), steel_dark)
	ItemMeshShared.add_cube(p, gx + _cs(0.10, SC), ty + _cs(0.06, SC), gz, _cs(0.07, SC), _cs(0.06, SC), _cs(0.07, SC), copper)

	# Pít-tông
	var px := _cs(-0.30, SC); var pz := _cs(0.20, SC)
	ItemMeshShared.add_cube(p, px, ty + _cs(0.02, SC), pz, _cs(0.09, SC), _cs(0.10, SC), _cs(0.07, SC), steel)
	ItemMeshShared.add_cube(p, px, ty + _cs(0.11, SC), pz, _cs(0.05, SC), _cs(0.16, SC), _cs(0.05, SC), steel_hi)
	ItemMeshShared.add_cube(p, px, ty + _cs(0.19, SC), pz, _cs(0.06, SC), _cs(0.03, SC), _cs(0.06, SC), copper)

	# Động cơ nhỏ
	var ex := _cs(0.62, SC); var ez := _cs(0.10, SC)
	ItemMeshShared.add_cube(p, ex, ty + _cs(0.02, SC), ez, _cs(0.20, SC), _cs(0.12, SC), _cs(0.14, SC), steel_dark)
	ItemMeshShared.add_cube(p, ex, ty + _cs(0.10, SC), ez, _cs(0.12, SC), _cs(0.04, SC), _cs(0.04, SC), copper)
	ItemMeshShared.add_cube(p, ex - _cs(0.04, SC), ty + _cs(0.09, SC), ez, _cs(0.06, SC), _cs(0.03, SC), _cs(0.05, SC), copper)

	# Cờ lê + mỏ lết
	ItemMeshShared.add_cube(p, _cs(0.12, SC), ty + _cs(0.04, SC), _cs(-0.16, SC), _cs(0.02, SC), _cs(0.05, SC), _cs(0.04, SC), steel_hi)
	var ridx: float = _cs(0.14, SC)
	for xv in [ridx]:
		ItemMeshShared.add_cube(p, xv - _cs(0.03, SC), ty + _cs(0.05, SC), _cs(-0.16, SC), _cs(0.06, SC), _cs(0.02, SC), _cs(0.04, SC), steel)

	# Van ống
	ItemMeshShared.add_cube(p, _cs(0.35, SC), ty + _cs(0.03, SC), _cs(0.18, SC), _cs(0.07, SC), _cs(0.05, SC), _cs(0.07, SC), copper)
	ItemMeshShared.add_cube(p, _cs(0.35, SC), ty + _cs(0.08, SC), _cs(0.18, SC), _cs(0.04, SC), _cs(0.02, SC), _cs(0.04, SC), steel_hi)

	# Dầu mỡ loang
	ItemMeshShared.add_cube(p, _cs(0.30, SC), ty + _cs(0.004, SC), _cs(-0.28, SC), _cs(0.08, SC), _cs(0.012, SC), _cs(0.06, SC), rust)

	# Hộp đồ nghề
	var ub_y := ty - th - _cs(0.06, SC)
	ItemMeshShared.add_cube(p, _cs(-0.45, SC), ub_y, _cs(0.10, SC), _cs(0.32, SC), _cs(0.08, SC), _cs(0.22, SC), steel_dark)
	ItemMeshShared.add_cube(p, _cs(-0.45, SC), ub_y + _cs(0.05, SC), _cs(0.10, SC), _cs(0.33, SC), _cs(0.02, SC), _cs(0.23, SC), steel_hi)


# ── FARM TABLE ──────────────────────────────────────────────────────────────
static func farm_table(p: Node3D) -> void:
	const SC: float = 2.78

	var wood       := Color(0.52, 0.34, 0.16)
	var wood_dark  := Color(0.40, 0.24, 0.11)
	var soil       := Color(0.30, 0.22, 0.14)
	var soil_wet   := Color(0.20, 0.15, 0.10)
	var leaf       := Color(0.16, 0.45, 0.18)
	var leaf_dark  := Color(0.10, 0.32, 0.14)
	var can        := Color(0.38, 0.32, 0.26)
	var can_hi     := Color(0.62, 0.55, 0.45)
	var metal      := Color(0.28, 0.28, 0.32)
	var sack       := Color(0.55, 0.46, 0.32)

	var tw := 5.0; var td := 2.36; var th := _cs(0.05, SC)
	var ty := _cs(0.62, SC)

	ItemMeshShared.add_cube(p, 0, ty - th * 0.5, 0, tw, th, td, wood)

	var lt := _cs(0.05, SC); var lh := ty - th
	for xv in [-tw * 0.5 + lt * 0.6, tw * 0.5 - lt * 0.6]:
		for zv in [-td * 0.5 + lt * 0.6, td * 0.5 - lt * 0.6]:
			ItemMeshShared.add_cube(p, xv, lh * 0.5, zv, lt * 0.7, lh, lt * 0.7, wood_dark)

	# Khay ươm cây
	var tx := _cs(-0.60, SC)
	ItemMeshShared.add_cube(p, tx, ty + _cs(0.015, SC), 0, _cs(0.42, SC), _cs(0.03, SC), _cs(0.26, SC), wood_dark)
	ItemMeshShared.add_cube(p, tx, ty + _cs(0.03, SC), 0, _cs(0.40, SC), _cs(0.02, SC), _cs(0.24, SC), soil)
	for i in range(3):
		var px := tx
		for j in range(2):
			var pz := _cs(-0.06, SC) + j * _cs(0.12, SC)
			ItemMeshShared.add_cube(p, px, ty + _cs(0.055, SC), pz, _cs(0.08, SC), _cs(0.05, SC), _cs(0.08, SC), soil)
			ItemMeshShared.add_cube(p, px, ty + _cs(0.10, SC), pz, _cs(0.045, SC), _cs(0.05, SC), _cs(0.045, SC), leaf_dark)
			ItemMeshShared.add_cube(p, px, ty + _cs(0.13, SC), pz, _cs(0.05, SC), _cs(0.025, SC), _cs(0.035, SC), leaf)

	# Bình tưới
	var cax := _cs(-0.05, SC); var caz := _cs(-0.16, SC)
	ItemMeshShared.add_cube(p, cax, ty + _cs(0.02, SC), caz, _cs(0.20, SC), _cs(0.12, SC), _cs(0.13, SC), can)
	ItemMeshShared.add_cube(p, cax, ty + _cs(0.02, SC), caz, _cs(0.18, SC), _cs(0.04, SC), _cs(0.10, SC), soil_wet)
	ItemMeshShared.add_cube(p, cax + _cs(0.11, SC), ty + _cs(0.06, SC), caz, _cs(0.02, SC), _cs(0.20, SC), _cs(0.02, SC), can_hi)

	# Cuốc + xẻng
	var hx := _cs(0.28, SC); var hz := _cs(0.24, SC)
	ItemMeshShared.add_cube(p, hx, ty + _cs(0.02, SC), hz, _cs(0.02, SC), _cs(0.26, SC), _cs(0.02, SC), wood)
	ItemMeshShared.add_cube(p, hx + _cs(0.08, SC), ty + _cs(0.02, SC), hz, _cs(0.16, SC), _cs(0.05, SC), _cs(0.03, SC), metal)
	ItemMeshShared.add_cube(p, hx, ty + _cs(0.12, SC), hz, _cs(0.02, SC), _cs(0.06, SC), _cs(0.10, SC), wood)

	# Bao hạt giống
	var bbx := _cs(-0.10, SC); var bbz := _cs(0.22, SC)
	ItemMeshShared.add_cube(p, bbx, ty + _cs(0.005, SC), bbz, _cs(0.16, SC), _cs(0.18, SC), _cs(0.12, SC), sack)
	ItemMeshShared.add_cube(p, bbx, ty + _cs(0.095, SC), bbz, _cs(0.16, SC), _cs(0.04, SC), _cs(0.12, SC), soil_wet)

	# Rổ rau
	var rb_x := _cs(0.55, SC); var rb_z := _cs(-0.14, SC)
	ItemMeshShared.add_cube(p, rb_x, ty + _cs(0.005, SC), rb_z, _cs(0.20, SC), _cs(0.08, SC), _cs(0.14, SC), wood)
	ItemMeshShared.add_cube(p, rb_x, ty + _cs(0.045, SC), rb_z, _cs(0.04, SC), _cs(0.05, SC), _cs(0.03, SC), leaf)
	ItemMeshShared.add_cube(p, rb_x + _cs(0.05, SC), ty + _cs(0.05, SC), rb_z, _cs(0.04, SC), _cs(0.06, SC), _cs(0.03, SC), leaf_dark)

	# Chậu đất trồng
	var pzx := _cs(-0.28, SC); var pzz := _cs(0.18, SC)
	ItemMeshShared.add_cube(p, pzx, ty + _cs(0.005, SC), pzz, _cs(0.10, SC), _cs(0.09, SC), _cs(0.10, SC), wood_dark)
	ItemMeshShared.add_cube(p, pzx, ty + _cs(0.05, SC), pzz, _cs(0.08, SC), _cs(0.03, SC), _cs(0.08, SC), soil)
	ItemMeshShared.add_cube(p, pzx, ty + _cs(0.14, SC), pzz, _cs(0.045, SC), _cs(0.02, SC), _cs(0.045, SC), leaf)


# ── CHEM TABLE ──────────────────────────────────────────────────────────────
static func chem_table(p: Node3D) -> void:
	const SC: float = 2.78

	var wood      := Color(0.50, 0.44, 0.38)
	var wood_dark := Color(0.38, 0.31, 0.26)
	var metal     := Color(0.42, 0.42, 0.48)
	var metal_hi  := Color(0.60, 0.60, 0.66)
	var glass     := Color(0.75, 0.82, 0.90)
	var glass_c   := Color(0.70, 0.85, 0.95)
	var liquid_r  := Color(0.55, 0.35, 0.36)
	var liquid_b  := Color(0.30, 0.36, 0.55)
	var liquid_g  := Color(0.28, 0.50, 0.36)
	var liquid_y  := Color(0.55, 0.50, 0.32)

	var tw := 5.0; var td := 2.36; var th := _cs(0.05, SC)
	var ty := _cs(0.66, SC)

	ItemMeshShared.add_cube(p, 0, ty - th * 0.5, 0, tw, th, td, wood)

	var lt := _cs(0.05, SC); var lh := ty - th
	for xv in [-tw * 0.5 + lt * 0.6, tw * 0.5 - lt * 0.6]:
		for zv in [-td * 0.5 + lt * 0.6, td * 0.5 - lt * 0.6]:
			ItemMeshShared.add_cube(p, xv, lh * 0.5, zv, lt * 0.7, lh, lt * 0.7, wood_dark)

	ItemMeshShared.add_cube(p, 0, _cs(0.18, SC), -td * 0.5 + lt * 0.6, tw - _cs(0.3, SC), _cs(0.025, SC), _cs(0.04, SC), wood_dark)
	ItemMeshShared.add_cube(p, 0, _cs(0.18, SC), td * 0.5 - lt * 0.6, tw - _cs(0.3, SC), _cs(0.025, SC), _cs(0.04, SC), wood_dark)

	# Giá ống nghiệm
	var rx := _cs(-0.58, SC)
	ItemMeshShared.add_cube(p, rx, ty + _cs(0.015, SC), _cs(-0.18, SC), _cs(0.26, SC), _cs(0.015, SC), _cs(0.05, SC), metal)
	ItemMeshShared.add_cube(p, rx, ty + _cs(0.06, SC), _cs(-0.18, SC), _cs(0.26, SC), _cs(0.015, SC), _cs(0.05, SC), metal)
	var tubes := [liquid_r, liquid_b, liquid_g, liquid_y, liquid_b]
	for i in range(5):
		var cx := rx - _cs(0.10, SC) + i * _cs(0.05, SC)
		ItemMeshShared.add_cube(p, cx, ty + _cs(0.04, SC), _cs(-0.18, SC), _cs(0.026, SC), _cs(0.07, SC), _cs(0.026, SC), glass)
		ItemMeshShared.add_cube(p, cx, ty + _cs(0.005, SC), _cs(-0.18, SC), _cs(0.022, SC), _cs(0.03, SC), _cs(0.022, SC), tubes[i])

	# Bình cầu
	var fx := _cs(-0.18, SC); var fz := _cs(-0.20, SC)
	ItemMeshShared.add_cube(p, fx, ty + _cs(0.02, SC), fz, _cs(0.16, SC), _cs(0.12, SC), _cs(0.16, SC), glass)
	ItemMeshShared.add_cube(p, fx, ty + _cs(0.005, SC), fz, _cs(0.14, SC), _cs(0.06, SC), _cs(0.14, SC), liquid_b)
	ItemMeshShared.add_cube(p, fx, ty + _cs(0.10, SC), fz, _cs(0.04, SC), _cs(0.10, SC), _cs(0.04, SC), glass_c)

	# Bình tam giác
	var tx := _cs(-0.40, SC); var tz := _cs(0.24, SC)
	ItemMeshShared.add_cube(p, tx, ty + _cs(0.015, SC), tz, _cs(0.12, SC), _cs(0.10, SC), _cs(0.12, SC), glass)
	ItemMeshShared.add_cube(p, tx, ty + _cs(0.003, SC), tz, _cs(0.10, SC), _cs(0.05, SC), _cs(0.10, SC), liquid_g)

	# Ống đong
	var ox := _cs(0.70, SC); var oz := _cs(0.20, SC)
	ItemMeshShared.add_cube(p, ox, ty + _cs(0.01, SC), oz, _cs(0.05, SC), _cs(0.12, SC), _cs(0.05, SC), glass_c)
	ItemMeshShared.add_cube(p, ox, ty + _cs(0.005, SC), oz, _cs(0.035, SC), _cs(0.05, SC), _cs(0.035, SC), liquid_y)

	# Ống nhỏ nằm ngang
	ItemMeshShared.add_cube(p, _cs(0.28, SC), ty + _cs(0.01, SC), _cs(-0.28, SC), _cs(0.18, SC), _cs(0.025, SC), _cs(0.025, SC), glass)


# ── MAGIC TABLE ─────────────────────────────────────────────────────────────
static func magic_table(p: Node3D) -> void:
	const SC: float = 2.78

	var wood      := Color(0.16, 0.10, 0.18)
	var wood_dark := Color(0.10, 0.06, 0.14)
	var crystal   := Color(0.55, 0.30, 0.88)
	var crystal_b := Color(0.26, 0.14, 0.45)
	var orb       := Color(0.75, 0.60, 0.95)
	var candle    := Color(0.90, 0.88, 0.80)
	var candle_w  := Color(0.45, 0.32, 0.18)
	var flame     := Color(0.95, 0.55, 0.15)
	var book      := Color(0.30, 0.12, 0.30)
	var book_pg   := Color(0.85, 0.80, 0.65)
	var gold      := Color(0.75, 0.60, 0.25)
	var rune      := Color(0.85, 0.45, 0.95)

	var tw := 5.0; var td := 2.36; var th := _cs(0.05, SC)
	var ty := _cs(0.68, SC)

	ItemMeshShared.add_cube(p, 0, ty - th * 0.5, 0, tw, th, td, wood)
	ItemMeshShared.add_cube(p, 0, ty + _cs(0.004, SC), 0, tw - _cs(0.3, SC), _cs(0.01, SC), td - _cs(0.3, SC), wood_dark)

	var lt := _cs(0.06, SC); var lh := ty - th
	for xv in [-tw * 0.5 + lt * 0.6, tw * 0.5 - lt * 0.6]:
		for zv in [-td * 0.5 + lt * 0.6, td * 0.5 - lt * 0.6]:
			ItemMeshShared.add_cube(p, xv, lh * 0.5, zv, lt * 0.7, lh, lt * 0.7, wood_dark)

	# Tinh thể
	var cx := _cs(-0.55, SC); var cz := _cs(0.14, SC)
	ItemMeshShared.add_cube(p, cx, ty + _cs(0.005, SC), cz, _cs(0.06, SC), _cs(0.02, SC), _cs(0.06, SC), gold)
	ItemMeshShared.add_cube(p, cx, ty + _cs(0.14, SC), cz, _cs(0.16, SC), _cs(0.16, SC), _cs(0.12, SC), crystal)
	ItemMeshShared.add_cube(p, cx + _cs(0.03, SC), ty + _cs(0.16, SC), cz + _cs(0.02, SC), _cs(0.16, SC), _cs(0.14, SC), _cs(0.09, SC), crystal_b)
	ItemMeshShared.add_cube(p, cx - _cs(0.10, SC), ty + _cs(0.24, SC), cz, _cs(0.07, SC), _cs(0.06, SC), _cs(0.06, SC), crystal)

	# Quả cầu
	var ox := _cs(0.52, SC); var oz := _cs(0.14, SC)
	ItemMeshShared.add_cube(p, ox, ty + _cs(0.005, SC), oz, _cs(0.06, SC), _cs(0.02, SC), _cs(0.06, SC), gold)
	ItemMeshShared.add_cube(p, ox, ty + _cs(0.10, SC), oz, _cs(0.13, SC), _cs(0.13, SC), _cs(0.13, SC), orb)

	# Nến
	for i in range(2):
		ItemMeshShared.add_cube(p, _cs(-0.20, SC) + i * _cs(0.12, SC), ty + _cs(0.02, SC), _cs(0.24, SC), _cs(0.05, SC), _cs(0.12, SC), _cs(0.05, SC), candle)
		ItemMeshShared.add_cube(p, _cs(-0.20, SC) + i * _cs(0.12, SC), ty + _cs(0.085, SC), _cs(0.24, SC), _cs(0.02, SC), _cs(0.015, SC), _cs(0.02, SC), flame)

	# Sách phép mở
	var bx := _cs(-0.20, SC); var bz := _cs(-0.16, SC)
	ItemMeshShared.add_cube(p, bx, ty + _cs(0.005, SC), bz, _cs(0.14, SC), _cs(0.05, SC), _cs(0.10, SC), book)
	ItemMeshShared.add_cube(p, bx - _cs(0.02, SC), ty + _cs(0.018, SC), bz, _cs(0.14, SC), _cs(0.03, SC), _cs(0.10, SC), book_pg)
	ItemMeshShared.add_cube(p, bx + _cs(0.055, SC), ty + _cs(0.005, SC), bz, _cs(0.03, SC), _cs(0.05, SC), _cs(0.012, SC), book)
	ItemMeshShared.add_cube(p, bx - _cs(0.06, SC), ty + _cs(0.03, SC), bz, _cs(0.03, SC), _cs(0.008, SC), _cs(0.012, SC), rune)

	# Hộp nguyên liệu
	var hbx := _cs(-0.40, SC); var hbz := _cs(-0.28, SC)
	ItemMeshShared.add_cube(p, hbx, ty + _cs(0.005, SC), hbz, _cs(0.14, SC), _cs(0.10, SC), _cs(0.10, SC), wood_dark)
	ItemMeshShared.add_cube(p, hbx - _cs(0.03, SC), ty + _cs(0.07, SC), hbz, _cs(0.05, SC), _cs(0.05, SC), _cs(0.05, SC), crystal_b)
	ItemMeshShared.add_cube(p, hbx + _cs(0.03, SC), ty + _cs(0.08, SC), hbz, _cs(0.05, SC), _cs(0.05, SC), _cs(0.05, SC), crystal)

	# Rune tròn trên mặt
	for i in range(3):
		ItemMeshShared.add_cube(p, _cs(-0.06, SC) + i * _cs(0.05, SC), ty + _cs(0.008, SC), _cs(-0.28, SC), _cs(0.014, SC), _cs(0.003, SC), _cs(0.014, SC), rune)


# ── KITCHEN TABLE ───────────────────────────────────────────────────────────
static func kitchen_table(p: Node3D) -> void:
	const SC: float = 2.78

	var wood       := Color(0.55, 0.38, 0.20)
	var wood_dark  := Color(0.42, 0.27, 0.14)
	var top_stone  := Color(0.55, 0.54, 0.52)
	var iron       := Color(0.30, 0.30, 0.34)
	var iron_hi    := Color(0.46, 0.47, 0.52)
	var copper     := Color(0.65, 0.42, 0.22)
	var cutting    := Color(0.62, 0.45, 0.24)
	var plate      := Color(0.90, 0.90, 0.90)
	var plate_in   := Color(0.92, 0.92, 0.95)
	var bowl       := Color(0.68, 0.66, 0.62)
	var tomato     := Color(0.72, 0.22, 0.18)
	var onion      := Color(0.68, 0.40, 0.22)
	var leaf       := Color(0.18, 0.48, 0.20)
	var flour      := Color(0.92, 0.88, 0.80)
	var sack       := Color(0.62, 0.52, 0.38)

	var tw := 5.0; var td := 2.36; var th := _cs(0.05, SC)
	var ty := _cs(0.68, SC)

	ItemMeshShared.add_cube(p, 0, ty - th * 0.5, 0, tw, th, td, wood)
	ItemMeshShared.add_cube(p, 0, ty + _cs(0.005, SC), 0, tw - _cs(0.1, SC), _cs(0.015, SC), td - _cs(0.1, SC), top_stone)

	var lt := _cs(0.05, SC); var lh := ty - th
	for xv in [-tw * 0.5 + lt * 0.6, tw * 0.5 - lt * 0.6]:
		for zv in [-td * 0.5 + lt * 0.6, td * 0.5 - lt * 0.6]:
			ItemMeshShared.add_cube(p, xv, lh * 0.5, zv, lt * 0.7, lh, lt * 0.7, wood_dark)

	ItemMeshShared.add_cube(p, 0, _cs(0.18, SC), -td * 0.5 + lt * 0.6, tw - _cs(0.3, SC), _cs(0.025, SC), _cs(0.04, SC), wood_dark)
	ItemMeshShared.add_cube(p, 0, _cs(0.18, SC), td * 0.5 - lt * 0.6, tw - _cs(0.3, SC), _cs(0.025, SC), _cs(0.04, SC), wood_dark)

	# Thớt + dao
	var cxb := _cs(-0.58, SC); var czb := _cs(0.00, SC)
	ItemMeshShared.add_cube(p, cxb, ty + _cs(0.005, SC), czb, _cs(0.24, SC), _cs(0.025, SC), _cs(0.18, SC), cutting)
	ItemMeshShared.add_cube(p, cxb + _cs(0.09, SC), ty + _cs(0.018, SC), czb + _cs(0.03, SC), _cs(0.02, SC), _cs(0.025, SC), _cs(0.07, SC), iron)
	ItemMeshShared.add_cube(p, cxb + _cs(0.09, SC), ty + _cs(0.018, SC), czb + _cs(0.07, SC), _cs(0.02, SC), _cs(0.03, SC), _cs(0.02, SC), wood_dark)
	ItemMeshShared.add_cube(p, cxb + _cs(0.02, SC), ty + _cs(0.02, SC), czb, _cs(0.03, SC), _cs(0.02, SC), _cs(0.10, SC), iron_hi)

	# Cà chua + hành
	ItemMeshShared.add_cube(p, cxb - _cs(0.06, SC), ty + _cs(0.025, SC), czb + _cs(0.04, SC), _cs(0.055, SC), _cs(0.045, SC), _cs(0.055, SC), tomato)
	ItemMeshShared.add_cube(p, cxb - _cs(0.06, SC), ty + _cs(0.05, SC), czb + _cs(0.04, SC), _cs(0.04, SC), _cs(0.01, SC), _cs(0.03, SC), leaf)
	ItemMeshShared.add_cube(p, cxb - _cs(0.14, SC), ty + _cs(0.022, SC), czb + _cs(0.03, SC), _cs(0.045, SC), _cs(0.035, SC), _cs(0.045, SC), onion)

	# Nồi
	var nx := _cs(-0.20, SC); var nz := _cs(0.00, SC)
	ItemMeshShared.add_cube(p, nx, ty + _cs(0.005, SC), nz, _cs(0.20, SC), _cs(0.10, SC), _cs(0.16, SC), iron)
	ItemMeshShared.add_cube(p, nx, ty + _cs(0.07, SC), nz, _cs(0.21, SC), _cs(0.025, SC), _cs(0.17, SC), iron)
	ItemMeshShared.add_cube(p, nx, ty + _cs(0.095, SC), nz + _cs(0.05, SC), _cs(0.10, SC), _cs(0.02, SC), _cs(0.03, SC), iron_hi)

	# Chảo
	var pnx := _cs(0.16, SC); var pnz := _cs(0.00, SC)
	ItemMeshShared.add_cube(p, pnx, ty + _cs(0.005, SC), pnz, _cs(0.18, SC), _cs(0.03, SC), _cs(0.16, SC), iron_hi)
	ItemMeshShared.add_cube(p, pnx, ty + _cs(0.025, SC), pnz, _cs(0.17, SC), _cs(0.012, SC), _cs(0.15, SC), iron)
	ItemMeshShared.add_cube(p, pnx - _cs(0.08, SC), ty + _cs(0.004, SC), pnz + _cs(0.07, SC), _cs(0.03, SC), _cs(0.015, SC), _cs(0.015, SC), copper)

	# Đĩa + bát
	var dx := _cs(0.50, SC); var dz := _cs(-0.14, SC)
	ItemMeshShared.add_cube(p, dx, ty + _cs(0.005, SC), dz, _cs(0.10, SC), _cs(0.02, SC), _cs(0.10, SC), plate)
	ItemMeshShared.add_cube(p, dx, ty + _cs(0.02, SC), dz, _cs(0.07, SC), _cs(0.008, SC), _cs(0.07, SC), plate_in)
	ItemMeshShared.add_cube(p, dx + _cs(0.16, SC), ty + _cs(0.005, SC), dz + _cs(0.04, SC), _cs(0.08, SC), _cs(0.05, SC), _cs(0.08, SC), bowl)

	# Bao bột
	var bbx := _cs(0.52, SC); var bbz := _cs(0.20, SC)
	ItemMeshShared.add_cube(p, bbx, ty + _cs(0.005, SC), bbz, _cs(0.15, SC), _cs(0.14, SC), _cs(0.11, SC), sack)
	ItemMeshShared.add_cube(p, bbx, ty + _cs(0.08, SC), bbz, _cs(0.15, SC), _cs(0.03, SC), _cs(0.11, SC), flour)

	# Giá treo đồ dùng
	for s in [-1, 1]:
		var sx: float = s * _cs(0.45, SC)
		ItemMeshShared.add_cube(p, sx, ty + _cs(0.055, SC), _cs(-0.36, SC), _cs(0.24, SC), _cs(0.02, SC), _cs(0.03, SC), wood_dark)
		ItemMeshShared.add_cube(p, sx - _cs(0.05, SC), ty + _cs(0.075, SC), _cs(-0.36, SC), _cs(0.025, SC), _cs(0.012, SC), _cs(0.06, SC), iron_hi)
		ItemMeshShared.add_cube(p, sx + _cs(0.06, SC), ty + _cs(0.065, SC), _cs(-0.36, SC), _cs(0.02, SC), _cs(0.06, SC), _cs(0.02, SC), copper)


# ── ARCHITECTURE TABLE ──────────────────────────────────────────────────────────
static func architecture_table(p: Node3D) -> void:
	const SC: float = 2.9

	var wood      := Color(0.48, 0.34, 0.18)
	var wood_d    := Color(0.36, 0.24, 0.11)
	var wood_l    := Color(0.58, 0.42, 0.26)
	var metal     := Color(0.28, 0.29, 0.33)
	var metal_hi  := Color(0.50, 0.51, 0.56)
	var steel     := Color(0.34, 0.35, 0.40)
	var brass     := Color(0.60, 0.46, 0.20)
	var parchment := Color(0.92, 0.89, 0.80)
	var paper     := Color(0.88, 0.84, 0.70)
	var grid      := Color(0.30, 0.26, 0.20)
	var ink       := Color(0.12, 0.12, 0.16)
	var house_mat := Color(0.66, 0.42, 0.24)
	var roof      := Color(0.48, 0.28, 0.20)
	var window    := Color(0.48, 0.56, 0.62)

	var tw := 5.0; var td := 2.4; var th := _cs(0.12, SC)
	var ty := _cs(0.72, SC)

	# Thick 3-plank top
	ItemMeshShared.add_cube(p, 0, ty - th * 0.5, 0, tw, th, td, wood)
	for i in range(3):
		var cx := _cs(-0.68, SC) + i * _cs(0.68, SC)
		ItemMeshShared.add_cube(p, cx, ty - th * 0.5 + _cs(0.034, SC), 0, _cs(0.66, SC), _cs(th * 0.55, SC), td - _cs(0.08, SC), wood_l)
	for i in range(2):
		var sx := _cs(-0.68, SC) + i * _cs(1.36, SC)
		ItemMeshShared.add_cube(p, sx, ty - th * 0.5 + _cs(0.072, SC), 0, _cs(0.06, SC), _cs(0.038, SC), td - _cs(0.08, SC), metal)
	# gridded drafting surface
	ItemMeshShared.add_cube(p, 0, ty + _cs(0.068, SC), 0, tw - _cs(0.08, SC), _cs(0.022, SC), td - _cs(0.08, SC), grid)
	for gx in [_cs(-0.52, SC), _cs(-0.18, SC), _cs(0.16, SC), _cs(0.50, SC)]:
		ItemMeshShared.add_cube(p, gx, ty + _cs(0.076, SC), _cs(-0.06, SC), _cs(0.008, SC), _cs(0.006, SC), _cs(0.04, SC), ink)

	# Legs + apron
	var lt := _cs(0.10, SC); var lh := ty - th
	for xv in [_cs(-0.84, SC), _cs(0.84, SC)]:
		for zv in [_cs(-0.42, SC), _cs(0.42, SC)]:
			ItemMeshShared.add_cube(p, xv, lh * 0.5, zv, _cs(0.10, SC), lh, _cs(0.10, SC), wood_d)
	var arz := _cs(0.46, SC)
	ItemMeshShared.add_cube(p, 0, _cs(0.30, SC), -arz, tw - _cs(0.3, SC), _cs(0.05, SC), _cs(0.06, SC), wood_d)
	ItemMeshShared.add_cube(p, 0, _cs(0.30, SC), arz, tw - _cs(0.3, SC), _cs(0.05, SC), _cs(0.06, SC), wood_d)

	# T-square + 45° triangle + compass
	var rx := _cs(-0.66, SC); var rz := _cs(-0.18, SC)
	ItemMeshShared.add_cube(p, rx, ty + _cs(0.008, SC), _cs(-0.04, SC), _cs(0.02, SC), _cs(0.022, SC), _cs(0.82, SC), steel)
	ItemMeshShared.add_cube(p, rx, ty + _cs(0.30, SC), _cs(-0.05, SC), _cs(0.016, SC), _cs(0.62, SC), _cs(0.02, SC), steel)
	var ax := _cs(-0.52, SC)
	ItemMeshShared.add_cube(p, ax, ty + _cs(0.008, SC), _cs(-0.08, SC), _cs(0.016, SC), _cs(0.46, SC), _cs(0.016, SC), brass)
	ItemMeshShared.add_cube(p, ax, ty + _cs(0.008, SC), _cs(0.20, SC), _cs(0.016, SC), _cs(0.46, SC), _cs(0.016, SC), brass)
	ItemMeshShared.add_cube(p, ax + _cs(0.28, SC), ty + _cs(0.008, SC), _cs(-0.08, SC), _cs(0.016, SC), _cs(0.46, SC), _cs(0.016, SC), brass)
	# compass
	var cx := _cs(-0.18, SC)
	ItemMeshShared.add_cube(p, cx, ty + _cs(0.01, SC), _cs(0.06, SC), _cs(0.09, SC), _cs(0.022, SC), _cs(0.09, SC), metal_hi)
	ItemMeshShared.add_cube(p, cx, ty + _cs(0.034, SC), _cs(0.06, SC), _cs(0.018, SC), _cs(0.04, SC), _cs(0.018, SC), metal)

	# Rolled plans
	for k in range(3):
		var col := parchment if k != 1 else Color(0.60, 0.36, 0.20)
		ItemMeshShared.add_cube(p, _cs(0.0, SC) + (k - 1) * _cs(0.14, SC), ty + _cs(0.008, SC), _cs(0.24, SC), _cs(0.10, SC), _cs(0.024, SC), _cs(0.036, SC), col)

	# Mini house model (back-right)
	var mx := _cs(0.46, SC); var mz := _cs(0.22, SC); var mh := _cs(0.16, SC)
	ItemMeshShared.add_cube(p, mx, ty + _cs(0.042, SC), mz, _cs(0.26, SC), _cs(0.04, SC), _cs(0.20, SC), house_mat)
	ItemMeshShared.add_cube(p, mx, ty + _cs(0.042, SC) + mh * 0.5, mz + _cs(0.089, SC), _cs(0.26, SC), mh, _cs(0.022, SC), house_mat)
	ItemMeshShared.add_cube(p, mx, ty + _cs(0.042, SC) + mh * 0.5, mz - _cs(0.089, SC), _cs(0.022, SC), mh, _cs(0.20, SC), house_mat)
	ItemMeshShared.add_cube(p, mx, ty + _cs(0.042, SC) + mh * 0.5, mz + _cs(0.089, SC), _cs(0.022, SC), mh, _cs(0.20, SC), house_mat)
	ItemMeshShared.add_cube(p, mx, ty + mh + _cs(0.056, SC), mz, _cs(0.28, SC), _cs(0.032, SC), _cs(0.22, SC), roof)
	ItemMeshShared.add_cube(p, mx - _cs(0.072, SC), ty + _cs(0.11, SC) + mh * 0.5, mz + _cs(0.089, SC), _cs(0.048, SC), _cs(0.048, SC), _cs(0.004, SC), window)
	ItemMeshShared.add_cube(p, mx + _cs(0.072, SC), ty + _cs(0.11, SC) + mh * 0.5, mz + _cs(0.089, SC), _cs(0.048, SC), _cs(0.048, SC), _cs(0.004, SC), window)


# ── FURNACE ─────────────────────────────────────────────────────────────────
static func furnace(p: Node3D) -> void:
	const SC: float = 2.5

	var stone      := Color(0.30, 0.28, 0.26)
	var stone_dark := Color(0.20, 0.18, 0.17)
	var brick      := Color(0.40, 0.22, 0.15)
	var metal      := Color(0.22, 0.22, 0.25)
	var metal_dark := Color(0.15, 0.15, 0.18)
	var anvil_mat  := Color(0.28, 0.28, 0.32)
	var fire_glow  := Color(0.80, 0.30, 0.05)
	var fire_hot   := Color(0.95, 0.60, 0.10)
	var fire_core  := Color(1.0, 0.85, 0.30)
	var wood       := Color(0.42, 0.26, 0.14)
	var iron_ore   := Color(0.36, 0.31, 0.26)
	var copper_ore := Color(0.38, 0.29, 0.18)
	var gold_ore   := Color(0.37, 0.33, 0.29)

	var fw := 4.0; var fh := _cs(0.65, SC); var fd := _cs(0.80, SC)
	var fy := fh * 0.5

	ItemMeshShared.add_cube(p, 0, fy, 0, fw, fh, fd, stone)
	ItemMeshShared.add_cube(p, 0, fh, 0, fw + _cs(0.04, SC), _cs(0.06, SC), fd + _cs(0.04, SC), brick)
	ItemMeshShared.add_cube(p, 0, _cs(0.03, SC), 0, fw + _cs(0.04, SC), _cs(0.06, SC), fd + _cs(0.04, SC), brick)

	var arch_mat := stone_dark
	ItemMeshShared.add_cube(p, 0, fh * 0.55, fd * 0.5 + _cs(0.02, SC), _cs(0.50, SC), _cs(0.04, SC), _cs(0.04, SC), arch_mat)
	ItemMeshShared.add_cube(p, _cs(-0.26, SC), fh * 0.42, fd * 0.5 + _cs(0.02, SC), _cs(0.04, SC), _cs(0.32, SC), _cs(0.04, SC), arch_mat)
	ItemMeshShared.add_cube(p, _cs(0.26, SC), fh * 0.42, fd * 0.5 + _cs(0.02, SC), _cs(0.04, SC), _cs(0.32, SC), _cs(0.04, SC), arch_mat)

	var fz := fd * 0.5 + _cs(0.03, SC)
	ItemMeshShared.add_cube(p, 0, fh * 0.40, fz, _cs(0.38, SC), _cs(0.18, SC), _cs(0.04, SC), fire_glow)
	ItemMeshShared.add_cube(p, 0, fh * 0.45, fz, _cs(0.26, SC), _cs(0.10, SC), _cs(0.04, SC), fire_hot)
	ItemMeshShared.add_cube(p, 0, fh * 0.50, fz, _cs(0.12, SC), _cs(0.04, SC), _cs(0.04, SC), fire_core)

	var cz := -fd * 0.5 + _cs(0.10, SC)
	ItemMeshShared.add_cube(p, 0, fh + _cs(0.09, SC), cz, _cs(0.24, SC), _cs(0.18, SC), _cs(0.24, SC), stone_dark)
	ItemMeshShared.add_cube(p, 0, fh + _cs(0.21, SC), cz, _cs(0.20, SC), _cs(0.06, SC), _cs(0.20, SC), stone_dark)

	var ax := fw * 0.5 + _cs(0.08, SC); var az := _cs(0.10, SC)
	ItemMeshShared.add_cube(p, ax, _cs(0.12, SC), az, _cs(0.14, SC), _cs(0.08, SC), _cs(0.10, SC), anvil_mat)
	ItemMeshShared.add_cube(p, ax, _cs(0.19, SC), az, _cs(0.10, SC), _cs(0.06, SC), _cs(0.08, SC), anvil_mat)
	ItemMeshShared.add_cube(p, ax, _cs(0.09, SC), az, _cs(0.12, SC), _cs(0.02, SC), _cs(0.08, SC), metal)
	ItemMeshShared.add_cube(p, ax + _cs(0.03, SC), _cs(0.23, SC), az, _cs(0.04, SC), _cs(0.03, SC), _cs(0.04, SC), fire_hot)

	ItemMeshShared.add_cube(p, ax, _cs(0.32, SC), az, _cs(0.10, SC), _cs(0.02, SC), _cs(0.04, SC), wood)
	ItemMeshShared.add_cube(p, ax - _cs(0.03, SC), _cs(0.36, SC), az, _cs(0.01, SC), _cs(0.06, SC), _cs(0.01, SC), Color(0.35, 0.22, 0.08))

	var bx := -fw * 0.5 + _cs(0.15, SC); var bz2 := fd * 0.5 - _cs(0.05, SC)
	ItemMeshShared.add_cube(p, bx, _cs(0.04, SC), bz2, _cs(0.14, SC), _cs(0.08, SC), _cs(0.12, SC), metal_dark)
	ItemMeshShared.add_cube(p, bx - _cs(0.03, SC), _cs(0.09, SC), bz2 - _cs(0.02, SC), _cs(0.04, SC), _cs(0.02, SC), _cs(0.04, SC), copper_ore)
	ItemMeshShared.add_cube(p, bx + _cs(0.03, SC), _cs(0.09, SC), bz2 + _cs(0.02, SC), _cs(0.04, SC), _cs(0.02, SC), _cs(0.04, SC), iron_ore)

	ItemMeshShared.add_cube(p, -fw * 0.5 + _cs(0.40, SC), _cs(0.03, SC), -fd * 0.5 + _cs(0.06, SC), _cs(0.14, SC), _cs(0.06, SC), _cs(0.10, SC), wood)
	ItemMeshShared.add_cube(p, fw * 0.5 - _cs(0.20, SC), _cs(0.02, SC), -fd * 0.5 + _cs(0.08, SC), _cs(0.10, SC), _cs(0.04, SC), _cs(0.08, SC), wood)

	ItemMeshShared.add_cube(p, _cs(-0.10, SC), fh * 0.25, -fd * 0.5 - _cs(0.02, SC), _cs(0.40, SC), _cs(0.02, SC), _cs(0.08, SC), wood)
	ItemMeshShared.add_cube(p, _cs(-0.20, SC), fh * 0.28, -fd * 0.5 - _cs(0.02, SC), _cs(0.03, SC), _cs(0.03, SC), _cs(0.03, SC), Color(0.15, 0.40, 0.80))


# ── BẾP NẤU (Cooking Stove) ────────────────────────────────────────────────
static func cooking_stove(p: Node3D) -> void:
	const SC: float = 3.0

	var body      := Color(0.30, 0.34, 0.38)
	var body_dark := Color(0.22, 0.25, 0.28)
	var body_light:= Color(0.42, 0.46, 0.50)
	var top_mat   := Color(0.25, 0.28, 0.30)
	var glass     := Color(0.14, 0.18, 0.22)
	var knob      := Color(0.10, 0.10, 0.12)
	var pot_metal := Color(0.35, 0.38, 0.42)
	var pot_dark  := Color(0.24, 0.26, 0.28)
	var lid       := Color(0.42, 0.46, 0.50)
	var flame     := Color(0.90, 0.45, 0.10)
	var flame_core:= Color(0.95, 0.75, 0.25)
	var foot      := Color(0.18, 0.20, 0.22)
	var steam     := Color(0.85, 0.88, 0.92)

	var sw := 5.0; var sh := _cs(0.72, SC); var sd := _cs(0.95, SC)

	# Body
	ItemMeshShared.add_cube(p, 0, sh * 0.5, 0, sw, sh, sd, body)
	ItemMeshShared.add_cube(p, 0, sh * 0.52, 0, sw - _cs(0.06, SC), sh - _cs(0.06, SC), sd - _cs(0.06, SC), body_dark)
	# Top surface
	ItemMeshShared.add_cube(p, 0, sh + _cs(0.02, SC), 0, sw - _cs(0.02, SC), _cs(0.04, SC), sd - _cs(0.02, SC), top_mat)
	# Front highlight
	ItemMeshShared.add_cube(p, 0, sh * 0.62, sd * 0.5 + _cs(0.005, SC), sw - _cs(0.10, SC), _cs(0.02, SC), _cs(0.01, SC), body_light)
	# Oven door + glass
	ItemMeshShared.add_cube(p, 0, sh * 0.34, sd * 0.5 + _cs(0.01, SC), _cs(0.78, SC), _cs(0.03, SC), _cs(0.02, SC), body_light)
	ItemMeshShared.add_cube(p, 0, sh * 0.28, sd * 0.5 + _cs(0.018, SC), _cs(0.72, SC), _cs(0.32, SC), _cs(0.015, SC), glass)
	ItemMeshShared.add_cube(p, 0, sh * 0.46, sd * 0.5 + _cs(0.02, SC), _cs(0.26, SC), _cs(0.02, SC), _cs(0.02, SC), body_light)
	# Knobs
	for i in range(4):
		ItemMeshShared.add_cube(p, _cs(-0.50 + i * 0.30, SC), sh + _cs(0.03, SC), sd * 0.5 - _cs(0.06, SC), _cs(0.10, SC), _cs(0.05, SC), _cs(0.10, SC), knob)
	# Feet
	for fx in [-sw * 0.5 + _cs(0.12, SC), sw * 0.5 - _cs(0.12, SC)]:
		for fz in [-sd * 0.5 + _cs(0.12, SC), sd * 0.5 - _cs(0.12, SC)]:
			ItemMeshShared.add_cube(p, fx, _cs(0.025, SC), fz, _cs(0.12, SC), _cs(0.05, SC), _cs(0.12, SC), foot)
	# Burners
	var bw := _cs(0.40, SC); var bz := _cs(0.06, SC)
	ItemMeshShared.add_cube(p, _cs(-0.42, SC), sh + _cs(0.05, SC), bz, bw, _cs(0.035, SC), bw, top_mat.darkened(0.2))
	ItemMeshShared.add_cube(p, _cs(-0.42, SC), sh + _cs(0.068, SC), bz, bw - _cs(0.06, SC), _cs(0.015, SC), bw - _cs(0.06, SC), flame_core)
	ItemMeshShared.add_cube(p, _cs(-0.42, SC), sh + _cs(0.058, SC), bz, bw - _cs(0.16, SC), _cs(0.02, SC), bw - _cs(0.16, SC), flame)
	ItemMeshShared.add_cube(p, _cs(0.42, SC), sh + _cs(0.05, SC), bz, bw, _cs(0.035, SC), bw, top_mat.darkened(0.2))
	ItemMeshShared.add_cube(p, _cs(0.42, SC), sh + _cs(0.068, SC), bz, bw - _cs(0.06, SC), _cs(0.015, SC), bw - _cs(0.06, SC), Color(0.60, 0.62, 0.68))
	# Pot on left burner
	var poy := sh + _cs(0.10, SC)
	ItemMeshShared.add_cube(p, _cs(-0.42, SC), poy + _cs(0.10, SC), bz, _cs(0.30, SC), _cs(0.20, SC), _cs(0.30, SC), pot_metal)
	ItemMeshShared.add_cube(p, _cs(-0.42, SC), poy + _cs(0.005, SC), bz, _cs(0.32, SC), _cs(0.02, SC), _cs(0.32, SC), pot_dark)
	ItemMeshShared.add_cube(p, _cs(-0.42, SC), poy + _cs(0.21, SC), bz, _cs(0.26, SC), _cs(0.02, SC), _cs(0.26, SC), pot_dark)
	ItemMeshShared.add_cube(p, _cs(-0.42, SC), poy + _cs(0.225, SC), bz, _cs(0.30, SC), _cs(0.02, SC), _cs(0.30, SC), lid)
	ItemMeshShared.add_cube(p, _cs(-0.42, SC), poy + _cs(0.255, SC), bz, _cs(0.08, SC), _cs(0.035, SC), _cs(0.08, SC), body_dark)
	# Steam
	for i in range(3):
		var sy2: float = poy + _cs(0.34 + i * 0.05, SC)
		ItemMeshShared.add_cube(p, _cs(-0.42 + i * 0.010, SC), sy2, bz, _cs(0.10 - i * 0.02, SC), _cs(0.015, SC), _cs(0.10 - i * 0.02, SC), steam)
	# Smoke vent (back)
	var vx := _cs(0.16, SC); var vz := -sd * 0.5 + _cs(0.06, SC)
	ItemMeshShared.add_cube(p, vx, sh + _cs(0.10, SC), vz, _cs(0.16, SC), _cs(0.16, SC), _cs(0.16, SC), body_dark)
	ItemMeshShared.add_cube(p, vx, sh + _cs(0.20, SC), vz, _cs(0.20, SC), _cs(0.04, SC), _cs(0.20, SC), body_light)
	ItemMeshShared.add_cube(p, vx, sh + _cs(0.185, SC), vz, _cs(0.10, SC), _cs(0.02, SC), _cs(0.10, SC), Color(0.05, 0.05, 0.06))


# ── TWILIGHT GATE ───────────────────────────────────────────────────────────
static func gate(p: Node3D) -> void:
	var frame := Color(0.10, 0.50, 0.45)
	var glow := Color(0.20, 0.70, 0.65)
	ItemMeshShared.add_cube(p, -2, 0, 0, 1.0, 1.0, 0.5, frame)
	ItemMeshShared.add_cube(p, -2, 1, 0, 1.0, 1.0, 0.5, frame)
	ItemMeshShared.add_cube(p, -2, 2, 0, 1.0, 1.0, 0.5, frame)
	ItemMeshShared.add_cube(p, -2, 3, 0, 1.0, 1.0, 0.5, frame)
	ItemMeshShared.add_cube(p, 2, 0, 0, 1.0, 1.0, 0.5, frame)
	ItemMeshShared.add_cube(p, 2, 1, 0, 1.0, 1.0, 0.5, frame)
	ItemMeshShared.add_cube(p, 2, 2, 0, 1.0, 1.0, 0.5, frame)
	ItemMeshShared.add_cube(p, 2, 3, 0, 1.0, 1.0, 0.5, frame)
	ItemMeshShared.add_cube(p, 0, 3, 0, 1.0, 1.0, 0.5, frame)
	ItemMeshShared.add_cube(p, 0, 4, 0, 3.0, 1.0, 0.5, frame)
	ItemMeshShared.add_cube(p, 0, 1, 0, 2.0, 1.0, 0.5, glow)


# ── FISHING BOAT (mini model: cầm tay / rơi / ném) ──────────────────────────
static func fishing_boat(p: Node3D) -> void:
	var wood       := Color(0.46, 0.30, 0.15)
	var wood_dark  := Color(0.34, 0.21, 0.10)
	var wood_light := Color(0.58, 0.42, 0.24)
	var trim       := Color(0.20, 0.55, 0.45)
	var paddle     := Color(0.62, 0.48, 0.28)

	var L: float = 6.7   # ≈ 0.2 m khi cầm tay (units × V=0.03)
	var W: float = 2.8
	var H: float = 1.1

	# Thân chính
	ItemMeshShared.add_cube(p, 0, 0, 0, L, H, W, wood_dark)
	# Mũi nâng cao
	ItemMeshShared.add_cube(p, 0, H * 0.5 + 0.35, -L * 0.5 + 0.6, L * 0.55, H * 0.5, W * 0.8, wood)
	# Boong giữa
	ItemMeshShared.add_cube(p, 0, H * 0.5 + 0.05, 0.6, L * 0.75, H * 0.3, W * 0.65, wood_light)
	# Ghế lái đuôi
	ItemMeshShared.add_cube(p, 0, H * 0.5 + 0.5, L * 0.5 - 0.3, L * 0.6, H * 0.45, W * 0.7, wood_light)
	# Bánh lái
	ItemMeshShared.add_cube(p, 0, -0.15, L * 0.5 + 0.3, 0.3, H * 0.5, W * 0.4, wood_dark)
	# Viền mũi
	ItemMeshShared.add_cube(p, 0, H * 0.45, -L * 0.5 - 0.05, L * 0.15, H * 0.15, W * 0.5, trim)
	# Hai mái chèo
	ItemMeshShared.add_cube(p, W * 0.5 + 0.35, H * 0.25, -0.5, 0.12, 0.12, L * 0.7, paddle)
	ItemMeshShared.add_cube(p, -W * 0.5 - 0.35, H * 0.25, -0.5, 0.12, 0.12, L * 0.7, paddle)


# ── TRACTOR (mini model: máy kéo đỏ + rơ-moọc chở nông sản) ───────────────────
static func tractor(p: Node3D) -> void:
	var red       := Color(0.72, 0.10, 0.08)
	var red_d     := Color(0.48, 0.06, 0.05)
	var red_l     := Color(0.80, 0.20, 0.13)
	var steel     := Color(0.30, 0.31, 0.34)
	var steel_d   := Color(0.16, 0.17, 0.19)
	var tire      := Color(0.07, 0.07, 0.08)
	var cream     := Color(0.84, 0.78, 0.58)
	var wood      := Color(0.60, 0.40, 0.18)
	var wood_d    := Color(0.44, 0.29, 0.13)
	var straw     := Color(0.86, 0.74, 0.34)
	var burlap    := Color(0.66, 0.55, 0.40)
	var pump      := Color(0.88, 0.45, 0.10)

	# Khung gầm
	ItemMeshShared.add_cube(p, 0, -0.15, 0, 2.5, 0.4, 4.6, steel_d)
	# Bánh sau to (2 Bánh)
	for s in [1.0, -1.0]:
		ItemMeshShared.add_cube(p, 1.25 * s, -0.85, 1.2, 0.75, 1.7, 0.6, tire)
		ItemMeshShared.add_cube(p, 1.25 * s, -0.85, 1.2, 0.3, 0.7, 0.5, cream)
	# Bánh trước nhỏ
	for s in [1.0, -1.0]:
		ItemMeshShared.add_cube(p, 1.05 * s, -0.6, -1.7, 0.6, 1.0, 0.45, tire)
	# Nắp capo đỏ + hẻm
	ItemMeshShared.add_cube(p, 0, 0.55, -0.9, 1.9, 0.9, 1.8, red_l)
	ItemMeshShared.add_cube(p, 0, 0.85, -1.8, 1.7, 0.5, 0.2, red_d)
	ItemMeshShared.add_cube(p, 0, 0.45, -1.8, 1.6, 0.4, 0.15, steel_d)
	# Đèn pha
	ItemMeshShared.add_cube(p, 0.6, 0.7, -1.9, 0.3, 0.25, 0.12, Color(1.0, 0.88, 0.5))
	ItemMeshShared.add_cube(p, -0.6, 0.7, -1.9, 0.3, 0.25, 0.12, Color(1.0, 0.88, 0.5))
	# Ca-bin (lồng bảo vệ) + lưng đỏ
	ItemMeshShared.add_cube(p, 0, 1.35, 1.05, 1.8, 0.5, 1.1, red_d)
	ItemMeshShared.add_cube(p, 0, 1.75, 1.05, 0.3, 0.3, 1.1, steel)
	ItemMeshShared.add_cube(p, 0, 1.75, 1.05, 1.8, 0.3, 0.2, steel)
	# Ống xả
	ItemMeshShared.add_cube(p, 1.05, 1.4, 1.6, 0.18, 1.4, 0.18, steel_d)

	# ── Rơ-moọc (đuôi về +z) ──
	ItemMeshShared.add_cube(p, 0, -0.2, 3.6, 0.3, 0.4, 1.2, steel)
	# Sàn ván gỗ
	ItemMeshShared.add_cube(p, 0, 0.55, 5.1, 2.4, 0.3, 3.6, wood)
	# Vách 2 bên + trước
	for s in [1.0, -1.0]:
		ItemMeshShared.add_cube(p, 1.25 * s, 0.95, 5.1, 0.25, 0.7, 3.6, wood_d)
	ItemMeshShared.add_cube(p, 0, 0.95, 3.45, 2.5, 0.7, 0.2, wood_d)
	# Bánh rơ-moọc
	for s in [1.0, -1.0]:
		ItemMeshShared.add_cube(p, 1.15 * s, -0.5, 5.2, 0.7, 1.2, 0.55, tire)
	# Hàng hoá: bí cam + rơm + bao đay
	ItemMeshShared.add_cube(p, -0.55, 1.05, 4.6, 0.8, 0.8, 0.8, pump)
	ItemMeshShared.add_cube(p, -0.55, 1.45, 4.6, 0.65, 0.2, 0.65, Color(0.44, 0.55, 0.2))
	ItemMeshShared.add_cube(p, 0.65, 1.05, 5.4, 0.85, 0.85, 0.85, pump)
	ItemMeshShared.add_cube(p, 0.0, 1.05, 6.2, 0.8, 0.8, 0.8, pump)
	ItemMeshShared.add_cube(p, -0.5, 1.25, 6.4, 0.7, 0.5, 0.9, burlap)
	ItemMeshShared.add_cube(p, 0.55, 0.75, 4.5, 0.8, 0.3, 0.5, straw)
	ItemMeshShared.add_cube(p, -0.9, 0.75, 5.6, 0.6, 0.25, 0.4, straw)
	ItemMeshShared.add_cube(p, 0.6, 0.75, 6.0, 0.6, 0.25, 0.4, wood)


# ── RESCUE HELICOPTER (mini model: trực thăng cứu hộ đỏ-trắng) ────────────────
static func rescue_helicopter(p: Node3D) -> void:
	var red       := Color(0.78, 0.14, 0.10)
	var red_d     := Color(0.50, 0.07, 0.06)
	var white     := Color(0.93, 0.91, 0.87)
	var black     := Color(0.06, 0.06, 0.07)
	var steel     := Color(0.34, 0.35, 0.38)
	var carbon    := Color(0.10, 0.10, 0.11)
	var yellow    := Color(0.98, 0.78, 0.12)
	var glass     := Color(0.55, 0.72, 0.88)
	var glass_d   := Color(0.20, 0.30, 0.42)

	# Càng đáp (skids)
	ItemMeshShared.add_cube(p, 1.0, -0.45, 0.0, 0.16, 0.12, 3.2, black)
	ItemMeshShared.add_cube(p, -1.0, -0.45, 0.0, 0.16, 0.12, 3.2, black)
	for s in [1.0, -1.0]:
		ItemMeshShared.add_cube(p, 0.8 * s, -0.1, -1.3, 0.08, 0.6, 0.08, black)
		ItemMeshShared.add_cube(p, 0.8 * s, -0.1, 1.3, 0.08, 0.6, 0.08, black)
	# Bụng + thân chính đỏ
	ItemMeshShared.add_cube(p, 0, 0.2, 0.0, 1.8, 0.4, 3.6, red_d)
	ItemMeshShared.add_cube(p, 0, 0.55, 0.0, 2.0, 0.7, 3.7, red)
	# Thân trên + trần trắng
	ItemMeshShared.add_cube(p, 0, 1.05, 0.0, 1.8, 0.5, 3.6, red)
	ItemMeshShared.add_cube(p, 0, 1.4, 0.0, 1.4, 0.3, 3.4, white)
	# Sọc trắng hông
	for s in [1.0, -1.0]:
		ItemMeshShared.add_cube(p, 1.02 * s, 0.6, 0.0, 0.05, 0.2, 3.6, white)
	# Huy hiệu chữ thập 2 bên
	for s in [1.0, -1.0]:
		ItemMeshShared.add_cube(p, 1.04 * s, 0.8, 0.9, 0.05, 0.7, 0.7, white)
		ItemMeshShared.add_cube(p, 1.06 * s, 0.92, 0.9, 0.04, 0.14, 0.5, red)
		ItemMeshShared.add_cube(p, 1.06 * s, 0.8, 0.78, 0.04, 0.5, 0.14, red)
	# Mũi kính vòm (buồng lái 2 chỗ)
	ItemMeshShared.add_cube(p, 0, 0.75, -2.3, 1.2, 0.6, 1.0, glass)
	ItemMeshShared.add_cube(p, 0, 0.95, -2.1, 1.0, 0.45, 0.8, glass_d)
	# Khung kính đen
	ItemMeshShared.add_cube(p, 0, 0.5, -2.15, 1.3, 0.07, 1.2, black)
	ItemMeshShared.add_cube(p, 0, 1.2, -2.1, 1.1, 0.06, 0.95, black)
	# Mũi nhọn đỏ
	ItemMeshShared.add_cube(p, 0, 0.7, -2.85, 0.7, 0.5, 0.6, red)
	# Đuôi trắng thon
	ItemMeshShared.add_cube(p, 0, 0.6, 2.1, 0.6, 0.6, 2.6, white)
	ItemMeshShared.add_cube(p, 0, 0.72, 2.1, 0.65, 0.14, 2.6, red)
	# Vây đuôi đứng
	ItemMeshShared.add_cube(p, 0, 1.05, 3.0, 0.12, 0.7, 0.7, red)
	# Chóp đuôi + cánh đuôi fenestron
	ItemMeshShared.add_cube(p, 0, 0.6, 3.85, 0.5, 0.55, 0.35, red)
	ItemMeshShared.add_cube(p, 0, 0.6, 3.85, 0.75, 0.14, 0.3, carbon)
	# Trục cánh quạt + hub
	ItemMeshShared.add_cube(p, 0, 1.6, 0.0, 0.14, 0.16, 0.14, black)
	ItemMeshShared.add_cube(p, 0, 1.75, 0.0, 0.26, 0.1, 0.26, steel)
	# 4 cánh quạt đen + đầu vàng
	for i in 4:
		var ang := deg_to_rad(i * 90.0)
		ItemMeshShared.add_cube(p, sin(ang) * 1.9, 1.8, cos(ang) * 1.9, 0.2, 0.03, 3.8, carbon)
	ItemMeshShared.add_cube(p, 0, 1.8, 3.4, 0.2, 0.03, 0.6, yellow)
	# Beacon trên hub
	ItemMeshShared.add_cube(p, 0, 1.92, 0.0, 0.08, 0.12, 0.08, red)
