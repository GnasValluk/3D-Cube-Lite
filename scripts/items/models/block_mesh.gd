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

	if block_id >= _DATA.BlockID.COPPER_ORE:
		_build_ore_item(p, block_id)
	else:
		var top_col: Color = _DATA.BLOCK_COLORS_RW[block_id]
		var side_col: Color = _DATA.block_side_color(top_col)
		var bot_col: Color = Color(side_col.r * 0.7, side_col.g * 0.7, side_col.b * 0.7)
		_build_colored_cube(p, 3.0, top_col, side_col, bot_col)

static func _get_ore_item_material(block_id: int) -> Material:
	if _ore_item_mats.has(block_id):
		return _ore_item_mats[block_id]
	var base: Color
	var speck_dark: Color
	var speck_light: Color
	match block_id:
		_DATA.BlockID.COPPER_ORE:
			base = Color(0.38, 0.35, 0.32); speck_dark = Color(0.30, 0.28, 0.25); speck_light = Color(0.80, 0.55, 0.25)
		_DATA.BlockID.BAUXITE_ORE:
			base = Color(0.38, 0.35, 0.32); speck_dark = Color(0.30, 0.28, 0.25); speck_light = Color(0.70, 0.70, 0.72)
		_DATA.BlockID.SILVER_ORE:
			base = Color(0.38, 0.38, 0.40); speck_dark = Color(0.30, 0.30, 0.32); speck_light = Color(0.85, 0.85, 0.92)
		_DATA.BlockID.IRON_ORE:
			base = Color(0.36, 0.33, 0.28); speck_dark = Color(0.28, 0.25, 0.20); speck_light = Color(0.55, 0.50, 0.45)
		_DATA.BlockID.GOLD_ORE:
			base = Color(0.38, 0.35, 0.30); speck_dark = Color(0.30, 0.28, 0.22); speck_light = Color(0.95, 0.80, 0.30)
		_DATA.BlockID.TITAN_ORE:
			base = Color(0.36, 0.34, 0.38); speck_dark = Color(0.28, 0.26, 0.30); speck_light = Color(0.65, 0.55, 0.80)
		_DATA.BlockID.PLATINUM_ORE:
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
			var c := Color(base.r + (r - 0.5) * 0.20, base.g + (r - 0.5) * 0.15, base.b + (r - 0.5) * 0.12)
			h = h * 16807 + 1
			var speck := float(h & 0x7FFFFFFF) / 2147483648.0
			if speck > 0.82:
				c = speck_dark
			elif speck < 0.15:
				c = speck_light
			img.set_pixel(x, y, c)
	var tex := ImageTexture.create_from_image(img)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ore_item_mats[block_id] = mat
	return mat

static func _build_ore_item(p: Node3D, block_id: int) -> void:
	var V := ItemMeshShared.V
	var sz: float = 3.0
	var h := sz * 0.5
	var mat := _get_ore_item_material(block_id)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	_add_quad_uv(st, Vector3(-h, h, -h), Vector3(h, h, -h), Vector3(h, h, h), Vector3(-h, h, h), Vector3(0, 1, 0))
	_add_quad_uv(st, Vector3(-h, -h, h), Vector3(h, -h, h), Vector3(h, h, h), Vector3(-h, h, h), Vector3(0, 0, 1))
	_add_quad_uv(st, Vector3(h, -h, -h), Vector3(-h, -h, -h), Vector3(-h, h, -h), Vector3(h, h, -h), Vector3(0, 0, -1))
	_add_quad_uv(st, Vector3(h, -h, -h), Vector3(h, h, -h), Vector3(h, h, h), Vector3(h, -h, h), Vector3(1, 0, 0))
	_add_quad_uv(st, Vector3(-h, -h, h), Vector3(-h, h, h), Vector3(-h, h, -h), Vector3(-h, -h, -h), Vector3(-1, 0, 0))

	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.scale = Vector3(V, V, V)
	p.add_child(mi)

static func _add_quad_uv(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, nrm: Vector3) -> void:
	st.set_normal(nrm)
	st.set_uv(Vector2(0, 1)); st.add_vertex(a)
	st.set_uv(Vector2(1, 1)); st.add_vertex(b)
	st.set_uv(Vector2(1, 0)); st.add_vertex(c)
	st.set_uv(Vector2(0, 1)); st.add_vertex(a)
	st.set_uv(Vector2(1, 0)); st.add_vertex(c)
	st.set_uv(Vector2(0, 0)); st.add_vertex(d)

static func _build_colored_cube(p: Node3D, sz: float, top: Color, side: Color, bot: Color) -> void:
	var V := ItemMeshShared.V
	var h := sz * 0.5

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	_add_quad_colored(st, Vector3(-h, h, -h), Vector3(-h, h, h), Vector3(h, h, h), Vector3(h, h, -h), Vector3(0, 1, 0), top)
	_add_quad_colored(st, Vector3(-h, -h, h), Vector3(-h, -h, -h), Vector3(h, -h, -h), Vector3(h, -h, h), Vector3(0, -1, 0), bot)
	_add_quad_colored(st, Vector3(-h, -h, h), Vector3(h, -h, h), Vector3(h, h, h), Vector3(-h, h, h), Vector3(0, 0, 1), side)
	_add_quad_colored(st, Vector3(h, -h, -h), Vector3(-h, -h, -h), Vector3(-h, h, -h), Vector3(h, h, -h), Vector3(0, 0, -1), side)
	_add_quad_colored(st, Vector3(h, -h, -h), Vector3(h, h, -h), Vector3(h, h, h), Vector3(h, -h, h), Vector3(1, 0, 0), side)
	_add_quad_colored(st, Vector3(-h, -h, h), Vector3(-h, h, h), Vector3(-h, h, -h), Vector3(-h, -h, -h), Vector3(-1, 0, 0), side)

	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mi.material_override = mat
	mi.scale = Vector3(V, V, V)
	p.add_child(mi)

static func _add_quad_colored(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, nrm: Vector3, col: Color) -> void:
	st.set_normal(nrm)
	st.set_color(col)
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)
	st.add_vertex(a)
	st.add_vertex(c)
	st.add_vertex(d)
