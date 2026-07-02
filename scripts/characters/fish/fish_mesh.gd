## fish/fish_mesh.gd
## Mesh procedural hình cá nước ngọt — thân dẹp, vây, đuôi.

class_name FishMesh

var rig:       Node3D   # root pivot cho animation
var body:      Node3D   # thân chính
var tail:      Node3D   # pivot đuôi
var fin_top:   MeshInstance3D
var fin_l:     MeshInstance3D
var fin_r:     MeshInstance3D

var _mat_body:  StandardMaterial3D
var _mat_belly: StandardMaterial3D
var _mat_fin:   StandardMaterial3D
var _mat_eye:   StandardMaterial3D
var _mat_tail:  StandardMaterial3D

# Màu cá — được set từ FishCharacter trước khi gọi build()
var color_body:   Color = Color(0.30, 0.60, 0.40)
var color_belly:  Color = Color(0.80, 0.85, 0.75)
var color_fin:    Color = Color(0.25, 0.50, 0.35)
var color_tail:   Color = Color(0.20, 0.45, 0.30)

func build(root: Node3D) -> void:
	_make_materials()

	rig      = MeshBuilder.pivot(root, Vector3(0, 0.0, 0))
	rig.name = "FishRig"

	body = MeshBuilder.pivot(rig, Vector3(0, 0, 0))
	body.name = "FishBody"

	_build_body()
	_build_fins()
	_build_tail()
	_build_eyes()

func _make_materials() -> void:
	_mat_body  = MeshBuilder.emit_mat(color_body,   Color(0,0,0), 0.0)
	_mat_belly = MeshBuilder.emit_mat(color_belly,  Color(0,0,0), 0.0)
	_mat_fin   = MeshBuilder.emit_mat(color_fin,    Color(0,0,0), 0.0)
	_mat_tail  = MeshBuilder.emit_mat(color_tail,   Color(0,0,0), 0.0)
	_mat_eye   = MeshBuilder.emit_mat(Color(0.05, 0.05, 0.05), Color(0,0,0), 0.0)

func _build_body() -> void:
	# Thân chính — hình elipsoid dẹp ngang
	MeshBuilder.box(body, Vector3(0, 0.0,  0.00), Vector3(0.12, 0.10, 0.30), _mat_body)
	MeshBuilder.box(body, Vector3(0, 0.0,  0.10), Vector3(0.10, 0.08, 0.12), _mat_body)
	MeshBuilder.box(body, Vector3(0, 0.0, -0.08), Vector3(0.09, 0.08, 0.12), _mat_body)
	# Bụng sáng hơn
	MeshBuilder.box(body, Vector3(0, -0.04, 0.04), Vector3(0.08, 0.04, 0.20), _mat_belly)

func _build_fins() -> void:
	# Vây lưng
	fin_top = MeshBuilder.box(body, Vector3(0, 0.10, 0.02), Vector3(0.02, 0.08, 0.12), _mat_fin)
	fin_top.name = "FinTop"
	# Vây bên trái
	fin_l = MeshBuilder.box(body, Vector3(-0.08, -0.01, 0.06), Vector3(0.06, 0.02, 0.08), _mat_fin)
	fin_l.name = "FinL"
	# Vây bên phải
	fin_r = MeshBuilder.box(body, Vector3( 0.08, -0.01, 0.06), Vector3(0.06, 0.02, 0.08), _mat_fin)
	fin_r.name = "FinR"

func _build_tail() -> void:
	tail = MeshBuilder.pivot(body, Vector3(0, 0, -0.18))
	tail.name = "Tail"
	# Đuôi xoè — hai mảnh chéo
	MeshBuilder.box(tail, Vector3(0,  0.06, -0.06), Vector3(0.02, 0.08, 0.10), _mat_tail)
	MeshBuilder.box(tail, Vector3(0, -0.06, -0.06), Vector3(0.02, 0.08, 0.10), _mat_tail)

func _build_eyes() -> void:
	MeshBuilder.sphere(body, Vector3(-0.06, 0.02, 0.16), 0.025, _mat_eye)
	MeshBuilder.sphere(body, Vector3( 0.06, 0.02, 0.16), 0.025, _mat_eye)
