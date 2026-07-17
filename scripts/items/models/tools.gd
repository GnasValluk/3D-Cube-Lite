class_name ToolsMesh

# ── Held weapon builders (full scale, for player hand) ──
static func build_held(pivot: Node3D, item_id: String) -> void:
	if pivot == null: return
	for ch in pivot.get_children(): ch.queue_free()
	if item_id.is_empty(): return
	match item_id:
		"cup":     _build_cup(pivot)
		"xeng":    _build_xeng(pivot)
		"riu":     _build_riu(pivot)
		"kiem":    _build_kiem(pivot)
		"can_cau": _build_can_cau(pivot)

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
	var wood := _mat(Color(0.55, 0.32, 0.10))
	var iron := _mat(Color(0.62, 0.62, 0.68))
	var iron_d := _mat(Color(0.40, 0.40, 0.46))
	_cyl(p, Vector3(0, 0.18, 0), 0.04, 0.36, wood)
	_box(p, Vector3(0, 0.38, 0), Vector3(0.07, 0.07, 0.28), iron)
	_box(p, Vector3(0.04, 0.30, 0.10), Vector3(0.05, 0.16, 0.05), iron_d)
	_box(p, Vector3(0.04, 0.30, -0.10), Vector3(0.05, 0.16, 0.05), iron_d)
	_box(p, Vector3(0, 0.36, 0), Vector3(0.07, 0.07, 0.07), iron)

static func _build_xeng(p: Node3D) -> void:
	var wood := _mat(Color(0.55, 0.32, 0.10))
	var iron := _mat(Color(0.68, 0.65, 0.55))
	var iron_d := _mat(Color(0.45, 0.42, 0.35))
	_cyl(p, Vector3(0, 0.18, 0), 0.04, 0.36, wood)
	_box(p, Vector3(0, 0.44, 0), Vector3(0.025, 0.30, 0.24), iron)
	_box(p, Vector3(0, 0.30, 0), Vector3(0.030, 0.035, 0.28), iron_d)
	_box(p, Vector3(0, 0.37, 0), Vector3(0.05, 0.10, 0.07), iron)

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
	var metal := Color(0.60, 0.55, 0.50)
	ItemMeshShared.add_cube(p, 0, 0, 0, 2.5, 0.5, 2.5, metal.darkened(0.2))
	ItemMeshShared.add_cube(p, 0, 1, 0, 2.5, 2.0, 2.5, metal)
	ItemMeshShared.add_cube(p, 2, 0, 0, 1.0, 4.0, 1.0, metal)
	ItemMeshShared.add_cube(p, 0, 0.5, 0, 2.0, 0.3, 2.0, Color(0.25, 0.25, 0.30))

static func shovel_drop(p: Node3D) -> void:
	var handle := Color(0.55, 0.40, 0.25)
	var blade := Color(0.50, 0.50, 0.50)
	ItemMeshShared.add_cube(p, 0, -2, 0, 1.0, 2.5, 1.0, handle)
	ItemMeshShared.add_cube(p, 0, 1, 0, 2.5, 1.5, 1.2, blade)
	ItemMeshShared.add_cube(p, 0, 3, 0, 2.0, 0.5, 1.5, blade.darkened(0.15))

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
