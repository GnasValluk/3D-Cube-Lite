## PlayerAnimator – Layered procedural animation cho PlayerMesh blockout soulslike.
## Lớp Base: locomotion (pelvis lead, thigh/calf so le, foot plant, spine counter-rotation).
## Lớp Upper: attack whip-chain qua Pelvis→Spine→Clavicle→UpperArm→Forearm→Hand→Weapon.
## Lớp Additive: hit reaction, breathing, blink, gaze, jaw.
## Lớp Physics: cape chain trễ pha + trọng lực.
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

# Cape chain physics state
var _cape_ang: Array = []
var _cape_target: Array = []
var _cape_lag: Array = []

func setup(m: PlayerMesh, b: CharacterBase) -> void:
	mesh = m
	base = b
	player = b as PlayerCharacter
	_cape_reset()

func _cape_reset() -> void:
	_cape_ang.clear()
	_cape_target.clear()
	_cape_lag.clear()
	for i in range(6):
		_cape_ang.append(0.0)
		_cape_target.append(0.0)
		_cape_lag.append(0.0)

func _bone(name: String) -> Node3D:
	if mesh == null:
		return null
	return mesh.bones.get(name) as Node3D

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
	_cape_physics(delta, t)
	_facial_loop(delta, t)

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

func _grip(fingers: Array, curl: float, rate: float, delta: float) -> void:
	for bn in fingers:
		var n: Node3D = _bone(bn)
		if n == null:
			continue
		_lerp_rot(n, 0, curl, rate, delta)

func _grip_idle(delta: float, t: float) -> void:
	var f := 0.16 + 0.05 * sin(t * 1.3)
	_grip(["thumb_01_l", "thumb_02_l"], f, 4.0, delta)
	_grip(["thumb_01_r", "thumb_02_r"], f, 4.0, delta)
	for fname in ["index", "middle", "ring", "pinky"]:
		_grip(["%s_01_l" % fname, "%s_02_l" % fname], f * 0.8, 4.0, delta)
		_grip(["%s_03_l" % fname], f * 1.2, 4.0, delta)
		_grip(["%s_01_r" % fname, "%s_02_r" % fname], f * 0.8, 4.0, delta)
		_grip(["%s_03_r" % fname], f * 1.2, 4.0, delta)

func _grip_swing(delta: float, _t: float) -> void:
	_grip(["thumb_01_r", "thumb_02_r"], 0.35, 12.0, delta)
	for fname in ["index", "middle", "ring", "pinky"]:
		_grip(["%s_01_r" % fname], 0.40, 12.0, delta)
		_grip(["%s_02_r" % fname], 0.62, 12.0, delta)
		_grip(["%s_03_r" % fname], 0.85, 12.0, delta)

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

func _cape_puff(t: float, amp: float) -> Array:
	var out: Array = []
	for i in range(6):
		out.append(sin(t * 1.6 + i * 0.55) * amp)
	return out

# ── Base locomotion ─────────────────────────────────────────────────────────
func _idle(delta: float, t: float) -> void:
	var b: float = sin(t * idle_breathe_speed)
	mesh.rig.position.y = lerp(mesh.rig.position.y, 0.004 + abs(b) * 0.006, delta * 5.0)
	mesh.rig.rotation.x = lerp(mesh.rig.rotation.x, 0.0, delta * 6.0)
	mesh.rig.rotation.z = lerp(mesh.rig.rotation.z, b * 0.010, delta * 4.0)
	_lerp_rot(_bone("pelvis"), 0, -b * 0.012, 5.0, delta)
	_lerp_rot(_bone("pelvis"), 2, b * 0.008, 4.0, delta)
	_lerp_rot(_bone("spine_01"), 0, b * 0.018, 5.0, delta)
	_lerp_rot(_bone("spine_03"), 0, -b * 0.022, 5.0, delta)
	_lerp_rot(_bone("spine_02"), 2, b * 0.012, 4.0, delta)
	_lerp_rot(_bone("neck_02"), 0, -b * 0.02, 4.0, delta)
	_lerp_rot(_bone("head"), 0, b * 0.035 + sin(t * 0.4) * 0.02, 4.0, delta)
	_lerp_rot(_bone("head"), 1, sin(t * 0.5) * 0.06, 3.0, delta)
	var arm_bob: float = 1.0
	if player and player.equipped_weapon and player.equipped_weapon.id == "watermelon_cannon":
		arm_bob = 0.3
	_arm_chain("l", (-0.05 + b * 0.02) * arm_bob, (0.02 + b * 0.01) * arm_bob, 5.0, delta)
	_arm_chain("r", (-0.05 + b * 0.02) * arm_bob, (-0.02 - b * 0.01) * arm_bob, 5.0, delta)
	_leg_cycle("l", 0.015, -0.04, 0.0, 6.0, delta)
	_leg_cycle("r", 0.015, -0.04, 0.0, 6.0, delta)
	_cape_target = _cape_puff(t, 0.05)
	_grip_idle(delta, t)

func _walk(delta: float, t: float, mult: float) -> void:
	var cyc: float = t * walk_cycle_speed * mult
	var amp: float = 0.55 + mult * 0.10
	mesh.rig.position.y = 0.004 + abs(sin(cyc)) * (0.025 + mult * 0.012)
	mesh.rig.rotation.x = lerp(mesh.rig.rotation.x, -0.03 * mult, delta * 8.0)
	_lerp_rot(_bone("pelvis"), 2, sin(cyc) * 0.07, 10.0, delta)
	_lerp_rot(_bone("pelvis"), 0, sin(cyc * 0.5) * 0.03, 8.0, delta)
	_lerp_rot(_bone("spine_01"), 0, sin(cyc * 0.5) * 0.05, 8.0, delta)
	_lerp_rot(_bone("spine_02"), 1, -sin(cyc) * 0.10, 8.0, delta)
	_lerp_rot(_bone("spine_03"), 1, -sin(cyc) * 0.08, 8.0, delta)
	_lerp_rot(_bone("spine_03"), 0, sin(cyc * 0.5) * 0.04, 7.0, delta)
	_lerp_rot(_bone("neck_02"), 0, -sin(cyc * 0.5) * 0.04, 6.0, delta)
	_lerp_rot(_bone("head"), 0, sin(cyc * 0.5) * 0.03, 6.0, delta)
	_lerp_rot(_bone("head"), 1, sin(cyc * 0.5) * 0.05 * mult, 6.0, delta)
	var arm_swing: float = 0.30 + mult * 0.10
	if player and player.equipped_weapon and player.equipped_weapon.id == "watermelon_cannon":
		arm_swing *= 0.35
	_arm_chain("l", sin(cyc + PI) * arm_swing, 0.03, 10.0, delta)
	_arm_chain("r", sin(cyc) * arm_swing, -0.03, 10.0, delta)
	_leg_cycle("l", sin(cyc) * amp, -0.18 - abs(sin(cyc + PI * 0.5)) * 0.28, 0.12 + sin(cyc + PI * 0.5) * 0.10, 11.0, delta)
	_leg_cycle("r", sin(cyc + PI) * amp, -0.18 - abs(sin(cyc - PI * 0.5)) * 0.28, 0.12 + sin(cyc - PI * 0.5) * 0.10, 11.0, delta)
	_cape_target = _cape_puff(t, 0.10 + mult * 0.05)
	_grip_idle(delta, t)

func _crouch(delta: float, t: float) -> void:
	var cyc: float = t * walk_cycle_speed * 0.5
	mesh.rig.position.y = lerp(mesh.rig.position.y, -0.14, delta * 10.0)
	mesh.rig.rotation.x = lerp(mesh.rig.rotation.x, 0.10, delta * 8.0)
	_lerp_rot(_bone("pelvis"), 0, 0.34, 10.0, delta)
	_lerp_rot(_bone("spine_01"), 0, 0.22, 10.0, delta)
	_lerp_rot(_bone("spine_02"), 0, 0.16, 10.0, delta)
	_lerp_rot(_bone("spine_03"), 0, 0.10, 10.0, delta)
	_lerp_rot(_bone("neck_02"), 0, -0.10, 8.0, delta)
	_lerp_rot(_bone("head"), 0, 0.06, 8.0, delta)
	_arm_chain("l", -0.30, 0.14, 10.0, delta)
	_arm_chain("r", -0.30, -0.14, 10.0, delta)
	var step: float = sin(cyc) * 0.16
	_leg_cycle("l", 0.34 + step, -0.62 - abs(step) * 0.4, 0.30, 10.0, delta)
	_leg_cycle("r", 0.34 - step, -0.62 - abs(step) * 0.4, 0.30, 10.0, delta)
	_cape_target = _cape_puff(t, 0.04)
	_grip_idle(delta, t)

func _dash(delta: float, _t: float) -> void:
	# Roll: pelvis dẫn đầu, spine cuộn theo, tay thu, chân gập, cape quất
	mesh.rig.position.y = lerp(mesh.rig.position.y, 0.0, delta * 18.0)
	mesh.rig.rotation.x = lerp(mesh.rig.rotation.x, 0.06, delta * 12.0)
	_lerp_rot(_bone("pelvis"), 0, 0.62, 18.0, delta)
	_lerp_rot(_bone("spine_01"), 0, 0.42, 16.0, delta)
	_lerp_rot(_bone("spine_02"), 0, 0.30, 16.0, delta)
	_lerp_rot(_bone("spine_03"), 0, 0.18, 16.0, delta)
	_lerp_rot(_bone("pelvis"), 2, -0.10, 14.0, delta)
	_lerp_rot(_bone("neck_02"), 0, -0.22, 14.0, delta)
	_lerp_rot(_bone("head"), 0, -0.12, 14.0, delta)
	_arm_chain("l", -0.85, 0.55, 16.0, delta)
	_arm_chain("r", -0.95, -0.42, 16.0, delta)
	_lerp_rot(_bone("hand_l"), 2, -0.45, 16.0, delta)
	_lerp_rot(_bone("hand_r"), 2, 0.38, 16.0, delta)
	_leg_cycle("l", -0.78, -1.05, 0.42, 18.0, delta)
	_leg_cycle("r", -0.78, -1.05, 0.42, 18.0, delta)
	for i in range(6):
		_cape_target[i] = 0.7 - i * 0.025
		_cape_lag[i] = 0.9
	_grip_idle(delta, 0.0)

func _air(delta: float, t: float, rising: bool) -> void:
	var tuck: float
	if rising:
		tuck = clamp(base.velocity.y / base._jump_v, 0.0, 1.0)
	else:
		tuck = clamp(1.0 + base.velocity.y / base._jump_v, 0.0, 1.0) * 0.5
	mesh.rig.position.y = lerp(mesh.rig.position.y, 0.004, delta * 6.0)
	_lerp_rot(_bone("pelvis"), 0, -0.06 + tuck * 0.10, 8.0, delta)
	_lerp_rot(_bone("spine_01"), 0, -0.10 + tuck * 0.08, 8.0, delta)
	_lerp_rot(_bone("spine_02"), 0, -0.06, 8.0, delta)
	_lerp_rot(_bone("neck_02"), 0, 0.14, 8.0, delta)
	_lerp_rot(_bone("head"), 0, -0.12 + tuck * 0.05, 8.0, delta)
	_arm_chain("l", -0.55 - tuck * 0.25, 0.42 + tuck * 0.25, 9.0, delta)
	_arm_chain("r", -0.55 - tuck * 0.25, -0.42 - tuck * 0.25, 9.0, delta)
	_leg_cycle("l", -0.42 - tuck * 0.35, -0.30 - tuck * 0.25, 0.10, 10.0, delta)
	_leg_cycle("r", -0.42 - tuck * 0.35, -0.30 - tuck * 0.25, 0.10, 10.0, delta)
	_cape_target = _cape_puff(t, 0.35 + tuck * 0.15)
	for i in range(6):
		_cape_lag[i] = 1.0
	_grip_idle(delta, t)

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
	_cape_target = _cape_puff(t, 0.15)
	_grip_idle(delta, t)

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
	_cape_target = _cape_puff(t, 0.04)
	_grip_idle(delta, t)

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
	for i in range(6):
		_cape_lag[i] = 0.7
	_grip_idle(delta, 0.0)

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
	for i in range(6):
		_cape_target[i] = 0.35 + i * 0.05
		_cape_lag[i] = 1.0

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
	_grip_swing(delta, 0.0)
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

# ── Lớp Physics: cape chain trễ pha + trọng lực ─────────────────────────────
func _cape_physics(delta: float, _t: float) -> void:
	if _cape_ang.size() != 6:
		return
	# Trọng lực + đàn hồi: mỗi đốt trễ hơn đốt trước
	var prev_x: float = 0.0
	for i in range(6):
		var bn := _bone("cape_%02d" % (i + 1))
		if bn == null:
			continue
		var target: float = _cape_target[i]
		if _cape_lag[i] > 0.0:
			target += _cape_lag[i] * 0.6
		var spring := 6.0 + i * 0.8
		_cape_ang[i] = lerp(_cape_ang[i], target - 0.10, clamp(spring * delta * 0.5, 0.0, 1.0))
		_cape_ang[i] = clamp(_cape_ang[i], -0.9, 0.9)
		var wobble: float = sin(_t * 2.2 + i * 1.1) * 0.02 - i * 0.012
		bn.rotation.x = _cape_ang[i] + wobble + prev_x * 0.25
		bn.rotation.z = sin(_t * 1.7 + i * 0.9) * 0.03
		prev_x = bn.rotation.x
	_cape_lag.fill(0.0)

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