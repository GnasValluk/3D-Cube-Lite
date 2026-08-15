class_name SwampSedgeProp
extends DestroyableProp

## Lác nước đầm lầy — cụm lá kiếm dựng đứng màu xanh rêu ngả vàng, mọc thành
## bụi trên bùn sình hay ven vũng nước của rừng đầm lầy. Rơi "swamp_sedge" khi
## chặt (bằng tay là được — thân mềm).

const VOXEL: float = 0.25

func setup() -> void:
	pass

func _ready() -> void:
	super._ready()
	_build_mesh()

func _build_mesh() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var s: int = int(global_position.x * 131.0) ^ int(global_position.z * 577.0)
	s = (s ^ (s >> 13)) * 1274126177; s = s ^ (s >> 16)
	var r2 := float(s & 0x7FFFFFFF) / 2147483648.0
	var r3 := float((s >> 3) & 0x7FFFFFFF) / 2147483648.0
	var s2: int = s

	# 2-3 khóm lác, mỗi khóm lá dẹt cong võng, đầu lá nâu khô
	var clump_count: int = 2 + int(r2 * 2)
	var clump_r: float = 0.25 + r2 * 0.25
	var max_h: float = 0.85 + r3 * 0.45
	var col_base := Color(0.20 + r3 * 0.06, 0.34 + r3 * 0.10, 0.07 + r3 * 0.03)
	var col_tip := Color(0.30 + r2 * 0.08, 0.42 + r2 * 0.10, 0.10 + r2 * 0.04)
	var col_seed := Color(0.34, 0.26, 0.10)

	for ci in range(clump_count):
		s2 = s2 * 16807 + 1
		var cdir := Vector3(cos(float(s2 & 0x7FFFFFFF) / 2147483648.0 * TAU), 0, sin(float(s2 & 0x7FFFFFFF) / 2147483648.0 * TAU))
		s2 = s2 * 16807 + 1
		var origin := Vector3(
			cos(cdir.x * 2.0 + 1.0) * clump_r * 0.5,
			0.0,
			sin(cdir.x * 2.0 + 3.0) * clump_r * 0.5)
		var blade_count: int = 5 + int(float(s2 & 0x7FFFFFFF) / 2147483648.0 * 3)
		s2 = s2 * 16807 + 1
		var lean := cdir * 0.12
		for bi in range(blade_count):
			s2 = s2 * 16807 + 1; var ba := float(s2 & 0x7FFFFFFF) / 2147483648.0 * TAU
			s2 = s2 * 16807 + 1; var br := float(s2 & 0x7FFFFFFF) / 2147483648.0
			var b_origin := origin + Vector3(cos(ba) * clump_r * 0.4 * sqrt(br), 0, sin(ba) * clump_r * 0.4 * sqrt(br))
			var blade_h: float = max_h * (0.5 + br * 0.7)
			var w: float = VOXEL * (0.30 + r2 * 0.18)
			var segs: int = 3
			var prev := b_origin
			for seg in range(segs):
				var t := float(seg + 1) / float(segs)
				var nxt := b_origin + Vector3(0, blade_h * t, 0) \
					+ lean * blade_h * t * t * (0.4 + br * 0.5)
				var mid := (prev + nxt) * 0.5
				var dir := (nxt - prev).normalized()
				var perp := Vector3(-dir.z, 0, dir.x).normalized()
				var taper: float = 1.0 - t * 0.8
				var col := col_base.lerp(col_tip, t * 0.8)
				_add_quad(st, mid, perp * w * 0.5 * taper, dir * (nxt - prev).length() * 0.5, Vector3(0, 1, 0), col)
				prev = nxt
			var tip := prev
			# Chỏm nâu khô ở đầu lá — như cụm hạt chấm
			_add_quad(st, tip + Vector3(0, 0.05, 0), Vector3(-lean.normalized().x if lean.length_squared() > 0.001 else 0, 0, -1 * (1 if lean.length_squared() > 0.001 else 0)).normalized() * w * 0.22,
				Vector3(0, 0.10, 0), Vector3(0, 1, 0), col_seed)

	var mesh := st.commit()
	if mesh:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.metallic = 0.0
		mat.roughness = 0.95
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)

static func _add_quad(st: SurfaceTool, center: Vector3, u: Vector3, v: Vector3, n: Vector3, col: Color) -> void:
	st.set_normal(n); st.set_color(col)
	st.add_vertex(center - u - v)
	st.add_vertex(center + u - v)
	st.add_vertex(center + u + v)
	st.add_vertex(center - u - v)
	st.add_vertex(center + u + v)
	st.add_vertex(center - u + v)