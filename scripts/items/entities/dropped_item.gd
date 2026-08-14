class_name DroppedItem
extends Area3D

const PlantProp := preload("res://scripts/world/props/plant_prop.gd")
const ExperienceOrb := preload("res://scripts/items/entities/experience_orb.gd")



var item_def: ItemDef = null
var item_count: int = 1
var _time_alive: float = 0.0
var can_pickup: bool = false
var _flying: bool = false
var _straight_flight: bool = false
var _velocity: Vector3 = Vector3.ZERO
var _ground_y: float = 0.0
var _throw_damage: int = 0
var _throw_attacker: Node3D = null
var _player: Node3D = null

const MAGNET_RANGE: float = 3.0
const FLY_SPEED: float = 7.0
const PICKUP_DISTANCE: float = 1.35
const FALL_GRAVITY: float = 14.0
const FALL_EPS: float = 0.02
const REST_HEIGHT: float = 0.2

var _settled: bool = false
var _fall_vel: float = 0.0
var _ground_measured: bool = false

func init(def_: ItemDef, count: int = 1):
	item_def = def_
	item_count = count
	_setup_mesh()
	call_deferred("_find_player")
	var timer := Timer.new()
	timer.one_shot = true
	timer.autostart = true
	timer.wait_time = 1.0
	timer.timeout.connect(func(): can_pickup = true)
	add_child(timer)

func _setup_mesh():
	var root := Node3D.new()
	add_child(root)
	root.position.y = 0.15

	var item_id := item_def.id
	if item_id in ["pickaxe", "shovel", "axe", "iron_sword", "fishing_rod", "iron_greatsword", "leather_gloves", "crossbow", "arrow", "watermelon_cannon", "watermelon_nuke_ammo", "pumpkin_mortar", "iron_halberd", "flashlight"]:
		var scale_node := Node3D.new()
		scale_node.scale = Vector3(1.8, 1.8, 1.8)
		root.add_child(scale_node)
		ToolsMesh.build_held(scale_node, item_id)
	elif item_id in ["carp", "climbing_perch", "red_tilapia", "snakehead", "flowerhorn", "shrimp"]:
		_build_fish_model(root, item_id)
	elif item_id == "taro":
		PlantProp.build_drop_mesh(root, "taro")
	elif item_id == "tropical_seaweed":
		PlantProp.build_drop_mesh(root, "weed")
	elif item_id == "seagrass":
		PlantProp.build_drop_mesh(root, "seagrass")
	elif item_id in ["chest", "twilight_gate", "crafting_table", "furnace", "cooking_stove", "tool_table", "mech_table", "farm_table", "chem_table", "magic_table", "kitchen_table"]:
		ItemMesh.build(root, item_id)
	else:
		var item_scale: float = 1.5
		# Trái cây to bản — nhỏ bớt để không vượt 1 block khi rơi xuống đất
		if item_id == "watermelon" or item_id == "pumpkin":
			item_scale = 1.1
		var scale_pivot := Node3D.new()
		scale_pivot.scale = Vector3(item_scale, item_scale, item_scale)
		root.add_child(scale_pivot)
		ItemMesh.build(scale_pivot, item_id)

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
		"carp": variant = 0
		"climbing_perch": variant = 1
		"red_tilapia": variant = 2
		"snakehead": variant = 3
		"flowerhorn": variant = 4
		"shrimp": variant = 5

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

func launch(initial_velocity: Vector3, ground_y: float) -> void:
	_flying = true
	_velocity = initial_velocity
	_ground_y = ground_y
	_ground_measured = true
	_settled = false

func fly_straight(initial_velocity: Vector3, ground_y: float, damage: int = 0, attacker: Node3D = null) -> void:
	_flying = true
	_straight_flight = true
	_velocity = initial_velocity
	_ground_y = ground_y
	_ground_measured = true
	_settled = false
	_throw_damage = damage
	_throw_attacker = attacker

func _find_player() -> void:
	var world := get_tree().current_scene
	if world == null: return
	var mgr := world.get_node_or_null("CharacterManager") as CharacterManager
	if mgr:
		_player = mgr.get_current_character()

func _ready() -> void:
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = 60.0
	timer.timeout.connect(queue_free)
	add_child(timer)
	timer.start()

func _process(delta: float):
	if not is_instance_valid(self): return
	_time_alive += delta
	if _flying:
		if _straight_flight:
			var parent := get_parent()
			var parent_inv: Transform3D = parent.global_transform.affine_inverse() if parent != null else Transform3D.IDENTITY
			var next_pos := position + _velocity * delta
			var space := get_world_3d().direct_space_state
			var hit_obstacle := false
			if space:
				var q := PhysicsRayQueryParameters3D.new()
				q.from = to_global(position) if parent != null else position
				q.to = to_global(next_pos) if parent != null else next_pos
				q.collide_with_areas = false
				q.collide_with_bodies = true
				q.exclude = [self]
				var hit := space.intersect_ray(q)
				if not hit.is_empty():
					next_pos = parent_inv * hit.position if parent != null else hit.position
					hit_obstacle = true
					if _throw_damage > 0:
						var col := hit.get("collider") as Object
						if is_instance_valid(col) and col.has_method("take_damage"):
							col.take_damage(_throw_damage, _throw_attacker)
			position = next_pos
			var dir := _velocity.normalized()
			if dir.length_squared() > 0.001:
				var up_ref := Vector3.UP if abs(dir.y) < 0.99 else Vector3.FORWARD
				var x_axis := up_ref.cross(dir).normalized()
				var y_axis := dir
				var z_axis := x_axis.cross(y_axis).normalized()
				transform.basis = Basis(x_axis, y_axis, z_axis)
			if position.y <= _ground_y or hit_obstacle:
				if hit_obstacle:
					position.y = maxf(position.y, _ground_y)
				else:
					position.y = _ground_y
				_flying = false
				_straight_flight = false
		else:
			_velocity.y -= 9.8 * delta
			position += _velocity * delta
			rotation.x += delta * 6.0
			rotation.z += delta * 4.0
			if position.y <= _ground_y:
				position.y = _ground_y
				_flying = false
				rotation.x = 0.0
				rotation.z = 0.0
	else:
		if not _settled:
			_fall(delta)
		# Magnet: bay về phía người chơi khi đủ gần
		if can_pickup and _player and is_instance_valid(_player):
			var to_player := _player.global_position - global_position
			var dist := to_player.length()
			if dist <= PICKUP_DISTANCE:
				collect(_player)
				return
			if dist < MAGNET_RANGE:
				var dir := to_player / maxf(dist, 0.001)
				global_position += dir * FLY_SPEED * delta
				return
		var bob := sin(_time_alive * 2.0) * 0.05
		position.y += bob * delta * 2.0
		var rot := delta * 30.0
		rotation.y += deg_to_rad(rot)

## Vật phẩm rơi từ trên cao (không có launch): có trọng lực, rớt chạm đất rồi đứng yên.
func _fall(delta: float) -> void:
	if not _ground_measured:
		_ground_measured = true
		_ground_y = _measure_ground_y()
	if position.y - REST_HEIGHT > _ground_y + FALL_EPS:
		_fall_vel -= FALL_GRAVITY * delta
		position.y += _fall_vel * delta
	else:
		position.y = _ground_y + REST_HEIGHT
		_settled = true
		_fall_vel = 0.0

## Tìm chiều cao mặt đất ngay dưới vật phẩm (raycast xuống, bỏ qua chính nó).
func _measure_ground_y() -> float:
	var space := get_world_3d().direct_space_state
	if space != null:
		var q := PhysicsRayQueryParameters3D.new()
		q.from = global_position
		q.to = global_position + Vector3(0, -60.0, 0)
		q.collide_with_areas = false
		q.collide_with_bodies = true
		q.exclude = [self]
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			return hit.position.y
	return global_position.y

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

static func spawn(world: Node, def_: ItemDef, pos: Vector3, count: int = 1, velocity: Vector3 = Vector3.ZERO, ground_y: float = -INF) -> Node3D:
	# Hạt kinh nghiệm: vứt ra sẽ rớt thành hạt thật (khác view 3 khối cũ) —
	# không quay lại kho khi nhặt lại, mà tiêu hao +1 XP như hạt quái rớt.
	if def_ != null and def_.id == "experience_orb":
		var gy: float = ground_y if ground_y > -INF else pos.y
		var last: Node3D = null
		for i in range(maxi(count, 1)):
			var jitter := Vector3(randf_range(-0.25, 0.25), 0, randf_range(-0.25, 0.25))
			last = ExperienceOrb.spawn(world, pos + jitter, gy)
			if last == null:
				break
		return last
	var item := DroppedItem.new()
	item.init(def_, count)
	item.position = pos + Vector3(0, 0.2, 0)
	var parent := _resolve_world_parent(world)
	if parent == null:
		item.queue_free()
		return null
	parent.add_child(item)
	if velocity != Vector3.ZERO:
		item.launch(velocity, ground_y if ground_y > -INF else pos.y)
	return item

## Khi world được truyền không phải Node3D (vd. LoadingScreen đang là
## current_scene trong lúc chuyển cảnh), tìm thế giới 3D thực tế dưới root.
static func _resolve_world_parent(world: Node) -> Node3D:
	if world == null:
		return null
	if world is Node3D:
		return world as Node3D
	var tree := world.get_tree()
	if tree == null:
		return null
	for child in tree.root.get_children():
		if child is Node3D:
			return child as Node3D
	return null
