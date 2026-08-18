class_name VoxelShared
extends Object

## Cache dùng chung cho MỌI cây/vật voxel: 1 BoxMesh unit + 1 StandardMaterial3D
## dùng chung (vertex color làm albedo). Trước đây mỗi prop tự tạo mesh + material
## mới → N cây = N RID + N shader state. Dùng chung giúp GPU pipeline cache,
## giảm allocation và giữ bộ nhớ thấp.
##
## Kích thước voxel được set bằng per-instance scale trong MultiMesh (TRANSFORM_3D),
## cho phép cùng 1 mesh vẽ cả thân (lưới 0.125) lẫn lá (lưới 0.1875) trong
## cùng multi-mesh — đúng cỡ lưới nên nhìn ngang không còn khe rỗng giữa cube.

const TRUNK_SCALE: float = 0.13    # lưới thân 2×VOXEL (0.125) + overlap che khe
const BRANCH_SCALE: float = 0.075  # cành mảnh
const LEAF_SCALE: float = 0.20     # lưới lá 3×VOXEL (0.1875) + overlap
const FINE_SCALE: float = 0.07     # trái / cây mảnh / mầm (lưới 1×VOXEL)

# Cỡ tối đa (unit icon) của model khúc gỗ khi drop — nhỏ hơn khối gỗ để
# người chơi phân biệt được khúc cây (thân thật) với block gỗ đặt được.
const LOG_ITEM_TARGET: float = 2.0

static var _box: BoxMesh = null
static var _mat: StandardMaterial3D = null

## BoxMesh 1×1×1 — scale theo instance.
static func box() -> BoxMesh:
	if _box == null:
		_box = BoxMesh.new()
		_box.size = Vector3.ONE
	return _box

## Material dùng chung: màu lấy từ vertex color, không kim loại, roughness trung bình.
static func mat() -> StandardMaterial3D:
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.vertex_color_use_as_albedo = true
		_mat.metallic = 0.0
		_mat.roughness = 0.85
	return _mat

## Tạo MultiMeshInstance3D từ 3 mảng song song (vị trí, cỡ, màu) — 1 draw call.
static func build(positions: Array, scales: Array, colors: Array) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = box()
	mm.instance_count = positions.size()
	# Đổ transform + color bằng 1 lệnh set_buffer thay vì loop
	# set_instance_transform/color — nhanh hơn ~3x cho hàng trăm voxel/cây.
	var n: int = positions.size()
	if n > 0:
		var buf := PackedFloat32Array()
		buf.resize(n * 16)
		var k: int = 0
		for i in range(n):
			var p: Vector3 = positions[i]
			var s: float = scales[i]
			var c: Color = colors[i]
			buf[k] = s; buf[k + 1] = 0.0; buf[k + 2] = 0.0; buf[k + 3] = p.x
			buf[k + 4] = 0.0; buf[k + 5] = s; buf[k + 6] = 0.0; buf[k + 7] = p.y
			buf[k + 8] = 0.0; buf[k + 9] = 0.0; buf[k + 10] = s; buf[k + 11] = p.z
			buf[k + 12] = c.r; buf[k + 13] = c.g; buf[k + 14] = c.b; buf[k + 15] = c.a
			k += 16
		mm.set_buffer(buf)
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat()
	return mmi

## Transform cho 1 instance với scale — dùng khi tự điền MultiMesh.
static func xform(pos: Vector3, s: float) -> Transform3D:
	return Transform3D(Basis.from_scale(Vector3.ONE * s), pos)

## Canh giữa + thu/phóng đều về quanh gốc tọa độ sao cho kích thước lớn nhất =
## target (unit), rồi build MultiMesh. Dùng cho model khúc cây (bộ xương thân
## cây thật) khi gắn vào item drop. Không đọc lại transform qua
## get_instance_transform (sau set_buffer không đáng tin cậy), mà biến đổi
## thẳng mảng vị trí trước khi build.
static func build_centered(positions: Array, voxel_size: float, colors: Array, target: float) -> MultiMeshInstance3D:
	var n := positions.size()
	if n == 0:
		return null
	var minv := Vector3.INF
	var maxv := -Vector3.INF
	for i in range(n):
		var o: Vector3 = positions[i]
		minv = Vector3(minf(minv.x, o.x), minf(minv.y, o.y), minf(minv.z, o.z))
		maxv = Vector3(maxf(maxv.x, o.x), maxf(maxv.y, o.y), maxf(maxv.z, o.z))
	var ext := maxv - minv
	var m := maxf(maxf(ext.x, ext.y), ext.z)
	var s := 1.0
	if m > 0.0001:
		s = target / m
	var center := (minv + maxv) * 0.5
	var pos2: Array = []
	var sc2: Array = []
	for i in range(n):
		pos2.append((positions[i] as Vector3 - center) * s)
		sc2.append(voxel_size * s)
	return build(pos2, sc2, colors)

## ── Sway budget: chỉ tính sway cho prop GẦN camera ───────────────────────────
## Hàng trăm cây/cỏ biển mỗi cây chạy `_process` + vài sin/cos mỗi frame dù ở
## xa ngoài tầm mắt → tốn CPU trên máy yếu/mobile. Helper này cache vị trí
## camera + thời gian 1 lần/frame (static), mỗi prop chỉ so khoảng cách rất rẻ.
static var _cam_pos: Vector3 = Vector3.INF
static var _cam_frame: int = -1
static var _time_sec: float = 0.0

static func _refresh_frame() -> void:
	var f := Engine.get_process_frames()
	if f == _cam_frame:
		return
	_cam_frame = f
	_time_sec = Time.get_ticks_usec() * 0.000001
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		var cam := tree.root.get_camera_3d()
		_cam_pos = cam.global_position if cam != null else Vector3.INF
	else:
		_cam_pos = Vector3.INF

## Thời gian (giây) cache 1 lần/frame — thay Time.get_ticks_usec() mỗi prop.
static func time_sec() -> float:
	_refresh_frame()
	return _time_sec

## Prop có đáng sway không? `max_dist <= 0` (hoặc không có camera) → luôn true.
static func sway_active(pos: Vector3, max_dist: float) -> bool:
	if max_dist <= 0.0:
		return true
	_refresh_frame()
	if _cam_pos == Vector3.INF:
		return true
	return _cam_pos.distance_squared_to(pos) <= max_dist * max_dist