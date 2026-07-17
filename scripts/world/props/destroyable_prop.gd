class_name DestroyableProp
extends Node3D

enum WeaponReq { NONE, AXE, SWORD, PICKAXE }

var max_hp: int = 3
var hp: int
var weapon_requirement: int = WeaponReq.NONE
var drop_item_id: String = ""
var _destroyed: bool = false

func _init(p_max_hp: int = 3, p_weapon_req: int = WeaponReq.NONE, p_drop_id: String = "") -> void:
	max_hp = p_max_hp
	hp = max_hp
	weapon_requirement = p_weapon_req
	drop_item_id = p_drop_id

func _ready() -> void:
	hp = max_hp
	add_to_group("destroyable_props")

func try_destroy(weapon_id: String, damage: int = 1) -> bool:
	if _destroyed or not _weapon_allowed(weapon_id):
		return false
	hp -= damage
	if hp > 0:
		_hit_flash()
		_spawn_damage_number(damage)
		SFXManager.play_hurt()
	else:
		_spawn_damage_number(damage)
		SFXManager.play_block_break()
		_die()
	return true

func _weapon_allowed(weapon_id: String) -> bool:
	if weapon_requirement == WeaponReq.NONE:
		return true
	match weapon_requirement:
		WeaponReq.AXE:     return weapon_id == "riu"
		WeaponReq.SWORD:   return weapon_id == "kiem"
		WeaponReq.PICKAXE: return weapon_id == "cup"
	return false

func _hit_flash() -> void:
	for mi in _get_mesh_instances():
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color.WHITE
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var orig := mi.material_override
		mi.material_override = mat
		var tween := create_tween()
		tween.tween_interval(0.08)
		tween.tween_callback(func():
			if is_instance_valid(mi):
				mi.material_override = orig
		)

func _get_mesh_instances() -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	for ch in get_children(true):
		if ch is MeshInstance3D:
			result.append(ch)
		_collect_mi(ch, result)
	return result

static func _collect_mi(node: Node, result: Array[MeshInstance3D]) -> void:
	for ch in node.get_children(true):
		if ch is MeshInstance3D:
			result.append(ch)
		_collect_mi(ch, result)

func _spawn_damage_number(dmg: int) -> void:
	var world := get_tree().current_scene if get_tree() else null
	if world == null:
		return
	var dn := FloatingDamage.new()
	world.add_child(dn)
	dn.setup(dmg, global_position + Vector3(0, 1.5, 0), Color.WHITE)

func _die() -> void:
	_destroyed = true
	spawn_drop()
	_on_destroy()
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector3.ZERO, 0.25).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "position:y", position.y + 0.5, 0.25)
	tween.tween_interval(0.3)
	tween.tween_callback(queue_free)

func _spawn_drop_velocity() -> Vector3:
	return Vector3(randf_range(-1.5, 1.5), randf_range(2.0, 3.5), randf_range(-1.5, 1.5))

func _on_destroy() -> void:
	pass

func set_drop(item_id: String) -> void:
	drop_item_id = item_id

func spawn_drop() -> void:
	if drop_item_id == "":
		return
	var world := _find_world_manager()
	if world == null:
		return
	ItemDatabase.ensure_db()
	var def: ItemDef = ItemDatabase.items_db.get(drop_item_id)
	if def != null:
		DroppedItem.spawn(world, def, global_position, 1, _spawn_drop_velocity(), global_position.y)

func _find_world_manager() -> Node3D:
	var p := get_parent()
	while p != null:
		if p is OpenWorldManager:
			return p
		p = p.get_parent()
	return null