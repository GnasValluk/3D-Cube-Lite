class_name DroppedItem
extends Area3D

var item_def: ItemDef = null
var item_count: int = 1
var _time_alive: float = 0.0

func init(def_: ItemDef, count: int = 1):
	item_def = def_
	item_count = count
	_setup_mesh()

func _setup_mesh():
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.3, 0.3, 0.3)
	box.material = StandardMaterial3D.new()
	box.material.albedo_color = item_def.icon_color
	mesh.mesh = box
	add_child(mesh)
	mesh.position.y = 0.15

	var coll := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.6, 0.6, 0.6)
	coll.shape = shape
	add_child(coll)

	collision_layer = 1
	collision_mask = 0
	set_process(true)
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
