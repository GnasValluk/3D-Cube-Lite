class_name TavernDoor
extends Node3D

## ── Cửa quán rượu — mở/đóng được ──────────────────────────────────────────────
## Đặt tại buildingổ (node có rotation.y = yaw). Cánh cửa treo trên bản lề cạnh
## trái, mở vào trong, có collision đóng/mở. Phát hiện người chơi qua Area3D.

const COL_DOOR:    Color = Color(0.36, 0.24, 0.14)
const COL_DOOR_DK: Color = Color(0.20, 0.13, 0.07)
const COL_HANDLE:  Color = Color(0.85, 0.75, 0.38)

const OPEN_ANGLE: float = deg_to_rad(-100.0)  # quay vào trong
const HINGE_X:    float = -0.775                 # trục bản lh1 lề (trái, nhìn ngoài)
const PANEL_W:    float = 1.55
const PANEL_H:    float = 2.05
const PANEL_T:    float = 0.30
const DOOR_Z:     float = -2.62

var _hinge: Node3D
var _panel: MeshInstance3D
var _door_body: StaticBody3D
var _col: CollisionShape3D
var _open: bool = false
var _player_nearby: bool = false
var _tween: Tween

func _ready() -> void:
	_hinge = Node3D.new()
	_hinge.position = Vector3(HINGE_X, 0.0, DOOR_Z)
	add_child(_hinge)

	var panel_mat := StandardMaterial3D.new()
	panel_mat.albedo_color = COL_DOOR
	var pan := BoxMesh.new()
	pan.size = Vector3(PANEL_W, PANEL_H, PANEL_T)
	_panel = MeshInstance3D.new()
	_panel.mesh = pan
	_panel.material_override = panel_mat
	_panel.position = Vector3(PANEL_W * 0.5, PANEL_H * 0.5, 0.0)
	_hinge.add_child(_panel)

	# ván gỗ dọc trang trí trên cánh + tay cầm cạnh lề còn lại
	var plank := BoxMesh.new()
	plank.size = Vector3(0.10, PANEL_H - 0.5, PANEL_T + 0.02)
	var plank_mat := StandardMaterial3D.new()
	plank_mat.albedo_color = COL_DOOR_DK
	for px in [0.45, 1.05]:
		var plank_mi := MeshInstance3D.new()
		plank_mi.mesh = plank
		plank_mi.material_override = plank_mat
		plank_mi.position = Vector3(PANEL_W * 0.5 + px - 0.65, PANEL_H * 0.5, 0.0)
		_hinge.add_child(plank_mi)

	var hmat := StandardMaterial3D.new()
	hmat.albedo_color = COL_HANDLE
	var handle := BoxMesh.new()
	handle.size = Vector3(0.26, 0.10, 0.10)
	var handle_mi := MeshInstance3D.new()
	handle_mi.mesh = handle
	handle_mi.material_override = hmat
	handle_mi.position = Vector3(PANEL_W - 0.22, PANEL_H * 0.5 - 0.1, -PANEL_T * 0.5 - 0.02)
	_hinge.add_child(handle_mi)

	_door_body = StaticBody3D.new()
	_col = CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3(PANEL_W, PANEL_H, PANEL_T)
	_col.shape = sh
	_col.position = Vector3(PANEL_W * 0.5, PANEL_H * 0.5, 0.0)
	_door_body.add_child(_col)
	_hinge.add_child(_door_body)

	add_to_group("tavern_doors")
	_setup_area()

func _setup_area() -> void:
	var area := Area3D.new()
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 1.5
	cs.shape = sph
	area.add_child(cs)
	area.position = Vector3(0.0, 1.0, DOOR_Z)
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	add_child(area)

func _on_body_entered(body: Node) -> void:
	if body is PlayerCharacter:
		_player_nearby = true

func _on_body_exited(body: Node) -> void:
	if body is PlayerCharacter:
		_player_nearby = false

func is_player_nearby() -> bool:
	return _player_nearby

func toggle() -> void:
	_open = not _open
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if _open:
		_col.set_deferred("disabled", true)
		_tween.tween_property(_hinge, "rotation:y", OPEN_ANGLE, 0.55)
	else:
		_col.set_deferred("disabled", false)
		_tween.tween_property(_hinge, "rotation:y", 0.0, 0.55)
