class_name SlashTrailVFX
extends Node3D

## Vệt kiếm RIBBON theo đúng đường vung THẬT của lưỡi.
## Mỗi tick physics lấy 2 điểm (gốc lưỡi + mũi lưỡi) từ weapon_pivot đang
## animate, nối thành dải tam giác phát sáng mờ dần theo tuổi.
##
## Vì mẫu trực tiếp từ transform của lưỡi nên vệt LUÔN ĐÚNG theo animation —
## không cần chỉnh tay hướng/mặt phẳng cho từng đòn như VFX cung tĩnh cũ.
##
## Mesh dùng top_level = true → toạ độ đỉnh là WORLD space: player lao tới
## trong lúc vung thì vệt chém in đúng quỹ đạo trong không gian.

const MAX_SEGMENTS := 28

var _color := Color.WHITE
var _base_y := 0.16      # điểm gốc lưỡi (trục +Y cục bộ của weapon_pivot)
var _tip_y := 0.60       # mũi lưỡi
var _life := 0.24        # tuổi thọ mỗi đoạn trail (giây)
var _recording := true
var _bases: Array[Vector3] = []
var _tips: Array[Vector3] = []
var _ages: Array[float] = []
var _total_age := 0.0

var _mi: MeshInstance3D = null

func setup(color: Color, tip_y: float, life: float, base_y: float = 0.16) -> void:
	_color = color
	_tip_y = tip_y
	_base_y = base_y
	_life = maxf(life, 0.10)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD          # cộng sáng — vệt kiếm glow
	mat.vertex_color_use_as_albedo = true                   # alpha gradient qua vertex color
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED            # nhìn được cả 2 mặt
	mat.disable_receive_shadows = true
	mat.albedo_color = Color(1, 1, 1, 1)
	_mi = MeshInstance3D.new()
	_mi.mesh = ArrayMesh.new()
	_mi.material_override = mat
	_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mi)
	# Đỉnh mesh lưu ở WORLD space → tách _mi khỏi cây transform của weapon
	# (top_level) để vệt in đúng quỹ đạo tuyệt đối, kể cả khi player lao tới.
	_mi.top_level = true
	_mi.global_transform = Transform3D.IDENTITY

func stop_recording() -> void:
	_recording = false

func _physics_process(delta: float) -> void:
	var wp := get_parent() as Node3D
	if wp == null or not is_instance_valid(wp):
		queue_free()
		return
	_total_age += delta

	if _recording:
		var b: Vector3 = wp.to_global(Vector3(0, _base_y, 0))
		var t: Vector3 = wp.to_global(Vector3(0, _tip_y, 0))
		# Teleport/respawn → nhảy vị trí lớn: xoá trail cũ khỏi bị kéo sợi sai
		if not _bases.is_empty() and _bases[_bases.size() - 1].distance_to(b) > 2.0:
			_bases.clear()
			_tips.clear()
			_ages.clear()
		_bases.append(b)
		_tips.append(t)
		_ages.append(0.0)
		while _bases.size() > MAX_SEGMENTS:
			_bases.remove_at(0)
			_tips.remove_at(0)
			_ages.remove_at(0)

	for i in range(_ages.size()):
		_ages[i] += delta
	while not _ages.is_empty() and _ages[0] >= _life:
		_bases.remove_at(0)
		_tips.remove_at(0)
		_ages.remove_at(0)

	_rebuild_mesh()

	if not _recording and _bases.size() < 2:
		queue_free()
	elif _total_age > 2.0:
		queue_free()   # vanh đai an toàn — không bao giờ sống quá 2s

func _rebuild_mesh() -> void:
	if _mi == null:
		return
	if _bases.size() < 2:
		_mi.mesh = ArrayMesh.new()
		return
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(_bases.size() - 1):
		var a0: float = clampf(1.0 - _ages[i] / _life, 0.0, 1.0)
		var a1: float = clampf(1.0 - _ages[i + 1] / _life, 0.0, 1.0)
		a0 *= a0   # bình phương → đầu sáng đuôi mềm
		a1 *= a1
		if a0 <= 0.01 and a1 <= 0.01:
			continue
		var c0 := Color(_color.r, _color.g, _color.b, a0)
		var c1 := Color(_color.r, _color.g, _color.b, a1)
		var b0 := _bases[i]
		var t0 := _tips[i]
		var b1 := _bases[i + 1]
		var t1 := _tips[i + 1]
		st.set_color(c0); st.add_vertex(b0)
		st.set_color(c0); st.add_vertex(t0)
		st.set_color(c1); st.add_vertex(t1)
		st.set_color(c0); st.add_vertex(b0)
		st.set_color(c1); st.add_vertex(t1)
		st.set_color(c1); st.add_vertex(b1)
	_mi.mesh = st.commit()
