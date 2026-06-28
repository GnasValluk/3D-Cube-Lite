extends Node3D
class_name BeyordeathBomb

@export var lifetime: float = 3.0
@export var hit_damage: int = 75
@export var aoe_radius: float = 2.5
@export var fall_speed: float = 12.0

var _age: float = 0.0
var _owner: Node3D = null
var _start_y: float = 0.0
var _start_pos: Vector3 = Vector3.ZERO
var _horizontal_dir: Vector3 = Vector3.FORWARD
var _mat_body: StandardMaterial3D
var _mat_glow: StandardMaterial3D

func setup(origin: Vector3, horizontal: Vector3, owner: Node3D) -> void:
	global_position = origin
	_start_pos = origin
	_start_y = origin.y
	_horizontal_dir = horizontal.normalized()
	_owner = owner
	_make_materials()
	_build_visual()

func _make_materials() -> void:
	var green := Color(0.30, 1.0, 0.40)
	_mat_body = MeshBuilder.emit_mat(Color(0.10, 0.12, 0.14), green * 0.3, 0.5)
	_mat_glow = MeshBuilder.emit_mat(green, Color(0.50, 1.0, 0.50), 5.0)

func _build_visual() -> void:
	var body := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.06
	cyl.bottom_radius = 0.04
	cyl.height = 0.14
	body.mesh = cyl
	body.material_override = _mat_body
	body.position = Vector3(0, 0, 0)
	add_child(body)
	var glow := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.04
	sph.height = 0.08
	glow.mesh = sph
	glow.material_override = _mat_glow
	glow.position = Vector3(0, 0, 0.08)
	add_child(glow)
	var light := OmniLight3D.new()
	light.light_color = Color(0.25, 1.0, 0.35)
	light.light_energy = 2.0
	light.omni_range = 3.0
	add_child(light)

func _process(delta: float) -> void:
	_age += delta
	global_position += _horizontal_dir * 0.5 * delta
	var fall_prog: float = _age / 0.5
	var y_offset: float = -9.8 * 0.5 * fall_prog * fall_prog
	global_position.y = _start_y + y_offset
	if global_position.y <= 0.05:
		_explode_aoe()
	if _age >= lifetime:
		_explode_aoe()

func _explode_aoe() -> void:
	set_process(false)
	for ch in _find_targets():
		if ch and ch != _owner and ch.is_alive:
			var offset: Vector3 = ch.global_position - global_position
			offset.y = 0.0
			if offset.length() <= aoe_radius:
				var dmg: int = _owner.calc_skill_damage(hit_damage) if _owner and _owner.has_method("calc_skill_damage") else hit_damage
				ch.take_damage(dmg, _owner)
	var parent := get_parent()
	if parent == null:
		return
	var flash := OmniLight3D.new()
	flash.light_color = Color(0.30, 1.0, 0.40)
	flash.light_energy = 8.0
	flash.omni_range = 6.0
	parent.add_child(flash)
	flash.global_position = global_position
	get_tree().create_timer(0.1).timeout.connect(func(): if is_instance_valid(flash): flash.queue_free())
	for j in range(5):
		var mat := MeshBuilder.emit_mat(Color(0.30, 1.0, 0.40), Color(0.50, 1.0, 0.50), 6.0 - j)
		var mi := MeshInstance3D.new()
		var tor := TorusMesh.new()
		tor.inner_radius = 0.02 + j * 0.02
		tor.outer_radius = 0.10 - j * 0.014
		mi.mesh = tor
		mi.material_override = mat
		add_child(mi)
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(mi, "scale", Vector3(5, 5, 5), 0.3)
		tween.tween_property(mat, "emission_energy_multiplier", 0.0, 0.3)
		tween.tween_property(mat, "albedo_color:a", 0.0, 0.3)
	get_tree().create_timer(0.35).timeout.connect(queue_free)

func _find_targets() -> Array[CharacterBase]:
	var mgr := _find_manager()
	if mgr == null:
		return []
	var result: Array[CharacterBase] = []
	for ch in mgr.get_children():
		if ch is CharacterBase and ch.is_alive:
			result.append(ch as CharacterBase)
	return result

func _find_manager() -> Node:
	var p := get_parent()
	while p != null:
		if p is CharacterManager:
			return p
		p = p.get_parent()
	return null
