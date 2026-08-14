class_name MechTable
extends CraftingStation

## Bàn Cơ Khí — thân kim loại, bánh răng, pít-tông, van, cờ lê, động cơ mini.
func _init() -> void:
	super._init(80, "mech_table")

func _setup_mesh() -> void:
	var steel      := _m(Color(0.34, 0.36, 0.42), 0.58, 0.40)
	var steel_hi   := _m(Color(0.58, 0.59, 0.65), 0.72, 0.30)
	var steel_dark := _m(Color(0.18, 0.19, 0.25), 0.55, 0.50)
	var copper     := _m(Color(0.74, 0.46, 0.21), 0.70, 0.30)
	var copper_hi  := _m(Color(0.84, 0.56, 0.26), 0.78, 0.28)
	var brass      := _m(Color(0.58, 0.44, 0.18), 0.68, 0.40)
	var rust       := _m(Color(0.46, 0.30, 0.22), 0.45, 0.62)
	var oil_dark   := _m(Color(0.18, 0.16, 0.14), 0.30, 0.70, true)

	var tw := 2.00; var td := 1.00; var th := 0.14; var ty := 0.74
	var top_y := ty - th * 0.5

	# ---- Thick steel top (ridged) ----
	_box(self, Vector3(tw, th, td), Vector3(0, top_y, 0), steel_dark)
	_box(self, Vector3(tw - 0.04, th * 0.45, td - 0.04), Vector3(0, top_y + th * 0.30, 0), steel)
	for i in range(3):
		var cx := -0.62 + i * 0.62
		_box(self, Vector3(0.62, th * 0.18, td - 0.06), Vector3(cx, top_y - th * 0.42, 0), steel_hi)

	# ---- Chunky legs (hollow pipes) + base rails ----
	var lt := 0.10; var lh := ty - th
	for x in [-tw * 0.42, tw * 0.42]:
		for z in [-td * 0.42, td * 0.42]:
			_box(self, Vector3(lt, lh, lt), Vector3(x, lh * 0.5, z), steel_dark)
			_box(self, Vector3(lt * 1.2, 0.06, lt * 1.2), Vector3(x, 0.03, z), steel_dark)
	# Base cross-members
	for gx in [-tw * 0.18, 0.0, tw * 0.18]:
		_box(self, Vector3(0.06, 0.04, td - 0.3), Vector3(gx, 0.34, 0), steel)
	for gz in [-td * 0.36, td * 0.36]:
		_box(self, Vector3(tw - 0.3, 0.04, 0.06), Vector3(0, 0.52, gz), steel_dark)

	# ---- Large gear + handwheel (center-left) ----
	var gx := -0.56; var gz := 0.08
	_box(self, Vector3(0.30, 0.055, 0.07), Vector3(gx, top_y + 0.05, gz), steel_hi)
	_box(self, Vector3(0.22, 0.045, 0.045), Vector3(gx, top_y + 0.05, gz), steel_dark)
	# gear teeth
	for i in range(8):
		var ang := deg_to_rad(i * 45.0)
		_box(self, Vector3(0.034, 0.04, 0.016),
			Vector3(gx + sin(ang) * 0.18, top_y + 0.05, gz + cos(ang) * 0.18), steel_hi)

	# ---- Piston (right) ----
	var px := 0.34; var pz := 0.20
	_box(self, Vector3(0.10, 0.11, 0.08), Vector3(px, top_y + 0.02, pz), steel)
	_box(self, Vector3(0.05, 0.17, 0.05), Vector3(px, top_y + 0.12, pz), steel_hi)
	_box(self, Vector3(0.06, 0.03, 0.06), Vector3(px, top_y + 0.20, pz), copper)

	# ---- Engine block (front-right) ----
	var ex := 0.66; var ez := 0.10
	_box(self, Vector3(0.22, 0.13, 0.15), Vector3(ex, top_y + 0.02, ez), steel_dark)
	_box(self, Vector3(0.12, 0.045, 0.045), Vector3(ex, top_y + 0.10, ez), copper)
	_box(self, Vector3(0.065, 0.03, 0.05), Vector3(ex - 0.08, top_y + 0.09, ez), copper)
	# cooling fins
	for f in range(4):
		_box(self, Vector3(0.08, 0.012, 0.15), Vector3(ex - 0.10, top_y + 0.04 + f * 0.024, ez), steel_hi)

	# ---- Valve / pipe coupling (back) ----
	var vx := 0.24; var vz := -0.22
	_box(self, Vector3(0.08, 0.06, 0.08), Vector3(vx, top_y + 0.03, vz), copper)
	_box(self, Vector3(0.038, 0.026, 0.038), Vector3(vx, top_y + 0.08, vz), steel_hi)
	_box(self, Vector3(0.024, 0.07, 0.024), Vector3(vx + 0.06, top_y + 0.06, vz), steel)

	# ---- Wrench + socket tray (front-left) ----
	_box(self, Vector3(0.024, 0.055, 0.034), Vector3(-0.60, top_y + 0.04, -0.20), brass)
	_box(self, Vector3(0.032, 0.022, 0.026), Vector3(-0.60, top_y + 0.07, -0.20), steel_hi)

	# ---- Spilled oil + scattered parts ----
	_box(self, Vector3(0.08, 0.014, 0.05), Vector3(0.12, top_y + 0.006, 0.26), oil_dark)
	_box(self, Vector3(0.018, 0.018, 0.024), Vector3(-0.44, top_y + 0.006, -0.26), copper)
	_box(self, Vector3(0.016, 0.016, 0.016), Vector3(-0.36, top_y + 0.006, -0.24), rust)

	# ---- Tool bin under table (right) ----
	var ub_y := ty - th - 0.07
	_box(self, Vector3(0.34, 0.09, 0.24), Vector3(0.58, ub_y, 0.02), steel_dark)
	_box(self, Vector3(0.35, 0.024, 0.25), Vector3(0.58, ub_y + 0.05, 0.02), steel_hi)
	_box(self, Vector3(0.10, 0.018, 0.05), Vector3(0.58, ub_y + 0.066, 0.06), copper)

	# ---- Collision ----
	var col := CollisionShape3D.new()
	var box_col := BoxShape3D.new()
	box_col.size = Vector3(2.3, 0.85, 1.2)
	col.shape = box_col
	col.position = Vector3(0, 0.40, 0)
	add_child(col)
