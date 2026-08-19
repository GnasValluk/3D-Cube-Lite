## ChunkBlockData — lưu trữ 3D block grid cho 1 chunk
## QUAN TRỌNG: Mỗi block là SLAB cao 0.5 unit (nửa block Minecraft)
## → 2 block slab chồng lên = 1 unit Godot
extends RefCounted

const _Data = preload("chunk_data.gd")

var size_x: int = 0
var size_z: int = 0
var _chunk_h: int = 21

## Y range: world Y từ Y_MIN đến Y_MAX (inclusive)
## SLAB_HEIGHT = 0.5, WATER_Y = 0.5
## Terrain cao nhất (DARK_GRASS) = 1.0
const Y_MIN: int = -18
const Y_MAX: int = 50
const CHUNK_H: int = Y_MAX - Y_MIN + 1   # = 69
const SLAB_HEIGHT: float = 0.5

## Offset nội-ô (sub-cell 0.25): mỗi cell lưu 1 byte.
## Grid mịn: dx/dz ∈ -3..3 (bước 0.25) → box tâm lệch ±0.75 so chuẩn. Đủ để
## 2 khối hộp 0.5 đặt ở 2 ô liền có thể ghép khít nhau (khối khe "nhô sang ô kế").
## Index = (dx+3)*7 + (dz+3) → 0..48. OFF_CENTER = 24 (dx=dz=0 → tâm ô chuẩn).
const OFF_CENTER: int = 24
const OFF_DX_MIN: int = -3
const OFF_DX_MAX: int = 3
const OFF_STEP: float = 0.25

var _data: PackedByteArray
var _off: PackedByteArray
var dirty: bool = false

func init(sx: int, sz: int) -> void:
	size_x = sx
	size_z = sz
	_chunk_h = Y_MAX - Y_MIN + 1
	_data = PackedByteArray()
	_data.resize(size_x * _chunk_h * size_z)
	_data.fill(0)
	_off = PackedByteArray()
	_off.resize(size_x * _chunk_h * size_z)
	_off.fill(OFF_CENTER)

func _idx(x: int, y: int, z: int) -> int:
	return x * _chunk_h * size_z + y * size_z + z

func get_block(x: int, y: int, z: int) -> int:
	if x < 0 or x >= size_x or z < 0 or z >= size_z:
		return _Data.BlockID.AIR
	if y < 0 or y >= _chunk_h:
		return _Data.BlockID.AIR
	return _data[_idx(x, y, z)]

func set_block(x: int, y: int, z: int, block_id: int) -> void:
	if x < 0 or x >= size_x or z < 0 or z >= size_z:
		return
	if y < 0 or y >= _chunk_h:
		return
	var i: int = _idx(x, y, z)
	if _data[i] != block_id:
		_data[i] = block_id
		dirty = true

## Offset nội-ô (index đã encode, OFF_CENTER = tâm). Trả OFF_CENTER nếu
## block này chưa từng được đặt với offset (chunk cũ / chưa init).
func get_offset(x: int, y: int, z: int) -> int:
	if _off.size() == 0:
		return OFF_CENTER
	if x < 0 or x >= size_x or z < 0 or z >= size_z:
		return OFF_CENTER
	if y < 0 or y >= _chunk_h:
		return OFF_CENTER
	return _off[_idx(x, y, z)]

func set_offset(x: int, y: int, z: int, off: int) -> void:
	if off == OFF_CENTER:
		return
	if x < 0 or x >= size_x or z < 0 or z >= size_z:
		return
	if y < 0 or y >= _chunk_h:
		return
	if _off.size() == 0:
		_off = PackedByteArray()
		_off.resize(size_x * _chunk_h * size_z)
		_off.fill(OFF_CENTER)
	if _off[_idx(x, y, z)] != off:
		_off[_idx(x, y, z)] = off
		dirty = true

## Giải mã offset → dịch (dx, dz) tính bằng unit so với tâm ô.
static func offset_delta(off: int) -> Vector2:
	if off == OFF_CENTER:
		return Vector2.ZERO
	var dx: int = off / 7 - 3
	var dz: int = off % 7 - 3
	return Vector2(float(dx) * OFF_STEP, float(dz) * OFF_STEP)

## Mã hoá offset từ delta (dx, dz unit, bước OFF_STEP). Ép về khoảng ±0.75.
static func offset_index(delta: Vector2) -> int:
	var dx: int = clampi(roundi(delta.x / OFF_STEP), OFF_DX_MIN, OFF_DX_MAX)
	var dz: int = clampi(roundi(delta.y / OFF_STEP), OFF_DX_MIN, OFF_DX_MAX)
	return (dx + 3) * 7 + (dz + 3)

## World-Y (float, Godot units) → slab layer index
## world_y = 0.5 → layer 1 (0.0-0.5)
## world_y = 1.0 → layer 2 (0.5-1.0)
static func world_y_to_layer(wy: float) -> int:
	return floori(wy / SLAB_HEIGHT) - Y_MIN

## Slab layer index → world-Y (float, tâm slab)
## layer 0 (Y_MIN=-18) → world_y = -8.75
## layer 1 → -8.25, layer 2 → -7.75 ...
static func layer_to_world_y(layer: int) -> float:
	return (float(layer + Y_MIN) + 0.5) * SLAB_HEIGHT

func to_bytes() -> PackedByteArray:
	if _off.size() == 0:
		return _data.duplicate()
	return _data.duplicate() + _off.duplicate()

func from_bytes(bytes: PackedByteArray, sx: int, sz: int) -> void:
	size_x = sx
	size_z = sz
	_chunk_h = Y_MAX - Y_MIN + 1
	var used: int = size_x * _chunk_h * size_z
	if bytes.size() >= used * 2:
		_data = bytes.slice(0, used)
		_off = bytes.slice(used, used * 2)
	else:
		_data = bytes.duplicate()
		_chunk_h = _data.size() / (size_x * size_z)
		_off = PackedByteArray()
	dirty = false
