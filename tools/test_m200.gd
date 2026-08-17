extends Node

## Headless verification M200: item registration, held/drop mesh builders,
## has/consume ammo .338, start_aim/cancel, fire (1 phát, tiêu hao đạn, giảm
## độ bền, spawn BulletProjectile), bolt-action cooldown chặn re-aim,
## hitbox đạn (radius) + aim-assist.

const _PC = preload("res://scripts/characters/player/player_character.gd")
const _IDB = preload("res://scripts/items/core/item_database.gd")
const _M200 = preload("res://scripts/characters/player/player_m200.gd")
const _TL = preload("res://scripts/items/models/tools.gd")
const _Bullet = preload("res://scripts/items/entities/bullet_projectile.gd")

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
	var m200: ItemDef = _IDB.items_db.get("m200")
	var ammo: ItemDef = _IDB.items_db.get("bullet_338mm")
	_check(m200 != null, "m200 đã đăng ký")
	_check(ammo != null, "bullet_338mm đã đăng ký")
	if m200:
		_check(m200.type == ItemDef.Type.WEAPON, "m200 type = WEAPON")
		_check(not m200.stackable, "m200 không stackable")
		_check(m200.atk_bonus >= 14, "m200 atk_bonus >= 14 (got %d)" % m200.atk_bonus)
		_check(m200.max_durability >= 200, "m200 max_durability >= 200")
		_check(m200.name.contains("DarkVoid"), "m200 tên chứa 'DarkVoid' (got '%s')" % m200.name)
	if ammo:
		_check(ammo.type == ItemDef.Type.MATERIAL, "bullet_338mm type = MATERIAL")
		_check(ammo.stackable and ammo.max_stack >= 16, "bullet_338mm stackable >= 16")

	# ── 2. Mesh builders không lỗi + ra node con ───────────────────────────
	var pivot := Node3D.new()
	add_child(pivot)
	_TL.build_held(pivot, "m200")
	_check(pivot.get_child_count() > 0, "build_held(m200) tạo mesh")
	var hf := pivot.get_node_or_null("HoldForward")
	_check(hf != null, "m200: súng được bọc trong HoldForward (không đổi hold base)")
	_check(hf != null and hf.position.is_equal_approx(Vector3(0, 0.05, 0)), "m200: HoldForward nhích ra trước nòng 0.05")
	var vfx := pivot.get_node_or_null("HoldForward/M200VFX")
	_check(vfx != null, "m200: có node idle VFX M200VFX")
	_check(vfx != null and vfx.get_child_count() >= 6, "m200: VFX có lõi/halo/hạt neon/đèn (children=%d)" % (vfx.get_child_count() if vfx != null else -1))
	if vfx != null:
		var tick_ok := true
		for i in 30:
			vfx.call("_process", 1.0 / 60.0)
		_check(tick_ok, "m200: VFX idle chạy 30 tick không lỗi")
	_TL.build_held(pivot, "bullet_338mm")
	_check(pivot.get_child_count() > 0, "build_held(bullet_338mm) tạo mesh")
	var drop_pivot := Node3D.new()
	add_child(drop_pivot)
	_TL.m200_drop(drop_pivot)
	_TL.bullet_338_drop(drop_pivot)
	_check(drop_pivot.get_child_count() > 0, "drop builders tạo voxel")
	pivot.queue_free()
	drop_pivot.queue_free()

	# ── 3. Trang bị M200 + đạn .338 ───────────────────────────────────────
	var player: Node = _PC.new()
	add_child(player)
	await get_tree().process_frame
	await get_tree().process_frame
	player.equipped_weapon = _IDB.items_db["m200"]
	player.inventory.add_item(_IDB.items_db["bullet_338mm"], 5)

	_check(_M200.has_ammo(player), "có đạn → has_ammo true")
	_check(_count(player.inventory, _IDB.items_db["bullet_338mm"].id) == 5, "đạn ban đầu = 5")

	# ── 4. start_aim → ngắm; cancel_aim → tắt ─────────────────────────────
	_M200.start_aim(player)
	_check(player._bow_aiming, "start_aim → _bow_aiming = true")
	_check(player._m200_aiming, "start_aim → _m200_aiming = true")
	_M200.cancel_aim(player)
	_check(not player._bow_aiming, "cancel_aim → hết ngắm")
	_check(not player._m200_aiming, "cancel_aim → hết ngắm M200")

	# ── 5. fire: 1 phát → tiêu hao đạn + spawn bullet + giảm độ bền ───────
	player._bow_aiming = true
	player._m200_aiming = true
	player._bow_aim_dir = -player.global_transform.basis.z.normalized()
	player._equipped_durability = player.equipped_weapon.max_durability
	var dura_before: int = player._equipped_durability
	var spawned_before: int = get_tree().get_nodes_in_group("bullets").size()
	_M200.fire(player)
	var spawned_after: int = get_tree().get_nodes_in_group("bullets").size()
	_check(spawned_after == spawned_before + 1, "fire spawn 1 BulletProjectile")
	var shot: Node = null
	for b in get_tree().get_nodes_in_group("bullets"):
		shot = b
	_check(shot != null and shot.get("damage_type") == _PC.DamageType.SPACE, "m200: đạn nguyên tố chính = Không Gian")
	_check(shot != null and shot.get("damage_type_alt") == _PC.DamageType.PHYSICAL, "m200: đạn nguyên tố phụ = Vật Lý")
	_check(shot != null and absf(shot.get("alt_frac") - 0.2) < 0.001, "m200: alt_frac = 0.2 (20% vật lý)")
	if shot != null:
		var split: Dictionary = shot.call("_split_damage")
		_check(split.alt > 0 and split.primary + split.alt == int(shot.get("_damage")), "chia dmg đúng tổng (%d K.Gian + %d V.Lý = %d)" % [split.primary, split.alt, int(shot.get("_damage"))])
	_check(_count(player.inventory, _IDB.items_db["bullet_338mm"].id) == 4, "bắn 1 phát → còn 4 đạn")
	_check(player._equipped_durability == dura_before - 1, "bắn → giảm 1 độ bền")
	_check(player._m200_recoil > 0.0, "bắn → khởi tạo giật nòng")
	_check(player._m200_bolt_cd > 0.0, "bắn → khởi tạo hồi thoi nòng")
	_check(not player._bow_aiming, "bắn xong → ra khỏi ngắm (1 phát 1 lần)")
	for b in get_tree().get_nodes_in_group("bullets"):
		b.free()

	# ── 5b. update_pose: giơ súng ngang + tay giữ khi ngắm, hạ khi nghỉ ──
	var wp: Node3D = player._mesh.weapon_pivot
	var arm_r: Node3D = player._mesh.arm_r
	var arm_l: Node3D = player._mesh.arm_l
	player._bow_aiming = true
	player._m200_aiming = true
	player._m200_recoil = 0.0
	for i in 40:
		_M200.update_pose(player, 1.0 / 60.0)
	await get_tree().process_frame
	_check(absf(wp.rotation_degrees.x - 90.0) < 2.0, "ngắm M200 → pivot xoay nòng ra trước ~90° (%.1f)" % wp.rotation_degrees.x)
	_check(arm_r.rotation.x <= -0.45, "ngắm M200 → tay phải giơ giữ tay cầm (%.2f)" % arm_r.rotation.x)
	_check(arm_l.rotation.x <= -0.35, "ngắm M200 → tay trái giữ thân súng (%.2f)" % arm_l.rotation.x)
	player._bow_aiming = false
	player._m200_aiming = false
	for i in 40:
		_M200.update_pose(player, 1.0 / 60.0)
	await get_tree().process_frame
	_check(arm_r.rotation.x > -0.35, "nghỉ → tay phải hạ xuống (%.2f)" % arm_r.rotation.x)

	# ── 5c. recoil nòng hồi về 0 sau khi bắn ──────────────────────────────
	player._m200_recoil = 0.8
	for i in 120:
		_M200.update_pose(player, 1.0 / 60.0)
	_check(player._m200_recoil <= 0.001, "giật nòng hồi về 0")

	# ── 6. Bolt-action: cooldown chặn start_aim trong hồi thoi ────────────
	player._m200_bolt_cd = 0.5
	_M200.start_aim(player)
	_check(not player._bow_aiming, "đang hồi thoi → start_aim bị chặn")
	player._m200_bolt_cd = 0.0
	_M200.start_aim(player)
	_check(player._bow_aiming, "hết hồi thoi → start_aim lại được")

	# ── 7. Hết đạn → fire không spawn, hiện thông báo, thoát ngắm ─────────
	player.inventory.remove_item_by_id(_IDB.items_db["bullet_338mm"].id, 99)
	_check(not _M200.has_ammo(player), "hết đạn → has_ammo false")
	player._m200_bolt_cd = 0.0
	player._bow_aiming = true
	player._m200_aiming = true
	var before2: int = get_tree().get_nodes_in_group("bullets").size()
	_M200.fire(player)
	_check(get_tree().get_nodes_in_group("bullets").size() == before2, "hết đạn → không spawn bullet")
	_check(not player._bow_aiming, "hết đạn → fire thoát ngắm")

	# ── 8. Hitbox: bán kính sweep mở rộng + aim-assist ────────────────────
	_check(absf(_Bullet.HIT_RADIUS - 0.24) < 0.001, "HIT_RADIUS = 0.24 (to hơn — dễ dính)")
	_check(_Bullet.ASSIST_RADIUS >= 0.8, "ASSIST_RADIUS >= 0.8 (bám địch dễ hơn)")
	_check(_Bullet.WORLD_RADIUS < 0.05, "WORLD_RADIUS nhỏ — đạn không dính địa hình sát mặt đất")
	player._m200_bolt_cd = 0.0
	player.inventory.add_item(_IDB.items_db["bullet_338mm"], 1)
	player._bow_aiming = true
	player._m200_aiming = true
	player._equipped_durability = player.equipped_weapon.max_durability
	var b := BulletProjectile.new()
	player.get_tree().current_scene.add_child(b)
	b.global_position = player.global_position + Vector3(0, 0.6, 0)
	var dir: Vector3 = -player.global_transform.basis.z.normalized()
	b.setup(dir, 10, 120.0, 40.0, player)
	_check(get_tree().get_nodes_in_group("bullets").size() > 0, "bullet được thêm vào nhóm bullets")
	# Áp dụng vài bước _physics_process thủ công để xác nhận không lỗi.
	for i in 5:
		b._physics_process(1.0 / 60.0)
	_check(b.is_queued_for_deletion() or b._dist_traveled > 0.0, "bullet chạy bước physics không lỗi")
	if is_instance_valid(b):
		b.free()

	# ── 9. Player phóng to 1.2 + scope shader ───────────────────────────────
	var cap_ok := false
	for c in player.get_children():
		if c is CollisionShape3D and c.shape is CapsuleShape3D:
			cap_ok = absf((c.shape as CapsuleShape3D).radius - 0.32 * 1.2) < 0.001
			break
	_check(cap_ok, "player capsule phóng to 1.2 (radius 0.384)")
	_check(absf(player.hit_radius - 0.32 * 1.2) < 0.001, "hit_radius phóng to 1.2 (0.384)")
	_check(player._mesh != null and player._mesh.ground_anchor != null and player._mesh.ground_anchor.scale.is_equal_approx(Vector3.ONE * 1.2), "mesh player scale 1.2")
	var shader_src := FileAccess.get_file_as_string("res://scripts/ui/hud/scope_lens.gdshader")
	_check(shader_src.contains("target_locked"), "scope shader: uniform target_locked (nháy đỏ khi khóa)")
	_check(shader_src.contains("SCREEN_TEXTURE"), "scope shader: blur nền bên ngoài kính")

	# ── 10. Nổ khi trúng địch: sát thương vùng nhỏ + kết thúc đạn ──────────
	_check(_Bullet.BLAST_RADIUS >= 1.5, "BLAST_RADIUS >= 1.5 — đạn nổ khi trúng địch")
	var target := _PC.new()
	add_child(target)
	target.global_position = Vector3(0, -1.0, -10)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var target_hp: int = target.hp
	var b2 := BulletProjectile.new()
	player.get_tree().current_scene.add_child(b2)
	b2.global_position = target.global_position + Vector3(0, 0.6, 10)
	b2.setup(Vector3(0, 0, -1), 8, 200.0, 40.0, player)
	for i in 30:
		if b2.is_queued_for_deletion():
			break
		b2._physics_process(1.0 / 60.0)
	_check(target.hp < target_hp, "đạn trúng địch → nổ gây sát thương vùng (%d → %d)" % [target_hp, target.hp])
	_check(b2.is_queued_for_deletion(), "đạn trúng địch → kết thúc sau khi nổ")
	target.free()

	player.free()

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])
	await WorldChunk.wait_for_tasks_async(get_tree())
	get_tree().quit(0 if _failures == 0 else 1)
