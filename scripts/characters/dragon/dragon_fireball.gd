## dragon/dragon_fireball.gd
## Quả cầu lửa khè của rồng – bay thẳng về phía trước, tự xoá sau khi hết tầm.
## Spawn từ dragon_character.gd, add vào scene root.

extends Node3D
class_name DragonFireball

@export var speed:     float = 22.0   # tốc độ bay (units/s)
@export var lifetime:  float = 1.8    # tự xoá sau (giây)
@export var radius:    float = 0.22   # bán kính quả cầu

var _dir:      Vector3 = Vector3.FORWARD
var _age:      float   = 0.0
var _mesh_root: Node3D

# ── Build ─────────────────────────────────────────────────────────────────────
func setup(origin: Vector3, direction: Vector3) -> void:
	global_position = origin
	_dir = direction.normalized()
	_build_visual()

func _build_visual() -> void:
	_mesh_root = Node3D.new()
	add_child(_mesh_root)

	# Core – quả cầu lửa chính
	var mat_core := MeshBuilder.emit_mat(
		Color(1.0, 0.45, 0.05),
		Color(1.0, 0.30, 0.0), 5.0)
	MeshBuilder.sphere(_mesh_root, Vector3.ZERO, radius, mat_core)

	# Lớp ngoài – hào quang tím
	var mat_halo := MeshBuilder.emit_mat(
		Color(0.8, 0.1, 1.0),
		Color(0.7, 0.0, 1.0), 3.0)
	MeshBuilder.sphere(_mesh_root, Vector3.ZERO, radius * 1.45, mat_halo)

	# Các mảnh lửa xung quanh – 6 sphere nhỏ quay quanh core
	var mat_spark := MeshBuilder.emit_mat(
		Color(1.0, 0.8, 0.1),
		Color(1.0, 0.7, 0.0), 4.0)
	for i in range(6):
		var a: float = float(i) / 6.0 * TAU
		MeshBuilder.sphere(_mesh_root,
			Vector3(cos(a), sin(a), 0.0) * radius * 0.9,
			radius * 0.28, mat_spark)

	# OmniLight – ánh sáng đỏ cam
	var light := OmniLight3D.new()
	light.light_color  = Color(1.0, 0.4, 0.0)
	light.light_energy = 5.0
	light.omni_range   = 4.5
	add_child(light)

# ── Process ───────────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	_age += delta

	# Xoay mesh_root để tạo cảm giác cầu lửa đang xoáy
	_mesh_root.rotation.z += delta * 4.0
	_mesh_root.rotation.y += delta * 2.5

	# Bay thẳng
	global_position += _dir * speed * delta

	# Pulse scale nhẹ
	var pulse: float = 1.0 + sin(_age * 12.0) * 0.08
	_mesh_root.scale = Vector3(pulse, pulse, pulse)

	if _age >= lifetime:
		_explode()

func _explode() -> void:
	# Flash nhỏ rồi xoá
	var flash := OmniLight3D.new()
	flash.light_color  = Color(1.0, 0.5, 0.0)
	flash.light_energy = 12.0
	flash.omni_range   = 6.0
	get_parent().add_child(flash)
	flash.global_position = global_position
	get_tree().create_timer(0.15).timeout.connect(func(): flash.queue_free())
	queue_free()
