class_name Inventory
extends RefCounted

const DEFAULT_SIZE: int = 36
const HOTBAR_SIZE: int = 9

var slots: Array[ItemSlot] = []

func _init(size: int = DEFAULT_SIZE):
	ItemDatabase.ensure_db()
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
	var temp_dur: int = slots[idx_a].durability
	slots[idx_a].item = slots[idx_b].item
	slots[idx_a].count = slots[idx_b].count
	slots[idx_a].durability = slots[idx_b].durability
	slots[idx_b].item = temp_item
	slots[idx_b].count = temp_count
	slots[idx_b].durability = temp_dur

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
		dst.durability = src.durability
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

func remove_item_by_id(item_id: String, count: int = 1) -> bool:
	var remaining: int = count
	for i in range(slots.size()):
		if remaining <= 0:
			break
		var slot: ItemSlot = slots[i]
		if slot.is_empty() or slot.item.id != item_id:
			continue
		var take: int = mini(remaining, slot.count)
		remaining -= take
		slot.count -= take
		if slot.count <= 0:
			slot.clear()
	return remaining < count

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

func to_dict() -> Array:
	var arr: Array = []
	for slot in slots:
		if slot.is_empty():
			arr.append(null)
		else:
			var d: Dictionary = {"id": slot.item.id, "count": slot.count}
			if slot.durability >= 0:
				d["dur"] = slot.durability
			arr.append(d)
	return arr

func from_dict(data: Array) -> void:
	ItemDatabase.ensure_db()
	var db := ItemDatabase.items_db
	for i in range(mini(data.size(), slots.size())):
		if data[i] != null:
			var item_id: String = data[i]["id"]
			var count: int = data[i]["count"]
			if db.has(item_id):
				slots[i].item = db[item_id]
				slots[i].count = count
				if slots[i].durability >= 0:
					slots[i].durability = clampi(int(data[i].get("dur", slots[i].durability)), 0, slots[i].item.max_durability)
			else:
				slots[i].item = null
				slots[i].count = 0
		else:
			slots[i].item = null
			slots[i].count = 0

func sort() -> void:
	var filled: Array[ItemSlot] = []
	for slot in slots:
		if not slot.is_empty():
			filled.append(slot)
	for i in range(slots.size()):
		slots[i].item = null
		slots[i].count = 0
	filled.sort_custom(func(a: ItemSlot, b: ItemSlot) -> bool:
		if a.item.type != b.item.type:
			return a.item.type < b.item.type
		return a.item.name < b.item.name)
	for i in range(mini(filled.size(), slots.size())):
		slots[i].item = filled[i].item
		slots[i].count = filled[i].count

func split_stack(idx: int, count: int) -> int:
	if idx < 0 or idx >= slots.size():
		return -1
	var slot: ItemSlot = slots[idx]
	if slot.is_empty() or slot.count <= count:
		return -1
	var empty_idx: int = find_empty_slot()
	if empty_idx < 0:
		return -1
	slots[empty_idx].item = slot.item
	slots[empty_idx].count = count
	slots[empty_idx].durability = slot.durability
	slot.count -= count
	return empty_idx

# ── Độ bền ──────────────────────────────────────────────────────────────────
## Slot chứa item_def nào (nếu có). Dùng để truy độ bền của item đang cầm.
func find_slot_of_item(item_def: ItemDef) -> int:
	if item_def == null:
		return -1
	for i in range(slots.size()):
		if not slots[i].is_empty() and slots[i].item == item_def:
			return i
	return -1

## Trừ độ bền của slot. Trả về true nếu còn dùng được; false nếu vỡ.
func damage_slot_durability(idx: int, amount: int) -> bool:
	if idx < 0 or idx >= slots.size():
		return true
	var slot: ItemSlot = slots[idx]
	if slot.is_empty() or slot.durability < 0:
		return true
	slot.durability = maxi(slot.durability - amount, 0)
	return slot.durability > 0
