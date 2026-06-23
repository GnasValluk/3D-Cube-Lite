## core/character_base.gd
## Base class cho mọi nhân vật (người chơi + bot).
## Chứa: physics, state machine, input, camera, squash/stretch, HP/stats.

extends CharacterBody3D
class_name CharacterBase

signal damage_taken(amount: int, attacker: Node3D)
signal died(attacker: Node3D)
signal hp_changed(current: int, max_hp: int)

# ── Element system ─────────────────────────────────────────────────────────────
enum Element { NONE, DIEN, BANG, PHONG, HOA, HAC_AM, ANH_SANG }
const ELEMENT_COLORS: Dictionary = {
	Element.NONE:    Color(1.0, 1.0, 1.0),
	Element.DIEN:    Color(1.0, 0.85, 0.0),
	Element.BANG:    Color(0.40, 0.80, 1.0),
	Element.PHONG:   Color(0.40, 1.0, 0.40),
	Element.HOA:     Color(1.0, 0.40, 0.0),
	Element.HAC_AM:  Color(1.0, 0.55, 1.0),
	Element.ANH_SANG: Color(1.0, 0.85, 0.0)
}

# ── Stats ─────────────────────────────────────────────────────────────────────
@export var max_hp:             int   = 100
@export var hp:                 int   = 100
@export var defense:            int   = 0
@export var attack_power:       int   = 15
@export var move_speed:         float = 5.5
@export var sprint_speed:       float = 9.5
@export var acceleration:       float = 26.0
@export var friction:           float = 20.0
@export var jump_height:        float = 1.4
@export var jump_time_rise:     float = 0.28
@export var jump_time_fall:     float = 0.20
@export var dash_speed:         float = 18.0
@export var dash_duration:      float = 0.18
@export var dash_cooldown:      float = 0.80
@export var attack_duration:    float = 0.45
@export var melee_damage:       int   = 10
@export var melee_range:        float = 2.0
@export var auto_aim_range:     float = 20.0
@export var lmb_cooldown:       float = 0.0
@export var q_cooldown:         float = 0.0
@export var r_cooldown:         float = 0.0
@export var cooldown_rate:      float = 1.0

var is_alive: bool = true
var character_name: String = ""
var element: int = Element.NONE
var _melee_hit_once: bool = false

# ── State machine ─────────────────────────────────────────────────────────────
enum State { IDLE, WALK, SPRINT, CROUCH, DASH, ATTACK, DEVOUR, JUMP, FALL, HIT, DEAD }
var _state: State = State.IDLE

# ── Timers ────────────────────────────────────────────────────────────────────
const COYOTE_TIME: float = 0.12
const JUMP_BUFFER: float = 0.10
var _coyote:          float  = 0.0
var _jbuf:            float  = 0.0
var _dash_timer:      float  = 0.0
var _dash_cd:         float  = 0.0
var _attack_timer:    float  = 0.0
var _attack2_timer:   float  = 0.0
var _attack2_duration: float = 0.70
var _action_lunge_timer: float = 0.0
var _action_lunge_speed: float = 0.0
var _dash_dir:        Vector3 = Vector3.ZERO
var _lmb_cd:          float   = 0.0
var _q_cd:            float   = 0.0
var _r_cd:            float   = 0.0
var _invul_timer:     float   = 0.0
var _hit_timer:       float   = 0.0
var _death_timer:     float   = 0.0
var _aim_dir:         Vector3 = Vector3.FORWARD

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
var _is_player: bool = true

# ── Camera refs ───────────────────────────────────────────────────────────────
var _camera:  Camera3D
var _iso_rig: Node3D
var _tp_rig:  Node3D
var _use_tp:  bool = false

# ─────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	hp = max_hp
	_jump_v    = (2.0 * jump_height) / jump_time_rise
	_grav_rise = (2.0 * jump_height) / (jump_time_rise * jump_time_rise)
	_grav_fall = (2.0 * jump_height) / (jump_time_fall * jump_time_fall)
	_build_character()
	await get_tree().process_frame
	if _is_player:
		var root: Node = get_parent().get_parent()
		if root == null:
			root = get_parent()
		_iso_rig = root.get_node_or_null("CameraRig")
		_tp_rig  = root.get_node_or_null("TPCameraRig")
		_camera  = get_viewport().get_camera_3d()
	_add_world_hp_bar()

func _add_world_hp_bar() -> void:
	var bar := WorldHPBar.new()
	add_child(bar)
	bar.setup(self)

func _process(delta: float) -> void:
	if _invul_timer > 0.0:
		_invul_timer = max(_invul_timer - delta, 0.0)
	if _hit_timer > 0.0:
		_hit_timer = max(_hit_timer - delta, 0.0)

# ── Overrideable interface ────────────────────────────────────────────────────
func get_element() -> int:
	return element

func _build_character() -> void:      pass
func _animate(_delta: float) -> void: pass
func _on_primary_attack() -> void:    pass
func _on_secondary_attack() -> void:  pass
func _on_show_animation() -> void:    pass

# ── HP / Damage ───────────────────────────────────────────────────────────────
func take_damage(amount: int, attacker: Node3D = null) -> void:
	if not is_alive or _invul_timer > 0.0:
		return
	var dmg := maxi(1, amount - defense)
	hp = maxi(0, hp - dmg)
	_invul_timer = 0.05
	_hit_timer = 0.18
	_hit_flash()
	_spawn_damage_number(dmg, attacker)
	_state = State.HIT
	_attack_timer = 0.0
	_attack2_timer = 0.0
	hp_changed.emit(hp, max_hp)
	damage_taken.emit(dmg, attacker)
	if hp <= 0:
		_die(attacker)

func heal(amount: int) -> void:
	if not is_alive:
		return
	hp = mini(max_hp, hp + amount)
	hp_changed.emit(hp, max_hp)

func _die(_attacker: Node3D = null) -> void:
	is_alive = false
	_flash_restore()
	_death_timer = 1.8
	_state = State.DEAD
	_attack_timer = 0.0
	_attack2_timer = 0.0
	_hit_timer = 0.0
	velocity = Vector3.ZERO
	died.emit(_attacker)

func revive() -> void:
	hp     = max_hp
	is_alive = true
	_active  = true
	_state   = State.IDLE
	_flash_restore()
	_death_timer = 0.0
	_hit_timer = 0.0
	set_physics_process(true)
	set_process_unhandled_input(true)
	set_process_unhandled_key_input(true)
	if _rig:
		_rig.visible = true
	hp_changed.emit(hp, max_hp)

# ── Hit flash ─────────────────────────────────────────────────────────────────
var _white_mat: StandardMaterial3D = null
var _flash_pairs: Array[Dictionary] = []

func _hit_flash() -> void:
	_flash_restore()
	if _rig == null:
		return
	if _white_mat == null:
		_white_mat = StandardMaterial3D.new()
		_white_mat.albedo_color = Color(1, 1, 1)
		_white_mat.emission = Color(1, 1, 1)
		_white_mat.emission_energy_multiplier = 10.0
		_white_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var mis: Array[MeshInstance3D] = []
	_collect_mesh_instances(_rig, mis)
	for mi in mis:
		var orig := mi.material_override as StandardMaterial3D
		if orig == null:
			continue
		_flash_pairs.append({"mi": mi, "orig": orig})
		mi.material_override = _white_mat

	if is_inside_tree():
		get_tree().create_timer(0.18).timeout.connect(_flash_restore)

func _flash_restore() -> void:
	if _flash_pairs.is_empty():
		return
	for pair in _flash_pairs:
		var mi := pair["mi"] as MeshInstance3D
		if is_instance_valid(mi):
			mi.material_override = pair["orig"]
	_flash_pairs.clear()

func _collect_mesh_instances(node: Node3D, out: Array[MeshInstance3D]) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			out.append(child as MeshInstance3D)
		if child is Node3D:
			_collect_mesh_instances(child as Node3D, out)

# ── CharacterManager API ──────────────────────────────────────────────────────
func set_active(value: bool) -> void:
	_active = value
	set_physics_process(value)
	set_process_unhandled_input(value)
	set_process_unhandled_key_input(value)
	if _rig:
		_rig.visible = value
	for child in get_children():
		if child is WorldHPBar:
			child.visible = value
	if value and _is_player:
		await get_tree().process_frame
		_camera = get_viewport().get_camera_3d()

# ── Input ─────────────────────────────────────────────────────────────────────
func _unhandled_key_input(event: InputEvent) -> void:
	if not _active or not _is_player:
		return
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo:
			if k.keycode == KEY_SPACE:
				_jbuf = JUMP_BUFFER
			if k.keycode == KEY_F1:
				_toggle_camera()
			if k.keycode == KEY_CTRL:
				if _attack_timer <= 0.0 and _attack2_timer <= 0.0 and _state != State.DASH:
					_on_show_animation()
			if k.keycode == KEY_R:
				if _r_cd <= 0.0 and _attack2_timer <= 0.0 and _attack_timer <= 0.0 and _state != State.DASH:
					_aim_dir = _calc_aim_dir()
					var fwd := global_transform.basis.z
					if _aim_dir.dot(fwd) < 0.99:
						rotation.y = atan2(_aim_dir.x, _aim_dir.z)
					_r_cd = r_cooldown
					_on_secondary_attack()

func _unhandled_input(event: InputEvent) -> void:
	if not _active or not _is_player:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_LEFT:
				if _lmb_cd <= 0.0 and _attack_timer <= 0.0 and _attack2_timer <= 0.0 and _state != State.DASH:
					_aim_dir = _calc_aim_dir()
					var fwd := global_transform.basis.z
					if _aim_dir.dot(fwd) < 0.99:
						rotation.y = atan2(_aim_dir.x, _aim_dir.z)
					_lmb_cd = lmb_cooldown
					_attack_timer = attack_duration
					_state = State.ATTACK
					_melee_hit_once = false
					_on_primary_attack()

# ── Physics ───────────────────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if not _active:
		return
	if not is_alive:
		if _state == State.DEAD:
			_death_timer -= delta
			velocity.x *= 0.85
			velocity.z *= 0.85
			_animate(delta)
			if _death_timer <= 0.0:
				_active = false
				set_physics_process(false)
				set_process_unhandled_input(false)
				set_process_unhandled_key_input(false)
				if _rig:
					_rig.visible = false
			return
		return

	_time          += delta
	var cd_delta: float = delta * cooldown_rate
	_lmb_cd         = max(_lmb_cd - cd_delta, 0.0)
	_q_cd           = max(_q_cd - cd_delta, 0.0)
	_r_cd           = max(_r_cd - cd_delta, 0.0)
	_dash_cd        = max(_dash_cd - delta, 0.0)
	_attack_timer   = max(_attack_timer - delta, 0.0)
	_attack2_timer  = max(_attack2_timer - delta, 0.0)
	_action_lunge_timer = max(_action_lunge_timer - delta, 0.0)
	_invul_timer    = max(_invul_timer - delta, 0.0)

	if _hit_timer > 0.0:
		velocity.x *= 0.3
		velocity.z *= 0.3
		_state = State.HIT
		move_and_slide()
		_animate(delta)
		return

	var on_floor: bool = is_on_floor()

	if on_floor:
		_coyote = COYOTE_TIME
	else:
		_coyote = max(_coyote - delta, 0.0)
	_jbuf = max(_jbuf - delta, 0.0)

	# DASH
	if _state == State.DASH:
		_dash_timer = max(_dash_timer - delta, 0.0)
		velocity    = _dash_dir * dash_speed
		velocity.y  = 0.0
		if _dash_timer <= 0.0:
			_state = State.IDLE
		move_and_slide()
		_animate(delta)
		return

	# Gravity
	if not on_floor:
		if velocity.y > 0.0:
			velocity.y -= _grav_rise * delta
		else:
			velocity.y -= _grav_fall * delta
	else:
		velocity.y = -0.5

	# Jump
	if _jbuf > 0.0 and _coyote > 0.0:
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

	# Movement input
	var attacking: bool = _attack_timer > 0.0
	var devouring: bool = _attack2_timer > 0.0
	var lunging: bool = _action_lunge_timer > 0.0 and (attacking or devouring)
	var dir: Vector3 = _read_input()
	var sprinting: bool
	if _is_player:
		sprinting = Input.is_key_pressed(KEY_SHIFT)
	else:
		sprinting = false

	var spd: float = sprint_speed if sprinting else move_speed

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

	# Melee hit detection (ATTACK state)
	if attacking and not _melee_hit_once:
		_do_melee_hit()

	# Dash trigger
	var want_dash: bool = false
	if _is_player:
		want_dash = Input.is_key_pressed(KEY_Q) and _q_cd <= 0.0 and not attacking and not devouring
	if want_dash:
		var di := _read_input()
		if di.length_squared() > 0.001:
			_dash_dir = di.normalized()
		else:
			_dash_dir = -global_transform.basis.z
		_dash_dir.y = 0.0
		_dash_dir    = _dash_dir.normalized()
		_q_cd        = q_cooldown
		_dash_timer  = dash_duration
		_dash_cd     = dash_cooldown
		_state       = State.DASH
		_sy_tgt      = 1.15
		move_and_slide()
		_animate(delta)
		return

	# State update
	if attacking:
		_state = State.ATTACK
	elif devouring:
		_state = State.DEVOUR
	elif not on_floor:
		if velocity.y > 0.0:
			_state = State.JUMP
		else:
			_state = State.FALL
	elif dir.length_squared() > 0.001:
		if sprinting:
			_state = State.SPRINT
		else:
			_state = State.WALK
	else:
		_state = State.IDLE

	move_and_slide()
	_animate(delta)

func _do_melee_hit() -> void:
	_melee_hit_once = true
	var mgr := _find_character_manager()
	if mgr == null:
		return
	var fwd := Vector3(sin(rotation.y), 0.0, cos(rotation.y)).normalized()
	for ch in mgr.get_children():
		if ch is CharacterBase and ch != self and ch.is_alive and ch._active:
			var offset: Vector3 = ch.global_position - global_position
			offset.y = 0.0
			var dist: float = offset.length()
			if dist <= melee_range:
				var dot: float = fwd.dot(offset / dist)
				if dot >= 0.4:
					ch.take_damage(melee_damage, self)

func _find_character_manager() -> Node:
	var p := get_parent()
	while p != null:
		if p is CharacterManager:
			return p
		p = p.get_parent()
	return null

# ── Read input direction ──────────────────────────────────────────────────────
func _read_input() -> Vector3:
	if _is_player:
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
	return Vector3.ZERO

func _calc_aim_dir() -> Vector3:
	var target := _find_nearest_target()
	if target != null:
		var dir := target.global_position - global_position
		dir.y = 0.0
		if dir.length_squared() > 0.001:
			return dir.normalized()
	return global_transform.basis.z

func _find_nearest_target() -> CharacterBase:
	var mgr := _find_character_manager()
	if mgr == null:
		return null
	var best: CharacterBase = null
	var best_dsq := auto_aim_range * auto_aim_range
	for ch in mgr.get_children():
		if ch is CharacterBase and ch != self and ch.is_alive and not ch._is_player:
			var dsq := global_position.distance_squared_to(ch.global_position)
			if dsq < best_dsq:
				best_dsq = dsq
				best = ch as CharacterBase
	return best

func _start_forward_lunge(speed: float, duration: float) -> void:
	_action_lunge_speed = speed
	_action_lunge_timer = duration

func _spawn_damage_number(dmg: int, attacker: Node3D = null) -> void:
	var world := get_tree().current_scene
	if world == null:
		return
	var elem: int = Element.NONE
	if attacker != null and attacker.has_method("get_element"):
		elem = attacker.get_element()
	var col: Color = ELEMENT_COLORS.get(elem, Color.WHITE)
	var dn := FloatingDamage.new()
	world.add_child(dn)
	dn.setup(dmg, global_position + Vector3(0, 1.5, 0), col)

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
