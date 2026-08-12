class_name ItemDatabase
extends RefCounted

static var items_db: Dictionary = {}

## Thời gian ăn (giây) theo từng loại thức ăn — mặc định 3.0s
const EAT_TIMES: Dictionary = {
	"shrimp": 1.2,
	"climbing_perch": 1.8,
	"carp": 2.0,
	"red_tilapia": 2.2,
	"pumpkin": 2.5,
	"taro": 2.5,
	"snakehead": 2.8,
	"flowerhorn": 3.0,
	"coconut": 3.2,
	"raw_pork": 4.0,
	"eggplant_fruit": 2.5,
	"eggplant_slice": 1.8,
	"watermelon": 3.0,
	"watermelon_slice": 1.2,
	"pumpkin_slice": 1.2,
	"orange": 2.2,
}

static func ensure_db() -> void:
	if items_db.is_empty():
		items_db = create_item_db()

static func create_item_db() -> Dictionary:
	var db: Dictionary = {}
	_add(db, "chest",         "Rương Gỗ",     ItemDef.Type.BLOCK,  Color(0.50, 0.32, 0.10), "C",  "Rương gỗ chắc chắn",     false, 1)
	_add(db, "crafting_table", "Bàn Chế Tạo", ItemDef.Type.BLOCK,  Color(0.45, 0.28, 0.15), "W",  "Bàn chế tạo đa năng",     false, 1)
	_add(db, "furnace",       "Lò Nung",     ItemDef.Type.BLOCK,  Color(0.30, 0.28, 0.26), "F",  "Lò nung quặng — nấu chảy quặng thành thỏi", false, 1)
	_add(db, "twilight_gate", "Cổng Twilight", ItemDef.Type.TOOL,   Color(0.10, 0.50, 0.45), "T",  "Đặt cổng Twilight ra thế giới", false, 1)

	# ── Công cụ ────────────────────────────────────────────────────────────────
	_add(db, "pickaxe",   "Cúp Sắt",   ItemDef.Type.TOOL,   Color(0.60, 0.55, 0.50), "⛏", "Đào đất, khai thác tài nguyên",   false, 1, 0, 3,  0, -1, 251)
	_add(db, "shovel",  "Xẻng Sắt",  ItemDef.Type.TOOL,   Color(0.70, 0.65, 0.55), "🔨", "Xúc đất, di chuyển vật liệu",     false, 1, 0, 2,  0, -1, 251)
	_add(db, "axe",   "Rìu Sắt",   ItemDef.Type.TOOL,   Color(0.50, 0.45, 0.40), "🪓", "Chặt cây, phá gỗ",                false, 1, 0, 8, 0, -1, 251)
	_add(db, "hoe",   "Cuốc Sắt",  ItemDef.Type.TOOL,   Color(0.58, 0.52, 0.44), "🪏", "Cuốc cỏ/đất thành đất tơi xốp để trồng mầm", false, 1, 0, 2, 0, -1, 251)

	# ── Vũ khí ─────────────────────────────────────────────────────────────────
	_add(db, "iron_sword",    "Kiếm Sắt",       ItemDef.Type.WEAPON, Color(0.75, 0.80, 0.90), "⚔", "Tấn công nhanh, sát thương cao",  false, 1, 0, 6, 0, -1, 251)
	_add(db, "iron_greatsword","Đại Kiếm Sắt",   ItemDef.Type.WEAPON, Color(0.40, 0.45, 0.60), "🗡", "Chém mạnh một nhát, sát thương cực cao", false, 1, 0, 12, 0, -1, 500)
	_add(db, "leather_gloves","Găng Tay Da Thú", ItemDef.Type.WEAPON, Color(0.55, 0.32, 0.14), "🥊", "Đấm nhanh liên hoàn, sát thương thấp", false, 1, 0, 5, 0, -1, 60)
	_add(db, "iron_halberd","Kích Sắt",   ItemDef.Type.WEAPON, Color(0.55, 0.55, 0.62), "🔱", "Kích dài sắt — tầm đánh xa, sát thương mạnh", false, 1, 0, 10, 0, -1, 400)
	_add(db, "crossbow",          "Nỏ",          ItemDef.Type.WEAPON, Color(0.55, 0.35, 0.18), "🏹", "Nỏ — bắn tên từ xa, giữ chuột để nạp và tăng sát thương", false, 1, 0, 8, 0, -1, 300)
	_add(db, "watermelon_cannon","Pháo Dưa Hấu Hạt Nhân", ItemDef.Type.WEAPON, Color(0.20, 0.55, 0.15), "🍉", "Bắn đạn hạt nhân dưa hấu phát nổ gây sát thương vùng. Cần đạn hạt nhân dưa hấu!", false, 1, 0, 20, 0, -1, 150)

	# ── Câu cá ────────────────────────────────────────────────────────────────
	_add(db, "fishing_rod", "Cần câu", ItemDef.Type.TOOL, Color(0.55, 0.40, 0.25), "🎣", "Cần câu cá — dùng để câu cá ở vùng nước", false, 1, 0, 0, 0, -1, 64)
	_add(db, "fishing_boat", "Thuyền Đánh Cá", ItemDef.Type.TOOL, Color(0.55, 0.36, 0.18), "⛵", "Thuyền đánh cá — đặt xuống nước, nhấn F để lên thuyền chèo ra sông câu cá", false, 1)
	_add(db, "tractor", "Máy Kéo Nông Nghiệp", ItemDef.Type.TOOL, Color(0.72, 0.10, 0.08), "🚜", "Máy kéo + rơ-moóc chở hàng — đặt xuống đất, nhấn F để lên lái xe băng qua ruộng", false, 1)
	_add(db, "rescue_helicopter", "Trực Thăng Cứu Hộ", ItemDef.Type.TOOL, Color(0.82, 0.16, 0.10), "🚁", "Trực thăng cứu hộ đa năng — đặt xuống, nhấn F lên lái, SPACE bay lên / SHIFT hạ xuống / WASD di chuyển", false, 1)
	_add(db, "water_bucket", "Xô Nước", ItemDef.Type.TOOL, Color(0.15, 0.40, 0.70), "🌊", "Xô đựng nước — đặt khối nước tại vị trí chỉ định", false, 16)

	# ── Cá (thức ăn) ──────────────────────────────────────────────────────────
	_add(db, "carp", "Carp", ItemDef.Type.FOOD, Color(0.95, 0.70, 0.10), "🐟", "Freshwater carp — rich, firm flesh", true, 16, 30)
	_add(db, "climbing_perch",   "Climbing Perch", ItemDef.Type.FOOD, Color(0.30, 0.30, 0.30), "🐟", "Climbing perch — sweet white meat", true, 16, 20)
	_add(db, "red_tilapia", "Red Tilapia", ItemDef.Type.FOOD, Color(0.88, 0.55, 0.45), "🐟", "Red tilapia — firm, mild flavour", true, 16, 35)
	_add(db, "snakehead", "Snakehead", ItemDef.Type.FOOD, Color(0.30, 0.25, 0.15), "🐟", "Snakehead — dense, savoury fillet", true, 16, 45)
	_add(db, "flowerhorn", "Flowerhorn", ItemDef.Type.FOOD, Color(0.92, 0.25, 0.15), "🐟", "Flowerhorn — rich, flavourful meat", true, 16, 55)
	_add(db, "shrimp", "Freshwater Shrimp", ItemDef.Type.FOOD, Color(0.85, 0.35, 0.20), "🦐", "Freshwater shrimp — sweet, delicate meat", true, 16, 8)

	# ── Trứng sinh vật (chỉ có ở thư viện — ném parabol, chạm đất nở con) ─────
	_add(db, "egg_carp",       "Trứng Cá Chép",      ItemDef.Type.MATERIAL, Color(0.95, 0.70, 0.10), "🥚", "Trứng cá chép — giữ chuột trái để ngắm, thả để ném; chạm nước nở cá chép", true, 16)
	_add(db, "egg_perch",      "Trứng Cá Rô",        ItemDef.Type.MATERIAL, Color(0.30, 0.30, 0.30), "🥚", "Trứng cá rô — giữ chuột trái để ngắm, thả để ném; chạm nước nở cá rô", true, 16)
	_add(db, "egg_tilapia",    "Trứng Cá Điêu Hồng", ItemDef.Type.MATERIAL, Color(0.88, 0.55, 0.45), "🥚", "Trứng cá điêu hồng — giữ chuột trái để ngắm, thả để ném; chạm nước nở cá điêu hồng", true, 16)
	_add(db, "egg_snakehead",  "Trứng Cá Lóc",       ItemDef.Type.MATERIAL, Color(0.30, 0.25, 0.15), "🥚", "Trứng cá lóc — giữ chuột trái để ngắm, thả để ném; chạm nước nở cá lóc", true, 16)
	_add(db, "egg_flowerhorn", "Trứng Cá La Hán",    ItemDef.Type.MATERIAL, Color(0.92, 0.25, 0.15), "🥚", "Trứng cá la hán — giữ chuột trái để ngắm, thả để ném; chạm nước nở cá la hán", true, 16)
	_add(db, "egg_shrimp",     "Trứng Tôm",          ItemDef.Type.MATERIAL, Color(0.85, 0.35, 0.20), "🥚", "Trứng tôm — giữ chuột trái để ngắm, thả để ném; chạm nước nở tôm", true, 16)
	_add(db, "egg_pig",        "Trứng Heo",          ItemDef.Type.MATERIAL, Color(0.87, 0.72, 0.63), "🥚", "Trứng heo — giữ chuột trái để ngắm, thả để ném; chạm đất nở heo con", true, 16)

	_add(db, "pumpkin", "Trái Bí Đỏ", ItemDef.Type.FOOD, Color(0.91,0.41,0.21), "🎃", "Trái bí đỏ — cầu dẹp 8-10 múi khía sâu, cam cháy ấm, cuống gỗ 5 góc; chế biến món ăn, trang trí hoặc đục thành đèn lồng", true, 16, 14)

	# ── Thịt ──────────────────────────────────────────────────────────────────
	_add(db, "raw_pork", "Thịt Heo Sống", ItemDef.Type.FOOD, Color(0.85, 0.50, 0.45), "🥩", "Thịt heo tươi — nấu chín trước khi ăn", true, 16, 12)

	# ── Slime ─────────────────────────────────────────────────────────────────
	_add(db, "slime_ball", "Slimeball", ItemDef.Type.MATERIAL, Color(0.45, 0.85, 0.35), "🟢", "Quả gel dính xanh lá — lấy từ slime, chế tạo Piston Dính / Slime Block", true, 64)

	# ── Vật phẩm từ prop ─────────────────────────────────────────────────────
	_add(db, "taro", "Môn ngọt (Taro)", ItemDef.Type.FOOD, Color(0.25, 0.50, 0.15), "🌿", "Củ môn ngọt — có thể nấu ăn", true, 16, 12)
	_add(db, "coconut", "Trái Dừa", ItemDef.Type.FOOD, Color(0.50, 0.35, 0.20), "🥥", "Trái dừa tươi — bổ dưỡng, giải khát", true, 16, 16)
	_add(db, "palm_wood", "Gỗ Dừa", ItemDef.Type.MATERIAL, Color(0.78, 0.70, 0.48), "🪵", "Gỗ dừa chắc — nguyên liệu chế tạo", true, 64)
	_add(db, "tropical_seaweed", "Rong nhiệt đới", ItemDef.Type.MATERIAL, Color(0.08, 0.55, 0.10), "🌊", "Rong nhiệt đới — nguyên liệu chế tạo", true, 32)
	_add(db, "seagrass", "Cỏ Biển", ItemDef.Type.MATERIAL, Color(0.10, 0.62, 0.42), "🌿", "Cỏ biển tươi — lá dài mảnh, nguyên liệu chế tạo", true, 32)

	# ── Mầm cây trồng ─────────────────────────────────────────────────────────
	_add(db, "coconut_seed", "Mầm Dừa", ItemDef.Type.MATERIAL, Color(0.45, 0.72, 0.25), "🌱", "Mầm dừa — trồng trên đất tơi xốp, lớn thành cây dừa", true, 16)
	_add(db, "taro_seed", "Mầm Môn Ngọt", ItemDef.Type.MATERIAL, Color(0.30, 0.55, 0.18), "🌱", "Mầm môn ngọt — trồng trên đất tơi xốp, thu hoạch củ môn", true, 16)
	_add(db, "seaweed_seed", "Mầm Rong Nhiệt Đới", ItemDef.Type.MATERIAL, Color(0.10, 0.60, 0.12), "🌱", "Mầm rong nhiệt đới — trồng dưới nước trên cát/bùn", true, 16)
	_add(db, "seagrass_seed", "Hạt Giống Cỏ Biển", ItemDef.Type.MATERIAL, Color(0.08, 0.55, 0.38), "🌱", "Hạt giống cỏ biển — gieo xuống biển nông trên nền cát, lớn thành bụi cỏ biển", true, 16)

	# ── Quặng & Kim loại ──────────────────────────────────────────────────────
	# Copper (Đồng)
	_add(db, "copper_ore",             "Copper Ore",            ItemDef.Type.BLOCK,    Color(0.38, 0.29, 0.18), "🧱", "Quặng đồng thô — nung thành Copper Ingot", true, 64)
	_add(db, "copper_ingot",           "Copper Ingot",          ItemDef.Type.MATERIAL, Color(0.70, 0.55, 0.15), "RM", "Thỏi đồng — kim loại cơ bản", true, 64)
	_add(db, "copper_high_ingot",      "Copper High Ingot",     ItemDef.Type.MATERIAL, Color(0.85, 0.70, 0.20), "RM", "Thỏi đồng tinh luyện cao — sáng bóng", true, 64)
	_add(db, "copper_purified_ingot",  "Copper Purified Ingot", ItemDef.Type.MATERIAL, Color(0.92, 0.78, 0.30), "RM", "Thỏi đồng tinh khiết — phát sáng nhẹ", true, 64)

	# Bauxite → Aluminium (Nhôm)
	_add(db, "bauxite_ore",             "Bauxite Ore",              ItemDef.Type.BLOCK,    Color(0.55, 0.35, 0.25), "🧱", "Quặng bô-xít — nung thành Aluminium Ingot", true, 64)
	_add(db, "aluminium_ingot",         "Aluminium Ingot",          ItemDef.Type.MATERIAL, Color(0.65, 0.65, 0.68), "RM", "Thỏi nhôm — nhẹ, bền", true, 64)
	_add(db, "aluminium_high_ingot",    "Aluminium High Ingot",     ItemDef.Type.MATERIAL, Color(0.80, 0.80, 0.85), "RM", "Thỏi nhôm tinh luyện cao — sáng bóng", true, 64)
	_add(db, "aluminium_purified_ingot","Aluminium Purified Ingot", ItemDef.Type.MATERIAL, Color(0.90, 0.90, 0.95), "RM", "Thỏi nhôm tinh khiết — phát sáng nhẹ", true, 64)

	# Silver (Bạc)
	_add(db, "silver_ore",             "Silver Ore",            ItemDef.Type.BLOCK,    Color(0.35, 0.35, 0.38), "🧱", "Quặng bạc thô — nung thành Silver Ingot", true, 64)
	_add(db, "silver_ingot",           "Silver Ingot",          ItemDef.Type.MATERIAL, Color(0.75, 0.75, 0.80), "RM", "Thỏi bạc — kim loại quý", true, 64)
	_add(db, "silver_high_ingot",      "Silver High Ingot",     ItemDef.Type.MATERIAL, Color(0.88, 0.88, 0.92), "RM", "Thỏi bạc tinh luyện cao — sáng bóng", true, 64)
	_add(db, "silver_purified_ingot",  "Silver Purified Ingot", ItemDef.Type.MATERIAL, Color(0.95, 0.95, 1.00), "RM", "Thỏi bạc tinh khiết — phát sáng nhẹ", true, 64)

	# Iron (Sắt)
	_add(db, "iron_ore",               "Iron Ore",              ItemDef.Type.BLOCK,    Color(0.36, 0.31, 0.26), "🧱", "Quặng sắt thô — nung thành Iron Ingot", true, 64)
	_add(db, "iron_ingot",             "Iron Ingot",            ItemDef.Type.MATERIAL, Color(0.55, 0.55, 0.60), "RM", "Thỏi sắt — kim loại cơ bản", true, 64)
	_add(db, "iron_high_ingot",        "Iron High Ingot",       ItemDef.Type.MATERIAL, Color(0.72, 0.72, 0.78), "RM", "Thỏi sắt tinh luyện cao — sáng bóng", true, 64)
	_add(db, "iron_purified_ingot",    "Iron Purified Ingot",   ItemDef.Type.MATERIAL, Color(0.85, 0.85, 0.90), "RM", "Thỏi sắt tinh khiết — phát sáng nhẹ", true, 64)

	# Gold (Vàng)
	_add(db, "gold_ore",               "Gold Ore",              ItemDef.Type.BLOCK,    Color(0.37, 0.33, 0.29), "🧱", "Quặng vàng thô — nung thành Gold Ingot", true, 64)
	_add(db, "gold_ingot",             "Gold Ingot",            ItemDef.Type.MATERIAL, Color(0.85, 0.65, 0.10), "RM", "Thỏi vàng — kim loại quý", true, 64)
	_add(db, "gold_high_ingot",        "Gold High Ingot",       ItemDef.Type.MATERIAL, Color(0.92, 0.75, 0.15), "RM", "Thỏi vàng tinh luyện cao — sáng bóng", true, 64)
	_add(db, "gold_purified_ingot",    "Gold Purified Ingot",   ItemDef.Type.MATERIAL, Color(0.97, 0.82, 0.25), "RM", "Thỏi vàng tinh khiết — phát sáng nhẹ", true, 64)

	# Steel (Thép) — hợp kim, không có quặng thô
	_add(db, "steel_ingot",            "Steel Ingot",           ItemDef.Type.MATERIAL, Color(0.50, 0.50, 0.55), "RM", "Thỏi thép — hợp kim bền chắc", true, 64)
	_add(db, "steel_high_ingot",       "Steel High Ingot",      ItemDef.Type.MATERIAL, Color(0.60, 0.60, 0.65), "RM", "Thỏi thép tinh luyện cao — sáng bóng", true, 64)
	_add(db, "steel_purified_ingot",   "Steel Purified Ingot",  ItemDef.Type.MATERIAL, Color(0.75, 0.75, 0.82), "RM", "Thỏi thép tinh khiết — phát sáng nhẹ", true, 64)

	# Titan (Titanium)
	_add(db, "titan_ore",              "Titan Ore",             ItemDef.Type.BLOCK,    Color(0.35, 0.30, 0.40), "🧱", "Quặng titan thô — nung thành Titan Ingot", true, 64)
	_add(db, "titan_ingot",            "Titan Ingot",           ItemDef.Type.MATERIAL, Color(0.55, 0.60, 0.70), "RM", "Thỏi titan — siêu bền, chịu nhiệt", true, 64)
	_add(db, "titan_high_ingot",       "Titan High Ingot",      ItemDef.Type.MATERIAL, Color(0.70, 0.75, 0.85), "RM", "Thỏi titan tinh luyện cao — sáng bóng", true, 64)
	_add(db, "titan_purified_ingot",   "Titan Purified Ingot",  ItemDef.Type.MATERIAL, Color(0.85, 0.88, 0.95), "RM", "Thỏi titan tinh khiết — phát sáng nhẹ", true, 64)

	# Platinum (Bạch kim)
	_add(db, "platinum_ore",           "Platinum Ore",          ItemDef.Type.BLOCK,    Color(0.30, 0.30, 0.35), "🧱", "Quặng bạch kim thô — nung thành Platinum Ingot", true, 64)
	_add(db, "platinum_ingot",         "Platinum Ingot",        ItemDef.Type.MATERIAL, Color(0.80, 0.82, 0.88), "RM", "Thỏi bạch kim — kim loại quý hiếm", true, 64)
	_add(db, "platinum_high_ingot",    "Platinum High Ingot",   ItemDef.Type.MATERIAL, Color(0.90, 0.92, 0.96), "RM", "Thỏi bạch kim tinh luyện cao — sáng bóng", true, 64)
	_add(db, "platinum_purified_ingot","Platinum Purified Ingot",ItemDef.Type.MATERIAL, Color(0.97, 0.98, 1.00), "RM", "Thỏi bạch kim tinh khiết — phát sáng nhẹ", true, 64)

	# Coal (Than)
	_add(db, "coal_ore",  "Quặng Than", ItemDef.Type.BLOCK,    Color(0.28, 0.28, 0.30), "🧱", "Quặng than — đào ra Than Đá", true, 64)
	_add(db, "coal",      "Than Đá",    ItemDef.Type.MATERIAL, Color(0.18, 0.18, 0.20), "🪨", "Than đá — nhiên liệu đốt lò rèn", true, 64)
	_add(db, "charcoal",  "Than Củi",   ItemDef.Type.MATERIAL, Color(0.14, 0.12, 0.10), "🪵", "Than củi — đốt từ gỗ, nhiên liệu nhẹ", true, 64)

	# Dark Metal (Kim loại tối) — chỉ có dạng tinh luyện cao
	_add(db, "dark_metal_high_ingot",   "Dark Metal High Ingot",   ItemDef.Type.MATERIAL, Color(0.25, 0.25, 0.28), "RM", "Thỏi kim loại tối tinh luyện — ma thuật", true, 64)
	_add(db, "dark_metal_purified_ingot","Dark Metal Purified Ingot",ItemDef.Type.MATERIAL, Color(0.30, 0.20, 0.45), "RM", "Thỏi kim loại tối tinh khiết — hào quang tím", true, 64)

	_add(db, "arrow", "Mũi Tên", ItemDef.Type.MATERIAL, Color(0.60, 0.50, 0.35), "🪶", "Đạn cho nỏ — tiêu hao khi bắn", true, 64)
	_add(db, "watermelon_nuke_ammo", "Đạn Hạt Nhân Dưa Hấu", ItemDef.Type.MATERIAL, Color(0.18, 0.50, 0.12), "☢", "Đạn cho pháo dưa hấu hạt nhân — tiêu hao khi bắn", true, 32)
	_add(db, "pumpkin_mortar", "Pháo Cối Bí Đỏ", ItemDef.Type.WEAPON, Color(0.80, 0.50, 0.15), "🎃", "Pháo cối bí đỏ — bắn đạn bí đỏ theo đường parabal, gây sát thương vùng + để lại bãi lầy làm chậm. Cần bí đỏ!", false, 1, 0, 11, 0, -1, 150)

	# ── Khối (đào từ thế giới) ─────────────────────────────────────────────────
	_add(db, "block_grass",       "Cỏ",        ItemDef.Type.BLOCK, Color(0.22, 0.58, 0.14), "🧱", "Khối cỏ",           true, 64)
	_add(db, "block_dark_grass",  "Cỏ Tối",    ItemDef.Type.BLOCK, Color(0.14, 0.40, 0.08), "🧱", "Khối cỏ tối",       true, 64)
	_add(db, "block_young_grass", "Cỏ Non",    ItemDef.Type.BLOCK, Color(0.34, 0.58, 0.14), "🧱", "Khối cỏ non — bãi đất pha cỏ mới mọc ở đồng bằng", true, 64)
	_add(db, "block_grass_dirt", "Cỏ Đồng Bằng Cỏ", ItemDef.Type.BLOCK, Color(0.16, 0.54, 0.10), "🧱", "Khối cỏ đồng bằng — địa hình đồi thoải chung, hợp nhất đồng bằng + cao nguyên", true, 64)
	_add(db, "block_desert_plateau", "Cát Cao Nguyên Sa Mạc", ItemDef.Type.BLOCK, Color(0.90, 0.82, 0.55), "🧱", "Khối cát cao nguyên sa mạc — sa mạc nâng cao, địa hình gồ ghề (mesa)", true, 64)
	_add(db, "block_twilight_grass", "Cỏ Twilight", ItemDef.Type.BLOCK, Color(0.12, 0.28, 0.20), "🧱", "Khối cỏ Twilight — bề mặt thế giới Twilight", true, 64)
	_add(db, "block_twilight_dirt", "Đất Twilight", ItemDef.Type.BLOCK, Color(0.09, 0.12, 0.10), "🧱", "Khối đất Twilight — đất nền bên dưới cỏ Twilight", true, 64)
	_add(db, "block_dry_grass", "Cỏ Già", ItemDef.Type.BLOCK, Color(0.55, 0.48, 0.14), "🧱", "Khối cỏ già — cỏ khô vàng rạ, đốm rải rác trên đồng bằng", true, 64)
	_add(db, "block_sparse_grass", "Cỏ Thưa", ItemDef.Type.BLOCK, Color(0.28, 0.42, 0.10), "🧱", "Khối cỏ thưa — cỏ lẫn đất, đốm thưa trên đồng bằng", true, 64)
	_add(db, "block_pale_sand", "Cát Phai", ItemDef.Type.BLOCK, Color(0.94, 0.88, 0.62), "🧱", "Khối cát phai — cát nhạt, đốm cồn mòn trên sa mạc", true, 64)
	_add(db, "block_sand",        "Cát",       ItemDef.Type.BLOCK, Color(0.92, 0.78, 0.32), "🧱", "Khối cát",          true, 64)
	_add(db, "block_dirt",        "Đất",       ItemDef.Type.BLOCK, Color(0.42, 0.22, 0.08), "🧱", "Khối đất",          true, 64)
	_add(db, "block_silt",        "Phù Sa",    ItemDef.Type.BLOCK, Color(0.16, 0.15, 0.13), "🧱", "Khối phù sa",       true, 64)
	_add(db, "block_stone",       "Đá",        ItemDef.Type.BLOCK, Color(0.42, 0.42, 0.46), "🧱", "Khối đá",           true, 64)
	_add(db, "block_stone_qtr",   "Đá Tư",     ItemDef.Type.BLOCK, Color(0.42, 0.42, 0.46), "🧱", "Đá tư — ¼ khối đá, đặt làm bậc/trang trí", true, 64)
	_add(db, "block_stone_eighth","Đá Vụn",    ItemDef.Type.BLOCK, Color(0.44, 0.44, 0.48), "🧱", "Đá vụn — ⅛ khối đá, tấm mỏng", true, 64)
	_add(db, "block_stone_thin",  "Đá Phiến",  ItemDef.Type.BLOCK, Color(0.40, 0.40, 0.44), "🧱", "Đá phiến — dày 0.2 thay vì 0.5 như block thường", true, 64)
	_add(db, "block_dark_dirt",   "Đất Tối",   ItemDef.Type.BLOCK, Color(0.28, 0.16, 0.06), "🧱", "Khối đất tối",      true, 64)
	_add(db, "block_sand_deep",   "Cát Sâu",   ItemDef.Type.BLOCK, Color(0.80, 0.66, 0.28), "🧱", "Khối cát sâu",      true, 64)
	_add(db, "block_trail",       "Đường Mòn", ItemDef.Type.BLOCK, Color(0.76, 0.58, 0.22), "🧱", "Khối đường mòn",    true, 64)
	_add(db, "block_ocean_floor", "Đáy Biển",  ItemDef.Type.BLOCK, Color(0.22, 0.28, 0.32), "🧱", "Khối đáy biển",     true, 64)
	_add(db, "block_ocean_sand",  "Cát Biển",  ItemDef.Type.BLOCK, Color(0.86, 0.78, 0.52), "🧱", "Khối cát biển",     true, 64)
	_add(db, "block_muddy_sand",  "Cát Bùn",   ItemDef.Type.BLOCK, Color(0.54, 0.46, 0.22), "🧱", "Khối cát bùn",      true, 64)
	_add(db, "block_ocean_gravel","Sỏi Biển",  ItemDef.Type.BLOCK, Color(0.35, 0.30, 0.25), "🧱", "Khối sỏi biển",     true, 64)
	_add(db, "block_ocean_mud",   "Bùn Biển",  ItemDef.Type.BLOCK, Color(0.16, 0.20, 0.22), "🧱", "Khối bùn biển",     true, 64)
	_add(db, "block_tilled_soil", "Đất Tơi Xốp", ItemDef.Type.BLOCK, Color(0.36, 0.22, 0.11), "🧱", "Đất tơi xốp — ẩm khi gần nước, trồng được mầm cây", true, 64)
	_add(db, "block_oak_wood", "Gỗ Sồi", ItemDef.Type.BLOCK, Color(0.62, 0.47, 0.28), "🧱", "Khối gỗ sồi — vân nâu sáng ấm, chặt từ cây sồi bằng rìu, xây dựng và chế tạo", true, 64)
	_add(db, "block_hard_wood", "Gỗ Cứng", ItemDef.Type.BLOCK, Color(0.47, 0.36, 0.20), "🧱", "Khối gỗ cứng — vân nâu sẫm chắc chắn, chặt từ cây rừng rậm bằng rìu", true, 64)

	# ── Cà tím ───────────────────────────────────────────────────────────────
	_add(db, "eggplant_fruit", "Trái Cà Tím", ItemDef.Type.FOOD, Color(0.42, 0.14, 0.50), "🍆", "Trái cà tím — tím hoàng gia mộng nước, vỏ bóng mượt vệt sáng trắng xanh, đài hoa xanh ngả tím; ăn được hoặc chế biến", true, 16, 10)
	_add(db, "eggplant_slice", "Cà Tím Bổ Đôi", ItemDef.Type.FOOD, Color(0.94, 0.90, 0.78), "🍆", "Cà tím bổ đôi — ruột trắng kem sốp nhẹ, hạt vàng nâu quanh tâm, nguyên liệu nấu ăn", true, 32, 6)
	_add(db, "eggplant_seed", "Hạt Giống Cà Tím", ItemDef.Type.MATERIAL, Color(0.62, 0.46, 0.24), "🌱", "Túi hạt giống cà tím — gieo trên đất tơi xốp, lớn thành bụi cà tím cho trái mộng nước", true, 16)
	_add(db, "watermelon", "Trái Dưa Hấu", ItemDef.Type.FOOD, Color(0.22, 0.60, 0.28), "🍉", "Trái dưa hấu — quả cầu căng mọng vỏ xanh ngọc bích vằn xanh đen, vệt đất vàng ngà ở đáy; ăn được hoặc cắt lát", true, 16, 14)
	_add(db, "watermelon_slice", "Miếng Dưa Hấu", ItemDef.Type.FOOD, Color(0.88, 0.16, 0.20), "🍉", "Miếng dưa hấu tam giác — ruột đỏ tươi mộng nước, hạt đen tuyền, vỏ xanh sẫm viền cùi trắng ngà", true, 32, 6)
	_add(db, "watermelon_seed", "Hạt Giống Dưa Hấu", ItemDef.Type.MATERIAL, Color(0.30, 0.16, 0.08), "🌱", "Túi hạt giống dưa hấu — gieo trên đất tơi xốp, dây bò lớn thành thảm dưa cho quả căng tròn", true, 16)

	# ── Bí đỏ ────────────────────────────────────────────────────────────────
	_add(db, "pumpkin_slice", "Miếng Bí Đỏ", ItemDef.Type.FOOD, Color(0.95, 0.62, 0.16), "🎃", "Miếng bí đỏ — vỏ cam mỏng, thịt cam tươi mộng nước, lõi xơ vàng đan chéo cùng hạt bí ngà dẹt; ăn được hoặc nấu ăn", true, 32, 7)
	_add(db, "pumpkin_seed", "Hạt Giống Bí Đỏ", ItemDef.Type.MATERIAL, Color(0.55, 0.45, 0.30), "🌱", "Túi vải đay hạt giống bí đỏ — gieo trên đất tơi xốp, dây bò thô mộc cho quả cam cháy mùa thu", true, 16)
	_add(db, "jack_o_lantern", "Đèn Lồng Bí Đỏ", ItemDef.Type.BLOCK, Color(0.92, 0.55, 0.14), "🎃", "Đèn lồng bí đỏ — bí đã đục mắt/mũi/miệng hình tam giác zíc-zắc, nến voxel bên trong tỏa ánh lửa vàng đỏ; đặt trang trí", true, 64)

	# ── Cây cam ───────────────────────────────────────────────────────────────
	_add(db, "orange", "Quả Cam", ItemDef.Type.FOOD, Color(0.95, 0.55, 0.12), "🍊", "Quả cam chín — căng mọng vỏ cam rực vân lõm nhẹ, núm xanh ngả vàng; mọng nước, giàu vitamin, ăn trực tiếp hoặc lấy hạt trồng", true, 16, 8)
	_add(db, "orange_seed", "Hạt Giống Cam", ItemDef.Type.MATERIAL, Color(0.92, 0.58, 0.18), "🌱", "Túi hạt giống cam — gieo trên đất tơi xốp, lớn thành cây cam cho trái vàng rực", true, 16)

	# ── Bộ giáp sắt ───────────────────────────────────────────────────────────
	_add(db, "iron_helmet",     "Nón Sắt",     ItemDef.Type.ARMOR, Color(0.60, 0.62, 0.72), "⛑", "Nón sắt vững chắc — +1.5 giáp, +1 kháng sát thương chí mạng", false, 1, 0, 0, 1.5, ItemDef.ArmorSlot.HEAD, 200, 0.0, 1.0)
	_add(db, "iron_chestplate", "Giáp Sắt",    ItemDef.Type.ARMOR, Color(0.55, 0.57, 0.66), "⛨", "Áo giáp sắt — +4.5 giáp, găng tay sắt đã hợp vào thân", false, 1, 0, 0, 4.5, ItemDef.ArmorSlot.BODY, 260)
	_add(db, "iron_boots",      "Giày Sắt",    ItemDef.Type.ARMOR, Color(0.54, 0.56, 0.64), "👢", "Giày sắt — +1 giáp", false, 1, 0, 0, 1.0, ItemDef.ArmorSlot.FEET, 160)
	_add(db, "iron_leggings",   "Quần Sắt",    ItemDef.Type.ARMOR, Color(0.57, 0.59, 0.67), "🩳", "Quần sắt bảo vệ đôi chân — +1.5 giáp", false, 1, 0, 0, 1.5, ItemDef.ArmorSlot.LEGS, 170)

	# ── Trang sức & phụ kiện ─────────────────────────────────────────────────
	_add(db, "golden_ring",     "Nhẫn Vàng",   ItemDef.Type.ARMOR, Color(0.90, 0.72, 0.12), "💍", "Nhẫn vàng — tăng vận may ẩn (+2 luck), câu được đồ hiếm hơn", false, 1, 0, 0, 0.0, ItemDef.ArmorSlot.SUB, 0, 2.0)
	_add(db, "leather_backpack", "Balo Da Thú", ItemDef.Type.ARMOR, Color(0.45, 0.30, 0.18), "🎒", "Balo da thú chắc chắn — +4 slot kho đồ và +5% giới hạn tải", false, 1, 0, 0, 0.0, ItemDef.ArmorSlot.BACK, 0, 0.0, 0.0, 4, 1.05)

	# ── Cây dầu ───────────────────────────────────────────────────────────────

	return db

static func _add(db: Dictionary, id: String, name: String, type: int, color: Color, char: String,
				desc: String = "", stackable: bool = true, max_stack: int = 64,
				heal: int = 0, atk: int = 0, def_val: float = 0.0, armor_slot: int = -1,
				durability: int = 0, luck: float = 0.0, crit_resist: float = 0.0,
				slots_bonus: int = 0, weight_mult: float = 1.0) -> void:
	db[id] = ItemDef.new(id, name, type, color, char, desc, stackable, max_stack, heal, atk, def_val, armor_slot, durability, luck, crit_resist, slots_bonus, weight_mult)
	db[id].eat_time = EAT_TIMES.get(id, 3.0)
	db[id].weight = WEIGHTS.get(id, _default_weight(type))

## Trọng lượng riêng theo từng item (override mặc định theo loại).
const WEIGHTS: Dictionary = {
	"chest": 8.0, "crafting_table": 6.0, "furnace": 10.0, "twilight_gate": 20.0,
	"pickaxe": 4.0, "shovel": 4.0, "axe": 5.0, "hoe": 3.0,
	"iron_sword": 4.0, "iron_greatsword": 8.0, "iron_halberd": 9.0,
	"crossbow": 6.0, "fishing_rod": 2.0, "watermelon_cannon": 14.0,
	"pumpkin_mortar": 12.0, "leather_gloves": 1.5,
	"watermelon": 6.0, "pumpkin": 5.0, "jack_o_lantern": 5.0,
	"coconut": 2.0, "orange": 0.3, "eggplant_fruit": 0.8,
	"eggplant_slice": 0.3, "watermelon_slice": 0.4, "pumpkin_slice": 0.3,
	"eggplant_seed": 0.1, "watermelon_seed": 0.1, "pumpkin_seed": 0.1, "orange_seed": 0.1,
	"coconut_seed": 0.2, "taro_seed": 0.2, "seaweed_seed": 0.1, "seagrass_seed": 0.1,
	"carp": 1.0, "climbing_perch": 0.8, "red_tilapia": 1.2, "snakehead": 1.5,
	"flowerhorn": 1.4, "shrimp": 0.4, "raw_pork": 3.0, "taro": 0.6,
	"tractor": 40.0, "fishing_boat": 50.0, "rescue_helicopter": 55.0,
	"iron_helmet": 1.5, "iron_chestplate": 4.5, "iron_boots": 1.0,
	"iron_leggings": 1.8,
	"golden_ring": 0.1, "leather_backpack": 2.0,
}

static func _default_weight(type: int) -> float:
	match type:
		ItemDef.Type.BLOCK:    return 2.0
		ItemDef.Type.TOOL:     return 3.0
		ItemDef.Type.WEAPON:   return 4.0
		ItemDef.Type.ARMOR:    return 3.0
		ItemDef.Type.FOOD:     return 0.5
		ItemDef.Type.MATERIAL: return 1.0
	return 1.0

static func load_icon_2d(item_id: String) -> Texture2D:
	var path := "res://assets/icon_items/%s.png" % item_id
	if ResourceLoader.exists(path):
		return load(path)
	return null

# Helper: returns {tex, has_icon}. When has_icon==true, use neutral face bg.
static func try_load_icon(item_id: String) -> Dictionary:
	var tex := load_icon_2d(item_id)
	return { "tex": tex, "has_icon": tex != null }

const _NEUTRAL_FACE := Color(0.20, 0.15, 0.30, 0.4)
