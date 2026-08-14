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