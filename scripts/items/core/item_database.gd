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
	_add(db, "kiem",  "Kiếm",  ItemDef.Type.WEAPON, Color(0.75, 0.80, 0.90), "⚔",  "Tấn công nhanh, sát thương cao",  false, 1, 0, 10, 0)

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

	# ── Resource materials (named) ─────────────────────────────────────────
	_add(db, "bear_skin", "Bear Skin", ItemDef.Type.MATERIAL, Color(0.286, 0.192, 0.145), "RM", "Crafting material", true, 64)
	_add(db, "bone", "Bone", ItemDef.Type.MATERIAL, Color(0.420, 0.400, 0.427), "RM", "Crafting material", true, 64)
	_add(db, "clay", "Clay", ItemDef.Type.MATERIAL, Color(0.557, 0.357, 0.243), "RM", "Crafting material", true, 64)
	_add(db, "coal_ore", "Coal Ore", ItemDef.Type.MATERIAL, Color(0.141, 0.141, 0.137), "RM", "Crafting material", true, 64)
	_add(db, "copper_coins", "Copper Coins", ItemDef.Type.MATERIAL, Color(0.525, 0.302, 0.275), "RM", "Crafting material", true, 64)
	_add(db, "copper_ingot", "Copper Ingot", ItemDef.Type.MATERIAL, Color(0.475, 0.267, 0.231), "RM", "Crafting material", true, 64)
	_add(db, "copper_ore", "Copper Ore", ItemDef.Type.MATERIAL, Color(0.380, 0.290, 0.180), "RM", "Crafting material", true, 64)
	_add(db, "dark_wood", "Dark Wood", ItemDef.Type.MATERIAL, Color(0.310, 0.176, 0.125), "RM", "Crafting material", true, 64)
	_add(db, "dark_wooden_planks", "Dark Wooden Planks", ItemDef.Type.MATERIAL, Color(0.400, 0.235, 0.157), "RM", "Crafting material", true, 64)
	_add(db, "diamond", "Diamond", ItemDef.Type.MATERIAL, Color(0.267, 0.373, 0.467), "RM", "Crafting material", true, 64)
	_add(db, "egg", "Egg", ItemDef.Type.MATERIAL, Color(0.631, 0.573, 0.514), "RM", "Crafting material", true, 64)
	_add(db, "pearl_elemental", "Elemental Pearl", ItemDef.Type.MATERIAL, Color(0.341, 0.298, 0.290), "RM", "Crafting material", true, 64)
	_add(db, "feather", "Feather", ItemDef.Type.MATERIAL, Color(0.478, 0.459, 0.490), "RM", "Crafting material", true, 64)
	_add(db, "gold_coins", "Gold Coins", ItemDef.Type.MATERIAL, Color(0.651, 0.369, 0.169), "RM", "Crafting material", true, 64)
	_add(db, "gold_ingot", "Gold Ingot", ItemDef.Type.MATERIAL, Color(0.596, 0.357, 0.196), "RM", "Crafting material", true, 64)
	_add(db, "gold_ore", "Gold Ore", ItemDef.Type.MATERIAL, Color(0.369, 0.329, 0.290), "RM", "Crafting material", true, 64)
	_add(db, "copper_high_ingot", "Copper High Ingot", ItemDef.Type.MATERIAL, Color(0.659, 0.486, 0.365), "RM", "Crafting material", true, 64)
	_add(db, "gold_high_ingot", "Gold High Ingot", ItemDef.Type.MATERIAL, Color(0.573, 0.482, 0.408), "RM", "Crafting material", true, 64)
	_add(db, "copper_high_grade", "Copper High Grade", ItemDef.Type.MATERIAL, Color(0.486, 0.263, 0.220), "RM", "Crafting material", true, 64)
	_add(db, "gold_high_grade", "Gold High Grade", ItemDef.Type.MATERIAL, Color(0.620, 0.349, 0.165), "RM", "Crafting material", true, 64)
	_add(db, "iron_high_grade", "Iron High Grade", ItemDef.Type.MATERIAL, Color(0.345, 0.388, 0.475), "RM", "Crafting material", true, 64)
	_add(db, "red_iron_high_grade", "Red Iron High Grade", ItemDef.Type.MATERIAL, Color(0.243, 0.086, 0.106), "RM", "Crafting material", true, 64)
	_add(db, "steel_high_grade", "Steel High Grade", ItemDef.Type.MATERIAL, Color(0.200, 0.204, 0.216), "RM", "Crafting material", true, 64)
	_add(db, "iron_high_ingot", "Iron High Ingot", ItemDef.Type.MATERIAL, Color(0.557, 0.510, 0.608), "RM", "Crafting material", true, 64)
	_add(db, "red_iron_high_ingot", "Red Iron High Ingot", ItemDef.Type.MATERIAL, Color(0.412, 0.184, 0.157), "RM", "Crafting material", true, 64)
	_add(db, "steel_high_ingot", "Steel High Ingot", ItemDef.Type.MATERIAL, Color(0.275, 0.275, 0.314), "RM", "Crafting material", true, 64)
	_add(db, "iron_coins", "Iron Coins", ItemDef.Type.MATERIAL, Color(0.506, 0.494, 0.569), "RM", "Crafting material", true, 64)
	_add(db, "iron_ingot", "Iron Ingot", ItemDef.Type.MATERIAL, Color(0.357, 0.357, 0.404), "RM", "Crafting material", true, 64)
	_add(db, "iron_ore", "Iron Ore", ItemDef.Type.MATERIAL, Color(0.361, 0.306, 0.263), "RM", "Crafting material", true, 64)
	_add(db, "magic_wood", "Magic Wood", ItemDef.Type.MATERIAL, Color(0.345, 0.298, 0.247), "RM", "Crafting material", true, 64)
	_add(db, "magic_wooden_planks", "Magic Wooden Planks", ItemDef.Type.MATERIAL, Color(0.361, 0.298, 0.235), "RM", "Crafting material", true, 64)
	_add(db, "normal_wood", "Normal Wood", ItemDef.Type.MATERIAL, Color(0.396, 0.282, 0.200), "RM", "Crafting material", true, 64)
	_add(db, "normal_wooden_planks", "Normal Wooden Planks", ItemDef.Type.MATERIAL, Color(0.553, 0.380, 0.259), "RM", "Crafting material", true, 64)
	_add(db, "paper", "Paper", ItemDef.Type.MATERIAL, Color(0.647, 0.655, 0.659), "RM", "Crafting material", true, 64)
	_add(db, "sapphire_purple", "Purple Sapphire", ItemDef.Type.MATERIAL, Color(0.416, 0.192, 0.510), "RM", "Crafting material", true, 64)
	_add(db, "red_iron_ingot", "Red Iron Ingot", ItemDef.Type.MATERIAL, Color(0.275, 0.090, 0.114), "RM", "Crafting material", true, 64)
	_add(db, "red_iron_ore", "Red Iron Ore", ItemDef.Type.MATERIAL, Color(0.400, 0.271, 0.259), "RM", "Crafting material", true, 64)
	_add(db, "ruby", "Ruby", ItemDef.Type.MATERIAL, Color(0.569, 0.173, 0.184), "RM", "Crafting material", true, 64)
	_add(db, "steel_ingot", "Steel Ingot", ItemDef.Type.MATERIAL, Color(0.204, 0.196, 0.208), "RM", "Crafting material", true, 64)
	_add(db, "wolf_skin", "Wolf Skin", ItemDef.Type.MATERIAL, Color(0.169, 0.173, 0.200), "RM", "Crafting material", true, 64)
	_add(db, "wooden_stick", "Wooden Stick", ItemDef.Type.MATERIAL, Color(0.235, 0.169, 0.141), "RM", "Crafting material", true, 64)

	# ── New materials ───────────────────────────────────────────────
	_add(db, "bauxite_ore", "Bauxite Ore", ItemDef.Type.MATERIAL, Color(0.55, 0.35, 0.25), "RM", "Crafting material", true, 64)
	_add(db, "bauxite_ingot", "Bauxite Ingot", ItemDef.Type.MATERIAL, Color(0.65, 0.55, 0.50), "RM", "Crafting material", true, 64)
	_add(db, "bauxite_high_ingot", "Bauxite High Ingot", ItemDef.Type.MATERIAL, Color(0.75, 0.65, 0.60), "RM", "Crafting material", true, 64)
	_add(db, "bauxite_high_grade", "Bauxite High Grade", ItemDef.Type.MATERIAL, Color(0.60, 0.40, 0.30), "RM", "Crafting material", true, 64)
	_add(db, "dark_metal_high_ingot", "Dark Metal High Ingot", ItemDef.Type.MATERIAL, Color(0.25, 0.25, 0.28), "RM", "Crafting material", true, 64)
	_add(db, "dark_metal_high_grade", "Dark Metal High Grade", ItemDef.Type.MATERIAL, Color(0.18, 0.18, 0.20), "RM", "Crafting material", true, 64)
	_add(db, "glow_iron_ore", "Glow Iron Ore", ItemDef.Type.MATERIAL, Color(0.30, 0.35, 0.25), "RM", "Crafting material", true, 64)
	_add(db, "glow_iron_ingot", "Glow Iron Ingot", ItemDef.Type.MATERIAL, Color(0.35, 0.70, 0.35), "RM", "Crafting material", true, 64)
	_add(db, "glow_iron_high_grade", "Glow Iron High Grade", ItemDef.Type.MATERIAL, Color(0.30, 0.75, 0.30), "RM", "Crafting material", true, 64)
	_add(db, "magic_metal_high_ingot", "Magic Metal High Ingot", ItemDef.Type.MATERIAL, Color(0.55, 0.35, 0.65), "RM", "Crafting material", true, 64)
	_add(db, "titan_ingot", "Titan Ingot", ItemDef.Type.MATERIAL, Color(0.55, 0.60, 0.70), "RM", "Crafting material", true, 64)
	_add(db, "titan_high_ingot", "Titan High Ingot", ItemDef.Type.MATERIAL, Color(0.70, 0.75, 0.85), "RM", "Crafting material", true, 64)
	_add(db, "titan_high_grade", "Titan High Grade", ItemDef.Type.MATERIAL, Color(0.50, 0.55, 0.65), "RM", "Crafting material", true, 64)
	_add(db, "diamond_red", "Red Diamond", ItemDef.Type.MATERIAL, Color(0.90, 0.40, 0.35), "RM", "Crafting material", true, 64)
	_add(db, "ruby_twilight", "Twilight Ruby", ItemDef.Type.MATERIAL, Color(0.70, 0.25, 0.50), "RM", "Crafting material", true, 64)
	_add(db, "sapphire_blue", "Blue Sapphire", ItemDef.Type.MATERIAL, Color(0.40, 0.60, 0.90), "RM", "Crafting material", true, 64)
	_add(db, "sapphire_red", "Red Sapphire", ItemDef.Type.MATERIAL, Color(0.85, 0.35, 0.35), "RM", "Crafting material", true, 64)
	_add(db, "bull_skin", "Bull Skin", ItemDef.Type.MATERIAL, Color(0.45, 0.30, 0.20), "RM", "Crafting material", true, 64)
	_add(db, "deer_skin", "Deer Skin", ItemDef.Type.MATERIAL, Color(0.55, 0.42, 0.30), "RM", "Crafting material", true, 64)
	_add(db, "fire_fox_skin", "Fire Fox Skin", ItemDef.Type.MATERIAL, Color(0.75, 0.35, 0.15), "RM", "Crafting material", true, 64)
	_add(db, "frost_ermine_skin", "Frost Ermine Skin", ItemDef.Type.MATERIAL, Color(0.85, 0.85, 0.88), "RM", "Crafting material", true, 64)
	_add(db, "panther_skin", "Panther Skin", ItemDef.Type.MATERIAL, Color(0.15, 0.15, 0.18), "RM", "Crafting material", true, 64)
	_add(db, "rhino_skin", "Rhino Skin", ItemDef.Type.MATERIAL, Color(0.30, 0.28, 0.25), "RM", "Crafting material", true, 64)
	_add(db, "snow_rat_skin", "Snow Rat Skin", ItemDef.Type.MATERIAL, Color(0.65, 0.65, 0.70), "RM", "Crafting material", true, 64)
	_add(db, "tiger_skin", "Tiger Skin", ItemDef.Type.MATERIAL, Color(0.75, 0.50, 0.20), "RM", "Crafting material", true, 64)
	_add(db, "twilight_essence", "Twilight Essence", ItemDef.Type.MATERIAL, Color(0.55, 0.35, 0.75), "RM", "Crafting material", true, 64)
	_add(db, "twilight_powder", "Twilight Powder", ItemDef.Type.MATERIAL, Color(0.35, 0.20, 0.45), "RM", "Crafting material", true, 64)

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
		"bear_skin": return "res://assets/icon_items/resource_mats/bear_skin.png"
		"bone": return "res://assets/icon_items/resource_mats/bone.png"
		"clay": return "res://assets/icon_items/resource_mats/clay.png"
		"coal_ore": return "res://assets/icon_items/resource_mats/coal_ore.png"
		"copper_coins": return "res://assets/icon_items/resource_mats/copper_coins.png"
		"copper_ingot": return "res://assets/icon_items/resource_mats/copper_ingot.png"
		"copper_ore": return "res://assets/icon_items/resource_mats/copper_ore.png"
		"dark_wood": return "res://assets/icon_items/resource_mats/dark_wood.png"
		"dark_wooden_planks": return "res://assets/icon_items/resource_mats/dark_wooden_planks.png"
		"diamond": return "res://assets/icon_items/resource_mats/diamond.png"
		"egg": return "res://assets/icon_items/resource_mats/egg.png"
		"pearl_elemental": return "res://assets/icon_items/resource_mats/pearl_elemental.png"
		"feather": return "res://assets/icon_items/resource_mats/feather.png"
		"gold_coins": return "res://assets/icon_items/resource_mats/gold_coins.png"
		"gold_ingot": return "res://assets/icon_items/resource_mats/gold_ingot.png"
		"gold_ore": return "res://assets/icon_items/resource_mats/gold_ore.png"
		"copper_high_ingot": return "res://assets/icon_items/resource_mats/copper_high_ingot.png"
		"gold_high_ingot": return "res://assets/icon_items/resource_mats/gold_high_ingot.png"
		"copper_high_grade": return "res://assets/icon_items/resource_mats/copper_high_grade.png"
		"gold_high_grade": return "res://assets/icon_items/resource_mats/gold_high_grade.png"
		"iron_high_grade": return "res://assets/icon_items/resource_mats/iron_high_grade.png"
		"red_iron_high_grade": return "res://assets/icon_items/resource_mats/red_iron_high_grade.png"
		"steel_high_grade": return "res://assets/icon_items/resource_mats/steel_high_grade.png"
		"iron_high_ingot": return "res://assets/icon_items/resource_mats/iron_high_ingot.png"
		"red_iron_high_ingot": return "res://assets/icon_items/resource_mats/red_iron_high_ingot.png"
		"steel_high_ingot": return "res://assets/icon_items/resource_mats/steel_high_ingot.png"
		"iron_coins": return "res://assets/icon_items/resource_mats/iron_coins.png"
		"iron_ingot": return "res://assets/icon_items/resource_mats/iron_ingot.png"
		"iron_ore": return "res://assets/icon_items/resource_mats/iron_ore.png"
		"magic_wood": return "res://assets/icon_items/resource_mats/magic_wood.png"
		"magic_wooden_planks": return "res://assets/icon_items/resource_mats/magic_wooden_planks.png"
		"normal_wood": return "res://assets/icon_items/resource_mats/normal_wood.png"
		"normal_wooden_planks": return "res://assets/icon_items/resource_mats/normal_wooden_planks.png"
		"paper": return "res://assets/icon_items/resource_mats/paper.png"
		"sapphire_purple": return "res://assets/icon_items/resource_mats/sapphire_purple.png"
		"red_iron_ingot": return "res://assets/icon_items/resource_mats/red_iron_ingot.png"
		"red_iron_ore": return "res://assets/icon_items/resource_mats/red_iron_ore.png"
		"ruby": return "res://assets/icon_items/resource_mats/ruby.png"
		"steel_ingot": return "res://assets/icon_items/resource_mats/steel_ingot.png"
		"wolf_skin": return "res://assets/icon_items/resource_mats/wolf_skin.png"
		"wooden_stick": return "res://assets/icon_items/resource_mats/wooden_stick.png"
		"bauxite_ore": return "res://assets/icon_items/resource_mats/bauxite_ore.png"
		"bauxite_ingot": return "res://assets/icon_items/resource_mats/bauxite_ingot.png"
		"bauxite_high_ingot": return "res://assets/icon_items/resource_mats/bauxite_high_ingot.png"
		"bauxite_high_grade": return "res://assets/icon_items/resource_mats/bauxite_high_grade.png"
		"dark_metal_high_ingot": return "res://assets/icon_items/resource_mats/dark_metal_high_ingot.png"
		"dark_metal_high_grade": return "res://assets/icon_items/resource_mats/dark_metal_high_grade.png"
		"glow_iron_ore": return "res://assets/icon_items/resource_mats/glow_iron_ore.png"
		"glow_iron_ingot": return "res://assets/icon_items/resource_mats/glow_iron_ingot.png"
		"glow_iron_high_grade": return "res://assets/icon_items/resource_mats/glow_iron_high_grade.png"
		"magic_metal_high_ingot": return "res://assets/icon_items/resource_mats/magic_metal_high_ingot.png"
		"titan_ingot": return "res://assets/icon_items/resource_mats/titan_ingot.png"
		"titan_high_ingot": return "res://assets/icon_items/resource_mats/titan_high_ingot.png"
		"titan_high_grade": return "res://assets/icon_items/resource_mats/titan_high_grade.png"
		"diamond_red": return "res://assets/icon_items/resource_mats/diamond_red.png"
		"ruby_twilight": return "res://assets/icon_items/resource_mats/ruby_twilight.png"
		"sapphire_blue": return "res://assets/icon_items/resource_mats/sapphire_blue.png"
		"sapphire_red": return "res://assets/icon_items/resource_mats/sapphire_red.png"
		"bull_skin": return "res://assets/icon_items/resource_mats/bull_skin.png"
		"deer_skin": return "res://assets/icon_items/resource_mats/deer_skin.png"
		"fire_fox_skin": return "res://assets/icon_items/resource_mats/fire_fox_skin.png"
		"frost_ermine_skin": return "res://assets/icon_items/resource_mats/Frost Ermine_skin.png"
		"panther_skin": return "res://assets/icon_items/resource_mats/panther_skin.png"
		"rhino_skin": return "res://assets/icon_items/resource_mats/rhino_skin.png"
		"snow_rat_skin": return "res://assets/icon_items/resource_mats/snow_rat_skin.png"
		"tiger_skin": return "res://assets/icon_items/resource_mats/tiger_skin.png"
		"twilight_essence": return "res://assets/icon_items/resource_mats/twilight_essence.png"
		"twilight_powder": return "res://assets/icon_items/resource_mats/twilight_powder.png"

	return ""
