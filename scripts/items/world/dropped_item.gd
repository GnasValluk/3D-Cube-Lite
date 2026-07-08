class_name DroppedItem
extends Area3D

const _WeaponMesh := preload("res://scripts/characters/player/weapon_mesh.gd")

var item_def: ItemDef = null
var item_count: int = 1
var _time_alive: float = 0.0
var can_pickup: bool = false

func init(def_: ItemDef, count: int = 1):
	item_def = def_
	item_count = count
	_setup_mesh()
	var timer := Timer.new()
	timer.one_shot = true
	timer.autostart = true
	timer.wait_time = 3.0
	timer.timeout.connect(func(): can_pickup = true)
	add_child(timer)

func _setup_mesh():
	var root := Node3D.new()
	add_child(root)
	root.position.y = 0.15

	var item_id := item_def.id
	if item_id in ["cup", "xeng", "riu", "kiem", "can_cau"]:
		var pivot := Node3D.new()
		root.add_child(pivot)
		_WeaponMesh.build(pivot, item_id)
	elif item_id in ["ca_chep", "ca_ro", "ca_dieu_hong", "ca_loc", "ca_la_han", "tom"]:
		_build_fish_model(root, item_id)
	else:
		ItemMesh.build(root, item_id)

	var light := OmniLight3D.new()
	light.omni_range = 1.2
	light.light_energy = 0.35
	light.light_color = item_def.icon_color.lightened(0.4)
	light.light_specular = 0.0
	root.add_child(light)

	var coll := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.6, 0.6, 0.6)
	coll.shape = shape
	add_child(coll)

	collision_layer = 1
	collision_mask = 0
	set_process(true)

func _build_fish_model(parent: Node3D, item_id: String) -> void:
	var variant: int = 0
	match item_id:
		"ca_chep": variant = 0
		"ca_ro": variant = 1
		"ca_dieu_hong": variant = 2
		"ca_loc": variant = 3
		"ca_la_han": variant = 4
		"tom": variant = 5

	var colors: Array = FishCharacter.VARIANT_COLORS[variant]

	var fm := FishMesh.new()
	fm.color_body = colors[0]
	fm.color_belly = colors[1]
	fm.color_fin = colors[2]
	fm.color_tail = (colors[0] as Color) * 0.8
	fm.color_pattern = FishCharacter.VARIANT_PATTERN[variant]
	fm.body_z_scale = FishCharacter.VARIANT_BODY_Z[variant]
	if variant == 4:
		fm.body_triangular = true
		fm.has_horns = true
	elif variant == 5:
		fm.body_shape = FishMesh.BodyShape.SHRIMP

	var temp := Node3D.new()
	fm.build(temp)
	var rig: Node3D = temp.get_child(0) if temp.get_child_count() > 0 else null
	if rig:
		temp.remove_child(rig)
		parent.add_child(rig)
	temp.queue_free()

func _ready() -> void:
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = 60.0
	timer.timeout.connect(queue_free)
	add_child(timer)
	timer.start()

func _process(delta: float):
	_time_alive += delta
	var bob := sin(_time_alive * 2.0) * 0.05
	position.y += bob * delta * 2.0
	var rot := delta * 30.0
	rotation.y += deg_to_rad(rot)

func collect(player: Node) -> bool:
	if not can_pickup:
		return false
	if player.has_method("pickup_item"):
		var remaining: int = player.pickup_item(item_def, item_count)
		if remaining <= 0:
			queue_free()
			return true
		item_count = remaining
	return false

static func spawn(world: Node3D, def_: ItemDef, pos: Vector3, count: int = 1) -> DroppedItem:
	var item := DroppedItem.new()
	item.init(def_, count)
	item.position = pos + Vector3(0, 0.2, 0)
	world.add_child(item)
	return item
