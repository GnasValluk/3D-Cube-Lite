## dragon/dragon_atom_zone.gd – Vùng nguyên tử (AOE persistent)
## Ấn chú địa ngục: vòng tròn đỏ + hoạ tiết tím/cam/vàng dưới đất

extends Node3D
class_name DragonAtomZone

@export var damage_per_tick: int   = 25
@export var tick_interval:   float = 1.0
@export var duration:        float = 10.0
@export var radius:          float = 5.0

var _age:  float = 0.0
var _tick: float = 0.0
var _owner: Node3D = null
var _root: Node3D
var _light: OmniLight3D
var _mats: Array[StandardMaterial3D] = []
var _fading: bool = false

func _get_ground_y_at(pos: Vector3) -> float:
	var space := get_world_3d().direct_space_state
	if space == null:
		return pos.y
	var query := PhysicsRayQueryParameters3D.new()
	query.from = pos + Vector3(0, 20, 0)
	query.to   = pos - Vector3(0, 20, 0)
	query.collision_mask = 1
	var result := space.intersect_ray(query)
	if result.is_empty():
		return pos.y
	return result.position.y

func setup(pos: Vector3, owner: Node3D) -> void:
	_owner = owner
	var ground_y: float = _get_ground_y_at(pos)
	global_position = Vector3(pos.x, ground_y, pos.z)
	_build()

func _mat(c: Color, e: Color, en: float) -> StandardMaterial3D:
	var m: StandardMaterial3D = MeshBuilder.emit_mat(c, e, en)
	_mats.append(m)
	return m

func _dot(pos: Vector3, r: float, color: Color, emit: Color, energy: float, alpha: float = 0.9) -> void:
	var mat: StandardMaterial3D = _mat(Color(color.r, color.g, color.b, alpha), emit, energy)
	var mi: MeshInstance3D = MeshInstance3D.new()
	var sp: SphereMesh = SphereMesh.new()
	sp.radius = r; sp.height = r * 2.0
	mi.mesh = sp; mi.material_override = mat
	mi.position = pos
	_root.add_child(mi)

func _circle(num_dots: int, ring_r: float, dot_r: float, y: float,
			color: Color, emit: Color, energy: float, alpha: float = 0.9) -> void:
	for i in range(num_dots):
		var a: float = float(i) / num_dots * TAU
		var pos: Vector3 = Vector3(cos(a) * ring_r, y, sin(a) * ring_r)
		_dot(pos, dot_r, color, emit, energy, alpha)

func _build() -> void:
	_root = Node3D.new()
	add_child(_root)

	# Vòng tròn đỏ chính - viền ngoài: chấm dày
	_circle(36, radius, 0.05, 0.003, Color(1.0, 0.05, 0.10), Color(1.0, 0.0, 0.05), 9.0)

	# Vòng tròn đỏ 2 - gần ngoài: chấm vừa
	_circle(30, radius * 0.85, 0.035, 0.004, Color(0.90, 0.0, 0.15), Color(1.0, 0.0, 0.10), 7.0)

	# Vòng cam
	_circle(24, radius * 0.70, 0.03, 0.005, Color(1.0, 0.40, 0.0), Color(1.0, 0.35, 0.0), 7.0)

	# Vòng tím
	_circle(20, radius * 0.55, 0.03, 0.005, Color(0.60, 0.0, 0.75), Color(0.70, 0.0, 0.80), 6.0)

	# Vòng vàng
	_circle(18, radius * 0.42, 0.025, 0.006, Color(1.0, 0.80, 0.0), Color(1.0, 0.75, 0.0), 7.0)

	# Vòng tím đậm
	_circle(16, radius * 0.30, 0.025, 0.006, Color(0.50, 0.0, 0.60), Color(0.55, 0.0, 0.65), 5.0)

	# Vòng đỏ trong cùng
	_circle(12, radius * 0.18, 0.025, 0.007, Color(0.95, 0.0, 0.20), Color(1.0, 0.0, 0.15), 8.0)

	# Tâm: chấm tím to
	_dot(Vector3(0, 0.008, 0), 0.10, Color(0.70, 0.0, 0.80), Color(0.80, 0.0, 0.90), 12.0)
	_dot(Vector3(0, 0.012, 0), 0.05, Color(1.0, 0.80, 0.0), Color(1.0, 0.75, 0.0), 10.0)

	# 8 trụ lửa (chấm cam đỏ) quanh vòng ngoài
	for i in range(8):
		var a: float = float(i) / 8.0 * TAU
		var r: float = radius + 0.10
		var col: Color = Color(0.90 + sin(a) * 0.10, 0.20 + cos(a * 2.0) * 0.15, 0.0)
		_dot(Vector3(cos(a) * r, 0.003, sin(a) * r), 0.06,
			col, Color(col.r, col.g, 0.0), 9.0 + sin(a * 3.0) * 2.0)

	# Chữ rune (chấm nhỏ) giữa các trụ lửa
	for i in range(8):
		var a: float = (float(i) + 0.5) / 8.0 * TAU
		var r: float = radius + 0.02
		_dot(Vector3(cos(a) * r, 0.006, sin(a) * r), 0.035,
			Color(0.65, 0.0, 0.75), Color(0.75, 0.0, 0.80), 7.0)

	# Tia lửa từ tâm (chấm nhỏ dần)
	for i in range(16):
		var a: float = float(i) / 16.0 * TAU
		for j in range(6):
			var t: float = float(j + 1) / 6.0
			var rr: float = radius * 0.85 * t
			var dot_r: float = 0.015 * (1.0 - t * 0.5)
			var col_spark: Color
			if j % 3 == 0:
				col_spark = Color(1.0, 0.50, 0.0)
			elif j % 3 == 1:
				col_spark = Color(0.95, 0.0, 0.20)
			else:
				col_spark = Color(0.60, 0.0, 0.70)
			_dot(Vector3(cos(a) * rr, 0.004 + t * 0.002, sin(a) * rr), dot_r,
				col_spark, Color(col_spark.r, col_spark.g, col_spark.b), 6.0 - t * 2.0, 0.7 - t * 0.3)

	_light = OmniLight3D.new()
	_light.light_color = Color(0.90, 0.20, 0.05)
	_light.light_energy = 0.0
	_light.omni_range = 15.0
	_light.light_specular = 0.0
	_light.position = Vector3(0, 0.3, 0)
	add_child(_light)

	_root.scale = Vector3.ZERO

func _physics_process(delta: float) -> void:
	if _fading:
		return
	_pull_enemies(delta)

func _process(delta: float) -> void:
	if _fading:
		return
	_age += delta
	_tick += delta

	const ENTRY_DURATION: float = 0.4
	var entry_p: float = clamp(_age / ENTRY_DURATION, 0.0, 1.0)
	var entry_smooth: float = smoothstep(0.0, 1.0, entry_p)

	_root.scale = Vector3(entry_smooth, entry_smooth, entry_smooth)
	if entry_smooth < 1.0:
		_root.rotation.y += delta * 0.3 * entry_smooth

	_light.light_energy = entry_smooth * (8.0 + sin(_age * 5.0) * 3.0)
	_light.light_color = Color(
		0.90 + sin(_age * 3.0) * 0.08,
		0.20 + sin(_age * 4.0) * 0.10,
		0.05 + sin(_age * 2.0) * 0.05)

	if entry_p >= 1.0:
		_root.rotation.y += delta * 0.3
		var sp: float = 1.0 + sin(_age * 2.5) * 0.01
		_root.scale = Vector3(sp, sp, sp)

	if _tick >= tick_interval:
		_tick = 0.0
		_deal_damage()

	if _age >= duration:
		_fade_out()

func _fade_out() -> void:
	_fading = true
	var t: Tween = create_tween()
	t.set_parallel(true)
	t.tween_property(_light, "light_energy", 0.0, 0.3)
	for m in _mats:
		if is_instance_valid(m):
			t.tween_property(m, "emission_energy_multiplier", 0.0, 0.3)
			t.tween_property(m, "albedo_color:a", 0.0, 0.3)
	t.tween_callback(queue_free)

func _find_mgr() -> Node:
	var p: Node = get_parent()
	while p != null:
		if p is CharacterManager:
			return p
		p = p.get_parent()
	return null

func _pull_enemies(delta: float) -> void:
	var mgr: Node = _find_mgr()
	if mgr == null:
		return
	for ch in mgr.get_children():
		if ch is CharacterBase and ch.is_alive and ch._active and ch != _owner:
			var off: Vector3 = global_position - ch.global_position
			off.y = 0.0
			var dist: float = off.length()
			if dist < radius and dist > 0.01:
				var pull_t: float = max(1.0 - dist / radius, 0.15)
				var speed: float = 6.0 * pull_t
				var target: Vector3 = Vector3(global_position.x, ch.global_position.y, global_position.z)
				ch.global_position = ch.global_position.move_toward(target, speed * delta)

func _deal_damage() -> void:
	var mgr: Node = _find_mgr()
	if mgr == null:
		return
	for ch in mgr.get_children():
		if ch is CharacterBase and ch.is_alive and ch._active and ch != _owner:
			var off: Vector3 = global_position - ch.global_position
			off.y = 0.0
			if off.length() < radius:
				var dmg: int = _owner.calc_skill_damage(damage_per_tick) if _owner and _owner.has_method("calc_skill_damage") else damage_per_tick
				ch.take_damage(dmg, _owner)