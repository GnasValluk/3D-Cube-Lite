class_name BlockMeshes

static func block_cube(p: Node3D, item_id: String) -> void:
	var def: ItemDef = ItemDatabase.items_db.get(item_id) as ItemDef
	var color: Color = def.icon_color if def else Color(0.50, 0.50, 0.50)
	ItemMeshShared.add_cube(p, 0, 0, 0, 3.0, 3.0, 3.0, color)
