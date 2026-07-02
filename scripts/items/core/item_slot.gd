class_name ItemSlot

var item: ItemDef = null
var count: int = 0

func is_empty() -> bool:
	return item == null or count <= 0

func clear() -> void:
	item = null
	count = 0

func get_item_name() -> String:
	if item == null:
		return ""
	return item.name

func get_description() -> String:
	if item == null or item.desc.is_empty():
		return ""
	return item.desc
