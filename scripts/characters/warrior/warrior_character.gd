## warrior/warrior_character.gd
## Warrior dùng beam tầm thẳng và cú nhảy dậm đất mạnh.

extends CharacterBase
class_name WarriorCharacter

const BEAM_ATTACK_DURATION: float = 0.52
const BEAM_FIRE_TIME: float = 0.14
const STOMP_DURATION: float = 0.84
const STOMP_AIR_RATIO: float = 0.78
const STOMP_FORWARD_DISTANCE: float = 5.6
const STOMP_APEX_HEIGHT: float = 2.2
const BEAM_SHAKE_INTENSITY: float = 0.07
const BEAM_SHAKE_DURATION: float = 0.10
const STOMP_SHAKE_INTENSITY: float = 0.22
const STOMP_SHAKE_DURATION: float = 0.20

var _mesh: WarriorMesh
var _anim: WarriorAnimator
var _beam_spawned: bool = false
var _stomping: bool = false
var _stomp_impacted: bool = false
var _stomp_start: Vector3 = Vector3.ZERO
var _stomp_target: Vector3 = Vector3.ZERO
var _stomp_ground_y: float = 0.0

func _build_character() -> void:
	move_speed = 4.6
	sprint_speed = 7.4
	jump_height = 1.2
	dash_speed = 15.0
	attack_duration = BEAM_ATTACK_DURATION
	_attack2_duration = STOMP_DURATION
	lmb_cooldown = 0.8
	q_cooldown   = 1.8
	r_cooldown   = 6.0
	max_hp = 800
	character_name = "Warrior"
	element        = Element.BANG

	var col := CollisionShape3D.new()
	var cs := CapsuleShape3D.new()
	cs.radius = 0.42
	cs.height = 1.72
	col.shape = cs
	col.position = Vector3(0, 0.86, 0)
	add_child(col)

	_mesh = WarriorMesh.new()
	_mesh.build(self)
	_rig = _mesh.rig

	_anim = WarriorAnimator.new()
	_anim.setup(_mesh, self)

func _unhandled_key_input(event: InputEvent) -> void:
	super._unhandled_key_input(event)

func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	super._unhandled_input(event)

func _physics_process(delta: float) -> void:
	if _stomping:
		_update_stomp(delta)
		return
	super._physics_process(delta)
	if _state == State.ATTACK and not _beam_spawned:
		var elapsed: float = attack_duration - _attack_timer
		if elapsed >= BEAM_FIRE_TIME:
			_spawn_beam()
			_beam_spawned = true

func _on_primary_attack() -> void:
	attack_duration = BEAM_ATTACK_DURATION
	_beam_spawned = false
	_stomp_impacted = false

func _on_secondary_attack() -> void:
	if not is_on_floor():
		_attack2_timer = 0.0
		_state = State.IDLE
		return
	_attack2_duration = STOMP_DURATION
	_attack2_timer = _attack2_duration
	_stomping = true
	_stomp_impacted = false
	_stomp_ground_y = global_position.y
	_stomp_start = global_position
	_stomp_target = global_position + _forward_dir() * STOMP_FORWARD_DISTANCE
	_stomp_target.y = _stomp_ground_y
	velocity = Vector3.ZERO
	_sy_tgt = 1.12

func _update_stomp(delta: float) -> void:
	_time += delta
	_dash_cd = max(_dash_cd - delta, 0.0)
	_attack_timer = 0.0
	_action_lunge_timer = 0.0
	_attack2_timer = max(_attack2_timer - delta, 0.0)

	_sy_cur = lerp(_sy_cur, _sy_tgt, delta * 18.0)
	_sy_tgt = lerp(_sy_tgt, 1.0, delta * 10.0)
	if _rig:
		var sx: float = 1.0 + (1.0 - _sy_cur) * 0.5
		_rig.scale = Vector3(sx, _sy_cur, sx)

	var progress: float = get_stomp_progress()
	var air_progress: float = clamp(progress / STOMP_AIR_RATIO, 0.0, 1.0)
	var horiz: float = smoothstep(0.0, 1.0, air_progress)
	var arc: float = sin(air_progress * PI) * STOMP_APEX_HEIGHT
	var pos: Vector3 = _stomp_start.lerp(_stomp_target, horiz)
	pos.y = _stomp_ground_y + arc
	global_position = pos
	velocity = Vector3.ZERO
	_state = State.DEVOUR

	if air_progress >= 1.0 and not _stomp_impacted:
		global_position = _stomp_target
		_stomping = false
		_stomp_impacted = true
		_sy_tgt = 0.72
		_spawn_ground_impact()
		_shake_cameras(STOMP_SHAKE_INTENSITY, STOMP_SHAKE_DURATION)
		_do_stomp_damage()

	_animate(delta)

func get_attack_progress() -> float:
	if attack_duration <= 0.0:
		return 0.0
	return clamp(1.0 - (_attack_timer / attack_duration), 0.0, 1.0)

func get_beam_progress() -> float:
	return get_attack_progress()

func get_stomp_progress() -> float:
	if _attack2_duration <= 0.0:
		return 0.0
	return clamp(1.0 - (_attack2_timer / _attack2_duration), 0.0, 1.0)

func is_stomp_airborne() -> bool:
	return _stomping

func has_stomp_impacted() -> bool:
	return _stomp_impacted

func _spawn_beam() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var beam := WarriorBeam.new()
	parent.add_child(beam)
	var beam_dir: Vector3 = _aim_dir if _aim_dir.length_squared() > 0.001 else _forward_dir()
	var origin: Vector3 = global_position + Vector3(0.0, 1.18, 0.0) + beam_dir * 0.95
	if _mesh:
		if _mesh.chest:
			origin = _mesh.chest.global_position + beam_dir * 0.72 + Vector3(0.0, 0.02, 0.0)
		elif _mesh.spine:
			origin = _mesh.spine.global_position + beam_dir * 0.82 + Vector3(0.0, 0.08, 0.0)
	beam.setup(origin, beam_dir, self)
	_shake_cameras(BEAM_SHAKE_INTENSITY, BEAM_SHAKE_DURATION)

func _spawn_ground_impact() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var impact := WarriorGroundImpact.new()
	parent.add_child(impact)
	impact.setup(global_position + Vector3(0.0, 0.02, 0.0))

func _scene_root() -> Node:
	var scene_root: Node = get_parent().get_parent()
	if scene_root == null:
		scene_root = get_parent()
	return scene_root

func _forward_dir() -> Vector3:
	return Vector3(sin(rotation.y), 0.0, cos(rotation.y)).normalized()

func _shake_cameras(intensity: float, duration: float) -> void:
	if is_instance_valid(_iso_rig) and _iso_rig.has_method("add_shake"):
		_iso_rig.call("add_shake", intensity, duration)
	if is_instance_valid(_tp_rig) and _tp_rig.has_method("add_shake"):
		_tp_rig.call("add_shake", intensity, duration)

func _do_stomp_damage() -> void:
	var mgr: Node = _find_character_manager()
	if mgr == null:
		return
	for ch_node in mgr.get_children():
		if ch_node is CharacterBase and ch_node != self and ch_node.is_alive and ch_node._active:
			var d: float = global_position.distance_to(ch_node.global_position)
			if d <= 4.0:
				ch_node.take_damage(150, self)
	if mgr.has_method("get_party_characters"):
		var party: Array[CharacterBase] = mgr.get_party_characters()
		var shield_amount: int = max_hp * 20 / 100
		for pm in party:
			if pm.is_alive:
				pm.add_shield(shield_amount)
				var applied: int = shield_amount
				get_tree().create_timer(10.0).timeout.connect(func():
					if is_instance_valid(pm):
						pm.shield = max(pm.shield - applied, 0)
						pm.shield_changed.emit(pm.shield)
					)

func _find_character_manager() -> Node:
	var p := get_parent()
	while p != null:
		if p is CharacterManager:
			return p
		p = p.get_parent()
	return null

func _animate(delta: float) -> void:
	_anim.animate(delta)
