## warrior/warrior_animator.gd
## Animator cho Warrior với beam cast và cú stomp dậm đất.

class_name WarriorAnimator

var walk_cycle_speed: float = 6.6
var sprint_cycle_mult: float = 1.55
var idle_breathe_speed: float = 1.1
var cape_wave_speed: float = 2.6

var mesh: WarriorMesh
var base: CharacterBase

func setup(m: WarriorMesh, b: CharacterBase) -> void:
	mesh = m
	base = b

func m() -> WarriorMesh:
	return mesh

func animate(delta: float) -> void:
	var t: float = base._time
	match base._state:
		CharacterBase.State.IDLE:
			_idle(delta, t)
		CharacterBase.State.WALK:
			_walk(delta, t, 1.0)
		CharacterBase.State.SPRINT:
			_walk(delta, t, sprint_cycle_mult)
		CharacterBase.State.DASH:
			_dash(delta, t)
		CharacterBase.State.ATTACK:
			_beam(delta, t)
		CharacterBase.State.DEVOUR:
			_stomp(delta, t)
		CharacterBase.State.JUMP:
			_air(delta, t)
		CharacterBase.State.FALL:
			_air(delta, t)
		CharacterBase.State.HIT:
			_hit(delta, t)
		CharacterBase.State.DEAD:
			_dead(delta, t)

func _idle(delta: float, t: float) -> void:
	var b: float = sin(t * idle_breathe_speed)
	m().rig.position.y = lerp(m().rig.position.y, 0.10 + b * 0.02, delta * 6.0)
	m().rig.rotation.x = lerp(m().rig.rotation.x, -0.03, delta * 7.0)
	m().rig.rotation.z = lerp(m().rig.rotation.z, 0.0, delta * 7.0)
	m().spine.rotation.x = lerp(m().spine.rotation.x, -0.03, delta * 6.0)
	m().spine.rotation.y = lerp(m().spine.rotation.y, 0.0, delta * 6.0)
	m().chest.rotation.x = lerp(m().chest.rotation.x, 0.04 + b * 0.02, delta * 6.0)
	m().chest.rotation.y = lerp(m().chest.rotation.y, sin(t * 0.5) * 0.04, delta * 4.0)
	m().head.rotation.x = lerp(m().head.rotation.x, 0.00 + b * 0.02, delta * 6.0)
	m().head.rotation.y = lerp(m().head.rotation.y, sin(t * 0.35) * 0.08, delta * 4.0)
	_set_guard_arms(delta, 0.58, 0.42)
	m().thigh_l.rotation.x = lerp(m().thigh_l.rotation.x, 0.04, delta * 6.0)
	m().thigh_r.rotation.x = lerp(m().thigh_r.rotation.x, 0.04, delta * 6.0)
	m().shin_l.rotation.x = lerp(m().shin_l.rotation.x, 0.08, delta * 6.0)
	m().shin_r.rotation.x = lerp(m().shin_r.rotation.x, 0.08, delta * 6.0)
	m().foot_l.rotation.x = lerp(m().foot_l.rotation.x, -0.04, delta * 6.0)
	m().foot_r.rotation.x = lerp(m().foot_r.rotation.x, -0.04, delta * 6.0)
	_sway_cloth(delta, t, 0.10, 0.06)

func _walk(delta: float, t: float, mult: float) -> void:
	var cyc: float = t * walk_cycle_speed * mult
	var cyc2: float = cyc + PI
	m().rig.position.y = 0.10 + abs(sin(cyc * 0.9)) * (0.04 + mult * 0.02)
	m().rig.rotation.x = lerp(m().rig.rotation.x, -0.08 * mult, delta * 8.0)
	m().rig.rotation.z = sin(cyc) * (0.03 + mult * 0.01)
	m().spine.rotation.y = lerp(m().spine.rotation.y, sin(cyc) * 0.10, delta * 7.0)
	m().chest.rotation.y = lerp(m().chest.rotation.y, sin(cyc) * 0.12, delta * 7.0)
	m().head.rotation.y = lerp(m().head.rotation.y, sin(cyc) * -0.08, delta * 6.0)
	_set_guard_arms(delta, 0.50 + sin(cyc2) * 0.12, 0.34 + sin(cyc) * 0.10)
	m().upper_arm_l.rotation.x = lerp(m().upper_arm_l.rotation.x, 0.36 + sin(cyc2) * 0.18, delta * 8.0)
	m().upper_arm_r.rotation.x = lerp(m().upper_arm_r.rotation.x, 0.44 + sin(cyc) * 0.16, delta * 8.0)
	m().thigh_l.rotation.x = sin(cyc) * 0.58
	m().shin_l.rotation.x = abs(sin(cyc)) * 0.52
	m().foot_l.rotation.x = -abs(sin(cyc)) * 0.24
	m().thigh_r.rotation.x = sin(cyc2) * 0.58
	m().shin_r.rotation.x = abs(sin(cyc2)) * 0.52
	m().foot_r.rotation.x = -abs(sin(cyc2)) * 0.24
	_sway_cloth(delta, t, 0.14 + mult * 0.05, 0.10 + mult * 0.04)

func _dash(delta: float, t: float) -> void:
	m().rig.position.y = lerp(m().rig.position.y, 0.02, delta * 18.0)
	m().rig.rotation.x = lerp(m().rig.rotation.x, 0.34, delta * 18.0)
	m().spine.rotation.x = lerp(m().spine.rotation.x, 0.20, delta * 16.0)
	m().chest.rotation.x = lerp(m().chest.rotation.x, 0.24, delta * 16.0)
	m().head.rotation.x = lerp(m().head.rotation.x, -0.20, delta * 14.0)
	m().upper_arm_l.rotation.x = lerp(m().upper_arm_l.rotation.x, -0.20, delta * 16.0)
	m().upper_arm_r.rotation.x = lerp(m().upper_arm_r.rotation.x, -0.10, delta * 16.0)
	m().upper_arm_l.rotation.z = lerp(m().upper_arm_l.rotation.z, 0.14, delta * 16.0)
	m().upper_arm_r.rotation.z = lerp(m().upper_arm_r.rotation.z, -0.18, delta * 16.0)
	m().lower_arm_l.rotation.x = lerp(m().lower_arm_l.rotation.x, -0.42, delta * 16.0)
	m().lower_arm_r.rotation.x = lerp(m().lower_arm_r.rotation.x, -0.50, delta * 16.0)
	m().thigh_l.rotation.x = lerp(m().thigh_l.rotation.x, -0.52, delta * 18.0)
	m().thigh_r.rotation.x = lerp(m().thigh_r.rotation.x, -0.42, delta * 18.0)
	m().shin_l.rotation.x = lerp(m().shin_l.rotation.x, 0.20, delta * 18.0)
	m().shin_r.rotation.x = lerp(m().shin_r.rotation.x, 0.16, delta * 18.0)
	_fists_forward(delta, 0.28)
	_sway_cloth(delta, t, 0.20, 0.18)

func _beam(delta: float, _t: float) -> void:
	var prog: float = _beam_progress()
	var charge: float = clamp(prog / 0.28, 0.0, 1.0)
	var fire: float = clamp((prog - 0.28) / 0.72, 0.0, 1.0)
	m().rig.position.y = lerp(m().rig.position.y, 0.12 + sin(fire * PI) * 0.03, delta * 12.0)
	m().rig.rotation.x = lerp(m().rig.rotation.x, lerp(-0.10, 0.08, fire), delta * 18.0)
	m().rig.rotation.z = lerp(m().rig.rotation.z, 0.0, delta * 16.0)
	m().spine.rotation.x = lerp(m().spine.rotation.x, lerp(-0.08, 0.16, fire), delta * 18.0)
	m().spine.rotation.y = lerp(m().spine.rotation.y, 0.0, delta * 16.0)
	m().chest.rotation.x = lerp(m().chest.rotation.x, lerp(-0.12, 0.34, fire), delta * 18.0)
	m().chest.rotation.y = lerp(m().chest.rotation.y, lerp(-0.10, 0.0, fire), delta * 18.0)
	m().head.rotation.x = lerp(m().head.rotation.x, lerp(-0.08, 0.06, fire), delta * 16.0)
	m().head.rotation.y = lerp(m().head.rotation.y, 0.0, delta * 14.0)
	m().upper_arm_l.rotation.x = lerp(m().upper_arm_l.rotation.x, lerp(-0.28, 0.74, charge), delta * 20.0)
	m().upper_arm_l.rotation.z = lerp(m().upper_arm_l.rotation.z, lerp(0.52, 0.18, fire), delta * 20.0)
	m().lower_arm_l.rotation.x = lerp(m().lower_arm_l.rotation.x, lerp(-0.44, -1.20, charge), delta * 20.0)
	m().lower_arm_l.rotation.z = lerp(m().lower_arm_l.rotation.z, lerp(-0.06, -0.18, fire), delta * 18.0)
	m().hand_l.rotation.x = lerp(m().hand_l.rotation.x, lerp(-0.04, -0.26, fire), delta * 18.0)
	m().hand_l.rotation.z = lerp(m().hand_l.rotation.z, lerp(-0.02, -0.16, fire), delta * 18.0)
	m().upper_arm_r.rotation.x = lerp(m().upper_arm_r.rotation.x, lerp(-0.34, 0.38, charge), delta * 18.0)
	m().upper_arm_r.rotation.z = lerp(m().upper_arm_r.rotation.z, lerp(-0.56, -0.22, charge), delta * 18.0)
	m().lower_arm_r.rotation.x = lerp(m().lower_arm_r.rotation.x, lerp(-0.28, -0.92, charge), delta * 18.0)
	m().lower_arm_r.rotation.z = lerp(m().lower_arm_r.rotation.z, 0.16, delta * 18.0)
	m().hand_r.rotation.x = lerp(m().hand_r.rotation.x, lerp(0.00, -0.22, fire), delta * 18.0)
	m().hand_r.rotation.z = lerp(m().hand_r.rotation.z, lerp(0.06, 0.14, fire), delta * 18.0)
	m().thigh_l.rotation.x = lerp(m().thigh_l.rotation.x, lerp(0.12, 0.26, fire), delta * 14.0)
	m().thigh_r.rotation.x = lerp(m().thigh_r.rotation.x, lerp(0.12, -0.08, fire), delta * 14.0)
	m().shin_l.rotation.x = lerp(m().shin_l.rotation.x, 0.34, delta * 14.0)
	m().shin_r.rotation.x = lerp(m().shin_r.rotation.x, 0.20, delta * 14.0)
	m().foot_l.rotation.x = lerp(m().foot_l.rotation.x, -0.10, delta * 14.0)
	m().foot_r.rotation.x = lerp(m().foot_r.rotation.x, -0.08, delta * 14.0)
	_sway_cloth(delta, base._time, 0.18 + fire * 0.12, 0.14 + fire * 0.10)

func _stomp(delta: float, t: float) -> void:
	var prog: float = _stomp_progress()
	if _is_stomp_airborne():
		var flight: float = clamp(prog / 0.78, 0.0, 1.0)
		var tuck: float = sin(flight * PI)
		m().rig.position.y = lerp(m().rig.position.y, 0.08 + tuck * 0.10, delta * 12.0)
		m().rig.rotation.x = lerp(m().rig.rotation.x, lerp(-0.06, 0.34, flight), delta * 16.0)
		m().spine.rotation.x = lerp(m().spine.rotation.x, lerp(-0.12, 0.20, flight), delta * 16.0)
		m().chest.rotation.x = lerp(m().chest.rotation.x, lerp(-0.04, 0.34, flight), delta * 18.0)
		m().head.rotation.x = lerp(m().head.rotation.x, lerp(-0.04, 0.14, flight), delta * 14.0)
		m().upper_arm_l.rotation.x = lerp(m().upper_arm_l.rotation.x, lerp(-0.24, 1.02, flight), delta * 18.0)
		m().upper_arm_l.rotation.z = lerp(m().upper_arm_l.rotation.z, lerp(0.18, 0.08, flight), delta * 18.0)
		m().upper_arm_r.rotation.x = lerp(m().upper_arm_r.rotation.x, lerp(-0.24, 1.02, flight), delta * 18.0)
		m().upper_arm_r.rotation.z = lerp(m().upper_arm_r.rotation.z, lerp(-0.18, -0.08, flight), delta * 18.0)
		m().lower_arm_l.rotation.x = lerp(m().lower_arm_l.rotation.x, lerp(-0.54, -1.26, flight), delta * 18.0)
		m().lower_arm_r.rotation.x = lerp(m().lower_arm_r.rotation.x, lerp(-0.54, -1.26, flight), delta * 18.0)
		m().hand_l.rotation.x = lerp(m().hand_l.rotation.x, -0.18, delta * 18.0)
		m().hand_r.rotation.x = lerp(m().hand_r.rotation.x, -0.18, delta * 18.0)
		m().thigh_l.rotation.x = lerp(m().thigh_l.rotation.x, lerp(-0.12, 0.92, tuck), delta * 18.0)
		m().thigh_r.rotation.x = lerp(m().thigh_r.rotation.x, lerp(-0.12, 0.92, tuck), delta * 18.0)
		m().shin_l.rotation.x = lerp(m().shin_l.rotation.x, lerp(0.22, 1.18, tuck), delta * 18.0)
		m().shin_r.rotation.x = lerp(m().shin_r.rotation.x, lerp(0.22, 1.18, tuck), delta * 18.0)
		m().foot_l.rotation.x = lerp(m().foot_l.rotation.x, lerp(-0.10, -0.38, tuck), delta * 16.0)
		m().foot_r.rotation.x = lerp(m().foot_r.rotation.x, lerp(-0.10, -0.38, tuck), delta * 16.0)
		_sway_cloth(delta, t, 0.20 + tuck * 0.18, 0.16 + tuck * 0.12)
		return

	var settle: float = 0.0
	if _has_stomp_impacted():
		settle = clamp((prog - 0.78) / 0.22, 0.0, 1.0)
	var hold: float = 1.0 - settle
	m().rig.position.y = lerp(m().rig.position.y, 0.02 + settle * 0.06, delta * 16.0)
	m().rig.rotation.x = lerp(m().rig.rotation.x, 0.18 - settle * 0.14, delta * 16.0)
	m().spine.rotation.x = lerp(m().spine.rotation.x, 0.24 - settle * 0.12, delta * 16.0)
	m().chest.rotation.x = lerp(m().chest.rotation.x, 0.30 - settle * 0.14, delta * 16.0)
	m().head.rotation.x = lerp(m().head.rotation.x, 0.10 - settle * 0.08, delta * 14.0)
	m().upper_arm_l.rotation.x = lerp(m().upper_arm_l.rotation.x, 0.82 - settle * 0.28, delta * 18.0)
	m().upper_arm_l.rotation.z = lerp(m().upper_arm_l.rotation.z, 0.20, delta * 18.0)
	m().upper_arm_r.rotation.x = lerp(m().upper_arm_r.rotation.x, 0.82 - settle * 0.28, delta * 18.0)
	m().upper_arm_r.rotation.z = lerp(m().upper_arm_r.rotation.z, -0.20, delta * 18.0)
	m().lower_arm_l.rotation.x = lerp(m().lower_arm_l.rotation.x, -1.34 + settle * 0.24, delta * 18.0)
	m().lower_arm_r.rotation.x = lerp(m().lower_arm_r.rotation.x, -1.34 + settle * 0.24, delta * 18.0)
	m().hand_l.rotation.x = lerp(m().hand_l.rotation.x, -0.26, delta * 18.0)
	m().hand_r.rotation.x = lerp(m().hand_r.rotation.x, -0.26, delta * 18.0)
	m().thigh_l.rotation.x = lerp(m().thigh_l.rotation.x, 0.78 - settle * 0.42, delta * 18.0)
	m().thigh_r.rotation.x = lerp(m().thigh_r.rotation.x, 0.78 - settle * 0.42, delta * 18.0)
	m().shin_l.rotation.x = lerp(m().shin_l.rotation.x, 1.02 - settle * 0.56, delta * 18.0)
	m().shin_r.rotation.x = lerp(m().shin_r.rotation.x, 1.02 - settle * 0.56, delta * 18.0)
	m().foot_l.rotation.x = lerp(m().foot_l.rotation.x, -0.42 + settle * 0.24, delta * 18.0)
	m().foot_r.rotation.x = lerp(m().foot_r.rotation.x, -0.42 + settle * 0.24, delta * 18.0)
	m().chest.rotation.y = lerp(m().chest.rotation.y, sin(t * 24.0) * 0.015 * hold, delta * 16.0)
	_sway_cloth(delta, t, 0.26 + hold * 0.16, 0.20 + hold * 0.12)

func _air(delta: float, t: float) -> void:
	var rising: bool = base._state == CharacterBase.State.JUMP
	var tuck: float
	if rising:
		tuck = clamp(base.velocity.y / base._jump_v, 0.0, 1.0)
	else:
		tuck = clamp(1.0 + base.velocity.y / base._jump_v, 0.0, 1.0) * 0.5
	m().rig.position.y = lerp(m().rig.position.y, 0.10, delta * 6.0)
	m().rig.rotation.x = lerp(m().rig.rotation.x, 0.02, delta * 8.0)
	m().spine.rotation.x = lerp(m().spine.rotation.x, -0.08 + tuck * 0.12, delta * 8.0)
	m().chest.rotation.x = lerp(m().chest.rotation.x, -0.06 + tuck * 0.14, delta * 8.0)
	m().head.rotation.x = lerp(m().head.rotation.x, -0.06, delta * 8.0)
	m().upper_arm_l.rotation.x = lerp(m().upper_arm_l.rotation.x, -0.18, delta * 8.0)
	m().upper_arm_r.rotation.x = lerp(m().upper_arm_r.rotation.x, -0.18, delta * 8.0)
	m().lower_arm_l.rotation.x = lerp(m().lower_arm_l.rotation.x, -0.62, delta * 10.0)
	m().lower_arm_r.rotation.x = lerp(m().lower_arm_r.rotation.x, -0.62, delta * 10.0)
	m().thigh_l.rotation.x = lerp(m().thigh_l.rotation.x, -0.26 - tuck * 0.42, delta * 10.0)
	m().thigh_r.rotation.x = lerp(m().thigh_r.rotation.x, -0.26 - tuck * 0.42, delta * 10.0)
	m().shin_l.rotation.x = lerp(m().shin_l.rotation.x, 0.54 + tuck * 0.38, delta * 10.0)
	m().shin_r.rotation.x = lerp(m().shin_r.rotation.x, 0.54 + tuck * 0.38, delta * 10.0)
	m().foot_l.rotation.x = lerp(m().foot_l.rotation.x, -0.26, delta * 10.0)
	m().foot_r.rotation.x = lerp(m().foot_r.rotation.x, -0.26, delta * 10.0)
	_fists_forward(delta, 0.10)
	_sway_cloth(delta, t, 0.18, 0.14)

# ── HIT ────────────────────────────────────────────────────────────────────────
func _hit(delta: float, _t: float) -> void:
	var p: float = 1.0 - (base._hit_timer / 0.18)
	m().rig.position.y = lerp(m().rig.position.y, 0.06, delta*14.0)
	m().rig.rotation.x = lerp(m().rig.rotation.x, 0.26 - p*0.18, delta*16.0)
	m().spine.rotation.x = lerp(m().spine.rotation.x, 0.20 - p*0.12, delta*14.0)
	m().chest.rotation.x = lerp(m().chest.rotation.x, 0.18 - p*0.10, delta*14.0)
	m().head.rotation.x = lerp(m().head.rotation.x, -0.20 + p*0.14, delta*16.0)
	m().upper_arm_l.rotation.x = lerp(m().upper_arm_l.rotation.x, -0.40, delta*20.0)
	m().upper_arm_l.rotation.z = lerp(m().upper_arm_l.rotation.z, 0.40, delta*18.0)
	m().lower_arm_l.rotation.x = lerp(m().lower_arm_l.rotation.x, -0.20, delta*20.0)
	m().upper_arm_r.rotation.x = lerp(m().upper_arm_r.rotation.x, -0.40, delta*20.0)
	m().upper_arm_r.rotation.z = lerp(m().upper_arm_r.rotation.z, -0.40, delta*18.0)
	m().lower_arm_r.rotation.x = lerp(m().lower_arm_r.rotation.x, -0.20, delta*20.0)
	m().thigh_l.rotation.x = lerp(m().thigh_l.rotation.x, -0.08, delta*12.0)
	m().thigh_r.rotation.x = lerp(m().thigh_r.rotation.x, -0.08, delta*12.0)
	m().shin_l.rotation.x = lerp(m().shin_l.rotation.x, 0.42, delta*12.0)
	m().shin_r.rotation.x = lerp(m().shin_r.rotation.x, 0.42, delta*12.0)

# ── DEAD ───────────────────────────────────────────────────────────────────────
func _dead(delta: float, t: float) -> void:
	var prog: float = 1.0 - (base._death_timer / 1.8)
	if prog < 0.20:
		var p: float = prog / 0.20
		m().rig.rotation.x = lerp(m().rig.rotation.x, p * 0.30, delta*16.0)
		m().rig.rotation.z = lerp(m().rig.rotation.z, p * (-0.08), delta*14.0)
		m().spine.rotation.x = lerp(m().spine.rotation.x, p * 0.20, delta*14.0)
		m().chest.rotation.x = lerp(m().chest.rotation.x, p * 0.22, delta*14.0)
		m().head.rotation.x = lerp(m().head.rotation.x, -p * 0.16, delta*14.0)
		m().upper_arm_l.rotation.x = lerp(m().upper_arm_l.rotation.x, -0.40, delta*18.0)
		m().upper_arm_r.rotation.x = lerp(m().upper_arm_r.rotation.x, -0.40, delta*18.0)
	elif prog < 0.60:
		var p: float = (prog - 0.20) / 0.40
		m().rig.rotation.x = lerp(m().rig.rotation.x, 0.30 + p * 0.50, delta*14.0)
		m().rig.rotation.z = lerp(m().rig.rotation.z, -0.08 - p * 0.18, delta*12.0)
		m().rig.position.y = lerp(m().rig.position.y, -p * 0.14, delta*10.0)
		m().spine.rotation.x = lerp(m().spine.rotation.x, 0.20 + p * 0.30, delta*14.0)
		m().chest.rotation.x = lerp(m().chest.rotation.x, 0.22 + p * 0.34, delta*14.0)
		m().head.rotation.x = lerp(m().head.rotation.x, -0.16 - p * 0.20, delta*12.0)
		m().thigh_l.rotation.x = lerp(m().thigh_l.rotation.x, 0.60, delta*14.0)
		m().thigh_r.rotation.x = lerp(m().thigh_r.rotation.x, 0.60, delta*14.0)
		m().shin_l.rotation.x = lerp(m().shin_l.rotation.x, 1.00, delta*14.0)
		m().shin_r.rotation.x = lerp(m().shin_r.rotation.x, 1.00, delta*14.0)
	else:
		m().rig.rotation.x = lerp(m().rig.rotation.x, 0.80, delta*8.0)
		m().rig.rotation.z = lerp(m().rig.rotation.z, -0.26, delta*8.0)
		m().rig.position.y = lerp(m().rig.position.y, -0.14, delta*6.0)

func _set_guard_arms(delta: float, left_raise: float, right_raise: float) -> void:
	m().shoulder_l.rotation.z = lerp(m().shoulder_l.rotation.z, 0.12, delta * 8.0)
	m().shoulder_r.rotation.z = lerp(m().shoulder_r.rotation.z, -0.12, delta * 8.0)
	m().upper_arm_l.rotation.x = lerp(m().upper_arm_l.rotation.x, left_raise, delta * 8.0)
	m().upper_arm_l.rotation.z = lerp(m().upper_arm_l.rotation.z, 0.26, delta * 8.0)
	m().lower_arm_l.rotation.x = lerp(m().lower_arm_l.rotation.x, -0.98, delta * 8.0)
	m().lower_arm_l.rotation.z = lerp(m().lower_arm_l.rotation.z, -0.14, delta * 8.0)
	m().hand_l.rotation.x = lerp(m().hand_l.rotation.x, -0.10, delta * 8.0)
	m().hand_l.rotation.z = lerp(m().hand_l.rotation.z, -0.04, delta * 8.0)
	m().upper_arm_r.rotation.x = lerp(m().upper_arm_r.rotation.x, right_raise, delta * 8.0)
	m().upper_arm_r.rotation.z = lerp(m().upper_arm_r.rotation.z, -0.26, delta * 8.0)
	m().lower_arm_r.rotation.x = lerp(m().lower_arm_r.rotation.x, -0.98, delta * 8.0)
	m().lower_arm_r.rotation.z = lerp(m().lower_arm_r.rotation.z, 0.14, delta * 8.0)
	m().hand_r.rotation.x = lerp(m().hand_r.rotation.x, -0.10, delta * 8.0)
	m().hand_r.rotation.z = lerp(m().hand_r.rotation.z, 0.04, delta * 8.0)

func _fists_forward(delta: float, spread: float) -> void:
	m().hand_l.rotation.z = lerp(m().hand_l.rotation.z, -spread, delta * 10.0)
	m().hand_r.rotation.z = lerp(m().hand_r.rotation.z, spread, delta * 10.0)
	m().hand_l.rotation.x = lerp(m().hand_l.rotation.x, -0.18, delta * 10.0)
	m().hand_r.rotation.x = lerp(m().hand_r.rotation.x, -0.18, delta * 10.0)

func _sway_cloth(delta: float, t: float, cape_amp: float, panel_amp: float) -> void:
	for i in range(m().cape.size()):
		var offset: float = float(i) * 0.45
		m().cape[i].rotation.x = lerp(m().cape[i].rotation.x, 0.12 + sin(t * cape_wave_speed + offset) * cape_amp, delta * 6.0)
		m().cape[i].rotation.y = lerp(m().cape[i].rotation.y, sin(t * 1.4 + offset) * 0.06, delta * 5.0)
	for i in range(m().cloth_panels.size()):
		var sign: float = -1.0 + float(i)
		m().cloth_panels[i].rotation.x = lerp(m().cloth_panels[i].rotation.x, 0.04 + abs(sin(t * 3.0 + float(i) * 0.6)) * panel_amp, delta * 7.0)
		m().cloth_panels[i].rotation.y = lerp(m().cloth_panels[i].rotation.y, sign * 0.05, delta * 5.0)
	for i in range(m().back_spikes.size()):
		m().back_spikes[i].rotation.x = lerp(m().back_spikes[i].rotation.x, -0.04 + sin(t * 2.0 + float(i) * 0.35) * 0.03, delta * 6.0)

func _beam_progress() -> float:
	if base.has_method("get_beam_progress"):
		return float(base.call("get_beam_progress"))
	if base.has_method("get_attack_progress"):
		return float(base.call("get_attack_progress"))
	return 0.0

func _stomp_progress() -> float:
	if base.has_method("get_stomp_progress"):
		return float(base.call("get_stomp_progress"))
	return 0.0

func _is_stomp_airborne() -> bool:
	if base.has_method("is_stomp_airborne"):
		return bool(base.call("is_stomp_airborne"))
	return false

func _has_stomp_impacted() -> bool:
	if base.has_method("has_stomp_impacted"):
		return bool(base.call("has_stomp_impacted"))
	return false
