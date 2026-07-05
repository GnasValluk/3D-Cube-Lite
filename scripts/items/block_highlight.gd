extends Node3D
class_name BlockHighlight

var _box: MeshInstance3D

func _init() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.6, 0.1, 0.4)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = true
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.04, 0.54, 1.04)
	_box = MeshInstance3D.new()
	_box.mesh = mesh
	_box.material_override = mat
	_box.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_box)

func show_at(world_pos: Vector3) -> void:
	global_position = world_pos
	visible = true

func hide_block() -> void:
	visible = false
