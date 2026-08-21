class_name PlayerAnimator

const _TrailVFX := preload("res://scripts/characters/player/slash_trail_vfx.gd")

## Animator khớp-driven cho rig khối khớp (PlayerBlockMesh).
## Dùng khớp thật: cổ (neck), vai (arm_l/r), khuỷu (elbow_l/r), xương chậu
## (pelvis), hông (leg_l/r), gối (knee_l/r), cổ chân (ankle_l/r), bàn chân
## (foot_l/r). Chuyển động hông→gối→cổ chân được tính từ phase bước để chân
## nhấc lên đúng lúc (logic), các khớp phụ (đầu/balo/thân) chạy theo spring
## (đàn hồi) cho cảm giác trễ tự nhiên.

var walk_cycle_speed: float = 6.5
var sprint_cycle_mult: float = 1.6
## Chu kỳ thở 2.5-3s: speed = TAU / ~2.7 ≈ 2.3. Trước đây 0.9 (~7s) quá chậm.
var idle_breathe_speed: float = 2.3
var swim_cycle_speed: float = 4.5
## Vai hạ thấp thả lỏng khi idle (tăng từ 0 lên độ hạ vai tự nhiên)
var sleep_shoulder_drop: float = 0.04

var mesh: PlayerMesh
var base: CharacterBase
var player: PlayerCharacter
var _last_remaining: float = 0.0

# ── Pha bước (gait phase) ───────────────────────────────────────────────────
## Pha bước tích lũy theo tốc độ ngang THỰC của nhân vật (không phải theo t
## cố định) → tần số tay chân khớp với vận tốc, bàn chân không trượt đất.
var _gait_phase: float = 0.0
var _gait_rate: float = 6.5

func _advance_gait(delta: float) -> float:
	var sp: float = Vector2(base.velocity.x, base.velocity.z).length()
	# ~1.75 rad mỗi mét: tần số khớp tốc độ để bàn chân KHÔNG trượt đất.
	var target: float = clamp(sp * 1.75, 5.0, 15.5)
	# Làm mượt tần số để chuyển idle↔walk↔sprint không giật pha bước.
	_gait_rate = lerpf(_gait_rate, target, minf(1.0, delta * 5.0))
	_gait_phase += _gait_rate * delta
	return _gait_phase

## Chu kỳ gối đúng sinh học — PHÂN BIỆT pha vung / pha trụ qua cờ `swinging`
## (s giảm = đang vung tới trước; s tăng = đang trụ đạp sau):
##  • Vung  : co SÂU giữa pha vung (gót gập lên) rồi DUỖI THẲNG cẳng chân
##            vươn tới trước khi chạm gót — hết trượt patanh
##  • Trụ   : lún nhẹ ngay sau tiếp đất (loading response) rồi gần thẳng đẩy sau
func _gait_knee(s: float, knee_amp: float, swinging: bool) -> float:
	if swinging:
		var u: float = clampf(-s, 0.0, 1.0)   # 0 = dưới thân → 1 = chạm gót
		# Co sâu giữa vung (u≈0.48) rồi DUỖI THẲNG dần tới lúc chạm (u→0.94)
		var co: float = knee_amp * (smoothstep(0.05, 0.48, u) * (1.0 - smoothstep(0.55, 0.94, u)))
		var load: float = 0.24 * smoothstep(0.82, 0.98, u)
		return 0.08 + co + load
	else:
		# Chân trụ: lún gối hấp thụ ngay sau tiếp đất, gần thẳng khi đạp
		var load2: float = 0.20 * exp(-pow((s + 0.75) / 0.30, 2.0))
		var push: float = 0.14 * exp(-pow((s - 0.95) / 0.25, 2.0))
		return 0.08 + load2 + push

# ── Spring state (secondary motion) ─────────────────────────────────────────
var _spos: Dictionary = {}
var _svel: Dictionary = {}

## Spring giảm chấn — target là giá trị chạy, pos trả về có thể vượt (overshoot)
## rồi dao động nhẹ về target → cảm giác đàn hồi.
##
## Áp dụng nghiệm đóng dạng (analytic solution) của bộ dao động đường và sau
## được giảm chấn — ổn định TUYỆT ĐỐI (năng lượng không bao giờ tăng) dù delta
## lớn hay target thay đổi khung nào. Trước đây dùng Euler tường minh + công
## thức vận tốc sai → tiêm năng lượng khi target di chuyển (idle/walk) → khớp
## bay ra ngoài. Dùng nghiệm đúng của  ẍ + 2zw·ẋ + w²·x = 0  (x = pos - target,
## trong 1 bước coi target cố định), cập nhật vận tốc đúng → không tích lũy năng lượng.
func _spring(name: String, target: float, freq: float, zeta: float, delta: float) -> float:
	if delta <= 0.0 or freq <= 0.0:
		_spos[name] = target
		_svel[name] = 0.0
		return target
	var x: float = _spos.get(name, target) - target          # x0 = pos - target
	var v: float = _svel.get(name, 0.0)                       # v0
	var w: float = TAU * freq
	var z: float = clamp(zeta, 0.0, 1.0)
	var zw: float = z * w
	var e: float = exp(-zw * delta)
	if z < 0.9999:
		var wd: float = w * sqrt(1.0 - z * z)
		var wd_dt: float = wd * delta
		var c: float = cos(wd_dt)
		var s: float = sin(wd_dt)
		var x_new: float = e * (x * c + (v + zw * x) / wd * s)
		var v_new: float = e * (v * c - (v * zw + w * w * x) / wd * s)
		_spos[name] = x_new + target
		_svel[name] = v_new
		return _spos[name]
	else:
		# Tiểu điệp (ζ ≈ 1): 0 overshoot, vẫn ổn định.
		# x(t) = (x0 + (v0 + w·x0)·dt)·e^(-w·dt);  v(t) = e^(-w·dt)·[(v0 + w·x0) - w·x(t)]
		var wd_dt: float = w * delta
		var x_new: float = e * (x * (1.0 + wd_dt) + v * delta)
		var v_new: float = e * ((v + w * x) - w * x_new)
		_spos[name] = x_new + target
		_svel[name] = v_new
		return _spos[name]

## Vũ khí tự điều khiển tay riêng (update_pose chạy sau animator trong _process):
## animator nhường tay để tránh giằng co (spring freq cao dễ "giành" lại pose).
const _ARMS_OWNED_WEAPONS: Array[String] = ["ak_12", "m200", "crossbow", "watermelon_cannon", "pumpkin_mortar"]

func _weapon_owns_arms() -> bool:
	# Câu cá: khi đang thả câu/cầm cần chờ, pose cần do PlayerFishing điều khiển
	if player != null and player._fishing_active \
			and player.equipped_weapon != null and player.equipped_weapon.id == "fishing_rod":
		return true
	return player != null and player.equipped_weapon != null \
		and _ARMS_OWNED_WEAPONS.has(player.equipped_weapon.id)

func setup(m: PlayerMesh, b: CharacterBase) -> void:
	mesh = m
	base = b
	player = b as PlayerCharacter

## Xoá sạch tư thế + trạng thái spring (gọi khi hồi sinh): animation chết gập
## người rig.rotation.x ~1.35 rad bằng lerp thẳng vào node, KHÔNG đi qua spring
## → nếu không reset, khớp giữ tư thế nằm và spring nhảy cóc từ giá trị cũ.
func reset_pose() -> void:
	_spos.clear()
	_svel.clear()
	_gait_phase = 0.0
	_gait_rate = 6.5
	_kill_trail()
	_trail_released = true
	_last_remaining = 0.0
	if mesh == null:
		return
	for j in [mesh.rig, mesh.pelvis, mesh.body, mesh.torso, mesh.neck, mesh.head,
			mesh.arm_l, mesh.arm_r, mesh.elbow_l, mesh.elbow_r,
			mesh.leg_l, mesh.leg_r, mesh.knee_l, mesh.knee_r,
			mesh.ankle_l, mesh.ankle_r, mesh.foot_l, mesh.foot_r,
			mesh.backpack]:
		if j != null and is_instance_valid(j):
			j.rotation = Vector3.ZERO
	if mesh.pelvis != null and is_instance_valid(mesh.pelvis):
		mesh.pelvis.position = Vector3(0, 0.47, 0)
	if mesh.rig != null and is_instance_valid(mesh.rig):
		mesh.rig.position = Vector3(0, 0.02, 0)
	if mesh.backpack != null and is_instance_valid(mesh.backpack):
		mesh.backpack.position = Vector3(0, 0.10, -0.13)

func animate(delta: float) -> void:
	var t: float = base._time
	match base._state:
		CharacterBase.State.IDLE:
			_idle(delta, t)
		CharacterBase.State.WALK:
			_walk(delta, t)
		CharacterBase.State.SPRINT:
			_sprint(delta, t)
		CharacterBase.State.CROUCH:
			_crouch(delta, t)
		CharacterBase.State.DASH:
			_dash(delta, t)
		CharacterBase.State.ATTACK:
			_attack(delta, t)
		CharacterBase.State.RECOVERY:
			_recovery(delta, t)
		CharacterBase.State.PARRY:
			_parry(delta, t)
		CharacterBase.State.CHARGE:
			_charge_pose(delta)
		CharacterBase.State.AIR_ATTACK:
			_air_attack(delta, t)
		CharacterBase.State.JUMP:
			_air(delta, t, true)
		CharacterBase.State.FALL:
			_air(delta, t, false)
		CharacterBase.State.HIT:
			_hit(delta, t)
		CharacterBase.State.DEAD:
			_dead(delta, t)
		CharacterBase.State.SWIM:
			_swim(delta, t)
		CharacterBase.State.EAT:
			_eat(delta, t)
	# ── Lưới an toàn thế cầm vũ khí ──────────────────────────────────────────
	# HIT/DASH/EAT... ngắt giữa đòn sẽ bỏ qua recovery → weapon_pivot kẹt ở góc
	# chém, kiếm cầm lệch hẳn. Mọi state KHÔNG phải đánh đều ép wp về IDLE_WP.
	if base._state != CharacterBase.State.ATTACK \
			and base._state != CharacterBase.State.AIR_ATTACK \
			and not _weapon_owns_arms() \
			and mesh.weapon_pivot != null and is_instance_valid(mesh.weapon_pivot):
		mesh.weapon_pivot.rotation_degrees = \
			mesh.weapon_pivot.rotation_degrees.lerp(IDLE_WP, minf(1.0, delta * 8.0))
	# Khiên: ngoài lúc đỡ → treo về dọc song song cánh tay
	if base._state != CharacterBase.State.PARRY \
			and mesh.shield_pivot != null and is_instance_valid(mesh.shield_pivot):
		mesh.shield_pivot.rotation_degrees = \
			mesh.shield_pivot.rotation_degrees.lerp(Vector3(0, -90, 0), minf(1.0, delta * 8.0))
	# Clamp an toàn: giữ ankle + foot ở mức dorsiflex nhẹ (mũi hướng lên)
	# để tránh chân chìm đất khi đứng độn (foot sink do spring overshoot).
	# Chỉ áp dụng khi trên mặt đất (không cho bơi/rơi).
	_clamp_feet_safe()

## Clamp an toàn cho bàn chân: đảm bảo ankle & foot không bao giờ quay
## xuống dương nghĩa (plantarflex → mũi hướng xuống) nhiều quá mức khi đứng độn.
## Spring overshoot có thể khiến giá trị vượt target âm → bàn chân chìm đất.
## Bỏ qua khi đang bơi/rơi để giữ độ biến dạng chân tự nhiên của swim kick,
## và khi sprint (gót nhấc khỏi đất — tiếp đất bằng mũi là chủ đích).
func _clamp_feet_safe() -> void:
	if mesh == null or base == null:
		return
	var s: int = base._state
	# ATTACK cũng loại: thế đánh có chủ ý nhấc gót chân sau đạp nền (plantarflex)
	if s == CharacterBase.State.SWIM or s == CharacterBase.State.JUMP or s == CharacterBase.State.FALL or s == CharacterBase.State.DEAD or s == CharacterBase.State.SPRINT or s == CharacterBase.State.CROUCH or s == CharacterBase.State.AIR_ATTACK or s == CharacterBase.State.ATTACK:
		return
	if mesh.ankle_l != null and is_instance_valid(mesh.ankle_l):
		mesh.ankle_l.rotation.x = max(mesh.ankle_l.rotation.x, -0.02)
	if mesh.ankle_r != null and is_instance_valid(mesh.ankle_r):
		mesh.ankle_r.rotation.x = max(mesh.ankle_r.rotation.x, -0.02)
	if mesh.foot_l != null and is_instance_valid(mesh.foot_l):
		mesh.foot_l.rotation.x = max(mesh.foot_l.rotation.x, -0.05)
	if mesh.foot_r != null and is_instance_valid(mesh.foot_r):
		mesh.foot_r.rotation.x = max(mesh.foot_r.rotation.x, -0.05)

# ── Dáng đứng / thư giãn ────────────────────────────────────────────────────
## Idle: hô hấp chậm (chu kỳ 2.5-3s, ngực phồng/hạ), trọng tâm dồn qua lại
## từ chân trái sang phải, vai hạ thấp thả lỏng, tay buông thõng ngón hơi co,
## đung đưa rất khẽ theo nhịp thở. Chân rộng bằng vai, gối hơi chùng.
func _idle(delta: float, t: float) -> void:
	var breath: float = sin(t * idle_breathe_speed)
	var shift: float = sin(t * 0.42)
	var chest: float = abs(breath) * 0.06
	# Trọng tâm nhịp nhàng dồn lực từ chân này sang chân kia (qua pelvis z + nghiêng hông)
	mesh.pelvis.position.z = _spring("pelvis_z", shift * 0.05, 2.5, 0.9, delta)
	mesh.pelvis.position.x = _spring("pelvis_sway", shift * 0.012, 2.5, 0.9, delta)
	mesh.pelvis.rotation.z = _spring("pelvis_twist", shift * 0.06, 2.0, 0.8, delta)
	# Neutralize mọi khớp nghiêng có thể bị kẹt từ state trước (air/hit/dash...):
	# nếu không ghi đè liên tục, hông/thân giữ nguyên độ nghiêng cũ → đứng lệch.
	mesh.pelvis.rotation.x = _spring("pelvis_x", 0.0, 3.0, 1.0, delta)
	mesh.body.rotation.z = _spring("body_z", 0.0, 4.0, 1.0, delta)
	mesh.rig.rotation.z = _spring("rig_z", 0.0, 5.0, 1.0, delta)
	mesh.head.rotation.y = _spring("head_y", shift * 0.04, 2.5, 0.8, delta)
	mesh.backpack.rotation.x = _spring("bp_rx", 0.0, 4.0, 1.0, delta)
	mesh.pelvis.rotation.x = _spring("pelvis_x", -shift * 0.03, 2.0, 0.8, delta)
	# Nhún thở: ngực phồng lên, rig hơi nhấc theo nhịp hô hấp
	mesh.rig.position.y = _spring("rig_y", 0.02 + chest * 0.04, 3.0, 1.0, delta)
	mesh.rig.rotation.x = _spring("rig_x", breath * 0.010, 3.0, 1.0, delta)
	# Thân hô hấp nhẹ — ngực phồng → thân hơi ngửa nhẹ
	mesh.body.rotation.x = _spring("body_x", breath * 0.015, 3.0, 0.9, delta)
	mesh.neck.rotation.y = _spring("neck_y", shift * 0.07, 2.0, 0.7, delta)
	mesh.head.rotation.x = _spring("head_x", breath * 0.030, 3.5, 0.9, delta)
	mesh.head.rotation.z = _spring("head_z", sin(t * 0.5) * 0.03, 3.0, 0.8, delta)
	mesh.neck.rotation.x = _spring("neck_x", -breath * 0.025, 3.0, 0.9, delta)
	mesh.backpack.position.z = _spring("bp_z", -0.02 + chest * 0.012, 3.0, 1.0, delta)
	if not _weapon_owns_arms():
		# Vai hạ thấp thả lỏng, tay buông thõng tự nhiên bên hông đung rất khẽ theo nhịp thở
		var ab: float = 1.0 + breath * 0.12
		mesh.arm_l.rotation.x = _spring("arm_l_x", (-0.10 - sleep_shoulder_drop) * ab, 3.0, 0.9, delta)
		mesh.arm_r.rotation.x = _spring("arm_r_x", (-0.10 - sleep_shoulder_drop) * ab, 3.0, 0.9, delta)
		mesh.arm_l.rotation.z = _spring("arm_l_z", 0.07 * ab, 3.0, 0.8, delta)
		mesh.arm_r.rotation.z = _spring("arm_r_z", -0.07 * ab, 3.0, 0.8, delta)
		_follow_l_elbow(delta)
		_follow_r_elbow(delta)
	# Chân mở rộng bằng vai, đùi hơi tách nhẹ, gối chùng (không khóa khớp)
	mesh.leg_l.rotation.x = _spring("leg_l_x", 0.07, 4.0, 1.0, delta)
	mesh.leg_r.rotation.x = _spring("leg_r_x", 0.07, 4.0, 1.0, delta)
	mesh.knee_l.rotation.x = _spring("knee_l_x", 0.06, 4.0, 1.0, delta)
	mesh.knee_r.rotation.x = _spring("knee_r_x", 0.06, 4.0, 1.0, delta)
	# Trọng tâm dồn nghiêng nhẹ theo bên khi shift — đùi đối diện hạ thấp hơn
	mesh.leg_l.rotation.z = _spring("leg_l_z", 0.02 + shift * 0.02, 3.0, 0.9, delta)
	mesh.leg_r.rotation.z = _spring("leg_r_z", -0.02 - shift * 0.02, 3.0, 0.9, delta)
	mesh.ankle_l.rotation.x = _spring("ankle_l_x", 0.03, 4.0, 1.0, delta)
	mesh.ankle_r.rotation.x = _spring("ankle_r_x", 0.03, 4.0, 1.0, delta)
	mesh.foot_l.rotation.x = _spring("foot_l_x", 0.0, 6.0, 1.0, delta)
	mesh.foot_r.rotation.x = _spring("foot_r_x", 0.0, 6.0, 1.0, delta)

# ── Đi bộ — chân dẫn bởi pha bước theo tốc độ thật, tay chéo chân đối diện ───
## Quy ước dấu (nhân vật nhìn về +Z): rotation.x âm = chi vung tới TRƯỚC,
## dương = vung ra SAU. Khuỷu chỉ gập về trước (âm) như giải phẫu thật.
func _walk(delta: float, _t: float) -> void:
	var cyc: float = _advance_gait(delta)
	var s_l: float = sin(cyc)
	var s_r: float = sin(cyc + PI)
	# Biên độ theo tốc độ thực: đi chậm bước ngắn, đi nhanh sải dài.
	var sp: float = Vector2(base.velocity.x, base.velocity.z).length()
	var spd_n: float = clamp(sp / max(base.move_speed, 0.1), 0.0, 1.6)
	var amp: float      = 0.46 + spd_n * 0.24       # biên độ hông (tới 45°)
	var knee_amp: float = 0.72 + spd_n * 0.38       # co gối giữa pha vung
	var toe_off: float  = 0.30 + spd_n * 0.14       # duỗi mũi chân khi đạp
	# Hông BẤT ĐỐI XỨNG: vung tới SÂU hơn (cẳng chân đưa rộng lên trước),
	# đưa sau GIẢM mạnh — chân không quét quá nửa sau thân (hết cảm giác lùi).
	var hip_fwd: float = amp * 1.18
	var hip_back: float = amp * 0.60
	var hip_l: float = s_l * (hip_fwd if s_l < 0.0 else hip_back) + 0.06 * pow(max(0.0, s_l), 1.5)
	var hip_r: float = s_r * (hip_fwd if s_r < 0.0 else hip_back) + 0.06 * pow(max(0.0, s_r), 1.5)
	# Gối: co giữa vung → DUỖI THẲNG vươn tới → lún tiếp đất → đạp
	var knee_l: float = _gait_knee(s_l, knee_amp, cos(cyc) < 0.0)
	var knee_r: float = _gait_knee(s_r, knee_amp, cos(cyc + PI) < 0.0)
	# Cổ chân: gập gót MẠNH đúng lúc chạm đất (slap — chỉ khi ĐANG vung tới),
	# duỗi mũi dứt khi đạp cuối
	var flick_l: float = -toe_off * pow(max(0.0, s_l), 3.0)
	var flick_r: float = -toe_off * pow(max(0.0, s_r), 3.0)
	var slap_l: float = 0.34 * exp(-pow((s_l + 0.90) / 0.22, 2.0)) if cos(cyc) < 0.0 else 0.0
	var slap_r: float = 0.34 * exp(-pow((s_r + 0.90) / 0.22, 2.0)) if cos(cyc + PI) < 0.0 else 0.0
	var dors_l: float = 0.20 * max(0.0, -s_l) + slap_l
	var dors_r: float = 0.20 * max(0.0, -s_r) + slap_r
	var ankle_l: float = flick_l + dors_l
	var ankle_r: float = flick_r + dors_r

	mesh.leg_l.rotation.x   = _spring("leg_l_x",   hip_l,  10.0, 1.0, delta)
	mesh.leg_r.rotation.x   = _spring("leg_r_x",   hip_r,  10.0, 1.0, delta)
	mesh.knee_l.rotation.x  = _spring("knee_l_x",  knee_l,  10.0, 1.0, delta)
	mesh.knee_r.rotation.x  = _spring("knee_r_x",  knee_r,  10.0, 1.0, delta)
	mesh.ankle_l.rotation.x = _spring("ankle_l_x", ankle_l, 10.0, 1.0, delta)
	mesh.ankle_r.rotation.x = _spring("ankle_r_x", ankle_r, 10.0, 1.0, delta)
	# Chân hỗ trợ (stance) giữ mũi chân phẳng; chân hớt (swing) gãy mũi lên
	# để không vấp. Trường hợp stance ankle<0 → foot level, không lún xuống đất.
	mesh.foot_l.rotation.x = _spring("foot_l_x", max(0.0, -ankle_l) * 0.30, 8.0, 1.0, delta)
	mesh.foot_r.rotation.x = _spring("foot_r_x", max(0.0, -ankle_r) * 0.30, 8.0, 1.0, delta)

	# Nhún dọc: đỉnh ở mid-stance (chân trụ thẳng đứng), thấp nhất lúc
	# double-support — biên độ LỚN + đường cong sắc để thân "rơi" vào từng bước.
	var bob: float = pow(1.0 - abs(s_l), 1.35) * (0.055 + spd_n * 0.030)
	mesh.rig.position.y = _spring("rig_y", 0.02 + bob, 7.0, 1.0, delta)
	# Nghiêng người nhẹ về trước theo tốc độ (rotation.x dương = ngả trước).
	mesh.rig.rotation.x = _spring("rig_x", 0.03 + spd_n * 0.06, 6.0, 0.9, delta)
	# Hông lăn sâu: hạ hông bên chân vung — trọng tâm thật sự dồn bên trụ.
	mesh.pelvis.rotation.z = _spring("pelvis_twist", -s_l * (0.055 + spd_n * 0.040), 6.0, 0.8, delta)
	# Lắc trọng tâm NGANG sang bên chân trụ.
	mesh.pelvis.position.x = _spring("pelvis_sway", -cos(cyc) * (0.034 + spd_n * 0.012), 5.0, 0.9, delta)
	mesh.pelvis.position.z = _spring("pelvis_z", 0.0, 5.0, 0.9, delta)
	# Neutralize khớp nghiêng không thuộc walk — chống kẹt nghiêng từ state trước.
	mesh.pelvis.rotation.x = _spring("pelvis_x", 0.0, 4.0, 1.0, delta)
	mesh.body.rotation.z = _spring("body_z", 0.0, 5.0, 1.0, delta)
	mesh.rig.rotation.z = _spring("rig_z", 0.0, 5.0, 1.0, delta)
	mesh.head.rotation.y = _spring("head_y", 0.0, 4.0, 0.8, delta)
	# Đầu ổn định nhìn thẳng — bù ngược nhẹ cho nhún thân.
	mesh.body.rotation.x = _spring("body_x", sin(cyc) * (0.02 + spd_n * 0.015), 5.0, 0.9, delta)
	mesh.neck.rotation.y = _spring("neck_y", s_l * 0.05, 5.0, 0.8, delta)
	mesh.head.rotation.z = _spring("head_z", sin(cyc) * 0.04, 5.0, 0.8, delta)
	mesh.head.rotation.x = _spring("head_x", -(0.03 + spd_n * 0.05) * 0.6, 5.0, 0.9, delta)
	mesh.neck.rotation.x = _spring("neck_x", sin(cyc) * 0.015, 5.0, 0.9, delta)
	mesh.backpack.position.z = _spring("bp_z", -0.02 + bob * 0.4, 6.0, 0.9, delta)
	mesh.backpack.rotation.x = _spring("bp_rx", sin(cyc) * 0.04, 6.0, 0.9, delta)

	# Tay vung NGƯỢC chân cùng bên (contralateral): chân L tới → tay L ra sau.
	# Base gần thẳng đứng (-0.06) thay vì chúi 34° như trước — hết dáng zombie.
	if not _weapon_owns_arms():
		mesh.arm_l.rotation.x = _spring("arm_l_x", -0.06 - hip_l * 0.85, 9.0, 1.0, delta)
		mesh.arm_r.rotation.x = _spring("arm_r_x", -0.06 - hip_r * 0.85, 9.0, 1.0, delta)
		mesh.arm_l.rotation.z = _spring("arm_l_z", 0.06, 7.0, 1.0, delta)
		mesh.arm_r.rotation.z = _spring("arm_r_z", -0.06, 7.0, 1.0, delta)
		_follow_l_elbow(delta)
		_follow_r_elbow(delta)

# ── Sprint (chạy nhanh / bứt tốc) ──────────────────────────────────────────
## Thân đổ gập 15-20° phía trước dùng trọng lực; cột sống xoay nhẹ theo nhịp
## vung tay. Tay vung rộng từ ngang hông vọt lên ngang cằm, khuỷu khóa ~90°,
## vai rung theo tần số chân. Đùi nâng cao, chân sau duỗi thẳng (hip extension)
## đạp nền, tiếp đất bằng mũi/nửa trước bàn chân (gót không chạm đất).
func _sprint(delta: float, _t: float) -> void:
	var cyc: float = _advance_gait(delta)
	# Pha chân — đối xứng chân trái/phải
	var s_l: float = sin(cyc)
	var s_r: float = sin(cyc + PI)
	# Đùi BẤT ĐỐI XỨNG: vung tới gần ngang (1.46), đưa sau ngắn gọn (0.88)
	var hip_fwd_s: float = 1.46
	var hip_back_s: float = 0.88
	var hip_l: float = s_l * (hip_fwd_s if s_l < 0.0 else hip_back_s) + 0.10 * pow(max(0.0, s_l), 1.5)
	var hip_r: float = s_r * (hip_fwd_s if s_r < 0.0 else hip_back_s) + 0.10 * pow(max(0.0, s_r), 1.5)
	# Gối: co gọn giữa vung → duỗi thẳng vươn tới → đạp nổ (chu kỳ sinh học)
	var knee_l: float = _gait_knee(s_l, 1.45, cos(cyc) < 0.0)
	var knee_r: float = _gait_knee(s_r, 1.45, cos(cyc + PI) < 0.0)
	# Cổ chân: đạp bằng mũi dứt khoát (plantarflex sâu), gập gót khi hớt
	var ankle_l: float = -0.55 * max(0.0, s_l) + 0.28 * max(0.0, -s_l)
	var ankle_r: float = -0.55 * max(0.0, s_r) + 0.28 * max(0.0, -s_r)

	mesh.leg_l.rotation.x   = _spring("leg_l_x",   hip_l,  11.0, 1.0, delta)
	mesh.leg_r.rotation.x   = _spring("leg_r_x",   hip_r,  11.0, 1.0, delta)
	mesh.knee_l.rotation.x  = _spring("knee_l_x",  knee_l,  11.0, 1.0, delta)
	mesh.knee_r.rotation.x  = _spring("knee_r_x",  knee_r,  11.0, 1.0, delta)
	mesh.ankle_l.rotation.x = _spring("ankle_l_x", ankle_l, 12.0, 1.0, delta)
	mesh.ankle_r.rotation.x = _spring("ankle_r_x", ankle_r, 12.0, 1.0, delta)
	# Gót nhấc khỏi đất — foot gập mạnh theo mũi (plantarflex) để góc bám nền
	mesh.foot_l.rotation.x = _spring("foot_l_x", -ankle_l * 0.5, 10.0, 1.0, delta)
	mesh.foot_r.rotation.x = _spring("foot_r_x", -ankle_r * 0.5, 10.0, 1.0, delta)

	# Thân trên đổ gập về trước 15-20° (~0.26-0.35 rad)
	mesh.rig.rotation.x = _spring("rig_x", 0.30, 10.0, 1.0, delta)
	mesh.rig.rotation.z = _spring("rig_z", sin(cyc) * 0.03, 9.0, 0.9, delta)
	# Nhún dọc: đỉnh ở mid-stance, biên độ lớn — mỗi bước đập xuống một nhịp
	var bob: float = pow(1.0 - abs(s_l), 1.3) * 0.10
	mesh.rig.position.y = _spring("rig_y", 0.02 + bob, 9.0, 1.0, delta)
	# Cột sống xoay nhẹ theo nhịp vung tay
	mesh.body.rotation.x = _spring("body_x", -0.12 + sin(cyc) * 0.04, 8.0, 0.9, delta)
	mesh.pelvis.rotation.z = _spring("pelvis_twist", -s_l * 0.13, 8.0, 0.8, delta)
	mesh.pelvis.position.x = _spring("pelvis_sway", -cos(cyc) * 0.042, 6.0, 0.9, delta)
	mesh.pelvis.rotation.x = _spring("pelvis_x", -0.05, 7.0, 0.9, delta)
	mesh.pelvis.position.z = _spring("pelvis_z", 0.0, 6.0, 0.9, delta)
	mesh.body.rotation.z = _spring("body_z", 0.0, 5.0, 1.0, delta)
	mesh.head.rotation.y = _spring("head_y", 0.0, 5.0, 0.8, delta)
	mesh.neck.rotation.y = _spring("neck_y", s_l * 0.10, 7.0, 0.8, delta)
	mesh.head.rotation.x = _spring("head_x", -0.15, 7.0, 0.9, delta)
	mesh.head.rotation.z = _spring("head_z", sin(cyc) * 0.05, 7.0, 0.8, delta)
	mesh.neck.rotation.x = _spring("neck_x", -0.06, 7.0, 0.9, delta)
	mesh.backpack.position.z = _spring("bp_z", -0.06 + bob * 0.25, 8.0, 0.9, delta)
	mesh.backpack.rotation.x = _spring("bp_rx", sin(cyc) * 0.06, 8.0, 0.9, delta)

	# Tay vung NGƯỢC chân cùng bên, base thẳng đứng; khuỷu khóa gập về trước
	if not _weapon_owns_arms():
		mesh.arm_l.rotation.x = _spring("arm_l_x", -0.10 - hip_l * 0.52, 12.0, 1.0, delta)
		mesh.arm_r.rotation.x = _spring("arm_r_x", -0.10 - hip_r * 0.52, 12.0, 1.0, delta)
		mesh.arm_l.rotation.z = _spring("arm_l_z", 0.14, 9.0, 0.9, delta)
		mesh.arm_r.rotation.z = _spring("arm_r_z", -0.14, 9.0, 0.9, delta)
		# Khuỷu khóa ~70-90° gập về TRƯỚC (âm = đúng giải phẫu)
		mesh.elbow_l.rotation.x = _spring("elbow_l_x", -1.20, 14.0, 1.0, delta)
		mesh.elbow_r.rotation.x = _spring("elbow_r_x", -1.20, 14.0, 1.0, delta)

# ── Ngồi xổm / lẻn ─────────────────────────────────────────────────────────
## Chuyển tiếp vào: hông hạ thấp đột ngột, gập sâu gối, cột sống uốn cong,
## đầu & vai gập về trước ~35°.
## Crouch-walk: bước ngắn, đùi song song/gần mặt đất, tiếp đất bằng mũi/bản
## giữa (không gót) giảm xóc & tiếng động; tay đưa cao ngang ngực giữ thăng
## bằng, khuỷu tay co gập.
func _crouch(delta: float, t: float) -> void:
	var cyc: float = _advance_gait(delta)
	var s_l: float = sin(cyc)
	var s_r: float = sin(cyc + PI)
	# Transition-in: hạ thấp hông đột ngột, gối gập sâu
	mesh.rig.position.y = _spring("rig_y", -0.26, 11.0, 1.0, delta)
	# Cột sống uốn cong về trước ~30-40° (tổng rig + thân + cổ + đầu)
	mesh.rig.rotation.x = _spring("rig_x", 0.22, 9.0, 0.9, delta)
	mesh.pelvis.rotation.x = _spring("pelvis_x", -0.42, 9.0, 1.0, delta)
	mesh.body.rotation.x = _spring("body_x", 0.18, 8.0, 0.9, delta)
	mesh.neck.rotation.x = _spring("neck_x", 0.10, 7.0, 0.9, delta)
	mesh.head.rotation.x = _spring("head_x", -0.30, 7.0, 0.9, delta)
	mesh.head.rotation.z = _spring("head_z", sin(t * 0.6) * 0.04, 5.0, 0.8, delta)
	mesh.backpack.position.z = _spring("bp_z", -0.08, 5.0, 1.0, delta)
	mesh.pelvis.position.x = _spring("pelvis_sway", -cos(cyc) * 0.018, 5.0, 0.9, delta)
	# Chân: bước ngắn — đùi gần như song song mặt đất (gập sâu toàn bộ khớp).
	# sin<0 = vung tới (nhấc), sin>0 = đỡ sau.
	var leg_base: float = -0.85
	mesh.leg_l.rotation.x = _spring("leg_l_x", leg_base + s_l * 0.16, 9.0, 1.0, delta)
	mesh.leg_r.rotation.x = _spring("leg_r_x", leg_base + s_r * 0.16, 9.0, 1.0, delta)
	# Gối gập sâu khi chân hớt lên, duỗi nhẹ khi đỡ — đùi giữ sát mặt đất
	mesh.knee_l.rotation.x = _spring("knee_l_x", 1.40 + max(0.0, -s_l) * 0.25, 9.0, 1.0, delta)
	mesh.knee_r.rotation.x = _spring("knee_r_x", 1.40 + max(0.0, -s_r) * 0.25, 9.0, 1.0, delta)
	# Cổ chân: gót nhấc — tiếp đất bằng mu/mũi bàn chân (dorsiflex nhẹ).
	# [CROUCH] exempt from foot-sink clamp để toe-strike có thể thể hiện.
	var stance_l: float = clamp(-s_l * 0.30, 0.0, 0.30) if s_l < 0.0 else 0.0
	var stance_r: float = clamp(-s_r * 0.30, 0.0, 0.30) if s_r < 0.0 else 0.0
	var swing_l: float  = max(0.0, s_l) * 0.10
	var swing_r: float  = max(0.0, s_r) * 0.10
	mesh.ankle_l.rotation.x = _spring("ankle_l_x", stance_l + swing_l, 8.0, 1.0, delta)
	mesh.ankle_r.rotation.x = _spring("ankle_r_x", stance_r + swing_r, 8.0, 1.0, delta)
	mesh.foot_l.rotation.x = _spring("foot_l_x", 0.0, 6.0, 1.0, delta)
	mesh.foot_r.rotation.x = _spring("foot_r_x", 0.0, 6.0, 1.0, delta)
	if not _weapon_owns_arms():
		# Tay đưa cao ngang ngực/hông giữ thăng bằng, vung ngược chân, khuỷu co gập
		mesh.arm_l.rotation.x = _spring("arm_l_x", -0.50 - s_l * 0.10, 8.0, 0.8, delta)
		mesh.arm_r.rotation.x = _spring("arm_r_x", -0.50 - s_r * 0.10, 8.0, 0.8, delta)
		mesh.arm_l.rotation.z = _spring("arm_l_z", 0.15, 7.0, 0.9, delta)
		mesh.arm_r.rotation.z = _spring("arm_r_z", -0.15, 7.0, 0.9, delta)
		mesh.elbow_l.rotation.x = _spring("elbow_l_x", -0.90, 8.0, 0.8, delta)
		mesh.elbow_r.rotation.x = _spring("elbow_r_x", -0.90, 8.0, 0.8, delta)
		_follow_l_elbow(delta)
		_follow_r_elbow(delta)

# ── Dash / Dodge — bước né LOW GLIDE ─────────────────────────────────────────
## Windup (~12%): hạ thấp lấy đà, gối chùng, tay rút về sau
## Glide  (~70%): THÂN THẤP lao tới 24° — chân DẪN duỗi đặt XA TRƯỚC gót trụ,
##                chân SAU duỗi đạp mũi kéo lê mặt đất, tay ôm thẳng cân bằng
## Recover(~18%): thu hai chân về dưới thân, dâng người trở lại
func _dash(delta: float, _t: float) -> void:
	var rem: float = base._dash_timer
	var prog: float = 1.0 - clampf(rem / base.dash_duration, 0.0, 1.0)
	var down: float = smoothstep(0.0, 0.12, prog)
	var glide: float = smoothstep(0.12, 0.30, prog) * (1.0 - smoothstep(0.78, 0.94, prog))
	var rec: float = smoothstep(0.82, 1.0, prog)

	mesh.rig.position.y = _spring("rig_y", 0.02 - down * 0.10 - glide * 0.10 + rec * 0.06, 14.0, 1.0, delta)
	mesh.rig.rotation.x = _spring("rig_x", 0.10 * down + 0.42 * glide + 0.10 * rec, 13.0, 0.9, delta)
	mesh.pelvis.rotation.x = _spring("pelvis_x", -0.10 * glide, 12.0, 0.9, delta)
	mesh.body.rotation.x = _spring("body_x", 0.08 * down + 0.14 * glide + 0.10 * rec, 12.0, 0.9, delta)
	mesh.head.rotation.x = _spring("head_x", -0.16 * glide - 0.10 * rec, 12.0, 0.9, delta)
	mesh.neck.rotation.x = _spring("neck_x", 0.08 * glide, 12.0, 0.9, delta)
	mesh.backpack.position.z = _spring("bp_z", -0.05 * glide - 0.03 * rec, 12.0, 1.0, delta)
	mesh.pelvis.position.x = _spring("pelvis_sway", 0.0, 8.0, 0.9, delta)

	if not _weapon_owns_arms():
		# Tay: windup rút sau → glide ôm thẳng song song giữ thăng bằng → xòe hãm
		var ax: float = -0.55 * down - 0.15 * glide - 0.35 * rec
		var az: float = 0.30 * down + 0.10 * glide + 0.34 * rec
		mesh.arm_r.rotation.x = _spring("arm_r_x", ax, 14.0, 0.9, delta)
		mesh.arm_l.rotation.x = _spring("arm_l_x", ax * 0.8, 14.0, 0.9, delta)
		mesh.arm_r.rotation.z = _spring("arm_r_z", -az, 13.0, 0.9, delta)
		mesh.arm_l.rotation.z = _spring("arm_l_z", az, 13.0, 0.9, delta)
		mesh.elbow_r.rotation.x = _spring("elbow_r_x", -0.85 * down - 0.30 * glide - 0.10 * rec, 13.0, 0.9, delta)
		mesh.elbow_l.rotation.x = _spring("elbow_l_x", -0.85 * down - 0.50 * glide - 0.10 * rec, 13.0, 0.9, delta)

	# Chân dẫn (trái) đặt xa trước gót trụ; chân sau (phải) đạp mũi kéo lê
	var lead := Vector3(-0.30, 0.75, 0.10) * down
	lead = lead.lerp(Vector3(-0.78, 0.48, 0.22), glide)
	lead = lead.lerp(Vector3(-0.10, 0.35, 0.05), rec)
	var trail := Vector3(0.25, 0.65, -0.10) * down
	trail = trail.lerp(Vector3(0.72, 0.20, -0.46), glide)
	trail = trail.lerp(Vector3(0.08, 0.40, 0.00), rec)
	mesh.leg_l.rotation.x = _spring("leg_l_x", lead.x, 13.0, 1.0, delta)
	mesh.knee_l.rotation.x = _spring("knee_l_x", lead.y, 13.0, 1.0, delta)
	mesh.ankle_l.rotation.x = _spring("ankle_l_x", lead.z, 12.0, 1.0, delta)
	mesh.leg_r.rotation.x = _spring("leg_r_x", trail.x, 13.0, 1.0, delta)
	mesh.knee_r.rotation.x = _spring("knee_r_x", trail.y, 13.0, 1.0, delta)
	mesh.ankle_r.rotation.x = _spring("ankle_r_x", trail.z, 12.0, 1.0, delta)
	mesh.foot_l.rotation.x = _spring("foot_l_x", 0.0, 12.0, 1.0, delta)
	mesh.foot_r.rotation.x = _spring("foot_r_x", 0.0, 12.0, 1.0, delta)

# ── Nhảy / Rơi — NHẢY GỐI TÚC compact mạnh mẽ ────────────────────────────────
## Take-off : chân ĐẨY (phải) duỗi bung mũi, chân DẪN (trái) hông vung mạnh
##            lên trước — thân đổ tới, tay vung ĐỐI BÊN (phải lên)
## Bay      : TÚC GỐI — cả hai chân co gập lên trước ngực (dẫn cao hơn, sau
##            thấp lệch sau một nhịp), thân gom lại — dáng nhảy gọn mà lực
## Rơi      : hai chân duỗi xuống chuẩn bị, chân dẫn tới trước một nhịp,
##            gót gập sẵn, tay giơ giữ thăng bằng
## Tiếp đất : hai gối gập sâu khác mức hấp thụ, thân ôm xuống, tay chống trước
func _air(delta: float, _t: float, rising: bool) -> void:
	var vy: float = base.velocity.y
	var on_floor: bool = base.is_on_floor()
	# Tiến trình pha: apex_k theo |vy| — LÊN dần tới đỉnh rồi TỤT DẦN sau đỉnh
	# (không reset khi chuyển JUMP→FALL để tư thế túc hiển thị trọn vẹn).
	# Mũ 0.70 = front-load: lên nhanh giữ cao lâu — bù độ trễ spring gối.
	var rise_p: float = pow(clampf(1.0 - abs(vy) / max(base._jump_v, 0.001), 0.0, 1.0), 0.70)
	var fall_d: float = clampf(-vy / max(base._grav_fall, 0.001), 0.0, 1.0) if (not rising and vy < 0.0) else 0.0
	var landing: float = fall_d
	if not rising and on_floor:
		landing = 1.0

	# ── Chân DẪN (trái): đạp lên → GỐI TÚC CAO sát ngực → duỗi đón → hấp thụ ──
	var lead := Vector3(-0.55, 1.20, 0.10)                            # take-off drive
	lead = lead.lerp(Vector3(-1.26, 1.72, 0.16), rise_p)              # apex: túc cao
	lead = lead.lerp(Vector3(-0.42, 0.58, 0.34), minf(fall_d, 1.0))   # duỗi đón đất
	lead = lead.lerp(Vector3(-0.58, 1.10, 0.36), landing)             # hấp thụ sâu
	# ── Chân SAU (phải): duỗi bung mũi → TÚC THEO thấp hơn lệch sau 1 nhịp ──
	var trail := Vector3(0.38, 0.14, -0.52)
	trail = trail.lerp(Vector3(-0.68, 1.58, 0.14), rise_p)
	trail = trail.lerp(Vector3(0.22, 0.92, -0.18), minf(fall_d, 1.0))
	trail = trail.lerp(Vector3(-0.34, 1.02, 0.30), landing)

	mesh.leg_l.rotation.x = _spring("leg_l_x", lead.x, 11.0, 1.0, delta)
	mesh.knee_l.rotation.x = _spring("knee_l_x", lead.y, 13.0, 1.0, delta)
	mesh.ankle_l.rotation.x = _spring("ankle_l_x", lead.z, 10.0, 1.0, delta)
	mesh.leg_r.rotation.x = _spring("leg_r_x", trail.x, 11.0, 1.0, delta)
	mesh.knee_r.rotation.x = _spring("knee_r_x", trail.y, 13.0, 1.0, delta)
	mesh.ankle_r.rotation.x = _spring("ankle_r_x", trail.z, 10.0, 1.0, delta)
	mesh.foot_l.rotation.x = _spring("foot_l_x", 0.0, 7.0, 1.0, delta)
	mesh.foot_r.rotation.x = _spring("foot_r_x", 0.0, 7.0, 1.0, delta)

	# ── Thân: bật đổ tới → apex GOM NGƯỜI → rơi mở ra → đáp ôm xuống ──
	var lean: float = 0.20 - rise_p * 0.10 + fall_d * 0.12 + landing * 0.22
	mesh.rig.rotation.x = _spring("rig_x", lean, 8.0, 0.9, delta)
	mesh.rig.position.y = _spring("rig_y", 0.02 + (0.06 if rising else 0.0) - landing * 0.07, 8.0, 1.0, delta)
	mesh.body.rotation.x = _spring("body_x", -0.04 + rise_p * 0.16 + fall_d * 0.08 + landing * 0.24, 8.0, 0.9, delta)
	mesh.pelvis.rotation.x = _spring("pelvis_x", 0.06 + rise_p * 0.08 + fall_d * 0.10 - landing * 0.05, 8.0, 0.9, delta)
	mesh.head.rotation.x = _spring("head_x", -0.10 + landing * 0.14, 7.0, 0.9, delta)
	mesh.neck.rotation.x = _spring("neck_x", 0.05, 6.0, 0.9, delta)
	mesh.backpack.position.z = _spring("bp_z", -0.05 - rise_p * 0.03, 8.0, 1.0, delta)
	mesh.pelvis.position.x = _spring("pelvis_sway", 0.0, 5.0, 0.9, delta)

	# ── Tay: vung ĐỐI BÊN khi bật → ÉP XUỐNG hai hông lúc apex (gom lực) →
	# giơ rộng khi rơi → chống trước khi đáp ──
	var arm_r_t: float = lerpf(lerpf(-1.55, -0.55, rise_p), -1.15, minf(fall_d, 1.0))
	arm_r_t = lerpf(arm_r_t, -0.62, landing)
	var arm_l_t: float = lerpf(lerpf(0.45, -0.50, rise_p), -1.05, minf(fall_d, 1.0))
	arm_l_t = lerpf(arm_l_t, -0.62, landing)
	var spread: float = 0.24 + rise_p * 0.10
	if not _weapon_owns_arms():
		mesh.arm_r.rotation.x = _spring("arm_r_x", arm_r_t, 9.0, 0.9, delta)
		mesh.arm_l.rotation.x = _spring("arm_l_x", arm_l_t, 9.0, 0.9, delta)
		mesh.arm_r.rotation.z = _spring("arm_r_z", -spread - landing * 0.18, 8.0, 0.9, delta)
		mesh.arm_l.rotation.z = _spring("arm_l_z", spread + landing * 0.18, 8.0, 0.9, delta)
		mesh.elbow_r.rotation.x = _spring("elbow_r_x", -0.40 - rise_p * 0.55 - landing * 0.45, 8.0, 0.9, delta)
		mesh.elbow_l.rotation.x = _spring("elbow_l_x", -0.40 - rise_p * 0.55 - landing * 0.45, 8.0, 0.9, delta)

# ── Bơi ────────────────────────────────────────────────────────────────────
## Cơ thể nằm ngang song song mặt nước: tay vươn dài về trước quạt theo hình
## xoáy trôn ốc từ trước ngực ra sau hông, vai xoay liên tục theo nhịp quạt.
## Chân duỗi thẳng, cổ chân duỗi tối đa, Flutter kick đập trên-dưới tạo sóng.
func _swim(delta: float, t: float) -> void:
	var cyc: float = t * swim_cycle_speed
	# Nằm ngang: nghiêng rig gập trước xuống mặt nước ~90°, hơi ngóc theo sóng
	mesh.rig.position.y  = _spring("rig_y", 0.0 + abs(sin(cyc * 0.5)) * 0.02, 7.0, 1.0, delta)
	mesh.rig.rotation.x  = _spring("rig_x", PI * 0.5 + sin(cyc * 0.5) * 0.06, 7.0, 0.9, delta)
	mesh.pelvis.rotation.x = _spring("pelvis_x", 0.0, 6.0, 0.9, delta)
	# Thân nằm ngang rạch nước, lăn nhẹ theo nhịp thở
	mesh.body.rotation.x  = _spring("body_x", 0.0 + sin(cyc * 0.5) * 0.04, 8.0, 0.9, delta)
	mesh.body.rotation.z  = _spring("body_z", sin(cyc * 0.5) * 0.05, 7.0, 0.8, delta)
	mesh.neck.rotation.x   = _spring("neck_x", 0.35, 6.0, 0.9, delta)
	mesh.head.rotation.x   = _spring("head_x", -0.25 + sin(cyc * 0.5) * 0.08, 7.0, 0.9, delta)
	mesh.head.rotation.y   = _spring("head_y", sin(cyc * 0.3) * 0.06, 6.0, 0.8, delta)
	mesh.neck.rotation.y   = _spring("neck_y", sin(cyc * 0.5) * 0.06, 5.0, 0.8, delta)
	mesh.backpack.position.z = _spring("bp_z", -0.02, 5.0, 1.0, delta)
	if not _weapon_owns_arms():
		# Vai quạt xoáy trôn ốc: tay vươn về trước rồi kéo từ trước ngực ra sau
		# hông, vai lăn liên tục theo nhịp quạt (2 bên lệch pha PI).
		var a_l: float = sin(cyc + PI * 0.25)   # vai trái
		var a_r: float = sin(cyc - PI * 0.25)   # vai phải
		mesh.arm_l.rotation.x = _spring("arm_l_x", clamp(a_l * 1.00, -0.85, 0.85), 9.0, 0.9, delta)
		mesh.arm_r.rotation.x = _spring("arm_r_x", clamp(a_r * 1.00, -0.85, 0.85), 9.0, 0.9, delta)
		# Vai xoay lăn theo nhịp quạt (scoop nước)
		mesh.arm_l.rotation.z = _spring("arm_l_z",  a_l * 0.35, 7.0, 0.9, delta)
		mesh.arm_r.rotation.z = _spring("arm_r_z", -a_r * 0.35, 7.0, 0.9, delta)
		# Khuỷu duỗi khi vươn, gập về trước khi kéo nước về sau hông
		mesh.elbow_l.rotation.x = _spring("elbow_l_x", clamp(-a_l * 0.55 - 0.10, -0.95, -0.05), 9.0, 0.9, delta)
		mesh.elbow_r.rotation.x = _spring("elbow_r_x", clamp(-a_r * 0.55 - 0.10, -0.95, -0.05), 9.0, 0.9, delta)
	# Flutter kick: chân duỗi thẳng, cổ chân duỗi tối đa (plantarflex), đập nhanh
	# lên-xuống (phase đối nhau) tạo luồng đẩy & sóng về sau.
	var kick_l: float = sin(cyc * 2.0 + PI * 0.5) * 0.50
	var kick_r: float = sin(cyc * 2.0 - PI * 0.5) * 0.50
	mesh.leg_l.rotation.x   = _spring("leg_l_x",   kick_l, 10.0, 0.9, delta)
	mesh.leg_r.rotation.x   = _spring("leg_r_x",   kick_r, 10.0, 0.9, delta)
	mesh.knee_l.rotation.x  = _spring("knee_l_x", 0.12 + kick_l * 0.12, 10.0, 0.9, delta)
	mesh.knee_r.rotation.x  = _spring("knee_r_x", 0.12 + kick_r * 0.12, 10.0, 0.9, delta)
	mesh.ankle_l.rotation.x = _spring("ankle_l_x", -0.55 + kick_l * 0.25, 9.0, 0.9, delta)
	mesh.ankle_r.rotation.x = _spring("ankle_r_x", -0.55 + kick_r * 0.25, 9.0, 0.9, delta)
	mesh.foot_l.rotation.x  = _spring("foot_l_x", -0.30 + kick_l * 0.20, 8.0, 1.0, delta)
	mesh.foot_r.rotation.x  = _spring("foot_r_x", -0.30 + kick_r * 0.20, 8.0, 1.0, delta)

# ── Ăn / nhai ──────────────────────────────────────────────────────────────
func _eat(delta: float, t: float) -> void:
	var chew: float = abs(sin(t * 9.0))
	mesh.rig.position.y = _spring("rig_y", 0.02, 5.0, 1.0, delta)
	mesh.rig.rotation.x = _spring("rig_x", 0.0, 6.0, 1.0, delta)
	mesh.pelvis.rotation.x = _spring("pelvis_x", 0.20, 6.0, 1.0, delta)
	mesh.pelvis.position.x = _spring("pelvis_sway", 0.0, 6.0, 0.9, delta)
	mesh.body.rotation.x = _spring("body_x", 0.10, 6.0, 0.9, delta)
	# Đầu cúi xuống thức ăn, gật theo nhịp nhai
	mesh.head.rotation.x = _spring("head_x", -0.18 - chew * 0.05, 8.0, 0.9, delta)
	mesh.neck.rotation.x = _spring("neck_x", 0.10, 7.0, 0.9, delta)
	mesh.neck.rotation.y = _spring("neck_y", sin(t * 1.2) * 0.05, 6.0, 0.8, delta)
	mesh.backpack.position.z = _spring("bp_z", -0.02, 5.0, 1.0, delta)
	if not _weapon_owns_arms():
		# Tay phải đưa lên miệng (khuỷu gập mạnh), tay trái bưng bát
		mesh.arm_r.rotation.x = _spring("arm_r_x", -1.15 - chew * 0.10, 9.0, 0.9, delta)
		mesh.arm_r.rotation.z = _spring("arm_r_z", 0.10, 7.0, 0.9, delta)
		mesh.elbow_r.rotation.x = _spring("elbow_r_x", -0.70 - chew * 0.06, 9.0, 0.9, delta)
		mesh.arm_l.rotation.x = _spring("arm_l_x", -0.35 + chew * 0.08, 8.0, 0.9, delta)
		mesh.arm_l.rotation.z = _spring("arm_l_z", 0.25, 7.0, 0.9, delta)
		mesh.elbow_l.rotation.x = _spring("elbow_l_x", -0.55, 8.0, 0.9, delta)
	# Chân thư giãn
	mesh.leg_l.rotation.x = _spring("leg_l_x", 0.02, 6.0, 1.0, delta)
	mesh.leg_r.rotation.x = _spring("leg_r_x", 0.02, 6.0, 1.0, delta)
	mesh.knee_l.rotation.x = _spring("knee_l_x", 0.06, 6.0, 1.0, delta)
	mesh.knee_r.rotation.x = _spring("knee_r_x", 0.06, 6.0, 1.0, delta)
	mesh.ankle_l.rotation.x = _spring("ankle_l_x", -0.04, 6.0, 1.0, delta)
	mesh.ankle_r.rotation.x = _spring("ankle_r_x", -0.04, 6.0, 1.0, delta)
	mesh.foot_l.rotation.x = 0.0
	mesh.foot_r.rotation.x = 0.0

# ── Trúng đòn ──────────────────────────────────────────────────────────────
func _hit(delta: float, _t: float) -> void:
	var p: float = 1.0 - (base._hit_timer / 0.18)
	mesh.rig.position.y = _spring("rig_y", 0.03, 12.0, 1.0, delta)
	mesh.rig.rotation.x = _spring("rig_x", 0.20 - p * 0.14, 13.0, 0.9, delta)
	mesh.body.rotation.x = _spring("body_x", 0.14 - p * 0.08, 12.0, 0.9, delta)
	mesh.pelvis.rotation.x = _spring("pelvis_x", -0.15, 12.0, 1.0, delta)
	mesh.pelvis.position.x = _spring("pelvis_sway", 0.0, 8.0, 0.9, delta)
	mesh.head.rotation.x = _spring("head_x", -0.15 + p * 0.10, 13.0, 0.9, delta)
	mesh.neck.rotation.x = _spring("neck_x", 0.10, 12.0, 0.9, delta)
	# Tay bật về sau, khuỷu cong phản xạ (vũ khí tự pose tay thì nhường)
	if not _weapon_owns_arms():
		mesh.arm_l.rotation.x = _spring("arm_l_x", -0.30, 14.0, 0.9, delta)
		mesh.arm_r.rotation.x = _spring("arm_r_x", -0.30, 14.0, 0.9, delta)
		mesh.arm_l.rotation.z = _spring("arm_l_z", 0.12, 12.0, 0.9, delta)
		mesh.arm_r.rotation.z = _spring("arm_r_z", -0.12, 12.0, 0.9, delta)
		mesh.elbow_l.rotation.x = _spring("elbow_l_x", -0.60, 12.0, 0.9, delta)
		mesh.elbow_r.rotation.x = _spring("elbow_r_x", -0.60, 12.0, 0.9, delta)
	mesh.leg_l.rotation.x = _spring("leg_l_x", -0.08, 11.0, 1.0, delta)
	mesh.leg_r.rotation.x = _spring("leg_r_x", -0.08, 11.0, 1.0, delta)
	mesh.knee_l.rotation.x = _spring("knee_l_x", 0.35, 11.0, 1.0, delta)
	mesh.knee_r.rotation.x = _spring("knee_r_x", 0.35, 11.0, 1.0, delta)
	mesh.ankle_l.rotation.x = _spring("ankle_l_x", 0.05, 10.0, 1.0, delta)
	mesh.ankle_r.rotation.x = _spring("ankle_r_x", 0.05, 10.0, 1.0, delta)
	mesh.foot_l.rotation.x = 0.0
	mesh.foot_r.rotation.x = 0.0

# ── Chết / ngã ─────────────────────────────────────────────────────────────
## 3 pha: Hit Impact (cơ thể giật ngược về sau/sang hông theo hướng đòn) →
## Collapse (khớp thả lỏng, cơ thể gập đôi, đầu gục xuống) →
## Settle (hông & vai đập xuống sàn, nảy nhẹ 1-2 nhịp, chi buông thõng).
func _dead(delta: float, t: float) -> void:
	var prog: float = 1.0 - (base._death_timer / 1.8)
	if prog < 0.18:
		# ── Hit Impact: giật ngược về sau, tay khuỷu cong phản xạ ────────────
		var p: float = prog / 0.18
		mesh.rig.rotation.x = lerp(mesh.rig.rotation.x, -0.55 * sin(p * PI), delta * 18.0)
		mesh.rig.rotation.z = lerp(mesh.rig.rotation.z, 0.12 * sin(p * PI), delta * 16.0)
		mesh.head.rotation.x = lerp(mesh.head.rotation.x, -0.30 * p, delta * 15.0)
		mesh.body.rotation.x = lerp(mesh.body.rotation.x, 0.12 * p, delta * 14.0)
		mesh.knee_l.rotation.x = lerp(mesh.knee_l.rotation.x, -0.30 * p, delta * 14.0)
		mesh.knee_r.rotation.x = lerp(mesh.knee_r.rotation.x, -0.30 * p, delta * 14.0)
		mesh.arm_l.rotation.x = lerp(mesh.arm_l.rotation.x, -0.40 * p, delta * 16.0)
		mesh.arm_r.rotation.x = lerp(mesh.arm_r.rotation.x, -0.40 * p, delta * 16.0)
		mesh.elbow_l.rotation.x = lerp(mesh.elbow_l.rotation.x, -0.30 * p, delta * 15.0)
		mesh.elbow_r.rotation.x = lerp(mesh.elbow_r.rotation.x, -0.30 * p, delta * 15.0)
	elif prog < 0.60:
		# ── Collapse: mất lực — cơ thể gập đôi, đầu gục trước, chi buông ──────
		var p: float = (prog - 0.18) / 0.42
		mesh.rig.rotation.x = lerp(mesh.rig.rotation.x, 0.45 + p * 0.45, delta * 12.0)
		mesh.rig.rotation.z = lerp(mesh.rig.rotation.z, 0.05 + p * 0.06, delta * 10.0)
		mesh.rig.position.y = lerp(mesh.rig.position.y, -p * 0.12, delta * 10.0)
		mesh.body.rotation.x = lerp(mesh.body.rotation.x, 0.18 + p * 0.18, delta * 10.0)
		mesh.head.rotation.x = lerp(mesh.head.rotation.x, -0.55 * p, delta * 11.0)
		mesh.neck.rotation.x = lerp(mesh.neck.rotation.x, 0.25 * p, delta * 10.0)
		mesh.knee_l.rotation.x = lerp(mesh.knee_l.rotation.x, 0.25 + p * 0.15, delta * 10.0)
		mesh.knee_r.rotation.x = lerp(mesh.knee_r.rotation.x, 0.25 + p * 0.15, delta * 10.0)
		mesh.arm_l.rotation.x = lerp(mesh.arm_l.rotation.x, -0.20 - p * 0.20, delta * 10.0)
		mesh.arm_r.rotation.x = lerp(mesh.arm_r.rotation.x, -0.20 - p * 0.20, delta * 10.0)
		mesh.elbow_l.rotation.x = lerp(mesh.elbow_l.rotation.x, -0.55, delta * 9.0)
		mesh.elbow_r.rotation.x = lerp(mesh.elbow_r.rotation.x, -0.55, delta * 9.0)
	else:
		# ── Settle: hông/vai chạm sàn, nảy 1-2 nhịp rồi bất động ───────────────
		var p: float = (prog - 0.60) / 0.40
		mesh.rig.rotation.x = lerp(mesh.rig.rotation.x, 1.35, delta * 8.0)
		mesh.rig.rotation.z = lerp(mesh.rig.rotation.z, 0.12, delta * 7.0)
		# Nảy nhẹ do quán tính — dao động 2 nhịp tắt dần theo p
		var bounce: float = sin(p * TAU * 1.0) * (1.0 - p) * 0.05
		mesh.rig.position.y = lerp(mesh.rig.position.y, -0.14 + bounce, delta * 9.0)
		mesh.body.rotation.x = lerp(mesh.body.rotation.x, 0.30, delta * 7.0)
		mesh.head.rotation.x = lerp(mesh.head.rotation.x, -0.50, delta * 8.0)
		mesh.arm_l.rotation.x = lerp(mesh.arm_l.rotation.x, -0.10, delta * 6.0)
		mesh.arm_r.rotation.x = lerp(mesh.arm_r.rotation.x, -0.10, delta * 6.0)
		# Chi buông thõng chạm đất — khuỷu hơi gập về trước tự nhiên
		mesh.elbow_l.rotation.x = lerp(mesh.elbow_l.rotation.x, -0.25, delta * 6.0)
		mesh.elbow_r.rotation.x = lerp(mesh.elbow_r.rotation.x, -0.25, delta * 6.0)
	mesh.foot_l.rotation.x = 0.0
	mesh.foot_r.rotation.x = 0.0

# ── Khuỷu tay theo đà quét của vai (elastic follow-through) ─────────────────
## Khi vai chuyển (arm.rotation.x chênh khỏi buông thõng), khuỷu tự gập/duỗi
## theo quán tính → cánh tay có độ trễ đàn hồi thay vì cứng đờ.
## Khuỷu người CHỈ gập về trước (rotation.x âm) — dương là gãy ngược xương.
func _elbow_bend_target(arm_angle: float) -> float:
	# Vai đưa ra sau (dương) → khuỷu duỗi; vai đưa tới trước (âm) → gập thêm.
	var bend: float = -0.16 + arm_angle * 0.45
	return clamp(bend, -0.90, -0.04)

func _follow_l_elbow(delta: float) -> void:
	if _weapon_owns_arms():
		return
	mesh.elbow_l.rotation.x = _spring("elbow_l_x", _elbow_bend_target(mesh.arm_l.rotation.x), 9.0, 0.75, delta)

func _follow_r_elbow(delta: float) -> void:
	if _weapon_owns_arms():
		return
	mesh.elbow_r.rotation.x = _spring("elbow_r_x", _elbow_bend_target(mesh.arm_r.rotation.x), 9.0, 0.75, delta)

# ── Tấn công — combo tự động theo chain (MeleeCombos) ────────────────────────
## Mỗi bước combo 3 pha: WINDUP (kéo vũ khí ra sau, co người) → STRIKE (chém
## dứt khoát; VFX + sát thương do physics gọi theo pha hit) → FOLLOW (đà theo).
## Pose định nghĩa bằng bảng "khớp.trục" → giá trị đích (wp tính bằng ĐỘ),
## nội suy mượt vào node bằng lerp với tốc độ khác nhau theo từng pha.
const IDLE_WP := Vector3(90, 0, 0)

# Kiếm thép: ngang P→T, ngược T→P, đâm kết
const _POSE_SWORD := [
	{"w1": 0.34, "w2": 0.58,
		"wind":   {"rig.y": 0.22, "body.x": 0.05, "head.y": 0.18, "arm_r.x": -1.55, "arm_r.z": -0.35, "elbow_r.x": -1.35, "arm_l.x": 0.20, "wp.x": 45.0, "wp.y": 65.0, "wp.z": -75.0},
		"strike": {"rig.y": -0.30, "body.x": 0.14, "head.y": -0.24, "arm_r.x": 0.70, "arm_r.z": 0.40, "elbow_r.x": -0.15, "arm_l.x": -0.35, "wp.x": 150.0, "wp.y": -20.0, "wp.z": 14.0},
		"follow": {"rig.y": -0.16, "body.x": 0.08, "head.y": -0.10, "arm_r.x": 0.35, "arm_r.z": 0.22, "elbow_r.x": -0.40, "arm_l.x": -0.12, "wp.x": 128.0, "wp.y": -8.0, "wp.z": 6.0}},
	{"w1": 0.32, "w2": 0.56,
		"wind":   {"rig.y": -0.22, "body.x": 0.05, "head.y": -0.18, "arm_r.x": -1.55, "arm_r.z": 0.35, "elbow_r.x": -1.35, "arm_l.x": 0.20, "wp.x": 45.0, "wp.y": -65.0, "wp.z": 75.0},
		"strike": {"rig.y": 0.30, "body.x": 0.14, "head.y": 0.24, "arm_r.x": 0.70, "arm_r.z": -0.40, "elbow_r.x": -0.15, "arm_l.x": -0.35, "wp.x": 150.0, "wp.y": 20.0, "wp.z": -14.0},
		"follow": {"rig.y": 0.16, "body.x": 0.08, "head.y": 0.10, "arm_r.x": 0.35, "arm_r.z": -0.22, "elbow_r.x": -0.40, "arm_l.x": -0.12, "wp.x": 128.0, "wp.y": 8.0, "wp.z": -6.0}},
	{"w1": 0.36, "w2": 0.52,
		"wind":   {"rig.y": 0.16, "rig.x": -0.06, "body.x": -0.04, "head.y": 0.12, "arm_r.x": -1.90, "arm_r.z": -0.15, "elbow_r.x": -1.60, "arm_l.x": -0.45, "wp.x": 80.0, "wp.y": 20.0, "wp.z": -10.0},
		"strike": {"rig.y": -0.08, "rig.x": 0.16, "body.x": 0.16, "head.y": -0.06, "arm_r.x": -0.95, "arm_r.z": 0.05, "elbow_r.x": -0.10, "arm_l.x": 0.30, "wp.x": 96.0, "wp.y": 0.0, "wp.z": 0.0},
		"follow": {"rig.x": 0.10, "body.x": 0.10, "arm_r.x": -0.70, "elbow_r.x": -0.50, "wp.x": 92.0, "wp.y": 0.0, "wp.z": 0.0}},
]

# Giáp tay da thú — COMBO VÕ THUẬT:
##  • Thu đòn về HÔNG lấy đà (chamber: vai sau + khuỷu gập kín) — chuẩn võ
##  • Đánh thẳng DUỖI KHUỶU hoàn toàn, thân xoay đấm sâu theo cú
##  • Trình tự: Chưởng trái → Quyền phải → SONG CHƯỜNG ĐẨY ĐÔI → Hồi quyền phủ
## rig.y DƯƠNG = vai trái tiến trước (khớp chân dẫn bước chẵn/lẻ).
const _POSE_GLOVES := [
	{"w1": 0.32, "w2": 0.50,
		"wind":   {"rig.y": -0.36, "body.x": 0.06, "head.y": -0.16,
			"arm_l.x": 0.44, "elbow_l.x": -1.95, "arm_l.z": 0.24,
			"arm_r.x": -0.88, "elbow_r.x": -1.55, "arm_r.z": -0.28},
		"strike": {"rig.y": 0.36, "body.x": 0.16, "head.y": 0.14,
			"arm_l.x": -1.78, "elbow_l.x": -0.02, "arm_l.z": 0.04,
			"arm_r.x": 0.38, "elbow_r.x": -1.85, "arm_r.z": -0.22},
		"follow": {"rig.y": 0.12, "body.x": 0.08,
			"arm_l.x": -0.74, "elbow_l.x": -0.90, "arm_r.x": -0.45, "elbow_r.x": -1.28}},
	{"w1": 0.32, "w2": 0.50,
		"wind":   {"rig.y": 0.36, "body.x": 0.06, "head.y": 0.16,
			"arm_r.x": 0.46, "elbow_r.x": -1.98, "arm_r.z": -0.22,
			"arm_l.x": -0.88, "elbow_l.x": -1.55, "arm_l.z": 0.28},
		"strike": {"rig.y": -0.38, "body.x": 0.18, "head.y": -0.14,
			"arm_r.x": -1.82, "elbow_r.x": -0.02, "arm_r.z": -0.04,
			"arm_l.x": 0.40, "elbow_l.x": -1.88, "arm_l.z": 0.24},
		"follow": {"rig.y": -0.12, "body.x": 0.08,
			"arm_r.x": -0.76, "elbow_r.x": -0.94, "arm_l.x": -0.45, "elbow_l.x": -1.28}},
	{"w1": 0.34, "w2": 0.54,
		"wind":   {"rig.y": 0.10, "body.x": -0.04, "head.y": 0.06,
			"arm_r.x": 0.50, "elbow_r.x": -1.90, "arm_r.z": -0.40,
			"arm_l.x": 0.50, "elbow_l.x": -1.90, "arm_l.z": 0.40},
		"strike": {"rig.y": 0.00, "body.x": 0.24, "head.x": -0.08,
			"arm_r.x": -1.62, "elbow_r.x": -0.04, "arm_r.z": -0.10,
			"arm_l.x": -1.62, "elbow_l.x": -0.04, "arm_l.z": 0.10},
		"follow": {"rig.y": 0.00, "body.x": 0.10,
			"arm_r.x": -0.70, "elbow_r.x": -1.00, "arm_l.x": -0.70, "elbow_l.x": -1.00}},
	{"w1": 0.36, "w2": 0.54,
		"wind":   {"rig.x": 0.24, "body.x": 0.22, "rig.y": 0.30, "head.x": 0.10,
			"arm_r.x": 0.62, "elbow_r.x": -1.92, "arm_r.z": -0.16,
			"arm_l.x": -0.86, "elbow_l.x": -1.58, "arm_l.z": 0.30},
		"strike": {"rig.x": -0.14, "body.x": -0.10, "rig.y": -0.22, "head.x": -0.22,
			"arm_r.x": -2.15, "elbow_r.x": -0.10, "arm_r.z": -0.06,
			"arm_l.x": 0.20, "elbow_l.x": -1.80, "arm_l.z": 0.24},
		"follow": {"rig.x": 0.02, "body.x": 0.02, "rig.y": -0.06,
			"arm_r.x": -0.80, "elbow_r.x": -0.96, "arm_l.x": -0.44, "elbow_l.x": -1.26}},
]

# Đại kiếm — VŨ KHÍ 2 TAY, đòn NẶNG:
##  • Cả hai tay nắm chuôi (arm_l vươn qua thân bám vào cán cùng arm_r)
##  • Windup dài, xoay người sâu (rig.y ±0.5), kéo kiếm vòng ra sau lưng
##  • Strike dứt một nhịp rồi follow quánh, lưỡi kéo lê xuống thấp
##  • rw/rs/rf = tốc độ lerp riêng: chậm khi co, nhanh khi chém, rất chậm khi hồi
const _POSE_GS := [
	{"w1": 0.44, "w2": 0.66, "rw": 8.0, "rs": 22.0, "rf": 6.0,
		"wind":   {"rig.y": 0.46, "rig.x": 0.05, "body.x": 0.12, "head.y": 0.32, "head.x": -0.06,
			"arm_r.x": -2.10, "arm_r.z": -0.55, "elbow_r.x": -0.65,
			"arm_l.x": -1.40, "arm_l.z": 0.50, "elbow_l.x": -0.95,
			"wp.x": 30.0, "wp.y": 85.0, "wp.z": -90.0},
		"strike": {"rig.y": -0.54, "rig.x": 0.16, "body.x": 0.22, "head.y": -0.40, "head.x": 0.08,
			"arm_r.x": 0.80, "arm_r.z": 0.50, "elbow_r.x": -0.08,
			"arm_l.x": -1.00, "arm_l.z": 0.62, "elbow_l.x": -0.35,
			"wp.x": 160.0, "wp.y": -30.0, "wp.z": 22.0},
		"follow": {"rig.y": -0.36, "rig.x": 0.13, "body.x": 0.15, "head.y": -0.24,
			"arm_r.x": 0.45, "arm_r.z": 0.32, "elbow_r.x": -0.28,
			"arm_l.x": -0.72, "arm_l.z": 0.48, "elbow_l.x": -0.58,
			"wp.x": 140.0, "wp.y": -14.0, "wp.z": 10.0}},
	{"w1": 0.46, "w2": 0.68, "rw": 8.0, "rs": 24.0, "rf": 6.0,
		"wind":   {"rig.x": -0.15, "body.x": -0.10, "head.x": -0.32, "rig.y": 0.06,
			"arm_r.x": -2.75, "arm_r.z": -0.10, "elbow_r.x": -0.45,
			"arm_l.x": -2.60, "arm_l.z": 0.18, "elbow_l.x": -0.50,
			"wp.x": 6.0, "wp.y": 0.0, "wp.z": 0.0},
		"strike": {"rig.x": 0.30, "body.x": 0.28, "head.x": 0.16, "rig.y": -0.04,
			"arm_r.x": 0.95, "arm_r.z": 0.05, "elbow_r.x": -0.06,
			"arm_l.x": 0.80, "arm_l.z": 0.32, "elbow_l.x": -0.14,
			"wp.x": 178.0, "wp.y": 0.0, "wp.z": 0.0},
		"follow": {"rig.x": 0.20, "body.x": 0.18, "head.x": 0.07,
			"arm_r.x": 0.62, "elbow_r.x": -0.25,
			"arm_l.x": 0.48, "elbow_l.x": -0.35,
			"wp.x": 162.0, "wp.y": 0.0, "wp.z": 0.0}},
	{"w1": 0.46, "w2": 0.68, "rw": 8.0, "rs": 22.0, "rf": 6.0,
		"wind":   {"rig.y": -0.50, "rig.x": 0.06, "body.x": 0.12, "head.y": -0.36,
			"arm_r.x": -2.00, "arm_r.z": 0.55, "elbow_r.x": -0.55,
			"arm_l.x": -1.60, "arm_l.z": 0.65, "elbow_l.x": -0.75,
			"wp.x": 30.0, "wp.y": -85.0, "wp.z": 90.0},
		"strike": {"rig.y": 0.58, "rig.x": 0.18, "body.x": 0.22, "head.y": 0.42,
			"arm_r.x": 0.75, "arm_r.z": -0.50, "elbow_r.x": -0.08,
			"arm_l.x": -0.88, "arm_l.z": 0.55, "elbow_l.x": -0.30,
			"wp.x": 164.0, "wp.y": 32.0, "wp.z": -24.0},
		"follow": {"rig.y": 0.38, "rig.x": 0.13, "head.y": 0.26,
			"arm_r.x": 0.42, "arm_r.z": -0.30, "elbow_r.x": -0.30,
			"arm_l.x": -0.62, "elbow_l.x": -0.52,
			"wp.x": 142.0, "wp.y": 16.0, "wp.z": -12.0}},
]

# Lưỡi hái — GẶT: hai nhịp quét ngang rộng + xoay người gặt kết (lưỡi liềm)
const _POSE_SCYTHE := [
	{"w1": 0.32, "w2": 0.56,
		"wind":   {"rig.y": -0.44, "rig.x": 0.04, "body.x": 0.08, "head.y": -0.30,
			"arm_r.x": -1.45, "arm_r.z": 0.42, "elbow_r.x": -1.05,
			"arm_l.x": -1.10, "arm_l.z": 0.48, "elbow_l.x": -1.15,
			"wp.x": 38.0, "wp.y": -74.0, "wp.z": 80.0},
		"strike": {"rig.y": 0.52, "rig.x": 0.14, "body.x": 0.16, "head.y": 0.36,
			"arm_r.x": 0.64, "arm_r.z": -0.46, "elbow_r.x": -0.12,
			"arm_l.x": -0.55, "arm_l.z": 0.56, "elbow_l.x": -0.40,
			"wp.x": 158.0, "wp.y": 32.0, "wp.z": -22.0},
		"follow": {"rig.y": 0.32, "body.x": 0.10, "head.y": 0.18,
			"arm_r.x": 0.35, "arm_r.z": -0.28, "elbow_r.x": -0.38,
			"wp.x": 138.0, "wp.y": 14.0, "wp.z": -10.0}},
	{"w1": 0.32, "w2": 0.56,
		"wind":   {"rig.y": 0.46, "rig.x": 0.06, "body.x": 0.08, "head.y": 0.32,
			"arm_r.x": -1.50, "arm_r.z": -0.46, "elbow_r.x": -1.00,
			"arm_l.x": -1.05, "arm_l.z": 0.50, "elbow_l.x": -1.10,
			"wp.x": 38.0, "wp.y": 76.0, "wp.z": -82.0},
		"strike": {"rig.y": -0.54, "rig.x": 0.14, "body.x": 0.16, "head.y": -0.38,
			"arm_r.x": 0.66, "arm_r.z": 0.48, "elbow_r.x": -0.10,
			"arm_l.x": -0.52, "elbow_l.x": -0.42,
			"wp.x": 160.0, "wp.y": -34.0, "wp.z": 24.0},
		"follow": {"rig.y": -0.34, "body.x": 0.10, "head.y": -0.18,
			"arm_r.x": 0.38, "elbow_r.x": -0.36,
			"wp.x": 140.0, "wp.y": -14.0, "wp.z": 10.0}},
	{"w1": 0.36, "w2": 0.60,
		"wind":   {"rig.y": -0.58, "rig.x": 0.10, "body.x": 0.12, "head.y": -0.42,
			"arm_r.x": -1.70, "arm_r.z": 0.50, "elbow_r.x": -0.90,
			"arm_l.x": -1.20, "arm_l.z": 0.55, "elbow_l.x": -1.05,
			"wp.x": 28.0, "wp.y": -88.0, "wp.z": 90.0},
		"strike": {"rig.y": 0.72, "rig.x": 0.20, "body.x": 0.20, "head.y": 0.55,
			"arm_r.x": 0.82, "arm_r.z": -0.54, "elbow_r.x": -0.08,
			"arm_l.x": -0.60, "elbow_l.x": -0.38,
			"wp.x": 166.0, "wp.y": 38.0, "wp.z": -28.0},
		"follow": {"rig.y": 0.44, "rig.x": 0.14, "head.y": 0.26,
			"arm_r.x": 0.45, "elbow_r.x": -0.34,
			"wp.x": 146.0, "wp.y": 18.0, "wp.z": -12.0}},
]

# Halberd: đâm xa, chém trục, quét ngang
const _POSE_HALBERD := [
	{"w1": 0.34, "w2": 0.50,
		"wind":   {"rig.y": 0.18, "body.x": 0.04, "head.y": 0.12, "arm_r.x": -0.85, "elbow_r.x": -1.55, "arm_l.x": -1.05, "elbow_l.x": -1.30, "wp.x": 88.0, "wp.y": 12.0, "wp.z": 0.0},
		"strike": {"rig.y": -0.10, "rig.x": 0.12, "body.x": 0.14, "head.y": -0.06, "arm_r.x": -0.35, "elbow_r.x": -0.06, "arm_l.x": -0.55, "elbow_l.x": -0.35, "wp.x": 92.0, "wp.y": 0.0, "wp.z": 0.0},
		"follow": {"rig.x": 0.06, "arm_r.x": -0.55, "elbow_r.x": -0.60, "wp.x": 90.0, "wp.y": 0.0, "wp.z": 0.0}},
	{"w1": 0.36, "w2": 0.58,
		"wind":   {"rig.x": -0.08, "body.x": -0.04, "arm_r.x": -2.30, "elbow_r.x": -0.70, "arm_l.x": -1.60, "wp.x": 25.0, "wp.y": 0.0, "wp.z": 0.0},
		"strike": {"rig.x": 0.20, "body.x": 0.18, "arm_r.x": 0.90, "elbow_r.x": -0.10, "arm_l.x": 0.50, "wp.x": 165.0, "wp.y": 0.0, "wp.z": 0.0},
		"follow": {"rig.x": 0.10, "arm_r.x": 0.50, "elbow_r.x": -0.40, "wp.x": 140.0, "wp.y": 0.0, "wp.z": 0.0}},
	{"w1": 0.34, "w2": 0.62, "rw": 9.0, "rs": 26.0, "rf": 7.0,
		# ĐÒN CUỐI: rút đà sâu ra sau (kích co hông, tay trái nắm gốc cán)
		# → ĐÂM THẲNG giữ nguyên tư thế xuyên suốt pha LƯỚT → thu về
		"wind":   {"rig.y": 0.42, "rig.x": -0.06, "body.x": -0.04, "head.y": 0.26,
			"arm_r.x": -0.35, "elbow_r.x": -1.75, "arm_l.x": -0.30, "elbow_l.x": -1.85,
			"wp.x": 62.0, "wp.y": 26.0, "wp.z": 14.0},
		"strike": {"rig.y": -0.10, "rig.x": 0.20, "body.x": 0.18, "head.y": -0.04,
			"arm_r.x": -1.05, "elbow_r.x": -0.08, "arm_l.x": -0.92, "elbow_l.x": -0.30,
			"wp.x": 91.0, "wp.y": 0.0, "wp.z": 0.0},
		"follow": {"rig.x": 0.10, "body.x": 0.10,
			"arm_r.x": -0.60, "elbow_r.x": -0.70, "arm_l.x": -0.55, "elbow_l.x": -0.85,
			"wp.x": 90.0, "wp.y": 4.0, "wp.z": 0.0}},
]

# Axe / pickaxe: chop phải, chop trái, chém dọc nặng
const _POSE_HEAVY := [
	{"w1": 0.36, "w2": 0.58,
		"wind":   {"rig.y": 0.20, "body.x": 0.06, "head.y": 0.16, "arm_r.x": -2.20, "arm_r.z": -0.20, "elbow_r.x": -0.80, "arm_l.x": -0.40, "wp.x": 25.0, "wp.y": 30.0, "wp.z": -30.0},
		"strike": {"rig.x": 0.20, "rig.y": -0.14, "body.x": 0.20, "head.y": -0.12, "arm_r.x": 0.90, "arm_r.z": 0.15, "elbow_r.x": -0.10, "wp.x": 160.0, "wp.y": -10.0, "wp.z": 8.0},
		"follow": {"rig.x": 0.10, "arm_r.x": 0.50, "elbow_r.x": -0.40, "wp.x": 140.0, "wp.y": -5.0, "wp.z": 4.0}},
	{"w1": 0.36, "w2": 0.58,
		"wind":   {"rig.y": -0.20, "body.x": 0.06, "head.y": -0.16, "arm_r.x": -2.10, "arm_r.z": 0.30, "elbow_r.x": -0.80, "wp.x": 25.0, "wp.y": -30.0, "wp.z": 30.0},
		"strike": {"rig.x": 0.18, "rig.y": 0.18, "body.x": 0.20, "head.y": 0.14, "arm_r.x": 0.85, "arm_r.z": -0.25, "elbow_r.x": -0.10, "wp.x": 158.0, "wp.y": 12.0, "wp.z": -8.0},
		"follow": {"rig.x": 0.09, "rig.y": 0.08, "arm_r.x": 0.45, "elbow_r.x": -0.40, "wp.x": 138.0, "wp.y": 6.0, "wp.z": -4.0}},
	{"w1": 0.40, "w2": 0.62,
		"wind":   {"rig.x": -0.12, "body.x": -0.06, "arm_r.x": -2.50, "elbow_r.x": -0.60, "arm_l.x": -2.00, "wp.x": 10.0, "wp.y": 0.0, "wp.z": 0.0},
		"strike": {"rig.x": 0.24, "body.x": 0.24, "arm_r.x": 1.00, "elbow_r.x": -0.06, "arm_l.x": 0.70, "wp.x": 170.0, "wp.y": 0.0, "wp.z": 0.0},
		"follow": {"rig.x": 0.12, "arm_r.x": 0.55, "elbow_r.x": -0.35, "wp.x": 148.0, "wp.y": 0.0, "wp.z": 0.0}},
]

# Shovel / hoe: vẩy ngang, đào xuống kết
const _POSE_TOOL := [
	{"w1": 0.34, "w2": 0.56,
		"wind":   {"rig.y": 0.20, "body.x": 0.05, "head.y": 0.16, "arm_r.x": -1.60, "arm_r.z": -0.30, "elbow_r.x": -1.10, "wp.x": 45.0, "wp.y": 50.0, "wp.z": -55.0},
		"strike": {"rig.y": -0.26, "body.x": 0.14, "head.y": -0.18, "arm_r.x": 0.65, "arm_r.z": 0.30, "elbow_r.x": -0.15, "wp.x": 148.0, "wp.y": -15.0, "wp.z": 10.0},
		"follow": {"rig.y": -0.12, "arm_r.x": 0.30, "elbow_r.x": -0.45, "wp.x": 126.0, "wp.y": -6.0, "wp.z": 4.0}},
	{"w1": 0.38, "w2": 0.60,
		"wind":   {"rig.x": -0.10, "body.x": -0.05, "arm_r.x": -2.30, "elbow_r.x": -0.70, "wp.x": 20.0, "wp.y": 0.0, "wp.z": 0.0},
		"strike": {"rig.x": 0.22, "body.x": 0.20, "arm_r.x": 0.90, "elbow_r.x": -0.10, "wp.x": 162.0, "wp.y": 0.0, "wp.z": 0.0},
		"follow": {"rig.x": 0.10, "arm_r.x": 0.50, "elbow_r.x": -0.40, "wp.x": 142.0, "wp.y": 0.0, "wp.z": 0.0}},
]

func _pose_table(wid: String) -> Array:
	match wid:
		"iron_sword": return _POSE_SWORD
		"leather_gloves": return _POSE_GLOVES
		"iron_greatsword": return _POSE_GS
		"iron_halberd": return _POSE_HALBERD
		"iron_scythe": return _POSE_SCYTHE
		"axe", "pickaxe": return _POSE_HEAVY
		"shovel", "hoe": return _POSE_TOOL
	return _POSE_SWORD

## Ghi giá trị đích vào một khớp ("tên.trục") bằng lerp mượt.
## "wp.*" là weapon_pivot và tính bằng rotation_degrees.
func _set_joint(key: String, val: float, delta: float, rate: float) -> void:
	var parts := key.split(".")
	if parts.size() != 2:
		return
	var k: float = minf(1.0, delta * rate)
	if parts[0] == "wp":
		var wp := mesh.weapon_pivot
		if wp == null or not is_instance_valid(wp):
			return
		var deg: Vector3 = wp.rotation_degrees
		match parts[1]:
			"x": deg.x = lerpf(deg.x, val, k)
			"y": deg.y = lerpf(deg.y, val, k)
			"z": deg.z = lerpf(deg.z, val, k)
		wp.rotation_degrees = deg
		return
	var node: Node3D = null
	match parts[0]:
		"rig": node = mesh.rig
		"body": node = mesh.body
		"head": node = mesh.head
		"neck": node = mesh.neck
		"arm_l": node = mesh.arm_l
		"arm_r": node = mesh.arm_r
		"elbow_l": node = mesh.elbow_l
		"elbow_r": node = mesh.elbow_r
	if node == null or not is_instance_valid(node):
		return
	var rot: Vector3 = node.rotation
	match parts[1]:
		"x": rot.x = lerpf(rot.x, val, k)
		"y": rot.y = lerpf(rot.y, val, k)
		"z": rot.z = lerpf(rot.z, val, k)
	node.rotation = rot

## Trộn pose của bước combo hiện tại theo pha prog ∈ [0,1].
## Windup đuổi dáng co vừa phải, strike bắt rất nhanh (snap), follow thả chậm.
## Bước có thể override tốc độ: "rw"/"rs"/"rf" — đại kiếm dùng giá trị chậm
## hơn để đòn có TRỌNG LƯỢNG (co lâu, chém dứt, hồi quánh).
func _combo_blend(step: Dictionary, prog: float, delta: float) -> void:
	var w1: float = step.w1
	var w2: float = step.w2
	var r_wind: float = step.get("rw", 16.0)
	var r_strike: float = step.get("rs", 30.0)
	var r_follow: float = step.get("rf", 11.0)
	var wind: Dictionary = step.wind
	var strike: Dictionary = step.strike
	var follow: Dictionary = step.follow
	for key in wind.keys():
		var target: float
		var rate: float
		if prog < w1:
			target = wind[key]
			rate = r_wind
		elif prog < w2:
			target = strike.get(key, wind[key])
			rate = r_strike
		else:
			target = follow.get(key, strike.get(key, wind[key]))
			rate = r_follow
		_set_joint(key, target, delta, rate)

## Chân khi tấn công — THẾ ĐÁNH CÓ LỰC (đọc là biết đánh):
##  • Windup  : chân DẪN bước mạnh ra trước (hông vung sâu), thân nhấc lấy đà
##  • Strike  : chân trước ĐẬP XUỐNG — gối gập sâu hấp thụ + truyền lực,
##              chân sau duỗi thẳng tắp đạp hông về trước (gót nhấc),
##              TOÀN THÂN LÚN XUỐNG = trọng lực dồn vào đòn
##  • Follow  : giữ thế kiềng thấp ổn định, hồi chậm
## Đổi bên theo bước chẵn/lẻ → mỗi đòn trong chain đánh vào thế chân khác.
func _combo_legs(prog: float, delta: float, step_i: int, step: Dictionary) -> void:
	var lead_is_right := (step_i % 2) == 0
	var w1: float = step.get("w1", 0.35)
	var w2: float = step.get("w2", 0.60)
	# Trọng số 3 pha
	var k_step: float = smoothstep(0.02, w1, prog)                     # bước ra
	var k_drive: float = smoothstep(w1, w2, prog)                      # đập xuống
	var k_settle: float = smoothstep(w2, minf(w2 + 0.22, 1.0), prog)   # giữ thế

	# Key-pose chân DẪN: [hông, gối, cổ chân] — vung TỚI RỘNG, đưa sau VỪA
	var lead_guard := Vector3(0.10, 0.18, 0.05)
	var lead_step := Vector3(-0.98, 0.72, 0.26)    # cẳng chân đưa rộng lên trước
	var lead_drive := Vector3(-0.62, 1.00, 0.06)   # đạp: gối gập SÂU, bàn chân trụ
	var lead_hold := Vector3(-0.68, 0.84, 0.05)
	# Key-pose chân SAU: duỗi đạp nền vừa phải — QUÁ XA sau gây cảm giác lùi
	var trail_guard := Vector3(-0.08, 0.22, 0.05)
	var trail_step := Vector3(0.36, 0.12, 0.12)
	var trail_drive := Vector3(0.56, 0.05, -0.44)  # duỗi + gót nhấc đạp
	var trail_hold := Vector3(0.44, 0.08, -0.28)

	var lead: Vector3
	if k_drive <= 0.0:
		lead = lead_guard.lerp(lead_step, k_step)
	else:
		lead = lead_step.lerp(lead_drive, k_drive).lerp(lead_hold, k_settle)
	var trail: Vector3
	if k_drive <= 0.0:
		trail = trail_guard.lerp(trail_step, k_step)
	else:
		trail = trail_step.lerp(trail_drive, k_drive).lerp(trail_hold, k_settle)

	# Hông lún sâu khi đập = trọng lượng dồn vào đòn; nhấc nhẹ khi bước
	var drop: float = lerpf(lerpf(0.0, 0.025, k_step), -0.095, k_drive)
	drop = lerpf(drop, -0.06, k_settle)

	var leg_lead := mesh.leg_r if lead_is_right else mesh.leg_l
	var leg_trail := mesh.leg_l if lead_is_right else mesh.leg_r
	var an_lead := mesh.ankle_r if lead_is_right else mesh.ankle_l
	var an_trail := mesh.ankle_l if lead_is_right else mesh.ankle_r

	leg_lead.rotation.x = lerpf(leg_lead.rotation.x, lead.x, minf(1.0, delta * 14.0))
	leg_trail.rotation.x = lerpf(leg_trail.rotation.x, trail.x, minf(1.0, delta * 14.0))
	# Giang chân NGANG: chân dẫn hơi khép, chân sau dang ra ngoài — bệ đứng rộng
	var side_f: float = 1.0 if lead_is_right else -1.0
	leg_lead.rotation.z = lerpf(leg_lead.rotation.z, -side_f * 0.06 * k_drive, minf(1.0, delta * 10.0))
	leg_trail.rotation.z = lerpf(leg_trail.rotation.z, side_f * 0.09 * k_drive, minf(1.0, delta * 10.0))
	# Gối dùng spring chung tên với walk → chuyển state không giật pha
	if lead_is_right:
		mesh.knee_r.rotation.x = _spring("knee_r_x", lead.y, 11.0, 1.0, delta)
		mesh.knee_l.rotation.x = _spring("knee_l_x", trail.y, 11.0, 1.0, delta)
	else:
		mesh.knee_l.rotation.x = _spring("knee_l_x", lead.y, 11.0, 1.0, delta)
		mesh.knee_r.rotation.x = _spring("knee_r_x", trail.y, 11.0, 1.0, delta)
	an_lead.rotation.x = lerpf(an_lead.rotation.x, lead.z, minf(1.0, delta * 12.0))
	an_trail.rotation.x = lerpf(an_trail.rotation.x, trail.z, minf(1.0, delta * 12.0))

	mesh.rig.position.y = _spring("rig_y", 0.02 + drop, 10.0, 1.0, delta)
	# Hông xoay đấm theo hướng tấn công + lắc ngang sang chân trụ
	mesh.pelvis.rotation.z = _spring("pelvis_twist", side_f * 0.10 * k_drive, 8.0, 0.8, delta)
	mesh.pelvis.position.x = _spring("pelvis_sway", -side_f * 0.020 * k_drive, 7.0, 0.9, delta)

func _attack(delta: float, _t: float) -> void:
	var remaining: float = base._attack_timer
	var prog: float = 1.0 - clampf(remaining / max(base._cur_step_dur, 0.001), 0.0, 1.0)
	# ── TRỌNG KÍCH phóng thích — pose riêng từng vũ khí ─────────────────────
	if base._is_charged_release:
		var wid_c: String = player.equipped_weapon.id if player != null and player.equipped_weapon != null else ""
		if remaining > _last_remaining + 0.001:
			_start_trail(wid_c)
		_last_remaining = remaining
		if not _trail_released and prog >= 0.40:
			_trail_released = true
			if _trail != null and is_instance_valid(_trail):
				_trail.stop_recording()
			SFXManager.play_attack_strong()
			player.camera_shake(0.10 + 0.10 * base._charge_level, 0.20)
		_charged_blend(prog, delta, wid_c)
		_combo_legs(prog, delta, 0, {"w1": 0.26, "w2": 0.50})
		return
	# ── RIPoste (parry attack): phản đòn sau chặn — vung ngược lên + đâm ────
	if base._is_riposte:
		if remaining > _last_remaining + 0.001:
			_start_trail("iron_sword")
		_last_remaining = remaining
		if not _trail_released and prog >= 0.34:
			_trail_released = true
			if _trail != null and is_instance_valid(_trail):
				_trail.stop_recording()
			SFXManager.play_attack_strong()
		_riposte_blend(prog, delta)
		_combo_legs(prog, delta, 1, {"w1": 0.24, "w2": 0.46})
		return
	var step_i: int = player.combo_step if player != null else 0
	var wid: String = player.equipped_weapon.id if player != null and player.equipped_weapon != null else ""
	var table: Array = _pose_table(wid)
	step_i = clampi(step_i, 0, table.size() - 1)
	# Bước mới bắt đầu (timer nhảy lên) → mở vệt kiếm mới cho đường vung này
	if remaining > _last_remaining + 0.001:
		_start_trail(wid)
	_last_remaining = remaining
	var step: Dictionary = table[step_i]
	# Đúng thời điểm lưỡi quét (w2): khoá trail + âm vung + impact đấm
	if not _trail_released and prog >= float(step.w2):
		_trail_released = true
		if _trail != null and is_instance_valid(_trail):
			_trail.stop_recording()
		if wid == "iron_greatsword" or wid == "axe" or wid == "pickaxe" \
				or wid == "iron_halberd" or wid == "iron_scythe":
			SFXManager.play_attack_strong()
	else:
		SFXManager.play_attack_weak()
		if wid == "leather_gloves":
			_spawn_punch_fx(step_i)
	_combo_blend(step, prog, delta)
	_combo_legs(prog, delta, step_i, step)

# ── Sword trail — vệt lưỡi theo đúng đường vung thật ──────────────────────────
var _trail: _TrailVFX = null
var _trail_released: bool = true

## Mở vệt kiếm cho một bước đánh: gắn vào weapon_pivot, tự mẫu transform lưỡi.
func _start_trail(wid: String) -> void:
	_kill_trail()
	_trail_released = false
	if mesh == null or mesh.weapon_pivot == null or not is_instance_valid(mesh.weapon_pivot):
		return
	var tip_y := 0.60
	var life := 0.22
	var col := Color(0.95, 0.97, 1.0)
	match wid:
		"iron_sword":
			tip_y = 0.58; life = 0.22; col = Color(0.95, 0.97, 1.00)
		"iron_greatsword":
			tip_y = 1.05; life = 0.34; col = Color(0.80, 0.88, 1.00)
		"iron_halberd":
			tip_y = 0.82; life = 0.30; col = Color(0.65, 0.75, 0.85)
		"iron_scythe":
			tip_y = 0.92; life = 0.34; col = Color(0.72, 0.70, 0.95)   # tím nhạt tử thần
		"axe":
			tip_y = 0.44; life = 0.26; col = Color(1.00, 0.98, 0.92)
		"pickaxe":
			tip_y = 0.42; life = 0.26; col = Color(0.90, 0.94, 1.00)
		"shovel", "hoe":
			tip_y = 0.46; life = 0.22; col = Color(0.95, 0.92, 0.80)
		"air":
			tip_y = 0.70; life = 0.30; col = Color(0.88, 0.94, 1.00)
		_:
			return   # găng tay không có vệt kiếm (dùng PunchVFX)
	_trail = _TrailVFX.new()
	mesh.weapon_pivot.add_child(_trail)
	_trail.setup(col, tip_y, life)

func _kill_trail() -> void:
	if _trail != null and is_instance_valid(_trail):
		_trail.queue_free()
	_trail = null

## Impact đấm tại nắm tay đang đánh (bước chẵn tay trái, lẻ tay phải).
# ── PARRY: thế chặn — kiếm dựng chéo chắn ngực, chân trụ vững, người vặn che ─
func _parry(delta: float, _t: float) -> void:
	mesh.rig.position.y = _spring("rig_y", -0.02, 9.0, 1.0, delta)
	mesh.rig.rotation.x = _spring("rig_x", 0.06, 9.0, 0.9, delta)
	mesh.rig.rotation.y = _spring("rig_rot_y", 0.20, 10.0, 0.9, delta)
	mesh.body.rotation.x = _spring("body_x", 0.08, 8.0, 0.9, delta)
	mesh.head.rotation.x = _spring("head_x", -0.04, 7.0, 0.9, delta)
	mesh.head.rotation.y = _spring("head_y", 0.10, 7.0, 0.8, delta)
	if not _weapon_owns_arms():
		var wp := mesh.weapon_pivot
		if wp != null and is_instance_valid(wp):
			# Kiếm dựng CHÉO chắn trước thân
			wp.rotation_degrees = wp.rotation_degrees.lerp(Vector3(18, -46, -12), minf(1.0, delta * 13.0))
		# KHIÊN (nếu đeo): xoay mặt khiên ra TRƯỚC che thân khi đỡ
		if player != null and player.equipped_sub != null \
				and player.equipped_sub.id == "iron_shield" \
				and mesh.shield_pivot != null and is_instance_valid(mesh.shield_pivot):
			mesh.shield_pivot.rotation_degrees = mesh.shield_pivot.rotation_degrees.lerp(
				Vector3(0, 0, 0), minf(1.0, delta * 11.0))
		mesh.arm_r.rotation.x = _spring("arm_r_x", -1.05, 11.0, 0.9, delta)
		mesh.arm_r.rotation.z = _spring("arm_r_z", -0.30, 10.0, 0.9, delta)
		mesh.elbow_r.rotation.x = _spring("elbow_r_x", -1.15, 10.0, 0.9, delta)
		mesh.arm_l.rotation.x = _spring("arm_l_x", -0.95, 11.0, 0.9, delta)
		mesh.arm_l.rotation.z = _spring("arm_l_z", 0.34, 10.0, 0.9, delta)
		mesh.elbow_l.rotation.x = _spring("elbow_l_x", -1.25, 10.0, 0.9, delta)
	mesh.leg_l.rotation.x = _spring("leg_l_x", -0.36, 10.0, 1.0, delta)
	mesh.knee_l.rotation.x = _spring("knee_l_x", 0.42, 10.0, 1.0, delta)
	mesh.leg_r.rotation.x = _spring("leg_r_x", 0.24, 10.0, 1.0, delta)
	mesh.knee_r.rotation.x = _spring("knee_r_x", 0.34, 10.0, 1.0, delta)
	mesh.pelvis.position.x = _spring("pelvis_sway", -0.018, 7.0, 0.9, delta)
	mesh.pelvis.rotation.x = _spring("pelvis_x", 0.04, 7.0, 1.0, delta)

## RIPoste blend: sau chặn vung NGƯỢC từ dưới-hông lên chéo rồi đâm tới —
## vào thế cực nhanh (rate 22), chém dứt khoát, thu gọn.
func _riposte_blend(prog: float, delta: float) -> void:
	var w1 := 0.22
	var w2 := 0.44
	var wind := {
		"rig.y": 0.30, "rig.x": 0.02, "body.x": 0.04, "head.y": 0.20,
		"arm_r.x": 0.55, "elbow_r.x": -1.90, "arm_l.x": -0.70, "elbow_l.x": -1.35,
		"wp.x": 55.0, "wp.y": 40.0, "wp.z": 40.0}
	var strike := {
		"rig.y": -0.26, "rig.x": 0.16, "body.x": 0.14, "head.y": -0.12,
		"arm_r.x": -1.28, "elbow_r.x": -0.05, "arm_l.x": -0.98, "elbow_l.x": -0.42,
		"wp.x": 92.0, "wp.y": 0.0, "wp.z": 0.0}
	var follow := {
		"rig.y": -0.12, "rig.x": 0.10, "body.x": 0.08,
		"arm_r.x": -0.85, "elbow_r.x": -0.45, "arm_l.x": -0.62, "elbow_l.x": -0.80,
		"wp.x": 88.0, "wp.y": 4.0, "wp.z": 0.0}
	for key in wind.keys():
		var target: float
		var rate: float
		if prog < w1:
			target = wind[key]
			rate = 22.0
		elif prog < w2:
			target = strike.get(key, wind[key])
			rate = 32.0
		else:
			target = follow.get(key, strike.get(key, wind[key]))
			rate = 10.0
		_set_joint(key, target, delta, rate)

# ── VẬN LỰC (giữ chuột trái) — kéo vũ khí về sau, rung nhẹ khi đầy lực ───────
func _charge_pose(delta: float) -> void:
	var lvl: float = base._charge_level
	var tremble: float = sin(base._time * 42.0) * 0.018 * lvl
	var wid: String = player.equipped_weapon.id if player != null and player.equipped_weapon != null else ""
	# Pose gồng riêng vũ khí: [vai, khuỷu, wp.x] kéo về sau tối đa
	var pull := Vector3(0.62, -1.98, 30.0)
	match wid:
		"iron_greatsword", "iron_halberd":
			pull = Vector3(0.85, -2.10, 16.0)
		"leather_gloves":
			pull = Vector3(0.55, -2.05, 90.0)
	mesh.rig.rotation.x = _spring("rig_x", -0.10 * lvl, 9.0, 0.9, delta)
	mesh.rig.rotation.y = _spring("rig_rot_y", 0.34 * lvl + tremble, 9.0, 0.9, delta)
	mesh.body.rotation.x = _spring("body_x", 0.10 * lvl, 8.0, 0.9, delta)
	if not _weapon_owns_arms():
		var wp := mesh.weapon_pivot
		if wp != null and is_instance_valid(wp):
			wp.rotation_degrees = wp.rotation_degrees.lerp(
				Vector3(pull.z, 26.0 * lvl, -20.0 * lvl), minf(1.0, delta * 10.0))
		mesh.arm_r.rotation.x = _spring("arm_r_x", pull.x, 12.0, 0.95, delta)
		mesh.elbow_r.rotation.x = _spring("elbow_r_x", pull.y, 12.0, 0.95, delta)
		mesh.arm_l.rotation.x = _spring("arm_l_x", -0.72 * lvl - 0.15, 11.0, 0.95, delta)
		mesh.arm_l.rotation.z = _spring("arm_l_z", 0.36 * lvl, 11.0, 0.95, delta)
	# Chân trụ thấp dần theo mức vận — trọng lượng dồn xuống
	var drop: float = 0.06 * lvl
	mesh.leg_l.rotation.x = _spring("leg_l_x", -0.30 * lvl, 9.0, 1.0, delta)
	mesh.knee_l.rotation.x = _spring("knee_l_x", 0.40 * lvl + 0.08, 9.0, 1.0, delta)
	mesh.leg_r.rotation.x = _spring("leg_r_x", 0.24 * lvl, 9.0, 1.0, delta)
	mesh.knee_r.rotation.x = _spring("knee_r_x", 0.34 * lvl + 0.08, 9.0, 1.0, delta)
	mesh.rig.position.y = _spring("rig_y", 0.02 - drop, 9.0, 1.0, delta)

## ── TRỌNG KÍCH phóng thích — bảng pose RIÊNG từng vũ khí ──────────────────────
func _charged_blend(prog: float, delta: float, wid: String) -> void:
	var table: Dictionary
	match wid:
		"iron_sword":
			table = {"w1": 0.22, "w2": 0.52,
				"wind":   {"rig.y": -0.60, "rig.x": 0.04},
				"strike": {"rig.y": 1.35, "rig.x": 0.14, "body.x": 0.16,
					"arm_r.x": -0.45, "elbow_r.x": -0.10, "wp.x": 150.0, "wp.y": 0.0, "wp.z": 8.0},
				"follow": {"rig.y": 1.05, "arm_r.x": -0.70, "elbow_r.x": -0.35}}
		"leather_gloves":
			table = {"w1": 0.20, "w2": 0.46,
				"wind":   {"rig.x": 0.28, "body.x": 0.24},
				"strike": {"rig.x": -0.18, "body.x": -0.10, "head.x": -0.24,
					"arm_r.x": -2.25, "elbow_r.x": -0.06, "arm_l.x": -2.10, "elbow_l.x": -0.10},
				"follow": {"rig.x": -0.02, "arm_r.x": -1.30, "elbow_r.x": -0.50}}
		"iron_greatsword":
			table = {"w1": 0.30, "w2": 0.58,
				"wind":   {"rig.x": -0.18, "body.x": -0.10, "rig.y": 0.10},
				"strike": {"rig.x": 0.40, "body.x": 0.32, "head.x": 0.18,
					"arm_r.x": -2.85, "arm_l.x": -2.70, "elbow_r.x": -0.06, "elbow_l.x": -0.08,
					"wp.x": 182.0, "wp.y": 0.0, "wp.z": 0.0},
				"follow": {"rig.x": 0.26, "arm_r.x": 0.80, "wp.x": 168.0}}
		"iron_halberd":
			table = {"w1": 0.24, "w2": 0.54,
				"wind":   {"rig.y": -0.70, "rig.x": 0.06},
				"strike": {"rig.y": 0.90, "rig.x": 0.18, "body.x": 0.18,
					"arm_r.x": -0.75, "elbow_r.x": -0.10, "arm_l.x": -0.65, "elbow_l.x": -0.30,
					"wp.x": 96.0, "wp.y": 0.0, "wp.z": 0.0},
				"follow": {"rig.y": 0.55, "arm_r.x": -0.55}}
		"iron_scythe":
			# LIỀM CHẾT: xoay tròn gặt quanh thân (vòng ~200°) rồi vung kết lên
			table = {"w1": 0.20, "w2": 0.62,
				"wind":   {"rig.y": -1.10, "rig.x": 0.10, "body.x": 0.12,
					"arm_r.x": -1.60, "elbow_r.x": -0.70, "arm_l.x": -1.30,
					"wp.x": 40.0, "wp.y": -80.0, "wp.z": 84.0},
				"strike": {"rig.y": 2.20, "rig.x": 0.16, "body.x": 0.18, "head.y": 0.60,
					"arm_r.x": 0.85, "elbow_r.x": -0.08,
					"wp.x": 168.0, "wp.y": 34.0, "wp.z": -24.0},
				"follow": {"rig.y": 1.40, "rig.x": -0.10, "head.x": -0.16,
					"arm_r.x": -1.90, "elbow_r.x": -0.30,
					"wp.x": 30.0, "wp.y": 0.0, "wp.z": 0.0}}
		"axe":
			table = {"w1": 0.28, "w2": 0.56,
				"wind":   {"rig.x": -0.20, "rig.y": -0.30},
				"strike": {"rig.x": 0.38, "rig.y": 0.30, "body.x": 0.28,
					"arm_r.x": -2.90, "elbow_r.x": -0.06, "wp.x": 178.0, "wp.y": 0.0, "wp.z": 0.0},
				"follow": {"rig.x": 0.24, "arm_r.x": 0.70, "wp.x": 160.0}}
		"pickaxe":
			table = {"w1": 0.26, "w2": 0.54,
				"wind":   {"rig.x": -0.16, "rig.y": 0.34},
				"strike": {"rig.x": 0.34, "rig.y": -0.36, "body.x": 0.26,
					"arm_r.x": 1.00, "elbow_r.x": -0.08, "wp.x": 172.0, "wp.y": -14.0, "wp.z": -10.0},
				"follow": {"rig.x": 0.22, "arm_r.x": 0.62, "wp.x": 154.0}}
		_:
			table = {"w1": 0.26, "w2": 0.54,
				"wind":   {"rig.y": -0.44, "rig.x": 0.04},
				"strike": {"rig.y": 0.52, "rig.x": 0.30, "body.x": 0.24,
					"arm_r.x": -2.70, "elbow_r.x": -0.08, "wp.x": 170.0, "wp.y": 0.0, "wp.z": 0.0},
				"follow": {"rig.x": 0.20, "arm_r.x": 0.60, "wp.x": 156.0}}
	var w1: float = table.w1
	var w2: float = table.w2
	var wind: Dictionary = table.get("wind", {})
	var strike: Dictionary = table.strike
	var follow: Dictionary = table.follow
	for key in wind.keys():
		var target: float
		var rate: float
		if prog < w1:
			target = wind[key]
			rate = 20.0
		elif prog < w2:
			target = strike.get(key, wind[key])
			rate = 30.0
		else:
			target = follow.get(key, strike.get(key, wind[key]))
			rate = 9.0
		_set_joint(key, target, delta, rate)

func _spawn_punch_fx(step_i: int) -> void:
	var anchor: Node3D = mesh.elbow_r if (step_i % 2) == 1 else mesh.elbow_l
	if anchor == null or not is_instance_valid(anchor):
		return
	var pv := PunchVFX.new(1.0 + 0.15 * step_i, Color(0.85, 0.72, 0.40))
	anchor.add_child(pv)
	pv.position = Vector3(0, -0.24, 0.06)

# ── Hạ thủ sau chain (RECOVERY) ────────────────────────────────────────────────
## Vũ khí về thế thủ thấp hơi nâng (sẵn sàng), thân thẳng lại, hít một nhịp.
func _recovery(delta: float, _t: float) -> void:
	mesh.rig.rotation.x = _spring("rig_x", 0.04, 7.0, 0.9, delta)
	mesh.rig.rotation.y = _spring("rig_rot_y", 0.0, 7.0, 0.9, delta)
	mesh.body.rotation.x = _spring("body_x", 0.05, 7.0, 0.9, delta)
	mesh.head.rotation.x = _spring("head_x", -0.03, 7.0, 0.9, delta)
	mesh.head.rotation.y = _spring("head_y", 0.0, 6.0, 0.8, delta)
	if not _weapon_owns_arms():
		var wp := mesh.weapon_pivot
		if wp != null and is_instance_valid(wp):
			wp.rotation_degrees = wp.rotation_degrees.lerp(IDLE_WP, minf(1.0, delta * 9.0))
		mesh.arm_r.rotation.x = _spring("arm_r_x", -0.35, 8.0, 0.9, delta)
		mesh.arm_r.rotation.z = _spring("arm_r_z", -0.10, 8.0, 0.9, delta)
		mesh.elbow_r.rotation.x = _spring("elbow_r_x", -0.85, 8.0, 0.8, delta)
		mesh.arm_l.rotation.x = _spring("arm_l_x", -0.30, 8.0, 0.9, delta)
		mesh.arm_l.rotation.z = _spring("arm_l_z", 0.12, 8.0, 0.9, delta)
		mesh.elbow_l.rotation.x = _spring("elbow_l_x", -0.80, 8.0, 0.8, delta)
	mesh.leg_l.rotation.x = _spring("leg_l_x", 0.05, 8.0, 1.0, delta)
	mesh.leg_r.rotation.x = _spring("leg_r_x", -0.05, 8.0, 1.0, delta)
	mesh.knee_l.rotation.x = _spring("knee_l_x", 0.12, 8.0, 1.0, delta)
	mesh.knee_r.rotation.x = _spring("knee_r_x", 0.12, 8.0, 1.0, delta)
	mesh.pelvis.position.x = _spring("pelvis_sway", 0.0, 6.0, 0.9, delta)
	# Neutralize toàn bộ khớp nghiêng + chân sau chain → không dư nghiêng sang idle.
	mesh.pelvis.rotation.x = _spring("pelvis_x", 0.0, 6.0, 1.0, delta)
	mesh.pelvis.position.z = _spring("pelvis_z", 0.0, 6.0, 0.9, delta)
	mesh.rig.rotation.z = _spring("rig_z", 0.0, 7.0, 1.0, delta)
	mesh.body.rotation.z = _spring("body_z", 0.0, 7.0, 1.0, delta)
	mesh.backpack.rotation.x = _spring("bp_rx", 0.0, 6.0, 1.0, delta)
	mesh.neck.rotation.y = _spring("neck_y", 0.0, 6.0, 0.8, delta)
	mesh.ankle_l.rotation.x = _spring("ankle_l_x", 0.03, 8.0, 1.0, delta)
	mesh.ankle_r.rotation.x = _spring("ankle_r_x", 0.03, 8.0, 1.0, delta)
	mesh.foot_l.rotation.x = _spring("foot_l_x", 0.0, 8.0, 1.0, delta)
	mesh.foot_r.rotation.x = _spring("foot_r_x", 0.0, 8.0, 1.0, delta)

# ── Đòn đánh trên không (AIR_ATTACK → LANDING) ────────────────────────────────
## Co người giữa không trung, chém chéo từ trên vai phải xuống trái hông;
## tiếp đất do physics chuyển sang RECOVERY dài hơn (hấp thụ cú đáp).
func _air_attack(delta: float, _t: float) -> void:
	var remaining: float = base._attack_timer
	var prog: float = 1.0 - clampf(remaining / max(base._cur_step_dur, 0.001), 0.0, 1.0)
	if remaining > _last_remaining + 0.001:
		_start_trail("air")
	_last_remaining = remaining
	if not _trail_released and prog >= 0.62:
		_trail_released = true
		if _trail != null and is_instance_valid(_trail):
			_trail.stop_recording()
		SFXManager.play_attack_weak()
	var strike_k: float = smoothstep(0.28, 0.62, prog)
	mesh.rig.rotation.x = _spring("rig_x", 0.10 + prog * 0.14, 9.0, 0.9, delta)
	mesh.rig.rotation.y = _spring("rig_rot_y", lerpf(0.24, -0.26, strike_k), 9.0, 0.9, delta)
	mesh.body.rotation.x = _spring("body_x", 0.10 + prog * 0.10, 8.0, 0.9, delta)
	mesh.head.rotation.x = _spring("head_x", -0.10, 7.0, 0.9, delta)
	if not _weapon_owns_arms():
		mesh.arm_r.rotation.x = _spring("arm_r_x", lerpf(-2.35, 0.85, strike_k), 13.0, 1.0, delta)
		mesh.arm_r.rotation.z = _spring("arm_r_z", lerpf(-0.30, 0.30, strike_k), 11.0, 1.0, delta)
		mesh.elbow_r.rotation.x = _spring("elbow_r_x", lerpf(-0.90, -0.08, strike_k), 12.0, 1.0, delta)
		mesh.arm_l.rotation.x = _spring("arm_l_x", -0.55, 9.0, 0.9, delta)
		mesh.arm_l.rotation.z = _spring("arm_l_z", 0.25, 9.0, 0.9, delta)
		mesh.elbow_l.rotation.x = _spring("elbow_l_x", -1.10, 9.0, 0.9, delta)
	# Chân co trước mặt (tuck) — dáng đấm bay
	mesh.leg_l.rotation.x = _spring("leg_l_x", -0.55, 9.0, 1.0, delta)
	mesh.leg_r.rotation.x = _spring("leg_r_x", -0.20, 9.0, 1.0, delta)
	mesh.knee_l.rotation.x = _spring("knee_l_x", 1.05, 9.0, 1.0, delta)
	mesh.knee_r.rotation.x = _spring("knee_r_x", 0.65, 9.0, 1.0, delta)
	mesh.ankle_l.rotation.x = _spring("ankle_l_x", 0.20, 8.0, 1.0, delta)
	mesh.ankle_r.rotation.x = _spring("ankle_r_x", 0.10, 8.0, 1.0, delta)
	mesh.pelvis.position.x = _spring("pelvis_sway", 0.0, 6.0, 0.9, delta)
