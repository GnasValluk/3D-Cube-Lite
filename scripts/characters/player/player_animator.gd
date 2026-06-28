class_name PlayerAnimator

var walk_cycle_speed: float = 7.0
var sprint_cycle_mult: float = 1.6
var idle_breathe_speed: float = 1.0

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
		CharacterBase.State.DASH:
			_dash(delta, t)
		CharacterBase.State.JUMP:
			_air(delta, t)
		CharacterBase.State.FALL:
			_air(delta, t)
		CharacterBase.State.HIT:
			_hit(delta, t)
		CharacterBase.State.DEAD:
			_dead(delta, t)
		CharacterBase.State.SWIM:
			_swim(delta, t)

func _idle(delta: float, t: float) -> void:
	var b: float = sin(t * idle_breathe_speed)
	mesh.rig.position.y = lerp(mesh.rig.position.y, 0.04, delta * 6.0)
	mesh.rig.rotation.x = lerp(mesh.rig.rotation.x, 0.0, delta * 7.0)
	mesh.head.rotation.x = lerp(mesh.head.rotation.x, b * 0.02, delta * 5.0)
	mesh.head.rotation.y = lerp(mesh.head.rotation.y, sin(t * 0.3) * 0.06, delta * 4.0)
	mesh.body.rotation.x = lerp(mesh.body.rotation.x, b * 0.01, delta * 5.0)
	mesh.arm_l.rotation.x = lerp(mesh.arm_l.rotation.x, -0.10, delta * 6.0)
	mesh.arm_r.rotation.x = lerp(mesh.arm_r.rotation.x, -0.10, delta * 6.0)
	mesh.leg_l.rotation.x = lerp(mesh.leg_l.rotation.x, 0.05, delta * 6.0)
	mesh.leg_r.rotation.x = lerp(mesh.leg_r.rotation.x, 0.05, delta * 6.0)

func _walk(delta: float, t: float, mult: float) -> void:
	var cyc: float = t * walk_cycle_speed * mult
	mesh.rig.position.y = 0.04 + abs(sin(cyc * 0.9)) * (0.03 + mult * 0.02)
	mesh.rig.rotation.x = lerp(mesh.rig.rotation.x, -0.04 * mult, delta * 8.0)
	mesh.rig.rotation.z = sin(cyc) * (0.02 + mult * 0.01)
	mesh.head.rotation.y = lerp(mesh.head.rotation.y, sin(cyc) * -0.06, delta * 6.0)
	mesh.body.rotation.x = lerp(mesh.body.rotation.x, sin(cyc * 0.5) * 0.03, delta * 5.0)
	mesh.arm_l.rotation.x = sin(cyc + PI) * (0.30 + mult * 0.10)
	mesh.arm_r.rotation.x = sin(cyc) * (0.30 + mult * 0.10)
	mesh.leg_l.rotation.x = sin(cyc) * (0.40 + mult * 0.10)
	mesh.leg_r.rotation.x = sin(cyc + PI) * (0.40 + mult * 0.10)

func _dash(delta: float, _t: float) -> void:
	mesh.rig.position.y = lerp(mesh.rig.position.y, 0.02, delta * 18.0)
	mesh.rig.rotation.x = lerp(mesh.rig.rotation.x, 0.30, delta * 18.0)
	mesh.head.rotation.x = lerp(mesh.head.rotation.x, -0.15, delta * 14.0)
	mesh.body.rotation.x = lerp(mesh.body.rotation.x, 0.20, delta * 16.0)
	mesh.arm_l.rotation.x = lerp(mesh.arm_l.rotation.x, -0.30, delta * 16.0)
	mesh.arm_r.rotation.x = lerp(mesh.arm_r.rotation.x, -0.30, delta * 16.0)
	mesh.leg_l.rotation.x = lerp(mesh.leg_l.rotation.x, -0.40, delta * 18.0)
	mesh.leg_r.rotation.x = lerp(mesh.leg_r.rotation.x, -0.40, delta * 18.0)

func _air(delta: float, t: float) -> void:
	var rising: bool = base._state == CharacterBase.State.JUMP
	var tuck: float
	if rising:
		tuck = clamp(base.velocity.y / base._jump_v, 0.0, 1.0)
	else:
		tuck = clamp(1.0 + base.velocity.y / base._jump_v, 0.0, 1.0) * 0.5
	mesh.rig.position.y = lerp(mesh.rig.position.y, 0.04, delta * 6.0)
	mesh.rig.rotation.x = lerp(mesh.rig.rotation.x, 0.02, delta * 8.0)
	mesh.head.rotation.x = lerp(mesh.head.rotation.x, -0.04, delta * 6.0)
	mesh.body.rotation.x = lerp(mesh.body.rotation.x, -0.04 + tuck * 0.12, delta * 8.0)
	mesh.arm_l.rotation.x = lerp(mesh.arm_l.rotation.x, -0.30 - tuck * 0.30, delta * 8.0)
	mesh.arm_r.rotation.x = lerp(mesh.arm_r.rotation.x, -0.30 - tuck * 0.30, delta * 8.0)
	mesh.leg_l.rotation.x = lerp(mesh.leg_l.rotation.x, -0.20 - tuck * 0.40, delta * 10.0)
	mesh.leg_r.rotation.x = lerp(mesh.leg_r.rotation.x, -0.20 - tuck * 0.40, delta * 10.0)

func _swim(delta: float, t: float) -> void:
	var cyc: float = t * 4.0
	mesh.rig.position.y = lerp(mesh.rig.position.y, 0.02, delta * 6.0)
	mesh.rig.rotation.x = lerp(mesh.rig.rotation.x, 0.15, delta * 8.0)
	mesh.head.rotation.x = lerp(mesh.head.rotation.x, -0.10, delta * 6.0)
	mesh.arm_l.rotation.x = sin(cyc) * 0.60
	mesh.arm_r.rotation.x = sin(cyc + PI) * 0.60
	mesh.leg_l.rotation.x = sin(cyc + PI) * 0.40
	mesh.leg_r.rotation.x = sin(cyc) * 0.40

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
