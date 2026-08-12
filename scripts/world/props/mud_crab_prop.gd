class_name MudCrabProp
extends DestroyableProp

## Cua bùn rừng ngập mặn — cua nhỏ đứng im trên bãi bùn, thỉnh thoảng lủi
## ngang vài bước rồi đứng yên. Rơi thịt cua ("mud_crab") khi chặt.

var _bob_phase: float
var _bob_timer: float = 0.0
var _move_timer: float = 0.0
var _move_left: float = 0.0
var _move_dir: Vector3 = Vector3.ZERO
var _moving: bool = false

func setup() -> void:
	pass

func _ready() -> void:
	super._ready()
	_build_crab()
	_setup_collision()
	_bob_phase = randf() * TAU
	_move_timer = randf_range(4.0, 9.0)

func _setup_collision() -> void:
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.42, 0.22, 0.4)
	col.shape = shape
	col.position.y = 0.14
	body.add_child(col)
	add_child(body)

func _build_crab() -> void:
	var col_shell := Color(0.44, 0.22, 0.12)
	var col_leg := Color(0.33, 0.17, 0.10)
	var col_claw := Color(0.52, 0.26, 0.14)
	var col_eye := Color(0.08, 0.06, 0.05)

	# Thân (mai) — khối dẹt thuôn
	_add_box(Vector3(0.0, 0.12, 0.0), Vector3(0.30, 0.16, 0.26), col_shell)
	_add_box(Vector3(0.0, 0.16, 0.0), Vector3(0.24, 0.06, 0.20), col_shell)
	# Đuôi gập dưới mai
	_add_box(Vector3(0.0, 0.08, 0.14), Vector3(0.22, 0.10, 0.10), col_shell.darkened(0.12))

	# 4 chân mỗi bên — cong ra rồi xuống bùn
	for side in [-1.0, 1.0]:
		for li in range(4):
			var z_off: float = -0.16 + li * 0.10
			var reach: float = 0.11 + (li % 2) * 0.03
			_add_box(Vector3(side * 0.20, 0.06, z_off), Vector3(0.04, 0.04, 0.03), col_leg)
			_add_box(Vector3(side * (0.20 + reach), 0.015, z_off), Vector3(0.04, 0.03, 0.03), col_leg)
	# Càng — đòn tay nhô ra trước, quả càng mọc lên
	for side in [-1.0, 1.0]:
		_add_box(Vector3(side * 0.22, 0.10, -0.16), Vector3(0.05, 0.05, 0.22), col_leg)
		_add_box(Vector3(side * 0.22, 0.17, -0.26), Vector3(0.09, 0.10, 0.06), col_claw)
		_add_box(Vector3(side * 0.22, 0.17, -0.32), Vector3(0.06, 0.05, 0.06), col_claw.darkened(0.1))
	# Mắt — cuống nhỏ + hạt mắt
	for side in [-1.0, 1.0]:
		_add_box(Vector3(side * 0.10, 0.24, 0.02), Vector3(0.03, 0.06, 0.03), col_leg)
		_add_box(Vector3(side * 0.10, 0.29, 0.02), Vector3(0.055, 0.055, 0.055), col_eye)

func _add_box(pos: Vector3, size: Vector3, col: Color) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.metallic = 0.05
	mat.roughness = 0.55
	mi.material_override = mat
	add_child(mi)

func _process(delta: float) -> void:
	_bob_timer += delta
	if _bob_timer > 0.5:
		_bob_timer = 0.0
		# Nhịp thở — nghiêng nhẹ thân
		var s := sin(Time.get_ticks_usec() * 0.000001 * 3.0 + _bob_phase)
		rotation.z = s * 0.06
		position.y = position.y - s * 0.012
	_move_timer -= delta
	if _move_timer <= 0.0:
		_move_timer = randf_range(4.0, 9.0)
		if not _moving and randf() < 0.45:
			var a := randf() * TAU
			_move_dir = Vector3(cos(a), 0, sin(a))
			_move_left = 0.4 + randf() * 0.5
			_moving = true
	if _moving:
		_move_dir = _move_dir.normalized()
		position += _move_dir * delta * 0.6
		rotation.y = lerp_angle(rotation.y, atan2(_move_dir.x, _move_dir.z), delta * 4.0)
		_move_left -= delta
		if _move_left <= 0.0:
			_moving = false