## world/props/wood_lamp.gd
## Đèn đường gỗ phong cách làng quê đồng bằng — cột gỗ vuông + đèn lồng vàng.
## Chỉ phát sáng ban đêm thông qua RoadLampManager.
##
## Tối ưu: share ShaderMaterial (1 draw call cho toàn bộ kính),
## range nhỏ hơn trên mobile, tự unregister khi bị xóa.

extends Node3D
class_name WoodLamp

# ── Shared materials (tạo 1 lần, tất cả đèn dùng chung) ──────────────────────
static var _shared_wood_mat:   StandardMaterial3D = null
static var _shared_glass_mat:  ShaderMaterial     = null

# ── Màu sắc gỗ ───────────────────────────────────────────────────────────────
const C_WOOD_DARK:  Color = Color(0.22, 0.13, 0.07)
const C_WOOD_MID:   Color = Color(0.30, 0.18, 0.09)
const C_WOOD_LIGHT: Color = Color(0.42, 0.26, 0.13)

# ── Màu đèn lồng ──────────────────────────────────────────────────────────────
const C_FRAME:      Color = Color(0.18, 0.11, 0.05)
const C_GLASS:      Color = Color(1.00, 0.82, 0.40)

# ── Thông số hình học ─────────────────────────────────────────────────────────
const POLE_W:      float = 0.18
const POLE_H:      float = 3.0
const BASE_W:      float = 0.30
const BASE_H:      float = 0.22
const MID_BAND_H:  float = 0.10
const ARM_OUT:     float = 0.65
const ARM_H:       float = 0.14
const BRACE_LEN:   float = 0.50
const LANTERN_W:   float = 0.34
const LANTERN_H:   float = 0.40
const LANTERN_CAP: float = 0.08

# ── Ánh sáng ──────────────────────────────────────────────────────────────────
const LIGHT_COLOR:      Color = Color(1.00, 0.80, 0.35)
const LIGHT_RANGE:      float = 9.0
const LIGHT_ENERGY_MAX: float = 3.5

# ── Hướng đường — set trước khi add_child ─────────────────────────────────────
var road_dir: Vector2 = Vector2(1.0, 0.0)

var _light: OmniLight3D = null
var _crystal_mi: MeshInstance3D = null

func _ready() -> void:
	# Đọc road_dir từ meta nếu được set bởi spawner (tránh type issue cross-script)
	if has_meta("road_dir_x"):
		road_dir = Vector2(get_meta("road_dir_x"), get_meta("road_dir_y"))
	var perp    := Vector2(-road_dir.y, road_dir.x).normalized()
	var arm_dir := Vector3(perp.x, 0.0, perp.y)
	_build_mesh(arm_dir)
	_setup_light(arm_dir)

# ─────────────────────────────────────────────────────────────────────────────
func _build_mesh(arm_dir: Vector3) -> void:
	var st  := SurfaceTool.new()
	var stg := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	stg.begin(Mesh.PRIMITIVE_TRIANGLES)

	# 1. Đế
	_box(st, Vector3(0, BASE_H * 0.5, 0), Vector3(BASE_W, BASE_H, BASE_W), C_WOOD_DARK)
	_box(st, Vector3(0, BASE_H + 0.03, 0), Vector3(BASE_W + 0.04, 0.06, BASE_W + 0.04), C_WOOD_MID)

	# 2. Thân cột
	var pole_bot_y: float = BASE_H + 0.06
	var pole_top_y: float = pole_bot_y + POLE_H
	_box(st, Vector3(0, pole_bot_y + POLE_H * 0.5, 0), Vector3(POLE_W, POLE_H, POLE_W), C_WOOD_DARK)

	# 3. Gờ ngang giữa thân + điểm sáng nhỏ
	var mid_y: float = pole_bot_y + POLE_H * 0.38
	_box(st, Vector3(0, mid_y, 0), Vector3(POLE_W + 0.06, MID_BAND_H, POLE_W + 0.06), C_WOOD_MID)
	_box(st, Vector3(0, mid_y, 0), Vector3(POLE_W * 0.5, MID_BAND_H * 0.6, POLE_W * 0.5), C_WOOD_LIGHT)

	# 4. Đầu cột
	_box(st, Vector3(0, pole_top_y + 0.04, 0), Vector3(POLE_W + 0.08, 0.08, POLE_W + 0.08), C_WOOD_MID)
	_box(st, Vector3(0, pole_top_y + 0.10, 0), Vector3(POLE_W + 0.04, 0.06, POLE_W + 0.04), C_WOOD_DARK)

	# 5. Cánh tay ngang
	var arm_base_y: float = pole_top_y + 0.07
	var sx: float = abs(arm_dir.x) * ARM_OUT + abs(arm_dir.z) * ARM_H
	var sz: float = abs(arm_dir.z) * ARM_OUT + abs(arm_dir.x) * ARM_H
	_box(st, Vector3(0, arm_base_y, 0) + arm_dir * (ARM_OUT * 0.5), Vector3(sx, ARM_H, sz), C_WOOD_MID)

	# 6. Thanh chống xiên
	var brace_bot: Vector3 = arm_dir * 0.04 + Vector3(0, arm_base_y - BRACE_LEN * 0.72, 0)
	var brace_top: Vector3 = arm_dir * ARM_OUT + Vector3(0, arm_base_y - ARM_H * 0.5, 0)
	_brace(st, brace_bot, brace_top, ARM_H * 0.55, C_WOOD_MID)

	# 7. Đèn lồng
	var lantern_c: Vector3 = arm_dir * ARM_OUT + Vector3(0, arm_base_y - ARM_H * 0.5 - LANTERN_H * 0.5, 0)
	_build_lantern(st, stg, lantern_c)

	# Commit mesh gỗ — dùng shared material để giảm draw call
	var mesh_main := st.commit()
	if mesh_main:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh_main
		mi.material_override = _get_shared_wood_mat()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)

	# Commit mesh kính — dùng shared material, emit_energy điều khiển qua uniform
	var mesh_glass := stg.commit()
	if mesh_glass:
		var mi_g := MeshInstance3D.new()
		mi_g.mesh = mesh_glass
		# QUAN TRỌNG: mỗi đèn cần instance riêng của material để emit_energy độc lập
		mi_g.material_override = _get_shared_glass_mat().duplicate()
		mi_g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi_g)
		_crystal_mi = mi_g
		RoadLampManager.register_crystal(mi_g)

# ── Đèn lồng vuông ───────────────────────────────────────────────────────────
func _build_lantern(st: SurfaceTool, stg: SurfaceTool, c: Vector3) -> void:
	var hw: float = LANTERN_W * 0.5
	var hh: float = LANTERN_H * 0.5

	# Nắp trên
	_box(st, c + Vector3(0, hh + LANTERN_CAP * 0.5, 0),
		Vector3(LANTERN_W + 0.04, LANTERN_CAP, LANTERN_W + 0.04), C_WOOD_DARK)
	_box(st, c + Vector3(0, hh + LANTERN_CAP + 0.02, 0),
		Vector3(LANTERN_W * 0.6, 0.04, LANTERN_W * 0.6), C_FRAME)

	# Đáy
	_box(st, c + Vector3(0, -hh - 0.03, 0),
		Vector3(LANTERN_W + 0.02, 0.06, LANTERN_W + 0.02), C_FRAME)

	# 4 cột khung góc
	var ox: float = hw - 0.04
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			_box(st, c + Vector3(ox * sx, 0.0, ox * sz), Vector3(0.06, LANTERN_H, 0.06), C_FRAME)

	# 4 mặt kính (glass mesh)
	var gi: float = hw - 0.03   # glass inset
	var ei: float = 0.06        # edge inset
	# +X
	_glass_face(stg, c, Vector3(gi, hh * 0.88, -gi + ei), Vector3(gi, -hh * 0.88, -gi + ei),
		Vector3(gi, -hh * 0.88, gi - ei), Vector3(gi, hh * 0.88, gi - ei), Vector3(1,0,0))
	# -X
	_glass_face(stg, c, Vector3(-gi, hh * 0.88, gi - ei), Vector3(-gi, -hh * 0.88, gi - ei),
		Vector3(-gi, -hh * 0.88, -gi + ei), Vector3(-gi, hh * 0.88, -gi + ei), Vector3(-1,0,0))
	# +Z
	_glass_face(stg, c, Vector3(gi - ei, hh * 0.88, gi), Vector3(gi - ei, -hh * 0.88, gi),
		Vector3(-gi + ei, -hh * 0.88, gi), Vector3(-gi + ei, hh * 0.88, gi), Vector3(0,0,1))
	# -Z
	_glass_face(stg, c, Vector3(-gi + ei, hh * 0.88, -gi), Vector3(-gi + ei, -hh * 0.88, -gi),
		Vector3(gi - ei, -hh * 0.88, -gi), Vector3(gi - ei, hh * 0.88, -gi), Vector3(0,0,-1))

func _glass_face(stg: SurfaceTool, origin: Vector3,
		v0: Vector3, v1: Vector3, v2: Vector3, v3: Vector3, n: Vector3) -> void:
	stg.set_normal(n); stg.set_color(C_GLASS)
	stg.add_vertex(origin + v0)
	stg.set_normal(n); stg.set_color(C_GLASS)
	stg.add_vertex(origin + v1)
	stg.set_normal(n); stg.set_color(C_GLASS)
	stg.add_vertex(origin + v2)
	stg.set_normal(n); stg.set_color(C_GLASS)
	stg.add_vertex(origin + v0)
	stg.set_normal(n); stg.set_color(C_GLASS)
	stg.add_vertex(origin + v2)
	stg.set_normal(n); stg.set_color(C_GLASS)
	stg.add_vertex(origin + v3)

# ── OmniLight3D ───────────────────────────────────────────────────────────────
func _setup_light(arm_dir: Vector3) -> void:
	_light = OmniLight3D.new()
	var pole_top_y: float = BASE_H + 0.06 + POLE_H
	var arm_base_y: float = pole_top_y + 0.07
	var lantern_y:  float = arm_base_y - LANTERN_H * 0.5
	_light.position         = arm_dir * ARM_OUT + Vector3(0, lantern_y - 0.05, 0)
	_light.light_color      = LIGHT_COLOR
	_light.light_energy     = 0.0
	# Mobile: giảm range để hạn chế overdraw và số fragment bị ảnh hưởng
	_light.omni_range       = 6.0 if DeviceManager.is_mobile() else LIGHT_RANGE
	_light.omni_attenuation = 1.4
	_light.shadow_enabled   = false
	_light.light_specular   = 0.0
	add_child(_light)
	RoadLampManager.register_light(_light)

## Tự unregister khi node bị xóa khỏi scene (chunk unload)
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if _light != null:
			RoadLampManager.unregister_light(_light)
		if _crystal_mi != null:
			RoadLampManager.unregister_crystal(_crystal_mi)

# ── Shared material helpers ───────────────────────────────────────────────────
## Trả về StandardMaterial3D dùng chung (tạo 1 lần cho toàn bộ session)
static func _get_shared_wood_mat() -> StandardMaterial3D:
	if _shared_wood_mat == null:
		_shared_wood_mat = StandardMaterial3D.new()
		_shared_wood_mat.vertex_color_use_as_albedo = true
		# Unshaded: vertex color đã encode baked lighting, không cần dynamic light
		# tác động → loại bỏ hoàn toàn specular highlight và phản quang trắng
		_shared_wood_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_shared_wood_mat.cull_mode = BaseMaterial3D.CULL_BACK
	return _shared_wood_mat

## Trả về ShaderMaterial gốc (mỗi đèn sẽ .duplicate() để có emit_energy riêng)
static func _get_shared_glass_mat() -> ShaderMaterial:
	if _shared_glass_mat == null:
		var s := Shader.new()
		s.code = """
shader_type spatial;
render_mode blend_mix, cull_disabled, unshaded;
uniform vec4  glass_color : source_color = vec4(1.0, 0.82, 0.40, 0.55);
uniform vec4  emit_color  : source_color = vec4(1.0, 0.75, 0.25, 1.00);
uniform float emit_energy : hint_range(0.0, 8.0) = 0.0;
void fragment() {
	float a = clamp(emit_energy * 0.22 + 0.18, 0.18, 0.85);
	ALBEDO   = glass_color.rgb;
	ALPHA    = a;
	EMISSION = emit_color.rgb * emit_energy;
}
"""
		_shared_glass_mat = ShaderMaterial.new()
		_shared_glass_mat.shader = s
	return _shared_glass_mat

# ── Vật liệu (deprecated — giữ lại để tương thích, dùng shared helpers trên) ─
func _mat_wood() -> StandardMaterial3D:
	return _get_shared_wood_mat()

func _mat_glass() -> ShaderMaterial:
	return _get_shared_glass_mat().duplicate()

# ── Helpers ───────────────────────────────────────────────────────────────────
func _box(st: SurfaceTool, center: Vector3, size: Vector3, col: Color) -> void:
	var hx: float = size.x * 0.5
	var hy: float = size.y * 0.5
	var hz: float = size.z * 0.5
	var c_top  := Color(minf(col.r * 1.12, 1.0), minf(col.g * 1.12, 1.0), minf(col.b * 1.10, 1.0))
	var c_bot  := Color(col.r * 0.55, col.g * 0.55, col.b * 0.52)
	var c_side := Color(col.r * 0.75, col.g * 0.75, col.b * 0.72)
	var c_frnt := Color(col.r * 0.88, col.g * 0.88, col.b * 0.85)
	# top
	_quad_st(st, center+Vector3(-hx,hy,-hz), center+Vector3(hx,hy,-hz),
		center+Vector3(hx,hy,hz), center+Vector3(-hx,hy,hz), Vector3(0,1,0), c_top)
	# bottom
	_quad_st(st, center+Vector3(-hx,-hy,hz), center+Vector3(hx,-hy,hz),
		center+Vector3(hx,-hy,-hz), center+Vector3(-hx,-hy,-hz), Vector3(0,-1,0), c_bot)
	# +Z
	_quad_st(st, center+Vector3(-hx,-hy,hz), center+Vector3(hx,-hy,hz),
		center+Vector3(hx,hy,hz), center+Vector3(-hx,hy,hz), Vector3(0,0,1), c_frnt)
	# -Z
	_quad_st(st, center+Vector3(hx,-hy,-hz), center+Vector3(-hx,-hy,-hz),
		center+Vector3(-hx,hy,-hz), center+Vector3(hx,hy,-hz), Vector3(0,0,-1), c_side)
	# +X
	_quad_st(st, center+Vector3(hx,-hy,hz), center+Vector3(hx,-hy,-hz),
		center+Vector3(hx,hy,-hz), center+Vector3(hx,hy,hz), Vector3(1,0,0), c_side)
	# -X
	_quad_st(st, center+Vector3(-hx,-hy,-hz), center+Vector3(-hx,-hy,hz),
		center+Vector3(-hx,hy,hz), center+Vector3(-hx,hy,-hz), Vector3(-1,0,0), c_side)

func _quad_st(st: SurfaceTool, v0: Vector3, v1: Vector3,
		v2: Vector3, v3: Vector3, n: Vector3, col: Color) -> void:
	st.set_normal(n); st.set_color(col); st.add_vertex(v0)
	st.set_normal(n); st.set_color(col); st.add_vertex(v1)
	st.set_normal(n); st.set_color(col); st.add_vertex(v2)
	st.set_normal(n); st.set_color(col); st.add_vertex(v0)
	st.set_normal(n); st.set_color(col); st.add_vertex(v2)
	st.set_normal(n); st.set_color(col); st.add_vertex(v3)

func _brace(st: SurfaceTool, a: Vector3, b: Vector3,
		thickness: float, col: Color) -> void:
	var dir: Vector3  = (b - a).normalized()
	var length: float = a.distance_to(b)
	var mid: Vector3  = (a + b) * 0.5
	var up := Vector3(0, 1, 0)
	var axis: Vector3 = up.cross(dir)
	if axis.length_squared() < 0.0001:
		return
	var angle: float = up.angle_to(dir)
	var basis := Basis(axis.normalized(), angle)
	var hw: float = thickness * 0.5
	var hl: float = length * 0.5
	var lc: Array[Vector3] = [
		Vector3(-hw,-hl,-hw), Vector3(hw,-hl,-hw),
		Vector3(hw, hl,-hw), Vector3(-hw, hl,-hw),
		Vector3(-hw,-hl, hw), Vector3(hw,-hl, hw),
		Vector3(hw, hl, hw), Vector3(-hw, hl, hw),
	]
	for k in range(lc.size()):
		lc[k] = mid + basis * lc[k]
	var faces: Array = [
		[0,1,2,3,Vector3(0,0,-1)], [7,6,5,4,Vector3(0,0,1)],
		[3,2,6,7,Vector3(0,1,0)],  [4,5,1,0,Vector3(0,-1,0)],
		[1,5,6,2,Vector3(1,0,0)],  [0,3,7,4,Vector3(-1,0,0)],
	]
	for face in faces:
		var fn: Vector3 = basis * (face[4] as Vector3)
		var sc: float   = 0.65 + abs((face[4] as Vector3).y) * 0.35
		var fc: Color   = Color(col.r*sc, col.g*sc, col.b*sc)
		_quad_st(st, lc[face[0]], lc[face[1]], lc[face[2]], lc[face[3]], fn, fc)
