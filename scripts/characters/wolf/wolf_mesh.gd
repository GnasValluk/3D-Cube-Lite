## wolf/wolf_mesh.gd
## Mesh procedural — Sói Đồng Đêm (Plains Night Wolf): thân dài thấp cúi rình
## mồi, bờ vai gù, đầu nhọn, đôi mắt vàng rực phát sáng khi đuổi theo.
## Mesh dựng trong khối 1 đơn vị; kích thước thật do scale của character.

class_name WolfMesh

var rig: Node3D

var _mat_body:   StandardMaterial3D
var _mat_dark:   StandardMaterial3D
var _mat_snout:  StandardMaterial3D
var _mat_eye:    StandardMaterial3D
var _mat_tail:   StandardMaterial3D

func build(root: Node3D) -> void:
	_make_materials()

	rig      = MeshBuilder.pivot(root, Vector3(0, 0.0, 0))
	rig.name = "WolfRig"

	var body := MeshBuilder.pivot(rig, Vector3.ZERO)
	body.name = "WolfBody"
	_build_body(body)

func _make_materials() -> void:
	# Lông sói — xám đá phiến hơi nâu
	_mat_body = MeshBuilder.emit_mat(Color(0.38, 0.36, 0.34), Color(0, 0, 0), 0.0)
	# Vai gù / lưng xám đen
	_mat_dark = MeshBuilder.emit_mat(Color(0.25, 0.24, 0.22), Color(0, 0, 0), 0.0)
	# Mõm & tai — xám lạnh nhạt
	_mat_snout = MeshBuilder.emit_mat(Color(0.48, 0.46, 0.44), Color(0, 0, 0), 0.0)
	# Mắt — vàng hổ phách rực, phát sáng
	_mat_eye = MeshBuilder.emit_mat(Color(0.95, 0.75, 0.20), Color(1.0, 0.70, 0.15), 3.0)
	# Đuôi — lông rậm xám sậm
	_mat_tail = MeshBuilder.emit_mat(Color(0.30, 0.28, 0.27), Color(0, 0, 0), 0.0)

func _build_body(b: Node3D) -> void:
	# Thân dài cúi — lưng gù cao phía trước
	MeshBuilder.box(b, Vector3(0, 0.52, -0.10), Vector3(0.40, 0.34, 0.80), _mat_body)
	MeshBuilder.box(b, Vector3(0, 0.62, -0.30), Vector3(0.36, 0.40, 0.40), _mat_dark)
	# Ngực trước — nối đầu
	MeshBuilder.box(b, Vector3(0, 0.44, 0.30), Vector3(0.36, 0.30, 0.42), _mat_body)
	# Đầu — dẹt dài, cúi xuống nhìn mồi
	MeshBuilder.box(b, Vector3(0, 0.72, 0.44), Vector3(0.30, 0.24, 0.28), _mat_snout)
	MeshBuilder.box(b, Vector3(0, 0.82, 0.34), Vector3(0.28, 0.18, 0.24), _mat_body)
	# Mõm nhọn
	MeshBuilder.box(b, Vector3(0, 0.64, 0.58), Vector3(0.16, 0.12, 0.20), _mat_snout)
	# Mắt vàng rực
	MeshBuilder.box(b, Vector3(-0.09, 0.78, 0.50), Vector3(0.08, 0.06, 0.04), _mat_eye)
	MeshBuilder.box(b, Vector3(0.09, 0.78, 0.50), Vector3(0.08, 0.06, 0.04), _mat_eye)
	# Tai dựng đứng
	MeshBuilder.box(b, Vector3(-0.11, 0.99, 0.34), Vector3(0.06, 0.16, 0.08), _mat_dark)
	MeshBuilder.box(b, Vector3(0.11, 0.99, 0.34), Vector3(0.06, 0.16, 0.08), _mat_dark)
	# Chân — 4 chân ngắn khỏe
	MeshBuilder.box(b, Vector3(-0.12, 0.16, 0.26), Vector3(0.10, 0.30, 0.12), _mat_body)
	MeshBuilder.box(b, Vector3(0.12, 0.16, 0.26), Vector3(0.10, 0.30, 0.12), _mat_body)
	MeshBuilder.box(b, Vector3(-0.12, 0.16, -0.32), Vector3(0.10, 0.30, 0.12), _mat_body)
	MeshBuilder.box(b, Vector3(0.12, 0.16, -0.32), Vector3(0.10, 0.30, 0.12), _mat_body)
	# Đuôi rậm cụp xuống sau
	MeshBuilder.box(b, Vector3(0, 0.34, -0.52), Vector3(0.10, 0.20, 0.18), _mat_tail)

## Mắt sáng hơn khi đang đuổi theo
func set_chasing(active: bool) -> void:
	if _mat_eye:
		if active:
			_mat_eye.emission_energy_multiplier = 4.0
		else:
			_mat_eye.emission_energy_multiplier = 3.0