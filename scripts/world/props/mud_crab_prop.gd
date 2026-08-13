class_name MudCrabProp
extends DestroyableProp

## Cua bùn rừng ngập mặn — cua nhỏ đứng trên bãi bùn, thỉnh thoảng lủi
## ngang vài bước rồi đứng yên. Chân xoay/gập liên tục (nhịp sống), càng
## gập liu-riêu, mỗi cánh tay độc lập (phase offset). Rơi thịt cua ("mud_crab")
## khi chặt. HP thấp (5) để damage rõ rệt.

const MAX_HP := 5

var _bob_phase: float
var _bob_timer: float = 0.0
var _move_timer: float = 0.0
var _move_left: float = 0.0
var _move_dir: Vector3 = Vector3.ZERO
var _moving: bool = false
var _walk_phase: float = 0.0

# Nhóm node để animate
var _legs: Array[Node3D] = []
var _claws: Array[Node3D] = []
var _leg_offsets: Array[Vector3] = []
var _leg_phases: Array[float] = []
var _claw_phases: Array[float] = []

func setup() -> void:
	pass

func _init(p_max_hp: int = MAX_HP, p_weapon_req: int = WeaponReq.NONE, p_drop_id: String = "mud_crab") -> void:
	# Luôn dùng HP thấp (MAX_HP) để damage rõ rệt; bỏ qua p_max_hp truyền vào
	super(MAX_HP, p_weapon_req, p_drop_id)

func _ready() -> void:
	super._ready()
	_bob_phase = randf() * TAU
	_move_timer = randf_range(4.0, 9.0)
	_build_crab()
	_setup_collision()
	_reset_leg_offsets()

func _setup_collision() -> void:
	var body := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.42, 0.22, 0.4)
	col.shape = shape
	col.position.y = 0.14
	body.add_child(col)
	add_child(body)

func _reset_leg_offsets() -> void:
	_leg_offsets.resize(_legs.size())
	_leg_phases.resize(_legs.size())
	for i in _legs.size():
		_leg_offsets[i] = _legs[i].position
		_leg_phases[i] = float(i) / max(1.0, float(_legs.size())) * TAU + _bob_phase

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
	var leg_idx := 0
	for side in [-1.0, 1.0]:
		for li in range(4):
			var z_off: float = -0.16 + li * 0.10
			var reach: float = 0.11 + (li % 2) * 0.03
			_legs.append(_add_box(Vector3(side * 0.20, 0.06, z_off), Vector3(0.04, 0.04, 0.03), col_leg))
			_legs.append(_add_box(Vector3(side * (0.20 + reach), 0.015, z_off), Vector3(0.04, 0.03, 0.03), col_leg))
			leg_idx += 1
	# Reset phase offsets now that legs populated
	if _leg_phases.size() != _legs.size():
		_reset_leg_offsets()

	# Càng — đòn tay nhô ra trước, quả càng mọc lên
	for side in [-1.0, 1.0]:
		_add_box(Vector3(side * 0.22, 0.10, -0.16), Vector3(0.05, 0.05, 0.22), col_leg)
		var c1 := _add_box(Vector3(side * 0.22, 0.17, -0.26), Vector3(0.09, 0.10, 0.06), col_claw)
		var c2 := _add_box(Vector3(side * 0.22, 0.17, -0.32), Vector3(0.06, 0.05, 0.06), col_claw.darkened(0.1))
		_claws.append(c1)
		_claws.append(c2)
	_claw_phases.resize(_claws.size())
	for i in _claws.size():
		_claw_phases[i] = float(i) / max(1.0, float(_claws.size())) * TAU + _bob_phase

	# Mắt — cuống nhỏ + hạt mắt
	for side in [-1.0, 1.0]:
		_add_box(Vector3(side * 0.10, 0.24, 0.02), Vector3(0.03, 0.06, 0.03), col_leg)
		_add_box(Vector3(side * 0.10, 0.29, 0.02), Vector3(0.055, 0.055, 0.055), col_eye)

func _add_box(pos: Vector3, size: Vector3, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.metallic = 0.05
	mat.roughness = 0.55
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	add_child(mi)
	return mi

func _process(delta: float) -> void:
	_bob_timer += delta
	_walk_phase += delta
	var t := Time.get_ticks_usec() * 0.000001
	if _bob_timer > 0.5:
		_bob_timer = 0.0
		# Nhịp thở — nghiêng nhẹ thân
		var s := sin(t * 3.0 + _bob_phase)
		rotation.z = s * 0.06
		position.y = position.y - s * 0.012

	# Animate từng chân: gập/lun lên-xuống + quay nhẹ
	var wag_amp := 0.025
	for i in _legs.size():
		var base := _leg_offsets[i]
		var ph := _leg_phases[i]
		var swing := sin(_walk_phase * 4.0 + ph)
		var leg := _legs[i]
		leg.position = base + Vector3(swing * wag_amp, absf(swing) * wag_amp, 0.0)
		leg.rotation = Vector3(swing * 0.4, 0.0, 0.0)

	# Animate càng: gập liu-riêu, cánh tay tay đối xứng (phase Δ)
	var claw_close := 0.35
	if _moving:
		claw_close += 0.2
	for i in _claws.size():
		var c := _claws[i]
		var ph := _claw_phases[i]
		var pinch := sin(t * 3.5 + ph) * claw_close
		c.rotation = Vector3(0.0, pinch * 0.6, 0.0)

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
		# Dời toàn bộ thân (legs/claws/mắt follow) theo hướng di chuyển
		position += _move_dir * delta * 0.6
		rotation.y = lerp_angle(rotation.y, atan2(_move_dir.x, _move_dir.z), delta * 4.0)
		_move_left -= delta
		if _move_left <= 0.0:
			_moving = false
