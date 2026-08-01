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
