class_name Chest
extends DestructibleEntity

var inventory: Inventory = null
var _player_nearby: bool = false
var _lid_pivot: Node3D
var _treasure_root: Node3D
var _sparkle: GPUParticles3D
var _is_open: bool = false

func _init() -> void:
	max_hp = 60
	drop_item_id = "chest"

func _ready() -> void:
	super._ready()
	inventory = Inventory.new(27)
	_setup_mesh()
	_setup_area()

func _m(color: Color, metallic: float = 0.0, rough: float = 0.8) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = rough
	return m

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
	var wood_body := _m(Color(0.42, 0.26, 0.14), 0.1, 0.85)
	var wood_lid := _m(Color(0.47, 0.30, 0.17), 0.1, 0.80)
	var plank_dark := _m(Color(0.28, 0.14, 0.07))
	var metal := _m(Color(0.25, 0.22, 0.20), 0.5, 0.5)
	var rivet_mat := _m(Color(0.35, 0.32, 0.30), 0.6, 0.4)
	var lock_gold := _m(Color(0.75, 0.60, 0.20), 0.7, 0.3)
	var dark_inside := _m(Color(0.12, 0.06, 0.04))
	var red_velvet := _m(Color(0.35, 0.08, 0.08), 0.0, 0.9)
	var gold_coin := _m(Color(0.80, 0.65, 0.15), 0.8, 0.2)
	var gem_blue := _m(Color(0.15, 0.40, 0.80), 0.3, 0.1)
	var gem_red := _m(Color(0.70, 0.15, 0.15), 0.3, 0.1)
	var gem_green := _m(Color(0.15, 0.60, 0.30), 0.3, 0.1)

	# ---- BODY ----
	var bw := 1.76  # body width
	var bh := 0.36  # body height
	var bd := 0.78  # body depth

	_box(self, Vector3(bw, bh, bd), Vector3(0, bh * 0.5, 0), wood_body)

	var body_front_z := bd * 0.5 + 0.005
	var body_side_x := bw * 0.5 + 0.005

	# Vertical plank lines (front face)
	for x in [-0.60, -0.30, 0, 0.30, 0.60]:
		_box(self, Vector3(0.02, 0.26, 0.01), Vector3(x, bh * 0.5, body_front_z), plank_dark)

	# Vertical plank lines (side faces)
	for z_off in [-0.20, 0.20]:
		_box(self, Vector3(0.01, 0.26, 0.02), Vector3(-body_side_x, bh * 0.5, z_off), plank_dark)
		_box(self, Vector3(0.01, 0.26, 0.02), Vector3(body_side_x, bh * 0.5, z_off), plank_dark)

	# ---- METAL BANDS ----
	var band_h := 0.04
	var band_d := 0.06
	var band_y_bottom := 0.06
	var band_y_top := bh - 0.06

	# Bottom band
	_box(self, Vector3(bw + 0.04, band_h, band_d), Vector3(0, band_y_bottom, body_front_z), metal)
	_box(self, Vector3(band_d, band_h, bd - 0.04), Vector3(-body_side_x, band_y_bottom, 0), metal)
	_box(self, Vector3(band_d, band_h, bd - 0.04), Vector3(body_side_x, band_y_bottom, 0), metal)

	# Top band
	_box(self, Vector3(bw + 0.04, band_h, band_d), Vector3(0, band_y_top, body_front_z), metal)
	_box(self, Vector3(band_d, band_h, bd - 0.04), Vector3(-body_side_x, band_y_top, 0), metal)
	_box(self, Vector3(band_d, band_h, bd - 0.04), Vector3(body_side_x, band_y_top, 0), metal)

	# Rivets on bottom band
	for x in [-0.54, -0.18, 0.18, 0.54]:
		_box(self, Vector3(0.04, 0.03, 0.04), Vector3(x, band_y_bottom, body_front_z + 0.03), rivet_mat)
		_box(self, Vector3(0.04, 0.03, 0.04), Vector3(x, band_y_top, body_front_z + 0.03), rivet_mat)

	# ---- LOCK ----
	var lock_w := 0.16
	var lock_h := 0.14
	var lock_d := 0.08
	_box(self, Vector3(lock_w, lock_h, lock_d), Vector3(0, bh * 0.5, body_front_z + 0.04), lock_gold)

	# Lock shackle (small arch above lock body)
	_box(self, Vector3(0.08, 0.04, 0.04), Vector3(0, bh * 0.5 + lock_h * 0.5 + 0.02, body_front_z + 0.04), metal)

	# ---- HINGES (back) ----
	var hinge_z := -(bd * 0.5 + 0.01)
	_box(self, Vector3(0.06, 0.10, 0.04), Vector3(-0.50, bh * 0.5, hinge_z), metal)
	_box(self, Vector3(0.06, 0.10, 0.04), Vector3(0.50, bh * 0.5, hinge_z), metal)

	# ---- LID ----
	var lw := bw + 0.08
	var lh := 0.06
	var ld := bd + 0.06

	_lid_pivot = Node3D.new()
	_lid_pivot.position = Vector3(0, bh, -bd * 0.5)
	add_child(_lid_pivot)

	_box(_lid_pivot, Vector3(lw, lh, ld), Vector3(0, lh * 0.5, ld * 0.5), wood_lid)

	# Lid band (at front edge of lid)
	_box(_lid_pivot, Vector3(lw + 0.02, lh * 0.5, 0.04), Vector3(0, lh * 0.5, ld * 0.5 - 0.02), metal)

	# Lid rivets
	for x in [-0.54, -0.18, 0.18, 0.54]:
		_box(_lid_pivot, Vector3(0.03, 0.02, 0.03), Vector3(x, lh * 0.5, ld * 0.5), rivet_mat)

	# ---- TREASURE (interior, hidden until opened) ----
	_treasure_root = Node3D.new()
	_treasure_root.position = Vector3(0, bh + 0.01, 0)
	add_child(_treasure_root)

	# Dark interior floor
	_box(_treasure_root, Vector3(bw - 0.12, 0.02, bd - 0.12), Vector3(0, 0, 0), dark_inside)
	# Red velvet
	_box(_treasure_root, Vector3(bw - 0.20, 0.01, bd - 0.20), Vector3(0, 0.015, 0), red_velvet)

	# Gold coins
	var coin_positions := [
		Vector3(-0.30, 0.04, 0.10),
		Vector3(0.20, 0.04, -0.15),
		Vector3(-0.10, 0.04, 0.25),
		Vector3(0.35, 0.04, 0.20),
		Vector3(-0.20, 0.04, -0.20),
		Vector3(0.05, 0.04, -0.05),
	]
	for cp in coin_positions:
		_box(_treasure_root, Vector3(0.06, 0.02, 0.06), cp, gold_coin)

	# Stacked coins (piles)
	_box(_treasure_root, Vector3(0.06, 0.04, 0.06), Vector3(-0.30, 0.06, 0.10), gold_coin)
	_box(_treasure_root, Vector3(0.06, 0.06, 0.06), Vector3(0.35, 0.07, 0.20), gold_coin)

	# Gems
	_box(_treasure_root, Vector3(0.05, 0.05, 0.05), Vector3(-0.40, 0.05, -0.10), gem_blue)
	_box(_treasure_root, Vector3(0.04, 0.04, 0.04), Vector3(0.40, 0.04, -0.15), gem_red)
	_box(_treasure_root, Vector3(0.05, 0.05, 0.05), Vector3(0, 0.05, -0.28), gem_green)

	# Item (tiny sword shape: two boxes)
	var sword_mat := _m(Color(0.50, 0.50, 0.55), 0.7, 0.2)
	_box(_treasure_root, Vector3(0.04, 0.20, 0.02), Vector3(-0.55, 0.12, 0), sword_mat)
	_box(_treasure_root, Vector3(0.02, 0.06, 0.04), Vector3(-0.55, 0.03, 0), _m(Color(0.35, 0.20, 0.06)))

	# Sparkle particles
	_sparkle = GPUParticles3D.new()
	_sparkle.emitting = false
	_sparkle.amount = 15
	_sparkle.lifetime = 1.2
	_sparkle.one_shot = false
	_sparkle.explosiveness = 0.0
	_sparkle.randomness = 0.4
	_sparkle.position = Vector3(0, 0.08, 0)

	var pmat := ParticleProcessMaterial.new()
	pmat.direction = Vector3.UP
	pmat.spread = 120.0
	pmat.gravity = Vector3(0, -0.05, 0)
	pmat.initial_velocity_min = 0.05
	pmat.initial_velocity_max = 0.15
	pmat.scale_min = 0.02
	pmat.scale_max = 0.05
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.85, 0.3, 0.8))
	grad.set_color(1, Color(1.0, 0.85, 0.3, 0.0))
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = grad
	pmat.color_ramp = grad_tex

	var quad := QuadMesh.new()
	quad.size = Vector2(0.04, 0.04)
	_sparkle.draw_pass_1 = quad
	_sparkle.process_material = pmat
	_treasure_root.add_child(_sparkle)

	# ---- COLLISION ----
	var col := CollisionShape3D.new()
	var box_col := BoxShape3D.new()
	box_col.size = Vector3(2.0, 0.5, 1.0)
	col.shape = box_col
	col.position = Vector3(0, 0.25, 0)
	add_child(col)

	_treasure_root.hide()

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
	_treasure_root.show()
	_sparkle.emitting = true
	var hud := _find_hud()
	if hud:
		hud.open_chest(self)
	SFXManager.play_chest_open()
	_open_animation()

func close_ui() -> void:
	if not _is_open:
		return
	_is_open = false
	_treasure_root.hide()
	_sparkle.emitting = false
	var hud := _find_hud()
	if hud:
		hud.close_chest()
	SFXManager.play_chest_close()
	_close_animation()

func _open_animation() -> void:
	if not is_instance_valid(_lid_pivot):
		return
	var tween := create_tween()
	tween.tween_property(_lid_pivot, "rotation:x", deg_to_rad(-110.0), 0.4)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)

func _close_animation() -> void:
	if not is_instance_valid(_lid_pivot):
		return
	var tween := create_tween()
	tween.tween_property(_lid_pivot, "rotation:x", 0.0, 0.3)
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

## Bị phá huỷ: đóng UI (nếu đang mở) + đổ toàn bộ đồ trong rương ra ngoài.
func _on_destroy() -> void:
	close_ui()

func _spill_inventory() -> void:
	if inventory == null:
		return
	var world := _find_world_manager()
	if world == null:
		return
	for slot in inventory.slots:
		if slot.is_empty():
			continue
		var scatter: Vector3 = Vector3(randf_range(-0.7, 0.7), 0.2, randf_range(-0.7, 0.7))
		DroppedItem.spawn(world, slot.item, global_position + scatter, slot.count,
			_spawn_drop_velocity(), global_position.y)
