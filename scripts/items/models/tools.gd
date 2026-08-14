class_name ToolsMesh

# ── Held weapon builders (full scale, for player hand) ──
static func build_held(pivot: Node3D, item_id: String) -> void:
	if pivot == null: return
	for ch in pivot.get_children(): ch.queue_free()
	if item_id.is_empty(): return
	match item_id:
		"pickaxe":     _build_cup(pivot)
		"shovel":    _build_xeng(pivot)
		"axe":     _build_riu(pivot)
		"hoe":     _build_cuoc(pivot)
		"iron_sword":    _build_kiem(pivot)
		"fishing_rod": _build_can_cau(pivot)
		"iron_greatsword": _build_dai_kiem(pivot)
		"iron_halberd": _build_iron_halberd(pivot)
		"leather_gloves": _build_gang_tay(pivot)
		"crossbow": _build_no(pivot)
		"watermelon_cannon": _build_phao_dua_hau(pivot)
		"arrow": _build_mui_ten(pivot)
		"watermelon_nuke_ammo": _build_dan_hat_nhan_dua_hau(pivot)
		"pumpkin_mortar": _build_phao_coi(pivot)
		"flashlight": _build_den_pin(pivot)

static func _mat(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 0.85
	m.metallic_specular = 0.1
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m

static func _box(p: Node3D, pos: Vector3, sz: Vector3, mat: StandardMaterial3D) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = sz; mi.mesh = bm
	mi.position = pos; mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.add_child(mi)

static func _cyl(p: Node3D, pos: Vector3, r: float, h: float, mat: StandardMaterial3D) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new(); cm.top_radius = r; cm.bottom_radius = r; cm.height = h; cm.radial_segments = 8
	mi.mesh = cm; mi.position = pos; mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.add_child(mi)

static func _build_cup(p: Node3D) -> void:
	var wood := _mat(Color(0.52, 0.30, 0.10))
	var wood_d := _mat(Color(0.38, 0.22, 0.07))
	var iron := _mat(Color(0.60, 0.60, 0.66))
	var iron_d := _mat(Color(0.38, 0.38, 0.44))
	var iron_l := _mat(Color(0.72, 0.72, 0.78))
	var wrap := _mat(Color(0.42, 0.28, 0.12))
	# Handle — longer, with grip wrap at bottom
	_cyl(p, Vector3(0, 0.16, 0), 0.035, 0.32, wood)
	_cyl(p, Vector3(0, 0.06, 0), 0.040, 0.08, wood_d)
	_box(p, Vector3(0, 0.04, 0), Vector3(0.005, 0.04, 0.005), wrap)
	# Iron ferrule — ring connecting handle to head
	_cyl(p, Vector3(0, 0.32, 0), 0.045, 0.04, iron_d)
	_box(p, Vector3(0, 0.34, 0), Vector3(0.06, 0.03, 0.06), iron)
	# Main head bar (crossbar) — centered on X
	_box(p, Vector3(0.00, 0.38, 0.00), Vector3(0.07, 0.06, 0.28), iron)
	_box(p, Vector3(0.00, 0.38, 0.00), Vector3(0.09, 0.04, 0.30), iron_d)
	# Left prong — centered, extends in +Z
	_box(p, Vector3(0.00, 0.34, 0.12), Vector3(0.05, 0.12, 0.06), iron)
	_box(p, Vector3(0.00, 0.36, 0.16), Vector3(0.04, 0.10, 0.05), iron_d)
	_box(p, Vector3(0.00, 0.32, 0.10), Vector3(0.06, 0.06, 0.04), iron_d)
	# Right prong — centered, extends in -Z
	_box(p, Vector3(0.00, 0.34, -0.12), Vector3(0.05, 0.12, 0.06), iron)
	_box(p, Vector3(0.00, 0.36, -0.16), Vector3(0.04, 0.10, 0.05), iron_d)
	_box(p, Vector3(0.00, 0.32, -0.10), Vector3(0.06, 0.06, 0.04), iron_d)
	# Center tip (point) — centered
	_box(p, Vector3(0.00, 0.38, 0.00), Vector3(0.05, 0.06, 0.06), iron_l)
	# Prong tips — lighter metal
	_box(p, Vector3(0.00, 0.38, 0.18), Vector3(0.03, 0.06, 0.03), iron_l)
	_box(p, Vector3(0.00, 0.38, -0.18), Vector3(0.03, 0.06, 0.03), iron_l)

static func _build_xeng(p: Node3D) -> void:
	var wood := _mat(Color(0.55, 0.32, 0.10))
	var iron := _mat(Color(0.60, 0.60, 0.66))
	var iron_d := _mat(Color(0.40, 0.40, 0.46))
	_cyl(p, Vector3(0, 0.18, 0), 0.04, 0.36, wood)
	_box(p, Vector3(0, 0.44, 0), Vector3(0.025, 0.30, 0.24), iron)
	_box(p, Vector3(0, 0.30, 0), Vector3(0.030, 0.035, 0.28), iron_d)
	_box(p, Vector3(0, 0.37, 0), Vector3(0.05, 0.10, 0.07), iron)

## ── Cuốc Sắt (Iron Hoe) — cán gỗ + lưỡi bản ngang ───────────────────────────
static func _build_cuoc(p: Node3D) -> void:
	var wood := _mat(Color(0.55, 0.32, 0.10))
	var iron := _mat(Color(0.60, 0.60, 0.66))
	var iron_d := _mat(Color(0.40, 0.40, 0.46))
	var edge := _mat(Color(0.78, 0.80, 0.86))
	# Cán gỗ
	_cyl(p, Vector3(0, 0.16, 0), 0.040, 0.34, wood)
	_cyl(p, Vector3(0, 0.06, 0), 0.045, 0.08, iron_d)
	# Đai nối cán với lưỡi
	_cyl(p, Vector3(0, 0.33, 0), 0.048, 0.05, iron)
	# Lưỡi cuốc — bản ngang vuông góc cán
	_box(p, Vector3(0, 0.38, 0), Vector3(0.07, 0.05, 0.30), iron)
	_box(p, Vector3(0, 0.36, 0), Vector3(0.05, 0.05, 0.32), iron_d)
	# Cạnh cắt (dưới cùng)
	_box(p, Vector3(0, 0.33, 0), Vector3(0.03, 0.05, 0.34), edge)

static func _build_riu(p: Node3D) -> void:
	var wood := _mat(Color(0.48, 0.28, 0.08))
	var iron := _mat(Color(0.58, 0.58, 0.62))
	var edge := _mat(Color(0.80, 0.82, 0.88))
	_cyl(p, Vector3(0, 0.15, 0), 0.05, 0.30, wood)
	_box(p, Vector3(0, 0.36, 0.08), Vector3(0.09, 0.20, 0.18), iron)
	_box(p, Vector3(0, 0.37, 0.16), Vector3(0.07, 0.18, 0.10), iron)
	_box(p, Vector3(0, 0.37, 0.24), Vector3(0.035, 0.26, 0.07), edge)
	_box(p, Vector3(0, 0.37, -0.07), Vector3(0.05, 0.09, 0.05), iron)
	_box(p, Vector3(0, 0.32, 0), Vector3(0.07, 0.10, 0.07), iron)

static func _build_kiem(p: Node3D) -> void:
	var grip := _mat(Color(0.28, 0.16, 0.08))
	var guard := _mat(Color(0.75, 0.62, 0.18))
	var blade := _mat(Color(0.82, 0.84, 0.90))
	var edge := _mat(Color(0.96, 0.98, 1.00))
	var fuller := _mat(Color(0.68, 0.70, 0.78))
	_cyl(p, Vector3(0, 0.06, 0), 0.045, 0.12, grip)
	_box(p, Vector3(0, 0.13, 0), Vector3(0.045, 0.045, 0.32), guard)
	_box(p, Vector3(0, 0.34, 0), Vector3(0.022, 0.42, 0.048), blade)
	_box(p, Vector3(0, 0.34, 0.020), Vector3(0.013, 0.40, 0.009), edge)
	_box(p, Vector3(0, 0.34, -0.020), Vector3(0.013, 0.40, 0.009), edge)
	_box(p, Vector3(0, 0.54, 0), Vector3(0.018, 0.10, 0.030), edge)
	_box(p, Vector3(0, 0.32, 0), Vector3(0.026, 0.36, 0.011), fuller)

static func _build_can_cau(p: Node3D) -> void:
	var wood := _mat(Color(0.50, 0.35, 0.15))
	var bark := _mat(Color(0.42, 0.28, 0.10))
	var tip := _mat(Color(0.75, 0.70, 0.60))
	var line := _mat(Color(0.50, 0.50, 0.55))
	_cyl(p, Vector3(0, 0.10, 0), 0.040, 0.20, wood)
	_cyl(p, Vector3(0, 0.22, 0), 0.030, 0.14, bark)
	_cyl(p, Vector3(0, 0.32, 0), 0.020, 0.16, bark)
	_cyl(p, Vector3(0, 0.44, 0), 0.012, 0.12, bark)
	_cyl(p, Vector3(0, 0.52, 0), 0.005, 0.06, tip)
	_box(p, Vector3(0, 0.52, 0.020), Vector3(0.002, 0.02, 0.04), line)

# ── Dropped / display weapon builders (voxel scale) ──
static func sword_drop(p: Node3D) -> void:
	var blade := Color(0.75, 0.80, 0.90)
	var handle := Color(0.40, 0.25, 0.15)
	var guard := Color(0.70, 0.65, 0.50)
	ItemMeshShared.add_cube(p, 0, -2, 0, 0.8, 2.0, 0.8, handle)
	ItemMeshShared.add_cube(p, 0, 1, 0, 2.5, 0.5, 0.5, guard)
	ItemMeshShared.add_cube(p, 0, 3, 0, 1.0, 3.0, 0.6, blade)
	ItemMeshShared.add_cube(p, 0, 5, 0, 0.4, 1.5, 0.4, blade.lightened(0.15))

static func cup_drop(p: Node3D) -> void:
	var wood := Color(0.52, 0.30, 0.10)
	var iron := Color(0.60, 0.60, 0.66)
	var iron_d := Color(0.40, 0.40, 0.46)
	ItemMeshShared.add_cube(p, 0, -1, 0, 1.0, 2.0, 1.0, wood)
	ItemMeshShared.add_cube(p, 0, 1, 0, 2.0, 0.8, 2.5, iron)
	ItemMeshShared.add_cube(p, 0, 2, 0, 2.0, 1.2, 2.0, iron_d)
	ItemMeshShared.add_cube(p, 1, 1, 1, 1.2, 1.5, 0.8, iron)
	ItemMeshShared.add_cube(p, 1, 1, -1, 1.2, 1.5, 0.8, iron)
	ItemMeshShared.add_cube(p, 1, 2, 1.5, 1.0, 1.0, 0.6, iron.lightened(0.1))
	ItemMeshShared.add_cube(p, 1, 2, -1.5, 1.0, 1.0, 0.6, iron.lightened(0.1))

static func shovel_drop(p: Node3D) -> void:
	var handle := Color(0.55, 0.40, 0.25)
	var blade := Color(0.50, 0.50, 0.50)
	ItemMeshShared.add_cube(p, 0, -2, 0, 1.0, 2.5, 1.0, handle)
	ItemMeshShared.add_cube(p, 0, 1, 0, 2.5, 1.5, 1.2, blade)
	ItemMeshShared.add_cube(p, 0, 3, 0, 2.0, 0.5, 1.5, blade.darkened(0.15))

static func hoe_drop(p: Node3D) -> void:
	var handle := Color(0.55, 0.40, 0.25)
	var blade := Color(0.50, 0.50, 0.50)
	var edge := Color(0.70, 0.72, 0.78)
	ItemMeshShared.add_cube(p, 0, -2, 0, 1.0, 2.5, 1.0, handle)
	ItemMeshShared.add_cube(p, 0, 1, 0, 3.0, 1.2, 1.0, blade)
	ItemMeshShared.add_cube(p, 0, 0, 0, 3.2, 1.0, 1.2, blade.darkened(0.15))
	ItemMeshShared.add_cube(p, 0, -1, 0, 2.8, 0.6, 1.4, edge)

static func axe_drop(p: Node3D) -> void:
	var handle := Color(0.50, 0.35, 0.20)
	var head := Color(0.45, 0.45, 0.45)
	ItemMeshShared.add_cube(p, 0, -2, 0, 1.0, 2.5, 1.0, handle)
	ItemMeshShared.add_cube(p, 0, 2, 0, 2.5, 1.5, 1.0, head)
	ItemMeshShared.add_cube(p, -1, 2, 0, 1.0, 1.0, 1.8, head.lightened(0.1))

static func fishing_rod_drop(p: Node3D) -> void:
	var handle := Color(0.55, 0.40, 0.25)
	var pole := Color(0.65, 0.52, 0.35)
	ItemMeshShared.add_cube(p, 0, 0, 0, 1.5, 1.0, 1.5, handle)
	ItemMeshShared.add_cube(p, 0, 1, 0, 0.8, 1.5, 0.8, handle)
	ItemMeshShared.add_cube(p, 0, 3, 0, 0.5, 2.5, 0.5, pole)
	ItemMeshShared.add_cube(p, 0, 5, 0, 0.3, 1.5, 0.3, pole.lightened(0.1))

# ── Đại Kiếm (Greatsword) — phong cách trung cổ châu Âu ──────────────────────
static func _build_dai_kiem(p: Node3D) -> void:
	var grip := _mat(Color(0.18, 0.10, 0.05))
	var wrap := _mat(Color(0.30, 0.17, 0.09))
	var guard := _mat(Color(0.65, 0.52, 0.14))
	var guard_dark := _mat(Color(0.42, 0.32, 0.08))
	var blade := _mat(Color(0.62, 0.65, 0.75))
	var edge := _mat(Color(0.82, 0.85, 0.92))
	var dark := _mat(Color(0.30, 0.32, 0.38))
	var pommel := _mat(Color(0.48, 0.38, 0.22))
	var fuller := _mat(Color(0.48, 0.50, 0.58))

	# ── Pommel (nắm chuôi hình bánh xe) ──────────────────────────────────
	_cyl(p, Vector3(0, -0.10, 0), 0.070, 0.030, pommel)
	_cyl(p, Vector3(0, -0.10, 0), 0.030, 0.035, guard)

	# ── Chuôi dài 2 tay (bọc da) ─────────────────────────────────────────
	_cyl(p, Vector3(0, 0.04, 0), 0.050, 0.26, grip)
	# Đai quấn da — 6 khoanh
	for i in range(6):
		_cyl(p, Vector3(0, -0.09 + i * 0.042, 0), 0.054, 0.010, wrap)

	# ── Cán chữ thập (crossguard) — rộng, quillon cong xuống ─────────────
	# Thanh chính
	_box(p, Vector3(0, 0.18, 0), Vector3(0.070, 0.035, 0.40), guard)
	_box(p, Vector3(0, 0.18, 0), Vector3(0.40, 0.035, 0.070), guard)
	# Khối trung tâm
	_box(p, Vector3(0, 0.18, 0), Vector3(0.090, 0.050, 0.090), guard_dark)
	# Đầu quillon trái — cong xuống
	_box(p, Vector3(-0.17, 0.16, 0), Vector3(0.050, 0.025, 0.065), guard_dark)
	_box(p, Vector3(-0.21, 0.13, 0), Vector3(0.035, 0.035, 0.055), guard)
	# Đầu quillon phải
	_box(p, Vector3(0.17, 0.16, 0), Vector3(0.050, 0.025, 0.065), guard_dark)
	_box(p, Vector3(0.21, 0.13, 0), Vector3(0.035, 0.035, 0.055), guard)

	# ── Ricasso (phần lưỡi không mài) ────────────────────────────────────
	_box(p, Vector3(0, 0.25, 0), Vector3(0.045, 0.10, 0.085), dark)
	# Móc đỡ phụ (parrying hook)
	_box(p, Vector3(0, 0.27, 0.080), Vector3(0.055, 0.025, 0.025), guard_dark)

	# ── Lưỡi chính (rộng, thon dần, dài) ─────────────────────────────────
	# Đoạn gốc — rộng nhất
	_box(p, Vector3(0, 0.36, 0), Vector3(0.048, 0.16, 0.095), blade)
	# Đoạn giữa
	_box(p, Vector3(0, 0.52, 0), Vector3(0.042, 0.24, 0.082), blade)
	# Đoạn trên
	_box(p, Vector3(0, 0.70, 0), Vector3(0.036, 0.24, 0.060), blade)
	# Gần mũi
	_box(p, Vector3(0, 0.85, 0), Vector3(0.028, 0.16, 0.040), blade)
	# Mũi nhọn
	_box(p, Vector3(0, 0.96, 0), Vector3(0.016, 0.08, 0.024), edge)
	_box(p, Vector3(0, 1.02, 0), Vector3(0.006, 0.04, 0.010), edge)

	# ── Cạnh sắc (edge bevels) hai bên ───────────────────────────────────
	_box(p, Vector3(0, 0.38, 0.044), Vector3(0.030, 0.14, 0.020), edge)
	_box(p, Vector3(0, 0.54, 0.038), Vector3(0.026, 0.24, 0.016), edge)
	_box(p, Vector3(0, 0.72, 0.028), Vector3(0.022, 0.24, 0.012), edge)
	_box(p, Vector3(0, 0.38, -0.044), Vector3(0.030, 0.14, 0.020), edge)
	_box(p, Vector3(0, 0.54, -0.038), Vector3(0.026, 0.24, 0.016), edge)
	_box(p, Vector3(0, 0.72, -0.028), Vector3(0.022, 0.24, 0.012), edge)

	# ── Rãnh máu (fuller) rộng ──────────────────────────────────────────
	_box(p, Vector3(0, 0.52, 0), Vector3(0.055, 0.52, 0.014), fuller)
	# Đường chạm khắc trang trí hai bên fuller
	_box(p, Vector3(0.034, 0.52, 0), Vector3(0.002, 0.44, 0.028), _mat(Color(0.50, 0.52, 0.60)))
	_box(p, Vector3(-0.034, 0.52, 0), Vector3(0.002, 0.44, 0.028), _mat(Color(0.50, 0.52, 0.60)))

# ── Kích Sắt (Iron Halberd) — cán dài, lưỡi búa + mũi nhọn ─────────────────
static func _build_iron_halberd(p: Node3D) -> void:
	var wood := _mat(Color(0.48, 0.28, 0.08))
	var wood_d := _mat(Color(0.35, 0.20, 0.06))
	var iron := _mat(Color(0.58, 0.58, 0.62))
	var iron_d := _mat(Color(0.38, 0.38, 0.44))
	var iron_l := _mat(Color(0.72, 0.72, 0.78))
	var edge := _mat(Color(0.82, 0.84, 0.90))
	# Cán dài (pole)
	_cyl(p, Vector3(0, 0.00, 0), 0.035, 0.80, wood)
	_cyl(p, Vector3(0, -0.06, 0), 0.040, 0.10, wood_d)
	# Đai sắt giữa cán
	_cyl(p, Vector3(0, 0.32, 0), 0.042, 0.04, iron_d)
	# Ferrule — khớp nối đầu cán với lưỡi
	_cyl(p, Vector3(0, 0.41, 0), 0.048, 0.06, iron)
	_box(p, Vector3(0, 0.44, 0), Vector3(0.07, 0.03, 0.07), iron_d)
	# Phần lưỡi búa (axe blade) — mở rộng sang +X
	# Sống lưỡi
	_box(p, Vector3(0.05, 0.46, 0.00), Vector3(0.18, 0.06, 0.05), iron)
	_box(p, Vector3(0.15, 0.46, 0.00), Vector3(0.10, 0.06, 0.04), iron_d)
	# Lưỡi cắt — cạnh sắc
	_box(p, Vector3(0.22, 0.46, 0.00), Vector3(0.04, 0.06, 0.025), edge)
	# Đế lưỡi (phần nối với cán)
	_box(p, Vector3(0.00, 0.46, 0.00), Vector3(0.06, 0.08, 0.07), iron_d)
	# Mũi nhọn trên đỉnh (spike) — thẳng lên trên
	_box(p, Vector3(0.00, 0.56, 0.00), Vector3(0.04, 0.12, 0.04), iron)
	_box(p, Vector3(0.00, 0.68, 0.00), Vector3(0.025, 0.10, 0.025), iron_l)
	_box(p, Vector3(0.00, 0.78, 0.00), Vector3(0.012, 0.06, 0.012), edge)
	# Móc sau (back hook) — ở -X phía sau lưỡi
	_box(p, Vector3(-0.06, 0.46, 0.00), Vector3(0.04, 0.04, 0.04), iron)
	_box(p, Vector3(-0.08, 0.48, 0.00), Vector3(0.02, 0.040, 0.02), iron_d)

static func iron_halberd_drop(p: Node3D) -> void:
	var wood := Color(0.48, 0.28, 0.08)
	var iron := Color(0.58, 0.58, 0.62)
	var edge := Color(0.82, 0.84, 0.90)
	ItemMeshShared.add_cube(p, 0, -3, 0, 1.0, 5.0, 1.0, wood)
	ItemMeshShared.add_cube(p, 0, 2, 0, 2.5, 1.5, 1.2, iron)
	ItemMeshShared.add_cube(p, 0, 4, 0, 1.5, 2.0, 0.8, iron)
	ItemMeshShared.add_cube(p, 1, 2, 0, 1.8, 1.0, 0.5, edge)

# ── Găng Tay Da Thú (Fur Leather Gloves) — chi tiết ─────────────────────────
static func _build_gang_tay(p: Node3D) -> void:
	var wrap := Node3D.new()
	wrap.rotation_degrees = Vector3(-90, 0, 0)
	wrap.position = Vector3(0, 0.11, 0.02)
	p.add_child(wrap)

	var leather     := _mat(Color(0.42, 0.28, 0.14))
	var light       := _mat(Color(0.50, 0.34, 0.17))
	var dark        := _mat(Color(0.28, 0.17, 0.07))
	var finger_mat  := _mat(Color(0.58, 0.42, 0.20))
	var stitch_c    := _mat(Color(0.55, 0.40, 0.22))
	var metal_c     := _mat(Color(0.50, 0.50, 0.56))
	var finger_w: Array[float] = [0.028, 0.028, 0.028, 0.022]
	var finger_len: Array[float] = [0.06, 0.07, 0.06, 0.04]
	var finger_off: Array[float] = [-0.045, -0.015, 0.015, 0.045]

	for s in [-1.0, 1.0]:
		# weapon_pivot gắn ở tay phải → găng phải ở x dương nhẹ, găng trái ở x âm
		var x: float = 0.02 if s > 0 else -0.20

		# Cổ tay (wrist cuff)
		_box(wrap, Vector3(x, -0.02, 0),  Vector3(0.14, 0.06, 0.16), dark)
		_box(wrap, Vector3(x, -0.01, 0.08), Vector3(0.13, 0.002, 0.006), stitch_c)
		_cyl(wrap, Vector3(x, -0.01, 0.07), 0.016, 0.06, metal_c)

		# Lòng bàn tay + mu bàn tay (palm + back)
		_box(wrap, Vector3(x, 0.04, 0),   Vector3(0.15, 0.08, 0.15), leather)
		_box(wrap, Vector3(x, 0.05, 0.05), Vector3(0.12, 0.06, 0.08), light)

		# Đốt ngón tay (knuckle bumps)
		for i in 4:
			var kx: float = x + finger_off[i] * s
			_box(wrap, Vector3(kx, 0.09, 0.04), Vector3(0.022, 0.025, 0.025), finger_mat)

		# Ngón tay — 4 ngón, mỗi ngón 2 đốt (fingers, 2 segments each)
		for i in 4:
			var fx: float = x + finger_off[i] * s
			var w: float = finger_w[i]
			var fl: float = finger_len[i]
			# Đốt gần (proximal)
			_box(wrap, Vector3(fx, 0.10, 0.06), Vector3(w, 0.035, fl * 0.5), finger_mat)
			# Đốt xa (distal)
			_box(wrap, Vector3(fx, 0.10, 0.06 + fl * 0.35), Vector3(w * 0.85, 0.03, fl * 0.5), light)
			# Đường chỉ khớp (stitch at joint)
			_box(wrap, Vector3(fx, 0.10, 0.06 + fl * 0.22), Vector3(w * 0.9, 0.002, 0.002), stitch_c)

		# Ngón cái (thumb)
		_box(wrap, Vector3(x + 0.05 * s, 0.02, 0.07), Vector3(0.04, 0.05, 0.05), finger_mat)
		_box(wrap, Vector3(x + 0.06 * s, 0.01, 0.09), Vector3(0.035, 0.04, 0.04), light)

		# Đường chỉ viền (edge stitching)
		_box(wrap, Vector3(x, 0.04,  0.065), Vector3(0.14, 0.002, 0.002), stitch_c)
		_box(wrap, Vector3(x, 0.04, -0.065), Vector3(0.14, 0.002, 0.002), stitch_c)

# ── Drop / display ─────────────────────────────────────────────────────────
static func greatsword_drop(p: Node3D) -> void:
	var handle := Color(0.22, 0.12, 0.06)
	var guard_c := Color(0.65, 0.52, 0.14)
	var blade_c := Color(0.55, 0.58, 0.68)
	# Pommel
	ItemMeshShared.add_cube(p, 0, -3, 0, 1.5, 0.8, 1.5, guard_c)
	# Handle (2-hand)
	ItemMeshShared.add_cube(p, 0, -2, 0, 1.2, 1.5, 1.2, handle)
	ItemMeshShared.add_cube(p, 0, -1, 0, 1.2, 1.5, 1.2, handle)
	# Crossguard (wide)
	ItemMeshShared.add_cube(p, 0, 0, 0, 2.5, 0.7, 2.0, guard_c)
	ItemMeshShared.add_cube(p, 0, 0, 0, 2.0, 0.7, 2.5, guard_c)
	# Blade — tall and wide
	ItemMeshShared.add_cube(p, 0, 2, 0, 1.8, 3.5, 1.5, blade_c)
	ItemMeshShared.add_cube(p, 0, 4, 0, 1.4, 2.5, 1.2, blade_c)
	ItemMeshShared.add_cube(p, 0, 6, 0, 1.0, 2.5, 0.9, blade_c)
	ItemMeshShared.add_cube(p, 0, 8, 0, 0.6, 1.5, 0.6, blade_c.lightened(0.1))
	ItemMeshShared.add_cube(p, 0, 9, 0, 0.3, 0.8, 0.3, blade_c.lightened(0.15))

static func gauntlet_drop(p: Node3D) -> void:
	var leather := Color(0.42, 0.28, 0.14)
	var light := Color(0.50, 0.34, 0.17)
	var dark := Color(0.28, 0.17, 0.07)
	ItemMeshShared.add_cube(p, -0.8, 0, 0, 1.2, 1.2, 1.2, leather)
	ItemMeshShared.add_cube(p, 0.8, 0, 0, 1.2, 1.2, 1.2, leather)
	ItemMeshShared.add_cube(p, -0.8, 0, 0.5, 0.8, 0.8, 0.4, light)
	ItemMeshShared.add_cube(p, 0.8, 0, 0.5, 0.8, 0.8, 0.4, light)
	ItemMeshShared.add_cube(p, -0.8, -0.5, 0, 1.0, 0.5, 1.0, dark)
	ItemMeshShared.add_cube(p, 0.8, -0.5, 0, 1.0, 0.5, 1.0, dark)

# ── Nỏ (Crossbow) — chi tiết ──────────────────────────────────────────────────
static func _build_no(p: Node3D) -> void:
	var stock := _mat(Color(0.38, 0.22, 0.09))
	var stock_light := _mat(Color(0.48, 0.30, 0.13))
	var stock_dark := _mat(Color(0.26, 0.14, 0.05))
	var prod := _mat(Color(0.50, 0.32, 0.14))
	var prod_light := _mat(Color(0.58, 0.38, 0.16))
	var prod_dark := _mat(Color(0.35, 0.20, 0.08))
	var metal := _mat(Color(0.40, 0.42, 0.46))
	var metal_bright := _mat(Color(0.58, 0.60, 0.66))
	var leather := _mat(Color(0.30, 0.18, 0.10))
	var string_mat := _mat(Color(0.78, 0.74, 0.62))
	var wrap := _mat(Color(0.38, 0.24, 0.14))
	var bolt_shaft := _mat(Color(0.55, 0.40, 0.25))
	var bolt_tip := _mat(Color(0.65, 0.65, 0.70))
	var bolt_fletch := _mat(Color(0.75, 0.70, 0.55))

	# ── Thân nỏ (Stock) — dọc trục Y (hướng về phía trước) ────────────
	# Bệ vai (phía sau, -Y hướng về người chơi)
	_box(p, Vector3(0, -0.22, 0), Vector3(0.070, 0.10, 0.060), stock_dark)
	# Chuyển tiếp thân
	_box(p, Vector3(0, -0.14, 0), Vector3(0.060, 0.06, 0.050), stock)
	# Tay cầm bọc da
	_box(p, Vector3(0, -0.08, 0), Vector3(0.055, 0.06, 0.048), leather)
	# Đai da quấn tay
	_box(p, Vector3(0, -0.090, -0.005), Vector3(0.058, 0.008, 0.045), _mat(Color(0.22, 0.14, 0.08)))
	_box(p, Vector3(0, -0.065, -0.005), Vector3(0.058, 0.008, 0.045), _mat(Color(0.22, 0.14, 0.08)))
	# Thân chính
	_box(p, Vector3(0, 0.00, -0.015), Vector3(0.050, 0.08, 0.042), stock)
	_box(p, Vector3(0, 0.08, -0.015), Vector3(0.046, 0.08, 0.038), stock)
	# Nàng (barrel)
	_box(p, Vector3(0, 0.16, -0.015), Vector3(0.042, 0.08, 0.035), stock_light)
	_box(p, Vector3(0, 0.22, -0.015), Vector3(0.038, 0.04, 0.032), stock_light)
	# Ray kim loại trên nàng (rãnh dẫn tên) — nằm ở -Z (phía trên sau khi xoay)
	_box(p, Vector3(0, 0.10, -0.040), Vector3(0.024, 0.24, 0.005), metal_bright)

	# ── Bộ cò (Trigger) — nằm ở +Z (phía dưới sau khi xoay) ──────────────
	# Vòng bọc cò
	_box(p, Vector3(0, -0.04, 0.050), Vector3(0.035, 0.035, 0.025), metal)
	# Cò
	_box(p, Vector3(0, -0.06, 0.035), Vector3(0.015, 0.020, 0.015), metal_bright)

	# ── Giá lắp cánh cung (Prod mount) ─────────────────────────────────────
	_box(p, Vector3(0, 0.26, -0.005), Vector3(0.042, 0.030, 0.040), metal)
	_box(p, Vector3(0, 0.27, 0), Vector3(0.055, 0.015, 0.045), metal)

	# ── Cánh cung trái (Left limb) — nằm ngang trục X ─────────────────────
	_box(p, Vector3(-0.040, 0.26, -0.010), Vector3(0.035, 0.030, 0.025), prod)
	_box(p, Vector3(-0.090, 0.26, -0.015), Vector3(0.035, 0.030, 0.020), prod_light)
	_box(p, Vector3(-0.135, 0.26, -0.020), Vector3(0.030, 0.030, 0.016), prod_light)
	_box(p, Vector3(-0.175, 0.26, -0.025), Vector3(0.025, 0.030, 0.012), prod)
	_box(p, Vector3(-0.210, 0.26, -0.030), Vector3(0.020, 0.030, 0.010), prod_dark)

	# ── Cánh cung phải (Right limb) — đối xứng ────────────────────────────
	_box(p, Vector3(0.040, 0.26, -0.010), Vector3(0.035, 0.030, 0.025), prod)
	_box(p, Vector3(0.090, 0.26, -0.015), Vector3(0.035, 0.030, 0.020), prod_light)
	_box(p, Vector3(0.135, 0.26, -0.020), Vector3(0.030, 0.030, 0.016), prod_light)
	_box(p, Vector3(0.175, 0.26, -0.025), Vector3(0.025, 0.030, 0.012), prod)
	_box(p, Vector3(0.210, 0.26, -0.030), Vector3(0.020, 0.030, 0.010), prod_dark)

	# ── Dây cung (String) — 2 đoạn tạo hình tam giác khi kéo ────────────
	var str_grp := Node3D.new()
	str_grp.name = "BowString"
	p.add_child(str_grp)

	var s_left := MeshInstance3D.new()
	s_left.name = "SegLeft"
	s_left.mesh = CylinderMesh.new()
	s_left.mesh.top_radius = 0.0035
	s_left.mesh.bottom_radius = 0.0035
	s_left.mesh.height = 1.0
	s_left.material_override = string_mat
	str_grp.add_child(s_left)

	var s_right := MeshInstance3D.new()
	s_right.name = "SegRight"
	s_right.mesh = CylinderMesh.new()
	s_right.mesh.top_radius = 0.0035
	s_right.mesh.bottom_radius = 0.0035
	s_right.mesh.height = 1.0
	s_right.material_override = string_mat
	str_grp.add_child(s_right)

	# Nút quấn giữa dây (nocking point) — ở -Z (phía trên)
	var nock_point := MeshInstance3D.new()
	nock_point.name = "NockPoint"
	nock_point.mesh = BoxMesh.new()
	nock_point.mesh.size = Vector3(0.012, 0.015, 0.020)
	nock_point.material_override = wrap
	nock_point.position = Vector3(0, 0.26, -0.030)
	str_grp.add_child(nock_point)

	# Quấn đầu dây trái / phải (serving wraps)
	var serving_left := MeshInstance3D.new()
	serving_left.name = "ServingLeft"
	serving_left.mesh = CylinderMesh.new()
	serving_left.mesh.top_radius = 0.006
	serving_left.mesh.bottom_radius = 0.006
	serving_left.mesh.height = 0.030
	serving_left.material_override = wrap
	serving_left.position = Vector3(-0.210, 0.26, -0.030)
	str_grp.add_child(serving_left)

	var serving_right := MeshInstance3D.new()
	serving_right.name = "ServingRight"
	serving_right.mesh = CylinderMesh.new()
	serving_right.mesh.top_radius = 0.006
	serving_right.mesh.bottom_radius = 0.006
	serving_right.mesh.height = 0.030
	serving_right.material_override = wrap
	serving_right.position = Vector3(0.210, 0.26, -0.030)
	str_grp.add_child(serving_right)

	# ── Mũi tên nỏ (Bolt) — nằm trên nàng ở -Z (phía trên) ──────────────
	# Thân tên
	_box(p, Vector3(0, 0.10, -0.055), Vector3(0.015, 0.20, 0.015), bolt_shaft)
	# Mũi tên
	_box(p, Vector3(0, 0.19, -0.055), Vector3(0.020, 0.04, 0.020), bolt_tip)
	# Chòm lông (rear)
	_box(p, Vector3(0, 0.01, -0.060), Vector3(0.028, 0.05, 0.028), bolt_fletch)
	_box(p, Vector3(0, 0.01, -0.060), Vector3(0.015, 0.05, 0.040), bolt_fletch)

static func no_drop(p: Node3D) -> void:
	var stock := Color(0.40, 0.24, 0.10)
	var metal := Color(0.45, 0.45, 0.50)
	var prod_c := Color(0.50, 0.32, 0.14)
	ItemMeshShared.add_cube(p, -2, 0, 0, 2.5, 0.8, 0.8, prod_c)  # left limb
	ItemMeshShared.add_cube(p, 2, 0, 0, 2.5, 0.8, 0.8, prod_c)  # right limb
	ItemMeshShared.add_cube(p, 0, -2, 0, 2.0, 2.0, 0.8, stock)  # stock
	ItemMeshShared.add_cube(p, 0, 0, 0, 1.5, 1.5, 1.2, metal)   # mount

# ── Mũi tên (Arrow) drop model ─────────────────────────────────────────────────
static func arrow_drop(p: Node3D) -> void:
	var shaft := Color(0.55, 0.40, 0.25)
	var tip := Color(0.65, 0.65, 0.70)
	var fletch := Color(0.75, 0.70, 0.55)
	ItemMeshShared.add_cube(p, 0, 0, 0, 0.4, 2.0, 0.4, shaft)
	ItemMeshShared.add_cube(p, 0, -1, 0, 0.6, 0.5, 0.6, shaft)
	ItemMeshShared.add_cube(p, 0, 1, 0, 0.7, 0.5, 0.7, tip)
	ItemMeshShared.add_cube(p, 0, 1, 0, 1.0, 0.2, 0.2, fletch)
	ItemMeshShared.add_cube(p, 0, 1, 0, 0.2, 0.2, 1.0, fletch)

# ── Mũi tên (Arrow) held model — chi tiết, tỉ lệ lớn ─────────────────────────
static func _build_mui_ten(p: Node3D) -> void:
	var s := 0.65
	var shaft := _mat(Color(0.55, 0.40, 0.25))
	var shaft_light := _mat(Color(0.65, 0.50, 0.35))
	var tip_mat := _mat(Color(0.65, 0.65, 0.70))
	var tip_edge := _mat(Color(0.82, 0.82, 0.88))
	var fletch := _mat(Color(0.75, 0.70, 0.55))
	var fletch_dark := _mat(Color(0.60, 0.55, 0.42))
	var wrap := _mat(Color(0.38, 0.24, 0.14))
	_cyl(p, Vector3(0, 0.15 * s, 0), 0.030 * s, 0.55 * s, shaft)
	_cyl(p, Vector3(0, 0.15 * s, 0), 0.018 * s, 0.48 * s, shaft_light)
	_box(p, Vector3(0, 0.48 * s, 0), Vector3(0.060 * s, 0.12 * s, 0.015 * s), tip_mat)
	_box(p, Vector3(0, 0.48 * s, 0), Vector3(0.015 * s, 0.12 * s, 0.060 * s), tip_mat)
	_box(p, Vector3(0, 0.56 * s, 0), Vector3(0.035 * s, 0.04 * s, 0.008 * s), tip_edge)
	_box(p, Vector3(0, 0.56 * s, 0), Vector3(0.008 * s, 0.04 * s, 0.035 * s), tip_edge)
	_cyl(p, Vector3(0, -0.12 * s, 0), 0.035 * s, 0.025 * s, wrap)
	_box(p, Vector3(0, -0.04 * s, 0.060 * s), Vector3(0.008 * s, 0.16 * s, 0.040 * s), fletch)
	_box(p, Vector3(0, -0.04 * s, -0.060 * s), Vector3(0.008 * s, 0.16 * s, 0.040 * s), fletch)
	_box(p, Vector3(0.060 * s, -0.04 * s, 0), Vector3(0.040 * s, 0.16 * s, 0.008 * s), fletch)
	_box(p, Vector3(-0.060 * s, -0.04 * s, 0), Vector3(0.040 * s, 0.16 * s, 0.008 * s), fletch)
	_box(p, Vector3(0, -0.04 * s, 0.060 * s), Vector3(0.004 * s, 0.14 * s, 0.034 * s), fletch_dark)
	_box(p, Vector3(0, -0.04 * s, -0.060 * s), Vector3(0.004 * s, 0.14 * s, 0.034 * s), fletch_dark)
	_cyl(p, Vector3(0, -0.12 * s, 0), 0.040 * s, 0.012 * s, wrap)

# ── Pháo Dưa Hấu (Watermelon Cannon) — to, lực, chi tiết ─────────────────
static func _build_phao_dua_hau(p: Node3D) -> void:
	var gunmetal := _mat(Color(0.35, 0.36, 0.40))
	var gunmetal2:= _mat(Color(0.42, 0.43, 0.48))
	var steel    := _mat(Color(0.55, 0.56, 0.62))
	var brass    := _mat(Color(0.55, 0.42, 0.12))
	var wood     := _mat(Color(0.40, 0.24, 0.10))
	var wood_d   := _mat(Color(0.28, 0.16, 0.06))
	var green    := _mat(Color(0.22, 0.52, 0.16))
	var green_l  := _mat(Color(0.30, 0.60, 0.22))
	var stripe_c := _mat(Color(0.12, 0.32, 0.08))
	var dark     := _mat(Color(0.18, 0.18, 0.20))
	# Bệ đỡ vai (shoulder stock) — dày, chắc, nhiều chi tiết
	_box(p, Vector3(0, -0.14, -0.10), Vector3(0.14, 0.06, 0.18), wood_d)
	_box(p, Vector3(0, -0.10, -0.14), Vector3(0.16, 0.06, 0.08), wood)
	_box(p, Vector3(0, -0.06, -0.16), Vector3(0.10, 0.04, 0.05), wood_d)
	_cyl(p, Vector3(0, -0.10, -0.12), 0.025, 0.08, brass)
	# Khung thân pháo chính (main frame)
	_box(p, Vector3(0, 0.02, 0.02),  Vector3(0.18, 0.16, 0.18), gunmetal)
	_box(p, Vector3(0, 0.06, 0.08),  Vector3(0.16, 0.08, 0.06), green)
	_box(p, Vector3(0, 0.12, 0.08),  Vector3(0.005, 0.04, 0.07), stripe_c)
	_box(p, Vector3(0, 0.06, 0.08),  Vector3(0.005, 0.04, 0.07), stripe_c)
	# Đai ốc / tán giữ
	_box(p, Vector3(-0.08, 0.02, 0.02), Vector3(0.02, 0.12, 0.16), dark)
	_box(p, Vector3(0.08, 0.02, 0.02), Vector3(0.02, 0.12, 0.16), dark)
	# Đai tăng cường (reinforcement bands)
	_box(p, Vector3(0, 0.14, 0.02), Vector3(0.20, 0.04, 0.20), steel)
	_cyl(p, Vector3(0, 0.14, 0.02), 0.10, 0.04, steel)
	_box(p, Vector3(0, 0.28, 0.02), Vector3(0.18, 0.04, 0.18), steel)
	_cyl(p, Vector3(0, 0.28, 0.02), 0.09, 0.04, steel)
	# Thân nòng (barrel) — dày hơn, dài hơn
	_cyl(p, Vector3(0, 0.10, 0.02), 0.09, 0.18, gunmetal2)
	_cyl(p, Vector3(0, 0.22, 0.02), 0.08, 0.12, gunmetal)
	_cyl(p, Vector3(0, 0.34, 0.02), 0.07, 0.10, gunmetal2)
	# Họa tiết dưa hấu dọc thân nòng
	_box(p, Vector3(0, 0.10, 0.10),  Vector3(0.14, 0.22, 0.02), green_l)
	_box(p, Vector3(0, 0.16, 0.10),  Vector3(0.006, 0.05, 0.025), stripe_c)
	_box(p, Vector3(0, 0.24, 0.10),  Vector3(0.006, 0.05, 0.025), stripe_c)
	# Nòng pháo (muzzle) — loe to, uy lực
	_cyl(p, Vector3(0, 0.40, 0.02), 0.09, 0.04, steel)
	_cyl(p, Vector3(0, 0.42, 0.02), 0.11, 0.03, gunmetal)
	_cyl(p, Vector3(0, 0.40, 0.02), 0.06, 0.08, dark)
	# Tay cầm / cò súng
	_box(p, Vector3(0, -0.04, -0.06), Vector3(0.04, 0.05, 0.06), wood)
	_box(p, Vector3(0, -0.06, -0.04), Vector3(0.025, 0.02, 0.03), steel)
	# Bộ phận ngắm (sight) — trên nòng
	_box(p, Vector3(0, 0.20, 0.10), Vector3(0.01, 0.03, 0.02), brass)
	_box(p, Vector3(0, 0.35, 0.10), Vector3(0.01, 0.03, 0.02), brass)

static func _build_dan_hat_nhan_dua_hau(p: Node3D) -> void:
	# Mini watermelon projectile model — vỏ xanh, ruột đỏ
	var green_d := Color(0.18, 0.50, 0.12)
	var green_l := Color(0.28, 0.60, 0.20)
	var red_f := Color(0.75, 0.15, 0.18)
	var m_core := MeshBuilder.emit_mat(red_f, Color(1.0, 0.2, 0.25), 4.0)
	MeshBuilder.sphere(p, Vector3.ZERO, 0.08, m_core)
	var m_glow := MeshBuilder.emit_mat(green_d, green_l, 3.0)
	var glow := MeshBuilder.sphere(p, Vector3.ZERO, 0.16, m_glow)
	glow.scale = Vector3(1.0, 0.6, 1.0)
	var m_ring := MeshBuilder.emit_mat(green_l, green_l, 3.0)
	var tor := TorusMesh.new(); tor.inner_radius = 0.22; tor.outer_radius = 0.02
	var ri := MeshInstance3D.new(); ri.mesh = tor; ri.material_override = m_ring
	ri.rotation = Vector3(0.5, 0.3, 0.1); p.add_child(ri)

static func phao_dua_hau_drop(p: Node3D) -> void:
	var steel_c := Color(0.55, 0.56, 0.62)
	var wood_c  := Color(0.40, 0.24, 0.10)
	var green_c := Color(0.22, 0.52, 0.16)
	ItemMeshShared.add_cube(p, 0, 0, 0, 1.8, 2.8, 2.0, steel_c)
	ItemMeshShared.add_cube(p, 0, -2.0, 0, 2.0, 1.2, 1.6, wood_c)
	ItemMeshShared.add_cube(p, 0, 2.0, 0, 2.0, 1.2, 1.8, steel_c)
	ItemMeshShared.add_cube(p, 0, -1.0, 1.0, 1.6, 2.0, 0.4, green_c)
	ItemMeshShared.add_cube(p, 0, 1.5, 0, 1.4, 0.4, 1.6, steel_c)
	ItemMeshShared.add_cube(p, 0, 2.6, 0, 2.2, 0.4, 2.2, steel_c)

# ── Pháo Cối Bí Đỏ (Pumpkin Mortar) — nòng ngắn, bệ đỡ, bí đỏ trang trí ─────
static func _build_phao_coi(p: Node3D) -> void:
	var metal_d := _mat(Color(0.30, 0.30, 0.35))
	var metal   := _mat(Color(0.45, 0.45, 0.50))
	var metal_l := _mat(Color(0.55, 0.55, 0.62))
	var brass   := _mat(Color(0.55, 0.42, 0.12))
	var orange  := _mat(Color(1.0, 0.55, 0.0))
	var green   := _mat(Color(0.15, 0.55, 0.10))
	var dark    := _mat(Color(0.18, 0.18, 0.20))

	var pivot := Node3D.new()
	pivot.rotation_degrees = Vector3(-45, 0, 0)
	p.add_child(pivot)

	# Bệ đỡ (base plate)
	_box(pivot, Vector3(0, -0.06, 0), Vector3(0.20, 0.04, 0.22), metal_d)
	_box(pivot, Vector3(0, -0.12, 0), Vector3(0.16, 0.08, 0.18), dark)
	# Chân đế (legs)
	_box(pivot, Vector3(-0.08, -0.18, 0.06), Vector3(0.04, 0.08, 0.05), metal_d)
	_box(pivot, Vector3(0.08, -0.18, 0.06), Vector3(0.04, 0.08, 0.05), metal_d)
	_box(pivot, Vector3(-0.08, -0.18, -0.06), Vector3(0.04, 0.08, 0.05), metal_d)
	_box(pivot, Vector3(0.08, -0.18, -0.06), Vector3(0.04, 0.08, 0.05), metal_d)

	# Giá đỡ nòng (barrel mount)
	_box(pivot, Vector3(0, 0.02, -0.04), Vector3(0.10, 0.08, 0.10), metal_d)
	_box(pivot, Vector3(0, 0.06, -0.04), Vector3(0.12, 0.04, 0.12), metal)

	# Nòng pháo (barrel) — ống ngắn, dày
	_cyl(pivot, Vector3(0, 0.10, 0.06), 0.07, 0.18, metal_d)
	_cyl(pivot, Vector3(0, 0.14, 0.10), 0.06, 0.10, metal)
	_cyl(pivot, Vector3(0, 0.22, 0.08), 0.065, 0.06, metal_l)
	# Miệng nòng (muzzle)
	_cyl(pivot, Vector3(0, 0.26, 0.06), 0.08, 0.03, metal_d)
	_cyl(pivot, Vector3(0, 0.28, 0.06), 0.09, 0.02, metal_l)
	# Lỗ nòng
	_cyl(pivot, Vector3(0, 0.14, 0.10), 0.03, 0.20, dark)

	# Kích hoạt / cò (trigger mechanism)
	_box(pivot, Vector3(0, -0.02, -0.08), Vector3(0.03, 0.04, 0.03), brass)
	_box(pivot, Vector3(0, -0.04, -0.06), Vector3(0.015, 0.02, 0.02), metal_l)

	# Ngòi nổ / dây cháy chậm (fuse) — trên nòng
	var fuse := MeshInstance3D.new()
	var fuse_mesh := CylinderMesh.new()
	fuse_mesh.top_radius = 0.005
	fuse_mesh.bottom_radius = 0.005
	fuse_mesh.height = 0.06
	fuse.mesh = fuse_mesh
	fuse.material_override = _mat(Color(0.55, 0.40, 0.25))
	fuse.position = Vector3(0, 0.30, 0.06)
	fuse.rotation = Vector3(0.3, 0, 0)
	fuse.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pivot.add_child(fuse)

	# Quả bí đỏ trang trí trên miệng nòng
	var pumpkin := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.05
	sph.height = 0.10
	sph.radial_segments = 8
	sph.rings = 6
	pumpkin.mesh = sph
	pumpkin.material_override = orange
	pumpkin.position = Vector3(0.05, 0.28, 0.10)
	pumpkin.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pivot.add_child(pumpkin)

	var stem := MeshInstance3D.new()
	var stem_mesh := CylinderMesh.new()
	stem_mesh.top_radius = 0.005
	stem_mesh.bottom_radius = 0.002
	stem_mesh.height = 0.025
	stem.mesh = stem_mesh
	stem.material_override = green
	stem.position = Vector3(0.05, 0.31, 0.10)
	stem.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.add_child(stem)


# ── Đèn Pin (Flashlight) — model cầm tay + nguồn sáng refl phía trước ────────
# tool dựng dọc +Y local (giống pickaxe/kiếm); weapon_pivot xoay 90° về X nên
# +Y local → hướng nhìn. SpotLight quay (90,0,0) để tia -Z trùng +Y local.
static func _build_den_pin(p: Node3D) -> void:
	var body    := _mat(Color(0.25, 0.26, 0.30))
	var body_d  := _mat(Color(0.16, 0.16, 0.20))
	var grip    := _mat(Color(0.34, 0.36, 0.42))
	var band    := _mat(Color(0.60, 0.62, 0.70))
	var lens_r  := _mat(Color(0.95, 0.90, 0.60))
	var lens_c  := _mat(Color(1.0, 1.0, 0.85))
	var switch  := _mat(Color(0.15, 0.15, 0.18))
	var dark    := _mat(Color(0.10, 0.10, 0.12))
	# Thân chính — dọc +Y, đuôi ở 0
	_cyl(p, Vector3(0, 0.22, 0), 0.050, 0.30, body)
	# Đầu đèn — loe rộng hơn
	_cyl(p, Vector3(0, 0.42, 0), 0.065, 0.16, body_d)
	_cyl(p, Vector3(0, 0.425, 0), 0.070, 0.06, band)
	# Tay cầm bọc nhựa có rãnh
	_cyl(p, Vector3(0, 0.12, 0), 0.056, 0.20, grip)
	for i in 4:
		_cyl(p, Vector3(0, 0.07 + i * 0.045, 0), 0.058, 0.010, dark)
	# Công tắc nâu
	_box(p, Vector3(0.075, 0.30, 0), Vector3(0.025, 0.05, 0.02), switch)
	# Mặt thấu kính
	_cyl(p, Vector3(0, 0.53, 0), 0.062, 0.025, lens_r)
	_cyl(p, Vector3(0, 0.545, 0), 0.045, 0.015, lens_c)
	# Vành bảo vệ đầu tai đèn
	_cyl(p, Vector3(0, 0.50, 0), 0.068, 0.012, band)

	# ── Đèn chiếu sáng — dọc +Y local (hướng nhìn) ──────────────────────
	var light := SpotLight3D.new()
	light.name = "FlashlightSpot"
	light.light_color = Color(1.0, 0.98, 0.88)
	light.light_energy = 2.4
	light.light_specular = 0.4
	light.spot_range = 20.0
	light.spot_angle = 24.0
	light.spot_attenuation = 1.2
	light.shadow_enabled = true
	light.rotation_degrees = Vector3(90, 0, 0)
	light.position = Vector3(0, 0.30, 0)
	p.add_child(light)

	# Đèn áp sáng nhỏ quanh đầu để thấy mặt đất gần chân
	var omni := OmniLight3D.new()
	omni.light_color = Color(1.0, 0.97, 0.85)
	omni.light_energy = 0.5
	omni.omni_range = 3.0
	omni.shadow_enabled = false
	omni.position = Vector3(0, 0.30, 0)
	p.add_child(omni)

# ── Đèn Pin — model drop / đeo (voxel nhỏ, không nguồn sáng để đỡ chi phí) ───
static func flashlight_drop(p: Node3D) -> void:
	var body   := Color(0.30, 0.32, 0.38)
	var body_d := Color(0.20, 0.20, 0.24)
	var grip   := Color(0.42, 0.44, 0.50)
	var band   := Color(0.65, 0.68, 0.75)
	var lens   := Color(0.95, 0.92, 0.65)
	ItemMeshShared.add_cube(p, 0, -1, 0, 1.0, 2.2, 1.0, body)
	ItemMeshShared.add_cube(p, 0, -1, 0, 1.1, 1.4, 1.1, grip)
	ItemMeshShared.add_cube(p, 0, 1, 0, 1.4, 0.8, 1.4, body_d)
	ItemMeshShared.add_cube(p, 0, 1.6, 0, 1.5, 0.5, 1.5, band)
	ItemMeshShared.add_cube(p, 0, 2.2, 0, 1.2, 0.6, 1.2, lens)

## Xô (bucket) — dùng cho water_bucket / lava_bucket.
static func bucket_drop(p: Node3D, is_lava: bool = false) -> void:
	var metal   := Color(0.75, 0.75, 0.78)
	var metal_d := Color(0.55, 0.55, 0.58)
	var rim     := Color(0.85, 0.85, 0.88)
	# Thân xô
	ItemMeshShared.add_cube(p, 0, -0.8, 0, 1.2, 2.2, 1.2, metal)
	ItemMeshShared.add_cube(p, 0, -0.9, 0, 1.0, 0.4, 1.0, metal_d)
	ItemMeshShared.add_cube(p, 0, 1.0, 0, 1.1, 0.3, 1.1, rim)
	if is_lava:
		var lava := Color(0.92, 0.28, 0.10)
		ItemMeshShared.add_cube_shaded(p, 0, -0.3, 0, 0.9, 0.8, 0.9, lava, 0.0, 0.3, Color(1.0, 0.55, 0.15))
	else:
		var water := Color(0.15, 0.42, 0.72)
		ItemMeshShared.add_cube_shaded(p, 0, -0.3, 0, 0.9, 0.8, 0.9, water, 0.0, 0.2, Color(0.0, 0.3, 0.8))
