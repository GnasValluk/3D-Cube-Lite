## wraith/wraith_mesh.gd
## Mesh procedural — Bóng Đêm (Night Wraith): hồn ma hình người lơ lửng,
## áo choàng đen xé rách phủ kín thân, hai mắt trắng sáng rực phát quang,
## không có chân — chạm trần phía dưới.
## Mesh dựng trong khối 1 đơn vị; kích thước thật do scale của character.

class_name WraithMesh

var rig: Node3D

var _mat_robe:  StandardMaterial3D
var _mat_hood:  StandardMaterial3D
var _mat_eye:   StandardMaterial3D
var _mat_hand:  StandardMaterial3D

func build(root: Node3D) -> void:
	_make_materials()

	rig      = MeshBuilder.pivot(root, Vector3(0, 0.0, 0))
	rig.name = "WraithRig"

	var body := MeshBuilder.pivot(rig, Vector3.ZERO)
	body.name = "WraithBody"
	_build_body(body)

func _make_materials() -> void:
	# Áo choàng — đen sâu, hơi lu mờ
	_mat_robe = MeshBuilder.emit_mat(Color(0.06, 0.06, 0.10), Color(0.08, 0.08, 0.15), 0.6)
	# Mũ trùm — đen thẫm hơn
	_mat_hood = MeshBuilder.emit_mat(Color(0.03, 0.03, 0.06), Color(0.06, 0.06, 0.12), 0.8)
	# Mắt — trắng xanh phát quang ma mị
	_mat_eye = MeshBuilder.emit_mat(Color(0.80, 0.92, 1.00), Color(0.55, 0.80, 1.0), 3.0)
	# Bàn tay — xám xanh nhợt nhạt
	_mat_hand = MeshBuilder.emit_mat(Color(0.42, 0.48, 0.55), Color(0.10, 0.15, 0.22), 0.8)

func _build_body(b: Node3D) -> void:
	# Tà áo xé rách — phần dưới loe rộng, tua rua đứt đoạn
	MeshBuilder.box(b, Vector3(0, 0.35, 0), Vector3(0.44, 0.42, 0.30), _mat_robe)
	MeshBuilder.box(b, Vector3(0, 0.12, 0), Vector3(0.50, 0.22, 0.34), _mat_robe)
	MeshBuilder.box(b, Vector3(-0.14, -0.02, 0.02), Vector3(0.18, 0.14, 0.26), _mat_robe)
	MeshBuilder.box(b, Vector3(0.14, -0.02, 0.02), Vector3(0.18, 0.14, 0.26), _mat_robe)
	MeshBuilder.box(b, Vector3(0, 0.02, 0.06), Vector3(0.20, 0.10, 0.28), _mat_robe)
	# Thân trên
	MeshBuilder.box(b, Vector3(0, 0.68, 0), Vector3(0.40, 0.34, 0.28), _mat_robe)
	# Mũ trùm khép kín — không thấy mặt
	MeshBuilder.box(b, Vector3(0, 1.00, 0), Vector3(0.40, 0.36, 0.36), _mat_hood)
	MeshBuilder.box(b, Vector3(0, 1.22, 0), Vector3(0.30, 0.16, 0.28), _mat_hood)
	# Mắt trắng sáng trong bóng tối mũ trùm
	MeshBuilder.box(b, Vector3(-0.09, 1.06, 0.19), Vector3(0.09, 0.07, 0.03), _mat_eye)
	MeshBuilder.box(b, Vector3(0.09, 1.06, 0.19), Vector3(0.09, 0.07, 0.03), _mat_eye)
	# Tay xương chìa ra khỏi tà áo
	MeshBuilder.box(b, Vector3(-0.30, 0.62, 0.05), Vector3(0.22, 0.10, 0.10), _mat_robe)
	MeshBuilder.box(b, Vector3(-0.45, 0.60, 0.05), Vector3(0.10, 0.09, 0.09), _mat_hand)
	MeshBuilder.box(b, Vector3(0.30, 0.62, 0.05), Vector3(0.22, 0.10, 0.10), _mat_robe)
	MeshBuilder.box(b, Vector3(0.45, 0.60, 0.05), Vector3(0.10, 0.09, 0.09), _mat_hand)

## Mắt sáng hơn khi đang tấn công (lúc nạp tia tối)
func set_charging(active: bool) -> void:
	if _mat_eye:
		if active:
			_mat_eye.emission_energy_multiplier = 5.0
		else:
			_mat_eye.emission_energy_multiplier = 3.0