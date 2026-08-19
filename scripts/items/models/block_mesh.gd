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
	elif block_id >= _DATA.BlockID.COPPER_ORE and block_id != _DATA.BlockID.STONE_PLATFORM \
			and block_id != _DATA.BlockID.STONE_WALL_Z \
			and block_id != _DATA.BlockID.STONE_WALL_X \
			and block_id != _DATA.BlockID.STONE_HALF \
			and block_id != _DATA.BlockID.STONE_QUARTER \
			and block_id != _DATA.BlockID.STONE_EIGHTH_2 \
			and block_id != _DATA.BlockID.YOUNG_GRASS \
			and block_id != _DATA.BlockID.GRASS_DIRT \
			and block_id != _DATA.BlockID.DESERT_PLATEAU \
			and block_id != _DATA.BlockID.TWILIGHT_GRASS \
			and block_id != _DATA.BlockID.TWILIGHT_DIRT \
			and block_id != _DATA.BlockID.DRY_GRASS \
			and block_id != _DATA.BlockID.SPARSE_GRASS \
			and block_id != _DATA.BlockID.PALE_SAND \
			and block_id != _DATA.BlockID.SNOW \
			and block_id != _DATA.BlockID.FROST_DIRT:
		_build_ore_item(p, block_id)
	else:
		var dirt_id: int = _DATA.grass_dirt_id(block_id)
		if dirt_id >= 0:
			_build_grass_cube(p, 3.0,
				_DATA.BLOCK_COLORS_RW[block_id],
				_DATA.BLOCK_COLORS_RW[dirt_id])
			return
		var top_col: Color = _DATA.BLOCK_COLORS_RW[block_id]
		var side_col: Color
		var bot_col: Color
		match block_id:
			46:  # PALE_SAND — cát phai: mặt bên cát phai
				side_col = _DATA.BLOCK_COLORS_RW[9]  # SAND_DEEP
				bot_col = _DATA.block_side_color(side_col)
			41:  # DESERT_PLATEAU (legacy) — vẫn render như cát sâu
				side_col = _DATA.BLOCK_COLORS_RW[9]  # SAND_DEEP
				bot_col = _DATA.block_side_color(side_col)
			43:  # TWILIGHT_DIRT — đất Twilight: mặt bên cũng đất
				side_col = _DATA.block_side_color(top_col)
				bot_col = Color(side_col.r * 0.7, side_col.g * 0.7, side_col.b * 0.7)
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

## Cube 6 mặt với vertex color: top / side / bot — thay BoxMesh 1 màu cũ.
static func _build_colored_cube(p: Node3D, sz: float, top: Color, side: Color, bot: Color) -> void:
	var V := ItemMeshShared.V
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := sz * V * 0.5
	_item_quad(st, Vector3(0, h, 0), Vector3(h, 0, 0), Vector3(0, 0, h),
		Vector3(0, 1, 0), top)
	_item_quad(st, Vector3(0, -h, 0), Vector3(h, 0, 0), Vector3(0, 0, h),
		Vector3(0, -1, 0), bot)
	_item_quad(st, Vector3(0, 0, h), Vector3(h, 0, 0), Vector3(0, h, 0),
		Vector3(0, 0, 1), side)
	_item_quad(st, Vector3(0, 0, -h), Vector3(h, 0, 0), Vector3(0, h, 0),
		Vector3(0, 0, -1), side)
	_item_quad(st, Vector3(h, 0, 0), Vector3(0, 0, h), Vector3(0, h, 0),
		Vector3(1, 0, 0), side)
	_item_quad(st, Vector3(-h, 0, 0), Vector3(0, 0, h), Vector3(0, h, 0),
		Vector3(-1, 0, 0), side)
	_item_finish(p, st)

## Khối cỏ Minecraft-style: top = cỏ, side nửa trên cỏ + nửa dưới đất, bot = đất.
static func _build_grass_cube(p: Node3D, sz: float, grass: Color, dirt: Color) -> void:
	var V := ItemMeshShared.V
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := sz * V * 0.5
	var grass_side := Color(grass.r * 0.50, grass.g * 0.50, grass.b * 0.50, grass.a)
	var dirt_side := Color(dirt.r * 0.50, dirt.g * 0.50, dirt.b * 0.50, dirt.a)
	var dirt_bot := Color(dirt.r * 0.35, dirt.g * 0.35, dirt.b * 0.35, dirt.a)
	_item_quad(st, Vector3(0, h, 0), Vector3(h, 0, 0), Vector3(0, 0, h),
		Vector3(0, 1, 0), grass)
	_item_quad(st, Vector3(0, -h, 0), Vector3(h, 0, 0), Vector3(0, 0, h),
		Vector3(0, -1, 0), dirt_bot)
	var gh := Vector3(0, h * 0.5, 0)  # nửa trên (cỏ)
	var dh := Vector3(0, h * 0.5, 0)  # nửa dưới (đất), dời xuống dưới tâm
	_item_quad(st, Vector3(0, h * 0.5, h), Vector3(h, 0, 0), gh,
		Vector3(0, 0, 1), grass_side)
	_item_quad(st, Vector3(0, -h * 0.5, h), Vector3(h, 0, 0), dh,
		Vector3(0, 0, 1), dirt_side)
	_item_quad(st, Vector3(0, h * 0.5, -h), Vector3(h, 0, 0), gh,
		Vector3(0, 0, -1), grass_side)
	_item_quad(st, Vector3(0, -h * 0.5, -h), Vector3(h, 0, 0), dh,
		Vector3(0, 0, -1), dirt_side)
	_item_quad(st, Vector3(h, h * 0.5, 0), Vector3(0, 0, h), gh,
		Vector3(1, 0, 0), grass_side)
	_item_quad(st, Vector3(h, -h * 0.5, 0), Vector3(0, 0, h), dh,
		Vector3(1, 0, 0), dirt_side)
	_item_quad(st, Vector3(-h, h * 0.5, 0), Vector3(0, 0, h), gh,
		Vector3(-1, 0, 0), grass_side)
	_item_quad(st, Vector3(-h, -h * 0.5, 0), Vector3(0, 0, h), dh,
		Vector3(-1, 0, 0), dirt_side)
	_item_finish(p, st)

## Quad vuông cho item cube — pattern giống _Terrain._add_quad (center, u, v).
static func _item_quad(st: SurfaceTool, c: Vector3, u: Vector3, v: Vector3,
		n: Vector3, col: Color) -> void:
	st.set_normal(n); st.set_color(col)
	st.add_vertex(c - u - v)
	st.add_vertex(c + u - v)
	st.add_vertex(c + u + v)
	st.add_vertex(c - u - v)
	st.add_vertex(c + u + v)
	st.add_vertex(c - u + v)

static func _item_finish(p: Node3D, st: SurfaceTool) -> void:
	var mesh := st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	p.add_child(mi)
