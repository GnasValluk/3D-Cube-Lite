class_name BlockMeshes

const _DATA := preload("res://scripts/world/chunk/chunk_data.gd")
const _OreTex := preload("res://scripts/items/models/ore_texture.gd")

static func block_cube(p: Node3D, item_id: String) -> void:
	var block_id: int = _DATA.ITEM_TO_BLOCK.get(item_id, -1)
	if block_id < 0:
		var def: ItemDef = ItemDatabase.items_db.get(item_id) as ItemDef
		var color: Color = def.icon_color if def else Color(0.50, 0.50, 0.50)
		ItemMeshShared.add_cube(p, 0, 0, 0, 3.0, 3.0, 3.0, color)
		return

	if block_id == _DATA.BlockID.TILLED_SOIL:
		_build_soil_item(p)
	elif block_id >= _DATA.BlockID.COPPER_ORE and block_id != _DATA.BlockID.YOUNG_GRASS:
		_build_ore_item(p, block_id)
	else:
		var top_col: Color = _DATA.BLOCK_COLORS_RW[block_id]
		var side_col: Color
		var bot_col: Color
		match block_id:
			1:  # GRASS
				side_col = _DATA.BLOCK_COLORS_RW[4]  # DIRT
				bot_col = _DATA.block_side_color(side_col)
			2:  # DARK_GRASS
				side_col = _DATA.BLOCK_COLORS_RW[8]  # DARK_DIRT
				bot_col = _DATA.block_side_color(side_col)
			38:  # YOUNG_GRASS — bãi cỏ non: mặt bên đất trống
				side_col = _DATA.BLOCK_COLORS_RW[4]  # DIRT
				bot_col = _DATA.block_side_color(side_col)
			_:
				side_col = _DATA.block_side_color(top_col)
				bot_col = Color(side_col.r * 0.7, side_col.g * 0.7, side_col.b * 0.7)
		_build_colored_cube(p, 3.0, top_col, side_col, bot_col)

static func _get_ore_item_material(block_id: int) -> Material:
	return _OreTex.get_material(block_id, true)

static func _build_soil_item(p: Node3D) -> void:
	var V := ItemMeshShared.V
	var sz := 3.0
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(sz * V, sz * V, sz * V)
	mesh.material = _OreTex.get_soil_material(false, true)
	mi.mesh = mesh
	p.add_child(mi)

static func _build_ore_item(p: Node3D, block_id: int) -> void:
	var V := ItemMeshShared.V
	var sz := 3.0
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(sz * V, sz * V, sz * V)
	mesh.material = _get_ore_item_material(block_id)
	mi.mesh = mesh
	p.add_child(mi)

static func _build_colored_cube(p: Node3D, sz: float, top: Color, side: Color, bot: Color) -> void:
	ItemMeshShared.add_cube(p, 0, 0, 0, sz, sz, sz, side)
