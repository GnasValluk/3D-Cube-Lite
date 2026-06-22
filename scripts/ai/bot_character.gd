## ai/bot_character.gd
## AI controller – attach làm con của CharacterBody3D để bot tự động.
## Cung cấp hướng di chuyển, tấn công, dash cho character_base.

extends Node
class_name BotAI

signal ai_state_changed(state: int)

@export var aggro_range:   float = 18.0
@export var attack_range:  float = 2.5
@export var flee_hp_ratio: float = 0.25
@export var wander_radius: float = 12.0
@export var ai_update_interval: float = 0.3
@export var bot_type_name: String = "Bot"

enum AIState { WANDER, CHASE, ATTACK, FLEE }

var ai_state: AIState = AIState.WANDER
var _target: CharacterBase = null
var _ai_timer: float = 0.0
var _wander_target: Vector3 = Vector3.ZERO
var _next_attack_time: float = 0.0
var _spawn_pos: Vector3 = Vector3.ZERO
var _parent: CharacterBase = null

var desired_dir: Vector3 = Vector3.ZERO
var want_attack: bool = false
var want_dash: bool = false
var want_jump: bool = false
var is_sprinting: bool = false

func _ready() -> void:
	_parent = get_parent() as CharacterBase
	if _parent:
		_spawn_pos = _parent.global_position

func _physics_process(delta: float) -> void:
	if _parent == null or not _parent.is_alive:
		return
	_ai_timer += delta
	if _ai_timer >= ai_update_interval:
		_ai_timer = 0.0
		_update_ai()
	_handle_state(delta)

func _update_ai() -> void:
	_find_target()
	if not is_instance_valid(_target) or not _target.is_alive:
		_target = null
		_set_state(AIState.WANDER)
		return
	var dist := _parent.global_position.distance_to(_target.global_position)
	var hp_ratio := float(_parent.hp) / float(_parent.max_hp)
	if hp_ratio <= flee_hp_ratio:
		_set_state(AIState.FLEE)
	elif dist <= attack_range:
		_set_state(AIState.ATTACK)
	elif dist <= aggro_range:
		_set_state(AIState.CHASE)
	else:
		_set_state(AIState.WANDER)

func _set_state(s: AIState) -> void:
	if ai_state != s:
		ai_state = s
		ai_state_changed.emit(s)

func _find_target() -> void:
	var mgr := _find_manager()
	if mgr == null:
		return
	var best: CharacterBase = null
	var best_dist: float = INF
	for ch in mgr.get_children():
		if ch is CharacterBase and ch != _parent and ch.is_alive and ch._is_player:
			var d := _parent.global_position.distance_squared_to(ch.global_position)
			if d < best_dist:
				best_dist = d
				best = ch
	_target = best

func _find_manager() -> Node:
	var p := get_parent()
	while p != null:
		if p is CharacterManager:
			return p
		p = p.get_parent()
	return null

func _handle_state(delta: float) -> void:
	want_attack = false
	want_dash = false
	want_jump = false
	is_sprinting = false

	match ai_state:
		AIState.WANDER:
			_do_wander(delta)
		AIState.CHASE:
			_do_chase(delta)
		AIState.ATTACK:
			_do_attack(delta)
		AIState.FLEE:
			_do_flee(delta)

func _dir_to(pos: Vector3) -> Vector3:
	var d := pos - _parent.global_position
	d.y = 0.0
	if d.length_squared() < 0.01:
		return Vector3.ZERO
	return d.normalized()

func _do_wander(delta: float) -> void:
	if _parent.global_position.distance_squared_to(_wander_target) < 4.0:
		var a := randf_range(0, TAU)
		var r := randf_range(2.0, wander_radius)
		_wander_target = _spawn_pos + Vector3(cos(a) * r, 0, sin(a) * r)
	desired_dir = _dir_to(_wander_target)
	is_sprinting = false

func _do_chase(delta: float) -> void:
	if not is_instance_valid(_target):
		return
	desired_dir = _dir_to(_target.global_position)
	is_sprinting = false

func _do_attack(delta: float) -> void:
	if not is_instance_valid(_target):
		return
	desired_dir = _dir_to(_target.global_position)
	is_sprinting = false
	if _next_attack_time <= 0.0:
		want_attack = true
		_next_attack_time = _parent.attack_duration + 0.4
	_next_attack_time -= delta

func _do_flee(delta: float) -> void:
	if not is_instance_valid(_target):
		return
	var away := _parent.global_position - _target.global_position
	away.y = 0.0
	if away.length_squared() < 0.01:
		return
	away = away.normalized()
	desired_dir = away
	is_sprinting = false

func die() -> void:
	_respawn_timer()

func _respawn_timer() -> void:
	var tween := create_tween()
	tween.tween_interval(3.5)
	tween.tween_callback(_respawn)

func _respawn() -> void:
	if _parent == null or not is_instance_valid(_parent):
		return
	_parent.revive()
	_parent.global_position = _spawn_pos + Vector3(randf_range(-2, 2), 1, randf_range(-2, 2))
	_parent.velocity = Vector3.ZERO
	_set_state(AIState.WANDER)
