class_name ItemMesh

const V: float = 0.030

static func build(parent: Node3D, item_id: String) -> void:
	match item_id:
		"ca_chep": _build_fish(parent, Color(0.95, 0.70, 0.10))
		"ca_ro": _build_fish(parent, Color(0.30, 0.30, 0.30))
		"ca_dieu_hong": _build_fish(parent, Color(0.88, 0.55, 0.45))
		"ca_loc": _build_fish(parent, Color(0.30, 0.25, 0.15))
		"ca_la_han": _build_fish(parent, Color(0.92, 0.25, 0.15))
		"tom": _build_shrimp(parent)
		"kiem": _build_sword(parent)
		"cup": _build_cup(parent)
		"xeng": _build_shovel(parent)
		"riu": _build_axe(parent)
		"chest": _build_chest(parent)
		"can_cau": _build_fishing_rod(parent)
		"twilight_gate": _build_gate(parent)
		_: _build_default(parent)

static func _add_cube(p: Node3D, x: float, y: float, z: float, sx: float, sy: float, sz: float, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(sx * V, sy * V, sz * V)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.material = mat
	mi.mesh = mesh
	mi.position = Vector3(x * V, y * V, z * V)
	p.add_child(mi)

static func _make_mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	return m

static func _build_fish(p: Node3D, body_color: Color) -> void:
	var belly := body_color.lightened(0.30)
	var dark := body_color.darkened(0.25)
	var tail := Color(0.70, 0.55, 0.30)

	_add_cube(p, -2, 0, 0, 2, 1.5, 1.2, dark)
	_add_cube(p, 0, 0, 0, 2, 1.8, 1.5, body_color)
	_add_cube(p, 2, 0, 0, 2, 1.5, 1.2, body_color)
	_add_cube(p, 4, 0, 0, 1.5, 0.8, 2.2, tail)
	_add_cube(p, 0, 2, 0, 0.8, 1.2, 1.2, dark)
	_add_cube(p, 0, -2, 0, 1.2, 0.8, 1.2, belly)
	_add_cube(p, -2, 1, 1.5, 0.6, 0.6, 0.6, Color(0.05, 0.05, 0.05))
	_add_cube(p, -2, 1, -1.5, 0.6, 0.6, 0.6, Color(0.05, 0.05, 0.05))

static func _build_shrimp(p: Node3D) -> void:
	var body := Color(0.85, 0.35, 0.20)
	var dark := body.darkened(0.25)

	_add_cube(p, -2, 0, 0, 1.5, 1.0, 1.0, dark)
	_add_cube(p, 0, 0, 0, 2.0, 1.2, 1.2, body)
	_add_cube(p, 2, 0, 0, 2.0, 1.5, 1.2, body.lightened(0.15))
	_add_cube(p, 4, 0, 0, 1.5, 0.6, 1.8, dark)
	_add_cube(p, 0, 2, 0, 0.5, 1.5, 0.5, dark)
	_add_cube(p, -2, 0, 1.8, 3.0, 0.3, 0.5, body)
	_add_cube(p, -2, 1.5, 1.5, 0.3, 0.3, 1.5, dark)
	_add_cube(p, -2, 1.5, -1.5, 0.3, 0.3, 1.5, dark)

static func _build_sword(p: Node3D) -> void:
	var blade := Color(0.75, 0.80, 0.90)
	var handle := Color(0.40, 0.25, 0.15)
	var guard := Color(0.70, 0.65, 0.50)

	_add_cube(p, 0, -2, 0, 0.8, 2.0, 0.8, handle)
	_add_cube(p, 0, 1, 0, 2.5, 0.5, 0.5, guard)
	_add_cube(p, 0, 3, 0, 1.0, 3.0, 0.6, blade)
	_add_cube(p, 0, 5, 0, 0.4, 1.5, 0.4, blade.lightened(0.15))

static func _build_cup(p: Node3D) -> void:
	var metal := Color(0.60, 0.55, 0.50)

	_add_cube(p, 0, 0, 0, 2.5, 0.5, 2.5, metal.darkened(0.2))
	_add_cube(p, 0, 1, 0, 2.5, 2.0, 2.5, metal)
	_add_cube(p, 2, 0, 0, 1.0, 4.0, 1.0, metal)
	_add_cube(p, 0, 0.5, 0, 2.0, 0.3, 2.0, Color(0.25, 0.25, 0.30))

static func _build_shovel(p: Node3D) -> void:
	var handle := Color(0.55, 0.40, 0.25)
	var blade := Color(0.50, 0.50, 0.50)

	_add_cube(p, 0, -2, 0, 1.0, 2.5, 1.0, handle)
	_add_cube(p, 0, 1, 0, 2.5, 1.5, 1.2, blade)
	_add_cube(p, 0, 3, 0, 2.0, 0.5, 1.5, blade.darkened(0.15))

static func _build_axe(p: Node3D) -> void:
	var handle := Color(0.50, 0.35, 0.20)
	var head := Color(0.45, 0.45, 0.45)

	_add_cube(p, 0, -2, 0, 1.0, 2.5, 1.0, handle)
	_add_cube(p, 0, 2, 0, 2.5, 1.5, 1.0, head)
	_add_cube(p, -1, 2, 0, 1.0, 1.0, 1.8, head.lightened(0.1))

static func _build_chest(p: Node3D) -> void:
	var wood := Color(0.50, 0.32, 0.10)
	var lid := Color(0.55, 0.35, 0.12)
	var metal := Color(0.70, 0.65, 0.40)

	_add_cube(p, 0, 0, 0, 2.5, 1.5, 2.5, wood)
	_add_cube(p, 0, 2, 0, 2.5, 0.8, 2.5, lid)
	_add_cube(p, 0, 1.5, 0, 1.5, 0.3, 1.5, metal)

static func _build_fishing_rod(p: Node3D) -> void:
	var handle := Color(0.55, 0.40, 0.25)
	var pole := Color(0.65, 0.52, 0.35)

	_add_cube(p, 0, 0, 0, 1.5, 1.0, 1.5, handle)
	_add_cube(p, 0, 1, 0, 0.8, 1.5, 0.8, handle)
	_add_cube(p, 0, 3, 0, 0.5, 2.5, 0.5, pole)
	_add_cube(p, 0, 5, 0, 0.3, 1.5, 0.3, pole.lightened(0.1))

static func _build_gate(p: Node3D) -> void:
	var frame := Color(0.10, 0.50, 0.45)
	var glow := Color(0.20, 0.70, 0.65)

	_add_cube(p, -2, 0, 0, 1.0, 1.0, 0.5, frame)
	_add_cube(p, -2, 1, 0, 1.0, 1.0, 0.5, frame)
	_add_cube(p, -2, 2, 0, 1.0, 1.0, 0.5, frame)
	_add_cube(p, -2, 3, 0, 1.0, 1.0, 0.5, frame)
	_add_cube(p, 2, 0, 0, 1.0, 1.0, 0.5, frame)
	_add_cube(p, 2, 1, 0, 1.0, 1.0, 0.5, frame)
	_add_cube(p, 2, 2, 0, 1.0, 1.0, 0.5, frame)
	_add_cube(p, 2, 3, 0, 1.0, 1.0, 0.5, frame)
	_add_cube(p, 0, 3, 0, 1.0, 1.0, 0.5, frame)
	_add_cube(p, 0, 4, 0, 3.0, 1.0, 0.5, frame)
	_add_cube(p, 0, 1, 0, 2.0, 1.0, 0.5, glow)

static func _build_default(p: Node3D) -> void:
	_add_cube(p, 0, 0, 0, 3.0, 3.0, 3.0, Color(0.50, 0.50, 0.50))
