class_name PlayerLongbow
extends RefCounted

## CUNG GỖ — animation bắn cung CHUẨN:
##  • Tay TRÁI giơ thẳng giữ cung NGANG (thân cung nằm ngang vai)
##  • Tay PHẢI kéo dây cung căng dần về má khi GIỮ chuột trái (charge)
##  • Thả chuột: buông dây → mũi tên phóng đi (sát thương/tầm theo độ căng)
## Pose tay do script này sở hữu (wooden_bow nằm trong _ARMS_OWNED_WEAPONS).

const DRAW_RATE: float = 1.15          # giây để kéo căng tối đa
const MIN_SHOT_CHARGE: float = 0.10    # dưới mức này chỉ hạ cung, không bắn

static func has_arrows(player) -> bool:
	if player.inventory == null:
		return false
	for slot in player.inventory.slots:
		if not slot.is_empty() and slot.item.id == "arrow":
			return true
	return false

static func consume_arrow(player) -> bool:
	if player.inventory == null:
		return false
	for i in range(player.inventory.slots.size()):
		var slot: ItemSlot = player.inventory.slots[i]
		if not slot.is_empty() and slot.item.id == "arrow":
			player.inventory.remove_item(i, 1)
			return true
	return false

## Bắt đầu KÉO CĂNG (nhấn chuột trái) — kiểm tra tên trước khi vào tư thế.
static func start_draw(player) -> void:
	if not player.equipped_weapon or player.equipped_weapon.id != "wooden_bow":
		return
	if not has_arrows(player):
		player._scroll_inventory_message(player.tr("BOW_NO_ARROWS"))
		return
	player._bow_aiming = true
	player._bow_charge = 0.0
	if not player._lb_hold_captured and player._mesh != null \
			and player._mesh.weapon_pivot != null:
		player._lb_hold_base = player._mesh.weapon_pivot.position
		player._lb_hold_captured = true
	_setup_indicator(player)

static func cancel_draw(player) -> void:
	player._bow_aiming = false
	player._bow_charge = 0.0
	player._aim_tp_mode = false
	if player._bow_indicator_root:
		player._bow_indicator_root.visible = false
	_update_string(player, 0.0)

## Giữ chuột: tích độ căng + duy trì pose kéo dây.
static func update_draw(player, delta: float) -> void:
	if not player._bow_aiming or not player.equipped_weapon \
			or player.equipped_weapon.id != "wooden_bow":
		return
	player._bow_charge = minf(player._bow_charge + delta * DRAW_RATE,
		player._bow_max_charge)
	var d: float = clampf(player._bow_charge / player._bow_max_charge, 0.0, 1.0)
	_apply_pose(player, delta, d)
	_update_string(player, d)

## THẢ chuột: buông dây — mũi tên bay ra. Độ căng quyết định dmg/tầm/tốc.
static func release(player) -> void:
	if not player.equipped_weapon or player.equipped_weapon.id != "wooden_bow":
		return
	if not player._bow_aiming:
		return
	var d: float = clampf(player._bow_charge / player._bow_max_charge, 0.0, 1.0)
	var was_ready: bool = d >= MIN_SHOT_CHARGE
	cancel_draw(player)
	if not was_ready:
		return
	if not consume_arrow(player):
		player._scroll_inventory_message(player.tr("BOW_NO_ARROWS"))
		return
	player._damage_equipped_tool(1)

	var base_dmg: int = player.attack_power \
		+ (player.equipped_weapon.atk_bonus if player.equipped_weapon else 7)
	var total_dmg: int = int(base_dmg * lerpf(0.6, 1.7, d))
	var arrow_speed: float = lerpf(22.0, 72.0, d)
	var range_len: float = lerpf(16.0, 95.0, d)

	var spawn_from: Vector3 = player.global_position + Vector3(0, 0.62, 0)
	if player._mesh != null and player._mesh.weapon_pivot != null:
		spawn_from = player._mesh.weapon_pivot.global_transform * Vector3(-0.06, 0, 0.05)
	var aim_dir: Vector3 = player._bow_aim_dir
	if player._aim_tp_mode and player._aim_world_point != Vector3.ZERO:
		var to_tgt: Vector3 = player._aim_world_point - spawn_from
		if to_tgt.length_squared() > 0.01:
			aim_dir = to_tgt.normalized()
			range_len = maxf(range_len, minf(to_tgt.length(), 95.0))
			arrow_speed = maxf(arrow_speed, 42.0)
	if aim_dir.length_squared() < 0.001:
		aim_dir = -player.global_transform.basis.z

	var spread := deg_to_rad(lerpf(2.4, 0.25, d))   # căng hết = chuẩn xác
	var up_ref := Vector3.UP
	if absf(aim_dir.dot(up_ref)) > 0.98:
		up_ref = Vector3.RIGHT
	var right := aim_dir.cross(up_ref).normalized()
	var up2 := right.cross(aim_dir).normalized()
	var dir := (aim_dir + right * randf_range(-spread, spread)
		+ up2 * randf_range(-spread, spread)).normalized()

	var arrow := ArrowProjectile.new()
	var world: Node = player.get_tree().current_scene
	if world:
		world.add_child(arrow)
	else:
		player.add_child(arrow)
	arrow.global_position = spawn_from + dir * 0.45
	arrow.setup(dir, total_dmg, arrow_speed, range_len, player)
	SFXManager.play_cast()

## Tư thế CẦM ĐI BỘ (không kéo): cung vác chéo thấp trước ngực, tay thả lỏng.
static func update_carry(player, delta: float) -> void:
	if player._mesh == null:
		return
	var mesh = player._mesh
	var t: float = player._time
	var breathe := sin(t * 1.8) * 0.02
	mesh.arm_l.rotation.x = lerp(mesh.arm_l.rotation.x, -0.52 + breathe,
		minf(1.0, delta * 8.0))
	mesh.elbow_l.rotation.x = lerp(mesh.elbow_l.rotation.x, -0.72,
		minf(1.0, delta * 8.0))
	mesh.arm_r.rotation.x = lerp(mesh.arm_r.rotation.x, -0.28 + breathe * 0.5,
		minf(1.0, delta * 8.0))
	mesh.elbow_r.rotation.x = lerp(mesh.elbow_r.rotation.x, -0.66,
		minf(1.0, delta * 8.0))
	var wp: Node3D = mesh.weapon_pivot
	if wp != null and is_instance_valid(wp):
		wp.rotation_degrees = wp.rotation_degrees.lerp(
			Vector3(38.0 + breathe * 30.0, 14.0, 76.0), minf(1.0, delta * 8.0))
		if player._lb_hold_captured:
			wp.position = wp.position.lerp(player._lb_hold_base, minf(1.0, delta * 8.0))
	_update_string(player, 0.0)

## ── POSE — phần quan trọng nhất ────────────────────────────────────────────────
## d = 0..1 độ kéo căng:
##  • Tay TRÁI duỗi THẲNG ra trước, cao ngang vai, giữ CUNG NẰM NGANG
##    (wp.z=90° xoay thân cung nằm ngang; wp.x hơi chúi/ngẩng theo nhắm)
##  • Tay PHẢI: từ vị trí trên dây kéo DẦN về MÁ — khuỷu gập sâu khi căng hết
##  • Thân vặn nhẹ, đầu nghiêng áp má nhìn theo mũi tên
static func _apply_pose(player, delta: float, d: float) -> void:
	if player._mesh == null:
		return
	var mesh = player._mesh
	var t: float = player._time
	var breathe := sin(t * 1.8) * 0.012 * (1.0 - d * 0.7)

	# ── Tay trái: duỗi thẳng giữ cung ngang (càng căng càng khóa chắc) ──────
	mesh.arm_l.rotation.x = lerp(mesh.arm_l.rotation.x, -1.52 - d * 0.03,
		minf(1.0, delta * 12.0))
	mesh.arm_l.rotation.z = lerp(mesh.arm_l.rotation.z, 0.06, minf(1.0, delta * 10.0))
	mesh.elbow_l.rotation.x = lerp(mesh.elbow_l.rotation.x, -0.08 - breathe,
		minf(1.0, delta * 11.0))

	# ── Tay phải: kéo dây về MÁ (khuỷu nhấc cao gập sâu) ────────────────────
	var pull := lerpf(-0.55, -1.02, d)            # vai đưa ra trước rồi ghì về má
	mesh.arm_r.rotation.x = lerp(mesh.arm_r.rotation.x, pull,
		minf(1.0, delta * 13.0))
	mesh.arm_r.rotation.z = lerp(mesh.arm_r.rotation.z, -0.10 - d * 0.14,
		minf(1.0, delta * 11.0))
	mesh.elbow_r.rotation.x = lerp(mesh.elbow_r.rotation.x,
		lerpf(-0.60, -1.62, d), minf(1.0, delta * 12.0))
	mesh.elbow_r.rotation.z = lerp(mesh.elbow_r.rotation.z, 0.18 * d,
		minf(1.0, delta * 10.0))

	# ── Thân cung NẰM NGANG: wp.z = 90° ; wp.x = góc nhắm nhẹ theo căng ─────
	var wp: Node3D = mesh.weapon_pivot
	if wp != null and is_instance_valid(wp):
		var target_rot := Vector3(-4.0 * d + breathe * 40.0, 0.0, 90.0)
		wp.rotation_degrees = wp.rotation_degrees.lerp(target_rot, minf(1.0, delta * 12.0))
		# Cung ép sát về phía trước-tay trái khi căng (điểm neo ổn định)
		wp.position = wp.position.lerp(
			player._lb_hold_base + Vector3(-0.04, 0.05, 0.06) * d, minf(1.0, delta * 10.0))

	# ── Thân/đầu: vặn nhẹ nạp lực, đầu áp má nhìn thẳng mũi tên ─────────────
	mesh.rig.rotation.y = lerp(mesh.rig.rotation.y, 0.16 * d, minf(1.0, delta * 9.0))
	mesh.body.rotation.x = lerp(mesh.body.rotation.x, -0.03 - d * 0.02,
		minf(1.0, delta * 9.0))
	mesh.head.rotation.x = lerp(mesh.head.rotation.x, -0.05 - d * 0.04,
		minf(1.0, delta * 9.0))
	mesh.head.rotation.y = lerp(mesh.head.rotation.y, 0.14 * d, minf(1.0, delta * 9.0))
	mesh.neck.rotation.x = lerp(mesh.neck.rotation.x, 0.04 * d, minf(1.0, delta * 8.0))

	# Chân thế xạ thủ: chân trái trước chân phải sau, trùng dần khi căng lâu
	mesh.leg_l.rotation.x = lerp(mesh.leg_l.rotation.x, (-0.24 + sin(t * 1.5) * 0.02) * d,
		minf(1.0, delta * 8.0))
	mesh.leg_r.rotation.x = lerp(mesh.leg_r.rotation.x, (0.16) * d,
		minf(1.0, delta * 8.0))
	mesh.knee_l.rotation.x = lerp(mesh.knee_l.rotation.x, 0.20 * d, minf(1.0, delta * 8.0))
	mesh.knee_r.rotation.x = lerp(mesh.knee_r.rotation.x, 0.16 * d, minf(1.0, delta * 8.0))
	mesh.pelvis.position.x = lerp(mesh.pelvis.position.x, -0.012 * d,
		minf(1.0, delta * 8.0))

	# Vòng chỉ điểm mục tiêu mờ dần khi căng đủ (không cần nữa)
	if player._bow_indicator_target != null:
		player._bow_indicator_target.transparency = lerpf(0.35, 0.85, d)

## ── DÂY CUNG: 2 đoạn từ 2 đầu cánh → hốc dây; hốc bị KÉO ra sau theo độ căng ─
static func _update_string(player, d: float) -> void:
	if player._mesh == null or player._mesh.weapon_pivot == null:
		return
	var wp: Node3D = player._mesh.weapon_pivot
	var str_node: Node3D = null
	for ch in wp.get_children():
		if ch.name == "BowString":
			str_node = ch
			break
	if str_node == null:
		str_node = Node3D.new()
		str_node.name = "BowString"
		wp.add_child(str_node)
		var s_top := MeshInstance3D.new()
		s_top.name = "SegTop"
		s_top.mesh = CylinderMesh.new()
		s_top.mesh.top_radius = 0.004
		s_top.mesh.bottom_radius = 0.004
		s_top.mesh.height = 1.0
		s_top.material_override = StandardMaterial3D.new()
		(s_top.material_override as StandardMaterial3D).albedo_color = Color(0.92, 0.90, 0.82)
		s_top.material_override.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		str_node.add_child(s_top)
		var s_bot := s_top.duplicate()
		s_bot.name = "SegBottom"
		str_node.add_child(s_bot)
	# Đầu cánh cung & hốc dây bị kéo ra SAU (-X local) theo d
	var tip_t := Vector3(-0.05, 0.46, 0.0)
	var tip_b := Vector3(-0.05, -0.46, 0.0)
	var nock := Vector3(-0.05 - 0.30 * d, 0.0, 0.0)
	_place_seg(str_node.get_node("SegTop"), tip_t, nock)
	_place_seg(str_node.get_node("SegBottom"), nock, tip_b)

static func _place_seg(seg: Node3D, a: Vector3, b: Vector3) -> void:
	var mid := (a + b) * 0.5
	var dir := (b - a)
	var len := dir.length()
	if len < 0.001:
		seg.visible = false
		return
	seg.visible = true
	seg.position = mid
	seg.basis = Basis.looking_at(dir.normalized(), Vector3.RIGHT).scaled(
		Vector3(1.0, 1.0, maxf(len, 0.01)))

## Vòng ngắm đơn giản dưới chân mục tiêu (tái dùng mẫu của crossbow).
static func _setup_indicator(player) -> void:
	if player._bow_indicator_root == null:
		player._bow_indicator_root = Node3D.new()
		player._bow_indicator_root.name = "BowAimIndicator"
		player.get_tree().current_scene.add_child(player._bow_indicator_root)
	else:
		for ch in player._bow_indicator_root.get_children():
			ch.queue_free()
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color(0.65, 0.9, 1.0, 0.35)
	ring_mat.emission_enabled = true
	ring_mat.emission_color = Color(0.65, 0.9, 1.0)
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.no_depth_test = true
	player._bow_indicator_target = MeshInstance3D.new()
	var ring := CylinderMesh.new()
	ring.top_radius = 0.42
	ring.bottom_radius = 0.42
	ring.height = 0.04
	ring.radial_segments = 14
	player._bow_indicator_target.mesh = ring
	player._bow_indicator_target.material_override = ring_mat
	player._bow_indicator_root.add_child(player._bow_indicator_target)
	player._bow_indicator_root.visible = true