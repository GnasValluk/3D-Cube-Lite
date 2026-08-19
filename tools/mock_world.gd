extends Node

const BD = preload("res://scripts/world/chunk/chunk_block_data.gd")
const D = preload("res://scripts/world/chunk/chunk_data.gd")

var blocks: Dictionary = {}
var rebuild_count: int = 0
var rebuild_ns: Array[int] = []

func _key(xf: float, ly: int, zf: float) -> String:
	return "%d,%d,%d" % [floori(xf), ly, floori(zf)]

func get_block(wx: float, wy: float, wz: float) -> int:
	var ly: int = BD.world_y_to_layer(wy)
	return blocks.get(_key(wx, ly, wz), D.BlockID.AIR)

## Mô phỏng rebuild mesh của WorldChunk: đếm số lần bị gọi.
func rebuild_mesh(_at: Vector3i = Vector3i(-1, -1, -1)) -> void:
	rebuild_count += 1

func place_block(wx: float, wy: float, wz: float, bid: int, off: int = 4) -> bool:
	var ly: int = BD.world_y_to_layer(wy)
	var k := _key(wx, ly, wz)
	var cur: int = blocks.get(k, D.BlockID.AIR)
	if cur != D.BlockID.AIR and not D.is_water(cur):
		return false
	blocks[k] = bid
	rebuild_mesh()
	return true

## Mô phỏng API mới: đặt hàng loạt nhưng chỉ rebuild 1 lần ở cuối.
func place_blocks_bulk(positions: Array[Vector3], block_ids: Array[int], off: int = 4) -> int:
	var placed: int = 0
	var ly_old: Array[int] = []
	for i in range(positions.size()):
		var p: Vector3 = positions[i]
		var ly: int = BD.world_y_to_layer(p.y)
		var k := _key(p.x, ly, p.z)
		var cur: int = blocks.get(k, D.BlockID.AIR)
		if cur != D.BlockID.AIR and not D.is_water(cur):
			continue
		blocks[k] = block_ids[i]
		placed += 1
	rebuild_mesh()
	return placed