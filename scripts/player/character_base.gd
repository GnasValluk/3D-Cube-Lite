## character_base.gd
## Base class cho tất cả nhân vật có thể điều khiển.
## Xử lý: physics, state machine, input, camera switching.
## Subclass phải override: _build_character(), _animate(delta)
## và khai báo: _rig, _neck, _snout_bot, _tail[]

extends CharacterBody3D
## CharacterBase – duplicate class_name removed; use core version

# ── Export – tuỳ chỉnh per-character ─────────────────────────────────────────
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

# ── State ─────────────────────────────────────────────────────────────────────
enum State { IDLE, WALK, SPRINT, CROUCH, DASH, ATTACK, JUMP, FALL }
var _state: State = State.IDLE

# ── Timers ────────────────────────────────────────────────────────────────────
const COYOTE_TIME: float = 0.12
const JUMP_BUFFER: float = 0.10
var _coyote:       float = 0.0
var _jbuf:         float = 0.0
var _dash_timer:   float = 0.0
var _dash_cd:      float = 0.0
var _attack_timer: float = 0.0
var _dash_dir:     Vector3 = Vector3.ZERO

# ── Physics ───────────────────────────────────────────────────────────────────
var _jump_v:    float
var _grav_rise: float
var _grav_fall: float
var _was_floor: bool = false
var _time:      float = 0.0

# ── Camera ────────────────────────────────────────────────────────────────────
var _camera:   Camera3D
var _iso_rig:  Node3D
var _tp_rig:   Node3D
var _use_tp:   bool = false

# ── Squash / stretch ──────────────────────────────────────────────────────────
var _sy_tgt: float = 1.0
var _sy_cur: float = 1.0

# ── Rig (subclass phải gán) ───────────────────────────────────────────────────
var _rig: Node3D   # root visual node, sẽ bị scale squash/stretch

# ── Visibility (character manager bật/tắt) ───────────────────────────────────
var _active: bool = true

# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	_jump_v    = (2.0 * jump_height) / jump_time_rise
	_grav_rise = (2.0 * jump_height) / (jump_time_rise * jump_time_rise)
	_grav_fall = (2.0 * jump_height) / (jump_time_fall * jump_time_fall)
	_build_character()
	await get_tree().process_frame
	# Camera rigs nằm ở scene root (cha của CharacterManager)
	var scene_root: Node = get_parent().get_parent()
	if scene_root == null: scene_root = get_parent()
	_iso_rig = scene_root.get_node_or_null("CameraRig")
	_tp_rig  = scene_root.get_node_or_null("TPCameraRig")
	_camera  = get_viewport().get_camera_3d()

# ── Override in subclass ──────────────────────────────────────────────────────
func _build_character() -> void:
	pass   # subclass builds mesh + collision here

# ── Activate / Deactivate (called by CharacterManager) ───────────────────────
func set_active(value: bool) -> void:
	_active = value
	set_physics_process(value)
	set_process_unhandled_input(value)
	set_process_unhandled_key_input(value)
	if _rig:
		_rig.visible = value
	if value:
		# Refresh camera reference khi được kích hoạt
		await get_tree().process_frame
		_camera = get_viewport().get_camera_3d()

# ── Input ─────────────────────────────────────────────────────────────────────
func _unhandled_key_input(event: InputEvent) -> void:
	if not _active: return
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.keycode == KEY_SPACE and k.pressed and not k.echo:
			_jbuf = JUMP_BUFFER
		if k.keycode == KEY_F1 and k.pressed and not k.echo:
			_toggle_camera()

func _unhandled_input(event: InputEvent) -> void:
	if not _active: return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			if _attack_timer <= 0.0 and _state != State.DASH:
				_attack_timer = attack_duration
				_state = State.ATTACK

# ── Physics process ───────────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if not _active: return
	_time     += delta
	_dash_cd      = max(_dash_cd - delta, 0.0)
	_attack_timer = max(_attack_timer - delta, 0.0)
	var on_floor: bool = is_on_floor()

	# Coyote time
	if on_floor: _coyote = COYOTE_TIME
	else:        _coyote = max(_coyote - delta, 0.0)
	_jbuf = max(_jbuf - delta, 0.0)

	# ── DASH ─────────────────────────────────────────────────────────────────
	if _state == State.DASH:
		_dash_timer = max(_dash_timer - delta, 0.0)
		velocity = _dash_dir * dash_speed
		velocity.y = 0.0
		if _dash_timer <= 0.0:
			_state = State.IDLE
		move_and_slide()
		_animate(delta)
		return

	# ── Gravity ───────────────────────────────────────────────────────────────
	if not on_floor:
		if velocity.y > 0.0: velocity.y -= _grav_rise * delta
		else:                velocity.y -= _grav_fall * delta
	else:
		velocity.y = -0.5

	# ── Jump ─────────────────────────────────────────────────────────────────
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
	if _rig: _rig.scale = Vector3(sx, _sy_cur, sx)

	# ── Movement input ────────────────────────────────────────────────────────
	var is_attacking: bool = _attack_timer > 0.0
	var is_crouching: bool = Input.is_key_pressed(KEY_CTRL)
	var is_sprinting: bool = Input.is_key_pressed(KEY_SHIFT) and not is_crouching
	var target_spd: float
	if is_crouching:   target_spd = crouch_speed
	elif is_sprinting: target_spd = sprint_speed
	else:              target_spd = move_speed

	var dir := _read_input()
	if dir.length_squared() > 0.001 and not is_attacking:
		dir = dir.normalized()
		velocity.x = move_toward(velocity.x, dir.x * target_spd, acceleration * delta)
		velocity.z = move_toward(velocity.z, dir.z * target_spd, acceleration * delta)
		rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), delta * 14.0)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		velocity.z = move_toward(velocity.z, 0.0, friction * delta)

	# ── Dash trigger (Q) ─────────────────────────────────────────────────────
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

	# ── State update ──────────────────────────────────────────────────────────
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

# ── Animation (override in subclass) ─────────────────────────────────────────
func _animate(_delta: float) -> void:
	pass

# ── Input direction ───────────────────────────────────────────────────────────
func _read_input() -> Vector3:
	var rx: float = 0.0; var rz: float = 0.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):    rz -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):  rz += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):  rx -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): rx += 1.0
	if rx == 0.0 and rz == 0.0: return Vector3.ZERO
	if _camera == null: return Vector3.ZERO
	var cb  := _camera.global_transform.basis
	var fwd := -cb.z; fwd.y = 0.0; fwd = fwd.normalized()
	var rgt :=  cb.x; rgt.y = 0.0; rgt = rgt.normalized()
	return fwd * -rz + rgt * rx

# ── Camera toggle (F1) ────────────────────────────────────────────────────────
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
	await get_tree().process_frame
	_camera = get_viewport().get_camera_3d()

# ── Primitive helpers (shared across all characters) ─────────────────────────
func _emit_mat(albedo: Color, emit: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = albedo; m.roughness = 1.0; m.metallic_specular = 0.0
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.emission_enabled = true; m.emission = emit
	m.emission_energy_multiplier = energy
	return m

func _box(p: Node3D, pos: Vector3, sz: Vector3, mat: StandardMaterial3D) -> MeshInstance3D:
	var mi   := MeshInstance3D.new()
	var mesh := BoxMesh.new(); mesh.size = sz
	mi.mesh = mesh; mi.position = pos; mi.material_override = mat
	p.add_child(mi); return mi

func _sphere(p: Node3D, pos: Vector3, r: float, mat: StandardMaterial3D) -> MeshInstance3D:
	var mi   := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = r; mesh.height = r * 2.0
	mesh.radial_segments = 10; mesh.rings = 6
	mi.mesh = mesh; mi.position = pos; mi.material_override = mat
	p.add_child(mi); return mi

func _cylinder(p: Node3D, pos: Vector3, r: float, h: float,
			   mat: StandardMaterial3D) -> MeshInstance3D:
	var mi   := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = r; mesh.bottom_radius = r; mesh.height = h
	mesh.radial_segments = 8
	mi.mesh = mesh; mi.position = pos; mi.material_override = mat
	p.add_child(mi); return mi

func _prism(p: Node3D, pos: Vector3, sz: Vector3, rot: Vector3,
			mat: StandardMaterial3D) -> MeshInstance3D:
	# Dùng BoxMesh vát để giả prism (đủ dùng cho vây / sừng)
	var mi   := MeshInstance3D.new()
	var mesh := BoxMesh.new(); mesh.size = sz
	mi.mesh = mesh; mi.position = pos; mi.rotation = rot
	mi.material_override = mat
	p.add_child(mi); return mi

func _pivot(p: Node3D, pos: Vector3) -> Node3D:
	var n := Node3D.new(); n.position = pos; p.add_child(n); return n
