## slime/slime_mesh.gd
## Mesh procedural — slime xanh lá (Green Slime): lớp vỏ gel ngoài trong suốt
## dập dềnh + lõi nhân phát sáng ngọc lục bảo + mặt + đồ vật bị nuốt (slime to).
## Mesh dựng trong khối 1 đơn vị (1 block); kích thước thật do scale của character.

class_name SlimeMesh

var rig: Node3D

var _mat_shell:  StandardMaterial3D
var _mat_core:   StandardMaterial3D
var _mat_eye:    StandardMaterial3D
var _mat_mouth:  StandardMaterial3D
var _mat_bone:   StandardMaterial3D
var _mat_coin:   StandardMaterial3D
var _mat_ore:    StandardMaterial3D

var _prop_layer: Node3D
var _mouth_open: MeshInstance3D
var _mouth_pout: MeshInstance3D

## Vỏ gel nhọn góc — độ "tròn" (0.15 = tròn nhẹ, 0.35 = tròn hẳn)
var roundness: float = 0.28
## Lớp vỏ trong suốt (alpha) — mờ hơn khi nhỏ
var shell_alpha: float = 0.55
## Có đồ vật bị nuốt (slime to)
var show_props: bool = false

func build(root: Node3D) -> void:
	_make_materials()

	rig      = MeshBuilder.pivot(root, Vector3(0, 0.0, 0))
	rig.name = "SlimeRig"

	var shell := MeshBuilder.pivot(rig, Vector3.ZERO)
	shell.name = "SlimeShell"
	_build_shell(shell)

	var core := MeshBuilder.pivot(rig, Vector3(0, 0.0, 0))
	core.name = "SlimeCore"
	_build_core(core)

	if show_props:
		_prop_layer = MeshBuilder.pivot(rig, Vector3(0, 0.15, 0))
		_prop_layer.name = "SlimeProps"
		_build_props(_prop_layer)

func _make_materials() -> void:
	# Vỏ gel ngoài — trong suốt, xanh chanh (limelight), bóng nhẹ
	_mat_shell = StandardMaterial3D.new()
	_mat_shell.albedo_color = Color(0.55, 0.95, 0.45, shell_alpha)
	_mat_shell.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat_shell.roughness = 0.25
	_mat_shell.metallic = 0.1
	_mat_shell.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat_shell.emission_enabled = true
	_mat_shell.emission = Color(0.45, 0.75, 0.35)

	# Lõi nhân — xanh lục bảo thẫm, phát sáng
	_mat_core = MeshBuilder.emit_mat(Color(0.08, 0.35, 0.16), Color(0.15, 0.70, 0.35), 2.2)

	# Mắt — xanh đen, in nổi trên lõi nhân
	_mat_eye = MeshBuilder.emit_mat(Color(0.04, 0.06, 0.05), Color(0.0, 0.0, 0.0), 0.0)

	# Miệng — rãnh tối xanh đen
	_mat_mouth = MeshBuilder.emit_mat(Color(0.02, 0.05, 0.03), Color(0.0, 0.0, 0.0), 0.0)

	# Đồ bị nuốt
	_mat_bone = MeshBuilder.emit_mat(Color(0.88, 0.84, 0.72), Color(0, 0, 0), 0.0)
	_mat_coin = MeshBuilder.emit_mat(Color(0.95, 0.80, 0.25), Color(0.35, 0.25, 0.0), 0.6)
	_mat_ore  = MeshBuilder.emit_mat(Color(0.62, 0.50, 0.45), Color(0, 0, 0), 0.0)

func _build_shell(shell: Node3D) -> void:
	var r: float = roundness
	var w := 1.0
	# Lớp voxel tạo khối mô-chính bo tròn (nhìn như cục thạch)
	# Đáy dẹt, úp mặt xuống đất — top nhọn tròn dần
	MeshBuilder.box(shell, Vector3(0, 0.09, 0), Vector3(w * 0.86, 0.18, w * 0.86), _mat_shell)
	MeshBuilder.box(shell, Vector3(0, 0.27, 0), Vector3(w * 1.00, 0.18, w * 1.00), _mat_shell)
	MeshBuilder.box(shell, Vector3(0, 0.45, 0), Vector3(w * 0.94, 0.18, w * 0.94), _mat_shell)
	MeshBuilder.box(shell, Vector3(0, 0.63, 0), Vector3(w * 0.80, 0.18, w * 0.80), _mat_shell)
	MeshBuilder.box(shell, Vector3(0, 0.81, 0), Vector3(w * 0.58, 0.18, w * 0.58), _mat_shell)
	# Tai/vảy nhỏ phụ — tạo cảm giác gel đùn ra
	MeshBuilder.box(shell, Vector3(-w * 0.42, 0.36, 0), Vector3(w * 0.18, w * 0.16, w * 0.18), _mat_shell)
	MeshBuilder.box(shell, Vector3(w * 0.42, 0.36, 0), Vector3(w * 0.18, w * 0.16, w * 0.18), _mat_shell)

func _build_core(core: Node3D) -> void:
	# Lõi nhân nhỏ hơn lớp vỏ — xuyên thấy qua gel trong suốt
	MeshBuilder.box(core, Vector3(0, 0.42, 0), Vector3(0.68, 0.62, 0.68), _mat_core)
	MeshBuilder.box(core, Vector3(0, 0.70, 0), Vector3(0.50, 0.14, 0.50), _mat_core)
	# Mắt in nổi trên mặt trước lõi (+Z là hướng nhìn)
	MeshBuilder.box(core, Vector3(-0.15, 0.52, 0.36), Vector3(0.14, 0.16, 0.08), _mat_eye)
	MeshBuilder.box(core, Vector3(0.15, 0.52, 0.36), Vector3(0.14, 0.16, 0.08), _mat_eye)
	# Miệng — trạng thái "bĩu" (mím)
	var pout := MeshBuilder.box(core, Vector3(0, 0.36, 0.38), Vector3(0.30, 0.05, 0.06), _mat_mouth)
	_mouth_pout = pout
	# Miệng — trạng thái "há" khi tấn công
	var open := MeshBuilder.box(core, Vector3(0, 0.34, 0.40), Vector3(0.24, 0.16, 0.10), _mat_mouth)
	_mouth_open = open
	_mouth_open.visible = false
	_mouth_pout.visible = true

## Đổi biểu cảm miệng: true = há (tấn công), false = bĩu (bình thường/bị đánh)
func set_mouth_open(value: bool) -> void:
	if _mouth_open and _mouth_pout:
		_mouth_open.visible = value
		_mouth_pout.visible = not value

func _build_props(layer: Node3D) -> void:
	# Mẩu xương
	MeshBuilder.box(layer, Vector3(-0.16, 0.08, 0.12), Vector3(0.16, 0.05, 0.05), _mat_bone)
	MeshBuilder.box(layer, Vector3(-0.21, 0.13, 0.12), Vector3(0.05, 0.10, 0.04), _mat_bone)
	# Đồng xu (vàng)
	MeshBuilder.box(layer, Vector3(0.12, 0.06, -0.18), Vector3(0.12, 0.04, 0.12), _mat_coin)
	MeshBuilder.box(layer, Vector3(0.26, 0.02, -0.24), Vector3(0.10, 0.03, 0.10), _mat_coin)
	# Mẩu quặng sắt
	MeshBuilder.box(layer, Vector3(-0.20, 0.02, -0.20), Vector3(0.14, 0.12, 0.14), _mat_ore)
	MeshBuilder.box(layer, Vector3(-0.20, 0.02, -0.20), Vector3(0.05, 0.05, 0.05), MeshBuilder.emit_mat(Color(1.0, 0.6, 0.3), Color(1.0, 0.4, 0.1), 1.0))