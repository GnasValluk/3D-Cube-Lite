## wolf/wolf_character.gd
## Sinh vật thù địch: Sói Đồng Đêm (Plains Night Wolf) — đồng bằng.
## Nhanh nhẹn lao tới cắn xé liên hồi, máu mỏng hơn. Chết drop Wolf Fang
## và tách tốc độ drop cao. Chỉ gặp về đêm.

extends CharacterBase
class_name WolfCharacter

const HP: float = 18.0
const ATK: int = 4
const SPEED: float = 4.0
const SCALE: float = 0.85

const AGGRO_RANGE: float = 18.0
const ATTACK_RANGE: float = 1.5
const ATTACK_COOLDOWN: float = 0.85
const WANDER_RADIUS: float = 8.0
const WANDER_SPEED_MULT: float = 0.4

const _DroppedItem = preload("res://scripts/items/entities/dropped_item.gd")
const _ExpOrb = preload("res://scripts/items/entities/experience_orb.gd")
const EXP_DROP_RATE: float = 0.26

var _mesh: WolfMesh
var _home: Vector3 = Vector3.ZERO
var _player: Node3D = null
var _attack_cd: float = 0.0
var _target_dir: Vector3 = Vector3.FORWARD
var _base_move_speed: float = 4.0
var _wander_t: float = 0.0
var _idle_t: float = 0.0

func _init() -> void:
	show_world_hp_bar = true

func _build_character() -> void:
	_is_player = false
	character_name = "Sói Đồng Đêm"
	mob_bonus_lv = 2
	level = compute_level()
	var smult: float = get_stat_mult()
	max_hp = maxi(1, int(HP * smult))
	hp = max_hp
	_base_move_speed = SPEED * smult
	move_speed = _base_move_speed
	sprint_speed = move_speed
	acceleration = 34.0
	friction = 8.0
	defense = 1
	attack_power = ATK
	jump_height = 0.8
	jump_time_rise = 0.24
	jump_time_fall = 0.16
	melee_range = 0.45
	hit_radius = 0.34
	_world_hp_enabled = true

	var sc: float = SCALE
	scale = Vector3(sc, sc, sc)

	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.30
	cap.height = 0.80
	col.shape = cap
	col.position = Vector3(0, 0.42, 0)
	add_child(col)

	_mesh = WolfMesh.new()
	_mesh.build(self)
	_rig = _mesh.rig

func _ready() -> void:
	super._ready()
	_home = global_position
	add_to_group("wolf")
	_target_dir = -global_transform.basis.z
	_wander_t = randf_range(1.0, 2.5)

func _find_player() -> Node3D:
	var world := get_tree().current_scene
	if world == null:
		return null
	var mgr := world.get_node_or_null("CharacterManager") as CharacterManager
	if mgr:
		return mgr.get_current_character()
	return null

func _read_input() -> Vector3:
	return _target_dir

func _animate(delta: float) -> void:
	if not is_alive:
		return
	_attack_cd = max(_attack_cd - delta, 0.0)

	if _player == null or not is_instance_valid(_player):
		_player = _find_player()

	var chasing := false
	if _player and is_instance_valid(_player) and _player.get("is_alive"):
		var to_player := _player.global_position - global_position
		if abs(to_player.y) <= 3.0:
			to_player.y = 0.0
			var dist := to_player.length()
			chasing = dist < AGGRO_RANGE
			if chasing:
				if dist > 0.01:
					_target_dir = to_player.normalized()
				if dist < ATTACK_RANGE and _attack_cd <= 0.0:
					_attack_cd = ATTACK_COOLDOWN
					_player.take_damage(attack_power, self)
					SFXManager.play_damage_hit()

	move_speed = _base_move_speed * (WANDER_SPEED_MULT if not chasing else 1.0)
	sprint_speed = move_speed

	if not chasing:
		var to_home := _home - global_position
		to_home.y = 0.0
		var home_dist := to_home.length()
		if home_dist > WANDER_RADIUS:
			_target_dir = to_home.normalized()
			_idle_t = 0.0
			_wander_t = randf_range(0.5, 1.5)
		elif _idle_t > 0.0:
			_idle_t -= delta
			_target_dir = _target_dir.lerp(Vector3.ZERO, delta * 2.0)
		else:
			_wander_t -= delta
			if _wander_t <= 0.0:
				if randf() < 0.3:
					_idle_t = randf_range(0.6, 1.6)
				else:
					_wander_t = randf_range(1.2, 3.0)
					_target_dir = Vector3(cos(randf() * TAU), 0, sin(randf() * TAU))
			_target_dir = _target_dir.normalized()

	if _mesh:
		_mesh.set_chasing(chasing)

func _roll_exp_drop() -> void:
	var world := get_tree().current_scene
	if world == null:
		return
	if randf() < EXP_DROP_RATE * get_rate_mult():
		_ExpOrb.spawn(world, global_position, global_position.y)

func _roll_loot() -> void:
	var world := get_tree().current_scene
	if world == null:
		return
	ItemDatabase.ensure_db()
	var defn: ItemDef = ItemDatabase.items_db.get("wolf_fang")
	if defn and randf() < 0.9 * get_rate_mult():
		var count := randi_range(1, 2)
		var vel := Vector3(randf_range(-1.0, 1.0), randf_range(2.0, 3.5), randf_range(-1.0, 1.0))
		_DroppedItem.spawn(world, defn, global_position, count, vel, global_position.y)

func _die(_attacker: Node3D = null) -> void:
	_roll_loot()
	_roll_exp_drop()
	super._die(_attacker)