class_name CraftingStation
extends DestructibleEntity

## Bàn trạm chế tạo chuyên ngành — kế thừa cách hoạt động của Bàn Chế Tạo:
## đặt vật phẩm trong thế giới (StaticBody3D), có InteractArea để nhấn F mở
## lưới chế tạo riêng theo từng loại bàn (công cụ / cơ khí / nông nghiệp /
## hoá học / phép thuật / làm bếp). Mỗi bàn có mesh riêng, rớt đúng item.

var station_id: String = ""
var _player_nearby: bool = false
var _is_open: bool = false

func _init(p_max_hp: int = 60, p_drop_id: String = "") -> void:
	max_hp = p_max_hp
	drop_item_id = p_drop_id
	station_id = p_drop_id

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

## Mesh đặc trưng từng loại bàn — ghi đè ở class con.
func _setup_mesh() -> void:
	pass

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

## Bị phá huỷ: đóng UI (nếu đang mở) rồi rớt lại vật phẩm bàn trạm.
func _on_destroy() -> void:
	close_ui()