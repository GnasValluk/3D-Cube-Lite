extends Node3D
class_name WorldHPBar

const BAR_WIDTH: float = 1.2
const BAR_HEIGHT: float = 0.08
const BAR_OFFSET_Y: float = 2.6
const BAR_GAP: float = 0.02

var _pivot: Node3D
var _fill: MeshInstance3D
var _shield: MeshInstance3D
var _mana: MeshInstance3D
var _target: CharacterBase

func setup(target: CharacterBase) -> void:
	_target = target
	position = Vector3(0, BAR_OFFSET_Y, 0)
	_build()
	target.hp_changed.connect(_update)
	target.shield_changed.connect(_update_shield)
	target.mana_changed.connect(_update_mana)
	target.died.connect(_hide)
	_update(target.hp, target.max_hp)
	_update_shield(target.shield)
	_update_mana(target.mana, target.max_mana)

func _build() -> void:
	_pivot = Node3D.new()
	add_child(_pivot)

	var mat_fill := StandardMaterial3D.new()
	mat_fill.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var qfill := QuadMesh.new()
	qfill.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	_fill = MeshInstance3D.new()
	_fill.mesh = qfill
	_fill.material_override = mat_fill
	_pivot.add_child(_fill)

	var mat_shield := StandardMaterial3D.new()
	mat_shield.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_shield.albedo_color = Color(1.0, 0.85, 0.0, 0.60)
	var qshield := QuadMesh.new()
	qshield.size = Vector2(0.0, BAR_HEIGHT)
	_shield = MeshInstance3D.new()
	_shield.mesh = qshield
	_shield.material_override = mat_shield
	var mat_mana := StandardMaterial3D.new()
	mat_mana.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_mana.albedo_color = Color(0.20, 0.50, 1.0, 0.60)
	var qmana := QuadMesh.new()
	qmana.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	_mana = MeshInstance3D.new()
	_mana.mesh = qmana
	_mana.material_override = mat_mana
	_mana.position = Vector3(-BAR_WIDTH * 0.5, -(BAR_HEIGHT + BAR_GAP), 0.0)
	_pivot.add_child(_mana)

	_shield.position = Vector3(-BAR_WIDTH * 0.5, -(BAR_HEIGHT + BAR_GAP) * 2, 0.0)
	_pivot.add_child(_shield)

func _process(_delta: float) -> void:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return
	var scale_vec: Vector3 = _target.scale
	if scale_vec.length_squared() < 0.01:
		return
	var dir: Vector3 = cam.global_position - _pivot.global_position
	dir.y = 0.0
	if dir.length_squared() < 0.001:
		return
	dir = dir.normalized()
	_pivot.look_at(_pivot.global_position - dir, Vector3.UP)

func _resize_fill(ratio: float) -> void:
	var qm: QuadMesh = _fill.mesh as QuadMesh
	if qm == null:
		return
	qm.size = Vector2(BAR_WIDTH * ratio, BAR_HEIGHT)
	_fill.position = Vector3(-(1.0 - ratio) * BAR_WIDTH * 0.5, 0.0, 0.0)

func _update(current: int, max_hp_val: int) -> void:
	if not is_instance_valid(_target):
		return
	var ratio: float = clamp(float(current) / float(max_hp_val), 0.0, 1.0)
	if ratio <= 0.0:
		_fill.visible = false
	else:
		_fill.visible = true
		var fill_mat := _fill.material_override as StandardMaterial3D
		if ratio > 0.6:
			fill_mat.albedo_color = Color(0.20, 0.85, 0.30, 0.90)
		elif ratio > 0.3:
			fill_mat.albedo_color = Color(0.95, 0.80, 0.10, 0.90)
		else:
			fill_mat.albedo_color = Color(0.95, 0.12, 0.12, 0.90)
		_resize_fill(ratio)
	_update_shield(_target.shield)

func _update_shield(current: int) -> void:
	if not is_instance_valid(_target):
		return
	if current <= 0:
		_shield.visible = false
		return
	_shield.visible = true
	var max_hp_val: int = _target.max_hp
	var shield_ratio: float = clamp(float(current) / float(max_hp_val), 0.0, 1.0)
	var qm: QuadMesh = _shield.mesh as QuadMesh
	if qm == null:
		return
	qm.size = Vector2(BAR_WIDTH * shield_ratio, BAR_HEIGHT)
	_shield.position = Vector3(-(1.0 - shield_ratio) * BAR_WIDTH * 0.5, -(BAR_HEIGHT + BAR_GAP) * 2, 0.0)

func _update_mana(current: int, max_mana_val: int) -> void:
	if not is_instance_valid(_target):
		return
	if current <= 0:
		_mana.visible = false
		return
	_mana.visible = true
	var ratio: float = clamp(float(current) / float(max_mana_val), 0.0, 1.0)
	var qm: QuadMesh = _mana.mesh as QuadMesh
	if qm == null:
		return
	qm.size = Vector2(BAR_WIDTH * ratio, BAR_HEIGHT)
	_mana.position = Vector3(-(1.0 - ratio) * BAR_WIDTH * 0.5, -(BAR_HEIGHT + BAR_GAP), 0.0)

func _hide(_attacker: Node3D = null) -> void:
	visible = false
