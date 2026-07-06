## ChunkBlockData — lưu trữ 3D block grid cho 1 chunk
## QUAN TRỌNG: Mỗi block là SLAB cao 0.5 unit (nửa block Minecraft)
## → 2 block slab chồng lên = 1 unit Godot
extends RefCounted

const _Data = preload("chunk_data.gd")

var size_x: int = 0
var size_z: int = 0

## Y range: world Y từ Y_MIN đến Y_MAX (inclusive)
## SLAB_HEIGHT = 0.5, WATER_Y = 0.5 (nằm ở top của slab layer 1)
## Terrain cao nhất (DARK_GRASS) = 1.0 = top của slab layer 2
## GIẢM layers để fix crash: Y_MIN = -6 → Y_MAX = 2 (9 slab layers)
## → World Y từ -3.0 đến +1.0 (unit Godot)
const Y_MIN: int = -10   # slab layer index — mở rộng để hỗ trợ đáy biển y=-4
const Y_MAX: int = 2
const CHUNK_H: int = Y_MAX - Y_MIN + 1   # = 13 slab layers
const SLAB_HEIGHT: float = 0.5

var _data: PackedByteArray
var dirty: bool = false

func init(sx: int, sz: int) -> void:
	size_x = sx
	size_z = sz
	_data = PackedByteArray()
	_data.resize(size_x * CHUNK_H * size_z)
	_data.fill(0)

func _idx(x: int, y: int, z: int) -> int:
	return x * CHUNK_H * size_z + y * size_z + z

func get_block(x: int, y: int, z: int) -> int:
	if x < 0 or x >= size_x or z < 0 or z >= size_z:
		return _Data.BlockID.AIR
	if y < 0 or y >= CHUNK_H:
		return _Data.BlockID.AIR
	return _data[_idx(x, y, z)]

func set_block(x: int, y: int, z: int, block_id: int) -> void:
	if x < 0 or x >= size_x or z < 0 or z >= size_z:
		return
	if y < 0 or y >= CHUNK_H:
		return
	var i: int = _idx(x, y, z)
	if _data[i] != block_id:
		_data[i] = block_id
		dirty = true

## World-Y (float, Godot units) → slab layer index
## world_y = 0.5 → layer 1 (0.0-0.5)
## world_y = 1.0 → layer 2 (0.5-1.0)
static func world_y_to_layer(wy: float) -> int:
	return floori(wy / SLAB_HEIGHT) - Y_MIN

## Slab layer index → world-Y (float, tâm slab)
## layer 0 (Y_MIN=-8) → world_y = -4.0 + 0.25 = -3.75
## layer 1 → -3.25, layer 2 → -2.75 ...
static func layer_to_world_y(layer: int) -> float:
	return (float(layer + Y_MIN) + 0.5) * SLAB_HEIGHT

func to_bytes() -> PackedByteArray:
	return _data.duplicate()

func from_bytes(bytes: PackedByteArray, sx: int, sz: int) -> void:
	size_x = sx
	size_z = sz
	_data = bytes.duplicate()
	dirty = false
