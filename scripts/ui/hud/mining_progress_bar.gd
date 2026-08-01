extends Node3D
class_name MiningProgressBar

## Thanh tiến trình đào block — billboard 3D ngay trên đầu block.
## Bg + fill: hai quad unshaded, fill trượt từ trái sang phải theo tỉ lệ.

const BAR_W: float = 0.90
const BAR_H: float = 0.14
const FILL_W: float = 0.78
const FILL_H: float = 0.09
const FILL_COLOR := Color(0.25, 0.85, 0.35, 0.95)
const BG_COLOR := Color(0.02, 0.02, 0.04, 0.60)

var _fill: MeshInstance3D = null

func _ensure_built() -> void:
	if _fill != null:
		return
	var bg_quad := QuadMesh.new()
	bg_quad.size = Vector2(BAR_W, BAR_H)
	var bg_mat := StandardMaterial3D.new()
	bg_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bg_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bg_mat.albedo_color = BG_COLOR
	bg_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	bg_mat.billboard_keep_scale = true
	bg_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var bg := MeshInstance3D.new()
	bg.mesh = bg_quad
	bg.material_override = bg_mat
	add_child(bg)

	_fill = MeshInstance3D.new()
	_fill.mesh = QuadMesh.new()
	var fill_mat := StandardMaterial3D.new()
	fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fill_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fill_mat.albedo_color = FILL_COLOR
	fill_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	fill_mat.billboard_keep_scale = true
	fill_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_fill.material_override = fill_mat
	add_child(_fill)
	visible = false

func show_at(world_pos: Vector3, ratio: float) -> void:
	_ensure_built()
	global_position = world_pos
	ratio = clampf(ratio, 0.0, 1.0)
	var w := FILL_W * ratio
	(_fill.mesh as QuadMesh).size = Vector2(w, FILL_H)
	_fill.position.x = -(FILL_W - w) * 0.5
	_fill.visible = w > 0.001
	visible = true

func hide_bar() -> void:
	if _fill == null:
		return
	visible = false
