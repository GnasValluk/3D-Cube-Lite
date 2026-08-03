class_name CraftingTable
extends DestructibleEntity

var _player_nearby: bool = false
var _is_open: bool = false

func _init() -> void:
	max_hp = 60
	drop_item_id = "crafting_table"

func _ready() -> void:
	super._ready()
	_setup_mesh()
	_setup_area()

func _m(color: Color, metallic: float = 0.0, rough: float = 0.8) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = rough
	return mat

func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi

func _setup_mesh() -> void:
	var wood := _m(Color(0.42, 0.26, 0.14), 0.05, 0.85)
	var wood_dark := _m(Color(0.35, 0.20, 0.10), 0.05, 0.90)
	var wood_light := _m(Color(0.50, 0.32, 0.17), 0.05, 0.80)
	var metal := _m(Color(0.22, 0.22, 0.25), 0.4, 0.6)
	var metal_dark := _m(Color(0.15, 0.15, 0.18), 0.4, 0.7)
	var anvil_mat := _m(Color(0.28, 0.28, 0.32), 0.5, 0.5)
	var fire_glow := _m(Color(0.70, 0.20, 0.05), 0.0, 0.8)
	var fire_hot := _m(Color(0.90, 0.55, 0.10), 0.0, 0.7)
	var grid_mark := _m(Color(0.28, 0.16, 0.08))
	var gold_coin := _m(Color(0.80, 0.65, 0.15), 0.8, 0.2)
	var scrap := _m(Color(0.30, 0.30, 0.32), 0.5, 0.6)
	var gem_blue := _m(Color(0.15, 0.40, 0.80), 0.3, 0.1)
	var bottle_glass := _m(Color(0.55, 0.65, 0.75), 0.1, 0.1)
	var bottle_red := _m(Color(0.70, 0.15, 0.15), 0.0, 0.3)
	var bottle_green := _m(Color(0.15, 0.55, 0.25), 0.0, 0.3)

	var tw := 1.80
	var td := 0.85
	var th := 0.05
	var ty := 0.65

	# ---- TABLE TOP ----
	_box(self, Vector3(tw, th, td), Vector3(0, ty - th * 0.5, 0), wood)

	# ---- LEGS ----
	var lt := 0.05
	var lh := ty - th
	for x in [-tw * 0.5 + lt * 0.6, tw * 0.5 - lt * 0.6]:
		for z in [-td * 0.5 + lt * 0.6, td * 0.5 - lt * 0.6]:
			_box(self, Vector3(lt * 0.7, lh, lt * 0.7), Vector3(x, lh * 0.5, z), wood_dark)

	# ---- CROSSBARS ----
	_box(self, Vector3(tw - 0.24, 0.03, 0.04), Vector3(0, 0.15, -td * 0.5 + lt * 0.6), wood_dark)
	_box(self, Vector3(tw - 0.24, 0.03, 0.04), Vector3(0, 0.15, td * 0.5 - lt * 0.6), wood_dark)

	# ---- CRAFTING GRID (center) ----
	var gc := 0.42
	var cell := gc / 3.0
	_box(self, Vector3(gc + 0.04, 0.01, gc + 0.04), Vector3(0, ty, 0), grid_mark)
	for row in range(3):
		for col in range(3):
			var cx := (col - 1) * cell
			var cz := (row - 1) * cell
			_box(self, Vector3(cell - 0.02, 0.01, cell - 0.02), Vector3(cx, ty + 0.005, cz), wood_light)

	# ---- FORGE (right) ----
	var fx := 0.52
	var fz := -0.12
	_box(self, Vector3(0.26, 0.12, 0.22), Vector3(fx, ty + 0.06, fz), metal_dark)
	_box(self, Vector3(0.16, 0.04, 0.14), Vector3(fx, ty + 0.14, fz), fire_glow)
	_box(self, Vector3(0.08, 0.02, 0.07), Vector3(fx, ty + 0.17, fz), fire_hot)
	_box(self, Vector3(0.26, 0.02, 0.22), Vector3(fx, ty + 0.13, fz), metal)

	# ---- ANVIL (right, next to forge) ----
	var ax := 0.75
	var az := -0.12
	_box(self, Vector3(0.12, 0.06, 0.09), Vector3(ax, ty + 0.08, az), anvil_mat)
	_box(self, Vector3(0.08, 0.04, 0.06), Vector3(ax, ty + 0.14, az), anvil_mat)
	_box(self, Vector3(0.10, 0.02, 0.07), Vector3(ax, ty + 0.06, az), metal)

	# Tools on anvil
	_box(self, Vector3(0.02, 0.06, 0.02), Vector3(ax + 0.03, ty + 0.18, az), _m(Color(0.35, 0.22, 0.08)))
	_box(self, Vector3(0.04, 0.02, 0.01), Vector3(ax - 0.03, ty + 0.17, az), metal)

	# ---- APOTHECARY (back-right corner) ----
	var apx := 0.46
	var apz := 0.28
	_box(self, Vector3(0.18, 0.02, 0.12), Vector3(apx, ty + 0.03, apz), wood_dark)
	_box(self, Vector3(0.02, 0.05, 0.02), Vector3(apx - 0.05, ty + 0.065, apz), bottle_red)
	_box(self, Vector3(0.02, 0.06, 0.02), Vector3(apx, ty + 0.07, apz), bottle_green)
	_box(self, Vector3(0.02, 0.05, 0.02), Vector3(apx + 0.05, ty + 0.065, apz), bottle_glass)
	# Mortar and pestle
	_box(self, Vector3(0.04, 0.02, 0.04), Vector3(apx - 0.02, ty + 0.05, apz + 0.04), _m(Color(0.40, 0.38, 0.35)))
	_box(self, Vector3(0.01, 0.04, 0.01), Vector3(apx - 0.02, ty + 0.07, apz + 0.04), _m(Color(0.45, 0.42, 0.38)))

	# ---- SCATTERED MATERIALS (left) ----
	_box(self, Vector3(0.06, 0.02, 0.06), Vector3(-0.50, ty + 0.01, -0.18), gold_coin)
	_box(self, Vector3(0.06, 0.02, 0.06), Vector3(-0.38, ty + 0.01, -0.12), gold_coin)
	_box(self, Vector3(0.06, 0.04, 0.06), Vector3(-0.44, ty + 0.03, -0.15), gold_coin)
	_box(self, Vector3(0.04, 0.01, 0.07), Vector3(-0.55, ty + 0.005, 0.12), scrap)
	_box(self, Vector3(0.07, 0.01, 0.03), Vector3(-0.42, ty + 0.005, 0.18), scrap)
	_box(self, Vector3(0.04, 0.04, 0.04), Vector3(-0.60, ty + 0.02, 0.02), gem_blue)
	_box(self, Vector3(0.06, 0.01, 0.03), Vector3(-0.32, ty + 0.005, -0.22), wood_light)
	_box(self, Vector3(0.02, 0.02, 0.03), Vector3(-0.48, ty + 0.01, 0.25), _m(Color(0.50, 0.35, 0.15)))

	# ---- STORAGE BOXES (under table, both sides) ----
	var ub_y := ty - th - 0.06
	_box(self, Vector3(0.12, 0.05, 0.10), Vector3(-0.55, ub_y, -0.20), wood_dark)
	_box(self, Vector3(0.12, 0.05, 0.10), Vector3(-0.55, ub_y, 0.20), wood_dark)
	_box(self, Vector3(0.08, 0.03, 0.08), Vector3(0.60, ub_y, -0.25), wood_dark)

	# ---- DRAWERS (under front edge) ----
	var dr_y := ty - th - 0.04
	_box(self, Vector3(0.14, 0.04, 0.08), Vector3(-0.30, dr_y, td * 0.5 - 0.04), wood_light)
	_box(self, Vector3(0.14, 0.02, 0.02), Vector3(-0.30, dr_y + 0.02, td * 0.5 - 0.02), _m(Color(0.25, 0.18, 0.10)))

	# ---- COLLISION ----
	var col := CollisionShape3D.new()
	var box_col := BoxShape3D.new()
	box_col.size = Vector3(2.0, 0.7, 1.0)
	col.shape = box_col
	col.position = Vector3(0, 0.35, 0)
	add_child(col)

func _setup_area() -> void:
	var area := Area3D.new()
	area.name = "InteractArea"
	var col_shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.8
	col_shape.shape = sphere
	area.add_child(col_shape)
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	add_child(area)

func _on_body_entered(body: Node) -> void:
	if body is PlayerCharacter:
		_player_nearby = true

func _on_body_exited(body: Node) -> void:
	if body is PlayerCharacter:
		_player_nearby = false
		close_ui()

func is_player_nearby() -> bool:
	return _player_nearby

func open_ui() -> void:
	if _is_open:
		return
	_is_open = true
	var hud := _find_hud()
	if hud:
		hud.open_crafting(self)

func close_ui() -> void:
	if not _is_open:
		return
	_is_open = false
	var hud := _find_hud()
	if hud:
		hud.close_crafting()

func _find_hud() -> HUD:
	var root := get_tree().current_scene if get_tree() else null
	if root == null:
		return null
	for child in root.get_children():
		if child is HUD:
			return child
	return null

## Bị phá huỷ: đóng UI (nếu đang mở) rồi rớt lại vật phẩm bàn chế tạo.
func _on_destroy() -> void:
	close_ui()
