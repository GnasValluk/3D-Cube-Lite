extends Node3D
class_name BeyordeathBullet

@export var speed: float = 32.0
@export var lifetime: float = 1.2
@export var hit_damage: int = 20
@export var hit_radius: float = 0.6

var _dir: Vector3 = Vector3.FORWARD
var _age: float = 0.0
var _owner: Node3D = null

var _mat_core: StandardMaterial3D
var _mat_glow: StandardMaterial3D

func setup(origin: Vector3, direction: Vector3, owner: Node3D = null) -> void:
	global_position = origin
	_dir = direction.normalized()
	_owner = owner
	_make_materials()
	_build_visual()

func _make_materials() -> void:
	var green := Color(0.30, 1.0, 0.40)
	_mat_core = MeshBuilder.emit_mat(green, Color(0.50, 1.0, 0.50), 8.0)
	_mat_glow = MeshBuilder.emit_mat(Color(0.20, 0.80, 0.30), green, 4.0)

func _build_visual() -> void:
	var body := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.025
	cyl.bottom_radius = 0.025
	cyl.height = 0.16
	body.mesh = cyl
	body.material_override = _mat_core
	body.position = Vector3(0, 0, 0.06)
	add_child(body)
	var tip := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.03
	sph.height = 0.06
	tip.mesh = sph
	tip.material_override = _mat_glow
	tip.position = Vector3(0, 0, 0.14)
	add_child(tip)
	var halo := MeshInstance3D.new()
	var sph2 := SphereMesh.new()
	sph2.radius = 0.07
	sph2.height = 0.14
	halo.mesh = sph2
	halo.material_override = _mat_glow
	halo.position = Vector3(0, 0, 0.02)
	add_child(halo)
	var light := OmniLight3D.new()
	light.light_color = Color(0.25, 1.0, 0.35)
	light.light_energy = 3.0
	light.omni_range = 3.0
	add_child(light)

func _process(delta: float) -> void:
	_age += delta
	if _dir.length_squared() > 0.001:
		look_at(global_position + _dir, Vector3.UP)
	global_position += _dir * speed * delta
	_check_hit()
	var pulse: float = 1.0 + sin(_age * 24.0) * 0.05
	scale = Vector3(pulse, pulse, pulse)
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

func _explode() -> void:
	var parent := get_parent()
	if parent == null:
		return
	for i in range(3):
		var flash := OmniLight3D.new()
		flash.light_color = Color(0.25, 1.0, 0.35)
		flash.light_energy = 5.0 + i * 2.0
		flash.omni_range = 3.0
		parent.add_child(flash)
		flash.global_position = global_position
		get_tree().create_timer(0.04 * i).timeout.connect(func(): if is_instance_valid(flash): flash.queue_free())
	for j in range(4):
		var mat := MeshBuilder.emit_mat(Color(0.30, 1.0, 0.40), Color(0.50, 1.0, 0.50), 5.0 - j * 0.5)
		var mi := MeshInstance3D.new()
		var tor := TorusMesh.new()
		tor.inner_radius = 0.015 + j * 0.015
		tor.outer_radius = 0.08 - j * 0.012
		mi.mesh = tor
		mi.material_override = mat
		add_child(mi)
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(mi, "scale", Vector3(4, 4, 4), 0.2)
		tween.tween_property(mat, "emission_energy_multiplier", 0.0, 0.2)
		tween.tween_property(mat, "albedo_color:a", 0.0, 0.2)
	set_process(false)
	get_tree().create_timer(0.25).timeout.connect(queue_free)
