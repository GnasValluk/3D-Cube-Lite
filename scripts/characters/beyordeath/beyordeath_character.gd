extends CharacterBase
class_name BeyordeathCharacter

var _mesh: BeyordeathMesh
var _anim: BeyordeathAnimator

var _burst_count: int = 0
var _burst_elapsed: float = 0.0
const BURST_INTERVAL: float = 0.06
const BURST_SHOTS: int = 6

const DOUBLE_TAP_WINDOW := 1.0
const JET_DURATION := 10.0
const JET_TAKEOFF_TIME := 0.50
const JET_LANDING_TIME := 0.50
const JET_CRUISE_HEIGHT := 3.0

var _last_space_press: float = -10.0
var _jet_mode: bool = false
var _jet_timer: float = 0.0
var _jet_ground_y: float = 0.0
var _jet_cruise_y: float = 0.0
var _jet_landing: bool = false
var _jet_landing_start_y: float = 0.0
var _flight_cd: float = 0.0
@export var flight_cooldown: float = 10.0

var _jet_dash_timer: float = 0.0
var _jet_dash_dir: Vector3 = Vector3.FORWARD
var _jet_bomb_interval: float = 0.0
var _jet_q_bomb_count: int = 0
const JET_DASH_BOMB_COUNT: int = 15
const JET_BURST_SHOTS: int = 10
const JET_BURST_INTERVAL: float = 0.05

func _build_character() -> void:
	move_speed = 5.0
	sprint_speed = 10.0
	jump_height = 1.3
	dash_speed = 19.0
	dash_duration = 0.18
	attack_duration = 0.55
	_attack2_duration = 0.80
	attack_power = 165
	defense = 12
	lmb_cooldown = 1.0
	q_cooldown = 3.0
	r_cooldown = 7.0
	max_hp = 450
	mana_cost_lmb = 0
	mana_cost_q   = 0
	mana_cost_r   = 130
	character_name = "Beyordeath"
	element = Element.DECAY

	var col := CollisionShape3D.new()
	var cs := CapsuleShape3D.new()
	cs.radius = 0.35
	cs.height = 1.30
	col.shape = cs
	col.position = Vector3(0, 0.65, 0)
	add_child(col)

	_mesh = BeyordeathMesh.new()
	_mesh.build(self)
	_rig = _mesh.rig

	_anim = BeyordeathAnimator.new()
	_anim.setup(_mesh, self)

func _unhandled_key_input(event: InputEvent) -> void:
	if not _active or not _is_player:
		return
	if _is_building_placing():
		return
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo:
			if k.keycode == KEY_SPACE:
				_handle_space()
				return
			if k.keycode == KEY_CTRL:
				if _jet_mode:
					_begin_landing()
					return
				if _attack_timer <= 0.0 and _attack2_timer <= 0.0 and _state != State.DASH:
					_on_show_animation()
				return
			if k.keycode == KEY_R:
				if _r_cd <= 0.0 and _attack2_timer <= 0.0 and _attack_timer <= 0.0 and _state != State.DASH:
					if not try_skill(mana_cost_r):
						return
					_aim_dir = _calc_aim_dir()
					var fwd := global_transform.basis.z
					if _aim_dir.dot(fwd) < 0.99:
						rotation.y = atan2(_aim_dir.x, _aim_dir.z)
					_r_cd = r_cooldown
					_on_secondary_attack()
				return
	super._unhandled_key_input(event)

func _handle_space() -> void:
	if _jet_mode:
		_begin_landing()
		return
	var now: float = Time.get_ticks_msec() * 0.001
	var double_tap: bool = (now - _last_space_press) <= DOUBLE_TAP_WINDOW
	_last_space_press = now
	if double_tap:
		if _state != State.DASH and _attack_timer <= 0.0 and _attack2_timer <= 0.0:
			_start_jet()
	else:
		_jbuf = CharacterBase.JUMP_BUFFER

func _unhandled_input(event: InputEvent) -> void:
	if not _active or not _is_player:
		return
	if _is_building_placing():
		return
	if _jet_mode:
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
				if _lmb_cd <= 0.0 and _attack_timer <= 0.0 and _attack2_timer <= 0.0:
					_aim_dir = _calc_aim_dir()
					var fwd := global_transform.basis.z
					if _aim_dir.dot(fwd) < 0.99:
						rotation.y = atan2(_aim_dir.x, _aim_dir.z)
					_lmb_cd = 0.5
					_attack_timer = attack_duration
					_state = State.ATTACK
					_on_primary_attack()
		return
	super._unhandled_input(event)

func _on_primary_attack() -> void:
	_burst_count = 0
	_burst_elapsed = 0.0

func _on_secondary_attack() -> void:
	_spawn_missiles()

func _on_show_animation() -> void:
	_attack2_timer = _attack2_duration
	_state = State.DEVOUR

func _physics_process(delta: float) -> void:
	_flight_cd = max(_flight_cd - delta, 0.0)
	if _jet_mode:
		_update_jet(delta)
		return
	super._physics_process(delta)
	if _state == State.ATTACK:
		_update_burst(delta)

func _update_burst(delta: float) -> void:
	var max_shots: int = JET_BURST_SHOTS if _jet_mode else BURST_SHOTS
	var interval: float = JET_BURST_INTERVAL if _jet_mode else BURST_INTERVAL
	if _burst_count >= max_shots:
		return
	_burst_elapsed += delta
	while _burst_count < max_shots and _burst_elapsed >= _burst_count * interval:
		_spawn_bullet(_burst_count)
		_burst_count += 1

func _spawn_bullet(idx: int) -> void:
	var side := -1.0 if idx % 2 == 0 else 1.0
	var fire_dir: Vector3 = _aim_dir if _aim_dir.length_squared() > 0.001 else global_transform.basis.z
	var muzzle: Vector3 = global_position + Vector3(side * 0.30, 0.85, 0.0)
	if _mesh and _mesh.hand_l and _mesh.hand_r:
		var hand_pivot := _mesh.hand_l if side < 0 else _mesh.hand_r
		muzzle = hand_pivot.global_position + fire_dir * 0.12
	var parent := get_parent()
	if parent == null:
		return
	var bullet := BeyordeathBullet.new()
	parent.add_child(bullet)
	if _jet_mode:
		bullet.hit_damage = 17
	bullet.setup(muzzle, fire_dir, self)

func _spawn_missiles() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var fire_dir: Vector3 = _aim_dir if _aim_dir.length_squared() > 0.001 else global_transform.basis.z
	for side in [-1, 1]:
		var offset := Vector3(side * 0.25, 0.70, 0.0)
		var muzz: Vector3 = global_position + offset
		if _mesh and _mesh.hand_l and _mesh.hand_r:
			var hand_pivot := _mesh.hand_l if side < 0 else _mesh.hand_r
			muzz = hand_pivot.global_position + fire_dir * 0.15
		var missile := BeyordeathMissile.new()
		parent.add_child(missile)
		var mis_dir := fire_dir.rotated(Vector3.UP, side * 0.08)
		missile.setup(muzz, mis_dir, self)

func _start_jet() -> void:
	if _flight_cd > 0.0:
		return
	_jet_mode = true
	_jet_timer = 0.0
	_jet_landing = false
	_jet_dash_timer = 0.0
	_attack_timer = 0.0
	_attack2_timer = 0.0
	_dash_timer = 0.0
	_jbuf = 0.0
	if is_on_floor():
		_jet_ground_y = global_position.y
	_jet_cruise_y = _jet_ground_y + JET_CRUISE_HEIGHT
	velocity = Vector3.ZERO
	_state = State.JUMP
	if _mesh:
		_mesh.set_jet_mode(true)

func _begin_landing() -> void:
	_jet_landing = true
	_jet_timer = 0.0
	_jet_landing_start_y = global_position.y

func _update_jet(delta: float) -> void:
	_time += delta
	_jet_timer += delta
	var cd_delta: float = delta * cooldown_rate
	_lmb_cd = max(_lmb_cd - cd_delta, 0.0)
	_q_cd = max(_q_cd - cd_delta, 0.0)
	_r_cd = max(_r_cd - cd_delta, 0.0)
	_dash_cd = max(_dash_cd - delta, 0.0)
	_attack_timer = max(_attack_timer - delta, 0.0)
	_attack2_timer = max(_attack2_timer - delta, 0.0)
	_jet_dash_timer = max(_jet_dash_timer - delta, 0.0)

	if _attack_timer <= 0.0 and _state == State.ATTACK:
		_state = State.JUMP

	if _state == State.ATTACK:
		_update_burst(delta)

	var dir := _read_input()
	var spd: float = move_speed * 1.1

	var want_dash: bool = Input.is_key_pressed(KEY_Q) and _q_cd <= 0.0 and _attack_timer <= 0.0
	if want_dash and _jet_dash_timer <= 0.0 and try_skill(75):
		var ddir: Vector3 = dir if dir.length_squared() > 0.001 else -global_transform.basis.z
		ddir.y = 0.0
		_jet_dash_dir = ddir.normalized()
		_jet_dash_timer = 0.35
		_jet_bomb_interval = 0.0
		_jet_q_bomb_count = 0
		_q_cd = 5.0
		velocity = _jet_dash_dir * dash_speed * 1.5
	elif _jet_dash_timer > 0.0:
		velocity = _jet_dash_dir * dash_speed * 1.5
		_jet_bomb_interval += delta
		if _jet_bomb_interval >= 0.022 and _jet_q_bomb_count < JET_DASH_BOMB_COUNT:
			_spawn_bomb()
			_jet_q_bomb_count += 1
			_jet_bomb_interval = 0.0
	elif dir.length_squared() > 0.001:
		dir = dir.normalized()
		velocity.x = move_toward(velocity.x, dir.x * spd, acceleration * delta)
		velocity.z = move_toward(velocity.z, dir.z * spd, acceleration * delta)
		rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), delta * 10.0)
	else:
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		velocity.z = move_toward(velocity.z, 0.0, friction * delta)

	if not _jet_landing and _jet_timer >= JET_DURATION:
		_begin_landing()

	var desired_y: float
	if _jet_landing:
		var land_p: float = smoothstep(0.0, 1.0, min(_jet_timer / JET_LANDING_TIME, 1.0))
		desired_y = lerp(_jet_landing_start_y, _jet_ground_y + 0.05, land_p)
	elif _jet_timer < JET_TAKEOFF_TIME:
		var lift_p: float = smoothstep(0.0, 1.0, _jet_timer / JET_TAKEOFF_TIME)
		desired_y = lerp(_jet_ground_y + 0.10, _jet_cruise_y, lift_p)
	else:
		desired_y = _jet_cruise_y + sin(_time * 3.0) * 0.08

	var vertical_speed: float = clamp((desired_y - global_position.y) * 6.0, -5.0, 5.0)
	velocity.y = move_toward(velocity.y, vertical_speed, 20.0 * delta)
	if _state != State.ATTACK:
		_state = State.JUMP
	move_and_slide()
	if _jet_landing and (is_on_floor() or global_position.y <= _jet_ground_y + 0.08):
		_end_jet()
		return
	_animate(delta)

func _end_jet() -> void:
	if _mesh:
		_mesh.set_jet_mode(false)
	_jet_mode = false
	_jet_landing = false
	_jet_timer = 0.0
	_jet_dash_timer = 0.0
	_flight_cd = flight_cooldown
	velocity.y = -0.5
	if Vector2(velocity.x, velocity.z).length_squared() > 0.04:
		_state = State.WALK
	else:
		_state = State.IDLE
	_animate(0.0)

func is_flying() -> bool:
	return _jet_mode

func _spawn_bomb() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var bomb := BeyordeathBomb.new()
	parent.add_child(bomb)
	var bomb_pos := global_position + Vector3(0, -0.3, 0)
	bomb.setup(bomb_pos, _jet_dash_dir, self)

func _animate(delta: float) -> void:
	if _jet_mode:
		_jet_animate()
		return
	_anim.animate(delta)

func _jet_animate() -> void:
	if _mesh == null or _mesh.jet_root == null:
		return
	var roll: float = sin(_time * 2.0) * 0.02
	_mesh.jet_root.rotation.z = roll
	var target_pitch: float = -0.10 if _jet_landing else 0.05
	var weight: float = clamp(_time * 2.0, 0.0, 1.0)
	_mesh.jet_root.rotation.x = lerp(_mesh.jet_root.rotation.x, target_pitch, weight)
