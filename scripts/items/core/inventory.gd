class_name Inventory
extends RefCounted

const DEFAULT_SIZE: int = 36
const HOTBAR_SIZE: int = 9

static var items_db: Dictionary = {}

static func ensure_db() -> void:
	if items_db.is_empty():
		items_db = create_item_db()

var slots: Array[ItemSlot] = []

func _init(size: int = DEFAULT_SIZE):
	ensure_db()
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
	_add(db, "chest",         "Rương đồ",     ItemDef.Type.BLOCK,  Color(0.50, 0.32, 0.10), "C",  "Rương chứa đồ",          false, 1)
	_add(db, "twilight_gate", "Cổng Twilight", ItemDef.Type.TOOL,   Color(0.10, 0.50, 0.45), "T",  "Đặt cổng Twilight ra thế giới", false, 1)

	# ── Công cụ ────────────────────────────────────────────────────────────────
	_add(db, "cup",   "Cúp",   ItemDef.Type.TOOL,   Color(0.60, 0.55, 0.50), "⛏", "Đào đất, khai thác tài nguyên",   false, 1, 0, 8,  0)
	_add(db, "xeng",  "Xẻng",  ItemDef.Type.TOOL,   Color(0.70, 0.65, 0.55), "🔨", "Xúc đất, di chuyển vật liệu",     false, 1, 0, 6,  0)
	_add(db, "riu",   "Rìu",   ItemDef.Type.TOOL,   Color(0.50, 0.45, 0.40), "🪓", "Chặt cây, phá gỗ",                false, 1, 0, 14, 0)

	# ── Vũ khí ─────────────────────────────────────────────────────────────────
	_add(db, "kiem",  "Kiếm",  ItemDef.Type.WEAPON, Color(0.75, 0.80, 0.90), "⚔",  "Tấn công nhanh, sát thương cao",  false, 1, 0, 22, 0)

	# ── Câu cá ────────────────────────────────────────────────────────────────
	_add(db, "can_cau", "Cần câu", ItemDef.Type.TOOL, Color(0.55, 0.40, 0.25), "🎣", "Cần câu cá — dùng để câu cá ở vùng nước", false, 1, 0, 0, 0)

	# ── Cá (thức ăn) ──────────────────────────────────────────────────────────
	_add(db, "ca_chep", "Carp", ItemDef.Type.FOOD, Color(0.95, 0.70, 0.10), "🐟", "Freshwater carp — rich, firm flesh", true, 16, 30)
	_add(db, "ca_ro",   "Climbing Perch", ItemDef.Type.FOOD, Color(0.30, 0.30, 0.30), "🐟", "Climbing perch — sweet white meat", true, 16, 20)
	_add(db, "ca_dieu_hong", "Red Tilapia", ItemDef.Type.FOOD, Color(0.88, 0.55, 0.45), "🐟", "Red tilapia — firm, mild flavour", true, 16, 35)
	_add(db, "ca_loc", "Snakehead", ItemDef.Type.FOOD, Color(0.30, 0.25, 0.15), "🐟", "Snakehead — dense, savoury fillet", true, 16, 45)
	_add(db, "ca_la_han", "Flowerhorn", ItemDef.Type.FOOD, Color(0.92, 0.25, 0.15), "🐟", "Flowerhorn — rich, flavourful meat", true, 16, 55)
	_add(db, "tom", "Freshwater Shrimp", ItemDef.Type.FOOD, Color(0.85, 0.35, 0.20), "🦐", "Freshwater shrimp — sweet, delicate meat", true, 16, 8)

	return db

static func _add(db: Dictionary, id: String, name: String, type: int, color: Color, char: String,
				 desc: String = "", stackable: bool = true, max_stack: int = 64,
				 heal: int = 0, atk: int = 0, def_val: int = 0, armor_slot: int = -1) -> void:
	db[id] = ItemDef.new(id, name, type, color, char, desc, stackable, max_stack, heal, atk, def_val, armor_slot)

func to_dict() -> Array:
	var arr: Array = []
	for slot in slots:
		if slot.is_empty():
			arr.append(null)
		else:
			arr.append({"id": slot.item.id, "count": slot.count})
	return arr

func from_dict(data: Array) -> void:
	ensure_db()
	var db := items_db
	for i in range(mini(data.size(), slots.size())):
		if data[i] != null:
			var item_id: String = data[i]["id"]
			var count: int = data[i]["count"]
			if db.has(item_id):
				slots[i].item = db[item_id]
				slots[i].count = count
			else:
				slots[i].item = null
				slots[i].count = 0
		else:
			slots[i].item = null
			slots[i].count = 0


