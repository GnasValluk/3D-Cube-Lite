## world/explore_system.gd – Hệ thống khám phá bản đồ
extends Node
class_name ExploreSystem

const CELL_SIZE: float = 2.0
const EXPLORE_RADIUS: float = 14.0

const _Data = preload("res://scripts/world/chunk/chunk_data.gd")
const _BlockData = preload("res://scripts/world/chunk/chunk_block_data.gd")
const _Dim = preload("res://scripts/world/dimension_defs.gd")
const _Noise = preload("res://scripts/world/chunk/chunk_noise.gd")

var _explored: Dictionary = {}
var _explore_version: int = 0
var _dirty: bool = false
var _player: Node3D = null

var _explore_timer: float = 0.0
var _dimension_id: int = _Dim.DimensionID.TWILIGHT
var _world_mgr: OpenWorldManager = null


func _ready() -> void:
	_world_mgr = get_node("../WorldManager") as OpenWorldManager
	if _world_mgr:
		_dimension_id = _world_mgr.dimension_id

func set_player(p: Node3D) -> void:
	_player = p

func get_explored() -> Dictionary:
	return _explored

func get_explore_version() -> int:
	return _explore_version

func is_dirty() -> bool:
	return _dirty

func serialize() -> Dictionary:
	var out: Dictionary = {}
	for key in _explored:
		var c: Color = _explored[key]
		out["%d,%d" % [key.x, key.y]] = [c.r, c.g, c.b, c.a]
	return {"dimension": _dimension_id, "cells": out}

func deserialize(data: Dictionary) -> void:
	if data.has("dimension"):
		_dimension_id = data["dimension"]
	var cells: Dictionary = data.get("cells", {})
	for key_str in cells:
		var parts = key_str.split(",")
		if parts.size() == 2:
			var v := Vector2i(int(parts[0]), int(parts[1]))
			var c_arr: Array = cells[key_str]
			if c_arr.size() == 4:
				_explored[v] = Color(c_arr[0], c_arr[1], c_arr[2], c_arr[3])
	_dirty = true
	_explore_version += 1

func mark_all_explored_in_rect(x_min: float, x_max: float, z_min: float, z_max: float, color: Color) -> void:
	var cmin_x: int = int(floor(x_min / CELL_SIZE))
	var cmax_x: int = int(floor(x_max / CELL_SIZE))
	var cmin_z: int = int(floor(z_min / CELL_SIZE))
	var cmax_z: int = int(floor(z_max / CELL_SIZE))
	var any_new: bool = false
	for cx in range(cmin_x, cmax_x + 1):
		for cz in range(cmin_z, cmax_z + 1):
			var key := Vector2i(cx, cz)
			if not _explored.has(key):
				_explored[key] = color
				_dirty = true
				any_new = true
	if any_new:
		_explore_version += 1

func _process(delta: float) -> void:
	if _player == null:
		_find_player()
		return
	_explore_timer -= delta
	if _explore_timer <= 0.0:
		_explore_timer = 0.3
		_dirty = false
		_update_explored()

func _find_player() -> void:
	var mgr := get_node("../CharacterManager") as CharacterManager
	if mgr:
		_player = mgr.get_current_character()

func _update_explored() -> void:
	if _player == null:
		return
	var pos := _player.global_position
	var cx: int = int(floor(pos.x / CELL_SIZE))
	var cz: int = int(floor(pos.z / CELL_SIZE))
	var r: int = ceili(EXPLORE_RADIUS / CELL_SIZE)
	var any_new: bool = false
	for dx in range(-r, r + 1):
		for dz in range(-r, r + 1):
			var cell := Vector2i(cx + dx, cz + dz)
			if _explored.has(cell):
				continue
			var wcx: float = (cell.x + 0.5) * CELL_SIZE
			var wcz: float = (cell.y + 0.5) * CELL_SIZE
			var dist := Vector2(pos.x - wcx, pos.z - wcz).length()
			if dist <= EXPLORE_RADIUS:
				_explored[cell] = _sample_color(wcx, wcz)
				_dirty = true
				any_new = true
	if any_new:
		_explore_version += 1

func _sample_color(wx: float, wz: float) -> Color:
	if _dimension_id == _Dim.DimensionID.REAL_WORLD:
		return _sample_color_rw(wx, wz)
	return _sample_color_tw(wx, wz)

func _sample_color_rw(wx: float, wz: float) -> Color:
	var colors: Array[Color] = _Data.BLOCK_COLORS_RW

	# Ưu tiên: đọc block thực tế từ chunk nếu có
	if _world_mgr:
		var chunk: Node = _world_mgr.get_chunk_at(wx, wz)
		if chunk is WorldChunk:
			var wc: WorldChunk = chunk as WorldChunk
			if wc.block_data != null:
				var bd: _BlockData = wc.block_data
				var org: float = wc._cx * 32.0 - 16.0
				var orgz: float = wc._cz * 32.0 - 16.0
				var lx: int = clampi(floori(wx - org), 0, 31)
				var lz: int = clampi(floori(wz - orgz), 0, 31)
				var top_bid: int = _Data.BlockID.AIR
				var top_ly: int = -1
				var floor_ly: int = -1
				for ly in range(_BlockData.CHUNK_H - 1, -1, -1):
					var bid: int = bd.get_block(lx, ly, lz)
					if bid == _Data.BlockID.WATER and top_bid == _Data.BlockID.AIR:
						top_bid = _Data.BlockID.WATER
						top_ly = ly
					elif bid != _Data.BlockID.AIR and bid != _Data.BlockID.WATER:
						if top_bid == _Data.BlockID.AIR:
							top_bid = bid
						floor_ly = ly
						break
				if top_bid == _Data.BlockID.WATER:
					var depth_t: float = 1.0
					if floor_ly >= 0:
						var floor_y: float = _BlockData.layer_to_world_y(floor_ly) + _BlockData.SLAB_HEIGHT
						var water_y: float = _BlockData.layer_to_world_y(top_ly)
						depth_t = clamp((water_y - floor_y) / 5.0, 0.0, 1.0)
					return Color(0.04, lerp(0.38, 0.12, depth_t), lerp(0.68, 0.30, depth_t))
				if top_bid != _Data.BlockID.AIR and top_bid < colors.size():
					return colors[top_bid]

	# Fallback noise nếu chunk chưa load
	return _sample_color_rw_fallback(wx, wz)

func _sample_color_rw_fallback(wx: float, wz: float) -> Color:
	var nd: Dictionary = _Noise._noise_for_dim(_dimension_id)
	var n_biome: FastNoiseLite = nd["biome"]

	# Sa mạc
	var n_desert: FastNoiseLite = nd.get("desert") as FastNoiseLite
	if n_desert:
		var dv: float = (n_desert.get_noise_2d(wx, wz) + 1.0) * 0.5
		if dv > 0.55:
			if _is_river(wx, wz):
				return Color(0.08, 0.38, 0.72, 0.70)
			var pd: float = (nd.get("patch2") as FastNoiseLite).get_noise_2d(wx, wz) \
					if nd.get("patch2") else 0.0
			if pd > 0.72:
				return Color(0.94, 0.88, 0.62)   # PALE_SAND
			return Color(0.92, 0.78, 0.32)

	# Cao nguyên (đồng bằng cao) — khớp _biome_at: xa spawn, mask > 0.55
	var n_highland: FastNoiseLite = nd.get("highland") as FastNoiseLite
	if n_highland:
		var hv: float = (n_highland.get_noise_2d(wx, wz) + 1.0) * 0.5
		if hv > 0.55 and (wx * wx + wz * wz) > 1500000.0:
			return Color(0.16, 0.54, 0.10)

	# Sông
	if _is_river(wx, wz):
		return Color(0.08, 0.38, 0.72, 0.70)
	# Đường
	if _is_road(wx, wz):
		return Color(0.68, 0.52, 0.26)

	# Biển
	var n_ocean: FastNoiseLite = nd["ocean"]
	var ow: FastNoiseLite = nd["ocean_warp"]
	var warp_x: float = ow.get_noise_2d(wx * 0.5, wz * 0.5) * 200.0
	var warp_z: float = ow.get_noise_2d(wx * 0.5 + 100.0, wz * 0.5 + 100.0) * 200.0
	var is_ocean: bool = (n_ocean.get_noise_2d(wx + warp_x, wz + warp_z) + 1.0) * 0.5 > _Data.OCEAN_THRESHOLD
	if is_ocean:
		var dist_to_shore: float = _ocean_shore_dist(wx, wz, nd)
		if dist_to_shore < 5.0:
			return Color(0.72, 0.82, 0.55)
		var ocean_depth_t: float = clamp((dist_to_shore - 5.0) / 45.0, 0.0, 1.0)
		return Color(0.04, lerp(0.35, 0.15, ocean_depth_t), lerp(0.60, 0.35, ocean_depth_t))

# Đồng bằng cỏ (nhiều loại cỏ) — bãi đất/bãi cỏ non như compute_chunk
	var dn: float = (n_biome.get_noise_2d(wx * 0.7 + 500.0, wz * 0.7 + 500.0) + 1.0) * 0.5
	if dn > 0.74:
		return Color(0.42, 0.22, 0.08)                # DIRT
	if dn > 0.71:
		return Color(0.55, 0.48, 0.14)                # DRY_GRASS (cỏ già)
	if dn > 0.68:
		return Color(0.44, 0.38, 0.13)                # YOUNG_GRASS
	if dn > 0.65:
		return Color(0.28, 0.42, 0.10)                # SPARSE_GRASS (cỏ thưa)
	if dn > 0.61:
		return Color(0.11, 0.46, 0.07)                # DARK_GRASS
	if dn > 0.56:
		return Color(0.22, 0.58, 0.14)                # GRASS

	var n_lake: FastNoiseLite = nd["lake"]
	var lake_val: float = (n_lake.get_noise_2d(wx, wz) + 1.0) * 0.5
	if lake_val > 0.68:
		return Color(0.08, 0.36, 0.68, 0.70)

	return Color(0.16, 0.54, 0.10)                    # GRASS_DIRT

func _sample_color_tw(wx: float, wz: float) -> Color:
	var nd: Dictionary = _Noise._noise_for_dim(_dimension_id)
	var n_biome: FastNoiseLite = nd["biome"]
	var n_warp: FastNoiseLite = nd["warp"]
	var wx_off: float = n_warp.get_noise_2d(wx, wz + 100.0) * 18.0
	var wz_off: float = n_warp.get_noise_2d(wx + 100.0, wz) * 18.0
	var n: float = (n_biome.get_noise_2d(wx + wx_off, wz + wz_off) + 1.0) * 0.5
	if n >= 0.50:
		return Color(0.03, 0.12, 0.08)
	return Color(0.06, 0.22, 0.16)

func _ocean_shore_dist(wx: float, wz: float, nd: Dictionary) -> float:
	var n_ocean: FastNoiseLite = nd["ocean"]
	var ow: FastNoiseLite = nd["ocean_warp"]
	var rings: Array[int] = [2, 4, 6, 8, 10, 15, 20, 30, 40, 50]
	for ri in range(rings.size()):
		var r: int = rings[ri]
		for off in [Vector2(r, 0), Vector2(-r, 0), Vector2(0, r), Vector2(0, -r)]:
			var ox: float = wx + off.x
			var oz: float = wz + off.y
			var wx2: float = ow.get_noise_2d(ox * 0.5, oz * 0.5) * 200.0
			var wz2: float = ow.get_noise_2d(ox * 0.5 + 100.0, oz * 0.5 + 100.0) * 200.0
			if (n_ocean.get_noise_2d(ox + wx2, oz + wz2) + 1.0) * 0.5 <= _Data.OCEAN_THRESHOLD:
				return float(r)
	return 999.0

func _is_road(wx: float, wz: float) -> bool:
	return WorldChunk._is_on_road(wx, wz)

func _is_river(wx: float, wz: float) -> bool:
	return WorldChunk._is_on_river(wx, wz)
