class_name PlayerAK
extends RefCounted

## Súng trường tấn công AK-12 — bắn tự động trong lúc giữ chuột trái,
## tiêu hao đạn 7,62mm mỗi phát.

const AK_FIRE_INTERVAL: float = 0.11
const AK_BULLET_SPEED: float = 120.0
const AK_RANGE: float = 40.0
const AK_SPREAD_DEG: float = 0.8

static func has_ammo(player) -> bool:
	if player.inventory == null:
		return false
	for slot in player.inventory.slots:
		if not slot.is_empty() and slot.item.id == "bullet_762mm":
			return true
	return false

static func consume_ammo(player) -> bool:
	if player.inventory == null:
		return false
	for i in range(player.inventory.slots.size()):
		var slot: ItemSlot = player.inventory.slots[i]
		if not slot.is_empty() and slot.item.id == "bullet_762mm":
			player.inventory.remove_item(i, 1)
			return true
	return false

static func start_fire(player) -> void:
	if not player.equipped_weapon or player.equipped_weapon.id != "ak_12":
		return
	player._bow_aiming = true
	player._bow_charge = 0.0
	player._ak_fire_cooldown = 0.0
	player._ak_recoil = 0.0
	_setup_indicator(player)

## Bật/tắt ADS (ngắm) bằng chuột phải — không kiểm tra đạn ở đây,
## lúc bắn (update_fire) mới kiểm tra và báo hết đạn.
static func toggle_ads(player) -> void:
	if player._bow_aiming:
		cancel_aim(player)
	else:
		start_fire(player)

static func _setup_indicator(player) -> void:
	if player._bow_indicator_root == null:
		player._bow_indicator_root = Node3D.new()
		player._bow_indicator_root.name = "BowAimIndicator"
		player.get_tree().current_scene.add_child(player._bow_indicator_root)
	else:
		for ch in player._bow_indicator_root.get_children():
			ch.queue_free()
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color(1.0, 0.85, 0.4, 0.40)
	ring_mat.emission_enabled = true
	ring_mat.emission_color = Color(1.0, 0.85, 0.4)
	ring_mat.emission_energy_multiplier = 0.5
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.no_depth_test = true
	player._bow_indicator_target = MeshInstance3D.new()
	var ring := CylinderMesh.new()
	ring.top_radius = 0.5
	ring.bottom_radius = 0.5
	ring.height = 0.05
	ring.radial_segments = 16
	player._bow_indicator_target.mesh = ring
	player._bow_indicator_target.material_override = ring_mat
	player._bow_indicator_root.add_child(player._bow_indicator_target)
	player._bow_indicator_root.visible = true

static func update_fire(player, delta: float) -> void:
	if not player._bow_aiming:
		return
	if not player.equipped_weapon or player.equipped_weapon.id != "ak_12":
		player._bow_aiming = false
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		return
	if not has_ammo(player):
		player._scroll_inventory_message(player.tr("NO_AK_AMMO"))
		cancel_aim(player)
		return
	player._ak_fire_cooldown -= delta
	if player._ak_fire_cooldown > 0.0:
		return
	player._ak_fire_cooldown = AK_FIRE_INTERVAL
	fire_shot(player)

static func fire_shot(player) -> void:
	if not consume_ammo(player):
		cancel_aim(player)
		return
	player._damage_equipped_tool(1)

	var base_dmg: int = player.attack_power + (player.equipped_weapon.atk_bonus if player.equipped_weapon else 8)

	var spawn_from: Vector3 = player.global_position + Vector3(0, 0.6, 0) + player._bow_aim_dir * 0.5
	if player._mesh and player._mesh.weapon_pivot:
		spawn_from = player._mesh.weapon_pivot.global_transform * Vector3(0, 0.36, 0)

	var aim_dir: Vector3 = player._bow_aim_dir
	if player._aim_tp_mode and player._aim_world_point != Vector3.ZERO:
		var to_tgt: Vector3 = player._aim_world_point - spawn_from
		if to_tgt.length_squared() > 0.01:
			aim_dir = to_tgt.normalized()
	if aim_dir.length_squared() < 0.001:
		aim_dir = -player.global_transform.basis.z

	var spread := deg_to_rad(AK_SPREAD_DEG)
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
	bullet.setup(dir, base_dmg, AK_BULLET_SPEED, AK_RANGE, player)

	SFXManager.play_gun_shot()
	_muzzle_flash(player, spawn_from, dir)
	_kick(player, dir)

## Pose cầm/ngắm AK-12: giơ súng ngang, hai tay giữ súng khi bắn, hạ thấp khi nghỉ.
static func update_pose(player, delta: float) -> void:
	if player._mesh == null or player._mesh.weapon_pivot == null or player._mesh.arm_r == null:
		return
	if player.equipped_weapon == null or player.equipped_weapon.id != "ak_12":
		if player._ak_recoil > 0.0:
			player._ak_recoil = 0.0
		return
	var wp: Node3D = player._mesh.weapon_pivot
	if not player._ak_hold_captured:
		player._ak_hold_base = wp.position
		player._ak_hold_captured = true
	var is_ak_aiming: bool = player._bow_aiming
	# Giật nòng: từ từ hồi về 0.
	player._ak_recoil = maxf(player._ak_recoil - delta * 3.0, 0.0)
	# Súng luôn xoay nòng ra trước (giống tư thế nỏ) + ngả nhẹ khi giật.
	var target_rot: Vector3 = Vector3(90, 0, 0)
	target_rot.x += player._ak_recoil * 3.0
	wp.rotation_degrees = wp.rotation_degrees.lerp(target_rot, 0.15)
	# Giật lùi dọc theo hướng bắn ngược + hạ nhẹ nòng, rồi hồi về vị trí cầm gốc.
	# Không dùng tween riêng cho position — chỉ lerp về base cố định để không trôi.
	var aim: Vector3 = player._bow_aim_dir
	if aim.length_squared() < 0.001:
		aim = -player.global_transform.basis.z
	var kick: Vector3 = -aim * (player._ak_recoil * 0.05)
	kick.y -= player._ak_recoil * 0.02
	wp.position = wp.position.lerp(player._ak_hold_base + kick, delta * 14.0)
	if is_ak_aiming:
		# Tay phải đẩy tay cầm, tay trái giữ thân — tư thế ngắm bắn
		player._mesh.arm_r.rotation.x = lerp(player._mesh.arm_r.rotation.x, -0.55, 0.15)
		player._mesh.arm_r.rotation.z = lerp(player._mesh.arm_r.rotation.z, -0.06, 0.12)
		player._mesh.arm_l.rotation.x = lerp(player._mesh.arm_l.rotation.x, -0.42, 0.15)
		player._mesh.arm_l.rotation.z = lerp(player._mesh.arm_l.rotation.z, 0.18, 0.12)
	else:
		# Cầm súng hạ thấp, nghỉ ngơi
		player._mesh.arm_r.rotation.x = lerp(player._mesh.arm_r.rotation.x, -0.22, 0.12)
		player._mesh.arm_l.rotation.x = lerp(player._mesh.arm_l.rotation.x, -0.14, 0.12)
		player._mesh.arm_l.rotation.z = lerp(player._mesh.arm_l.rotation.z, 0.10, 0.12)

## Ánh lửa nòng: chùm sáng hình nón + lõi sáng + tia lửa bắn về hướng đạn.
static func _muzzle_flash(player, pos: Vector3, dir: Vector3) -> void:
	var world: Node = player.get_tree().current_scene
	if world == null:
		return

	# Lõi sáng rực phía đầu nòng
	var core_mat := MeshBuilder.emit_mat(
		Color(1.0, 0.9, 0.55, 1.0),
		Color(1.0, 0.8, 0.4), 8.0)
	core_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var core := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.05
	sph.height = 0.10
	core.mesh = sph
	core.material_override = core_mat
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(core)
	core.global_position = pos
	var tw: Tween = core.create_tween()
	tw.tween_property(core, "scale", Vector3(0.28, 0.28, 0.28), 0.05)
	tw.tween_property(core, "scale", Vector3(0.10, 0.10, 0.10), 0.10).set_delay(0.05)
	tw.tween_property(core_mat, "albedo_color:a", 0.0, 0.10).set_delay(0.05)
	tw.tween_property(core_mat, "emission_energy_multiplier", 0.0, 0.10).set_delay(0.05)
	tw.tween_callback(core.queue_free).set_delay(0.16)

	# Chùm lửa hình nón phóng về phía nòng (theo hướng bắn)
	var flame_mat := MeshBuilder.emit_mat(
		Color(1.0, 0.7, 0.3, 0.9),
		Color(1.0, 0.6, 0.2), 7.0)
	flame_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flame_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var flame := MeshInstance3D.new()
	var fmesh := CylinderMesh.new()
	fmesh.top_radius = 0.015
	fmesh.bottom_radius = 0.05
	fmesh.height = 0.30
	fmesh.radial_segments = 8
	flame.mesh = fmesh
	flame.material_override = flame_mat
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(flame)
	flame.global_position = pos + dir * 0.15
	flame.global_basis = _align_y_to(flame.global_basis, dir)
	var ftw: Tween = flame.create_tween().set_parallel()
	ftw.tween_property(flame, "scale", Vector3(1.4, 1.6, 1.4), 0.05)
	ftw.tween_property(flame_mat, "albedo_color:a", 0.0, 0.11)
	ftw.tween_property(flame_mat, "emission_energy_multiplier", 0.0, 0.11)
	ftw.tween_callback(flame.queue_free).set_delay(0.12)

	# Tia lửa văng về phía trước
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
		var sdir := (dir + _rand_side(dir) * randf_range(-0.6, 0.6)).normalized()
		var stw: Tween = spark.create_tween().set_parallel()
		stw.tween_property(spark, "global_position", spark.global_position + sdir * randf_range(0.35, 0.7), 0.10)
		stw.tween_property(spark_mat, "albedo_color:a", 0.0, 0.10)
		stw.tween_property(spark_mat, "emission_energy_multiplier", 0.0, 0.10)
		stw.tween_callback(spark.queue_free).set_delay(0.11)

## Giật nòng (recoil): chỉ cộng dồn vào _ak_recoil — update_pose sẽ ngả nòng
## + lùi nhẹ rồi hồi về base cố định. Không tạo tween riêng để tránh chồng
## tween làm súng trôi dần khỏi vị trí cầm khi bắn tự động.
static func _kick(player, _dir: Vector3) -> void:
	player._ak_recoil = minf(player._ak_recoil + 0.6, 1.0)

static func _align_y_to(b: Basis, dir: Vector3) -> Basis:
	var up := Vector3.UP
	if absf(dir.dot(up)) > 0.98:
		up = Vector3.RIGHT
	var x_axis := up.cross(dir).normalized()
	var z_axis := x_axis.cross(dir).normalized()
	return Basis(x_axis, dir, z_axis)

static func _rand_side(dir: Vector3) -> Vector3:
	var up := Vector3.UP
	if absf(dir.dot(up)) > 0.98:
		up = Vector3.RIGHT
	var h := dir.cross(up).normalized()
	return h

static func cancel_aim(player) -> void:
	player._bow_aiming = false
	player._bow_charge = 0.0
	player._aim_tp_mode = false
	player._ak_recoil = 0.0
	if player._bow_indicator_root:
		player._bow_indicator_root.visible = false