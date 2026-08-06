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
