## raptor_character.gd – Velociraptor neon (Nhân vật 1)
## Extends CharacterBase. Build + animate toàn bộ mesh procedural.

extends CharacterBase
class_name RaptorCharacter

# ── Animation params ──────────────────────────────────────────────────────────
@export var run_cycle_speed:   float = 11.0
@export var sprint_cycle_mult: float = 1.6
@export var idle_breathe_spd:  float = 1.2
@export var tail_sway_speed:   float = 3.5

# ── Rig node refs ─────────────────────────────────────────────────────────────
var _torso:     MeshInstance3D
var _neck:      Node3D
var _snout_bot: MeshInstance3D
var _arm_l:     Node3D
var _arm_r:     Node3D
var _thigh_l:   Node3D
var _thigh_r:   Node3D
var _shin_l:    Node3D
var _shin_r:    Node3D
var _foot_l:    Node3D
var _foot_r:    Node3D
var _tail:      Array[Node3D] = []

# ── Materials ─────────────────────────────────────────────────────────────────
var _mat_body:  StandardMaterial3D
var _mat_dark:  StandardMaterial3D
var _mat_light: StandardMaterial3D
var _mat_eye:   StandardMaterial3D

# ─────────────────────────────────────────────────────────────────────────────
func _build_character() -> void:
	move_speed   = 5.5
	sprint_speed = 9.5
	jump_height  = 1.4

	# Collision
	var col := CollisionShape3D.new()
	var cs  := CapsuleShape3D.new()
	cs.radius = 0.28; cs.height = 1.10
	col.shape = cs; col.position = Vector3(0, 0.55, 0)
	add_child(col)

	_rig = Node3D.new(); _rig.name = "RaptorRig"
	_rig.position = Vector3(0, 0.10, 0)
	add_child(_rig)

	_mat_body  = _emit_mat(Color(0.55,0.95,0.88), Color(0.25,0.90,0.78), 1.6)
	_mat_dark  = _emit_mat(Color(0.04,0.22,0.20), Color(0.04,0.30,0.26), 0.8)
	_mat_light = _emit_mat(Color(0.85,1.00,0.96), Color(0.50,1.00,0.92), 2.2)
	_mat_eye   = _emit_mat(Color(1.00,0.95,0.40), Color(1.00,0.90,0.20), 3.0)

	_build_raptor_mesh()

func _build_raptor_mesh() -> void:
	# Torso
	_torso = _box(_rig, Vector3(0,0.62,0),   Vector3(0.44,0.30,0.70), _mat_body)
	_box(_rig, Vector3(0,0.55, 0.28), Vector3(0.38,0.22,0.22), _mat_body)
	_box(_rig, Vector3(0,0.60,-0.30), Vector3(0.40,0.26,0.28), _mat_body)
	# Spine plates
	for i in range(4):
		_box(_rig, Vector3(0, 0.78+float(i)*0.04, 0.18-float(i)*0.08),
			 Vector3(0.06, 0.10+float(i)*0.02, 0.05), _mat_light)

	# Neck + head
	_neck = _pivot(_rig, Vector3(0, 0.74, 0.26))
	_box(_neck, Vector3(0,0.10,0.12), Vector3(0.20,0.22,0.30), _mat_body)
	_box(_neck, Vector3(0,0.22,0.26), Vector3(0.16,0.18,0.22), _mat_body)
	var hp: Node3D = _pivot(_neck, Vector3(0, 0.28, 0.32))
	_box(hp, Vector3(0, 0,    0.04), Vector3(0.22,0.18,0.30), _mat_body)
	_box(hp, Vector3(0,-0.02, 0.21), Vector3(0.16,0.08,0.18), _mat_body)
	_snout_bot = _box(hp, Vector3(0,-0.07,0.18), Vector3(0.14,0.06,0.16), _mat_body)
	# Teeth
	for ti in range(3):
		_box(hp, Vector3(-0.04+float(ti)*0.04, -0.10, 0.20+float(ti)*0.02),
			 Vector3(0.02,0.04,0.02), _mat_light)
	# Crest
	_box(hp, Vector3(0, 0.10,-0.04), Vector3(0.06,0.12,0.08), _mat_light)
	# Eyes
	_sphere(hp, Vector3(-0.10,0.04,0.10), 0.038, _mat_eye)
	_sphere(hp, Vector3( 0.10,0.04,0.10), 0.038, _mat_eye)
	# Brow ridges
	_box(hp, Vector3(-0.10,0.06,0.13), Vector3(0.06,0.04,0.04), _mat_dark)
	_box(hp, Vector3( 0.10,0.06,0.13), Vector3(0.06,0.04,0.04), _mat_dark)
	# Nostrils
	_box(hp, Vector3(-0.05,-0.01,0.27), Vector3(0.03,0.02,0.02), _mat_dark)
	_box(hp, Vector3( 0.05,-0.01,0.27), Vector3(0.03,0.02,0.02), _mat_dark)

	# Arms
	_arm_l = _pivot(_rig, Vector3(-0.22,0.64,0.20))
	_box(_arm_l, Vector3(0,-0.08, 0),    Vector3(0.08,0.16,0.07), _mat_body)
	_box(_arm_l, Vector3(0,-0.20, 0.02), Vector3(0.06,0.10,0.06), _mat_body)
	_box(_arm_l, Vector3(-0.02,-0.28,0.04), Vector3(0.04,0.06,0.03), _mat_dark)
	_arm_r = _pivot(_rig, Vector3(0.22,0.64,0.20))
	_box(_arm_r, Vector3(0,-0.08, 0),    Vector3(0.08,0.16,0.07), _mat_body)
	_box(_arm_r, Vector3(0,-0.20, 0.02), Vector3(0.06,0.10,0.06), _mat_body)
	_box(_arm_r, Vector3(0.02,-0.28,0.04), Vector3(0.04,0.06,0.03), _mat_dark)

	# Legs
	_thigh_l = _pivot(_rig, Vector3(-0.16,0.50,-0.10))
	var ll: Array[Node3D] = _build_leg(_thigh_l,-1.0); _shin_l=ll[0]; _foot_l=ll[1]
	_thigh_r = _pivot(_rig, Vector3( 0.16,0.50,-0.10))
	var lr: Array[Node3D] = _build_leg(_thigh_r, 1.0); _shin_r=lr[0]; _foot_r=lr[1]

	# Tail (5 segments)
	_tail.clear()
	var tsz: Array[Vector3] = [
		Vector3(0.26,0.20,0.22), Vector3(0.20,0.16,0.20),
		Vector3(0.15,0.12,0.18), Vector3(0.11,0.09,0.16),
		Vector3(0.07,0.06,0.14)]
	var tp2: Node3D = _rig
	for i in range(5):
		var off: Vector3 = Vector3(0,0.58,-0.44) if i == 0 else Vector3(0,0,-tsz[i-1].z)
		var tp: Node3D  = _pivot(tp2, off)
		_box(tp, Vector3(0,0,-tsz[i].z*0.5), tsz[i], _mat_body)
		if i < 3:
			_box(tp, Vector3(0, tsz[i].y*0.55, -tsz[i].z*0.4),
				 Vector3(0.04, 0.07-float(i)*0.02, 0.04), _mat_light)
		_tail.append(tp); tp2 = tp
	_box(tp2, Vector3(0,0,-0.14), Vector3(0.04,0.04,0.12), _mat_light)

func _build_leg(tp: Node3D, side: float) -> Array[Node3D]:
	_box(tp, Vector3(0,-0.14, 0.04), Vector3(0.14,0.28,0.16), _mat_body)
	_box(tp, Vector3(0,-0.30, 0.08), Vector3(0.10,0.08,0.10), _mat_light)
	var shin: Node3D = _pivot(tp, Vector3(0,-0.30,0.06))
	_box(shin, Vector3(0,-0.12,-0.02), Vector3(0.10,0.22,0.10), _mat_body)
	var foot: Node3D = _pivot(shin, Vector3(0,-0.24,-0.02))
	_box(foot, Vector3(0,-0.03,0.06), Vector3(0.10,0.06,0.20), _mat_body)
	for tt in range(3):
		var tx: float = (-0.06+float(tt)*0.06)*side
		_box(foot, Vector3(tx,-0.04, 0.18+float(tt)*0.01), Vector3(0.04,0.04,0.10), _mat_body)
		_box(foot, Vector3(tx,-0.06, 0.25), Vector3(0.03,0.03,0.05), _mat_dark)
	_box(foot, Vector3(0,0.02,0.22), Vector3(0.03,0.08,0.04), _mat_light)
	var r: Array[Node3D] = [shin, foot]; return r

# ── Animate dispatcher ────────────────────────────────────────────────────────
func _animate(delta: float) -> void:
	var t := _time
	match _state:
		State.IDLE:   _anim_idle(delta, t)
		State.WALK:   _anim_walk(delta, t, 1.0)
		State.SPRINT: _anim_walk(delta, t, sprint_cycle_mult)
		State.CROUCH: _anim_crouch(delta, t)
		State.DASH:   _anim_dash(delta, t)
		State.ATTACK: _anim_attack(delta, t)
		State.JUMP:   _anim_air(delta, t)
		State.FALL:   _anim_air(delta, t)

# ── IDLE ──────────────────────────────────────────────────────────────────────
func _anim_idle(delta: float, t: float) -> void:
	var b := sin(t * idle_breathe_spd)
	_rig.position.y    = lerp(_rig.position.y, 0.10, delta*8.0)
	_rig.rotation.x    = lerp(_rig.rotation.x, 0.0,  delta*10.0)
	_rig.rotation.z    = b * 0.012
	_neck.rotation.x   = lerp(_neck.rotation.x, -0.28 + b*0.03, delta*5.0)
	_neck.rotation.y   = b * 0.04
	_snout_bot.rotation.x = lerp(_snout_bot.rotation.x, 0.0, delta*4.0)
	_arm_l.rotation.x  = lerp(_arm_l.rotation.x, -0.15, delta*5.0)
	_arm_r.rotation.x  = lerp(_arm_r.rotation.x, -0.15, delta*5.0)
	_thigh_l.rotation.x = lerp(_thigh_l.rotation.x, 0.15, delta*6.0)
	_shin_l.rotation.x  = lerp(_shin_l.rotation.x,  0.30, delta*6.0)
	_foot_l.rotation.x  = lerp(_foot_l.rotation.x, -0.15, delta*6.0)
	_thigh_r.rotation.x = lerp(_thigh_r.rotation.x, 0.15, delta*6.0)
	_shin_r.rotation.x  = lerp(_shin_r.rotation.x,  0.30, delta*6.0)
	_foot_r.rotation.x  = lerp(_foot_r.rotation.x, -0.15, delta*6.0)
	for i in range(_tail.size()):
		_tail[i].rotation.y = sin(t*tail_sway_speed*0.4+float(i)*0.6)*(0.07+float(i)*0.04)
		_tail[i].rotation.x = lerp(_tail[i].rotation.x, 0.04+float(i)*0.03, delta*3.0)

# ── WALK / SPRINT ─────────────────────────────────────────────────────────────
func _anim_walk(delta: float, t: float, speed_mult: float) -> void:
	var cyc := t * run_cycle_speed * speed_mult
	_rig.position.y = 0.10 + abs(sin(cyc)) * (0.04 + speed_mult*0.02)
	_rig.rotation.x = lerp(_rig.rotation.x, 0.0, delta*10.0)
	_rig.rotation.z = sin(cyc*0.5) * (0.03 + speed_mult*0.01)
	_neck.rotation.x = -0.30 + sin(cyc)*0.07
	_neck.rotation.y = lerp(_neck.rotation.y, 0.0, delta*8.0)
	_snout_bot.rotation.x = abs(sin(cyc*0.5)) * 0.10
	_arm_l.rotation.x = sin(cyc+PI)*0.25
	_arm_r.rotation.x = sin(cyc)   *0.25
	_thigh_l.rotation.x =  sin(cyc)         * 0.55
	_shin_l.rotation.x  =  abs(sin(cyc))    * 0.70
	_foot_l.rotation.x  = -abs(sin(cyc))    * 0.30
	_thigh_r.rotation.x =  sin(cyc+PI)      * 0.55
	_shin_r.rotation.x  =  abs(sin(cyc+PI)) * 0.70
	_foot_r.rotation.x  = -abs(sin(cyc+PI)) * 0.30
	for i in range(_tail.size()):
		_tail[i].rotation.y = sin(t*tail_sway_speed+float(i)*0.55)*(0.15+float(i)*0.06)
		_tail[i].rotation.x = 0.06+float(i)*0.04

# ── CROUCH ────────────────────────────────────────────────────────────────────
func _anim_crouch(delta: float, t: float) -> void:
	_rig.position.y = lerp(_rig.position.y, -0.12, delta*10.0)
	_rig.rotation.x = lerp(_rig.rotation.x,  0.20, delta*8.0)
	_neck.rotation.x = lerp(_neck.rotation.x, -0.10, delta*6.0)
	_snout_bot.rotation.x = lerp(_snout_bot.rotation.x, 0.0, delta*4.0)
	_arm_l.rotation.x = lerp(_arm_l.rotation.x, 0.30, delta*6.0)
	_arm_r.rotation.x = lerp(_arm_r.rotation.x, 0.30, delta*6.0)
	_thigh_l.rotation.x = lerp(_thigh_l.rotation.x, 0.60, delta*8.0)
	_shin_l.rotation.x  = lerp(_shin_l.rotation.x,  0.80, delta*8.0)
	_foot_l.rotation.x  = lerp(_foot_l.rotation.x, -0.40, delta*8.0)
	_thigh_r.rotation.x = lerp(_thigh_r.rotation.x, 0.60, delta*8.0)
	_shin_r.rotation.x  = lerp(_shin_r.rotation.x,  0.80, delta*8.0)
	_foot_r.rotation.x  = lerp(_foot_r.rotation.x, -0.40, delta*8.0)
	for i in range(_tail.size()):
		_tail[i].rotation.x = lerp(_tail[i].rotation.x, -0.10+float(i)*0.02, delta*5.0)
		_tail[i].rotation.y = sin(t*tail_sway_speed*0.3+float(i)*0.5)*(0.04+float(i)*0.02)

# ── DASH ──────────────────────────────────────────────────────────────────────
func _anim_dash(delta: float, _t: float) -> void:
	_rig.position.y  = lerp(_rig.position.y,  0.06, delta*20.0)
	_rig.rotation.x  = lerp(_rig.rotation.x,  0.35, delta*20.0)
	_neck.rotation.x = lerp(_neck.rotation.x, 0.10, delta*15.0)
	_arm_l.rotation.x = lerp(_arm_l.rotation.x, -0.60, delta*20.0)
	_arm_r.rotation.x = lerp(_arm_r.rotation.x, -0.60, delta*20.0)
	_thigh_l.rotation.x = lerp(_thigh_l.rotation.x, -0.50, delta*20.0)
	_shin_l.rotation.x  = lerp(_shin_l.rotation.x,   0.20, delta*20.0)
	_thigh_r.rotation.x = lerp(_thigh_r.rotation.x, -0.50, delta*20.0)
	_shin_r.rotation.x  = lerp(_shin_r.rotation.x,   0.20, delta*20.0)
	for i in range(_tail.size()):
		_tail[i].rotation.x = lerp(_tail[i].rotation.x, -0.15, delta*18.0)
		_tail[i].rotation.y = lerp(_tail[i].rotation.y,  0.0,  delta*18.0)

# ── ATTACK ────────────────────────────────────────────────────────────────────
func _anim_attack(delta: float, _t: float) -> void:
	var prog: float = 1.0 - (_attack_timer / attack_duration)
	if prog < 0.4:
		_neck.rotation.x      = lerp(_neck.rotation.x,      0.20, delta*18.0)
		_snout_bot.rotation.x = lerp(_snout_bot.rotation.x, 0.0,  delta*10.0)
		_arm_l.rotation.x     = lerp(_arm_l.rotation.x,    -0.80, delta*18.0)
		_arm_r.rotation.x     = lerp(_arm_r.rotation.x,    -0.80, delta*18.0)
		_rig.rotation.x       = lerp(_rig.rotation.x,      -0.10, delta*12.0)
	else:
		_neck.rotation.x      = lerp(_neck.rotation.x,      -0.55, delta*30.0)
		_snout_bot.rotation.x = lerp(_snout_bot.rotation.x,  0.28, delta*30.0)
		_arm_l.rotation.x     = lerp(_arm_l.rotation.x,      0.70, delta*30.0)
		_arm_r.rotation.x     = lerp(_arm_r.rotation.x,      0.70, delta*30.0)
		_rig.rotation.x       = lerp(_rig.rotation.x,        0.15, delta*20.0)
		for i in range(_tail.size()):
			_tail[i].rotation.x = lerp(_tail[i].rotation.x, 0.20+float(i)*0.08, delta*20.0)
	_thigh_l.rotation.x = lerp(_thigh_l.rotation.x, 0.20, delta*8.0)
	_shin_l.rotation.x  = lerp(_shin_l.rotation.x,  0.35, delta*8.0)
	_thigh_r.rotation.x = lerp(_thigh_r.rotation.x, 0.20, delta*8.0)
	_shin_r.rotation.x  = lerp(_shin_r.rotation.x,  0.35, delta*8.0)

# ── AIR ───────────────────────────────────────────────────────────────────────
func _anim_air(delta: float, _t: float) -> void:
	_rig.position.y = lerp(_rig.position.y, 0.10, delta*5.0)
	var rising := _state == State.JUMP
	var tuck: float
	if rising: tuck = clamp(velocity.y / _jump_v, 0.0, 1.0)
	else:      tuck = clamp(1.0 + velocity.y / _jump_v, 0.0, 1.0) * 0.3
	_thigh_l.rotation.x = lerp(_thigh_l.rotation.x, -0.30-tuck*0.5, delta*12.0)
	_shin_l.rotation.x  = lerp(_shin_l.rotation.x,   0.60+tuck*0.6, delta*12.0)
	_foot_l.rotation.x  = lerp(_foot_l.rotation.x,  -0.40,           delta*10.0)
	_thigh_r.rotation.x = lerp(_thigh_r.rotation.x, -0.30-tuck*0.5, delta*12.0)
	_shin_r.rotation.x  = lerp(_shin_r.rotation.x,   0.60+tuck*0.6, delta*12.0)
	_foot_r.rotation.x  = lerp(_foot_r.rotation.x,  -0.40,           delta*10.0)
	var fall_t: float = clamp(-velocity.y/6.0, 0.0, 1.0)
	_neck.rotation.x = lerp(_neck.rotation.x, -0.50+fall_t*0.20, delta*8.0)
	_rig.rotation.x  = lerp(_rig.rotation.x,  0.0, delta*10.0)
	for i in range(_tail.size()):
		var droop: float = (0.15+float(i)*0.08) if not rising else -0.05
		_tail[i].rotation.x = lerp(_tail[i].rotation.x, droop, delta*6.0)
		_tail[i].rotation.y = lerp(_tail[i].rotation.y, 0.0,   delta*5.0)
