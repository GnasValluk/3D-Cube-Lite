class_name BlockMeshes

const _DATA := preload("res://scripts/world/chunk/chunk_data.gd")

static var _ore_item_mats: Dictionary[int, Material] = {}

static func block_cube(p: Node3D, item_id: String) -> void:
	var block_id: int = _DATA.ITEM_TO_BLOCK.get(item_id, -1)
	if block_id < 0:
		var def: ItemDef = ItemDatabase.items_db.get(item_id) as ItemDef
		var color: Color = def.icon_color if def else Color(0.50, 0.50, 0.50)
		ItemMeshShared.add_cube(p, 0, 0, 0, 3.0, 3.0, 3.0, color)
		return

	if block_id >= 18:
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
			_:
				side_col = _DATA.block_side_color(top_col)
				bot_col = Color(side_col.r * 0.7, side_col.g * 0.7, side_col.b * 0.7)
		_build_colored_cube(p, 3.0, top_col, side_col, bot_col)

static func _get_ore_item_material(block_id: int) -> Material:
	if _ore_item_mats.has(block_id):
		return _ore_item_mats[block_id]
	var base: Color
	var speck_dark: Color
	var speck_light: Color
	var is_ore := true
	match block_id:
		18:  # COPPER_ORE
			base = Color(0.38, 0.35, 0.32); speck_dark = Color(0.30, 0.28, 0.25); speck_light = Color(0.80, 0.55, 0.25)
		19:  # BAUXITE_ORE
			base = Color(0.38, 0.35, 0.32); speck_dark = Color(0.30, 0.28, 0.25); speck_light = Color(0.70, 0.70, 0.72)
		20:  # SILVER_ORE
			base = Color(0.38, 0.38, 0.40); speck_dark = Color(0.30, 0.30, 0.32); speck_light = Color(0.85, 0.85, 0.92)
		21:  # IRON_ORE
			base = Color(0.36, 0.33, 0.28); speck_dark = Color(0.28, 0.25, 0.20); speck_light = Color(0.55, 0.50, 0.45)
		22:  # GOLD_ORE
			base = Color(0.38, 0.35, 0.30); speck_dark = Color(0.30, 0.28, 0.22); speck_light = Color(0.95, 0.80, 0.30)
		23:  # TITAN_ORE
			base = Color(0.36, 0.34, 0.38); speck_dark = Color(0.28, 0.26, 0.30); speck_light = Color(0.65, 0.55, 0.80)
		24:  # PLATINUM_ORE
			base = Color(0.38, 0.36, 0.38); speck_dark = Color(0.30, 0.28, 0.30); speck_light = Color(0.80, 0.85, 0.95)
		_:
			base = Color(0.50, 0.50, 0.50); speck_dark = Color(0.30, 0.30, 0.30); speck_light = Color(0.70, 0.70, 0.70)
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	for y in range(8):
		for x in range(8):
			var h: int = x * 374761393 + y * 668265263 + 12345
			h = (h ^ (h >> 13)) * 1274126177
			h = h ^ (h >> 16)
			var r := float(h & 0x7FFFFFFF) / 2147483648.0
			var c := Color(
				base.r + (r - 0.5) * 0.20,
				base.g + (r - 0.5) * 0.15,
				base.b + (r - 0.5) * 0.12)
			h = h * 16807 + 1
			var speck := float(h & 0x7FFFFFFF) / 2147483648.0
			if is_ore:
				if speck > 0.82:
					c = speck_dark
				elif speck < 0.15:
					c = speck_light
			else:
				if speck > 0.92:
					c = speck_dark
				elif speck < 0.06:
					c = speck_light
			img.set_pixel(x, y, c)
	var tex := ImageTexture.create_from_image(img)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if is_ore:
		mat.roughness = 0.65
		mat.metallic_specular = 0.15
		mat.emission_enabled = true
		mat.emission_texture = tex
		mat.emission_energy_multiplier = 0.25
	else:
		mat.roughness = 0.9
		mat.metallic_specular = 0.0
	_ore_item_mats[block_id] = mat
	return mat

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
