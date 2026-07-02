extends RefCounted

enum TileType { GRASS, DARK_GRASS, SAND, DIRT, SILT }

const VOXEL: float = 1.0
const TILE_W: int = 5
const TILE_D: int = 5

const ROAD_COLOR: Color = Color(0.45, 0.45, 0.45)
const ROAD_SIDE: Color = Color(0.30, 0.30, 0.30)
const TRAIL_COLOR: Color = Color(0.68, 0.52, 0.26)
const TRAIL_SIDE: Color = Color(0.46, 0.36, 0.18)

const PAD: int = 5
const WATER_Y: float = VOXEL * 0.5
const CONST_INF: int = 999

const ROAD_GRID: float = 80.0
const ROAD_OFFSET: float = 22.0
const ROAD_HALF_W: float = 1.5
const ROAD_GRID_R: int = 40

const _Dim = preload("res://scripts/world/dimension_defs.gd")

const TILE_COLORS_TW: Array[Dictionary] = [
	{ "base": Color(0.06, 0.22, 0.16), "emit": Color(0.08, 0.28, 0.20), "pow": 0.3 },
	{ "base": Color(0.03, 0.12, 0.08), "emit": Color(0.05, 0.16, 0.10), "pow": 0.2 },
	{ "base": Color(0.05, 0.15, 0.10), "emit": Color(0.06, 0.18, 0.12), "pow": 0.2 },
	{ "base": Color(0.04, 0.10, 0.07), "emit": Color(0.05, 0.12, 0.08), "pow": 0.15 },
	{ "base": Color(0.06, 0.14, 0.08), "emit": Color(0.07, 0.16, 0.09), "pow": 0.15 },
]

const TILE_COLORS_RW: Array[Dictionary] = [
	{ "base": Color(0.28, 0.48, 0.18), "emit": Color(0.0, 0.0, 0.0), "pow": 0.0 },
	{ "base": Color(0.20, 0.35, 0.12), "emit": Color(0.0, 0.0, 0.0), "pow": 0.0 },
	{ "base": Color(0.90, 0.80, 0.42), "emit": Color(0.0, 0.0, 0.0), "pow": 0.0 },
	{ "base": Color(0.32, 0.18, 0.08), "emit": Color(0.0, 0.0, 0.0), "pow": 0.0 },
	{ "base": Color(0.14, 0.14, 0.13), "emit": Color(0.0, 0.0, 0.0), "pow": 0.0 },
]
