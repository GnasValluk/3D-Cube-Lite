extends RefCounted

enum TileType { GRASS, DARK_GRASS, SAND, DIRT, SILT, OCEAN_SHALLOW, OCEAN_DEEP, SAND_WHITE, MUDDY_SAND, DESERT, YOUNG_GRASS, GRASS_DIRT, SAND_DEEP, TWILIGHT_GRASS, TWILIGHT_DIRT, DRY_GRASS, SPARSE_GRASS, PALE_SAND, STONE_PATCH, MANGROVE_MUD, FROST, FROST_SNOW, SWAMP, SWAMP_MUD, SWAMP_DIRT }

## Tile "đồng cỏ" hợp nhất: đều mọc cỏ/được props/được coi là cỏ nền.
## (Đồ BẰNG = GRASS_DIRT/GRASS/DARK_GRASS/YOUNG_GRASS — nhiều loại khối cỏ.
##  DRY_GRASS/SPARSE_GRASS KHÔNG nằm ở đây: là đốm khô/thưa — cố tình để trống
##  không mọc cỏ blade xanh lòe lên trên, tạo điểm nhấn đa dạng.)
static func is_grass_tile(t: int) -> bool:
	return t == TileType.GRASS or t == TileType.DARK_GRASS \
		or t == TileType.YOUNG_GRASS or t == TileType.GRASS_DIRT

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
	HARD_WOOD    = 39,  # Gỗ cứng — vân gỗ nâu sẫm, chặt từ cây rừng rậm
	GRASS_DIRT = 40,  # Cỏ đồng bằng cỏ (đã hợp nhất cỏ thường + cao nguyên) — đất hỗn cỏ, địa hình đồi thoải chung cho mọi biome
	DESERT_PLATEAU = 41,  # Cát cao nguyên sa mạc — sa mạc nâng cao, địa hình gồ ghề (mesa)
	TWILIGHT_GRASS = 42,  # Cỏ Twilight — bề mặt thế giới Twilight (thay GRASS ở dim TW)
	TWILIGHT_DIRT = 43,  # Đất Twilight — đất nền bên dưới cỏ Twilight
	DRY_GRASS = 44,   # Cỏ già/khô — đốm vàng rạ trên đồng bằng (lẫn GRASS thường)
	SPARSE_GRASS = 45,  # Cỏ thưa — cỏ lẫn đất, đốm thưa giữa dải GRASS_DIRT
	PALE_SAND = 46,   # Cát phai — đốm cát nhạt hơn DESERT (đồi mòn / cồn già)
	MANGROVE_MUD = 47,  # Bùn ngập mặn — bùn đen đầm lầy vùng triều, nền rừng đước
	MANGROVE_WOOD = 48, # Gỗ đước — vân gỗ nâu đỏ, chặt từ cây đước rừng ngập mặn
	SNOW = 49,          # Tuyết — bề mặt bio băng giá (mặt trên tuyết trắng, hông tuyết/đất đóng băng)
	FROST_DIRT = 50,    # Đất đóng băng — lớp nền bên dưới tuyết bio băng giá
	SPRUCE_WOOD = 51,   # Gỗ vân sam — chặt từ cây vân sam (thông) bio băng giá
	LAVA_SOURCE = 52,   # Núi lửa — dung nham nguồn (level 8)
	LAVA_LEVEL_7 = 53,
	LAVA_LEVEL_6 = 54,
	LAVA_LEVEL_5 = 55,
	LAVA_LEVEL_4 = 56,
	LAVA_LEVEL_3 = 57,
	LAVA_LEVEL_2 = 58,
	LAVA_LEVEL_1 = 59,
	SWAMP_MUD = 60,    # Bùn đầm lầy — nền rừng đầm lầy ẩm thấp, xẻng đào được
	SWAMP_DIRT = 61,   # Đất đầm lầy — lớp nền bên dưới bùn đầm lầy
	SWAMP_WOOD = 62,   # Gỗ tràm — vân gỗ nâu xám, chặt từ cây tràm rừng đầm lầy
	STONE_PLATFORM = 63, # Nền đá platform — mỗi ô đầy block (1×0.5×1), đặt 3×3 tạo sàn
	STONE_WALL_Z   = 64, # Tường đá dày theo Z (1×0.5×0.5) — tường 3×3 dài theo X
	STONE_WALL_X   = 65, # Tường đá dày theo X (0.5×0.5×1) — tường 3×3 dài theo Z
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
	BlockID.HARD_WOOD:    "block_hard_wood",
	BlockID.GRASS_DIRT: "block_grass_dirt",
	BlockID.DESERT_PLATEAU: "block_desert_plateau",
	BlockID.TWILIGHT_GRASS: "block_twilight_grass",
	BlockID.TWILIGHT_DIRT: "block_twilight_dirt",
	BlockID.DRY_GRASS: "block_dry_grass",
	BlockID.SPARSE_GRASS: "block_sparse_grass",
	BlockID.PALE_SAND: "block_pale_sand",
	BlockID.MANGROVE_MUD: "block_mangrove_mud",
	BlockID.MANGROVE_WOOD: "mangrove_wood",
	BlockID.SNOW: "block_snow",
	BlockID.FROST_DIRT: "block_frost_dirt",
	BlockID.SPRUCE_WOOD: "spruce_wood",
	BlockID.LAVA_SOURCE: "lava_bucket",
	BlockID.LAVA_LEVEL_7: "lava_bucket",
	BlockID.LAVA_LEVEL_6: "lava_bucket",
	BlockID.LAVA_LEVEL_5: "lava_bucket",
	BlockID.LAVA_LEVEL_4: "lava_bucket",
	BlockID.LAVA_LEVEL_3: "lava_bucket",
	BlockID.LAVA_LEVEL_2: "lava_bucket",
	BlockID.LAVA_LEVEL_1: "lava_bucket",
	BlockID.SWAMP_MUD: "block_swamp_mud",
	BlockID.SWAMP_DIRT: "block_swamp_dirt",
	BlockID.SWAMP_WOOD: "swamp_wood",
	BlockID.STONE_PLATFORM: "block_stone_platform",
	BlockID.STONE_WALL_Z:    "block_stone_wall",
	BlockID.STONE_WALL_X:    "block_stone_wall",
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
	"block_hard_wood":    BlockID.HARD_WOOD,
	"block_grass_dirt": BlockID.GRASS_DIRT,
	"block_desert_plateau": BlockID.DESERT_PLATEAU,
	"block_twilight_grass": BlockID.TWILIGHT_GRASS,
	"block_twilight_dirt": BlockID.TWILIGHT_DIRT,
	"block_dry_grass": BlockID.DRY_GRASS,
	"block_sparse_grass": BlockID.SPARSE_GRASS,
	"block_pale_sand": BlockID.PALE_SAND,
	"block_mangrove_mud": BlockID.MANGROVE_MUD,
	"mangrove_wood": BlockID.MANGROVE_WOOD,
	"block_snow": BlockID.SNOW,
	"block_frost_dirt": BlockID.FROST_DIRT,
	"spruce_wood": BlockID.SPRUCE_WOOD,
	"lava_bucket": BlockID.LAVA_SOURCE,
	"block_swamp_mud": BlockID.SWAMP_MUD,
	"block_swamp_dirt": BlockID.SWAMP_DIRT,
	"swamp_wood": BlockID.SWAMP_WOOD,
	"block_stone_platform":    BlockID.STONE_PLATFORM,
	"block_stone_wall":        BlockID.STONE_WALL_Z,   # mặc định: tường dài theo X (dày Z)
	"block_stone_wall_door":   BlockID.STONE_WALL_Z,
	"block_stone_wall_window": BlockID.STONE_WALL_Z,
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
const ROAD_HALF_W: float = 2.0
const ROAD_GRID_R: int = 40

const RIVER_GRID: float = 220.0
const RIVER_OFFSET: float = 50.0
const RIVER_HALF_W: float = 3.0
const RIVER_GRID_R: int = 40

## ── Lưới ĐẢO — 1 ô = 1 đảo. Mỗi đảo là 1 blob quanh hub (tâm ô + nhiễu), bán
## kính luôn < 0.5*CELL nên các đảo KHÔNG BAO GIỜ chạm nhau → quần đảo nhỏ dày.
## Ocean mask (world_chunk) và biome (chunk_noise) dùng CHUNG lưới này để "1 đảo
## = 1 biome" nhất quán qua mọi pipeline (chunk/tile/LOD/hud/explore/teleport).
const ISLAND_CELL: float = 340.0

## Hash tất định (0..1) theo ô đảo + seed — jitter hàng/fixture không cần noise.
static func _h01(seed: int, x: int, y: int) -> float:
	var h: int = x * 374761393 + y * 668265263 + seed * 1442695040
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0x7fffffff) / 2147483647.0

## Tâm đảo (nhiễu FULL ô — hub có thể nằm sát mép ô, đủ để các đường lưới
## chính (x=k*CELL, z=k*CELL) của ray test luôn cắt được blob): các hàm dùng
## chung phải cho CÙNG kết quả.
static func island_hub(cx: int, cz: int, seed: int) -> Vector2:
	var hx: float = (cx + 0.5) * ISLAND_CELL
	var hz: float = (cz + 0.5) * ISLAND_CELL
	var jx: float = (_h01(seed, cx * 2 + 1, cz * 2 + 1) - 0.5) * ISLAND_CELL
	var jz: float = (_h01(seed, cx * 2 + 2, cz * 2 + 2) - 0.5) * ISLAND_CELL
	return Vector2(hx + jx, hz + jz)

## Bán kính đảo theo 2 trục (elip) — max gần < 0.5*CELL nên đảo các ô hiếm khi
## dính nhau; bán kính trung bình ~0.29*CELL → đất ~25-30% (biển chiếm đa số).
static func island_axes(cx: int, cz: int, seed: int) -> Vector2:
	var rn: float = _h01(seed, cx * 3 + 1, cz * 3 + 1)
	var radius: float = ISLAND_CELL * (0.22 + rn * 0.14)
	var shape: float = (_h01(seed, cx * 3 + 2, cz * 3 + 2) - 0.5)
	var rx: float = radius * (1.0 + shape * 0.6)
	var rz: float = radius * (1.0 - shape * 0.6)
	return Vector2(rx, rz)

## ── Đảo nhỏ (islet) — rải rác đầy biển để bất kỳ hướng đi nào cũng gặp đất
## trong tầm ngắn (dân cư nouvelle ở giữa các đảo lớn). Không phải biome riêng.
const ISLET_CELL: float = 150.0
static func islet_hub(cx: int, cz: int, seed: int) -> Vector2:
	var hx: float = (cx + 0.5) * ISLET_CELL
	var hz: float = (cz + 0.5) * ISLET_CELL
	var jx: float = (_h01(seed, cx * 5 + 1, cz * 5 + 1) - 0.5) * ISLET_CELL
	var jz: float = (_h01(seed, cx * 5 + 2, cz * 5 + 2) - 0.5) * ISLET_CELL
	return Vector2(hx + jx, hz + jz)
static func islet_present(cx: int, cz: int, seed: int) -> bool:
	return _h01(seed, cx * 5 + 3, cz * 5 + 3) < 0.35
static func islet_radius(cx: int, cz: int, seed: int) -> float:
	return ISLET_CELL * (0.10 + _h01(seed, cx * 5 + 4, cz * 5 + 4) * 0.10)

const _Dim = preload("res://scripts/world/dimension_defs.gd")

## ── Màu sắc theo block ID ────────────────────────────────────────────────────
## Index = BlockID value — màu cho unshaded renderer (side_mul=0.50 tạo shading giả)
const BLOCK_COLORS_RW: Array[Color] = [
	Color(0, 0, 0, 0),                 # 0 AIR
	Color(0.22, 0.58, 0.14),           # 1 GRASS — xanh cỏ tươi vừa phải, bớt chói
	Color(0.12, 0.40, 0.08),           # 2 DARK_GRASS — xanh sậm rừng rậm
	Color(0.90, 0.76, 0.40),           # 3 SAND (hồ nội địa) — vàng cát ấm
	Color(0.46, 0.30, 0.14),           # 4 DIRT — nâu đất ấm, tương phản tốt hơn
	Color(0.20, 0.18, 0.15),           # 5 SILT — xám bùn hơi ấm
	Color(0.08, 0.36, 0.68, 0.70),     # 6 WATER (backward compat)
	Color(0.46, 0.46, 0.50),           # 7 STONE — đá xám hơi xanh lạnh
	Color(0.30, 0.18, 0.08),           # 8 DARK_DIRT — đất nâu tối
	Color(0.82, 0.68, 0.32),           # 9 SAND_DEEP — cát sâu vàng nâu ấm
	Color(0.16, 0.14, 0.16),           # 10 BEDROCK
	Color(0.78, 0.60, 0.26),           # 11 TRAIL — đường mòn đất nâu vàng
	Color(0.24, 0.30, 0.34),           # 12 OCEAN_FLOOR — cát thô xám xanh đáy biển
	Color(0.88, 0.80, 0.56),           # 13 OCEAN_SAND  — cát bãi biển sáng vừa
	Color(0.56, 0.48, 0.28),           # 14 MUDDY_SAND — cát bùn pha trộn
	Color(0.38, 0.34, 0.28),           # 15 OCEAN_GRAVEL — sỏi biển nâu xám
	Color(0.18, 0.22, 0.26),           # 16 OCEAN_MUD — bùn biển sâu xanh xám
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
	Color(0.38, 0.24, 0.12),           # 32 TILLED_SOIL — đất tơi xốp ẩm, nâu đậm
	Color(0.26, 0.26, 0.28),           # 33 COAL_ORE — than đen xám
	Color(0.46, 0.46, 0.50),           # 34 STONE_QTR — đá tư (khớp STONE)
	Color(0.48, 0.48, 0.52),           # 35 STONE_EIGHTH — đá vụn sáng hơn chút
	Color(0.44, 0.44, 0.48),           # 36 STONE_THIN — đá phiến mỏng
	Color(0.56, 0.48, 0.36),           # 37 OAK_WOOD — gỗ sồi nâu ấm
	Color(0.36, 0.56, 0.16),           # 38 YOUNG_GRASS — cỏ non xanh vàng tươi
	Color(0.40, 0.30, 0.18),           # 39 HARD_WOOD — gỗ cứng nâu sẫm
	Color(0.20, 0.52, 0.12),           # 40 GRASS_DIRT — cỏ đồng bằng xanh trung tính
	Color(0.92, 0.84, 0.58),           # 41 DESERT_PLATEAU — cát cao nguyên khô nhạt
	Color(0.12, 0.28, 0.20),           # 42 TWILIGHT_GRASS — cỏ Twilight (xanh tối rêu)
	Color(0.09, 0.12, 0.10),           # 43 TWILIGHT_DIRT — đất Twilight (nâu tối xanh)
	Color(0.62, 0.54, 0.22),           # 44 DRY_GRASS — cỏ già khô vàng rạ rõ hơn
	Color(0.32, 0.46, 0.14),           # 45 SPARSE_GRASS — cỏ thưa xanh lá đất
	Color(0.96, 0.90, 0.68),           # 46 PALE_SAND — cát phai sáng nhạt
	Color(0.13, 0.11, 0.09),           # 47 MANGROVE_MUD — bùn đầm lầy đen ngấm nước
	Color(0.56, 0.26, 0.14),           # 48 MANGROVE_WOOD — gỗ đước nâu đỏ
	Color(0.93, 0.96, 0.99),           # 49 SNOW — tuyết trắng tinh băng giá
	Color(0.44, 0.38, 0.42),           # 50 FROST_DIRT — đất đóng băng nâu xám lạnh
	Color(0.38, 0.24, 0.12),           # 51 SPRUCE_WOOD — gỗ vân sam nâu đỏ tối
	Color(0.95, 0.48, 0.10),           # 52 LAVA_SOURCE — cam nóng rực
	Color(0.88, 0.42, 0.08),           # 53 LAVA_LEVEL_7
	Color(0.80, 0.36, 0.06),           # 54 LAVA_LEVEL_6
	Color(0.72, 0.30, 0.05),           # 55 LAVA_LEVEL_5
	Color(0.65, 0.26, 0.04),           # 56 LAVA_LEVEL_4
	Color(0.56, 0.22, 0.03),           # 57 LAVA_LEVEL_3
	Color(0.48, 0.18, 0.02),           # 58 LAVA_LEVEL_2
	Color(0.40, 0.14, 0.02),           # 59 LAVA_LEVEL_1
	Color(0.14, 0.18, 0.10),           # 60 SWAMP_MUD — bùn đầm lầy nâu sậm pha xanh rêu
	Color(0.19, 0.16, 0.09),           # 61 SWAMP_DIRT — đất đầm lầy nâu xám ẩm
	Color(0.42, 0.38, 0.30),           # 62 SWAMP_WOOD — gỗ tràm nâu xám nhạt
	Color(0.46, 0.46, 0.50),           # 63 STONE_PLATFORM — đá nền platform (khớp STONE)
	Color(0.46, 0.46, 0.50),           # 64 STONE_WALL_Z — tường đá dày Z
	Color(0.46, 0.46, 0.50),           # 65 STONE_WALL_X — tường đá dày X
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
	Color(0.06, 0.08, 0.06),           # 39 HARD_WOOD
	Color(0.05, 0.16, 0.04),           # 40 GRASS_DIRT (TW palette placeholder)
	Color(0.06, 0.14, 0.09),           # 41 DESERT_PLATEAU
	Color(0.08, 0.20, 0.15),           # 42 TWILIGHT_GRASS — cỏ Twilight (xanh tối rêu)
	Color(0.05, 0.08, 0.06),           # 43 TWILIGHT_DIRT — đất Twilight (nâu tối xanh)
	Color(0.09, 0.08, 0.04),           # 44 DRY_GRASS (TW palette placeholder)
	Color(0.05, 0.07, 0.03),           # 45 SPARSE_GRASS (TW palette placeholder)
	Color(0.10, 0.09, 0.06),           # 46 PALE_SAND (TW palette placeholder)
	Color(0.04, 0.05, 0.04),           # 47 MANGROVE_MUD (TW palette placeholder)
	Color(0.06, 0.05, 0.04),           # 48 MANGROVE_WOOD (TW palette placeholder)
	Color(0.08, 0.10, 0.12),           # 49 SNOW (TW palette placeholder)
	Color(0.05, 0.04, 0.04),           # 50 FROST_DIRT (TW palette placeholder)
	Color(0.05, 0.04, 0.03),           # 51 SPRUCE_WOOD (TW palette placeholder)
	Color(0.95, 0.48, 0.10),           # 52 LAVA_SOURCE — cam nóng rực
	Color(0.88, 0.42, 0.08),           # 53 LAVA_LEVEL_7
	Color(0.80, 0.36, 0.06),           # 54 LAVA_LEVEL_6
	Color(0.72, 0.30, 0.05),           # 55 LAVA_LEVEL_5
	Color(0.65, 0.26, 0.04),           # 56 LAVA_LEVEL_4
	Color(0.56, 0.22, 0.03),           # 57 LAVA_LEVEL_3
	Color(0.48, 0.18, 0.02),           # 58 LAVA_LEVEL_2
	Color(0.40, 0.14, 0.02),           # 59 LAVA_LEVEL_1
	Color(0.05, 0.07, 0.04),           # 60 SWAMP_MUD (TW palette placeholder)
	Color(0.06, 0.05, 0.03),           # 61 SWAMP_DIRT (TW palette placeholder)
	Color(0.06, 0.05, 0.04),           # 62 SWAMP_WOOD (TW palette placeholder)
	Color(0.04, 0.08, 0.06),           # 63 STONE_PLATFORM (TW palette placeholder)
	Color(0.04, 0.08, 0.06),           # 64 STONE_WALL_Z (TW palette placeholder)
	Color(0.04, 0.08, 0.06),           # 65 STONE_WALL_X (TW palette placeholder)
]

## TRAIL_SINK bỏ — không dùng nữa để tránh void
## TRAIL phân biệt với terrain bằng màu, không bằng height
const TRAIL_SINK: float = 0.0

## Side màu tối hơn top — unshaded cần chênh lệch rõ để tạo cảm giác 3D
static func block_side_color(top_col: Color) -> Color:
	return Color(top_col.r * 0.50, top_col.g * 0.50, top_col.b * 0.50, top_col.a)

## ── Khối cỏ Minecraft-style: mặt trên xanh cỏ, nửa dưới mặt bên + đáy = đất ──
## Trả về BlockID đất tương ứng (-1 nếu không phải khối cỏ kiểu này).
static func grass_dirt_id(block_id: int) -> int:
	match block_id:
		BlockID.GRASS:        return BlockID.DIRT
		BlockID.DARK_GRASS:   return BlockID.DARK_DIRT
		BlockID.YOUNG_GRASS:  return BlockID.DIRT
		BlockID.GRASS_DIRT:   return BlockID.DIRT
		BlockID.DRY_GRASS:    return BlockID.DIRT
		BlockID.SPARSE_GRASS: return BlockID.DIRT
		BlockID.TWILIGHT_GRASS: return BlockID.TWILIGHT_DIRT
		BlockID.MANGROVE_MUD: return BlockID.MANGROVE_MUD
		BlockID.SNOW: return BlockID.FROST_DIRT
		BlockID.SWAMP_MUD: return BlockID.SWAMP_DIRT
		_: return -1

static func is_grass_top_block(block_id: int) -> bool:
	return grass_dirt_id(block_id) >= 0

## ── Block có hình dạng riêng (không phải voxel đầy) ─────────────────────────
## Kích thước hộp tính theo đơn vị block (slab chuẩn = 1×0.5×1).
## Block shape KHÔNG tham gia heightmap/top_ly — luôn vẽ đè lên terrain.
const BLOCK_SHAPES: Dictionary = {
	BlockID.STONE_QTR:    Vector3(0.5, 0.5, 0.5),   # ¼ khối đá
	BlockID.STONE_EIGHTH: Vector3(0.5, 0.25, 0.5),  # ⅛ khối đá
	BlockID.STONE_THIN:   Vector3(1.0, 0.2, 1.0),   # tấm mỏng 0.2
	BlockID.STONE_PLATFORM: Vector3(1.0, 0.5, 1.0), # nền đá — đầy cell (dày 0.5)
	BlockID.STONE_WALL_Z:   Vector3(1.0, 0.5, 0.5), # tường đá — dài X, dày Z 0.5
	BlockID.STONE_WALL_X:   Vector3(0.5, 0.5, 1.0), # tường đá — dài Z, dày X 0.5
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

## ── Núi lửa — lava ─────────────────────────────────────────────────────────
static func is_lava(bid: int) -> bool:
	return bid == BlockID.LAVA_SOURCE \
		or (bid >= BlockID.LAVA_LEVEL_7 and bid <= BlockID.LAVA_LEVEL_1)

static func lava_level(bid: int) -> int:
	if bid == BlockID.LAVA_SOURCE:
		return 8
	if bid >= BlockID.LAVA_LEVEL_7 and bid <= BlockID.LAVA_LEVEL_1:
		return 8 - (bid - BlockID.LAVA_LEVEL_7)
	return 0

static func is_source_lava(bid: int) -> bool:
	return bid == BlockID.LAVA_SOURCE

static func lava_block_for_level(level: int) -> int:
	if level >= 8:
		return BlockID.LAVA_SOURCE
	if level >= 1:
		return BlockID.LAVA_LEVEL_7 - (level - 7)
	return BlockID.AIR

## Fluid chung: water hoặc lava.
static func is_fluid(bid: int) -> bool:
	return is_water(bid) or is_lava(bid)

static func fluid_level(bid: int) -> int:
	if is_water(bid):
		return water_level(bid)
	if is_lava(bid):
		return lava_level(bid)
	return 0

## Block nào là solid (player không đi xuyên qua)
static func is_solid(block_id: int) -> bool:
	return block_id != BlockID.AIR and not is_fluid(block_id)

## Block nào là indestructible (không thể phá vỡ)
static func is_indestructible(block_id: int) -> bool:
	return block_id == BlockID.BEDROCK

## Block nào là transparent (render both sides / skip face culling)
static func is_transparent(block_id: int) -> bool:
	return block_id == BlockID.AIR or is_fluid(block_id)

## ── Đất tơi xốp ─────────────────────────────────────────────────────────────
## Bán kính nước (block) làm đất tơi xốp chuyển sang trạng thái ẩm.
const SOIL_RADIUS: int = 3

static func is_soil(bid: int) -> bool:
	return bid == BlockID.TILLED_SOIL

## Block nào cuốc được thành đất tơi xốp.
static func is_tillable(bid: int) -> bool:
	return bid == BlockID.GRASS or bid == BlockID.DARK_GRASS \
		or bid == BlockID.DIRT or bid == BlockID.DARK_DIRT \
		or bid == BlockID.YOUNG_GRASS or bid == BlockID.GRASS_DIRT \
		or bid == BlockID.DRY_GRASS or bid == BlockID.SPARSE_GRASS \
		or bid == BlockID.MANGROVE_MUD \
		or bid == BlockID.SWAMP_MUD or bid == BlockID.SWAMP_DIRT

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
	BlockID.STONE_PLATFORM: 1.2,
	BlockID.STONE_WALL_Z:   1.2,
	BlockID.STONE_WALL_X:   1.2,
	BlockID.BAUXITE_ORE:  1.3,
	BlockID.COPPER_ORE:   1.6,
	BlockID.GOLD_ORE:     1.7,
	BlockID.SILVER_ORE:   1.8,
	BlockID.IRON_ORE:     2.4,
	BlockID.PLATINUM_ORE: 3.0,
	BlockID.TITAN_ORE:    3.6,
	# Rìu — gỗ
	BlockID.OAK_WOOD:     1.4,
	BlockID.HARD_WOOD:    1.6,
	# Cỏ non — như cỏ thường
	BlockID.YOUNG_GRASS:  1.2,
	# Cỏ già / cỏ thưa — như cỏ thường
	BlockID.DRY_GRASS:    1.2,
	BlockID.SPARSE_GRASS: 1.2,
	# Cát phai — như cát
	BlockID.PALE_SAND:    1.2,
	# Bùn ngập mặn — như đất sình, xẻng
	BlockID.MANGROVE_MUD: 1.3,
	# Gỗ đước — như gỗ sồi, rìu
	BlockID.MANGROVE_WOOD: 1.5,
	# Cỏ đồng bằng cỏ — như cỏ thường
	BlockID.GRASS_DIRT: 1.2,
	# Cát cao nguyên sa mạc — như cát
	BlockID.DESERT_PLATEAU: 1.2,
	# Đất Twilight — như cỏ/đất
	BlockID.TWILIGHT_GRASS: 1.2,
	BlockID.TWILIGHT_DIRT: 1.2,
	# Bio băng giá — tuyết mềm, đất đông cứng
	BlockID.SNOW: 0.8,
	BlockID.FROST_DIRT: 1.2,
	# Gỗ vân sam — như gỗ sồi, rìu
	BlockID.SPRUCE_WOOD: 1.5,
	# Bùn đầm lầy — đất sình, xẻng
	BlockID.SWAMP_MUD: 1.2,
	BlockID.SWAMP_DIRT: 1.2,
	# Gỗ tràm — như gỗ sồi, rìu
	BlockID.SWAMP_WOOD: 1.5,
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
		or bid == BlockID.STONE_PLATFORM or bid == BlockID.STONE_WALL_Z or bid == BlockID.STONE_WALL_X \
		or (bid >= BlockID.COPPER_ORE and bid <= BlockID.PLATINUM_ORE) \
		or bid == BlockID.COAL_ORE

## Block nào xẻng (shovel) đào được — đất, cát, bùn...
static func is_shovelable(bid: int) -> bool:
	return bid == BlockID.GRASS or bid == BlockID.DARK_GRASS or bid == BlockID.DIRT \
		or bid == BlockID.DARK_DIRT or bid == BlockID.TILLED_SOIL \
		or bid == BlockID.YOUNG_GRASS or bid == BlockID.GRASS_DIRT \
		or bid == BlockID.DRY_GRASS or bid == BlockID.SPARSE_GRASS or bid == BlockID.PALE_SAND \
		or bid == BlockID.TWILIGHT_GRASS or bid == BlockID.TWILIGHT_DIRT \
		or bid == BlockID.SAND or bid == BlockID.SAND_DEEP or bid == BlockID.OCEAN_SAND \
		or bid == BlockID.MUDDY_SAND or bid == BlockID.OCEAN_GRAVEL or bid == BlockID.OCEAN_MUD \
		or bid == BlockID.SILT or bid == BlockID.TRAIL or bid == BlockID.OCEAN_FLOOR \
		or bid == BlockID.DESERT_PLATEAU \
		or bid == BlockID.MANGROVE_MUD \
		or bid == BlockID.SNOW or bid == BlockID.FROST_DIRT

## Block nào rìu (axe) đào được — gỗ.
static func is_axable(bid: int) -> bool:
	return bid == BlockID.OAK_WOOD or bid == BlockID.HARD_WOOD \
		or bid == BlockID.MANGROVE_WOOD or bid == BlockID.SPRUCE_WOOD \
		or bid == BlockID.SWAMP_WOOD

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
