## fish/fish_mesh.gd
## Mesh procedural — cá nước ngọt (thân dẹp) hoặc tôm (đốt cong)

class_name FishMesh

enum BodyShape { FISH, SHRIMP }

var rig:       Node3D
var body:      Node3D
var tail:      Node3D
var fin_top:   MeshInstance3D
var fin_l:     MeshInstance3D
var fin_r:     MeshInstance3D

var _mat_body:    StandardMaterial3D
var _mat_belly:   StandardMaterial3D
var _mat_fin:     StandardMaterial3D
var _mat_eye:     StandardMaterial3D
var _mat_tail:    StandardMaterial3D
var _mat_pattern: StandardMaterial3D

var color_body:    Color = Color(0.30, 0.60, 0.40)
var color_belly:   Color = Color(0.80, 0.85, 0.75)
var color_fin:     Color = Color(0.25, 0.50, 0.35)
var color_tail:    Color = Color(0.20, 0.45, 0.30)
var color_pattern: Color = Color(0, 0, 0, 0)
var body_z_scale:  float = 1.0
var body_triangular: bool = false
var has_horns:      bool = false
var body_shape:     int   = BodyShape.FISH

func build(root: Node3D) -> void:
	_make_materials()

	rig      = MeshBuilder.pivot(root, Vector3(0, 0.0, 0))
	rig.name = "FishRig"

	body = MeshBuilder.pivot(rig, Vector3(0, 0, 0))
	body.name = "FishBody"

	match body_shape:
		BodyShape.SHRIMP:
			_build_shrimp_body()
			_build_shrimp_tail()
			_build_shrimp_legs()
			_build_antennae()
			_build_eyes()
		_:
			_build_body()
			_build_fins()
			_build_tail()
			_build_eyes()
			if has_horns:
				_build_horns()

func _make_materials() -> void:
	_mat_body    = MeshBuilder.emit_mat(color_body,    Color(0,0,0), 0.0)
	_mat_belly   = MeshBuilder.emit_mat(color_belly,   Color(0,0,0), 0.0)
	_mat_fin     = MeshBuilder.emit_mat(color_fin,     Color(0,0,0), 0.0)
	_mat_tail    = MeshBuilder.emit_mat(color_tail,    Color(0,0,0), 0.0)
	_mat_eye     = MeshBuilder.emit_mat(Color(0.05, 0.05, 0.05), Color(0,0,0), 0.0)
	if color_pattern.a > 0:
		_mat_pattern = MeshBuilder.emit_mat(color_pattern, Color(0,0,0), 0.0)

func _build_body() -> void:
	var bz := body_z_scale
	if body_triangular:
		# Thân hình tam giác — rộng đầu, hẹp đuôi (Flowerhorn)
		MeshBuilder.box(body, Vector3(0, 0.0,  0.13 * bz), Vector3(0.20, 0.12, 0.16 * bz), _mat_body)
		MeshBuilder.box(body, Vector3(0, 0.0,  0.02 * bz), Vector3(0.14, 0.10, 0.18 * bz), _mat_body)
		MeshBuilder.box(body, Vector3(0, 0.0, -0.10 * bz), Vector3(0.08, 0.08, 0.12 * bz), _mat_body)
		MeshBuilder.box(body, Vector3(0, -0.04, 0.04 * bz), Vector3(0.14, 0.04, 0.20 * bz), _mat_belly)
		if _mat_pattern:
			MeshBuilder.box(body, Vector3(0, 0.02, 0.0), Vector3(0.06, 0.02, 0.26 * bz), _mat_pattern)
	else:
		# Thân chính — hình elipsoid dẹp ngang
		MeshBuilder.box(body, Vector3(0, 0.0,  0.00),      Vector3(0.12, 0.10, 0.30 * bz), _mat_body)
		MeshBuilder.box(body, Vector3(0, 0.0,  0.10 * bz), Vector3(0.10, 0.08, 0.12 * bz), _mat_body)
		MeshBuilder.box(body, Vector3(0, 0.0, -0.08 * bz), Vector3(0.09, 0.08, 0.12 * bz), _mat_body)
		# Bụng sáng hơn
		MeshBuilder.box(body, Vector3(0, -0.04, 0.04 * bz), Vector3(0.08, 0.04, 0.20 * bz), _mat_belly)
		# Pattern dọc thân (vảy khoang)
		if _mat_pattern:
			MeshBuilder.box(body, Vector3(0, 0.02, 0.0), Vector3(0.04, 0.02, 0.26 * bz), _mat_pattern)

func _build_fins() -> void:
	var bz := body_z_scale
	# Vây lưng
	fin_top = MeshBuilder.box(body, Vector3(0, 0.10, 0.02 * bz), Vector3(0.02, 0.08, 0.12 * bz), _mat_fin)
	fin_top.name = "FinTop"
	# Vây bên trái
	fin_l = MeshBuilder.box(body, Vector3(-0.08, -0.01, 0.06 * bz), Vector3(0.06, 0.02, 0.08 * bz), _mat_fin)
	fin_l.name = "FinL"
	# Vây bên phải
	fin_r = MeshBuilder.box(body, Vector3( 0.08, -0.01, 0.06 * bz), Vector3(0.06, 0.02, 0.08 * bz), _mat_fin)
	fin_r.name = "FinR"

func _build_tail() -> void:
	var bz := body_z_scale
	tail = MeshBuilder.pivot(body, Vector3(0, 0, -0.18 * bz))
	tail.name = "Tail"
	# Đuôi xoè — hai mảnh chéo
	MeshBuilder.box(tail, Vector3(0,  0.06, -0.06), Vector3(0.02, 0.08, 0.10), _mat_tail)
	MeshBuilder.box(tail, Vector3(0, -0.06, -0.06), Vector3(0.02, 0.08, 0.10), _mat_tail)

func _build_eyes() -> void:
	var bz := body_z_scale
	MeshBuilder.sphere(body, Vector3(-0.06, 0.02, 0.16 * bz), 0.025, _mat_eye)
	MeshBuilder.sphere(body, Vector3( 0.06, 0.02, 0.16 * bz), 0.025, _mat_eye)

func _build_horns() -> void:
	var bz := body_z_scale
	var mat := _mat_body
	var hl := MeshInstance3D.new()
	var ml := CylinderMesh.new()
	ml.top_radius = 0.005
	ml.bottom_radius = 0.025
	ml.height = 0.10
	ml.radial_segments = 6
	hl.mesh = ml
	hl.material_override = mat
	hl.position = Vector3(-0.08, 0.08, 0.22 * bz)
	hl.rotation = Vector3(deg_to_rad(-25), 0, deg_to_rad(20))
	body.add_child(hl)
	var hr := MeshInstance3D.new()
	var mr := CylinderMesh.new()
	mr.top_radius = 0.005
	mr.bottom_radius = 0.025
	mr.height = 0.10
	mr.radial_segments = 6
	hr.mesh = mr
	hr.material_override = mat
	hr.position = Vector3(0.08, 0.08, 0.22 * bz)
	hr.rotation = Vector3(deg_to_rad(-25), 0, deg_to_rad(-20))
	body.add_child(hr)

# ── Shrimp ──────────────────────────────────────────────────────────────────

func _build_shrimp_body() -> void:
	var bz := body_z_scale
	# 4 đốt tạo thành đường cong lưng dốc (còng lưng)
	# Segments: tail → mid-tail → mid-body (hump) → head
	var segs := [
		{ "pos": Vector3(0, 0.00, -0.16 * bz), "sz": Vector3(0.06, 0.04, 0.08 * bz) },
		{ "pos": Vector3(0, 0.04, -0.06 * bz), "sz": Vector3(0.08, 0.05, 0.08 * bz) },
		{ "pos": Vector3(0, 0.08,  0.05 * bz), "sz": Vector3(0.10, 0.07, 0.10 * bz) },
		{ "pos": Vector3(0, 0.03,  0.15 * bz), "sz": Vector3(0.08, 0.05, 0.08 * bz) },
	]
	for s in segs:
		MeshBuilder.box(body, s["pos"], s["sz"], _mat_body)
	# Bụng sáng — cong theo thân
	MeshBuilder.box(body, Vector3(0, -0.01, 0.04 * bz), Vector3(0.09, 0.025, 0.22 * bz), _mat_belly)

func _build_shrimp_tail() -> void:
	var bz := body_z_scale
	var fan_mat := _mat_tail
	MeshBuilder.box(body, Vector3(0, 0.01, -0.19 * bz), Vector3(0.06, 0.02, 0.04 * bz), fan_mat)
	MeshBuilder.box(body, Vector3(0, 0.01, -0.19 * bz), Vector3(0.02, 0.03, 0.04 * bz), fan_mat)
	var tl := MeshInstance3D.new()
	var tlm := CylinderMesh.new()
	tlm.top_radius = 0.001
	tlm.bottom_radius = 0.025
	tlm.height = 0.02
	tlm.radial_segments = 4
	tl.mesh = tlm
	tl.material_override = fan_mat
	tl.position = Vector3(-0.03, 0.01, -0.19 * bz)
	tl.rotation = Vector3(deg_to_rad(90), 0, deg_to_rad(15))
	body.add_child(tl)
	var tr := MeshInstance3D.new()
	var trm := CylinderMesh.new()
	trm.top_radius = 0.001
	trm.bottom_radius = 0.025
	trm.height = 0.02
	trm.radial_segments = 4
	tr.mesh = trm
	tr.material_override = fan_mat
	tr.position = Vector3(0.03, 0.01, -0.19 * bz)
	tr.rotation = Vector3(deg_to_rad(90), 0, deg_to_rad(-15))
	body.add_child(tr)

func _build_shrimp_legs() -> void:
	var leg_mat := _mat_fin
	var z_off := [-0.08, 0.0, 0.10]
	for z in z_off:
		MeshBuilder.box(body, Vector3(-0.03, -0.01, z), Vector3(0.02, 0.02, 0.01), leg_mat)
		MeshBuilder.box(body, Vector3( 0.03, -0.01, z), Vector3(0.02, 0.02, 0.01), leg_mat)

func _build_antennae() -> void:
	var bz := body_z_scale
	var ant_mat := _mat_fin
	var al := MeshInstance3D.new()
	var alm := CylinderMesh.new()
	alm.top_radius = 0.002
	alm.bottom_radius = 0.006
	alm.height = 0.14
	alm.radial_segments = 4
	al.mesh = alm
	al.material_override = ant_mat
	al.position = Vector3(-0.025, 0.04, 0.20 * bz)
	al.rotation = Vector3(deg_to_rad(10), 0, deg_to_rad(35))
	body.add_child(al)
	var ar := MeshInstance3D.new()
	var arm := CylinderMesh.new()
	arm.top_radius = 0.002
	arm.bottom_radius = 0.006
	arm.height = 0.14
	arm.radial_segments = 4
	ar.mesh = arm
	ar.material_override = ant_mat
	ar.position = Vector3(0.025, 0.04, 0.20 * bz)
	ar.rotation = Vector3(deg_to_rad(10), 0, deg_to_rad(-35))
	body.add_child(ar)
