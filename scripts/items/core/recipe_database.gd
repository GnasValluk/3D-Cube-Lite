## recipe_database.gd — Hệ thống công thức chế tạo (không theo hình dạng).
## Recipe = { "id", "name", "result", "count", "ingredients": {item_id: số lượng}, "category" }.
## Ghép khớp dựa trên lưới chế tạo 3x3 (đếm nguyên liệu, không cần đúng ô).
class_name RecipeDatabase
extends RefCounted

static var recipes: Array[Dictionary] = []
static var _built: bool = false

const CAT_STRUCTURES: String = "Công Trình"
const CAT_TOOLS: String = "Công Cụ"
const CAT_MATERIALS: String = "Nguyên Liệu"

static func ensure() -> void:
	if _built:
		return
	_built = true
	recipes = [
		{
			"id": "fishing_boat",
			"name": "Thuyền Đánh Cá",
			"result": "fishing_boat",
			"count": 1,
			"ingredients": { "palm_wood": 6, "coconut": 2, "tropical_seaweed": 2 },
			"category": CAT_STRUCTURES,
			"desc": "Thuyền gỗ dừa — đặt xuống nước, F để lên lái, câu cá ngay trên thuyền.",
		},
		{
			"id": "fishing_rod",
			"name": "Cần Câu",
			"result": "fishing_rod",
			"count": 1,
			"ingredients": { "palm_wood": 3, "tropical_seaweed": 2 },
			"category": CAT_TOOLS,
			"desc": "Cần câu cá — chế từ gỗ dừa và rong biển.",
		},
		{
			"id": "water_bucket",
			"name": "Xô Nước",
			"result": "water_bucket",
			"count": 1,
			"ingredients": { "iron_ingot": 2, "palm_wood": 1 },
			"category": CAT_TOOLS,
			"desc": "Xô đựng nước — đặt khối nước tại vị trí chỉ định.",
		},
		{
			"id": "block_stone_qtr",
			"name": "Đá Tư",
			"result": "block_stone_qtr",
			"count": 4,
			"ingredients": { "block_stone": 1 },
			"category": CAT_MATERIALS,
			"desc": "Cắt 1 khối đá thành 4 miếng ¼ — làm bậc, trang trí.",
		},
		{
			"id": "block_stone_eighth",
			"name": "Đá Vụn",
			"result": "block_stone_eighth",
			"count": 8,
			"ingredients": { "block_stone": 1 },
			"category": CAT_MATERIALS,
			"desc": "Cắt 1 khối đá thành 8 miếng ⅛ — tấm mỏng.",
		},
		{
			"id": "block_stone_thin",
			"name": "Đá Phiến",
			"result": "block_stone_thin",
			"count": 2,
			"ingredients": { "block_stone": 1 },
			"category": CAT_MATERIALS,
			"desc": "Mài 1 khối đá thành 2 tấm mỏng 0.2 thay vì dày 0.5.",
		},
		{
			"id": "eggplant_slice",
			"name": "Cà Tím Bổ Đôi",
			"result": "eggplant_slice",
			"count": 2,
			"ingredients": { "eggplant_fruit": 1 },
			"category": CAT_MATERIALS,
			"desc": "Bổ đôi trái cà tím — ruột trắng kem, hạt vàng nâu, nguyên liệu nấu ăn.",
		},
		{
			"id": "eggplant_seed",
			"name": "Hạt Giống Cà Tím",
			"result": "eggplant_seed",
			"count": 2,
			"ingredients": { "eggplant_fruit": 1 },
			"category": CAT_MATERIALS,
			"desc": "Lấy hạt từ trái cà tím — gieo trên đất tơi xốp để trồng thêm bụi cà tím.",
		},
		{
			"id": "watermelon_slice",
			"name": "Miếng Dưa Hấu",
			"result": "watermelon_slice",
			"count": 4,
			"ingredients": { "watermelon": 1 },
			"category": CAT_MATERIALS,
			"desc": "Cắt quả dưa hấu thành 4 miếng tam giác — ruột đỏ mọng nước, hạt đen tuyền, ăn nhanh hồi máu.",
		},
		{
			"id": "watermelon_seed",
			"name": "Hạt Giống Dưa Hấu",
			"result": "watermelon_seed",
			"count": 3,
			"ingredients": { "watermelon": 1 },
			"category": CAT_MATERIALS,
			"desc": "Bổ quả dưa hấu lấy hạt — gieo trên đất tơi xốp để trồng thêm thảm dây dưa.",
		},
		{
			"id": "pumpkin_slice",
			"name": "Miếng Bí Đỏ",
			"result": "pumpkin_slice",
			"count": 4,
			"ingredients": { "pumpkin": 1 },
			"category": CAT_MATERIALS,
			"desc": "Cắt quả bí đỏ thành 4 miếng — vỏ cam mỏng, thịt cam tươi mộng nước, lõi xơ vàng với hạt bí ngà, ăn nhanh hồi máu.",
		},
		{
			"id": "pumpkin_seed",
			"name": "Hạt Giống Bí Đỏ",
			"result": "pumpkin_seed",
			"count": 3,
			"ingredients": { "pumpkin": 1 },
			"category": CAT_MATERIALS,
			"desc": "Lấy hạt bí ngà dẹt từ quả — gieo trên đất tơi xốp để trồng thêm dây bí đỏ.",
		},
		{
			"id": "jack_o_lantern",
			"name": "Đèn Lồng Bí Đỏ",
			"result": "jack_o_lantern",
			"count": 1,
			"ingredients": { "pumpkin": 1 },
			"category": CAT_MATERIALS,
			"desc": "Đục mắt/mũi/miệng tam giác zíc-zắc, đặt nến voxel — đèn lồng tỏa ánh lửa vàng đỏ ấm áp cho đêm hội.",
		},
	]

## Đếm item trong lưới chế tạo → dictionary {item_id: count}.
static func count_grid(grid_inventory) -> Dictionary:
	var have: Dictionary = {}
	if grid_inventory == null:
		return have
	for slot in grid_inventory.slots:
		if slot == null or slot.is_empty():
			continue
		have[slot.item.id] = have.get(slot.item.id, 0) + slot.count
	return have

## Tìm recipe đầu tiên khớp với lưới chế tạo (trả null nếu không khớp).
static func match_grid(grid_inventory) -> Dictionary:
	var have := count_grid(grid_inventory)
	return match_counts(have)

## Tìm recipe khớp với dictionary {item_id: count}.
static func match_counts(have: Dictionary) -> Dictionary:
	for r in recipes:
		var ok := true
		for ing in (r["ingredients"] as Dictionary):
			if have.get(ing, 0) < (r["ingredients"] as Dictionary)[ing]:
				ok = false
				break
		if ok:
			return r
	return {}
