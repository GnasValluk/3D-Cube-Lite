class_name ToolTable
extends CraftingStation

## Bàn Công Cụ — dụng cụ treo tường, đe, kẹp gỗ, thước, rìu/xẻng...
func _init() -> void:
	super._init(60, "tool_table")

func _setup_mesh() -> void:
	var wood       := _m(Color(0.48, 0.30, 0.15), 0.05, 0.82)
	var wood2      := _m(Color(0.56, 0.38, 0.21), 0.05, 0.76)
	var wood_d     := _m(Color(0.36, 0.22, 0.10), 0.05, 0.90)
	var metal      := _m(Color(0.25, 0.26, 0.30), 0.48, 0.48)
	var metal_b    := _m(Color(0.48, 0.48, 0.55), 0.70, 0.32)
	var steel      := _m(Color(0.32, 0.33, 0.37), 0.55, 0.42)
	var handle     := _m(Color(0.54, 0.38, 0.20), 0.05, 0.72)
	var rust       := _m(Color(0.46, 0.30, 0.22), 0.45, 0.65)

	var tw := 2.00; var td := 1.00; var th := 0.12; var ty := 0.68
	var top_y := ty - th * 0.5

	# ---- Thick 3-plank weathered-pine top ----
	_box(self, Vector3(tw, th, td), Vector3(0, top_y, 0), wood)
	for i in range(3):
		var cx := -0.62 + i * 0.62
		_box(self, Vector3(0.62, th * 0.55, td - 0.08), Vector3(cx, top_y + th * 0.28, 0), wood2)
	for i in range(2):
		var sx := -0.62 + i * 1.24
		_box(self, Vector3(th * 0.5, th * 0.32, td - 0.08), Vector3(sx, top_y + th * 0.60, 0), metal)

	# ---- Chunky legs + apron rails ----
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

	# ---- Bench clamp (right back corner) ----
	var cx := 0.58; var cz := -0.12
	_box(self, Vector3(0.28, 0.03, 0.04), Vector3(cx, top_y + 0.01, cz), steel)
	_box(self, Vector3(0.06, 0.16, 0.04), Vector3(cx, top_y + 0.09, cz), metal_b)
	_box(self, Vector3(0.03, 0.06, 0.04), Vector3(cx + 0.07, top_y + 0.12, cz), metal)

	# ---- Mini anvil (left front) ----
	var ax := -0.70; var az := -0.16
	_box(self, Vector3(0.16, 0.07, 0.10), Vector3(ax, top_y + 0.06, az), steel)
	_box(self, Vector3(0.10, 0.05, 0.07), Vector3(ax, top_y + 0.13, az), metal_b)
	_box(self, Vector3(0.13, 0.024, 0.09), Vector3(ax, top_y + 0.05, az), metal)
	_box(self, Vector3(0.07, 0.024, 0.03), Vector3(ax - 0.08, top_y + 0.11, az), steel)

	# ---- Hand-forged hammer on left ----
	_box(self, Vector3(0.026, 0.06, 0.026), Vector3(ax - 0.16, top_y + 0.11, az + 0.04), metal_b)
	_box(self, Vector3(0.04, 0.02, 0.04), Vector3(ax - 0.16, top_y + 0.07, az + 0.04), steel)
	_box(self, Vector3(0.026, 0.12, 0.026), Vector3(ax - 0.16, top_y + 0.015, az + 0.04), handle)

	# ---- Tool rack (left side) ----
	var rx := -0.44; var rz := -0.32
	_box(self, Vector3(0.62, 0.026, 0.04), Vector3(rx, top_y + 0.05, rz), wood_d)
	for i in range(2):
		var hx := rx - 0.20 + i * 0.40
		_box(self, Vector3(0.026, 0.30, 0.026), Vector3(hx, top_y + 0.05, rz - 0.024), metal)
		# blade tip + pommel
		_box(self, Vector3(0.026, 0.17, 0.016), Vector3(hx, top_y + 0.20, rz - 0.024), metal_b)
		_box(self, Vector3(0.034, 0.03, 0.034), Vector3(hx, top_y + 0.38, rz - 0.024), handle)

	# ---- Saw on rack ----
	_box(self, Vector3(0.32, 0.022, 0.022), Vector3(rx + 0.22, top_y + 0.22, rz), metal_b)

	# ---- Tool chest under table ----
	var ub_y := ty - th - 0.07
	_box(self, Vector3(0.36, 0.07, 0.22), Vector3(0.55, ub_y, -0.02), wood_d)
	_box(self, Vector3(0.37, 0.024, 0.23), Vector3(0.55, ub_y + 0.044, -0.02), metal_b)
	for k in range(3):
		_box(self, Vector3(0.026, 0.024, 0.022), Vector3(0.55, ub_y + 0.058, -0.06 + k * 0.03), rust)

	# ---- Scattered wood shavings + nails ----
	_box(self, Vector3(0.06, 0.018, 0.034), Vector3(-0.28, top_y + 0.006, 0.18), wood2)
	_box(self, Vector3(0.05, 0.022, 0.022), Vector3(-0.20, top_y + 0.008, 0.15), wood_d)
	for n in range(5):
		_box(self, Vector3(0.014, 0.014, 0.014), Vector3(-0.44 + n * 0.03, top_y + 0.004, 0.12), rust)

	# ---- Collision ----
	var col := CollisionShape3D.new()
	var box_col := BoxShape3D.new()
	box_col.size = Vector3(2.2, 0.75, 1.2)
	col.shape = box_col
	col.position = Vector3(0, 0.38, 0)
	add_child(col)
