class_name Inventory
extends RefCounted

const DEFAULT_SIZE: int = 36
const HOTBAR_SIZE: int = 9

var slots: Array[ItemSlot] = []

func _init(size: int = DEFAULT_SIZE):
	slots.resize(size)
	for i in range(size):
		slots[i] = ItemSlot.new()

func get_hotbar() -> Array[ItemSlot]:
	return slots.slice(0, mini(HOTBAR_SIZE, slots.size()))

func get_storage() -> Array[ItemSlot]:
	return slots.slice(HOTBAR_SIZE, slots.size())

func add_item(item_def: ItemDef, count: int = 1) -> int:
	var remaining: int = count
	if item_def.stackable:
		for i in range(slots.size()):
			var slot: ItemSlot = slots[i]
			if not slot.is_empty() and slot.item.id == item_def.id and slot.count < item_def.max_stack:
				var space: int = item_def.max_stack - slot.count
				var add: int = mini(space, remaining)
				slot.count += add
				remaining -= add
				if remaining <= 0:
					return 0
	for i in range(slots.size()):
		var slot: ItemSlot = slots[i]
		if slot.is_empty():
			var add: int = mini(item_def.max_stack if item_def.stackable else 1, remaining)
			slot.item = item_def
			slot.count = add
			remaining -= add
			if remaining <= 0:
				return 0
	return remaining

func remove_item(slot_idx: int, count: int = 1) -> bool:
	if slot_idx < 0 or slot_idx >= slots.size():
		return false
	var slot: ItemSlot = slots[slot_idx]
	if slot.is_empty() or slot.count < count:
		return false
	slot.count -= count
	if slot.count <= 0:
		slot.clear()
	return true

func swap(idx_a: int, idx_b: int) -> void:
	if idx_a < 0 or idx_a >= slots.size() or idx_b < 0 or idx_b >= slots.size():
		return
	if idx_a == idx_b:
		return
	var temp_item: ItemDef = slots[idx_a].item
	var temp_count: int = slots[idx_a].count
	slots[idx_a].item = slots[idx_b].item
	slots[idx_a].count = slots[idx_b].count
	slots[idx_b].item = temp_item
	slots[idx_b].count = temp_count

func transfer(from_idx: int, to_idx: int) -> bool:
	if from_idx < 0 or from_idx >= slots.size() or to_idx < 0 or to_idx >= slots.size():
		return false
	var src: ItemSlot = slots[from_idx]
	var dst: ItemSlot = slots[to_idx]
	if src.is_empty():
		return false
	if dst.is_empty():
		dst.item = src.item
		dst.count = src.count
		src.clear()
		return true
	if src.item.id == dst.item.id and dst.item.stackable and dst.count < dst.item.max_stack:
		var space: int = dst.item.max_stack - dst.count
		var move: int = mini(space, src.count)
		dst.count += move
		src.count -= move
		if src.count <= 0:
			src.clear()
		return true
	return false

func can_transfer(from_idx: int, to_idx: int) -> bool:
	if from_idx < 0 or from_idx >= slots.size() or to_idx < 0 or to_idx >= slots.size():
		return false
	var src: ItemSlot = slots[from_idx]
	var dst: ItemSlot = slots[to_idx]
	if src.is_empty():
		return false
	if dst.is_empty():
		return true
	if src.item.id == dst.item.id and dst.item.stackable and dst.count < dst.item.max_stack:
		return true
	return false

func get_item_count(item_id: String) -> int:
	var total: int = 0
	for slot in slots:
		if not slot.is_empty() and slot.item.id == item_id:
			total += slot.count
	return total

func count_filled_slots() -> int:
	var n: int = 0
	for slot in slots:
		if not slot.is_empty():
			n += 1
	return n

func is_full() -> bool:
	for slot in slots:
		if slot.is_empty():
			return false
	return true

func is_empty() -> bool:
	for slot in slots:
		if not slot.is_empty():
			return false
	return true

func find_empty_slot() -> int:
	for i in range(slots.size()):
		if slots[i].is_empty():
			return i
	return -1

func has_item(item_id: String) -> bool:
	for slot in slots:
		if not slot.is_empty() and slot.item.id == item_id:
			return true
	return false

static func create_item_db() -> Dictionary:
	var db: Dictionary = {}
	_add(db, "dirt",         "Đất",         ItemDef.Type.BLOCK,    Color(0.54, 0.32, 0.12), "D", "Khối đất thông thường")
	_add(db, "stone",        "Đá",          ItemDef.Type.BLOCK,    Color(0.50, 0.50, 0.50), "S", "Khối đá rắn chắc")
	_add(db, "wood",         "Gỗ",          ItemDef.Type.BLOCK,    Color(0.40, 0.25, 0.10), "W", "Khối gỗ")
	_add(db, "grass",        "Cỏ",          ItemDef.Type.BLOCK,    Color(0.20, 0.70, 0.15), "G", "Khối cỏ xanh")
	_add(db, "sand",         "Cát",         ItemDef.Type.BLOCK,    Color(0.76, 0.70, 0.50), "A", "Khối cát mịn")
	_add(db, "brick",        "Gạch",        ItemDef.Type.BLOCK,    Color(0.65, 0.30, 0.20), "B", "Khối gạch đỏ")
	_add(db, "apple",        "Táo",         ItemDef.Type.FOOD,     Color(0.85, 0.15, 0.10), "A", "Hồi 20 HP", true, 64, 20)
	_add(db, "bread",        "Bánh mì",     ItemDef.Type.FOOD,     Color(0.85, 0.70, 0.30), "B", "Hồi 35 HP", true, 64, 35)
	_add(db, "cooked_meat",  "Thịt chín",   ItemDef.Type.FOOD,     Color(0.55, 0.35, 0.20), "M", "Hồi 50 HP", true, 64, 50)
	_add(db, "stick",        "Gậy",         ItemDef.Type.MATERIAL, Color(0.55, 0.35, 0.15), "I", "Nguyên liệu chế tạo")
	_add(db, "string",       "Dây",         ItemDef.Type.MATERIAL, Color(0.90, 0.90, 0.90), "N", "Sợi dây chắc chắn")
	_add(db, "iron",         "Sắt",         ItemDef.Type.MATERIAL, Color(0.75, 0.75, 0.80), "F", "Thỏi sắt nguyên chất")
	_add(db, "gold",         "Vàng",        ItemDef.Type.MATERIAL, Color(1.00, 0.85, 0.00), "G", "Thỏi vàng quý giá")
	_add(db, "diamond",      "Kim cương",   ItemDef.Type.MATERIAL, Color(0.00, 0.80, 1.00), "D", "Viên kim cương lấp lánh")
	_add(db, "stone_sword",  "Kiếm đá",     ItemDef.Type.WEAPON,   Color(0.50, 0.50, 0.55), "K", "Sát thương +8", false, 1, 0, 8)
	_add(db, "iron_sword",   "Kiếm sắt",    ItemDef.Type.WEAPON,   Color(0.75, 0.75, 0.80), "K", "Sát thương +15", false, 1, 0, 15)
	_add(db, "stone_pickaxe","Cúp đá",      ItemDef.Type.TOOL,     Color(0.50, 0.50, 0.55), "P", "Khai thác đá", false, 1)
	_add(db, "iron_pickaxe", "Cúp sắt",     ItemDef.Type.TOOL,     Color(0.75, 0.75, 0.80), "P", "Khai thác nhanh", false, 1)
	_add(db, "leather_helmet","Mũ da",      ItemDef.Type.ARMOR,    Color(0.60, 0.40, 0.20), "H", "Đầu +3", false, 1, 0, 0, 3, ItemDef.ArmorSlot.HEAD)
	_add(db, "leather_chest", "Áo da",      ItemDef.Type.ARMOR,    Color(0.60, 0.40, 0.20), "C", "Thân +5", false, 1, 0, 0, 5, ItemDef.ArmorSlot.BODY)
	_add(db, "leather_legs",  "Quần da",    ItemDef.Type.ARMOR,    Color(0.60, 0.40, 0.20), "L", "Chân +4", false, 1, 0, 0, 4, ItemDef.ArmorSlot.LEGS)
	_add(db, "leather_boots", "Giày da",    ItemDef.Type.ARMOR,    Color(0.60, 0.40, 0.20), "B", "Chân +2", false, 1, 0, 0, 2, ItemDef.ArmorSlot.FEET)
	_add(db, "iron_helmet",   "Mũ sắt",     ItemDef.Type.ARMOR,    Color(0.75, 0.75, 0.80), "H", "Đầu +7", false, 1, 0, 0, 7, ItemDef.ArmorSlot.HEAD)
	_add(db, "iron_chest",    "Áo sắt",     ItemDef.Type.ARMOR,    Color(0.75, 0.75, 0.80), "C", "Thân +12", false, 1, 0, 0, 12, ItemDef.ArmorSlot.BODY)
	_add(db, "iron_legs",     "Quần sắt",   ItemDef.Type.ARMOR,    Color(0.75, 0.75, 0.80), "L", "Chân +9", false, 1, 0, 0, 9, ItemDef.ArmorSlot.LEGS)
	_add(db, "iron_boots",    "Giày sắt",   ItemDef.Type.ARMOR,    Color(0.75, 0.75, 0.80), "B", "Chân +5", false, 1, 0, 0, 5, ItemDef.ArmorSlot.FEET)
	_add(db, "twilight_gate","Cổng Twilight",ItemDef.Type.TOOL,    Color(0.10, 0.50, 0.45), "T", "Đặt cổng Twilight ra thế giới", false, 1)
	return db

static func _add(db: Dictionary, id: String, name: String, type: int, color: Color, char: String,
				 desc: String = "", stackable: bool = true, max_stack: int = 64,
				 heal: int = 0, atk: int = 0, def_val: int = 0, armor_slot: int = -1) -> void:
	db[id] = ItemDef.new(id, name, type, color, char, desc, stackable, max_stack, heal, atk, def_val, armor_slot)

static func seed_inventory(inv: Inventory) -> void:
	pass
