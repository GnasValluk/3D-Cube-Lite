class_name PlayerM200
extends RefCounted

## Súng bắn tỉa M200 — 1 phát 1 lần: giữ chuột trái ngắm kính (ADS + scope),
## nhả chuột trái để bắn, sau đó hồi thoi nòng ~1s mới ngắm bắn tiếp.
## Tiêu hao đạn .338 Lapua mỗi phát.

const M200_BULLET_SPEED: float = 150.0
const M200_RANGE: float = 120.0
const M200_SPREAD_DEG: float = 0.12
const M200_BOLT_TIME: float = 1.0

static func has_ammo(player) -> bool:
	if player.inventory == null:
		return false
	for slot in player.inventory.slots:
		if not slot.is_empty() and slot.item.id == "bullet_338mm":
			return true
	return false

static func consume_ammo(player) -> bool:
	if player.inventory == null:
		return false
	for i in range(player.inventory.slots.size()):
		var slot: ItemSlot = player.inventory.slots[i]
		if not slot.is_empty() and slot.item.id == "bullet_338mm":
			player.inventory.remove_item(i, 1)
			return true
	return false

## Giữ chuột trái → vào tư thế ngắm (ADS + scope overlay). Chặn nếu đang hồi thoi.
static func start_aim(player) -> void:
	if player.equipped_weapon == null or player.equipped_weapon.id != "m200":
		return
	if player._m200_bolt_cd > 0.0:
		return
	player._bow_aiming = true
	player._m200_aiming = true
	player._bow_charge = 0.0
	player._m200_recoil = 0.0
	if player._bow_indicator_root:
		player._bow_indicator_root.visible = false

## Nhả chuột trái → bắn 1 phát. Xong thì ra khỏi ngắm + hồi thoi nòng.
static func fire(player) -> void:
	if player.equipped_weapon == null or player.equipped_weapon.id != "m200":
		return
	if not player._bow_aiming:
		return
	if player._m200_bolt_cd > 0.0:
		return
	# Hết băng: tự nạp; không có dự trữ mới báo.
	if player._mag_ammo <= 0:
		if player._count_reserve("bullet_338mm") > 0:
			player._start_reload()
		else:
			player._scroll_inventory_message(player.tr("NO_M200_AMMO"))
			cancel_aim(player)
		return
	player._mag_ammo -= 1
	player._damage_equipped_tool(1)

	var base_dmg: int = player.attack_power + (player.equipped_weapon.atk_bonus if player.equipped_weapon else 16)

	var spawn_from: Vector3 = player.global_position + Vector3(0, 0.6, 0) + player._bow_aim_dir * 0.5
	if player._mesh and player._mesh.weapon_pivot:
		spawn_from = player._mesh.weapon_pivot.global_transform * Vector3(0, 0.44, 0)

	var aim_dir: Vector3 = player._bow_aim_dir
	if player._aim_tp_mode and player._aim_world_point != Vector3.ZERO:
		var to_tgt: Vector3 = player._aim_world_point - spawn_from
		if to_tgt.length_squared() > 0.01:
			aim_dir = to_tgt.normalized()
	if aim_dir.length_squared() < 0.001:
		aim_dir = -player.global_transform.basis.z

	var spread := deg_to_rad(M200_SPREAD_DEG)
	var up_ref := Vector3.UP
	if absf(aim_dir.dot(up_ref)) > 0.98:
		up_ref = Vector3.RIGHT
	var right := aim_dir.cross(up_ref).normalized()
	var up2 := right.cross(aim_dir).normalized()
	var dir := (aim_dir + right * randf_range(-spread, spread) + up2 * randf_range(-spread, spread)).normalized()

	var bullet := BulletProjectile.new()
	bullet.calibre = ".338"
	# DarkVoid: 80% Dmg Không Gian + 20% Dmg Vật Lý.
	bullet.damage_type = CharacterBase.DamageType.SPACE
	bullet.damage_type_alt = CharacterBase.DamageType.PHYSICAL
	bullet.alt_frac = 0.2
	var world: Node = player.get_tree().current_scene
	if world:
		world.add_child(bullet)
	else:
		player.add_child(bullet)
	bullet.global_position = spawn_from + dir * 0.3
	bullet.setup(dir, base_dmg, M200_BULLET_SPEED, M200_RANGE, player)

	SFXManager.play_gun_shot()
	_muzzle_flash(player, spawn_from, dir)
	player._m200_bolt_cd = M200_BOLT_TIME
	cancel_aim(player)
	_kick(player, dir)
	# Bắn tỉa: giật mạnh → rung màn hình đậm
	player.camera_shake(0.16, 0.32)

## Pose cầm/ngắm M200 — đầy đủ: scope ADS đưa kính lên mắt, lắc thở/bước,
## GIẬT MẠNH khi bắn, và TAY TRÁI LÊN ĐẠN THOI trong 1s sau mỗi phát.
static func update_pose(player, delta: float) -> void:
	if player._mesh == null or player._mesh.weapon_pivot == null or player._mesh.arm_r == null:
		return
	if player.equipped_weapon == null or player.equipped_weapon.id != "m200":
		if player._m200_recoil > 0.0:
			player._m200_recoil = 0.0
		return
	var wp: Node3D = player._mesh.weapon_pivot
	if not player._m200_hold_captured:
		player._m200_hold_base = wp.position
		player._m200_hold_captured = true
	var is_aiming: bool = player._m200_aiming or player._bow_aiming
	player._gun_ads_blend = lerpf(player._gun_ads_blend, 1.0 if is_aiming else 0.0, minf(1.0, delta * 9.0))
	var ads: float = player._gun_ads_blend

	player._m200_recoil = maxf(player._m200_recoil - delta * 2.2, 0.0)

	# ── BÙ NGHỊCH GÓC TAY — nòng luôn NGANG (ε = 90° − Σ ⇒ wp = 90° − tổng) ──
	# Tư thế tay mục tiêu: ngắm kính (-0.66, -1.40) / hạ súng (-0.30, -1.05).
	var arm_sum_t: float = lerpf(-1.35, -2.06, ads)
	var t: float = player._time
	var speed: float = Vector2(player.velocity.x, player.velocity.z).length()
	var move_k: float = clampf(speed / max(player.move_speed, 0.1), 0.0, 1.5)
	var gait: float = player._anim._gait_phase if player._anim != null else t * 6.0
	var target_rot: Vector3 = Vector3(90.0 - rad_to_deg(arm_sum_t), 0, 0)
	target_rot.x += 14.0 * (1.0 - ads)                             # nghỉ: mũi chúi 14°
	target_rot.x -= player._m200_recoil * 4.5                      # giật: nòng hốc LÊN mạnh
	target_rot.z += sin(gait) * 1.6 * move_k * (1.0 - ads * 0.75)
	target_rot.x += sin(t * 2.1) * 0.5 * (1.0 - ads * 0.85)
	wp.rotation_degrees = wp.rotation_degrees.lerp(target_rot, 0.18)

	var aim: Vector3 = player._bow_aim_dir
	if aim.length_squared() < 0.001:
		aim = -player.global_transform.basis.z
	var kick: Vector3 = -aim * (player._m200_recoil * 0.09)
	kick.y -= player._m200_recoil * 0.04
	var sway := Vector3(
		sin(t * 1.7) * 0.004 + cos(gait * 0.5) * 0.007 * move_k,
		sin(t * 2.3) * 0.003 + abs(sin(gait)) * 0.009 * move_k,
		0.0)
	sway *= (1.0 - ads * 0.82)   # ngắm kính → gần như bất động
	var ads_raise := Vector3(-0.02, 0.13, 0.07) * ads   # kính lên tầm mắt
	wp.position = wp.position.lerp(player._m200_hold_base + kick + sway + ads_raise, delta * 14.0)

	if is_aiming:
		# Ngắm kính: má áp báng, tay trái ôm ốp lót phía trước
		player._mesh.arm_r.rotation.x = lerp(player._mesh.arm_r.rotation.x, -0.66, 0.15)
		player._mesh.arm_r.rotation.z = lerp(player._mesh.arm_r.rotation.z, -0.05, 0.12)
		player._mesh.elbow_r.rotation.x = lerp(player._mesh.elbow_r.rotation.x, -1.40, 0.10)
		player._mesh.arm_l.rotation.x = lerp(player._mesh.arm_l.rotation.x, -0.58, 0.15)
		player._mesh.arm_l.rotation.z = lerp(player._mesh.arm_l.rotation.z, 0.26, 0.12)
		player._mesh.elbow_l.rotation.x = lerp(player._mesh.elbow_l.rotation.x, -1.20, 0.10)
	else:
		player._mesh.arm_r.rotation.x = lerp(player._mesh.arm_r.rotation.x, -0.30, 0.12)
		player._mesh.arm_r.rotation.z = lerp(player._mesh.arm_r.rotation.z, -0.08, 0.12)
		player._mesh.elbow_r.rotation.x = lerp(player._mesh.elbow_r.rotation.x, -1.05, 0.10)
		player._mesh.arm_l.rotation.x = lerp(player._mesh.arm_l.rotation.x, -0.20, 0.12)
		player._mesh.arm_l.rotation.z = lerp(player._mesh.arm_l.rotation.z, 0.14, 0.12)
		player._mesh.elbow_l.rotation.x = lerp(player._mesh.elbow_l.rotation.x, -0.95, 0.10)

	# ── Chu kỳ LÊN ĐẠN THOI (1s sau bắn): tay trái rút cần gạt + thân hơi xoay ──
	if player._m200_bolt_cd > 0.0:
		var p: float = 1.0 - (player._m200_bolt_cd / M200_BOLT_TIME)   # 0→1
		var pump: float = sin(p * PI)   # lên rồi về
		player._mesh.arm_l.rotation.x += pump * -0.38   # tay trái vung ra thao tác
		player._mesh.arm_l.rotation.z += pump * 0.18
		player._mesh.elbow_l.rotation.x += pump * -0.30
		wp.rotation_degrees.z += pump * 5.0             # súng nghiêng nhẹ nhả thoi
		mesh_head_duck(player, pump, delta)

## Cúi đầu né nhẹ sang phải lúc tay trái thao tác thoi nòng.
static func mesh_head_duck(player, pump: float, delta: float) -> void:
	if player._mesh == null or player._mesh.head == null:
		return
	player._mesh.head.rotation.z = lerp(player._mesh.head.rotation.z,
		pump * 0.14, minf(1.0, delta * 10.0))

## Ánh lửa nòng nhỏ gọn: lõi + chùm nón + vài tia lửa.
static func _muzzle_flash(player, pos: Vector3, dir: Vector3) -> void:
	var world: Node = player.get_tree().current_scene
	if world == null:
		return
	var core_mat := MeshBuilder.emit_mat(
		Color(1.0, 0.9, 0.55, 1.0),
		Color(1.0, 0.8, 0.4), 8.0)
	core_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var core := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.06
	sph.height = 0.12
	core.mesh = sph
	core.material_override = core_mat
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(core)
	core.global_position = pos
	var tw: Tween = core.create_tween()
	tw.tween_property(core, "scale", Vector3(0.34, 0.34, 0.34), 0.05)
	tw.tween_property(core, "scale", Vector3(0.10, 0.10, 0.10), 0.10).set_delay(0.05)
	tw.tween_property(core_mat, "albedo_color:a", 0.0, 0.10).set_delay(0.05)
	tw.tween_property(core_mat, "emission_energy_multiplier", 0.0, 0.10).set_delay(0.05)
	tw.tween_callback(core.queue_free).set_delay(0.16)

	var flame_mat := MeshBuilder.emit_mat(
		Color(1.0, 0.7, 0.3, 0.9),
		Color(1.0, 0.6, 0.2), 7.0)
	flame_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flame_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var flame := MeshInstance3D.new()
	var fmesh := CylinderMesh.new()
	fmesh.top_radius = 0.015
	fmesh.bottom_radius = 0.05
	fmesh.height = 0.34
	fmesh.radial_segments = 8
	flame.mesh = fmesh
	flame.material_override = flame_mat
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(flame)
	flame.global_position = pos + dir * 0.15
	flame.global_basis = PlayerAK._align_y_to(flame.global_basis, dir)
	var ftw: Tween = flame.create_tween().set_parallel()
	ftw.tween_property(flame, "scale", Vector3(1.4, 1.6, 1.4), 0.05)
	ftw.tween_property(flame_mat, "albedo_color:a", 0.0, 0.11)
	ftw.tween_property(flame_mat, "emission_energy_multiplier", 0.0, 0.11)
	ftw.tween_callback(flame.queue_free).set_delay(0.12)

	for i in 4:
		var spark_mat := MeshBuilder.emit_mat(
			Color(1.0, 0.75, 0.3, 1.0),
			Color(1.0, 0.65, 0.25), 6.0)
		spark_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var spark := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.012
		sm.height = 0.024
		spark.mesh = sm
		spark.material_override = spark_mat
		spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world.add_child(spark)
		spark.global_position = pos + dir * 0.08
		var sdir := (dir + PlayerAK._rand_side(dir) * randf_range(-0.6, 0.6)).normalized()
		var stw: Tween = spark.create_tween().set_parallel()
		stw.tween_property(spark, "global_position", spark.global_position + sdir * randf_range(0.35, 0.7), 0.10)
		stw.tween_property(spark_mat, "albedo_color:a", 0.0, 0.10)
		stw.tween_property(spark_mat, "emission_energy_multiplier", 0.0, 0.10)
		stw.tween_callback(spark.queue_free).set_delay(0.11)

static func _kick(player, _dir: Vector3) -> void:
	player._m200_recoil = minf(player._m200_recoil + 0.85, 1.0)

static func cancel_aim(player) -> void:
	player._bow_aiming = false
	player._m200_aiming = false
	player._bow_charge = 0.0
	player._aim_tp_mode = false
	player._m200_recoil = 0.0
	if player._bow_indicator_root:
		player._bow_indicator_root.visible = false