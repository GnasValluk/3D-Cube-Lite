## dragon/dragon_fireball.gd
## Quả cầu lửa siêu cấp – core + corona + vòng xoáy + chớp sáng

extends Node3D
class_name DragonFireball

@export var speed:      float = 22.0
@export var lifetime:   float = 1.8
@export var radius:     float = 0.22
@export var hit_damage: int   = 100
@export var hit_radius: float = 1.0
@export var aoe_damage: int   = 20
@export var aoe_radius: float = 3.5

var _dir:      Vector3 = Vector3.FORWARD
var _age:      float   = 0.0
var _mesh_root: Node3D
var _owner: Node3D = null
var _light: OmniLight3D
var _ring_mats: Array[StandardMaterial3D] = []
var _trail_timer: float = 0.0

func setup(origin: Vector3, direction: Vector3, owner: Node3D = null) -> void:
	global_position = origin
	_dir = direction.normalized()
	_owner = owner
	_build_visual()

func _build_visual() -> void:
	_mesh_root = Node3D.new()
	add_child(_mesh_root)

	var mat_core := MeshBuilder.emit_mat(
		Color(0.65, 0.10, 0.85),
		Color(0.90, 0.05, 0.60), 8.0)
	MeshBuilder.sphere(_mesh_root, Vector3.ZERO, radius, mat_core)

	var mat_glow := MeshBuilder.emit_mat(
		Color(0.50, 0.05, 0.70),
		Color(0.70, 0.0, 0.50), 5.0)
	MeshBuilder.sphere(_mesh_root, Vector3.ZERO, radius * 1.6, mat_glow)

	var mat_corona := MeshBuilder.emit_mat(
		Color(0.40, 0.0, 0.60, 0.35),
		Color(0.60, 0.0, 0.50), 2.5)
	var corona := MeshBuilder.sphere(_mesh_root, Vector3.ZERO, radius * 3.0, mat_corona)
	corona.scale = Vector3(1.0, 0.6, 1.0)

	var mat_ring := MeshBuilder.emit_mat(
		Color(0.80, 0.05, 0.30),
		Color(1.0, 0.0, 0.20), 6.0)
	var mat_ring2 := MeshBuilder.emit_mat(
		Color(0.60, 0.0, 0.60),
		Color(0.80, 0.0, 0.40), 4.0)
	_ring_mats = [mat_ring, mat_ring2]

	for i in range(4):
		var tor := TorusMesh.new()
		tor.inner_radius = radius * 1.8 + i * 0.04
		tor.outer_radius = 0.035
		var mi := MeshInstance3D.new()
		mi.mesh = tor
		mi.material_override = mat_ring if i % 2 == 0 else mat_ring2
		var ang := float(i) * 1.57
		mi.rotation = Vector3(ang, ang * 0.7, ang * 0.3)
		_mesh_root.add_child(mi)

	for i in range(8):
		var a1: float = float(i) / 8.0 * TAU
		var a2: float = float(i) * 1.1
		var ember_r := radius * (0.7 + sin(i * 2.3) * 0.3)
		var pos := Vector3(
			cos(a1) * sin(a2),
			sin(a1) * sin(a2),
			cos(a2)
		) * radius * 2.2
		var mat_ember := MeshBuilder.emit_mat(
			Color(0.90 + sin(i) * 0.10, 0.05, 0.70 + cos(i * 1.3) * 0.20),
			Color(1.0, 0.0, 0.50), 5.0 + sin(i * 1.7) * 2.0)
		MeshBuilder.sphere(_mesh_root, pos, radius * 0.15, mat_ember)

	_light = OmniLight3D.new()
	_light.light_color = Color(0.70, 0.05, 0.90)
	_light.light_energy = 6.0
	_light.omni_range = 6.0
	add_child(_light)

func _process(delta: float) -> void:
	_age += delta
	_trail_timer += delta

	_mesh_root.rotation.z += delta * 5.0
	_mesh_root.rotation.y += delta * 3.5
	_mesh_root.rotation.x += delta * 1.5

	global_position += _dir * speed * delta

	_check_hit()

	var pulse: float = 1.0 + sin(_age * 14.0) * 0.10
	_mesh_root.scale = Vector3(pulse, pulse, pulse)

	_light.light_energy = 5.0 + sin(_age * 18.0) * 2.0
	_light.omni_range = 5.0 + sin(_age * 12.0) * 1.5

	if _trail_timer >= 0.03:
		_trail_timer = 0.0
		_spawn_trail()

	if _age >= lifetime:
		_explode()

func _spawn_trail() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var mat := MeshBuilder.emit_mat(
		Color(0.60, 0.05, 0.80, 0.6),
		Color(0.80, 0.0, 0.60), 3.0)
	var mi := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.06
	sph.height = 0.12
	mi.mesh = sph
	mi.material_override = mat
	parent.add_child(mi)
	mi.global_position = global_position - _dir * 0.12

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(mi, "scale", Vector3(0.2, 0.2, 0.2), 0.4)
	tween.tween_property(mat, "emission_energy_multiplier", 0.0, 0.4)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.4)
	tween.tween_callback(func(): if is_instance_valid(mi): mi.queue_free())

func _check_hit() -> void:
	var mgr := _find_manager()
	if mgr == null:
		return
	for ch in mgr.get_children():
		if ch is CharacterBase and ch.is_alive and ch._active and ch != _owner:
			var offset: Vector3 = global_position - ch.global_position
			offset.y = 0.0
			if offset.length() < hit_radius:
				ch.take_damage(hit_damage, _owner)
				_explode()
				return

func _find_manager() -> Node:
	var p := get_parent()
	while p != null:
		if p is CharacterManager:
			return p
		p = p.get_parent()
	return null

func _deal_aoe_damage() -> void:
	var mgr := _find_manager()
	if mgr == null:
		return
	for ch in mgr.get_children():
		if ch is CharacterBase and ch.is_alive and ch._active and ch != _owner:
			var offset: Vector3 = global_position - ch.global_position
			offset.y = 0.0
			if offset.length() < aoe_radius:
				ch.take_damage(aoe_damage, _owner)

func _explode() -> void:
	var parent := get_parent()
	if parent == null:
		return
	_deal_aoe_damage()
	for i in range(6):
		var flash := OmniLight3D.new()
		flash.light_color = Color(0.70 + i * 0.04, 0.05, 0.80 + i * 0.03)
		flash.light_energy = 10.0 + i * 4.0
		flash.omni_range = 5.0 + i * 1.5
		parent.add_child(flash)
		flash.global_position = global_position
		get_tree().create_timer(0.03 * i).timeout.connect(
			func(): if is_instance_valid(flash): flash.queue_free())

	for j in range(8):
		var mat := MeshBuilder.emit_mat(
			Color(0.70 - j * 0.04, 0.05, 0.80 - j * 0.04),
			Color(0.90 - j * 0.05, 0.0, 0.60 - j * 0.04), 6.0 - j * 0.5)
		var mi := MeshInstance3D.new()
		var tor := TorusMesh.new()
		tor.inner_radius = 0.03 + j * 0.025
		tor.outer_radius = 0.12 - j * 0.01
		mi.mesh = tor
		mi.material_override = mat
		mi.rotation = Vector3(randf_range(0, TAU), randf_range(0, TAU), 0)
		add_child(mi)

		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(mi, "scale", Vector3(6, 6, 6), 0.3)
		tween.tween_property(mat, "emission_energy_multiplier", 0.0, 0.3)
		tween.tween_property(mat, "albedo_color:a", 0.0, 0.3)

	set_process(false)
	get_tree().create_timer(0.35).timeout.connect(queue_free)
