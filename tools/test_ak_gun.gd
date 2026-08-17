extends Node

## Headless verification AK-12: item registration, held/drop mesh builders,
## has/consume ammo, start/cancel aim, fire_shot spawns BulletProjectile +
## tiêu hao đạn + giảm độ bền.

const _PC = preload("res://scripts/characters/player/player_character.gd")
const _IDB = preload("res://scripts/items/core/item_database.gd")
const _AK = preload("res://scripts/characters/player/player_ak.gd")
const _TL = preload("res://scripts/items/models/tools.gd")

var _failures: int = 0

func _check(cond: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures += 1

func _count(inv, item_id: String) -> int:
	var total := 0
	for slot in inv.slots:
		if not slot.is_empty() and slot.item.id == item_id:
			total += slot.count
	return total

func _ready() -> void:
	seed(20260816)

	# ── 1. Đăng ký item ────────────────────────────────────────────────────
	_IDB.ensure_db()
	var ak: ItemDef = _IDB.items_db.get("ak_12")
	var ammo: ItemDef = _IDB.items_db.get("bullet_762mm")
	_check(ak != null, "ak_12 đã đăng ký")
	_check(ammo != null, "bullet_762mm đã đăng ký")
	if ak:
		_check(ak.type == ItemDef.Type.WEAPON, "ak_12 type = WEAPON")
		_check(not ak.stackable, "ak_12 không stackable")
		_check(ak.atk_bonus >= 7, "ak_12 atk_bonus >= 7 (got %d)" % ak.atk_bonus)
		_check(ak.max_durability >= 200, "ak_12 max_durability >= 200")
		_check(ak.name.contains("Thunderbolt"), "ak_12 tên chứa 'Thunderbolt' (got '%s')" % ak.name)
	if ammo:
		_check(ammo.type == ItemDef.Type.MATERIAL, "bullet_762mm type = MATERIAL")
		_check(ammo.stackable and ammo.max_stack >= 16, "bullet_762mm stackable >= 16")

	# ── 2. Mesh builders không lỗi + ra node con ───────────────────────────
	var pivot := Node3D.new()
	add_child(pivot)
	_TL.build_held(pivot, "ak_12")
	_check(pivot.get_child_count() > 0, "build_held(ak_12) tạo mesh")
	var hf := pivot.get_node_or_null("HoldForward")
	_check(hf != null, "ak_12: súng được bọc trong HoldForward (không đổi hold base)")
	_check(hf != null and hf.position.is_equal_approx(Vector3(0, 0.05, 0)), "ak_12: HoldForward nhích ra trước nòng 0.05")
	var ak_vfx := pivot.get_node_or_null("HoldForward/AK12VFX")
	_check(ak_vfx != null, "ak_12: có node idle VFX AK12VFX")
	_check(ak_vfx != null and ak_vfx.get_child_count() >= 6, "ak_12: VFX có lõi/halo/hạt neon/đèn (children=%d)" % (ak_vfx.get_child_count() if ak_vfx != null else -1))
	_TL.build_held(pivot, "bullet_762mm")
	_check(pivot.get_child_count() > 0, "build_held(bullet_762mm) tạo mesh")
	var drop_pivot := Node3D.new()
	add_child(drop_pivot)
	_TL.ak12_drop(drop_pivot)
	_TL.bullet_762_drop(drop_pivot)
	_check(drop_pivot.get_child_count() > 0, "drop builders tạo voxel")
	pivot.queue_free()
	drop_pivot.queue_free()

	# ── 3. Trang bị AK-12 + đạn ───────────────────────────────────────────
	var player: Node = _PC.new()
	add_child(player)
	await get_tree().process_frame
	await get_tree().process_frame
	player.equipped_weapon = _IDB.items_db["ak_12"]
	player.inventory.add_item(_IDB.items_db["bullet_762mm"], 10)

	_check(_AK.has_ammo(player), "có đạn → has_ammo true")
	var before: int = _count(player.inventory, _IDB.items_db["bullet_762mm"].id)
	_check(before == 10, "đạn ban đầu = 10")

	# ── 4. start_fire → ngắm + indicator; cancel_aim → tắt ────────────────
	_AK.start_fire(player)
	_check(player._bow_aiming, "start_fire → _bow_aiming = true")
	_check(player._bow_indicator_root != null and player._bow_indicator_root.visible, "indicator hiển thị")
	_AK.cancel_aim(player)
	_check(not player._bow_aiming, "cancel_aim → hết ngắm")
	_check(player._bow_indicator_root == null or not player._bow_indicator_root.visible, "indicator ẩn")

	# ── 5. fire_shot: tiêu hao đạn + spawn BulletProjectile + giảm độ bền ─
	player._bow_aiming = true
	player._bow_aim_dir = -player.global_transform.basis.z.normalized()
	player._equipped_durability = player.equipped_weapon.max_durability
	var dura_before: int = player._equipped_durability
	var spawned_before: int = get_tree().get_nodes_in_group("bullets").size()
	_AK.fire_shot(player)
	var spawned_after: int = get_tree().get_nodes_in_group("bullets").size()
	_check(spawned_after == spawned_before + 1, "fire_shot spawn 1 BulletProjectile")
	_check(_count(player.inventory, _IDB.items_db["bullet_762mm"].id) == 9, "bắn 1 phát → còn 9 đạn")
	_check(player._equipped_durability == dura_before - 1, "bắn → giảm 1 độ bền")
	_check(player._ak_recoil > 0.0, "bắn → khởi tạo giật nòng")
	var shot_bullet: Node = null
	for b in get_tree().get_nodes_in_group("bullets"):
		if b.is_inside_tree():
			shot_bullet = b
			break
	_check(shot_bullet != null and shot_bullet.get("calibre") == "7.62", "đạn calibre 7.62")
	_check(shot_bullet != null and shot_bullet.get("damage_type") == _PC.DamageType.LIGHTNING, "ak: đạn nguyên tố chính = Lôi")
	_check(shot_bullet != null and shot_bullet.get("damage_type_alt") == _PC.DamageType.PHYSICAL, "ak: đạn nguyên tố phụ = Vật Lý")
	_check(shot_bullet != null and absf(shot_bullet.get("alt_frac") - 0.2) < 0.001, "ak: alt_frac = 0.2 (20% lôi)")
	if shot_bullet != null:
		var split: Dictionary = shot_bullet.call("_split_damage")
		_check(split.alt > 0 and split.primary + split.alt == int(shot_bullet.get("_damage")), "chia dmg đúng tổng (%d Lôi + %d V.Lý = %d)" % [split.primary, split.alt, int(shot_bullet.get("_damage"))])
	for b in get_tree().get_nodes_in_group("bullets"):
		b.free()

	# ── 5b. update_pose: giơ súng ngang + tay giữ khi ngắm, hạ khi nghỉ ──
	var wp: Node3D = player._mesh.weapon_pivot
	var arm_r: Node3D = player._mesh.arm_r
	var arm_l: Node3D = player._mesh.arm_l
	player._bow_aiming = true
	player._ak_recoil = 0.0
	for i in 40:
		_AK.update_pose(player, 1.0 / 60.0)
	await get_tree().process_frame
	_check(absf(wp.rotation_degrees.x - 90.0) < 2.0, "ngắm AK → pivot xoay nòng ra trước ~90° (%.1f)" % wp.rotation_degrees.x)
	_check(arm_r.rotation.x <= -0.40, "ngắm AK → tay phải giơ giữ tay cầm (%.2f)" % arm_r.rotation.x)
	_check(arm_l.rotation.x <= -0.30, "ngắm AK → tay trái giữ thân súng (%.2f)" % arm_l.rotation.x)
	player._bow_aiming = false
	for i in 40:
		_AK.update_pose(player, 1.0 / 60.0)
	await get_tree().process_frame
	_check(arm_r.rotation.x > -0.35, "nghỉ → tay phải hạ xuống (%.2f)" % arm_r.rotation.x)

	# ── 5c. recoil nòng hồi về 0 sau khi bắn ──────────────────────────────
	player._ak_recoil = 0.8
	player._bow_aiming = true
	for i in 120:
		_AK.update_pose(player, 1.0 / 60.0)
	_check(player._ak_recoil <= 0.001, "giật nòng hồi về 0")

	# ── 5d. bắn liên tục → súng không trôi khỏi vị trí cầm gốc ────────────
	player._ak_hold_captured = false
	player._ak_recoil = 0.0
	for i in 60:
		_AK.update_pose(player, 1.0 / 60.0)
	var base_hold: Vector3 = player._mesh.weapon_pivot.position
	player._bow_aim_dir = -player.global_transform.basis.z.normalized()
	for shot in 30:
		player.inventory.add_item(_IDB.items_db["bullet_762mm"], 1)
		player._equipped_durability = player.equipped_weapon.max_durability
		_AK.fire_shot(player)
		for i in 4:
			_AK.update_pose(player, 1.0 / 60.0)
	for b in get_tree().get_nodes_in_group("bullets"):
		b.free()
	for i in 240:
		_AK.update_pose(player, 1.0 / 60.0)
	var drift: float = player._mesh.weapon_pivot.position.distance_to(base_hold)
	_check(drift < 0.01, "bắn 30 phát liên tục → pivot về đúng vị trí cầm (drift=%.4f)" % drift)

	# ── 6. Hết đạn → chuyển ngắm, không spawn ─────────────────────────────
	player.inventory.remove_item_by_id(_IDB.items_db["bullet_762mm"].id, 99)
	_check(not _AK.has_ammo(player), "hết đạn → has_ammo false")
	_AK.cancel_aim(player)
	_AK.start_fire(player)
	_check(player._bow_aiming, "hết đạn → ADS vẫn bật được (RMB toggle)")
	var before2: int = get_tree().get_nodes_in_group("bullets").size()
	_AK.update_fire(player, 1.0 / 60.0)
	_check(player._bow_aiming, "không giữ LMB → update_fire giữ nguyên ADS")
	_AK.fire_shot(player)
	_check(not player._bow_aiming, "hết đạn → fire_shot hủy ngắm")
	_check(get_tree().get_nodes_in_group("bullets").size() == before2, "hết đạn → không spawn bullet")
	player.free()

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	await WorldChunk.wait_for_tasks_async(get_tree())
	get_tree().quit(0 if _failures == 0 else 1)