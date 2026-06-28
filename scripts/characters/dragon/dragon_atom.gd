## dragon/dragon_atom.gd – Quả cầu nguyên tử (R skill)
## Bay thẳng, khi trúng địch/hết đời tạo vùng nguyên tử AOE

extends Node3D
class_name DragonAtom

@export var speed:     float = 18.0
@export var lifetime:  float = 2.0
@export var zone_duration: float = 10.0
@export var zone_radius:   float = 5.0
@export var zone_damage:   int   = 25
@export var zone_interval: float = 1.0

var _dir:  Vector3 = Vector3.FORWARD
var _age:  float = 0.0
var _owner: Node3D = null
var _root: Node3D
var _light: OmniLight3D
var _orbit: Array[MeshInstance3D] = []
var _hit:   bool = false

func setup(origin: Vector3, direction: Vector3, owner: Node3D) -> void:
	_owner = owner
	_dir = direction.normalized()
	global_position = origin
	_build()

func _build() -> void:
	_root = Node3D.new()
	add_child(_root)

	var mat_core: StandardMaterial3D = MeshBuilder.emit_mat(
		Color(0.85, 0.05, 0.35, 0.95),
		Color(1.0, 0.0, 0.25), 14.0)
	var core: MeshInstance3D = MeshInstance3D.new()
	var sph: SphereMesh = SphereMesh.new()
	sph.radius = 0.22; sph.height = 0.44
	core.mesh = sph; core.material_override = mat_core
	_root.add_child(core)

	var mat_glow: StandardMaterial3D = MeshBuilder.emit_mat(
		Color(0.60, 0.0, 0.50, 0.5),
		Color(0.70, 0.0, 0.40), 9.0)
	var glow: MeshInstance3D = MeshInstance3D.new()
	var sg: SphereMesh = SphereMesh.new()
	sg.radius = 0.40; sg.height = 0.80
	glow.mesh = sg; glow.material_override = mat_glow
	_root.add_child(glow)

	var mat_halo: StandardMaterial3D = MeshBuilder.emit_mat(
		Color(0.70, 0.0, 0.45, 0.3),
		Color(0.80, 0.0, 0.35), 5.0)
	var halo: MeshInstance3D = MeshInstance3D.new()
	var sh: SphereMesh = SphereMesh.new()
	sh.radius = 0.65; sh.height = 1.30
	halo.mesh = sh; halo.material_override = mat_halo
	halo.scale = Vector3(1.0, 0.3, 1.0)
	_root.add_child(halo)

	for i in range(4):
		var mat_ring: StandardMaterial3D = MeshBuilder.emit_mat(
			Color(0.80, 0.0, 0.40, 0.6),
			Color(1.0, 0.0, 0.30), 7.0)
		var mi: MeshInstance3D = MeshInstance3D.new()
		var tor: TorusMesh = TorusMesh.new()
		tor.inner_radius = 0.40 + float(i) * 0.12
		tor.outer_radius = 0.025
		mi.mesh = tor; mi.material_override = mat_ring
		var ang: float = float(i) * 1.57
		mi.rotation = Vector3(ang, ang * 0.5, ang * 0.2)
		_root.add_child(mi)
		_orbit.append(mi)

	for i in range(8):
		var a: float = float(i) / 8.0 * TAU
		var r: float = 0.35 + randf() * 0.20
		var pos: Vector3 = Vector3(cos(a) * r, sin(a * 2.0) * 0.10, sin(a) * r)
		var mat_e: StandardMaterial3D = MeshBuilder.emit_mat(
			Color(0.90, 0.0, 0.30 + randf()*0.20, 0.8),
			Color(1.0, 0.0, 0.30), 9.0 + randf() * 3.0)
		var ei: MeshInstance3D = MeshInstance3D.new()
		var es: SphereMesh = SphereMesh.new()
		es.radius = 0.03 + randf() * 0.02; es.height = es.radius * 2.0
		ei.mesh = es; ei.material_override = mat_e
		ei.position = pos
		_root.add_child(ei)

	_light = OmniLight3D.new()
	_light.light_color = Color(0.80, 0.0, 0.45)
	_light.light_energy = 9.0
	_light.omni_range = 10.0
	add_child(_light)

func _process(delta: float) -> void:
	if _hit:
		return
	_age += delta

	_root.rotation.x += delta * 3.0
	_root.rotation.z += delta * 2.0
	var pulse: float = 1.0 + sin(_age * 10.0) * 0.06
	_root.scale = Vector3(pulse, pulse, pulse)

	_light.light_energy = 7.0 + sin(_age * 12.0) * 2.0

	global_position += _dir * speed * delta
	_check_hit()

	if _age >= lifetime:
		_spawn_zone()
		queue_free()

func _check_hit() -> void:
	var mgr: Node = _find_mgr()
	if mgr == null:
		return
	for ch in mgr.get_children():
		if ch is CharacterBase and ch.is_alive and ch._active and ch != _owner:
			var off: Vector3 = global_position - ch.global_position
			off.y = 0.0
			if off.length() < 1.2:
				_spawn_zone()
				queue_free()
				return

func _find_mgr() -> Node:
	var p: Node = get_parent()
	while p != null:
		if p is CharacterManager:
			return p
		p = p.get_parent()
	return null

func _spawn_zone() -> void:
	var parent := get_parent()
	if parent == null:
		return
	_hit = true
	var zone: DragonAtomZone = DragonAtomZone.new()
	zone.damage_per_tick = zone_damage
	zone.tick_interval   = zone_interval
	zone.duration        = zone_duration
	zone.radius          = zone_radius
	parent.add_child(zone)
	zone.setup(global_position, _owner)
	var gp: Vector3 = Vector3(global_position.x, 0.0, global_position.z)

	var mat_exp: StandardMaterial3D = MeshBuilder.emit_mat(
		Color(0.85, 0.0, 0.40, 0.8),
		Color(1.0, 0.0, 0.30), 14.0)
	var sph: MeshInstance3D = MeshInstance3D.new()
	var ss: SphereMesh = SphereMesh.new()
	ss.radius = 0.5; ss.height = 1.0
	sph.mesh = ss; sph.material_override = mat_exp
	sph.scale = Vector3.ZERO
	parent.add_child(sph)
	sph.global_position = gp

	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(sph, "scale", Vector3(zone_radius * 2, 0.5, zone_radius * 2), 0.3)
	tween.tween_property(mat_exp, "emission_energy_multiplier", 0.0, 0.4)
	tween.tween_property(mat_exp, "albedo_color:a", 0.0, 0.4)
	tween.tween_callback(_kill_node.bind(sph))

	var flash: OmniLight3D = OmniLight3D.new()
	flash.light_color = Color(0.80, 0.05, 0.55)
	flash.light_energy = 20.0
	flash.omni_range = 20.0
	parent.add_child(flash)
	flash.global_position = gp
	var ft: SceneTreeTimer = get_tree().create_timer(0.15)
	ft.timeout.connect(_kill_node.bind(flash))

func _kill_node(node: Node) -> void:
	if is_instance_valid(node):
		node.queue_free()
