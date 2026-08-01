class_name ItemSlot

var item: ItemDef = null:
	set(v):
		item = v
		if v != null and v.max_durability > 0:
			durability = v.max_durability
		else:
			durability = -1
var count: int = 0
var durability: int = -1  # độ bền hiện tại; -1 = không dùng độ bền

func is_empty() -> bool:
	return item == null or count <= 0

func clear() -> void:
	item = null
	count = 0

func get_durability_ratio() -> float:
	if item == null or item.max_durability <= 0 or durability < 0:
		return -1.0
	return clampf(float(durability) / float(item.max_durability), 0.0, 1.0)

func get_item_name() -> String:
	if item == null:
		return ""
	return item.name

func get_description() -> String:
	if item == null or item.desc.is_empty():
		return ""
	return item.desc
