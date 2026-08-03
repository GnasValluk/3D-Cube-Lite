extends RefCounted

enum TileType { GRASS, DARK_GRASS, SAND, DIRT, SILT, OCEAN_SHALLOW, OCEAN_DEEP, SAND_WHITE, MUDDY_SAND, DESERT, YOUNG_GRASS }

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
	MUDDY_SAND  = 14,  # Cát bùn hồ — pha trộn giữa SAND và SILT
	OCEAN_GRAVEL = 15, # Sỏi biển — nâu xám, đáy gần bờ
	OCEAN_MUD    = 16, # Bùn biển sâu — xanh xám đậm, đồng bằng sâu
	COPPER_ORE   = 17,
	BAUXITE_ORE  = 18,
	SILVER_ORE   = 19,
	IRON_ORE     = 20,
	GOLD_ORE     = 21,
	TITAN_ORE    = 22,
	PLATINUM_ORE = 23,
	WATER_SOURCE = 24,
	WATER_LEVEL_7 = 25,
	WATER_LEVEL_6 = 26,
	WATER_LEVEL_5 = 27,
	WATER_LEVEL_4 = 28,
	WATER_LEVEL_3 = 29,
	WATER_LEVEL_2 = 30,
	WATER_LEVEL_1 = 31,
	TILLED_SOIL  = 32,  # Đất tơi xốp — cuốc lên từ GRASS/DIRT; ẩm nếu có nước gần (≤3 block)
	COAL_ORE     = 33,  # Quặng than — đào ra Than đá (không phải block item)
	STONE_QTR    = 34,  # Đá tư — ¼ khối đá (0.5×0.5×0.5), không tính vào địa hình
	STONE_EIGHTH = 35,  # Đá vụn — ⅛ khối đá (0.5×0.25×0.5)
	STONE_THIN   = 36,  # Đá phiến — mỏng (1×0.2×1) thay vì slab 0.5
	OAK_WOOD     = 37,  # Gỗ sồi — texture vân gỗ riêng, chặt từ cây sồi cổ thụ
	YOUNG_GRASS  = 38,  # Cỏ non — bãi đất pha cỏ mới mọc, đám rải rác trên đồng bằng
}

## ── BlockID ↔ item_id mapping ──────────────────────────────────────────
const BLOCK_TO_ITEM: Dictionary = {
	BlockID.GRASS:       "block_grass",
	BlockID.DARK_GRASS:  "block_dark_grass",
	BlockID.SAND:        "block_sand",
	BlockID.DIRT:        "block_dirt",
	BlockID.SILT:        "block_silt",
	BlockID.STONE:       "block_stone",
	BlockID.DARK_DIRT:   "block_dark_dirt",
	BlockID.SAND_DEEP:   "block_sand_deep",
	BlockID.TRAIL:       "block_trail",
	BlockID.OCEAN_FLOOR: "block_ocean_floor",
	BlockID.OCEAN_SAND:  "block_ocean_sand",
	BlockID.MUDDY_SAND:  "block_muddy_sand",
	BlockID.OCEAN_GRAVEL:"block_ocean_gravel",
	BlockID.OCEAN_MUD:   "block_ocean_mud",
	BlockID.COPPER_ORE:   "copper_ore",
	BlockID.BAUXITE_ORE:  "bauxite_ore",
	BlockID.SILVER_ORE:   "silver_ore",
	BlockID.IRON_ORE:     "iron_ore",
	BlockID.GOLD_ORE:     "gold_ore",
	BlockID.TITAN_ORE:    "titan_ore",
	BlockID.PLATINUM_ORE: "platinum_ore",
	BlockID.TILLED_SOIL:  "block_tilled_soil",
	BlockID.COAL_ORE:     "coal",       # Đào quặng than → rớt Than đá
	BlockID.STONE_QTR:    "block_stone_qtr",
	BlockID.STONE_EIGHTH: "block_stone_eighth",
	BlockID.STONE_THIN:   "block_stone_thin",
	BlockID.OAK_WOOD:     "block_oak_wood",
	BlockID.YOUNG_GRASS:  "block_young_grass",
}

## ── item_id → BlockID mapping (dùng khi place block) ────────────────────
const ITEM_TO_BLOCK: Dictionary = {
	"block_grass":        BlockID.GRASS,
	"block_dark_grass":   BlockID.DARK_GRASS,
	"block_sand":         BlockID.SAND,
	"block_dirt":         BlockID.DIRT,
	"block_silt":         BlockID.SILT,
	"block_stone":        BlockID.STONE,
	"block_dark_dirt":    BlockID.DARK_DIRT,
	"block_sand_deep":    BlockID.SAND_DEEP,
	"block_trail":        BlockID.TRAIL,
	"block_ocean_floor":  BlockID.OCEAN_FLOOR,
	"block_ocean_sand":   BlockID.OCEAN_SAND,
	"block_muddy_sand":   BlockID.MUDDY_SAND,
	"block_ocean_gravel": BlockID.OCEAN_GRAVEL,
	"block_ocean_mud":    BlockID.OCEAN_MUD,
	"copper_ore":         BlockID.COPPER_ORE,
	"bauxite_ore":        BlockID.BAUXITE_ORE,
	"silver_ore":         BlockID.SILVER_ORE,
	"iron_ore":           BlockID.IRON_ORE,
	"gold_ore":           BlockID.GOLD_ORE,
	"titan_ore":          BlockID.TITAN_ORE,
	"platinum_ore":       BlockID.PLATINUM_ORE,
	"block_tilled_soil":  BlockID.TILLED_SOIL,
	"coal_ore":           BlockID.COAL_ORE,
	"water_bucket":       BlockID.WATER_SOURCE,
	"block_stone_qtr":    BlockID.STONE_QTR,
	"block_stone_eighth": BlockID.STONE_EIGHTH,
	"block_stone_thin":   BlockID.STONE_THIN,
	"block_oak_wood":     BlockID.OAK_WOOD,
	"block_young_grass":  BlockID.YOUNG_GRASS,
}

const VOXEL: float = 1.0
const TILE_W: int = 5
const TILE_D: int = 5

const ROAD_COLOR: Color = Color(0.45, 0.45, 0.45)
const ROAD_SIDE: Color = Color(0.30, 0.30, 0.30)
const TRAIL_COLOR: Color = Color(0.68, 0.52, 0.26)
const TRAIL_SIDE: Color = Color(0.46, 0.36, 0.18)

## ── Hằng số biển ──────────────────────────────────────────────────────────────
const OCEAN_THRESHOLD:     float = 0.48
const BEACH_WIDTH:         int   = 5
const OCEAN_SHALLOW_DEPTH: float = -1.5
const OCEAN_DEEP_DEPTH:    float = -6.0

const PAD: int = 5
const WATER_Y: float = VOXEL * 0.5
const CONST_INF: int = 999

const ROAD_GRID: float = 80.0
const ROAD_OFFSET: float = 22.0
const ROAD_HALF_W: float = 1.5
const ROAD_GRID_R: int = 40

const RIVER_GRID: float = 220.0
const RIVER_OFFSET: float = 50.0
const RIVER_HALF_W: float = 3.0
const RIVER_GRID_R: int = 40

const _Dim = preload("res://scripts/world/dimension_defs.gd")

## ── Màu sắc theo block ID ────────────────────────────────────────────────────
## Index = BlockID value — màu đậm, bão hòa cao cho unshaded renderer
const BLOCK_COLORS_RW: Array[Color] = [
	Color(0, 0, 0, 0),                 # 0 AIR
	Color(0.18, 0.64, 0.12),           # 1 GRASS
	Color(0.11, 0.46, 0.07),           # 2 DARK_GRASS
	Color(0.92, 0.78, 0.32),           # 3 SAND (hồ nội địa)
	Color(0.42, 0.22, 0.08),           # 4 DIRT
	Color(0.16, 0.15, 0.13),           # 5 SILT
	Color(0.08, 0.36, 0.68, 0.70),     # 6 WATER (backward compat)
	Color(0.42, 0.42, 0.46),           # 7 STONE
	Color(0.28, 0.16, 0.06),           # 8 DARK_DIRT
	Color(0.80, 0.66, 0.28),           # 9 SAND_DEEP
	Color(0.14, 0.12, 0.14),           # 10 BEDROCK
	Color(0.76, 0.58, 0.22),           # 11 TRAIL
	Color(0.22, 0.28, 0.32),           # 12 OCEAN_FLOOR — cát thô xám xanh đáy biển
	Color(0.86, 0.78, 0.52),           # 13 OCEAN_SAND  — cát bãi biển sáng vừa
	Color(0.54, 0.46, 0.22),           # 14 MUDDY_SAND — cát bùn pha trộn
	Color(0.35, 0.30, 0.25),           # 15 OCEAN_GRAVEL — sỏi biển nâu xám
	Color(0.16, 0.20, 0.22),           # 16 OCEAN_MUD — bùn biển sâu xanh xám
	Color(0.38, 0.29, 0.18),           # 17 COPPER_ORE
	Color(0.55, 0.35, 0.25),           # 18 BAUXITE_ORE
	Color(0.35, 0.35, 0.38),           # 19 SILVER_ORE
	Color(0.36, 0.31, 0.26),           # 20 IRON_ORE
	Color(0.37, 0.33, 0.29),           # 21 GOLD_ORE
	Color(0.35, 0.30, 0.40),           # 22 TITAN_ORE
	Color(0.30, 0.30, 0.35),           # 23 PLATINUM_ORE
	Color(0.08, 0.36, 0.68, 0.75),     # 24 WATER_SOURCE
	Color(0.08, 0.36, 0.68, 0.70),     # 25 WATER_LEVEL_7
	Color(0.10, 0.40, 0.70, 0.65),     # 26 WATER_LEVEL_6
	Color(0.12, 0.44, 0.72, 0.60),     # 27 WATER_LEVEL_5
	Color(0.14, 0.48, 0.74, 0.55),     # 28 WATER_LEVEL_4
	Color(0.16, 0.52, 0.76, 0.50),     # 29 WATER_LEVEL_3
	Color(0.18, 0.56, 0.78, 0.45),     # 30 WATER_LEVEL_2
	Color(0.20, 0.60, 0.80, 0.40),     # 31 WATER_LEVEL_1
	Color(0.36, 0.22, 0.11),           # 32 TILLED_SOIL — đất tơi xốp (nâu đất, hơi sẫm hơn DIRT)
	Color(0.28, 0.28, 0.30),           # 33 COAL_ORE
	Color(0.42, 0.42, 0.46),           # 34 STONE_QTR — đá tư
	Color(0.44, 0.44, 0.48),           # 35 STONE_EIGHTH — đá vụn
	Color(0.40, 0.40, 0.44),           # 36 STONE_THIN — đá phiến mỏng
	Color(0.54, 0.46, 0.38),           # 37 OAK_WOOD — gỗ sồi (nâu xám)
	Color(0.44, 0.38, 0.13),           # 38 YOUNG_GRASS — bãi cỏ non (đất pha cỏ vàng xanh)
]

const BLOCK_COLORS_TW: Array[Color] = [
	Color(0, 0, 0, 0),                 # 0 AIR
	Color(0.06, 0.22, 0.16),           # 1 GRASS
	Color(0.03, 0.12, 0.08),           # 2 DARK_GRASS
	Color(0.05, 0.15, 0.10),           # 3 SAND
	Color(0.04, 0.10, 0.07),           # 4 DIRT
	Color(0.06, 0.14, 0.08),           # 5 SILT
	Color(0.10, 0.55, 0.45, 0.70),     # 6 WATER (backward compat)
	Color(0.04, 0.08, 0.06),           # 7 STONE
	Color(0.03, 0.10, 0.06),           # 8 DARK_DIRT
	Color(0.05, 0.13, 0.08),           # 9 SAND_DEEP
	Color(0.06, 0.05, 0.07),           # 10 BEDROCK
	Color(0.08, 0.10, 0.05),           # 11 TRAIL
	Color(0.04, 0.08, 0.10),           # 12 OCEAN_FLOOR (TW không có nhưng cần tránh crash)
	Color(0.06, 0.10, 0.08),           # 13 OCEAN_SAND
	Color(0.08, 0.10, 0.06),           # 14 MUDDY_SAND
	Color(0.08, 0.10, 0.06),           # 15 OCEAN_GRAVEL
	Color(0.04, 0.08, 0.10),           # 16 OCEAN_MUD
	Color(0.38, 0.29, 0.18),           # 17 COPPER_ORE
	Color(0.55, 0.35, 0.25),           # 18 BAUXITE_ORE
	Color(0.35, 0.35, 0.38),           # 19 SILVER_ORE
	Color(0.36, 0.31, 0.26),           # 20 IRON_ORE
	Color(0.37, 0.33, 0.29),           # 21 GOLD_ORE
	Color(0.35, 0.30, 0.40),           # 22 TITAN_ORE
	Color(0.30, 0.30, 0.35),           # 23 PLATINUM_ORE
	Color(0.10, 0.55, 0.45, 0.75),     # 24 WATER_SOURCE
	Color(0.10, 0.55, 0.45, 0.70),     # 25 WATER_LEVEL_7
	Color(0.12, 0.57, 0.47, 0.65),     # 26 WATER_LEVEL_6
	Color(0.14, 0.59, 0.49, 0.60),     # 27 WATER_LEVEL_5
	Color(0.16, 0.61, 0.51, 0.55),     # 28 WATER_LEVEL_4
	Color(0.18, 0.63, 0.53, 0.50),     # 29 WATER_LEVEL_3
	Color(0.20, 0.65, 0.55, 0.45),     # 30 WATER_LEVEL_2
	Color(0.22, 0.67, 0.57, 0.40),     # 31 WATER_LEVEL_1
	Color(0.05, 0.07, 0.04),           # 32 TILLED_SOIL
	Color(0.28, 0.28, 0.30),           # 33 COAL_ORE
	Color(0.04, 0.08, 0.06),           # 34 STONE_QTR
	Color(0.04, 0.09, 0.07),           # 35 STONE_EIGHTH
	Color(0.04, 0.07, 0.05),           # 36 STONE_THIN
	Color(0.07, 0.10, 0.08),           # 37 OAK_WOOD
	Color(0.06, 0.09, 0.05),           # 38 YOUNG_GRASS
]

## TRAIL_SINK bỏ — không dùng nữa để tránh void
## TRAIL phân biệt với terrain bằng màu, không bằng height
const TRAIL_SINK: float = 0.0

## Side màu tối hơn top — unshaded cần chênh lệch rõ để tạo cảm giác 3D
static func block_side_color(top_col: Color) -> Color:
	return Color(top_col.r * 0.50, top_col.g * 0.50, top_col.b * 0.50, top_col.a)

## ── Block có hình dạng riêng (không phải voxel đầy) ─────────────────────────
## Kích thước hộp tính theo đơn vị block (slab chuẩn = 1×0.5×1).
## Block shape KHÔNG tham gia heightmap/top_ly — luôn vẽ đè lên terrain.
const BLOCK_SHAPES: Dictionary = {
	BlockID.STONE_QTR:    Vector3(0.5, 0.5, 0.5),   # ¼ khối đá
	BlockID.STONE_EIGHTH: Vector3(0.5, 0.25, 0.5),  # ⅛ khối đá
	BlockID.STONE_THIN:   Vector3(1.0, 0.2, 1.0),   # tấm mỏng 0.2
}

static func is_shaped_block(bid: int) -> bool:
	return BLOCK_SHAPES.has(bid)

## Kích thước hộp của block (Vector3.ZERO nếu là voxel đầy).
static func block_shape(bid: int) -> Vector3:
	return BLOCK_SHAPES.get(bid, Vector3.ZERO)

## Water helpers
static func is_water(bid: int) -> bool:
	return bid == BlockID.WATER \
		or (bid >= BlockID.WATER_SOURCE and bid <= BlockID.WATER_LEVEL_1)

static func water_level(bid: int) -> int:
	if bid == BlockID.WATER_SOURCE or bid == BlockID.WATER:
		return 8
	if bid >= BlockID.WATER_LEVEL_7 and bid <= BlockID.WATER_LEVEL_1:
		return 8 - (bid - BlockID.WATER_LEVEL_7)
	return 0

static func is_source_water(bid: int) -> bool:
	return bid == BlockID.WATER_SOURCE or bid == BlockID.WATER

static func water_block_for_level(level: int) -> int:
	if level >= 8:
		return BlockID.WATER_SOURCE
	if level >= 1:
		return BlockID.WATER_LEVEL_7 - (level - 7)
	return BlockID.AIR

## Block nào là solid (player không đi xuyên qua)
static func is_solid(block_id: int) -> bool:
	return block_id != BlockID.AIR and not is_water(block_id)

## Block nào là indestructible (không thể phá vỡ)
static func is_indestructible(block_id: int) -> bool:
	return block_id == BlockID.BEDROCK

## Block nào là transparent (render both sides / skip face culling)
static func is_transparent(block_id: int) -> bool:
	return block_id == BlockID.AIR or is_water(block_id)

## ── Đất tơi xốp ─────────────────────────────────────────────────────────────
## Bán kính nước (block) làm đất tơi xốp chuyển sang trạng thái ẩm.
const SOIL_RADIUS: int = 3

static func is_soil(bid: int) -> bool:
	return bid == BlockID.TILLED_SOIL

## Block nào cuốc được thành đất tơi xốp.
static func is_tillable(bid: int) -> bool:
	return bid == BlockID.GRASS or bid == BlockID.DARK_GRASS \
		or bid == BlockID.DIRT or bid == BlockID.DARK_DIRT \
		or bid == BlockID.YOUNG_GRASS

## ── Độ cứng block (giây đào với công cụ sắt đúng loại) ─────────────────────
## -1 = không thể phá vỡ. Không có trong bảng (0) = không đào được.
## Công cụ đúng loại: cúp (pickaxe) cho đá/quặng, xẻng (shovel) cho đất/cát.
const BLOCK_HARDNESS: Dictionary = {
	# Xẻng — đất & cát
	BlockID.GRASS:        1.2,
	BlockID.DARK_GRASS:   1.2,
	BlockID.DIRT:         1.2,
	BlockID.DARK_DIRT:    1.2,
	BlockID.TILLED_SOIL:  0.8,
	BlockID.COAL_ORE:     1.5,
	BlockID.SAND:         1.2,
	BlockID.SAND_DEEP:    1.2,
	BlockID.OCEAN_SAND:   1.0,
	BlockID.MUDDY_SAND:   1.1,
	BlockID.OCEAN_GRAVEL: 1.3,
	BlockID.OCEAN_MUD:    1.1,
	BlockID.SILT:         1.0,
	BlockID.TRAIL:        1.2,
	BlockID.OCEAN_FLOOR:  1.2,
	# Cúp — đá & quặng (theo độ cứng thực tế: quặng kim loại cứng hơn đá nền)
	BlockID.STONE:        1.2,
	BlockID.STONE_QTR:    1.2,
	BlockID.STONE_EIGHTH: 1.2,
	BlockID.STONE_THIN:   1.2,
	BlockID.BAUXITE_ORE:  1.3,
	BlockID.COPPER_ORE:   1.6,
	BlockID.GOLD_ORE:     1.7,
	BlockID.SILVER_ORE:   1.8,
	BlockID.IRON_ORE:     2.4,
	BlockID.PLATINUM_ORE: 3.0,
	BlockID.TITAN_ORE:    3.6,
	# Rìu — gỗ
	BlockID.OAK_WOOD:     1.4,
	# Cỏ non — như cỏ thường
	BlockID.YOUNG_GRASS:  1.2,
	# Không thể phá
	BlockID.BEDROCK:      -1.0,
}

## Thời gian đào block (giây, công cụ sắt đúng loại). 0 = không đào được; <0 = vĩnh cửu.
static func get_block_hardness(bid: int) -> float:
	return BLOCK_HARDNESS.get(bid, 0.0)

## Block nào cúp (pickaxe) đào được — đá và quặng.
static func is_pickaxable(bid: int) -> bool:
	return bid == BlockID.STONE \
		or bid == BlockID.STONE_QTR or bid == BlockID.STONE_EIGHTH or bid == BlockID.STONE_THIN \
		or (bid >= BlockID.COPPER_ORE and bid <= BlockID.PLATINUM_ORE) \
		or bid == BlockID.COAL_ORE

## Block nào xẻng (shovel) đào được — đất, cát, bùn...
static func is_shovelable(bid: int) -> bool:
	return bid == BlockID.GRASS or bid == BlockID.DARK_GRASS or bid == BlockID.DIRT \
		or bid == BlockID.DARK_DIRT or bid == BlockID.TILLED_SOIL \
		or bid == BlockID.YOUNG_GRASS \
		or bid == BlockID.SAND or bid == BlockID.SAND_DEEP or bid == BlockID.OCEAN_SAND \
		or bid == BlockID.MUDDY_SAND or bid == BlockID.OCEAN_GRAVEL or bid == BlockID.OCEAN_MUD \
		or bid == BlockID.SILT or bid == BlockID.TRAIL or bid == BlockID.OCEAN_FLOOR

## Block nào rìu (axe) đào được — gỗ.
static func is_axable(bid: int) -> bool:
	return bid == BlockID.OAK_WOOD

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
