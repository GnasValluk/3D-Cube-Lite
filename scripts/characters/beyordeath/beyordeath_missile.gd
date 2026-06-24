extends Node3D
class_name BeyordeathMissile

@export var speed: float = 18.0
@export var lifetime: float = 4.0
@export var turn_rate: float = 3.0

var _dir: Vector3 = Vector3.FORWARD
var _age: float = 0.0
var _owner: Node3D = null
var _target: CharacterBase = null
var _spawn_pos: Vector3 = Vector3.ZERO

var _mat_body: StandardMaterial3D
var _mat_glow: StandardMaterial3D

var _offset_angle: float = 0.0

func setup(origin: Vector3, direction: Vector3, owner: Node3D) -> void:
	global_position = origin
	_dir = direction.normalized()
	_owner = owner
	_spawn_pos = origin
	_make_materials()
	_build_visual()
	_find_target()
	_offset_angle = randf_range(0, TAU)

func _make_materials() -> void:
	var green := Color(0.30, 1.0, 0.40)
	_mat_body = MeshBuilder.emit_mat(Color(0.10, 0.12, 0.14), green * 0.3, 0.5)
	_mat_glow = MeshBuilder.emit_mat(green, Color(0.50, 1.0, 0.50), 6.0)

func _build_visual() -> void:
	var body := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.04
	cyl.bottom_radius = 0.06
	cyl.height = 0.35
	body.mesh = cyl
	body.material_override = _mat_body
	body.position = Vector3(0, 0, 0.05)
	add_child(body)
	var nose := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.045
	sph.height = 0.09
	sph.radial_segments = 8
	nose.mesh = sph
	nose.material_override = _mat_glow
	nose.position = Vector3(0, 0, 0.22)
	add_child(nose)
	for side in [-1, 1]:
		var fin := MeshInstance3D.new()
		var fm := BoxMesh.new()
		fm.size = Vector3(0.02, 0.08, 0.06)
		fin.mesh = fm
		fin.material_override = _mat_body
		fin.position = Vector3(side * 0.06, -0.02, -0.10)
		add_child(fin)
	var trail := OmniLight3D.new()
	trail.light_color = Color(0.25, 1.0, 0.35)
	trail.light_energy = 2.0
	trail.omni_range = 2.5
	add_child(trail)

func _find_target() -> void:
	var mgr := _find_manager()
	if mgr == null:
		return
	var best: CharacterBase = null
	var best_dsq: float = 100.0
	for ch in mgr.get_children():
		if ch is CharacterBase and ch != _owner and ch.is_alive and not ch._is_player:
			var dsq := global_position.distance_squared_to(ch.global_position)
			if dsq < best_dsq:
				best_dsq = dsq
				best = ch as CharacterBase
	if best and best_dsq < 400.0:
		_target = best

func _find_manager() -> Node:
	var p := get_parent()
	while p != null:
		if p is CharacterManager:
			return p
		p = p.get_parent()
	return null

func _process(delta: float) -> void:
	_age += delta
	if _target and is_instance_valid(_target):
		var to_target: Vector3 = _target.global_position - global_position
		to_target.y = 0.0
		if to_target.length_squared() > 0.01:
			var desired: Vector3 = to_target.normalized()
			var perp := Vector3(0, 1, 0).cross(desired).normalized()
			if perp.length_squared() < 0.01:
				perp = Vector3.RIGHT
			var wave: float = sin(_age * 5.0 + _offset_angle) * 0.25
			desired = desired.rotated(Vector3.UP, wave)
			_dir = _dir.slerp(desired, turn_rate * delta).normalized()
	_dir = _dir.normalized()
	look_at(global_position + _dir, Vector3.UP)
	global_position += _dir * speed * delta
	var mgr := _find_manager()
	if mgr == null:
		queue_free()
		return
	for ch in mgr.get_children():
		if ch is CharacterBase and ch != _owner and ch.is_alive:
			var offset: Vector3 = global_position - ch.global_position
			offset.y = 0.0
			if offset.length() < 0.8:
				_hit_target(ch)
				return
	if _age >= lifetime:
		_spawn_vfx(global_position)
		queue_free()

func _hit_target(ch: CharacterBase) -> void:
	var parent := get_parent()
	if parent == null:
		return
	if is_instance_valid(ch):
		ch.take_damage(100, _owner)
	_spawn_vfx(ch.global_position if is_instance_valid(ch) else global_position)
	queue_free()

func _spawn_vfx(pos: Vector3) -> void:
	var parent := get_parent()
	if parent == null:
		return
	var vfx := BeyordeathMissileZone.new()
	parent.add_child(vfx)
	vfx.setup(pos, _owner)
