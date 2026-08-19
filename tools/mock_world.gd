extends Node

const BD = preload("res://scripts/world/chunk/chunk_block_data.gd")
const D = preload("res://scripts/world/chunk/chunk_data.gd")

var blocks: Dictionary = {}

func _key(xf: float, ly: int, zf: float) -> String:
	return "%d,%d,%d" % [floori(xf), ly, floori(zf)]

func get_block(wx: float, wy: float, wz: float) -> int:
	var ly: int = BD.world_y_to_layer(wy)
	return blocks.get(_key(wx, ly, wz), D.BlockID.AIR)

func place_block(wx: float, wy: float, wz: float, bid: int, off: int = 4) -> bool:
	var ly: int = BD.world_y_to_layer(wy)
	var k := _key(wx, ly, wz)
	var cur: int = blocks.get(k, D.BlockID.AIR)
	if cur != D.BlockID.AIR and not D.is_water(cur):
		return false
	blocks[k] = bid
	return true