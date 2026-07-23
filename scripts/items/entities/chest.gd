class_name Chest
extends StaticBody3D

var inventory: Inventory = null
var _label: Label3D
var _player_nearby: bool = false
var _lid_pivot: Node3D
var _is_open: bool = false

func _ready() -> void:
	inventory = Inventory.new(27)
	_setup_mesh()
	_setup_area()
	_setup_label()

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and _label:
		_label.text = tr("CHEST_INTERACT" if _player_nearby else "CHEST_LABEL")

func _setup_mesh() -> void:
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.45, 0.28, 0.15)
	body_mat.metallic = 0.1
	body_mat.roughness = 0.8

	var lid_mat := StandardMaterial3D.new()
	lid_mat.albedo_color = Color(0.50, 0.32, 0.18)
	lid_mat.metallic = 0.1
	lid_mat.roughness = 0.7

	var body_mesh := MeshInstance3D.new()
	var body_box := BoxMesh.new()
	body_box.size = Vector3(0.7, 0.35, 0.6)
	body_mesh.mesh = body_box
	body_mesh.material_override = body_mat
	body_mesh.position = Vector3(0, 0.175, 0)
	add_child(body_mesh)

	_lid_pivot = Node3D.new()
	_lid_pivot.position = Vector3(0, 0.38, 0.31)
	add_child(_lid_pivot)

	var lid_mesh := MeshInstance3D.new()
	var lid_box := BoxMesh.new()
	lid_box.size = Vector3(0.72, 0.06, 0.62)
	lid_mesh.mesh = lid_box
	lid_mesh.material_override = lid_mat
	lid_mesh.position = Vector3(0, 0, -0.31)
	_lid_pivot.add_child(lid_mesh)

	var band_mat := StandardMaterial3D.new()
	band_mat.albedo_color = Color(0.35, 0.22, 0.12)
	var band := MeshInstance3D.new()
	var band_box := BoxMesh.new()
	band_box.size = Vector3(0.74, 0.04, 0.08)
	band.mesh = band_box
	band.material_override = band_mat
	band.position = Vector3(0, 0.20, 0.305)
	add_child(band)

	var lock_mat := StandardMaterial3D.new()
	lock_mat.albedo_color = Color(0.60, 0.50, 0.30)
	var lock_mesh := MeshInstance3D.new()
	var lock_box := BoxMesh.new()
	lock_box.size = Vector3(0.10, 0.08, 0.06)
	lock_mesh.mesh = lock_box
	lock_mesh.material_override = lock_mat
	lock_mesh.position = Vector3(0, 0.22, 0.305)
	add_child(lock_mesh)

	var col := CollisionShape3D.new()
	var box_col := BoxShape3D.new()
	box_col.size = Vector3(0.8, 0.5, 0.7)
	col.shape = box_col
	col.position = Vector3(0, 0.25, 0)
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

func _setup_label() -> void:
	_label = Label3D.new()
	_label.text = tr("CHEST_LABEL")
	_label.font_size = 24
	_label.outline_size = 4
	_label.modulate = Color(1, 1, 1, 0.8)
	_label.position = Vector3(0, 0.8, 0)
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.pixel_size = 0.005
	add_child(_label)

func _on_body_entered(body: Node) -> void:
	if body is PlayerCharacter:
		_player_nearby = true
		_label.text = tr("CHEST_INTERACT")

func _on_body_exited(body: Node) -> void:
	if body is PlayerCharacter:
		_player_nearby = false
		_label.text = tr("CHEST_LABEL")
		close_ui()

func is_player_nearby() -> bool:
	return _player_nearby

func open_ui() -> void:
	if _is_open:
		return
	_is_open = true
	var hud := _find_hud()
	if hud:
		hud.open_chest(self)
	SFXManager.play_chest_open()
	_open_animation()

func close_ui() -> void:
	if not _is_open:
		return
	_is_open = false
	var hud := _find_hud()
	if hud:
		hud.close_chest()
	SFXManager.play_chest_close()
	_close_animation()

func _open_animation() -> void:
	if not is_instance_valid(_lid_pivot):
		return
	var tween := create_tween()
	tween.tween_property(_lid_pivot, "rotation:x", deg_to_rad(120.0), 0.35)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)

func _close_animation() -> void:
	if not is_instance_valid(_lid_pivot):
		return
	var tween := create_tween()
	tween.tween_property(_lid_pivot, "rotation:x", 0.0, 0.25)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BOUNCE)

func _find_hud() -> HUD:
	var root := get_tree().current_scene if get_tree() else null
	if root == null:
		return null
	for child in root.get_children():
		if child is HUD:
			return child
	return null
