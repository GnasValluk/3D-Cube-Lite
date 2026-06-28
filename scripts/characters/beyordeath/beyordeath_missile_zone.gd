extends Node3D
class_name BeyordeathMissileZone

var _age: float = 0.0
var _duration: float = 2.0
var _mat_ring: StandardMaterial3D
var _mat_core: StandardMaterial3D
var _rings: Array[MeshInstance3D] = []
var _ring_speeds: Array[float] = []
var _pivots: Array[Node3D] = []
var _owner: Node3D = null
var _pull_radius: float = 8.0
var _hit_radius: float = 2.0
var _hit_ids: Array[int] = []

func setup(pos: Vector3, owner: Node3D) -> void:
	global_position = pos
	_owner = owner
	_make_visual()

func _make_visual() -> void:
	_mat_ring = MeshBuilder.emit_mat(Color(0.30, 1.0, 0.40), Color(0.50, 1.0, 0.50), 8.0)
	_mat_core = MeshBuilder.emit_mat(Color(0.05, 0.10, 0.38), Color(0.05, 0.08, 0.35), 5.0)
	var core := MeshInstance3D.new()
	var csph := SphereMesh.new()
	csph.radius = 0.20
	csph.height = 0.40
	core.mesh = csph
	core.material_override = _mat_core
	add_child(core)
	var light := OmniLight3D.new()
	light.light_color = Color(0.25, 1.0, 0.35)
	light.light_energy = 8.0
	light.omni_range = 6.0
	add_child(light)
	for i in range(5):
		var px := Node3D.new()
		add_child(px)
		var mi := MeshInstance3D.new()
		var tor := TorusMesh.new()
		var ring_r: float = 0.3 + i * 0.18
		var tube_r: float = 0.02 + i * 0.004
		tor.inner_radius = ring_r - tube_r
		tor.outer_radius = ring_r + tube_r
		mi.mesh = tor
		mi.material_override = _mat_ring
		mi.rotation = Vector3(PI * 0.5, 0, 0)
		mi.rotation = mi.rotation.rotated(Vector3.RIGHT, (i + 1) * PI * 0.28)
		mi.rotation = mi.rotation.rotated(Vector3.FORWARD, i * PI * 0.22)
		px.add_child(mi)
		_rings.append(mi)
		_ring_speeds.append(1.8 + i * 0.5)
		_pivots.append(px)

func _find_mgr() -> Node:
	var p := get_parent()
	while p != null:
		if p is CharacterManager:
			return p
		p = p.get_parent()
	return null

func _process(delta: float) -> void:
	_age += delta
	var t := _age / _duration
	if t < 0.15:
		var s := t / 0.15
		scale = Vector3.ONE * s
	elif t > 0.6:
		var fade := (1.0 - t) / 0.4
		scale = Vector3.ONE * (1.0 + fade * 3.5)
		if t >= 1.0:
			queue_free()
	else:
		scale = Vector3.ONE * (1.0 + sin(_age * 8.0) * 0.05)
	for i in range(_pivots.size()):
		_pivots[i].rotation.y += _ring_speeds[i] * delta
	if t >= 0.85:
		_pull_and_hit(delta)

func _pull_and_hit(delta: float) -> void:
	var mgr: Node = _find_mgr()
	if mgr == null:
		return
	for ch in mgr.get_children():
		if ch is CharacterBase and ch.is_alive and ch != _owner:
			var off: Vector3 = global_position - ch.global_position
			off.y = 0.0
			var dist: float = off.length()
			if dist < _pull_radius and dist > 0.01:
				var pull_t: float = max(1.0 - dist / _pull_radius, 0.05)
				var speed: float = 22.0 * pull_t
				var target: Vector3 = Vector3(global_position.x, ch.global_position.y, global_position.z)
				ch.global_position = ch.global_position.move_toward(target, speed * delta)
				var cid: int = ch.get_instance_id()
				if dist < _hit_radius and not cid in _hit_ids:
					_hit_ids.append(cid)
					var dmg: int = _owner.calc_skill_damage(100) if _owner and _owner.has_method("calc_skill_damage") else 100
					ch.take_damage(dmg, _owner)
					ch.apply_dot(10, 1.0, 10.0, _owner)
