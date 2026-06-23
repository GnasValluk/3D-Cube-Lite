extends Node3D
class_name WorldHPBar

const BAR_WIDTH: float = 1.2
const BAR_HEIGHT: float = 0.08
const BAR_OFFSET_Y: float = 2.6

var _fill: MeshInstance3D
var _target: CharacterBase

func setup(target: CharacterBase) -> void:
	_target = target
	position = Vector3(0, BAR_OFFSET_Y, 0)
	_build()
	target.hp_changed.connect(_update)
	target.died.connect(_hide)
	target.tree_exiting.connect(_cleanup)
	_update(target.hp, target.max_hp)

func _build() -> void:
	var mat_fill := StandardMaterial3D.new()
	mat_fill.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat_fill.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED

	var qfill := QuadMesh.new()
	qfill.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	_fill = MeshInstance3D.new()
	_fill.mesh = qfill
	_fill.material_override = mat_fill
	add_child(_fill)

func _update(current: int, max_hp_val: int) -> void:
	if not is_instance_valid(_target):
		return
	var ratio: float = clamp(float(current) / float(max_hp_val), 0.0, 1.0)
	if ratio <= 0.0:
		_fill.visible = false
		return
	_fill.visible = true

	var fill_mat := _fill.material_override as StandardMaterial3D
	if ratio > 0.6:
		fill_mat.albedo_color = Color(0.20, 0.85, 0.30, 0.90)
	elif ratio > 0.3:
		fill_mat.albedo_color = Color(0.95, 0.80, 0.10, 0.90)
	else:
		fill_mat.albedo_color = Color(0.95, 0.12, 0.12, 0.90)

	_fill.scale.x = ratio
	_fill.position.x = -(1.0 - ratio) * BAR_WIDTH * 0.5

var _hidden: bool = false

func _hide(_attacker: Node3D = null) -> void:
	_hidden = true
	visible = false

func _cleanup() -> void:
	if is_instance_valid(_target):
		if _target.hp_changed.is_connected(_update):
			_target.hp_changed.disconnect(_update)
		if _target.died.is_connected(_hide):
			_target.died.disconnect(_hide)
		if _target.tree_exiting.is_connected(_cleanup):
			_target.tree_exiting.disconnect(_cleanup)
