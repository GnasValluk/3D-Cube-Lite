## PlayerAnimator – Layered procedural animation cho PlayerMesh blockout soulslike.
## Lớp Base: locomotion (pelvis lead, thigh/calf so le, foot roles, spine counter-rotation).
## Lớp Upper: attack whip-chain qua Pelvis→Spine→Clavicle→UpperArm→Forearm→Hand→Weapon
##           với choreography xoay hông/thân theo nhịp chém.
## Lớp Additive: hit reaction, breathing, blink, gaze, jaw.
## Giữ nguyên API setup()/animate() và toàn bộ curve vũ khí cũ (cảm giác chơi không đổi).
class_name PlayerAnimator

var walk_cycle_speed: float = 3.2
var sprint_cycle_mult: float = 1.7
var idle_breathe_speed: float = 0.9
var swim_cycle_speed: float = 4.5

var mesh: PlayerMesh
var base: CharacterBase
var player: PlayerCharacter
var _slash_spawned: bool = false
var _last_remaining: float = 0.0

# Cache Node3D reference cho mỗi xương — tránh dict.get(name)+cast mỗi frame
# (animate() chạm ~200 xương/lần gọi; việc tra cứu dict × Node3D cast là hot path).
var _bones: Dictionary = {}

# State tracking cho dash (thời điểm bắt đầu roll)
var _last_state: CharacterBase.State = CharacterBase.State.IDLE
var _dash_t0: float = 0.0

func setup(m: PlayerMesh, b: CharacterBase) -> void:
	mesh = m
	base = b
	player = b as PlayerCharacter

func _bone(name: String) -> Node3D:
	var cached: Node3D = _bones.get(name) as Node3D
	if cached != null:
		return cached
	if mesh == null:
		return null
	var n := mesh.bones.get(name) as Node3D
	_bones[name] = n
	return n

func _lerp_rot(node: Node3D, axis: int, target: float, rate: float, delta: float) -> void:
	if node == null:
		return
	var cur := node.rotation
	match axis:
		0: cur.x = lerp(cur.x, target, clamp(rate * delta, 0.0, 1.0))
		1: cur.y = lerp(cur.y, target, clamp(rate * delta, 0.0, 1.0))
		2: cur.z = lerp(cur.z, target, clamp(rate * delta, 0.0, 1.0))
	node.rotation = cur

func animate(delta: float) -> void:
	if mesh == null or base == null:
		return
	var t: float = base._time
	# Landing soft/heavy: đo mức rơi qua biến thiên _fall_peak (FALL → trên đất)
	if base._state == CharacterBase.State.FALL:
		_fall_peak = maxf(_fall_peak, base.global_position.y)
	if _last_state == CharacterBase.State.FALL and base._state != CharacterBase.State.FALL and base.is_on_floor():
		_land_intensity = clampf(-base.velocity.y / (1.1 * base._jump_v), 0.0, 1.0)
		_land_t = 0.0
	_land_t += delta
	if base._state != _last_state:
		if base._state == CharacterBase.State.DASH:
			_dash_t0 = t
		_on_state_changed(base._state)
		_last_state = base._state
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
		CharacterBase.State.EAT, CharacterBase.State.DEVOUR:
			_eat(delta, t)
		_:
			_idle(delta, t)
	_facial_loop(delta, t)

## Reset gait machine mỗi khi state locomotion đổi — khởi động Start phase.
func _on_state_changed(state: CharacterBase.State) -> void:
	match state:
		CharacterBase.State.WALK:
			_gait = 1
			_start_t = 0.0
			_stop_t = 0.0
		CharacterBase.State.SPRINT:
			_gait = 2
			_start_t = 0.0
			_stop_t = 0.0
		CharacterBase.State.CROUCH:
			_gait = 3
			_start_t = 0.0
			_stop_t = 0.0
		CharacterBase.State.JUMP:
			_gait = 0
			_jump_t0 = base._time if base != null else 0.0
			_fall_peak = base.global_position.y if base != null else 0.0
		_:
			_gait = 0
			_start_t = 1.0

# ── Layers: arm chain (whip) ────────────────────────────────────────────────
# Target áp lên upper_arm; clavicle/forearm/hand chia phần với tốc độ tăng dần
# theo khớp → hiệu ứng sóng (mỗi khâu sau vận tốc góc lớn hơn).
func _arm_chain(side: String, pitch: float, roll: float, rate: float, delta: float) -> void:
	var cl: Node3D = _bone("clavicle_%s" % side)
	var up: Node3D = _bone("upper_arm_%s" % side)
	var fo: Node3D = _bone("forearm_%s" % side)
	var ha: Node3D = _bone("hand_%s" % side)
	_lerp_rot(cl, 0, pitch * 0.28, rate * 0.7, delta)
	_lerp_rot(up, 0, pitch * 0.72, rate * 1.1, delta)
	var elbow_bend: float = -abs(pitch) * 0.30
	_lerp_rot(fo, 0, pitch * 0.30 + elbow_bend, rate * 1.5, delta)
	_lerp_rot(ha, 0, pitch * 0.18, rate * 1.9, delta)
	_lerp_rot(cl, 2, roll * 0.70, rate * 0.8, delta)
	_lerp_rot(up, 2, roll * 0.45, rate * 1.2, delta)

# ── Layers: legs (foot plant + knee bend) ───────────────────────────────────
func _leg_cycle(side: String, swing: float, bend: float, foot_plant: float, rate: float, delta: float) -> void:
	var th: Node3D = _bone("thigh_%s" % side)
	var ca: Node3D = _bone("calf_%s" % side)
	var fo: Node3D = _bone("foot_%s" % side)
	var to: Node3D = _bone("toe_%s" % side)
	_lerp_rot(th, 0, swing, rate, delta)
	_lerp_rot(ca, 0, bend, rate * 1.15, delta)
	_lerp_rot(fo, 0, foot_plant, rate * 1.3, delta)
	_lerp_rot(to, 0, foot_plant * 0.4, rate * 1.3, delta)

# ═══ NEW JOINT ENGINE (khối lượng + trọng lực + chân IK) ═══════════════════
# Thay thế cách "lerp trực tiếp theo target giả" bằng:
#   1) Spring-damper (con lắc khối lượng) cho mọi khớp → có quán tính/trễ.
#   2) IK 2 xương analytic (đùi–ống) ghim bàn chân xuống mặt đất khi
#      trong pha stance → chân không trượt dù pelvis di chuyển.
#   3) Gait phase machine tách Start/Loop/Stop theo chân trụ.

const _FEMUR := 0.48
const _TIBIA := 0.48
const _STANCE_WALK := 0.60
const _STANCE_RUN := 0.40
const _STANCE_CROUCH := 0.70
const _STEP_WALK := 0.55
const _STEP_RUN := 0.95
const _STEP_CROUCH := 0.40

var _sp_val: Dictionary = {}
var _sp_vel: Dictionary = {}

var _step_phase: float = 0.0
var _step_speed: float = 0.0
var _plant_l := Vector3.ZERO
var _plant_r := Vector3.ZERO
var _prev_stance_l := false
var _prev_stance_r := false
var _gait := 0            # 0 none / 1 walk / 2 run / 3 crouch
var _start_t := 1.0       # anticipation tiến trình (1 = đã xong)
var _stop_t := 0.0        # brake tiến trình (0 = chưa, 1 = đã đứng hẳn)
var _mv_dir := Vector3.FORWARD
var _fall_peak := 0.0     # độ cao rơi (để phân degree landing)
var _jump_t0 := 0.0
var _land_intensity := 0.0
var _land_t := 99.0

func _springy(key: String, target: float, k: float, c: float, delta: float) -> float:
	# Spring-damper: a = k*(target) - c*u ; v += a*dt ; x += v*dt
	var v: float = _sp_val.get(key, 0.0)
	var u: float = _sp_vel.get(key, 0.0)
	var a: float = k * (target - v) - c * u
	u += a * delta
	v += u * delta
	_sp_val[key] = v
	_sp_vel[key] = u
	return v

func _set_axis(node: Node3D, axis: int, val: float) -> void:
	if node == null:
		return
	var r := node.rotation
	match axis:
		0: r.x = val
		1: r.y = val
		2: r.z = val
	node.rotation = r

## Khớp chạy bằng spring-damper thật (quán tính/trễ theo mass), thay lerp target.
func _spring_rot(node: Node3D, axis: int, target: float, k: float, c: float, delta: float) -> void:
	if node == null:
		return
	var key := "%s_%d" % [node.name, axis]
	var v: float = _springy(key, target, k, c, delta)
	_set_axis(node, axis, v)

func _step_phase_of(side: String) -> float:
	# Mỗi chân có phase riêng trong [0,1), lệch nửa chu kỳ.
	var base_p: float = fmod(_step_phase, 1.0)
	if side == "l":
		return base_p
	return fmod(base_p + 0.5, 1.0)

func _foot_stance_frac() -> float:
	match _gait:
		2: return _STANCE_RUN
		3: return _STANCE_CROUCH
		_: return _STANCE_WALK

func _foot_step_len() -> float:
	match _gait:
		2: return _STEP_RUN
		3: return _STEP_CROUCH
		_: return _STEP_WALK

func _move_dir() -> Vector3:
	if base == null:
		return Vector3.FORWARD
	var vx := base.velocity
	var d := Vector3(vx.x, 0.0, vx.z)
	if d.length_squared() > 0.0001:
		return d.normalized()
	return -(base.global_transform.basis.z)

## IK 2 xương analytic: ghim ankle_local trong khung pelvis.
## Knee luôn bẻ về hướng DI CHUYỂN (forward -Z local của khung pelvis),
## shin ngả sau → dáng chạy tự nhiên. Chỉ dùng rotation.x cho thigh (swing)
## và calf (bend), tránh twist xuất hiện khi decompose quaternion.
func _leg_ik(side: String, ankle_local: Vector3) -> void:
	var th: Node3D = _bone("thigh_%s" % side)
	var ca: Node3D = _bone("calf_%s" % side)
	if th == null or ca == null:
		return
	var hip := Vector3(-0.10 if side == "l" else 0.10, -0.045, 0.0)
	var ab := ankle_local - hip
	var d := ab.length()
	if d < 0.0001:
		return
	var l1 := _FEMUR
	var l2 := _TIBIA
	var d_clamped: float = clampf(d, (l1 - l2) * 0.999, (l1 + l2) * 0.999)
	var u: Vector3 = ab / d_clamped
	# perp hướng ra ngoài mặt phẳng chứa u; ép knee về phía forward (-Z local)
	var lat := Vector3(-1.0 if side == "l" else 1.0, 0.0, 0.0)
	var perp: Vector3 = u.cross(lat)
	if perp.length() < 0.0001:
		perp = Vector3(0, 0, -1)
	perp = perp.normalized()
	if perp.z > 0.0:
		perp = -perp
	var aa: float = (l1 * l1 - l2 * l2 + d_clamped * d_clamped) / (2.0 * d_clamped)
	var h: float = sqrt(maxf(l1 * l1 - aa * aa, 0.0))
	var knee: Vector3 = hip + u * aa + perp * h
	var dir_th := (knee - hip).normalized()
	var dir_ca := (ankle_local - knee).normalized()
	# Swing quanh axis X: dir_th.y = -cos, dir_th.z = -sin (forward = -Z)
	th.rotation = Vector3(atan2(-dir_th.z, -dir_th.y), 0.0, atan2(dir_th.x, -dir_th.y) * 0.5)
	# Bend calf trong frame local của thigh (un-rotate theo th.rotation)
	var inv_th: Quaternion = Basis.from_euler(th.rotation).get_rotation_quaternion().inverse()
	var dir_l: Vector3 = inv_th * dir_ca
	ca.rotation = Vector3(atan2(-dir_l.z, -dir_l.y), 0.0, 0.0)

func _ankle_world_ground() -> float:
	# Bàn chân pivot (foot) rest: pelvis 0.92 - hip 0.045 - femur 0.48 - tibia 0.48 = -0.085.
	# Target ankle cách mặt đất 0.15 → gap hông 0.725 so leg 0.96 → dư ~0.63 bán kính
	# tay với nên bước được sải rộng mà bàn chân vẫn gần chạm đất (gót cách ~3cm).
	if base == null:
		return 0.0
	return base.global_position.y + 0.15

func _foot_land_target(side: String) -> Vector3:
	# Điểm tiếp đất MỚI (world) cho foot của 1 bên. Dùng cho cả swing ease + lock-onset.
	var right := _move_dir().cross(Vector3.UP).normalized()
	var lat := -right * 0.10 if side == "l" else right * 0.10
	var hip_w: Vector3
	if base != null:
		hip_w = base.global_position
	else:
		hip_w = Vector3.ZERO
	var land := hip_w + lat + _mv_dir * _foot_step_len() * 0.5
	land.y = _ankle_world_ground()
	# Bước Start: compensating step dài hơn để rút chân trụ cũ
	land += _mv_dir * 0.14 * (1.0 - _start_t)
	return land

func _foot_plant_world(side: String) -> Vector3:
	# Vị trí bàn chân mục tiêu (world) cho 1 chân, theo trạng thái stance/swing.
	var p := _step_phase_of(side)
	var stance := _foot_stance_frac()
	if p < stance:
		# Stance: khoá chân tại điểm đã tiếp đất (không trượt)
		return (_plant_r if side == "r" else _plant_l)
	# Swing: từ điểm tiếp đất cũ → điểm tiếp đất mới phía trước
	var t := (p - stance) / (1.0 - stance)
	var ease := t * t * (3.0 - 2.0 * t)
	var launch: Vector3 = (_plant_r if side == "r" else _plant_l)
	var land := _foot_land_target(side)
	var out: Vector3 = launch.lerp(land, ease)
	out.y += sin(t * PI) * (_step_lift())
	return out

func _step_lift() -> float:
	match _gait:
		2: return 0.10
		3: return 0.07
		_: return 0.045

## Cập nhật pha bước + cập nhật khoá chân khi chuyển swing→stance.
## 1.0 đơn vị phase = một chu kỳ bước đầy đủ (cả 2 chân), quãng di chuyển cơ thể
## = _foot_step_len(). => cadence = speed/step_len; chân trụ giữ 1 điểm world cố
## định trong khi cơ thể chạy qua → KHÔNG trượt.
func _advance_feet(delta: float) -> void:
	var speed := 0.0
	if base != null:
		speed = Vector3(base.velocity.x, 0.0, base.velocity.z).length()
	_step_speed = _springy("step_speed", speed, 30.0, 7.0, delta)
	_step_phase += delta * (_step_speed / _foot_step_len())
	_update_plant_locks()

func _update_plant_locks() -> void:
	var stance := _foot_stance_frac()
	for side in ["l", "r"]:
		var p := _step_phase_of(side)
		var in_stance := p < stance
		var was_stance := _prev_stance_l if side == "l" else _prev_stance_r
		if in_stance and not was_stance:
			# Mới chạm đất: plant = ĐÚNG chỗ bàn chân vừa tiếp xúc (liên tục C1,
			# không giật). Swing path đã ease về land (ngang mặt đất) ở pha cuối.
			var fo: Node3D = _bone("foot_%s" % side)
			var land: Vector3 = fo.global_position if fo != null else _foot_land_target(side)
			land.y = _ankle_world_ground()
			if side == "l":
				_plant_l = land
			else:
				_plant_r = land
		if side == "l":
			_prev_stance_l = in_stance
		else:
			_prev_stance_r = in_stance

## Đẩy cả 2 chân xuống đất theo IK, giữ plantar ổn định.
## toe_down: độ vểnh mũi chân (0 = flat, âm = đi mũi chân).
func _pose_feet(toe_down: float) -> void:
	var pelvis: Node3D = _bone("pelvis")
	if pelvis == null:
		return
	for side in ["l", "r"]:
		var t_w := _foot_plant_world(side)
		var t_loc := pelvis.to_local(t_w)
		_leg_ik(side, t_loc)
		var to: Node3D = _bone("toe_%s" % side)
		if to != null:
			_set_axis(to, 0, toe_down)

# ── Base locomotion ─────────────────────────────────────────────────────────
## Crush khi chạm đất: soft (nhẹ) / heavy (mạnh) theo _land_intensity.
## Chỉ dip COM + biến dạng nhẹ; chân ghim bởi IK nên không trượt.
func _land_crush(delta: float) -> float:
	var crush: float = _land_intensity * clampf(1.0 - _land_t / 0.28, 0.0, 1.0)
	if crush > 0.0:
		mesh.rig.position.y = lerp(mesh.rig.position.y, mesh.rig.position.y - crush * 0.035, clampf(delta * 18.0, 0.0, 1.0))
	return crush

func _idle(delta: float, t: float) -> void:
	var b: float = sin(t * idle_breathe_speed)
	# Idle-break: cứ ~5.4s một cụm nhìn quanh + trọng tâm dồn (deterministic)
	var ik: float = fmod(t, 5.4)
	var bk: float = clampf((ik - 3.2) / 0.4, 0.0, 1.0) * clampf((5.4 - ik) / 0.6, 0.0, 1.0)
	mesh.rig.position.y = _springy("idle_y", 0.004 + abs(b) * 0.006, 60.0, 9.0, delta)
	mesh.rig.rotation.x = _springy("idle_rx", 0.0, 60.0, 9.0, delta)
	mesh.rig.rotation.z = _springy("idle_rz", b * 0.010 + bk * 0.012, 50.0, 8.0, delta)
	_spring_rot(_bone("pelvis"), 0, -b * 0.012 + bk * 0.04, 60.0, 9.0, delta)
	_spring_rot(_bone("pelvis"), 2, sin(t * 0.5) * 0.02 + b * 0.008 + bk * 0.03, 50.0, 8.0, delta)
	_spring_rot(_bone("spine_01"), 0, b * 0.018, 55.0, 9.0, delta)
	_spring_rot(_bone("spine_03"), 0, -b * 0.022, 55.0, 9.0, delta)
	_spring_rot(_bone("spine_02"), 2, b * 0.012, 50.0, 8.0, delta)
	_spring_rot(_bone("neck_02"), 0, -b * 0.02, 50.0, 8.0, delta)
	_spring_rot(_bone("head"), 0, b * 0.035 + sin(t * 0.4) * 0.02, 50.0, 8.0, delta)
	_spring_rot(_bone("head"), 1, sin(t * 0.5) * 0.06 + bk * 0.30, 40.0, 7.0, delta)
	var arm_bob: float = 1.0
	if player and player.equipped_weapon and player.equipped_weapon.id == "watermelon_cannon":
		arm_bob = 0.3
	# Tay nghỉ: khuỷu hơi gập, vai khép nhẹ
	_arm_chain("l", (-0.10 + b * 0.02) * arm_bob, (0.10 + b * 0.01) * arm_bob + bk * 0.15, 5.0, delta)
	_arm_chain("r", (-0.10 + b * 0.02) * arm_bob, (-0.10 - b * 0.01) * arm_bob - bk * 0.15, 5.0, delta)
	_lerp_rot(_bone("forearm_l"), 0, -0.35 * arm_bob, 5.0, delta)
	_lerp_rot(_bone("forearm_r"), 0, -0.35 * arm_bob, 5.0, delta)
	_leg_cycle("l", 0.015, -0.06, 0.0, 6.0, delta)
	_leg_cycle("r", 0.015, -0.06, 0.0, 6.0, delta)

func _walk(delta: float, _t: float, mult: float) -> void:
	# Gait machine: Start (anticipation) → Loop → Stop (brake). _step_phase do engine điều khiển.
	_start_t = minf(_start_t + delta / 0.22, 1.0)
	# Brake: gần dừng → thu dần biên độ tay/nảy (End/Stop phase)
	var hspeed: float = 0.0
	if base != null:
		hspeed = Vector3(base.velocity.x, 0.0, base.velocity.z).length()
	if hspeed < 0.4:
		_stop_t = minf(_stop_t + delta / 0.20, 1.0)
	else:
		_stop_t = maxf(_stop_t - delta / 0.12, 0.0)
	var loco: float = _start_t * (1.0 - 0.85 * _stop_t)
	_advance_feet(delta)
	_pose_feet(0.0)
	var crush: float = _land_crush(delta)
	# COM: nảy theo nhịp chạm đất (2 contact mỗi chu kỳ) + ngả theo tốc độ
	var bounce: float = abs(sin(_step_phase * PI))
	var com_y: float = 0.004 + bounce * (0.016 + mult * 0.012) * _stop_t
	mesh.rig.position.y = _springy("com_y", com_y, 130.0, 15.0, delta)
	var lean: float = -(0.03 + 0.035 * mult) * _start_t
	mesh.rig.rotation.x = _springy("com_rx", lean, 90.0, 13.0, delta)
	mesh.rig.rotation.z = _springy("com_rz", bounce * 0.012, 90.0, 13.0, delta)
	# Hông dẫn nhịp theo chân trụ (spring → có quán tính, không lướt cứng)
	_spring_rot(_bone("pelvis"), 2, sin(_step_phase * PI * 2.0) * 0.05, 120.0, 16.0, delta)
	_spring_rot(_bone("pelvis"), 1, sin(_step_phase * PI * 2.0) * 0.04, 100.0, 15.0, delta)
	_spring_rot(_bone("pelvis"), 0, -0.05 * sin(_step_phase * PI * 2.0) + crush * 0.12, 120.0, 16.0, delta)
	# Spine counter-rotation: lưng xoay ngược vai
	_spring_rot(_bone("spine_01"), 0, 0.02 + sin(_step_phase * PI * 2.0) * 0.05, 110.0, 15.0, delta)
	_spring_rot(_bone("spine_02"), 1, -sin(_step_phase * PI) * 0.10, 110.0, 15.0, delta)
	_spring_rot(_bone("spine_03"), 1, -sin(_step_phase * PI) * 0.07, 100.0, 14.0, delta)
	_spring_rot(_bone("spine_03"), 0, sin(_step_phase * PI * 2.0) * 0.03, 90.0, 13.0, delta)
	# Đầu giữ hướng nhìn, bù ngược nhẹ
	_spring_rot(_bone("neck_02"), 0, -sin(_step_phase * PI * 2.0) * 0.03, 80.0, 12.0, delta)
	_spring_rot(_bone("head"), 0, sin(_step_phase * PI * 2.0) * 0.02 + 0.02 * mult, 80.0, 12.0, delta)
	_spring_rot(_bone("head"), 1, -sin(_step_phase * PI) * 0.03, 70.0, 11.0, delta)
	# Tay: quả lắc đối pha với chân cùng bên (sprint bơi mạnh hơn)
	var arm_swing: float = 0.34 + mult * 0.14
	if player and player.equipped_weapon and player.equipped_weapon.id == "watermelon_cannon":
		arm_swing *= 0.35
	var aw: float = sin(_step_phase * PI) * arm_swing * loco
	_arm_chain("l", -aw, 0.05, 10.0, delta)
	_arm_chain("r", aw, -0.05, 10.0, delta)
	_lerp_rot(_bone("forearm_l"), 0, -0.45 + aw * 0.55, 12.0, delta)
	_lerp_rot(_bone("forearm_r"), 0, -0.45 - aw * 0.55, 12.0, delta)
	_lerp_rot(_bone("hand_l"), 0, 0.08, 10.0, delta)
	_lerp_rot(_bone("hand_r"), 0, 0.08, 10.0, delta)

func _crouch(delta: float, _t: float) -> void:
	# Rón rén: hạ trọng tâm, lưng xuôi, mũi chân bám — bước chậm, âm thầm
	_start_t = minf(_start_t + delta / 0.25, 1.0)
	_advance_feet(delta)
	_pose_feet(-0.20)
	var crush: float = _land_crush(delta)
	mesh.rig.position.y = _springy("com_y", -0.15, 110.0, 18.0, delta)
	mesh.rig.rotation.x = _springy("com_rx", 0.10, 80.0, 14.0, delta)
	# Ngồi xổm sâu: hông chìm xuống, đùi gần ngang (chân ghim bởi IK tự gập)
	_spring_rot(_bone("pelvis"), 0, 0.42 - crush * 0.10, 120.0, 16.0, delta)
	_spring_rot(_bone("pelvis"), 2, sin(_step_phase * PI * 2.0) * 0.04, 100.0, 15.0, delta)
	# Lưng cuộn ngang (thấp)
	_spring_rot(_bone("spine_01"), 0, 0.26, 110.0, 15.0, delta)
	_spring_rot(_bone("spine_02"), 0, 0.20, 100.0, 14.0, delta)
	_spring_rot(_bone("spine_03"), 0, 0.13, 100.0, 14.0, delta)
	_spring_rot(_bone("neck_02"), 0, -0.14, 90.0, 13.0, delta)
	_spring_rot(_bone("head"), 0, 0.10 + sin(_step_phase * PI * 2.0) * 0.02, 90.0, 13.0, delta)
	# Tay kẹp trước ngực, khuỷu gập, vai khép
	_arm_chain("l", -0.55, 0.22, 10.0, delta)
	_arm_chain("r", -0.55, -0.22, 10.0, delta)
	_lerp_rot(_bone("forearm_l"), 0, -0.90, 12.0, delta)
	_lerp_rot(_bone("forearm_r"), 0, -0.90, 12.0, delta)

func _dash(delta: float, t: float) -> void:
	# Roll lăn: tuck bó gọn → đổ người → bật dậy (spring theo chuỗi, có quán tính)
	var dp: float = clamp((t - _dash_t0) / 0.45, 0.0, 1.0)
	var k: float = clamp(dp / 0.55, 0.0, 1.0)
	var u: float = clamp((dp - 0.55) / 0.45, 0.0, 1.0)
	var roll: float = 0.30 + 0.85 * k - 0.55 * u
	mesh.rig.position.y = _springy("dash_com_y", -0.02 - 0.03 * k + 0.02 * u, 150.0, 17.0, delta)
	mesh.rig.rotation.x = _springy("dash_com_rx", 0.05 * (1.0 - k) + 0.10 * u, 120.0, 16.0, delta)
	# Sóng đổ xuôi chuỗi: pelvis → spine → cổ → đầu (spring, mỗi khâu trễ hơn)
	_spring_rot(_bone("pelvis"), 0, roll, 180.0, 19.0, delta)
	_spring_rot(_bone("spine_01"), 0, roll * 0.72, 170.0, 18.0, delta)
	_spring_rot(_bone("spine_02"), 0, roll * 0.52, 160.0, 17.0, delta)
	_spring_rot(_bone("spine_03"), 0, roll * 0.34, 150.0, 16.0, delta)
	_spring_rot(_bone("neck_02"), 0, -roll * 0.30, 150.0, 16.0, delta)
	_spring_rot(_bone("head"), 0, -roll * 0.42 - 0.10 * u, 160.0, 17.0, delta)
	_spring_rot(_bone("pelvis"), 2, -0.08 - 0.05 * u, 140.0, 16.0, delta)
	# Tay bó gọn: vai khép, khuỷu gập sát người
	_arm_chain("l", -0.55 - 0.45 * k, 0.62, 16.0, delta)
	_arm_chain("r", -0.65 - 0.50 * k, -0.50, 16.0, delta)
	_lerp_rot(_bone("forearm_l"), 0, -1.05 * k, 16.0, delta)
	_lerp_rot(_bone("forearm_r"), 0, -1.05 * k, 16.0, delta)
	_lerp_rot(_bone("hand_l"), 2, -0.30, 16.0, delta)
	_lerp_rot(_bone("hand_r"), 2, 0.30, 16.0, delta)
	# Chân gập tối đa lúc tuck → duỗi khi bật dậy
	var leg_rx: float = -0.55 - 0.55 * k + 0.30 * u
	var leg_bend: float = -0.70 - 0.55 * k + 0.45 * u
	_leg_cycle("l", leg_rx, leg_bend, -0.25 * k, 18.0, delta)
	_leg_cycle("r", leg_rx, leg_bend, -0.25 * k, 18.0, delta)

func _air(delta: float, t: float, rising: bool) -> void:
	var jt: float = (t - _jump_t0) if rising else 0.0
	if rising and base.is_on_floor():
		# Start (anticipation): hạ người lấy đà 0.16s trước khi rời đất
		var prep: float = clampf(jt / 0.16, 0.0, 1.0)
		var load: float = 0.35 * (1.0 - prep)
		mesh.rig.position.y = _springy("air_com_y", -load * 0.06, 150.0, 17.0, delta)
		mesh.rig.rotation.x = _springy("air_com_rx", 0.05 * (1.0 - prep), 120.0, 16.0, delta)
		_spring_rot(_bone("pelvis"), 0, 0.18 * (1.0 - prep), 140.0, 17.0, delta)
		_spring_rot(_bone("spine_01"), 0, 0.10 * (1.0 - prep), 130.0, 16.0, delta)
		_spring_rot(_bone("neck_02"), 0, -0.06 * (1.0 - prep), 110.0, 15.0, delta)
		_arm_chain("l", -0.15 * (1.0 - prep), 0.10 * (1.0 - prep), 10.0, delta)
		_arm_chain("r", -0.15 * (1.0 - prep), -0.10 * (1.0 - prep), 10.0, delta)
		var sq: float = 1.0 - prep
		_leg_cycle("l", 0.30 * sq, -1.15 * sq, -0.10 * sq, 14.0, delta)
		_leg_cycle("r", 0.30 * sq, -1.15 * sq, -0.10 * sq, 14.0, delta)
		return
	var tuck: float
	if rising:
		tuck = clamp(base.velocity.y / base._jump_v, 0.0, 1.0)
	else:
		tuck = clamp(1.0 + base.velocity.y / base._jump_v, 0.0, 1.0) * 0.5
	# Ascend / Air loop / Descend: cuộn người nhẹ, tay gập theo đà
	mesh.rig.position.y = _springy("air_com_y", 0.004, 80.0, 12.0, delta)
	mesh.rig.rotation.x = _springy("air_com_rx", -0.06 + tuck * 0.10, 100.0, 14.0, delta)
	_spring_rot(_bone("pelvis"), 0, -0.06 + tuck * 0.10, 120.0, 16.0, delta)
	_spring_rot(_bone("spine_01"), 0, -0.10 + tuck * 0.08, 110.0, 15.0, delta)
	_spring_rot(_bone("spine_02"), 0, -0.06, 100.0, 14.0, delta)
	_spring_rot(_bone("neck_02"), 0, 0.14, 90.0, 13.0, delta)
	_spring_rot(_bone("head"), 0, -0.12 + tuck * 0.05, 100.0, 14.0, delta)
	_arm_chain("l", -0.55 - tuck * 0.25, 0.42 + tuck * 0.25, 9.0, delta)
	_arm_chain("r", -0.55 - tuck * 0.25, -0.42 - tuck * 0.25, 9.0, delta)
	# Descend: duỗi chân đón đất trước khi chạm (tuck giảm khi rơi)
	var fall_ext: float = 0.35 * tuck
	_leg_cycle("l", -0.42 - tuck * 0.35, -0.30 - tuck * 0.25 + fall_ext, 0.10, 10.0, delta)
	_leg_cycle("r", -0.42 - tuck * 0.35, -0.30 - tuck * 0.25 + fall_ext, 0.10, 10.0, delta)

func _swim(delta: float, t: float) -> void:
	var cyc: float = t * swim_cycle_speed
	mesh.rig.position.y = lerp(mesh.rig.position.y, 0.004, delta * 6.0)
	mesh.rig.rotation.x = lerp(mesh.rig.rotation.x, 0.10, delta * 8.0)
	_lerp_rot(_bone("pelvis"), 0, 0.22, 8.0, delta)
	_lerp_rot(_bone("spine_01"), 0, 0.14, 8.0, delta)
	_lerp_rot(_bone("spine_02"), 0, sin(cyc * 0.5) * 0.06 + 0.08, 8.0, delta)
	_lerp_rot(_bone("neck_02"), 0, -0.10, 7.0, delta)
	_lerp_rot(_bone("head"), 0, -0.10, 7.0, delta)
	_arm_chain("l", sin(cyc) * 0.85, 0.25, 10.0, delta)
	_arm_chain("r", sin(cyc + PI) * 0.85, -0.25, 10.0, delta)
	_leg_cycle("l", sin(cyc + PI * 0.5) * 0.35, sin(cyc + PI * 0.5) * 0.85, sin(cyc * 2.0) * 0.12, 14.0, delta)
	_leg_cycle("r", sin(cyc - PI * 0.5) * 0.35, sin(cyc - PI * 0.5) * 0.85, sin(cyc * 2.0) * 0.12, 14.0, delta)
	var kick: float = abs(sin(cyc * 1.5))
	mesh.rig.position.y += kick * 0.015

func _eat(delta: float, t: float) -> void:
	var chew: float = abs(sin(t * 9.0))
	mesh.rig.position.y = lerp(mesh.rig.position.y, 0.004, delta * 5.0)
	_lerp_rot(_bone("pelvis"), 0, 0.06, 8.0, delta)
	_lerp_rot(_bone("spine_01"), 0, 0.12, 7.0, delta)
	_lerp_rot(_bone("neck_02"), 0, -0.20, 8.0, delta)
	_lerp_rot(_bone("head"), 0, -0.14 - chew * 0.04, 8.0, delta)
	_lerp_rot(_bone("head"), 1, sin(t * 1.2) * 0.05, 6.0, delta)
	_arm_chain("r", -1.15 - chew * 0.12, 0.12, 10.0, delta)
	_lerp_rot(_bone("upper_arm_r"), 0, -1.5, 12.0, delta)
	_lerp_rot(_bone("forearm_r"), 0, -0.60, 12.0, delta)
	_arm_chain("l", -0.45 + chew * 0.06, 0.30, 9.0, delta)
	_lerp_rot(_bone("jaw"), 0, 0.22 + chew * 0.18, 14.0, delta)
	_leg_cycle("l", 0.02, -0.04, 0.0, 6.0, delta)
	_leg_cycle("r", 0.02, -0.04, 0.0, 6.0, delta)

func _hit(delta: float, _t: float) -> void:
	var p: float = 1.0 - clamp(base._hit_timer / 0.18, 0.0, 1.0)
	mesh.rig.position.y = lerp(mesh.rig.position.y, 0.01 - p * 0.008, delta * 14.0)
	_lerp_rot(_bone("pelvis"), 0, 0.22 - p * 0.16, 18.0, delta)
	_lerp_rot(_bone("spine_01"), 0, 0.16 - p * 0.10, 16.0, delta)
	_lerp_rot(_bone("spine_02"), 0, 0.10 - p * 0.06, 16.0, delta)
	_lerp_rot(_bone("neck_02"), 0, -0.10 + p * 0.08, 16.0, delta)
	_lerp_rot(_bone("head"), 0, -0.14 + p * 0.12, 18.0, delta)
	_lerp_rot(_bone("head"), 2, 0.08 - p * 0.06, 16.0, delta)
	_arm_chain("l", -0.30, 0.06, 20.0, delta)
	_arm_chain("r", -0.30, -0.06, 20.0, delta)
	_lerp_rot(_bone("jaw"), 0, 0.10 * p, 18.0, delta)
	_leg_cycle("l", -0.06, -0.08, 0.04, 14.0, delta)
	_leg_cycle("r", -0.10, -0.08, 0.04, 14.0, delta)

func _dead(delta: float, _t: float) -> void:
	# Wave collapse: pelvis mất đỡ trước → spine đổ → head cuối, tay rũ, chân gục
	var prog: float = clamp(1.0 - (base._death_timer / 1.8), 0.0, 1.0)
	if prog < 0.25:
		var p: float = prog / 0.25
		mesh.rig.position.y = lerp(mesh.rig.position.y, -p * 0.02, delta * 10.0)
		_lerp_rot(_bone("pelvis"), 0, p * 0.75, 16.0, delta)
		_lerp_rot(_bone("pelvis"), 2, p * -0.14, 14.0, delta)
		_lerp_rot(_bone("spine_01"), 0, p * 0.55, 14.0, delta)
		_lerp_rot(_bone("spine_02"), 0, p * 0.40, 12.0, delta)
		_lerp_rot(_bone("spine_03"), 0, p * 0.25, 10.0, delta)
		_arm_chain("l", p * 0.6, p * 0.34, 12.0, delta)
		_arm_chain("r", p * 0.75, p * -0.34, 12.0, delta)
		_leg_cycle("l", p * 0.12, -p * 0.9, p * 0.15, 12.0, delta)
		_leg_cycle("r", p * 0.12, -p * 0.9, p * 0.15, 12.0, delta)
	elif prog < 0.65:
		var p: float = (prog - 0.25) / 0.40
		mesh.rig.position.y = lerp(mesh.rig.position.y, -0.03 - p * 0.03, delta * 8.0)
		_lerp_rot(_bone("pelvis"), 0, 0.75 + p * 0.55, 16.0, delta)
		_lerp_rot(_bone("pelvis"), 2, -0.14 - p * 0.10, 14.0, delta)
		_lerp_rot(_bone("spine_01"), 0, 0.55 + p * 0.50, 14.0, delta)
		_lerp_rot(_bone("spine_02"), 0, 0.40 + p * 0.45, 12.0, delta)
		_lerp_rot(_bone("spine_03"), 0, 0.25 + p * 0.40, 10.0, delta)
		_lerp_rot(_bone("neck_02"), 0, -p * 0.35, 12.0, delta)
		_lerp_rot(_bone("head"), 0, -p * 0.30, 14.0, delta)
		_lerp_rot(_bone("jaw"), 0, p * 0.25, 12.0, delta)
		_arm_chain("l", 0.6 + p * 0.8, 0.34, 14.0, delta)
		_arm_chain("r", 0.75 + p * 0.9, -0.34, 14.0, delta)
		_lerp_rot(_bone("thigh_l"), 2, p * -0.40, 12.0, delta)
		_lerp_rot(_bone("thigh_r"), 2, p * 0.40, 12.0, delta)
		_leg_cycle("l", 0.12 + p * 0.3, -0.9 - p * 0.5, 0.15, 12.0, delta)
		_leg_cycle("r", 0.12 + p * 0.3, -0.9 - p * 0.5, 0.15, 12.0, delta)
	else:
		mesh.rig.position.y = lerp(mesh.rig.position.y, -0.08, delta * 6.0)
		_lerp_rot(_bone("pelvis"), 0, 1.30, 8.0, delta)
		_lerp_rot(_bone("pelvis"), 2, -0.24, 6.0, delta)
		_lerp_rot(_bone("spine_01"), 0, 1.05, 8.0, delta)
		_lerp_rot(_bone("spine_02"), 0, 0.85, 8.0, delta)
		_lerp_rot(_bone("spine_03"), 0, 0.65, 8.0, delta)
		_lerp_rot(_bone("neck_02"), 0, -0.35, 8.0, delta)
		_lerp_rot(_bone("head"), 0, -0.30, 10.0, delta)
		_lerp_rot(_bone("head"), 2, 0.35, 8.0, delta)
		_lerp_rot(_bone("jaw"), 0, 0.30, 8.0, delta)
		_arm_chain("l", 1.40, 0.40, 10.0, delta)
		_arm_chain("r", 1.65, -0.40, 10.0, delta)
		_leg_cycle("l", 0.42, -1.40, 0.15, 10.0, delta)
		_leg_cycle("r", 0.42, -1.40, 0.15, 10.0, delta)

# ── Upper layer: attack (curve vũ khí cũ giữ nguyên, đẩy chuyển động qua chuỗi khớp) ─
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

	# Trụ: chân hơi gập, tay phải nắm chặt, tay trái chống
	_leg_cycle("l", 0.10, -0.22, 0.06, 14.0, delta)
	_leg_cycle("r", -0.10, -0.18, 0.10, 14.0, delta)

	if is_heavy:
		# ── Heavy overhead swing ──────────────────────────────────────────────
		if prog < 0.35:
			var p: float = prog / 0.35
			wp.rotation_degrees.x = lerp(wp.rotation_degrees.x, -35.0 + 90.0 * (1.0 - p), delta * 14.0)
			wp.rotation_degrees.y = lerp(wp.rotation_degrees.y, 8.0 * p, delta * 14.0)
			wp.rotation_degrees.z = lerp(wp.rotation_degrees.z, -5.0 * p, delta * 14.0)
			_arm_chain("r", -0.80 * p, 0.10 * p, 18.0, delta)
			_arm_chain("l", 0.10 * p, -0.06 * p, 12.0, delta)
			_lerp_rot(_bone("pelvis"), 0, -0.06 * p, 14.0, delta)
			_lerp_rot(_bone("pelvis"), 1, 0.08 * p, 12.0, delta)
			_lerp_rot(_bone("spine_02"), 2, -0.10 * p, 12.0, delta)
			_lerp_rot(_bone("spine_03"), 2, -0.12 * p, 12.0, delta)
			_lerp_rot(_bone("head"), 1, 0.14 * p, 12.0, delta)
		elif prog < 0.75:
			if not _slash_spawned:
				_slash_spawned = true
				_spawn_slash(step)
			var p: float = (prog - 0.35) / 0.40
			wp.rotation_degrees.x = lerp(wp.rotation_degrees.x, 145.0, delta * 26.0)
			wp.rotation_degrees.y = lerp(wp.rotation_degrees.y, -12.0, delta * 22.0)
			wp.rotation_degrees.z = lerp(wp.rotation_degrees.z, 8.0, delta * 22.0)
			_arm_chain("r", 0.50 * p - 0.70 * (1.0 - p), -0.14 * sin(p * PI), 28.0, delta)
			_arm_chain("l", -0.15 * sin(p * PI), 0.02, 14.0, delta)
			_lerp_rot(_bone("pelvis"), 0, 0.10 * sin(p * PI), 18.0, delta)
			_lerp_rot(_bone("pelvis"), 1, -0.15 * sin(p * PI), 18.0, delta)
			_lerp_rot(_bone("spine_01"), 0, -0.08 * sin(p * PI), 16.0, delta)
			_lerp_rot(_bone("head"), 1, -0.18 * sin(p * PI), 16.0, delta)
			_lerp_rot(_bone("head"), 0, 0.10 * sin(p * PI), 14.0, delta)
			_lerp_rot(_bone("thigh_r"), 0, 0.20 * sin(p * PI), 12.0, delta)
		else:
			wp.rotation_degrees = wp.rotation_degrees.lerp(IDLE_WP, delta * 10.0)
			_lerp_rot(_bone("pelvis"), 0, 0.0, 10.0, delta)
			_lerp_rot(_bone("pelvis"), 1, 0.0, 10.0, delta)
			_lerp_rot(_bone("pelvis"), 2, 0.0, 10.0, delta)
			_lerp_rot(_bone("spine_01"), 0, 0.0, 10.0, delta)
			_lerp_rot(_bone("head"), 0, 0.0, 10.0, delta)
			_lerp_rot(_bone("head"), 1, 0.0, 10.0, delta)
			_arm_chain("r", -0.05, -0.03, 10.0, delta)
			_arm_chain("l", -0.05, 0.02, 10.0, delta)
			_leg_cycle("l", 0.02, -0.04, 0.0, 10.0, delta)
			_leg_cycle("r", 0.02, -0.04, 0.0, 10.0, delta)
	elif is_gs:
		# ── Đại kiếm: step 0 = chém dọc, step 1 = chém ngang ─────────────────
		if prog < 0.40:
			var p: float = prog / 0.40
			match step:
				0:
					wp.rotation_degrees.x = lerp(wp.rotation_degrees.x, -40.0 + 90.0 * (1.0 - p), delta * 16.0)
					wp.rotation_degrees.y = lerp(wp.rotation_degrees.y, 6.0 * p, delta * 14.0)
					wp.rotation_degrees.z = lerp(wp.rotation_degrees.z, -4.0 * p, delta * 14.0)
					_arm_chain("r", -0.60 * p, 0.05 * p, 20.0, delta)
					_arm_chain("l", 0.08 * p, -0.04 * p, 12.0, delta)
					_lerp_rot(_bone("pelvis"), 0, -0.05 * p, 14.0, delta)
					_lerp_rot(_bone("pelvis"), 1, 0.06 * p, 14.0, delta)
					_lerp_rot(_bone("spine_01"), 0, 0.04 * p, 12.0, delta)
					_lerp_rot(_bone("head"), 1, 0.10 * p, 12.0, delta)
				1:
					wp.rotation_degrees.x = lerp(wp.rotation_degrees.x, 60.0, delta * 16.0)
					wp.rotation_degrees.y = lerp(wp.rotation_degrees.y, 40.0, delta * 14.0)
					wp.rotation_degrees.z = lerp(wp.rotation_degrees.z, -18.0, delta * 14.0)
					_arm_chain("r", -0.50 * p, -0.22 * p, 20.0, delta)
					_arm_chain("l", 0.14 * p, -0.08 * p, 12.0, delta)
					_lerp_rot(_bone("pelvis"), 1, 0.15 * p, 14.0, delta)
					_lerp_rot(_bone("head"), 1, 0.22 * p, 12.0, delta)
			_lerp_rot(_bone("pelvis"), 0, -0.06 * p, 14.0, delta)
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
					_arm_chain("r", 0.60 * p - 0.60 * (1.0 - p), -0.10 * sin(p * PI), 30.0, delta)
					_arm_chain("l", -0.14 * sin(p * PI), 0.0, 16.0, delta)
					_lerp_rot(_bone("pelvis"), 1, -0.18 * sin(p * PI), 20.0, delta)
					_lerp_rot(_bone("head"), 1, -0.20 * sin(p * PI), 18.0, delta)
					_lerp_rot(_bone("head"), 0, 0.08 * sin(p * PI), 16.0, delta)
					_lerp_rot(_bone("thigh_r"), 0, 0.22 * sin(p * PI), 14.0, delta)
				1:
					wp.rotation_degrees.x = lerp(wp.rotation_degrees.x, 118.0, delta * 28.0)
					wp.rotation_degrees.y = lerp(wp.rotation_degrees.y, -30.0, delta * 24.0)
					wp.rotation_degrees.z = lerp(wp.rotation_degrees.z, 14.0, delta * 24.0)
					_arm_chain("r", 0.80 * p - 0.50 * (1.0 - p), 0.22 * sin(p * PI), 32.0, delta)
					_arm_chain("l", -0.25 * sin(p * PI), 0.0, 18.0, delta)
					_lerp_rot(_bone("pelvis"), 1, -0.35 * sin(p * PI), 22.0, delta)
					_lerp_rot(_bone("head"), 1, -0.40 * sin(p * PI), 20.0, delta)
					_lerp_rot(_bone("head"), 0, 0.06 * sin(p * PI), 16.0, delta)
					_lerp_rot(_bone("thigh_r"), 0, 0.18 * sin(p * PI), 14.0, delta)
			_lerp_rot(_bone("pelvis"), 0, 0.10 * p, 20.0, delta)
			_lerp_rot(_bone("pelvis"), 2, -0.04 * sin(p * PI), 18.0, delta)
			_lerp_rot(_bone("spine_01"), 0, 0.06 * p, 16.0, delta)
		else:
			wp.rotation_degrees = wp.rotation_degrees.lerp(IDLE_WP, delta * 10.0)
			_lerp_rot(_bone("pelvis"), 0, 0.0, 10.0, delta)
			_lerp_rot(_bone("pelvis"), 1, 0.0, 10.0, delta)
			_lerp_rot(_bone("pelvis"), 2, 0.0, 10.0, delta)
			_lerp_rot(_bone("spine_01"), 0, 0.0, 10.0, delta)
			_lerp_rot(_bone("head"), 0, 0.0, 10.0, delta)
			_lerp_rot(_bone("head"), 1, 0.0, 10.0, delta)
			_arm_chain("r", -0.05, -0.03, 10.0, delta)
			_arm_chain("l", -0.05, 0.02, 10.0, delta)
			_leg_cycle("l", 0.02, -0.04, 0.0, 10.0, delta)
			_leg_cycle("r", 0.02, -0.04, 0.0, 10.0, delta)
			if remaining <= 0.0 and player and player.combo_timer <= 0.0:
				player.combo_step = 0

	elif is_halberd:
		# ── Kích sắt: step 0 = bổ dọc, step 1 = quét ngang ─────────────────────
		if prog < 0.35:
			var p: float = prog / 0.35
			match step:
				0:
					wp.rotation_degrees.x = lerp(wp.rotation_degrees.x, -40.0 + 90.0 * (1.0 - p), delta * 16.0)
					wp.rotation_degrees.y = lerp(wp.rotation_degrees.y, 6.0 * p, delta * 14.0)
					wp.rotation_degrees.z = lerp(wp.rotation_degrees.z, -4.0 * p, delta * 14.0)
					_arm_chain("r", -0.60 * p, 0.05 * p, 20.0, delta)
					_arm_chain("l", 0.08 * p, -0.04 * p, 12.0, delta)
					_lerp_rot(_bone("pelvis"), 0, -0.05 * p, 14.0, delta)
					_lerp_rot(_bone("pelvis"), 1, 0.06 * p, 14.0, delta)
					_lerp_rot(_bone("spine_01"), 0, 0.04 * p, 12.0, delta)
					_lerp_rot(_bone("head"), 1, 0.10 * p, 12.0, delta)
				1:
					wp.rotation_degrees.x = lerp(wp.rotation_degrees.x, 60.0, delta * 16.0)
					wp.rotation_degrees.y = lerp(wp.rotation_degrees.y, 40.0, delta * 14.0)
					wp.rotation_degrees.z = lerp(wp.rotation_degrees.z, -18.0, delta * 14.0)
					_arm_chain("r", -0.50 * p, -0.22 * p, 20.0, delta)
					_arm_chain("l", 0.14 * p, -0.08 * p, 12.0, delta)
					_lerp_rot(_bone("pelvis"), 1, 0.15 * p, 14.0, delta)
					_lerp_rot(_bone("head"), 1, 0.22 * p, 12.0, delta)
			_lerp_rot(_bone("pelvis"), 0, -0.06 * p, 14.0, delta)
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
					_arm_chain("r", 0.60 * p - 0.60 * (1.0 - p), -0.10 * sin(p * PI), 30.0, delta)
					_arm_chain("l", -0.14 * sin(p * PI), 0.0, 16.0, delta)
					_lerp_rot(_bone("pelvis"), 1, -0.18 * sin(p * PI), 20.0, delta)
					_lerp_rot(_bone("head"), 1, -0.20 * sin(p * PI), 18.0, delta)
					_lerp_rot(_bone("head"), 0, 0.08 * sin(p * PI), 16.0, delta)
					_lerp_rot(_bone("thigh_r"), 0, 0.22 * sin(p * PI), 14.0, delta)
				1:
					wp.rotation_degrees.x = lerp(wp.rotation_degrees.x, 118.0, delta * 28.0)
					wp.rotation_degrees.y = lerp(wp.rotation_degrees.y, -30.0, delta * 24.0)
					wp.rotation_degrees.z = lerp(wp.rotation_degrees.z, 14.0, delta * 24.0)
					_arm_chain("r", 0.80 * p - 0.50 * (1.0 - p), 0.22 * sin(p * PI), 32.0, delta)
					_arm_chain("l", -0.25 * sin(p * PI), 0.0, 18.0, delta)
					_lerp_rot(_bone("pelvis"), 1, -0.35 * sin(p * PI), 22.0, delta)
					_lerp_rot(_bone("head"), 1, -0.40 * sin(p * PI), 20.0, delta)
					_lerp_rot(_bone("head"), 0, 0.06 * sin(p * PI), 16.0, delta)
					_lerp_rot(_bone("thigh_r"), 0, 0.18 * sin(p * PI), 14.0, delta)
			_lerp_rot(_bone("pelvis"), 0, 0.10 * p, 20.0, delta)
			_lerp_rot(_bone("pelvis"), 2, -0.04 * sin(p * PI), 18.0, delta)
			_lerp_rot(_bone("spine_01"), 0, 0.06 * p, 16.0, delta)
		else:
			wp.rotation_degrees = wp.rotation_degrees.lerp(IDLE_WP, delta * 10.0)
			_lerp_rot(_bone("pelvis"), 0, 0.0, 10.0, delta)
			_lerp_rot(_bone("pelvis"), 1, 0.0, 10.0, delta)
			_lerp_rot(_bone("pelvis"), 2, 0.0, 10.0, delta)
			_lerp_rot(_bone("spine_01"), 0, 0.0, 10.0, delta)
			_lerp_rot(_bone("head"), 0, 0.0, 10.0, delta)
			_lerp_rot(_bone("head"), 1, 0.0, 10.0, delta)
			_arm_chain("r", -0.05, -0.03, 10.0, delta)
			_arm_chain("l", -0.05, 0.02, 10.0, delta)
			_leg_cycle("l", 0.02, -0.04, 0.0, 10.0, delta)
			_leg_cycle("r", 0.02, -0.04, 0.0, 10.0, delta)
			if remaining <= 0.0 and player and player.combo_timer <= 0.0:
				player.combo_step = 0

	else:
		# ── Fast sword / fisticuffs combo ─────────────────────────────────────
		var punch: bool = player and player.equipped_weapon != null and player.equipped_weapon.id == "leather_gloves"
		if prog < 0.25:
			var p: float = prog / 0.25
			match step:
				0:
					wp.rotation_degrees.x = lerp(wp.rotation_degrees.x, 72.0, delta * 18.0)
					wp.rotation_degrees.y = lerp(wp.rotation_degrees.y, 28.0, delta * 18.0)
					wp.rotation_degrees.z = lerp(wp.rotation_degrees.z, -14.0, delta * 18.0)
					_arm_chain("r", -0.60 * p, -0.22 * p, 22.0, delta)
					_arm_chain("l", 0.12 * p, 0.04 * p, 14.0, delta)
					_lerp_rot(_bone("pelvis"), 1, 0.12 * p, 16.0, delta)
					_lerp_rot(_bone("head"), 1, 0.18 * p, 14.0, delta)
				1:
					wp.rotation_degrees.x = lerp(wp.rotation_degrees.x, 72.0, delta * 18.0)
					wp.rotation_degrees.y = lerp(wp.rotation_degrees.y, -28.0, delta * 18.0)
					wp.rotation_degrees.z = lerp(wp.rotation_degrees.z, 14.0, delta * 18.0)
					_arm_chain("r", -0.60 * p, 0.22 * p, 22.0, delta)
					_arm_chain("l", 0.12 * p, -0.04 * p, 14.0, delta)
					_lerp_rot(_bone("pelvis"), 1, -0.12 * p, 16.0, delta)
					_lerp_rot(_bone("head"), 1, -0.18 * p, 14.0, delta)
				2:
					wp.rotation_degrees.x = lerp(wp.rotation_degrees.x, 82.0, delta * 18.0)
					wp.rotation_degrees.y = lerp(wp.rotation_degrees.y, 42.0, delta * 18.0)
					wp.rotation_degrees.z = lerp(wp.rotation_degrees.z, -7.0, delta * 18.0)
					_arm_chain("r", -0.32 * p, -0.34 * p, 22.0, delta)
					_arm_chain("l", 0.16 * p, 0.06 * p, 14.0, delta)
					_lerp_rot(_bone("pelvis"), 1, 0.20 * p, 16.0, delta)
					_lerp_rot(_bone("head"), 1, 0.25 * p, 14.0, delta)
			_lerp_rot(_bone("pelvis"), 0, -0.08 * p, 16.0, delta)
			_lerp_rot(_bone("spine_01"), 0, -0.05 * p, 14.0, delta)
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
					_arm_chain("r", 0.80 * p - 0.60 * (1.0 - p), 0.10 * sin(p * PI), 32.0, delta)
					if punch:
						_arm_chain("l", 0.35 * sin(p * PI), 0.0, 18.0, delta)
					else:
						_arm_chain("l", -0.18 * sin(p * PI), 0.0, 16.0, delta)
					_lerp_rot(_bone("pelvis"), 1, -0.18 * sin(p * PI), 20.0, delta)
					_lerp_rot(_bone("head"), 1, -0.22 * sin(p * PI), 18.0, delta)
					_lerp_rot(_bone("head"), 0, 0.08 * sin(p * PI), 16.0, delta)
					_lerp_rot(_bone("thigh_r"), 0, 0.18 * sin(p * PI), 14.0, delta)
				1:
					wp.rotation_degrees.x = lerp(wp.rotation_degrees.x, 112.0, delta * 30.0)
					wp.rotation_degrees.y = lerp(wp.rotation_degrees.y, 22.0, delta * 30.0)
					wp.rotation_degrees.z = lerp(wp.rotation_degrees.z, -16.0, delta * 30.0)
					_arm_chain("r", 0.80 * p - 0.60 * (1.0 - p), -0.10 * sin(p * PI), 32.0, delta)
					_arm_chain("l", -0.18 * sin(p * PI), 0.0, 16.0, delta)
					_lerp_rot(_bone("pelvis"), 1, 0.18 * sin(p * PI), 20.0, delta)
					_lerp_rot(_bone("head"), 1, 0.22 * sin(p * PI), 18.0, delta)
					_lerp_rot(_bone("head"), 0, 0.08 * sin(p * PI), 16.0, delta)
					_lerp_rot(_bone("thigh_l"), 0, 0.18 * sin(p * PI), 14.0, delta)
				2:
					wp.rotation_degrees.x = lerp(wp.rotation_degrees.x, 97.0, delta * 30.0)
					wp.rotation_degrees.y = lerp(wp.rotation_degrees.y, -42.0, delta * 30.0)
					wp.rotation_degrees.z = lerp(wp.rotation_degrees.z, 11.0, delta * 30.0)
					_arm_chain("r", 0.50 * p - 0.32 * (1.0 - p), 0.14 * sin(p * PI), 32.0, delta)
					_arm_chain("l", -0.22 * sin(p * PI), 0.0, 16.0, delta)
					_lerp_rot(_bone("pelvis"), 1, 0.45 * sin(p * PI), 22.0, delta)
					_lerp_rot(_bone("head"), 1, 0.38 * sin(p * PI), 20.0, delta)
					_lerp_rot(_bone("head"), 0, 0.06 * sin(p * PI), 16.0, delta)
					_lerp_rot(_bone("thigh_r"), 0, 0.22 * sin(p * PI), 14.0, delta)
			_lerp_rot(_bone("pelvis"), 0, 0.12 * p, 22.0, delta)
			_lerp_rot(_bone("pelvis"), 2, -0.05 * sin(p * PI), 20.0, delta)
			_lerp_rot(_bone("spine_01"), 0, 0.08 * p, 18.0, delta)
		else:
			wp.rotation_degrees = wp.rotation_degrees.lerp(IDLE_WP, delta * 10.0)
			_lerp_rot(_bone("pelvis"), 0, 0.0, 10.0, delta)
			_lerp_rot(_bone("pelvis"), 1, 0.0, 10.0, delta)
			_lerp_rot(_bone("pelvis"), 2, 0.0, 10.0, delta)
			_lerp_rot(_bone("spine_01"), 0, 0.0, 10.0, delta)
			_lerp_rot(_bone("head"), 0, 0.0, 10.0, delta)
			_lerp_rot(_bone("head"), 1, 0.0, 10.0, delta)
			_arm_chain("r", -0.05, -0.03, 10.0, delta)
			_arm_chain("l", -0.05, 0.02, 10.0, delta)
			_leg_cycle("l", 0.02, -0.04, 0.0, 10.0, delta)
			_leg_cycle("r", 0.02, -0.04, 0.0, 10.0, delta)
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

# ── Lớp Additive: blink + gaze + thở ────────────────────────────────────────
func _facial_loop(delta: float, t: float) -> void:
	if base == null or base._state == CharacterBase.State.DEAD:
		return
	# Blink: nhắm mắt thoáng qua mỗi vài giây
	var bc: float = fmod(t, 4.6)
	var blink: float = 0.0
	if bc < 0.12:
		blink = sin(bc / 0.12 * PI)
	var lid_target: float = blink * 0.55
	_lerp_rot(_bone("eyelid_up_l"), 0, lid_target, 24.0, delta)
	_lerp_rot(_bone("eyelid_up_r"), 0, lid_target, 24.0, delta)
	_lerp_rot(_bone("eyelid_low_l"), 0, -lid_target * 0.5, 24.0, delta)
	_lerp_rot(_bone("eyelid_low_r"), 0, -lid_target * 0.5, 24.0, delta)
	# Gaze: mắt nhìn lướt nhẹ khi idle
	if base._state == CharacterBase.State.IDLE:
		_lerp_rot(_bone("eye_l"), 1, sin(t * 0.7) * 0.18, 3.0, delta)
		_lerp_rot(_bone("eye_r"), 1, sin(t * 0.7) * 0.18, 3.0, delta)
		_lerp_rot(_bone("eye_l"), 0, sin(t * 1.1) * 0.06, 3.0, delta)
		_lerp_rot(_bone("eye_r"), 0, sin(t * 1.1) * 0.06, 3.0, delta)
	# Thở: ngực phồng qua spine_01
	var br: float = sin(t * idle_breathe_speed)
	if base._state == CharacterBase.State.IDLE:
		_bone("spine_02").position.z = lerp(_bone("spine_02").position.z, 0.0 + br * 0.006, clamp(delta * 4.0, 0.0, 1.0))