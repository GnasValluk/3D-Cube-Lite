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
	var flight_blend: float = float(base.call("get_flight_blend")) if base.has_method("get_flight_blend") else 0.0
	if base.has_method("is_flying") and base.call("is_flying"):
		_fly(delta, t, flight_blend)
		return
	match base._state:
		CharacterBase.State.IDLE:           _idle(delta, t)
		CharacterBase.State.WALK:           _walk(delta, t, 1.0)
		CharacterBase.State.SPRINT:         _walk(delta, t, sprint_cycle_mult)
		CharacterBase.State.DASH:           _dash(delta, t)
		CharacterBase.State.ATTACK:         _breathe_fire(delta, t)
		CharacterBase.State.DEVOUR:         _devour(delta, t)
		CharacterBase.State.JUMP:           _air(delta, t)
		CharacterBase.State.FALL:           _air(delta, t)
		CharacterBase.State.HIT:            _hit(delta, t)
		CharacterBase.State.DEAD:           _dead(delta, t)

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

# ── BREATHE FIRE (LMB) ────────────────────────────────────────────────────────
# Phase 0→0.30 : Windup – cổ thụt lại, cánh bung, ngực phồng lên
# Phase 0.30→1 : Khè – cổ vươn thẳng ra trước, miệng mở tối đa, cánh dang rộng
#                cổ và đầu rung nhẹ để giả hiệu ứng luồng lửa
func _breathe_fire(delta: float, t: float) -> void:
	var prog: float = 1.0 - (base._attack_timer / base.attack_duration)

	if prog < 0.30:
		# ── Windup: nạp năng lượng ──────────────────────────────────────────
		var p: float = prog / 0.30   # 0→1
		# Cổ kéo thụt vào, đầu ngẩng cao
		m().neck.rotation.x       = lerp(m().neck.rotation.x,       0.40, delta*22.0)
		m().neck2.rotation.x      = lerp(m().neck2.rotation.x,      0.30, delta*22.0)
		m().head_pivot.rotation.x = lerp(m().head_pivot.rotation.x, 0.25, delta*20.0)
		# Miệng còn đóng
		m().jaw.rotation.x        = lerp(m().jaw.rotation.x,        0.0,  delta*15.0)
		# Thân hơi nhún lên – ngực phồng
		m().rig.position.y = lerp(m().rig.position.y, 0.18 + p*0.06, delta*16.0)
		m().rig.rotation.x = lerp(m().rig.rotation.x, -0.20,          delta*14.0)
		# Cánh bung lên trên chuẩn bị
		m().wing_l.rotation.z  = lerp(m().wing_l.rotation.z, -0.60, delta*24.0)
		m().wing_l.rotation.x  = lerp(m().wing_l.rotation.x, -0.25, delta*22.0)
		m().wing_l2.rotation.z = lerp(m().wing_l2.rotation.z,-0.20, delta*22.0)
		m().wing_r.rotation.z  = lerp(m().wing_r.rotation.z,  0.60, delta*24.0)
		m().wing_r.rotation.x  = lerp(m().wing_r.rotation.x, -0.25, delta*22.0)
		m().wing_r2.rotation.z = lerp(m().wing_r2.rotation.z, 0.20, delta*22.0)
		# Chân trước chịu lực
		m().fl_thigh.rotation.x = lerp(m().fl_thigh.rotation.x, 0.30, delta*18.0)
		m().fr_thigh.rotation.x = lerp(m().fr_thigh.rotation.x, 0.30, delta*18.0)
		m().fl_shin.rotation.x  = lerp(m().fl_shin.rotation.x,  0.50, delta*18.0)
		m().fr_shin.rotation.x  = lerp(m().fr_shin.rotation.x,  0.50, delta*18.0)
	else:
		# ── Khè lửa: cổ phóng thẳng ra, miệng há rộng, rung nhẹ ─────────────
		var fire_shake: float = sin(t * 28.0) * 0.025   # rung cổ khi khè
		# Cổ vươn thẳng phía trước thấp
		m().neck.rotation.x       = lerp(m().neck.rotation.x,  -0.55 + fire_shake, delta*32.0)
		m().neck2.rotation.x      = lerp(m().neck2.rotation.x, -0.40 + fire_shake, delta*32.0)
		m().head_pivot.rotation.x = lerp(m().head_pivot.rotation.x, -0.15, delta*28.0)
		# Miệng mở hết cỡ – rung theo nhịp khè
		m().jaw.rotation.x = lerp(m().jaw.rotation.x, 0.55 + abs(fire_shake)*2.0, delta*35.0)
		# Thân nghiêng về trước
		m().rig.rotation.x = lerp(m().rig.rotation.x, 0.25, delta*20.0)
		m().rig.position.y = lerp(m().rig.position.y, 0.10, delta*10.0)
		# Cánh xoè dang ngang uy nghi – giữ nguyên để không che lửa
		m().wing_l.rotation.z  = lerp(m().wing_l.rotation.z,  0.10, delta*18.0)
		m().wing_l.rotation.x  = lerp(m().wing_l.rotation.x, -0.10, delta*16.0)
		m().wing_l2.rotation.z = lerp(m().wing_l2.rotation.z, 0.15, delta*16.0)
		m().wing_l2.rotation.x = lerp(m().wing_l2.rotation.x,-0.05, delta*14.0)
		m().wing_l3.rotation.x = lerp(m().wing_l3.rotation.x,-0.05, delta*12.0)
		m().wing_r.rotation.z  = lerp(m().wing_r.rotation.z, -0.10, delta*18.0)
		m().wing_r.rotation.x  = lerp(m().wing_r.rotation.x, -0.10, delta*16.0)
		m().wing_r2.rotation.z = lerp(m().wing_r2.rotation.z,-0.15, delta*16.0)
		m().wing_r2.rotation.x = lerp(m().wing_r2.rotation.x,-0.05, delta*14.0)
		m().wing_r3.rotation.x = lerp(m().wing_r3.rotation.x,-0.05, delta*12.0)
		# Chân trước chịu lực tốt
		m().fl_thigh.rotation.x = lerp(m().fl_thigh.rotation.x, 0.45, delta*20.0)
		m().fr_thigh.rotation.x = lerp(m().fr_thigh.rotation.x, 0.45, delta*20.0)
		m().fl_shin.rotation.x  = lerp(m().fl_shin.rotation.x,  0.65, delta*20.0)
		m().fr_shin.rotation.x  = lerp(m().fr_shin.rotation.x,  0.65, delta*20.0)
		# Đuôi vút lên cân bằng
		for i in range(m().tail.size()):
			m().tail[i].rotation.x = lerp(m().tail[i].rotation.x, 0.20+float(i)*0.06, delta*18.0)
		# Vây lưng rung theo nhịp lửa
		for i in range(m().spine_fins.size()):
			m().spine_fins[i].rotation.z = sin(t*20.0+float(i)*0.8)*0.12

	# Chân sau đứng vững suốt
	m().bl_thigh.rotation.x = lerp(m().bl_thigh.rotation.x, 0.28, delta*8.0)
	m().bl_shin.rotation.x  = lerp(m().bl_shin.rotation.x,  0.42, delta*8.0)
	m().br_thigh.rotation.x = lerp(m().br_thigh.rotation.x, 0.28, delta*8.0)
	m().br_shin.rotation.x  = lerp(m().br_shin.rotation.x,  0.42, delta*8.0)

# ── DEVOUR (R) ────────────────────────────────────────────────────────────────
# Chân đứng yên, thân không nghiêng – chỉ cổ cúi xuống rồi nhai liên tục
func _devour(delta: float, t: float) -> void:
	var prog: float = 1.0 - (base._attack2_timer / base._attack2_duration)

	if prog < 0.20:
		# Cúi nhanh xuống
		m().neck.rotation.x       = lerp(m().neck.rotation.x,       0.60, delta*30.0)
		m().neck2.rotation.x      = lerp(m().neck2.rotation.x,      0.50, delta*30.0)
		m().head_pivot.rotation.x = lerp(m().head_pivot.rotation.x, 0.40, delta*28.0)
		m().jaw.rotation.x        = lerp(m().jaw.rotation.x,        0.40, delta*25.0)
	else:
		# Nhai liên tục – cổ giữ cúi, hàm đóng mở theo sin
		var chew: float = (sin(t * 14.0) * 0.5 + 0.5) * 0.42
		m().neck.rotation.x       = lerp(m().neck.rotation.x,       0.55, delta*12.0)
		m().neck2.rotation.x      = lerp(m().neck2.rotation.x,      0.45, delta*12.0)
		m().head_pivot.rotation.x = lerp(m().head_pivot.rotation.x,
			0.35 + sin(t * 14.0) * 0.05, delta*20.0)
		m().jaw.rotation.x = lerp(m().jaw.rotation.x, chew, delta*35.0)

	# Thân, cánh, chân – giữ nguyên idle
	m().rig.position.y  = lerp(m().rig.position.y,  0.10, delta*8.0)
	m().rig.rotation.x  = lerp(m().rig.rotation.x,  0.0,  delta*8.0)
	# Đuôi vút lên cân bằng
	for i in range(m().tail.size()):
		m().tail[i].rotation.x = lerp(m().tail[i].rotation.x, 0.12 + float(i)*0.04, delta*10.0)

# ── HIT ────────────────────────────────────────────────────────────────────────
func _hit(delta: float, _t: float) -> void:
	var p: float = 1.0 - (base._hit_timer / 0.18)
	m().rig.position.y = lerp(m().rig.position.y, 0.06, delta*14.0)
	m().rig.rotation.x = lerp(m().rig.rotation.x, 0.32 - p*0.18, delta*14.0)
	m().neck.rotation.x  = lerp(m().neck.rotation.x,  0.80 - p*0.40, delta*30.0)
	m().neck2.rotation.x = lerp(m().neck2.rotation.x, 0.60 - p*0.30, delta*28.0)
	m().head_pivot.rotation.x = lerp(m().head_pivot.rotation.x, 0.40 - p*0.20, delta*24.0)
	m().jaw.rotation.x = lerp(m().jaw.rotation.x, 0.0, delta*14.0)
	m().wing_l.rotation.z  = lerp(m().wing_l.rotation.z,  -0.40, delta*20.0)
	m().wing_l.rotation.x  = lerp(m().wing_l.rotation.x,  -0.30, delta*18.0)
	m().wing_l2.rotation.z = lerp(m().wing_l2.rotation.z, -0.50, delta*18.0)
	m().wing_r.rotation.z  = lerp(m().wing_r.rotation.z,   0.40, delta*20.0)
	m().wing_r.rotation.x  = lerp(m().wing_r.rotation.x,  -0.30, delta*18.0)
	m().wing_r2.rotation.z = lerp(m().wing_r2.rotation.z,  0.50, delta*18.0)

# ── DEAD ───────────────────────────────────────────────────────────────────────
func _dead(delta: float, _t: float) -> void:
	var prog: float = 1.0 - (base._death_timer / 1.8)
	if prog < 0.20:
		var p: float = prog / 0.20
		m().rig.rotation.x = lerp(m().rig.rotation.x, p * 0.30, delta*16.0)
		m().neck.rotation.x  = lerp(m().neck.rotation.x,  0.60, delta*20.0)
		m().neck2.rotation.x = lerp(m().neck2.rotation.x, 0.50, delta*18.0)
		m().head_pivot.rotation.x = lerp(m().head_pivot.rotation.x, 0.40, delta*16.0)
		m().jaw.rotation.x = lerp(m().jaw.rotation.x, 0.30, delta*16.0)
		m().wing_l.rotation.z  = lerp(m().wing_l.rotation.z,  -0.60, delta*20.0)
		m().wing_l2.rotation.z = lerp(m().wing_l2.rotation.z, -0.80, delta*18.0)
		m().wing_r.rotation.z  = lerp(m().wing_r.rotation.z,   0.60, delta*20.0)
		m().wing_r2.rotation.z = lerp(m().wing_r2.rotation.z,  0.80, delta*18.0)
	elif prog < 0.60:
		var p: float = (prog - 0.20) / 0.40
		m().rig.rotation.x = lerp(m().rig.rotation.x, 0.30 + p * 0.60, delta*14.0)
		m().rig.rotation.z = lerp(m().rig.rotation.z, -p * 0.20, delta*12.0)
		m().rig.position.y = lerp(m().rig.position.y, -p * 0.18, delta*10.0)
		m().neck.rotation.x  = lerp(m().neck.rotation.x,  0.60 + p * 0.40, delta*16.0)
		m().neck2.rotation.x = lerp(m().neck2.rotation.x, 0.50 + p * 0.30, delta*14.0)
		m().head_pivot.rotation.x = lerp(m().head_pivot.rotation.x, 0.40 + p * 0.30, delta*14.0)
		m().wing_l.rotation.z  = lerp(m().wing_l.rotation.z,  -0.60 + p * 0.20, delta*14.0)
		m().wing_l2.rotation.z = lerp(m().wing_l2.rotation.z, -0.80 + p * 0.30, delta*14.0)
		m().wing_r.rotation.z  = lerp(m().wing_r.rotation.z,   0.60 - p * 0.20, delta*14.0)
		m().wing_r2.rotation.z = lerp(m().wing_r2.rotation.z,  0.80 - p * 0.30, delta*14.0)
	else:
		m().rig.rotation.x = lerp(m().rig.rotation.x, 0.90, delta*8.0)
		m().rig.rotation.z = lerp(m().rig.rotation.z, -0.20, delta*8.0)
		m().rig.position.y = lerp(m().rig.position.y, -0.18, delta*6.0)

func _fly(delta: float, t: float, blend: float) -> void:
	var dashing: bool = base.has_method("is_flight_dashing") and base.call("is_flight_dashing")
	var flap: float = 0.0 if dashing else sin(t * lerp(6.0, 11.0, blend))
	var flap_abs: float = 0.0 if dashing else abs(flap)
	m().rig.position.y = lerp(m().rig.position.y, lerp(0.10, 0.22 + flap_abs * 0.08, blend), delta*8.0)
	m().rig.rotation.x = lerp(m().rig.rotation.x, lerp(0.0, -0.12, blend), delta*8.0)
	m().rig.rotation.z = lerp(m().rig.rotation.z, flap * 0.03 * blend, delta*6.0)
	m().neck.rotation.x  = lerp(m().neck.rotation.x, lerp(-0.35, -0.18, blend), delta*6.0)
	m().neck2.rotation.x = lerp(m().neck2.rotation.x, lerp(-0.25, -0.12, blend), delta*6.0)
	m().head_pivot.rotation.x = lerp(m().head_pivot.rotation.x, lerp(0.0, -0.05, blend), delta*6.0)
	m().jaw.rotation.x = lerp(m().jaw.rotation.x, lerp(0.04, 0.08 + flap_abs * 0.05, blend), delta*8.0)
	m().wing_l.rotation.z  = lerp(m().wing_l.rotation.z, lerp(0.28,  0.18 - flap * 0.95, blend), delta*14.0)
	m().wing_l.rotation.x  = lerp(m().wing_l.rotation.x, lerp(0.10, -0.20 - flap_abs * 0.20, blend), delta*12.0)
	m().wing_l2.rotation.z = lerp(m().wing_l2.rotation.z, lerp(0.35, 0.35 + flap_abs * 0.90, blend), delta*14.0)
	m().wing_l2.rotation.x = lerp(m().wing_l2.rotation.x, lerp(0.06, -0.12 + flap * 0.08, blend), delta*10.0)
	m().wing_l3.rotation.x = lerp(m().wing_l3.rotation.x, lerp(0.12, -0.08 + flap_abs * 0.18, blend), delta*10.0)
	m().wing_r.rotation.z  = lerp(m().wing_r.rotation.z, lerp(-0.28, -0.18 + flap * 0.95, blend), delta*14.0)
	m().wing_r.rotation.x  = lerp(m().wing_r.rotation.x, lerp(0.10, -0.20 - flap_abs * 0.20, blend), delta*12.0)
	m().wing_r2.rotation.z = lerp(m().wing_r2.rotation.z, lerp(-0.35, -0.35 - flap_abs * 0.90, blend), delta*14.0)
	m().wing_r2.rotation.x = lerp(m().wing_r2.rotation.x, lerp(0.06, -0.12 - flap * 0.08, blend), delta*10.0)
	m().wing_r3.rotation.x = lerp(m().wing_r3.rotation.x, lerp(0.12, -0.08 + flap_abs * 0.18, blend), delta*10.0)
	m().fl_thigh.rotation.x = lerp(m().fl_thigh.rotation.x, lerp(0.10, -0.10, blend), delta*8.0)
	m().fl_shin.rotation.x  = lerp(m().fl_shin.rotation.x,  lerp(0.25, 0.42, blend), delta*8.0)
	m().fr_thigh.rotation.x = lerp(m().fr_thigh.rotation.x, lerp(0.10, -0.10, blend), delta*8.0)
	m().fr_shin.rotation.x  = lerp(m().fr_shin.rotation.x,  lerp(0.25, 0.42, blend), delta*8.0)
	m().bl_thigh.rotation.x = lerp(m().bl_thigh.rotation.x, lerp(0.18, -0.20, blend), delta*8.0)
	m().bl_shin.rotation.x  = lerp(m().bl_shin.rotation.x,  lerp(0.32, 0.55, blend), delta*8.0)
	m().br_thigh.rotation.x = lerp(m().br_thigh.rotation.x, lerp(0.18, -0.20, blend), delta*8.0)
	m().br_shin.rotation.x  = lerp(m().br_shin.rotation.x,  lerp(0.32, 0.55, blend), delta*8.0)
	for i in range(m().tail.size()):
		m().tail[i].rotation.x = lerp(m().tail[i].rotation.x, lerp(0.05 + float(i) * 0.02, -0.06 + float(i) * 0.04, blend), delta*8.0)
		m().tail[i].rotation.y = lerp(m().tail[i].rotation.y, sin(t * 3.5 + float(i) * 0.5) * (0.08 + float(i) * 0.04) * blend, delta*6.0)
	for i in range(m().spine_fins.size()):
		m().spine_fins[i].rotation.z = sin(t * 8.0 + float(i) * 0.6) * 0.10 * blend


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
