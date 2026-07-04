## WeaponMesh — Model procedural cho vũ khí / công cụ cầm tay
## Model build theo trục +Y (gốc Y=0 là cán, đầu ở Y dương)
## weapon_pivot xoay X=+90 → +Y pivot = -Z world = chỉa ra trước nhân vật
extends RefCounted

static func build(pivot: Node3D, item_id: String) -> void:
	if pivot == null:
		return
	for ch in pivot.get_children():
		ch.queue_free()
	if item_id.is_empty():
		return
	match item_id:
		"cuoc": _build_cuoc(pivot)
		"xeng": _build_xeng(pivot)
		"riu":  _build_riu(pivot)
		"kiem": _build_kiem(pivot)

static func _mat(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness    = 0.85
	m.metallic_specular = 0.1
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m

static func _box(p: Node3D, pos: Vector3, sz: Vector3, mat: StandardMaterial3D) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = sz
	mi.mesh = bm
	mi.position = pos
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.add_child(mi)

static func _cyl(p: Node3D, pos: Vector3, r: float, h: float, mat: StandardMaterial3D) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r; cm.bottom_radius = r; cm.height = h; cm.radial_segments = 8
	mi.mesh = cm; mi.position = pos; mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.add_child(mi)

# ── CUỐC ─────────────────────────────────────────────────────────────────────
# Cán dọc Y, đầu cuốc ở trên (Y dương), 2 răng cong xuống
static func _build_cuoc(p: Node3D) -> void:
	var wood   := _mat(Color(0.55, 0.32, 0.10))
	var iron   := _mat(Color(0.62, 0.62, 0.68))
	var iron_d := _mat(Color(0.40, 0.40, 0.46))
	_cyl(p, Vector3(0, 0.18, 0),        0.04, 0.36, wood)               # cán
	_box(p, Vector3(0, 0.38, 0),        Vector3(0.28, 0.07, 0.07), iron) # thanh ngang
	_box(p, Vector3(-0.10, 0.30, 0.04), Vector3(0.05, 0.16, 0.05), iron_d) # răng trái
	_box(p, Vector3( 0.10, 0.30, 0.04), Vector3(0.05, 0.16, 0.05), iron_d) # răng phải
	_box(p, Vector3(0, 0.36, 0),        Vector3(0.07, 0.07, 0.07), iron) # cổ nối

# ── XẺNG ─────────────────────────────────────────────────────────────────────
# Cán dọc Y, lưỡi xẻng hình chữ nhật ở trên
static func _build_xeng(p: Node3D) -> void:
	var wood   := _mat(Color(0.55, 0.32, 0.10))
	var iron   := _mat(Color(0.68, 0.65, 0.55))
	var iron_d := _mat(Color(0.45, 0.42, 0.35))
	_cyl(p, Vector3(0, 0.18, 0), 0.04, 0.36, wood)
	_box(p, Vector3(0, 0.44, 0), Vector3(0.24, 0.30, 0.025), iron)      # lưỡi
	_box(p, Vector3(0, 0.30, 0), Vector3(0.28, 0.035, 0.030), iron_d)   # viền đáy
	_box(p, Vector3(0, 0.37, 0), Vector3(0.07, 0.10, 0.05), iron)       # cổ nối

# ── RÌU ──────────────────────────────────────────────────────────────────────
# Cán dọc Y, lưỡi rìu lệch sang -X
static func _build_riu(p: Node3D) -> void:
	var wood  := _mat(Color(0.48, 0.28, 0.08))
	var iron  := _mat(Color(0.58, 0.58, 0.62))
	var edge  := _mat(Color(0.80, 0.82, 0.88))
	_cyl(p, Vector3(0, 0.15, 0),        0.05, 0.30, wood)
	_box(p, Vector3(-0.08, 0.36, 0),    Vector3(0.18, 0.20, 0.09), iron)
	_box(p, Vector3(-0.16, 0.37, 0),    Vector3(0.10, 0.18, 0.07), iron)
	_box(p, Vector3(-0.24, 0.37, 0),    Vector3(0.07, 0.26, 0.035), edge)  # lưỡi bén
	_box(p, Vector3( 0.07, 0.37, 0),    Vector3(0.05, 0.09, 0.05), iron)   # mũi sau
	_box(p, Vector3(0, 0.32, 0),        Vector3(0.07, 0.10, 0.07), iron)   # cổ nối

# ── KIẾM ─────────────────────────────────────────────────────────────────────
# Cán ở Y thấp, lưỡi dài hướng lên Y
static func _build_kiem(p: Node3D) -> void:
	var grip   := _mat(Color(0.28, 0.16, 0.08))
	var guard  := _mat(Color(0.75, 0.62, 0.18))
	var blade  := _mat(Color(0.82, 0.84, 0.90))
	var edge   := _mat(Color(0.96, 0.98, 1.00))
	var fuller := _mat(Color(0.68, 0.70, 0.78))
	_cyl(p, Vector3(0, 0.06, 0),      0.045, 0.12, grip)                # cán
	_box(p, Vector3(0, 0.13, 0),      Vector3(0.32, 0.045, 0.045), guard) # crossguard
	_box(p, Vector3(0, 0.34, 0),      Vector3(0.048, 0.42, 0.022), blade) # thân lưỡi
	_box(p, Vector3(-0.020, 0.34, 0), Vector3(0.009, 0.40, 0.013), edge)  # cạnh trái
	_box(p, Vector3( 0.020, 0.34, 0), Vector3(0.009, 0.40, 0.013), edge)  # cạnh phải
	_box(p, Vector3(0, 0.54, 0),      Vector3(0.030, 0.10, 0.018), edge)  # mũi nhọn
	_box(p, Vector3(0, 0.32, 0),      Vector3(0.011, 0.36, 0.026), fuller) # fuller
