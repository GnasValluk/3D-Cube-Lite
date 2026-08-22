class_name CattailProp
extends DestroyableProp

## Thủy trúc (cattail) — cụm lá kiếm dựng đứng mọc trên bãi bùn ngập mặn,
## đầu bông trụ nâu sẫm. Rơi "cattail" khi chặt.

const VOXEL: float = 0.25

func setup() -> void:
	pass

func _ready() -> void:
	is_plant = true
	super._ready()
	_build_mesh()

func _build_mesh() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var s: int = int(global_position.x * 131.0) ^ int(global_position.z * 517.0)
	s = (s ^ (s >> 13)) * 1274126177; s = s ^ (s >> 16)
	var r2 := float(s & 0x7FFFFFFF) / 2147483648.0
	var r3 := float((s >> 3) & 0x7FFFFFFF) / 2147483648.0
	var s2: int = s

	var blade_count: int = 7 + int(r2 * 4)
	var clump_r: float = 0.35 + r2 * 0.35
	var max_h: float = 1.0 + r3 * 0.55
	var col_base := Color(0.10 + r3 * 0.05, 0.30 + r3 * 0.12, 0.06 + r3 * 0.03)
	var col_tip := Color(0.18 + r2 * 0.06, 0.44 + r2 * 0.14, 0.09 + r2 * 0.04)
	var cur_dir := Vector3(cos(r3 * TAU), 0, sin(r3 * TAU))

	# Lá kiếm dựng đứng, hơi võng theo gió
	for bi in range(blade_count):
		s2 = s2 * 16807 + 1; var ba := float(s2 & 0x7FFFFFFF) / 2147483648.0 * TAU
		s2 = s2 * 16807 + 1; var br := float(s2 & 0x7FFFFFFF) / 2147483648.0
		var origin := Vector3(cos(ba) * clump_r * sqrt(br), 0, sin(ba) * clump_r * sqrt(br))
		var blade_h: float = max_h * (0.6 + br * 0.6)
		var w: float = VOXEL * (0.28 + r2 * 0.2)
		var segs: int = 3
		var prev := origin
		for seg in range(segs):
			var t := float(seg + 1) / float(segs)
			var nxt := origin + Vector3(0, blade_h * t, 0) \
				+ cur_dir * blade_h * 0.10 * t * t * (0.5 + br * 0.5)
			var mid := (prev + nxt) * 0.5
			var dir := (nxt - prev).normalized()
			var perp := Vector3(-dir.z, 0, dir.x).normalized()
			var taper: float = 1.0 - t * 0.75
			var col := col_base.lerp(col_tip, t * 0.85)
			_add_quad(st, mid, perp * w * 0.5 * taper, dir * (nxt - prev).length() * 0.5, Vector3(0, 1, 0), col)
			prev = nxt

	# Bông trụ nâu — 2-3 trụ trên thân cứng, một số chưa nở (xanh)
	s2 = s2 * 16807 + 1
	var cattail_count: int = 1 + int(float(s2 & 0x7FFFFFFF) / 2147483648.0 > 0.5)
	for ci in range(cattail_count):
		s2 = s2 * 16807 + 1; var ca := float(s2 & 0x7FFFFFFF) / 2147483648.0 * TAU
		s2 = s2 * 16807 + 1; var cr := float(s2 & 0x7FFFFFFF) / 2147483648.0
		var stem_h: float = 1.1 + cr * 0.5
		var origin := Vector3(cos(ca) * clump_r * 0.5, 0, sin(ca) * clump_r * 0.5)
		var sw: float = VOXEL * 0.34
		var prev := origin
		var segs2: int = 4
		for seg in range(segs2):
			var t := float(seg + 1) / float(segs2)
			var nxt := origin + Vector3(0, stem_h * t, 0) + cur_dir * stem_h * 0.05 * t
			var mid := (prev + nxt) * 0.5
			var dir := (nxt - prev).normalized()
			var perp := Vector3(-dir.z, 0, dir.x).normalized()
			_add_quad(st, mid, perp * sw, dir * (nxt - prev).length() * 0.5, Vector3(0, 1, 0), Color(0.28, 0.42, 0.14))
			prev = nxt
		# Trụ bông nâu đậm trên ngọn
		var head_top: Vector3 = origin + Vector3(0, stem_h, 0) + cur_dir * stem_h * 0.05
		var head_h: float = 0.22 + cr * 0.12
		var head_w: float = sw * 2.1
		var col_head := Color(0.30, 0.22, 0.10)
		var prev_h := head_top - Vector3(0, head_h, 0)
		var hsegs: int = 3
		for seg in range(hsegs):
			var t := float(seg + 1) / float(hsegs)
			var nxt := prev_h + Vector3(0, head_h * t, 0)
			var mid := (prev_h + nxt) * 0.5
			var perp := Vector3(-cur_dir.z, 0, cur_dir.x).normalized()
			var taper: float = 1.0 - (t - 0.5) * 0.4 if t > 0.5 else 1.0
			_add_quad(st, mid, perp * head_w * taper * 0.5, Vector3(0, (nxt - prev_h).length() * 0.5, 0), Vector3(0, 1, 0), col_head)
			prev_h = nxt

	var mesh := st.commit()
	if mesh:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.metallic = 0.0
		mat.roughness = 0.9
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

