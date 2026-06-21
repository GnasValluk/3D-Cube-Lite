## player.gd – Raptor
## States: IDLE, WALK, SPRINT, CROUCH, DASH, ATTACK, JUMP, FALL
## Controls: WASD=move, Shift=sprint, Ctrl=crouch, Space=jump, Q=dash, LMB=attack

extends CharacterBody3D

# ── Export ────────────────────────────────────────────────────────────────────
@export var move_speed:     float = 5.5    # Walk (giảm từ 8 xuống)
@export var sprint_speed:   float = 9.5    # Sprint
@export var crouch_speed:   float = 2.5    # Crouch
@export var acceleration:   float = 26.0
@export var friction:       float = 20.0
@export var jump_height:    float = 1.4
@export var jump_time_rise: float = 0.28
@export var jump_time_fall: float = 0.20
@export var dash_speed:     float = 18.0
@export var dash_duration:  float = 0.18
@export var dash_cooldown:  float = 0.80
@export var attack_duration: float = 0.45
@export var run_cycle_speed:  float = 11.0
@export var sprint_cycle_mult: float = 1.6
@export var idle_breathe_spd: float = 1.2
@export var tail_sway_speed:  float = 3.5

# ── State enum ────────────────────────────────────────────────────────────────
enum State { IDLE, WALK, SPRINT, CROUCH, DASH, ATTACK, JUMP, FALL }
var _state: State = State.IDLE

# ── Timers ────────────────────────────────────────────────────────────────────
const COYOTE_TIME: float = 0.12
const JUMP_BUFFER: float = 0.10
var _coyote:       float = 0.0
var _jbuf:         float = 0.0
var _dash_timer:   float = 0.0   # Thời gian còn lại của dash
var _dash_cd:      float = 0.0   # Cooldown
var _attack_timer: float = 0.0   # Thời gian còn lại của attack
var _dash_dir:     Vector3 = Vector3.ZERO

# ── Physics ───────────────────────────────────────────────────────────────────
var _jump_v:    float
var _grav_rise: float
var _grav_fall: float
var _was_floor: bool = false
var _time:      float = 0.0
var _camera:    Camera3D

# ── Camera switching ──────────────────────────────────────────────────────────
var _iso_rig: Node3D      # CameraRig (isometric)
var _tp_rig:  Node3D      # TPCameraRig (third-person)
var _use_tp:  bool = false

# ── Squash/stretch ────────────────────────────────────────────────────────────
var _sy_tgt: float = 1.0
var _sy_cur: float = 1.0

# ── Rig refs ──────────────────────────────────────────────────────────────────
var _rig:       Node3D
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

# ── Ready ─────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_jump_v    = (2.0 * jump_height) / jump_time_rise
	_grav_rise = (2.0 * jump_height) / (jump_time_rise * jump_time_rise)
	_grav_fall = (2.0 * jump_height) / (jump_time_fall * jump_time_fall)
	_build_materials()
	_build_raptor()
	await get_tree().process_frame
	# Lấy tham chiếu tới cả 2 camera rig từ scene cha
	var scene_root := get_parent()
	_iso_rig = scene_root.get_node_or_null("CameraRig")
	_tp_rig  = scene_root.get_node_or_null("TPCameraRig")
	# Bắt đầu với iso camera
	_camera = get_viewport().get_camera_3d()

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.keycode == KEY_SPACE and k.pressed and not k.echo:
			_jbuf = JUMP_BUFFER
		# F1: chuyển đổi giữa iso camera và third-person camera
		if k.keycode == KEY_F1 and k.pressed and not k.echo:
			_toggle_camera()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			if _attack_timer <= 0.0 and _state != State.DASH:
				_attack_timer = attack_duration
				_state = State.ATTACK

# ── Materials ─────────────────────────────────────────────────────────────────
func _emit_mat(albedo: Color, emit: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = albedo; m.roughness = 1.0; m.metallic_specular = 0.0
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.emission_enabled = true; m.emission = emit
	m.emission_energy_multiplier = energy
	return m

func _build_materials() -> void:
	_mat_body  = _emit_mat(Color(0.55, 0.95, 0.88), Color(0.25, 0.90, 0.78), 1.6)
	_mat_dark  = _emit_mat(Color(0.04, 0.22, 0.20), Color(0.04, 0.30, 0.26), 0.8)
	_mat_light = _emit_mat(Color(0.85, 1.00, 0.96), Color(0.50, 1.00, 0.92), 2.2)
	_mat_eye   = _emit_mat(Color(1.00, 0.95, 0.40), Color(1.00, 0.90, 0.20), 3.0)

# ── Build raptor ──────────────────────────────────────────────────────────────
func _build_raptor() -> void:
	var col := CollisionShape3D.new()
	var cs  := CapsuleShape3D.new()
	cs.radius = 0.28; cs.height = 1.10
	col.shape = cs; col.position = Vector3(0, 0.55, 0)
	add_child(col)
	_rig = Node3D.new(); _rig.name = "RaptorRig"
	_rig.position = Vector3(0, 0.10, 0)
	add_child(_rig)
	_torso = _box(_rig, Vector3(0,0.62,0),    Vector3(0.44,0.30,0.70), _mat_body)
	_box(_rig, Vector3(0,0.55, 0.28),  Vector3(0.38,0.22,0.22), _mat_body)
	_box(_rig, Vector3(0,0.60,-0.30),  Vector3(0.40,0.26,0.28), _mat_body)
	for i in range(4):
		_box(_rig, Vector3(0,0.78+float(i)*0.04,0.18-float(i)*0.08),
			 Vector3(0.06,0.10+float(i)*0.02,0.05), _mat_light)
	_neck = _pivot(_rig, Vector3(0,0.74,0.26))
	_box(_neck, Vector3(0,0.10,0.12), Vector3(0.20,0.22,0.30), _mat_body)
	_box(_neck, Vector3(0,0.22,0.26), Vector3(0.16,0.18,0.22), _mat_body)
	var hp: Node3D = _pivot(_neck, Vector3(0,0.28,0.32))
	_box(hp, Vector3(0,0,0.04),     Vector3(0.22,0.18,0.30), _mat_body)
	_box(hp, Vector3(0,-0.02,0.21), Vector3(0.16,0.08,0.18), _mat_body)
	_snout_bot = _box(hp, Vector3(0,-0.07,0.18), Vector3(0.14,0.06,0.16), _mat_body)
	for ti in range(3):
		_box(hp, Vector3(-0.04+float(ti)*0.04,-0.10,0.20+float(ti)*0.02),
			 Vector3(0.02,0.04,0.02), _mat_light)
	_box(hp, Vector3(0,0.10,-0.04), Vector3(0.06,0.12,0.08), _mat_light)
	_sphere(hp, Vector3(-0.10,0.04,0.10), 0.038, _mat_eye)
	_sphere(hp, Vector3( 0.10,0.04,0.10), 0.038, _mat_eye)
	_box(hp, Vector3(-0.10,0.06,0.13), Vector3(0.06,0.04,0.04), _mat_dark)
	_box(hp, Vector3( 0.10,0.06,0.13), Vector3(0.06,0.04,0.04), _mat_dark)
	_box(hp, Vector3(-0.05,-0.01,0.27), Vector3(0.03,0.02,0.02), _mat_dark)
	_box(hp, Vector3( 0.05,-0.01,0.27), Vector3(0.03,0.02,0.02), _mat_dark)
	_arm_l = _pivot(_rig, Vector3(-0.22,0.64,0.20))
	_box(_arm_l, Vector3(0,-0.08,0),    Vector3(0.08,0.16,0.07), _mat_body)
	_box(_arm_l, Vector3(0,-0.20,0.02), Vector3(0.06,0.10,0.06), _mat_body)
	_box(_arm_l, Vector3(-0.02,-0.28,0.04), Vector3(0.04,0.06,0.03), _mat_dark)
	_arm_r = _pivot(_rig, Vector3(0.22,0.64,0.20))
	_box(_arm_r, Vector3(0,-0.08,0),    Vector3(0.08,0.16,0.07), _mat_body)
	_box(_arm_r, Vector3(0,-0.20,0.02), Vector3(0.06,0.10,0.06), _mat_body)
	_box(_arm_r, Vector3(0.02,-0.28,0.04), Vector3(0.04,0.06,0.03), _mat_dark)
	_thigh_l = _pivot(_rig, Vector3(-0.16,0.50,-0.10))
	var ll: Array[Node3D] = _build_leg(_thigh_l,-1.0); _shin_l=ll[0]; _foot_l=ll[1]
	_thigh_r = _pivot(_rig, Vector3(0.16,0.50,-0.10))
	var lr: Array[Node3D] = _build_leg(_thigh_r, 1.0); _shin_r=lr[0]; _foot_r=lr[1]
	_tail.clear()
	var tsz: Array[Vector3] = [
		Vector3(0.26,0.20,0.22),Vector3(0.20,0.16,0.20),Vector3(0.15,0.12,0.18),
		Vector3(0.11,0.09,0.16),Vector3(0.07,0.06,0.14)]
	var tp2: Node3D = _rig
	for i in range(5):
		var off: Vector3 = Vector3(0,0.58,-0.44) if i==0 else Vector3(0,0,-tsz[i-1].z)
		var tp: Node3D = _pivot(tp2, off)
		_box(tp, Vector3(0,0,-tsz[i].z*0.5), tsz[i], _mat_body)
		if i < 3:
			_box(tp, Vector3(0,tsz[i].y*0.55,-tsz[i].z*0.4),
				 Vector3(0.04,0.07-float(i)*0.02,0.04), _mat_light)
		_tail.append(tp); tp2 = tp
	_box(tp2, Vector3(0,0,-0.14), Vector3(0.04,0.04,0.12), _mat_light)

func _build_leg(tp: Node3D, side: float) -> Array[Node3D]:
	_box(tp, Vector3(0,-0.14,0.04), Vector3(0.14,0.28,0.16), _mat_body)
	_box(tp, Vector3(0,-0.30,0.08), Vector3(0.10,0.08,0.10), _mat_light)
	var shin: Node3D = _pivot(tp, Vector3(0,-0.30,0.06))
	_box(shin, Vector3(0,-0.12,-0.02), Vector3(0.10,0.22,0.10), _mat_body)
	var foot: Node3D = _pivot(shin, Vector3(0,-0.24,-0.02))
	_box(foot, Vector3(0,-0.03,0.06), Vector3(0.10,0.06,0.20), _mat_body)
	for tt in range(3):
		var tx: float = (-0.06+float(tt)*0.06)*side
		_box(foot, Vector3(tx,-0.04,0.18+float(tt)*0.01), Vector3(0.04,0.04,0.10), _mat_body)
		_box(foot, Vector3(tx,-0.06,0.25), Vector3(0.03,0.03,0.05), _mat_dark)
	_box(foot, Vector3(0,0.02,0.22), Vector3(0.03,0.08,0.04), _mat_light)
	var r: Array[Node3D] = [shin,foot]; return r

func _box(p: Node3D, pos: Vector3, sz: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new(); mesh.size = sz
	mi.mesh=mesh; mi.position=pos; mi.material_override=mat; p.add_child(mi); return mi

func _sphere(p: Node3D, pos: Vector3, r: float, mat: StandardMaterial3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new(); mesh.radius=r; mesh.height=r*2.0
	mesh.radial_segments=8; mesh.rings=5
	mi.mesh=mesh; mi.position=pos; mi.material_override=mat; p.add_child(mi); return mi

func _pivot(p: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new(); n.position=pos; p.add_child(n); return n

# ── Physics process ───────────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	_time += delta
	_dash_cd      = max(_dash_cd - delta, 0.0)
	_attack_timer = max(_attack_timer - delta, 0.0)
	var on_floor: bool = is_on_floor()

	# Coyote
	if on_floor: _coyote = COYOTE_TIME
	else:        _coyote = max(_coyote - delta, 0.0)
	_jbuf = max(_jbuf - delta, 0.0)

	# ── DASH state ────────────────────────────────────────────────────────────
	if _state == State.DASH:
		_dash_timer = max(_dash_timer - delta, 0.0)
		velocity = _dash_dir * dash_speed
		velocity.y = 0.0
		if _dash_timer <= 0.0:
			_state = State.IDLE
		move_and_slide()
		_animate(delta)
		return   # Bỏ qua gravity & input khi dash

	# ── Gravity ───────────────────────────────────────────────────────────────
	if not on_floor:
		if velocity.y > 0.0: velocity.y -= _grav_rise * delta
		else:                velocity.y -= _grav_fall * delta
	else:
		velocity.y = -0.5

	# ── Jump ──────────────────────────────────────────────────────────────────
	if _jbuf > 0.0 and _coyote > 0.0 and _state != State.CROUCH:
		velocity.y = _jump_v
		_jbuf = 0.0; _coyote = 0.0
		_sy_tgt = 1.22

	# Landing squash
	if on_floor and not _was_floor: _sy_tgt = 0.76
	_was_floor = on_floor

	# Squash/stretch
	_sy_cur = lerp(_sy_cur, _sy_tgt, delta * 18.0)
	_sy_tgt = lerp(_sy_tgt, 1.0,     delta * 10.0)
	var sx: float = 1.0 + (1.0 - _sy_cur) * 0.5
	_rig.scale = Vector3(sx, _sy_cur, sx)

	# ── Movement input ────────────────────────────────────────────────────────
	var is_attacking: bool = _attack_timer > 0.0
	var is_crouching: bool = Input.is_key_pressed(KEY_CTRL)
	var is_sprinting: bool = Input.is_key_pressed(KEY_SHIFT) and not is_crouching
	var target_spd: float
	if is_crouching:    target_spd = crouch_speed
	elif is_sprinting:  target_spd = sprint_speed
	else:               target_spd = move_speed

	var dir := _read_input()
	if dir.length_squared() > 0.001 and not is_attacking:
		dir = dir.normalized()
		velocity.x = move_toward(velocity.x, dir.x * target_spd, acceleration * delta)
		velocity.z = move_toward(velocity.z, dir.z * target_spd, acceleration * delta)
		rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), delta * 14.0)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		velocity.z = move_toward(velocity.z, 0.0, friction * delta)

	# ── Dash trigger (Q) ──────────────────────────────────────────────────────
	if Input.is_key_pressed(KEY_Q) and _dash_cd <= 0.0 and not is_attacking:
		var dash_input := _read_input()
		_dash_dir = (dash_input.normalized() if dash_input.length_squared() > 0.001
					 else -global_transform.basis.z)
		_dash_dir.y = 0.0; _dash_dir = _dash_dir.normalized()
		_dash_timer = dash_duration
		_dash_cd    = dash_cooldown
		_state      = State.DASH
		_sy_tgt     = 1.15
		move_and_slide(); _animate(delta); return

	# ── Update state ──────────────────────────────────────────────────────────
	if is_attacking:
		_state = State.ATTACK
	elif not on_floor:
		_state = State.JUMP if velocity.y > 0.0 else State.FALL
	elif is_crouching:
		_state = State.CROUCH
	elif dir.length_squared() > 0.001:
		_state = State.SPRINT if is_sprinting else State.WALK
	else:
		_state = State.IDLE

	move_and_slide()
	_animate(delta)

func _read_input() -> Vector3:
	var rx: float = 0.0; var rz: float = 0.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):    rz -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):  rz += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):  rx -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): rx += 1.0
	if rx == 0.0 and rz == 0.0: return Vector3.ZERO
	if _camera == null: return Vector3.ZERO
	var cb := _camera.global_transform.basis
	var fwd := -cb.z; fwd.y = 0.0; fwd = fwd.normalized()
	var rgt :=  cb.x; rgt.y = 0.0; rgt = rgt.normalized()
	return fwd * -rz + rgt * rx

# ── Camera toggle ─────────────────────────────────────────────────────────────
func _toggle_camera() -> void:
	_use_tp = not _use_tp
	if _use_tp:
		if is_instance_valid(_iso_rig) and _iso_rig.has_method("deactivate"):
			_iso_rig.deactivate()
		if is_instance_valid(_tp_rig) and _tp_rig.has_method("activate"):
			_tp_rig.activate()
	else:
		if is_instance_valid(_tp_rig) and _tp_rig.has_method("deactivate"):
			_tp_rig.deactivate()
		if is_instance_valid(_iso_rig) and _iso_rig.has_method("activate"):
			_iso_rig.activate()
	# Cập nhật _camera để _read_input dùng đúng camera đang active
	await get_tree().process_frame
	_camera = get_viewport().get_camera_3d()

# ── Animation ─────────────────────────────────────────────────────────────────
func _animate(delta: float) -> void:
	var t: float = _time
	match _state:
		State.IDLE:    _anim_idle(delta, t)
		State.WALK:    _anim_walk(delta, t, 1.0)
		State.SPRINT:  _anim_walk(delta, t, sprint_cycle_mult)
		State.CROUCH:  _anim_crouch(delta, t)
		State.DASH:    _anim_dash(delta, t)
		State.ATTACK:  _anim_attack(delta, t)
		State.JUMP:    _anim_air(delta, t)
		State.FALL:    _anim_air(delta, t)

# ── IDLE ──────────────────────────────────────────────────────────────────────
func _anim_idle(delta: float, t: float) -> void:
	var b: float = sin(t * idle_breathe_spd)
	_rig.position.y = lerp(_rig.position.y, 0.10, delta * 8.0)
	_rig.rotation.x = lerp(_rig.rotation.x, 0.0, delta * 10.0)
	_rig.rotation.z = b * 0.012
	_neck.rotation.x = lerp(_neck.rotation.x, -0.28 + b*0.03, delta*5.0)
	_neck.rotation.y = b * 0.04
	_snout_bot.rotation.x = lerp(_snout_bot.rotation.x, 0.0, delta*4.0)
	_arm_l.rotation.x = lerp(_arm_l.rotation.x, -0.15, delta*5.0)
	_arm_r.rotation.x = lerp(_arm_r.rotation.x, -0.15, delta*5.0)
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
	var cyc: float = t * run_cycle_speed * speed_mult
	_rig.position.y = 0.10 + abs(sin(cyc)) * (0.04 + speed_mult*0.02)
	_rig.rotation.x = lerp(_rig.rotation.x, 0.0, delta * 10.0)
	_rig.rotation.z = sin(cyc*0.5) * (0.03 + speed_mult*0.01)
	_neck.rotation.x = -0.30 + sin(cyc)*0.07
	_neck.rotation.y = lerp(_neck.rotation.y, 0.0, delta*8.0)
	_snout_bot.rotation.x = abs(sin(cyc*0.5)) * 0.10
	_arm_l.rotation.x = sin(cyc+PI)*0.25; _arm_r.rotation.x = sin(cyc)*0.25
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
	# Toàn thân thấp xuống, đuôi nằm ngang, cổ vươn ra trước thấp
	_rig.position.y = lerp(_rig.position.y, -0.12, delta*10.0)
	_rig.rotation.x = lerp(_rig.rotation.x, 0.20, delta*8.0)   # Thân nghiêng ra trước
	_neck.rotation.x = lerp(_neck.rotation.x, -0.10, delta*6.0)
	_snout_bot.rotation.x = lerp(_snout_bot.rotation.x, 0.0, delta*4.0)
	_arm_l.rotation.x = lerp(_arm_l.rotation.x, 0.30, delta*6.0)
	_arm_r.rotation.x = lerp(_arm_r.rotation.x, 0.30, delta*6.0)
	# Chân gập sâu
	_thigh_l.rotation.x = lerp(_thigh_l.rotation.x, 0.60, delta*8.0)
	_shin_l.rotation.x  = lerp(_shin_l.rotation.x,  0.80, delta*8.0)
	_foot_l.rotation.x  = lerp(_foot_l.rotation.x, -0.40, delta*8.0)
	_thigh_r.rotation.x = lerp(_thigh_r.rotation.x, 0.60, delta*8.0)
	_shin_r.rotation.x  = lerp(_shin_r.rotation.x,  0.80, delta*8.0)
	_foot_r.rotation.x  = lerp(_foot_r.rotation.x, -0.40, delta*8.0)
	# Đuôi nằm ngang thẳng ra sau
	for i in range(_tail.size()):
		_tail[i].rotation.x = lerp(_tail[i].rotation.x, -0.10+float(i)*0.02, delta*5.0)
		_tail[i].rotation.y = sin(t*tail_sway_speed*0.3+float(i)*0.5)*(0.04+float(i)*0.02)

# ── DASH ──────────────────────────────────────────────────────────────────────
func _anim_dash(delta: float, _t: float) -> void:
	var prog: float = 1.0 - (_dash_timer / dash_duration)   # 0→1 theo tiến trình
	# Thân lao ra trước mạnh
	_rig.position.y = lerp(_rig.position.y, 0.06, delta*20.0)
	_rig.rotation.x = lerp(_rig.rotation.x, 0.35, delta*20.0)
	_neck.rotation.x = lerp(_neck.rotation.x, 0.10, delta*15.0)
	# Tay duỗi ra sau như đang lao
	_arm_l.rotation.x = lerp(_arm_l.rotation.x, -0.60, delta*20.0)
	_arm_r.rotation.x = lerp(_arm_r.rotation.x, -0.60, delta*20.0)
	# Chân duỗi ra sau
	_thigh_l.rotation.x = lerp(_thigh_l.rotation.x, -0.50, delta*20.0)
	_shin_l.rotation.x  = lerp(_shin_l.rotation.x,   0.20, delta*20.0)
	_thigh_r.rotation.x = lerp(_thigh_r.rotation.x, -0.50, delta*20.0)
	_shin_r.rotation.x  = lerp(_shin_r.rotation.x,   0.20, delta*20.0)
	# Đuôi thẳng ra sau
	for i in range(_tail.size()):
		_tail[i].rotation.x = lerp(_tail[i].rotation.x, -0.15, delta*18.0)
		_tail[i].rotation.y = lerp(_tail[i].rotation.y, 0.0,   delta*18.0)

# ── ATTACK ────────────────────────────────────────────────────────────────────
func _anim_attack(delta: float, _t: float) -> void:
	var prog: float = 1.0 - (_attack_timer / attack_duration)   # 0→1
	# Phase 1 (0→0.4): Windup – lùi đầu về sau, tay co lên
	# Phase 2 (0.4→1): Strike – đầu phóng ra trước, há miệng, tay tát mạnh
	if prog < 0.4:
		var p: float = prog / 0.4
		_neck.rotation.x = lerp(_neck.rotation.x, 0.20, delta*18.0)   # đầu lùi
		_snout_bot.rotation.x = lerp(_snout_bot.rotation.x, 0.0, delta*10.0)
		_arm_l.rotation.x = lerp(_arm_l.rotation.x, -0.80, delta*18.0)
		_arm_r.rotation.x = lerp(_arm_r.rotation.x, -0.80, delta*18.0)
		_rig.rotation.x   = lerp(_rig.rotation.x, -0.10, delta*12.0)
	else:
		var p: float = (prog - 0.4) / 0.6
		# Đầu phóng mạnh ra trước
		_neck.rotation.x = lerp(_neck.rotation.x, -0.55, delta*30.0)
		# Há miệng cắn
		_snout_bot.rotation.x = lerp(_snout_bot.rotation.x, 0.28, delta*30.0)
		# Tay tát xuống
		_arm_l.rotation.x = lerp(_arm_l.rotation.x, 0.70, delta*30.0)
		_arm_r.rotation.x = lerp(_arm_r.rotation.x, 0.70, delta*30.0)
		# Toàn thân lao về trước
		_rig.rotation.x = lerp(_rig.rotation.x, 0.15, delta*20.0)
		# Đuôi vút lên để cân bằng
		for i in range(_tail.size()):
			_tail[i].rotation.x = lerp(_tail[i].rotation.x,
									   0.20+float(i)*0.08, delta*20.0)
	# Chân đứng vững
	_thigh_l.rotation.x = lerp(_thigh_l.rotation.x, 0.20, delta*8.0)
	_shin_l.rotation.x  = lerp(_shin_l.rotation.x,  0.35, delta*8.0)
	_thigh_r.rotation.x = lerp(_thigh_r.rotation.x, 0.20, delta*8.0)
	_shin_r.rotation.x  = lerp(_shin_r.rotation.x,  0.35, delta*8.0)

# ── AIR (JUMP + FALL) ─────────────────────────────────────────────────────────
func _anim_air(delta: float, _t: float) -> void:
	_rig.position.y = lerp(_rig.position.y, 0.10, delta*5.0)
	var rising: bool = _state == State.JUMP
	_rig.rotation.x = lerp(_rig.rotation.x, 0.0, delta * 10.0)
	var tuck: float
	if rising: tuck = clamp(velocity.y / _jump_v, 0.0, 1.0)
	else:      tuck = clamp(1.0 + velocity.y / _jump_v, 0.0, 1.0) * 0.3
	_thigh_l.rotation.x = lerp(_thigh_l.rotation.x,-0.30-tuck*0.5, delta*12.0)
	_shin_l.rotation.x  = lerp(_shin_l.rotation.x,  0.60+tuck*0.6, delta*12.0)
	_foot_l.rotation.x  = lerp(_foot_l.rotation.x, -0.40,           delta*10.0)
	_thigh_r.rotation.x = lerp(_thigh_r.rotation.x,-0.30-tuck*0.5, delta*12.0)
	_shin_r.rotation.x  = lerp(_shin_r.rotation.x,  0.60+tuck*0.6, delta*12.0)
	_foot_r.rotation.x  = lerp(_foot_r.rotation.x, -0.40,           delta*10.0)
	var fall_t: float = clamp(-velocity.y/6.0, 0.0, 1.0)
	_neck.rotation.x = lerp(_neck.rotation.x, -0.50+fall_t*0.20, delta*8.0)
	_rig.rotation.x  = lerp(_rig.rotation.x, 0.0, delta*10.0)
	for i in range(_tail.size()):
		var droop: float = (0.15+float(i)*0.08) if not rising else -0.05
		_tail[i].rotation.x = lerp(_tail[i].rotation.x, droop, delta*6.0)
		_tail[i].rotation.y = lerp(_tail[i].rotation.y, 0.0,   delta*5.0)
