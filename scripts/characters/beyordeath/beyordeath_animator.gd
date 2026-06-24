class_name BeyordeathAnimator

var mesh: BeyordeathMesh
var base: CharacterBase

var _walk_cycle: float = 10.0
var _sprint_mult: float = 1.6

func setup(m: BeyordeathMesh, b: CharacterBase) -> void:
	mesh = m; base = b

func animate(delta: float) -> void:
	var t: float = base._time
	match base._state:
		CharacterBase.State.IDLE:   _idle(delta, t)
		CharacterBase.State.WALK:   _walk(delta, t)
		CharacterBase.State.SPRINT: _walk(delta, t)
		CharacterBase.State.DASH:   _dash(delta, t)
		CharacterBase.State.ATTACK: _attack(delta, t)
		CharacterBase.State.DEVOUR: _devour(delta, t)
		CharacterBase.State.JUMP:   _air(delta, t)
		CharacterBase.State.FALL:   _air(delta, t)
		CharacterBase.State.HIT:    _hit(delta, t)
		CharacterBase.State.DEAD:   _dead(delta, t)

func _idle(delta: float, t: float) -> void:
	var b := sin(t * 1.8)
	mesh.rig.position.y = lerp(mesh.rig.position.y, 0.10, delta * 8.0)
	mesh.rig.rotation.z = b * 0.012
	mesh.head.rotation.x = lerp(mesh.head.rotation.x, b * 0.03, delta * 4.0)
	mesh.arm_l.rotation.x = lerp(mesh.arm_l.rotation.x, -0.10, delta * 5.0)
	mesh.arm_r.rotation.x = lerp(mesh.arm_r.rotation.x, -0.10, delta * 5.0)
	mesh.forearm_l.rotation.x = lerp(mesh.forearm_l.rotation.x, 0.0, delta * 5.0)
	mesh.forearm_r.rotation.x = lerp(mesh.forearm_r.rotation.x, 0.0, delta * 5.0)
	mesh.thigh_l.rotation.x = lerp(mesh.thigh_l.rotation.x, 0.10, delta * 5.0)
	mesh.shin_l.rotation.x = lerp(mesh.shin_l.rotation.x, 0.20, delta * 5.0)
	mesh.foot_l.rotation.x = lerp(mesh.foot_l.rotation.x, -0.08, delta * 5.0)
	mesh.thigh_r.rotation.x = lerp(mesh.thigh_r.rotation.x, 0.10, delta * 5.0)
	mesh.shin_r.rotation.x = lerp(mesh.shin_r.rotation.x, 0.20, delta * 5.0)
	mesh.foot_r.rotation.x = lerp(mesh.foot_r.rotation.x, -0.08, delta * 5.0)

func _walk(delta: float, t: float) -> void:
	var cyc := t * _walk_cycle
	var mult: float = _sprint_mult if base._state == CharacterBase.State.SPRINT else 1.0
	cyc *= mult
	mesh.rig.position.y = 0.10 + abs(sin(cyc)) * 0.04 * mult
	mesh.arm_l.rotation.x = sin(cyc + PI) * 0.30 * mult
	mesh.arm_r.rotation.x = sin(cyc) * 0.30 * mult
	mesh.forearm_l.rotation.x = lerp(mesh.forearm_l.rotation.x, 0.0, delta * 8.0)
	mesh.forearm_r.rotation.x = lerp(mesh.forearm_r.rotation.x, 0.0, delta * 8.0)
	mesh.head.rotation.x = lerp(mesh.head.rotation.x, -0.05, delta * 5.0)
	mesh.thigh_l.rotation.x = sin(cyc) * 0.40
	mesh.shin_l.rotation.x = abs(sin(cyc)) * 0.50
	mesh.foot_l.rotation.x = -abs(sin(cyc)) * 0.20
	mesh.thigh_r.rotation.x = sin(cyc + PI) * 0.40
	mesh.shin_r.rotation.x = abs(sin(cyc + PI)) * 0.50
	mesh.foot_r.rotation.x = -abs(sin(cyc + PI)) * 0.20

func _dash(delta: float, _t: float) -> void:
	mesh.rig.position.y = lerp(mesh.rig.position.y, 0.06, delta * 20.0)
	mesh.rig.rotation.x = lerp(mesh.rig.rotation.x, 0.30, delta * 20.0)
	mesh.head.rotation.x = lerp(mesh.head.rotation.x, 0.15, delta * 15.0)
	mesh.arm_l.rotation.x = lerp(mesh.arm_l.rotation.x, -0.50, delta * 20.0)
	mesh.arm_r.rotation.x = lerp(mesh.arm_r.rotation.x, -0.50, delta * 20.0)
	mesh.forearm_l.rotation.x = lerp(mesh.forearm_l.rotation.x, 0.30, delta * 20.0)
	mesh.forearm_r.rotation.x = lerp(mesh.forearm_r.rotation.x, 0.30, delta * 20.0)
	mesh.thigh_l.rotation.x = lerp(mesh.thigh_l.rotation.x, -0.40, delta * 20.0)
	mesh.shin_l.rotation.x = lerp(mesh.shin_l.rotation.x, 0.10, delta * 20.0)
	mesh.thigh_r.rotation.x = lerp(mesh.thigh_r.rotation.x, -0.40, delta * 20.0)
	mesh.shin_r.rotation.x = lerp(mesh.shin_r.rotation.x, 0.10, delta * 20.0)

func _attack(delta: float, _t: float) -> void:
	var prog: float = 1.0 - (base._attack_timer / max(base.attack_duration, 0.001))
	var recoil: float = sin(prog * PI * 3.0) * 0.08
	mesh.rig.rotation.x = lerp(mesh.rig.rotation.x, 0.05, delta * 14.0)
	mesh.arm_l.rotation.x = lerp(mesh.arm_l.rotation.x, -0.40 + recoil, delta * 24.0)
	mesh.arm_r.rotation.x = lerp(mesh.arm_r.rotation.x, -0.40 + recoil, delta * 24.0)
	mesh.forearm_l.rotation.x = lerp(mesh.forearm_l.rotation.x, 0.40, delta * 20.0)
	mesh.forearm_r.rotation.x = lerp(mesh.forearm_r.rotation.x, 0.40, delta * 20.0)
	mesh.head.rotation.x = lerp(mesh.head.rotation.x, 0.08, delta * 10.0)

func _devour(delta: float, _t: float) -> void:
	mesh.rig.position.y = lerp(mesh.rig.position.y, 0.10, delta * 8.0)
	mesh.rig.rotation.x = lerp(mesh.rig.rotation.x, 0.0, delta * 8.0)
	mesh.arm_l.rotation.x = lerp(mesh.arm_l.rotation.x, -0.15, delta * 8.0)
	mesh.arm_r.rotation.x = lerp(mesh.arm_r.rotation.x, -0.15, delta * 8.0)
	mesh.thigh_l.rotation.x = lerp(mesh.thigh_l.rotation.x, 0.10, delta * 8.0)
	mesh.shin_l.rotation.x = lerp(mesh.shin_l.rotation.x, 0.20, delta * 8.0)
	mesh.foot_l.rotation.x = lerp(mesh.foot_l.rotation.x, -0.08, delta * 8.0)
	mesh.thigh_r.rotation.x = lerp(mesh.thigh_r.rotation.x, 0.10, delta * 8.0)
	mesh.shin_r.rotation.x = lerp(mesh.shin_r.rotation.x, 0.20, delta * 8.0)
	mesh.foot_r.rotation.x = lerp(mesh.foot_r.rotation.x, -0.08, delta * 8.0)
	mesh.head.rotation.x = lerp(mesh.head.rotation.x, 0.0, delta * 6.0)

func _hit(delta: float, _t: float) -> void:
	mesh.rig.position.y = lerp(mesh.rig.position.y, 0.06, delta * 14.0)
	mesh.rig.rotation.x = lerp(mesh.rig.rotation.x, 0.25, delta * 14.0)
	mesh.rig.rotation.z = lerp(mesh.rig.rotation.z, 0.06, delta * 12.0)
	mesh.head.rotation.x = lerp(mesh.head.rotation.x, -0.30, delta * 20.0)
	mesh.arm_l.rotation.x = lerp(mesh.arm_l.rotation.x, -0.40, delta * 20.0)
	mesh.arm_r.rotation.x = lerp(mesh.arm_r.rotation.x, -0.40, delta * 20.0)

func _dead(delta: float, _t: float) -> void:
	var prog: float = 1.0 - (base._death_timer / 1.8)
	if prog < 0.30:
		mesh.rig.rotation.x = lerp(mesh.rig.rotation.x, prog / 0.30 * 0.80, delta * 16.0)
		mesh.rig.position.y = lerp(mesh.rig.position.y, 0.08, delta * 12.0)
	else:
		mesh.rig.rotation.x = lerp(mesh.rig.rotation.x, 1.0, delta * 10.0)
		mesh.rig.position.y = lerp(mesh.rig.position.y, -0.05, delta * 8.0)

func _air(delta: float, _t: float) -> void:
	var falling: float = clamp(-base.velocity.y / 6.0, 0.0, 1.0)
	mesh.arm_l.rotation.x = lerp(mesh.arm_l.rotation.x, -0.20, delta * 8.0)
	mesh.arm_r.rotation.x = lerp(mesh.arm_r.rotation.x, -0.20, delta * 8.0)
	mesh.forearm_l.rotation.x = lerp(mesh.forearm_l.rotation.x, 0.20, delta * 8.0)
	mesh.forearm_r.rotation.x = lerp(mesh.forearm_r.rotation.x, 0.20, delta * 8.0)
	mesh.thigh_l.rotation.x = lerp(mesh.thigh_l.rotation.x, -0.20 - falling * 0.30, delta * 10.0)
	mesh.shin_l.rotation.x = lerp(mesh.shin_l.rotation.x, 0.40 + falling * 0.40, delta * 10.0)
	mesh.foot_l.rotation.x = lerp(mesh.foot_l.rotation.x, -0.30, delta * 8.0)
	mesh.thigh_r.rotation.x = lerp(mesh.thigh_r.rotation.x, -0.20 - falling * 0.30, delta * 10.0)
	mesh.shin_r.rotation.x = lerp(mesh.shin_r.rotation.x, 0.40 + falling * 0.40, delta * 10.0)
	mesh.foot_r.rotation.x = lerp(mesh.foot_r.rotation.x, -0.30, delta * 8.0)
