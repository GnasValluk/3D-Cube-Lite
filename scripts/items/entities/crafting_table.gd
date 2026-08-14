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

func _m(color: Color, metallic: float = 0.0, rough: float = 0.8, emissive: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = rough
	if emissive:
		mat.emission_enabled = true
		mat.emission = color * 2.0
		mat.emission_energy_multiplier = 1.6
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
	var wood      := _m(Color(0.44, 0.27, 0.15), 0.05, 0.82)
	var wood2     := _m(Color(0.52, 0.34, 0.19), 0.05, 0.78)
	var wood_d    := _m(Color(0.34, 0.20, 0.10), 0.05, 0.90)
	var metal     := _m(Color(0.24, 0.24, 0.28), 0.45, 0.5)
	var metal_hi  := _m(Color(0.48, 0.48, 0.54), 0.7, 0.3)
	var metal_d   := _m(Color(0.15, 0.15, 0.18), 0.45, 0.75)
	var anvil     := _m(Color(0.30, 0.30, 0.34), 0.55, 0.45)
	var fire_glow := _m(Color(0.80, 0.28, 0.05), 0.0, 0.8)
	var fire_hot  := _m(Color(0.98, 0.62, 0.12), 0.0, 0.4)
	var fire_core := _m(Color(1.0, 0.9, 0.55), 0.0, 0.15, true)
	var coin      := _m(Color(0.82, 0.67, 0.18), 0.8, 0.2)
	var scrap     := _m(Color(0.33, 0.33, 0.36), 0.5, 0.55)
	var gem_b     := _m(Color(0.20, 0.45, 0.90), 0.3, 0.2, true)
	var glass     := _m(Color(0.45, 0.60, 0.80), 0.25, 0.15, true)
	var gem_r     := _m(Color(0.82, 0.22, 0.20), 0.3, 0.2, true)
	var bottle_r  := _m(Color(0.60, 0.26, 0.28), 0.25, 0.35, true)
	var bottle_g  := _m(Color(0.24, 0.60, 0.32), 0.25, 0.35, true)

	var tw := 2.00; var td := 1.00; var th := 0.12; var ty := 0.72
	var top_y := ty - th * 0.5

	# ---- Thick 3-plank top with metal corner straps ----
	_box(self, Vector3(tw, th, td), Vector3(0, top_y, 0), wood)
	for i in range(3):
		var cx := -0.62 + i * 0.62
		_box(self, Vector3(0.62, th * 0.55, td - 0.08), Vector3(cx, top_y + th * 0.28, 0), wood2)
	for i in range(2):
		var sx := -0.62 + i * 1.24
		_box(self, Vector3(th * 0.5, th * 0.35, td - 0.08), Vector3(sx, top_y + th * 0.62, 0), metal)
	_box(self, Vector3(tw, th * 0.4, 0.05), Vector3(0, top_y - th * 0.6, -td * 0.5 + 0.025), wood2)
	_box(self, Vector3(tw, th * 0.4, 0.05), Vector3(0, top_y - th * 0.6, td * 0.5 - 0.025), wood2)

	# ---- Chunky legs + apron rails ----
	var lt := 0.10; var lh := ty - th
	for x in [-tw * 0.42, tw * 0.42]:
		for z in [-td * 0.42, td * 0.42]:
			_box(self, Vector3(lt, lh, lt), Vector3(x, lh * 0.5, z), wood_d)
			_box(self, Vector3(lt * 1.1, 0.06, lt * 1.1), Vector3(x, 0.03, z), wood_d)
	# Apron rails (connect legs, thick)
	var arz := td * 0.42 + 0.04
	_box(self, Vector3(tw - 0.3, 0.05, lt * 0.6), Vector3(0, 0.30, -arz), wood_d)
	_box(self, Vector3(tw - 0.3, 0.05, lt * 0.6), Vector3(0, 0.30, arz), wood_d)
	_box(self, Vector3(lt * 0.6, 0.05, td - 0.3), Vector3(-tw * 0.42 - 0.03, 0.30, 0), wood_d)
	_box(self, Vector3(lt * 0.6, 0.05, td - 0.3), Vector3(tw * 0.42 + 0.03, 0.30, 0), wood_d)

	# ---- Central crafting grid ----
	var gc := 0.44
	var cell := gc / 3.0
	_box(self, Vector3(gc + 0.10, 0.018, gc + 0.10), Vector3(0, ty, 0), metal_d)
	for row in range(3):
		for col in range(3):
			var cx := (col - 1) * cell
			var cz := (row - 1) * cell
			_box(self, Vector3(cell - 0.03, 0.018, cell - 0.03), Vector3(cx, ty + 0.008, cz), wood2)

	# ---- Forge (right side) ----
	var fx := 0.62; var fz := -0.18
	_box(self, Vector3(0.28, 0.14, 0.24), Vector3(fx, ty + 0.03, fz), metal_d)
	_box(self, Vector3(0.18, 0.05, 0.16), Vector3(fx, ty + 0.12, fz), fire_glow)
	_box(self, Vector3(0.10, 0.03, 0.09), Vector3(fx, ty + 0.18, fz), fire_hot)
	_box(self, Vector3(0.04, 0.04, 0.04), Vector3(fx, ty + 0.21, fz), fire_core)
	_box(self, Vector3(0.10, 0.015, 0.12), Vector3(fx, ty + 0.21, fz), anvil)
	# chimney
	_box(self, Vector3(0.08, 0.18, 0.08), Vector3(fx, ty + 0.10, fz - 0.14), metal_d)
	_box(self, Vector3(0.10, 0.04, 0.10), Vector3(fx, ty + 0.20, fz - 0.14), metal)

	# ---- Anvil (next to forge) ----
	var ax := 0.82; var az := -0.10
	_box(self, Vector3(0.14, 0.07, 0.10), Vector3(ax, ty + 0.06, az), anvil)
	_box(self, Vector3(0.09, 0.045, 0.07), Vector3(ax, ty + 0.13, az), anvil)
	_box(self, Vector3(0.12, 0.022, 0.08), Vector3(ax, ty + 0.05, az), metal)

	# ---- Tool rack (left) ----
	var rack_y := ty + 0.06; var rack_z := -0.34
	_box(self, Vector3(0.58, 0.028, 0.04), Vector3(0.0, rack_y, rack_z), metal)
	for hx in [-0.24, 0.0, 0.24]:
		_box(self, Vector3(0.022, 0.11, 0.022), Vector3(hx, rack_y - 0.02, rack_z), metal_hi)
		_box(self, Vector3(0.07, 0.026, 0.022), Vector3(hx, rack_y + 0.08, rack_z), metal)

	# ---- Scattered materials (left corner) ----
	_box(self, Vector3(0.09, 0.025, 0.09), Vector3(-0.54, ty + 0.008, -0.16), coin)
	_box(self, Vector3(0.10, 0.04, 0.10), Vector3(-0.46, ty + 0.012, -0.13), coin)
	_box(self, Vector3(0.06, 0.055, 0.06), Vector3(-0.58, ty + 0.02, 0.02), gem_b)
	_box(self, Vector3(0.07, 0.012, 0.10), Vector3(-0.52, ty + 0.008, 0.18), scrap)

	# ---- Apothecary bottles (back-right) ----
	var apx := 0.48; var apz := 0.24
	_box(self, Vector3(0.15, 0.022, 0.10), Vector3(apx, ty + 0.008, apz), metal_d)
	_box(self, Vector3(0.022, 0.12, 0.022), Vector3(apx - 0.05, ty + 0.07, apz), bottle_r)
	_box(self, Vector3(0.024, 0.13, 0.024), Vector3(apx, ty + 0.072, apz), bottle_g)
	_box(self, Vector3(0.022, 0.12, 0.022), Vector3(apx + 0.05, ty + 0.07, apz), glass)
	_box(self, Vector3(0.024, 0.024, 0.024), Vector3(apx, ty + 0.14, apz), metal_hi)

	# ---- Storage boxes under table (both sides) ----
	var ub_y := ty - th - 0.07
	for bx in [-0.58, 0.62]:
		var bz := -0.18 if bx < 0 else 0.14
		_box(self, Vector3(0.15, 0.07, 0.12), Vector3(bx, ub_y, bz), wood_d)
		_box(self, Vector3(0.16, 0.022, 0.13), Vector3(bx, ub_y + 0.042, bz), metal_hi)
		_box(self, Vector3(0.07, 0.016, 0.05), Vector3(bx, ub_y + 0.052, bz), gem_r)

	# ---- Drawers under front ----
	var dr_y := ty - th - 0.05
	_box(self, Vector3(0.30, 0.06, 0.10), Vector3(0.18, dr_y, td * 0.5 - 0.05), wood2)
	_box(self, Vector3(0.30, 0.026, 0.10), Vector3(0.18, dr_y + 0.022, td * 0.5 - 0.05), _m(Color(0.25, 0.18, 0.10)))
	_box(self, Vector3(0.12, 0.026, 0.018), Vector3(0.18, dr_y + 0.028, td * 0.5 - 0.025), metal_hi)

	# ---- Collision ----
	var col := CollisionShape3D.new()
	var box_col := BoxShape3D.new()
	box_col.size = Vector3(2.2, 0.80, 1.2)
	col.shape = box_col
	col.position = Vector3(0, 0.40, 0)
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

func _on_destroy() -> void:
	close_ui()
