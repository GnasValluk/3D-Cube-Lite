## scarecrow/scarecrow_mesh.gd
## Mesh procedural — Bù Nhìn Ác Quỷ (Haunted Scarecrow): cây thánh giá gỗ +
## thân rơm tơi xốp, đầu túi vải rách với đôi mắt đỏ rực phát sáng đêm tối.
## Mesh dựng trong khối 1 đơn vị; kích thước thật do scale của character.

class_name ScarecrowMesh

var rig: Node3D

var _mat_wood:  StandardMaterial3D
var _mat_straw: StandardMaterial3D
var _mat_sack:  StandardMaterial3D
var _mat_hat:   StandardMaterial3D
var _mat_eye:   StandardMaterial3D
var _mat_mouth: StandardMaterial3D

func build(root: Node3D) -> void:
	_make_materials()

	rig      = MeshBuilder.pivot(root, Vector3(0, 0.0, 0))
	rig.name = "ScarecrowRig"

	var body := MeshBuilder.pivot(rig, Vector3.ZERO)
	body.name = "ScarecrowBody"
	_build_body(body)

func _make_materials() -> void:
	# Cột gỗ thánh giá — nâu sẫm mộc mạc
	_mat_wood = MeshBuilder.emit_mat(Color(0.42, 0.30, 0.18), Color(0, 0, 0), 0.0)
	# Rơm khô — vàng rơm nhạt xơ xác
	_mat_straw = MeshBuilder.emit_mat(Color(0.78, 0.66, 0.34), Color(0, 0, 0), 0.0)
	# Túi vải bố — nâu bẩn sờn
	_mat_sack = MeshBuilder.emit_mat(Color(0.60, 0.50, 0.36), Color(0, 0, 0), 0.0)
	# Mũ rơm — vàng sậm hơn thân
	_mat_hat = MeshBuilder.emit_mat(Color(0.65, 0.54, 0.26), Color(0, 0, 0), 0.0)
	# Mắt — đỏ rực phát sáng trong đêm
	_mat_eye = MeshBuilder.emit_mat(Color(0.95, 0.10, 0.08), Color(1.0, 0.25, 0.15), 3.0)
	# Miệng rách — vết đen
	_mat_mouth = MeshBuilder.emit_mat(Color(0.08, 0.05, 0.04), Color(0.0, 0.0, 0.0), 0.0)

func _build_body(b: Node3D) -> void:
	# Cột gỗ đứng — xuyên suốt từ chân lên thân
	MeshBuilder.box(b, Vector3(0, 0.55, 0), Vector3(0.13, 1.30, 0.13), _mat_wood)
	# Thanh ngang (cánh tay đỡ)
	MeshBuilder.box(b, Vector3(0, 1.05, 0), Vector3(0.95, 0.09, 0.09), _mat_wood)
	# Thân rơm — khối tơi xốp ôm cột gỗ
	MeshBuilder.box(b, Vector3(0, 0.62, 0), Vector3(0.52, 0.62, 0.34), _mat_straw)
	MeshBuilder.box(b, Vector3(0, 0.90, 0), Vector3(0.44, 0.12, 0.38), _mat_straw)
	# Tay rơm xõa xuôi hai bên
	MeshBuilder.box(b, Vector3(-0.30, 1.02, 0), Vector3(0.30, 0.16, 0.16), _mat_straw)
	MeshBuilder.box(b, Vector3(0.30, 1.02, 0), Vector3(0.30, 0.16, 0.16), _mat_straw)
	# Đầu túi vải rách
	MeshBuilder.box(b, Vector3(0, 1.42, 0), Vector3(0.40, 0.42, 0.40), _mat_sack)
	# Mắt đỏ rực ăn sâu vào túi
	MeshBuilder.box(b, Vector3(-0.09, 1.48, 0.21), Vector3(0.12, 0.11, 0.05), _mat_eye)
	MeshBuilder.box(b, Vector3(0.09, 1.48, 0.21), Vector3(0.12, 0.11, 0.05), _mat_eye)
	# Miệng rách — đường chỉ khâu gãy (hình "s" nghiêng bằng 2 ô)
	MeshBuilder.box(b, Vector3(-0.05, 1.34, 0.21), Vector3(0.14, 0.05, 0.04), _mat_mouth)
	MeshBuilder.box(b, Vector3(0.06, 1.30, 0.21), Vector3(0.12, 0.05, 0.04), _mat_mouth)
	# Mũ rơm nghiêng
	MeshBuilder.box(b, Vector3(0, 1.68, -0.02), Vector3(0.58, 0.08, 0.52), _mat_hat)
	MeshBuilder.box(b, Vector3(0, 1.78, -0.02), Vector3(0.30, 0.14, 0.30), _mat_hat)

## Mắt sáng hơn khi đang đuổi theo — xoay tông màu nhấp nháy nhẹ
func set_chasing(active: bool) -> void:
	if _mat_eye:
		if active:
			_mat_eye.emission_energy_multiplier = 4.5
		else:
			_mat_eye.emission_energy_multiplier = 3.0