class_name PlayerAnimator

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
var _slash_spawned: bool = false
var _last_remaining: float = 0.0

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
	return player != null and player.equipped_weapon != null \
		and _ARMS_OWNED_WEAPONS.has(player.equipped_weapon.id)

func setup(m: PlayerMesh, b: CharacterBase) -> void:
	mesh = m
	base = b
	player = b as PlayerCharacter

func animate(delta: float) -> void:
	var t: float = base._time
	match base._state:
		CharacterBase.State.IDLE:
			_idle(delta, t)
		CharacterBase.State.WALK:
			_walk(delta, t, 1.0)
		CharacterBase.State.SPRINT:
			_sprint(delta, t)
		CharacterBase.State.CROUCH:
			_crouch(delta, t)
		CharacterBase.State.DASH:
			_dash(delta, t)
		CharacterBase.State.ATTACK:
			_attack(delta, t)
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
	if s == CharacterBase.State.SWIM or s == CharacterBase.State.JUMP or s == CharacterBase.State.FALL or s == CharacterBase.State.DEAD or s == CharacterBase.State.SPRINT or s == CharacterBase.State.CROUCH:
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
	mesh.pelvis.rotation.z = _spring("pelvis_twist", shift * 0.06, 2.0, 0.8, delta)
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

# ── Đi bộ / chạy — chân dẫn bởi phase, tay chéo chân đối diện ─────────────────
func _walk(delta: float, t: float, mult: float) -> void:
	var cyc: float = t * walk_cycle_speed * mult
	# Tăng tốc: biên độ hông to, tay vung rộng, gót không chạm đất.
	var amp: float     = 0.40 + mult * 0.20       # biên độ hông
	var knee_amp: float = 0.55 + mult * 0.20       # gập gối khi vung
	var toe_off: float = 0.25 + mult * 0.08        # duỗi mũi chân khi đạp
	var arm_amp: float  = 0.35 + mult * 0.12       # biên độ vung tay
	# Chân trái/phải chênh PI: sin<0 vung tới (nhấc), sin>0 đỡ sau.
	var ph_l: float = cyc
	var ph_r: float = cyc + PI
	var s_l: float = sin(ph_l)
	var s_r: float = sin(ph_r)
	# Hông (đùi): mang chân theo chu kỳ bước vuông góc với thân khi chạy
	var hip_l: float = s_l * amp
	var hip_r: float = s_r * amp
	# Gối: gập mạnh khi chân vung tới (nhấc bàn), duỗi thẳng khi đỡ sau
	var knee_l: float = knee_amp * max(0.0, -s_l)
	var knee_r: float = knee_amp * max(0.0, -s_r)
	# Cổ chân: duỗi mũi khi đạp cuối (toe-off), gập mũi lên khi hớt
	var flick_l: float = -toe_off * pow(max(0.0, s_l), 3.0)
	var flick_r: float = -toe_off * pow(max(0.0, s_r), 3.0)
	var dors_l: float = 0.30 * max(0.0, -s_l)
	var dors_r: float = 0.30 * max(0.0, -s_r)
	var ankle_l: float = flick_l + dors_l
	var ankle_r: float = flick_r + dors_r

	mesh.leg_l.rotation.x   = _spring("leg_l_x",   hip_l,  9.0 + mult, 1.0, delta)
	mesh.leg_r.rotation.x   = _spring("leg_r_x",   hip_r,  9.0 + mult, 1.0, delta)
	mesh.knee_l.rotation.x  = _spring("knee_l_x",  knee_l,  9.0 + mult, 1.0, delta)
	mesh.knee_r.rotation.x  = _spring("knee_r_x",  knee_r,  9.0 + mult, 1.0, delta)
	mesh.ankle_l.rotation.x = _spring("ankle_l_x", ankle_l, 9.0 + mult, 1.0, delta)
	mesh.ankle_r.rotation.x = _spring("ankle_r_x", ankle_r, 9.0 + mult, 1.0, delta)
	# Chân hỗ trợ (stance) giữ mũi chân phẳng; chân hớt (swing) gãy mũi lên
	# để không vấp. Trưởng hợp stance ankle<0 → foot level, không lún xuống đất.
	mesh.foot_l.rotation.x = _spring("foot_l_x", max(0.0, -ankle_l) * 0.30, 8.0, 1.0, delta)
	mesh.foot_r.rotation.x = _spring("foot_r_x", max(0.0, -ankle_r) * 0.30, 8.0, 1.0, delta)

	# Nhún theo nhịp: chạm đất ≈ khi chân thẳng (sin gần 0)
	var bob: float = abs(sin(cyc)) * (0.04 + mult * 0.02)
	mesh.rig.position.y = _spring("rig_y", 0.02 + bob, 6.0, 1.0, delta)
	mesh.rig.rotation.x = _spring("rig_x", -0.05 * mult, 6.0, 0.9, delta)
	mesh.pelvis.rotation.z = _spring("pelvis_twist", sin(cyc) * (0.04 + mult * 0.03), 6.0, 0.8, delta)
	mesh.pelvis.position.z = _spring("pelvis_z", sin(cyc * 0.5) * 0.03, 5.0, 0.9, delta)
	# Thân ngả nhẹ theo chu kỳ, đầu lắc ngược nhẹ
	mesh.body.rotation.x = _spring("body_x", -sin(cyc * 0.5) * (0.04 + mult * 0.02), 5.0, 0.9, delta)
	mesh.neck.rotation.y = _spring("neck_y", sin(cyc * 0.5) * 0.10 * mult, 5.0, 0.8, delta)
	mesh.head.rotation.z = _spring("head_z", sin(cyc * 0.5) * (0.05 + mult * 0.02), 5.0, 0.8, delta)
	mesh.head.rotation.x = _spring("head_x", -0.04 * mult, 5.0, 0.9, delta)
	mesh.neck.rotation.x = _spring("neck_x", -sin(cyc * 0.5) * 0.02 * mult, 5.0, 0.9, delta)
	mesh.backpack.position.z = _spring("bp_z", -0.02 + abs(sin(cyc * 0.5)) * 0.02, 6.0, 0.9, delta)
	mesh.backpack.rotation.x = _spring("bp_rx", sin(cyc * 0.5) * 0.05, 6.0, 0.9, delta)

	# Tay chéo chân ĐỐI DIỆN: khi chân L về trước (hip_l>0) tay L về sau.
	# → tay L = -hip_l (đối diện chân L). Trước đây arm_l=-hip_r=+hip_l sai.
	if not _weapon_owns_arms():
		mesh.arm_l.rotation.x = _spring("arm_l_x", -0.60 + hip_l * 0.20, 9.0, 1.0, delta)
		mesh.arm_r.rotation.x = _spring("arm_r_x", -0.60 + hip_r * 0.20, 9.0, 1.0, delta)
		mesh.arm_l.rotation.z = _spring("arm_l_z", 0.06, 7.0, 1.0, delta)
		mesh.arm_r.rotation.z = _spring("arm_r_z", -0.06, 7.0, 1.0, delta)
		_follow_l_elbow(delta)
		_follow_r_elbow(delta)

# ── Sprint (chạy nhanh / bứt tốc) ──────────────────────────────────────────
## Thân đổ gập 15-20° phía trước dùng trọng lực; cột sống xoay nhẹ theo nhịp
## vung tay. Tay vung rộng từ ngang hông vọt lên ngang cằm, khuỷu khóa ~90°,
## vai rung theo tần số chân. Đùi nâng cao, chân sau duỗi thẳng (hip extension)
## đạp nền, tiếp đất bằng mũi/nửa trước bàn chân (gót không chạm đất).
func _sprint(delta: float, t: float) -> void:
	var cyc: float = t * walk_cycle_speed * sprint_cycle_mult
	# Pha chân — đối xứng chân trái/phải
	var ph_l: float = cyc
	var ph_r: float = cyc + PI
	var s_l: float = sin(ph_l)
	var s_r: float = sin(ph_r)
	# Đùi nâng cao (gấp ~70-90°) khi hớt, duỗi thẳng phía sau khi đạp → hip extension
	var hip_l: float = s_l * 1.05
	var hip_r: float = s_r * 1.05
	# Gối: gập mạnh khi hớt (sin<0), duỗi thẳng khi đạp — latex mạnh hơn WALK
	var knee_l: float = 1.15 * max(0.0, -s_l) + 0.10
	var knee_r: float = 1.15 * max(0.0, -s_r) + 0.10
	# Cổ chân: duỗi mũi (plantarflex) lúc đạp để đẩy bằng mũi, gãy nhẹ khi hớt.
	# Sprint: gót không chạm — ankle duỗi mũi mạnh khi chân sau, hờ hụt khi hớt.
	var ankle_l: float = -0.45 * max(0.0, s_l) + 0.25 * max(0.0, -s_l)
	var ankle_r: float = -0.45 * max(0.0, s_r) + 0.25 * max(0.0, -s_r)

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
	# Nhún theo nhịp — vai rung theo từng bước, thân dao động dọc trục
	var bob: float = abs(sin(cyc)) * 0.07
	mesh.rig.position.y = _spring("rig_y", 0.02 + bob, 9.0, 1.0, delta)
	# Cột sống xoay nhẹ theo nhịp vung tay
	mesh.body.rotation.x = _spring("body_x", -0.12 + sin(cyc * 0.5) * 0.05, 8.0, 0.9, delta)
	mesh.pelvis.rotation.z = _spring("pelvis_twist", sin(cyc) * 0.08, 8.0, 0.8, delta)
	mesh.pelvis.rotation.x = _spring("pelvis_x", -0.05, 7.0, 0.9, delta)
	mesh.neck.rotation.y = _spring("neck_y", sin(cyc * 0.5) * 0.14, 7.0, 0.8, delta)
	mesh.head.rotation.x = _spring("head_x", -0.15, 7.0, 0.9, delta)
	mesh.head.rotation.z = _spring("head_z", sin(cyc * 0.5) * 0.06, 7.0, 0.8, delta)
	mesh.neck.rotation.x = _spring("neck_x", -0.06, 7.0, 0.9, delta)
	mesh.backpack.position.z = _spring("bp_z", -0.06 + abs(sin(cyc * 0.5)) * 0.02, 8.0, 0.9, delta)
	mesh.backpack.rotation.x = _spring("bp_rx", sin(cyc * 0.5) * 0.06, 8.0, 0.9, delta)

	# Tay vung rộng — co 90° đưa ra trước (hông→cằm), không quặt sau lưng — hướng ngược
	if not _weapon_owns_arms():
		var arm_amp: float = 0.25
		mesh.arm_l.rotation.x = _spring("arm_l_x", -0.65 + hip_l * arm_amp, 12.0, 1.0, delta)
		mesh.arm_r.rotation.x = _spring("arm_r_x", -0.65 + hip_r * arm_amp, 12.0, 1.0, delta)
		mesh.arm_l.rotation.z = _spring("arm_l_z", 0.14, 9.0, 0.9, delta)
		mesh.arm_r.rotation.z = _spring("arm_r_z", -0.14, 9.0, 0.9, delta)
		# Khuỷu khóa ~90° — gập trước ngực (đảo dấu do hướng ngược)
		mesh.elbow_l.rotation.x = _spring("elbow_l_x", -1.10, 14.0, 1.0, delta)
		mesh.elbow_r.rotation.x = _spring("elbow_r_x", -1.10, 14.0, 1.0, delta)

# ── Ngồi xổm / lẻn ─────────────────────────────────────────────────────────
## Chuyển tiếp vào: hông hạ thấp đột ngột, gập sâu gối, cột sống uốn cong,
## đầu & vai gập về trước ~35°.
## Crouch-walk: bước ngắn, đùi song song/gần mặt đất, tiếp đất bằng mũi/bản
## giữa (không gót) giảm xóc & tiếng động; tay đưa cao ngang ngực giữ thăng
## bằng, khuỷu tay co gập.
func _crouch(delta: float, t: float) -> void:
	var cyc: float = t * walk_cycle_speed * 0.5
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
		# Tay đưa cao ngang ngực/hông giữ thăng bằng, khuỷu co gập
		mesh.arm_l.rotation.x = _spring("arm_l_x", -0.50 + s_l * 0.10, 8.0, 0.8, delta)
		mesh.arm_r.rotation.x = _spring("arm_r_x", -0.50 + s_r * 0.10, 8.0, 0.8, delta)
		mesh.arm_l.rotation.z = _spring("arm_l_z", 0.15, 7.0, 0.9, delta)
		mesh.arm_r.rotation.z = _spring("arm_r_z", -0.15, 7.0, 0.9, delta)
		mesh.elbow_l.rotation.x = _spring("elbow_l_x", 0.90, 8.0, 0.8, delta)
		mesh.elbow_r.rotation.x = _spring("elbow_r_x", 0.90, 8.0, 0.8, delta)
		_follow_l_elbow(delta)
		_follow_r_elbow(delta)

# ── Lao nhanh ──────────────────────────────────────────────────────────────
## 3 pha: Wind-up (chân trụ gập sâu nhún xuống, tay rút nhanh sau) →
## Execution (đạp biến lực thành động năng, lao vọt theo đường chéo sát đất,
## cột sống + chân sau duỗi thẳng tắp) → Recovery (chân trước vươn xa gập gối
## hãm, tay xòe rộng/gạt xuống sàn cân bằng).
func _dash(delta: float, _t: float) -> void:
	var rem: float = base._dash_timer
	var prog: float = 1.0 - clamp(rem / base.dash_duration, 0.0, 1.0)
	# Wind-up ~12%, Execution ~70%, Recovery ~18%
	var down: float = smoothstep(0.0, 0.12, prog)
	var up:   float = smoothstep(0.12, 0.82, prog)
	var rec:  float = smoothstep(0.82, 1.0, prog)
	# Wind-up: nhún sâu xuống chân trụ. Execution: nhẹ nhấc lao tới.
	# Recovery: hạ nhẹ sau khi hãm.
	mesh.rig.position.y  = _spring("rig_y",  0.02 + down * (-0.14) + up * 0.03 + rec * 0.04, 15.0, 1.0, delta)
	# Cột sống duỗi thẳng lao theo đường chéo sát đất khi Execution
	mesh.rig.rotation.x  = _spring("rig_x",  0.32 * up + 0.12 * rec, 14.0, 0.9, delta)
	mesh.pelvis.rotation.x = _spring("pelvis_x", -0.18 * up, 12.0, 0.9, delta)
	mesh.body.rotation.x  = _spring("body_x", 0.12 * up + 0.16 * rec, 12.0, 0.9, delta)
	mesh.neck.rotation.x   = _spring("neck_x", 0.12 * up, 12.0, 0.9, delta)
	mesh.head.rotation.x   = _spring("head_x", -0.22 * up, 12.0, 0.9, delta)
	mesh.backpack.position.z = _spring("bp_z", -0.06 * up - 0.04 * rec, 12.0, 1.0, delta)
	if not _weapon_owns_arms():
		# Wind-up: tay rút nhanh về sau (tạo đà). Execution: tay xòe rộng.
		# Recovery: tay gạt xuống sàn cân bằng lại trọng tâm.
		var ax: float = lerp(-0.60, -0.10, up) * (1.0 - rec) - 0.30 * rec
		var bx: float = 0.35 * down - 0.18 * up + 0.30 * rec
		mesh.arm_l.rotation.x = _spring("arm_l_x", ax, 15.0, 0.9, delta)
		mesh.arm_r.rotation.x = _spring("arm_r_x", ax, 15.0, 0.9, delta)
		mesh.arm_l.rotation.z = _spring("arm_l_z", bx, 13.0, 0.9, delta)
		mesh.arm_r.rotation.z = _spring("arm_r_z", -bx, 13.0, 0.9, delta)
		# Khuỷu gập khi rút tay sau (wind-up), xòe thẳng khi phóng
		mesh.elbow_l.rotation.x = _spring("elbow_l_x", 0.80 * down - 0.20 * up, 13.0, 0.9, delta)
		mesh.elbow_r.rotation.x = _spring("elbow_r_x", 0.80 * down - 0.20 * up, 13.0, 0.9, delta)
	# Chân: Wind-up chân trụ gập sâu nhún. Execution: chân sau duỗi thẳng tắp
	# đạp nền, chân trước hướng lao. Recovery: chân trước vươn xa gập gối hãm.
	var leg_wind: float = -0.55 * down
	var leg_exec: float = -0.35 * up + 0.85 * rec
	var knee_wind: float = 0.95 * down
	var knee_exec: float = 0.08 * up + 0.95 * rec
	# Ankle/foot luôn giữ mũi hướng lên nhẹ (dorsiflex) để tránh chân lún đất.
	var ankle_target: float = 0.15 * up + 0.30 * rec
	mesh.leg_l.rotation.x   = _spring("leg_l_x",   leg_wind + leg_exec, 13.0, 1.0, delta)
	mesh.leg_r.rotation.x   = _spring("leg_r_x",   leg_wind + leg_exec, 13.0, 1.0, delta)
	mesh.knee_l.rotation.x  = _spring("knee_l_x",  knee_wind + knee_exec, 13.0, 1.0, delta)
	mesh.knee_r.rotation.x  = _spring("knee_r_x",  knee_wind + knee_exec, 13.0, 1.0, delta)
	mesh.ankle_l.rotation.x = _spring("ankle_l_x", ankle_target, 13.0, 1.0, delta)
	mesh.ankle_r.rotation.x = _spring("ankle_r_x", ankle_target, 13.0, 1.0, delta)
	mesh.foot_l.rotation.x = _spring("foot_l_x", 0.0, 13.0, 1.0, delta)
	mesh.foot_r.rotation.x = _spring("foot_r_x", 0.0, 13.0, 1.0, delta)

# ── Nhảy / rơi ─────────────────────────────────────────────────────────────
## Chuỗi 3 pha: Take-off (khuỵu gối 45°, tay văng sau → duỗi dứt khoát 3 khớp
## cổ chân-gối-hông + vung tay lên cao) → In-air/Fall (đỉnh: đùi thu nhẹ; rơi:
## duỗi thẳng, tay xòe ngang, nhìn điểm hạ đất) → Landing (mũi chân chạm trước,
## gối gập sâu hấp thụ, thân gập sâu, tay chống nhẹ đất).
func _air(delta: float, t: float, rising: bool) -> void:
	var vy: float = base.velocity.y
	var on_floor: bool = base.is_on_floor()
	var tuck: float
	if rising:
		# Sau cú đẩy: chân đang duỗi thẳng dứt khoát (tuck≈0 khi vy~jump_v).
		# Khi tiến về đỉnh (vy→0) đùi thu nhẹ về phía ngực (tuck→1) — curl chuẩn bị.
		tuck = clamp((1.0 - abs(vy / base._jump_v)) * 1.4, 0.0, 1.0)
	else:
		tuck = clamp(1.0 + vy / base._jump_v, 0.0, 1.0) * 0.5
	# Pha hạ cánh: dựa trên tốc độ rơi + trạng thái chạm đất.
	var landing: float = 0.0
	if not rising and vy < 0.0:
		landing = clamp(-vy / base._grav_fall, 0.0, 1.0)
		if on_floor:
			landing = 1.0
	var takeoff: float = 1.0 if rising else 0.0
	# Take-off: nhấc nhẹ, lao lên. Fall: thẳng. Landing: ép xuống hấp thụ.
	mesh.rig.position.y  = _spring("rig_y",  0.02 + takeoff * 0.06 - landing * 0.05, 8.0, 1.0, delta)
	mesh.rig.rotation.x  = _spring("rig_x",  0.05 + tuck * 0.10 - landing * 0.15, 8.0, 0.9, delta)
	# Thân: take-off hơi ngả sau để đột phá, fall duỗi thẳng, landing gập sâu
	mesh.body.rotation.x   = _spring("body_x", -0.05 + tuck * 0.15 - landing * 0.35, 8.0, 0.9, delta)
	mesh.pelvis.rotation.x = _spring("pelvis_x", 0.15 + tuck * 0.20 + landing * 0.35, 8.0, 0.9, delta)
	mesh.head.rotation.x   = _spring("head_x", -0.12 + tuck * 0.08 - landing * 0.20, 7.0, 0.9, delta)
	mesh.neck.rotation.x    = _spring("neck_x", 0.06, 6.0, 0.9, delta)
	mesh.backpack.position.z = _spring("bp_z", -0.05 - tuck * 0.04, 8.0, 1.0, delta)
	if not _weapon_owns_arms():
		# Take-off: tay văng ra sau tạo đà rồi vung lên cao. Fall: xòe ngang.
		# Landing: hớt xuống chống nhẹ đất.
		var arm_spread: float = tuck * 0.35
		mesh.arm_l.rotation.x = _spring("arm_l_x", -0.35 - takeoff * 0.55 + landing * 0.40, 9.0, 0.9, delta)
		mesh.arm_r.rotation.x = _spring("arm_r_x", -0.35 - takeoff * 0.55 + landing * 0.40, 9.0, 0.9, delta)
		mesh.arm_l.rotation.z = _spring("arm_l_z", (0.25 + arm_spread) * (1.0 - takeoff) + 0.35 * takeoff + landing * 0.30, 8.0, 0.9, delta)
		mesh.arm_r.rotation.z = _spring("arm_r_z", -(0.25 + arm_spread) * (1.0 - takeoff) - 0.35 * takeoff - landing * 0.30, 8.0, 0.9, delta)
		mesh.elbow_l.rotation.x = _spring("elbow_l_x", -0.25 - arm_spread * 0.5 + landing * 0.45, 8.0, 0.9, delta)
		mesh.elbow_r.rotation.x = _spring("elbow_r_x", -0.25 - arm_spread * 0.5 + landing * 0.45, 8.0, 0.9, delta)
	# Chân: take-off duỗi dứt khoát 3 khớp (cổ chân-gối-hông) sau khi co gập,
	# fall duỗi thẳng có kiểm soát, landing gập sâu hấp thụ + mũi chạm đất trước.
	var tuck_leg: float = -0.35 - tuck * 0.30 + landing * (-0.45)
	var tuck_knee: float = 0.20 + tuck * 0.95 + landing * 0.80
	# Cổ chân: take-off giữ mũi hướng lên, fall duỗi thẳng, landing gãy mũi
	# nhưng luôn dương (mũi hướng lên) để mũi chân chạm đất trước không lún gót.
	var tuck_ankle: float = max(-0.05, -0.08 - tuck * 0.25 + landing * 0.35)
	mesh.leg_l.rotation.x   = _spring("leg_l_x",   tuck_leg,  10.0 + tuck, 1.0, delta)
	mesh.leg_r.rotation.x   = _spring("leg_r_x",   tuck_leg,  10.0 + tuck, 1.0, delta)
	mesh.knee_l.rotation.x  = _spring("knee_l_x",  tuck_knee, 10.0 + tuck, 1.0, delta)
	mesh.knee_r.rotation.x  = _spring("knee_r_x",  tuck_knee, 10.0 + tuck, 1.0, delta)
	mesh.ankle_l.rotation.x = _spring("ankle_l_x", tuck_ankle, 9.0 + tuck, 1.0, delta)
	mesh.ankle_r.rotation.x = _spring("ankle_r_x", tuck_ankle, 9.0 + tuck, 1.0, delta)
	# Foot duỗi thẳng (0.0) — không bao giờ âm để tránh lún xuống đất.
	mesh.foot_l.rotation.x = _spring("foot_l_x", 0.0, 7.0, 1.0, delta)
	mesh.foot_r.rotation.x = _spring("foot_r_x", 0.0, 7.0, 1.0, delta)

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
		# Khuỷu duỗi khi vươn, gập khi kéo nước về sau hông
		mesh.elbow_l.rotation.x = _spring("elbow_l_x", clamp(-a_l * 0.55 + 0.15, 0.0, 0.95), 9.0, 0.9, delta)
		mesh.elbow_r.rotation.x = _spring("elbow_r_x", clamp(-a_r * 0.55 + 0.15, 0.0, 0.95), 9.0, 0.9, delta)
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
		mesh.elbow_r.rotation.x = _spring("elbow_r_x", 0.70 + chew * 0.06, 9.0, 0.9, delta)
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
		mesh.elbow_l.rotation.x = lerp(mesh.elbow_l.rotation.x, 0.30 * p, delta * 15.0)
		mesh.elbow_r.rotation.x = lerp(mesh.elbow_r.rotation.x, 0.30 * p, delta * 15.0)
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
		# Chi buông thõng chạm đất
		mesh.elbow_l.rotation.x = lerp(mesh.elbow_l.rotation.x, 0.35, delta * 6.0)
		mesh.elbow_r.rotation.x = lerp(mesh.elbow_r.rotation.x, 0.35, delta * 6.0)
	mesh.foot_l.rotation.x = 0.0
	mesh.foot_r.rotation.x = 0.0

# ── Khuỷu tay theo đà quét của vai (elastic follow-through) ─────────────────
## Khi vai chuyển (arm.rotation.x chênh khỏi buông thõng), khuỷu tự gập/duỗi
## theo quán tính → cánh tay có độ trễ đàn hồi thay vì cứng đờ.
func _elbow_bend_target(arm_angle: float) -> float:
	var bend: float = 0.35 + arm_angle * 0.8
	return clamp(bend, -0.65, 0.95)

func _follow_l_elbow(delta: float) -> void:
	if _weapon_owns_arms():
		return
	mesh.elbow_l.rotation.x = _spring("elbow_l_x", _elbow_bend_target(mesh.arm_l.rotation.x), 9.0, 0.75, delta)

func _follow_r_elbow(delta: float) -> void:
	if _weapon_owns_arms():
		return
	mesh.elbow_r.rotation.x = _spring("elbow_r_x", _elbow_bend_target(mesh.arm_r.rotation.x), 9.0, 0.75, delta)

# ── Tấn công (giữ nguyên logic vũ khí — các pivot cũ vẫn tồn tại) ────────────
func _attack(delta: float, _t: float) -> void:
	var dur: float = base.attack_duration
	var remaining: float = base._attack_timer
	var prog: float = 1.0 - clamp(remaining / dur, 0.0, 1.0)
	var step: int = player.combo_step if player != null else 0
	var wp := mesh.weapon_pivot
	const IDLE_WP: Vector3 = Vector3(90, 0, 0)

	if remaining > _last_remaining + 0.001:
		_slash_spawned = false
	_last_remaining = remaining

	var is_heavy: bool = player and player.equipped_weapon != null and (player.equipped_weapon.id == "axe" or player.equipped_weapon.id == "pickaxe")
	var is_gs: bool = player and player.equipped_weapon != null and player.equipped_weapon.id == "iron_greatsword"
	var is_halberd: bool = player and player.equipped_weapon != null and player.equipped_weapon.id == "iron_halberd"

	if is_heavy:
		if prog < 0.35:
			var p: float = prog / 0.35
			wp.rotation_degrees.x = lerp(wp.rotation_degrees.x, -35.0 + 90.0 * (1.0 - p), delta * 14.0)
			wp.rotation_degrees.y = lerp(wp.rotation_degrees.y, 8.0 * p, delta * 14.0)
			wp.rotation_degrees.z = lerp(wp.rotation_degrees.z, -5.0 * p, delta * 14.0)
			mesh.arm_r.rotation.x = lerp(mesh.arm_r.rotation.x, -0.70 * p, delta * 18.0)
			mesh.arm_r.rotation.z = lerp(mesh.arm_r.rotation.z, 0.06 * p, delta * 14.0)
			mesh.rig.rotation.x = lerp(mesh.rig.rotation.x, -0.06 * p, delta * 14.0)
			mesh.rig.rotation.y = lerp(mesh.rig.rotation.y, 0.08 * p, delta * 12.0)
			mesh.body.rotation.x = lerp(mesh.body.rotation.x, 0.06 * p, delta * 12.0)
			mesh.head.rotation.y = lerp(mesh.head.rotation.y, 0.14 * p, delta * 12.0)
			mesh.arm_l.rotation.x = lerp(mesh.arm_l.rotation.x, 0.10 * p, delta * 12.0)
			mesh.elbow_r.rotation.x = _spring("elbow_r_x", 0.55 * p, 10.0, 0.75, delta)
		elif prog < 0.75:
			if not _slash_spawned:
				_slash_spawned = true
				_spawn_slash(step)
			var p: float = (prog - 0.35) / 0.40
			wp.rotation_degrees.x = lerp(wp.rotation_degrees.x, 145.0, delta * 26.0)
			wp.rotation_degrees.y = lerp(wp.rotation_degrees.y, -12.0, delta * 22.0)
			wp.rotation_degrees.z = lerp(wp.rotation_degrees.z, 8.0, delta * 22.0)
			mesh.arm_r.rotation.x = lerp(mesh.arm_r.rotation.x, 0.50 * p - 0.70 * (1.0 - p), delta * 28.0)
			mesh.arm_r.rotation.z = lerp(mesh.arm_r.rotation.z, -0.12 * sin(p * PI), delta * 22.0)
			mesh.rig.rotation.x = lerp(mesh.rig.rotation.x, 0.10 * sin(p * PI), delta * 18.0)
			mesh.rig.rotation.y = lerp(mesh.rig.rotation.y, -0.15 * sin(p * PI), delta * 18.0)
			mesh.body.rotation.x = lerp(mesh.body.rotation.x, -0.08 * sin(p * PI), delta * 16.0)
			mesh.head.rotation.y = lerp(mesh.head.rotation.y, -0.18 * sin(p * PI), delta * 16.0)
			mesh.head.rotation.x = lerp(mesh.head.rotation.x, 0.10 * sin(p * PI), delta * 14.0)
			mesh.arm_l.rotation.x = lerp(mesh.arm_l.rotation.x, -0.15 * sin(p * PI), delta * 14.0)
			mesh.leg_r.rotation.x = lerp(mesh.leg_r.rotation.x, 0.20 * sin(p * PI), delta * 12.0)
			mesh.elbow_r.rotation.x = _spring("elbow_r_x", -0.15, 12.0, 0.75, delta)
		else:
			wp.rotation_degrees = wp.rotation_degrees.lerp(IDLE_WP, delta * 10.0)
			mesh.rig.rotation.x = lerp(mesh.rig.rotation.x, 0.0, delta * 10.0)
			mesh.rig.rotation.y = lerp(mesh.rig.rotation.y, 0.0, delta * 10.0)
			mesh.rig.rotation.z = lerp(mesh.rig.rotation.z, 0.0, delta * 10.0)
			mesh.body.rotation.x = lerp(mesh.body.rotation.x, 0.0, delta * 10.0)
			mesh.head.rotation.x = lerp(mesh.head.rotation.x, 0.0, delta * 10.0)
			mesh.head.rotation.y = lerp(mesh.head.rotation.y, 0.0, delta * 10.0)
			mesh.arm_r.rotation.x = lerp(mesh.arm_r.rotation.x, -0.06, delta * 10.0)
			mesh.arm_r.rotation.z = lerp(mesh.arm_r.rotation.z, -0.04, delta * 10.0)
			mesh.arm_l.rotation.x = lerp(mesh.arm_l.rotation.x, -0.06, delta * 10.0)
			mesh.leg_l.rotation.x = lerp(mesh.leg_l.rotation.x, 0.02, delta * 10.0)
			mesh.leg_r.rotation.x = lerp(mesh.leg_r.rotation.x, 0.02, delta * 10.0)
			_follow_r_elbow(delta)
			_follow_l_elbow(delta)

	elif is_gs:
		if prog < 0.40:
			var p: float = prog / 0.40
			match step:
				0:
					wp.rotation_degrees.x = lerp(wp.rotation_degrees.x, -40.0 + 90.0 * (1.0 - p), delta * 16.0)
					wp.rotation_degrees.y = lerp(wp.rotation_degrees.y, 6.0 * p, delta * 14.0)
					wp.rotation_degrees.z = lerp(wp.rotation_degrees.z, -4.0 * p, delta * 14.0)
					mesh.arm_r.rotation.x = lerp(mesh.arm_r.rotation.x, -0.60 * p, delta * 20.0)
					mesh.arm_r.rotation.z = lerp(mesh.arm_r.rotation.z, 0.05 * p, delta * 16.0)
					mesh.rig.rotation.x = lerp(mesh.rig.rotation.x, -0.05 * p, delta * 14.0)
					mesh.rig.rotation.y = lerp(mesh.rig.rotation.y, 0.06 * p, delta * 14.0)
					mesh.body.rotation.x = lerp(mesh.body.rotation.x, 0.04 * p, delta * 12.0)
					mesh.head.rotation.y = lerp(mesh.head.rotation.y, 0.10 * p, delta * 12.0)
					mesh.arm_l.rotation.x = lerp(mesh.arm_l.rotation.x, 0.08 * p, delta * 12.0)
				1:
					wp.rotation_degrees.x = lerp(wp.rotation_degrees.x, 60.0, delta * 16.0)
					wp.rotation_degrees.y = lerp(wp.rotation_degrees.y, 40.0, delta * 14.0)
					wp.rotation_degrees.z = lerp(wp.rotation_degrees.z, -18.0, delta * 14.0)
					mesh.arm_r.rotation.x = lerp(mesh.arm_r.rotation.x, -0.50 * p, delta * 20.0)
					mesh.arm_r.rotation.z = lerp(mesh.arm_r.rotation.z, -0.22 * p, delta * 16.0)
					mesh.rig.rotation.y = lerp(mesh.rig.rotation.y, 0.15 * p, delta * 14.0)
					mesh.head.rotation.y = lerp(mesh.head.rotation.y, 0.22 * p, delta * 12.0)
					mesh.arm_l.rotation.x = lerp(mesh.arm_l.rotation.x, 0.14 * p, delta * 12.0)
			mesh.rig.rotation.x = lerp(mesh.rig.rotation.x, -0.06 * p, delta * 14.0)
			mesh.elbow_r.rotation.x = _spring("elbow_r_x", 0.50 * p, 10.0, 0.75, delta)
		elif prog < 0.85:
			if not _slash_spawned:
				_slash_spawned = true
				_spawn_slash(step)
			var p: float = (prog - 0.40) / 0.45
			match step:
				0:
					wp.rotation_degrees.x = lerp(wp.rotation_degrees.x, 155.0, delta * 28.0)
					wp.rotation_degrees.y = lerp(wp.rotation_degrees.y, -10.0, delta * 24.0)
					wp.rotation_degrees.z = lerp(wp.rotation_degrees.z, 7.0, delta * 24.0)
					mesh.arm_r.rotation.x = lerp(mesh.arm_r.rotation.x, 0.60 * p - 0.60 * (1.0 - p), delta * 30.0)
					mesh.arm_r.rotation.z = lerp(mesh.arm_r.rotation.z, -0.10 * sin(p * PI), delta * 24.0)
					mesh.rig.rotation.y = lerp(mesh.rig.rotation.y, -0.18 * sin(p * PI), delta * 20.0)
					mesh.head.rotation.y = lerp(mesh.head.rotation.y, -0.20 * sin(p * PI), delta * 18.0)
					mesh.head.rotation.x = lerp(mesh.head.rotation.x, 0.08 * sin(p * PI), delta * 16.0)
					mesh.arm_l.rotation.x = lerp(mesh.arm_l.rotation.x, -0.14 * sin(p * PI), delta * 16.0)
					mesh.leg_r.rotation.x = lerp(mesh.leg_r.rotation.x, 0.22 * sin(p * PI), delta * 14.0)
				1:
					wp.rotation_degrees.x = lerp(wp.rotation_degrees.x, 118.0, delta * 28.0)
					wp.rotation_degrees.y = lerp(wp.rotation_degrees.y, -30.0, delta * 24.0)
					wp.rotation_degrees.z = lerp(wp.rotation_degrees.z, 14.0, delta * 24.0)
					mesh.arm_r.rotation.x = lerp(mesh.arm_r.rotation.x, 0.80 * p - 0.50 * (1.0 - p), delta * 32.0)
					mesh.arm_r.rotation.z = lerp(mesh.arm_r.rotation.z, 0.22 * sin(p * PI), delta * 26.0)
					mesh.rig.rotation.y = lerp(mesh.rig.rotation.y, -0.35 * sin(p * PI), delta * 22.0)
					mesh.head.rotation.y = lerp(mesh.head.rotation.y, -0.40 * sin(p * PI), delta * 20.0)
					mesh.head.rotation.x = lerp(mesh.head.rotation.x, 0.06 * sin(p * PI), delta * 16.0)
					mesh.arm_l.rotation.x = lerp(mesh.arm_l.rotation.x, -0.25 * sin(p * PI), delta * 18.0)
					mesh.leg_r.rotation.x = lerp(mesh.leg_r.rotation.x, 0.18 * sin(p * PI), delta * 14.0)
			mesh.rig.rotation.x = lerp(mesh.rig.rotation.x, 0.10 * p, delta * 20.0)
			mesh.rig.rotation.z = lerp(mesh.rig.rotation.z, -0.04 * sin(p * PI), delta * 18.0)
			mesh.body.rotation.x = lerp(mesh.body.rotation.x, 0.06 * p, delta * 16.0)
			mesh.elbow_r.rotation.x = _spring("elbow_r_x", -0.10, 12.0, 0.75, delta)
		else:
			wp.rotation_degrees = wp.rotation_degrees.lerp(IDLE_WP, delta * 10.0)
			mesh.rig.rotation.x = lerp(mesh.rig.rotation.x, 0.0, delta * 10.0)
			mesh.rig.rotation.y = lerp(mesh.rig.rotation.y, 0.0, delta * 10.0)
			mesh.rig.rotation.z = lerp(mesh.rig.rotation.z, 0.0, delta * 10.0)
			mesh.body.rotation.x = lerp(mesh.body.rotation.x, 0.0, delta * 10.0)
			mesh.head.rotation.x = lerp(mesh.head.rotation.x, 0.0, delta * 10.0)
			mesh.head.rotation.y = lerp(mesh.head.rotation.y, 0.0, delta * 10.0)
			mesh.arm_r.rotation.x = lerp(mesh.arm_r.rotation.x, -0.06, delta * 10.0)
			mesh.arm_r.rotation.z = lerp(mesh.arm_r.rotation.z, -0.04, delta * 10.0)
			mesh.arm_l.rotation.x = lerp(mesh.arm_l.rotation.x, -0.06, delta * 10.0)
			mesh.leg_l.rotation.x = lerp(mesh.leg_l.rotation.x, 0.02, delta * 10.0)
			mesh.leg_r.rotation.x = lerp(mesh.leg_r.rotation.x, 0.02, delta * 10.0)
			# Đặt lại ankle/foot về phẳng — tránh kế thừa trạng thái lún đất từ state trước
			mesh.ankle_l.rotation.x = _spring("ankle_l_x", 0.02, 10.0, 1.0, delta)
			mesh.ankle_r.rotation.x = _spring("ankle_r_x", 0.02, 10.0, 1.0, delta)
			mesh.foot_l.rotation.x = _spring("foot_l_x", 0.0, 7.0, 1.0, delta)
			mesh.foot_r.rotation.x = _spring("foot_r_x", 0.0, 7.0, 1.0, delta)
			_follow_r_elbow(delta)
			_follow_l_elbow(delta)
			if remaining <= 0.0 and player and player.combo_timer <= 0.0:
				player.combo_step = 0

	elif is_halberd:
		if prog < 0.35:
			var p: float = prog / 0.35
			match step:
				0:
					wp.rotation_degrees.x = lerp(wp.rotation_degrees.x, -40.0 + 90.0 * (1.0 - p), delta * 16.0)
					wp.rotation_degrees.y = lerp(wp.rotation_degrees.y, 6.0 * p, delta * 14.0)
					wp.rotation_degrees.z = lerp(wp.rotation_degrees.z, -4.0 * p, delta * 14.0)
					mesh.arm_r.rotation.x = lerp(mesh.arm_r.rotation.x, -0.60 * p, delta * 20.0)
					mesh.arm_r.rotation.z = lerp(mesh.arm_r.rotation.z, 0.05 * p, delta * 16.0)
					mesh.rig.rotation.x = lerp(mesh.rig.rotation.x, -0.05 * p, delta * 14.0)
					mesh.rig.rotation.y = lerp(mesh.rig.rotation.y, 0.06 * p, delta * 14.0)
					mesh.body.rotation.x = lerp(mesh.body.rotation.x, 0.04 * p, delta * 12.0)
					mesh.head.rotation.y = lerp(mesh.head.rotation.y, 0.10 * p, delta * 12.0)
					mesh.arm_l.rotation.x = lerp(mesh.arm_l.rotation.x, 0.08 * p, delta * 12.0)
				1:
					wp.rotation_degrees.x = lerp(wp.rotation_degrees.x, 60.0, delta * 16.0)
					wp.rotation_degrees.y = lerp(wp.rotation_degrees.y, 40.0, delta * 14.0)
					wp.rotation_degrees.z = lerp(wp.rotation_degrees.z, -18.0, delta * 14.0)
					mesh.arm_r.rotation.x = lerp(mesh.arm_r.rotation.x, -0.50 * p, delta * 20.0)
					mesh.arm_r.rotation.z = lerp(mesh.arm_r.rotation.z, -0.22 * p, delta * 16.0)
					mesh.rig.rotation.y = lerp(mesh.rig.rotation.y, 0.15 * p, delta * 14.0)
					mesh.head.rotation.y = lerp(mesh.head.rotation.y, 0.22 * p, delta * 12.0)
					mesh.arm_l.rotation.x = lerp(mesh.arm_l.rotation.x, 0.14 * p, delta * 12.0)
			mesh.rig.rotation.x = lerp(mesh.rig.rotation.x, -0.06 * p, delta * 14.0)
			mesh.elbow_r.rotation.x = _spring("elbow_r_x", 0.50 * p, 10.0, 0.75, delta)
		elif prog < 0.80:
			if not _slash_spawned:
				_slash_spawned = true
				_spawn_slash(step)
			var p: float = (prog - 0.35) / 0.45
			match step:
				0:
					wp.rotation_degrees.x = lerp(wp.rotation_degrees.x, 155.0, delta * 28.0)
					wp.rotation_degrees.y = lerp(wp.rotation_degrees.y, -10.0, delta * 24.0)
					wp.rotation_degrees.z = lerp(wp.rotation_degrees.z, 7.0, delta * 24.0)
					mesh.arm_r.rotation.x = lerp(mesh.arm_r.rotation.x, 0.60 * p - 0.60 * (1.0 - p), delta * 30.0)
					mesh.arm_r.rotation.z = lerp(mesh.arm_r.rotation.z, -0.10 * sin(p * PI), delta * 24.0)
					mesh.rig.rotation.y = lerp(mesh.rig.rotation.y, -0.18 * sin(p * PI), delta * 20.0)
					mesh.head.rotation.y = lerp(mesh.head.rotation.y, -0.20 * sin(p * PI), delta * 18.0)
					mesh.head.rotation.x = lerp(mesh.head.rotation.x, 0.08 * sin(p * PI), delta * 16.0)
					mesh.arm_l.rotation.x = lerp(mesh.arm_l.rotation.x, -0.14 * sin(p * PI), delta * 16.0)
					mesh.leg_r.rotation.x = lerp(mesh.leg_r.rotation.x, 0.22 * sin(p * PI), delta * 14.0)
				1:
					wp.rotation_degrees.x = lerp(wp.rotation_degrees.x, 118.0, delta * 28.0)
					wp.rotation_degrees.y = lerp(wp.rotation_degrees.y, -30.0, delta * 24.0)
					wp.rotation_degrees.z = lerp(wp.rotation_degrees.z, 14.0, delta * 24.0)
					mesh.arm_r.rotation.x = lerp(mesh.arm_r.rotation.x, 0.80 * p - 0.50 * (1.0 - p), delta * 32.0)
					mesh.arm_r.rotation.z = lerp(mesh.arm_r.rotation.z, 0.22 * sin(p * PI), delta * 26.0)
					mesh.rig.rotation.y = lerp(mesh.rig.rotation.y, -0.35 * sin(p * PI), delta * 22.0)
					mesh.head.rotation.y = lerp(mesh.head.rotation.y, -0.40 * sin(p * PI), delta * 20.0)
					mesh.head.rotation.x = lerp(mesh.head.rotation.x, 0.06 * sin(p * PI), delta * 16.0)
					mesh.arm_l.rotation.x = lerp(mesh.arm_l.rotation.x, -0.25 * sin(p * PI), delta * 18.0)
					mesh.leg_r.rotation.x = lerp(mesh.leg_r.rotation.x, 0.18 * sin(p * PI), delta * 14.0)
			mesh.rig.rotation.x = lerp(mesh.rig.rotation.x, 0.10 * p, delta * 20.0)
			mesh.rig.rotation.z = lerp(mesh.rig.rotation.z, -0.04 * sin(p * PI), delta * 18.0)
			mesh.body.rotation.x = lerp(mesh.body.rotation.x, 0.06 * p, delta * 16.0)
			mesh.elbow_r.rotation.x = _spring("elbow_r_x", -0.10, 12.0, 0.75, delta)
		else:
			wp.rotation_degrees = wp.rotation_degrees.lerp(IDLE_WP, delta * 10.0)
			mesh.rig.rotation.x = lerp(mesh.rig.rotation.x, 0.0, delta * 10.0)
			mesh.rig.rotation.y = lerp(mesh.rig.rotation.y, 0.0, delta * 10.0)
			mesh.rig.rotation.z = lerp(mesh.rig.rotation.z, 0.0, delta * 10.0)
			mesh.body.rotation.x = lerp(mesh.body.rotation.x, 0.0, delta * 10.0)
			mesh.head.rotation.x = lerp(mesh.head.rotation.x, 0.0, delta * 10.0)
			mesh.head.rotation.y = lerp(mesh.head.rotation.y, 0.0, delta * 10.0)
			mesh.arm_r.rotation.x = lerp(mesh.arm_r.rotation.x, -0.06, delta * 10.0)
			mesh.arm_r.rotation.z = lerp(mesh.arm_r.rotation.z, -0.04, delta * 10.0)
			mesh.arm_l.rotation.x = lerp(mesh.arm_l.rotation.x, -0.06, delta * 10.0)
			mesh.leg_l.rotation.x = lerp(mesh.leg_l.rotation.x, 0.02, delta * 10.0)
			mesh.leg_r.rotation.x = lerp(mesh.leg_r.rotation.x, 0.02, delta * 10.0)
			mesh.ankle_l.rotation.x = _spring("ankle_l_x", 0.02, 10.0, 1.0, delta)
			mesh.ankle_r.rotation.x = _spring("ankle_r_x", 0.02, 10.0, 1.0, delta)
			mesh.foot_l.rotation.x = _spring("foot_l_x", 0.0, 7.0, 1.0, delta)
			mesh.foot_r.rotation.x = _spring("foot_r_x", 0.0, 7.0, 1.0, delta)
			_follow_r_elbow(delta)
			_follow_l_elbow(delta)
			if remaining <= 0.0 and player and player.combo_timer <= 0.0:
				player.combo_step = 0

	else:
		# ── Epic Fight prototype: iron_sword — IDLE → AUTO_ATTACK → RECOVERY ──
		# Chuẩn khớp: vai (arm) xoay trước/sau, khuỷu (elbow) gập 90° khi chém,
		# cổ tay/bàn tay theo weapon_pivot, chân trụ giữ thăng bằng.
		if prog < 0.20:
			# Anticipation: kéo kiếm ra sau, vai mở, khuỷu co nhẹ
			var p: float = prog / 0.20
			match step:
				0:
					wp.rotation_degrees.x = lerp(wp.rotation_degrees.x, 72.0, delta * 18.0)
					wp.rotation_degrees.y = lerp(wp.rotation_degrees.y, 28.0, delta * 18.0)
					wp.rotation_degrees.z = lerp(wp.rotation_degrees.z, -14.0, delta * 18.0)
					mesh.arm_r.rotation.x = lerp(mesh.arm_r.rotation.x, -0.55 * p, delta * 22.0)
					mesh.arm_r.rotation.z = lerp(mesh.arm_r.rotation.z, -0.20 * p, delta * 18.0)
					mesh.rig.rotation.y = lerp(mesh.rig.rotation.y, 0.12 * p, delta * 16.0)
					mesh.head.rotation.y = lerp(mesh.head.rotation.y, 0.18 * p, delta * 14.0)
					mesh.arm_l.rotation.x = lerp(mesh.arm_l.rotation.x, -0.05 + 0.10 * p, delta * 14.0)
					mesh.arm_l.rotation.z = lerp(mesh.arm_l.rotation.z, 0.08 * p, delta * 12.0)
				1:
					wp.rotation_degrees.x = lerp(wp.rotation_degrees.x, 72.0, delta * 18.0)
					wp.rotation_degrees.y = lerp(wp.rotation_degrees.y, -28.0, delta * 18.0)
					wp.rotation_degrees.z = lerp(wp.rotation_degrees.z, 14.0, delta * 18.0)
					mesh.arm_r.rotation.x = lerp(mesh.arm_r.rotation.x, -0.55 * p, delta * 22.0)
					mesh.arm_r.rotation.z = lerp(mesh.arm_r.rotation.z, 0.20 * p, delta * 18.0)
					mesh.rig.rotation.y = lerp(mesh.rig.rotation.y, -0.12 * p, delta * 16.0)
					mesh.head.rotation.y = lerp(mesh.head.rotation.y, -0.18 * p, delta * 14.0)
					mesh.arm_l.rotation.x = lerp(mesh.arm_l.rotation.x, -0.05 + 0.10 * p, delta * 14.0)
					mesh.arm_l.rotation.z = lerp(mesh.arm_l.rotation.z, -0.08 * p, delta * 12.0)
				2:
					wp.rotation_degrees.x = lerp(wp.rotation_degrees.x, 82.0, delta * 18.0)
					wp.rotation_degrees.y = lerp(wp.rotation_degrees.y, 42.0, delta * 18.0)
					wp.rotation_degrees.z = lerp(wp.rotation_degrees.z, -7.0, delta * 18.0)
					mesh.arm_r.rotation.x = lerp(mesh.arm_r.rotation.x, -0.28 * p, delta * 22.0)
					mesh.arm_r.rotation.z = lerp(mesh.arm_r.rotation.z, -0.32 * p, delta * 18.0)
					mesh.rig.rotation.y = lerp(mesh.rig.rotation.y, 0.20 * p, delta * 16.0)
					mesh.head.rotation.y = lerp(mesh.head.rotation.y, 0.25 * p, delta * 14.0)
					mesh.arm_l.rotation.x = lerp(mesh.arm_l.rotation.x, -0.05 + 0.12 * p, delta * 14.0)
					mesh.arm_l.rotation.z = lerp(mesh.arm_l.rotation.z, 0.06 * p, delta * 12.0)
			mesh.rig.rotation.x = lerp(mesh.rig.rotation.x, -0.08 * p, delta * 16.0)
			mesh.body.rotation.x = lerp(mesh.body.rotation.x, -0.05 * p, delta * 14.0)
			mesh.elbow_r.rotation.x = _spring("elbow_r_x", 0.55 * p, 10.0, 0.75, delta)
			mesh.elbow_l.rotation.x = _spring("elbow_l_x", 0.45 * p, 10.0, 0.75, delta)
		elif prog < 0.65:
			# AUTO_ATTACK active: chém — vai xoay trước, khuỷu duỗi 90°→mở, cổ tay dẫn
			if not _slash_spawned:
				_slash_spawned = true
				_spawn_slash(step)
			var p: float = (prog - 0.20) / 0.45
			match step:
				0:
					wp.rotation_degrees.x = lerp(wp.rotation_degrees.x, 112.0, delta * 30.0)
					wp.rotation_degrees.y = lerp(wp.rotation_degrees.y, -22.0, delta * 30.0)
					wp.rotation_degrees.z = lerp(wp.rotation_degrees.z, 16.0, delta * 30.0)
					mesh.arm_r.rotation.x = lerp(mesh.arm_r.rotation.x, 0.85 * p - 0.55 * (1.0 - p), delta * 32.0)
					mesh.arm_r.rotation.z = lerp(mesh.arm_r.rotation.z, 0.10 * sin(p * PI), delta * 26.0)
					mesh.rig.rotation.y = lerp(mesh.rig.rotation.y, -0.18 * sin(p * PI), delta * 20.0)
					mesh.head.rotation.y = lerp(mesh.head.rotation.y, -0.22 * sin(p * PI), delta * 18.0)
					mesh.head.rotation.x = lerp(mesh.head.rotation.x, 0.08 * sin(p * PI), delta * 16.0)
					mesh.arm_l.rotation.x = lerp(mesh.arm_l.rotation.x, 0.15 * sin(p * PI), delta * 16.0)
					mesh.arm_l.rotation.z = lerp(mesh.arm_l.rotation.z, 0.10 * sin(p * PI), delta * 12.0)
					mesh.leg_r.rotation.x = lerp(mesh.leg_r.rotation.x, 0.18 * sin(p * PI), delta * 14.0)
				1:
					wp.rotation_degrees.x = lerp(wp.rotation_degrees.x, 112.0, delta * 30.0)
					wp.rotation_degrees.y = lerp(wp.rotation_degrees.y, 22.0, delta * 30.0)
					wp.rotation_degrees.z = lerp(wp.rotation_degrees.z, -16.0, delta * 30.0)
					mesh.arm_r.rotation.x = lerp(mesh.arm_r.rotation.x, 0.85 * p - 0.55 * (1.0 - p), delta * 32.0)
					mesh.arm_r.rotation.z = lerp(mesh.arm_r.rotation.z, -0.10 * sin(p * PI), delta * 26.0)
					mesh.rig.rotation.y = lerp(mesh.rig.rotation.y, 0.18 * sin(p * PI), delta * 20.0)
					mesh.head.rotation.y = lerp(mesh.head.rotation.y, 0.22 * sin(p * PI), delta * 18.0)
					mesh.head.rotation.x = lerp(mesh.head.rotation.x, 0.08 * sin(p * PI), delta * 16.0)
					mesh.arm_l.rotation.x = lerp(mesh.arm_l.rotation.x, 0.15 * sin(p * PI), delta * 16.0)
					mesh.arm_l.rotation.z = lerp(mesh.arm_l.rotation.z, -0.10 * sin(p * PI), delta * 12.0)
					mesh.leg_l.rotation.x = lerp(mesh.leg_l.rotation.x, 0.18 * sin(p * PI), delta * 14.0)
				2:
					wp.rotation_degrees.x = lerp(wp.rotation_degrees.x, 97.0, delta * 30.0)
					wp.rotation_degrees.y = lerp(wp.rotation_degrees.y, -42.0, delta * 30.0)
					wp.rotation_degrees.z = lerp(wp.rotation_degrees.z, 11.0, delta * 30.0)
					mesh.arm_r.rotation.x = lerp(mesh.arm_r.rotation.x, 0.55 * p - 0.28 * (1.0 - p), delta * 32.0)
					mesh.arm_r.rotation.z = lerp(mesh.arm_r.rotation.z, 0.14 * sin(p * PI), delta * 26.0)
					mesh.rig.rotation.y = lerp(mesh.rig.rotation.y, 0.35 * sin(p * PI), delta * 22.0)
					mesh.head.rotation.y = lerp(mesh.head.rotation.y, 0.30 * sin(p * PI), delta * 20.0)
					mesh.head.rotation.x = lerp(mesh.head.rotation.x, 0.06 * sin(p * PI), delta * 16.0)
					mesh.arm_l.rotation.x = lerp(mesh.arm_l.rotation.x, 0.12 * sin(p * PI), delta * 16.0)
					mesh.arm_l.rotation.z = lerp(mesh.arm_l.rotation.z, 0.08 * sin(p * PI), delta * 12.0)
					mesh.leg_r.rotation.x = lerp(mesh.leg_r.rotation.x, 0.22 * sin(p * PI), delta * 14.0)
			mesh.rig.rotation.x = lerp(mesh.rig.rotation.x, 0.12 * p, delta * 22.0)
			mesh.rig.rotation.z = lerp(mesh.rig.rotation.z, -0.05 * sin(p * PI), delta * 20.0)
			mesh.body.rotation.x = lerp(mesh.body.rotation.x, 0.08 * p, delta * 18.0)
			mesh.elbow_r.rotation.x = _spring("elbow_r_x", 1.15, 12.0, 0.75, delta)
			mesh.elbow_l.rotation.x = _spring("elbow_l_x", 0.95, 12.0, 0.75, delta)
		else:
			# RECOVERY → IDLE: thu kiếm, vai thả, khuỷu gập nhẹ về idle
			var p: float = (prog - 0.65) / 0.35
			wp.rotation_degrees = wp.rotation_degrees.lerp(IDLE_WP, delta * 10.0)
			mesh.rig.rotation.x = lerp(mesh.rig.rotation.x, 0.0, delta * 10.0)
			mesh.rig.rotation.y = lerp(mesh.rig.rotation.y, 0.0, delta * 10.0)
			mesh.rig.rotation.z = lerp(mesh.rig.rotation.z, 0.0, delta * 10.0)
			mesh.body.rotation.x = lerp(mesh.body.rotation.x, 0.0, delta * 10.0)
			mesh.head.rotation.x = lerp(mesh.head.rotation.x, 0.0, delta * 10.0)
			mesh.head.rotation.y = lerp(mesh.head.rotation.y, 0.0, delta * 10.0)
			mesh.arm_r.rotation.x = lerp(mesh.arm_r.rotation.x, -0.06, delta * 10.0)
			mesh.arm_r.rotation.z = lerp(mesh.arm_r.rotation.z, -0.04, delta * 10.0)
			mesh.arm_l.rotation.x = lerp(mesh.arm_l.rotation.x, -0.06, delta * 10.0)
			mesh.arm_l.rotation.z = lerp(mesh.arm_l.rotation.z, 0.04, delta * 10.0)
			mesh.elbow_r.rotation.x = _spring("elbow_r_x", lerp(1.15, 0.45, p), 10.0, 0.75, delta)
			mesh.elbow_l.rotation.x = _spring("elbow_l_x", lerp(0.95, 0.45, p), 10.0, 0.75, delta)
			mesh.leg_l.rotation.x = lerp(mesh.leg_l.rotation.x, 0.02, delta * 10.0)
			mesh.leg_r.rotation.x = lerp(mesh.leg_r.rotation.x, 0.02, delta * 10.0)
			mesh.ankle_l.rotation.x = _spring("ankle_l_x", 0.02, 10.0, 1.0, delta)
			mesh.ankle_r.rotation.x = _spring("ankle_r_x", 0.02, 10.0, 1.0, delta)
			mesh.foot_l.rotation.x = _spring("foot_l_x", 0.0, 7.0, 1.0, delta)
			mesh.foot_r.rotation.x = _spring("foot_r_x", 0.0, 7.0, 1.0, delta)
			if remaining <= 0.0 and player and player.combo_timer <= 0.0:
				player.combo_step = 0

func _spawn_slash(step: int) -> void:
	if not is_instance_valid(mesh) or not is_instance_valid(mesh.weapon_pivot):
		return
	if not player or not player.equipped_weapon:
		return
	var wp := mesh.weapon_pivot
	var is_heavy: bool = player.equipped_weapon.id == "axe" or player.equipped_weapon.id == "pickaxe"
	var is_gs: bool = player.equipped_weapon.id == "iron_greatsword"
	var is_halberd: bool = player.equipped_weapon.id == "iron_halberd"

	if is_heavy:
		var is_axe: bool = player.equipped_weapon.id == "axe"
		var vfx := SlashVFX.new(75.0 if is_axe else 60.0, 0.40 if is_axe else 0.30, 0.10, Color.WHITE)
		wp.add_child(vfx)
		vfx.position = Vector3(0, 0.40, 0)
		vfx.rotation_degrees = Vector3(0, 90, 0)
	elif player.equipped_weapon.id == "iron_sword":
		var vfx := SlashVFX.new(70.0, 0.5, 0.12, Color.WHITE)
		wp.add_child(vfx)
		vfx.position = Vector3(0, 0.40, 0)
		match step:
			0: vfx.rotation_degrees = Vector3(0, 0, 30)
			1: vfx.rotation_degrees = Vector3(0, 0, -30)
			2: vfx.rotation_degrees = Vector3(85, 0, 0)
	elif is_gs:
		var arc: float = 80.0 if step == 0 else 65.0
		var radius: float = 0.55
		var vfx := SlashVFX.new(arc, radius, 0.10, Color(0.85, 0.90, 1.00))
		wp.add_child(vfx)
		vfx.position = Vector3(0, 0.50, 0)
		match step:
			0: vfx.rotation_degrees = Vector3(0, 90, 0)
			1: vfx.rotation_degrees = Vector3(90, 0, 30)
	elif is_halberd:
		var arc: float = 85.0 if step == 0 else 75.0
		var radius: float = 0.55 if step == 0 else 0.60
		var vfx := SlashVFX.new(arc, radius, 0.10, Color(0.55, 0.65, 0.75))
		wp.add_child(vfx)
		vfx.position = Vector3(0, 0.50, 0)
		match step:
			0: vfx.rotation_degrees = Vector3(0, 90, 0)
			1: vfx.rotation_degrees = Vector3(90, 0, 30)
	elif player.equipped_weapon.id == "leather_gloves":
		var vfx := PunchVFX.new(1.0, Color(0.85, 0.72, 0.40))
		wp.add_child(vfx)
		vfx.position = Vector3(0, 0.25, 0.08)