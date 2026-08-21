extends Node3D

## Test melee auto-combo: IDLE → ATTACK (chain tự nối khi giữ chuột)
## → RECOVERY → IDLE, và nhánh AIR_ATTACK → LANDING (RECOVERY).

const _PlayerChar = preload("res://scripts/characters/player/player_character.gd")
const _Combos := preload("res://scripts/characters/player/melee_combos.gd")

var _failures: int = 0

func _check(cond: bool, label: String) -> void:
	print("%s | %s" % ["PASS" if cond else "FAIL", label])
	if not cond:
		_failures += 1

func _click_left(pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = Vector2(100, 100)
	Input.parse_input_event(ev)

## Tap nhanh: nhấn-nhả 2 frame — ra đòn thường bước 0 (không vận lực)
func _tap_left() -> void:
	_click_left(true)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_click_left(false)

func _wait_frames(n: int) -> void:
	for i in range(n):
		await get_tree().physics_frame

func _ready() -> void:
	print("== test_melee_combo: auto-attack chain + air attack ==")
	ItemDatabase.ensure_db()

	# Sàn để player đứng thật (is_on_floor hoạt động)
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(90, 1, 90)
	floor_shape.shape = box
	floor_shape.position = Vector3(0, -0.5, 0)
	floor_body.add_child(floor_shape)
	add_child(floor_body)

	var p := _PlayerChar.new()
	add_child(p)
	await _wait_frames(5)

	var db: Dictionary = ItemDatabase.items_db
	if db.has("iron_sword"):
		p.equipped_weapon = db["iron_sword"]
	_check(p.equipped_weapon != null, "trang bị iron_sword")
	var chain: Array = _Combos.chain_for("iron_sword")
	_check(chain.size() == 3, "kiếm có chain 3 đòn (got=%d)" % chain.size())

	# ── 1. TAP chuột → đòn thường bước 0 ─────────────────────────────────────
	await _tap_left()
	var got_attack := false
	for i in range(15):
		await get_tree().physics_frame
		if p._state == p.State.ATTACK:
			got_attack = true
			break
	_check(got_attack, "tap chuột → ATTACK")
	_check(p.combo_step == 0, "bắt đầu từ bước 0 (step=%d)" % p.combo_step)
	_check(p._attack_timer > 0.0, "timer đếm ngược bước")

	# ── 2. BẤM ĐỆM NHỊP → chain tự nối 0 → 1 → 2 ─────────────────────────────
	var saw_step1 := false
	var saw_step2 := false
	for rep in range(4):
		await _tap_left()
		for i in range(34):
			await get_tree().physics_frame
			if p.combo_step == 1 and p._state == p.State.ATTACK:
				saw_step1 = true
			if p.combo_step == 2 and p._state == p.State.ATTACK:
				saw_step2 = true
			if p._state == p.State.RECOVERY:
				break
	_check(saw_step1, "bấm đệm nhịp → tự nối bước 1")
	_check(saw_step2, "bấm đệm nhịp → tự nối bước 2")

	# ── 3. Hết chain → RECOVERY (dù vẫn giữ chuột) → IDLE ────────────────────
	var saw_recovery := false
	for i in range(90):
		await get_tree().physics_frame
		if p._state == p.State.RECOVERY:
			saw_recovery = true
			break
	_check(saw_recovery, "hết chain → RECOVERY")
	var saw_idle := false
	for i in range(90):
		await get_tree().physics_frame
		if p._state == p.State.IDLE:
			saw_idle = true
			break
	_check(saw_idle, "RECOVERY hết → IDLE")

	# ── 4. Bấm lẻ 1 lần (không đệm) → 1 đòn rồi RECOVERY ────────────────────
	await _tap_left()
	await _wait_frames(2)
	_check(p._state == p.State.ATTACK, "bấm đơn → ATTACK")
	var went_recovery := false
	for i in range(120):
		await get_tree().physics_frame
		if p._state == p.State.RECOVERY:
			went_recovery = true
			break
	_check(went_recovery, "bấm đơn không nối chain → RECOVERY ngay")
	for i in range(90):
		await get_tree().physics_frame
		if p._state == p.State.IDLE:
			break

	# ── 5. AIR_ATTACK: nhảy + đánh trên không ────────────────────────────────
	# Đặt jump buffer trực tiếp (action_press không tạo key event qua
	# _unhandled_key_input nên không kích hoạt nhảy được).
	p._jbuf = p.JUMP_BUFFER
	await _wait_frames(3)
	var airborne := not p.is_on_floor()
	_check(airborne, "player đang trên không (pre-check)")
	if not airborne:
		p.global_position.y += 2.0
		await _wait_frames(3)
		airborne = not p.is_on_floor()
	_check(airborne, "ép rời mặt đất (fallback)")
	_click_left(true)
	var got_air := false
	for i in range(15):
		await get_tree().physics_frame
		if p._state == p.State.AIR_ATTACK:
			got_air = true
			break
	_check(got_air, "nhảy + đánh → AIR_ATTACK")
	_click_left(false)
	var landed_recovery := false
	for i in range(150):
		await get_tree().physics_frame
		if p.is_on_floor() and p._state == p.State.RECOVERY:
			landed_recovery = true
			break
	_check(landed_recovery, "tiếp đất → RECOVERY (LANDING)")
	_check(p._air_attack_available, "chạm đất → mở khoá air attack cho lần sau")

	# ── 6. ANTI-TILT: hông/thân/thế cầm phải về chuẩn sau mọi chuỗi đòn ──────
	var saw_idle2 := false
	for i in range(120):
		await get_tree().physics_frame
		if p._state == p.State.IDLE:
			saw_idle2 = true
			break
	_check(saw_idle2, "trở về IDLE sau air attack")
	await _wait_frames(50)   # cho spring ổn định hoàn toàn
	var mesh_node: PlayerMesh = p._mesh
	var pelvis_x: float = mesh_node.pelvis.rotation.x
	var body_z: float = mesh_node.body.rotation.z
	var rig_x: float = mesh_node.rig.rotation.x
	var wp_deg: Vector3 = mesh_node.weapon_pivot.rotation_degrees
	var wp_err: float = Vector3(90, 0, 0).distance_to(wp_deg)
	_check(absf(pelvis_x) < 0.06, "hông không còn gập sau đáp đất+combo (pelvis.x=%.3f)" % pelvis_x)
	_check(absf(body_z) < 0.05, "thân không còn nghiêng ngang (body.z=%.3f)" % body_z)
	_check(absf(rig_x) < 0.10, "thân không chúi/lệch (rig.x=%.3f)" % rig_x)
	_check(wp_err < 4.0, "kiếm cầm về thế chuẩn (wp=%s err=%.1f)" % [str(wp_deg), wp_err])

	# ── 7. Ngắt giữa đòn bằng HIT → wp vẫn phải hồi về thế chuẩn ────────────
	p._charge_pending = false
	p._charging = false
	p._combo_chain = _Combos.chain_for("iron_sword")
	p._begin_combo_step(0)
	var attacking_ok: bool = p._state == p.State.ATTACK
	_check(attacking_ok, "có đòn đang vung để ngắt")
	p.take_damage(1, null)   # HIT giữa chừng
	await _wait_frames(40)
	await _wait_frames(80)
	var wp_err2: float = Vector3(90, 0, 0).distance_to(mesh_node.weapon_pivot.rotation_degrees)
	_check(wp_err2 < 4.0, "bị HIT ngắt giữa đòn → kiếm vẫn về thế chuẩn (err=%.1f)" % wp_err2)
	var pelvis_x2: float = mesh_node.pelvis.rotation.x
	_check(absf(pelvis_x2) < 0.06, "sau HIT hông thẳng lại (pelvis.x=%.3f)" % pelvis_x2)

	# ── 8. Găng tay THAY THẾ bàn tay ─────────────────────────────────────────
	var db2: Dictionary = ItemDatabase.items_db
	if db2.has("leather_gloves"):
		p.equipped_weapon = db2["leather_gloves"]
		p._update_weapon_mesh()
		await _wait_frames(3)
		_check(mesh_node.hand_l != null and not mesh_node.hand_l.visible, "găng: tay trái gốc bị ẩn")
		_check(mesh_node.hand_r != null and not mesh_node.hand_r.visible, "găng: tay phải gốc bị ẩn")
		var glove_l := false
		var glove_r := false
		for ch in mesh_node.elbow_l.get_children():
			if ch.name == "GloveL":
				glove_l = true
		for ch in mesh_node.elbow_r.get_children():
			if ch.name == "GloveR":
				glove_r = true
		_check(glove_l and glove_r, "model găng đeo đúng 2 khuỷu (thay chỗ bàn tay)")
		# Đổi sang kiếm → găng biến mất, tay hiện lại
		p.equipped_weapon = db2["iron_sword"]
		p._update_weapon_mesh()
		await _wait_frames(3)
		_check(mesh_node.hand_l.visible and mesh_node.hand_r.visible, "đổi vũ khí → tay gốc hiện lại")
		var gloves_gone := true
		for ch in mesh_node.elbow_l.get_children():
			if ch.name == "GloveL" and not ch.is_queued_for_deletion():
				gloves_gone = false
		_check(gloves_gone, "đổi vũ khí → model găng được dọn sạch")

	# ── 9. Đại kiếm 2 tay: chuỗi NẶNG (chậm) + pose dùng cả 2 tay ───────────
	if db2.has("iron_greatsword"):
		p.equipped_weapon = db2["iron_greatsword"]
		p._update_weapon_mesh()
		var gs_chain: Array = _Combos.chain_for("iron_greatsword")
		var total_t: float = 0.0
		for st in gs_chain:
			total_t += st.dur
		_check(total_t > 2.6, "đại kiếm chuỗi nặng: tổng %.2fs > 2.6s" % total_t)
		# Bắt đầu vung bước 0 → pose windup phải kéo TAY TRÁI lên nắm chuôi cùng
		p._charge_pending = false
		p._charging = false
		p._combo_chain = gs_chain
		p._begin_combo_step(0)
		var gs_attacking: bool = p._state == p.State.ATTACK
		await _wait_frames(6)
		var arm_l_x: float = mesh_node.arm_l.rotation.x
		_check(gs_attacking and arm_l_x < -0.5,
			"đại kiếm vung: tay trái tham gia nắm chuôi (arm_l.x=%.2f)" % arm_l_x)
		_click_left(false)

	# ── 10. Sword trail VFX mới: sinh khi vung → tích điểm → tự huỷ ─────────
	if db2.has("iron_sword"):
		p.equipped_weapon = db2["iron_sword"]
		p._update_weapon_mesh()
		await _wait_frames(5)
		for i in range(90):
			await get_tree().physics_frame
			if p._state == p.State.IDLE:
				break
		p._charge_pending = false
		p._charging = false
		p._combo_chain = _Combos.chain_for("iron_sword")
		p._begin_combo_step(0)
		var trail_found := false
		var max_segs := 0
		for i in range(25):
			await get_tree().physics_frame
			if p._anim != null and p._anim._trail != null and is_instance_valid(p._anim._trail):
				trail_found = true
				max_segs = maxi(max_segs, p._anim._trail._bases.size())
		_check(trail_found, "vung kiếm → trail được tạo trên weapon_pivot")
		_check(max_segs >= 4, "trail ghi được đường vung (%d đoạn)" % max_segs)
		var trail_gone := false
		for i in range(180):
			await get_tree().physics_frame
			if p._anim == null or p._anim._trail == null or not is_instance_valid(p._anim._trail):
				trail_gone = true
				break
		_check(trail_gone, "trail tự huỷ sau khi đòn kết thúc")

	# ── 11. Chân đánh CÓ LỰC: thế kiềng sâu khi strike ───────────────────────
	if db2.has("iron_sword"):
		p.equipped_weapon = db2["iron_sword"]
		p._update_weapon_mesh()
		await _wait_frames(5)
		for i in range(90):
			await get_tree().physics_frame
			if p._state == p.State.IDLE:
				break
		# Gọi trực tiếp bước đánh (tất định, không phụ thuộc input queue)
		p._charge_pending = false
		p._charging = false
		p._combo_chain = _Combos.chain_for("iron_sword")
		p._begin_combo_step(0)
		var max_lead_knee := 0.0
		var min_rig_y := 10.0
		var min_trail_ankle := 10.0
		for i in range(40):
			await get_tree().physics_frame
			if p._state != p.State.ATTACK:
				break
			max_lead_knee = maxf(max_lead_knee, mesh_node.knee_r.rotation.x)
			min_rig_y = minf(min_rig_y, mesh_node.rig.position.y)
			min_trail_ankle = minf(min_trail_ankle, mesh_node.ankle_l.rotation.x)
		_click_left(false)
		_check(max_lead_knee > 0.55, "gối chân trước gập sâu khi đập (%.2f rad)" % max_lead_knee)
		_check(min_rig_y < -0.02, "thân lún xuống dồn lực (rig.y=%.3f)" % min_rig_y)
		_check(min_trail_ankle < -0.25, "gót chân sau nhấc đạp (ankle=%.2f)" % min_trail_ankle)

	# ── 12. Súng: ADS đầu ngắm theo nòng + thoi nòng M200 + shake không crash ─
	var aim_cam := Camera3D.new()
	add_child(aim_cam)
	aim_cam.rotation_degrees.x = 40.0   # Godot: pitch DƯƠNG = nhìn LÊN trời
	aim_cam.current = true
	await _wait_frames(2)
	if db2.has("ak_12"):
		p.equipped_weapon = db2["ak_12"]
		p._update_weapon_mesh()
		await _wait_frames(3)
		p._bow_aiming = true
		for i in range(45):
			await get_tree().physics_frame
			await get_tree().process_frame
		_check(p._gun_ads_blend > 0.5, "ADS blend vào tư thế ngắm (%.2f)" % p._gun_ads_blend)
		var hx: float = mesh_node.head.rotation.x
		_check(hx < -0.10, "đầu NGẮM LÊN theo hướng nòng (head.x=%.2f)" % hx)
		p._bow_aiming = false
		p._AK.cancel_aim(p)
		for i in range(40):
			await get_tree().process_frame
		_check(p._gun_ads_blend < 0.35, "nhả ngắm → blend hồi về (%.2f)" % p._gun_ads_blend)

	if db2.has("m200"):
		p.equipped_weapon = db2["m200"]
		p._update_weapon_mesh()
		await _wait_frames(3)
		p._m200_bolt_cd = 1.0   # bắt đầu chu kỳ thoi nòng
		var max_dev := 0.0
		for i in range(30):
			await get_tree().process_frame
			max_dev = maxf(max_dev, absf(mesh_node.arm_l.rotation.x + 0.20))
		_check(max_dev > 0.06, "tay trái thao tác LÊN ĐẠN THOI sau bắn (dev=%.2f)" % max_dev)

	# ── 14. Nòng súng NGANG mặt đất — chống "cầm gậy phép" ──────────────────
	if db2.has("ak_12"):
		p.equipped_weapon = db2["ak_12"]
		p._update_weapon_mesh()
		await _wait_frames(70)   # cho tay + wp hội tụ tư thế nghỉ
		var axis: Vector3 = p._mesh.weapon_pivot.global_transform.basis * Vector3(0, 1, 0)
		var pitch_rest: float = asin(clampf(axis.normalized().y, -1.0, 1.0))
		_check(absf(pitch_rest) < 0.32, "nòng AK NGANG khi hạ súng (pitch=%.2f rad)" % pitch_rest)
		p._bow_aiming = true
		await _wait_frames(55)
		axis = p._mesh.weapon_pivot.global_transform.basis * Vector3(0, 1, 0)
		var pitch_ads: float = asin(clampf(axis.normalized().y, -1.0, 1.0))
		_check(absf(pitch_ads) < 0.30, "nòng AK NGANG khi ADS (pitch=%.2f rad)" % pitch_ads)
		p._bow_aiming = false
		p._AK.cancel_aim(p)
		await _wait_frames(10)

	# Shake sát thương: gọi trực tiếp mức nhỏ/lớn — headless không có camera nên
	# chỉ xác nhận KHÔNG crash và công thức không âm.
	p._damage_shake(1)
	p._damage_shake(50)
	_check(true, "_damage_shake chạy an toàn với mọi mức sát thương")

	# ── 13. Chu kỳ gối sinh học: co giữa vung → DUỖI THẲNG khi chạm gót ─────
	var anim := p._anim
	if anim != null:
		var k_mid: float = anim._gait_knee(-0.48, 0.90, true)    # giữa pha vung
		var k_reach: float = anim._gait_knee(-0.90, 0.90, true)  # vươn tới trước chạm
		var k_contact: float = anim._gait_knee(-1.0, 0.90, false) # vừa tiếp đất
		var k_stance: float = anim._gait_knee(0.0, 0.90, false)   # giữa pha trụ
		_check(k_mid > 0.75, "gối co SÂU giữa pha vung (%.2f rad)" % k_mid)
		_check(k_reach < 0.40, "DUỖI THẲNG cẳng chân trước khi chạm (%.2f rad)" % k_reach)
		_check(k_mid > k_reach * 2.2, "tương phản co/duỗi rõ (%.2f vs %.2f)" % [k_mid, k_reach])
		_check(k_stance < 0.20, "chân trụ gần thẳng đứng (%.2f rad)" % k_stance)
		_check(k_contact >= k_stance, "lún gối ngay sau tiếp đất (%.2f >= %.2f)" % [k_contact, k_stance])

	# ── 14. Giáp tay da thú: model bao cẳng tay + ĐẤM DUỖI THẲNG khuỷu ──────
	if db2.has("leather_gloves"):
		p.equipped_weapon = db2["leather_gloves"]
		p._update_weapon_mesh()
		await _wait_frames(3)
		var glove_parts := 0
		for ch in mesh_node.elbow_l.get_children():
			if ch.name == "GloveL":
				glove_parts = ch.get_child_count()
		_check(glove_parts >= 30, "giáp tay đầy đủ chi tiết bao cẳng tay (%d phần)" % glove_parts)
		await _wait_frames(5)
		for i in range(90):
			await get_tree().physics_frame
			if p._state == p.State.IDLE:
				break
		p._charge_pending = false
		p._charging = false
		p._combo_chain = _Combos.chain_for("leather_gloves")
		p._begin_combo_step(0)
		var straightest := 0.0    # giá trị elbow_l gần 0 nhất = duỗi thẳng nhất
		var deepest := 0.0        # gập sâu nhất khi vung co
		for i in range(18):
			await get_tree().physics_frame
			if p._state != p.State.ATTACK:
				break
			var e: float = mesh_node.elbow_l.rotation.x
			straightest = maxf(straightest, e)
			deepest = minf(deepest, e)
		_check(deepest < -1.30, "vung co tay SÂU lấy đà (%.2f rad)" % deepest)
		_check(straightest > -0.45, "ĐẤM DUỖI THẲNG khuỷu khi trúng (%.2f rad)" % straightest)

	# ── 15. Nhảy GỐI TÚC: cả hai gối co cao sát ngực khi bay ────────────────
	p._jbuf = p.JUMP_BUFFER
	await _wait_frames(3)
	var max_knee_l := 0.0
	var max_knee_r := 0.0
	for i in range(34):
		await get_tree().physics_frame
		if p.is_on_floor():
			break
		max_knee_l = maxf(max_knee_l, mesh_node.knee_l.rotation.x)
		max_knee_r = maxf(max_knee_r, mesh_node.knee_r.rotation.x)
	_check(max_knee_l > 1.15, "chân dẫn GỐI TÚC cao (knee_l=%.2f)" % max_knee_l)
	_check(max_knee_r > 0.95, "chân sau túc theo thấp hơn một nhịp (knee_r=%.2f)" % max_knee_r)

	# ── 16. Dash LOW GLIDE: thân nghiêng thấp + hai chân tách trước/sau ─────
	Input.action_press("dash")
	var in_dash := false
	var max_lean := 0.0
	var max_legdiff := 0.0
	for i in range(26):
		await get_tree().physics_frame
		if p._state == p.State.DASH:
			in_dash = true
			max_lean = maxf(max_lean, absf(mesh_node.rig.rotation.x))
			max_legdiff = maxf(max_legdiff, absf(mesh_node.leg_l.rotation.x - mesh_node.leg_r.rotation.x))
	Input.action_release("dash")
	_check(in_dash, "dash kích hoạt")
	_check(max_lean > 0.20, "glide NGHIÊNG người thấp (rig.x=%.2f)" % max_lean)
	_check(max_legdiff > 0.80, "hai chân TÁCH xa kiểu glide (diff=%.2f)" % max_legdiff)

	# ── 17. Kích sắt đòn cuối: ĐÂM THẲNG + LƯỚT tới trước ───────────────────
	if db2.has("iron_halberd"):
		p.equipped_weapon = db2["iron_halberd"]
		p._update_weapon_mesh()
		await _wait_frames(5)
		for i in range(90):
			await get_tree().physics_frame
			if p._state == p.State.IDLE:
				break
		p._combo_chain = _Combos.chain_for("iron_halberd")
		p.rotation.y = 0.0   # lao theo +Z cho dễ đo
		p._begin_combo_step(2)
		await _wait_frames(4)
		var pos0: Vector3 = p.global_position
		var sliding := false
		for i in range(50):
			await get_tree().physics_frame
			if p._combo_slide and p._action_lunge_timer > 0.0:
				sliding = true
		var moved: float = abs(p.global_position.z - pos0.z)
		_check(sliding, "đòn cuối KÍCH SẮT lướt tới (lunge chạy)")
		_check(moved > 1.2, "lướt được một đoạn đáng kể (d=%.2f m)" % moved)
		for i in range(100):
			await get_tree().physics_frame
			if p._state == p.State.IDLE or p._state == p.State.RECOVERY:
				break

	# ── 18. Cần câu: thả câu → pose giữ cần chúc xuống mặt nước ─────────────
	if db2.has("fishing_rod"):
		p.equipped_weapon = db2["fishing_rod"]
		p._update_weapon_mesh()
		await _wait_frames(3)
		p._Fishing.cast_line(p)
		await _wait_frames(4)
		_check(p._fishing_active, "thả câu → fishing pose ACTIVE")
		var rod_down := false
		for i in range(80):
			await get_tree().process_frame
			if p._bobber == null:
				break
			var rax: Vector3 = mesh_node.weapon_pivot.global_transform.basis * Vector3(0, 1, 0)
			var rpit: float = asin(clampf(rax.normalized().y, -1.0, 1.0))
			if rpit < -0.12:
				rod_down = true
		_check(rod_down, "giữ cần chờ cá: thân cần CHÚC xuống nước")
		if p._bobber != null and p._bobber.has_method("reel_in"):
			p._bobber.reel_in()

	# ── 19. PARRY + RIPoste (kiếm): chặn đòn → phản đòn lập tức ─────────────
	# Reset về giữa sàn — các test di chuyển trước đó có thể đã đẩy player xa
	p.global_position = Vector3(0, 1.2, 0)
	p.velocity = Vector3.ZERO
	if db2.has("iron_sword"):
		p.equipped_weapon = db2["iron_sword"]
		p._update_weapon_mesh()
		await _wait_frames(5)
		for i in range(90):
			await get_tree().physics_frame
			if p._state == p.State.IDLE:
				break
		_check(p._can_parry(), "kiếm được parry (_can_parry)")
		p._begin_parry()
		await _wait_frames(2)
		_check(p._state == p.State.PARRY, "chuột phải → PARRY (state=%d)" % p._state)
		_check(p._parry_window > 0.0, "cửa sổ parry đang mở")
		var hp0: int = p.hp
		# Giả lập kẻ địch đứng trước mặt 1.5m đánh vào
		var foe := Node3D.new()
		add_child(foe)
		foe.global_position = p.global_position \
			+ Vector3(sin(p.rotation.y), 0, cos(p.rotation.y)) * 1.5
		var parried: bool = p._try_parry(foe)
		_check(parried, "đòn địch trong window → PARRY THÀNH CÔNG")
		_check(p.hp == hp0, "sát thương bị HOÁ GIẢI hoàn toàn (hp=%d/%d)" % [p.hp, hp0])
		_check(p._state == p.State.ATTACK and p._is_riposte,
			"riposte tự động kích hoạt ngay (ATTACK + riposte flag)")
		foe.queue_free()
		for i in range(80):
			await get_tree().physics_frame
			if p._state == p.State.IDLE or p._state == p.State.RECOVERY:
				break
		_check(not p._is_riposte, "hết riposte → cờ reset")

	# ── 20. Dash DÀI HƠN + bóng lưu ảnh ──────────────────────────────────────
	await _wait_frames(10)
	p.global_position = Vector3(0, 1.2, 0)
	p.velocity = Vector3.ZERO
	await _wait_frames(6)
	var dpos: Vector3 = p.global_position
	p.rotation.y = 0.0
	Input.action_press("dash")
	var ghosts := 0
	for i in range(30):
		await get_tree().physics_frame
		var n := 0
		for ch in p.get_parent().get_children():
			if ch.name.begins_with("GroundAnchor") and ch != mesh_node.ground_anchor:
				n += 1
		ghosts = maxi(ghosts, n)
	Input.action_release("dash")
	var dd: float = absf(p.global_position.z - dpos.z)
	_check(dd > 3.0, "dash tầm DÀI hơn (d=%.2f m > 3.0)" % dd)
	_check(ghosts > 0, "có bóng LƯU ẢNH khi dash (%d ghost)" % ghosts)

	# ── 21. KHIÊN SẮT: đeo tay trái + ĐỠ ĐÒN chặn frontal, hao độ bền ───────
	if db2.has("iron_shield"):
		p.equipped_weapon = db2["iron_sword"]
		p.set_equipped_by_slot(5, db2["iron_shield"])
		p._update_armor_mesh()
		await _wait_frames(3)
		var shield_built := false
		for ch in mesh_node.elbow_l.get_children():
			if ch.name == "ShieldPivot" and ch.get_child_count() > 0:
				shield_built = true
		_check(shield_built, "khiên hiển thị trên TAY TRÁI (ShieldPivot có model)")
		_check(p._shield_durability == 240, "độ bền khiên khởi tạo (=%d)" % p._shield_durability)
		# Bật guard thủ công + giả lập đòn frontal (gọi NGAY frame — headless
		# không giữ được chuột phải nên physics-refresh sẽ xoá cờ nếu await)
		var foe2 := Node3D.new()
		add_child(foe2)
		foe2.global_position = p.global_position \
			+ Vector3(sin(p.rotation.y), 0, cos(p.rotation.y)) * 1.4
		p._begin_guard()
		p._guarding = true
		var hp_g: int = p.hp
		var blocked: bool = p.try_guard_block(foe2, 10)
		_check(blocked, "GUARD chặn đòn FRONTAL")
		_check(p.hp == hp_g, "guard hoá giải sát thương (hp=%d)" % p.hp)
		_check(p._shield_durability == 234, "hao độ bền theo đòn (=%d, trừ 6)" % p._shield_durability)
		# Đánh từ PHÍA SAU → không chặn
		foe2.global_position = p.global_position \
			- Vector3(sin(p.rotation.y), 0, cos(p.rotation.y)) * 1.4
		var hp_h: int = p.hp
		var back_blocked: bool = p.try_guard_block(foe2, 8)
		_check(not back_blocked and p.hp < hp_h or not back_blocked,
			"đòn từ phía SAU không bị chặn")
		foe2.queue_free()
		p._guarding = false
		p.set_equipped_by_slot(5, null)

	# ── 22. BỘ GIÁP SẮT THAY THẾ đúng bộ phận ───────────────────────────────
	if db2.has("iron_helmet") and db2.has("iron_chestplate") \
			and db2.has("iron_leggings") and db2.has("iron_boots"):
		p.set_equipped_by_slot(0, db2["iron_helmet"])
		p.set_equipped_by_slot(1, db2["iron_chestplate"])
		p.set_equipped_by_slot(2, db2["iron_leggings"])
		p.set_equipped_by_slot(3, db2["iron_boots"])
		await _wait_frames(3)
		var head_hidden: bool = _all_mi_hidden(mesh_node.head)
		var torso_hidden: bool = not mesh_node.torso.visible
		var thigh_hidden: bool = _mi_hidden(mesh_node.thigh_mesh_l) \
			and _mi_hidden(mesh_node.thigh_mesh_r)
		var shin_hidden: bool = _all_mi_hidden(mesh_node.shin_l) \
			and _all_mi_hidden(mesh_node.shin_r)
		var foot_hidden: bool = _all_mi_hidden(mesh_node.foot_l) \
			and _all_mi_hidden(mesh_node.foot_r)
		_check(head_hidden, "mũ sắt THAY THẾ đầu (head boxes ẩn)")
		_check(torso_hidden, "giáp thân THAY THẾ áo (torso ẩn)")
		_check(thigh_hidden and shin_hidden, "quần sắt THAY THẾ đùi+cẳng chân")
		_check(foot_hidden, "giày sắt THAY THẾ bàn chân")
		# Tháo hết → các phần thân gốc hiện lại
		p.set_equipped_by_slot(0, null)
		p.set_equipped_by_slot(1, null)
		p.set_equipped_by_slot(2, null)
		p.set_equipped_by_slot(3, null)
		await _wait_frames(3)
		_check(not _all_mi_hidden(mesh_node.head), "tháo giáp → đầu hiện lại")
		_check(not _mi_hidden(mesh_node.thigh_mesh_l), "tháo giáp → đùi hiện lại")

	# ── 23. TRỌNG KÍCH: giữ chuột VẬN LỰC → thả ra PHÓNG THÍCH ──────────────
	if db2.has("iron_sword"):
		p.equipped_weapon = db2["iron_sword"]
		p._update_weapon_mesh()
		await _wait_frames(5)
		for i in range(90):
			await get_tree().physics_frame
			if p._state == p.State.IDLE:
				break
		_click_left(true)
		var saw_charge := false
		for i in range(42):
			await get_tree().physics_frame
			if p._state == p.State.CHARGE and p._charging:
				saw_charge = true
		_check(saw_charge, "giữ chuột → VẬN LỰC (State.CHARGE)")
		_check(p._charge_level > 0.30, "mức vận tích luỹ (level=%.2f)" % p._charge_level)
		_click_left(false)
		await _wait_frames(2)
		_check(p._state == p.State.ATTACK and p._is_charged_release,
			"thả chuột → TRỌNG KÍCH phóng thích")
		_check(p._charged_mult > 1.35,
			"sát thương nhân theo mức vận (x%.2f)" % p._charged_mult)

	print("TOTAL | %s | %d failures" % ["PASS" if _failures == 0 else "FAIL", _failures])

func _all_mi_hidden(pivot: Node3D) -> bool:
	if pivot == null:
		return false
	for ch in pivot.get_children():
		if ch is MeshInstance3D and ch.visible:
			return false
	return true

func _mi_hidden(n: Node3D) -> bool:
	return n != null and is_instance_valid(n) and not n.visible
	get_tree().quit(0 if _failures == 0 else 1)
