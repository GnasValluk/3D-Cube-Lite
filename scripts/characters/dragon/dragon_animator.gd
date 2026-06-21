## dragon/dragon_animator.gd
## Tất cả animation states của Dragon.

class_name DragonAnimator

var walk_cycle_speed:   float = 7.0
var sprint_cycle_mult:  float = 1.8
var idle_breathe_spd:   float = 0.9
var tail_wave_speed:    float = 2.8
var wing_flap_idle_spd: float = 1.4
var wing_flap_run_spd:  float = 3.2

var mesh: DragonMesh
var base: CharacterBase

func setup(m: DragonMesh, b: CharacterBase) -> void:
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

# ── Shorthand refs ────────────────────────────────────────────────────────────
func m() -> DragonMesh: return mesh

# ── IDLE ──────────────────────────────────────────────────────────────────────
func _idle(delta: float, t: float) -> void:
	var b  := sin(t * idle_breathe_spd)
	var bw := sin(t * wing_flap_idle_spd * 0.5)
	m().rig.position.y = lerp(m().rig.position.y, 0.10 + b*0.015, delta*6.0)
	m().rig.rotation.x = lerp(m().rig.rotation.x, 0.0, delta*8.0)
	m().rig.rotation.z = b * 0.008
	m().neck.rotation.x       = lerp(m().neck.rotation.x,  -0.35+b*0.04, delta*4.0)
	m().neck.rotation.y       = sin(t*0.5)*0.08
	m().neck2.rotation.x      = lerp(m().neck2.rotation.x, -0.25+b*0.03, delta*4.0)
	m().head_pivot.rotation.y = sin(t*0.4)*0.12
	m().jaw.rotation.x        = lerp(m().jaw.rotation.x, 0.04+b*0.02, delta*5.0)
	var wa: float = 0.28 + bw*0.08
	m().wing_l.rotation.z  = lerp(m().wing_l.rotation.z,   wa,        delta*3.0)
	m().wing_l.rotation.x  = lerp(m().wing_l.rotation.x,   0.10+b*0.04, delta*3.0)
	m().wing_l2.rotation.z = lerp(m().wing_l2.rotation.z,  0.35+bw*0.10, delta*3.0)
	m().wing_l2.rotation.x = lerp(m().wing_l2.rotation.x,  0.06, delta*3.0)
	m().wing_l3.rotation.x = lerp(m().wing_l3.rotation.x,  0.12+bw*0.06, delta*3.0)
	m().wing_r.rotation.z  = lerp(m().wing_r.rotation.z,  -wa,        delta*3.0)
	m().wing_r.rotation.x  = lerp(m().wing_r.rotation.x,   0.10+b*0.04, delta*3.0)
	m().wing_r2.rotation.z = lerp(m().wing_r2.rotation.z, -0.35-bw*0.10, delta*3.0)
	m().wing_r2.rotation.x = lerp(m().wing_r2.rotation.x,  0.06, delta*3.0)
	m().wing_r3.rotation.x = lerp(m().wing_r3.rotation.x,  0.12+bw*0.06, delta*3.0)
	m().fl_thigh.rotation.x = lerp(m().fl_thigh.rotation.x, 0.10, delta*5.0)
	m().fl_shin.rotation.x  = lerp(m().fl_shin.rotation.x,  0.25, delta*5.0)
	m().fr_thigh.rotation.x = lerp(m().fr_thigh.rotation.x, 0.10, delta*5.0)
	m().fr_shin.rotation.x  = lerp(m().fr_shin.rotation.x,  0.25, delta*5.0)
	m().bl_thigh.rotation.x = lerp(m().bl_thigh.rotation.x, 0.18, delta*5.0)
	m().bl_shin.rotation.x  = lerp(m().bl_shin.rotation.x,  0.32, delta*5.0)
	m().br_thigh.rotation.x = lerp(m().br_thigh.rotation.x, 0.18, delta*5.0)
	m().br_shin.rotation.x  = lerp(m().br_shin.rotation.x,  0.32, delta*5.0)
	for i in range(m().spine_fins.size()):
		m().spine_fins[i].rotation.z = sin(t*1.2+float(i)*0.4)*0.06
	for i in range(m().tail.size()):
		m().tail[i].rotation.y = sin(t*tail_wave_speed*0.35+float(i)*0.7)*(0.10+float(i)*0.05)
		m().tail[i].rotation.x = lerp(m().tail[i].rotation.x, 0.05+float(i)*0.02, delta*2.5)

# ── WALK / SPRINT ─────────────────────────────────────────────────────────────
func _walk(delta: float, t: float, mult: float) -> void:
	var cyc  := t * walk_cycle_speed * mult
	var cyc2 := cyc + PI
	m().rig.position.y = 0.10 + abs(sin(cyc*2.0))*(0.025+mult*0.015)
	m().rig.rotation.x = lerp(m().rig.rotation.x, -0.06*mult, delta*8.0)
	m().rig.rotation.z = sin(cyc)*(0.025+mult*0.010)
	m().neck.rotation.x  = lerp(m().neck.rotation.x,  -0.28+sin(cyc)*0.05, delta*6.0)
	m().neck2.rotation.x = lerp(m().neck2.rotation.x, -0.20+sin(cyc)*0.04, delta*6.0)
	m().neck.rotation.y  = sin(cyc*0.5)*0.06
	m().head_pivot.rotation.x = lerp(m().head_pivot.rotation.x, 0.0, delta*5.0)
	m().jaw.rotation.x   = lerp(m().jaw.rotation.x, 0.0, delta*8.0)
	var wf := sin(cyc * wing_flap_run_spd / walk_cycle_speed)
	var ws := 0.22 + mult*0.14
	var we := 0.28 + mult*0.12 + wf*0.18
	m().wing_l.rotation.z  = lerp(m().wing_l.rotation.z,   ws-wf*0.35, delta*7.0)
	m().wing_l.rotation.x  = lerp(m().wing_l.rotation.x,   0.08-wf*0.06, delta*6.0)
	m().wing_l2.rotation.z = lerp(m().wing_l2.rotation.z,  we, delta*6.0)
	m().wing_l2.rotation.x = lerp(m().wing_l2.rotation.x,  0.04+wf*0.08, delta*5.0)
	m().wing_l3.rotation.x = lerp(m().wing_l3.rotation.x,  0.10+wf*0.12, delta*4.0)
	m().wing_r.rotation.z  = lerp(m().wing_r.rotation.z,  -(ws-wf*0.35), delta*7.0)
	m().wing_r.rotation.x  = lerp(m().wing_r.rotation.x,   0.08-wf*0.06, delta*6.0)
	m().wing_r2.rotation.z = lerp(m().wing_r2.rotation.z, -we, delta*6.0)
	m().wing_r2.rotation.x = lerp(m().wing_r2.rotation.x,  0.04+wf*0.08, delta*5.0)
	m().wing_r3.rotation.x = lerp(m().wing_r3.rotation.x,  0.10+wf*0.12, delta*4.0)
	m().fl_thigh.rotation.x =  sin(cyc)*0.48;   m().fl_shin.rotation.x = abs(sin(cyc))*0.60
	m().fl_foot.rotation.x  = -abs(sin(cyc))*0.25
	m().fr_thigh.rotation.x =  sin(cyc2)*0.48;  m().fr_shin.rotation.x = abs(sin(cyc2))*0.60
	m().fr_foot.rotation.x  = -abs(sin(cyc2))*0.25
	m().bl_thigh.rotation.x =  sin(cyc2)*0.52;  m().bl_shin.rotation.x = abs(sin(cyc2))*0.65
	m().bl_foot.rotation.x  = -abs(sin(cyc2))*0.28
	m().br_thigh.rotation.x =  sin(cyc)*0.52;   m().br_shin.rotation.x = abs(sin(cyc))*0.65
	m().br_foot.rotation.x  = -abs(sin(cyc))*0.28
	for i in range(m().tail.size()):
		m().tail[i].rotation.y = sin(t*tail_wave_speed+float(i)*0.55)*(0.18+float(i)*0.07)*mult
		m().tail[i].rotation.x = lerp(m().tail[i].rotation.x, 0.04+float(i)*0.03, delta*4.0)
	for i in range(m().spine_fins.size()):
		m().spine_fins[i].rotation.z = sin(cyc+float(i)*0.3)*(0.05+mult*0.04)

# ── CROUCH ────────────────────────────────────────────────────────────────────
func _crouch(delta: float, t: float) -> void:
	m().rig.position.y = lerp(m().rig.position.y, -0.18, delta*8.0)
	m().rig.rotation.x = lerp(m().rig.rotation.x,  0.28, delta*7.0)
	m().neck.rotation.x       = lerp(m().neck.rotation.x,   0.15, delta*6.0)
	m().neck2.rotation.x      = lerp(m().neck2.rotation.x,  0.10, delta*6.0)
	m().head_pivot.rotation.x = lerp(m().head_pivot.rotation.x, 0.10, delta*5.0)
	m().jaw.rotation.x        = lerp(m().jaw.rotation.x, 0.05, delta*5.0)
	m().wing_l.rotation.z  = lerp(m().wing_l.rotation.z,   0.72, delta*7.0)
	m().wing_l.rotation.x  = lerp(m().wing_l.rotation.x,  -0.15, delta*6.0)
	m().wing_l2.rotation.z = lerp(m().wing_l2.rotation.z,  1.05, delta*7.0)
	m().wing_l2.rotation.x = lerp(m().wing_l2.rotation.x,  0.20, delta*6.0)
	m().wing_l3.rotation.x = lerp(m().wing_l3.rotation.x,  0.30, delta*5.0)
	m().wing_r.rotation.z  = lerp(m().wing_r.rotation.z,  -0.72, delta*7.0)
	m().wing_r.rotation.x  = lerp(m().wing_r.rotation.x,  -0.15, delta*6.0)
	m().wing_r2.rotation.z = lerp(m().wing_r2.rotation.z, -1.05, delta*7.0)
	m().wing_r2.rotation.x = lerp(m().wing_r2.rotation.x,  0.20, delta*6.0)
	m().wing_r3.rotation.x = lerp(m().wing_r3.rotation.x,  0.30, delta*5.0)
	m().fl_thigh.rotation.x = lerp(m().fl_thigh.rotation.x,  0.55, delta*8.0)
	m().fl_shin.rotation.x  = lerp(m().fl_shin.rotation.x,   0.80, delta*8.0)
	m().fl_foot.rotation.x  = lerp(m().fl_foot.rotation.x,  -0.35, delta*8.0)
	m().fr_thigh.rotation.x = lerp(m().fr_thigh.rotation.x,  0.55, delta*8.0)
	m().fr_shin.rotation.x  = lerp(m().fr_shin.rotation.x,   0.80, delta*8.0)
	m().fr_foot.rotation.x  = lerp(m().fr_foot.rotation.x,  -0.35, delta*8.0)
	m().bl_thigh.rotation.x = lerp(m().bl_thigh.rotation.x,  0.65, delta*8.0)
	m().bl_shin.rotation.x  = lerp(m().bl_shin.rotation.x,   0.90, delta*8.0)
	m().bl_foot.rotation.x  = lerp(m().bl_foot.rotation.x,  -0.40, delta*8.0)
	m().br_thigh.rotation.x = lerp(m().br_thigh.rotation.x,  0.65, delta*8.0)
	m().br_shin.rotation.x  = lerp(m().br_shin.rotation.x,   0.90, delta*8.0)
	m().br_foot.rotation.x  = lerp(m().br_foot.rotation.x,  -0.40, delta*8.0)
	for i in range(m().tail.size()):
		m().tail[i].rotation.x = lerp(m().tail[i].rotation.x, -0.08+float(i)*0.02, delta*5.0)
		m().tail[i].rotation.y = sin(t*tail_wave_speed*0.25+float(i)*0.5)*(0.06+float(i)*0.03)

# ── DASH ──────────────────────────────────────────────────────────────────────
func _dash(delta: float, _t: float) -> void:
	m().rig.position.y = lerp(m().rig.position.y,  0.04, delta*22.0)
	m().rig.rotation.x = lerp(m().rig.rotation.x,  0.40, delta*22.0)
	m().neck.rotation.x  = lerp(m().neck.rotation.x,  0.20, delta*18.0)
	m().neck2.rotation.x = lerp(m().neck2.rotation.x, 0.15, delta*18.0)
	m().jaw.rotation.x   = lerp(m().jaw.rotation.x,   0.18, delta*18.0)
	m().wing_l.rotation.z  = lerp(m().wing_l.rotation.z, -0.05, delta*22.0)
	m().wing_l.rotation.x  = lerp(m().wing_l.rotation.x, -0.08, delta*20.0)
	m().wing_l2.rotation.z = lerp(m().wing_l2.rotation.z, 0.06, delta*20.0)
	m().wing_l2.rotation.x = lerp(m().wing_l2.rotation.x,-0.04, delta*18.0)
	m().wing_l3.rotation.x = lerp(m().wing_l3.rotation.x,-0.06, delta*16.0)
	m().wing_r.rotation.z  = lerp(m().wing_r.rotation.z,  0.05, delta*22.0)
	m().wing_r.rotation.x  = lerp(m().wing_r.rotation.x, -0.08, delta*20.0)
	m().wing_r2.rotation.z = lerp(m().wing_r2.rotation.z,-0.06, delta*20.0)
	m().wing_r2.rotation.x = lerp(m().wing_r2.rotation.x,-0.04, delta*18.0)
	m().wing_r3.rotation.x = lerp(m().wing_r3.rotation.x,-0.06, delta*16.0)
	m().fl_thigh.rotation.x = lerp(m().fl_thigh.rotation.x,-0.45, delta*20.0)
	m().fl_shin.rotation.x  = lerp(m().fl_shin.rotation.x,  0.20, delta*20.0)
	m().fr_thigh.rotation.x = lerp(m().fr_thigh.rotation.x,-0.45, delta*20.0)
	m().fr_shin.rotation.x  = lerp(m().fr_shin.rotation.x,  0.20, delta*20.0)
	m().bl_thigh.rotation.x = lerp(m().bl_thigh.rotation.x,-0.55, delta*20.0)
	m().bl_shin.rotation.x  = lerp(m().bl_shin.rotation.x,  0.18, delta*20.0)
	m().br_thigh.rotation.x = lerp(m().br_thigh.rotation.x,-0.55, delta*20.0)
	m().br_shin.rotation.x  = lerp(m().br_shin.rotation.x,  0.18, delta*20.0)
	for i in range(m().tail.size()):
		m().tail[i].rotation.x = lerp(m().tail[i].rotation.x,-0.12, delta*20.0)
		m().tail[i].rotation.y = lerp(m().tail[i].rotation.y, 0.0,  delta*20.0)

# ── ATTACK ────────────────────────────────────────────────────────────────────
func _attack(delta: float, _t: float) -> void:
	var prog: float = 1.0 - (base._attack_timer / base.attack_duration)
	if prog < 0.35:
		m().neck.rotation.x       = lerp(m().neck.rotation.x,   0.35, delta*20.0)
		m().neck2.rotation.x      = lerp(m().neck2.rotation.x,  0.25, delta*20.0)
		m().head_pivot.rotation.x = lerp(m().head_pivot.rotation.x, 0.20, delta*20.0)
		m().jaw.rotation.x        = lerp(m().jaw.rotation.x,    0.0,  delta*15.0)
		m().rig.rotation.x        = lerp(m().rig.rotation.x,   -0.15, delta*14.0)
		m().wing_l.rotation.z  = lerp(m().wing_l.rotation.z,  -0.55, delta*24.0)
		m().wing_l.rotation.x  = lerp(m().wing_l.rotation.x,  -0.20, delta*22.0)
		m().wing_l2.rotation.z = lerp(m().wing_l2.rotation.z, -0.15, delta*22.0)
		m().wing_l2.rotation.x = lerp(m().wing_l2.rotation.x, -0.10, delta*20.0)
		m().wing_r.rotation.z  = lerp(m().wing_r.rotation.z,   0.55, delta*24.0)
		m().wing_r.rotation.x  = lerp(m().wing_r.rotation.x,  -0.20, delta*22.0)
		m().wing_r2.rotation.z = lerp(m().wing_r2.rotation.z,  0.15, delta*22.0)
		m().wing_r2.rotation.x = lerp(m().wing_r2.rotation.x, -0.10, delta*20.0)
		m().fl_thigh.rotation.x = lerp(m().fl_thigh.rotation.x,-0.60, delta*20.0)
		m().fr_thigh.rotation.x = lerp(m().fr_thigh.rotation.x,-0.60, delta*20.0)
		m().fl_shin.rotation.x  = lerp(m().fl_shin.rotation.x,  0.80, delta*20.0)
		m().fr_shin.rotation.x  = lerp(m().fr_shin.rotation.x,  0.80, delta*20.0)
	else:
		m().neck.rotation.x       = lerp(m().neck.rotation.x,  -0.65, delta*35.0)
		m().neck2.rotation.x      = lerp(m().neck2.rotation.x, -0.45, delta*35.0)
		m().head_pivot.rotation.x = lerp(m().head_pivot.rotation.x,-0.20, delta*35.0)
		m().jaw.rotation.x        = lerp(m().jaw.rotation.x,    0.45, delta*35.0)
		m().rig.rotation.x        = lerp(m().rig.rotation.x,    0.20, delta*25.0)
		m().wing_l.rotation.z  = lerp(m().wing_l.rotation.z,   0.70, delta*32.0)
		m().wing_l.rotation.x  = lerp(m().wing_l.rotation.x,   0.18, delta*30.0)
		m().wing_l2.rotation.z = lerp(m().wing_l2.rotation.z,  0.85, delta*30.0)
		m().wing_l2.rotation.x = lerp(m().wing_l2.rotation.x,  0.22, delta*28.0)
		m().wing_l3.rotation.x = lerp(m().wing_l3.rotation.x,  0.30, delta*25.0)
		m().wing_r.rotation.z  = lerp(m().wing_r.rotation.z,  -0.70, delta*32.0)
		m().wing_r.rotation.x  = lerp(m().wing_r.rotation.x,   0.18, delta*30.0)
		m().wing_r2.rotation.z = lerp(m().wing_r2.rotation.z, -0.85, delta*30.0)
		m().wing_r2.rotation.x = lerp(m().wing_r2.rotation.x,  0.22, delta*28.0)
		m().wing_r3.rotation.x = lerp(m().wing_r3.rotation.x,  0.30, delta*25.0)
		m().fl_thigh.rotation.x = lerp(m().fl_thigh.rotation.x, 0.65, delta*32.0)
		m().fr_thigh.rotation.x = lerp(m().fr_thigh.rotation.x, 0.65, delta*32.0)
		m().fl_shin.rotation.x  = lerp(m().fl_shin.rotation.x,  0.20, delta*30.0)
		m().fr_shin.rotation.x  = lerp(m().fr_shin.rotation.x,  0.20, delta*30.0)
		for i in range(m().tail.size()):
			m().tail[i].rotation.x = lerp(m().tail[i].rotation.x, 0.25+float(i)*0.08, delta*25.0)
	m().bl_thigh.rotation.x = lerp(m().bl_thigh.rotation.x, 0.30, delta*8.0)
	m().bl_shin.rotation.x  = lerp(m().bl_shin.rotation.x,  0.45, delta*8.0)
	m().br_thigh.rotation.x = lerp(m().br_thigh.rotation.x, 0.30, delta*8.0)
	m().br_shin.rotation.x  = lerp(m().br_shin.rotation.x,  0.45, delta*8.0)

# ── AIR ───────────────────────────────────────────────────────────────────────
func _air(delta: float, _t: float) -> void:
	m().rig.position.y = lerp(m().rig.position.y, 0.10, delta*5.0)
	var rising: bool = base._state == CharacterBase.State.JUMP
	var tuck: float
	if rising: tuck = clamp(base.velocity.y / base._jump_v, 0.0, 1.0)
	else:      tuck = clamp(1.0 + base.velocity.y / base._jump_v, 0.0, 1.0) * 0.4
	var ws: float = 0.15 if rising else 0.08
	var wd: float = tuck * 0.25
	m().wing_l.rotation.z  = lerp(m().wing_l.rotation.z,   ws-wd,      delta*8.0)
	m().wing_l.rotation.x  = lerp(m().wing_l.rotation.x,  -0.12+tuck*0.08, delta*7.0)
	m().wing_l2.rotation.z = lerp(m().wing_l2.rotation.z,  0.10+wd*0.5, delta*7.0)
	m().wing_l2.rotation.x = lerp(m().wing_l2.rotation.x, -0.06, delta*6.0)
	m().wing_l3.rotation.x = lerp(m().wing_l3.rotation.x, -0.08+tuck*0.15, delta*5.0)
	m().wing_r.rotation.z  = lerp(m().wing_r.rotation.z,  -(ws-wd),    delta*8.0)
	m().wing_r.rotation.x  = lerp(m().wing_r.rotation.x,  -0.12+tuck*0.08, delta*7.0)
	m().wing_r2.rotation.z = lerp(m().wing_r2.rotation.z, -(0.10+wd*0.5), delta*7.0)
	m().wing_r2.rotation.x = lerp(m().wing_r2.rotation.x, -0.06, delta*6.0)
	m().wing_r3.rotation.x = lerp(m().wing_r3.rotation.x, -0.08+tuck*0.15, delta*5.0)
	var fall_t: float = clamp(-base.velocity.y/7.0, 0.0, 1.0)
	m().neck.rotation.x  = lerp(m().neck.rotation.x,  -0.40+fall_t*0.25, delta*7.0)
	m().neck2.rotation.x = lerp(m().neck2.rotation.x, -0.30+fall_t*0.20, delta*7.0)
	m().jaw.rotation.x   = lerp(m().jaw.rotation.x,    0.0, delta*6.0)
	m().rig.rotation.x   = lerp(m().rig.rotation.x,    0.0, delta*8.0)
	m().fl_thigh.rotation.x = lerp(m().fl_thigh.rotation.x,-0.28-tuck*0.45, delta*10.0)
	m().fl_shin.rotation.x  = lerp(m().fl_shin.rotation.x,  0.55+tuck*0.50, delta*10.0)
	m().fr_thigh.rotation.x = lerp(m().fr_thigh.rotation.x,-0.28-tuck*0.45, delta*10.0)
	m().fr_shin.rotation.x  = lerp(m().fr_shin.rotation.x,  0.55+tuck*0.50, delta*10.0)
	m().bl_thigh.rotation.x = lerp(m().bl_thigh.rotation.x,-0.35-tuck*0.40, delta*10.0)
	m().bl_shin.rotation.x  = lerp(m().bl_shin.rotation.x,  0.60+tuck*0.45, delta*10.0)
	m().br_thigh.rotation.x = lerp(m().br_thigh.rotation.x,-0.35-tuck*0.40, delta*10.0)
	m().br_shin.rotation.x  = lerp(m().br_shin.rotation.x,  0.60+tuck*0.45, delta*10.0)
	for i in range(m().tail.size()):
		var droop: float = (0.10+float(i)*0.06) if not rising else -0.08
		m().tail[i].rotation.x = lerp(m().tail[i].rotation.x, droop, delta*5.0)
		m().tail[i].rotation.y = lerp(m().tail[i].rotation.y, 0.0,   delta*4.0)
	for i in range(m().spine_fins.size()):
		m().spine_fins[i].rotation.z = sin(base._time*4.0+float(i)*0.5)*0.08
