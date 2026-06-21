## raptor/raptor_animator.gd
## Tất cả animation states của Raptor.
## Nhận RaptorMesh + CharacterBase state để điều khiển rotations.

class_name RaptorAnimator

# ── Tuning params ─────────────────────────────────────────────────────────────
var run_cycle_speed:   float = 11.0
var sprint_cycle_mult: float = 1.6
var idle_breathe_spd:  float = 1.2
var tail_sway_speed:   float = 3.5

# ── Refs (set từ raptor_character.gd) ────────────────────────────────────────
var mesh: RaptorMesh
var base: CharacterBase   # để đọc _state, _time, velocity, _jump_v, _attack_timer

func setup(m: RaptorMesh, b: CharacterBase) -> void:
	mesh = m; base = b

# ── Dispatcher ────────────────────────────────────────────────────────────────
func animate(delta: float) -> void:
	var t: float = base._time
	match base._state:
		CharacterBase.State.IDLE:   _idle(delta, t)
		CharacterBase.State.WALK:   _walk(delta, t, 1.0)
		CharacterBase.State.SPRINT: _walk(delta, t, sprint_cycle_mult)
		CharacterBase.State.CROUCH: _crouch(delta, t)
		CharacterBase.State.DASH:   _dash(delta, t)
		CharacterBase.State.ATTACK: _attack(delta, t)
		CharacterBase.State.JUMP:   _air(delta, t)
		CharacterBase.State.FALL:   _air(delta, t)

# ── IDLE ──────────────────────────────────────────────────────────────────────
func _idle(delta: float, t: float) -> void:
	var b := sin(t * idle_breathe_spd)
	mesh.rig.position.y = lerp(mesh.rig.position.y, 0.10, delta*8.0)
	mesh.rig.rotation.x = lerp(mesh.rig.rotation.x, 0.0,  delta*10.0)
	mesh.rig.rotation.z = b * 0.012
	mesh.neck.rotation.x = lerp(mesh.neck.rotation.x, -0.28+b*0.03, delta*5.0)
	mesh.neck.rotation.y = b * 0.04
	mesh.snout_bot.rotation.x = lerp(mesh.snout_bot.rotation.x, 0.0, delta*4.0)
	mesh.arm_l.rotation.x = lerp(mesh.arm_l.rotation.x, -0.15, delta*5.0)
	mesh.arm_r.rotation.x = lerp(mesh.arm_r.rotation.x, -0.15, delta*5.0)
	mesh.thigh_l.rotation.x = lerp(mesh.thigh_l.rotation.x, 0.15, delta*6.0)
	mesh.shin_l.rotation.x  = lerp(mesh.shin_l.rotation.x,  0.30, delta*6.0)
	mesh.foot_l.rotation.x  = lerp(mesh.foot_l.rotation.x, -0.15, delta*6.0)
	mesh.thigh_r.rotation.x = lerp(mesh.thigh_r.rotation.x, 0.15, delta*6.0)
	mesh.shin_r.rotation.x  = lerp(mesh.shin_r.rotation.x,  0.30, delta*6.0)
	mesh.foot_r.rotation.x  = lerp(mesh.foot_r.rotation.x, -0.15, delta*6.0)
	for i in range(mesh.tail.size()):
		mesh.tail[i].rotation.y = sin(t*tail_sway_speed*0.4+float(i)*0.6)*(0.07+float(i)*0.04)
		mesh.tail[i].rotation.x = lerp(mesh.tail[i].rotation.x, 0.04+float(i)*0.03, delta*3.0)

# ── WALK / SPRINT ─────────────────────────────────────────────────────────────
func _walk(delta: float, t: float, mult: float) -> void:
	var cyc := t * run_cycle_speed * mult
	mesh.rig.position.y = 0.10 + abs(sin(cyc)) * (0.04 + mult*0.02)
	mesh.rig.rotation.x = lerp(mesh.rig.rotation.x, 0.0, delta*10.0)
	mesh.rig.rotation.z = sin(cyc*0.5) * (0.03 + mult*0.01)
	mesh.neck.rotation.x = -0.30 + sin(cyc)*0.07
	mesh.neck.rotation.y = lerp(mesh.neck.rotation.y, 0.0, delta*8.0)
	mesh.snout_bot.rotation.x = abs(sin(cyc*0.5)) * 0.10
	mesh.arm_l.rotation.x = sin(cyc+PI)*0.25
	mesh.arm_r.rotation.x = sin(cyc)   *0.25
	mesh.thigh_l.rotation.x =  sin(cyc)         * 0.55
	mesh.shin_l.rotation.x  =  abs(sin(cyc))    * 0.70
	mesh.foot_l.rotation.x  = -abs(sin(cyc))    * 0.30
	mesh.thigh_r.rotation.x =  sin(cyc+PI)      * 0.55
	mesh.shin_r.rotation.x  =  abs(sin(cyc+PI)) * 0.70
	mesh.foot_r.rotation.x  = -abs(sin(cyc+PI)) * 0.30
	for i in range(mesh.tail.size()):
		mesh.tail[i].rotation.y = sin(t*tail_sway_speed+float(i)*0.55)*(0.15+float(i)*0.06)
		mesh.tail[i].rotation.x = 0.06+float(i)*0.04

# ── CROUCH ────────────────────────────────────────────────────────────────────
func _crouch(delta: float, t: float) -> void:
	mesh.rig.position.y = lerp(mesh.rig.position.y, -0.12, delta*10.0)
	mesh.rig.rotation.x = lerp(mesh.rig.rotation.x,  0.20, delta*8.0)
	mesh.neck.rotation.x = lerp(mesh.neck.rotation.x, -0.10, delta*6.0)
	mesh.snout_bot.rotation.x = lerp(mesh.snout_bot.rotation.x, 0.0, delta*4.0)
	mesh.arm_l.rotation.x = lerp(mesh.arm_l.rotation.x, 0.30, delta*6.0)
	mesh.arm_r.rotation.x = lerp(mesh.arm_r.rotation.x, 0.30, delta*6.0)
	mesh.thigh_l.rotation.x = lerp(mesh.thigh_l.rotation.x, 0.60, delta*8.0)
	mesh.shin_l.rotation.x  = lerp(mesh.shin_l.rotation.x,  0.80, delta*8.0)
	mesh.foot_l.rotation.x  = lerp(mesh.foot_l.rotation.x, -0.40, delta*8.0)
	mesh.thigh_r.rotation.x = lerp(mesh.thigh_r.rotation.x, 0.60, delta*8.0)
	mesh.shin_r.rotation.x  = lerp(mesh.shin_r.rotation.x,  0.80, delta*8.0)
	mesh.foot_r.rotation.x  = lerp(mesh.foot_r.rotation.x, -0.40, delta*8.0)
	for i in range(mesh.tail.size()):
		mesh.tail[i].rotation.x = lerp(mesh.tail[i].rotation.x, -0.10+float(i)*0.02, delta*5.0)
		mesh.tail[i].rotation.y = sin(t*tail_sway_speed*0.3+float(i)*0.5)*(0.04+float(i)*0.02)

# ── DASH ──────────────────────────────────────────────────────────────────────
func _dash(delta: float, _t: float) -> void:
	mesh.rig.position.y  = lerp(mesh.rig.position.y,  0.06, delta*20.0)
	mesh.rig.rotation.x  = lerp(mesh.rig.rotation.x,  0.35, delta*20.0)
	mesh.neck.rotation.x = lerp(mesh.neck.rotation.x, 0.10, delta*15.0)
	mesh.arm_l.rotation.x = lerp(mesh.arm_l.rotation.x, -0.60, delta*20.0)
	mesh.arm_r.rotation.x = lerp(mesh.arm_r.rotation.x, -0.60, delta*20.0)
	mesh.thigh_l.rotation.x = lerp(mesh.thigh_l.rotation.x, -0.50, delta*20.0)
	mesh.shin_l.rotation.x  = lerp(mesh.shin_l.rotation.x,   0.20, delta*20.0)
	mesh.thigh_r.rotation.x = lerp(mesh.thigh_r.rotation.x, -0.50, delta*20.0)
	mesh.shin_r.rotation.x  = lerp(mesh.shin_r.rotation.x,   0.20, delta*20.0)
	for i in range(mesh.tail.size()):
		mesh.tail[i].rotation.x = lerp(mesh.tail[i].rotation.x, -0.15, delta*18.0)
		mesh.tail[i].rotation.y = lerp(mesh.tail[i].rotation.y,  0.0,  delta*18.0)

# ── ATTACK ────────────────────────────────────────────────────────────────────
func _attack(delta: float, _t: float) -> void:
	var prog: float = 1.0 - (base._attack_timer / base.attack_duration)
	if prog < 0.4:
		mesh.neck.rotation.x      = lerp(mesh.neck.rotation.x,       0.20, delta*18.0)
		mesh.snout_bot.rotation.x = lerp(mesh.snout_bot.rotation.x,  0.0,  delta*10.0)
		mesh.arm_l.rotation.x     = lerp(mesh.arm_l.rotation.x,     -0.80, delta*18.0)
		mesh.arm_r.rotation.x     = lerp(mesh.arm_r.rotation.x,     -0.80, delta*18.0)
		mesh.rig.rotation.x       = lerp(mesh.rig.rotation.x,        -0.10, delta*12.0)
	else:
		mesh.neck.rotation.x      = lerp(mesh.neck.rotation.x,      -0.55, delta*30.0)
		mesh.snout_bot.rotation.x = lerp(mesh.snout_bot.rotation.x,  0.28, delta*30.0)
		mesh.arm_l.rotation.x     = lerp(mesh.arm_l.rotation.x,      0.70, delta*30.0)
		mesh.arm_r.rotation.x     = lerp(mesh.arm_r.rotation.x,      0.70, delta*30.0)
		mesh.rig.rotation.x       = lerp(mesh.rig.rotation.x,         0.15, delta*20.0)
		for i in range(mesh.tail.size()):
			mesh.tail[i].rotation.x = lerp(mesh.tail[i].rotation.x, 0.20+float(i)*0.08, delta*20.0)
	mesh.thigh_l.rotation.x = lerp(mesh.thigh_l.rotation.x, 0.20, delta*8.0)
	mesh.shin_l.rotation.x  = lerp(mesh.shin_l.rotation.x,  0.35, delta*8.0)
	mesh.thigh_r.rotation.x = lerp(mesh.thigh_r.rotation.x, 0.20, delta*8.0)
	mesh.shin_r.rotation.x  = lerp(mesh.shin_r.rotation.x,  0.35, delta*8.0)

# ── AIR ───────────────────────────────────────────────────────────────────────
func _air(delta: float, _t: float) -> void:
	mesh.rig.position.y = lerp(mesh.rig.position.y, 0.10, delta*5.0)
	var rising: bool = base._state == CharacterBase.State.JUMP
	var tuck: float
	if rising: tuck = clamp(base.velocity.y / base._jump_v, 0.0, 1.0)
	else:      tuck = clamp(1.0 + base.velocity.y / base._jump_v, 0.0, 1.0) * 0.3
	mesh.thigh_l.rotation.x = lerp(mesh.thigh_l.rotation.x, -0.30-tuck*0.5, delta*12.0)
	mesh.shin_l.rotation.x  = lerp(mesh.shin_l.rotation.x,   0.60+tuck*0.6, delta*12.0)
	mesh.foot_l.rotation.x  = lerp(mesh.foot_l.rotation.x,  -0.40,           delta*10.0)
	mesh.thigh_r.rotation.x = lerp(mesh.thigh_r.rotation.x, -0.30-tuck*0.5, delta*12.0)
	mesh.shin_r.rotation.x  = lerp(mesh.shin_r.rotation.x,   0.60+tuck*0.6, delta*12.0)
	mesh.foot_r.rotation.x  = lerp(mesh.foot_r.rotation.x,  -0.40,           delta*10.0)
	var fall_t: float = clamp(-base.velocity.y / 6.0, 0.0, 1.0)
	mesh.neck.rotation.x = lerp(mesh.neck.rotation.x, -0.50+fall_t*0.20, delta*8.0)
	mesh.rig.rotation.x  = lerp(mesh.rig.rotation.x,   0.0,               delta*10.0)
	for i in range(mesh.tail.size()):
		var droop: float = (0.15+float(i)*0.08) if not rising else -0.05
		mesh.tail[i].rotation.x = lerp(mesh.tail[i].rotation.x, droop, delta*6.0)
		mesh.tail[i].rotation.y = lerp(mesh.tail[i].rotation.y, 0.0,   delta*5.0)
