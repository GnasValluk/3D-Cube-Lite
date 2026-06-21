## core/character_base.gd
## Base class cho mọi nhân vật điều khiển được.
## Chứa: physics, state machine, input, camera switching, squash/stretch.
## Subclass implement: _build_character(), _animate(delta)

extends CharacterBody3D
class_name CharacterBase

# ── Stats ─────────────────────────────────────────────────────────────────────
@export var move_speed:        float = 5.5
@export var sprint_speed:      float = 9.5
@export var crouch_speed:      float = 2.5
@export var acceleration:      float = 26.0
@export var friction:          float = 20.0
@export var jump_height:       float = 1.4
@export var jump_time_rise:    float = 0.28
@export var jump_time_fall:    float = 0.20
@export var dash_speed:        float = 18.0
@export var dash_duration:     float = 0.18
@export var dash_cooldown:     float = 0.80
@export var attack_duration:   float = 0.45

# ── State machine ─────────────────────────────────────────────────────────────
enum State { IDLE, WALK, SPRINT, CROUCH, DASH, ATTACK, DEVOUR, JUMP, FALL }
var _state: State = State.IDLE

# ── Timers ────────────────────────────────────────────────────────────────────
const COYOTE_TIME: float = 0.12
const JUMP_BUFFER: float = 0.10
var _coyote:          float   = 0.0
var _jbuf:            float   = 0.0
var _dash_timer:      float   = 0.0
var _dash_cd:         float   = 0.0
var _attack_timer:    float   = 0.0
var _attack2_timer:   float   = 0.0
var _attack2_duration: float  = 0.70
var _action_lunge_timer: float = 0.0
var _action_lunge_speed: float = 0.0
var _dash_dir:        Vector3 = Vector3.ZERO

# ── Physics internals ─────────────────────────────────────────────────────────
var _jump_v:    float = 0.0
var _grav_rise: float = 0.0
var _grav_fall: float = 0.0
var _was_floor: bool  = false
var _time:      float = 0.0

# ── Squash / stretch ──────────────────────────────────────────────────────────
var _sy_tgt: float = 1.0
var _sy_cur: float = 1.0

# ── Visual root ───────────────────────────────────────────────────────────────
var _rig: Node3D

# ── Active flag ───────────────────────────────────────────────────────────────
var _active: bool = true

# ── Camera refs ───────────────────────────────────────────────────────────────
var _camera:  Camera3D
var _iso_rig: Node3D
var _tp_rig:  Node3D
var _use_tp:  bool = false

# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_jump_v    = (2.0 * jump_height) / jump_time_rise
	_grav_rise = (2.0 * jump_height) / (jump_time_rise * jump_time_rise)
	_grav_fall = (2.0 * jump_height) / (jump_time_fall * jump_time_fall)
	_build_character()
	await get_tree().process_frame
	var root: Node = get_parent().get_parent()
	if root == null:
		root = get_parent()
	_iso_rig = root.get_node_or_null("CameraRig")
	_tp_rig  = root.get_node_or_null("TPCameraRig")
	_camera  = get_viewport().get_camera_3d()

# ── Overrideable interface ────────────────────────────────────────────────────
func _build_character() -> void:
	pass

func _animate(_delta: float) -> void:
	pass

func _on_primary_attack() -> void:
	pass

func _on_secondary_attack() -> void:
	pass

# ── CharacterManager API ──────────────────────────────────────────────────────
func set_active(value: bool) -> void:
	_active = value
	set_physics_process(value)
	set_process_unhandled_input(value)
	set_process_unhandled_key_input(value)
	if _rig:
		_rig.visible = value
	if value:
		await get_tree().process_frame
		_camera = get_viewport().get_camera_3d()

# ── Input ─────────────────────────────────────────────────────────────────────
func _unhandled_key_input(event: InputEvent) -> void:
	if not _active:
		return
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo:
			if k.keycode == KEY_SPACE:
				_jbuf = JUMP_BUFFER
			if k.keycode == KEY_F1:
				_toggle_camera()
			if k.keycode == KEY_R:
				if _attack2_timer <= 0.0 and _attack_timer <= 0.0 and _state != State.DASH:
					_attack2_timer = _attack2_duration
					_state = State.DEVOUR
					_on_secondary_attack()

func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_LEFT:
				if _attack_timer <= 0.0 and _attack2_timer <= 0.0 and _state != State.DASH:
					_attack_timer = attack_duration
					_state = State.ATTACK
					_on_primary_attack()

# ── Physics ───────────────────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if not _active:
		return
	_time          += delta
	_dash_cd        = max(_dash_cd - delta, 0.0)
	_attack_timer   = max(_attack_timer - delta, 0.0)
	_attack2_timer  = max(_attack2_timer - delta, 0.0)
	_action_lunge_timer = max(_action_lunge_timer - delta, 0.0)
	var on_floor: bool = is_on_floor()

	if on_floor:
		_coyote = COYOTE_TIME
	else:
		_coyote = max(_coyote - delta, 0.0)
	_jbuf = max(_jbuf - delta, 0.0)

	# DASH ────────────────────────────────────────────────────────────────────
	if _state == State.DASH:
		_dash_timer = max(_dash_timer - delta, 0.0)
		velocity    = _dash_dir * dash_speed
		velocity.y  = 0.0
		if _dash_timer <= 0.0:
			_state = State.IDLE
		move_and_slide()
		_animate(delta)
		return

	# Gravity ─────────────────────────────────────────────────────────────────
	if not on_floor:
		if velocity.y > 0.0:
			velocity.y -= _grav_rise * delta
		else:
			velocity.y -= _grav_fall * delta
	else:
		velocity.y = -0.5

	# Jump ────────────────────────────────────────────────────────────────────
	if _jbuf > 0.0 and _coyote > 0.0 and _state != State.CROUCH:
		velocity.y = _jump_v
		_jbuf = 0.0
		_coyote = 0.0
		_sy_tgt = 1.22

	if on_floor and not _was_floor:
		_sy_tgt = 0.76
	_was_floor = on_floor

	_sy_cur = lerp(_sy_cur, _sy_tgt, delta * 18.0)
	_sy_tgt = lerp(_sy_tgt, 1.0,     delta * 10.0)
	if _rig:
		var sx: float = 1.0 + (1.0 - _sy_cur) * 0.5
		_rig.scale = Vector3(sx, _sy_cur, sx)

	# Movement ────────────────────────────────────────────────────────────────
	var attacking: bool = _attack_timer > 0.0
	var devouring: bool = _attack2_timer > 0.0
	var lunging: bool = _action_lunge_timer > 0.0 and (attacking or devouring)
	var crouching: bool = Input.is_key_pressed(KEY_CTRL)
	var sprinting: bool = Input.is_key_pressed(KEY_SHIFT) and not crouching
	var spd: float
	if crouching:
		spd = crouch_speed
	elif sprinting:
		spd = sprint_speed
	else:
		spd = move_speed

	var dir := _read_input()
	if dir.length_squared() > 0.001 and not attacking and not devouring:
		dir = dir.normalized()
		velocity.x = move_toward(velocity.x, dir.x * spd, acceleration * delta)
		velocity.z = move_toward(velocity.z, dir.z * spd, acceleration * delta)
		rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), delta * 14.0)
	elif lunging:
		var fwd := Vector3(sin(rotation.y), 0.0, cos(rotation.y)).normalized()
		velocity.x = fwd.x * _action_lunge_speed
		velocity.z = fwd.z * _action_lunge_speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		velocity.z = move_toward(velocity.z, 0.0, friction * delta)

	# Dash trigger ────────────────────────────────────────────────────────────
	if Input.is_key_pressed(KEY_Q) and _dash_cd <= 0.0 and not attacking and not devouring:
		var di := _read_input()
		if di.length_squared() > 0.001:
			_dash_dir = di.normalized()
		else:
			_dash_dir = -global_transform.basis.z
		_dash_dir.y = 0.0
		_dash_dir    = _dash_dir.normalized()
		_dash_timer  = dash_duration
		_dash_cd     = dash_cooldown
		_state       = State.DASH
		_sy_tgt      = 1.15
		move_and_slide()
		_animate(delta)
		return

	# State update ────────────────────────────────────────────────────────────
	if attacking:
		_state = State.ATTACK
	elif devouring:
		_state = State.DEVOUR
	elif not on_floor:
		if velocity.y > 0.0:
			_state = State.JUMP
		else:
			_state = State.FALL
	elif crouching:
		_state = State.CROUCH
	elif dir.length_squared() > 0.001:
		if sprinting:
			_state = State.SPRINT
		else:
			_state = State.WALK
	else:
		_state = State.IDLE

	move_and_slide()
	_animate(delta)

# ── Read input direction ──────────────────────────────────────────────────────
func _read_input() -> Vector3:
	var rx: float = 0.0
	var rz: float = 0.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):    rz -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):  rz += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):  rx -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): rx += 1.0
	if rx == 0.0 and rz == 0.0:
		return Vector3.ZERO
	if _camera == null:
		return Vector3.ZERO
	var cb:  Basis   = _camera.global_transform.basis
	var fwd: Vector3 = -cb.z; fwd.y = 0.0; fwd = fwd.normalized()
	var rgt: Vector3 =  cb.x; rgt.y = 0.0; rgt = rgt.normalized()
	return fwd * -rz + rgt * rx

func _start_forward_lunge(speed: float, duration: float) -> void:
	_action_lunge_speed = speed
	_action_lunge_timer = duration

# ── Camera toggle ─────────────────────────────────────────────────────────────
func _toggle_camera() -> void:
	_use_tp = not _use_tp
	if _use_tp:
		if is_instance_valid(_iso_rig):
			_iso_rig.call("deactivate")
		if is_instance_valid(_tp_rig):
			_tp_rig.call("activate")
	else:
		if is_instance_valid(_tp_rig):
			_tp_rig.call("deactivate")
		if is_instance_valid(_iso_rig):
			_iso_rig.call("activate")
	await get_tree().process_frame
	_camera = get_viewport().get_camera_3d()
