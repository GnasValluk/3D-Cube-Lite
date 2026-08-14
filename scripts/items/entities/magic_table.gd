class_name MagicTable
extends CraftingStation

## Bàn Phép Thuật — mặt bàn tối, tinh thể phát sáng, nến, sách phép, quả cầu ánh sáng.
func _init() -> void:
	super._init(80, "magic_table")

func _setup_mesh() -> void:
	var wood      := _m(Color(0.18, 0.11, 0.22), 0.22, 0.72)
	var wood_d    := _m(Color(0.10, 0.06, 0.14), 0.22, 0.82)
	var carve     := _m(Color(0.44, 0.19, 0.58), 0.24, 0.68)
	var crystal   := _m(Color(0.58, 0.32, 0.92), 0.40, 0.20, true)
	var crystal_b := _m(Color(0.28, 0.15, 0.48), 0.30, 0.25, true)
	var orb       := _m(Color(0.80, 0.66, 0.98), 0.55, 0.16, true)
	var candle    := _m(Color(0.90, 0.88, 0.80), 0.12, 0.78)
	var candle_w  := _m(Color(0.48, 0.34, 0.20), 0.12, 0.78)
	var flame     := _m(Color(1.0, 0.64, 0.22), 0.14, 0.40, true)
	var book      := _m(Color(0.32, 0.14, 0.32), 0.22, 0.78)
	var book_pg   := _m(Color(0.88, 0.84, 0.68), 0.12, 0.78)
	var gold      := _m(Color(.78, 0.62, 0.26), 0.62, 0.40)
	var rune      := _m(Color(0.88, 0.48, 0.98), 0.30, 0.60, true)
	var glow_aura := _m(Color(0.50, 0.26, 0.72), 0.10, 0.65, true)

	var tw := 2.00; var td := 1.00; var th := 0.14; var ty := 0.74
	var top_y := ty - th * 0.5

	# ---- Thick rune-carved dark top ----
	_box(self, Vector3(tw, th, td), Vector3(0, top_y, 0), wood_d)
	_box(self, Vector3(tw - 0.05, th * 0.6, td - 0.05), Vector3(0, top_y + th * 0.28, 0), carve)
	for i in range(4):
		var ax := -0.08 + i * 0.056
		_box(self, Vector3(0.018, 0.003, 0.018), Vector3(ax, top_y + th * 0.86, 0.054), rune)
		_box(self, Vector3(0.018, 0.003, 0.018), Vector3(ax, top_y + th * 0.86, 0.0), rune)

	# ---- Chunky legs + base platform ----
	var lt := 0.10; var lh := ty - th
	for x in [-tw * 0.42, tw * 0.42]:
		for z in [-td * 0.42, td * 0.42]:
			_box(self, Vector3(lt, lh, lt), Vector3(x, lh * 0.5, z), wood_d)
			_box(self, Vector3(lt * 1.2, 0.06, lt * 1.2), Vector3(x, 0.03, z), wood_d)
	# stone-ish base ring
	_box(self, Vector3(tw - 0.2, 0.06, td - 0.2), Vector3(0, 0.30, 0), carve)

	# ---- Glowing crystal cluster (left) ----
	var cx := -0.58; var cz := 0.12
	_box(self, Vector3(0.07, 0.07, 0.07), Vector3(cx, top_y + 0.03, cz), gold)
	_box(self, Vector3(0.18, 0.18, 0.14), Vector3(cx, top_y + 0.10, cz), crystal)
	_box(self, Vector3(0.17, 0.15, 0.10), Vector3(cx + 0.035, top_y + 0.18, cz + 0.022), crystal_b)
	_box(self, Vector3(0.07, 0.07, 0.06), Vector3(cx - 0.11, top_y + 0.24, cz), crystal)
	# glow particles (soft cubes)
	_box(self, Vector3(0.22, 0.06, 0.16), Vector3(cx, top_y + 0.16, cz), glow_aura)

	# ---- Floating orb (right) ----
	var ox := 0.56; var oz := 0.12
	_box(self, Vector3(0.07, 0.07, 0.07), Vector3(ox, top_y + 0.03, oz), gold)
	_box(self, Vector3(0.14, 0.14, 0.14), Vector3(ox, top_y + 0.11, oz), orb)
	_box(self, Vector3(0.10, 0.10, 0.09), Vector3(ox + 0.04, top_y + 0.18, oz + 0.02), crystal)
	_box(self, Vector3(0.07, 0.06, 0.07), Vector3(ox, top_y + 0.195, oz), glow_aura)

	# ---- Candles (2 on each side) ----
	for side in [-1, 1]:
		for i in range(2):
			var nx: float = side * (0.24 + i * 0.13)
			var nz: float = side * 0.20
			_box(self, Vector3(0.05, 0.13, 0.05), Vector3(nx, top_y + 0.022, nz), candle_w)
			_box(self, Vector3(0.045, 0.05, 0.045), Vector3(nx, top_y + 0.078, nz), candle)
			_box(self, Vector3(0.02, 0.014, 0.02), Vector3(nx, top_y + 0.13, nz), flame)

	# ---- Open spellbook (center) ----
	var bx := -0.14; var bz := -0.14
	_box(self, Vector3(0.16, 0.024, 0.11), Vector3(bx - 0.022, top_y + 0.008, bz), book_pg)
	_box(self, Vector3(0.17, 0.05, 0.11), Vector3(bx - 0.022, top_y + 0.002, bz), book)
	_box(self, Vector3(0.024, 0.05, 0.014), Vector3(bx + 0.06, top_y + 0.002, bz), book)
	_box(self, Vector3(0.034, 0.008, 0.014), Vector3(bx - 0.068, top_y + 0.024, bz), rune)

	# ---- Standing book (right front) ----
	var sx := 0.22; var sz := -0.24
	_box(self, Vector3(0.04, 0.13, 0.11), Vector3(sx, top_y + 0.008, sz), book)
	_box(self, Vector3(0.04, 0.032, 0.11), Vector3(sx, top_y + 0.074, sz), book_pg)
	_box(self, Vector3(0.045, 0.024, 0.11), Vector3(sx, top_y + 0.11, sz), gold)

	# ---- Magical material storage box ----
	var hbx := -0.46; var hbz := -0.26
	_box(self, Vector3(0.16, 0.11, 0.11), Vector3(hbx, top_y + 0.01, hbz), wood_d)
	_box(self, Vector3(0.15, 0.024, 0.10), Vector3(hbx, top_y + 0.082, hbz), carve)
	_box(self, Vector3(0.055, 0.055, 0.055), Vector3(hbx - 0.034, top_y + 0.045, hbz), crystal_b)
	_box(self, Vector3(0.055, 0.058, 0.055), Vector3(hbx + 0.034, top_y + 0.05, hbz), crystal)

	# ---- Rune circle on top ----
	for i in range(6):
		var ang := deg_to_rad(i * 60.0)
		_box(self, Vector3(0.018, 0.003, 0.018),
			Vector3(sin(ang) * 0.30, top_y + th * 0.90, cos(ang) * 0.30), rune)

	# ---- Collision ----
	var col := CollisionShape3D.new()
	var box_col := BoxShape3D.new()
	box_col.size = Vector3(2.3, 0.86, 1.2)
	col.shape = box_col
	col.position = Vector3(0, 0.40, 0)
	add_child(col)
