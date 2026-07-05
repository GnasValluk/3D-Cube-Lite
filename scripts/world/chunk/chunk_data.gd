extends RefCounted

enum TileType { GRASS, DARK_GRASS, SAND, DIRT, SILT, OCEAN_SHALLOW, OCEAN_DEEP }

## ── Block IDs cho hệ thống voxel Minecraft-style ────────────────────────────
## 0 = AIR luôn luôn, giá trị khớp với TileType để map dễ dàng
enum BlockID {
	AIR         = 0,
	GRASS       = 1,
	DARK_GRASS  = 2,
	SAND        = 3,
	DIRT        = 4,
	SILT        = 5,
	WATER       = 6,
	STONE       = 7,
	DARK_DIRT   = 8,
	SAND_DEEP   = 9,
	BEDROCK     = 10,
	TRAIL       = 11,
	OCEAN_FLOOR = 12,  # Đáy biển — cát thô màu xám xanh
	OCEAN_SAND  = 13,  # Cát bãi biển — sáng hơn SAND nội địa
}

const VOXEL: float = 1.0
const TILE_W: int = 5
const TILE_D: int = 5

const ROAD_COLOR: Color = Color(0.45, 0.45, 0.45)
const ROAD_SIDE: Color = Color(0.30, 0.30, 0.30)
const TRAIL_COLOR: Color = Color(0.68, 0.52, 0.26)
const TRAIL_SIDE: Color = Color(0.46, 0.36, 0.18)

## ── Hằng số biển ──────────────────────────────────────────────────────────────
## Continent noise tần số rất thấp — 1 "lục địa" rộng ~800-1200 world units
const CONTINENT_FREQ:      float = 0.0008
const CONTINENT_THRESHOLD: float = 0.38   # < threshold = biển, >= = đất liền
## Bề rộng bãi biển (voxels) — transition SAND trước khi vào nước biển
const BEACH_WIDTH:         int   = 5
## Độ sâu biển nông (OCEAN_SHALLOW) và sâu (OCEAN_DEEP) tính theo slab layers
const OCEAN_SHALLOW_DEPTH: float = -1.0   # world Y = -1.0 (dưới WATER_Y)
const OCEAN_DEEP_DEPTH:    float = -3.0   # world Y = -3.0 (đáy)

const PAD: int = 5
const WATER_Y: float = VOXEL * 0.5
const CONST_INF: int = 999

const ROAD_GRID: float = 80.0
const ROAD_OFFSET: float = 22.0
const ROAD_HALF_W: float = 1.5
const ROAD_GRID_R: int = 40

const _Dim = preload("res://scripts/world/dimension_defs.gd")

## ── Màu sắc theo block ID ────────────────────────────────────────────────────
## Index = BlockID value — màu đậm, bão hòa cao cho unshaded renderer
const BLOCK_COLORS_RW: Array[Color] = [
	Color(0, 0, 0, 0),                 # 0 AIR
	Color(0.22, 0.58, 0.14),           # 1 GRASS
	Color(0.14, 0.40, 0.08),           # 2 DARK_GRASS
	Color(0.92, 0.78, 0.32),           # 3 SAND (hồ nội địa)
	Color(0.42, 0.22, 0.08),           # 4 DIRT
	Color(0.16, 0.15, 0.13),           # 5 SILT
	Color(0.08, 0.36, 0.68, 0.70),     # 6 WATER (hồ)
	Color(0.42, 0.42, 0.46),           # 7 STONE
	Color(0.28, 0.16, 0.06),           # 8 DARK_DIRT
	Color(0.80, 0.66, 0.28),           # 9 SAND_DEEP
	Color(0.14, 0.12, 0.14),           # 10 BEDROCK
	Color(0.76, 0.58, 0.22),           # 11 TRAIL
	Color(0.22, 0.28, 0.32),           # 12 OCEAN_FLOOR — cát thô xám xanh đáy biển
	Color(0.94, 0.88, 0.62),           # 13 OCEAN_SAND  — cát bãi biển sáng vàng nhạt
]

const BLOCK_COLORS_TW: Array[Color] = [
	Color(0, 0, 0, 0),                 # 0 AIR
	Color(0.06, 0.22, 0.16),           # 1 GRASS
	Color(0.03, 0.12, 0.08),           # 2 DARK_GRASS
	Color(0.05, 0.15, 0.10),           # 3 SAND
	Color(0.04, 0.10, 0.07),           # 4 DIRT
	Color(0.06, 0.14, 0.08),           # 5 SILT
	Color(0.10, 0.55, 0.45, 0.70),     # 6 WATER
	Color(0.04, 0.08, 0.06),           # 7 STONE
	Color(0.03, 0.10, 0.06),           # 8 DARK_DIRT
	Color(0.05, 0.13, 0.08),           # 9 SAND_DEEP
	Color(0.06, 0.05, 0.07),           # 10 BEDROCK
	Color(0.08, 0.10, 0.05),           # 11 TRAIL
	Color(0.04, 0.08, 0.10),           # 12 OCEAN_FLOOR (TW không có nhưng cần tránh crash)
	Color(0.06, 0.10, 0.08),           # 13 OCEAN_SAND
]

## TRAIL_SINK bỏ — không dùng nữa để tránh void
## TRAIL phân biệt với terrain bằng màu, không bằng height
const TRAIL_SINK: float = 0.0

## Side màu tối hơn top — unshaded cần chênh lệch rõ để tạo cảm giác 3D
static func block_side_color(top_col: Color) -> Color:
	return Color(top_col.r * 0.50, top_col.g * 0.50, top_col.b * 0.50, top_col.a)

## Block nào là solid (player không đi xuyên qua)
static func is_solid(block_id: int) -> bool:
	return block_id != BlockID.AIR and block_id != BlockID.WATER

## Block nào là indestructible (không thể phá vỡ)
static func is_indestructible(block_id: int) -> bool:
	return block_id == BlockID.BEDROCK

## Block nào là transparent (render both sides / skip face culling)
static func is_transparent(block_id: int) -> bool:
	return block_id == BlockID.AIR or block_id == BlockID.WATER

## ── Legacy tile colors (giữ lại để tương thích các code cũ) ─────────────────
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
