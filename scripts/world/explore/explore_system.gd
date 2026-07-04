## world/explore_system.gd – Hệ thống khám phá bản đồ
extends Node
class_name ExploreSystem

const CELL_SIZE: float = 2.0
const EXPLORE_RADIUS: float = 6.0

const _Dim = preload("res://scripts/world/dimension_defs.gd")

var _explored: Dictionary = {}
var _dirty: bool = false
var _player: Node3D = null

var _dimension_id: int = _Dim.DimensionID.TWILIGHT

var _noise_biome: FastNoiseLite
var _noise_warp: FastNoiseLite

func _ready() -> void:
	var owm := get_node("../WorldManager") as OpenWorldManager
	if owm:
		_dimension_id = owm.dimension_id

	var base_seed: int = WorldSeed.seed_value + _dimension_id * 1000
	var freq_bio: float = 0.008
	if _dimension_id == _Dim.DimensionID.REAL_WORLD:
		freq_bio = 0.012

	_noise_biome = FastNoiseLite.new()
	_noise_biome.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise_biome.seed = base_seed
	_noise_biome.frequency = freq_bio
	_noise_warp = FastNoiseLite.new()
	_noise_warp.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_noise_warp.seed = base_seed + 99
	_noise_warp.frequency = 0.022

func set_player(p: Node3D) -> void:
	_player = p

func get_explored() -> Dictionary:
	return _explored

func is_dirty() -> bool:
	var d: bool = _dirty
	_dirty = false
	return d

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

func mark_all_explored_in_rect(x_min: float, x_max: float, z_min: float, z_max: float, color: Color) -> void:
	var cmin_x: int = int(floor(x_min / CELL_SIZE))
	var cmax_x: int = int(floor(x_max / CELL_SIZE))
	var cmin_z: int = int(floor(z_min / CELL_SIZE))
	var cmax_z: int = int(floor(z_max / CELL_SIZE))
	for cx in range(cmin_x, cmax_x + 1):
		for cz in range(cmin_z, cmax_z + 1):
			var key := Vector2i(cx, cz)
			if not _explored.has(key):
				_explored[key] = color
				_dirty = true

func _process(delta: float) -> void:
	if _player == null:
		_find_player()
		return
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

func _sample_color(wx: float, wz: float) -> Color:
	var wx_off: float = _noise_warp.get_noise_2d(wx, wz + 100.0) * 18.0
	var wz_off: float = _noise_warp.get_noise_2d(wx + 100.0, wz) * 18.0
	var n: float = (_noise_biome.get_noise_2d(wx + wx_off, wz + wz_off) + 1.0) * 0.5
	var threshold: float = 0.40 if _dimension_id == _Dim.DimensionID.REAL_WORLD else 0.50
	var is_dark: bool = n >= threshold

	# Road on land only (not underwater)
	if _dimension_id == _Dim.DimensionID.REAL_WORLD and _is_road(wx, wz):
		return Color(0.68, 0.52, 0.26)

	if _dimension_id == _Dim.DimensionID.REAL_WORLD:
		if is_dark:
			var dn: float = (_noise_biome.get_noise_2d(wx + 500.0, wz + 500.0) + 1.0) * 0.5
			if dn > 0.78:
				return Color(0.32, 0.18, 0.08)
			return Color(0.20, 0.35, 0.12)

		# GRASS → approximate distance-field: check expanding rings for DARK_GRASS
		var found_dark: bool = false
		var nearest_ring: int = 999
		var rings: Array[int] = [2, 4, 6, 8, 10]
		for ri in range(rings.size()):
			var r: int = rings[ri]
			for off in [Vector2(r, 0), Vector2(-r, 0), Vector2(0, r), Vector2(0, -r)]:
				var ox: float = wx + off.x
				var oz: float = wz + off.y
				var ox_off: float = _noise_warp.get_noise_2d(ox, oz + 100.0) * 18.0
				var oz_off: float = _noise_warp.get_noise_2d(ox + 100.0, oz) * 18.0
				var nn: float = (_noise_biome.get_noise_2d(ox + ox_off, oz + oz_off) + 1.0) * 0.5
				if nn >= threshold:
					found_dark = true
					nearest_ring = ri
					break
			if found_dark:
				break

		if not found_dark:
			return Color(0.06, 0.25, 0.55)
		if nearest_ring == 0:
			return Color(0.90, 0.80, 0.42)
		var t: float = float(nearest_ring) / 4.0
		return Color(0.08, 0.36 - t * 0.18, 0.68 - t * 0.18)

	if is_dark:
		return Color(0.03, 0.12, 0.08)
	return Color(0.06, 0.22, 0.16)

func _is_road(wx: float, wz: float) -> bool:
	return WorldChunk._is_on_road(wx, wz)
