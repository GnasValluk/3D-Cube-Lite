class_name DuckweedProp
extends DestroyableProp

## Bèo tấm (bèo cám) — thảm lá xanh lục nhỏ nổi trên mặt nước của rừng đầm lầy.
## Mọc thành đốm/vạt, trôi nhẹ nhàng. Rơi "duckweed" khi hái bằng tay.

const VOXEL: float = 0.25

func setup() -> void:
	pass

func _ready() -> void:
	super._ready()
	_build_mesh()

func _build_mesh() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var s: int = int(global_position.x * 193.0) ^ int(global_position.z * 613.0)
	s = (s ^ (s >> 13)) * 1274126177; s = s ^ (s >> 16)
	var r2 := float(s & 0x7FFFFFFF) / 2147483648.0
	var s2: int = s

	# Vạt bèo — cụm đốm lá bầu dục xếp lệch, vài chỗ hở ra mặt nước
	var patch_count: int = 4 + int(r2 * 5)
	var patch_r: float = 0.45 + r2 * 0.55
	var col_leaf := Color(0.10 + r2 * 0.06, 0.34 + r2 * 0.10, 0.12 + r2 * 0.04)
	var col_leaf_dark := Color(0.07, 0.26, 0.10)
	var col_leaf_yellow := Color(0.24, 0.38, 0.12)

	var base_pos := Vector3(0, 0, 0)
	for pi in range(patch_count):
		s2 = s2 * 16807 + 1; var pa := float(s2 & 0x7FFFFFFF) / 2147483648.0 * TAU
		s2 = s2 * 16807 + 1; var pr := float(s2 & 0x7FFFFFFF) / 2147483648.0
		var origin := base_pos + Vector3(cos(pa) * patch_r * sqrt(pr), 0, sin(pa) * patch_r * sqrt(pr))
		var leaf_count: int = 2 + int(float(s2 & 0x7FFFFFFF) / 2147483648.0 * 3)
		s2 = s2 * 16807 + 1; var drift := float(s2 & 0x7FFFFFFF) / 2147483648.0 * TAU
		for li in range(leaf_count):
			s2 = s2 * 16807 + 1; var la := float(s2 & 0x7FFFFFFF) / 2147483648.0 * TAU
			s2 = s2 * 16807 + 1; var lr := float(s2 & 0x7FFFFFFF) / 2147483648.0
			var leaf_pos := origin + Vector3(cos(la) * 0.12 * sqrt(lr), 0, sin(la) * 0.12 * sqrt(lr))
			var leaf_w: float = VOXEL * (0.7 + lr * 0.6)
			var leaf_h: float = leaf_w * 0.8
			var angle := la + drift
			var u := Vector3(cos(angle) * leaf_w, 0, sin(angle) * leaf_w)
			var v := Vector3(0, 0.03, 0)
			var col: Color = col_leaf
			var cr := float((s2 >> 2) & 0x7FFFFFFF) / 2147483648.0
			if cr < 0.25:
				col = col_leaf_dark
			elif cr > 0.78:
				col = col_leaf_yellow
			var n := Vector3(0, 1, 0)
			# Hai lá chéo nhau tạo hình bèo
			for mi in range(2):
				var rot := angle + (0.9 if mi == 1 else 0.0)
				var uu := Vector3(cos(rot) * leaf_w * 0.5, 0, sin(rot) * leaf_w * 0.5)
				var vv := Vector3(0, 0.02, 0)
				st.set_normal(n); st.set_color(col)
				st.add_vertex(leaf_pos - uu - vv)
				st.add_vertex(leaf_pos + uu - vv)
				st.add_vertex(leaf_pos + uu + vv)
				st.add_vertex(leaf_pos - uu - vv)
				st.add_vertex(leaf_pos + uu + vv)
				st.add_vertex(leaf_pos - uu + vv)
			# Rễ nhỏ chúi xuống nước
			s2 = s2 * 16807 + 1
			if float(s2 & 0x7FFFFFFF) / 2147483648.0 < 0.5:
				var root := leaf_pos + Vector3(0, -0.12, 0)
				var root_u := Vector3(0.012, 0, 0)
				var root_v := Vector3(0, 0.09, 0)
				st.set_normal(n); st.set_color(Color(0.16, 0.30, 0.10))
				st.add_vertex(root - root_u)
				st.add_vertex(root + root_u)
				st.add_vertex(root + root_u + root_v)
				st.add_vertex(root - root_u)
				st.add_vertex(root + root_u + root_v)
				st.add_vertex(root - root_u + root_v)

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