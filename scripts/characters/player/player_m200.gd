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
	if not consume_ammo(player):
		player._scroll_inventory_message(player.tr("NO_M200_AMMO"))
		cancel_aim(player)
		return
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

## Pose cầm/ngắm M200: giơ súng cao hơn AK, ngả nhẹ khi giật, hạ thấp khi nghỉ.
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
	player._m200_recoil = maxf(player._m200_recoil - delta * 3.0, 0.0)
	var target_rot: Vector3 = Vector3(90, 0, 0)
	target_rot.x += player._m200_recoil * 3.0
	wp.rotation_degrees = wp.rotation_degrees.lerp(target_rot, 0.15)
	var aim: Vector3 = player._bow_aim_dir
	if aim.length_squared() < 0.001:
		aim = -player.global_transform.basis.z
	var kick: Vector3 = -aim * (player._m200_recoil * 0.06)
	kick.y -= player._m200_recoil * 0.03
	wp.position = wp.position.lerp(player._m200_hold_base + kick, delta * 14.0)
	if is_aiming:
		player._mesh.arm_r.rotation.x = lerp(player._mesh.arm_r.rotation.x, -0.58, 0.15)
		player._mesh.arm_r.rotation.z = lerp(player._mesh.arm_r.rotation.z, -0.06, 0.12)
		player._mesh.arm_l.rotation.x = lerp(player._mesh.arm_l.rotation.x, -0.45, 0.15)
		player._mesh.arm_l.rotation.z = lerp(player._mesh.arm_l.rotation.z, 0.18, 0.12)
	else:
		player._mesh.arm_r.rotation.x = lerp(player._mesh.arm_r.rotation.x, -0.22, 0.12)
		player._mesh.arm_l.rotation.x = lerp(player._mesh.arm_l.rotation.x, -0.14, 0.12)
		player._mesh.arm_l.rotation.z = lerp(player._mesh.arm_l.rotation.z, 0.10, 0.12)

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