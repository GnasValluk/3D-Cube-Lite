## raptor/raptor_bullet.gd
## Đạn năng lượng neon – hình trụ dài như viên đạn thật, kèm hiệu ứng điện xanh.

extends Node3D
class_name RaptorBullet

@export var speed:       float = 30.0
@export var lifetime:    float = 1.5
@export var hit_damage:  int   = 30
@export var hit_radius:  float = 0.8

var _dir:     Vector3 = Vector3.FORWARD
var _age:     float   = 0.0
var _trail_timer: float = 0.0
var _owner: Node3D = null

var _mat_core:  StandardMaterial3D
var _mat_glow:  StandardMaterial3D
var _mat_elec:  StandardMaterial3D

func setup(origin: Vector3, direction: Vector3, owner: Node3D = null) -> void:
	global_position = origin
	_dir = direction.normalized()
	_owner = owner
	_build_materials()
	_build_visual()

func _build_materials() -> void:
	_mat_core = MeshBuilder.emit_mat(
		Color(1.0, 0.85, 0.20),
		Color(1.0, 0.80, 0.10), 6.0)
	_mat_glow = MeshBuilder.emit_mat(
		Color(1.0, 0.75, 0.15),
		Color(1.0, 0.70, 0.10), 3.5)
	_mat_elec = MeshBuilder.emit_mat(
		Color(1.0, 0.95, 0.50),
		Color(1.0, 0.95, 0.40), 10.0)

func _build_visual() -> void:
	var body := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius    = 0.035
	cyl.bottom_radius = 0.035
	cyl.height        = 0.22
	body.mesh = cyl
	body.material_override = _mat_core
	body.position = Vector3(0, 0, 0.07)
	add_child(body)

	var tip := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius          = 0.04
	sph.height          = 0.08
	sph.radial_segments = 8
	sph.rings           = 5
	tip.mesh = sph
	tip.material_override = _mat_elec
	tip.position = Vector3(0, 0, 0.18)
	add_child(tip)

	var tail := MeshInstance3D.new()
	var cyl2 := CylinderMesh.new()
	cyl2.top_radius    = 0.035
	cyl2.bottom_radius = 0.050
	cyl2.height        = 0.06
	tail.mesh = cyl2
	tail.material_override = _mat_core
	tail.position = Vector3(0, 0, -0.04)
	add_child(tail)

	var halo := MeshInstance3D.new()
	var sph2 := SphereMesh.new()
	sph2.radius          = 0.10
	sph2.height          = 0.20
	sph2.radial_segments = 12
	sph2.rings           = 8
	halo.mesh = sph2
	halo.material_override = _mat_glow
	halo.position = Vector3(0, 0, 0.04)
	add_child(halo)

	for i in range(3):
		var ring := MeshInstance3D.new()
		var tor := TorusMesh.new()
		tor.inner_radius = 0.045 + i * 0.005
		tor.outer_radius = 0.015
		ring.mesh = tor
		ring.material_override = _mat_elec
		ring.position = Vector3(0, 0, 0.02 + i * 0.07)
		ring.rotation = Vector3(randf_range(0, TAU), randf_range(0, TAU), 0)
		add_child(ring)

	var light := OmniLight3D.new()
	light.light_color  = Color(0.30, 0.80, 1.0)
	light.light_energy = 1.5
	light.omni_range   = 1.5
	add_child(light)

func _process(delta: float) -> void:
	_age += delta
	_trail_timer += delta

	if _dir.length_squared() > 0.001:
		look_at(global_position + _dir, Vector3.UP)

	global_position += _dir * speed * delta

	_check_hit()

	var pulse: float = 1.0 + sin(_age * 22.0) * 0.06
	scale = Vector3(pulse, pulse, pulse)

	var flicker: float = 0.7 + sin(_age * 31.0) * 0.3
	_mat_glow.emission_energy_multiplier = 3.5 * flicker
	_mat_elec.emission_energy_multiplier = 10.0 * flicker

	if _trail_timer >= 0.025:
		_trail_timer = 0.0
		_spawn_trail()

	if _age >= lifetime:
		_explode()

func _check_hit() -> void:
	var mgr := _find_manager()
	if mgr == null:
		return
	for ch in mgr.get_children():
		if ch is CharacterBase and ch.is_alive and ch._active and ch != _owner:
			var offset: Vector3 = global_position - ch.global_position
			offset.y = 0.0
			if offset.length() < hit_radius:
				var dmg: int = _owner.calc_skill_damage(hit_damage) if _owner and _owner.has_method("calc_skill_damage") else hit_damage
				ch.take_damage(dmg, _owner)
				_explode()
				return

func _find_manager() -> Node:
	var p := get_parent()
	while p != null:
		if p is CharacterManager:
			return p
		p = p.get_parent()
	return null

func _spawn_trail() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var p := Node3D.new()
	var mat := MeshBuilder.emit_mat(
		Color(1.0, 0.80, 0.15),
		Color(1.0, 0.75, 0.10), 2.0)
	var mi := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.025
	sph.height = 0.05
	mi.mesh = sph
	mi.material_override = mat
	p.add_child(mi)
	parent.add_child(p)
	p.global_position = global_position - _dir * 0.08
	p.rotation = rotation

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(p, "scale", Vector3(0.3, 0.3, 0.3), 0.3)
	tween.tween_property(mat, "emission_energy_multiplier", 0.0, 0.3)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.3)
	tween.tween_callback(func(): if is_instance_valid(p): p.queue_free())

func _explode() -> void:
	var parent := get_parent()
	if parent == null:
		return
	for i in range(4):
		var flash := OmniLight3D.new()
		flash.light_color  = Color(1.0, 0.80, 0.15)
		flash.light_energy = 6.0 + i * 3.0
		flash.omni_range   = 3.5 + i * 1.0
		parent.add_child(flash)
		flash.global_position = global_position
		get_tree().create_timer(0.04 * i).timeout.connect(
			func(): if is_instance_valid(flash): flash.queue_free())

	for j in range(5):
		var mat := MeshBuilder.emit_mat(
			Color(1.0, 0.80, 0.10 + float(j) * 0.03),
			Color(1.0, 0.75, 0.05), 6.0 - float(j) * 0.8)
		var mi := MeshInstance3D.new()
		var tor := TorusMesh.new()
		tor.inner_radius = 0.02 + j * 0.02
		tor.outer_radius = 0.10 - j * 0.015
		mi.mesh = tor
		mi.material_override = mat
		add_child(mi)
		mi.rotation = Vector3(randf_range(0, TAU), randf_range(0, TAU), 0)

		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(mi, "scale", Vector3(5, 5, 5), 0.25)
		tween.tween_property(mat, "emission_energy_multiplier", 0.0, 0.25)
		tween.tween_property(mat, "albedo_color:a", 0.0, 0.25)

	set_process(false)
	get_tree().create_timer(0.3).timeout.connect(queue_free)
