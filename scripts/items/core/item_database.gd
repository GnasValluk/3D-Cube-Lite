class_name ItemDatabase
extends RefCounted

static var items_db: Dictionary = {}

static func ensure_db() -> void:
	if items_db.is_empty():
		items_db = create_item_db()

static func create_item_db() -> Dictionary:
	var db: Dictionary = {}
	_add(db, "chest",         "Rương đồ",     ItemDef.Type.BLOCK,  Color(0.50, 0.32, 0.10), "C",  "Rương chứa đồ",          false, 1)
	_add(db, "twilight_gate", "Cổng Twilight", ItemDef.Type.TOOL,   Color(0.10, 0.50, 0.45), "T",  "Đặt cổng Twilight ra thế giới", false, 1)

	# ── Công cụ ────────────────────────────────────────────────────────────────
	_add(db, "cup",   "Cúp",   ItemDef.Type.TOOL,   Color(0.60, 0.55, 0.50), "⛏", "Đào đất, khai thác tài nguyên",   false, 1, 0, 8,  0)
	_add(db, "xeng",  "Xẻng",  ItemDef.Type.TOOL,   Color(0.70, 0.65, 0.55), "🔨", "Xúc đất, di chuyển vật liệu",     false, 1, 0, 6,  0)
	_add(db, "riu",   "Rìu",   ItemDef.Type.TOOL,   Color(0.50, 0.45, 0.40), "🪓", "Chặt cây, phá gỗ",                false, 1, 0, 14, 0)

	# ── Vũ khí ─────────────────────────────────────────────────────────────────
	_add(db, "kiem",    "Kiếm",       ItemDef.Type.WEAPON, Color(0.75, 0.80, 0.90), "⚔", "Tấn công nhanh, sát thương cao",  false, 1, 0, 10, 0)
	_add(db, "dai_kiem","Đại Kiếm",   ItemDef.Type.WEAPON, Color(0.40, 0.45, 0.60), "🗡", "Chém mạnh một nhát, sát thương cực cao", false, 1, 0, 16, 0)
	_add(db, "gang_tay_da_thu","Găng Tay Da Thú", ItemDef.Type.WEAPON, Color(0.55, 0.32, 0.14), "🥊", "Đấm nhanh liên hoàn, sát thương thấp", false, 1, 0, 7, 0)
	_add(db, "no",          "Nỏ",          ItemDef.Type.WEAPON, Color(0.55, 0.35, 0.18), "🏹", "Nỏ — bắn tên từ xa, giữ chuột để nạp và tăng sát thương", false, 1, 0, 8, 0)
	_add(db, "phao_dua_hau","Pháo Dưa Hấu Hạt Nhân", ItemDef.Type.WEAPON, Color(0.20, 0.55, 0.15), "🍉", "Bắn đạn hạt nhân dưa hấu phát nổ gây sát thương vùng. Cần đạn hạt nhân dưa hấu!", false, 1, 0, 12, 0)

	# ── Câu cá ────────────────────────────────────────────────────────────────
	_add(db, "can_cau", "Cần câu", ItemDef.Type.TOOL, Color(0.55, 0.40, 0.25), "🎣", "Cần câu cá — dùng để câu cá ở vùng nước", false, 1, 0, 0, 0)

	# ── Cá (thức ăn) ──────────────────────────────────────────────────────────
	_add(db, "ca_chep", "Carp", ItemDef.Type.FOOD, Color(0.95, 0.70, 0.10), "🐟", "Freshwater carp — rich, firm flesh", true, 16, 30)
	_add(db, "ca_ro",   "Climbing Perch", ItemDef.Type.FOOD, Color(0.30, 0.30, 0.30), "🐟", "Climbing perch — sweet white meat", true, 16, 20)
	_add(db, "ca_dieu_hong", "Red Tilapia", ItemDef.Type.FOOD, Color(0.88, 0.55, 0.45), "🐟", "Red tilapia — firm, mild flavour", true, 16, 35)
	_add(db, "ca_loc", "Snakehead", ItemDef.Type.FOOD, Color(0.30, 0.25, 0.15), "🐟", "Snakehead — dense, savoury fillet", true, 16, 45)
	_add(db, "ca_la_han", "Flowerhorn", ItemDef.Type.FOOD, Color(0.92, 0.25, 0.15), "🐟", "Flowerhorn — rich, flavourful meat", true, 16, 55)
	_add(db, "tom", "Freshwater Shrimp", ItemDef.Type.FOOD, Color(0.85, 0.35, 0.20), "🦐", "Freshwater shrimp — sweet, delicate meat", true, 16, 8)

	# ── Hoa quả & rau củ ──────────────────────────────────────────────────────
	_add(db, "apple_green", "Green Apple", ItemDef.Type.FOOD, Color(0.28,0.65,0.20), "🍎", "Green apple — crisp and sour", true, 16, 12)
	_add(db, "banana_peeled", "Banana", ItemDef.Type.FOOD, Color(0.94,0.71,0.24), "🍌", "Banana — soft and sweet", true, 16, 10)
	_add(db, "blueberry", "Blueberry", ItemDef.Type.FOOD, Color(0.19,0.37,0.63), "🫐", "Blueberry — tiny antioxidant burst", true, 16, 5)
	_add(db, "cabbage", "Cabbage", ItemDef.Type.FOOD, Color(0.13,0.50,0.19), "🥬", "Cabbage — crunchy leaf vegetable", true, 16, 8)
	_add(db, "carrot", "Carrot", ItemDef.Type.FOOD, Color(0.60,0.22,0.25), "🥕", "Carrot — sweet root vegetable", true, 16, 6)
	_add(db, "cauliflower", "Cauliflower", ItemDef.Type.FOOD, Color(0.62,0.72,0.83), "🥦", "Cauliflower — mild and versatile", true, 16, 10)
	_add(db, "cherry", "Cherry", ItemDef.Type.FOOD, Color(0.68,0.16,0.29), "🍒", "Cherry — small and juicy", true, 16, 6)
	_add(db, "chili_red", "Chili Pepper", ItemDef.Type.FOOD, Color(0.68,0.16,0.29), "🌶", "Chili pepper — fiery and intense", true, 16, 4)
	_add(db, "corn", "Corn", ItemDef.Type.FOOD, Color(0.83,0.52,0.21), "🌽", "Corn — sweet golden kernels", true, 16, 12)
	_add(db, "cucumber", "Cucumber", ItemDef.Type.FOOD, Color(0.55,0.78,0.27), "🥒", "Cucumber — cool and refreshing", true, 16, 8)
	_add(db, "eggplant", "Eggplant", ItemDef.Type.FOOD, Color(0.67,0.33,0.66), "🍆", "Eggplant — hearty purple vegetable", true, 16, 8)
	_add(db, "grapes_black", "Black Grapes", ItemDef.Type.FOOD, Color(0.67,0.33,0.66), "🍇", "Black grapes — rich and sweet", true, 16, 8)
	_add(db, "leek", "Leek", ItemDef.Type.FOOD, Color(0.28,0.65,0.20), "🧅", "Leek — mild onion flavour", true, 16, 6)
	_add(db, "lemon", "Lemon", ItemDef.Type.FOOD, Color(0.94,1.00,1.00), "🍋", "Lemon — bright and tangy", true, 16, 4)
	_add(db, "onion", "Onion", ItemDef.Type.FOOD, Color(0.83,0.52,0.21), "🧅", "Onion — layered and pungent", true, 16, 6)
	_add(db, "orange", "Orange", ItemDef.Type.FOOD, Color(0.91,0.41,0.21), "🍊", "Orange — citrus and sweet", true, 16, 10)
	_add(db, "paprika_red", "Red Paprika", ItemDef.Type.FOOD, Color(0.90,0.36,0.36), "🫑", "Red paprika — sweet bell pepper", true, 16, 6)
	_add(db, "pear", "Pear", ItemDef.Type.FOOD, Color(0.72,0.42,0.23), "🍐", "Pear — soft and buttery", true, 16, 10)
	_add(db, "pineapple", "Pineapple", ItemDef.Type.FOOD, Color(0.83,0.52,0.21), "🍍", "Pineapple — tropical and tangy", true, 16, 15)
	_add(db, "plum", "Plum", ItemDef.Type.FOOD, Color(0.52,0.30,0.60), "🍑", "Plum — sweet stone fruit", true, 16, 6)
	_add(db, "potato", "Potato", ItemDef.Type.FOOD, Color(0.60,0.34,0.24), "🥔", "Potato — starchy and filling", true, 16, 8)
	_add(db, "pumpkin", "Pumpkin", ItemDef.Type.FOOD, Color(0.91,0.41,0.21), "🎃", "Pumpkin — hearty winter squash", true, 16, 14)
	_add(db, "raspberry", "Raspberry", ItemDef.Type.FOOD, Color(0.90,0.36,0.36), "🍓", "Raspberry — tart summer berry", true, 16, 4)
	_add(db, "strawberry", "Strawberry", ItemDef.Type.FOOD, Color(0.90,0.36,0.36), "🍓", "Strawberry — sweet and aromatic", true, 16, 6)
	_add(db, "tomato", "Tomato", ItemDef.Type.FOOD, Color(0.80,0.21,0.26), "🍅", "Tomato — juicy red fruit", true, 16, 8)
	_add(db, "watermelon", "Watermelon", ItemDef.Type.FOOD, Color(0.55,0.78,0.27), "🍉", "Watermelon — refreshing and sweet", true, 16, 16)

	# ── Vật phẩm từ prop ─────────────────────────────────────────────────────
	_add(db, "mon_ngot", "Môn ngọt (Taro)", ItemDef.Type.FOOD, Color(0.25, 0.50, 0.15), "🌿", "Củ môn ngọt — có thể nấu ăn", true, 16, 12)
	_add(db, "rong_nhiet_doi", "Rong nhiệt đới", ItemDef.Type.MATERIAL, Color(0.08, 0.55, 0.10), "🌊", "Rong nhiệt đới — nguyên liệu chế tạo", true, 32)

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

	# Dark Metal (Kim loại tối) — chỉ có dạng tinh luyện cao
	_add(db, "dark_metal_high_ingot",   "Dark Metal High Ingot",   ItemDef.Type.MATERIAL, Color(0.25, 0.25, 0.28), "RM", "Thỏi kim loại tối tinh luyện — ma thuật", true, 64)
	_add(db, "dark_metal_purified_ingot","Dark Metal Purified Ingot",ItemDef.Type.MATERIAL, Color(0.30, 0.20, 0.45), "RM", "Thỏi kim loại tối tinh khiết — hào quang tím", true, 64)

	_add(db, "mui_ten", "Mũi Tên", ItemDef.Type.MATERIAL, Color(0.60, 0.50, 0.35), "🪶", "Đạn cho nỏ — tiêu hao khi bắn", true, 64)
	_add(db, "dan_hat_nhan_dua_hau", "Đạn Hạt Nhân Dưa Hấu", ItemDef.Type.MATERIAL, Color(0.18, 0.50, 0.12), "☢", "Đạn cho pháo dưa hấu hạt nhân — tiêu hao khi bắn", true, 32)
	_add(db, "phao_coi_bi_do", "Pháo Cối Bí Đỏ", ItemDef.Type.WEAPON, Color(0.80, 0.50, 0.15), "🎃", "Pháo cối bí đỏ — bắn đạn bí đỏ theo đường parabal, gây sát thương vùng + để lại bãi lầy làm chậm. Cần bí đỏ!", false, 1, 0, 12, 0)

	# ── Khối (đào từ thế giới) ─────────────────────────────────────────────────
	_add(db, "block_grass",       "Cỏ",        ItemDef.Type.BLOCK, Color(0.22, 0.58, 0.14), "🧱", "Khối cỏ",           true, 64)
	_add(db, "block_dark_grass",  "Cỏ Tối",    ItemDef.Type.BLOCK, Color(0.14, 0.40, 0.08), "🧱", "Khối cỏ tối",       true, 64)
	_add(db, "block_sand",        "Cát",       ItemDef.Type.BLOCK, Color(0.92, 0.78, 0.32), "🧱", "Khối cát",          true, 64)
	_add(db, "block_dirt",        "Đất",       ItemDef.Type.BLOCK, Color(0.42, 0.22, 0.08), "🧱", "Khối đất",          true, 64)
	_add(db, "block_silt",        "Phù Sa",    ItemDef.Type.BLOCK, Color(0.16, 0.15, 0.13), "🧱", "Khối phù sa",       true, 64)
	_add(db, "block_stone",       "Đá",        ItemDef.Type.BLOCK, Color(0.42, 0.42, 0.46), "🧱", "Khối đá",           true, 64)
	_add(db, "block_dark_dirt",   "Đất Tối",   ItemDef.Type.BLOCK, Color(0.28, 0.16, 0.06), "🧱", "Khối đất tối",      true, 64)
	_add(db, "block_sand_deep",   "Cát Sâu",   ItemDef.Type.BLOCK, Color(0.80, 0.66, 0.28), "🧱", "Khối cát sâu",      true, 64)
	_add(db, "block_trail",       "Đường Mòn", ItemDef.Type.BLOCK, Color(0.76, 0.58, 0.22), "🧱", "Khối đường mòn",    true, 64)
	_add(db, "block_ocean_floor", "Đáy Biển",  ItemDef.Type.BLOCK, Color(0.22, 0.28, 0.32), "🧱", "Khối đáy biển",     true, 64)
	_add(db, "block_ocean_sand",  "Cát Biển",  ItemDef.Type.BLOCK, Color(0.86, 0.78, 0.52), "🧱", "Khối cát biển",     true, 64)
	_add(db, "block_muddy_sand",  "Cát Bùn",   ItemDef.Type.BLOCK, Color(0.54, 0.46, 0.22), "🧱", "Khối cát bùn",      true, 64)
	_add(db, "block_sediment",    "Trầm Tích", ItemDef.Type.BLOCK, Color(0.50, 0.20, 0.10), "🧱", "Khối trầm tích",    true, 64)
	_add(db, "block_ocean_gravel","Sỏi Biển",  ItemDef.Type.BLOCK, Color(0.35, 0.30, 0.25), "🧱", "Khối sỏi biển",     true, 64)
	_add(db, "block_ocean_mud",   "Bùn Biển",  ItemDef.Type.BLOCK, Color(0.16, 0.20, 0.22), "🧱", "Khối bùn biển",     true, 64)

	return db

static func _add(db: Dictionary, id: String, name: String, type: int, color: Color, char: String,
				desc: String = "", stackable: bool = true, max_stack: int = 64,
				heal: int = 0, atk: int = 0, def_val: int = 0, armor_slot: int = -1) -> void:
	db[id] = ItemDef.new(id, name, type, color, char, desc, stackable, max_stack, heal, atk, def_val, armor_slot)

static func get_icon_2d_path(item_id: String) -> String:
	match item_id:
		"apple_green": return "res://assets/icon_items/frutti/Apple_Green.png"
		"banana_peeled": return "res://assets/icon_items/frutti/Banana_Peeled.png"
		"blueberry": return "res://assets/icon_items/frutti/Blueberry.png"
		"cabbage": return "res://assets/icon_items/frutti/Cabbage.png"
		"carrot": return "res://assets/icon_items/frutti/Carrot.png"
		"cauliflower": return "res://assets/icon_items/frutti/Cauliflower.png"
		"cherry": return "res://assets/icon_items/frutti/Cherry.png"
		"chili_red": return "res://assets/icon_items/frutti/Chili_Red.png"
		"corn": return "res://assets/icon_items/frutti/Corn.png"
		"cucumber": return "res://assets/icon_items/frutti/Cucumber.png"
		"eggplant": return "res://assets/icon_items/frutti/Eggplant.png"
		"grapes_black": return "res://assets/icon_items/frutti/Grapes_Black.png"
		"leek": return "res://assets/icon_items/frutti/Leek.png"
		"lemon": return "res://assets/icon_items/frutti/Lemon.png"
		"onion": return "res://assets/icon_items/frutti/Onion.png"
		"orange": return "res://assets/icon_items/frutti/Orange.png"
		"paprika_red": return "res://assets/icon_items/frutti/Paprika_Red.png"
		"pear": return "res://assets/icon_items/frutti/Pear.png"
		"pineapple": return "res://assets/icon_items/frutti/Pineapple.png"
		"plum": return "res://assets/icon_items/frutti/Plum.png"
		"potato": return "res://assets/icon_items/frutti/Potato.png"
		"pumpkin": return "res://assets/icon_items/frutti/Pumpkin.png"
		"raspberry": return "res://assets/icon_items/frutti/Raspberry.png"
		"strawberry": return "res://assets/icon_items/frutti/Strawberry.png"
		"tomato": return "res://assets/icon_items/frutti/Tomato.png"
		"watermelon": return "res://assets/icon_items/frutti/Watermelon.png"
		"phao_coi_bi_do": return "res://assets/icon_items/frutti/Pumpkin.png"

	return ""

static func load_icon_2d(item_id: String) -> Texture2D:
	var path := get_icon_2d_path(item_id)
	if path.is_empty():
		return null
	return load(path) as Texture2D
