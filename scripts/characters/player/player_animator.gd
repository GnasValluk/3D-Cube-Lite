class_name PlayerAnimator

var walk_cycle_speed: float = 6.5
var sprint_cycle_mult: float = 1.6
var idle_breathe_speed: float = 0.9
var swim_cycle_speed: float = 4.5

var mesh: PlayerMesh
var base: CharacterBase

func setup(m: PlayerMesh, b: CharacterBase) -> void:
	mesh = m
	base = b

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

func _idle(delta: float, t: float) -> void:
	# Chibi idle: nhún nhẹ, đầu lắc lư cute
	var b: float = sin(t * idle_breathe_speed)
	mesh.rig.position.y = lerp(mesh.rig.position.y, 0.02 + abs(b) * 0.008, delta * 5.0)
	mesh.rig.rotation.x = lerp(mesh.rig.rotation.x, 0.0, delta * 7.0)
	mesh.rig.rotation.z = lerp(mesh.rig.rotation.z, b * 0.015, delta * 4.0)
	# Đầu to chibi: lắc nhẹ trái phải, gật nhẹ
	mesh.head.rotation.x = lerp(mesh.head.rotation.x, b * 0.03, delta * 4.0)
	mesh.head.rotation.y = lerp(mesh.head.rotation.y, sin(t * 0.4) * 0.08, delta * 3.0)
	mesh.head.rotation.z = lerp(mesh.head.rotation.z, sin(t * 0.5) * 0.04, delta * 3.0)
	mesh.body.rotation.x = lerp(mesh.body.rotation.x, b * 0.015, delta * 5.0)
	mesh.backpack.position.z = lerp(mesh.backpack.position.z, -0.02, delta * 5.0)
	# Tay đung đưa nhẹ
	mesh.arm_l.rotation.x = lerp(mesh.arm_l.rotation.x, -0.06 + b * 0.03, delta * 5.0)
	mesh.arm_r.rotation.x = lerp(mesh.arm_r.rotation.x, -0.06 + b * 0.03, delta * 5.0)
	mesh.arm_l.rotation.z = lerp(mesh.arm_l.rotation.z,  0.04 + b * 0.02, delta * 4.0)
	mesh.arm_r.rotation.z = lerp(mesh.arm_r.rotation.z, -0.04 - b * 0.02, delta * 4.0)
	# Chân nhỏ đứng yên
	mesh.leg_l.rotation.x = lerp(mesh.leg_l.rotation.x, 0.02, delta * 6.0)
	mesh.leg_r.rotation.x = lerp(mesh.leg_r.rotation.x, 0.02, delta * 6.0)

func _walk(delta: float, t: float, mult: float) -> void:
	# Chibi walk: nhún nhiều hơn, đầu to lắc cute
	var cyc: float = t * walk_cycle_speed * mult
	mesh.rig.position.y = 0.02 + abs(sin(cyc)) * (0.04 + mult * 0.018)
	mesh.rig.rotation.x = lerp(mesh.rig.rotation.x, -0.05 * mult, delta * 8.0)
	mesh.rig.rotation.z = sin(cyc) * (0.025 + mult * 0.012)
	# Đầu to chibi: lắc lư theo nhịp bước
	mesh.head.rotation.y = lerp(mesh.head.rotation.y, sin(cyc * 0.5) * 0.10 * mult, delta * 5.0)
	mesh.head.rotation.z = lerp(mesh.head.rotation.z, sin(cyc * 0.5) * 0.05, delta * 5.0)
	mesh.body.rotation.x = lerp(mesh.body.rotation.x, sin(cyc * 0.5) * 0.04, delta * 5.0)
	mesh.backpack.position.z = lerp(mesh.backpack.position.z, -0.02 + abs(sin(cyc * 0.5)) * 0.015, delta * 5.0)
	mesh.backpack.rotation.x = sin(cyc * 0.5) * 0.04
	# Tay đánh nhịp
	mesh.arm_l.rotation.x = sin(cyc + PI) * (0.28 + mult * 0.08)
	mesh.arm_r.rotation.x = sin(cyc) * (0.28 + mult * 0.08)
	mesh.arm_l.rotation.z = lerp(mesh.arm_l.rotation.z, 0.04, delta * 6.0)
	mesh.arm_r.rotation.z = lerp(mesh.arm_r.rotation.z, -0.04, delta * 6.0)
	# Chân ngắn chibi bước rộng hơn để cute
	mesh.leg_l.rotation.x = sin(cyc) * (0.50 + mult * 0.12)
	mesh.leg_r.rotation.x = sin(cyc + PI) * (0.50 + mult * 0.12)

func _crouch(delta: float, t: float) -> void:
	var cyc: float = t * walk_cycle_speed * 0.5
	mesh.rig.position.y = lerp(mesh.rig.position.y, -0.18, delta * 10.0)
	mesh.rig.rotation.x = lerp(mesh.rig.rotation.x, 0.18, delta * 8.0)
	mesh.head.rotation.x = lerp(mesh.head.rotation.x, 0.10, delta * 6.0)
	mesh.head.rotation.y = lerp(mesh.head.rotation.y, sin(t * 0.2) * 0.08, delta * 4.0)
	mesh.body.rotation.x = lerp(mesh.body.rotation.x, 0.08, delta * 6.0)
	mesh.backpack.position.z = lerp(mesh.backpack.position.z, -0.06, delta * 5.0)
	mesh.arm_l.rotation.x = sin(cyc + PI) * 0.20
	mesh.arm_r.rotation.x = sin(cyc) * 0.20
	mesh.leg_l.rotation.x = 0.30 + sin(cyc) * 0.20
	mesh.leg_r.rotation.x = 0.30 + sin(cyc + PI) * 0.20

func _dash(delta: float, _t: float) -> void:
	mesh.rig.position.y = lerp(mesh.rig.position.y, 0.02, delta * 18.0)
	mesh.rig.rotation.x = lerp(mesh.rig.rotation.x, 0.30, delta * 18.0)
	mesh.head.rotation.x = lerp(mesh.head.rotation.x, -0.15, delta * 14.0)
	mesh.body.rotation.x = lerp(mesh.body.rotation.x, 0.20, delta * 16.0)
	mesh.backpack.position.z = lerp(mesh.backpack.position.z, -0.06, delta * 12.0)
	mesh.arm_l.rotation.x = lerp(mesh.arm_l.rotation.x, -0.40, delta * 16.0)
	mesh.arm_r.rotation.x = lerp(mesh.arm_r.rotation.x, -0.40, delta * 16.0)
	mesh.leg_l.rotation.x = lerp(mesh.leg_l.rotation.x, -0.50, delta * 18.0)
	mesh.leg_r.rotation.x = lerp(mesh.leg_r.rotation.x, -0.50, delta * 18.0)

func _air(delta: float, t: float, rising: bool) -> void:
	var tuck: float
	if rising:
		tuck = clamp(base.velocity.y / base._jump_v, 0.0, 1.0)
	else:
		tuck = clamp(1.0 + base.velocity.y / base._jump_v, 0.0, 1.0) * 0.5
	mesh.rig.position.y = lerp(mesh.rig.position.y, 0.02, delta * 6.0)
	mesh.rig.rotation.x = lerp(mesh.rig.rotation.x, 0.02, delta * 8.0)
	# Đầu to chibi ngửa lên khi nhảy (cute)
	mesh.head.rotation.x = lerp(mesh.head.rotation.x, -0.10 + tuck * 0.06, delta * 6.0)
	mesh.head.rotation.z = lerp(mesh.head.rotation.z, 0.0, delta * 6.0)
	mesh.body.rotation.x = lerp(mesh.body.rotation.x, -0.04 + tuck * 0.10, delta * 8.0)
	mesh.backpack.position.z = lerp(mesh.backpack.position.z, -0.04 - tuck * 0.03, delta * 8.0)
	# Tay xoè ra hai bên khi nhảy (cute)
	mesh.arm_l.rotation.x = lerp(mesh.arm_l.rotation.x, -0.50 - tuck * 0.25, delta * 8.0)
	mesh.arm_r.rotation.x = lerp(mesh.arm_r.rotation.x, -0.50 - tuck * 0.25, delta * 8.0)
	mesh.arm_l.rotation.z = lerp(mesh.arm_l.rotation.z,  0.30 + tuck * 0.20, delta * 8.0)
	mesh.arm_r.rotation.z = lerp(mesh.arm_r.rotation.z, -0.30 - tuck * 0.20, delta * 8.0)
	# Chân thu lên
	mesh.leg_l.rotation.x = lerp(mesh.leg_l.rotation.x, -0.30 - tuck * 0.35, delta * 10.0)
	mesh.leg_r.rotation.x = lerp(mesh.leg_r.rotation.x, -0.30 - tuck * 0.35, delta * 10.0)

func _swim(delta: float, t: float) -> void:
	var cyc: float = t * swim_cycle_speed
	mesh.rig.position.y = lerp(mesh.rig.position.y, 0.02, delta * 6.0)
	mesh.rig.rotation.x = lerp(mesh.rig.rotation.x, 0.18, delta * 8.0)
	mesh.head.rotation.x = lerp(mesh.head.rotation.x, -0.12, delta * 6.0)
	mesh.body.rotation.x = sin(cyc * 0.5) * 0.06 + 0.10
	mesh.backpack.position.z = lerp(mesh.backpack.position.z, -0.04, delta * 5.0)
	mesh.arm_l.rotation.x = sin(cyc) * 0.60
	mesh.arm_r.rotation.x = sin(cyc + PI) * 0.60
	mesh.leg_l.rotation.x = sin(cyc + PI * 0.5) * 0.50
	mesh.leg_r.rotation.x = sin(cyc - PI * 0.5) * 0.50
	var kick: float = abs(sin(cyc * 1.5))
	mesh.rig.position.y += kick * 0.02

func _hit(delta: float, _t: float) -> void:
	var p: float = 1.0 - (base._hit_timer / 0.18)
	mesh.rig.position.y = lerp(mesh.rig.position.y, 0.03, delta * 14.0)
	mesh.rig.rotation.x = lerp(mesh.rig.rotation.x, 0.20 - p * 0.14, delta * 16.0)
	mesh.head.rotation.x = lerp(mesh.head.rotation.x, -0.15 + p * 0.10, delta * 16.0)
	mesh.body.rotation.x = lerp(mesh.body.rotation.x, 0.14 - p * 0.08, delta * 14.0)
	mesh.arm_l.rotation.x = lerp(mesh.arm_l.rotation.x, -0.30, delta * 20.0)
	mesh.arm_r.rotation.x = lerp(mesh.arm_r.rotation.x, -0.30, delta * 20.0)
	mesh.leg_l.rotation.x = lerp(mesh.leg_l.rotation.x, -0.08, delta * 12.0)
	mesh.leg_r.rotation.x = lerp(mesh.leg_r.rotation.x, -0.08, delta * 12.0)

func _dead(delta: float, t: float) -> void:
	var prog: float = 1.0 - (base._death_timer / 1.8)
	if prog < 0.30:
		var p: float = prog / 0.30
		mesh.rig.rotation.x = lerp(mesh.rig.rotation.x, p * 0.50, delta * 16.0)
		mesh.rig.rotation.z = lerp(mesh.rig.rotation.z, p * (-0.10), delta * 14.0)
		mesh.head.rotation.x = lerp(mesh.head.rotation.x, -p * 0.20, delta * 14.0)
	elif prog < 0.70:
		var p: float = (prog - 0.30) / 0.40
		mesh.rig.rotation.x = lerp(mesh.rig.rotation.x, 0.50 + p * 0.60, delta * 14.0)
		mesh.rig.position.y = lerp(mesh.rig.position.y, -p * 0.10, delta * 10.0)
	else:
		mesh.rig.rotation.x = lerp(mesh.rig.rotation.x, 1.10, delta * 8.0)
		mesh.rig.position.y = lerp(mesh.rig.position.y, -0.10, delta * 6.0)
