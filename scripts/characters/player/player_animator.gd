class_name PlayerAnimator

## Animator khớp-driven cho rig khối khớp (PlayerBlockMesh).
## Dùng khớp thật: cổ (neck), vai (arm_l/r), khuỷu (elbow_l/r), xương chậu
## (pelvis), hông (leg_l/r), gối (knee_l/r), cổ chân (ankle_l/r), bàn chân
## (foot_l/r). Chuyển động hông→gối→cổ chân được tính từ phase bước để chân
## nhấc lên đúng lúc (logic), các khớp phụ (đầu/balo/thân) chạy theo spring
## (đàn hồi) cho cảm giác trễ tự nhiên.

var walk_cycle_speed: float = 6.5
var sprint_cycle_mult: float = 1.6
var idle_breathe_speed: float = 0.9
var swim_cycle_speed: float = 4.5

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
func _spring(name: String, target: float, freq: float, zeta: float, delta: float) -> float:
	var pos: float = _spos.get(name, target)
	var vel: float = _svel.get(name, 0.0)
	var w: float = TAU * freq
	var st: float = w * w
	var damp: float = 2.0 * zeta * w
	var acc: float = -st * (pos - target) - damp * vel
	vel += acc * delta
	pos += vel * delta
	_spos[name] = pos
	_svel[name] = vel
	return pos

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
			_walk(delta, t, sprint_cycle_mult)
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

# ── Dáng đứng / thư giãn ────────────────────────────────────────────────────
func _idle(delta: float, t: float) -> void:
	var breath: float = sin(t * idle_breathe_speed)
	var shift: float = sin(t * 0.4)
	# Trọng tâm dồn qua lại chậm giữa 2 chân (weight shift qua pelvis)
	mesh.pelvis.position.z = _spring("pelvis_z", shift * 0.02, 2.5, 0.9, delta)
	mesh.pelvis.rotation.z = _spring("pelvis_twist", shift * 0.03, 2.0, 0.8, delta)
	# Nhún thở nhẹ cả cơ thể
	mesh.rig.position.y = _spring("rig_y", 0.02 + abs(breath) * 0.008, 3.0, 1.0, delta)
	mesh.rig.rotation.x = _spring("rig_x", 0.0, 3.0, 1.0, delta)
	# Thân hơi hô hấp, đầu lắc lư đàn hồi
	mesh.body.rotation.x = _spring("body_x", breath * 0.015, 3.0, 0.9, delta)
	mesh.neck.rotation.y = _spring("neck_y", shift * 0.06, 2.0, 0.7, delta)
	mesh.head.rotation.x = _spring("head_x", breath * 0.03, 3.5, 0.9, delta)
	mesh.head.rotation.z = _spring("head_z", sin(t * 0.5) * 0.04, 3.0, 0.8, delta)
	mesh.backpack.position.z = _spring("bp_z", -0.02, 3.0, 1.0, delta)
	# Tay buông thõng, khuỷu hơi cong đàn hồi (vũ khí tự pose tay thì nhường)
	if not _weapon_owns_arms():
		var arm_bob: float = 1.0
		mesh.arm_l.rotation.x = _spring("arm_l_x", (-0.06 + breath * 0.03) * arm_bob, 3.0, 0.9, delta)
		mesh.arm_r.rotation.x = _spring("arm_r_x", (-0.06 + breath * 0.03) * arm_bob, 3.0, 0.9, delta)
		mesh.arm_l.rotation.z = _spring("arm_l_z", (0.04 + breath * 0.02) * arm_bob, 3.0, 0.8, delta)
		mesh.arm_r.rotation.z = _spring("arm_r_z", (-0.04 - breath * 0.02) * arm_bob, 3.0, 0.8, delta)
		_follow_r_elbow(delta)
	# Hông/khuỷu/chân khớp: gối khóa nhẹ, bàn chân tỳ xuống
	mesh.leg_l.rotation.x = _spring("leg_l_x", 0.02, 4.0, 1.0, delta)
	mesh.leg_r.rotation.x = _spring("leg_r_x", 0.02, 4.0, 1.0, delta)
	mesh.knee_l.rotation.x = _spring("knee_l_x", 0.06, 4.0, 1.0, delta)
	mesh.knee_r.rotation.x = _spring("knee_r_x", 0.06, 4.0, 1.0, delta)
	mesh.ankle_l.rotation.x = _spring("ankle_l_x", -0.04, 4.0, 1.0, delta)
	mesh.ankle_r.rotation.x = _spring("ankle_r_x", -0.04, 4.0, 1.0, delta)
	mesh.foot_l.rotation.x = 0.0
	mesh.foot_r.rotation.x = 0.0

# ── Đi bộ / chạy — chân dẫn bởi phase ───────────────────────────────────────
func _walk(delta: float, t: float, mult: float) -> void:
	var cyc: float = t * walk_cycle_speed * mult
	var amp: float = 0.50 + mult * 0.12       # biên độ hông
	var ampx: float = 0.34 + mult * 0.09      # biên độ khuỷu gối
	var lift: float = 0.55 + mult * 0.18      # nhấc đùi khi vung
	# Bước từng chân: sin(ph) < 0 = vung tới, sin(ph) > 0 = chống chân sau
	var ph_l: float = cyc
	var ph_r: float = cyc + PI
	# Hông (thigh): mang đùi theo chu kỳ bước
	var hip_l: float = sin(ph_l) * amp
	var hip_r: float = sin(ph_r) * amp
	# Gối: gập khi chân vung tới để nhấc bàn chân khỏi mặt đất,
	# duỗi gần thẳng khi chân chống sau
	var knee_l: float = lift * max(0.0, -sin(ph_l))
	var knee_r: float = lift * max(0.0, -sin(ph_r))
	# Cổ chân: duỗi mũi chân lúc đạp cuối (toe-off), gập mũi lên lúc vung để không vấp
	var toe_off: float = 0.20
	var flick_l: float = -toe_off * pow(max(0.0, sin(ph_l)), 3.0)
	var flick_r: float = -toe_off * pow(max(0.0, sin(ph_r)), 3.0)
	var dors_l: float = 0.28 * max(0.0, -sin(ph_l))
	var dors_r: float = 0.28 * max(0.0, -sin(ph_r))
	var ankle_l: float = flick_l + dors_l
	var ankle_r: float = flick_r + dors_r

	mesh.leg_l.rotation.x = _spring("leg_l_x", hip_l, 8.0, 1.0, delta)
	mesh.leg_r.rotation.x = _spring("leg_r_x", hip_r, 8.0, 1.0, delta)
	mesh.knee_l.rotation.x = _spring("knee_l_x", knee_l, 8.0, 1.0, delta)
	mesh.knee_r.rotation.x = _spring("knee_r_x", knee_r, 8.0, 1.0, delta)
	mesh.ankle_l.rotation.x = _spring("ankle_l_x", ankle_l, 8.0, 1.0, delta)
	mesh.ankle_r.rotation.x = _spring("ankle_r_x", ankle_r, 8.0, 1.0, delta)
	mesh.foot_l.rotation.x = -ankle_l * 0.35
	mesh.foot_r.rotation.x = -ankle_r * 0.35

	# Nhún theo nhịp: chạm đất ≈ khi chân thẳng (sin gần 0, 2 lần/chu kỳ)
	mesh.rig.position.y = 0.02 + abs(sin(cyc)) * (0.04 + mult * 0.018)
	mesh.rig.rotation.x = _spring("rig_x", -0.05 * mult, 6.0, 0.9, delta)
	mesh.pelvis.rotation.z = _spring("pelvis_twist", sin(cyc) * (0.03 + mult * 0.02), 6.0, 0.8, delta)
	mesh.pelvis.position.z = _spring("pelvis_z", sin(cyc * 0.5) * 0.02, 5.0, 0.9, delta)
	# Thân theo nhịp, đầu lắc đàn hồi ngược lại
	mesh.body.rotation.x = _spring("body_x", -sin(cyc * 0.5) * 0.04, 5.0, 0.9, delta)
	mesh.neck.rotation.y = _spring("neck_y", sin(cyc * 0.5) * 0.10 * mult, 5.0, 0.8, delta)
	mesh.head.rotation.z = _spring("head_z", sin(cyc * 0.5) * 0.05, 5.0, 0.8, delta)
	mesh.head.rotation.x = _spring("head_x", -0.05 * mult, 5.0, 0.9, delta)
	mesh.backpack.position.z = _spring("bp_z", -0.02 + abs(sin(cyc * 0.5)) * 0.015, 5.0, 0.9, delta)
	mesh.backpack.rotation.x += sin(cyc * 0.5) * 0.04

	# Tay đánh nhịp chéo với chân đối diện (vũ khí tự pose tay thì nhường)
	if not _weapon_owns_arms():
		var arm_swing: float = 0.28 + mult * 0.08
		mesh.arm_l.rotation.x = _spring("arm_l_x", -hip_r * arm_swing / amp, 8.0, 1.0, delta)
		mesh.arm_r.rotation.x = _spring("arm_r_x", -hip_l * arm_swing / amp, 8.0, 1.0, delta)
		mesh.arm_l.rotation.z = _spring("arm_l_z", 0.04, 6.0, 1.0, delta)
		mesh.arm_r.rotation.z = _spring("arm_r_z", -0.04, 6.0, 1.0, delta)
		_follow_r_elbow(delta)
		_follow_l_elbow(delta)

# ── Ngồi xổm / lẻn ─────────────────────────────────────────────────────────
func _crouch(delta: float, t: float) -> void:
	var cyc: float = t * walk_cycle_speed * 0.5
	# Gập sâu hông + gối: đùi chếch tới, mông hạ thấp
	mesh.rig.position.y = _spring("rig_y", -0.24, 9.0, 1.0, delta)
	mesh.pelvis.rotation.x = _spring("pelvis_x", -0.35, 8.0, 1.0, delta)
	mesh.rig.rotation.x = _spring("rig_x", 0.18, 8.0, 0.9, delta)
	mesh.body.rotation.x = _spring("body_x", 0.14, 7.0, 0.9, delta)
	mesh.leg_l.rotation.x = _spring("leg_l_x", -0.85 + sin(cyc) * 0.16, 8.0, 1.0, delta)
	mesh.leg_r.rotation.x = _spring("leg_r_x", -0.85 + sin(cyc + PI) * 0.16, 8.0, 1.0, delta)
	mesh.knee_l.rotation.x = _spring("knee_l_x", 1.35 + max(0.0, -sin(cyc)) * 0.15, 8.0, 1.0, delta)
	mesh.knee_r.rotation.x = _spring("knee_r_x", 1.35 + max(0.0, -sin(cyc + PI)) * 0.15, 8.0, 1.0, delta)
	# Bàn chân giữ bằng phẳng với mặt đất
	mesh.ankle_l.rotation.x = _spring("ankle_l_x", -(mesh.leg_l.rotation.x + mesh.knee_l.rotation.x) * 0.45, 8.0, 1.0, delta)
	mesh.ankle_r.rotation.x = _spring("ankle_r_x", -(mesh.leg_r.rotation.x + mesh.knee_r.rotation.x) * 0.45, 8.0, 1.0, delta)
	mesh.foot_l.rotation.x = 0.0
	mesh.foot_r.rotation.x = 0.0
	mesh.neck.rotation.y = _spring("neck_y", sin(t * 0.2) * 0.08, 4.0, 0.8, delta)
	mesh.head.rotation.x = _spring("head_x", -0.35, 6.0, 0.9, delta)
	mesh.backpack.position.z = _spring("bp_z", -0.06, 5.0, 1.0, delta)
	if not _weapon_owns_arms():
		mesh.arm_l.rotation.x = _spring("arm_l_x", sin(cyc + PI) * 0.20, 7.0, 1.0, delta)
		mesh.arm_r.rotation.x = _spring("arm_r_x", sin(cyc) * 0.20, 7.0, 1.0, delta)
		mesh.arm_l.rotation.z = _spring("arm_l_z", 0.18, 6.0, 1.0, delta)
		mesh.arm_r.rotation.z = _spring("arm_r_z", -0.18, 6.0, 1.0, delta)
		_follow_l_elbow(delta)
		_follow_r_elbow(delta)

# ── Lao nhanh ──────────────────────────────────────────────────────────────
func _dash(delta: float, _t: float) -> void:
	mesh.rig.position.y = _spring("rig_y", 0.02, 12.0, 1.0, delta)
	mesh.rig.rotation.x = _spring("rig_x", 0.30, 12.0, 0.9, delta)
	mesh.pelvis.rotation.x = _spring("pelvis_x", -0.20, 12.0, 0.9, delta)
	mesh.body.rotation.x = _spring("body_x", 0.20, 11.0, 0.9, delta)
	mesh.head.rotation.x = _spring("head_x", -0.30, 11.0, 0.9, delta)
	mesh.neck.rotation.x = _spring("neck_x", 0.12, 11.0, 0.9, delta)
	mesh.backpack.position.z = _spring("bp_z", -0.06, 10.0, 1.0, delta)
	if not _weapon_owns_arms():
		mesh.arm_l.rotation.x = _spring("arm_l_x", -0.40, 12.0, 1.0, delta)
		mesh.arm_r.rotation.x = _spring("arm_r_x", -0.40, 12.0, 1.0, delta)
		mesh.arm_l.rotation.z = _spring("arm_l_z", 0.10, 10.0, 1.0, delta)
		mesh.arm_r.rotation.z = _spring("arm_r_z", -0.10, 10.0, 1.0, delta)
		_follow_l_elbow(delta)
		_follow_r_elbow(delta)
	# Chân chùng nhẹ, gối gập để chạy nước rút
	mesh.leg_l.rotation.x = _spring("leg_l_x", -0.50, 12.0, 1.0, delta)
	mesh.leg_r.rotation.x = _spring("leg_r_x", -0.50, 12.0, 1.0, delta)
	mesh.knee_l.rotation.x = _spring("knee_l_x", 0.55, 12.0, 1.0, delta)
	mesh.knee_r.rotation.x = _spring("knee_r_x", 0.55, 12.0, 1.0, delta)
	mesh.ankle_l.rotation.x = _spring("ankle_l_x", 0.15, 12.0, 1.0, delta)
	mesh.ankle_r.rotation.x = _spring("ankle_r_x", 0.15, 12.0, 1.0, delta)
	mesh.foot_l.rotation.x = 0.0
	mesh.foot_r.rotation.x = 0.0

# ── Nhảy / rơi ─────────────────────────────────────────────────────────────
func _air(delta: float, t: float, rising: bool) -> void:
	var tuck: float
	if rising:
		tuck = clamp(base.velocity.y / base._jump_v, 0.0, 1.0)
	else:
		tuck = clamp(1.0 + base.velocity.y / base._jump_v, 0.0, 1.0) * 0.5
	mesh.rig.position.y = _spring("rig_y", 0.02, 6.0, 1.0, delta)
	mesh.rig.rotation.x = _spring("rig_x", 0.02, 7.0, 0.9, delta)
	# Thân gập nhẹ, đầu ngửa lên để nhìn đường rơi
	mesh.body.rotation.x = _spring("body_x", -0.04 + tuck * 0.10, 7.0, 0.9, delta)
	mesh.pelvis.rotation.x = _spring("pelvis_x", 0.12 + tuck * 0.15, 7.0, 0.9, delta)
	mesh.head.rotation.x = _spring("head_x", -0.10 + tuck * 0.06, 6.0, 0.9, delta)
	mesh.neck.rotation.x = _spring("neck_x", 0.05, 6.0, 0.9, delta)
	mesh.backpack.position.z = _spring("bp_z", -0.04 - tuck * 0.03, 7.0, 1.0, delta)
	if not _weapon_owns_arms():
		# Tay xoè ra cân bằng
		mesh.arm_l.rotation.x = _spring("arm_l_x", -0.50 - tuck * 0.25, 8.0, 0.9, delta)
		mesh.arm_r.rotation.x = _spring("arm_r_x", -0.50 - tuck * 0.25, 8.0, 0.9, delta)
		mesh.arm_l.rotation.z = _spring("arm_l_z", 0.30 + tuck * 0.20, 7.0, 0.9, delta)
		mesh.arm_r.rotation.z = _spring("arm_r_z", -0.30 - tuck * 0.20, 7.0, 0.9, delta)
		mesh.elbow_l.rotation.x = _spring("elbow_l_x", -0.45 - tuck * 0.20, 7.0, 0.9, delta)
		mesh.elbow_r.rotation.x = _spring("elbow_r_x", -0.45 - tuck * 0.20, 7.0, 0.9, delta)
	# Hông tới + gối gập tối đa khi nhảy (gập bụng), duỗi khi rơi chậm
	mesh.leg_l.rotation.x = _spring("leg_l_x", -0.30 - tuck * 0.35, 9.0, 1.0, delta)
	mesh.leg_r.rotation.x = _spring("leg_r_x", -0.30 - tuck * 0.35, 9.0, 1.0, delta)
	mesh.knee_l.rotation.x = _spring("knee_l_x", 0.25 + tuck * 0.80, 9.0, 1.0, delta)
	mesh.knee_r.rotation.x = _spring("knee_r_x", 0.25 + tuck * 0.80, 9.0, 1.0, delta)
	# Cổ chân cân bằng mũi chân
	mesh.ankle_l.rotation.x = _spring("ankle_l_x", -0.10 - tuck * 0.25, 8.0, 1.0, delta)
	mesh.ankle_r.rotation.x = _spring("ankle_r_x", -0.10 - tuck * 0.25, 8.0, 1.0, delta)
	mesh.foot_l.rotation.x = _spring("foot_l_x", 0.05, 6.0, 1.0, delta)
	mesh.foot_r.rotation.x = _spring("foot_r_x", 0.05, 6.0, 1.0, delta)

# ── Bơi ────────────────────────────────────────────────────────────────────
func _swim(delta: float, t: float) -> void:
	var cyc: float = t * swim_cycle_speed
	mesh.rig.position.y = _spring("rig_y", 0.02, 6.0, 1.0, delta)
	mesh.rig.rotation.x = _spring("rig_x", 0.18, 7.0, 0.9, delta)
	mesh.pelvis.rotation.x = _spring("pelvis_x", 0.10, 7.0, 0.9, delta)
	mesh.body.rotation.x = sin(cyc * 0.5) * 0.06 + 0.10
	mesh.head.rotation.x = _spring("head_x", -0.12, 6.0, 0.9, delta)
	mesh.neck.rotation.x = _spring("neck_x", 0.06, 6.0, 0.9, delta)
	mesh.neck.rotation.y = _spring("neck_y", sin(cyc * 0.5) * 0.06, 5.0, 0.8, delta)
	mesh.backpack.position.z = _spring("bp_z", -0.04, 5.0, 1.0, delta)
	# Quạt tay sang hai bên (vũ khí tự pose tay thì nhường)
	if not _weapon_owns_arms():
		mesh.arm_l.rotation.x = _spring("arm_l_x", sin(cyc + PI * 0.5) * 0.60, 7.0, 0.9, delta)
		mesh.arm_r.rotation.x = _spring("arm_r_x", sin(cyc - PI * 0.5) * 0.60, 7.0, 0.9, delta)
		mesh.arm_l.rotation.z = _spring("arm_l_z", 0.30, 6.0, 0.9, delta)
		mesh.arm_r.rotation.z = _spring("arm_r_z", -0.30, 6.0, 0.9, delta)
		mesh.elbow_l.rotation.x = _spring("elbow_l_x", -0.40, 7.0, 0.9, delta)
		mesh.elbow_r.rotation.x = _spring("elbow_r_x", -0.40, 7.0, 0.9, delta)
	# Đạp chân kiểu ếch/sóng: hông + gối vẫy ngược phase, cổ chân duỗi đạp
	var kick_l: float = sin(cyc + PI * 0.5) * 0.50
	var kick_r: float = sin(cyc - PI * 0.5) * 0.50
	mesh.leg_l.rotation.x = _spring("leg_l_x", kick_l, 7.0, 0.9, delta)
	mesh.leg_r.rotation.x = _spring("leg_r_x", kick_r, 7.0, 0.9, delta)
	mesh.knee_l.rotation.x = _spring("knee_l_x", max(0.0, -kick_l) * 0.9, 7.0, 0.9, delta)
	mesh.knee_r.rotation.x = _spring("knee_r_x", max(0.0, -kick_r) * 0.9, 7.0, 0.9, delta)
	mesh.ankle_l.rotation.x = _spring("ankle_l_x", -kick_l * 0.4 - 0.15, 7.0, 0.9, delta)
	mesh.ankle_r.rotation.x = _spring("ankle_r_x", -kick_r * 0.4 - 0.15, 7.0, 0.9, delta)
	mesh.foot_l.rotation.x = _spring("foot_l_x", -0.2, 6.0, 1.0, delta)
	mesh.foot_r.rotation.x = _spring("foot_r_x", -0.2, 6.0, 1.0, delta)
	var kick: float = abs(sin(cyc * 1.5))
	mesh.rig.position.y += kick * 0.02

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
	mesh.ankle_l.rotation.x = _spring("ankle_l_x", -0.10, 10.0, 1.0, delta)
	mesh.ankle_r.rotation.x = _spring("ankle_r_x", -0.10, 10.0, 1.0, delta)
	mesh.foot_l.rotation.x = 0.0
	mesh.foot_r.rotation.x = 0.0

# ── Chết / ngã ─────────────────────────────────────────────────────────────
func _dead(delta: float, t: float) -> void:
	var prog: float = 1.0 - (base._death_timer / 1.8)
	if prog < 0.30:
		var p: float = prog / 0.30
		mesh.rig.rotation.x = lerp(mesh.rig.rotation.x, p * 0.50, delta * 16.0)
		mesh.rig.rotation.z = lerp(mesh.rig.rotation.z, p * (-0.10), delta * 14.0)
		mesh.head.rotation.x = lerp(mesh.head.rotation.x, -p * 0.20, delta * 14.0)
		mesh.knee_l.rotation.x = lerp(mesh.knee_l.rotation.x, 0.20, delta * 12.0)
		mesh.knee_r.rotation.x = lerp(mesh.knee_r.rotation.x, 0.20, delta * 12.0)
	elif prog < 0.70:
		var p: float = (prog - 0.30) / 0.40
		mesh.rig.rotation.x = lerp(mesh.rig.rotation.x, 0.50 + p * 0.60, delta * 14.0)
		mesh.rig.position.y = lerp(mesh.rig.position.y, -p * 0.10, delta * 10.0)
		mesh.body.rotation.x = lerp(mesh.body.rotation.x, 0.20, delta * 10.0)
		mesh.arm_l.rotation.x = lerp(mesh.arm_l.rotation.x, -0.25, delta * 10.0)
		mesh.arm_r.rotation.x = lerp(mesh.arm_r.rotation.x, -0.25, delta * 10.0)
		mesh.elbow_l.rotation.x = lerp(mesh.elbow_l.rotation.x, -0.50, delta * 10.0)
		mesh.elbow_r.rotation.x = lerp(mesh.elbow_r.rotation.x, -0.50, delta * 10.0)
	else:
		mesh.rig.rotation.x = lerp(mesh.rig.rotation.x, 1.10, delta * 8.0)
		mesh.rig.position.y = lerp(mesh.rig.position.y, -0.10, delta * 6.0)
	mesh.rig.position.y = lerp(mesh.rig.position.y, 0.02, delta * 8.0)
	mesh.foot_l.rotation.x = 0.0
	mesh.foot_r.rotation.x = 0.0

# ── Khuỷu tay theo đà quét của vai (elastic follow-through) ─────────────────
## Khi vai chuyển (arm.rotation.x chênh khỏi buông thõng), khuỷu tự gập/duỗi
## theo quán tính → cánh tay có độ trễ đàn hồi thay vì cứng đờ.
func _elbow_bend_target(arm_angle: float) -> float:
	var bend: float = -0.35 - arm_angle * 0.8
	return clamp(bend, -0.95, 0.65)

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
			_follow_r_elbow(delta)
			_follow_l_elbow(delta)
			if remaining <= 0.0 and player and player.combo_timer <= 0.0:
				player.combo_step = 0

	else:
		if prog < 0.25:
			var p: float = prog / 0.25
			match step:
				0:
					wp.rotation_degrees.x = lerp(wp.rotation_degrees.x, 72.0, delta * 18.0)
					wp.rotation_degrees.y = lerp(wp.rotation_degrees.y, 28.0, delta * 18.0)
					wp.rotation_degrees.z = lerp(wp.rotation_degrees.z, -14.0, delta * 18.0)
					mesh.arm_r.rotation.x = lerp(mesh.arm_r.rotation.x, -0.55 * p, delta * 22.0)
					mesh.arm_r.rotation.z = lerp(mesh.arm_r.rotation.z, -0.20 * p, delta * 18.0)
					mesh.rig.rotation.y = lerp(mesh.rig.rotation.y, 0.12 * p, delta * 16.0)
					mesh.head.rotation.y = lerp(mesh.head.rotation.y, 0.18 * p, delta * 14.0)
					mesh.arm_l.rotation.x = lerp(mesh.arm_l.rotation.x, 0.12 * p, delta * 14.0)
				1:
					wp.rotation_degrees.x = lerp(wp.rotation_degrees.x, 72.0, delta * 18.0)
					wp.rotation_degrees.y = lerp(wp.rotation_degrees.y, -28.0, delta * 18.0)
					wp.rotation_degrees.z = lerp(wp.rotation_degrees.z, 14.0, delta * 18.0)
					mesh.arm_r.rotation.x = lerp(mesh.arm_r.rotation.x, -0.55 * p, delta * 22.0)
					mesh.arm_r.rotation.z = lerp(mesh.arm_r.rotation.z, 0.20 * p, delta * 18.0)
					mesh.rig.rotation.y = lerp(mesh.rig.rotation.y, -0.12 * p, delta * 16.0)
					mesh.head.rotation.y = lerp(mesh.head.rotation.y, -0.18 * p, delta * 14.0)
					mesh.arm_l.rotation.x = lerp(mesh.arm_l.rotation.x, 0.12 * p, delta * 14.0)
				2:
					wp.rotation_degrees.x = lerp(wp.rotation_degrees.x, 82.0, delta * 18.0)
					wp.rotation_degrees.y = lerp(wp.rotation_degrees.y, 42.0, delta * 18.0)
					wp.rotation_degrees.z = lerp(wp.rotation_degrees.z, -7.0, delta * 18.0)
					mesh.arm_r.rotation.x = lerp(mesh.arm_r.rotation.x, -0.28 * p, delta * 22.0)
					mesh.arm_r.rotation.z = lerp(mesh.arm_r.rotation.z, -0.32 * p, delta * 18.0)
					mesh.rig.rotation.y = lerp(mesh.rig.rotation.y, 0.20 * p, delta * 16.0)
					mesh.head.rotation.y = lerp(mesh.head.rotation.y, 0.25 * p, delta * 14.0)
					mesh.arm_l.rotation.x = lerp(mesh.arm_l.rotation.x, 0.16 * p, delta * 14.0)
			mesh.rig.rotation.x = lerp(mesh.rig.rotation.x, -0.08 * p, delta * 16.0)
			mesh.body.rotation.x = lerp(mesh.body.rotation.x, -0.05 * p, delta * 14.0)
			mesh.elbow_r.rotation.x = _spring("elbow_r_x", 0.55 * p, 10.0, 0.75, delta)
		elif prog < 0.70:
			if not _slash_spawned:
				_slash_spawned = true
				_spawn_slash(step)
			var p: float = (prog - 0.25) / 0.45
			match step:
				0:
					wp.rotation_degrees.x = lerp(wp.rotation_degrees.x, 112.0, delta * 30.0)
					wp.rotation_degrees.y = lerp(wp.rotation_degrees.y, -22.0, delta * 30.0)
					wp.rotation_degrees.z = lerp(wp.rotation_degrees.z, 16.0, delta * 30.0)
					mesh.arm_r.rotation.x = lerp(mesh.arm_r.rotation.x, 0.75 * p - 0.55 * (1.0 - p), delta * 32.0)
					mesh.arm_r.rotation.z = lerp(mesh.arm_r.rotation.z, 0.10 * sin(p * PI), delta * 26.0)
					mesh.rig.rotation.y = lerp(mesh.rig.rotation.y, -0.18 * sin(p * PI), delta * 20.0)
					mesh.head.rotation.y = lerp(mesh.head.rotation.y, -0.22 * sin(p * PI), delta * 18.0)
					mesh.head.rotation.x = lerp(mesh.head.rotation.x, 0.08 * sin(p * PI), delta * 16.0)
					mesh.arm_l.rotation.x = lerp(mesh.arm_l.rotation.x, -0.18 * sin(p * PI), delta * 16.0)
					mesh.leg_r.rotation.x = lerp(mesh.leg_r.rotation.x, 0.18 * sin(p * PI), delta * 14.0)
				1:
					wp.rotation_degrees.x = lerp(wp.rotation_degrees.x, 112.0, delta * 30.0)
					wp.rotation_degrees.y = lerp(wp.rotation_degrees.y, 22.0, delta * 30.0)
					wp.rotation_degrees.z = lerp(wp.rotation_degrees.z, -16.0, delta * 30.0)
					mesh.arm_r.rotation.x = lerp(mesh.arm_r.rotation.x, 0.75 * p - 0.55 * (1.0 - p), delta * 32.0)
					mesh.arm_r.rotation.z = lerp(mesh.arm_r.rotation.z, -0.10 * sin(p * PI), delta * 26.0)
					mesh.rig.rotation.y = lerp(mesh.rig.rotation.y, 0.18 * sin(p * PI), delta * 20.0)
					mesh.head.rotation.y = lerp(mesh.head.rotation.y, 0.22 * sin(p * PI), delta * 18.0)
					mesh.head.rotation.x = lerp(mesh.head.rotation.x, 0.08 * sin(p * PI), delta * 16.0)
					mesh.arm_l.rotation.x = lerp(mesh.arm_l.rotation.x, -0.18 * sin(p * PI), delta * 16.0)
					mesh.leg_l.rotation.x = lerp(mesh.leg_l.rotation.x, 0.18 * sin(p * PI), delta * 14.0)
				2:
					wp.rotation_degrees.x = lerp(wp.rotation_degrees.x, 97.0, delta * 30.0)
					wp.rotation_degrees.y = lerp(wp.rotation_degrees.y, -42.0, delta * 30.0)
					wp.rotation_degrees.z = lerp(wp.rotation_degrees.z, 11.0, delta * 30.0)
					mesh.arm_r.rotation.x = lerp(mesh.arm_r.rotation.x, 0.45 * p - 0.28 * (1.0 - p), delta * 32.0)
					mesh.arm_r.rotation.z = lerp(mesh.arm_r.rotation.z, 0.14 * sin(p * PI), delta * 26.0)
					mesh.rig.rotation.y = lerp(mesh.rig.rotation.y, 0.45 * sin(p * PI), delta * 22.0)
					mesh.head.rotation.y = lerp(mesh.head.rotation.y, 0.38 * sin(p * PI), delta * 20.0)
					mesh.head.rotation.x = lerp(mesh.head.rotation.x, 0.06 * sin(p * PI), delta * 16.0)
					mesh.arm_l.rotation.x = lerp(mesh.arm_l.rotation.x, -0.22 * sin(p * PI), delta * 16.0)
					mesh.leg_r.rotation.x = lerp(mesh.leg_r.rotation.x, 0.22 * sin(p * PI), delta * 14.0)
			mesh.rig.rotation.x = lerp(mesh.rig.rotation.x, 0.12 * p, delta * 22.0)
			mesh.rig.rotation.z = lerp(mesh.rig.rotation.z, -0.05 * sin(p * PI), delta * 20.0)
			mesh.body.rotation.x = lerp(mesh.body.rotation.x, 0.08 * p, delta * 18.0)
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
			_follow_r_elbow(delta)
			_follow_l_elbow(delta)
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