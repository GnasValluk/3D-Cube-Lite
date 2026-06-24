## raptor/raptor_lightning.gd – Tia sét phóng thẳng đến mục tiêu (R skill)

extends Node3D
class_name RaptorLightning

const _life: float = 0.7
var _age: float = 0.0
var _root: Node3D
var _light: OmniLight3D
var _children_mat: Array[StandardMaterial3D] = []

func setup(origin: Vector3, targets: Array[Vector3], _owner: Node3D = null) -> void:
	global_position = origin
	_build(targets)

func _build(targets: Array[Vector3]) -> void:
	_root = Node3D.new()
	add_child(_root)

	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.80, 0.10)
	_light.light_energy = 18.0
	_light.omni_range = 25.0
	add_child(_light)

	var mat_flash: StandardMaterial3D = MeshBuilder.emit_mat(
		Color(1.0, 0.92, 0.30, 0.8), Color(1.0, 0.88, 0.20), 15.0)
	var sph: SphereMesh = SphereMesh.new()
	sph.radius = 0.18; sph.height = 0.36
	var flash: MeshInstance3D = MeshInstance3D.new()
	flash.mesh = sph; flash.material_override = mat_flash
	_root.add_child(flash)

	for t in targets:
		_create_bolt(t)

func _mat(color: Color, emit: Color, energy: float) -> StandardMaterial3D:
	var m: StandardMaterial3D = MeshBuilder.emit_mat(color, emit, energy)
	_children_mat.append(m)
	return m

func _create_bolt(target: Vector3) -> void:
	var diff: Vector3 = target - global_position
	var dist: float = diff.length()
	var fwd: Vector3 = diff / dist

	var seg_count: int = 3 + randi() % 3
	var prev: Vector3 = Vector3.ZERO

	for i in range(seg_count):
		var seg_end: float = float(i + 1) / float(seg_count)
		var pos: Vector3 = fwd * dist * seg_end
		if i < seg_count - 1:
			var spread: float = dist * 0.04
			pos += Vector3(
				(randf() - 0.5) * spread,
				(randf() - 0.5) * spread * 0.5,
				(randf() - 0.5) * spread)

		var seg_vec: Vector3 = pos - prev
		var seg_len: float = seg_vec.length()
		if seg_len < 0.01:
			prev = pos
			continue
		var seg_n: Vector3 = seg_vec / seg_len

		var mat: StandardMaterial3D = _mat(
			Color(1.0, 0.85, 0.20, 0.9 - float(i) * 0.08),
			Color(1.0, 0.80, 0.10), 10.0 - float(i) * 0.5)
		var mi: MeshInstance3D = MeshInstance3D.new()
		var c: CylinderMesh = CylinderMesh.new()
		c.top_radius = 0.025 - float(i) * 0.003
		c.bottom_radius = 0.04 - float(i) * 0.005
		c.height = seg_len
		mi.mesh = c; mi.material_override = mat
		mi.position = (prev + pos) * 0.5
		if seg_n != Vector3.UP and seg_n != Vector3.DOWN:
			mi.quaternion = Quaternion(Vector3.UP, seg_n)
		_root.add_child(mi)

		var mat_glow: StandardMaterial3D = _mat(
			Color(1.0, 0.90, 0.30, 0.7), Color(1.0, 0.85, 0.20), 8.0)
		var g: MeshInstance3D = MeshInstance3D.new()
		var sg: SphereMesh = SphereMesh.new()
		sg.radius = 0.04 + randf() * 0.02
		sg.height = sg.radius * 2.0
		g.mesh = sg; g.material_override = mat_glow
		g.position = pos
		_root.add_child(g)

		if i == seg_count - 1:
			var mat_hit: StandardMaterial3D = _mat(
				Color(1.0, 0.80, 0.10, 0.9), Color(1.0, 0.75, 0.05), 10.0)
			var h: MeshInstance3D = MeshInstance3D.new()
			var sh: SphereMesh = SphereMesh.new()
			sh.radius = 0.10 + randf() * 0.05
			sh.height = sh.radius * 2.0
			h.mesh = sh; h.material_override = mat_hit
			h.position = pos
			_root.add_child(h)

		if i < seg_count - 1 and randf() > 0.4:
			for k in range(1 + randi() % 2):
				var br_ang: float = randf() * TAU
				var br_tilt: float = (randf() * 0.6 + 0.3)
				var br_len: float = seg_len * (0.2 + randf() * 0.3)
				var br_dir: Vector3 = seg_n.rotated(Vector3.UP, br_ang)
				br_dir = br_dir.rotated(seg_n.cross(Vector3.UP).normalized(), br_tilt)
				var br_end: Vector3 = pos + br_dir * br_len

				var bmat: StandardMaterial3D = _mat(
					Color(1.0, 0.82, 0.15, 0.6), Color(1.0, 0.78, 0.08), 6.0)
				var bmi: MeshInstance3D = MeshInstance3D.new()
				var bc: CylinderMesh = CylinderMesh.new()
				bc.top_radius = 0.012
				bc.bottom_radius = 0.02
				bc.height = br_len
				bmi.mesh = bc; bmi.material_override = bmat
				bmi.position = pos + br_dir * br_len * 0.5
				if br_dir != Vector3.UP and br_dir != Vector3.DOWN:
					bmi.quaternion = Quaternion(Vector3.UP, br_dir)
				_root.add_child(bmi)

		prev = pos

func _process(delta: float) -> void:
	_age += delta
	var p: float = _age / _life
	_light.light_energy = 18.0 * max(1.0 - p * 2.0, 0.0)
	for m in _children_mat:
		m.emission_energy_multiplier = lerp(m.emission_energy_multiplier, 0.0, delta * 8.0)
	if _age >= _life:
		queue_free()
