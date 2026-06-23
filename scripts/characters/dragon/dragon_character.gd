## dragon/dragon_character.gd – Rồng Neon (Nhân vật 2)
## LMB = Khè lửa + bắn fireball
## R = Cúi xuống ăn xác (Devour)

extends CharacterBase
class_name DragonCharacter

var _mesh: DragonMesh
var _anim: DragonAnimator

# Thời điểm trong animation để bắn fireball (giây sau khi bắt đầu khè)
const FIRE_SPAWN_TIME := 0.30
const FLIGHT_DOUBLE_TAP_WINDOW := 1.0
const FLIGHT_DURATION := 10.0
const FLIGHT_TAKEOFF_TIME := 0.60
const FLIGHT_LANDING_TIME := 0.60
const FLIGHT_CRUISE_HEIGHT := 3.0

var _fire_spawned: bool = false   # tránh spam
var _last_space_press_time: float = -10.0
var _flying: bool = false
var _flight_timer: float = 0.0
var _flight_ground_y: float = 0.0
var _flight_cruise_y: float = 0.0
var _flight_anim_blend: float = 0.0
var _flight_landing: bool = false
var _flight_landing_start_y: float = 0.0
var _flight_dash_timer: float = 0.0
var _flight_cd: float = 0.0
@export var flight_cooldown: float = 5.0

func _build_character() -> void:
	move_speed       = 4.8
	sprint_speed     = 8.5
	jump_height      = 1.8
	dash_speed       = 16.0
	attack_duration  = 0.65
	_attack2_duration = 0.80
	lmb_cooldown     = 1.0
	q_cooldown       = 2.0
	r_cooldown       = 5.0
	character_name   = "Dragon"
	element          = Element.HAC_AM

	# Collision
	var col := CollisionShape3D.new()
	var cs  := CapsuleShape3D.new()
	cs.radius = 0.42; cs.height = 1.30
	col.shape = cs; col.position = Vector3(0, 0.65, 0)
	add_child(col)

	# Mesh
	_mesh = DragonMesh.new()
	_mesh.build(self)
	_rig = _mesh.rig

	# Animator
	_anim = DragonAnimator.new()
	_anim.setup(_mesh, self)

# ── LMB: Khè lửa → reset fire_spawned flag ───────────────────────────────────
func _on_primary_attack() -> void:
	_fire_spawned = false

func _on_secondary_attack() -> void:
	var fire_dir: Vector3 = _aim_dir if _aim_dir.length_squared() > 0.001 else Vector3(sin(rotation.y), 0.0, cos(rotation.y)).normalized()
	var pos: Vector3 = global_position + fire_dir * 1.0
	var atom: DragonAtom = DragonAtom.new()
	get_parent().add_child(atom)
	atom.setup(pos, fire_dir, self)

func _on_show_animation() -> void:
	if _flying:
		return
	_attack2_timer = _attack2_duration
	_state = State.DEVOUR

func _unhandled_key_input(event: InputEvent) -> void:
	if not _active:
		return
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo and k.keycode == KEY_SPACE:
			var now: float = float(Time.get_ticks_msec()) * 0.001
			if _flying:
				if not _flight_landing:
					_begin_landing()
				return
			var double_tap: bool = (now - _last_space_press_time) <= FLIGHT_DOUBLE_TAP_WINDOW
			_last_space_press_time = now
			if double_tap:
				if _state != State.DASH and _attack_timer <= 0.0 and _attack2_timer <= 0.0:
					_start_flight()
					return
			super._unhandled_key_input(event)
			return
	super._unhandled_key_input(event)

func _unhandled_input(event: InputEvent) -> void:
	if _flying:
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
				if _attack_timer <= 0.0 and _attack2_timer <= 0.0:
					_aim_dir = _calc_aim_dir()
					var fwd := global_transform.basis.z
					if _aim_dir.dot(fwd) < 0.99:
						rotation.y = atan2(_aim_dir.x, _aim_dir.z)
					_attack_timer = attack_duration
					_state = State.ATTACK
					_on_primary_attack()
		return
	super._unhandled_input(event)

# ── Spawn fireball vào đúng thời điểm trong animation ────────────────────────
func _physics_process(delta: float) -> void:
	_flight_cd = max(_flight_cd - delta, 0.0)
	if _flying:
		_update_flight(delta)
	else:
		super._physics_process(delta)
		if is_on_floor():
			_flight_ground_y = global_position.y

	# Spawn fireball khi đã qua FIRE_SPAWN_TIME trong animation khè
	if _state == State.ATTACK and not _fire_spawned:
		var elapsed: float = attack_duration - _attack_timer
		if elapsed >= FIRE_SPAWN_TIME:
			_spawn_fireball()
			_fire_spawned = true

func is_flying() -> bool:
	return _flying

func get_flight_blend() -> float:
	return _flight_anim_blend

func is_flight_dashing() -> bool:
	return _flight_dash_timer > 0.0

func _start_flight() -> void:
	if _flight_cd > 0.0:
		return
	_flying = true
	_flight_timer = 0.0
	_flight_anim_blend = 0.0
	_flight_landing = false
	_attack_timer = 0.0
	_attack2_timer = 0.0
	_dash_timer = 0.0
	_jbuf = 0.0
	if is_on_floor():
		_flight_ground_y = global_position.y
	_flight_cruise_y = _flight_ground_y + FLIGHT_CRUISE_HEIGHT
	velocity = Vector3.ZERO
	_state = State.JUMP

func _begin_landing() -> void:
	_flight_landing = true
	_flight_timer = 0.0
	_flight_landing_start_y = global_position.y

func _update_flight(delta: float) -> void:
	_time += delta
	_flight_timer += delta
	var cd_delta: float = delta * cooldown_rate
	_lmb_cd = max(_lmb_cd - cd_delta, 0.0)
	_q_cd = max(_q_cd - cd_delta, 0.0)
	_r_cd = max(_r_cd - cd_delta, 0.0)
	_dash_cd = max(_dash_cd - delta, 0.0)
	_attack_timer = max(_attack_timer - delta, 0.0)
	_attack2_timer = max(_attack2_timer - delta, 0.0)
	_flight_dash_timer = max(_flight_dash_timer - delta, 0.0)
	if _attack_timer <= 0.0 and _state == State.ATTACK:
		_state = State.JUMP

	var dir := _read_input()
	var spd: float = move_speed * 0.9

	# Dash during flight
	var want_dash: bool = Input.is_key_pressed(KEY_Q) and _q_cd <= 0.0 and _attack_timer <= 0.0
	if want_dash:
		var ddir: Vector3 = dir if dir.length_squared() > 0.001 else -global_transform.basis.z
		ddir.y = 0.0
		velocity = ddir.normalized() * dash_speed * 1.2
		_q_cd = q_cooldown
		_dash_cd = dash_cooldown
		_flight_dash_timer = 0.25
	elif dir.length_squared() > 0.001:
		dir = dir.normalized()
		velocity.x = move_toward(velocity.x, dir.x * spd, acceleration * delta)
		velocity.z = move_toward(velocity.z, dir.z * spd, acceleration * delta)
		rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), delta * 10.0)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		velocity.z = move_toward(velocity.z, 0.0, friction * delta)

	if not _flight_landing and _flight_timer >= FLIGHT_DURATION:
		_begin_landing()

	var desired_y: float
	if _flight_landing:
		var land_p: float = smoothstep(0.0, 1.0, min(_flight_timer / FLIGHT_LANDING_TIME, 1.0))
		_flight_anim_blend = 1.0 - land_p
		desired_y = lerp(_flight_landing_start_y, _flight_ground_y + 0.05, land_p)
	elif _flight_timer < FLIGHT_TAKEOFF_TIME:
		var lift_p: float = smoothstep(0.0, 1.0, _flight_timer / FLIGHT_TAKEOFF_TIME)
		_flight_anim_blend = lift_p
		desired_y = lerp(_flight_ground_y + 0.10, _flight_cruise_y, lift_p)
	else:
		_flight_anim_blend = 1.0
		desired_y = _flight_cruise_y + sin(_time * 4.0) * 0.10

	var target_vertical_speed: float = clamp((desired_y - global_position.y) * 6.0, -4.5, 5.0)
	velocity.y = move_toward(velocity.y, target_vertical_speed, 18.0 * delta)
	_state = State.JUMP
	move_and_slide()
	if _flight_landing and (is_on_floor() or global_position.y <= _flight_ground_y + 0.08):
		_flying = false
		_flight_anim_blend = 0.0
		_flight_landing = false
		_flight_timer = 0.0
		_flight_cd = flight_cooldown
		velocity.y = -0.5
		if Vector2(velocity.x, velocity.z).length_squared() > 0.04:
			_state = State.WALK
		else:
			_state = State.IDLE
		_animate(delta)
		return
	_animate(delta)

func _spawn_fireball() -> void:
	var fb := DragonFireball.new()

	var fire_dir: Vector3 = _aim_dir if _aim_dir.length_squared() > 0.001 else Vector3(sin(rotation.y), 0.0, cos(rotation.y)).normalized()

	# Vị trí miệng: offset về phía trước + lên cao
	var mouth_pos: Vector3 = global_position + Vector3(0, 1.4, 0) + fire_dir * 0.8
	if _mesh and _mesh.head_pivot:
		mouth_pos = _mesh.head_pivot.global_position + fire_dir * 0.6

	get_parent().add_child(fb)
	fb.setup(mouth_pos, fire_dir, self)

func _animate(delta: float) -> void:
	_anim.animate(delta)
